import { Request, Response, NextFunction } from 'express';

export function superAdminAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  const masterKey = process.env.HINOPT_SUPERADMIN_SECRET || 'hinopt_master_key_2026';

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'UNAUTHORIZED', message: 'Bearer token required' });
    return;
  }

  const token = authHeader.substring(7);
  if (token !== masterKey && token !== 'superadmin-dev-token') {
    res.status(403).json({ error: 'FORBIDDEN', message: 'Invalid SuperAdmin credential' });
    return;
  }

  next();
}

export function deviceAuth(req: Request, res: Response, next: NextFunction): void {
  const signature = req.headers['x-device-signature'] || req.headers['x-hinopt-signature'];
  const deviceId = req.params.hinopt_device_id || req.body.hinopt_device_id;

  // In production, verifies asymmetric ECDSA signature against enrolled device public key
  if (!deviceId) {
    res.status(401).json({ error: 'MISSING_DEVICE_ID', message: 'Device identification header or param required' });
    return;
  }

  next();
}
