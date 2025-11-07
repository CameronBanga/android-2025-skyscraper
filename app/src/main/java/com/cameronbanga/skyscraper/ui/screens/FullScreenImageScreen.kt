package com.cameronbanga.skyscraper.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import coil.compose.AsyncImage
import com.cameronbanga.skyscraper.models.ImageView
import com.cameronbanga.skyscraper.services.ImageUtils
import kotlinx.coroutines.launch

/**
 * Full-screen image viewer with paging and zoom support
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun FullScreenImageScreen(
    images: List<ImageView>,
    initialIndex: Int = 0,
    onBack: () -> Unit = {}
) {
    val pagerState = rememberPagerState(
        initialPage = initialIndex,
        pageCount = { images.size }
    )

    var isAltTextExpanded by remember { mutableStateOf(false) }
    var showOptionsMenu by remember { mutableStateOf(false) }
    var isProcessing by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Permission launcher for saving images (Android 9 and below)
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            val currentImage = images.getOrNull(pagerState.currentPage)
            if (currentImage != null) {
                scope.launch {
                    isProcessing = true
                    try {
                        val success = ImageUtils.saveImageToGallery(context, currentImage.fullsize)
                        if (success) {
                            Toast.makeText(context, "Image saved to gallery", Toast.LENGTH_SHORT).show()
                        } else {
                            Toast.makeText(context, "Failed to save image", Toast.LENGTH_SHORT).show()
                        }
                    } catch (e: Exception) {
                        Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                    } finally {
                        isProcessing = false
                    }
                }
            }
        } else {
            Toast.makeText(context, "Permission denied", Toast.LENGTH_SHORT).show()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Image pager
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            ZoomableImage(
                imageUrl = images[page].fullsize.ifEmpty { images[page].thumb }
            )

            // Reset alt text when page changes
            LaunchedEffect(page) {
                isAltTextExpanded = false
            }
        }

        // Top bar with close button and counter
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .align(Alignment.TopStart),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = onBack,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.5f))
            ) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Close",
                    tint = Color.White
                )
            }

            if (images.size > 1) {
                Surface(
                    shape = CircleShape,
                    color = Color.Black.copy(alpha = 0.5f)
                ) {
                    Text(
                        text = "${pagerState.currentPage + 1} / ${images.size}",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                    )
                }
            }

            IconButton(
                onClick = { showOptionsMenu = true },
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.5f))
            ) {
                Icon(
                    Icons.Default.MoreVert,
                    contentDescription = "Options",
                    tint = Color.White
                )
            }
        }

        // Alt text display at bottom
        val currentImage = images.getOrNull(pagerState.currentPage)
        if (currentImage != null && currentImage.alt.isNotEmpty()) {
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .fillMaxWidth()
                    .padding(16.dp)
                    .clickable { isAltTextExpanded = !isAltTextExpanded },
                shape = RoundedCornerShape(12.dp),
                color = Color.Black.copy(alpha = 0.7f)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = Color.White.copy(alpha = 0.3f)
                        ) {
                            Text(
                                text = "ALT",
                                color = Color.White,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }

                        Icon(
                            if (isAltTextExpanded) Icons.Default.ExpandMore else Icons.Default.ExpandLess,
                            contentDescription = if (isAltTextExpanded) "Collapse" else "Expand",
                            tint = Color.White.copy(alpha = 0.7f)
                        )
                    }

                    Text(
                        text = currentImage.alt,
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = if (isAltTextExpanded) Int.MAX_VALUE else 3
                    )
                }
            }
        }

        // Options menu
        DropdownMenu(
            expanded = showOptionsMenu,
            onDismissRequest = { showOptionsMenu = false }
        ) {
            DropdownMenuItem(
                text = { Text("Share Image") },
                onClick = {
                    showOptionsMenu = false
                    val currentImage = images.getOrNull(pagerState.currentPage)
                    if (currentImage != null) {
                        scope.launch {
                            isProcessing = true
                            try {
                                ImageUtils.shareImage(context, currentImage.fullsize)
                            } catch (e: Exception) {
                                Toast.makeText(context, "Failed to share: ${e.message}", Toast.LENGTH_SHORT).show()
                            } finally {
                                isProcessing = false
                            }
                        }
                    }
                },
                leadingIcon = {
                    Icon(Icons.Default.Share, contentDescription = null)
                }
            )
            DropdownMenuItem(
                text = { Text("Save to Gallery") },
                onClick = {
                    showOptionsMenu = false
                    val currentImage = images.getOrNull(pagerState.currentPage)
                    if (currentImage != null) {
                        // Check if we need to request permission (Android 9 and below)
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            val hasPermission = ContextCompat.checkSelfPermission(
                                context,
                                Manifest.permission.WRITE_EXTERNAL_STORAGE
                            ) == PackageManager.PERMISSION_GRANTED

                            if (hasPermission) {
                                scope.launch {
                                    isProcessing = true
                                    try {
                                        val success = ImageUtils.saveImageToGallery(context, currentImage.fullsize)
                                        if (success) {
                                            Toast.makeText(context, "Image saved to gallery", Toast.LENGTH_SHORT).show()
                                        } else {
                                            Toast.makeText(context, "Failed to save image", Toast.LENGTH_SHORT).show()
                                        }
                                    } catch (e: Exception) {
                                        Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                                    } finally {
                                        isProcessing = false
                                    }
                                }
                            } else {
                                permissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                            }
                        } else {
                            // Android 10+ doesn't need permission for MediaStore
                            scope.launch {
                                isProcessing = true
                                try {
                                    val success = ImageUtils.saveImageToGallery(context, currentImage.fullsize)
                                    if (success) {
                                        Toast.makeText(context, "Image saved to gallery", Toast.LENGTH_SHORT).show()
                                    } else {
                                        Toast.makeText(context, "Failed to save image", Toast.LENGTH_SHORT).show()
                                    }
                                } catch (e: Exception) {
                                    Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                                } finally {
                                    isProcessing = false
                                }
                            }
                        }
                    }
                },
                leadingIcon = {
                    Icon(Icons.Default.Download, contentDescription = null)
                }
            )
        }

        // Loading overlay
        if (isProcessing) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.5f)),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = Color.White)
            }
        }
    }
}

/**
 * Zoomable image component with basic pinch-to-zoom support
 */
@Composable
private fun ZoomableImage(imageUrl: String) {
    var scale by remember { mutableStateOf(1f) }
    var offsetX by remember { mutableStateOf(0f) }
    var offsetY by remember { mutableStateOf(0f) }

    AsyncImage(
        model = imageUrl,
        contentDescription = "Full screen image",
        modifier = Modifier
            .fillMaxSize()
            .pointerInput(Unit) {
                detectTransformGestures { _, pan, zoom, _ ->
                    scale = (scale * zoom).coerceIn(1f, 4f)

                    val maxOffsetX = (size.width * (scale - 1)) / 2
                    val maxOffsetY = (size.height * (scale - 1)) / 2

                    offsetX = (offsetX + pan.x).coerceIn(-maxOffsetX, maxOffsetX)
                    offsetY = (offsetY + pan.y).coerceIn(-maxOffsetY, maxOffsetY)

                    // Reset offsets when zooming out to 1x
                    if (scale == 1f) {
                        offsetX = 0f
                        offsetY = 0f
                    }
                }
            }
            .graphicsLayer(
                scaleX = scale,
                scaleY = scale,
                translationX = offsetX,
                translationY = offsetY
            ),
        contentScale = ContentScale.Fit
    )
}
