-- ============================================================================
-- HINOPT Sovereign Authority Database Schema
-- Database / Project: hinopt-core (Supabase Project 1)
-- Scope: Master Tenants, Hardware Devices, Keystore Keys, Licences, Telemetry
-- Version: 1.0.0 (Phase 1 Baseline - Clean Production / Zero Demo Data)
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. Helper Function: Auto-update updated_at timestamp
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. Master Tenants / Clients Table (Zero Demo Data - Purely Registered Clients)
-- ----------------------------------------------------------------------------
CREATE TABLE hinopt_tenants (
    tenant_id TEXT PRIMARY KEY, -- e.g. client slug or UUID
    name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    max_screens_quota INTEGER NOT NULL DEFAULT 10 CHECK (max_screens_quota >= 1),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_hinopt_tenants_updated_at
    BEFORE UPDATE ON hinopt_tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Zero Demo Data Invariant: NO pre-seeded demo clients.
-- Clients appear here ONLY when created by HINOPT Super Admin.

-- ----------------------------------------------------------------------------
-- 3. Licence Plans Table (Master Tier Templates)
-- ----------------------------------------------------------------------------
CREATE TABLE hinopt_licence_plans (
    plan_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    max_offline_days INTEGER NOT NULL DEFAULT 30 CHECK (max_offline_days >= 0), -- 0 = Unlimited
    features JSONB NOT NULL DEFAULT '["FULL_SCREEN_1080P", "OFFLINE_PLAYBACK_30D"]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Baseline system plan templates (system definitions, not client demo data)
INSERT INTO hinopt_licence_plans (plan_id, name, max_offline_days, features)
VALUES 
    ('STANDARD', 'Standard Commercial Kiosk', 30, '["FULL_SCREEN_1080P", "SPLIT_SCREEN_ZONES", "OFFLINE_PLAYBACK_30D"]'::jsonb),
    ('ENTERPRISE', 'Enterprise High-Autonomy Kiosk', 90, '["FULL_SCREEN_1080P", "SPLIT_SCREEN_ZONES", "OFFLINE_PLAYBACK_90D", "HARDWARE_WATCHDOG"]'::jsonb),
    ('UNLIMITED_OFFLINE', 'Full Licence Offline Autonomy', 0, '["FULL_SCREEN_1080P", "SPLIT_SCREEN_ZONES", "OFFLINE_PLAYBACK_FULL_TERM"]'::jsonb)
ON CONFLICT (plan_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. Master Devices Table (Hardware Registry - Zero Demo Data)
-- ----------------------------------------------------------------------------
CREATE TABLE hinopt_devices (
    hinopt_device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id TEXT NOT NULL REFERENCES hinopt_tenants(tenant_id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    activation_code TEXT UNIQUE,
    activation_code_expires_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'UNENROLLED'
        CHECK (status IN ('UNENROLLED', 'PENDING', 'ACTIVE', 'SUSPENDED', 'REVOKED', 'DECOMMISSIONED')),
    hardware_model TEXT NOT NULL DEFAULT 'TPC 151TCT',
    os_version TEXT,
    assigned_plan_id TEXT REFERENCES hinopt_licence_plans(plan_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hinopt_devices_tenant ON hinopt_devices(tenant_id);
CREATE INDEX idx_hinopt_devices_status ON hinopt_devices(status);
CREATE INDEX idx_hinopt_devices_act_code ON hinopt_devices(activation_code) WHERE activation_code IS NOT NULL;

CREATE TRIGGER trg_hinopt_devices_updated_at
    BEFORE UPDATE ON hinopt_devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Zero Demo Data Invariant: NO fake/demo devices.
-- Devices appear ONLY when an actual physical screen boots and is enrolled.

-- ----------------------------------------------------------------------------
-- 5. Device Cryptographic Public Keys (AndroidKeyStore ECDSA P-256)
-- ----------------------------------------------------------------------------
CREATE TABLE hinopt_device_keys (
    hinopt_device_id UUID PRIMARY KEY REFERENCES hinopt_devices(hinopt_device_id) ON DELETE CASCADE,
    public_key_pem TEXT NOT NULL,
    algorithm TEXT NOT NULL DEFAULT 'ECDSA_P256',
    key_fingerprint_sha256 TEXT NOT NULL,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 6. Issued Licences Table (Ed25519 Signed Tokens)
-- ----------------------------------------------------------------------------
CREATE TABLE hinopt_licences (
    licence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hinopt_device_id UUID NOT NULL REFERENCES hinopt_devices(hinopt_device_id) ON DELETE CASCADE,
    tenant_id TEXT NOT NULL REFERENCES hinopt_tenants(tenant_id),
    plan_id TEXT NOT NULL REFERENCES hinopt_licence_plans(plan_id),
    signed_token TEXT NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    max_offline_days INTEGER NOT NULL DEFAULT 30,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hinopt_licences_device ON hinopt_licences(hinopt_device_id, is_revoked, valid_until DESC);
CREATE INDEX idx_hinopt_licences_tenant ON hinopt_licences(tenant_id);

-- ----------------------------------------------------------------------------
-- 7. Device Telemetry Heartbeats Table
-- ----------------------------------------------------------------------------
CREATE TABLE hinopt_heartbeats (
    id BIGSERIAL PRIMARY KEY,
    hinopt_device_id UUID NOT NULL REFERENCES hinopt_devices(hinopt_device_id) ON DELETE CASCADE,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cpu_temp_celsius NUMERIC(5,2),
    memory_used_mb INTEGER,
    memory_free_mb INTEGER,
    storage_used_bytes BIGINT,
    storage_free_bytes BIGINT,
    uptime_seconds BIGINT,
    app_version TEXT,
    player_state JSONB,
    ip_address INET
);

CREATE INDEX idx_hinopt_heartbeats_device_time ON hinopt_heartbeats(hinopt_device_id, received_at DESC);

-- ----------------------------------------------------------------------------
-- 8. Immutable System Audit Logs Table
-- ----------------------------------------------------------------------------
CREATE TABLE hinopt_audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    actor_type TEXT NOT NULL CHECK (actor_type IN ('SUPER_ADMIN', 'DEVICE', 'SYSTEM', 'TENANT_API')),
    actor_id TEXT NOT NULL,
    action TEXT NOT NULL,
    target_entity TEXT NOT NULL,
    target_id TEXT NOT NULL,
    details JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hinopt_audit_target ON hinopt_audit_logs(target_entity, target_id);
CREATE INDEX idx_hinopt_audit_created ON hinopt_audit_logs(created_at DESC);

-- ----------------------------------------------------------------------------
-- 9. Row-Level Security (RLS) Policies
-- ----------------------------------------------------------------------------
ALTER TABLE hinopt_tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE hinopt_licence_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE hinopt_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE hinopt_device_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE hinopt_licences ENABLE ROW LEVEL SECURITY;
ALTER TABLE hinopt_heartbeats ENABLE ROW LEVEL SECURITY;
ALTER TABLE hinopt_audit_logs ENABLE ROW LEVEL SECURITY;

-- Service Role Policy: Full access for HINOPT backend services only
CREATE POLICY hinopt_service_role_all ON hinopt_tenants FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY hinopt_service_role_all ON hinopt_licence_plans FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY hinopt_service_role_all ON hinopt_devices FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY hinopt_service_role_all ON hinopt_device_keys FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY hinopt_service_role_all ON hinopt_licences FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY hinopt_service_role_all ON hinopt_heartbeats FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY hinopt_service_role_all ON hinopt_audit_logs FOR ALL TO service_role USING (true) WITH CHECK (true);
