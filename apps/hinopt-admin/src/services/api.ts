const BASE_URL = 'http://localhost:8081/v1';
const SUPERADMIN_TOKEN = 'hinopt_master_key_2026';

const headers = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${SUPERADMIN_TOKEN}`
};

export interface Tenant {
  id: string;
  name: string;
  contact_email: string;
  max_screens: number;
  status: 'ACTIVE' | 'SUSPENDED';
}

export interface ScreenDevice {
  id: string;
  tenant_id: string;
  activation_code?: string;
  enrollment_status: 'PENDING_PAIRING' | 'PRE_AUTHORIZED' | 'ACTIVE' | 'REVOKED';
  screen_name: string;
  hardware_model: string;
  serial_number: string;
  license_tier: string;
  license_expires_at: string;
  last_heartbeat_at?: string;
  storage_free_bytes?: number;
  ram_free_bytes?: number;
  soc_temperature_celsius?: number;
  battery_level_percent?: number;
  is_charging?: boolean;
}

export async function fetchTenants(): Promise<Tenant[]> {
  try {
    const res = await fetch(`${BASE_URL}/tenants`, { headers });
    if (!res.ok) return [];
    const data = await res.json();
    return data.tenants || [];
  } catch {
    return [];
  }
}

export async function createTenant(tenant: { name: string; contact_email: string; max_screens: number }): Promise<Tenant | null> {
  const res = await fetch(`${BASE_URL}/tenants`, {
    method: 'POST',
    headers,
    body: JSON.stringify(tenant)
  });
  if (!res.ok) return null;
  const data = await res.json();
  return data.tenant;
}

export async function fetchScreens(tenantId?: string): Promise<ScreenDevice[]> {
  try {
    const url = tenantId ? `${BASE_URL}/devices?tenant_id=${tenantId}` : `${BASE_URL}/devices`;
    const res = await fetch(url, { headers });
    if (!res.ok) return [];
    const data = await res.json();
    return data.screens || [];
  } catch {
    return [];
  }
}

export async function preAuthorizeScreen(req: {
  activation_code: string;
  tenant_id: string;
  screen_name: string;
  license_tier: string;
  duration_days: number;
}): Promise<boolean> {
  const res = await fetch(`${BASE_URL}/devices/pre-authorize`, {
    method: 'POST',
    headers,
    body: JSON.stringify(req)
  });
  return res.ok;
}

export async function revokeScreen(screenId: string): Promise<boolean> {
  const res = await fetch(`${BASE_URL}/devices/${screenId}/revoke`, {
    method: 'POST',
    headers
  });
  return res.ok;
}
