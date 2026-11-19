package com.hinopt.player.data.db

import androidx.room.*

@Dao
interface ProofOfPlayDao {

    @Query("SELECT * FROM proof_of_play_tallies WHERE is_uploaded = 0")
    suspend fun getPendingUploads(): List<ProofOfPlayEntity>

    @Query("SELECT * FROM proof_of_play_tallies WHERE campaign_id = :campaignId AND asset_id = :assetId AND play_date = :date LIMIT 1")
    suspend fun findRecord(campaignId: String, assetId: String, date: String): ProofOfPlayEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(entry: ProofOfPlayEntity)

    @Transaction
    suspend fun recordImpression(campaignId: String, assetId: String, date: String, secondsPlayed: Int, completed: Boolean) {
        val existing = findRecord(campaignId, assetId, date)
        if (existing == null) {
            insertOrUpdate(
                ProofOfPlayEntity(
                    campaign_id = campaignId,
                    asset_id = assetId,
                    play_date = date,
                    completed_impressions = if (completed) 1 else 0,
                    total_seconds_played = secondsPlayed,
                    interrupted_impressions = if (completed) 0 else 1,
                    is_uploaded = false
                )
            )
        } else {
            existing.total_seconds_played += secondsPlayed
            if (completed) {
                existing.completed_impressions += 1
            } else {
                existing.interrupted_impressions += 1
            }
            existing.is_uploaded = false
            insertOrUpdate(existing)
        }
    }

    @Query("UPDATE proof_of_play_tallies SET is_uploaded = 1 WHERE campaign_id = :campaignId AND asset_id = :assetId AND play_date = :date")
    suspend fun markUploaded(campaignId: String, assetId: String, date: String)
}
