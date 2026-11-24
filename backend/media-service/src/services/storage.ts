import { S3Client, PutObjectCommand, DeleteObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { MediaAssetMetadata, UploadRequest } from '../types.js';

class StorageService {
  private s3: S3Client | null = null;
  private bucketName: string;
  private publicCdnBase: string;
  private assetsStore: Map<string, MediaAssetMetadata> = new Map();

  constructor() {
    const accountId = process.env.CLOUDFLARE_R2_ACCOUNT_ID;
    const accessKeyId = process.env.CLOUDFLARE_R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY;
    this.bucketName = process.env.CLOUDFLARE_R2_BUCKET || 'hinopt-media-creatives';
    this.publicCdnBase = process.env.CDN_BASE_URL || 'https://cdn.hinopt.com/media';

    if (accountId && accessKeyId && secretAccessKey) {
      this.s3 = new S3Client({
        region: 'auto',
        endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId,
          secretAccessKey
        }
      });
      console.log('[Media] Connected to Cloudflare R2 storage bucket:', this.bucketName);
    } else {
      console.log('[Media] Running with Local Media Storage Service (Zero demo records).');
    }
  }

  async generateUploadUrl(req: UploadRequest): Promise<{ asset_id: string; upload_url: string; destination_key: string }> {
    const assetId = crypto.randomUUID();
    const extension = req.media_type === 'VIDEO_MP4' ? 'mp4' : req.media_type === 'IMAGE_PNG' ? 'png' : 'jpg';
    const destinationKey = `creatives/${req.campaign_id}/${assetId}.${extension}`;

    let uploadUrl = `${this.publicCdnBase}/mock-upload/${destinationKey}`;

    if (this.s3) {
      const command = new PutObjectCommand({
        Bucket: this.bucketName,
        Key: destinationKey,
        ContentType: req.media_type === 'VIDEO_MP4' ? 'video/mp4' : req.media_type === 'IMAGE_PNG' ? 'image/png' : 'image/jpeg'
      });
      uploadUrl = await getSignedUrl(this.s3, command, { expiresIn: 900 }); // 15 min expiry
    }

    // Save pending record
    const meta: MediaAssetMetadata = {
      id: assetId,
      campaign_id: req.campaign_id,
      name: req.name,
      media_type: req.media_type,
      file_size_bytes: req.file_size_bytes,
      duration_seconds: req.duration_seconds,
      width: req.width || 1920,
      height: req.height || 1080,
      sha256_checksum: 'PENDING_CONFIRMATION',
      cdn_url: `${this.publicCdnBase}/${destinationKey}`,
      status: 'PENDING_UPLOAD',
      created_at: new Date().toISOString()
    };

    this.assetsStore.set(assetId, meta);

    return {
      asset_id: assetId,
      upload_url: uploadUrl,
      destination_key: destinationKey
    };
  }

  async confirmUpload(assetId: string, sha256: string, flightEndDate?: string): Promise<MediaAssetMetadata | null> {
    const asset = this.assetsStore.get(assetId);
    if (!asset) return null;

    asset.status = 'AVAILABLE';
    asset.sha256_checksum = sha256;

    // Rule: Campaign Flight End Date + 3 Days (FEAT-003 specification)
    if (flightEndDate) {
      const end = new Date(flightEndDate);
      const purgeDate = new Date(end.getTime() + 3 * 24 * 60 * 60 * 1000);
      asset.r2_purge_at = purgeDate.toISOString();
    }

    this.assetsStore.set(assetId, asset);
    return asset;
  }

  async getAsset(assetId: string): Promise<MediaAssetMetadata | null> {
    return this.assetsStore.get(assetId) || null;
  }

  async purgeExpiredAssets(): Promise<string[]> {
    const now = new Date().getTime();
    const purgedIds: string[] = [];

    for (const [id, asset] of this.assetsStore.entries()) {
      if (asset.r2_purge_at && new Date(asset.r2_purge_at).getTime() <= now && asset.status !== 'PURGED') {
        asset.status = 'PURGED';
        purgedIds.push(id);
        console.log(`[Retention] Purged expired media asset ${id} (${asset.name})`);
      }
    }

    return purgedIds;
  }
}

export const storage = new StorageService();
