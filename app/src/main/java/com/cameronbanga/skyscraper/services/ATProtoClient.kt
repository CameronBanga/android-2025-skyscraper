package com.cameronbanga.skyscraper.services

import android.graphics.Bitmap
import android.util.Log
import com.cameronbanga.skyscraper.models.*
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import java.io.ByteArrayOutputStream
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.regex.Pattern

/**
 * AT Protocol API client for BlueSky
 * Main API client - handles all interactions with the AT Protocol/BlueSky API
 */
class ATProtoClient private constructor() {

    companion object {
        @Volatile
        private var INSTANCE: ATProtoClient? = null

        fun getInstance(): ATProtoClient = INSTANCE ?: synchronized(this) {
            INSTANCE ?: ATProtoClient().also { INSTANCE = it }
        }

        val shared: ATProtoClient get() = getInstance()
    }

    // Session state
    private val _session = MutableStateFlow<ATProtoSession?>(null)
    val session: StateFlow<ATProtoSession?> = _session.asStateFlow()

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()

    private val _isChatAvailable = MutableStateFlow(false)
    val isChatAvailable: StateFlow<Boolean> = _isChatAvailable.asStateFlow()

    private var baseURL = ATProtoUrls.DEFAULT_PDS
    private val refreshMutex = Mutex()

    // Moshi for JSON
    private val moshi = Moshi.Builder()
        .addLast(KotlinJsonAdapterFactory())
        .build()

    // OkHttp client with interceptors
    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor(AuthInterceptor())
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        })
        .build()

    // Retrofit instances
    private var api: ATProtoApi = createApi(baseURL)
    private var chatApi: ATProtoChatApi = createChatApi()
    private val publicApi: ATProtoPublicApi = createPublicApi()

    private fun createApi(baseUrl: String): ATProtoApi {
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(ATProtoApi::class.java)
    }

    private fun createChatApi(): ATProtoChatApi {
        return Retrofit.Builder()
            .baseUrl(ATProtoUrls.CHAT_API)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(ATProtoChatApi::class.java)
    }

    private fun createPublicApi(): ATProtoPublicApi {
        return Retrofit.Builder()
            .baseUrl(ATProtoUrls.PUBLIC_API)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(ATProtoPublicApi::class.java)
    }

    // Auth Interceptor to add Bearer token
    private inner class AuthInterceptor : Interceptor {
        override fun intercept(chain: Interceptor.Chain): okhttp3.Response {
            val originalRequest = chain.request()
            val currentSession = _session.value

            val requestWithAuth = if (currentSession != null && !originalRequest.url.encodedPath.contains("createSession")) {
                originalRequest.newBuilder()
                    .header("Authorization", "Bearer ${currentSession.accessJwt}")
                    .build()
            } else {
                originalRequest
            }

            return chain.proceed(requestWithAuth)
        }
    }

    // MARK: - Session Management

    suspend fun login(identifier: String, password: String, customPDSURL: String? = null) {
        val pdsUrl = customPDSURL ?: ATProtoUrls.DEFAULT_PDS
        baseURL = pdsUrl
        api = createApi(baseURL)

        val request = CreateSessionRequest(identifier, password)
        val response = api.createSession(request)

        val session = ATProtoSession(
            did = response.did,
            handle = response.handle,
            email = response.email,
            accessJwt = response.accessJwt,
            refreshJwt = response.refreshJwt,
            pdsURL = pdsUrl
        )

        saveSession(session)
        Log.d("ATProtoClient", "✅ Logged in as ${session.handle}")
    }

    private fun saveSession(session: ATProtoSession) {
        _session.value = session
        _isAuthenticated.value = true
        updateChatAvailability()
        // TODO: Save to secure storage (EncryptedSharedPreferences)
    }

    suspend fun logout() {
        _session.value = null
        _isAuthenticated.value = false
        baseURL = ATProtoUrls.DEFAULT_PDS
        api = createApi(baseURL)
        updateChatAvailability()
        // TODO: Clear from secure storage
    }

    private fun updateChatAvailability() {
        val currentSession = _session.value
        _isChatAvailable.value = if (currentSession != null) {
            currentSession.pdsURL?.contains("bsky.social") == true ||
                    baseURL == ATProtoUrls.DEFAULT_PDS
        } else {
            false
        }
    }

    suspend fun refreshSession() = refreshMutex.withLock {
        val currentSession = _session.value
            ?: throw ATProtoException.Unauthorized("No session to refresh")

        Log.d("ATProtoClient", "🔄 Refreshing session...")

        val response = api.refreshSession()
        val newSession = ATProtoSession(
            did = response.did,
            handle = response.handle,
            email = response.email,
            accessJwt = response.accessJwt,
            refreshJwt = response.refreshJwt,
            pdsURL = currentSession.pdsURL
        )

        saveSession(newSession)
        Log.d("ATProtoClient", "✅ Session refreshed successfully")
    }

    // MARK: - Feed Operations

    suspend fun getTimeline(limit: Int = 50, cursor: String? = null): FeedResponse {
        val clampedLimit = ATProtoLimits.clampFeedLimit(limit, ATProtoLimits.Feed.MAX_TIMELINE_POSTS)
        return api.getTimeline(clampedLimit, cursor)
    }

    suspend fun getFeed(feed: String, limit: Int = 50, cursor: String? = null): FeedResponse {
        val clampedLimit = ATProtoLimits.clampFeedLimit(limit, ATProtoLimits.Feed.MAX_FEED_POSTS)
        return api.getFeed(feed, clampedLimit, cursor)
    }

    suspend fun getAuthorFeed(
        actor: String,
        filter: String = "posts_with_replies",
        limit: Int = 50,
        cursor: String? = null
    ): FeedResponse {
        return api.getAuthorFeed(actor, filter, limit, cursor)
    }

    suspend fun getActorLikes(actor: String, limit: Int = 50, cursor: String? = null): FeedResponse {
        return api.getActorLikes(actor, limit, cursor)
    }

    suspend fun searchPosts(query: String, cursor: String? = null, limit: Int = 50): SearchPostsResponse {
        return api.searchPosts(query, limit, cursor)
    }

    suspend fun getSuggestedFeeds(limit: Int = 50, cursor: String? = null): FeedGeneratorsResponse {
        val clampedLimit = ATProtoLimits.clampFeedLimit(limit, ATProtoLimits.Feed.MAX_SUGGESTED_FEEDS)
        return api.getSuggestedFeeds(clampedLimit, cursor)
    }

    // MARK: - Post Operations

    suspend fun uploadImage(bitmap: Bitmap, altText: String? = null): UploadedImage? {
        // Compress image to JPEG < 925KB
        var quality = 90
        var imageData: ByteArray

        do {
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream)
            imageData = outputStream.toByteArray()
            quality -= 10
        } while (imageData.size > 925 * 1024 && quality > 10)

        val requestBody = imageData.toRequestBody("image/jpeg".toMediaType())
        val response = api.uploadBlob(requestBody)

        if (response.isSuccessful) {
            val responseBody = response.body()?.string()
            val blobAdapter = moshi.adapter(UploadBlobResponse::class.java)
            val uploadResponse = blobAdapter.fromJson(responseBody ?: "")

            return uploadResponse?.blob?.let { blob ->
                UploadedImage(blob, altText ?: "")
            }
        }

        return null
    }

    suspend fun createPost(
        text: String,
        reply: ReplyRef? = null,
        images: List<UploadedImage>? = null,
        langs: List<String>? = null,
        moderationSettings: PostModerationSettings? = null
    ): Post {
        val session = _session.value ?: throw ATProtoException.Unauthorized("Not logged in")
        val now = Instant.now().toString()

        // Detect facets (mentions, links, hashtags)
        val facets = detectFacets(text)

        // Build record
        val record = mutableMapOf<String, Any>(
            "\$type" to "app.bsky.feed.post",
            "text" to text,
            "createdAt" to now
        )

        if (facets.isNotEmpty()) {
            record["facets"] = facets
        }

        if (!langs.isNullOrEmpty()) {
            record["langs"] = langs
        }

        if (!images.isNullOrEmpty()) {
            record["embed"] = mapOf(
                "\$type" to "app.bsky.embed.images",
                "images" to images.map { img ->
                    mapOf(
                        "alt" to img.altText,
                        "image" to img.blob
                    )
                }
            )
        }

        if (reply != null) {
            record["reply"] = mapOf(
                "root" to mapOf("uri" to reply.root.uri, "cid" to reply.root.cid),
                "parent" to mapOf("uri" to reply.parent.uri, "cid" to reply.parent.cid)
            )
        }

        // Create post
        val body = mapOf(
            "repo" to session.did,
            "collection" to ATProtoCollections.POST,
            "record" to record
        )

        val response = api.createRecord(body)
        val responseBody = response.body()?.string()
        val postAdapter = moshi.adapter(CreateRecordResponse::class.java)
        val createResponse = postAdapter.fromJson(responseBody ?: "")
            ?: throw ATProtoException.DecodingError("Failed to decode post response")

        // TODO: Handle threadgate and postgate if moderationSettings provided

        // Return a minimal Post object (should be fetched from timeline for full data)
        return Post(
            uri = createResponse.uri,
            cid = createResponse.cid,
            author = Author(
                did = session.did,
                handle = session.handle
            ),
            record = PostRecord(
                text = text,
                createdAt = now,
                facets = facets,
                langs = langs
            )
        )
    }

    suspend fun likePost(uri: String, cid: String): String {
        val session = _session.value ?: throw ATProtoException.Unauthorized("Not logged in")
        val now = Instant.now().toString()

        val body = mapOf(
            "repo" to session.did,
            "collection" to ATProtoCollections.LIKE,
            "record" to mapOf(
                "\$type" to "app.bsky.feed.like",
                "subject" to mapOf("uri" to uri, "cid" to cid),
                "createdAt" to now
            )
        )

        val response = api.createRecord(body)
        val responseBody = response.body()?.string()
        val adapter = moshi.adapter(CreateRecordResponse::class.java)
        val createResponse = adapter.fromJson(responseBody ?: "")
            ?: throw ATProtoException.DecodingError("Failed to decode like response")

        return createResponse.uri
    }

    suspend fun unlikePost(likeUri: String) {
        val session = _session.value ?: throw ATProtoException.Unauthorized("Not logged in")
        val rkey = likeUri.substringAfterLast("/")

        val body = mapOf(
            "repo" to session.did,
            "collection" to ATProtoCollections.LIKE,
            "rkey" to rkey
        )

        api.deleteRecord(body)
    }

    suspend fun repost(uri: String, cid: String): String {
        val session = _session.value ?: throw ATProtoException.Unauthorized("Not logged in")
        val now = Instant.now().toString()

        val body = mapOf(
            "repo" to session.did,
            "collection" to ATProtoCollections.REPOST,
            "record" to mapOf(
                "\$type" to "app.bsky.feed.repost",
                "subject" to mapOf("uri" to uri, "cid" to cid),
                "createdAt" to now
            )
        )

        val response = api.createRecord(body)
        val responseBody = response.body()?.string()
        val adapter = moshi.adapter(CreateRecordResponse::class.java)
        val createResponse = adapter.fromJson(responseBody ?: "")
            ?: throw ATProtoException.DecodingError("Failed to decode repost response")

        return createResponse.uri
    }

    suspend fun unrepost(repostUri: String) {
        val session = _session.value ?: throw ATProtoException.Unauthorized("Not logged in")
        val rkey = repostUri.substringAfterLast("/")

        val body = mapOf(
            "repo" to session.did,
            "collection" to ATProtoCollections.REPOST,
            "rkey" to rkey
        )

        api.deleteRecord(body)
    }

    // MARK: - Thread Operations

    suspend fun getPostThread(
        uri: String,
        depth: Int? = null,
        parentHeight: Int? = null
    ): ThreadResponse {
        return api.getPostThread(uri, depth, parentHeight)
    }

    // MARK: - Profile Operations

    suspend fun getProfile(actor: String): Profile {
        return api.getProfile(actor)
    }

    suspend fun searchUsers(query: String, limit: Int = 25): ActorSearchResponse {
        return api.searchActors(query, limit)
    }

    suspend fun followUser(did: String): String {
        val session = _session.value ?: throw ATProtoException.Unauthorized("Not logged in")
        val now = Instant.now().toString()

        val body = mapOf(
            "repo" to session.did,
            "collection" to ATProtoCollections.FOLLOW,
            "record" to mapOf(
                "\$type" to "app.bsky.graph.follow",
                "subject" to did,
                "createdAt" to now
            )
        )

        val response = api.createRecord(body)
        val responseBody = response.body()?.string()
        val adapter = moshi.adapter(CreateRecordResponse::class.java)
        val createResponse = adapter.fromJson(responseBody ?: "")
            ?: throw ATProtoException.DecodingError("Failed to decode follow response")

        return createResponse.uri
    }

    suspend fun unfollowUser(followUri: String) {
        val session = _session.value ?: throw ATProtoException.Unauthorized("Not logged in")
        val rkey = followUri.substringAfterLast("/")

        val body = mapOf(
            "repo" to session.did,
            "collection" to ATProtoCollections.FOLLOW,
            "rkey" to rkey
        )

        api.deleteRecord(body)
    }

    // MARK: - Notifications

    suspend fun getNotifications(cursor: String? = null, limit: Int = 50): NotificationsResponse {
        return api.listNotifications(limit, cursor)
    }

    suspend fun updateSeenNotifications(seenAt: Instant = Instant.now()) {
        val seenAtStr = DateTimeFormatter.ISO_INSTANT.format(seenAt)
        val body = mapOf("seenAt" to seenAtStr)
        api.updateSeenNotifications(body)
    }

    // MARK: - Preferences

    suspend fun getPreferences(): PreferencesResponse {
        return api.getPreferences()
    }

    suspend fun putPreferences(preferences: List<Preference>) {
        val preferencesMap = preferences.map { pref ->
            when (pref) {
                is Preference.SavedFeeds -> mapOf<String, Any>(
                    "\$type" to "app.bsky.actor.defs#savedFeedsPref",
                    "pinned" to pref.data.pinned,
                    "saved" to pref.data.saved
                )
                is Preference.PersonalDetails -> mapOf<String, Any>(
                    "\$type" to "app.bsky.actor.defs#personalDetailsPref",
                    "birthDate" to (pref.data.birthDate ?: "")
                )
                else -> mapOf<String, Any>()
            }
        }

        val body = mapOf("preferences" to preferencesMap)
        api.putPreferences(body)
    }

    // MARK: - Lists and Starter Packs

    suspend fun getList(list: String, limit: Int = 100, cursor: String? = null): ListResponse {
        return api.getList(list, limit, cursor)
    }

    suspend fun getStarterPacks(uris: List<String>): StarterPacksResponse {
        return api.getStarterPacks(uris)
    }

    suspend fun getActorStarterPacks(
        actor: String,
        limit: Int = 50,
        cursor: String? = null
    ): StarterPacksResponse {
        return api.getActorStarterPacks(actor, limit, cursor)
    }

    // MARK: - Chat Operations

    suspend fun listConvos(limit: Int = 50, cursor: String? = null): ListConvosResponse {
        if (!_isChatAvailable.value) {
            throw ATProtoException.ChatNotAvailable("Chat is only available on bsky.social")
        }
        return chatApi.listConvos(limit, cursor)
    }

    suspend fun getMessages(convoId: String, limit: Int = 50, cursor: String? = null): GetMessagesResponse {
        if (!_isChatAvailable.value) {
            throw ATProtoException.ChatNotAvailable("Chat is only available on bsky.social")
        }
        return chatApi.getMessages(convoId, limit, cursor)
    }

    suspend fun sendMessage(convoId: String, message: MessageInput): SendMessageResponse {
        if (!_isChatAvailable.value) {
            throw ATProtoException.ChatNotAvailable("Chat is only available on bsky.social")
        }
        val body = mapOf(
            "convoId" to convoId,
            "message" to mapOf("text" to message.text)
        )
        return chatApi.sendMessage(body)
    }

    // MARK: - Public API

    suspend fun getTrendingTopics(limit: Int = 10): TrendingTopicsResponse {
        return publicApi.getTrendingTopics(limit)
    }

    // MARK: - Facet Detection

    private fun detectFacets(text: String): List<Facet> {
        val facets = mutableListOf<Facet>()

        // Detect mentions (@handle)
        val mentionPattern = Pattern.compile("(?:^|\\s)@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)")
        val mentionMatcher = mentionPattern.matcher(text)
        while (mentionMatcher.find()) {
            val start = mentionMatcher.start() + if (mentionMatcher.group().startsWith(" ")) 1 else 0
            val end = mentionMatcher.end()
            val handle = text.substring(start + 1, end)  // Remove @

            // TODO: Resolve handle to DID via API
            facets.add(
                Facet(
                    index = ByteSlice(start, end),
                    features = listOf(
                        FeatureJson(
                            type = "app.bsky.richtext.facet#mention",
                            did = "did:placeholder:$handle"  // Should resolve to actual DID
                        )
                    )
                )
            )
        }

        // Detect URLs
        val urlPattern = Pattern.compile("https?://[^\\s]+")
        val urlMatcher = urlPattern.matcher(text)
        while (urlMatcher.find()) {
            facets.add(
                Facet(
                    index = ByteSlice(urlMatcher.start(), urlMatcher.end()),
                    features = listOf(
                        FeatureJson(
                            type = "app.bsky.richtext.facet#link",
                            uri = text.substring(urlMatcher.start(), urlMatcher.end())
                        )
                    )
                )
            )
        }

        // Detect hashtags
        val hashtagPattern = Pattern.compile("(?:^|\\s)#([a-zA-Z0-9_]+)")
        val hashtagMatcher = hashtagPattern.matcher(text)
        while (hashtagMatcher.find()) {
            val start = hashtagMatcher.start() + if (hashtagMatcher.group().startsWith(" ")) 1 else 0
            val end = hashtagMatcher.end()
            val tag = text.substring(start + 1, end)  // Remove #

            facets.add(
                Facet(
                    index = ByteSlice(start, end),
                    features = listOf(
                        FeatureJson(
                            type = "app.bsky.richtext.facet#tag",
                            tag = tag
                        )
                    )
                )
            )
        }

        return facets
    }
}

// MARK: - Response Models for Internal Use

data class CreateRecordResponse(
    val uri: String,
    val cid: String
)

data class UploadBlobResponse(
    val blob: BlobRef
)

data class BlobRef(
    val type: String,
    val ref: Map<String, String>,
    val mimeType: String,
    val size: Int
)

data class UploadedImage(
    val blob: BlobRef,
    val altText: String
)

// MARK: - Exceptions

sealed class ATProtoException(message: String) : Exception(message) {
    data class NetworkError(val error: Throwable, val url: String? = null, val statusCode: Int? = null) :
        ATProtoException("Network error: ${error.message}")

    data class DecodingError(val error: String) :
        ATProtoException("Decoding error: $error")

    data class Unauthorized(val error: String) :
        ATProtoException("Unauthorized: $error")

    data class ChatNotAvailable(val error: String) :
        ATProtoException("Chat not available: $error")

    data class ApiError(val error: String) :
        ATProtoException("API error: $error")
}
