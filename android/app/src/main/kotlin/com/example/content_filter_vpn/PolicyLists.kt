package com.example.content_filter_vpn

/**
 * Built-in local policy data.
 *
 * These are deliberately small seed lists for the local engine. The architecture
 * is designed so larger signed/downloaded lists can replace or extend them later.
 */
object PolicyLists {
    val blockedDomains: Map<String, String> = mapOf(
        // Adult
        "pornhub.com" to "adult",
        "xvideos.com" to "adult",
        "xnxx.com" to "adult",
        "xhamster.com" to "adult",
        "redtube.com" to "adult",
        "youporn.com" to "adult",
        "tube8.com" to "adult",
        "spankbang.com" to "adult",
        "porn.com" to "adult",
        "sex.com" to "adult",
        "xxx.com" to "adult",
        "brazzers.com" to "adult",
        "onlyfans.com" to "adult",
        "chaturbate.com" to "adult",
        "livejasmin.com" to "adult",
        "stripchat.com" to "adult",
        "cam4.com" to "adult",
        "myfreecams.com" to "adult",

        // Gambling
        "bet365.com" to "gambling",
        "betway.com" to "gambling",
        "draftkings.com" to "gambling",
        "fanduel.com" to "gambling",
        "pokerstars.com" to "gambling",
        "888casino.com" to "gambling",
        "williamhill.com" to "gambling",
        "unibet.com" to "gambling",
        "bwin.com" to "gambling",
        "betfair.com" to "gambling",
        "ladbrokes.com" to "gambling",
        "paddypower.com" to "gambling",
        "coral.co.uk" to "gambling",
        "skybet.com" to "gambling",
        "betfred.com" to "gambling",
        "bovada.lv" to "gambling",
        "betonline.ag" to "gambling",
        "mybookie.ag" to "gambling",
        "sportsbetting.ag" to "gambling",
        "intertops.eu" to "gambling",
        "casino.com" to "gambling",
        "jackpotcity.com" to "gambling",
        "casumo.com" to "gambling",
        "leovegas.com" to "gambling",
        "betmgm.com" to "gambling",
        "caesars.com" to "gambling",
        "borgata.com" to "gambling"
    )

    val allowedDomains: Set<String> = setOf(
        "google.com",
        "googleapis.com",
        "gstatic.com",
        "android.com",
        "googleusercontent.com"
    )

    /**
     * Local reputation results are separate from policy lists.
     * A reputation hit means the domain has been identified as risky by a
     * local intelligence source. No network call is made here.
     */
    val riskyReputation: Map<String, String> = mapOf(
        // Seed entries can later be populated from signed threat-intelligence updates.
    )
}
