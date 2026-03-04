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
    m.injuryBar = m.top.findNode("injuryBar")
    m.injurySummary = m.top.findNode("injurySummary")

    m.mainCard.cardWidth = 548
    m.mainCard.cardHeight = 168
    m.mainCard.cornerRadius = m.theme.radius.card
    m.mainCard.backgroundColor = m.theme.colors.cardBg
    m.mainCard.focusBackgroundColor = m.theme.colors.cardBgFocus
    m.mainCard.showShadow = true

    m.awayName.font.size = m.theme.type.body
    m.homeName.font.size = m.theme.type.body
    m.awayRight.font.size = m.theme.type.body
    m.homeRight.font.size = m.theme.type.body
    m.infoLine1.font.size = m.theme.type.caption + 2
    m.provider.font.size = m.theme.type.caption
    m.injurySummary.font.size = m.theme.type.caption - 2

    m.awayName.color = m.theme.colors.textPrimary
    m.homeName.color = m.theme.colors.textPrimary
    m.awayRight.color = m.theme.colors.textPrimary
    m.homeRight.color = m.theme.colors.textPrimary
    m.infoLine1.color = m.theme.colors.textPrimary
    m.provider.color = m.theme.colors.accent
    m.injuryBar.color = "0x7F2525CC"
    m.injurySummary.color = "0xF8EDEEFF"

    m.top.opacity = 0.9
end sub

sub ClearCard()
    m.mainCard.visible = false
    m.top.opacity = 0
    m.awayName.text = ""
    m.homeName.text = ""
    m.awayRight.text = ""
    m.homeRight.text = ""
    m.infoLine1.text = ""
    m.provider.text = ""
    m.awayLogo.uri = ""
    m.homeLogo.uri = ""
    m.awayLogo.visible = false
    m.homeLogo.visible = false
    m.injuryBar.visible = false
    m.injurySummary.visible = false
    m.injurySummary.text = ""
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

function Shorten(text as String, maxLen as Integer) as String
    if Len(text) <= maxLen then return text
    if maxLen < 4 then return text
    return Left(text, maxLen - 3) + "..."
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
    if item = invalid then
        ClearCard()
        return
    end if

    parsedNames = SplitOnce(S(item.title), " ##HOME## ")
    desc = SplitOnce(S(item.description), " ##HS## ")
    line2 = SplitOnce(S(item.shortDescriptionLine2), " ##INJ## ")
    logos = SplitOnce(S(item.HDPosterUrl), " ##HOMELOGO## ")

    awayName = parsedNames.left
    homeName = parsedNames.right
    awayRight = desc.left
    homeRight = desc.right
    infoLine1 = S(item.shortDescriptionLine1)
    provider = line2.left.Trim()
    injuries = line2.right.Trim()

    ' Empty cells can be presented by recycled renderers in MarkupGrid.
    if awayName = "" and homeName = "" and infoLine1 = "" and provider = "" then
        ClearCard()
        return
    end if

    m.mainCard.visible = true
    m.top.opacity = 0.9

    m.awayName.text = Shorten(awayName, 24)
    m.homeName.text = Shorten(homeName, 24)
    m.awayRight.text = awayRight
    m.homeRight.text = homeRight
    m.infoLine1.text = infoLine1
    m.provider.text = provider

    SetPosterUri(m.awayLogo, logos.left.Trim())
    SetPosterUri(m.homeLogo, logos.right.Trim())

    hasInj = (injuries <> "")
    if hasInj then
        m.injurySummary.text = Shorten(injuries, 100)
    else
        m.injurySummary.text = ""
    end if
    m.injuryBar.visible = hasInj
    m.injurySummary.visible = hasInj
end sub

sub onItemFocusChanged()
    if m.mainCard.visible = false then
        m.top.opacity = 0
        return
    end if

    focused = m.top.itemHasFocus
    if focused = invalid then focused = false

    m.mainCard.isFocused = focused
    if focused then
        m.top.opacity = 1.0
    else
        m.top.opacity = 0.9
    end if
end sub
