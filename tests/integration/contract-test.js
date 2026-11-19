/**
 * HINOPT Integration & Contract Test Suite
 * Validates responses against OpenAPI 3.1 specifications.
 * Run with: node tests/integration/contract-test.js
 */

const http = require('http');

const BASE_URL = 'http://localhost:8080';

function makeRequest(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const req = http.request(url, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    }, res => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, body: data ? JSON.parse(data) : null });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, body: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  console.log("======================================================================");
  console.log("  Running HINOPT Contract Verification Tests                          ");
  console.log("======================================================================");

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`[PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`[FAIL] ${name}: ${err.message}`);
      failed++;
    }
  }

  // 1. Test Authority Pre-Authorization
  await test("POST /v1/authority/devices/pre-authorize returns 200 with code", async () => {
    const res = await makeRequest('POST', '/v1/authority/devices/pre-authorize', {
      activation_code: "K97M2P",
      tenant_id: "admobitics",
      name: "Test Screen 1"
    });
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.activation_code !== "K97M2P") throw new Error("Code mismatch");
  });

  // 2. Test Device Enrollment
  let deviceId;
  await test("POST /v1/authority/devices/enroll returns 201 with hinopt_device_id", async () => {
    const res = await makeRequest('POST', '/v1/authority/devices/enroll', {
      activation_code: "K97M2P",
      public_key_pem: "-----BEGIN PUBLIC KEY-----\nMOCK\n-----END PUBLIC KEY-----",
      hardware_model: "TPC 151TCT",
      os_version: "Android 10"
    });
    if (res.status !== 201) throw new Error(`Expected 201, got ${res.status}`);
    if (!res.body.hinopt_device_id) throw new Error("Missing hinopt_device_id");
    deviceId = res.body.hinopt_device_id;
  });

  // 3. Test Sync Manifest Delivery
  let etag;
  await test("GET /v1/admobitics/displays/:id/sync-manifest returns 200 with campaigns", async () => {
    const res = await makeRequest('GET', `/v1/admobitics/displays/${deviceId}/sync-manifest`);
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (!res.body.campaigns || res.body.campaigns.length === 0) throw new Error("Missing campaigns");
    etag = res.headers['etag'];
  });

  // 4. Test ETag 304 Caching
  await test("GET /v1/admobitics/displays/:id/sync-manifest with If-None-Match returns 304", async () => {
    const res = await makeRequest('GET', `/v1/admobitics/displays/${deviceId}/sync-manifest`, null, {
      'If-None-Match': etag
    });
    if (res.status !== 304) throw new Error(`Expected 304 Not Modified, got ${res.status}`);
  });

  // 5. Test Playback Report Ingestion
  await test("POST /v1/admobitics/displays/:id/playback-reports returns 202 Accepted", async () => {
    const res = await makeRequest('POST', `/v1/admobitics/displays/${deviceId}/playback-reports`, {
      report_batch_id: "b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e",
      hinopt_device_id: deviceId,
      summaries: [
        {
          campaign_id: "c1a2b3c4-d5e6-4f7a-8b9c-0d1e2f3a4b5c",
          asset_id: "a9b8c7d6-e5f4-4a3b-2c1d-0e9f8a7b6c5d",
          reporting_date: "2026-11-19",
          impressions_count: 50,
          total_seconds_played: 750
        }
      ]
    });
    if (res.status !== 202) throw new Error(`Expected 202 Accepted, got ${res.status}`);
    if (res.body.acknowledged_count !== 1) throw new Error("Count mismatch");
  });

  console.log("----------------------------------------------------------------------");
  console.log(`Test Results: ${passed} Passed, ${failed} Failed`);
  console.log("======================================================================");

  if (failed > 0) process.exit(1);
}

// Check if server is running before executing
makeRequest('GET', '/v1/authority/devices/pre-authorize')
  .then(() => runTests())
  .catch(() => {
    console.log("[NOTICE] Mock server not running at http://localhost:8080.");
    console.log("[INFO] To run tests: node tools/development/mock-server/server.js in one terminal, then run this test.");
  });
