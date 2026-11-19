/**
 * HINOPT Security & Tamper Detection Test Suite
 * Validates 4-State Time Machine clock rollback detection and request signature validation.
 * Run with: node tests/security/tamper-detection-test.js
 */

const crypto = require('crypto');

function simulateTimeMachineEvaluation(systemClockMs, highWaterMarkMs, elapsedRealtimeMs) {
  // Case A: Clock Rollback Detected
  if (systemClockMs < highWaterMarkMs) {
    return {
      state: "CLOCK_ROLLBACK_QUARANTINE",
      allowCommercialAds: false,
      reason: `System clock (${systemClockMs}) is earlier than persistent high-water mark (${highWaterMarkMs})`
    };
  }

  // Case B: Continuous Running
  if (elapsedRealtimeMs > 0 && elapsedRealtimeMs < 24 * 3600 * 1000) {
    return {
      state: "CONTINUOUS_OFFLINE",
      allowCommercialAds: true,
      reason: "Monotonic ticker verified"
    };
  }

  // Case C: Offline Reboot Grace
  return {
    state: "UNTRUSTED_OFFLINE_REBOOT",
    allowCommercialAds: true,
    reason: "Within 24-hour grace window"
  };
}

function verifyRequestSignature(method, path, timestamp, body, publicKeyPem, signatureBase64) {
  const canonicalString = `${method}\n${path}\n${timestamp}\n${crypto.createHash('sha256').update(body).digest('hex')}`;
  
  // Replay protection: check clock skew <= 300 seconds
  const currentEpoch = Math.floor(Date.now() / 1000);
  if (Math.abs(currentEpoch - timestamp) > 300) {
    return { valid: false, error: "CLOCK_SKEW_EXCEEDED" };
  }

  const verifier = crypto.createVerify('SHA256');
  verifier.update(canonicalString);
  const isValid = verifier.verify(publicKeyPem, signatureBase64, 'base64');

  return { valid: isValid, error: isValid ? null : "INVALID_SIGNATURE" };
}

function runSecurityTests() {
  console.log("======================================================================");
  console.log("  Running HINOPT Security & Tamper Detection Tests                    ");
  console.log("======================================================================");

  let passed = 0;
  let failed = 0;

  function assert(name, condition) {
    if (condition) {
      console.log(`[PASS] ${name}`);
      passed++;
    } else {
      console.error(`[FAIL] ${name}`);
      failed++;
    }
  }

  // 1. Clock Rollback Simulation
  const highWater = 1732000000000; // e.g. Nov 19
  const rolledBackClock = 1731500000000; // e.g. Nov 13 (Rolled back)
  const result1 = simulateTimeMachineEvaluation(rolledBackClock, highWater, 0);
  assert("Detects clock rollback and enters CLOCK_ROLLBACK_QUARANTINE", result1.state === "CLOCK_ROLLBACK_QUARANTINE");
  assert("Halts commercial ads during rollback quarantine", result1.allowCommercialAds === false);

  // 2. Normal Continuous Playback
  const normalClock = 1732005000000;
  const result2 = simulateTimeMachineEvaluation(normalClock, highWater, 3600000);
  assert("Permits playback during CONTINUOUS_OFFLINE monotonic ticks", result2.state === "CONTINUOUS_OFFLINE");
  assert("Allows commercial ads during continuous offline run", result2.allowCommercialAds === true);

  // 3. Request Signature Verification & Tamper Detection
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const publicKeyPem = publicKey.export({ type: 'spki', format: 'pem' });

  const method = "POST";
  const path = "/v1/devices/d4e5f6a7/heartbeat";
  const timestamp = Math.floor(Date.now() / 1000);
  const originalBody = JSON.stringify({ cpu_temp: 50 });

  const canonicalString = `${method}\n${path}\n${timestamp}\n${crypto.createHash('sha256').update(originalBody).digest('hex')}`;
  const signer = crypto.createSign('SHA256');
  signer.update(canonicalString);
  const validSignature = signer.sign(privateKey, 'base64');

  // Valid signature verification
  const sigCheck1 = verifyRequestSignature(method, path, timestamp, originalBody, publicKeyPem, validSignature);
  assert("Verifies authentic ECDSA P-256 request signature", sigCheck1.valid === true);

  // Tampered payload verification
  const tamperedBody = JSON.stringify({ cpu_temp: 99, injected: true });
  const sigCheck2 = verifyRequestSignature(method, path, timestamp, tamperedBody, publicKeyPem, validSignature);
  assert("Rejects tampered payload with INVALID_SIGNATURE", sigCheck2.valid === false);

  // Replay attack simulation (timestamp 600s in the past)
  const oldTimestamp = timestamp - 600;
  const sigCheck3 = verifyRequestSignature(method, path, oldTimestamp, originalBody, publicKeyPem, validSignature);
  assert("Rejects replayed request with CLOCK_SKEW_EXCEEDED", sigCheck3.error === "CLOCK_SKEW_EXCEEDED");

  console.log("----------------------------------------------------------------------");
  console.log(`Security Test Results: ${passed} Passed, ${failed} Failed`);
  console.log("======================================================================");

  if (failed > 0) process.exit(1);
}

runSecurityTests();
