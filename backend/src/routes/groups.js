const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { verifyToken } = require('../middleware/auth');
const { db } = require('../config/firebase');

const router = express.Router();

// POST /api/groups - Create a group
router.post('/', verifyToken, async (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Group name is required' });
    }

    const groupId = uuidv4();
    const group = {
      id: groupId,
      name: name.trim(),
      description: (description || '').trim(),
      userId: req.user.uid,
      reelCount: 0,
      createdAt: new Date().toISOString(),
    };

    await db.collection('groups').doc(groupId).set(group);
    res.json(group);
  } catch (error) {
    console.error('Create group error:', error);
    res.status(500).json({ error: 'Failed to create group' });
  }
});

// GET /api/groups - List user's groups
router.get('/', verifyToken, async (req, res) => {
  try {
    const snapshot = await db.collection('groups')
      .where('userId', '==', req.user.uid)
      .get();

    const groups = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    groups.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    res.json({ groups });
  } catch (error) {
    console.error('List groups error:', error);
    res.status(500).json({ error: 'Failed to load groups' });
  }
});

// GET /api/groups/:id - Get single group
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const doc = await db.collection('groups').doc(req.params.id).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    res.status(500).json({ error: 'Failed to load group' });
  }
});

// GET /api/groups/:id/reels - Get reels in a group
router.get('/:id/reels', verifyToken, async (req, res) => {
  try {
    const snapshot = await db.collection('reels')
      .where('groupId', '==', req.params.id)
      .get();

    const reels = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    reels.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    res.json({ reels });
  } catch (error) {
    console.error('Group reels error:', error);
    res.status(500).json({ error: 'Failed to load group reels' });
  }
});

// PUT /api/groups/:id - Update group
router.put('/:id', verifyToken, async (req, res) => {
  try {
    const doc = await db.collection('groups').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Group not found' });
    if (doc.data().userId !== req.user.uid) return res.status(403).json({ error: 'Not authorized' });

    const updates = {};
    if (req.body.name) updates.name = req.body.name.trim();
    if (req.body.description !== undefined) updates.description = req.body.description.trim();

    await db.collection('groups').doc(req.params.id).update(updates);
    res.json({ id: req.params.id, ...doc.data(), ...updates });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update group' });
  }
});

// DELETE /api/groups/:id - Delete group
router.delete('/:id', verifyToken, async (req, res) => {
  try {
    const doc = await db.collection('groups').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Group not found' });
    if (doc.data().userId !== req.user.uid) return res.status(403).json({ error: 'Not authorized' });

    // Unlink reels from group (don't delete them)
    const reelsSnapshot = await db.collection('reels')
      .where('groupId', '==', req.params.id)
      .get();

    const batch = db.batch();
    reelsSnapshot.docs.forEach(reelDoc => {
      batch.update(reelDoc.ref, { groupId: '' });
    });
    batch.delete(db.collection('groups').doc(req.params.id));
    await batch.commit();

    res.json({ deleted: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete group' });
  }
});

module.exports = router;
