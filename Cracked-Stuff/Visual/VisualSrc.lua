-- luarmor cracked by intertia

local G = (getgenv and getgenv()) or _G

local function bootlog(...)
    pcall(print, "[I32 LOGS]", ...)
end

local function tb(err)
    local s = tostring(err)
    if debug and type(debug.traceback) == "function" then
        local ok, out = pcall(debug.traceback, s, 2)
        if ok then return out end
    end
    return s
end

bootlog("starting")
bootlog("original UI profile loaded")

for _, slot in ipairs({
    "I32A1",
    "I32A2",
    "I32A3",
    "I32A4",
    "I32A5",
}) do
    local old = rawget(G, slot)
    if type(old) == "table" and type(old.Destroy) == "function" then
        pcall(old.Destroy)
    end
end

bootlog("initializing engine") -- just cooler idk
local ok_engine, NativeRuntimeOrErr = xpcall(function()
local NativeRuntime = (function()

local ENV = (getgenv and getgenv()) or _G

local function log(...)
    if rawget(ENV, "I32A1_DEBUG") == true then
        pcall(print, "[I32 LOGS]", ...)
    end
end

local function safe(fn, fallback)
    local ok, value = pcall(fn)
    if ok then
        return value
    end
    return fallback
end

local function clean(v, maxlen)
    local ok, s = pcall(tostring, v)
    if not ok then s = "<error>" end
    s = tostring(s):gsub("[\r\n\t]", " ")
    maxlen = maxlen or 1600
    if #s > maxlen then
        s = s:sub(1, maxlen) .. "..."
    end
    return s
end

local function destroy_previous_runtime()
    local candidates = {}

    local function add_candidate(v)
        if type(v) == "table" then
            for _, existing in ipairs(candidates) do
                if existing == v then
                    return
                end
            end
            candidates[#candidates + 1] = v
        end
    end

    add_candidate(rawget(ENV, "I32_RUNTIME"))
    pcall(function()
        add_candidate(rawget(_G, "I32_RUNTIME"))
    end)
    pcall(function()
        if type(shared) == "table" then
            add_candidate(rawget(shared, "I32_RUNTIME"))
        end
    end)

    for _, previous in ipairs(candidates) do
        local destroy = rawget(previous, "Destroy")
        if type(destroy) == "function" then
            local ok, err = pcall(destroy)
            log("previous I32 cleanup", ok, err or "")
        end
    end
end

destroy_previous_runtime()

local function get_shared_fire_surface()
    local rs = game:GetService("ReplicatedStorage")
    for _, obj in ipairs(rs:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            return obj.FireServer
        end
    end
end

do
    local ishooked = rawget(ENV, "isfunctionhooked")
    if type(ishooked) == "function" then
        local fire = safe(get_shared_fire_surface)
        if type(fire) == "function" then
            local hooked = safe(function() return ishooked(fire) end, false)
            if hooked then
                error(
                    "[I32] RemoteEvent.FireServer is already hooked. " ..
                    "Use a clean session or restore the previous test hook first.",
                    0
                )
            end
        end
    end
end

local NativeHelpers = (function()

local NativeHelpers = {}
local SPEED_EPSILON = 0.001

local function is_live_instance(value)
    return value ~= nil and value.Parent ~= nil
end

local function find_child(instance, name)
    if instance == nil then
        return nil
    end
    return instance:FindFirstChild(name)
end

function NativeHelpers.new(config)
    config = config or {}

    local workspace_ref = config.workspace or workspace
    local local_player = config.local_player
    if local_player == nil then
        local players = game:GetService("Players")
        local_player = players.LocalPlayer
    end

    local balls_folder = config.balls_folder
    local position_resolver = config.position_resolver
    local ball_history = config.ball_history or {}
    local closest_player = config.closest_player
    local closest_entity_getter = config.closest_entity_getter
    local closest_entity = config.closest_entity

    local death_slash_active_getter = config.death_slash_active_getter
    local immortality_ui_resolver = config.immortality_ui_resolver

    local spam_scale_state_getter = config.spam_scale_state_getter

    local parry_remote = config.parry_remote
    local parry_hash = config.parry_hash
    local parry_token = config.parry_token
    local parry_time_key = config.parry_time_key

    local auto_resolve_parry = config.auto_resolve_parry ~= false
    local parry_time_search_window_cs =
        config.parry_time_search_window_cs or 200

    local parry_capture = {
        installed = false,
        active = false,
        ready =
            parry_remote ~= nil
            and type(parry_hash) == "string"
            and type(parry_token) == "string"
            and type(parry_time_key) == "string"
            and #parry_time_key > 0,
        observed_calls = 0,
        matched_calls = 0,
        captured_args = nil,
        captured_timestamp = nil,
        original_fire = nil,
        fire_surface = nil,
        error = nil,
    }

    local parry_data_builder = config.parry_data_builder

    local camera_aim_use_viewport_center =
        config.camera_aim_use_viewport_center == true

    local user_input_service =
        config.user_input_service or game:GetService("UserInputService")

    local data_ping = config.data_ping
    if data_ping == nil then
        pcall(function()
            local stats = game:GetService("Stats")
            data_ping = stats.Network.ServerStatsItem["Data Ping"]
        end)
    end

    local allow_direct_position_fallback =
        config.allow_direct_position_fallback == true

    local api = {}

    local function looks_like_uuid(value)
        return type(value) == "string"
            and value:match(
                "^[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+%-[0-9a-fA-F]+$"
            ) ~= nil
    end

    local function is_remote_event(value)
        return typeof(value) == "Instance"
            and value:IsA("RemoteEvent")
    end

    local function matches_parry_capture_packet(remote, args)
        if not is_remote_event(remote) then
            return false
        end

        if args.n < 8 then
            return false
        end

        if not looks_like_uuid(args[1]) then
            return false
        end

        if type(args[2]) ~= "string"
            or #args[2] < 1
            or #args[2] > 64
        then
            return false
        end

        if type(args[3]) ~= "string"
            or #args[3] < 1
            or #args[3] > 128
        then
            return false
        end

        return type(args[4]) == "number"
            and typeof(args[5]) == "CFrame"
            and type(args[6]) == "table"
            and type(args[7]) == "table"
            and args[8] == false
    end

    local function derive_parry_time_key(encoded_time, observed_server_time, token)
        if type(encoded_time) ~= "string"
            or type(observed_server_time) ~= "number"
            or type(token) ~= "string"
            or #token == 0
        then
            return nil, nil
        end

        local key_length = #token
        local base_cs = math.floor(observed_server_time * 100)

        local function try_timestamp(timestamp_cs)
            local timestamp = tostring(timestamp_cs)
            if #timestamp ~= #encoded_time then
                return nil
            end

            local key_bytes = table.create(key_length)

            for i = 1, #timestamp do
                local timestamp_byte = string.byte(timestamp, i)
                local encoded_byte = string.byte(encoded_time, i)
                local adjusted = (timestamp_byte + i) % 256
                local key_byte = bit32.bxor(adjusted, encoded_byte)
                local key_index = ((i - 1) % key_length) + 1

                if key_bytes[key_index] == nil then
                    key_bytes[key_index] = key_byte
                elseif key_bytes[key_index] ~= key_byte then
                    return nil
                end
            end

            for i = 1, key_length do
                if key_bytes[i] == nil then
                    return nil
                end
            end

            return string.char(table.unpack(key_bytes)), timestamp
        end

        for radius = 0, parry_time_search_window_cs do
            local key, timestamp = try_timestamp(base_cs - radius)
            if key ~= nil then
                return key, timestamp
            end

            if radius ~= 0 then
                key, timestamp = try_timestamp(base_cs + radius)
                if key ~= nil then
                    return key, timestamp
                end
            end
        end

        return nil, nil
    end

    local function find_fire_server_surface()
        local roots = {
            game:GetService("ReplicatedStorage"),
            workspace_ref,
        }

        for _, root in roots do
            for _, object in root:GetDescendants() do
                if object:IsA("RemoteEvent") then
                    local fire = object.FireServer
                    if type(fire) == "function" then
                        return fire
                    end
                end
            end
        end

        return nil
    end

    local function install_parry_discovery()
        if parry_capture.ready
            or parry_capture.installed
            or not auto_resolve_parry
        then
            return parry_capture.ready
        end

        local hookfunction_ref = rawget((getgenv and getgenv()) or _G, "hookfunction")
        if type(hookfunction_ref) ~= "function" then
            parry_capture.error = "hookfunction unavailable"
            return false
        end

        local fire_surface = find_fire_server_surface()
        if type(fire_surface) ~= "function" then
            parry_capture.error = "RemoteEvent.FireServer surface unavailable"
            return false
        end

        local environment = (getgenv and getgenv()) or _G
        local isfunctionhooked_ref = rawget(environment, "isfunctionhooked")
        if type(isfunctionhooked_ref) == "function"
            and isfunctionhooked_ref(fire_surface)
        then
            parry_capture.error =
                "RemoteEvent.FireServer is already hooked; " ..
                "native discovery expects a clean standalone session"
            return false
        end

        local old_fire
        old_fire = hookfunction_ref(fire_surface, function(self, ...)
            if parry_capture.active then
                parry_capture.observed_calls += 1

                local args = table.pack(...)
                if matches_parry_capture_packet(self, args) then
                    parry_capture.matched_calls += 1

                    local observed_server_time =
                        workspace_ref:GetServerTimeNow()
                    local recovered_key, recovered_timestamp =
                        derive_parry_time_key(
                            args[3],
                            observed_server_time,
                            args[2]
                        )

                    parry_remote = self
                    parry_hash = args[1]
                    parry_token = args[2]
                    parry_capture.captured_args = args

                    if recovered_key ~= nil then
                        parry_time_key = recovered_key
                        parry_capture.captured_timestamp = recovered_timestamp
                        parry_capture.ready = true
                        parry_capture.active = false
                        parry_capture.error = nil
                    else
                        parry_capture.error =
                            "matched parry packet but could not derive time key"
                    end
                end
            end

            return old_fire(self, ...)
        end)

        parry_capture.original_fire = old_fire
        parry_capture.fire_surface = fire_surface
        parry_capture.installed = true
        parry_capture.active = true
        parry_capture.error = nil

        return true
    end

    local function refresh_parry_capture_ready()
        parry_capture.ready =
            parry_remote ~= nil
            and type(parry_hash) == "string"
            and type(parry_token) == "string"
            and type(parry_time_key) == "string"
            and #parry_time_key > 0

        if parry_capture.ready then
            parry_capture.active = false
        end

        return parry_capture.ready
    end

    local function get_balls_folder()
        if not is_live_instance(balls_folder) then
            balls_folder = workspace_ref:FindFirstChild("Balls")
        end
        return balls_folder
    end

    local function get_zoomies_if_real(ball)
        if ball == nil then
            return nil
        end

        if not ball:GetAttribute("realBall") then
            return nil
        end

        return ball:FindFirstChild("zoomies")
    end

    local function resolve_ball_position(ball)
        if position_resolver ~= nil then
            return position_resolver(ball)
        end

        return ball.Position
    end

    function api.Get_Balls(collect_all)
        local container = get_balls_folder()

        if container == nil then
            if collect_all then
                return {}
            end
            return nil
        end

        if collect_all then
            local result = {}

            for _, ball in container:GetChildren() do
                if get_zoomies_if_real(ball) ~= nil then
                    table.insert(result, ball)
                end
            end

            return result
        end

        for _, ball in container:GetChildren() do
            if get_zoomies_if_real(ball) ~= nil then
                return ball
            end
        end

        return nil
    end

    function api.Get_Targeting_Balls(collect_all)
        local container = get_balls_folder()

        if container == nil or local_player == nil then
            if collect_all then
                return {}
            end
            return nil
        end

        local target_name = local_player.Name

        if collect_all then
            local result = {}

            for _, ball in container:GetChildren() do
                local zoomies = get_zoomies_if_real(ball)

                if zoomies ~= nil
                    and ball:GetAttribute("target") == target_name
                then
                    table.insert(result, ball)
                end
            end

            return result
        end

        local character = local_player.Character
        local primary_part = character and character.PrimaryPart

        if primary_part == nil then
            return nil
        end

        local player_position = primary_part.Position
        local best_ball = nil
        local best_eta = math.huge

        for _, ball in container:GetChildren() do
            local zoomies = get_zoomies_if_real(ball)

            if zoomies ~= nil
                and ball:GetAttribute("target") == target_name
            then
                local velocity = zoomies.VectorVelocity
                local speed = velocity.Magnitude

                if speed > SPEED_EPSILON then
                    local ball_position = resolve_ball_position(ball)

                    local distance = (player_position - ball_position).Magnitude
                    local eta = distance / speed

                    if eta < best_eta then
                        best_eta = eta
                        best_ball = ball
                    end
                end
            end
        end

        return best_ball
    end

    function api.Get_Ball_Properties(ball)
        if ball == nil then
            return false
        end

        local zoomies = ball:FindFirstChild("zoomies")
        if zoomies == nil then
            return false
        end

        local velocity = zoomies.VectorVelocity
        local speed = velocity.Magnitude

        local character = local_player and local_player.Character
        local primary_part = character and character.PrimaryPart
        if primary_part == nil then
            return false
        end

        local player_position = primary_part.Position
        local current_position = resolve_ball_position(ball)

        local history = ball_history[ball]
        if history == nil then
            history = {
                Last_Position = nil,
                Last_Time = nil,
                Predicted_Velocity = Vector3.new(0, 0, 0),
            }
            ball_history[ball] = history
        end

        local now = os.clock()
        local last_position = history.Last_Position
        local last_time = history.Last_Time

        if last_position ~= nil and last_time ~= nil then
            local dt = now - last_time

            if dt > 0 and dt < 0.1 then
                local measured_velocity = (current_position - last_position) / dt
                local predicted_velocity =
                    history.Predicted_Velocity or Vector3.new(0, 0, 0)

                local ping_ms = 0
                if data_ping ~= nil then
                    ping_ms = data_ping:GetValue()
                end

                local alpha = math.clamp(ping_ms / 200, 0.4, 0.85)
                predicted_velocity =
                    predicted_velocity
                    + (measured_velocity - predicted_velocity) * alpha

                history.Predicted_Velocity = predicted_velocity
            end
        end

        history.Last_Position = current_position
        history.Last_Time = now

        local ping_ms = 0
        if data_ping ~= nil then
            ping_ms = data_ping:GetValue()
        end

        local lead_time = math.clamp(
            ping_ms / 1000 + 0.05,
            0.05,
            0.15
        )

        local predicted_velocity =
            history.Predicted_Velocity or Vector3.new(0, 0, 0)

        local predicted_position =
            current_position + predicted_velocity * lead_time

        local delta = player_position - predicted_position
        local distance = delta.Magnitude

        local direction
        if distance > SPEED_EPSILON then
            direction = delta / distance
        else
            direction = Vector3.new(0, 0, 0)
        end

        local dot = 0
        if speed > 0 then
            dot = velocity:Dot(direction) / speed
        end

        return {
            Speed = speed,
            Velocity = velocity,
            Direction = direction,
            Distance = distance,
            Dot = dot,
            Predicted_Position = predicted_position,
        }
    end

    function api.Closest_Player()
        local alive = workspace_ref:FindFirstChild("Alive")
        local character = local_player and local_player.Character

        if alive == nil or character == nil then
            closest_entity = nil
            return false
        end

        local local_root = character:FindFirstChild("HumanoidRootPart")
        if local_root == nil then
            closest_entity = nil
            return false
        end

        local local_position = local_root.Position
        local local_name = local_player.Name

        local best_distance = math.huge
        local best_character = nil

        for _, candidate in alive:GetChildren() do
            if candidate.Name ~= local_name then
                local primary_part = candidate.PrimaryPart

                if primary_part ~= nil then
                    local delta = local_position - primary_part.Position
                    local distance = delta.Magnitude

                    if distance < best_distance then
                        best_distance = distance
                        best_character = candidate
                    end
                end
            end
        end

        closest_entity = best_character
        return best_character
    end

    function api.Get_Entity_Properties()
        local returned_target
        if closest_player ~= nil then
            returned_target = closest_player()
        else
            returned_target = api.Closest_Player()
        end

        if returned_target ~= nil and returned_target ~= false then
            closest_entity = returned_target
        end

        if closest_entity_getter ~= nil then
            closest_entity = closest_entity_getter()
        end

        local target = closest_entity
        if target == nil then
            return false
        end

        local target_primary = target.PrimaryPart
        if target_primary == nil then
            return false
        end

        local character = local_player and local_player.Character
        local local_primary = character and character.PrimaryPart
        if local_primary == nil then
            return false
        end

        local velocity = target_primary.AssemblyLinearVelocity
        local delta = local_primary.Position - target_primary.Position
        local distance = delta.Magnitude

        local direction
        if distance > 0 then
            direction = delta.Unit
        else
            direction = Vector3.new(0, 0, 0)
        end

        return {
            Velocity = velocity,
            Direction = direction,
            Distance = distance,
        }
    end


    local IMMORTALITY_ABILITY_NAMES = {
        "Infinity",
        "Time Hole",
        "Death Slash",
        "Slashes of Fury",
        "Singularity",
        "Forcefield",
        "Invisibility",
    }

    function api.Player_Has_Immortality()
        local character = local_player and local_player.Character
        if character == nil then
            return false, nil
        end

        local primary_part = character.PrimaryPart
        if primary_part == nil then
            return false, nil
        end

        if primary_part:FindFirstChild("SingularityCape") ~= nil then
            return true, "Singularity"
        end

        if death_slash_active_getter ~= nil then
            local ok, active = pcall(death_slash_active_getter)
            if ok and active then
                return true, "DeathSlash"
            end
        end

        if character:GetAttribute("IsInvisible") then
            return true, "Invisibility"
        end

        local abilities = character:FindFirstChild("Abilities")
        if abilities ~= nil then
            for _, name in IMMORTALITY_ABILITY_NAMES do
                if abilities:FindFirstChild(name) ~= nil then
                    return true, name
                end
            end
        end

        if immortality_ui_resolver ~= nil then
            local ok, active, reason = pcall(immortality_ui_resolver, character)
            if ok and active then
                return true, reason
            end
        end

        return false, nil
    end

    function api.Spam_Service(data)
        if data == nil then
            return 0
        end

        local ball = data.Ball
        if ball == nil then
            return 0
        end

        local zoomies = ball:FindFirstChild("zoomies")
        if zoomies == nil then
            return 0
        end

        local speed = zoomies.VectorVelocity.Magnitude

        local ping = data.Ping or 0
        local ping_base
        if ping >= 100 then
            ping_base = 17
        else
            ping_base = 10
        end

        local spam_state = 1
        if spam_scale_state_getter ~= nil then
            local ok, value = pcall(spam_scale_state_getter)
            if ok and type(value) == "number" then
                spam_state = value
            end
        end

        local scale = (3 - spam_state) * 0.15

        local range =
            (ping_base + math.min(speed * 0.125, 75))
            * scale

        if range < 2 then
            range = 2
        end

        local ball_properties = data.Ball_Properties
        if ball_properties == nil then
            return 0
        end

        local dot = ball_properties.Dot
        if type(dot) ~= "number" then
            return 0
        end

        local direction_penalty =
            math.clamp(dot, -1, 0)
            * (5 - math.min(speed * 0.2, 5))

        range = range - direction_penalty

        local ball_distance = ball_properties.Distance
        if type(ball_distance) ~= "number" then
            return 0
        end

        local entity_properties = data.Entity_Properties
        if entity_properties == nil then
            return 0
        end

        local entity_distance = entity_properties.Distance
        if type(entity_distance) ~= "number" then
            return 0
        end

        if ball_distance > range then
            return 0
        end

        if entity_distance > range * 2.5 then
            return 0
        end

        return range
    end

    function api.Parry_Data_Camera()
        local camera = workspace_ref.CurrentCamera
        if camera == nil then
            return nil
        end

        local alive = workspace_ref:FindFirstChild("Alive")
        if alive == nil then
            return nil
        end

        local screen_positions = {}

        for _, character in alive:GetChildren() do
            local primary_part = character.PrimaryPart

            if primary_part ~= nil then
                local screen_position =
                    camera:WorldToScreenPoint(primary_part.Position)

                screen_positions[character.Name] =
                    screen_position
            end
        end

        local camera_cframe = camera.CFrame
        local camera_position = camera_cframe.Position

        local aim_cframe =
            CFrame.new(
                camera_position,
                camera_position + camera_cframe.LookVector
            )

        local aim_2d

        if camera_aim_use_viewport_center then
            local viewport = camera.ViewportSize

            aim_2d = {
                viewport.X * 0.5,
                viewport.Y * 0.5,
            }
        else
            local mouse =
                user_input_service:GetMouseLocation()

            aim_2d = {
                mouse.X,
                mouse.Y,
            }
        end

        return {
            0,
            aim_cframe,
            screen_positions,
            aim_2d,
        }
    end

    function api.Parry_Data(parry_type)
        if parry_type == "Camera" then
            return api.Parry_Data_Camera()
        end

        if parry_data_builder ~= nil then
            return parry_data_builder(parry_type)
        end

        error(
            "native Parry_Data currently supports Camera; " ..
            "other parry types are not migrated yet",
            2
        )
    end

    function api.Encode_Parry_Time(server_time)
        local now = server_time
        if now == nil then
            now = workspace_ref:GetServerTimeNow()
        end

        local timestamp =
            tostring(math.floor(now * 100))

        local key_length = #parry_time_key
        assert(key_length > 0, "parry time key cannot be empty")

        local encoded = table.create(#timestamp)

        for i = 1, #timestamp do
            local timestamp_byte = string.byte(timestamp, i)
            local adjusted_byte = (timestamp_byte + i) % 256

            local key_index =
                ((i - 1) % key_length) + 1
            local key_byte =
                string.byte(parry_time_key, key_index)

            encoded[i] =
                string.char(bit32.bxor(adjusted_byte, key_byte))
        end

        return table.concat(encoded), timestamp
    end

    function api.Build_Parry_Args(parry_data, server_time)
        assert(type(parry_data) == "table", "parry_data must be a table")
        assert(type(parry_hash) == "string", "Parry_Hash is not resolved")
        assert(type(parry_token) == "string", "parry token is not resolved")
        assert(
            type(parry_time_key) == "string" and #parry_time_key > 0,
            "parry time key is not resolved; perform one manual parry first"
        )

        local encoded_time =
            api.Encode_Parry_Time(server_time)

        return {
            parry_hash,
            parry_token,
            encoded_time,
            parry_data[1],
            parry_data[2],
            parry_data[3],
            parry_data[4],
            false,
        }
    end
    function api.Parry_From_Data(parry_data, server_time)
        assert(
            parry_remote ~= nil,
            "Parry_Remote is not resolved; perform one manual parry first"
        )

        local args =
            api.Build_Parry_Args(parry_data, server_time)

        parry_remote:FireServer(
            args[1],
            args[2],
            args[3],
            args[4],
            args[5],
            args[6],
            args[7],
            args[8]
        )

        return args
    end

    function api.Parry(input, server_time)
        if type(input) == "table"
            and (
                input[1] ~= nil
                or input[2] ~= nil
                or input[3] ~= nil
                or input[4] ~= nil
            )
        then
            return api.Parry_From_Data(input, server_time)
        end

        local parry_data =
            api.Parry_Data(input)

        if parry_data == nil then
            return nil
        end

        return api.Parry_From_Data(parry_data, server_time)
    end

    function api.Set_Parry_Remote(remote)
        assert(
            remote == nil or is_remote_event(remote),
            "parry remote must be a RemoteEvent or nil"
        )
        parry_remote = remote
        refresh_parry_capture_ready()
    end

    function api.Set_Parry_Data_Builder(fn)
        assert(fn == nil or type(fn) == "function", "parry data builder must be function or nil")
        parry_data_builder = fn
    end

    function api.Set_Parry_Time_Key(key)
        assert(type(key) == "string" and #key > 0, "parry time key must be a non-empty string")
        parry_time_key = key
        refresh_parry_capture_ready()
    end

    function api.Set_Parry_Identity(hash, token)
        if hash ~= nil then
            assert(type(hash) == "string", "parry hash must be a string")
            parry_hash = hash
        end

        if token ~= nil then
            assert(type(token) == "string", "parry token must be a string")
            parry_token = token
        end

        refresh_parry_capture_ready()
    end

    function api.Start_Parry_Discovery()
        return install_parry_discovery()
    end

    function api.Is_Parry_Ready()
        return refresh_parry_capture_ready()
    end

    function api.Get_Parry_Discovery_Status()
        return {
            installed = parry_capture.installed,
            active = parry_capture.active,
            ready = refresh_parry_capture_ready(),
            error = parry_capture.error,
            observed_calls = parry_capture.observed_calls,
            matched_calls = parry_capture.matched_calls,
            remote = parry_remote,
            hash = parry_hash,
            token = parry_token,
            time_key = parry_time_key,
            captured_timestamp = parry_capture.captured_timestamp,
            captured_args = parry_capture.captured_args,
        }
    end

    function api.Restore_Parry_Discovery_Hook()
        if not parry_capture.installed then
            return true
        end

        local environment = (getgenv and getgenv()) or _G
        local restorefunction_ref = rawget(environment, "restorefunction")
        if type(restorefunction_ref) ~= "function" then
            return false, "restorefunction unavailable"
        end

        local ok, err = pcall(restorefunction_ref, parry_capture.fire_surface)
        if not ok then
            return false, err
        end

        parry_capture.installed = false
        parry_capture.active = false
        return true
    end

    function api.Set_Immortality_Resolvers(death_slash_getter, ui_resolver)
        assert(
            death_slash_getter == nil or type(death_slash_getter) == "function",
            "death_slash_getter must be function or nil"
        )
        assert(
            ui_resolver == nil or type(ui_resolver) == "function",
            "ui_resolver must be function or nil"
        )

        death_slash_active_getter = death_slash_getter
        immortality_ui_resolver = ui_resolver
    end

    function api.Set_Spam_Scale_State_Getter(fn)
        assert(fn == nil or type(fn) == "function", "spam scale getter must be function or nil")
        spam_scale_state_getter = fn
    end

    function api.Set_Closest_Player(fn, getter)
        assert(fn == nil or type(fn) == "function", "closest_player must be function or nil")
        assert(getter == nil or type(getter) == "function", "closest_entity_getter must be function or nil")
        closest_player = fn
        closest_entity_getter = getter
    end

    function api.Set_Closest_Entity(entity)
        closest_entity = entity
    end

    function api.Set_Position_Resolver(fn)
        assert(fn == nil or type(fn) == "function", "position resolver must be function or nil")
        position_resolver = fn
    end

    function api.Set_Balls_Folder(folder)
        balls_folder = folder
    end

    function api.Get_Balls_Folder()
        return get_balls_folder()
    end

    function api.Get_Status()
        return {
            version = "I32",
            speed_epsilon = SPEED_EPSILON,
            balls_folder = balls_folder,
            local_player = local_player,
            has_position_resolver = position_resolver ~= nil,
            direct_position_fallback = allow_direct_position_fallback,
            exact_native = {
                Get_Balls = true,
                Get_Targeting_Balls_filters = true,
                Get_Targeting_Balls_eta_selection = true,
                Get_Ball_Properties_gameplay_dataflow = true,
                Get_Entity_Properties_gameplay_dataflow = true,
                Closest_Player_gameplay_dataflow = true,
                Spam_Service_gameplay_dataflow = true,
                Player_Has_Immortality_direct_checks = true,
                Parry_Remote_discovery = true,
                Parry_identity_capture = true,
                Parry_time_key_recovery = true,
            },
            parry_discovery = {
                installed = parry_capture.installed,
                active = parry_capture.active,
                ready = refresh_parry_capture_ready(),
                error = parry_capture.error,
                observed_calls = parry_capture.observed_calls,
                matched_calls = parry_capture.matched_calls,
                remote = parry_remote,
                hash = parry_hash,
                token = parry_token,
                captured_timestamp = parry_capture.captured_timestamp,
            },
            pending_dependency = {
                shared_position_resolver = position_resolver == nil,
                Player_Has_Immortality_Duration_UIGradient_branch =
                    immortality_ui_resolver == nil,
                manual_parry_capture = not refresh_parry_capture_ready(),
            },
        }
    end

    install_parry_discovery()

    return api
end

return NativeHelpers

end)()


local CONFIG = {
    enabled = false,
    parry_type = "Camera",

    min_incoming_dot = 0.00,

    base_distance = 8.0,
    speed_range_scale = 0.25,
    ping_range_scale = 0.025,
    min_distance = 12.0,
    max_distance = 95.0,

    global_cooldown_seconds = 0.12,
    respect_direct_immortality = true,

    diagnostic_interval_seconds = math.huge,
    log_state_changes = false,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local local_player = Players.LocalPlayer

local data_ping = nil
pcall(function()
    data_ping = Stats.Network.ServerStatsItem["Data Ping"]
end)

local api = NativeHelpers.new({
    auto_resolve_parry = true,
})

local runtime = {
    Version = "I32",
    Enabled = CONFIG.enabled,
    Ready = false,
    Destroyed = false,
    Api = api,
    Config = CONFIG,

    ParryCount = 0,
    LastParryClock = -math.huge,
    LastParryBall = nil,
    LastDecision = nil,

    Connection = nil,
    BallState = setmetatable({}, { __mode = "k" }),
}

local function set_global_runtime()
    ENV.I32_RUNTIME = runtime
    pcall(function() _G.I32_RUNTIME = runtime end)
    pcall(function()
        if type(shared) == "table" then
            shared.I32_RUNTIME = runtime
        end
    end)
end

set_global_runtime()

local function get_ping_ms()
    if data_ping == nil then
        return 0
    end

    local value = safe(function() return data_ping:GetValue() end, 0)
    if type(value) == "number" then
        return value
    end

    return tonumber(value) or 0
end

local function direct_active_immortality()
    local character = local_player and local_player.Character
    if character == nil then
        return false, nil
    end

    local primary_part = character.PrimaryPart
    if primary_part == nil then
        return false, nil
    end

    if primary_part:FindFirstChild("SingularityCape") ~= nil then
        return true, "SingularityCape"
    end

    if character:GetAttribute("IsInvisible") then
        return true, "IsInvisible"
    end

    return false, nil
end

local function first_ability_marker()
    local character = local_player and local_player.Character
    local abilities = character and character:FindFirstChild("Abilities")
    if abilities == nil then
        return nil
    end

    local names = {
        "Infinity",
        "Time Hole",
        "Death Slash",
        "Slashes of Fury",
        "Singularity",
        "Forcefield",
        "Invisibility",
    }

    for _, name in ipairs(names) do
        if abilities:FindFirstChild(name) ~= nil then
            return name
        end
    end

    return nil
end

local function refresh_ball_target_states()
    local local_name = local_player and local_player.Name
    if local_name == nil then
        return
    end

    local balls = api.Get_Balls(true)

    for _, ball in ipairs(balls) do
        local state = runtime.BallState[ball]
        if state == nil then
            state = {
                was_targeting_local = false,
                parried_this_target_event = false,
            }
            runtime.BallState[ball] = state
        end

        local targeting_local =
            ball:GetAttribute("target") == local_name

        if targeting_local then
            if not state.was_targeting_local then
                state.parried_this_target_event = false
            end
            state.was_targeting_local = true
        else
            state.was_targeting_local = false
            state.parried_this_target_event = false
        end
    end
end

local function compute_decision(ball, props)
    local ping_ms = get_ping_ms()
    local speed = props.Speed or 0
    local distance = props.Distance or math.huge
    local dot = props.Dot or -1

    if speed <= 0.001 then
        return false, {
            reason = "speed",
            ping_ms = ping_ms,
            speed = speed,
            distance = distance,
            dot = dot,
            parry_range = 0,
        }
    end

    local parry_range =
        CONFIG.base_distance
        + speed * CONFIG.speed_range_scale
        + ping_ms * CONFIG.ping_range_scale

    parry_range = math.clamp(
        parry_range,
        CONFIG.min_distance,
        CONFIG.max_distance
    )

    local incoming = dot >= CONFIG.min_incoming_dot
    local in_range = distance <= parry_range

    local eta = distance / speed

    return incoming and in_range, {
        reason =
            not incoming and "dot"
            or (not in_range and "distance" or "parry"),
        ping_ms = ping_ms,
        speed = speed,
        distance = distance,
        dot = dot,
        eta = eta,
        parry_range = parry_range,
    }
end

local function format_decision(d)
    return string.format(
        "dist=%.3f range=%.3f speed=%.3f dot=%.4f eta=%.4f ping=%.1f",
        tonumber(d.distance) or -1,
        tonumber(d.parry_range) or -1,
        tonumber(d.speed) or -1,
        tonumber(d.dot) or -1,
        tonumber(d.eta) or -1,
        tonumber(d.ping_ms) or -1
    )
end

local function restore_discovery_after_ready()
    local ok, a, b = pcall(function()
        return api.Restore_Parry_Discovery_Hook()
    end)

    if ok then
        log("discovery hook restored", a, b or "")
        return a
    end

    log("discovery hook restore error", a)
    return false
end

local function on_ready(status)
    if runtime.Ready then
        return
    end

    runtime.Ready = true

    log("READY true")
    log("Parry_Remote", clean(status.remote))
    log(
        "full name",
        status.remote and clean(status.remote:GetFullName()) or "nil"
    )
    log("Parry_Hash", clean(status.hash))
    log("token", clean(status.token))

    restore_discovery_after_ready()

    log("native Auto Parry ACTIVE")
    log(
        "trigger",
        "Dot>=" .. tostring(CONFIG.min_incoming_dot),
        "distance=",
        tostring(CONFIG.base_distance)
            .. " + speed*"
            .. tostring(CONFIG.speed_range_scale)
            .. " + ping*"
            .. tostring(CONFIG.ping_range_scale),
        "clamp",
        tostring(CONFIG.min_distance)
            .. ".."
            .. tostring(CONFIG.max_distance)
    )
    log(
        "immortality mode",
        "direct-only (SingularityCape / IsInvisible); ability markers ignored"
    )
end

local last_status_ready = false
local last_target_ball = nil
local last_diagnostic_clock = -math.huge
local last_immortality_reason = nil

local function step()
    if runtime.Destroyed then
        return
    end

    local status = api.Get_Parry_Discovery_Status()

    if not status.ready then
        if last_status_ready then
            last_status_ready = false
            log("parry identity no longer ready")
        end
        return
    end

    if not runtime.Ready then
        on_ready(status)
    end
    last_status_ready = true

    if not runtime.Enabled then
        return
    end

    local character = local_player and local_player.Character
    local primary_part = character and character.PrimaryPart
    if primary_part == nil then
        return
    end

    refresh_ball_target_states()

    local ball = api.Get_Targeting_Balls()

    if ball ~= last_target_ball then
        last_target_ball = ball
        if CONFIG.log_state_changes then
            log("target ball", ball and clean(ball.Name) or "nil")
        end
    end

    if ball == nil then
        return
    end

    local state = runtime.BallState[ball]
    if state == nil then
        state = {
            was_targeting_local = true,
            parried_this_target_event = false,
        }
        runtime.BallState[ball] = state
    end

    if state.parried_this_target_event then
        return
    end

    if CONFIG.respect_direct_immortality then
        local immortal, immortal_reason = direct_active_immortality()

        if immortal then
            runtime.LastDecision = {
                reason = "direct_immortal",
                immortality_reason = immortal_reason,
            }

            if immortal_reason ~= last_immortality_reason
                or os.clock() - last_diagnostic_clock
                    >= CONFIG.diagnostic_interval_seconds
            then
                last_immortality_reason = immortal_reason
                last_diagnostic_clock = os.clock()
                log(
                    "BLOCK direct immortality",
                    immortal_reason or "<unknown>"
                )
            end

            return
        end
    end

    last_immortality_reason = nil

    local ability_marker = first_ability_marker()
    if ability_marker ~= nil then
        local now_marker = os.clock()

        if now_marker - last_diagnostic_clock
            >= CONFIG.diagnostic_interval_seconds
        then
            last_diagnostic_clock = now_marker
            log("INFO ignored ability marker", ability_marker)
        end
    end

    local props = api.Get_Ball_Properties(ball)
    if type(props) ~= "table" then
        return
    end

    local should_parry, decision =
        compute_decision(ball, props)

    runtime.LastDecision = decision

    if not should_parry then
        local now_diag = os.clock()

        if now_diag - last_diagnostic_clock
            >= CONFIG.diagnostic_interval_seconds
        then
            last_diagnostic_clock = now_diag
            log(
                "TRACK",
                decision.reason,
                clean(ball.Name),
                format_decision(decision)
            )
        end

        return
    end

    local now = os.clock()
    if now - runtime.LastParryClock < CONFIG.global_cooldown_seconds then
        return
    end

    state.parried_this_target_event = true
    runtime.LastParryClock = now
    runtime.LastParryBall = ball

    local ok, args_or_err = pcall(function()
        return api.Parry(CONFIG.parry_type)
    end)

    if not ok then
        state.parried_this_target_event = false
        log("PARRY ERROR", args_or_err)
        return
    end

    runtime.ParryCount += 1

    log(
        "PARRY",
        runtime.ParryCount,
        clean(ball.Name),
        format_decision(decision)
    )

    local args = args_or_err
    if type(args) == "table" then
        log(
            "packet",
            "arg4=" .. clean(args[4]),
            "arg6_entries=" .. tostring(
                type(args[6]) == "table"
                and (function()
                    local n = 0
                    for _ in pairs(args[6]) do n += 1 end
                    return n
                end)()
                or 0
            )
        )
    end
end

function runtime.ResetTargetState()
    table.clear(runtime.BallState)
    runtime.LastParryBall = nil
    runtime.LastDecision = nil
    last_target_ball = nil
    last_immortality_reason = nil
    return true
end

function runtime.SetEnabled(value)
    local next_enabled = value == true

    if runtime.Enabled ~= next_enabled then
        runtime.ResetTargetState()
    end

    runtime.Enabled = next_enabled
    log("Enabled", runtime.Enabled)
    return runtime.Enabled
end

function runtime.GetStatus()
    local discovery = api.Get_Parry_Discovery_Status()

    return {
        version = runtime.Version,
        enabled = runtime.Enabled,
        ready = runtime.Ready,
        destroyed = runtime.Destroyed,
        parry_count = runtime.ParryCount,
        last_parry_clock = runtime.LastParryClock,
        last_parry_ball = runtime.LastParryBall,
        last_decision = runtime.LastDecision,
        discovery = discovery,
        config = CONFIG,
        ignored_ability_marker = first_ability_marker(),
    }
end

function runtime.SetRangePolicy(
    base_distance,
    speed_scale,
    ping_scale,
    min_dot,
    max_distance
)
    if base_distance ~= nil then
        assert(type(base_distance) == "number")
        CONFIG.base_distance = base_distance
    end

    if speed_scale ~= nil then
        assert(type(speed_scale) == "number")
        CONFIG.speed_range_scale = speed_scale
    end

    if ping_scale ~= nil then
        assert(type(ping_scale) == "number")
        CONFIG.ping_range_scale = ping_scale
    end

    if min_dot ~= nil then
        assert(type(min_dot) == "number")
        CONFIG.min_incoming_dot = min_dot
    end

    if max_distance ~= nil then
        assert(type(max_distance) == "number")
        CONFIG.max_distance = max_distance
    end

    log(
        "range policy updated",
        "base", CONFIG.base_distance,
        "speed_scale", CONFIG.speed_range_scale,
        "ping_scale", CONFIG.ping_range_scale,
        "min_dot", CONFIG.min_incoming_dot,
        "max", CONFIG.max_distance
    )
end

function runtime.SetTiming(base_distance, speed_scale, min_dot)
    runtime.SetRangePolicy(
        base_distance,
        speed_scale,
        nil,
        min_dot,
        nil
    )
end

function runtime.Destroy()
    if runtime.Destroyed then
        return true
    end

    runtime.Destroyed = true
    runtime.Enabled = false

    if runtime.Connection ~= nil then
        pcall(function()
            runtime.Connection:Disconnect()
        end)
        runtime.Connection = nil
    end

    pcall(function()
        api.Restore_Parry_Discovery_Hook()
    end)

    if rawget(ENV, "I32_RUNTIME") == runtime then
        ENV.I32_RUNTIME = nil
    end

    pcall(function()
        if _G.I32_RUNTIME == runtime then
            _G.I32_RUNTIME = nil
        end
    end)

    pcall(function()
        if type(shared) == "table"
            and shared.I32_RUNTIME == runtime
        then
            shared.I32_RUNTIME = nil
        end
    end)

    log("destroyed")
    return true
end

runtime.Connection =
    RunService.PreSimulation:Connect(function()
        local ok, err = pcall(step)
        if not ok then
            log("loop error", err)
        end
    end)

local initial = api.Get_Parry_Discovery_Status()

log("cracked engine loaded")
log("singleton runtime installed")
log("auto parry enabled", runtime.Enabled)
log("discovery installed", initial.installed)
log("discovery active", initial.active)
log("ready", initial.ready)

if not initial.ready then
    log("manual parry ONCE to learn current session identity")
else
    on_ready(initial)
end

log("no F6 required")
log("runtime handle: I32_RUNTIME")

return runtime

end)()

    return NativeRuntime
end, tb)

if not ok_engine then
    bootlog(NativeRuntimeOrErr)
    error(NativeRuntimeOrErr, 0)
end

local NativeRuntime = NativeRuntimeOrErr
local REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"

bootlog("loading ui + addons")

local ok_lib, bundle = xpcall(function()
    local function load_url(url)
        local src = game:HttpGet(url)
        assert(type(src) == "string" and #src > 100, "download failed: " .. url)

        local fn, err = loadstring(src)
        assert(fn, "compile failed: " .. tostring(err))

        return fn()
    end

    local Library = load_url(REPO .. "Library.lua")
    assert(type(Library) == "table", "Library did not return table")

    local ThemeManager = load_url(REPO .. "addons/ThemeManager.lua")
    local SaveManager = load_url(REPO .. "addons/SaveManager.lua")

    return {
        Library = Library,
        ThemeManager = ThemeManager,
        SaveManager = SaveManager,
    }
end, tb)

if not ok_lib then
    pcall(function() NativeRuntime.Destroy() end)
    bootlog("UI LOAD ERROR")
    bootlog(bundle)
    error(bundle, 0)
end

local Library = bundle.Library
local ThemeManager = bundle.ThemeManager
local SaveManager = bundle.SaveManager

local ORIGINAL_THEME = {
    FontColor = "#ffffff",
    MainColor = "#232330",
    AccentColor = "#426e87",
    BackgroundColor = "#1d1b26",
    OutlineColor = "#27232f",
    BackgroundImage = "",
    FontFace = "Code",
}

Library.NotifySide = "Right"
Library.ShowCustomCursor = false
Library.ShowToggleFrameInKeybinds = true
Library.NotifyOnError = false

local App = {
    Version = "I32",
    Runtime = NativeRuntime,
    Library = Library,
    ThemeManager = ThemeManager,
    SaveManager = SaveManager,
    Destroyed = false,

    Settings = {
        Notifications = false,
        ParryMethod = "Remote",
        ParryType = "Camera",
        ParryAccuracy = 100,
        ParryRange = 0,
    },
}

App.Controls = {}
App.Internal = {
    correcting_method = false,
    correcting_type = false,
}

G.I32A1 = App
pcall(function() _G.I32A1 = App end)
pcall(function()
    if type(shared) == "table" then
        shared.I32A1 = App
    end
end)

local function notify(text)
    if not App.Settings.Notifications then
        return
    end

    pcall(function()
        Library:Notify(text)
    end)
end

local function apply_native_policy()
    local range = tonumber(App.Settings.ParryRange) or 0
    local accuracy = tonumber(App.Settings.ParryAccuracy) or 100

    local multiplier = 1 + math.clamp(range, 0, 10) * 0.05
    local min_dot = math.clamp((100 - accuracy) / 100, 0, 0.99)

    NativeRuntime.SetRangePolicy(
        8.0 * multiplier,
        0.25 * multiplier,
        0.025 * multiplier,
        min_dot,
        math.clamp(95.0 * multiplier, 95, 150)
    )
end

local function shell_callback()
    -- Visual compatibility surface only
end

local function safe_ui(label, fn)
    local ok, result = pcall(fn)

    if not ok then
        bootlog("UI shell warning", label, result)
        return nil
    end

    return result
end

local function add_keypicker(element, id, text)
    if type(element) ~= "table" or type(element.AddKeyPicker) ~= "function" then
        return
    end

    safe_ui("keypicker " .. id, function()
        element:AddKeyPicker(id, {
            Default = "",
            SyncToggleState = true,
            Mode = "Toggle",
            Text = text,
            NoUI = false,
        })
    end)
end

local function add_colorpicker(element, id, color)
    if type(element) ~= "table" or type(element.AddColorPicker) ~= "function" then
        return
    end

    safe_ui("colorpicker " .. id, function()
        element:AddColorPicker(id, {
            Default = color,
            Title = "",
            Transparency = 0,
            Callback = shell_callback,
        })
    end)
end

local ok_window, WindowOrErr = xpcall(function()
    local Window = Library:CreateWindow({
        Title = "Visual | Intertia",
        Footer = "(Cracked by Intertia) | My discord: .int3rtia",
        ToggleKeybind = Enum.KeyCode.RightAlt,
        Size = UDim2.fromOffset(620, 420),
        Center = true,
        AutoShow = true,
        NotifySide = "Right",
        ShowCustomCursor = false,
    })

    local Main = Window:AddTab("Main")
    --local Visuals = Window:AddTab("Visuals")
    --local Swords = Window:AddTab("Swords")
    local Settings = Window:AddTab("Settings")
    local AutoParry = Main:AddLeftGroupbox("AutoParry")

    local AutoParryToggle = AutoParry:AddToggle("Auto_Parry_Toggle", {
        Text = "Auto Parry",
        Default = false,
        Callback = function(value)
            apply_native_policy()
            NativeRuntime.SetEnabled(value == true)

            if value == true then
                local status = NativeRuntime.GetStatus()
                local discovery = status.discovery or {}

                if not discovery.ready then
                    notify("Manual parry once to resolve the current session.")
                else
                    notify("Auto Parry enabled.")
                end
            else
                notify("Auto Parry disabled.")
            end
        end,
    })
    App.Controls.AutoParry = AutoParryToggle
    add_keypicker(AutoParryToggle, "Auto_Parry_Keybind", "Auto Parry")

    local NotificationsToggle = AutoParry:AddToggle("Notifications_Toggle", {
        Text = "Notifications",
        Default = false,
        Callback = function(value)
            App.Settings.Notifications = value == true
        end,
    })
    App.Controls.Notifications = NotificationsToggle

    local ParryMethodDropdown
    ParryMethodDropdown = AutoParry:AddDropdown("Parry_Method_Dropdown", {
        Text = "Parry Method",
        Values = {"Remote", "Keypress"},
        Default = "Remote",
        Multi = false,
        Callback = function(value)
            if App.Internal.correcting_method then
                return
            end

            if value ~= "Remote" then
                App.Internal.correcting_method = true
                App.Settings.ParryMethod = "Remote"

                task.defer(function()
                    if not App.Destroyed
                        and ParryMethodDropdown
                        and type(ParryMethodDropdown.SetValue) == "function"
                    then
                        ParryMethodDropdown:SetValue("Remote")
                    end

                    App.Internal.correcting_method = false
                end)

                notify("Keypress is not native yet. Using Remote.")
                return
            end

            App.Settings.ParryMethod = "Remote"
        end,
    })
    App.Controls.ParryMethod = ParryMethodDropdown

    pcall(function()
        if type(ParryMethodDropdown.SetDisabledValues) == "function" then
            ParryMethodDropdown:SetDisabledValues({"Keypress"})
        end
    end)

    local ParryTypeDropdown
    ParryTypeDropdown = AutoParry:AddDropdown("Parry_Type_Dropdown", {
        Text = "Parry Type",
        Values = {
            "Camera",
            "Straight",
            "Dot",
            "Backward",
            "Random",
            "Random Target",
        },
        Default = "Camera",
        Multi = false,
        Callback = function(value)
            if App.Internal.correcting_type then
                return
            end

            if value ~= "Camera" then
                App.Internal.correcting_type = true
                App.Settings.ParryType = "Camera"
                NativeRuntime.Config.parry_type = "Camera"

                task.defer(function()
                    if not App.Destroyed
                        and ParryTypeDropdown
                        and type(ParryTypeDropdown.SetValue) == "function"
                    then
                        ParryTypeDropdown:SetValue("Camera")
                    end

                    App.Internal.correcting_type = false
                end)

                notify(tostring(value) .. " is not native yet. Using Camera.")
                return
            end

            App.Settings.ParryType = "Camera"
            NativeRuntime.Config.parry_type = "Camera"
        end,
    })
    App.Controls.ParryType = ParryTypeDropdown

    pcall(function()
        if type(ParryTypeDropdown.SetDisabledValues) == "function" then
            ParryTypeDropdown:SetDisabledValues({
                "Straight",
                "Dot",
                "Backward",
                "Random",
                "Random Target",
            })
        end
    end)

    local ParryAccuracySlider = AutoParry:AddSlider("Parry_Accuracy", {
        Text = "Parry Accuracy",
        Default = 100,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Callback = function(value)
            App.Settings.ParryAccuracy = math.clamp(
                tonumber(value) or 100,
                1,
                100
            )
            apply_native_policy()
        end,
    })
    App.Controls.ParryAccuracy = ParryAccuracySlider

    local ParryRangeSlider = AutoParry:AddSlider("Parry_Range", {
        Text = "Parry Range",
        Default = 0,
        Min = 0,
        Max = 10,
        Rounding = 0,
        Callback = function(value)
            App.Settings.ParryRange = math.clamp(
                tonumber(value) or 0,
                0,
                10
            )
            apply_native_policy()
        end,
    })
    App.Controls.ParryRange = ParryRangeSlider
--[[
    local Clashing = Main:AddRightGroupbox("Clashing")

    local AutoSpam = Clashing:AddToggle("Auto_Spam_Toggle", {
        Text = "Auto Spam",
        Default = false,
        Callback = shell_callback,
    })
    add_keypicker(AutoSpam, "Auto_Spam_Keybind", "Auto Spam")

    Clashing:AddToggle("Animation_Fix_Toggle", {
        Text = "Animation Fix",
        Default = false,
        Callback = shell_callback,
    })

    local ManualSpam = Clashing:AddToggle("Manual_Spam_Toggle", {
        Text = "Manual Spam",
        Default = false,
        Callback = shell_callback,
    })
    add_keypicker(ManualSpam, "Manual_Spam_Keybind", "Manual Spam")

    Clashing:AddSlider("Auto_Spam_Threshold_Slider", {
        Text = "Spam Threshold",
        Default = 2,
        Min = 1,
        Max = 3,
        Rounding = 0,
        Callback = shell_callback,
    })

    local Abilities = Main:AddRightGroupbox("Abilities")

    local AutoAbilities = Abilities:AddToggle("Auto_Ability_Toggle", {
        Text = "Auto Abilities",
        Default = false,
        Callback = shell_callback,
    })
    add_keypicker(AutoAbilities, "Auto_Ability_Keybind", "Auto Abilities")

    local CooldownProtection = Abilities:AddToggle("Cooldown_Protection_Toggle", {
        Text = "Cooldown Protection",
        Default = false,
        Callback = shell_callback,
    })
    add_keypicker(
        CooldownProtection,
        "Cooldown_Protection_Keybind",
        "Cooldown Protection"
    )]]


--[[
    local Camera = Visuals:AddLeftGroupbox("Camera")

    Camera:AddToggle("Camera_Unlock_Toggle", {
        Text = "Unlock Camera",
        Default = true,
        Callback = shell_callback,
    })

    Camera:AddToggle("Stretch_Screen_Toggle", {
        Text = "Stretch Screen",
        Default = false,
        Callback = shell_callback,
    })

    Camera:AddToggle("FOV_Toggle", {
        Text = "FOV",
        Default = false,
        Callback = shell_callback,
    })

    Camera:AddSlider("Camera_Zoom_Slider", {
        Text = "Max Zoom Distance",
        Default = 75,
        Min = 5,
        Max = 200,
        Rounding = 0,
        Callback = shell_callback,
    })

    Camera:AddSlider("Stretch_Value_Slider", {
        Text = "Stretch Value",
        Default = 1,
        Min = 0.1,
        Max = 1,
        Rounding = 1,
        Callback = shell_callback,
    })

    Camera:AddSlider("FOV_Slider", {
        Text = "FOV",
        Default = 70,
        Min = 70,
        Max = 120,
        Rounding = 0,
        Callback = shell_callback,
    })

    local Visualizer = Visuals:AddLeftGroupbox("Visualizer")
    local VisualizerToggle = Visualizer:AddToggle("Visualizer_Toggle", {
        Text = "Visualizer",
        Default = false,
        Tooltip = "Shows parry range visualization",
        Callback = shell_callback,
    })
    add_colorpicker(
        VisualizerToggle,
        "Visualizer_Color",
        Color3.fromRGB(0, 255, 0)
    )

    local ESP = Visuals:AddLeftGroupbox("ESP")
    local AbilityESP = ESP:AddToggle("Ablity_ESP_Toggle", {
        Text = "Ability ESP",
        Default = false,
        Callback = shell_callback,
    })
    add_keypicker(AbilityESP, "Ablity_ESP_Keybind", "Ability ESP")

    local VFX = Visuals:AddRightGroupbox("VFX")

    VFX:AddToggle("No_Render_Toggle", {
        Text = "No Render",
        Default = false,
        Callback = shell_callback,
    })

    VFX:AddToggle("Ball_Glow_Toggle", {
        Text = "Long Trail",
        Default = false,
        Callback = shell_callback,
    })

    local Appearance = Visuals:AddRightGroupbox("Appearance")

    Appearance:AddToggle("Headless_Only_Toggle", {
        Text = "Headless",
        Default = false,
        Callback = shell_callback,
    })

    Appearance:AddToggle("Korblox_Only_Toggle", {
        Text = "Korblox",
        Default = false,
        Callback = shell_callback,
    })

    local Forcefield = Appearance:AddToggle("Forcefield_Toggle", {
        Text = "Forcefield",
        Default = false,
        Callback = shell_callback,
    })
    add_colorpicker(
        Forcefield,
        "Forcefield_Color",
        Color3.fromRGB(0, 170, 255)
    )

    Appearance:AddToggle("Avatar_Changer_Toggle", {
        Text = "Avatar Changer",
        Default = false,
        Callback = shell_callback,
    })

    safe_ui("Avatar ID input", function()
        Appearance:AddInput("Avatar_Changer_Textbox", {
            Text = "Avatar ID/Username",
            Default = "",
            Numeric = false,
            Finished = false,
            Callback = shell_callback,
        })
    end)

    ]]





--[[
    local SwordsChanger = Swords:AddLeftGroupbox("Swords Changer")

    SwordsChanger:AddToggle("Unlock_Enabled_Toggle", {
        Text = "Toggle",
        Default = false,
        Callback = shell_callback,
    })

    local SwordFX = Swords:AddRightGroupbox("Shield & Slash FX")

    local ShieldFX = SwordFX:AddToggle("ShieldFX_Toggle", {
        Text = "Shield FX",
        Default = false,
        Callback = shell_callback,
    })
    add_colorpicker(ShieldFX, "ShieldFX_Color", Color3.fromRGB(255, 0, 0))

    SwordFX:AddToggle("ShieldFX_Rainbow", {
        Text = "Rainbow",
        Default = false,
        Callback = shell_callback,
    })

    local SlashFX = SwordFX:AddToggle("SlashFX_Toggle", {
        Text = "Slash FX",
        Default = false,
        Callback = shell_callback,
    })
    add_colorpicker(SlashFX, "SlashFX_Color", Color3.fromRGB(255, 0, 0))

    SwordFX:AddToggle("SlashFX_Rainbow", {
        Text = "Rainbow",
        Default = false,
        Callback = shell_callback,
    })

]]

    local Menu = Settings:AddLeftGroupbox("Menu")

    Menu:AddButton({
        Text = "Unload",
        Func = function()
            App.Destroy()
        end,
    })

    Menu:AddToggle("Show_Keybinds_Toggle", {
        Text = "Show Keybinds",
        Default = false,
        Tooltip = "Display all available keybinds",
        Callback = function(value)
            pcall(function()
                Library.KeybindFrame.Visible = value == true
            end)
        end,
    })

    local MenuBind = Menu:AddLabel("Menu bind")
    safe_ui("MenuKeybind", function()
        MenuBind:AddKeyPicker("MenuKeybind", {
            Default = "RightAlt",
            NoUI = true,
            Text = "Menu keybind",
            Mode = "Toggle",
        })
        Library.ToggleKeybind = Library.Options.MenuKeybind
    end)

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)

    ThemeManager:SetDefaultTheme(ORIGINAL_THEME)

    pcall(function()
        ThemeManager:SetFolder("Vanana")
    end)

    pcall(function()
        SaveManager:SetFolder("Vanana")
    end)

    pcall(function()
        SaveManager:IgnoreThemeSettings()
    end)

    pcall(function()
        SaveManager:SetIgnoreIndexes({"MenuKeybind"})
    end)

    SaveManager:BuildConfigSection(Settings)
    ThemeManager:ApplyToTab(Settings)

    local theme_ok, theme_err = ThemeManager:ApplyTheme("Default")
    if not theme_ok then
        bootlog("theme apply warning", theme_err)
    end
    task.defer(function()
        if not App.Destroyed then
            local ok, err = ThemeManager:ApplyTheme("Default")
            if not ok then
                bootlog("deferred theme apply warning", err)
            end
        end
    end)

    App.Window = Window
    App.Tabs = {
        Main = Main,
        --Visuals = Visuals,
        --Swords = Swords,
        Settings = Settings,
    }

    apply_native_policy()

    return Window
end, tb)

if not ok_window then
    pcall(function() NativeRuntime.Destroy() end)
    pcall(function() Library:Unload() end)

    bootlog("WINDOW ERROR")
    bootlog(WindowOrErr)
    error(WindowOrErr, 0)
end

local last_ready = false
local last_count = 0

App.StatusThread = task.spawn(function()
    while not App.Destroyed do
        local ok, status = pcall(NativeRuntime.GetStatus)

        if ok and type(status) == "table" then
            local discovery = status.discovery or {}
            local ready = discovery.ready == true
            local count = tonumber(status.parry_count) or 0

            if ready and not last_ready then
                last_ready = true
                notify("Parry hooked.")
            elseif not ready then
                last_ready = false
            end

            if count > last_count then
                last_count = count
                -- notify("Parried")
            else
                last_count = count
            end
        end

        task.wait(0.25)
    end
end)

function App.GetStatus()
    local status = NativeRuntime.GetStatus()

    status.ui = {
        enabled = App.Controls.AutoParry
            and App.Controls.AutoParry.Value == true
            or false,
        notifications = App.Settings.Notifications,
        parry_method = App.Settings.ParryMethod,
        parry_type = App.Settings.ParryType,
        parry_accuracy = App.Settings.ParryAccuracy,
        parry_range = App.Settings.ParryRange,
    }

    return status
end

function App.SetAutoParry(value)
    local toggle = App.Controls.AutoParry

    if toggle and type(toggle.SetValue) == "function" then
        toggle:SetValue(value == true)
        return toggle.Value == true
    end

    NativeRuntime.SetEnabled(value == true)
    return NativeRuntime.GetStatus().enabled
end

function App.SetParryRange(value)
    local slider = App.Controls.ParryRange
    value = math.clamp(tonumber(value) or 0, 0, 10)

    if slider and type(slider.SetValue) == "function" then
        slider:SetValue(value)
    else
        App.Settings.ParryRange = value
        apply_native_policy()
    end

    return App.Settings.ParryRange
end

function App.SetParryAccuracy(value)
    local slider = App.Controls.ParryAccuracy
    value = math.clamp(tonumber(value) or 100, 1, 100)

    if slider and type(slider.SetValue) == "function" then
        slider:SetValue(value)
    else
        App.Settings.ParryAccuracy = value
        apply_native_policy()
    end

    return App.Settings.ParryAccuracy
end

function App.Destroy()
    if App.Destroyed then
        return true
    end

    App.Destroyed = true

    pcall(function()
        NativeRuntime.Destroy()
    end)

    pcall(function()
        Library:Unload()
    end)

    if rawget(G, "I32A1") == App then
        G.I32A1 = nil
    end

    pcall(function()
        if _G.I32A1 == App then
            _G.I32A1 = nil
        end
    end)

    pcall(function()
        if type(shared) == "table"
            and shared.I32A1 == App
        then
            shared.I32A1 = nil
        end
    end)

    bootlog("unloaded")
    return true
end

bootlog("ready")
return App
