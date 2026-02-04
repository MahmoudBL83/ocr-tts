import admin from 'firebase-admin';
import * as fs from 'fs';

if (!admin.apps.length) {
  // For Vercel: Use JSON credentials from environment variable
  // For local: Use application default credentials or service account file
  let credential: admin.credential.Credential;

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON) {
    // Vercel deployment: Parse JSON from environment variable
    const serviceAccount = JSON.parse(process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON);
    credential = admin.credential.cert(serviceAccount);
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const credValue = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    
    // Check if it's JSON content (starts with {) or a file path
    if (credValue.trim().startsWith('{')) {
      // It's JSON content, parse it directly
      const serviceAccount = JSON.parse(credValue);
      credential = admin.credential.cert(serviceAccount);
    } else if (fs.existsSync(credValue)) {
      // It's a file path, read and parse
      const serviceAccount = JSON.parse(fs.readFileSync(credValue, 'utf8'));
      credential = admin.credential.cert(serviceAccount);
    } else {
      throw new Error(`Cannot find credentials file: ${credValue}`);
    }
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
