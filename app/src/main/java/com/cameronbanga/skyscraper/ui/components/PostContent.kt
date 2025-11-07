package com.cameronbanga.skyscraper.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.ClickableText
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.cameronbanga.skyscraper.models.Post

/**
 * Reusable component for displaying post content (text, images, links, etc.)
 */
@Composable
fun PostContent(
    post: Post,
    onHashtagClick: (String) -> Unit = {},
    onProfileClick: (String) -> Unit = {},
    onLinkClick: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Post text with clickable hashtags and mentions
        val annotatedText = buildAnnotatedString {
            val text = post.record.text
            var lastIndex = 0

            // Find hashtags
            val hashtagRegex = """#\w+""".toRegex()
            hashtagRegex.findAll(text).forEach { match ->
                // Add regular text before hashtag
                append(text.substring(lastIndex, match.range.first))

                // Add clickable hashtag
                pushStringAnnotation(
                    tag = "hashtag",
                    annotation = match.value.substring(1) // Remove #
                )
                withStyle(
                    style = SpanStyle(
                        color = MaterialTheme.colorScheme.primary,
                        textDecoration = TextDecoration.None
                    )
                ) {
                    append(match.value)
                }
                pop()

                lastIndex = match.range.last + 1
            }

            // Find mentions
            val mentionRegex = """@[\w.]+""".toRegex()
            mentionRegex.findAll(text.substring(lastIndex)).forEach { match ->
                val actualIndex = lastIndex + match.range.first
                append(text.substring(lastIndex, actualIndex))

                pushStringAnnotation(
                    tag = "mention",
                    annotation = match.value.substring(1) // Remove @
                )
                withStyle(
                    style = SpanStyle(
                        color = MaterialTheme.colorScheme.primary,
                        textDecoration = TextDecoration.None
                    )
                ) {
                    append(match.value)
                }
                pop()

                lastIndex = actualIndex + match.value.length
            }

            // Add remaining text
            append(text.substring(lastIndex))
        }

        ClickableText(
            text = annotatedText,
            style = MaterialTheme.typography.bodyLarge.copy(
                color = MaterialTheme.colorScheme.onSurface
            ),
            onClick = { offset ->
                annotatedText.getStringAnnotations(
                    tag = "hashtag",
                    start = offset,
                    end = offset
                ).firstOrNull()?.let { annotation ->
                    onHashtagClick(annotation.item)
                }

                annotatedText.getStringAnnotations(
                    tag = "mention",
                    start = offset,
                    end = offset
                ).firstOrNull()?.let { annotation ->
                    onProfileClick(annotation.item)
                }
            }
        )

        // Images
        post.embed?.images?.let { images ->
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
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onLinkClick(external.uri) },
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

        // Video embed
        post.embed?.video?.let { video ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Box {
                    video.thumbnail?.let { thumbnail ->
                        AsyncImage(
                            model = thumbnail,
                            contentDescription = null,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(200.dp),
                            contentScale = ContentScale.Crop
                        )
                    }
                    // TODO: Add play button overlay and video player
                }
            }
        }
    }
}
