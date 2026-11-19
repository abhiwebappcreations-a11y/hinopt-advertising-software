import test from 'node:test';
import assert from 'node:assert/strict';
import { storage } from '../dist/services/storage.js';

test('Media upload request and confirmation lifecycle', async () => {
  const upload = await storage.generateUploadUrl({
    campaign_id: 'camp-nike-1',
    name: 'nike_commercial_1080p.mp4',
    media_type: 'VIDEO_MP4',
    file_size_bytes: 25000000,
    duration_seconds: 15
  });

  assert.ok(upload.asset_id, 'Asset ID must be created');
  assert.ok(upload.upload_url, 'Upload URL must be generated');

  const pending = await storage.getAsset(upload.asset_id);
  assert.equal(pending?.status, 'PENDING_UPLOAD');

  // Confirm upload with flight end date + 3 days retention test
  const flightEnd = '2026-12-31T23:59:59Z';
  const confirmed = await storage.confirmUpload(
    upload.asset_id,
    'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
    flightEnd
  );

  assert.equal(confirmed?.status, 'AVAILABLE');
  assert.ok(confirmed?.r2_purge_at, 'r2_purge_at must be populated');

  // Verify purge date is exactly 3 days after flight end date
  const expectedPurgeTime = new Date(flightEnd).getTime() + 3 * 24 * 60 * 60 * 1000;
  assert.equal(new Date(confirmed.r2_purge_at).getTime(), expectedPurgeTime);
});
