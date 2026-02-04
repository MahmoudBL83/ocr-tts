import { Router } from 'express';

const router = Router();

router.get('/health', (_req, res) => {
  res.json({ status: 'healthy', version: '0.1.0', timestamp: new Date().toISOString() });
});

export default router;
