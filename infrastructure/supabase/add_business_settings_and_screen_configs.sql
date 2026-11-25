-- ============================================================================
-- HINOPT BUSINESS SETTINGS & SCREEN CONFIGURATIONS MIGRATION
-- Target: Supabase Project yqmczojypjzsvbngipwd (https://yqmczojypjzsvbngipwd.supabase.co)
-- Adds tenant-level business admin preferences (ads_tenant_settings) and
-- per-screen playback/display/sync configurations (ads_screen_configs).
-- Safe & idempotent: can be executed repeatedly in Supabase SQL Editor.
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 1. Tenant-Level Business Admin Settings & Fleet Defaults
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads_tenant_settings (
    tenant_id TEXT PRIMARY KEY,
    license_key TEXT,
    -- Screen Playback & Display Defaults
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
    -- Campaign & Creative Governance
    require_campaign_approval BOOLEAN NOT NULL DEFAULT FALSE,
    default_sov_percent INTEGER NOT NULL DEFAULT 25,
    video_duration_mode TEXT NOT NULL DEFAULT 'FLEXIBLE'
        CHECK (video_duration_mode IN ('FLEXIBLE', 'STRICT_15S', 'STRICT_30S')),
    max_video_duration_seconds INTEGER NOT NULL DEFAULT 60,
    default_image_duration_seconds INTEGER NOT NULL DEFAULT 10,
    frequency_cap_slots INTEGER NOT NULL DEFAULT 0,
    -- Sync, Bandwidth & Proof-of-Play Preferences
    default_download_window_mode TEXT NOT NULL DEFAULT 'IMMEDIATE'
        CHECK (default_download_window_mode IN ('IMMEDIATE', 'SCHEDULED_OFF_PEAK')),
    off_peak_start TEXT NOT NULL DEFAULT '01:00:00',
    off_peak_end TEXT NOT NULL DEFAULT '05:00:00',
    default_pop_upload_trigger TEXT NOT NULL DEFAULT 'DAILY_END_OF_DAY'
        CHECK (default_pop_upload_trigger IN ('DAILY_END_OF_DAY', 'CAMPAIGN_DEADLINE')),
    sync_interval_seconds INTEGER NOT NULL DEFAULT 10,
    -- Kiosk Security & Portal Preferences
    owner_pin TEXT NOT NULL DEFAULT '202600',
    auto_refresh_seconds INTEGER NOT NULL DEFAULT 15,
    enable_live_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_ads_tenant_settings_updated_at ON ads_tenant_settings;
CREATE TRIGGER trg_ads_tenant_settings_updated_at
    BEFORE UPDATE ON ads_tenant_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 2. Per-Screen Operational & Display Configurations
-- ----------------------------------------------------------------------------
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
-- 3. RLS Policies & Permissions
-- ----------------------------------------------------------------------------
ALTER TABLE ads_tenant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_screen_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ads_tenant_settings_policy" ON ads_tenant_settings;
DROP POLICY IF EXISTS "ads_screen_configs_policy" ON ads_screen_configs;

CREATE POLICY "ads_tenant_settings_policy" ON ads_tenant_settings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ads_screen_configs_policy" ON ads_screen_configs FOR ALL USING (true) WITH CHECK (true);

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON TABLE ads_tenant_settings TO anon, authenticated, service_role;
GRANT ALL ON TABLE ads_screen_configs TO anon, authenticated, service_role;
