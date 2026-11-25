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
-- 7b. Business Admin Settings & Per-Screen Configurations (Zero Demo Data)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads_tenant_settings (
    tenant_id TEXT PRIMARY KEY,
    license_key TEXT,
    default_fallback_mode TEXT NOT NULL DEFAULT 'HOUSE_LOOP'
        CHECK (default_fallback_mode IN ('HOUSE_LOOP', 'STATIC_IMAGE', 'BLACK_SCREEN')),
    default_fallback_asset_url TEXT NOT NULL DEFAULT '',
    default_audio_policy TEXT NOT NULL DEFAULT 'MUTED_GLOBAL'
        CHECK (default_audio_policy IN ('MUTED_GLOBAL', 'ENABLED_WITH_LIMIT', 'SCHEDULED_AUDIO')),
    default_audio_schedule JSONB NOT NULL DEFAULT '{"start": "09:00:00", "end": "21:00:00", "max_volume_pct": 70}'::jsonb,
    default_rotation_policy TEXT NOT NULL DEFAULT 'ROUND_ROBIN'
        CHECK (default_rotation_policy IN ('ROUND_ROBIN', 'WEIGHTED_SOV')),
    default_layout_mode TEXT NOT NULL DEFAULT 'FULL_SCREEN_1080P'
        CHECK (default_layout_mode IN ('FULL_SCREEN_1080P', 'SPLIT_SCREEN_DUAL_VIDEO', 'SPLIT_SCREEN_TICKER')),
    default_ticker_text TEXT NOT NULL DEFAULT '',
    default_companion_asset_url TEXT NOT NULL DEFAULT '',
    require_campaign_approval BOOLEAN NOT NULL DEFAULT FALSE,
    default_sov_percent INTEGER NOT NULL DEFAULT 25,
    video_duration_mode TEXT NOT NULL DEFAULT 'FLEXIBLE'
        CHECK (video_duration_mode IN ('FLEXIBLE', 'STRICT_15S', 'STRICT_30S')),
    max_video_duration_seconds INTEGER NOT NULL DEFAULT 60,
    default_image_duration_seconds INTEGER NOT NULL DEFAULT 10,
    frequency_cap_slots INTEGER NOT NULL DEFAULT 0,
    default_download_window_mode TEXT NOT NULL DEFAULT 'IMMEDIATE'
        CHECK (default_download_window_mode IN ('IMMEDIATE', 'SCHEDULED_OFF_PEAK')),
    off_peak_start TEXT NOT NULL DEFAULT '01:00:00',
    off_peak_end TEXT NOT NULL DEFAULT '05:00:00',
    default_pop_upload_trigger TEXT NOT NULL DEFAULT 'DAILY_END_OF_DAY'
        CHECK (default_pop_upload_trigger IN ('DAILY_END_OF_DAY', 'CAMPAIGN_DEADLINE')),
    sync_interval_seconds INTEGER NOT NULL DEFAULT 10,
    owner_pin TEXT NOT NULL DEFAULT '202600',
    auto_refresh_seconds INTEGER NOT NULL DEFAULT 15,
    enable_live_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ads_screen_configs (
    screen_id UUID PRIMARY KEY REFERENCES hinopt_screens(id) ON DELETE CASCADE,
    tenant_id TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    use_tenant_defaults BOOLEAN NOT NULL DEFAULT TRUE,
    fallback_mode TEXT NOT NULL DEFAULT 'HOUSE_LOOP'
        CHECK (fallback_mode IN ('HOUSE_LOOP', 'STATIC_IMAGE', 'BLACK_SCREEN')),
    fallback_asset_url TEXT NOT NULL DEFAULT '',
    fallback_asset_sha256 TEXT NOT NULL DEFAULT '',
    audio_policy TEXT NOT NULL DEFAULT 'MUTED_GLOBAL'
        CHECK (audio_policy IN ('MUTED_GLOBAL', 'ENABLED_WITH_LIMIT', 'SCHEDULED_AUDIO')),
    audio_schedule JSONB NOT NULL DEFAULT '{"start": "09:00:00", "end": "21:00:00", "max_volume_pct": 70}'::jsonb,
    rotation_policy TEXT NOT NULL DEFAULT 'ROUND_ROBIN'
        CHECK (rotation_policy IN ('ROUND_ROBIN', 'WEIGHTED_SOV')),
    layout_mode TEXT NOT NULL DEFAULT 'FULL_SCREEN_1080P'
        CHECK (layout_mode IN ('FULL_SCREEN_1080P', 'SPLIT_SCREEN_DUAL_VIDEO', 'SPLIT_SCREEN_TICKER')),
    ticker_text TEXT NOT NULL DEFAULT '',
    companion_asset_url TEXT NOT NULL DEFAULT '',
    pop_upload_trigger TEXT NOT NULL DEFAULT 'DAILY_END_OF_DAY'
        CHECK (pop_upload_trigger IN ('DAILY_END_OF_DAY', 'CAMPAIGN_DEADLINE')),
    download_window_mode TEXT NOT NULL DEFAULT 'IMMEDIATE'
        CHECK (download_window_mode IN ('IMMEDIATE', 'SCHEDULED_OFF_PEAK')),
    sync_interval_seconds INTEGER NOT NULL DEFAULT 10,
    owner_pin TEXT NOT NULL DEFAULT '',
    manifest_version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ads_screen_configs_tenant ON ads_screen_configs(tenant_id);

DROP TRIGGER IF EXISTS trg_ads_tenant_settings_updated_at ON ads_tenant_settings;
CREATE TRIGGER trg_ads_tenant_settings_updated_at
    BEFORE UPDATE ON ads_tenant_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_ads_screen_configs_updated_at ON ads_screen_configs;
CREATE TRIGGER trg_ads_screen_configs_updated_at
    BEFORE UPDATE ON ads_screen_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION increment_screen_config_manifest_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.manifest_version = COALESCE(OLD.manifest_version, 0) + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ads_screen_configs_manifest_ver ON ads_screen_configs;
CREATE TRIGGER trg_ads_screen_configs_manifest_ver
    BEFORE UPDATE ON ads_screen_configs
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION increment_screen_config_manifest_version();

-- ----------------------------------------------------------------------------
-- 8. Row-Level Security Policies (Open for Anon & Service Role in dev/pilot)
-- ----------------------------------------------------------------------------
ALTER TABLE hinopt_tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE hinopt_screens ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_advertisers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_creatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_proof_of_play ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_tenant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_screen_configs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-running script
DROP POLICY IF EXISTS "hinopt_tenants_policy" ON hinopt_tenants;
DROP POLICY IF EXISTS "hinopt_screens_policy" ON hinopt_screens;
DROP POLICY IF EXISTS "ads_advertisers_policy" ON ads_advertisers;
DROP POLICY IF EXISTS "ads_campaigns_policy" ON ads_campaigns;
DROP POLICY IF EXISTS "ads_creatives_policy" ON ads_creatives;
DROP POLICY IF EXISTS "ads_proof_of_play_policy" ON ads_proof_of_play;
DROP POLICY IF EXISTS "ads_tenant_settings_policy" ON ads_tenant_settings;
DROP POLICY IF EXISTS "ads_screen_configs_policy" ON ads_screen_configs;

-- Allow read/write for backend API operations
CREATE POLICY "hinopt_tenants_policy" ON hinopt_tenants FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "hinopt_screens_policy" ON hinopt_screens FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_advertisers_policy" ON ads_advertisers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_campaigns_policy" ON ads_campaigns FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_creatives_policy" ON ads_creatives FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_proof_of_play_policy" ON ads_proof_of_play FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_tenant_settings_policy" ON ads_tenant_settings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_screen_configs_policy" ON ads_screen_configs FOR ALL USING (true) WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 9. Grant schema permissions to anon, authenticated, and service_role
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
