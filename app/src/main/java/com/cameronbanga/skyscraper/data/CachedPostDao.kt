package com.cameronbanga.skyscraper.data

import androidx.room.*

/**
 * Data Access Object for cached posts
 */
@Dao
interface CachedPostDao {

    @Query("SELECT * FROM cached_posts WHERE feedId = :feedId ORDER BY sortOrder ASC")
    suspend fun getPostsForFeed(feedId: String): List<CachedPost>

    @Query("SELECT * FROM cached_posts WHERE uri = :uri")
    suspend fun getPostByUri(uri: String): CachedPost?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPost(post: CachedPost)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPosts(posts: List<CachedPost>)

    @Delete
    suspend fun deletePost(post: CachedPost)

    @Query("DELETE FROM cached_posts WHERE feedId = :feedId")
    suspend fun clearFeed(feedId: String)

    @Query("DELETE FROM cached_posts WHERE cachedAt < :cutoffTime")
    suspend fun deleteOldPosts(cutoffTime: Long)

    @Query("DELETE FROM cached_posts")
    suspend fun clearAll()

    @Query("SELECT COUNT(*) FROM cached_posts WHERE feedId = :feedId")
    suspend fun getPostCountForFeed(feedId: String): Int
}
