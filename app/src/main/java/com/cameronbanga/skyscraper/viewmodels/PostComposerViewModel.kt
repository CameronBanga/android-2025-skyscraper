package com.cameronbanga.skyscraper.viewmodels

import android.app.Application
import android.content.ContentResolver
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cameronbanga.skyscraper.models.*
import com.cameronbanga.skyscraper.services.ATProtoClient
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for post composition
 * Handles text, images, language, moderation settings, mentions, hashtags, and posting
 */
class PostComposerViewModel(
    application: Application,
    private val replyTo: ReplyRef? = null,
    private val draft: PostDraft? = null
) : AndroidViewModel(application) {

    private val client = ATProtoClient.getInstance()
    private val contentResolver: ContentResolver = application.contentResolver

    private val _text = MutableStateFlow("")
    val text: StateFlow<String> = _text.asStateFlow()

    private val _selectedImages = MutableStateFlow<List<Uri>>(emptyList())
    val selectedImages: StateFlow<List<Uri>> = _selectedImages.asStateFlow()

    private val _imageAltTexts = MutableStateFlow<List<String>>(emptyList())
    val imageAltTexts: StateFlow<List<String>> = _imageAltTexts.asStateFlow()

    private val _selectedLanguage = MutableStateFlow(Language.defaultLanguage)
    val selectedLanguage: StateFlow<Language> = _selectedLanguage.asStateFlow()

    private val _moderationSettings = MutableStateFlow(ModerationSettings.default)
    val moderationSettings: StateFlow<ModerationSettings> = _moderationSettings.asStateFlow()

    private val _isPosting = MutableStateFlow(false)
    val isPosting: StateFlow<Boolean> = _isPosting.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _mentionSuggestions = MutableStateFlow<List<Profile>>(emptyList())
    val mentionSuggestions: StateFlow<List<Profile>> = _mentionSuggestions.asStateFlow()

    private val _hashtagSuggestions = MutableStateFlow<List<String>>(emptyList())
    val hashtagSuggestions: StateFlow<List<String>> = _hashtagSuggestions.asStateFlow()

    private val _cursorPosition = MutableStateFlow(0)
    private val cursorPosition: StateFlow<Int> = _cursorPosition.asStateFlow()

    private var mentionSearchJob: Job? = null
    private var hashtagSearchJob: Job? = null
    private var currentDraftId: String? = draft?.id

    val characterCount: StateFlow<Int> = MutableStateFlow(0).apply {
        viewModelScope.launch {
            text.collect { value = it.length }
        }
    }

    val canPost: StateFlow<Boolean> = MutableStateFlow(false).apply {
        viewModelScope.launch {
            text.collect {
                val hasText = it.trim().isNotEmpty()
                val hasMedia = _selectedImages.value.isNotEmpty()
                val withinLimit = it.length <= 300
                value = (hasText || hasMedia) && withinLimit
            }
        }
    }

    val canSaveDraft: StateFlow<Boolean> = MutableStateFlow(false).apply {
        viewModelScope.launch {
            text.collect {
                value = it.trim().isNotEmpty() || _selectedImages.value.isNotEmpty()
            }
        }
    }

    init {
        // Load draft if provided
        draft?.let { loadDraft(it) }
    }

    private fun loadDraft(draft: PostDraft) {
        _text.value = draft.text
        _imageAltTexts.value = draft.imageAltTexts
        _selectedLanguage.value = Language.allLanguages.firstOrNull { it.id == draft.languageId }
            ?: Language.defaultLanguage
        _moderationSettings.value = draft.moderationSettings
        // Note: selectedImages would need to be restored from imageData if needed
    }

    fun updateText(newText: String) {
        _text.value = newText
        _cursorPosition.value = newText.length
        detectMention()
        detectHashtag()
    }

    fun loadSelectedImages(uris: List<Uri>) {
        _selectedImages.value = uris
        // Initialize alt texts for new images
        _imageAltTexts.value = List(uris.size) { index ->
            _imageAltTexts.value.getOrNull(index) ?: ""
        }
    }

    fun removeImage(index: Int) {
        if (index < _selectedImages.value.size) {
            _selectedImages.value = _selectedImages.value.filterIndexed { i, _ -> i != index }
            _imageAltTexts.value = _imageAltTexts.value.filterIndexed { i, _ -> i != index }
        }
    }

    fun updateAltText(index: Int, altText: String) {
        if (index < _imageAltTexts.value.size) {
            _imageAltTexts.value = _imageAltTexts.value.toMutableList().apply {
                this[index] = altText
            }
        }
    }

    fun setLanguage(language: Language) {
        _selectedLanguage.value = language
    }

    fun setModerationSettings(settings: ModerationSettings) {
        _moderationSettings.value = settings
    }

    // MARK: - Mention Autocomplete

    private fun detectMention() {
        mentionSearchJob?.cancel()

        val cursorIndex = _cursorPosition.value.coerceIn(0, _text.value.length)
        val textBeforeCursor = _text.value.substring(0, cursorIndex)

        // Find the last @ symbol before cursor
        val lastAtIndex = textBeforeCursor.lastIndexOf('@')
        if (lastAtIndex >= 0) {
            val mentionText = textBeforeCursor.substring(lastAtIndex + 1)

            // Check if there's a space (which would end the mention)
            if (!mentionText.contains(' ')) {
                searchMentions(mentionText)
            } else {
                clearMentionSuggestions()
            }
        } else {
            clearMentionSuggestions()
        }
    }

    private fun searchMentions(query: String) {
        mentionSearchJob?.cancel()

        mentionSearchJob = viewModelScope.launch {
            try {
                // Add delay to avoid too many API calls
                delay(300)

                val results = mutableListOf<Profile>()
                val seenDIDs = mutableSetOf<String>()

                // Get current user's DID
                val currentUserDID = client.session.value?.did ?: return@launch

                // 1. Search follows
                try {
                    val follows = client.getFollows(currentUserDID, limit = 50)
                    follows.forEach { profile ->
                        if (query.isEmpty() ||
                            profile.handle.contains(query, ignoreCase = true) ||
                            (profile.displayName?.contains(query, ignoreCase = true) == true)
                        ) {
                            if (!seenDIDs.contains(profile.did)) {
                                results.add(profile)
                                seenDIDs.add(profile.did)
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Continue even if follows search fails
                }

                // 2. Search followers
                try {
                    val followers = client.getFollowers(currentUserDID, limit = 50)
                    followers.forEach { profile ->
                        if (query.isEmpty() ||
                            profile.handle.contains(query, ignoreCase = true) ||
                            (profile.displayName?.contains(query, ignoreCase = true) == true)
                        ) {
                            if (!seenDIDs.contains(profile.did)) {
                                results.add(profile)
                                seenDIDs.add(profile.did)
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Continue even if followers search fails
                }

                // 3. Search all users if we need more results
                if (results.size < 10 && query.isNotEmpty()) {
                    try {
                        val searchResults = client.searchUsers(query, limit = 10)
                        searchResults.forEach { profile ->
                            if (!seenDIDs.contains(profile.did)) {
                                results.add(profile)
                                seenDIDs.add(profile.did)
                            }
                        }
                    } catch (e: Exception) {
                        // Continue even if search fails
                    }
                }

                // Limit to 10 results
                _mentionSuggestions.value = results.take(10)
            } catch (e: Exception) {
                // Ignore errors in mention search
            }
        }
    }

    fun insertMention(profile: Profile) {
        val cursorIndex = _cursorPosition.value.coerceIn(0, _text.value.length)
        val textBeforeCursor = _text.value.substring(0, cursorIndex)

        // Find the last @ symbol
        val lastAtIndex = textBeforeCursor.lastIndexOf('@')
        if (lastAtIndex >= 0) {
            val beforeAt = _text.value.substring(0, lastAtIndex)
            val afterCursor = _text.value.substring(cursorIndex)

            // Insert the mention
            val mention = "@${profile.handle} "
            _text.value = beforeAt + mention + afterCursor
            _cursorPosition.value = beforeAt.length + mention.length

            clearMentionSuggestions()
        }
    }

    private fun clearMentionSuggestions() {
        _mentionSuggestions.value = emptyList()
        mentionSearchJob?.cancel()
    }

    // MARK: - Hashtag Autocomplete

    private fun detectHashtag() {
        hashtagSearchJob?.cancel()

        val cursorIndex = _cursorPosition.value.coerceIn(0, _text.value.length)
        val textBeforeCursor = _text.value.substring(0, cursorIndex)

        // Find the last # symbol before cursor
        val lastHashIndex = textBeforeCursor.lastIndexOf('#')
        if (lastHashIndex >= 0) {
            val hashtagText = textBeforeCursor.substring(lastHashIndex + 1)

            // Check if there's a space (which would end the hashtag)
            if (!hashtagText.contains(' ')) {
                searchHashtags(hashtagText)
            } else {
                clearHashtagSuggestions()
            }
        } else {
            clearHashtagSuggestions()
        }
    }

    private fun searchHashtags(query: String) {
        hashtagSearchJob?.cancel()

        hashtagSearchJob = viewModelScope.launch {
            try {
                // Add delay to avoid too many API calls
                delay(300)

                // Search for posts with this hashtag
                val searchQuery = if (query.isEmpty()) "popular" else "#$query"
                val response = client.searchPosts(searchQuery, limit = 20)

                // Extract unique hashtags from posts
                val hashtags = mutableSetOf<String>()
                response.posts.forEach { post ->
                    post.record.tags?.forEach { tag ->
                        hashtags.add(tag)
                    }
                }

                // Filter by query and limit to 10
                val filteredHashtags = hashtags.sorted().filter { tag ->
                    query.isEmpty() || tag.startsWith(query, ignoreCase = true)
                }.take(10)

                _hashtagSuggestions.value = filteredHashtags
            } catch (e: Exception) {
                // Ignore errors in hashtag search
            }
        }
    }

    fun insertHashtag(tag: String) {
        val cursorIndex = _cursorPosition.value.coerceIn(0, _text.value.length)
        val textBeforeCursor = _text.value.substring(0, cursorIndex)

        // Find the last # symbol
        val lastHashIndex = textBeforeCursor.lastIndexOf('#')
        if (lastHashIndex >= 0) {
            val beforeHash = _text.value.substring(0, lastHashIndex)
            val afterCursor = _text.value.substring(cursorIndex)

            // Insert the hashtag
            val hashtag = "#$tag "
            _text.value = beforeHash + hashtag + afterCursor
            _cursorPosition.value = beforeHash.length + hashtag.length

            clearHashtagSuggestions()
        }
    }

    private fun clearHashtagSuggestions() {
        _hashtagSuggestions.value = emptyList()
        hashtagSearchJob?.cancel()
    }

    // MARK: - Posting

    fun post(onComplete: (Boolean) -> Unit) {
        if (!canPost.value) {
            onComplete(false)
            return
        }

        viewModelScope.launch {
            _isPosting.value = true
            _errorMessage.value = null

            try {
                // Upload images if any are selected
                val uploadedImages = mutableListOf<UploadedImage>()
                _selectedImages.value.forEachIndexed { index, uri ->
                    try {
                        val inputStream = contentResolver.openInputStream(uri)
                        val bytes = inputStream?.readBytes()
                        inputStream?.close()

                        if (bytes != null) {
                            val altText = _imageAltTexts.value.getOrNull(index)
                                ?.takeIf { it.isNotEmpty() }
                            val uploaded = client.uploadImageBytes(bytes, altText)
                            uploadedImages.add(uploaded)
                        }
                    } catch (e: Exception) {
                        // Continue even if one image fails
                    }
                }

                // Create post
                client.createPost(
                    text = _text.value,
                    reply = replyTo,
                    images = uploadedImages.ifEmpty { null },
                    langs = listOf(_selectedLanguage.value.id)
                )

                // Clear form on success
                _text.value = ""
                _selectedImages.value = emptyList()
                _imageAltTexts.value = emptyList()

                onComplete(true)
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Failed to create post"
                onComplete(false)
            } finally {
                _isPosting.value = false
            }
        }
    }

    fun saveDraft() {
        if (!canSaveDraft.value) return

        // TODO: Implement draft saving to local storage
        // This would require a DraftManager similar to the iOS version
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
