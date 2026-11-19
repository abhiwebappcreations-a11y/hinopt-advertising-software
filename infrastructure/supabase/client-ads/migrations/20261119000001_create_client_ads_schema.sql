-- ============================================================================
-- Client Advertising Operations Database Schema
-- Database / Project: client-ads (Supabase Project 2)
-- Scope: Multi-Tenant Advertising Operations for Client Ad Companies (e.g. Admobitics)
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
-- 2. Advertisers Table (Zero Demo Data - Purely Registered Advertisers)
-- ----------------------------------------------------------------------------
CREATE TABLE ads_advertisers (
    advertiser_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL,
    contact_name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_ads_advertisers_updated_at
    BEFORE UPDATE ON ads_advertisers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Zero Demo Data Invariant: NO fake/demo advertisers.

-- ----------------------------------------------------------------------------
-- 3. Screen Groups Table (Topology / Locations - Zero Demo Data)
-- ----------------------------------------------------------------------------
CREATE TABLE ads_screen_groups (
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    location_city TEXT,
    venue_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Zero Demo Data Invariant: NO fake/demo screen groups.

-- ----------------------------------------------------------------------------
-- 4. Screen Configurations Table
-- Note: hinopt_device_id is the opaque UUID issued by HINOPT
-- Screens appear here ONLY when authorized by HINOPT Super Admin for this client
-- ----------------------------------------------------------------------------
CREATE TABLE ads_screen_configs (
    hinopt_device_id UUID PRIMARY KEY, -- Opaque reference to HINOPT device
    group_id UUID REFERENCES ads_screen_groups(group_id) ON DELETE SET NULL,
    display_name TEXT NOT NULL,
    fallback_mode TEXT NOT NULL DEFAULT 'HOUSE_LOOP'
        CHECK (fallback_mode IN ('HOUSE_LOOP', 'STATIC_IMAGE', 'BLACK_SCREEN')),
    audio_policy TEXT NOT NULL DEFAULT 'MUTED_GLOBAL'
        CHECK (audio_policy IN ('MUTED_GLOBAL', 'ENABLED_WITH_LIMIT', 'SCHEDULED_AUDIO')),
    audio_schedule JSONB DEFAULT '{"start": "09:00:00", "end": "21:00:00", "max_volume_pct": 70}'::jsonb,
    rotation_policy TEXT NOT NULL DEFAULT 'ROUND_ROBIN'
        CHECK (rotation_policy IN ('ROUND_ROBIN', 'WEIGHTED_SOV')),
    layout_mode TEXT NOT NULL DEFAULT 'FULL_SCREEN_1080P'
        CHECK (layout_mode IN ('FULL_SCREEN_1080P', 'SPLIT_SCREEN_DUAL_VIDEO', 'SPLIT_SCREEN_TICKER')),
    pop_upload_trigger TEXT NOT NULL DEFAULT 'DAILY_END_OF_DAY'
        CHECK (pop_upload_trigger IN ('DAILY_END_OF_DAY', 'CAMPAIGN_DEADLINE')),
    fallback_asset_url TEXT,
    fallback_asset_sha256 TEXT,
    ticker_text TEXT,
    manifest_version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ads_screen_group ON ads_screen_configs(group_id);

CREATE TRIGGER trg_ads_screens_updated_at
    BEFORE UPDATE ON ads_screen_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to increment manifest_version on screen change
CREATE OR REPLACE FUNCTION increment_manifest_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.manifest_version = OLD.manifest_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ads_screens_manifest_ver
    BEFORE UPDATE ON ads_screen_configs
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION increment_manifest_version();

-- ----------------------------------------------------------------------------
-- 5. Advertising Campaigns Table (Zero Demo Data)
-- ----------------------------------------------------------------------------
CREATE TABLE ads_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    advertiser_id UUID NOT NULL REFERENCES ads_advertisers(advertiser_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    flight_start_date DATE NOT NULL,
    flight_end_date DATE NOT NULL,
    weight INTEGER NOT NULL DEFAULT 1 CHECK (weight >= 1 AND weight <= 5),
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PENDING_APPROVAL', 'SCHEDULED', 'ACTIVE', 'PAUSED', 'EXPIRED', 'ARCHIVED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (flight_start_date <= flight_end_date)
);

CREATE INDEX idx_ads_campaigns_dates ON ads_campaigns(flight_start_date, flight_end_date);
CREATE INDEX idx_ads_campaigns_status ON ads_campaigns(status);

CREATE TRIGGER trg_ads_campaigns_updated_at
    BEFORE UPDATE ON ads_campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 6. Day-Part Windows Table (Contiguous Time Slots)
-- ----------------------------------------------------------------------------
CREATE TABLE ads_day_parts (
    day_part_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES ads_campaigns(campaign_id) ON DELETE CASCADE,
    days_of_week TEXT[] NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (start_time < end_time)
);

CREATE INDEX idx_ads_dayparts_campaign ON ads_day_parts(campaign_id);

-- ----------------------------------------------------------------------------
-- 7. Creative Assets Table (Cloudflare R2 Objects)
-- ----------------------------------------------------------------------------
CREATE TABLE ads_creative_assets (
    asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES ads_campaigns(campaign_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('VIDEO', 'IMAGE')),
    r2_object_key TEXT NOT NULL UNIQUE,
    cdn_url TEXT NOT NULL,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds > 0),
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0),
    sha256 TEXT NOT NULL,
    width INTEGER NOT NULL DEFAULT 1920,
    height INTEGER NOT NULL DEFAULT 1080,
    codec_profile TEXT,
    r2_purge_at TIMESTAMPTZ NOT NULL, -- Flight End Date + 3 Days
    is_purged BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ads_assets_purge ON ads_creative_assets(r2_purge_at, is_purged);
CREATE INDEX idx_ads_assets_campaign ON ads_creative_assets(campaign_id);

-- ----------------------------------------------------------------------------
-- 8. Campaign Screen Assignments (Many-to-Many Mapping)
-- ----------------------------------------------------------------------------
CREATE TABLE ads_campaign_screens (
    campaign_id UUID NOT NULL REFERENCES ads_campaigns(campaign_id) ON DELETE CASCADE,
    hinopt_device_id UUID NOT NULL REFERENCES ads_screen_configs(hinopt_device_id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (campaign_id, hinopt_device_id)
);

CREATE OR REPLACE FUNCTION notify_screen_manifest_update()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        UPDATE ads_screen_configs 
        SET manifest_version = manifest_version + 1, updated_at = NOW() 
        WHERE hinopt_device_id = NEW.hinopt_device_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE ads_screen_configs 
        SET manifest_version = manifest_version + 1, updated_at = NOW() 
        WHERE hinopt_device_id = OLD.hinopt_device_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_campaign_screens_manifest_update
    AFTER INSERT OR UPDATE OR DELETE ON ads_campaign_screens
    FOR EACH ROW EXECUTE FUNCTION notify_screen_manifest_update();

-- ----------------------------------------------------------------------------
-- 9. Proof-of-Play (PoP) Aggregated Summaries Table
-- ----------------------------------------------------------------------------
CREATE TABLE ads_proof_of_play_summaries (
    summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hinopt_device_id UUID NOT NULL REFERENCES ads_screen_configs(hinopt_device_id) ON DELETE CASCADE,
    campaign_id UUID NOT NULL REFERENCES ads_campaigns(campaign_id) ON DELETE CASCADE,
    asset_id UUID NOT NULL REFERENCES ads_creative_assets(asset_id) ON DELETE CASCADE,
    reporting_date DATE NOT NULL,
    impressions_count INTEGER NOT NULL DEFAULT 0 CHECK (impressions_count >= 0),
    total_seconds_played INTEGER NOT NULL DEFAULT 0 CHECK (total_seconds_played >= 0),
    interrupted_count INTEGER NOT NULL DEFAULT 0 CHECK (interrupted_count >= 0),
    first_play_timestamp TIMESTAMPTZ NOT NULL,
    last_play_timestamp TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_device_campaign_asset_date UNIQUE (hinopt_device_id, campaign_id, asset_id, reporting_date)
);

CREATE INDEX idx_ads_pop_reporting ON ads_proof_of_play_summaries(campaign_id, reporting_date);
CREATE INDEX idx_ads_pop_device ON ads_proof_of_play_summaries(hinopt_device_id, reporting_date);

-- ----------------------------------------------------------------------------
-- 10. Row-Level Security (RLS) Policies
-- ----------------------------------------------------------------------------
ALTER TABLE ads_advertisers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_screen_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_screen_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_day_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_creative_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_campaign_screens ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads_proof_of_play_summaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY ads_service_role_all ON ads_advertisers FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY ads_service_role_all ON ads_screen_groups FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY ads_service_role_all ON ads_screen_configs FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY ads_service_role_all ON ads_campaigns FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY ads_service_role_all ON ads_day_parts FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY ads_service_role_all ON ads_creative_assets FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY ads_service_role_all ON ads_campaign_screens FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY ads_service_role_all ON ads_proof_of_play_summaries FOR ALL TO service_role USING (true) WITH CHECK (true);
