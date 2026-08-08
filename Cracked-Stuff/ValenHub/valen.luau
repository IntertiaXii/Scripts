local Env = getfenv();
local P = {};
local v1 = {...};
local r1 = true;
local r2 = string.gmatch;
local function r3(...)
    error("Tamper Detected!");
    return; 
end;
local r4 = false;
local v2 = pcall(function(...)
    r4 = true;
    return; 
end);
local v3 = v2;
if v2 then
    v3 = r4;
end;
local v4 = 1;
local r5 = math.random;
local v5 = table.concat;
local function v6(...)
    while true do
        l1 = l2;
        l2 = l1;
        r3(); 
    end;
    return; 
end;
local r6 = table and table.unpack or unpack;
local r7 = r5(3, 65);
local v7 = {
    pcall(function(...)
        return "f84hX5qdbeg" / (8541722 - "OBug" ^ 1328323); 
    end)
};
local v8 = v7[2];
local r8 = tonumber(r2(tostring(v8), ":(%d*):")());
for A = 1, r7 do
    r9 = A;
    r10 = math.random(1, 100);
    r11 = r5(0, 255);
    r12 = r5(1, r10);
    r13 = r5(1, 2) == 1;
    r14 = v8.gsub(v8, ":(%d*):", ":" .. tostring(r5(0, 10000)) .. ":");
    g = {
        pcall(function(...)
            if r5(1, 2) == 1 or r9 == r7 then
                r1 = r1 and r8 == tonumber(r2(tostring(({
                    pcall(function(...)
                        return "dVC6l6RywL" / (10455385 - "nPjf" ^ 1576676); 
                    end)
                })[2]), ":(%d*):")());
            end;
            if r13 then
                error(r14, 0);
            end;
            v1 = {};
            for M = 1, r10 do
                v1[M] = r5(0, 255); 
            end;
            v1[r12] = r11;
            return r6(v1); 
        end)
    };
    if r13 then
        r1 = r1 and (pcall(function(...)
            if r5(1, 2) == 1 or r9 == r7 then
                r1 = r1 and r8 == tonumber(r2(tostring(({
                    pcall(function(...)
                        return "dVC6l6RywL" / (10455385 - "nPjf" ^ 1576676); 
                    end)
                })[2]), ":(%d*):")());
            end;
            if r13 then
                error(r14, 0);
            end;
            v1 = {};
            for M = 1, r10 do
                v1[M] = r5(0, 255); 
            end;
            v1[r12] = r11;
            return r6(v1); 
        end) == false and g[2] == r14);
    end; 
end;
r1 = r1 and 0 == 0;
if r1 then
    r17 = math.floor;
    v7 = {};
    r18 = 0;
    r19 = 2;
    r20 = {};
    C = 0;
    for T = 1, 256 do
        v7[T] = T; 
    end;
    v8 = #v7 == 0;
    T = table.remove(v7, math.random(1, #v7));
    r20[T] = string.char(T - 1);
    if #v7 == 0 then
        r21 = {};
        r23 = {};
        r16 = setmetatable({}, {
            ["__index"] = r23,
            ["__metatable"] = nil
        });
        M = game;
        r24 = M.GetService(M, "Players");
        W = game;
        r25 = W.GetService(W, "HttpService");
        v4 = game;
        r26 = v4.GetService(v4, "TweenService");
        r27 = r24.LocalPlayer;
        r28 = "https://script.google.com/macros/s/AKfycbxV4PJbPpHtyuH9PFy77lEIWYkPz3KdJH5mjqUj5hIyJQ8xVA7-9FJ8me7MpvBOQkaX/exec";
        r29 = "ValenHub";
        r30 = r29 .. "/Key.txt";
        v7 = game;
        r31 = loadstring(v7.HttpGet(v7, "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))();
        r32 = "rbxassetid://";
        Ru[1] = "\xe10\x8dF\xa6\x02\x99\x12&\x01\x06";
        r33 = "rbxassetid://";
        r34 = "Dark";
        r35 = {
            "Dark",
            "Light",
            "Rose",
            "Plant",
            "Indigo",
            "Sky",
            "Violet",
            "Amber"
        };
        r36 = "ValenHub/Config.json";
        local function r37(...)
            if writefile then
                r38 = {
                    ["Theme"] = r34,
                    ["Background"] = r32
                };
                pcall(function(...)
                    u = game;
                    M = u.GetService(u, "HttpService");
                    writefile(r36, M.JSONEncode(M, r38));
                    return; 
                end);
            end;
            return; 
        end;
        (function(...)
            if readfile then
                M = {
                    pcall(function(...)
                        return readfile(r36); 
                    end)
                };
                u = pcall(function(...)
                    return readfile(r36); 
                end);
                r39 = M[2];
                if u then
                    v3 = r39 and r39 ~= "";
                    v5 = pcall;
                end;
                if u then
                    W = {
                        pcall(function(...)
                            v5 = game;
                            v3 = v5.GetService(v5, "HttpService");
                            return v3.JSONDecode(v3, r39); 
                        end)
                    };
                    o = pcall(function(...)
                        v5 = game;
                        v3 = v5.GetService(v5, "HttpService");
                        return v3.JSONDecode(v3, r39); 
                    end);
                    v1 = W[2];
                    if o then
                        v3 = W[2];
                    end;
                    if o then
                        if v1.Theme then
                            v6 = r35;
                            v4 = 21200618235536[2];
                            v2 = 21200618235536[3];
                            for v2, k in ipairs(v3) do
                                F = v2;
                                if k == W[2].Theme then
                                    W = true;
                                else
                                    
                                end; 
                            end;
                            if false then
                                r34 = W[2].Theme;
                            end;
                        end;
                        if v1.Background then
                            r32 = W[2].Background;
                        end;
                    end;
                end;
            end;
            return; 
        end)();
        local function r40(...)
            v5 = game;
            v3 = v5.GetService(v5, "RbxAnalyticsService");
            return v3.GetClientId(v3); 
        end;
        local function r41(arg1_2, ...)
            v4 = r25;
            F = r25;
            r42 = r28 .. "?key=" .. v4.UrlEncode(v4, arg1_2) .. "&hwid=" .. F.UrlEncode(F, r40());
            v4 = {
                pcall(function(...)
                    v5 = game;
                    return v5.HttpGet(v5, r42); 
                end)
            };
            o = v4[2];
            if not pcall(function(...)
                v5 = game;
                return v5.HttpGet(v5, r42); 
            end) then
                return "error";
            end;
            v5 = o.gsub(o, "^%s+", "");
            return v5.gsub(v5, "%s+$", ""); 
        end;
        local function r43(arg1_3, ...)
            r44 = arg1_3;
            if writefile then
                pcall(function(...)
                    local y = {
                        y[1],
                        y[2],
                        139
                    };
                    if makefolder then
                        makefolder(P[y[1]]);
                    end;
                    writefile(P[y[2]], r44);
                    return; 
                end);
            end;
            return; 
        end;
        local function r45(...)
            if readfile then
                v5 = pcall;
                M = {
                    v5(function(...)
                        return readfile(r30); 
                    end)
                };
                u = v5(function(...)
                    return readfile(r30); 
                end);
                v1 = M[2];
                if u then
                    if v1 then
                        M = M[2] ~= "";
                    end;
                    v5 = pcall;
                    v3 = v1;
                end;
                if u then
                    v5 = v1.gsub(v1, "^%s+", "");
                    return v5.gsub(v5, "%s+$", "");
                end;
            end;
            return nil; 
        end;
        local function r46(...)
            if delfile then
                pcall(function(...)
                    delfile(P[y[1]]);
                    return; 
                end);
            end;
            return; 
        end;
        r47 = {
            "ReplicatedStorage",
            "Workspace",
            "Players",
            "Lighting",
            "StarterGui",
            "StarterPack",
            "StarterPlayer",
            "SoundService",
            "Chat",
            "TextChatService",
            "RunService",
            "TweenService",
            "HttpService",
            "MarketplaceService",
            "BadgeService",
            "Teams",
            "JointsService",
            "CollectionService",
            "PhysicsService",
            "AssetService",
            "GamePassService",
            "PointsService",
            "PolicyService",
            "SocialService",
            "TeleportService",
            "UserInputService",
            "VRService",
            "ServerScriptService",
            "ServerStorage",
            "ReplicatedFirst",
            "RobloxReplicatedStorage",
            "CoreGui",
            "CorePackages",
            "DataStoreService",
            "Debris",
            "InsertService",
            "LocalizationService",
            "LogService",
            "PathfindingService",
            "ProximityPromptService"
        };
        local function r48(arg1_4, ...)
            r49 = arg1_4;
            o = {
                pcall(function(...)
                    v5 = game;
                    return v5.GetService(v5, r49); 
                end)
            };
            u = o[2];
            M = pcall(function(...)
                v5 = game;
                return v5.GetService(v5, r49); 
            end);
            if M then
                v3 = o[2];
            end;
            if M then
                return u;
            end;
            v5 = game;
            return v5.FindFirstChild(v5, r49); 
        end;
        local function r50(arg1_5, ...)
            v1 = arg1_5;
            if not v1 then
                return "nil";
            end;
            o = v1.Parent;
            v3 = o;
            while not o do
                if v3 then
                    u = v1.Parent.Name .. "/" .. u;
                end;
                return v1.Name; 
            end;
            v3 = v1.Parent ~= game; 
        end;
        local function r51(arg1_6, ...)
            v1 = arg1_6;
            if not v1 or v1 == "" then
                return nil;
            end;
            u = {};
            v2 = r15;
            v4 = {
                string.gmatch(v1, "[^.]+")
            };
            W = string.gmatch(v1, "[^.]+");
            o = W(v4[2], v4[3]);
            while o do
                v4 = o;
                table.insert(u, v4); 
            end;
            M = game;
            o = v2[1];
            W = v2[2];
            for v4, v6 in ipairs(u) do
                if v4 == 1 then
                    k = game;
                    M = k.GetService(k, v6) or k.FindFirstChild(k, v6);
                else
                    M = M.FindFirstChild(M, v6);
                end;
                if not M then
                    return nil;
                else
                    
                end; 
            end;
            return M; 
        end;
        local function r52(arg1_7, ...)
            v5 = {};
            M = arg1_7;
            while not M do
                if M then
                    table.insert(v5, 1, v1.Name);
                    M = v1.Parent;
                end;
                o = v5;
                v3 = M and M.Name;
                v5 = v5;
                if M then
                    v5 = v5;
                    F = r16;
                    v2 = F[2];
                    v6 = F[3];
                    for v6, k in ipairs(v5) do
                        F = v6;
                        W = ("game:GetService(" .. string.format(r16[r15("\xcb-", v8)], o) .. F[C]) .. "[" .. string.format("%q", k) .. "]"; 
                    end;
                    return "game:GetService(" .. string.format("%q", W and M.Name) .. ")";
                else
                    v3 = "ReplicatedStorage";
                end; 
            end;
            v3 = M.Parent and M.Parent ~= game;
            v5 = v5; 
        end;
        local function r53(arg1_8, ...)
            v1 = arg1_8;
            u = typeof(v1);
            if u == "string" then
                return string.format("%q", v1);
            end;
            if u == "number" or u == "boolean" then
                return tostring(v1);
            end;
            if u == "Instance" then
                if v1 then
                    W = v1.GetFullName(v1);
                end;
                v5 = v5;
                v5 = v5;
                return "Instance: " .. (v1 or "nil");
            end;
            if u == "Vector3" then
                return string.format("Vector3.new(%s, %s, %s)", tostring(v1.X), tostring(v1.Y), tostring(v1.Z));
            end;
            if u == "Vector2" then
                return string.format("Vector2.new(%s, %s)", tostring(v1.X), tostring(v1.Y));
            end;
            if u == "Color3" then
                return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(v1.R * 255), math.floor(v1.v8 * 255), math.floor(v1.B * 255));
            end;
            if u == "CFrame" then
                o = {
                    v1.GetComponents(v1)
                };
                return string.format("CFrame.new(%s, %s, %s)", tostring(v1.GetComponents(v1)), tostring(o[2]), tostring(o[3]));
            end;
            if u == "UDim" then
                return string.format("UDim.new(%s, %s)", tostring(v1.Scale), tostring(v1.Offset));
            end;
            if u == "UDim2" then
                return string.format("UDim2.new(%s, %s, %s, %s)", tostring(v1.X.Scale), tostring(v1.X.Offset), tostring(v1.Y.Scale), tostring(v1.Y.Offset));
            end;
            if u == "EnumItem" then
                return tostring(v1);
            end;
            M = r16;
            if u == "table" then
                M = {};
                o = ("C\xd3?\xe0}")[2];
                W = ("C\xd3?\xe0}")[3];
                v4 = "pairs";
                for W, v6 in pairs(v1) do
                    table.insert(M, string.format("[%s] = %s", tostring(W), tostring(v6))); 
                end;
                return "{" .. table.concat(M, ", ") .. "}";
            end;
            return "[" .. u .. "]"; 
        end;
        local function r54(arg1_9, arg2_9, arg3_9, ...)
            W = P[u];
            v1 = arg1_9;
            M = arg3_9;
            if M then
                M = M;
                v5 = v5;
                v4 = string.rep("    ", arg2_9 or 0);
                W = {};
                if not v1 then
                    table.insert(W, v4 .. "[nil instance]");
                    return W;
                end;
                if M.progress then
                    M.progress.count = M.progress.count + 1;
                    if M.progress.onUpdate then
                        v6 = tick();
                        if v6 - o.progress.lastUpdate >= .2 then
                            k = tick();
                            o.progress.lastUpdate = k;
                            o.progress.onUpdate(o.progress.count, o.progress.total);
                        end;
                    end;
                end;
                v2 = v4 .. v1.Name;
                if M.sourceFormat then
                    v2 = r52(v1) .. " -- " .. v1.ClassName;
                    table.insert(W, v2);
                    if M.dumpAttributes then
                        q = {};
                        C = v1.GetAttributes(v1);
                        T = b[2];
                        A = b[3];
                        for A, b in pairs(C) do
                            table.insert(q, A); 
                        end;
                        b = r15;
                        table.sort(q);
                        A = b[3];
                        for A, b in b[1], ipairs(q) do
                            v7 = A;
                            table.insert({}, "-- " .. r52(v1) .. ":GetAttribute(" .. string.format("%q", b) .. ") == " .. r53(C[b])); 
                        end;
                    end;
                    if M.dumpChildren then
                        C = v1.GetChildren(v1);
                        A = r15;
                        table.sort(C, function(arg1_10, arg2_10, ...)
                            return arg1_10.Name < arg2_10.Name; 
                        end);
                        v8 = A[2];
                        T = A[3];
                        for T, A in ipairs(C) do
                            q = T;
                            Z = J[2];
                            r = J[1];
                            for l, J in ipairs(r54(A, v3 + 1, o)) do
                                b = l;
                                table.insert({}, J); 
                            end; 
                        end;
                    end;
                    return W;
                end;
                if v1.IsA(v1, "StringValue") then
                    v2 = v2 .. " [StringValue = " .. r53(arg1_9.Value) .. "]";
                else
                    if v1.IsA(v1, "IntValue") then
                        v2 = v2 .. " [IntValue = " .. tostring(arg1_9.Value) .. "]";
                    else
                        if v1.IsA(v1, "NumberValue") then
                            v2 = v2 .. " [NumberValue = " .. tostring(arg1_9.Value) .. "]";
                        else
                            if v1.IsA(v1, "BoolValue") then
                                v2 = v2 .. " [BoolValue = " .. tostring(arg1_9.Value) .. "]";
                            else
                                if v1.IsA(v1, "ObjectValue") then
                                    v8 = arg1_9.Value;
                                    if v8 then
                                        l = v8.Name;
                                    end;
                                    v5 = v5;
                                    v5 = v5;
                                    v2 = v2 .. " [ObjectValue = " .. (v8 or "nil") .. "]";
                                else
                                    if v1.IsA(v1, "Color3Value") then
                                        v8 = arg1_9.Value;
                                        v2 = v2 .. string.format(" [Color3Value = Color3.fromRGB(%d, %d, %d)]", math.floor(v8.R * 255), math.floor(v8.v8 * 255), math.floor(v8.B * 255));
                                    else
                                        if v1.IsA(v1, "Vector3Value") then
                                            v8 = arg1_9.Value;
                                            v2 = v2 .. string.format(" [Vector3Value = Vector3.new(%s, %s, %s)]", tostring(v8.X), tostring(v8.Y), tostring(v8.Z));
                                        else
                                            if v1.IsA(v1, "CFrameValue") then
                                                v8 = arg1_9.Value;
                                                l = {
                                                    v8.GetComponents(v8)
                                                };
                                                v2 = v2 .. string.format(" [CFrameValue = CFrame.new(%s, %s, %s)]", tostring(v8.GetComponents(v8)), tostring(l[2]), tostring(l[3]));
                                            else
                                                if v1.IsA(v1, "RayValue") then
                                                    v2 = v2 .. " [RayValue]";
                                                else
                                                    if v1.IsA(v1, "BrickColorValue") then
                                                        v2 = v2 .. " [BrickColorValue = " .. tostring(arg1_9.Value) .. "]";
                                                    else
                                                        if v1.IsA(v1, "RemoteEvent") then
                                                            v2 = v2 .. " [RemoteEvent]";
                                                        else
                                                            if v1.IsA(v1, "RemoteFunction") then
                                                                v2 = v2 .. " [RemoteFunction]";
                                                            else
                                                                if v1.IsA(v1, "BindableEvent") then
                                                                    v2 = v2 .. " [BindableEvent]";
                                                                else
                                                                    if v1.IsA(v1, "BindableFunction") then
                                                                        v2 = v2 .. " [BindableFunction]";
                                                                    else
                                                                        if v1.IsA(v1, "ModuleScript") then
                                                                            v2 = v2 .. " [ModuleScript]";
                                                                        else
                                                                            if v1.IsA(v1, "Script") then
                                                                                v2 = v2 .. " [Script]";
                                                                            else
                                                                                if v1.IsA(v1, "LocalScript") then
                                                                                    v2 = v2 .. " [LocalScript]";
                                                                                else
                                                                                    v2 = v2 .. " [" .. v1.ClassName .. "]";
                                                                                end;
                                                                                table.insert(W, v2);
                                                                                if o.dumpAttributes then
                                                                                    n = v1.GetAttributes(v1);
                                                                                    V = {};
                                                                                    H = Kd[3];
                                                                                    f = Kd[2];
                                                                                    for H, Kd in pairs(n) do
                                                                                        table.insert(V, H); 
                                                                                    end;
                                                                                    Kd = r15;
                                                                                    table.sort(V);
                                                                                    f = Kd[2];
                                                                                    Bd = Kd[1];
                                                                                    for H, Kd in ipairs(V) do
                                                                                        X = H;
                                                                                        table.insert({}, string.rep("    ", u) .. "    @Attribute: " .. Kd .. " = " .. r53(n[Kd])); 
                                                                                    end;
                                                                                end;
                                                                                V = v5;
                                                                                v5 = V;
                                                                                if o.dumpProperties and v1.IsA(v1, "BasePart") then
                                                                                    table.insert(W, v4 .. "    @Property: Position = " .. r53(v1.Position));
                                                                                    table.insert(W, v4 .. "    @Property: Size = " .. r53(v1.Size));
                                                                                    table.insert(W, v4 .. "    @Property: Orientation = " .. r53(v1.Orientation));
                                                                                    table.insert(W, v4 .. "    @Property: BrickColor = " .. tostring(v1.BrickColor));
                                                                                    table.insert(W, v4 .. "    @Property: Material = " .. tostring(v1.Material));
                                                                                    table.insert(W, v4 .. "    @Property: Transparency = " .. tostring(v1.Transparency));
                                                                                    table.insert(W, v4 .. "    @Property: CanCollide = " .. tostring(v1.CanCollide));
                                                                                    table.insert(W, v4 .. "    @Property: Anchored = " .. tostring(v1.Anchored));
                                                                                end;
                                                                                v5 = v5;
                                                                                if o.dumpProperties and v1.IsA(v1, "Humanoid") then
                                                                                    table.insert(W, v4 .. "    @Property: Health = " .. tostring(v1.Health));
                                                                                    table.insert(W, v4 .. "    @Property: MaxHealth = " .. tostring(v1.MaxHealth));
                                                                                    table.insert(W, v4 .. "    @Property: WalkSpeed = " .. tostring(v1.WalkSpeed));
                                                                                    table.insert(W, v4 .. "    @Property: JumpPower = " .. tostring(v1.JumpPower));
                                                                                end;
                                                                                if o.dumpChildren then
                                                                                    n = v1.GetChildren(v1);
                                                                                    H = r15;
                                                                                    table.sort(n, function(arg1_11, arg2_11, ...)
                                                                                        return arg1_11.Name < arg2_11.Name; 
                                                                                    end);
                                                                                    f = H[3];
                                                                                    for f, H in H[1], ipairs(n) do
                                                                                        V = f;
                                                                                        vd = hd[1];
                                                                                        yd = hd[2];
                                                                                        for zd, hd in ipairs(r54(H, v3 + 1, o)) do
                                                                                            Kd = zd;
                                                                                            table.insert({}, hd); 
                                                                                        end; 
                                                                                    end;
                                                                                end;
                                                                                return W;
                                                                            end;
                                                                        end;
                                                                    end;
                                                                end;
                                                            end;
                                                        end;
                                                    end;
                                                end;
                                            end;
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            else
                o = {};
            end; 
        end;
        local function r55(arg1_12, arg2_12, ...)
            u = arg2_12;
            M = {};
            table.insert(M, "-- ============================================================");
            table.insert(M, "--  Valen Dump Output");
            table.insert(M, "-- ============================================================");
            r56 = "Unknown";
            pcall(function(...)
                v5 = game;
                v3 = v5.GetService(v5, "MarketplaceService");
                v1 = v3.GetProductInfo(v3, game.PlaceId);
                if v1 then
                    v3 = v1.Name;
                end;
                if v1 then
                    r56 = v1.Name;
                end;
                return; 
            end);
            table.insert(M, "-- Game:    " .. r56);
            table.insert(M, "-- PlaceId: " .. tostring(game.PlaceId));
            table.insert(M, "-- JobId:   " .. tostring(game.JobId));
            table.insert(M, "-- Time:    " .. os.date("%Y-%m-%d %H:%M:%S"));
            table.insert(M, "-- Target:  " .. r50(arg1_12));
            table.insert(M, "-- Options: Children=" .. tostring(u.dumpChildren) .. ", Attributes=" .. tostring(u.dumpAttributes) .. ", Properties=" .. tostring(u.dumpProperties));
            table.insert(M, "-- ============================================================");
            table.insert(M, "");
            return M; 
        end;
        local function r57(arg1_13, arg2_13, ...)
            r58 = arg1_13;
            r59 = "ValenHub_Dumps/Dump";
            if makefolder then
                pcall(function(...)
                    makefolder("ValenHub_Dumps");
                    return; 
                end);
                pcall(function(...)
                    makefolder(r59);
                    return; 
                end);
            end;
            r60 = r59 .. "/" .. arg2_13;
            if writefile then
                W = pcall(function(...)
                    writefile(r60, r58);
                    return; 
                end);
                if W then
                    return r60;
                end;
            end;
            return nil; 
        end;
        r61 = "sync,update,heartbeat,tick,ping,replicate,stream,position,character,camera,move,cframe";
        local function r62(arg1_14, ...)
            v1 = arg1_14;
            u = typeof(v1);
            if u == "string" then
                return string.format("%q", v1);
            end;
            if u == "number" or u == "boolean" then
                return tostring(v1);
            end;
            if u == "nil" then
                return "nil";
            end;
            if u == "Instance" then
                return "--[[Instance]] game:GetService(\"ReplicatedStorage\")";
            end;
            if u == "Vector3" then
                return string.format("Vector3.new(%s, %s, %s)", tostring(v1.X), tostring(v1.Y), tostring(v1.Z));
            end;
            if u == "CFrame" then
                o = {
                    v1.GetComponents(v1)
                };
                return string.format("CFrame.new(%s, %s, %s)", tostring(v1.GetComponents(v1)), tostring(o[2]), tostring(o[3]));
            end;
            if u == "table" then
                o = ("\xce\xa6\xab\xee\xd8")[2];
                v4 = ("\xce\xa6\xab\xee\xd8")[1];
                for W, v6 in pairs(v1) do
                    if type(W) == "number" then
                        table.insert({}, r62(v6));
                    else
                        table.insert({}, "[" .. string.format("%q", tostring(W)) .. "] = " .. r62(v6));
                    end; 
                end;
                return "{" .. table.concat({}, ", ") .. "}";
            end;
            return "--[[" .. u .. "]] nil"; 
        end;
        r63 = {
            ["DumpedText"] = "",
            ["LastFilePath"] = ""
        };
        r64 = {
            ["Snapshots"] = {},
            ["MaxSnapshots"] = 20,
            ["AutoSnapEnabled"] = false,
            ["AutoSnapInterval"] = 5,
            ["SnapInProgress"] = false,
            ["SelectedSnap"] = nil,
            ["SnapNames"] = {}
        };
        local function Fd(...)
            r64.AutoSnapEnabled = false;
            return; 
        end;
        r65 = {
            ["Snaps"] = {},
            ["MaxSnaps"] = 100,
            ["Enabled"] = false,
            ["Conn"] = nil
        };
        r66 = {
            ["LastSnap"] = nil,
            ["TargetPlr"] = nil,
            ["ItemName"] = ""
        };
        r67 = workspace;
        local function r68(arg1_15, ...)
            v1 = arg1_15;
            q = {
                v1.GetComponents(v1)
            };
            return {
                v1.GetComponents(v1),
                q[2],
                q[3],
                q[4],
                q[5],
                q[6],
                q[7],
                q[8],
                q[9],
                q[10],
                q[11],
                q[12]
            }; 
        end;
        local function r69(arg1_16, ...)
            v1 = arg1_16;
            if type(v1) ~= "table" or #v1 < 12 then
                return CFrame.new();
            end;
            return CFrame.new(unpack(v1)); 
        end;
        local function r70(arg1_17, ...)
            v1 = arg1_17;
            return {
                v1.X,
                v1.Y,
                v1.Z
            }; 
        end;
        local function r71(arg1_18, ...)
            v1 = arg1_18;
            if type(v1) ~= "table" or #v1 < 3 then
                return Vector3.new();
            end;
            return Vector3.new(unpack(v1)); 
        end;
        local function r72(arg1_19, ...)
            v1 = arg1_19;
            return {
                math.floor(v1.R * 255 + 0.5),
                math.floor(v1.v8 * 255 + 0.5),
                math.floor(v1.B * 255 + 0.5)
            }; 
        end;
        local function r73(arg1_20, ...)
            v1 = arg1_20;
            if type(v1) ~= "table" or #v1 < 3 then
                return Color3.new(1, 1, 1);
            end;
            return Color3.fromRGB(unpack(v1)); 
        end;
        local function r74(arg1_21, ...)
            return tostring(arg1_21); 
        end;
        local function r75(arg1_22, arg2_22, ...)
            r76 = arg1_22;
            r77 = arg2_22;
            W = {
                pcall(function(...)
                    return Enum[r76][r77]; 
                end)
            };
            if pcall(function(...)
                return Enum[r76][r77]; 
            end) then
                return W[2];
            end;
            return nil; 
        end;
        local function kd(...)
            r65.Enabled = false;
            if r65.Conn then
                v5 = r65.Conn;
                v5.Disconnect(v5);
                r65.Conn = nil;
            end;
            return; 
        end;
        local function r78(arg1_23, ...)
            r79 = arg1_23;
            v4 = r79;
            F = v5;
            q = r79.Parent;
            if q then
                q = r79.Parent;
                k = q.GetFullName(q);
            end;
            k = r79;
            v5 = {
                ["ClassName"] = r79.ClassName,
                ["Name"] = r79.Name,
                ["FullName"] = v4.GetFullName(v4),
                ["ParentPath"] = q or nil,
                ["Ref"] = k
            };
            M = pcall(function(...)
                v1 = {};
                v5 = r79;
                if v5.IsA(v5, "BasePart") then
                    v1.CFrame = r68(r79.CFrame);
                    v1.Size = r70(r79.Size);
                    v1.Color = r72(r79.Color);
                    v1.Material = r74(r79.Material);
                    v1.Transparency = r79.Transparency;
                    v1.Reflectance = r79.Reflectance;
                    v1.CanCollide = r79.CanCollide;
                    v1.Anchored = r79.Anchored;
                    v1.CastShadow = r79.CastShadow;
                    v1.Locked = r79.Locked;
                    v1.Massless = r79.Massless;
                    v5 = r79;
                    if v5.IsA(v5, "Part") then
                        ({}).Shape = r74(r79.Shape);
                    end;
                    v5 = r79;
                    v4 = "\xdd\xe9Y\x01\xeaY\xedA";
                    if v5.IsA(v5, r16[r15(v4, 30657156904899)]) then
                        o = {
                            pcall(function(...)
                                return r79.MeshId; 
                            end)
                        };
                        M = pcall(function(...)
                            return r79.MeshId; 
                        end);
                        v3 = M;
                        u = o[2];
                        if M then
                            if u then
                                o = o[2] ~= "";
                            end;
                            v5 = pcall;
                            v3 = u;
                        end;
                        if v3 then
                            v3 = o[2];
                            ({}).MeshId = v3;
                        end;
                        v4 = {
                            pcall(function(...)
                                return r79.TextureID; 
                            end)
                        };
                        o = v4[2];
                        W = pcall(function(...)
                            return r79.TextureID; 
                        end);
                        v3 = W;
                        if W then
                            if o then
                                v4 = v4[2] ~= "";
                            end;
                            v3 = o;
                            v5 = pcall;
                        end;
                        if v3 then
                            v3 = v4[2];
                            ({}).TextureID = v3;
                        end;
                    end;
                end;
                v5 = r79;
                if v5.IsA(v5, "StringValue") then
                    v1.Value = r79.Value;
                else
                    v5 = r79;
                    if v5.IsA(v5, "IntValue") then
                        ({}).Value = r79.Value;
                    else
                        v5 = r79;
                        if v5.IsA(v5, "NumberValue") then
                            ({}).Value = r79.Value;
                        else
                            v5 = r79;
                            if v5.IsA(v5, "BoolValue") then
                                ({}).Value = r79.Value;
                            else
                                v5 = r79;
                                if v5.IsA(v5, "Color3Value") then
                                    ({}).Value = r72(r79.Value);
                                else
                                    v5 = r79;
                                    if v5.IsA(v5, "Vector3Value") then
                                        ({}).Value = r70(r79.Value);
                                    else
                                        v5 = r79;
                                        v3 = v5.IsA(v5, "CFrameValue");
                                        if v3 then
                                            ({}).Value = r68(r79.Value);
                                        else
                                            v5 = r79;
                                            if v5.IsA(v5, "ObjectValue") then
                                                v5 = "Value";
                                                u = v5;
                                                W = r79.Value;
                                                if W then
                                                    W = r79.Value;
                                                    M = W.GetFullName(W);
                                                end;
                                                v5 = v5;
                                                ({})[v5] = W or nil;
                                            end;
                                            v3 = r79;
                                            if v3.IsA(v3, "Light") then
                                                v1.Color = r72(r79.Color);
                                                v1.Brightness = r79.Brightness;
                                                v1.Range = r79.Range;
                                                v1.Shadows = r79.Shadows;
                                                v1.Enabled = r79.Enabled;
                                                v3 = r79;
                                                if v3.IsA(v3, "SpotLight") then
                                                    v1.Angle = r79.Angle;
                                                    v1.Face = r74(r79.Face);
                                                end;
                                                v3 = r79;
                                                if v3.IsA(v3, "SurfaceLight") then
                                                    v1.Angle = r79.Angle;
                                                    v1.Face = r74(r79.Face);
                                                end;
                                            end;
                                            M = r79;
                                            v3 = M.IsA(M, "Decal") or M.IsA(M, "Texture");
                                            v5 = v5;
                                            if v3 then
                                                v1.Texture = r79.Texture;
                                                v1.Face = r74(r79.Face);
                                                v1.Transparency = r79.Transparency;
                                                v3 = r79;
                                                if v3.IsA(v3, "Texture") then
                                                    v1.StudsPerTileU = r79.StudsPerTileU;
                                                    v1.StudsPerTileV = r79.StudsPerTileV;
                                                end;
                                            end;
                                            v3 = r79;
                                            if v3.IsA(v3, "Sound") then
                                                v1.SoundId = r79.SoundId;
                                                v1.Volume = r79.Volume;
                                                v1.PlaybackSpeed = r79.PlaybackSpeed;
                                                v1.Looped = r79.Looped;
                                                v1.RollOffMode = r74(r79.RollOffMode);
                                                v1.RollOffMaxDistance = r79.RollOffMaxDistance;
                                                v1.RollOffMinDistance = r79.RollOffMinDistance;
                                            end;
                                            v3 = r79;
                                            if v3.IsA(v3, "ParticleEmitter") then
                                                v1.Color = tostring(r79.Color);
                                                v1.Size = tostring(r79.Size);
                                                v1.Transparency = tostring(r79.Transparency);
                                                v1.Lifetime = tostring(r79.Lifetime);
                                                v1.Rate = r79.Rate;
                                                v1.Speed = tostring(r79.Speed);
                                                v1.LightEmission = r79.LightEmission;
                                                v1.LightInfluence = r79.LightInfluence;
                                                v1.Texture = r79.Texture;
                                                v1.Enabled = r79.Enabled;
                                            end;
                                            v3 = r79;
                                            if v3.IsA(v3, "Attachment") then
                                                v1.Position = r70(r79.Position);
                                                v1.Orientation = r70(r79.Orientation);
                                                v1.Axis = r70(r79.Axis);
                                                v1.SecondaryAxis = r70(r79.SecondaryAxis);
                                                v1.Visible = r79.Visible;
                                            end;
                                            v3 = r79;
                                            if v3.IsA(v3, "SpawnLocation") then
                                                v1.Duration = r79.Duration;
                                                v1.Neutral = r79.Neutral;
                                                v1.TeamColor = tostring(r79.TeamColor);
                                                v1.AllowTeamChangeOnTouch = r79.AllowTeamChangeOnTouch;
                                            end;
                                            M = r79;
                                            v3 = M.IsA(M, "Seat") or M.IsA(M, "VehicleSeat");
                                            v5 = v5;
                                            if v3 then
                                                v1.MaxSpeed = r79.MaxSpeed;
                                                v3 = r79;
                                                if v3.IsA(v3, "VehicleSeat") then
                                                    v1.Torque = r79.Torque;
                                                    v1.TurnSpeed = r79.TurnSpeed;
                                                end;
                                            end;
                                            v3 = r79;
                                            if v3.IsA(v3, "SpecialMesh") then
                                                v1.MeshType = r74(r79.MeshType);
                                                W = {
                                                    pcall(function(...)
                                                        return r79.MeshId; 
                                                    end)
                                                };
                                                u = pcall(function(...)
                                                    return r79.MeshId; 
                                                end);
                                                M = W[2];
                                                o = v5;
                                                if u then
                                                    if M then
                                                        W = W[2] ~= "";
                                                    end;
                                                    v5 = v5;
                                                    v3 = M;
                                                end;
                                                if u then
                                                    o = W[2];
                                                    ({}).MeshId = o;
                                                end;
                                                v2 = {
                                                    pcall(function(...)
                                                        return r79.TextureId; 
                                                    end)
                                                };
                                                o = pcall(function(...)
                                                    return r79.TextureId; 
                                                end);
                                                v4 = o;
                                                W = v2[2];
                                                if o then
                                                    if W then
                                                        v2 = v2[2] ~= "";
                                                    end;
                                                    v3 = W;
                                                    v5 = o;
                                                end;
                                                v5 = r70;
                                                if o then
                                                    v4 = v2[2];
                                                    ({}).TextureId = v4;
                                                end;
                                                v1.Scale = r70(r79.Scale);
                                                v1.Offset = r70(r79.Offset);
                                            end;
                                            return v1;
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end; 
            end);
            if M then
                v2 = v4[2];
            end;
            v5 = v5;
            v5.Properties = M or ;
            v5.Attributes = {};
            v6 = {
                pcall(function(...)
                    v5 = r79;
                    return v5.GetAttributes(v5); 
                end)
            };
            W = pcall(function(...)
                v5 = r79;
                return v5.GetAttributes(v5); 
            end);
            v4 = v6[2];
            if W then
                v3 = v6[2];
            end;
            v5 = v5;
            if W then
                v2 = k[1];
                v6 = k[2];
                for F, C in pairs(v4) do
                    q = typeof(C);
                    if q == "Vector3" then
                        v5.Attributes[F] = {
                            ["Type"] = "Vector3",
                            ["Value"] = r70(C)
                        };
                    else
                        if q == "CFrame" then
                            v5.Attributes[F] = {
                                ["Type"] = "CFrame",
                                ["Value"] = r68(C)
                            };
                        else
                            if typeof(C) == "Color3" then
                                v5.Attributes[F] = {
                                    ["Type"] = "Color3",
                                    ["Value"] = r72(C)
                                };
                            else
                                if typeof(C) == "EnumItem" then
                                    v5.Attributes[F] = {
                                        ["Type"] = "Enum",
                                        ["Value"] = tostring(C)
                                    };
                                else
                                    v5.Attributes[F] = {
                                        ["Type"] = "Raw",
                                        ["Value"] = C
                                    };
                                end;
                            end;
                        end;
                    end; 
                end;
            end;
            return v5; 
        end;
        local function r80(arg1_24, arg2_24, ...)
            u = arg2_24;
            r81 = arg1_24;
            if r64.SnapInProgress then
                return nil, "Snapshot in progress";
            end;
            v5 = r64;
            v5.SnapInProgress = true;
            o = v5;
            v3 = "Name";
            M = u;
            if u then
                o = "Time";
                os.time();
                W = "Timestamp";
                tick();
                k = v5;
                v2 = "TargetPath";
                v7 = r81;
                F = v7 and v7.GetFullName(v7);
                v5 = v5;
                if v7 then
                    v5 = v5;
                    r82 = {
                        [r16[W]] = u,
                        ["Time"] = os.time(),
                        ["Timestamp"] = tick(),
                        ["TargetPath"] = C and v7.GetFullName(v7),
                        ["Data"] = {},
                        ["InstanceCount"] = 0
                    };
                    local function r83(arg1_25, ...)
                        r84 = arg1_25;
                        o = {
                            pcall(function(...)
                                return r15(r84); 
                            end)
                        };
                        u = o[2];
                        M = pcall(function(...)
                            return r15(r84); 
                        end);
                        if M then
                            v3 = o[2];
                        end;
                        if M then
                            o = u;
                            r82.Data[r84] = o;
                        end;
                        v4 = r84;
                        o = v4[2];
                        v4 = v4[1];
                        for W, v6 in ipairs(v4.GetChildren(v4)) do
                            v2 = W;
                            r83(v6); 
                        end;
                        return; 
                    end;
                    pcall(function(...)
                        r83(r81);
                        return; 
                    end);
                    v6 = {
                        pairs(r82.Data)
                    };
                    v2 = pairs(r82.Data);
                    v4 = v2(v6[2], v6[3]);
                    while v4 do
                        v6 = v4;
                        r82.InstanceCount = r82.InstanceCount + 1; 
                    end;
                    table.insert(r64.Snapshots, 1, r82);
                    while #r64.Snapshots > r64.MaxSnapshots do
                        table.remove(r64.Snapshots); 
                    end;
                    r64.SnapNames = {};
                    F = r64;
                    v2 = F[3];
                    for v2, F in F[1], ipairs(F.Snapshots) do
                        v6 = v2;
                        table.insert(r64.SnapNames, {
                            ["Title"] = F.Name .. " [" .. F.InstanceCount .. "] " .. os.date("%H:%M:%S", F.Time)
                        }); 
                    end;
                    r64.SnapInProgress = false;
                    return r82, nil;
                else
                    F = "Workspace";
                end;
            else
                M = "Snap_" .. os.date("%H%M%S");
            end; 
        end;
        local function r85(arg1_26, ...)
            v1 = arg1_26;
            if not v1 or not v1.Data then
                return 0, 0, "Invalid snapshot";
            end;
            u = 0;
            v6 = "Data";
            v2 = v1[v6];
            W = v6[2];
            v2 = v6[1];
            for v4, F in pairs(v2) do
                r86 = v4;
                if typeof(r86) ~= "Instance" then
                    o = 0 + 1;
                else
                    v7 = r86;
                    if not v7.IsDescendantOf(v7, game) then
                        u = 0 + 1;
                    end;
                    if F.ParentPath then
                        r87 = r51(F.ParentPath);
                        v5 = C ~= k;
                        if r87 and r86.Parent ~= r87 then
                            if not pcall(function(...)
                                r86.Parent = r87;
                                return; 
                            end) then
                                success = false;
                            end;
                        end;
                    end;
                    A = F.ClassName;
                    if r86.ClassName ~= A then
                        u = 0 + 1;
                    else
                        r88 = F.Properties;
                        if not r88 then
                            u = 0 + 1;
                        end;
                        C = true;
                        A = r86;
                        if A.IsA(A, "BasePart") then
                            if r88.CFrame then
                                if not pcall(function(...)
                                    r86.CFrame = r69(r88.CFrame);
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Size then
                                if not pcall(function(...)
                                    r86.Size = r71(r88.Size);
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Color then
                                if not pcall(function(...)
                                    r86.Color = r73(r88.Color);
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Material then
                                if not pcall(function(...)
                                    u = r88.Material;
                                    v1 = r75("Material", u);
                                    if v1 then
                                        u = "Material";
                                        r86.Material = u;
                                    end;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Transparency ~= nil then
                                if not pcall(function(...)
                                    r86.Transparency = r88.Transparency;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Reflectance ~= nil then
                                if not pcall(function(...)
                                    r86.Reflectance = r88.Reflectance;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.CanCollide ~= nil then
                                if not pcall(function(...)
                                    r86.CanCollide = r88.CanCollide;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Anchored ~= nil then
                                if not pcall(function(...)
                                    r86.Anchored = r88.Anchored;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.CastShadow ~= nil then
                                if not pcall(function(...)
                                    r86.CastShadow = r88.CastShadow;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Locked ~= nil then
                                if not pcall(function(...)
                                    r86.Locked = r88.Locked;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Massless ~= nil then
                                if not pcall(function(...)
                                    r86.Massless = r88.Massless;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            if r88.Shape then
                                if not pcall(function(...)
                                    u = r88.Shape;
                                    v1 = r75("PartType", u);
                                    if v1 then
                                        u = r86;
                                        v3 = u.IsA(u, "Part");
                                    end;
                                    if v1 then
                                        u = v1;
                                        r86.Shape = u;
                                    end;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            X = r88.MeshId;
                            n = C ~= k;
                            if X then
                                X = r86;
                                n = X.IsA(X, "MeshPart");
                            end;
                            if n then
                                if not pcall(function(...)
                                    r86.MeshId = r88.MeshId;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                            Bd = r88.TextureID;
                            if Bd then
                                Bd = r86;
                                V = Bd.IsA(Bd, "MeshPart");
                            end;
                            v5 = C ~= k;
                            if Bd then
                                if not pcall(function(...)
                                    r86.TextureID = r88.TextureID;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            end;
                        end;
                        f = r86;
                        H = f.IsA(f, "StringValue");
                        if H then
                            X = r88.Value ~= nil;
                        end;
                        v5 = C ~= k;
                        if H then
                            if not pcall(function(...)
                                r86.Value = r88.Value;
                                return; 
                            end) then
                                C = false;
                            end;
                        else
                            H = r86;
                            Kd = H.IsA(H, "IntValue");
                            if Kd then
                                Bd = r88.Value ~= nil;
                            end;
                            v5 = Bd;
                            if Kd then
                                if not pcall(function(...)
                                    r86.Value = r88.Value;
                                    return; 
                                end) then
                                    C = false;
                                end;
                            else
                                Kd = r86;
                                Dd = Kd.IsA(Kd, "NumberValue");
                                if Dd then
                                    f = r88.Value ~= nil;
                                end;
                                v5 = f;
                                if Dd then
                                    if not pcall(function(...)
                                        r86.Value = r88.Value;
                                        return; 
                                    end) then
                                        C = false;
                                    end;
                                else
                                    Dd = r86;
                                    yd = "BoolValue";
                                    vd = Dd.IsA(Dd, yd);
                                    if vd then
                                        H = r88.Value ~= nil;
                                    end;
                                    v5 = H;
                                    if vd then
                                        if not pcall(function(...)
                                            r86.Value = r88.Value;
                                            return; 
                                        end) then
                                            C = false;
                                        end;
                                    else
                                        vd = r86;
                                        zd = "Color3Value";
                                        yd = vd.IsA(vd, zd);
                                        if yd then
                                            Kd = r88.Value;
                                        end;
                                        v5 = Kd;
                                        if yd then
                                            if not pcall(function(...)
                                                r86.Value = r73(r88.Value);
                                                return; 
                                            end) then
                                                C = false;
                                            end;
                                        else
                                            vd = Dd;
                                            yd = r86;
                                            zd = yd.IsA(yd, "Vector3Value");
                                            if zd then
                                                Dd = r88.Value;
                                            end;
                                            v5 = vd;
                                            if zd then
                                                if not pcall(function(...)
                                                    r86.Value = r71(r88.Value);
                                                    return; 
                                                end) then
                                                    C = false;
                                                end;
                                            else
                                                yd = hd;
                                                zd = r86;
                                                hd = zd.IsA(zd, "CFrameValue");
                                                vd = r16[wd];
                                                if hd then
                                                    vd = r88.Value;
                                                end;
                                                if vd then
                                                    if not pcall(function(...)
                                                        r86.Value = r69(r88.Value);
                                                        return; 
                                                    end) then
                                                        C = false;
                                                    end;
                                                end;
                                                yd = r86;
                                                ud = 2332983166014;
                                                wd = r15("I\xb2\x11\xce~", ud);
                                                if yd.IsA(yd, r16[wd]) then
                                                    if r88.Color then
                                                        if not pcall(function(...)
                                                            r86.Color = r73(r88.Color);
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Brightness ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Brightness = r88.Brightness;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Range ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Range = r88.Range;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Shadows ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Shadows = r88.Shadows;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Enabled ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Enabled = r88.Enabled;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    wd = r86;
                                                    if wd.IsA(wd, "SpotLight") then
                                                        if r88.Angle ~= nil then
                                                            if not pcall(function(...)
                                                                r86.Angle = r88.Angle;
                                                                return; 
                                                            end) then
                                                                C = false;
                                                            end;
                                                        end;
                                                        if r88.Face then
                                                            if not pcall(function(...)
                                                                u = r88.Face;
                                                                v1 = r75("NormalId", u);
                                                                if v1 then
                                                                    u = "Face";
                                                                    r86.Face = u;
                                                                end;
                                                                return; 
                                                            end) then
                                                                C = false;
                                                            end;
                                                        end;
                                                    end;
                                                    ud = r86;
                                                    if ud.IsA(ud, "SurfaceLight") then
                                                        if r88.Angle ~= nil then
                                                            if not pcall(function(...)
                                                                r86.Angle = r88.Angle;
                                                                return; 
                                                            end) then
                                                                C = false;
                                                            end;
                                                        end;
                                                        if r88.Face then
                                                            if not pcall(function(...)
                                                                u = r88.Face;
                                                                v1 = r75("NormalId", u);
                                                                if v1 then
                                                                    u = "Face";
                                                                    r86.Face = u;
                                                                end;
                                                                return; 
                                                            end) then
                                                                C = false;
                                                            end;
                                                        end;
                                                    end;
                                                end;
                                                Rd = r86;
                                                Ld = Rd.IsA(Rd, "Decal");
                                                v5 = yd;
                                                if Ld or Rd.IsA(Rd, "Texture") then
                                                    if r88.Texture then
                                                        if not pcall(function(...)
                                                            r86.Texture = r88.Texture;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Transparency ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Transparency = r88.Transparency;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Face then
                                                        if not pcall(function(...)
                                                            u = r88.Face;
                                                            v1 = r75("NormalId", u);
                                                            if v1 then
                                                                u = "Face";
                                                                r86.Face = u;
                                                            end;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    Ld = r86;
                                                    if Ld.IsA(Ld, "Texture") then
                                                        if r88.StudsPerTileU ~= nil then
                                                            if not pcall(function(...)
                                                                r86.StudsPerTileU = r88.StudsPerTileU;
                                                                return; 
                                                            end) then
                                                                C = false;
                                                            end;
                                                        end;
                                                        if r88.StudsPerTileV ~= nil then
                                                            if not pcall(function(...)
                                                                r86.StudsPerTileV = r88.StudsPerTileV;
                                                                return; 
                                                            end) then
                                                                C = false;
                                                            end;
                                                        end;
                                                    end;
                                                end;
                                                Yd = r86;
                                                if Yd.IsA(Yd, "Sound") then
                                                    if r88.SoundId then
                                                        if not pcall(function(...)
                                                            r86.SoundId = r88.SoundId;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Volume ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Volume = r88.Volume;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.PlaybackSpeed ~= nil then
                                                        if not pcall(function(...)
                                                            r86.PlaybackSpeed = r88.PlaybackSpeed;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Looped ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Looped = r88.Looped;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.RollOffMode then
                                                        if not pcall(function(...)
                                                            u = r88.RollOffMode;
                                                            v1 = r75("RollOffMode", u);
                                                            if v1 then
                                                                u = "RollOffMode";
                                                                r86.RollOffMode = u;
                                                            end;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.RollOffMaxDistance ~= nil then
                                                        if not pcall(function(...)
                                                            r86.RollOffMaxDistance = r88.RollOffMaxDistance;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.RollOffMinDistance ~= nil then
                                                        if not pcall(function(...)
                                                            r86.RollOffMinDistance = r88.RollOffMinDistance;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                end;
                                                pd = r86;
                                                if pd.IsA(pd, "ParticleEmitter") then
                                                    if r88.Color then
                                                        if not pcall(function(...)
                                                            r86.Color = r88.Color;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Size then
                                                        if not pcall(function(...)
                                                            r86.Size = r88.Size;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Transparency then
                                                        if not pcall(function(...)
                                                            r86.Transparency = r88.Transparency;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Lifetime then
                                                        if not pcall(function(...)
                                                            r86.Lifetime = r88.Lifetime;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Rate ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Rate = r88.Rate;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Speed then
                                                        if not pcall(function(...)
                                                            r86.Speed = r88.Speed;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.LightEmission ~= nil then
                                                        if not pcall(function(...)
                                                            r86.LightEmission = r88.LightEmission;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.LightInfluence ~= nil then
                                                        if not pcall(function(...)
                                                            r86.LightInfluence = r88.LightInfluence;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Texture then
                                                        if not pcall(function(...)
                                                            r86.Texture = r88.Texture;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Enabled ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Enabled = r88.Enabled;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                end;
                                                id = r86;
                                                if id.IsA(id, "Attachment") then
                                                    if r88.Position then
                                                        if not pcall(function(...)
                                                            r86.Position = r71(r88.Position);
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Orientation then
                                                        if not pcall(function(...)
                                                            r86.Orientation = r71(r88.Orientation);
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Axis then
                                                        if not pcall(function(...)
                                                            r86.Axis = r71(r88.Axis);
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.SecondaryAxis then
                                                        if not pcall(function(...)
                                                            r86.SecondaryAxis = r71(r88.SecondaryAxis);
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Visible ~= nil then
                                                        if not pcall(function(...)
                                                            r86.Visible = r88.Visible;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                end;
                                                ld = r86;
                                                if ld.IsA(ld, "SpecialMesh") then
                                                    if r88.MeshType then
                                                        if not pcall(function(...)
                                                            u = r88.MeshType;
                                                            v1 = r75("MeshType", u);
                                                            if v1 then
                                                                u = "MeshType";
                                                                r86.MeshType = u;
                                                            end;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.MeshId then
                                                        if not pcall(function(...)
                                                            r86.MeshId = r88.MeshId;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.TextureId then
                                                        if not pcall(function(...)
                                                            r86.TextureId = r88.TextureId;
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Scale then
                                                        if not pcall(function(...)
                                                            r86.Scale = r71(r88.Scale);
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                    if r88.Offset then
                                                        if not pcall(function(...)
                                                            r86.Offset = r71(r88.Offset);
                                                            return; 
                                                        end) then
                                                            C = false;
                                                        end;
                                                    end;
                                                end;
                                                Hd = "M\xd6\x9d\xc2\xc7\xc4*\xa1\xd7\xfc";
                                                if F[r16[r15(Hd, 23599227546349)]] then
                                                    Hd = "Attributes";
                                                    fd = F[Hd];
                                                    nd = Hd[2];
                                                    Xd = Hd[3];
                                                    for Xd, fd in pairs(fd) do
                                                        r89 = Xd;
                                                        r90 = fd;
                                                        if not pcall(function(...)
                                                            v5 = r90.Type == "Vector3";
                                                            if v5 then
                                                                v5 = r86;
                                                                v5.SetAttribute(v5, r89, r71(r90.Value));
                                                            else
                                                                v5 = r90.Type == "CFrame";
                                                                if v5 then
                                                                    v5 = r86;
                                                                    v5.SetAttribute(v5, r89, r69(r90.Value));
                                                                else
                                                                    v5 = r90.Type == "Color3";
                                                                    if v5 then
                                                                        v5 = r86;
                                                                        v5.SetAttribute(v5, r89, r73(r90.Value));
                                                                    else
                                                                        v5 = r86;
                                                                        v5.SetAttribute(v5, r89, r90.Value);
                                                                    end;
                                                                    return;
                                                                end;
                                                            end; 
                                                        end) then
                                                            C = false;
                                                        end; 
                                                    end;
                                                end;
                                                if true then
                                                    M = 0 + 1;
                                                else
                                                    o = 0 + 1;
                                                end;
                                            end;
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end; 
            end;
            return 0, 0, nil; 
        end;
        local function Wd(arg1_27, ...)
            v1 = arg1_27;
            if v1 >= 1 and v1 <= #r64.Snapshots then
                table.remove(r64.Snapshots, v1);
                r64.SnapNames = {};
                W = r64;
                o = W.Snapshots;
                M = W[3];
                u = W[2];
                for M, v4 in ipairs("ipairs") do
                    W = M;
                    table.insert(r64.SnapNames, {
                        ["Title"] = v4.Name .. " [" .. v4.InstanceCount .. "] " .. os.date("%H:%M:%S", v4.Time)
                    }); 
                end;
                return true;
            end;
            return false; 
        end;
        local function r91(...)
            v1 = r27.Character;
            if not v1 then
                return false;
            end;
            u = v1.FindFirstChild(v1, "HumanoidRootPart");
            if not u then
                return false;
            end;
            M = v1.FindFirstChildOfClass(v1, "Humanoid");
            v5 = table.insert;
            k = v5;
            v8 = v5;
            if M then
                T = M.Health;
            end;
            v5 = v5;
            v5(r65.Snaps, {
                ["CFrame"] = u.CFrame,
                ["CamCFrame"] = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or nil,
                ["Time"] = tick(),
                ["Health"] = M or nil
            });
            if #r65.Snaps > r65.MaxSnaps then
                table.remove(r65.Snaps, 1);
            end;
            return true; 
        end;
        local function qd(arg1_28, ...)
            r93 = arg1_28;
            r92 = task.spawn(function(...)
                while r64.AutoSnapEnabled do
                    task.wait(r93);
                    if r64.AutoSnapEnabled then
                        pcall(function(...)
                            r80(r67, "Auto_" .. os.date("%H%M%S"));
                            return; 
                        end);
                    end; 
                end;
                return; 
            end);
            return; 
        end;
        local function r94(...)
            v5 = r27;
            v4 = "\xa7T\x9b\xe4\x1d\x98\r\xf1";
            u = v5.FindFirstChild(v5, r16[r15(v4, 443307032782)]);
            if u then
                v4 = u.GetChildren;
                W = {
                    v4(u)
                };
                o = v4[3];
                M = v4[2];
                for o, v2 in ipairs(D("ipairs")) do
                    v4 = o;
                    table.insert({}, v2.Name); 
                end;
            end;
            M = r27.Character;
            if M then
                v6 = M.GetChildren;
                W = v6[2];
                v4 = v6[3];
                for v4, v6 in ipairs(v6(M)) do
                    v2 = v4;
                    if v6.IsA(v6, "Tool") then
                        table.insert({}, v6.Name);
                    end; 
                end;
            end;
            return {}; 
        end;
        local function sd(arg1_29, ...)
            M = math.max(1, math.min(#r65.Snaps - (arg1_29 or 1), #r65.Snaps));
            if M < 1 then
                M = 1;
            end;
            o = r65.Snaps[M];
            if not o then
                return false;
            end;
            W = r27.Character;
            if not W then
                return false;
            end;
            v4 = W.FindFirstChild(W, "HumanoidRootPart");
            if not v4 then
                return false;
            end;
            v4.CFrame = o.CFrame;
            v5 = P[u];
            if o.CamCFrame and workspace.CurrentCamera then
                workspace.CurrentCamera.CFrame = o.CamCFrame;
            end;
            return true; 
        end;
        local function td(arg1_30, ...)
            r95 = arg1_30;
            v5 = r65.Conn;
            if v5 then
                v5 = r65.Conn;
                v5.Disconnect(v5);
            end;
            r65.Enabled = true;
            r65.Snaps = {};
            M = game;
            u = M.GetService(M, "RunService").Heartbeat;
            r65.Conn = u.Connect(u, function(...)
                if not r65.Enabled then
                    return;
                end;
                if tick() % r95 < .016666666666667 then
                    r91();
                end;
                return; 
            end);
            return; 
        end;
        local function r96(...)
            o = r24;
            M = o[3];
            o = o[1];
            for M, v4 in o, ipairs(o.GetPlayers(o)) do
                W = M;
                if v4 ~= r27 then
                    table.insert({}, v4);
                end; 
            end;
            return {}; 
        end;
        local function Td(arg1_31, arg2_31, ...)
            v5 = r27;
            u = arg2_31;
            v1 = arg1_31;
            M = v5.FindFirstChild(v5, "Backpack");
            o = r27.Character;
            if M then
                W = M.FindFirstChild(M, v1);
            end;
            v2 = not nil;
            if v2 then
                v3 = r27[r16[r15(v6, F)]];
            end;
            if v2 then
                W = o.FindFirstChild(o, v1);
            end;
            if not nil then
                return false, "Item not found";
            end;
            v2 = u.FindFirstChild(u, "Backpack");
            if v2 then
                F = u.FindFirstChild(u, v6);
                nil.Clone(nil).Parent = F;
                return true, "Cloned '" .. v1 .. "' to " .. u.Name;
            end;
            return false, "Target has no Backpack"; 
        end;
        local function id(arg1_32, arg2_32, ...)
            v5 = r27;
            v1 = arg1_32;
            u = arg2_32;
            M = v5.FindFirstChild(v5, "Backpack");
            if not M then
                return false, "No Backpack";
            end;
            o = r80(M, "TradeDupe_" .. v1);
            if not o then
                return false, "Snapshot failed";
            end;
            r66.LastSnap = o;
            r97 = M.FindFirstChild(M, v1);
            if not r97 then
                v4 = r27.Character;
                if v4 then
                    r97 = v4.FindFirstChild(v4, arg1_32);
                end;
            end;
            if not r97 then
                return false, "Item '" .. v1 .. "' not found";
            end;
            v3 = r97;
            v2 = u.FindFirstChild(u, "Backpack");
            if not v2 then
                return false, "Target has no Backpack";
            end;
            v3.Clone(v3).Parent = v2;
            r98 = Instance.new("Folder");
            r98.Name = "ValenHub_Temp";
            k = game;
            r98.Parent = k.GetService(k, "ReplicatedStorage");
            pcall(function(...)
                r97.Parent = r98;
                return; 
            end);
            task.wait(.1);
            q = {
                r85(o)
            };
            C = q[3];
            k = q[2];
            pcall(function(...)
                v5 = r98;
                v5.Destroy(v5);
                return; 
            end);
            if C then
                return false, "Rollback error: " .. tostring(C);
            end;
            return true, "Dupe OK! Restored " .. r85(o) .. " items. Clone sent to " .. u.Name; 
        end;
        local function r99(arg1_33, arg2_33, ...)
            v1 = arg1_33;
            u = arg2_33;
            if u then
                u = u;
                M = typeof(v1);
                if M == "string" then
                    return string.format("%q", arg1_33);
                end;
                if M == "number" or M == "boolean" then
                    return tostring(arg1_33);
                end;
                if M == "nil" then
                    return "nil";
                end;
                if M == "Vector3" then
                    return string.format("Vector3.new(%s, %s, %s)", tostring(v1.X), tostring(v1.Y), tostring(v1.Z));
                end;
                if M == "Vector2" then
                    return string.format("Vector2.new(%s, %s)", tostring(v1.X), tostring(v1.Y));
                end;
                if M == "Color3" then
                    return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(v1.R * 255), math.floor(v1.v8 * 255), math.floor(v1.B * 255));
                end;
                if M == "CFrame" then
                    T = {
                        v1.GetComponents(v1)
                    };
                    return string.format("CFrame.new(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)", tostring(v1.GetComponents(v1)), tostring(T[2]), tostring(T[3]), tostring(T[4]), tostring(T[5]), tostring(T[6]), tostring(T[7]), tostring(T[8]), tostring(T[9]), tostring(T[10]), tostring(T[11]), tostring(T[12]));
                end;
                if M == "UDim" then
                    return string.format("UDim.new(%s, %s)", tostring(v1.Scale), tostring(v1.Offset));
                end;
                if M == "UDim2" then
                    return string.format("UDim2.new(%s, %s, %s, %s)", tostring(v1.X.Scale), tostring(v1.X.Offset), tostring(v1.Y.Scale), tostring(v1.Y.Offset));
                end;
                if M == "EnumItem" then
                    return tostring(arg1_33);
                end;
                if M == "BrickColor" then
                    return string.format("BrickColor.new(%q)", tostring(arg1_33));
                end;
                if M == "NumberRange" then
                    return string.format("NumberRange.new(%s, %s)", tostring(v1.Min), tostring(v1.Max));
                end;
                if M == "NumberSequence" then
                    return string.format("NumberSequence.new(%s)", tostring(arg1_33));
                end;
                if M == "ColorSequence" then
                    return string.format("ColorSequence.new(%s)", tostring(arg1_33));
                end;
                o = "table";
                if M == o then
                    if u[v1] then
                        return "nil --[[circular]]";
                    end;
                    u[v1] = true;
                    o = {};
                    v2 = ("\xa9F\x00\x0e\x01")[3];
                    for v2, F in ("\xa9F\x00\x0e\x01")[1], pairs(v1) do
                        table.insert(o, "[" .. r99(v2, v3) .. "] = " .. r99(F, v3)); 
                    end;
                    return "{" .. table.concat(o, ", ") .. "}";
                end;
                return "nil --[[" .. M .. "]]";
            else
                v3 = {};
            end; 
        end;
        local function r100(arg1_34, ...)
            v1 = arg1_34;
            return v1.gsub(v1, "[^%w_]", "_"); 
        end;
        local function r101(arg1_35, arg2_35, arg3_35, arg4_35, ...)
            W = {};
            r102 = arg1_35;
            r103 = arg2_35;
            r104 = arg3_35;
            r105 = arg4_35;
            table.insert(W, "-- ============================================================");
            table.insert(W, "--  Valen Hub | Map Reconstructor for Roblox Studio");
            table.insert(W, "--  Game PlaceId: " .. tostring(game.PlaceId));
            table.insert(W, "--  Generated: " .. os.date("%Y-%m-%d %H:%M:%S"));
            table.insert(W, "--  HOW TO USE:");
            table.insert(W, "--  1. Open Roblox Studio");
            table.insert(W, "--  2. Open Command Bar (View > Command Bar)");
            table.insert(W, "--  3. Paste this entire script into the Command Bar");
            table.insert(W, "--  4. Press Enter - the map will be built in Workspace");
            table.insert(W, "-- ============================================================");
            table.insert(W, "");
            table.insert(W, "local MapFolder = Instance.new(\"Folder\")");
            table.insert(W, "MapFolder.Name = \"" .. r102 .. "\"");
            table.insert(W, "MapFolder.Parent = workspace");
            table.insert(W, "");
            r106 = {};
            r107 = 0;
            local function r108(arg1_36, ...)
                v1 = arg1_36;
                if v1.Name == r102 then
                    return true;
                end;
                if not r103 and v1.IsA(v1, "Terrain") then
                    return true;
                end;
                u = not r104;
                v3 = not r105;
                if u then
                    v5 = v1[r16[W]] == r102;
                    v3 = v1.IsA(v1, "Script") or (v1.IsA(v1, "LocalScript") or v1.IsA(v1, "ModuleScript"));
                end;
                if v3 then
                    return true;
                end;
                u = not r105;
                v3 = v1.IsA(v1, "Camera");
                if u then
                    v3 = v1.IsA(v1, "Humanoid") or (v1.IsA(v1, "Animator") or v1.IsA(v1, "HumanoidDescription"));
                    v5 = v1[r16[W]] == r102;
                end;
                if v3 then
                    return true;
                end;
                if v1.IsA(v1, "Camera") and v1.Parent == workspace then
                    return true;
                end;
                return false; 
            end;
            q = (function(arg1_37, ...)
                r109 = {};
                local function r110(arg1_38, ...)
                    v1 = arg1_38;
                    if r108(v1) then
                        return;
                    end;
                    table.insert(r109, v1);
                    W = v1.GetChildren;
                    o = {
                        W(v1)
                    };
                    M = W[3];
                    u = W[2];
                    for M, v4 in ipairs(D("ipairs")) do
                        W = M;
                        r110(v4); 
                    end;
                    return; 
                end;
                r110(arg1_37);
                return r109; 
            end)(workspace);
            v7 = #q;
            T = ("\xf1\xa2\x04-Zj\x14")[3];
            A = ("\xf1\xa2\x04-Zj\x14")[1];
            for T, i in A, ipairs(q) do
                r111 = i;
                r = (function(arg1_39, ...)
                    v1 = arg1_39;
                    if not r106[v1] then
                        r107 = r107 + 1;
                        r106[v1] = "_obj" .. r107;
                    end;
                    return r106[v1]; 
                end)(r111);
                Z = r111.ClassName;
                table.insert(W, "-- [" .. T .. "/" .. v7 .. "] " .. r100(r111.Name) .. " (" .. Z .. ")");
                table.insert(W, "local " .. r .. " = Instance.new(\"" .. Z .. "\")");
                Ud = r111.Name;
                H = 32302838708930;
                V = r16;
                Bd = r15("R", H);
                table.insert(W, r .. ".Name = \"" .. Ud.gsub(Ud, "\"", "\\\"") .. V[Bd]);
                v5 = r111;
                I = r16;
                N = r15;
                if v5.IsA(v5, "BasePart") then
                    g = "Material";
                    V = "CanCollide";
                    Bd = "CastShadow";
                    N = g[3];
                    I = g[2];
                    for N, Ud in ipairs({
                        "Position",
                        "Size",
                        "Orientation",
                        "Color",
                        g,
                        "Transparency",
                        "Reflectance",
                        V,
                        "Anchored",
                        Bd,
                        "Locked",
                        "Massless",
                        "TopSurface",
                        "BottomSurface",
                        "LeftSurface",
                        "RightSurface",
                        "FrontSurface",
                        "BackSurface"
                    }) do
                        g = N;
                        r112 = Ud;
                        Bd = {
                            pcall(function(...)
                                return r111[r112]; 
                            end)
                        };
                        V = Bd[2];
                        if pcall(function(...)
                            return r111[r112]; 
                        end) then
                            if r112 == "Orientation" then
                                table.insert({}, F(P[i]) .. ".Rotation = Vector3.new(" .. tostring(V.X) .. ", " .. tostring(V.Y) .. ", " .. tostring(V.Z) .. ")");
                            else
                                if r112 == "Color" then
                                    table.insert({}, F(P[i]) .. ".Color = Color3.fromRGB(" .. math.floor(V.R * 255) .. ", " .. math.floor(V.v8 * 255) .. ", " .. math.floor(V.B * 255) .. ")");
                                else
                                    if r112 == "Material" then
                                        table.insert({}, F(P[i]) .. ".Material = Enum.Material." .. tostring(Bd[2]));
                                    else
                                        if r112 == "TopSurface" or (r112 == "BottomSurface" or (r112 == "LeftSurface" or (r112 == "RightSurface" or (r112 == "FrontSurface" or r112 == "BackSurface")))) then
                                            table.insert({}, F(P[i]) .. "." .. r112 .. " = Enum.SurfaceType." .. tostring(Bd[2]));
                                        else
                                            if type(V) == "boolean" or type(V) == "number" then
                                                table.insert({}, F(P[i]) .. "." .. r112 .. " = " .. tostring(Bd[2]));
                                            end;
                                        end;
                                    end;
                                end;
                            end;
                        end; 
                    end;
                    I = r111;
                    N = I.IsA(I, "Part");
                    if N then
                        e = r111.Shape ~= Enum.PartType.Block;
                    end;
                    if N then
                        table.insert({}, F(P[i]) .. ".Shape = Enum.PartType." .. tostring(r111.Shape));
                    end;
                end;
                v5 = r111;
                if v5.IsA(v5, "MeshPart") then
                    N = {
                        pcall(function(...)
                            return r111.MeshId; 
                        end)
                    };
                    e = N[2];
                    J = pcall(function(...)
                        return r111.MeshId; 
                    end);
                    if J then
                        I = e and e ~= "";
                        v5 = pcall;
                    end;
                    if J then
                        table.insert({}, F(P[i]) .. ".MeshId = \"" .. e .. "\"");
                    end;
                    Ud = {
                        pcall(function(...)
                            return r111.TextureID; 
                        end)
                    };
                    N = Ud[2];
                    I = pcall(function(...)
                        return r111.TextureID; 
                    end);
                    if I then
                        if N then
                            Ud = Ud[2] ~= "";
                        end;
                        v5 = pcall;
                        g = N;
                    end;
                    if I then
                        table.insert({}, F(P[i]) .. ".TextureID = \"" .. N .. "\"");
                    end;
                    if pcall(function(...)
                        return r111.RenderFidelity; 
                    end) then
                        table.insert({}, F(P[i]) .. ".RenderFidelity = Enum.RenderFidelity." .. tostring(V[2]));
                    end;
                end;
                v5 = r111;
                if v5.IsA(v5, "SpecialMesh") then
                    if pcall(function(...)
                        return r111.MeshType; 
                    end) then
                        table.insert({}, F(P[i]) .. ".MeshType = Enum.MeshType." .. tostring(N[2]));
                    end;
                    Ud = {
                        pcall(function(...)
                            return r111.MeshId; 
                        end)
                    };
                    N = Ud[2];
                    I = pcall(function(...)
                        return r111.MeshId; 
                    end);
                    if I then
                        if N then
                            Ud = Ud[2] ~= "";
                        end;
                        v5 = pcall;
                        g = N;
                    end;
                    if I then
                        table.insert({}, F(P[i]) .. ".MeshId = \"" .. N .. "\"");
                    end;
                    V = {
                        pcall(function(...)
                            return r111.TextureId; 
                        end)
                    };
                    g = pcall(function(...)
                        return r111.TextureId; 
                    end);
                    Ud = V[2];
                    if g then
                        if Ud then
                            V = V[2] ~= "";
                        end;
                        v5 = pcall;
                        n = Ud;
                    end;
                    if g then
                        table.insert({}, F(P[i]) .. ".TextureId = \"" .. Ud .. "\"");
                    end;
                    if pcall(function(...)
                        return r111.Scale; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Scale = " .. r99(Bd[2]));
                    end;
                    if pcall(function(...)
                        return r111.Offset; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Offset = " .. r99(H[2]));
                    end;
                end;
                e = r111;
                N = "UnionOperation";
                if e.IsA(e, N) or e.IsA(e, "NegateOperation") then
                    if pcall(function(...)
                        return r111.UsePartColor; 
                    end) then
                        table.insert({}, F(P[i]) .. ".UsePartColor = " .. tostring(N[2]));
                    end;
                end;
                e = r111;
                if e.IsA(e, "Decal") or e.IsA(e, "Texture") then
                    N = {
                        pcall(function(...)
                            return r111.Texture; 
                        end)
                    };
                    J = pcall(function(...)
                        return r111.Texture; 
                    end);
                    e = N[2];
                    if J then
                        if e then
                            N = N[2] ~= "";
                        end;
                        v5 = pcall;
                        I = e;
                    end;
                    if J then
                        table.insert({}, F(P[i]) .. ".Texture = \"" .. e .. "\"");
                    end;
                    if pcall(function(...)
                        return r111.Face; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Face = Enum.NormalId." .. tostring(Ud[2]));
                    end;
                    v5 = r111;
                    Bd = "\xdaSd'\x11\xba\xc3";
                    if v5.IsA(v5, r16[r15(Bd, 14135033338294)]) then
                        if pcall(function(...)
                            return r111.StudsPerTileU; 
                        end) then
                            table.insert({}, F(P[i]) .. ".StudsPerTileU = " .. tostring(V[2]));
                        end;
                        if pcall(function(...)
                            return r111.StudsPerTileV; 
                        end) then
                            table.insert({}, F(P[i]) .. ".StudsPerTileV = " .. tostring(Bd[2]));
                        end;
                    end;
                end;
                v5 = r111;
                if v5.IsA(v5, "Light") then
                    Bd = 22834102610312;
                    g = r16[r15("\xc2\xf6r\xf5(\xb4\x1b", Bd)];
                    N = g[3];
                    for N, Ud in g[1], ipairs({
                        "Color",
                        "Brightness",
                        "Range",
                        "Shadows",
                        g
                    }) do
                        g = N;
                        r113 = Ud;
                        Bd = {
                            pcall(function(...)
                                return r111[r113]; 
                            end)
                        };
                        V = Bd[2];
                        if pcall(function(...)
                            return r111[r113]; 
                        end) then
                            if r113 == "Color" then
                                table.insert({}, F(P[i]) .. ".Color = Color3.fromRGB(" .. math.floor(V.R * 255) .. ", " .. math.floor(V.v8 * 255) .. ", " .. math.floor(V.B * 255) .. ")");
                            else
                                table.insert({}, F(P[i]) .. "." .. r113 .. " = " .. tostring(Bd[2]));
                            end;
                        end; 
                    end;
                    n = "ed\xf9\xcdKY\x9aRt";
                    v5 = r111;
                    if v5.IsA(v5, r16[r15(n, 17853985710201)]) then
                        if pcall(function(...)
                            return r111.Angle; 
                        end) then
                            table.insert({}, F(P[i]) .. ".Angle = " .. tostring(g[2]));
                        end;
                        if pcall(function(...)
                            return r111.Face; 
                        end) then
                            table.insert({}, F(P[i]) .. ".Face = Enum.NormalId." .. tostring(n[2]));
                        end;
                    end;
                    v5 = r111;
                    n = "\xba\xf5\xe3\xd6\xef\xd1\xdff\x03\xbd\x84\xc7";
                    if v5.IsA(v5, r16[r15(n, 28721436341310)]) then
                        if pcall(function(...)
                            return r111.Angle; 
                        end) then
                            table.insert({}, F(P[i]) .. ".Angle = " .. tostring(g[2]));
                        end;
                        if pcall(function(...)
                            return r111.Face; 
                        end) then
                            table.insert({}, F(P[i]) .. ".Face = Enum.NormalId." .. tostring(n[2]));
                        end;
                    end;
                end;
                v5 = r111;
                if v5.IsA(v5, "SpawnLocation") then
                    if pcall(function(...)
                        return r111.Duration; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Duration = " .. tostring(N[2]));
                    end;
                    if pcall(function(...)
                        return r111.Neutral; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Neutral = " .. tostring(Ud[2]));
                    end;
                    if pcall(function(...)
                        return r111.TeamColor; 
                    end) then
                        table.insert({}, F(P[i]) .. ".TeamColor = BrickColor.new(\"" .. tostring(V[2]) .. "\")");
                    end;
                    if pcall(function(...)
                        return r111.AllowTeamChangeOnTouch; 
                    end) then
                        table.insert({}, F(P[i]) .. ".AllowTeamChangeOnTouch = " .. tostring(Bd[2]));
                    end;
                end;
                e = r111;
                if e.IsA(e, "Seat") or e.IsA(e, "VehicleSeat") then
                    if pcall(function(...)
                        return r111.MaxSpeed; 
                    end) then
                        table.insert({}, F(P[i]) .. ".MaxSpeed = " .. tostring(N[2]));
                    end;
                    v5 = r111;
                    V = "H\xbf\xf8\x1a\xdbl\xfa\x03\xca\x86\xb9";
                    if v5.IsA(v5, r16[r15(V, 25325801795089)]) then
                        if pcall(function(...)
                            return r111.Torque; 
                        end) then
                            table.insert({}, F(P[i]) .. ".Torque = " .. tostring(Ud[2]));
                        end;
                        if pcall(function(...)
                            return r111.TurnSpeed; 
                        end) then
                            table.insert({}, F(P[i]) .. ".TurnSpeed = " .. tostring(V[2]));
                        end;
                    end;
                end;
                v5 = r111;
                g = r15("0\xd3\xc1\xdb\xea", 10684391035759);
                if v5.IsA(v5, r16[g]) then
                    g = "Playing";
                    Bd = r15;
                    V = "RollOffMinDistance";
                    N = g[3];
                    for N, Ud in g[1], ipairs({
                        "SoundId",
                        "Volume",
                        "PlaybackSpeed",
                        "Looped",
                        g,
                        "RollOffMode",
                        "RollOffMaxDistance",
                        V
                    }) do
                        r114 = Ud;
                        g = N;
                        Bd = {
                            pcall(function(...)
                                return r111[r114]; 
                            end)
                        };
                        V = Bd[2];
                        if pcall(function(...)
                            return r111[r114]; 
                        end) then
                            if type(V) == "string" then
                                table.insert({}, F(P[i]) .. "." .. r114 .. " = \"" .. Bd[2] .. "\"");
                            else
                                if type(V) == "boolean" or type(V) == "number" then
                                    table.insert({}, F(P[i]) .. "." .. r114 .. " = " .. tostring(Bd[2]));
                                else
                                    if r114 == "RollOffMode" then
                                        table.insert({}, F(P[i]) .. ".RollOffMode = Enum.RollOffMode." .. tostring(Bd[2]));
                                    end;
                                end;
                            end;
                        end; 
                    end;
                end;
                v5 = r111;
                g = r15("\xcc\xdb\x87f6\x93mH\x99g\xd1\xa9:0\xca", 19655818798016);
                if v5.IsA(v5, r16[g]) then
                    g = "Rate";
                    Bd = "LightEmission";
                    I = g[2];
                    e = g[1];
                    for N, Ud in ipairs({
                        "Color",
                        "Size",
                        "Transparency",
                        "Lifetime",
                        g,
                        "Speed",
                        "SpreadAngle",
                        "Acceleration",
                        "RotSpeed",
                        Bd,
                        "LightInfluence",
                        "Texture"
                    }) do
                        g = N;
                        r115 = Ud;
                        Bd = {
                            pcall(function(...)
                                return r111[r115]; 
                            end)
                        };
                        n = pcall(function(...)
                            return r111[r115]; 
                        end);
                        V = Bd[2];
                        if n then
                            X = V ~= nil;
                        end;
                        if n then
                            table.insert({}, F(P[i]) .. "." .. r115 .. " = " .. r99(V));
                        end; 
                    end;
                end;
                v5 = r111;
                n = 23255876348493;
                if v5.IsA(v5, r16[r15("1r\xb2\x9c", n)]) then
                    g = "CurveSize0";
                    Bd = "Segments";
                    I = g[2];
                    e = g[1];
                    for N, Ud in ipairs({
                        "Color",
                        "Transparency",
                        "Width0",
                        "Width1",
                        g,
                        "CurveSize1",
                        "FaceCamera",
                        "LightEmission",
                        "LightInfluence",
                        Bd,
                        "Texture",
                        "TextureLength",
                        "TextureMode",
                        "TextureSpeed"
                    }) do
                        g = N;
                        r116 = Ud;
                        Bd = {
                            pcall(function(...)
                                return r111[r116]; 
                            end)
                        };
                        V = Bd[2];
                        n = pcall(function(...)
                            return r111[r116]; 
                        end);
                        if n then
                            X = V ~= nil;
                        end;
                        if n then
                            if type(V) == "string" then
                                table.insert({}, F(P[i]) .. "." .. r116 .. " = \"" .. Bd[2] .. "\"");
                            else
                                if type(V) == "boolean" or type(V) == "number" then
                                    table.insert({}, F(P[i]) .. "." .. r116 .. " = " .. tostring(Bd[2]));
                                else
                                    if r116 == "TextureMode" then
                                        table.insert({}, F(P[i]) .. ".TextureMode = Enum.TextureMode." .. tostring(Bd[2]));
                                    else
                                        table.insert({}, F(P[i]) .. "." .. r116 .. " = " .. r99(Bd[2]));
                                    end;
                                end;
                            end;
                        end; 
                    end;
                    g = {
                        pcall(function(...)
                            return r111.Attachment0; 
                        end)
                    };
                    I = g[2];
                    e = pcall(function(...)
                        return r111.Attachment0; 
                    end);
                    n = {
                        pcall(function(...)
                            return r111.Attachment1; 
                        end)
                    };
                    g = n[2];
                    N = pcall(function(...)
                        return r111.Attachment1; 
                    end);
                    if e then
                        Ud = I and r106[I];
                        v5 = pcall;
                    end;
                    if e then
                        table.insert({}, F(P[i]) .. ".Attachment0 = " .. r106[I]);
                    end;
                    if N then
                        if g then
                            n = r106[n[2]];
                        end;
                        v5 = pcall;
                        Ud = g;
                    end;
                    if N then
                        table.insert({}, F(P[i]) .. ".Attachment1 = " .. r106[g]);
                    end;
                end;
                v5 = r111;
                g = r15("\xf6\x1a\xad\xb5Uwu]\x05\x94", 5866473835179);
                if v5.IsA(v5, r16[g]) then
                    if pcall(function(...)
                        return r111.Position; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Position = " .. r99(N[2]));
                    end;
                    if pcall(function(...)
                        return r111.Orientation; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Orientation = " .. r99(Ud[2]));
                    end;
                    if pcall(function(...)
                        return r111.Axis; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Axis = " .. r99(V[2]));
                    end;
                    if pcall(function(...)
                        return r111.SecondaryAxis; 
                    end) then
                        table.insert({}, F(P[i]) .. ".SecondaryAxis = " .. r99(Bd[2]));
                    end;
                    if pcall(function(...)
                        return r111.Visible; 
                    end) then
                        table.insert({}, F(P[i]) .. ".Visible = " .. tostring(H[2]));
                    end;
                end;
                v5 = r111;
                I = g[2];
                e = g[1];
                for N, Ud in pairs(v5.GetAttributes(v5)) do
                    table.insert({}, r .. ":SetAttribute(\"" .. N.gsub(N, "\"", "\\\"") .. "\", " .. r99(Ud) .. ")"); 
                end;
                if r111.Parent == workspace then
                    table.insert({}, r .. ".Parent = MapFolder");
                else
                    if r106[r111.Parent] then
                        table.insert({}, F(P[i]) .. ".Parent = " .. r106[r111.Parent]);
                    end;
                    table.insert({}, "");
                end; 
            end;
            b = r15;
            table.insert(W, "-- Parent assignments");
            v8 = b[1];
            T = b[2];
            for A, i in ipairs({}) do
                b = A;
                table.insert(W, i); 
            end;
            table.insert(W, "");
            table.insert(W, "print(\"[ValenHub] Map reconstructed! Total instances: \" .. " .. tostring(v7) .. ")");
            table.insert(W, "print(\"[ValenHub] Folder: \" .. MapFolder.Name)");
            return table.concat(W, "\n"), v7; 
        end;
        local function r117(arg1_40, ...)
            r118 = arg1_40;
            task.spawn(function(...)
                v5 = r31;
                v5.Notify(v5, {
                    ["Title"] = "Map Dump",
                    ["Desc"] = "Scanning workspace... This may take a moment."
                });
                o = {
                    pcall(function(...)
                        v4 = {
                            P[97](MapFolderName, MapIncludeTerrain, MapIncludeScripts, MapIncludeCharacters)
                        };
                        return P[97](MapFolderName, MapIncludeTerrain, MapIncludeScripts, MapIncludeCharacters), v4[2]; 
                    end)
                };
                v5 = not pcall(function(...)
                    v4 = {
                        P[97](MapFolderName, MapIncludeTerrain, MapIncludeScripts, MapIncludeCharacters)
                    };
                    return P[97](MapFolderName, MapIncludeTerrain, MapIncludeScripts, MapIncludeCharacters), v4[2]; 
                end);
                u = o[3];
                v1 = o[2];
                if v5 then
                    v5 = r31;
                    v5.Notify(v5, {
                        ["Title"] = "Map Dump",
                        ["Desc"] = "Failed: " .. tostring(v1)
                    });
                    return;
                end;
                r63.DumpedText = v1;
                if r118 then
                    v5 = r57;
                    W = v5(v1, MapFolderName .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".lua");
                    if W then
                        v2 = v3;
                        r63.LastFilePath = v2;
                    end;
                    if setclipboard and (r63.DumpedText and r63.DumpedText ~= "") then
                        pcall(function(...)
                            setclipboard(r63.DumpedText);
                            return; 
                        end);
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Map Dump",
                            ["Desc"] = "Copied " .. o[3] .. " instances to clipboard! Paste in Studio Command Bar."
                        });
                    else
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Map Dump",
                            ["Desc"] = "Dumped " .. o[3] .. " instances. File saved in executor workspace."
                        });
                    end;
                end; 
            end);
            return; 
        end;
        Ru[2] = 19612931433388;
        r119 = {
            ["Enabled"] = false,
            ["AntiMuteLoop"] = false,
            ["AutoRejoin"] = false,
            ["VoiceChatInternal"] = nil,
            ["VoiceChatService"] = nil,
            ["StateConn"] = nil,
            ["LoopConn"] = nil,
            ["RejoinConn"] = nil,
            ["Status"] = "Idle",
            ["LastState"] = nil,
            ["MuteCount"] = 0,
            [r16[r15(Ru[1], Ru[2])]] = 0
        };
        local function r120(...)
            M = {
                pcall(function(...)
                    local y = {
                        y[1],
                        y[2]
                    };
                    v5 = game;
                    return v5.GetService(v5, "VoiceChatInternal"); 
                end)
            };
            v1 = M[2];
            u = pcall(function(...)
                local y = {
                    y[1],
                    y[2]
                };
                v5 = game;
                return v5.GetService(v5, "VoiceChatInternal"); 
            end);
            if u then
                v3 = M[2];
            end;
            if u then
                return v1;
            end;
            return nil; 
        end;
        local function r121(...)
            M = {
                pcall(function(...)
                    local y = {
                        y[1],
                        y[2]
                    };
                    v5 = game;
                    return v5.GetService(v5, "VoiceChatService"); 
                end)
            };
            v1 = M[2];
            u = pcall(function(...)
                local y = {
                    y[1],
                    y[2]
                };
                v5 = game;
                return v5.GetService(v5, "VoiceChatService"); 
            end);
            if u then
                v3 = M[2];
            end;
            if u then
                return v1;
            end;
            return nil; 
        end;
        local function r122(...)
            r123 = r120();
            if not r123 then
                return false;
            end;
            return pcall(function(...)
                v5 = r123;
                v5.MuteMicrophone(v5, false);
                return; 
            end); 
        end;
        local function r124(...)
            r125 = r120();
            if not r125 then
                return nil;
            end;
            o = {
                pcall(function(...)
                    v5 = r125;
                    return v5.IsMutedLocally(v5); 
                end)
            };
            if pcall(function(...)
                v5 = r125;
                return v5.IsMutedLocally(v5); 
            end) then
                return o[2];
            end;
            return nil; 
        end;
        local function r126(...)
            r127 = r121();
            if not r127 then
                return false;
            end;
            return pcall(function(...)
                v5 = r127.joinVoice;
                if v5 then
                    v5 = r127;
                    v5.joinVoice(v5);
                end;
                return; 
            end); 
        end;
        local function r128(...)
            r129 = r120();
            if not r129 then
                138.IsA(138, "Humanoid");
            end;
            return pcall(function(...)
                v5 = r129;
                v5.TempSetMicMutedToggleMic(v5);
                return; 
            end); 
        end;
        local function r130(...)
            r131 = r120();
            if not r131 then
                return "Unknown";
            end;
            o = {
                pcall(function(...)
                    return r131.VoiceChatState; 
                end)
            };
            if pcall(function(...)
                return r131.VoiceChatState; 
            end) then
                return tostring(o[2]);
            end;
            return "Error"; 
        end;
        local function r132(...)
            if r119.LoopConn then
                pcall(function(...)
                    v5 = r119.LoopConn;
                    v5.Disconnect(v5);
                    return; 
                end);
                r119.LoopConn = nil;
            end;
            r119.LoopConn = task.spawn(function(...)
                while r119.AntiMuteLoop do
                    task.wait(0.5);
                    if not r119.AntiMuteLoop then
                        break;
                    else
                        if r124() == true then
                            r119.MuteCount = r119.MuteCount + 1;
                            r122();
                        end;
                    end; 
                end;
                return; 
            end);
            return; 
        end;
        local function r133(...)
            r119.AntiMuteLoop = false;
            if r119.LoopConn then
                pcall(function(...)
                    v5 = r119.LoopConn;
                    v5.Disconnect(v5);
                    return; 
                end);
                r119.LoopConn = nil;
            end;
            return; 
        end;
        local function r134(...)
            u = r16;
            if r119.RejoinConn then
                pcall(function(...)
                    v5 = r119.RejoinConn;
                    v5.Disconnect(v5);
                    return; 
                end);
                r119.RejoinConn = nil;
            end;
            v1 = r120();
            if v1 then
                v3 = v1.StateChanged;
            end;
            if v1 then
                u = v1.StateChanged;
                r119.RejoinConn = u.Connect(u, function(arg1_41, arg2_41, ...)
                    v1 = arg1_41;
                    u = arg2_41;
                    if not r119.AutoRejoin then
                        return;
                    end;
                    r119.LastState = tostring(u);
                    o = tostring(u);
                    M = o.lower(o);
                    o = M.find(M, "ended");
                    if o then
                        if o then
                            r119.RejoinCount = r119.RejoinCount + 1;
                            task.wait(1);
                            r126();
                        end;
                        return;
                    end; 
                end);
            else
                r119.RejoinConn = task.spawn(function(...)
                    while r119.AutoRejoin do
                        task.wait(3);
                        v1 = r119;
                        M = r16;
                        u = "AutoRejoin";
                        if not v1[u] then
                            break;
                        else
                            v1 = r130();
                            u = v1.lower(v1);
                            M = u.find(u, "ended");
                            v3 = M;
                            if M then
                            end;
                        end; 
                    end;
                    return; 
                end);
            end;
            return; 
        end;
        local function r135(...)
            r119.AutoRejoin = false;
            if r119.RejoinConn then
                pcall(function(...)
                    v5 = typeof(r119.RejoinConn) == "RBXScriptConnection";
                    if v5 then
                        v5 = r119.RejoinConn;
                        v5.Disconnect(v5);
                    end;
                    return; 
                end);
                r119.RejoinConn = nil;
            end;
            return; 
        end;
        local function r136(...)
            r119.Enabled = true;
            r119.AntiMuteLoop = true;
            r119.AutoRejoin = true;
            r119.VoiceChatInternal = r120();
            r119.VoiceChatService = r121();
            r132();
            r134();
            r119.Status = "Active";
            return; 
        end;
        local function r137(...)
            r119.Enabled = false;
            r133();
            r135();
            r119.Status = "Disabled";
            return; 
        end;
        local function r138(...)
            return "-- ============================================================\n--  Valen Hub | Anti VC Ban Standalone\n--  Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "--  PlaceId: " .. tostring(game.PlaceId) .. "-- ============================================================\n\nlocal AntiVCData = {\n    Enabled = false,\n    AntiMuteLoop = false,\n    AutoRejoin = false,\n    VoiceChatInternal = nil,\n    VoiceChatService = nil,\n    StateConn = nil,\n    LoopConn = nil,\n    RejoinConn = nil,\n    Status = \"Idle\",\n    LastState = nil,\n    MuteCount = 0,\n    RejoinCount = 0,\n}\n\nlocal function GetVoiceChatInternal()\n    local ok, svc = pcall(function()\n        return game:GetService(\"VoiceChatInternal\")\n    end)\n    if ok and svc then\n        return svc\n    end\n    return nil\nend\n\nlocal function GetVoiceChatService()\n    local ok, svc = pcall(function()\n        return game:GetService(\"VoiceChatService\")\n    end)\n    if ok and svc then\n        return svc\n    end\n    return nil\nend\n\nlocal function ForceUnmuteSelf()\n    local vci = GetVoiceChatInternal()\n    if not vci then return false end\n    local ok = pcall(function()\n        vci:MuteMicrophone(false)\n    end)\n    return ok\nend\n\nlocal function IsSelfMuted()\n    local vci = GetVoiceChatInternal()\n    if not vci then return nil end\n    local ok, muted = pcall(function()\n        return vci:IsMutedLocally()\n    end)\n    if ok then return muted end\n    return nil\nend\n\nlocal function RejoinVoiceChannel()\n    local vcs = GetVoiceChatService()\n    if not vcs then return false end\n    local ok = pcall(function()\n        if vcs.joinVoice then\n            vcs:joinVoice()\n        end\n    end)\n    return ok\nend\n\nlocal function ToggleMicMute()\n    local vci = GetVoiceChatInternal()\n    if not vci then return false end\n    local ok = pcall(function()\n        vci:TempSetMicMutedToggleMic()\n    end)\n    return ok\nend\n\nlocal function GetVCState()\n    local vci = GetVoiceChatInternal()\n    if not vci then return \"Unknown\" end\n    local ok, state = pcall(function()\n        return vci.VoiceChatState\n    end)\n    if ok then return tostring(state) end\n    return \"Error\"\nend\n\nlocal function StartAntiVCLoop()\n    if AntiVCData.LoopConn then\n        pcall(function() AntiVCData.LoopConn:Disconnect() end)\n        AntiVCData.LoopConn = nil\n    end\n    AntiVCData.LoopConn = task.spawn(function()\n        while AntiVCData.AntiMuteLoop do\n            task.wait(0.5)\n            if not AntiVCData.AntiMuteLoop then break end\n            local muted = IsSelfMuted()\n            if muted == true then\n                AntiVCData.MuteCount = AntiVCData.MuteCount + 1\n                ForceUnmuteSelf()\n            end\n        end\n    end)\nend\n\nlocal function StopAntiVCLoop()\n    AntiVCData.AntiMuteLoop = false\n    if AntiVCData.LoopConn then\n        pcall(function() AntiVCData.LoopConn:Disconnect() end)\n        AntiVCData.LoopConn = nil\n    end\nend\n\nlocal function StartAutoRejoin()\n    if AntiVCData.RejoinConn then\n        pcall(function() AntiVCData.RejoinConn:Disconnect() end)\n        AntiVCData.RejoinConn = nil\n    end\n    local vci = GetVoiceChatInternal()\n    if vci and vci.StateChanged then\n        AntiVCData.RejoinConn = vci.StateChanged:Connect(function(oldState, newState)\n            if not AntiVCData.AutoRejoin then return end\n            AntiVCData.LastState = tostring(newState)\n            if tostring(newState):lower():find(\"ended\") or tostring(newState):lower():find(\"failed\") or tostring(newState):lower():find(\"left\") then\n                AntiVCData.RejoinCount = AntiVCData.RejoinCount + 1\n                task.wait(1)\n                RejoinVoiceChannel()\n            end\n        end)\n    else\n        AntiVCData.RejoinConn = task.spawn(function()\n            while AntiVCData.AutoRejoin do\n                task.wait(3)\n                if not AntiVCData.AutoRejoin then break end\n                local state = GetVCState()\n                if state:lower():find(\"ended\") or state:lower():find(\"failed\") or state:lower():find(\"left\") or state:lower():find(\"idle\") then\n                    AntiVCData.RejoinCount = AntiVCData.RejoinCount + 1\n                    RejoinVoiceChannel()\n                end\n            end\n        end)\n    end\nend\n\nlocal function StopAutoRejoin()\n    AntiVCData.AutoRejoin = false\n    if AntiVCData.RejoinConn then\n        pcall(function()\n            if typeof(AntiVCData.RejoinConn) == \"RBXScriptConnection\" then\n                AntiVCData.RejoinConn:Disconnect()\n            end\n        end)\n        AntiVCData.RejoinConn = nil\n    end\nend\n\nlocal function EnableAntiVC()\n    AntiVCData.Enabled = true\n    AntiVCData.AntiMuteLoop = true\n    AntiVCData.AutoRejoin = true\n    AntiVCData.VoiceChatInternal = GetVoiceChatInternal()\n    AntiVCData.VoiceChatService = GetVoiceChatService()\n    StartAntiVCLoop()\n    StartAutoRejoin()\n    AntiVCData.Status = \"Active\"\n    print(\"[ValenHub AntiVC] Activated!\")\nend\n\nlocal function DisableAntiVC()\n    AntiVCData.Enabled = false\n    StopAntiVCLoop()\n    StopAutoRejoin()\n    AntiVCData.Status = \"Disabled\"\n    print(\"[ValenHub AntiVC] Deactivated.\")\nend\n\n-- Auto-start\nEnableAntiVC()\n\n-- Status loop\ntask.spawn(function()\n    while true do\n        task.wait(5)\n        local state = GetVCState()\n        local muted = IsSelfMuted()\n        local mutedStr = muted == nil and \"N/A\" or (muted and \"Muted\" or \"Unmuted\")\n        print(\"[ValenHub AntiVC] State: \" .. state .. \" | Mic: \" .. mutedStr .. \" | AntiMutes: \" .. AntiVCData.MuteCount .. \" | Rejoins: \" .. AntiVCData.RejoinCount)\n    end\nend)\n"; 
        end;
        local function r139(arg1_42, arg2_42, ...)
            u = arg2_42;
            r140 = r138();
            r63.DumpedText = r140;
            if arg1_42 then
                W = r57(r140, "ValenHub_AntiVC_Standalone_" .. os.date("%Y%m%d_%H%M%S") .. ".lua");
                if W then
                    v2 = v3;
                    r63.LastFilePath = v2;
                end;
            end;
            if u then
                v4 = setclipboard and r140 ~= "";
            end;
            if u then
                pcall(function(...)
                    setclipboard(r140);
                    return; 
                end);
            end;
            return W, r140; 
        end;
        local function r141(arg1_43, ...)
            v1 = arg1_43;
            M = pcall(function(...)
                r142 = Instance.new("ScreenGui");
                r142.Name = "ValenHubIntro";
                r142.DisplayOrder = 999999;
                r142.ResetOnSpawn = false;
                r142.IgnoreGuiInset = true;
                pcall(function(...)
                    v1 = game;
                    r142.Parent = v1.GetService(v1, "CoreGui");
                    return; 
                end);
                u = r142;
                if not u.Parent then
                    u = r27;
                    r142.Parent = u.WaitForChild(u, "PlayerGui");
                end;
                u = Instance.new("Frame");
                u.Name = "Background";
                u.Size = UDim2.new(1, 0, 1, 0);
                u.BackgroundColor3 = Color3.fromRGB(13, 13, 15);
                u.BorderSizePixel = 0;
                u.Parent = r142;
                M = Instance.new("ImageLabel");
                M.Name = "Vignette";
                M.Size = UDim2.new(1, 0, 1, 0);
                M.BackgroundTransparency = 1;
                M.Image = "rbxassetid://1072804457";
                M.ImageColor3 = Color3.fromRGB(0, 0, 0);
                M.ImageTransparency = .3;
                M.ZIndex = 1;
                M.Parent = u;
                o = Instance.new("Frame");
                o.Name = "Container";
                o.Size = UDim2.new(0, 400, 0, 200);
                o.Position = UDim2.new(0.5, -200, 0.5, -100);
                o.BackgroundTransparency = 1;
                o.ZIndex = 10;
                o.Parent = u;
                W = Instance.new("Frame");
                W.Size = UDim2.new(0, 6, 0, 6);
                W.Position = UDim2.new(0.5, -3, 0, 30);
                W.BackgroundColor3 = Color3.fromRGB(200, 200, 210);
                W.BorderSizePixel = 0;
                W.BackgroundTransparency = 1;
                W.ZIndex = 10;
                W.Parent = o;
                v4 = Instance.new("UICorner");
                v4.CornerRadius = UDim.new(1, 0);
                v4.Parent = W;
                v2 = Instance.new("TextLabel");
                v2.Name = "Title";
                v2.Size = UDim2.new(1, 0, 0, 60);
                v2.Position = UDim2.new(0, 0, 0, 50);
                v2.BackgroundTransparency = 1;
                v2.Text = "VALEN HUB";
                v2.TextColor3 = Color3.fromRGB(230, 230, 235);
                v2.TextSize = 42;
                v2.Font = Enum.Font.GothamBold;
                v2.TextTransparency = 1;
                v2.ZIndex = 10;
                v2.Parent = o;
                v6 = Instance.new("Frame");
                v6.Size = UDim2.new(0, 0, 0, 1);
                v6.Position = UDim2.new(0.5, 0, 0, 115);
                v6.AnchorPoint = Vector2.new(0.5, 0);
                v6.BackgroundColor3 = Color3.fromRGB(80, 80, 90);
                v6.BorderSizePixel = 0;
                v6.ZIndex = 10;
                v6.Parent = o;
                F = Instance.new("TextLabel");
                F.Name = "Subtitle";
                F.Size = UDim2.new(1, 0, 0, 24);
                F.Position = UDim2.new(0, 0, 0, 125);
                F.BackgroundTransparency = 1;
                F.Text = "Initializing...";
                F.TextColor3 = Color3.fromRGB(120, 120, 130);
                F.TextSize = 14;
                F.Font = Enum.Font.Gotham;
                F.TextTransparency = 1;
                F.ZIndex = 10;
                F.Parent = o;
                k = Instance.new("Frame");
                k.Name = "BarBg";
                k.Size = UDim2.new(0, 200, 0, 2);
                k.Position = UDim2.new(0.5, -100, 0, 165);
                k.BackgroundColor3 = Color3.fromRGB(35, 35, 40);
                k.BorderSizePixel = 0;
                k.BackgroundTransparency = 1;
                k.ZIndex = 10;
                k.Parent = o;
                C = Instance.new("Frame");
                C.Name = "BarFill";
                C.Size = UDim2.new(0, 0, 1, 0);
                C.BackgroundColor3 = Color3.fromRGB(200, 200, 210);
                C.BorderSizePixel = 0;
                C.BackgroundTransparency = 1;
                C.ZIndex = 11;
                C.Parent = k;
                q = Enum.EasingStyle.Quart;
                v7 = Enum.EasingDirection.Out;
                v5 = r26;
                v3 = v5.Create(v5, u, TweenInfo.new(.4, q, v7), {});
                v3.Play(v3);
                task.wait(.2);
                v5 = r26;
                v3 = v5.Create(v5, W, TweenInfo.new(.6, q, v7), {
                    ["BackgroundTransparency"] = 0
                });
                v3.Play(v3);
                task.wait(.15);
                v5 = r26;
                v3 = v5.Create(v5, v2, TweenInfo.new(.8, q, v7), {
                    ["TextTransparency"] = 0
                });
                v3.Play(v3);
                task.wait(.2);
                v5 = r26;
                v3 = v5.Create(v5, v6, TweenInfo.new(.6, q, v7), {
                    ["Size"] = UDim2.new(0, 60, 0, 1)
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, F, TweenInfo.new(.6, q, v7), {
                    ["TextTransparency"] = 0
                });
                v3.Play(v3);
                task.wait(.15);
                v5 = r26;
                v3 = v5.Create(v5, k, TweenInfo.new(.4, q, v7), {
                    ["BackgroundTransparency"] = 0
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, C, TweenInfo.new(.4, q, v7), {
                    ["BackgroundTransparency"] = 0
                });
                v3.Play(v3);
                v5 = r26;
                v8 = v5.Create(v5, C, TweenInfo.new(2.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut), {
                    ["Size"] = UDim2.new(1, 0, 1, 0)
                });
                v8.Play(v8);
                task.wait(2.8);
                v5 = r26;
                v3 = v5.Create(v5, v2, TweenInfo.new(.7, q, v7), {
                    ["TextTransparency"] = 1
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, F, TweenInfo.new(.7, q, v7), {
                    ["TextTransparency"] = 1
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, W, TweenInfo.new(.7, q, v7), {
                    ["BackgroundTransparency"] = 1
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, v6, TweenInfo.new(.7, q, v7), {
                    ["BackgroundTransparency"] = 1
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, k, TweenInfo.new(.7, q, v7), {
                    ["BackgroundTransparency"] = 1
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, C, TweenInfo.new(.7, q, v7), {
                    ["BackgroundTransparency"] = 1
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, M, TweenInfo.new(.8, q, v7), {
                    ["ImageTransparency"] = 1
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, u, TweenInfo.new(.8, q, v7), {
                    ["BackgroundTransparency"] = 1
                });
                v3.Play(v3);
                task.wait(1);
                v5 = r142;
                v5.Destroy(v5);
                return; 
            end);
            if not M then
                warn("[ValenHub] Intro animation error: " .. tostring(o[2]));
            end;
            if v1 then
                v1();
            end;
            return; 
        end;
        local function r143(...)
            v5 = r31;
            r144 = v5.CreateWindow(v5, {
                ["Title"] = "Valen Hub",
                ["Folder"] = "ValenHub",
                ["HideSearchBar"] = false,
                ["OpenButton"] = {
                    ["Enabled"] = true,
                    ["Draggable"] = true,
                    ["OnlyMobile"] = false
                },
                ["Topbar"] = {
                    ["Height"] = 44,
                    ["ButtonsType"] = "Mac"
                },
                ["Background"] = r32
            });
            if r33 ~= "rbxassetid://0" then
                pcall(function(...)
                    M = r144;
                    u = M[3];
                    v1 = M[2];
                    M = "pairs";
                    for u, W in pairs(M.GetDescendants(M)) do
                        o = u;
                        v6 = "Frame";
                        if W.IsA(W, v6) and v6.find(v6, "title") then
                            v4 = Instance.new("ImageLabel");
                            v4.Name = "HubLogo";
                            v4.Image = r33;
                            v4.Size = UDim2.new(0, 28, 0, 28);
                            v4.Position = UDim2.new(0, 8, 0.5, -14);
                            v4.BackgroundTransparency = 1;
                            v4.Parent = W;
                            break;
                        else
                            
                        end; 
                    end;
                    return; 
                end);
            end;
            if r32 ~= "rbxassetid://0" then
                task.delay(.3, function(...)
                    pcall(function(...)
                        o = game.CoreGui;
                        M = o[3];
                        o = o[1];
                        for M, v4 in o, pairs(o.GetChildren(o)) do
                            W = M;
                            if v4.IsA(v4, "ScreenGui") then
                                C = v4.GetDescendants;
                                v6 = C[2];
                                v2 = C[1];
                                for F, C in pairs(C(v4)) do
                                    k = F;
                                    if C.IsA(C, "TextLabel") and C.Text == "Valen Hub" then
                                        v1 = v4;
                                    else
                                        
                                    end; 
                                end;
                                if nil then
                                    
                                else
                                    
                                end;
                            end; 
                        end;
                        if not nil then
                            return;
                        end;
                        F = nil.GetDescendants;
                        v6 = {
                            F(nil)
                        };
                        v2 = F[3];
                        for v2, v6 in F[1], pairs(D(v6)) do
                            o = v2;
                            v5 = pairs;
                            if v6.IsA(v6, "Frame") or v6.IsA(v6, "ScrollingFrame") then
                                F = v6.AbsoluteSize.X * v6.AbsoluteSize.Y;
                                k = F > 0;
                                if k then
                                    k = v6.AbsoluteSize.X * C;
                                    u = v6;
                                    M = F;
                                end;
                            end; 
                        end;
                        if nil then
                            o = nil.FindFirstChild(nil, "CustomBg");
                            if o then
                                o.Destroy(o);
                            end;
                            v4 = Instance.new("ImageLabel");
                            v4.Name = "CustomBg";
                            v4.Image = r32;
                            v4.Size = UDim2.new(1, 0, 1, 0);
                            v4.Position = UDim2.new(0, 0, 0, 0);
                            v4.BackgroundTransparency = 1;
                            v4.ImageTransparency = 0;
                            v4.ZIndex = 0;
                            v4.Parent = u;
                            v7 = nil.GetDescendants;
                            q = {
                                v7(nil)
                            };
                            F = v7[3];
                            v6 = v7[2];
                            for F, q in pairs(D(q)) do
                                W = F;
                                v5 = pairs;
                                if q.IsA(q, "GuiObject") and q.ZIndex < 1 then
                                    q.ZIndex = 1;
                                end; 
                            end;
                        end;
                        return; 
                    end);
                    return; 
                end);
            end;
            pcall(function(...)
                v5 = r31;
                v5.SetTheme(v5, r34);
                return; 
            end);
            v5 = r144;
            u = v5.Tab(v5, {
                ["Title"] = "Main",
                ["Icon"] = "user-round-check"
            });
            v5 = r144;
            v5 = r144;
            M = v5.Tab(v5, {
                ["Title"] = "Preview",
                ["Icon"] = "eye"
            });
            o = v5.Tab(v5, {
                ["Title"] = "Remote Spy",
                ["Icon"] = "activity"
            });
            v5 = r144;
            W = v5.Tab(v5, {
                ["Title"] = "Trade Rollback",
                ["Icon"] = "rotate-ccw"
            });
            v5 = r144;
            v4 = v5.Tab(v5, {
                ["Title"] = "Map Dump",
                ["Icon"] = "map"
            });
            v5 = r144;
            v5 = r144;
            v2 = v5.Tab(v5, {
                ["Title"] = "Anti VC Ban",
                ["Icon"] = "mic"
            });
            v6 = v5.Tab(v5, {
                ["Title"] = "Settings",
                ["Icon"] = "settings"
            });
            v2.Paragraph(v2, {
                ["Title"] = "Anti VC Ban",
                ["Desc"] = "\xe0\xb8\xa3\xe0\xb8\xb0\xe0\xb8\x9a\xe0\xb8\x9a\xe0\xb8\x81\xe0\xb8\xb1\xe0\xb8\x99\xe0\xb9\x81\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb8\x84\xe0\xb9\x8c / \xe0\xb8\x81\xe0\xb8\xb1\xe0\xb8\x99 Mute \xe0\xb8\xad\xe0\xb8\xb1\xe0\xb8\x95\xe0\xb9\x82\xe0\xb8\x99\xe0\xb8\xa1\xe0\xb8\xb1\xe0\xb8\x95\xe0\xb8\xb4 \xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89 VoiceChatInternal API + VoiceChatService"
            });
            r145 = v2.Paragraph(v2, {
                ["Title"] = "Status",
                ["Desc"] = "Idle"
            });
            local function r146(...)
                v5 = r124;
                o = r145;
                u = v5();
                if u then
                    W = "Muted";
                end;
                v5 = v5;
                v5 = v5;
                v5 = o;
                v5 = r145;
                v5.SetDesc(v5, "State: " .. r130() .. " | Mic: " .. (u == nil and "N/A" or (u or "Unmuted")) .. " | AntiMutes: " .. r119.MuteCount .. " | Rejoins: " .. r119.RejoinCount);
                return; 
            end;
            v2.Toggle(v2, {
                ["Title"] = "Enable Anti VC Ban",
                ["Desc"] = "\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb8\xb4\xe0\xb8\x94\xe0\xb8\xa3\xe0\xb8\xb0\xe0\xb8\x9a\xe0\xb8\x9a\xe0\xb8\x81\xe0\xb8\xb1\xe0\xb8\x99\xe0\xb9\x81\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb8\x84\xe0\xb9\x8c\xe0\xb9\x81\xe0\xb8\x9a\xe0\xb8\x9a\xe0\xb9\x80\xe0\xb8\x95\xe0\xb9\x87\xe0\xb8\xa1\xe0\xb8\xa3\xe0\xb8\xb9\xe0\xb8\x9b\xe0\xb9\x81\xe0\xb8\x9a\xe0\xb8\x9a (AntiMute + AutoRejoin)",
                ["Default"] = false,
                ["Flag"] = "AntiVCEnabled",
                ["Callback"] = function(arg1_44, ...)
                    if arg1_44 then
                        r136();
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Ban",
                            ["Desc"] = "Activated! Monitoring voice chat..."
                        });
                    else
                        r137();
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Ban",
                            ["Desc"] = "Deactivated."
                        });
                    end;
                    r146();
                    return; 
                end
            });
            v2.Toggle(v2, {
                ["Title"] = "Anti Mute Loop",
                ["Desc"] = "Force unmute \xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\x87\xe0\xb8\x97\xe0\xb8\xb8\xe0\xb8\x81 0.5 \xe0\xb8\xa7\xe0\xb8\xb4\xe0\xb8\x99\xe0\xb8\xb2\xe0\xb8\x97\xe0\xb8\xb5 \xe0\xb8\xab\xe0\xb8\xb2\xe0\xb8\x81\xe0\xb8\x96\xe0\xb8\xb9\xe0\xb8\x81 AI mute",
                ["Default"] = false,
                ["Flag"] = "AntiMuteLoop",
                ["Callback"] = function(arg1_45, ...)
                    v1 = arg1_45;
                    r119.AntiMuteLoop = v1;
                    if v1 then
                        r132();
                    else
                        r133();
                    end;
                    r146();
                    return; 
                end
            });
            v2.Toggle(v2, {
                ["Title"] = "Auto Rejoin Voice",
                ["Desc"] = "Rejoin voice channel \xe0\xb8\xad\xe0\xb8\xb1\xe0\xb8\x95\xe0\xb9\x82\xe0\xb8\x99\xe0\xb8\xa1\xe0\xb8\xb1\xe0\xb8\x95\xe0\xb8\xb4\xe0\xb8\xab\xe0\xb8\xb2\xe0\xb8\x81\xe0\xb8\x96\xe0\xb8\xb9\xe0\xb8\x81 disconnect / suspend",
                ["Default"] = false,
                ["Flag"] = "AutoRejoinVoice",
                ["Callback"] = function(arg1_46, ...)
                    v1 = arg1_46;
                    r119.AutoRejoin = v1;
                    if v1 then
                        r134();
                    else
                        r135();
                    end;
                    r146();
                    return; 
                end
            });
            v2.Button(v2, {
                ["Title"] = "Force Unmute Now",
                ["Icon"] = "mic",
                ["Callback"] = function(...)
                    v5 = r122;
                    if v5() then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Ban",
                            ["Desc"] = "Force unmute executed!"
                        });
                    else
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Ban",
                            ["Desc"] = "Failed to unmute (VoiceChatInternal not available)"
                        });
                    end;
                    r146();
                    return; 
                end
            });
            v2.Button(v2, {
                ["Title"] = "Rejoin Voice Channel",
                ["Icon"] = "refresh-cw",
                ["Callback"] = function(...)
                    v5 = r126;
                    v1 = v5();
                    if v1 then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Ban",
                            ["Desc"] = "Rejoin voice channel executed!"
                        });
                    else
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Ban",
                            ["Desc"] = "Failed to rejoin (VoiceChatService not available)"
                        });
                    end;
                    r146();
                    return; 
                end
            });
            v2.Button(v2, {
                ["Title"] = "Toggle Mic Mute",
                ["Icon"] = "mic-off",
                ["Callback"] = function(...)
                    v5 = r128;
                    v1 = v5();
                    if v1 then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Ban",
                            ["Desc"] = "Mic toggled!"
                        });
                    else
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Ban",
                            ["Desc"] = "Toggle failed"
                        });
                    end;
                    r146();
                    return; 
                end
            });
            v2.Space(v2);
            v2.Paragraph(v2, {
                ["Title"] = "API Info",
                ["Desc"] = "VoiceChatInternal (Secret API):\n- MuteMicrophone(bool)\n- IsMutedLocally()\n- TempSetMicMutedToggleMic()\n- StateChanged event\n\nVoiceChatService:\n- joinVoice()"
            });
            v2.Paragraph(v2, {
                ["Title"] = "\xe0\xb8\xa7\xe0\xb8\xb4\xe0\xb8\x98\xe0\xb8\xb5\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89",
                ["Desc"] = "1) \xe0\xb9\x80\xe0\xb8\x9b\xe0\xb8\xb4\xe0\xb8\x94 Enable Anti VC Ban \xe0\xb9\x80\xe0\xb8\x9e\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb8\xb4\xe0\xb8\x94\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89\xe0\xb8\x87\xe0\xb8\xb2\xe0\xb8\x99\xe0\xb8\x97\xe0\xb8\xb1\xe0\xb9\x89\xe0\xb8\x87\xe0\xb8\xab\xe0\xb8\xa1\xe0\xb8\x94\n2) Anti Mute Loop \xe0\xb8\x88\xe0\xb8\xb0 force unmute \xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\x87\xe0\xb8\x95\xe0\xb8\xa5\xe0\xb8\xad\xe0\xb8\x94\xe0\xb9\x80\xe0\xb8\xa7\xe0\xb8\xa5\xe0\xb8\xb2\n3) Auto Rejoin Voice \xe0\xb8\x88\xe0\xb8\xb0 rejoin voice channel \xe0\xb8\xab\xe0\xb8\xb2\xe0\xb8\x81\xe0\xb8\x96\xe0\xb8\xb9\xe0\xb8\x81 disconnect\n4) \xe0\xb8\x81\xe0\xb8\x94 Force Unmute Now \xe0\xb8\xab\xe0\xb8\xb2\xe0\xb8\x81\xe0\xb8\x96\xe0\xb8\xb9\xe0\xb8\x81 mute \xe0\xb8\x81\xe0\xb8\xb0\xe0\xb8\x97\xe0\xb8\xb1\xe0\xb8\x99\xe0\xb8\xab\xe0\xb8\xb1\xe0\xb8\x99\n5) \xe0\xb8\x81\xe0\xb8\x94 Rejoin Voice Channel \xe0\xb8\xab\xe0\xb8\xb2\xe0\xb8\x81 icon voice chat \xe0\xb8\xab\xe0\xb8\xb2\xe0\xb8\xa2"
            });
            v2.Space(v2);
            v2.Paragraph(v2, {
                ["Title"] = "Dump Source Code",
                ["Desc"] = "\xe0\xb9\x80\xe0\xb8\x8b\xe0\xb8\x9f\xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x84\xe0\xb8\xb1\xe0\xb8\x94\xe0\xb8\xa5\xe0\xb8\xad\xe0\xb8\x81\xe0\xb8\x8b\xe0\xb8\xad\xe0\xb8\xaa\xe0\xb9\x82\xe0\xb8\x84\xe0\xb9\x89\xe0\xb8\x94\xe0\xb8\xa3\xe0\xb8\xb0\xe0\xb8\x9a\xe0\xb8\x9a\xe0\xb9\x81\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb8\x84\xe0\xb9\x8c\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x87\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\x9f\xe0\xb8\xa5\xe0\xb9\x8c standalone .lua"
            });
            v2.Button(v2, {
                ["Title"] = "Dump Anti VC Source to File",
                ["Icon"] = "file-code",
                ["Desc"] = "\xe0\xb9\x80\xe0\xb8\x8b\xe0\xb8\x9f\xe0\xb8\x8b\xe0\xb8\xad\xe0\xb8\xaa\xe0\xb9\x82\xe0\xb8\x84\xe0\xb9\x89\xe0\xb8\x94\xe0\xb8\xa3\xe0\xb8\xb0\xe0\xb8\x9a\xe0\xb8\x9a\xe0\xb9\x81\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb8\x84\xe0\xb9\x8c\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x87\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\x9f\xe0\xb8\xa5\xe0\xb9\x8c .lua \xe0\xb9\x83\xe0\xb8\x99 executor workspace + \xe0\xb8\x84\xe0\xb8\xb1\xe0\xb8\x94\xe0\xb8\xa5\xe0\xb8\xad\xe0\xb8\x81\xe0\xb9\x84\xe0\xb8\x9b\xe0\xb8\x84\xe0\xb8\xa5\xe0\xb8\xb4\xe0\xb8\x9b\xe0\xb8\x9a\xe0\xb8\xad\xe0\xb8\xa3\xe0\xb9\x8c\xe0\xb8\x94",
                ["Callback"] = function(...)
                    task.spawn(function(...)
                        v5 = r139;
                        o = {
                            v5(true, true)
                        };
                        v1 = o[2];
                        u = v5(true, true);
                        if u then
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Anti VC Dump",
                                ["Desc"] = "Saved to: " .. u .. "\nAlso copied to clipboard!"
                            });
                        else
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Anti VC Dump",
                                ["Desc"] = "Copied to clipboard! (writefile not available)"
                            });
                        end;
                        v2 = r15;
                        v4 = {
                            v1.gmatch(v1, "[^\r\n]+")
                        };
                        M = {};
                        v5 = v1.gmatch(v1, "[^\r\n]+");
                        v4 = v4[2];
                        o = v5(v4, v4[3]);
                        while o do
                            v2 = W(v4, v4[3]);
                            table.insert(M, v2);
                            if #M >= 50 then
                                
                            else
                                
                            end; 
                        end;
                        o = PreviewCode and PreviewCode.SetCode;
                        v5 = v5;
                        if o then
                            o = PreviewCode;
                            o.SetCode(o, table.concat(M, "\n"));
                        end;
                        return; 
                    end);
                    return; 
                end
            });
            v2.Button(v2, {
                ["Title"] = "Copy Anti VC Source",
                ["Icon"] = "clipboard",
                ["Desc"] = "\xe0\xb8\x84\xe0\xb8\xb1\xe0\xb8\x94\xe0\xb8\xa5\xe0\xb8\xad\xe0\xb8\x81\xe0\xb8\x8b\xe0\xb8\xad\xe0\xb8\xaa\xe0\xb9\x82\xe0\xb8\x84\xe0\xb9\x89\xe0\xb8\x94\xe0\xb8\xa3\xe0\xb8\xb0\xe0\xb8\x9a\xe0\xb8\x9a\xe0\xb9\x81\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb8\x84\xe0\xb9\x8c\xe0\xb9\x84\xe0\xb8\x9b\xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb8\x84\xe0\xb8\xa5\xe0\xb8\xb4\xe0\xb8\x9b\xe0\xb8\x9a\xe0\xb8\xad\xe0\xb8\xa3\xe0\xb9\x8c\xe0\xb8\x94\xe0\xb8\xad\xe0\xb8\xa2\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87\xe0\xb9\x80\xe0\xb8\x94\xe0\xb8\xb5\xe0\xb8\xa2\xe0\xb8\xa7",
                ["Callback"] = function(...)
                    task.spawn(function(...)
                        o = {
                            r139(false, true)
                        };
                        v1 = o[2];
                        v5 = r31;
                        u = r139(false, true);
                        v5.Notify(v5, {
                            ["Title"] = "Anti VC Dump",
                            ["Desc"] = "Copied " .. tostring(#v1) .. " chars to clipboard!"
                        });
                        v2 = r15;
                        M = {};
                        v4 = {
                            v1.gmatch(v1, "[^\r\n]+")
                        };
                        v5 = v1.gmatch(v1, "[^\r\n]+");
                        v4 = v4[2];
                        o = v5(v4, v4[3]);
                        while o do
                            v2 = W(v4, v4[3]);
                            table.insert(M, v2);
                            if #M >= 50 then
                                
                            else
                                
                            end; 
                        end;
                        v4 = PreviewCode;
                        o = v4;
                        if v4 then
                            o = PreviewCode.SetCode;
                        end;
                        v5 = v5;
                        if o then
                            o = PreviewCode;
                            o.SetCode(o, table.concat(M, "\n"));
                        end;
                        return; 
                    end);
                    return; 
                end
            });
            v2.Button(v2, {
                ["Title"] = "Preview Anti VC Source",
                ["Icon"] = "eye",
                ["Desc"] = "\xe0\xb9\x81\xe0\xb8\xaa\xe0\xb8\x94\xe0\xb8\x87\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb8\xad\xe0\xb8\xa2\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87\xe0\xb8\x8b\xe0\xb8\xad\xe0\xb8\xaa\xe0\xb9\x82\xe0\xb8\x84\xe0\xb9\x89\xe0\xb8\x94\xe0\xb9\x83\xe0\xb8\x99\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a Preview",
                ["Callback"] = function(...)
                    task.spawn(function(...)
                        o = {
                            r139(false, false)
                        };
                        v1 = o[2];
                        M = {};
                        v2 = r15;
                        u = r139(false, false);
                        v4 = {
                            v1.gmatch(v1, "[^\r\n]+")
                        };
                        v5 = v1.gmatch(v1, "[^\r\n]+");
                        v4 = v4[2];
                        o = v5(v4, v4[3]);
                        while o do
                            v2 = W(v4, v4[3]);
                            table.insert(M, v2);
                            if #M >= 100 then
                                
                            else
                                
                            end; 
                        end;
                        o = PreviewCode and PreviewCode.SetCode;
                        v5 = v5;
                        if o then
                            o = PreviewCode;
                            o.SetCode(o, table.concat(M, "\n"));
                            o = r31;
                            o.Notify(o, {
                                ["Title"] = "Anti VC Dump",
                                ["Desc"] = "Preview loaded in Preview tab!"
                            });
                        else
                            o = r31;
                            o.Notify(o, {
                                ["Title"] = "Anti VC Dump",
                                ["Desc"] = "PreviewCode not available"
                            });
                        end;
                        return; 
                    end);
                    return; 
                end
            });
            task.spawn(function(...)
                while true do
                    task.wait(2);
                    pcall(r146); 
                end;
                return; 
            end);
            W.Paragraph(W, {
                ["Title"] = "Trade Rollback",
                ["Desc"] = "\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x89\xe0\xb8\xb2\xe0\xb8\xab\xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb8\xa2\xe0\xb9\x81\xe0\xb8\xa5\xe0\xb8\xb0\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1\xe0\xb8\xab\xe0\xb8\xa5\xe0\xb8\xb2\xe0\xb8\xa2\xe0\xb8\xad\xe0\xb8\xb1\xe0\xb8\x99\xe0\xb9\x80\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xb2 Queue \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7\xe0\xb8\x81\xe0\xb8\x94 Dupe!"
            });
            r147 = {};
            r148 = {};
            r150 = {
                ["Player"] = nil,
                ["Item"] = nil
            };
            r151 = W.Dropdown(W, {
                ["Title"] = "\xe0\xb8\x9b\xe0\xb8\xa3\xe0\xb8\xb0\xe0\xb9\x80\xe0\xb8\xa0\xe0\xb8\x97\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x89\xe0\xb8\xb2\xe0\xb8\xab\xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb8\xa2",
                ["Values"] = {
                    {
                        ["Title"] = "\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\x84\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\x99"
                    },
                    {
                        ["Title"] = "\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\x87 (Backpack)"
                    },
                    {
                        ["Title"] = "\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\x87 (Character)"
                    },
                    {
                        ["Title"] = "Workspace"
                    },
                    {
                        ["Title"] = "ReplicatedStorage"
                    }
                },
                ["Value"] = {
                    ["Title"] = "\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\x84\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\x99"
                },
                ["Callback"] = function(arg1_47, ...)
                    v1 = arg1_47;
                    return; 
                end
            });
            local function r152(...)
                v1 = {};
                o = r96;
                M = o[3];
                o = o[1];
                for M, v4 in o, ipairs(o()) do
                    W = M;
                    table.insert(v1, {
                        ["Title"] = v4.Name
                    }); 
                end;
                if #v1 == 0 then
                    table.insert(v1, {
                        ["Title"] = "No players"
                    });
                end;
                return v1; 
            end;
            r153 = W.Dropdown(W, {
                ["Title"] = "\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99",
                ["Values"] = r152(),
                ["Value"] = {
                    ["Title"] = "Select..."
                },
                ["Callback"] = function(arg1_48, ...)
                    v1 = arg1_48;
                    return; 
                end
            });
            W.Button(W, {
                ["Title"] = "Refresh Players",
                ["Icon"] = "refresh-cw",
                ["Callback"] = function(...)
                    v5 = r153;
                    v5.SetValues(v5, r152());
                    v5 = r31;
                    v5.Notify(v5, {
                        ["Title"] = "Trade Rollback",
                        ["Desc"] = "\xe0\xb8\xa3\xe0\xb8\xb5\xe0\xb9\x80\xe0\xb8\x9f\xe0\xb8\xa3\xe0\xb8\x8a\xe0\xb8\xa3\xe0\xb8\xb2\xe0\xb8\xa2\xe0\xb8\x8a\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7"
                    });
                    return; 
                end
            });
            W.Toggle(W, {
                ["Title"] = "Auto Refresh \xe0\xb8\xa3\xe0\xb8\xb2\xe0\xb8\xa2\xe0\xb8\x8a\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99",
                ["Desc"] = "\xe0\xb8\xad\xe0\xb8\xb1\xe0\xb8\x9e\xe0\xb9\x80\xe0\xb8\x94\xe0\xb8\x95\xe0\xb8\xa3\xe0\xb8\xb2\xe0\xb8\xa2\xe0\xb8\x8a\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb1\xe0\xb8\x95\xe0\xb9\x82\xe0\xb8\x99\xe0\xb8\xa1\xe0\xb8\xb1\xe0\xb8\x95\xe0\xb8\xb4",
                ["Default"] = true,
                ["Flag"] = "AutoRefreshPlayerList",
                ["Callback"] = function(arg1_49, ...)
                    v4 = "\x81S\xfe<\x8e@";
                    if r150[r16[r15(v4, 6647463087127)]] then
                        pcall(function(...)
                            v5 = r150.Player.Added;
                            v5.Disconnect(v5);
                            return; 
                        end);
                        pcall(function(...)
                            v5 = r150.Player.Removing;
                            v5.Disconnect(v5);
                            return; 
                        end);
                        r150.Player = nil;
                    end;
                    if arg1_49 then
                        o = r24.PlayerAdded;
                        v4 = r24.PlayerRemoving;
                        r150.Player = {
                            ["Added"] = o.Connect(o, function(...)
                                task.wait(.3);
                                v5 = r153;
                                v5.SetValues(v5, r152());
                                return; 
                            end),
                            ["Removing"] = v4.Connect(v4, function(...)
                                task.wait(.3);
                                v5 = r153;
                                v5.SetValues(v5, r152());
                                return; 
                            end)
                        };
                    end;
                    return; 
                end
            });
            r154 = W.Paragraph(W, {
                ["Title"] = "Target Queue (0)",
                ["Desc"] = "\xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\xa1\xe0\xb8\xb5\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x89\xe0\xb8\xb2\xe0\xb8\xab\xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb8\xa2"
            });
            local function r155(...)
                v1 = #r147;
                v5 = r154;
                v5.SetTitle(v5, "Target Queue (" .. v1 .. ")");
                v5 = v1 == 0;
                if v5 then
                    v5 = r154;
                    v5.SetDesc(v5, "\xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\xa1\xe0\xb8\xb5\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x89\xe0\xb8\xb2\xe0\xb8\xab\xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb8\xa2");
                else
                    u = {};
                    W = r147;
                    M = v4[2];
                    o = v4[3];
                    for o, v2 in ipairs(v3) do
                        table.insert(u, o .. ". " .. v2.Label); 
                    end;
                    v5 = r154;
                    v5.SetDesc(v5, table.concat(u, "\n"));
                    return;
                end; 
            end;
            W.Button(W, {
                ["Title"] = "Add Target",
                ["Icon"] = "plus",
                ["Callback"] = function(...)
                    v5 = W.Button;
                    v1 = r151.Value and r151.Value.Title or "\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\x84\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\x99";
                    if v1 == "\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\x84\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\x99" then
                        v5 = v1 == v3;
                        M = r153.Value and r153.Value.Title or "";
                        if M == "" or (M == "Select..." or M == "No players") then
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\x81\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x99!"
                            });
                            return;
                        end;
                        v2 = r24;
                        v4 = v2[3];
                        v2 = v2[1];
                        for v4, F in v2, ipairs(v2.GetPlayers(v2)) do
                            v6 = v4;
                            if F.Name == M then
                                o = F;
                            else
                                
                            end; 
                        end;
                        W = not nil;
                        if W then
                            W = r31;
                            W.Notify(W, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\x9e\xe0\xb8\x9a\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99 " .. M
                            });
                            return;
                        end;
                        u = {
                            ["Type"] = "Player",
                            ["Player"] = nil,
                            ["Label"] = "Player: " .. nil.Name
                        };
                    else
                        if v1 == "\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\x87 (Backpack)" then
                            u = {
                                ["Type"] = "SelfBp",
                                ["Label"] = "Self (Backpack)"
                            };
                        else
                            if (r151[r16[v6]] and r151.Value.Title or "\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\x84\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\x99") == "\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\x87 (Character)" then
                                u = {
                                    ["Type"] = "SelfChar",
                                    ["Label"] = "Self (Character)"
                                };
                            else
                                if (r151[r16[v6]] and r151.Value.Title or "\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\x84\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\x99") == "Workspace" then
                                    u = {
                                        ["Type"] = "Workspace",
                                        ["Label"] = "Workspace"
                                    };
                                else
                                    v6 = "ReplicatedStorage";
                                    if (r151[r16[v6]] and r151.Value.Title or "\xe0\xb8\x9c\xe0\xb8\xb9\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\x84\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\x99") == v6 then
                                        u = {
                                            ["Type"] = "ReplicatedStorage",
                                            ["Label"] = "ReplicatedStorage"
                                        };
                                    end;
                                    if nil then
                                        table.insert(r147, nil);
                                        r155();
                                        v6 = r31;
                                        v6.Notify(v6, {
                                            ["Title"] = "Trade Rollback",
                                            ["Desc"] = "\xe0\xb9\x80\xe0\xb8\x9e\xe0\xb8\xb4\xe0\xb9\x88\xe0\xb8\xa1 " .. nil.Label .. " (" .. #r147 .. ")"
                                        });
                                    end;
                                    return;
                                end;
                            end;
                        end;
                    end; 
                end
            });
            W.Button(W, {
                ["Title"] = "Clear Target Queue",
                ["Icon"] = "trash-2",
                ["Callback"] = function(...)
                    r147 = {};
                    r155();
                    v3 = r31;
                    v3.Notify(v3, {
                        ["Title"] = "Trade Rollback",
                        ["Desc"] = "\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xb2\xe0\xb8\x87 Target Queue \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7"
                    });
                    return; 
                end
            });
            W.Space(W);
            local function r156(...)
                v1 = {};
                o = r94;
                M = o[3];
                o = o[1];
                for M, v4 in o, ipairs(o()) do
                    W = M;
                    table.insert(v1, {
                        ["Title"] = v4
                    }); 
                end;
                if #v1 == 0 then
                    table.insert(v1, {
                        ["Title"] = "No items"
                    });
                end;
                return v1; 
            end;
            r157 = W.Dropdown(W, {
                ["Title"] = "\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1 (\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81\xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7\xe0\xb8\x81\xe0\xb8\x94 Add)",
                ["Values"] = r156(),
                ["Value"] = {
                    ["Title"] = "Press Scan..."
                },
                ["Callback"] = function(arg1_50, ...)
                    v1 = arg1_50;
                    return; 
                end
            });
            W.Button(W, {
                ["Title"] = "Scan Items",
                ["Icon"] = "scan",
                ["Callback"] = function(...)
                    v5 = r157;
                    v5.SetValues(v5, r156());
                    v5 = r31;
                    v5.Notify(v5, {
                        ["Title"] = "Trade Rollback",
                        ["Desc"] = "\xe0\xb8\xaa\xe0\xb9\x81\xe0\xb8\x81\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1\xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7"
                    });
                    return; 
                end
            });
            W.Toggle(W, {
                ["Title"] = "Auto Refresh \xe0\xb8\xa3\xe0\xb8\xb2\xe0\xb8\xa2\xe0\xb8\x81\xe0\xb8\xb2\xe0\xb8\xa3\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1",
                ["Desc"] = "\xe0\xb8\xad\xe0\xb8\xb1\xe0\xb8\x9e\xe0\xb9\x80\xe0\xb8\x94\xe0\xb8\x95\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1\xe0\xb8\xad\xe0\xb8\xb1\xe0\xb8\x95\xe0\xb9\x82\xe0\xb8\x99\xe0\xb8\xa1\xe0\xb8\xb1\xe0\xb8\x95\xe0\xb8\xb4",
                ["Default"] = true,
                ["Flag"] = "AutoRefreshItemList",
                ["Callback"] = function(arg1_51, ...)
                    if r150.Item then
                        W = r150;
                        o = W.Item;
                        u = W[2];
                        o = W[1];
                        for M, v4 in pairs(o) do
                            r158 = v4;
                            W = M;
                            pcall(function(...)
                                v5 = P[v5];
                                v5.Disconnect(v5);
                                return; 
                            end); 
                        end;
                        r150.Item = nil;
                    end;
                    if arg1_51 then
                        u = {};
                        M = r27.CharacterAdded;
                        u.CharAdded = M.Connect(M, function(...)
                            task.wait(0.5);
                            v5 = r157;
                            v5.SetValues(v5, r156());
                            return; 
                        end);
                        M = r27.CharacterRemoving;
                        u.CharRemoving = M.Connect(M, function(...)
                            task.wait(.2);
                            v5 = r157;
                            v5.SetValues(v5, r156());
                            return; 
                        end);
                        v5 = r27;
                        o = "Backpack";
                        M = v5.FindFirstChild(v5, o);
                        if M then
                            o = M.ChildAdded;
                            u.BpAdded = o.Connect(o, function(...)
                                task.wait(.1);
                                v5 = r157;
                                v5.SetValues(v5, r156());
                                return; 
                            end);
                            o = M.ChildRemoved;
                            u.BpRemoved = o.Connect(o, function(...)
                                task.wait(.1);
                                v5 = r157;
                                v5.SetValues(v5, r156());
                                return; 
                            end);
                        end;
                        r150.Item = u;
                    end;
                    return; 
                end
            });
            r159 = W.Paragraph(W, {
                ["Title"] = "Item Queue (0)",
                ["Desc"] = "\xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\xa1\xe0\xb8\xb5\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1\xe0\xb9\x83\xe0\xb8\x99 Queue"
            });
            local function r160(...)
                v1 = #r148;
                v5 = r159;
                v5.SetTitle(v5, "Item Queue (" .. v1 .. ")");
                v5 = v1 == 0;
                if v5 then
                    v5 = r159;
                    v5.SetDesc(v5, "\xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\xa1\xe0\xb8\xb5\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1");
                else
                    u = {};
                    W = r148;
                    M = v4[2];
                    o = v4[3];
                    for o, v2 in ipairs(v3) do
                        table.insert(u, o .. ". " .. v2); 
                    end;
                    v5 = r159;
                    v5.SetDesc(v5, table.concat(u, "\n"));
                    return;
                end; 
            end;
            W.Button(W, {
                ["Title"] = "Add Item",
                ["Icon"] = "plus",
                ["Callback"] = function(...)
                    v5 = "Button";
                    v1 = r157.Value and r157.Value.Title or "";
                    W = r15;
                    if v1 == "" or (v1 == "Press Scan..." or v1 == "No items") then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Trade Rollback",
                            ["Desc"] = "\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1\xe0\xb8\x81\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x99!"
                        });
                        return;
                    end;
                    o = r148;
                    u = W[2];
                    M = W[3];
                    for M, v4 in ipairs(v3) do
                        v5 = v4 == v1;
                        W = M;
                        if v5 then
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1\xe0\xb8\x99\xe0\xb8\xb5\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa2\xe0\xb8\xb9\xe0\xb9\x88\xe0\xb9\x83\xe0\xb8\x99 Queue \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7"
                            });
                            return;
                        else
                            
                        end; 
                    end;
                    table.insert(r148, v1);
                    r160();
                    v5 = r31;
                    v5.Notify(v5, {
                        ["Title"] = "Trade Rollback",
                        ["Desc"] = "\xe0\xb9\x80\xe0\xb8\x9e\xe0\xb8\xb4\xe0\xb9\x88\xe0\xb8\xa1 " .. v1 .. " (" .. #r148 .. ")"
                    });
                    return; 
                end
            });
            W.Input(W, {
                ["Title"] = "\xe0\xb8\x9e\xe0\xb8\xb4\xe0\xb8\xa1\xe0\xb8\x9e\xe0\xb9\x8c\xe0\xb8\x8a\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1\xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\x87",
                ["Placeholder"] = "\xe0\xb8\x8a\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1...",
                ["Callback"] = function(arg1_52, ...)
                    v1 = arg1_52;
                    if v1 then
                        v3 = v1 ~= "";
                    end;
                    if v1 then
                        o = r148;
                        M = W[3];
                        o = W[1];
                        for M, v4 in o, ipairs(o) do
                            W = M;
                            if v4 == arg1_52 then
                                return;
                            else
                                
                            end; 
                        end;
                        table.insert(r148, v1);
                        r160();
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Trade Rollback",
                            ["Desc"] = "\xe0\xb9\x80\xe0\xb8\x9e\xe0\xb8\xb4\xe0\xb9\x88\xe0\xb8\xa1 " .. v1 .. " (" .. #r148 .. ")"
                        });
                    end;
                    return; 
                end
            });
            W.Button(W, {
                ["Title"] = "Clear Item Queue",
                ["Icon"] = "trash-2",
                ["Callback"] = function(...)
                    r148 = {};
                    r160();
                    v3 = r31;
                    v3.Notify(v3, {
                        ["Title"] = "Trade Rollback",
                        ["Desc"] = "\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xb2\xe0\xb8\x87 Item Queue \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7"
                    });
                    return; 
                end
            });
            W.Space(W);
            r161 = W.Paragraph(W, {
                ["Title"] = "Status",
                ["Desc"] = "\xe0\xb9\x80\xe0\xb8\x9e\xe0\xb8\xb4\xe0\xb9\x88\xe0\xb8\xa1 Target \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb8\xb0 Item \xe0\xb9\x80\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xb2 Queue \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7\xe0\xb8\x81\xe0\xb8\x94 Dupe!"
            });
            local function r162(arg1_53, ...)
                v1 = arg1_53;
                if v1.Type == "Player" then
                    v5 = v1.Player;
                    M = r16;
                    if not v5.FindFirstChild(v5, "Backpack") then
                        o = r16;
                        M = arg1_53.Player.Character;
                        if M then
                            o = M.FindFirstChild(M, "Backpack");
                            if o then
                                u = o;
                                return u;
                            else
                                v3 = v5;
                            end;
                        end;
                    end;
                end;
                v5 = v1.Type == "SelfBp";
                if v5 then
                    v5 = r27;
                    return v5.FindFirstChild(v5, "Backpack");
                end;
                if v1.Type == "SelfChar" then
                    return r27.Character;
                end;
                if v1.Type == "Workspace" then
                    return workspace;
                end;
                v5 = v1.Type == "ReplicatedStorage";
                if v5 then
                    v5 = game;
                    return v5.GetService(v5, "ReplicatedStorage");
                end;
                return nil; 
            end;
            W.Button(W, {
                ["Title"] = "Dupe!",
                ["Icon"] = "copy",
                ["Callback"] = function(...)
                    task.spawn(function(...)
                        v5 = #r147 == 0;
                        if v5 then
                            v5 = r161;
                            v5.SetDesc(v5, "Target Queue \xe0\xb8\xa7\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87!");
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "Target Queue \xe0\xb8\xa7\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87!"
                            });
                            return;
                        end;
                        v5 = #r148 == 0;
                        if v5 then
                            v5 = r161;
                            v5.SetDesc(v5, "Item Queue \xe0\xb8\xa7\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87!");
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "Item Queue \xe0\xb8\xa7\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87!"
                            });
                            return;
                        end;
                        v5 = r161;
                        v5.SetDesc(v5, "Step 1/3: Snapshot...");
                        v5 = r27;
                        v1 = v5.FindFirstChild(v5, "Backpack");
                        v5 = not v1;
                        if v5 then
                            v5 = r161;
                            v5.SetDesc(v5, "\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\xa1\xe0\xb8\xb5 Backpack!");
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\x9e\xe0\xb8\x9a Backpack"
                            });
                            return;
                        end;
                        o = {
                            r80(v1, "TradeDupe_Multi")
                        };
                        u = o[2];
                        M = r80(v1, "TradeDupe_Multi");
                        v5 = not M;
                        if v5 then
                            v5 = r161;
                            v5.SetDesc(v5, "Snapshot \xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa1\xe0\xb9\x80\xe0\xb8\xab\xe0\xb8\xa5\xe0\xb8\xa7");
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "Snapshot \xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa1\xe0\xb9\x80\xe0\xb8\xab\xe0\xb8\xa5\xe0\xb8\xa7"
                            });
                            return;
                        end;
                        r149 = M;
                        v2 = 10[2];
                        v6 = 10[3];
                        for v6, k in ipairs(r148) do
                            F = v6;
                            C = v1.FindFirstChild(v1, k);
                            if not C then
                                q = r27.Character;
                                if q then
                                    q.FindFirstChild(q, k);
                                end;
                            end;
                            if not C then
                                table.insert({}, k);
                            else
                                A = r147;
                                v7 = 17[1];
                                v8 = 17[2];
                                for T, A in ipairs(A) do
                                    i = r162(A);
                                    q = T;
                                    if i then
                                        Z = i;
                                        C.Clone(C).Parent = Z;
                                        o = 0 + 1;
                                    end; 
                                end;
                            end; 
                        end;
                        v4 = r161;
                        v4.SetDesc(v4, "Step 3/3: Cloned " .. 0 .. " \xe0\xb8\x81\xe0\xb8\xb3\xe0\xb8\xa5\xe0\xb8\xb1\xe0\xb8\x87 Rollback...");
                        C = r15("/\xd6\xcd\x82", 33172177173591);
                        task[r16[C]](.15);
                        v4 = r85;
                        k = {
                            v4(M)
                        };
                        F = k[3];
                        v6 = k[2];
                        v2 = v4(M);
                        if F then
                            v4 = r161;
                            v4.SetDesc(v4, "Rollback Error: " .. tostring(F));
                            v4 = r31;
                            v4.Notify(v4, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "Rollback Error"
                            });
                        else
                            v4 = "Dupe OK! Cloned " .. 0 .. " | Restored " .. v4(M);
                            if #{} > 0 then
                                v4 = ("Dupe OK! Cloned " .. o .. v7 .. v2) .. " | \xe0\xb8\xab\xe0\xb8\xb2\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb9\x80\xe0\xb8\x88\xe0\xb8\xad: " .. table.concat({}, ", ");
                            end;
                            C = r161;
                            C.SetDesc(C, v4);
                            C = r31;
                            C.Notify(C, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = v4
                            });
                            return;
                        end; 
                    end);
                    return; 
                end
            });
            W.Button(W, {
                ["Title"] = "Simple Clone",
                ["Icon"] = "copy",
                ["Desc"] = "Clone \xe0\xb9\x84\xe0\xb8\x9b\xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb8\x97\xe0\xb8\xb8\xe0\xb8\x81 Target \xe0\xb9\x82\xe0\xb8\x94\xe0\xb8\xa2\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88 Rollback",
                ["Callback"] = function(...)
                    task.spawn(function(...)
                        v5 = #r147 == 0;
                        if v5 then
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "Target Queue \xe0\xb8\xa7\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87!"
                            });
                            return;
                        end;
                        v5 = #r148 == 0;
                        if v5 then
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Trade Rollback",
                                ["Desc"] = "Item Queue \xe0\xb8\xa7\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87!"
                            });
                            return;
                        end;
                        v5 = r27;
                        v1 = v5.FindFirstChild(v5, "Backpack");
                        u = r27.Character;
                        o = {};
                        v2 = r148;
                        W = v6[2];
                        v4 = v6[3];
                        for v4, F in ipairs(v3) do
                            v6 = v4;
                            if v1 then
                                k = v1.FindFirstChild(v1, F);
                            end;
                            v7 = not nil;
                            if v7 then
                                C = r27.Character;
                            end;
                            if v7 then
                                k = u.FindFirstChild(u, F);
                            end;
                            if not nil then
                                table.insert({}, F);
                            else
                                A = r147;
                                v8 = 17[2];
                                v7 = 17[1];
                                for T, A in ipairs(A) do
                                    q = T;
                                    i = r162(A);
                                    if i then
                                        Z = i;
                                        nil.Clone(nil).Parent = Z;
                                        M = 0 + 1;
                                    end; 
                                end;
                            end; 
                        end;
                        if #o > 0 then
                            W = ("Clone OK! " .. M .. F[q]) .. " | \xe0\xb8\xab\xe0\xb8\xb2\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb9\x80\xe0\xb8\x88\xe0\xb8\xad: " .. table.concat(o, ", ");
                        end;
                        v2 = r31;
                        v2.Notify(v2, {
                            ["Title"] = "Trade Rollback",
                            ["Desc"] = "Clone OK! " .. 0 .. " items"
                        });
                        return; 
                    end);
                    return; 
                end
            });
            W.Space(W);
            W.Paragraph(W, {
                ["Title"] = "\xe0\xb8\xa7\xe0\xb8\xb4\xe0\xb8\x98\xe0\xb8\xb5\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89",
                ["Desc"] = "1) \xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81 Target Type -> Add Target (\xe0\xb8\x97\xe0\xb8\xb3\xe0\xb8\x8b\xe0\xb9\x89\xe0\xb8\xb3\xe0\xb9\x84\xe0\xb8\x94\xe0\xb9\x89)\n2) Scan Items -> \xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1 -> Add Item (\xe0\xb8\x97\xe0\xb8\xb3\xe0\xb8\x8b\xe0\xb9\x89\xe0\xb8\xb3\xe0\xb9\x84\xe0\xb8\x94\xe0\xb9\x89)\n3) \xe0\xb8\x81\xe0\xb8\x94 Dupe! \xe0\xb9\x80\xe0\xb8\x9e\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad Snapshot + Clone \xe0\xb8\x97\xe0\xb8\xb8\xe0\xb8\x81\xe0\xb9\x84\xe0\xb8\xad\xe0\xb9\x80\xe0\xb8\x97\xe0\xb8\xa1\xe0\xb9\x83\xe0\xb8\xab\xe0\xb9\x89\xe0\xb8\x97\xe0\xb8\xb8\xe0\xb8\x81 Target + Rollback\n\xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81\xe0\xb8\x94 Simple Clone \xe0\xb9\x80\xe0\xb8\x9e\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad Clone \xe0\xb8\xad\xe0\xb8\xa2\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87\xe0\xb9\x80\xe0\xb8\x94\xe0\xb8\xb5\xe0\xb8\xa2\xe0\xb8\xa7"
            });
            u.Paragraph(u, {
                ["Title"] = "\xe0\xb8\xa2\xe0\xb8\xb4\xe0\xb8\x99\xe0\xb8\x94\xe0\xb8\xb5\xe0\xb8\x95\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\x99\xe0\xb8\xa3\xe0\xb8\xb1\xe0\xb8\x9a\xe0\xb8\xaa\xe0\xb8\xb9\xe0\xb9\x88 Valen Hub",
                ["Desc"] = "\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb8\xb5\xe0\xb9\x89\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89 Dump \xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb9\x83\xe0\xb8\x99\xe0\xb9\x80\xe0\xb8\x81\xe0\xb8\xa1 \xe0\xb9\x80\xe0\xb8\x8a\xe0\xb9\x88\xe0\xb8\x99 ReplicatedStorage, Workspace \xe0\xb8\xaf\xe0\xb8\xa5\xe0\xb8\xaf \xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\x81 Service \xe0\xb8\x97\xe0\xb8\xb5\xe0\xb9\x88\xe0\xb8\x95\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\x87\xe0\xb8\x81\xe0\xb8\xb2\xe0\xb8\xa3 \xe0\xb8\x95\xe0\xb8\xb1\xe0\xb9\x89\xe0\xb8\x87\xe0\xb8\x84\xe0\xb9\x88\xe0\xb8\xb2 options \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7\xe0\xb8\x81\xe0\xb8\x94 Dump \xe0\xb9\x80\xe0\xb8\x9e\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x94\xe0\xb8\xb6\xe0\xb8\x87\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb8\xad\xe0\xb8\xad\xe0\xb8\x81\xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x87\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\x9f\xe0\xb8\xa5\xe0\xb9\x8c .txt \xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb7\xe0\xb8\xad .lua"
            });
            r163 = "ReplicatedStorage";
            r164 = "";
            r165 = "";
            V = {};
            f = r47;
            X = ("s+\xca\xdd\xf9\x17\x98\xd4\xca\xc6q\xf5wa\x15\x1b\x1b\xe6\"\xd7e0!\xb9Wg\x92b\x1d\x05\x03N\xe5\x027\xe5(\x17\x0bx\xd0\x1d\x93\x88H\xe2hq\xd3\xebV\x8ei{U\xd8\x80\xb0V\x1d\xe8\x03\x1d\xa0|\x19\x03Rh\xe0\x1fe><V\x18\xe6!N\x98vU\t\x8a\x1b\xad\x9f\xdf\xd8\x83\x12\x84>\xee\x07@\xd4\xa6\xd7\xe9\xdc\x02\xcf\xbc\x8b\xd0\x05\xeb\xb0\x949\n\xcaO\x08\x0b\x1e.1\xfc\xdc)\xd7\x85\xcfV\xe4\x8ab=\xa2>\x89N'\x93!\x82F\xeb65\xfbeE\xa7\x16\xbfr\xe0\x81\x1cA\nZ\x1f\xb9\xaa\xb6\x88d\xdc\\\x03\xc7e\xbd\x8a\xecB\xd0\r\xec}\xb6G^B\x01\xb2\xc0P\x12I\xbd\r\xca\xf5\xbc,\xcar\xcedk\x1b\xde|\xe0v\x07/\xb8\\\x13U\x9e\x1e)(ov\x05\xde\x1fF\xe5\xbd\xd9$;cG`IC\x9c\xc7s\x0ec\xd5(.\x87U=\x05r<r9)\xf9h-\xd9\x15>6\xb61\x86\xe6\x85|eZ4\xa1\xc5\xa8@\xc0\xdaPo\xe6A\x99Wj\x8a\xda\x19\x8c \xd1\xce\x9e\xcd\xb4\x03(\xde\xbe\xf9i\x1d\xcb\x08=\x8fM\xcfd\x11\x84z\xe6\xa4\x1b^\x0f;Z\x1c%G\x8b0/Vk\x9e\x8b\x99\\w&\x93\xf9\x15qb\x93\x93\xf4\xec\xf2\x06\x17O\x0c\xe3")[2];
            Bd = ("s+\xca\xdd\xf9\x17\x98\xd4\xca\xc6q\xf5wa\x15\x1b\x1b\xe6\"\xd7e0!\xb9Wg\x92b\x1d\x05\x03N\xe5\x027\xe5(\x17\x0bx\xd0\x1d\x93\x88H\xe2hq\xd3\xebV\x8ei{U\xd8\x80\xb0V\x1d\xe8\x03\x1d\xa0|\x19\x03Rh\xe0\x1fe><V\x18\xe6!N\x98vU\t\x8a\x1b\xad\x9f\xdf\xd8\x83\x12\x84>\xee\x07@\xd4\xa6\xd7\xe9\xdc\x02\xcf\xbc\x8b\xd0\x05\xeb\xb0\x949\n\xcaO\x08\x0b\x1e.1\xfc\xdc)\xd7\x85\xcfV\xe4\x8ab=\xa2>\x89N'\x93!\x82F\xeb65\xfbeE\xa7\x16\xbfr\xe0\x81\x1cA\nZ\x1f\xb9\xaa\xb6\x88d\xdc\\\x03\xc7e\xbd\x8a\xecB\xd0\r\xec}\xb6G^B\x01\xb2\xc0P\x12I\xbd\r\xca\xf5\xbc,\xcar\xcedk\x1b\xde|\xe0v\x07/\xb8\\\x13U\x9e\x1e)(ov\x05\xde\x1fF\xe5\xbd\xd9$;cG`IC\x9c\xc7s\x0ec\xd5(.\x87U=\x05r<r9)\xf9h-\xd9\x15>6\xb61\x86\xe6\x85|eZ4\xa1\xc5\xa8@\xc0\xdaPo\xe6A\x99Wj\x8a\xda\x19\x8c \xd1\xce\x9e\xcd\xb4\x03(\xde\xbe\xf9i\x1d\xcb\x08=\x8fM\xcfd\x11\x84z\xe6\xa4\x1b^\x0f;Z\x1c%G\x8b0/Vk\x9e\x8b\x99\\w&\x93\xf9\x15qb\x93\x93\xf4\xec\xf2\x06\x17O\x0c\xe3")[3];
            for Bd, Kd in ipairs(v3) do
                H = Bd;
                table.insert(V, {
                    ["Title"] = Kd
                }); 
            end;
            u.Dropdown(u, {
                ["Title"] = "Target Service",
                ["Values"] = V,
                ["Value"] = {
                    ["Title"] = r163
                },
                ["Callback"] = function(arg1_54, ...)
                    r163 = arg1_54.Title;
                    return; 
                end
            });
            u.Input(u, {
                ["Title"] = "Sub Path (optional)",
                ["Placeholder"] = "e.g. TS/data/plants",
                ["Callback"] = function(arg1_55, ...)
                    r164 = arg1_55;
                    return; 
                end
            });
            u.Space(u);
            r166 = true;
            r167 = true;
            r168 = false;
            r169 = false;
            u.Toggle(u, {
                ["Title"] = "Dump Children Tree",
                ["Default"] = true,
                ["Flag"] = "DumpChildren",
                ["Callback"] = function(arg1_56, ...)
                    r166 = arg1_56;
                    return; 
                end
            });
            u.Toggle(u, {
                ["Title"] = "Dump Attributes",
                ["Default"] = true,
                ["Flag"] = "DumpAttributes",
                ["Callback"] = function(arg1_57, ...)
                    r167 = arg1_57;
                    return; 
                end
            });
            u.Toggle(u, {
                ["Title"] = "Dump Part / Humanoid Properties",
                ["Default"] = false,
                ["Flag"] = "DumpProperties",
                ["Callback"] = function(arg1_58, ...)
                    r168 = arg1_58;
                    return; 
                end
            });
            u.Toggle(u, {
                ["Title"] = "Source Code Format",
                ["Default"] = false,
                ["Flag"] = "SourceFormat",
                ["Callback"] = function(arg1_59, ...)
                    r169 = arg1_59;
                    return; 
                end
            });
            u.Space(u);
            u.Input(u, {
                ["Title"] = "File Name (optional)",
                ["Placeholder"] = "leave empty for auto name",
                ["Callback"] = function(arg1_60, ...)
                    r165 = arg1_60;
                    return; 
                end
            });
            u.Paragraph(u, {
                ["Title"] = "Status",
                ["Desc"] = "Ready to dump. Select target and press Dump."
            });
            M.Paragraph(M, {
                ["Title"] = "\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb8\xad\xe0\xb8\xa2\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb8\x97\xe0\xb8\xb5\xe0\xb9\x88 Dump",
                ["Desc"] = "\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb8\xb5\xe0\xb9\x89\xe0\xb9\x81\xe0\xb8\xaa\xe0\xb8\x94\xe0\xb8\x87\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb8\xad\xe0\xb8\xa2\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb8\x97\xe0\xb8\xb5\xe0\xb9\x88 Dump \xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb8\x88\xe0\xb8\xb2\xe0\xb8\x81\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a Main \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb8\xb0\xe0\xb9\x81\xe0\xb8\xaa\xe0\xb8\x94\xe0\xb8\x87 Log \xe0\xb8\x82\xe0\xb8\xad\xe0\xb8\x87 Remote Spy (\xe0\xb8\x96\xe0\xb9\x89\xe0\xb8\xb2\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb8\xb4\xe0\xb8\x94\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89\xe0\xb8\x87\xe0\xb8\xb2\xe0\xb8\x99)"
            });
            PreviewCode = M.Code(M, {
                ["Title"] = "Dump Preview",
                ["Code"] = "-- \xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\xa1\xe0\xb8\xb5\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5 \xe0\xb9\x84\xe0\xb8\x9b\xe0\xb8\x97\xe0\xb8\xb5\xe0\xb9\x88\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a Main \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7\xe0\xb8\x81\xe0\xb8\x94 Dump"
            });
            r170 = M.Code(M, {
                ["Title"] = "Live Spy Log (last 50 calls)",
                ["Code"] = "-- Enable Remote Spy and play the game to see logs here..."
            });
            local function r171(arg1_61, ...)
                M = math.floor(arg1_61 / 100 * 20);
                if M < 0 then
                    M = 0;
                end;
                v3 = M > 20;
                if v3 then
                    v3 = 20;
                    M = 20;
                end;
                return "[" .. string.rep("#", M) .. string.rep("-", 20 - M) .. "]"; 
            end;
            local function r172(arg1_62, ...)
                r173 = arg1_62;
                task.spawn(function(...)
                    v1 = r48(r163);
                    v5 = not v1;
                    if v5 then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Status",
                            ["Desc"] = "Service not found: " .. tostring(r163)
                        });
                        return;
                    end;
                    r174 = v1;
                    if r164 and r164 ~= "" then
                        v4 = "[^/]+";
                        v2 = {
                            string.gmatch(r164, v4)
                        };
                        o = string.gmatch(r164, v4)(v2[2], v2[3]);
                        while o do
                            v5 = r174;
                            v4 = W(M, v2[3]);
                            v5 = not v5.FindFirstChild(v5, v4);
                            if v5 then
                                v5 = r31;
                                v5.Notify(v5, {
                                    ["Title"] = "Status",
                                    ["Desc"] = "Path not found: " .. r164 .. " (missing '" .. v4 .. "')"
                                });
                                return;
                            else
                                r174 = v5.FindFirstChild(v5, v4);
                            end; 
                        end;
                    end;
                    M = r31;
                    M.Notify(M, {
                        ["Title"] = "Status",
                        ["Desc"] = "Counting instances under " .. r50(r174) .. "..."
                    });
                    r175 = 1;
                    pcall(function(...)
                        v1 = r174;
                        r175 = #v1.GetDescendants(v1) + 1;
                        return; 
                    end);
                    r = 11010629112839;
                    W = {
                        ["dumpChildren"] = r166,
                        ["dumpAttributes"] = r167,
                        ["dumpProperties"] = r168,
                        ["sourceFormat"] = r169,
                        [r16[r15("J\xe0\xb7\xb9\"\x9eN\xfb", r)]] = {
                            ["count"] = 0,
                            ["total"] = r175,
                            ["lastUpdate"] = 0,
                            ["onUpdate"] = function(arg1_63, arg2_63, ...)
                                v1 = arg1_63;
                                u = arg2_63;
                                if u > 0 then
                                    M = math.floor(v1 / u * 100);
                                end;
                                v5 = r31;
                                v5.Notify(v5, {
                                    ["Title"] = "Dumping",
                                    ["Desc"] = r171(0) .. " " .. 0 .. "% (" .. v1 .. "/" .. u .. ")"
                                });
                                return; 
                            end
                        }
                    };
                    r176 = W;
                    k = {
                        pcall(function(...)
                            M = {};
                            o = 168[2];
                            v4 = 168[1];
                            for W, v6 in ipairs(r55(r174, r176)) do
                                table.insert(M, v6); 
                            end;
                            v4 = ("pcall")[3];
                            W = ("pcall")[2];
                            for v4, v6 in ipairs(r54(r174, 0, r176)) do
                                table.insert(M, v6); 
                            end;
                            return M; 
                        end)
                    };
                    v6 = k[2];
                    W = not pcall(function(...)
                        M = {};
                        o = 168[2];
                        v4 = 168[1];
                        for W, v6 in ipairs(r55(r174, r176)) do
                            table.insert(M, v6); 
                        end;
                        v4 = ("pcall")[3];
                        W = ("pcall")[2];
                        for v4, v6 in ipairs(r54(r174, 0, r176)) do
                            table.insert(M, v6); 
                        end;
                        return M; 
                    end);
                    if W then
                        W = r31;
                        W.Notify(W, {
                            ["Title"] = "Status",
                            ["Desc"] = "Dump failed: " .. tostring(v6)
                        });
                        return;
                    end;
                    k = table.concat(v6, "\n");
                    q = k;
                    r63.DumpedText = q;
                    F = r174.Name;
                    v8 = v5;
                    q = v5;
                    v5 = v8;
                    F = r169 and ".lua" or ".txt";
                    T = r165;
                    v8 = q;
                    if T then
                        v7 = r165 ~= "";
                    end;
                    v5 = v8;
                    if T then
                        v8 = r165;
                        q = v8.gsub(v8, "[^%w_%- ]", "_") .. F;
                    else
                        q = F.gsub(F, "[^%w_]", "_") .. "_" .. os.date("%Y%m%d_%H%M%S") .. F;
                    end;
                    if r173 then
                        A = r57;
                        T = A(k, nil);
                        if T then
                            r63.LastFilePath = T;
                            A = r31;
                            A.Notify(A, {
                                ["Title"] = "Status",
                                ["Desc"] = "Saved to: " .. T .. "\nLines: " .. #v6
                            });
                        else
                            A = r31;
                            A.Notify(A, {
                                ["Title"] = "Status",
                                ["Desc"] = "writefile not available.\nLines: " .. #v6 .. " (copy from Preview)"
                            });
                        end;
                    else
                        T = r57(table.concat(W, "\n"), nil);
                        if T then
                            Z = i;
                            r63.LastFilePath = Z;
                        end;
                        A = r31;
                        A.Notify(A, {
                            ["Title"] = "Status",
                            ["Desc"] = "Dumped " .. #v6 .. " lines. Check Preview tab."
                        });
                        A = {};
                        for l = 1, math.min(100, #v6) do
                            table.insert(A, v6[l]); 
                        end;
                        r = PreviewCode;
                        r.SetCode(r, table.concat(A, "\n"));
                        return;
                    end; 
                end);
                return; 
            end;
            u.Button(u, {
                ["Title"] = "Dump \xe0\xb8\xa5\xe0\xb8\x87\xe0\xb9\x84\xe0\xb8\x9f\xe0\xb8\xa5\xe0\xb9\x8c",
                ["Desc"] = "\xe0\xb8\x94\xe0\xb8\xb6\xe0\xb8\x87\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb9\x81\xe0\xb8\xa5\xe0\xb8\xb0\xe0\xb8\x9a\xe0\xb8\xb1\xe0\xb8\x99\xe0\xb8\x97\xe0\xb8\xb6\xe0\xb8\x81\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x87\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\x9f\xe0\xb8\xa5\xe0\xb9\x8c\xe0\xb9\x83\xe0\xb8\x99 executor workspace",
                ["Callback"] = function(...)
                    r172(true);
                    return; 
                end
            });
            u.Button(u, {
                ["Title"] = "Dump \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb8\xb0\xe0\xb8\x94\xe0\xb8\xb9\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb8\xad\xe0\xb8\xa2\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87",
                ["Desc"] = "\xe0\xb8\x94\xe0\xb8\xb6\xe0\xb8\x87\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb9\x81\xe0\xb8\xa5\xe0\xb8\xb0\xe0\xb9\x81\xe0\xb8\xaa\xe0\xb8\x94\xe0\xb8\x87\xe0\xb8\x95\xe0\xb8\xb1\xe0\xb8\xa7\xe0\xb8\xad\xe0\xb8\xa2\xe0\xb9\x88\xe0\xb8\xb2\xe0\xb8\x87\xe0\xb9\x83\xe0\xb8\x99\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a Preview",
                ["Callback"] = function(...)
                    r172(false);
                    return; 
                end
            });
            u.Button(u, {
                ["Title"] = "Open Dumps Folder",
                ["Callback"] = function(...)
                    v5 = r63.LastFilePath ~= "";
                    if v5 then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Status",
                            ["Desc"] = "Last file: " .. r63.LastFilePath .. "\nCopy this path to share with AI."
                        });
                    else
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Status",
                            ["Desc"] = "No dump saved yet. Press Dump to File first."
                        });
                    end;
                    return; 
                end
            });
            M.Button(M, {
                ["Title"] = "Refresh Preview",
                ["Callback"] = function(...)
                    if r63.DumpedText and r63.DumpedText ~= "" then
                        v1 = {};
                        v5 = r63.DumpedText;
                        W = {
                            v5.gmatch(v5, "[^\r\n]+")
                        };
                        o = v5.gmatch(v5, "[^\r\n]+");
                        M = o(W[2], W[3]);
                        while M do
                            W = M;
                            table.insert(v1, W);
                            if #v1 >= 100 then
                                
                            else
                                
                            end; 
                        end;
                        v5 = PreviewCode;
                        v5.SetCode(v5, table.concat(v1, "\n"));
                    else
                        v5 = PreviewCode;
                        v5.SetCode(v5, "No dump data. Press Dump and Preview first.");
                    end;
                    return; 
                end
            });
            M.Button(M, {
                ["Title"] = "Copy Last File Path",
                ["Callback"] = function(...)
                    if r63.LastFilePath and r63.LastFilePath ~= "" then
                        v5 = setclipboard;
                        if v5 then
                            pcall(function(...)
                                setclipboard(r63.LastFilePath);
                                return; 
                            end);
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Preview",
                                ["Desc"] = "Copied to clipboard:\n" .. r63.LastFilePath
                            });
                        else
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Preview",
                                ["Desc"] = "Path: " .. r63.LastFilePath
                            });
                        end;
                    else
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Preview",
                            ["Desc"] = "No file saved yet."
                        });
                    end;
                    return; 
                end
            });
            o.Paragraph(o, {
                ["Title"] = "Remote Spy - \xe0\xb8\x94\xe0\xb8\xb1\xe0\xb8\x81\xe0\xb8\x88\xe0\xb8\xb1\xe0\xb8\x9a Remote",
                ["Desc"] = "\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb8\xb5\xe0\xb9\x89\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89\xe0\xb8\x94\xe0\xb8\xb1\xe0\xb8\x81\xe0\xb8\x88\xe0\xb8\xb1\xe0\xb8\x9a\xe0\xb8\x81\xe0\xb8\xb2\xe0\xb8\xa3\xe0\xb9\x80\xe0\xb8\xa3\xe0\xb8\xb5\xe0\xb8\xa2\xe0\xb8\x81 RemoteEvent/RemoteFunction \xe0\xb8\x97\xe0\xb8\xb8\xe0\xb8\x81\xe0\xb8\x84\xe0\xb8\xa3\xe0\xb8\xb1\xe0\xb9\x89\xe0\xb8\x87\xe0\xb8\x97\xe0\xb8\xb5\xe0\xb9\x88\xe0\xb9\x80\xe0\xb8\x81\xe0\xb8\xa1\xe0\xb8\xaa\xe0\xb9\x88\xe0\xb8\x87\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb9\x84\xe0\xb8\x9b Server \xe0\xb9\x80\xe0\xb8\xab\xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb8\xb0\xe0\xb8\xaa\xe0\xb8\xb3\xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb1\xe0\xb8\x9a\xe0\xb8\xab\xe0\xb8\xb2\xe0\xb8\xa7\xe0\xb8\xb4\xe0\xb8\x98\xe0\xb8\xb5\xe0\xb8\x97\xe0\xb8\xb3\xe0\xb8\x87\xe0\xb8\xb2\xe0\xb8\x99\xe0\xb8\x82\xe0\xb8\xad\xe0\xb8\x87\xe0\xb9\x80\xe0\xb8\x81\xe0\xb8\xa1\xe0\xb9\x81\xe0\xb8\xa5\xe0\xb8\xb0\xe0\xb8\xab\xe0\xb8\xb2 Exploit vector"
            });
            r177 = false;
            r178 = {};
            r179 = {};
            r180 = 1000;
            r181 = 0;
            r182 = "";
            r183 = {};
            r184 = {};
            r185 = false;
            r187 = {};
            local function r189(arg1_64, ...)
                v1 = arg1_64;
                r187 = {};
                W = {
                    v1.gmatch(v1, "[^,]+")
                };
                M = v1.gmatch(v1, "[^,]+")(W[2], W[3]);
                while M do
                    W = M;
                    v4 = W.gsub(W, "^%s+", "");
                    v2 = v4.gsub(v4, "%s+$", "");
                    W = v2.lower(v2);
                    if #W > 0 then
                        table.insert(r187, W);
                    end; 
                end;
                return; 
            end;
            r189(r61);
            local function r190(arg1_65, ...)
                v1 = arg1_65;
                u = v1.lower(v1);
                W = r187;
                o = v4[3];
                M = v4[2];
                for o, v2 in pairs("pairs") do
                    v4 = o;
                    if u.find(u, v2, 1, true) then
                        return true;
                    else
                        
                    end; 
                end;
                return false; 
            end;
            local function r191(arg1_66, arg2_66, ...)
                v1 = arg1_66;
                u = arg2_66;
                if u then
                    u = u;
                    M = typeof(v1);
                    if M == "string" then
                        return string.format("%q", arg1_66);
                    end;
                    if M == "number" or M == "boolean" then
                        return tostring(arg1_66);
                    end;
                    if M == "nil" then
                        return "nil";
                    end;
                    if M == "Instance" then
                        if not r183[v1] then
                            r183[v1] = r52(v1);
                        end;
                        return r183[v1];
                    end;
                    if M == "Vector3" then
                        return string.format("Vector3.new(%s, %s, %s)", tostring(v1.X), tostring(v1.Y), tostring(v1.Z));
                    end;
                    if M == "Vector2" then
                        return string.format("Vector2.new(%s, %s)", tostring(v1.X), tostring(v1.Y));
                    end;
                    if M == "Color3" then
                        return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(v1.R * 255), math.floor(v1.v8 * 255), math.floor(v1.B * 255));
                    end;
                    if M == "CFrame" then
                        v4 = {
                            v1.GetComponents(v1)
                        };
                        return string.format("CFrame.new(%s, %s, %s)", tostring(v1.GetComponents(v1)), tostring(v4[2]), tostring(v4[3]));
                    end;
                    if M == "UDim" then
                        return string.format("UDim.new(%s, %s)", tostring(v1.Scale), tostring(v1.Offset));
                    end;
                    if M == "UDim2" then
                        return string.format("UDim2.new(%s, %s, %s, %s)", tostring(v1.X.Scale), tostring(v1.X.Offset), tostring(v1.Y.Scale), tostring(v1.Y.Offset));
                    end;
                    if M == "EnumItem" then
                        return tostring(arg1_66);
                    end;
                    v4 = r15;
                    if M == "table" then
                        if u[v1] then
                            return "\"--[[circular reference]]\"";
                        end;
                        u[v1] = true;
                        v5 = pairs;
                        v6 = 23539782314705[3];
                        v2 = 23539782314705[2];
                        for v6, k in v5(v1) do
                            v5 = 0 + 1;
                            W = v5;
                            v5 = v5;
                            if type(v6) ~= "number" or (v6 < 1 or v6 % 1 ~= 0) then
                                o = false;
                            else
                                
                            end; 
                        end;
                        v2 = v5;
                        if true then
                            v4 = 0 > 0;
                        end;
                        v5 = "{" .. table.concat(v4, ", ") .. "}";
                        if o then
                            v2 = 0;
                            for t = 1, v2 do
                                if arg1_66[v6] == nil then
                                    o = false;
                                else
                                    
                                end; 
                            end;
                        end;
                        v4 = {};
                        if true then
                            v6 = 0;
                            for F = 1, v6 do
                                table.insert({}, r191(arg1_66[F], v3)); 
                            end;
                            return "{" .. table.concat(v4, ", ") .. "}";
                        end;
                        k = 13[3];
                        for k, v7 in 13[1], pairs(v1) do
                            T = type(k) == "string" and k.match(k, "^[A-Za-z_][A-Za-z0-9_]*$");
                            v5 = v2;
                            if T then
                                T = k;
                                v8 = k;
                            else
                                if type(k) == "string" then
                                    v8 = "[" .. string.format("%q", k) .. "]";
                                else
                                    v8 = "[" .. tostring(k) .. "]";
                                end;
                                table.insert({}, nil .. " = " .. r191(v7, v3));
                            end; 
                        end;
                        return "{" .. table.concat(v4, ", ") .. "}";
                    end;
                    return "\"--[[" .. M .. "]]\"";
                else
                    v3 = {};
                end; 
            end;
            local function r192(...)
                if r185 then
                    return;
                end;
                r185 = true;
                u = true;
                M = #r184 > 0;
                v3 = 0 < 50;
                while not M do
                    v5 = v5;
                    if v3 then
                        v1 = 0 + 1;
                        M = table.remove(r184, 1);
                        u = M.remote;
                        r193 = M.args;
                        if not pcall(function(...)
                            v1 = {};
                            for u = 1, #r193 do
                                v1[u] = P[Yd](r193[u]); 
                            end;
                            return v1; 
                        end) then
                            v2 = {
                                "\"--[[serialize error]]\""
                            };
                        end;
                        if not r183[u] then
                            r183[u] = r52(u);
                        end;
                        v5 = u;
                        v5 = u;
                        if #r178 >= r180 then
                            table.remove(r178, 1);
                        end;
                        table.insert(r178, "local Event = " .. r183[u] .. "\nEvent:" .. (u.IsA(u, "RemoteFunction") and "InvokeServer" or "FireServer") .. "(" .. table.concat(F[2], ", ") .. ")");
                        r181 = r181 + 1;
                    end;
                    r185 = false;
                    if #r184 > 0 then
                        task.defer(r192);
                        break;
                    end;
                    return; 
                end;
                v3 = 0 < 50; 
            end;
            local function r194(arg1_67, ...)
                r195 = arg1_67;
                if r179[r195] then
                    return;
                end;
                if r190(r195.Name) then
                    return;
                end;
                r179[r195] = true;
                r196 = hookmetamethod(r195, "__namecall", function(arg1_68, ...)
                    M = r177;
                    v1 = arg1_68;
                    if M then
                        v3 = v1 == r195;
                    end;
                    if M then
                        M = getnamecallmethod();
                        if M == "FireServer" or M == "InvokeServer" then
                            table.insert(r184, {
                                ["remote"] = r195,
                                ["args"] = {...}
                            });
                            task.defer(r192);
                        end;
                    end;
                    return r196(v1, ...); 
                end);
                return; 
            end;
            local function r197(...)
                v2 = r15;
                M = game.ReplicatedStorage;
                u = M[3];
                M = M[1];
                for u, W in M, pairs(M.GetDescendants(M)) do
                    o = u;
                    r198 = W;
                    v2 = P[v5];
                    if v2.IsA(v2, "RemoteEvent") or v2.IsA(v2, "RemoteFunction") then
                        task.defer(function(...)
                            pcall(function(...)
                                P[Sd](P[v5]);
                                return; 
                            end);
                            return; 
                        end);
                    end; 
                end;
                if r186 then
                    v5 = r186;
                    v5.Disconnect(v5);
                end;
                v1 = game.ReplicatedStorage.DescendantAdded;
                r186 = v1.Connect(v1, function(arg1_69, ...)
                    r199 = arg1_69;
                    o = r199;
                    v5 = r194;
                    if (o.IsA(o, "RemoteEvent") or o.IsA(o, "RemoteFunction")) and r177 then
                        task.defer(function(...)
                            local y = {
                                190,
                                40
                            };
                            pcall(function(...)
                                local y = {
                                    190,
                                    40
                                };
                                r177(r199);
                                return; 
                            end);
                            return; 
                        end);
                    end;
                    return; 
                end);
                return; 
            end;
            r188 = o.Paragraph(o, {
                ["Title"] = "Status",
                ["Desc"] = "Logging is off. Turn it on, then use the game normally."
            });
            o.Input(o, {
                ["Title"] = "Skip remotes containing (comma separated)",
                ["Placeholder"] = "sync, heartbeat, position...",
                ["Value"] = r61,
                ["Callback"] = function(arg1_70, ...)
                    v1 = arg1_70;
                    if v1 then
                        v3 = #v1 > 0;
                    end;
                    if v1 then
                        r189(v1);
                    end;
                    return; 
                end
            });
            o.Toggle(o, {
                ["Title"] = "Enable Remote Spy",
                ["Default"] = false,
                ["Flag"] = "SpyEnabled",
                ["Callback"] = function(arg1_71, ...)
                    v1 = arg1_71;
                    r177 = v1;
                    if v1 then
                        v3 = not pcall(r197);
                        if v3 then
                            v3 = r31;
                            v3.Notify(v3, {
                                ["Title"] = "Remote Spy",
                                ["Desc"] = "This executor does not support hookmetamethod."
                            });
                            return;
                        end;
                        v3 = r188;
                        v3.SetDesc(v3, "Logging active. Calls captured: 0");
                        v3 = r31;
                        v3.Notify(v3, {
                            ["Title"] = "Remote Spy",
                            ["Desc"] = "Logging active. Play the game normally."
                        });
                    else
                        v3 = r188;
                        v3.SetDesc(v3, "Logging paused. Total captured: " .. r181);
                        v3 = r31;
                        v3.Notify(v3, {
                            ["Title"] = "Remote Spy",
                            ["Desc"] = "Logging paused."
                        });
                    end;
                    return; 
                end
            });
            task.spawn(function(...)
                while true do
                    task.wait(2);
                    if r177 then
                        pcall(function(...)
                            if r188 and r188.SetDesc then
                                v5 = r188;
                                v5.SetDesc(v5, "Logging active. Calls captured: " .. r181 .. " | Queue: " .. #r184);
                            end;
                            return; 
                        end);
                        pcall(function(...)
                            if r170 and r170.SetCode then
                                v1 = #r178;
                                v5 = v1 > 0;
                                if v5 then
                                    M = r16;
                                    math.max(1, M);
                                    M = {};
                                    for M = v1, v1, 0 do
                                        v2 = 0;
                                        table.insert(M, r178[v2]); 
                                    end;
                                    v5 = r170;
                                    v5.SetCode(v5, table.concat(M, "\n\n"));
                                end;
                            end;
                            return; 
                        end);
                    end; 
                end;
                return; 
            end);
            o.Input(o, {
                ["Title"] = "File Name (optional)",
                ["Placeholder"] = "leave empty for auto name",
                ["Callback"] = function(arg1_72, ...)
                    r182 = arg1_72;
                    return; 
                end
            });
            o.Button(o, {
                ["Title"] = "Save Log as Source Code",
                ["Callback"] = function(...)
                    v5 = not isfolder;
                    if v5 then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Status",
                            ["Desc"] = "makefolder/writefile not available on this executor."
                        });
                        return;
                    end;
                    if not isfolder("ValenHub_Dumps") then
                        makefolder("ValenHub_Dumps");
                    end;
                    if not isfolder("ValenHub_Dumps/RemoteSpy") then
                        makefolder("ValenHub_Dumps/RemoteSpy");
                    end;
                    v4 = r15;
                    u = {};
                    W = r178;
                    o = v4[3];
                    M = v4[2];
                    for o, v2 in pairs(v3) do
                        v4 = o;
                        table.insert(u, v2); 
                    end;
                    r200 = table.concat({
                        "-- Remote Spy log",
                        "-- Game: " .. tostring(game.PlaceId),
                        "-- Time: " .. os.date("%Y-%m-%d %H:%M:%S"),
                        "-- Total captured: " .. tostring(r181),
                        ""
                    }, "\n") .. "\n" .. table.concat(u, "\n\n");
                    if r182 and r182 ~= "" then
                        v2 = r182;
                        r201 = "ValenHub_Dumps/RemoteSpy/" .. v2.gsub(v2, "[^%w_%- ]", "_") .. ".lua";
                    else
                        r201 = "ValenHub_Dumps/RemoteSpy/RemoteSpy_" .. os.date("%Y%m%d_%H%M%S") .. ".lua";
                    end;
                    v4 = pcall;
                    if v4(function(...)
                        writefile(r201, r200);
                        return; 
                    end) then
                        v4 = r31;
                        v4.Notify(v4, {
                            ["Title"] = "Status",
                            ["Desc"] = "Saved " .. #r178 .. " calls to " .. r201
                        });
                    else
                        v4 = r31;
                        v4.Notify(v4, {
                            ["Title"] = "Status",
                            ["Desc"] = "Failed to save log file."
                        });
                    end;
                    return; 
                end
            });
            o.Button(o, {
                ["Title"] = "Clear Log",
                ["Callback"] = function(...)
                    r178 = {};
                    r181 = 0;
                    v1 = r31;
                    v1.Notify(v1, {
                        ["Title"] = "Status",
                        ["Desc"] = "Log cleared."
                    });
                    return; 
                end
            });
            v4.Paragraph(v4, {
                ["Title"] = "Map Dump - \xe0\xb8\x94\xe0\xb8\xb6\xe0\xb8\x87\xe0\xb9\x81\xe0\xb8\xa1\xe0\xb8\x9e\xe0\xb8\xad\xe0\xb8\xad\xe0\xb8\x81\xe0\xb8\xa1\xe0\xb8\xb2",
                ["Desc"] = "\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a\xe0\xb8\x99\xe0\xb8\xb5\xe0\xb9\x89\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89\xe0\xb8\x94\xe0\xb8\xb6\xe0\xb8\x87\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb9\x81\xe0\xb8\xa1\xe0\xb8\x9e (Workspace) \xe0\xb8\xad\xe0\xb8\xad\xe0\xb8\x81\xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb9\x80\xe0\xb8\x9b\xe0\xb9\x87\xe0\xb8\x99\xe0\xb9\x84\xe0\xb8\x9f\xe0\xb8\xa5\xe0\xb9\x8c .rbxlx \xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb8\xaa\xe0\xb8\x84\xe0\xb8\xa3\xe0\xb8\xb4\xe0\xb8\x9b\xe0\xb8\x95\xe0\xb9\x8c Lua \xe0\xb8\x97\xe0\xb8\xb5\xe0\xb9\x88\xe0\xb8\x99\xe0\xb8\xb3\xe0\xb9\x84\xe0\xb8\x9b\xe0\xb8\xa7\xe0\xb8\xb2\xe0\xb8\x87\xe0\xb9\x83\xe0\xb8\x99 Roblox Studio \xe0\xb9\x84\xe0\xb8\x94\xe0\xb9\x89\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xa2\n\xe0\xb9\x80\xe0\xb8\xab\xe0\xb8\xa1\xe0\xb8\xb2\xe0\xb8\xb0\xe0\xb8\xaa\xe0\xb8\xb3\xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb1\xe0\xb8\x9a\xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\xb2\xe0\xb9\x81\xe0\xb8\xa1\xe0\xb8\x9e\xe0\xb9\x84\xe0\xb8\x9b\xe0\xb8\xa8\xe0\xb8\xb6\xe0\xb8\x81\xe0\xb8\xa9\xe0\xb8\xb2\xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb7\xe0\xb8\xad\xe0\xb9\x81\xe0\xb8\x81\xe0\xb9\x89\xe0\xb9\x84\xe0\xb8\x82\xe0\xb8\x95\xe0\xb9\x88\xe0\xb8\xad"
            });
            v4.Space(v4);
            v4.Input(v4, {
                ["Title"] = "Folder Name",
                ["Placeholder"] = "ValenHub_Map",
                ["Value"] = "ValenHub_Map",
                ["Callback"] = function(arg1_73, ...)
                    v1 = arg1_73;
                    o = v1 ~= "";
                    if o then
                        u = arg1_73;
                    end;
                    v5 = M.Code(M, {
                        ["Title"] = "Dump Preview",
                        ["Code"] = "-- \xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb9\x84\xe0\xb8\xa1\xe0\xb9\x88\xe0\xb8\xa1\xe0\xb8\xb5\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5 \xe0\xb9\x84\xe0\xb8\x9b\xe0\xb8\x97\xe0\xb8\xb5\xe0\xb9\x88\xe0\xb9\x81\xe0\xb8\x97\xe0\xb9\x87\xe0\xb8\x9a Main \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7\xe0\xb8\x81\xe0\xb8\x94 Dump"
                    });
                    MapFolderName = o or "ValenHub_Map";
                    return; 
                end
            });
            v4.Toggle(v4, {
                ["Title"] = "Include Terrain",
                ["Default"] = false,
                ["Flag"] = "MapIncludeTerrain",
                ["Callback"] = function(arg1_74, ...)
                    MapIncludeTerrain = arg1_74;
                    return; 
                end
            });
            v4.Toggle(v4, {
                ["Title"] = "Include Scripts",
                ["Default"] = false,
                ["Flag"] = "MapIncludeScripts",
                ["Callback"] = function(arg1_75, ...)
                    MapIncludeScripts = arg1_75;
                    return; 
                end
            });
            v4.Toggle(v4, {
                ["Title"] = "Include Characters (Humanoid, Animator)",
                ["Default"] = false,
                ["Flag"] = "MapIncludeCharacters",
                ["Callback"] = function(arg1_76, ...)
                    MapIncludeCharacters = arg1_76;
                    return; 
                end
            });
            v4.Space(v4);
            v4.Button(v4, {
                ["Title"] = "Save as Studio File (.rbxlx)",
                ["Callback"] = function(...)
                    v5 = saveinstance;
                    if v5 then
                        r202 = MapFolderName .. "_" .. os.date("%Y%m%d_%H%M%S");
                        M = pcall(function(...)
                            if type(saveinstance) == "function" then
                                saveinstance(game, r202);
                            end;
                            return; 
                        end);
                        v5 = not M;
                        if v5 then
                            M = pcall(function(...)
                                saveinstance({
                                    ["FileName"] = r202,
                                    ["Decompile"] = false,
                                    ["SavePlayers"] = false,
                                    ["noscripts"] = not MapIncludeScripts
                                });
                                return; 
                            end);
                        end;
                        if M then
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Map Dump",
                                ["Desc"] = "Saved! Check executor workspace folder for " .. r202 .. ".rbxlx"
                            });
                        else
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Map Dump",
                                ["Desc"] = "saveinstance failed: " .. tostring(o[2]) .. ". Use Copy to Clipboard instead."
                            });
                        end;
                    else
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Map Dump",
                            ["Desc"] = "saveinstance() not supported. Use Copy to Clipboard instead."
                        });
                    end;
                    return; 
                end
            });
            v4.Button(v4, {
                ["Title"] = "Dump Map & Copy to Clipboard",
                ["Callback"] = function(...)
                    P[Zd](true);
                    return; 
                end
            });
            v4.Button(v4, {
                ["Title"] = "Copy Last Script to Clipboard",
                ["Callback"] = function(...)
                    if r63.DumpedText and r63.DumpedText ~= "" then
                        v5 = setclipboard;
                        if v5 then
                            pcall(function(...)
                                setclipboard(r63.DumpedText);
                                return; 
                            end);
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Map Dump",
                                ["Desc"] = "Copied full script to clipboard! Paste in Studio Script."
                            });
                        else
                            v5 = r31;
                            v5.Notify(v5, {
                                ["Title"] = "Map Dump",
                                ["Desc"] = "setclipboard not available on this executor."
                            });
                        end;
                    else
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Map Dump",
                            ["Desc"] = "No script generated yet. Press Dump Map first."
                        });
                    end;
                    return; 
                end
            });
            v4.Space(v4);
            v4.Paragraph(v4, {
                ["Title"] = "How to use",
                ["Desc"] = "EASIEST: Press \"Save as Studio File (.rbxlx)\" then open the file in Studio directly.\n\nALTERNATIVE: Press \"Dump Map & Copy to Clipboard\" > paste into Studio Script > Run (F5)."
            });
            v6.Paragraph(v6, {
                ["Title"] = "About",
                ["Desc"] = "Valen Hub - Universal Game Dump\n\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89 \xe0\xb8\xa2\xe0\xb8\xb1\xe0\xb8\x87\xe0\xb9\x84\xe0\xb8\x87 \xe0\xb8\x99\xe0\xb8\xb5\xe0\xb9\x88\xe0\xb8\x84\xe0\xb8\xb7\xe0\xb8\xad scirpt \xe0\xb8\xaa\xe0\xb8\xb3\xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb1\xe0\xb8\x9a \xe0\xb8\x82\xe0\xb9\x82\xe0\xb8\xa1\xe0\xb8\xa2\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xad\xe0\xb8\xa1\xe0\xb8\xb9\xe0\xb8\xa5\xe0\xb9\x83\xe0\xb8\x99\xe0\xb9\x81\xe0\xb8\xa1\xe0\xb8\x9e \xe0\xb9\x81\xe0\xb8\xa5\xe0\xb8\xb0 \xe0\xb9\x80\xe0\xb8\xad\xe0\xb8\xb2\xe0\xb9\x84\xe0\xb8\x9b\xe0\xb9\x83\xe0\xb8\xab\xe0\xb9\x89 AI \xe0\xb8\x8a\xe0\xb9\x88\xe0\xb8\xa7\xe0\xb8\xa2\xe0\xb9\x80\xe0\xb8\x82\xe0\xb8\xb5\xe0\xb8\xa2\xe0\xb8\x99\xe0\xb8\xad\xe0\xb8\xb5\xe0\xb8\x81\xe0\xb8\x97\xe0\xb8\xb5 \xe0\xb9\x82\xe0\xb8\x94\xe0\xb8\xa2 \xe0\xb8\xab\xe0\xb8\xb2\xe0\xb8\x81\xe0\xb8\x87\xe0\xb8\x87\xe0\xb9\x80\xe0\xb8\x82\xe0\xb9\x89\xe0\xb8\xb2 DISCORD \xe0\xb8\xaa\xe0\xb8\xad\xe0\xb8\x9a\xe0\xb8\x96\xe0\xb8\xb2\xe0\xb8\xa1\xe0\xb9\x80\xe0\xb8\xa5\xe0\xb8\xa2"
            });
            v6.Space(v6);
            qd = r16;
            v6.Paragraph(v6, {
                ["Title"] = "Appearance",
                ["Desc"] = "Change the look of Valen Hub instantly."
            });
            cd = {};
            kd = r35;
            sd = qd[2];
            td = qd[3];
            for td, kd in ipairs(kd) do
                Wd = td;
                table.insert(cd, {
                    ["Title"] = kd
                }); 
            end;
            v6.Dropdown(v6, {
                ["Title"] = "Select Theme",
                ["Values"] = cd,
                ["Value"] = {
                    ["Title"] = r34
                },
                ["Callback"] = function(arg1_77, ...)
                    r34 = arg1_77.Title;
                    v3 = r37;
                    v3();
                    if pcall(function(...)
                        v5 = r31;
                        v5.SetTheme(v5, r34);
                        return; 
                    end) then
                        v3 = r31;
                        v3.Notify(v3, {
                            ["Title"] = "Theme Changed",
                            ["Desc"] = "Switched to \"" .. r34 .. "\" theme."
                        });
                    else
                        v3 = r31;
                        v3.Notify(v3, {
                            ["Title"] = "Theme Error",
                            ["Desc"] = "\"" .. r34 .. "\" theme is not available. Using default."
                        });
                    end;
                    return; 
                end
            });
            v6.Space(v6);
            v6.Button(v6, {
                ["Title"] = "Save Settings Now",
                ["Callback"] = function(...)
                    r37();
                    v5 = r31;
                    v5.Notify(v5, {
                        ["Title"] = "Settings Saved",
                        ["Desc"] = "Theme & Background saved to config."
                    });
                    return; 
                end
            });
            r203 = r144.ConfigManager;
            r204 = "default";
            v6.Input(v6, {
                ["Title"] = "Config Name",
                ["Placeholder"] = "default",
                ["Callback"] = function(arg1_78, ...)
                    r204 = arg1_78;
                    return; 
                end
            });
            v6.Button(v6, {
                ["Title"] = "Save Config",
                ["Callback"] = function(...)
                    v1 = r203;
                    r144.CurrentConfig = v1.Config(v1, r204);
                    v5 = r144.CurrentConfig;
                    if v5.Save(v5) then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Config Saved",
                            ["Desc"] = "Config '" .. r204 .. "' saved"
                        });
                    end;
                    return; 
                end
            });
            v6.Button(v6, {
                ["Title"] = "Load Config",
                ["Callback"] = function(...)
                    v1 = r203;
                    r144.CurrentConfig = v1.CreateConfig(v1, r204);
                    v5 = r144.CurrentConfig;
                    if v5.Load(v5) then
                        v5 = r31;
                        v5.Notify(v5, {
                            ["Title"] = "Config Loaded",
                            ["Desc"] = "Config '" .. r204 .. "' loaded"
                        });
                    end;
                    return; 
                end
            });
            v6.Button(v6, {
                ["Title"] = "Remove Saved Key",
                ["Callback"] = function(...)
                    r46();
                    v5 = r31;
                    v5.Notify(v5, {
                        ["Title"] = "Key Removed",
                        ["Desc"] = "Restart the script to enter a new key."
                    });
                    return; 
                end
            });
            v6.Button(v6, {
                ["Title"] = "Destroy UI",
                ["Callback"] = function(...)
                    v5 = r144;
                    v5.Destroy(v5);
                    return; 
                end
            });
            Wd = r31;
            Wd.Notify(Wd, {
                ["Title"] = "Valen Hub Loaded",
                ["Desc"] = "Select a service and press Dump to File."
            });
            return; 
        end;
        local function r205(...)
            r206 = Instance.new("ScreenGui");
            r206.Name = "ValenHubKeyGate";
            r206.DisplayOrder = 99999;
            r206.ResetOnSpawn = false;
            r206.IgnoreGuiInset = true;
            pcall(function(...)
                v1 = game;
                r206.Parent = v1.GetService(v1, "CoreGui");
                return; 
            end);
            u = r206;
            if not u.Parent then
                u = r27;
                r206.Parent = u.WaitForChild(u, "PlayerGui");
            end;
            u = Instance.new("Frame");
            u.Size = UDim2.new(1, 0, 1, 0);
            u.BackgroundColor3 = Color3.fromRGB(11, 11, 13);
            u.BorderSizePixel = 0;
            u.Parent = r206;
            M = Instance.new("ImageLabel");
            M.Size = UDim2.new(1, 0, 1, 0);
            M.BackgroundTransparency = 1;
            M.Image = "rbxassetid://1072804457";
            M.ImageColor3 = Color3.fromRGB(20, 20, 22);
            M.ImageTransparency = .85;
            M.ZIndex = 1;
            M.Parent = u;
            r207 = Instance.new("Frame");
            r207.Size = UDim2.new(0, 400, 0, 280);
            r207.Position = UDim2.new(0.5, -200, 0.5, -140);
            r207.BackgroundColor3 = Color3.fromRGB(22, 22, 26);
            r207.BorderSizePixel = 0;
            r207.ZIndex = 10;
            r207.Parent = u;
            W = Instance.new("UICorner");
            W.CornerRadius = UDim.new(0, 20);
            W.Parent = r207;
            r208 = Instance.new("UIStroke");
            r208.Color = Color3.fromRGB(35, 35, 42);
            r208.Thickness = 1;
            r208.Transparency = .3;
            r208.Parent = r207;
            v2 = Instance.new("Frame");
            v2.Size = UDim2.new(1, 0, 0, 3);
            v2.Position = UDim2.new(0, 0, 0, 0);
            v2.BackgroundColor3 = Color3.fromRGB(60, 60, 70);
            v2.BorderSizePixel = 0;
            v2.ZIndex = 11;
            v2.Parent = r207;
            v6 = Instance.new("UICorner");
            v6.CornerRadius = UDim.new(0, 20);
            v6.Parent = v2;
            F = Instance.new("Frame");
            F.Size = UDim2.new(0, 10, 0, 10);
            F.Position = UDim2.new(0.5, -5, 0, 28);
            F.BackgroundColor3 = Color3.fromRGB(180, 180, 190);
            F.BorderSizePixel = 0;
            F.ZIndex = 10;
            F.Parent = r207;
            k = Instance.new("UICorner");
            k.CornerRadius = UDim.new(1, 0);
            k.Parent = F;
            C = Instance.new("TextLabel");
            C.Size = UDim2.new(1, 0, 0, 40);
            C.Position = UDim2.new(0, 0, 0, 45);
            C.BackgroundTransparency = 1;
            C.Text = "VALEN HUB";
            C.TextColor3 = Color3.fromRGB(220, 220, 225);
            C.TextSize = 28;
            C.Font = Enum.Font.GothamBold;
            C.ZIndex = 10;
            C.Parent = r207;
            q = Instance.new("TextLabel");
            q.Size = UDim2.new(1, 0, 0, 20);
            q.Position = UDim2.new(0, 0, 0, 82);
            q.BackgroundTransparency = 1;
            q.Text = "Authentication Required";
            q.TextColor3 = Color3.fromRGB(120, 120, 130);
            q.TextSize = 13;
            q.Font = Enum.Font.Gotham;
            q.ZIndex = 10;
            q.Parent = r207;
            v7 = Instance.new("Frame");
            v7.Size = UDim2.new(0, 40, 0, 1);
            v7.Position = UDim2.new(0.5, -20, 0, 110);
            v7.BackgroundColor3 = Color3.fromRGB(50, 50, 58);
            v7.BorderSizePixel = 0;
            v7.ZIndex = 10;
            v7.Parent = r207;
            r209 = Instance.new("Frame");
            r209.Size = UDim2.new(0, 320, 0, 44);
            r209.Position = UDim2.new(0.5, -160, 0, 128);
            r209.BackgroundColor3 = Color3.fromRGB(28, 28, 34);
            r209.BorderSizePixel = 0;
            r209.ZIndex = 10;
            r209.Parent = r207;
            T = Instance.new("UICorner");
            T.CornerRadius = UDim.new(0, 10);
            T.Parent = r209;
            r210 = Instance.new("UIStroke");
            r210.Color = Color3.fromRGB(40, 40, 48);
            r210.Thickness = 1.5;
            r210.Parent = r209;
            r211 = Instance.new("TextBox");
            r211.Size = UDim2.new(1, -24, 1, 0);
            r211.Position = UDim2.new(0, 12, 0, 0);
            r211.BackgroundTransparency = 1;
            r211.TextColor3 = Color3.fromRGB(220, 220, 225);
            r211.PlaceholderText = "Enter your access key...";
            r211.PlaceholderColor3 = Color3.fromRGB(90, 90, 100);
            r211.Text = "";
            r211.TextSize = 14;
            r211.Font = Enum.Font.Gotham;
            r211.ClearTextOnFocus = false;
            r211.ZIndex = 10;
            r211.Parent = r209;
            r212 = Instance.new("TextLabel");
            r212.Size = UDim2.new(1, 0, 0, 18);
            r212.Position = UDim2.new(0, 0, 0, 182);
            r212.BackgroundTransparency = 1;
            r212.Text = "Waiting for key...";
            r212.TextColor3 = Color3.fromRGB(100, 100, 110);
            r212.TextSize = 12;
            r212.Font = Enum.Font.Gotham;
            r212.ZIndex = 10;
            r212.Parent = r207;
            r213 = Instance.new("TextButton");
            r213.Size = UDim2.new(0, 320, 0, 44);
            r213.Position = UDim2.new(0.5, -160, 0, 210);
            r213.BackgroundColor3 = Color3.fromRGB(35, 35, 42);
            r213.TextColor3 = Color3.fromRGB(200, 200, 210);
            r213.Text = "Verify";
            r213.TextSize = 15;
            r213.Font = Enum.Font.GothamBold;
            r213.AutoButtonColor = false;
            r213.ZIndex = 10;
            r213.Parent = r207;
            Z = Instance.new("UICorner");
            Z.CornerRadius = UDim.new(0, 10);
            Z.Parent = r213;
            r214 = Instance.new("UIStroke");
            r214.Color = Color3.fromRGB(50, 50, 60);
            r214.Thickness = 1.5;
            r214.Parent = r213;
            v5 = r211.Focused;
            v5.Connect(v5, function(...)
                v5 = r26;
                v3 = v5.Create(v5, r210, TweenInfo.new(0.25), {
                    ["Color"] = Color3.fromRGB(80, 80, 95)
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, r209, TweenInfo.new(0.25), {
                    ["BackgroundColor3"] = Color3.fromRGB(32, 32, 38)
                });
                v3.Play(v3);
                return; 
            end);
            v5 = r211.FocusLost;
            v5.Connect(v5, function(...)
                v5 = r26;
                v3 = v5.Create(v5, r210, TweenInfo.new(0.25), {
                    ["Color"] = Color3.fromRGB(40, 40, 48)
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, r209, TweenInfo.new(0.25), {
                    ["BackgroundColor3"] = Color3.fromRGB(28, 28, 34)
                });
                v3.Play(v3);
                return; 
            end);
            v5 = r213.MouseEnter;
            v5.Connect(v5, function(...)
                v5 = r26;
                v3 = v5.Create(v5, r213, TweenInfo.new(.2), {
                    ["BackgroundColor3"] = Color3.fromRGB(45, 45, 55)
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, r214, TweenInfo.new(.2), {
                    ["Color"] = Color3.fromRGB(70, 70, 85)
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, r213, TweenInfo.new(.2), {
                    ["TextColor3"] = Color3.fromRGB(230, 230, 240)
                });
                v3.Play(v3);
                return; 
            end);
            v5 = r213.MouseLeave;
            v5.Connect(v5, function(...)
                v5 = r26;
                v3 = v5.Create(v5, r213, TweenInfo.new(.2), {
                    ["BackgroundColor3"] = Color3.fromRGB(35, 35, 42)
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, r214, TweenInfo.new(.2), {
                    ["Color"] = Color3.fromRGB(50, 50, 60)
                });
                v3.Play(v3);
                v5 = r26;
                v3 = v5.Create(v5, r213, TweenInfo.new(.2), {
                    ["TextColor3"] = Color3.fromRGB(200, 200, 210)
                });
                v3.Play(v3);
                return; 
            end);
            r207.BackgroundTransparency = 1;
            r208.Transparency = 1;
            F.BackgroundTransparency = 1;
            C.TextTransparency = 1;
            q.TextTransparency = 1;
            v7.BackgroundTransparency = 1;
            r209.BackgroundTransparency = 1;
            r211.TextTransparency = 1;
            r212.TextTransparency = 1;
            r213.BackgroundTransparency = 1;
            r213.TextTransparency = 1;
            r214.Transparency = 1;
            v2.BackgroundTransparency = 1;
            v5 = r26;
            v3 = v5.Create(v5, r207, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                ["BackgroundTransparency"] = 0
            });
            v3.Play(v3);
            v5 = r26;
            v3 = v5.Create(v5, r208, TweenInfo.new(.6), {
                ["Transparency"] = .3
            });
            v3.Play(v3);
            task.wait(.1);
            v5 = r26;
            v3 = v5.Create(v5, v2, TweenInfo.new(.4), {
                ["BackgroundTransparency"] = 0
            });
            v3.Play(v3);
            v5 = r26;
            v3 = v5.Create(v5, F, TweenInfo.new(0.5), {
                ["BackgroundTransparency"] = 0
            });
            v3.Play(v3);
            task.wait(.1);
            v5 = r26;
            v3 = v5.Create(v5, C, TweenInfo.new(0.5), {
                ["TextTransparency"] = 0
            });
            v3.Play(v3);
            task.wait(.08);
            v5 = r26;
            v3 = v5.Create(v5, q, TweenInfo.new(0.5), {
                ["TextTransparency"] = 0
            });
            v3.Play(v3);
            v5 = r26;
            v3 = v5.Create(v5, v7, TweenInfo.new(0.5), {
                ["BackgroundTransparency"] = 0
            });
            v3.Play(v3);
            task.wait(.08);
            v5 = r26;
            v3 = v5.Create(v5, r209, TweenInfo.new(0.5), {
                ["BackgroundTransparency"] = 0
            });
            v3.Play(v3);
            v5 = r26;
            v3 = v5.Create(v5, r211, TweenInfo.new(0.5), {
                ["TextTransparency"] = 0
            });
            v3.Play(v3);
            v5 = r26;
            v3 = v5.Create(v5, r210, TweenInfo.new(0.5), {
                ["Transparency"] = 0
            });
            v3.Play(v3);
            task.wait(.08);
            v5 = r26;
            v3 = v5.Create(v5, r212, TweenInfo.new(0.5), {
                ["TextTransparency"] = 0
            });
            v3.Play(v3);
            task.wait(.08);
            v5 = r26;
            v3 = v5.Create(v5, r213, TweenInfo.new(0.5), {
                ["BackgroundTransparency"] = 0,
                ["TextTransparency"] = 0
            });
            v3.Play(v3);
            v5 = r26;
            v3 = v5.Create(v5, r214, TweenInfo.new(0.5), {
                ["Transparency"] = 0
            });
            v3.Play(v3);
            v5 = r213.MouseButton1Click;
            v5.Connect(v5, function(...)
                r215 = r211.Text;
                v3 = r215;
                if v3 == "" then
                    r212.Text = "Please enter a key";
                    r212.TextColor3 = Color3.fromRGB(200, 80, 80);
                    v5 = r26;
                    v3 = v5.Create(v5, r210, TweenInfo.new(.2), {
                        ["Color"] = Color3.fromRGB(150, 60, 60)
                    });
                    v3.Play(v3);
                    return;
                end;
                r212.Text = "Verifying...";
                r212.TextColor3 = Color3.fromRGB(130, 130, 140);
                v5 = r26;
                v3 = v5.Create(v5, r213, TweenInfo.new(.2), {
                    ["BackgroundColor3"] = Color3.fromRGB(30, 30, 36)
                });
                v3.Play(v3);
                task.spawn(function(...)
                    M = {
                        pcall(function(...)
                            return r41(r215); 
                        end)
                    };
                    v1 = M[2];
                    v3 = pcall(function(...)
                        return r41(r215); 
                    end);
                    u = "valid";
                    if not u then
                        r212.Text = "Connection error";
                        r212.TextColor3 = Color3.fromRGB(200, 80, 80);
                        v5 = r26;
                        v3 = v5.Create(v5, r213, TweenInfo.new(.2), {
                            ["BackgroundColor3"] = Color3.fromRGB(35, 35, 42)
                        });
                        v3.Play(v3);
                        return;
                    end;
                    if v1 == "valid" then
                        r212.Text = "Access key";
                        r212.TextColor3 = Color3.fromRGB(100, 200, 120);
                        v5 = r26;
                        v3 = v5.Create(v5, r213, TweenInfo.new(.2), {
                            ["BackgroundColor3"] = Color3.fromRGB(40, 70, 50)
                        });
                        v3.Play(v3);
                        v5 = r26;
                        v3 = v5.Create(v5, r214, TweenInfo.new(.2), {
                            ["Color"] = Color3.fromRGB(60, 120, 70)
                        });
                        v3.Play(v3);
                        r43(r215);
                        task.wait(.8);
                        v5 = r26;
                        v3 = v5.Create(v5, r207, TweenInfo.new(.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            ["BackgroundTransparency"] = 1
                        });
                        v3.Play(v3);
                        v5 = r26;
                        v3 = v5.Create(v5, r208, TweenInfo.new(.4), {
                            ["Transparency"] = 1
                        });
                        v3.Play(v3);
                        W = r207;
                        o = W[3];
                        W = W[1];
                        for o, v2 in W, pairs(W.GetDescendants(W)) do
                            v4 = o;
                            v6 = v2.IsA(v2, "TextLabel") or v2.IsA(v2, "TextButton");
                            if v6 then
                                v5 = r26;
                                v6 = v5.Create(v5, v2, TweenInfo.new(.3), {
                                    ["TextTransparency"] = 1
                                });
                                v6.Play(v6);
                            else
                                v6 = v2.IsA(v2, "Frame") and v2 ~= r207;
                                if v6 then
                                    v5 = r26;
                                    v6 = v5.Create(v5, v2, TweenInfo.new(.3), {
                                        ["BackgroundTransparency"] = 1
                                    });
                                    v6.Play(v6);
                                end;
                            end; 
                        end;
                        task.wait(0.5);
                        v5 = r206;
                        v5.Destroy(v5);
                        task.wait(.2);
                        r143();
                    else
                        v5 = v1 == "used";
                        if v5 then
                            r212.Text = "\xe0\xb8\x84\xe0\xb8\xb5\xe0\xb8\xa2\xe0\xb8\xa3\xe0\xb9\x8c\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89\xe0\xb9\x81\xe0\xb8\xa5\xe0\xb9\x89\xe0\xb8\xa7\xe0\xb8\xa1\xe0\xb8\xb6\xe0\xb8\x87\xe0\xb8\x88\xe0\xb8\xb0\xe0\xb9\x83\xe0\xb8\x8a\xe0\xb9\x89\xe0\xb8\x8b\xe0\xb9\x89\xe0\xb8\xb3\xe0\xb8\x97\xe0\xb8\xb3\xe0\xb9\x84\xe0\xb8\xa1";
                            r212.TextColor3 = Color3.fromRGB(200, 80, 80);
                            v5 = r26;
                            M = v5.Create(v5, r210, TweenInfo.new(.2), {
                                ["Color"] = Color3.fromRGB(150, 60, 60)
                            });
                            M.Play(M);
                            v5 = r26;
                            M = v5.Create(v5, r213, TweenInfo.new(.2), {
                                ["BackgroundColor3"] = Color3.fromRGB(35, 35, 42)
                            });
                            M.Play(M);
                            task.wait(2);
                            v5 = r27;
                            v5.Kick(v5, "\xe0\xb8\x84\xe0\xb8\xb8\xe0\xb8\x93\xe0\xb8\x96\xe0\xb8\xb9\xe0\xb8\x81\xe0\xb9\x80\xe0\xb8\x95\xe0\xb8\xb0\xe0\xb9\x80\xe0\xb8\x99\xe0\xb8\xb7\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x87\xe0\xb8\x88\xe0\xb8\xb2\xe0\xb8\x81\xe0\xb8\xa1\xe0\xb8\xb6\xe0\xb8\x87\xe0\xb8\x82\xe0\xb9\x82\xe0\xb8\xa1\xe0\xb8\xa2 key \xe0\xb8\xab\xe0\xb8\xa3\xe0\xb8\xb7\xe0\xb8\xad hwid \xe0\xb8\x9c\xe0\xb8\xb4\xe0\xb8\x94");
                        else
                            M = "key \xe0\xb8\x9c\xe0\xb8\xb4\xe0\xb8\x94\xe0\xb9\x80\xe0\xb8\x8a\xe0\xb9\x87\xe0\xb8\x84\xe0\xb8\x81\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x99\xe0\xb9\x83\xe0\xb8\xaa\xe0\xb9\x88";
                            v5 = M[2] == M;
                            if v5 then
                                r212.Text = "Invalid key \xe0\xb9\x80\xe0\xb8\x8a\xe0\xb9\x87\xe0\xb8\x84\xe0\xb9\x83\xe0\xb8\xab\xe0\xb9\x89\xe0\xb8\x81\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x99\xe0\xb8\x81\xe0\xb9\x88\xe0\xb8\xad\xe0\xb8\x99\xe0\xb9\x83\xe0\xb8\xaa\xe0\xb9\x88";
                                r212.TextColor3 = Color3.fromRGB(200, 80, 80);
                                v5 = r26;
                                M = v5.Create(v5, r210, TweenInfo.new(.2), {
                                    ["Color"] = Color3.fromRGB(150, 60, 60)
                                });
                                M.Play(M);
                                v5 = r26;
                                M = v5.Create(v5, r213, TweenInfo.new(.2), {
                                    ["BackgroundColor3"] = Color3.fromRGB(35, 35, 42)
                                });
                                M.Play(M);
                                task.wait(2);
                                v5 = r27;
                                v5.Kick(v5, "Invalid key. Please purchase a valid key.");
                            else
                                r212.Text = "Server error";
                                r212.TextColor3 = Color3.fromRGB(200, 80, 80);
                                v5 = r26;
                                M = v5.Create(v5, r213, TweenInfo.new(.2), {
                                    ["BackgroundColor3"] = Color3.fromRGB(35, 35, 42)
                                });
                                M.Play(M);
                            end;
                            return;
                        end;
                    end; 
                end);
                return; 
            end);
            return; 
        end;
        (function(...)
            r141(function(...)
                local y = {
                    y[2],
                    y[3],
                    y[4],
                    y[5],
                    y[6],
                    y[7],
                    y[8]
                };
                v1 = P[y[3]]();
                if v1 then
                    v3 = v1 ~= "";
                end;
                if v1 then
                    if P[y[6]](v1) == "valid" then
                        P[y[8]]();
                    else
                        P[y[8]]();
                        P[y[8]]();
                    end;
                else
                    P[y[8]]();
                end;
                return; 
            end);
            return; 
        end)();
        return;
    end;
end;
return (function(...)
    while true do
        l1 = l2;
        l2 = l1;
        r3(); 
    end;
    return; 
end)();
