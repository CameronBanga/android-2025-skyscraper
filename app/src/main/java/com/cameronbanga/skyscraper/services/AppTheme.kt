package com.cameronbanga.skyscraper.services

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Manages app-wide theme colors
 */
class AppTheme private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: AppTheme? = null

        fun getInstance(context: Context): AppTheme = INSTANCE ?: synchronized(this) {
            INSTANCE ?: AppTheme(context.applicationContext).also { INSTANCE = it }
        }

        val shared get() = INSTANCE
            ?: throw IllegalStateException("AppTheme not initialized")
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(
        "skyscraper_theme",
        Context.MODE_PRIVATE
    )

    private val _accentColor = MutableStateFlow(ThemeColor.Orange.color)
    val accentColor: StateFlow<Color> = _accentColor.asStateFlow()

    private val _isCustomColor = MutableStateFlow(false)
    val isCustomColor: StateFlow<Boolean> = _isCustomColor.asStateFlow()

    init {
        loadColor()
    }

    private fun loadColor() {
        val colorName = prefs.getString("accent_color", null)

        when {
            colorName == "custom" -> {
                _isCustomColor.value = true
                _accentColor.value = loadCustomColor() ?: ThemeColor.Orange.color
            }
            colorName != null -> {
                val themeColor = ThemeColor.values().firstOrNull { it.name == colorName }
                _isCustomColor.value = false
                _accentColor.value = themeColor?.color ?: ThemeColor.Orange.color
            }
            else -> {
                _isCustomColor.value = false
                _accentColor.value = ThemeColor.Orange.color
            }
        }
    }

    fun setThemeColor(themeColor: ThemeColor) {
        _isCustomColor.value = false
        _accentColor.value = themeColor.color
        saveColor(themeColor.name)
    }

    fun setCustomColor(color: Color) {
        _isCustomColor.value = true
        _accentColor.value = color
        saveCustomColor(color)
    }

    private fun saveColor(colorName: String) {
        prefs.edit()
            .putString("accent_color", colorName)
            .apply()

        // Clear custom color data
        prefs.edit()
            .remove("custom_color_argb")
            .apply()
    }

    private fun saveCustomColor(color: Color) {
        prefs.edit()
            .putString("accent_color", "custom")
            .putInt("custom_color_argb", color.toArgb())
            .apply()
    }

    private fun loadCustomColor(): Color? {
        val argb = prefs.getInt("custom_color_argb", 0)
        return if (argb != 0) {
            Color(argb)
        } else {
            null
        }
    }
}

enum class ThemeColor(val displayName: String, val color: Color) {
    Orange("Orange", Color(0xFFFF9500)),
    Blue("Blue", Color(0xFF007AFF)),
    Purple("Purple", Color(0xFFAF52DE)),
    Pink("Pink", Color(0xFFFF2D55)),
    Green("Green", Color(0xFF34C759)),
    Red("Red", Color(0xFFFF3B30)),
    Teal("Teal", Color(0xFF5AC8FA)),
    Indigo("Indigo", Color(0xFF5856D6)),
    Yellow("Yellow", Color(0xFFFFCC00))
}
