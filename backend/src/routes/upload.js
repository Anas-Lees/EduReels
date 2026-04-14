const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const pdfParse = require('pdf-parse');
const { v4: uuidv4 } = require('uuid');
const { verifyToken } = require('../middleware/auth');
const {
  generateReelsFromText,
  extractConcepts,
  extractConceptsFromPage,
  generateSingleReel,
  generateVideoReel,
  STYLE_PRESETS,
} = require('../services/claude-service');
const { extractPages } = require('../utils/pdf-extractor');
const { db, admin } = require('../config/firebase');

const router = express.Router();

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configure multer for PDF uploads
const storage = multer.diskStorage({
  destination: uploadsDir,
  filename: (req, file, cb) => {
    cb(null, `${uuidv4()}-${file.originalname}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'application/pdf') {
      cb(null, true);
    } else {
      cb(new Error('Only PDF files are allowed'));
    }
  },
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB max
});

// Helper: send SSE event
function sendSSE(res, event, data) {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

// POST /api/upload/stream - SSE streaming reel generation (page-by-page)
router.post('/stream', verifyToken, upload.single('pdf'), async (req, res) => {
  let aborted = false;
  req.on('close', () => { aborted = true; });

  // Keepalive interval handle
  let keepaliveInterval = null;

  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No PDF file uploaded' });
    }

    const subject = req.body.subject || 'General';
    const style = STYLE_PRESETS[req.body.style] ? req.body.style : 'realistic';
    const groupId = req.body.groupId || '';
    const explanationStyle = req.body.explanationStyle || '';
    const filePath = req.file.path;

    // Parse PDF page by page
    const pdfBuffer = fs.readFileSync(filePath);
    const pages = await extractPages(pdfBuffer);

    if (!pages || pages.length === 0) {
      fs.unlinkSync(filePath);
      return res.status(400).json({ error: 'PDF has too little text content (no pages with 100+ chars)' });
    }

    // Enforce max 100 pages
    const MAX_PAGES = 100;
    let truncated = false;
    if (pages.length > MAX_PAGES) {
      truncated = true;
      pages.length = MAX_PAGES;
    }

    // Set SSE headers
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.flushHeaders();

    // Start keepalive comments every 15s
    keepaliveInterval = setInterval(() => {
      if (!aborted) {
        res.write(': keepalive\n\n');
      }
    }, 15000);

    const uploadId = uuidv4();
    const reelIds = [];
    const allConceptTitles = []; // Track titles across pages to avoid duplicates
    let totalReelCount = 0;

    sendSSE(res, 'start', {
      totalPages: pages.length,
      uploadId,
      truncated: truncated ? `PDF truncated to ${MAX_PAGES} pages` : undefined,
    });

    if (aborted) { fs.unlinkSync(filePath); clearInterval(keepaliveInterval); return res.end(); }

    // Process each page
    for (let pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      if (aborted) break;

      const page = pages[pageIdx];

      // Extract concepts from this page
      let concepts;
      try {
        concepts = await extractConceptsFromPage(
          page.text,
          page.pageNum,
          subject,
          allConceptTitles,
          explanationStyle
        );
      } catch (err) {
        console.error(`Error extracting concepts from page ${page.pageNum}:`, err.message);
        sendSSE(res, 'error', { message: `Page ${page.pageNum}: ${err.message}`, pageNumber: page.pageNum });
        continue;
      }

      if (!concepts || concepts.length === 0) {
        sendSSE(res, 'page_done', { pageNumber: page.pageNum, reelCount: 0 });
        continue;
      }

      sendSSE(res, 'page_start', {
        pageNumber: page.pageNum,
        pageText: page.text.substring(0, 200),
        conceptCount: concepts.length,
      });

      // Add new concept titles to dedup list
      concepts.forEach(c => allConceptTitles.push(c.title));

      // Generate reels for this page's concepts in parallel batches of 3
      const BATCH_SIZE = 3;
      let pageReelCount = 0;

      for (let batchStart = 0; batchStart < concepts.length; batchStart += BATCH_SIZE) {
        if (aborted) break;

        const batch = concepts.slice(batchStart, batchStart + BATCH_SIZE);
        const promises = batch.map((concept, offset) => {
          const globalIdx = totalReelCount + batchStart + offset;
          const isVideo = (globalIdx % 3 === 1);
          const genFn = isVideo
            ? generateVideoReel(concept.title, page.text, subject, style, explanationStyle, concept.sourceQuote || '', concept.pageNumber)
            : generateSingleReel(concept.title, page.text, subject, style, explanationStyle, concept.sourceQuote || '', concept.pageNumber);
          return genFn
            .then(data => ({ data, concept, isVideo }))
            .catch(err => ({ error: err, concept, isVideo: false }));
        });

        const results = await Promise.all(promises);

        for (const result of results) {
          if (aborted) break;

          if (result.error) {
            console.error(`Error generating reel for "${result.concept.title}":`, result.error.message);
            sendSSE(res, 'error', { message: result.error.message, concept: result.concept.title });
            continue;
          }

          const reelId = uuidv4();
          const reelDoc = {
            id: reelId,
            userId: req.user.uid,
            title: result.data.title,
            slides: result.data.slides || [],
            scenes: result.data.scenes || [],
            narration: result.data.narration,
            quiz: result.data.quiz,
            tags: result.data.tags || [],
            subject,
            style,
            type: result.isVideo ? 'video' : 'card',
            likes: 0,
            views: 0,
            createdAt: new Date().toISOString(),
            pdfName: req.file.originalname,
            groupId: groupId || '',
            explanationStyle: explanationStyle || '',
            sourceQuote: result.data.sourceQuote || '',
            pageNumber: result.data.pageNumber || null,
          };

          await db.collection('reels').doc(reelId).set(reelDoc);
          reelIds.push(reelId);
          pageReelCount++;

          sendSSE(res, 'reel', reelDoc);
          console.log(`Generated reel: ${result.data.title} (page ${page.pageNum}, ${result.isVideo ? 'video' : 'card'}) [${style}]`);
        }
      }

      totalReelCount += pageReelCount;

      sendSSE(res, 'page_done', { pageNumber: page.pageNum, reelCount: pageReelCount });

      // Delay between pages to avoid Groq rate limits
      if (pageIdx < pages.length - 1 && !aborted) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }

    // Save upload record
    if (reelIds.length > 0) {
      await db.collection('uploads').doc(uploadId).set({
        id: uploadId,
        userId: req.user.uid,
        fileName: req.file.originalname,
        subject,
        style,
        reelCount: reelIds.length,
        reelIds,
        groupId: groupId || '',
        explanationStyle: explanationStyle || '',
        createdAt: new Date().toISOString(),
      });

      // Update group reel count if groupId is provided
      if (groupId) {
        await db.collection('groups').doc(groupId).update({
          reelCount: admin.firestore.FieldValue.increment(reelIds.length),
        });
      }
    }

    // Clean up
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    clearInterval(keepaliveInterval);

    sendSSE(res, 'done', { totalReels: reelIds.length, uploadId });
    res.end();
  } catch (error) {
    console.error('Stream upload error:', error.message);
    if (keepaliveInterval) clearInterval(keepaliveInterval);
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    const isRateLimit = error.message && error.message.includes('429');
    const userMessage = isRateLimit
      ? 'AI rate limit reached. Please wait a minute and try again.'
      : 'An error occurred during processing';
    if (res.headersSent) {
      sendSSE(res, 'error', { message: userMessage });
      res.end();
    } else {
      res.status(isRateLimit ? 429 : 500).json({ error: userMessage });
    }
  }
});

// POST /api/upload - Original bulk upload (kept for mobile)
router.post('/', verifyToken, upload.single('pdf'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No PDF file uploaded' });
    }

    const subject = req.body.subject || 'General';
    const style = STYLE_PRESETS[req.body.style] ? req.body.style : 'realistic';
    const groupId = req.body.groupId || '';
    const explanationStyle = req.body.explanationStyle || '';
    const filePath = req.file.path;

    const pdfBuffer = fs.readFileSync(filePath);
    const pdfData = await pdfParse(pdfBuffer);

    if (!pdfData.text || pdfData.text.trim().length < 50) {
      fs.unlinkSync(filePath);
      return res.status(400).json({ error: 'PDF has too little text content' });
    }

    const reelData = await generateReelsFromText(pdfData.text, subject, style, explanationStyle);

    const reelIds = [];
    const batch = db.batch();

    for (const reel of reelData.reels) {
      const reelId = uuidv4();
      const reelRef = db.collection('reels').doc(reelId);

      batch.set(reelRef, {
        id: reelId,
        userId: req.user.uid,
        title: reel.title,
        slides: reel.slides,
        scenes: [],
        narration: reel.narration,
        quiz: reel.quiz,
        tags: reel.tags || [],
        subject,
        style,
        type: 'card',
        likes: 0,
        views: 0,
        createdAt: new Date().toISOString(),
        pdfName: req.file.originalname,
        groupId: groupId || '',
        explanationStyle: explanationStyle || '',
        sourceQuote: reel.sourceQuote || '',
        pageNumber: reel.pageNumber || null,
      });

      reelIds.push(reelId);
    }

    const uploadId = uuidv4();
    batch.set(db.collection('uploads').doc(uploadId), {
      id: uploadId,
      userId: req.user.uid,
      fileName: req.file.originalname,
      subject,
      style,
      reelCount: reelIds.length,
      reelIds,
      groupId: groupId || '',
      explanationStyle: explanationStyle || '',
      createdAt: new Date().toISOString(),
    });

    // Update group reel count if groupId is provided
    if (groupId) {
      batch.update(db.collection('groups').doc(groupId), {
        reelCount: admin.firestore.FieldValue.increment(reelIds.length),
      });
    }

    await batch.commit();
    fs.unlinkSync(filePath);

    res.json({ message: 'Reels generated!', uploadId, reelCount: reelIds.length, reelIds });
  } catch (error) {
    console.error('Upload error:', error.message || error);
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    res.status(500).json({ error: 'Failed to process PDF' });
  }
});

module.exports = router;
