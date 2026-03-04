sub init()
    m.theme = GetThemeTokens()

    m.mainCard = m.top.findNode("mainCard")
    m.awayLogo = m.top.findNode("awayLogo")
    m.awayName = m.top.findNode("awayName")
    m.awayRight = m.top.findNode("awayRight")
    m.homeLogo = m.top.findNode("homeLogo")
    m.homeName = m.top.findNode("homeName")
    m.homeRight = m.top.findNode("homeRight")
    m.infoLine1 = m.top.findNode("infoLine1")
    m.provider = m.top.findNode("provider")
    m.injuryAlertPill = m.top.findNode("injuryAlertPill")
    m.injuryAlertText = m.top.findNode("injuryAlertText")

    m.mainCard.cardWidth = 1160
    m.mainCard.cardHeight = 126
    m.mainCard.cornerRadius = m.theme.radius.card
    m.mainCard.backgroundColor = m.theme.colors.cardBg
    m.mainCard.focusBackgroundColor = m.theme.colors.cardBgFocus
    m.mainCard.showShadow = true

    m.awayName.font.size = m.theme.type.body + 4
    m.homeName.font.size = m.theme.type.body + 4
    m.awayRight.font.size = m.theme.type.body + 4
    m.homeRight.font.size = m.theme.type.body + 4
    m.infoLine1.font.size = m.theme.type.body
    m.provider.font.size = m.theme.type.caption
    m.injuryAlertText.font.size = m.theme.type.caption - 2

    m.awayName.color = m.theme.colors.textPrimary
    m.homeName.color = m.theme.colors.textPrimary
    m.awayRight.color = m.theme.colors.textPrimary
    m.homeRight.color = m.theme.colors.textPrimary
    m.infoLine1.color = m.theme.colors.textPrimary
    m.provider.color = m.theme.colors.accent
    m.injuryAlertPill.color = "0x8E2A2AFF"
    m.injuryAlertText.color = "0xF7E7E7FF"

    m.top.opacity = 0.9
end sub

function S(value as Dynamic) as String
    if value = invalid then return ""
    return value.ToStr()
end function

function SplitOnce(raw as String, marker as String) as Object
    p = Instr(1, raw, marker)
    if p <= 0 then
        return { left: raw, right: "" }
    end if
    left = Left(raw, p - 1)
    right = Mid(raw, p + Len(marker))
    return { left: left, right: right }
end function

sub SetPosterUri(node as Object, uri as String)
    if uri = invalid or uri = "" then
        node.uri = ""
        node.visible = false
    else
        node.uri = uri
        node.visible = true
    end if
end sub

sub onItemContentChanged()
    item = m.top.itemContent
    if item = invalid then return

    awayName = ""
    homeName = ""
    awayRight = ""
    homeRight = ""
    infoLine1 = S(item.shortDescriptionLine1)
    provider = ""
    injuries = ""

    parsedNames = SplitOnce(S(item.title), " ##HOME## ")
    if parsedNames.right <> "" then
        awayName = parsedNames.left
        homeName = parsedNames.right
    else
        awayName = S(item.title)
        homeName = ""
    end if

    desc = S(item.description)
    parsedScore = SplitOnce(desc, " ##HS## ")
    if awayRight = "" then awayRight = parsedScore.left
    if homeRight = "" then homeRight = parsedScore.right

    if infoLine1 = "" then infoLine1 = S(item.shortDescriptionLine1)

    line2 = S(item.shortDescriptionLine2)
    parsedInj = SplitOnce(line2, " ##INJ## ")
    provider = parsedInj.left.Trim()
    injuries = parsedInj.right.Trim()

    logos = SplitOnce(S(item.HDPosterUrl), " ##HOMELOGO## ")
    SetPosterUri(m.awayLogo, logos.left.Trim())
    SetPosterUri(m.homeLogo, logos.right.Trim())

    m.awayName.text = awayName
    m.homeName.text = homeName
    m.awayRight.text = awayRight
    m.homeRight.text = homeRight
    m.infoLine1.text = infoLine1
    m.provider.text = provider

    hasInj = (injuries <> "")
    m.injuryAlertPill.visible = hasInj
    m.injuryAlertText.visible = hasInj
end sub

sub onItemFocusChanged()
    focused = m.top.itemHasFocus
    if focused = invalid then focused = false

    m.mainCard.isFocused = focused
    if focused then
        m.top.opacity = 1.0
    else
        m.top.opacity = 0.9
    end if
end sub
