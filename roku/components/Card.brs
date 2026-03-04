sub init()
    m.theme = GetThemeTokens()

    m.shadowImage = m.top.findNode("shadowImage")
    m.shadow = m.top.findNode("shadow")
    m.surface = m.top.findNode("surface")

    m.top.cardWidth = 1120
    m.top.cardHeight = 152
    m.top.cornerRadius = m.theme.radius.card
    m.top.backgroundColor = m.theme.colors.cardBg
    m.top.focusBackgroundColor = m.theme.colors.cardBgFocus
    m.top.showShadow = true
    m.top.shadowUri = ""
    m.top.scale = [1.0, 1.0]

    onLayoutChanged()
    onColorChanged()
    onShadowChanged()
end sub

sub onLayoutChanged()
    w = m.top.cardWidth
    h = m.top.cardHeight
    if w <= 0 then w = 100
    if h <= 0 then h = 100

    m.shadow.width = w
    m.shadow.height = h
    m.shadowImage.width = w
    m.shadowImage.height = h
    m.surface.width = w
    m.surface.height = h

    ' Older Roku firmware may not expose cornerRadius on Rectangle.
    ' Keep rectangular fallback for compatibility.
end sub

sub onColorChanged()
    if m.top.isFocused then
        m.surface.color = m.top.focusBackgroundColor
    else
        m.surface.color = m.top.backgroundColor
    end if
end sub

sub onShadowChanged()
    if m.top.shadowUri <> invalid and m.top.shadowUri <> "" then
        m.shadowImage.uri = m.top.shadowUri
        m.shadowImage.visible = m.top.showShadow
        m.shadow.visible = false
        return
    end if

    m.shadowImage.visible = false
    if m.top.showShadow then
        m.shadow.visible = true
    else
        m.shadow.visible = false
    end if
end sub

sub onFocusChanged()
    if m.top.isFocused then
        m.surface.color = m.top.focusBackgroundColor
        m.top.scale = [m.theme.motion.focusScale, m.theme.motion.focusScale]
        m.shadow.opacity = 0.75
    else
        m.surface.color = m.top.backgroundColor
        m.top.scale = [m.theme.motion.blurScale, m.theme.motion.blurScale]
        m.shadow.opacity = 0.45
    end if
end sub
