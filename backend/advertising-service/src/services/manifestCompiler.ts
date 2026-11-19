import crypto from 'crypto';
import { Campaign, SyncManifest, PlaylistItem, DayPartingSchedule } from '../types.js';

export function isCampaignActive(campaign: Campaign, targetDate: Date = new Date()): boolean {
  if (campaign.status !== 'ACTIVE' && campaign.status !== 'APPROVED') return false;

  const start = new Date(campaign.flight_start_date).getTime();
  const end = new Date(campaign.flight_end_date).getTime();
  const current = targetDate.getTime();

  return current >= start && current <= end;
}

export function isDayPartingActive(dayparting: DayPartingSchedule[] | undefined, targetDate: Date = new Date()): boolean {
  if (!dayparting || dayparting.length === 0) return true; // 24/7 if unspecified

  const dayOfWeek = targetDate.getDay(); // 0 = Sunday
  const hours = String(targetDate.getHours()).padStart(2, '0');
  const minutes = String(targetDate.getMinutes()).padStart(2, '0');
  const seconds = String(targetDate.getSeconds()).padStart(2, '0');
  const currentTimeStr = `${hours}:${minutes}:${seconds}`;

  for (const rule of dayparting) {
    if (rule.days_of_week.includes(dayOfWeek)) {
      if (currentTimeStr >= rule.start_time && currentTimeStr <= rule.end_time) {
        return true;
      }
    }
  }

  return false;
}

/**
 * Compiles a deterministic manifest for a specific screen based on active campaigns.
 */
export function compileSyncManifest(
  screenId: string,
  tenantId: string,
  campaigns: Campaign[],
  targetDate: Date = new Date()
): SyncManifest {
  const eligibleCampaigns = campaigns.filter(c => {
    // Screen target filter
    if (c.target_screens && c.target_screens.length > 0 && !c.target_screens.includes(screenId)) {
      return false;
    }
    return isCampaignActive(c, targetDate) && isDayPartingActive(c.dayparting, targetDate);
  });

  const playlist: PlaylistItem[] = [];
  const assetsToDownload: SyncManifest['assets_to_download'] = [];

  // Build playlist items
  for (const camp of eligibleCampaigns) {
    for (const asset of camp.assets) {
      playlist.push({
        asset_id: asset.id,
        campaign_id: camp.id,
        url: asset.storage_url,
        sha256: asset.sha256_checksum,
        duration_seconds: asset.duration_seconds || 15,
        media_type: asset.media_type,
        audio_mode: 'MUTED',
        valid_from: camp.flight_start_date,
        valid_until: camp.flight_end_date
      });

      assetsToDownload.push({
        asset_id: asset.id,
        url: asset.storage_url,
        sha256: asset.sha256_checksum,
        file_size_bytes: asset.file_size_bytes
      });
    }
  }

  // Calculate deterministic SHA-256 version hash from playlist content
  const playlistPayload = JSON.stringify(playlist);
  const hash = crypto.createHash('sha256').update(playlistPayload).digest('hex').substring(0, 16);
  const manifestVersion = `v-${hash}`;

  return {
    manifest_version: manifestVersion,
    generated_at: new Date().toISOString(),
    screen_id: screenId,
    tenant_id: tenantId,
    fallback_mode: 'HOUSE_AD',
    loop_duration_target_seconds: 120, // 2-minute loop standard
    playlist,
    assets_to_download: assetsToDownload,
    assets_to_purge: []
  };
}
