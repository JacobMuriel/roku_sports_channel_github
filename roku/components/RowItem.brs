sub init()
    m.theme = GetThemeTokens()

    m.card = m.top.findNode("card")
    m.myTeamBadge = m.top.findNode("myTeamBadge")
    m.myTeamText = m.top.findNode("myTeamText")
    m.matchup = m.top.findNode("matchup")
    m.meta = m.top.findNode("meta")
    m.scoreline = m.top.findNode("scoreline")
    m.network = m.top.findNode("network")
    m.starInjuries = m.top.findNode("starInjuries")

    m.card.cardWidth = 1160
    m.card.cardHeight = 152
    m.card.cornerRadius = m.theme.radius.card
    m.card.backgroundColor = m.theme.colors.cardBg
    m.card.focusBackgroundColor = m.theme.colors.cardBgFocus
    m.card.showShadow = true

    m.myTeamBadge.color = m.theme.colors.badgeBg
    m.myTeamBadge.cornerRadius = m.theme.radius.badge

    m.myTeamText.font.size = m.theme.type.caption
    m.matchup.font.size = m.theme.type.body + 6
    m.meta.font.size = m.theme.type.caption
    m.scoreline.font.size = m.theme.type.body
    m.network.font.size = m.theme.type.caption
    m.starInjuries.font.size = m.theme.type.caption - 2

    m.myTeamText.color = m.theme.colors.badgeText
    m.matchup.color = m.theme.colors.textPrimary
    m.meta.color = m.theme.colors.textSecondary
    m.scoreline.color = m.theme.colors.textPrimary
    m.network.color = m.theme.colors.accent
    m.starInjuries.color = m.theme.colors.textMuted

    m.scorelineYDefault = 92
    m.networkYDefault = 124
    m.scorelineYWithInjuries = 82
    m.networkYWithInjuries = 104
    m.starInjuriesY = 128

    m.top.opacity = 0.92
end sub

function ToSafeString(value as Dynamic) as String
    if value = invalid then return ""
    return value.ToStr()
end function

sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    matchup = ToSafeString(item.matchup)
    if matchup = "" then matchup = ToSafeString(item.title)

    meta = ToSafeString(item.meta)
    if meta = "" then meta = ToSafeString(item.subtitle)

    scoreline = ToSafeString(item.scoreline)
    if scoreline = "" then scoreline = ToSafeString(item.score)
    if scoreline = "" then scoreline = ToSafeString(item.description)
    if scoreline = "" then scoreline = ToSafeString(item.shortDescriptionLine1)

    rawLine2 = ToSafeString(item.shortDescriptionLine2)
    network = ToSafeString(item.network)
    if network = "" then network = rawLine2
    if network = "" then network = "N/A"
    starInjuriesText = ToSafeString(item.starInjuries)
    if starInjuriesText = "" then starInjuriesText = ToSafeString(item.longDescription)

    marker = " ##STAR## "
    markerPos = Instr(1, rawLine2, marker)
    if markerPos > 0 then
        network = Left(rawLine2, markerPos - 1)
        starInjuriesText = Mid(rawLine2, markerPos + Len(marker))
    end if

    m.matchup.text = matchup
    m.meta.text = meta
    m.scoreline.text = scoreline
    m.network.text = network
    m.starInjuries.text = starInjuriesText
    hasInjuries = (starInjuriesText <> "")
    m.starInjuries.visible = hasInjuries

    if hasInjuries then
        m.scoreline.translation = [124, m.scorelineYWithInjuries]
        m.network.translation = [124, m.networkYWithInjuries]
        m.starInjuries.translation = [124, m.starInjuriesY]
    else
        m.scoreline.translation = [124, m.scorelineYDefault]
        m.network.translation = [124, m.networkYDefault]
        m.starInjuries.translation = [124, m.starInjuriesY]
    end if

    isMyTeam = false
    if item.isMyTeam <> invalid then isMyTeam = item.isMyTeam
    m.myTeamBadge.visible = isMyTeam
    m.myTeamText.visible = isMyTeam
end sub

sub onItemFocusChanged()
    focused = m.top.itemHasFocus
    if focused = invalid then focused = false

    m.card.isFocused = focused
    if focused then
        m.top.opacity = 1.0
        m.meta.color = m.theme.colors.textPrimary
    else
        m.top.opacity = 0.92
        m.meta.color = m.theme.colors.textSecondary
    end if
end sub
