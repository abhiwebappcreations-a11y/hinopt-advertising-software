import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { Advertiser, Campaign, ProofOfPlayRecord } from '../types.js';

class DatabaseService {
  private supabase: SupabaseClient | null = null;

  // Clean in-memory storage (Enforcing ZERO DEMO DATA invariant)
  private advertisersStore: Map<string, Advertiser> = new Map();
  private campaignsStore: Map<string, Campaign> = new Map();
  private proofOfPlayStore: ProofOfPlayRecord[] = [];

  constructor() {
    const supabaseUrl = process.env.SUPABASE_ADS_URL;
    const supabaseKey = process.env.SUPABASE_ADS_SERVICE_KEY;

    if (supabaseUrl && supabaseKey) {
      this.supabase = createClient(supabaseUrl, supabaseKey);
      console.log('[DB] Connected to Supabase client-ads database.');
    } else {
      console.log('[DB] Running with Sovereign Zero-Demo Clean Store (No demo records).');
    }
  }

  // --- Advertisers ---
  async getAdvertisers(): Promise<Advertiser[]> {
    if (this.supabase) {
      const { data, error } = await this.supabase.from('ads_advertisers').select('*');
      if (error) throw error;
      return data || [];
    }
    return Array.from(this.advertisersStore.values());
  }

  async getAdvertiserById(id: string): Promise<Advertiser | null> {
    if (this.supabase) {
      const { data, error } = await this.supabase.from('ads_advertisers').select('*').eq('id', id).single();
      if (error || !data) return null;
      return data;
    }
    return this.advertisersStore.get(id) || null;
  }

  async createAdvertiser(adv: Omit<Advertiser, 'id' | 'created_at' | 'updated_at'>): Promise<Advertiser> {
    const now = new Date().toISOString();
    const newAdv: Advertiser = {
      id: crypto.randomUUID(),
      name: adv.name,
      contact_email: adv.contact_email,
      phone: adv.phone,
      created_at: now,
      updated_at: now
    };

    if (this.supabase) {
      const { data, error } = await this.supabase.from('ads_advertisers').insert([newAdv]).select().single();
      if (error) throw error;
      return data;
    }

    this.advertisersStore.set(newAdv.id, newAdv);
    return newAdv;
  }

  // --- Campaigns ---
  async getCampaigns(advertiserId?: string): Promise<Campaign[]> {
    if (this.supabase) {
      let query = this.supabase.from('ads_campaigns').select('*, assets:ads_creatives(*)');
      if (advertiserId) query = query.eq('advertiser_id', advertiserId);
      const { data, error } = await query;
      if (error) throw error;
      return data || [];
    }

    const all = Array.from(this.campaignsStore.values());
    if (advertiserId) {
      return all.filter(c => c.advertiser_id === advertiserId);
    }
    return all;
  }

  async getCampaignById(id: string): Promise<Campaign | null> {
    if (this.supabase) {
      const { data, error } = await this.supabase.from('ads_campaigns').select('*, assets:ads_creatives(*)').eq('id', id).single();
      if (error || !data) return null;
      return data;
    }
    return this.campaignsStore.get(id) || null;
  }

  async saveCampaign(campaign: Campaign): Promise<Campaign> {
    campaign.updated_at = new Date().toISOString();

    if (this.supabase) {
      const { data, error } = await this.supabase.from('ads_campaigns').upsert([campaign]).select().single();
      if (error) throw error;
      return data;
    }

    this.campaignsStore.set(campaign.id, campaign);
    return campaign;
  }

  // --- Proof of Play ---
  async recordProofOfPlay(screenId: string, records: ProofOfPlayRecord[]): Promise<number> {
    if (this.supabase) {
      const rows = records.map(r => ({
        screen_id: screenId,
        campaign_id: r.campaign_id,
        asset_id: r.asset_id,
        play_date: r.date,
        completed_impressions: r.completed_impressions,
        total_seconds_played: r.total_seconds_played,
        interrupted_impressions: r.interrupted_impressions,
        ingested_at: new Date().toISOString()
      }));

      const { error } = await this.supabase.from('ads_proof_of_play').insert(rows);
      if (error) throw error;
      return records.length;
    }

    this.proofOfPlayStore.push(...records);
    return records.length;
  }

  async getProofOfPlaySummaries(campaignId?: string): Promise<ProofOfPlayRecord[]> {
    if (this.supabase) {
      let query = this.supabase.from('ads_proof_of_play').select('*');
      if (campaignId) query = query.eq('campaign_id', campaignId);
      const { data, error } = await query;
      if (error) throw error;
      return data || [];
    }

    if (campaignId) {
      return this.proofOfPlayStore.filter(r => r.campaign_id === campaignId);
    }
    return this.proofOfPlayStore;
  }
}

export const db = new DatabaseService();
