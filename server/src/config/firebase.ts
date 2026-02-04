import admin from 'firebase-admin';

if (!admin.apps.length) {
  // For Vercel: Use JSON credentials from environment variable
  // For local: Use application default credentials or service account file
  let credential: admin.credential.Credential;

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON) {
    // Vercel deployment: Parse JSON from environment variable
    const serviceAccount = JSON.parse(process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON);
    credential = admin.credential.cert(serviceAccount);
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    // Local development: Use service account file path
    const serviceAccount = require(process.env.GOOGLE_APPLICATION_CREDENTIALS);
    credential = admin.credential.cert(serviceAccount);
  } else {
    // Fallback to application default credentials
    credential = admin.credential.applicationDefault();
  }

  admin.initializeApp({
    credential,
    projectId: process.env.FIREBASE_PROJECT_ID || 'ocr-tts-ad7d6',
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET || 'ocr-tts-ad7d6.firebasestorage.app',
  });
}

const firestore = admin.firestore();
export { admin, firestore };
