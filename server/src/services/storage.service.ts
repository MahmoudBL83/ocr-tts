import { admin } from '../config/firebase';

const bucket = admin.storage().bucket();

export class StorageService {
  static async uploadAudioSegment(
    userId: string,
    requestId: string,
    segmentIndex: number,
    buffer: Buffer,
  ): Promise<string> {
    const path = `audio/${userId}/${requestId}_part${segmentIndex}.mp3`;
    const file = bucket.file(path);
    await file.save(buffer, { contentType: 'audio/mpeg' });
    const [url] = await file.getSignedUrl({ action: 'read', expires: '2491-01-01' });
    return url;
  }
}
