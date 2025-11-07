package com.cameronbanga.skyscraper.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cameronbanga.skyscraper.models.Post
import com.cameronbanga.skyscraper.models.ThreadViewPost
import com.cameronbanga.skyscraper.services.AppTheme
import com.cameronbanga.skyscraper.ui.components.AvatarImage
import com.cameronbanga.skyscraper.ui.components.PostContent
import com.cameronbanga.skyscraper.utils.DateUtils
import com.cameronbanga.skyscraper.viewmodels.PostDetailViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostDetailScreen(
    postUri: String,
    viewModel: PostDetailViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
                @Suppress("UNCHECKED_CAST")
                return PostDetailViewModel(
                    application = LocalContext.current.applicationContext as android.app.Application,
                    postUri = postUri
                ) as T
            }
        }
    ),
    onBack: () -> Unit = {},
    onProfileClick: (String) -> Unit = {},
    onPostClick: (String) -> Unit = {},
    onReplyClick: (Post) -> Unit = {},
    onHashtagClick: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val appTheme = remember { AppTheme.getInstance(context) }
    val accentColor by appTheme.accentColor.collectAsState()

    val thread by viewModel.thread.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val expandedReplies by viewModel.expandedReplies.collectAsState()
    val loadingNestedThreads by viewModel.loadingNestedThreads.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Thread") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        when {
            isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            errorMessage != null -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Icon(
                            Icons.Default.Warning,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.error
                        )
                        Text(
                            text = errorMessage!!,
                            textAlign = TextAlign.Center
                        )
                        Button(onClick = { viewModel.loadThread() }) {
                            Text("Retry")
                        }
                    }
                }
            }
            thread != null -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                ) {
                    // Parent chain
                    val parentChain = viewModel.getParentChain(thread!!)
                    items(parentChain) { parentPost ->
                        ThreadPostItem(
                            threadPost = parentPost,
                            isMainPost = false,
                            accentColor = accentColor,
                            onProfileClick = onProfileClick,
                            onPostClick = { onPostClick(parentPost.post.uri) },
                            onLikeClick = { viewModel.likePost(parentPost.post) },
                            onRepostClick = { viewModel.repostPost(parentPost.post) },
                            onReplyClick = { onReplyClick(parentPost.post) },
                            onHashtagClick = onHashtagClick,
                            showConnector = true
                        )
                    }

                    // Main post (highlighted)
                    item {
                        ThreadPostItem(
                            threadPost = thread!!,
                            isMainPost = true,
                            accentColor = accentColor,
                            onProfileClick = onProfileClick,
                            onPostClick = { onPostClick(thread!!.post.uri) },
                            onLikeClick = { viewModel.likePost(thread!!.post) },
                            onRepostClick = { viewModel.repostPost(thread!!.post) },
                            onReplyClick = { onReplyClick(thread!!.post) },
                            onHashtagClick = onHashtagClick,
                            showConnector = thread!!.replies?.isNotEmpty() == true
                        )
                    }

                    // Replies
                    thread!!.replies?.let { replies ->
                        items(replies) { reply ->
                            ThreadReplyTree(
                                threadPost = reply,
                                depth = 0,
                                accentColor = accentColor,
                                expandedReplies = expandedReplies,
                                loadingNestedThreads = loadingNestedThreads,
                                onProfileClick = onProfileClick,
                                onPostClick = onPostClick,
                                onLikeClick = { viewModel.likePost(it) },
                                onRepostClick = { viewModel.repostPost(it) },
                                onReplyClick = onReplyClick,
                                onHashtagClick = onHashtagClick,
                                onShowMoreReplies = { viewModel.toggleRepliesExpansion(it) },
                                onLoadNestedReplies = { viewModel.loadNestedReplies(it) },
                                shouldShowMoreReplies = { postUri, replies ->
                                    viewModel.shouldShowMoreReplies(postUri, replies)
                                },
                                getVisibleReplies = { postUri, replies ->
                                    viewModel.getVisibleReplies(postUri, replies)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ThreadPostItem(
    threadPost: ThreadViewPost,
    isMainPost: Boolean,
    accentColor: Color,
    onProfileClick: (String) -> Unit,
    onPostClick: () -> Unit,
    onLikeClick: () -> Unit,
    onRepostClick: () -> Unit,
    onReplyClick: () -> Unit,
    onHashtagClick: (String) -> Unit,
    showConnector: Boolean
) {
    val post = threadPost.post

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .then(
                if (isMainPost) {
                    Modifier.background(accentColor.copy(alpha = 0.1f))
                } else {
                    Modifier
                }
            )
            .clickable { onPostClick() }
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Avatar with connector line
            Box {
                AvatarImage(
                    url = post.author.avatar,
                    size = 48.dp,
                    modifier = Modifier.clickable { onProfileClick(post.author.handle) }
                )

                // Connector line to next post
                if (showConnector) {
                    Box(
                        modifier = Modifier
                            .width(2.dp)
                            .height(48.dp)
                            .offset(x = 23.dp, y = 48.dp)
                            .background(MaterialTheme.colorScheme.outlineVariant)
                    )
                }
            }

            // Post content
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Author info
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = post.author.displayName ?: post.author.handle,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = "@${post.author.handle}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Text(
                        text = DateUtils.formatRelativeTime(post.record.createdAt),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                // Post text and embeds
                PostContent(
                    post = post,
                    onHashtagClick = onHashtagClick,
                    onProfileClick = onProfileClick
                )

                // Action buttons
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    ActionButton(
                        icon = Icons.Default.ChatBubbleOutline,
                        count = post.replyCount,
                        onClick = onReplyClick
                    )
                    ActionButton(
                        icon = if (post.viewer?.repost != null) Icons.Default.Repeat else Icons.Default.Repeat,
                        count = post.repostCount,
                        isActive = post.viewer?.repost != null,
                        activeColor = Color(0xFF00BA7C),
                        onClick = onRepostClick
                    )
                    ActionButton(
                        icon = if (post.viewer?.like != null) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                        count = post.likeCount,
                        isActive = post.viewer?.like != null,
                        activeColor = Color(0xFFE0245E),
                        onClick = onLikeClick
                    )
                    IconButton(onClick = { /* Share */ }) {
                        Icon(
                            Icons.Default.Share,
                            contentDescription = "Share",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ThreadReplyTree(
    threadPost: ThreadViewPost,
    depth: Int,
    accentColor: Color,
    expandedReplies: Set<String>,
    loadingNestedThreads: Set<String>,
    onProfileClick: (String) -> Unit,
    onPostClick: (String) -> Unit,
    onLikeClick: (Post) -> Unit,
    onRepostClick: (Post) -> Unit,
    onReplyClick: (Post) -> Unit,
    onHashtagClick: (String) -> Unit,
    onShowMoreReplies: (String) -> Unit,
    onLoadNestedReplies: (String) -> Unit,
    shouldShowMoreReplies: (String, List<ThreadViewPost>?) -> Boolean,
    getVisibleReplies: (String, List<ThreadViewPost>?) -> List<ThreadViewPost>
) {
    val post = threadPost.post
    val indentWidth = (depth * 16).dp

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = indentWidth)
    ) {
        // Reply post
        ThreadPostItem(
            threadPost = threadPost,
            isMainPost = false,
            accentColor = accentColor,
            onProfileClick = onProfileClick,
            onPostClick = { onPostClick(post.uri) },
            onLikeClick = { onLikeClick(post) },
            onRepostClick = { onRepostClick(post) },
            onReplyClick = { onReplyClick(post) },
            onHashtagClick = onHashtagClick,
            showConnector = threadPost.replies?.isNotEmpty() == true
        )

        // Nested replies
        val visibleReplies = getVisibleReplies(post.uri, threadPost.replies)
        visibleReplies.forEach { nestedReply ->
            ThreadReplyTree(
                threadPost = nestedReply,
                depth = depth + 1,
                accentColor = accentColor,
                expandedReplies = expandedReplies,
                loadingNestedThreads = loadingNestedThreads,
                onProfileClick = onProfileClick,
                onPostClick = onPostClick,
                onLikeClick = onLikeClick,
                onRepostClick = onRepostClick,
                onReplyClick = onReplyClick,
                onHashtagClick = onHashtagClick,
                onShowMoreReplies = onShowMoreReplies,
                onLoadNestedReplies = onLoadNestedReplies,
                shouldShowMoreReplies = shouldShowMoreReplies,
                getVisibleReplies = getVisibleReplies
            )
        }

        // Show more replies button (client-side pagination)
        if (shouldShowMoreReplies(post.uri, threadPost.replies)) {
            TextButton(
                onClick = { onShowMoreReplies(post.uri) },
                modifier = Modifier.padding(start = 16.dp + indentWidth)
            ) {
                Text(
                    "Show ${threadPost.replies!!.size - 3} more replies",
                    color = accentColor
                )
            }
        }

        // Load nested replies button (server-side pagination)
        if (threadPost.replyCount != null &&
            threadPost.replyCount!! > (threadPost.replies?.size ?: 0)) {

            if (loadingNestedThreads.contains(post.uri)) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                }
            } else {
                TextButton(
                    onClick = { onLoadNestedReplies(post.uri) },
                    modifier = Modifier.padding(start = 16.dp + indentWidth)
                ) {
                    Text(
                        "Load more replies",
                        color = accentColor
                    )
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
    activeColor: Color = MaterialTheme.colorScheme.primary,
    onClick: () -> Unit
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
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
                text = count.toString(),
                style = MaterialTheme.typography.bodySmall,
                color = if (isActive) activeColor else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
