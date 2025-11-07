package com.cameronbanga.skyscraper.services

import android.content.Context
import androidx.work.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker for periodic timeline refresh in background
 * Similar to iOS TimelineFetchService with BGAppRefreshTask
 */
class TimelineRefreshWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    private val client = ATProtoClient.getInstance()

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            // Check if user is logged in
            if (client.session.value == null) {
                return@withContext Result.success()
            }

            // Fetch latest timeline posts
            val response = client.getTimeline(limit = 20)

            // Cache the posts for faster loading
            try {
                val postCacheService = PostCacheService.getInstance(applicationContext)
                postCacheService.cachePosts(response.feed, "timeline")
            } catch (e: Exception) {
                // Continue even if caching fails
            }

            // Cleanup old cached posts
            try {
                val postCacheService = PostCacheService.getInstance(applicationContext)
                postCacheService.cleanupOldPosts()
            } catch (e: Exception) {
                // Continue even if cleanup fails
            }

            Result.success()
        } catch (e: Exception) {
            // Retry on failure
            if (runAttemptCount < 3) {
                Result.retry()
            } else {
                Result.failure()
            }
        }
    }

    companion object {
        const val WORK_NAME = "timeline_refresh"

        /**
         * Schedule periodic timeline refresh
         * Runs every 30 minutes when device is idle and on WiFi
         */
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build()

            val refreshRequest = PeriodicWorkRequestBuilder<TimelineRefreshWorker>(
                30, TimeUnit.MINUTES,
                15, TimeUnit.MINUTES // Flex interval
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    10, TimeUnit.MINUTES
                )
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                refreshRequest
            )
        }

        /**
         * Cancel scheduled refresh
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
