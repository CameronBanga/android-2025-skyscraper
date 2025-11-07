package com.cameronbanga.skyscraper.services

import android.content.Context
import coil.ImageLoader
import coil.request.ImageRequest
import com.cameronbanga.skyscraper.models.FeedViewPost
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Service for prefetching images in the background
 * Improves scrolling performance by preloading images ahead of time
 */
class ImagePrefetchService private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: ImagePrefetchService? = null

        fun getInstance(context: Context): ImagePrefetchService = INSTANCE ?: synchronized(this) {
            INSTANCE ?: ImagePrefetchService(context.applicationContext).also { INSTANCE = it }
        }

        val shared get() = INSTANCE
            ?: throw IllegalStateException("ImagePrefetchService not initialized")

        private const val PREFETCH_AHEAD_COUNT = 10 // Number of posts to prefetch ahead
    }

    private val imageLoader = ImageLoader(context)
    private val prefetchScope = CoroutineScope(Dispatchers.IO)

    /**
     * Prefetch images for upcoming posts
     * @param posts All posts in the timeline
     * @param currentIndex Current visible post index
     */
    fun prefetchImagesForUpcomingPosts(posts: List<FeedViewPost>, currentIndex: Int) {
        if (posts.isEmpty()) return

        prefetchScope.launch {
            val startIndex = (currentIndex + 1).coerceIn(0, posts.size - 1)
            val endIndex = (currentIndex + PREFETCH_AHEAD_COUNT).coerceIn(0, posts.size)

            for (i in startIndex until endIndex) {
                val post = posts[i]

                // Prefetch author avatar
                post.post.author.avatar?.let { avatar ->
                    prefetchImage(avatar)
                }

                // Prefetch embedded images
                post.post.embed?.images?.forEach { imageView ->
                    prefetchImage(imageView.thumb)
                    prefetchImage(imageView.fullsize)
                }

                // Prefetch external link image
                post.post.embed?.external?.thumb?.let { thumb ->
                    prefetchImage(thumb)
                }

                // Prefetch video thumbnail
                post.post.embed?.video?.thumbnail?.let { thumbnail ->
                    prefetchImage(thumbnail)
                }
            }
        }
    }

    /**
     * Prefetch a single image URL
     */
    private fun prefetchImage(url: String) {
        if (url.isBlank()) return

        val request = ImageRequest.Builder(context)
            .data(url)
            .build()

        imageLoader.enqueue(request)
    }

    /**
     * Clear the image cache
     */
    fun clearCache() {
        imageLoader.memoryCache?.clear()
        imageLoader.diskCache?.clear()
    }
}
