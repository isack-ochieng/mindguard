package com.example.content_filter_vpn

/**
 * Small deterministic local policy list.
 *
 * Gemini can later extend this list, but the core blocker remains local
 * and continues working with no AI key and no AI network call.
 */
object PolicyLists {
    val blockedDomains: Map<String, String> = mapOf(
        // Gambling — prominent for the demo.
        "betika.com" to "gambling",
        "betway.com" to "gambling",
        "bet365.com" to "gambling",
        "1xbet.com" to "gambling",
        "sportpesa.com" to "gambling",

        // Small representative adult-content set.
        "pornhub.com" to "adult",
        "xvideos.com" to "adult",
        "xnxx.com" to "adult",
        "xhamster.com" to "adult"
    )

    val allowedDomains: Set<String> = setOf(
        "google.com",
        "googleapis.com",
        "gstatic.com",
        "android.com",
        "googleusercontent.com",
        "github.com"
    )

    val riskyReputation: Map<String, String> = emptyMap()
}
