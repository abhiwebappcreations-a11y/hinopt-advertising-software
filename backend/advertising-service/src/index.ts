import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { getSyncManifest } from './controllers/manifest.js';
import { ingestPlaybackReports, getProofOfPlayAnalytics } from './controllers/reports.js';
import {
  listCampaigns,
  getCampaign,
  createCampaign,
  listAdvertisers,
  createAdvertiser
} from './controllers/campaigns.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8082;

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ONLINE',
    service: 'hinopt-advertising-service',
    timestamp: new Date().toISOString()
  });
});

// Display Sync Manifest & Proof of Play Endpoints
app.get('/v1/displays/:hinopt_device_id/sync-manifest', getSyncManifest);
app.post('/v1/displays/:hinopt_device_id/playback-reports', ingestPlaybackReports);
app.get('/v1/analytics/proof-of-play', getProofOfPlayAnalytics);

// Campaigns & Advertisers Management
app.get('/v1/campaigns', listCampaigns);
app.post('/v1/campaigns', createCampaign);
app.get('/v1/campaigns/:campaign_id', getCampaign);

app.get('/v1/advertisers', listAdvertisers);
app.post('/v1/advertisers', createAdvertiser);

export { app };

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`[HINOPT Advertising Service] Listening on port ${PORT}`);
  });
}
