import { firestore } from '../config/firebase';

export class RequestService {
  private readonly requests = firestore.collection('requests');

  async markProcessing(requestId: string) {
    const now = new Date().toISOString();
    await this.requests.doc(requestId).set(
      {
        status: 'processing',
        processing_started_at: now,
        updated_at: now,
      },
      { merge: true },
    );
  }

  async markCompleted(
    requestId: string,
    audioUrls: string[],
    segmentCount: number,
    extractedTextLength: number,
  ) {
    const now = new Date().toISOString();
    await this.requests.doc(requestId).set(
      {
        status: 'completed',
        processing_completed_at: now,
        updated_at: now,
        audio_urls: audioUrls,
        segment_count: segmentCount,
        extracted_text_length: extractedTextLength,
      },
      { merge: true },
    );
  }

  async markError(requestId: string, message: string, code: string) {
    const now = new Date().toISOString();
    await this.requests.doc(requestId).set(
      {
        status: 'error',
        error_message: message,
        error_code: code,
        updated_at: now,
      },
      { merge: true },
    );
  }

  async resetToPending(requestId: string) {
    const now = new Date().toISOString();
    await this.requests.doc(requestId).set(
      {
        status: 'pending',
        updated_at: now,
      },
      { merge: true },
    );
  }
}
