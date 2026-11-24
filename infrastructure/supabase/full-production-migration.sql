-- ============================================================================
-- HINOPT & ADMOBITICS CONSOLIDATED PRODUCTION DATABASE SCHEMA
-- Target: Supabase Project yqmczojypjzsvbngipwd (https://yqmczojypjzsvbngipwd.supabase.co)
-- Scope: Sovereign Authority + Multi-Tenant Advertising Operations
-- Invariant: 100% Clean / Zero Demo Data
-- ============================================================================

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
-- 2. Master Tenants / Clients (Zero Demo Data)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hinopt_tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id TEXT UNIQUE,
    name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    max_screens INTEGER NOT NULL DEFAULT 10,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 3. Master Devices / Screens (Hardware Registry - Zero Demo Data)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hinopt_screens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id TEXT NOT NULL,
    activation_code TEXT UNIQUE,
    enrollment_status TEXT NOT NULL DEFAULT 'PENDING_PAIRING',
    screen_name TEXT NOT NULL,
    hardware_model TEXT NOT NULL DEFAULT 'TPC 151TCT',
    serial_number TEXT NOT NULL DEFAULT 'PENDING',
    android_id TEXT,
    mac_address TEXT,
    public_key TEXT,
    license_tier TEXT NOT NULL DEFAULT 'PRO',
    license_expires_at TIMESTAMPTZ NOT NULL,
    last_heartbeat_at TIMESTAMPTZ,
    storage_free_bytes BIGINT,
    ram_free_bytes BIGINT,
    soc_temperature_celsius NUMERIC(5,2),
    battery_level_percent INTEGER,
    is_charging BOOLEAN,
    app_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hinopt_screens_tenant ON hinopt_screens(tenant_id);
CREATE INDEX IF NOT EXISTS idx_hinopt_screens_status ON hinopt_screens(enrollment_status);

-- ----------------------------------------------------------------------------
-- 4. Advertisers (Admobitics CRM - Zero Demo Data)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads_advertisers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 5. Advertising Campaigns (Zero Demo Data)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    advertiser_id UUID REFERENCES ads_advertisers(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    flight_start_date TIMESTAMPTZ NOT NULL,
    flight_end_date TIMESTAMPTZ NOT NULL,
    target_screens JSONB DEFAULT '[]'::jsonb,
    share_of_voice_percent INTEGER DEFAULT 25,
    dayparting JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 6. Creative Assets Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads_creatives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES ads_campaigns(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    media_type TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    duration_seconds INTEGER NOT NULL DEFAULT 15,
    sha256_checksum TEXT NOT NULL,
    storage_url TEXT NOT NULL,
    r2_purge_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 7. Proof-of-Play (PoP) Ingested Summaries
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads_proof_of_play (
    id BIGSERIAL PRIMARY KEY,
    screen_id TEXT NOT NULL,
    campaign_id TEXT NOT NULL,
    asset_id TEXT NOT NULL,
    play_date DATE NOT NULL,
    completed_impressions INTEGER NOT NULL DEFAULT 0,
    total_seconds_played INTEGER NOT NULL DEFAULT 0,
    interrupted_impressions INTEGER NOT NULL DEFAULT 0,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ads_pop_screen_date ON ads_proof_of_play(screen_id, play_date);
CREATE INDEX IF NOT EXISTS idx_ads_pop_campaign ON ads_proof_of_play(campaign_id);

-- ----------------------------------------------------------------------------
-- 8. Row-Level Security Policies (Open for Anon & Service Role in dev/pilot)
-- ----------------------------------------------------------------------------
ALTER TABLE hinopt_tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE hinopt_screens ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_advertisers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_creatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_proof_of_play ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-running script
DROP POLICY IF EXISTS "hinopt_tenants_policy" ON hinopt_tenants;
DROP POLICY IF EXISTS "hinopt_screens_policy" ON hinopt_screens;
DROP POLICY IF EXISTS "ads_advertisers_policy" ON ads_advertisers;
DROP POLICY IF EXISTS "ads_campaigns_policy" ON ads_campaigns;
DROP POLICY IF EXISTS "ads_creatives_policy" ON ads_creatives;
DROP POLICY IF EXISTS "ads_proof_of_play_policy" ON ads_proof_of_play;

-- Allow read/write for backend API operations
CREATE POLICY "hinopt_tenants_policy" ON hinopt_tenants FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "hinopt_screens_policy" ON hinopt_screens FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_advertisers_policy" ON ads_advertisers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_campaigns_policy" ON ads_campaigns FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_creatives_policy" ON ads_creatives FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_proof_of_play_policy" ON ads_proof_of_play FOR ALL USING (true) WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 9. Grant schema permissions to anon, authenticated, and service_role
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
