--[[
    DEADLINE 0.25.2 — SUITE v5  (Potassium)
    ======================================================================
    Обход (deadline_bypass.lua) запускается ОТДЕЛЬНО и ПЕРВЫМ.

    АРХИТЕКТУРА ESP (переписана против мелькания/лага):
      • Drawing-объекты закреплены ЗА МОДЕЛЬЮ игрока (espByModel), а НЕ
        переиспользуются по индексу слота. Создаются при первом появлении
        врага, уничтожаются когда модель исчезла. Ноль перетасовки = ноль
        мелькания.
      • Bounding box стабильный: строится из humanoid_root_part + верх головы
        + ноги, шириной height*aspect. Проекция проверяет только Z>0 (точка
        перед камерой), БЕЗ гейта "в пределах вьюпорта" — поэтому враг у края
        экрана не пропадает и бокс не прыгает от махов рук/ног.
      • Скелет и все элементы красятся ЦВЕТОМ БОКСА (видим/скрыт).

    ПРОИЗВОДИТЕЛЬНОСТЬ:
      • SilentAim-резолв (дорогие raycast'ы MultiPoint/Resolver) троттлится
        до AimResolveInterval (20 Гц), между резолвами цель кэшируется и
        только проверяется на живость. Визуалы обновляются каждый кадр.
      • Видимость ESP кэшируется на VisCacheTtl (1 raycast на игрока/кадр).
      • filtergc метаданных — раз в MetaRefresh; реестр сущностей мёржится
        (не пересобирается), игрок не мигает между рефрешами.

    MULTIPOINT (как в BRM5Lib): бинарный поиск смещения дула по
      {cam.Right, -cam.Right, cam.Up}, из которого к кости есть прямой путь.
      Визуализация: линия дуло->цель; при спуфе дуло->спуф (жёлтая) +
      спуф->цель (зелёная).

    Выключить: getgenv().DL.unload()   |   Конфиг: getgenv().DL.config
--]]

if getgenv().DL and getgenv().DL.unload then
    pcall(getgenv().DL.unload)
end

local DL = {}
getgenv().DL = DL

local function log(msg)
    local out = rconsoleprint or print
    pcall(out, "[dl] " .. tostring(msg))
end

--======================================================================
--  CONFIG
--======================================================================
local CFG = {
    -- ── ESP ──────────────────────────────────────────────────────────
    ESP                = true,
    EspEnemyOnly       = true,
    EspMaxDistance     = 1500,
    EspBox             = true,
    EspBoxMode         = "Corner",      -- "Corner" | "Box"
    EspCornerScale     = 0.28,          -- доля стороны на уголок
    EspBoxAspect       = 0.62,          -- ширина = высота * aspect
    EspBoxThickness    = 1.6,
    EspShowName        = true,
    EspShowDistance    = true,
    EspShowWeapon      = true,
    EspShowStates      = true,
    EspHpBar           = true,
    EspSkeleton        = true,
    EspSkeletonMaxDist = 450,
    EspHeadCircle      = true,
    EspChams           = true,
    EspChamsFillTrans  = 0.72,
    EspChamsOutTrans   = 0.15,
    EspSmooth          = true,
    EspSmoothAlpha     = 0.5,
    EspVisibleCheck    = true,

    --[[ Цвета ESP раньше были зашиты в код (локалы COL_*), поэтому из меню
         ничего нельзя было перекрасить. Теперь они живут в CFG -> попадают
         в конфиг и в колорпикеры. ]]
    EspColorVisible    = Color3.fromRGB(70, 255, 90),
    EspColorHidden     = Color3.fromRGB(255, 55, 55),
    EspColorName       = Color3.fromRGB(235, 235, 245),
    EspColorDist       = Color3.fromRGB(235, 235, 245),
    EspColorWeapon     = Color3.fromRGB(255, 165, 60),
    EspNameUseTier     = true,   -- имя красится по видимости, а не своим цветом
    --[[ Обводки текста настройкой НЕТ СОЗНАТЕЛЬНО. Она включается один раз при
         создании объекта (esp_make_text) и выключаться не должна: без неё
         светлый текст ESP пропадает на снегу и на небе. Ключ EspTextOutline
         тут раньше лежал, но не читался нигде — удалён, чтобы не выглядеть
         настройкой, которая что-то меняет. ]]
    EspTextSize        = 14,
    -- Chams: по умолчанию наследует цвет видимости, но можно задать свой
    EspChamsOwnColor   = false,
    EspChamsColorVis   = Color3.fromRGB(70, 255, 90),
    EspChamsColorHid   = Color3.fromRGB(255, 55, 55),
    -- Skeleton / Head Circle: то же самое
    EspSkeletonOwnColor = false,
    EspSkeletonColor   = Color3.fromRGB(235, 235, 245),
    EspSkeletonThick   = 1,
    EspHeadCircleThick = 1,
    -- HP Bar: цвета краёв градиента (полное HP -> при смерти)
    EspHpHigh          = Color3.fromRGB(70, 255, 90),
    EspHpLow           = Color3.fromRGB(255, 55, 55),

    -- ── SILENT AIM ───────────────────────────────────────────────────
    SilentAim          = true,
    SilentAimFOV       = 120,           -- ПОЛНЫЙ конус (градусы)
    SilentAimMaxDist   = 600,
    AimBone            = "head",        -- "head" | "torso" | "auto"
    IgnoreTeammates    = true,
    SkipBlocked        = true,          -- не целиться в полностью закрытых
    --[[ Цена резолва = цели * направления * шаги * 2 луча. При 20 Гц и трёх
         целях выходило ~1200 raycast'ов в секунду — отсюда просадки. Теперь
         реже, и дорогой поиск идёт только пока не найден годный вариант. ]]
    AimResolveInterval = 0.09,          -- ~11 Гц

    --[[ ══ АНТИ-КИК «network tampering» ══════════════════════════════════
         SpoofOrigin  — подменять ли origin выстрела (сам эксплоит MultiPoint:
                        стрельба из точки, откуда цель видна). true = работает.
         OriginBudget — МАКСИМАЛЬНОЕ смещение origin от реального дула, студы.
                        Именно за перелёт этого бюджета сервер и кикал.
                        Направление спуфа сохраняется, длина подрезается.
                        4 студа ≈ правдоподобный вынос оружия/наклон.
                        Кикает — снижай (3 / 2); мало пробивает — поднимай
                        к MPMaxOffset (6). 0 = origin не подменять вообще.
         MaxSpoofAngle— ограничитель угла пули от честного LookVector, град.
                        0 = ВЫКЛ (нормальный silent aim). Включать только
                        если сервер начнёт валидировать угол. ]]
    SpoofOrigin        = true,
    OriginBudget       = 4.0,
    MaxSpoofAngle      = 0,

    --[[ ── MULTIPOINT (два фильтра) ──────────────────────────────────────
         ФИЛЬТР 1 ищет точку, откуда цель ВИДНА (приоритет).
         ФИЛЬТР 2 включается только если фильтр 1 пуст — ищет точку с
         МИНИМАЛЬНОЙ ценой пробития по формуле дв����ка (caster:193).
         Цена в лучах: фильтр 1 = о�� 3 (все направления глухие) до 3 + steps,
         потому что крайняя точка каждого направления проверяется ОДНИМ лучом
         и сразу отбрасывает бесполезное направление. ]]
    MultiPoint         = true,
    MPMaxOffset        = 6,
    MPBinarySteps      = 3,             -- шагов уточнения МИНИМАЛЬНОГО смещения
    MPPenProbes        = 2,             -- точек на направление для фильтра 2
    MPExtraDirs        = false,         -- true = +низ и 4 диагонали (дороже)
    MPTryOtherBone     = false,         -- true = пробовать вторую кость (дороже)
    MPCacheSec         = 0.8,
    MPDistScale        = 200,
    MPStickySec        = 0.35,
    MPMaxTargets       = 3,

    -- ── RESOLVER ─────────────────────────────────────────────────────
    -- В этой игре толком не нужен (хитбоксы простые, R6) — по умолчанию выкл,
    -- заодно экономит raycast'ы. Включай, если хочется добивать «выглядывающих».
    Resolver           = false,
    ResolverInset      = 0.08,

    -- ── ПРЕДИКТ (упреждение, которое ожидает сервер) ──────────────────
    Prediction          = true,
    PredictIterations   = 3,        -- итераций сходимости дистанция<->время
    PredictVertical     = false,    -- учитывать вер��икальную скорость цели
    PredictWind         = true,     -- компенсировать GlobalWind
    PredictMaxTime      = 1.2,      -- предел времени полёта (сек), 0 = без
    PredictFallbackSpeed = 900,     -- если не удалось прочитать патрон

    --[[ ── КОМПЕНСАЦИЯ ОТКАТА РЕПЛИКАЦИИ ────────────────────────────────
        ВОТ ПОЧЕМУ ПО БЫСТРЫМ ВРАГАМ НЕ ПРИНИМАЛО ПОПАДАНИЕ.
        Чужие модели рисуются НЕ в текущем положении, а в прошлом:
            ReplicationBuffer.get_position(t):
                v8 = t - SHARED_STATE.plr_replication_rollback_time_ms.value
            shared_state:140  plr_replication_rollback_time_ms = 190
        То есть всё, что мы видим (и куда наводимся), отстаёт на 190 мс.
        Для врага на 25 ст/с это 4.75 студа — шире торса, поэтому по бегущим
        заявка на попадание и отлетала, а по стоящим работала.

        Поэтому в общее время предикта добавляем откат: суммарный лид =
        время полёта пули + rollback. Значение читаем из самого SHARED_STATE,
        так что если разработчик его поменяет — подстроимся автоматически.
        Factor оставлен для подгонки: 1.0 = полная компенсация. Если начнёт
        перелетать вперёд по бегущим — снижай до 0.5. ]]
    PredictRollback       = true,
    PredictRollbackFactor = 1.0,

    --[[ Отсечка мусорных скоростей: респавн/телепорт дают гигантск��й рывок
         позиции, из которого получается бессмысленный лид. ]]
    PredictMaxTargetSpeed = 120,

    --[[ ── ПРОБИТИЕ (по бюджету патрона, а не по студам) ──────────────────
         Порог больше не задаётся в студах: движок сравнивает
             cost = толщина / penetration_modifiers.penetration[Material]
         с бюджетом
             bullet_penetration_ability * plr_penetration_multiplier
         (caster:148/193/209). Бюджет читается у РЕАЛЬНОГО патрона в стволе,
         поэтому подстраивается под оружие сам.
         BudgetUse — какую долю бюджета разрешаем тратить. < 1 нужно потому,
         что движок накапливает cost по всем преградам на пути (caster:212),
         а мы меряем участок одним замером: запас гасит эту разницу. ]]
    AllowPenetrable        = true,
    PenetrationBudgetUse   = 0.85,

    -- ── FORCE HIT ────────────────────────────────────────────────────
    ForceHit           = true,
    ForceHitPart       = "auto",        -- "auto" = наведённая кость, иначе имя части
    ForceHitDelay      = 0.03,

    -- ── ЛОКАЛЬНЫЙ ВИЗУАЛ СПУФА ───────────────────────────────────────
    -- OFF: MultiPoint работает на уровне пакета; локальную пулю не трогаем
    SpoofLocalVisual   = false,

    -- Бэктрек убран: сервер не засчитывал попадания по прошлым тикам,
    -- поэтому и прицеливание, и визуализация призрака удалены целиком.
    ClientRollbackMs   = nil,           -- nil = не трогать; 0 = видеть врага «сейчас»

    -- ── ВИЗУАЛЫ ──────────────────────────────────────────────────────
    FovCircle          = true,
    FovCircleColor     = Color3.fromRGB(255, 255, 255),
    FovCircleThick     = 1,
    FovCircleFilled    = false,
    FovCircleTrans     = 0.6,

    MuzzleVisual       = true,
    MuzzleLineColor    = Color3.fromRGB(80, 220, 255),
    MuzzleLineThick    = 2.0,
    MuzzleLineTrans    = 0.15,

    ShotTracers        = true,
    --[[ ── ИНДИКАТОР СОСТОЯНИЯ (HUD) ─────────────────────────────────────
        Все значения читаются из fp_controller и его сборки оружия — ровно
        оттуда же, откуда их берёт игровой интерфейс:
            патроны   weapon.ammo.rounds_in_magazine (+1 если в пат��������������������о����������нике)
                      MagazineStats:115 формирует свою строку так же
            ёмкость   weapon.build.result.stats.magazine_capacity
                      (count_stats:184 — mag_space / shell_size)
            здоровье  ctrl.health, максимум SHARED_STATE.plr_initial_health
            стамина   ctrl.stamina / plr_max_stamina
            руки      ctrl.arm_stamina / plr_max_arm_stamina (дрожь прицела)
            адреналин ctrl.adrenaline
        Ничего не угадано и не захардкожено: максимумы сервер меняет на ходу,
        поэтому они тоже читаются, а не вписаны числами. ]]
    Hud                = false,
    HudScale           = 1.0,
    -- по умолчанию правее и ниже (просьба): панель уходит из зоны, где
    -- игровой интерфейс держит свои подсказки в левой части экрана
    HudX               = 96,
    HudY               = 420,
    --[[ ПРИВЯЗКА. "Muzzle" держит панель рядом с реальным дулом (тем же
         muzzle_cframe, что и прицел по дулу), "Fixed" — в точке HudX/HudY.
         По умолчанию панель висит справа от дула: там она читается краем
         глаза, не перекрывая ни центр экрана, ни сам ствол.
         Если оружия нет (пустые руки, респавн, смена предмета), дула тоже
         нет — тогда автоматически используется Fixed-позиция, иначе панель
         просто исчезала бы в самые нужные моменты. ]]
    HudAnchor          = "Muzzle",  -- "Muzzle" | "Fixed"
    HudMuzzleSide      = "Right",   -- "Right" | "Left"
    -- правее и ниже дула, чем было (34/0): панель больше не наезжает на ствол
    HudMuzzleOffX      = 72,        -- отступ от дула по горизонтали, px
    HudMuzzleOffY      = 56,        -- сдвиг по вертикали от центра панели, px
    HudAmmo            = true,
    HudHealth          = true,
    HudStamina         = true,
    HudArms            = false,
    HudAdrenaline      = false,
    --[[ FPS и PING УДАЛЕНЫ. Это не «выключено по умолчанию», а убрано вместе с
         кодом: счётчика кадров и опроса Stats в скрипте больше нет. ]]
    HudSpeed           = false,
    HudBars            = true,      -- полоски рядом со числами
    HudAccent          = Color3.fromRGB(255, 90, 35),
    HudBg              = Color3.fromRGB(10, 11, 13),
    HudText            = Color3.fromRGB(236, 238, 242),
    HudDim             = Color3.fromRGB(128, 134, 145),
    --[[ ГРАДИЕНТ. У Drawing.Square нет заливки градиентом — свойство одно,
         Color. Поэтому градиент собирается из полос: панель и акцентная
         полоса рисуются HS.bands прямоугольниками с перетеканием цвета
         от HudBg/HudAccent к HudBg2/HudAccent2. Полосы лежат в том же пуле,
         что и остальные объекты, так что за кадр ничего не создаётся.
         Выключенный градиент рисует ОДНУ полосу — то есть ровно то же
         количество объектов, что было до градиента. ]]
    HudGradient        = true,
    HudBg2             = Color3.fromRGB(24, 18, 16),
    HudAccent2         = Color3.fromRGB(255, 186, 64),
    --[[ АНИМАЦИИ. Сглаживаются только полоски заполнения и появление панели.
         ЧИСЛА НЕ СГЛАЖИВАЮТСЯ СОЗНАТЕЛЬНО: интерполяция счётчика патронов
         показывала бы 29 там, где в магазине уже 30, — то есть врала бы ровно
         в том, ради чего этот индикатор и нужен. ]]
    HudAnim            = true,
    HudAnimSpeed       = 12,        -- скорость подтягивания, 1..30
    --[[ ПЕРЕТАСКИВАНИЕ. Пока HudMove включён, панель берётся мышью. Режим
         явный, потому что состояние курсора в этой игре ненадёжно — подробности
         в комментарии к hud_update_drag. Выключенный режим = ЛКМ снова только
         стрельба, поэтому отдельного «Draggable» больше нет: он всегда стоял в
         true и лишь дублировал этот переключатель. ]]
    HudMove            = false,

    --[[ ── MUZZLE CROSSHAIR ───────────────────────────────────────────────
        Прицел ставится не в центр экрана, а в точку перед РЕАЛЬНЫМ дулом:
        ctrl.weapon.viewmodel.receiver.barrel (у нас уже есть muzzle_cframe).
        Смысл — видеть, откуда именно пойдёт пуля: в игре ствол смещён от
        центра экрана, и у стены/угла пуля уходит не туда, куда центр. ]]
    MuzzleCross        = false,
    MuzzleCrossDist    = 6,         -- на сколько метров вперёд от дула
    MuzzleCrossSize    = 5,         -- длина штриха, px
    MuzzleCrossGap     = 3,         -- отступ от центра, px
    MuzzleCrossDot     = true,
    MuzzleCrossColor   = Color3.fromRGB(120, 255, 170),
    MuzzleCrossThick   = 1.5,
    --[[ ВРАЩЕНИЕ. Крутятся ТОЛЬКО штрихи — центральная точка остаётся на
         месте. Она отмечает точку выхода пули, и если бы вращалась она,
         прицел перестал бы показывать то единственное, зачем нужен: куда
         именно уйдёт выстрел. Точка лежит в центре вращения, так что
         вращать её и незачем — визуально это ничего не меняет. ]]
    MuzzleCrossSpin    = false,
    MuzzleCrossSpinSpd = 90,        -- градусов в секунду, может быть отрицательной

    TracerColor        = Color3.fromRGB(255, 90, 35),
    TracerDuration     = 1.4,
    TracerFadeIn       = 0.12,
    TracerThickness    = 0.9,

    AimVisuals         = true,
    AimVisualStyle     = "Diamond",     -- "Default" | "CrossGap" | "DefaultV2" | "Diamond"
    AimVisualScale     = 1.0,
    AimVisualColor     = nil,           -- nil = цвет по тиру

    HitParticles       = true,
    HitParticleType    = "Wireframe",   -- "Wireframe" | "Orbs" | "Sparks"
    HitParticleCount   = 18,
    HitParticleDur     = 1.1,
    HitParticleGrav    = -32,
    HitParticleSpdMin  = 2,
    HitParticleSpdMax  = 32,
    HitParticleColorA  = Color3.fromRGB(88, 165, 255),
    HitParticleColorB  = Color3.fromRGB(165, 95, 255),
    HitParticleOpMin   = 0.45,
    HitParticleOpMax   = 1.0,
    HitParticleWireS   = 0.4,
    HitParticleMaxSys  = 4,

    HitSound           = true,
    --[[ ПРЕСЕТЫ. HitSoundId остаётся источником истины — пре��������������ет просто
         записывает в него свой id. "Custom" нич��го не ��иш��т, поэ��ом��
         вручную вв��дённый id не затирается при перезагрузке конфига. ]]
    HitSoundPreset     = "Fatality",
    HitSoundId         = 115982072912004,
    --[[ ПОЧЕМУ БЫЛО ТИХО. Я сам зажимал громкость в clamp(v, 0, 1), тогда как
         у Roblox Sound.Volume диапазон 0..10 (ползунок в студии кончается на
         1, но свойство принимае������ ���о 10). То есть звук играл на максимуме моего
         же искусственного потолка. Теперь потолок настоящий. ]]
    HitSoundVolume     = 3.5,       -- 0..10
    HitSoundPitch      = 1.0,

    -- ── WEAPON MODS ──────────────────────────────────────────────────
    NoRecoil           = true,
    --[[ Доля ОСТАВШЕЙСЯ отдачи по осям, 0..1. 0 = оси нет вообще, 1 = как в
         игре. Оба нуля = отдачи нет совсем (прежнее поведение NoRecoil). ]]
    RecoilVertical     = 0,
    RecoilHorizontal   = 0,
    --[[ ТРЯСКА КАМЕРЫ — отдельная ось. Пружины camera_recoil /
         camera_lag_recoil / rotation_recoil / roll_recoil не подчиняются
         plr_recoil, поэтому раньше камеру трясло даже при нулевой отдаче. ]]
    RecoilCamera       = 0,
    NoSpread           = true,
    NoSway             = true,
    FullAuto           = true,

    --[[ ── INFINITE ARM STAMINA ─────────────────────────────────────────
        Что это вообще такое. arm_stamina — выносливость рук, она тратится
        при прицеливании (FPC:1747) и от задержки дыхания (FPC:1750), а ещё
        разово срезается, когда по тебе стреля��т (FPC.suppress:797).
        Трат��тся она ��А КЛИЕНТЕ: и сли��, и реген, и clamp живут в heartbeat
        локального контроллера (FPC:1722-1770), сервер это поле не видит.

        Зачем. Единственный реальный потребитель — амплитуда дрожи прицела:
        rifle_methods:1855 считает v219 = arm_stamina / max и раздувает вес
        анимации univ_breathing на (1 - v219) * 5. При полной выносливости
        множитель ровно ноль, то есть дрожи нет. Второй эффект: hold_breath
        (FPC:574) отказывается работать при arm_stamina <= 0.1 и сам
        сбрасывается на FPC:1774 — с этим модом задержка дыхания больше не
        обрывается.

        Побочный э��фект, который НЕ баг: игра сама скрывает полосу
        выносливости рук, когда она полна (FPC_extend:491 сравнивает
        значение с max - 0.15). Полоса просто исчезнет — это штатное
        поведение игры при полных руках, а не поломка.

        Почему это НЕ в apply_mods. Тот цикл ходит раз в ModsInterval, то
        есть раз в 2 секунды, а слив — до 3 единиц в секунду при максимуме
        60. За один интервал руки просаживались бы на 10%, и дрожь успевала
        бы вернуться. Поэтому значение восстанавливается каждый кадр. ]]
    InfArmStamina      = false,

    --[[ ── INSTANT EQUIP ────────────────────────────────────────────────
        Задержка смены оружия — это АНИМАЦИЯ, а не таймер. BaseItem:317
        play_track берёт скорость из get_animation_speed(name), а
        FPC:1276 блокирует действия, пока tracks.unequip.playing. Значит
        достаточно вернуть огромную скорость для треков смены — трек
        доигрывает за кадр, блокировка снимается сразу.
        Это ЛОКАЛЬНО: скорострельность не растёт, сервер о треках не знает. ]]
    InstantEquip       = true,
    EquipSpeed         = 12,        -- множитель скорости equip/unequip

    --[[ ── INSTANT AIM ───────────────────────────────────────────────────
        Прицеливание — это SlerpValue state_lerps.final_aim (FPC:233), а
        get_lerp("final_aim") (FPC:783) возвращает его .current. У SlerpValue
        есть :force(value) — мгновенная установка без интерполяции (FPC:1378
        сама игра так и делает для idle). Каждый кадр форсим лерп в 1 при
        прицеливании и в 0 при отпускании. ]]
    InstantAim         = true,
    --[[ Форсить ли и выход из прицела. Выключи, если резкий выход мешает
         визуально: тогда мгновенным будет только вход. ]]
    InstantAimOut      = true,

    --[[ ── VIEWMODEL / GUNMODEL ─────────────────────���────────────────────
        Красим то, что видим от первого лица. Структура рига взята из дампа
        (BaseItem:103 prepare_rig + SharedPlayerRigLogic:14 connect_weapon):

            weapon.viewmodel            Model в Workspace.ignore
              ├── receiver              КОРЕНЬ ОРУЖИЯ (+ все его потомки)
              ├── left / right          РУКИ (одежда/перчатки — их потомки)
              ├── root_part, *_marker   невидимая служебка, не трогаем

        Поэтому «руки» и «оружие» — это два разных поддерева одной модели, и
        разделяем мы их по принадлежности к receiver, а не ��о именам частей.

        Всё это ЧИСТО ЛОКАЛЬНО: viewmodel существует только у нас, другие
        игроки видят свой риг. Античит (список в deadlineVision) свойства
        частей вьюмодели не проверяет. ]]
    VmEnabled          = false,
    VmColorEnabled     = true,
    VmColor            = Color3.fromRGB(0, 200, 255),
    VmMaterialEnabled  = false,
    VmMaterial         = "ForceField",
    VmTransparency     = 0,             -- 0 = как в игре

    --[[ ── CUSTOM FOV РУК (ВЬЮМОДЕЛИ) ──────────────────────────────────���──
        У игры ОДНА камера: FirstPersonController р��нд��рит вьюмодель в мировом
        пространстве (viewmodel_world_space, FPC:473/1446), поэтому отдельного
        FieldOfView у рук в д��ижке НЕТ. «FOV рук» эмулируем масштабом смещения
        вьюмодели от камеры в поздней BindToRenderStep (после апдейта игры):
            rel = cam:ToObjectSpace(vmPivot);  vm:PivotTo(cam * scaled(rel))
        Коэффициент из желаемого FOV: k = tan(baseFov/2) / tan(VmFOV/2). Ниже
        VmFOV -> руки визуально «приближаются» (как узкий объектив), выше ->
        отодвигаются. Всё локально: вьюмодель есть только у нас, АЦ её не
        проверяет (список проверок в deadlineVision). ]]
    VmFOVEnabled       = false,
    VmFOV              = 70,            -- целевой «FOV рук»

    GunEnabled         = false,
    GunColorEnabled    = true,
    GunColor           = Color3.fromRGB(0, 170, 255),
    GunMaterialEnabled = false,
    GunMaterial        = "ForceField",
    GunTransparency    = 0,

    --[[ Г��АДИЕНТ — плавный перелив между ДВУМЯ цветами (не радуга).
         Треугольная волна A→B→A, поэтому на стыке цикла нет скачка.
         Spread растягивает волну по частям оружия: 0 = все синхронно. ]]
    VmGradient         = false,
    GunGradient        = false,
    GradientSpeed      = 0.35,          -- циклов A⇆B в секунду
    GradientColorA     = Color3.fromRGB(190, 150, 255),
    GradientColorB     = Color3.fromRGB(120, 210, 255),
    GunGradientSpread  = 1.6,

    --[[ ── ГРАНАТЫ (таймер + предсказание траектории) ────────────────────
        Гранаты — это сущности jecs с grenade_projectile_component
        (ClientGrenadeProjectile:18). Внутри лежит ровно то, что нужно:

            segment.origin / velocity / start_time   парабола текущего отрезка
            physics.radius / restitution / friction  параметры отскока
            motion.settled / rolling / bounces       состояние
            properties.firing.fuse_time / fuse_type  запал
            thrower_ingame_id                        кто бросил

        Движение честно считается формулой из движка (grenade_step:105):
            pos(t) = origin + v*t + (gravity + wind*0.5) * t^2 / 2
        Поэтому предсказание совпадает с реальным полётом, а не «примерно
        похоже»: те же коэффициенты, тот же restitution на отскоке.

        fuse_type == "delayed" -> взрыв по таймеру от броска;
        "contact"/"impact"     -> по касанию, там таймер бессмысленен. ]]
    Grenades           = true,
    GrenadeEnemyOnly   = false,     -- свои тоже полезно видеть
    GrenadeMaxDist     = 400,
    --[[ ── ЗНАЧОК ГРАНАТЫ: ФОН + ИКОНКА + ДУГА ЗАПАЛА ─────────────────────
        Круглый значок вместо текста «1.4s 37m»: цифры надо считать, а в бою
        нужен один взгляд. Залитый фон, иконка гранаты в центре и дуга по краю
        как круговой индикатор запала — полная дуга = полный запал, цвет едет от
        зелёного к красному.

        ИКОНКА: настоящая картинка по assetid, силуэт из линий — только запас.
        Прошлый вывод «иконки быть не могло» был неверным. Разбор причины и
        рабочая загрузка — в image_bytes(); коротко: Drawing.Image.Data хочет
        байты файла, а assetdelivery отдаёт их лишь с клиентским User-Agent,
        которого я раньше не ставил.

        GrenadeIconAsset — id картинки. Силуэта-из-линий больше нет: пока байты
        не пришли (или id пустой/битый), значок рисует только фон + дугу запала.

        Толщина дуги, число её сегментов и заливка фона были настройками — это
        визуальный шум, которым нельзя улучшить результат, только испортить.
        Теперь константы GRN_* ниже. ]]
    GrenadeMarker      = true,
    --[[ Настоящая иконка гранаты (rbxassetid). Drawing.Image.Data хочет СЫРЫЕ
         байты PNG, не ссылку — их тянет image_bytes() через assetdelivery с
         User-Agent Roblox/WinInet. Силуэт-из-линий убран полностью: если байты
         не пришли, значок рисуется без иконки (только фон + дуга запала). ]]
    GrenadeIconAsset   = "85012617711318",
    GrenadeMarkerSize  = 15,        -- радиус значка в пикселях
    GrenadeFuseFull    = Color3.fromRGB(80, 235, 130),
    GrenadeFuseLow     = Color3.fromRGB(255, 60, 45),

    GrenadePath        = true,      -- предсказание полёта
    GrenadePathBounces = 3,         -- сколько отскоков считать
    --[[ Лимит длины траектории. Симуляция раньше жила только по числу шагов, а
         значит её стоимость зависела от скорости гранаты, а не от того, сколько
         реально полезно видеть. Ограничение по пройденному пути одновременно и
         предсказуемо по цене, и убирает бессмысленно длинные дуги. ]]
    GrenadePathMaxDist = 200,

    --[[ ── ТРАЕКТОРИЯ БРОСКА, ПОКА ГРАНАТА В РУКАХ ────────────────────────
        Раньше траектория появлялась только ПОСЛЕ броска, то есть когда решение
        уже принято. Бросок считается на клиенте и целиком читается из дампа
        (throwable_methods:230-231):
            origin = clamp_throw_origin(cam.Position, receiver.Position, props)
            dir    = CFrame.new(origin, cam.Position + cam.LookVector*40).LookVector
            speed  = (сильный and 75 or 40) * plr_grenade_throw_strength
        Подставляем это в ту же симуляцию, что и для летящих гранат, и получаем
        точную линию до броска. Считается только пока в руках метательное. ]]
    GrenadeAim         = true,
    GrenadeAimWeak     = true,      -- втор��й линией слабый бросок (40 против 75)
    GrenadeAimColor    = Color3.fromRGB(120, 255, 170),
    GrenadeAimWeakColor = Color3.fromRGB(255, 200, 90),
    GrenadeColorMine   = Color3.fromRGB(90, 200, 255),
    GrenadeColorEnemy  = Color3.fromRGB(255, 80, 60),

    -- ── ВН��ТРЕННЕЕ ───────────────────────────────────────────────────
    -- теперь это дешёвое чтение таблиц dl_replicator, а не обход GC
    MetaRefresh        = 0.5,
    ModsInterval       = 2.0,
    VisCacheTtl        = 0.12,
}
DL.config = CFG

--======================================================================
--  ПЕРСИСТЕНТНОСТЬ НАСТРОЕК — НЕ ЗДЕСЬ
--======================================================================
--[[
    УДАЛЕНО ОСОЗНАННО. Раньше здесь жила таблица Persist: она писала весь CFG
    в syllinse/deadline_sa.json при КАЖДОМ изменении (дебаунс 1.5 с) и читала
    файл при загрузке модуля.

    Именно она и была причиной жалобы «какого хуя н����стройки сохраняются, даже
    если я не загружал никакого конфига». ForceAutoLoad тут не при чём — во всём
    модуле он не выставлен ни на од��ом элементе; персистентность делал этот
    самодельный автосейв, работавший ВСЕГДА и молча.

    Теперь сохранением владеет ТОЛЬКО загрузчик, через штатную config-систему
    MacLib: MacLib:SetFolder(...), tab:InsertConfigSection() и
    MacLib:LoadAutoLoadConfig() (loaderv9: 693, 1340, 1342). То есть ��астройки
    переносятся между сессиями исключительно ��огда, к��гда ты сам нажал Save и
    Load. Ничего не пишется за твоей спиной.

    Единственное, что осталось от той системы, — то, что каждый UI-элемент
    берёт Default из ТЕКУЩЕГО значения CFG (Get = ...), а не из зашитой
    константы. Это нужно, чтобы LoadConfig и повторное построение UI не
    затирали значения дефолтами, и никакой записи на диск не делает.
--]]

--======================================================================
--  ОФОРМЛЕНИЕ (константы BRM5ESP)
--======================================================================
--[[ K — общий namespace для редко используемых констант.
     Пр��чина та же, что и у ESPC ниже: тело скрипта — это одна функция, а у
     Luau лимит 200 локалов на функцию. Скрипт стоял ровно на 200, из-за чего
     любое добавление падало с "Out of local registers". Тринадцать таблиц
     (POSE_NAME, WEAPON_SHORT, HIT_PART_*, SWAY_*, MATERIALS, HIT_SOUND_* и др.)
     обращались к себе по 1-2 раза, поэтому держать под каждую отдельный
     регистр было расточительно — теперь это поля K, а лишний hash-lookup
     в таких местах ничего не стоит.
     ESPC ОСТАВЛЕН отдельн��м локалом сознательно: к нему обращаются в цикле
     отрисовки на каждую сущность каждый кадр. ]]
local K = {}
--[[ Геометрия ESP: одна таблица вместо 8 локалов (лимит 200 регистров).
     Цвета отсюда УБРАНЫ — теперь они в CFG, иначе их нельзя было менять
     из меню. Размер текста тоже читается из CFG (ESPC.LabelSize оставлен
     как фолбэк для кода, который вызывается до применения конфига). ]]
local ESPC = {
    LabelSize = 14,
    LineStep  = 0.52,
    StackGap  = 3,
    ChipGap   = 2,
    --[[ Один общий пустой список на весь скрипт — для случая «состояний нет».
         Раньше в этой ветке писалось `or {}`, то есть пустая таблица
         создавалась на каждую сущность каждый кадр только чтобы у неё сразу
         же спросили длину. Читатели (#st и ipairs) её не меняют, поэтому
         общий экземпляр безопасен. МЕНЯТЬ ЕГО НЕЛЬЗЯ. ]]
    EMPTY     = {},
}

-- цвет чипа состояния по категории
K.CHIP_COLOR = {
    fire   = Color3.fromRGB(255, 70, 70),
    aim    = Color3.fromRGB(255, 210, 90),
    reload = Color3.fromRGB(255, 160, 45),
    run    = Color3.fromRGB(90, 200, 255),
    walk   = Color3.fromRGB(90, 200, 255),
    crouch = Color3.fromRGB(190, 170, 255),
    prone  = Color3.fromRGB(190, 170, 255),
    idle   = Color3.fromRGB(150, 150, 165),
    nvg    = Color3.fromRGB(170, 255, 150),
}

K.POSE_NAME = { [1] = "idle", [2] = "prone", [3] = "crouch", [4] = "run" }
K.TIER_WEIGHT = { [0] = 0, [1] = 750, [2] = 2100, [3] = 3800 }

--======================================================================
--  SERVICES / ЛОКАЛИ
--======================================================================
--[[ БЮДЖЕТ РЕГИСТРОВ. У Luau лимит 200 локалов на функцию, и тело скрипта —
     это одна функция, поэтому каждый локал верхнего уровня расходует общий
     бюджет. Отсюда убраны имена, которые его тратили впустую:
       • R6_PARTS, sqrt — не использовались нигде;
       • SoundSvc — упоминался только в комментарии, звук идёт через
         RawSoundService (cloneref-прокси как раз и ломал воспроизведение);
       • Players, RunService — по одному обращению, не в горячем пути,
         поэтому подставлены по месту, а не держатся в алиасе.
     Алиасы вида floor/min/max/V3 оставлены: они в горячих циклах. ]]
local RS          = cloneref and cloneref(game:GetService("ReplicatedStorage")) or game:GetService("ReplicatedStorage")
local Debris      = game:GetService("Debris")
--[[ Нужен только для перетаскивания HUD: положение курсора и состояние ЛКМ.
     Через cloneref, как и остальные сервисы, чтобы не отдавать анти-читу
     ссылку на наш экземпляр. ]]
local UIS         = cloneref and cloneref(game:GetService("UserInputService"))
    or game:GetService("UserInputService")
local Workspace   = cloneref and cloneref(workspace) or workspace
local LocalPlayer = (cloneref and cloneref(game:GetService("Players"))
    or game:GetService("Players")).LocalPlayer

local clock = os.clock
local floor = math.floor
local abs   = math.abs
local min   = math.min
local max   = math.max
local clamp = math.clamp
local rad   = math.rad
local deg   = math.deg
local tan   = math.tan
local sin   = math.sin
local cos   = math.cos
local acos  = math.acos
local pi    = math.pi
local rnd   = math.random
local V2    = Vector2.new
local V3    = Vector3.new
local CF    = CFrame.new
local ZERO3 = V3()

local running = true
local conns = {}

--[[ ── ДИАГНОСТИКА (ВРЕМЕННАЯ) ─────────────────────────────────────────────
     Печатает в консоль исполнителя, почему падают три фичи (таймер гранаты,
     траектория, custom fov). Throttled по ключу, чтобы не спамить 60 раз/сек.
     Фо��мат строки: [dlsa:<tag>] <msg>. Удалю, как только фичи заработают.

     ВАЖНО: объявлены как ГЛОБАЛЫ, а НЕ local. Файл упирается в лимит Luau в 200
     локальных регистров на область (ошибка "Out of local registers" на hud_ammo).
     Эти хелперы живут в верхней области и держали бы 7 регистров до самого низа
     — глобалы не занимают ни одного. Имена оставлены прежними, чтобы все места
     вызова (dfov/dgren/daim/diag/diag1) резолвились без правок. ]]
DLSA_DIAG = true
_dlsaDiagLast = {}
function diag(tag, msg)
    if not DLSA_DIAG then return end
    --[[ Троттлинг ПО ПОЛНОМУ ТЕКСТУ (tag+msg), а не по одному tag. Прошлый
         вариант глушил все сообщения одного тега кроме первого за секунду:
         "holding throwable OK" печаталось и прятало следующий за ним реальный
         сбой ("held_weapon nil"/"handPos nil"/...). Теперь каждое РАЗНОЕ
         состояние печатается раз в секунду независимо. ]]
    local key = tag .. "\0" .. msg
    local t = os.clock()
    if (t - (_dlsaDiagLast[key] or 0)) < 1 then return end
    _dlsaDiagLast[key] = t
    print("[dlsa:" .. tag .. "] " .. tostring(msg))
end
function dfov(msg) diag("fov", msg) end
function dgren(msg) diag("gren", msg) end
function daim(msg) diag("aim", msg) end
-- одноразовый лог без throttle — для редких событий (установка хука и т.п.)
function diag1(tag, msg)
    if not DLSA_DIAG then return end
    print("[dlsa:" .. tag .. "] " .. tostring(msg))
end

--[[ FORWARD-ДЕКЛАРАЦИИ. Обязаны стоять ЗДЕСЬ, выше кадрового цикла.
     В Lua имя видно только НИЖЕ своего `local`, а ссылка выше молча становится
     о��раще��ием к глобалу. Раньше эти пять имён объявлялись рядом со своими
     реализациями (строк�� 4200+), то есть НИЖЕ кадрового цикла, который их
     вызывает. Из-за этого `apply_instant_aim()` в цикле читал глобал = nil и
     падал с "attempt to call a nil value" на первом же кадре, унося с собой
     весь тик: ESP, viewmodel, gunmodel и остальное после него не выполнялись.
     `apply_rig_style` был обёрнут в pcall, а `update_grenades` — в проверку
     `if update_grenades then`, поэтому они не падали, а просто никогда не
     работали — то же самое, только молча.
     Объявление здесь делает их апвэлами: и цикл, и присваивания ниже теперь
     видят одну и ту же переменную. Регистров это не добавляет — имена лишь
     переехали, а строки `local ...` у реализаций удалены. ]]
local apply_rig_style, apply_instant_aim, hook_equip_speed
--[[ apply_arm_stamina тоже ЗДЕСЬ, а не рядом со своей реализацией: она нужна
     кадровому ц��клу, а реализация лежит ниже него. Глобалом её оставлять
     не��ьзя — это ровно тот случай, что описан выше, п��юс скрипт сам чистит
     чужие глобалы (genvKilled). ]]
local apply_arm_stamina
local update_grenades, clear_grenades
local update_grenade_aim, clear_grenade_aim
--[[ HUD и прицел по дулу живут в собственной области видимости (do ... end
     ниже): в Luau на функцию приходится не больше 200 локальных регистров, и
     их внутренние переменные этот лимит на уровне файла уже переполняли.
     Наружу выходят только эти четыре имени. ]]
local update_hud, hud_free
local update_muzzle_cross, muzzle_cross_free

--======================================================================
--  СТРАХОВКА ОТ ЛОВУШЕК getenv  (обяз��тельна именно для это��о скрипта)
--======================================================================
--[[
    В игре три функции-ловушки с одинаковой начинкой (все с константой
    "kill yourself", поэтому наход��тся одним filtergc):

      module/namespace/NetworkEncode:12   getenv()  for i = 0, 9
          вызывается из write_exact_position, write_time, write_pose,
          compress_position, compress_velocity
      module/caster/caster:404            getenv()  for i = 1, 10
      module/util/lua/util:10             getenv()  for i = 1, 10
          НО с предохранителем: if math.random(1,100) ~= 100 then return end
          -> срабатывает 1 раз из 100, вызывается из map_clamped и copy_table

    Каждая обходит pcall(getfenv, i) по уровням стека и, если в чьём-то
    окружении есть rconsoleprint, делает:
        loading_status:FireServer("_genv")   -- доклад серверу
        rconsoleprint("kill yourself")
        while true do end                    -- вешает п��ток

    П��чему это критично ИМЕННО здесь: мы хукаем write_exact_position и функции
    caster'а. Когда игра их вызывает, НАШ хук лежит на стеке — и getfenv
    наход��т окру��ение экзекутора. Вероятностный вариант из util объясняет
    «иногда всё ломается без причины»: 1% на каждое сжатие позиции.

    deadline_bypass делает то же самое, но suite обязан быть самодостаточным:
    если обход не загружен или загружен позже, мы всё равно не подставляемся.
--]]
--[[
    ИДЕМПОТЕНТНОСТЬ — ВАЖНО.
    Обход и каждый из скриптов раньше ��укали ОДНИ И ТЕ ЖЕ три за��ыкания getenv.
    Получалось до четырёх слоёв hookfunction на функциях, ��оторые вызываются из
    самого горячего пути (write_time / compress_position / map_clamped) — лишний
    риск на пустом месте. Ставим общий маркер в getgenv(): кто первый пришёл,
    тот и глушит, остальные только читают результат.
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
    -- второй слой (дешёвый, можно и повторно): убираем то, за ч��о цепляется л��вушка
    for _, envGetter in ipairs({ getgenv, getrenv }) do
        pcall(function()
            local env = envGetter and envGetter()
            if type(env) == "table" and rawget(env, "rconsoleprint") ~= nil then
                rawset(env, "rconsoleprint", nil)
            end
        end)
    end
end

--[[
    SHARED_STATE читают и предикт (plr_replication_rollback_time_ms), и weapon
    mods (plr_recoil �� т.д.), поэтому забираем его сразу — иначе внутри
    predict_point ссылка была бы глобальной и всегда nil.
--]]
local SHARED
pcall(function()
    SHARED = require(RS.module.shared_state).SHARED_STATE
end)

--======================================================================
--  СОКРАЩЕНИЯ ИМЁН ОРУЖИЯ
--======================================================================
K.WEAPON_SHORT = {
    ["Kazarov Group AK-12"]          = "AK-12",
    ["Kazarov Group AK-308"]         = "AK-308",
    ["Kazarov Group AK 5.45 Carbine"]= "AK5.45C",
    ["Kazarov Group AK 5.45"]        = "AK-5.45",
    ["Kazarov Group AK 7.62"]        = "AK-7.62",
    ["Kazarov Group PP-19-01"]       = "PP-19",
    ["Kazarov Type 1"]               = "AKM-1",
    ["Kazarov Type 2"]               = "AKM-2",
    ["Löwenherz AUG A3"]             = "AUG-A3",
    ["Whitner Defense EDC X9"]       = "EDC-X9",
    ["KF KG-31"]                     = "KG-31",
    ["KF 416"]                       = "KF416",
    ["KF MPi-54"]                    = "MP5",
    ["KF UMC-45"]                    = "UMP-45",
    ["M11 EOD"]                      = "M11",
    ["AR-15"]                        = "AR-15",
    ["AR-9"]                         = "AR-9",
    ["Ladoga MP133"]                 = "MP133",
    ["Pistolet Makarova"]            = "PM",
    ["Mosin Nagant M91/30 PU"]       = "MOSIN",
    ["Sic Stürmer P320"]             = "P320",
    ["Sanxian QBZ-95"]               = "QBZ-95",
    ["Roosevelt M700"]               = "M700",
    ["Roosevelt M870 Express"]       = "M870",
    ["RSA SG-58"]                    = "SG-58",
    ["HILT Defense MK-76"]           = "MK-76",
    ["AFT MK-17"]                    = "MK-17",
    ["AFT MK-16"]                    = "MK-16",
    ["Tokarev TT-33"]                = "TT-33",
    ["KALIS Scalar Gen II"]          = "VECTOR",
    ["M9 Bayonet"]                   = "M9",
    ["RPG-7"]                        = "RPG-7",
}
K.WEAPON_VENDORS = {
    "Kazarov Group", "Kazarov", "Whitner Defense", "HILT Defense", "Löwenherz",
    "Sic Stürmer", "Roosevelt", "Sanxian", "Ladoga", "Tokarev", "KALIS", "RSA", "AFT", "KF",
}
local weaponShortCache = {}

local function short_weapon(fullName)
    if not fullName then
        return nil
    end
    local cached = weaponShortCache[fullName]
    if cached then
        return cached
    end
    local result = K.WEAPON_SHORT[fullName]
    if not result then
        result = fullName
        for _, vendor in ipairs(K.WEAPON_VENDORS) do
            if result:sub(1, #vendor) == vendor then
                result = result:sub(#vendor + 2)
                break
            end
        end
        result = result:gsub("^%s+", ""):upper()
        if #result > 9 then
            result = result:sub(1, 9)
        end
    end
    weaponShortCache[fullName] = result
    return result
end

--======================================================================
--  МЕТАДАННЫЕ ИГРОКОВ  (реестр мёржится, не пересобирается -> нет миганий)
--======================================================================
local entByModel   = {}   -- [characterModel] = entity
local entByIngame  = {}   -- [tostring(ingame_id)] = entity
local ctrl                -- локальный fp_controller
local framework           -- ClientFramework (синглтон, ��ивёт через ��мерти)
local myCharacter         -- НАША модель; LocalPlayer.Character здесь в��егда nil
local ignoreDirty = true  -- пересобрать список исключений для лучей
local ent_count = 0

--[[
    ДЕШЁВОЕ ОБНОВЛЕНИЕ «КТО МЫ» — вызывается КАЖДЫЙ КАДР.
    Раньше и сущности, и наш контроллер обновлялись одним filtergc раз в
    MetaRefresh (1 сек). Из-за этого после респавна до целой секунды работали
    мёртвые ctrl/myCharacter: muzzle-трейсер уходил не оттуда, лучи не
    исключали наше тело, моды не переставлялись. Теперь framework ищется один
    раз, а живое тело читается прямым rawget — это бесплатно, поэтому делаем
    каждый кадр. Дорогой filtergc сущносте�� остался в refresh_meta.
--]]
--[[
    КРИТИЧНО: ПОИСК framework ОБЯЗАН БЫТЬ ЗАДРОССЕЛИРОВАН.
    ЭТО БЫЛА ПРИЧИНА КРАША ИГРЫ. refresh_local зовётся КАЖДЫЙ ����АДР, и в первой
    версии, если framework ещё не найден, прямо здесь запускался filtergc — то
    есть полный проход по ВСЕЙ куче GC 60 р��з в секунду. Пока ты в лобби или
    ��щё ��е заспавнился, framework не существует в принципе, поэтому
    сканирование шло непрерывно и клиент вставал н��смерть.

    Покадрово теперь выполняется ТОЛЬКО дешёвый rawget по уже найденному
    объекту. Сам поиск — не чаще одного раза в FRAMEWORK_SCAN_INTERVAL, и это
    жёсткий предел, а не «желательно».
--]]
--[[ Интервал поднят с 1.0 до 4.0 с: framework — синглтон, он создаётся один
     раз и переживает смерти (ClientFramework:840 переставляет lifetime_state
     внутри того же объекта). Искать его раз в секунду смысла нет, а каждый
     такой вызов — stop-the-world обход GC, то есть просадка кадров. ]]
local FRAMEWORK_SCAN_INTERVAL = 4.0
local lastFrameworkScan = -math.huge

local function find_framework_throttled()
    local now = clock()
    if now - lastFrameworkScan < FRAMEWORK_SCAN_INTERVAL then
        return nil
    end
    lastFrameworkScan = now

    local okf, foundf = pcall(filtergc, "table", {
        Keys = { "lifetime_maid", "ui_bindings" },
    }, false)
    if not okf or type(foundf) ~= "table" then
        return nil
    end
    local fallback = nil
    for _, cand in ipairs(foundf) do
        if rawget(cand, "output") ~= nil or rawget(cand, "framework_store") ~= nil then
            local lt = rawget(cand, "lifetime_state")
            if type(lt) == "table" and rawget(lt, "fp_controller") ~= nil then
                return cand
            end
            fallback = fallback or cand
        end
    end
    return fallback
end

local function refresh_local()
    if framework == nil then
        framework = find_framework_throttled()
        if framework == nil then
            return
        end
    end

    local lt = rawget(framework, "lifetime_state")
    if type(lt) == "table" then
        local fpc = rawget(lt, "fp_controller")
        if type(fpc) == "table" and fpc ~= ctrl then
            ctrl = fpc
            ignoreDirty = true          -- новое тело -> пересобрать списо�� лучей
        end
        local ch = rawget(lt, "character")
        if ch ~= myCharacter then
            myCharacter = ch
            ignoreDirty = true
        end
    else
        -- мертвы: контроллер и тело больше не наши, иначе будем целиться трупом
        ctrl = nil
        if myCharacter ~= nil then
            myCharacter = nil
            ignoreDirty = true
        end
    end
end

--[[ ── ТИП ПРЕДМЕТА В РУКАХ: ОДНА ФУНКЦИЯ НА ВСЁ ──────────────────────────
     Раньше э��о читали в двух местах врассыпную (`ctrl.weapon.type` в прицеле
     ствола и в дуге броска), и ОБА промахивались одновременно — отсюда сразу
     две жалобы: с гранатой в руках рисовался muzzle-крест для оружия, а дуга
     броска не появлялась вовсе. Симптомы разные, причина одна.

     Значение сравнива��м с "throwable" — ровно как сам движок перед броском
     (throwable_key_map:19 `u1.weapon.type ~= "throwable"`), а также
     FirstPersonController:650 и MobileInput:85.

     Что здесь важно и чего не было:
       • не опираемся на ОДИН кэшированный ctrl. Если refresh_local не успел
         обновиться (или framework найден, а lifetime_state временно nil),
         ctrl остаётся nil — и оба места молча получали nil;
       • читаем ЖИВОЙ путь framework.lifetime_state.fp_controller как запас;
       • rawget и обычное индексирование пробуем об��: поле type ставится
         прямо на объект (ThrowableItem:31), но сам weapon может приходить
         через метатаблицу класса. ]]
local function held_item_type()
    local function type_of(c)
        if type(c) ~= "table" then return nil end
        local w = rawget(c, "weapon")
        if w == nil then
            pcall(function() w = c.weapon end)
        end
        if type(w) ~= "table" then return nil end
        local t = rawget(w, "type")
        if t == nil then
            pcall(function() t = w.type end)
        end
        return type(t) == "string" and t or nil
    end

    local t = type_of(ctrl)
    if t then return t end

    -- запасной путь: живо�� чтение, минуя кэш ctrl
    if type(framework) == "table" then
        local lt = rawget(framework, "lifetime_state")
        if lt == nil then
            pcall(function() lt = framework.lifetime_state end)
        end
        if type(lt) == "table" then
            local fpc = rawget(lt, "fp_controller")
            if fpc == nil then
                pcall(function() fpc = lt.fp_controller end)
            end
            t = type_of(fpc)
            if t then return t end
        end
    end
    return nil
end

local function holding_throwable()
    return held_item_type() == "throwable"
end

--[[ Сам объект предмета в руках, т��м же двухпутевым способом. Нужен дуге
     броска: из него читаются properties и receiver. ]]
local function held_weapon()
    local function weapon_of(c)
        if type(c) ~= "table" then return nil end
        local w = rawget(c, "weapon")
        if w == nil then
            pcall(function() w = c.weapon end)
        end
        return type(w) == "table" and w or nil
    end

    local w = weapon_of(ctrl)
    if w then return w end

    if type(framework) == "table" then
        local lt = rawget(framework, "lifetime_state")
        if lt == nil then
            pcall(function() lt = framework.lifetime_state end)
        end
        if type(lt) == "table" then
            local fpc = rawget(lt, "fp_controller")
            if fpc == nil then
                pcall(function() fpc = lt.fp_controller end)
            end
            return weapon_of(fpc)
        end
    end
    return nil
end

--[[ ═══ ��РОСАДКА FPS: ЧТО БЫЛО НЕ ТАК ════════════════════════════════════��═
    filtergc — это stop-the-world обход всей памяти Luau, а getgc(true) с
    pairs() по каждой найденной таблице — то же самое, то��ько в разы дороже.
    В прошлой версии я поставил такой поиск «владельцев реестра» с рескана
    раз в 5 с, и, поскольку сущности после обновления игры уехали в
    Actor-VM, поиск НИКОГДА не завершался успехом — то есть полный обход
    кучи повторялся вечно. Это и есть просадка, которой раньше не было.

    Ниже GC больше не используется как источник ростера. Ростер читается из
    Workspace.characters (см. refresh_meta), а filtergc остаётся только для
    метаданных и запускается лишь на появление нового персонажа.
══════════════════════════════════════════════════════════════════════════ ]]
local charFolder    = nil
local lastEntScan   = -math.huge
local ENT_RESCAN    = 2.0

local function get_char_folder()
    if charFolder ~= nil and charFolder.Parent ~= nil then return charFolder end
    charFolder = Workspace:FindFirstChild("characters")
    return charFolder
end

--[[ ЕДИНСТВЕННЫЙ обход GC — и только когда в ростере появился персонаж, для
     которого у нас ещё нет метаданных (то есть на чужо�� ��еспавне). В покое
     GC не трогается вообще. Раньше здесь был getgc(true) + pairs() по КАЖДОЙ
     таблице кучи — ��то и была та самая просадка, которую я же и внёс. ]]
local function scan_entities_gc()
    local now = clock()
    if now - lastEntScan < ENT_RESCAN then return false end
    lastEntScan = now

    local ok, found = pcall(filtergc, "table", {
        Keys = { "replicated_team", "player_name", "spawn_data" },
    }, false)
    if not (ok and type(found) == "table") then return false end

    for _, ent in ipairs(found) do
        if type(ent) == "table" then
            local model = rawget(ent, "character")
            if model ~= nil and rawget(ent, "player_name") ~= nil then
                local prev = entByModel[model]
                -- живая сущность вытесняет устаревшую мёртвую по той же модели
                if prev == nil or (rawget(prev, "dead") == true and rawget(ent, "dead") ~= true) then
                    entByModel[model] = ent
                end
            end
        end
    end
    return true
end

local function refresh_meta()
    --[[ ═══ РОСТЕР ТЕПЕРЬ ИЗ WORKSPACE, А НЕ ИЗ GC ════════════════════════
        В обновлении игры репликация переехала в отдельные Actor'ы
        (PlayerScripts/Actor/parallel_replicator — новый файл в дампе), у
        каждого своя Luau VM: dl_replicator:828-1035 клонирует скрипт в
        Instance.new("Actor") на каждого игрок��. Поэтому опираться на обход
        кучи стало и дорого, и не��адёжно.

        Зато модели ле��ат в Workspace.characters (dl_replicator:919), а имя
        мод��ли — это ingame_id (parallel_replicator:78 character.Name =
        tostring(ingame_id)). Ростер читается прямым перечислением детей:
        никакого GC, стоимость — микросекунды.
    ════════════════════════���════════════════════════════════════════���═ ]]
    local folder = get_char_folder()
    if folder ~= nil then
        -- есть ли персонаж без метаданных? (��оявился новый -> нужен один скан)
        local needScan = false
        for _, model in ipairs(folder:GetChildren()) do
            if model ~= myCharacter and entByModel[model] == nil then
                needScan = true
                break
            end
        end
        if needScan then scan_entities_gc() end

        local n = 0
        table.clear(entByIngame)
        for _, model in ipairs(folder:GetChildren()) do
            if model ~= myCharacter then
                local ent = entByModel[model]
                if ent ~= nil and rawget(ent, "dead") ~= true then
                    local iid = rawget(ent, "ingame_id") or tonumber(model.Name)
                    if iid ~= nil then
                        entByIngame[tostring(iid)] = ent
                    end
                    n += 1
                end
            end
        end
        ent_count = n

        -- прунинг: убираем записи для исчезнувших моделей
        for model in pairs(entByModel) do
            if model.Parent == nil then entByModel[model] = nil end
        end
    end

    --[[
        ЛОКАЛЬНЫЙ КОНТРОЛЛЕР — ИСП��АВЛЕН КОРНЕВОЙ БАГ.
        Прошлый вариант сверял cand.character с LocalPlayer.Character. Но в этой
        игре LocalPlayer.Character НЕ присваивается никогда (в дампе нет ни
        одного присваивания — модель парентится в Workspace.characters, а игроку
        ставится только ReplicationFocus). Значит проверка не срабатывала, и мы
        уходили в запасной критерий, который после респавна мог вернуть СТАРЫЙ
        контроллер. Отсюда «после смерти muzzle/моды отваливаются».

        Правильный источник — ClientFramework.lifetime_state: он создаётся при
        спавне (ClientFramework:828) и ОБНУЛЯЕТСЯ при смерти (234, 1133, 1142),
        поэтому труп подхватить невозможно. Сам framework — синглтон и живёт
        через смерти, ищем его один раз по постоянным ключам.
    --]]
    refresh_local()
end

--[[ Фильтр по команде — ЯВНЫЙ аргумент, а не чтение CFG внутри.

     Так исправлен тихий баг: раньше здесь читался CFG.IgnoreTeammates, и эту
     же функцию вызывал ESP. То есть галка ESP «Enemy Only» не делала вообще
     ничего (CFG.EspEnemyOnly не читался нигде в коде), а состав ESP на самом
     деле переключался настройкой из вкладки Silent Aim. Выключить своих в
     ESP, оставив их для аима, было невозможно.

     Теперь у каждого потребителя свой флаг, и функция проверяет только то,
     что от неё зависит: сущность есть и она живая. ]]
local function is_enemy(ent, skipFriendly)
    if not ent then
        return false
    end
    if rawget(ent, "dead") == true then
        return false
    end
    if skipFriendly and rawget(ent, "is_player_friendly") == true then
        return false
    end
    return true
end

--======================================================================
--  AIM / FIRE ИЗ REPLICATION-СТРИ��А  (aiming, стрельба)
--======================================================================
local netState = {}
local hookedStreams = {}

--[[
    Входящий стрим (сервер -> клиент) отличается от исходящего!
    Клиент шлёт последовательность write_bool, а сервер переупаковывает
    состояние в БИТОВОЕ ПОЛЕ u16 (parallel_replicator: read_time -> read_u16
    -> unpack_number16). Раскладка бит (LSB-first, 1-индексация оригинала):
        [1] nvg   [2] aiming   [3] climbing  [4] laser   [5] flashlight
        [6] есть байт fire_multiplier        [7] позиция [8] lean
        [9] look  [10] barrel_look           [11] поза
    Читаем напрямую нативным buffer — БЕЗ зависимости от игрового BitBuffer
    (его import() всё равно делает buffer.fromstring).
--]]
local function decode_stream(data)
    local buf
    if type(data) == "string" then
        buf = buffer.fromstring(data)
    elseif type(data) == "buffer" then
        buf = data
    else
        return nil
    end
    if buffer.len(buf) < 6 then
        return nil
    end
    local bits = buffer.readu16(buf, 4)          -- пропускаем u32 time
    local aiming = bit32.extract(bits, 1) == 1   -- бит [2]
    local hasFire = bit32.extract(bits, 5) == 1  -- бит [6]
    local fire = 0
    if hasFire and buffer.len(buf) >= 7 then
        fire = buffer.readu8(buf, 6) / 64
    end
    return aiming, fire
end

local function hook_stream(child)
    if not child:IsA("UnreliableRemoteEvent") then
        return
    end
    if hookedStreams[child.Name] then
        return
    end
    hookedStreams[child.Name] = true
    local streamId = child.Name                  -- = tostring(ingame_id)
    conns[#conns + 1] = child.OnClientEvent:Connect(function(data)
        if not running then
            return
        end
        local ok, aiming, fire = pcall(decode_stream, data)
        if not ok or aiming == nil then
            return
        end
        local state = netState[streamId]
        if not state then
            state = {}
            netState[streamId] = state
        end
        state.aim = aiming
        state.fire = fire or 0
        state.t = clock()
    end)
end

pcall(function()
    local actions = RS:WaitForChild("actions", 10)
    local streams = actions and actions:FindFirstChild("replication_streams")
    if not streams then
        return
    end
    for _, child in ipairs(streams:GetChildren()) do
        hook_stream(child)
    end
    conns[#conns + 1] = streams.ChildAdded:Connect(hook_stream)
end)

--======================================================================
--  РЕЕСТР CHARACTER — ПОЛНЫЕ СТЕЙТЫ ИГРОКОВ
--======================================================================
--[[
    ПОЧЕМУ РАНЬШЕ НЕ БЫЛО shooting И ПРОЧИХ СТЕЙТОВ.

    Я читал только UnreliableRemoteEvent-стрим (replication_streams). Н�� по
    parallel_replicator:219-296 в него влезает РОВНО 11 бит + опциональные
    поля, и это всё:
        [1] nvg  [2] aiming  [3] climbing  [4] laser  [5] flashlight
        [6] есть байт fire_multiplier      [7] position  [8] lean
        [9] look [10] barrel_look          [11] pose
    Никакого "shooting", здоровья, оружия или команды там НЕ передаётся ���
    отсюда и «не вижу shooting и другие стейты». Больше из этого стрима
    выжать физически нечего.

    Настоящее состояние живёт в классе Character внутри dl_replicator, и там
    его много (dl_replicator:189-219, 620-668, 940-970):
        dead, connected, pose, using_nvg, is_player_friendly, replicated_team,
        character/humanoid_root_part, equipped_weapon (+ laser_enabled,
        flashlight_enabled, last_shot), cached_velocity_magnitude,
        cached_look_activity, weapons[], player_name, user_id, ingame_id
    Реестр — таблица u44[player.UserId] = Character (dl_replicator:807).

    ВЫСТРЕЛ БЕРЁМ ИЗ last_shot: on_fired_weapon/on_fired_shotgun ставят
    equipped_weapon.last_shot = tick() (строки 668 и 738). Зна��ит «стреляет
    сейчас» = tick() - last_shot < порог. Это тот самый shooting-стейт.

    Достаём реестр через getsenv у скрипта-контроллера: он локальный (upvalue
    u44), поэтому идём через debug.getupvalue по функции из окружения. Всё в
    pcall — если исполнитель не даёт getsenv, просто останется nil, и логика
    молча деградирует к данным из стрима.
--]]
--[[ ЧТО ЕЩЁ ЛЕЖИТ В ЭТОМ ОБЪЕКТЕ (на буд��щее, сейчас не используется):
       dead, connected, loaded_weapons, is_player_friendly, replicated_team,
       user_id, player_name, ingame_id, character, humanoid_root_part,
       current_weapon, weapons[] (build.result: firerate, ammunition, ...),
       cached_look_activity (насколько резко крутит мыш��ю),
       spawn_data.char_details, voice, quality_settings.
     Реестр всех живых игроков — таблица u44[UserId] внутри dl_replicator
     (строка 807), если пон��доб��тся доступ не через уже готовый ent. ]]

--======================================================================
--  RAYCAST / LOS / ПРОБИТИЕ
--======================================================================
local rayForward, rayBackward
pcall(function()
    rayForward = RaycastParams.new()
    rayForward.FilterType = Enum.RaycastFilterType.Exclude
    rayBackward = RaycastParams.new()
    rayBackward.FilterType = Enum.RaycastFilterType.Exclude
end)

--[[
    СПИСОК ИСКЛЮЧЕНИЙ ДЛЯ ЛУЧЕЙ — ИСПРАВ��ЕНЫ ДВЕ ПРОБЛЕМЫ.

    1) КОРРЕКТНОСТЬ. Раньше сюда шёл LocalPlayer.Character, который в этой игре
       ВСЕГ��А nil. То есть наше собственное тело из лучей не исключалос��: луч из
       камеры/дула нередко попадал в наш же торс или руки, path_tier возвращал 3
       («закрыто»), и цель считалась невидимой. Отсюда и «ForceHit не форсит», и
       «MultiPoint не работает», и пропадающий muzzle-трейсер. Теперь берём
       настоящую модель из lifetime_state.character.

    2) ПРОИЗВОДИТЕЛЬНОСТЬ. Раньше на КАЖДЫЙ луч создавалась новая таблица и
       дёргался Workspace:FindFirstChild("ignore"). При резолве по костям это
       сотни аллокаций в секунду. Теперь статическая часть (наше тело, ignore,
       камера) с��б��р��ется один раз и обновляется только при смене тела, а
       модель цели просто подставляется в первый слот.
--]]
local ignoreStatic = {}
local ignoreScratch = {}

local function refresh_ignore_static()
    table.clear(ignoreStatic)
    if myCharacter then
        ignoreStatic[#ignoreStatic + 1] = myCharacter
    end
    local ignoreFolder = Workspace:FindFirstChild("ignore")
    if ignoreFolder then
        ignoreStatic[#ignoreStatic + 1] = ignoreFolder
    end
    local cam = Workspace.CurrentCamera
    if cam then
        ignoreStatic[#ignoreStatic + 1] = cam
    end
    ignoreDirty = false
end

local ignoreStaticAt = 0

local function build_ignore(model)
    -- камера/папка ignore могут смениться без смены тела: подстраховываемся
    local nowI = clock()
    if ignoreDirty or (nowI - ignoreStaticAt) > 2 then
        ignoreStaticAt = nowI
        refresh_ignore_static()
    end
    table.clear(ignoreScratch)
    if model then
        ignoreScratch[1] = model
    end
    for i = 1, #ignoreStatic do
        ignoreScratch[#ignoreScratch + 1] = ignoreStatic[i]
    end
    return ignoreScratch
end

--[[
    ЛУЧ БЕЗ АЛЛОКАЦИЙ — ПЕРВАЯ ИЗ ТРЁХ ПРИЧИН ПРОСАДОК.
    Раньше КАЖДЫЙ raycast шёл через pcall(function() return Workspace:Raycast(...) end).
    Это анонимное замыкание с захватом fromPos/dir/params, то есть НОВЫЙ объект
    на каждый луч. При резолве по костям — сотни аллокаций в секунду и
    непрерывная работа GC ровно в горячем пути. Передаём метод напрямую:
    pcall(Workspace.Raycast, Workspace, ...) — ноль аллокаций, тот же pcall.
--]]
local ws_raycast = Workspace.Raycast

local function cast(fromPos, dir, params)
    local ok, res = pcall(ws_raycast, Workspace, fromPos, dir, params)
    if ok then
        return res
    end
    return nil
end

--[[
    ФИЛЬТР 1 — ЧИСТАЯ ВИДИМОСТЬ. РОВНО ОДИН ЛУЧ.
    Это вторая причина просадок: MultiPoint спрашивал только «видно ли»
    (tier == 0), но шёл через path_tier, а тот при AllowPenetrable на КАЖДОМ
    перекрытом луче делал ВТОРОЙ, обратный луч ради толщины — которая для
    проверки видимости не нужна вообще. То есть половина лучей бы��а выброшена.
    Теперь проверка видимости стоит один луч, а цена пробития считается
    отдельно и только когда видимости нет ни в одной т��чке.
--]]
local function los_clear(fromPos, toPos, model)
    if not rayForward then
        return true
    end
    local dir = toPos - fromPos
    if dir.Magnitude < 0.05 then
        return true
    end
    rayForward.FilterDescendantsInstances = build_ignore(model)
    return cast(fromPos, dir, rayForward) == nil
end

local direct_path = los_clear

--[[
    ФИЛ��ТР 2 — ЦЕНА ПРОБИТИЯ ПО РЕАЛЬНОЙ МАТЕМАТИКЕ ИГРЫ (а не по студам).

    caster:261 penetrate_bullet �� точный алгоритм движка:
        :172  Magnitude = (Position - v47).Magnitude        -- толщина преграды
        :175  v50 = penetration_modifiers.penetration[Material]
        :193  v52 = penetration_cost + Magnitude / v50      -- ЦЕНА
        :148  v44 = properties.bullet_penetration_ability
                        * SHARED_STATE.plr_penetration_multiplier.value   -- БЮДЖЕТ
        :209  if v44 >= v52 then ... return true            -- пробило
        :192  if v50 > 0 ... else v52 = math.huge           -- непробиваемо

    Значит толщ��на в студах сама по себе НИЧЕГО не решает — решает
    толщина / делитель материала. По данным penetration_modifiers:
        Wood = 5      3 студа дерева  -> cost 0.60
        Concrete = 1  2 студа бетона  -> cost 2.00
        Metal = 0.15  2 студа металла -> cost 13.3
    ��тарый флаг MaxPenetration = 2.5 СТУДА отбрасывал дерево (реальн��
    пробиваемое) и принимал металл (непробиваемый ничем) — работал наоборот.

    ЧЕСТНО О ГРАНИЦЕ ТОЧНОСТИ: обратный луч даёт ПОСЛЕДНЮЮ повер��ность перед
    целью, поэтому при несколь��их преградах с воздушным зазором мы считаем весь
    промежуток монолитом входного материала. Это оценка СВЕРХУ (пессимистичная):
    мы можем отказаться от р��ально пробиваемой стены, но не зая��им невозможное
    пробитие. Движок при этом рекурсивно суммирует cost с лимитом recursion > 5
    (caster:200), поэтому многослойные преграды он всё равно режет.
--]]
local PEN_DIV
pcall(function()
    -- ровно тот же модуль, что требует caster:22
    PEN_DIV = require(RS.module.data.game.penetration_modifiers).penetration
end)

--[[
    Патрон ч��тается ОДИН раз на кэш-интервал и переиспользуется и пробитием,
    и предиктом. Раньше ammo_ballistics дёргал два pcall с обращением по цепочке
    ctrl.weapon.build.result.ammunition ��а каждый вызов.
    Поле bullet_penetration_ability лежит в ЭТОЙ ЖЕ таблице: CaliberManifest:14
    перечисляет velocity / velocity_drop / bullet_penetration_ability как
    свойства одного набора, и BallisticsPanel:172 читает
    ammunition.bullet_penetration_ability.
--]]
local ammoCache, ammoCacheAt = nil, 0

local function read_ammo()
    local now = clock()
    if ammoCache ~= nil and (now - ammoCacheAt) < 0.5 then
        return ammoCache
    end
    ammoCacheAt = now
    local ammo = nil
    if ctrl then
        pcall(function()
            ammo = ctrl.weapon.build.result.ammunition
        end)
        if ammo == nil then
            pcall(function()
                ammo = ctrl.weapon.build_result.ammunition
            end)
        end
    end
    ammoCache = ammo
    return ammo
end

local penMulAt, penMul = 0, 1

local function penetration_budget()
    local now = clock()
    if now - penMulAt > 2 then
        penMulAt = now
        pcall(function()
            local sv = SHARED and SHARED.plr_penetration_multiplier
            if sv and type(sv.value) == "number" then
                penMul = sv.value
            end
        end)
    end
    local ammo = read_ammo()
    local ability = 0
    if type(ammo) == "table" then
        local a = rawget(ammo, "bullet_penetration_ability")
        if type(a) == "number" then
            ability = a
        end
    end
    -- запас: у самой границы движок отказывает из-за накопленного cost
    return ability * penMul * CFG.PenetrationBudgetUse
end

--[[
    Цена пробития участка from->to. Возвращает число (cost) или nil, если
    преграда непробиваема в принципе (неизвестный материал / делитель <= 0,
    как ForceField = 0 в penetration_modifiers). 2 луча.
--]]
local function wall_cost(fromPos, toPos, model)
    if not rayForward then
        return 0
    end
    local dir = toPos - fromPos
    if dir.Magnitude < 0.05 then
        return 0
    end
    local ignore = build_ignore(model)
    rayForward.FilterDescendantsInstances = ignore
    local hit = cast(fromPos, dir, rayForward)
    if hit == nil then
        return 0                      -- чисто
    end
    rayBackward.FilterDescendantsInstances = ignore
    local back = cast(toPos, fromPos - toPos, rayBackward)
    if back == nil then
        return nil
    end
    local thickness = (hit.Position - back.Position).Magnitude
    local div = PEN_DIV and PEN_DIV[hit.Material]
    if div == nil then
        -- материала нет в таблице: движок пишет warn и НЕ пробивает (caster:178)
        return nil
    end
    if div <= 0 then
        return nil                    -- caster:192 -> cost = math.huge
    end
    return thickness / div
end

--[[
    path_tier() удалён: он мерил ОДИН и тот же отрезок третий раз после
    resolve_target и find_multipoint (на каждый вызов — лишний обратный луч).
    Теперь тир пути возвращает сам find_multipoint, который уже посчитал и
    видимость, и стоимость стены.
--]]

--[[
    Кэш видимости без мусора: раньше на каждое обновление создавалась ��ОВАЯ
    таблица { t =, v = } на игрока — это третий источник GC-давления.
    Теперь два плоских кэша, значение перезаписывается на месте.
--]]
local visCacheT = {}
local visCacheV = {}

local function is_visible(fromPos, model)
    local now = clock()
    local t = visCacheT[model]
    if t and (now - t) < CFG.VisCacheTtl then
        return visCacheV[model]
    end
    local part = model:FindFirstChild("torso") or model:FindFirstChild("humanoid_root_part")
    local vis = false
    if part then
        vis = los_clear(fromPos, part.Position, model)
    end
    visCacheT[model] = now
    visCacheV[model] = vis
    return vis
end

-- сэмплы кости: центр + грань, обращённая к стрелку (0.72 полуразмера по доминантной оси)
local function core_samples(bone, origin)
    if not bone then
        return {}
    end
    local cf = bone.CFrame
    local halfSize = bone.Size * 0.5
    local center = cf.Position
    local toObserver = origin - center
    if toObserver.Magnitude < 0.05 then
        return { center }
    end
    local localDir = cf:VectorToObjectSpace(toObserver.Unit)
    local ax, ay, az = abs(localDir.X), abs(localDir.Y), abs(localDir.Z)
    local rel
    if ax >= ay and ax >= az then
        rel = V3((localDir.X >= 0 and 1 or -1) * halfSize.X * 0.72, 0, 0)
    elseif ay >= az then
        rel = V3(0, (localDir.Y >= 0 and 1 or -1) * halfSize.Y * 0.72, 0)
    else
        rel = V3(0, 0, (localDir.Z >= 0 and 1 or -1) * halfSize.Z * 0.72)
    end
    return { center, cf:PointToWorldSpace(rel) }
end

local function apply_inset(bone, point)
    local inset = CFG.ResolverInset
    if not bone or inset <= 0 then
        return point
    end
    local dir = bone.CFrame.Position - point
    if dir.Magnitude < 0.04 then
        return point
    end
    return point + dir.Unit * min(inset, dir.Magnitude * 0.35)
end

--======================================================================
--  ЛОКАЛЬНОЕ ДУЛО
--======================================================================
local function muzzle_cframe()
    if not ctrl then
        return nil
    end
    local ok, cf = pcall(function()
        return ctrl.weapon.viewmodel.receiver.barrel.WorldCFrame
    end)
    if ok and typeof(cf) == "CFrame" then
        return cf
    end
    return nil
end

local function aim_origin()
    local m = muzzle_cframe()
    if m then
        return m.Position
    end
    local cam = Workspace.CurrentCamera
    if cam then
        return cam.CFrame.Position
    end
    return ZERO3
end

--======================================================================
--  MULTIPOINT — ��ВА РАЗДЕЛЁННЫХ ФИЛЬТРА
--======================================================================
--[[
    ЧТО БЫЛО НЕ ТАК В СТАРОМ MULTIPOINT (три отдельных дефекта).

    1) ОН НЕ ИСКАЛ ПРОБИТИЕ ВООБЩЕ.
       binary_peek проверял только direct_path (чистая видимость). Если щели
       не нашлось, код падал в общий fallback и ��ерил стену РОВНО ИЗ ЧЕСТНОГ��
       ДУЛА (одна точка). Поиска «где стена тоньше» не было ни одной строкой.

    2) БИНАРНЫЙ ПОИСК БЫЛ НЕВЕРНЫМ.
       lo = 0.25, hi = maxOffset, и первым же шагом бралс�� mid = середина.
       Крайняя точка hi НИКОГДА не проверялась. При steps = 3 щупались всего
       три внутренние точки, поэтому щель, открывающаяся только у самого края
       (5.5-6 студов), просто не находилась — «р��ботает, но странно».
       Хуже: на каждую неудачн��ю точку уходило ��ВА луча (см. п.3), то есть
       код платил максимум и находил минимум.

    3) КАЖДАЯ ПРОВЕРКА ВИДИМОСТИ СТОИЛА ДВА ЛУЧА.
       direct_path -> path_tier -> при п��р��крытии второй, обратный луч ради
       толщины, которая для ��видно/не видно�� не нужн��.
       Итого худший случай на одну кость: 3 dirs * 3 шага * 2 луча = 18 лучей,
       и это без гарантии результата.

    КАК СДЕЛАНО ТЕПЕРЬ.

    ФИЛЬТР 1 — ВИДИМОСТЬ (приоритет, как ты и просил).
        Для каждого направления сначала ОДИН луч из крайней точки (гейт).
        Не видно из края -> направление отбрасывается целиком за 1 луч
        (раньше на это уходило до 6).
        Видно -> бинарным поиском находим МИНИМАЛЬНОЕ смещение, из которо��о
        цель ещё видна. Миниму�� важен вдвойне: это и меньшая ложь серверу про
        позицию дула (OriginBudget), и точка, которая переживёт следующий кадр.
        Здесь гарантия монотонности честная: край проверен ДО поиска.

    ФИЛЬТР 2 — МИНИМАЛЬНАЯ СТЕНА (только если фильтр 1 не дал НИ ОДНОЙ точки).
        Перебираем те же направления и ищем точку с МИНИМАЛЬНОЙ ЦЕНОЙ пробития
        по формуле движка (толщина / делитель материала, caster:193).
        Берём точку, если её цена влезает в бюджет патрона (caster:209).
        Никаких «студов» — метрика ровно ��а, п�� которой считает игра.

    ЦЕНА: фильтр 1 — от 3 л��чей (все направления глухие) до 3 + steps.
          фильтр 2 — dirs * MPPenProbes * 2, и только когда фильтр 1 пуст.
--]]

--[[ Кэш по САМОЙ КОСТИ, без string.format и tostring на каждый вызов.
     Раньше ключ собирался строкой ("lite|%.1f|...|%s") — это две аллокации на
     каждую попытку резолва, плюс tostring(Instance) читает Name.
     Таблица слабая по ключам: уничтоженные части уходят сами. ]]
local mpCache = setmetatable({}, { __mode = "k" })

local dirScratch = {}

local function mp_dirs(cam)
    local cf = cam and cam.CFrame
    local right = cf and cf.RightVector or V3(1, 0, 0)
    local up    = cf and cf.UpVector or V3(0, 1, 0)
    table.clear(dirScratch)
    -- порядок: горизонталь (у угла срабатывает чаще всего), затем вертикаль
    dirScratch[1] = right
    dirScratch[2] = -right
    dirScratch[3] = up
    if CFG.MPExtraDirs then
        dirScratch[4] = -up
        local d1, d2, d3, d4 = right + up, -right + up, right - up, -right - up
        dirScratch[5] = d1.Magnitude > 0.001 and d1.Unit or right
        dirScratch[6] = d2.Magnitude > 0.001 and d2.Unit or -right
        dirScratch[7] = d3.Magnitude > 0.001 and d3.Unit or right
        dirScratch[8] = d4.Magnitude > 0.001 and d4.Unit or -right
    end
    return dirScratch
end

--[[ ФИЛЬТР 1: минимальное смещение вдоль dir, из которого цель ВИДНА.
     Возвращает точку или nil. Первый луч — гейт по краю. ]]
local function peek_visible(origin, aimPoint, model, dir, maxOffset, steps)
    local far = origin + dir * maxOffset
    if not los_clear(far, aimPoint, model) then
        return nil
    end
    local lo, hi = 0, maxOffset
    local best = far
    for _ = 1, steps do
        local mid = (lo + hi) * 0.5
        local cand = origin + dir * mid
        if los_clear(cand, aimPoint, model) then
            best = cand
            hi = mid
        else
            lo = mid
        end
    end
    return best
end

--[[ ФИЛЬТР 2: точка с МИНИМАЛЬНОЙ ценой пробития.
     Возвращает point, cost — или nil, cost (если минимум не влез в бюджет). ]]
local function peek_cheapest(origin, aimPoint, model, cam, maxOffset)
    local budget = penetration_budget()
    if budget <= 0 then
        return nil, math.huge
    end
    local bestPt, bestCost = nil, math.huge
    -- честное ��уло тоже кандидат: часто оно и е��ть самое тонкое место
    local c0 = wall_cost(origin, aimPoint, model)
    if c0 then
        bestPt, bestCost = origin, c0
    end
    local dirs = mp_dirs(cam)
    local probes = max(1, CFG.MPPenProbes)
    for i = 1, #dirs do
        local dir = dirs[i]
        for s = 1, probes do
            local pt = origin + dir * (maxOffset * (s / probes))
            local c = wall_cost(pt, aimPoint, model)
            if c and c < bestCost then
                bestPt, bestCost = pt, c
            end
        end
    end
    if bestPt and bestCost <= budget then
        return bestPt, bestCost
    end
    return nil, bestCost
end

--[[ Возвращает spoofOrigin, tier
     tier 0 = цель видна из этой точки
     tier 1 = видимости нет, но сте��а проб��ваема и здесь она минимальна
     tier 3 = нет варианта ]]
local function find_multipoint(origin, aimPoint, part, cam)
    local model = part and part.Parent

    -- честное дуло: видимость проверяется всегда, до любых смещений
    if los_clear(origin, aimPoint, model) then
        return origin, 0
    end
    if not CFG.MultiPoint then
        -- MultiPoint выключен: остаётся только пробитие из честного дула
        if CFG.AllowPenetrable then
            local c = wall_cost(origin, aimPoint, model)
            if c and c <= penetration_budget() then
                return origin, 1
            end
        end
        return nil, 3
    end

    local now = clock()
    local rec = mpCache[part]
    local dist = part and (part.Position - origin).Magnitude or 0
    local ttl = CFG.MPCacheSec * (1 + dist / CFG.MPDistScale)

    --[[ Переис��ользуем прошлый результат, только если и дуло, и точка прицела
         почти те же. Раньше ключ квантовался до 0.1 студа по origin, а точка
         прицела в ключ не входила вообще — при движении цели кэш отдавал
         смещение, посчитанное под ДРУГУЮ точку. ]]
    if rec and (now - rec.t) < ttl
        and (rec.org - origin).Magnitude < 0.6
        and (rec.aim - aimPoint).Magnitude < 1.2 then
        if rec.tier == 0 and los_clear(rec.spoof, aimPoint, model) then
            return rec.spoof, 0
        end
        if rec.tier == 3 and (now - rec.t) < 0.08 then
            return nil, 3
        end
    end

    --[[ Ищем СРАЗУ внутри анти-кик бюджета: иначе найденная точ��а окажется
         дальше OriginBudget, сетевой хук подрежет её обратно в стену, и
         эксплоит не ��работает вовсе. ]]
    local limit = CFG.MPMaxOffset
    if CFG.SpoofOrigin and (CFG.OriginBudget or 0) > 0 then
        limit = min(limit, CFG.OriginBudget)
    end

    -- ── ФИЛЬТР 1: полная видимость ───────────────────────────────────
    local dirs = mp_dirs(cam)
    local steps = CFG.MPBinarySteps
    for i = 1, #dirs do
        local pt = peek_visible(origin, aimPoint, model, dirs[i], limit, steps)
        if pt then
            mpCache[part] = { tier = 0, spoof = pt, t = now, org = origin, aim = aimPoint }
            return pt, 0
        end
    end

    -- ── ФИЛЬТР 2: минимальная стена ────────────────────────���─────────
    if CFG.AllowPenetrable then
        local pt = peek_cheapest(origin, aimPoint, model, cam, limit)
        if pt then
            mpCache[part] = { tier = 1, spoof = pt, t = now, org = origin, aim = aimPoint }
            return pt, 1
        end
    end

    mpCache[part] = { tier = 3, spoof = nil, t = now, org = origin, aim = aimPoint }
    return nil, 3
end

--======================================================================
--  RESOLVER LITE  (кость, выглядывающая из укрытия)
--======================================================================
--[[ Имена частей, которые движо�� принимает в таблице попаданий.
     Ровно список caster:97 (u17) — ничего другого сервер не ждёт. ]]
K.HIT_PART_VALID = {
    left_arm_vis = true, right_arm_vis = true,
    left_leg_vis = true, right_leg_vis = true,
    torso = true, head = true,
}
-- бытовые имена костей -> имена из u17
K.HIT_PART_ALIAS = {
    left_arm = "left_arm_vis",   right_arm = "right_arm_vis",
    left_leg = "left_leg_vis",   right_leg = "right_leg_vis",
    upper_torso = "torso", lower_torso = "torso",
    humanoid_root_part = "torso", root = "torso", body = "torso",
}

K.RESOLVER_BONES = { "head", "torso" }

local function resolve_lite(origin, model)
    if not CFG.Resolver then
        return nil, nil
    end
    for _, boneName in ipairs(K.RESOLVER_BONES) do
        local bone = model:FindFirstChild(boneName)
        if bone then
            local samples = core_samples(bone, origin)
            local center = samples[1]
            local edge = samples[2]
            if center and direct_path(origin, center, model) then
                return bone, center
            end
            if edge and direct_path(origin, edge, model) then
                return bone, apply_inset(bone, edge)
            end
        end
    end
    return nil, nil
end

--======================================================================
--  ПРЕДИКТ  (упреждение по реальн��й модели полёта пули этой игры)
--======================================================================
--[[
    Движок считает позицию пули так (caster.path_position_at_lifetime):

        pos(t) = origin
               + dir.Unit * (velocity * t) / (t * velocity_drop + 1)
               + gravity * t^2
               + GlobalWind * t^2 * 4

    где gravity = Vector3.new(0, -workspace.Gravity, 0).
    Пройденная вдоль ствола дистанция: d(t) = v*t / (t*vd + 1).
    Отсюда время до дистанции D в замкнутом виде:
        v*t = D*(t*vd + 1)  ->  t = D / (v - D*vd)     (при v > D*vd)

    Упреждение: цель за это время уедет на targetVel * t, а саму пулю с��есёт
    вниз и ветром — эти члены компенсируем, поднимая точку прицела.
    Дистанция зависит от смещённой точки, поэтому пара итераций сходимости.
--]]
local velTrack = {}          -- [model] = { pos, t, vel }

local function track_velocity(model)
    local hrp = model:FindFirstChild("humanoid_root_part")
    if not hrp then
        return ZERO3
    end
    local now = clock()
    local pos = hrp.Position
    local rec = velTrack[model]
    if not rec then
        velTrack[model] = { pos = pos, t = now, vel = ZERO3 }
        return ZERO3
    end
    local dt = now - rec.t
    --[[
        Порог снижен с 0.03 до 0.016 (кадр), а сглаживание поднято до 0.6.
        Причина: прошлый вариант сам добавлял 50-70 мс запаздывания к оценке
        скорости — поверх и без того 190 мс отката ре��л��кации. По бегущим это
        складывалось в промах. Позиция чужой модели уже интерполирована
        буф��ром, поэтому она гладкая и часто с��мплировать её безопасно.
    --]]
    if dt >= 0.016 then
        local raw = (pos - rec.pos) / dt
        --[[
            Отсечка рывков. При респавне/телепорте модель прыгает на десятки
            студов за кадр, и raw получается сотнями — такой лид уводил
            прицел в пустоту. Считаем это не движением, а сменой позиции.
        --]]
        if raw.Magnitude > CFG.PredictMaxTargetSpeed then
            rec.vel = ZERO3
        else
            rec.vel = rec.vel + (raw - rec.vel) * 0.6
        end
        rec.pos = pos
        rec.t = now
    end
    return rec.vel
end

--[[
    Откат репликации в СЕКУНДАХ, прочи��анный из живого SHARED_STATE.
    Читаем через кэш: значение статичное, а об��ащение к SHARED_STATE на каждую
    кость каждой цели — лишняя работа в самом горячем месте.
--]]
local rollbackSec = 0.19
local rollbackReadAt = 0

local function replication_rollback()
    if not CFG.PredictRollback then
        return 0
    end
    local now = clock()
    if now - rollbackReadAt > 2 then
        rollbackReadAt = now
        pcall(function()
            local ms = SHARED and SHARED.plr_replication_rollback_time_ms
            if ms and type(ms.value) == "number" and ms.value > 0 then
                rollbackSec = ms.value / 1000
            end
        end)
    end
    return rollbackSec * CFG.PredictRollbackFactor
end

--[[
    ПАРАМЕТРЫ БОЕПРИ��АСА — ИСПРАВЛЕН П��ТЬ (вторая причина непопаданий).
    Раньше читал��сь ctrl.weapon.build_result.ammunition. Такое поле в игре
    ЕСТЬ, но только у редактора обвесов (BallisticsPanel), а не у живого
    оружия. Рантайм читает иначе:
        FPC_extend:730        weapon.build.result.ammunition
        dl_replicator:636,699 build.result.ammunition
    Обращение было в pcall, поэтому падало ТИХО, и предикт всегда работал на
    запасных 900 ст/с с нулевым падением. Для пистолета (~350) или снайперки
    это давало заметно неверный лид — по движущимся мы просто не попадали.
    Основной путь теперь верный, старый оставлен как запасной.
--]]
local function ammo_ballistics()
    local velocity, drop = CFG.PredictFallbackSpeed, 0
    if not ctrl then
        return velocity, drop
    end
    -- общий кэшированный читатель (см. read_ammo): тот же патрон нужен пробитию
    local ammo = read_ammo()
    if type(ammo) == "table" then
        local v = rawget(ammo, "velocity")
        if type(v) == "number" and v > 1 then
            velocity = v
        end
        local d = rawget(ammo, "velocity_drop")
        if type(d) == "number" then
            drop = d
        end
    end
    return velocity, drop
end

-- время полёта д�� дистанции D
local function travel_time(dist, velocity, drop)
    local denom = velocity - dist * drop
    if denom <= 1 then
        return dist / max(velocity, 1)      -- вне разумного диапазона
    end
    return dist / denom
end

local function predict_point(model, origin, basePoint)
    if not CFG.Prediction then
        return basePoint
    end
    local targetVel = track_velocity(model)
    local velocity, drop = ammo_ballistics()
    local gravY = -Workspace.Gravity
    local wind = ZERO3
    if CFG.PredictWind then
        local okw, w = pcall(function() return Workspace.GlobalWind end)
        if okw and typeof(w) == "Vector3" then
            wind = w
        end
    end

    --[[
        Откат репликации ��обавляется к ЛИДУ ЦЕЛИ, но НЕ к компенсации падения
        пули. Это принципиал��но: пуля летит travel_time и падает именно за это
        время, а вот цель за прошедшие 190 мс уже уехала — то есть её надо
        доводить дальше, а траекторию пули считать как есть. Раньше эти 190 мс
        не учитывались вообще, поэтому по бегущим мы стреляли им в спину.
    --]]
    local rb = replication_rollback()

    local aim = basePoint
    for _ = 1, CFG.PredictIterations do
        local dist = (aim - origin).Magnitude
        local t = travel_time(dist, velocity, drop)
        if CFG.PredictMaxTime > 0 and t > CFG.PredictMaxTime then
            t = CFG.PredictMaxTime
        end
        local lead = targetVel * (t + rb)
        if not CFG.PredictVertical then
            lead = V3(lead.X, 0, lead.Z)
        end
        -- компенсация падения пули и ветра (в модели именно t^2, без 1/2)
        local dropComp = V3(0, -(gravY * t * t), 0) - wind * (t * t * 4)
        aim = basePoint + lead + dropComp
    end
    return aim
end

--======================================================================
--  ВЫБОР ЦЕЛИ  (веса BRM5, FOV по УГЛУ, sticky) — вызывается ТРОТТЛЕННО
--======================================================================
local Target = {
    pos = nil,
    model = nil,
    ent = nil,
    tier = 3,
    spoof = nil,
    bone = nil,
    t = 0,
}

local function fov_half_deg()
    return clamp(CFG.SilentAimFOV, 1, 179) * 0.5
end

local function fov_radius_px(cam)
    local vp = cam.ViewportSize
    local focal = (vp.Y * 0.5) / tan(rad((cam.FieldOfView or 70) * 0.5))
    return max(tan(rad(clamp(CFG.SilentAimFOV, 1, 179) * 0.5)) * focal, 1)
end

local function angle_from_look(cam, worldPos)
    local look = cam.CFrame.LookVector
    local toTarget = worldPos - cam.CFrame.Position
    if toTarget.Magnitude < 0.01 then
        return 0
    end
    return deg(acos(clamp(look:Dot(toTarget.Unit), -1, 1)))
end

local function bone_name_for(depth)
    local bone = CFG.AimBone
    if bone == "auto" then
        return (depth <= 140) and "head" or "torso"
    end
    return bone
end

--[[
    ПУЛ КАНДИДАТОВ — без аллокаций на кадр.
    Раньше каждый резолв создавал таблицу prev, таблицу candidates и по таблице
    на КАЖДОГО кандидата. При 11 Гц и трёх-пяти врагах это десятки мусорных
    таблиц в секунду в самом горячем месте. Теперь таблицы переиспользуются.
--]]
local candPool = {}
local candList = {}

local function cand_slot(i)
    local c = candPool[i]
    if not c then
        c = {}
        candPool[i] = c
    end
    return c
end

-- полный резолв цели (дорогой); вызыв��ется не чаще AimResolveInterval
local function resolve_target()
    -- прошлая цель для sticky — плоскими локалями, без таблицы
    local pPos, pModel, pEnt, pTier, pSpoof, pBone, pT =
        Target.pos, Target.model, Target.ent, Target.tier, Target.spoof, Target.bone, Target.t

    Target.pos = nil
    Target.model = nil
    Target.ent = nil
    Target.tier = 3
    Target.spoof = nil
    Target.bone = nil

    if not CFG.SilentAim then
        return
    end
    local cam = Workspace.CurrentCamera
    local folder = Workspace:FindFirstChild("characters")
    if not cam or not folder then
        return
    end

    local origin = aim_origin()
    local maxAngle = fov_half_deg()
    -- LocalPlayer.Character в этой игре всегда nil: берём модель из lifetime_state
    local myChar = myCharacter
    local now = clock()

    -- ФАЗА 1: дешёвый гейт (FOV-угол + дистанция), собираем кандидатов
    local n = 0
    for _, model in ipairs(folder:GetChildren()) do
        if model ~= myChar then
            local ent = entByModel[model]
            if is_enemy(ent, CFG.IgnoreTeammates) then
                local hrp = model:FindFirstChild("humanoid_root_part")
                if hrp then
                    local dist = (origin - hrp.Position).Magnitude
                    if dist <= CFG.SilentAimMaxDist then
                        local anchor = model:FindFirstChild("torso") or hrp
                        local angle = angle_from_look(cam, anchor.Position)
                        if angle <= maxAngle then
                            n += 1
                            local c = cand_slot(n)
                            c.model, c.ent, c.dist, c.angle = model, ent, dist, angle
                            candList[n] = c
                        end
                    end
                end
            end
        end
    end
    -- обрезаем хвост прошлого кадра, чтобы table.sort видел ровно n элементов
    for i = #candList, n + 1, -1 do
        candList[i] = nil
    end
    -- сортировка кандидатов по грубому приоритету (угол важнее, дистанция вторична)
    table.sort(candList, function(a, b)
        return (a.angle + a.dist * 0.02) < (b.angle + b.dist * 0.02)
    end)

    -- ФАЗА 2: ��орогой резолв (MultiPoint / Resolver) только для топ-N
    local bestScore = math.huge
    local best = nil
    local resolved = 0
    for ci = 1, #candList do
        local cand = candList[ci]
        if resolved >= CFG.MPMaxTargets then
            break
        end
        resolved += 1

        local model = cand.model
        local ent = cand.ent
        local dist = cand.dist
        local angle = cand.angle

        local boneName = bone_name_for(dist)
        local bone = model:FindFirstChild(boneName) or model:FindFirstChild("torso")
        if bone then
            -- ПРЕДИКТ: сервер симулирует пулю сам, поэтому целимся туда, где
            -- цель окажется к ��оменту прилёта (с учётом скорости патрона,
            -- падения и ветра). Проверки видимости идут уже по этой точке.
            local aimPt = predict_point(model, origin, bone.Position)

            --[[ find_multipoint сам делает всё по порядку:
                 честн��е дуло -> фильтр 1 (видимость) -> фильтр 2 (мин. стена).
                 Раньше эта логика была размазана здесь и дублировала лучи:
                 direct_path вызывался тут, потом ещё раз внутри find_multipoint,
                 а в конце path_tier мерил стену ТРЕТИЙ раз по тому же отрезку. ]]
            local spoof, tier = find_multipoint(origin, aimPt, bone, cam)

            --[[ Альтернативная кость: к голове щели нет, а к торсу есть (или
                 наоборот). ВАЖНО: точка а��ьтернативной кости тоже прогоняется
                 через предикт. Раньше бралась сырая altBone.Position — то есть
                 по этой ветке упреждение молча терялось и по бегущим не заходило. ]]
            if tier == 3 and CFG.MPTryOtherBone then
                local altName = (boneName == "head") and "torso" or "head"
                local altBone = model:FindFirstChild(altName)
                if altBone then
                    local altPt = predict_point(model, origin, altBone.Position)
                    local sp2, t2 = find_multipoint(origin, altPt, altBone, cam)
                    if t2 < 3 then
                        spoof, tier, aimPt, bone = sp2, t2, altPt, altBone
                    end
                end
            end

            -- resolver: кость, выглядывающая из укрытия (по умолчанию выключен)
            if tier == 3 then
                local rBone, rPoint = resolve_lite(origin, model)
                if rBone and rPoint then
                    tier, spoof, aimPt, bone = 2, origin, rPoint, rBone
                end
            end

            if tier < 3 or not CFG.SkipBlocked then
                local playerBias = -500
                local score = (K.TIER_WEIGHT[tier] or 3800) + angle * 12 + dist * 0.008 + playerBias
                if score < bestScore and aimPt then
                    bestScore = score
                    best = {
                        pos = aimPt, model = model, ent = ent, tier = tier,
                        spoof = spoof, bone = bone,
                    }
                end
            end

            --[[
                РАННИЙ ВЫХОД (главная экономия).
                Кандидаты уже отсортированы по «углу + дистанции», поэтому
                первый, у кого прямая видимость (tier 0), почти всегда и есть
                нужная цель. Раньше мы всё равно прогонял�� дорогой MultiPoint
                по остальным — это и создавало лаги.
            --]]
            if tier == 0 then
                break
            end
        end
    end

    if best then
        Target.pos = best.pos
        Target.model = best.model
        Target.ent = best.ent
        Target.tier = best.tier
        Target.spoof = best.spoof
        Target.bone = best.bone
        Target.t = now
    elseif pModel and pModel.Parent ~= nil
        and (now - (pT or 0)) < CFG.MPStickySec and is_enemy(pEnt, CFG.IgnoreTeammates) then
        -- sticky: держим прошлую цель, если она ещё в FOV И путь ещё открыт
        local anchor = pModel:FindFirstChild("torso") or pModel:FindFirstChild("humanoid_root_part")
        if anchor and angle_from_look(cam, anchor.Position) <= maxAngle
            and los_clear(pSpoof or origin, pPos or anchor.Position, pModel) then
            Target.pos = pPos
            Target.model = pModel
            Target.ent = pEnt
            Target.tier = pTier
            Target.spoof = pSpoof
            Target.bone = pBone
            Target.t = pT
        end
    end
end

-- лёгкая покадровая проверка живости цели (бе�� raycast)
local function validate_target()
    if Target.model and Target.model.Parent == nil then
        Target.pos = nil
        Target.model = nil
        Target.ent = nil
        Target.tier = 3
        Target.spoof = nil
        Target.bone = nil
    end
end

--======================================================================
--  ПАТЧ ПАКЕТА ВЫСТРЕЛА  (origin + direction)
--======================================================================
local NetEnc
pcall(function()
    NetEnc = require(RS.module.namespace.NetworkEncode).NetworkEncode
end)

local Caster
pcall(function()
    Caster = require(RS.module.caster.caster)
end)

local shotOrigin = nil
local packet_hooked = false

local function hook_packet()
    if packet_hooked or not NetEnc then
        return
    end
    local original = rawget(NetEnc, "write_exact_position")
    if type(original) ~= "function" then
        return
    end
    --[[ ═══ ПРИЧИНА КИКА "network tampering" (разобрано по новому дампу) ═════
        rifle_methods:167-190 — точная структура ��акета выстрела:

            local v37 = BitBuffer.new(256)
            v37:write_bool(ammunition.is_mixed_ammo)
            NetworkEncode.write_exact_position(v37, WorldPosition)  -- 1-й = ORIGIN
            ...
            NetworkEncode.write_exact_position(v37, v40.direction)  -- 2-й+ = DIR

        где WorldPosition = barrel.WorldPosition (:169) — РЕАЛЬНАЯ позиция дула.
        Codec (NetworkEncode:35) пишет СЫРЫЕ f32 без квантизации и лимитов, и
        используется ТОЛЬКО здесь (3 точки: :169 origin, :180/:188 direction) —
        значит сам спуф пакет не «ломает», ловит его серверная проверка origin
        относительно реплики персонажа. MPMaxOffset=6 студов + смещение сквозь
        стену выходило за правдоподобие -> kick "network tampering".

        РЕШЕНИЕ (эксплоит СОХРАН��Н, обход обновлён):
          1) origin по-прежнем�� спуфится (в этом весь смысл MultiPoint), но
             смещение подрезается бюджетом CFG.OriginBudget: направление
             спуфа сохраняем, длину ограничиваем до правдоподобной.
          2) direction считается от ТОГ�� ЖЕ origin, что реально уш��л в пакете —
             раньше пара (origin, direction) могла быть несогласованной.
          3) origin/direction различаем по ПОРЯДКУ вызовов внутри буфера, как
             пишет rifle_methods (Magnitude > 1.01 ломался у нуля координат и
             корректно не отличал origin от direction).
          4) CFG.MaxSpoofAngle — опциональный ограничитель угла, ��о умолчанию
             ВЫКЛЮЧЕН (0), чтобы не резать silent aim.
    ══════════════════════════════════════════════════════════════════════ ]]
    local bufIndex = setmetatable({}, { __mode = "k" })  -- buffer -> № вызова
    local sentOrigin = nil   -- origin, который РЕАЛЬНО у��ёл в этом пакете

    rawset(NetEnc, "write_exact_position", function(buffer, vec)
        local out = vec
        pcall(function()
            if typeof(vec) ~= "Vector3" then return end

            local idx = (bufIndex[buffer] or 0) + 1
            bufIndex[buffer] = idx

            if idx == 1 then
                -- ══ ORIGIN ══ спуф остаётся (это и есть эксплоит MultiPoint),
                -- но смещение ограничено бюджетом OriginBudget.
                shotOrigin = vec
                sentOrigin = vec
                if CFG.SpoofOrigin and CFG.SilentAim and Target.pos and Target.spoof then
                    local off = Target.spoof - vec
                    local d   = off.Magnitude
                    local budget = CFG.OriginBudget or 0
                    if d > 0.001 and budget > 0 then
                        -- дальше бюджета не уходим: направление смещения
                        -- сохраняем, длину подрезаем
                        sentOrigin = (d <= budget) and Target.spoof
                                     or (vec + off.Unit * budget)
                        out = sentOrigin
                    end
                end
                return
            end

            -- ══ DIRECTION ══ считаем от ТОГО ЖЕ origin, что ушёл в пакете:
            -- инач�� луч (origin, direction) несогласован и сервер видит бред.
            local base = sentOrigin or shotOrigin
            if not (CFG.SilentAim and Target.pos and base) then return end
            local toTarget = Target.pos - base
            if toTarget.Magnitude <= 0.001 then return end
            local want = toTarget.Unit

            -- Ограничение угла — ОПЦИЯ. 0 = выключено (обычное поведение
            -- silent aim: пуля летит куда нужно). Включать только если сервер
            -- начнёт валидировать угол относительно взгляда.
            local maxDeg = CFG.MaxSpoofAngle or 0
            if maxDeg <= 0 then
                out = want
                return
            end
            local trueDir = (vec.Magnitude > 0.001) and vec.Unit or want
            local maxRad  = rad(maxDeg)
            if acos(clamp(trueDir:Dot(want), -1, 1)) <= maxRad then
                out = want
            else
                local axis = trueDir:Cross(want)
                out = (axis.Magnitude > 1e-6)
                      and (CFrame.fromAxisAngle(axis.Unit, maxRad) * trueDir).Unit
                      or want
            end
        end)
        return original(buffer, out)
    end)
    packet_hooked = true
end

--======================================================================
--  ЗВУК ПОПАДАНИЯ
--======================================================================
--[[
    HIT SOUND — по шаблону самой игры.

    Почему прошлые версии молчали (разобрано по дампу):
      1) Звук создавался З��НОВО на каждое попадание и проигрывался сразу.
         Ассет в этот ��омент ещё не загружен -> Play() уходит в пустоту.
      2) Sound не попадал в микшер игры. Игра ведёт весь звук через SoundGroup'ы
         (client/controller/misc/volume: SoundService.master.Volume =
         client_vol), а свои звуки создаёт так
         (insitux/luau/lib/luau_client_library, sound.create):
             Sound.SoundGroup = SoundService.master.ingame.main
             Sound.Parent     = Workspace
         затем Timescale.play_sound -> Sound:Play().
      Поэтому делаем ровно так же: ОДИН предзагруженный Sound в нужной группе,
      на попадании просто перезапускаем его.
--]]
--[[
    HIT SOUND — вернул РОВНО тот вариант, который работал.

    Что я с��омал «улучшениями»:
      • один переиспользуемый Sound вместо нового на каждый хит: при частых
        попаданиях перезапуск через TimePosition вместо Play() глуши�� звук,
        �� если игра чистила Workspace — инстанс терялся;
      • SoundGroup = SoundService.master.ingame.main: звук уходил в микшер
        игры, где группа может быть тихой/выключенной (в лобби — точно);
      • родитель Workspace вместо SoundService.
    Рабочая схема простая: НОВЫЙ Sound на каждое попадание, родитель
    SoundService, БЕЗ SoundGroup, обычный :Play(), уборка через Debris.
--]]
local lastHitSoundAt = 0
local hitSoundRoute = "?"          -- какой способ реально сработал
local warmSound = nil              -- держим ассет прогретым

--[[
    ПОЧЕМУ ЗВУКА НЕ БЫЛО — две ошибки ��разу, о��е мои:

    1) sound.Parent = SoundSvc, где SoundSvc это cloneref-ПРОКСИ сервиса.
       Назначение Parent на прокси может не сработать: инстанс остаётся без
       родителя, а Play() у беспарентного Sound молчит.
    2) Вся цепочка стояла в ОДНОМ pcall. Если падало назначение Parent, то
       sound:Play() уже не вызывался — и ошибку глотал pcall. Тишина без следов.

    Теперь: сырой сервис (без cloneref), каждый шаг �� своём pcall, основной
    путь — PlayLocalSound (ему родитель вообще не нужен), плюс запасной путь
    через Parent+Play. SoundGroup не ставим: в микшере игры группа может быть
    ��риглушена (в прошлой версии это д��бивало и PlayLocalSound).
--]]
local RawSoundService = game:GetService("SoundService")

--[[ КАТАЛОГ ЗВУКОВ ПОПАДАНИЯ.
     Взят один-к-одному из модуля Visuals (HIT_SOUNDS / HIT_SOUND_ORDER) — те же
     девять названий и те же id, чтобы звук здесь и там был идентичным.
     Прошлый вариант я собрал сам, и это было ошибкой: часть id ��ообще не
     относилась к звукам попадания.
     ORDER задаёт порядок в дропдауне: в таблице-словаре обход был бы случайным.
     Питч-множителей тут нет — в исходнике их нет, id воспроизводятся как есть,
     а ручной питч остаётся отдельной настройкой. ]]
K.HIT_SOUNDS = {
    Fatality          = 115982072912004,
    ["Minecraft XP"]  = 15181891182,
    ["Minecraft Hit"] = 73571339886360,
    ["Minecraft Egg"] = 134530432300459,
    ["Minecraft Bow"] = 111481862692779,
    Click             = 95635059379804,
    Bell              = 124010691633262,
    Neverlose         = 139452805868562,
    Primordial        = 97511223764004,
}
K.HIT_SOUND_ORDER = { "Fatality", "Minecraft XP", "Minecraft Hit",
    "Minecraft Egg", "Minecraft Bow", "Click", "Bell", "Neverlose",
    "Primordial", "Custom" }

--[[ Применяет пресет к CFG. "Custom" не трогает id — так вручную введённый
     номер не затирается выбором из списка. ]]
local function apply_hit_preset(name)
    CFG.HitSoundPreset = name
    local id = K.HIT_SOUNDS[name]
    if id then
        CFG.HitSoundId = id
    end
    warmSound = nil     -- прогретый ассет относится к старому id
end

local function build_hit_sound()
    local s = nil
    pcall(function()
        s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. tostring(CFG.HitSoundId)
        s.Volume = clamp(CFG.HitSoundVolume, 0, 10)
        s.PlaybackSpeed = clamp(CFG.HitSoundPitch, 0.5, 2)
        s.Looped = false
    end)
    return s
end

-- прогреваем ассет заранее, чтобы первое попадание уже звучало
local function warm_hit_sound()
    if warmSound and warmSound.Parent then
        return
    end
    local s = build_hit_sound()
    if not s then
        return
    end
    pcall(function()
        s.Volume = 0
        s.Parent = RawSoundService
    end)
    warmSound = s
end

local function play_hit_sound()
    if not CFG.HitSound then
        return
    end
    -- защита от дубля: звук зовётся и из network_hit, и из ForceHit
    local now = clock()
    if now - lastHitSoundAt < 0.04 then
        return
    end
    lastHitSoundAt = now

    --[[
        РОВНО КАК В BRM5 (silentaim.lua:950 playLocalHitSound):
            s.Parent = game:GetService("SoundService")
            s:Play()
            Debris:AddItem(s, 4)
        Никакого PlayLocalSound. Моя прошлая версия пробовала его ПЕРВЫМ и при
        успехе выходила — а он fire-and-forget: если ассет не в кэше именно в
        этот момент, звука нет, и до рабочего пути дело уже не доходило.
        Parent+Play держит Sound в дереве 4 секунды (Debris), поэтому ассет
        ��спевает догрузиться и звук всё равно играет.
    --]]
    --[[ Раньше здесь крутился цикл на CFG.HitSoundStack копий. Это был мой
         костыль против тихого звука, а настоящей причиной был потолок
         clamp(v, 0, 1) на громкости — он уже исправлен на реальные 0..10,
         поэтому складывать копии больше незачем, и настройка Stack убрана. ]]
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. tostring(CFG.HitSoundId)
        -- 0..10 — настоящий диапазон Roblox, раньше зде��ь стоял потолок 1
        s.Volume = clamp(CFG.HitSoundVolume, 0, 10)
        s.PlaybackSpeed = clamp(CFG.HitSoundPitch, 0.5, 2)
        s.Parent = RawSoundService
        s:Play()
        Debris:AddItem(s, 4)
        hitSoundRoute = "Parent+Play"
    end)
end

--======================================================================
--  HIT PARTICLES  (Wireframe / Orbs / Sparks)
--======================================================================
--======================================================================
--  ПУЛ Drawing для частиц (переиспользование вместо Drawing.new на выстрел)
--======================================================================
local drawPool = { Line = {}, Circle = {} }

local function acquire_draw(kind)
    local free = drawPool[kind]
    local obj = free[#free]
    if obj then
        free[#free] = nil
        obj.Visible = false
        return obj
    end
    obj = Drawing.new(kind)
    obj.ZIndex = 9
    obj.Visible = false
    return obj
end

local function release_draw(kind, obj)
    obj.Visible = false
    local free = drawPool[kind]
    if #free < 512 then
        free[#free + 1] = obj
    else
        pcall(function() obj:Remove() end)
    end
end

local function release_particle(particle)
    local kind = (particle.kind == "Line") and "Line" or particle.kind
    for _, drawing in ipairs(particle.draw) do
        release_draw(particle.kind, drawing)
    end
end

local TETRA = {
    verts = { V3(1, 1, 1), V3(1, -1, -1), V3(-1, 1, -1), V3(-1, -1, 1) },
    edges = { {1, 2}, {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4} },
}
local particleSystems = {}

local function lerp_color(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function spawn_particles(pos, normal)
    if not CFG.HitParticles then
        return
    end
    if #particleSystems >= CFG.HitParticleMaxSys then
        local old = table.remove(particleSystems, 1)
        if old then
            for _, particle in ipairs(old.parts) do
                release_particle(particle)
            end
        end
    end

    normal = (typeof(normal) == "Vector3" and normal.Magnitude > 0.01) and normal.Unit or V3(0, 1, 0)
    local right = normal:Cross(V3(0, 1, 0))
    if right.Magnitude < 0.01 then
        right = normal:Cross(V3(1, 0, 0))
    end
    right = right.Unit
    local fwd = normal:Cross(right).Unit

    local sys = { t = clock(), parts = {} }
    local count = clamp(CFG.HitParticleCount, 8, 48)
    for _ = 1, count do
        local theta = rnd() * pi * 2
        local phi = acos(clamp(1 - rnd() * 1.85, -1, 1))
        local dir = normal * cos(phi)
            + right * (sin(phi) * cos(theta))
            + fwd * (sin(phi) * sin(theta))
            + V3((rnd() - 0.5) * 0.35, (rnd() - 0.2) * 0.25, (rnd() - 0.5) * 0.35)
        if dir.Magnitude < 0.001 then
            dir = normal
        end
        dir = dir.Unit
        local z = rnd()
        local speed = CFG.HitParticleSpdMin + z * (CFG.HitParticleSpdMax - CFG.HitParticleSpdMin)
        local particle = {
            pos = pos + dir * rnd() * 0.12,
            vel = dir * speed + V3((rnd() - 0.5) * 5, rnd() * 4, (rnd() - 0.5) * 5),
            z = z,
            phase = rnd(),
            ang = rnd() * pi * 2,
            angVel = (rnd() - 0.5) * 4,
            scale = CFG.HitParticleWireS * (0.6 + z * 0.8),
            draw = {},
        }
        if CFG.HitParticleType == "Wireframe" then
            particle.kind = "Line"
            for _ = 1, #TETRA.edges do
                local line = acquire_draw("Line")
                line.Thickness = 0.7
                particle.draw[#particle.draw + 1] = line
            end
        elseif CFG.HitParticleType == "Orbs" then
            particle.kind = "Circle"
            local circle = acquire_draw("Circle")
            circle.Filled = true
            circle.NumSides = 12
            particle.draw[1] = circle
        else
            particle.kind = "Line"
            local line = acquire_draw("Line")
            line.Thickness = 1.5
            particle.draw[1] = line
        end
        sys.parts[#sys.parts + 1] = particle
    end
    particleSystems[#particleSystems + 1] = sys
end

local function update_particles(cam, dt)
    local duration = CFG.HitParticleDur
    local gravity = V3(0, CFG.HitParticleGrav, 0)
    local now = clock()
    for si = #particleSystems, 1, -1 do
        local sys = particleSystems[si]
        local age = now - sys.t
        if age > duration then
            for _, particle in ipairs(sys.parts) do
                release_particle(particle)
            end
            table.remove(particleSystems, si)
        else
            local fadeIn = duration * 0.15
            local fadeOut = duration * 0.75
            local fade
            if age < fadeIn then
                local t = age / fadeIn
                fade = t * (2 - t)
            elseif age > fadeOut then
                local t = (age - fadeOut) / (duration - fadeOut)
                fade = (1 - t) * (1 - t)
            else
                fade = 1
            end
            local pulseT = (sin(age * 3.2) + 1) * 0.5
            local step = min(dt, 0.05)
            local drag = clamp(1 - step * 0.35, 0.55, 1)
            for _, particle in ipairs(sys.parts) do
                particle.vel = (particle.vel + gravity * step) * drag
                particle.pos = particle.pos + particle.vel * step
                particle.ang = particle.ang + particle.angVel * step
                local screen, onScreen = cam:WorldToViewportPoint(particle.pos)
                local opacity = (CFG.HitParticleOpMin + (CFG.HitParticleOpMax - CFG.HitParticleOpMin) * particle.z) * fade
                local color = lerp_color(CFG.HitParticleColorA, CFG.HitParticleColorB, (pulseT + particle.phase) % 1)
                if onScreen and screen.Z > 0 then
                    if CFG.HitParticleType == "Wireframe" then
                        local s = particle.scale * (0.85 + 0.15 * sin(age * 4 + particle.phase))
                        local ca, sa = cos(particle.ang), sin(particle.ang)
                        local proj = {}
                        for vi, v in ipairs(TETRA.verts) do
                            local rotated = V3(v.X * ca - v.Z * sa, v.Y, v.X * sa + v.Z * ca) * s
                            local q, qo = cam:WorldToViewportPoint(particle.pos + rotated)
                            proj[vi] = qo and V2(q.X, q.Y) or nil
                        end
                        for ei, edge in ipairs(TETRA.edges) do
                            local line = particle.draw[ei]
                            local a, b = proj[edge[1]], proj[edge[2]]
                            if line and a and b then
                                line.Visible = true
                                line.Color = color
                                line.Thickness = 0.65 + particle.z * 0.45
                                line.Transparency = opacity
                                line.From = a
                                line.To = b
                            elseif line then
                                line.Visible = false
                            end
                        end
                    elseif CFG.HitParticleType == "Orbs" then
                        local circle = particle.draw[1]
                        if circle then
                            circle.Visible = true
                            circle.Color = color
                            circle.Transparency = opacity
                            circle.Position = V2(screen.X, screen.Y)
                            circle.Radius = max(0.45, (0.28 + particle.z * 0.62) * 17 / max(screen.Z, 1))
                        end
                    else
                        local line = particle.draw[1]
                        if line then
                            local tail = clamp(particle.vel.Magnitude * 0.035, 0.05, 0.9)
                            local q, qo = cam:WorldToViewportPoint(particle.pos - particle.vel.Unit * tail)
                            if qo then
                                line.Visible = true
                                line.Color = color
                                line.Transparency = opacity
                                line.From = V2(screen.X, screen.Y)
                                line.To = V2(q.X, q.Y)
                            else
                                line.Visible = false
                            end
                        end
                    end
                else
                    for _, drawing in ipairs(particle.draw) do
                        drawing.Visible = false
                    end
                end
            end
        end
    end
end

--======================================================================
--  SHOT TRACERS  (fade-кривая BRM5)
--======================================================================
local tracers = {}
local TRACER_MAX = 20
local tracerLines = {}
for i = 1, TRACER_MAX do
    local line = Drawing.new("Line")
    line.ZIndex = 30
    line.Visible = false
    tracerLines[i] = line
end

local function tracer_alpha(age, life, fadeIn)
    if age < fadeIn then
        local t = age / fadeIn
        return t * t
    end
    local tail = life - fadeIn
    if tail <= 0.01 then
        return 0
    end
    local t = (age - fadeIn) / tail
    return (1 - t) * (1 - t)
end

--======================================================================
--  FORCE HIT  +  отлов id пули  (ТОЛЬКО СВОИ выстр��лы)
--======================================================================
local claimedBullets = {}
local fire_hooked = false
local nh_hooked = false

local function hook_network_hit()
    if nh_hooked or not Caster then
        return
    end
    local original = rawget(Caster, "network_hit")
    if type(original) ~= "function" then
        return
    end
    rawset(Caster, "network_hit", function(id, targetId, parts, ...)
        --[[
            ВАЖНО: каждый эффект в СВОЁМ pcall.
            Раньше звук стоял последним в общем pcall вместе с поиском сущности
            и частицами — любая ошибка выше (нет сущности, сбо�� частиц) съедала
            вызов, и HitSound молчал.
        --]]
        pcall(function()
            claimedBullets[id] = true
        end)

        -- звук — пер��ым и независимо: он должен играть на любое попадание
        pcall(play_hit_sound)

        local hitName = nil
        pcall(function()
            local ent = entByIngame[tostring(targetId)]
            if not ent then
                return
            end
            local dmg = 0
            if type(parts) == "table" then
                for _, partName in pairs(parts) do
                    hitName = hitName or partName
                    if partName == "head" then
                        dmg += 100
                    elseif partName == "torso" then
                        dmg += 40
                    else
                        dmg += 22
                    end
                end
            end
            ent.__hp = max(0, (ent.__hp or 100) - (dmg > 0 and dmg or 22))
        end)

        -- частицы отдельно: их сбой не дол��ен глушить звук/урон
        pcall(function()
            if not CFG.HitParticles then
                return
            end
            local ent = entByIngame[tostring(targetId)]
            local model = ent and rawget(ent, "character")
            local part = model and (model:FindFirstChild(hitName or "torso") or model:FindFirstChild("torso"))
            if part then
                spawn_particles(part.Position, aim_origin() - part.Position)
            end
        end)

        return original(id, targetId, parts, ...)
    end)
    nh_hooked = true
end

local function hook_fire()
    if fire_hooked or not Caster then
        return
    end
    local original = rawget(Caster, "fire")
    if type(original) ~= "function" then
        return
    end
    rawset(Caster, "fire", function(player, origin, direction, user_data, character, ...)
        -- ТОЛЬКО наши пули: чужие идут с другим player и флагом replicated
        local isLocalShot = (player == LocalPlayer)
            and not (type(user_data) == "table" and user_data.replicated == true)

        if isLocalShot then
            local id = type(user_data) == "table" and user_data.id or nil
            local targetPos = Target.pos
            local targetEnt = Target.ent

            --[[
                ЛОКАЛЬНЫЙ ВИЗУАЛ СПУФА.
                Патч пакета меняет только то, что уходит на сервер. Локальная
                симуляция (трассер/пуля движка) стреляет из Н��СТОЯЩЕГО ствола,
                поэтому "визуально пуля летит с того же места". Подменяем origin
                и направление и для локального вызова — тогда MultiPoint видно.
            --]]
            if CFG.SpoofLocalVisual and CFG.SilentAim and targetPos and Target.spoof then
                if typeof(Target.spoof) == "Vector3" then
                    origin = Target.spoof
                    local toTarget = targetPos - Target.spoof
                    if toTarget.Magnitude > 0.001 then
                        direction = toTarget.Unit
                    end
                end
            end

            pcall(function()
                --[[ ОТКУДА РИСУЕМ ТРЕЙСЕР.
                    Берём sentOrigin — точку, которая РЕАЛЬНО ушла в пакете
                    (write_exact_position idx==1). Это не то же самое, что
                    Target.spoof: спуф подрезается бюджетом OriginBudget, и
                    если желаемая точка дальше бюджета, сервер видит
                    vec + off.Unit*budget. Рисуя от Target.spoof, трейсер врал
                    бы ровно на эту разницу.
                    Порядок вызовов позволяет так делать: па��ет пишется до
                    Caster.fire, поэтому к этому моменту sentOrigin уже свежий.
                    Fallback — реальное дуло, когда спуфа не было. ]]
                local from = sentOrigin or shotOrigin or origin
                if CFG.ShotTracers and typeof(from) == "Vector3" then
                    local dest = targetPos
                    if not dest and typeof(direction) == "Vector3" then
                        dest = from + direction * 400
                    end
                    if dest then
                        tracers[#tracers + 1] = { a = from, b = dest, t = clock() }
                    end
                end
            end)

            --[[ ═══ ВОТ П��ЧЕМУ КИКАЛО ЗА "network tampering" ═══════════════════
                Я неверно прочитал формат таблицы попаданий. Настоящий код —
                caster.penetrate_humanoid_char:266-268:

                    for _, v in pairs(u17) do          -- u17 = ИМЕНА частей
                        ...
                        local Magnitude = (p56.initial_origin - v63.Position).Magnitude
                        v59[v] = math.floor(Magnitude ~= Magnitude and 0 or Magnitude)

                то есть КЛЮЧ = имя ча��ти, ЗНАЧЕНИЕ = дистанция:
                    { torso = 37 }
                А я слал ЗЕРКАЛЬНО — { [37] = "torso" }. Сервер получал таблицу
                неверной формы и кикал за подмену пакета. Отсюда же и «SilentAim
                без ForceHit не работает»: урон в этой игре заявляет КЛИЕНТ через
                caster.network_hit (caster:285 -> dl_replicator:1439
                u18:SendToServer). Локальная пуля летит по исходному лучу, в цель
                не попадает, network_hit сам не вызывается — значит без ForceHit
                урона нет в принци��е. Теперь формат верный, и SilentAim раб����ает.

                Ещё два важных момента из того же кода:
                  * имя части допустимо ТОЛЬКО из u17 (caster:97):
                    left_arm_vis / right_arm_vis / left_leg_vis / right_leg_vis /
                    torso / head. Кость прицеливания приводим к этому списку.
                  * дистанция считается от initial_origin — РЕАЛЬНОГО ствола, а
                    не от ��пуфнутой точки. Раньше здесь стоял Target.spoof.
            ════���═════════���═══════════════════════════════════════════════════ ]]
            if CFG.ForceHit and id and targetPos and targetEnt then
                local ingameId = rawget(targetEnt, "ingame_id")
                local model = rawget(targetEnt, "character")
                if ingameId and model then
                    local partName = CFG.ForceHitPart
                    if partName == "auto" or partName == nil then
                        partName = (Target.bone and Target.bone.Name) or CFG.AimBone or "torso"
                    end
                    -- приводим к именам, которые принимает движок (caster:97)
                    partName = K.HIT_PART_ALIAS[partName] or partName
                    if not K.HIT_PART_VALID[partName] then partName = "torso" end

                    local hitPart = model:FindFirstChild(partName)
                    if hitPart == nil then
                        partName = "torso"
                        hitPart = model:FindFirstChild("torso")
                    end
                    local partPos = (hitPart and hitPart.Position) or targetPos
                    -- ВАЖНО: от реального ствола, как initial_origin в caster
                    local shotFrom = shotOrigin or origin
                    local dist = 0
                    if typeof(shotFrom) == "Vector3" and typeof(partPos) == "Vector3" then
                        dist = floor((partPos - shotFrom).Magnitude)
                    end
                    if dist ~= dist then dist = 0 end   -- NaN-guard, как в caster
                    local parts = { [partName] = dist }
                    local targetId = tonumber(ingameId) or tonumber(model.Name) or ingameId
                    task.delay(CFG.ForceHitDelay, function()
                        if not running or claimedBullets[id] then
                            return
                        end
                        --[[
                            HIT SOUND и здесь тоже.
                            При SilentAim ЛОКАЛЬНАЯ пуля летит по исходному
                            направлению (мы правим только па��ет), поэтому в цель
                            она обычно не попадает и caster.network_hit локально
                            НЕ вызывается — из-за этого звук и молчал.
                            Заявку о попадании шлём мы сами, значит и звук
                            воспроизводи�� здес��.
                        --]]
                        pcall(play_hit_sound)
                        pcall(function()
                            local nh = rawget(Caster, "network_hit")
                            if type(nh) == "function" then
                                nh(id, targetId, parts)
                            end
                        end)
                    end)
                end
            end

            if id then
                task.delay(3, function()
                    claimedBullets[id] = nil
                end)
            end
        end

        return original(player, origin, direction, user_data, character, ...)
    end)
    fire_hooked = true
end

--======================================================================
--  ВИЗУАЛЫ ПРИЦЕЛА  (FOV circle, muzzle lines, reticle)
--======================================================================
local fovCircle = Drawing.new("Circle")
fovCircle.NumSides = 64
fovCircle.ZIndex = 10
fovCircle.Visible = false

local muzzleLine = Drawing.new("Line")
muzzleLine.ZIndex = 44
muzzleLine.Visible = false

local spoofLineA = Drawing.new("Line")  -- д��ло -> спуф (жёлтая)
spoofLineA.ZIndex = 43
spoofLineA.Visible = false

local spoofLineB = Drawing.new("Line")  -- спуф -> цель (зелёная)
spoofLineB.ZIndex = 45
spoofLineB.Visible = false

local RETICLE_MAX = 16
local reticleLines = {}
for i = 1, RETICLE_MAX do
    local line = Drawing.new("Line")
    line.ZIndex = 45
    line.Visible = false
    reticleLines[i] = line
end

local function tier_color(tier)
    if CFG.AimVisualColor then
        return CFG.AimVisualColor
    end
    if tier == 0 then
        return Color3.fromRGB(120, 255, 120)
    elseif tier == 1 then
        return Color3.fromRGB(255, 220, 80)
    elseif tier == 2 then
        return Color3.fromRGB(120, 180, 255)
    end
    return Color3.fromRGB(255, 90, 90)
end

local function draw_reticle(cx, cy, color, now)
    for _, line in ipairs(reticleLines) do
        line.Visible = false
    end
    local sc = CFG.AimVisualScale
    local style = CFG.AimVisualStyle
    local baseAlpha = 0.95

    local function seg(i, x1, y1, x2, y2, thickness, alpha)
        local line = reticleLines[i]
        if not line then
            return
        end
        line.Visible = true
        line.From = V2(x1, y1)
        line.To = V2(x2, y2)
        line.Thickness = thickness
        line.Color = color
        line.Transparency = alpha or baseAlpha
    end

    if style == "Default" then
        local arm = 9 * sc
        seg(1, cx - arm, cy, cx + arm, cy, 1.4)
        seg(2, cx, cy - arm, cx, cy + arm, 1.4)
    elseif style == "CrossGap" then
        local gap = 5 * sc
        local arm = 9 * sc
        seg(1, cx - arm, cy, cx - gap, cy, 1.3)
        seg(2, cx + gap, cy, cx + arm, cy, 1.3)
        seg(3, cx, cy - arm, cx, cy - gap, 1.3)
        seg(4, cx, cy + gap, cx, cy + arm, 1.3)
    elseif style == "DefaultV2" then
        local spin = now * 2.8
        local gap = 4 * sc
        local arm = 8 * sc
        for i = 0, 3 do
            local ang = spin + i * pi * 0.5
            seg(i + 1,
                cx + cos(ang) * gap, cy + sin(ang) * gap,
                cx + cos(ang) * (gap + arm), cy + sin(ang) * (gap + arm), 1.35)
        end
    else -- Diamond (пульсирующий)
        local pulse = 0.5 + 0.5 * sin(now * 5.8)
        local r = (6.5 + pulse * 3.5) * sc
        local outerSpin = now * 1.6
        local idx = 0
        for i = 0, 5 do
            local a1 = outerSpin + i * pi / 3
            local a2 = outerSpin + (i + 1) * pi / 3
            idx += 1
            seg(idx, cx + cos(a1) * r, cy + sin(a1) * r,
                     cx + cos(a2) * r, cy + sin(a2) * r, 1.15 + pulse * 0.35)
        end
        local innerSpin = -now * 3.4
        local ig = (2.5 + pulse * 1.2) * sc
        local ia = (5.5 + pulse * 1.8) * sc
        for i = 0, 3 do
            local ang = innerSpin + i * pi * 0.5
            idx += 1
            seg(idx, cx + cos(ang) * ig, cy + sin(ang) * ig,
                     cx + cos(ang) * (ig + ia), cy + sin(ang) * (ig + ia), 1.5)
        end
        local accSpin = now * 4.2
        local tr = r + 2.2 + pulse * 1.5
        for i = 0, 5 do
            if idx >= RETICLE_MAX then
                break
            end
            local ang = accSpin + i * pi / 3
            idx += 1
            seg(idx, cx + cos(ang) * tr, cy + sin(ang) * tr,
                     cx + cos(ang) * (tr + 2.5), cy + sin(ang) * (tr + 2.5), 0.9, baseAlpha * 0.55 * pulse)
        end
    end
end

--======================================================================
--  ESP  —  Drawing-объекты ЗА МОДЕЛЬЮ (без переиспользования по индексу)
--======================================================================
local espByModel = {}

local function make_text(zindex, centered)
    local text = Drawing.new("Text")
    text.Outline = true
    text.Center = centered
    text.ZIndex = zindex
    text.Visible = false
    return text
end

local function new_esp()
    local o = {}
    o.boxLines = {}
    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.ZIndex = 20
        line.Visible = false
        o.boxLines[i] = line
    end
    o.name = make_text(22, true)
    o.dist = make_text(23, true)
    o.weapon = make_text(23, true)
    o.chips = {}
    for i = 1, 6 do
        o.chips[i] = make_text(23, false)
    end
    o.skel = {}
    for i = 1, 12 do
        local line = Drawing.new("Line")
        line.Thickness = 1.4
        line.ZIndex = 19
        line.Visible = false
        o.skel[i] = line
    end
    o.hpOutline = Drawing.new("Square")
    o.hpOutline.Filled = false
    o.hpOutline.Thickness = 1
    o.hpOutline.ZIndex = 17
    o.hpOutline.Color = Color3.fromRGB(8, 8, 8)
    o.hpOutline.Visible = false
    o.hpBg = Drawing.new("Square")
    o.hpBg.Filled = true
    o.hpBg.ZIndex = 18
    o.hpBg.Color = Color3.fromRGB(22, 22, 22)
    o.hpBg.Visible = false
    o.hpFill = Drawing.new("Square")
    o.hpFill.Filled = true
    o.hpFill.ZIndex = 19
    o.hpFill.Visible = false
    o.headCircle = Drawing.new("Circle")
    o.headCircle.Filled = false
    o.headCircle.Thickness = 1.4
    o.headCircle.NumSides = 16
    o.headCircle.ZIndex = 19
    o.headCircle.Visible = false
    o.smooth = nil
    return o
end

local function hide_esp(o)
    for _, line in ipairs(o.boxLines) do
        line.Visible = false
    end
    for _, chip in ipairs(o.chips) do
        chip.Visible = false
    end
    for _, line in ipairs(o.skel) do
        line.Visible = false
    end
    o.name.Visible = false
    o.dist.Visible = false
    o.weapon.Visible = false
    o.hpOutline.Visible = false
    o.hpBg.Visible = false
    o.hpFill.Visible = false
    o.headCircle.Visible = false
end

local function free_esp(o)
    for _, line in ipairs(o.boxLines) do
        pcall(function() line:Remove() end)
    end
    for _, chip in ipairs(o.chips) do
        pcall(function() chip:Remove() end)
    end
    for _, line in ipairs(o.skel) do
        pcall(function() line:Remove() end)
    end
    for _, drawing in ipairs({ o.name, o.dist, o.weapon, o.hpOutline, o.hpBg, o.hpFill, o.headCircle }) do
        pcall(function() drawing:Remove() end)
    end
end

local function adaptive_label_size(lineCount)
    local base = CFG.EspTextSize or ESPC.LabelSize
    if lineCount >= 5 then
        return base - 2
    end
    if lineCount >= 3 then
        return base - 1
    end
    return base
end

local function weapon_of(ent)
    local ok, name = pcall(function()
        local weapon = ent.equipped_weapon
        if not weapon then
            return nil
        end
        local props = weapon.build and weapon.build.result and weapon.build.result.properties
        if props then
            local general = props.generalData
            if general and general.name then
                return general.name
            end
            return props.name
        end
        return nil
    end)
    if ok and type(name) == "string" then
        return name
    end
    return nil
end

local function states_of(ent)
    local out = {}
    local ns = ent.ingame_id and netState[tostring(ent.ingame_id)]
    local fresh = ns and (clock() - (ns.t or 0) < 1.5)

    --[[ ДОБАВЛЕНО: ПОЧЕМУ РАНЬШЕ НЕ БЫЛО shooting.
         Здесь были только "fire"/"aim" из битового стрима, а стрим его просто
         НЕ НЕСЁТ: в parallel_replicator:219-296 упаковано ровно 11 бит
         (nvg, aiming, climbing, laser, flashlight, есть-ли-fire_multiplier,
         position, lean, look, barrel_look, pose) — и всё.

         Зато `ent` — это сам объект Character из dl_replicator, а он держит
         equipped_weapon.last_shot, куда on_fired_weapon:668 и
         on_fired_shotgun:738 пишут tick() на каждом выстреле. Отсюда и берём
         настоящий факт стрельбы, а старый "fire" оставляем как запасной. ]]
    local weapon = ent.equipped_weapon
    local lastShot = type(weapon) == "table" and weapon.last_shot or nil
    if lastShot and (tick() - lastShot) < 0.25 then
        out[#out + 1] = "shoot"
    elseif fresh and (ns.fire or 0) > 0.05 then
        out[#out + 1] = "fire"
    end
    if fresh and ns.aim then
        out[#out + 1] = "aim"
    end

    local pose = K.POSE_NAME[ent.pose]
    if pose == "idle" and (ent.cached_velocity_magnitude or 0) > 2 then
        pose = "walk"
    end
    if pose then
        out[#out + 1] = pose
    end
    if ent.using_nvg then
        out[#out + 1] = "nvg"
    end
    -- лазер и ф��нарь врага: видно, даже когда сам игрок за укрытием
    if type(weapon) == "table" then
        if weapon.laser_enabled      then out[#out + 1] = "laser" end
        if weapon.flashlight_enabled then out[#out + 1] = "light" end
    end
    return out
end

-- СТАБИЛЬНЫЙ bbox: HRP + верх головы + ноги, ширина = height*aspect, только Z>0
local function compute_bounds(cam, model)
    local hrp = model:FindFirstChild("humanoid_root_part")
    if not hrp then
        return nil
    end
    local head = model:FindFirstChild("head")
    local headWorld
    if head then
        headWorld = head.Position + V3(0, head.Size.Y * 0.5 + 0.3, 0)
    else
        headWorld = hrp.Position + V3(0, 2.6, 0)
    end
    local feetWorld = hrp.Position - V3(0, 3.0, 0)

    local topScreen, topInFront = cam:WorldToViewportPoint(headWorld)
    local botScreen = cam:WorldToViewportPoint(feetWorld)

    -- отбрасываем только если точка ЗА камерой (не по краю экрана)
    if topScreen.Z <= 0 or botScreen.Z <= 0 then
        return nil
    end

    local topY = min(topScreen.Y, botScreen.Y)
    local botY = max(topScreen.Y, botScreen.Y)
    local height = botY - topY
    if height < 1 then
        return nil
    end
    local width = height * CFG.EspBoxAspect
    local centerX = (topScreen.X + botScreen.X) * 0.5

    return {
        minX = centerX - width * 0.5,
        maxX = centerX + width * 0.5,
        minY = topY,
        maxY = botY,
        centerX = centerX,
        headTopY = topScreen.Y,
        height = height,
        width = width,
    }
end

local function draw_box(o, r, color)
    for _, line in ipairs(o.boxLines) do
        line.Visible = false
    end
    local w = r.maxX - r.minX
    local h = r.maxY - r.minY

    local function ln(i, x1, y1, x2, y2)
        local line = o.boxLines[i]
        if not line then
            return
        end
        line.Visible = true
        line.Color = color
        line.Thickness = CFG.EspBoxThickness
        line.From = V2(x1, y1)
        line.To = V2(x2, y2)
    end

    if CFG.EspBoxMode == "Corner" then
        -- длина у��олка = дол�� стороны, но не длиннее половины (иначе углы сойдутся).
        -- НЕ используем clamp с фикс. min: у мелкого бокса w*0.5 < min -> min>max -> ошибка.
        local cx = min(w * CFG.EspCornerScale, w * 0.5)
        local cy = min(h * CFG.EspCornerScale, h * 0.5)
        -- верх-лево
        ln(1, r.minX, r.minY, r.minX + cx, r.minY)
        ln(2, r.minX, r.minY, r.minX, r.minY + cy)
        -- верх-право
        ln(3, r.maxX - cx, r.minY, r.maxX, r.minY)
        ln(4, r.maxX, r.minY, r.maxX, r.minY + cy)
        -- низ-лево
        ln(5, r.minX, r.maxY - cy, r.minX, r.maxY)
        ln(6, r.minX, r.maxY, r.minX + cx, r.maxY)
        -- низ-право
        ln(7, r.maxX, r.maxY - cy, r.maxX, r.maxY)
        ln(8, r.maxX - cx, r.maxY, r.maxX, r.maxY)
    else
        ln(1, r.minX, r.minY, r.maxX, r.minY)
        ln(2, r.maxX, r.minY, r.maxX, r.maxY)
        ln(3, r.maxX, r.maxY, r.minX, r.maxY)
        ln(4, r.minX, r.maxY, r.minX, r.minY)
    end
end

-- настоящие суставы R6 (шея/таз/плечи/бёдра), красятся ЦВЕТОМ БОКСА
local function skeleton_segments(model)
    local torso = model:FindFirstChild("torso")
    if not torso then
        return nil
    end
    local tc = torso.CFrame
    local ts = torso.Size
    local neck   = (tc * CF(0,  ts.Y * 0.5, 0)).Position
    local pelvis = (tc * CF(0, -ts.Y * 0.5, 0)).Position
    local shoulderL = (tc * CF(-ts.X * 0.5, ts.Y * 0.42, 0)).Position
    local shoulderR = (tc * CF( ts.X * 0.5, ts.Y * 0.42, 0)).Position
    local hipL = (tc * CF(-ts.X * 0.25, -ts.Y * 0.5, 0)).Position
    local hipR = (tc * CF( ts.X * 0.25, -ts.Y * 0.5, 0)).Position

    local function tip(part)
        if not part then
            return nil
        end
        return (part.CFrame * CF(0, -part.Size.Y * 0.5, 0)).Position
    end

    local head = model:FindFirstChild("head")
    local armL = model:FindFirstChild("left_arm_vis")
    local armR = model:FindFirstChild("right_arm_vis")
    local legL = model:FindFirstChild("left_leg_vis")
    local legR = model:FindFirstChild("right_leg_vis")

    return {
        { head and head.Position or neck, neck },
        { neck, pelvis },
        { shoulderL, shoulderR },
        { neck, shoulderL }, { shoulderL, tip(armL) },
        { neck, shoulderR }, { shoulderR, tip(armR) },
        { pelvis, hipL }, { hipL, tip(legL) },
        { pelvis, hipR }, { hipR, tip(legR) },
    }
end

local function update_esp(cam, camPos, vp, model, ent, vis)
    local o = espByModel[model]
    if not o then
        o = new_esp()
        espByModel[model] = o
    end

    local hrp = model:FindFirstChild("humanoid_root_part")
    if not hrp then
        hide_esp(o)
        return
    end
    local depth = (camPos - hrp.Position).Magnitude
    if depth > CFG.EspMaxDistance or depth < 3 then
        hide_esp(o)
        return
    end
    local raw = compute_bounds(cam, model)
    if not raw then
        hide_esp(o)
        return
    end

    -- сглаживание, привязанн��е к объекту модели
    local r = raw
    if CFG.EspSmooth then
        local sm = o.smooth
        if not sm then
            sm = { minX = raw.minX, maxX = raw.maxX, minY = raw.minY, maxY = raw.maxY, headTopY = raw.headTopY }
            o.smooth = sm
        else
            local a = CFG.EspSmoothAlpha
            sm.minX = sm.minX + (raw.minX - sm.minX) * a
            sm.maxX = sm.maxX + (raw.maxX - sm.maxX) * a
            sm.minY = sm.minY + (raw.minY - sm.minY) * a
            sm.maxY = sm.maxY + (raw.maxY - sm.maxY) * a
            sm.headTopY = sm.headTopY + (raw.headTopY - sm.headTopY) * a
        end
        --[[ Результат складывается в ТУ ЖЕ таблицу, что и в прошлом кадре.
             Раньше здесь создавалась новая: одна таблица на каждого врага на
             каждом кадре, то есть при 20 видимых целях ~1200 таблиц в секунду
             в мусор — и всё это на пути, который обязан укладываться в кадр.
             Ниже r только читается, так что пере��спользов��ние безопасно. ]]
        local out = o.smoothOut
        if not out then
            out = {}
            o.smoothOut = out
        end
        out.minX, out.maxX = sm.minX, sm.maxX
        out.minY, out.maxY = sm.minY, sm.maxY
        out.centerX = (sm.minX + sm.maxX) * 0.5
        out.headTopY = sm.headTopY
        r = out
    end

    local color = vis and CFG.EspColorVisible or CFG.EspColorHidden

    local st = (CFG.EspShowStates and ent) and states_of(ent) or ESPC.EMPTY
    local lineCount = 1
        + (CFG.EspShowDistance and 1 or 0)
        + (CFG.EspShowWeapon and 1 or 0)
        + #st
    local labelSize = adaptive_label_size(lineCount)

    -- бокс
    if CFG.EspBox then
        draw_box(o, r, color)
    else
        for _, line in ipairs(o.boxLines) do
            line.Visible = false
        end
    end

    -- имя над боксом
    if CFG.EspShowName then
        o.name.Visible = true
        o.name.Size = labelSize + 1
        -- по умолчанию имя красится по видимости, но можно задать свой цвет
        o.name.Color = CFG.EspNameUseTier and color or CFG.EspColorName
        --[[ Text пишется только когда имя реально изменилось. Присваивание в
             Drawing-объект уходит за грани��у Lua в сам рендерер, поэтому оно
             куда дороже сравнения ��трок, а имя не меняется никогда. ]]
        local nm = tostring((ent and ent.player_name) or model.Name)
        if o.lastName ~= nm then
            o.lastName = nm
            o.name.Text = nm
        end
        o.name.Position = V2(r.centerX, r.headTopY - (labelSize + 1) - 4)
    else
        o.name.Visible = false
    end

    -- под боксом: строка 1 = дистанция, строка 2 = [ОРУЖИЕ] оранжевым
    local ly = r.maxY + ESPC.StackGap
    if CFG.EspShowDistance then
        o.dist.Visible = true
        o.dist.Size = labelSize
        o.dist.Color = CFG.EspColorDist
        --[[ Сравниваем ЦЕЛОЕ число метров, а не готовую строку: тогда при
             сближении на полметра не тратятся ни конкатенация, ни запись в
             рендерер — подпись всё равно показывает те же «12m». ]]
        local dm = floor(depth)
        if o.lastDist ~= dm then
            o.lastDist = dm
            o.dist.Text = dm .. "m"
        end
        o.dist.Position = V2(r.centerX, ly)
        ly = ly + labelSize * ESPC.LineStep + ESPC.StackGap
    else
        o.dist.Visible = false
    end
    if CFG.EspShowWeapon then
        local wname = ent and short_weapon(weapon_of(ent))
        if wname then
            o.weapon.Visible = true
            o.weapon.Size = labelSize
            o.weapon.Color = CFG.EspColorWeapon
            -- ор��жие меняется только при смене ствола, а не каждый кадр
            if o.lastWeapon ~= wname then
                o.lastWeapon = wname
                o.weapon.Text = "[" .. wname .. "]"
            end
            o.weapon.Position = V2(r.centerX, ly)
        else
            o.weapon.Visible = false
        end
    else
        o.weapon.Visible = false
    end

    -- HP bar слева
    local hp = ent and rawget(ent, "__hp")
    if CFG.EspHpBar and hp then
        local barW = 4
        local bx = r.minX - barW - 3
        local by = r.minY
        local bh = max(r.maxY - r.minY, 8)
        local pct = clamp(hp / 100, 0, 1)
        o.hpOutline.Visible = true
        o.hpOutline.Size = V2(barW + 2, bh + 2)
        o.hpOutline.Position = V2(bx - 1, by - 1)
        o.hpOutline.Transparency = 0.85
        o.hpBg.Visible = true
        o.hpBg.Size = V2(barW, bh)
        o.hpBg.Position = V2(bx, by)
        o.hpBg.Transparency = 0.7
        local fillH = max(bh * pct, 1)
        o.hpFill.Visible = true
        o.hpFill.Size = V2(barW, fillH)
        o.hpFill.Position = V2(bx, by + bh - fillH)
        o.hpFill.Transparency = 0.98
        -- градиент между настраиваемыми цветами вместо зашитой формулы RGB
        o.hpFill.Color = CFG.EspHpLow:Lerp(CFG.EspHpHigh, clamp(pct, 0, 1))
    else
        o.hpOutline.Visible = false
        o.hpBg.Visible = false
        o.hpFill.Visible = false
    end

    -- чипы состояний: столбик сверху вниз у правого края, с клампом в экран
    for i = 1, #o.chips do
        o.chips[i].Visible = false
    end
    if CFG.EspShowStates and #st > 0 then
        local chipSize = labelSize
        local sx = r.maxX + 6
        if sx + 44 > vp.X then
            sx = r.minX - 6 - 40
        end
        if sx < 2 then
            sx = 2
        end
        for i, label in ipairs(st) do
            local chip = o.chips[i]
            if not chip then
                break
            end
            local y = r.minY + (i - 1) * (chipSize + ESPC.ChipGap)
            if y + chipSize > vp.Y then
                break
            end
            chip.Visible = true
            chip.Size = chipSize
            chip.Text = label
            chip.Color = K.CHIP_COLOR[label] or CFG.EspColorDist
            chip.Center = false
            chip.Position = V2(sx, y)
        end
    end

    -- ��келет (цвет = цвет бокса)
    for _, line in ipairs(o.skel) do
        line.Visible = false
    end
    o.headCircle.Visible = false
    if CFG.EspSkeleton and depth <= CFG.EspSkeletonMaxDist then
        local segs = skeleton_segments(model)
        local k = 0
        if segs then
            for _, seg in ipairs(segs) do
                local a = seg[1]
                local b = seg[2]
                if a and b and k < #o.skel then
                    local p1 = cam:WorldToViewportPoint(a)
                    local p2 = cam:WorldToViewportPoint(b)
                    if p1.Z > 0 and p2.Z > 0 then
                        k = k + 1
                        local line = o.skel[k]
                        line.Visible = true
                        -- скелет может иметь свой ��вет, а не только тир видимости
                        line.Color = CFG.EspSkeletonOwnColor and CFG.EspSkeletonColor or color
                        line.Thickness = CFG.EspSkeletonThick or 1
                        line.From = V2(p1.X, p1.Y)
                        line.To = V2(p2.X, p2.Y)
                    end
                end
            end
        end
    end

    --[[ Head Circle раньше лежал ВНУТРИ блока `if CFG.EspSkeleton`, из-за чего
         его тумблер не работал без включённого скелета и ��олча пропадал за
         EspSkeletonMaxDist. Теперь это независимая опция. ]]
    local head = model:FindFirstChild("head")
    if CFG.EspHeadCircle and head then
        local hp2 = cam:WorldToViewportPoint(head.Position)
        if hp2.Z > 0 then
            local viewScale = (vp.Y * 0.5) / tan(rad((cam.FieldOfView or 70) * 0.5))
            o.headCircle.Visible = true
            o.headCircle.Color = color
            o.headCircle.Thickness = CFG.EspHeadCircleThick or 1
            o.headCircle.Position = V2(hp2.X, hp2.Y)
            o.headCircle.Radius = clamp((head.Size.Y * 0.6) * viewScale / max(depth, 1), 2, 11)
        end
    end
end

--======================================================================
--  CHAMS
--======================================================================
local hlHolder
local hlByModel = {}
pcall(function()
    hlHolder = Instance.new("Folder")
    hlHolder.Name = "\0"
    hlHolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)

local function set_chams(model, enabled, color)
    if not hlHolder then
        return
    end
    local hl = hlByModel[model]
    if enabled and CFG.EspChams then
        if not hl then
            pcall(function()
                hl = Instance.new("Highlight")
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee = model
                hl.Parent = hlHolder
                hlByModel[model] = hl
            end)
        end
        if hl then
            hl.Enabled = true
            --[[ Прозрачность раньше выставлялась ТОЛЬКО при создании Highlight,
                 поэтому ползунки Fill/Outline не давали никакого эффекта на уже
                 отрисо��анных иг��оках. Обновляем каждый кадр. ]]
            hl.FillTransparency = CFG.EspChamsFillTrans
            hl.OutlineTransparency = CFG.EspChamsOutTrans
            hl.FillColor = color
            hl.OutlineColor = color
        end
    elseif hl then
        hl.Enabled = false
    end
end

--======================================================================
--  СБОРКА МУСОРА КЭШЕЙ  (по ис��езнувшим ��оделям)
--======================================================================
local function gc_caches()
    for model, hl in pairs(hlByModel) do
        if not model or model.Parent == nil then
            pcall(function() hl:Destroy() end)
            hlByModel[model] = nil
        end
    end
    for model, o in pairs(espByModel) do
        if not model or model.Parent == nil then
            free_esp(o)
            espByModel[model] = nil
        end
    end
    for model in pairs(visCacheT) do
        if not model or model.Parent == nil then
            visCacheT[model] = nil
            visCacheV[model] = nil
        end
    end
    for model in pairs(velTrack) do
        if not model or model.Parent == nil then
            velTrack[model] = nil
        end
    end
    --[[ mpCache теперь слабый по ключам (__mode = "k") и ключ �� сама кость:
         уничтоженные части уходят сборщиком сами, ручная зачистка по времени
         не нужна. Просроченные записи всё равно отбрасываются по ttl. ]]
end

--======================================================================
--  MUZZLE CROSSHAIR
--======================================================================
--[[ Прицел в точке перед реальным дулом, а не в центре экрана.
     Зачем: ствол в игре смещён от оси камеры, поэтому пуля выходит НЕ из
     ��ентра. У стены, из-за укрытия или при наклоне разница доходит до
     нескольких градусов, и центральный прицел прямо врёт. Точку берём на
     MuzzleCrossDist вперёд по стволу, чтобы линия ствола была видна как
     конкретное место на экране, а не как невидимое направление. ]]
do      -- своя область видимости: см. форвард-декларации выше

local muzzleCross = nil

function muzzle_cross_free()
    if muzzleCross == nil then return end
    for _, d in ipairs(muzzleCross) do
        pcall(function() d:Remove() end)
    end
    muzzleCross = nil
end

local function muzzle_cross_build()
    local t = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Visible = false
        t[i] = l
    end
    local dot = Drawing.new("Circle")
    dot.Filled = true
    dot.NumSides = 10
    dot.Radius = 1.5
    dot.Visible = false
    t.dot = dot
    t[5] = dot
    return t
end

local function muzzle_cross_hide()
    if muzzleCross == nil then return end
    for _, d in ipairs(muzzleCross) do
        d.Visible = false
    end
end

--[[ HS — состояние и хелперы прицела по дулу и HUD одной таблицей. Тело скрипта
     это одна функция, а у Luau лимит 200 локальных регистров на функцию, и он
     тут уже достигнут (см. комментарий к K выше — по той же причине). Девять
     отдельных локалов валили компиляцию с "Out of local registers", поэтому всё
     новое живёт полями HS: лишний hash-lookup в этих местах ничего не стоит.

       spin      — накопленный угол вращения прицела. Копится по dt, а не
                   берётся от os.clock: иначе скорость зависела бы от того,
                   сколько скрипт уже работает, а смена знака скорости давала
                   бы рывок вместо разворота с текущего угла.
       bands     — число полос градиента панели. Восемь: дальше пол��сы уже не
                   различимы глазом на панели та��ой высоты, а объекты и такты
                   рендера тратятся. При выключенном градиенте рисуется одна.
       fade      ��� прозрачность панели (появление и скрытие).
       anim      — сглаженные доли заполнения полосок ПО ПОДПИСИ строки. Ключ
                   именно подпись, а не номер: набор показателей включается на
                   ходу, и при нумерации значение HEALTH перетекало бы в
                   полоску STAMINA просто потому, что та заняла её место.
       posLoaded — позиция панели уже прочитана с диска (читаем один раз). ]]
local HS = { spin = 0, bands = 8, fade = 0, anim = {}, posLoaded = false }

function update_muzzle_cross(cam, dt)
    if not CFG.MuzzleCross then
        muzzle_cross_hide()
        return
    end

    --[[ С ГРАНАТОЙ В РУКАХ ПРИЦЕЛА БЫТЬ НЕ ДОЛЖНО.
         Прицел отмечает точку выхода пули, а у метательного ствола нет — вместо
         него работает дуга броска. Раньше проверки не было: muzzle_cframe()
         находил у гранаты какой-нибудь receiver и рисовал крест, который вёл
         вообще не туда, куда полетит граната. Тип оружия читаем той же
         проверкой, что и движок перед броском (throwable_key_map:19). ]]
    if holding_throwable() then
        muzzle_cross_hide()
        return
    end

    local cf = muzzle_cframe()
    if cf == nil then
        muzzle_cross_hide()
        return
    end

    muzzleCross = muzzleCross or muzzle_cross_build()

    local target = cf.Position + cf.LookVector * CFG.MuzzleCrossDist
    local sp, onScreen = cam:WorldToViewportPoint(target)
    if not (onScreen and sp.Z > 0) then
        muzzle_cross_hide()
        return
    end

    local x, y = sp.X, sp.Y
    local gap = CFG.MuzzleCrossGap
    local len = CFG.MuzzleCrossSize
    local col = CFG.MuzzleCrossColor
    local th = CFG.MuzzleCrossThick

    --[[ Четыре штри��а с отступо�� от центра: сплошной крест закрывал бы саму
         точку выхода пули, а разрыв в середине оставляет её видимой.

         Штрихи задаются не готовыми координатами, а НАПРАВЛЕНИЯМИ от центра:
         так один и тот же код рисует и обычный крест, и повёрнутый — угол
         просто прибавляется к б��зовому направлению каждого штриха. ]]
    if CFG.MuzzleCrossSpin then
        HS.spin = (HS.spin + CFG.MuzzleCrossSpinSpd * (dt or 0)) % 360
    else
        HS.spin = 0
    end
    local a0 = rad(HS.spin)

    for i = 1, 4 do
        -- базовые направления: влево, вправо, вверх, вниз (шаг 90°)
        local a = a0 + rad(90 * (i - 1))
        local dx, dy = cos(a), sin(a)
        local l = muzzleCross[i]
        l.From = V2(x + dx * gap, y + dy * gap)
        l.To = V2(x + dx * (gap + len), y + dy * (gap + len))
        l.Color = col
        l.Thickness = th
        l.Transparency = 1
        l.Visible = true
    end

    local dot = muzzleCross.dot
    if CFG.MuzzleCrossDot then
        dot.Position = V2(x, y)
        dot.Radius = max(1, th)
        dot.Color = col
        dot.Transparency = 1
        dot.Visible = true
    else
        dot.Visible = false
    end
end

--======================================================================
--  ИНДИКАТОР СОСТОЯНИЯ (HUD)
--======================================================================
--[[ Панель из Drawing-объектов: фон, акцентная полоса слева, заголовок и
     строки «подпись — значение» с необязательной полоской заполнения.

     Объекты создаются ОДИН раз и переиспользуются: пересоздавать Drawing
     каждый кадр — гарантированное мельтешение и утечка, как это уже было в
     ESP до перехода на пул. Строк фиксированный максимум, лишние просто
     скрываются. ]]
local HUD_ROWS = 8
local HUD_BAR_SEGS = 8          -- сегментов на градиент одной полоски
local hud = nil
local hudDragging, hudGrabDX, hudGrabDY = false, 0, 0

--[[ ── ЦВЕТА ПОЛОСОК ─────────────────────────────────────────────────────
     Полоски были БЕЛЫМИ не по замыслу: заливка лерпилась в CFG.HudText (236,
     238, 242), то есть при высоком значении приходила ровно в цвет текста. Из
     этого выходило сразу три беды — белый спо��ил с акцентом пан��ли, разные
     показатели выглядели одинаково, и никакого градиента не было вообще.

     Теперь у каждого показателя свой цвет, и он же задаёт градиент: от
     затемнённого варианта к самому цвету. Ключ — стабильный id строки, а не
     подпись, чтобы переименование подписи не ломало ни цвет, ни сглаживание.

     HP — единственный показатель, который меняет цвет по значению: он
     переезжает от красного к зелёному, потому что низкое HP это то, на что
     нужно реагировать. Остальные держат свой тон и показывают уровень длиной. ]]
local HUD_BAR = {
    hp      = { low = Color3.fromRGB(232, 48, 42), full = Color3.fromRGB(74, 208, 116) },
    stamina = { full = Color3.fromRGB(64, 178, 232) },
    arms    = { full = Color3.fromRGB(238, 176, 62) },
    ammo    = { full = Color3.fromRGB(255, 122, 48) },
    adren   = { full = Color3.fromRGB(178, 118, 238) },
}
local HUD_BAR_DARK = Color3.fromRGB(12, 13, 16)


function hud_free()
    if hud == nil then return end
    for _, d in ipairs(hud.all) do
        pcall(function() d:Remove() end)
    end
    hud = nil
end

local function hud_build()
    local o = { all = {}, rows = {} }
    local function keep(d)
        o.all[#o.all + 1] = d
        return d
    end

    --[[ Фон и акцентная полоса — наборы полос для ��радиента (см. CFG.HudGradient).
         Акцентная полоса слева — единственный «яркий» элемент панели; всё
         остальное намеренно тихое, чтобы HUD не спорил с ESP за внимание. ]]
    --[[ ZIndex у всех объектов панели задан ЯВНО. При равном ZIndex порядок
         определяется порядком создания, а полосы фон�� и акцента создаются в
         одном ц��кл�� — без явных слоёв полоса фона перекрывала бы акцент,
         созданный до неё. ]]
    o.bgBands, o.accBands = {}, {}
    for i = 1, HS.bands do
        local b = keep(Drawing.new("Square"))
        b.Filled = true
        b.ZIndex = 0
        b.Visible = false
        o.bgBands[i] = b

        local a = keep(Drawing.new("Square"))
        a.Filled = true
        a.ZIndex = 1
        a.Visible = false
        o.accBands[i] = a
    end

    o.edge = keep(Drawing.new("Square"))
    o.edge.Filled = false
    o.edge.Thickness = 1
    o.edge.ZIndex = 2
    o.edge.Visible = false

    o.title = keep(Drawing.new("Text"))
    o.title.Center = false
    o.title.Outline = false
    o.title.ZIndex = 4
    o.title.Visible = false

    for i = 1, HUD_ROWS do
        local r = {}
        r.label = keep(Drawing.new("Text"))
        r.label.Center = false
        r.label.Outline = false
        r.label.ZIndex = 4
        r.label.Visible = false

        r.value = keep(Drawing.new("Text"))
        r.value.Center = false
        r.value.Outline = false
        r.value.ZIndex = 4
        r.value.Visible = false

        r.barBg = keep(Drawing.new("Square"))
        r.barBg.Filled = true
        r.barBg.ZIndex = 2
        r.barBg.Visible = false

        --[[ ЗАЛИВКА ПОЛОСКИ — НАБОР СЕГМЕНТОВ, А НЕ ОДИН КВАДРАТ.
             Drawing.Square заливается ровно одним цветом, поэтому градиент по
             длине можно получить только несколькими квадратами подряд — тем же
             приёмом, что уже используется для фона панели (bgBands). Раньше тут
             стоял единственный барFill, из-за чего полоски и были плоскими.
             Сегменты создаются один раз на строку и переиспользуются. ]]
        r.barSegs = {}
        for k = 1, HUD_BAR_SEGS do
            local s = keep(Drawing.new("Square"))
            s.Filled = true
            s.ZIndex = 3
            s.Visible = false
            r.barSegs[k] = s
        end

        o.rows[i] = r
    end
    return o
end

local function hud_hide()
    if hud == nil then return end
    for _, d in ipairs(hud.all) do
        d.Visible = false
    end
end

--[[ Чтение показателей. Каждое обращение в pcall: сборка оружия и контроллер
     перестраиваются при смене предмета и на респавне, и в этот момент любая
     ветка цепочки может быть nil. Отсутствующее значение — это не ошибка,
     строка просто не рисуется. ]]
--[[ ЗДЕСЬ pcall НЕ НУЖЕН, и это проверено по исходнику игры.
     SHARED_STATE — обычная Lua-таблица, а её значения это
     `setmetatable({}, u2)` с `u2.__index = u2` (shared_state:14-23, 492), то
     есть .value — простое поле простой таблицы. Ни свойств Instance, ни
     __index-функции здесь нет, поэтому упасть чтению нечем, а nil на любом
     шаге ловится проверками.
     Раньше тело лежало в pcall(function() ... end): замыкание создаётся при
     КАЖДОМ вызове, а вызывается это трижды за ка��р (стамина, руки и мод
     бесконечных рук) — то есть pcall только ради страховки, которая по
     устройству игры никогда не срабатывает. ]]
local function hud_shared_max(key, fallback)
    local sv = SHARED and SHARED[key]
    local v = sv and sv.value
    if type(v) == "number" then
        return v
    end
    return fallback
end

--[[ Патрон в патроннике СОЗНАТЕЛЬНО не показывается отдельным «+1».
     Игровой интерфейс пишет так (MagazineStats:115), но здесь это только шум:
     строка скачет между «30» и «29+1» при каждом выстреле, а полезного в этом
     ничего — стрелять можно и тем патроном, и этим. Показываем ровно остаток
     в магазине: 30/30, 29/30 и так далее. ]]
local function hud_ammo()
    if ctrl == nil then return nil end
    local rounds, cap
    pcall(function()
        rounds = ctrl.weapon.ammo.rounds_in_magazine
    end)
    if type(rounds) ~= "number" then return nil end
    pcall(function()
        cap = ctrl.weapon.build.result.stats.magazine_capacity
    end)
    return rounds, cap
end


--[[ ПОЗИЦИЯ ПАНЕЛИ МЕЖДУ ЗАПУСКАМИ — через FAL Data API MacLib.

     Почему именно он. Позиция задаётся мышью, а не UI-элементом, поэтому в
     config-систему она не попадает: Save/Load работают только с флагованными
     элементами. Свой автосейв здесь писать нельзя — ровно такая самодельная
     таблица Persist когда-то и писа��а весь CFG на диск за спиной пользователя
     (см. блок «ПЕРСИСТЕНТНОСТЬ НАСТРОЕК — НЕ ЗДЕСЬ»). FALSetData — штатный
     механизм библиотеки для данных, не привязанных к элементу.

     MacLib берётся и�� окружения и проверяе��ся на наличие самих методов: модуль
     запускается загрузчиком, но может быть запущен и напрямую. Если библиотеки
     нет — позиция просто не сохраняется, всё остальное работает.

     Хелперы тоже поля HS, а не локальные функции — ровно по той же причине,
     по которой в HS собрано состояние: свободных регистров в этой функции нет. ]]
HS.posKey = "DLSA_HudPos"

function HS.maclib()
    local m = nil
    pcall(function()
        local g = getgenv and getgenv()
        m = g and rawget(g, "MacLib")
    end)
    if type(m) == "table" and type(m.FALSetData) == "function"
        and type(m.FALGetData) == "function" then
        return m
    end
    return nil
end

function HS.posLoad()
    if HS.posLoaded then return end
    HS.posLoaded = true
    local m = HS.maclib()
    if m == nil then return end
    pcall(function()
        local d = m:FALGetData(HS.posKey, nil)
        if type(d) ~= "table" then return end
        -- каждое поле проверяем отдельно: файл мог быть записан прошлой
        -- версией, где части этих ключей ещё не было
        if type(d.x) == "number" then CFG.HudX = d.x end
        if type(d.y) == "number" then CFG.HudY = d.y end
        if type(d.mx) == "number" then CFG.HudMuzzleOffX = d.mx end
        if type(d.my) == "number" then CFG.HudMuzzleOffY = d.my end
    end)
end

--[[ Пишем только по отпусканию мыши, а не на каждый кадр перетаскив��ния:
     иначе это была бы запись файла ~60 раз в секунду всё время, пока панель
     держат мышью. ]]
function HS.posSave()
    local m = HS.maclib()
    if m == nil then return end
    pcall(function()
        m:FALSetData(HS.posKey, {
            x = CFG.HudX, y = CFG.HudY,
            mx = CFG.HudMuzzleOffX, my = CFG.HudMuzzleOffY,
        })
    end)
end

--[[ Перетаскивание. Работает ТОЛЬКО когда курсор свободен: в бою ЛКМ — это
     выстрел, и без этой проверки панель уползала бы при каждой стрельбе.
     Свободный курсор в этой игре означает открытое меню, так что условие
     заодно и есть «режим настройки».

     Принимает и возвращает фактический прямоугольник панели: в режиме привязки
     к дулу «позиция» — это не CFG.HudX/Y, а вычисленная точка, и тащить надо
     смещение от дула, иначе панель дёргалась бы обратно к дулу сразу же. ]]
local function hud_update_drag(w, h, px, py)
    --[[ Отпускание мыши = конец перетаскивания и момент записи позиции.
         Проверяется во всех выходах, поэтому вынесено в локальную функцию. ]]
    local function release()
        if hudDragging then
            hudDragging = false
            HS.posSave()
        end
    end

    --[[ Проверяется и CFG.Hud: выключенная панель ещё несколько кадров
         дорисовывается затуханием, и без этого её можно было бы схватить
         мышью уже после выключения. ]]
    if not CFG.Hud then
        release()
        return px, py
    end

    --[[ ─�� ПОЧЕМУ РЕЖИМ ПЕРЕМЕЩЕНИЯ ТЕПЕРЬ ЯВНЫЙ ──────────────────────────
         Раньше условием было «курсор свободен»:
             UIS.MouseBehavior == Enum.MouseBehavior.Default
         и именно из-за него панель не бралась мышью. MouseBehavior в этой игре
         не наш: set_mouse_focus:62-71 ПРИНУДИТЕЛЬНО ставит LockCenter каждый
         раз, когда пересчитывается состояние игрового UI, а MacLib ставит
         Default, когда открывает окно. Двое писателей одного свойства — и то,
         что мы читаем в кадре, зависит от того, кто записал последним. Отсюда и
         «нажимаю, а оно не перемещается»: захват срабатывал через раз.

         Гадать, кто победил, бессмысленно, поэтому спрашиваем не игру, а
         пользователя: пока включён Move HUD, панель тащится мышью. Это заодно
         снимает и старый риск — в бою ЛКМ это выстрел, а с явным режимом панель
         не может уползти во время стрельбы, потому что режим выключен. ]]
    if not CFG.HudMove then
        release()
        return px, py
    end

    local down = false
    pcall(function()
        down = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    end)

    local mp
    pcall(function() mp = UIS:GetMouseLocation() end)
    if mp == nil or not down then
        release()
        return px, py
    end

    --[[ ── ВОТ ПОЧЕМУ ПАНЕЛЬ ТАК И НЕ ТАЩИЛАСЬ ──────────────────────���──────
         Тумблер Move HUD был только половиной дела. Вторая ��оловина — системы
         координат, и они РАЗНЫЕ:

           • Drawing рисует в АБСОЛЮТНЫХ пикселях окна, считая от самого верха,
             включая полосу Roblox сверху;
           • UIS:GetMouseLocation() отдаёт позицию БЕЗ этой полосы, то есть
             смещённую вверх на GetGuiInset().

         Панель рисуется по первым координатам, а попадание проверялось по
         вторым. Разница по Y — высота топбара (обычно 36 px), и она больше,
         чем высота строки HUD. То ест�� кликать надо было заметно НИЖЕ панели,
         примерно в пустое место, — со стороны это выглядит как «нажимаю, и
         ничего не происходит».

         Приводим мышь в ту же систему, в которой нарисована панель. ]]
    local mx, my = mp.X, mp.Y
    pcall(function()
        local inset = game:GetService("GuiService"):GetGuiInset()
        mx, my = mx + inset.X, my + inset.Y
    end)

    if not hudDragging then
        --[[ Захват только если нажали ВНУТРИ панели, иначе любой клик по меню
             телепортировал бы HUD под курсор. Небольшой допуск по краям: панель
             узкая, и попасть точно в пиксель мышью неудобно. ]]
        local pad = 6
        if mx >= px - pad and mx <= px + w + pad
            and my >= py - pad and my <= py + h + pad
        then
            hudDragging = true
            hudGrabDX = mx - px
            hudGrabDY = my - py
        end
        return px, py
    end

    local nx, ny = mx - hudGrabDX, my - hudGrabDY
    if CFG.HudAnchor == "Muzzle" then
        --[[ При привязке слева панель растёт влево от дула, то есть рост
             HudMuzzleOffX уводит её В ОБРАТНУЮ от курсора сторону. Без этого
             знака панель при левой привязке убегала бы от мыши. ]]
        local sgn = (CFG.HudMuzzleSide == "Left") and -1 or 1
        CFG.HudMuzzleOffX = CFG.HudMuzzleOffX + (nx - px) * sgn
        CFG.HudMuzzleOffY = CFG.HudMuzzleOffY + (ny - py)
    else
        CFG.HudX, CFG.HudY = nx, ny
    end
    return nx, ny
end

function update_hud(cam, dt)
    --[[ Выключенная панель ещё несколько кадров дорисовывается — это и есть
         анимация скрытия. Полный выход только когда затухание закончилось,
         иначе панель пропадала бы мгновенно, как раньше. ]]
    if not CFG.Hud and (hud == nil or HS.fade <= 0.02 or not CFG.HudAnim) then
        HS.fade = 0
        hud_hide()
        return
    end
    hud = hud or hud_build()
    HS.posLoad()

    --[[ Затухание па��ели. Шаг ��ажат в 0..1: на просадке кадра dt большой, и без
         зажима значение перелетало бы цель и дёргалось вокруг неё. ]]
    local aStep = clamp(clamp(CFG.HudAnimSpeed, 1, 30) * dt, 0, 1)
    if CFG.HudAnim then
        HS.fade = HS.fade + ((CFG.Hud and 1 or 0) - HS.fade) * aStep
    else
        HS.fade = CFG.Hud and 1 or 0
    end
    local fade = clamp(HS.fade, 0, 1)
    if fade <= 0.02 then
        hud_hide()
        return
    end

    local sc = clamp(CFG.HudScale, 0.6, 2.5)
    local fs = floor(13 * sc + 0.5)          -- размер строки
    local ts = floor(12 * sc + 0.5)          -- размер заголовка
    local pad = floor(8 * sc + 0.5)
    --[[ ВЫСОТА СТРОКИ СЧИТАЕТСЯ ПО СОДЕ��ЖИМОМУ.
         Раньше шаг был фиксированный (16*sc), а полоска рисовалась на 15*sc от
         верха строки — то есть залезала на текст следующей. Теперь строка с
         полоской занимает на barGap+barH больше, и панель ровно по контенту:
         строки без полосок от этого не раздуваются. ]]
    local textH = fs + floor(3 * sc + 0.5)
    local barGap = floor(2 * sc + 0.5)
    local barH = max(2, floor(3 * sc + 0.5))
    local width = floor(148 * sc + 0.5)

    --[[ Собираем строки заранее: высота панел�� зависит от того, сколько
         показателей включено, поэтому фон нельзя рисовать до подсчёта. ]]
    local rows = {}
    --[[ id — стабильный ключ строки (цвет полоски и сглаживание), label — то,
         что видно. Разделены, чтобы правка подписи не сбрасывала анимацию. ]]
    local function push(id, label, value, frac)
        if #rows >= HUD_ROWS then return end
        rows[#rows + 1] = { id = id, label = label, value = value, frac = frac }
    end

    if CFG.HudAmmo then
        local r, cap = hud_ammo()
        if r then
            local txt = tostring(floor(r))
            if type(cap) == "number" and cap > 0 then
                txt = txt .. " / " .. tostring(floor(cap))
                push("ammo", "Ammo", txt, clamp(r / cap, 0, 1))
            else
                push("ammo", "Ammo", txt, nil)
            end
        end
    end

    if CFG.HudHealth and ctrl then
        local hp
        pcall(function() hp = ctrl.health end)
        if type(hp) == "number" then
            local mx = hud_shared_max("plr_initial_health", 100)
            if mx <= 0 then mx = 100 end
            push("hp", "HP", ("%d"):format(floor(hp + 0.5)), clamp(hp / mx, 0, 1))
        end
    end

    if CFG.HudStamina and ctrl then
        local st
        pcall(function() st = ctrl.stamina end)
        if type(st) == "number" then
            -- 120, а не 100: это значение самой игры (shared_state:252).
            -- Со «круглым» фолбэком полная стамина показывалась бы как 83%.
            local mx = hud_shared_max("plr_max_stamina", 120)
            if mx <= 0 then mx = 120 end
            push("stamina", "Stamina",
                ("%d%%"):format(floor(clamp(st / mx, 0, 1) * 100)),
                clamp(st / mx, 0, 1))
        end
    end

    if CFG.HudArms and ctrl then
        local st
        pcall(function() st = ctrl.arm_stamina end)
        if type(st) == "number" then
            -- 60, а не 100 (shared_state:259): иначе полные руки показывались
            -- бы как 60%, �� Infinite Arm Stamina выглядел бы неработающим.
            local mx = hud_shared_max("plr_max_arm_stamina", 60)
            if mx <= 0 then mx = 60 end
            push("arms", "Arms",
                ("%d%%"):format(floor(clamp(st / mx, 0, 1) * 100)),
                clamp(st / mx, 0, 1))
        end
    end

    if CFG.HudAdrenaline and ctrl then
        local ad
        pcall(function() ad = ctrl.adrenaline end)
        if type(ad) == "number" then
            push("adren", "Adrenaline", ("%.0f"):format(ad), clamp(ad / 100, 0, 1))
        end
    end

    if CFG.HudSpeed then
        --[[ ── СТРОКА SPEED НИКОГДА НЕ ПОКАЗЫВАЛАСЬ ─────────────────────────
             Дело в имени детали: искали "HumanoidRootPart", а риг этой игры
             собран в snake_case — "humanoid_root_part" (Ragdoll:23,
             parallel_replicator:75). FindFirstChild возвращал nil, sp оставался
             nil, push не вызывался: тумблер включаешь, а строки нет.

             Плюс персонаж здесь не всегда Instance — контроллер отдаёт и
             таблицу, поэтому читаем оба варианта (как get_hrp в модуле
             движения, где это уже сделано правильно). ]]
        local sp
        pcall(function()
            local ch = LocalPlayer and LocalPlayer.Character
            local hrp
            if typeof(ch) == "Instance" then
                hrp = ch:FindFirstChild("humanoid_root_part")
            elseif type(ch) == "table" then
                hrp = rawget(ch, "humanoid_root_part")
            end
            if hrp then
                local v = hrp.AssemblyLinearVelocity
                sp = V3(v.X, 0, v.Z).Magnitude
            end
        end)
        if type(sp) == "number" then
            push("speed", "Speed", ("%.1f"):format(sp), nil)
        end
    end

    --[[ FPS и PING УДАЛЕНЫ СОВСЕМ (по прямой просьбе, повторно).
         Заодно ушли и их источники: счётчик кадров крутился в update_hud на
         каждом кадре, а пинг лазил по GetService("Stats") и разбирал строку из
         PerformanceStats — обе работы делались даже когда строки не показаны. ]]

    if #rows == 0 then
        hud_hide()
        return
    end

    local titleH = floor(18 * sc + 0.5)
    local bars = CFG.HudBars

    --[[ Высота панели — сумма фактических высот строк (см. textH выше). ]]
    local height = pad * 2 + titleH
    for i = 1, #rows do
        height = height + textH
        if bars and rows[i].frac then height = height + barGap + barH end
    end

    --[[ ПРИВЯЗКА К ДУЛУ. Панель ставится рядом с реальным дулом, а не в центр
         экрана: смысл тот же, что у прицела по дулу — то, что относится к
         оружию, читается там, где оружие. Если дула нет (пустые руки, респавн)
         или оно за камерой, и��пользуется фиксированная позиция: пропадающая
         панель хуже неподвижной. ]]
    local x, y
    if CFG.HudAnchor == "Muzzle" then
        local mcf = muzzle_cframe()
        if mcf then
            local sp = cam:WorldToViewportPoint(mcf.Position)
            if sp.Z > 0 then
                if CFG.HudMuzzleSide == "Left" then
                    x = sp.X - CFG.HudMuzzleOffX - width
                else
                    x = sp.X + CFG.HudMuzzleOffX
                end
                -- по вертикали центрируем панель на дуле
                y = sp.Y - height * 0.5 + CFG.HudMuzzleOffY
            end
        end
    end
    if x == nil then
        x, y = CFG.HudX, CFG.HudY
    end

    x, y = hud_update_drag(width, height, x, y)

    --[[ Держим панель в пределах экр��на: после смены разрешения или
         перетаскивания к краю она иначе осталась бы за кадром навсегда, и
         сбросить её было бы нечем. В фиксированном режиме зажатое зн��чение
         пишется обратно в CFG, в режиме дула — только в позицию отрисовки:
         писать его в смещение значило бы, что панель, прижатая к краю экрана,
         навсегда теряет заданный отступ от дула. ]]
    local vp = cam.ViewportSize
    x = clamp(x, 0, max(0, vp.X - width))
    y = clamp(y, 0, max(0, vp.Y - height))
    if CFG.HudAnchor ~= "Muzzle" then
        CFG.HudX, CFG.HudY = x, y
    end
    x, y = floor(x), floor(y)

    hud_hide()

    local accentW = max(2, floor(2 * sc + 0.5))
    --[[ Полосы градиента. Каждая на 1px выше расчётной: высота полосы дробная,
         и без перекрытия на округлении между полосам�� появлялись бы волосяные
         щели, сквозь которые ��идно игру. ]]
    local nb = CFG.HudGradient and HS.bands or 1
    local bh = height / nb
    for i = 1, nb do
        local t = (nb > 1) and ((i - 1) / (nb - 1)) or 0
        local by = y + (i - 1) * bh
        local bhi = floor(bh) + 1

        local b = hud.bgBands[i]
        b.Position = V2(x, floor(by))
        b.Size = V2(width, bhi)
        b.Color = CFG.HudGradient and CFG.HudBg:Lerp(CFG.HudBg2, t) or CFG.HudBg
        b.Transparency = 0.82 * fade
        b.Visible = true

        local a = hud.accBands[i]
        a.Position = V2(x, floor(by))
        a.Size = V2(accentW, bhi)
        a.Color = CFG.HudGradient and CFG.HudAccent:Lerp(CFG.HudAccent2, t)
            or CFG.HudAccent
        a.Transparency = fade
        a.Visible = true
    end

    hud.edge.Position = V2(x, y)
    hud.edge.Size = V2(width, height)
    hud.edge.Color = CFG.HudAccent
    hud.edge.Transparency = 0.28 * fade
    hud.edge.Visible = true

    local left = x + pad + accentW
    hud.title.Text = "Status"
    hud.title.Size = ts
    hud.title.Color = CFG.HudAccent
    hud.title.Position = V2(left, y + pad)
    hud.title.Transparency = fade
    hud.title.Visible = true

    local cy = y + pad + titleH
    for i = 1, #rows do
        local r = rows[i]
        local row = hud.rows[i]

        row.label.Text = r.label
        row.label.Size = fs
        row.label.Color = CFG.HudDim
        row.label.Position = V2(left, cy)
        row.label.Transparency = fade
        row.label.Visible = true

        --[[ Значение прижимаем к правому краю: Drawing.Text не умеет
             выравнивание, поэтому сдвигаем по измеренной ширине текста.
             Сам текст ставится БЕЗ сглаживания — см. CFG.HudAnim. ]]
        row.value.Text = r.value
        row.value.Size = fs
        row.value.Color = CFG.HudText
        local tw = 0
        pcall(function() tw = row.value.TextBounds.X end)
        row.value.Position = V2(x + width - pad - tw, cy)
        row.value.Transparency = fade
        row.value.Visible = true

        cy = cy + textH

        if bars and r.frac then
            --[[ Доля заполнения подтягивается к цели, а не прыгает: аптечка и
                 перезарядка меняют значение одним скачком, и полоска без
                 сглаживания просто телепортировалась бы. ]]
            local shown = HS.anim[r.id]
            if shown == nil or not CFG.HudAnim then
                shown = r.frac
            else
                shown = shown + (r.frac - shown) * aStep
            end
            HS.anim[r.id] = shown

            local bw = width - pad * 2 - accentW
            row.barBg.Position = V2(left, cy)
            row.barBg.Size = V2(bw, barH)
            row.barBg.Color = CFG.HudDim
            row.barBg.Transparency = 0.25 * fade
            row.barBg.Visible = true

            --[[ Цвет по показателю (см. HUD_BAR). У HP он ещё и зависит от
                 значения — от красного к зелёному; у остальных тон постоянный, а
                 уровень читается длиной. Неизвестный id падает на акцент
                 панели, так что новая строка не окажется невидимой. ]]
            local pal = HUD_BAR[r.id]
            local base = CFG.HudAccent
            if pal then
                base = pal.low and pal.low:Lerp(pal.full, clamp(shown, 0, 1))
                    or pal.full
            end

            --[[ Заливка идёт сегментами слева направо: от за��емнённого цвета к
                 полному. Ноль ширины Drawing не любит, поэтому минимум 1px.
                 Градиент считается по ДОЛЕ ЗАПОЛНЕНИЯ, а не по всей ширине
                 полоски, — иначе при низком значении был бы виден только тёмный
                 конец, и полоска выглядела бы погасшей. ]]
            local fw = max(1, floor(bw * clamp(shown, 0, 1)))
            local segW = fw / HUD_BAR_SEGS
            for k = 1, HUD_BAR_SEGS do
                local s = row.barSegs[k]
                local t = (k - 1) / (HUD_BAR_SEGS - 1)
                s.Position = V2(left + floor((k - 1) * segW), cy)
                -- +1px перекрытие: убирает щели на округлении дробной ширины
                s.Size = V2(floor(segW) + 1, barH)
                s.Color = HUD_BAR_DARK:Lerp(base, 0.35 + t * 0.65)
                s.Transparency = 0.95 * fade
                s.Visible = true
            end

            cy = cy + barGap + barH
        end
    end
end

end     -- область видимости HUD / muzzle crosshair

--======================================================================
--  ГЛАВНЫЙ ЦИКЛ РЕНДЕРА
--======================================================================
local lastFrame = clock()
local lastResolve = 0

conns[#conns + 1] = (cloneref and cloneref(game:GetService("RunService"))
    or game:GetService("RunService")).RenderStepped:Connect(function()
    if not running then
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then
        return
    end
    local now = clock()
    local dt = now - lastFrame
    lastFrame = now
    local camPos = cam.CFrame.Position
    local vp = cam.ViewportSize

    --[[ ��то мы — каждый кадр. Это чистый rawget по lifetime_state, поэтому
         бесплатно, зато после респавна ствол/лучи/моды сразу берут живое тело
         (раньше до секунды работал труп). ]]
    refresh_local()

    --[[ Каждый кадр, сразу после refresh_local: лерпы прицела живут в текущем
         fp_controller, а игра пересчитывает их в своём апдейте. ]]
    apply_instant_aim()

    --[[ Каждый кадр по той же причине: игра сливает выносливость рук в своём
         heartbeat, поэтому редкое восстановление дрожь не убирает. Почему не
         в apply_mods — см. комментарий к CFG.InfArmStamina. ]]
    apply_arm_stamina()

    --[[ Тоже каждый кадр: игра пересозда��т риг при смене ор��жия, поэтому
         покраску надо пере-применять, иначе она молча пропадает. ]]
    pcall(apply_rig_style, now)

    -- резолв цели ТРОТТЛИТСЯ; между резолвами — только проверка живости
    validate_target()
    if now - lastResolve >= CFG.AimResolveInterval then
        lastResolve = now
        pcall(resolve_target)
    end

    -- FOV circle
    if CFG.FovCircle and CFG.SilentAim then
        fovCircle.Visible = true
        fovCircle.Radius = fov_radius_px(cam)
        fovCircle.Position = V2(vp.X * 0.5, vp.Y * 0.5)
        fovCircle.Color = Target.pos and tier_color(Target.tier) or CFG.FovCircleColor
        fovCircle.Transparency = 1 - CFG.FovCircleTrans
        fovCircle.Thickness = CFG.FovCircleThick
        fovCircle.Filled = CFG.FovCircleFilled
    else
        fovCircle.Visible = false
    end

    -- muzzle / spoof линии (визуализация MultiPoint)
    muzzleLine.Visible = false
    spoofLineA.Visible = false
    spoofLineB.Visible = false
    if CFG.MuzzleVisual and Target.pos then
        -- фолбэк: если ствол/вьюмодель ещё не готовы, берём точку чуть ниже
        -- камеры — иначе линия периодически пропадала при аиме
        local mcf = muzzle_cframe()
        local muzzlePos = mcf and mcf.Position
        if not muzzlePos then
            muzzlePos = camPos - V3(0, 1, 0)
        end
        if muzzlePos then
            --[[
                ВАЖНО: второй возврат WorldToViewportPoint — это "точка внутри
                прямоугольника экрана", а НЕ "перед камерой". Дуло проецируется
                у самого низа/кра�� экрана и часто даёт false -> линия пропадала.
                Для ЛИНИЙ нужен только признак "перед камерой" = screen.Z > 0,
                выход за край экрана нормален.
            --]]
            local mScreen = cam:WorldToViewportPoint(muzzlePos)
            local tScreen = cam:WorldToViewportPoint(Target.pos)
            local mFront = mScreen.Z > 0
            local tFront = tScreen.Z > 0
            local spoofed = Target.spoof and (Target.spoof - muzzlePos).Magnitude > 0.05
            if not spoofed then
                if mFront and tFront then
                    muzzleLine.Visible = true
                    muzzleLine.Color = CFG.MuzzleLineColor
                    muzzleLine.Thickness = CFG.MuzzleLineThick
                    muzzleLine.Transparency = 1 - CFG.MuzzleLineTrans
                    muzzleLine.From = V2(mScreen.X, mScreen.Y)
                    muzzleLine.To = V2(tScreen.X, tScreen.Y)
                end
            else
                local sScreen = cam:WorldToViewportPoint(Target.spoof)
                local sFront = sScreen.Z > 0
                if mFront and sFront then
                    spoofLineA.Visible = true
                    spoofLineA.Color = Color3.fromRGB(255, 200, 60)
                    spoofLineA.Thickness = 1.4
                    spoofLineA.Transparency = 0.7
                    spoofLineA.From = V2(mScreen.X, mScreen.Y)
                    spoofLineA.To = V2(sScreen.X, sScreen.Y)
                end
                if sFront and tFront then
                    spoofLineB.Visible = true
                    spoofLineB.Color = Color3.fromRGB(120, 255, 180)
                    spoofLineB.Thickness = 2.2
                    spoofLineB.Transparency = 0.8
                    spoofLineB.From = V2(sScreen.X, sScreen.Y)
                    spoofLineB.To = V2(tScreen.X, tScreen.Y)
                end
                -- фолбэк: спуф не спроецировался — показываем обычную линию,
                -- чтобы визуал прицела не про��адал
                if not spoofLineA.Visible and not spoofLineB.Visible and mFront and tFront then
                    muzzleLine.Visible = true
                    muzzleLine.Color = CFG.MuzzleLineColor
                    muzzleLine.Thickness = CFG.MuzzleLineThick
                    muzzleLine.Transparency = 1 - CFG.MuzzleLineTrans
                    muzzleLine.From = V2(mScreen.X, mScreen.Y)
                    muzzleLine.To = V2(tScreen.X, tScreen.Y)
                end
            end
        end
    end

    -- reticle на цели
    if CFG.AimVisuals and Target.pos then
        local tScreen = cam:WorldToViewportPoint(Target.pos)
        if tScreen.Z > 0 then
            draw_reticle(tScreen.X, tScreen.Y, tier_color(Target.tier), now)
        else
            for _, line in ipairs(reticleLines) do
                line.Visible = false
            end
        end
    else
        for _, line in ipairs(reticleLines) do
            line.Visible = false
        end
    end

    -- shot tracers c fade
    if CFG.ShotTracers then
        local li = 0
        for i = #tracers, 1, -1 do
            local tr = tracers[i]
            local age = now - tr.t
            if age > CFG.TracerDuration then
                table.remove(tracers, i)
            elseif li < TRACER_MAX then
                local p1 = cam:WorldToViewportPoint(tr.a)
                local p2 = cam:WorldToViewportPoint(tr.b)
                if p1.Z > 0 and p2.Z > 0 then
                    li = li + 1
                    local line = tracerLines[li]
                    local alpha = tracer_alpha(age, CFG.TracerDuration, CFG.TracerFadeIn)
                    line.Visible = true
                    line.Thickness = CFG.TracerThickness + alpha * 0.5
                    line.Color = CFG.TracerColor:Lerp(Color3.new(1, 1, 1), alpha * 0.18)
                    line.Transparency = alpha
                    line.From = V2(p1.X, p1.Y)
                    line.To = V2(p2.X, p2.Y)
                end
            end
        end
        for i = li + 1, TRACER_MAX do
            tracerLines[i].Visible = false
        end
    else
        for i = 1, TRACER_MAX do
            tracerLines[i].Visible = false
        end
    end

    pcall(update_particles, cam, dt)

    --[[ Гранаты обновляем ЗДЕСЬ, до ранних return'ов ESP ниже: иначе при
         выключенном ESP цикл выходил бы раньше и траектории замирали. ]]
    --[[ ДИАГНОСТИКА: ловим ТЕКСТ ошибки, а не глотаем её. Именно поэтому раньше
         "predicting" печаталось, а "draw_arc" — нет: внутри всё падало, а голый
         pcall прятал причину. Теперь err печатается (throttled). ]]
    if update_grenades then
        local ok, err = pcall(update_grenades)
        if not ok then diag("gerr", "update_grenades: " .. tostring(err)) end
    end
    if update_grenade_aim then
        local ok, err = pcall(update_grenade_aim)
        if not ok then diag("aerr", "update_grenade_aim: " .. tostring(err)) end
    end

    --[[ HUD и прицел по дулу ��� последними в кадре: они только читают уже
         посчитанное состояние, поэтому цифры совпадают с тем, что вид��о. ]]
    pcall(update_muzzle_cross, cam, dt)
    pcall(update_hud, cam, dt)

    -- ESP
    if not CFG.ESP then
        for _, o in pairs(espByModel) do
            hide_esp(o)
        end
        return
    end
    local folder = Workspace:FindFirstChild("characters")
    if not folder then
        for _, o in pairs(espByModel) do
            hide_esp(o)
        end
        return
    end
    -- LocalPlayer.Character в этой игре всегда nil: берём модель из lifetime_state
    local myChar = myCharacter
    local seen = {}
    for _, model in ipairs(folder:GetChildren()) do
        if model ~= myChar then
            local ent = entByModel[model]
            if is_enemy(ent, CFG.EspEnemyOnly) then
                seen[model] = true
                local vis = true
                if CFG.EspVisibleCheck then
                    vis = is_visible(camPos, model)
                end
                pcall(update_esp, cam, camPos, vp, model, ent, vis)
                -- у chams может быть собственная пара цветов, независимая от бокса
                set_chams(model, true, CFG.EspChamsOwnColor
                    and (vis and CFG.EspChamsColorVis or CFG.EspChamsColorHid)
                    or  (vis and CFG.EspColorVisible or CFG.EspColorHidden))
            end
        end
    end
    -- гасим тех, ��ого не рисовали в этом кадре
    for model, o in pairs(espByModel) do
        if not seen[model] then
            hide_esp(o)
            set_chams(model, false)
        end
    end
end)

--======================================================================
--  CUSTOM FOV РУК (ВЬЮМОДЕЛИ)
--======================================================================
--[[ У игры одна камера, отдельного FOV рук нет. Каждый кадр игра ставит
     viewmodel.root_part.CFrame = render_rootpart_cframe (FPC:1544), а весь риг
     рук приварен к root_part. «FOV рук» = масштаб смещения root_part от камеры:
         rel = cam:ToObjectSpace(root.CFrame)   -- поза рук в осях камеры
         k   = tan(baseFov/2) / tan(vmFov/2)     -- vmFov<base -> k>1 -> ближе
         root.CFrame = cam.CFrame * rel_с_масштабированной_позицией
     Масштабируем ТОЛЬКО позицию (ориентацию не трогаем). baseFov берём живым из
     cam.FieldOfView: игра меняет его при ADS/спринте, руки должны следовать.

     ПОЧЕМУ ПРОШЛАЯ ВЕРСИЯ НЕ РАБОТАЛА (BindToRenderStep):
     игра двигает вьюмодель НЕ через BindToRenderStep, а обычным
     RunService.RenderStepped:Connect (ClientScheduler:87 гоняет Timescale.
     renderstep_connections). А Roblox ВСЕГДА выполняет ВСЕ BindToRenderStep-
     колбеки ПЕРЕД любыми RenderStepped:Connect в том же кадре. Значит наш
     BindToRenderStep срабатывал ДО игрового апдейта, и игра затирала нас каждый
     кадр — эффекта ноль.

     ФИКС: сами вешаемся на RenderStepped:Connect. Для одного события порядок
     колбеков = порядок подключения, а игровой ClientScheduler подключается при
     загрузке (задолго до запуска скрипта), поэтому наш обработчик идёт ПОСЛЕ
     игрового и перекрывает root_part последним. Восстанав��ивать не нужно —
     игра перезапишет CFrame в следующем кадре. ]]
local RS_SVC = (cloneref and cloneref(game:GetService("RunService")))
    or game:GetService("RunService")

conns[#conns + 1] = RS_SVC.RenderStepped:Connect(function()
    if not running or not CFG.VmFOVEnabled or ctrl == nil then
        --[[ Если фичи не видно — печатаем, ПОЧЕМУ гейт закрыт: чаще всего
             VmFOVEnabled=false (тумблер в меню выключен). ]]
        dfov(string.format("gate: running=%s enabled=%s ctrl=%s",
            tostring(running), tostring(CFG.VmFOVEnabled), tostring(ctrl ~= nil)))
        return
    end
    local cam = Workspace.CurrentCamera
    if cam == nil then return end
    --[[ ГЛАВНЫЙ ФИКС FOV: ДВИГАЕМ НЕ ТУ ЧАСТЬ, ЧТО РАНЬШЕ.
         Прошлая версия трогала ctrl.weapon.viewmodel.root_part — и лог
         подтверждал, что она РАБОТАЕТ (run base=.. vm=.. root=root_part), но
         визуально НОЛЬ. Причина: игра рендерит вьюмодель, выставляя КАЖДЫЙ КАДР
         ctrl.root_part.CFrame = render_rootpart_cframe (FirstPersonController
         :1544, где self==ctrl==fp_controller). Весь риг рук/оружия приварен к
         ЭТОЙ part через Motor6D ctrl.root_part.weapon (FPC:1345,1520). А
         ctrl.weapon.viewmodel.root_part — ДРУГАЯ part, к рендеру отношения не
         имеет, поэтому её сдвиг ничего не менял.
         Теперь берём ctrl.root_part (с фолбэком на старую), и т.к. наш
         RenderStepped:Connect подключён ПОЗЖЕ игрового (ClientScheduler:70), мы
         перезаписываем CFrame последними в кадре — сдвиг виден. ]]
    pcall(function()
        local root = ctrl.root_part
        if root == nil then
            pcall(function() root = ctrl.weapon.viewmodel.root_part end)
        end
        if typeof(root) ~= "Instance" then dfov("no root_part") return end

        local baseFov = cam.FieldOfView
        local vmFov = clamp(CFG.VmFOV, 20, 120)
        dfov(string.format("run base=%.1f vm=%.1f root=%s", baseFov, vmFov, root.Name))
        if math.abs(vmFov - baseFov) < 0.01 then return end

        --[[ Масштаб смещения вьюмодели от камеры = tan(base/2)/tan(vm/2).
             vm>base -> k<1 -> руки ближе (крупнее); vm<base -> дальше (мельче).
             Трогаем только позицию, ориентацию рига оставляем. ]]
        local k = math.tan(math.rad(baseFov) * 0.5) / math.tan(math.rad(vmFov) * 0.5)
        local rel = cam.CFrame:ToObjectSpace(root.CFrame)
        local scaled = CFrame.new(rel.Position * k) * (rel - rel.Position)
        root.CFrame = cam.CFrame * scaled
    end)
end)

--======================================================================
--  WEAPON MODS
--======================================================================
-- SHARED поднят �� началу файла: его читает предикт (replication_rollback)

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

--[[ Ключи отдачи разбиты по осям, чтобы гасить их процентно по отдельности.
     v    — подбрасывает ствол вверх (вертикаль)
     h    — уводит в стороны и крутит оружие (горизонталь)
     both — общие множители, к оси не ��ривязаны: б��рём максимум из двух,
            иначе выкрученная вертикаль резалась бы нулевой горизонталью. ]]
--[[ ══ ПОЧЕМУ NO RECOIL РАНЬШЕ НЕ РАБОТАЛ (найдено по дампу) ══════════════════
     Игра сама предоставляет механизм переопределения отдачи. rifle_methods
     читает каждое значение так (строки 236-244, 249-257, 296-304 и далее):

         local vertical_recoil = u27.debug_values.vertical_recoil
         if vertical_recoil.changed then
             v51 = vertical_recoil.value          -- <== НАШ путь
         elseif recoil_traits.vertical_recoil == nil then
             v51 = vertical_recoil.value
         else
             v51 = recoil_traits.vertical_recoil  -- родное значение ствола
         end

     То есть достаточно выставить .value и .changed = true.

     СТАРЫЙ КОД ИСКАЛ ЭТУ ТАБЛИЦУ ЧЕРЕЗ filtergc И ОТБРАКОВЫВАЛ ЕЁ:
     фильтр требовал rawget(field, "changed") ~= nil, а в исходной таблице
     (framework/util/recoil_debug_values) поля changed ПРОСТО НЕТ — там только
     { min, max, value }. Поле появляется лишь ПОСЛЕ первой зап��си. Поэтому
     проверка всегда давала nil, таблица не проходила фильтр, и не патчилось
     НИЧЕГО — ни отдача, ни тр��ска камеры.

     ТЕПЕРЬ: берём таблицу напрямую через require. ClientFramework:185 делает
     `u61.debug_values = RECOIL_DEBUG_VALUES`, то есть это ОДНА И ТА ЖЕ ссылка,
     что и у фреймворка — filtergc не нужен вовсе.

     ТРЯСКА КАМЕРЫ (жалоба «трясёт даже при нулевой отдаче»). Она приходит НЕ
     из plr_recoil: тот множитель влияет только н�� одну величину
     (rifle_methods:204). За тряску отвечают отдельные пружины камеры
     camera_recoil / camera_lag_recoil / rotation_recoil / roll_recoil, поэтому
     они вынесены в СВОЮ ось `cam` с отдельным ползунком.
     ВАЖНО: camera_lag_recoil по умолчани�� ОТРИЦАТЕЛЕН (-0.1, min = -2),
     поэтому значения т��лько МАСШТАБИРУЮТСЯ от исходных и никогда не
     клампятся к нулю снизу — иначе мы вышли бы за диапазон ключа. ]]
--[[ ══ ПОЧЕМУ NO RECOIL ЛОМАЛ ТЕЛО И КАМЕРУ (жалоба «тело отсоединяется от
     камеры, не могу ��вигать камерой») ═════════════════════════════════════════
     В группе `both` лежал ключ animation_weight. Он НЕ является величиной
     отдачи. rifle_methods:426-443 использует его так:

         v78 = animation_weight.value            -- (или трейт ствола)
         v30.bone_weights.receiver = {
             { v78*rnd, v78*rnd, v78*rnd },
             { v78*rnd, v78*rnd, v78*rnd } }

     То есть это ВЕС КОСТЕЙ РИГА оружия/рук. При выкрученном в ноль ползунке
     он становился 0, все шесть весов обнулялись, р��г переставал привязывать
     ресивер к камере — отсюда «тело отсоединяется». Ключ убран полностью:
     к отдаче он отношения не имеет и патчить его незачем.

     Заодно снят progressive_increment: это ШАГ НАРАСТАНИЯ отдачи в очереди
     (rifle_methods:207-218 накапливает progressive_recoil_multiplier), а не
     сила отдачи. Оси v/h/cam уже режут результат, так что трогать накопитель
     нет смысла — а его зануление мешало игре сбрасыв��ть множитель.

     ══ ГЛАВНОЕ, ЧЕГО Я НЕ УЧЁЛ РАНЬШЕ: vertical/horizontal — ЭТО НЕ СИЛА ══
     Из-за этого «ползунки ни на что не влияли», а потом «на 100% отдачи нет».
     Смотрим, что игра делает с этими двумя ключами (rifle_methods:260-278):

         v52 = Vector2.new(rnd * horizontal_recoil, rnd * vertical_recoil)
         v54 = v52.Unit * v44          -- ← ВЕКТОР НОРМАЛИЗУЕТСЯ

     `.Unit` выбрасывает длину. Значит vertical_recoil и horizontal_recoil
     задают ТОЛЬКО НАПРАВЛЕНИЕ отбоя (соотношение осей), а величину целиком
     определяет v44. Сколько бы мы ни резали эти два ключа, суммарная отдача
     не менялась — она лишь наклонялась в другую сторону. Отсюда первый
     симптом: ползунки кр��тятся, ощущения те же.

     Хуже: при обоих ключах в нуле получается v52 = (0,0), а (0,0).Unit —
     это NaN. NaN уходит в last_fire_direction и в пружины камеры
     (rifle_methods:279, 294, 319), после чего отдача не «уменьшается», а
     полностью разваливается. Отсюда второй симптом — «отдача отрубается».

     Настоящая сила лежит в двух местах:
       1) v44 = v43 * SHARED_STATE.plr_recoil.value * 1.5 * прогрессия
          (rifle_methods:204). plr_recoil — «Global recoil multiplier»,
          дефолт 1 (shared_state:173, insi_shared_state_descriptions:209).
          Это и есть честный множитель ВЕЛИЧИНЫ отдачи.
       2) camera_recoil / roll_recoil / camera_lag_recoil — множители
          пружин камеры (rifle_methods:307 `v57 * (v58 * 0.1)`), то есть
          то, что игрок ВИДИТ как подброс.

     Поэтому теперь:
       • Vertical/Horizontal задают величину через plr_recoil, а между собой
         делят направление (пропорция сохраняется);
       • оба в нуле → plr_recoil = 0, а веса направления остаются РОДНЫМИ,
         чтобы .Unit считался от нормального вектора и NaN не возникал;
       • 100/100 = ровно как в игре (множитель 1, веса не тронуты). ]]
local RECOIL = {
    --[[ Веса НАПРАВЛЕНИЯ (не силы) — идут в нормализуемый вектор. ]]
    dirV = "vertical_recoil",
    dirH = "horizontal_recoil",
    --[[ knockback — честная величина: масштабирует отбой оружия по Z
         (rifle_methods:419), нормализация его не касается. ]]
    mag  = { "knockback" },
    cam  = { "camera_recoil", "camera_lag_recoil", "rotation_recoil",
             "roll_recoil", "weapon_roll_recoil" },
    base = {},   -- исходные значения по ИМЕНИ ключа (таблица одна на весь сеанс)
}
K.SWAY_KEYS = { "sway_recoil", "aim_sway_recoil" }

--[[ Прямой доступ к таблице отдачи. Требуется один раз, дальше кэш.
     Никакого filtergc и никакого периодического рескана. ]]
local DBGV = nil
local function get_debug_values()
    if DBGV then return DBGV end
    pcall(function()
        DBGV = require(RS.framework.util.recoil_debug_values).RECOIL_DEBUG_VALUES
    end)
    -- запасной путь: если модуль переехал — ищем таблицу по характерным кл��чам
    if type(DBGV) ~= "table" then
        DBGV = nil
        local ok, found = pcall(filtergc, "table",
            { Keys = { "vertical_recoil", "camera_recoil", "knockback" } }, false)
        if ok and type(found) == "table" then
            for _, tbl in ipairs(found) do
                local probe = rawget(tbl, "vertical_recoil")
                -- ТОЛЬКО .value: поля .changed в свежей таблице ещё нет
                if type(probe) == "table" and type(rawget(probe, "value")) == "number" then
                    DBGV = tbl
                    break
                end
            end
        end
    end
    return DBGV
end

--[[ Масштабируем ключ от ЕГО ИСХОДНОГО значения: после перв��го зануления
     умножать было бы уже нечего (0 * pct = 0) и вернуть отдачу ползунком
     стало бы невозможно. Исходники запоминаем по имени ключа — таблица
     debug_values одна на весь сеанс, так что этого достаточно. ]]
local function scale_group(tbl, keys, keep, traits)
    for _, key in ipairs(keys) do
        local field = rawget(tbl, key)
        if type(field) == "table" then
            --[[ Отладочный дефолт запоминаем ОДИН раз: он нужен и как база для
                 стволов без своего трейта, и чтобы корректно снять мод. ]]
            local def = RECOIL.base[key]
            if def == nil then
                local cur = rawget(field, "value")
                if type(cur) ~= "number" then
                    continue        -- не число: не наша ось, не трогаем
                end
                def = cur
                RECOIL.base[key] = def
            end

            --[[ ── ОТ ЧЕГО СЧИТАЕМ ПРОЦЕНТ ────��────────────────────────────
                ЗДЕСЬ И БЫЛА ПРИЧИНА «ПОЛЗУНКИ НИ НА ЧТО НЕ ВЛИЯЮТ».
                Раньше базой служило значение из debug_values, то е��ть ОДИН
                ОБЩИЙ отладочный дефолт на всю игру (horizontal_recoil = 0.4,
                camera_recoil = 0.75 и т.д. — recoil_debug_values:20-35).
                Но у каждого ствола отдача своя, и лежит она в
                properties.firing.recoil_traits: дв��жок берёт debug-значение
                ТОЛЬКО если у оружия нет своего трейта (rifle_methods:239-245).

                Из-за этого 100% на ползунке означало «поставить всем стволам
                одинаковую усреднённую отдачу», а не «оставить как в игре».
                На стволах, чья родная отда��а близка к дефолту, разница между
                крайними положениями почти не читалась — ползунок выглядел
                мёртвым. На пистолете, где родное значение заметно больше,
                100% ощущались как «отдачи нет» — тот самый второй симптом.

                Теперь база — СОБСТВЕННОЕ значение текущего ствола, а
                отладочный дефолт остаётся запасным ровно там, где к нему
                обращается сам движок. Тогда 100% = как в игре, 0% = нет
                отдачи, промежуточные значения линейны и честны для любого
                оружия. ]]
            local orig = def
            if traits ~= nil then
                local t = traits[key]
                if type(t) == "number" then
                    orig = t
                end
            end
            pcall(function()
                --[[ Клампим в СОБСТВЕННЫЙ диапазон ключа. У camera_lag_recoil
                     min = -2 (дефолт -0.1), у остальных min = 0 — выход за
                     границы игра трактует непредсказуе��о, поэтому держимся
                     внутри объявленных min/max. ]]
                local lo = tonumber(rawget(field, "min"))
                local hi = tonumber(rawget(field, "max"))
                local val = orig * keep
                if lo and val < lo then val = lo end
                if hi and val > hi then val = hi end
                field.value   = val
                -- ГЛАВНОЕ: без changed = true игра берёт значение ствола,
                -- а не наше (rifle_methods:239/252/299)
                field.changed = true
            end)
        end
    end
end

--[[ ── ВЕЛИЧИНА ОТДАЧИ: SHARED_STATE.plr_recoil ────────────────────────────
     Пишем поле `.value` напрямую, а НЕ через :set(). set() дополнительно
     дёргает сигнал changed (shared_state:37-44), на который подписан игровой
     код, — нам нужно только число, которое читает rifle_methods:204.
     Оригинал сохраняем один раз, ч��обы вернуть его при выключении мода. ]]
local plrRecoilOrig = nil

local function plr_recoil_set(mult)
    local node = SHARED and rawget(SHARED, "plr_recoil")
    if type(node) ~= "table" then return end
    pcall(function()
        if plrRecoilOrig == nil then
            local cur = rawget(node, "value")
            plrRecoilOrig = type(cur) == "number" and cur or 1
        end
        node.value = (mult == nil) and plrRecoilOrig or (plrRecoilOrig * mult)
    end)
end

--[[ Вернуть ключам их исходные значения и снять переопределение — тем же
     способом, каким это делает сам�� игра (game_debug_buttons:21-24). ]]
local function restore_keys(tbl, keys)
    for _, key in ipairs(keys) do
        local field = rawget(tbl, key)
        local orig  = RECOIL.base[key]
        if type(field) == "table" and orig ~= nil then
            pcall(function()
                field.value   = orig
                field.changed = false
            end)
        end
    end
end

local function patch_debug_values()
    local tbl = get_debug_values()
    if not tbl then
        return
    end
    if CFG.NoRecoil then
        --[[ Трейты ТЕКУЩЕГО ствола — база для процентов (см. scale_group).
             Берём каждый раз заново: при смене оружия таблица другая, а без
             обновления проценты считались бы от предыдущего ствола. Если ствола
             в руках нет, traits = nil и работает отладочный дефолт. ]]
        local traits
        pcall(function()
            traits = ctrl.weapon.properties.firing.recoil_traits
        end)
        if type(traits) ~= "table" then traits = nil end

        local pv = clamp(CFG.RecoilVertical   or 0, 0, 1)
        local ph = clamp(CFG.RecoilHorizontal or 0, 0, 1)
        local pc = clamp(CFG.RecoilCamera     or 0, 0, 1)

        --[[ Величина отдачи — максимум по осям. Максимум, а не сумма: при
             100/100 множитель обязан остаться РОВНО 1, иначе «как в игре»
             превратится в «вдвое сильнее». ]]
        local mag = pv > ph and pv or ph
        plr_recoil_set(mag)

        if mag > 0 then
            --[[ Делим направление в заданной пропорции. Нормируем на mag,
                 чтобы сильнейшая ось шла с родным весом: 50/50 даёт родное
                 направление и вдвое меньшую силу, 100/0 — чистую вертикаль. ]]
            scale_group(tbl, { RECOIL.dirV }, pv / mag, traits)
            scale_group(tbl, { RECOIL.dirH }, ph / mag, traits)
        else
            --[[ Сила уже ноль — веса ОБЯЗАНЫ остаться родными: (0,0).Unit
                 эт�� NaN, и он разнёс бы прицел и пружины камеры. ]]
            restore_keys(tbl, { RECOIL.dirV, RECOIL.dirH })
        end

        scale_group(tbl, RECOIL.mag, pv, traits)

        --[[ Подброс камеры — это то, что игрок видит как отдачу. Он должен
             отвечать и на оси: иначе Vertical 100% при Camera 0 выглядит как
             «отдачи нет» (ровно та жалоба). Ползунок Camera остаётся
             самостоятельным и может добавить подброс сверху. ]]
        local camMul = mag > pc and mag or pc
        scale_group(tbl, RECOIL.cam, camMul, traits)
    else
        plr_recoil_set(nil)
        --[[ Мод выключили. Возвращаем не только значения, но и СНИМАЕМ флаг
             changed — ровно так игра сама снимает переопределение
             (game_debug_buttons:21-24 "unapply debug_values"). ��наче ствол
             нав������гда остался бы на наших числах вместо своих трейтов. ]]
        restore_keys(tbl, { RECOIL.dirV, RECOIL.dirH })
        restore_keys(tbl, RECOIL.mag)
        restore_keys(tbl, RECOIL.cam)
    end
    for _, key in ipairs(K.SWAY_KEYS) do
        local field = rawget(tbl, key)
        if type(field) == "table" then
            if RECOIL.base[key] == nil and type(rawget(field, "value")) == "number" then
                RECOIL.base[key] = rawget(field, "value")
            end
            local orig = RECOIL.base[key]
            if orig ~= nil then
                pcall(function()
                    field.value   = CFG.NoSway and 0 or orig
                    field.changed = CFG.NoSway and true or false
                end)
            end
        end
    end
end

K.SWAY_SPRINGS = {
    "aim_sway", "sway", "slow_sway", "sway_recoil", "aim_sway_recoil",
    "main_bobbing", "sideways_bobbing",
}
local blockedSprings = setmetatable({}, { __mode = "k" })
local spring_hooked = false

local function hook_springs()
    if spring_hooked or not ctrl then
        return
    end
    local springs = rawget(ctrl, "springs")
    if type(springs) ~= "table" then
        return
    end
    local sample = springs.aim_sway or springs.sway
    if type(sample) ~= "table" then
        return
    end
    local mt = getmetatable(sample)
    if type(mt) ~= "table" then
        return
    end
    pcall(function()
        local origUpdate = rawget(mt, "update")
        local origShove = rawget(mt, "shove")
        if type(origUpdate) == "function" then
            rawset(mt, "update", function(self, dt)
                if blockedSprings[self] then
                    self.velocity = ZERO3
                    self.position = ZERO3
                    return ZERO3
                end
                return origUpdate(self, dt)
            end)
        end
        if type(origShove) == "function" then
            rawset(mt, "shove", function(self, v)
                if blockedSprings[self] then
                    return
                end
                return origShove(self, v)
            end)
        end
        spring_hooked = true
    end)
end

--======================================================================
--  VIEWMODEL / GUNMODEL  (перекраска рига от первог�� лица)
--======================================================================
--[[
    Два независимых store: руки и оружие. В store лежит ОРИГИНАЛ каждой
    тронутой части, поэтому выключение фичи возвращает всё как был��.

    Почему цвет приходится ��ЕРЕ-применять каждый кадр: части рига живут в
    Workspace.ignore, игра их пересо��даёт при каждой смене оружия и
    переодевании. Разовая покраска пропадает молча — это и есть типичное
    «не работает».

    Текстуры важнее цвета: MeshPart.TextureID и SurfaceAppearance перекрывают
    Color. Поэтому при покраске мы их снимаем (с сохранением) — иначе камо
    ствола просто перекроет наш цвет и снова получится «не работает».
--]]
--======================================================================
--  ГРАНАТЫ: таймер запала + предсказание траектории
--======================================================================
--[[
    Данные берём из ECS-мира игры, а не угадываем: world.ecs — синглтон
    (world:11 local u2 = v1.world()), поэтому require даёт ТОТ ЖЕ мир, в
    котором живут гранаты, а не копию.

    Симуляция повторяет grenade_step дословно:
      • полёт        pos(t) = o + v*t + a*t^2/2,  a = (0,-Gravity,0) + wind*0.5
      • отскок       vn = -v·n ; tangent = v - n*(v·n)
                     new = tangent*(1-friction) + n*(vn*restitution)
      • качение      если n.Y > 0.6 и от��кок слабый -> гасим тангенс
    Совпадение коэффициентов и есть причина, по которой линия ложится на
    реальный полёт, а не рядом с ним.
--]]
--[[ ПОЧЕМУ ЗДЕСЬ Ф��НКЦИЯ, А НЕ do...end.
     Первая версия оборачивала систему в do-блок — и получила
     "Out of local registers ... exceeded limit 200". do...end создаёт лексическую
     область видимости, но НЕ новый кадр регистров: все локалы внутри него
     по-прежнему выдел��ются в кадре main, где лимит Luau (200) уже почти выбран
     остальной частью скрипта. Освобождаются они только после end — слишком поздно.
     Отдельная функция получает собственный кадр регистров, поэтому внутренности
     системы гранат больше не давят на main. Наружу выходят ровно два имени. ]]
-- update_grenades / clear_grenades объявлены в forward-блоке наверху файла.
local function make_grenade_system()
local GRENADE = { ready = false }

pcall(function()
    local world = require(RS.client.module.ecs.world)
    GRENADE.ecs = world.ecs
    GRENADE.comp = require(RS.client.module.ecs.component.grenade_projectile)
        .grenade_projectile_component
    GRENADE.Timescale = require(RS.module.namespace.Timescale).Timescale
    GRENADE.ready = GRENADE.ecs ~= nil and GRENADE.comp ~= nil
end)

if not GRENADE.ready then
    log("grenades: ecs world not found, grenade visuals disabled")
end

--[[ ── АВТОРИТЕТНОЕ ВРЕМЯ ПОДРЫВА (УЧИТЫВАЕТ ГОТОВКУ) ──────────────────────
    ГЛАВНАЯ ПРИЧИНА НЕВЕРНОГО ТАЙМЕРА. Раньше остаток запала считался как
    fuse_time - (now - момент_броска). Это неверно для «готовки»: гранату
    можно удерживать (cook), и запал тикает ЕЩЁ ДО броска. На сущности гра��аты
    времени подрыва нет вовсе.

    ПОЧЕМУ ПРОШЛАЯ ПОПЫТКА (второй :Connect на @rbxts/net) НЕ СРАБОТАЛА:
    net-обёртка отдаёт explosion_time надёжно только СВОЕМУ хендлеру; наш
    второй Connect до значения не доходил, таблица explAt оставалась пустой, и
    таймер молча падал на старую формулу «от броска» — ровно то, что ты видел.

    Н��ДЁЖНЫЙ СПОСОБ: оборачиваем саму функцию ClientGrenadeProjectile.
    schedule_explosion. Реплкатор зовёт её так:
        v5:Connect(function(p13) ClientGrenadeProjectile.schedule_explosion(p13) end)
    (grenade_replicator dump:66-69) — то есть индексирует поле .schedule_explosion
    на таблице В МОМЕНТ ВЫЗОВА. Значит наша подмена поля ГАРАНТИРОВАННО ловит
    каждый вызов. Мы читаем p13 = { id = network_id, explosion_time = <синхр.
    абсолютное время, УЖЕ учитывает готовку> } и зовём оригинал — поведение игры
    не меняется. require кешируется, поэтому таблица у нас и у реплкатора одна.
    Это локальная клиентская логика отображения, не FireServer — байпассер и АЦ
    не при чём. ]]
GRENADE.explAt = {}          -- [network_id] = explosion_time (синхр. часы)
do
    local ok, err = pcall(function()
        local CGP = require(RS.client.module.ecs.namespace.ClientGrenadeProjectile)
            .ClientGrenadeProjectile
        local orig = CGP.schedule_explosion
        diag1("timer", "hook install: CGP=" .. tostring(CGP)
            .. " schedule_explosion type=" .. type(orig))
        if type(orig) == "function" then
            CGP.schedule_explosion = function(payload, ...)
                pcall(function()
                    diag("timer", "schedule_explosion fired id="
                        .. tostring(type(payload) == "table" and payload.id)
                        .. " t=" .. tostring(type(payload) == "table" and payload.explosion_time))
                    if type(payload) == "table"
                        and payload.id ~= nil
                        and type(payload.explosion_time) == "number"
                    then
                        GRENADE.explAt[payload.id] = payload.explosion_time
                    end
                end)
                return orig(payload, ...)
            end
            diag1("timer", "hook installed OK")
        end
    end)
    if not ok then diag1("timer", "hook install FAILED: " .. tostring(err)) end
end

--[[ Синхронное время игры: fuse считается от него, а не от os.clock. ]]
local function grenade_now()
    if GRENADE.Timescale and GRENADE.Timescale.get_synced_time then
        local ok, t = pcall(GRENADE.Timescale.get_synced_time)
        if ok and type(t) == "number" then
            return t
        end
    end
    return clock()
end

--[[ Ускорение — ровно то же, что в grenade_step:105. ]]
local function grenade_accel()
    return V3(0, -Workspace.Gravity, 0) + Workspace.GlobalWind * 0.5
end

--[[ Предсказание с отскоками. Возвращает список точек и точку падения.
     Дорогая часть — spherecast на сегмент, поэтому длину дуги ограничивает
     GrenadePathMaxDist, а число отскоков — GrenadePathBounces. Шаг времени
     мелкий и фиксированный (PATH_DT): от него зависит точность, а результат
     кэшируется на segment, так что за кадр симуляция не повторяется. ]]
--[[ Один RaycastParams на всё: граната в движке сталкивается только с
     map_geometry_only, поэтому персонажей и служебную папку исключаем.
     Список обновляется раз в кадр в update_grenades, а не на каждый снаряд —
     пересборка таблицы внутри цикла симуляции была лишним мусором для GC. ]]
local grenadeRayParams = RaycastParams.new()
grenadeRayParams.FilterType = Enum.RaycastFilterType.Exclude
grenadeRayParams.IgnoreWater = true

local function grenade_refresh_filter()
    local filter = {}
    local chars = Workspace:FindFirstChild("characters")
    local ign = Workspace:FindFirstChild("ignore")
    if chars then filter[#filter + 1] = chars end
    if ign then filter[#filter + 1] = ign end
    grenadeRayParams.FilterDescendantsInstances = filter
end

--[[ ШАГ СИМУЛЯЦИИ — ТЕПЕРЬ КОНСТАНТА, А НЕ НАСТРОЙКА.
     Раньше шаг и число шагов крутились слайдерами. Это выглядело как гибкость,
     а на деле было ловушкой: точность траектории напрямую зависит от шага, и
     любое значение кроме мелкого давало заметно неверную дугу — то ес��ь
     слайдер позволял только испортить результат. Шаг фиксирован мелким (60 Гц,
     как физический тик), а длину дуги ограничивает GrenadePathMaxDist. ]]
--[[ ШАГ 1/30, А НЕ 1/60 — И ЭТО НЕ ТЕРЯЕТ ТОЧНОСТЬ СТОЛКНОВЕНИЙ.
     Ключевой момент: каждый шаг проверяется НЕ точкой, а spherecast'ом вдоль
     всего сегмента. Sweep непрерывен, поэтому удвоение шага не даёт гранате
     «пролететь сквозь» стену — оно лишь делает саму ломаную грубее. То есть
     цена падает вдвое, а место касания остаётся тем же.
     Раньше стоял 1/60 «как физический тик», хотя ломаная такой плотности всё
     равно не видна на экране. ]]
local PATH_DT = 1 / 30
local PATH_STEPS_CAP = 240      -- страховка от бесконечного цикла
local PATH_KEEP = 3             -- каждая N-я точка попадает в ломаную

--[[ ФИЗИКА ОТСКОКА — ИЗ SHARED_STATE, А НЕ ЦИФРАМИ В КОДЕ.
     Здесь были захардкоженные значения, и все они расходились с игрой, отчего
     отскоки и считались неправильно (shared_state:231-237):

         упругость            было 0.4   в игре 0.2     -> отскок вдвое выше
         порог перехода в качение  8     в игре 2       -> «покатилась» слишком рано
         сопротивление качению    0.5    в игре 0.005   -> в 100 раз сильнее
         порог остановки          1      в игре 4       -> дуга тянулась дальше нужного

     Читаем теми же ключами, что и движок при рождении снаряда. ]]
local function grenade_roll_consts()
    return hud_shared_max("plr_grenade_roll_away_speed", 2),
           hud_shared_max("plr_grenade_rolling_resistance", 0.005),
           hud_shared_max("plr_grenade_settle_speed", 4)
end

--[[ Наличие Spherecast проверяем один раз, а не в каждом шаге симуляции:
     проверка внутри цикла — это сотни лишних обращений за кадр. Если вызов
     когда-нибудь упадёт, флаг гасится навсегда и дальше идёт обычный Raycast. ]]
local sphereCastOK = (typeof(Workspace.Spherecast) == "function")

local function grenade_predict(origin, vel, restitution, friction, radius)
    local pts = { origin }
    local a = grenade_accel()
    local pos, v = origin, vel
    local bounces = 0
    local impact = nil
    local dt = PATH_DT
    local maxDist = CFG.GrenadePathMaxDist
    local travelled = 0
    -- читаем один раз на симуляцию, а не в каждом шаге
    local rollAway, rollRes, settleV = grenade_roll_consts()
    local kept, tailAdded = 0, true

    for _ = 1, PATH_STEPS_CAP do
        local nextPos = pos + v * dt + a * (dt * dt * 0.5)
        local delta = nextPos - pos
        local dist = delta.Magnitude

        --[[ Лимит по пройде��ному пути. Считаем ДО шага: иначе последний
             сегмент вылезал бы за лимит на свою длину. ]]
        travelled = travelled + dist
        if travelled > maxDist then
            break
        end

        if dist > 1e-4 then
            --[[ ПОЧЕМУ SPHERECAST, А НЕ RAYCAST.
                Луч — это линия нулевой толщины, а граната — шар радиусом
                radius. Из-за этого луч пролезал там, где шар не пролезает: в
                щель между ящиками, мимо угла, вплотную к перилам — и
                предсказание уводило дугу «сквозь» препятствие. Spherecast
                ведёт по траектории шар нужного радиуса, поэтому касание
                считается там же, где его посчитает физика.
                Fallback на Raycast нужен на случай, если метода нет. ]]
            local res
            if sphereCastOK then
                local okc, r = pcall(Workspace.Spherecast, Workspace,
                    pos, radius, delta, grenadeRayParams)
                if okc then
                    res = r
                else
                    sphereCastOK = false
                end
            end
            if res == nil and not sphereCastOK then
                res = Workspace:Raycast(pos, delta, grenadeRayParams)
            end

            if res then
                local n = res.Normal.Unit
                local vAtHit = v + a * dt
                local vn = vAtHit:Dot(n)

                --[[ ОТСКОКА НЕТ, ЕСЛИ ГРАНАТА УЛЕТАЕТ ОТ ПОВЕРХНОСТИ.
                     Движок здесь выходит сра��у (handle_bounce:129 `if v22 >= 0
                     then return nil`), и это не мелочь: skim по касательной
                     вдоль стены давал у нас ложный отско�� на каждом шаге, из-за
                     чего дуга у стен ломалась в гармошку и впустую жгла лимит
                     отскоков. Теперь просто продолжаем полёт. ]]
                if vn >= 0 then
                    pos = res.Position + n * (radius + 0.05)
                    v = vAtHit
                    pts[#pts + 1] = pos
                else
                    --[[ Spherecast возвращает точку на ПОВЕРХНОСТИ, а центр
                         шара стоит на radius от неё — отсюда смещение. ]]
                    local hitPos = res.Position + n * (radius + 0.05)
                    pts[#pts + 1] = hitPos
                    if impact == nil then
                        impact = hitPos
                    end
                    bounces = bounces + 1
                    if bounces > CFG.GrenadePathBounces then
                        break
                    end

                    -- отражение дословно по handle_bounce:132-140
                    local tangent = vAtHit - n * vn
                    local rebound = -vn * restitution
                    local rolling = (n.Y > 0.6) and (rebound < rollAway)
                    if rolling then
                        v = tangent * (1 - rollRes)
                    else
                        v = tangent * (1 - friction) + n * rebound
                    end
                    pos = hitPos

                    if v.Magnitude < settleV then
                        break               -- легла (motion.settled)
                    end

                    --[[ ЗДЕСЬ СИМУЛЯЦИЯ ЗАКАНЧИВАЕТСЯ СОЗНАТЕЛЬНО.
                         При переходе в качение движок бросает баллистику и
                         передаёт снаряд в step_rolling, а тот ползёт ПО РЕЛЬЕФУ:
                         каждый кадр ищет землю под гранатой и прижимает её к
                         поверхности. Баллистикой это не воспроизводится — мы
                         продолжали лететь параболой и рисовали дугу, уходящую
                         сквозь пол. Условие качения — то же, что в is_rolling
                         (grenade_step:92-99): нормаль вверх, отскок слабый и
                         есть горизонтальная скорость. ]]
                    if rolling and V3(v.X, 0, v.Z).Magnitude >= 0.5 then
                        break
                    end
                end
            else
                pos = nextPos
                v = v + a * dt
                --[[ ПРОРЕЖИВАНИЕ ЛОМАНОЙ.
                     Шаг симуляции остаётся м��лким (от него зависит, где
                     посчитается касание), но в рисуемую ломаную идёт не каждая
                     точка, а каждая PATH_KEEP-я. На параболе разница незаметна,
                     зато в три раза меньше и Drawing-линий, и вызовов
                     WorldToViewportPoint — а проекция делается КАЖДЫЙ кадр для
                     каждой точки, в отличие от самой симуляции, которая
                     кэшируется. Точки отскока добавляются всегда (ветка выше),
                     поэтому форма траектории не теряется. ]]
                kept = kept + 1
                if kept % PATH_KEEP == 0 then
                    pts[#pts + 1] = pos
                    tailAdded = true
                else
                    tailAdded = false
                end
            end
        else
            break
        end
    end

    --[[ Последняя точка нужна всегда: б��з неё траектория обрывалась бы за
         нес��олько шагов до реального конца. ]]
    if not tailAdded and (pos - pts[#pts]).Magnitude > 1e-3 then
        pts[#pts + 1] = pos
    end
    return pts, impact
end

--[[ Один снаряд = один набор Drawing-объектов, закреплённых за network_id.
     Так же, как в ESP: без переиспользования по индексу, иначе мелькает. ]]
local grenadeDraws = {}

--[[ ── КОНСТАНТЫ ЗНАЧКА ───────────────────────────────────────────────────
     Были слайдерами (толщина дуги, число сегментов, заливка фона). Крутить их
     можно было только во вред, поэтому теперь просто константы. ]]
local GRN_ARC_THICK = 3
local GRN_ARC_SEGS  = 28
local GRN_BG_TRANS  = 0.45

--[[ ��─ ПОЧЕМУ RBXASSETID НЕ ГРУЗИЛСЯ (РАЗБОР, А НЕ ОБХОД) ──────────────────
     Две отдельные причины, и я раньше остановился на полпути.

     1. Drawing.Image.Data — это НЕ id и НЕ ссылка, а СЫРЫЕ БАЙТЫ файла
        (docs: Image.Data: string, «An image from a URL or file»). Присваивание
        строки "rbxassetid://123" отдаёт декодеру ASCII-текст: rbxassetid://
        разворачивает только контент-провайдер самого Roblox, а Drawing — это
        внешний оверлей, он к нему не обращается. Декодирование молча падает —
        отсюда «иконки нет».

     2. Байты надо взять самому, и вот здесь была МОЯ ошибка. Я дёргал
        assetdelivery через httpget, получал «Authentication required to access
        Asset» и сделал вывод, что иконка невозможна. Неверно: этот эндпоинт
        отвечает так на запрос без клиентского User-Agent. С заголовком
        Roblox/WinInet (request поддерживает Headers) он отдаёт файл. То есть
        причина была в отсутствующем заголовке, а не в «нельзя».

     Плюс третья тонкость: id загруженной картинки часто указывает на Decal, и
     тогд�� в ответе не PNG, а XML со ссылкой на настоящую текст��ру — её надо
     достать и запросить второй раз.

     Сеть уходит в task.spawn: в кадровом коде её быть не должно. Результат
     кэшируется и в память, и в файл, поэтому запрос делается один раз за всё
     время, а не раз в сеанс. ]]
local imgCache = {}          -- [assetId] = байты | false (не вышло)

local function image_fetch(id)
    local url = "https://assetdelivery.roblox.com/v1/asset/?id=" .. id
    local body
    pcall(function()
        local resp = request({
            Url = url,
            Method = "GET",
            -- ← тот самый заголовок, без которого приходил Authentication required
            Headers = { ["User-Agent"] = "Roblox/WinInet" },
        })
        if resp and resp.Success and type(resp.Body) == "string" then
            body = resp.Body
        end
    end)
    return body
end

local function image_bytes(assetId)
    if assetId == nil or assetId == "" then return nil end
    local cached = imgCache[assetId]
    if cached ~= nil then
        return cached or nil
    end
    imgCache[assetId] = false          -- метка «уже грузим», чтобы не спамить

    task.spawn(function()
        local id = tostring(assetId):match("(%d+)")
        if id == nil then return end

        local file = "deadlineSA_icon_" .. id .. ".png"
        -- сначала диск: между сеансами сеть не нужна вовсе
        local ok, disk = pcall(function()
            if isfile and isfile(file) then return readfile(file) end
            return nil
        end)
        if ok and type(disk) == "string" and #disk > 8 then
            imgCache[assetId] = disk
            return
        end

        local body = image_fetch(id)
        --[[ Ответ-XML = это Decal-обёртка. Достаём id на��тоящей текстуры и
             запрашиваем ещё раз. Больше одного шага не делаем: глубже вложения
             у картинок не бывает, а цикл здесь опаснее пропущенной иконки. ]]
        if type(body) == "string" and body:sub(1, 1) == "<" then
            local realId = body:match("id=(%d+)")
            if realId and realId ~= id then
                body = image_fetch(realId)
            end
        end

        if type(body) == "string" and #body > 8 and body:sub(1, 1) ~= "<" then
            imgCache[assetId] = body
            pcall(function() writefile(file, body) end)
        end
    end)

    return nil
end

local function grenade_draw_new()
    local o = {}
    --[[ ZIndex задан явно: фон должен быть под силуэтом и дугой, иначе порядок
         зависел бы от очерёдности создания объектов. ]]
    o.bg = Drawing.new("Circle")
    o.bg.Filled = true
    o.bg.NumSides = 32
    o.bg.ZIndex = 1
    o.bg.Visible = false

    --[[ Image создаём заранее, но Data ставим только когда байты реально
         пришли: объект с пустым Data ничего не рисует и не мешает. Конструктор
         в pcall — на исполнителях без типа "Image" он бы уронил весь значок. ]]
    pcall(function()
        o.icon = Drawing.new("Image")
        o.icon.ZIndex = 2
        o.icon.Visible = false
    end)

    --[[ Общий пул Line-объектов: используется дугой запала И траекторией.
         Силуэта из линий больше нет — если байты иконки не пришли, значок
         показывает только фон + дугу. ]]
    o.lines = {}
    return o
end

local function grenade_draw_free(o)
    pcall(function() o.bg:Remove() end)
    if o.icon then pcall(function() o.icon:Remove() end) end
    for _, l in ipairs(o.lines) do
        pcall(function() l:Remove() end)
    end
end

local function grenade_line(o, i)
    local l = o.lines[i]
    if l == nil then
        l = Drawing.new("Line")
        l.Thickness = 1.5
        l.ZIndex = 3
        o.lines[i] = l
    end
    return l
end

local function grenade_hide(o)
    o.bg.Visible = false
    if o.icon then o.icon.Visible = false end
    for _, l in ipairs(o.lines) do
        l.Visible = false
    end
end

--[[ ЗНАЧОК: ФОН + ИКОНКА + ДУГА ЗАПАЛА.
    frac — сколько запала осталось (1 = полный, 0 = взрыв). Дуга идёт от 12
    часов по часовой стрелке, е�� длин�� пропорциональна frac, а цвет едет от
    GrenadeFuseFull к GrenadeFuseLow. Иконку тонируем тем же цветом, поэтому
    «сколько осталось» читается даже краем глаза, без разглядывания дуги.

    Дугу собираем из отрезков: у Drawing нет ни частичной окружности, ни
    градиента, поэтому это единственный способ, а не выбор стиля. Число
    сегментов считаем от frac, а не берём полное: на остатке в 10% рисовать 28
    отрезков незачем.

    li — общий индекс в пуле линий снаряда (тот же, что у траектории), поэтому
    новых Drawing-объектов дуга не создаёт. Возвращаем сдвинутый индекс. ]]
local function grenade_badge(o, li, sx, sy, frac, baseCol)
    local r = CFG.GrenadeMarkerSize

    local col = baseCol
    if frac then
        col = CFG.GrenadeFuseLow:Lerp(CFG.GrenadeFuseFull, clamp(frac, 0, 1))
    end

    o.bg.Position = V2(sx, sy)
    o.bg.Radius = r
    o.bg.Color = Color3.new(0.04, 0.05, 0.07)
    o.bg.Transparency = GRN_BG_TRANS
    o.bg.Visible = true

    --[[ ── ИКОНКА ГРАНАТЫ (rbxassetid 85012617711318) ─────────────────────
         Никакого рисованного силуэта: тот фейк-силуэт из линий убран целиком.
         Значок — это Drawing.Image с СЫРЫМИ байтами PNG (Potassium: у Image
         только .Data, никакого .Uri/assetid). Байты тянет image_bytes()
         асинхронно и кладёт в кэш + на диск, поэтому первые кадры после спавна
         иконки может ещё не быть — тогда рисуем только фон и дугу запала, без
         подмены силуэтом. Data ставим ОДИН раз на объект, иначе декодер
         дёргался бы каждый кадр. Цвет иконки НЕ тонируем — читаемость времени
         несёт дуга запала по краю. ]]
    local bytes = image_bytes(CFG.GrenadeIconAsset)
    if o.icon and bytes then
        if o.iconData ~= bytes then
            o.iconData = bytes
            pcall(function() o.icon.Data = bytes end)
        end
        local d = r * 1.4                   -- иконка чуть меньше фонового круга
        o.icon.Size = V2(d, d)
        o.icon.Position = V2(sx - d * 0.5, sy - d * 0.5)
        o.icon.Visible = true
    elseif o.icon then
        o.icon.Visible = false
    end

    if frac then
        local f = clamp(frac, 0, 1)
        local segs = max(1, floor(GRN_ARC_SEGS * f + 0.5))
        local span = (math.pi * 2) * f
        local step = span / segs
        local start = -math.pi * 0.5          -- 12 часов
        local ar = r - GRN_ARC_THICK * 0.5

        local px, py = sx + cos(start) * ar, sy + sin(start) * ar
        for i = 1, segs do
            local a = start + step * i
            local nx, ny = sx + cos(a) * ar, sy + sin(a) * ar
            li = li + 1
            local l = grenade_line(o, li)
            l.From = V2(px, py)
            l.To = V2(nx, ny)
            l.Color = col
            l.Thickness = GRN_ARC_THICK
            l.Transparency = 1
            l.Visible = true
            px, py = nx, ny
        end
    end

    return li
end

function clear_grenades()
    for id, o in pairs(grenadeDraws) do
        grenade_draw_free(o)
        grenadeDraws[id] = nil
    end
end

function update_grenades()
    if not CFG.Grenades or not GRENADE.ready then
        if next(grenadeDraws) then clear_grenades() end
        return
    end

    local cam = Workspace.CurrentCamera
    if cam == nil then
        return
    end
    local myPos = cam.CFrame.Position
    local now = grenade_now()
    local seen = {}       -- ключи grenadeDraws (network_id или tostring(seg))
    local seenNid = {}    -- только network_id — для чистки GRENADE.explAt
    grenade_refresh_filter()

    --[[ ── ИЗОЛЯЦИЯ ПО ГРАНАТЕ + ГАРАНТИРОВАННАЯ УБОРКА ───────────────────
         БЫЛО: весь цикл в ОДНОМ pcall, а при ошибке — `if not ok then return`.
         Любая одна кривая граната (nil-поле, гибнущая сущность) роняла pcall,
         и тогда: (1) не отрисовывались ОСТАЛЬНЫЕ гранаты, включая траектории —
         «траектория не показывается вообще»; (2) пропускалась уборка ниже,
         поэтому уже нарисованные значки/круги ЗАМИРАЛИ на экране, пока граната
         не исчезнет (взрыв) — «круг застывает, п��ка не взорвётся». Обе жалобы —
         один корень. Теперь каждая граната в своём pcall, а уборка ВСЕГДА. ]]
    pcall(function()
        for _, gr in GRENADE.ecs:query(GRENADE.comp) do
          pcall(function()
            local seg = gr.segment
            local phys = gr.physics
            local motion = gr.motion
            if type(seg) == "table" and type(phys) == "table" then
                local id = gr.network_id or tostring(seg)
                seen[id] = true
                if gr.network_id ~= nil then seenNid[gr.network_id] = true end

                --[[ Текущая позиция считается формулой, а не берётся из
                     инстанса: инстанс интерполируется отдельно и может
                     отставать, а нам нужна та точка, из которой предсказывать. ]]
                local t = math.max(0, now - (seg.start_time or now))
                local a = grenade_accel()
                local pos = (motion and motion.settled)
                    and (motion.current_position or seg.origin)
                    or (seg.origin + seg.velocity * t + a * (t * t * 0.5))

                local dist = (pos - myPos).Magnitude
                local o = grenadeDraws[id]
                if dist > CFG.GrenadeMaxDist then
                    if o then grenade_hide(o) end
                else
                    if o == nil then
                        o = grenade_draw_new()
                        grenadeDraws[id] = o
                    end
                    grenade_hide(o)

                    --[[ СВОЯ ИЛИ ЧУЖАЯ.
                        Сравнить thrower_ingame_id с нашим напрямую нельзя:
                        ingame_id — это серверный id сущности игрока
                        (dl_replicator:806 u33[ingame_id]), он есть у ЧУЖИХ
                        Character-объектов, а у нашего fp_controller его нет.
                        Зато dl_replicator заводит запись только для чужих
                        игроков, поэтому известный id = чужая граната, а
                        н��известный (или отсутствующий) = наша.
                        Реестр чужих у нас уже собран для ESP: entByIngame
                        индексирован ровно этим же id (см. refresh_meta), так
                        что проверка — одно чтение таблицы, без перебора. ]]
                    local tid = gr.thrower_ingame_id
                    local mine = not (tid ~= nil and entByIngame[tostring(tid)] ~= nil)
                    if not (CFG.GrenadeEnemyOnly and mine) then
                        local col = mine and CFG.GrenadeColorMine or CFG.GrenadeColorEnemy

                        -- ── ТАЙМЕР ЗАПАЛА ──────────────────────────────
                        --[[ Авторитетное время подрыва приходит remote-ом и УЖЕ
                             учитывает готовку (см. GRENADE.explAt в setup).
                             Прежний fuse_time - (now - throw) удержание не
                             учитывал — отсюда и неверный таймер. ]]
                        local fuseLeft, frac = nil, nil
                        local firing = nil
                        pcall(function() firing = gr.properties.firing end)

                        local explAt = gr.network_id ~= nil
                            and GRENADE.explAt[gr.network_id] or nil

                        --[[ ДИАГНОСТИКА КЛЮЧА ТАЙМЕРА: печатает тип и значение
                             gr.network_id и есть ли по нему запись в explAt.
                             Если nil/mismatch — таймер падает на cook-неу��ётный
                             фолбэк. Печатаем сжато: nid=<type>:<val> hit=<bool>
                             keys=<сколько всего в explAt>. ]]
                        do
                            local n = 0
                            for _ in pairs(GRENADE.explAt) do n = n + 1 end
                            dgren(string.format("timer nid=%s:%s hit=%s keys=%d",
                                type(gr.network_id), tostring(gr.network_id),
                                tostring(explAt ~= nil), n))
                        end

                        if explAt then
                            fuseLeft = explAt - now
                            --[[ Знаменатель дуги: номинальный fuse_time, если он
                                 есть — тогда у кукнутой гранаты дуга честно
                                 стартует НЕ с полной, видно что её готовили.
                                 Иначе — остаток на момент первого получения. ]]
                            local total
                            if firing and type(firing.fuse_time) == "number"
                                and firing.fuse_time > 0 then
                                total = firing.fuse_time
                            else
                                o.fuseFull = o.fuseFull or max(fuseLeft, 0.001)
                                total = o.fuseFull
                            end
                            frac = clamp(fuseLeft / total, 0, 1)
                        elseif firing and firing.fuse_type == "delayed" and firing.fuse_time then
                            --[[ Фолбэк на первые кадры, пока remote ещё не
                                 пришёл: грубый отсчёт от появления снаряда. Как
                                 только придёт explosion_time — переключимся. ]]
                            o.spawn = o.spawn or (seg.start_time or now)
                            fuseLeft = firing.fuse_time - (now - o.spawn)
                            if firing.fuse_time > 0 then
                                frac = clamp(fuseLeft / firing.fuse_time, 0, 1)
                            end
                        end

                        local li = 0

                        local sp, onScreen = cam:WorldToViewportPoint(pos)
                        if onScreen and sp.Z > 0 and CFG.GrenadeMarker then
                            li = grenade_badge(o, li, sp.X, sp.Y, frac, col)
                        end

                        -- ── ТРАЕКТОРИЯ ─────────────────────────────────
                        if CFG.GrenadePath and not (motion and motion.settled) then
                            --[[ КЭШ ТРАЕКТОРИИ — ЛЕЧЕНИЕ ДЁРГАНЬЯ.
                                Раньше дуга считалась заново КАЖДЫЙ кадр от
                                текущей позиции. Позиция берётся из времени
                                (now - start_time), а `now` приходит из
                                синхрониз��рованных часов и слегка плавает,
                                поэтому каждый кадр симуляция стартовала ��з
                                чуть другой точки — и вся дуга, особенно после
                                отскока, заметно дрожала.
                                Но участок полёта БАЛЛИСТИЧЕСКИЙ: пока не
                                сменился segment, форма траектории не меняется
                                вообще. Поэтому считаем её один раз на segment
                                (ключ — start_time) и переиспользуем. Заодно
                                это снимает основную нагрузку: раньше на каждую
                                гранату каждый кадр приходились сотни
                                spherecast-ов. ]]
                            local key = seg.start_time or 0
                            local cache = o.path
                            if cache == nil or cache.key ~= key then
                                cache = { key = key, pts = grenade_predict(
                                    seg.origin, seg.velocity,
                                    phys.restitution or 0.2,
                                    phys.friction or 0.3,
                                    phys.radius or 0.5) }
                                o.path = cache
                            end
                            local pts = cache.pts

                            local drawn = 0
                            for i = 1, #pts - 1 do
                                local p1, ok1 = cam:WorldToViewportPoint(pts[i])
                                local p2, ok2 = cam:WorldToViewportPoint(pts[i + 1])
                                if ok1 and ok2 and p1.Z > 0 and p2.Z > 0 then
                                    li = li + 1
                                    drawn = drawn + 1
                                    local l = grenade_line(o, li)
                                    l.From = V2(p1.X, p1.Y)
                                    l.To = V2(p2.X, p2.Y)
                                    l.Color = col
                                    --[[ Толщину задаём ЯВНО. Пул линий общий с
                                         дугой запала, которая ставит свою
                                         толщину, и без этой строки линия,
                                         побывавшая сегментом дуги, осталась бы
                                         толстой уже в роли траектории. ]]
                                    l.Thickness = 1.5
                                    --[[ Transparency = 1 = ПОЛНОСТЬЮ НЕПРОЗРАЧНО.
                                         У Drawing шкала ОБРАТНА роблоксовской:
                                         1 = видно, 0 = невидимо (docs.potassium
                                         .pro). Прошлые 0.85 давали еле видную/
                                         невидимую линию — ровно «траектория не
                                         показывается». Дуга запала рисуется на 1
                                         и видна, значит трассе тоже нужна 1. ]]
                                    l.Transparency = 1
                                    l.Visible = true
                                end
                            end
                            dgren(string.format("thrown pts=%d drawn=%d dist=%.0f col=%s",
                                #pts, drawn, dist, tostring(col)))
                        else
                            dgren(string.format("path skipped: GrenadePath=%s settled=%s",
                                tostring(CFG.GrenadePath), tostring(motion and motion.settled)))
                        end
                    end
                end
            end
          end) -- pcall на одну гранату: её падение не роняет остальные
        end
    end)

    --[[ Уборка ВСЕГДА (раньше её пропускал `if not ok then return`): снаряд
         исчез -> убираем его объекты, поэтому круг/значок больше не «застывает»
         на экране после того, как граната ушла из виду. ]]
    for id, o in pairs(grenadeDraws) do
        if not seen[id] then
            grenade_draw_free(o)
            grenadeDraws[id] = nil
        end
    end
    --[[ Чистим таблицу времён подрыва по исчезнувшим снарядам, чтобы она не
         росла бесконечно (ключ — network_id, живёт пока жив снаряд). ]]
    for nid in pairs(GRENADE.explAt) do
        if not seenNid[nid] then
            GRENADE.explAt[nid] = nil
        end
    end
end

--======================================================================
--  ТРАЕКТОРИЯ БРОСКА, ПОКА ГРАНАТА ЕЩЁ В РУКАХ
--======================================================================
--[[ Отдельный набор Drawing-объектов: он не привязан к network_id, потому что
     снаряда ещё не существует — мы рисуем то, что БУДЕТ, если бросить сейчас. ]]
local aimDraw, aimDrawWeak
--[[ Кэш предсказания броска. Живёт вне функции, потому что должен переживать
     кадры — в этом весь смысл. Поля: t (время расчёта), origin/dir (для чего
     считали), pts1/pts2 (сильный и слабый бросок), weak (был ли включён слабый
     на момент расчёта). ]]
local aimCache = { t = 0, origin = V3(0, 0, 0), dir = V3(0, 0, 1) }

function clear_grenade_aim()
    if aimDraw then grenade_draw_free(aimDraw); aimDraw = nil end
    if aimDrawWeak then grenade_draw_free(aimDrawWeak); aimDrawWeak = nil end
end

--[[ Повтор clamp_throw_origin (grenade_step:220-245) од��н в один.
     Смысл: граната рождается не ���� камере, а в руке, и если между камерой и
     рук��й оказалась стена (прижались к углу), точку старта подтягивают назад,
     чтобы снаряд не родился ЗА стеной. Без этого предска��ание у стены
     показывало бросок сквозь неё. ]]
local function clamp_throw_origin(camPos, handPos, props)
    local d = handPos - camPos
    local mag = d.Magnitude
    if mag < 0.001 then
        return handPos
    end
    local res = Workspace:Raycast(camPos, d, grenadeRayParams)
    if not res then
        return handPos
    end
    local unit = d.Unit
    local col
    pcall(function() col = props.collision.radius end)
    local back = max(col == nil and 0.5 or col, 0.1) + 0.1
    local along = (res.Position - camPos):Dot(unit) - back
    return camPos + unit * clamp(along, 0, mag)
end

--[[ Физику берём из SHARED_STATE теми же к��ючами, что и движок при рождении
     снаряда (grenade_step:441-450). Читать их из уже летящей гранаты нельзя —
     летящей гранаты ещё нет, а константы подста��лять нельзя: обе величины
     сервер может менять на ходу. ]]
local function grenade_hand_physics(props)
    --[[ Фолбэки — реальные значения игры (shared_state:232-233). Упругость тут
         была 0.4 против 0.2 в игре, то есть пре��сказанный отскок задирался
         вдвое выше наст��ящего. ]]
    local fr = hud_shared_max("plr_grenade_friction", 0.3)
    local el = hud_shared_max("plr_grenade_elasticity", 0.2)
    local col
    pcall(function() col = props.collision.radius end)
    local radius = max(col == nil and 0.5 or col, 0.1)
    return el, fr, radius
end

function update_grenade_aim()
    --[[ ── ТРАЕКТОРИЯ БОЛЬШЕ НЕ ЗАВИСИТ ОТ ESP ЧУЖИХ ГРАНАТ ────────────────
         Было `CFG.Grenades and CFG.GrenadeAim`. CFG.Grenades — это мастер-
         тумблер ОТСЛЕЖИВАНИЯ ЧУЖИХ гранат (ECS-трекер в update_grenades), к
         своему броску он отношения не имеет. С выключенным Grenades дуга не
         рисовалась вообще, сколько бы раз ни включали GrenadeAim.
         Дуга считается локально из позиции руки и камеры — ей не нужны ни ECS,
         ни GRENADE.ready. ]]
    if not CFG.GrenadeAim then
        if aimDraw then grenade_hide(aimDraw) end
        if aimDrawWeak then grenade_hide(aimDrawWeak) end
        return
    end

    local cam = Workspace.CurrentCamera
    if cam == nil then
        return
    end

    --[[ Ри��уем только когда в руках именно метательное: ровно эту проверку
         делает и сам движок перед броском (throwable_key_map:19). ]]
    if not holding_throwable() then
        daim("not holding_throwable")
        if aimDraw then grenade_hide(aimDraw) end
        if aimDrawWeak then grenade_hide(aimDrawWeak) end
        return
    end
    daim("holding throwable OK")

    --[[ ПОЧЕМУ ДВА ПУТИ И ПОЧЕМУ ЭТО БЫЛА ПРИЧИНА «ТРАЕКТОРИИ НЕТ».
        Раньш�� читалось только `weapon.build.result.properties` — такого поля
        нет. Сам движок в момент броска берёт `weapon.properties`
        (throwable_methods:231), результат билда там не участвует. props
        получался nil, функция выходила на следующей строке, и траектория не
        рисовалась вообще никогда. Правильный путь ставим первым, старый
        оставляем вторым про��то как запас. ]]
    --[[ ГЛАВНЫЙ ФИКС ПРИЦЕЛЬНОЙ ДУГИ: НИКОГДА НЕ ВЫХОДИМ РАНЬШЕ ВРЕМЕНИ.
         Прошлая версия делала return, если не нашла held_weapon / properties /
         receiver.Position. Именно сюда всё и упиралось: held_weapon идёт другим
         путём, чем holding_throwable (которая true), и на этой раскладке
         оружия одно из трёх чтений давало nil — дуга не рисовалась вообще.
         А она и не нужна для рисования: grenade_hand_physics и
         clamp_throw_origin оба корректно работают с props=nil (берут дефолты
         игры), а origin при отсутствии руки берём из позиции камеры — визуально
         дуга всё равно строится по направлению взгляда. Поэтому просто
         собираем что смогли и всегда идём предсказывать. ]]
    local wep = held_weapon()

    local props
    if wep ~= nil then
        pcall(function() props = wep.properties end)
        if props == nil then
            pcall(function() props = wep.build.result.properties end)
        end
    end

    --[[ Точка в руке. Пробуем receiver в нескольких раскладках; если нигде нет
         — origin = позиция камеры (фолбэк, дуга всё равно появится). ]]
    local handPos
    if wep ~= nil then
        pcall(function() handPos = wep.receiver.Position end)
        if handPos == nil then
            pcall(function() handPos = wep.viewmodel.receiver.Position end)
        end
        if handPos == nil then
            pcall(function()
                local r = wep.viewmodel:FindFirstChild("receiver", true)
                if r then handPos = r.Position end
            end)
        end
    end
    if handPos == nil then
        handPos = cam.CFrame.Position
    end
    daim(string.format("predicting wep=%s props=%s hand=%s",
        tostring(wep ~= nil), tostring(props ~= nil), tostring(handPos)))

    grenade_refresh_filter()

    local camCF = cam.CFrame
    local origin = clamp_throw_origin(camCF.Position, handPos, props)

    --[[ Направление — не просто LookVector камеры: движок строит CFrame из
         origin в точку «камера + взгляд*40», поэтому бросок из руки слегка
         сводится к линии прицеливания. На дистанции это заметный сдвиг. ]]
    local aimAt = camCF.Position + camCF.LookVector * 40
    local dir = CFrame.new(origin, aimAt).LookVector

    local strength = 1
    pcall(function() strength = SHARED.plr_grenade_throw_strength.value or 1 end)

    local el, fr, radius = grenade_hand_physics(props)

    --[[ ── КЭШ ПРИЦЕЛЬНОЙ ТРАЕКТОРИИ — ГЛАВНАЯ ПРИЧИНА ПРОСАДОК FPS ─────────
         Здесь си��уляция запускалась ЗАНОВО КАЖДЫЙ КАДР, причём дважды (сильный
         и слабый бросок). При лимите в 200 юнитов это сотни spherecast-ов на
         кадр всё время, пока граната просто держится в руке, — отсюда и «фпс
         дропы участились», и они не совпадали с самим броском.
         У летящих гранат кэш по segment уже был, а этой ветке его не сделали,
         хотя форма дуги зависит ровно от двух величин: точк�� старта и
         направления. Пересчитываем только когда одна из них реально изменилась
         (или изредка по таймеру — мир и физика могут поменяться). ]]
    local now = clock()
    local c = aimCache
    local stale = (c.pts1 == nil)
        or (now - c.t > 0.25)
        or ((origin - c.origin).Magnitude > 0.35)
        or (dir:Dot(c.dir) < 0.9997)        -- поворот примерно на 1.4 граду��а
        or (c.weak ~= (CFG.GrenadeAimWeak == true))

    if stale then
        c.t, c.origin, c.dir = now, origin, dir
        c.weak = (CFG.GrenadeAimWeak == true)
        c.pts1 = grenade_predict(origin, dir * 75 * strength, el, fr, radius)
        c.pts2 = c.weak
            and grenade_predict(origin, dir * 40 * strength, el, fr, radius)
            or nil
    end

    local function draw_arc(store, pts, col)
        if pts == nil then daim("draw_arc pts nil") return end
        local li = 0
        for i = 1, #pts - 1 do
            local p1, ok1 = cam:WorldToViewportPoint(pts[i])
            local p2, ok2 = cam:WorldToViewportPoint(pts[i + 1])
            if ok1 and ok2 and p1.Z > 0 and p2.Z > 0 then
                li = li + 1
                local l = grenade_line(store, li)
                l.From = V2(p1.X, p1.Y)
                l.To = V2(p2.X, p2.Y)
                l.Color = col
                -- 1 = непрозрачно (шкала Drawing обратна роблоксовской); 0.9 давала невидимую линию
                l.Transparency = 1
                l.Thickness = 1.5
                l.Visible = true
            end
        end
        daim(string.format("draw_arc pts=%d drawn=%d col=%s", #pts, li, tostring(col)))
    end

    -- сильный бросок: 75 (throwable_methods:231)
    aimDraw = aimDraw or grenade_draw_new()
    grenade_hide(aimDraw)
    draw_arc(aimDraw, c.pts1, CFG.GrenadeAimColor)

    -- слабый бросок: 40, тем же расчётом, вторым цветом
    if CFG.GrenadeAimWeak then
        aimDrawWeak = aimDrawWeak or grenade_draw_new()
        grenade_hide(aimDrawWeak)
        draw_arc(aimDrawWeak, c.pts2, CFG.GrenadeAimWeakColor)
    elseif aimDrawWeak then
        grenade_hide(aimDrawWeak)
    end
end
end     -- make_grenade_system

--[[ update_grenades / clear_grenades — апвэлы этой функции, поэтому обычные
     присваивания внутри неё уже связали внешние имена; вызов лишь выполняет
     инициализацию (require ECS-мира и прогрев). ]]
make_grenade_system()

--[[ РЕГИСТРЫ. У Luau лимит 200 локалов на ф��нкцию, а верхний уровень файла —
     тоже функция. Изначально служебные локалы прятались в do...end в расчёте,
     что после его закрытия регистры освободятся — ЭТО НЕВЕРНО: do...end даёт
     только область видимости, а регистры остаются занятыми до конца кадра
     функции. Поэтому внутренности вынесены в make_rig_styler() ниже: у неё
     собственный кадр. Наружу торчат apply_rig_style и K.MATERIALS для UI. ]]
K.MATERIALS = {
    "ForceField", "Neon", "Glass", "SmoothPlastic", "Plastic", "Metal",
    "DiamondPlate", "Foil", "Marble", "Granite", "Slate", "Wood", "Ice",
}
-- apply_rig_style объявлен в forward-блоке наверху файла.
--[[ Функция, а не do...end: do-блок не даёт нового кадра регистров, его локалы
     копятся в main и вместе с остальными переполняли лимит 200 (��адало на
     style_part). Здесь у внутренностей свой кадр. ]]
local function make_rig_styler()
local vmStore  = {}          -- [part] = { M, C, T, tex, sa, gp }
local gunStore = {}
local lastRigScan  = 0

local function material_enum(name)
    local ok, en = pcall(function() return Enum.Material[name] end)
    return ok and en or Enum.Material.ForceField
end

--[[ Красит одну часть и запоминает её исходное ��остояние. ]]
local function style_part(d, store, opts)
    if not d:IsA("BasePart") then
        return
    end
    local paint = opts.colorOn or opts.matOn
    local rec = store[d]
    if rec == nil then
        rec = { M = d.Material, C = d.Color, T = d.Transparency }
        if paint then
            if d:IsA("MeshPart") and d.TextureID ~= "" then
                rec.tex = d.TextureID
            end
            local sa = nil
            for _, ch in ipairs(d:GetChildren()) do
                if ch:IsA("SurfaceAppearance") or ch:IsA("Decal") or ch:IsA("Texture") then
                    sa = sa or {}
                    sa[#sa + 1] = { inst = ch, parent = ch.Parent }
                end
            end
            rec.sa = sa
        end
        store[d] = rec
    end

    pcall(function()
        if opts.matOn then d.Material = opts.mat end
        if opts.colorOn then d.Color = opts.color end
        if paint then
            if rec.tex ~= nil and d.TextureID ~= "" then d.TextureID = "" end
            if rec.sa then
                for _, r in ipairs(rec.sa) do
                    if r.inst and r.inst.Parent then r.inst.Parent = nil end
                end
            end
        end
        local tr = opts.transp or 0
        if tr > 0 then
            -- часть, спрятанную самой игрой (T == 1), не «проявляем»
            if rec.T < 1 then d.Transparency = tr end
        elseif rec.T < 1 then
            d.Transparency = rec.T
        end
    end)
end

local function restore_store(store)
    for part, s in pairs(store) do
        if part then
            pcall(function()
                part.Material     = s.M
                part.Color        = s.C
                part.Transparency = s.T
                if s.tex ~= nil then part.TextureID = s.tex end
            end)
            if s.sa then
                for _, r in ipairs(s.sa) do
                    pcall(function()
                        if r.inst and r.parent then r.inst.Parent = r.parent end
                    end)
                end
            end
        end
    end
    table.clear(store)
end

--[[ Пинг-понг A→B→A: на стыке цикла нет разрыва цвета. ]]
local function gradient_color(phase)
    local p = phase % 1
    local t = (p < 0.5) and (p * 2) or (2 - p * 2)
    return CFG.GradientColorA:Lerp(CFG.GradientColorB, t)
end

--[[ Фаза части берётся по её ИНДЕКСУ, а не по мировой позиции: позиция
     вьюмодели меняется каждый кадр, и волна по ней дрожала бы. ]]
local function gradient_phase_index(store)
    local list = {}
    for part in pairs(store) do
        list[#list + 1] = part
    end
    table.sort(list, function(a, b)
        return tostring(a) < tostring(b)
    end)
    for i, part in ipairs(list) do
        local rec = store[part]
        if rec then rec.gp = (i - 1) / math.max(1, #list) end
    end
end

--[[ ── ИМЕНА ЧАСТЕЙ ШАБЛО��А РИГА (= РУКИ) ─────────────────────────────────
     Берём оба шаблона, которыми игра может собрать вьюмодель (BaseItem:118-122):
       новый риг: data.model.viewmodel.newgen.arm_ik_rig
       старый:    data.other.viewmodel
     Оба разом, а не по значению ff_new_rigs: флаг может переключиться между
     раундами, а имена шаблонов не конфликтуют — так результат не зависит от
     того, когда мы посмотрели на флаг.

     Шаблоны в ReplicatedStorage статичны, поэтому набор считается ОДИН раз за
     сессию: это обход дерева, ему нечего делать в кадровом коде. ]]
local rigNamesCache = nil

--[[ Безопасная навигация по дереву. Точечное индексирование (RS.data.model...)
     в��утри pcall выбрасывает ошибку на ПЕРВОМ отсутствующем звене, и весь
     обход молча пропадает — а результат при этом кэшировался. ]]
local function child_path(root, ...)
    local node = root
    for _, name in ipairs({ ... }) do
        if typeof(node) ~= "Instance" then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

local function rig_template_names()
    if rigNamesCache then return rigNamesCache end
    local names = {}
    local function add(inst)
        if typeof(inst) ~= "Instance" then return end
        for _, d in ipairs(inst:GetDescendants()) do
            names[d.Name] = true
        end
    end

    add(child_path(RS, "data", "model", "viewmodel", "newgen", "arm_ik_rig"))
    add(child_path(RS, "data", "other", "viewmodel"))

    --[[ Ресивер и его обвес принадлежат ОРУЖИЮ, но лежат в вьюмодели рядом с
         рукой. Если такое имя пришло из шаблона — убираем, иначе ствол снова
         начнёт считаться рукой. ]]
    names.receiver = nil
    names.attachments = nil

    --[[ ── ПОЧЕМУ GUNMODEL ПРОДОЛЖАЛ КРАСИТЬ РУКИ ─────────────────────────
         Прошлая версия кэшировала результат ВСЕГДА — включая ПУСТОЙ. Если
         на момент первого вызова data.* е��ё не отреплицировалось (или путь
         оборвался на любом звене — точечный доступ падал на первом же
         отсутствующем ребёнке), то в кэш ложилась пустая таблица, рукой не
         считалось НИЧЕГО, весь риг уходил в gunParts, и GunModel красил руки.
         Навсегда: кэш больше не пересматривался.

         Теперь пуст��й результат НЕ кэшируется — попробуем снова на следующем
         кадре, когда дерево доступно. ]]
    if next(names) == nil then
        return names
    end
    rigNamesCache = names
    return names
end

--[[ Разделение рига на руки и оружие — по дампу, а не по именам частей. ]]
local function collect_rig()
    if ctrl == nil then
        return nil, nil, nil
    end
    local weapon = rawget(ctrl, "weapon")
    if type(weapon) ~= "table" then
        return nil, nil, nil
    end
    local vm = rawget(weapon, "viewmodel")
    if typeof(vm) ~= "Instance" then
        return nil, nil, nil
    end

    --[[ ПОЧЕМУ ОРУЖИЕ ОПРЕДЕЛЯЕТСЯ «ВСЁ, ЧТО НЕ РУКА».
        Предыдущая версия брала в gunParts только сам `receiver` и его
        потомков. На гранате это работало (граната ЦЕЛИКОМ и есть receiver —
        поэтому «на гранаты работает»), а на стволе — нет: у собранного оружия
        часть деталей не висит под ресивером. ItemBuild кладёт под
        `model.receiver` только обвес, который проходит через
        clone_attachment_to_receiver (barrel_ModuleScript:44), а корпус,
        магазин и прочее остаются в `weapon_model` рядом с ним. В итоге
        gunParts содержал одну-две детали, визуально не менялось ничего, и
        секция выглядела нерабочей — молча, без ошибок.

        Теперь логика обратная и не зависит от того, угадал ли я раскладку:
        рука — только то, что лежит под явно найденным узлом руки, всё
        остальное в риге — оружие. Ошибиться в минус тут уже нельзя. ]]

    --[[ ── ЧТО РУКА, А ЧТО ОРУЖИЕ: СПРАШИВАЕМ ШАБЛОН РИГА ─────────────────
        ЭТО И БЫЛ БАГ «GunModel МЕНЯЕТ И ОРУЖИЕ, И РУКИ».
        Руки определялись по ИМЕНАМ прямых детей вьюмодели: left / right / arms
        / *arm* / *hand* / *glove*. Это верно только для СТАРОГО рига —
        ItemManager:212-213 действительно берёт viewmodel.left и viewmodel.right.

        Но игра выбирает риг по флагу (BaseItem:118-122), и на новом риге
        вьюмодель �� клон data.model.viewmodel.newgen.arm_ik_rig, где руки зовутся
        hand_l_marker / hand_r_marker и служебными косточками
        (SharedPlayerRigLogic:21-26). Ни одно из этих имён под старый набор не
        подходило: armParts оставался ПУСТЫМ, и все части ��ига проваливались в
        ветку «значит, оружие». Отсюда ровно то, что видно на экране — GunModel
        красит и ствол, и руки, а Viewmodel не красит ничего.

        Поэтому имена больше не угадываем. Оружие попадает в риг единственным
        путём: connect_weapon (SharedPlayerRigLogic:14-18) перевешивает детей
        модели оружия внутрь вьюмодели. Значит рука — то, что пришло из ШАБЛОНА
        рига, а ��ружие — всё остальное. Набор имён шаблона и есть истина. ]]
    local rigNames = rig_template_names()

    local armParts, gunParts = {}, {}

    --[[ Узлы со стороны ОРУЖИЯ имеют приоритет над именами шаблона: ресивер и
         весь его обвес приходят от ствола, даже если имя случайно совпало. ]]
    local receiver = vm:FindFirstChild("receiver", true)

    --[[ ── ВТОРОЙ, НЕЗАВИСИМЫЙ ПРИЗНАК РУКИ ───────────────────────────────
         Полагаться только на имена шаблона нельзя: шаблон может не
         прочитаться. Но у рига есть жёстко заданные узлы рук, и они прописаны
         в самом движке: connects_hands читает hand_l_marker / hand_r_marker
         (SharedPlayerRigLogic:21-26), а старый риг собирается из
         viewmodel.left / viewmodel.right (ItemManager:212-213).
         Это структурный факт, а не догадка по подстроке. ]]
    local ARM_NODES = {
        hand_l_marker = true, hand_r_marker = true,
        left = true, right = true, arms = true,
    }

    for _, d in ipairs(vm:GetDescendants()) do
        if d:IsA("BasePart") then
            local isArm = false
            if not (receiver and (d == receiver or d:IsDescendantOf(receiver))) then
                -- сама часть или любой её предок до вьюмодели есть в шаблоне
                local node = d
                while node ~= nil and node ~= vm do
                    if rigNames[node.Name] or ARM_NODES[node.Name] then
                        isArm = true
                        break
                    end
                    node = node.Parent
                end
            end
            if isArm then
                armParts[#armParts + 1] = d
            else
                gunParts[#gunParts + 1] = d
            end
        end
    end

    --[[ ── ПРЕДОХРАНИТЕЛЬ: НЕ УГАДАЛИ РУКИ — НЕ ТРОГАЕМ РИГ ЦЕЛИКОМ ────────
         Если рукой не опознано НИ ОДНОЙ части, значит распознавание провалилось.
         Прошлое поведение в этом случае было худшим из возможных: «раз рук нет,
         значит весь риг — оружие», и GunModel красил руки. Вместо этого сужаем
         оружие до того, что принадлежит ему гарантированно: ресивер со всем
         обвесом и узел attachments (ItemBuild кладёт обвес именно туда,
         SharedPlayerRigLogic:57). Руку это не заде��ает по определению. ]]
    if #armParts == 0 then
        local safe = {}
        local attachments = vm:FindFirstChild("attachments", true)
        for _, d in ipairs(gunParts) do
            local ownedByGun =
                (receiver and (d == receiver or d:IsDescendantOf(receiver)))
                or (attachments and d:IsDescendantOf(attachments))
            if ownedByGun then safe[#safe + 1] = d end
        end
        gunParts = safe
    end

    --[[ ── ВОТ ЗДЕСЬ GUNMODEL И ЗАБИРАЛ СЕБЕ РУКИ ─────────────────────────
         Ниже был проход по `weapon.build.result.model` — «на случай, если
         сборка положила ствол рядом с вьюмоделью».

         Но build.result.model — это САМА ВЬЮМОДЕЛЬ, а не отдельная модель
         оружия: WeaponItem:331-352 присваивает viewmodel именно результат
         билда. То есть bm == vm.

         А `vm:IsDescendantOf(vm)` — это ЛОЖЬ: инстанс не потомок сам себе.
         Значит условие `not bm:IsDescendantOf(vm)` выполнялось ВСЕГДА, и цикл
         проходил по всем потомкам вьюмодели, дописывая в gunParts ВСЁ подряд —
         вместе с руками, которые пятнадцатью строками выше были аккуратно
         отсортированы в armParts. Отсюда ровно то, что видно в игре: Viewmodel
         красит только руки (он работает по armParts и его это не задело), а
         GunModel красит и оружие, и руки.

         Правильная гарантия — та, о которой сказал пользователь: оружие есть
         РИГ МИНУС ТО, ЧТО УЖЕ ДЕЛАЕТ VIEWMODEL. Держим множество рук и
         вычитаем его при любом добавлении, чтобы рука не могла попасть в
         gunParts никаким путём. ]]
    local isArmPart = {}
    for _, d in ipairs(armParts) do isArmPart[d] = true end

    local bm
    pcall(function() bm = weapon.build.result.model end)
    --[[ Берём модель билда только если это ДЕЙСТВИТЕЛЬНО отдельный узел вне
         вьюмодели. bm == vm и bm-предок-vm отсекаем явно. ]]
    if typeof(bm) == "Instance"
        and bm ~= vm
        and not bm:IsDescendantOf(vm)
        and not vm:IsDescendantOf(bm)
    then
        local seen = {}
        for _, d in ipairs(gunParts) do seen[d] = true end
        local function add_gun(d)
            if d:IsA("BasePart") and not seen[d] and not isArmPart[d] then
                seen[d] = true
                gunParts[#gunParts + 1] = d
            end
        end
        for _, d in ipairs(bm:GetDescendants()) do add_gun(d) end
        add_gun(bm)
    end

    return vm, armParts, gunParts
end

function apply_rig_style(now)
    -- выключено целиком -> вернуть оригиналы и уйти
    if not CFG.VmEnabled and not CFG.GunEnabled then
        if next(vmStore) then restore_store(vmStore) end
        if next(gunStore) then restore_store(gunStore) end
        return
    end

    local vm, armParts, gunParts = collect_rig()
    if vm == nil then
        return
    end

    local phase = now * CFG.GradientSpeed

    if CFG.VmEnabled then
        local col = CFG.VmGradient and gradient_color(phase) or CFG.VmColor
        local opts = {
            colorOn = CFG.VmColorEnabled or CFG.VmGradient,
            color   = col,
            matOn   = CFG.VmMaterialEnabled,
            mat     = material_enum(CFG.VmMaterial),
            transp  = CFG.VmTransparency,
        }
        for _, d in ipairs(armParts) do
            style_part(d, vmStore, opts)
        end
    elseif next(vmStore) then
        restore_store(vmStore)
    end

    if CFG.GunEnabled then
        local baseOpts = {
            matOn  = CFG.GunMaterialEnabled,
            mat    = material_enum(CFG.GunMaterial),
            transp = CFG.GunTransparency,
        }
        --[[ Волна по частям: у каждой части своя фаза (rec.gp), поэтому
             перелив бежит вдоль ствола, а не мигает всем сразу. ]]
        if CFG.GunGradient then
            if now - lastRigScan > 1 then
                lastRigScan = now
                gradient_phase_index(gunStore)
            end
            for _, d in ipairs(gunParts) do
                local rec = gunStore[d]
                local gp = rec and rec.gp or 0
                baseOpts.colorOn = true
                baseOpts.color = gradient_color(phase + gp * CFG.GunGradientSpread)
                style_part(d, gunStore, baseOpts)
            end
        else
            baseOpts.colorOn = CFG.GunColorEnabled
            baseOpts.color = CFG.GunColor
            for _, d in ipairs(gunParts) do
                style_part(d, gunStore, baseOpts)
            end
        end
    elseif next(gunStore) then
        restore_store(gunStore)
    end
end
end     -- make_rig_styler
make_rig_styler()

--======================================================================
--  INSTANT EQUIP
--======================================================================
--[[
    Хукаем get_animation_speed на КЛАССЕ предмета, а не на экземпляре: метод
    объявлен в BaseItem (BaseItem:290) и наследуется всеми стволами через
    __index, поэтому один хук закрывает любое оружие, включая то, что мы
    возьмём в руки позже.

    Ускоряем только треки смены оружия. Стрельбу/перезарядку не трогаем: там
    скорость анимации связана с ре��льными таймерами, и её разгон — это уже
    rate-of-fire чит, который сервер видит.
--]]
-- hook_equip_speed объявлен в forward-блоке наверху файла.
local function make_equip_hook()      -- см. пояснение про кадр регистров выше
local EQUIP_TRACKS = {
    equip = true, unequip = true, deploy = true, holster = true, draw = true,
}

local equipClasses = setmetatable({}, { __mode = "k" })

--[[ Идём по цепочке __index и находим таблицу, у которой get_animation_speed
     СВОЙ ключ. Хук на промежуточном классе не ср��ботал бы. ]]
local function find_method_owner(startTbl, method)
    local seen, node = {}, startTbl
    while type(node) == "table" and not seen[node] do
        seen[node] = true
        if rawget(node, method) ~= nil then
            return node
        end
        local mt = getmetatable(node)
        node = type(mt) == "table" and rawget(mt, "__index") or nil
    end
    return nil
end

function hook_equip_speed()
    if not CFG.InstantEquip or ctrl == nil then
        return
    end
    local weapon = rawget(ctrl, "weapon")
    if type(weapon) ~= "table" then
        return
    end

    local cls = getmetatable(weapon)
    if type(cls) ~= "table" then
        return
    end
    local owner = find_method_owner(cls, "get_animation_speed")
        or find_method_owner(weapon, "get_animation_speed")
    if owner == nil or equipClasses[owner] then
        return
    end

    local orig = rawget(owner, "get_animation_speed")
    if type(orig) ~= "function" then
        return
    end
    equipClasses[owner] = true

    rawset(owner, "get_animation_speed", function(self, name)
        local base = orig(self, name)
        if CFG.InstantEquip and type(name) == "string" and type(base) == "number" then
            if EQUIP_TRACKS[name] then
                return base * CFG.EquipSpeed
            end
        end
        return base
    end)
end
end     -- make_equip_hook
make_equip_hook()

--======================================================================
--  INSTANT AIM
--======================================================================
--[[
    Вызывается КАЖДЫЙ КАДР: игра пересчитывает state_lerps в своём апдейте,
    поэтому р��зов��я установка ничего не даст — её тут же затрёт интерполяция.
    force() ставит значение без перехода (тот же ме���од использует сама игра,
    FPC:1378), так что прицел приходит в конечное положение за один кадр.

    point_aim не трогаем: это отдельный лерп «от бедра», и его форсирование
    ломает переход между обычным и point-прицеливанием.
--]]
-- apply_instant_aim объявлен в forward-блоке наверху файла.
local function make_instant_aim()     -- см. пояснение про кадр регистров выше
local AIM_LERPS = { "final_aim", "aim" }

function apply_instant_aim()
    if not CFG.InstantAim or ctrl == nil then
        return
    end
    if rawget(ctrl, "weapon") == nil then
        return          -- без оружия лерпов нет, get_lerp вернёт 0
    end
    local lerps = rawget(ctrl, "state_lerps")
    if type(lerps) ~= "table" then
        return
    end

    local aiming = rawget(ctrl, "aiming") and true or false
    if not aiming and not CFG.InstantAimOut then
        return
    end

    local goal = aiming and 1 or 0
    for _, key in ipairs(AIM_LERPS) do
        local lv = rawget(lerps, key)
        if type(lv) == "table" then
            pcall(function()
                if type(rawget(getmetatable(lv) or {}, "force")) == "function"
                    or type(lv.force) == "function" then
                    lv:force(goal)
                else
                    -- запасной путь: у SlerpValue поля current/target
                    lv.current = goal
                    lv.target  = goal
                end
            end)
        end
    end
end
end     -- make_instant_aim
make_instant_aim()

--======================================================================
--  INFINITE ARM STAMINA
--======================================================================
--[[
    Подробный разбор механики — в комментарии к CFG.InfArmStamina.

    Здесь важно только одно: пишем ровно max, а не какое-то большое число.
    Игра всё равно зажимает поле в 0..max на FPC:1770, так что запись «с
    запасом» ничего бы не дала, зато один кадр в rifle_methods:1855 считался
    бы с v219 > 1 и вес анимации ушёл бы в отрицательный.

    Максимум берётся из shared_state каждый раз, а не кэшируется: это
    обычное реплицируемое значение, и сервер может его менять по ходу матча.
--]]
apply_arm_stamina = function()
    if not CFG.InfArmStamina or ctrl == nil then
        return
    end
    --[[ Максимум читается тем же хелпером, что и полоски HUD: он без pcall и
         без замыканий (см. комментарий к hud_shared_max), а фолбэк 60 — это
         значение самой игры из shared_state:259. ]]
    local mx = hud_shared_max("plr_max_arm_stamina", 60)
    if rawget(ctrl, "arm_stamina") ~= mx then
        ctrl.arm_stamina = mx
    end
end

local function apply_mods()
    --[[ plr_recoil ВСЕГДА 1. Раньше он опускался до нуля вместе с ползунками, но
         это ГЛОБАЛЬНЫЙ ключ shared_state, а не наш личный: резать им отдачу
         незачем, к��гда per-key значения уже режет scale_group. Держим нейтраль,
         чтобы не влиять на чужой код, читающий тот же ключ. ]]
    set_shared("plr_recoil", 1)
    if CFG.NoSpread then
        set_shared("plr_barrel_deviation", 0)
        set_shared("plr_buck_barrel_deviation", 0)
    end
    if CFG.ClientRollbackMs ~= nil then
        set_shared("plr_replication_rollback_time_ms", CFG.ClientRollbackMs)
    end
    patch_debug_values()
    if ctrl then
        local springs = rawget(ctrl, "springs")
        if type(springs) == "table" then
            for _, key in ipairs(K.SWAY_SPRINGS) do
                local spring = rawget(springs, key)
                if type(spring) == "table" then
                    blockedSprings[spring] = CFG.NoSway or nil
                end
            end
        end
        local smooth = rawget(ctrl, "smooth_values")
        if type(smooth) == "table" and CFG.NoSway then
            for _, key in ipairs({ "swayLagX", "swayLagY" }) do
                local obj = rawget(smooth, key)
                if type(obj) == "table" then
                    pcall(function()
                        obj.value = 0
                        obj.target = 0
                    end)
                end
            end
        end
        hook_springs()
        --[[ Ставится один раз на класс, но пробуем регулярно: класс становится
             доступен только когда в руках реально есть ствол. ]]
        pcall(hook_equip_speed)
        if CFG.FullAuto then
            pcall(function()
                local weapon = rawget(ctrl, "weapon")
                if type(weapon) == "table" and weapon.firemode == "semi" then
                    weapon.firemode = "auto"
                end
            end)
        end
    end
end

--======================================================================
--  ФОНОВЫЕ ЦИКЛЫ
--======================================================================
task.spawn(function()
    while running do
        pcall(refresh_meta)
        pcall(hook_packet)
        pcall(hook_fire)
        pcall(hook_network_hit)
        pcall(gc_caches)
        task.wait(CFG.MetaRefresh)
    end
end)

task.spawn(function()
    while running do
        pcall(apply_mods)
        task.wait(CFG.ModsInterval)
    end
end)

--======================================================================
--  ВЫГРУЗКА
--======================================================================
--[[
    ДИАГНОСТИКА: getgenv().DL.debug()
    Показывает ровно то, что раньше прихо��илось угадывать: нашли ли мы живой
    контроллер и Н��ШУ модель (LocalPlayer.Character тут всегда nil, поэтому это
    главный источник тихих поломок), сколько сущностей видно, есть ли цель и
    какой откат репликации реально прочитан.
--]]
DL.debug = function()
    local tgt = Target and Target.model
    local s = ("ctrl=%s myChar=%s ents=%d esp=%d target=%s rollback=%.0fms genv-traps=%d"):format(
        tostring(ctrl ~= nil),
        myCharacter and tostring(myCharacter.Name) or "nil",
        ent_count,
        (function() local n = 0; for _ in pairs(espByModel) do n += 1 end; return n end)(),
        tgt and tostring(tgt.Name) or "none",
        replication_rollback() * 1000,
        genvKilled)
    log(s)
    return s
end

-- диагностика: getgenv().DL.testsound() — проверить, слышен ли HitSound
DL.testsound = function()
    local saved = CFG.HitSound
    CFG.HitSound = true
    lastHitSoundAt = 0
    play_hit_sound()
    CFG.HitSound = saved
    log(("testsound: route=%s id=%s vol=%.2f"):format(
        hitSoundRoute, tostring(CFG.HitSoundId), CFG.HitSoundVolume))
end

DL.unload = function()
    running = false
    --[[ Снимаем переопределение отдачи, иначе наши числа остались бы в
         debug_values и после выгрузки скрипта (флаг changed живёт в таблице
         игры, а не в нашей). Тот же порядок, что в game_debug_buttons:21-24. ]]
    pcall(function()
        local tbl = get_debug_values()
        if not tbl then return end
        for key, orig in pairs(RECOIL.base) do
            local field = rawget(tbl, key)
            if type(field) == "table" then
                field.value   = orig
                field.changed = false
            end
        end
    end)
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    for model, o in pairs(espByModel) do
        free_esp(o)
        espByModel[model] = nil
    end
    pcall(function()
        fovCircle:Remove()
        muzzleLine:Remove()
        spoofLineA:Remove()
        spoofLineB:Remove()
    end)
    if clear_grenades then pcall(clear_grenades) end
    if clear_grenade_aim then pcall(clear_grenade_aim) end
    pcall(hud_free)
    pcall(muzzle_cross_free)
    for _, line in ipairs(reticleLines) do
        pcall(function() line:Remove() end)
    end
    for _, line in ipairs(tracerLines) do
        pcall(function() line:Remove() end)
    end
    for _, sys in ipairs(particleSystems) do
        for _, particle in ipairs(sys.parts) do
            for _, drawing in ipairs(particle.draw) do
                pcall(function() drawing:Remove() end)
            end
        end
    end
    particleSystems = {}
    for model, hl in pairs(hlByModel) do
        pcall(function() hl:Destroy() end)
        hlByModel[model] = nil
    end
    pcall(function()
        if hlHolder then
            hlHolder:Destroy()
        end
    end)
    table.clear(visCacheT)
    table.clear(visCacheV)
    table.clear(mpCache)
    for spring in pairs(blockedSprings) do
        blockedSprings[spring] = nil
    end
    pcall(function()
        set_shared("plr_recoil", 1)
        set_shared("plr_barrel_deviation", 1)
        set_shared("plr_buck_barrel_deviation", 1)
        set_shared("plr_replication_rollback_time_ms", 190)
    end)
    if getgenv().DL == DL then
        getgenv().DL = nil
    end
    log("unloaded")
end

--======================================================================
--  СТАРТ
--======================================================================
task.wait(0.2)
refresh_meta()
warm_hit_sound()      -- прогреть ассет, чтобы первый хит уже звучал
hook_packet()
hook_fire()
hook_network_hit()
apply_mods()

log(("suite v5 | ents=%d ctrl=%s | packet=%s fire=%s nh=%s | bone=%s"):format(
    ent_count, tostring(ctrl ~= nil), tostring(packet_hooked),
    tostring(fire_hooked), tostring(nh_hooked), tostring(CFG.AimBone)))
log("off: getgenv().DL.unload()  |  cfg: getgenv().DL.config")

--======================================================================
--  LOADER MODULE  (Syllinse Project / MacLib)
--======================================================================
return {
    --[[
        start() НЕ ЗАНУЛЯЕТ НАСТРОЙКИ (раньше здесь принудительно гасились 24
        флага CFG при каждом запуске) и НЕ ЧИТАЕТ НИКАКИХ ФАЙЛОВ. Модуль
        стартует на своих дефолтах; восстановление значений — дело config-системы
        загрузчика, и только по твоей команде Load.
    --]]
    start = function()
        log("started on defaults (persistence is handled by the loader config)")
    end,

    stop = function()
        if DL and type(DL.unload) == "function" then pcall(DL.unload) end
    end,

    buildUI = function(ctx)
        local ready = false
        task.defer(function() ready = true end)
        local function note(t, b) if ready then pcall(ctx.notify, t, b) end end

        --[[
            ВСЕ ХЕЛПЕРЫ БЕРУТ Default ИЗ ЖИВОГО CFG (поле Get), а не из зашитой
            конс��анты: иначе элемент строился бы с Default = false и сразу
            затирал текущее значение своим Callback. Записи на диск здесь нет —
            сохранение делает только config-система загрузчика по кнопке Save.
        --]]
        --[[ Тумблер главной функции секции. Имя всегда "Enabled": название
             самой функции уже стоит в Header, дублировать его незачем.
             Кейбинд всегда называется "Keybind". ]]
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
            el = sec:Toggle({ Name = "Enabled", Default = o.get() and true or false,
                Callback = function(v) if not guard then commit(v) end end },
                ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
            ctx.keybind(sec, { Name = "Keybind", Flag = ctx.flag(o.Flag .. "_KB"),
                Toggle = function() commit(not o.get()) end })
        end

        -- обычный тумблер без кейбинда
        local function bool(sec, name, o)
            sec:Toggle({ Name = name, Default = o.Get() and true or false,
                Callback = function(v)
                    o.set(v and true or false)
                    note(name, v and "Enabled" or "Disabled")
                end },
                ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
        end

        local function slider(sec, o)
            sec:Slider({ Name = o.Name, Default = o.Get(), Minimum = o.Min, Maximum = o.Max,
                Precision = o.Precision or 0, Suffix = o.Suffix, Prefix = o.Prefix,
                Callback = function(v) o.Callback(v) end }, ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
        end

        local function dropdown(sec, o)
            sec:Dropdown({ Name = o.Name, Options = o.Options, Default = o.Get(), Required = true,
                Callback = function(v)
                    if type(v) == "string" and v ~= "" then o.Callback(v) end
                end },
                ctx.flag(o.Flag))
            if o.Desc then sec:SubLabel({ Text = o.Desc }) end
        end

        local function color(sec, o)
            sec:Colorpicker({ Name = o.Name, Default = o.Get(),
                Callback = function(c) o.Callback(c) end }, ctx.flag(o.Flag))
        end

        -- секция с заголовком: header уже нес��т имя функции
        local function section(tab, side, name)
            local s = tab:Section({ Side = side })
            s:Header({ Name = name })
            return s
        end

        --==============================================================
        -- TAB: SILENT AIM
        -- Одна фун��ция = одна секция со своим Header, как в остальных
        -- модулях сьюта. Слева — то, что считает выстрел, справа — то,
        -- что рисует и даёт фидбек.
        --==============================================================
        local A = ctx.tabs.SilentAim

        ---- Silent Aim ------------------------------------------------
        local s = section(A, "Left", "Silent Aim")
        feature(s, { Title = "Silent Aim", Flag = "SA_Enabled",
            get = function() return CFG.SilentAim end,
            set = function(v) CFG.SilentAim = v end })
        s:Divider()
        dropdown(s, { Name = "Aim Bone", Flag = "SA_Bone",
            Options = { "Head", "Torso", "Nearest" },
            Get = function() return CFG.AimBone end,
            Callback = function(v) CFG.AimBone = v end })
        slider(s, { Name = "Max Distance", Flag = "SA_MaxDist",
            Get = function() return CFG.SilentAimMaxDist end,
            Min = 50, Max = 2000, Suffix = " st",
            Callback = function(v) CFG.SilentAimMaxDist = v end })
        bool(s, "Ignore Teammates", { Flag = "SA_NoTeam",
            Get = function() return CFG.IgnoreTeammates end,
            set = function(v) CFG.IgnoreTeammates = v end })
        bool(s, "Skip Blocked", { Flag = "SA_SkipBlocked",
            Get = function() return CFG.SkipBlocked end,
            set = function(v) CFG.SkipBlocked = v end,
            Desc = "off = shoot through walls too (obvious)" })
        slider(s, { Name = "Resolve Rate", Flag = "SA_Resolve",
            Get = function() return CFG.AimResolveInterval * 1000 end,
            Min = 16, Max = 200, Suffix = " ms",
            Callback = function(v) CFG.AimResolveInterval = v / 1000 end,
            Desc = "higher = less work per frame" })

        ---- FOV -------------------------------------------------------
        s = section(A, "Left", "FOV")
        slider(s, { Name = "FOV", Flag = "SA_FOV",
            Get = function() return CFG.SilentAimFOV end,
            Min = 5, Max = 180, Suffix = " deg",
            Callback = function(v) CFG.SilentAimFOV = v end,
            Desc = "targets outside the cone are ignored" })
        s:Divider()
        feature(s, { Title = "FOV Circle", Flag = "SA_FovC",
            get = function() return CFG.FovCircle end,
            set = function(v) CFG.FovCircle = v end,
            Desc = "draws the cone on screen" })
        color(s, { Name = "Circle Color", Flag = "SA_FovCol",
            Get = function() return CFG.FovCircleColor end,
            Callback = function(c) CFG.FovCircleColor = c end })
        slider(s, { Name = "Thickness", Flag = "SA_FovThick",
            Get = function() return CFG.FovCircleThick end,
            Min = 1, Max = 5,
            Callback = function(v) CFG.FovCircleThick = v end })
        bool(s, "Filled", { Flag = "SA_FovFill",
            Get = function() return CFG.FovCircleFilled end,
            set = function(v) CFG.FovCircleFilled = v end })

        ---- Prediction ------------------------------------------------
        s = section(A, "Left", "Prediction")
        feature(s, { Title = "Prediction", Flag = "SA_Predict",
            get = function() return CFG.Prediction end,
            set = function(v) CFG.Prediction = v end })
        s:Divider()
        bool(s, "Rollback Compensation", { Flag = "SA_PredRB",
            Get = function() return CFG.PredictRollback end,
            set = function(v) CFG.PredictRollback = v end })
        slider(s, { Name = "Rollback Factor", Flag = "SA_PredRBF",
            Get = function() return CFG.PredictRollbackFactor * 100 end,
            Min = 0, Max = 150, Suffix = " %",
            Callback = function(v) CFG.PredictRollbackFactor = v / 100 end,
            Desc = "lower it if you overshoot runners" })
        slider(s, { Name = "Max Lead Time", Flag = "SA_PredMax",
            Get = function() return CFG.PredictMaxTime * 1000 end,
            Min = 200, Max = 2000, Suffix = " ms",
            Callback = function(v) CFG.PredictMaxTime = v / 1000 end })
        bool(s, "Vertical Lead", { Flag = "SA_PredVert",
            Get = function() return CFG.PredictVertical end,
            set = function(v) CFG.PredictVertical = v end,
            Desc = "jumps are unpredictable, usually hurts" })
        bool(s, "Wind Compensation", { Flag = "SA_PredWind",
            Get = function() return CFG.PredictWind end,
            set = function(v) CFG.PredictWind = v end })

        ---- MultiPoint ------------------------------------------------
        s = section(A, "Left", "MultiPoint")
        feature(s, { Title = "MultiPoint", Flag = "SA_MP",
            get = function() return CFG.MultiPoint end,
            set = function(v) CFG.MultiPoint = v end })
        s:Divider()
        slider(s, { Name = "Max Offset", Flag = "SA_MPOff",
            Get = function() return CFG.MPMaxOffset end,
            Min = 2, Max = 14, Suffix = " st",
            Callback = function(v) CFG.MPMaxOffset = v end })
        slider(s, { Name = "Search Steps", Flag = "SA_MPSteps",
            Get = function() return CFG.MPBinarySteps end,
            Min = 1, Max = 6,
            Callback = function(v) CFG.MPBinarySteps = v end })
        slider(s, { Name = "Max Targets", Flag = "SA_MPTargets",
            Get = function() return CFG.MPMaxTargets end,
            Min = 1, Max = 8,
            Callback = function(v) CFG.MPMaxTargets = v end })
        bool(s, "Extra Directions", { Flag = "SA_MPDirs",
            Get = function() return CFG.MPExtraDirs end,
            set = function(v) CFG.MPExtraDirs = v end })
        bool(s, "Try Other Bone", { Flag = "SA_MPBone",
            Get = function() return CFG.MPTryOtherBone end,
            set = function(v) CFG.MPTryOtherBone = v end })

        ---- Penetration -----------------------------------------------
        s = section(A, "Left", "Penetration")
        feature(s, { Title = "Penetration", Flag = "SA_Pen",
            get = function() return CFG.AllowPenetrable end,
            set = function(v) CFG.AllowPenetrable = v end })
        s:Divider()
        slider(s, { Name = "Budget", Flag = "SA_PenBudget",
            Get = function() return CFG.PenetrationBudgetUse * 100 end,
            Min = 40, Max = 100, Suffix = " %",
            Callback = function(v) CFG.PenetrationBudgetUse = v / 100 end })
        slider(s, { Name = "Probes", Flag = "SA_PenProbes",
            Get = function() return CFG.MPPenProbes end,
            Min = 1, Max = 4,
            Callback = function(v) CFG.MPPenProbes = v end })

        ---- Origin Spoof (right) --------------------------------------
        s = section(A, "Right", "Origin Spoof")
        feature(s, { Title = "Spoof Origin", Flag = "SA_SpoofOrigin",
            get = function() return CFG.SpoofOrigin end,
            set = function(v) CFG.SpoofOrigin = v end })
        s:Divider()
        slider(s, { Name = "Origin Budget", Flag = "SA_OriginBudget",
            Get = function() return CFG.OriginBudget * 10 end,
            Min = 0, Max = 140, Suffix = " st/10",
            Callback = function(v) CFG.OriginBudget = v / 10 end,
            Desc = "kicked for network tampering? lower this" })
        slider(s, { Name = "Max Bullet Angle", Flag = "SA_MaxAngle",
            Get = function() return CFG.MaxSpoofAngle end,
            Min = 0, Max = 90, Suffix = " deg",
            Callback = function(v) CFG.MaxSpoofAngle = v end })

        ---- Force Hit -------------------------------------------------
        s = section(A, "Right", "Force Hit")
        feature(s, { Title = "Force Hit", Flag = "SA_FH",
            get = function() return CFG.ForceHit end,
            set = function(v) CFG.ForceHit = v end })
        s:Divider()
        dropdown(s, { Name = "Hit Part", Flag = "SA_FHPart",
            Options = { "Head", "Torso" },
            Get = function() return CFG.ForceHitPart end,
            Callback = function(v) CFG.ForceHitPart = v end })
        slider(s, { Name = "Delay", Flag = "SA_FHDelay",
            Get = function() return CFG.ForceHitDelay * 1000 end,
            Min = 0, Max = 120, Suffix = " ms",
            Callback = function(v) CFG.ForceHitDelay = v / 1000 end })

        ---- Reticle ---------------------------------------------------
        s = section(A, "Right", "Reticle")
        feature(s, { Title = "Reticle", Flag = "SA_Reticle",
            get = function() return CFG.AimVisuals end,
            set = function(v) CFG.AimVisuals = v end,
            Desc = "marker on the currently selected target" })
        s:Divider()
        dropdown(s, { Name = "Style", Flag = "SA_ReticleStyle",
            Options = { "Cross", "Dot", "Box", "Diamond" },
            Get = function() return CFG.AimVisualStyle end,
            Callback = function(v) CFG.AimVisualStyle = v end })
        color(s, { Name = "Color", Flag = "SA_ReticleCol",
            Get = function() return CFG.AimVisualColor or Color3.fromRGB(255, 80, 80) end,
            Callback = function(c) CFG.AimVisualColor = c end })
        slider(s, { Name = "Scale", Flag = "SA_ReticleScale",
            Get = function() return CFG.AimVisualScale * 100 end,
            Min = 30, Max = 250, Suffix = " %",
            Callback = function(v) CFG.AimVisualScale = v / 100 end })

        ---- Bullet Tracer ---------------------------------------------
        s = section(A, "Right", "Bullet Tracer")
        feature(s, { Title = "Bullet Tracer", Flag = "SA_Tracer",
            get = function() return CFG.ShotTracers end,
            set = function(v) CFG.ShotTracers = v end,
            Desc = "your shots only" })
        s:Divider()
        color(s, { Name = "Color", Flag = "SA_TracerCol",
            Get = function() return CFG.TracerColor end,
            Callback = function(c) CFG.TracerColor = c end })
        slider(s, { Name = "Duration", Flag = "SA_TracerDur",
            Get = function() return CFG.TracerDuration * 1000 end,
            Min = 100, Max = 1500, Suffix = " ms",
            Callback = function(v) CFG.TracerDuration = v / 1000 end })
        slider(s, { Name = "Thickness", Flag = "SA_TracerThick",
            Get = function() return CFG.TracerThickness end,
            Min = 1, Max = 6,
            Callback = function(v) CFG.TracerThickness = v end })

        ---- Muzzle Line -----------------------------------------------
        s = section(A, "Right", "Muzzle Line")
        feature(s, { Title = "Muzzle Line", Flag = "SA_Muzzle",
            get = function() return CFG.MuzzleVisual end,
            set = function(v) CFG.MuzzleVisual = v end,
            Desc = "shows where the muzzle actually points" })
        s:Divider()
        color(s, { Name = "Color", Flag = "SA_MuzzleCol",
            Get = function() return CFG.MuzzleLineColor end,
            Callback = function(c) CFG.MuzzleLineColor = c end })

        ---- Hit Sound -------------------------------------------------
        s = section(A, "Right", "Hit Sound")
        feature(s, { Title = "Hit Sound", Flag = "SA_HitSnd",
            get = function() return CFG.HitSound end,
            set = function(v) CFG.HitSound = v end })
        s:Divider()
        dropdown(s, { Name = "Preset", Flag = "SA_HitPreset",
            Options = K.HIT_SOUND_ORDER,
            Get = function() return CFG.HitSoundPreset end,
            Callback = function(v) apply_hit_preset(v) end,
            Desc = "Custom keeps the Sound ID below" })
        s:Input({ Name = "Sound ID", Placeholder = "rbxassetid number",
            Default = tostring(CFG.HitSoundId),
            AcceptedCharacters = "Numeric", CharacterLimit = 20,
            Callback = function(txt)
                --[[ Ручной id имеет смысл только вместе с Custom, иначе его
                     затрёт следующий выбор пресета — поэтому переключаем сами. ]]
                local id = tonumber((tostring(txt):gsub("%D", "")))
                if id and id > 0 then
                    CFG.HitSoundId = id
                    CFG.HitSoundPreset = "Custom"
                    warmSound = nil
                end
            end }, ctx.flag("SA_HitId"))
        slider(s, { Name = "Volume", Flag = "SA_HitVol",
            Get = function() return CFG.HitSoundVolume end,
            Min = 0.5, Max = 10, Precision = 1,
            Callback = function(v) CFG.HitSoundVolume = v end,
            Desc = "Roblox range is 0-10, not 0-1" })
        slider(s, { Name = "Pitch", Flag = "SA_HitPitch",
            Get = function() return CFG.HitSoundPitch end,
            Min = 0.5, Max = 2, Precision = 2,
            Callback = function(v) CFG.HitSoundPitch = v end })
        s:Button({ Name = "Test Sound", Callback = function() pcall(DL.testsound) end },
            ctx.flag("SA_BtnSound"))

        ---- Hit Particles ---------------------------------------------
        s = section(A, "Right", "Hit Particles")
        feature(s, { Title = "Hit Particles", Flag = "SA_HitPart",
            get = function() return CFG.HitParticles end,
            set = function(v) CFG.HitParticles = v end })
        s:Divider()
        dropdown(s, { Name = "Type", Flag = "SA_HitPartType",
            Options = { "Wireframe", "Orbs", "Sparks" },
            Get = function() return CFG.HitParticleType end,
            Callback = function(v) CFG.HitParticleType = v end })
        slider(s, { Name = "Count", Flag = "SA_HitPartCount",
            Get = function() return CFG.HitParticleCount end,
            Min = 2, Max = 24,
            Callback = function(v) CFG.HitParticleCount = v end })
        slider(s, { Name = "Duration", Flag = "SA_HitPartDur",
            Get = function() return CFG.HitParticleDur * 1000 end,
            Min = 100, Max = 1200, Suffix = " ms",
            Callback = function(v) CFG.HitParticleDur = v / 1000 end })
        color(s, { Name = "Color A", Flag = "SA_HitPartA",
            Get = function() return CFG.HitParticleColorA end,
            Callback = function(c) CFG.HitParticleColorA = c end })
        color(s, { Name = "Color B", Flag = "SA_HitPartB",
            Get = function() return CFG.HitParticleColorB end,
            Callback = function(c) CFG.HitParticleColorB = c end })

        --==============================================================
        -- TAB: GUN MODS
        -- БЕЗ кейбиндов: моды включаются один раз и ви��ят, биндить их на
        -- клавишу смысла нет (в отличие от Silent Aim / ESP).
        --==============================================================
        local G = ctx.tabs.GunMods

        s = section(G, "Left", "No Recoil")
        bool(s, "Enabled", { Flag = "GM_NoRecoil",
            Get = function() return CFG.NoRecoil end,
            set = function(v) CFG.NoRecoil = v end })
        s:Divider()
        --[[ Проценты ОСТАВШЕЙСЯ отдачи по ��сям. Оба на нуле = отдачи нет
             вообще (как раньше делал один тумблер). ]]
        slider(s, { Name = "Vertical", Flag = "GM_RecoilV",
            Get = function() return CFG.RecoilVertical * 100 end,
            Min = 0, Max = 100, Suffix = " %",
            Callback = function(v) CFG.RecoilVertical = v / 100 end,
            Desc = "0 = no vertical kick, 100 = stock" })
        slider(s, { Name = "Horizontal", Flag = "GM_RecoilH",
            Get = function() return CFG.RecoilHorizontal * 100 end,
            Min = 0, Max = 100, Suffix = " %",
            Callback = function(v) CFG.RecoilHorizontal = v / 100 end,
            Desc = "0 = no sideways kick, 100 = stock" })
        slider(s, { Name = "Camera Shake", Flag = "GM_RecoilCam",
            Get = function() return CFG.RecoilCamera * 100 end,
            Min = 0, Max = 100, Suffix = " %",
            Callback = function(v) CFG.RecoilCamera = v / 100 end })

        s = section(G, "Left", "No Spread")
        bool(s, "Enabled", { Flag = "GM_NoSpread",
            Get = function() return CFG.NoSpread end,
            set = function(v) CFG.NoSpread = v end })

        s = section(G, "Right", "No Sway")
        bool(s, "Enabled", { Flag = "GM_NoSway",
            Get = function() return CFG.NoSway end,
            set = function(v) CFG.NoSway = v end,
            Desc = "removes the idle aim wobble" })
        --[[ Живёт ЗДЕСЬ, а не в отдельной секции: полные руки убирают дрожь
             прицела ровно так же, как No Sway убирает покачивание, — это одна
             и та же задача с точки зрения пользователя. ]]
        s:Divider()
        bool(s, "Infinite Arm Stamina", { Flag = "GM_InfArms",
            Get = function() return CFG.InfArmStamina end,
            set = function(v) CFG.InfArmStamina = v end })
        s:SubLabel({ Text = "the game hides the arm bar when it is full" })

        s = section(G, "Right", "Full Auto")
        bool(s, "Enabled", { Flag = "GM_FullAuto",
            Get = function() return CFG.FullAuto end,
            set = function(v) CFG.FullAuto = v end })
        --[[ Instant Equip и Instant Aim живут ЗДЕСЬ, в существующей секции
             Full Auto: все три — локальное ускорение обращения с оружием,
             новых секций не добавляем. ]]
        s:Divider()
        bool(s, "Instant Equip", { Flag = "GM_InstantEquip",
            Get = function() return CFG.InstantEquip end,
            set = function(v) CFG.InstantEquip = v; if v then pcall(hook_equip_speed) end end,
            Desc = "local only: rate of fire is untouched" })
        slider(s, { Name = "Equip Speed", Flag = "GM_EquipSpeed",
            Get = function() return CFG.EquipSpeed end,
            Min = 2, Max = 30, Suffix = "x",
            Callback = function(v) CFG.EquipSpeed = v end })
        s:Divider()
        bool(s, "Instant Aim", { Flag = "GM_InstantAim",
            Get = function() return CFG.InstantAim end,
            set = function(v) CFG.InstantAim = v end })
        bool(s, "Instant Aim Out", { Flag = "GM_InstantAimOut",
            Get = function() return CFG.InstantAimOut end,
            set = function(v) CFG.InstantAimOut = v end })

        --==============================================================
        -- TAB: VISUALS (ESP)
        --==============================================================
        local V = ctx.tabs.Visuals

        ---- VIEWMODEL / GUNMODEL --------------------------------------
        --[[ Обе секции правят ЛОКАЛЬНЫЙ риг (Workspace.ignore): руки — это
             поддеревья left/right, оружие — поддерево receiver. ]]
        s = section(V, "Right", "Viewmodel")
        feature(s, { Title = "Viewmodel", Flag = "VM_On",
            get = function() return CFG.VmEnabled end,
            set = function(v) CFG.VmEnabled = v end })
        s:Divider()
        bool(s, "Recolor", { Flag = "VM_ColOn",
            Get = function() return CFG.VmColorEnabled end,
            set = function(v) CFG.VmColorEnabled = v end })
        color(s, { Name = "Color", Flag = "VM_Col",
            Get = function() return CFG.VmColor end,
            Callback = function(c) CFG.VmColor = c end })
        bool(s, "Change Material", { Flag = "VM_MatOn",
            Get = function() return CFG.VmMaterialEnabled end,
            set = function(v) CFG.VmMaterialEnabled = v end })
        dropdown(s, { Name = "Material", Flag = "VM_Mat", Options = K.MATERIALS,
            Get = function() return CFG.VmMaterial end,
            Callback = function(v) CFG.VmMaterial = v end })
        slider(s, { Name = "Transparency", Flag = "VM_Tr",
            Get = function() return CFG.VmTransparency * 100 end,
            Min = 0, Max = 100, Suffix = " %",
            Callback = function(v) CFG.VmTransparency = v / 100 end,
            Desc = "0 = untouched, 100 = invisible arms" })
        bool(s, "Gradient", { Flag = "VM_Grad",
            Get = function() return CFG.VmGradient end,
            set = function(v) CFG.VmGradient = v end })
        s:Divider()
        bool(s, "Custom FOV", { Flag = "VM_FovOn",
            Get = function() return CFG.VmFOVEnabled end,
            set = function(v) CFG.VmFOVEnabled = v end,
            Desc = "Scale arms toward/away from camera (local only)" })
        slider(s, { Name = "Arms FOV", Flag = "VM_Fov",
            Get = function() return CFG.VmFOV end,
            Min = 20, Max = 120, Suffix = "°",
            Callback = function(v) CFG.VmFOV = v end,
            Desc = "Lower = arms closer, higher = arms farther" })

        s = section(V, "Right", "Gun Model")
        feature(s, { Title = "Gun Model", Flag = "GMD_On",
            get = function() return CFG.GunEnabled end,
            set = function(v) CFG.GunEnabled = v end })
        s:Divider()
        bool(s, "Recolor", { Flag = "GMD_ColOn",
            Get = function() return CFG.GunColorEnabled end,
            set = function(v) CFG.GunColorEnabled = v end })
        color(s, { Name = "Color", Flag = "GMD_Col",
            Get = function() return CFG.GunColor end,
            Callback = function(c) CFG.GunColor = c end })
        bool(s, "Change Material", { Flag = "GMD_MatOn",
            Get = function() return CFG.GunMaterialEnabled end,
            set = function(v) CFG.GunMaterialEnabled = v end })
        dropdown(s, { Name = "Material", Flag = "GMD_Mat", Options = K.MATERIALS,
            Get = function() return CFG.GunMaterial end,
            Callback = function(v) CFG.GunMaterial = v end })
        slider(s, { Name = "Transparency", Flag = "GMD_Tr",
            Get = function() return CFG.GunTransparency * 100 end,
            Min = 0, Max = 100, Suffix = " %",
            Callback = function(v) CFG.GunTransparency = v / 100 end })
        s:Divider()
        bool(s, "Gradient", { Flag = "GMD_Grad",
            Get = function() return CFG.GunGradient end,
            set = function(v) CFG.GunGradient = v end })
        slider(s, { Name = "Gradient Spread", Flag = "GMD_GradSp",
            Get = function() return CFG.GunGradientSpread * 10 end,
            Min = 0, Max = 50, Suffix = "",
            Callback = function(v) CFG.GunGradientSpread = v / 10 end,
            Desc = "0 = every part in phase" })

        --[[ Общие для обеих секций цвета перелива: держим в GunModel, чтобы
             не плодить третью ��екцию ради двух пикеров. ]]
        s:Divider()
        slider(s, { Name = "Gradient Speed", Flag = "GRD_Sp",
            Get = function() return CFG.GradientSpeed * 100 end,
            Min = 5, Max = 300, Suffix = "",
            Callback = function(v) CFG.GradientSpeed = v / 100 end,
            Desc = "shared by viewmodel and gun" })
        color(s, { Name = "Gradient A", Flag = "GRD_A",
            Get = function() return CFG.GradientColorA end,
            Callback = function(c) CFG.GradientColorA = c end })
        color(s, { Name = "Gradient B", Flag = "GRD_B",
            Get = function() return CFG.GradientColorB end,
            Callback = function(c) CFG.GradientColorB = c end })

        ---- ESP -------------------------------------------------------
        s = section(V, "Left", "ESP")
        feature(s, { Title = "ESP", Flag = "VZ_ESP",
            get = function() return CFG.ESP end,
            set = function(v) CFG.ESP = v end })
        s:Divider()
        slider(s, { Name = "Max Distance", Flag = "VZ_MaxDist",
            Get = function() return CFG.EspMaxDistance end,
            Min = 50, Max = 2000, Suffix = " st",
            Callback = function(v) CFG.EspMaxDistance = v end })
        bool(s, "Enemies Only", { Flag = "VZ_EnemyOnly",
            Get = function() return CFG.EspEnemyOnly end,
            set = function(v) CFG.EspEnemyOnly = v end })
        bool(s, "Visibility Check", { Flag = "VZ_VisCheck",
            Get = function() return CFG.EspVisibleCheck end,
            set = function(v) CFG.EspVisibleCheck = v end,
            Desc = "colors targets you cannot see directly" })
        bool(s, "Smooth Movement", { Flag = "VZ_Smooth",
            Get = function() return CFG.EspSmooth end,
            set = function(v) CFG.EspSmooth = v end })
        s:Divider()
        color(s, { Name = "Visible Color", Flag = "VZ_ColVis",
            Get = function() return CFG.EspColorVisible end,
            Callback = function(c) CFG.EspColorVisible = c end })
        color(s, { Name = "Hidden Color", Flag = "VZ_ColHid",
            Get = function() return CFG.EspColorHidden end,
            Callback = function(c) CFG.EspColorHidden = c end })

        --[[ ОБЪЕДИНЕНО: Box + Head Circle + HP Bar.
            Все три рисуются вокруг одного и того же бокса сущности и включаются
            вместе, а по отдельности занимали три секции ради одного слайдера
            каждая. Skeleton и Chams СОЗНАТЕЛЬНО оставлены отдельно: это не
            геометрия бокса, а рисова��ие по костям рига и подсветка тел. ]]
        s = section(V, "Left", "Box & Bars")
        feature(s, { Title = "Box", Flag = "VZ_Box",
            get = function() return CFG.EspBox end,
            set = function(v) CFG.EspBox = v end })
        s:Divider()
        dropdown(s, { Name = "Style", Flag = "VZ_BoxMode",
            Options = { "Corner", "Full" },
            Get = function() return CFG.EspBoxMode end,
            Callback = function(v) CFG.EspBoxMode = v end })
        slider(s, { Name = "Corner Length", Flag = "VZ_BoxCorner",
            Get = function() return CFG.EspCornerScale * 100 end,
            Min = 10, Max = 50, Suffix = " %",
            Callback = function(v) CFG.EspCornerScale = v / 100 end })
        slider(s, { Name = "Thickness", Flag = "VZ_BoxThick",
            Get = function() return CFG.EspBoxThickness end,
            Min = 1, Max = 4, Precision = 1,
            Callback = function(v) CFG.EspBoxThickness = v end })

        s:Divider()
        feature(s, { Title = "Head Circle", Flag = "VZ_HeadCircle",
            get = function() return CFG.EspHeadCircle end,
            set = function(v) CFG.EspHeadCircle = v end })
        slider(s, { Name = "Circle Thickness", Flag = "VZ_HeadThick",
            Get = function() return CFG.EspHeadCircleThick end,
            Min = 1, Max = 4,
            Callback = function(v) CFG.EspHeadCircleThick = v end })

        s:Divider()
        feature(s, { Title = "HP Bar", Flag = "VZ_HP",
            get = function() return CFG.EspHpBar end,
            set = function(v) CFG.EspHpBar = v end,
            Desc = "bar on the left of the box" })
        color(s, { Name = "Full HP Color", Flag = "VZ_HpHigh",
            Get = function() return CFG.EspHpHigh end,
            Callback = function(c) CFG.EspHpHigh = c end })
        color(s, { Name = "Low HP Color", Flag = "VZ_HpLow",
            Get = function() return CFG.EspHpLow end,
            Callback = function(c) CFG.EspHpLow = c end })

        ---- Text ------------------------------------------------------
        s = section(V, "Left", "Text")
        bool(s, "Name", { Flag = "VZ_Name",
            Get = function() return CFG.EspShowName end,
            set = function(v) CFG.EspShowName = v end })
        bool(s, "Distance", { Flag = "VZ_Dist",
            Get = function() return CFG.EspShowDistance end,
            set = function(v) CFG.EspShowDistance = v end })
        bool(s, "Weapon", { Flag = "VZ_Weapon",
            Get = function() return CFG.EspShowWeapon end,
            set = function(v) CFG.EspShowWeapon = v end,
            Desc = "weapon and ammo under the box" })
        bool(s, "States", { Flag = "VZ_States",
            Get = function() return CFG.EspShowStates end,
            set = function(v) CFG.EspShowStates = v end,
            Desc = "Aiming / Reloading / Prone / NVG" })
        s:Divider()
        slider(s, { Name = "Text Size", Flag = "VZ_TextSize",
            Get = function() return CFG.EspTextSize end,
            Min = 10, Max = 22,
            Callback = function(v) CFG.EspTextSize = v end })
        bool(s, "Name Uses Tier Color", { Flag = "VZ_NameTier",
            Get = function() return CFG.EspNameUseTier end,
            set = function(v) CFG.EspNameUseTier = v end,
            Desc = "off = always use the name color below" })
        color(s, { Name = "Name Color", Flag = "VZ_ColName",
            Get = function() return CFG.EspColorName end,
            Callback = function(c) CFG.EspColorName = c end })
        color(s, { Name = "Distance Color", Flag = "VZ_ColDist",
            Get = function() return CFG.EspColorDist end,
            Callback = function(c) CFG.EspColorDist = c end })
        color(s, { Name = "Weapon Color", Flag = "VZ_ColWep",
            Get = function() return CFG.EspColorWeapon end,
            Callback = function(c) CFG.EspColorWeapon = c end })

        ---- Skeleton --------------------------------------------------
        s = section(V, "Right", "Skeleton")
        feature(s, { Title = "Skeleton", Flag = "VZ_Skel",
            get = function() return CFG.EspSkeleton end,
            set = function(v) CFG.EspSkeleton = v end,
            Desc = "R6 rig, built from the real joints" })
        s:Divider()
        slider(s, { Name = "Max Distance", Flag = "VZ_SkelDist",
            Get = function() return CFG.EspSkeletonMaxDist end,
            Min = 30, Max = 500, Suffix = " st",
            Callback = function(v) CFG.EspSkeletonMaxDist = v end })
        slider(s, { Name = "Thickness", Flag = "VZ_SkelThick",
            Get = function() return CFG.EspSkeletonThick end,
            Min = 1, Max = 4, Precision = 1,
            Callback = function(v) CFG.EspSkeletonThick = v end })
        bool(s, "Own Color", { Flag = "VZ_SkelOwn",
            Get = function() return CFG.EspSkeletonOwnColor end,
            set = function(v) CFG.EspSkeletonOwnColor = v end,
            Desc = "off = follows the visible/hidden colors" })
        color(s, { Name = "Color", Flag = "VZ_SkelCol",
            Get = function() return CFG.EspSkeletonColor end,
            Callback = function(c) CFG.EspSkeletonColor = c end })

        ---- Chams -----------------------------------------------------
        s = section(V, "Right", "Chams")
        feature(s, { Title = "Chams", Flag = "VZ_Chams",
            get = function() return CFG.EspChams end,
            set = function(v) CFG.EspChams = v end,
            Desc = "highlights bodies through walls" })
        s:Divider()
        slider(s, { Name = "Fill Opacity", Flag = "VZ_ChamsFill",
            Get = function() return (1 - CFG.EspChamsFillTrans) * 100 end,
            Min = 0, Max = 100, Suffix = " %",
            Callback = function(v) CFG.EspChamsFillTrans = 1 - v / 100 end })
        slider(s, { Name = "Outline Opacity", Flag = "VZ_ChamsOut",
            Get = function() return (1 - CFG.EspChamsOutTrans) * 100 end,
            Min = 0, Max = 100, Suffix = " %",
            Callback = function(v) CFG.EspChamsOutTrans = 1 - v / 100 end })
        bool(s, "Own Color", { Flag = "VZ_ChamsOwn",
            Get = function() return CFG.EspChamsOwnColor end,
            set = function(v) CFG.EspChamsOwnColor = v end,
            Desc = "off = follows the visible/hidden colors" })
        color(s, { Name = "Visible Color", Flag = "VZ_ChamsColVis",
            Get = function() return CFG.EspChamsColorVis end,
            Callback = function(c) CFG.EspChamsColorVis = c end })
        color(s, { Name = "Hidden Color", Flag = "VZ_ChamsColHid",
            Get = function() return CFG.EspChamsColorHid end,
            Callback = function(c) CFG.EspChamsColorHid = c end })

        ---- Grenades --------------------------------------------------
        s = section(V, "Left", "Grenades")
        feature(s, { Title = "Grenades", Flag = "VZ_Nade",
            get = function() return CFG.Grenades end,
            set = function(v) CFG.Grenades = v end,
            Desc = "fuse timer and predicted flight path" })
        s:Divider()
        bool(s, "Enemy Only", { Flag = "VZ_NadeEnemy",
            Get = function() return CFG.GrenadeEnemyOnly end,
            set = function(v) CFG.GrenadeEnemyOnly = v end,
            Desc = "hides your own throws" })
        slider(s, { Name = "Max Distance", Flag = "VZ_NadeDist",
            Get = function() return CFG.GrenadeMaxDist end,
            Min = 50, Max = 1000, Suffix = " m",
            Callback = function(v) CFG.GrenadeMaxDist = v end })
        s:Divider()
        bool(s, "Marker", { Flag = "VZ_NadeMark",
            Get = function() return CFG.GrenadeMarker end,
            set = function(v) CFG.GrenadeMarker = v end })
        s:Input({ Name = "Icon ID", Placeholder = "rbxassetid number",
            Default = tostring(CFG.GrenadeIconAsset or ""),
            AcceptedCharacters = "Numeric", CharacterLimit = 20,
            Callback = function(txt)
                --[[ Пусто = силуэт линиями. Непустой id качается один раз и
                     кладётся в файл; если не загрузится — снова силуэт. ]]
                local id = tostring(txt):gsub("%D", "")
                CFG.GrenadeIconAsset = (id ~= "" and id or "")
            end }, ctx.flag("VZ_NadeIcon"))
        s:SubLabel({ Text = "empty = drawn silhouette" })
        slider(s, { Name = "Badge Size", Flag = "VZ_NadeMarkSz",
            Get = function() return CFG.GrenadeMarkerSize end,
            Min = 6, Max = 40,
            Callback = function(v) CFG.GrenadeMarkerSize = v end })
        color(s, { Name = "Fuse Full", Flag = "VZ_NadeFuseF",
            Get = function() return CFG.GrenadeFuseFull end,
            Callback = function(c) CFG.GrenadeFuseFull = c end })
        color(s, { Name = "Fuse Empty", Flag = "VZ_NadeFuseL",
            Get = function() return CFG.GrenadeFuseLow end,
            Callback = function(c) CFG.GrenadeFuseLow = c end })
        s:Divider()
        bool(s, "Trajectory", { Flag = "VZ_NadePath",
            Get = function() return CFG.GrenadePath end,
            set = function(v) CFG.GrenadePath = v end })
        slider(s, { Name = "Path Limit", Flag = "VZ_NadePathMax",
            Get = function() return CFG.GrenadePathMaxDist end,
            Min = 50, Max = 600, Suffix = " studs",
            Callback = function(v) CFG.GrenadePathMaxDist = v end,
            Desc = "how far ahead the arc is simulated" })
        slider(s, { Name = "Bounces", Flag = "VZ_NadeBounce",
            Get = function() return CFG.GrenadePathBounces end,
            Min = 0, Max = 8,
            Callback = function(v) CFG.GrenadePathBounces = v end })
        s:Divider()
        bool(s, "Throw Prediction", { Flag = "VZ_NadeAim",
            Get = function() return CFG.GrenadeAim end,
            set = function(v) CFG.GrenadeAim = v end })
        bool(s, "Show Weak Throw", { Flag = "VZ_NadeAimWeak",
            Get = function() return CFG.GrenadeAimWeak end,
            set = function(v) CFG.GrenadeAimWeak = v end,
            Desc = "second arc for the tap throw (40 vs 75)" })
        color(s, { Name = "Throw Color", Flag = "VZ_NadeAimCol",
            Get = function() return CFG.GrenadeAimColor end,
            Callback = function(c) CFG.GrenadeAimColor = c end })
        color(s, { Name = "Weak Throw Color", Flag = "VZ_NadeAimColW",
            Get = function() return CFG.GrenadeAimWeakColor end,
            Callback = function(c) CFG.GrenadeAimWeakColor = c end })
        s:Divider()
        color(s, { Name = "Own Color", Flag = "VZ_NadeColMine",
            Get = function() return CFG.GrenadeColorMine end,
            Callback = function(c) CFG.GrenadeColorMine = c end })
        color(s, { Name = "Enemy Color", Flag = "VZ_NadeColEnemy",
            Get = function() return CFG.GrenadeColorEnemy end,
            Callback = function(c) CFG.GrenadeColorEnemy = c end })

        ---- Status HUD ------------------------------------------------
        s = section(V, "Right", "Status HUD")
        feature(s, { Title = "Status HUD", Flag = "VZ_Hud",
            get = function() return CFG.Hud end,
            set = function(v) CFG.Hud = v end,
            Desc = "reads the same fields the game HUD reads" })
        bool(s, "Move HUD", { Flag = "VZ_HudMove",
            Get = function() return CFG.HudMove end,
            set = function(v) CFG.HudMove = v end,
            Desc = "hold left mouse on the panel to move it" })
        slider(s, { Name = "Scale", Flag = "VZ_HudScale",
            Get = function() return CFG.HudScale end,
            Min = 0.6, Max = 2.5, Precision = 2,
            Callback = function(v) CFG.HudScale = v end })
        bool(s, "Bars", { Flag = "VZ_HudBars",
            Get = function() return CFG.HudBars end,
            set = function(v) CFG.HudBars = v end })
        s:Divider()
        dropdown(s, { Name = "Anchor", Flag = "VZ_HudAnchor",
            Options = { "Muzzle", "Fixed" },
            Get = function() return CFG.HudAnchor end,
            Callback = function(v) CFG.HudAnchor = v end })
        dropdown(s, { Name = "Muzzle Side", Flag = "VZ_HudMzSide",
            Options = { "Right", "Left" },
            Get = function() return CFG.HudMuzzleSide end,
            Callback = function(v) CFG.HudMuzzleSide = v end })
        slider(s, { Name = "Muzzle Offset X", Flag = "VZ_HudMzOffX",
            Get = function() return CFG.HudMuzzleOffX end,
            Min = 0, Max = 400,
            Callback = function(v) CFG.HudMuzzleOffX = v end })
        slider(s, { Name = "Muzzle Offset Y", Flag = "VZ_HudMzOffY",
            Get = function() return CFG.HudMuzzleOffY end,
            Min = -300, Max = 300,
            Callback = function(v) CFG.HudMuzzleOffY = v end })
        s:Divider()
        bool(s, "Animations", { Flag = "VZ_HudAnim",
            Get = function() return CFG.HudAnim end,
            set = function(v) CFG.HudAnim = v end })
        slider(s, { Name = "Animation Speed", Flag = "VZ_HudAnimSpd",
            Get = function() return CFG.HudAnimSpeed end,
            Min = 1, Max = 30,
            Callback = function(v) CFG.HudAnimSpeed = v end })
        s:Divider()
        bool(s, "Ammo", { Flag = "VZ_HudAmmo",
            Get = function() return CFG.HudAmmo end,
            set = function(v) CFG.HudAmmo = v end,
            Desc = "rounds left in the magazine" })
        bool(s, "Health", { Flag = "VZ_HudHp",
            Get = function() return CFG.HudHealth end,
            set = function(v) CFG.HudHealth = v end })
        bool(s, "Stamina", { Flag = "VZ_HudStam",
            Get = function() return CFG.HudStamina end,
            set = function(v) CFG.HudStamina = v end })
        bool(s, "Arm Stamina", { Flag = "VZ_HudArms",
            Get = function() return CFG.HudArms end,
            set = function(v) CFG.HudArms = v end,
            Desc = "drives the aim shake" })
        bool(s, "Adrenaline", { Flag = "VZ_HudAdr",
            Get = function() return CFG.HudAdrenaline end,
            set = function(v) CFG.HudAdrenaline = v end })
        bool(s, "Speed", { Flag = "VZ_HudSpd",
            Get = function() return CFG.HudSpeed end,
            set = function(v) CFG.HudSpeed = v end })
        s:Divider()
        color(s, { Name = "Accent", Flag = "VZ_HudAcc",
            Get = function() return CFG.HudAccent end,
            Callback = function(c) CFG.HudAccent = c end })
        color(s, { Name = "Background", Flag = "VZ_HudBg",
            Get = function() return CFG.HudBg end,
            Callback = function(c) CFG.HudBg = c end })
        color(s, { Name = "Text", Flag = "VZ_HudTxt",
            Get = function() return CFG.HudText end,
            Callback = function(c) CFG.HudText = c end })
        color(s, { Name = "Muted Text", Flag = "VZ_HudDim",
            Get = function() return CFG.HudDim end,
            Callback = function(c) CFG.HudDim = c end })
        s:Divider()
        bool(s, "Gradient", { Flag = "VZ_HudGrad",
            Get = function() return CFG.HudGradient end,
            set = function(v) CFG.HudGradient = v end })
        color(s, { Name = "Background Fade", Flag = "VZ_HudBg2",
            Get = function() return CFG.HudBg2 end,
            Callback = function(c) CFG.HudBg2 = c end })
        color(s, { Name = "Accent Fade", Flag = "VZ_HudAcc2",
            Get = function() return CFG.HudAccent2 end,
            Callback = function(c) CFG.HudAccent2 = c end })

        ---- Muzzle Crosshair ------------------------------------------
        s = section(V, "Right", "Muzzle Crosshair")
        feature(s, { Title = "Muzzle Crosshair", Flag = "VZ_MzCross",
            get = function() return CFG.MuzzleCross end,
            set = function(v) CFG.MuzzleCross = v end })
        slider(s, { Name = "Distance", Flag = "VZ_MzDist",
            Get = function() return CFG.MuzzleCrossDist end,
            Min = 1, Max = 60, Precision = 1,
            Callback = function(v) CFG.MuzzleCrossDist = v end,
            Desc = "how far down the barrel the mark sits" })
        slider(s, { Name = "Size", Flag = "VZ_MzSize",
            Get = function() return CFG.MuzzleCrossSize end,
            Min = 1, Max = 20,
            Callback = function(v) CFG.MuzzleCrossSize = v end })
        slider(s, { Name = "Gap", Flag = "VZ_MzGap",
            Get = function() return CFG.MuzzleCrossGap end,
            Min = 0, Max = 20,
            Callback = function(v) CFG.MuzzleCrossGap = v end })
        slider(s, { Name = "Thickness", Flag = "VZ_MzThick",
            Get = function() return CFG.MuzzleCrossThick end,
            Min = 1, Max = 5, Precision = 1,
            Callback = function(v) CFG.MuzzleCrossThick = v end })
        bool(s, "Center Dot", { Flag = "VZ_MzDot",
            Get = function() return CFG.MuzzleCrossDot end,
            set = function(v) CFG.MuzzleCrossDot = v end })
        s:Divider()
        bool(s, "Spin", { Flag = "VZ_MzSpin",
            Get = function() return CFG.MuzzleCrossSpin end,
            set = function(v) CFG.MuzzleCrossSpin = v end })
        slider(s, { Name = "Spin Speed", Flag = "VZ_MzSpinSpd",
            Get = function() return CFG.MuzzleCrossSpinSpd end,
            Min = -720, Max = 720, Suffix = " deg/s",
            Callback = function(v) CFG.MuzzleCrossSpinSpd = v end,
            Desc = "negative spins the other way" })
        s:Divider()
        color(s, { Name = "Color", Flag = "VZ_MzCol",
            Get = function() return CFG.MuzzleCrossColor end,
            Callback = function(c) CFG.MuzzleCrossColor = c end })

        --==============================================================
        -- TAB: DEBUG  (created by the loader)
        --==============================================================
        s = section(ctx.tabs.Debug, "Left", "Silent Aim")
        s:Button({ Name = "Print Aim Debug", Callback = function()
            pcall(DL.debug); note("Silent Aim", "debug -> console")
        end }, ctx.flag("SA_BtnDebug"))
        s:Button({ Name = "Test Hit Sound", Callback = function()
            pcall(DL.testsound)
        end }, ctx.flag("SA_BtnSound2"))
        -- кнопки "Save Settings Now" больше нет: сохранение живёт в штатной
        -- config-секции загрузчика (Tab:InsertConfigSection), дублировать её незачем
    end,
}
