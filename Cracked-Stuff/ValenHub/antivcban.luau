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
