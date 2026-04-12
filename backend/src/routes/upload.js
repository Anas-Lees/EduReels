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
  generateSingleReel,
  generateVideoReel,
  STYLE_PRESETS,
} = require('../services/claude-service');
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

// POST /api/upload/stream - SSE streaming reel generation
router.post('/stream', verifyToken, upload.single('pdf'), async (req, res) => {
  let aborted = false;
  req.on('close', () => { aborted = true; });

  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No PDF file uploaded' });
    }

    const subject = req.body.subject || 'General';
    const style = STYLE_PRESETS[req.body.style] ? req.body.style : 'realistic';
    const groupId = req.body.groupId || '';
    const explanationStyle = req.body.explanationStyle || '';
    const filePath = req.file.path;

    // Parse PDF
    const pdfBuffer = fs.readFileSync(filePath);
    const pdfData = await pdfParse(pdfBuffer);

    if (!pdfData.text || pdfData.text.trim().length < 50) {
      fs.unlinkSync(filePath);
      return res.status(400).json({ error: 'PDF has too little text content' });
    }

    // Set SSE headers
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.flushHeaders();

    // Step 1: Extract concepts (fast ~2s)
    const concepts = await extractConcepts(pdfData.text, subject, explanationStyle);
    const uploadId = uuidv4();
    const reelIds = [];

    sendSSE(res, 'start', { totalConcepts: concepts.length, uploadId });

    if (aborted) { fs.unlinkSync(filePath); return res.end(); }

    // Step 2: Generate reels in parallel batches of 3 for speed
    const BATCH_SIZE = 3;
    for (let batchStart = 0; batchStart < concepts.length; batchStart += BATCH_SIZE) {
      if (aborted) break;

      const batch = concepts.slice(batchStart, batchStart + BATCH_SIZE);
      const promises = batch.map((concept, offset) => {
        const i = batchStart + offset;
        const isVideo = (i % 3 === 1);
        const genFn = isVideo
          ? generateVideoReel(concept, pdfData.text, subject, style, explanationStyle)
          : generateSingleReel(concept, pdfData.text, subject, style, explanationStyle);
        return genFn
          .then(data => ({ data, index: i, isVideo }))
          .catch(err => ({ error: err, index: i, isVideo: false }));
      });

      const results = await Promise.all(promises);

      // Process results in order
      for (const result of results) {
        if (aborted) break;

        if (result.error) {
          console.error(`Error generating reel ${result.index + 1}:`, result.error.message);
          sendSSE(res, 'error', { message: result.error.message, index: result.index });
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
        };

        await db.collection('reels').doc(reelId).set(reelDoc);
        reelIds.push(reelId);

        sendSSE(res, 'reel', reelDoc);
        console.log(`Generated reel ${result.index + 1}/${concepts.length}: ${result.data.title} (${result.isVideo ? 'video' : 'card'}) [${style}]`);
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

    sendSSE(res, 'done', { reelCount: reelIds.length, uploadId });
    res.end();
  } catch (error) {
    console.error('Stream upload error:', error.message);
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
