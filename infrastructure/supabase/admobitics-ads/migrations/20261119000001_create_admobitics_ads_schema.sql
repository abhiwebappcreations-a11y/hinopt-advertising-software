-- ============================================================================
-- Admobitics Advertising Operations Database Schema
-- Database / Project: admobitics-ads (Supabase Project 2)
-- Scope: Advertisers, Campaigns, Day-Parts, Screen Configs, Proof-of-Play
-- Version: 1.0.0 (Phase 1 Baseline)
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
-- 2. Advertisers Table
-- ----------------------------------------------------------------------------
CREATE TABLE admobitics_advertisers (
    advertiser_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL,
    contact_name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_admobitics_advertisers_updated_at
    BEFORE UPDATE ON admobitics_advertisers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 3. Screen Groups Table (Topology / Locations)
-- ----------------------------------------------------------------------------
CREATE TABLE admobitics_screen_groups (
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    location_city TEXT,
    venue_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed baseline group
INSERT INTO admobitics_screen_groups (name, description, location_city, venue_type)
VALUES ('Default General Fleet', 'All unassigned active commercial screens', 'Global', 'Commercial')
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. Screen Configurations Table
-- Note: hinopt_device_id is an opaque UUID issued by HINOPT
-- ----------------------------------------------------------------------------
CREATE TABLE admobitics_screen_configs (
    hinopt_device_id UUID PRIMARY KEY, -- Opaque reference to HINOPT device
    group_id UUID REFERENCES admobitics_screen_groups(group_id) ON DELETE SET NULL,
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

CREATE INDEX idx_admobitics_screen_group ON admobitics_screen_configs(group_id);

CREATE TRIGGER trg_admobitics_screens_updated_at
    BEFORE UPDATE ON admobitics_screen_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to increment manifest_version on screen change
CREATE OR REPLACE FUNCTION increment_manifest_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.manifest_version = OLD.manifest_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_admobitics_screens_manifest_ver
    BEFORE UPDATE ON admobitics_screen_configs
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION increment_manifest_version();

-- ----------------------------------------------------------------------------
-- 5. Advertising Campaigns Table
-- ----------------------------------------------------------------------------
CREATE TABLE admobitics_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    advertiser_id UUID NOT NULL REFERENCES admobitics_advertisers(advertiser_id),
    name TEXT NOT NULL,
    flight_start_date DATE NOT NULL,
    flight_end_date DATE NOT NULL,
    weight INTEGER NOT NULL DEFAULT 1 CHECK (weight >= 1 AND weight <= 5),
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PENDING_MEDIA', 'SCHEDULED', 'ACTIVE', 'PAUSED', 'EXPIRED', 'ARCHIVED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (flight_start_date <= flight_end_date)
);

CREATE INDEX idx_admobitics_campaigns_dates ON admobitics_campaigns(flight_start_date, flight_end_date);
CREATE INDEX idx_admobitics_campaigns_status ON admobitics_campaigns(status);

CREATE TRIGGER trg_admobitics_campaigns_updated_at
    BEFORE UPDATE ON admobitics_campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 6. Day-Part Windows Table (Contiguous Time Slots)
-- ----------------------------------------------------------------------------
CREATE TABLE admobitics_day_parts (
    day_part_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES admobitics_campaigns(campaign_id) ON DELETE CASCADE,
    days_of_week TEXT[] NOT NULL, -- ['MONDAY', 'TUESDAY', ...]
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (start_time < end_time)
);

CREATE INDEX idx_admobitics_dayparts_campaign ON admobitics_day_parts(campaign_id);

-- ----------------------------------------------------------------------------
-- 7. Creative Assets Table (Cloudflare R2 Objects)
-- ----------------------------------------------------------------------------
CREATE TABLE admobitics_creative_assets (
    asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES admobitics_campaigns(campaign_id) ON DELETE CASCADE,
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

CREATE INDEX idx_admobitics_assets_purge ON admobitics_creative_assets(r2_purge_at, is_purged);
CREATE INDEX idx_admobitics_assets_campaign ON admobitics_creative_assets(campaign_id);

-- ----------------------------------------------------------------------------
-- 8. Campaign Screen Assignments (Many-to-Many Mapping)
-- ----------------------------------------------------------------------------
CREATE TABLE admobitics_campaign_screens (
    campaign_id UUID NOT NULL REFERENCES admobitics_campaigns(campaign_id) ON DELETE CASCADE,
    hinopt_device_id UUID NOT NULL REFERENCES admobitics_screen_configs(hinopt_device_id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (campaign_id, hinopt_device_id)
);

-- Trigger to increment screen manifest_version when campaign assignment changes
CREATE OR REPLACE FUNCTION notify_screen_manifest_update()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        UPDATE admobitics_screen_configs 
        SET manifest_version = manifest_version + 1, updated_at = NOW() 
        WHERE hinopt_device_id = NEW.hinopt_device_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE admobitics_screen_configs 
        SET manifest_version = manifest_version + 1, updated_at = NOW() 
        WHERE hinopt_device_id = OLD.hinopt_device_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_campaign_screens_manifest_update
    AFTER INSERT OR UPDATE OR DELETE ON admobitics_campaign_screens
    FOR EACH ROW EXECUTE FUNCTION notify_screen_manifest_update();

-- ----------------------------------------------------------------------------
-- 9. Proof-of-Play (PoP) Aggregated Summaries Table
-- ----------------------------------------------------------------------------
CREATE TABLE admobitics_proof_of_play_summaries (
    summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hinopt_device_id UUID NOT NULL REFERENCES admobitics_screen_configs(hinopt_device_id) ON DELETE CASCADE,
    campaign_id UUID NOT NULL REFERENCES admobitics_campaigns(campaign_id) ON DELETE CASCADE,
    asset_id UUID NOT NULL REFERENCES admobitics_creative_assets(asset_id) ON DELETE CASCADE,
    reporting_date DATE NOT NULL,
    impressions_count INTEGER NOT NULL DEFAULT 0 CHECK (impressions_count >= 0),
    total_seconds_played INTEGER NOT NULL DEFAULT 0 CHECK (total_seconds_played >= 0),
    interrupted_count INTEGER NOT NULL DEFAULT 0 CHECK (interrupted_count >= 0),
    first_play_timestamp TIMESTAMPTZ NOT NULL,
    last_play_timestamp TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_device_campaign_asset_date UNIQUE (hinopt_device_id, campaign_id, asset_id, reporting_date)
);

CREATE INDEX idx_admobitics_pop_reporting ON admobitics_proof_of_play_summaries(campaign_id, reporting_date);
CREATE INDEX idx_admobitics_pop_device ON admobitics_proof_of_play_summaries(hinopt_device_id, reporting_date);

-- ----------------------------------------------------------------------------
-- 10. Row-Level Security (RLS) Policies
-- ----------------------------------------------------------------------------
ALTER TABLE admobitics_advertisers ENABLE ROW LEVEL SECURITY;
ALTER TABLE admobitics_screen_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE admobitics_screen_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE admobitics_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE admobitics_day_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE admobitics_creative_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE admobitics_campaign_screens ENABLE ROW LEVEL SECURITY;
ALTER TABLE admobitics_proof_of_play_summaries ENABLE ROW LEVEL SECURITY;

-- Service Role Policy: Full access for Admobitics backend services only
CREATE POLICY admobitics_service_role_all ON admobitics_advertisers FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY admobitics_service_role_all ON admobitics_screen_groups FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY admobitics_service_role_all ON admobitics_screen_configs FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY admobitics_service_role_all ON admobitics_campaigns FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY admobitics_service_role_all ON admobitics_day_parts FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY admobitics_service_role_all ON admobitics_creative_assets FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY admobitics_service_role_all ON admobitics_campaign_screens FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY admobitics_service_role_all ON admobitics_proof_of_play_summaries FOR ALL TO service_role USING (true) WITH CHECK (true);
