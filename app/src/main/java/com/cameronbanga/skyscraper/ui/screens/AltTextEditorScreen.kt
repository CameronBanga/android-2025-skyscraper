package com.cameronbanga.skyscraper.ui.screens

import android.graphics.Bitmap
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cameronbanga.skyscraper.services.AppTheme
import com.cameronbanga.skyscraper.services.ImageCaptionService
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AltTextEditorScreen(
    initialAltText: String,
    image: Bitmap?,
    onSave: (String) -> Unit,
    onBack: () -> Unit = {}
) {
    val context = LocalContext.current
    val appTheme = remember { AppTheme.getInstance(context) }
    val accentColor by appTheme.accentColor.collectAsState()

    var altText by remember { mutableStateOf(initialAltText) }
    var isGeneratingAltText by remember { mutableStateOf(false) }
    var showError by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf("") }

    val maxCharacters = 1000
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add Alt Text") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.Close, contentDescription = "Cancel")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            onSave(altText)
                            onBack()
                        },
                        enabled = altText.length <= maxCharacters
                    ) {
                        Text(
                            "Done",
                            fontWeight = FontWeight.SemiBold,
                            color = if (altText.length <= maxCharacters) {
                                accentColor
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            }
                        )
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Image preview
            if (image != null) {
                Image(
                    bitmap = image.asImageBitmap(),
                    contentDescription = "Image to add alt text",
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 300.dp)
                        .padding(16.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Fit
                )
            }

            // Alt text input section
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Alt Text",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // AI Generate button
                        if (image != null) {
                            IconButton(
                                onClick = {
                                    scope.launch {
                                        isGeneratingAltText = true
                                        try {
                                            val captionService = ImageCaptionService.getInstance(context)
                                            val generatedText = captionService.generateAltText(image)

                                            // If user hasn't typed anything, replace. Otherwise, replace anyway
                                            altText = generatedText

                                            Toast.makeText(
                                                context,
                                                "Alt text generated successfully",
                                                Toast.LENGTH_SHORT
                                            ).show()
                                        } catch (e: Exception) {
                                            errorMessage = e.message ?: "Failed to generate alt text"
                                            showError = true
                                        } finally {
                                            isGeneratingAltText = false
                                        }
                                    }
                                },
                                enabled = !isGeneratingAltText
                            ) {
                                if (isGeneratingAltText) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(20.dp),
                                        strokeWidth = 2.dp
                                    )
                                } else {
                                    Icon(
                                        Icons.Default.AutoAwesome,
                                        contentDescription = "Generate alt text with AI",
                                        tint = accentColor
                                    )
                                }
                            }
                        }

                        Text(
                            text = "${altText.length}/$maxCharacters",
                            style = MaterialTheme.typography.bodySmall,
                            color = if (altText.length > maxCharacters) {
                                MaterialTheme.colorScheme.error
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            }
                        )
                    }
                }

                OutlinedTextField(
                    value = altText,
                    onValueChange = { altText = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp),
                    placeholder = { Text("Describe this image...") },
                    isError = altText.length > maxCharacters
                )

                Text(
                    text = "Describe this image for people who can't see it. This helps make your posts more accessible.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.weight(1f))
        }
    }

    if (showError) {
        AlertDialog(
            onDismissRequest = { showError = false },
            title = { Text("Error Generating Alt Text") },
            text = { Text(errorMessage) },
            confirmButton = {
                TextButton(onClick = { showError = false }) {
                    Text("OK")
                }
            }
        )
    }
}
