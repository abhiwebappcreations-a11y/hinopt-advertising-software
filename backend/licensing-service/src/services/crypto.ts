import crypto from 'crypto';

// Server master keypair for Ed25519 license signing
let serverPrivateKey: crypto.KeyObject;
let serverPublicKey: crypto.KeyObject;
let serverPublicKeyHex: string;

try {
  // Generate or load ephemeral Ed25519 keypair for sovereign authority
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  serverPrivateKey = privateKey;
  serverPublicKey = publicKey;
  serverPublicKeyHex = publicKey.export({ type: 'spki', format: 'der' }).toString('hex');
} catch {
  // Fallback if platform lacks Ed25519
  const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  serverPrivateKey = privateKey;
  serverPublicKey = publicKey;
  serverPublicKeyHex = publicKey.export({ type: 'spki', format: 'der' }).toString('hex');
}

export function getServerPublicKey(): string {
  return serverPublicKeyHex;
}

export function signLicense(deviceId: string, tenantId: string, expiresAt: string): { token: string; signature: string } {
  const payload = {
    iss: 'hinopt-sovereign-authority',
    sub: deviceId,
    tenant_id: tenantId,
    exp: expiresAt,
    iat: new Date().toISOString()
  };

  const payloadStr = JSON.stringify(payload);
  const token = Buffer.from(payloadStr).toString('base64url');

  const sign = crypto.createSign('SHA256');
  sign.update(token);
  sign.end();
  
  // Create signature using server private key
  const signature = crypto.sign(null, Buffer.from(token), serverPrivateKey).toString('hex');

  return { token, signature };
}

export function verifyDeviceSignature(payload: string, signature: string, publicKeyPem: string): boolean {
  try {
    const verify = crypto.createVerify('SHA256');
    verify.update(payload);
    verify.end();
    return crypto.verify(null, Buffer.from(payload), publicKeyPem, Buffer.from(signature, 'hex'));
  } catch {
    return false;
  }
}

export function generateActivationCode(): string {
  // Generates clean 6-character alphanumeric pairing code (excluding confusing characters 0/O, 1/I)
  const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  let code = '';
  const bytes = crypto.randomBytes(6);
  for (let i = 0; i < 6; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
}

export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}
