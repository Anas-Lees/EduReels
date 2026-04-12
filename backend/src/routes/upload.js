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
} = require('../services/claude-service');
const { db } = require('../config/firebase');

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
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.flushHeaders();

    // Step 1: Extract concepts (fast ~2s)
    const concepts = await extractConcepts(pdfData.text, subject);
    const uploadId = uuidv4();
    const reelIds = [];

    sendSSE(res, 'start', { totalConcepts: concepts.length, uploadId });

    if (aborted) { fs.unlinkSync(filePath); return res.end(); }

    // Step 2: Generate reels one by one
    for (let i = 0; i < concepts.length; i++) {
      if (aborted) break;

      try {
        const isVideo = (i % 3 === 1); // Every 3rd reel (index 1, 4, 7) is video
        let reelData;

        if (isVideo) {
          reelData = await generateVideoReel(concepts[i], pdfData.text, subject);
        } else {
          reelData = await generateSingleReel(concepts[i], pdfData.text, subject);
        }

        const reelId = uuidv4();
        const reelDoc = {
          id: reelId,
          userId: req.user.uid,
          title: reelData.title,
          slides: reelData.slides || [],
          scenes: reelData.scenes || [],
          narration: reelData.narration,
          quiz: reelData.quiz,
          tags: reelData.tags || [],
          subject,
          type: isVideo ? 'video' : 'card',
          likes: 0,
          views: 0,
          createdAt: new Date().toISOString(),
          pdfName: req.file.originalname,
        };

        // Save immediately to Firestore
        await db.collection('reels').doc(reelId).set(reelDoc);
        reelIds.push(reelId);

        // Send reel to client
        sendSSE(res, 'reel', reelDoc);
        console.log(`Generated reel ${i + 1}/${concepts.length}: ${reelData.title} (${isVideo ? 'video' : 'card'})`);
      } catch (err) {
        console.error(`Error generating reel ${i + 1}:`, err.message);
        sendSSE(res, 'error', { message: err.message, index: i });
      }
    }

    // Save upload record
    if (reelIds.length > 0) {
      await db.collection('uploads').doc(uploadId).set({
        id: uploadId,
        userId: req.user.uid,
        fileName: req.file.originalname,
        subject,
        reelCount: reelIds.length,
        reelIds,
        createdAt: new Date().toISOString(),
      });
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
    // If headers already sent, send error as SSE
    if (res.headersSent) {
      sendSSE(res, 'error', { message: 'An error occurred during processing' });
      res.end();
    } else {
      res.status(500).json({ error: 'Failed to process PDF' });
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
    const filePath = req.file.path;

    const pdfBuffer = fs.readFileSync(filePath);
    const pdfData = await pdfParse(pdfBuffer);

    if (!pdfData.text || pdfData.text.trim().length < 50) {
      fs.unlinkSync(filePath);
      return res.status(400).json({ error: 'PDF has too little text content' });
    }

    const reelData = await generateReelsFromText(pdfData.text, subject);

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
        type: 'card',
        likes: 0,
        views: 0,
        createdAt: new Date().toISOString(),
        pdfName: req.file.originalname,
      });

      reelIds.push(reelId);
    }

    const uploadId = uuidv4();
    batch.set(db.collection('uploads').doc(uploadId), {
      id: uploadId,
      userId: req.user.uid,
      fileName: req.file.originalname,
      subject,
      reelCount: reelIds.length,
      reelIds,
      createdAt: new Date().toISOString(),
    });

    await batch.commit();
    fs.unlinkSync(filePath);

    res.json({ message: 'Reels generated!', uploadId, reelCount: reelIds.length, reelIds });
  } catch (error) {
    console.error('Upload error:', error.message || error);
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    res.status(500).json({ error: error.message || 'Failed to process PDF.' });
  }
});

module.exports = router;
