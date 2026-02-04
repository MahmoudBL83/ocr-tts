import { DocumentSnapshot } from 'firebase-admin/firestore';
import { firestore } from '../config/firebase';
import { processingRequestFromDoc } from '../models/request.model';
import { AudioSegmenter } from '../utils/audio-segmenter';
import { logger } from '../utils/logger';
import { OCRService } from '../services/ocr.service';
import { RequestService } from '../services/request.service';
import { StorageService } from '../services/storage.service';
import { TTSService } from '../services/tts.service';

export class ProcessingWorker {
  private readonly requestService = new RequestService();
  private readonly isProcessing = new Set<string>();
  private unsubscribe?: () => void;

  start() {
    this.unsubscribe = firestore
      .collection('requests')
      .where('status', '==', 'pending')
      .orderBy('created_at')
      .onSnapshot((snapshot) => {
        snapshot.docChanges().forEach((change) => {
          if (change.type === 'added') {
            void this.handleRequest(change.doc);
          }
        });
      });
    logger.info('Processing worker started');
  }

  stop() {
    this.unsubscribe?.();
  }

  private async handleRequest(doc: DocumentSnapshot) {
    const requestId = doc.id;
    if (this.isProcessing.has(requestId)) return;
    this.isProcessing.add(requestId);

    logger.info('Processing request picked up', { requestId });
    try {
      const data = processingRequestFromDoc(doc);
      await this.requestService.markProcessing(requestId);

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

      await this.requestService.markCompleted(requestId, audioUrls, segments.length, length);
      logger.info('Processing request completed', { requestId, segments: segments.length });
    } catch (error) {
      logger.error('Processing worker failed', { requestId, error: error instanceof Error ? error.message : error });
      await this.requestService.markError(requestId, 'Processing failed', 'PROCESSING_ERROR');
    } finally {
      this.isProcessing.delete(requestId);
    }
  }
}
