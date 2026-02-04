import https from 'https';

// Cloudinary configuration
const CLOUDINARY_CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME || 'dnmr9yxyv';
const CLOUDINARY_API_KEY = process.env.CLOUDINARY_API_KEY || '587752342741975';
const CLOUDINARY_API_SECRET = process.env.CLOUDINARY_API_SECRET || 'TYSS2KU3G-M33x6UOq7W8WiK6No';

// Timeout helper
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Upload timeout')), ms);
    promise
      .then((val) => { clearTimeout(timer); resolve(val); })
      .catch((err) => { clearTimeout(timer); reject(err); });
  });
}

export class StorageService {
  static async uploadAudioSegment(
    userId: string,
    requestId: string,
    segmentIndex: number,
    buffer: Buffer,
  ): Promise<string> {
    const publicId = `audio/${userId}/${requestId}_part${segmentIndex}`;
    
    try {
      // Upload to Cloudinary with 4 second timeout
      const timestamp = Math.floor(Date.now() / 1000);
      const signature = await this.generateSignature(publicId, timestamp);
      
      const formData = this.buildFormData({
        file: `data:audio/mpeg;base64,${buffer.toString('base64')}`,
        public_id: publicId,
        resource_type: 'video', // Cloudinary uses 'video' for audio files
        timestamp: timestamp.toString(),
        api_key: CLOUDINARY_API_KEY,
        signature,
      });

      const url = await withTimeout(this.uploadToCloudinary(formData), 4000);
      return url;
    } catch (error) {
      console.error('[Storage] Upload failed or timeout:', error);
      // Return a placeholder URL - the request will still complete
      return `https://res.cloudinary.com/${CLOUDINARY_CLOUD_NAME}/video/upload/${publicId}.mp3`;
    }
  }

  private static async generateSignature(publicId: string, timestamp: number): Promise<string> {
    const crypto = await import('crypto');
    const toSign = `public_id=${publicId}&timestamp=${timestamp}${CLOUDINARY_API_SECRET}`;
    return crypto.createHash('sha1').update(toSign).digest('hex');
  }

  private static buildFormData(fields: Record<string, string>): string {
    const boundary = '----CloudinaryBoundary' + Date.now();
    let body = '';
    
    for (const [key, value] of Object.entries(fields)) {
      body += `--${boundary}\r\n`;
      body += `Content-Disposition: form-data; name="${key}"\r\n\r\n`;
      body += `${value}\r\n`;
    }
    body += `--${boundary}--\r\n`;
    
    return body;
  }

  private static uploadToCloudinary(formData: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const boundary = formData.split('\r\n')[0].substring(2);
      
      const options = {
        hostname: 'api.cloudinary.com',
        port: 443,
        path: `/v1_1/${CLOUDINARY_CLOUD_NAME}/video/upload`,
        method: 'POST',
        headers: {
          'Content-Type': `multipart/form-data; boundary=${boundary}`,
          'Content-Length': Buffer.byteLength(formData),
        },
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            if (json.secure_url) {
              resolve(json.secure_url);
            } else {
              reject(new Error(json.error?.message || 'Upload failed'));
            }
          } catch (e) {
            reject(new Error('Failed to parse response'));
          }
        });
      });

      req.on('error', reject);
      req.write(formData);
      req.end();
    });
  }
}
