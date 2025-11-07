package com.cameronbanga.skyscraper.services

import com.cameronbanga.skyscraper.models.*
import okhttp3.RequestBody
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.*

/**
 * Retrofit API interface for AT Protocol / BlueSky API
 */
interface ATProtoApi {

    // MARK: - Authentication

    @POST("/xrpc/com.atproto.server.createSession")
    suspend fun createSession(@Body request: CreateSessionRequest): CreateSessionResponse

    @POST("/xrpc/com.atproto.server.refreshSession")
    suspend fun refreshSession(): CreateSessionResponse

    // MARK: - Feed Operations

    @GET("/xrpc/app.bsky.feed.getTimeline")
    suspend fun getTimeline(
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): FeedResponse

    @GET("/xrpc/app.bsky.feed.getFeed")
    suspend fun getFeed(
        @Query("feed") feed: String,
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): FeedResponse

    @GET("/xrpc/app.bsky.feed.getAuthorFeed")
    suspend fun getAuthorFeed(
        @Query("actor") actor: String,
        @Query("filter") filter: String = "posts_with_replies",
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): FeedResponse

    @GET("/xrpc/app.bsky.feed.getActorLikes")
    suspend fun getActorLikes(
        @Query("actor") actor: String,
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): FeedResponse

    @GET("/xrpc/app.bsky.feed.getActorFeeds")
    suspend fun getActorFeeds(
        @Query("actor") actor: String,
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): FeedGeneratorsResponse

    @GET("/xrpc/app.bsky.feed.searchPosts")
    suspend fun searchPosts(
        @Query("q") query: String,
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): SearchPostsResponse

    @GET("/xrpc/app.bsky.feed.getSuggestedFeeds")
    suspend fun getSuggestedFeeds(
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): FeedGeneratorsResponse

    @GET("/xrpc/app.bsky.feed.getFeedGenerators")
    suspend fun getFeedGenerators(
        @Query("feeds") feeds: List<String>
    ): FeedGeneratorsResponse

    // MARK: - Post Operations

    @POST("/xrpc/com.atproto.repo.uploadBlob")
    @Headers("Content-Type: image/jpeg")
    suspend fun uploadBlob(@Body imageData: RequestBody): Response<ResponseBody>

    @POST("/xrpc/com.atproto.repo.createRecord")
    suspend fun createRecord(@Body body: Map<String, Any>): Response<ResponseBody>

    @POST("/xrpc/com.atproto.repo.deleteRecord")
    suspend fun deleteRecord(@Body body: Map<String, Any>): Response<ResponseBody>

    // MARK: - Thread Operations

    @GET("/xrpc/app.bsky.feed.getPostThread")
    suspend fun getPostThread(
        @Query("uri") uri: String,
        @Query("depth") depth: Int? = null,
        @Query("parentHeight") parentHeight: Int? = null
    ): ThreadResponse

    @GET("/xrpc/app.bsky.feed.getPosts")
    suspend fun getPosts(
        @Query("uris") uris: List<String>
    ): Response<ResponseBody>

    // MARK: - Profile Operations

    @GET("/xrpc/app.bsky.actor.getProfile")
    suspend fun getProfile(
        @Query("actor") actor: String
    ): Profile

    @GET("/xrpc/app.bsky.actor.getProfiles")
    suspend fun getProfiles(
        @Query("actors") actors: List<String>
    ): Response<ResponseBody>

    // MARK: - Social Graph Operations

    @GET("/xrpc/app.bsky.actor.searchActors")
    suspend fun searchActors(
        @Query("q") query: String,
        @Query("limit") limit: Int = 25
    ): ActorSearchResponse

    @GET("/xrpc/app.bsky.graph.getFollows")
    suspend fun getFollows(
        @Query("actor") actor: String,
        @Query("limit") limit: Int = 50
    ): Response<ResponseBody>

    @GET("/xrpc/app.bsky.graph.getFollowers")
    suspend fun getFollowers(
        @Query("actor") actor: String,
        @Query("limit") limit: Int = 50
    ): Response<ResponseBody>

    // MARK: - Notifications

    @GET("/xrpc/app.bsky.notification.listNotifications")
    suspend fun listNotifications(
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): NotificationsResponse

    @POST("/xrpc/app.bsky.notification.updateSeen")
    suspend fun updateSeenNotifications(@Body body: Map<String, String>): Response<ResponseBody>

    // MARK: - Preferences

    @GET("/xrpc/app.bsky.actor.getPreferences")
    suspend fun getPreferences(): PreferencesResponse

    @POST("/xrpc/app.bsky.actor.putPreferences")
    suspend fun putPreferences(@Body body: Map<String, List<Map<String, Any>>>): Response<ResponseBody>

    // MARK: - Lists

    @GET("/xrpc/app.bsky.graph.getLists")
    suspend fun getActorLists(
        @Query("actor") actor: String,
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): ActorListsResponse

    @GET("/xrpc/app.bsky.graph.getList")
    suspend fun getList(
        @Query("list") list: String,
        @Query("limit") limit: Int = 100,
        @Query("cursor") cursor: String? = null
    ): ListResponse

    // MARK: - Starter Packs

    @GET("/xrpc/app.bsky.graph.getStarterPacks")
    suspend fun getStarterPacks(
        @Query("uris") uris: List<String>
    ): StarterPacksResponse

    @GET("/xrpc/app.bsky.graph.getActorStarterPacks")
    suspend fun getActorStarterPacks(
        @Query("actor") actor: String,
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): StarterPacksResponse
}

/**
 * Separate API interface for Chat endpoints (different base URL)
 */
interface ATProtoChatApi {

    @GET("/xrpc/chat.bsky.convo.listConvos")
    suspend fun listConvos(
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): ListConvosResponse

    @GET("/xrpc/chat.bsky.convo.getConvo")
    suspend fun getConvo(
        @Query("convoId") convoId: String
    ): GetConvoResponse

    @GET("/xrpc/chat.bsky.convo.getConvoForMembers")
    suspend fun getConvoForMembers(
        @Query("members") members: List<String>
    ): GetConvoForMembersResponse

    @GET("/xrpc/chat.bsky.convo.getMessages")
    suspend fun getMessages(
        @Query("convoId") convoId: String,
        @Query("limit") limit: Int = 50,
        @Query("cursor") cursor: String? = null
    ): GetMessagesResponse

    @POST("/xrpc/chat.bsky.convo.sendMessage")
    suspend fun sendMessage(@Body body: Map<String, Any>): SendMessageResponse

    @POST("/xrpc/chat.bsky.convo.updateRead")
    suspend fun updateRead(@Body body: Map<String, String>): Response<ResponseBody>

    @POST("/xrpc/chat.bsky.convo.muteConvo")
    suspend fun muteConvo(@Body body: Map<String, String>): Response<ResponseBody>

    @POST("/xrpc/chat.bsky.convo.unmuteConvo")
    suspend fun unmuteConvo(@Body body: Map<String, String>): Response<ResponseBody>

    @POST("/xrpc/chat.bsky.convo.leaveConvo")
    suspend fun leaveConvo(@Body body: Map<String, String>): Response<ResponseBody>
}

/**
 * Public API interface (no authentication required)
 */
interface ATProtoPublicApi {

    @GET("/xrpc/app.bsky.unspecced.getTrendingTopics")
    suspend fun getTrendingTopics(
        @Query("limit") limit: Int = 10
    ): TrendingTopicsResponse
}
