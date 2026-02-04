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

// Process a specific request (called by app after creating a request)
router.post('/requests/:requestId/process', authenticate, async (req: AuthenticatedRequest, res) => {
  const { requestId } = req.params;
  const context = { requestId, uid: req.uid ?? 'unknown' };
  logger.info('Process request received', context);

  try {
    const docRef = firestore.collection('requests').doc(requestId);
    const doc = await docRef.get();

    if (!doc.exists) {
      logger.warn('Process request missing document', context);
      return res.status(404).json({ error: { code: 'REQUEST_NOT_FOUND', message: 'Request not found' } });
    }

    const data = doc.data();
    if (!data) {
      logger.warn('Process request document empty', context);
      return res.status(404).json({ error: { code: 'REQUEST_NOT_FOUND', message: 'Request not found' } });
    }

    if (data.owner_user_id !== req.uid) {
      logger.warn('Process request forbidden', context);
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Request does not belong to you' } });
    }

    if (data.status !== 'pending') {
      logger.warn('Process request invalid status', { ...context, status: data.status });
      return res.status(400).json({ error: { code: 'INVALID_STATUS', message: 'Request is not pending' } });
    }

    // Import processing dependencies
    const { OCRService } = await import('../services/ocr.service');
    const { TTSService } = await import('../services/tts.service');
    const { StorageService } = await import('../services/storage.service');
    const { AudioSegmenter } = await import('../utils/audio-segmenter');
    const { RequestService } = await import('../services/request.service');
    
    const requestService = new RequestService();

    // Mark as processing
    await requestService.markProcessing(requestId);
    
    // Send immediate response - processing will continue
    res.json({ success: true, request_id: requestId, status: 'processing' });

    // Process the request
    try {
      const { text, length } = await OCRService.extractText(data.image_url);
      const normalizedText = text.length === 0 ? 'No text detected in image' : text;
      const segments = AudioSegmenter.splitText(normalizedText);
      const audioUrls: string[] = [];

      for (let index = 0; index < segments.length; index++) {
        const segmentText = segments[index];
        const buffer = await TTSService.synthesizeText(segmentText);
        const url = await StorageService.uploadAudioSegment(data.owner_user_id, requestId, index + 1, buffer);
        audioUrls.push(url);
      }

      await requestService.markCompleted(requestId, audioUrls, segments.length, length);
      logger.info('Processing request completed', { requestId, segments: segments.length });
    } catch (processError) {
      logger.error('Processing failed', { requestId, error: processError instanceof Error ? processError.message : processError });
      await requestService.markError(requestId, 'Processing failed', 'PROCESSING_ERROR');
    }
  } catch (error) {
    logger.error('Process request failed', { ...context, error: error instanceof Error ? error.message : error });
    return res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Process failed. Please try again later.' } });
  }
});

export default router;
