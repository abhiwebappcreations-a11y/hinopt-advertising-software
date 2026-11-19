import test from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../dist/services/db.js';
import { compileSyncManifest } from '../dist/services/manifestCompiler.js';

test('Zero Demo Data Invariant: initial store has 0 advertisers and 0 campaigns', async () => {
  const advs = await db.getAdvertisers();
  assert.equal(advs.length, 0, 'Must have zero pre-seeded advertisers');

  const camps = await db.getCampaigns();
  assert.equal(camps.length, 0, 'Must have zero pre-seeded campaigns');
});

test('Manifest compilation with active campaign', async () => {
  const adv = await db.createAdvertiser({
    name: 'Local Hyd Retailer',
    contact_email: 'retail@hyderabad.in'
  });

  const now = new Date();
  const nextMonth = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

  const campaign = await db.saveCampaign({
    id: 'camp-test-1',
    advertiser_id: adv.id,
    name: 'Hyd Mega Sale',
    status: 'ACTIVE',
    flight_start_date: now.toISOString(),
    flight_end_date: nextMonth.toISOString(),
    assets: [
      {
        id: 'asset-1',
        campaign_id: 'camp-test-1',
        name: 'sale_1080p.mp4',
        media_type: 'VIDEO_MP4',
        file_size_bytes: 14200000,
        duration_seconds: 15,
        sha256_checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        storage_url: 'https://cdn.hinopt.com/media/sale_1080p.mp4'
      }
    ],
    created_at: now.toISOString(),
    updated_at: now.toISOString()
  });

  const manifest = compileSyncManifest('screen-auto-01', 'tenant-test', [campaign]);
  assert.equal(manifest.playlist.length, 1);
  assert.equal(manifest.playlist[0].asset_id, 'asset-1');
  assert.ok(manifest.manifest_version.startsWith('v-'), 'Manifest version must be hashed');

  // Test Proof-of-Play recording
  const recorded = await db.recordProofOfPlay('screen-auto-01', [
    {
      campaign_id: 'camp-test-1',
      asset_id: 'asset-1',
      date: '2026-11-19',
      completed_impressions: 48,
      total_seconds_played: 720,
      interrupted_impressions: 0
    }
  ]);
  assert.equal(recorded, 1);
});
