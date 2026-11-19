export interface Advertiser {
  id: string;
  name: string;
  contact_email: string;
  phone?: string;
  created_at: string;
  updated_at: string;
}

export interface DayPartingSchedule {
  days_of_week: number[]; // 0=Sunday, 1=Monday, ... 6=Saturday
  start_time: string;     // "08:00:00"
  end_time: string;       // "22:00:00"
}

export interface MediaAsset {
  id: string;
  campaign_id: string;
  name: string;
  media_type: 'VIDEO_MP4' | 'IMAGE_PNG' | 'IMAGE_JPEG';
  file_size_bytes: number;
  duration_seconds: number;
  sha256_checksum: string;
  storage_url: string;
  r2_purge_at?: string;
}

export interface Campaign {
  id: string;
  advertiser_id: string;
  name: string;
  status: 'DRAFT' | 'APPROVED' | 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'ARCHIVED';
  flight_start_date: string; // ISO 8601
  flight_end_date: string;   // ISO 8601
  target_screens?: string[]; // Screen IDs or empty for all
  share_of_voice_percent?: number;
  dayparting?: DayPartingSchedule[];
  assets: MediaAsset[];
  created_at: string;
  updated_at: string;
}

export interface PlaylistItem {
  asset_id: string;
  campaign_id: string;
  url: string;
  sha256: string;
  duration_seconds: number;
  media_type: 'VIDEO_MP4' | 'IMAGE_PNG' | 'IMAGE_JPEG';
  audio_mode?: 'MUTED' | 'NORMAL' | 'SCHEDULED';
  valid_from?: string;
  valid_until?: string;
}

export interface SyncManifest {
  manifest_version: string; // SHA-256 hash or version tag
  generated_at: string;
  screen_id: string;
  tenant_id: string;
  fallback_mode: 'HOUSE_AD' | 'STATIC_GRAPHIC' | 'BLACK_SCREEN';
  loop_duration_target_seconds: number;
  playlist: PlaylistItem[];
  assets_to_download: {
    asset_id: string;
    url: string;
    sha256: string;
    file_size_bytes: number;
  }[];
  assets_to_purge: string[];
}

export interface ProofOfPlayRecord {
  campaign_id: string;
  asset_id: string;
  date: string; // YYYY-MM-DD
  completed_impressions: number;
  total_seconds_played: number;
  interrupted_impressions: number;
}

export interface PlaybackReportBatch {
  screen_id: string;
  batch_timestamp: string;
  records: ProofOfPlayRecord[];
}
