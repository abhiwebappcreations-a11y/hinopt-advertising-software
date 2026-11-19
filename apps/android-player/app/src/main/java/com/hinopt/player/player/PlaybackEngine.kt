package com.hinopt.player.player

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.hinopt.player.data.db.AppDatabase
import com.hinopt.player.data.db.PlaylistItemEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class PlaybackEngine(
    private val context: Context,
    private val playerView: PlayerView,
    private val scope: CoroutineScope
) : Player.Listener {

    private var exoPlayer: ExoPlayer? = null
    private var currentPlaylist: List<PlaylistItemEntity> = emptyList()
    private var currentIndex: Int = 0
    private var itemStartTimeMs: Long = 0L

    private val db = AppDatabase.getInstance(context)
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    init {
        initializePlayer()
    }

    private fun initializePlayer() {
        val player = ExoPlayer.Builder(context)
            .build()
            .apply {
                repeatMode = Player.REPEAT_MODE_ALL
                volume = 0f // In-auto signage default: Muted
                playWhenReady = true
                addListener(this@PlaybackEngine)
            }

        playerView.player = player
        exoPlayer = player
        Log.i(TAG, "Hardware-accelerated Media3 ExoPlayer initialized.")
    }

    fun submitPlaylist(items: List<PlaylistItemEntity>) {
        if (items.isEmpty()) {
            Log.w(TAG, "Empty playlist submitted. Switching to fallback mode.")
            currentPlaylist = emptyList()
            exoPlayer?.clearMediaItems()
            return
        }

        currentPlaylist = items
        val mediaItems = items.map { item ->
            val uri = if (item.local_path.isNotEmpty() && File(item.local_path).exists()) {
                Uri.fromFile(File(item.local_path))
            } else {
                Uri.parse(item.remote_url)
            }
            MediaItem.fromUri(uri)
        }

        exoPlayer?.apply {
            setMediaItems(mediaItems)
            prepare()
            play()
        }
        itemStartTimeMs = System.currentTimeMillis()
        Log.i(TAG, "Loaded ${items.size} playlist items into ExoPlayer loop.")
    }

    override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
        super.onMediaItemTransition(mediaItem, reason)

        // Record proof-of-play for the item that just finished playing
        if (currentPlaylist.isNotEmpty() && currentIndex < currentPlaylist.size) {
            val finishedItem = currentPlaylist[currentIndex]
            val durationPlayed = ((System.currentTimeMillis() - itemStartTimeMs) / 1000).toInt()
            val completed = durationPlayed >= (finishedItem.duration_seconds - 1)
            val today = dateFormat.format(Date())

            scope.launch(Dispatchers.IO) {
                db.proofOfPlayDao().recordImpression(
                    campaignId = finishedItem.campaign_id,
                    assetId = finishedItem.asset_id,
                    date = today,
                    secondsPlayed = durationPlayed,
                    completed = completed
                )
            }
        }

        currentIndex = exoPlayer?.currentMediaItemIndex ?: 0
        itemStartTimeMs = System.currentTimeMillis()
    }

    override fun onPlayerError(error: PlaybackException) {
        super.onPlayerError(error)
        Log.e(TAG, "Playback error on item index $currentIndex: ${error.message}. Skipping to next.")
        exoPlayer?.seekToNextMediaItem()
    }

    fun release() {
        exoPlayer?.release()
        exoPlayer = null
    }

    companion object {
        private const val TAG = "PlaybackEngine"
    }
}
