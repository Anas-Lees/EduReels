const admin = require('firebase-admin');

// Try loading credentials in order: env var (for cloud deploy) > local file > default
let serviceAccount;

if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  // For cloud deployment: pass the entire JSON as an env var
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  try {
    serviceAccount = require('../../serviceAccountKey.json');
  } catch (e) {
    console.log('No serviceAccountKey.json found, using default credentials');
  }
}

if (serviceAccount) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  });
} else {
  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID,
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  });
}

const db = admin.firestore();
const storage = admin.storage();
const auth = admin.auth();

module.exports = { admin, db, storage, auth };
