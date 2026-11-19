import { Request, Response } from 'express';
import { storage } from '../services/storage.js';
import { UploadRequest, ConfirmUploadRequest } from '../types.js';

export async function requestUpload(req: Request, res: Response): Promise<void> {
  try {
    const { campaign_id, name, media_type, file_size_bytes, duration_seconds } = req.body as UploadRequest;

    if (!campaign_id || !name || !media_type || !file_size_bytes) {
      res.status(400).json({ error: 'MISSING_FIELDS', message: 'campaign_id, name, media_type, file_size_bytes required' });
      return;
    }

    // Constraint: Max 50 MB (52,428,800 bytes)
    if (file_size_bytes > 52428800) {
      res.status(400).json({ error: 'FILE_TOO_LARGE', message: 'Maximum file size allowed is 50MB' });
      return;
    }

    const result = await storage.generateUploadUrl(req.body);

    res.status(200).json({
      asset_id: result.asset_id,
      upload_url: result.upload_url,
      destination_key: result.destination_key,
      expires_in_seconds: 900,
      headers_required: {
        'Content-Type': media_type === 'VIDEO_MP4' ? 'video/mp4' : 'image/png'
      }
    });
  } catch (err: any) {
    res.status(500).json({ error: 'UPLOAD_REQUEST_FAILED', message: err.message });
  }
}

export async function confirmUpload(req: Request, res: Response): Promise<void> {
  try {
    const { asset_id, sha256_checksum, campaign_flight_end_date } = req.body as ConfirmUploadRequest;

    if (!asset_id || !sha256_checksum) {
      res.status(400).json({ error: 'MISSING_FIELDS', message: 'asset_id and sha256_checksum are required' });
      return;
    }

    const asset = await storage.confirmUpload(asset_id, sha256_checksum, campaign_flight_end_date);
    if (!asset) {
      res.status(404).json({ error: 'ASSET_NOT_FOUND', message: 'Asset not found or not in pending state' });
      return;
    }

    res.status(201).json(asset);
  } catch (err: any) {
    res.status(500).json({ error: 'CONFIRM_FAILED', message: err.message });
  }
}

export async function getAsset(req: Request, res: Response): Promise<void> {
  try {
    const asset_id = String(req.params.asset_id);
    const asset = await storage.getAsset(asset_id);
    if (!asset) {
      res.status(404).json({ error: 'ASSET_NOT_FOUND', message: 'Asset not found' });
      return;
    }
    res.status(200).json(asset);
  } catch (err: any) {
    res.status(500).json({ error: 'GET_ASSET_FAILED', message: err.message });
  }
}
