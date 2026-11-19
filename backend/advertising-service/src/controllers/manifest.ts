import { Request, Response } from 'express';
import { db } from '../services/db.js';
import { compileSyncManifest } from '../services/manifestCompiler.js';

export async function getSyncManifest(req: Request, res: Response): Promise<void> {
  try {
    const hinopt_device_id = String(req.params.hinopt_device_id);
    const ifNoneMatch = req.headers['if-none-match'];

    const campaigns = await db.getCampaigns();
    const manifest = compileSyncManifest(hinopt_device_id, 'tenant-default', campaigns);

    // ETag comparison for O(1) sync caching (PRD-004 specification)
    const etag = `"${manifest.manifest_version}"`;

    if (ifNoneMatch && (ifNoneMatch === etag || ifNoneMatch === manifest.manifest_version)) {
      res.setHeader('ETag', etag);
      res.status(304).end(); // Not Modified!
      return;
    }

    res.setHeader('ETag', etag);
    res.status(200).json(manifest);
  } catch (err: any) {
    res.status(500).json({ error: 'MANIFEST_COMPILATION_ERROR', message: err.message });
  }
}
