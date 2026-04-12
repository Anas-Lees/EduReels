const { auth } = require('../config/firebase');

async function verifyToken(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = header.split('Bearer ')[1];
  if (!token) {
    return res.status(401).json({ error: 'Malformed authorization header' });
  }
  try {
    const decoded = await auth.verifyIdToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    console.error('Auth error:', error.message);
    return res.status(401).json({ error: 'Invalid token' });
  }
}

module.exports = { verifyToken };
