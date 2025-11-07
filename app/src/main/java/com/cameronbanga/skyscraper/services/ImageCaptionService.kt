package com.cameronbanga.skyscraper.services

import android.content.Context
import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.tasks.await
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

/**
 * AI-powered image caption generation for alt text using ML Kit
 * Android equivalent of iOS ImageCaptionService
 */
class ImageCaptionService private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: ImageCaptionService? = null

        fun getInstance(context: Context): ImageCaptionService = INSTANCE ?: synchronized(this) {
            INSTANCE ?: ImageCaptionService(context.applicationContext).also { INSTANCE = it }
        }

        val shared: ImageCaptionService get() = INSTANCE
            ?: throw IllegalStateException("ImageCaptionService not initialized")
    }

    private val imageLabeler = ImageLabeling.getClient(ImageLabelerOptions.DEFAULT_OPTIONS)
    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    /**
     * Generate an alt text description for an image using ML Kit
     */
    suspend fun generateAltText(bitmap: Bitmap): String {
        return try {
            val inputImage = InputImage.fromBitmap(bitmap, 0)

            // Perform image labeling and text recognition in parallel
            val labels = try {
                imageLabeler.process(inputImage).await()
            } catch (e: Exception) {
                println("⚠️ Image labeling error: ${e.message}")
                emptyList()
            }

            val text = try {
                textRecognizer.process(inputImage).await()
            } catch (e: Exception) {
                println("⚠️ Text recognition error: ${e.message}")
                null
            }

            // Build natural language description
            buildNaturalDescription(
                labels = labels.filter { it.confidence > 0.6f }.map { it.text },
                detectedText = text?.text?.trim()?.takeIf { it.isNotEmpty() }
            )
        } catch (e: Exception) {
            println("❌ Image caption generation failed: ${e.message}")
            throw ImageCaptionException("Failed to generate image caption: ${e.message}")
        }
    }

    /**
     * Build a natural language description from detected labels and text
     */
    private fun buildNaturalDescription(
        labels: List<String>,
        detectedText: String?
    ): String {
        val parts = mutableListOf<String>()

        // Start with the most confident labels
        when {
            labels.isEmpty() -> {
                parts.add("Image content")
            }
            labels.size == 1 -> {
                parts.add(humanizeLabel(labels[0]))
            }
            else -> {
                // Combine top labels into a natural description
                val topLabels = labels.take(3).map { humanizeLabel(it) }
                parts.add("Image showing ${topLabels.joinToString(", ")}")
            }
        }

        // Add text information if available
        if (!detectedText.isNullOrEmpty()) {
            if (detectedText.length < 50) {
                parts.add("with text: \"$detectedText\"")
            } else {
                parts.add("containing visible text")
            }
        }

        // Combine all parts
        var finalDescription = parts.joinToString(" ")

        // Ensure proper capitalization
        if (finalDescription.isNotEmpty()) {
            finalDescription = finalDescription.replaceFirstChar { it.uppercase() }
        }

        // Add period if not present
        if (finalDescription.isNotEmpty() && !finalDescription.endsWith(".")) {
            finalDescription += "."
        }

        // Limit to 500 characters
        return finalDescription.take(500)
    }

    /**
     * Convert ML Kit labels to more natural language
     */
    private fun humanizeLabel(label: String): String {
        val labelMap = mapOf(
            "Sky" to "a sky view",
            "Cloud" to "clouds",
            "Water" to "a water scene",
            "Ocean" to "an ocean view",
            "Sea" to "a sea view",
            "Beach" to "a beach scene",
            "Mountain" to "a mountain scene",
            "Forest" to "a forest",
            "Tree" to "trees",
            "Building" to "a building",
            "Architecture" to "architecture",
            "City" to "a cityscape",
            "Street" to "a street scene",
            "Food" to "food",
            "Person" to "a person",
            "People" to "people",
            "Face" to "a face",
            "Animal" to "an animal",
            "Cat" to "a cat",
            "Dog" to "a dog",
            "Bird" to "a bird",
            "Plant" to "plants",
            "Flower" to "flowers",
            "Vehicle" to "a vehicle",
            "Car" to "a car",
            "Nature" to "a nature scene",
            "Indoor" to "an indoor scene",
            "Outdoor" to "an outdoor scene",
            "Landscape" to "a landscape",
            "Sunset" to "a sunset",
            "Sunrise" to "a sunrise",
            "Night" to "a nighttime scene",
            "Snow" to "a snowy scene"
        )

        return labelMap[label] ?: label.lowercase()
    }
}

/**
 * Exception thrown when image caption generation fails
 */
class ImageCaptionException(message: String) : Exception(message)
