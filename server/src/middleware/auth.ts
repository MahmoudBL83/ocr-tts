import { Request, Response, NextFunction } from 'express';
import { admin } from '../config/firebase';

export interface AuthenticatedRequest extends Request {
  uid?: string;
  claims?: admin.auth.DecodedIdToken;
}

export const authenticate = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Missing authorization header' } });
  }

  const token = header.split(' ')[1];

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.uid = decoded.uid;
    req.claims = decoded;
    return next();
  } catch (error) {
    console.error('Auth middleware error', error);
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } });
  }
};
