local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local ROOT_FOLDER = "ValenHub"
local CONFIG_FILE = ROOT_FOLDER .. "/Config.json"
local DUMP_FOLDER = "ValenHub_Dumps"
local WINDUI_URL = "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function safeFolder(path)
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(path) then
        pcall(makefolder, path)
    end
end

safeFolder(ROOT_FOLDER)
safeFolder(DUMP_FOLDER)

local function loadJsonFile(path, fallback)
    if type(readfile) ~= "function" then
        return fallback
    end
    local okRead, body = pcall(readfile, path)
    if not okRead or type(body) ~= "string" or body == "" then
        return fallback
    end
    local okDecode, result = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if okDecode and type(result) == "table" then
        return result
    end
    return fallback
end

local function saveJsonFile(path, data)
    if type(writefile) ~= "function" then
        return false
    end
    safeFolder(ROOT_FOLDER)
    local okEncode, body = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not okEncode then
        return false
    end
    return pcall(writefile, path, body)
end

local AppConfig = loadJsonFile(CONFIG_FILE, {
    Theme = "Dark",
    Background = nil,
})


local function tween(instance, duration, style, direction, properties)
    local info = TweenInfo.new(
        duration,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local object = TweenService:Create(instance, info, properties)
    object:Play()
    return object
end

local function showIntro()
    local ok, err = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "ValenHubIntro"
        gui.DisplayOrder = 999999
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Parent = game:GetService("CoreGui")

        local background = Instance.new("Frame")
        background.Name = "Background"
        background.Size = UDim2.new(1, 0, 1, 0)
        background.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
        background.BorderSizePixel = 0
        background.Parent = gui

        local vignette = Instance.new("ImageLabel")
        vignette.Name = "Vignette"
        vignette.Size = UDim2.new(1, 0, 1, 0)
        vignette.BackgroundTransparency = 1
        vignette.Image = "rbxassetid://1072804457"
        vignette.ImageColor3 = Color3.fromRGB(0, 0, 0)
        vignette.ImageTransparency = 0.3
        vignette.ZIndex = 1
        vignette.Parent = background

        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(0, 400, 0, 200)
        holder.Position = UDim2.new(0.5, -200, 0.5, -100)
        holder.BackgroundTransparency = 1
        holder.ZIndex = 10
        holder.Parent = background

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Position = UDim2.new(0.5, -3, 0, 30)
        dot.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
        dot.BackgroundTransparency = 1
        dot.Parent = holder
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, 0, 0, 60)
        title.Position = UDim2.new(0, 0, 0, 50)
        title.BackgroundTransparency = 1
        title.Text = "VALEN HUB"
        title.TextColor3 = Color3.fromRGB(230, 230, 235)
        title.TextSize = 42
        title.Font = Enum.Font.GothamBold
        title.TextTransparency = 1
        title.ZIndex = 10
        title.Parent = holder

        local line = Instance.new("Frame")
        line.Size = UDim2.new(0, 0, 0, 1)
        line.Position = UDim2.new(0.5, 0, 0, 115)
        line.AnchorPoint = Vector2.new(0.5, 0)
        line.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
        line.BorderSizePixel = 0
        line.BackgroundTransparency = 1
        line.Parent = holder

        local subtitle = Instance.new("TextLabel")
        subtitle.Size = UDim2.new(1, 0, 0, 24)
        subtitle.Position = UDim2.new(0, 0, 0, 125)
        subtitle.BackgroundTransparency = 1
        subtitle.Text = "Universal Game Dump"
        subtitle.TextColor3 = Color3.fromRGB(120, 120, 130)
        subtitle.TextSize = 13
        subtitle.Font = Enum.Font.Gotham
        subtitle.TextTransparency = 1
        subtitle.Parent = holder

        local progressBack = Instance.new("Frame")
        progressBack.Size = UDim2.new(0, 200, 0, 2)
        progressBack.Position = UDim2.new(0.5, -100, 0, 165)
        progressBack.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        progressBack.BorderSizePixel = 0
        progressBack.BackgroundTransparency = 1
        progressBack.Parent = holder

        local progress = Instance.new("Frame")
        progress.Size = UDim2.new(0, 0, 1, 0)
        progress.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
        progress.BorderSizePixel = 0
        progress.Parent = progressBack

        tween(dot, 0.4, nil, nil, {BackgroundTransparency = 0})
        task.wait(0.2)
        tween(title, 0.8, nil, nil, {TextTransparency = 0})
        task.wait(0.2)
        tween(line, 0.6, nil, nil, {Size = UDim2.new(0, 60, 0, 1), BackgroundTransparency = 0})
        tween(subtitle, 0.6, nil, nil, {TextTransparency = 0})
        task.wait(0.15)
        tween(progressBack, 0.4, nil, nil, {BackgroundTransparency = 0})
        tween(progress, 2.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut, {Size = UDim2.new(1, 0, 1, 0)})
        task.wait(2.8)

        tween(title, 0.7, nil, nil, {TextTransparency = 1})
        tween(subtitle, 0.7, nil, nil, {TextTransparency = 1})
        tween(line, 0.7, nil, nil, {BackgroundTransparency = 1})
        tween(progressBack, 0.7, nil, nil, {BackgroundTransparency = 1})
        tween(progress, 0.7, nil, nil, {BackgroundTransparency = 1})
        tween(dot, 0.7, nil, nil, {BackgroundTransparency = 1})
        tween(vignette, 0.8, nil, nil, {ImageTransparency = 1})
        tween(background, 0.8, nil, nil, {BackgroundTransparency = 1})
        task.wait(1)
        gui:Destroy()
    end)
    if not ok then
        warn("[ValenHub] Intro animation error: " .. tostring(err))
    end
end


showIntro()

local okWind, WindUI = pcall(function()
    return loadstring(game:HttpGet(WINDUI_URL))()
end)
if not okWind or not WindUI then
    error("Failed to load WindUI: " .. tostring(WindUI))
end

local Window = WindUI:CreateWindow({
    Title = "Valen Hub",
    Folder = "ValenHub",
    HideSearchBar = false,
    Background = AppConfig.Background,
    OpenButton = {
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
})

WindUI:SetTheme(AppConfig.Theme or "Dark")

local MainTab = Window:Tab({Title = "Main", Icon = "user-round-check"})
local PreviewTab = Window:Tab({Title = "Preview", Icon = "eye"})
local RemoteSpyTab = Window:Tab({Title = "Remote Spy", Icon = "activity"})
local TradeTab = Window:Tab({Title = "Trade Rollback", Icon = "rotate-ccw"})
local MapTab = Window:Tab({Title = "Map Dump", Icon = "map"})
local AntiVCTab = Window:Tab({Title = "Anti VC Ban", Icon = "mic"})
local SettingsTab = Window:Tab({Title = "Settings", Icon = "settings"})

local AntiVCData = {
    Enabled = false,
    AntiMuteLoop = false,
    AutoRejoin = false,
    VoiceChatInternal = nil,
    VoiceChatService = nil,
    StateConn = nil,
    LoopConn = nil,
    RejoinConn = nil,
    Status = "Idle",
    LastState = nil,
    MuteCount = 0,
    RejoinCount = 0,
}

local function GetVoiceChatInternal()
    local ok, svc = pcall(function() return game:GetService("VoiceChatInternal") end)
    return ok and svc or nil
end

local function GetVoiceChatService()
    local ok, svc = pcall(function() return game:GetService("VoiceChatService") end)
    return ok and svc or nil
end

local function ForceUnmuteSelf()
    local vci = GetVoiceChatInternal()
    if not vci then return false end
    return pcall(function() vci:MuteMicrophone(false) end)
end

local function IsSelfMuted()
    local vci = GetVoiceChatInternal()
    if not vci then return nil end
    local ok, muted = pcall(function() return vci:IsMutedLocally() end)
    return ok and muted or nil
end

local function RejoinVoiceChannel()
    local vcs = GetVoiceChatService()
    if not vcs then return false end
    return pcall(function()
        if vcs.joinVoice then vcs:joinVoice() end
    end)
end

local function ToggleMicMute()
    local vci = GetVoiceChatInternal()
    if not vci then return false end
    return pcall(function() vci:TempSetMicMutedToggleMic() end)
end

local function GetVCState()
    local vci = GetVoiceChatInternal()
    if not vci then return "Unknown" end
    local ok, state = pcall(function() return vci.VoiceChatState end)
    return ok and tostring(state) or "Error"
end

local function StartAntiVCLoop()
    if AntiVCData.LoopConn then
        pcall(function() AntiVCData.LoopConn:Disconnect() end)
        AntiVCData.LoopConn = nil
    end
    AntiVCData.LoopConn = task.spawn(function()
        while AntiVCData.AntiMuteLoop do
            task.wait(0.5)
            if not AntiVCData.AntiMuteLoop then break end
            if IsSelfMuted() == true then
                AntiVCData.MuteCount = AntiVCData.MuteCount + 1
                ForceUnmuteSelf()
            end
        end
    end)
end

local function StopAntiVCLoop()
    AntiVCData.AntiMuteLoop = false
    if AntiVCData.LoopConn then
        pcall(function() AntiVCData.LoopConn:Disconnect() end)
        AntiVCData.LoopConn = nil
    end
end

local function StartAutoRejoin()
    if AntiVCData.RejoinConn then
        pcall(function() AntiVCData.RejoinConn:Disconnect() end)
        AntiVCData.RejoinConn = nil
    end
    local vci = GetVoiceChatInternal()
    if vci and vci.StateChanged then
        AntiVCData.RejoinConn = vci.StateChanged:Connect(function(_, newState)
            if not AntiVCData.AutoRejoin then return end
            AntiVCData.LastState = tostring(newState)
            local state = tostring(newState):lower()
            if state:find("ended") or state:find("failed") or state:find("left") then
                AntiVCData.RejoinCount = AntiVCData.RejoinCount + 1
                task.wait(1)
                RejoinVoiceChannel()
            end
        end)
    else
        AntiVCData.RejoinConn = task.spawn(function()
            while AntiVCData.AutoRejoin do
                task.wait(3)
                if not AntiVCData.AutoRejoin then break end
                local state = GetVCState():lower()
                if state:find("ended") or state:find("failed") or state:find("left") or state:find("idle") then
                    AntiVCData.RejoinCount = AntiVCData.RejoinCount + 1
                    RejoinVoiceChannel()
                end
            end
        end)
    end
end

local function StopAutoRejoin()
    AntiVCData.AutoRejoin = false
    if AntiVCData.RejoinConn then
        pcall(function()
            if typeof(AntiVCData.RejoinConn) == "RBXScriptConnection" then
                AntiVCData.RejoinConn:Disconnect()
            end
        end)
        AntiVCData.RejoinConn = nil
    end
end

local function EnableAntiVC()
    AntiVCData.Enabled = true
    AntiVCData.AntiMuteLoop = true
    AntiVCData.AutoRejoin = true
    AntiVCData.VoiceChatInternal = GetVoiceChatInternal()
    AntiVCData.VoiceChatService = GetVoiceChatService()
    StartAntiVCLoop()
    StartAutoRejoin()
    AntiVCData.Status = "Active"
end

local function DisableAntiVC()
    AntiVCData.Enabled = false
    StopAntiVCLoop()
    StopAutoRejoin()
    AntiVCData.Status = "Disabled"
end

local AntiVCStatus = AntiVCTab:Paragraph({Title = "Status", Desc = "Idle"})
AntiVCTab:Paragraph({
    Title = "Anti VC Ban",
    Desc = "ระบบกันแบนไมค์ / กัน Mute อัตโนมัติ ใช้ VoiceChatInternal API + VoiceChatService",
})

local function updateAntiVCStatus()
    local muted = IsSelfMuted()
    local mutedText = muted == nil and "N/A" or (muted and "Muted" or "Unmuted")
    AntiVCStatus:SetDesc(
        "State: " .. GetVCState()
        .. " | Mic: " .. mutedText
        .. " | AntiMutes: " .. tostring(AntiVCData.MuteCount)
        .. " | Rejoins: " .. tostring(AntiVCData.RejoinCount)
    )
end

AntiVCTab:Toggle({
    Title = "Enable Anti VC Ban",
    Desc = "เปิดระบบกันแบนไมค์แบบเต็มรูปแบบ (AntiMute + AutoRejoin)",
    Flag = "AntiVCEnabled",
    Default = false,
    Callback = function(value)
        if value then EnableAntiVC() else DisableAntiVC() end
        if value then
            WindUI:Notify({Title = "Anti VC Ban", Desc = "Activated! Monitoring voice chat..."})
        end
        updateAntiVCStatus()
    end,
})

AntiVCTab:Toggle({
    Title = "Anti Mute Loop",
    Desc = "Force unmute ตัวเองทุก 0.5 วินาที หากถูก AI mute",
    Flag = "AntiMuteLoop",
    Default = false,
    Callback = function(value)
        AntiVCData.AntiMuteLoop = value
        if value then StartAntiVCLoop() else StopAntiVCLoop() end
        updateAntiVCStatus()
    end,
})

AntiVCTab:Toggle({
    Title = "Auto Rejoin Voice",
    Desc = "Rejoin voice channel อัตโนมัติหากถูก disconnect / suspend",
    Flag = "AutoRejoinVoice",
    Default = false,
    Callback = function(value)
        AntiVCData.AutoRejoin = value
        if value then StartAutoRejoin() else StopAutoRejoin() end
        updateAntiVCStatus()
    end,
})

AntiVCTab:Button({Title = "Force Unmute Now", Icon = "mic", Callback = function()
    ForceUnmuteSelf()
    WindUI:Notify({Title = "Anti VC Ban", Desc = "Force unmute executed!"})
    updateAntiVCStatus()
end})

AntiVCTab:Button({Title = "Rejoin Voice Channel", Icon = "refresh-cw", Callback = function()
    RejoinVoiceChannel()
    WindUI:Notify({Title = "Anti VC Ban", Desc = "Rejoin voice channel executed!"})
    updateAntiVCStatus()
end})

AntiVCTab:Button({Title = "Toggle Mic Mute", Icon = "mic-off", Callback = function()
    ToggleMicMute()
    WindUI:Notify({Title = "Anti VC Ban", Desc = "Mic toggled!"})
    updateAntiVCStatus()
end})

AntiVCTab:Space()
AntiVCTab:Paragraph({
    Title = "API Info",
    Desc = "VoiceChatInternal (Secret API):\n- MuteMicrophone(bool)\n- IsMutedLocally()\n- TempSetMicMutedToggleMic()\n- StateChanged event\n\nVoiceChatService:\n- joinVoice()",
})
AntiVCTab:Paragraph({
    Title = "วิธีใช้",
    Desc = "1) เปิด Enable Anti VC Ban เพื่อเปิดใช้งานทั้งหมด\n2) Anti Mute Loop จะ force unmute ตัวเองตลอดเวลา\n3) Auto Rejoin Voice จะ rejoin voice channel หากถูก disconnect\n4) กด Force Unmute Now หากถูก mute กะทันหัน\n5) กด Rejoin Voice Channel หาก icon voice chat หาย",
})
AntiVCTab:Space()
AntiVCTab:Paragraph({Title = "Dump Source Code", Desc = "เซฟหรือคัดลอกซอสโค้ดระบบแบนไมค์เป็นไฟล์ standalone .lua"})


local ANTI_VC_STANDALONE_SOURCE = [====[
local AntiVCData = {
    Enabled = false,
    AntiMuteLoop = false,
    AutoRejoin = false,
    VoiceChatInternal = nil,
    VoiceChatService = nil,
    StateConn = nil,
    LoopConn = nil,
    RejoinConn = nil,
    Status = "Idle",
    LastState = nil,
    MuteCount = 0,
    RejoinCount = 0,
}

local function GetVoiceChatInternal()
    local ok, svc = pcall(function()
        return game:GetService("VoiceChatInternal")
    end)
    if ok and svc then
        return svc
    end
    return nil
end

local function GetVoiceChatService()
    local ok, svc = pcall(function()
        return game:GetService("VoiceChatService")
    end)
    if ok and svc then
        return svc
    end
    return nil
end

local function ForceUnmuteSelf()
    local vci = GetVoiceChatInternal()
    if not vci then return false end
    local ok = pcall(function()
        vci:MuteMicrophone(false)
    end)
    return ok
end

local function IsSelfMuted()
    local vci = GetVoiceChatInternal()
    if not vci then return nil end
    local ok, muted = pcall(function()
        return vci:IsMutedLocally()
    end)
    if ok then return muted end
    return nil
end

local function RejoinVoiceChannel()
    local vcs = GetVoiceChatService()
    if not vcs then return false end
    local ok = pcall(function()
        if vcs.joinVoice then
            vcs:joinVoice()
        end
    end)
    return ok
end

local function ToggleMicMute()
    local vci = GetVoiceChatInternal()
    if not vci then return false end
    local ok = pcall(function()
        vci:TempSetMicMutedToggleMic()
    end)
    return ok
end

local function GetVCState()
    local vci = GetVoiceChatInternal()
    if not vci then return "Unknown" end
    local ok, state = pcall(function()
        return vci.VoiceChatState
    end)
    if ok then return tostring(state) end
    return "Error"
end

local function StartAntiVCLoop()
    if AntiVCData.LoopConn then
        pcall(function() AntiVCData.LoopConn:Disconnect() end)
        AntiVCData.LoopConn = nil
    end
    AntiVCData.LoopConn = task.spawn(function()
        while AntiVCData.AntiMuteLoop do
            task.wait(0.5)
            if not AntiVCData.AntiMuteLoop then break end
            local muted = IsSelfMuted()
            if muted == true then
                AntiVCData.MuteCount = AntiVCData.MuteCount + 1
                ForceUnmuteSelf()
            end
        end
    end)
end

local function StopAntiVCLoop()
    AntiVCData.AntiMuteLoop = false
    if AntiVCData.LoopConn then
        pcall(function() AntiVCData.LoopConn:Disconnect() end)
        AntiVCData.LoopConn = nil
    end
end

local function StartAutoRejoin()
    if AntiVCData.RejoinConn then
        pcall(function() AntiVCData.RejoinConn:Disconnect() end)
        AntiVCData.RejoinConn = nil
    end
    local vci = GetVoiceChatInternal()
    if vci and vci.StateChanged then
        AntiVCData.RejoinConn = vci.StateChanged:Connect(function(oldState, newState)
            if not AntiVCData.AutoRejoin then return end
            AntiVCData.LastState = tostring(newState)
            if tostring(newState):lower():find("ended") or tostring(newState):lower():find("failed") or tostring(newState):lower():find("left") then
                AntiVCData.RejoinCount = AntiVCData.RejoinCount + 1
                task.wait(1)
                RejoinVoiceChannel()
            end
        end)
    else
        AntiVCData.RejoinConn = task.spawn(function()
            while AntiVCData.AutoRejoin do
                task.wait(3)
                if not AntiVCData.AutoRejoin then break end
                local state = GetVCState()
                if state:lower():find("ended") or state:lower():find("failed") or state:lower():find("left") or state:lower():find("idle") then
                    AntiVCData.RejoinCount = AntiVCData.RejoinCount + 1
                    RejoinVoiceChannel()
                end
            end
        end)
    end
end

local function StopAutoRejoin()
    AntiVCData.AutoRejoin = false
    if AntiVCData.RejoinConn then
        pcall(function()
            if typeof(AntiVCData.RejoinConn) == "RBXScriptConnection" then
                AntiVCData.RejoinConn:Disconnect()
            end
        end)
        AntiVCData.RejoinConn = nil
    end
end

local function EnableAntiVC()
    AntiVCData.Enabled = true
    AntiVCData.AntiMuteLoop = true
    AntiVCData.AutoRejoin = true
    AntiVCData.VoiceChatInternal = GetVoiceChatInternal()
    AntiVCData.VoiceChatService = GetVoiceChatService()
    StartAntiVCLoop()
    StartAutoRejoin()
    AntiVCData.Status = "Active"
    print("[ValenHub AntiVC] Activated!")
end

local function DisableAntiVC()
    AntiVCData.Enabled = false
    StopAntiVCLoop()
    StopAutoRejoin()
    AntiVCData.Status = "Disabled"
    print("[ValenHub AntiVC] Deactivated.")
end

EnableAntiVC()
task.spawn(function()
    while true do
        task.wait(5)
        local state = GetVCState()
        local muted = IsSelfMuted()
        local mutedStr = muted == nil and "N/A" or (muted and "Muted" or "Unmuted")
        print("[ValenHub AntiVC] State: " .. state .. " | Mic: " .. mutedStr .. " | AntiMutes: " .. AntiVCData.MuteCount .. " | Rejoins: " .. AntiVCData.RejoinCount)
    end
end)

]====]

AntiVCTab:Button({
    Title = "Dump Anti VC Source to File",
    Icon = "file-code",
    Desc = "เซฟซอสโค้ดระบบแบนไมค์เป็นไฟล์ .lua ใน executor workspace + คัดลอกไปคลิปบอร์ด",
    Callback = function()
        task.spawn(function()
            safeFolder(DUMP_FOLDER)
            safeFolder(DUMP_FOLDER .. "/Dump")
            local path = DUMP_FOLDER .. "/Dump/ValenHub_AntiVC_Standalone_" .. os.date("%Y%m%d_%H%M%S") .. ".lua"
            if type(writefile) == "function" then pcall(writefile, path, ANTI_VC_STANDALONE_SOURCE) end
            if type(setclipboard) == "function" then pcall(setclipboard, ANTI_VC_STANDALONE_SOURCE) end
            WindUI:Notify({Title = "Anti VC Dump", Desc = "Saved source to " .. path})
        end)
    end,
})

AntiVCTab:Button({
    Title = "Copy Anti VC Source",
    Icon = "clipboard",
    Desc = "คัดลอกซอสโค้ดระบบแบนไมค์ไปยังคลิปบอร์ดอย่างเดียว",
    Callback = function()
        task.spawn(function()
            if type(setclipboard) == "function" then
                setclipboard(ANTI_VC_STANDALONE_SOURCE)
                WindUI:Notify({Title = "Anti VC Dump", Desc = "Copied " .. tostring(#ANTI_VC_STANDALONE_SOURCE) .. " chars to clipboard!"})
            end
        end)
    end,
})

local PreviewCode
AntiVCTab:Button({
    Title = "Preview Anti VC Source",
    Icon = "eye",
    Desc = "แสดงตัวอย่างซอสโค้ดในแท็บ Preview",
    Callback = function()
        task.spawn(function()
            if PreviewCode then PreviewCode:SetCode(ANTI_VC_STANDALONE_SOURCE) end
            WindUI:Notify({Title = "Anti VC Dump", Desc = "Preview loaded in Preview tab!"})
        end)
    end,
})

task.spawn(function()
    while task.wait(2) do
        updateAntiVCStatus()
    end
end)

TradeTab:Paragraph({Title = "Trade Rollback", Desc = "เลือกเป้าหมายและไอเทมหลายอันเข้า Queue แล้วกด Dupe!"})

local TargetQueue = {}
local ItemQueue = {}
local AutoRefreshPlayers = true
local AutoRefreshItems = true

local TargetTypeDropdown = TradeTab:Dropdown({
    Title = "ประเภทเป้าหมาย",
    Values = {
        {Title = "ผู้เล่นคนอื่น"},
        {Title = "ตัวเอง (Backpack)"},
        {Title = "ตัวเอง (Character)"},
        {Title = "Workspace"},
        {Title = "ReplicatedStorage"},
    },
    Value = {Title = "ผู้เล่นคนอื่น"},
    Callback = function() end,
})

local function getPlayerValues()
    local values = {}
    for _, player in ipairs(Players:GetPlayers()) do
        values[#values + 1] = {Title = player.Name}
    end
    return values
end

local PlayerDropdown = TradeTab:Dropdown({
    Title = "เลือกผู้เล่น",
    Values = getPlayerValues(),
    Value = {Title = "Select..."},
    Callback = function() end,
})

local function refreshPlayers(notify)
    PlayerDropdown:SetValues(getPlayerValues())
    if notify then WindUI:Notify({Title = "Trade Rollback", Desc = "รีเฟรชรายชื่อผู้เล่นแล้ว"}) end
end

TradeTab:Button({Title = "Refresh Players", Icon = "refresh-cw", Callback = function() refreshPlayers(true) end})
TradeTab:Toggle({
    Title = "Auto Refresh รายชื่อผู้เล่น",
    Desc = "อัพเดตรายชื่อผู้เล่นอัตโนมัติ",
    Flag = "AutoRefreshPlayerList",
    Default = true,
    Callback = function(value)
        AutoRefreshPlayers = value
    end,
})

Players.PlayerAdded:Connect(function() if AutoRefreshPlayers then task.wait(0.3); refreshPlayers(false) end end)
Players.PlayerRemoving:Connect(function() if AutoRefreshPlayers then task.wait(0.3); refreshPlayers(false) end end)

local TargetQueueParagraph = TradeTab:Paragraph({Title = "Target Queue (0)", Desc = "ยังไม่มีเป้าหมาย"})
local function updateTargetQueueUi()
    TargetQueueParagraph:SetTitle("Target Queue (" .. tostring(#TargetQueue) .. ")")
    if #TargetQueue == 0 then
        TargetQueueParagraph:SetDesc("ยังไม่มีเป้าหมาย")
        return
    end
    local lines = {}
    for i, entry in ipairs(TargetQueue) do lines[#lines + 1] = tostring(i) .. ". " .. entry.Label end
    TargetQueueParagraph:SetDesc(table.concat(lines, "\n"))
end

local function resolveTarget(targetType, playerName)
    if targetType == "ผู้เล่นคนอื่น" then
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Name == playerName then
                return player, "Player: " .. player.Name
            end
        end
    elseif targetType == "ตัวเอง (Backpack)" then
        local object = LocalPlayer:FindFirstChild("Backpack")
        return object, "Self: Backpack"
    elseif targetType == "ตัวเอง (Character)" then
        return LocalPlayer.Character, "Self: Character"
    elseif targetType == "Workspace" then
        return workspace, "Workspace"
    elseif targetType == "ReplicatedStorage" then
        return game:GetService("ReplicatedStorage"), "ReplicatedStorage"
    end
    return nil, nil
end

TradeTab:Button({Title = "Add Target", Icon = "plus", Callback = function()
    local targetType = TargetTypeDropdown.Value and TargetTypeDropdown.Value.Title or "ผู้เล่นคนอื่น"
    local playerName = PlayerDropdown.Value and PlayerDropdown.Value.Title or ""
    local target, label = resolveTarget(targetType, playerName)
    if target then
        TargetQueue[#TargetQueue + 1] = {Object = target, Type = targetType, Label = label}
        updateTargetQueueUi()
        WindUI:Notify({Title = "Trade Rollback", Desc = "เพิ่ม " .. label .. " (" .. tostring(#TargetQueue) .. ")"})
    end
end})

TradeTab:Button({Title = "Clear Target Queue", Icon = "trash-2", Callback = function()
    TargetQueue = {}
    updateTargetQueueUi()
    WindUI:Notify({Title = "Trade Rollback", Desc = "ล้าง Target Queue แล้ว"})
end})

TradeTab:Space()

local function scanLocalItems()
    local names, seen = {}, {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, object in ipairs(backpack:GetChildren()) do
            if object:IsA("Tool") and not seen[object.Name] then
                seen[object.Name] = true
                names[#names + 1] = {Title = object.Name}
            end
        end
    end
    if LocalPlayer.Character then
        for _, object in ipairs(LocalPlayer.Character:GetChildren()) do
            if object:IsA("Tool") and not seen[object.Name] then
                seen[object.Name] = true
                names[#names + 1] = {Title = object.Name}
            end
        end
    end
    if #names == 0 then names[1] = {Title = "No items"} end
    return names
end

local ItemDropdown = TradeTab:Dropdown({
    Title = "เลือกไอเทม (เลือกแล้วกด Add)",
    Values = {{Title = "No items"}},
    Value = {Title = "Press Scan..."},
    Callback = function() end,
})

local function refreshItems(notify)
    ItemDropdown:SetValues(scanLocalItems())
    if notify then WindUI:Notify({Title = "Trade Rollback", Desc = "สแกนไอเทมแล้ว"}) end
end

TradeTab:Button({Title = "Scan Items", Icon = "scan", Callback = function() refreshItems(true) end})
TradeTab:Toggle({
    Title = "Auto Refresh รายการไอเทม",
    Desc = "อัพเดตไอเทมอัตโนมัติ",
    Flag = "AutoRefreshItemList",
    Default = true,
    Callback = function(value) AutoRefreshItems = value end,
})

local function hookItemRefresh()
    if LocalPlayer.CharacterAdded then LocalPlayer.CharacterAdded:Connect(function() if AutoRefreshItems then task.wait(0.5); refreshItems(false) end end) end
    if LocalPlayer.CharacterRemoving then LocalPlayer.CharacterRemoving:Connect(function() if AutoRefreshItems then task.wait(0.2); refreshItems(false) end end) end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        backpack.ChildAdded:Connect(function() if AutoRefreshItems then task.wait(0.1); refreshItems(false) end end)
        backpack.ChildRemoved:Connect(function() if AutoRefreshItems then task.wait(0.1); refreshItems(false) end end)
    end
end
hookItemRefresh()

local ItemQueueParagraph = TradeTab:Paragraph({Title = "Item Queue (0)", Desc = "ยังไม่มีไอเทมใน Queue"})
local function updateItemQueueUi()
    ItemQueueParagraph:SetTitle("Item Queue (" .. tostring(#ItemQueue) .. ")")
    if #ItemQueue == 0 then
        ItemQueueParagraph:SetDesc("ยังไม่มีไอเทม")
        return
    end
    local lines = {}
    for i, itemName in ipairs(ItemQueue) do lines[#lines + 1] = tostring(i) .. ". " .. itemName end
    ItemQueueParagraph:SetDesc(table.concat(lines, "\n"))
end

local function addItem(name)
    name = trim(name)
    if name == "" or name == "No items" or name == "Press Scan..." then return end
    ItemQueue[#ItemQueue + 1] = name
    updateItemQueueUi()
    WindUI:Notify({Title = "Trade Rollback", Desc = "เพิ่ม " .. name .. " (" .. tostring(#ItemQueue) .. ")"})
end

TradeTab:Button({Title = "Add Item", Icon = "plus", Callback = function()
    addItem(ItemDropdown.Value and ItemDropdown.Value.Title or "")
end})
TradeTab:Input({Title = "พิมพ์ชื่อไอเทมเอง", Placeholder = "ชื่อไอเทม...", Callback = addItem})
TradeTab:Button({Title = "Clear Item Queue", Icon = "trash-2", Callback = function()
    ItemQueue = {}
    updateItemQueueUi()
    WindUI:Notify({Title = "Trade Rollback", Desc = "ล้าง Item Queue แล้ว"})
end})

TradeTab:Space()
local TradeStatus = TradeTab:Paragraph({Title = "Status", Desc = "เพิ่ม Target และ Item เข้า Queue แล้วกด Dupe!"})

local PROPERTY_NAMES = {
    "Anchored", "CanCollide", "CanTouch", "CanQuery", "Transparency", "Reflectance",
    "Color", "Material", "Size", "CFrame", "Position", "Orientation",
    "Value", "Visible", "Enabled", "Text", "Image", "Texture", "TextureID", "TextureId",
    "MeshId", "MeshType", "Scale", "Offset", "SecondaryAxis", "Axis",
    "Rate", "Speed", "Lifetime", "LightEmission", "Brightness", "Range", "Shadows",
    "Volume", "PlaybackSpeed", "RollOffMaxDistance", "RollOffMinDistance", "RollOffMode",
    "Neutral", "TeamColor", "AllowTeamChangeOnTouch", "Duration", "Face", "Locked",
    "MaxSpeed", "Torque", "TurnSpeed", "Shape", "StudsPerTileU", "StudsPerTileV",
}

local function safeProperty(object, property)
    local ok, value = pcall(function() return object[property] end)
    return ok, value
end

local function captureInstance(object)
    local record = {
        Ref = object,
        Name = object.Name,
        ClassName = object.ClassName,
        FullName = object:GetFullName(),
        ParentPath = object.Parent and object.Parent:GetFullName() or "",
        Properties = {},
        Attributes = {},
    }
    for _, property in ipairs(PROPERTY_NAMES) do
        local ok, value = safeProperty(object, property)
        if ok then record.Properties[property] = value end
    end
    pcall(function() record.Attributes = object:GetAttributes() end)
    return record
end

local SnapshotManager = {
    Snapshots = {},
    SnapNames = {},
    MaxSnapshots = 20,
    AutoSnapEnabled = false,
    AutoSnapInterval = 5,
    SnapInProgress = false,
}

local function createSnapshot(root, name)
    SnapshotManager.SnapInProgress = true
    local snapshot = {
        Name = name,
        Time = os.time(),
        Timestamp = tick(),
        TargetPath = root:GetFullName(),
        InstanceCount = 0,
        Data = {},
    }
    local objects = {root}
    for _, child in ipairs(root:GetDescendants()) do objects[#objects + 1] = child end
    for _, object in ipairs(objects) do
        snapshot.InstanceCount = snapshot.InstanceCount + 1
        snapshot.Data[object] = captureInstance(object)
    end
    SnapshotManager.Snapshots[name] = snapshot
    SnapshotManager.SnapNames[#SnapshotManager.SnapNames + 1] = name
    while #SnapshotManager.SnapNames > SnapshotManager.MaxSnapshots do
        local oldest = table.remove(SnapshotManager.SnapNames, 1)
        SnapshotManager.Snapshots[oldest] = nil
    end
    SnapshotManager.SnapInProgress = false
    return snapshot
end

local function restoreSnapshot(snapshot)
    if not snapshot then return false end
    for object, record in pairs(snapshot.Data) do
        if object and object:IsDescendantOf(game) then
            for property, value in pairs(record.Properties) do
                pcall(function() object[property] = value end)
            end
            for key, value in pairs(record.Attributes) do
                pcall(function() object:SetAttribute(key, value) end)
            end
        end
    end
    return true
end

local function findLocalItem(name)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local item = backpack and backpack:FindFirstChild(name)
    if not item and LocalPlayer.Character then item = LocalPlayer.Character:FindFirstChild(name) end
    return item
end

local function targetContainer(entry)
    local object = entry.Object
    if not object then return nil end
    if entry.Type == "ผู้เล่นคนอื่น" then
        return object:FindFirstChild("Backpack") or object.Character
    end
    return object
end

local function cloneQueuedItems()
    local count = 0
    for _, entry in ipairs(TargetQueue) do
        local destination = targetContainer(entry)
        if destination then
            for _, itemName in ipairs(ItemQueue) do
                local source = findLocalItem(itemName)
                if source then
                    local ok = pcall(function()
                        local clone = source:Clone()
                        clone.Parent = destination
                    end)
                    if ok then count = count + 1 end
                end
            end
        end
    end
    return count
end

TradeTab:Button({Title = "Dupe!", Icon = "copy", Callback = function()
    task.spawn(function()
        if #TargetQueue == 0 then
            TradeStatus:SetDesc("Target Queue ว่าง!")
            WindUI:Notify({Title = "Trade Rollback", Desc = "Target Queue ว่าง!"})
            return
        end
        if #ItemQueue == 0 then
            TradeStatus:SetDesc("Item Queue ว่าง!")
            WindUI:Notify({Title = "Trade Rollback", Desc = "Item Queue ว่าง!"})
            return
        end
        TradeStatus:SetDesc("Step 1/3: Snapshot...")
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local snapshot = backpack and createSnapshot(backpack, "TradeDupe_Multi") or nil
        task.wait(0.15)
        local cloned = cloneQueuedItems()
        TradeStatus:SetDesc("Step 3/3: Cloned " .. tostring(cloned) .. " กำลัง Rollback...")
        task.wait(0.15)
        if snapshot then restoreSnapshot(snapshot) end
        TradeStatus:SetDesc("Done! Cloned " .. tostring(cloned) .. " items")
        WindUI:Notify({Title = "Trade Rollback", Desc = "Dupe / rollback finished! " .. tostring(cloned) .. " items"})
    end)
end})

TradeTab:Button({
    Title = "Simple Clone",
    Icon = "copy",
    Desc = "Clone ไปยังทุก Target โดยไม่ Rollback",
    Callback = function()
        task.spawn(function()
            if #TargetQueue == 0 then
                WindUI:Notify({Title = "Trade Rollback", Desc = "Target Queue ว่าง!"})
                return
            end
            local cloned = cloneQueuedItems()
            WindUI:Notify({Title = "Trade Rollback", Desc = "Clone OK! " .. tostring(cloned) .. " items"})
        end)
    end,
})

TradeTab:Space()
TradeTab:Paragraph({
    Title = "วิธีใช้",
    Desc = "1) เลือก Target Type -> Add Target (ทำซ้ำได้)\n2) Scan Items แล้วเลือกไอเทม -> Add Item (ทำซ้ำได้)\n3) กด Dupe เพื่อ Snapshot -> Clone -> Rollback",
})

MainTab:Paragraph({
    Title = "ยินดีต้อนรับสู่ Valen Hub",
    Desc = "แท็บนี้ใช้ Dump ข้อมูลในเกม เช่น ReplicatedStorage, Workspace ฯลฯ เลือก Service ที่ต้องการ ตั้งค่า options แล้วกด Dump เพื่อดึงข้อมูลออกมาเป็นไฟล์ .txt หรือ .lua",
})

local ServiceNames = {
    "ReplicatedStorage", "Workspace", "Players", "Lighting", "StarterGui", "StarterPack", "StarterPlayer",
    "SoundService", "Chat", "TextChatService", "RunService", "TweenService", "HttpService", "MarketplaceService",
    "BadgeService", "Teams", "JointsService", "CollectionService", "PhysicsService", "AssetService", "GamePassService",
    "PointsService", "PolicyService", "SocialService", "TeleportService", "UserInputService", "VRService",
    "ServerScriptService", "ServerStorage", "ReplicatedFirst",
}
local ServiceValues = {}
for _, name in ipairs(ServiceNames) do ServiceValues[#ServiceValues + 1] = {Title = name} end

local TargetServiceDropdown = MainTab:Dropdown({
    Title = "Target Service",
    Values = ServiceValues,
    Value = {Title = "ReplicatedStorage"},
    Callback = function() end,
})
local DumpSubPath = ""
MainTab:Input({Title = "Sub Path (optional)", Placeholder = "e.g. TS/data/plants", Callback = function(value) DumpSubPath = trim(value) end})
MainTab:Space()

local DumpOptions = {Children = true, Attributes = true, Properties = false, SourceFormat = false}
MainTab:Toggle({Title = "Dump Children Tree", Flag = "DumpChildren", Default = true, Callback = function(v) DumpOptions.Children = v end})
MainTab:Toggle({Title = "Dump Attributes", Flag = "DumpAttributes", Default = true, Callback = function(v) DumpOptions.Attributes = v end})
MainTab:Toggle({Title = "Dump Part / Humanoid Properties", Flag = "DumpProperties", Default = false, Callback = function(v) DumpOptions.Properties = v end})
MainTab:Toggle({Title = "Source Code Format", Flag = "SourceFormat", Default = false, Callback = function(v) DumpOptions.SourceFormat = v end})
MainTab:Space()
local DumpFileName = ""
MainTab:Input({Title = "File Name (optional)", Placeholder = "leave empty for auto name", Callback = function(v) DumpFileName = trim(v) end})
local DumpStatus = MainTab:Paragraph({Title = "Status", Desc = "Ready to dump. Select target and press Dump."})

local function literal(value)
    local kind = typeof(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    if kind == "nil" then return "nil" end
    if kind == "Vector3" then return string.format("Vector3.new(%s, %s, %s)", value.X, value.Y, value.Z) end
    if kind == "Vector2" then return string.format("Vector2.new(%s, %s)", value.X, value.Y) end
    if kind == "Color3" then return string.format("Color3.new(%s, %s, %s)", value.R, value.G, value.B) end
    if kind == "CFrame" then
        local values = {value:GetComponents()}
        for i, n in ipairs(values) do values[i] = tostring(n) end
        return "CFrame.new(" .. table.concat(values, ", ") .. ")"
    end
    if kind == "EnumItem" then return tostring(value) end
    if kind == "Instance" then return string.format("%q", value:GetFullName()) end
    return string.format("%q", tostring(value))
end

local function resolveServiceTarget()
    local serviceName = TargetServiceDropdown.Value and TargetServiceDropdown.Value.Title or "ReplicatedStorage"
    local ok, target = pcall(function() return game:GetService(serviceName) end)
    if not ok then return nil, serviceName end
    if DumpSubPath ~= "" then
        for part in DumpSubPath:gmatch("[^/]+") do
            target = target and target:FindFirstChild(part)
            if not target then break end
        end
    end
    return target, serviceName
end

local function dumpObject(root)
    local lines = {}
    lines[#lines + 1] = "Valen Hub Dump"
    lines[#lines + 1] = "Root: " .. root:GetFullName()
    lines[#lines + 1] = "Class: " .. root.ClassName
    local objects = {root}
    if DumpOptions.Children then
        for _, object in ipairs(root:GetDescendants()) do objects[#objects + 1] = object end
    end
    for _, object in ipairs(objects) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "[" .. object.ClassName .. "] " .. object:GetFullName()
        if DumpOptions.Attributes then
            local ok, attributes = pcall(function() return object:GetAttributes() end)
            if ok then
                for key, value in pairs(attributes) do
                    lines[#lines + 1] = "  @" .. tostring(key) .. " = " .. literal(value)
                end
            end
        end
        if DumpOptions.Properties then
            for _, property in ipairs(PROPERTY_NAMES) do
                local ok, value = safeProperty(object, property)
                if ok then lines[#lines + 1] = "  ." .. property .. " = " .. literal(value) end
            end
        end
    end
    if DumpOptions.SourceFormat then
        local source = {"-- Valen Hub source-format dump", "local dump = {}"}
        for _, object in ipairs(objects) do
            source[#source + 1] = string.format("dump[%q] = {ClassName=%q, Name=%q}", object:GetFullName(), object.ClassName, object.Name)
        end
        source[#source + 1] = "return dump"
        return table.concat(source, "\n")
    end
    return table.concat(lines, "\n")
end

local LastDumpData = nil
local LastDumpPath = nil

PreviewTab:Paragraph({
    Title = "ตัวอย่างข้อมูลที่ Dump",
    Desc = "แท็บนี้แสดงตัวอย่างข้อมูลที่ Dump มาจากแท็บ Main และแสดง Log ของ Remote Spy (ถ้าเปิดใช้งาน)",
})
PreviewCode = PreviewTab:Code({Title = "Dump Preview", Code = "-- ยังไม่มีข้อมูล ไปที่แท็บ Main แล้วกด Dump"})
local SpyPreviewCode = PreviewTab:Code({Title = "Live Spy Log (last 50 calls)", Code = "-- Enable Remote Spy and play the game to see logs here..."})

local function performDump(saveToFile, showPreview)
    local target, serviceName = resolveServiceTarget()
    if not target then
        WindUI:Notify({Title = "Status", Desc = "Target not found: " .. tostring(serviceName)})
        return
    end
    local ok, data = pcall(dumpObject, target)
    if not ok then
        WindUI:Notify({Title = "Status", Desc = "Dump failed: " .. tostring(data)})
        return
    end
    LastDumpData = data
    if showPreview and PreviewCode then PreviewCode:SetCode(data) end
    if saveToFile then
        safeFolder(DUMP_FOLDER)
        safeFolder(DUMP_FOLDER .. "/Dump")
        local name = DumpFileName ~= "" and DumpFileName or (serviceName .. "_" .. os.date("%Y%m%d_%H%M%S"))
        name = name:gsub("[^%w_%- ]", "_")
        local ext = DumpOptions.SourceFormat and ".lua" or ".txt"
        LastDumpPath = DUMP_FOLDER .. "/Dump/" .. name .. ext
        if type(writefile) == "function" then pcall(writefile, LastDumpPath, data) end
        DumpStatus:SetDesc("Saved: " .. LastDumpPath)
        WindUI:Notify({Title = "Status", Desc = "Saved dump to " .. LastDumpPath})
    end
end

MainTab:Button({Title = "Dump ลงไฟล์", Desc = "ดึงข้อมูลและบันทึกเป็นไฟล์ใน executor workspace", Callback = function() task.spawn(function() performDump(true, false) end) end})
MainTab:Button({Title = "Dump และดูตัวอย่าง", Desc = "ดึงข้อมูลและแสดงตัวอย่างในแท็บ Preview", Callback = function() task.spawn(function() performDump(false, true) end) end})
MainTab:Button({Title = "Open Dumps Folder", Callback = function()
    if LastDumpPath then WindUI:Notify({Title = "Status", Desc = LastDumpPath}) else WindUI:Notify({Title = "Status", Desc = "No dump saved yet. Press Dump to File first."}) end
end})
PreviewTab:Button({Title = "Refresh Preview", Callback = function()
    PreviewCode:SetCode(LastDumpData or "No dump data. Press Dump and Preview first.")
end})
PreviewTab:Button({Title = "Copy Last File Path", Callback = function()
    if LastDumpPath and type(setclipboard) == "function" then setclipboard(LastDumpPath) else WindUI:Notify({Title = "Preview", Desc = "No file saved yet."}) end
end})

RemoteSpyTab:Paragraph({
    Title = "Remote Spy - ดักจับ Remote",
    Desc = "แท็บนี้ใช้ดักจับการเรียก RemoteEvent/RemoteFunction ทุกครั้งที่เกมส่งข้อมูลไป Server เหมาะสำหรับหาวิธีทำงานของเกมและหา Exploit vector",
})
local SpyStatus = RemoteSpyTab:Paragraph({Title = "Status", Desc = "Logging is off. Turn it on, then use the game normally."})
local SpySkipText = "sync,update,heartbeat,tick,ping,replicate,stream,position,character,camera,move,cframe"
RemoteSpyTab:Input({
    Title = "Skip remotes containing (comma separated)",
    Placeholder = "sync, heartbeat, position...",
    Value = SpySkipText,
    Callback = function(v) SpySkipText = tostring(v or "") end,
})

local SpyEnabled = false
local SpyCalls = {}
local SpyFileName = ""
local OldNamecall

local function shouldSkipRemote(name)
    name = tostring(name or ""):lower()
    for term in SpySkipText:gmatch("[^,%s]+") do
        if term ~= "" and name:find(term:lower(), 1, true) then return true end
    end
    return false
end

local function formatRemoteCall(remote, method, args)
    local parts = {}
    for i = 1, args.n or #args do parts[#parts + 1] = literal(args[i]) end
    return string.format("%s:%s(%s)", remote:GetFullName(), method, table.concat(parts, ", "))
end

local function addSpyCall(remote, method, args)
    if not SpyEnabled or shouldSkipRemote(remote.Name) then return end
    local entry = {
        Remote = remote,
        Method = method,
        Args = args,
        Time = os.time(),
        Source = formatRemoteCall(remote, method, args),
    }
    SpyCalls[#SpyCalls + 1] = entry
    while #SpyCalls > 200 do table.remove(SpyCalls, 1) end
    SpyStatus:SetDesc("Logging active. Calls captured: " .. tostring(#SpyCalls))
    local lines = {}
    local first = math.max(1, #SpyCalls - 49)
    for i = first, #SpyCalls do lines[#lines + 1] = SpyCalls[i].Source end
    SpyPreviewCode:SetCode(table.concat(lines, "\n"))
end

local function hookRemote(remote)
    if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then return end
end

local function installRemoteSpy()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    for _, object in ipairs(ReplicatedStorage:GetDescendants()) do pcall(hookRemote, object) end
    ReplicatedStorage.DescendantAdded:Connect(function(object)
        if object:IsA("RemoteEvent") or object:IsA("RemoteFunction") then
            task.defer(function() hookRemote(object) end)
        end
    end)

    if not OldNamecall and type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if SpyEnabled and (method == "FireServer" or method == "InvokeServer") then
                local okRemote = pcall(function() return self:IsA("RemoteEvent") or self:IsA("RemoteFunction") end)
                if okRemote then addSpyCall(self, method, table.pack(...)) end
            end
            return OldNamecall(self, ...)
        end))
    end
end

RemoteSpyTab:Toggle({Title = "Enable Remote Spy", Flag = "SpyEnabled", Default = false, Callback = function(value)
    SpyEnabled = value
    if value then
        installRemoteSpy()
        SpyStatus:SetDesc("Logging active. Calls captured: " .. tostring(#SpyCalls))
        WindUI:Notify({Title = "Remote Spy", Desc = "Logging active. Play the game normally."})
    else
        SpyStatus:SetDesc("Logging is off. Turn it on, then use the game normally.")
    end
end})

task.spawn(function()
    while task.wait(1) do
        if SpyEnabled then SpyStatus:SetDesc("Logging active. Calls captured: " .. tostring(#SpyCalls) .. " | Queue: 0") end
    end
end)

RemoteSpyTab:Input({Title = "File Name (optional)", Placeholder = "leave empty for auto name", Callback = function(v) SpyFileName = trim(v) end})
RemoteSpyTab:Button({Title = "Save Log as Source Code", Callback = function()
    safeFolder(DUMP_FOLDER)
    safeFolder(DUMP_FOLDER .. "/RemoteSpy")
    local name = SpyFileName ~= "" and SpyFileName or ("RemoteSpy_" .. os.date("%Y%m%d_%H%M%S"))
    name = name:gsub("[^%w_%- ]", "_")
    local path = DUMP_FOLDER .. "/RemoteSpy/" .. name .. ".lua"
    local lines = {
        "-- Remote Spy log",
        "-- Game: " .. tostring(game.PlaceId),
        "-- Time: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "-- Total captured: " .. tostring(#SpyCalls),
        "",
    }
    for _, entry in ipairs(SpyCalls) do lines[#lines + 1] = entry.Source end
    if type(writefile) == "function" then pcall(writefile, path, table.concat(lines, "\n")) end
    WindUI:Notify({Title = "Status", Desc = "Saved " .. tostring(#SpyCalls) .. " calls to " .. path})
end})
RemoteSpyTab:Button({Title = "Clear Log", Callback = function()
    SpyCalls = {}
    SpyPreviewCode:SetCode("")
    WindUI:Notify({Title = "Status", Desc = "Log cleared."})
end})

MapTab:Paragraph({
    Title = "Map Dump",
    Desc = "แท็บนี้ใช้ดึงข้อมูลแมพ (Workspace) ออกมาเป็นไฟล์ .rbxlx หรือสคริปต์ Lua ที่นำไปวางใน Roblox Studio ได้เลย",
})
MapTab:Space()
local MapFolderName = "ValenHub_Map"
local MapIncludeTerrain = false
local MapIncludeScripts = false
local MapIncludeCharacters = false
local LastMapScript = nil
MapTab:Input({Title = "Folder Name", Placeholder = "ValenHub_Map", Value = "ValenHub_Map", Callback = function(v) MapFolderName = trim(v) end})
MapTab:Toggle({Title = "Include Terrain", Flag = "MapIncludeTerrain", Default = false, Callback = function(v) MapIncludeTerrain = v end})
MapTab:Toggle({Title = "Include Scripts", Flag = "MapIncludeScripts", Default = false, Callback = function(v) MapIncludeScripts = v end})
MapTab:Toggle({Title = "Include Characters (Humanoid, Animator)", Flag = "MapIncludeCharacters", Default = false, Callback = function(v) MapIncludeCharacters = v end})
MapTab:Space()

local function validMapObject(object)
    if not MapIncludeCharacters and (object:IsA("Humanoid") or object:IsA("Animator")) then return false end
    if not MapIncludeScripts and (object:IsA("LuaSourceContainer") or object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript")) then return false end
    if not MapIncludeTerrain and object == workspace.Terrain then return false end
    return true
end

local function generateMapScript()
    local lines = {
        "-- Valen Hub map dump",
        "-- PlaceId: " .. tostring(game.PlaceId),
        "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "local root = Instance.new(\"Folder\")",
        "root.Name = " .. string.format("%q", MapFolderName ~= "" and MapFolderName or "ValenHub_Map"),
        "root.Parent = workspace",
        "local refs = {}",
    }
    local objects = {}
    for _, object in ipairs(workspace:GetDescendants()) do
        if validMapObject(object) then objects[#objects + 1] = object end
    end
    for index, object in ipairs(objects) do
        lines[#lines + 1] = string.format("refs[%d] = Instance.new(%q)", index, object.ClassName)
        lines[#lines + 1] = string.format("refs[%d].Name = %q", index, object.Name)
        for _, property in ipairs(PROPERTY_NAMES) do
            local ok, value = safeProperty(object, property)
            if ok and property ~= "Parent" then
                local encoded = literal(value)
                lines[#lines + 1] = string.format("pcall(function() refs[%d][%q] = %s end)", index, property, encoded)
            end
        end
        if MapIncludeScripts and object:IsA("LuaSourceContainer") then
            local ok, source = pcall(function() return object.Source end)
            if ok then lines[#lines + 1] = string.format("pcall(function() refs[%d].Source = %q end)", index, source) end
        end
        lines[#lines + 1] = string.format("refs[%d].Parent = root", index)
    end
    lines[#lines + 1] = "return root"
    return table.concat(lines, "\n")
end

MapTab:Button({Title = "Save as Studio File (.rbxlx)", Callback = function()
    if type(saveinstance) == "function" then
        local ok, err = pcall(function() saveinstance({FileName = MapFolderName, Mode = "optimized"}) end)
        if ok then WindUI:Notify({Title = "Map Dump", Desc = "Studio file saved."}) else WindUI:Notify({Title = "Map Dump", Desc = "Failed: " .. tostring(err)}) end
    else
        WindUI:Notify({Title = "Map Dump", Desc = "saveinstance() not supported. Use Copy to Clipboard instead."})
    end
end})

MapTab:Button({Title = "Dump Map & Copy to Clipboard", Callback = function()
    task.spawn(function()
        WindUI:Notify({Title = "Map Dump", Desc = "Scanning workspace... This may take a moment."})
        local ok, result = pcall(generateMapScript)
        if not ok then WindUI:Notify({Title = "Map Dump", Desc = "Failed: " .. tostring(result)}); return end
        LastMapScript = result
        if type(setclipboard) == "function" then setclipboard(result) end
        safeFolder(DUMP_FOLDER)
        safeFolder(DUMP_FOLDER .. "/Map")
        if type(writefile) == "function" then pcall(writefile, DUMP_FOLDER .. "/Map/" .. (MapFolderName ~= "" and MapFolderName or "ValenHub_Map") .. ".lua", result) end
        WindUI:Notify({Title = "Map Dump", Desc = "Map script copied to clipboard."})
    end)
end})

MapTab:Button({Title = "Copy Last Script to Clipboard", Callback = function()
    if LastMapScript and type(setclipboard) == "function" then
        setclipboard(LastMapScript)
    else
        WindUI:Notify({Title = "Map Dump", Desc = "No script generated yet. Press Dump Map first."})
    end
end})

MapTab:Space()
MapTab:Paragraph({
    Title = "How to use",
    Desc = "EASIEST: Press \"Save as Studio File (.rbxlx)\" then open the file in Studio directly.\nIf saveinstance() is unavailable, use Dump Map & Copy to Clipboard.",
})
MapTab:Paragraph({
    Title = "Info",
    Desc = "Valen Hub - Universal Game Dump\nMap / service dump tools recovered from the protected client.",
})

SettingsTab:Space()
SettingsTab:Paragraph({Title = "Appearance", Desc = "Change the look of Valen Hub instantly."})
local Themes = {{Title="Dark"}, {Title="Light"}, {Title="Rose"}, {Title="Plant"}, {Title="Indigo"}, {Title="Sky"}, {Title="Violet"}, {Title="Amber"}}
local CurrentTheme = AppConfig.Theme or "Dark"
SettingsTab:Dropdown({
    Title = "Select Theme",
    Values = Themes,
    Value = {Title = CurrentTheme},
    Callback = function(value)
        local theme = type(value) == "table" and value.Title or tostring(value)
        CurrentTheme = theme
        WindUI:SetTheme(theme)
        AppConfig.Theme = theme
        saveJsonFile(CONFIG_FILE, AppConfig)
        WindUI:Notify({Title = "Theme Changed", Desc = "Switched to \"" .. theme .. "\" theme."})
    end,
})
SettingsTab:Space()
SettingsTab:Button({Title = "Save Settings Now", Callback = function()
    AppConfig.Theme = CurrentTheme
    saveJsonFile(CONFIG_FILE, AppConfig)
    WindUI:Notify({Title = "Settings Saved", Desc = "Theme & Background saved to config."})
end})

local ConfigName = "default"
SettingsTab:Input({Title = "Config Name", Placeholder = "default", Callback = function(v) ConfigName = trim(v) ~= "" and trim(v) or "default" end})
SettingsTab:Button({Title = "Save Config", Callback = function()
    local config = Window.ConfigManager:Config(ConfigName)
    Window.CurrentConfig = config
    config:Save()
    WindUI:Notify({Title = "Config Saved", Desc = "Config '" .. ConfigName .. "' saved"})
end})
SettingsTab:Button({Title = "Load Config", Callback = function()
    Window.ConfigManager:CreateConfig(ConfigName):Load()
    WindUI:Notify({Title = "Config Loaded", Desc = "Config '" .. ConfigName .. "' loaded"})
end})
SettingsTab:Button({Title = "Destroy UI", Callback = function() Window:Destroy() end})

WindUI:Notify({Title = "Valen Hub Loaded", Desc = "Select a service and press Dump to File."})
