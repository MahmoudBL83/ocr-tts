import vision from '@google-cloud/vision';

const client = new vision.ImageAnnotatorClient();

// Timeout helper
function withTimeout<T>(promise: Promise<T>, ms: number, fallback: T): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((resolve) => setTimeout(() => resolve(fallback), ms))
  ]);
}

export class OCRService {
  static async extractText(imageUrl: string) {
    try {
      // Try OCR with 6 second timeout (leave room for TTS)
      const result = await withTimeout(
        client.documentTextDetection({
          image: {
            source: { imageUri: imageUrl },
          },
        }),
        6000,
        null // fallback value
      );

      if (result) {
        const text = result[0]?.fullTextAnnotation?.text?.trim() ?? '';
        if (text.length > 0) {
          return { text, length: text.length };
        }
      }
      
      // OCR timed out or returned empty - use fallback
      console.log('[OCR] Timeout or empty result, using fallback text');
      const fallbackText = 'Image received successfully. Text extraction is temporarily unavailable. Please try again later.';
      return { text: fallbackText, length: fallbackText.length };
      
    } catch (error) {
      console.error('[OCR] Error:', error);
      const fallbackText = 'Unable to extract text from image. Please ensure the image contains readable text.';
      return { text: fallbackText, length: fallbackText.length };
    }
  }
}
