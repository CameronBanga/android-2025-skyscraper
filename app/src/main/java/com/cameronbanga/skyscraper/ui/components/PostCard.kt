package com.cameronbanga.skyscraper.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.cameronbanga.skyscraper.models.FeedViewPost
import com.cameronbanga.skyscraper.models.Post
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

@Composable
fun PostCard(
    feedPost: FeedViewPost,
    onPostClick: (FeedViewPost) -> Unit,
    onProfileClick: (String) -> Unit,
    onLikeClick: () -> Unit,
    onRepostClick: () -> Unit,
    onReplyClick: () -> Unit,
    onShareClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val post = feedPost.post

    Surface(
        modifier = modifier.clickable { onPostClick(feedPost) },
        color = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // Repost indicator
            feedPost.reason?.by?.let { reposter ->
                Row(
                    modifier = Modifier.padding(bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Repeat,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "${reposter.displayName ?: reposter.safeHandle} reposted",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // Author info
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top
            ) {
                // Avatar
                AsyncImage(
                    model = post.author.avatar,
                    contentDescription = "Avatar",
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .clickable { onProfileClick(post.author.safeHandle) },
                    contentScale = ContentScale.Crop
                )

                Spacer(modifier = Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    // Name and handle
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = post.author.displayName ?: post.author.safeHandle,
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = "@${post.author.safeHandle}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }

                        // Timestamp
                        Text(
                            text = formatRelativeTime(post.createdAt),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // Post text
                    Text(
                        text = post.record.text,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface
                    )

                    // Images
                    post.embed?.images?.let { images ->
                        Spacer(modifier = Modifier.height(8.dp))
                        when (images.size) {
                            1 -> {
                                AsyncImage(
                                    model = images[0].fullsize,
                                    contentDescription = images[0].alt,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(300.dp)
                                        .clip(MaterialTheme.shapes.medium),
                                    contentScale = ContentScale.Crop
                                )
                            }
                            2 -> {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    images.forEach { image ->
                                        AsyncImage(
                                            model = image.fullsize,
                                            contentDescription = image.alt,
                                            modifier = Modifier
                                                .weight(1f)
                                                .height(150.dp)
                                                .clip(MaterialTheme.shapes.medium),
                                            contentScale = ContentScale.Crop
                                        )
                                    }
                                }
                            }
                            3 -> {
                                Column(
                                    verticalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    AsyncImage(
                                        model = images[0].fullsize,
                                        contentDescription = images[0].alt,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(148.dp)
                                            .clip(MaterialTheme.shapes.medium),
                                        contentScale = ContentScale.Crop
                                    )
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        images.drop(1).forEach { image ->
                                            AsyncImage(
                                                model = image.fullsize,
                                                contentDescription = image.alt,
                                                modifier = Modifier
                                                    .weight(1f)
                                                    .height(148.dp)
                                                    .clip(MaterialTheme.shapes.medium),
                                                contentScale = ContentScale.Crop
                                            )
                                        }
                                    }
                                }
                            }
                            4 -> {
                                Column(
                                    verticalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        images.take(2).forEach { image ->
                                            AsyncImage(
                                                model = image.fullsize,
                                                contentDescription = image.alt,
                                                modifier = Modifier
                                                    .weight(1f)
                                                    .height(148.dp)
                                                    .clip(MaterialTheme.shapes.medium),
                                                contentScale = ContentScale.Crop
                                            )
                                        }
                                    }
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        images.drop(2).forEach { image ->
                                            AsyncImage(
                                                model = image.fullsize,
                                                contentDescription = image.alt,
                                                modifier = Modifier
                                                    .weight(1f)
                                                    .height(148.dp)
                                                    .clip(MaterialTheme.shapes.medium),
                                                contentScale = ContentScale.Crop
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // External link preview
                    post.embed?.external?.let { external ->
                        Spacer(modifier = Modifier.height(8.dp))
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant
                            )
                        ) {
                            Column {
                                external.thumb?.let { thumb ->
                                    AsyncImage(
                                        model = thumb,
                                        contentDescription = null,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(200.dp),
                                        contentScale = ContentScale.Crop
                                    )
                                }
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Text(
                                        text = external.title,
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.Bold,
                                        maxLines = 2,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = external.description,
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 2,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = external.uri,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // Action buttons
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        // Reply
                        ActionButton(
                            icon = Icons.Outlined.ChatBubbleOutline,
                            count = post.replyCount,
                            onClick = onReplyClick
                        )

                        // Repost
                        val isReposted = post.viewer?.repost != null
                        ActionButton(
                            icon = if (isReposted) Icons.Default.Repeat else Icons.Outlined.Repeat,
                            count = post.repostCount,
                            isActive = isReposted,
                            activeColor = MaterialTheme.colorScheme.tertiary,
                            onClick = onRepostClick
                        )

                        // Like
                        val isLiked = post.viewer?.like != null
                        ActionButton(
                            icon = if (isLiked) Icons.Default.Favorite else Icons.Outlined.FavoriteBorder,
                            count = post.likeCount,
                            isActive = isLiked,
                            activeColor = MaterialTheme.colorScheme.error,
                            onClick = onLikeClick
                        )

                        // Share
                        IconButton(onClick = onShareClick) {
                            Icon(
                                Icons.Outlined.Share,
                                contentDescription = "Share",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    count: Int?,
    isActive: Boolean = false,
    activeColor: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.primary,
    onClick: () -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.clickable(onClick = onClick)
    ) {
        IconButton(onClick = onClick) {
            Icon(
                icon,
                contentDescription = null,
                tint = if (isActive) activeColor else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (count != null && count > 0) {
            Text(
                text = formatCount(count),
                style = MaterialTheme.typography.bodySmall,
                color = if (isActive) activeColor else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun formatCount(count: Int): String {
    return when {
        count >= 1000000 -> String.format("%.1fM", count / 1000000.0)
        count >= 1000 -> String.format("%.1fK", count / 1000.0)
        else -> count.toString()
    }
}

private fun formatRelativeTime(instant: Instant): String {
    val now = Instant.now()
    val seconds = ChronoUnit.SECONDS.between(instant, now)

    return when {
        seconds < 60 -> "now"
        seconds < 3600 -> "${seconds / 60}m"
        seconds < 86400 -> "${seconds / 3600}h"
        seconds < 604800 -> "${seconds / 86400}d"
        else -> {
            val formatter = DateTimeFormatter.ofPattern("MMM d")
                .withZone(ZoneId.systemDefault())
            formatter.format(instant)
        }
    }
}
