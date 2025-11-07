package com.cameronbanga.skyscraper.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cameronbanga.skyscraper.services.AccountManager
import com.cameronbanga.skyscraper.services.AppTheme
import com.cameronbanga.skyscraper.services.ThemeColor
import com.cameronbanga.skyscraper.ui.components.AvatarImage
import com.cameronbanga.skyscraper.viewmodels.AuthViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    authViewModel: AuthViewModel = viewModel(),
    onBack: () -> Unit = {},
    onProfileClick: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val appTheme = remember { AppTheme.getInstance(context) }
    val accountManager = remember { AccountManager.getInstance(context) }

    val accentColor by appTheme.accentColor.collectAsState()
    val accounts by accountManager.accounts.collectAsState()
    val activeAccountId by accountManager.activeAccountId.collectAsState()

    var showThemeDialog by remember { mutableStateOf(false) }
    var showAddAccountDialog by remember { mutableStateOf(false) }
    var showClearCacheDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Accounts Section
            item {
                Text(
                    text = "ACCOUNTS",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }

            items(accounts) { account ->
                Surface(
                    onClick = {
                        if (account.id != activeAccountId) {
                            accountManager.switchAccount(account.id)
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Active indicator
                        RadioButton(
                            selected = account.id == activeAccountId,
                            onClick = {
                                if (account.id != activeAccountId) {
                                    accountManager.switchAccount(account.id)
                                }
                            }
                        )

                        // Avatar
                        AvatarImage(
                            url = account.avatar,
                            size = 48.dp
                        )

                        // Account info
                        Column(
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(
                                text = account.displayName ?: account.handle,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = "@${account.handle}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        // Navigate to profile
                        IconButton(onClick = { onProfileClick(account.handle) }) {
                            Icon(
                                Icons.Default.ChevronRight,
                                contentDescription = "View profile"
                            )
                        }
                    }
                }
                Divider()
            }

            item {
                Surface(
                    onClick = { showAddAccountDialog = true },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = null,
                            tint = accentColor
                        )
                        Text(
                            text = "Add Additional Account",
                            color = accentColor
                        )
                    }
                }
                Divider()
            }

            // Appearance Section
            item {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "APPEARANCE",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }

            item {
                Surface(
                    onClick = { showThemeDialog = true },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Palette,
                            contentDescription = null
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Theme Color",
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Text(
                                text = "Customize accent color",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = null
                        )
                    }
                }
                Divider()
            }

            // Data & Cache Section
            item {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "DATA & CACHE",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }

            item {
                Surface(
                    onClick = { showClearCacheDialog = true },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.DeleteOutline,
                            contentDescription = null
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Clear Cache",
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Text(
                                text = "Remove cached posts and images",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                Divider()
            }

            // About Section
            item {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "ABOUT",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }

            item {
                Surface(
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Info,
                            contentDescription = null
                        )
                        Column {
                            Text(
                                text = "Skyscraper for Android",
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Text(
                                text = "Version 1.0.0",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }

    // Theme selection dialog
    if (showThemeDialog) {
        AlertDialog(
            onDismissRequest = { showThemeDialog = false },
            title = { Text("Choose Theme Color") },
            text = {
                Column {
                    ThemeColor.values().forEach { themeColor ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    appTheme.setThemeColor(themeColor)
                                    showThemeDialog = false
                                }
                                .padding(vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Surface(
                                modifier = Modifier.size(24.dp),
                                shape = MaterialTheme.shapes.small,
                                color = androidx.compose.ui.graphics.Color(themeColor.color.toArgb())
                            ) {}
                            Text(themeColor.displayName)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showThemeDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Add account dialog
    if (showAddAccountDialog) {
        AlertDialog(
            onDismissRequest = { showAddAccountDialog = false },
            title = { Text("Add Account") },
            text = { Text("Adding additional accounts is coming soon!") },
            confirmButton = {
                TextButton(onClick = { showAddAccountDialog = false }) {
                    Text("OK")
                }
            }
        )
    }

    // Clear cache dialog
    if (showClearCacheDialog) {
        AlertDialog(
            onDismissRequest = { showClearCacheDialog = false },
            title = { Text("Clear Cache") },
            text = { Text("Are you sure you want to clear the cache? This will remove all cached posts and images.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        // TODO: Implement cache clearing
                        showClearCacheDialog = false
                    }
                ) {
                    Text("Clear")
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearCacheDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
