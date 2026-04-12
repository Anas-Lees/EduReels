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
app.use(cors());
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

// Routes
app.use('/api/upload', uploadRoutes);
app.use('/api/reels', reelRoutes);
app.use('/api/groups', groupRoutes);

// Image proxy - bypasses CORS for Pollinations AI images
app.get('/api/image', async (req, res) => {
  try {
    const prompt = req.query.prompt;
    if (!prompt) return res.status(400).json({ error: 'Missing prompt' });

    const width = req.query.width || 720;
    const height = req.query.height || 1280;
    const seed = req.query.seed || '42';
    const encoded = encodeURIComponent(prompt);
    const url = `https://image.pollinations.ai/prompt/${encoded}?width=${width}&height=${height}&model=flux&nologo=true&seed=${seed}`;

    const fetch = (await import('node-fetch')).default;
    const response = await fetch(url, { timeout: 30000 });

    if (!response.ok) {
      return res.status(response.status).json({ error: 'Image generation failed' });
    }

    res.set({
      'Content-Type': response.headers.get('content-type') || 'image/jpeg',
      'Cache-Control': 'public, max-age=86400',
      'Access-Control-Allow-Origin': '*',
    });
    response.body.pipe(res);
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
