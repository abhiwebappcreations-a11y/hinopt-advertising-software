export interface Tenant {
  id: string;
  name: string;
  contact_email: string;
  max_screens: number;
  status: 'ACTIVE' | 'SUSPENDED';
  created_at: string;
  updated_at: string;
}

export interface ScreenDevice {
  id: string;
  tenant_id: string;
  activation_code?: string;
  enrollment_status: 'PENDING_PAIRING' | 'PRE_AUTHORIZED' | 'ACTIVE' | 'REVOKED';
  screen_name: string;
  hardware_model: string;
  serial_number: string;
  android_id?: string;
  mac_address?: string;
  public_key?: string;
  license_tier: 'CORE' | 'PRO' | 'ENTERPRISE';
  license_expires_at: string;
  last_heartbeat_at?: string;
  storage_free_bytes?: number;
  ram_free_bytes?: number;
  soc_temperature_celsius?: number;
  battery_level_percent?: number;
  is_charging?: boolean;
  app_version?: string;
  created_at: string;
  updated_at: string;
}

export interface PreAuthorizeRequest {
  activation_code: string;
  tenant_id: string;
  screen_name: string;
  license_tier?: 'CORE' | 'PRO' | 'ENTERPRISE';
  duration_days?: number;
}

export interface EnrollmentRequest {
  activation_code: string;
  hardware_model: string;
  serial_number: string;
  android_id: string;
  mac_address: string;
  public_key: string;
}

export interface EnrollmentResponse {
  hinopt_device_id: string;
  tenant_id: string;
  screen_name: string;
  license_token: string;
  license_signature: string;
  license_expires_at: string;
  public_key_server: string;
}

export interface HeartbeatRequest {
  timestamp: string;
  storage_free_bytes: number;
  ram_free_bytes: number;
  soc_temperature_celsius: number;
  battery_level_percent: number;
  is_charging: boolean;
  app_version: string;
  active_manifest_version: string;
  tamper_flags?: string[];
}

export interface HeartbeatResponse {
  server_time: string;
  license_status: 'ACTIVE' | 'EXPIRED' | 'REVOKED';
  license_expires_at: string;
  renewed_license_token?: string;
  next_heartbeat_seconds: number;
  command?: 'NONE' | 'REBOOT' | 'REFRESH_MANIFEST' | 'PURGE_CACHE' | 'QUARANTINE';
}
