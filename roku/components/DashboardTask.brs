sub init()
    m.top.functionName = "fetchDashboard"
end sub

function uriEncode(value as String) as String
    encoded = safeString(value)
    encoded = encoded.Replace("%", "%25")
    encoded = encoded.Replace(" ", "%20")
    encoded = encoded.Replace("/", "%2F")
    encoded = encoded.Replace(":", "%3A")
    return encoded
end function

function safeString(value as Dynamic) as String
    if value = invalid then return ""
    return value.ToStr()
end function

sub fetchDashboard()
    m.top.response = invalid
    m.top.error = ""

    baseUrl = safeString(m.top.baseUrl).Trim()
    tz = safeString(m.top.tz).Trim()
    if tz = "" then tz = "America/Chicago"

    if baseUrl = "" then
        m.top.error = "Missing backend BASE_URL"
        return
    end if

    url = baseUrl + "/dashboard?tz=" + uriEncode(tz)

    xfer = CreateObject("roUrlTransfer")
    if xfer = invalid then
        m.top.error = "Network unavailable"
        return
    end if

    if GetInterface(xfer, "ifUrlTransfer") = invalid then
        m.top.error = "URL transfer unsupported"
        return
    end if

    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.SetUrl(url)

    rsp = xfer.GetToString()

    rspText = safeString(rsp).Trim()
    if rspText = "" then
        m.top.error = "Empty response from backend"
        return
    end if

    parsed = ParseJson(rspText)
    if parsed = invalid or type(parsed) <> "roAssociativeArray" then
        m.top.error = "Invalid JSON response"
        return
    end if

    if parsed.Lookup("items") = invalid or type(parsed.items) <> "roArray" then
        m.top.error = "Malformed dashboard payload"
        return
    end if

    m.top.response = parsed
end sub
