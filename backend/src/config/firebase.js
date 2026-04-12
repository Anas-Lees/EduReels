const admin = require('firebase-admin');

// Initialize with default credentials (set GOOGLE_APPLICATION_CREDENTIALS env var)
// Or download serviceAccountKey.json from Firebase Console
let serviceAccount;
try {
  serviceAccount = require('../../serviceAccountKey.json');
} catch (e) {
  console.log('No serviceAccountKey.json found, using default credentials');
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
