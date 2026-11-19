import { Request, Response } from 'express';
import { db } from '../services/db.js';
import { Campaign, Advertiser } from '../types.js';

export async function listCampaigns(req: Request, res: Response): Promise<void> {
  try {
    const { advertiser_id } = req.query;
    const campaigns = await db.getCampaigns(advertiser_id as string | undefined);
    res.status(200).json({ campaigns, count: campaigns.length });
  } catch (err: any) {
    res.status(500).json({ error: 'FAILED_TO_LIST_CAMPAIGNS', message: err.message });
  }
}

export async function getCampaign(req: Request, res: Response): Promise<void> {
  try {
    const campaign_id = String(req.params.campaign_id);
    const campaign = await db.getCampaignById(campaign_id);
    if (!campaign) {
      res.status(404).json({ error: 'CAMPAIGN_NOT_FOUND', message: 'Campaign not found' });
      return;
    }
    res.status(200).json(campaign);
  } catch (err: any) {
    res.status(500).json({ error: 'FAILED_TO_GET_CAMPAIGN', message: err.message });
  }
}

export async function createCampaign(req: Request, res: Response): Promise<void> {
  try {
    const {
      advertiser_id,
      name,
      flight_start_date,
      flight_end_date,
      target_screens = [],
      share_of_voice_percent = 25,
      dayparting = [],
      assets = []
    } = req.body;

    if (!advertiser_id || !name || !flight_start_date || !flight_end_date) {
      res.status(400).json({ error: 'MISSING_FIELDS', message: 'advertiser_id, name, flight_start_date, flight_end_date are required' });
      return;
    }

    const campaign: Campaign = {
      id: crypto.randomUUID(),
      advertiser_id,
      name,
      status: 'ACTIVE',
      flight_start_date,
      flight_end_date,
      target_screens,
      share_of_voice_percent,
      dayparting,
      assets,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    const saved = await db.saveCampaign(campaign);
    res.status(201).json(saved);
  } catch (err: any) {
    res.status(500).json({ error: 'FAILED_TO_CREATE_CAMPAIGN', message: err.message });
  }
}

export async function listAdvertisers(req: Request, res: Response): Promise<void> {
  try {
    const advertisers = await db.getAdvertisers();
    res.status(200).json({ advertisers, count: advertisers.length });
  } catch (err: any) {
    res.status(500).json({ error: 'FAILED_TO_LIST_ADVERTISERS', message: err.message });
  }
}

export async function createAdvertiser(req: Request, res: Response): Promise<void> {
  try {
    const { name, contact_email, phone } = req.body;
    if (!name || !contact_email) {
      res.status(400).json({ error: 'MISSING_FIELDS', message: 'name and contact_email are required' });
      return;
    }

    const adv = await db.createAdvertiser({ name, contact_email, phone });
    res.status(201).json(adv);
  } catch (err: any) {
    res.status(500).json({ error: 'FAILED_TO_CREATE_ADVERTISER', message: err.message });
  }
}
