package com.cameronbanga.skyscraper.ui.screens

import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import coil.compose.AsyncImage
import com.cameronbanga.skyscraper.models.VideoView

/**
 * Video player component for HLS video playback
 *
 * Note: This is a simplified version of the iOS VideoPlayerView.
 * Uses Media3 ExoPlayer for HLS playback.
 */
@Composable
fun VideoPlayerComponent(
    video: VideoView,
    modifier: Modifier = Modifier,
    autoPlay: Boolean = true
) {
    val context = LocalContext.current

    // Create ExoPlayer
    val exoPlayer = remember {
        ExoPlayer.Builder(context).build().apply {
            val mediaItem = MediaItem.fromUri(video.playlist)
            setMediaItem(mediaItem)
            prepare()
            repeatMode = Player.REPEAT_MODE_ONE // Loop video
            volume = 0f // Start muted
        }
    }

    var isPlayerReady by remember { mutableStateOf(false) }
    var showControls by remember { mutableStateOf(true) }

    // Setup player listener
    DisposableEffect(exoPlayer) {
        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                isPlayerReady = playbackState == Player.STATE_READY
            }
        }
        exoPlayer.addListener(listener)

        // Auto-play if enabled
        if (autoPlay && isPlayerReady) {
            exoPlayer.playWhenReady = true
        }

        onDispose {
            exoPlayer.removeListener(listener)
            exoPlayer.release()
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(
                video.aspectRatio?.let { it.width.toFloat() / it.height.toFloat() } ?: 16f / 9f
            )
            .clip(RoundedCornerShape(12.dp))
            .background(Color.Black)
    ) {
        when {
            isPlayerReady -> {
                // Video player
                AndroidView(
                    factory = { context ->
                        PlayerView(context).apply {
                            player = exoPlayer
                            useController = false // Use custom controls
                            layoutParams = FrameLayout.LayoutParams(
                                ViewGroup.LayoutParams.MATCH_PARENT,
                                ViewGroup.LayoutParams.MATCH_PARENT
                            )
                        }
                    },
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable {
                            if (exoPlayer.isPlaying) {
                                exoPlayer.pause()
                            } else {
                                exoPlayer.play()
                            }
                            showControls = !showControls
                        }
                )

                // Play/Pause overlay
                if (showControls) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        IconButton(
                            onClick = {
                                if (exoPlayer.isPlaying) {
                                    exoPlayer.pause()
                                } else {
                                    exoPlayer.play()
                                    exoPlayer.volume = 1f // Unmute when user plays
                                }
                            },
                            modifier = Modifier
                                .size(60.dp)
                                .background(Color.Black.copy(alpha = 0.5f), CircleShape)
                        ) {
                            Icon(
                                if (exoPlayer.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                                contentDescription = if (exoPlayer.isPlaying) "Pause" else "Play",
                                tint = Color.White,
                                modifier = Modifier.size(40.dp)
                            )
                        }
                    }
                }

                // Volume control
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                ) {
                    IconButton(
                        onClick = {
                            exoPlayer.volume = if (exoPlayer.volume > 0f) 0f else 1f
                        },
                        modifier = Modifier
                            .size(36.dp)
                            .background(Color.Black.copy(alpha = 0.5f), CircleShape)
                    ) {
                        Icon(
                            if (exoPlayer.volume > 0f) Icons.Default.VolumeUp else Icons.Default.VolumeOff,
                            contentDescription = if (exoPlayer.volume > 0f) "Mute" else "Unmute",
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
            else -> {
                // Show thumbnail while loading
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    if (video.thumbnail != null) {
                        AsyncImage(
                            model = video.thumbnail,
                            contentDescription = "Video thumbnail",
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(Color.Gray.copy(alpha = 0.3f))
                        )
                    }

                    // Play button overlay
                    Icon(
                        Icons.Default.PlayCircle,
                        contentDescription = "Play",
                        tint = Color.White,
                        modifier = Modifier.size(50.dp)
                    )

                    // Loading indicator
                    if (!isPlayerReady) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(50.dp),
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}
