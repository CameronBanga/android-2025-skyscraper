package com.cameronbanga.skyscraper.models

data class Language(
    val id: String,  // ISO 639-1 code
    val name: String
) {
    companion object {
        val allLanguages = listOf(
            Language("en", "English"),
            Language("es", "Spanish"),
            Language("fr", "French"),
            Language("de", "German"),
            Language("it", "Italian"),
            Language("pt", "Portuguese"),
            Language("nl", "Dutch"),
            Language("pl", "Polish"),
            Language("ru", "Russian"),
            Language("ja", "Japanese"),
            Language("ko", "Korean"),
            Language("zh", "Chinese"),
            Language("ar", "Arabic"),
            Language("hi", "Hindi"),
            Language("bn", "Bengali"),
            Language("pa", "Punjabi"),
            Language("te", "Telugu"),
            Language("mr", "Marathi"),
            Language("ta", "Tamil"),
            Language("ur", "Urdu"),
            Language("tr", "Turkish"),
            Language("vi", "Vietnamese"),
            Language("th", "Thai"),
            Language("id", "Indonesian"),
            Language("ms", "Malay"),
            Language("fil", "Filipino"),
            Language("sv", "Swedish"),
            Language("no", "Norwegian"),
            Language("da", "Danish"),
            Language("fi", "Finnish"),
            Language("cs", "Czech"),
            Language("sk", "Slovak"),
            Language("hu", "Hungarian"),
            Language("ro", "Romanian"),
            Language("bg", "Bulgarian"),
            Language("hr", "Croatian"),
            Language("sr", "Serbian"),
            Language("uk", "Ukrainian"),
            Language("el", "Greek"),
            Language("he", "Hebrew"),
            Language("fa", "Persian"),
            Language("sw", "Swahili"),
            Language("af", "Afrikaans"),
            Language("am", "Amharic"),
            Language("ca", "Catalan"),
            Language("eu", "Basque"),
            Language("gl", "Galician"),
            Language("cy", "Welsh"),
            Language("ga", "Irish"),
            Language("is", "Icelandic"),
            Language("lt", "Lithuanian"),
            Language("lv", "Latvian"),
            Language("et", "Estonian"),
            Language("mt", "Maltese"),
            Language("sq", "Albanian"),
            Language("mk", "Macedonian"),
            Language("sl", "Slovenian"),
            Language("bs", "Bosnian")
        ).sortedBy { it.name }

        val defaultLanguage = Language("en", "English")
    }
}
