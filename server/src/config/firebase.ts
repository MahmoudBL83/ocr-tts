import admin from 'firebase-admin';
import * as fs from 'fs';

if (!admin.apps.length) {
  // For Vercel: Use JSON credentials from environment variable
  // For local: Use application default credentials or service account file
  let credential: admin.credential.Credential;

  // Check all possible credential sources
  const jsonCreds = process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON;
  const pathCreds = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const firebaseCreds = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  console.log('[Firebase] Credential sources:', {
    hasJsonCreds: !!jsonCreds,
    hasPathCreds: !!pathCreds,
    hasFirebaseCreds: !!firebaseCreds,
    jsonCredsLength: jsonCreds?.length || 0,
  });

  if (jsonCreds && jsonCreds.trim().startsWith('{')) {
    // Vercel deployment: Parse JSON from environment variable
    console.log('[Firebase] Using GOOGLE_APPLICATION_CREDENTIALS_JSON');
    const serviceAccount = JSON.parse(jsonCreds);
    credential = admin.credential.cert(serviceAccount);
  } else if (firebaseCreds && firebaseCreds.trim().startsWith('{')) {
    // Alternative env var name
    console.log('[Firebase] Using FIREBASE_SERVICE_ACCOUNT_JSON');
    const serviceAccount = JSON.parse(firebaseCreds);
    credential = admin.credential.cert(serviceAccount);
  } else if (pathCreds) {
    const credValue = pathCreds;
    
    // Check if it's JSON content (starts with {) or a file path
    if (credValue.trim().startsWith('{')) {
      // It's JSON content, parse it directly
      console.log('[Firebase] Using GOOGLE_APPLICATION_CREDENTIALS as JSON');
      const serviceAccount = JSON.parse(credValue);
      credential = admin.credential.cert(serviceAccount);
    } else if (fs.existsSync(credValue)) {
      // It's a file path, read and parse
      console.log('[Firebase] Using GOOGLE_APPLICATION_CREDENTIALS as file path');
      const serviceAccount = JSON.parse(fs.readFileSync(credValue, 'utf8'));
      credential = admin.credential.cert(serviceAccount);
    } else {
      throw new Error(`Cannot find credentials file: ${credValue}`);
    }
  } else {
    // No credentials found - fail with clear message
    throw new Error(
      'No Firebase credentials found. Set GOOGLE_APPLICATION_CREDENTIALS_JSON or FIREBASE_SERVICE_ACCOUNT_JSON environment variable with the service account JSON.'
    );
  }

  admin.initializeApp({
    credential,
    projectId: process.env.FIREBASE_PROJECT_ID || 'ocr-tts-ad7d6',
  });
  
  console.log('[Firebase] Admin SDK initialized successfully');
}

const firestore = admin.firestore();
export { admin, firestore };
