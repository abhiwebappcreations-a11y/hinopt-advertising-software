const ADS_API_URL = 'http://localhost:8082/v1';
const MEDIA_API_URL = 'http://localhost:8083/v1';

export interface Advertiser {
  id: string;
  name: string;
  contact_email: string;
  phone?: string;
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
}

export interface Campaign {
  id: string;
  advertiser_id: string;
  name: string;
  status: 'ACTIVE' | 'PAUSED' | 'COMPLETED';
  flight_start_date: string;
  flight_end_date: string;
  share_of_voice_percent?: number;
  assets: MediaAsset[];
}

export interface ProofOfPlaySummary {
  total_impressions: number;
  total_seconds_played: number;
  interrupted_impressions: number;
  record_count: number;
}

export async function fetchCampaigns(): Promise<Campaign[]> {
  try {
    const res = await fetch(`${ADS_API_URL}/campaigns`);
    if (!res.ok) return [];
    const data = await res.json();
    return data.campaigns || [];
  } catch {
    return [];
  }
}

export async function fetchAdvertisers(): Promise<Advertiser[]> {
  try {
    const res = await fetch(`${ADS_API_URL}/advertisers`);
    if (!res.ok) return [];
    const data = await res.json();
    return data.advertisers || [];
  } catch {
    return [];
  }
}

export async function createAdvertiser(adv: { name: string; contact_email: string; phone?: string }): Promise<Advertiser | null> {
  const res = await fetch(`${ADS_API_URL}/advertisers`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(adv)
  });
  if (!res.ok) return null;
  return res.json();
}

export async function createCampaign(camp: {
  advertiser_id: string;
  name: string;
  flight_start_date: string;
  flight_end_date: string;
  share_of_voice_percent?: number;
  assets?: MediaAsset[];
}): Promise<Campaign | null> {
  const res = await fetch(`${ADS_API_URL}/campaigns`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(camp)
  });
  if (!res.ok) return null;
  return res.json();
}

export async function fetchAnalytics(): Promise<ProofOfPlaySummary> {
  try {
    const res = await fetch(`${ADS_API_URL}/analytics/proof-of-play`);
    if (!res.ok) {
      return { total_impressions: 0, total_seconds_played: 0, interrupted_impressions: 0, record_count: 0 };
    }
    return res.json();
  } catch {
    return { total_impressions: 0, total_seconds_played: 0, interrupted_impressions: 0, record_count: 0 };
  }
}
