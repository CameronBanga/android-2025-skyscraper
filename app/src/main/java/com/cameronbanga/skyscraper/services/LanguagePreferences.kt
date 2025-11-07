package com.cameronbanga.skyscraper.services

import android.content.Context
import android.content.SharedPreferences
import com.cameronbanga.skyscraper.models.Language
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Manages language preferences for post composition
 */
class LanguagePreferences private constructor(context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: LanguagePreferences? = null

        fun getInstance(context: Context): LanguagePreferences = INSTANCE ?: synchronized(this) {
            INSTANCE ?: LanguagePreferences(context.applicationContext).also { INSTANCE = it }
        }

        val shared: LanguagePreferences get() = INSTANCE
            ?: throw IllegalStateException("LanguagePreferences not initialized")

        private const val PREFS_NAME = "com.skyscraper.languagePreferences"
        private const val KEY_PREFERRED_LANGUAGE = "preferred_language"
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _preferredLanguage = MutableStateFlow(loadPreferredLanguage())
    val preferredLanguage: StateFlow<Language> = _preferredLanguage.asStateFlow()

    /**
     * Set preferred language
     */
    fun setPreferredLanguage(language: Language) {
        _preferredLanguage.value = language
        prefs.edit().putString(KEY_PREFERRED_LANGUAGE, language.id).apply()
    }

    /**
     * Load preferred language from SharedPreferences
     */
    private fun loadPreferredLanguage(): Language {
        val languageId = prefs.getString(KEY_PREFERRED_LANGUAGE, null)
        return if (languageId != null) {
            Language.allLanguages.firstOrNull { it.id == languageId } ?: Language.defaultLanguage
        } else {
            Language.defaultLanguage
        }
    }
}
