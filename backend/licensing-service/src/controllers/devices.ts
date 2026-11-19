import { Request, Response } from 'express';
import { db } from '../services/db.js';
import { signLicense, getServerPublicKey } from '../services/crypto.js';
import { PreAuthorizeRequest, EnrollmentRequest, HeartbeatRequest, ScreenDevice } from '../types.js';

export async function preAuthorizeScreen(req: Request, res: Response): Promise<void> {
  try {
    const { activation_code, tenant_id, screen_name, license_tier = 'PRO', duration_days = 730 } = req.body as PreAuthorizeRequest;

    if (!activation_code || !tenant_id || !screen_name) {
      res.status(400).json({ error: 'INVALID_REQUEST', message: 'Missing activation_code, tenant_id, or screen_name' });
      return;
    }

    const tenant = await db.getTenantById(tenant_id);
    if (!tenant) {
      res.status(404).json({ error: 'TENANT_NOT_FOUND', message: `Tenant ID ${tenant_id} not found` });
      return;
    }

    // Check tenant quota
    const existingScreens = await db.getScreens(tenant_id);
    if (existingScreens.length >= tenant.max_screens) {
      res.status(403).json({ error: 'QUOTA_EXCEEDED', message: `Tenant maximum screen limit (${tenant.max_screens}) reached` });
      return;
    }

    const now = new Date();
    const expiry = new Date(now.getTime() + duration_days * 24 * 60 * 60 * 1000);

    const screen: ScreenDevice = {
      id: crypto.randomUUID(),
      tenant_id,
      activation_code: activation_code.toUpperCase(),
      enrollment_status: 'PRE_AUTHORIZED',
      screen_name,
      hardware_model: 'PENDING_DISCOVERY',
      serial_number: 'PENDING',
      license_tier,
      license_expires_at: expiry.toISOString(),
      created_at: now.toISOString(),
      updated_at: now.toISOString()
    };

    await db.saveScreen(screen);

    res.status(200).json({
      status: 'PRE_AUTHORIZED',
      screen_id: screen.id,
      tenant_id: screen.tenant_id,
      activation_code: screen.activation_code,
      license_expires_at: screen.license_expires_at
    });
  } catch (err: any) {
    res.status(500).json({ error: 'INTERNAL_ERROR', message: err.message });
  }
}

export async function enrollDevice(req: Request, res: Response): Promise<void> {
  try {
    const { activation_code, hardware_model, serial_number, android_id, mac_address, public_key } = req.body as EnrollmentRequest;

    if (!activation_code) {
      res.status(400).json({ error: 'MISSING_ACTIVATION_CODE', message: 'Activation code is required' });
      return;
    }

    const screen = await db.getScreenByActivationCode(activation_code.toUpperCase());
    if (!screen) {
      res.status(404).json({ error: 'CODE_NOT_FOUND', message: 'Activation code invalid or not pre-authorized' });
      return;
    }

    if (screen.enrollment_status === 'ACTIVE') {
      res.status(400).json({ error: 'ALREADY_ENROLLED', message: 'This screen is already active' });
      return;
    }

    // Generate cryptographic license
    const { token, signature } = signLicense(screen.id, screen.tenant_id, screen.license_expires_at);

    // Update screen record
    screen.enrollment_status = 'ACTIVE';
    screen.hardware_model = hardware_model || 'TPC 151TCT';
    screen.serial_number = serial_number || 'UNKNOWN';
    screen.android_id = android_id;
    screen.mac_address = mac_address;
    screen.public_key = public_key;
    screen.activation_code = undefined; // Consumed

    await db.saveScreen(screen);

    res.status(201).json({
      hinopt_device_id: screen.id,
      tenant_id: screen.tenant_id,
      screen_name: screen.screen_name,
      license_token: token,
      license_signature: signature,
      license_expires_at: screen.license_expires_at,
      public_key_server: getServerPublicKey()
    });
  } catch (err: any) {
    res.status(500).json({ error: 'ENROLLMENT_FAILED', message: err.message });
  }
}

export async function heartbeatDevice(req: Request, res: Response): Promise<void> {
  try {
    const hinopt_device_id = String(req.params.hinopt_device_id);
    const body = req.body as HeartbeatRequest;

    const screen = await db.getScreenById(hinopt_device_id);
    if (!screen) {
      res.status(404).json({ error: 'DEVICE_NOT_FOUND', message: 'Device not enrolled in HINOPT authority' });
      return;
    }

    if (screen.enrollment_status === 'REVOKED') {
      res.status(403).json({
        server_time: new Date().toISOString(),
        license_status: 'REVOKED',
        license_expires_at: screen.license_expires_at,
        command: 'QUARANTINE',
        next_heartbeat_seconds: 3600
      });
      return;
    }

    // Check license expiry
    const isExpired = new Date(screen.license_expires_at).getTime() < Date.now();
    const licenseStatus = isExpired ? 'EXPIRED' : 'ACTIVE';

    // Update telemetry
    screen.last_heartbeat_at = new Date().toISOString();
    screen.storage_free_bytes = body.storage_free_bytes;
    screen.ram_free_bytes = body.ram_free_bytes;
    screen.soc_temperature_celsius = body.soc_temperature_celsius;
    screen.battery_level_percent = body.battery_level_percent;
    screen.is_charging = body.is_charging;
    screen.app_version = body.app_version;

    await db.saveScreen(screen);

    let command: 'NONE' | 'REBOOT' | 'REFRESH_MANIFEST' | 'PURGE_CACHE' | 'QUARANTINE' = 'NONE';
    if (body.tamper_flags && body.tamper_flags.length > 0) {
      command = 'QUARANTINE';
    }

    res.status(200).json({
      server_time: new Date().toISOString(),
      license_status: licenseStatus,
      license_expires_at: screen.license_expires_at,
      next_heartbeat_seconds: 300,
      command
    });
  } catch (err: any) {
    res.status(500).json({ error: 'HEARTBEAT_FAILED', message: err.message });
  }
}

export async function listScreens(req: Request, res: Response): Promise<void> {
  try {
    const { tenant_id } = req.query;
    const screens = await db.getScreens(tenant_id as string | undefined);
    res.status(200).json({ screens, count: screens.length });
  } catch (err: any) {
    res.status(500).json({ error: 'LIST_FAILED', message: err.message });
  }
}

export async function revokeScreen(req: Request, res: Response): Promise<void> {
  try {
    const hinopt_device_id = String(req.params.hinopt_device_id);
    const screen = await db.updateScreen(hinopt_device_id, { enrollment_status: 'REVOKED' });
    if (!screen) {
      res.status(404).json({ error: 'SCREEN_NOT_FOUND', message: 'Screen device not found' });
      return;
    }
    res.status(200).json({ status: 'REVOKED', screen_id: screen.id });
  } catch (err: any) {
    res.status(500).json({ error: 'REVOKE_FAILED', message: err.message });
  }
}
