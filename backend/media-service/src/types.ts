export interface UploadRequest {
  campaign_id: string;
  name: string;
  media_type: 'VIDEO_MP4' | 'IMAGE_PNG' | 'IMAGE_JPEG';
  file_size_bytes: number;
  duration_seconds: number;
  width?: number;
  height?: number;
}

export interface UploadResponse {
  asset_id: string;
  upload_url: string;
  destination_key: string;
  expires_in_seconds: number;
  headers_required: Record<string, string>;
}

export interface ConfirmUploadRequest {
  asset_id: string;
  sha256_checksum: string;
  campaign_flight_end_date?: string; // Used to calculate r2_purge_at = flight_end_date + 3 days
}

export interface MediaAssetMetadata {
  id: string;
  campaign_id: string;
  name: string;
  media_type: 'VIDEO_MP4' | 'IMAGE_PNG' | 'IMAGE_JPEG';
  file_size_bytes: number;
  duration_seconds: number;
  width: number;
  height: number;
  sha256_checksum: string;
  cdn_url: string;
  status: 'PENDING_UPLOAD' | 'AVAILABLE' | 'PURGED';
  r2_purge_at?: string;
  created_at: string;
}
