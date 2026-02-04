export class AudioSegmenter {
  static splitText(text: string, maxChars = 1000) {
    const cleaned = text.trim();
    if (cleaned.length == 0) return [''];

    const segments: string[] = [];
    let offset = 0;
    while (offset < cleaned.length) {
      const end = Math.min(offset + maxChars, cleaned.length);
      segments.push(cleaned.slice(offset, end));
      offset = end;
    }
    return segments;
  }
}
