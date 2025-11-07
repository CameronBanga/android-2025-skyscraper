package com.cameronbanga.skyscraper.ui.screens

import com.cameronbanga.skyscraper.ui.components.PostCard
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cameronbanga.skyscraper.models.FeedViewPost
import com.cameronbanga.skyscraper.viewmodels.TimelineViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimelineScreen(
    viewModel: TimelineViewModel = viewModel(),
    onProfileClick: (String) -> Unit = {},
    onPostClick: (String) -> Unit = {},
    onSettingsClick: () -> Unit = {}
) {
    val state by viewModel.state.collectAsState()
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = state.selectedFeed?.displayName ?: "Timeline",
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onSettingsClick) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                },
                actions = {
                    IconButton(onClick = { /* TODO: Moderation settings */ }) {
                        Icon(Icons.Default.Shield, contentDescription = "Moderation")
                    }
                }
            )
        },
        floatingActionButton = {
            // New post FAB
            FloatingActionButton(
                onClick = { /* TODO: Open composer */ }
            ) {
                Icon(Icons.Default.Edit, contentDescription = "New Post")
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            when {
                state.isLoading && state.posts.isEmpty() -> {
                    // Initial loading
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            CircularProgressIndicator()
                            Spacer(modifier = Modifier.height(16.dp))
                            Text("Loading timeline...")
                        }
                    }
                }
                state.errorMessage != null && state.posts.isEmpty() -> {
                    // Error state
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(24.dp)
                        ) {
                            Icon(
                                Icons.Default.Error,
                                contentDescription = null,
                                modifier = Modifier.size(48.dp),
                                tint = MaterialTheme.colorScheme.error
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = state.errorMessage ?: "An error occurred",
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(
                                onClick = {
                                    scope.launch { viewModel.loadTimeline() }
                                }
                            ) {
                                Text("Retry")
                            }
                        }
                    }
                }
                state.posts.isEmpty() -> {
                    // Empty state
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Your timeline is empty",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                else -> {
                    // Posts list
                    PullToRefreshBox(
                        isRefreshing = state.isRefreshing,
                        onRefresh = {
                            scope.launch { viewModel.refresh() }
                        }
                    ) {
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.fillMaxSize()
                        ) {
                            items(
                                items = state.posts,
                                key = { it.id }
                            ) { feedPost ->
                                PostCard(
                                    feedPost = feedPost,
                                    onPostClick = { onPostClick(it.post.uri) },
                                    onProfileClick = { onProfileClick(it) },
                                    onLikeClick = {
                                        scope.launch { viewModel.toggleLike(feedPost) }
                                    },
                                    onRepostClick = {
                                        scope.launch { viewModel.toggleRepost(feedPost) }
                                    },
                                    onReplyClick = { /* TODO */ },
                                    onShareClick = { /* TODO */ },
                                    modifier = Modifier.fillMaxWidth()
                                )

                                Divider()

                                // Mark as seen when visible
                                LaunchedEffect(feedPost.post.uri) {
                                    viewModel.markPostAsSeen(feedPost.post.uri)
                                    viewModel.prefetchImagesForUpcomingPosts(feedPost.id)
                                }
                            }

                            // Load more indicator
                            if (state.cursor != null) {
                                item {
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(16.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        CircularProgressIndicator()
                                    }

                                    LaunchedEffect(Unit) {
                                        viewModel.loadMore()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Unseen posts banner
            if (state.unseenPostsCount > 0) {
                Surface(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 8.dp)
                        .clickable {
                            viewModel.insertPendingPosts()
                            scope.launch {
                                listState.animateScrollToItem(0)
                            }
                        },
                    shape = MaterialTheme.shapes.medium,
                    tonalElevation = 2.dp,
                    color = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.ArrowUpward,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "${state.unseenPostsCount} new post${if (state.unseenPostsCount > 1) "s" else ""}",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                }
            }

            // Background fetch error banner
            state.backgroundFetchError?.let { error ->
                Surface(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(16.dp)
                        .fillMaxWidth()
                        .clickable {
                            scope.launch {
                                viewModel.startBackgroundFetching()
                            }
                        },
                    shape = MaterialTheme.shapes.medium,
                    tonalElevation = 2.dp,
                    color = MaterialTheme.colorScheme.errorContainer
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Warning,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onErrorContainer
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = error,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }
    }
}
