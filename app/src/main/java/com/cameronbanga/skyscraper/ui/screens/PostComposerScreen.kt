package com.cameronbanga.skyscraper.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.cameronbanga.skyscraper.models.Profile
import com.cameronbanga.skyscraper.services.AppTheme
import com.cameronbanga.skyscraper.ui.components.AvatarImage
import com.cameronbanga.skyscraper.viewmodels.PostComposerViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostComposerScreen(
    viewModel: PostComposerViewModel = viewModel(),
    onDismiss: () -> Unit = {},
    onPostSuccess: () -> Unit = {}
) {
    val context = LocalContext.current
    val appTheme = remember { AppTheme.getInstance(context) }
    val accentColor by appTheme.accentColor.collectAsState()

    val text by viewModel.text.collectAsState()
    val characterCount by viewModel.characterCount.collectAsState()
    val canPost by viewModel.canPost.collectAsState()
    val isPosting by viewModel.isPosting.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val selectedImages by viewModel.selectedImages.collectAsState()
    val imageAltTexts by viewModel.imageAltTexts.collectAsState()
    val mentionSuggestions by viewModel.mentionSuggestions.collectAsState()
    val hashtagSuggestions by viewModel.hashtagSuggestions.collectAsState()
    val selectedLanguage by viewModel.selectedLanguage.collectAsState()
    val moderationSettings by viewModel.moderationSettings.collectAsState()
    val canSaveDraft by viewModel.canSaveDraft.collectAsState()

    var showSaveDraftDialog by remember { mutableStateOf(false) }
    var showLanguagePicker by remember { mutableStateOf(false) }
    var editingAltTextIndex by remember { mutableStateOf<Int?>(null) }

    // Image picker
    val imagePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = 4)
    ) { uris ->
        viewModel.loadSelectedImages(uris)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("New Post") },
                navigationIcon = {
                    IconButton(onClick = {
                        if (canSaveDraft) {
                            showSaveDraftDialog = true
                        } else {
                            onDismiss()
                        }
                    }) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            viewModel.post { success ->
                                if (success) {
                                    onPostSuccess()
                                    onDismiss()
                                }
                            }
                        },
                        enabled = canPost && !isPosting
                    ) {
                        if (isPosting) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp
                            )
                        } else {
                            Text(
                                "Post",
                                fontWeight = FontWeight.SemiBold,
                                color = if (canPost) accentColor else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
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
            // Main content area
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
            ) {
                // Text editor
                MentionTextField(
                    text = text,
                    onTextChange = { viewModel.updateText(it) },
                    accentColor = accentColor,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                )

                // Image previews
                if (selectedImages.isNotEmpty()) {
                    ImagePreviewSection(
                        images = selectedImages,
                        altTexts = imageAltTexts,
                        onRemoveImage = { index -> viewModel.removeImage(index) },
                        onEditAltText = { index -> editingAltTextIndex = index },
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))
            }

            // Mention suggestions
            if (mentionSuggestions.isNotEmpty()) {
                MentionSuggestionsRow(
                    suggestions = mentionSuggestions,
                    accentColor = accentColor,
                    onMentionClick = { profile -> viewModel.insertMention(profile) }
                )
            }

            // Hashtag suggestions
            if (hashtagSuggestions.isNotEmpty()) {
                HashtagSuggestionsRow(
                    suggestions = hashtagSuggestions,
                    accentColor = accentColor,
                    onHashtagClick = { tag -> viewModel.insertHashtag(tag) }
                )
            }

            // Error message
            errorMessage?.let { error ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Warning,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = error,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }

            // Bottom toolbar
            BottomToolbar(
                characterCount = characterCount,
                selectedLanguage = selectedLanguage,
                moderationSettings = moderationSettings,
                accentColor = accentColor,
                onImagePickerClick = {
                    imagePickerLauncher.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo)
                    )
                },
                onLanguageClick = { showLanguagePicker = true },
                onModerationClick = { /* TODO: Show moderation settings */ }
            )
        }
    }

    // Save draft dialog
    if (showSaveDraftDialog) {
        AlertDialog(
            onDismissRequest = { showSaveDraftDialog = false },
            title = { Text("Save Draft?") },
            text = { Text("Do you want to save this post as a draft?") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.saveDraft()
                    showSaveDraftDialog = false
                    onDismiss()
                }) {
                    Text("Save Draft")
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showSaveDraftDialog = false
                    onDismiss()
                }) {
                    Text("Discard")
                }
            }
        )
    }

    // Alt text editor dialog
    editingAltTextIndex?.let { index ->
        if (index < imageAltTexts.size) {
            AltTextEditorDialog(
                altText = imageAltTexts[index],
                imageUri = selectedImages.getOrNull(index),
                onDismiss = { editingAltTextIndex = null },
                onSave = { newAltText ->
                    viewModel.updateAltText(index, newAltText)
                    editingAltTextIndex = null
                }
            )
        }
    }
}

@Composable
private fun MentionTextField(
    text: String,
    onTextChange: (String) -> Unit,
    accentColor: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier
) {
    // Build annotated string with highlighted mentions and hashtags
    val annotatedText = buildAnnotatedString {
        var lastIndex = 0

        // Regex patterns
        val mentionPattern = Regex("""@[a-zA-Z0-9._-]+""")
        val hashtagPattern = Regex("""#[a-zA-Z0-9_]+""")

        // Find all mentions and hashtags
        val mentions = mentionPattern.findAll(text).toList()
        val hashtags = hashtagPattern.findAll(text).toList()
        val allMatches = (mentions + hashtags).sortedBy { it.range.first }

        allMatches.forEach { match ->
            // Add text before the match
            append(text.substring(lastIndex, match.range.first))

            // Add the highlighted match
            withStyle(SpanStyle(color = accentColor)) {
                append(match.value)
            }

            lastIndex = match.range.last + 1
        }

        // Add remaining text
        if (lastIndex < text.length) {
            append(text.substring(lastIndex))
        }
    }

    var textFieldValue by remember(text) {
        mutableStateOf(TextFieldValue(annotatedText, TextRange(text.length)))
    }

    BasicTextField(
        value = textFieldValue,
        onValueChange = { newValue ->
            textFieldValue = newValue
            onTextChange(newValue.text)
        },
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 120.dp),
        textStyle = MaterialTheme.typography.bodyLarge.copy(
            color = MaterialTheme.colorScheme.onSurface
        ),
        cursorBrush = SolidColor(accentColor),
        keyboardOptions = KeyboardOptions(
            capitalization = KeyboardCapitalization.Sentences
        ),
        decorationBox = { innerTextField ->
            Box {
                if (text.isEmpty()) {
                    Text(
                        "What's on your mind?",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                innerTextField()
            }
        }
    )
}

@Composable
private fun ImagePreviewSection(
    images: List<Uri>,
    altTexts: List<String>,
    onRemoveImage: (Int) -> Unit,
    onEditAltText: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(images.size) { index ->
            Box {
                AsyncImage(
                    model = images[index],
                    contentDescription = null,
                    modifier = Modifier
                        .size(100.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .clickable { onEditAltText(index) },
                    contentScale = ContentScale.Crop
                )

                // ALT badge if alt text exists
                if (index < altTexts.size && altTexts[index].isNotEmpty()) {
                    Surface(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(4.dp),
                        shape = RoundedCornerShape(4.dp),
                        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.7f)
                    ) {
                        Text(
                            text = "ALT",
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                // Remove button
                IconButton(
                    onClick = { onRemoveImage(index) },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp)
                        .size(24.dp)
                        .background(
                            MaterialTheme.colorScheme.surface.copy(alpha = 0.7f),
                            CircleShape
                        )
                ) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "Remove image",
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun MentionSuggestionsRow(
    suggestions: List<Profile>,
    accentColor: androidx.compose.ui.graphics.Color,
    onMentionClick: (Profile) -> Unit
) {
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .height(60.dp)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(suggestions) { profile ->
            Surface(
                modifier = Modifier.clickable { onMentionClick(profile) },
                shape = RoundedCornerShape(8.dp),
                color = accentColor.copy(alpha = 0.1f),
                border = androidx.compose.foundation.BorderStroke(
                    1.dp,
                    accentColor.copy(alpha = 0.3f)
                )
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    AvatarImage(
                        url = profile.avatar,
                        size = 32.dp
                    )
                    Column {
                        Text(
                            text = profile.displayName ?: profile.handle,
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1
                        )
                        Text(
                            text = "@${profile.handle}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun HashtagSuggestionsRow(
    suggestions: List<String>,
    accentColor: androidx.compose.ui.graphics.Color,
    onHashtagClick: (String) -> Unit
) {
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .height(60.dp)
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(suggestions) { tag ->
            Surface(
                modifier = Modifier.clickable { onHashtagClick(tag) },
                shape = RoundedCornerShape(8.dp),
                color = accentColor.copy(alpha = 0.1f),
                border = androidx.compose.foundation.BorderStroke(
                    1.dp,
                    accentColor.copy(alpha = 0.3f)
                )
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Surface(
                        shape = CircleShape,
                        color = accentColor.copy(alpha = 0.2f),
                        modifier = Modifier.size(32.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                Icons.Default.Tag,
                                contentDescription = null,
                                tint = accentColor,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                    Text(
                        text = "#$tag",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

@Composable
private fun BottomToolbar(
    characterCount: Int,
    selectedLanguage: com.cameronbanga.skyscraper.models.Language,
    moderationSettings: com.cameronbanga.skyscraper.models.ModerationSettings,
    accentColor: androidx.compose.ui.graphics.Color,
    onImagePickerClick: () -> Unit,
    onLanguageClick: () -> Unit,
    onModerationClick: () -> Unit
) {
    Surface(
        tonalElevation = 2.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            IconButton(onClick = onImagePickerClick) {
                Icon(
                    Icons.Default.Image,
                    contentDescription = "Add images",
                    tint = accentColor
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Language
            TextButton(onClick = onLanguageClick) {
                Text(
                    text = selectedLanguage.name,
                    style = MaterialTheme.typography.bodySmall,
                    color = accentColor
                )
            }

            Text(
                text = "·",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            // Moderation settings
            TextButton(onClick = onModerationClick) {
                Text(
                    text = moderationSettings.displaySummary,
                    style = MaterialTheme.typography.bodySmall,
                    color = accentColor
                )
            }

            // Character count
            Text(
                text = "$characterCount/300",
                style = MaterialTheme.typography.bodySmall,
                color = if (characterCount > 300) {
                    MaterialTheme.colorScheme.error
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
        }
    }
}

@Composable
private fun AltTextEditorDialog(
    altText: String,
    imageUri: Uri?,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit
) {
    var text by remember { mutableStateOf(altText) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit Alt Text") },
        text = {
            Column {
                imageUri?.let { uri ->
                    AsyncImage(
                        model = uri,
                        contentDescription = null,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
                            .clip(RoundedCornerShape(8.dp)),
                        contentScale = ContentScale.Crop
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                }
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    label = { Text("Alt text") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 4
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(text) }) {
                Text("Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
