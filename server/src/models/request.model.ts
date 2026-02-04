import type { DocumentSnapshot } from 'firebase-admin/firestore';

export type ProcessingStatus = 'pending' | 'processing' | 'completed' | 'delivered' | 'error';

export interface ProcessingRequestModel {
  request_id: string;
  owner_user_id: string;
  target_device_id: string;
  status: ProcessingStatus;
  created_at: string;
  updated_at?: string;
  image_url: string;
  image_size_bytes?: number;
  audio_urls?: string[];
  segment_count?: number;
  extracted_text_length?: number;
  processing_started_at?: string;
  processing_completed_at?: string;
  delivered_at?: string;
  error_message?: string;
  error_code?: string;
}

export const processingRequestFromDoc = (doc: DocumentSnapshot): ProcessingRequestModel => {
  const data = doc.data();
  if (!data) throw new Error('Processing request missing data');
  return {
    request_id: doc.id,
    owner_user_id: data.owner_user_id,
    target_device_id: data.target_device_id,
    status: data.status,
    created_at: data.created_at,
    updated_at: data.updated_at,
    image_url: data.image_url,
    image_size_bytes: data.image_size_bytes,
    audio_urls: data.audio_urls,
    segment_count: data.segment_count,
    extracted_text_length: data.extracted_text_length,
    processing_started_at: data.processing_started_at,
    processing_completed_at: data.processing_completed_at,
    delivered_at: data.delivered_at,
    error_message: data.error_message,
    error_code: data.error_code,
  };
};
