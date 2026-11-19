package com.hinopt.player.data.db

import androidx.room.*

@Dao
interface PlaylistItemDao {

    @Query("SELECT * FROM playlist_items ORDER BY sequence_order ASC")
    suspend fun getAllPlaylistItems(): List<PlaylistItemEntity>

    @Query("SELECT * FROM playlist_items WHERE is_downloaded = 1 ORDER BY sequence_order ASC")
    suspend fun getPlayableItems(): List<PlaylistItemEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(items: List<PlaylistItemEntity>)

    @Query("UPDATE playlist_items SET is_downloaded = 1, local_path = :localPath WHERE asset_id = :assetId")
    suspend fun markAssetDownloaded(assetId: String, localPath: String)

    @Query("DELETE FROM playlist_items WHERE asset_id NOT IN (:validAssetIds)")
    suspend fun purgeOldAssets(validAssetIds: List<String>)

    @Query("DELETE FROM playlist_items")
    suspend fun clearAll()
}
