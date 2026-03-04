function GetThemeTokens() as Object
    return {
        colors: {
            bgBase: "0x0C1117FF",
            bgTopTint: "0x1A2330AA",
            textPrimary: "0xEEF2F6FF",
            textSecondary: "0xA8B4C2FF",
            textMuted: "0x7E8B99FF",
            accent: "0x8BC0FFFF",
            accentStrong: "0xB7D9FFFF",
            cardBg: "0x1A232EFF",
            cardBgFocus: "0x253341FF",
            cardShadow: "0x00000088",
            tabActive: "0xEEF2F6FF",
            tabInactive: "0x7F8A97FF",
            badgeBg: "0xFFE08AFF",
            badgeText: "0x232A33FF"
        },
        type: {
            headline: 48,
            body: 24,
            caption: 20
        },
        spacing: {
            s8: 8,
            s16: 16,
            s24: 24,
            outer: 60
        },
        radius: {
            card: 20,
            badge: 12
        },
        motion: {
            focusScale: 1.04,
            blurScale: 1.0,
            focusDuration: 0.16,
            blurDuration: 0.12
        }
    }
end function
