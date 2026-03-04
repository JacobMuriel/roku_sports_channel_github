sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    scene = screen.CreateScene("MainScene")
    screen.Show()

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        else if type(msg) = "roSGNodeEvent"
            if msg.getField() = "requestExit" and msg.getData() = true then
                screen.Close()
                return
            end if
        end if
    end while
end sub
