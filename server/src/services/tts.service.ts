import { tts, getVoices } from 'edge-tts';

export class TTSService {
  private static readonly DEFAULT_VOICE = 'en-US-AriaNeural'; // Free neural voice

  /**
   * Available voices (all free!):
   * - en-US-AriaNeural (female, natural)
   * - en-US-GuyNeural (male, natural)
   * - en-US-JennyNeural (female, friendly)
   * - en-GB-SoniaNeural (British female)
   * - en-AU-NatashaNeural (Australian female)
   * 
   * Use getAvailableVoices() to list all voices
   */
  static async synthesizeText(text: string, voice: string = TTSService.DEFAULT_VOICE): Promise<Buffer> {
    const audioBuffer = await tts(text, {
      voice,
      rate: '+0%',    // Normal speed
      pitch: '+0Hz',  // Normal pitch
      volume: '+0%',  // Normal volume
    });
    
    return audioBuffer;
  }

  /**
   * Get list of all available voices
   */
  static async getAvailableVoices() {
    return getVoices();
  }
}
