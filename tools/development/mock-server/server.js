/**
 * HINOPT Advertising Software — Unified Mock Server Simulator
 * 
 * Implements OpenAPI 3.1 contracts for:
 *   1. HINOPT Sovereign Authority API (/v1/authority/...)
 *   2. Admobitics Advertising & Manifest API (/v1/admobitics/...)
 *   3. Media Ingestion & Upload API (/v1/media/...)
 * 
 * Zero external dependencies (pure Node.js http and crypto modules).
 * Run with: node tools/development/mock-server/server.js
 */

const http = require('http');
const crypto = require('crypto');
const url = require('url');

const PORT = process.env.PORT || 8080;

// In-Memory Database State
const state = {
  activeCode: "K97M2P",
  devices: new Map(),
  manifestVersion: 42,
  campaigns: [
    {
      campaign_id: "c1a2b3c4-d5e6-4f7a-8b9c-0d1e2f3a4b5c",
      flight_start_date: "2026-11-01",
      flight_end_date: "2026-12-31",
      weight: 2,
      day_parts: [
        {
          days_of_week: ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"],
          start_time: "00:00:00",
          end_time: "23:59:59"
        }
      ],
      creatives: [
        {
          asset_id: "a9b8c7d6-e5f4-4a3b-2c1d-0e9f8a7b6c5d",
          media_type: "VIDEO",
          duration_seconds: 15,
          file_size_bytes: 18452100,
          sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          download_url: "https://cdn.admobitics.hinopt.com/assets/sample-ad-15s.mp4"
        }
      ]
    }
  ],
  playbackReports: []
};

function sendJson(res, statusCode, data, headers = {}) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Device-Id, X-Device-Timestamp, X-Device-Signature, If-None-Match',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    ...headers
  });
  res.end(JSON.stringify(data, null, 2));
}

function sendError(res, statusCode, code, message) {
  sendJson(res, statusCode, {
    error: {
      code: code,
      message: message,
      timestamp: new Date().toISOString()
    }
  });
}

function parseBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        resolve({});
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;

  // Handle CORS Pre-flight
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Device-Id, X-Device-Timestamp, X-Device-Signature, If-None-Match',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
    });
    return res.end();
  }

  console.log(`[${new Date().toISOString()}] ${method} ${pathname}`);

  // =========================================================================
  // 1. HINOPT SOVEREIGN AUTHORITY ENDPOINTS
  // =========================================================================

  // POST /v1/authority/devices/pre-authorize
  if (pathname === '/v1/authority/devices/pre-authorize' && method === 'POST') {
    const body = await parseBody(req);
    state.activeCode = body.activation_code || "K97M2P";
    return sendJson(res, 200, {
      status: "PRE_AUTHORIZED",
      activation_code: state.activeCode,
      tenant_id: body.tenant_id || "admobitics",
      expires_at: new Date(Date.now() + 15 * 60 * 1000).toISOString()
    });
  }

  // POST /v1/authority/devices/enroll
  if (pathname === '/v1/authority/devices/enroll' && method === 'POST') {
    const body = await parseBody(req);
    if (body.activation_code !== state.activeCode) {
      return sendError(res, 400, "INVALID_ACTIVATION_CODE", "Activation code mismatch or expired.");
    }
    const deviceId = crypto.randomUUID();
    state.devices.set(deviceId, {
      deviceId,
      name: "TPC 151TCT Display #1",
      status: "ACTIVE",
      publicKey: body.public_key_pem
    });

    return sendJson(res, 201, {
      hinopt_device_id: deviceId,
      tenant_id: "admobitics",
      assigned_name: "TPC 151TCT Display #1",
      licence: {
        licence_id: crypto.randomUUID(),
        plan_id: "STANDARD",
        valid_from: Math.floor(Date.now() / 1000),
        valid_until: Math.floor(Date.now() / 1000) + (30 * 24 * 3600),
        max_offline_days: 30,
        signed_token: "MOCK_ED25519_JWT_eyJhbGciOiJFZERTQSI...HINOPT_SOVEREIGN"
      }
    });
  }

  // POST /v1/authority/devices/:id/heartbeat
  if (pathname.startsWith('/v1/authority/devices/') && pathname.endsWith('/heartbeat') && method === 'POST') {
    const body = await parseBody(req);
    return sendJson(res, 200, {
      server_time: new Date().toISOString(),
      licence_status: "VALID",
      renewed_licence_token: null,
      command: null
    });
  }

  // =========================================================================
  // 2. ADMOBITICS ADVERTISING & MANIFEST ENDPOINTS
  // =========================================================================

  // GET /v1/admobitics/displays/:id/sync-manifest
  if (pathname.startsWith('/v1/admobitics/displays/') && pathname.endsWith('/sync-manifest') && method === 'GET') {
    const ifNoneMatch = req.headers['if-none-match'];
    const currentETag = `"v${state.manifestVersion}"`;

    if (ifNoneMatch === currentETag) {
      res.writeHead(304, { 'ETag': currentETag });
      return res.end();
    }

    return sendJson(res, 200, {
      manifest_version: state.manifestVersion,
      generated_at: new Date().toISOString(),
      screen_config: {
        display_name: "TPC 151TCT Display #1",
        fallback_mode: "HOUSE_LOOP",
        audio_policy: "SCHEDULED_AUDIO",
        audio_schedule: { start: "09:00:00", end: "21:00:00", max_volume_pct: 70 },
        rotation_policy: "WEIGHTED_SOV",
        layout_mode: "FULL_SCREEN_1080P",
        pop_upload_trigger: "DAILY_END_OF_DAY"
      },
      campaigns: state.campaigns,
      fallback_asset: {
        asset_id: "fallback-house-loop-v1",
        media_type: "VIDEO",
        duration_seconds: 30,
        sha256: "8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4",
        download_url: "https://cdn.admobitics.hinopt.com/assets/house-loop-default-v1.mp4"
      }
    }, { 'ETag': currentETag });
  }

  // POST /v1/admobitics/displays/:id/playback-reports
  if (pathname.startsWith('/v1/admobitics/displays/') && pathname.endsWith('/playback-reports') && method === 'POST') {
    const body = await parseBody(req);
    state.playbackReports.push(body);
    return sendJson(res, 202, {
      status: "ACCEPTED",
      acknowledged_count: (body.summaries || []).length
    });
  }

  // =========================================================================
  // 3. MEDIA SERVICE ENDPOINTS
  // =========================================================================

  // POST /v1/media/request-upload
  if (pathname === '/v1/media/request-upload' && method === 'POST') {
    const body = await parseBody(req);
    const assetId = crypto.randomUUID();
    return sendJson(res, 200, {
      asset_id: assetId,
      r2_object_key: `creatives/mock/${assetId}.mp4`,
      upload_url: `https://mock-r2.hinopt.com/creatives/mock/${assetId}.mp4?presigned=true`,
      expires_at: new Date(Date.now() + 15 * 60 * 1000).toISOString()
    });
  }

  // Default 404
  return sendError(res, 404, "ENDPOINT_NOT_FOUND", `The route ${pathname} was not found on the mock server.`);
});

server.listen(PORT, () => {
  console.log(`
  =================================================================
    HINOPT Advertising Software — Mock Server Simulator
  =================================================================
    Port:       ${PORT}
    Authority:  http://localhost:${PORT}/v1/authority/devices/...
    Admobitics: http://localhost:${PORT}/v1/admobitics/displays/...
    Media:      http://localhost:${PORT}/v1/media/...
    Status:     READY FOR LOCAL TESTING
  =================================================================
  `);
});
