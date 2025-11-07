package com.cameronbanga.skyscraper.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

/**
 * Room database for Skyscraper app
 * Caches timeline posts for offline access and faster loading
 */
@Database(
    entities = [CachedPost::class],
    version = 1,
    exportSchema = false
)
abstract class SkyscraperDatabase : RoomDatabase() {

    abstract fun cachedPostDao(): CachedPostDao

    companion object {
        @Volatile
        private var INSTANCE: SkyscraperDatabase? = null

        fun getInstance(context: Context): SkyscraperDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: buildDatabase(context).also { INSTANCE = it }
            }
        }

        private fun buildDatabase(context: Context): SkyscraperDatabase {
            return Room.databaseBuilder(
                context.applicationContext,
                SkyscraperDatabase::class.java,
                "skyscraper_cache.db"
            )
                .fallbackToDestructiveMigration() // For development - delete old DB if schema changes
                .build()
        }

        /**
         * Clear all cached data
         */
        suspend fun clearCache(context: Context) {
            getInstance(context).clearAllTables()
        }
    }
}
