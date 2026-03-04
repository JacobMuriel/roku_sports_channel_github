sub init()
    m.theme = GetThemeTokens()

    m.header = m.top.findNode("header")
    m.status = m.top.findNode("status")
    m.gamesGrid = m.top.findNode("gamesGrid")
    m.bgTintTop = m.top.findNode("bgTintTop")
    m.tabBar = m.top.findNode("tabBar")
    m.tabNBA = m.top.findNode("tabNBA")
    m.tabNCAA = m.top.findNode("tabNCAA")
    m.tabPill = m.top.findNode("tabPill")
    m.tabNBAUnderline = m.top.findNode("tabNBAUnderline")
    m.tabNCAAUnderline = m.top.findNode("tabNCAAUnderline")
    m.injuryOverlay = m.top.findNode("injuryOverlay")
    m.injuryOverlayPanel = m.top.findNode("injuryOverlayPanel")
    m.injuryOverlayOuterBg = m.top.findNode("injuryOverlayOuterBg")
    m.injuryOverlayInnerBg = m.top.findNode("injuryOverlayInnerBg")
    m.injuryOverlayTitle = m.top.findNode("injuryOverlayTitle")
    m.injuryOverlayBody = m.top.findNode("injuryOverlayBody")
    m.injuryOverlayHint = m.top.findNode("injuryOverlayHint")
    m.pollTimer = m.top.findNode("pollTimer")

    m.baseUrl = GetBackendBaseUrl()
    m.dashboardTz = GetDashboardTimezone()

    m.nbaItems = []
    m.ncaaItems = []
    m.activeLeague = "nba"
    m.gridColumns = 2
    m.renderedRows = []
    m.currentFocusedIndex = 0
    m.lastFocusedGridIndex = 0
    m.lastNavKey = ""
    m.prevFocusedIndex = 0

    m.fetchInFlight = false
    m.errorCount = 0
    m.lastUpdated = "Never"

    m.bgTintTop.color = m.theme.colors.bgTopTint

    outer = m.theme.spacing.outer
    m.header.translation = [outer, 20]
    m.status.translation = [outer + 260, 30]
    m.tabBar.translation = [outer, 92]
    m.gamesGrid.translation = [outer, 156]
    m.gamesGrid.itemSpacing = [m.theme.spacing.s16, m.theme.spacing.s16]

    m.header.font.size = m.theme.type.headline
    m.header.color = m.theme.colors.textPrimary

    m.status.font.size = m.theme.type.caption
    m.status.color = m.theme.colors.textSecondary

    m.tabPill.color = m.theme.colors.cardBg

    m.tabNBA.font.size = m.theme.type.body
    m.tabNCAA.font.size = m.theme.type.body
    m.injuryOverlayTitle.font.size = m.theme.type.body + 2
    m.injuryOverlayBody.font.size = m.theme.type.caption
    m.injuryOverlayHint.font.size = m.theme.type.caption - 2
    m.injuryOverlayTitle.color = m.theme.colors.textPrimary
    m.injuryOverlayBody.color = m.theme.colors.textSecondary
    m.injuryOverlayHint.color = m.theme.colors.textMuted

    m.gamesGrid.observeField("itemFocused", "onItemFocusedChanged")
    m.gamesGrid.observeField("itemSelected", "onItemSelected")
    m.pollTimer.observeField("fire", "onPollTimerFire")

    updateTabUI()
    updateStatus("Loading...")
    m.gamesGrid.setFocus(true)
    schedulePoll(1)
end sub

function SafeToStr(value as Dynamic) as String
    if value = invalid then return ""
    return value.ToStr()
end function

function NormalizeDisplayText(value as Dynamic) as String
    s = SafeToStr(value)
    enDash = Chr(226) + Chr(128) + Chr(147)
    emDash = Chr(226) + Chr(128) + Chr(148)
    s = s.Replace(enDash, "-")
    s = s.Replace(emDash, "-")
    return s
end function

function GetAssoc(value as Dynamic) as Object
    if type(value) = "roAssociativeArray" then return value
    return invalid
end function

function SplitOnce(raw as String, marker as String) as Object
    p = Instr(1, raw, marker)
    if p <= 0 then
        return { left: raw, right: "" }
    end if
    return {
        left: Left(raw, p - 1),
        right: Mid(raw, p + Len(marker))
    }
end function

function TwoDigit(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

function LocalClockString() as String
    dt = CreateObject("roDateTime")
    if dt = invalid then return "Just now"

    dt.ToLocalTime()

    h = dt.GetHours()
    minuteVal = dt.GetMinutes()
    ampm = "AM"
    if h >= 12 then ampm = "PM"
    h12 = h Mod 12
    if h12 = 0 then h12 = 12

    return h12.ToStr() + ":" + TwoDigit(minuteVal) + " " + ampm
end function

function IsArray(value as Dynamic) as Boolean
    return type(value) = "roArray"
end function

function JoinNetworks(networks as Object, league as String) as String
    if IsArray(networks) and networks.Count() > 0 then
        text = ""
        for each n in networks
            v = NormalizeDisplayText(n)
            if v <> "" then
                if text = "" then
                    text = v
                else
                    text = text + " / " + v
                end if
            end if
        end for
        if text <> "" then return text
    end if

    if league = "nba" then return "League Pass"
    return "N/A"
end function

function FormatStartTime(item as Object) as String
    if item = invalid then return "TBD"

    display = GetAssoc(item.Lookup("display"))
    if display <> invalid then
        subtitle = NormalizeDisplayText(display.Lookup("subtitle"))
        if subtitle <> "" then return subtitle
    end if

    return "TBD"
end function

function ParseRank(value as Dynamic) as Integer
    if value = invalid then return -1
    t = type(value)
    if t = "roInt" or t = "Integer" then return value
    s = NormalizeDisplayText(value)
    if s = "" then return -1
    return Val(s)
end function

function TeamWithRank(name as String, rank as Integer, league as String) as String
    if league = "ncaam" and rank >= 1 and rank <= 25 then
        return name + " (" + rank.ToStr() + ")"
    end if
    return name
end function

function JoinStrings(parts as Object, delimiter as String) as String
    if parts = invalid then return ""
    if type(parts) <> "roArray" then return ""
    if parts.Count() = 0 then return ""

    out = ""
    for each p in parts
        s = NormalizeDisplayText(p)
        if s = "" then
            continue for
        end if
        if out = "" then
            out = s
        else
            out = out + delimiter + s
        end if
    end for
    return out
end function

function getStarInjuries(teamAlias as String, injuryData as Object) as Object
    injuries = []
    if teamAlias = invalid then return injuries
    if injuryData = invalid then return injuries
    if type(injuryData) <> "roAssociativeArray" then return injuries

    aliasKey = UCase(NormalizeDisplayText(teamAlias))
    if aliasKey = "" then return injuries

    raw = injuryData.Lookup(aliasKey)
    if raw = invalid then return injuries
    if type(raw) <> "roArray" then return injuries

    for each entry in raw
        if type(entry) <> "roAssociativeArray" then
            continue for
        end if
        name = NormalizeDisplayText(entry.Lookup("name"))
        status = NormalizeDisplayText(entry.Lookup("status"))
        reason = NormalizeDisplayText(entry.Lookup("reason"))
        if name = "" or status = "" then
            continue for
        end if
        injuries.Push({
            name: name,
            status: status,
            reason: reason
        })
    end for

    return injuries
end function

function FormatStarInjuryStrip(awayAlias as String, homeAlias as String, injuryData as Object) as String
    awayList = getStarInjuries(awayAlias, injuryData)
    homeList = getStarInjuries(homeAlias, injuryData)

    sections = []

    if type(awayList) = "roArray" and awayList.Count() > 0 then
        awayParts = []
        for each i in awayList
            bit = i.name + " (" + i.status
            if i.reason <> "" then bit = bit + " - " + i.reason
            bit = bit + ")"
            awayParts.Push(bit)
        end for
        sections.Push(awayAlias + ": " + JoinStrings(awayParts, ", "))
    end if

    if type(homeList) = "roArray" and homeList.Count() > 0 then
        homeParts = []
        for each i in homeList
            bit = i.name + " (" + i.status
            if i.reason <> "" then bit = bit + " - " + i.reason
            bit = bit + ")"
            homeParts.Push(bit)
        end for
        sections.Push(homeAlias + ": " + JoinStrings(homeParts, ", "))
    end if

    if sections.Count() = 0 then return ""
    return "Stars Out: " + JoinStrings(sections, " | ")
end function

function BuildRow(item as Object) as Object
    awayTeam = NormalizeDisplayText(item.Lookup("awayTeam"))
    homeTeam = NormalizeDisplayText(item.Lookup("homeTeam"))
    status = LCase(NormalizeDisplayText(item.Lookup("status")))
    periodClock = NormalizeDisplayText(item.Lookup("periodClock"))
    league = NormalizeDisplayText(item.Lookup("league"))

    awayScore = NormalizeDisplayText(item.Lookup("awayScore"))
    homeScore = NormalizeDisplayText(item.Lookup("homeScore"))
    awayRank = ParseRank(item.Lookup("awayRank"))
    homeRank = ParseRank(item.Lookup("homeRank"))
    awayAlias = NormalizeDisplayText(item.Lookup("awayAlias"))
    homeAlias = NormalizeDisplayText(item.Lookup("homeAlias"))

    awayTeam = TeamWithRank(awayTeam, awayRank, league)
    homeTeam = TeamWithRank(homeTeam, homeRank, league)

    if awayTeam = "" or homeTeam = "" then
        display = GetAssoc(item.Lookup("display"))
        if display <> invalid then
            title = NormalizeDisplayText(display.Lookup("title"))
            matchup = title
        else
            matchup = "Game"
        end if
    else
        matchup = awayTeam + " @ " + homeTeam
    end if

    startText = FormatStartTime(item)
    if status = "pre" and startText <> "" and startText <> "TBD" then
        if Instr(1, LCase(startText), "ct") = 0 then
            startText = startText + " CT"
        end if
    end if

    ' Spot-check for started/live state when status is stale.
    lowerClock = LCase(periodClock)
    hasLiveMarker = (Instr(1, lowerClock, "q") > 0) or (Instr(1, lowerClock, "half") > 0) or (Instr(1, lowerClock, "ot") > 0)
    hasFinalMarker = (Instr(1, lowerClock, "final") > 0)
    hasScore = (awayScore <> "" and homeScore <> "")
    if status = "pre" and hasLiveMarker and hasScore then status = "live"
    if status = "pre" and hasFinalMarker then status = "final"

    meta = startText + " - Scheduled"
    scoreline = ""
    if status = "live" then
        meta = startText + " - Live"
        if awayScore <> "" and homeScore <> "" then
            scoreline = awayScore + "-" + homeScore
        end if
        if periodClock <> "" then
            if scoreline <> "" then
                scoreline = scoreline + " " + periodClock
            else
                scoreline = periodClock
            end if
        end if
        if scoreline = "" then scoreline = "Live"
    else if status = "final" then
        meta = startText + " - Final"
        if awayScore <> "" and homeScore <> "" then
            scoreline = awayScore + "-" + homeScore + " FINAL"
        else
            scoreline = "FINAL"
        end if
    else
        scoreline = startText
    end if

    networks = item.Lookup("networks")
    networkText = JoinNetworks(networks, league)
    injuryData = item.Lookup("injuryData")
    starInjuriesText = ""
    if LCase(league) = "nba" then
        starInjuriesText = NormalizeDisplayText(item.Lookup("injuryStrip"))
        if starInjuriesText = "" then
            starInjuriesText = FormatStarInjuryStrip(awayAlias, homeAlias, injuryData)
        end if
    end if

    isMyTeam = false
    if item.Lookup("isMyTeam") <> invalid then isMyTeam = item.isMyTeam

    row = {
        matchup: matchup,
        meta: meta,
        scoreline: scoreline,
        network: networkText,
        starInjuries: starInjuriesText,
        isMyTeam: isMyTeam,
    }
    return row
end function

sub updateTabUI()
    if m.activeLeague = "nba" then
        m.header.text = "NBA"
        m.tabNBA.color = m.theme.colors.tabActive
        m.tabNCAA.color = m.theme.colors.tabInactive
        m.tabNBAUnderline.color = m.theme.colors.accent
        m.tabNCAAUnderline.color = m.theme.colors.accent
        m.tabNBAUnderline.visible = true
        m.tabNCAAUnderline.visible = false
    else
        m.header.text = "NCAA"
        m.tabNBA.color = m.theme.colors.tabInactive
        m.tabNCAA.color = m.theme.colors.tabActive
        m.tabNBAUnderline.color = m.theme.colors.accent
        m.tabNCAAUnderline.color = m.theme.colors.accent
        m.tabNBAUnderline.visible = false
        m.tabNCAAUnderline.visible = true
    end if
end sub

sub updateStatus(extra as String)
    text = "Last updated: " + NormalizeDisplayText(m.lastUpdated)
    if extra <> "" then text = text + "   " + NormalizeDisplayText(extra)
    m.status.text = text
end sub

sub schedulePoll(seconds as Integer)
    if seconds < 1 then seconds = 1
    m.pollTimer.control = "stop"
    m.pollTimer.duration = seconds
    m.pollTimer.control = "start"
end sub

sub onPollTimerFire()
    startFetch()
end sub

sub startFetch()
    if m.fetchInFlight then return

    m.fetchInFlight = true
    task = CreateObject("roSGNode", "DashboardTask")
    m.activeTask = task
    task.baseUrl = m.baseUrl
    task.tz = m.dashboardTz
    task.observeField("response", "onFetchResponse")
    task.observeField("error", "onFetchError")
    task.control = "run"
end sub

sub completeFetchWithError(errText as String)
    m.fetchInFlight = false
    m.errorCount = m.errorCount + 1

    retrySeconds = 30
    if m.errorCount > 1 then retrySeconds = 60

    updateStatus(NormalizeDisplayText(errText) + " Retrying in " + retrySeconds.ToStr() + "s...")
    schedulePoll(retrySeconds)
end sub

sub onFetchResponse()
    if m.activeTask = invalid then
        completeFetchWithError("Task unavailable")
        return
    end if

    data = m.activeTask.response
    if data = invalid or type(data) <> "roAssociativeArray" then
        completeFetchWithError("Invalid dashboard data")
        return
    end if

    items = data.Lookup("items")
    if items = invalid or type(items) <> "roArray" then
        completeFetchWithError("Missing items")
        return
    end if

    m.fetchInFlight = false
    m.errorCount = 0
    m.lastUpdated = LocalClockString()

    nba = []
    ncaa = []

    for each item in items
        aa = GetAssoc(item)
        if aa = invalid then
            continue for
        end if

        league = NormalizeDisplayText(aa.Lookup("league"))
        if league = "nba" then
            nba.Push(aa)
        else if league = "ncaam" then
            ncaa.Push(aa)
        end if
    end for

    m.nbaItems = nba
    m.ncaaItems = ncaa

    renderActiveLeague()

    updateStatus("")
    schedulePoll(30)
end sub

sub onFetchError()
    if m.activeTask = invalid then
        completeFetchWithError("Network error")
        return
    end if

    err = NormalizeDisplayText(m.activeTask.error)
    if err = "" then err = "Network error"

    completeFetchWithError(err)
end sub

sub renderActiveLeague()
    sourceItems = []
    if m.activeLeague = "nba" then
        sourceItems = m.nbaItems
        m.gamesGrid.itemSize = [572, 188]
        m.gamesGrid.itemSpacing = [m.theme.spacing.s16, m.theme.spacing.s16]
    else
        sourceItems = m.ncaaItems
        m.gamesGrid.itemSize = [572, 172]
        m.gamesGrid.itemSpacing = [m.theme.spacing.s16, m.theme.spacing.s16]
    end if

    content = CreateObject("roSGNode", "ContentNode")
    m.renderedRows = []
    if sourceItems.Count() = 0 then
        emptyNode = CreateObject("roSGNode", "ContentNode")
        emptyNode.title = "No games loaded ##HOME## Check backend connectivity"
        emptyNode.description = " ##HS## "
        emptyNode.shortDescriptionLine1 = ""
        emptyNode.shortDescriptionLine2 = ""
        emptyNode.HDPosterUrl = ""
        emptyNode.SDPosterUrl = ""
        content.AppendChild(emptyNode)
    end if

    for each item in sourceItems
        row = AdaptGameRow(item)
        m.renderedRows.Push(row)
        node = CreateObject("roSGNode", "ContentNode")
        node.title = row.awayTeamName + " ##HOME## " + row.homeTeamName
        node.description = row.awayRightText + " ##HS## " + row.homeRightText
        node.shortDescriptionLine1 = row.infoLine1
        if row.providerText <> "" then
            node.shortDescriptionLine2 = row.providerText
        else
            node.shortDescriptionLine2 = ""
        end if
        if row.injuriesText <> "" then
            node.shortDescriptionLine2 = node.shortDescriptionLine2 + " ##INJ## " + row.injuriesText
        end if
        node.HDPosterUrl = row.awayTeamLogoUri + " ##HOMELOGO## " + row.homeTeamLogoUri
        node.SDPosterUrl = node.HDPosterUrl
        content.AppendChild(node)
    end for

    m.gamesGrid.content = content
    m.gamesGrid.jumpToItem = 0
    m.currentFocusedIndex = 0
    m.lastFocusedGridIndex = 0
    m.prevFocusedIndex = 0
    m.gamesGrid.setFocus(true)
    updateTabUI()
end sub

function SafeIndex(value as Dynamic, fallback as Integer) as Integer
    if value = invalid then return fallback

    t = type(value)
    if t = "roInt" or t = "Integer" then return value
    if t = "Float" or t = "roFloat" then return Int(value)
    if t = "String" then
        n = Val(value)
        if n >= 0 then return n
        return fallback
    end if
    if t = "roArray" and value.Count() > 0 then
        return SafeIndex(value[0], fallback)
    end if
    return fallback
end function

function GridLinearIndex(value as Dynamic, fallback as Integer) as Integer
    if value = invalid then return fallback

    t = type(value)
    if t = "roArray" and value.Count() >= 2 then
        row = SafeIndex(value[0], -1)
        col = SafeIndex(value[1], -1)
        if row >= 0 and col >= 0 then
            return (row * m.gridColumns) + col
        end if
        return fallback
    end if

    return SafeIndex(value, fallback)
end function

function GridItemCount() as Integer
    if m.renderedRows = invalid then return 0
    return m.renderedRows.Count()
end function

function GridColFromIndex(idx as Integer) as Integer
    if idx < 0 then return 0
    return idx Mod m.gridColumns
end function

function GridLastRowStartIndex() as Integer
    total = GridItemCount()
    if total <= 0 then return 0
    lastIdx = total - 1
    return Int(lastIdx / m.gridColumns) * m.gridColumns
end function

sub SetGridFocusIndex(idx as Integer)
    total = GridItemCount()
    if total <= 0 then return
    if idx < 0 then idx = 0
    if idx >= total then idx = total - 1

    m.prevFocusedIndex = m.currentFocusedIndex
    m.currentFocusedIndex = idx
    m.lastFocusedGridIndex = idx
    m.gamesGrid.jumpToItem = idx
    m.gamesGrid.setFocus(true)
end sub

sub RestoreGridFocus()
    total = GridItemCount()
    if total <= 0 then
        m.gamesGrid.setFocus(true)
        return
    end if

    idx = m.lastFocusedGridIndex
    if idx < 0 then idx = 0
    if idx >= total then idx = total - 1

    m.currentFocusedIndex = idx
    m.prevFocusedIndex = idx
    m.gamesGrid.jumpToItem = idx
    m.gamesGrid.setFocus(true)
end sub

function MaxInt(a as Integer, b as Integer) as Integer
    if a > b then return a
    return b
end function

function MinInt(a as Integer, b as Integer) as Integer
    if a < b then return a
    return b
end function

function EstimateInjuryLines(text as String) as Integer
    if text = "" then return 2

    normalized = text.Replace(" • ", Chr(10))
    segments = normalized.Tokenize(Chr(10))
    if segments = invalid or segments.Count() = 0 then return 2

    lines = 0
    for each seg in segments
        s = NormalizeDisplayText(seg)
        if s = "" then
            lines = lines + 1
        else
            ' Rough wrap estimate for modal body width/font on 1080p.
            lines = lines + MaxInt(1, Int((Len(s) + 64) / 65))
        end if
    end for

    return MinInt(MaxInt(lines, 2), 10)
end function

sub LayoutInjuryOverlay(injuries as String)
    panelWidth = 860
    baseHeight = 164
    lineHeight = 26
    lines = EstimateInjuryLines(injuries)
    bodyHeight = lines * lineHeight
    panelHeight = baseHeight + bodyHeight

    panelHeight = MinInt(MaxInt(panelHeight, 220), 460)
    bodyHeight = panelHeight - baseHeight

    px = Int((1280 - panelWidth) / 2)
    py = Int((720 - panelHeight) / 2)

    m.injuryOverlayPanel.translation = [px, py]
    m.injuryOverlayOuterBg.width = panelWidth
    m.injuryOverlayOuterBg.height = panelHeight

    m.injuryOverlayInnerBg.translation = [16, 16]
    m.injuryOverlayInnerBg.width = panelWidth - 32
    m.injuryOverlayInnerBg.height = panelHeight - 32

    m.injuryOverlayTitle.translation = [36, 32]
    m.injuryOverlayTitle.width = panelWidth - 72

    m.injuryOverlayBody.translation = [36, 80]
    m.injuryOverlayBody.width = panelWidth - 72
    m.injuryOverlayBody.height = bodyHeight
    m.injuryOverlayBody.numLines = lines

    m.injuryOverlayHint.translation = [36, panelHeight - 44]
    m.injuryOverlayHint.width = panelWidth - 72
end sub

sub openInjuryOverlayForIndex(idx as Integer)
    if m.injuryOverlay.visible then return
    if idx < 0 then return
    if idx >= m.renderedRows.Count() then return

    row = m.renderedRows[idx]
    if type(row) <> "roAssociativeArray" then return

    matchup = NormalizeDisplayText(row.awayTeamName) + " @ " + NormalizeDisplayText(row.homeTeamName)
    injuries = NormalizeDisplayText(row.injuriesDetails)
    if injuries = "" then return

    displayText = injuries.Replace(" • ", Chr(10))
    LayoutInjuryOverlay(displayText)
    m.injuryOverlayTitle.text = matchup
    m.injuryOverlayBody.text = displayText
    m.injuryOverlay.visible = true
    m.injuryOverlay.opacity = 1.0
end sub

sub onItemFocusedChanged()
    idx = GridLinearIndex(m.gamesGrid.itemFocused, m.currentFocusedIndex)
    if idx < 0 then return

    oldIdx = m.currentFocusedIndex
    if oldIdx < 0 then oldIdx = idx

    ' Guard against native wrap behavior by snapping back when it loops.
    if m.lastNavKey = "down" and idx < oldIdx then
        m.gamesGrid.jumpToItem = oldIdx
        m.currentFocusedIndex = oldIdx
        m.prevFocusedIndex = oldIdx
        return
    end if
    if m.lastNavKey = "up" and idx > oldIdx then
        m.gamesGrid.jumpToItem = oldIdx
        m.currentFocusedIndex = oldIdx
        m.prevFocusedIndex = oldIdx
        return
    end if

    m.prevFocusedIndex = oldIdx
    m.currentFocusedIndex = idx
    m.lastFocusedGridIndex = idx
end sub

sub onItemSelected()
    idx = GridLinearIndex(m.gamesGrid.itemSelected, m.currentFocusedIndex)
    if idx < 0 then idx = m.currentFocusedIndex
    m.currentFocusedIndex = idx
    m.lastFocusedGridIndex = idx
end sub

sub closeInjuryOverlay()
    m.injuryOverlay.opacity = 0.0
    m.injuryOverlay.visible = false
    m.gamesGrid.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false
    m.lastNavKey = LCase(key)

    if m.injuryOverlay.visible then
        if key = "back" or key = "OK" then
            closeInjuryOverlay()
            return true
        end if
        return true
    end if

    if key = "OK" or key = "select" then
        idx = GridLinearIndex(m.gamesGrid.itemFocused, m.currentFocusedIndex)
        if idx < 0 then idx = GridLinearIndex(m.gamesGrid.itemSelected, m.currentFocusedIndex)
        if idx < 0 then idx = 0
        openInjuryOverlayForIndex(idx)
        if m.injuryOverlay.visible = false then
            ' Fallback: scan first visible rows for any available injury details.
            for i = 0 to m.renderedRows.Count() - 1
                row = m.renderedRows[i]
                if type(row) = "roAssociativeArray" then
                    if NormalizeDisplayText(row.injuriesDetails) <> "" then
                        openInjuryOverlayForIndex(i)
                        exit for
                    end if
                end if
            end for
        end if
        return true
    end if

    if key = "right" then
        idx = GridLinearIndex(m.gamesGrid.itemFocused, m.currentFocusedIndex)
        if idx < 0 then idx = m.currentFocusedIndex
        col = GridColFromIndex(idx)
        if col < (m.gridColumns - 1) and (idx + 1) < GridItemCount() then
            SetGridFocusIndex(idx + 1)
            return true
        end if
        if col = (m.gridColumns - 1) or (idx + 1) >= GridItemCount() then
            m.lastFocusedGridIndex = idx
            if m.activeLeague <> "ncaam" then
                m.activeLeague = "ncaam"
                updateTabUI()
                renderActiveLeague()
            end if
            return true
        end if
    else if key = "left" then
        idx = GridLinearIndex(m.gamesGrid.itemFocused, m.currentFocusedIndex)
        if idx < 0 then idx = m.currentFocusedIndex
        col = GridColFromIndex(idx)
        if col > 0 then
            SetGridFocusIndex(idx - 1)
            return true
        end if
        if col = 0 then
            m.lastFocusedGridIndex = idx
            if m.activeLeague <> "nba" then
                m.activeLeague = "nba"
                updateTabUI()
                renderActiveLeague()
            end if
            return true
        end if
    else if key = "up" then
        idx = GridLinearIndex(m.gamesGrid.itemFocused, m.currentFocusedIndex)
        if idx < 0 then idx = m.currentFocusedIndex
        target = idx - m.gridColumns
        if target < 0 then return true
        SetGridFocusIndex(target)
        return true
    else if key = "down" then
        idx = GridLinearIndex(m.gamesGrid.itemFocused, m.currentFocusedIndex)
        if idx < 0 then idx = m.currentFocusedIndex
        target = idx + m.gridColumns
        if target >= GridItemCount() then return true
        SetGridFocusIndex(target)
        return true
    else if key = "rewind" then
        if m.activeLeague <> "nba" then
            m.activeLeague = "nba"
            updateTabUI()
            renderActiveLeague()
            return true
        end if
    else if key = "fastforward" then
        if m.activeLeague <> "ncaam" then
            m.activeLeague = "ncaam"
            updateTabUI()
            renderActiveLeague()
            return true
        end if
    end if

    return false
end function
