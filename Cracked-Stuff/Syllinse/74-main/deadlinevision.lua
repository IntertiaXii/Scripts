--[[
    DEADLINE 0.25.2 — VISION / ENVIRONMENT  (Potassium)
    ======================================================================
    Отдельный скрипт под ОДИН класс уязвимости: SHARED_STATE.

    ПОЧЕМУ ЭТО РАБОТАЕТ (разбор, а не догадка).
    Модуль module/shared_state реплицируется ТОЛЬКО в одну сторону:
    сервер -> клиент (FireAllClients). Метод :set_client(v) пишет значение
    исключительно в ЛОКАЛЬНУЮ копию — обратно на сервер не уходит ничего.
    Сервер держит собственную копию и о нашей не знает.

    А клиентский античит (FirstPersonController_extend:680-790) проверяет
    строго конечный список:
        packet 1  посторонние ScreenGui в PlayerGui
        packet 3  torso_hitbox.CanCollide / CollisionGroup   (каждый тик!)
        packet 4  char_data.collective_weight < 0
        packet 5  ammunition.velocity_drop <= 0
        packet 6  ammunition.velocity > 10000
        packet 7  properties.firing.rpm > 1500
        packet 8  build.result.dirty_properties ~= nil
        packet 9  _G.actor_started
        packet 10 controller.stop
        + illegal bodymovers на torso
    Ни одного из флагов ниже в этом списке НЕТ. Поэтому это именно обход:
    мы меняем то, что сервер не наблюдает и не может наблюдать.

    ЧЕГО ЗДЕСЬ СОЗНАТЕЛЬНО НЕТ:
      • ammunition.velocity / velocity_drop  -> packet 5/6
      • properties.firing.rpm                -> packet 7
      • любая запись в properties            -> packet 8 (dirty_properties)
    Их трогать нельзя, и мы не трогаем.

    Запуск в любой момент. Выключить: getgenv().DLV.unload()
--]]

if getgenv().DLV and getgenv().DLV.unload then
    pcall(getgenv().DLV.unload)
end

local DLV = {}
getgenv().DLV = DLV

local function log(msg)
    local out = rconsoleprint or print
    pcall(out, "[dlv] " .. tostring(msg))
end

--======================================================================
--  СТРАХОВКА ОТ ЛОВУШЕК getenv
--======================================================================
--[[
    Те же три ловушки, что и в остальных скриптах (константа "kill yourself"):
        NetworkEncode:12  caster:404  util:10
    Последняя — под if math.random(1,100) ~= 100, то есть стреляет 1 раз из
    100 на каждый map_clamped. Мы читаем SHARED_STATE, а не хукаем горячие
    функции, но защита стоит копейки и снимает целый класс случайных фризов.
--]]
--[[
    ИДЕМПОТЕНТНОСТЬ: если ловушки уже заглушил другой скрипт (обход, suite,
    movement) — не хукаем повторно. Четыре слоя hookfunction на функциях
    горячего пути не нужны никому.
--]]
local GENV_MARK = "__dl_genv_traps_killed"
local genvKilled = 0
do
    local g = getgenv()
    local already = g and rawget(g, GENV_MARK)
    if type(already) == "number" then
        genvKilled = already
    else
        local NOOP = function() end
        local okf, found = pcall(filtergc, "function", {
            Constants      = { "kill yourself" },
            IgnoreExecutor = true,
        }, false)
        if okf and type(found) == "table" then
            for _, fn in ipairs(found) do
                if type(fn) == "function" and pcall(hookfunction, fn, NOOP) then
                    genvKilled = genvKilled + 1
                end
            end
        end
        if g then pcall(rawset, g, GENV_MARK, genvKilled) end
    end
    for _, envGetter in ipairs({ getgenv, getrenv }) do
        pcall(function()
            local env = envGetter and envGetter()
            if type(env) == "table" and rawget(env, "rconsoleprint") ~= nil then
                rawset(env, "rconsoleprint", nil)
            end
        end)
    end
end

--======================================================================
--  CONFIG
--======================================================================
local CFG = {
    --[[ ── ДЫМ НАСКВОЗЬ ────────────────────────────────────────────────
        Самое сильное из всего списка. Дым — клиентская ECS-система частиц
        (client/module/ecs/system/update_smokes:120-137). Прозрачность,
        скорость появления и время жизни пыжа берутся из SHARED_STATE и
        нигде не проверяются. Ставим прозрачность 0 — дымовые гранаты
        противника перестают работать против нас, для него всё как обычно. ]]
    SeeThroughSmoke  = true,

    --[[ ── БЕЗ ПОДАВЛЕНИЯ ──────────────────────────────────────────────
        caster:676: подавление применяется только если
        SHARED_STATE.plr_suppression.value истинно. Ставим false — пули
        рядом больше не дают размытие и не сбивают прицел.
        Само подавление считается НАШИМ клиентом (caster вызывает
        u1.suppress, зарегистрированный клиентским фреймворком), поэтому
        отключение полностью в нашей власти. ]]
    NoSuppression    = true,

    --[[ ── ПОГОДА И ОСВЕЩЕНИЕ ──────────────────────────────────────────
        weather:61 — весь апдейт Lighting (ClockTime, туман, дождь,
        пресеты) идёт под флагом. Выключаем — остаётся ровное яркое
        освещение вместо ночи/тумана/ливня. Lighting сервер не читает. ]]
    DisableWeather   = true,

    --[[ ── ТРАЕКТОРИИ ПУЛЬ ─────────────────────────────────────────────
        caster:303/397 берут dbg_projectile и рисуют gizmo-линии
        (caster:590-603). Важно, что кастер на нашем клиенте обрабатывает и
        ЧУЖИЕ выстрелы (dl_replicator создаёт кастеры для реплицированных
        выстрелов) — значит видно траектории входящих пуль, то есть откуда
        по нам стреляют. ]]
    ShowProjectiles  = false,

    --[[ dbg_show_shot_trajectory (rifle_methods:145): зелёная линия — куда
         смотрит ствол, красная — фактическое направление с разбросом.
         Удобно для проверки, работает ли no-spread. ]]
    ShowShotVector   = false,

    --[[ dbg_char_gizmos (DebugVisualize:15,66): точки и цилиндры коллизии
         персонажей — фактически показ хитбоксов симуляции. ]]
    ShowCharGizmos   = false,

    --[[ ── МГНОВЕННЫЙ ЗВУК ─────────────────────────────────────────────
        dl_replicator:604/661/731 задерживают звук выстрела на
        distance / sv_sound_speed. Снижаем задержку почти до нуля — выстрелы
        слышны сразу, направление читается точнее. 1120 -> 20000. ]]
    InstantSound     = true,
    SoundSpeed       = 20000,

    --[[ ── КАМЕРА НЕ ТРЯСЁТСЯ ОТ УСТАЛОСТИ ─────────────────────────────
        plr_stamina_shake_multiplier (rifle_methods:1900) — чисто клиентская
        тряска прицела при низкой стамине.
        ОТДАЧУ (plr_recoil) ЭТОТ ТУМБЛЕР БОЛЬШЕ НЕ ТРОГАЕТ: тем ключом
        управляет No Recoil в SilentAim, и раньше два модуля перебивали друг
        друга, из-за чего ползунки отдачи работали через раз. ]]
    SteadyAim        = true,

    --[[ InfStamina УБРАН ИЗ VISION — это дубль. Им уже владеет movement-модуль
         (deadlineMovement:1493), который каждый кадр держит stamina/arm_stamina
         на максимуме напрямую в fp_controller. Два независимых механизма на одну
         функцию только мешали друг другу. ]]

    --[[ ── ЗАЩИТА ОТ ОСЛЕПЛЕНИЯ ────────────────────────────────────────
        plr_lens_flare (lens_flare:91) — вспышки от фонарей и лазеров
        противника рисует наш клиент. Выключаем. ]]
    NoLensFlare      = true,

    --[[ ── НОЧНОЕ ВИДЕНИЕ ЯРЧЕ ─────────────────────────────────────────
        plr_nv_color (NightVisionEffects:37) — только ColorCorrection на
        клиенте. Белый вместо зелёного = максимальная различимость.
        ВАЖНО: сам факт включённого ПНВ реплицируется битом
        nv_head_gear_enabled в пакете, поэтому «ПНВ без прибора» здесь НЕ
        делается — это была бы уже подделка пакета. Меняем только цвет. ]]
    BrightNVG        = false,

    --[[ ── ПРИЦЕЛИВАНИЕ В КУСТАХ ───────────────────────────────────────
        plr_aim_in_bushes (rifle:26,302) — запрет прицеливаться в зоне
        кустарника проверяется ТОЛЬКО клиентом, по локальному
        slow_movement_zone_type, который серверу не уходит. ]]
    AimInBushes      = true,

    --[[ NoDrown УБРАН ИЗ VISION — тоже дубль movement-модуля
         (deadlineMovement:1377 пишет fp_controller.water_time каждый кадр). ]]

    --[[ ── ATMOSPHERE / FOG ─────────────────────────────────────────────
        ЭТО НЕ SHARED_STATE, А ПРЯМАЯ ЗАПИСЬ В Lighting — поэтому отдельный
        механизм, а не set_shared.

        Почему нельзя поставить один раз. Дымку рисует объект Atmosphere внутри
        Lighting (в дампе он лежит под именем preset_atmosphere), и тот же
        heartbeat погоды переписывает его КАЖДЫЙ КАДР из пресета
        (weather:142-155 -> instance_properties.preset_atmosphere):
            Density 0.3/0.55 | Haze 1.05/0.2 | Glare 0.73/0.2 | Color | Decay
        Любая разовая запись живёт до следующего кадра, отсюда «поставил — и
        ничего не изменилось».

        Почему это работает сейчас. Порядок кадра в Roblox:
            PreRender -> РЕНДЕР -> физика -> Heartbeat(PostSimulation)
        Игра пишет в Heartbeat, то есть УЖЕ ПОСЛЕ рендера кадра. Мы пишем в
        PreRender — последними перед отрисовкой. Кадр рисуется нашими
        значениями, а не игровыми, и мерцания нет вообще (в отличие от записи
        по таймеру, которая гонялась бы с heartbeat-ом).

        Почему это безопасно. DisableWeather рядом ломал экран потому, что
        глушил сам драйвер освещения. Здесь драйвер жив и продолжает работать —
        мы лишь дописываем поверх его результата, и только свойства рендера.
        Ни один ac_* флаг и ни один пакет репликации Lighting не читают:
        сервер о нашей видимости не знает. При выключении тумблера возвращаем
        сохранённые значения, а следующий же heartbeat вернёт свои. ]]
    Atmosphere       = false,
    AtmoDensity      = 0.05,   -- 0..1  главное: плотность дымки, 0 = воздух чист
    AtmoOffset       = 0,      -- 0..1  смещение дымки к горизонту
    AtmoHaze         = 0,      -- 0..10 замыливание далёких силуэтов
    AtmoGlare        = 0,      -- 0..10 засветка от солнца
    AtmoColors       = false,  -- перекрашивать дымку своим цветом
    AtmoColor        = Color3.fromRGB(200, 210, 225),
    AtmoDecay        = Color3.fromRGB(70, 80, 95),

    --[[ ОБЪЁМНЫЙ ТУМАН (Volumika) — ОТДЕЛЬНЫЙ СЛОЙ ОТ ATMOSPHERE.
        Это вторая половина «Atmosphere не работает»: даже когда мы правильно
        выставляли Density = 0, дымка на экране оставалась, потому что её рисует
        не Atmosphere, а система Volumika в Workspace.
        Она включается атрибутом Enabled (dl_client:443), а сам атрибут
        привязан к shared-флагу sv_volumika: dl_client подписан на его .changed
        и сам переставляет атрибут. Поэтому пишем именно флаг через set_shared —
        тогда наше значение восстановится штатным restore_shared при выгрузке,
        а не останется висеть на инстансе. ]]
    NoVolumetricFog  = false,

    --[[ Туман — другой слой рендера, чем Atmosphere: FogEnd/FogStart в пресетах
         НЕ перечислены, поэтому игра их не крутит, но держим в том же цикле —
         одна запись в кадр стоит дешевле, чем отдельная подписка. ]]
    CustomFog        = false,
    FogStart         = 0,
    FogEnd           = 100000,
    FogColor         = Color3.fromRGB(190, 200, 215),

    KeepAlive        = true,   -- сервер может переслать значения -> переставляем
    Interval         = 2.0,
}
DLV.config = CFG

local running = true
local applied = 0

--======================================================================
--  ДОСТУП К SHARED_STATE
--======================================================================
local RS = cloneref and cloneref(game:GetService("ReplicatedStorage"))
    or game:GetService("ReplicatedStorage")

local SHARED
pcall(function()
    SHARED = require(RS.module.shared_state).SHARED_STATE
end)

--[[
    set_client — штатный путь смены значения на клиенте. Он существует именно
    для того, чтобы обойти readonly-обёртку значения, поэтому пользуемся им, а
    не прямой записью в .value. Прямая запись оставлена запасным вариантом.
--]]
local original = {}

local function set_shared(key, value)
    if not SHARED then
        return false
    end
    local obj = rawget(SHARED, key)
    if type(obj) ~= "table" then
        return false
    end
    if original[key] == nil then
        original[key] = rawget(obj, "value")
    end
    local ok = pcall(function()
        if type(obj.set_client) == "function" then
            obj:set_client(value)
        else
            obj.value = value
        end
    end)
    if ok then
        applied = applied + 1
    end
    return ok
end

local function restore_shared(key)
    local prev = original[key]
    if prev == nil then
        return
    end
    set_shared(key, prev)
end

--======================================================================
--  ATMOSPHERE / FOG  (прямая запись в Lighting, в PreRender)
--======================================================================
local Lighting = cloneref and cloneref(game:GetService("Lighting"))
    or game:GetService("Lighting")
local RunSvc = cloneref and cloneref(game:GetService("RunService"))
    or game:GetService("RunService")

--[[ ПОЧЕМУ СПИСОК, А НЕ ОДИН ИНСТАНС.
     Раньше здесь стоял `FindFirstChild("preset_atmosphere") or
     FindFirstChildOfClass("Atmosphere")`, и имя было взято из
     lighting_presets. Но `preset_atmosphere` там — это КЛЮЧ таблицы
     instance_properties, а не гарантированное имя объекта: weather:143 делает
     `Lighting:FindFirstChild(i)` по этому ключу, то есть на карте, где объект
     назван иначе, игра его просто не трогает — а мы возвращали nil и молча
     не писали НИЧЕГО. Это и был «Atmosphere не работает».
     Теперь берём ВСЕ Atmosphere-объекты в Lighting: сколько бы их ни было и
     как бы они ни назывались, все получают наши значения. ]]
local function atmo_list()
    local out = {}
    for _, ch in ipairs(Lighting:GetChildren()) do
        if ch:IsA("Atmosphere") then
            out[#out + 1] = ch
        end
    end
    return out
end

local ATMO_KEYS = { "Density", "Offset", "Haze", "Glare", "Color", "Decay" }
local FOG_KEYS  = { "FogStart", "FogEnd", "FogColor" }

local atmoOrig, atmoConn

--[[ Список объектов кэшируем: GetChildren(Lighting) каждый кадр — это новая
     таблица каждый кадр, то есть постоянный мусор для GC на ровном месте.
     Освещение не перестраивается по 60 раз в секунду, так что раз в полсекунды
     более чем достаточно. ]]
local atmoCache, atmoCacheAt = nil, 0

local function atmo_cached()
    local t = os.clock()
    if atmoCache == nil or (t - atmoCacheAt) > 0.5 then
        atmoCache = atmo_list()
        atmoCacheAt = t
    end
    return atmoCache
end

--[[ Снимок делаем ОДИН раз, при первом включении: если снимать на каждом
     включении, то вторым снимком мы бы записали свои же значения как «оригинал». ]]
local function atmo_save()
    if atmoOrig then return end
    atmoOrig = { fog = {}, atmo = {} }
    for _, k in ipairs(FOG_KEYS) do
        local ok, v = pcall(function() return Lighting[k] end)
        if ok then atmoOrig.fog[k] = v end
    end
    --[[ Оригинал храним ПО ОБЪЕКТУ, а не одним набором: если в Lighting два
         Atmosphere с разными значениями, общий снимок вернул бы им обоим
         значения последнего. ]]
    for _, a in ipairs(atmo_list()) do
        local rec = {}
        for _, k in ipairs(ATMO_KEYS) do
            local ok, v = pcall(function() return a[k] end)
            if ok then rec[k] = v end
        end
        atmoOrig.atmo[a] = rec
    end
end

local function atmo_restore()
    if not atmoOrig then return end
    for k, v in pairs(atmoOrig.fog) do
        pcall(function() Lighting[k] = v end)
    end
    for a, rec in pairs(atmoOrig.atmo) do
        for k, v in pairs(rec) do
            pcall(function() a[k] = v end)
        end
    end
    atmoOrig = nil
    atmoCache = nil
end

local function atmo_write()
    if CFG.Atmosphere then
        for _, a in ipairs(atmo_cached()) do
            a.Density = CFG.AtmoDensity
            a.Offset  = CFG.AtmoOffset
            a.Haze    = CFG.AtmoHaze
            a.Glare   = CFG.AtmoGlare
            if CFG.AtmoColors then
                a.Color = CFG.AtmoColor
                a.Decay = CFG.AtmoDecay
            end
        end
    end
    if CFG.CustomFog then
        --[[ FogEnd <= FogStart движок считает некорректным диапазоном, и туман
             схлопывается в стену перед камерой. Держим порядок сами. ]]
        local s = CFG.FogStart
        local e = CFG.FogEnd
        if e <= s then e = s + 1 end
        Lighting.FogStart = s
        Lighting.FogEnd   = e
        Lighting.FogColor = CFG.FogColor
    end
end

--[[ Подписка живёт только пока хоть один из двух тумблеров включён: выключил —
     сняли и вернули игровые значения, ни одного лишнего вызова в кадре. ]]
local function atmo_sync()
    local want = CFG.Atmosphere or CFG.CustomFog
    if want and not atmoConn then
        atmo_save()
        --[[ PreRender — современное имя того же сигнала, что RenderStepped.
             Индексация отсутствующего свойства бросает ошибку, поэтому pcall. ]]
        local sig
        pcall(function() sig = RunSvc.PreRender end)
        sig = sig or RunSvc.RenderStepped
        atmoConn = sig:Connect(function()
            if not running then return end
            pcall(atmo_write)
        end)
    elseif not want and atmoConn then
        atmoConn:Disconnect()
        atmoConn = nil
        atmo_restore()
    end
end

--======================================================================
--  ВЕЧНЫЙ ДЕНЬ (замкнутая коррекция сдвига времени)
--======================================================================
--[[ Целимся в 12:00. По lighting_presets у всех пресетов day_time = 10 или 12
     при night_time = 24, а яркость (weather:110-116) считается так:
         day_time < t  ->  map(t, day_time, night_time, 1, 0)
         иначе         ->  t / day_time
     При t = 12 это даёт 1.0 для пресетов с day_time = 12 и 0.86 для day_time = 10,
     то есть светло в любом случае. ]]
local DAY_TARGET = 12

--[[ Одна итерация коррекции. Возвращает true, когда время уже на месте, —
     дальше можно не трогать sv_time_offset вообще. ]]
local function correct_daylight()
    if not SHARED then return false end
    local done = false
    pcall(function()
        local cur = Lighting.ClockTime
        local off = SHARED.sv_time_offset and SHARED.sv_time_offset.value or 0
        local diff = (DAY_TARGET - cur) % 24
        if diff > 12 then diff = diff - 24 end     -- крутим в короткую сторону
        if math.abs(diff) < 0.05 then
            done = true
            return
        end
        set_shared("sv_time_offset", (off + diff) % 24)
    end)
    return done
end

--[[ Ждём, пока heartbeat погоды отработает хотя бы раз (иначе ClockTime ещё не
     отражает внутреннее время игры), и правим сдвиг. Ограничиваем попытки,
     чтобы не крутиться вечно, если освещением управляет не этот драйвер. ]]
--[[ Флаг-страж: apply() вызывается ещё и KeepAlive-циклом каждые 2 с, поэтому
     без него мы плодили бы новый поток коррекции на каждой итерации. ]]
local holding = false
local function hold_daylight()
    if holding then return end
    holding = true
    task.spawn(function()
        for _ = 1, 20 do
            if not running or not CFG.DisableWeather then break end
            game:GetService("RunService").Heartbeat:Wait()
            if correct_daylight() then break end
        end
        holding = false
    end)
end

--======================================================================
--  ПРИМЕНЕНИЕ
--======================================================================
local function apply()
    applied = 0

    --[[ ДЫМ — только ОДИН безопасный параметр.
         update_smokes:136 делает
             math.clamp(cfg_smoke_fade_out_start, cfg_smoke_fade_in_end, 0.99)
         поэтому fade_in_end = 1 даёт min(1) > max(0.99) -> Luau бросает ошибку
         каждый кадр (ClientScheduler ловит её xpcall'ом и спамит warn, дым при
         этом вообще не обновляется). emit_rate = 0 идёт в 1/v54 на строке 172.
         Прозрачность даёт update_smokes:276 — v94 = clamp(v93,0,1) * max_opacity,
         так что max_opacity = 0 достаточно и ничего не ломает. ]]
    set_shared("cfg_smoke_max_opacity", CFG.SeeThroughSmoke and 0 or 0.55)
    -- вернуть дефолты игры, если их испортила предыдущая версия скрипта
    set_shared("cfg_smoke_fade_in_end", 0.01)
    set_shared("cfg_smoke_fade_out_start", 0.8)
    set_shared("cfg_smoke_emit_rate", 11)

    if CFG.NoSuppression then
        set_shared("plr_suppression", false)
    end

    --[[ Объёмный туман. Ставим только когда тумблер включён: sv_volumika по
         умолчанию false (shared_state:145), и безусловная запись false
         зафиксировала бы у нас «выключено» даже на картах, где сервер его
         включает — а потом restore_shared вернул бы не то, что было. ]]
    if CFG.NoVolumetricFog then
        set_shared("sv_volumika", false)
    end

    --[[ ══ ЭТО И БЫЛ ЧЁРНЫЙ ЭКРАН (проверено по дампу) ══════════════════
         weather:61 — `if SHARED_STATE.dbg_disable_weather.value then return nil end`
         стоит в САМОМ НАЧАЛЕ heartbeat-а, а этот heartbeat — ЕДИНСТВЕННОЕ, что
         вообще ведёт освещение карты:
             :81  Lighting.ClockTime = v20
             :128 Lighting[i] = math.map(...)      (пресеты освещения)
             :130 Lighting[i] = read_color_data(...)
             :158 Lighting.OutdoorAmbient = ...
             + VOLUMIKA (объёмный свет/туман)
         Ставя флаг в true, мы навсегда останавливали драйвер освещения, и сцена
         ��ставалась неинициализированной = ЧЁРНЫЙ ЭКРАН. Флаг НЕ пишем никогда;
         наоборот, форсим false, если его успела выставить прошлая версия.

         Вместо этого «вечный день» делаем ЛЕГАЛЬНЫМИ входами того же heartbeat-а
         (weather:79-81):  ClockTime = (u5 + sv_time_offset) % 24
             sv_day_cycle_speed = 0  -> время перестаёт бежать (день не сменится);
             sv_time_offset       -> сдвигаем так, чтобы ClockTime стал ~12:00.
         Драйвер остаётся живым -> свет есть. ]]
    set_shared("dbg_disable_weather", false)
    if CFG.DisableWeather then
        --[[ ══ А ВОТ ЭТО БЫЛ ВТОРОЙ, ЕЩЁ ЖИВОЙ ЧЁРНЫЙ ЭКРАН ═══════════════
             Прошлая версия считала сдвиг ОДИН РАЗ, прямо в apply(), и брала
             текущее время из Lighting.ClockTime:
                 off = (off + (12 - Lighting.ClockTime)) % 24

             Но apply() вызывается СРАЗУ при загрузке модуля, когда heartbeat
             погоды ещё ни разу не отработал. Значит Lighting.ClockTime в этот
             момент — НЕ игровое время, а то, что лежит в place-файле. Внутренний
             счётчик игры u7 (weather:79) с ним никак не связан.

             Дальше мы тем же apply() ставили sv_day_cycle_speed = 0, то есть
             ЗАМОРАЖИВАЛИ u7. В итоге неверный сдвиг фиксировался НАВСЕГДА:
                 v23 = (u7 + off) % 24  ->  например 22:00
             а при day_time = 12 (lighting_presets:26) яркость считается как
                 map(22, 12, 24, 1, 0) = 0.17
             то есть почти полная ночь, и время больше не идёт. Вечная ночь и
             есть тот самый чёрный экран при запуске.

             ТЕПЕРЬ ЗАМКНУТАЯ ПЕТЛЯ. Сначала морозим цикл, а сдвиг правим уже
             ПОСЛЕ того, как heartbeat отработал: тогда Lighting.ClockTime
             гарантированно равен (u7 + off) % 24, и коррекция
                 off += target - ClockTime
             попадает точно в цель. u7 заморожен, поэтому одной итерации хватает,
             а KeepAlive-цикл продолжает проверять и починит любой сброс с сервера.
             Промахнуться в темноту эта схема уже не может: она сама себя правит. ]]
        set_shared("sv_day_cycle_speed", 0)
        hold_daylight()
    else
        -- тумблер выключили — возвращаем ход суток, каким он был до нас
        restore_shared("sv_day_cycle_speed")
        restore_shared("sv_time_offset")
    end

    set_shared("dbg_projectile", CFG.ShowProjectiles and true or false)
    set_shared("dbg_show_shot_trajectory", CFG.ShowShotVector and true or false)
    set_shared("dbg_char_gizmos", CFG.ShowCharGizmos and true or false)

    if CFG.InstantSound then
        set_shared("sv_sound_speed", CFG.SoundSpeed)
    end

    --[[ SteadyAim БОЛЬШЕ НЕ ТРОГАЕТ plr_recoil. Этот ключ — общий множитель
         отдачи, и им же управляет No Recoil в SilentAim. Два модуля писали в
         одно значение и перебивали друг друга: ползунки отдачи в SA то работали,
         то нет, в зависимости от того, кто применился последним. Здесь остаётся
         только тряска от усталости — она к отдаче не относится. ]]
    if CFG.SteadyAim then
        set_shared("plr_stamina_shake_multiplier", 0)
    end

    if CFG.NoLensFlare then
        set_shared("plr_lens_flare", false)
    end

    if CFG.BrightNVG then
        set_shared("plr_nv_color", Color3.fromRGB(255, 255, 255))
    end

    if CFG.AimInBushes then
        set_shared("plr_aim_in_bushes", false)
    end

    -- NoDrown убран: им владеет movement-модуль, который каждый кадр
    -- переписывает fp_controller.water_time напрямую (deadlineMovement:1377).
    -- Дублировать это здесь было незачем.

    -- Atmosphere живёт вне SHARED_STATE, поэтому его подписку ведём отдельно
    pcall(atmo_sync)
end

--[[ Раньше здесь был безусловный apply() прямо на этапе загрузки файла. Это
     вторая половина проблемы с чёрным экраном: модуль применял свои дефолты
     (а DisableWeather по умолчанию = true) ДО того, как загрузчик успевал
     вызвать start() и до того, как погода вообще инициализировалась. Теперь
     первый apply() делает start() — то есть тогда, когда модуль реально включают. ]]

if CFG.KeepAlive then
    task.spawn(function()
        while running do
            task.wait(CFG.Interval)
            pcall(apply)
        end
    end)
end

--======================================================================
--  ДИАГНОСТИКА / ВЫГРУЗКА
--======================================================================
DLV.debug = function()
    --[[ Число найденных Atmosphere-объектов выводим специально: если тумблер
         «не работает», первый вопрос — есть ли вообще что писать. ]]
    local s = ("shared=%s applied=%d genv-traps=%d atmo-instances=%d")
        :format(tostring(SHARED ~= nil), applied, genvKilled, #atmo_list())
    log(s)
    return s
end

DLV.unload = function()
    running = false
    --[[ Сначала снимаем подписку рендера, потом возвращаем знач��ния: иначе наш
         же PreRender успел бы записать их обратно уже после restore. ]]
    if atmoConn then
        pcall(function() atmoConn:Disconnect() end)
        atmoConn = nil
    end
    pcall(atmo_restore)
    for key in pairs(original) do
        pcall(restore_shared, key)
    end
    if getgenv().DLV == DLV then
        getgenv().DLV = nil
    end
    log("unloaded (original values restored)")
end

if not SHARED then
    log("ERROR: could not get SHARED_STATE - run after the game has loaded")
else
    log(("armed | flags set: %d | genv-traps: %d"):format(applied, genvKilled))
    log("see-thru-smoke: " .. tostring(CFG.SeeThroughSmoke) ..
        " | no-suppression: " .. tostring(CFG.NoSuppression) ..
        " | no-weather: " .. tostring(CFG.DisableWeather))
    log("NOT touching: velocity / velocity_drop / rpm / properties = packets 5/6/7/8")
end

--======================================================================
--  LOADER MODULE  (Syllinse Project / MacLib)
--======================================================================
return {
    -- everything starts OFF and is applied immediately
    --[[ Модуль стартует ВЫКЛЮЧЕННЫМ по всем визуальным правкам: включать их
         должен ты тумблерами, а не факт загрузки скрипта. Особенно это важно для
         DisableWeather — именно его автовключение на старте и давало чёрный экран.
         Строки с InfStamina / NoDrown убраны: этих полей в модуле больше нет. ]]
    start = function()
        CFG.SeeThroughSmoke, CFG.NoSuppression, CFG.DisableWeather = false, false, false
        CFG.ShowProjectiles, CFG.ShowShotVector, CFG.ShowCharGizmos = false, false, false
        CFG.InstantSound, CFG.SteadyAim = false, false
        CFG.NoLensFlare, CFG.BrightNVG, CFG.AimInBushes = false, false, false
        CFG.Atmosphere, CFG.AtmoColors, CFG.CustomFog = false, false, false
        CFG.NoVolumetricFog = false
        pcall(apply)
    end,

    stop = function()
        if DLV and type(DLV.unload) == "function" then pcall(DLV.unload) end
    end,

    buildUI = function(ctx)
        local ready = false
        task.defer(function() ready = true end)
        local function note(t, b) if ready then pcall(ctx.notify, t, b) end end

        -- every toggle re-applies immediately: these are plain state flags
        local function bool(sec, name, o)
            sec:Toggle({ Name = name, Default = o.Default == true,
                Callback = function(v)
                    o.set(v and true or false)
                    pcall(apply)
                    note(name, v and "Enabled" or "Disabled")
                end }, ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
        end

        local function slider(sec, o)
            sec:Slider({ Name = o.Name, Default = o.Default, Minimum = o.Min, Maximum = o.Max,
                Precision = o.Precision or 0, Suffix = o.Suffix,
                Callback = function(v) o.Callback(v); pcall(apply) end }, ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
        end

        local function color(sec, o)
            sec:Colorpicker({ Name = o.Name, Default = o.Get(),
                Callback = function(c) o.Callback(c) end }, ctx.flag(o.Flag))
        end

        --==============================================================
        -- TAB: VISUALS  (world flags; ESP sections come from the suite)
        --==============================================================
        -- master switch + empty keybind, one per feature section
        local function feature(sec, o)
            local guard, el = false, nil
            local function commit(v)
                v = v and true or false
                o.set(v)
                pcall(apply)
                note(o.Title, v and "Enabled" or "Disabled")
                guard = true
                if el then pcall(function() el:UpdateState(v) end) end
                guard = false
            end
            el = sec:Toggle({ Name = "Enabled", Default = false,
                Callback = function(v) if not guard then commit(v) end end },
                ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
            ctx.keybind(sec, { Name = "Keybind", Flag = ctx.flag(o.Flag .. "_KB"),
                Toggle = function() commit(not o.get()) end })
        end

        --==============================================================
        -- TAB: VISUALS  (world flags; ESP sections come from the suite)
        --==============================================================
        local V = ctx.tabs.Visuals

        local w1 = V:Section({ Side = "Right" })
        w1:Header({ Name = "See Through Smoke" })
        feature(w1, { Title = "See Through Smoke", Flag = "WD_Smoke",
            get = function() return CFG.SeeThroughSmoke end,
            set = function(v) CFG.SeeThroughSmoke = v end,
            Desc = "smoke opacity 0 = enemy smokes stop working on you" })

        local w2 = V:Section({ Side = "Right" })
        w2:Header({ Name = "Disable Weather" })
        feature(w2, { Title = "Disable Weather", Flag = "WD_Weather",
            get = function() return CFG.DisableWeather end,
            set = function(v) CFG.DisableWeather = v end,
            Desc = "flat bright lighting instead of night, fog and rain" })

        local w3 = V:Section({ Side = "Right" })
        w3:Header({ Name = "No Lens Flare" })
        feature(w3, { Title = "No Lens Flare", Flag = "WD_Flare",
            get = function() return CFG.NoLensFlare end,
            set = function(v) CFG.NoLensFlare = v end,
            Desc = "no blinding from enemy flashlights and lasers" })

        local w4 = V:Section({ Side = "Right" })
        w4:Header({ Name = "Bright NVG" })
        feature(w4, { Title = "Bright NVG", Flag = "WD_NVG",
            get = function() return CFG.BrightNVG end,
            set = function(v) CFG.BrightNVG = v end,
            Desc = "white night vision instead of green" })

        --==============================================================
        -- TAB: MISC
        --==============================================================
        local X = ctx.tabs.Misc

        local x1 = X:Section({ Side = "Left" })
        x1:Header({ Name = "No Suppression" })
        feature(x1, { Title = "No Suppression", Flag = "MS_NoSupp",
            get = function() return CFG.NoSuppression end,
            set = function(v) CFG.NoSuppression = v end,
            Desc = "no blur or aim shake from nearby bullets" })

        local x2 = X:Section({ Side = "Right" })
        x2:Header({ Name = "Steady Aim" })
        feature(x2, { Title = "Steady Aim", Flag = "MS_Steady",
            get = function() return CFG.SteadyAim end,
            set = function(v) CFG.SteadyAim = v end,
            Desc = "removes the low-stamina aim shake (recoil lives in Silent Aim)" })

        -- "Infinite Stamina" здесь больше нет: тумблер живёт в movement-табе
        local x4 = X:Section({ Side = "Right" })
        x4:Header({ Name = "Aim In Bushes" })
        feature(x4, { Title = "Aim In Bushes", Flag = "MS_Bushes",
            get = function() return CFG.AimInBushes end,
            set = function(v) CFG.AimInBushes = v end,
            Desc = "the bush aim block is client-only" })

        local x5 = X:Section({ Side = "Left" })
        x5:Header({ Name = "Instant Sound" })
        feature(x5, { Title = "Instant Sound", Flag = "MS_Sound",
            get = function() return CFG.InstantSound end,
            set = function(v) CFG.InstantSound = v end,
            Desc = "removes the distance delay on gunshots" })
        slider(x5, { Name = "Sound Speed", Flag = "MS_SoundSpd", Default = 20000,
            Min = 1120, Max = 40000,
            Callback = function(v) CFG.SoundSpeed = v end,
            Desc = "game default is 1120" })

        --[[ Atmosphere отдельной секцией, а не внутри Disable Weather: тот глушит
             драйвер освещения целиком, этот дописывает поверх живого драйвера.
             Смешивать их в одном тумблере значило бы вернуть чёрный экран. ]]
        local x6 = X:Section({ Side = "Left" })
        x6:Header({ Name = "Atmosphere" })
        feature(x6, { Title = "Atmosphere", Flag = "MS_Atmo",
            get = function() return CFG.Atmosphere end,
            set = function(v) CFG.Atmosphere = v end,
            Desc = "clears the haze the map draws over distant enemies" })
        --[[ Volumika живёт в этой же секции: без неё Density = 0 визуально
             ничего не менял, потому что дымку на экране рисует именно она. ]]
        bool(x6, "No Volumetric Fog", { Flag = "MS_NoVolum", Default = false,
            set = function(v) CFG.NoVolumetricFog = v end,
            Desc = "Volumika layer, this is what actually hides distance" })
        slider(x6, { Name = "Density", Flag = "MS_AtmoDens", Default = CFG.AtmoDensity,
            Min = 0, Max = 1, Precision = 2,
            Callback = function(v) CFG.AtmoDensity = v end,
            Desc = "map uses 0.3 by day and 0.55 at night" })
        slider(x6, { Name = "Haze", Flag = "MS_AtmoHaze", Default = CFG.AtmoHaze,
            Min = 0, Max = 10, Precision = 2,
            Callback = function(v) CFG.AtmoHaze = v end,
            Desc = "blur on far silhouettes, map uses 1.05" })
        slider(x6, { Name = "Glare", Flag = "MS_AtmoGlare", Default = CFG.AtmoGlare,
            Min = 0, Max = 10, Precision = 2,
            Callback = function(v) CFG.AtmoGlare = v end,
            Desc = "sun washout, map uses 0.73" })
        slider(x6, { Name = "Offset", Flag = "MS_AtmoOff", Default = CFG.AtmoOffset,
            Min = 0, Max = 1, Precision = 2,
            Callback = function(v) CFG.AtmoOffset = v end })
        bool(x6, "Custom Colors", { Flag = "MS_AtmoCol", Default = false,
            set = function(v) CFG.AtmoColors = v end,
            Desc = "off = keep the map colors, only clear the density" })
        color(x6, { Name = "Haze Color", Flag = "MS_AtmoC1",
            Get = function() return CFG.AtmoColor end,
            Callback = function(c) CFG.AtmoColor = c; pcall(apply) end })
        color(x6, { Name = "Decay Color", Flag = "MS_AtmoC2",
            Get = function() return CFG.AtmoDecay end,
            Callback = function(c) CFG.AtmoDecay = c; pcall(apply) end })

        local x7 = X:Section({ Side = "Left" })
        x7:Header({ Name = "Custom Fog" })
        feature(x7, { Title = "Custom Fog", Flag = "MS_Fog",
            get = function() return CFG.CustomFog end,
            set = function(v) CFG.CustomFog = v end,
            Desc = "separate render layer from Atmosphere" })
        slider(x7, { Name = "Fog Start", Flag = "MS_FogS", Default = CFG.FogStart,
            Min = 0, Max = 5000,
            Callback = function(v) CFG.FogStart = v end })
        slider(x7, { Name = "Fog End", Flag = "MS_FogE", Default = CFG.FogEnd,
            Min = 1, Max = 100000,
            Callback = function(v) CFG.FogEnd = v end,
            Desc = "keep it high to see across the map" })
        color(x7, { Name = "Fog Color", Flag = "MS_FogC",
            Get = function() return CFG.FogColor end,
            Callback = function(c) CFG.FogColor = c; pcall(apply) end })

        -- "No Drown" здесь больше нет: тумблер живёт в movement-табе

        --==============================================================
        -- TAB: DEBUG  (created by the loader)
        --==============================================================
        local D = ctx.tabs.Debug

        local d1 = D:Section({ Side = "Right" })
        d1:Header({ Name = "Show Projectiles" })
        feature(d1, { Title = "Show Projectiles", Flag = "WD_Proj",
            get = function() return CFG.ShowProjectiles end,
            set = function(v) CFG.ShowProjectiles = v end,
            Desc = "all bullet paths, incoming ones too" })

        local d2 = D:Section({ Side = "Left" })
        d2:Header({ Name = "Show Shot Vector" })
        feature(d2, { Title = "Show Shot Vector", Flag = "WD_ShotVec",
            get = function() return CFG.ShowShotVector end,
            set = function(v) CFG.ShowShotVector = v end,
            Desc = "green = barrel, red = real direction with spread" })

        local d3 = D:Section({ Side = "Right" })
        d3:Header({ Name = "Show Hitboxes" })
        feature(d3, { Title = "Show Hitboxes", Flag = "WD_Gizmos",
            get = function() return CFG.ShowCharGizmos end,
            set = function(v) CFG.ShowCharGizmos = v end,
            Desc = "character collision cylinders" })
    end,
}
