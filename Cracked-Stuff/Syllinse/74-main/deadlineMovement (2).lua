--[[
    DEADLINE 0.25.2 — MOVEMENT  (Potassium)
    ======================================================================
    Обход (deadline_bypass.lua) запускается ОТДЕЛЬНО и ПЕРВЫМ.

    ЧТО ФАКТИЧЕСКИ ЛОВИТ АНТИЧИТ (найдено в дампе по причинам смерти в хитлоге
    и по флагам SHARED_STATE):
        ac_airtime_kill = true   -> причина смерти "airtime_timeout"
                                    ("Airtime timeout"): слишком долго в воздухе
        ac_movement     = true   -> серверная проверка перемещения (скорость)
        ac_sound_kill   = true
        ac_shot_timeout = 15
        + серверный debug_failed_sanity_check
    Плюс клиентские пакеты-репорты (нейтрализуются deadline_bypass):
        3 = torso_hitbox.CanCollide/CollisionGroup (каждый тик!)
        2 = bodymovers на своём torso
        10 = вызов методов FPC через _G (игра пишет туда ctrl.stop)

    ИЗ ЭТОГО СЛЕДУЮТ ПРАВИЛА, НА КОТОРЫХ ПОСТРОЕН ЭТОТ СКРИПТ:
      • Сервер знает о нас позицию, скорость, метку времени, позу, aiming,
        lean и вес снаряжения. Подменять их нельзя — либо десинк, либо ac_movement.
      • Значит скорость поднимаем ТОЛЬКО убирая ЛОКАЛЬНЫЕ штрафы, о которых
        сервер не знает (стамина, штраф после приземления). Максимум позы при
        этом не превышаем -> проверке нечего ловить. Это режим LegitMax.
      • Воздух ограничен airtime. Поэтому Fly держится в зоне определения
        земли (grounded остаётся true, airtime не копится), а для высокого
        полёта есть страховка: перед лимитом сами касаемся земли.
      • torso_hitbox трогать нельзя, а он и есть коллайдер -> NoClip сделан
        через Anchored + ручное ведение CFrame (у anchored части коллизии
        физикой не разрешаются).

    Выключить: getgenv().DLM.unload()   |   Конфиг: getgenv().DLM.config
--]]

if getgenv().DLM and getgenv().DLM.unload then
    pcall(getgenv().DLM.unload)
end

local DLM = {}
getgenv().DLM = DLM

local function log(msg)
    local out = rconsoleprint or print
    pcall(out, "[dlm] " .. tostring(msg))
end

--======================================================================
--  CONFIG
--======================================================================
local CFG = {
    -- ── SPEED ────────────────────────────────────────────────────────
    Speed            = false,
    SpeedKey         = Enum.KeyCode.L,
    --[[ LegitMax — база: снимаем ЛОКАЛЬНЫЕ штрафы (стамина, замедление после
         приземления), о которых сервер не знает. Максимум позы не превышаем. ]]
    LegitMax         = true,
    --[[ BURST — рабочий рычаг. У серверной проверки есть окно терпимости
         (на практике рывок в 1-2 секунды проходит). Поэтому разгоняемся
         короткими импульсами и обязательно возвращаемся к норме, чтобы
         средняя скорость за окно осталась легальной. ]]
    BurstSpeed       = true,
    SpeedMultiplier  = 2.2,
    BurstOnTime      = 0.8,          -- сек импульса (держим < 1с)
    BurstOffTime     = 0.7,          -- сек отдыха на нормальной скорости
    --[[ Постоянный множитель без импульсов — именно он и ловится ac_movement. ]]
    ConstantMultiplier = false,

    --[[ ── FLY ─────────────────────────────────────────────────────────
        Скорость полёта — ПОРОГОВАЯ и отдельная от скорости персонажа: Fly
        больше не трогает overrides.speed вообще. По умолчанию держим в
        легальных рамках, чтобы серверная проверка перемещения молчала.
    --]]
    Fly              = false,
    FlyKey           = Enum.KeyCode.F,
    FlySpeed         = 22,           -- порог: держим на уровне легального бега
    FlySmooth        = 0.35,         -- сглаживание (0 = резко, 1 = вязко)
    --[[ false = рабочая схема (анкор + CFrame): не флагается, но проходит
         сквозь геометрию. true = полёт через скорость: стены не проходит,
         но риск airtime-детекта выше. ]]
    FlyCollide       = false,
    FlyUpKey         = Enum.KeyCode.Space,
    FlyDownKey       = Enum.KeyCode.LeftControl,

    --[[ ── СПУФ СОСТОЯНИЯ (главный обход воздуха) ───────────────────────
        В пакете репликации есть бит is_climbing (FPC_extend:575,
        write_bool(u82.is_climbing)) — «я на лестнице», т.е. ЛЕГАЛЬНОЕ
        длительное пребывание в воздухе с вертикальным движением.

        ВАЖНО: поле fp_controller.is_climbing трогать НЕЛЬЗЯ — по нему игра
        убирает оружие и рвёт бинды:
            v189 = is_freecam() or fp_controller.is_climbing
            if v189 and weapon.is_equipped ... item_manager:unequip_weapon(true)
                                               input_group:disconnect_all_binds()
        Именно поэтому в полёте пропадал ствол. Поэтому поле поднимается лишь
        на время сборки пакета (write_time -> compress_position), а всё
        остальное время остаётся как было — клиент ничего не замечает.
    --]]
    SpoofClimbing    = true,

    --[[ ── СПУФ ПОЗЫ ─────────────────────────────────────────────────────
        Сервер берёт допустимую скорость из РЕПЛИЦИРОВАННОЙ позы
        (walkspeed: idle 14, running 25, crouching 8, prone 6). Летим 22 ст/с
        стоя — это выше лимита idle, отсюда «тпхает назад, когда не бегаю».
        Поэтому в пакете подменяем позу на 4 (running): лимит 25, наши 22
        проходят как легальные. Это обход проверки, а не подстройка под неё. ]]
    SpoofRunningPose = true,

    --[[ ── FREE GUN ─────────────────────────────────────────────────────
        Страховка: если игра всё же убрала ствол (freecam, лестница, любая
        причина) — сразу возвращаем его и восстанавливаем бинды. ]]
    FreeGun          = true,

    --[[ Generic-детекты полёта (по практике) смотрят на связку
         «время в воздухе + velocity.Y > 0». Мы двигаемся через CFrame под
         анкором, поэтому скорость остаётся нулевой и признак «летит вверх»
         не появляется. Дополнительно можно вообще не давать velocity расти. ]]
    KeepVelocityZero = true,

    --[[ ── ОБХОД AIRTIME_TIMEOUT (то, что убивало в небе) ───────��───────
        Причина смерти найдена точно. Список причин смерти зашит в клиенте
        (DeathView:216-232):
            took_damage | reset | airtime_timeout | drowned |
            took_explosion_damage | took_fire_damage | killed_via_console
        Значит в воздухе нас убивает СЕРВЕРНЫЙ таймер airtime_timeout. Клиент
        его не считает вообще — поэтому локально «зацепиться» не за что, и
        любые попытки чинить это на клиенте были мимо.

        Сервер знает о нас только из пакета репликации (FPC_extend:568-620):
            write_time | nvg | aiming | is_climbing | lean | pose |
            compress_position | compress_velocity | look
        Больше НИЧЕГО. Значит счётчик воздуха сбрасывается только тогда, когда
        по реплицированной позиции мы оказываемся на земле.

        ЧЕМ ЭТО РЕШЕНО СЕЙЧАС: не разовым «касанием», а НЕПРЕРЫВНОЙ ПРОЕКЦИЕЙ
        (CFG.GroundProject ниже, реализация в project_y). Разовый ping не мог
        работать в принципе: чтобы сервер увидел землю, надо отправить землю, а
        следующим пакетом вернуться наверх — мгновенный подъём ловит ac_movement.
        Из-за этого подстановку зажали порогом, и она почти никогда не
        срабатывала. Проекция же врёт по Y ПОСТОЯННО, поэтому возвращаться
        никуда не нужно: для сервера мы просто всё время идём по земле, и
        счётчик воздуха не запускается вообще. ]]

    --[[ ── AUTO TOUCHDOWN: ГАРАНТИРОВАННЫЙ СБРОС СЕРВЕРНОГО AIRTIME ──────
        ЧЕСТНО О ГРАНИЦЕ ВОЗМОЖНОГО.
        Лимит времени в воздухе живёт в SHARED_STATE.ac_airtime_kill
        (shared_state:298, описание в insi_shared_state_descriptions:9 —
        «Whether staying in the air will kill you»). Локально его НЕ выключить:
        репликация состояния строго односторонняя, сервер -> клиент
            shared_state:  script.download:InvokeServer()   -- скачать всё
                           changed.OnClientEvent -> set_client(...)
        и ни одного ClientToServer для состояния в дампе нет. Сервер держит
        свою копию и о нашей не знает, поэтому set_client("ac_airtime_kill",
        false) не даёт ничего. Ни один из четырёх ac_* флагов в клиенте вообще
        не читается — они целиком серверные.

        Подделать позицию тоже не выход: «виртуальное касание» требует потом
        ВЕРНУТЬ отчётную позицию на высоту, а мгновенный подъём на сотни студов
        физически невозможен и ловится ac_movement. Спуск-то легален (падение
        разгоняется до сотен ст/с), а подъём — нет.

        Поэтому единственный надёжный сброс — РЕАЛЬНО коснуться земли и снова
        подняться. Для сервера это обычный игрок, который прыгал; счётчик
        воздуха обнуляется, и полёт продолжается. Делаем это сами, быстро и
        автоматически, с возвратом на исходную высоту.

        Ставь AutoTouchdownAfter меньше серверного лимита. Точное значение
        лимита в дампе отсутствует (оно на сервере), поэтому 8 секунд — с
        запасом. Если в консоли увидишь HITLOG type=airtime_timeout — уменьшай.
    --]]
    AutoTouchdown       = true,
    AutoTouchdownAfter  = 8.0,       -- сек полёта до касания
    AutoTouchdownSpeed  = 120,       -- скорость спуска (падение легально быстрое)
    AutoTouchdownReturn = true,      -- вернуться на прежнюю высоту после касания

    --[[ ── ЛОГ ПРИЧИНЫ СМЕРТИ ───────────────────────────────────────────
        Сервер сам присылает записи хитлога (ServerToClient
        995825.1875876792, ClientFramework:1052). Печатаем их — и «что меня
        убило» становится фактом, а не версией. Если увидишь
        type=airtime_timeout, значит is_climbing сервером НЕ считается
        исключением, и полагаться надо на AutoTouchdown. ]]
    LogDeathReason   = true,

    --[[ Старая страховка «принудительно приземлиться» — оставлена как
         аварийный вариант; AutoTouchdown выше делает то же самое, но умнее
         (с возвратом на высоту).
         ВАЖНО: даже включённая, она теперь молчит, пока падение/полёт скрывает
         Ground Projection (projCovers) — иначе полёт дёргался бы к земле каждые
         FlyAirtimeLimit секунд без всякой необходимости. Реально срабатывает
         только над пропастью или при выключенной проекции. ]]
    ForceTouchdown   = false,
    FlyAirtimeLimit  = 3.0,          -- сек в воздухе до принудительного касания
    FlyTouchdownTime = 0.35,

    -- ── NOCLIP ───────────────────────────────────────────────────────
    --[[ РЫЧАГ: игра КАЖДЫЙ тик делает
             HRP.Anchored = fp_controller:is_freecam() or lifetime.is_player_anchored
         (ClientFramework:1271). Именно поэтому прошлый noclip не работал —
         движок сбрасывал наш Anchored обратно. Ставим сам флаг
         lifetime_state.is_player_anchored = true, и тогда АНКОРИТ САМА ИГРА,
         а мы ведём HRP.CFrame — ровно тот путь, которым движок двигает
         персонажа во время вольта (Anchored + запись CFrame).
         torso_hitbox при этом не трогаем (пакет 3). ]]
    NoClip           = false,
    NoClipKey        = Enum.KeyCode.N,
    NoClipSpeed      = 22,           -- держим в легальных рамках (ac_movement)
    --[[ Позицию при ноклипе шлём ЧЕСТНО. Сглаживание отчётной позиции убрано:
         оно давало реальный десинк, из-за которого при выходе из стены дёргало
         назад и иногда убивало. Держим скорость легальной — этого достаточно. ]]
    --[[ Снятие анкора внутри геометрии = выброс физикой и «смерть без причины».
         Перед выходом ищем свободное место. ]]
    NoClipSafeExit     = true,

    -- ── ПРЫЖКИ ───────────────────────────────────────────────────────
    Bhop             = false,
    BhopKey          = Enum.KeyCode.B,
    AirControl       = false,        -- plr_jump_control_momentum: сервер знает поле
    InstantVault     = true,

    -- ── ПАССИВНЫЕ (локальные, серверу неизвестны) ─────────────────────
    InfStamina       = true,
    NoLandingPenalty = true,

    --[[ ── ANTI-DROWN ───────────────────────────────────────────────────
        Единственная смерть, о которой сервер узнаёт ОТ НАС (ClientFramework:
        1329-1332). ��ержим water_time на максимуме — доклад не отправляется
        никогда. Особенно важно в полёте: зона воды проверяется по позиции
        КАМЕРЫ, а не тела. ]]
    AntiDrown        = true,

    --[[ ── ANTI-VOTEKICK ────────────────────────────────────────────────
        Всплывающее окно голосования присылает сервер
        (namespace 477961.1280885361 -> 299484.2376342709), а наш голос уходит
        через 812177.1199294078. Мы: (а) сразу голосуем «против», чтобы наш
        голос не потерялся и окно не мешало, (б) видим в логе, что голосование
        началось и против кого — это раннее предупреждение, времени хватает
        выключить всё и не попасть под кик. ]]
    AntiVotekick     = true,
    VotekickAutoNo   = true,

    --[[ ── NO FALL ──────────────────────────────────────────────────────
        Клиент урон падения НЕ применяет: в ClientFramework на приземлении
        только тряска камеры и landing_walkspeed_timer, никакого FireServer.
        Значит урон считает СЕРВЕР по реплицированному падению — поэтому флаг
        plr_fall_damage=false ничего и не давал.
        Работающий путь один: не дать состояться быстрому падению. Гасим
        вертикальную скорость до безопасной, т.е. спускаемся мягко.
    --]]
    NoFall             = true,
    FallMaxSpeed       = 28,        -- макс. скорость падения (studs/s), локальный слой

    --[[ ── GROUND PROJECTION — ЭТО И ЕСТЬ НОВЫЙ NoFall + ОБХОД AIRTIME ─────
        Прошлые версии проваливались обе по одной причине: они пытались
        РАЗОВО подставить землю (ground-ping) и упирались в противоречие —
        чтобы сервер увидел нас на земле, надо отправить землю, а следующим
        пакетом вернуться наверх. Мгновенный подъём ловится ac_movement,
        поэтому подстановку зажали порогом 6-25 студов, и она почти никогда
        не срабатывала. Отсюда «NoFall не работает» и «airtime не фиксит».

        ПРАВИЛЬНОЕ РЕШЕНИЕ — не разовая подстановка, а НЕПРЕРЫВНАЯ ПРОЕКЦИЯ.
        Пока мы в воздухе, в каждом пакете по X/Z шлём правду, а по Y — уровень
        земли РОВНО ПОД НАМИ (raycast вниз). Для сервера это обычный игрок,
        который всё это время шёл по земле:
          • перепад высот = 0            -> урона от падения нет вообще;
          • в воздухе мы не были никогда  -> ac_airtime_kill не запускается;
          • возврата наверх не требуется  -> нет подписи телепорта.

        Главный бонус: при касании земли отчётная позиция УЖЕ совпадает с
        реальной (мы падаем именно на ту землю, которую проецировали), поэтому
        рассинхронизации на выходе нет — в отличие от ping'а, который всегда
        оставлял разрыв.

        Работает на ЛЮБОЙ высоте, чем и отличается от старого порога 8 студов. ]]
    GroundProject      = true,
    --[[ Земля под нами меняется скачком, когда мы пролетаем край крыши. Такой
         скачок Y — это телепорт в глазах ac_movement, поэтому отчётный Y
         догоняет новый уровень не мгновенно, а шагами по столько студов за
         пакет. При 24-30 Гц это 72-90 студов/с — быстро, но физически
         правдоподобно (обычное падение). ]]
    GroundProjectStep  = 3,
    --[[ Если земли под нами нет дальше этой дистанции (пропасть, полёт над
         картой) — проецировать некуда. Тогда держим последний известный
         уровень земли: он всё равно лучше, чем реальный Y в воздухе. ]]
    GroundProjectDrop  = 512,

    --[[ ══ DESYNC — ПЕРЕПИСАН ПОЛНОСТЬЮ ════════════════════════════════════
        СУТЬ ЭКСПЛОЙТА: игроки видят меня нормально, но урон по мне не
        регистрируется. Достигается сбоем репликации МОЕГО тела: сервер и чужие
        клиенты продолжают рисовать меня (поза, наклон, взгляд, анимации идут),
        но точка, по которой считается попадание, устаревает.

        Старые режимы (stall / hybrid / fakelag / jitter) удалены: все четыре
        были вариациями «сдвинуть координату на пару студов» или «задержать
        пакет», то есть били по одному и тому же каналу и давали разрыв в
        считанные студы. Ниже — четыре РАЗНЫХ по природе метода, от прикладного
        до пакетного. Их можно включать по отдельности и комбинировать. ]]
    Desync            = false,
    DesyncKey         = Enum.KeyCode.K,

    --[[ МЕТОД 1 — заморозка позиции (прикладной уровень, самый надёжный).
        FPC_extend:658-668 пишет позицию в пакет ТОЛЬКО если она изменилась:
            v96 = last_replication_state.position ~= compress_position(pos)
            u91:write_bool(v96 or v97); if v96 or v97 then write_position(...)
        Значит достаточно отдавать ОДНУ И ТУ ЖЕ координату — игра сама решит,
        что «ничего не поменялось», и не отправит позицию вообще. Мы не врём
        координатами и не ломаем пакет: мы просто перестаём сообщать новые.
        Сервер держит последнюю известную точку, мы уходим — это ровно тот
        «застываю у всех на старой позиции», о котором речь. ]]
    DesyncFreezePos   = true,

    --[[ МЕТОД 2 — порча ID_TIMESTAMP (пакетный уровень, RakNet).
        Широко известный replication desync: у пакета 0x1B затирается метка
        времени, и движок сервера не может корректно упорядочить наши
        физические апдейты. Бьёт по ДРУГОМУ каналу, чем метод 1: там прикладной
        пакет игры, здесь физика самого Roblox (по ней чужой клиент строит
        хитбоксы наших частей). Требует включённого RakNet в настройках
        Potassium. Риск бана выше — поэтому по умолчанию выключен. ]]
    DesyncRakTimestamp = false,

    --[[ МЕТОД 3 — блокировка исходящих физических пакетов (RakNet).
        packet:Block() на время окна десинка: движок вообще не отправляет
        физику нашей сборки. Самый «жёсткий» разрыв хитбокса. ]]
    DesyncRakBlock     = false,

    --[[ МЕТОД 4 — заморозка анимационного канала (эксплойт с анимациями).
        ВАЖНО: в этой игре НЕТ объекта Humanoid — риг кастомный
        (humanoid_root_part это просто BasePart), поэтому классический
        ChangeState(Physics) здесь неприменим и не используется.

        Игровой эквивалент есть в том же пакете: поза, наклон и взгляд тоже
        отправляются только при изменении (FPC_extend:635-655, 671-679) —
        сравнение идёт с last_replication_state. Замораживая эти три канала, мы
        останавливаем обновление РИГА: для остальных мы застываем в последней
        позе целиком, а не только в точке.

        Метод 1 замораживает ГДЕ мы, метод 4 — КАК мы выглядим. Метод 1 без
        метода 4 выглядит живее (мы стоим не там, но двигаемся и целимся), что
        менее заметно; метод 4 даёт полную статую. ]]
    DesyncFreezeAnim   = false,

    --[[ ── АГРЕССИВНОСТЬ ───────────────────────────────────────────────────
        false (умеренно) — рабочий цикл: держим десинк DesyncHoldMs, затем
              САМИ возвращаем репликацию в норму на DesyncResyncMs. Сервер
              регулярно получает честную точку, поэтому ac_movement не видит
              накопленного расхождения, а airtime не копится.
        true (агрессивно) — держим десинк непрерывно. Урон почти не регается,
              но расхождение растёт, и рано или поздно прилетит откат позиции
              или airtime_timeout. ]]
    DesyncAggressive  = false,
    DesyncHoldMs      = 170,
    DesyncResyncMs    = 120,
    --[[ Предохранитель умеренного режима: как только призрак отстал больше чем
         на столько студов, окно закрывается досрочно, не дожидаясь таймера.
         Именно накопленный отрыв, а не сам десинк, ловит ac_movement. ]]
    DesyncMaxDrift    = 18,
    --[[ Визуализация: линия до призрака, его силуэт и отрыв в студах. ]]
    DesyncVisualize   = true,

    ApplyInterval    = 0.5,
}
DLM.config = CFG

--======================================================================
--  SERVICES
--======================================================================
local Players     = cloneref and cloneref(game:GetService("Players"))    or game:GetService("Players")
local RunService  = cloneref and cloneref(game:GetService("RunService")) or game:GetService("RunService")
local UIS         = cloneref and cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local RS          = cloneref and cloneref(game:GetService("ReplicatedStorage")) or game:GetService("ReplicatedStorage")
local Workspace   = cloneref and cloneref(workspace) or workspace
local LocalPlayer = Players.LocalPlayer

local V3    = Vector3.new
local CF    = CFrame.new
local ZERO3 = V3()
local clock = os.clock
local min, max, clamp = math.min, math.max, math.clamp
local running = true
local conns = {}

--======================================================================
--  СТРАХОВКА ОТ ЛОВУШКИ getenv  (главная причина «подыхаю без причины»)
--======================================================================
--[[
    НАЙДЕНО В ДАМПЕ — это объясняет «иногда подыхаю», «иногда movement
    отваливается», «меня тпхает назад».

    В игре ТРИ функции-ловушки, все с одинаковой начинкой:
      module/util/lua/util.lua:10        (getenv)
      module/namespace/NetworkEncode:12  (getenv)
      module/caster/caster.lua:404       (getenv)
    Каждая обходит pcall(getfenv, i) по уровням стека (0..9 / 1..10) и, если в
    чьём-то окружении находит rconsoleprint, делает:
        loading_status:FireServer("_genv")   -- стучит серверу
        rconsoleprint("kill yourself")
        while true do end                    -- вешает поток НАСМЕРТЬ

    Почему это било именно по нам:
      • NetworkEncode.getenv вызывается ИЗ write_time, write_pose,
        write_exact_position, compress_* — то есть ровно там, где стоят наши
        хуки. Наш ху�� лежит на стеке -> getfenv находит окружение экзекутора.
      • util.getenv вызывается из map_clamped и copy_table (горячее место:
        каждое сжатие ��озиции/взгляда), но срабатывает ВЕРОЯТНОСТНО:
            if math.random(1, 100) ~= 100 then return end
        1 случай из 100. Отсюда и «иногда». Повисший поток = пакеты не идут =
        сервер тянет нас назад и в итоге убивает.

    Обход: находим все три по уникальной константе "kill yourself" и
    подменяем пустышкой. deadline_bypass делает это же, но movement теперь
    самодостаточен — если обход не загружен, скрипт всё равно безопасен.
--]]
--[[
    ИДЕМПОТЕНТНОСТЬ. Обход и каждый из скриптов умеют глушить эти ловушки, чтобы
    быть самодостаточными. Но хукать одни и те же три замыкания четыре раза —
    лишний риск на функциях горячего пути (write_time / compress_position /
    map_clamped). Поэтому общий маркер в getgenv(): кто первый пришёл, тот и
    глушит, остальные читают результат.
--]]
local GENV_MARK = "__dl_genv_traps_killed"
local genvKilled = 0
do
    local g = getgenv()
    local already = g and rawget(g, GENV_MARK)
    if type(already) == "number" then
        genvKilled = already                 -- уже заглушено другим скриптом
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
    --[[ Второй слой: даже если какая-то ловушка уцелела, ей не за что
         зацепиться — убираем rconsoleprint из окружений, которые она смотрит.
         Логи после этого идут через print. ]]
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
--  СОСТОЯНИЕ, ПРИВЯЗАННОЕ К ТЕЛУ  (сбрасывается при респавне)
--======================================================================
local ctrl                     -- живой FirstPersonController
local reportedPos = nil
local lastGroundY = nil
local airtime = 0
local touchdownUntil = 0
local engineAnchored = false
local hrpCache = nil          -- кэш humanoid_root_part (сбрасывается на респавне)

-- NO FALL: реальная высота прошлого кадра (для расчёта скорости спуска)
local lastRealY = nil

--[[ Объявлены ЗДЕСЬ, а не рядом со своей логикой ниже, потому что сброс на
     респавне (reset_character_state) находится выше по файлу и обращается к
     ним. Без forward-декларации это были бы глобальные переменные. ]]
local projY      = nil   -- отчётный Y (ground projection)
--[[ Прикрывает ли проекция падение ПРЯМО СЕЙЧАС. Нужен, чтобы локальный зажим
     скорости включался только когда проекции нет (пропасть / фича выключена):
     иначе он тормозил каждое падение до FallMaxSpeed, а это видно всем вокруг
     и вообще не требуется, когда сервер уже видит нас на земле. ]]
local projCovers = false
local dsActive   = false -- окно десинка открыто
local dsPhaseAt  = 0     -- clock() последней смены фазы
local dsGhostPos = nil   -- точка, которую повторяем (= что видит сервер)
local dsDrift    = 0     -- отрыв призрака в студах

-- согласование скорости с позицией (см. блок про compress_velocity ниже)
local lastSentPos = nil
local lastSentTime = nil
local derivedVel = nil
local burstOn = false
local burstSwitchAt = 0

--======================================================================
--  ДОСТУП К ИГРОВЫМ ОБЪЕКТАМ
--======================================================================
local SHARED
pcall(function()
    SHARED = require(RS.module.shared_state).SHARED_STATE
end)

local function set_shared(key, value)
    if not SHARED then
        return false
    end
    local obj = rawget(SHARED, key)
    if type(obj) ~= "table" then
        return false
    end
    return (pcall(function()
        if type(obj.set_client) == "function" then
            obj:set_client(value)
        else
            obj.value = value
        end
    end))
end

local function get_shared(key, fallback)
    if not SHARED then
        return fallback
    end
    local obj = rawget(SHARED, key)
    if type(obj) == "table" and obj.value ~= nil then
        return obj.value
    end
    return fallback
end

--[[
    ВЫБОР ЖИВОГО КОНТРОЛЛЕРА — КОРНЕВАЯ ПРИЧИНА
    «перестаёт работать после смертей» И смертей в полёте.

    Прошлый вариант искал контроллер и сверял его character с
    LocalPlayer.Character. Но в этой игре LocalPlayer.Character НЕ присваивается
    вообще (в дампе ни одного присваивания): модель персонажа парентится в
    Workspace.characters, а игроку прописывается только ReplicationFocus.
    Значит сравнение никогда не совпадало, и мы сваливались на «первый
    подходящий» — то есть на СТАРЫЙ, мёртвый контроллер. Все спуфы (в т.ч.
    is_climbing) ставились на труп и до пакета не доезжали -> airtime-смерть.

    Правильный источник истины — сам ClientFramework: у него есть поле
    lifetime_state, которое создаётся при спавне (ClientFramework:828) и
    ОБНУЛЯЕТСЯ при смерти (234, 1133, 1142). Поэ��ому берём framework, а из него
    каждый раз свежие lifetime_state и fp_controller.
--]]
local framework = nil

--[[
    КРИТИЧНО: ПОИСК ЗАДРОССЕЛИРОВАН ЖЁСТКО. ЭТО БЫЛА ПРИЧИНА КРАША ИГРЫ.
    refresh_ctrl зовётся КАЖДЫЙ КАДР. Если framework ещё не найден (лобби,
    экран смерти, момент до спавна), то без ограничителя прямо в покадровом
    коде запускался filtergc — полный проход по ВСЕЙ куче GC 60 раз в секунду.
    Клиент от этого вставал насмерть. Покадрово теперь идёт ТОЛЬКО дешёвый
    rawget по уже найденном�� объекту.
--]]
local FRAMEWORK_SCAN_INTERVAL = 1.0
local lastFrameworkScan = -math.huge

local function find_framework()
    local now = clock()
    if now - lastFrameworkScan < FRAMEWORK_SCAN_INTERVAL then
        return nil
    end
    lastFrameworkScan = now

    --[[
        Ищем по ключам, которые есть у framework ВСЕГДА, в том числе пока мы
        мертвы: lifetime_maid и ui_bindings (ClientFramework:1086, 1093, 336).
        Именно поэтому н��льз�� искать по lifetime_state — при смерти он nil.
    --]]
    local okf, foundf = pcall(filtergc, "table", {
        Keys = { "lifetime_maid", "ui_bindings" },
    }, false)
    if not okf or type(foundf) ~= "table" then
        return nil
    end
    local fallback = nil
    for _, cand in ipairs(foundf) do
        -- у framework есть ещё и output/death_callback — отсекаем однофамильцев
        if rawget(cand, "output") ~= nil or rawget(cand, "framework_store") ~= nil then
            local lt = rawget(cand, "lifetime_state")
            if type(lt) == "table" and rawget(lt, "fp_controller") ~= nil then
                return cand                    -- живой: берём сразу
            end
            fallback = fallback or cand        -- мёртвый, но это тот же framework
        end
    end
    return fallback
end

local function refresh_ctrl()
    -- framework — синглтон, он переживает смерть, поэтому ищем его один раз
    if framework == nil then
        framework = find_framework()
    end

    local lt = framework and rawget(framework, "lifetime_state")
    if type(lt) ~= "table" then
        --[[ Мертвы или ещё не заспавнились. Сбрасываем ВСЁ, что привязано к
             телу, включая взведённые ping'и: иначе сразу после респавна
             улетал ненужный «сброс на землю», а счётчики продолжали с чужих
             значений. ]]
        lifetime = nil
        ctrl = nil
        hrpCache = nil
        engineAnchored = false
        lastRealY = nil
        --[[ Проекцию и призрака ОБЯЗАТЕЛЬНО сбрасываем на респавне: иначе
             отчётный Y пополз бы к земле со старой точки смерти, а десинк
             держал бы призрака в прошлой жизни. ]]
        projY = nil
        --[[ Иначе после смерти в воздухе флаг остался бы true и зажим падения
             не включился бы в новой жизни до первого пакета. ]]
        projCovers = false
        dsActive = false
        dsGhostPos = nil
        dsDrift = 0
        lastSentPos = nil
        lastSentTime = nil
        derivedVel = nil
        return
    end

    lifetime = lt
    local best = rawget(lt, "fp_controller")
    if type(best) ~= "table" then
        return
    end
    if best ~= ctrl then
        ctrl = best
        reportedPos = nil
        lastGroundY = nil
        airtime = 0
        touchdownUntil = 0
        engineAnchored = false
        hrpCache = nil          -- новое тело — сбрасываем кэш части

    end
end

--[[
    LIFETIME_STATE — таблица жизни персонажа из ClientFramework:
        { broken, is_player_anchored, char_data, character, fp_controller,
          item_manager, simulation, ... }
    Нужна ради поля is_player_anchored: игра каждый тик выполняет
        HRP.Anchored = fp_controller:is_freecam() or lifetime.is_player_anchored
    Выставив этот флаг, мы заставляем ИГРУ саму держать персонажа anchored —
    это её штатный путь (так же она двигает тело во время вольта).
--]]
-- lifetime берётся из framework.lifetime_state в refresh_ctrl (см. выше):
-- это единственный источник, который обнуляется при смерти, поэтому труп
-- никогда не подхватывается.

--[[
    ВКЛЮЧЕНИЕ ШТАТНОГО АНКОРА.
    Флаг НУЖНО переставлять КАЖДЫЙ КАДР: игра снимает его при любом вводе —
        ClientFramework:391  if HRP.Anchored and is_player_anchored then
                                 is_player_anchored = false
    Раньше он ставился один раз, поэтому первое же нажатие клавиши убивало
    анкор и noclip проходил «через раз».
--]]
-- кэш HRP: FindFirstChild каждый кадр — лишняя работа
-- hrpCache объявлен выше

local function cached_hrp()
    if hrpCache and hrpCache.Parent then
        return hrpCache
    end
    local hrp
    if ctrl then
        local ch = rawget(ctrl, "character")
        if ch and typeof(ch) == "Instance" then
            hrp = ch:FindFirstChild("humanoid_root_part")
        end
    end
    if not hrp then
        local mc = LocalPlayer.Character
        hrp = mc and mc:FindFirstChild("humanoid_root_part")
    end
    hrpCache = hrp
    return hrp
end

local function set_engine_anchor(enabled)
    local okAny = false
    if lifetime then
        okAny = pcall(function()
            lifetime.is_player_anchored = enabled and true or false
        end)
    end
    -- дублируем напрямую: если lifetime не найден, хотя бы держим сам Anchored
    local hrp = cached_hrp()
    if hrp then
        pcall(function()
            if hrp.Anchored ~= enabled then
                hrp.Anchored = enabled
            end
        end)
        okAny = true
    end
    return okAny
end

--[[
    СПУФ is_climbing — ПРЯМО В ПОЛЕ (тот вариант, который реально работал).

    Ставим fp_controller.is_climbing = true. Это:
      • уходит на сервер в пакете (FPC_extend:575 write_bool(u82.is_climbing)) —
        «я на лестнице», т.е. легальное длительное пребывание в воздухе;
      • на клиенте (FPC:1496, признак v263) выключает обработку приземления.

    Единственная плата — игра пытается убрать оружие:
        v189 = is_freecam() or fp_controller.is_climbing
        if v189 and (weapon.is_equipped and not item_manager.removing_weapon) then
            unequip_weapon(true); input_group:disconnect_all_binds()
        end
    Но по всему дампу removing_weapon читается ТОЛЬКО в этом условии
    (ClientFramework:1258-1263 и одна инициализация в ItemManager:66).
    Значит достаточно держать item_manager.removing_weapon = true — блок
    разоружения не выполнится, и больше это поле ни на что не влияет.
    Никаких хуков на горячие функции (из-за них падал FPS) не нужно.
--]]
--[[
    ПОЧЕМУ ПОЛЕ НАДО ДЕРЖАТЬ ПОСТОЯННО, А НЕ ТОЛЬКО В ПАКЕТЕ.

    Игра переписывает его КАЖДЫЙ КАДР (FirstPersonController:1475):
        u252.is_climbing = (simulation.current_state_name == "climbing")
    поэтому переставлять надо покадрово. Одного присвоения не хватает.

    Прошлая версия поднимала поле ТОЛЬКО на время сборки пакета (write_time ->
    compress_position). Логически этого должно было хватать, но ты говорил:
    «Fly работал ахуенно, когда ты сделал is_climbing подход, именно локальный».
    Разбор дампа показывает, почему постоянное поле сильнее:

      FPC:1468   if not grounded and last_grounded then
                     jump_last_position = HRP.Position
                 — «откуда я упал» пишется в момент ОТРЫВА от земли
      FPC:1487   v263 -> звуки посадки/схода с лестницы
      FPC:1496   if grounded and not last_grounded and jump_last_position
                    and NOT v263  then  <блок приземления>
                 v263 = Climbing.climb_timer:expired() or is_climbing
      FPC:1500   v264 = jump_last_position.Y - HRP.Position.Y   -- дистанция падения

    То есть постоянный is_climbing гасит весь клиентский путь приземления и
    падения целиком. Пока поле поднималось лишь внутри пакета, всё остальное
    (включая запись точки отрыва) шло как у обычного падающего игрока — и та же
    модель, скорее всего, считается на сервере.

    Плата — попытка снять оружие. Но removing_weapon по всему дампу читается
    РОВНО в одном условии (ClientFramework:1258; пишется на 1260/1263,
    инициализируется в ItemManager:66). Держим его true — блок разоружения не
    выполнится никогда. Побочный эффект один: звуки шагов идут по ветке
    climbing_sounds (FPC:538), то есть косметика.

    Окно пакета оставлено ВТОРЫМ слоем: если обновление контроллера случится
    после нашего кадра, окно всё равно подставит правильное значение.
--]]
local spoofActive = false
local savedClimbing = nil

local function set_climbing_spoof(enabled)
    if enabled and not CFG.SpoofClimbing then
        enabled = false
    end
    spoofActive = enabled and true or false

    -- разоружение блокируем постоянно, пока спуф активен: читается это поле
    -- только в блоке unequip, так что побочных эффектов нет
    if lifetime then
        pcall(function()
            local im = rawget(lifetime, "item_manager")
            if im then
                im.removing_weapon = spoofActive
            end
        end)
    end
    if not spoofActive and ctrl then
        pcall(function()
            ctrl.is_climbing = false
        end)
    end
end

--[[
    ПОКАДРОВОЕ УДЕРЖАНИЕ ПОЛЯ — тот самый «локальный» вариант, который у тебя
    работал. Вызывается из RenderStepped, пока спуф активен.
--]]
local function hold_climbing_field()
    if not (spoofActive and ctrl) then
        return
    end
    pcall(function()
        if rawget(ctrl, "is_climbing") ~= true then
            ctrl.is_climbing = true
        end
    end)
    -- страховка: игра могла успеть разоружить нас до того, как мы взяли флаг
    if lifetime then
        pcall(function()
            local im = rawget(lifetime, "item_manager")
            if im and rawget(im, "removing_weapon") ~= true then
                im.removing_weapon = true
            end
        end)
    end
end

-- вызывается из write_time: открыть «окно пакета»
local function packet_window_open()
    if not (spoofActive and ctrl) then
        savedClimbing = nil
        return
    end
    savedClimbing = rawget(ctrl, "is_climbing")
    pcall(function()
        ctrl.is_climbing = true
    end)
    --[[
        ПОЗА = «БЕГ».
        Сервер считает допустимую скорость из РЕПЛИЦИРОВАННОЙ позы
        (walkspeed[pose]: idle 14, running 25, crouch 8, prone 6). Если мы летим
        22 ст/с, а поза idle — это выше лимита, отсюда и «тпхает назад, если я
        не бегаю». Заставляем игру переслать позу (сбрасываем дельту), а сам
        write_pose подменяем на 4 = running: лимит становится 25 и наши 22
        проходят как легальные.
    --]]
    if CFG.SpoofRunningPose then
        pcall(function()
            local st = rawget(ctrl, "last_replication_state")
            if type(st) == "table" then
                st.pose = -1        -- дельта сработает -> write_pose вызовется
            end
        end)
    end
end

--[[
    ИЗМЕРЕНИЕ ВМЕСТО ДОГАДОК.
    Серверный код я видеть не могу, поэтому единственный способ понять, почему
    Fly всё ещё убивает — замерить, доезжает ли бит is_climbing до пакета.
    Порядок сборки (FPC_extend:568-607):
        write_time -> write_bool(is_climbing) -> compress_position
    Наше окно закрывается на compress_position, то есть здесь поле ещё в том
    виде, в котором его ПРОЧИТАЛ write_bool. Тут и снимаем показание.

    Как читать DLM.debug():
      climbSent ≈ packets  -> бит уходит на сервер исправно. Значит is_climbing
                              НЕ является исключением для ac_airtime_kill, и
                              единственный гарантированный путь — не висеть
                              дольше лимита (ForceTouchdown = true).
      climbSent << packets -> спуф не доезжает, чинить надо его.
--]]
local packetsSeen = 0
local climbSent = 0

-- вызывается из compress_position: закрыть «окно пакета»
local function packet_window_close()
    packetsSeen = packetsSeen + 1
    if ctrl and rawget(ctrl, "is_climbing") == true then
        climbSent = climbSent + 1
    end
    if savedClimbing ~= nil and ctrl then
        pcall(function()
            ctrl.is_climbing = savedClimbing
        end)
    end
    savedClimbing = nil
end

--[[
    FREE GUN.
    Игра сохраняет индекс убранного ствола в fp_controller.saved_unequipped_weapon
    и возвращает его сама только когда v189 (freecam/climbing) станет false.
    Мы возвращаем сразу и заново подключаем бинды оружия.
--]]
local function apply_free_gun()
    if not (CFG.FreeGun and ctrl and lifetime) then
        return
    end
    local saved = rawget(ctrl, "saved_unequipped_weapon")
    if saved == nil then
        return
    end
    pcall(function()
        local im = rawget(lifetime, "item_manager")
        if im and type(im.equip_weapon) == "function" then
            im.removing_weapon = false
            im:equip_weapon(saved)
            ctrl.saved_unequipped_weapon = nil
        end
    end)
end

local function get_character()
    if ctrl then
        local ch = rawget(ctrl, "character")
        if ch ~= nil then
            return ch
        end
    end
    return LocalPlayer.Character
end

local function get_hrp()
    local ch = get_character()
    if ch and typeof(ch) == "Instance" then
        return ch:FindFirstChild("humanoid_root_part")
    end
    if type(ch) == "table" then
        return rawget(ch, "humanoid_root_part")
    end
    return nil
end

local function get_walking_state()
    if not ctrl then
        return nil
    end
    local sim = rawget(ctrl, "simulation")
    if type(sim) ~= "table" then
        return nil
    end
    local states = rawget(sim, "states")
    if type(states) ~= "table" then
        return nil
    end
    return rawget(states, "Walking")
end

local function is_grounded()
    local walking = get_walking_state()
    if walking then
        local g = rawget(walking, "grounded")
        if g ~= nil then
            return g == true
        end
    end
    local g2 = ctrl and rawget(ctrl, "grounded")
    if g2 ~= nil then
        return g2 == true
    end
    return true
end

-- гасим штатные форсы движения, чтобы они не боролись с нашей скоростью
local function zero_forces()
    local walking = get_walking_state()
    if not walking then
        return
    end
    local forces = rawget(walking, "forces")
    if type(forces) ~= "table" then
        return
    end
    pcall(function()
        if forces.vectorForce then
            forces.vectorForce.Force = ZERO3
        end
        if forces.bodyPosition then
            forces.bodyPosition.MaxForce = ZERO3
        end
    end)
end

local function restore_forces()
    local walking = get_walking_state()
    if not walking then
        return
    end
    local forces = rawget(walking, "forces")
    if type(forces) ~= "table" then
        return
    end
    pcall(function()
        if forces.bodyPosition then
            forces.bodyPosition.MaxForce = V3(0, 4000, 0)
        end
    end)
end

--======================================================================
--  SPEED
--======================================================================
--[[
    LegitMax убирает только те штрафы, которые считаются ЛОКАЛЬНО и серверу
    неизвестны:
      • stamina  — ниже 40 режет скорость (map_clamped(stamina,0,40,0.6,1))
      • landing_walkspeed_timer — до 1.5с замедления после жёсткого приземления
    Вес (collective_weight), позу, aiming и lean НЕ трогаем: их сервер знает,
    и расхождение = ac_movement.
--]]
local function apply_speed()
    if not ctrl then
        return
    end
    local charData = rawget(ctrl, "char_data")
    if type(charData) ~= "table" then
        return
    end
    local overrides = rawget(charData, "overrides")
    if type(overrides) ~= "table" then
        return
    end

    --[[
        BURST: разгон короткими импульсами. У серверной проверки есть окно
        терпимости — рывок около секунды проходит, поэтому чередуем импульс
        и отдых, чтобы средняя скорость за окно осталась легальной.
    --]]
    local mul = 1
    if CFG.Speed then
        if CFG.ConstantMultiplier then
            mul = CFG.SpeedMultiplier
        elseif CFG.BurstSpeed then
            local now = clock()
            if now >= burstSwitchAt then
                burstOn = not burstOn
                burstSwitchAt = now + (burstOn and CFG.BurstOnTime or CFG.BurstOffTime)
            end
            mul = burstOn and CFG.SpeedMultiplier or 1
        end
    end
    overrides.speed = mul

    if CFG.Speed and CFG.LegitMax then
        -- полная стамина = нет штрафа скорости (и вольты не упираются)
        pcall(function()
            local maxStam = get_shared("plr_max_stamina", 120)
            if rawget(ctrl, "stamina") ~= nil then
                ctrl.stamina = maxStam
            end
        end)
        -- снять замедление после приземления
        local lt = rawget(ctrl, "landing_walkspeed_timer")
        if type(lt) == "table" then
            pcall(function() lt.next_time = 0 end)
        end
    end
end

--======================================================================
--  AIRTIME GUARD  (защита от ac_airtime_kill -> "airtime_timeout")
--======================================================================
local function update_airtime(dt)
    if is_grounded() then
        airtime = 0
        local hrp = get_hrp()
        if hrp and typeof(hrp) == "Instance" then
            lastGroundY = hrp.Position.Y
        end
    else
        airtime = airtime + dt
    end

end

-- true = нужно принудительно опускаться, иначе прилетит airtime_timeout
local function needs_touchdown()
    if not CFG.ForceTouchdown then
        return false
    end
    if CFG.FlyAirtimeLimit <= 0 then
        return false
    end
    --[[ ТОТ ЖЕ ДЕФЕКТ, ЧТО БЫЛ У ЗАЖИМА ПАДЕНИЯ: принудительный спуск — это
        обход airtime_timeout, но он выполнялся всегда, поэтому полёт каждые
        FlyAirtimeLimit секунд прерывался рывком к земле. При работающей
        проекции сервер вообще не видит нас в воздухе (в пакете Y = уровень
        земли), значит airtime не тикает и опускаться не нужно.
        Оставляем спуск только там, где проекции нет: над пропастью или при
        выключенном Ground Projection. ]]
    if projCovers then
        return false
    end
    local now = clock()
    if now < touchdownUntil then
        return true
    end
    if airtime >= CFG.FlyAirtimeLimit then
        touchdownUntil = now + CFG.FlyTouchdownTime
        return true
    end
    return false
end

--======================================================================
--  ВВОД НАПРАВЛЕНИЯ (общий для Fly и NoClip)
--======================================================================
local function input_direction(includeVertical)
    local cam = Workspace.CurrentCamera
    if not cam then
        return ZERO3
    end
    local dir = ZERO3
    local cf = cam.CFrame
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
    if includeVertical then
        if UIS:IsKeyDown(CFG.FlyUpKey) then dir = dir + V3(0, 1, 0) end
        if UIS:IsKeyDown(CFG.FlyDownKey) then dir = dir - V3(0, 1, 0) end
    end
    return dir
end

--======================================================================
--  ДВИЖЕНИЕ ЧЕРЕЗ ШТАТНЫЙ АНКОР ДВИЖКА  (Fly + NoClip)
--======================================================================
--[[
    РЫЧАГ. Игра каждый тик выполняет (ClientFramework:1271):
        HRP.Anchored = fp_controller:is_freecam() or lifetime.is_player_anchored
    Поэтому свой Anchored держать бесполезно — движок его перезатирал, из-за
    этого noclip и не работал. Вместо борьбы включаем ЕГО флаг
    (lifetime_state.is_player_anchored), и дальше:
      • анкорит сама игра, каждый тик, легально;
      • у anchored части физика не разрешает коллизии -> проходим сквозь всё;
      • двигаем HRP.CFrame напрямую — тем же способом, которым движок ведёт
        персонажа во время вольта (Anchored + запись CFrame);
      • torso_hitbox не трога��м вообще (пакет 3 спокоен).
    Скорость держим легальной, а airtime — под присмотром, иначе прилетит
    "airtime_timeout".
--]]
local flyVel = ZERO3          -- сглаженная скорость полёта

local function anchored_move(dt, speed, includeVertical, forceDownward)
    local hrp = get_hrp()
    if not hrp or typeof(hrp) ~= "Instance" then
        return
    end

    -- анкор и спуф состояния переставляем КАЖДЫЙ кадр (игра их снимает)
    set_engine_anchor(true)
    set_climbing_spoof(true)
    engineAnchored = true
    zero_forces()

    local dir = input_direction(includeVertical)
    if forceDownward then
        dir = V3(dir.X, -1, dir.Z)
    end

    local target = ZERO3
    if dir.Magnitude > 0.001 then
        target = dir.Unit * speed
    end

    -- сглаживание: без него движение было рывками и «не работало ��ормал��но»
    local a = clamp(1 - CFG.FlySmooth, 0.05, 1)
    flyVel = flyVel + (target - flyVel) * a

    if CFG.KeepVelocityZero then
        --[[ generic-детекты ловят связку «в в��здухе + velocity.Y > 0».
             Под анкором фи��ической скорости нет, но на всякий случай держим
             её нулевой, чтобы признак «летит вверх» вообще не появлялся. ]]
        pcall(function()
            hrp.AssemblyLinearVelocity = ZERO3
        end)
    end

    if flyVel.Magnitude < 0.01 then
        return
    end
    pcall(function()
        hrp.CFrame = hrp.CFrame + flyVel * dt
    end)
end

--[[
    БЕЗОПАСНЫЙ ВЫХОД ИЗ НОКЛИПА.
    Если снять анкор, находясь ВНУТРИ геометрии, физика выталкивает тело куда
    попало, а сервер видит нас в стене — отсюда и «подыхаю без причины».
    Поэтому перед снятием анкора проверяем, свободно ли место, и если нет —
    поднимаем немного вверх, пока не найдём открытую точку.
--]]

--[[
    Проверяем ИМЕННО пересечение с геометрией, а не «есть ли что-то сверху».
    Предыдущая версия пускала луч вверх — а ��ад головой почти всегда потолок,
    поэтому она поднимала тело вверх без всякой причины (и в связке с багом
    вызова каждый кадр уносила в небо).
    Правильный инструмент — GetPartsInPart по хитбоксу: он даёт список того,
    с чем мы РЕАЛЬНО пересекаемся. Сам хитбокс только читаем (пакет 3 спокоен).
--]]
local function ensure_safe_exit()
    if not CFG.NoClipSafeExit then
        return
    end
    local hrp = cached_hrp()
    if not hrp then
        return
    end
    pcall(function()
        local ch = LocalPlayer.Character
        local torso = ch and ch:FindFirstChild("torso")
        local hitbox = torso and torso:FindFirstChild("torso_hitbox")
        local probe = hitbox or hrp
        if not probe then
            return
        end

        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = {}
        if ch then ignore[#ignore + 1] = ch end
        local ig = Workspace:FindFirstChild("ignore")
        if ig then ignore[#ignore + 1] = ig end
        local chars = Workspace:FindFirstChild("characters")
        if chars then ignore[#ignore + 1] = chars end
        params.FilterDescendantsInstances = ignore
        params.MaxParts = 1

        -- пока реально застряли — выталкиваемся вверх маленькими шагами
        for _ = 1, 8 do
            local hits = Workspace:GetPartsInPart(probe, params)
            if not hits or #hits == 0 then
                break
            end
            hrp.CFrame = hrp.CFrame + V3(0, 1, 0)
        end
    end)
end

local function anchored_stop()
    if engineAnchored then
        ensure_safe_exit()
        set_engine_anchor(false)
        set_climbing_spoof(false)
        engineAnchored = false
        flyVel = ZERO3
    end
    restore_forces()
end

--[[
    FLY — БЕЗ ПРОХОДА СКВОЗЬ СТЕНЫ.
    Раньше полёт шёл через тот же анкор, что и ноклип, поэтому и вёл себя как
    ноклип: у anchored части физика не разрешает коллизии. Теперь Fly работает
    ЧЕРЕЗ СКОРОСТЬ — тело остаётся физическим и упирается в геометрию, а
    гравитацию компенсируем сами. Скорость персонажа при этом не трогаем.
--]]
--[[
    FLY — вернул рабочую схему: штатный анкор движка + ведение CFrame,
    плюс is_climbing прямо в поле. Именно так полёт и работал нормально.
    Побочный эффект — под анкором нет коллизий, т.е. Fly проходит сквозь
    геометрию. Это плата за то, что он не флагается; кому нужны коллизии —
    FlyCollide = true (тогда полёт идёт через скорость, но airtime-риск выше).
--]]
--[[
    AUTO TOUCHDOWN — состояние.
    Три фазы:
      idle       — обычный полёт
      descending — быстро идём вниз, пока не коснёмся земли
      returning  — поднимаемся назад на запомненную высоту
    Позицию НЕ подделываем ни в одной фазе: сервер видит настоящее падение и
    настоящий подъём, поэтому счётчик воздуха обнуляется законно.
--]]
local tdPhase = "idle"
local tdReturnY = nil
local tdFlyTime = 0

local function autotouchdown_reset()
    tdPhase = "idle"
    tdReturnY = nil
    tdFlyTime = 0
end

-- true = эту итерацию fly_step обрабатывает касание, обычный ввод игнорируем
local function autotouchdown_step(dt)
    if not (CFG.AutoTouchdown and CFG.Fly) then
        autotouchdown_reset()
        return false
    end
    local hrp = cached_hrp()
    if not hrp then
        return false
    end

    if tdPhase == "idle" then
        -- копим время полёта только пока реально в воздухе
        if is_grounded() then
            tdFlyTime = 0
            return false
        end
        tdFlyTime = tdFlyTime + dt
        if tdFlyTime < CFG.AutoTouchdownAfter then
            return false
        end
        -- пора коснуться: запоминаем высоту и уходим вниз
        tdReturnY = hrp.Position.Y
        tdPhase = "descending"
        log(("auto-touchdown: descending to reset server airtime (was %.0f studs up)")
            :format(tdReturnY))
        return true
    end

    if tdPhase == "descending" then
        -- касание засчитано движком -> уходим в возврат
        if is_grounded() then
            tdFlyTime = 0
            if CFG.AutoTouchdownReturn and tdReturnY ~= nil then
                tdPhase = "returning"
                log("auto-touchdown: ground contact, returning to altitude")
            else
                autotouchdown_reset()
                log("auto-touchdown: ground contact, airtime reset")
            end
            return true
        end
        --[[
            Спуск ведём БЕЗ анкора: нужен настоящий контакт с землёй, чтобы
            движок выставил grounded, а сервер увидел приземление. Под анкором
            физики нет и касания не будет никогда.
        --]]
        if engineAnchored then
            set_engine_anchor(false)
            engineAnchored = false
        end
        -- на время касания спуф снимаем: иначе клиент считает нас на лестнице
        set_climbing_spoof(false)
        pcall(function()
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = V3(v.X * 0.5, -CFG.AutoTouchdownSpeed, v.Z * 0.5)
        end)
        return true
    end

    if tdPhase == "returning" then
        local y = hrp.Position.Y
        if tdReturnY == nil or y >= tdReturnY - 2 then
            autotouchdown_reset()
            log("auto-touchdown: back at altitude, flight resumed")
            return false
        end
        -- возврат уже под анкором и со спуфом: это обычный полёт вверх
        set_climbing_spoof(true)
        hold_climbing_field()
        if not engineAnchored then
            set_engine_anchor(true)
            engineAnchored = true
        end
        pcall(function()
            local step = min(CFG.FlySpeed * dt * 3, tdReturnY - y)
            hrp.CFrame = hrp.CFrame + V3(0, step, 0)
        end)
        return true
    end

    return false
end

local function fly_step(dt)
    -- касание/возврат имеют приоритет над обычным вводом
    if autotouchdown_step(dt) then
        return
    end

    if CFG.FlyCollide then
        local hrp = cached_hrp()
        if not hrp then
            return
        end
        if engineAnchored then
            set_engine_anchor(false)
            engineAnchored = false
        end
        set_climbing_spoof(true)
        -- гасим только вертикальную тягу (она прижимает к земле),
        -- горизонтальную не трогаем, иначе борьба с движком = рывки
        local walking = get_walking_state()
        if walking then
            local forces = rawget(walking, "forces")
            if type(forces) == "table" and forces.bodyPosition then
                pcall(function()
                    forces.bodyPosition.MaxForce = ZERO3
                end)
            end
        end
        local dir = input_direction(true)
        local target = ZERO3
        if dir.Magnitude > 0.001 then
            target = dir.Unit * CFG.FlySpeed
        end
        local a = clamp(1 - CFG.FlySmooth, 0.05, 1)
        flyVel = flyVel + (target - flyVel) * a
        pcall(function()
            hrp.AssemblyLinearVelocity = flyVel
        end)
        return
    end

    -- рабочий режим: анкор + CFrame
    anchored_move(dt, CFG.FlySpeed, true, false)
end

local function noclip_step(dt)
    -- ноклип остаётся на анкоре: только так проходим сквозь геометрию
    local forceDown = false
    if not (CFG.SpoofClimbing and ctrl) then
        forceDown = needs_touchdown()
    end
    anchored_move(dt, CFG.NoClipSpeed, true, forceDown)
end

--======================================================================
--  ANTI-DROWN  (уязвимость: смерть в воде докладывает САМ КЛИЕНТ)
--======================================================================
--[[
    ЭТО ЕДИНСТВЕННАЯ СМЕРТЬ В ИГРЕ, КОТОРУЮ ЗАЯВЛЯЕТ КЛИЕНТ.
    ClientFramework:1327-1334 (в heartbeat):

        if v194 then                                  -- камера внутри зоны water
            fp_controller.water_time -= dt
            if fp_controller.water_time < 0.1 then
                u18:SendToServer()                    -- <- «я утонул»
            end
        else
            fp_controller.water_time += dt * 5
            fp_controller.water_time = clamp(0, plr_drown_time)
        end

    Сервер сам не считает, сколько мы под водой — он ждёт наш доклад. Значит
    достаточно НЕ дать таймеру опуститься: держим water_time на максимуме, и
    условие никогда не выполняется. Утонуть становится невозможно, при этом
    ни одного пакета мы не подделываем.

    Полезно и вне воды: зона water определяется по ����озиции КАМЕРЫ
    (Workspace.Camera.CFrame.Position), а не тела — с freecam/полётом камера
    легко оказывается под водой, пока тело сухое.
--]]
local function apply_antidrown()
    if not CFG.AntiDrown or not ctrl then
        return
    end
    pcall(function()
        local maxT = get_shared("plr_drown_time", 20)
        if rawget(ctrl, "water_time") ~= nil then
            ctrl.water_time = maxT
        end
    end)
end

--======================================================================
--  NO FALL  (сервер считает урон сам -> просто не падаем быстро)
--======================================================================
--[[
    ПОЧЕМУ РАНЬШЕ НЕ РАБОТАЛО (и что изменилось).
    Прошлая версия просто зажимала реальную вертикальную скорость. Это было
    ВИДНО (персонаж не ускорялся при падении), но урон всё равно приходил.
    Вывод: сервер считает урон не по скорости, а по ПРОЙДЕННОЙ ВЫСОТЕ —
    запоминает максимум Y за время в воздухе и вычитает Y приземления.
    Зажим скорости растягивает падение по времени, но не по расстоянию,
    поэтому и не помогал.

    ОБХОД (сейчас): раз урон считается по ПРОЙДЕННОЙ ВЫСОТЕ, мы просто никогда
    не сообщаем серверу изменение высоты — по Y уходит уровень земли под нами
    (project_y, ground projection). Максимум Y и Y приземления совпадают,
    перепад равен нулю, значит и урона нет. Тот же механизм закрывает airtime:
    в воздухе мы для сервера не были.

    Зажим скорости ниже оставлен вторым, ЛОКАЛЬНЫМ слоем — он нужен на случай,
    когда проекции нет (полёт над пропастью: земли под нами не нашлось).
--]]
local function apply_nofall(dt)
    if not CFG.NoFall then
        lastRealY = nil
        return
    end

    local hrp = cached_hrp()
    if not hrp then
        return
    end
    lastRealY = hrp.Position.Y

    --[[ Основную работу делает ground-projection в decide_reported_raw: сервер
         вообще не видит перепада высоты. Ниже — два ЛОКАЛЬНЫХ слоя, они не
         касаются сети и нужны на случай, если проекции не нашлось (пропасть):
         зажим скорости спуска и снятие клиентского штрафа за жёсткую поса��ку. ]]
    --[[ ЗАЖИМ ТОЛЬКО КАК ЗАПАСНОЙ ВАРИАНТ.
        Раньше это условие не смотрело на проекцию, поэтому медленный спуск
        включался на КАЖДОМ падении — при работающей проекции он не нужен
        (сервер уже не видит перепада), зато отлично заметен окружающим:
        игрок, планирующий вниз на 28 studs/s, выглядит однозначно.
        Теперь тормозим лишь тогда, когда скрывать падение нечем: проекция
        выключена или земли под нами не нашлось (projCovers == false). ]]
    if not engineAnchored and not projCovers and not is_grounded() then
        pcall(function()
            local vel = hrp.AssemblyLinearVelocity
            if vel.Y < -CFG.FallMaxSpeed then
                hrp.AssemblyLinearVelocity = V3(vel.X, -CFG.FallMaxSpeed, vel.Z)
            end
        end)
    end

    -- снимаем клиентский штраф скорости после жёсткого приземления
    if ctrl and rawget(ctrl, "jump_last_position") ~= nil then
        pcall(function() ctrl.jump_last_position = nil end)
    end
end

--======================================================================
--  ПРЫЖКИ / ВОЛЬТЫ
--======================================================================
local function apply_jump_tweaks()
    if not ctrl then
        return
    end
    if CFG.Bhop or CFG.InstantVault then
        local jt = rawget(ctrl, "jump_timer")
        if type(jt) == "table" then
            pcall(function() jt.next_time = 0 end)
        end
    end
    if CFG.NoLandingPenalty then
        local lt = rawget(ctrl, "landing_walkspeed_timer")
        if type(lt) == "table" then
            pcall(function() lt.next_time = 0 end)
        end
    end
end

--======================================================================
--  ПАССИВНЫЕ ТВИКИ
--======================================================================
local function apply_passive()
    if CFG.InfStamina and ctrl then
        local maxStam = get_shared("plr_max_stamina", 120)
        local maxArm = get_shared("plr_max_arm_stamina", 60)
        pcall(function()
            if rawget(ctrl, "stamina") ~= nil then
                ctrl.stamina = maxStam
            end
            if rawget(ctrl, "arm_stamina") ~= nil then
                ctrl.arm_stamina = maxArm
            end
        end)
    end

    if CFG.NoFall then
        -- гасит только клиентскую тряску/штраф; сам урон считает сервер,
        -- поэтому основную работу делает ground-ping в decide_reported
        set_shared("plr_fall_damage", false)
    end
    if CFG.AirControl then
        set_shared("plr_jump_control_momentum", true)
    end

    -- пакет 10: игра пишет в ctrl.stop имя метода FPC, вызванного через _G.
    -- Мы _G не трогаем, но чистим поле на случай чужих скриптов.
    if ctrl and rawget(ctrl, "stop") ~= nil then
        pcall(function() ctrl.stop = nil end)
    end
end

--======================================================================
--  DESYNC  (перехват исходящей позиции)
--======================================================================
--[[
    compress_position по всему дампу вызывается ровно один раз —
    FirstPersonController_extend:607, для НАШЕЙ исходящей позиции.
    Значит, патча этой функции достаточно, чтобы управлять тем, что сервер
    знает о нашем местоположении. Используем это ТОЛЬКО для Desync.
--]]
local NetEnc
pcall(function()
    NetEnc = require(RS.module.namespace.NetworkEncode).NetworkEncode
end)

local netHooked = false

--[[
    СОГЛАСОВАНИЕ СКОРОСТИ С ПОЗИЦИЕЙ.
    Под анкором (Fly/NoClip) реальная AssemblyLinearVelocity равна НУЛЮ, а
    позиция в пакете меняется. Для сервера это подпись телепорта: «позиция
    поехала, скорость нулевая». Поэтому скорость в пакете выводим из тех
    позиций, которые мы САМИ отправили — пакет становится внутренне
    непротиворечивым, как у обычного бегущего игрока.
    Это не подделка данных ради обхода проверки скорости (её мы и так держим в
    легальных рамках), а устранение искусственного противоречия, которое
    создаёт сам анкор.
--]]
-- lastSentPos / lastSentTime / derivedVel объявлены выше, вместе с остальным
-- состоянием, привязанным к телу (их сбрасывает refresh_ctrl при смерти)

--[[
    Ищем землю строго под нами. Персонажей и Workspace.ignore исключаем, иначе
    «землёй» окажется чужое тело или триггер-зона.
--]]
local groundRayParams = nil

local function ground_point(pos)
    if groundRayParams == nil then
        groundRayParams = RaycastParams.new()
        groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
        groundRayParams.IgnoreWater = true
    end
    local ignore = {}
    local chars = Workspace:FindFirstChild("characters")
    if chars then ignore[#ignore + 1] = chars end
    local ig = Workspace:FindFirstChild("ignore")
    if ig then ignore[#ignore + 1] = ig end
    groundRayParams.FilterDescendantsInstances = ignore

    local res = Workspace:Raycast(pos, V3(0, -CFG.GroundProjectDrop, 0), groundRayParams)
    if res == nil then
        return nil
    end
    -- +2.6 — центр HRP над поверхностью, как при обычной ходьбе
    return res.Position.Y + 2.6
end

--[[
    GROUND PROJECTION.
    Возвращает Y, который надо СООБЩИТЬ вместо реального. Ключевая деталь —
    отчётный Y не прыгает на новый уровень земли мгновенно, а догоняет его
    шагами по GroundProjectStep за пакет: пролёт над краем крыши меняет землю
    под нами скачком, а скачок Y в пакете — это подпись телепорта.

    Пока мы на земле, projY просто следует за реальным Y, поэтому включение и
    выключение проекции не создаёт разрыва.
--]]
local function project_y(realPos, grounded)
    if not CFG.GroundProject then
        projY = nil
        projCovers = false
        return realPos.Y
    end

    if grounded then
        -- на земле врать нечего: отчётный Y = реальный
        projY = realPos.Y
        projCovers = false
        return realPos.Y
    end

    local target = ground_point(realPos)
    if target == nil then
        --[[ Земли не нашлось -> сервер увидит реальное падение, значит
             локальный зажим скорости снова обязан работать. ]]
        projCovers = false
        --[[ Земли под нами нет (пропасть / полёт над картой). Проецировать
             некуда, поэтому держим последний известный уровень: он всё равно
             не даёт серверу увидеть падение. ]]
        if projY == nil then
            projY = realPos.Y
        end
        return projY
    end

    --[[ Выше земли мы быть не должны: если реальный Y УЖЕ ниже проекции
         (пробили пол ноклипом) — честно отдаём реальный, иначе сервер увидит
         нас парящим над землёй и это уже его насторожит. ]]
    if realPos.Y < target then
        projY = realPos.Y
        projCovers = false
        return realPos.Y
    end

    --[[ Дальше мы действительно врём про Y, то есть падение от сервера скрыто. ]]
    projCovers = true

    if projY == nil then
        projY = target
        return target
    end

    local step = max(CFG.GroundProjectStep, 0.1)
    local diff = target - projY
    if diff > step then
        projY = projY + step
    elseif diff < -step then
        projY = projY - step
    else
        projY = target
    end
    return projY
end

-- считает скорость по двум последним ОТПРАВЛЕННЫМ позициям
local function note_sent(pos)
    local now = clock()
    if lastSentPos ~= nil and lastSentTime ~= nil then
        local dt = now - lastSentTime
        if dt > 0.001 and dt < 1 then
            -- умножение на 1/dt вместо деления: работает одинаково и дешевле
            local v = (pos - lastSentPos) * (1 / dt)
            -- ground-ping даёт разовый скачок: такую «скорость» отдавать нельзя
            if v.Magnitude < 200 then
                derivedVel = v
            end
        end
    end
    lastSentPos = pos
    lastSentTime = now
end

--======================================================================
--  DESYNC — ФАЗЫ РАБОЧЕГО ЦИКЛА
--======================================================================
--[[
    Умеренный режим сам закрывает окно — по таймеру ИЛИ по достижению
    DesyncMaxDrift, что наступит раньше. Ловит нас не сам десинк, а накопленный
    отрыв, поэтому предохр��нитель по расстоянию важнее таймера.
--]]
local function desync_phase_update(realPos)
    if not CFG.Desync then
        dsActive, dsGhostPos, dsDrift = false, nil, 0
        return
    end

    local now = clock()

    if CFG.DesyncAggressive then
        if not dsActive then
            dsActive, dsPhaseAt, dsGhostPos = true, now, nil
        end
        return
    end

    if dsActive then
        local drift = dsGhostPos and (realPos - dsGhostPos).Magnitude or 0
        if (now - dsPhaseAt) * 1000 >= CFG.DesyncHoldMs or drift >= CFG.DesyncMaxDrift then
            -- фаза resync: отдаём честную точку, сервер догоняет
            dsActive, dsPhaseAt, dsGhostPos = false, now, nil
        end
    elseif (now - dsPhaseAt) * 1000 >= CFG.DesyncResyncMs then
        dsActive, dsPhaseAt = true, now
    end
end

local function decide_reported_raw(realPos)
    if reportedPos == nil then
        reportedPos = realPos
    end

    --[[
        ── NO FALL + AIRTIME (единый механизм) ──────────────────────────
        По X/Z шлём правду, ��о Y — уровень земли под нами. Сервер видит игрока,
        который всё время шёл по земле: перепада высот нет (нет урона), в
        воздухе мы не были (нет airtime_timeout). Подробнее — в CFG.GroundProject.
    --]]
    local grounded = is_grounded()
    local projected = V3(realPos.X, project_y(realPos, grounded), realPos.Z)
    reportedPos = projected

    --[[
        ── DESYNC ──────────────────────────────────────────────────────
        МЕТОД 1: возвращаем ОДНУ И ТУ ЖЕ точку. Игра сравнивает её с
        last_replication_state.position (FPC_extend:658) и, не увидев
        изменения, вообще не пишет позицию в пакет. Сервер остаётся с
        последней известной точкой, мы уходим — призрак готов.
    --]]
    desync_phase_update(projected)
    if dsActive and CFG.DesyncFreezePos then
        if dsGhostPos == nil then
            dsGhostPos = projected
        end
        dsDrift = (projected - dsGhostPos).Magnitude
        return dsGhostPos
    end
    dsDrift = 0
    return projected
end

--[[ ── СНЯТО: старая реализация NoFall и режимы Desync ────────────────────
    Ниже до конца блока — код, который больше не используется. Оставлять его
    нельзя (он перебивал бы новую логику), поэтому он удалён; здесь только
    объяснение, чтобы не вернуться к нему снова.

    NoFall через ground-ping не работал: чтобы сервер увидел землю, надо было
    отправить землю и следующим пакетом вернуться наверх, а мгновенный подъём
    ловит ac_movement. Из-за этого подстановку зажали порогом в 6 студов, и она
    почти никогда не срабатывала. Заменено непрерывной проекцией (project_y).

    Режимы stall / hybrid / fakelag / jitter удалены: все четыре сводились к
    сдвигу координаты на пару студов или задержке пакета, били по одному и тому
    же каналу и давали отрыв в считанные студы. Заменены четырьмя методами
    разной природы (см. CFG.Desync*).
--]]

local function decide_reported(realPos)
    local out = decide_reported_raw(realPos)
    note_sent(out)
    return out
end

local function hook_network()
    if netHooked or not NetEnc then
        return
    end
    --[[ МЕТОД 4 (заморозка анимации): запоминаем первое значение каждого канала
         за окно десинка и повторяем его, пока окно открыто. Объявлено ДО хуков,
         потому что write_time ниже ссылается на anim_reset_if_live. ]]
    local frozenPose, frozenLean, frozenLook = nil, nil, nil

    local function anim_frozen()
        return CFG.Desync and dsActive and CFG.DesyncFreezeAnim
    end

    -- сброс заморозки, как только окно закрылось
    local function anim_reset_if_live()
        if not anim_frozen() then
            frozenPose, frozenLean, frozenLook = nil, nil, nil
        end
    end

    -- начало пакета репликации: поднимаем is_climbing и просим переслать позу
    local origWriteTime = rawget(NetEnc, "write_time")
    if type(origWriteTime) == "function" then
        rawset(NetEnc, "write_time", function(buf, value)
            packet_window_open()
            anim_reset_if_live()
            return origWriteTime(buf, value)
        end)
    end

    -- подмена позы на «бег», чтобы серверный лимит скорости был 25, а не 14
    local origWritePose = rawget(NetEnc, "write_pose")
    if type(origWritePose) == "function" then
        rawset(NetEnc, "write_pose", function(buf, pose)
            if spoofActive and CFG.SpoofRunningPose then
                pose = 4            -- 1=idle 2=prone 3=crouching 4=running
            end
            if anim_frozen() then
                if frozenPose == nil then frozenPose = pose end
                pose = frozenPose
            end
            return origWritePose(buf, pose)
        end)
    end

    local origWriteLean = rawget(NetEnc, "write_lean")
    if type(origWriteLean) == "function" then
        rawset(NetEnc, "write_lean", function(buf, lean)
            if anim_frozen() then
                if frozenLean == nil then frozenLean = lean end
                lean = frozenLean
            end
            return origWriteLean(buf, lean)
        end)
    end

    --[[ Взгляд глушим на compress_look, а не на write_look: тогда сравнение
         v99 = compress_look(...) ~= last_replication_state.world_look даёт
         false, и взгляд не уходит в пакет вообще. ]]
    local origCompressLook = rawget(NetEnc, "compress_look")
    if type(origCompressLook) == "function" then
        rawset(NetEnc, "compress_look", function(look)
            local out = origCompressLook(look)
            if anim_frozen() then
                if frozenLook == nil then frozenLook = out end
                return frozenLook
            end
            frozenLook = nil
            return out
        end)
    end

    local origCompressPos = rawget(NetEnc, "compress_position")
    if type(origCompressPos) == "function" then
        rawset(NetEnc, "compress_position", function(pos)
            packet_window_close()
            local out = pos
            if typeof(pos) == "Vector3" then
                local ok, res = pcall(decide_reported, pos)
                if ok and typeof(res) == "Vector3" then
                    out = res
                end
            end
            return origCompressPos(out)
        end)
    end
    --[[
        Скорость приводим в соответствие с позицией ТОЛЬКО под анкором, где
        реальная velocity искусственно нулевая. В остальное время не тр��гаем.
        compress_velocity по дампу вызывается ровно один раз
        (FPC_extend:608) — только для нашего исходящего пакета, так что хук
        никого больше не задевает.
    --]]
    local origCompressVel = rawget(NetEnc, "compress_velocity")
    if type(origCompressVel) == "function" then
        rawset(NetEnc, "compress_velocity", function(vel)
            local out = vel
            if engineAnchored and derivedVel ~= nil and typeof(vel) == "Vector3" then
                out = derivedVel
            end
            return origCompressVel(out)
        end)
    end

    --[[
        Метку времени НЕ патчим сознательно: write_time читают другие клиенты
        (read_time -> parallel_position_buffer ->
        ReplicationBuffer.get_position(t - rollback)). Любое растяжение вр��мени
        кладёт наши записи «в будущее» относительно их часов, и мы выглядим
        застывшими/не там. Это и был�� источнико�� десинка в прошлых версиях.
    --]]
    netHooked = true
end

--======================================================================
--  DESYNC — МЕТОДЫ 2 и 3 (RakNet, пакетный уровень)
--======================================================================
--[[
    Методы 1 и 4 работают с ПРИКЛАДНЫМ пакетом игры. Но чужой клиент считает
    попадание не только по нему: хитбоксы наших частей движок реплицирует сам.
    Этот канал прикладным пакетом не достать — только RakNet.

    ID_TIMESTAMP (0x1B). Физические апдейты Roblox отправляет пакетами с меткой
    времени: по ней принимающая сторона понимает, к какому моменту относится
    состояние сборки. Отсюда два метода:
      • порча метки  -> состояние приходит, но упорядочить его нельзя;
      • Block()      -> состояние не приходит вовсе.

    ВАЖНО ЧЕСТНО: raknet.add_send_hook в Potassium требует включения RakNet в
    настройках executor'а, иначе хук молча не работает (это оговорено в самой
    документации). И риск бана здесь ВЫШЕ, чем у методов 1/4, потому что мы
    вмешиваемся в транспорт самого движка. Поэтому оба выключены по умолчанию.
--]]
local rakHooked = false
local rakAvailable = (type(raknet) == "table")

local function hook_raknet()
    if rakHooked or not rakAvailable then
        return
    end
    local ok = pcall(function()
        raknet.add_send_hook(function(packet)
            -- 0x1B = ID_TIMESTAMP
            if packet.PacketId ~= 0x1B then
                return
            end
            if not (CFG.Desync and dsActive) then
                return
            end

            if CFG.DesyncRakBlock then
                packet:Block()
                return
            end

            if CFG.DesyncRakTimestamp then
                local okb = pcall(function()
                    local buf = packet.AsBuffer
                    -- метка лежит сразу за идентификатором пакета
                    buffer.writeu32(buf, 1, 0xFFFFFFFF)
                    packet:SetData(buf)
                end)
                if not okb then
                    log("desync: не удалось перезаписать ID_TIMESTAMP")
                end
            end
        end)
    end)
    if ok then
        rakHooked = true
    else
        log("desync: raknet.add_send_hook недоступен (включи RakNet в настройках Potassium)")
    end
end

--======================================================================
--  DESYNC — ВИЗУАЛИЗАЦИЯ
--======================================================================
--[[
    Показываем ровно то, что видит сервер: точку, которую мы последней ему
    сообщили (dsGhostPos). Без этого десинк — «чёрный ящик»: непонятно, работает
    ли он и насколько разошёлся призрак.
      • круг      — призрак (по нему стреляют);
      • линия     — от нас до призрака;
      • подпись   — отрыв в студах, режим и активные методы.
--]]
local dsDraw = nil

local function desync_visual_destroy()
    if dsDraw == nil then
        return
    end
    for _, obj in pairs(dsDraw) do
        pcall(function() obj:Remove() end)
    end
    dsDraw = nil
end

local function desync_visual_ensure()
    if dsDraw ~= nil or type(Drawing) ~= "table" then
        return
    end
    local ok = pcall(function()
        local ring = Drawing.new("Circle")
        ring.Thickness, ring.NumSides, ring.Filled, ring.Visible = 2, 24, false, false
        ring.Color = Color3.fromRGB(255, 80, 80)

        local link = Drawing.new("Line")
        link.Thickness, link.Visible = 1, false
        link.Color = Color3.fromRGB(255, 80, 80)

        local tag = Drawing.new("Text")
        tag.Size, tag.Center, tag.Outline, tag.Visible = 13, true, true, false
        tag.Color = Color3.fromRGB(255, 210, 210)

        dsDraw = { ring = ring, link = link, tag = tag }
    end)
    if not ok then
        dsDraw = nil
    end
end

local function desync_visual_hide()
    if dsDraw == nil then
        return
    end
    for _, obj in pairs(dsDraw) do
        pcall(function() obj.Visible = false end)
    end
end

local function desync_visual_update()
    if not (CFG.Desync and CFG.DesyncVisualize) then
        desync_visual_hide()
        return
    end
    desync_visual_ensure()
    if dsDraw == nil then
        return
    end

    local hrp = cached_hrp()
    local cam = Workspace.CurrentCamera
    if hrp == nil or cam == nil or dsGhostPos == nil or not dsActive then
        desync_visual_hide()
        return
    end

    local ghost2d, ghostOn = cam:WorldToViewportPoint(dsGhostPos)
    local me2d, meOn = cam:WorldToViewportPoint(hrp.Position)
    if not ghostOn then
        desync_visual_hide()
        return
    end

    -- радиус привязан к расстоянию: вблизи круг больше, вдали меньше
    local dist = (cam.CFrame.Position - dsGhostPos).Magnitude
    local radius = math.clamp(900 / max(dist, 1), 6, 60)

    local gp = Vector2.new(ghost2d.X, ghost2d.Y)
    dsDraw.ring.Position = gp
    dsDraw.ring.Radius   = radius
    dsDraw.ring.Visible  = true

    dsDraw.tag.Position = Vector2.new(ghost2d.X, ghost2d.Y - radius - 16)
    dsDraw.tag.Text     = ("GHOST  %.1f st  [%s]"):format(
        dsDrift, CFG.DesyncAggressive and "aggressive" or "moderate")
    dsDraw.tag.Visible  = true

    if meOn then
        dsDraw.link.From    = Vector2.new(me2d.X, me2d.Y)
        dsDraw.link.To      = gp
        dsDraw.link.Visible = true
    else
        dsDraw.link.Visible = false
    end
end

--[[
    Полный сброс десинка. Обязательно сбрасываем dsGhostPos: иначе после
    выключения мы продолжили бы отдавать замороженную точку, и сервер оставил бы
    нас в призраке — то есть «выключил, а меня всё равно нет там, где я стою».
--]]
local function desync_stop()
    dsActive   = false
    dsGhostPos = nil
    dsDrift    = 0
    dsPhaseAt  = clock()
    desync_visual_hide()
end

--======================================================================
--  ЛОГГЕР ПРИЧИНЫ СМЕРТИ  (главный инструмент этой версии)
--======================================================================
--[[
    ЗАЧЕМ. Серверный код я видеть не могу, поэтому «что тебя убило» до сих пор
    было догадкой. Но сервер САМ присылает нам записи хитлога — именно из них
    DeathView и берёт причину.

    ГДЕ НАШЁЛ:
      ClientFramework:123-124
          local u40 = v12:Get("267603.47485371726")   -- ClientToServer
          local u41 = v12:Get("995825.1875876792")    -- ServerToClient  <-- этот
      ClientFramework:1052-1056
          u171:GiveTask(u41:Connect(function(p175)
              u46:info("updating hitlog after death")
              table.insert(u166.hitlog, p175)
          end))
      remotes:157  ["995825.1875876792"] = Definitions.ServerToClientEvent()
      namespace    "447425.4364725505"   (ClientFramework:95, v12)

    ЧТО В ЗАПИСИ. Тип берётся из поля .type, полный список зашит в клиенте
    (DeathView:216-232):
        took_damage | reset | airtime_timeout | drowned |
        took_explosion_damage | took_fire_damage | killed_via_console

    Подключаемся ПАРАЛЛЕЛЬНО игровому обработчику (не заменяем его), поэтому
    ничего не ломаем — просто печатаем в консоль всё, что пришло.
    Теперь на вопрос «что меня убило» будет ответ, а не версия.
--]]
local deathHooked = false
local lastDeathType = "none"

local function describe_hit(entry)
    if type(entry) ~= "table" then
        return tostring(entry)
    end
    local parts = {}
    -- сначала самое важное, потом всё остальное, что есть в записи
    local t = rawget(entry, "type")
    if t ~= nil then
        parts[#parts + 1] = "type=" .. tostring(t)
    end
    for k, v in pairs(entry) do
        if k ~= "type" and type(v) ~= "table" and type(v) ~= "function" then
            parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
        end
    end
    return table.concat(parts, " ")
end

--[[
    ПОЧЕМУ ПРОШЛАЯ ВЕРСИЯ МОЛЧАЛА.
    Я шёл через require(RS.module.remotes).default и :GetNamespace():Get().
    Этот путь отдаёт объект-обёртку @rbxts/net, и на нём Connect может не
    подцепиться (обёртка создаётся в своём окружении, а namespace-ключ ещё и
    участвует в формировании ИМЕНИ ремоута). Поэтому ни одной строки в консоли.

    Надёжный путь — подключаться к НАСТОЯЩЕМУ RemoteEvent. Разбор net по дампу:
        include/node_modules/@rbxts/net/out/internal:60-66
            _NetManaged = script.Parent:FindFirstChild("_NetManaged")
            -- папка, в которой лежат все ремоуты
        .../Inside_client/ClientEvent:29
            p5.instance = getRemoteOrThrow("RemoteEvent", p6)
        .../Inside_client/ClientEvent:46-58
            return p14.instance.OnClientEvent:Connect(u15)
    То есть обёртка в итоге просто вешается на OnClientEvent обычного
    RemoteEvent. Значит достаточно найти этот RemoteEvent по имени (в имени
    присутствует ключ события) и подключиться напрямую — без обёрток и без
    зависимости от того, в каком окружении собран net.
--]]
--[[ КЛЮЧ ОБНОВЛЁН. Старый "995825.1875876792" — от предыдущей версии игры, в
     текущем дампе его нет вообще, поэтому find_remote ничего не находил и
     death-log молчал даже с правильным механизмом подключения.
     Актуальный ключ (ClientFramework:130 -> :1076 table.insert(hitlog)):
         namespace "969130.894165284" (ClientFramework:101)
         hitlog S2C "316031.4389296031"  = u43 ]]
local HITLOG_KEY = "316031.4389296031"

local function find_remote(keySubstring)
    local found = nil
    -- 1) штатное место: папка _NetManaged внутри модуля net
    pcall(function()
        local nm = RS:FindFirstChild("_NetManaged", true)
        if nm then
            for _, child in ipairs(nm:GetDescendants()) do
                if child:IsA("RemoteEvent") and string.find(child.Name, keySubstring, 1, true) then
                    found = child
                    return
                end
            end
        end
    end)
    if found then
        return found
    end
    -- 2) запасной путь: поиск по всему ReplicatedStorage (ремоут могли перенести)
    pcall(function()
        for _, child in ipairs(RS:GetDescendants()) do
            if child:IsA("RemoteEvent") and string.find(child.Name, keySubstring, 1, true) then
                found = child
                return
            end
        end
    end)
    return found
end

local function hook_death_log()
    if deathHooked or not CFG.LogDeathReason then
        return
    end
    local ev = find_remote(HITLOG_KEY)
    if ev == nil then
        return          -- ремоут ещё не создан: цикл попробует снова
    end
    local ok = pcall(function()
        ev.OnClientEvent:Connect(function(entry)
            local desc = describe_hit(entry)
            if type(entry) == "table" and rawget(entry, "type") ~= nil then
                lastDeathType = tostring(rawget(entry, "type"))
            end
            log("HITLOG << " .. desc)
            --[[
                Поясняем самые важные типы, чтобы не лезть каждый раз в дамп.
            --]]
            if lastDeathType == "airtime_timeout" then
                log("  ^ SERVER airtime limit (ac_airtime_kill). is_climbing did NOT " ..
                    "exempt us -> lower AutoTouchdownAfter")
            elseif lastDeathType == "took_damage" then
                log("  ^ regular damage: bullets OR server-side fall damage")
            elseif lastDeathType == "drowned" then
                log("  ^ drowning: client-reported, AntiDrown should have blocked it")
            end
        end)
        deathHooked = true
        log("death-log: connected to hitlog remote '" .. ev.Name .. "'")
    end)
    if not ok then
        log("death-log: found remote but Connect failed")
    end
end

--======================================================================
--  ANTI-VOTEKICK
--======================================================================
--[[
    РАЗБОР ПО ДАМПУ.
    Namespace "477961.1280885361" (module/remotes:222-226):
        "299484.2376342709"  ServerToClient  -> открыть окно (player, reason)
        "110166.20104106168" ServerToClient  -> закрыть окно
        "812177.1199294078"  ClientToServer  -> наш голос (bool)
    Обработчики в dl_client:182-205: сервер присылает имя цели и причину,
    клиент рисует окно, а по нажатию отправляет vote(true/false).

    Что это даёт:
      • РАННЕЕ ПРЕДУПРЕЖДЕНИЕ. Мы узнаём о старте голосования и против кого
        оно, в тот же миг, что и остальные. Если цель — мы, есть время
        выключить всё (panic) до того, как кик состоится.
      • Свой голос отдаём «против» сразу и автоматически, окно не мешает.
    Подделать ИСХОД голосования с клиента нельзя — считает сервер, поэтому
    честно: это ��редупреждение + автоответ, а не отмена кика.
--]]
local voteHooked = false

--[[
    ИСПРАВЛЕНО (было "could not connect to namespace"). Две причины разом:

    1) НЕВЕРНЫЙ ПУТЬ. Шли через require(remotes).default + GetNamespace():Get().
       Это ровно тот обёрточный путь, который в этом же файле (см. death-log
       выше) уже признан ненадёжным: обёртка @rbxts/net собирается в сво��м
       окружении, и Connect на ней может не подцепиться. Теперь берём НАСТОЯЩИЙ
       RemoteEvent через find_remote(), как это делает рабочий death-log.

    2) КЛЮЧИ БЫЛИ ОТ СТАРОЙ ��ЕРСИИ ИГРЫ. В текущем дампе (dl_client:95,112-114)
       ключей 477961/299484/812177 НЕТ ВООБЩЕ:
           namespace  138004.31878449238   (v21)
           open  S2C  728887.5914058049    (v38 -> player, reason)
           close S2C  401758.55746792397   (v39)
           vote  C2S  25617.929726704515   (u40 -> vote(bool))
       Поэтому даже с правильным путём старые ключи ничего бы не нашли.

    Аргументы сверены по dl_client:195 — v38:Connect(p79, p80, p81), то есть
    player идёт ВТОРЫМ, а не первым.
--]]
local VOTE_OPEN_KEY = "728887.5914058049"
local VOTE_SEND_KEY = "25617.929726704515"

local function hook_votekick()
    if voteHooked or not CFG.AntiVotekick then
        return
    end
    local openEv = find_remote(VOTE_OPEN_KEY)
    local voteEv = find_remote(VOTE_SEND_KEY)
    if openEv == nil then
        return          -- ремоут ещё не создан: цикл попробует снова
    end
    local ok = pcall(function()
        openEv.OnClientEvent:Connect(function(_, player, reason)
            local target = tostring(player)
            local me = (target == LocalPlayer.Name) or (target == LocalPlayer.DisplayName)
            if me then
                log("!!! VOTEKICK AGAINST YOU: " .. tostring(reason) ..
                    " -> movement cheats OFF (panic)")
                CFG.Fly = false
                CFG.Speed = false
                CFG.NoClip = false
                CFG.Desync = false
            else
                log("votekick started against " .. target .. " (" .. tostring(reason) .. ")")
            end
            -- сырой RemoteEvent: FireServer, а не обёрточный SendToServer
            if CFG.VotekickAutoNo and voteEv then
                pcall(function() voteEv:FireServer(false) end)
            end
        end)
        voteHooked = true
        log("anti-votekick: connected to '" .. openEv.Name .. "'")
    end)
    if not ok then
        log("anti-votekick: found remote but Connect failed")
    end
end

--======================================================================
--  КЛАВИШИ
--======================================================================
-- getgenv().DLM.status() — one-shot state dump
local function status_lines()
    local function onoff(v) return v and "ON " or "off" end
    -- keys are UNBOUND by default under the loader, so never index them blindly
    local function keyName(k)
        if k == nil then return "-" end
        local ok, n = pcall(function() return k.Name end)
        return (ok and n) and tostring(n) or "-"
    end
    local speedMode
    if CFG.ConstantMultiplier then
        speedMode = "constant x" .. CFG.SpeedMultiplier .. " (FLAGGED)"
    elseif CFG.BurstSpeed then
        speedMode = "burst x" .. CFG.SpeedMultiplier
    else
        speedMode = "legit-max"
    end
    return {
        "--- MOVEMENT STATUS ---------------------------------",
        ("  [%s] Speed   key %-14s %s"):format(onoff(CFG.Speed), keyName(CFG.SpeedKey), speedMode),
        ("  [%s] Fly     key %-14s %d st/s, collide=%s")
            :format(onoff(CFG.Fly), keyName(CFG.FlyKey), CFG.FlySpeed, tostring(CFG.FlyCollide)),
        ("  [%s] NoClip  key %-14s %d st/s")
            :format(onoff(CFG.NoClip), keyName(CFG.NoClipKey), CFG.NoClipSpeed),
        ("  [%s] Bhop    key %-14s"):format(onoff(CFG.Bhop), keyName(CFG.BhopKey)),
        ("  [%s] Desync  key %-14s %s  [%s]"):format(
            onoff(CFG.Desync), keyName(CFG.DesyncKey),
            CFG.DesyncAggressive and "aggressive" or
                ("moderate " .. CFG.DesyncHoldMs .. "/" .. CFG.DesyncResyncMs .. "ms"),
            (function()
                local m = {}
                if CFG.DesyncFreezePos    then m[#m + 1] = "pos"   end
                if CFG.DesyncFreezeAnim   then m[#m + 1] = "anim"  end
                if CFG.DesyncRakTimestamp then m[#m + 1] = "stamp" end
                if CFG.DesyncRakBlock     then m[#m + 1] = "block" end
                return #m > 0 and table.concat(m, "+") or "no method"
            end)()),
        "  --- passive (no keybind) --------------------------",
        --[[ Печатаем ещё и projCovers: по нему сразу видно, скрывает ли падение
             проекция (тогда зажим спит) или включён запасной медленный спуск. ]]
        ("  [%s] NoFall            clamp %d st/s, fallback=%s (proj covers=%s)"):format(
            onoff(CFG.NoFall), CFG.FallMaxSpeed,
            tostring(not projCovers), tostring(projCovers)),
        ("  [%s] GroundProjection  step %d st%s"):format(
            onoff(CFG.GroundProject), CFG.GroundProjectStep,
            projY and (", reported Y " .. ("%.0f"):format(projY)) or ""),
        ("  [%s] AutoTouchdown     every %.0fs of flight, return=%s")
            :format(onoff(CFG.AutoTouchdown), CFG.AutoTouchdownAfter,
                    tostring(CFG.AutoTouchdownReturn)),
        ("  [%s] SpoofClimbing     [%s] SpoofRunningPose")
            :format(onoff(CFG.SpoofClimbing), onoff(CFG.SpoofRunningPose)),
        ("  [%s] AntiDrown         [%s] AntiVotekick")
            :format(onoff(CFG.AntiDrown), onoff(CFG.AntiVotekick)),
        ("  [%s] FreeGun           [%s] InfStamina")
            :format(onoff(CFG.FreeGun), onoff(CFG.InfStamina)),
        ("  [%s] InstantVault      [%s] NoLandingPenalty")
            :format(onoff(CFG.InstantVault), onoff(CFG.NoLandingPenalty)),
        ("  [%s] LogDeathReason    (prints HITLOG lines on death)")
            :format(onoff(CFG.LogDeathReason)),
        "----------------------------------------------------",
    }
end

local function print_status()
    for _, line in ipairs(status_lines()) do
        log(line)
    end
end

conns[#conns + 1] = UIS.InputBegan:Connect(function(input, processed)
    if processed or not running then
        return
    end
    local key = input.KeyCode
    if key == CFG.SpeedKey then
        CFG.Speed = not CFG.Speed
        apply_speed()
        local mode
        if CFG.ConstantMultiplier then
            mode = "x" .. CFG.SpeedMultiplier .. " constant (flagged)"
        elseif CFG.BurstSpeed then
            mode = "burst x" .. CFG.SpeedMultiplier
        else
            mode = "legit-max"
        end
        log("Speed: " .. (CFG.Speed and ("ON (" .. mode .. ")") or "OFF"))
    elseif key == CFG.FlyKey then
        CFG.Fly = not CFG.Fly
        if not CFG.Fly then
            anchored_stop()
            autotouchdown_reset()
        end
        local how = CFG.SpoofClimbing and "climb-spoof" or "airtime-guard"
        log("Fly: " .. (CFG.Fly and ("ON (" .. how .. ", " .. CFG.FlySpeed .. " st/s)") or "OFF"))
    elseif key == CFG.NoClipKey then
        CFG.NoClip = not CFG.NoClip
        if not CFG.NoClip then
            anchored_stop()
        end
        log("NoClip: " .. (CFG.NoClip and "ON (anchored CFrame)" or "OFF"))
    elseif key == CFG.BhopKey then
        CFG.Bhop = not CFG.Bhop
        log("Bhop: " .. (CFG.Bhop and "ON" or "OFF"))
    elseif key == CFG.DesyncKey then
        CFG.Desync = not CFG.Desync
        if not CFG.Desync then
            desync_stop()
        else
            dsPhaseAt = clock()
            hook_raknet()
        end
        log("Desync: " .. (CFG.Desync
            and ("ON (" .. (CFG.DesyncAggressive and "aggressive" or "moderate") .. ")")
            or "OFF"))
    end
end)

--======================================================================
--  ЦИКЛЫ
--======================================================================
local lastFrame = clock()

conns[#conns + 1] = RunService.RenderStepped:Connect(function()
    if not running then
        return
    end
    local now = clock()
    local dt = now - lastFrame
    lastFrame = now
    if dt <= 0 or dt > 0.5 then
        dt = 1 / 60
    end

    --[[
        ЖИВОЕ ТЕЛО — КАЖДЫЙ КАДР.
        Раньше контроллер обновлялся только в фоновом цикле раз в
        ApplyInterval (0.5с). После респавна полсекунды все спуфы уходили в
        труп: is_climbing не попадал в пакет, анкор ставился не тому объекту.
        Именно так и выглядело «movement перестаёт работать после пары
        смертей». Теперь framework ищется один раз, а живое тело читается
        прямым rawget — это беспл��тно, поэтому делаем покадрово.
    --]]
    refresh_ctrl()

    update_airtime(dt)

    --[[
        ВАЖНО (был баг «улетаю вверх»):
        раньше при включённом Fly первая ветка каждый кадр вызывала
        anchored_stop(), а он делает ensure_safe_exit() — луч вверх находит
        ПОТОЛОК и поднимает тело на 2.5 studs до 12 раз, то есть +30 studs
        за кадр. Затем fly_step снова анкорил. Отсюда и полёт в небо.
        Теперь анкор снимается ТОЛЬКО когда выключены и ноклип, и полёт.
    --]]
    local anchorWanted = CFG.NoClip or (CFG.Fly and not CFG.FlyCollide)
    --[[
        Во время фазы спуска auto-touchdown анкор НУЖЕН снятым: без физики
        персонаж не коснётся земли и grounded никогда не станет true. Поэтому
        на эту фазу исключаем анкор из «желаемого» — иначе следующая же строка
        поставит его обратно и касание не случится никогда.
    --]]
    if tdPhase == "descending" then
        anchorWanted = false
    end

    if CFG.NoClip then
        noclip_step(dt)
    elseif CFG.Fly then
        fly_step(dt)
    end

    if not anchorWanted and engineAnchored then
        anchored_stop()
    end

    if CFG.Bhop or CFG.InstantVault or CFG.NoLandingPenalty then
        apply_jump_tweaks()
    end

    if CFG.Speed then
        apply_speed()
    end

    apply_nofall(dt)
    apply_antidrown()

    --[[ Хук RakNet ставим лениво — только когда десинк реально включили: он
         вмешивается в транспорт движка, и держать его вхолостую незачем. ]]
    if CFG.Desync and (CFG.DesyncRakTimestamp or CFG.DesyncRakBlock) then
        hook_raknet()
    end
    desync_visual_update()

    -- вернуть ствол, если игра его убрала (freecam/лестница/что угодно)
    if CFG.FreeGun then
        apply_free_gun()
    end

    --[[
        КОГДА СПУФ НУЖЕН.
        Кроме полёта и ноклипа держим его ВСЁ ВРЕМЯ, пока мы в воздухе и включён
        NoFall. Иначе выходило так: выключаеш�� полёт на высоте -> спуф снят ->
        падение обычное -> сервер начисляет урон падения (он считает его сам по
        реплицированной высоте). Пока в пакете стоит «я на лестнице», серверу
        нечего засчитывать — ни airtime, ни падение.
    --]]
    local wantSpoof = CFG.Fly or CFG.NoClip
    if not wantSpoof and CFG.NoFall and not is_grounded() then
        wantSpoof = true
    end
    --[[
        ВО ВРЕМЯ КАСАНИЯ СПУФ ОБЯЗАН БЫТЬ СНЯТ.
        Смысл касания — чтобы СЕРВЕР увидел, что мы приземлились, и обнулил
        счётчик воздуха. Если в пакете при этом стоит is_climbing = true, мы
        сообщаем «я на лестнице» — то есть ровно то состояние, из-за которого
        счётчик и не сбрасывается. Поэтому на фазу спуска спуф выключаем, а
        на возврате включаем обратно.
    --]]
    if tdPhase == "descending" then
        wantSpoof = false
    end
    if not wantSpoof then
        set_climbing_spoof(false)
    else
        set_climbing_spoof(true)
        --[[
            И СРАЗУ ДЕРЖИМ САМО ПОЛЕ. FPC:1475 перезаписывает is_climbing
            каждый кадр из состояния симуляции, поэтому переставляем покадрово.
            Это и есть тот «локальный» вариант, который у тебя работал; окно
            пакета осталось вторым слоем.
        --]]
        hold_climbing_field()
    end
end)

task.spawn(function()
    while running do
        pcall(refresh_ctrl)     -- он же обновляет lifetime из framework
        pcall(hook_network)
        pcall(hook_votekick)
        pcall(hook_death_log)

        pcall(apply_speed)
        pcall(apply_passive)
        task.wait(CFG.ApplyInterval)
    end
end)

--======================================================================
--  ВЫГРУЗКА
--======================================================================
--[[
    ДИАГНОСТИКА: getgenv().DLM.debug()
    Показывает то, что раньше приходилось угадывать. Если ctrl=false — мы мертвы
    или framework не найден, и никакие спуфы не работают в принципе.
--]]
DLM.debug = function()
    local climbField = "?"
    if ctrl then
        climbField = tostring(rawget(ctrl, "is_climbing"))
    end
    local s = ("ctrl=%s lifetime=%s anchored=%s spoof=%s climbField=%s packets=%d climbSent=%d air=%.1f projY=%s desync=%s drift=%.1f rak=%s traps=%d")
        :format(tostring(ctrl ~= nil), tostring(lifetime ~= nil),
                tostring(engineAnchored), tostring(spoofActive), climbField,
                packetsSeen, climbSent, airtime,
                projY and ("%.0f"):format(projY) or "-",
                tostring(dsActive), dsDrift, tostring(rakHooked), genvKilled)
    log(s)
    return s
end

-- сбросить счётчики: удобно замерить ровно один полёт
DLM.reset_counters = function()
    packetsSeen = 0
    climbSent = 0
    log("packet counters reset")
end

-- полная таблица «что включено»: getgenv().DLM.status()
DLM.status = function()
    print_status()
    return table.concat(status_lines(), "\n")
end

-- фаза auto-touchdown: нужна харнессу для проверки цикла фаз
DLM.__td_phase = function()
    return tdPhase
end

-- последняя причина смерти, присланная сервером
DLM.last_death = function()
    log("last death reason from server: " .. lastDeathType)
    return lastDeathType
end

-- пробник для проверки Desync "stall": показывает срок следующего пакета
DLM.__timer_probe = function()
    if not ctrl then
        return nil
    end
    local t = rawget(ctrl, "replication_timer")
    if type(t) ~= "table" then
        return nil
    end
    return rawget(t, "next_time")
end

DLM.unload = function()
    running = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    anchored_stop()
    -- (анкор снимается в anchored_stop)
    desync_stop()
    -- Drawing-объекты живут вне дерева игры, их надо удалить явно
    desync_visual_destroy()
    if ctrl then
        local charData = rawget(ctrl, "char_data")
        if type(charData) == "table" then
            local overrides = rawget(charData, "overrides")
            if type(overrides) == "table" then
                pcall(function() overrides.speed = 1 end)
            end
        end
    end
    set_shared("plr_fall_damage", true)
    set_shared("plr_jump_control_momentum", false)
    if getgenv().DLM == DLM then
        getgenv().DLM = nil
    end
    log("unloaded")
end

--======================================================================
--  СТАРТ
--======================================================================
task.wait(0.2)
refresh_ctrl()
hook_network()
hook_votekick()
hook_death_log()

apply_speed()
apply_passive()

-- one line on load; the full table is available via DLM.status() / the UI button
log(("movement armed | ctrl=%s lifetime=%s net-hook=%s death-log=%s genv-traps=%d")
    :format(tostring(ctrl ~= nil), tostring(lifetime ~= nil), tostring(netHooked),
            tostring(deathHooked), genvKilled))
if lifetime == nil then
    log("WARNING: lifetime_state not found -> NoClip/Fly will misbehave")
end

--======================================================================
--  LOADER MODULE  (Syllinse Project / MacLib)
--======================================================================
return {
    -- everything starts OFF and unbound; the user enables it from the UI
    start = function()
        CFG.Speed, CFG.Fly, CFG.NoClip, CFG.Bhop, CFG.Desync = false, false, false, false, false
        CFG.NoFall, CFG.AutoTouchdown = false, false
        CFG.InfStamina, CFG.NoLandingPenalty, CFG.InstantVault = false, false, false
        CFG.AntiDrown, CFG.AntiVotekick, CFG.FreeGun = false, false, false
        CFG.AirControl, CFG.ForceTouchdown, CFG.ConstantMultiplier = false, false, false
        CFG.SpeedKey, CFG.FlyKey, CFG.NoClipKey = nil, nil, nil
        CFG.BhopKey, CFG.DesyncKey = nil, nil
    end,

    stop = function()
        if DLM and type(DLM.unload) == "function" then pcall(DLM.unload) end
    end,

    buildUI = function(ctx)
        local ready = false
        task.defer(function() ready = true end)
        local function note(t, b) if ready then pcall(ctx.notify, t, b) end end

        -- master switch + empty keybind (fires on PC and mobile FAB)
        local function feature(sec, o)
            local guard, el = false, nil
            local function commit(v)
                v = v and true or false
                o.set(v)
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

        local function bool(sec, name, o)
            sec:Toggle({ Name = name, Default = o.Default == true,
                Callback = function(v) o.set(v and true or false); note(name, v and "Enabled" or "Disabled") end },
                ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
        end

        local function slider(sec, o)
            sec:Slider({ Name = o.Name, Default = o.Default, Minimum = o.Min, Maximum = o.Max,
                Precision = o.Precision or 0, Suffix = o.Suffix, Prefix = o.Prefix,
                Callback = o.Callback }, ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
        end

        local function dropdown(sec, o)
            sec:Dropdown({ Name = o.Name, Options = o.Options, Default = o.Default, Required = true,
                Callback = function(v) if type(v) == "string" and v ~= "" then o.Callback(v) end end },
                ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
        end

        local T = ctx.tabs.Movement

        ---------------------------------------------------------------- Speed
        local s1 = T:Section({ Side = "Left" })
        s1:Header({ Name = "Speed" })
        feature(s1, { Title = "Speed", Flag = "MV_Speed",
            get = function() return CFG.Speed end,
            set = function(v) CFG.Speed = v end })

        s1:Divider()
        s1:Header({ Name = "Mode" })
        dropdown(s1, { Name = "Mode", Flag = "MV_SpeedMode",
            Options = { "Legit", "Burst", "Constant" }, Default = "Burst",
            Callback = function(v)
                CFG.LegitMax           = (v == "Legit" or v == "Burst")
                CFG.BurstSpeed         = (v == "Burst")
                CFG.ConstantMultiplier = (v == "Constant")
            end,
            Desc = "Legit = local penalties only\nBurst = short dashes, passes the server window\nConstant = flagged by ac_movement" })
        slider(s1, { Name = "Multiplier", Flag = "MV_SpeedMul", Default = 2.2,
            Min = 1.1, Max = 5, Precision = 1, Prefix = "x",
            Callback = function(v) CFG.SpeedMultiplier = v end })
        slider(s1, { Name = "Burst On", Flag = "MV_BurstOn", Default = 800,
            Min = 200, Max = 1500, Suffix = " ms",
            Callback = function(v) CFG.BurstOnTime = v / 1000 end,
            Desc = "keep under 1s" })
        slider(s1, { Name = "Burst Off", Flag = "MV_BurstOff", Default = 700,
            Min = 200, Max = 2000, Suffix = " ms",
            Callback = function(v) CFG.BurstOffTime = v / 1000 end })

        ---------------------------------------------------------------- Fly
        local s2 = T:Section({ Side = "Right" })
        s2:Header({ Name = "Fly" })
        feature(s2, { Title = "Fly", Flag = "MV_Fly",
            get = function() return CFG.Fly end,
            set = function(v) CFG.Fly = v; if not v then anchored_stop(); autotouchdown_reset() end end,
            Desc = "Space = up, LeftCtrl = down" })
        slider(s2, { Name = "Speed", Flag = "MV_FlySpeed", Default = 22,
            Min = 8, Max = 60, Suffix = " st/s",
            Callback = function(v) CFG.FlySpeed = v end,
            Desc = "22 = legal run speed" })
        slider(s2, { Name = "Smoothing", Flag = "MV_FlySmooth", Default = 35,
            Min = 0, Max = 90, Suffix = " %",
            Callback = function(v) CFG.FlySmooth = v / 100 end })
        bool(s2, "Collide With Walls", { Flag = "MV_FlyCollide", Default = false,
            set = function(v) CFG.FlyCollide = v end,
            Desc = "off = pass through geometry (more stable)" })
        s2:SubLabel({ Text = "enable Free Gun in the Gun Mods tab to keep your weapon" })

        ---------------------------------------------------------------- NoClip
        local s3 = T:Section({ Side = "Left" })
        s3:Header({ Name = "NoClip" })
        feature(s3, { Title = "NoClip", Flag = "MV_NoClip",
            get = function() return CFG.NoClip end,
            set = function(v) CFG.NoClip = v; if not v then anchored_stop() end end })
        slider(s3, { Name = "Speed", Flag = "MV_ClipSpeed", Default = 22,
            Min = 8, Max = 60, Suffix = " st/s",
            Callback = function(v) CFG.NoClipSpeed = v end })
        bool(s3, "Safe Exit", { Flag = "MV_ClipSafe", Default = true,
            set = function(v) CFG.NoClipSafeExit = v end,
            Desc = "leaving noclip inside geometry kills you" })

        ---------------------------------------------------------------- Airtime
        local s4 = T:Section({ Side = "Right" })
        s4:Header({ Name = "Airtime" })
        s4:SubLabel({ Text = "ac_airtime_kill is server-side: it counts how long you report being off the ground\n"
            .. "MAIN FIX = 'Ground Projection' in the No Fall section: it reports the ground under you as your Y,\n"
            .. "so the server never sees you leave the ground and the timer never starts\n"
            .. "the options below are fallbacks for when no ground exists under you (flying over a void)" })
        bool(s4, "Auto Touchdown", { Flag = "MV_AutoTD", Default = false,
            set = function(v) CFG.AutoTouchdown = v end,
            Desc = "drops to the ground, touches, flies back up" })
        slider(s4, { Name = "Touchdown Every", Flag = "MV_AutoTDAfter", Default = 8,
            Min = 3, Max = 30, Suffix = " s",
            Callback = function(v) CFG.AutoTouchdownAfter = v end,
            Desc = "lower it if you still get airtime_timeout" })
        bool(s4, "Return To Altitude", { Flag = "MV_AutoTDRet", Default = true,
            set = function(v) CFG.AutoTouchdownReturn = v end })
        bool(s4, "Spoof Climbing", { Flag = "MV_SpoofClimb", Default = true,
            set = function(v) CFG.SpoofClimbing = v end,
            Desc = "ladder bit = legal airtime" })
        bool(s4, "Spoof Running Pose", { Flag = "MV_SpoofPose", Default = true,
            set = function(v) CFG.SpoofRunningPose = v end,
            Desc = "raises the server speed limit from 14 to 25" })

        ---------------------------------------------------------------- No Fall
        local s5 = T:Section({ Side = "Left" })
        s5:Header({ Name = "No Fall" })
        feature(s5, { Title = "No Fall", Flag = "MV_NoFall",
            get = function() return CFG.NoFall end,
            set = function(v) CFG.NoFall = v end,
            Desc = "local layer: clamps descent speed + landing penalty" })
        slider(s5, { Name = "Max Fall Speed", Flag = "MV_FallSpeed", Default = 28,
            Min = 10, Max = 80, Suffix = " st/s",
            Callback = function(v) CFG.FallMaxSpeed = v end,
            Desc = "fallback only: applies when Ground Projection\n"
                .. "cannot cover the fall (off, or no ground below)" })
        bool(s5, "Ground Projection", { Flag = "MV_GroundProject", Default = true,
            set = function(v) CFG.GroundProject = v end,
            Desc = "reports the ground under you as your Y at all times\n"
                .. "server sees no height drop -> no fall damage, no airtime kill" })
        slider(s5, { Name = "Projection Step", Flag = "MV_GroundStep", Default = 3,
            Min = 1, Max = 10, Suffix = " st",
            Callback = function(v) CFG.GroundProjectStep = v end,
            Desc = "how fast reported Y catches a new ground level\nlower = smoother, higher = keeps up over roof edges" })

        ---------------------------------------------------------------- Desync
        local s6 = T:Section({ Side = "Right" })
        s6:Header({ Name = "Desync" })
        feature(s6, { Title = "Desync", Flag = "MV_Desync",
            get = function() return CFG.Desync end,
            set = function(v)
                CFG.Desync = v
                if not v then desync_stop() else dsPhaseAt = clock() end
            end,
            Desc = "enemies see you normally, damage does not register" })

        bool(s6, "Aggressive", { Flag = "MV_DesyncAggr", Default = false,
            set = function(v) CFG.DesyncAggressive = v; desync_stop() end,
            Desc = "OFF = hold/resync cycle, auto-recovers before anticheat reacts\n"
                .. "ON  = desync held nonstop, max effect, risks rollback / airtime kill" })
        slider(s6, { Name = "Hold", Flag = "MV_DesyncHold", Default = 170,
            Min = 40, Max = 400, Suffix = " ms",
            Callback = function(v) CFG.DesyncHoldMs = v end,
            Desc = "rollback window is 190ms; above it your OWN hits start missing" })
        slider(s6, { Name = "Resync", Flag = "MV_DesyncResync", Default = 120,
            Min = 40, Max = 400, Suffix = " ms",
            Callback = function(v) CFG.DesyncResyncMs = v end,
            Desc = "moderate mode only: honest replication between windows" })
        slider(s6, { Name = "Max Drift", Flag = "MV_DesyncDrift", Default = 18,
            Min = 4, Max = 60, Suffix = " st",
            Callback = function(v) CFG.DesyncMaxDrift = v end,
            Desc = "closes the window early once the ghost lags this far" })

        -- методы: разная природа, можно комбинировать
        bool(s6, "Freeze Position", { Flag = "MV_DesyncPos", Default = true,
            set = function(v) CFG.DesyncFreezePos = v end,
            Desc = "repeats one coordinate so the game skips sending position" })
        bool(s6, "Freeze Animation", { Flag = "MV_DesyncAnim", Default = false,
            set = function(v) CFG.DesyncFreezeAnim = v end,
            Desc = "freezes pose/lean/look: your rig becomes a statue for others" })
        bool(s6, "RakNet: Bad Timestamp", { Flag = "MV_DesyncStamp", Default = false,
            set = function(v) CFG.DesyncRakTimestamp = v; if v then hook_raknet() end end,
            Desc = "corrupts ID_TIMESTAMP on physics packets (engine-level)\n"
                .. "needs RakNet enabled in Potassium settings; higher ban risk" })
        bool(s6, "RakNet: Block Physics", { Flag = "MV_DesyncBlock", Default = false,
            set = function(v) CFG.DesyncRakBlock = v; if v then hook_raknet() end end,
            Desc = "drops outgoing physics packets entirely; hardest desync" })
        bool(s6, "Visualize", { Flag = "MV_DesyncVis", Default = true,
            set = function(v) CFG.DesyncVisualize = v; if not v then desync_visual_hide() end end,
            Desc = "draws the ghost the server shoots at, plus drift in studs" })

        ------------------------------------------------ Bhop (own section)
        local s7 = T:Section({ Side = "Left" })
        s7:Header({ Name = "Bhop" })
        feature(s7, { Title = "Bhop", Flag = "MV_Bhop",
            get = function() return CFG.Bhop end,
            set = function(v) CFG.Bhop = v end,
            Desc = "auto jump while held" })

        ------------------------------------- Infinite Stamina (own section)
        local s8 = T:Section({ Side = "Right" })
        s8:Header({ Name = "Infinite Stamina" })
        feature(s8, { Title = "Infinite Stamina", Flag = "MV_InfStam",
            get = function() return CFG.InfStamina end,
            set = function(v) CFG.InfStamina = v end,
            Desc = "stamina lives only in the client controller" })

        ----------------------------------- No Landing Penalty (own section)
        local s9 = T:Section({ Side = "Left" })
        s9:Header({ Name = "No Landing Penalty" })
        feature(s9, { Title = "No Landing Penalty", Flag = "MV_NoLandPen",
            get = function() return CFG.NoLandingPenalty end,
            set = function(v) CFG.NoLandingPenalty = v end,
            Desc = "removes the slowdown after landing" })

        ---------------------------------------- Instant Vault (own section)
        local s10 = T:Section({ Side = "Right" })
        s10:Header({ Name = "Instant Vault" })
        feature(s10, { Title = "Instant Vault", Flag = "MV_InstVault",
            get = function() return CFG.InstantVault end,
            set = function(v) CFG.InstantVault = v end,
            Desc = "removes the delay when climbing over obstacles" })

        ------------------------------------------- Anti Drown (own section)
        local s11 = T:Section({ Side = "Left" })
        s11:Header({ Name = "Anti Drown" })
        feature(s11, { Title = "Anti Drown", Flag = "MV_AntiDrown",
            get = function() return CFG.AntiDrown end,
            set = function(v) CFG.AntiDrown = v end,
            Desc = "drowning is the only death the client reports itself" })

        ---------------------------------------- Anti Votekick (own section)
        local s12 = T:Section({ Side = "Right" })
        s12:Header({ Name = "Anti Votekick" })
        feature(s12, { Title = "Anti Votekick", Flag = "MV_AntiVK",
            get = function() return CFG.AntiVotekick end,
            set = function(v) CFG.AntiVotekick = v end,
            Desc = "auto-votes no, warns and panics if you are the target" })
        bool(s12, "Auto Vote No", { Flag = "MV_VKAutoNo", Default = true,
            set = function(v) CFG.VotekickAutoNo = v end })

        --==============================================================
        -- TAB: GUN MODS  (movement's contribution)
        --==============================================================
        local G = ctx.tabs.GunMods

        local g1 = G:Section({ Side = "Right" })
        g1:Header({ Name = "Free Gun" })
        feature(g1, { Title = "Free Gun", Flag = "MV_FreeGun",
            get = function() return CFG.FreeGun end,
            set = function(v) CFG.FreeGun = v end,
            Desc = "restores the weapon whenever the game removes it\nrequired together with Fly" })

        --==============================================================
        -- TAB: DEBUG  (created by the loader)
        --==============================================================
        local D = ctx.tabs.Debug

        local d1 = D:Section({ Side = "Left" })
        d1:Header({ Name = "Death Reason" })
        bool(d1, "Log Death Reason", { Flag = "MV_LogDeath", Default = true,
            set = function(v) CFG.LogDeathReason = v end,
            Desc = "prints the server death type: airtime_timeout, took_damage, ..." })
        d1:Button({ Name = "Last Death Reason", Callback = function()
            note("Last Death", tostring(lastDeathType))
        end }, ctx.flag("MV_BtnDeath"))

        local d2 = D:Section({ Side = "Right" })
        d2:Header({ Name = "Movement State" })
        d2:Button({ Name = "Print Status", Callback = function()
            pcall(print_status); note("Movement", "status -> console")
        end }, ctx.flag("MV_BtnStatus"))
        d2:Button({ Name = "Print Debug", Callback = function()
            pcall(DLM.debug); note("Movement", "debug -> console")
        end }, ctx.flag("MV_BtnDebug"))
        d2:Button({ Name = "Reset Packet Counters", Callback = function()
            pcall(DLM.reset_counters); note("Movement", "counters reset")
        end }, ctx.flag("MV_BtnReset"))
    end,
}
