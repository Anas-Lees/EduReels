require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const uploadRoutes = require('./routes/upload');
const reelRoutes = require('./routes/reels');
const groupRoutes = require('./routes/groups');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);
app.use(cors({
  origin: allowedOrigins.length > 0
    ? (origin, callback) => {
        // Allow requests with no origin (mobile apps, curl) and listed origins
        if (!origin || allowedOrigins.includes(origin)) {
          callback(null, true);
        } else {
          callback(new Error('Not allowed by CORS'));
        }
      }
    : true, // fallback to allow-all if no env var set (dev mode)
  credentials: true,
}));
app.use(express.json({ limit: '10mb' }));

// Request logging
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

// Routes
app.use('/api/upload', uploadRoutes);
app.use('/api/reels', reelRoutes);
app.use('/api/groups', groupRoutes);

// Simple in-memory rate limiter for image proxy
const imageRateLimit = {};
const IMAGE_RATE_WINDOW = 60000; // 1 minute
const IMAGE_RATE_MAX = 30; // max 30 requests per minute per IP

// Image proxy - bypasses CORS for AI images with retry + fallback
app.get('/api/image', async (req, res) => {
  try {
    // Rate limit by IP
    const clientIp = req.ip || req.connection.remoteAddress || 'unknown';
    const now = Date.now();
    if (!imageRateLimit[clientIp] || now - imageRateLimit[clientIp].start > IMAGE_RATE_WINDOW) {
      imageRateLimit[clientIp] = { start: now, count: 0 };
    }
    imageRateLimit[clientIp].count++;
    if (imageRateLimit[clientIp].count > IMAGE_RATE_MAX) {
      return res.status(429).json({ error: 'Too many image requests. Please wait.' });
    }

    const prompt = req.query.prompt;
    if (!prompt) return res.status(400).json({ error: 'Missing prompt' });

    // Sanitize prompt: limit length and strip control characters
    if (prompt.length > 500) return res.status(400).json({ error: 'Prompt too long (max 500 chars)' });
    const sanitizedPrompt = prompt.replace(/[\x00-\x1f]/g, '');

    const width = Math.min(parseInt(req.query.width) || 720, 1920);
    const height = Math.min(parseInt(req.query.height) || 1280, 1920);
    const seed = (req.query.seed || '42').replace(/[^0-9]/g, '').substring(0, 10) || '42';
    const encoded = encodeURIComponent(sanitizedPrompt);

    const fetch = (await import('node-fetch')).default;

    // Try Pollinations with retry
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const url = `https://image.pollinations.ai/prompt/${encoded}?width=${width}&height=${height}&model=flux&nologo=true&seed=${seed}`;
        const response = await fetch(url, { timeout: 25000 });
        if (response.ok) {
          res.set({
            'Content-Type': response.headers.get('content-type') || 'image/jpeg',
            'Cache-Control': 'public, max-age=86400',
            'Access-Control-Allow-Origin': '*',
          });
          return response.body.pipe(res);
        }
        if (response.status === 429 && attempt === 0) {
          await new Promise(r => setTimeout(r, 2000));
          continue;
        }
      } catch (e) {
        if (attempt === 0) continue;
      }
      break;
    }

    // Fallback: loremflickr with keywords extracted from prompt for relevant images
    const keywords = sanitizedPrompt.replace(/[^a-zA-Z ]/g, '').split(' ').filter(w => w.length > 3).slice(0, 3).join(',') || 'education,learning';
    const fallbackUrl = `https://loremflickr.com/${width}/${height}/${encodeURIComponent(keywords)}`;
    const fallback = await fetch(fallbackUrl, { redirect: 'follow', timeout: 10000 });
    if (fallback.ok) {
      res.set({
        'Content-Type': fallback.headers.get('content-type') || 'image/jpeg',
        'Cache-Control': 'public, max-age=86400',
        'Access-Control-Allow-Origin': '*',
      });
      return fallback.body.pipe(res);
    }

    res.status(502).json({ error: 'All image sources failed' });
  } catch (e) {
    console.error('Image proxy error:', e.message);
    res.status(500).json({ error: 'Image proxy failed' });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`EduReels API running on port ${PORT}`);
});
