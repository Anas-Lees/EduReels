const express = require('express');
const { verifyToken } = require('../middleware/auth');
const { db } = require('../config/firebase');

const router = express.Router();

// GET /api/reels - Get reel feed (paginated)
router.get('/', verifyToken, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const lastId = req.query.lastId;

    let query = db.collection('reels')
      .orderBy('createdAt', 'desc')
      .limit(limit);

    if (lastId) {
      const lastDoc = await db.collection('reels').doc(lastId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    const snapshot = await query.get();
    const reels = snapshot.docs.map(doc => doc.data());

    res.json({ reels, hasMore: reels.length === limit });
  } catch (error) {
    console.error('Feed error:', error);
    res.status(500).json({ error: 'Failed to load reels' });
  }
});

// GET /api/reels/my - Get current user's reels
router.get('/my', verifyToken, async (req, res) => {
  try {
    const snapshot = await db.collection('reels')
      .where('userId', '==', req.user.uid)
      .get();

    const reels = snapshot.docs.map(doc => doc.data());
    reels.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    res.json({ reels });
  } catch (error) {
    console.error('My reels error:', error);
    res.status(500).json({ error: 'Failed to load your reels' });
  }
});

// POST /api/reels/:id/like - Toggle like
router.post('/:id/like', verifyToken, async (req, res) => {
  try {
    const reelId = req.params.id;
    const userId = req.user.uid;
    const likeRef = db.collection('likes').doc(`${userId}_${reelId}`);
    const likeDoc = await likeRef.get();

    const reelRef = db.collection('reels').doc(reelId);

    if (likeDoc.exists) {
      // Unlike
      await likeRef.delete();
      await reelRef.update({
        likes: require('firebase-admin').firestore.FieldValue.increment(-1),
      });
      res.json({ liked: false });
    } else {
      // Like
      await likeRef.set({ userId, reelId, createdAt: new Date().toISOString() });
      await reelRef.update({
        likes: require('firebase-admin').firestore.FieldValue.increment(1),
      });
      res.json({ liked: true });
    }
  } catch (error) {
    console.error('Like error:', error);
    res.status(500).json({ error: 'Failed to update like' });
  }
});

// POST /api/reels/:id/view - Track view
router.post('/:id/view', verifyToken, async (req, res) => {
  try {
    const reelRef = db.collection('reels').doc(req.params.id);
    await reelRef.update({
      views: require('firebase-admin').firestore.FieldValue.increment(1),
    });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to track view' });
  }
});

// POST /api/reels/:id/save - Toggle save/bookmark
router.post('/:id/save', verifyToken, async (req, res) => {
  try {
    const reelId = req.params.id;
    const userId = req.user.uid;
    const saveRef = db.collection('saved').doc(`${userId}_${reelId}`);
    const saveDoc = await saveRef.get();

    if (saveDoc.exists) {
      await saveRef.delete();
      res.json({ saved: false });
    } else {
      await saveRef.set({ userId, reelId, createdAt: new Date().toISOString() });
      res.json({ saved: true });
    }
  } catch (error) {
    res.status(500).json({ error: 'Failed to save reel' });
  }
});

module.exports = router;
