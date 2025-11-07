package com.cameronbanga.skyscraper

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Alignment
import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBox
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cameronbanga.skyscraper.ui.screens.ChatListScreen
import com.cameronbanga.skyscraper.ui.screens.LoginScreen
import com.cameronbanga.skyscraper.ui.screens.SearchScreen
import com.cameronbanga.skyscraper.ui.screens.TimelineScreen
import com.cameronbanga.skyscraper.viewmodels.AuthViewModel
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.tooling.preview.PreviewScreenSizes
import com.cameronbanga.skyscraper.ui.theme.SkyscraperTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            SkyscraperTheme {
                SkyscraperApp()
            }
        }
    }
}

@PreviewScreenSizes
@Composable
fun SkyscraperApp() {
    val authViewModel: AuthViewModel = viewModel()
    val isAuthenticated by authViewModel.isAuthenticated.collectAsState()
    val isCheckingSession by authViewModel.isCheckingSession.collectAsState()

    when {
        isCheckingSession -> {
            // Splash screen while checking for saved session
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        }
        isAuthenticated -> {
            // Main app with navigation
            var currentDestination by rememberSaveable { mutableStateOf(AppDestinations.HOME) }

            NavigationSuiteScaffold(
                navigationSuiteItems = {
                    AppDestinations.entries.forEach {
                        item(
                            icon = {
                                Icon(
                                    it.icon,
                                    contentDescription = it.label
                                )
                            },
                            label = { Text(it.label) },
                            selected = it == currentDestination,
                            onClick = { currentDestination = it }
                        )
                    }
                }
            ) {
                when (currentDestination) {
                    AppDestinations.HOME -> TimelineScreen()
                    AppDestinations.SEARCH -> SearchScreen()
                    AppDestinations.CHAT -> ChatListScreen()
                    AppDestinations.PROFILE -> {
                        // TODO: Implement full ProfileScreen
                        Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                            Greeting(
                                name = "Profile (Coming Soon)",
                                modifier = Modifier.padding(innerPadding)
                            )
                        }
                    }
                }
            }
        }
        else -> {
            // Login screen
            LoginScreen(
                viewModel = authViewModel,
                onLoginSuccess = {
                    // Authentication state will automatically update
                }
            )
        }
    }
}

enum class AppDestinations(
    val label: String,
    val icon: ImageVector,
) {
    HOME("Home", Icons.Default.Home),
    SEARCH("Search", Icons.Default.Search),
    CHAT("Chat", Icons.Default.Email),
    PROFILE("Profile", Icons.Default.AccountBox),
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(
        text = "Hello $name!",
        modifier = modifier
    )
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    SkyscraperTheme {
        Greeting("Android")
    }
}