import { Router } from 'express';
import { admin, firestore } from '../config/firebase';
import { authenticate, AuthenticatedRequest } from '../middleware/auth';
import { logger } from '../utils/logger';

const router = Router();

router.post('/requests/:requestId/retry', authenticate, async (req: AuthenticatedRequest, res) => {
  const { requestId } = req.params;
  const context = { requestId, uid: req.uid ?? 'unknown' };
  logger.info('Retry request received', context);

  try {
    const docRef = firestore.collection('requests').doc(requestId);
    const doc = await docRef.get();

    if (!doc.exists) {
      logger.warn('Retry request missing document', context);
      return res.status(404).json({ error: { code: 'REQUEST_NOT_FOUND', message: 'Request not found' } });
    }

    const data = doc.data();
    if (!data) {
      logger.warn('Retry request document empty', context);
      return res.status(404).json({ error: { code: 'REQUEST_NOT_FOUND', message: 'Request not found' } });
    }

    if (data.owner_user_id !== req.uid) {
      logger.warn('Retry request forbidden', context);
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Request does not belong to you' } });
    }

    if (data.status !== 'error') {
      logger.warn('Retry request invalid status', { ...context, status: data.status });
      return res.status(400).json({ error: { code: 'INVALID_STATUS', message: 'Request is not in error status' } });
    }

    await docRef.update({
      status: 'pending',
      error_message: admin.firestore.FieldValue.delete(),
      error_code: admin.firestore.FieldValue.delete(),
      updated_at: new Date().toISOString(),
    });

    logger.info('Retry request queued', context);
    return res.json({ success: true, request_id: requestId, new_status: 'pending' });
  } catch (error) {
    logger.error('Retry request failed', { ...context, error: error instanceof Error ? error.message : error });
    return res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Retry failed. Please try again later.' } });
  }
});

export default router;
