import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { requestUpload, confirmUpload, getAsset } from './controllers/media.js';
import { storage } from './services/storage.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8083;

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ONLINE',
    service: 'hinopt-media-service',
    timestamp: new Date().toISOString()
  });
});

// Media Ingestion & Upload Endpoints
app.post('/v1/media/request-upload', requestUpload);
app.post('/v1/media/confirm-upload', confirmUpload);
app.get('/v1/media/:asset_id', getAsset);

// Automated 24h retention cleanup runner
setInterval(async () => {
  try {
    const purged = await storage.purgeExpiredAssets();
    if (purged.length > 0) {
      console.log(`[Retention] Automated purge finished: ${purged.length} assets purged.`);
    }
  } catch (err: any) {
    console.error('[Retention] Cleaner error:', err.message);
  }
}, 3600000); // Check hourly

export { app };

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`[HINOPT Media Service] Listening on port ${PORT}`);
  });
}
