package com.cameronbanga.skyscraper.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cameronbanga.skyscraper.models.ConvoView
import com.cameronbanga.skyscraper.models.MessageUnion
import com.cameronbanga.skyscraper.services.ATProtoClient
import com.cameronbanga.skyscraper.services.AppTheme
import com.cameronbanga.skyscraper.ui.components.AvatarImage
import com.cameronbanga.skyscraper.viewmodels.ChatViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    conversation: ConvoView,
    viewModel: ChatViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
                @Suppress("UNCHECKED_CAST")
                return ChatViewModel(
                    application = LocalContext.current.applicationContext as android.app.Application,
                    conversation = conversation
                ) as T
            }
        }
    ),
    onBack: () -> Unit = {}
) {
    val context = LocalContext.current
    val appTheme = remember { AppTheme.getInstance(context) }
    val accentColor by appTheme.accentColor.collectAsState()

    val messages by viewModel.messages.collectAsState()
    val messageText by viewModel.messageText.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isSending by viewModel.isSending.collectAsState()

    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Load messages and start polling
    DisposableEffect(Unit) {
        if (messages.isEmpty()) {
            viewModel.loadMessages()
        }
        viewModel.startPolling()

        onDispose {
            viewModel.stopPolling()
        }
    }

    // Auto-scroll to bottom when new messages arrive
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            scope.launch {
                listState.animateScrollToItem(messages.size - 1)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        val firstMember = conversation.members.firstOrNull()
                        AvatarImage(
                            url = firstMember?.avatar,
                            size = 32.dp
                        )
                        Text(
                            text = firstMember?.displayName ?: firstMember?.handle ?: "Chat",
                            style = MaterialTheme.typography.titleMedium
                        )
                    }
                },
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
            // Messages list
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                if (isLoading && messages.isEmpty()) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(messages) { message ->
                            MessageBubble(
                                message = message,
                                isFromCurrentUser = isFromCurrentUser(message)
                            )
                        }
                    }
                }
            }

            Divider()

            // Input bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Bottom
            ) {
                OutlinedTextField(
                    value = messageText,
                    onValueChange = { viewModel.updateMessageText(it) },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Message") },
                    shape = RoundedCornerShape(20.dp),
                    maxLines = 6
                )

                IconButton(
                    onClick = { viewModel.sendMessage() },
                    enabled = messageText.trim().isNotEmpty() && !isSending,
                    modifier = Modifier.size(48.dp)
                ) {
                    if (isSending) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            strokeWidth = 2.dp
                        )
                    } else {
                        Icon(
                            Icons.AutoMirrored.Filled.Send,
                            contentDescription = "Send",
                            tint = if (messageText.trim().isNotEmpty()) {
                                accentColor
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            },
                            modifier = Modifier.size(36.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MessageBubble(
    message: MessageUnion,
    isFromCurrentUser: Boolean
) {
    val alignment = if (isFromCurrentUser) Alignment.End else Alignment.Start
    val backgroundColor = if (isFromCurrentUser) {
        MaterialTheme.colorScheme.primaryContainer
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }
    val textColor = if (isFromCurrentUser) {
        MaterialTheme.colorScheme.onPrimaryContainer
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }

    Box(
        modifier = Modifier.fillMaxWidth(),
        contentAlignment = alignment
    ) {
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = backgroundColor,
            modifier = Modifier.widthIn(max = 280.dp)
        ) {
            Column(
                modifier = Modifier.padding(12.dp)
            ) {
                when (message) {
                    is MessageUnion.MessageView -> {
                        message.message.text?.let { text ->
                            Text(
                                text = text,
                                style = MaterialTheme.typography.bodyMedium,
                                color = textColor
                            )
                        }
                    }
                    is MessageUnion.DeletedMessageView -> {
                        Text(
                            text = "Message deleted",
                            style = MaterialTheme.typography.bodyMedium,
                            color = textColor.copy(alpha = 0.6f),
                            fontWeight = FontWeight.Light
                        )
                    }
                }
            }
        }
    }
}

private fun isFromCurrentUser(message: MessageUnion): Boolean {
    val currentUserDID = ATProtoClient.getInstance().session.value?.did ?: ""
    return when (message) {
        is MessageUnion.MessageView -> message.message.sender.did == currentUserDID
        is MessageUnion.DeletedMessageView -> message.message.sender.did == currentUserDID
    }
}
