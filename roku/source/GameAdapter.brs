function GASafeString(value as Dynamic) as String
    if value = invalid then return ""
    return value.ToStr()
end function

function GAUpper(value as Dynamic) as String
    return UCase(GASafeString(value))
end function

function GAIsArray(value as Dynamic) as Boolean
    return type(value) = "roArray"
end function

function GANormalizeProvider(raw as String) as String
    s = UCase(raw.Trim())
    if s = "" then return ""

    if Instr(1, s, "ESPN") > 0 then return "ESPN"
    if Instr(1, s, "ABC") > 0 then return "ABC"
    if Instr(1, s, "PEACOCK") > 0 then return "NBC/Peacock"
    ' Do not map regional "NBC Sports <region>" RSNs to NBC/Peacock.
    if s = "NBC" then return "NBC/Peacock"
    if Instr(1, s, "AMAZON") > 0 then return "Prime Video"
    if Instr(1, s, "PRIME") > 0 then return "Prime Video"
    if Instr(1, s, "NBATV") > 0 or Instr(1, s, "NBA TV") > 0 then return "NBA TV"

    return ""
end function

function GAProviderPriority(provider as String) as Integer
    if provider = "ESPN" then return 0
    if provider = "ABC" then return 1
    if provider = "NBC/Peacock" then return 2
    if provider = "Prime Video" then return 3
    if provider = "NBA TV" then return 4
    return 99
end function

function GASelectProviderFromBroadcasts(broadcasts as Dynamic, fallbackRaw as String) as String
    best = ""
    bestRank = 99

    if GAIsArray(broadcasts) then
        for each b in broadcasts
            p = GANormalizeProvider(GASafeString(b))
            if p = "" then
                continue for
            end if
            r = GAProviderPriority(p)
            if r < bestRank then
                bestRank = r
                best = p
            end if
        end for
    end if

    if best <> "" then return best
    return GANormalizeProvider(fallbackRaw)
end function

function GAFormatInfoLine1(game as Object) as String
    state = LCase(GASafeString(game.Lookup("gameState")))
    if state = "" then
        status = LCase(GASafeString(game.Lookup("status")))
        if status = "live" then
            state = "in"
        else if status = "final" then
            state = "final"
        else
            state = "pre"
        end if
    end if

    if state = "pre" then
        t = GASafeString(game.Lookup("startTimeLocalString"))
        if t = "" then
            display = game.Lookup("display")
            if type(display) = "roAssociativeArray" then
                t = GASafeString(display.Lookup("subtitle"))
            end if
        end if
        return t
    end if

    if state = "final" then return "Final"

    if game.Lookup("isHalftime") <> invalid and game.isHalftime = true then return "HT"

    p = GASafeString(game.Lookup("periodNumber"))
    c = GASafeString(game.Lookup("clockString"))
    if p <> "" and c <> "" then return "Q" + p + " " + c
    if p <> "" then return "Q" + p
    if c <> "" then return c

    periodClock = GASafeString(game.Lookup("periodClock"))
    if periodClock <> "" then return periodClock

    return "Live"
end function

function GARightValue(game as Object, side as String) as String
    state = LCase(GASafeString(game.Lookup("gameState")))
    if state = "" then
        status = LCase(GASafeString(game.Lookup("status")))
        if status = "live" then
            state = "in"
        else if status = "final" then
            state = "final"
        else
            state = "pre"
        end if
    end if

    if state = "pre" then return ""

    if side = "away" then return GASafeString(game.Lookup("awayScore"))
    return GASafeString(game.Lookup("homeScore"))
end function

function GATruncateEllipsis(text as String, maxLen as Integer) as String
    if Len(text) <= maxLen then return text
    if maxLen <= 1 then return ""
    return Left(text, maxLen - 1) + "..."
end function

function GAInjuryTeamSegment(alias as String, rows as Dynamic) as String
    if not GAIsArray(rows) or rows.Count() = 0 then return ""

    parts = []
    for each r in rows
        if type(r) <> "roAssociativeArray" then
            continue for
        end if
        n = GASafeString(r.Lookup("playerName"))
        s = GAUpper(r.Lookup("statusShort"))
        if n = "" then n = GASafeString(r.Lookup("name"))
        if s = "" then s = GAUpper(r.Lookup("status"))
        if n = "" or s = "" then
            continue for
        end if
        parts.Push(n + " (" + s + ")")
    end for

    if parts.Count() = 0 then return ""

    joined = ""
    for each p in parts
        if joined = "" then
            joined = p
        else
            joined = joined + ", " + p
        end if
    end for

    return alias + " - " + joined
end function

function GABuildInjuriesText(game as Object) as String
    awayAlias = GASafeString(game.Lookup("awayAlias"))
    homeAlias = GASafeString(game.Lookup("homeAlias"))
    away = game.Lookup("injuriesAway")
    home = game.Lookup("injuriesHome")

    segA = GAInjuryTeamSegment(awayAlias, away)
    segH = GAInjuryTeamSegment(homeAlias, home)

    if segA = "" and segH = "" then
        return ""
    end if

    text = "Injuries: "
    if segA <> "" then text = text + segA
    if segA <> "" and segH <> "" then text = text + " • "
    if segH <> "" then text = text + segH

    return text
end function

function AdaptGameRow(game as Object) as Object
    awayName = GASafeString(game.Lookup("awayTeamName"))
    homeName = GASafeString(game.Lookup("homeTeamName"))
    if awayName = "" then awayName = GASafeString(game.Lookup("awayTeam"))
    if homeName = "" then homeName = GASafeString(game.Lookup("homeTeam"))

    league = LCase(GASafeString(game.Lookup("league")))
    if league = "ncaam" then
        awayRank = GASafeString(game.Lookup("awayRank"))
        homeRank = GASafeString(game.Lookup("homeRank"))
        if awayRank <> "" and Val(awayRank) > 0 then awayName = awayName + " (" + awayRank + ")"
        if homeRank <> "" and Val(homeRank) > 0 then homeName = homeName + " (" + homeRank + ")"
    end if

    provider = GASelectProviderFromBroadcasts(game.Lookup("broadcasts"), GASafeString(game.Lookup("providerRaw")))
    info1 = GAFormatInfoLine1(game)
    injuriesFull = GABuildInjuriesText(game)
    injuriesSummary = GATruncateEllipsis(injuriesFull, 120)

    return {
        awayTeamName: awayName,
        homeTeamName: homeName,
        awayTeamLogoUri: GASafeString(game.Lookup("awayTeamLogoUri")),
        homeTeamLogoUri: GASafeString(game.Lookup("homeTeamLogoUri")),
        awayRightText: GARightValue(game, "away"),
        homeRightText: GARightValue(game, "home"),
        infoLine1: info1,
        providerText: provider,
        injuriesText: injuriesSummary,
        injuriesDetails: injuriesFull,
        showInjuries: (injuriesFull <> ""),
        isMyTeam: (game.Lookup("isMyTeam") <> invalid and game.isMyTeam = true)
    }
end function
