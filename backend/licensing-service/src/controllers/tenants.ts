import { Request, Response } from 'express';
import { db } from '../services/db.js';

export async function listTenants(req: Request, res: Response): Promise<void> {
  try {
    const tenants = await db.getTenants();
    res.status(200).json({ tenants, count: tenants.length });
  } catch (err: any) {
    res.status(500).json({ error: 'FAILED_TO_LIST_TENANTS', message: err.message });
  }
}

export async function getTenant(req: Request, res: Response): Promise<void> {
  try {
    const tenant_id = String(req.params.tenant_id);
    const tenant = await db.getTenantById(tenant_id);
    if (!tenant) {
      res.status(404).json({ error: 'TENANT_NOT_FOUND', message: 'Tenant not found' });
      return;
    }
    const screens = await db.getScreens(tenant_id);
    res.status(200).json({ tenant, active_screens: screens.length, max_screens: tenant.max_screens });
  } catch (err: any) {
    res.status(500).json({ error: 'FAILED_TO_GET_TENANT', message: err.message });
  }
}

export async function createTenant(req: Request, res: Response): Promise<void> {
  try {
    const { name, contact_email, max_screens = 10, status = 'ACTIVE' } = req.body;
    if (!name || !contact_email) {
      res.status(400).json({ error: 'INVALID_REQUEST', message: 'Name and contact_email are required' });
      return;
    }

    const tenant = await db.createTenant({
      name,
      contact_email,
      max_screens,
      status
    });

    res.status(201).json({ tenant });
  } catch (err: any) {
    res.status(500).json({ error: 'FAILED_TO_CREATE_TENANT', message: err.message });
  }
}
