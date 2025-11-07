package com.cameronbanga.skyscraper.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.cameronbanga.skyscraper.models.Profile
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    actor: String,
    onBackClick: () -> Unit = {}
) {
    var profile by remember { mutableStateOf<Profile?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()
    val client = ATProtoClient.getInstance()

    LaunchedEffect(actor) {
        scope.launch {
            isLoading = true
            try {
                profile = client.getProfile(actor)
            } catch (e: Exception) {
                errorMessage = e.message
            } finally {
                isLoading = false
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(profile?.displayName ?: actor) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.Default.ArrowBack, "Back")
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
                isLoading -> {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
                errorMessage != null -> {
                    Text(
                        text = errorMessage ?: "Error",
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
                profile != null -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp)
                    ) {
                        AsyncImage(
                            model = profile!!.avatar,
                            contentDescription = null,
                            modifier = Modifier
                                .size(80.dp)
                                .clip(CircleShape),
                            contentScale = ContentScale.Crop
                        )

                        Spacer(modifier = Modifier.height(16.dp))

                        Text(
                            text = profile!!.displayName ?: profile!!.handle,
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold
                        )

                        Text(
                            text = "@${profile!!.handle}",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        profile!!.description?.let { desc ->
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(text = desc)
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Row {
                            Text("${profile!!.followersCount ?: 0} followers")
                            Spacer(modifier = Modifier.width(16.dp))
                            Text("${profile!!.followsCount ?: 0} following")
                        }
                    }
                }
            }
        }
    }
}
