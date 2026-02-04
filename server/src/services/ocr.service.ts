import vision from '@google-cloud/vision';

const client = new vision.ImageAnnotatorClient();

export class OCRService {
  static async extractText(imageUrl: string) {
    const [result] = await client.documentTextDetection({
      image: {
        source: { imageUri: imageUrl },
      },
    });

    const text = result.fullTextAnnotation?.text?.trim() ?? '';
    return {
      text,
      length: text.length,
    };
  }
}
