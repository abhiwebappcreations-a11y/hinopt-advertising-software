import test from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../dist/services/db.js';
import { signLicense, generateActivationCode } from '../dist/services/crypto.js';

test('Zero Demo Data Invariant: initial store has 0 tenants and 0 screens', async () => {
  const tenants = await db.getTenants();
  assert.equal(tenants.length, 0, 'Must have zero pre-seeded tenants');

  const screens = await db.getScreens();
  assert.equal(screens.length, 0, 'Must have zero pre-seeded screens');
});

test('Tenant creation and screen pre-authorization flow', async () => {
  const tenant = await db.createTenant({
    name: 'Admobitics Media Fleet',
    contact_email: 'fleet@admobitics.com',
    max_screens: 10,
    status: 'ACTIVE'
  });

  assert.ok(tenant.id, 'Tenant ID should be generated');
  assert.equal(tenant.name, 'Admobitics Media Fleet');

  const code = generateActivationCode();
  assert.equal(code.length, 6, 'Activation code must be 6 characters');

  const { token, signature } = signLicense('device-test-1', tenant.id, new Date(Date.now() + 86400000).toISOString());
  assert.ok(token, 'Token must be non-empty');
  assert.ok(signature, 'Signature must be non-empty');
});
