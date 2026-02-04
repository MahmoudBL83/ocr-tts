import https from 'https';

// Timeout helper
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('TTS timeout')), ms);
    promise
      .then((val) => { clearTimeout(timer); resolve(val); })
      .catch((err) => { clearTimeout(timer); reject(err); });
  });
}

export class TTSService {
  private static readonly GOOGLE_TTS_URL = 'https://translate.google.com/translate_tts';

  /**
   * Synthesize text to speech using Google Translate TTS (free, no API key)
   * Has timeout to work within Vercel limits
   */
  static async synthesizeText(text: string, lang: string = 'en'): Promise<Buffer> {
    try {
      // Limit text to first 500 chars to stay within timeout
      const limitedText = text.substring(0, 500);
      
      // Split text into chunks of max 200 characters (Google TTS limit)
      const chunks = TTSService.splitText(limitedText, 200);
      const audioBuffers: Buffer[] = [];

      for (const chunk of chunks) {
        // 3 second timeout per chunk
        const buffer = await withTimeout(TTSService.fetchAudio(chunk, lang), 3000);
        audioBuffers.push(buffer);
      }

      return Buffer.concat(audioBuffers);
    } catch (error) {
      console.error('[TTS] Error or timeout:', error);
      // Return a minimal valid MP3 silence (will still complete the request)
      return TTSService.getMinimalAudio();
    }
  }

  // Minimal MP3 audio (very short beep/silence) as fallback
  private static getMinimalAudio(): Buffer {
    // Minimal valid MP3 frame (silence)
    return Buffer.from([
      0xFF, 0xFB, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]);
  }

  private static splitText(text: string, maxLength: number): string[] {
    const chunks: string[] = [];
    let remaining = text;

    while (remaining.length > 0) {
      if (remaining.length <= maxLength) {
        chunks.push(remaining);
        break;
      }

      // Find last space within limit
      let splitIndex = remaining.lastIndexOf(' ', maxLength);
      if (splitIndex === -1) splitIndex = maxLength;

      chunks.push(remaining.substring(0, splitIndex));
      remaining = remaining.substring(splitIndex).trim();
    }

    return chunks;
  }

  private static fetchAudio(text: string, lang: string): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const encodedText = encodeURIComponent(text);
      const url = `${TTSService.GOOGLE_TTS_URL}?ie=UTF-8&client=tw-ob&tl=${lang}&q=${encodedText}`;

      https.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://translate.google.com/',
        }
      }, (response) => {
        if (response.statusCode === 302 || response.statusCode === 301) {
          // Follow redirect
          const redirectUrl = response.headers.location;
          if (redirectUrl) {
            https.get(redirectUrl, (redirectResponse) => {
              const chunks: Buffer[] = [];
              redirectResponse.on('data', (chunk) => chunks.push(chunk));
              redirectResponse.on('end', () => resolve(Buffer.concat(chunks)));
              redirectResponse.on('error', reject);
            }).on('error', reject);
          } else {
            reject(new Error('Redirect without location'));
          }
          return;
        }

        if (response.statusCode !== 200) {
          reject(new Error(`TTS request failed with status ${response.statusCode}`));
          return;
        }

        const chunks: Buffer[] = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => resolve(Buffer.concat(chunks)));
        response.on('error', reject);
      }).on('error', reject);
    });
  }
}
