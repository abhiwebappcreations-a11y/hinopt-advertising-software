import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import {
  preAuthorizeScreen,
  enrollDevice,
  heartbeatDevice,
  listScreens,
  revokeScreen
} from './controllers/devices.js';
import { listTenants, getTenant, createTenant } from './controllers/tenants.js';
import { superAdminAuth, deviceAuth } from './middleware/auth.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8081;

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ONLINE',
    service: 'hinopt-licensing-service',
    timestamp: new Date().toISOString()
  });
});

// Device Authority & Licensing Endpoints
app.post('/v1/devices/pre-authorize', superAdminAuth, preAuthorizeScreen);
app.post('/v1/devices/enroll', enrollDevice);
app.post('/v1/devices/:hinopt_device_id/heartbeat', deviceAuth, heartbeatDevice);
app.get('/v1/devices', superAdminAuth, listScreens);
app.post('/v1/devices/:hinopt_device_id/revoke', superAdminAuth, revokeScreen);

// Tenant Management Endpoints
app.get('/v1/tenants', superAdminAuth, listTenants);
app.get('/v1/tenants/:tenant_id', superAdminAuth, getTenant);
app.post('/v1/tenants', superAdminAuth, createTenant);

export { app };

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`[HINOPT Licensing Authority] Listening on port ${PORT}`);
  });
}
