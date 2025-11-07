package com.cameronbanga.skyscraper.ui.screens

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cameronbanga.skyscraper.models.FeedGenerator
import com.cameronbanga.skyscraper.services.AppTheme
import com.cameronbanga.skyscraper.ui.components.AvatarImage
import com.cameronbanga.skyscraper.viewmodels.FeedBrowserViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedBrowserScreen(
    viewModel: FeedBrowserViewModel = viewModel(),
    onBack: () -> Unit = {},
    onFeedClick: (FeedGenerator) -> Unit = {}
) {
    val context = LocalContext.current
    val appTheme = remember { AppTheme.getInstance(context) }
    val accentColor by appTheme.accentColor.collectAsState()

    val feeds by viewModel.feeds.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val savedFeedURIs by viewModel.savedFeedURIs.collectAsState()
    val isTogglingFeed by viewModel.isTogglingFeed.collectAsState()

    var searchText by remember { mutableStateOf("") }

    val filteredFeeds = remember(feeds, searchText) {
        if (searchText.isEmpty()) {
            feeds
        } else {
            feeds.filter { feed ->
                feed.displayName.contains(searchText, ignoreCase = true) ||
                (feed.description?.contains(searchText, ignoreCase = true) == true) ||
                feed.creator.handle.contains(searchText, ignoreCase = true)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Browse Feeds") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Search bar
            OutlinedTextField(
                value = searchText,
                onValueChange = { searchText = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                placeholder = { Text("Search feeds") },
                leadingIcon = {
                    Icon(Icons.Default.Search, contentDescription = null)
                },
                trailingIcon = {
                    if (searchText.isNotEmpty()) {
                        IconButton(onClick = { searchText = "" }) {
                            Icon(Icons.Default.Close, contentDescription = "Clear")
                        }
                    }
                },
                singleLine = true
            )

            when {
                isLoading && feeds.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            CircularProgressIndicator()
                            Text("Loading feeds...")
                        }
                    }
                }
                errorMessage != null -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                            modifier = Modifier.padding(horizontal = 32.dp)
                        ) {
                            Icon(
                                Icons.Default.Warning,
                                contentDescription = null,
                                modifier = Modifier.size(48.dp),
                                tint = MaterialTheme.colorScheme.error
                            )
                            Text(
                                text = "Unable to load feeds",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = errorMessage!!,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center
                            )
                            Button(onClick = { viewModel.loadFeeds() }) {
                                Text("Try Again")
                            }
                        }
                    }
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = 8.dp)
                    ) {
                        items(filteredFeeds) { feed ->
                            FeedRow(
                                feed = feed,
                                isSaved = savedFeedURIs.contains(feed.uri),
                                isToggling = isTogglingFeed == feed.uri,
                                accentColor = accentColor,
                                onFeedClick = { onFeedClick(feed) },
                                onToggleSave = { viewModel.toggleSaveFeed(feed.uri) }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FeedRow(
    feed: FeedGenerator,
    isSaved: Boolean,
    isToggling: Boolean,
    accentColor: Color,
    onFeedClick: () -> Unit,
    onToggleSave: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Feed avatar
        if (feed.avatar != null) {
            AvatarImage(
                url = feed.avatar,
                size = 50.dp
            )
        } else {
            Surface(
                modifier = Modifier.size(50.dp),
                shape = CircleShape,
                color = accentColor.copy(alpha = 0.2f)
            ) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.RssFeed,
                        contentDescription = null,
                        tint = accentColor
                    )
                }
            }
        }

        // Feed info
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = feed.displayName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold
            )

            Text(
                text = "by @${feed.creator.handle}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            if (feed.likeCount != null && feed.likeCount!! > 0) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Favorite,
                        contentDescription = null,
                        modifier = Modifier.size(12.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = feed.likeCount.toString(),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            if (feed.description != null && feed.description.isNotEmpty()) {
                Text(
                    text = feed.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 3
                )
            }
        }

        // Save button
        if (isToggling) {
            Box(
                modifier = Modifier
                    .width(70.dp)
                    .height(36.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp))
            }
        } else {
            Button(
                onClick = onToggleSave,
                modifier = Modifier
                    .width(70.dp)
                    .height(36.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isSaved) accentColor else Color.Transparent,
                    contentColor = if (isSaved) Color.White else accentColor
                ),
                border = if (!isSaved) androidx.compose.foundation.BorderStroke(
                    1.dp,
                    accentColor
                ) else null,
                contentPadding = PaddingValues(0.dp)
            ) {
                Text(
                    text = if (isSaved) "Saved" else "Save",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}
