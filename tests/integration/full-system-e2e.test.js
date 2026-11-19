import test from 'node:test';
import assert from 'node:assert/strict';

import { db as licensingDb } from '../../backend/licensing-service/dist/services/db.js';
import { signLicense, generateActivationCode } from '../../backend/licensing-service/dist/services/crypto.js';
import { db as adsDb } from '../../backend/advertising-service/dist/services/db.js';
import { compileSyncManifest } from '../../backend/advertising-service/dist/services/manifestCompiler.js';
import { storage } from '../../backend/media-service/dist/services/storage.js';

test('FULL END-TO-END SYSTEM INTEGRATION AUDIT (HINOPT + ADMOBITICS)', async (t) => {

  await t.test('1. Zero Demo Data Verification', async () => {
    const tenants = await licensingDb.getTenants();
    assert.equal(tenants.length, 0, 'Sovereign authority must start with 0 tenants');

    const screens = await licensingDb.getScreens();
    assert.equal(screens.length, 0, 'Sovereign authority must start with 0 screens');

    const advs = await adsDb.getAdvertisers();
    assert.equal(advs.length, 0, 'Advertising service must start with 0 advertisers');

    const camps = await adsDb.getCampaigns();
    assert.equal(camps.length, 0, 'Advertising service must start with 0 campaigns');
  });

  let tenantId = '';
  await t.test('2. Register Commercial Tenant (Admobitics)', async () => {
    const tenant = await licensingDb.createTenant({
      name: 'Admobitics Media Network',
      contact_email: 'operations@admobitics.com',
      max_screens: 10,
      status: 'ACTIVE'
    });
    assert.ok(tenant.id, 'Tenant ID must be created');
    assert.equal(tenant.name, 'Admobitics Media Network');
    tenantId = tenant.id;
  });

  const screenActivationCode = generateActivationCode();
  let screenId = '';
  await t.test('3. Pre-Authorize Auto Screen (Auto #01 HITEC City)', async () => {
    const expiry = new Date(Date.now() + 730 * 24 * 60 * 60 * 1000).toISOString();
    const preAuthScreen = await licensingDb.saveScreen({
      id: crypto.randomUUID(),
      tenant_id: tenantId,
      activation_code: screenActivationCode,
      enrollment_status: 'PRE_AUTHORIZED',
      screen_name: 'Auto #01 (HITEC City Loop)',
      hardware_model: 'TPC 151TCT',
      serial_number: 'TPC-2026-0042',
      license_tier: 'PRO',
      license_expires_at: expiry,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });

    assert.equal(preAuthScreen.enrollment_status, 'PRE_AUTHORIZED');
    screenId = preAuthScreen.id;
  });

  await t.test('4. Cryptographic Screen Enrollment & License Issuance', async () => {
    const screen = await licensingDb.getScreenByActivationCode(screenActivationCode);
    assert.ok(screen, 'Screen must be found by activation code');

    const { token, signature } = signLicense(screen.id, screen.tenant_id, screen.license_expires_at);
    assert.ok(token);
    assert.ok(signature);

    screen.enrollment_status = 'ACTIVE';
    screen.activation_code = undefined; // Consumed
    await licensingDb.saveScreen(screen);

    const activeScreen = await licensingDb.getScreenById(screenId);
    assert.equal(activeScreen?.enrollment_status, 'ACTIVE');
  });

  let campaignId = '';
  await t.test('5. Admobitics Books Commercial Campaign & Uploads Media to R2', async () => {
    const adv = await adsDb.createAdvertiser({
      name: 'Paradise Biryani Hyderabad',
      contact_email: 'marketing@paradisebiryani.in'
    });

    const upload = await storage.generateUploadUrl({
      campaign_id: 'pending-camp',
      name: 'paradise_special_1080p.mp4',
      media_type: 'VIDEO_MP4',
      file_size_bytes: 14500000,
      duration_seconds: 15
    });

    const flightEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    const confirmedAsset = await storage.confirmUpload(
      upload.asset_id,
      'b7f32095f9c636f8634e0499e28f3a3bf29f79e564940f959f63567b545d9e5f',
      flightEnd
    );
    assert.equal(confirmedAsset?.status, 'AVAILABLE');

    const campaign = await adsDb.saveCampaign({
      id: crypto.randomUUID(),
      advertiser_id: adv.id,
      name: 'Weekend Hyderabad Feast',
      status: 'ACTIVE',
      flight_start_date: new Date(Date.now() - 3600000).toISOString(),
      flight_end_date: flightEnd,
      share_of_voice_percent: 25,
      assets: [
        {
          id: confirmedAsset.id,
          campaign_id: 'will-update',
          name: confirmedAsset.name,
          media_type: confirmedAsset.media_type,
          file_size_bytes: confirmedAsset.file_size_bytes,
          duration_seconds: confirmedAsset.duration_seconds,
          sha256_checksum: confirmedAsset.sha256_checksum,
          storage_url: confirmedAsset.cdn_url,
          r2_purge_at: confirmedAsset.r2_purge_at
        }
      ],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });

    assert.ok(campaign.id);
    campaignId = campaign.id;
  });

  await t.test('6. Screen Sync Manifest Compilation & O(1) ETag Caching', async () => {
    const allCampaigns = await adsDb.getCampaigns();
    const manifest = compileSyncManifest(screenId, tenantId, allCampaigns);

    assert.equal(manifest.screen_id, screenId);
    assert.equal(manifest.playlist.length, 1);
    assert.ok(manifest.manifest_version.startsWith('v-'));

    // Second compilation with same campaigns must produce identical deterministic ETag
    const manifest2 = compileSyncManifest(screenId, tenantId, allCampaigns);
    assert.equal(manifest.manifest_version, manifest2.manifest_version, 'Deterministic ETag must match for 304 caching');
  });

  await t.test('7. Proof-of-Play Ingestion & Analytics Reconciliation', async () => {
    const recorded = await adsDb.recordProofOfPlay(screenId, [
      {
        campaign_id: campaignId,
        asset_id: 'asset-test-01',
        date: '2026-11-19',
        completed_impressions: 64,
        total_seconds_played: 960,
        interrupted_impressions: 2
      }
    ]);
    assert.equal(recorded, 1);

    const summaries = await adsDb.getProofOfPlaySummaries(campaignId);
    assert.equal(summaries.length, 1);
    assert.equal(summaries[0].completed_impressions, 64);
    assert.equal(summaries[0].total_seconds_played, 960);
    assert.equal(summaries[0].interrupted_impressions, 2);
  });
});
