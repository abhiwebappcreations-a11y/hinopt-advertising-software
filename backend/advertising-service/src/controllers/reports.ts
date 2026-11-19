import { Request, Response } from 'express';
import { db } from '../services/db.js';
import { PlaybackReportBatch } from '../types.js';

export async function ingestPlaybackReports(req: Request, res: Response): Promise<void> {
  try {
    const hinopt_device_id = String(req.params.hinopt_device_id);
    const body = req.body as PlaybackReportBatch;

    if (!body || !body.records || !Array.isArray(body.records)) {
      res.status(400).json({ error: 'INVALID_PAYLOAD', message: 'Records array is required' });
      return;
    }

    const count = await db.recordProofOfPlay(hinopt_device_id, body.records);

    res.status(202).json({
      status: 'ACCEPTED',
      acknowledged_count: count,
      screen_id: hinopt_device_id,
      reconciled_at: new Date().toISOString()
    });
  } catch (err: any) {
    res.status(500).json({ error: 'INGESTION_FAILED', message: err.message });
  }
}

export async function getProofOfPlayAnalytics(req: Request, res: Response): Promise<void> {
  try {
    const { campaign_id } = req.query;
    const records = await db.getProofOfPlaySummaries(campaign_id as string | undefined);
    
    // Calculate aggregate metrics
    const totalImpressions = records.reduce((acc, r) => acc + r.completed_impressions, 0);
    const totalSeconds = records.reduce((acc, r) => acc + r.total_seconds_played, 0);
    const interruptedImpressions = records.reduce((acc, r) => acc + r.interrupted_impressions, 0);

    res.status(200).json({
      total_impressions: totalImpressions,
      total_seconds_played: totalSeconds,
      interrupted_impressions: interruptedImpressions,
      record_count: records.length,
      records
    });
  } catch (err: any) {
    res.status(500).json({ error: 'ANALYTICS_FAILED', message: err.message });
  }
}
