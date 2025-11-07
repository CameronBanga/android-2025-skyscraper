package com.cameronbanga.skyscraper.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.cameronbanga.skyscraper.models.Language
import com.cameronbanga.skyscraper.services.LanguagePreferences
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LanguagePickerScreen(
    currentLanguage: Language,
    onLanguageSelected: (Language) -> Unit,
    onBack: () -> Unit = {}
) {
    val context = LocalContext.current
    val languagePreferences = remember { LanguagePreferences.getInstance(context) }

    var searchText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    val filteredLanguages = remember(searchText) {
        if (searchText.isEmpty()) {
            Language.allLanguages
        } else {
            Language.allLanguages.filter { language ->
                language.name.contains(searchText, ignoreCase = true)
            }
        }
    }

    // Scroll to selected language on first composition
    LaunchedEffect(Unit) {
        val selectedIndex = filteredLanguages.indexOfFirst { it.id == currentLanguage.id }
        if (selectedIndex >= 0) {
            scope.launch {
                listState.scrollToItem(selectedIndex.coerceAtLeast(0))
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Post Language") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.Close, contentDescription = "Cancel")
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
                placeholder = { Text("Search languages") },
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

            // Language list
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                state = listState
            ) {
                items(
                    items = filteredLanguages,
                    key = { it.id }
                ) { language ->
                    LanguageRow(
                        language = language,
                        isSelected = language.id == currentLanguage.id,
                        onClick = {
                            onLanguageSelected(language)
                            languagePreferences.setPreferredLanguage(language)
                            onBack()
                        }
                    )
                    Divider()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LanguageRow(
    language: Language,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = language.name,
                style = MaterialTheme.typography.bodyMedium
            )

            if (isSelected) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = "Selected",
                    tint = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}
