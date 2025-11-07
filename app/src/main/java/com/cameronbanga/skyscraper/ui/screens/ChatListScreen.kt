package com.cameronbanga.skyscraper.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cameronbanga.skyscraper.models.ConvoView
import com.cameronbanga.skyscraper.services.AppTheme
import com.cameronbanga.skyscraper.ui.components.AvatarImage
import com.cameronbanga.skyscraper.viewmodels.ChatListViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatListScreen(
    viewModel: ChatListViewModel = viewModel(),
    onConversationClick: (ConvoView) -> Unit = {},
    onNewConversationClick: () -> Unit = {}
) {
    val context = LocalContext.current
    val appTheme = remember { AppTheme.getInstance(context) }
    val accentColor by appTheme.accentColor.collectAsState()

    val conversations by viewModel.conversations.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    var showNewConversation by remember { mutableStateOf(false) }

    // Start/stop polling
    DisposableEffect(Unit) {
        if (conversations.isEmpty()) {
            viewModel.loadConversations()
        }
        viewModel.startPolling()

        onDispose {
            viewModel.stopPolling()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Chat") },
                actions = {
                    IconButton(onClick = { showNewConversation = true }) {
                        Icon(
                            Icons.Default.Edit,
                            contentDescription = "New conversation",
                            tint = accentColor
                        )
                    }
                }
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                isLoading && conversations.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
                errorMessage != null -> {
                    ErrorView(
                        message = errorMessage!!,
                        onRetry = { viewModel.loadConversations() }
                    )
                }
                conversations.isEmpty() -> {
                    EmptyStateView(
                        accentColor = accentColor,
                        onNewConversationClick = { showNewConversation = true }
                    )
                }
                else -> {
                    PullToRefreshBox(
                        isRefreshing = isLoading,
                        onRefresh = { viewModel.refreshConversations() }
                    ) {
                        ConversationsList(
                            conversations = conversations,
                            onConversationClick = onConversationClick,
                            onLoadMore = { conversation ->
                                viewModel.loadMoreIfNeeded(conversation)
                            }
                        )
                    }
                }
            }
        }
    }

    // TODO: Implement new conversation dialog/sheet
    if (showNewConversation) {
        AlertDialog(
            onDismissRequest = { showNewConversation = false },
            title = { Text("New Conversation") },
            text = { Text("New conversation feature coming soon!") },
            confirmButton = {
                TextButton(onClick = { showNewConversation = false }) {
                    Text("OK")
                }
            }
        )
    }
}

@Composable
private fun ConversationsList(
    conversations: List<ConvoView>,
    onConversationClick: (ConvoView) -> Unit,
    onLoadMore: (ConvoView) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize()
    ) {
        items(conversations) { conversation ->
            ConversationRow(
                conversation = conversation,
                onClick = { onConversationClick(conversation) }
            )

            LaunchedEffect(conversation.id) {
                onLoadMore(conversation)
            }

            Divider(modifier = Modifier.padding(start = 76.dp))
        }
    }
}

@Composable
private fun ConversationRow(
    conversation: ConvoView,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Avatar (use first member's avatar)
        val firstMember = conversation.members.firstOrNull()
        AvatarImage(
            url = firstMember?.avatar,
            size = 48.dp
        )

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = firstMember?.displayName ?: firstMember?.handle ?: "Unknown",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )

                conversation.lastMessage?.let { lastMsg ->
                    Text(
                        text = formatTimestamp(lastMsg.sentAt),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            conversation.lastMessage?.let { lastMsg ->
                Text(
                    text = when (lastMsg) {
                        is com.cameronbanga.skyscraper.models.MessageUnion.MessageView ->
                            lastMsg.message.text ?: ""
                        is com.cameronbanga.skyscraper.models.MessageUnion.DeletedMessageView ->
                            "Message deleted"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Unread indicator
            if (conversation.unreadCount > 0) {
                Surface(
                    shape = MaterialTheme.shapes.small,
                    color = MaterialTheme.colorScheme.primary
                ) {
                    Text(
                        text = conversation.unreadCount.toString(),
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                }
            }
        }
    }
}

@Composable
private fun EmptyStateView(
    accentColor: androidx.compose.ui.graphics.Color,
    onNewConversationClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.Email,
            contentDescription = null,
            modifier = Modifier.size(60.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "No conversations yet",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Start a new conversation to get started",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = onNewConversationClick,
            colors = ButtonDefaults.buttonColors(containerColor = accentColor)
        ) {
            Icon(Icons.Default.Edit, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("New Conversation")
        }
    }
}

@Composable
private fun ErrorView(
    message: String,
    onRetry: () -> Unit
) {
    val isNotEnabledError = message.contains("Not Enabled", ignoreCase = true)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            if (isNotEnabledError) Icons.Default.Lock else Icons.Default.Warning,
            contentDescription = null,
            modifier = Modifier.size(60.dp),
            tint = if (isNotEnabledError) {
                MaterialTheme.colorScheme.tertiary
            } else {
                MaterialTheme.colorScheme.error
            }
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Parse title and body if message contains newline
        val parts = message.split("\n", limit = 2)
        if (parts.size > 1) {
            Text(
                text = parts[0],
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = parts[1],
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        } else {
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }

        if (!isNotEnabledError) {
            Spacer(modifier = Modifier.height(24.dp))
            Button(onClick = onRetry) {
                Text("Retry")
            }
        }
    }
}

private fun formatTimestamp(timestamp: String): String {
    return try {
        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
        val date = sdf.parse(timestamp) ?: return ""
        val now = System.currentTimeMillis()
        val diff = now - date.time

        when {
            diff < 60_000 -> "now"
            diff < 3600_000 -> "${diff / 60_000}m"
            diff < 86400_000 -> "${diff / 3600_000}h"
            diff < 604800_000 -> "${diff / 86400_000}d"
            else -> SimpleDateFormat("MMM d", Locale.getDefault()).format(date)
        }
    } catch (e: Exception) {
        ""
    }
}
