package com.hinopt.player.data.model

data class SyncManifest(
    val manifest_version: String,
    val generated_at: String,
    val screen_id: String,
    val tenant_id: String,
    val fallback_mode: String,
    val loop_duration_target_seconds: Int,
    val playlist: List<PlaylistItemModel>,
    val assets_to_download: List<AssetDownloadModel>,
    val assets_to_purge: List<String>
)

data class PlaylistItemModel(
    val asset_id: String,
    val campaign_id: String,
    val url: String,
    val sha256: String,
    val duration_seconds: Int,
    val media_type: String,
    val audio_mode: String?,
    val valid_from: String?,
    val valid_until: String?
)

data class AssetDownloadModel(
    val asset_id: String,
    val url: String,
    val sha256: String,
    val file_size_bytes: Long
)

data class ProofOfPlayEntry(
    val campaign_id: String,
    val asset_id: String,
    val date: String,
    val completed_impressions: Int,
    val total_seconds_played: Int,
    val interrupted_impressions: Int
)
