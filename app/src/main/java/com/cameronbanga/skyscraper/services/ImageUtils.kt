package com.cameronbanga.skyscraper.services

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.URL

/**
 * Utility functions for image operations (download, share, save)
 */
object ImageUtils {

    /**
     * Download image from URL
     */
    suspend fun downloadImage(url: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val connection = URL(url).openConnection()
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            connection.connect()

            val inputStream = connection.getInputStream()
            BitmapFactory.decodeStream(inputStream)
        } catch (e: Exception) {
            println("Failed to download image: ${e.message}")
            null
        }
    }

    /**
     * Share image using Android share sheet
     */
    suspend fun shareImage(context: Context, imageUrl: String) {
        withContext(Dispatchers.IO) {
            try {
                // Download the image
                val bitmap = downloadImage(imageUrl) ?: throw IOException("Failed to download image")

                // Save to cache
                val cacheDir = context.cacheDir
                val imageFile = File(cacheDir, "shared_image_${System.currentTimeMillis()}.jpg")

                FileOutputStream(imageFile).use { out ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                }

                // Get content URI using FileProvider
                val contentUri = FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    imageFile
                )

                // Create share intent
                val shareIntent = Intent().apply {
                    action = Intent.ACTION_SEND
                    putExtra(Intent.EXTRA_STREAM, contentUri)
                    type = "image/jpeg"
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }

                withContext(Dispatchers.Main) {
                    context.startActivity(Intent.createChooser(shareIntent, "Share image"))
                }
            } catch (e: Exception) {
                println("Failed to share image: ${e.message}")
                throw e
            }
        }
    }

    /**
     * Save image to gallery/downloads
     */
    suspend fun saveImageToGallery(context: Context, imageUrl: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                // Download the image
                val bitmap = downloadImage(imageUrl) ?: throw IOException("Failed to download image")

                // Save to MediaStore (Android 10+) or external storage
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    saveImageToMediaStore(context, bitmap)
                } else {
                    saveImageToExternalStorage(context, bitmap)
                }

                true
            } catch (e: Exception) {
                println("Failed to save image: ${e.message}")
                false
            }
        }
    }

    /**
     * Save image to MediaStore (Android 10+)
     */
    private fun saveImageToMediaStore(context: Context, bitmap: Bitmap) {
        val filename = "Skyscraper_${System.currentTimeMillis()}.jpg"

        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Skyscraper")
        }

        val resolver = context.contentResolver
        val imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            ?: throw IOException("Failed to create MediaStore entry")

        resolver.openOutputStream(imageUri)?.use { out ->
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)) {
                throw IOException("Failed to save bitmap")
            }
        } ?: throw IOException("Failed to open output stream")
    }

    /**
     * Save image to external storage (Android 9 and below)
     */
    @Suppress("DEPRECATION")
    private fun saveImageToExternalStorage(context: Context, bitmap: Bitmap) {
        val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val skyscraperDir = File(picturesDir, "Skyscraper")

        if (!skyscraperDir.exists()) {
            skyscraperDir.mkdirs()
        }

        val filename = "Skyscraper_${System.currentTimeMillis()}.jpg"
        val file = File(skyscraperDir, filename)

        FileOutputStream(file).use { out ->
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)) {
                throw IOException("Failed to save bitmap")
            }
        }

        // Notify media scanner
        val intent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
        intent.data = Uri.fromFile(file)
        context.sendBroadcast(intent)
    }
}
