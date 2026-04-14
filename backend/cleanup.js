require('dotenv').config();
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET
});

const db = admin.firestore();

async function cleanup() {
  // Delete all reels
  const reels = await db.collection('reels').get();
  const batch1 = [];
  reels.forEach(doc => batch1.push(doc.ref.delete()));
  await Promise.all(batch1);
  console.log(`Deleted ${reels.size} reels`);

  // Delete all groups
  const groups = await db.collection('groups').get();
  const batch2 = [];
  groups.forEach(doc => batch2.push(doc.ref.delete()));
  await Promise.all(batch2);
  console.log(`Deleted ${groups.size} groups`);

  console.log('Cleanup complete!');
  process.exit(0);
}

cleanup().catch(e => { console.error(e); process.exit(1); });
