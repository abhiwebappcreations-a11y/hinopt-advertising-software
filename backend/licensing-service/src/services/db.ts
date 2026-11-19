import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { Tenant, ScreenDevice } from '../types.js';

class DatabaseService {
  private supabase: SupabaseClient | null = null;
  
  // Clean in-memory storage (Enforcing ZERO DEMO DATA invariant)
  private tenantsStore: Map<string, Tenant> = new Map();
  private screensStore: Map<string, ScreenDevice> = new Map();

  constructor() {
    const supabaseUrl = process.env.SUPABASE_HINOPT_URL;
    const supabaseKey = process.env.SUPABASE_HINOPT_SERVICE_KEY;

    if (supabaseUrl && supabaseKey) {
      this.supabase = createClient(supabaseUrl, supabaseKey);
      console.log('[DB] Connected to Supabase hinopt-core authority.');
    } else {
      console.log('[DB] Running with Sovereign Zero-Demo Clean Store (No demo records).');
    }
  }

  // --- Tenants ---
  async getTenants(): Promise<Tenant[]> {
    if (this.supabase) {
      const { data, error } = await this.supabase.from('hinopt_tenants').select('*');
      if (error) throw error;
      return data || [];
    }
    return Array.from(this.tenantsStore.values());
  }

  async getTenantById(id: string): Promise<Tenant | null> {
    if (this.supabase) {
      const { data, error } = await this.supabase.from('hinopt_tenants').select('*').eq('id', id).single();
      if (error || !data) return null;
      return data;
    }
    return this.tenantsStore.get(id) || null;
  }

  async createTenant(tenant: Omit<Tenant, 'id' | 'created_at' | 'updated_at'> & { id?: string }): Promise<Tenant> {
    const now = new Date().toISOString();
    const newTenant: Tenant = {
      id: tenant.id || crypto.randomUUID(),
      name: tenant.name,
      contact_email: tenant.contact_email,
      max_screens: tenant.max_screens,
      status: tenant.status || 'ACTIVE',
      created_at: now,
      updated_at: now
    };

    if (this.supabase) {
      const { data, error } = await this.supabase.from('hinopt_tenants').insert([newTenant]).select().single();
      if (error) throw error;
      return data;
    }

    this.tenantsStore.set(newTenant.id, newTenant);
    return newTenant;
  }

  // --- Screens / Devices ---
  async getScreens(tenantId?: string): Promise<ScreenDevice[]> {
    if (this.supabase) {
      let query = this.supabase.from('hinopt_screens').select('*');
      if (tenantId) query = query.eq('tenant_id', tenantId);
      const { data, error } = await query;
      if (error) throw error;
      return data || [];
    }

    const all = Array.from(this.screensStore.values());
    if (tenantId) {
      return all.filter(s => s.tenant_id === tenantId);
    }
    return all;
  }

  async getScreenById(id: string): Promise<ScreenDevice | null> {
    if (this.supabase) {
      const { data, error } = await this.supabase.from('hinopt_screens').select('*').eq('id', id).single();
      if (error || !data) return null;
      return data;
    }
    return this.screensStore.get(id) || null;
  }

  async getScreenByActivationCode(code: string): Promise<ScreenDevice | null> {
    if (this.supabase) {
      const { data, error } = await this.supabase.from('hinopt_screens').select('*').eq('activation_code', code).single();
      if (error || !data) return null;
      return data;
    }
    for (const screen of this.screensStore.values()) {
      if (screen.activation_code === code) return screen;
    }
    return null;
  }

  async saveScreen(screen: ScreenDevice): Promise<ScreenDevice> {
    screen.updated_at = new Date().toISOString();

    if (this.supabase) {
      const { data, error } = await this.supabase.from('hinopt_screens').upsert([screen]).select().single();
      if (error) throw error;
      return data;
    }

    this.screensStore.set(screen.id, screen);
    return screen;
  }

  async updateScreen(id: string, updates: Partial<ScreenDevice>): Promise<ScreenDevice | null> {
    const existing = await this.getScreenById(id);
    if (!existing) return null;

    const updated: ScreenDevice = {
      ...existing,
      ...updates,
      updated_at: new Date().toISOString()
    };

    return this.saveScreen(updated);
  }
}

export const db = new DatabaseService();
