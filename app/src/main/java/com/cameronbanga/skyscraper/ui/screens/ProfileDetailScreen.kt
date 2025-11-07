package com.cameronbanga.skyscraper.ui.screens

import androidx.compose.foundation.background
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.cameronbanga.skyscraper.models.Profile
import com.cameronbanga.skyscraper.services.AppTheme
import com.cameronbanga.skyscraper.ui.components.AvatarImage
import com.cameronbanga.skyscraper.ui.components.PostCard
import com.cameronbanga.skyscraper.viewmodels.AuthViewModel
import com.cameronbanga.skyscraper.viewmodels.ProfileTab
import com.cameronbanga.skyscraper.viewmodels.ProfileViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileDetailScreen(
    actor: String,
    authViewModel: AuthViewModel = viewModel(),
    viewModel: ProfileViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
                @Suppress("UNCHECKED_CAST")
                return ProfileViewModel(
                    application = LocalContext.current.applicationContext as android.app.Application,
                    actor = actor
                ) as T
            }
        }
    ),
    onBack: () -> Unit = {},
    onPostClick: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val appTheme = remember { AppTheme.getInstance(context) }
    val accentColor by appTheme.accentColor.collectAsState()

    val profile by viewModel.profile.collectAsState()
    val posts by viewModel.posts.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isLoadingContent by viewModel.isLoadingContent.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val selectedTab by viewModel.selectedTab.collectAsState()

    var showLogoutDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Profile") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (viewModel.isCurrentUser) {
                        TextButton(
                            onClick = { showLogoutDialog = true },
                            colors = ButtonDefaults.textButtonColors(
                                contentColor = MaterialTheme.colorScheme.error
                            )
                        ) {
                            Text("Log Out")
                        }
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
                        Button(onClick = { viewModel.loadProfile() }) {
                            Text("Retry")
                        }
                    }
                }
            }
            profile != null -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                ) {
                    // Profile Header
                    item {
                        ProfileHeader(
                            profile = profile!!,
                            isCurrentUser = viewModel.isCurrentUser,
                            accentColor = accentColor,
                            onFollowClick = { viewModel.toggleFollow() }
                        )
                    }

                    // Tabs
                    item {
                        TabRow(
                            selectedTab = selectedTab,
                            isCurrentUser = viewModel.isCurrentUser,
                            onTabSelected = { viewModel.selectTab(it) }
                        )
                    }

                    // Content
                    if (isLoadingContent && posts.isEmpty()) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(24.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator()
                            }
                        }
                    } else if (posts.isEmpty()) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(48.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = when (selectedTab) {
                                        ProfileTab.POSTS -> "No posts yet"
                                        ProfileTab.REPLIES -> "No replies yet"
                                        ProfileTab.LIKES -> "No likes yet"
                                        ProfileTab.LISTS -> "No lists yet"
                                    },
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    } else {
                        items(posts) { feedPost ->
                            PostCard(
                                feedPost = feedPost,
                                onPostClick = { onPostClick(it.post.uri) },
                                onProfileClick = { /* Navigate to profile */ },
                                onLikeClick = { /* TODO */ },
                                onRepostClick = { /* TODO */ },
                                onReplyClick = { /* TODO */ },
                                onShareClick = { /* TODO */ }
                            )
                            Divider()

                            // Load more at end
                            if (feedPost == posts.lastOrNull()) {
                                LaunchedEffect(Unit) {
                                    viewModel.loadMore()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Logout confirmation dialog
    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("Log Out") },
            text = { Text("Are you sure you want to log out of this account?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        authViewModel.logout()
                        showLogoutDialog = false
                        onBack()
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("Log Out")
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun ProfileHeader(
    profile: Profile,
    isCurrentUser: Boolean,
    accentColor: Color,
    onFollowClick: () -> Unit
) {
    Column {
        // Banner
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(150.dp)
                .background(MaterialTheme.colorScheme.primaryContainer)
        ) {
            profile.banner?.let { bannerUrl ->
                AsyncImage(
                    model = bannerUrl,
                    contentDescription = "Profile banner",
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
            }
        }

        // Avatar and stats
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .offset(y = (-48).dp)
                .padding(horizontal = 16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                // Avatar
                Surface(
                    modifier = Modifier.size(96.dp),
                    shape = CircleShape,
                    tonalElevation = 4.dp
                ) {
                    AvatarImage(
                        url = profile.avatar,
                        size = 96.dp
                    )
                }

                // Follow button
                if (!isCurrentUser) {
                    Button(
                        onClick = onFollowClick,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (profile.viewer?.following != null) {
                                MaterialTheme.colorScheme.surfaceVariant
                            } else {
                                accentColor
                            }
                        )
                    ) {
                        Text(
                            if (profile.viewer?.following != null) "Following" else "Follow"
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Display name and handle
            Text(
                text = profile.displayName ?: profile.handle,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "@${profile.handle}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            // Bio
            profile.description?.let { bio ->
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = bio,
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            // Stats
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                StatItem(
                    count = profile.followersCount ?: 0,
                    label = "Followers"
                )
                StatItem(
                    count = profile.followsCount ?: 0,
                    label = "Following"
                )
                StatItem(
                    count = profile.postsCount ?: 0,
                    label = "Posts"
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

@Composable
private fun StatItem(count: Int, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = count.toString(),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun TabRow(
    selectedTab: ProfileTab,
    isCurrentUser: Boolean,
    onTabSelected: (ProfileTab) -> Unit
) {
    val tabs = if (isCurrentUser) {
        listOf(ProfileTab.POSTS, ProfileTab.REPLIES, ProfileTab.LIKES, ProfileTab.LISTS)
    } else {
        listOf(ProfileTab.POSTS, ProfileTab.REPLIES, ProfileTab.LISTS)
    }

    ScrollableTabRow(
        selectedTabIndex = tabs.indexOf(selectedTab),
        modifier = Modifier.fillMaxWidth()
    ) {
        tabs.forEach { tab ->
            Tab(
                selected = selectedTab == tab,
                onClick = { onTabSelected(tab) },
                text = {
                    Text(
                        text = when (tab) {
                            ProfileTab.POSTS -> "Posts"
                            ProfileTab.REPLIES -> "Replies"
                            ProfileTab.LIKES -> "Likes"
                            ProfileTab.LISTS -> "Lists"
                        }
                    )
                }
            )
        }
    }
}
