package com.hinopt.player.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "playlist_items")
data class PlaylistItemEntity(
    @PrimaryKey val asset_id: String,
    val campaign_id: String,
    val local_path: String,
    val remote_url: String,
    val sha256: String,
    val duration_seconds: Int,
    val media_type: String,
    val audio_mode: String,
    val sequence_order: Int,
    val is_downloaded: Boolean
)

@Entity(tableName = "proof_of_play_tallies", primaryKeys = ["campaign_id", "asset_id", "play_date"])
data class ProofOfPlayEntity(
    val campaign_id: String,
    val asset_id: String,
    val play_date: String, // YYYY-MM-DD
    var completed_impressions: Int = 0,
    var total_seconds_played: Int = 0,
    var interrupted_impressions: Int = 0,
    var is_uploaded: Boolean = false
)

@Entity(tableName = "screen_config")
data class ScreenConfigEntity(
    @PrimaryKey val key: String,
    val value: String
)
