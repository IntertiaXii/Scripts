do
	local _E = (getgenv and getgenv()) or _G
	if not _E["LPH_NO_VIRTUALIZE"] then
		local id, nop = function(f) return f end, function() end
		_E["LPH_NO_VIRTUALIZE"] = id
		_E["LPH_JIT_MAX"] = id
		_E["LPH_JIT"] = id
		_E["LPH_ENCFUNC"] = id
		_E["LPH_NO_UPVALUES"] = id
		_E["LPH_ENCSTR"] = id
		_E["LPH_ENCNUM"] = id
		_E["LPH_SKIP"] = id
		_E["LPH_CRASH"] = nop
	end
end
-- Главный чанк упирался в лимит Luau (200 локальных регистров на функцию), и
-- Syllinse/Luraph (компилирует без -O2, поэтому мёртвые локалы не сливаются)
-- падал с "Out of local registers". 60 локалов свёрнуты в две таблицы.
-- ОБЪЯВЛЕНИЯ ДОЛЖНЫ БЫТЬ ЗДЕСЬ, В САМОМ ВЕРХУ: обе таблицы заполняются уже на
-- строке ~400 (_D.LEGACY_ATTACKS), и если объявить их ниже первого присваивания,
-- получим runtime "attempt to index nil with 'LEGACY_ATTACKS'".
local _C = {}   -- приватные кеши/счётчики (29 локалов -> 1)
local _D = {}   -- статические таблицы данных и буферы логов (31 -> 1)

local Config = {
	Version       = "V176",
	Enabled       = false,
	Mode          = "Perfect",

	-- ДАЛЬНОСТЬ. Раньше 36 студов — почти вдвое больше физически возможной.
	-- Из дампа игры: M1.DefaultHitboxForwardOffset=4, M2=3, т.е. хитбокс ставится
	-- в 3-4 студах перед атакующим. Плюс полширины хитбокса и радиусы двух тел —
	-- реальный предел попадания ~13 студов. Из-за 36 в список угроз лезли чужие
	-- размены (в логе: dist=17, 19, 28 — все потом отлетали как geometry-rejected,
	-- но успевали раздуть кластер и утащить защиту в блок).
	Range         = 15,
	-- Запас на сближение во время замаха. MaxWait=1.6с давал 22*1.6=35 студов
	-- допуска, что возвращало старое поведение. Реальный замах M1 = 0.32с,
	-- M2 = 0.30с, поэтому добежать успевают максимум ~8 студов.
	ReachCloseCap = 8,
	RequireFacing = false,
	IncludeNPCs   = true,
	HeavyEnabled  = true,

	M1Forward     = 4,
	M2Forward     = 3,
	HitboxDepth   = 4.0,
	HitboxDepthBack = 1.0,
	HitHalfWidth  = 3.0,
	HitboxSlack   = 0.5,
	HighSlack     = 0.35,
	HighReachPad  = 3.0,
	HighFaceFloor = -0.85,
	-- Допуск на ошибку РЕКОНСТРУКЦИИ бокса, а не игровой префильтр. Было 6.0 —
	-- это Size/2+6 из VictimHitboxServiceClient, то есть широкая фаза «кого
	-- вообще проверять». Как тест попадания он раздувал вылет на 6 стадов и
	-- пропускал врагов с dist=9..10. Сближение учитывается отдельно
	-- (approachAllow), поэтому здесь нужен только запас на реконструкцию.
	ProvenReachPad    = 2.0,
	ProvenReachWindow = 0.18,  -- только когда контакт ближе этого (сек) — чтоб не ловить далёкий фейк-спам
	WillHitLeadFrac = 0.90,
	FilterFailSafe= true,
	-- Абсолютный потолок угла до нас: больше — удар физически не наш.
	-- Было 115° и применялось как cos-порог, т.е. конус 230° — не фильтр вовсе.
	FaceHardDeg     = 100,
	-- Добавка на мгновенный снап CFrame.lookAt в момент создания хитбокса
	-- (M2_ModuleScript:358): кинематикой он не ловится, но и бесконечным быть
	-- не может. Основной бюджет доворота считается по ИЗМЕРЕННОЙ скорости
	-- сокращения угла до нас. Разбор — в willHitMe.
	TurnSnapDeg     = 35,
	-- Не удерживать решение об угрозе, когда враг отвернулся или ушёл далеко:
	-- sticky должен переживать только погрешность реконструкции бокса.
	StickyStrict    = true,
	StickyReachPad  = 4.0,
	-- Тот же принцип для geom-латча (третий обход фильтра, он же главная причина
	-- реакции на чужие удары): держим только погрешность реконструкции бокса,
	-- а не свинг, который явно летит в союзника.
	LatchStrict     = true,
	LatchSidePad    = 4.0,
	-- Не снимать 2-й удар связки (Boxing M2) по транзиентному Stunned атакующего:
	-- отмену связки мы узнаём явно из исхода 1-го удара (group.cancelled).
	MultiHitKeep    = true,
	-- Гард последнего шанса: если парри на кулдауне И додж недоступен — не
	-- отпускать блок, чтобы удар пришёл в поднятый гард, а не чистым.
	GuardLastResort        = true,
	GuardLastResortHorizon = 0.8,

	AccuracyMode  = "High",

	WillHitVelCap   = 2.0,
	WillHitCloseCap = 12,
	WillHitLatCap   = 1.5,

	FeintFrac     = 0.80,
	FeintGraceMs  = 90,

	ComboEscape        = true,
	ComboEscapeDodge   = true,
	DodgeOnParryCooldown = true,
	StunReleaseLead    = 0.14,
	GuardbreakProtect  = true,
	StaminaFloor       = 18,
	StaminaAttrs       = { "Stamina", "BlockStamina", "GuardStamina", "Posture", "Guard" },

	-- ── ОКНО ПЕРФЕКТ-БЛОКА ────────────────────────────────────────────────────
	-- Игра: CombatConfig.Block.PerfectBlockWindow = 0.125 (БЫЛО 0.15 до апдейта).
	-- Окно = [contact-0.125 .. contact]. Нажал РАНЬШЕ окна → обычный блок, а не парри.
	-- Именно поэтому скрипт "иногда блокирует, а не парирует".
	-- PerfectWindowLive=true → берём значение из живого CombatConfig (переживает апдейты).
	PerfectWindow = 0.125,
	PerfectWindowLive = true,
	PerfectMin    = 0.05,
	PerfectLead   = 0.0625,   -- центр окна 0.125 → максимальный запас с обеих сторон
	HoldAfter     = 0.12,
	HoldLateGrace = 0.14,

	-- ── КАЛИБРОВКА СЕРВЕРНОГО ЗАЗОРА (КОРЕНЬ ПРОМАХОВ) ────────────────────────
	-- Мы НЕ МОЖЕМ измерить настоящий зазор «блок дошёл до сервера → хитбокс».
	-- Всё, что есть, — trueGap = (eventServer - pressServer) - uplink, и он
	-- СИСТЕМАТИЧЕСКИ ЗАВЫШЕН. Доказательство из диага 870989 (окно 125мс, все
	-- строки guard=IN-WINDOW, т.е. сам скрипт считал, что попал):
	--     trueGap 44мс → HIT      59мс → LATE     68мс → LATE
	--     trueGap 87мс → PERFECT 100мс → PERFECT 106мс → PERFECT  124мс → PERFECT
	-- Граница исхода лежит между 68 и 87, а не на нуле. Значит настоящий зазор =
	-- trueGap - X, где X ≈ 75мс. Тогда всё сходится: 87→12мс (внутри окна, но у
	-- самого ��р��я), 106→31мс, а провалы 68→-7мс и 59→-16мс — блок пришёл ПОСЛЕ
	-- удара. Механизм X разложим:
	--   ~38мс — uplink вычитает RTT*0.5 (up=83) при истинном одностороннем ~45мс;
	--   ~30мс — разрыв между локальным чтением GetServerTimeNow и меткой сервера
	--            (в логе detect→press по srv = 183..200мс при pressDt 151..182мс);
	--   ~33мс — VictimHitboxServiceClient сканирует оверлап на 30Гц и сам шлёт
	--            VictimHitConfirm, т.е. событие ещё и квантовано тиком скана.
	-- ГЛАВНОЕ СЛЕДСТВИЕ: цель зазора в LEAD-QUANT задавалась в «реальных»
	-- ��оординатах (центр окна 62мс), а сравнивалась с величиной, живущей в
	-- координатах trueGap. Итог: настоящий зазор выходил 62-75 = -13мс, т.е.
	-- НОЛЬ С МИНУСОМ, и исход решал джиттер ±25мс → 8 PERFECT на 7 провалов.
	-- Здесь мы переводим цель и оба капа в координаты trueGap прибавлением X.
	-- Пересчёт при смене региона/хостинга: собрать по логу минимальный trueGap
	-- с result=PERFECT и максимальный с LATE, X ≈ (min_perfect + max_late) / 2.
	-- ⚠ ПОПРАВКА К РАЗБОРУ ВЫШЕ (важно, читать перед тюнингом):
	-- Вывод «X ≈ 75мс» был получе�� из корреляции trueGap с исходом, а trueGap
	-- считается как (detectServer + measured) - pressServer - uplink, где
	-- `measured` — момент ОСТАНОВКИ анимации атакующего. Анимация встаёт ПОТОМУ,
	-- что мы успешно парировали. То есть trueGap раздувается САМИМ УСПЕХОМ, и
	-- «PERFECT имеет больший trueGap» — это следствие, а не причина. Я принял
	-- следствие за причину, ровно та же ловушка, из-за которой отключён ResidComp.
	-- Что говорят ЧИСТЫЕ данные (серверные метки + HitboxDelay из конфига,
	-- без участия `measured`), лог 2 (Kure, contact=290мс):
	--   PERFECT: press приходит на сервер за ~86мс до удара
	--   HIT:     press приходит за ~80мс  ← НЕОТЛИЧИМО
	-- Тайминг нажатия в этих провалах НЕ ВИНОВАТ вообще. Настоящие причины
	-- разобраны у BlockCooldownPredict ниже.
	-- Поэтому офсет снижен 75 → 40: при 75 прицел уезжал на 137мс, а окно 125мс,
	-- то есть скрипт СОЗНАТЕЛЬНО целился за верхний край окна (в логе это видно
	-- как guard=EARLY(>125)=BLOCK-NOT-PARRY почти на каждой строке). 40 держит
	-- прицел ~102мс — внутри окна, но с запасом от нижнего края, где промах.
	ServerGapOffsetMs = 40,
	-- Диаг��остика калибровки: пишет в лог фактическую границу PERFECT/LATE по
	-- накопленным trueGap, чтобы ServerGapOffsetMs можно было уточнить по факту.
	GapCalibDiag  = true,

	-- ── КОМПЕНСАЦИЯ ПИНГА В АНИМАЦИЯХ (НОВОЕ В АПДЕЙТЕ) ───────────────────────
	-- Игра добавила Shared.Utils.CombatPingAnimUtils:
	--   animSpeed = heightMult * (delay / (delay + clamp(ping/2, 0, 0.35)))
	-- Т.е. анимация атакующего ЗАМЕДЛЯЕТСЯ на его пол-пинга (до 350 мс!), чтобы
	-- визуал совпал с серверным моментом хитбокса.
	-- Вывод (математика в animContactTime): хитбокс всегда с��а��атывает на
	-- ФИКСИРОВАННОЙ позиции анимации TimePosition == delay+extra, независимо от
	-- роста и пинга. Поэтому единственно верная модель:
	--   remainingWall = (animContact - TimePosition) / track.Speed
	-- Старый код делил на heightMult и игнорировал пинг → стрелял до 350 мс раньше.
	AnimTimeModel   = true,   -- считать контакт в аним-времени и делить на живой Speed
	AnimPingCompMax = 0.35,   -- = Shared.NetworkAnimPingCompensation.MaxEstimatedOneWaySeconds
	HitboxWindupExtra = 0.012, -- = Shared.HitboxWindupExtra (фолбэк, живое из cfg)
	SpeedSanityMin  = 0.20,   -- защита от мусорного track.Speed
	SpeedSanityMax  = 3.00,

	-- ── ЗАМЫКАНИЕ ОБРАТНОЙ СВЯЗИ ПО СКРЫТОМУ ПОЛ-ПИНГУ АТАКУЮЩЕГО ─────────────
	-- КОРЕНЬ БАГА "блок вместо парри": track.Speed у ЧУЖОЙ анимации на нашем
	-- клиенте читается ~1.0. Замедление на пол-пинг (CombatPingAnimUtils) игра
	-- применяет на клиенте АТАКУЮЩЕГО через AdjustSpeed — оно НЕ реплицируется
	-- как читаемая скорость трека. Поэтому remaining=(animContact-tp)/Speed
	-- делит на 1.0 и прогноз контакта всегда РАНЬШЕ реального на пол-пинг
	-- атакующего. В логах это ровно predErr/resAvg = +50..+145мс (всегда «+»).
	-- Пинг чужого игрока клиентом НЕ читается → единственный источник истины —
	-- измеренный постфактум остаток. Копим его per-attacker (задержка = пол-пинг,
	-- от стиля почти не зависит) и ДОБАВЛЯЕМ к contactAbs, сдвигая нажатие �� окно.
	-- ВАЖНО про величину сдвига. Диаг чужих игроков показал, что predErr вокруг
	-- своего среднего гуляет ОГРОМНО: у tutelzs подряд шли +64,-46,+31,-15,-83,
	-- +159,-107,-150 при истинном среднем ~+30мс. Быстрая EMA (alpha=0.35) на таком
	-- шуме сама превращалась в шум и уводила bias до +151мс — при окне парри всего
	-- 125мс это гарантированный промах В ДРУГУЮ сторону (в логах поток guard=LATE,
	-- pressLate=+96..+196мс, accuracy 37%). Поэтому теперь:
	--   * не EMA, а устойчивое СРЕДНЕЕ по выборке (sum/n) — ��ум ус��едняется;
	--   * прогрев ResidCompMinN: пока замеров мало, сдвиг НЕ применяем вообще;
	--   * ResidCompShrink: применяем лишь часть измеренного среднего (недо-коррекция
	--     всегда безопаснее пере-коррекции, т.к. окно узкое);
	--   * ResidCompMax порезан с 350мс до 45мс — сдвиг это тонкая доводка внутрь
	--     окна, а не полпинга-костыль;
	--   * ResidCompSeedMs=0 — слепой приор +45мс всем новым врагам раньше сдвигал
	--     первые (самые важные) нажатия в LATE ещё до единого замера.
	-- ВНИМАНИЕ: сам тумблер ResidComp объявлен ОДИН раз — ниже, рядом с GapBiasComp
	-- (здесь он раньше стоял вторым дублем и молча перебивался). Ниже — только его
	-- параметры, они применяются лишь когда ResidComp включён.
	ResidCompMax    = 0.045,  -- максимум сдвига (сек). Окно парри = 125мс
	ResidCompMinMs  = -20,    -- шум ниже -20мс не двигает прогноз (не жмём раньше)
	ResidCompMinN   = 6,      -- прогрев: меньше 6 замеров → сдвиг 0
	ResidCompShrink = 0.5,    -- применяем половину измеренного среднего
	ResidCompSeedMs = 0,      -- ��икакого слепо��о приора
	ResidCompLoMs   = -120,   -- замеры вне [lo,hi] — выброс, в среднее не берём
	ResidCompHiMs   = 220,
	ResidCompWinN   = 40,     -- длина окна усреднения per-attacker

	-- Санитария списка угроз (см. THREAT-EXPIRE). Без неё встрявшие анимации
	-- накапливались как вечные угрозы и переводили защиту в HELD_GUARD.
	ThreatStallSec   = 0.45,  -- dt не меняется столько → трек встал, угроза фантом
	ThreatMaxAgeSec  = 1.5,   -- абсолютный предел жизни свинга сверх его анимации
	LatchClusterGrace = 0.25, -- latch держим для блока, но в кластер не пускаем

	PerHitRearm   = true,
	BlockFaceHard   = true,
	BlockFaceHardDt = 0.30,

	M2WidenWindow = false,
	M2WidenFront  = 0.22,
	M2WidenHold   = 0.10,

	HitboxDodge     = true,

	ChargeStallMs = 45,
	ReleaseGap    = 0.40,

	FaceGateMin   = 0.2,

	-- uplink компенсирует время, за которое НАШЕ нажатие дойдёт до сервера, то есть
	-- ОДНОСТОРОННЕЕ время. А getPingRaw() возвращает RTT (берёт max из
	-- GetNetworkPing и Stats "Data Ping" — оба туда-обратно). Множитель 1.0
	-- вычитал полный RTT, то есть примерно вдвое больше нужного: в логе
	-- up=68..92ms при изме��енном одностороннем 27..44ms.
	-- Эта ошибка ЧАСТИЧНО ГАСИЛА две другие (поздний contact +40ms и ложный
	-- ovDelay +40ms), поэтому править её можно только вместе с ними — что и
	-- сделано в этой ревизии. Баланс по логу: было +38ms позже идеала, теперь ~0.
	UplinkFactor  = 0.5,
	UplinkMargin  = 0.008,
	UplinkMin     = 0.010,
	-- Надбавка на низком пинге убрана (была 0.030): она компенсировала те самые
	-- ошибки, а не реальную сеть, и на пинге 50ms давала лишние +13ms.
	LowPingFloor   = 0.0,
	LowPingThresh  = 0.090,
	UplinkMax     = 0.500,
	PingCap       = 0.500,
	PingSourceMaxRatio = 2.5,
	PingWindow    = 24,
	PingSampleGap = 0.03,

	OverlapLeadBase = 2.0,
	OverlapReaction = 0.050,
	OverlapLeadCap  = 18.0,

	MoveLeadMax   = 0.045,
	MoveSpeedFull = 22,

	MaxWait       = 1.6,

	MinActGap     = 0.004,
	MinDeactGap   = 0.050,

	MatchWindow   = 1.30,
	MultiHitWindow = 1.30,

	AutoDodge     = true,
	DodgeHeavy    = true,
	FOV           = 360,

	MustDodge       = true,
	MustDodgeAutoGrab = true,
	MustDodgeStyles = {
		wrestling = { M2 = true },
		kure = { M2 = true },
	},

	IFrameDur     = 0.30,
	DodgeLead     = 0.10,
	UseServerCooldown = true,
	DodgeCooldown = 2.05,
	-- ── ДОПУЩЕНИЕ ПО ТАЙМИНГУ ДОДЖА В ЗАМЕСЕ ─────────────────────────────────
	-- В мультитаргете идеальное попадание в середину i-фреймов не требуется:
	-- лучше уйти чуть позже и накрыть остальные удары, чем не уйти вовсе.
	-- Работает только при >= MultiThreatMinN угроз, одиночный бой не задет.
	MultiDodgeLate      = true,
	MultiDodgeLateGrace = 0.06,
	-- Рост атакующего: глубокие источники (HumanoidDescription, HipHeight).
	-- Без них у низких/быстрых врагов aMult молча оставался 1.0 и скрипт
	-- опаздывал с нажатием → блок вместо парри. Разбор в attackSpeedMult.
	HeightDeepFallback  = true,

	-- ── НОВЫЕ КОНСТАНТЫ АПДЕЙТА (Evasive / ClientPredict / Shared) ────────────
	-- Раньше в скрипте не использовалась ни одна из них.
	-- Evasive: DashDuration = 0.2, DashSpeed = 30, IFrameDuration = 0.3,
	-- Cooldown = 1.5, а В ОКРУЖЕНИИ НЕСКОЛЬКИХ ВРАГ��В рывок УДЛИНЯЕТСЯ:
	--   OutnumberedDashSpeedMultiplier    = 1.5
	--   OutnumberedDashDurationMultiplier = 1.2   → 0.2 * 1.2 = 0.24с
	-- Планировщик доджа считал длительность как фиксированные 0.2с и в свалке
	-- систематически ошибался на 40мс.
	-- (сами DashDuration = 0.20 / DashSpeed = 30 уже объявлены ниже, в блоке доджа —
	-- второй раз их писать нельзя, Lua молча оставит последний)
	OutnumberedDashSpeedMult    = 1.5,
	OutnumberedDashDurationMult = 1.2,
	-- ClientPredict.Evasive.ServerConfirmTimeout = 0.18. Сервер подтверждает рывок
	-- максимум за 180мс; всё, что дольше, — уже не подтверждение, а мусор. В диаге
	-- 870989 скрипт ждал ack 1209мс и печатал «IFRAMES not confirmed» через секунду
	-- после того, как размен закончился, — решение принималось в пустоту.
	EvasiveAckTimeout  = 0.18,
	-- ClientPredict: локальные локауты атаки после парри/блока — на них сервер
	-- ориентируется при валидации, значит и нам нельзя атаковать раньше.
	LocalParryAttackLockout = 0.15,
	LocalBlockAttackLockout = 0.15,
	LocalM2AttemptLockout   = 0.20,
	-- Shared: ParryAttackLockoutSeconds = 0.15, GuardbreakLockoutSeconds = 2,
	-- ParryBufferAfterHit = 2 — сервер ДЕРЖИТ буфер парри 2с после попадания,
	-- т.е. запоздавшее нажатие в этом окне ещё может быть зачтено.
	ParryAttackLockout = 0.15,
	GuardbreakLockout  = 2.0,
	ParryBufferAfterHit = 2.0,
	-- Shared.StepForward: Duration = 0.14, MaxSpeed = 30 — доворот атакующего
	-- вперёд во время замаха (влияет на геометрию оверлапа).
	StepForwardDur     = 0.14,
	StepForwardMaxSpd  = 30,
	DodgeMinSpacing = 0.35,
	OutnumberEscape = true,
	ExposedEscapeDodge = true,
	ExposedDodgeWindow = 0.28,
	ExposedEscapeAttackOnly = true,
	OutnumberEscapePreferBlock = true,
	DashSpeed     = 30,
	MaxHeightDiff = 12,
	DashDuration  = 0.20,
	DodgeConfirm  = 0.18,
	DodgeCenter   = true,
	HeavyDodgeInset = 0.075,
	DodgeCenterBias = 0.00,
	HeavyDodgeBias  = 0.00,
	FrameLookahead   = 0.5,
	FrameLookaheadCap= 0.045,
	FrameLookaheadPeakK  = 0.50,
	FrameLookaheadPeakDecay = 1.10,
	FrameLookaheadCapK   = 0.75,
	FrameLookaheadCapHi  = 0.11,
	FrameStepCostComp    = 0.60,

	-- ── КОМПЕНСАЦИЯ НИЗКОГО FPS ───────────────────────────────────────────────
	-- Нажатие может произойти только НА КАДРЕ. Мы ставим цель pressAtQ, а реально
	-- жмём на первом кадре после неё, т.е. фактический момент нажатия размазан по
	-- окну шириной в один кадр. У tutelzs кадр 38.9мс, пик 63.2мс — это ±31мс
	-- разброса при окне перфект-блока всего 125мс.
	-- Само по себе опережение PerfectLead=0.0625 стоит в центре окна (это верно),
	-- НО к нему прибавляется velLead (компенсация сближения). Сумма lead+velLead
	-- может стоять близко к краю окна, и тогда дрожание кадра выкидывает нажатие
	-- за край → обычный блок вместо парри. Поэтому при чанковых кадрах:
	--   1) держим сумму опережения в БЕЗОПАСНОЙ ПОЛОСЕ с запасом на полкадра,
	--   2) сильнее ориентируем lookahead на ПИК кадра, а не на среднее,
	--      чтобы систематически не опаздывать ровно на кадр.
	LowFpsComp     = true,
	LowFpsFrameMs  = 25,     -- кадр дольше этого → режим низкого FPS
	LowFpsPeakK    = 0.85,   -- вместо FrameLookaheadPeakK (0.50)
	LowFpsCapHi    = 0.13,   -- разрешаем больший lookahead
	LowFpsEdgeMs   = 6,      -- доп. запас от края окна

	-- ── ПОПРАВКА СЕРВЕРНОГО ЗАЗОРА ────────────────────────────────────────────
	-- Мы планируем нажатие как contact - lead - up - velLead. Сервер увидит блок
	-- за (lead + velLead + (up - истинный_односторонний)) до касания. В диаге
	-- Da_NoobWave эта невязка стабильно ~+30мс: при lead=77, velLead=0 сервер
	-- показывал blockGap true=108мс (77+31), при lead=61, velLead=45 → 139мс
	-- (106+33). Т.е. `up` (≈RTT 95..113мс) завышает односторонний пинг примерно
	-- на 30мс, и мы жмём слишко�� рано. net1w (57мс), наоборот, занижает.
	-- Истину не угадать из пинга, поэтому у��им её и���� ПРЯМОГО наблюдения: у нас
	-- уже есть измеренный blockGap true на каждом исходе.
	-- ── ОБУЧЕНИЕ ОТКЛЮЧЕНО ОСОЗНАННО (А НЕ ДУБЛЁМ КЛЮЧА) ──────────────────────
	-- ВНИМАНИЕ, ЗДЕСЬ БЫЛ БАГ: `GapBiasComp` объявлялся ДВА раза (true выше, false
	-- ниже) и `ResidComp` тоже (true в блоке ResidComp, false здесь). В Lua при
	-- дубле ключа в конструкторе таблицы побеждает ПОСЛЕДНИЙ, поэтому оба
	-- обучателя молча выключались, а весь блок настроек ResidComp* выше — вместе с
	-- прогревом, шринком и окном усреднения — оставался мёртвым кодом. В диаге это
	-- видно прямо: `atkResid=+0ms bias=+0ms` в КАЖДОЙ строке OUT.
	-- Теперь ключ ровно один. Значение по-прежнему false, но уже осознанно:
	--  1. predErr считается от `meas` = момента ОСТАНОВКИ анимации, а она встаёт
	--     потому, что наше парри застанило атакующего. То есть сигнал — следствие
	--     нашего же успеха. В логе V176 у ВСЕХ PERFECT predErr ≈ -30мс, у провалов
	--     +31..+111мс. Обучение на таком признаке систематически смещено.
	--  2. Разброс trueGap в логе 10..232мс при окне 125мс. Одно скользящее среднее
	--     физически не может описать двустороннюю ошибку такой ширины.
	-- Систематическую часть ошибки теперь снимает не обучение, а разовая
	-- калибровка ServerGapOffsetMs (см. выше) — она статична и проверяема.
	GapBiasComp   = false,
	ResidComp     = false,
	GapBiasMinN   = 3,
	GapBiasShrink = 0.7,     -- применяем часть измеренного среднего
	GapBiasWinN   = 40,
	GapBiasLoMs   = -60,     -- вне [lo,hi] — выброс, в среднее не берём
	GapBiasHiMs   = 120,
	-- Предел по��равки СИЛЬНО урезан (было 60). Причина: ошибка предсказания
	-- ДВУСТОРОННЯЯ (в логе V176 predErr = +88 и -42 у одного и того же врага), и
	-- одно среднее её не описывает. Проверка на числах лога показала: поправка -27мс
	-- улучшала блокнутый случай (179→135мс, всё равно блок) и при этом ЛОМАЛА
	-- рабочий — зазор уходил в -1мс, то есть блок вообще не успевал встать.
	-- Цена ошибок разная: слишком рано = обычный блок (урона нет), слишком поздно =
	-- ПРОПУЩЕННЫЙ УДАР. Поэтому поправке разрешено лишь чуть подвинуть цель.
	GapBiasCapMs  = 20,
	-- Жёсткий пол ожидаемого зазора: ближе к нулю подходить нельзя, иначе вместо
	-- блока-вместо-парри получим пропущенный удар.
	GapSafeFloorMs = 55,
	GapEdgeMs     = 6,       -- отступ от краёв окна перфект-блока

	-- ── МЕХАНИКА ХИТБОКСОВ (из дампа игры) ────────────────────────────────────
	-- CombatConfig: M1/M2.HitboxDuration = 0.15, M1.DefaultHitboxForwardOffset = 4,
	-- M2 = 3, стилевой M2HitboxDuration до 0.32. VictimHitboxServiceClient сканирует
	-- пересечение на 30Hz (0.03333) и САМ отправляет VictimHitConfirm с нашими
	-- Blocking/PerfectBlocking в момент пересечения. Никакой проверки «смотрит ли
	-- враг на нас» в игре НЕТ — есть только физический оверлап.
	HitboxDuration   = 0.15,
	HitboxScanHz     = 30,
	HitboxRetime     = true,
	HitboxContactLead = 0.02, -- хитбокс появляется чуть раньше первого скан-тика
	HitboxRetimeMinMs = 40,   -- сдвигаем оценку только при значимом расхождении
	-- Аварийное нажатие, когда хитбокс уже физически пересекается с нами, а
	-- запланированный момент нажатия ещё в будущем (поздно опознанный свинг).
	-- Разбор случая — у самого условия в резолвере.
	EmergencyPress      = true,
	EmergencyPressGrace = 0.20,  -- сколько ещё имеет смысл жать после оверлапа
	-- Потолок скорости доворота (рад/с). Именно ПОТОЛОК: фактический бюджет
	-- берётся из измеренной знаковой скорости сокращения угла до нас, поэтому
	-- 6.0 больше не превращается в +100° к конусу, как было раньше.
	-- (FaceConeDeg удалён: после перехода на геометрический тест не читался.)
	TurnRateRad      = 6.0,
	ReachSlack       = 1,
	-- Направление доджа теперь всегда "умное" (тумблер убран — выключать его смысла нет).
	-- Режим задаёт КУДА уходить:
	--   "Defensive" — отходить ОТ врага (ретрит, разрыв дистанции)
	--   "Aggressive" — сближаться и ОБКРУЧИВАТЬ врага (орбита, как Ali dodge abuse)
	DodgeMode      = "Defensive",
	DodgeAggroSteer   = true,   -- в Aggressive-режиме толкать персонажа по орбите (hum:Move)
	DodgeAggroClose   = 0.45,   -- доля "внутрь" к врагу при обкрутке (0=чистая орбита,1=прямо �� него)
	DodgeExitSteer    = true,   -- в защитных доджах толкать ПРОЧЬ по вектору доджа, чтобы выйти из живого хитбокса до конца iframe
	DodgeWallCheck = true,
	DodgeWallDist  = 8,

	DodgeHardStates = { "Ragdoll", "Downed", "Knocked", "KnockedDown", "Grabbed", "Carried",
	                    "Frozen", "Sitting", "Cutscene", "Greenzone", "RpCombatLocked",
	                    "StaffModPeaceMode" },
	NoDodgeWhileStunned = true,
	DodgeTelemetry  = true,

	LiveHeavyTimer    = true,
	LiveSpeedFloor    = 0.15,
	LiveSpeedSmooth   = 0.35,
	LiveM1Timer       = true,
	LiveM1SpeedFloor  = 0.45,
	-- Минимальное окно замера live-скорости. TimePosition обновляется раз в кадр,
	-- поэтому мерить надо минимум по 2 кадрам, иначе получаем фантомные 4-9x.
	LiveSpeedMinDt    = 0.03,
	LiveSpeedMaxFactor= 1.5,   -- потолок = track.Speed * это
	LiveSpeedMinSamples = 1,   -- пока нет валидного замера — верим аним-таймлайну

	EmergencyDualDodge = true,
	MultiDodgeCover = true,
	MultiDodgeConfirmSlack = 0.03,
	TurnRateDegPerSec  = 720,
	RearmBudget        = 0.06,
	DualDodgeMaxGap     = 0.22,

	DeepDiag           = true,
	TraceDiag          = false,
	PerfProbe          = true,   -- лёгкий аудит: раз/сек лог [perf] threats/step-ms/willHitMe-per-s/GPBB-per-s/fps

	BoxingCounter     = false,
	BoxingCounterReach= 5.5,
	BoxingCounterGap  = 0.30,

	-- ══ WING CHUN COUNTER ═════════════════════════════════════════════════════
	-- Механика ОБРАТНАЯ Boxing/Ali: M2GrantsIFrames отсутствует → неуязвимости нет.
	-- M2RequiresCounterHit=true → враг должен ПОПАСТЬ внутри окна 0.5с (тогда 2.2с
	-- стан ему, ×1.25 урона). Промах окна = полный урон + 1с стан + 10с CD,
	-- поэтому гейты жёстче и по умолчанию всё выключено.
	WingChunCounter     = false,
	WingChunCounterReach= 6.5,
	WCStartup           = 7 / 60, -- WingChunVfx StartupFrame=7 @ Fps=60 (ФИКСИРОВАННЫЙ)
	WCCalibrate         = false,  -- АВТО-КАЛИБРОВКА УБРАНА: startupEma дрейфил и промахивался.
	                              -- Тайминг теперь = фикс. WCStartup + пинг-компенсация (uplink).
	WCAimFrac           = 0.35,   -- куда внутри окна 0.5с целим контакт
	WCEarlyMargin       = 0.045,
	WCLateMargin        = 0.10,
	WCRequireLiveTrack  = true,   -- предсказанный контакт слишком дорог в ��шибке
	WCSoloOnly          = true,   -- iframes нет → второй атакующий пробьёт
	WCSkipGrabs         = true,   -- грэб может не конвертнуться в контру

	AliCounter        = false,
	AliCounterReach   = 7.5,
	AliM2Variant      = "Left",
	AliProcTTLFrac    = 0.25,
	AliProcTTLMax     = 1.5,
	AliVariantSteerDur= 0.15,
	AliEvasiveCounter = false,
	AliDodgeAbuse     = false,
	CounterPreemptsDodge = true,
	-- Хитбокс игры проверяется КАЖДЫЙ кадр всё время, пока часть жива в workspace.Hitboxes
	-- (VictimHitboxServiceClient, Heartbeat), а спасает только IFRAMES. Если задоджить
	-- слишком рано — iframe кончится, а часть-хитбокс ещё жива и пересекает нас → ловим
	-- удар после успешного доджа. Поэтому центрируем iframe ПО��ЖЕ (меньше frac = позже фаер),
	-- чтобы окно неуязвимости покрывало "хвост" жизни хитбокса за моментом контакта.
	DodgeCenterFrac   = 0.38,

	SkillAddon        = true,
	SA_WrestlingGrab  = true,
	SA_DirtyGrab      = true,
	SA_HakariRead     = true,
	SA_HakariWiden    = 0.05,
	SA_BlatantDodge   = false,
	SA_BlatantWindow  = 0.32,

	AutoPlay          = false,
	AP_ForceNativeM1  = true,   -- true = бить через родную tryM1() игры (переживает обновления); false = хрупкий fast-path на debug-индексах
	AP_PunishOnParry  = true,
	AP_Interrupt      = false,
	AP_InterruptMargin= 0.055,
	AP_InterruptNetK  = 0.50,
	AP_BaseReach      = 5.5,
	AP_RefHeight      = 5.5,
	AP_InterruptM2       = true,
	AP_InterruptPreferM2 = true,
	AP_M2BaseReach       = 6.5,
	AP_M2Gap             = 0.30,
	AP_M2IFrameMargin    = 0.035,
	AP_AnimGuard    = true,
	AP_AnimFallback = 0.45,
	AP_MaxPerSec      = 8,
	AP_MinSendGap     = 0.08,
	AP_PunishFastGap  = 0.08,
	AP_M2Stun         = 1.0,
	AP_M1Stun         = 0.5,
	AP_PollGap        = 0,
	AP_FaceHold       = 0.35,
	AP_ComboMode      = "Follow",
	AP_FixedHit       = 1,

	RequireEquip      = true,

	RestrictZone      = true,
	RestrictLongOnly  = true,
	RestrictMinWindup = 0.30,
	RestrictPad       = 2.0,
	RestrictSoft      = true,
	RestrictShowZone  = true,

	SelfBusyDur     = 0.45,

	DesyncAttack   = false,
	DesyncMode     = "delay",
	DesyncDelayMs  = 140,
	DesyncDecoyId  = 507766388,
	DesyncApplyM1  = true,
	DesyncApplyM2  = true,
	AntiDecoy      = true,
	AntiDecoyGap   = 0.12,
	AntiDecoyMaxBurst = 3,
	DecoyRefireSec  = 0.60,
	DecoySpeedMin   = 0.30,
	DecoySpeedMax   = 1.25,
	DecoySpeedTol   = 0.50,
	DecoyHardDrop   = true,
	DecoySweepSec   = 5,
	DecoySeenMax    = 512,
	ServerProofGate = true,
	ProofGraceSec   = 0.06,
	TimeSpoof    = false,
	TimeShiftMs  = 40,
	DesyncClientVisible = false,
	DesyncSendHz      = 0,
	InvisibleOn    = false,
	InvisibleHeight= 0,
	InvisibleAnim  = true,

	BoxingFaceLockDur = 0.55,
	AliFaceLockDur = 0.75,

	MultiThreatGuard  = true,
	MultiThreatMinN   = 2,
	-- Игра: CombatConfig.Block.CooldownSeconds = 0.5, PerfectBlockWindow = 0.125.
	-- Т.е. после снятия блока повторное парри доступно только через 0.5с — поэтому
	-- два удара с разрывом меньше ~0.62с парировать ОБА физически нельзя, и
	-- правильный план для такой пары: парри первый + додж вт��рой.
	BlockCooldown     = 0.50,
	-- Не доверять серверному атрибуту BlockCooldown как единственному признаку:
	-- он приезжает с задержкой и на быстрых сериях (удары через 430-480мс) даёт
	-- ложное «можно». Разбор — в canBlockNow.
	BlockCooldownPredict = true,
	BlockCooldownSafety  = 0.03,
	SequentialMargin  = 0.05,  -- запас к расчёту разрыва для двух парри подряд
	-- План живёт между кадрами: к моменту доджа второй угрозы первая уже отработала
	-- и кластер распался, поэтому пересобрать план было бы невозможно.
	PlanLatchSec      = 1.2,
	CooldownDodge     = true,  -- блок в кулдауне → уходим доджем, а не едим удар
	-- SequentialSpread больше НЕ используется: это был магический порог 0.78с,
	-- который вместе с `not clusterHeavy` делал последовательные планы почти
	-- недостижимыми. Теперь разрыв считается по реальной механике (см. reParryNeed).
	SequentialSpread  = 0.78,
	MultiFaceAngleMax = 70,
	MultiFaceJitter   = 0.30,
	MultiFaceOnlyFront= true,
	DesyncSafeDecoy   = true,

	AntiCheatBypass = true,
	HideHooks       = true,
	MuteAC          = true,
	BlockKick       = true,
	BlockACReports  = true,
	ACScriptName    = "so you're challenging me",
	NeutralizeAC    = true,

	MultiFaceHard     = true,
	-- Доворачиваться только на удары, подтверждённые живой геометрией. Латч и
	-- явно чужие свинги к развороту не приводят: в замесе крутиться на чужую
	-- атаку = не успеть встретить свою. Разбор в aimedAtMe().
	FaceOnlyRealThreats = true,
	-- Нажатие достаётся тяжёлому удару (SKILL > M2 > M1), когда контакты ближе
	-- кулдауна блока и оплатить можно только одно нажатие. Разбор в heavyRank().
	HeavyFirst        = true,

	DodgeHorizon      = 0.34,
	MinBlockSeparation= 0.17,
	DodgeArmWindow    = 0.05,

	LegitAnims    = true,

	AutoFace      = true,
	FaceLerp      = 0.80,
	FaceLeadWindow= 0.30,
	FaceGoodDot   = 0.55,
	FaceLead      = 0.07,
	FaceLeadMax   = 4,
	FacePingLead  = 1.0,
	FaceLeadCap   = 0.28,
	FaceLeadMaxStuds = 16,
	FaceLatMaxStuds = 18,
	FaceRadMaxStuds = 5,

	OmniBlock      = true,

	ShowVisuals   = true,
	VizRing       = true,
	VizRingStyle  = "Flat",
	VizRingSeg    = 30,
	VizRingMirror = true,
	VizRingTilt   = 0.7,
	RotationMethod = "LookAt",
	AimLockLerp    = 0.35,
	VizHitbox     = true,
	VizRestrict   = true,
	VizRingSpeed  = 1.0,
	VizRingScale  = 1.0,
	VizRange      = 100,
	VizMaxFPS     = 60,
	VizAutoDegrade   = true,
	VizFrameShare    = 1.5,
	VizSkipNearPress = 0.20,
	VizSkipMaxFrames = 2,
	Debug         = true,

	Key_Toggle    = Enum.KeyCode.K,
	Key_Mode      = Enum.KeyCode.N,
	Key_Desync    = Enum.KeyCode.J,
	Key_Boxing    = Enum.KeyCode.V,
	Key_Double    = Enum.KeyCode.H,
	Key_Face      = Enum.KeyCode.G,
	Key_LogDump   = Enum.KeyCode.L,
	Key_Save      = Enum.KeyCode.P,
	Key_ACScan    = Enum.KeyCode.O,
	Key_DesyncSave = Enum.KeyCode.Semicolon,
	Key_DesyncTest = Enum.KeyCode.LeftBracket,
	Key_DesyncMode = Enum.KeyCode.RightBracket,
	AutoScanAC    = false,
	Key_Panel     = Enum.KeyCode.RightShift,
}

-- ══════════════════════════════════════════════════════════════════════════════
-- _D.LEGACY_ATTACKS — РЕГЕНЕРИРОВАНО ПОД ТЕКУЩИЙ АПДЕЙТ
-- Игра перезалила ВСЕ боевые анимации: ни один старый assetId больше не
-- существует в Animations.Combat. Старая таблица = 100% мёртвых ID, поэтому
-- fallback молча не работал, и любой стиль без живо��о реестра шёл в дефолт 0.32.
-- d = M1HitboxDelay + M1HitboxDelayOffsets[combo] из живого CombatConfig.
-- ВАЖНО: reaction-анимации (M2EHit / M2Success / 1st..4thEHit / BlockHit /
-- GuardbreakEHit) СЮДА НЕ ВНОСИМ — это анимации ЖЕРТВЫ, не атаки.
-- ═══════════════════════════════��════════════════════════════════��═════════════
_D.LEGACY_ATTACKS = {
	-- BaseCombat: дефолтный набор (стиль не выбран) → M1 0.32 / M2 0.30 из Styles.default
	[113961476814500]={t="M1",d=0.32,s="Base",c=1}, [82165070516177]={t="M1",d=0.32,s="Base",c=2},
	[138197524717835]={t="M1",d=0.32,s="Base",c=3}, [81174027972159]={t="M1",d=0.32,s="Base",c=4},
	[113480104450803]={t="M2",d=0.30,s="Base"},
	[102632933427597]={t="M1",d=0.37,s="Ali",c=2}, [119814294807778]={t="M1",d=0.42,s="Ali",c=3},
	[137247073345979]={t="M1",d=0.28,s="Ali",c=1}, [74315946602284]={t="M1",d=0.22,s="Ali",c=4},
	[128315752013166]={t="M2",d=0.53,s="Ali",v="Left"}, [70642098724811]={t="M2",d=0.67,s="Ali",v="Right"},
	[106980660082799]={t="M1",d=0.34,s="Basic",c=4}, [83491849294956]={t="M1",d=0.34,s="Basic",c=1},
	[83730275893449]={t="M1",d=0.34,s="Basic",c=3}, [89420531853362]={t="M1",d=0.34,s="Basic",c=2},
	[78888626472394]={t="M2",d=0.525,s="Basic"},
	[100408082509740]={t="M1",d=0.34,s="Boxing",c=2}, [137980914350618]={t="M1",d=0.34,s="Boxing",c=1},
	[78695517680318]={t="M1",d=0.38,s="Boxing",c=4}, [94803478352691]={t="M1",d=0.34,s="Boxing",c=3},
	[132022052139564]={t="M2",d=0.43,s="Boxing"},
	[106965238908791]={t="M1",d=0.28,s="Capoeira",c=4}, [117877243065533]={t="M1",d=0.35,s="Capoeira",c=3},
	[125976167173936]={t="M1",d=0.35,s="Capoeira",c=1}, [134945199381140]={t="M1",d=0.43,s="Capoeira",c=2},
	[131071815103338]={t="M2",d=0.45,s="Capoeira"},
	[103026596903060]={t="M1",d=0.37,s="Hakari",c=2}, [103100834246116]={t="M1",d=0.38,s="Hakari",c=4},
	[86626533783115]={t="M1",d=0.28,s="Hakari",c=3}, [92865171012109]={t="M1",d=0.35,s="Hakari",c=1},
	[103359839046574]={t="M2",d=0.35,s="Hakari"},
	-- Momentum M2 (анимация зовётся "MomentumM2", HakariMomentumM2HitboxDelay=0.48)
	[102961997518914]={t="M2",d=0.48,s="Hakari",mom=true},
	[113719263885794]={t="M1",d=0.32,s="HakariOther",c=2}, [126612786608030]={t="M1",d=0.32,s="HakariOther",c=1},
	[136305578634960]={t="M1",d=0.32,s="HakariOther",c=3}, [89039586375625]={t="M1",d=0.32,s="HakariOther",c=4},
	[101619248052969]={t="M2",d=0.30,s="HakariOther"},
	[82855179231529]={t="M2",d=0.48,s="HakariOther",mom=true},
	[100981571094705]={t="M1",d=0.315,s="Karate",c=2}, [130865087635587]={t="M1",d=0.39,s="Karate",c=3},
	[137837926745158]={t="M1",d=0.2775,s="Karate",c=1}, [86495068205420]={t="M1",d=0.465,s="Karate",c=4},
	[120393553812903]={t="M2",d=0.4875,s="Karate"},
	[103732110215321]={t="M1",d=0.32,s="Kure",c=2}, [103964436023727]={t="M1",d=0.32,s="Kure",c=3},
	[71676634048602]={t="M1",d=0.32,s="Kure",c=4}, [82904229252991]={t="M1",d=0.32,s="Kure",c=1},
	[102407060635393]={t="M2",d=0.30,s="Kure"},
	[104515319350296]={t="M1",d=0.30,s="MuayThai",c=3}, [139911027872047]={t="M1",d=0.30,s="MuayThai",c=2},
	[74960202100098]={t="M1",d=0.30,s="MuayThai",c=4}, [96726284968458]={t="M1",d=0.30,s="MuayThai",c=1},
	[137034747040618]={t="M2",d=0.60,s="MuayThai"},
	[104867156139010]={t="M1",d=0.45,s="Slugger",c=2}, [112759168172605]={t="M1",d=0.45,s="Slugger",c=3},
	[114647502301740]={t="M1",d=0.37,s="Slugger",c=4}, [134829666925953]={t="M1",d=0.50,s="Slugger",c=1},
	[118943955490014]={t="M2",d=0.82,s="Slugger"},
	-- STRIKER — ПЕРЕСЧИТАНО ПО ЖИВОМУ КОНФИГУ ТЕКУЩЕГО АПДЕЙТА.
	-- Старый комментарий («своего блока НЕТ → дефолт 0.32/0.30») БОЛЬШЕ НЕ ВЕРЕН:
	-- игра завела Styles.striker, и это меняет всё. ��ивые значения:
	--     M1HitboxDelay = 0.35,  M2HitboxDelay = 0.45,
	--     M1HitboxDelayOffsets = { 0, 0, -0.12, -0.23 }
	-- Отсюда d = base + offset[combo] (windup прибавляется отдельно, см. 2084):
	--     c1 0.35   c2 0.35   c3 0.23   c4 0.12
	-- Насколько мимо били прежние значения: c3 0.32 вместо 0.23 → +90мс,
	-- c4 0.32 вместо 0.12 → +200мс (третий и четвёртый удары серии не парировались
	-- вообще), M2 угадан верно (0.449 ≈ 0.45 — замер по серверу совпал с конфигом).
	-- Побочно: раз стиль теперь В КОНФИГЕ, cfgKnowsStyle("Striker") == true, и
	-- ранний возврат по LEGACY_ATTACKS (строка ~2078) для него больше не срабатывает —
	-- тайминг берётся из GetScaledStyleM1HitboxDelay. Таблица ниже осталась как
	-- фолбэк на случай, когда модуль конфига не прочитался.
	[118070233153900]={t="M1",d=0.23,s="Striker",c=3}, [127909081017342]={t="M1",d=0.35,s="Striker",c=1},
	[77710266587706]={t="M1",d=0.12,s="Striker",c=4}, [79563637573277]={t="M1",d=0.35,s="Striker",c=2},
	[114364673509520]={t="M2",d=0.45,s="Striker"},
	-- ID из свежего лога (игра перезалила анимации Striker):
	[116642061934550]={t="M1",d=0.35, s="Striker",c=1}, [115234849770695]={t="M1",d=0.35,s="Striker",c=2},
	[73777821288331] ={t="M1",d=0.12, s="Striker",c=4},
	[99309341097380] ={t="M2",d=0.45, s="Striker"},
	-- WING CHUN — ПЕРЕСЧИТАНО ПО ЖИВОМУ КОНФИГУ.
	-- Игра: M1HitboxDelay = 0.3 (а НЕ 0.4, как стояло здесь), offsets = {0,0,0,0.4},
	-- M2HitboxDelay = 0.525. Итог: c1..c3 = 0.30, c4 = 0.70.
	-- Прежние 0.40/0.36/0.36 били на 100 и 60мс ПОЗЖЕ реального контакта.
	-- M2 = НЕ УДАР, а counter-стойка → counter=true (парировать нечего).
	[117898175201201]={t="M1",d=0.30,s="WingChun",c=2}, [121315597867666]={t="M1",d=0.30,s="WingChun",c=3},
	[71178147313608]={t="M1",d=0.30,s="WingChun",c=1}, [81810173569294]={t="M1",d=0.70,s="WingChun",c=4},
	[82196924299426]={t="M2",d=0.525,s="WingChun",counter=true},
	[107464726433388]={t="M1",d=0.36,s="Wrestling",c=3}, [119685134442395]={t="M1",d=0.37,s="Wrestling",c=2},
	[82903450925391]={t="M1",d=0.36,s="Wrestling",c=1}, [91485623489753]={t="M1",d=0.35,s="Wrestling",c=4},
	[73748315742870]={t="M2",d=0.525,s="Wrestling"},
}

-- ════════════════════════════════════════════════���═════════════════════════════
-- WING CHUN — разбор механики (CombatConfig.Styles.wingchun)
-- ──────────────────────────────────────────────────────────────────────────────
-- ПАССИВКА (пассивных "iframe" у стиля Н��Т, слухи неверны):
--   DamageMultiplier            = 0.95   (-5% урона)
--   PostureResistanceMultiplier = 0.9    (-10% урона по стойке = дольше держит гард)
--   BlockChipPercent            = 0.1    (минимальный chip сквозь блок)
--   M1RecoveryLockout           = 0.58   (долгое восстановление после M1-серии)
--   perk SwiftHands             = +12.5% скорости M1 (CombatPerksConfig)
--
-- M2 = "counter stance", а ��Е удар: M2RequiresCounterHit=true, окно 0.5с,
-- промах = 1с стан себе, попадание = 2.2с стан жертве и ×1.25 урона, CD 10с.
-- Для автопарри: анимация "M2" у WingChun — НЕ угроза (парировать нечего, а
-- нажатие жжёт block-cooldown), и во время окна 0.5с нам НЕЛЬЗЯ атаковать.
-- "M2Success"/"M2EHit" — reaction-анимации, в _D.AttackIds не попадают.
-- ══════════════════════════════════════════════════════════════════════════════
_D.WINGCHUN = {
	-- Сверено с живым конфигом: M2CounterWindowDuration = 0.58 (было 0.5 — окно
	-- шире на 80мс, т.е. запрет на нашу атаку снимался слишком рано).
	CounterWindow   = 0.58,
	-- M2CounterParryDisableDuration = 1.35: после counter'а Wing Chun ПАРИРОВАНИЕ
	-- ОТКЛЮЧЕНО на 1.35с. Пока держится — жать блок бессмысленно, нужен додж.
	CounterParryDisable = 1.35,
	CounterWhiffStun= 1.0,
	CounterHoldSecs = 1.033,
	CounterFps      = 60,
	CounterFrames   = { 25, 41, 52, 62, 82 },
	VictimHitStun   = 2.2,
	-- WingChunVfx: StartupFrame=7 @ Fps=60 → стойка «встаёт» через 7/60 = 116.7мс.
	-- Это единственная видимая в дампе константа стартапа (сама counter-логика
	-- живёт на сервере), поэтому используем как старто��ую оценку и к��либру��м.
	StartupFrame    = 7,
	PostHitLockout  = 0.35,
	Cooldown        = 10,
}
_D.WINGCHUN.StartupSecs = _D.WINGCHUN.StartupFrame / _D.WINGCHUN.CounterFps

-- Наша собственная counter-транзакция Wing Chun. От��ельно от State.counterTxn,
-- потому что у той семантика «ждём iframes», а здесь iframes НЕ БУДЕТ.
_D.WCTxn = {
	pending = false, sentAt = 0, openAt = 0, closeAt = 0,
	startupEma = nil, samples = 0, hits = 0, whiffs = 0,
	threat = nil, threatId = nil,
}

-- Кто сейчас держит counter-стойку Wing Chun (weak keys по модели персонажа).
local WingChunCounter = setmetatable({}, { __mode = "k" })

local function wingChunCounterActive(model)
	if not model then return false end
	local untilClock = WingChunCounter[model]
	return untilClock ~= nil and os.clock() < untilClock
end

-- Стойка = анимация ровно "M2" у стиля WingChun (M2Success / M2EHit — реакции).
local function isWingChunCounterStance(info, id)
	if not info or info.t ~= "M2" then return false end
	-- styleKey() объявлен ниже по файлу, поэтому нормализуем на месте
	local sl = string.lower(tostring(info.s or "")):gsub("[%s_%-]", "")
	if sl ~= "wingchun" then return false end
	local le = id and _D.LEGACY_ATTACKS[id]
	if le and le.counter then return true end
	local nm = (info.name or ""):lower()
	return nm == "m2" or nm == ""
end

_D.LEGACY_M2_VARIANT = { M2 = "Left", M2Right = "Right", M2Left = "Left" }

-- M1HitboxDelayOffsets, сверено с CombatConfig текущей версии
_D.LEGACY_M1_OFFSETS = {
	ali      = {0.06, 0.15, 0.2, 0},
	basic    = {0.02, 0.02, 0.02, 0.02},
	boxing   = {0.02, 0.02, 0.02, 0.06},
	hakari   = {0.14, 0.16, 0.07, 0.17},
	hakario  = {0.14, 0.16, 0.07, 0.17},
	karate   = {0.0375, 0.075, 0.15, 0.225},
	capoeira = {0.02, 0.1, 0.02, -0.05},
	slugger  = {0.3, 0.25, 0.25, 0.17},
	wrestling= {0.04, 0.05, 0.04, 0.03},
	-- Wing Chun — сверено с живым конфигом: {0, 0, 0, 0.4}. Раньше здесь стояло
	-- {0,-0.04,-0.04,0.3}: 2-й и 3-й удары уезжали на 40мс раньше, 4-й на 100мс.
	wingchun = {0, 0, 0, 0.4},
	-- Striker — стиль ПОЯВИЛСЯ в конфиге в этом апдейте, оффсетов раньше не было
	-- вообще. Отрицательные значения означают, что 3-й и 4-�� удары серии БЫСТРЕЕ
	-- базовых 0.35 (на 120 и 230мс) — самые пропускаемые удары стиля.
	striker  = {0, 0, -0.12, -0.23},
}
-- M1HitboxDelay по стилям — сверено с Styles.* живого CombatConfig.
-- Правки этого апдейта: wingchun 0.40 → 0.30 (игра ОПУСТИЛА задержку, мы стреляли
-- на 100мс позже), striker 0.32 → 0.35 (у стиля появился свой блок в конфиге).
_D.LEGACY_M1_BASE = { ali=0.22, karate=0.24, muaythai=0.30, slugger=0.20, capoeira=0.33,
                         hakari=0.21, hakario=0.21, wingchun=0.30, striker=0.35,
                         kure=0.32, wrestling=0.32, basic=0.32, boxing=0.32 }
-- M2HitboxDelay: striker 0.30 → 0.45 (свой блок в конфиге, ошибка была -150мс).
_D.LEGACY_M2_BASE = { ali=0.53, boxing=0.43, capoeira=0.45, hakari=0.35, hakario=0.35, karate=0.4875,
                         muaythai=0.60, slugger=0.82, wrestling=0.525, basic=0.525,
                         taekwondo=0.46, wild=0.525, bulky=0.43, dirty=0.30, wingchun=0.525,
                         skygaolang=0.35, variant=0.35, kure=0.30, striker=0.45 }
_D.LEGACY_M2_MOM_BASE = { hakari=0.48, hakario=0.48 }
_D.WINDUP_EXTRA = 0.012
_D.COMBO_RESET  = 1.55

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Stats             = game:GetService("Stats")

local LocalPlayer  = Players.LocalPlayer
local ServerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Server")

local State = {
	blocking     = false,
	guardUp      = false,
	holdUntil    = 0,
	status       = "ARMED",
	lastThreat   = nil,
	parryCount   = 0,
	dodgeCount   = 0,
	grantEscapes = 0,
	selfBusyUntil= 0,
	attackBusyUntil = 0,
	kicksBlocked   = 0,
	reportsBlocked = 0,
	acMuted        = 0,
	acScript       = nil,
	desyncFires    = 0,
	fireCount    = 0,
	lastDodge    = -99,
	dodgeRejects = 0,
	swingAnimUntil = 0,
	threatNeutralized = 0,
	dodgeGateSaid = nil,
	lastDodgeInfo   = nil,
	aliM2CD = { char=nil, observed=false, active=false, known=false, started=0, duration=7 },
	dodgeTxn = { pending=false, confirmed=false, fire=0, lo=0, hi=0, untilAt=0, reason=nil },
	counterTxn = { seq=0, pending=false, confirmed=false, sent=0, ackDeadline=0,
		expectedIFramesAt=0, threat=nil, threatId=nil, source=nil, result=nil },
	lastDodgeRefuse = nil,
	lastAct      = -99,
	lastDeact    = -99,
	flashUntil   = 0,
	lastResult   = "—",
	lastErrMs    = 0,
	lastGapMs    = 0,
	tally        = { PERFECT=0, EARLY=0, LATE=0, GUARDBREAK=0 },
	vizTarget    = nil,
	faceGoalHRP   = nil,
	faceGoalHard  = false,
	faceGoalUntil = 0,
	faceHum       = nil,
	faceGoalPos   = nil,
	noParryActive = false,
	noParryNow    = false,
}

local Threats = {}

	_D.FaceByResult = {}
	_D.ResidByKS    = {}
	-- Per-attacker EMA скрытого пол-пинга (мс). Замыкает прогноз контакта: то, что
	-- resAvg только ПОКАЗЫВАЛ в логах, теперь применяется к contactAbs. Ключ = имя
	-- атакующ��го (совпадает с ключом Pending[attacker] и th.name).
	_D.ResidByAtk   = {}
	-- Скользящее среднее (sum/n), приор для новых атакующих. Не EMA: см. ResidComp*.
	_D.ResidGlobal  = { ms = nil, sum = 0, n = 0 }
	-- Невязка серверного зазора (см. gapBiasEst): учится из blockGap true.
	_D.GapBias      = { ms = nil, sum = 0, n = 0 }
local ComboState = {}
local Pending = {}

local logTrim = function(t, cap)
	local n = #t
	if n <= cap then return end
	local drop = cap // 2
	if drop < 1 then drop = 1 end
	table.move(t, drop + 1, n, 1)
	for i = n - drop + 1, n do t[i] = nil end
end

_D.DiagLog, _D.DIAG_MAX = {}, 1200
local diagPush = function(fmt, ...)
	if not Config.DeepDiag then return end
	local line = select("#", ...) > 0 and string.format(fmt, ...) or fmt
	_D.DiagLog[#_D.DiagLog+1] = line
	logTrim(_D.DiagLog, _D.DIAG_MAX)
end
-- per-frame hot-path trace: gated separately so idle-frame formatting never runs
-- unless deep frame debugging is explicitly enabled (TraceDiag).
local diagTrace = function(fmt, ...)
	if not Config.TraceDiag then return end
	local line = select("#", ...) > 0 and string.format(fmt, ...) or fmt
	_D.DiagLog[#_D.DiagLog+1] = line
	logTrim(_D.DiagLog, _D.DIAG_MAX)
end

_D.DesyncLog, _D.DESYNC_MAX = {}, 800
local function desyncPush(line)
	local stamped = string.format("t=%.2f  %s", os.clock(), line)
	_D.DesyncLog[#_D.DesyncLog+1] = stamped
	logTrim(_D.DesyncLog, _D.DESYNC_MAX)
end
_D.StatusLog, _D.STATUS_MAX = {}, 200
local function statusPush(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	local line = table.concat(parts, " ")
	_D.StatusLog[#_D.StatusLog + 1] = line
	logTrim(_D.StatusLog, _D.STATUS_MAX)
end

local function dbg(...)
	if Config.Debug then statusPush(...) end
end

local function aclog(...)
	statusPush(...)
end

_C.lastGoodPing = 0.08
-- ВНИМАНИЕ: первое значение — RTT (туда-обратно), НЕ одностороннее время.
-- Раньше переменная звалась oneWay и печаталась в логе как "net1w", хотя внутри
-- лежит GetNetworkPing(), то есть тот же RTT. Из-за этой метки в логе выходило
-- "net1w=26ms rawRTT=26ms" — и по ним легко сделать ложный вывод, что
-- односторонняя задержка равна полному RTT. Одностороннее ≈ RTT/2.
local function pingDiagSnapshot()
	local gnpRtt, statsRtt
	pcall(function()
		local v = LocalPlayer:GetNetworkPing()
		if type(v) == "number" and v > 0 then gnpRtt = v end
	end)
	pcall(function()
		local v = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		if type(v) == "number" and v > 1 then statsRtt = v / 1000 end
	end)
	return gnpRtt, statsRtt
end
local getPingRaw = function()
	local aRtt
	local okA, v = pcall(function() return LocalPlayer:GetNetworkPing() end)
	if okA and type(v) == "number" and v == v and v > 0 then aRtt = v end

	local bRtt
	local okB, ms = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if okB and type(ms) == "number" and ms == ms and ms > 1 then bRtt = ms / 1000 end

	local best
	if bRtt and aRtt then
		local ratio = Config.PingSourceMaxRatio or 2.5
		best = (aRtt > bRtt * ratio) and bRtt or math.max(aRtt, bRtt)
	else
		best = bRtt or aRtt
	end

	if best and best > 0 then
		_C.lastGoodPing = math.clamp(best, 0.005, 1.5)
	end
	return _C.lastGoodPing
end

local V93 = {
	frameDt   = 1/60,
	lookahead = 0,
	frameDtPeak = 1/60,
	lowFps    = false,
	stepCost  = 0,
	nearPress = math.huge,
	nearPressStamp = 0,
	vizLast   = 0,
	pingBuf   = {},
	pingBufN  = 0,
	pingBufI  = 0,
	pingSampleClock = -1,
	pingMedTmp = {},
	hbFolder = nil,
	sizes = {},
	hbParams = nil,
	hbChar = nil,
	hbFrame = -1,
	byOwner = {},
	hbFirstSeen = setmetatable({}, { __mode = "k" }),
	hbClaimBySid = {},
	hbLiveSid = {},
	pingCacheClock = -1,
	pingCacheVal   = 0.08,
	imminentBuf = {},
	clusterBuf  = {},
	faceBuf     = {},
	seenAttackers = {},
	threatSeen = {},
	interruptSeen = {},
	boxingM2Contacts = { 0.6000000, 1.0500000 },
	ownM1Info = { t = "M1", s = "Basic" },
	ownM2Info = { t = "M2", s = "Basic", mom = false, variant = nil },
	sortByContact = function(a, b) return a.contactAbs < b.contactAbs end,
	dodgeParams = nil,
	dodgeChar = nil,
}

local function getPing()
	local nowc = os.clock()
	if (nowc - V93.pingSampleClock) < (Config.PingSampleGap or 0.03) then
		return V93.pingCacheVal
	end
	V93.pingSampleClock = nowc

	local raw = getPingRaw()
	local win = math.max(3, Config.PingWindow or 24)
	V93.pingBufI = (V93.pingBufI % win) + 1
	V93.pingBuf[V93.pingBufI] = raw
	if V93.pingBufN < win then V93.pingBufN = V93.pingBufN + 1 end

	local n = V93.pingBufN
	local tmp = V93.pingMedTmp
	for i = 1, n do tmp[i] = V93.pingBuf[i] end
	for i = n + 1, #tmp do tmp[i] = nil end
	table.sort(tmp)
	local med
	if n % 2 == 1 then med = tmp[(n + 1) // 2]
	else med = (tmp[n // 2] + tmp[n // 2 + 1]) * 0.5 end

	V93.pingCacheVal = math.min(med, Config.PingCap)
	return V93.pingCacheVal
end

local uplink = function()
	local ping = getPing()
	local up = math.clamp(ping * Config.UplinkFactor + Config.UplinkMargin, Config.UplinkMin, Config.UplinkMax)
	local thr = Config.LowPingThresh or 0
	if thr > 0 and ping < thr then
		up = up + (Config.LowPingFloor or 0) * (1 - ping / thr)
	end
	return up
end

local function localChar() return LocalPlayer.Character end

_C.index = function(o, k) return o[k] end
V93.humMove = function(hum, dir) return hum:Move(dir, false) end
local safeGet = function(o, k, default)
	if o == nil then return default end
	local ok, v = pcall(_C.index, o, k)
	if ok and v ~= nil then return v end
	return default
end

_C.FrameId = 0
_C.hrpCache, _C.hrpFrame = nil, -1
local localHRP = function()
	if _C.hrpFrame == _C.FrameId and _C.hrpCache and _C.hrpCache.Parent then return _C.hrpCache end
	local c = localChar()
	_C.hrpCache = (c and c:FindFirstChild("HumanoidRootPart")) or nil
	_C.hrpFrame = _C.FrameId
	return _C.hrpCache
end

_D.HARD_BLOCKERS = { "BlockCooldown", "Ragdoll", "Downed", "Greenzone",
                        "RpCombatLocked", "StaffModPeaceMode" }
local function canBlockNow()
	local c = localChar()
	if not c then return false, "no-char" end
	if Config.RequireEquip ~= false and c:GetAttribute("Equip") ~= true then
		return false, "Unequip"
	end
	-- ── ЛОКАЛЬНОЕ ПРЕДСКАЗАНИЕ КУЛДАУНА (ГЛАВНАЯ ПРИЧИНА ОСТАВШИХСЯ ПРОМАХОВ) ──
	-- Атрибут "BlockCooldown" ниже — СЕРВЕРНЫЙ, он доезжает до нас с задержкой
	-- ~полпинга. Поэтому проверка по нему работает только когда удары редкие.
	-- Что было в логе (Kure, комбо c3→c4):
	--     press c3 @ t=2588.433
	--     press c4 @ t=2588.913   ← всего 480мс спустя, а CooldownSeconds = 0.5
	--   → атрибут ещё не пришёл, canBlockNow сказал «можно», блок ушёл на сервер,
	--     сервер его ОТКЛОНИЛ, и результат приехал M1Hit. В диаге эта строка
	--     выглядит идеально: pressDt=218мс, face=1.00, guard в пределах — и HIT.
	-- Именно поэтому промахи «неотличимы по таймингу»: тайминг там ни при чём,
	-- блока прост�� не существовало. Такие удары надо не «парировать точнее», а
	-- отдавать доджу — ветка CD-DODGE это уже умеет, ей не хватало честного
	-- признака. Считаем кулдаун от МОМЕНТА СНЯТИЯ нашего блока по локальным часам.
	if Config.BlockCooldownPredict ~= false then
		local rel = State.lastBlockRelease or State.lastPress
		if rel then
			-- Только Config: локал GameData объявлен НИЖЕ этой функции (строка ~1866),
			-- поэтому здесь имя разрешилось бы в глобал nil — ветка была бы мёртвой.
			local cd = Config.BlockCooldown or 0.5
			-- Запас на рассинхрон часов: лучше уйти доджем, чем послать блок,
			-- который сервер выбросит (цена оши��ки несимметрична).
			local ready = rel + cd + (Config.BlockCooldownSafety or 0.03)
			if os.clock() < ready then return false, "BlockCooldown" end
		end
	end
	for _, attr in ipairs(_D.HARD_BLOCKERS) do
		if c:GetAttribute(attr) == true then return false, attr end
	end
	local stunned = c:GetAttribute("Stunned") == true
	local cantAny = c:GetAttribute("CantAnything") == true
	if stunned or cantAny then
		if c:GetAttribute("ParryWindowDisabled") ~= true
		   and c:GetAttribute("PerfectBlocking") ~= true
		   and (c:GetAttribute("Parried") == true
			or (Config.ComboEscape and c:GetAttribute("ParryBuffered") == true)) then
			return true, nil
		end
		return false, stunned and "Stunned" or "CantAnything"
	end
	return true, nil
end

local function blockStamina()
	local c = localChar()
	if not c then return nil end
	for _, name in ipairs(Config.StaminaAttrs) do
		local v = c:GetAttribute(name)
		if type(v) == "number" and v >= 0 and v <= 1000 then return v end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	for _, host in ipairs({ c, hum }) do
		if host then
			for _, name in ipairs(Config.StaminaAttrs) do
				local obj = host:FindFirstChild(name)
				if obj and (obj:IsA("NumberValue") or obj:IsA("IntValue")) then return obj.Value end
			end
		end
	end
	return nil
end

local function ownerOf(animator)
	local p = animator.Parent
	if p and (p:IsA("Humanoid") or p:IsA("AnimationController")) then return p.Parent end
	return p
end

local isEnemyModel = function(model)
	if not model or model == localChar() then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return false end
	local plr = Players:GetPlayerFromCharacter(model)
	if plr then
		if plr == LocalPlayer then return false end
		return true, hrp
	end
	if Config.IncludeNPCs then return true, hrp end
	return false
end

local function flatDirTo(fromPos, targetPos)
	local d = Vector3.new(targetPos.X - fromPos.X, 0, targetPos.Z - fromPos.Z)
	if d.Magnitude < 0.05 then return nil end
	return d.Unit
end

local function faceDotToThreat(th)
	local a = th and th.attackerHRP
	local targetPos = (a and a.Parent) and a.Position or nil
	local myHRP = localHRP()
	if not myHRP or not targetPos then return nil end
	local dir = flatDirTo(myHRP.Position, targetPos)
	if not dir then return 1 end
	local look = myHRP.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.05 then return nil end
	return flatLook.Unit:Dot(dir)
end

-- ══ РОТАЦИЯ ТОЛЬКО НА УДАРЫ, КОТОРЫЕ РЕАЛЬНО ЛЕТЯТ В НАС ═════════════════════
-- Доворот раньше шёл по сырому th.threatens, а этот флаг намеренно «щедрый»:
-- в него попадают свинги, оставленные включёнными geom-латчем (то есть те, где
-- живая геометрия УЖЕ отказала, а решение держится по инерции от прошлых кадров).
-- Для нажатия блока такая щедрость оправдана — лишний блок дешевле пропуска.
-- Для ПОВОРОТА она вредна: развернуться можно только в одну сторону, и время на
-- это тратится физически. В соло-бою цена нулевая (враг один), а в замесе мы
-- крутились на чужие удары и не успевали встретить свой.
-- Поворачиваемся только когда удар подтверждён живой геометрией сейчас:
-- offTarget (явно опознан как чужой) и «латч без реального пересечения хитбокса»
-- к развороту не приводят.
-- Вес удара для размена приоритетом. SKILL выше M2: скиллы обычно бьют сильнее
-- всего и часто ломают гард, поэтому нажатие в первую очередь достаётся им.
local function heavyRank(th)
	local k = th and th.kind
	if k == "SKILL" then return 2 end
	if k == "M2" then return 1 end
	return 0
end

local function aimedAtMe(th)
	if not th or not th.threatens then return false end
	if th.offTarget then return false end
	if Config.FaceOnlyRealThreats == false then return true end
	if th.trustedHit then return true end
	return not th.geomLatched
end

local function computeMultiFaceGoal()
	if not Config.AutoFace then return nil end
	local nThreat = 0
	for _, th in ipairs(Threats) do
		if aimedAtMe(th) and th.attackerHRP and th.attackerHRP.Parent then
			nThreat = nThreat + 1
			if nThreat >= 2 then break end
		end
	end
	if nThreat < 2 then return nil end

	local me = localHRP(); if not me then return nil end
	local mePos = me.Position
	local flatMe = me.CFrame.LookVector; flatMe = Vector3.new(flatMe.X, 0, flatMe.Z)
	flatMe = flatMe.Magnitude > 0.05 and flatMe.Unit or Vector3.new(0, 0, 1)
	local t = V93.faceBuf
	local n = 0
	for _, th in ipairs(Threats) do
		if aimedAtMe(th) and th.attackerHRP and th.attackerHRP.Parent then
			local to = th.attackerHRP.Position - mePos
			local d = Vector3.new(to.X, 0, to.Z)
			local dist = d.Magnitude
			if dist > 0.05 then
				d = d.Unit
				n = n + 1
				local e = t[n]
				if not e then e = {}; t[n] = e end
				e.k = th.attackerModel or th.attackerHRP or th.name
				e.dir = d
				e.dist = dist
				e.front = flatMe:Dot(d) > 0.05
			end
		end
	end
	for i = #t, n + 1, -1 do t[i] = nil end
	if n < 2 then return nil end
	local best, bestAng = nil, nil
	local maxA = math.rad(Config.MultiFaceAngleMax or 70)
	for i = 1, #t-1 do for j = i+1, #t do
		local a, b = t[i], t[j]
		if a.k ~= b.k then
			local ok = (not Config.MultiFaceOnlyFront) or (a.front and b.front)
			if ok then
				local ang = math.acos(math.clamp(a.dir:Dot(b.dir), -1, 1))
				if ang <= maxA and (bestAng == nil or ang < bestAng) then
					bestAng = ang; best = {a, b}
				end
			end
		end
	end end
	if not best then return nil end
	local a, b = best[1], best[2]
	local bis = a.dir + b.dir
	if bis.Magnitude < 0.05 then return nil end
	bis = bis.Unit
	local td = math.min(a.dist, b.dist) + math.abs(a.dist - b.dist)*0.35
	local base = mePos + bis*td
	local j = (Config.MultiFaceJitter or 0.30)
	local side = (math.sin((_C.FrameId % 12)/12 * math.pi * 2) + 1) * 0.5
	local perp = Vector3.new(-bis.Z, 0, bis.X)
	return base + perp * (math.min(a.dist, b.dist) * j * (side - 0.5) * 2)
end

local function setFaceGoalPos(pos, hard, holdFor)
	if not Config.AutoFace then return end
	if not pos then return end
	State.faceGoalHRP = nil
	State.faceGoalPos = pos
	State.faceGoalHard = hard and true or false
	State.faceGoalUntil = os.clock() + (holdFor or 0.15)
end

local function setFaceGoal(targetHRP, hard, holdFor)
	if not Config.AutoFace then return end
	if not targetHRP or not targetHRP.Parent then return end
	State.faceGoalHRP   = targetHRP
	State.faceGoalHard  = hard and true or false
	State.faceGoalUntil = os.clock() + (holdFor or 0.15)
end

local styleForward
local registryKind

_C.FaceTrack = setmetatable({}, { __mode = "k" })
local function attackerPrevPos(aHRP)
	local now = os.clock()
	local rec = _C.FaceTrack[aHRP]
	local prevPos, prevT = nil, nil
	if rec then
		prevPos, prevT = rec.pos, rec.t
		rec.t, rec.pos = now, aHRP.Position
	else
		_C.FaceTrack[aHRP] = { t = now, pos = aHRP.Position }
	end
	return prevPos, prevT
end

-- Каждый кадр: GetChildren() + до 60 итераций с GetAttribute и двумя
-- FindFirstChild — порядка 180 обращений к Instance API за кадр, и всё это
-- шло через VM. См. разбор у hitboxGeom.
local hitboxIndex = LPH_NO_VIRTUALIZE(function()
	if V93.hbFrame == _C.FrameId then return V93.byOwner end
	V93.hbFrame = _C.FrameId
	local byOwner = V93.byOwner
	for k in pairs(byOwner) do byOwner[k] = nil end
	local liveSid = V93.hbLiveSid
	for k in pairs(liveSid) do liveSid[k] = nil end
	local folder = V93.hbFolder
	if not (folder and folder.Parent) then
		folder = Workspace:FindFirstChild("Hitboxes")
		V93.hbFolder = folder
	end
	if not folder then return byOwner end
	for idx, child in ipairs(folder:GetChildren()) do
		if idx > 60 then break end
		if child:IsA("BasePart") then
			-- ХИТБОКСЫ ПЕРЕИСПОЛЬЗУЮТСЯ. Раньше «первое появление» запоминалось по
			-- самому Part и больше никогда не обновлялось. Но игра держит пул частей
			-- в workspace.Hitboxes и на новый свинг лишь МЕНЯЕТ атрибут VictimSwingId
			-- (её собственный VictimHitboxService именно поэтому слушает
			-- GetAttributeChangedSignal("VictimSwingId")). В результате hbFirstSeen
			-- указывал на момент из далёкого прошлого, проверка свежести
			-- `seen >= detectClock - 0.035` не проходила, и хитбокс НИКОГДА не
			-- сопоставлялся: в логе sid=none и hbFirst=? в 49 случаях из 52, всё
			-- пад��ло на предсказание по анимации. Считаем «первое появление» для
			-- ПАРЫ (часть + текущий VictimSwingId).
			local sidNow = child:GetAttribute("VictimSwingId")
			local seenRec = V93.hbFirstSeen[child]
			if not seenRec or seenRec.sid ~= sidNow then
				seenRec = { sid = sidNow, t = os.clock() }
				V93.hbFirstSeen[child] = seenRec
			end
			local owner = child:FindFirstChild("Owner")
			local atk   = child:FindFirstChild("AttackName")
			if owner and atk and owner:IsA("StringValue") and atk:IsA("StringValue") then
				local sid = sidNow
				if typeof(sid) == "string" and sid ~= "" then
					liveSid[sid] = true
					local aType = atk.Value
					if aType == "M1" or aType == "M2" then V93.sizes[aType] = child.Size end
					local nm  = owner.Value
					local lst = byOwner[nm]
					if not lst then lst = {}; byOwner[nm] = lst end
					lst[#lst + 1] = child
				end
			end
		end
	end
	for sid in pairs(V93.hbClaimBySid) do
		if not liveSid[sid] then V93.hbClaimBySid[sid] = nil end
	end
	return byOwner
end)

-- Вызывается из realHitboxHitsMe на каждую угрозу каждый кадр. См. hitboxGeom.
local associatedHitbox = LPH_NO_VIRTUALIZE(function(th)
	if th.serverHitbox and th.serverHitbox.Parent then return th.serverHitbox end
	local lst = hitboxIndex()[th.name]
	if not lst then return nil end
	local best, bestScore
	for i = 1, #lst do
		local part = lst[i]
		local atk = part and part:FindFirstChild("AttackName")
		local sid = part and part:GetAttribute("VictimSwingId")
		if part.Parent and atk and atk:IsA("StringValue") and atk.Value == th.kind
			and typeof(sid) == "string" and sid ~= "" then
			local owner = V93.hbClaimBySid[sid]
			local claimKey = th.group or th
			if owner == nil or owner == claimKey then
				-- Свежесть считаем по паре (часть + sid): при переиспользовании час��и
				-- запись обнуляется, поэтому здесь всегда время ТЕКУЩЕГО свинга.
				local seenRec2 = V93.hbFirstSeen[part]
				local seen = (seenRec2 and seenRec2.sid == sid and seenRec2.t) or os.clock()
				if seen >= th.detectClock - 0.035 then
					local score = math.abs(seen - (th.contactAbs or (th.detectClock + (th.contact0 or 0))))
					if not bestScore or score < bestScore then best, bestScore = part, score end
				end
			end
		end
	end
	if best then
		local sid = best:GetAttribute("VictimSwingId")
		V93.hbClaimBySid[sid] = th.group or th
		th.serverHitbox, th.serverSwingId = best, sid
		local bestSeen = V93.hbFirstSeen[best]
		th.hbFirstClock = (bestSeen and bestSeen.sid == sid and bestSeen.t) or os.clock()
		th.hbFirstServer = Workspace:GetServerTimeNow()
		th.hbFirstPos, th.hbFirstSize = best.Position, best.Size
		if th.group then
			th.group.serverHitbox, th.group.serverSwingId = best, sid
			th.group.hbFirstClock = th.hbFirstClock
		end
		-- ── ХИТБОКС = ИСТИНА ПО ВРЕМЕНИ КОНТАКТА ─────────────────────────────
		-- Из дампа: удар засчитывается НЕ в момент анимации, а когда часть из
		-- workspace.Hitboxes физически пересекает нас (VictimHitboxServiceClient
		-- сканирует это на 30Hz и сам отправляет VictimHitConfirm, передавая наши
		-- Blocking/PerfectBlocking В ЭТОТ МОМЕНТ). Хитбокс живёт HitboxDuration=0.15с.
		-- Поэтому если враг доворачивается или искусственно задерживает удар,
		-- реальное касание позже анимационного — в логе predErr доходит до +590мс,
		-- и наш перфект-блок к тому времени истекал, оставался обычный Blocking=1
		-- → сервер писал БЛОК ВМЕСТО ПАРРИ (в диаге прямо: guard=EARLY(>125)=BLOCK-NOT-PARRY).
		-- Появление хитбокса — надёжный признак реального касания, сдвигаем оценку.
		if Config.HitboxRetime ~= false and th.contactAbs then
			local hbContact = th.hbFirstClock + (Config.HitboxContactLead or 0.02)
			local minShift = Config.HitboxRetimeMinMs or 40
			if (hbContact - th.contactAbs) * 1000 >= minShift then
				local oldContact = th.contactAbs
				th.contactAbs = hbContact
				th.contactRetimed = true
				th.pressed = nil          -- переоткрывае�� возможность нажать по реальному времени
				if th.group then th.group.contactAbs = hbContact; th.group.pressed = nil end
				diagPush("HB-RETIME t=%.2f %s %s контакт %+.0fms→%+.0fms (удар задержан: хитбокс появился только сейчас)",
					os.clock(), tostring(th.name), tostring(th.kind),
					(oldContact - os.clock()) * 1000, (hbContact - os.clock()) * 1000)
			end
		end

		diagTrace("TRACE-HB t=%.3f %s %s s%d sid=%s first=%+.0fms toPred=%+.0fms pos=(%.1f,%.1f,%.1f) size=(%.1f,%.1f,%.1f)", os.clock(), th.name or "?", th.kind or "?", th.strike or 1, tostring(sid),
				(th.hbFirstClock - th.detectClock)*1000, ((th.contactAbs or th.hbFirstClock)-th.hbFirstClock)*1000,
				best.Position.X, best.Position.Y, best.Position.Z, best.Size.X, best.Size.Y, best.Size.Z)
	end
	return best
end)

local realHitboxHitsMe = LPH_NO_VIRTUALIZE(function(ownerName, th)
	if th and th.gtQueryFrame == _C.FrameId then return th.gtQueryResult end
	if not ownerName or not th then return nil end
	local part = (th.group and th.group.serverHitbox) or th.serverHitbox or associatedHitbox(th)
	if not (part and part.Parent) then
		th.gtQueryFrame, th.gtQueryResult = _C.FrameId, nil
		return nil
	end
	local char = localChar()
	if not char then return nil end
	local params = V93.hbParams
	if not params then
		params = OverlapParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.MaxParts = 20
		V93.hbParams = params
	end
	if V93.hbChar ~= char then params.FilterDescendantsInstances = { char }; V93.hbChar = char end

	-- РЕАЛЬНЫЙ игровой тест 1:1 как VictimHitboxServiceClient: пересекает ли хитбокс нас ПРЯМО СЕЙЧАС.
	if Config.PerfProbe then V93.probeGPBB = (V93.probeGPBB or 0) + 1 end
	local realHit = #Workspace:GetPartBoundsInBox(part.CFrame, part.Size, params) > 0
	if realHit and not th.hbOverlapClock then
		th.hbOverlapClock, th.hbOverlapServer = os.clock(), Workspace:GetServerTimeNow()
		local my = localHRP()
		local av = th.attackerHRP and th.attackerHRP.AssemblyLinearVelocity or Vector3.zero
		local mv = my and my.AssemblyLinearVelocity or Vector3.zero
		diagTrace("TRACE-OV t=%.3f %s %s s%d sid=%s detect=%+.0fms predErr=%+.0fms av=(%.1f,%.1f) mv=(%.1f,%.1f)", th.hbOverlapClock, th.name or "?", th.kind or "?", th.strike or 1,
				tostring(th.serverSwingId or (th.group and th.group.serverSwingId) or "none"),
				(th.hbOverlapClock-th.detectClock)*1000,
				(th.hbOverlapClock-(th.contactAbs or th.hbOverlapClock))*1000,
				av.X, av.Z, mv.X, mv.Z)
	end

	-- РАЗДУТИЕ НА ПИНГ: сер��ер должен увидеть Blocking=true ДО реального касания.
	-- Растим бокс на ��уть, который хитбокс/атакующий пройдёт за (ping + reaction),
	-- чтобы триггер сработал заранее. Это НЕ facing и НЕ reach — это тот же самый
	-- игровой overlap-тест, только с временным упреждением на задержку сети.
	local hit = realHit
	if not hit then
		local leadTime = getPing() + (Config.OverlapReaction or 0.050)
		local sp = 0
		local pv = part.AssemblyLinearVelocity
		if pv then sp = math.sqrt(pv.X * pv.X + pv.Z * pv.Z) end
		local ah = th.attackerHRP
		if ah and ah.Parent then
			local apv = ah.AssemblyLinearVelocity
			if apv then local asp = math.sqrt(apv.X * apv.X + apv.Z * apv.Z); if asp > sp then sp = asp end end
		end
		local lead = math.clamp((Config.OverlapLeadBase or 2.0) + sp * leadTime, 0, Config.OverlapLeadCap or 18.0)
		local infl = part.Size + Vector3.new(lead * 2, lead, lead * 2)
		if Config.PerfProbe then V93.probeGPBB = (V93.probeGPBB or 0) + 1 end
		hit = #Workspace:GetPartBoundsInBox(part.CFrame, infl, params) > 0
		if hit and not th.gtLeadClock then
			th.gtLeadClock = os.clock()
			diagTrace("TRACE-LEAD t=%.3f %s %s s%d lead=%.1f sp=%.1f ping=%.0fms toContact=%+.0fms", th.gtLeadClock, th.name or "?", th.kind or "?", th.strike or 1,
					lead, sp, getPing() * 1000, ((th.contactAbs or th.gtLeadClock) - th.gtLeadClock) * 1000)
		end
	end
	th.gtQueryFrame, th.gtQueryResult = _C.FrameId, hit
	return hit
end)

-- Вызывается из syncContactWithHitbox на каждую угро��у каждый кадр.
local hitboxNearestPart = LPH_NO_VIRTUALIZE(function(ownerName, kind)
	if not ownerName then return nil, nil end
	local lst = hitboxIndex()[ownerName]
	if not lst or #lst == 0 then return nil, nil end
	local me = localHRP()
	if not me then return nil, nil end
	local best, bestD = nil, math.huge
	for i = 1, #lst do
		local part = lst[i]
		local atk = part and part:FindFirstChild("AttackName")
		if part.Parent and atk and atk:IsA("StringValue") and (not kind or atk.Value == kind) then
			local d = (part.Position - me.Position).Magnitude
			if d < bestD then bestD = d; best = part end
		end
	end
	return best, bestD
end)

local syncContactWithHitbox = LPH_NO_VIRTUALIZE(function(th, now)
	if not Config.HitboxDodge then return end
	if (th.strike or 1) > 1 then return end
	if th.dodged or th.hitboxSynced then return end
	local part = hitboxNearestPart(th.name, th.kind)
	if not part then return end
	if not th.hitboxSeen then
		th.hitboxSeen, th.hitboxPart = now, part
	end
	if realHitboxHitsMe(th.name, th) == true then
		th.gtConfirmed, th.hitboxSynced = true, true
	end
end)

-- Дважды на каждый вызов hitboxGeom, то есть 2×угрозы×кадр.
local clampLeadToVictim = LPH_NO_VIRTUALIZE(function(lead, aPos, mePos)
	local d = Vector3.new(aPos.X - mePos.X, 0, aPos.Z - mePos.Z).Magnitude
	local maxLead = d * (Config.WillHitLeadFrac or 0.90)
	if lead.Magnitude <= maxLead then return lead end
	if maxLead <= 1e-3 then return Vector3.zero end
	return lead.Unit * maxLead
end)

-- ══ ГЛАВНАЯ ПРИЧИНА ПРОСАДКИ FPS (не визуал) ═══════════════════════════════
-- Скрипт проходит через Luraph, и ВСЁ, что не обёрнуто в LPH_NO_VIRTUALIZE,
-- исполняется интерпретатором его виртуальной машины — то есть в десятки раз
-- медленнее нативного Luau. Обёрнуто было ровно 9 функций, и hitboxGeom в это
-- число не входила, хотя это самая тяжёлая математика в проекте: ~90 строк
-- векторных операций, Vector3.new, .Magnitude, .Unit, math.sqrt, math.acos,
-- и вызывается она НА КАЖДУЮ УГРОЗУ КАЖДЫЙ КАДР из willHitMe.
-- Причина, по которой это было незаметно в диаге: `step=0.1ms` мерит
-- schedulerStep через os.clock() ВНУТРИ виртуализированного кода, но сам
-- willHitMe помечен NO_VIRTUALIZE, поэтому выглядел дешёвым — а всю работу
-- он делегировал сюда, в VM. Отсюда и «100→60 в файтах»: цена линейна по
-- числу угроз, поэтому вне боя её нет, а в замесе она умножается.
-- Обёртка ничего не меняет в логике и в таймингах: вне обфускации макрос —
-- это функ��ия-тождество (см. пролог файла, строки 1-15).
local hitboxGeom = LPH_NO_VIRTUALIZE(function(th)
	if th.geomFrame == _C.FrameId then
		return th.geomC, th.geomF, th.geomP, th.geomL
	end
	local aHRP = th.attackerHRP
	if not aHRP or not aHRP.Parent then th.geomFrame = _C.FrameId; th.geomC = nil; return nil end
	local now  = os.clock()
	local tHit = math.clamp((th.contactAbs or now) - now, 0, 0.6)
	local aPos = aHRP.Position
	local aV = safeGet(aHRP, "AssemblyLinearVelocity", Vector3.zero)
	local lead = Vector3.new(aV.X * tHit, 0, aV.Z * tHit)
	local meG = localHRP()
	if meG then
		local toMeG = Vector3.new(meG.Position.X - aPos.X, 0, meG.Position.Z - aPos.Z)
		if toMeG.Magnitude > 0.05 then
			toMeG = toMeG.Unit
			local leadDot  = lead:Dot(toMeG)
			local closeAmt = leadDot
			if th.prevPos and th.prevPosT then
				local dtp = now - th.prevPosT
				if dtp > 1e-3 and dtp < 0.5 then
					local pdx   = th.prevPos.X - meG.Position.X
					local pdz   = th.prevPos.Z - meG.Position.Z
					local prevD = math.sqrt(pdx * pdx + pdz * pdz)
					local cdx   = aPos.X - meG.Position.X
					local cdz   = aPos.Z - meG.Position.Z
					local curD  = math.sqrt(cdx * cdx + cdz * cdz)
					local measClose = (prevD - curD) / dtp
					if measClose > 0 then closeAmt = math.max(closeAmt, measClose * tHit) end
				end
			end
			local latVec   = lead - toMeG * leadDot
			local latCap   = Config.WillHitLatCap or 1.5
			if latVec.Magnitude > latCap then latVec = latVec.Unit * latCap end
			local distToMe = Vector3.new(aPos.X - meG.Position.X, 0, aPos.Z - meG.Position.Z).Magnitude
			local closeCap = math.min(Config.WillHitCloseCap or 12, distToMe * 0.95)
			closeAmt = math.clamp(closeAmt, 0, closeCap)
			lead = toMeG * closeAmt + latVec
			lead = clampLeadToVictim(lead, aPos, meG.Position)
		else
			local cap = Config.WillHitVelCap or 2.0
			if lead.Magnitude > cap then lead = lead.Unit * cap end
			lead = clampLeadToVictim(lead, aPos, meG.Position)
		end
	else
		local cap = Config.WillHitVelCap or 2.0
		if lead.Magnitude > cap then lead = lead.Unit * cap end
	end
	local predA = Vector3.new(aPos.X + lead.X, 0, aPos.Z + lead.Z)
	local look = aHRP.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.05 then return nil end
	flatLook = flatLook.Unit

	local forward = (styleForward and styleForward(th.style, th.kind))
	                or ((th.kind == "M2") and Config.M2Forward or Config.M1Forward)
	if styleStepForward and (Config.AccuracyMode or "High") == "High" then
		local st = styleStepForward(th.style, th.kind, th.combo)
		if type(st) == "number" and st > 0 then
			forward = forward + st
			th.geomStep = st
		end
	end

	local prevPos, prevT = attackerPrevPos(aHRP)
	th.prevPos  = prevPos
	th.prevPosT = prevT

	-- ЗАМЕР СКОРОСТИ ДОВОРОТА (рад/с). Нужен, чтобы посчитать, за сколько атакующий
	-- доведёт хитбокс до нас, если сейчас он смотрит мимо. Берём угол между текущим
	-- и предыдущим flatLook, делим на dt. Знак не важен — важна скорость.
	do
		local nowT = os.clock()
		local pl, plT = th.prevLook, th.prevLookT
		if pl and plT then
			local dt = nowT - plT
			if dt > 1e-3 and dt < 0.5 then
				local d = math.clamp(pl.X * flatLook.X + pl.Z * flatLook.Z, -1, 1)
				local rate = math.acos(d) / dt
				-- Сглаживаем, иначе один дёрганый кадр даёт выброс.
				th.turnRate = th.turnRate and (th.turnRate * 0.5 + rate * 0.5) or rate
			end
		end
		th.prevLook, th.prevLookT = flatLook, nowT
	end

	local center = predA + flatLook * forward
	th.geomFrame, th.geomC, th.geomF, th.geomP, th.geomL = _C.FrameId, center, forward, predA, flatLook
	return center, forward, predA, flatLook
end)

local willHitMe = LPH_NO_VIRTUALIZE(function(th)
	if Config.PerfProbe then V93.probeWHM = (V93.probeWHM or 0) + 1 end
	local myHRP, aHRP = localHRP(), th.attackerHRP
	if not myHRP then return Config.FilterFailSafe end
	if not aHRP or not aHRP.Parent then
		th.recognitionSource = "no-hrp"
		return false
	end
	local aPos, myPos = aHRP.Position, myHRP.Position
	local mode = Config.AccuracyMode or "Low"
	local gt = realHitboxHitsMe(th.name, th)
	if gt == true then
		th.gtConfirmed, th.trustedHit = true, true
		th.recognitionSource = "server-overlap"
		return true
	end

	local maxYd = math.max(Config.MaxHeightDiff or 12, 8)
	if not th.serverProven
	   and math.abs(myPos.Y - aPos.Y) > maxYd then
		th.recognitionSource = "y-diff"
		return false
	end
	if gt == false then
		th.recognitionSource = "server-pending"
	end

	local _, forward, predA, rawLook = hitboxGeom(th)
	if not predA or not rawLook then return Config.FilterFailSafe end
	local now = os.clock()
	local tHit = math.clamp((th.contactAbs or now) - now, 0, 0.6)
	local look, origin = rawLook, aPos
	if mode == "High" then
		origin = Vector3.new(predA.X, aPos.Y, predA.Z)
	end
	local sz = V93.sizes[th.kind]
	local myAt = myPos
	local halfW = (sz and sz.X * 0.5 or Config.HitHalfWidth or 3)
		+ (mode == "High" and (Config.HighSlack or 0.35) or (Config.HitboxSlack or 0))
	local halfH = (sz and sz.Y * 0.5 or 3) + 1.5
	local halfD = sz and sz.Z * 0.5 or (Config.HitboxDepth or 4)
	if math.abs(myAt.Y - origin.Y) > halfH then return false end
	local ox, oz = myAt.X - origin.X, myAt.Z - origin.Z
	local depth = ox * look.X + oz * look.Z
	local side = math.abs(ox * (-look.Z) + oz * look.X)
	th.geomDepth, th.geomSide = depth, side
	th.geomForward, th.geomHalfD, th.geomHalfW = forward, halfD, halfW
	th.geomTHit, th.geomOrigin, th.geomVictim, th.geomLook = tHit, origin, myAt, look

	local hit
	if mode == "High" then
		local dist2d = math.sqrt(ox * ox + oz * oz)
		local reach = forward + halfD + (Config.HighReachPad or 2.0)
		local coreReach = forward + halfD
		local toMeX, toMeZ = ox, oz
		if dist2d > 0.05 then toMeX, toMeZ = ox / dist2d, oz / dist2d else toMeX, toMeZ = look.X, look.Z end
		local faceToMe = look.X * toMeX + look.Z * toMeZ
		th.geomFaceToMe = faceToMe

		local approachAllow = 0
		do
			local dtc = (th.contactAbs or now) - now
			if dtc > 0 and dtc <= (Config.MaxWait or 1.2) then
				local velToMe = 0
				local pp, pt = th.prevPos, th.prevPosT
				if pp and pt then
					local dtm = now - pt
					if dtm > 1e-3 and dtm < 0.5 then
						local mvx, mvz = (aPos.X - pp.X) / dtm, (aPos.Z - pp.Z) / dtm
						velToMe = mvx * toMeX + mvz * toMeZ
					end
				end
				-- прямое чтение вместо pcall(function()...) — aHRP.Parent проверен выше (1077),
					-- willHitMe не делает yield, чтение AssemblyLinearVelocity на живом BasePart не
					-- бросает ошибку. Убирает аллокацию closure на КАЖДУЮ угрозу КАЖДЫЙ кадр (GC).
					local av = aHRP.AssemblyLinearVelocity
					if av then
						local physVel = av.X * toMeX + av.Z * toMeZ
						if physVel > velToMe then velToMe = physVel end
					end
				if velToMe > 0.5 then
					approachAllow = math.clamp(velToMe * dtc, 0, Config.HighApproachCap or 10.0)
				end
				th.closeVel = velToMe
			end
		end
		th.geomApproach = approachAllow

		-- ══ КОГДА ХИТБОКС РЕАЛЬНО НАКРОЕТ НАС ══════��═════════════════════════
		-- Это и есть корень «блока вместо парри». Анимация даёт момент, когда хитбокс
		-- ПОЯ��ЛЯЕТСЯ (M1HitboxDelay=0.32, M2=0.30), а удар засчитывается только когда
		-- бокс ФИЗИЧЕСКИ пересёк нас — и живёт он ещё HitboxDuration=0.15с.
		-- Если враг в момент появления смотрит мимо или не достаёт, попадание
		-- случается ПОЗЖЕ появления, а скрипт жал по появлению → зазор до удара
		-- раздувался за 125мс → сервер писал обычный блок.
		-- Замер по логу V176: trueGap медиана 94мс при цели 62мс, а у «доворо��ных»
		-- ударов 129..232мс — ровно то, что ты и описал.
		-- Считаем зазоры до внутренностей бокса и время их закрытия. Чистая
		-- геометрия и кинематика, без подгонки и без обучения.
		do
			local gapSide  = side - halfW                      -- >0: бокс идёт мимо сбоку
			local gapDepth = math.abs(depth - forward) - halfD -- >0: не достаёт по глубине
			local life = Config.HitboxDuration or 0.15
			local d = 0
			-- ПОРОГ ЗНАЧИМОСТИ. Зазор в пределах точности реконструкции бокса (наши
			-- halfW/halfD восстановлены из живых размеров и могут врать на пол-стада)
			-- считаем нулевым, иначе шум геометрии начнёт создавать ложную задержку
			-- на ударах, которые и так попадают, — а это прямой путь к пропуску.
			local eps = Config.OvGapEps or 0.75
			if gapSide < eps then gapSide = 0 end
			if gapDepth < eps then gapDepth = 0 end
			if gapSide > 0 or gapDepth > 0 then
				local dRot, dApp = 0, 0
				-- ФОЛБЭК `= life` БЫЛ ГРУБОЙ ОШИБКОЙ. Если враг НЕ вращается и НЕ
				-- сближается, зазор не закроется вообще — а код ставил d = life,
				-- которое дальше зажималось до 40мс и ПРИБАВЛЯЛОСЬ к контакту.
				-- В логе это дало +40мс на ВСЕХ 37 ударах, в 25 из них при
				-- доворот=0.0 и сближение=0.0, то есть просто сдвиг всего тайминга
				-- на 40мс позже. Нет движения → нет задержки, ноль.
				if gapSide > 0 then
					-- Доворот: смещение нашей боковой координаты ≈ dist * dθ,
					-- значит нужный угол dθ = gapSide / dist.
					local w = th.turnRate or 0
					if dist2d > 0.1 and w > 0.05 then
						dRot = (gapSide / dist2d) / w
					end
				end
				if gapDepth > 0 then
					local v = th.closeVel or 0
					if v > 0.5 then dApp = gapDepth / v end
				end
				d = math.max(dRot, dApp)
				if d > life then d = life end
				-- ПРЕДЕЛ С ДОКАЗУЕМО ОГРАНИЧЕННЫМ УЩЕРБОМ. Задержка сдвигает нажатие
				-- позже. Если мы ошиблись и удар прилетел всё-таки по анимации, зазор
				-- уменьшится ровно на d. Цель зазора ≈ 62мс, а по логу парри работает
				-- даже при 10мс, поэтому d ≤ 55мс не может превратить парри в пропуск —
				-- в худшем случае зазор станет ~7мс, что всё ещё парри.
				-- Полные 150мс (время жизни хи��бокса) брать нельзя: при завышенной
				-- оценке зазор ушёл бы в минус, а это уже пропущенный удар.
				-- Предел 40мс выбран по логу: минимальный наблюдённый зазор 10мс плюс
				-- защитный пол цели 55мс дают запас, при котором ошибочная задержка
				-- оставляет зазор положительным.
				-- ВЫКЛЮЧЕНО ПО ЗАМЕРУ (Config.OvDelayCap = 0).
				-- В логе V176 задержка срабатывала 54 раза и 49 из них (91%)
				-- упиралась ровно в кап 40мс — то есть это была не оценка
				-- геометрии, а КОНСТАНТНЫЙ с��виг всего тайминга на 40мс позже.
				-- Причина завышения: модель считает время закрытия зазора по
				-- текущей скорости, но не учитывает шаг вперёд на замахе
				-- (M1StepForwardStuds) и запас самого хитбокса. Пример из лога:
				-- глубина=4.5 при сближении=5.9 даёт 760мс, хотя удар приходит
				-- через 330мс. Модель таймера теперь точна до ±7мс, и эта
				-- «поправка» только уводила нажатие из окна.
				local cap = Config.OvDelayCap or 0
				if d > cap then d = cap end
			end
			th.ovDelay   = d
			th.ovGapSide = gapSide
			th.ovGapDepth = gapDepth
		end

		-- НАПРАВЛЕНИЕ УДАРА. Порог -0.85 пропускал врага, отвернувшегося от нас почти
		-- на 148°, а faceExempt по coreReach снимал проверку вообще на всей длине
		-- замаха — отсюда ложные реакции на тех, кто бьёт кого-то другого спиной к нам.
		-- Из дампа: хитбокс ставится в HRP.CFrame * (0,0,-offset), т.е. ВПЕРЁД, и в
		-- M2_ModuleScript:358 атакующий доворачивается CFrame.lookAt в момент создания
		-- хитбокса. Значит довернуться он может, но только за ост��ток замаха
		-- (M1HitboxDelay=0.32, M2=0.30). Поэтому допуск на поворот считаем из
		-- оставшегося времени и скорости поворота, а не берём константой.
		-- ══ ТРЕТИЙ И ГЛАВНЫЙ ОБХОД: КОНУС БЫЛ ШИРЕ ГЕОМЕТРИИ В 5-8 РАЗ ══════════
		-- Замер по этому логу (V176), значения взяты прямо из строк диага:
		--   faceHard = cos(115°) = -0.4226  →  это конус 230°, т.е. НЕ фильтр.
		--   faceFloor при dt=292мс = -0.9968 → конус 175°, тоже не фильтр.
		-- Проверка на реальных строках:
		--   line78  face=0.12  (83°)  dt=169мс → ПРОШЁЛ, мы развернулись и нажали
		--   line109 face=-0.33 (109°) dt=166мс → ПРОШЁЛ, враг смотрел ОТ нас
		-- А сколько нужно ГЕОМЕТРИЧЕСКИ, чтобы бокс (halfW≈2.4) накрыл нас:
		--   dist=6 → 21.8°,  dist=9 → 14.9°,  dist=10 → 13.5°.
		-- То есть допуск был в 5-8 раз шире физически возможного. Отсюда и
		-- «реагирует на удары, которые точно не по мне, они даже далеко».
		--
		-- Причина завышения — модель «врагу хватит времени довернуться»:
		-- turnBudget = остаток замаха * TurnRateRad(6.0 рад/с = 344°/с). При
		-- dt=292мс это давало +100° к конусу. Но 6.0 рад/с — потолок, а не факт,
		-- и главное: th.turnRate считается как acos(d)/dt, то есть БЕЗ ЗНАКА —
		-- поворот ОТ нас засчитывался как приближение к нам наравне с поворотом
		-- К нам. Модель разрешала доворот, которого не происходит.
		--
		-- Теперь считаем ровно то, что решает игра: хитбокс ставится в
		-- HRP.CFrame * (0,0,-offset), значит накроет нас только если мы лежим
		-- внутри его половины ширины. Нужный угол = atan(halfW / dist), а бюджет
		-- доворота — ИЗМЕРЕННАЯ скорость сокращения угла до нас (знаковая), а не
		-- константа. Плюс ограниченная добавка на снап CFrame.lookAt в момент
		-- создания хитбокса (M2_ModuleScript:358) — он мгновенный, поэтому
		-- кинематикой его не поймать, но и бесконечным он быть не может.
		--
		-- Знаковую скорость сокращения угла измеряем здесь же: положительная —
		-- враг доворачивается К нам, отрицательная — отворачивается.
		local angToMe = math.acos(math.clamp(faceToMe, -1, 1))
		do
			local pa, pt = th.angPrev, th.angPrevT
			if pa and pt then
				local dtA = now - pt
				if dtA > 1e-3 and dtA < 0.5 then
					local r = (pa - angToMe) / dtA
					th.angClose = th.angClose and (th.angClose * 0.5 + r * 0.5) or r
				end
			end
			th.angPrev, th.angPrevT = angToMe, now
		end
		-- Освобождаем от проверки только реальный упор (мы уже внутри глубины бокса)
		-- и подтверждённые сервером свинги у самого контакта.
		-- ── ПОЧЕМУ ФИЛЬТР НЕ ФИЛЬТРОВАЛ (отклонено 2 удара из 88) ──────────────
		-- `faceExempt` снимал проверку направления ЦЕЛИКОМ для любого
		-- server-proven свинга ближе ~180мс до контакта. А server-proven — это
		-- КАЖДЫЙ реальный свинг (в логе `PROVEN by=attr +4ms after detect` на
		-- каждой строке). То есть у самого контакта, когда решение и принимается,
		-- направление не проверялось вообще: враг, бьющий СПИНОЙ к нам по
		-- кому-то другому, проходил как угроза. Это ровно тот случай, что ты
		-- описал — и он не просто «лишняя реакция»: каждый такой блок сжигает
		-- наш кулдаун 0.5с, и следующий РЕАЛЬНЫЙ удар приходит на кулдаун
		-- (в шапке диага: 10 из 23 пропусков — game-state-locked).
		-- Полный обход оставляем только когда мы ФИЗИЧЕСКИ внутри бокса —
		-- там направление действительно не имеет значения. Для proven-свингов
		-- даём широкий конус вместо отключения проверки: доворот возможен, но
		-- развернуться на 180° за остаток замаха нельзя.
		-- Мы физически внутри глубины бокса — направление действительно не важно.
		local faceExemptCore = (dist2d <= halfD)
		local faceOk, faceAllowDeg
		if faceExemptCore then
			faceOk, faceAllowDeg = true, 180
		else
			-- Сколько нужно довернуть, чтобы половина ширины бокса дотянулась до нас.
			local angNeed = angToMe - math.atan2(halfW, math.max(dist2d, 0.5))
			if angNeed < 0 then angNeed = 0 end
			-- Сколько реально успеют довернуть: измеренное сокращение угла за
			-- остаток замаха. Отворачивание (отрицательное) в бюджет не идёт.
			local tRem   = math.clamp((th.contactAbs or now) - now, 0, 0.4)
			local wClose = math.clamp(th.angClose or 0, 0, Config.TurnRateRad or 6.0)
			local budget = wClose * tRem + math.rad(Config.TurnSnapDeg or 35)
			-- Абсолютный потолок: удар из-за спины не считаем угрозой никогда.
			local hardMax = math.rad(Config.FaceHardDeg or 100)
			faceOk = (angNeed <= budget) and (angToMe <= hardMax)
			faceAllowDeg = math.deg(math.atan2(halfW, math.max(dist2d, 0.5)) + budget)
		end
		th.geomFaceFloor  = faceOk and -1.01 or math.cos(math.rad(math.min(faceAllowDeg, 180)))
		th.geomFaceAllow  = faceAllowDeg
		th.geomAngToMe    = math.deg(angToMe)
		-- Игра сама решает попадание только через GetPartBoundsInBox, а её грубый
		-- префильтр дистанции = Size.Magnitude/2 + 6 (см. VictimHitboxServiceClient).
		-- Наша реконструкция reach из combo-геометрии может ошибаться на пару стадов,
		-- и тогда РЕАЛЬНЫЙ, подтверждённый сервером свинг у самого контакта отлетал в
		-- OUT-OF-REACH (диаг: Maria_Branzica predicted-overlap contactIn=-0ms). Для
		-- server-proven угроз даём бонус к reach = игровой префильтр (+6), НО только
		-- когда контакт уже близко (<=~180мс) — чтобы не ловить далёкий фейк-спам.
		-- ВАЖНО ПРО +6: Size.Magnitude/2 + 6 в VictimHitboxServiceClient — это
		-- ГРУБЫЙ ПРЕФИЛЬТР широкой фазы (кого вообще проверять), а не тест
		-- попадания. Тест попадания у игры один — GetPartBoundsInBox. Подставлять
		-- префильтр вместо теста значит раздувать вылет на 6 стадов: в логе
		-- враги с dist=9..10 проходили как угроза. Здесь нужен только допуск на
		-- ошибку нашей реконструкции бокса (ProvenReachPad, ~2 стада), а
		-- сближение уже учтено отдельно в approachAllow.
		local reachEff = reach + approachAllow
		if th.serverProven then
			local dtc = (th.contactAbs or now) - now
			if dtc <= (Config.ProvenReachWindow or 0.18) then
				reachEff = math.max(reachEff, coreReach + (Config.ProvenReachPad or 2.0))
			end
		end
		-- Сохраняем ФАКТИЧЕСКИ применённый вылет: диаг раньше пересчитывал его по
		-- своей формуле (reachD + appr, без proven-пада) и мог написать "reach-ok"
		-- там, где тест отказал именно по вылету. Расхождение диага с логикой —
		-- худшее, что может быть при разборе, поэтому печатаем одно и то же число.
		th.geomReachEff = reachEff
		th.geomDist2d   = dist2d
		hit = (dist2d <= reachEff) and faceOk
	else
		th.geomFaceToMe = nil
		hit = depth >= (forward - halfD) and depth <= (forward + halfD) and side <= halfW
	end

	if hit and th.serverProven then
		th.geomStickyUntil = math.max(th.geomStickyUntil or 0,
			(th.contactAbs or now) + (Config.HoldAfter or 0.12) + 0.05)
		th.geomStickySource = th.recognitionSource or (mode == "High" and "predicted-overlap" or "current-overlap")
	elseif not hit and th.serverProven and (th.geomStickyUntil or 0) >= now then
		-- ── ВТОРОЙ МЕХАНИЗМ, ОБЕСЦЕНИВАВШИЙ ФИЛЬТР ────────────────────────────
		-- Достаточно было ОДНОГО кадра, где геометрия дала попадание, чтобы
		-- взвести sticky до `contact + HoldAfter + 50мс`. После этого ЛЮБОЙ
		-- последующий отказ геометрии переписывался в `hit = true` без условий.
		-- В связке с отключённым направлением (см. выше) это и давало
		-- «реагирует на всё»: враг мог отвернуться или отойти — решение уже
		-- было приклеено. Смысл у sticky есть, но узкий: наши halfW/halfD
		-- восстановлены из живых размеров и врут на пол-стада, поэтому
		-- ПОГРАНИЧНЫЙ промах (CURRENT-MISS) действительно надо переживать.
		-- А вот «отвернулся» и «ушёл далеко за пределы вылета» — это не шум
		-- реконструкции, это смена обстановки, и держать их нельзя.
		local d2       = math.sqrt(ox * ox + oz * oz)
		local reachPad = forward + halfD + (Config.HighReachPad or 2.0)
		local reason = (mode == "High" and ((d2 > reachPad)
			and "OUT-OF-REACH" or "BACK-FACING")) or "CURRENT-MISS"
		local revive = true
		if Config.StickyStrict ~= false and mode == "High" then
			if reason == "OUT-OF-REACH" then
				-- Терпим только запас на ошибку реконструкции вылета.
				revive = d2 <= reachPad + (Config.StickyReachPad or 4.0)
			elseif reason == "BACK-FACING" then
				-- Сверяемся с ТЕМ ЖЕ допуском, что применил основной тест
				-- (geomFaceAllow), а не с отдельным cos-порогом. Иначе sticky
				-- оживлял бы удар, который основной гейт только что отклонил
				-- по направлению, — то есть третий обход того же фильтра.
				local ang, allow = th.geomAngToMe, th.geomFaceAllow
				revive = (ang == nil) or (allow == nil) or (ang <= allow)
			end
		end
		if revive then
			hit = true
			th.recognitionSource = "geom-sticky/" .. reason
		else
			th.recognitionSource = "sticky-dropped/" .. reason
		end
		if Config.TraceDiag and (not th.geomStickyLogAt or now - th.geomStickyLogAt > 0.10) then
			th.geomStickyLogAt = now
			diagTrace("GEOM-STICKY t=%.3f %s %s s%d veto=%s revive=%s source=%s contactIn=%+.0fms stickyLeft=%.0fms dist=%.1f reach=%.1f face=%.2f", now, tostring(th.name), tostring(th.kind), th.strike or 1, reason,
					tostring(revive), tostring(th.geomStickySource or "?"), ((th.contactAbs or now)-now)*1000,
					((th.geomStickyUntil or now)-now)*1000, d2, reachPad, th.geomFaceToMe or 0)
		end
	end

	th.trustedHit = hit
	-- "sticky-dropped/..." тоже сохраняем: иначе причина отказа затиралась бы
	-- общим "predicted-miss" и в диаге было бы не видно, что именно отсеялось.
	if th.recognitionSource and (th.recognitionSource:sub(1, 12) == "geom-sticky/"
		or th.recognitionSource:sub(1, 15) == "sticky-dropped/") then
	elseif gt == false and not hit then
		th.recognitionSource = "server-pending+predicted-miss"
	else
		th.recognitionSource = hit and (mode == "High" and "predicted-overlap" or "current-overlap")
			or (mode == "High" and "predicted-miss" or "current-miss")
	end
	if not hit then th.offTarget = true end
	if not hit and Config.DeepDiag and not th.geomRejLogged then
		th.geomRejLogged = true
		local dist2d = math.sqrt(ox * ox + oz * oz)
		local reachD = forward + halfD + (Config.HighReachPad or 2.0)
		local f2m = th.geomFaceToMe
		if f2m == nil then
			f2m = 1
			if dist2d > 0.05 then f2m = (look.X * ox + look.Z * oz) / dist2d end
		end
			local appr = th.geomApproach or 0
			-- Берём вылет, применённый в самом тесте, а не пересчитываем заново.
			local reachEff = th.geomReachEff or (reachD + appr)
			if Config.TraceDiag then
			diagTrace("GEOM-REJECT t=%.3f %s %s(%s) c%s v%s mode=%s dt=%+.0fms | dist2d=%.2f reachEff=%.2f (fwd=%.2f step=%.2f halfD=%.2f appr=%.2f) %s | угол=%.0f° допуск=%.0f° закрытие=%.1fрад/с %s | depth=%.2f side=%.2f/%.2f", now, tostring(th.name), tostring(th.kind), tostring(th.style),
				tostring(th.combo or "?"), tostring(th.variant or "-"), tostring(mode),
				((th.contactAbs or now) - now) * 1000,
				dist2d, reachEff, forward - (th.geomStep or 0), th.geomStep or 0, halfD, appr,
				(dist2d > reachEff) and "OUT-OF-REACH" or "reach-ok",
				th.geomAngToMe or math.deg(math.acos(math.clamp(f2m, -1, 1))),
				th.geomFaceAllow or 0, th.angClose or 0,
				((th.geomAngToMe or 999) > (th.geomFaceAllow or 0)) and "NOT-AIMED-AT-ME" or "aim-ok",
				depth, side, halfW)
			end
		end
		return hit
	end)

local function nextCombo(attacker)
	local now = os.clock()
	local c = ComboState[attacker]
	local isFresh = (c == nil)
	local isNew = isFresh or (now - c.last) > _D.COMBO_RESET
	if isNew then c = { idx = 0, last = now } end
	c.idx  = (c.idx % 4) + 1
	c.last = now
	ComboState[attacker] = c
	ComboState._count = (ComboState._count or 0) + (isFresh and 1 or 0)
	if ComboState._count > 64 then
		local oldest, oldestName = math.huge, nil
		for name, rec in pairs(ComboState) do
			if type(rec) == "table" and rec.last and rec.last < oldest then
				oldest = rec.last; oldestName = name
			end
		end
		if oldestName then ComboState[oldestName] = nil; ComboState._count = ComboState._count - 1 end
	end
	return c.idx
end

local GameData = { cfg = nil, cau = nil, cu = nil, resolved = false }

local function loadGameModules()
	if GameData.resolved then return end
	-- БАГ (был): GameData.resolved = true ставился ДО pcall. loadGameModules()
	-- вызывается на старте скрипта, когда ReplicatedStorage.Shared может быть ещё
	-- не от��еп��ицирован → FindFirstChild вернёт nil, cfg останется nil, но флаг
	-- уже стоял → повт��рной попытки НИКОГДА не было. Все 44 обращения к
	-- GameData.cfg молча мертвы: perfectWindow/iframeDur/attackSpeedMult
	-- деградируют в захардкоженные константы на всю сессию.
	-- Теперь: помечаем resolved только когда реально получили CombatConfig,
	-- иначе разрешаем повтор (не чаще раза в 0.25с, чтобы не грузить require).
	local now = os.clock()
	if (now - (GameData.lastTry or -1)) < 0.25 then return end
	GameData.lastTry = now
	GameData.tries   = (GameData.tries or 0) + 1
	pcall(function()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local cfgMod = shared and shared:FindFirstChild("Config") and shared.Config:FindFirstChild("CombatConfig")
		if cfgMod then GameData.cfg = require(cfgMod) end
		local cauMod = shared and shared:FindFirstChild("Utils") and shared.Utils:FindFirstChild("CombatAnimationUtils")
		if cauMod then GameData.cau = require(cauMod) end
		local pauMod = shared and shared:FindFirstChild("Utils") and shared.Utils:FindFirstChild("CombatPingAnimUtils")
		if pauMod then GameData.pau = require(pauMod) end
		local pkgs = ReplicatedStorage:FindFirstChild("Packages")
		local cuMod = pkgs and pkgs:FindFirstChild("CombatUtils")
		if cuMod then GameData.cu = require(cuMod) end
	end)
	pcall(function()
		local ev = GameData.cfg and GameData.cfg.Evasive
		if ev and type(ev.IFrameDuration) == "number" and ev.IFrameDuration > 0.05 then
			GameData.iframeDur = ev.IFrameDuration
		end
		local cp = GameData.cfg and GameData.cfg.ClientPredict
		local cpe = cp and cp.Evasive
		if cpe and type(cpe.ServerConfirmTimeout) == "number" then
			GameData.confirmTimeout = cpe.ServerConfirmTimeout
		end
		if type(ev) == "table" and type(ev.Cooldown) == "number" and ev.Cooldown > 0 then
			GameData.evCooldown = ev.Cooldown
		end
		if cpe and type(cpe.Cooldown) == "number" and cpe.Cooldown > 0 then
			GameData.evPredictCooldown = cpe.Cooldown
		end
		if type(ev) == "table" and type(ev.DashDuration) == "number" and ev.DashDuration > 0 then
			GameData.dashDuration = ev.DashDuration
		end
		local bl = GameData.cfg and GameData.cfg.Block
		if bl and type(bl.PerfectBlockWindow) == "number" then
			GameData.perfectWindow = bl.PerfectBlockWindow
		end
		-- Живой кап ping-компенсации (Shared.NetworkAnimPingCompensation).
		local sh = GameData.cfg and GameData.cfg.Shared
		local nap = sh and sh.NetworkAnimPingCompensation
		if nap and type(nap.MaxEstimatedOneWaySeconds) == "number" then
			GameData.animPingCap = nap.MaxEstimatedOneWaySeconds
		end
		-- Shared.HitboxWindupExtra: аддитивная добавка ко ВСЕМ задержкам хитбокса.
		-- GetScaledHitboxDelay = (base + extra) / heightMult. Раньше в скрипте её
		-- не было вообще → систематическая ошибка 12мс на каждой атаке.
		if sh and type(sh.HitboxWindupExtra) == "number" then
			GameData.windupExtra = sh.HitboxWindupExtra
		end
	end)
	-- Критический модуль — CombatConfig: без него мертвы и окно парирования, и
	-- iframe-длительность. Остальные (cau/pau/cu) опциональны.
	if GameData.cfg then
		GameData.resolved = true
		diagPush("GAMEDATA-OK tries=%d perfectWindow=%s iframeDur=%s pau=%s cu=%s",
			GameData.tries or 0,
			GameData.perfectWindow and string.format("%.0fms", GameData.perfectWindow * 1000) or "nil",
			GameData.iframeDur and string.format("%.0fms", GameData.iframeDur * 1000) or "nil",
			GameData.pau and "yes" or "no", GameData.cu and "yes" or "no")
	end
end

-- ══ КОРЕНЬ БАГА "У НИЗКИХ ВРАГОВ ДЕРЖИТ БЛОК ВМЕСТО ПАРРИ" ═══════════════════
-- Рост атакующего входит в тайминг НАПРЯМУЮ: игра берёт задержку хитбокса как
-- GetScaledHitboxDelay = (base + windup) / heightMult, и hitTimeline() делит на
-- ровно этот aMult. Низкий рост → heightMult до 1.15 → удар приходит на 15%
-- РАНЬШЕ. Если рост не определился, здесь молча возвращалась 1, и для базы
-- 364мс мы ждали 364мс вместо реальных 316мс — опоздание ~48мс при окне парри
-- 125мс. Нажатие уходило за окно, и удар регистрировался как ОБЫЧНЫЙ БЛОК.
-- Ровно то, что описывают: «у низких часто держит блок, а не парирует».
--
-- Почему это не лечилось само: обучаемый сдвиг residContactBias() имеет
-- `if s < 0 then s = 0 end`, то есть умеет только ОТОДВИГАТЬ прогноз позже.
-- Наша ошибка здесь противоположна по знаку (жмём слишком поздно), поэтому
-- обратная связь структурно не могла её скомпенсировать — сколько бы боёв ни
-- прошло. Лечить надо источник, а не последствие.
--
-- Старая цепочка источников роста обрывалась на двух пунктах, и оба часто
-- недоступны для ЧУЖОГО игрока: PlayerData (не всегда реплицируется) и
-- BodyHeightScale (NumberValue, есть не на каждом риге). Добавлены два
-- надёжных, реплицируемых источника — applied HumanoidDescription.HeightScale
-- и геометрия через Humanoid.HipHeight. Единицы у всех одинаковые: это
-- масштаб роста (домен формулы 0.983..1.45), а не studs.
local HEIGHT_H_LO, HEIGHT_H_HI = 0.983, 1.45
local R15_HIP_HEIGHT = 2.0   -- HipHeight стандартного R15 при scale = 1.0

-- Возвращает рост-масштаб атакующего и имя источника (для диагностики).
local function resolveCharHeight(model)
	local h, src
	pcall(function()
		local pd = model:FindFirstChild("PlayerData")
		if pd then
			local v = tonumber(pd:GetAttribute("CurrentHeight")) or tonumber(pd:GetAttribute("Height"))
			if type(v) == "number" and v > 0.05 then h, src = v, "playerdata" end
		end
	end)
	if not h then
		pcall(function()
			local hum = model:FindFirstChildOfClass("Humanoid")
			local scale = hum and hum:FindFirstChild("BodyHeightScale")
			if scale and scale:IsA("NumberValue") and scale.Value > 0.05 then
				h, src = scale.Value, "bodyscale"
			end
		end)
	end
	if not h and Config.HeightDeepFallback ~= false then
		-- Applied HumanoidDescription реплицируется на всех игроков, и HeightScale
		-- в нём — ровно тот масштаб, которым игра скалит рост.
		pcall(function()
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				local d = hum:GetAppliedDescription()
				if d and type(d.HeightScale) == "number" and d.HeightScale > 0.05 then
					h, src = d.HeightScale, "description"
				end
			end
		end)
	end
	if not h and Config.HeightDeepFallback ~= false then
		-- Последний рубеж: HipHeight у R15 линейно масштабируется ростом, читается
		-- у любого отрендеренного персонажа. R6 не скалится ростом — там 1.0.
		pcall(function()
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.RigType == Enum.HumanoidRigType.R15 then
				local hip = hum.HipHeight
				if type(hip) == "number" and hip > 0.2 then
					h, src = hip / R15_HIP_HEIGHT, "hipheight"
				end
			end
		end)
	end
	if type(h) == "number" then
		-- Формула определена только на своём домене; вне него значение мусорное.
		if h < HEIGHT_H_LO * 0.5 or h > HEIGHT_H_HI * 1.5 then return nil, nil end
		return h, src
	end
	return nil, nil
end

_C.AttackMultCache = setmetatable({}, { __mode = "k" })
_C.HeightSrcLogged = setmetatable({}, { __mode = "k" })
local function attackSpeedMult(model)
	if not model then return 1 end
	local c = _C.AttackMultCache[model]
	if c and (os.clock() - c.t) < 1.0 then return c.m end
	loadGameModules()
	local mult, src = 1, nil
	if GameData.cu then
		local ok, h = pcall(function() return GameData.cu.GetCharacterHeight(model) end)
		if ok and type(h) == "number" then
			local ok2, m = pcall(function() return GameData.cu.GetAttackSpeedMultiplier(h) end)
			if ok2 and type(m) == "number" and m > 0.05 then mult, src = m, "cu" end
		end
	end
	if not src then
		local h, hsrc = resolveCharHeight(model)
		if h then
			-- Тот же расчёт, что и в игре, но по нашему замеру роста. Если живая
			-- GetAttackSpeedMultiplier доступна — предпочитаем её (она источник истины).
			local applied = false
			if GameData.cu then
				local ok, m = pcall(function() return GameData.cu.GetAttackSpeedMultiplier(h) end)
				if ok and type(m) == "number" and m > 0.05 then
					mult, src, applied = m, "cu-fn/" .. tostring(hsrc), true
				end
			end
			if not applied then
				mult = 1.15 - math.clamp((h - HEIGHT_H_LO) / (HEIGHT_H_HI - HEIGHT_H_LO), 0, 1) * 0.3
				src = "formula/" .. tostring(hsrc)
			end
		end
	end
	mult = math.clamp(mult, 0.80, 1.20)
	-- Один раз на модель сообщаем, откуда взят рост: если в бою против низкого
	-- врага здесь окажется src=none, значит тайминг считается без учёта роста.
	if Config.DeepDiag and not _C.HeightSrcLogged[model] then
		_C.HeightSrcLogged[model] = true
		diagPush("HEIGHT-SRC %s → aMult=%.3f src=%s", tostring(model and model.Name), mult, tostring(src or "none(=1.0)"))
	end
	_C.AttackMultCache[model] = { m = mult, t = os.clock(), src = src }
	return mult
end

local function heightDiag(model)
	local attrHeight, bodyScale, modelHeight = nil, nil, nil
	pcall(function()
		local pd = model and model:FindFirstChild("PlayerData")
		if pd then attrHeight = tonumber(pd:GetAttribute("CurrentHeight")) or tonumber(pd:GetAttribute("Height")) end
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		local scale = hum and hum:FindFirstChild("BodyHeightScale")
		if scale and scale:IsA("NumberValue") then bodyScale = scale.Value end
		if model then modelHeight = model:GetExtentsSize().Y end
	end)
	return attrHeight, bodyScale, modelHeight
end

_C.styleFn  = function(m) return GameData.cau.GetCombatStyleForCharacter(m) end
_C.styleAttr = function(m) return m:GetAttribute("CombatStyle") end
_C.styleCache = setmetatable({}, { __mode = "k" })
local function styleOf(model)
	local e = _C.styleCache[model]
	local nowc = os.clock()
	if e and nowc < e.t then return e.v end
	loadGameModules()
	local out
	if GameData.cau then
		local ok, s = pcall(_C.styleFn, model)
		if ok and type(s) == "string" and #s > 0 then out = s end
	end
	if not out then
		local ok, s = pcall(_C.styleAttr, model)
		if ok and type(s) == "string" and #s > 0 then out = s end
	end
	out = out or "Basic"
	if e then e.v, e.t = out, nowc + 0.5 else _C.styleCache[model] = { v = out, t = nowc + 0.5 } end
	return out
end

_D.AttackIds = {}
local function comboFromName(nm)
	local n = nm:match("^(%d+)")
	if n then return tonumber(n) end
	local l = nm:lower()
	if l:find("first")  then return 1 end
	if l:find("second") then return 2 end
	if l:find("third")  then return 3 end
	if l:find("fourth") then return 4 end
	return nil
end
local function kindFromName(nm)
	if nm:match("M2") then return "M2" end
	if nm:match("M1") then return "M1" end
	return nil
end
local function animIdOf(inst)
	if inst:IsA("Animation") then return tonumber(tostring(inst.AnimationId):match("(%d+)")) end
	local a = inst:FindFirstChildWhichIsA("Animation")
	if a then return tonumber(tostring(a.AnimationId):match("(%d+)")) end
	return nil
end
_D.BlockIds = {}
local function looksDefensive(nm)
	local l = nm:lower()
	return (l:find("block") or l:find("guard") or l:find("parry")
		or l:find("deflect") or l:find("perfect")) ~= nil
end
local function indexAllAnims()
	pcall(function()
		local anims  = ReplicatedStorage:FindFirstChild("Animations")
		if not anims then return end
		local combat = anims:FindFirstChild("Combat")
		if combat then
			for _, styleFolder in ipairs(combat:GetChildren()) do
				if styleFolder:IsA("Folder") then
					local isStyleFolder = styleFolder:FindFirstChild("M2") ~= nil
						or styleFolder:FindFirstChild("1stM1") ~= nil
						or styleFolder:FindFirstChild("2ndM1") ~= nil
					for _, child in ipairs(styleFolder:GetChildren()) do
						local lname     = child.Name:lower()
						local defensive = looksDefensive(child.Name)
						local reaction  = (lname:find("ehit") or lname:find("success")
							or lname:find("blockhit")) ~= nil
						local benignMove = (lname == "idle" or lname == "walk" or lname == "run"
							or lname:find("dash")) ~= nil
						local kind = nil
						if not defensive and not reaction and not benignMove then
							kind = kindFromName(child.Name)
							if not kind and isStyleFolder then kind = "SKILL" end
						end
						local id = animIdOf(child)
						if id and defensive then _D.BlockIds[id] = true end
						if kind and id then
							_D.AttackIds[id] = {
								kind = kind,
								combo = (kind == "M1") and comboFromName(child.Name) or nil,
								name = child.Name,
								mom = lname:find("momentum") ~= nil,
							}
						end
					end
				end
			end
		end
			for _, d in ipairs(anims:GetDescendants()) do
				if d:IsA("Animation") then
					local id = tonumber(tostring(d.AnimationId):match("(%d+)"))
					if id then
						if looksDefensive(d.Name) or (d.Parent and looksDefensive(d.Parent.Name)) then
							_D.BlockIds[id] = true
						end
						if not _D.AttackIds[id] and not _D.BlockIds[id] then
							local lname = d.Name:lower()
							if not (lname:find("ehit") or lname:find("success"))
								and (lname:find("crit") or lname:find("momentum")
									or lname:find("slam") or lname:find("special") or lname:find("finisher")) then
								_D.AttackIds[id] = { kind = "SKILL", combo = nil }
							end
						end
					end
				end
			end
	end)
	for id, v in pairs(_D.LEGACY_ATTACKS) do
		if not _D.AttackIds[id] then _D.AttackIds[id] = { kind = v.t, combo = nil } end
	end
end

local function attackEntry(id)
	return _D.AttackIds[id]
end

GameData.m2VarCache = {}
GameData.m2VariantId = function(style, animName)
	if type(animName) ~= "string" or animName == "" then return nil end
	local ck = tostring(style):lower() .. "|" .. animName
	local c = GameData.m2VarCache[ck]
	if c ~= nil then return c or nil end
	local out = false
	loadGameModules()
	if GameData.cfg and GameData.cfg.GetStyleM2Variants then
		pcall(function()
			local vs = GameData.cfg.GetStyleM2Variants(style)
			if type(vs) ~= "table" then return end
			for id, v in pairs(vs) do
				if type(v) == "table" and v.Anim == animName then out = id; return end
			end
			local ln = animName:lower()
			for id in pairs(vs) do
				local lid = tostring(id):lower()
				if #lid > 0 and ln:find(lid, 1, true) then out = id; return end
			end
		end)
	end
	if out == false then out = _D.LEGACY_M2_VARIANT[animName] or false end
	GameData.m2VarCache[ck] = out
	return out or nil
end

-- Нормализованная проверка стиля Boxing. Вынесена в функцию, потому что gsub
-- возвращает ДВА значения, и инлайн внутри конструктора таблицы легко ломается.
local function isBoxingStyle(style)
	local s = string.lower(tostring(style or "")):gsub("[%s_%-]", "")
	return s:sub(1, 6) == "boxing"
end

local resolveInfo = function(id, model)
	local entry  = _D.AttackIds[id]
	if not entry then return nil end
	local legacy = _D.LEGACY_ATTACKS[id]
	local kind = entry.kind
	local rk = registryKind and registryKind(model, id)
	if rk == "M1" or rk == "M2" then kind = rk end
	local style = styleOf(model) or (legacy and legacy.s) or "Basic"
	local variant = nil
	if kind == "M2" then
		if model then
			local okv, av = pcall(function() return model:GetAttribute("M2VariantId") end)
			if okv and type(av) == "string" and av ~= "" then variant = av end
		end
		if not variant then
			variant = GameData.m2VariantId(style, entry and entry.name) or (legacy and legacy.v) or nil
		end
	end
	return {
		t     = kind,
		s     = style,
		id    = id,
		hit   = entry.hit,
		-- Мультихит Boxing M2 (2 контакта). Сравнение было строгим равенством с
		-- сырым string.lower(style). Для чистого "Boxing" оно работает, но
		-- styleOf() берёт строку из игры (функция стиля / атрибут модели), и
		-- варианты вида "BoxingAnims"/"Boxing_Style" в равенство не попадали →
		-- contacts=nil → ветка MULTI вообще не создавала вторую угрозу.
		-- Матчим по нормализованному ПРЕФИКСУ: ни один другой стиль в таблицах
		-- (ali/kure/karate/…/striker) с "boxing" не начинается, ложных срабатываний нет.
		-- styleKey() объявлен НИЖЕ этой функции, поэтому нормализуем на месте.
		contacts = (kind == "M2" and isBoxingStyle(style)) and V93.boxingM2Contacts or nil,
		combo = entry and entry.combo or (legacy and legacy.c) or nil,
		mom   = (entry and entry.mom) or (legacy and legacy.mom) or false,
		name  = entry and entry.name or nil,
		variant = variant,
	}
end

-- Нормализация ключа стиля для LEGACY-таблиц.
-- Папка анимаци�� зовётся "HakariOtherAnims_Folder", а ключи в та��лицах — "hakario";
-- без алиаса "hakariother" не находился и молча падал в дефолт 0.32/0.30.
_D.STYLE_ALIAS = {
	hakariother = "hakario", hakarialt = "hakario", hakario = "hakario",
	wing = "wingchun", wingchun = "wingchun", ["wing chun"] = "wingchun",
	-- ВНИМАНИЕ: "base" НЕ алиас для "basic" — это разные ��аборы (BaseCombat_Folder
	-- vs BasicAnims_Folder) с разными задержками: base 0.32 без оффсетов, basic +0.02.
}
local function styleKey(s)
	local sl = string.lower(tostring(s or "")):gsub("[%s_%-]", "")
	return _D.STYLE_ALIAS[sl] or sl
end

-- Есть ли у стиля СВОЙ блок в живом CombatConfig.
-- Нужно потому, что GetStyleConfig() делает `Styles[key] or Styles.default` и для
-- незнакомого стиля не сообщает об этом никак — просто отдаёт чужие числа.
local function cfgKnowsStyle(style)
	loadGameModules()
	local c = GameData.cfg
	if not c then return false end
	local ok, styles = pcall(function() return c.Styles end)
	if not ok or type(styles) ~= "table" then
		-- Таблицу не видно (другая версия/обфускация) → считаем, что конфиг знает,
		-- и ничего не переопределяем. Безопасный вариант по умолчанию.
		return true
	end
	local key = style
	if type(c.NormalizeStyleKey) == "function" then
		local okk, k = pcall(c.NormalizeStyleKey, style)
		if okk and k ~= nil then key = k end
	end
	return styles[key] ~= nil
end

local function hitTimelineBase(info, combo)
	if info.t == "SKILL" then
		if info.hit and info.hit > 0 then return info.hit end
		return 0.35
	end
	-- ══════════════════════════════════════════════════════════════════════════
	-- ЗАМЕРЕННАЯ ЗАДЕРЖКА — ТОЛЬКО ДЛЯ СТИЛЕЙ, КОТОРЫХ НЕТ В КОНФИГЕ.
	-- ──────────────────────────────────────────────────────────────────────────
	-- GetStyleConfig() внутри делает `Styles[key] or Styles.default`, то есть для
	-- неизвестного стиля МОЛЧА от��аёт дефолт. Именно это и происходит со Striker:
	-- его блока в конфиге нет (в дампе слово "striker" не встречается ни разу),
	-- поэтому M2 приходит как дефолтные 0.30, а сервер по логу V176 ставит хитбокс
	-- на 437 и 441мс при aMult=1.05 → реальная задержка 0.449. Ошибка -140мс.
	--
	-- Обратный порядок (таблица важнее конфига) был бы опаснее: задержки живут в
	-- конфиге, а не в анимации, поэтому игра может изменить тайминг НЕ меняя ID —
	-- и захардкоженное значение молча перебило бы правильное живое. Поэтому
	-- таблица применяется строго там, где конфиг заведомо ничего не знает.
	if info.id and not cfgKnowsStyle(info.s) then
		local le0 = _D.LEGACY_ATTACKS[info.id]
		-- d в этих записях замерено ПО СЕРВЕРУ уже с нужным combo-оффсетом
		-- (запись привязана к конкретной анимации, а значит к конкретному удару
		-- серии), поэтому LEGACY_M1_OFFSETS здесь добавлять НЕЛЬЗЯ.
		if le0 and le0.t == info.t and type(le0.d) == "number" then
			return le0.d + _D.WINDUP_EXTRA
		end
	end
	if info.t == "M2" then
		loadGameModules()
		local cfgv, multi = nil, 1
		if GameData.cfg then
			local ok, d = pcall(function()
				return GameData.cfg.GetStyleM2HitboxDelay(info.s, info.mom, info.variant)
			end)
			if ok and type(d) == "number" then cfgv = d + _D.WINDUP_EXTRA end
			local okc, mc = pcall(function() return GameData.cfg.GetStyleNumber(info.s, "M2MultiHitCount", 1) end)
			if okc and type(mc) == "number" then multi = mc end
		end
		if not cfgv then
			local sl = styleKey(info.s)
			local le = info.id and _D.LEGACY_ATTACKS[info.id] or nil
			if le and le.t == "M2" and type(le.d) == "number" then
				cfgv = le.d + _D.WINDUP_EXTRA
			elseif info.mom and _D.LEGACY_M2_MOM_BASE[sl] then
				cfgv = _D.LEGACY_M2_MOM_BASE[sl] + _D.WINDUP_EXTRA
			else
				cfgv = (_D.LEGACY_M2_BASE[sl] or 0.30) + _D.WINDUP_EXTRA
			end
		end
		if multi > 1 and info.hit and info.hit > 0 then
			return cfgv
		end
		return cfgv
	end

	loadGameModules()
	if GameData.cfg then
		local ok, d = pcall(function() return GameData.cfg.GetScaledStyleM1HitboxDelay(info.s, combo or 1, 1) end)
		if ok and type(d) == "number" then return d end
	end
	local sl   = styleKey(info.s)
	local base = _D.LEGACY_M1_BASE[sl] or 0.32
	local off  = _D.LEGACY_M1_OFFSETS[sl]
	if off then base = base + (off[math.clamp(combo or 1, 1, 4)] or 0) end
	return base + _D.WINDUP_EXTRA
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ГЛАВНЫЙ ФИКС ТАЙМИНГОВ
-- ──────────────────────────────────────────────────────────────────────────────
-- Игра (M1_ModuleScript / M2_ModuleScript) ставит хитбокс так:
--     track:AdjustSpeed(CombatPingAnimUtils.GetFinalAnimSpeed(delay, heightMult, ping))
--     где speed = heightMult * (delay / (delay + clamp(ping/2, 0, 0.35)))
-- и затем ждёт достижения ФИКСИРОВАННОЙ позиции анимации delay (+windup).
-- Т.е. КОНТАКТ ВСЕГДА НА О��НОЙ И ТОЙ ЖЕ ANIM-ПОЗИЦИИ, а вся разница по росту и
-- пингу уже сидит внутри track.Speed.
--
-- Было (баг): hitTL = base / heightMult  → wall-время, БЕЗ учёта ping-компенсации,
-- и потом сравнивалось с track.TimePosition (это anim-время!) — смешение единиц.
-- При пинге 200 мс скрипт считал удар на ~100 мс раньше, пр�� 700 мс — на 350 мс.
-- Из-за этого нажатие уходило РАНЬШЕ окна перфект-блока → игра выдавала обычный
-- блок вместо парирования. Ровно жалоба "иногда блокирует, а не парирует".
--
-- Стало: hitTimeline возвращает ANIM-время контакта (как в игре), а перевод в
-- реальное время делает animToWall() деление�� на живой track.Speed.
-- ═════════════════════════════��══════════════�����═════════════════════════════════
local function hitTimeline(info, combo, mult, contactBase)
	local base = contactBase or hitTimelineBase(info, combo)
	-- Игра: GetScaledHitboxDelay(d, m) = d/max(0.05,m) + extra/max(0.05,m)
	--                                  = (d + HitboxWindupExtra) / m
	-- extra=0.012 применяется к КАЖДОЙ атаке (M1, M2, скиллы) без исключений.
	-- Без него мы стабильно ждали удар на 12мс раньше, чем он приходит.
	-- ══════════════════════════════════════════════════════════════════════════
	-- ИСПРАВЛЕНО: windup прибавлялся ДВАЖДЫ, и деление на aMult не делалось.
	-- ─────────────────────────────────��────────────────────────────────────────
	-- Доказано по дампу: GetScaledHitboxDelay(d, m) = d/m + windup/m, то есть
	-- windup УЖЕ ВНУТРИ. А GetScaledStyleM1HitboxDelay вызыв��ет её же, поэтому
	-- значение из конфига приходит с windup. Строка ниже добавляла его второй раз.
	-- M2-ветка так же делала `d + WINDUP_EXTRA`, и здесь набегал второй.
	--
	-- Сверка с логом V176 (все 5 совпали ДО МИЛЛИСЕКУНДЫ, windup=0.012):
	--   Capoeira M2   0.450 + w + w = 474ms  == hitTL 474
	--   Basic M2      0.525 + w + w = 549ms  == hitTL 549
	--   Karate M2     0.4875+ w + w = 511ms  == hitTL 511
	--   Basic M1 c1   0.34  + w + w = 364ms  == hitTL 364
	--   Capoeira M1c3 0.35  + w + w = 374ms  == hitTL 374
	--
	-- Второе: хитбокс — ТАЙМЕР, ждущий (d+windup)/aMult РЕАЛЬНЫХ секунд. Раньше
	-- AnimTimeModel возвращал значение как аним-время и делил его дальше на живой
	-- track.Speed — а он у реплицированной анимации атакующего РОВНО 1.00 (в логе
	-- V176 все 707 строк: spd=1.00). Значит aMult не применялся вообще.
	--
	-- Замер по 9 ударам с известной задержкой против серверного hbFirst:
	--   было (аним-таймлайн)   : медиана +31ms, |ош|ср 27.3ms
	--   стало (d+w)/aMult      : медиана  +3ms, |ош|ср  7.4ms
	local m = (type(mult) == "number" and mult > 0.05) and mult or 1
	return base / math.max(0.05, m)
end

-- Эффективная скорость прои��рывания анимации атакующего.
-- Приоритет: живой track.Speed (в нём уже и рост, и ping-компенсация атакующего).
-- Фолбэк (трека нет / мусорное значение): heightMult * ping-компенсация по нашему
-- пингу как приближение — лучше, чем игнорировать компенсацию совсем.
-- ПОБИТОВАЯ КОПИЯ CombatPingAnimUtils.GetPingAnimSpeedMultiplier:
--   if delay <= 0 then return 1
--   v = player:GetNetworkPing(); if not num/nan/<=0 then return 1
--   return delay / (delay + clamp(v * 0.5, 0, MaxEstimatedOneWaySeconds))
-- БАГ (был): з��есь использовался getPingRaw(), который СМЕШИВАЕТ GetNetworkPing
-- со Stats "Data Ping" и бе����ёт math.max(). Игра же читает ИСКЛЮЧИТЕЛЬНО
-- GetNetworkPing() и только у LocalPlayer (проверено: все вызовы в M1/M2/Skill
-- передают LocalPlayer). Когда Stats-пинг выше (обычное дело), мы считали
-- анимацию МЕДЛЕННЕЕ, чем она есть, и жали ПОЗЖЕ.
-- Пример: GetNetworkPing=0.10, Stats=0.25, contact=0.4 →
--   игра: 0.4/(0.4+0.05)=0.889 → удар через 450мс
--   было: 0.4/(0.4+0.125)=0.762 → ждали 525мс  ⇒ опоздание 75мс = гарантированный промах окна 125мс
local function gamePingAnimMult(animContact)
	if type(animContact) ~= "number" or animContact <= 0 then return 1 end
	local ok, v = pcall(function() return LocalPlayer:GetNetworkPing() end)
	if not ok or type(v) ~= "number" or v ~= v or v <= 0 then return 1 end
	local cap = GameData.animPingCap or Config.AnimPingCompMax or 0.35
	return animContact / (animContact + math.clamp(v * 0.5, 0, cap))
end

local function effAnimSpeed(track, aMult, animContact)
	local sp
	if track then
		local ok, v = pcall(function() return track.Speed end)
		if ok and type(v) == "number" then sp = v end
	end
	if type(sp) == "number" and sp >= (Config.SpeedSanityMin or 0.2)
		and sp <= (Config.SpeedSanityMax or 3.0) then
		return sp, "live"
	end
	local m = (type(aMult) == "number" and aMult > 0.05) and aMult or 1
	local d = (type(animContact) == "number" and animContact > 0.01) and animContact or 0.32
	local comp = gamePingAnimMult(d)
	return math.clamp(m * comp, Config.SpeedSanityMin or 0.2, Config.SpeedSanityMax or 3.0), "predict"
end

-- УДАЛЕНО: hitboxTimerDiv. Деление на aMult теперь ровно в одном месте —
-- в hitTimeline(). Прошлая версия пыталась выбрать между track.Speed и aMult по
-- условию `sp >= aMult * 0.9`, и это была ошибка: track.Speed у реплицированной
-- анимации ВСЕГДА 1.00 (лог V176, все 707 строк), поэтому при aMult <= 1/0.9 =
-- 1.111 условие выполнялось и деление молча не происходило. По логу это ровно
-- 52 свинга из 68 (aMult 0.96/1.05/1.07) шли без деления, а 16 (aMult 1.11+) с
-- делением — то есть предикт разъезжался на ~50мс между соседними ударами.

-- Скорость, с которой РЕАЛЬНО тикает TimePosition. Нужна отдельно от делителя
-- таймера: tp переводим в прошедшее реальное время именно ею.
local function tpSpeed(track)
	if track then
		local ok, v = pcall(function() return track.Speed end)
		if ok and type(v) == "number"
			and v >= (Config.SpeedSanityMin or 0.2)
			and v <= (Config.SpeedSanityMax or 3.0) then
			return v
		end
	end
	return 1
end

-- ANIM-время → реальное (wall) время
local function animToWall(animDelta, track, aMult, animContact)
	local sp = effAnimSpeed(track, aMult, animContact)
	return animDelta / sp
end

-- ОБУЧЕННЫЙ СДВИГ КОНТАКТА (замыкание обратной связи по скрытому пол-пингу).
-- Возвращает СЕКУНДЫ (>=0), на которые реальный контакт этого атакующего ПОЗЖЕ
-- аним-прогноза. Источник — измеренный per-attacker остаток predErr (см. onOutcome).
-- Новый атакующий берёт глобальны�� EMA, а до первых замеров — консервативный приор.
local function residContactBias(th)
	if not th or Config.ResidComp == false then return 0 end
	local minN = Config.ResidCompMinN or 6
	local rec = th.name and _D.ResidByAtk[th.name]
	local ms
	-- Берём источник, у которого выборка уже прогрелась. Недогретый исто��ник даёт
	-- сдвиг 0 (лучше не двигать вовсе, чем двигать по одному шумному замеру).
	if rec and rec.n and rec.n >= minN and rec.sum then
		ms = rec.sum / rec.n
	elseif _D.ResidGlobal.n and _D.ResidGlobal.n >= minN and _D.ResidGlobal.sum then
		ms = _D.ResidGlobal.sum / _D.ResidGlobal.n
	else
		ms = Config.ResidCompSeedMs or 0
	end
	if ms < (Config.ResidCompMinMs or -20) then ms = Config.ResidCompMinMs or -20 end
	local s = (ms / 1000) * (Config.ResidCompShrink or 0.5)
	if s < 0 then s = 0 end
	local cap = Config.ResidCompMax or 0.045
	if s > cap then s = cap end
	th.residBias = s
	return s
end

_C.fwdFn = function(st, k) return GameData.cfg.GetStyleHitboxForwardOffset(st, k) end
_C.fwdCache = {}
function styleForward(style, kind)
	local ck = tostring(style) .. "|" .. tostring(kind)
	local hit = _C.fwdCache[ck]
	if type(hit) == "number" then return hit end
	if hit == false then
		return (kind == "M2" or kind == "SKILL") and Config.M2Forward or Config.M1Forward
	end
	loadGameModules()
	if GameData.cfg then
		local ok, f = pcall(_C.fwdFn, style, kind)
		if ok and type(f) == "number" then _C.fwdCache[ck] = f; return f end
		_C.fwdCache[ck] = false
	end
	return (kind == "M2" or kind == "SKILL") and Config.M2Forward or Config.M1Forward
end

_C.stepCache = {}
function styleStepForward(style, kind, combo)
	local ck = tostring(style) .. "|" .. tostring(kind) .. "|" .. tostring(combo or 1)
	local v = _C.stepCache[ck]
	if type(v) == "number" then return v end
	if v == false then return 0 end
	loadGameModules()
	local out = nil
	if GameData.cfg then
		pcall(function()
			if kind == "M1" then
				if GameData.cfg.GetStyleM1StepForwardStuds then
					out = GameData.cfg.GetStyleM1StepForwardStuds(style, combo or 1)
				end
			elseif GameData.cfg.GetStyleM2StepForwardStuds then
				out = GameData.cfg.GetStyleM2StepForwardStuds(style)
			end
		end)
	end
	if type(out) ~= "number" then
		local sl = string.lower(tostring(style))
		if sl == "ali" then
			out = (kind == "M1") and (((combo == 1) or (combo == 3)) and 1.5 or 0) or 2
		else
			out = nil
		end
	end
	if type(out) ~= "number" then _C.stepCache[ck] = false; return 0 end
	out = math.clamp(out, 0, 8)
	_C.stepCache[ck] = out
	return out
end

-- velLead = насколько РАНЬШЕ произойдёт касание из-за того, что атакующий
-- сближается с нами во время замаха. Это поправка к ВРЕМЕНИ КОНТАКТА.
--
-- БЫЛО: брался МОДУЛЬ скорости атакующего, без направления. Любое движение —
-- вбок, по кругу, ОТ нас — давало полный velLead=45мс. В диаге это видно прямо:
-- av=(-0.1,-29.6) при mv=(0,0) → vlead=45мс, хотя сближения нет вообще.
-- Последствие ровно то, на что жалоба: сервер видит наш�� нажатие за
-- (lead + velLead) до касания, 61+45=106мс плюс систематическая ошибка ~30мс
-- = ~136мс > окна 125мс → ОБЫЧНЫЙ БЛОК ВМЕСТО ПАРРИ. По логу корреляция стопро-
-- центная: velLead>=24мс → guard=EARLY(>125), velLead<=8мс → guard=IN-WINDOW.
--
-- СТАЛО: проекция ОТНОСИ��ЕЛЬНОЙ скорости (его минус наша) на направление к нам.
-- Сближается → положительная поправка; идёт вбок или от нас → ровно 0.
local function velLead(hrp)
	local me = localHRP()
	if not me or not hrp then return 0 end
	local closing = 0
	local ok = pcall(function()
		local toMe = me.Position - hrp.Position
		local flat = Vector3.new(toMe.X, 0, toMe.Z)
		if flat.Magnitude < 0.1 then return end
		local dir = flat.Unit
		local av = hrp.AssemblyLinearVelocity
		local mv = me.AssemblyLinearVelocity
		local rel = Vector3.new(av.X - mv.X, 0, av.Z - mv.Z)
		closing = rel:Dot(dir)
	end)
	if not ok or closing <= 0 then return 0 end
	return math.clamp(closing / Config.MoveSpeedFull, 0, 1) * Config.MoveLeadMax
end

-- Оценка систематической невязки серверного зазора (в СЕКУНДАХ, знак «+» = сервер
-- видит блок раньше, чем мы рассчитывали, т.е. надо уменьшить lead).
-- Учится из измеренного blockGap true, устойчивым средним с прогревом.
local function gapBiasEst()
	if Config.GapBiasComp == false then return 0 end
	local g = _D.GapBias
	if not g or (g.n or 0) < (Config.GapBiasMinN or 6) then return 0 end
	local ms = (g.sum / g.n) * (Config.GapBiasShrink or 0.7)
	local cap = Config.GapBiasCapMs or 60
	if ms > cap then ms = cap elseif ms < -cap then ms = -cap end
	return ms / 1000
end

local function gapBiasLearn(errMs)
	if Config.GapBiasComp == false or type(errMs) ~= "number" then return end
	if errMs < (Config.GapBiasLoMs or -60) or errMs > (Config.GapBiasHiMs or 120) then return end
	local g = _D.GapBias
	if not g then g = { sum = 0, n = 0 }; _D.GapBias = g end
	local winN = Config.GapBiasWinN or 40
	g.sum, g.n = g.sum + errMs, g.n + 1
	if g.n > winN then g.sum = g.sum * (winN / g.n); g.n = winN end
	g.ms = g.sum / g.n
end

local Debris = game:GetService("Debris")
local AnimLib = { tracks = {}, dashCache = {}, blockAnim = nil, handler = nil, resolvedHandler = false }

local function looksLikeHandler(t)
	return type(t) == "table"
		and type(rawget(t, "LoadAnim"))  == "function"
		and type(rawget(t, "GetAnims"))  == "function"
		and type(rawget(t, "IsAnim"))    == "function"
		and type(rawget(t, "StopAnim"))  == "function"
		and type(rawget(t, "Anims"))     == "table"
end

AnimLib.handlers    = {}
AnimLib._handlerSet = setmetatable({}, { __mode = "k" })

local function addHandler(t)
	if not t or AnimLib._handlerSet[t] then return false end
	AnimLib._handlerSet[t] = true
	AnimLib.handlers[#AnimLib.handlers + 1] = t
	return true
end

_C.handlerNextScan = 0
local function scanAllHandlers()
	local now = os.clock()
	if now < _C.handlerNextScan then return AnimLib.handlers end
	_C.handlerNextScan = now + 2

	pcall(function()
		local pkgs = ReplicatedStorage:FindFirstChild("Packages")
		local mod  = pkgs and pkgs:FindFirstChild("AnimationHandler")
		if mod then
			local ok, ret = pcall(require, mod)
			if ok and looksLikeHandler(ret) then addHandler(ret) end
		end
	end)

	if type(getgc) ~= "function" and type(filtergc) ~= "function" then
		if not AnimLib._gcWarned then
			AnimLib._gcWarned = true
			if aclog then aclog("[DESYNC] no getgc/filtergc — executor can't recover the hidden AnimationHandler") end
		end
		return AnimLib.handlers
	end

	local scanned, before = 0, #AnimLib.handlers
	if type(getgc) == "function" then
		pcall(function()
			for _, obj in pairs(getgc(true)) do
				scanned = scanned + 1
				if looksLikeHandler(obj) then addHandler(obj) end
			end
		end)
	end
	if #AnimLib.handlers == 0 and type(filtergc) == "function" then
		pcall(function()
			local scan = filtergc("table", { Keys = { "LoadAnim", "GetAnims", "IsAnim", "StopAnim", "Anims" } })
			if looksLikeHandler(scan) then addHandler(scan)
			elseif type(scan) == "table" then
				for _, obj in pairs(scan) do if looksLikeHandler(obj) then addHandler(obj) end end
			end
		end)
	end

	local added = #AnimLib.handlers - before
	if #AnimLib.handlers > 0 then
		AnimLib.resolvedHandler = true
		if added > 0 and aclog then
			aclog(string.format("[DESYNC] GC scan: %d AnimationHandler instance(s) live (walked %d objects, +%d new)", #AnimLib.handlers, scanned, added))
		end
	elseif aclog and not AnimLib._scanLogged then
		AnimLib._scanLogged = true
		aclog(string.format("[DESYNC] GC scan: walked %d objects, no AnimationHandler yet (will retry)", scanned))
	end
	return AnimLib.handlers
end

local function getHandler()
	if #AnimLib.handlers == 0 then scanAllHandlers() end
	local lc = localChar()
	if lc then
		for _, h in ipairs(AnimLib.handlers) do
			local hasOurs = false
			pcall(function() hasOurs = rawget(h, "Anims")[lc] ~= nil end)
			if hasOurs then AnimLib.handler = h; return h end
		end
	end
	AnimLib.handler = AnimLib.handlers[1]
	return AnimLib.handler
end

function registryKind(model, id)
	if not model then return nil end
	if #AnimLib.handlers == 0 then getHandler() end
	for _, h in ipairs(AnimLib.handlers) do
		if type(rawget(h, "GetAnims")) == "function" then
			local cats
			local ok = pcall(function() cats = h.GetAnims(model) end)
			if ok and type(cats) == "table" then
				for catName, entries in pairs(cats) do
					if type(catName) == "string" and type(entries) == "table" then
						for key, entry in pairs(entries) do
							local kid = tonumber(tostring(key):match("(%d+)"))
							if not kid and type(entry) == "table" and entry.Track then
								pcall(function()
									local a = entry.Track.Animation
									if a then kid = tonumber(tostring(a.AnimationId):match("(%d+)")) end
								end)
							end
							if kid == id then
								if catName == "M1" then return "M1" end
								if catName == "M2" or catName == "WrestlingM2" then return "M2" end
								return catName
							end
						end
					end
				end
			end
		end
	end
	return nil
end

local function getAnimator()
	local c = localChar()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	return hum:FindFirstChildOfClass("Animator") or hum
end

local function findAnimByName(root, wanted)
	local found
	pcall(function()
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Animation") and d.Name == wanted then found = d; break end
		end
	end)
	return found
end

local function resolveBlockAnim()
	if AnimLib.blockAnim and AnimLib.blockAnim.Parent then return AnimLib.blockAnim end
	local a
	pcall(function()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local utils  = shared and shared:FindFirstChild("Utils")
		local mod    = utils and utils:FindFirstChild("CombatAnimationUtils")
		if mod then
			local CAU = require(mod)
			local folder = CAU.GetCombatAnimsFolderForPlayer(LocalPlayer)
			if folder then a = folder:FindFirstChild("Blocking") end
		end
	end)
	if not a then
		local anims = ReplicatedStorage:FindFirstChild("Animations") or ReplicatedStorage:FindFirstChild("Animations_Folder")
		if anims then a = findAnimByName(anims, "Blocking") end
	end
	AnimLib.blockAnim = a
	return a
end

local function playBlockAnim()
	if not Config.LegitAnims then return end
	if os.clock() < (State.swingAnimUntil or 0) then return end
	local char = localChar()
	local anim = resolveBlockAnim()
	if not char or not anim then return end

	local h = getHandler()
	if h and h.LoadAnim then
		local ok, tr = pcall(function() return h.LoadAnim(char, "Blocking", anim, nil, false) end)
		if ok and tr then
			local oldTr = AnimLib.tracks.Blocking
			AnimLib.tracks.Blocking = tr
			pcall(function() if oldTr and oldTr ~= tr and oldTr.Destroy then oldTr:Destroy() end end)
			pcall(function() if not tr.IsPlaying then tr:Play(0.08) end end)
			return
		end
	end
	local animator = getAnimator()
	if not animator then return end
	local tr = AnimLib.tracks.Blocking
	if not tr or not tr.IsPlaying then
		pcall(function()
			if not tr then
				local oldTr = AnimLib.tracks.Blocking
				tr = animator:LoadAnimation(anim); AnimLib.tracks.Blocking = tr
				pcall(function() if oldTr and oldTr ~= tr and oldTr.Destroy then oldTr:Destroy() end end)
			end
			tr.Priority = Enum.AnimationPriority.Action
			if not tr.IsPlaying then tr:Play(0.08) end
		end)
	end
end

local function stopBlockAnim()
	local char = localChar()
	local h = getHandler()
	if char and h and h.StopAnim then
		pcall(function() h.StopAnim(char, "Blocking", nil, 0.08) end)
	end
	local tr = AnimLib.tracks.Blocking
	if tr then pcall(function() tr:Stop(0.08) end) end
end

local function dashAnimMix(hrp, moveDir)
	local flat = Vector3.new(moveDir.X, 0, moveDir.Z)
	if flat.Magnitude < 0.05 then return { "DashBack" } end
	local u     = flat.Unit
	local fwd   = hrp.CFrame.LookVector;  fwd   = Vector3.new(fwd.X, 0, fwd.Z)
	local right = hrp.CFrame.RightVector; right = Vector3.new(right.X, 0, right.Z)
	if fwd.Magnitude < 0.05 then return { "DashBack" } end
	local ang = math.deg(math.atan2(u:Dot(right.Unit), u:Dot(fwd.Unit)))
	if ang > -22.5 and ang <= 22.5   then return { "DashFront" } end
	if ang > 22.5  and ang <= 67.5   then return { "DashFront", "DashRight" } end
	if ang > 67.5  and ang <= 112.5  then return { "DashRight" } end
	if ang > 112.5 and ang <= 157.5  then return { "DashBack", "DashRight" } end
	if ang > 157.5 or  ang <= -157.5 then return { "DashBack" } end
	if ang > -157.5 and ang <= -112.5 then return { "DashBack", "DashLeft" } end
	if ang > -112.5 and ang <= -67.5 then return { "DashLeft" } end
	return { "DashFront", "DashLeft" }
end

local function resolveDashAnim(name)
	if AnimLib.dashCache[name] and AnimLib.dashCache[name].Parent then return AnimLib.dashCache[name] end
	local a
	local anims = ReplicatedStorage:FindFirstChild("Animations") or ReplicatedStorage:FindFirstChild("Animations_Folder")
	if anims then
		local mv = anims:FindFirstChild("Movement")
		if mv then a = mv:FindFirstChild(name) end
		if not a then a = findAnimByName(anims, name) end
	end
	AnimLib.dashCache[name] = a
	return a
end

local function playDodgeMotion(dirOverride, speedOverride)
	if not Config.LegitAnims then return end
	local hrp = localHRP()
	if not hrp then return end
	local c   = localChar()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local moveDir = (hum and hum.MoveDirection) or Vector3.new()
	if dirOverride and dirOverride.Magnitude > 0.05 then
		moveDir = Vector3.new(dirOverride.X, 0, dirOverride.Z)
	end
	local mix = dashAnimMix(hrp, moveDir)

	local h = getHandler()
	local playedViaHandler = false
	if c and h and h.LoadAnim then
		pcall(function() h.StopAnim(c, "Evasive", nil, 0.05) end)
		local tracks = {}
		for _, name in ipairs(mix) do
			local anim = resolveDashAnim(name)
			if anim then
				local ok, tr = pcall(function() return h.LoadAnim(c, "Evasive", anim, nil, false) end)
				if ok and tr then tracks[#tracks+1] = tr end
			end
		end
		if #tracks == 2 then
			pcall(function() tracks[1]:AdjustWeight(0.5, 0.05); tracks[2]:AdjustWeight(0.5, 0.05) end)
		end
		playedViaHandler = #tracks > 0
	end
	if not playedViaHandler then
		local animator = getAnimator()
		if animator then
			for _, name in ipairs(mix) do
				local anim = resolveDashAnim(name)
				if anim then
					pcall(function()
						local tr = animator:LoadAnimation(anim)
						tr.Priority = Enum.AnimationPriority.Action2
						tr:Play(0.05, #mix == 2 and 0.5 or 1)
					end)
				end
			end
		end
	end

	pcall(function()
		local oldV = hrp:FindFirstChild("EvasiveDashLinearVelocity"); if oldV then oldV:Destroy() end
		local oldA = hrp:FindFirstChild("EvasiveDashAttachment");     if oldA then oldA:Destroy() end
		hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
		local flat = Vector3.new(moveDir.X, 0, moveDir.Z)
		local dir  = (flat.Magnitude > 0.001) and flat.Unit or (-hrp.CFrame.LookVector)
		local att  = Instance.new("Attachment"); att.Name = "EvasiveDashAttachment"; att.Parent = hrp
		local lv   = Instance.new("LinearVelocity"); lv.Name = "EvasiveDashLinearVelocity"
		lv.MaxForce = 100000
		lv.VectorVelocity = dir * math.min(speedOverride or Config.DashSpeed, Config.DashSpeed)
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = hrp
		Debris:AddItem(att, Config.DashDuration)
		Debris:AddItem(lv, Config.DashDuration)
	end)
end

local function spoofStamp(tsServer)
	if not Config.TimeSpoof then return tsServer end
	local shift = (Config.TimeShiftMs or 0) / 1000
	if shift <= 0 then return tsServer end
	return tsServer - shift
end

local function sendActivate(tsServer)
	local now = os.clock()
	if now - State.lastAct < Config.MinActGap then return false end
	State.lastAct = now
	local c = localChar()
	if c then c:SetAttribute("Blocking", true) end
	ServerRemote:FireServer(
		{ Type = "Combat", Action = "Block", Func = "Activated" },
		spoofStamp(tsServer)
	)
	State.guardUp = true
	playBlockAnim()
	return true
end

local function sendDeactivate(force)
	local now = os.clock()
	if not force and now - State.lastDeact < Config.MinDeactGap then return false end
	State.lastDeact = now
	local c = localChar()
	if c then c:SetAttribute("Blocking", nil) end
	ServerRemote:FireServer({ Type = "Combat", Action = "Block", Func = "Deactivated" })
	State.guardUp = false
	stopBlockAnim()
	return true
end

local function sendDodge(dir, speedOverride)
	if State.guardUp or State.blocking then
		State.blocking, State.holdUntil = false, 0
		sendDeactivate(true)
		stopBlockAnim()
	end
	ServerRemote:FireServer({ Type = "Combat", Action = "Evasive", Func = "Evasive" })
	playDodgeMotion(dir, speedOverride)
	State.lastDodge  = os.clock()
	State.dodgeCount = State.dodgeCount + 1
	State.flashUntil = os.clock() + 0.25
	State.status     = "DODGE"
	return true, nil
end

_D.BOXING_BLOCK_ATTRS = {
	"CombatAttacking", "Stunned", "Ragdoll",
	"ParryAttackLockout", "BlockAttackLockout",
}

local function counterStyle()
	local c = localChar()
	if not c then return nil end
	local st = (styleOf and styleOf(c) or ""):lower()
	if st == "" then return nil end
	if st == "boxing" then return Config.BoxingCounter and "boxing" or nil end
	if st == "ali"    then return Config.AliCounter    and "ali"    or nil end
	if styleKey(st) == "wingchun" then
		return Config.WingChunCounter and "wingchun" or nil
	end
	return nil
end

-- Стартап окна: калиброванный по ACK (если есть выборка) или VFX-оценка.
local function wcStartup()
	-- ФИКСИРОВАННЫЙ стартап стойки Wing Chun (VFX StartupFrame=7 @60fps = 117мс).
	-- Авто-калиб��овку (startupEma) убрали: она дрейфила по одному-двум ack и уводила
	-- окно, отсюда «Wing Chun не таймился / срабатывал поздно». Пинг-компенсация
	-- делается отдельно в wcDecide через uplink(), здесь — чистая игровая константа.
	local base = Config.WCStartup or _D.WINGCHUN.StartupSecs or (7 / 60)
	return math.clamp(base, 0.02, 0.9)
end

local function steerM2Variant(want)
	local c = localChar(); if not c then return end
	local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local hrp = localHRP(); if not hrp then return end
	local dir
	if want == "Right" then dir = hrp.CFrame.RightVector else dir = hrp.CFrame.LookVector end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.05 then return end
	State.ap.steerDir   = dir.Unit
	State.ap.steerUntil = os.clock() + (Config.AliVariantSteerDur or 0.15)
	pcall(function() hum:Move(State.ap.steerDir, false) end)
end

local function counterReady()
	if not Config.SkillAddon then return false, "SkillAddon-off" end
	local c = localChar()
	if not c then return false, "no-character" end
	local cs = counterStyle()
	if not cs then return false, "counter-style-disabled" end
	if (os.clock() - (State.lastCounter or 0)) < (Config.BoxingCounterGap or 0.30) then
		return false, "BoxingCounterGap"
	end
	for _, attr in ipairs(_D.BOXING_BLOCK_ATTRS) do
		if c:GetAttribute(attr) then return false, attr end
	end
	if c:GetAttribute("CantAnything") and not c:GetAttribute("CombatRecovery") then
		return false, "CantAnything"
	end
	if c:GetAttribute("Equip") ~= true then return false, "Equip" end
	if c:GetAttribute("Greenzone") == true then return false, "Greenzone" end
	if c:GetAttribute("RpCombatLocked") == true then return false, "RpCombatLocked" end
	if c:GetAttribute("M2Cooldown") == true then return false, "M2Cooldown" end
	if c:GetAttribute("M2CD") == true then return false, "M2CD" end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false, "dead" end
	local h = getHandler()
	if h and h.GetAnims then
		local ehit = false
		pcall(function() ehit = next(h.GetAnims(c, "EHit")) ~= nil end)
		if ehit then return false, "EHit" end
	end
	return true, "ready"
end

function V93.markOwnM2IFrames(now, tag)
	local style = tostring(styleOf(localChar()) or ""):lower()
	loadGameModules()
	local lastContact = 0.43
	if GameData.cfg and GameData.cfg.GetStyleM2HitboxDelay then
		local okd, d = pcall(GameData.cfg.GetStyleM2HitboxDelay, style, false, nil)
		if okd and type(d) == "number" and d > 0 then lastContact = d end
		if GameData.cfg.GetStyleM2Variants then
			local okv, vs = pcall(GameData.cfg.GetStyleM2Variants, style)
			if okv and type(vs) == "table" then
				for _, vid in pairs(vs) do
					local ok2, d2 = pcall(GameData.cfg.GetStyleM2HitboxDelay, style, false, vid)
					if ok2 and type(d2) == "number" and d2 > lastContact then lastContact = d2 end
				end
			end
		end
	end
	-- Тот же нормализованный матч, что и в resolveInfo: наш собственный стиль
	-- тоже приходит строкой из игры ("BoxingAnims" и т.п.), и строгое равенство
	-- молча теряло второй контакт нашей связки при расчёте counter i-frames.
	if isBoxingStyle(style) then
		local mc = V93.boxingM2Contacts
		if type(mc) == "table" then
			for i = 1, #mc do
				if type(mc[i]) == "number" and mc[i] > lastContact then lastContact = mc[i] end
			end
		end
	end
	State.counterIFramesUntil = 0
	State.attackBusyUntil = math.max(State.attackBusyUntil or 0, now + lastContact)
	State.selfBusyUntil   = math.max(State.selfBusyUntil or 0, now + lastContact)
	State.ownIFrameTag = tag
end

function State.updateCounterTxn(now)
	local tx = State.counterTxn
	if not tx or (not tx.pending and not tx.confirmed) then return end
	local th = tx.threat
	local ch = localChar()
	local liveIFrames = ch and (ch:GetAttribute("IFRAMES") == true
		or ch:GetAttribute("UltraInstinct") == true) or false
	local enemyStopped, stopSource = false, nil
	local enemy = th and th.attackerModel
	if enemy and enemy.Parent then
		if enemy:GetAttribute("Parried") == true or enemy:GetAttribute("Stunned") == true
			or enemy:GetAttribute("Ragdoll") == true or enemy:GetAttribute("Downed") == true
			or enemy:GetAttribute("GuardBroken") == true then
			enemyStopped, stopSource = true, "enemy-state"
		elseif th.kind == "M1" and th.trackSeen and th.track then
			local okPlaying, playing = pcall(function() return th.track.IsPlaying end)
			if okPlaying and not playing and now > tx.sent then
				enemyStopped, stopSource = true, "enemy-track-stopped"
			end
		end
	end

	if liveIFrames then
		if th then
			th.coveredByCounter, th.counterPendingId, th.resolved = true, nil, true
		end
		tx.confirmed, tx.pending, tx.result = false, false, "IFRAMES"
		State.counterIFramesUntil = 0
		diagPush("COUNTER-CONFIRM t=%.2f id=%s src=IFRAMES sentAgo=%.0fms → threat covered, dodge not needed", now, tostring(tx.threatId), (now - tx.sent) * 1000)
		return
	end

	if enemyStopped then
		if th then
			th.coveredByCounter, th.counterPendingId, th.resolved = true, nil, true
		end
		tx.pending, tx.confirmed, tx.result = false, false, stopSource
		diagPush("COUNTER-CONFIRM t=%.2f id=%s src=%s sentAgo=%.0fms → threat neutralized, dodge not needed", now, tostring(tx.threatId), tostring(stopSource), (now - tx.sent) * 1000)
		return
	end

	local coverageMiss = th and (th.contactAbs or 0) <= (tx.expectedIFramesAt or 0)
	local timedOut = now >= (tx.ackDeadline or 0)
	if (tx.confirmed and not liveIFrames) or (tx.pending and (timedOut or coverageMiss)) then
		if th then
			th.counterPendingId = nil
			th.coveredByCounter = nil
		end
		local why = tx.confirmed and "IFRAMES ended before contact"
			or (coverageMiss and "expected IFRAMES cannot precede contact" or "IFRAMES not confirmed")
		tx.pending, tx.confirmed, tx.result = false, false, "fallback"
		State.counterIFramesUntil = 0
		diagPush("COUNTER-FAIL/FALLBACK t=%.2f id=%s gate=%s sentAgo=%.0fms → normal defense restored", now, tostring(tx.threatId), why, (now - tx.sent) * 1000)
	end
end

function State.updateAliM2Cooldown(now)
	local cd = State.aliM2CD
	local ch = localChar()
	if ch ~= cd.char then
		cd.char, cd.observed, cd.active, cd.known, cd.started = ch, false, false, false, 0
		local tx = State.dodgeTxn
		if tx then
			tx.pending, tx.confirmed, tx.perfectConfirmed = false, false, false
			tx.abuseThreat, tx.perfectAt, tx.reason = nil, nil, nil
		end
		State.ap.dodgeSteerDir, State.ap.dodgeSteerUntil = nil, 0
	end
	if not ch then return end
	local active = ch:GetAttribute("M2Cooldown") == true
	if not cd.observed then
		cd.observed, cd.active = true, active
		if active then cd.known = false end
		return
	end
	if active and not cd.active then
		loadGameModules()
		local duration = 7
		if GameData.cfg and GameData.cfg.GetStyleM2Cooldown then
			local ok, v = pcall(GameData.cfg.GetStyleM2Cooldown, "ali")
			if ok and type(v) == "number" and v > 0 then duration = v end
		end
		cd.started, cd.duration, cd.known = now, duration, true
	elseif not active and cd.active then
		cd.known, cd.started = false, 0
	end
	cd.active = active
end

_C.PARRY_ONLY_M2_CACHE = {}
local function m2IsParryOnlyStyle(style)
	local st = tostring(style or ""):lower()
	if st == "" then return false end
	local cached = _C.PARRY_ONLY_M2_CACHE[st]
	if cached ~= nil then return cached end
	loadGameModules()
	local cfg = GameData.cfg
	local verdict = (st == "boxing")
	if cfg then
		local iframeDur = GameData.iframeDur or Config.IFrameDur or 0.30
		if cfg.GetStyleM2HitboxDuration then
			local ok, dur = pcall(cfg.GetStyleM2HitboxDuration, st)
			if ok and type(dur) == "number" and dur > 0 and dur >= iframeDur then
				verdict = true
			end
		end
		local multi
		if cfg.GetStyleNumber then
			local ok, v = pcall(cfg.GetStyleNumber, st, "M2MultiHitCount", 1)
			if ok and type(v) == "number" then multi = v end
		end
		local grants
		if cfg.GetStyleBoolean then
			local ok, v = pcall(cfg.GetStyleBoolean, st, "M2GrantsIFrames", false)
			if ok and type(v) == "boolean" then grants = v end
		end
		if multi == nil or grants == nil then
			local okS, styles = pcall(function() return cfg.Styles end)
			local s = okS and type(styles) == "table" and styles[st] or nil
			if type(s) == "table" then
				if multi == nil and type(s.M2MultiHitCount) == "number" then multi = s.M2MultiHitCount end
				if grants == nil and type(s.M2GrantsIFrames) == "boolean" then grants = s.M2GrantsIFrames end
			end
		end
		if type(multi) == "number" and multi > 1 then verdict = true end
		if grants == true then verdict = true end
	end
	_C.PARRY_ONLY_M2_CACHE[st] = verdict
	return verdict
end

function State.isParryOnlyM2(th)
	return th ~= nil and th.kind == "M2" and m2IsParryOnlyStyle(th.style)
end

function State.isAliBoxingM2(th)
	return (styleOf(localChar()) or ""):lower() == "ali" and State.isParryOnlyM2(th)
end

function State.clusterHasAliBoxingM2(cluster)
	for _, th in ipairs(cluster or {}) do
		if State.isAliBoxingM2(th) then return true end
	end
	return false
end

function State.aliDodgeAbuseEligible(th, now, imminent, ifLat, ifDur)
	if not (Config.SkillAddon and Config.AliDodgeAbuse and Config.AliEvasiveCounter and Config.AutoDodge) then
		return false, nil, "disabled"
	end
	if (styleOf(localChar()) or ""):lower() ~= "ali" then return false, nil, "not-ali" end
	if not th or not th.serverProven then return false, nil, "not-server-proven" end
	if State.isMustDodge and State.isMustDodge(th) then return false, nil, "must-dodge" end

	local meC = localChar()
	if meC then
		if meC:GetAttribute("CombatAttacking") == true then return false, nil, "self-attacking" end
		if meC:GetAttribute("Stunned") == true then return false, nil, "stunned" end
		if meC:GetAttribute("CantAnything") == true then return false, nil, "cant-anything" end
		if meC:GetAttribute("GuardBroken") == true then return false, nil, "guard-broken" end
	end

	if State.isAliBoxingM2(th) then return false, nil, "boxing-m2-parry" end

	local cd = State.aliM2CD
	if not (cd and cd.active and cd.known) then return false, nil, "m2-cooldown-unknown" end
	local remaining = (cd.started + cd.duration) - now
	if remaining <= 1.0 then return false, nil, "m2-ready-soon" end

	local innerLo = ifLat + math.max(V93.lookahead or 0, 0) + 0.04
	local innerHi = ifLat + ifDur - 0.07
	local dt = th.contactAbs - now
	if dt < innerLo or dt > innerHi then return false, nil, "primary-outside-inner-iframe" end
	for _, other in ipairs(imminent) do
		if not other.dodged and not other.coveredByDodge and not other.feinted then
			local odt = other.contactAbs - now
			if odt < innerLo or odt > innerHi then
				return false, nil, "concurrent-outside-inner-iframe"
			end
		end
	end
	return true, remaining, "all-active-covered"
end

local function fireBoxingCounter(th, targetDist)
	local myHRP = localHRP()
	local aHRP  = th and th.attackerHRP
	if myHRP and aHRP and aHRP.Parent then
		local d = flatDirTo(myHRP.Position, aHRP.Position)
		if d then myHRP.CFrame = CFrame.lookAt(myHRP.Position, myHRP.Position + d) end
		local faceHold = (counterStyle() == "ali") and (Config.AliFaceLockDur or 0.75)
			or (Config.BoxingFaceLockDur or 0.55)
		setFaceGoal(aHRP, true, faceHold)
	end
	if State.blocking then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		pcall(sendDeactivate, true)
	end
	local cs = counterStyle()
	if cs == "ali" then
		loadGameModules()
		local hasVars = false
		if GameData.cfg and GameData.cfg.GetStyleM2Variants then
			local okv, vs = pcall(GameData.cfg.GetStyleM2Variants, cs)
			hasVars = okv and type(vs) == "table"
		end
		if hasVars then steerM2Variant(Config.AliM2Variant or "Left") end
	end
	ServerRemote:FireServer({ Type = "Combat", Action = "M2", Func = "ServerCheck" })
	local sentAt = os.clock()
	State.lastCounter  = sentAt
	State.counterCount = (State.counterCount or 0) + 1
	State.flashUntil   = sentAt + 0.25
	State.status       = (cs == "ali") and "ALI-COUNTER"
		or (cs == "wingchun") and "WC-COUNTER" or "BOX-COUNTER"
	local tx = State.counterTxn
	if tx.threat and tx.threat ~= th then tx.threat.counterPendingId = nil end
	tx.seq = (tx.seq or 0) + 1
	local net = math.max(uplink(), 0.02)
	tx.pending, tx.confirmed, tx.sent = true, false, sentAt
	tx.ackDeadline = sentAt + net + (V93.lookahead or 0) + 0.08
	-- Wing Chun M2 не даёт iframes: math.huge не даёт counterPreemptsDodge()
	-- решить, что мы прикрыты, и заглушить додж вместе с парированием.
	tx.expectedIFramesAt = (cs == "wingchun") and math.huge
			-- «Один кадр» = РЕАЛЬНЫЙ кадр, а не 1/60. При 17.8 fps кадр 56мс, и
			-- захардкоженные 16.7мс занижали запас в 3.4 раза.
			or (sentAt + net + math.max(V93.lookahead or 0, 0) + math.max(V93.frameDt or 0, 1 / 60))
	tx.threat, tx.source, tx.result = th, cs, "sent"
	tx.threatId = tostring(th.serverSwingId or (th.group and th.group.serverSwingId)
		or ((th.name or "?") .. "/" .. (th.kind or "?") .. "/" .. math.floor((th.detectClock or sentAt) * 1000)))
	th.counterPendingId = tx.seq
	State.counterPreemptFrame = -1
	diagPush("COUNTER-SEND t=%.2f id=%s target=%s/%s dist=%.1f gate=M2-ready ack=%0.fms", sentAt, tx.threatId, tostring(th.name), tostring(th.kind), targetDist or -1,
			(tx.ackDeadline - sentAt) * 1000)
	if cs == "wingchun" then
		-- Никаког�� markOwnM2IFrames: неуязвимости нет. Считаем только окно ловушки
		-- и держим себя "занятыми" на время стойки, чтобы не спамить M2 в CD 10с.
		local su = wcStartup()
		_D.WCTxn.pending  = true
		_D.WCTxn.sentAt   = sentAt
		_D.WCTxn.openAt   = sentAt + net + su
		_D.WCTxn.closeAt  = _D.WCTxn.openAt + _D.WINGCHUN.CounterWindow
		_D.WCTxn.threat   = th
		_D.WCTxn.threatId = tx.threatId
		State.attackBusyUntil = math.max(State.attackBusyUntil or 0, _D.WCTxn.closeAt)
		State.selfBusyUntil   = math.max(State.selfBusyUntil or 0, _D.WCTxn.closeAt)
		diagPush("WC-COUNTER-SEND t=%.2f id=%s target=%s/%s dist=%.1f startup=%.0fms(%s) window=[%.0f..%.0f]ms contactIn=%.0fms iframes=NONE",
			sentAt, tostring(tx.threatId), tostring(th.name), tostring(th.kind), targetDist or -1,
			su * 1000, "fixed+ping",
			(_D.WCTxn.openAt - sentAt) * 1000, (_D.WCTxn.closeAt - sentAt) * 1000,
			((th.contactAbs or sentAt) - sentAt) * 1000)
	else
		V93.markOwnM2IFrames(os.clock(), "counter/" .. tostring(cs))
	end
end

local tryAliEvasiveCounter = LPH_NO_VIRTUALIZE(function(now)
	if not Config.SkillAddon or not Config.AliEvasiveCounter then return false end
	if (counterStyle() or "") ~= "ali" then return false end
	local tx = State.dodgeTxn
	if not (tx and tx.pending and tx.perfectConfirmed) then return false end
	-- Строгая семантика тумблеров: Evasive Counter вкл → M2 после доджа. Но если
	-- Ali Dodge Abuse ВЫКЛючен, лишний M2 кидаем ТОЛЬ��О после ВЫНУЖДЕННОГО доджа
	-- (must-dodge/blatant/exposed), а не после обычного защитного — иначе выглядит
	-- как работающий abuse при вы��люченном тумблере (баг, о котором сообщил юзер).
	if not Config.AliDodgeAbuse and not tx.forced then return false end
	if tx.evCounterFired then return false end
	if not tx.confirmed then
		if not tx.evCounterAwaitIframeLogged then
			tx.evCounterAwaitIframeLogged = true
			diagPush("ALI-EVCOUNTER-WAIT t=%.2f gate=await-iframe perfectAgo=%.0fms", now, (now-(tx.perfectAt or now))*1000)
		end
		return false
	end
	loadGameModules()
	local ec
	if GameData.cfg and GameData.cfg.GetStyleEvasiveCounter then
		local ok, v = pcall(GameData.cfg.GetStyleEvasiveCounter, "ali")
		if ok and type(v) == "table" then ec = v end
	end
	local cd    = (ec and tonumber(ec.Cooldown))  or 6
	local range = (ec and tonumber(ec.MaxRange))  or 22
	if (now - (State.lastEvCounter or -99)) < cd then return false end
		local procTTL = math.min(cd * (Config.AliProcTTLFrac or 0.25), Config.AliProcTTLMax or 1.5)
		local procDeadline = math.max(tx.untilAt or 0, (tx.perfectAt or now) + procTTL)
		if now > procDeadline then
			if not tx.evCounterExpiredLogged then
				tx.evCounterExpiredLogged = true
				diagPush("ALI-EVCOUNTER-EXPIRE t=%.2f perfectAgo=%.0fms gate=proc-window-ended ttl=%.0fms", now, (now-(tx.perfectAt or now))*1000, procTTL*1000)
			end
			return false
		end
	local c = localChar()
	if not c then return false end
	local stateGate = c:GetAttribute("Equip") ~= true and "not-equipped"
		or (c:GetAttribute("Stunned") == true and "stunned")
		or (c:GetAttribute("CombatAttacking") == true and "combat-attacking") or nil
	if stateGate then
		if tx.evCounterStateGate ~= stateGate then
			tx.evCounterStateGate = stateGate
			diagPush("ALI-EVCOUNTER-WAIT t=%.2f gate=%s perfectAgo=%.0fms", now, stateGate, (now-(tx.perfectAt or now))*1000)
		end
		return false
	end
	local myHRP = localHRP(); if not myHRP then return false end
	local myPos = myHRP.Position
	local best, bestDist
	local bound = tx.abuseThreat
	if bound then
		local aHRP = bound.attackerHRP
		if aHRP and aHRP.Parent then
			local dx, dz = myPos.X - aHRP.Position.X, myPos.Z - aHRP.Position.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= range then best, bestDist = bound, d end
		end
		if not best then
			if not tx.evCounterTargetGateLogged then
				tx.evCounterTargetGateLogged = true
				diagPush("ALI-EVCOUNTER-WAIT t=%.2f gate=bound-target-missing-or-range range=%.0f", now, range)
			end
			return false
		end
	else
		for i = 1, #Threats do
			local th = Threats[i]
			local aHRP = th.attackerHRP
			local boxingM2 = tostring(th.style or ""):lower() == "boxing" and th.kind == "M2"
			if aHRP and aHRP.Parent and not boxingM2 then
				local dx, dz = myPos.X - aHRP.Position.X, myPos.Z - aHRP.Position.Z
				local d = math.sqrt(dx * dx + dz * dz)
				if d <= range and (not bestDist or d < bestDist) then best, bestDist = th, d end
			end
		end
		if not best then return false end
	end
	local aHRP = best.attackerHRP
	if aHRP and aHRP.Parent then
		local d = flatDirTo(myPos, aHRP.Position)
		if d then myHRP.CFrame = CFrame.lookAt(myPos, myPos + d) end
		setFaceGoal(aHRP, true, Config.AliFaceLockDur or 0.75)
	end
	if State.blocking then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		pcall(sendDeactivate, true)
	end
	ServerRemote:FireServer({ Type = "Combat", Action = "M2", Func = "ServerCheck" })
	tx.evCounterFired    = true
	State.lastEvCounter  = now
	State.evCounterCount = (State.evCounterCount or 0) + 1
	State.flashUntil     = now + 0.25
	State.status         = "ALI-EV-COUNTER"
	diagPush("ALI-EVCOUNTER-SEND t=%.2f target=%s dist=%.1f range=%.0f specialCd=%.0fs ignoreNormalM2Cd=true variant=Left perfectAgo=%.0fms gate=one-StyleEvasiveCounter", now, best.name or "?", bestDist, range, cd, (now-(tx.perfectAt or now))*1000)
	return true
end)

function State.counterBlockedPerm()
	if not Config.SkillAddon then return true end
	local c = localChar(); if not c then return true end
	if not counterStyle() then return true end
	if c:GetAttribute("Equip") ~= true then return true end
	if c:GetAttribute("M2Cooldown") == true or c:GetAttribute("M2CD") == true then return true end
	if c:GetAttribute("Greenzone") == true or c:GetAttribute("RpCombatLocked") == true then return true end
	if c:GetAttribute("Ragdoll") == true or c:GetAttribute("Downed") == true then return true end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return true end
	local h = getHandler()
	if h and h.GetAnims then
		local ehit = false
		pcall(function() ehit = next(h.GetAnims(c, "EHit")) ~= nil end)
		if ehit then return true end
	end
	return false
end

function State.counterReadyAt(now)
	local at = now
	local gapEnd = (State.lastCounter or 0) + (Config.BoxingCounterGap or 0.30)
	if gapEnd > at then at = gapEnd end
	local swingEnd = State.swingAnimUntil or 0
	if swingEnd > at then at = swingEnd end
	return at
end

local function counterCandidate(now, ignoreTransient)
	if ignoreTransient then
		if State.counterBlockedPerm() then return nil end
	else
		local ready, gate = counterReady()
		if not ready then return nil, nil, gate end
	end
	local myHRP = localHRP()
	if not myHRP then return nil end
	local cstyle = counterStyle()
	local reach = (cstyle == "ali") and (Config.AliCounterReach or 7.5)
		or (cstyle == "wingchun") and (Config.WingChunCounterReach or 6.5)
		or (Config.BoxingCounterReach or 5.5)
	local myPos = myHRP.Position
	local best, bestDist
	local mustDodgeFn = State.isMustDodge
	-- Когда стиль Ali и включён dodge-abuse, приоритет у ДОДЖА (Q → п��ссивка → лишний M2),
	-- а не у counter. Раньше counter хватал э��от же threat, ставил pending-txn →
	-- counterPreemptsDodge(true) глушил Ali dodge abuse, а сам pending-counter выставлял
	-- нам CombatAttacking/CantAnything и ломал парри. Пусть додж владеет такими угрозами.
	local styleIsAli = (styleOf(localChar()) or ""):lower() == "ali"
	local aliAbuseOn = styleIsAli and Config.SkillAddon and Config.AliDodgeAbuse
		and Config.AliEvasiveCounter and Config.AutoDodge ~= false
	for i = 1, #Threats do
		local th = Threats[i]
		local aHRP = th.attackerHRP
		local aliVsBoxingM2 = State.isAliBoxingM2(th)
		if aliVsBoxingM2 and not th.aliBoxingCounterLogged then
			th.aliBoxingCounterLogged = true
			diagPush("ALI-BOXING-M2=PARRY t=%.2f target=%s strike=%d contactIn=%.0fms gate=counter", now, tostring(th.name), th.strike or 1, (th.contactAbs-now)*1000)
		end
		local yieldToAbuse = false
		if aliAbuseOn then
			local ifLat = math.max(uplink(), 0.02)
			local ifDur = GameData.iframeDur or Config.IFrameDur or 0.30
			local ok = State.aliDodgeAbuseEligible(th, now, Threats, ifLat, ifDur)
			if ok then yieldToAbuse = true end
		end
		if aHRP and aHRP.Parent and not aliVsBoxingM2 and not yieldToAbuse and not th.feinted and not th.dodged
		   and not th.coveredByDodge and not th.coveredByCounter and not th.counterPendingId
		   and not th.counterCommittedToParry
		   and not (mustDodgeFn and mustDodgeFn(th))
		   and (th.contactAbs - now) > -0.15 then
			local dx, dz = myPos.X - aHRP.Position.X, myPos.Z - aHRP.Position.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= reach and (not bestDist or dist < bestDist) then
				best, bestDist = th, dist
			end
		end
	end
	return best, bestDist
end

local function counterPreemptsDodge(now)
	if State.counterPreemptFrame == _C.FrameId then return State.counterPreemptVal end
	local ch = localChar()
	if ch then
		if ch:GetAttribute("IFRAMES") == true or ch:GetAttribute("UltraInstinct") == true then
			State.counterPreemptFrame, State.counterPreemptVal = _C.FrameId, true
			if now >= (State.lastPreemptLogAt or 0) + 0.5 then
				State.lastPreemptLogAt = now
				diagPush("IFRAME-COVER t=%.2f  dodge skipped, live IFRAMES attribute on us (src=%s)", now, tostring(State.ownIFrameTag or "game"))
			end
			return true
		end
	end
	if Config.CounterPreemptsDodge == false then return false end
	local ctx = State.counterTxn
	if ctx and ctx.pending and ctx.threat and ctx.threat.counterPendingId == ctx.seq
		and now < (ctx.ackDeadline or 0)
		and (ctx.expectedIFramesAt or math.huge) < (ctx.threat.contactAbs or 0) then
		State.counterPreemptFrame, State.counterPreemptVal = _C.FrameId, true
		if State.counterCoverTag ~= ctx.seq then
			State.counterCoverTag = ctx.seq
			State.counterCoverSkips = (State.counterCoverSkips or 0) + 1
			diagPush("COUNTER-COVER t=%.2f id=%s state=PENDING ackLeft=%.0fms contactIn=%.0fms", now, tostring(ctx.threatId), ((ctx.ackDeadline or now) - now) * 1000,
					((ctx.threat.contactAbs or now) - now) * 1000)
		end
		return true
	end
	State.counterPreemptFrame, State.counterPreemptVal = _C.FrameId, false
	return false
end

-- Закрываем висящую WC-транзакцию: если до конца окна (+сеть) не пришёл
-- WingChunCounterHit — окно пр��махнулось, зна��ит нас ждёт 1с стана и 10с CD.
local function wcPoll(now)
	if not _D.WCTxn.pending then return end
	local net = math.max(uplink(), 0.02)
	if now <= _D.WCTxn.closeAt + net then return end
	_D.WCTxn.pending = false
	_D.WCTxn.whiffs  = (_D.WCTxn.whiffs or 0) + 1
	-- Стан реален: не даём скрипту думать, что он может парировать.
	State.selfBusyUntil = math.max(State.selfBusyUntil or 0,
		now + _D.WINGCHUN.CounterWhiffStun)
	diagPush("WC-COUNTER-WHIFF t=%.2f id=%s → стан %.0fms + CD %.0fс  (hits=%d whiffs=%d)",
		now, tostring(_D.WCTxn.threatId), _D.WINGCHUN.CounterWhiffStun * 1000,
		_D.WINGCHUN.Cooldown, _D.WCTxn.hits or 0, _D.WCTxn.whiffs)
	_D.WCTxn.threat = nil
end

-- ══ WING CHUN: решатель окна ══════════════════════════════════════════════════
-- Boxing/Ali: нужны iframes В МОМЕНТ контакт�� → жать как можно раньше.
-- Wing Chun: нужно, чтобы КОНТАКТ ВРАГА попал внутрь окна [open, open+0.5].
-- Возвращает "fire" | "wait" | "parry" + текст причины.
local function wcDecide(th, now, threatCount)
	local net    = math.max(uplink(), 0.02)
	local su     = wcStartup()
	local openIn = net + su
	local win    = _D.WINGCHUN.CounterWindow
	local early  = Config.WCEarlyMargin or 0.045
	local late   = Config.WCLateMargin or 0.10
	local aimIn  = openIn + math.min((Config.WCAimFrac or 0.35) * win, win - late)
	local contactIn = (th.contactAbs or now) - now

	-- нет iframes → второй атакующий пробьёт нас в стойке
	if Config.WCSoloOnly ~= false and threatCount > 1 then
		return "parry", string.format("multi-threat(%d) без iframes", threatCount)
	end
	-- грэб может не конвертнуться в counter-hit, а 2.2с стан получим мы
	if Config.WCSkipGrabs ~= false and th.kind == "M2" then
		local st = styleKey(th.style)
		if st == "wrestling" or st == "dirty" then
			return "parry", "grab-style M2 (" .. st .. ")"
		end
	end
	-- на предсказанном контакте промах окна = урон + стан + 10с CD
	if Config.WCRequireLiveTrack ~= false and th.spdSrc ~= "live" then
		return "parry", "contact=predict (нет живого track.Speed)"
	end
	-- окно физически не накроет контакт
	if contactIn < openIn + early then
		return "parry", string.format("contactIn=%.0fms < open=%.0f+%.0fms",
			contactIn * 1000, openIn * 1000, early * 1000)
	end
	-- ещё рано: ждём, чтобы контакт лёг в середину окна, а не в хвост
	if contactIn > aimIn then
		return "wait", string.format("contactIn=%.0fms > aim=%.0fms",
			contactIn * 1000, aimIn * 1000)
	end
	return "fire", string.format("contact на %.0f%% окна",
		((contactIn - openIn) / win) * 100)
end

local function tryBoxingCounter(now)
	wcPoll(now)
	local best, bestDist = counterCandidate(now, true)
	if not best then return false end
	-- Wing Chun: пока у цели активно counter-окно (0.5с), любая наша атака
	-- превращается в контру с 2.2с стана. Контратаку отмен��ем, уходим в парирование.
	if wingChunCounterActive(best.attackerModel) then
		best.counterCommittedToParry = true
		if not best.wingChunGateLogged then
			best.wingChunGateLogged = true
			diagPush("WINGCHUN-GATE t=%.2f %s держит counter-стойку → контратака отменена (и��аче 2.2с стан)",
				now, tostring(best.name))
		end
		return false
	end
	local ready, gate = counterReady()
	if not ready then
		local contactAt = best.contactAbs or now
		-- Реальный кадр, не 1/60: иначе на 17.8 fps контратака считалась «успеем»,
		-- уходила в отправку, оставляла нас в Unequip/CombatAttacking — и удар ел��сь.
		local lead = math.max(uplink(), 0.02) + math.max(V93.lookahead or 0, 0)
			+ math.max(V93.frameDt or 0, 1 / 60)
		local viableAgain = State.counterReadyAt(now) + lead < contactAt
		if not viableAgain then best.counterCommittedToParry = true end
		if best.counterFallbackGate ~= gate then
			best.counterFallbackGate = gate
			diagPush("COUNTER-FALLBACK/PARRY t=%.2f target=%s/%s contactIn=%.0fms gate=%s retry=%s readyIn=%.0fms", now, tostring(best.name), tostring(best.kind),
					(contactAt-now)*1000, tostring(gate or "unknown"),
					tostring(viableAgain), (State.counterReadyAt(now)-now)*1000)
		end
		return false
	end
	if counterStyle() == "wingchun" then
		local live = 0
		for i = 1, #Threats do
			local t = Threats[i]
			if not t.feinted and not t.dodged and (t.contactAbs or 0) > now - 0.05 then
				live = live + 1
			end
		end
		local act, why = wcDecide(best, now, live)
		if act == "fire" then
			fireBoxingCounter(best, bestDist)
			return true
		end
		if act == "parry" then
			best.counterCommittedToParry = true
			if best.wcSkipWhy ~= why then
				best.wcSkipWhy = why
				diagPush("WC-COUNTER-SKIP/PARRY t=%.2f target=%s/%s reason=%s", now,
					tostring(best.name), tostring(best.kind), why)
			end
		elseif best.wcWaitWhy ~= why then
			best.wcWaitWhy = why
			diagPush("WC-COUNTER-WAIT t=%.2f target=%s/%s %s", now,
				tostring(best.name), tostring(best.kind), why)
		end
		return false
	end
	local contactIn = (best.contactAbs or now) - now
		-- Порог «уже поздно контратаковать, уходим в парри» то��е считался по 1/60.
		-- На низком fps он был втрое меньше нужного, поэтому контра стартовала
		-- слишком поздно и съедала возможность парировать.
		local fr = math.max(V93.frameDt or 0, 1 / 60)
		local iframeLead = math.max(uplink(), 0.02) + math.max(V93.lookahead or 0, 0) + fr
		local parryLead = math.max(Config.PerfectLead - math.max(uplink(), 0.02), 0) + fr
	local yieldLead = math.max(iframeLead, parryLead)
	if contactIn <= yieldLead then
		best.counterCommittedToParry = true
		if not best.counterLateSkipLogged then
			best.counterLateSkipLogged = true
			diagPush("COUNTER-SKIP/PARRY t=%.2f target=%s/%s contactIn=%.0fms need=%.0fms (iframe=%.0f parry=%.0f) gate=%s", now, tostring(best.name), tostring(best.kind), contactIn * 1000,
					yieldLead * 1000, iframeLead * 1000, parryLead * 1000,
					parryLead >= iframeLead and "PARRY-DEADLINE-FIRST" or "IFRAMES-cannot-precede-contact")
		end
		return false
	end
	fireBoxingCounter(best, bestDist)
	return true
end

local function isMustDodge(th)
	if not th then return false end
	local st = (th.style or ""):lower()
	if Config.SkillAddon then
		if Config.MustDodge and Config.SA_WrestlingGrab and st == "wrestling" and th.kind == "M2" then return true end
		if Config.MustDodge and Config.SA_DirtyGrab and st == "dirty" and (th.kind == "M2" or th.kind == "SKILL") then return true end
	end
	if not Config.MustDodge then return false end
	local byStyle = Config.MustDodgeStyles and Config.MustDodgeStyles[st]
	if byStyle and (byStyle[th.kind] or byStyle.all) then return true end
	if th.kind == "M2" and Config.MustDodgeAutoGrab ~= false and st ~= "" then
		GameData.grabCache = GameData.grabCache or {}
		local cached = GameData.grabCache[st]
		if cached == nil then
			cached = false
			loadGameModules()
			if GameData.cfg then
				pcall(function()
					local sc = GameData.cfg.GetStyleConfig and GameData.cfg.GetStyleConfig(st) or nil
					if sc then
						cached = (sc.M2GrabAllowRagdollCombo == true)
							or (type(sc.M2GrabTargetForwardOffset) == "number")
							or (type(sc.M2GrabLockDuration) == "number")
							or (type(sc.M2SlamParryWindowDisableDuration) == "number")
					end
				end)
			end
			GameData.grabCache[st] = cached
		end
		if cached then return true end
	end
	local aModel = th.attackerModel
	if aModel then
		local ok, grab = pcall(function()
			return aModel:GetAttribute("Grabbing") == true
				or aModel:GetAttribute("Unblockable") == true
				or aModel:GetAttribute("GuardBreak") == true
		end)
		if ok and grab then return true end
	end
	return false
end
State.isMustDodge = isMustDodge

State.ap = {
	m1         = nil,
	tryM1Fn    = nil,
	comboIdx   = nil,
	m1Tried    = false,
	fireOK     = false,
	u25idx     = nil,
	u26idx     = nil,
	u21idx     = nil,
	u32idx     = nil,
	u33idx     = nil,
	u27tbl     = nil,
	u28tbl     = nil,
	crc        = nil,
	getAnims   = nil,
	getSpeed   = nil,
	playSwing  = nil,
	nextM1At   = 0,
	punishTgt  = nil,
	punishUntil= 0,
		punishFresh= false,
		m1Txn      = nil,
		m1TxnSeq   = 0,
		busyAttrs = {
		"Stunned", "Ragdoll", "Downed", "GuardBroken", "CantAnything",
		"M1Cooldown", "ParryAttackLockout", "BlockAttackLockout",
	},
}

function State.ap.getM1()
	if State.ap.m1 then return State.ap.m1 end
	if State.ap.m1Tried then return nil end
	State.ap.m1Tried = true
	local mod
	pcall(function()
		local csc = ReplicatedStorage:FindFirstChild("CombatSystemClient")
		local base = csc and csc:FindFirstChild("Combat")
		base = base and base:FindFirstChild("Base")
		mod = base and base:FindFirstChild("M1")
	end)
	if not mod then
		pcall(function()
			for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
				if d.Name == "M1" and d:IsA("ModuleScript")
				   and d.Parent and d.Parent.Name == "Base" then mod = d; break end
			end
		end)
	end
	if mod then
		local ok, tbl = pcall(require, mod)
		if ok and type(tbl) == "table" and type(tbl.OnM1Activated) == "function" then State.ap.m1 = tbl end
	end
	if not State.ap.m1 and type(filtergc) == "function" then
		pcall(function()
			local t = filtergc("table",
				{ Keys = { "Hold", "OnM1Activated", "ServerResponse", "OnHoldSwing" } }, true)
			if type(t) == "table" and type(t.OnM1Activated) == "function" then State.ap.m1 = t end
		end)
	end
	if State.ap.m1 and type(debug) == "table" and type(debug.getupvalue) == "function" then
		pcall(function()
			local fn = debug.getupvalue(State.ap.m1.OnM1Activated, 1)
			if type(fn) == "function" then State.ap.tryM1Fn = fn end
		end)
			if State.ap.tryM1Fn and type(debug.setupvalue) == "function" then
				pcall(function()
					local fn = State.ap.tryM1Fn
					local function uv(i)
						local ok, v = pcall(debug.getupvalue, fn, i)
						if ok then return v end
						return nil
					end
					local C
					for i = 1, 40 do
						local v = uv(i)
						if type(v) == "table" and type(rawget(v, "Fire")) == "function" then C = i; break end
						if v == nil and i > 25 then break end
					end
					if not C then return end
					local getSpeed = uv(C - 12)
					local u19v     = uv(C - 11)
					local getAnims = uv(C - 10)
					local playSw   = uv(C - 8)
					local u25v     = uv(C - 4)
					local u26v     = uv(C - 3)
					local u27v     = uv(C - 2)
					local u28v     = uv(C - 1)
					local u21v     = uv(C - 16)
					local u32v     = uv(C - 15)
					local u33v     = uv(C - 14)
					if type(getSpeed) == "function"
					   and type(getAnims) == "function"
					   and type(playSw)  == "function"
					   and type(u19v) == "number" and u19v >= 0 and u19v <= 4
					   and type(u25v) == "number" and type(u26v) == "number"
					   and type(u27v) == "table"  and type(u28v) == "table" then
						State.ap.comboIdx  = C - 11
						State.ap.u25idx    = C - 4
						State.ap.u26idx    = C - 3
						State.ap.u27tbl    = u27v
						State.ap.u28tbl    = u28v
						State.ap.crc       = uv(C)
						State.ap.getSpeed  = getSpeed
						State.ap.getAnims  = getAnims
						State.ap.playSwing = playSw
						State.ap.fireOK    = true
						if type(u21v) == "boolean" then State.ap.u21idx = C - 16 end
						if type(u32v) == "number"  then State.ap.u32idx = C - 15 end
						if type(u33v) == "number"  then State.ap.u33idx = C - 14 end
					end
				end)
			end
		end
	if State.ap.m1 then diagPush("AUTOPLAY: M1 module resolved (legit attacks ready)"
		.. (State.ap.tryM1Fn and " +tryM1" or " (OnM1Activated only)")
		.. (State.ap.fireOK and " +CUSTOM-FIRE(fast)" or ""))
	else diagPush("AUTOPLAY: M1 module NOT found — attacks disabled") end
	return State.ap.m1
end

function State.ap.trackOwners()
	if type(getgenv) ~= "function" then return nil end
	local g = getgenv()
	local r = rawget(g, "__V0_COMBAT_TRACK_OWNERS")
	if type(r) ~= "table" then
		r = setmetatable({}, { __mode = "k" })
		rawset(g, "__V0_COMBAT_TRACK_OWNERS", r)
	end
	return r
end

function State.ap.finishM1Txn(reason, now)
	local ap, tx = State.ap, State.ap.m1Txn
	if not tx then return end
	ap.m1Txn = nil
	now = now or os.clock()
	diagPush("AUTOPLAY-DONE t=%.2f tx=%d swing=%d combo=%d reason=%s suppressed=%d age=%.0fms", now, tx.txid or 0, tx.swingId or 0, tx.combo or 0, tostring(reason or "complete"),
			tx.suppressed or 0, math.max(0, now - (tx.sentAt or now)) * 1000)
end

function State.ap.m1TxnActive(now)
	local ap, tx = State.ap, State.ap.m1Txn
	if not tx then return false end
	now = now or os.clock()
	local c = localChar()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if c ~= tx.char or not hum or hum.Health <= 0 then
		ap.finishM1Txn("character/death", now)
		return false
	end
	if now < (tx.untilAt or 0) then
		tx.suppressed = (tx.suppressed or 0) + 1
		return true
	end
	local why = tx.trackStopped and "track-stopped+floor" or "duration"
	ap.finishM1Txn(why, now)
	return false
end

function State.ap.markM1Track(char, anim, tx)
	local h = getHandler()
	if not (h and h.GetAnims and anim and tx) then return nil end
	local track
	pcall(function()
		local bucket = h.GetAnims(char, "M1")
		local entry = bucket and bucket[anim.AnimationId]
		track = entry and entry.Track
	end)
	if not track then return nil end
	tx.track = track
	local owners = State.ap.trackOwners()
	if owners then owners[track] = { owner = "autoplay", txid = tx.txid, swingId = tx.swingId } end
	pcall(function()
		track.Stopped:Connect(function()
			if State.ap.m1Txn == tx then tx.trackStopped = true end
		end)
	end)
	return track
end

function State.ap.fireM1Custom(char, model, wantCombo, ignoreRate, priority, dropGuard)
	local ap = State.ap
	if not (ap.fireOK and ap.tryM1Fn) then return false end
	local ok = false
	pcall(function()
		local now = os.clock()
		if ap.m1TxnActive(now) then return end
	if Config.SkillAddon and Config.AliEvasiveCounter then
		local etx = State.dodgeTxn
		if etx and etx.pending and etx.perfectConfirmed and not etx.evCounterFired then
			return
		end
		if Config.AliDodgeAbuse and Config.AutoDodge then
			local cdA = State.aliM2CD
			if cdA and cdA.active and cdA.known then
				local holdUntilContact = math.max(uplink(), 0.02)
					+ (GameData.iframeDur or Config.IFrameDur or 0.30) + 0.10
				for i = 1, #Threats do
					local th = Threats[i]
					if th and th.serverProven and not th.resolved and not th.dodged then
						local dtA = (th.contactAbs or 0) - os.clock()
						if dtA > 0 and dtA <= holdUntilContact then return end
					end
				end
			end
		end
	end
		local combo
		if wantCombo then
			combo = math.clamp(math.floor(wantCombo), 1, 4)
		elseif Config.AP_ComboMode == "Fixed" then
			combo = math.clamp(math.floor(Config.AP_FixedHit or 1), 1, 4)
		else
			combo = ((debug.getupvalue(ap.tryM1Fn, ap.comboIdx) or 0) % 3) + 1
		end
		if not ignoreRate then
			local rate = math.max(1, Config.AP_MaxPerSec or 6)
			local gap = priority and (Config.AP_PunishFastGap or 0.08)
				or math.max(Config.AP_MinSendGap or 0.09, (1 / rate) * 0.97)
			if (now - (ap.m1SendLast or 0)) < gap then return end
			if (now - (ap.m1WinStart or 0)) >= 1 then ap.m1WinStart, ap.m1WinCount = now, 0 end
			if (ap.m1WinCount or 0) >= rate then return end
		end
		if Config.AP_AnimGuard ~= false and (now - (ap.swingAnimAt or 0)) < (ap.swingAnimMin or 0) then
			return
		end
		local anims = ap.getAnims()
		local v53   = anims and anims[combo] or nil
		if not v53 then return end
		local spd = 1
		pcall(function() spd = ap.getSpeed(char, combo) or 1 end)
		local len = 0
		pcall(function()
			local cp = GameData.cfg and GameData.cfg.ClientPredict
			local m1 = cp and cp.M1
			len = tonumber(m1 and m1.AttackDuration) or 0
		end)
		if len <= 0 then len = Config.AP_AnimFallback or 0.45 end
		len = len / math.max(spd, 0.01)
		State.swingAnimUntil = now + len
		if AnimLib.tracks.Blocking or (char:GetAttribute("Blocking") == true) then
			stopBlockAnim()
		end
		local owners = ap.trackOwners()
		if owners then
			owners.__intent = { owner = "autoplay", char = char, animationId = v53.AnimationId, expires = now + 0.15 }
		end
		local played = false
		pcall(function() played = ap.playSwing(char, combo, spd, false) == true end)
		if not played then
			if owners and owners.__intent and owners.__intent.char == char then owners.__intent = nil end
			State.swingAnimUntil = 0
			return
		end
		ap.swingAnimAt  = now
		ap.swingAnimMin = len
		if dropGuard and (State.blocking or char:GetAttribute("Blocking") == true) then
			State.blocking, State.holdUntil = false, 0
			stopBlockAnim()
			pcall(sendDeactivate, true)
		end
		local newId = (debug.getupvalue(ap.tryM1Fn, ap.u25idx) or 0) + 1
			ServerRemote:FireServer({ Type = "Combat", Action = "M1", Func = "ServerCheck" }, newId)
			ap.m1SendLast = now
			ap.m1WinCount = (ap.m1WinCount or 0) + 1
			debug.setupvalue(ap.tryM1Fn, ap.comboIdx, combo)
			debug.setupvalue(ap.tryM1Fn, ap.u25idx, newId)
			debug.setupvalue(ap.tryM1Fn, ap.u26idx, newId)
			ap.u27tbl[newId] = combo
			ap.u28tbl[newId] = v53
			ap.m1TxnSeq = (ap.m1TxnSeq or 0) + 1
			local tx = {
				txid = ap.m1TxnSeq, swingId = newId, combo = combo, char = char,
				sentAt = now, untilAt = now + len, suppressed = 0,
			}
			ap.m1Txn = tx
			local tr = ap.markM1Track(char, v53, tx)
			if owners and owners.__intent and owners.__intent.char == char then owners.__intent = nil end
			diagPush("AUTOPLAY-SEND t=%.2f tx=%d swing=%d combo=%d duration=%.0fms track=%s", now, tx.txid, newId, combo, len * 1000, tr and "owned" or "unresolved")
			ok = true
	end)
	return ok
end

function State.ap.canAttack(ignoreBlocking)
	local c = localChar()
	if not c then return false end
	if c:GetAttribute("Equip") ~= true then return false end
	if not ignoreBlocking and c:GetAttribute("Blocking") == true then return false end
	if c:GetAttribute("CombatAttacking") == true or c:GetAttribute("M1") == true
	   or c:GetAttribute("M2") == true or c:GetAttribute("PendingM2") == true then return false end
	if c:GetAttribute("Greenzone") == true or c:GetAttribute("RpCombatLocked") == true then return false end
	for _, a in ipairs(State.ap.busyAttrs) do
		if c:GetAttribute(a) then return false end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	return true
end

function State.ap.reach()
	local base = Config.AP_BaseReach or 5.5
	loadGameModules()
	if GameData.cfg and GameData.cfg.GetStyleHitboxForwardOffset then
		local ok, fwd = pcall(GameData.cfg.GetStyleHitboxForwardOffset, styleOf(localChar()), "M1")
		if ok and type(fwd) == "number" then base = fwd + 1.5 end
	end
	local _, _, myH = heightDiag(localChar())
	if type(myH) == "number" and myH > 0 then
		base = base * math.clamp(myH / (Config.AP_RefHeight or 5.5), 0.85, 1.45)
	end
	return base
end

function State.ap.flatDist(model)
	local myHRP = localHRP()
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not (myHRP and hrp) then return math.huge end
	local aim = hrp.Position
	local lead = math.clamp(getPing() * (Config.FacePingLead or 1.0), 0, Config.FaceLeadCap or 0.22)
	if lead > 0 then
		local v = hrp.AssemblyLinearVelocity
		aim = aim + Vector3.new(v.X, 0, v.Z) * lead
	end
	return (Vector3.new(myHRP.Position.X, 0, myHRP.Position.Z)
	        - Vector3.new(aim.X, 0, aim.Z)).Magnitude
end

function State.ap.snapTo(hrp)
	setFaceGoal(hrp, true, Config.AP_FaceHold or 0.35)
	local myHRP = localHRP()
	if myHRP then
		local d = flatDirTo(myHRP.Position, hrp.Position)
		if d then myHRP.CFrame = CFrame.lookAt(myHRP.Position, myHRP.Position + d) end
	end
end

-- WALL-время (сек от «сейчас» до момента, когда НАШ удар достигнет контакта на
-- нашем клиенте). Нужно для сравнения с enemyLeft (тоже wall-время до чужого удара).
-- КЛЮЧ: игра замедляет и НАШУ анимацию на пол-пинга (CombatPingAnimUtils, тот же
-- gamePingAnimMult, читающий LocalPlayer:GetNetworkPing). Раньше это игнорировалось —
-- считали свой удар быстрее, чем он есть, и «сбив» либо не выигрывал гонку, либо код
-- вообще падал на несуществующих функциях. Теперь: wall = animContact / (mult * pingComp).
function State.ap.ownAttackWall(base)
	if type(base) ~= "number" or base <= 0 then return nil end
	local char = localChar()
	local windup = GameData.windupExtra or Config.HitboxWindupExtra or 0.012
	local animContact = base + windup
	local mult = attackSpeedMult(char)
	if type(mult) ~= "number" or mult < 0.05 then mult = 1 end
	local speed = mult * gamePingAnimMult(animContact)
	if speed < 0.05 then speed = 0.05 end
	return animContact / speed
end

-- ETA нашего M1 (wall-сек) + номер комбо. Использует V93.ownM1Info (M1!), а не M2.
function State.ap.ownM1Delay()
	local ap = State.ap
	local char = localChar()
	if not char then return nil, nil end
	local combo = 1
	if Config.AP_ComboMode == "Fixed" then
		combo = math.clamp(math.floor(Config.AP_FixedHit or 1), 1, 4)
	elseif ap.fireOK and ap.tryM1Fn and ap.comboIdx then
		combo = ((debug.getupvalue(ap.tryM1Fn, ap.comboIdx) or 0) % 3) + 1
	end
	local style = styleOf(char)
	local info  = V93.ownM1Info
	info.s = style
	local base = hitTimelineBase(info, combo)
	if type(base) ~= "number" or base <= 0 then return nil, nil end
	local eta = ap.ownAttackWall(base)
	if not eta then return nil, nil end
	return eta, combo
end

-- ETA нашего M2 (wall-сек) + id самого быстрого варианта стойки. Кэш по стилю.
function State.ap.ownM2Delay()
	local ap = State.ap
	local char = localChar()
	if not char then return nil, nil end
	local style = styleOf(char)
	local info  = V93.ownM2Info
	info.s, info.mom, info.variant, info.hit, info.id = style, false, nil, nil, nil
	local vc = State.ap.m2VarCache
	if not vc then vc = {}; State.ap.m2VarCache = vc end
	local hit = vc[style]
	if hit == nil then
		local bestId, bestBase = nil, nil
		loadGameModules()
		if GameData.cfg and GameData.cfg.GetStyleM2Variants then
			local okv, vs = pcall(GameData.cfg.GetStyleM2Variants, style)
			if okv and type(vs) == "table" then
				for id in pairs(vs) do
					info.variant = id
					local okb, base = pcall(hitTimelineBase, info, nil)
					if okb and type(base) == "number" and (not bestBase or base < bestBase) then
						bestId, bestBase = id, base
					end
				end
			end
		end
		info.variant = bestId
		if not bestBase then
			local okb, base = pcall(hitTimelineBase, info, nil)
			if okb and type(base) == "number" then bestBase = base end
		end
		hit = bestBase and { id = bestId, base = bestBase } or false
		vc[style] = hit
	end
	if hit == false then return nil, nil end
	if type(hit.base) ~= "number" or hit.base <= 0 then return nil, nil end
	info.variant = hit.id
	local eta = ap.ownAttackWall(hit.base)
	if not eta then return nil, nil end
	return eta, hit.id
end

-- Даёт ли наш M2 в текущем стиле i-frames (Boxing/Ali-подобные). Нужно tryInterrupt,
-- чтобы разрешить размен даже когда мы формально «не успеваем» — неуязвимость покроет.
function State.ap.m2GrantsIFrames()
	local char = localChar()
	if not char then return false end
	local style = styleOf(char)
	loadGameModules()
	if GameData.cfg then
		if GameData.cfg.GetStyleBoolean then
			local ok, v = pcall(GameData.cfg.GetStyleBoolean, style, "M2GrantsIFrames", false)
			if ok and type(v) == "boolean" then return v end
		end
		if GameData.cfg.GetStyleConfig then
			local ok, sc = pcall(GameData.cfg.GetStyleConfig, style)
			if ok and type(sc) == "table" and type(sc.M2GrantsIFrames) == "boolean" then
				return sc.M2GrantsIFrames
			end
		end
	end
	return false
end

function State.ap.reachM2()
	local base = Config.AP_M2BaseReach or 6.5
	loadGameModules()
	if GameData.cfg then
		if GameData.cfg.GetStyleHitboxForwardOffset then
			local ok, fwd = pcall(GameData.cfg.GetStyleHitboxForwardOffset, styleOf(localChar()), "M2")
			if ok and type(fwd) == "number" then base = fwd + 1.5 end
		end
		if GameData.cfg.GetStyleNumber then
			local oks, step = pcall(GameData.cfg.GetStyleNumber, styleOf(localChar()), "M2StepForwardStuds", 0)
			if oks and type(step) == "number" and step > 0 then base = base + step end
		end
	end
	local _, _, myH = heightDiag(localChar())
	if type(myH) == "number" and myH > 0 then
		base = base * math.clamp(myH / (Config.AP_RefHeight or 5.5), 0.85, 1.45)
	end
	return base
end

function State.ap.m2Ready()
	local c = localChar()
	if not c then return false end
	if c:GetAttribute("M2Cooldown") == true or c:GetAttribute("M2CD") == true then return false end
	if c:GetAttribute("M2") == true or c:GetAttribute("PendingM2") == true then return false end
	local lastM2 = State.ap.m2SendLast or 0
	local lastCn = State.lastCounter or 0
	if lastCn > lastM2 then lastM2 = lastCn end
	if (os.clock() - lastM2) < (Config.AP_M2Gap or 0.30) then return false end
	return true
end

function State.ap.fireM2(model, why, variant)
	local ap = State.ap
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	ap.snapTo(hrp)
	local c = localChar()
	if State.blocking or (c and c:GetAttribute("Blocking") == true) then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		pcall(sendDeactivate, true)
	end
	if variant then steerM2Variant(variant) end
	local ok = pcall(function()
		ServerRemote:FireServer({ Type = "Combat", Action = "M2", Func = "ServerCheck" })
	end)
	if not ok then return false end
	local now = os.clock()
	ap.m2SendLast    = now
	State.lastCounter = now
	State.flashUntil = now + 0.25
	State.apM2Count  = (State.apM2Count or 0) + 1
	return true
end

function State.ap.interruptible(th)
	if not th or not th.attackerModel or not th.attackerHRP then return false end
	if th.attackerModel:GetAttribute("IFRAMES") == true
	   or th.attackerModel:GetAttribute("HyperArmor") == true then return false end
	if th.kind == "M2" then
		loadGameModules()
		if GameData.cfg and GameData.cfg.GetStyleConfig then
			local ok, sc = pcall(GameData.cfg.GetStyleConfig, th.style or "basic")
			if ok and type(sc) == "table"
			   and (sc.M2GrantsIFrames == true or sc.M2GrantsHyperArmor == true) then return false end
		end
	end
	return true
end

function State.ap.tryInterrupt(now, th, threatCount)
	local ap = State.ap
	if not Config.AutoPlay or Config.AP_Interrupt ~= true then return false end
	if not th or th.pressed or th.dodged or th.interruptAttempted then return false end
	if th.kind ~= "M1" and th.kind ~= "M2" then return false end
	if isMustDodge(th) then return false end
	-- ПРИОРИТЕТ РАЗМЕНА (как просил юзер): если НАШ удар прилетит раньше вражеского,
	-- не пар��руем — сбиваем атакой. Раньше здесь стоял DEFENSE-FIRST-гейт, который
	-- при любой блокируемой угрозе делал return false, т.е. до сравнения скоростей
	-- дело НЕ доходило вообще → «ни разу не видел сбив». Убрано. Единственная защита,
	-- которую оставляем: гонку решает строгое сравнение ниже (own+margin < enemyLeft),
	-- поэтому уронив блок под свинг мы промахнёмся тольк�� если реально не успеваем —
	-- а этот случай отсекается (m1Hit/m2Hit = nil → return false → работает парри).
	--
	-- ВТОРАЯ УГРОЗА рядом: вот тут размен опасен (уронили guard → съели второй удар),
	-- поэтому при мультиугрозе остаёмся в защите.
	if threatCount >= 2 then
		local secondClose = false
		for _, other in ipairs(Threats) do
			if other ~= th and not other.feinted and not other.dodged and not other.pressed then
				local otherDt = other.contactAbs - now
				if otherDt >= 0 and otherDt <= (Config.DodgeHorizon or 0.6) then
					secondClose = true
					break
				end
			end
		end
		if secondClose then return false end
	end
	if not ap.interruptible(th) or not ap.canAttack(true) then return false end
	local enemyLeft = (th.contactAbs or now) - now
	if enemyLeft < 0.05 then return false end
	local baseMargin = th.kind == "M2" and (Config.AP_InterruptMargin or 0.055) * 0.6
	                                    or  (Config.AP_InterruptMargin or 0.055)
	local netLag = getPingRaw() * (Config.AP_InterruptNetK or 0.5)

	local m1Hit, m1Combo = nil, nil
	if ap.flatDist(th.attackerModel) <= ap.reach() then
		local d, combo = ap.ownM1Delay()
		if d then m1Hit, m1Combo = d + netLag, combo end
		if m1Hit and m1Hit + baseMargin >= enemyLeft then m1Hit = nil end
	end

	local m2Hit, m2Var, m2Iframes = nil, nil, false
	if Config.AP_InterruptM2 ~= false and ap.m2Ready()
	   and ap.flatDist(th.attackerModel) <= ap.reachM2() then
		local d, variant = ap.ownM2Delay()
		if d then
			m2Iframes = ap.m2GrantsIFrames()
			if m2Iframes then
				if netLag + (Config.AP_M2IFrameMargin or 0.035) < enemyLeft then
					m2Hit, m2Var = d + netLag, variant
				end
			elseif d + netLag + baseMargin < enemyLeft then
				m2Hit, m2Var = d + netLag, variant
			end
		end
	end

	local useM2 = (m2Hit ~= nil)
	if useM2 and m1Hit and Config.AP_InterruptPreferM2 == false then
		useM2 = m2Hit < m1Hit
	end
	if not useM2 and not m1Hit then return false end

	local ownHit, tag
	if useM2 then
		if not ap.fireM2(th.attackerModel, "interrupt", m2Var) then
			if not m1Hit then return false end
			useM2 = false
		end
	end
	if useM2 then
		ownHit = m2Hit
		tag = string.format("M2%s%s", m2Var and ("/" .. m2Var) or "", m2Iframes and "+IF" or "")
		if m2Iframes then V93.markOwnM2IFrames(now, "interrupt/M2+IF") end
	else
		if not ap.fireM1(th.attackerModel, "interrupt", true, true) then return false end
		ownHit = m1Hit
		tag = string.format("M1/c%d", m1Combo or 0)
	end
	th.interruptAttempted = true
	th.pressed = true            -- мы разменялись атакой — эту угрозу больше НЕ парируем
	State.interruptFiredFrame = _C.FrameId
	State.status = useM2 and "INTERRUPT-M2" or "INTERRUPT"
	diagPush("INTERRUPT t=%.2f %s %s(%s) via=%s ours=%.0fms enemy=%.0fms margin=%.0fms m1=%s m2=%s guard=fallback", now, th.name or "?", th.kind or "?", th.style or "?", tag,
			(ownHit or 0) * 1000, enemyLeft * 1000, baseMargin * 1000,
			m1Hit and string.format("%.0fms", m1Hit * 1000) or "no",
			m2Hit and string.format("%.0fms", m2Hit * 1000) or "no")
	return true
end

function State.ap.fireM1(model, why, priority, dropGuard)
		local ap = State.ap
		local now = os.clock()
		if ap.m1TxnActive(now) then return false end
		if now < ap.nextM1At then return false end
		if not ap.canAttack(dropGuard) then return false end
	local m1 = ap.getM1()
	if not m1 then return false end
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	ap.snapTo(hrp)
	ap.nextM1At = now + (Config.AP_PollGap or 0)
		local swung = false
		-- НАДЁЖНЫЙ путь по умолчанию: родная tryM1() и�� M1-модуля игры.
		-- Она version-proof (сама читает combo/anim/cooldown и шлёт ServerCheck
		-- изнутри), поэтому переживает обновлени�� игры. Хрупкий fast-path
		-- (fireM1Custom с debug.setupvalue по индексам upvalue) включается только
		-- если пользователь ЯВНО отключил AP_ForceNativeM1 — при обновлении ��гры
		-- индексы протухаю��, setupvalue пишет мусор и серве�� отклоняет свинг =
		-- "autoplay не бьёт, а раз не бьёт — стоит и не парирует".
		local useFast = ap.fireOK and (Config.AP_ForceNativeM1 == false)
		if useFast then
			local char = localChar()
			if char then swung = ap.fireM1Custom(char, model, nil, false, priority, dropGuard) end
			if not swung and ap.tryM1Fn then
				local ok, res = pcall(ap.tryM1Fn); swung = ok and res == true
			end
		elseif ap.tryM1Fn then
			local ok, res = pcall(ap.tryM1Fn)
			swung = ok and res == true
		else
			pcall(function() m1.OnM1Activated() end)
			swung = true
		end
		if swung then
			State.status      = "AUTO-M1"
			State.flashUntil  = now + 0.2
			State.autoM1Count = (State.autoM1Count or 0) + 1
		end
	return swung
end

function State.ap.testSwing()
	local ap = State.ap
	if not ap.getM1() then return 0, false end
	local char = localChar()
	if not char then return 0, false end
	local combo
	if Config.AP_ComboMode == "Fixed" then
		combo = math.clamp(math.floor(Config.AP_FixedHit or 1), 1, 4)
		elseif ap.fireOK and ap.tryM1Fn then
			combo = ((debug.getupvalue(ap.tryM1Fn, ap.comboIdx) or 0) % 3) + 1
		else
		combo = 1
	end
	local ok = false
	if ap.fireOK then
		ok = ap.fireM1Custom(char, nil, combo, true)
	elseif ap.tryM1Fn then
		local r; local s = pcall(function() r = ap.tryM1Fn() end); ok = s and r == true
	end
	return combo, ok
end

function State.ap.onPerfectParry(attackerName, kind)
	if not Config.AutoPlay or Config.AP_PunishOnParry == false then return end
	local plr   = attackerName and Players:FindFirstChild(attackerName)
	local model = plr and plr.Character
	if not model then return end
	if Config.BoxingCounter and (os.clock() - (State.lastCounter or 0)) < 0.40 then return end
	local stun = (kind == "M2") and (Config.AP_M2Stun or 1.0) or (Config.AP_M1Stun or 0.5)
	State.ap.punishTgt   = model
	State.ap.punishUntil = os.clock() + stun
	State.ap.punishFresh = true
end

function State.ap.step(now)
	if not Config.AutoPlay or Config.AP_PunishOnParry == false then return end
	local ap = State.ap
	local tgt = ap.punishTgt
	if not tgt then return end
	local hum = tgt.Parent and tgt:FindFirstChildOfClass("Humanoid")
	if (not hum) or hum.Health <= 0 or now > ap.punishUntil then
		ap.punishTgt = nil
		ap.punishFresh = false
		return
	end
	if ap.flatDist(tgt) > ap.reach() then return end
	if State.blocking then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		pcall(sendDeactivate, true)
	end
	if ap.fireM1(tgt, "punish", ap.punishFresh) then ap.punishFresh = false end
end

local function evasiveGranted()
	local c = localChar()
	return c and c:GetAttribute("OutnumberedEvasiveGrant") == true or false
end

local function dodgeReady()
	local c = localChar()
	if (os.clock() - State.lastDodge) < Config.DodgeMinSpacing then return false end
	if c then
		if c:GetAttribute("IFRAMECD") == true then return false end
		local remG = c:GetAttribute("EvasiveCooldownRemaining")
		if type(remG) == "number" and remG > 0 then return false end
	end
	local since = os.clock() - State.lastDodge
	if evasiveGranted() then
		local fullCd = GameData.evPredictCooldown or Config.DodgeCooldown
		local grantFloor = GameData.evCooldown or 1.5
		if (State.dodgeRejects or 0) >= 2 and since < fullCd then
			if not State.dodgeGateSaid then
				State.dodgeGateSaid = true
				diagPush("DODGE-GATE  грант активен, но %d отказа подряд → откат на полный CD %.2fс (прошло %.2fс)", State.dodgeRejects, fullCd, since)
			end
			return false
		end
		if since < grantFloor then
			if not State.dodgeGateSaid then
				State.dodgeGateSaid = true
				diagPush("DODGE-GATE  грант активен → серверный Evasive.Cooldown %.2fс, прошло %.2fс", grantFloor, since)
			end
			return false
		end
		State.dodgeGateSaid = nil
		return true
	end
	if Config.UseServerCooldown and c then
		return true
	end
	return since >= (GameData.evPredictCooldown and (GameData.evPredictCooldown + 0.05)
		or Config.DodgeCooldown)
end

local function canDodgeNow(force)
	local c = localChar()
	if not c then return false, "no-char" end
	if c:GetAttribute("Equip") == false then return false, "Unequipped" end
	for _, attr in ipairs(Config.DodgeHardStates) do
		if c:GetAttribute(attr) == true then return false, attr end
	end
	if not force and not evasiveGranted() and Config.NoDodgeWhileStunned
	   and (c:GetAttribute("Stunned") == true or c:GetAttribute("CantAnything") == true) then
		return false, "Stunned"
	end
	if c:GetAttribute("CombatAttacking") == true then return false, "CombatAttacking" end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum and (hum.Health <= 0
	   or hum:GetState() == Enum.HumanoidStateType.Dead
	   or hum:GetState() == Enum.HumanoidStateType.Physics) then
		return false, "humanoid-state"
	end
	return true, nil
end

local function releaseBlock()
	if not State.blocking then return end
	State.blocking  = false
	State.holdUntil = 0
	-- Момент снятия блока: от него игра отсчитывает Block.CooldownSeconds=0.5,
	-- и планировщик размена обязан это знать, чтобы не планировать второе парри,
	-- которое сервер всё равно отклонит (в логе это было `refused: BlockCooldown`).
	State.lastBlockRelease = os.clock()
	sendDeactivate(true)
end

local function fireBlock(tsServer)
	if not Config.Enabled then return nil end
	local ok, reason = canBlockNow()
	if not ok then
		State.blockedReason = reason
		return nil
	end
	State.blockedReason = nil
	if not sendActivate(tsServer) then return nil end
	State.blocking   = true
	State.lastPress  = os.clock()
	State.fireCount  = State.fireCount + 1
	State.status     = "PARRY"
	State.flashUntil = os.clock() + 0.14
	return tsServer
end

local refreshContact = function(th)
	local now = os.clock()
	if th.kind == "M2" and not th.variantLocked and th.attackerModel then
		local av = th.attackerModel:GetAttribute("M2VariantId")
		if type(av) == "string" and av ~= "" then
			th.variantLocked = true
			if av ~= th.variant then
				local prev = th.hitTL
				th.variant = av
				local newTL = hitTimeline({ t = "M2", s = th.style, mom = th.mom, id = th.id,
					variant = av, name = th.animName }, th.combo, th.attackMult)
				if type(newTL) == "number" and newTL > 0 then
					th.hitTL = newTL
					-- newTL пришёл из hitTimeline(), он уже в реальных секундах.
					th.hitTLReal = newTL
					-- newTL/prev — ANIM-время, дельту перевод��м в wall живой скоростью,
					-- иначе на высоком пинге правка варианта уез��ала в разы
					local dAnim = newTL - (prev or newTL)
					th.contact0 = math.max(0, (th.contact0 or 0)
						+ animToWall(dAnim, th.track, th.attackMult, newTL))
					diagPush("VARIANT t=%.2f  %s  M2 → %s  hitTL %.0f→%.0fms (server attr)", now, tostring(th.name), av, (prev or 0)*1000, newTL*1000)
				end
			end
		end
	end
	local remaining = th.contact0 - (now - th.detectClock)

	local playing = true
	if th.track then
		playing = safeGet(th.track, "IsPlaying", true)
		local tp = safeGet(th.track, "TimePosition", th.initTP)
		if type(tp) ~= "number" then tp = th.initTP end

		local lastTP    = th.lastTP or th.initTP
		local lastClock = th.lastTPClock or th.detectClock
		local dtReal    = now - lastClock
		-- КВАНТОВАНИЕ КАДРОВ. TimePosition двигается ДИСКРЕТНО — раз в кадр (13мс
		-- при 76fps). Замер на и��тервале короче кадра даёт мусор: tp прыгает на
		-- целый кадр (0.013), а dtReal=0.002 → "скорость" 6.5x. Порог был 0.0005с,
		-- поэтому ПЕРВЫЙ же сэмпл (+2мс после детекта) давал liveSpeed=4.6..9.3, и
		-- ниже liveRemain=(0.364-0.008)/4.67 = 76мс вместо 356мс. Скрипт жал
		-- мгновенно, блок вставал за ~360мс до удара, сервер видел
		-- guard=EARLY(>125) → ОБЫЧНЫЙ БЛОК ВМЕСТО ПАРИРОВАНИЯ на каждой атаке.
		-- Мерим на окне >= 2 кадров и зажимаем по ЗАЯВЛЕННОЙ скорости трека.
		local minDt = math.max(Config.LiveSpeedMinDt or 0.03, (V93.frameDt or 1/60) * 2)
		if dtReal >= minDt then
			local inst = (tp - lastTP) / dtReal
			if inst < 0 then inst = 0 end
			local decl = safeGet(th.track, "Speed", nil)
			if type(decl) ~= "number" or decl <= 0.01 then
				decl = math.max(th.initSpeed or 1, 0.05)
			end
			inst = math.min(inst, decl * (Config.LiveSpeedMaxFactor or 1.5))
			local a = Config.LiveSpeedSmooth or 0.35
			th.liveSpeed   = th.liveSpeed and (th.liveSpeed * (1 - a) + inst * a) or inst
			th.liveSamples = (th.liveSamples or 0) + 1
			th.lastTP = tp; th.lastTPClock = now
		end
		-- Нет н�� одного валидного замера → live-скорости нет, остаток берём из
		-- аним-таймлайна, а не из шума.
		local liveOk = (th.liveSamples or 0) >= (Config.LiveSpeedMinSamples or 1)

		if playing and tp > (th.maxTP or th.initTP) + 0.0005 then
			th.maxTP = tp; th.trackSeen = true; th.lastAdvanceClock = now
			if not th.firstProgressClock then
				th.firstProgressClock = now
				diagPush("TRACE-ANIM t=%.3f %s %s s%d firstProgress=%+.0fms tp=%.3f init=%.3f live=%.2f(n=%d) decl=%.2f", now, th.name or "?", th.kind or "?", th.strike or 1,
						(now-th.detectClock)*1000, tp, th.initTP or 0, th.liveSpeed or 0,
						th.liveSamples or 0, safeGet(th.track, "Speed", 0))
			end
		elseif not playing and not th.trackStopClock then
			th.trackStopClock = now
			diagPush("TRACE-ANIM t=%.3f %s %s s%d stopped=%+.0fms tp=%.3f maxTP=%.3f hitTL=%.3f", now, th.name or "?", th.kind or "?", th.strike or 1,
					(now-th.detectClock)*1000, tp, th.maxTP or th.initTP or 0, th.hitTL or 0)
		end

		if th.kind == "M1" and playing and Config.LiveM1Timer ~= false then
			-- Порог тоже в РЕАЛЬНОМ времени: таймер хитбокса срабатывает на
			-- hitTLReal = hitTL/aMult, то есть РАНЬШЕ аним-позиции hitTL.
			local hbReal = th.hitTLReal or th.hitTL
			if tp / tpSpeed(th.track) < hbReal - 0.001 and liveOk then
				local nominal = math.max(th.initSpeed or 1, 0.05)
				local floor   = nominal * (Config.LiveM1SpeedFloor or 0.45)
				local sp      = math.max(th.liveSpeed or nominal, floor)
				-- Момент удара — таймер (делится на aMult), прошедшее время — tp.
				local liveRemain = hbReal - tp / math.max(sp, 0.05)
				-- ФИКС: было math.max(remaining, liveRemain) — таймер умел только
				-- ОТОДВИГАТЬ удар. Если анимация шла быстрее прогноза (низкий пинг,
				-- маленький рост, перк SwiftHands +12.5%), скрипт держал устаревший
				-- contact0 и нажимал ПОЗЖЕ окна ��� пропуск или обычный блок.
				-- Живая позиция анимации — источник истины, она и решает.
				remaining = math.clamp(liveRemain, 0, Config.MaxWait or 2)
			end
		elseif (th.kind == "M2" or th.kind == "SKILL") and playing then
			local hbReal2 = th.hitTLReal or th.hitTL
			if Config.LiveHeavyTimer and tp / tpSpeed(th.track) < hbReal2 - 0.001 and liveOk then
				local nominal = math.max(th.initSpeed or 1, 0.05)
				local floor   = nominal * (Config.LiveSpeedFloor or 0.15)
				local sp      = math.max(th.liveSpeed or nominal, floor)
				local liveRemain = hbReal2 - tp / math.max(sp, 0.05)
				-- M2 можно держа��ь (charge) → liveSpeed падает и liveRemain растёт,
				-- поэтому раньше брали только max. Но при ускоренной анимации это
				-- держало устаревший прогноз и мы опаздывали. Живая позиция
				-- авторитетна; удержание само себя учитывает через sp.
				local held = th.liveSpeed and th.liveSpeed < nominal * 0.6
				remaining = held and math.max(remaining, liveRemain)
					or math.clamp(liveRemain, 0, Config.MaxWait or 2)
				th.heldBy = held and
					(liveRemain - math.max(th.contact0 - (now - th.detectClock), 0)) or 0
			else
				local stalledFor = now - (th.lastAdvanceClock or th.detectClock)
				if tp < th.hitTL - 0.001 and stalledFor > (Config.ChargeStallMs / 1000) then
					-- (th.hitTL - tp) — ANIM-время, нельзя подставлять как wall-время:
					-- на высоком пинге Speed<1 и остаток реально ДОЛЬШЕ. Переводим.
					remaining = math.max(remaining,
						animToWall(th.hitTL - tp, th.track, th.attackMult, th.hitTL))
				end
			end
		end

		if th.kind == "M1" and th.trackSeen and not playing and not th.feinted then
			local reached = (th.maxTP or th.initTP)
			local nearContact = (th.contactAbs - now) <= Config.FeintGraceMs / 1000
			if reached < th.hitTL * Config.FeintFrac and not nearContact then
				th.feinted = true
			end
		end
	end

	th.trackPlaying = playing
	-- Сдвигаем прогноз на скрытый пол-пинг атакующего (track.Speed его не видит).
	-- Без этого contactAbs систематически РАНЬШЕ реального → жмём до окна = блок.
	-- Вместо обучаемой поправки — ДЕТЕРМ��НИРОВАННАЯ задержка до реального оверлапа
	-- (см. расчёт в willHitMe). residContactBias учился на predErr, а predErr для
	-- удачных парри ЗАГРЯЗНЁН: `meas` — это момент ОСТАНОВКИ анимации, а она
	-- останавливается именно потому, что наше парри застанило атакующего. Отсюда
	-- в логе у всех PERFECT predErr ≈ -30мс, и обучение тянуло тайминг в сторону,
	-- вызванную нашим же успехом. Такой сигнал использовать ��ельзя.
	remaining = math.max(remaining, 0) + (th.ovDelay or 0)
	th.contactAbs = now + remaining
	if (th.ovDelay or 0) > 0.015 and not th.ovLogged and Config.DeepDiag then
		th.ovLogged = true
		diagPush("OV-DELAY t=%.2f %s %s удар доворотный: +%.0fms до реального оверлапа (зазор сбоку=%.1f глубина=%.1f | доворот=%.1fрад/с сближение=%.1f)",
			now, tostring(th.name), tostring(th.kind), (th.ovDelay or 0) * 1000,
			th.ovGapSide or 0, th.ovGapDepth or 0, th.turnRate or 0, th.closeVel or 0)
	end
	return remaining
end

local function insideAutoFOV(attackerHRP)
	local fov = math.clamp(tonumber(Config.FOV) or 360, 1, 360)
	if fov >= 359.5 then return true end
	local cam = Workspace.CurrentCamera
	if not cam or not attackerHRP then return true end
	local ok, point, visible = pcall(function()
		local p, onScreen = cam:WorldToViewportPoint(attackerHRP.Position)
		return p, onScreen
	end)
	if not ok or not point or point.Z <= 0 or not visible then return false end
	local vp = cam.ViewportSize
	local dx, dy = point.X - vp.X * 0.5, point.Y - vp.Y * 0.5
	local focal = math.max(vp.Y * 0.5, 1)
	local angle = math.deg(math.atan(math.sqrt(dx * dx + dy * dy) / focal))
	return angle <= fov * 0.5
end

local function _attrTrue(m, a) return m:GetAttribute(a) == true end
local function serverAttackProof(model)
	if not model then return false end
	local ok, v = pcall(_attrTrue, model, "M1")
	if ok and v then return true end
	ok, v = pcall(_attrTrue, model, "M2")
	if ok and v then return true end
	ok, v = pcall(_attrTrue, model, "CombatAttacking")
	return (ok and v) and true or false
end

-- ФИЗИЧЕСКИЙ ПРЕДЕЛ ДОСЯГАЕМОСТИ, выведенный из самой игры, а не подобранный на глаз.
-- VictimHitboxServiceClient принимает удар только если
--   (hitbox.Position - myHRP.Position).Magnitude <= hitbox.Size.Magnitude/2 + 6
-- и затем бокс реально пересекает нас. Хитбокс ставится перед атакующим на
-- DefaultHitboxForwardOffset (M1=4, M2=3). Размеры берём с живых хитбоксов
-- (V93.sizes заполняется при индексации workspace.Hitboxes), пока их нет — консервативно.
-- Дальше этого расстояния свинг не может достать даже при полном довороте, поэтому
-- реагировать на него незачем: именно такие свинги в логе шли как dist=25..45 и
-- потом отлетали в geometry-rejected, успев раздуть кластер.
local function reachLimit(kind)
	local sz = V93.sizes and V93.sizes[kind]
	local half = 4.5
	if sz then
		local flat = Vector3.new(sz.X, 0, sz.Z).Magnitude
		if flat > 0 then half = flat / 2 end
	end
	local off = (kind == "M2") and 3 or 4
	return off + half + 6 + (Config.ReachSlack or 1)
end

local function serverHitboxProof(ownerName)
	if not ownerName then return false end
	local folder = Workspace:FindFirstChild("Hitboxes")
	if not folder then return false end
	for _, part in ipairs(folder:GetChildren()) do
		local o = part:FindFirstChild("Owner")
		if o and o.Value == ownerName then
			local a = part:FindFirstChild("AttackName")
			local an = a and a.Value
			if an == "M1" or an == "M2" then return true end
		end
	end
	return false
end

local onAttack = function(attackerHRP, info, model, id, track)
	local myHRP = localHRP()
	if not myHRP then return end
	if not insideAutoFOV(attackerHRP) then return end
	if isWingChunCounterStance(info, id) then
		if model then
			WingChunCounter[model] = os.clock() + (_D.WINGCHUN.CounterWindow or 0.5)
		end
		diagPush("WINGCHUN t=%.2f  %s поднял counter-стойку → окно %.0fms: НЕ парируем (урона нет), не атакуем (вернётся контра %.1fс стана)",
			os.clock(), tostring(model and model.Name or "?"),
			(_D.WINGCHUN.CounterWindow or 0.5) * 1000, _D.WINGCHUN.VictimHitStun or 2.2)
		return
	end
	local dist = (attackerHRP.Position - myHRP.Position).Magnitude
	-- Предел берём из геометрии игры (reachLimit), а не из подобранной константы:
	-- Config.Range остаётся лишь верхней страховкой.
	-- resolveInfo возвращает вид удара в поле `t` (не `kind`).
	local kindGuess = (info and info.t) or "M1"
	local reachMax = math.min(reachLimit(kindGuess), Config.Range)
	if dist > reachMax then
		local closingSpeed = 0
		pcall(function()
			local toMe = (myHRP.Position - attackerHRP.Position)
			local flat = Vector3.new(toMe.X, 0, toMe.Z)
			if flat.Magnitude > 0.1 then
				local av = attackerHRP.AssemblyLinearVelocity
				-- ЗНАК БЫЛ ПЕРЕВЁРНУТ. flat смотрит ОТ атакующего К нам, поэтому у
				-- сближающегося врага dot уже положителен, а минус делал его
				-- отрицательным → math.max(...,0) обнулял запас именно тем, кто бежит
				-- на нас, и наоборот раздавал его убегающим.
				closingSpeed = Vector3.new(av.X, 0, av.Z):Dot(flat.Unit)
			end
		end)
		-- Запас считаем по РЕАЛЬНОМУ времени замаха, а не по MaxWait=1.6с, и жёстко
		-- ограничиваем: иначе бегущий мимо враг «дотягивался» с 35 студов.
		local canClose = math.max(closingSpeed, 0) * (Config.ReachCloseWindow or 0.35)
		local closeCap = Config.ReachCloseCap or 8
		if canClose > closeCap then canClose = closeCap end
		if dist > reachMax + canClose then return end
	end
	if info.t == "M2" and not Config.HeavyEnabled then return end

	local plr  = Players:GetPlayerFromCharacter(model)
	local name = plr and plr.Name or model.Name

	local suspectSwing = false
	if Config.AntiDecoy then
		local sig = State.antiDecoySig; if not sig then sig = {}; State.antiDecoySig = sig end
		local cnt = State.antiDecoyCount; if not cnt then cnt = {}; State.antiDecoyCount = cnt end
		local nowc = os.clock()
		local prev = sig[name]
		if prev and (nowc - prev) < (Config.AntiDecoyGap or 0.12) then
			cnt[name] = (cnt[name] or 1) + 1
			if cnt[name] > (Config.AntiDecoyMaxBurst or 3) then
				if (nowc - (State.lastAntiDecoyLog or 0)) > 1 then
					State.lastAntiDecoyLog = nowc
					aclog(string.format("[decoy] burst cap %dx %s from %s — dropped", cnt[name], tostring(info.t), name))
				end
				return
			end
			suspectSwing = true
			if (nowc - (State.lastAntiDecoyLog or 0)) > 1 then
				State.lastAntiDecoyLog = nowc
				aclog(string.format("[resolver] rapid %s from %s — kept as SUSPECT (needs swing-id proof)", tostring(info.t), name))
			end
		else
			cnt[name] = 1
		end
		sig[name] = nowc
	end

	local attrProof = serverAttackProof(model)

	local combo = (info.t == "M1") and (info.combo or nextCombo(name)) or 1

	local aMult    = attackSpeedMult(model)
	local heightAttr, bodyHeightScale, modelHeight = heightDiag(model)
	local speed    = 1
	local already  = 0
	if track then
		local okS, sp = pcall(function() return track.Speed end)
		if okS and type(sp) == "number" and sp > 0.05 then speed = sp end
		local okT, tp = pcall(function() return track.TimePosition end)
		if okT and type(tp) == "number" and tp > 0 then already = tp end
	end
	-- ЕДИНИЦЫ: всё ниже — РЕАЛЬНЫЕ секунды от начала свинга.
	-- hitTimeline() возвращает (d+windup)/aMult, уже реальное время.
	-- info.contacts (мультихит Boxing M2) — сырые аним-метки, их надо поделить на
	-- aMult самим, иначе мультихит окажется в других единицах, чем обычный удар.
	local aDiv  = (type(aMult) == "number" and aMult > 0.05) and aMult or 1
	local hitTL = (info.contacts and info.contacts[1] and (info.contacts[1] / aDiv))
		or hitTimeline(info, combo, aMult)
	local effSpd, spdSrc = effAnimSpeed(track, aMult, hitTL)
	-- hitTimeline() УЖЕ вернул (d+windup)/aMult в РЕАЛЬНЫХ секундах, поэтому делить
	-- второй раз нельзя. Прошедшее время: TimePosition тикает 1:1 с реальным
	-- временем (в логе V176 age==tp*1000 на всех выборках, spd=1.00), но делим на
	-- tpSpeed на случай, если игра когда-нибудь начнёт менять скорость трека.
	local hitTLReal  = hitTL
	local remaining0 = math.max(0, hitTLReal - already / tpSpeed(track))
	if remaining0 > Config.MaxWait then return end

	local vlead = velLead(attackerHRP)
	local nowClock  = os.clock()
	local nowServer = Workspace:GetServerTimeNow()
	local netOneWay, statsRtt = pingDiagSnapshot()
	local pingRawDetect, pingMedDetect, uplinkDetect = getPingRaw(), getPing(), uplink()
	local trackLength, trackPlaying = 0, false
	if track then
		pcall(function() trackLength = track.Length end)
		pcall(function() trackPlaying = track.IsPlaying end)
	end
	local th = {
		name = name, kind = info.t, style = info.s, mom = info.mom, id = id,
		combo = combo, variant = info.variant, animName = info.name,
		-- initSpeed: если трека нет, берём предсказанную (rост × ping-компенсация),
		-- иначе floor для liveSpeed считался бы от фиктивной 1.0
		track = track, hitTL = hitTL, hitTLReal = hitTLReal, initTP = already,
		initSpeed = (track and speed) or effSpd, effSpd = effSpd, spdSrc = spdSrc,
		detectClock = nowClock, detectServer = nowServer, contact0 = remaining0,
		contactAbs = nowClock + remaining0, velLead = vlead,
		attackerHRP = attackerHRP, attackerModel = model,
		heightAttr = heightAttr, bodyHeightScale = bodyHeightScale, modelHeight = modelHeight,
		attackMult = aMult,
		pingOneWayDetect = netOneWay, pingStatsDetect = statsRtt,
		pingRawDetect = pingRawDetect, pingMedDetect = pingMedDetect, uplinkDetect = uplinkDetect,
		trackLengthDetect = trackLength, trackPlayingDetect = trackPlaying,
		attackerPosDetect = attackerHRP.Position, victimPosDetect = myHRP.Position,
		attackerVelDetect = attackerHRP.AssemblyLinearVelocity, victimVelDetect = myHRP.AssemblyLinearVelocity,
		pressed = false, dodged = false,
		pressDt = nil,
		faceDot = nil,
		suspect = suspectSwing,
		serverProven = (not suspectSwing) and attrProof or false,
		provenBy = ((not suspectSwing) and attrProof) and "attr" or nil,
		serverProofClock = nil,
	}
	-- Начальный прогноз оставляем ЧИСТО аним-временем. Обученный сдвиг убран: на
	-- первом кадре геометрии ещё нет, а угадывать нечем — per-frame computeRemaining
	-- добавит детерминированную задержку оверлапа сразу, как появится геометрия
	-- (это происходит на том же кадре, до момента нажатия).
	if th.serverProven then th.serverProofClock = nowClock end
	if track then
		for i = #Threats, 1, -1 do
			local old = Threats[i]
			if old.name == name and old.track == track and not old.resolved and not old.staleTrack then
				old.staleTrack = true
				if Config.DeepDiag then
					diagPush("TRACE-STALE t=%.3f %s %s superseded: same track restarted (age=%.0fms, was dt=%+.0fms)", nowClock, name, tostring(old.kind),
							(nowClock - old.detectClock) * 1000,
							(old.contactAbs - nowClock) * 1000)
				end
			end
		end
	end
	Threats[#Threats+1] = th

	do
		local key = model or attackerHRP or name
		if key then
			State.lastSwingBy = State.lastSwingBy or setmetatable({}, { __mode = "k" })
			State.swingGapBy  = State.swingGapBy or setmetatable({}, { __mode = "k" })
			local prev = State.lastSwingBy[key]
			if prev then State.swingGapBy[key] = nowClock - prev end
			State.lastSwingBy[key] = nowClock
		end
	end

	local rec = { clock = nowClock, detectServer = nowServer, type = info.t, style = info.s,
	              id = id, contact = remaining0, pingRaw = pingRawDetect, combo = combo,
	              speed = speed, matched = false, th = th, strike = 1 }
	th.rec = rec
	local q = Pending[name]; if not q then q = {}; Pending[name] = q end
	q[#q+1] = rec
	if info.contacts and info.contacts[2] then
		local group = { cancelled = false, held = false }
		th.group, th.strike = group, 1
		-- второй контакт тоже в ANIM-времени; в wall переводим той же живой скоростью
		-- Те же единицы, что и у первого контакта: реальные секунды.
		local hit2     = info.contacts[2] / aDiv
		local hit2Real = hit2
		local rem2 = math.max(0, hit2Real - already / tpSpeed(track))
		local th2 = table.clone(th)
		th2.hitTL, th2.hitTLReal, th2.contact0, th2.contactAbs = hit2, hit2Real, rem2, nowClock + rem2
		-- Втор��й удар связки тоже без обученного сдвига — задержку оверлапа посчитает
		-- computeRemaining по живой геометрии на своём кадре.
		group.lastContact = th2.contactAbs
		th2.strike, th2.pressed, th2.dodged = 2, false, false
		th2.pressDt, th2.faceDot, th2.rec = nil, nil, nil
		th2.hitboxSeen, th2.hitboxSynced, th2.hitboxPart = nil, nil, nil
		Threats[#Threats+1] = th2
		local rec2 = { clock = nowClock, detectServer = nowServer, type = info.t, style = info.s,
			id = id, contact = rem2, pingRaw = rec.pingRaw, combo = combo,
			speed = speed, matched = false, th = th2, strike = 2 }
		th2.rec = rec2
		q[#q+1] = rec2
		diagPush("MULTI  t=%.2f  %s M2(Boxing) contacts=[%.0f,%.0f]ms markers=[%.0f,%.0f]ms speed=%.2f", nowClock, name, remaining0*1000, rem2*1000,
				info.contacts[1]*1000, info.contacts[2]*1000, speed)
	end
	while #q > 10 do table.remove(q, 1) end

	State.lastThreat = { name = name, type = info.t, dist = dist, hitIn = remaining0 }
	if State.status ~= "PARRY" then State.status = "THREAT" end
	State.parryCount = State.parryCount + 1

	if Config.DeepDiag then
		diagPush("TRACE-DETECT t=%.3f srv=%.3f %s %s id=%s tp=%.3f/%.3f spd=%.2f playing=%s | net1w=%sms statsRTT=%sms rawRTT=%.0fms medRTT=%.0fms uplink=%.0fms | av=(%.1f,%.1f) mv=(%.1f,%.1f)", nowClock, nowServer, name, info.t, tostring(id), already, trackLength or 0, speed,
				tostring(trackPlaying), netOneWay and string.format("%.0f", netOneWay*1000) or "?",
				statsRtt and string.format("%.0f", statsRtt*1000) or "?", pingRawDetect*1000,
				pingMedDetect*1000, uplinkDetect*1000,
				th.attackerVelDetect.X, th.attackerVelDetect.Z, th.victimVelDetect.X, th.victimVelDetect.Z)
		local pRaw  = pingRawDetect
		local pMult = hitTL / (hitTL + math.clamp(pRaw * 0.5, 0, 0.35))
		diagPush("SWING  t=%.2f  %s  %s(%s)  combo=%d  dist=%.0f  contact=%.0fms  spd=%.2f  aMult=%.2f  height=%s  bodyScale=%s  modelY=%s  pingMult=%.2f  hitTL=%.0fms  vlead=%.0fms  ping=%.0f", os.clock(), name, info.t, info.s, combo, dist, remaining0*1000, speed, aMult,
				heightAttr and string.format("%.3f", heightAttr) or "?",
				bodyHeightScale and string.format("%.3f", bodyHeightScale) or "?",
				modelHeight and string.format("%.2f", modelHeight) or "?",
					pMult, hitTL*1000, vlead*1000, pRaw*1000)
			-- Новая диагностика anim-time модели: видно, берё�� ли живой Speed или
			-- предсказываем, и насколько ping-компенсация растянула удар.
			diagPush("ANIMTIME t=%.2f %s %s  animContact=%.0fms  effSpd=%.3f(%s)  wall=%.0fms  pingComp=%.0fms  window=%.0fms",
					os.clock(), name, info.t, hitTL*1000, effSpd, spdSrc, remaining0*1000,
					math.clamp((select(2, pcall(function() return LocalPlayer:GetNetworkPing() end)) or 0) * 0.5,
						0, GameData.animPingCap or Config.AnimPingCompMax or 0.35)*1000,
					((Config.PerfectWindowLive ~= false and GameData.perfectWindow)
						or Config.PerfectWindow or 0.125)*1000)
		end
end

local function dirIsClear(origin, dir, allowedModel)
	if not Config.DodgeWallCheck then return true end
	local char = localChar()
	if not char then return true end
	local params = V93.dodgeParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		V93.dodgeParams = params
	end
	if V93.dodgeChar ~= char then
		V93.dodgeChar = char
		local ok = pcall(function() params.FilterDescendantsInstances = { char } end)
		if not ok then return true end
	end
	local hit
	pcall(function() hit = Workspace:Raycast(origin, dir.Unit * Config.DodgeWallDist, params) end)
	if not hit then return true end
	local part = hit.Instance
	if part and (not part.CanCollide or part:IsDescendantOf(char or part)
		or (allowedModel and part:IsDescendantOf(allowedModel))) then return true end
	return false
end

-- Возвращает направление доджа. Режим Config.DodgeMode:
--   Defensive  → уходим ОТ врага (ретрит).
--   Aggressive → обкручиваем врага по орбите + подрезаем внутрь (сближение).
-- preferBack форсирует ретрит независи��о от режима (must-dodge/escape уходы).
local function bestDodgeDir(now, preferBack)
	local me = localHRP(); if not me then return nil, false end
	local best, bestC
	for _, th in ipairs(Threats) do
		if th.threatens and th.attackerHRP and th.attackerHRP.Parent then
			if not bestC or th.contactAbs < bestC then best, bestC = th, th.contactAbs end
		end
	end
	if not best then return nil, false end
	local aHRP  = best.attackerHRP
	local aLook = aHRP.CFrame.LookVector
	local flook = Vector3.new(aLook.X, 0, aLook.Z)
	local toMe  = me.Position - aHRP.Position
	toMe = Vector3.new(toMe.X, 0, toMe.Z)
	if toMe.Magnitude < 0.05 then return nil, false end
	local away = toMe.Unit
	local toward = -away
	-- перпендикуляр к линии враг↔я = касательная к орбите вокру�� врага
	local orbit = Vector3.new(-toMe.Z, 0, toMe.X).Unit
	-- если знаем ��уда враг смотрит — орбитим в ту же с��ор����ну, куда он доворачи��ает
	if flook.Magnitude >= 0.05 then
		flook = flook.Unit
		local perp = Vector3.new(-flook.Z, 0, flook.X)
		if perp:Dot(orbit) < 0 then orbit = -orbit end
	end

	local aggressive = (Config.DodgeMode == "Aggressive") and not preferBack
	local candidates
	if aggressive then
		-- обкрутка: касательная + подрезка внутрь к врагу (сближение)
		local close = math.clamp(tonumber(Config.DodgeAggroClose) or 0.45, 0, 1)
		candidates = {
			(orbit + toward * close).Unit,
			(-orbit + toward * close).Unit,
			orbit,
			-orbit,
			toward,
		}
	elseif preferBack or Config.DodgeMode ~= "Aggressive" then
		-- Defensive / форс-ретрит: уходим от врага
		candidates = {
			away,
			(away * 0.7 + orbit * 0.5).Unit,
			(away * 0.7 - orbit * 0.5).Unit,
			orbit,
			-orbit,
		}
	end
	local origin = me.Position
	for _, dir in ipairs(candidates) do
		if dir and dir.Magnitude > 0.05 and dirIsClear(origin, dir) then
			return dir.Unit, false
		end
	end
	return nil, true
end

function State.bestAliForwardDodgeDir(th)
	local me = localHRP()
	local aHRP = th and th.attackerHRP
	if not me or not aHRP or not aHRP.Parent then return nil, "no-target" end

	local origin = th.geomOrigin or aHRP.Position
	local look = th.geomLook
	if not look or look.Magnitude < 0.05 then
		local lv = aHRP.CFrame.LookVector
		look = Vector3.new(lv.X, 0, lv.Z)
	end
	if look.Magnitude < 0.05 then return nil, "no-look" end
	look = look.Unit
	local forward = tonumber(th.geomForward) or 0
	local target = origin + look * forward
	local delta = target - me.Position
	local toward = Vector3.new(delta.X, 0, delta.Z)
	local targetDist = toward.Magnitude
	if targetDist < 0.05 then return nil, "already-in-sweet-spot" end
	toward = toward.Unit
	local side = Vector3.new(-toward.Z, 0, toward.X)
	local allowed = aHRP.Parent
	local duration = math.max(tonumber(Config.DashDuration) or 0.2, 0.05)
	local maxTravel = (tonumber(Config.DashSpeed) or 30) * duration
	local travel = math.min(targetDist, maxTravel)
	local speed = travel / duration
	local startDelta = aHRP.Position - me.Position
	local startDist = Vector3.new(startDelta.X, 0, startDelta.Z).Magnitude
	local candidates = {
		{ toward, "hitbox-center", speed },
		{ (toward * 0.8 + side * 0.35).Unit, "hitbox-center-side", speed },
		{ (toward * 0.8 - side * 0.35).Unit, "hitbox-center-side", speed },
	}
	for _, candidate in ipairs(candidates) do
		if dirIsClear(me.Position, candidate[1], allowed) then
			return candidate[1], candidate[2], candidate[3], startDist, targetDist, travel
		end
	end
	return nil, "blocked"
end

local function performDodge(now, reason, preferBack, force, bypassAutoOff, dodgeTarget)
	if Config.AutoDodge == false and not bypassAutoOff then
		if State.lastDodgeRefuse ~= "AutoDodge-off" then
			State.lastDodgeRefuse = "AutoDodge-off"
			diagPush("DODGE-SKIP t=%.2f  %s  (AutoDodge disabled)", now, reason)
		end
		return false
	end
	local tx0 = State.dodgeTxn
	if tx0 and tx0.pending then return false end
	do
		local ch0 = localChar()
		if ch0 and (ch0:GetAttribute("IFRAMES") == true or ch0:GetAttribute("UltraInstinct") == true) then
			if State.lastDodgeRefuse ~= "already-iframed" then
				State.lastDodgeRefuse = "already-iframed"
				diagPush("DODGE-SKIP t=%.2f  %s  (already invulnerable: IFRAMES live, src=%s)", now, reason, tostring(State.ownIFrameTag or "game"))
			end
			return false
		end
	end
	local can, why = canDodgeNow(force)
	if not can then
		if State.lastDodgeRefuse ~= why then
			State.lastDodgeRefuse = why
			diagPush("DODGE-SKIP t=%.2f  %s  (cannot dodge: %s)", now, reason, tostring(why))
		end
		return false
	end
	State.lastDodgeRefuse = nil

	local granted = evasiveGranted()
	local isAliAbuse = reason == "ali-dodge-abuse"
	local timingTarget = dodgeTarget
	if not timingTarget then
		for _, candidate in ipairs(Threats) do
			if type(candidate.contactAbs) == "number" and candidate.contactAbs >= now
			   and not candidate.resolved and not candidate.coveredByDodge
			   and (not timingTarget or candidate.contactAbs < timingTarget.contactAbs) then
				timingTarget = candidate
			end
		end
	end
	-- Capoeira M2: доджить ТОЛЬКО назад, независимо от Dodge Mode (Defensive/Aggressive).
	-- Форсим preferBack и запрещаем агрессивн��ю орбиту для этого доджа.
	local forceBackOnly = false
	do
		local ct = timingTarget
		if ct and ct.kind == "M2" and type(ct.style) == "string" and ct.style:lower() == "capoeira" then
			forceBackOnly = true
			preferBack = true
			if not ct.capoBackLogged then
				ct.capoBackLogged = true
				diagPush("DODGE-CAPO t=%.2f  %s Capoeira M2 → back-only (mode ignored)", now, tostring(ct.name))
			end
		end
	end
	local optionalDodge = not (reason == "must-dodge" or reason == "must-dodge(unblockable→back)"
		or (type(reason) == "string" and reason:sub(1, 9) == "must-dodge"))
	if optionalDodge and timingTarget and type(timingTarget.contactAbs) == "number" then
		local contactIn = timingTarget.contactAbs - now
		local net = math.max(uplink(), 0.02)
		local duration = GameData.iframeDur or Config.IFrameDur or 0.30
		local frame = math.max(V93.lookahead or 0, V93.frameDt or (1/60))
		local centerLead = net + duration * 0.5 + (Config.DodgeCenterBias or 0)
		if timingTarget.kind == "M2" then centerLead = centerLead + (Config.HeavyDodgeBias or 0) end
		if contactIn > centerLead + frame then
			if not timingTarget.dodgeCenterWaitLogged then
				timingTarget.dodgeCenterWaitLogged = true
				diagPush("DODGE-WAIT/CENTER t=%.2f %s contactIn=%.0fms target=%.0fms frame=%.0fms", now, tostring(reason), contactIn*1000, centerLead*1000, frame*1000)
			end
			return false
		end
		if contactIn <= net + frame then
			if not timingTarget.dodgeTooLateLogged then
				timingTarget.dodgeTooLateLogged = true
				diagPush("DODGE-SKIP/TOO-LATE t=%.2f %s contactIn=%.0fms minArrival=%.0fms", now, tostring(reason), contactIn*1000, (net+frame)*1000)
			end
			return false
		end
	end

	local dir, dirMode, dodgeSpeed, startDist, targetDist, travel
	if isAliAbuse and not forceBackOnly then
		dir, dirMode, dodgeSpeed, startDist, targetDist, travel = State.bestAliForwardDodgeDir(dodgeTarget)
		if not dir then
			diagPush("ALI-DODGE-SKIP t=%.2f gate=trajectory reason=%s", now, tostring(dirMode))
			return false
		end
		diagPush("ALI-DODGE-TRAJECTORY t=%.2f mode=%s startDist=%.2f targetDist=%.2f travel=%.2f speed=%.1f", now, tostring(dirMode), startDist or -1, targetDist or -1, travel or -1, dodgeSpeed or -1)
	else
		dir = bestDodgeDir(now, preferBack)
		dirMode = dir and "smart" or "input"
	end
	-- Стиринг персонажа по вектору доджа (dir уже = "прочь" для защиты, "орбита" для агро):
	--  • Ali-abuse — всегда;
	--  • Aggressive (не форс-ретрит) — орбита вокруг врага (обкрутка/сближение);
	--  • всё остальное (Defensive / must-dodge) — толкаем ПРОЧЬ, чтобы физически выйти из
	--    объёма живого хитбокса до конца iframe (хитбокс проверяется каждый к��др, пока жив).
	local aggressiveOrbit = (Config.DodgeMode == "Aggressive") and not preferBack
	local wantSteer = isAliAbuse
		or (aggressiveOrbit and Config.DodgeAggroSteer ~= false)
		or (not aggressiveOrbit and Config.DodgeExitSteer ~= false)
	if dir and wantSteer then
		local c = localChar()
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum then pcall(V93.humMove, hum, dir) end
		State.ap.dodgeSteerDir = dir
		State.ap.dodgeSteerUntil = now + math.max((uplink() * 0.5) + 0.06, 0.12)
	end
	sendDodge(dir, dodgeSpeed)
	if granted then State.grantEscapes = (State.grantEscapes or 0) + 1 end
	if type(reason) == "string" and reason:sub(1, 4) == "dual" then
		State.dualDodgeCount = (State.dualDodgeCount or 0) + 1
	end
	State.lastDodgeRefuse = nil
	local tx = State.dodgeTxn
	local ifLat0 = math.max(uplink(), 0.02)
	local ifDur0 = GameData.iframeDur or Config.IFrameDur or 0.30
	local iframeLo = now + ifLat0
	local iframeHi = iframeLo + ifDur0
	tx.pending, tx.confirmed = true, false
	tx.fire, tx.lo, tx.hi = now, iframeLo, iframeHi
	local ackWindow = granted and 1.2
		or math.max(GameData.confirmTimeout or Config.DodgeConfirm or 0.18, 0.6)
	tx.ackDeadline = now + ackWindow
	tx.untilAt, tx.reason = iframeHi + 0.08, reason
	tx.abuseThreat = isAliAbuse and dodgeTarget or nil
	-- вынужденный додж = must-dodge / blatant-override / exposed-escape (preferBack|force).
	-- Нужно для гейта evasive-counter: при выключенном Ali Dodge Abuse M2 после доджа
	-- кидается ТОЛЬКО если додж был вынужденным (см. tryAliEvasiveCounter).
	tx.forced = (preferBack == true) or (force == true)
	tx.dodgeDirMode = dirMode
	tx.perfectConfirmed, tx.perfectAt = false, nil
	if (counterStyle() or "") == "ali" and Config.SkillAddon and Config.AliEvasiveCounter then
		diagPush("ALI-DODGE-ARM t=%.2f reason=%s await=StyleEvasiveCounter proc=one-perfect-dodge specialCd=6s range=22 ignoreNormalM2Cd=true deadline=%.0fms", now, tostring(reason), (tx.untilAt-now)*1000)
	end
	tx.evCounterFired, tx.evCounterExpiredLogged = false, false
	tx.evCounterAwaitIframeLogged, tx.evCounterTargetGateLogged, tx.evCounterStateGate = false, false, nil
	local planned, soonest = 0, nil
	for _, th in ipairs(Threats) do
		local c = th.contactAbs
		if c >= iframeLo - 0.03 and c <= iframeHi + 0.03 then
			planned = planned + 1
			if not soonest or c < soonest then soonest = c end
		end
	end
	State.lastDodgeInfo = {
		fire=now, reason=reason, contactAbs=soonest, iframeLo=iframeLo, iframeHi=iframeHi,
		dir=dirMode or (dir and "smart" or "input"), planned=planned,
	}
	diagPush("DODGE  t=%.2f  %s%s  planned=%d  dir=%s  fire→contact=%s  iframe=[+%.0f,+%.0f]ms", now, reason, granted and " [GRANT]" or "", planned, State.lastDodgeInfo.dir,
			soonest and string.format("%.0fms", (soonest-now)*1000) or "n/a",
			ifLat0*1000, (ifLat0+ifDur0)*1000)
	return true
end

local updateDodgeTxn = LPH_NO_VIRTUALIZE(function(now)
	local tx = State.dodgeTxn
	if not tx or not tx.pending then return end
	local c = localChar()
	if not tx.confirmed and c and c:GetAttribute("IFRAMES") == true then
		tx.confirmed = true
		tx.lo, tx.hi = now, now + (GameData.iframeDur or Config.IFrameDur or 0.30)
		tx.untilAt = tx.hi + 0.08
		if State.lastDodgeInfo then
			State.lastDodgeInfo.iframeLo, State.lastDodgeInfo.iframeHi = tx.lo, tx.hi
		end
		local covered = 0
		for _, th in ipairs(Threats) do
			local contact = th.contactAbs
			if not th.dodged and contact >= tx.lo
				and contact <= tx.hi then
				th.dodged, th.coveredByDodge = true, true
				covered = covered + 1
			end
		end
		diagPush("DODGE-CONFIRM t=%.2f  %s  covered=%d  window=[+%.0f,+%.0f]ms", now, tostring(tx.reason or "?"), covered,
				(tx.lo-tx.fire)*1000, (tx.hi-tx.fire)*1000)
	end
	if not tx.confirmed and now >= (tx.ackDeadline or tx.untilAt) then
		State.dodgeRejects = (State.dodgeRejects or 0) + 1
		diagPush("DODGE-REJECT/EARLY-FALLBACK t=%.2f %s ack=%.0fms IFRAMES not confirmed; EDF/parry restored (подряд=%d)", now, tostring(tx.reason or "?"), (now-(tx.fire or now))*1000, State.dodgeRejects)
		tx.pending, tx.confirmed, tx.reason = false, false, nil
		tx.abuseThreat, tx.perfectConfirmed, tx.perfectAt = nil, false, nil
		State.ap.dodgeSteerDir, State.ap.dodgeSteerUntil = nil, 0
		return
	end
	local hardClose = tx.untilAt
	local budget = tx.ackDeadline or 0
	local awaitingProc = Config.AliEvasiveCounter
		and (tx.reason == "ali-dodge-abuse")
		and not tx.perfectConfirmed
	if (not tx.confirmed or awaitingProc) and budget > hardClose then hardClose = budget end
	if tx.perfectConfirmed and not tx.evCounterFired and Config.AliEvasiveCounter then
		local ttl = math.min(6 * (Config.AliProcTTLFrac or 0.25), Config.AliProcTTLMax or 1.5)
		local procEnd = (tx.perfectAt or 0) + ttl
		if procEnd > hardClose then hardClose = procEnd end
	end
	if now >= hardClose then
		if tx.reason == "ali-dodge-abuse" and tx.confirmed and not tx.perfectConfirmed then
			diagPush("ALI-PERFECT-MISS/EXPIRE t=%.2f target=%s gate=no-StyleEvasiveCounter iframe=[%.0f,%.0f]ms", now, tostring(tx.abuseThreat and tx.abuseThreat.name or "?"),
					((tx.lo or tx.fire)-tx.fire)*1000, ((tx.hi or tx.fire)-tx.fire)*1000)
		end
		if not tx.confirmed then
			State.dodgeRejects = (State.dodgeRejects or 0) + 1
			diagPush("DODGE-REJECT t=%.2f  %s  IFRAMES not confirmed; EDF retained (подряд отказов=%d%s)", now, tostring(tx.reason or "?"), State.dodgeRejects,
					State.dodgeRejects >= 2
						and string.format(", гейт откатился на полный CD %.2fс", 
							GameData.evPredictCooldown or Config.DodgeCooldown)
						or ", пол остаётся 0.38с")
		else
			State.dodgeRejects = 0
		end
		tx.pending, tx.confirmed, tx.reason = false, false, nil
		tx.abuseThreat, tx.perfectConfirmed, tx.perfectAt = nil, false, nil
		State.ap.dodgeSteerDir, State.ap.dodgeSteerUntil = nil, 0
	end
end)

_C.pubTargetModel, _C.pubThreat = nil, nil

local function publishTarget(th)
	_C.pubThreat = th
end

local publishVizTarget = function(model, hrp)
	if type(getgenv) ~= "function" then return end
	if not model then
		if _C.pubTargetModel ~= nil then _C.pubTargetModel = nil; getgenv().AP_TARGET = nil end
		return
	end
	local th = _C.pubThreat
	if th and th.attackerModel ~= model then th = nil end
	local plr = Players:GetPlayerFromCharacter(model)
	if model ~= _C.pubTargetModel then
		_C.pubTargetModel = model
		getgenv().AP_TARGET = {
			model = model, hrp = hrp,
			name = plr and plr.Name or model.Name,
			style = th and th.style or nil,
			kind = th and th.kind or nil,
			contactIn = th and math.max((th.contactAbs or 0) - os.clock(), 0) or nil,
			threatens = th and th.threatens == true or false,
			t = os.clock(),
		}
		return
	end
	local t = getgenv().AP_TARGET
	if not t then _C.pubTargetModel = nil; return end
	t.hrp = hrp
	t.style = th and th.style or t.style
	t.kind = th and th.kind or nil
	t.contactIn = th and math.max((th.contactAbs or 0) - os.clock(), 0) or nil
	t.threatens = th and th.threatens == true or false
	t.t = os.clock()
end

local schedulerStep = LPH_NO_VIRTUALIZE(function(now)
	updateDodgeTxn(now)
	State.updateAliM2Cooldown(now)
	State.updateCounterTxn(now)
	if State.interruptFiredFrame ~= _C.FrameId and tryAliEvasiveCounter(now) then return end
	if #Threats == 0 and not State.blocking and not Config.AutoPlay then
		State.interruptCandidate = nil
		State.interruptThreatCount = 0
		State.multiThreat = false
		State.multiThreatN = 0
		State.vizTarget = nil
		V93.nearPress = math.huge
		V93.nearPressStamp = os.clock()
		publishTarget(nil)
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	local up        = uplink()
	local ifDur     = GameData.iframeDur or Config.IFrameDur or 0.30
	local ifLat     = math.max(up, 0.02)
	local wantBlock = nil
	local faceTgt   = nil
	local imminent  = V93.imminentBuf
	table.clear(imminent)
	State.interruptCandidate = nil
	State.interruptThreatCount = 0
	table.clear(V93.interruptSeen)
	V93.nearPress = math.huge
	V93.nearPressStamp = os.clock()

		for i = #Threats, 1, -1 do
			local th = Threats[i]
			local trackGone = th.track and th.track.Parent == nil
			refreshContact(th)
			syncContactWithHitbox(th, now)
			local dt = th.contactAbs - now
			local noTrackExpired = (not th.track)
				and (now - th.detectClock) > ((th.contact0 or 0) + 0.35)

			-- ФАНТОМНЫЕ УГРОЗЫ. refreshContact() пересчитывает contactAbs от ЖИВОГО
			-- TimePosition трека. Если трек врага встал (анимация замерла/зациклилась,
			-- десинк реплики), то dt каждый кадр ОДИН И ТОТ Ж��, условие dt < -0.35 не
			-- наступает никогда и угроза живёт вечно. В диаге lijpNKSVQ такие фантомы
			-- (GEOM-LATCH ... contactIn=+106ms, не менялся >2 секунд) копились по 3-5
			-- штук на одного врага, из-за ч��го clusterN>=2 постоянно выбирал стратегию
			-- HELD_GUARD и глушил counter'ы как multi-threat(5) → скрипт держал блок
			-- вместо парри. Отсюда и жалоба «чаще блокирует, нежели парирует».
			if not th.stallDt or math.abs(dt - th.stallDt) > 0.012 then
				th.stallDt, th.stallSince = dt, now
			end
			local animStalled = (now - (th.stallSince or now)) > (Config.ThreatStallSec or 0.45)
			-- Страховка сверху: свинг физически не может жить ��ольше своей анимации
			-- плюс запас, даже если трек продолжает «играть».
			local ageCapped = (now - th.detectClock)
				> ((th.contact0 or 0) + (th.hitTL or 0) + (Config.ThreatMaxAgeSec or 1.5))
			if (animStalled or ageCapped) and not th.stallLogged then
				th.stallLogged = true
				if Config.DeepDiag then
					diagPush("THREAT-EXPIRE t=%.2f  %s  %s  → снят как фантом: %s (dt застыл на %+.0fms, возраст %.0fms)",
						now, tostring(th.name), tostring(th.kind),
						animStalled and "анимация-встала" or "превышен-возраст",
						dt * 1000, (now - th.detectClock) * 1000)
				end
			end

			local atkNeutralized = false
			if th.attackerModel and th.attackerModel.Parent then
				atkNeutralized = th.attackerModel:GetAttribute("Parried") == true
					or th.attackerModel:GetAttribute("Stunned") == true
					or th.attackerModel:GetAttribute("Ragdoll") == true
					or th.attackerModel:GetAttribute("Downed") == true
					or th.attackerModel:GetAttribute("GuardBroken") == true
			end
				-- ── ПОЧЕМУ ИГНОРИРОВАЛСЯ 2-Й УДАР Boxing M2 ───────────────────────
			-- У Boxing M2 два контакта (V93.boxingM2Contacts = {0.60, 1.05}), и
			-- ветка MULTI честно создаёт вторую угрозу th2 со strike=2, связанную
			-- с первой через th.group. Судьбу второго удара решает ИСХОД первого:
			--   PERFECT → group.cancelled = true  (парри прервало всю связку)
			--   EARLY   → group.held = true       (обычный блок — связка идёт)
			-- Но проверка atkNeutralized стоит ВЫШЕ проверки group.cancelled и
			-- удаляет угрозу по СЫРОМУ атрибуту атакующего. А "Stunned" у него
			-- может стоять транзиентно и по чужой причине: его парировал союзник,
			-- он в хитстане от нашей же атаки, и т.п. В этот момент из Threats
			-- вылетал и th2 — второй удар связки, который сервер всё равно
			-- доставит. Скрипт про него забывал, и удар приходил чистым.
			-- Поэтому для strike>=2 транзиентных "Parried/Stunned" НЕ достаточно:
			-- отмену связки мы и так узнаем явно через group.cancelled (строка
			-- ниже), а снять её досрочно можно только по-настоящему
			-- терминальным состояниям. Фантом, если он всё же возникнет, умрёт
			-- штатно по animStalled/ageCapped — это дешевле пропущенного удара.
			if atkNeutralized and th.group and (th.strike or 1) >= 2
				and not th.group.cancelled and Config.MultiHitKeep ~= false then
				local m = th.attackerModel
				local terminal = m and m.Parent and (m:GetAttribute("Ragdoll") == true
					or m:GetAttribute("Downed") == true
					or m:GetAttribute("GuardBroken") == true)
				if not terminal then
					atkNeutralized = false
					if Config.DeepDiag and not th.multiKeepLogged then
						th.multiKeepLogged = true
						diagPush("MULTI-KEEP t=%.2f  %s  %s s%d  → 2-й удар связки НЕ снят: у атакующего "
							.. "транзиентный Parried/Stunned, но связка не отменена (contactIn=%+.0fms)",
							now, tostring(th.name), tostring(th.kind), th.strike or 2,
							(th.contactAbs - now) * 1000)
					end
				end
			end
			if atkNeutralized then
					if Config.DeepDiag and not th.neutralLogged then
						th.neutralLogged = true
						diagPush("NEUTRALIZED t=%.2f  %s  %s  → угроза снята: атакующий в Parried/Stunned, "
							.. "свинг заве��шиться не может (додж не нужен)", now, th.name, th.kind)
					end
					State.threatNeutralized = (State.threatNeutralized or 0) + 1
					table.remove(Threats, i)
				elseif th.counterPendingId and State.counterTxn
					and th.counterPendingId == State.counterTxn.seq
					and (State.counterTxn.pending or State.counterTxn.confirmed) then
				elseif th.resolved or th.staleTrack or (th.group and th.group.cancelled) then
				table.remove(Threats, i)
			elseif th.feinted then
				if not th.feintLogged then
					th.feintLogged = true
					diagPush("FEINT  t=%.2f  %s  %s  reached=%.0f%% of hitTL → ignored", now, th.name, th.kind, (th.maxTP or 0) / math.max(th.hitTL, 0.001) * 100)
				end
				table.remove(Threats, i)
			elseif dt < -0.35 or noTrackExpired or animStalled or ageCapped
				or (trackGone and (now - th.detectClock) > 0.5 and dt < Config.PerfectLead) then
			local coveredByGuard = th.coveredByHeldGuard == true
				or (Config.OmniBlock and State.blocking and th.enteredWindow
					and th.contactAbs <= (State.holdUntil or 0) + 0.05)
				if th.coveredByDodge or th.coveredByCounter then
				elseif coveredByGuard then
				State.guardCovered = (State.guardCovered or 0) + 1
			elseif Config.DeepDiag and not th.pressed and not th.dodged and not th.deadLogged then
				th.deadLogged = true
				local reason
				if th.everThreatened == nil or th.everThreatened == false then
					reason = string.format("geometry-rejected source=%s sid=%s", tostring(th.recognitionSource or "none"), tostring(th.serverSwingId or (th.group and th.group.serverSwingId) or "none"))
					if th.offTarget then State.offTargetRej = (State.offTargetRej or 0) + 1 end
				elseif th.enteredWindow then
					reason = string.format("in-window но нажат��я не было: threatens=%s geomLatched=%s blocked=%s", tostring(th.threatens), tostring(th.geomLatched or false),
							tostring((th.rec and th.rec.blockedReason) or "-"))
				elseif th.contactPassedFast then
					reason = string.format("окно не открылось: контакт приле���ел быстре�� pressAt (minDtToPress=%.0fms)", (th.minDtToPress or 0)*1000)
				else
					reason = string.format("no-window (maxTP=%.0f%% hitTL, feint-grace?)", (th.maxTP or 0)/math.max(th.hitTL,0.001)*100)
				end
				reason = reason .. string.format(" | proof=%s%s", 
					th.serverProven and ("yes/" .. tostring(th.provenBy or "?")) or "NO",
					th.pressHeldForProof and " HELD-BY-GATE" or "")
				diagPush("MISS!  t=%.2f  %s  %s(%s)  contact0=%.0fms  height=%s bodyScale=%s modelY=%s aMult=%.2f  → %s", now, th.name, th.kind, th.style or "?", (th.contact0 or 0)*1000,
						th.heightAttr and string.format("%.3f", th.heightAttr) or "?",
						th.bodyHeightScale and string.format("%.3f", th.bodyHeightScale) or "?",
						th.modelHeight and string.format("%.2f", th.modelHeight) or "?",
						th.attackMult or 1, reason)
				State.independentMiss = (State.independentMiss or 0) + 1
			end
			table.remove(Threats, i)
		elseif not th.dodged then
			local threatens = willHitMe(th)
			-- ══ ГЛАВНАЯ ПРИЧИНА ПЛОХОГО МУЛЬТИТАРГЕТИНГА ═══════════════════════
			-- Это ТРЕТИЙ (и самый сильный) обход геометрического фильтра, после
			-- faceExempt и geom-sticky внутри willHitMe. Работает он прямо по
			-- `threatens`, то есть по значению, которое кормит imminent → кластер
			-- → wantBlock. Логика была: если свинг когда-либо (`everThreatened`)
			-- считался угрозой, то ЛЮБОЙ последующий отказ живой геометрии
			-- переписывается в `threatens = true` — вплоть до контакта.
			-- А `everThreatened` ставится на первом же кадре, где геометрия
			-- сказала «да». Итого: враг начал замах, когда мы случайно оказались
			-- в секторе, потом развернулся бить СОЮЗНИКА — а мы держим его уда��
			-- как свой до конца. Отсюда `off-target swings rejected=1` на 243
			-- атаки: латч возвращал в угрозы всё, что фильтр отсеивал.
			-- Цена не только в лишних нажатиях: каждый мусорный блок сжигает наш
			-- кулдаун 0.5с, и следующий РЕАЛЬНЫЙ удар приходит на кулдаун
			-- (35 из 52 пропусков в этом логе — game-state-locked).
			-- Смысл у латча есть, но узкий: halfW/halfD восстановлены из живых
			-- размеров и врут, поэтому ПОГРАНИЧНЫЙ отказ надо переживать.
			-- «Отвернулся» и «мы сильно вне ширины замаха» — это не погрешность
			-- реконструкции, это чужой удар.
			if not threatens and th.serverProven and th.everThreatened
			   and (th.contactAbs - now) > -(Config.HoldAfter or 0.12) then
				local latchOk = true
				local latchWhy = nil
					if Config.LatchStrict ~= false then
						-- Тот же допуск, что и в основном тесте: латч не должен
						-- оживлять удар, отклонённый по направлению (см. willHitMe).
						local ang, allow = th.geomAngToMe, th.geomFaceAllow
						if ang and allow and ang > allow then
							latchOk, latchWhy = false, "NOT-AIMED-AT-ME"
						end
					local side, halfW = th.geomSide, th.geomHalfW
					if latchOk and side and halfW
						and side > halfW + (Config.LatchSidePad or 4.0) then
						latchOk, latchWhy = false, "OFF-AXIS"
					end
				end
				if latchOk then
					threatens = true
					if not th.geomLatched then th.geomLatchSince = now end
					th.geomLatched = true
					if Config.DeepDiag and (not th.geomLatchLogAt or now - th.geomLatchLogAt > 0.10) then
						th.geomLatchLogAt = now
						diagPush("GEOM-LATCH t=%.3f %s %s s%d proven-swing un-threatened by live geometry → HELD"
							.. " | contactIn=%+.0fms src=%s", now, tostring(th.name), tostring(th.kind), th.strike or 1,
								(th.contactAbs - now) * 1000, tostring(th.recognitionSource or "?"))
					end
				else
					-- Явно помечаем как чужой удар, чтобы он попал в счётчик
					-- off-target и было видно, что фильтр реально работает.
					th.offTarget = true
					if Config.DeepDiag and (not th.latchDropLogAt or now - th.latchDropLogAt > 0.25) then
						th.latchDropLogAt = now
						diagPush("LATCH-DROP t=%.3f %s %s s%d → чужой удар (%s): face=%.2f side=%.1f/%.1f contactIn=%+.0fms",
							now, tostring(th.name), tostring(th.kind), th.strike or 1, tostring(latchWhy),
							th.geomFaceToMe or 0, th.geomSide or 0, th.geomHalfW or 0,
							(th.contactAbs - now) * 1000)
					end
				end
			end
			th.threatens = threatens
			if threatens and not th.firstThreatClock then
				th.firstThreatClock = now
				local ga, gm, gl = th.geomOrigin, th.geomVictim, th.geomLook
				if Config.TraceDiag then
				diagTrace("TRACE-GEOM t=%.3f %s %s s%d src=%s first=%+.0fms dt=%+.0fms tHit=%.0fms depth=%.2f range=[%.2f,%.2f] side=%.2f/%.2f A=(%s) M=(%s) look=(%s)", now, th.name or "?", th.kind or "?", th.strike or 1,
						tostring(th.recognitionSource or "?"), (now-th.detectClock)*1000,
						(th.contactAbs-now)*1000, (th.geomTHit or 0)*1000,
						th.geomDepth or 0, (th.geomForward or 0)-(th.geomHalfD or 0),
						(th.geomForward or 0)+(th.geomHalfD or 0), th.geomSide or 0, th.geomHalfW or 0,
						ga and string.format("%.1f,%.1f", ga.X,ga.Z) or "?",
						gm and string.format("%.1f,%.1f", gm.X,gm.Z) or "?",
						gl and string.format("%.2f,%.2f", gl.X,gl.Z) or "?")
				end
			end
			if threatens then th.everThreatened = true end
			if threatens then
				if th.group and th.group.held and State.blocking then
					th.pressed, th.coveredByHeldGuard = true, true
					State.holdUntil = math.max(State.holdUntil or 0,
						(th.group.lastContact or th.contactAbs) + Config.HoldAfter + (Config.HoldLateGrace or 0))
				end
				local ik = th.attackerModel or th.attackerHRP or th.name
				if ik and not V93.interruptSeen[ik] then
					V93.interruptSeen[ik] = true
					State.interruptThreatCount = State.interruptThreatCount + 1
				end
				if (th.kind == "M1" or th.kind == "M2") and (not State.interruptCandidate
				   or th.contactAbs < State.interruptCandidate.contactAbs) then
					State.interruptCandidate = th
				end
				local lead = Config.PerfectLead
				local hold = Config.HoldAfter
		if Config.M2WidenWindow and th.kind == "M2" then
			lead = lead + Config.M2WidenFront
			hold = hold + Config.M2WidenHold
		end
			if Config.SkillAddon and Config.SA_HakariRead and th.kind == "M2"
				and (th.style or ""):lower() == "hakari" then
				local w = Config.SA_HakariWiden or 0.05
				lead = lead + w
				hold = hold + w
			end
					-- ── КЛАМП ОП��РЕЖЕНИЯ ПОД ЖИВОЕ ОКНО ПЕРФЕКТ-БЛОКА ──────────────
					-- Сервер видит ��ажатие за (lead + velLead) до контакта: uplink
					-- компенсируется сетью, а вот lead и velLead складываются.
					-- Окно ужалось 0.15 → 0.125, и суммы стали вылезать за него:
					--   Hakari M2: 0.0625+0.05+0.045 = 0.1575  > 0.125 → ОБЫЧНЫЙ БЛОК
					--   M2WidenWindow: 0.0625+0.22+0.045 = 0.3275 → ОБЫЧНЫЙ БЛОК
					-- Это и есть "иногда блокирует, а не парирует". Держим сумму
					-- внутри [PerfectMin ; window*0.85] — нажатие всегда в окне.
					local pwin = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
						or Config.PerfectWindow or 0.125
						-- Ограничиваем так, чтобы ОЖИДАЕМЫЙ СЕРВЕРНЫЙ ЗАЗОР
						-- (lead + velLead + невязка) не вылез за верхний край окна.
						-- Раньше стояла эвристика pwin*0.85, а невязка не учитывалась:
						-- при velLead=45 кламп давал lead=61, зазор выходил
						-- 61+45+31 = 137мс > 125мс → guard=EARLY(>125) → БЛОК ВМЕСТО ��АРРИ.
						local gapBias = gapBiasEst()
						local edgeS = (Config.GapEdgeMs or 6) / 1000
						local pmin0 = Config.PerfectMin or 0.05
						-- velLead тоже надо ��граничить окном. Иначе при большом реальном
						-- сближении сумма pmin+velLead+невязка сама вылезала за край
						-- (50+45+31 = 126мс), и никакое уменьшение lead уже не помогало —
						-- он упирался в пол PerfectMin.
						-- Капы тоже в координатах измеряемого зазора (см. ServerGapOffsetMs),
						-- иначе они режут прицел до старого, промахивающегося значения.
						local gapOff0 = (Config.ServerGapOffsetMs or 0) / 1000
						local vlCap = math.max(pwin - edgeS + gapOff0 - pmin0 - gapBias, 0)
						if (th.velLead or 0) > vlCap then
							if Config.DeepDiag and not th.vlClampLogged then
								th.vlClampLogged = true
								diagPush("VLEAD-CLAMP t=%.2f %s %s velLead %.0f→%.0fms (окно=%.0fms невязка=%.0fms)",
									now, tostring(th.name), tostring(th.kind),
									(th.velLead or 0) * 1000, vlCap * 1000, pwin * 1000, gapBias * 1000)
							end
							th.velLead = vlCap
						end
						local leadCap = math.max(pwin - edgeS + gapOff0 - (th.velLead or 0) - gapBias, pmin0)
					if lead > leadCap then
						if Config.DeepDiag and not th.leadClampLogged then
							th.leadClampLogged = true
							diagPush("LEAD-CLAMP t=%.2f %s %s lead %.0f→%.0fms (window=%.0fms velLead=%.0fms)",
								now, tostring(th.name), tostring(th.kind), lead*1000, leadCap*1000,
								pwin*1000, (th.velLead or 0)*1000)
						end
						lead = leadCap
					end
					-- ── ЗАПАС НА КВАНТОВАНИЕ КАДРОМ ────────────────────────────
						-- Работает на ЛЮБОМ fps (модель верна всегда), но заметно только при
						-- чанковых кадрах. Правил�� «только поднимаем» делает его безопасным.
						if Config.LeadQuantComp ~= false then
							local edge    = (Config.LowFpsEdgeMs or 6) / 1000
						local vl      = th.velLead or 0
						local pmin    = Config.PerfectMin or 0.05
						-- Квантование кадром ОДНОСТОРОННЕЕ: нажать раньше запланированного
						-- нельзя физически, м��жно только ПОЗЖЕ — на следующем кадре. То есть
						-- факт��ческий зазор до контакта равен (lead+velLead) МИНУС задержка
						-- q, где q ∈ [0, кадр]. В логах это ровно lateBy: +2, +12, +46, +63,
						-- +72, +162мс — ВСЕГДА со знаком «+» и по величине примерно кадр.
						-- Значит чтобы зазор остался в окне [50,125]мс при любом q, надо
						-- ПОДНЯТЬ lead на длину кадра, а не опустить:
						--     lead+velLead = pmin + кадр + edge  →  зазор ∈ [pmin, ...]
						-- Прошлая версия считала дрожание ДВУСТОРОННИМ (±полкадра) и
						-- ОПУСКАЛА lead (62→48мс при кадре 38мс). При задержке в кадр зазор
						-- становился 48-38 = 10мс — мимо окна снизу, отсюда поток LATE и
						-- accuracy 48% у tutelzs на 17.8 fps.
						local q = V93.frameDt or (1/60)
						local qPeak = (V93.frameDtPeak or q) * (Config.LowFpsQuantPeakK or 0.75)
						if qPeak > q then q = qPeak end
							-- ЦЕЛЬ БЫЛА ПРИВЯЗАНА К НИЖНЕМУ КРАЮ: pmin + q + edge, т.е. 50 + кадр.
						-- Это защищало только от опоздания (LATE) и полностью игнорировало
						-- верхний край окна. В логе V176 цель вышла 80 и 93мс, а зазор должен
						-- остаться в [0..125], значит запаса на ПОЗДНИЙ удар было всего +45 и
						-- +32мс — оба блока ровно там: trueGap 179 и 149мс.
						-- Правильная цель — ЦЕНТР окна, тогда допуск симметричен (±62мс).
						-- Квантование кадром односторонее (нажать ��ожно только позже), поэтому
						-- добавляем ПОЛОВИНУ кадра: интервал [target-q, target] центрируется.
						-- ── ПЕРЕВОД ЦЕЛИ В КООРДИНАТЫ ИЗМЕРЯЕМОГО ЗАЗОРА ───────────
						-- ЭТО И БЫЛ КОРЕНЬ ПРОМАХОВ. `target` сравнивается с expGap =
						-- lead+velLead+bias, то есть с величиной ТОГО ЖЕ РОДА, что и
						-- trueGap в диаге, а trueGap завышен на ServerGapOffsetMs (см.
						-- разбор у константы). Цель же задавалась в «настоящих»
						-- координатах — центр окна 62мс. Настоящий зазор выходил
						-- 62 - 75 = -13мс: блок в среднем приходил ПОЗЖЕ удара, и
						-- исход решал джиттер ±25мс. В логе 870989 ровно это: цель
						-- 69мс на всех атаках, а trueGap разбросан 44..124 и результат
						-- скачет PERFECT/LATE при одинаковом прицеле.
						-- Прибавляем офсет к цели И К ОБОИМ КАПАМ — иначе hiCap (119мс)
						-- обрезал бы цель обратно и правка не дала бы ничего.
						local gapOff = (Config.ServerGapOffsetMs or 0) / 1000
						local center = pwin * 0.5
						local target = center + gapOff + q * 0.5
						local hiCap  = pwin - edge + gapOff
						-- Пол берём с защитным запасом: промах хуже блока (см. GapSafeFloorMs).
						local loCap  = math.max(pmin, (Config.GapSafeFloorMs or 55) / 1000) + gapOff
						if target > hiCap then target = hiCap end
						if target < loCap then target = loCap end
						-- Ведём зазор К ЦЕЛИ В ОБЕ СТОРОНЫ. Раньше правило было «только
						-- поднимать», и завышенный зазор (80..93мс) никогда не исправлялся —
						-- именно он давал блок вместо парри при чуть задержанном ударе.
						-- Опускать безопасно, потому что цель теперь центр окна, а не его низ.
						local newLead = lead
						-- Сравниваем именно ОЖИДАЕМЫЙ СЕРВЕРНЫЙ ЗАЗОР, а не сырой lead.
						local expGap = lead + vl + gapBias
						if math.abs(expGap - target) > 0.0005 then
							newLead = target - vl - gapBias
						end
						if newLead < 0 then newLead = 0 end
						if math.abs(newLead - lead) > 0.0005 then
							if Config.DeepDiag and not th.jitLogged then
								th.jitLogged = true
								diagPush("LEAD-QUANT t=%.2f %s %s lead %.0f→%.0fms (кадр=%.0fms peak=%.0fms q=%.0fms velLead=%.0fms зазор станет [%.0f..%.0f]ms окно=[%.0f..%.0f]ms)",
									now, tostring(th.name), tostring(th.kind), lead*1000, newLead*1000,
									(V93.frameDt or 0)*1000, (V93.frameDtPeak or 0)*1000, q*1000, vl*1000,
									(newLead + vl + gapBias - q)*1000, (newLead + vl + gapBias)*1000,
									pmin*1000, pwin*1000)
							end
							lead = newLead
						end
					end
						-- Целевой серверный зазор этого нажатия — по нему потом учим невязку.
						th.aimGap = lead + (th.velLead or 0)
						local pressAt = th.contactAbs - lead - up - th.velLead
					local holdEnd = th.contactAbs + hold
					local pressAtQ = pressAt - (V93.lookahead or 0)
				local dtToPress = pressAt - now
				if th.minDtToPress == nil or dtToPress < th.minDtToPress then
					th.minDtToPress = dtToPress
				end
				if dtToPress > -(Config.HoldAfter or 0.12) and dtToPress < V93.nearPress then
					V93.nearPress = dtToPress
				end
				if now < pressAt and (th.contactAbs - now) < lead then
					th.contactPassedFast = true
				end
				if not th.serverProven then
						if th.suspect then
							if th.serverSwingId or (th.group and th.group.serverSwingId) then
								th.serverProven, th.serverProofClock = true, now
								th.suspect = false
								th.provenBy = "swingid"
							end
						elseif serverAttackProof(th.attackerModel) then
							th.serverProven, th.serverProofClock = true, now
							th.provenBy = "attr"
							if Config.DeepDiag and not th.proofLogged then
								th.proofLogged = true
								diagPush("TRACE-PROOF t=%.3f %s %s PROVEN by=attr +%.0fms after detect, %+.0fms to contact", now, tostring(th.name), tostring(th.kind),
										(now - th.detectClock) * 1000,
										(th.contactAbs - now) * 1000)
							end
						elseif associatedHitbox(th) then
								-- ВАЖНО: фейк-атаки могут идти ВМЕСТЕ с настоящей. Настоящий свинг = РОВНО
								-- одна часть в workspace.Hitboxes с уникальным VictimSwingId. associatedHitbox
								-- претендует на неё через hbClaimBySid (по threat-группе), поэтому ДВЕ
								-- угрозы от одного врага НЕ могут делить один хитбокс: фейк-анимаци�� своего
								-- хитбокса не создаёт → пруф не получит. Раньше здесь был serverHitboxProof
								-- (owner-only) — он отдавал пруф фейку от хитбокса реального свинга. Исправлено.
								th.serverProven, th.serverProofClock = true, now
								th.provenBy = "hitbox"
							end
				end

					-- ── АВАРИЙНОЕ НАЖАТИЕ ──────────────────────────────────────────
					-- Случай из диага 870989: удар опознан ТОЛЬКО по физическому
					-- оверлапу хитбокса (src=server-overlap, hbOverlap=43мс), когда
					-- замах уже почти закончился. Прогноз при этом дал contact=+319мс
					-- вперёд (predErr=-252мс), поэтому pressAtQ оказался в будущем,
					-- удар разрешился раньше него — и скрипт НЕ НАЖАЛ ВООБЩЕ:
					--     blockGap=NO-PRESS guard=NOT-BLOCKED
					-- Так потеряно 2 удара из 7 провалов. Это чистая потеря: нажатие
					-- ничего не стоит, кроме block-cooldown, зато
					--   * Shared.ParryBufferAfterHit = 2с — сервер держит буфер парри
					--     после попадания, и запоздавшее нажатие ещё может быть зачтено;
					--   * даже если нет, блок встанет под СЛЕДУЮЩИЙ удар серии, а он
					--     после M1 идёт через ~350мс.
					-- Условие узкое: хитбокс уже пересекается с нами (это факт, не
					-- прогноз), угроза подтверждена сервером и нажатия ещё не было.
					local emergency = false
					if Config.EmergencyPress ~= false and not th.pressed and th.hbOverlapClock
					   and th.serverProven and now < th.hbOverlapClock + (Config.EmergencyPressGrace or 0.20) then
						emergency = true
						if Config.DeepDiag and not th.emergencyLogged then
							th.emergencyLogged = true
							diagPush("EMERGENCY t=%.2f %s %s хитбокс уже на нас (оверлап %+.0fms, прогноз contact %+.0fms) → жмём немедленно",
								now, tostring(th.name), tostring(th.kind),
								(now - th.hbOverlapClock) * 1000, (th.contactAbs - now) * 1000)
						end
					end
				if (now >= pressAtQ and now <= holdEnd) or emergency then
					th.enteredWindow = true
					if Config.ServerProofGate and not th.serverProven
					   and (th.suspect or (th.contactAbs - now) > (Config.ProofGraceSec or 0.06)) then
						if not th.baitHeldLogged then
							th.baitHeldLogged = true
							th.proofHoldClock = now
							diagPush("TRACE-PROOF t=%.3f %s %s HOLD unproven%s | dt=%+.0fms", now, tostring(th.name), tostring(th.kind),
									th.suspect and " SUSPECT(no swing-id)" or "",
									(th.contactAbs - now) * 1000)
							aclog(string.format("[resolver] %s %s unproven%s — holding press (bait?)", tostring(th.name), tostring(th.kind),
									th.suspect and " (SUSPECT: no swing-id)" or " by server"))
						end
						th.pressHeldForProof = true
					else
						th.pressHeldForProof = false
					-- ══ ПРИОРИТЕТ ТЯЖЁЛЫХ УДАРОВ (M2/SKILL) ═══════════════════════
						-- Раньше при равенстве по «нажат/не нажат» выбор шёл ТОЛЬКО по
						-- времени контакта: `th.contactAbs < wantBlock.contactAbs`.
						-- Тип удара не учитывался вообще. M1 почти всегда прилетает
						-- раньше M2 (252мс против 434мс у того же Karate), поэтому в
						-- связке «M1 + M2» цель всегда доставалась M1. Нажатие уходило
						-- на M1, включался кулаун 0.5с, а M2 через ~370мс попадал ровно
						-- в него: `BLOCK? refused: BlockCooldown`. Отсюда и «парирует
						-- M1, а на M2 похер» — это следствие сортировки, а не рандом.
						-- Разменивать надо наоборот: M2/SKILL бьют кратно больнее и
						-- ломают гард, а M1 переживается поднятым гардом (удержание
						-- кулдаун не тратит, см. GUARD-HOLD). Поэтому когда оба удара
						-- пришлись в одно окно и оплатить можно только одно нажатие
						-- (их контакты ближе кулдауна) — берём тяжёлый.
						-- Если разрыв больше кулдауна, порядок не важен: успеваем оба,
						-- и остаётся прежняя сортировка по времени контакта.
						local take = false
						if not wantBlock then
							take = true
						else
							local wbU, thU = not wantBlock.pressed, not th.pressed
							if thU ~= wbU then take = thU
							else
								local dHeavy = heavyRank(th) - heavyRank(wantBlock)
								local gap = math.abs(th.contactAbs - wantBlock.contactAbs)
								local cd  = (Config.BlockCooldown or 0.5)
								if Config.HeavyFirst ~= false and dHeavy ~= 0 and gap < cd then
									take = dHeavy > 0
									if take and Config.DeepDiag and not th.heavyPrioLogged then
										th.heavyPrioLogged = true
										diagPush("HEAVY-FIRST t=%.2f приоритет %s %s(%+.0fms) вместо %s %s(%+.0fms): "
											.. "разрыв %.0fms < кулдауна %.0fms, оплатить можно только одно нажатие",
											now, tostring(th.name), tostring(th.kind), (th.contactAbs - now) * 1000,
											tostring(wantBlock.name), tostring(wantBlock.kind),
											(wantBlock.contactAbs - now) * 1000, gap * 1000, cd * 1000)
									end
								else
									take = th.contactAbs < wantBlock.contactAbs
								end
							end
						end
						if take then wantBlock = th end
					end
				end
				-- Цель доворота выбираем только среди ударов, подтверждённых живой
					-- геометрией (aimedAtMe). Латч и явно чужие свинги сюда не попадают:
					-- крутиться на них — прямая потеря времени в замесе.
					if dt <= (Config.FaceLeadWindow + up) and dt >= -Config.HoldAfter
						and aimedAtMe(th) then
						local grace = now - 0.03
						local take = false
						if not faceTgt then
							take = true
						else
							local fUp, thUp = faceTgt.contactAbs >= grace, th.contactAbs >= grace
							if thUp ~= fUp then take = thUp
							else take = th.contactAbs < faceTgt.contactAbs end
						end
						if take then faceTgt = th end
					end
				-- В КЛАСТЕР (он выбирает HELD_GUARD / IFRAME_CLUSTER / доджи) пускаем
				-- только угрозы, которые реально могут достать. Свинг, залипший в
				-- geom-sticky/OUT-OF-REACH, физически вне радиуса — раньше он всё равно
				-- шёл в кластер, раздувал clusterN и переводил защиту в HELD_GUARD, т.е.
				-- блок вместо парри. Для самого блока/парри такие угрозы по-прежнему
				-- учитываются выше (wantBlock), меняется только логика кластера.
				local reachPhantom = (th.recognitionSource == "geom-sticky/OUT-OF-REACH")
					or (th.geomLatched and not th.trustedHit
						and (now - (th.geomLatchSince or now)) > (Config.LatchClusterGrace or 0.25))
				if dt <= Config.DodgeHorizon and dt >= -Config.HoldAfter and not th.staleTrack
					and not reachPhantom then
					imminent[#imminent+1] = th
				end
			end
		end
	end

	State.ap.tryInterrupt(now, State.interruptCandidate, State.interruptThreatCount)

	table.sort(imminent, V93.sortByContact)

	if State.interruptFiredFrame ~= _C.FrameId and tryBoxingCounter(now) then return end

	local cluster = V93.clusterBuf
	table.clear(cluster)
	local clusterHeavy = false
	for _, th in ipairs(imminent) do
		cluster[#cluster + 1] = th
		if th.kind == "M2" then clusterHeavy = true end
	end
	local clusterN = #cluster
	local clusterFirst = cluster[1]
	local clusterLast = cluster[#cluster]
	local clusterSpread = (clusterFirst and clusterLast) and (clusterLast.contactAbs - clusterFirst.contactAbs) or 0
		-- ПЛАН ДОЛЖЕН ПЕРЕЖИВАТЬ КАДРЫ. Тут бы��а моя ошибка: метки снимались
		-- безу��ловно каждый кадр, а план пересобирался только пока в кластере есть
		-- ДВЕ угрозы. Но додж второй угрозы исполняется, когда её контакт в 20-200мс,
		-- а к этому моменту ПЕРВАЯ уже отработала и вылетела из списка → в кластере
		-- осталась одна угроза → план не пересобрался → метка снята → PLAN-DODGE не
		-- срабатывал НИКОГДА. В логе это ровно так и выглядит: strategy=PARRY_THEN_DODGE
		-- выбран 26 раз, PLAN-DODGE — 0 раз, тяжёлая просто прилетала.
		-- Теперь метка живёт по своему сроку и снимается только когда действительно
		-- устарела или уже исполнена.
		local planTTL = Config.PlanLatchSec or 1.2
			for _, th in ipairs(imminent) do
				-- plannedParry планировщик пересчитывает каждый кадр, поэтому снимаем
				-- сразу. plannedDodge живёт по TTL: он нужен позже, когда первая
				-- угроза уже отработала и кластер распался.
				th.plannedParry, th.planCovered = nil, nil
				if th.plannedDodge and (now - (th.planStamp or 0)) > planTTL then
					th.plannedDodge, th.planStamp = nil, nil
				end
			end

		local clusterStrategy = nil
		local activeTxn = State.dodgeTxn
	if activeTxn and activeTxn.pending then
		clusterStrategy = "DODGE_TXN"
	end
	if not clusterStrategy and Config.MultiThreatGuard and clusterN >= (Config.MultiThreatMinN or 2) then
		local iframeSpan = math.max(0, ifDur - 0.07)
		local blockCd = Config.BlockCooldown or 0.5
		local frame   = math.max(V93.frameDt or 0, 1 / 60)
		local lead    = Config.PerfectLead or 0.0625
		local actGap  = Config.MinActGap or 0.004

		-- ══ ПЛАНИРОВЩИК РАЗМЕНА ═══════════════════════════════════════════════
		-- Раньше здесь была лестница спец-случаев («M1 потом M2», «две разные с
		-- разрывом > X») — она покрывала пару частных комбинаций, а всё остальное
		-- сваливала в HELD_GUARD, т.е. в слепой зажатый блок. Отсюда и «тупые
		-- решения»: блок вместо парри и полностью проигнорированная вторая атака.
		--
		-- Теперь считаем расписание от РЕАЛЬНЫХ правил игры (всё из дампа):
		--  1. Одно перфект-пар��и закрывает ВСЕ удары, чьё касание попало в наше окно
		--     PerfectBlockWindow=0.125с. VictimHitboxServiceClient на каждое
		--     пересечение отправляет наш флаг PerfectBlocking, а он один на всех —
		--     значит два-три удара в пределах 125мс парируются ОДНИМ нажатием.
		--  2. После снятия блока Block.CooldownSeconds=0.5с — повторное парри
		--     невозможно раньше.
		--  3. Додж закрывает ВСЕ удары, попавшие в i-frames: при IFRAMES=true
		--     _canScanCharacter возвращает false и жертва не репортит вообще ничего.
		-- Жадн�� идём по отсортированным угрозам и на каждую незакрытую выбир��ем
		-- доступное действие, помечая всё, что оно закрывает.
		local pwinPlan = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
			or Config.PerfectWindow or 0.125
		local parryCover  = math.max(pwinPlan - (Config.GapEdgeMs or 6) / 1000, 0.04)
		local dodgeCover  = math.max(iframeSpan, 0.05)
		local plannedParries, plannedDodges, planParts = 0, 0, nil
		-- Блок может быть уже в кулдауне от предыдущего парри — учитываем факт.
		local blockFreeAt = now
		if State.lastBlockRelease then
			blockFreeAt = math.max(blockFreeAt, State.lastBlockRelease + blockCd)
		end

		for i = 1, clusterN do
			local anchor = cluster[i]
			if anchor and not anchor.planCovered then
				local forceDodge = isMustDodge(anchor)
				-- Парри доступно, если блок выйдет из кулдауна до моме��та нажатия.
				local canParry = (not forceDodge)
					and (anchor.contactAbs - lead - up) >= (blockFreeAt - actGap)
				if canParry then
					plannedParries = plannedParries + 1
					anchor.plannedParry, anchor.planCovered = true, true
					local covered = 1
					for j = i + 1, clusterN do
						local o = cluster[j]
						if o and not o.planCovered and not isMustDodge(o)
							and (o.contactAbs - anchor.contactAbs) <= parryCover then
							o.planCovered, o.plannedParry = true, true
							covered = covered + 1
						end
					end
					-- Блок отпустим примерно на касании → отсюда и считается кулдаун.
					blockFreeAt = anchor.contactAbs + blockCd
						-- ПЕРФ: строка нужна ИСКЛЮЧИТЕЛЬНО для лога PLAN. Раньше она
						-- собиралась КАЖДЫЙ КАДР для КАЖДОЙ угрозы в кластере, даже с
						-- выключенным DeepDiag: string.format + два tostring + конкатенация
						-- аккумулятора (то есть новая строка на каждую итерацию, O(n²) по
						-- мусору). Гейт на DeepDiag стоял ниже, у самого diagPush, но
						-- аргументы в Lua вычисляются ДО вызова — гейт не спасал.
						-- Это и есть основной источник просадки FPS в бою.
						if Config.DeepDiag then
							planParts = (planParts and planParts .. ", " or "")
								.. string.format("парри %s %s(+%.0fms, закрывает %d)",
									tostring(anchor.name), tostring(anchor.kind),
									(anchor.contactAbs - now) * 1000, covered)
						else
							planParts = planParts or false
						end
				elseif Config.AutoDodge then
					plannedDodges = plannedDodges + 1
					anchor.plannedDodge, anchor.planStamp, anchor.planCovered = true, now, true
					local covered = 1
					for j = i + 1, clusterN do
						local o = cluster[j]
						if o and not o.planCovered
							and (o.contactAbs - anchor.contactAbs) <= dodgeCover then
							o.planCovered = true
							covered = covered + 1
						end
					end
						-- ПЕРФ: см. комментарий у ветки парри — строка только для лога.
						if Config.DeepDiag then
							planParts = (planParts and planParts .. ", " or "")
								.. string.format("додж %s %s(+%.0fms, закрывает %d)",
									tostring(anchor.name), tostring(anchor.kind),
									(anchor.contactAbs - now) * 1000, covered)
						else
							planParts = planParts or false
						end
				end
			end
		end

		-- Имя стратегии выводим из расписания, а не наоборот.
		if plannedParries >= 1 and plannedDodges >= 1 then
			clusterStrategy = "PARRY_THEN_DODGE"
		elseif plannedParries >= 2 then
			clusterStrategy = "SEQUENTIAL"
		elseif plannedDodges >= 1 and plannedParries == 0 then
			clusterStrategy = "IFRAME_CLUSTER"
		end
		-- ПЕРФ + ЧИСТОТА ЛОГА: дедуп раньше строился по `clusterStrategy .. planParts`,
		-- а planParts СОДЕРЖИТ «+%.0fms до контакта» — величину, которая меняется
		-- каждый кадр. Поэтому подпись всегда была новой, дедуп не срабатывал никогда,
		-- и в лог валился спам: в диаге 6 строк PLAN/CLUSTER за 30мс (t=2333.26/28/29)
		-- с одной и той же стратегией. Каждая строка — конкатенация + string.format.
		-- Теперь подпись из СТАБИЛЬНЫХ полей: стратегия и состав плана.
		if clusterStrategy and planParts and Config.DeepDiag then
			local psig = clusterStrategy .. ":" .. plannedParries .. ":" .. plannedDodges .. ":" .. clusterN
			if V93.planLogSig ~= psig then
				V93.planLogSig = psig
				diagPush("PLAN t=%.2f %s (%d угроз): %s", now, clusterStrategy, clusterN, planParts)
			end
		end
		for _, th in ipairs(cluster) do th.planCovered = nil end
	if not clusterStrategy then
		clusterStrategy = clusterSpread <= iframeSpan and "IFRAME_CLUSTER" or "HELD_GUARD"
		end
		for _, th in ipairs(cluster) do
			th.clusterStrategy = clusterStrategy
		end

		-- ПЕРФ: подпись кластера сравнивается ЧИСЛАМИ, без string.format.
		-- Раньше строка собиралась каждый кадр только чтобы сравнить её с прошлой
		-- (и в 99% кадров выбросить). Разброс округляем до 10мс, иначе дрожание
		-- на 1мс снова превращает дедуп в спам.
		local sigN, sigSpread = clusterN, math.floor(clusterSpread * 100 + 0.5)
		if State.lastClusterSigN ~= sigN or State.lastClusterSigSpread ~= sigSpread
			or State.lastClusterSigStrat ~= clusterStrategy
			or now >= (State.lastClusterLogAt or 0) + 0.5 then
			State.lastClusterSigN, State.lastClusterSigSpread = sigN, sigSpread
			State.lastClusterSigStrat = clusterStrategy
			State.lastClusterLogAt = now
			diagPush("CLUSTER t=%.2f n=%d spread=%.0fms strategy=%s contacts=[+%.0f,+%.0f]ms", now, clusterN, clusterSpread * 1000, clusterStrategy,
					(clusterFirst.contactAbs - now) * 1000, (clusterLast.contactAbs - now) * 1000)
		end

			if clusterStrategy == "IFRAME_CLUSTER" and Config.EmergencyDualDodge
				and not canBlockNow()
			and not State.clusterHasAliBoxingM2(cluster)
			and Config.MultiDodgeCover ~= false and dodgeReady() and canDodgeNow()
			and not counterPreemptsDodge(now) then
			local firstDt = clusterFirst.contactAbs - now
			local iframeLo = ifLat
			local iframeHi = ifLat + ifDur
			local covered = 0
			for _, th in ipairs(cluster) do
				local dtc = th.contactAbs - now
				if dtc >= iframeLo and dtc <= iframeHi then
					local dup = false
					for _, other in ipairs(cluster) do
						if other == th then break end
						local odtc = other.contactAbs - now
						if other.attackerModel == th.attackerModel
						   and odtc >= iframeLo and odtc <= iframeHi
						   and math.abs(odtc - dtc) <= 0.03 then
							dup = true
							break
						end
					end
					if not dup then covered = covered + 1 end
				end
			end
			if firstDt >= iframeLo and covered >= 2 then
				if performDodge(now, string.format("multi-cover(n=%d span=%.0fms)", covered, clusterSpread * 1000)) then
					return
				end
			end
		end
	end

	local dtx = State.dodgeTxn
	if dtx and dtx.pending then
		local inFlightUntil = (dtx.fire or 0) + math.max(uplink(), 0.02)
			+ math.max(V93.frameDt or 0, 1 / 60)
		if now < inFlightUntil then return end
	end

	if clusterStrategy == "DODGE_M1_PARRY_M2" and not canBlockNow()
	   and dodgeReady() and canDodgeNow() and not counterPreemptsDodge(now) then
		local m1th = cluster[1]
		local m1Dt = m1th.contactAbs - now
		local dLo  = ifLat - 0.03
		local dHi  = math.min(ifLat + ifDur * (Config.DodgeCenterFrac or 0.5)
			+ (Config.DodgeCenterBias or 0), ifLat + ifDur - 0.04)
		if m1Dt >= dLo and m1Dt <= dHi then
			if performDodge(now, "dodge-m1-parry-m2") then
				m1th.coveredByDodge = true
				return
			end
		end
	end

	-- ── ИСПОЛНЕНИЕ PARRY_THEN_DODGE: втора�� часть плана ���──────────────────��───
	-- Первую угрозу парирует обычный путь wantBlock ниже. Здесь ждём, пока вторая
	-- (обычно тяжёлая) войдёт в окно дод��а, и уходим с линии.
	for _, th in ipairs(imminent) do
		if th.plannedDodge and not th.coveredByDodge and not th.pressed then
			local pdDt = th.contactAbs - now
			local pdLo = ifLat - 0.03
			local pdHi = math.min(ifLat + ifDur * (Config.DodgeCenterFrac or 0.5)
				+ (Config.DodgeCenterBias or 0), ifLat + ifDur - 0.04)
			if pdDt >= pdLo and pdDt <= pdHi
				and dodgeReady() and canDodgeNow() and not counterPreemptsDodge(now) then
				if performDodge(now, "parry-then-dodge", false, false, false, th) then
					th.coveredByDodge = true
					diagPush("PLAN-DODGE t=%.2f %s %s contactIn=%.0fms → уходим с линии (первую парировали)",
						now, tostring(th.name), tostring(th.kind), pdDt * 1000)
					return
				end
			end
		end
	end

	-- ── БЛОК В КУЛДАУНЕ → ДОДЖ ─────────────────────────────────────────────────
	-- Игра даёт Block.CooldownSeconds=0.5 после снятия блока. Значит сразу после
	-- парри первого удара второй УЖЕ НЕЛЬЗЯ ни парировать, ни блокировать: путь
	-- wantBlock просто печатал «refused: BlockCooldown» и на этом всё
	-- заканчивалось — удар прилетал. Ровно это и есть «скрипт не реагирует на M2».
	-- Додж кулдауном блока не связан, п��этому уходим с линии.
	if Config.CooldownDodge ~= false and Config.AutoDodge then
		local okBlock, whyBlock = canBlockNow()
		if not okBlock and (whyBlock == "BlockCooldown" or whyBlock == "Unequip")
			and dodgeReady() and canDodgeNow() and not counterPreemptsDodge(now) then
			for _, th in ipairs(imminent) do
				if not th.coveredByDodge and not th.pressed then
					local cdDt = th.contactAbs - now
					local cdLo = ifLat - 0.03
					local cdHi = math.min(ifLat + ifDur * (Config.DodgeCenterFrac or 0.5)
						+ (Config.DodgeCenterBias or 0), ifLat + ifDur - 0.04)
					if cdDt >= cdLo and cdDt <= cdHi then
						if performDodge(now, "block-on-cooldown", false, false, false, th) then
							th.coveredByDodge = true
							diagPush("CD-DODGE t=%.2f %s %s contactIn=%.0fms → блок не��оступен (%s), уходим доджем",
								now, tostring(th.name), tostring(th.kind), cdDt * 1000, tostring(whyBlock))
							return
						end
					end
				end
			end
		end
	end

		local mustDodgeThreat = nil
		for _, candidate in ipairs(imminent) do
			if isMustDodge(candidate) then mustDodgeThreat = candidate; break end
		end
	if mustDodgeThreat and dodgeReady() and canDodgeNow() then
		local mustDt = mustDodgeThreat.contactAbs - now
		local mLo = ifLat - 0.03
		local mHi = math.min(ifLat + ifDur * (Config.DodgeCenterFrac or 0.5)
			+ (Config.DodgeCenterBias or 0), ifLat + ifDur - 0.04)
		if mustDt >= mLo and mustDt <= mHi then
			if performDodge(now, "must-dodge(unblockable→back)", true, false, true) then
				mustDodgeThreat.coveredByDodge = true
				return
			end
		end
	end

	if Config.SkillAddon and Config.SA_BlatantDodge and dodgeReady() and #imminent >= 1 then
		local a  = imminent[1]
		local dt = a.contactAbs - now
		local normalOk = canDodgeNow(false)
		local forceOk  = canDodgeNow(true)
		local locked   = (State.selfBusyUntil or 0) > now or (not canBlockNow())
		local coverLo  = ifLat - 0.03
		local coverHi  = ifLat + ifDur - 0.04
		if (not normalOk) and forceOk and locked and not State.isAliBoxingM2(a)
		   and dt >= (coverLo - 0.06) and dt <= math.max(coverHi, Config.SA_BlatantWindow or 0.32)
		   and not counterPreemptsDodge(now) then
			if performDodge(now, "blatant-override(locked)", true, true) then return end
		end
	end

	if dodgeReady() and canDodgeNow() and #imminent >= 1 then
		local a = imminent[1]
		local soonestDt = a.contactAbs - now

		local coverLo = ifLat - 0.03
		local coverHi = ifLat + ifDur * (Config.DodgeCenterFrac or 0.5)
			+ (Config.DodgeCenterBias or 0)
		local coverMax = ifLat + ifDur - 0.04
		if coverHi > coverMax then coverHi = coverMax end
		if coverHi < coverLo then coverHi = coverLo end

		-- ══ ПОЧЕМУ ПРИ МУЛЬТИТАРГЕТИНГЕ ДОДЖ НЕ ДЕЛАЛСЯ ВООБЩЕ ══════════════════
		-- Две причины, обе структурные.
		--
		-- 1) ОКНО ПОКРЫТИЯ БЫЛО УЖЕ, ЧЕМ i-ФРЕЙМЫ. coverHi брал лишь ПЕРВУЮ
		--    ПОЛОВИНУ неуязвимости (ifDur * DodgeCenterFrac=0.5) — это попытка
		--    попасть в середину окна, красив�� для одиночного удара. Но в замесе
		--    из-за этого «покрываемых» ударов почти не оставалось: половина
		--    физически валидного окна просто не рассматривалась.
		--
		-- 2) ЦЕЛЬ ВСЕГДА imminent[1] — САМЫЙ БЛИЖНИЙ УДАР. Если он уже ближе
		--    coverLo (а в замесе так и есть: угроз много, замечаем поздно), то
		--    coverable=false, и ВСЕ ветки доджа отказывают — outnumbered-escape,
		--    combo-escape, exposed-escape и overloaded. Хотя удары №2/№3 из этого
		--    же кластера покрывались идеально. Именно это выглядит как «тупо не
		--    успевает за врагами и не доджит»: один безнадёжно поздний удар
		--    блокировал защиту от всех остальных.
		--
		-- Правки (только в режиме мультиугрозы, одиночный бой не задет):
		--   * окно покрытия = ВСЯ неуязвимость до coverMax, а не половина;
		--   * допускаем поздний додж (MultiDodgeLateGrace) — как и просили, для
		--     мультитаргета 100% попадание в тайминг не требуется: удар придёт в
		--     начало i-фреймов или чуть раньше них, зато следующие закрыты;
		--   * если ближний удар покрыть уже нельзя — целимся в ПЕРВЫЙ покрываемый
		--     вместо отказа от доджа.
		local multiNow   = #imminent >= (Config.MultiThreatMinN or 2)
		local lateGrace  = (multiNow and Config.MultiDodgeLate ~= false)
			and (Config.MultiDodgeLateGrace or 0.06) or 0
		local coverHiEff = multiNow and coverMax or coverHi
		if coverHiEff < coverLo then coverHiEff = coverLo end
		-- Нижнюю границу НЕ опускаем ниже полукадра: удар, который прилетает
		-- раньше начала неуязвимости, доджем не спасти в принципе, а рывок сожжёт
		-- серверный кулдаун 1.5с и оставит нас без доджа на следующие удары.
		-- Отметку «покрыто» ставит не этот предикат, а фактическое окно
		-- транзакции в DODGE-CONFIRM, поэтому ложных coveredByDodge тут не будет.
		local frameQ     = math.max(V93.frameDt or 0, 1 / 60) * 0.5
		local coverLoEff = math.max(coverLo - lateGrace, frameQ)
		local function dodgeCovers(dt)
			return dt >= coverLoEff and dt <= coverHiEff
		end
		local coverable = dodgeCovers(soonestDt)

		if multiNow and not coverable then
			-- Додж един и накрывает ВСЁ, что попадает в окно неуязвимости, поэтому
			-- число накрытых ударов от выбора цели не зависит — считаем его один
			-- раз, а целью берём самый ранний покрываемый удар (imminent уже
			-- отсортирован по контакту, см. sortByContact выше).
			local pick, pickN = nil, 0
			for _, t in ipairs(imminent) do
				if dodgeCovers(t.contactAbs - now) then
					pickN = pickN + 1
					if not pick then pick = t end
				end
			end
			if pick then
				a, soonestDt, coverable = pick, pick.contactAbs - now, true
				if Config.DeepDiag and (not State.dodgeRetargetLogAt
					or now - State.dodgeRetargetLogAt > 0.25) then
					State.dodgeRetargetLogAt = now
					diagPush("DODGE-RETARGET t=%.2f ближний %s(%+.0fms) уже не покрывается → цель %s %s(%+.0fms), накроет %d уд.",
						now, tostring(imminent[1].name), (imminent[1].contactAbs - now) * 1000,
						tostring(pick.name), tostring(pick.kind), soonestDt * 1000, pickN)
				end
			end
		end

		local abuse, m2Remaining, abuseWhy = State.aliDodgeAbuseEligible(a, now, imminent, ifLat, ifDur)
		if abuse and not counterPreemptsDodge(now) then
			if performDodge(now, "ali-dodge-abuse", false, false, false, a) then
				diagPush("ALI-DODGE-ABUSE t=%.2f target=%s/%s s%d contactIn=%.0fms m2Remaining=%.2fs dir=%s", now, tostring(a.name), tostring(a.kind), a.strike or 1,
						(a.contactAbs-now)*1000, m2Remaining or -1,
						tostring(State.dodgeTxn.dodgeDirMode or "?"))
				return
			end
		elseif abuseWhy == "boxing-m2-parry" and not a.aliBoxingParryLogged then
			a.aliBoxingParryLogged = true
			diagPush("ALI-BOXING-M2=PARRY t=%.2f target=%s strike=%d contactIn=%.0fms gate=dodge-abuse", now, tostring(a.name), a.strike or 1, (a.contactAbs-now)*1000)
		end

		if Config.OutnumberEscape and evasiveGranted() and coverable
		   and not State.isAliBoxingM2(a) and not counterPreemptsDodge(now) then
			local coverableCount = 0
			for _, t in ipairs(imminent) do
				if dodgeCovers(t.contactAbs - now) then coverableCount = coverableCount + 1 end
			end
			local preferBlock = Config.OutnumberEscapePreferBlock ~= false
				and coverableCount <= 1 and canBlockNow()
			if not preferBlock then
				if performDodge(now, "outnumbered-escape") then return end
			end
		end
				if Config.ComboEscapeDodge and Config.DodgeOnParryCooldown ~= false
				   and not canBlockNow() and coverable and not State.isAliBoxingM2(a)
				   and not counterPreemptsDodge(now) then
					if performDodge(now, "combo-escape") then return end
				end
			local blatantOn = Config.SkillAddon and Config.SA_BlatantDodge
			local busyRef = (Config.ExposedEscapeAttackOnly ~= false)
				and (State.attackBusyUntil or 0) or (State.selfBusyUntil or 0)
			if blatantOn and Config.ExposedEscapeDodge and busyRef > now
			   and soonestDt <= Config.ExposedDodgeWindow and coverable and not State.isAliBoxingM2(a)
			   and not counterPreemptsDodge(now) then
				if performDodge(now, "exposed-escape(blatant)", false, true) then return end
			end

		local fireLead
		if Config.DodgeCenter then
			fireLead = ifDur * 0.5 + (Config.DodgeCenterBias or 0)
			if a.kind == "M2" then fireLead = fireLead + (Config.HeavyDodgeBias or 0) end
		else
			fireLead = Config.DodgeLead
		end
			if soonestDt <= (fireLead + up + (V93.lookahead or 0)) then
				local overloaded, why = false, nil
				local blockUp = canBlockNow()
				if not blockUp and Config.DodgeOnParryCooldown ~= false then
					if clusterStrategy ~= "HELD_GUARD" then
						if clusterN >= 2 and clusterHeavy and Config.DodgeHeavy then
							overloaded, why = true, "heavy+multi"
						elseif clusterN >= 3 then
							overloaded, why = true, string.format("%dx-burst", clusterN)
						end
					end
					if a.kind == "M2" and clusterN == 1 and Config.DodgeHeavy and not overloaded then
						overloaded, why = true, "heavy-dodge(no-block)"
					end
				end
	if not overloaded and Config.GuardbreakProtect then
		local st = blockStamina()
		if st and st <= Config.StaminaFloor then
			overloaded, why = true, string.format("guardbreak-save(st=%.0f)", st)
		end
	end
				if overloaded and counterPreemptsDodge(now) then overloaded = false end
			if overloaded and not State.isAliBoxingM2(a) then
				if performDodge(now, why) then return end
			end
			end
	end

	local midPos = computeMultiFaceGoal()
	if midPos then
		local nearest = math.huge
		for _, th in ipairs(imminent) do
			local dt = (th.contactAbs or now) - now
			if dt < nearest then nearest = dt end
		end
		local hard = nearest <= (Config.BlockFaceHardDt or 0.30) + up
		setFaceGoalPos(midPos, hard, math.max(nearest, 0) + (Config.HoldAfter or 0.12) + 0.08)
		faceTgt = nil
	end

	-- wantBlock как цель доворота берём только если удар реально в нас: сам
	-- wantBlock намеренно включает латч-угрозы (жмём на них блок «на всякий
	-- случай»), но разворачиваться под них не нужно. Прицел/визуал при этом
	-- остаётся на реальной цели, а не прыгает на чужие свинги.
	local turnTo = faceTgt or (aimedAtMe(wantBlock) and wantBlock or nil)
	if turnTo and turnTo.attackerHRP then
		local dtc = turnTo.contactAbs - now
		local hardWin = (Config.BlockFaceHardDt or 0.30) + up
		local hard = (dtc <= hardWin) or (Config.MultiFaceHard and clusterN >= (Config.MultiThreatMinN or 2))
		setFaceGoal(turnTo.attackerHRP, hard, math.max(dtc, 0) + (Config.HoldAfter or 0.12) + 0.06)
		State.vizTarget = { hrp = turnTo.attackerHRP, model = turnTo.attackerModel }
		publishTarget(turnTo)
	else
		State.vizTarget = nil
		publishTarget(nil)
	end

	local threatN, farContact = 0, nil
	do
		local seen = V93.threatSeen
		for k in pairs(seen) do seen[k] = nil end
		for _, th in ipairs(imminent) do
				local key = th.attackerModel or th.attackerHRP or th.name
				if key and not seen[key] then seen[key] = true; threatN = threatN + 1 end
				-- Угрозу, которую планируем ЗАДОДЖИТЬ, не берём в farContact: иначе
				-- блок продлевался до её контакта, держался зажатым и физически не
				-- давал уйти в додж (а зажатый блок её и не парирует).
				if not th.plannedDodge
					and (not farContact or th.contactAbs > farContact) then
					farContact = th.contactAbs
				end
		end
	end
	local multiThreat = Config.MultiThreatGuard
		and (threatN >= (Config.MultiThreatMinN or 2) or clusterN >= (Config.MultiThreatMinN or 2))
	State.multiThreat  = multiThreat
	State.multiThreatN = math.max(threatN, clusterN)
	if multiThreat then
		State.multiThreatMax   = math.max(State.multiThreatMax or 0, State.multiThreatN)
		State.multiThreatFrames = (State.multiThreatFrames or 0) + 1
		if farContact then
			local latch = farContact + Config.HoldAfter + (Config.HoldLateGrace or 0) + 0.05
			State.multiHoldUntil = math.max(State.multiHoldUntil or 0, latch)
		end
	end

	-- Если в этом кадре мы уже разменялись атакой (interrupt), НЕ парируем: guard уже
	-- уронен п��д свинг, а сама угроза помечена pressed. Иначе одновременный блок+свинг.
	if wantBlock and State.interruptFiredFrame == _C.FrameId then wantBlock = nil end

		-- ЗАЖАТЫЙ БЛОК ПОКРЫВАЕТ НЕ ВСЁ. Раньше при HELD_GUARD весь кластер разом
		-- помечался pressed/coveredByHeldGuard. Последствия ровно те, что в жалобе:
		--   * удар, который был парируемым, получал НЕ парри, а обычный блок;
		--   * тяжёлая на +500мс считалась «уже обработанной» и не получала НИ
		--     повторного парри, НИ доджа — её просто пропускали.
		-- Зажатый блок честно закрывает только те контакты, чьё окно парри уже
		-- перекрывается текущим нажатием. Всё, что дальше, обрабатывается своим
		-- решением в следующих ка��рах.
		local heldPwin = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
			or Config.PerfectWindow or 0.125
		local function heldGuardCovers(th)
			if th.plannedDodge or isMustDodge(th) then return false end
			return th.contactAbs <= now + heldPwin + up
		end

		if wantBlock then
			State.noParryNow = localChar() and localChar():GetAttribute("ParryWindowDisabled") == true
		if State.noParryNow ~= State.noParryActive then
			State.noParryActive = State.noParryNow
			diagPush("PARRY-WINDOW t=%.2f %s → %s", now, State.noParryNow and "DISABLED" or "RESTORED",
					State.noParryNow and "normal guard / must-dodge" or "perfect parry")
		end
		if State.noParryNow and State.blocking then
			wantBlock.pressed = true
			wantBlock.coveredByHeldGuard = true
			if wantBlock.rec then wantBlock.rec.blockedReason = "ParryWindowDisabled: normal guard" end
		end
			if clusterStrategy == "HELD_GUARD" and State.blocking then
				for _, th in ipairs(cluster) do
					if heldGuardCovers(th) then
						th.pressed = true
						th.coveredByHeldGuard = true
					end
				end
			end
		-- Игра НЕ требует смотреть на врага, что��ы блок/парри засчитался
		-- (Block_ModuleScript и VictimHitConfirm не проверяют направление — шлётся
		-- только флаг Blocking). ��оэтому доворот делаем ПАРАЛЛЕЛЬНО с нажатием, а не
		-- вместо него: раньше здесь стоял return, который держал парри до доворота —
		-- это и был б��г "поворачивается на врага, но больше нихуя не делает".
		-- ...и здесь тоже доворачиваемся только под удар, который реально в нас:
			-- нажатие всё равно уходит ниже независимо от доворота.
			if not wantBlock.pressed and Config.AutoFace and aimedAtMe(wantBlock)
			   and not (clusterStrategy == "HELD_GUARD") then
			local fd = faceDotToThreat(wantBlock)
			if fd ~= nil and fd < (Config.FaceGateMin or 0.2) then
				local dtc = wantBlock.contactAbs - now
				setFaceGoal(wantBlock.attackerHRP, true, math.max(dtc, 0) + (Config.HoldAfter or 0.12) + 0.06)
				if not wantBlock.faceWaitLogged then
					wantBlock.faceWaitLogged = true
					diagPush("FACETURN t=%.2f %s %s face=%.2f dt=%+.0fms → rotating + pressing", now, wantBlock.name or "?", wantBlock.kind or "?", fd, (wantBlock.contactAbs - now) * 1000)
				end
			end
		end
		-- ══ ОТСРОЧКА НАЖАТИЯ РАДИ ТЯЖЁЛОГО УДАРА ═══════════════════════════
			-- Почему одной сортировки (HEAVY-FIRST выше) недостаточно: окно нажатия
			-- у M1 открывается РАНЬШЕ, чем у M2 (252-66=186мс против 434-66=368мс),
			-- поэтому в один кадр кандидатами они почти не бывают — M1 успевает
			-- стать wantBlock и нажаться до того, как M2 вообще попадёт в список.
			-- Дальше кулдаун 0.5с, и на M2 остаётся только блок (GUARD-HOLD).
			-- Значит выбор нужно делать ЗАРАНЕЕ: если сейчас откроется нажатие на
			-- лёгкий удар, а тяжёлый прилетит внутри кулдауна после него — нажатие
			-- берёт себе тяжёлый, и M2 идёт в PERFECT вместо BLOCK.
			--
			-- Жёсткое условие безопасности: отсрочка разрешена ТОЛЬКО если лёгкий
			-- удар и без нажатия остаётся накрытым — мы уже блокируем и гард
			-- достаёт до его контакта. Менять парри на ЧИСТЫЙ пропуск нельзя
			-- никогда, поэтому без поднятого гарда отсрочки не будет.
			local deferForHeavy, heavyTh = false, nil
			if Config.HeavyFirst ~= false and not wantBlock.pressed
				and heavyRank(wantBlock) == 0 and State.blocking and heldGuardCovers(wantBlock) then
				local cd   = Config.BlockCooldown or 0.5
				local lead = Config.PerfectLead or 0.0625
				for _, th in ipairs(Threats) do
					if th ~= wantBlock and th.threatens and not th.pressed and not th.offTarget
						and heavyRank(th) > 0 and th.contactAbs > wantBlock.contactAbs
						and (th.contactAbs - wantBlock.contactAbs) < cd
						-- Тяжёлый должен быть реально достижим нажатием позже:
						-- его окно открывается после того, как отпустит кулдаун.
						and (th.contactAbs - lead - up) > now then
						deferForHeavy, heavyTh = true, th
						break
					end
				end
			end
			if deferForHeavy then
				wantBlock.coveredByHeldGuard = true
				if wantBlock.rec then wantBlock.rec.blockedReason = "DeferredForHeavy: covered by held guard" end
				if Config.DeepDiag and not wantBlock.deferLogged then
					wantBlock.deferLogged = true
					diagPush("HEAVY-DEFER t=%.2f нажатие копим на %s %s(%+.0fms): %s %s(%+.0fms) уже накрыт "
						.. "поднятым гардом, парри достаётся тяжёлому",
						now, tostring(heavyTh.name), tostring(heavyTh.kind), (heavyTh.contactAbs - now) * 1000,
						tostring(wantBlock.name), tostring(wantBlock.kind), (wantBlock.contactAbs - now) * 1000)
				end
			end
			if not wantBlock.pressed and not deferForHeavy then
			local sent = fireBlock(serverNow)
			if sent then
				wantBlock.pressed  = true
				wantBlock.pressDt  = wantBlock.contactAbs - now
					if clusterStrategy == "HELD_GUARD" then
						for _, th in ipairs(cluster) do
							if heldGuardCovers(th) then
								th.pressed = true
								th.coveredByHeldGuard = true
							end
						end
					end
				wantBlock.faceDot  = faceDotToThreat(wantBlock)
				State.rearmCount   = (State.rearmCount or 0) + 1
				if wantBlock.trustedHit and not wantBlock.trustCounted then
					wantBlock.trustCounted = true
					State.trustPress = (State.trustPress or 0) + 1
				end
				if wantBlock.rec then
					wantBlock.rec.pressDt = wantBlock.pressDt
					wantBlock.rec.pressServer = serverNow
					wantBlock.rec.pressClock = now
					wantBlock.rec.pressAt = wantBlock.contactAbs - (Config.PerfectLead or 0) - up - (wantBlock.velLead or 0)
					wantBlock.rec.pressLateBy = now - wantBlock.rec.pressAt
					wantBlock.rec.faceDot = wantBlock.faceDot
					local p1, ps = pingDiagSnapshot()
					local tpNow = wantBlock.track and safeGet(wantBlock.track, "TimePosition", -1) or -1
					diagPush("TRACE-PRESS t=%.3f srv=%.3f %s %s s%d dt=%+.0fms lateBy=%+.0fms tp=%.3f | detect net1w=%sms stats=%sms raw=%.0f med=%.0f up=%.0f | press net1w=%sms stats=%sms raw=%.0f med=%.0f up=%.0f", now, serverNow, wantBlock.name or "?", wantBlock.kind or "?", wantBlock.strike or 1,
							wantBlock.pressDt*1000, wantBlock.rec.pressLateBy*1000, tpNow,
							wantBlock.pingOneWayDetect and string.format("%.0f", wantBlock.pingOneWayDetect*1000) or "?",
							wantBlock.pingStatsDetect and string.format("%.0f", wantBlock.pingStatsDetect*1000) or "?",
							(wantBlock.pingRawDetect or 0)*1000, (wantBlock.pingMedDetect or 0)*1000,
							(wantBlock.uplinkDetect or 0)*1000,
							p1 and string.format("%.0f", p1*1000) or "?", ps and string.format("%.0f", ps*1000) or "?",
							getPingRaw()*1000, getPing()*1000, up*1000)
				end
			elseif State.blockedReason then
				if wantBlock.rec then wantBlock.rec.blockedReason = State.blockedReason end
				if wantBlock.lastReason ~= State.blockedReason then
					wantBlock.lastReason = State.blockedReason
					diagPush("BLOCK? t=%.2f  %s  %s  refused: %s", now, wantBlock.name, wantBlock.kind, State.blockedReason)
				end
			end
		end
		local holdExtra = (wantBlock.kind == "M2" and Config.M2WidenWindow) and Config.M2WidenHold or 0
		local base = wantBlock.contactAbs
			-- При SEQUENTIAL и PARRY_THEN_DODGE блок продлять НЕЛЬЗЯ: в обоих планах
			-- его надо отпустить, чтобы успеть на второе действие (повторное парри
			-- или додж). Раньше исключался только SEQUENTIAL.
			if multiThreat and farContact and farContact > base
				and clusterStrategy ~= "SEQUENTIAL"
				and clusterStrategy ~= "PARRY_THEN_DODGE" then
				base = farContact
			end
		State.holdUntil = math.max(State.holdUntil,
			base + Config.HoldAfter + (Config.HoldLateGrace or 0) + holdExtra)
	elseif State.blocking then
		local keepForCluster = (multiThreat and farContact
			and now < (farContact + Config.HoldAfter + (Config.HoldLateGrace or 0)))
			or (State.multiHoldUntil and now < State.multiHoldUntil)
		local releaseByGap = (not multiThreat) and (not (State.multiHoldUntil and now < State.multiHoldUntil))
			and (now - State.lastPress) > Config.ReleaseGap

		-- ══ ГАРД ПОСЛЕДНЕГО ШАНСА: парри → додж → БЛОК, но не пропуск ═══════════
		-- Ключевой факт, на котором всё держится: кулдаун 0.5с висит на ИНИЦИАЦИИ
		-- блока, а не на его удержании. Пока кнопка зажата, кулдаун не идёт и
		-- входящий удар гасится как обычный блок. Стоит отпустить — начинается
		-- отсчёт (State.lastBlockRelease), и следующий удар ловить уже нечем.
		-- Что было в логе: блок на кулдауне 0.5с, додж на СЕРВЕРНОМ кулдауне 1.5с
		-- ("DODGE-GATE ... Evasive.Cooldown 1.50с, прошло 0.37с"), и скрипт всё
		-- равно отпускал гард — удар приходил чистым:
		--     BLOCK? refused: BlockCooldown  →  MISS! ... blocked=BlockCooldown
		-- Поэтому перед снятием гарда проверяем: успеем ли мы вообще нажать
		-- заново к следующему удару, и если нет — сможем ли уйти доджем. Если ни
		-- то ни другое — гард НЕ отпускаем. Обычный блок вместо чистого удара.
		-- Ограничители: горизонт (не держать «на всякий случай») и стамина, иначе
		-- вместо пропущенного удара получим гардбрейк (в этом логе GUARDBREAK=2).
		local keepAsLastResort, lastResortTh = false, nil
		if Config.GuardLastResort ~= false then
			local horizon = now + (Config.GuardLastResortHorizon or 0.8)
			local soonest = nil
			for i = 1, #Threats do
				local th = Threats[i]
				if th.threatens and not th.pressed and not th.coveredByDodge
					and not th.coveredByCounter and not th.offTarget
					and th.contactAbs > now and th.contactAbs <= horizon
					and (not soonest or th.contactAbs < soonest.contactAbs) then
					soonest = th
				end
			end
			if soonest then
				local cd   = Config.BlockCooldown or 0.5
				local lead = Config.PerfectLead or 0.0625
				-- Отпустив сейчас, нажать снова сможем не раньше readyAt, а смысл
				-- нажатие имеет только до pressBy (позже сервер увидит его после удара).
				local readyAt = now + cd + (Config.BlockCooldownSafety or 0.03)
				local pressBy = soonest.contactAbs - lead - uplink()
				local canRepress = readyAt <= pressBy
				local canDodgeIt = Config.AutoDodge and dodgeReady() and canDodgeNow()
					and not counterPreemptsDodge(now)
				if not canRepress and not canDodgeIt then
					local stam = blockStamina()
					if stam == nil or stam > (Config.StaminaFloor or 18) then
						keepAsLastResort, lastResortTh = true, soonest
						State.holdUntil = math.max(State.holdUntil or 0,
							soonest.contactAbs + Config.HoldAfter + (Config.HoldLateGrace or 0))
						soonest.coveredByHeldGuard = true
					end
				end
			end
		end
		if keepAsLastResort and Config.DeepDiag
			and (not State.lastResortLogAt or now - State.lastResortLogAt > 0.25) then
			State.lastResortLogAt = now
			diagPush("GUARD-HOLD t=%.2f  %s  %s  → парри на кулдауне и додж недоступен, "
				.. "гард НЕ отпускаем (contactIn=%+.0fms): обычный блок вместо пропуска",
				now, tostring(lastResortTh.name), tostring(lastResortTh.kind),
				(lastResortTh.contactAbs - now) * 1000)
		end

		if not keepForCluster and not keepAsLastResort
			and (now >= State.holdUntil or releaseByGap) then
			releaseBlock()
			State.multiHoldUntil = 0
		end
	end

	if Config.AutoPlay and not wantBlock and #imminent == 0 then
		State.ap.step(now)
	end
end)

local function parseEvent(ev)
	local kind = ev:match("^(M%d)")
	if not kind then return nil end
	local rest = ev:sub(#kind + 1)
	if rest == "Hit" then return kind, "LATE"
	elseif rest == "Blocked" then return kind, "EARLY"
	elseif rest == "PerfectBlocked" then return kind, "PERFECT"
	elseif rest == "GuardBroken" then return kind, "GUARDBREAK" end
	return nil
end

local function outcomeTypeMatches(recType, kind)
	if recType == kind then return true end
	if kind == "M2" and recType == "SKILL" then return true end
	return false
end

local function onOutcome(attacker, result, kind, eventClock)
	local q = Pending[attacker]
	local rec, looseRec, followUp
	if q then
		for i = #q, 1, -1 do
			local r = q[i]
			local age = eventClock - r.clock
			if age >= 0 and age <= Config.MatchWindow and outcomeTypeMatches(r.type, kind) then
				if not r.matched then
					local score = math.abs((eventClock - r.clock) - (r.contact or 0))
					if r.type == kind then
						if not rec or score < (rec.matchScore or math.huge) then
							rec, r.matchScore = r, score
						end
					elseif not looseRec or score < (looseRec.matchScore or math.huge) then
						looseRec, r.matchScore = r, score
					end
				elseif not followUp and (eventClock - r.clock) <= Config.MultiHitWindow then
					followUp = r
				end
			end
		end
		if not rec then rec = looseRec end
	end

	if not rec and followUp then
		diagPush("OUT    t=%.2f  %s  %s  %s  (multi-hit follow-up +%.0fms, guard kept)", eventClock, attacker, kind, result, (eventClock - followUp.clock)*1000)
		return
	end

	if not rec then
		diagPush("OUT    t=%.2f  %s  %s  %s  (no fresh swing)", eventClock, attacker, kind, result)
		return
	end

	State.tally[result] = (State.tally[result] or 0) + 1
	State.lastResult    = result
	State.flashUntil    = os.clock() + 0.25

	if Config.DodgeTelemetry and State.lastDodgeInfo then
		local di = State.lastDodgeInfo
		local dtSinceFire = eventClock - di.fire
		if dtSinceFire >= 0 and dtSinceFire <= 0.9 then
			local hitT = eventClock
			local rel
			if hitT < di.iframeLo then
				rel = string.format("hit %.0fms BEFORE window → dodge TOO EARLY", (di.iframeLo - hitT)*1000)
			elseif hitT > di.iframeHi then
				rel = string.format("hit %.0fms AFTER window → dodge TOO LATE", (hitT - di.iframeHi)*1000)
			else
				rel = string.format("hit INSIDE i-frame window (+%.0fms from start)", (hitT - di.iframeLo)*1000)
			end
			diagPush("DODGE-OUT t=%.2f  %s  %s  %s  fired %.0fms before  [%s]", eventClock, attacker, kind, result, dtSinceFire*1000, rel)
			State.lastDodgeInfo = nil
		end
	end

	rec.matched = true
	if rec.th then rec.th.resolved = true end

	if result == "GUARDBREAK" then
		State.blocking, State.holdUntil = false, 0
	elseif result == "LATE" then
		local holding = State.blocking and (os.clock() < (State.holdUntil or 0))
		if not (State.multiThreat and holding) then State.blocking, State.holdUntil = false, 0 end
	end
	if result == "PERFECT" and rec.th and rec.th.group then
		rec.th.group.cancelled = true
	elseif result == "EARLY" and rec.th and rec.th.group then
		rec.th.group.held = true
	end
	if result == "PERFECT" and rec.th and rec.th.clusterStrategy == "HELD_GUARD" then
		for _, other in ipairs(Threats) do
			if other ~= rec.th and not other.resolved and other.contactAbs > eventClock then
				other.pressed, other.coveredByHeldGuard = false, false
				if other.rec then other.rec.pressDt, other.rec.pressServer = nil, nil end
			end
		end
		State.blocking, State.holdUntil, State.multiHoldUntil = false, 0, 0
	end
	if result == "PERFECT" then State.ap.onPerfectParry(attacker, kind) end

	local measured = eventClock - rec.clock
	local predErr  = (measured - rec.contact) * 1000
	State.lastErrMs = predErr

	local ksKey = tostring(kind) .. ":" .. tostring(rec.style or "?")
	local ks = _D.ResidByKS[ksKey]; if not ks then ks = { sum = 0, n = 0 }; _D.ResidByKS[ksKey] = ks end
	ks.sum = ks.sum + predErr; ks.n = ks.n + 1
	if ks.n > 100 then ks.sum = ks.sum * (100 / ks.n); ks.n = 100 end
	local resAvg = ks.sum / ks.n
	local resNShown = ks.n

	-- ЗАМЫК��ЕМ ОБРАТНУЮ СВЯЗЬ: копим остаток per-attacker (= скрытый пол-пинг) и
	-- глобально. residContactBias() читает это и сдвигает будущие contactAbs в окно.
	-- Раньше predErr только ПЕЧАТАЛСЯ (resAvg) и никуда не применялся — отсюда баг.
	-- ЗАМЕР ГОДЕН ТОЛЬКО ЕСЛИ СВИНГ РЕАЛЬНО ДОШЁЛ ДО КОНТАКТА.
	-- На успешном парри событие исхода приходит НЕ как урон по кругу «сервер→мы»,
	-- а как наша же смена состояния (Parried/PerfectBlocking), т.е. на одну
	-- одностороннюю задержку РАНЬШЕ. В диаге tutelzs это видно в чистом виде:
	--   PERFECT → predErr = -44, -54, -32мс  (при net1w ровно 48мс)
	--   LATE/HIT → predErr = +69, +86мс
	-- Один и тот же converseRshoes M1 с одним contact=364мс давал разброс 138мс
	-- просто в зависи��ости от ИСХОДА. Плюс на парри анимация атакующего обрывается
	-- (maxTP=0.292 при hitTL=0.364 — маркер удара не был достигнут), так что
	-- measured там вообще не время контакта. Смешивание двух классов в один
	-- ��ценщик делало resAvg бессмысленным и тянуло bias в минус (нажимать позже).
	local swingCompleted = (result ~= "PERFECT")
		and (result ~= "BLOCK" or (rec.th and (rec.th.maxTP or 0) >= (rec.th.hitTL or 0) * 0.9))
	if Config.ResidComp ~= false
		and swingCompleted
		and predErr >= (Config.ResidCompLoMs or -150)
		and predErr <= (Config.ResidCompHiMs or 400) then
		-- Скользящее среднее (sum/n с ограничением окна), а НЕ быстрая EMA: predErr
		-- шумит на ±150мс вокруг среднего ~+30мс, и EMA просто повторяла этот шум.
		local winN = Config.ResidCompWinN or 40
		local a = _D.ResidByAtk[attacker]
		if not a then
			a = { sum = 0, n = 0 }
			_D.ResidByAtk[attacker] = a
		end
		a.sum, a.n = a.sum + predErr, a.n + 1
		if a.n > winN then a.sum = a.sum * (winN / a.n); a.n = winN end
		a.ms = a.sum / a.n
		local g = _D.ResidGlobal
		g.sum, g.n = (g.sum or 0) + predErr, (g.n or 0) + 1
		if g.n > winN then g.sum = g.sum * (winN / g.n); g.n = winN end
		g.ms = g.sum / g.n
	end

	local upAtPress = math.clamp((rec.pingRaw or 0) * Config.UplinkFactor + Config.UplinkMargin,
	                             Config.UplinkMin, Config.UplinkMax) * 1000
	local eventServer = rec.detectServer and (rec.detectServer + measured) or nil
	local blockGap = nil
	if rec.pressServer and eventServer then blockGap = (eventServer - rec.pressServer) * 1000 end
	local trueGap = blockGap and (blockGap - upAtPress) or nil
	-- Учим невязку серверного зазора: сравниваем ИЗМЕРЕННЫЙ зазор с тем, на который
	-- целились. Берём только доведённые до касания свинги (на парри исход приходит
	-- раньше и зазор там не измеряется корректно — та же причина, что �� ResidComp).
	-- Учим и на PERFECT тоже. Раньше PERFECT исключался, и учиться было почти не на
	-- чем: в логе V176 обучение получило всего 2 замера при пороге 6 → поправка
	-- НИ РАЗУ не пр��менилась, хотя невязка там была +99 и +56мс. Проверено по логу:
	-- blockGap true измеряется и на PERFECT (74 и 93мс), т.е. данные пригодные.
	if trueGap and rec.th and rec.th.aimGap then
		gapBiasLearn(trueGap - rec.th.aimGap * 1000)
	end
	local gapStr  = blockGap and string.format("%+.0f→true%+.0fms", blockGap, trueGap) or "NO-PRESS"
	local pressStr = rec.pressDt and string.format("%.0fms", rec.pressDt*1000) or "—"
	local hint = "?"
	if trueGap then
		-- окно берём живое (0.125 после апдейта), а не зашитое "150" в тексте:
		-- раньше вердикт врал и EARLY-промахи считались "IN-WINDOW"
		local pwinMs = ((Config.PerfectWindowLive ~= false and GameData.perfectWindow)
			or Config.PerfectWindow or 0.125) * 1000
		if trueGap < Config.PerfectMin*1000 then hint = string.format("LATE(<%.0f)", Config.PerfectMin*1000)
		elseif trueGap > pwinMs then hint = string.format("EARLY(>%.0f)=BLOCK-NOT-PARRY", pwinMs)
		else hint = "IN-WINDOW" end
	elseif rec.pressServer == nil then
		hint = "NOT-BLOCKED"
	end

	local faceStr = rec.faceDot and string.format("%.2f", rec.faceDot) or "n/a"
	local faceFlag = (rec.faceDot ~= nil and rec.faceDot < Config.FaceGoodDot) and " BACK!" or ""
	if rec.faceDot ~= nil then
		local b = _D.FaceByResult[result]; if not b then b = { sum = 0, n = 0 }; _D.FaceByResult[result] = b end
		b.sum = b.sum + rec.faceDot; b.n = b.n + 1
		if b.n > 100 then b.sum = b.sum * (100 / b.n); b.n = 100 end
	end

	local reasonStr = rec.blockedReason and (" STATE:" .. rec.blockedReason) or ""
	if rec.blockedReason and (result == "LATE" or result == "GUARDBREAK") then
		State.stateHits = (State.stateHits or 0) + 1
	end

	do
		State.comboStat = State.comboStat or { opener = {}, tail = {} }
		local bucket = ((rec.combo or 0) >= 3) and State.comboStat.tail or State.comboStat.opener
		bucket[result] = (bucket[result] or 0) + 1
	end

	do
		local th = rec.th
		local p1, ps = pingDiagSnapshot()
		local tpOut = th and th.track and safeGet(th.track, "TimePosition", -1) or -1
		diagPush("TRACE-OUT t=%.3f %s %s s%d result=%s age=%.0fms tp=%.3f | firstThreat=%sms hbFirst=%sms hbOverlap=%sms sid=%s src=%s | pressLate=%sms | net1w=%sms stats=%sms raw=%.0f med=%.0f up=%.0f", eventClock, attacker, kind, rec.strike or 1, result, measured*1000, tpOut,
				th and th.firstThreatClock and string.format("%.0f", (th.firstThreatClock-rec.clock)*1000) or "?",
				th and th.hbFirstClock and string.format("%.0f", (th.hbFirstClock-rec.clock)*1000) or "?",
				th and th.hbOverlapClock and string.format("%.0f", (th.hbOverlapClock-rec.clock)*1000) or "?",
				tostring(th and (th.serverSwingId or (th.group and th.group.serverSwingId)) or "none"),
				tostring(th and th.recognitionSource or "none"),
				rec.pressLateBy and string.format("%+.0f", rec.pressLateBy*1000) or "?",
				p1 and string.format("%.0f", p1*1000) or "?", ps and string.format("%.0f", ps*1000) or "?",
				getPingRaw()*1000, getPing()*1000, uplink()*1000)
	end

	local atkResid = _D.ResidByAtk[attacker]
	local biasMs = (rec.th and rec.th.residBias or 0) * 1000
	diagPush("OUT    t=%.2f  %s  %s(c%d,s%d)  %-10s  meas=%.0fms pred=%.0fms predErr=%+.0fms resAvg=%+.0fms(n=%d) atkResid=%+.0fms bias=%+.0fms | blockGap=%s guard=%s pressDt=%s%s | face=%s%s spd=%.2f ping=%.0f", eventClock, attacker, kind, rec.combo or 0, rec.strike or 1, result, measured*1000, rec.contact*1000,
		        predErr, resAvg, resNShown, atkResid and atkResid.ms or 0, biasMs, gapStr, hint, pressStr, reasonStr, faceStr, faceFlag, rec.speed or 1, (rec.pingRaw or 0)*1000)
end

_C.hooked = setmetatable({}, { __mode = "k" })
_C.animIdCache = setmetatable({}, { __mode = "k" })
_C.ownerCache  = setmetatable({}, { __mode = "k" })
_C.OWNER_TTL    = 1.0

local function cachedAnimId(anim)
	local v = _C.animIdCache[anim]
	if v ~= nil then return v or nil end
	local parsed = tonumber(tostring(anim.AnimationId):match("(%d+)"))
	_C.animIdCache[anim] = parsed or false
	return parsed
end

local function cachedOwner(animator)
	local now = os.clock()
	local rec = _C.ownerCache[animator]
	if rec and (now - rec.t) < _C.OWNER_TTL then return rec end
	local model = ownerOf(animator)
	local enemy, hrp = isEnemyModel(model)
	rec = { model = model, isLocal = (model ~= nil and model == localChar()), enemy = enemy or false, hrp = hrp, t = now }
	_C.ownerCache[animator] = rec
	return rec
end

local function hookAnimator(animator)
	if _C.hooked[animator] then return end
	_C.hooked[animator] = true
	animator.AnimationPlayed:Connect(function(track)
		local anim = track and track.Animation
		if not anim then return end
		local id = cachedAnimId(anim)
		if not id then return end
		local rec = cachedOwner(animator)
		if Config.DesyncAttack and AnimLib.desyncOwnTrack and rec.isLocal then
			AnimLib.desyncOwnTrack(track, id, animator)
		end
		if not Config.Enabled then return end
		if not rec.enemy then return end
		if _D.BlockIds[id] then return end
		if not attackEntry(id) then return end
		if Config.AntiDecoy and Config.DecoyHardDrop ~= false then
			local S = State.decoySeen; if not S then S = {}; State.decoySeen = S end
			local nowd = os.clock()
			local okS, spd = pcall(function() return track.Speed end)
			if okS and type(spd) == "number" and spd > 0 then
				local lo = Config.DecoySpeedMin or 0.30
				local hi = Config.DecoySpeedMax or 1.25
				if spd < lo or spd > hi then
					State.decoyDropped = (State.decoyDropped or 0) + 1
					if (nowd - (State.lastDecoyLog or 0)) > 1 then
						State.lastDecoyLog = nowd
						aclog(string.format("[breaker] %s speed=%.2f (legal %.2f..%.2f) — phantom dropped x%d", tostring(rec.model and rec.model.Name or "?"), spd, lo, hi,
								State.decoyDropped))
					end
					return
				end
			end
			local dk = tostring(rec.model and rec.model.Name or "?") .. "|" .. tostring(id)
			local prevT = S[dk]
			if prevT and (nowd - prevT) < (Config.DecoyRefireSec or 0.60) then
				State.decoyDropped = (State.decoyDropped or 0) + 1
				if (nowd - (State.lastDecoyLog or 0)) > 1 then
					State.lastDecoyLog = nowd
					aclog(string.format("[breaker] %s same-id refire %.0fms (< %.0fms) — phantom dropped x%d", tostring(rec.model and rec.model.Name or "?"), (nowd - prevT)*1000,
							(Config.DecoyRefireSec or 0.60)*1000, State.decoyDropped))
				end
				return
			end
			S[dk] = nowd
			State.decoySweepAt = State.decoySweepAt or nowd
			if nowd >= State.decoySweepAt then
				State.decoySweepAt = nowd + (Config.DecoySweepSec or 5)
				local live = 0
				for k, t in pairs(S) do
					if (nowd - t) > 8 then S[k] = nil else live = live + 1 end
				end
				if live > (Config.DecoySeenMax or 512) then
					State.decoySeen = { [dk] = nowd }
				end
			end
		end
		local info = resolveInfo(id, rec.model)
		if not info then return end
		onAttack(rec.hrp, info, rec.model, id, track)
	end)
end

local function scanAnimators()
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch  = plr.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local an  = hum and hum:FindFirstChildOfClass("Animator")
		if an then hookAnimator(an) end
	end
	if not State.didInitialAnimatorSweep then
		State.didInitialAnimatorSweep = true
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("Animator") then hookAnimator(d) end
		end
	end
end

-- Fires for EVERY instance added anywhere in Workspace (effects, projectiles,
-- parts). ClassName compare is a single property read; :IsA walks the class
-- tree on every spawn. Animator is a final class so this is behavior-identical.
Workspace.DescendantAdded:Connect(function(d)
	if d.ClassName == "Animator" then hookAnimator(d) end
end)

task.spawn(function()
	local Shared  = ReplicatedStorage:WaitForChild("Shared", 30)
	local Network = Shared and Shared:WaitForChild("Network", 30)
	local ure     = Network and Network:WaitForChild("CombatBroadcastURE", 30)
	if not ure then dbg("CombatBroadcastURE not found — calibration off"); return end
	local myName = LocalPlayer.Name
	ure.OnClientEvent:Connect(function(eventName, attacker, victim, ...)
		if type(eventName) ~= "string" then return end
		if eventName == "StyleEvasiveCounter" then
			if attacker ~= myName then return end
			local now = os.clock()
			local tx = State.dodgeTxn
			if tx and tx.pending and now <= math.max(tx.untilAt or 0, tx.ackDeadline or 0) then
				tx.perfectConfirmed, tx.perfectAt = true, now
			diagPush("ALI-PERFECT-CONFIRM t=%.2f proc=one-perfect-dodge normalHeavyReset=false dodgeAgo=%.0fms iframeConfirmed=%s reason=%s", now, (now-(tx.fire or now))*1000, tostring(tx.confirmed == true),
					tostring(tx.reason or "?"))
			end
			return
		end
		-- Сервер сам сообщает о старте counter-стойк�� Wing Chun. Это точнее, чем
		-- ловить анимацию "M2": даёт и врагов (для гейта), и калибровку стартапа.
		if eventName == "WingChunCounterStartup" then
			local now = os.clock()
			if attacker == myName then
				if _D.WCTxn.pending and _D.WCTxn.sentAt > 0 then
					-- Авто-калибровку стартапа УБРАЛИ (дрейф → промахи). Тайминг фиксирован
					-- в wcStartup() + пинг-компенсация в wcDecide. Здесь лишь фиксируем
					-- РЕАЛЬНОЕ открытие окна ТЕКУЩЕЙ контры — это не калибровка будущего,
					-- а точное бухгалтерство активного окна ловушки.
					local ack = now - _D.WCTxn.sentAt
					_D.WCTxn.openAt  = now
					_D.WCTxn.closeAt = now + _D.WINGCHUN.CounterWindow
					diagPush("WC-STARTUP-ACK t=%.2f ack=%.0fms window=[now..+%.0fms] (fixed-timing, no-calib)",
						now, ack * 1000, _D.WINGCHUN.CounterWindow * 1000)
				end
			else
				local p = type(attacker) == "string" and Players:FindFirstChild(attacker)
				local m = p and p.Character
				if m then
					WingChunCounter[m] = now + _D.WINGCHUN.CounterWindow
					diagPush("WC-ENEMY-STANCE t=%.2f %s открыл counter-окно на %.0fms (broadcast)",
						now, tostring(attacker), _D.WINGCHUN.CounterWindow * 1000)
				end
			end
			return
		end
		if eventName == "WingChunCounterHit" then
			local now = os.clock()
			if attacker == myName then
				_D.WCTxn.pending = false
				_D.WCTxn.hits    = (_D.WCTxn.hits or 0) + 1
				State.selfBusyUntil = math.max(State.selfBusyUntil or 0,
					now + _D.WINGCHUN.CounterHoldSecs + _D.WINGCHUN.PostHitLockout)
				diagPush("WC-COUNTER-HIT t=%.2f victim=%s стан=%.1fс hold=%.0fms (hits=%d whiffs=%d)",
					now, tostring(victim), _D.WINGCHUN.VictimHitStun,
					_D.WINGCHUN.CounterHoldSecs * 1000, _D.WCTxn.hits, _D.WCTxn.whiffs or 0)
			elseif victim == myName then
				-- Нас поймали в контру: 2.2с стана, парировать нечем.
				State.selfBusyUntil = math.max(State.selfBusyUntil or 0,
					now + _D.WINGCHUN.VictimHitStun)
				diagPush("WC-COUNTERED-BY t=%.2f %s → мы в стане %.1fс",
					now, tostring(attacker), _D.WINGCHUN.VictimHitStun)
			end
			return
		end
		local kind, result = parseEvent(eventName)
		if not kind then return end
		if victim ~= myName then return end
		onOutcome(attacker, result, kind, os.clock())
	end)
	dbg("calibration active — listening CombatBroadcastURE")
end)

local function acAvailable(name)
	local ok, v = pcall(function()
		if type(getgenv) == "function" then local g = getgenv()[name]; if g ~= nil then return g end end
		return getfenv(0)[name]
	end)
	return ok and type(v) == "function"
end

local function hideHook(fn)
	if not Config.HideHooks then return fn end
	local out = fn
	if acAvailable("newcclosure") then
		local ok, c = pcall(newcclosure, fn); if ok and c then out = c end
	end
	if acAvailable("setstackhidden") then pcall(setstackhidden, out, true) end
	return out
end

local function findACScript()
	local rf = game:GetService("ReplicatedFirst")
	local s = rf:FindFirstChild(Config.ACScriptName)
	if s then return s end
	local roots = { rf }
	pcall(function()
		local lp = Players.LocalPlayer
		if lp then
			table.insert(roots, lp:FindFirstChild("PlayerScripts"))
			table.insert(roots, lp:FindFirstChild("PlayerGui"))
		end
		table.insert(roots, game:GetService("ReplicatedStorage"))
	end)
	for _, root in ipairs(roots) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("LocalScript") and d.Name:lower():find("challenging") then return d end
			end
		end
	end
	return nil
end

local function muteAC()
	if not (Config.AntiCheatBypass and Config.MuteAC) then return end
	if not acAvailable("getconnections") then
		aclog("[AC] getconnections unavailable on this executor — cannot mute AC connections"); return
	end
	local ac = findACScript()
	if not ac then
		if not State.acMissLogged then
			State.acMissLogged = true
			aclog("[AC] anticheat script NOT FOUND yet (name/location changed?) — will keep retrying")
		end
		return
	end
	State.acScript = ac
	if not State.acFoundLogged then
		State.acFoundLogged = true
		aclog(string.format("[AC] DETECTED anticheat LocalScript: %s  (parent=%s) — muting now", 
			tostring(ac.Name), tostring(ac.Parent and ac.Parent.Name or "?")))
	end

	local RS = game:GetService("RunService")
	local signals = {
		RS.Heartbeat, RS.RenderStepped, RS.Stepped, RS.PreSimulation, RS.PostSimulation,
		game.DescendantAdded, game.ChildAdded, workspace.DescendantAdded, workspace.ChildAdded,
	}
	pcall(function()
		local lp = Players.LocalPlayer
		if lp then table.insert(signals, lp.CharacterAdded); table.insert(signals, lp.Idled) end
	end)
	pcall(function()
		for _, svc in ipairs({ "ReplicatedStorage", "StarterGui", "StarterPlayer", "Players" }) do
			local s = game:GetService(svc)
			table.insert(signals, s.ChildAdded); table.insert(signals, s.DescendantAdded)
		end
	end)

	local muted = 0
	for _, sig in ipairs(signals) do
		pcall(function()
			for _, conn in ipairs(getconnections(sig)) do
				if conn.Script == ac then
					if type(conn.Disable) == "function" then
						conn:Disable(); muted = muted + 1
					elseif conn.Enabled ~= nil then
						conn.Enabled = false; muted = muted + 1
					end
				end
			end
		end)
	end
	State.acMuted = muted
	if muted > 0 then
		if (State.acMutedLogged or 0) ~= muted then
			State.acMutedLogged = muted
			aclog(string.format("[AC] BYPASS ACTIVE — muted %d connection(s) on the anticheat; script left enabled", muted))
		end
	elseif not State.acZeroLogged then
		State.acZeroLogged = true
		aclog("[AC] anticheat found but it owns no muteable connections yet — retrying")
	end
end

local function neutralizeAC()
	if not (Config.AntiCheatBypass and Config.NeutralizeAC) then return end
	if not acAvailable("getgc") then
		if not State.acNoGcLogged then
			State.acNoGcLogged = true
			aclog("[AC] getgc unavailable on this executor — cannot neutralize AC objects")
		end
		return
	end
	local killNames = {
		["_sendanticheatreport"]      = true,
		["_sendanticheatshadowreport"] = true,
		["_reportvictimhit"]          = true,
		["_scanhitboxes"]             = true,
		["_wireremotespamtouch"]      = true,
		["_reporthitbox"]             = true,
		["_reportswing"]              = true,
		["_flag"]                     = true,
	}
	local trueNames = { ["_issuppressed"] = true }
	local noop   = hideHook(function() end)
	local truefn = hideHook(function() return true end)

	local patched, tablesHit = 0, 0
	pcall(function()
		for _, o in ipairs(getgc(true)) do
			if type(o) == "table" then
				local todo
				pcall(function()
					for k, v in pairs(o) do
						if type(k) == "string" and type(v) == "function" then
							local lk = k:lower()
							if killNames[lk] then todo = todo or {}; todo[#todo + 1] = { k, noop } end
							if trueNames[lk] then todo = todo or {}; todo[#todo + 1] = { k, truefn } end
						end
					end
				end)
				if todo then
					local hitThis = false
					for _, pair in ipairs(todo) do
						if pcall(function() rawset(o, pair[1], pair[2]) end) then
							patched = patched + 1; hitThis = true
						end
					end
					if hitThis then tablesHit = tablesHit + 1 end
				end
			end
		end
	end)

	State.acNeutralized = patched
	if patched > 0 then
		if (State.acNeutLogged or 0) ~= patched then
			State.acNeutLogged = patched
			aclog(string.format("[AC] NEUTRALIZED — replaced %d report method(s) across %d AC object(s) with no-ops (report senders killed at the source)", patched, tablesHit))
		end
	elseif not State.acNeutZeroLogged then
		State.acNeutZeroLogged = true
		aclog("[AC] neutralize: no AC report methods in GC yet — retrying")
	end
end

local function scanAC()
	local L = {}
	local function w(s) L[#L + 1] = s end
	local function has(name)
		local ok, v = pcall(function()
			if type(getgenv) == "function" then local g = getgenv()[name]; if g ~= nil then return g end end
			return getfenv(0)[name]
		end)
		return ok and type(v) == "function", (ok and v) or nil
	end
	local function trunc(s, n)
		s = tostring(s):gsub("[%z\1-\8\11-\31]", ".")
		if #s > n then return s:sub(1, n) .. "…(" .. #s .. ")" end
		return s
	end

	w("===== AUTOPARRY ANTICHEAT SCAN =====")
	do
		local okId, exe, ver = pcall(function() local a, b = identifyexecutor(); return a, b end)
		w(string.format("executor: %s %s", okId and tostring(exe) or "?", okId and tostring(ver or "") or ""))
	end
	do
		local caps = { "getscriptclosure","getgc","filtergc","getconnections","getscriptbytecode",
			"getscripthash","getrunningscripts","getscriptthread","getcallingscript","decompile",
			"debug","hookfunction","newcclosure","setstackhidden","getsenv","getscripts" }
		local line = {}
		for _, c in ipairs(caps) do line[#line + 1] = (has(c) and "+" or "-") .. c end
		w("caps: " .. table.concat(line, " "))
	end

	local ac = findACScript()
	if not ac then
		w("!! AC script NOT FOUND by findACScript(). Listing candidate LocalScripts (name/parent):")
		local okScr, scripts = pcall(getscripts)
		if okScr and scripts then
			local shown = 0
			for _, s in ipairs(scripts) do
				local okA = pcall(function() return s:IsA("LocalScript") end)
				if okA and s:IsA("LocalScript") and shown < 60 then
					w(string.format("   %s  <%s>", tostring(s.Name), tostring(s.Parent and s.Parent:GetFullName() or "?")))
					shown = shown + 1
				end
			end
		end
	else
		w(string.format("AC script: %s", tostring(ac:GetFullName())))
		pcall(function() w("  hash: " .. tostring(getscripthash(ac))) end)
		pcall(function() local bc = getscriptbytecode(ac); w("  bytecode bytes: " .. tostring(bc and #bc or "?")) end)

		local hasGSC, gsc = has("getscriptclosure")
		local mainFn
		if hasGSC then local ok, f = pcall(gsc, ac); if ok then mainFn = f end end
		if type(mainFn) ~= "function" then
			w("  getscriptclosure: unavailable/failed — cannot walk protos")
		else
			local seen, fnCount = {}, 0
			local function walk(fn, depth, tag)
				if type(fn) ~= "function" or seen[fn] or depth > 6 or fnCount > 400 then return end
				seen[fn] = true; fnCount = fnCount + 1
				local info = {}
				pcall(function() local i = debug.getinfo(fn); if i then
					info = { nups = i.nups, npar = i.numparams, line = i.linedefined, name = i.name } end end)
				w(string.format("  fn[%s] d%d line=%s nups=%s name=%s", tag, depth,
					tostring(info.line or "?"), tostring(info.nups or "?"), tostring(info.name or "")))
				pcall(function()
					local cs = debug.getconstants(fn)
					if cs then for i, c in pairs(cs) do
						local t = type(c)
						if t == "string" and #c > 0 then
							w(string.format("     const[%s] %q", tostring(i), trunc(c, 90)))
						elseif t == "boolean" or t == "number" then
							w(string.format("     const[%s] = %s", tostring(i), tostring(c)))
						end
					end end
				end)
				pcall(function()
					local ups = debug.getupvalues(fn)
					if ups then for name, v in pairs(ups) do
						local t = type(v)
						local desc
						if t == "boolean" or t == "number" then desc = tostring(v)
						elseif t == "string" then desc = string.format("%q", trunc(v, 60))
						elseif t == "table" then
							local n = 0; pcall(function() for _ in pairs(v) do n = n + 1 end end)
							desc = string.format("table(#%d)", n)
						elseif t == "userdata" then
							local cls; pcall(function() cls = v.ClassName end)
							desc = "Instance<" .. tostring(cls or "userdata") .. ">"
							pcall(function() if v.Name then desc = desc .. ' "' .. tostring(v.Name) .. '"' end end)
						else desc = t end
						w(string.format("     up[%s] %s = %s", tostring(name), t, desc))
					end end
				end)
				pcall(function()
					local ps = debug.getprotos(fn)
					if ps then for i, p in ipairs(ps) do walk(p, depth + 1, tag .. "." .. i) end end
				end)
			end
			walk(mainFn, 0, "main")
			w(string.format("  (walked %d functions)", fnCount))
		end

		local hasGC, gc = has("getgc")
		if hasGC then
			local okSrc, acSrc = pcall(function() local i = debug.getinfo(mainFn); return i and i.source end)
			acSrc = okSrc and acSrc or nil
			local fnHit, tblHit = 0, 0
			local ok = pcall(function()
				for _, o in ipairs(gc(true)) do
					local t = type(o)
					if t == "function" and fnHit < 40 then
						local src; pcall(function() local i = debug.getinfo(o); src = i and i.source end)
						if src and acSrc and src == acSrc then
							local ln; pcall(function() ln = debug.getinfo(o).linedefined end)
							w(string.format("  gc.fn line=%s (AC-owned, live in GC)", tostring(ln)))
							fnHit = fnHit + 1
						end
					elseif t == "table" and tblHit < 25 then
						local keys = {}
						local okK = pcall(function()
							for k in pairs(o) do
								if type(k) == "string" then keys[#keys + 1] = k:lower() end
								if #keys > 24 then break end
							end
						end)
						if okK then
							local blob = table.concat(keys, ",")
							if blob:find("kick") or blob:find("detect") or blob:find("report")
							   or blob:find("flag") or blob:find("ban") or blob:find("exploit")
							   or blob:find("cheat") or blob:find("suspic") then
								w(string.format("  gc.table keys={%s}", trunc(blob, 120)))
								tblHit = tblHit + 1
							end
						end
					end
				end
			end)
			w(string.format("  gc sweep: %s (AC fns=%d, suspicious tables=%d)", ok and "ok" or "err", fnHit, tblHit))
		end

		local hasConn, gconn = has("getconnections")
		if hasConn then
			local RS = game:GetService("RunService")
			local sigs = {
				{ "Heartbeat", RS.Heartbeat }, { "RenderStepped", RS.RenderStepped }, { "Stepped", RS.Stepped },
				{ "PreSimulation", RS.PreSimulation }, { "PostSimulation", RS.PostSimulation },
				{ "PreRender", RS.PreRender }, { "PreAnimation", RS.PreAnimation },
				{ "game.DescendantAdded", game.DescendantAdded }, { "game.ChildAdded", game.ChildAdded },
				{ "ws.DescendantAdded", workspace.DescendantAdded },
			}
			pcall(function()
				local lp = Players.LocalPlayer
				if lp then
					sigs[#sigs+1] = { "LP.CharacterAdded", lp.CharacterAdded }
					sigs[#sigs+1] = { "LP.Idled", lp.Idled }
					if lp.Character then
						local hum = lp.Character:FindFirstChildOfClass("Humanoid")
						if hum then sigs[#sigs+1] = { "Humanoid.StateChanged", hum.StateChanged } end
					end
				end
			end)
			for _, pair in ipairs(sigs) do
				pcall(function()
					local total, mine = 0, 0
					for _, conn in ipairs(gconn(pair[2])) do
						total = total + 1
						if conn.Script == ac then mine = mine + 1 end
					end
					if total > 0 then w(string.format("  sig %s: %d conns (%d AC-owned)", pair[1], total, mine)) end
				end)
			end
		end

		pcall(function()
			local okT, th = pcall(getscriptthread, ac)
			if okT and th then w(string.format("  script thread: %s status=%s", tostring(th), tostring(coroutine.status(th)))) end
		end)
	end

	w("===== END SCAN =====")
	local report = table.concat(L, "\n")
	statusPush(report)
	local saved
	pcall(function()
		if type(writefile) == "function" then
			writefile("AutoParry_ACScan.txt", report); saved = "AutoParry_ACScan.txt"
		end
	end)
	pcall(function() if type(setclipboard) == "function" then setclipboard(report) end end)
	aclog(string.format("[AC] scan complete — %d lines%s%s", #L,
		saved and (" · saved " .. saved) or "",
		type(setclipboard) == "function" and " · copied to clipboard" or ""))
end

if Config.AntiCheatBypass then
	task.spawn(function()
		aclog("[AC] scanning for anticheat…")
		for _ = 1, 30 do
			pcall(muteAC)
			pcall(neutralizeAC)
			if (State.acMuted or 0) > 0 or (State.acNeutralized or 0) > 0 then break end
			task.wait(0.5)
		end
		if (State.acNeutralized or 0) > 0 then
			aclog(string.format("[AC] READY — %d report method(s) neutralized in GC%s; Kick+HTTP also blocked", 
				State.acNeutralized, (State.acMuted or 0) > 0 and (" + " .. State.acMuted .. " conns muted") or ""))
		elseif (State.acMuted or 0) > 0 then
			aclog(string.format("[AC] READY — anticheat muted (%d connections disabled); Kick+HTTP reports also blocked", State.acMuted))
		elseif State.acScript then
			aclog("[AC] anticheat found but nothing muteable/neutralizable yet — Kick+HTTP report blocking still active")
		else
			aclog("[AC] anticheat script not found — Kick+HTTP report blocking still active as fallback")
		end
		pcall(function()
			local lp = Players.LocalPlayer
			if lp then lp.CharacterAdded:Connect(function()
				task.wait(0.5); pcall(muteAC); pcall(neutralizeAC)
			end) end
		end)
	end)
end

if Config.AntiCheatBypass and Config.AutoScanAC then
	task.spawn(function()
		task.wait(5)
		aclog("[AC] auto-running deep scan (also on key O)…")
		local ok, err = pcall(scanAC)
		if not ok then aclog("[AC] auto-scan ERROR: " .. tostring(err)) end
	end)
end

local classifyCombat = function(a)
	if type(a) ~= "table" or a.Type ~= "Combat" then return nil end
	if a.Action == "M1" or a.Action == "M2" then return "attack" end
	if a.Action == "Evasive" then return "dash" end
	return nil
end

local function desyncApplies(action)
	if action == "M1" then return Config.DesyncApplyM1 end
	if action == "M2" then return Config.DesyncApplyM2 end
	return false
end

local function desyncMag()
	local ms = Config.DesyncDelayMs or 0
	if ms < 0 then ms = 0 end
	return ms / 1000
end

local function captureIdleId(animator)
	local myHRP = localHRP()
	local speed = 0
	if myHRP then
		local ok, v = pcall(function() return myHRP.AssemblyLinearVelocity end)
		if ok and v then speed = Vector3.new(v.X, 0, v.Z).Magnitude end
	end
	if speed > 3 then return _C.capturedIdleId end
	local best, bestW
	pcall(function()
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			local tid, looped, w = nil, false, 0
			pcall(function() tid = tonumber(tostring(t.Animation.AnimationId):match("(%d+)")) end)
			pcall(function() looped = t.Looped end)
			pcall(function() w = t.WeightCurrent end)
			if tid and looped and not _D.AttackIds[tid] then
				if not bestW or w > bestW then best, bestW = tid, w end
			end
		end
	end)
	if best then _C.capturedIdleId = best end
	return _C.capturedIdleId
end

local function getIdleDecoy(animator)
	local id = captureIdleId(animator) or Config.DesyncDecoyId or 507766388
	if _C.decoyId ~= id then
		_C.decoyId    = id
		_C.decoyTrack = nil
		pcall(function()
			_C.decoyAnim = Instance.new("Animation")
			_C.decoyAnim.AnimationId = "rbxassetid://" .. tostring(id)
		end)
	end
		if not _C.decoyTrack and _C.decoyAnim then
			pcall(function() _C.decoyTrack = animator:LoadAnimation(_C.decoyAnim) end)
			local owners = State.ap.trackOwners()
			if owners and _C.decoyTrack then owners[_C.decoyTrack] = { owner = "antiparry-idlemask" } end
		end
		return _C.decoyTrack
end

_D.SelfVerify = { conn = nil, lastLog = {}, decoyId = nil }

_D.DesyncTest = { on = false }
local toggleDesyncTest
do
local function pickAttackId()
	if Config.DesyncTestId then return Config.DesyncTestId end
	for id, e in pairs(_D.AttackIds) do
		if e and e.kind == "M1" then return id end
	end
	for id in pairs(_D.AttackIds) do return id end
	return 507766388
end
local function getTestDecoy(animator)
	local id = pickAttackId()
	if _C.testId ~= id then
		_C.testId, _C.testTrack = id, nil
		pcall(function()
			_C.testAnim = Instance.new("Animation")
			_C.testAnim.AnimationId = "rbxassetid://" .. tostring(id)
		end)
	end
		if not _C.testTrack and _C.testAnim then
			pcall(function() _C.testTrack = animator:LoadAnimation(_C.testAnim) end)
			local owners = State.ap.trackOwners()
			if owners and _C.testTrack then owners[_C.testTrack] = { owner = "antiparry-decoy" } end
		end
		return _C.testTrack, id
end
function toggleDesyncTest()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	_D.DesyncTest.on = not _D.DesyncTest.on
	if _D.DesyncTest.on then
		local track, id = getTestDecoy(animator)
		if not track then _D.DesyncTest.on = false; return end
		_D.SelfVerify.decoyId = "rbxassetid://" .. tostring(id)
		local topPrio = Enum.AnimationPriority.Action
		pcall(function() topPrio = Enum.AnimationPriority.Action4 end)
		local wgt = Config.DesyncClientVisible and 1 or 0.03
		pcall(function()
			track.Priority = topPrio
			track.Looped = true
			track:Play(0.1)
			track:AdjustWeight(wgt, 0)
		end)
		if _D.DesyncTest.conn then pcall(function() _D.DesyncTest.conn:Disconnect() end) end
		local autoEvery = 0.5
		pcall(function() local L = _C.testTrack.Length; if type(L) == "number" and L > 0.15 then autoEvery = L * 0.92 end end)
		local function replayInterval()
			local hz = tonumber(Config.DesyncSendHz) or 0
			if hz > 0 then return 1 / hz end
			return autoEvery
		end
		local nextReplay = os.clock() + replayInterval()
		_D.DesyncTest.conn = RunService.Heartbeat:Connect(function()
			if not _D.DesyncTest.on or not _C.testTrack then return end
			pcall(function()
				_C.testTrack.Priority = topPrio
				local nowc = os.clock()
				if nowc >= nextReplay or not _C.testTrack.IsPlaying then
					nextReplay = nowc + replayInterval()
					_C.testTrack:Stop(0)
					_C.testTrack:Play(0.05)
					_C.testTrack:AdjustWeight(wgt, 0)
				end
				if _C.testTrack.WeightCurrent < wgt * 0.5 then _C.testTrack:AdjustWeight(wgt, 0.1) end
			end)
		end)
	else
		if _D.DesyncTest.conn then pcall(function() _D.DesyncTest.conn:Disconnect() end); _D.DesyncTest.conn = nil end
		pcall(function() if _C.testTrack then _C.testTrack:Stop(0.1) end end)
	end
end
end
if type(getgenv) == "function" then getgenv().AP_DESYNC_TEST = toggleDesyncTest end

_D.DZ = {}
do
local function localAnimator()
	local ch = LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	return hum and hum:FindFirstChildOfClass("Animator")
end
local function topPriority()
	local p = Enum.AnimationPriority.Action
	pcall(function() p = Enum.AnimationPriority.Action4 end)
	return p
end
_D.IdleMask = { conn = nil }
local function stopIdleMask()
	if _D.IdleMask.conn then pcall(function() _D.IdleMask.conn:Disconnect() end); _D.IdleMask.conn = nil end
	pcall(function() if _C.decoyTrack then _C.decoyTrack:Stop(0.1) end end)
end
local function startIdleMask()
	if _D.IdleMask.conn then return end
	local animator = localAnimator()
	if not animator then aclog("[DESYNC:idlemask] нет аниматора (заспавнись)"); return end
	local track = getIdleDecoy(animator)
	if not track then aclog("[DESYNC:idlemask] idle-decoy не найде��"); return end
	local topPrio = topPriority()
	local wgt = Config.DesyncClientVisible and 1 or 0.92
	pcall(function() track.Priority = topPrio; track.Looped = true; track:Play(0.2); track:AdjustWeight(wgt, 0.1) end)
	_D.IdleMask.conn = RunService.Heartbeat:Connect(function()
		local an = localAnimator(); if not an then return end
		local tr = getIdleDecoy(an); if not tr then return end
		pcall(function()
			tr.Priority = topPrio
			if not tr.IsPlaying then
				tr.Looped = true
				tr:Play(0.2); tr:AdjustWeight(wgt, 0.1)
			elseif tr.WeightCurrent < wgt * 0.5 then
				tr:AdjustWeight(wgt, 0.1)
			end
		end)
	end)
	aclog("[desync] idlemask on")
end

_D.PreRun = { busyUntil = 0 }
local function firePreRunDecoy()
	local now = os.clock()
	if now < _D.PreRun.busyUntil then return end
	_D.PreRun.busyUntil = now + 0.22
	local animator = localAnimator(); if not animator then return end
	local track, id = getTestDecoy(animator); if not track then return end
	local topPrio = topPriority()
	local wgt = Config.DesyncClientVisible and 1 or 0.92
	local dur = (Config.DesyncDelayMs or 140) / 1000
	_D.SelfVerify.decoyId = "rbxassetid://" .. tostring(id)
	task.spawn(function()
		pcall(function() track.Priority = topPrio; track.Looped = false; track:Play(0.02); track:AdjustWeight(wgt, 0) end)
		task.wait(dur)
		pcall(function() track:Stop(0.05) end)
	end)
end

local function applyDesyncMode()
	stopIdleMask()
	if Config.DesyncAttack and Config.DesyncMode == "idlemask" then
		startIdleMask()
	end
end
_D.DESYNC_CYCLE = { "delay", "firedelay", "idlemask", "prerun" }
local function cycleDesyncMode()
	local cur, idx = Config.DesyncMode or "delay", 1
	for i, m in ipairs(_D.DESYNC_CYCLE) do if m == cur then idx = i break end end
	Config.DesyncMode = _D.DESYNC_CYCLE[(idx % #_D.DESYNC_CYCLE) + 1]
	applyDesyncMode()
	aclog(string.format("[desync] mode: %s%s", Config.DesyncMode, Config.DesyncAttack and "" or " (off)"))
end

_D.DZ.firePreRunDecoy = firePreRunDecoy
_D.DZ.applyDesyncMode = applyDesyncMode
_D.DZ.cycleDesyncMode = cycleDesyncMode
end
if type(getgenv) == "function" then getgenv().AP_DESYNC_MODE = _D.DZ.cycleDesyncMode end

_D.IV = {}
do
	local RS = RunService
	local function char()      return LocalPlayer.Character end
	local function humanoid()  local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
	local function rootOf()
		local c = char()
		return c and (c:FindFirstChild("HumanoidRootPart") or (humanoid() and humanoid().RootPart))
	end

	local Inv = { enabled = false, bindKey = nil, hb = nil, resp = nil, track = nil, oldcf = nil }

	local function playContort()
		if not Config.InvisibleAnim then return end
		local hum = humanoid(); if not hum then return end
		local animator = hum:FindFirstChildOfClass("Animator"); if not animator then return end
		local isR15 = hum.RigType == Enum.HumanoidRigType.R15
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. (isR15 and "18537363391" or "215384594")
		local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
		pcall(function() anim:Destroy() end)
		if ok and tr then
			Inv.track = tr
			pcall(function()
				tr.Priority = Enum.AnimationPriority.Action4
				tr:Play(0, 0.001, 0)
			end)
			task.delay(0, function() pcall(function() tr.TimePosition = isR15 and 0.77 or 0.38 end) end)
		end
	end

	local function stopInvisible()
		Inv.enabled = false
		if Inv.bindKey then pcall(function() RS:UnbindFromRenderStep(Inv.bindKey) end); Inv.bindKey = nil end
		if Inv.hb   then pcall(function() Inv.hb:Disconnect()   end); Inv.hb   = nil end
		if Inv.resp then pcall(function() Inv.resp:Disconnect() end); Inv.resp = nil end
		if Inv.track then pcall(function() Inv.track:Stop(); Inv.track:Destroy() end); Inv.track = nil end
		local r = rootOf()
		if r and Inv.oldcf then pcall(function() r.CFrame = Inv.oldcf end) end
		Inv.oldcf = nil
	end

	local function startInvisible()
		if Inv.enabled then return end
		Inv.enabled = true
		Inv.oldcf = nil
		playContort()

		Inv.bindKey = "AP_Invisible_" .. tostring(math.random(1e6, 9e6))
		pcall(function()
			RS:BindToRenderStep(Inv.bindKey, 0, function()
				local r = rootOf()
				if r and Inv.oldcf then
					r.CFrame = Inv.oldcf
					if Inv.track then pcall(function() Inv.track:AdjustWeight(0.001) end) end
				end
			end)
		end)

		Inv.hb = RS.Heartbeat:Connect(function()
			if not Inv.enabled then return end
			local r = rootOf(); local hum = humanoid()
			if not r or not hum then return end
			Inv.oldcf = r.CFrame
			local isR15 = hum.RigType == Enum.HumanoidRigType.R15
			local baseDrop = (hum.HipHeight or 2) + (r.Size.Y / 2) - 1
			local drop = baseDrop + (tonumber(Config.InvisibleHeight) or 0)
			local cf = r.CFrame - Vector3.new(0, drop, 0)
			pcall(function()
				r.CFrame = cf * CFrame.Angles(math.rad(isR15 and 180 or 90), 0, 0)
				if Inv.track then Inv.track:AdjustWeight(100) end
			end)
		end)

		Inv.resp = LocalPlayer.CharacterAdded:Connect(function()
			if not Config.InvisibleOn then return end
			task.wait(0.6)
			stopInvisible()
			if Config.InvisibleOn then startInvisible() end
		end)
	end

	function _D.IV.setInvisible(on)
		Config.InvisibleOn = on and true or false
		if Config.InvisibleOn then startInvisible() else stopInvisible() end
	end
end

_D.Observers = {}
local function observeOtherPlayer(name)
	local target = Players:FindFirstChild(name)
	if not target then
		aclog(string.format("[DESYNC-OBSERVE] игрок '%s' не найден рядом", tostring(name)))
		return
	end
	local last = {}
	local function hook(char)
		if not char then return end
		task.spawn(function()
			local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 8)
			local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 8))
			if not animator then return end
			if _D.Observers[name] then pcall(function() _D.Observers[name]:Disconnect() end) end
			_D.Observers[name] = animator.AnimationPlayed:Connect(function(track)
				pcall(function()
					local aid = track and track.Animation and track.Animation.AnimationId or "?"
					local now = os.clock()
					if (now - (last[aid] or 0)) < 0.25 then return end
					last[aid] = now
					local isAttack = _D.AttackIds and _D.AttackIds[aid] ~= nil
					local line = string.format("[OBSERVE %s] REPLICATED-TO-ME: id=%s %s prio=%s", name, tostring(aid), isAttack and "(=ATTACK id!)" or "(non-attack/idle)",
							tostring(track and track.Priority))
					aclog("[DESYNC-OBSERVE] " .. line)
					desyncPush(line)
				end)
			end)
			aclog(string.format("[DESYNC-OBSERVE] watching %s's animator — what THEY replicate to me is now logged (this is the enemy's-eye view)", name))
			desyncPush(string.format("[OBSERVE] started watching %s (enemy's-eye view of what replicates)", name))
		end)
	end
	hook(target.Character)
	target.CharacterAdded:Connect(hook)
end
if type(getgenv) == "function" then getgenv().AP_OBSERVE = observeOtherPlayer end

Players.PlayerRemoving:Connect(function(plr)
	local n = plr.Name
	local c = _D.Observers[n]
	if c then pcall(function() c:Disconnect() end); _D.Observers[n] = nil end
	if State.antiDecoySig then State.antiDecoySig[n] = nil end
	if Pending then Pending[n] = nil end
	if ComboState[n] ~= nil then
		ComboState[n] = nil
		ComboState._count = math.max((ComboState._count or 1) - 1, 0)
	end
end)

local function saveDesyncDebug()
	local header = table.concat({
		"===== AUTOPARRY DESYNC DEBUG (V75) =====",
		string.format("player=%s  mode=%s  DesyncAttack=%s  applyM1=%s applyM2=%s clientVisible=%s", LocalPlayer.Name, tostring(Config.DesyncMode), tostring(Config.DesyncAttack),
				tostring(Config.DesyncApplyM1), tostring(Config.DesyncApplyM2), tostring(Config.DesyncClientVisible)),
		string.format("raknet API present=%s  (add_send_hook=%s remove_send_hook=%s)", tostring(type(raknet) == "table"),
				tostring(type(raknet) == "table" and type(raknet.add_send_hook) == "function"),
				tostring(type(raknet) == "table" and type(raknet.remove_send_hook) == "function")),
		"legend: [SWING]=ServerCheck packet timing (SENT=immediate, HELD=delayed) | [DESYNC]=animation timing",
		"        [OBSERVE]=track seen on ANOTHER player's animator from a 2nd client (true enemy view)",
		"        [SCAN]=raknet outgoing-packet histogram (near=during my attacks, far=background)",
		"how to get the enemy-view lines: run this script on a 2nd account near your main,",
		"  then call getgenv().AP_OBSERVE(\"YourMainName\") and swing on the main.",
		"=========================================",
	}, "\n")
	local body = header .. "\n\n" .. table.concat(_D.DesyncLog, "\n") .. "\n"
	local fname = string.format("autoparry_desync_%d.txt", os.time() % 1000000)
	local ok = pcall(function() if writefile then writefile(fname, body) end end)
	if ok and writefile then
		aclog(string.format("[DESYNC] SAVED -> %s  (%d lines). Отправь мне этот файл.", fname, #_D.DesyncLog))
		if setclipboard then pcall(setclipboard, fname) end
	else
		aclog("[DESYNC] writefile unavailable — dumping debug to status log:")
		statusPush(body)
	end
	return fname
end
if type(getgenv) == "function" then getgenv().AP_SAVE_DESYNC = saveDesyncDebug end

_C.desyncBusyUntil = setmetatable({}, { __mode = "k" })
function AnimLib.desyncOwnTrack(track, id, animator)
	if not track then return end
	local entry = _D.AttackIds[id]
	if not entry then return end
	local kind = (entry.kind == "M2") and "M2" or "M1"
	if not desyncApplies(kind) then return end
	local now = os.clock()
	local busy = _C.desyncBusyUntil[track]
	if busy and now < busy then return end

	if (Config.DesyncMode or "delay") ~= "delay" then return end
	if track == _C.testTrack or track == _C.decoyTrack then return end
	if _D.DesyncTest.on then
		if (os.clock() - (State.lastAAPSkipLog or 0)) > 2 then
			State.lastAAPSkipLog = os.clock()
			aclog("[desync] anim-delay skipped �� anti-autoparry owns the anim channel (use firedelay instead)")
		end
		return
	end

	local window = (Config.DesyncDelayMs or 0) / 1000 + 0.05
	_C.desyncBusyUntil[track] = now + window

	local origSpeed = 1
	pcall(function() local s = track.Speed; if type(s) == "number" and s > 0.05 then origSpeed = s end end)
	State.desyncFires = (State.desyncFires or 0) + 1

	local animId = id
	local mag = desyncMag()
	pcall(function() track:Stop(0) end)
	task.delay(mag, function()
		pcall(function()
			track:Play(0)
			track:AdjustSpeed(origSpeed > 0 and origSpeed or 1)
		end)
	end)
	if (os.clock() - (State.lastDelayLog or 0)) > 0.15 then
		State.lastDelayLog = os.clock()
		aclog(string.format("[desync] %s anim held +%dms", kind, math.floor(mag * 1000)))
	end
end

task.spawn(function()
	if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
		dbg("combat hook: metamethod API unavailable — Guard/BlockKick/Desync disabled")
		aclog("[desync] no metamethod api")
		return
	end
	local NC_WATCHED = {
		FireServer = true, Kick = true,
		PostAsync = true, RequestAsync = true, GetAsync = true,
	}
	local nc_getMethod  = getnamecallmethod
	local nc_checkcaller = (type(checkcaller) == "function") and checkcaller or nil
	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", hideHook(function(self, ...)
		local method = nc_getMethod()
		if not NC_WATCHED[method] then return oldNamecall(self, ...) end

		local mine = (nc_checkcaller and nc_checkcaller()) or false
		if mine and method ~= "FireServer" then return oldNamecall(self, ...) end

		if Config.BlockKick and method == "Kick" then
			local okp, isPlayer = pcall(function() return typeof(self) == "Instance" and self:IsA("Player") end)
			if okp and isPlayer then
				State.kicksBlocked = (State.kicksBlocked or 0) + 1
				diagPush("BYPASS  t=%.2f  blocked local Kick on %s", os.clock(), tostring(self.Name))
				aclog(string.format("[AC] !! KICK BLOCKED #%d — anticheat tried to Player:Kick() us; swallowed", State.kicksBlocked))
				return
			end
		end

		if Config.BlockACReports
		   and (method == "PostAsync" or method == "RequestAsync" or method == "GetAsync") then
			local caller = (type(getcallingscript) == "function") and getcallingscript() or nil
			if caller and caller == State.acScript then
				State.reportsBlocked = (State.reportsBlocked or 0) + 1
				diagPush("BYPASS  t=%.2f  blocked AC HTTP %s", os.clock(), method)
				if State.reportsBlocked <= 3 or (os.clock() - (State.lastReportLog or 0)) > 5 then
					State.lastReportLog = os.clock()
					aclog(string.format("[AC] REPORT BLOCKED #%d — anticheat tried %s (detection phone-home); swallowed", State.reportsBlocked, method))
				end
				return
			end
		end

		if method ~= "FireServer" then
			return oldNamecall(self, ...)
		end
		if (State.desyncPass or 0) > 0 then return oldNamecall(self, ...) end

		local a1 = (select(1, ...))
		local ok, kind = pcall(classifyCombat, a1)
		if ok and kind then
			if not State.combatFireSeen then
				State.combatFireSeen = true
				aclog(string.format("[desync] combat FireServer intercepted (%s/%s) — hook OK", tostring(a1.Action), tostring(a1.Func)))
			end
			local now = os.clock()
				if kind == "attack" then
					State.selfBusyUntil = now + Config.SelfBusyDur
					State.attackBusyUntil = now + Config.SelfBusyDur
				local func = a1.Func
				if Config.DesyncAttack and func == "ServerCheck"
				   and (Config.DesyncMode == "firedelay" or Config.DesyncMode == "prerun")
				   and desyncApplies(a1.Action) then
					if Config.DesyncMode == "prerun" then pcall(_D.DZ.firePreRunDecoy) end
					local remote, packed, d = self, table.pack(...), desyncMag()
					task.delay(d, function()
						State.desyncPass = (State.desyncPass or 0) + 1
						pcall(function() remote:FireServer(table.unpack(packed, 1, packed.n)) end)
						State.desyncPass = State.desyncPass - 1
					end)
					if (now - (State.lastSwingLog or 0)) > 0.15 then
						State.lastSwingLog = now
						aclog(string.format("[desync] %s send held +%dms", tostring(a1.Action), math.floor(d * 1000)))
					end
					return
				end
			elseif kind == "dash" then
				State.selfBusyUntil = now + Config.DashDuration
			end
		end
		return oldNamecall(self, ...)
	end))
	AnimLib.desyncHooked = true
	dbg("combat hook active")
end)

local activeRestrictZone = function(now)
	if not Config.RestrictZone then return nil end
	local best, bestC
	for _, th in ipairs(Threats) do
		if th.threatens and th.attackerHRP and th.attackerHRP.Parent then
			local isLong   = (not Config.RestrictLongOnly) or th.kind == "M2" or th.kind == "SKILL"
			local windupOK = (th.contact0 or 0) >= Config.RestrictMinWindup
			local future   = (th.contactAbs or 0) > now
			if isLong and windupOK and future then
				if not bestC or th.contactAbs < bestC then best, bestC = th, th.contactAbs end
			end
		end
	end
	if not best then return nil end
	local center, _forward, aPos, look = hitboxGeom(best)
	if not center then return nil end
	local radius = math.max(Config.HitboxDepth or 4, Config.HitHalfWidth or 3.2)
	return {
		center = center, keepOut = radius + Config.RestrictPad, radius = radius,
		aPos = aPos, look = look, th = best,
	}
end

local restrictStep = LPH_NO_VIRTUALIZE(function(now)
	if not Config.RestrictZone then return end
	local hrp = localHRP(); if not hrp then return end
	if (now - State.lastDodge) < (Config.DashDuration + 0.05) then return end
	local z = activeRestrictZone(now); if not z then return end
	local pos  = hrp.Position
	local toC  = Vector3.new(z.center.X - pos.X, 0, z.center.Z - pos.Z)
	local dist = toC.Magnitude
	if dist < 0.05 or dist >= z.keepOut then return end
	local inward = toC.Unit
	local vel = hrp.AssemblyLinearVelocity
	local hv  = Vector3.new(vel.X, 0, vel.Z)
	local vin = hv:Dot(inward)
	if vin <= 0 then return end
	local newHV = hv - inward * vin
	hrp.AssemblyLinearVelocity = Vector3.new(newHV.X, vel.Y, newHV.Z)
	if not Config.RestrictSoft then
		local b = z.center - inward * z.keepOut
		hrp.CFrame = CFrame.new(Vector3.new(b.X, pos.Y, b.Z)) * (hrp.CFrame - hrp.CFrame.Position)
	end
end)

V93.schedulerPhase = RunService.PreSimulation and "PreSimulation" or "Heartbeat-fallback"
;(RunService.PreSimulation or RunService.Heartbeat):Connect(LPH_NO_VIRTUALIZE(function(hbDt)
	if type(hbDt) == "number" and hbDt > 0 then
		local d = math.clamp(hbDt, 1/480, 0.25)
		V93.frameDt = V93.frameDt + (d - V93.frameDt) * 0.2
		if d > V93.frameDtPeak then
			V93.frameDtPeak = d
		else
			local hl = Config.FrameLookaheadPeakDecay or 1.10
			V93.frameDtPeak = V93.frameDtPeak + (d - V93.frameDtPeak) * math.clamp(d / hl, 0, 1)
		end
	end
	do
		-- Режим низкого FPS: кадр съедает значимую долю окна парри (125мс), поэтому
		-- ориентируемся ��а ПИК кадра, иначе систематически опаздываем на кадр.
		local lowFps = (Config.LowFpsComp ~= false)
			and (V93.frameDt > ((Config.LowFpsFrameMs or 25) / 1000))
		V93.lowFps = lowFps
		local peakK = lowFps and (Config.LowFpsPeakK or 0.85)
			or (Config.FrameLookaheadPeakK or 0.5)
		local byEma  = V93.frameDt     * (Config.FrameLookahead or 0.5)
		local byPeak = V93.frameDtPeak * peakK
		local want   = (byEma > byPeak) and byEma or byPeak
		want = want + (V93.stepCost or 0) * (Config.FrameStepCostComp or 0.60)
		local cap = Config.FrameLookaheadCap or 0.045
		local capByPeak = V93.frameDtPeak * (Config.FrameLookaheadCapK or 0.75)
		if capByPeak > cap then cap = capByPeak end
		local capHi = lowFps and (Config.LowFpsCapHi or 0.13)
			or (Config.FrameLookaheadCapHi or 0.11)
		if cap > capHi then cap = capHi end
		V93.lookahead = (want < cap) and want or cap
	end
	if not Config.Enabled then
		if State.blocking then releaseBlock() end
		State.status = "OFF"
		return
	end
	local now = os.clock()
	_C.FrameId = _C.FrameId + 1
	local wantSteer = State.ap.steerUntil and now < State.ap.steerUntil and State.ap.steerDir
	local wantDodgeSteer = State.ap.dodgeSteerUntil and now < State.ap.dodgeSteerUntil and State.ap.dodgeSteerDir
	if wantSteer or wantDodgeSteer then
		local c = localChar()
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum then
			if wantSteer then pcall(V93.humMove, hum, State.ap.steerDir) end
			if wantDodgeSteer then pcall(V93.humMove, hum, State.ap.dodgeSteerDir) end
		end
	end
	local stepT0 = os.clock()
	pcall(schedulerStep, now)
	local stepMs = os.clock() - stepT0
	V93.stepCost = V93.stepCost + (stepMs - V93.stepCost) * 0.15
	if Config.PerfProbe then
		if not V93.probeLast then V93.probeLast = now end
		if stepMs > (V93.probeStepPeak or 0) then V93.probeStepPeak = stepMs end
		local tn = #Threats
		if tn > (V93.probeThreatPeak or 0) then V93.probeThreatPeak = tn end
		V93.probeFrames = (V93.probeFrames or 0) + 1
		local elapsed = now - (V93.probeLast or now)
		if elapsed >= 1 then
			local inv = 1 / math.max(elapsed, 0.001)
			aclog(string.format(
				"[perf] threats(peak)=%d | schedulerStep avg=%.2fms peak=%.2fms | willHitMe=%.0f/s GetPartBoundsInBox=%.0f/s | fps~%.0f",
				V93.probeThreatPeak or 0, (V93.stepCost or 0) * 1000, (V93.probeStepPeak or 0) * 1000,
				(V93.probeWHM or 0) * inv, (V93.probeGPBB or 0) * inv, (V93.probeFrames or 0) * inv))
			V93.probeLast = now
			V93.probeWHM, V93.probeGPBB, V93.probeStepPeak, V93.probeThreatPeak, V93.probeFrames = 0, 0, 0, 0, 0
		end
	end
	pcall(restrictStep, now)

	if State.guardUp and not State.blocking then
		pcall(sendDeactivate, true)
	end

	if _C.FrameId % 15 == 0 then
		for name, q in pairs(Pending) do
			for i = #q, 1, -1 do
				if now - q[i].clock > 3 then table.remove(q, i) end
			end
			if #q == 0 then Pending[name] = nil end
		end
	end

	if not State.blocking and State.status ~= "THREAT" then
		if now >= State.flashUntil then State.status = "ARMED" end
	end
end))

local function summary()
	local t = State.tally
	local total = (t.PERFECT or 0)+(t.EARLY or 0)+(t.LATE or 0)+(t.GUARDBREAK or 0)
	local hits = (t.LATE or 0) + (t.GUARDBREAK or 0)
	local stateHits = State.stateHits or 0
	local realMiss = math.max(0, hits - stateHits)
	local blockable = total - stateHits
	-- ВАЖНО: EARLY = ОБЫЧНЫЙ БЛОК, а НЕ парирование. В режиме Perfect блок — это
	-- ПРОМАХ по окну (нет контр-стана/бонуса). Раньше accuracy = (PERFECT+EARLY),
	-- поэтому блоки раздували цифру и казалось, что скрипт парирует. Настоящая
	-- точность парирования = только PERFECT. Блок-инклюзив оставляем как справку.
	local parryAcc = blockable > 0 and (100 * (t.PERFECT or 0) / blockable) or 0
	local acc = blockable > 0 and (100 * ((t.PERFECT or 0) + (t.EARLY or 0)) / blockable) or 0
	return table.concat({
		string.format("===== AUTOPARRY %s DIAG =====  (dumped %s UTC)", tostring(Config.Version or "?"), os.date("!%Y-%m-%d %H:%M:%S")),
		string.format("player=%s  ping=%.0fms  uplink=%.0fms  mode=%s  autoface=%s", LocalPlayer.Name, getPingRaw()*1000, uplink()*1000, Config.Mode, tostring(Config.AutoFace)),
		string.format("scheduler: phase=%s fps=%.1f frame=%.1fms peak=%.1fms lookahead=%.1fms step=%.1fms lowFps=%s", tostring(V93.schedulerPhase or "?"), 1 / math.max(V93.frameDt or 1/60, 1/480),
				(V93.frameDt or 0)*1000, (V93.frameDtPeak or 0)*1000,
				(V93.lookahead or 0)*1000, (V93.stepCost or 0)*1000,
			V93.lowFps and "YES(aggressive)" or "no"),
		string.format("model: PURE anim timeline + live TimePosition (NO calibration) | ping=robust median; lead=%.0fms hold=%.0fms window=[%.0f,%.0f]ms", Config.PerfectLead*1000, Config.HoldAfter*1000, Config.PerfectMin*1000, Config.PerfectWindow*1000),
		string.format("outcomes: PERFECT=%d  BLOCK=%d  HIT=%d  GUARDBREAK=%d  total=%d", t.PERFECT or 0, t.EARLY or 0, t.LATE or 0, t.GUARDBREAK or 0, total),
		string.format("attacks=%d  presses=%d  dodges=%d  outnumbered-escapes=%d  desync-anims=%d  ac-muted=%d  kicks-blocked=%d  reports-blocked=%d", State.parryCount, State.fireCount, State.dodgeCount, State.grantEscapes or 0, State.desyncFires or 0, State.acMuted or 0, State.kicksBlocked or 0, State.reportsBlocked or 0),
		string.format("HIT breakdown: %d total → %d game-state-locked (stun/attack/cooldown, unblockable) + %d real timing miss", hits, stateHits, realMiss),
		string.format("PARRY accuracy = %.1f%%  (%d/%d blockable landed as PERFECT-parry) | block-inclusive = %.1f%% (%d/%d as block-or-perfect)", parryAcc, t.PERFECT or 0, blockable, acc, blockable - realMiss, blockable),
		string.format("accuracy mode: %s  |  off-target swings rejected=%d  |  boxing-counter fired=%d  |  dodges skipped by counter i-frames=%d", Config.AccuracyMode or "Low", State.offTargetRej or 0, State.counterCount or 0,
				State.counterCoverSkips or 0),
		"=============================",
	}, "\n")
end

Config.RingA       = Config.RingA       or Color3.fromRGB(196, 158, 255)
Config.RingB       = Config.RingB       or Color3.fromRGB(122, 214, 255)
Config.ConeSafe    = Config.ConeSafe    or Color3.fromRGB(96, 214, 140)
Config.ConeHit     = Config.ConeHit     or Color3.fromRGB(255, 84, 84)
Config.RestrictCol = Config.RestrictCol or Color3.fromRGB(255, 72, 72)

local vizUpdate, vizHideAll
do
local RING_SEG  = 24
local CONE_SEG  = 12
local CONE_FILL = 0.32
local VIZ_CONE_HALF = math.rad(64)
local VIZ_CONE_PAD  = 5.0
local VIEW_DIST = 100

local LinePool = { items = {}, used = 0, ok = (Drawing ~= nil) }
LinePool.begin = function(self) self.used = 0 end
LinePool.get = function(self)
	if not self.ok then return nil end
	self.used = self.used + 1
	local ln = self.items[self.used]
	if not ln then
		local created = pcall(function() ln = Drawing.new("Line") end)
		if not created then self.ok = false; return nil end
		self.items[self.used] = ln
	end
	return ln
end
LinePool.finish = function(self)
	local hidden = self.hiddenTo or #self.items
	for i = self.used + 1, hidden do self.items[i].Visible = false end
	self.hiddenTo = self.used
end
LinePool.hideAll = function(self)
	for _, ln in ipairs(self.items) do ln.Visible = false end
	self.used, self.hiddenTo = 0, 0
end

local TriPool = { items = {}, used = 0, ok = (Drawing ~= nil) }
TriPool.begin = function(self) self.used = 0 end
TriPool.get = function(self)
	if not self.ok then return nil end
	self.used = self.used + 1
	local tr = self.items[self.used]
	if not tr then
		local created = pcall(function() tr = Drawing.new("Triangle"); tr.Filled = true end)
		if not created then self.ok = false; return nil end
		self.items[self.used] = tr
	end
	return tr
end
TriPool.finish = function(self)
	local hidden = self.hiddenTo or #self.items
	for i = self.used + 1, hidden do self.items[i].Visible = false end
	self.hiddenTo = self.used
end
TriPool.hideAll = function(self)
	for _, tr in ipairs(self.items) do tr.Visible = false end
	self.used, self.hiddenTo = 0, 0
end

function vizHideAll() LinePool:hideAll(); TriPool:hideAll() end

local Viz = { t = 0 }

local NEAR = 0.6

Viz.rotY = function(v, ang)
	local c, s = math.cos(ang), math.sin(ang)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

Viz.projRaw = function(cam, world)
	local sp = cam:WorldToViewportPoint(world)
	return sp.X, sp.Y, sp.Z
end

Viz.proj = function(cam, world)
	local x, y, z = Viz.projRaw(cam, world)
	return Vector2.new(x, y), z
end

Viz.drawWorldSeg = function(cam, a, b, color, thick)
	local ax, ay, az = Viz.projRaw(cam, a)
	local bx, by, bz = Viz.projRaw(cam, b)
	if az <= NEAR and bz <= NEAR then return end
	if az <= NEAR or bz <= NEAR then
		local t = (NEAR - az) / (bz - az)
		local mx, my = Viz.projRaw(cam, a:Lerp(b, t))
		if az <= NEAR then ax, ay = mx, my else bx, by = mx, my end
	end
	local ln = LinePool:get(); if not ln then return end
	ln.From, ln.To = Vector2.new(ax, ay), Vector2.new(bx, by)
	ln.Color, ln.Thickness, ln.Transparency, ln.Visible = color, thick, 1, true
end

Viz.pickTarget = function()
	local vt = State.vizTarget
	if vt and vt.model and vt.model.Parent and vt.hrp and vt.hrp.Parent then
		return vt.model, vt.hrp
	end
	-- Fallback nearest-enemy scan is O(players) and only feeds the idle cosmetic
	-- ring (no active threat). Throttle it instead of rescanning every drawn frame;
	-- 0.15s staleness is invisible on a ring, and real combat uses State.vizTarget above.
	local nowc = os.clock()
	if Viz.pickCacheHrp and Viz.pickCacheHrp.Parent and (nowc - (Viz.pickCacheT or 0)) < 0.15 then
		return Viz.pickCacheModel, Viz.pickCacheHrp
	end
	local me = localHRP(); if not me then return nil end
	local best, bestHrp, bestD = nil, nil, (Config.VizRange or VIEW_DIST)
	for _, p in ipairs(Players:GetPlayers()) do
		local ch = p.Character
		if ch then
			local ok, hrp = isEnemyModel(ch)
			if ok and hrp then
				local d = (hrp.Position - me.Position).Magnitude
				if d < bestD then best, bestHrp, bestD = ch, hrp, d end
			end
		end
	end
	Viz.pickCacheModel, Viz.pickCacheHrp, Viz.pickCacheT = best, bestHrp, nowc
	return best, bestHrp
end

Viz.bboxRaw = function(m) return m:GetBoundingBox() end
Viz.bbModel, Viz.bbClock, Viz.bbC, Viz.bbS = nil, -1, nil, nil
Viz.ringPts = {}
Viz.coneW   = {}
Viz.cone2d  = {}
Viz.coneZ   = {}
Viz.bboxOf = function(model)
	local nowc = os.clock()
	if model == Viz.bbModel and (nowc - Viz.bbClock) < 0.004 then return Viz.bbC, Viz.bbS end
	local ok, c, s = pcall(Viz.bboxRaw, model)
	if ok and typeof(c) == "CFrame" and typeof(s) == "Vector3" then
		Viz.bbModel, Viz.bbClock, Viz.bbC, Viz.bbS = model, nowc, c, s
		return c, s
	end
	return nil
end

Viz.ribbonQuad = function(cam, a, b, c, d, color, transp)
	local ax, ay, az = Viz.projRaw(cam, a)
	local bx, by, bz = Viz.projRaw(cam, b)
	local cx, cy, cz = Viz.projRaw(cam, c)
	local dx, dy, dz = Viz.projRaw(cam, d)
	if az <= 0 or bz <= 0 or cz <= 0 or dz <= 0 then return end
	local a2, b2 = Vector2.new(ax, ay), Vector2.new(bx, by)
	local c2, d2 = Vector2.new(cx, cy), Vector2.new(dx, dy)
	local t1 = TriPool:get()
	if t1 then
		t1.PointA, t1.PointB, t1.PointC = a2, b2, c2
		t1.Color, t1.Transparency, t1.Visible = color, transp, true
	end
	local t2 = TriPool:get()
	if t2 then
		t2.PointA, t2.PointB, t2.PointC = a2, c2, d2
		t2.Color, t2.Transparency, t2.Visible = color, transp, true
	end
end

Viz.gradLUT, Viz.gradA, Viz.gradB = {}, nil, nil
Viz.grad = function(a, b, f)
	if Viz.gradA ~= a or Viz.gradB ~= b then
		Viz.gradA, Viz.gradB = a, b
		local lut = Viz.gradLUT
		for i = 0, 32 do lut[i] = a:Lerp(b, i / 32) end
	end
	local i = f * 32 + 0.5
	i = (i < 0 and 0) or (i > 32 and 32) or (i // 1)
	return Viz.gradLUT[i]
end

Viz.drawRing = function(cam, model, hrp, hot)
	local footY = hrp.Position.Y - 2.8
	local radius = 3.2
	local bc, bs = Viz.bboxOf(model)
	if bc and bs then
		footY  = bc.Y - bs.Y * 0.5 + 0.08
		radius = math.clamp(math.max(bs.X, bs.Z) * 0.75, 2.4, 6)
	end
	radius = radius * (Config.VizRingScale or 1.0)
	local spd   = Config.VizRingSpeed or 1.0
	local style = Config.VizRingStyle or "Flat"
	local seg   = math.clamp(math.floor(Config.VizRingSeg or 30), 8, 48)
	local t     = Viz.t * spd
	local cx, cz = hrp.Position.X, hrp.Position.Z

	if style ~= "Orbit" and style ~= "OrbitSwirl" then
		local pulse = 1 + math.sin(t * 3.0) * 0.05
		local wpts = Viz.ringPts
		for i = 0, seg - 1 do
			local a = i / seg * math.pi * 2
			local r = radius * pulse * (1 + math.sin(a * 4 + t * 5) * 0.03)
			wpts[i] = Vector3.new(cx + math.cos(a) * r, footY, cz + math.sin(a) * r)
		end
		local thick = hot and 4 or 2.5
		for i = 0, seg - 1 do
			local j = (i + 1) % seg
			local f = 0.5 + 0.5 * math.sin(i / seg * math.pi * 2 + t * 2.2)
			Viz.drawWorldSeg(cam, wpts[i], wpts[j], Viz.grad(Config.RingA, Config.RingB, f), thick)
		end
		return
	end

	local bodyY = footY + ((bs and bs.Y or 5) * 0.5)
	local swirl = (style == "OrbitSwirl") and (t * 0.75) or 0
	local tilt  = Config.VizRingTilt or 0.7
	local rIn   = radius * 0.985

	for i = 0, seg - 1 do
		local a1 = (i / seg) * math.pi * 2 + swirl
		local a2 = ((i + 1) / seg) * math.pi * 2 + swirl
		local dy = math.cos(t + (i / seg) * math.pi * 2) * tilt
		local f  = 0.5 + 0.5 * math.sin((i / seg) * math.pi * 2 + t * 2.2)
		local col = Viz.grad(Config.RingA, Config.RingB, f)

		local y = bodyY + dy
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		Viz.ribbonQuad(cam,
			Vector3.new(cx + c1 * rIn,    y, cz + s1 * rIn),
			Vector3.new(cx + c2 * rIn,    y, cz + s2 * rIn),
			Vector3.new(cx + c2 * radius, y, cz + s2 * radius),
			Vector3.new(cx + c1 * radius, y, cz + s1 * radius), col, 1)

		if Config.VizRingMirror ~= false then
			local ym = bodyY - dy
			local rMid = (rIn + radius) * 0.5
			Viz.drawWorldSeg(cam,
				Vector3.new(cx + math.cos(-a1) * rMid, ym, cz + math.sin(-a1) * rMid),
				Vector3.new(cx + math.cos(-a2) * rMid, ym, cz + math.sin(-a2) * rMid),
				Viz.grad(Config.RingA, Config.RingB, 1 - f), hot and 3 or 2)
		end
	end
end

Viz.footYOf = function(model, hrp)
	local y = hrp.Position.Y - 2.8
	local bc, bs = Viz.bboxOf(model)
	if bc and bs then y = bc.Y - bs.Y * 0.5 + 0.05 end
	return y
end
Viz.drawTargetHitbox = function(cam, model, hrp)
	local look = hrp.CFrame.LookVector
	local flook = Vector3.new(look.X, 0, look.Z)
	if flook.Magnitude < 0.05 then return end
	flook = flook.Unit

	local style = styleOf(model)
	local styleReach = math.max(styleForward(style, "M1"), styleForward(style, "M2"))
	local reach = styleReach + VIZ_CONE_PAD
	local half  = VIZ_CONE_HALF
	local y = Viz.footYOf(model, hrp)
	local origin = Vector3.new(hrp.Position.X, y, hrp.Position.Z)

		local col = Config.ConeSafe
		local me  = localHRP()
		if me then
			local forward = styleReach
			local off  = Vector3.new(me.Position.X - hrp.Position.X, 0, me.Position.Z - hrp.Position.Z)
			local fwd  = off:Dot(flook)
			local side = math.abs(off:Dot(Vector3.new(-flook.Z, 0, flook.X)))
			local slack = Config.HitboxSlack or 0
			if fwd >= (forward - Config.HitboxDepthBack - slack) and fwd <= (forward + Config.HitboxDepth + slack)
			   and side <= (Config.HitHalfWidth + slack) then
				col = Config.ConeHit
			end
		end

	local wArc = Viz.coneW
	for i = 0, CONE_SEG do
		local ang = -half + (i / CONE_SEG) * (half * 2)
		wArc[i] = origin + Viz.rotY(flook, ang) * reach
	end
	local o2d, oz = Viz.proj(cam, origin)
	local a2d, az = Viz.cone2d, Viz.coneZ
	for i = 0, CONE_SEG do a2d[i], az[i] = Viz.proj(cam, wArc[i]) end
	for i = 0, CONE_SEG - 1 do
		if oz > NEAR and az[i] > NEAR and az[i + 1] > NEAR then
			local tr = TriPool:get()
			if tr then
				tr.PointA, tr.PointB, tr.PointC = o2d, a2d[i], a2d[i + 1]
				tr.Color, tr.Transparency, tr.Filled, tr.Visible = col, CONE_FILL, true, true
			end
		end
	end
	Viz.drawWorldSeg(cam, origin, wArc[0], col, 2)
	Viz.drawWorldSeg(cam, origin, wArc[CONE_SEG], col, 2)
	for i = 0, CONE_SEG - 1 do Viz.drawWorldSeg(cam, wArc[i], wArc[i + 1], col, 2) end
end

Viz.drawRestrictZone = function(cam)
	if not (Config.RestrictZone and Config.RestrictShowZone) then return end
	local z = activeRestrictZone(os.clock()); if not z then return end
	local aHRP = z.th.attackerHRP; if not (aHRP and aHRP.Parent) then return end
	local y  = Viz.footYOf(z.th.attackerModel, aHRP)
	local cx, cz = z.center.X, z.center.Z
	local r  = z.keepOut * (1 + math.sin(Viz.t * 4) * 0.02)
	local center3 = Vector3.new(cx, y, cz)

	local function arc(a0, a1, rr, thick, steps)
		steps = steps or 6
		local prev
		for i = 0, steps do
			local a = a0 + (a1 - a0) * (i / steps)
			local p = Vector3.new(cx + math.cos(a) * rr, y, cz + math.sin(a) * rr)
			if prev then Viz.drawWorldSeg(cam, prev, p, Config.RestrictCol, thick) end
			prev = p
		end
	end

	local bracket = math.rad(34)
	for k = 0, 3 do
		local mid = math.rad(45) + k * math.rad(90)
		arc(mid - bracket / 2, mid + bracket / 2, r, 3, 7)
	end

	local ch = math.max(r * 0.14, 0.7)
	Viz.drawWorldSeg(cam, Vector3.new(cx - ch, y, cz), Vector3.new(cx + ch, y, cz), Config.RestrictCol, 2)
	Viz.drawWorldSeg(cam, Vector3.new(cx, y, cz - ch), Vector3.new(cx, y, cz + ch), Config.RestrictCol, 2)

	if z.aPos then
		local from = Vector3.new(z.aPos.X, y, z.aPos.Z)
		local dir  = Vector3.new(cx - z.aPos.X, 0, cz - z.aPos.Z)
		if dir.Magnitude > 0.1 then
			local edge = center3 - dir.Unit * r
			Viz.drawWorldSeg(cam, from, edge, Config.RestrictCol, 1.5)
		end
	end
end

vizUpdate = LPH_NO_VIRTUALIZE(function(dt)
	if not LinePool.ok then return end
	local cam = Workspace.CurrentCamera
	if not (Config.Enabled and Config.ShowVisuals and cam) then vizHideAll(); return end
	Viz.t = Viz.t + dt

	local nowc     = os.clock()
	local interval = 1 / math.clamp(Config.VizMaxFPS or 60, 15, 240)
	if Config.VizAutoDegrade ~= false then
		local byFrame = V93.frameDt * (Config.VizFrameShare or 1.5)
		if byFrame > interval then interval = byFrame end
	end
	if (nowc - (Viz.lastDraw or 0)) < interval then return end
	local skipLim = Config.VizSkipNearPress or 0.20
	if skipLim > 0
	   and (nowc - (V93.nearPressStamp or 0)) < 0.20
	   and math.abs(V93.nearPress or math.huge) < skipLim
	   and (Viz.skipRun or 0) < (Config.VizSkipMaxFrames or 2) then
		Viz.skipRun = (Viz.skipRun or 0) + 1
		return
	end
	Viz.skipRun  = 0
	Viz.lastDraw = nowc

	LinePool:begin(); TriPool:begin()
	local model, hrp = Viz.pickTarget()
	publishVizTarget(model, hrp)
	if model and hrp then
		local hot = (State.status == "PARRY" or State.status == "DODGE")
		if Config.VizHitbox ~= false then Viz.drawTargetHitbox(cam, model, hrp) end
		if Config.VizRing ~= false then Viz.drawRing(cam, model, hrp, hot) end
	end
	if Config.VizRestrict ~= false then Viz.drawRestrictZone(cam) end
	LinePool:finish(); TriPool:finish()
end)
end

local applyFacing = LPH_NO_VIRTUALIZE(function()
	local goalPos = State.faceGoalPos
	local goalHRP = State.faceGoalHRP
	if not (goalHRP or goalPos) and not State.faceHum then return end
	local ec = localChar()
	local equipped = ec and ec:GetAttribute("Equip") == true
	if not (goalHRP or goalPos) or os.clock() > (State.faceGoalUntil or 0)
	   or (goalHRP and not goalHRP.Parent)
	   or (Config.RequireEquip ~= false and not equipped) then
		if State.faceHum then pcall(function() State.faceHum.AutoRotate = true end); State.faceHum = nil end
		State.faceGoalHRP = nil
		State.faceGoalPos = nil
		return
	end
	if not Config.AutoFace then return end
	local myHRP = localHRP()
	if not myHRP then return end
	local myPos = myHRP.Position
	local hum = ec and ec:FindFirstChildOfClass("Humanoid")
	if (Config.RotationMethod or "LookAt") ~= "AimLock" then
		if hum and hum.AutoRotate then hum.AutoRotate = false; State.faceHum = hum end
	elseif State.faceHum then
		pcall(function() State.faceHum.AutoRotate = true end); State.faceHum = nil
	end
	local aimPos = goalPos or goalHRP.Position
	local lead   = math.clamp(getPing() * (Config.FacePingLead or 1.0), 0, Config.FaceLeadCap or 0.28)
	if lead > 0 then
		local vel     = goalHRP.AssemblyLinearVelocity
		local flatVel = Vector3.new(vel.X, 0, vel.Z)
		local gp = goalHRP.Position
		local toMe = Vector3.new(myPos.X - gp.X, 0, myPos.Z - gp.Z)
		if toMe.Magnitude > 0.05 then
			local axis     = toMe.Unit
			local radialVec = axis * flatVel:Dot(axis)
			local latVec    = flatVel - radialVec
			local latOff = latVec * lead
			local latCap = Config.FaceLatMaxStuds or 18
			if latOff.Magnitude > latCap then latOff = latOff.Unit * latCap end
			local radOff = radialVec * lead
			local radCap = Config.FaceRadMaxStuds or 5
			if radOff.Magnitude > radCap then radOff = radOff.Unit * radCap end
			aimPos = aimPos + latOff + radOff
		else
			local off = flatVel * lead
			local mx  = Config.FaceLeadMaxStuds or 16
			if off.Magnitude > mx then off = off.Unit * mx end
			aimPos = aimPos + off
		end
	end
	local d = flatDirTo(myPos, aimPos)
	if not d then return end

	if (Config.RotationMethod or "LookAt") == "AimLock" then
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local cp = cam.CFrame.Position
		local target = aimPos + Vector3.new(0, 1.2, 0)
		local goalCam = CFrame.lookAt(cp, target)
		if State.faceGoalHard then
			cam.CFrame = goalCam
		else
			cam.CFrame = cam.CFrame:Lerp(goalCam, math.clamp(Config.AimLockLerp or 0.35, 0.05, 1))
		end
		return
	end

	local goal = CFrame.lookAt(myPos, myPos + d)
	if State.faceGoalHard then
		myHRP.CFrame = goal
	else
		myHRP.CFrame = myHRP.CFrame:Lerp(goal, Config.FaceLerp or 0.8)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not (Config.Enabled and Config.ShowVisuals) then return end
	local ok = pcall(vizUpdate, dt)
	if not ok then vizHideAll() end
end)

RunService.RenderStepped:Connect(function()
	pcall(applyFacing)
end)

indexAllAnims()
loadGameModules()
scanAnimators()
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then hookAnimator(animator) end
	end)
end)
task.spawn(function()
	while true do task.wait(3); scanAnimators() end
end)

return function(_Lib, _Core)
	local M = {}

	function M.start()
		Config.Enabled     = false
		Config.DesyncAttack = false
		if _D.DesyncTest.on then pcall(toggleDesyncTest) end
	end

	function M.buildUI(ctx)
		local uiReady = false
		local function notify(title, body)
			if uiReady then pcall(ctx.notify, title, body) end
		end

		local function feature(section, o)
			local guard, togEl = false, nil
			local function commit(val)
				val = val and true or false
				o.set(val)
				notify(o.Title, val and "Enabled" or "Disabled")
				guard = true
				if togEl then pcall(function() togEl:UpdateState(val) end) end
				guard = false
			end
			togEl = section:Toggle({
				Name    = "Enabled",
				Default = o.get(),
				Callback = function(v)
					if guard then return end
					commit(v)
				end,
			}, ctx.flag(o.Flag))
			if o.Desc then section:SubLabel({ Text = o.Desc }) end
			ctx.keybind(section, {
				Name = "Keybind",
				Flag = ctx.flag(o.Flag .. "_KB"),
				Toggle = function() commit(not o.get()) end,
			})
			return { commit = commit }
		end

		local function boolToggle(section, name, title, get, set)
			local guard, togEl = false, nil
			togEl = section:Toggle({
				Name = name, Default = get(),
				Callback = function(v)
					if guard then return end
					set(v and true or false)
					notify(title, v and "Enabled" or "Disabled")
				end,
			}, ctx.flag(name:gsub("%s+", "") .. "_T"))
			return togEl
		end

		local function slider(section, o)
			return section:Slider({
				Name = o.Name, Default = o.Default, Minimum = o.Min, Maximum = o.Max,
				Precision = o.Precision or 0, Suffix = o.Suffix,
				Callback = o.Callback,
			}, ctx.flag(o.Flag))
		end

		local AP = ctx.tabs.AutoParry

		local apMain = AP:Section({ Side = "Left" })

		apMain:Header({ Name = "AutoParry" })
		feature(apMain, {
			Title = "AutoParry", Flag = "AP_Enabled",
			get = function() return Config.Enabled end,
			set = function(v)
				Config.Enabled = v
				if not v then pcall(releaseBlock); pcall(vizHideAll) end
			end,
			Desc = "auto blocks n rolls hits for u\nbind works on PC + mobile",
		})

		apMain:Divider()
		apMain:Header({ Name = "Detection" })
		slider(apMain, { Name = "FOV", Flag = "AP_FOV", Default = Config.FOV or 360,
			Min = 1, Max = 360, Suffix = "°", Callback = function(v) Config.FOV = v end })
		apMain:SubLabel({ Text = "only reacts inside this cone · 360 = all around" })
		slider(apMain, { Name = "Range", Flag = "AP_Range", Default = Config.Range or 32,
			Min = 8, Max = 64, Suffix = " st", Callback = function(v) Config.Range = v end })
		slider(apMain, { Name = "Max Height Diff", Flag = "AP_MaxHeight", Default = Config.MaxHeightDiff or 12,
			Min = 4, Max = 40, Suffix = " st", Callback = function(v) Config.MaxHeightDiff = v end })
		apMain:SubLabel({ Text = "ignore enemies this far above/below you" })
		boolToggle(apMain, "Server Proof", "Server Proof",
			function() return Config.ServerProofGate ~= false end,
			function(v) Config.ServerProofGate = v end)
		apMain:SubLabel({ Text = "ignores fake anims — only parries server-confirmed swings" })
		slider(apMain, { Name = "Proof Grace", Flag = "AP_ProofGrace",
			Default = math.floor((Config.ProofGraceSec or 0.06) * 1000),
			Min = 20, Max = 150, Suffix = " ms",
			Callback = function(v) Config.ProofGraceSec = v / 1000 end })
		apMain:SubLabel({ Text = "lower = harsher on fakes · higher = safer if data is late" })
		apMain:Divider()
		apMain:Header({ Name = "Time Spoof" })
		boolToggle(apMain, "Time Spoof", "Time Spoof",
			function() return Config.TimeSpoof == true end,
			function(v) Config.TimeSpoof = v end)
		apMain:SubLabel({ Text = "back-dates the parry so late presses still land perfect" })
		slider(apMain, { Name = "Back-date", Flag = "AP_TimeShift",
			Default = Config.TimeShiftMs or 40,
			Min = 0, Max = 120, Suffix = " ms",
			Callback = function(v) Config.TimeShiftMs = v end })
		apMain:SubLabel({ Text = "how far back to claim you pressed · start ~40" })

		apMain:Divider()
		apMain:Header({ Name = "Rotation" })
		boolToggle(apMain, "Auto Face", "Auto Face", function() return Config.AutoFace end, function(v) Config.AutoFace = v end)
		apMain:SubLabel({ Text = "turn to face the attacker (needed for directional block/parry)" })
		local aimEls = {}
		local function rotVis()
			local isAim = (Config.RotationMethod or "LookAt") == "AimLock"
			for _, el in ipairs(aimEls) do pcall(function() el:SetVisibility(isAim) end) end
		end
		apMain:Dropdown({
			Name = "Method",
			Options = { "LookAt", "AimLock" },
			Default = Config.RotationMethod or "LookAt",
			Callback = function(v)
				if type(v) == "string" and v ~= "" then Config.RotationMethod = v; rotVis() end
			end,
		}, ctx.flag("AP_RotMethod"))
		apMain:SubLabel({ Text = "LookAt = turns ur model (safest for parry)\nAimLock = aims the camera instead, model isn't forced" })
		aimEls[#aimEls + 1] = slider(apMain, { Name = "Aim Speed", Flag = "AP_AimLockLerp",
			Default = math.floor((Config.AimLockLerp or 0.35) * 100), Min = 5, Max = 100, Suffix = "%",
			Callback = function(v) Config.AimLockLerp = v / 100 end })
		rotVis()
		boolToggle(apMain, "Instant Multi-Target Snap", "Multi Snap",
			function() return Config.MultiFaceHard end, function(v) Config.MultiFaceHard = v end)
		apMain:SubLabel({ Text = "in a group fight snap instantly to the next attacker" })
		boolToggle(apMain, "Hard Snap Near Contact", "Hard Snap", function() return Config.BlockFaceHard end, function(v) Config.BlockFaceHard = v end)
		apMain:SubLabel({ Text = "snap exactly on target right before the hit lands" })
		slider(apMain, { Name = "Rotation Speed", Flag = "AP_FaceLerp",
			Default = Config.FaceLerp or 0.80, Min = 0.10, Max = 1.00, Precision = 2,
			Callback = function(v) Config.FaceLerp = v end })

		local apDodge = AP:Section({ Side = "Right" })

		apDodge:Header({ Name = "Dodge" })
		feature(apDodge, {
			Title = "Auto Dodge", Flag = "AP_AutoDodge",
			get = function() return Config.AutoDodge ~= false end,
			set = function(v) Config.AutoDodge = v end,
			Desc = "master dodge switch — OFF = block/parry only",
		})
		local aggroEls = {}
		local function aggroVis()
			local on = (Config.DodgeMode or "Defensive") == "Aggressive"
			for _, el in ipairs(aggroEls) do pcall(function() el:SetVisibility(on) end) end
		end
		apDodge:Dropdown({
			Name = "Dodge Mode",
			Options = { "Defensive", "Aggressive" },
			Default = Config.DodgeMode or "Defensive",
			Callback = function(v)
				if type(v) == "string" and v ~= "" then Config.DodgeMode = v; aggroVis() end
			end,
		}, ctx.flag("AP_DodgeMode"))
		apDodge:SubLabel({ Text = "Defensive = roll away · Aggressive = orbit + close in" })
		aggroEls[#aggroEls + 1] = slider(apDodge, { Name = "Aggro Close-In", Flag = "AP_DodgeAggroClose",
			Default = math.floor((Config.DodgeAggroClose or 0.45) * 100), Min = 0, Max = 100, Suffix = "%",
			Callback = function(v) Config.DodgeAggroClose = v / 100 end })
		apDodge:SubLabel({ Text = "0 = pure orbit · 100 = cut straight in" })
		aggroVis()
		boolToggle(apDodge, "Dodge All Heavies", "Dodge All Heavies",
			function() return Config.DodgeHeavy end, function(v) Config.DodgeHeavy = v end)
		apDodge:SubLabel({ Text = "dodge M2 heavies when block is down" })
		boolToggle(apDodge, "Dodge If Cant Parry", "Dodge If Cant Parry",
			function() return Config.DodgeOnParryCooldown ~= false end,
			function(v) Config.DodgeOnParryCooldown = v end)
		apDodge:SubLabel({ Text = "dodge when parry is on cooldown, else eat it" })

		apDodge:Divider()
		apDodge:Header({ Name = "Dodge Tuning" })
		slider(apDodge, { Name = "Dodge Reaction (lead)", Flag = "AP_DodgeLead",
			Default = math.floor((Config.DodgeLead or 0.10) * 1000), Min = 40, Max = 300,
			Suffix = " ms", Callback = function(v) Config.DodgeLead = v / 1000 end })
		apDodge:SubLabel({ Text = "how early to start the roll before impact" })
		slider(apDodge, { Name = "Dodge Speed", Flag = "AP_DashSpeed", Default = Config.DashSpeed or 30,
			Min = 10, Max = 90, Suffix = " st/s", Callback = function(v) Config.DashSpeed = v end })
		slider(apDodge, { Name = "i-Frame Window", Flag = "AP_IFrame",
			Default = math.floor((Config.IFrameDur or 0.30) * 1000), Min = 120, Max = 500,
			Suffix = " ms", Callback = function(v) Config.IFrameDur = v / 1000 end })

		apDodge:Divider()
		apDodge:Header({ Name = "Must-Dodge List" })
		do
			local STYLES = {
				"Default","Basic","Boxing","Bulky","Dirty","Hakari","Karate","Kure",
				"MuayThai","SkyGaoLang","Variant","Taekwondo","Wild","WingChun",
				"Wrestling","Capoeira","Slugger","Striker",
			}
			local KINDS = { { label = "M1", key = "M1" }, { label = "M2 (Heavy)", key = "M2" } }
			local mdOptions, mdDefault = {}, {}
			for _, s in ipairs(STYLES) do
				local saved = Config.MustDodgeStyles and Config.MustDodgeStyles[s:lower()]
				for _, k in ipairs(KINDS) do
					local opt = s .. " / " .. k.label
					mdOptions[#mdOptions + 1] = opt
					if saved and (saved[k.key] or saved.all) then
						mdDefault[#mdDefault + 1] = opt
					end
				end
			end
			apDodge:Dropdown({
				Name = "Must-Dodge Attacks", Options = mdOptions, Multi = true, Search = true,
				Default = mdDefault,
				Callback = function(sel)
					local t, n = {}, 0
					for label, on in pairs(sel) do
						if on then
							local st, kindLabel = label:match("^(.-) / (.+)$")
							if st and kindLabel then
								local key = (kindLabel == "M1" and "M1")
									or (kindLabel == "M2 (Heavy)" and "M2")
								if key then
									st = st:lower()
									t[st] = t[st] or {}
									t[st][key] = true
									n = n + 1
								end
							end
						end
					end
					Config.MustDodgeStyles = t
					notify("Must-Dodge", "Selected: " .. n .. " attack(s)")
				end,
			}, ctx.flag("AP_MustDodge"))
			apDodge:SubLabel({ Text = "roll into i-frames on these instead of blocking\npick M1 or M2 per style" })
		end

		local apBox = AP:Section({ Side = "Left" })

		apBox:Header({ Name = "Skill Addons" })
		feature(apBox, {
			Title = "Skill Addons", Flag = "AP_SkillAddon",
			get = function() return Config.SkillAddon end,
			set = function(v) Config.SkillAddon = v end,
			Desc = "master switch for the per-style stuff below",
		})

		apBox:Divider()
		apBox:Header({ Name = "Boxing" })
		boolToggle(apBox, "Boxing Counter", "Boxing Counter",
			function() return Config.BoxingCounter end, function(v) Config.BoxingCounter = v end)
		apBox:SubLabel({ Text = "boxing style only\nenemy attacks in range → INSTANTLY throw ur own M2 instead of parrying" })
		slider(apBox, { Name = "Counter Range", Flag = "AP_CounterReach",
			Default = Config.BoxingCounterReach or 5.5,
			Min = 3, Max = 12, Precision = 1, Suffix = " studs",
			Callback = function(v) Config.BoxingCounterReach = v end })
		apBox:SubLabel({ Text = "max distance to the attacker to fire the instant counter M2" })

		apBox:Divider()
		apBox:Header({ Name = "Ali" })
		boolToggle(apBox, "Ali Counter", "Ali Counter",
			function() return Config.AliCounter end, function(v) Config.AliCounter = v end)
		slider(apBox, { Name = "Ali Counter Range", Flag = "AP_AliCounterReach",
			Default = Config.AliCounterReach or 7.5,
			Min = 3, Max = 14, Precision = 1, Suffix = " studs",
			Callback = function(v) Config.AliCounterReach = v end })
		boolToggle(apBox, "Ali Evasive Counter", "Ali Evasive Counter",
			function() return Config.AliEvasiveCounter end, function(v) Config.AliEvasiveCounter = v end)
		boolToggle(apBox, "Ali Dodge Abuse", "Ali Dodge Abuse",
			function() return Config.AliDodgeAbuse end, function(v) Config.AliDodgeAbuse = v end)
		slider(apBox, { Name = "Ali Rotation Hold", Flag = "AP_AliFaceLockDur",
			Default = math.floor((Config.AliFaceLockDur or 0.75) * 1000),
			Min = 200, Max = 1400, Suffix = " ms",
			Callback = function(v) Config.AliFaceLockDur = v / 1000 end })
		apBox:SubLabel({ Text = "Dodge Abuse only fires M2 after server-confirmed perfect dodge\nBoxing M2 stays parry-only" })
		apBox:Dropdown({
			Name = "Ali M2 Variant",
			Options = { "Right", "Left" },
			Default = Config.AliM2Variant or "Left",
			Callback = function(v)
				if type(v) == "string" and v ~= "" then Config.AliM2Variant = v end
			end,
		}, ctx.flag("AP_AliM2Variant"))

		apBox:Divider()
		apBox:Header({ Name = "Wing Chun" })
		boolToggle(apBox, "Wing Chun Counter", "Wing Chun Counter",
			function() return Config.WingChunCounter end,
			function(v) Config.WingChunCounter = v end)
		apBox:SubLabel({ Text = "wing chun style only\nM2 = counter STANCE, not an attack — it gives NO iframes\nenemy must LAND a hit inside the 0.5s window -> 2.2s stun + x1.25 dmg\nmistime = u eat the hit + 1s self stun + 10s cd" })
		slider(apBox, { Name = "Wing Chun Counter Range", Flag = "AP_WCReach",
			Default = Config.WingChunCounterReach or 6.5,
			Min = 3, Max = 14, Precision = 1, Suffix = " studs",
			Callback = function(v) Config.WingChunCounterReach = v end })
		slider(apBox, { Name = "Window Aim Point", Flag = "AP_WCAimFrac",
			Default = math.floor((Config.WCAimFrac or 0.35) * 100),
			Min = 10, Max = 80, Suffix = " %",
			Callback = function(v) Config.WCAimFrac = v / 100 end })
		apBox:SubLabel({ Text = "where inside the 0.5s window the enemy hit should land\nlower = fires later (safer vs early contact), higher = fires earlier" })
		apBox:SubLabel({ Text = "startup timing: FIXED 7/60 = 117ms + live ping compensation\n(auto-calibration removed — it drifted and mistimed the window)" })
		boolToggle(apBox, "WC Require Live Track", "WC Require Live Track",
			function() return Config.WCRequireLiveTrack ~= false end,
			function(v) Config.WCRequireLiveTrack = v end)
		boolToggle(apBox, "WC Solo Threat Only", "WC Solo Threat Only",
			function() return Config.WCSoloOnly ~= false end,
			function(v) Config.WCSoloOnly = v end)
		apBox:SubLabel({ Text = "no iframes -> a 2nd attacker hits u for free while u hold the stance" })
		boolToggle(apBox, "WC Skip Grabs", "WC Skip Grabs",
			function() return Config.WCSkipGrabs ~= false end,
			function(v) Config.WCSkipGrabs = v end)

		apBox:Divider()
		apBox:Header({ Name = "Counter" })
		boolToggle(apBox, "Counter Instead Of Dodge", "Counter Instead Of Dodge",
			function() return Config.CounterPreemptsDodge ~= false end,
			function(v) Config.CounterPreemptsDodge = v end)
		apBox:SubLabel({ Text = "counter instead of dodge when it already covers you" })

		apBox:Divider()
		apBox:Header({ Name = "Anti-Grab" })
		boolToggle(apBox, "Wrestling Anti-Grab", "Wrestling Anti-Grab",
			function() return Config.SA_WrestlingGrab end, function(v) Config.SA_WrestlingGrab = v end)
		apBox:SubLabel({ Text = "always roll the unblockable wrestling grab" })
		boolToggle(apBox, "Dirty Anti-Grab", "Dirty Anti-Grab",
			function() return Config.SA_DirtyGrab end, function(v) Config.SA_DirtyGrab = v end)
		apBox:SubLabel({ Text = "always roll the dirty grab (eats blocks)" })
		boolToggle(apBox, "Hakari Double Read", "Hakari Double Read",
			function() return Config.SA_HakariRead end, function(v) Config.SA_HakariRead = v end)
		apBox:SubLabel({ Text = "widens the window for late hakari M2" })

		apBox:Divider()
		apBox:Header({ Name = "Force-Dodge (client)" })
		boolToggle(apBox, "Blatant Force-Dodge", "Blatant Force-Dodge",
			function() return Config.SA_BlatantDodge end, function(v) Config.SA_BlatantDodge = v end)
		apBox:SubLabel({ Text = "dodges even when the game wont let u (client sided, obvious)" })
		slider(apBox, { Name = "Force-Dodge Window", Flag = "AP_SABlatantWin",
			Default = math.floor((Config.SA_BlatantWindow or 0.32) * 1000), Min = 150, Max = 500, Suffix = " ms",
			Callback = function(v) Config.SA_BlatantWindow = v / 1000 end })

		local apPlay = AP:Section({ Side = "Left" })

		apPlay:Header({ Name = "AutoPlay" })
		feature(apPlay, {
			Title = "AutoPlay", Flag = "AP_AutoPlay",
			get = function() return Config.AutoPlay end,
			set = function(v) Config.AutoPlay = v end,
			Desc = "auto-M1 a stunned enemy after your perfect parry",
		})

		apPlay:Divider()
		apPlay:Header({ Name = "Behaviour" })
		boolToggle(apPlay, "Reliable Attacks", "Reliable Attacks",
			function() return Config.AP_ForceNativeM1 ~= false end, function(v) Config.AP_ForceNativeM1 = v end)
		apPlay:SubLabel({ Text = "swing via the game's own M1 (survives updates)" })
		boolToggle(apPlay, "Punish After Parry", "Punish After Parry",
			function() return Config.AP_PunishOnParry ~= false end, function(v) Config.AP_PunishOnParry = v end)
	apPlay:SubLabel({ Text = "auto-M1 the enemy your parry just stunned" })
	boolToggle(apPlay, "Smooth Swings", "Smooth Swings",
		function() return Config.AP_AnimGuard ~= false end,
		function(v) Config.AP_AnimGuard = v end)
	apPlay:SubLabel({ Text = "stops the swing anim restarting on desync" })
	boolToggle(apPlay, "Counter Interrupt", "Counter Interrupt",
		function() return Config.AP_Interrupt == true end, function(v) Config.AP_Interrupt = v end)
	apPlay:SubLabel({ Text = "swing instead of parry when you land first (risky — can drop the parry, off by default)" })
	boolToggle(apPlay, "Interrupt With M2", "Interrupt With M2",
		function() return Config.AP_InterruptM2 ~= false end, function(v) Config.AP_InterruptM2 = v end)
	apPlay:SubLabel({ Text = "let the interrupt use M2, not just M1" })
	boolToggle(apPlay, "Prefer M2", "Prefer M2",
		function() return Config.AP_InterruptPreferM2 ~= false end, function(v) Config.AP_InterruptPreferM2 = v end)
	apPlay:SubLabel({ Text = "take M2 when both land in time" })
	slider(apPlay, { Name = "Interrupt M2 Range", Flag = "AP_M2BaseReach",
		Default = Config.AP_M2BaseReach or 6.5,
		Min = 3, Max = 14, Precision = 1, Suffix = " studs",
		Callback = function(v) Config.AP_M2BaseReach = v end })
	apPlay:SubLabel({ Text = "M2 reach (scaled by style/height)" })

	apPlay:Divider()
			apPlay:Header({ Name = "Combo" })
			apPlay:Dropdown({
				Name = "Combo Mode",
				Options = { "Follow", "Fixed" },
				Default = Config.AP_ComboMode or "Follow",
				Callback = function(v)
					Config.AP_ComboMode = v
					notify("Combo Mode", "Selected: " .. tostring(v))
				end,
			}, ctx.flag("AP_ComboMode"))
			apPlay:SubLabel({ Text = "Follow = natural 1→2→3→4 · Fixed = one chosen hit" })
			slider(apPlay, { Name = "Fixed Combo Hit", Flag = "AP_FixedHit", Default = Config.AP_FixedHit or 1,
				Min = 1, Max = 4, Callback = function(v) Config.AP_FixedHit = v end })
			apPlay:SubLabel({ Text = "which combo hit to throw (Fixed mode)" })
			apPlay:Button({
				Name = "Test Swing",
				Callback = function()
					local combo, ok = State.ap.testSwing()
					if ok then
						notify("Test Swing", "sent M1 hit #" .. tostring(combo)
							.. (Config.AP_ComboMode == "Fixed" and " (Fixed)" or " (next in combo)"))
					else
						notify("Test Swing", "could not swing (equip weapon / rate-limited / M1 not resolved)")
					end
				end,
			})
			apPlay:SubLabel({ Text = "fires one M1 right now with the combo animation the script would use (Fixed hit, or next in sequence)" })

		apPlay:Divider()
			apPlay:Header({ Name = "Tuning" })
			slider(apPlay, { Name = "M1 Rate", Flag = "AP_MaxPerSec", Default = Config.AP_MaxPerSec or 6,
				Min = 3, Max = 8, Suffix = " /s", Callback = function(v) Config.AP_MaxPerSec = v end })
			apPlay:SubLabel({ Text = "swings per second, spread evenly (fills the whole stun window)\n6 = safe server ceiling; 7-8 hits harder but is more detectable" })
			slider(apPlay, { Name = "M1 Reach", Flag = "AP_BaseReach", Default = Config.AP_BaseReach or 5.5,
				Min = 3, Max = 10, Precision = 1, Suffix = " st", Callback = function(v) Config.AP_BaseReach = v end })
	apPlay:SubLabel({ Text = "scaled by ur character height automatically" })

		local apVis = AP:Section({ Side = "Right" })

		apVis:Header({ Name = "Visuals" })
		feature(apVis, {
			Title = "Visuals", Flag = "AP_ShowVisuals",
			get = function() return Config.ShowVisuals end,
			set = function(v)
				Config.ShowVisuals = v
				if not v then pcall(vizHideAll) end
			end,
			Desc = "master switch for all AutoParry visuals",
		})

		apVis:Divider()
		apVis:Header({ Name = "What To Draw" })
		boolToggle(apVis, "Target Ring", "Target Ring",
			function() return Config.VizRing end,
			function(v) Config.VizRing = v; if not v then pcall(vizHideAll) end end)
		boolToggle(apVis, "Attack Cone", "Attack Cone",
			function() return Config.VizHitbox end,
			function(v) Config.VizHitbox = v; if not v then pcall(vizHideAll) end end)
		apVis:SubLabel({ Text = "their reach — green = ur safe, red = ur in it" })
		boolToggle(apVis, "Keep-Out Zone", "Keep-Out Zone",
			function() return Config.VizRestrict end,
			function(v) Config.VizRestrict = v; if not v then pcall(vizHideAll) end end)

		apVis:Divider()
		apVis:Header({ Name = "Ring" })
		local ringOrbitEls, ringSwirlEls = {}, {}
		local function ringVis()
			local st = Config.VizRingStyle or "Flat"
			local isOrbit = (st == "Orbit" or st == "OrbitSwirl")
			for _, el in ipairs(ringOrbitEls) do pcall(function() el:SetVisibility(isOrbit) end) end
			for _, el in ipairs(ringSwirlEls) do pcall(function() el:SetVisibility(st == "OrbitSwirl") end) end
		end
		apVis:Dropdown({
			Name = "Style",
			Options = { "Flat", "Orbit", "OrbitSwirl" },
			Default = Config.VizRingStyle or "Flat",
			Callback = function(v)
				if type(v) == "string" and v ~= "" then Config.VizRingStyle = v; ringVis() end
			end,
		}, ctx.flag("AP_VizRingStyle"))
		apVis:SubLabel({ Text = "Flat = line ring at their feet\nOrbit = filled 3d ribbon · OrbitSwirl = same ribbon, spinning" })
		slider(apVis, { Name = "Size", Flag = "AP_VizRingScale",
			Default = math.floor((Config.VizRingScale or 1) * 100), Min = 40, Max = 250, Suffix = "%",
			Callback = function(v) Config.VizRingScale = v / 100 end })
		slider(apVis, { Name = "Speed", Flag = "AP_VizRingSpeed",
			Default = math.floor((Config.VizRingSpeed or 1) * 100), Min = 10, Max = 300, Suffix = "%",
			Callback = function(v) Config.VizRingSpeed = v / 100 end })
		slider(apVis, { Name = "Smoothness", Flag = "AP_VizRingSeg",
			Default = Config.VizRingSeg or 30, Min = 8, Max = 48, Suffix = "",
			Callback = function(v) Config.VizRingSeg = v end })
		ringOrbitEls[#ringOrbitEls + 1] = slider(apVis, { Name = "Depth", Flag = "AP_VizRingTilt",
			Default = math.floor((Config.VizRingTilt or 0.7) * 100), Min = 10, Max = 200, Suffix = "%",
			Callback = function(v) Config.VizRingTilt = v / 100 end })
		ringOrbitEls[#ringOrbitEls + 1] = boolToggle(apVis, "Mirror Band", "Ring Mirror",
			function() return Config.VizRingMirror ~= false end,
			function(v) Config.VizRingMirror = v end)
		ringVis()
		apVis:Colorpicker({ Name = "Color A", Default = Config.RingA,
			Callback = function(c) Config.RingA = c end }, ctx.flag("AP_RingA"))
		apVis:Colorpicker({ Name = "Color B", Default = Config.RingB,
			Callback = function(c) Config.RingB = c end }, ctx.flag("AP_RingB"))

		apVis:Divider()
		apVis:Header({ Name = "Cone & Zone Colors" })
		apVis:Colorpicker({ Name = "Cone (safe)", Default = Config.ConeSafe,
			Callback = function(c) Config.ConeSafe = c end }, ctx.flag("AP_ConeSafe"))
		apVis:Colorpicker({ Name = "Cone (in range)", Default = Config.ConeHit,
			Callback = function(c) Config.ConeHit = c end }, ctx.flag("AP_ConeHit"))
		apVis:Colorpicker({ Name = "Keep-Out", Default = Config.RestrictCol,
			Callback = function(c) Config.RestrictCol = c end }, ctx.flag("AP_Restrict"))

		apVis:Divider()
		apVis:Header({ Name = "Performance" })
		slider(apVis, { Name = "Draw Distance", Flag = "AP_VizRange",
			Default = Config.VizRange or 100, Min = 20, Max = 250, Suffix = " st",
			Callback = function(v) Config.VizRange = v end })
		slider(apVis, { Name = "Redraw Cap", Flag = "AP_VizMaxFPS",
			Default = Config.VizMaxFPS or 60, Min = 15, Max = 240, Suffix = " fps",
			Callback = function(v) Config.VizMaxFPS = v end })
		apVis:SubLabel({ Text = "how often the overlay redraws, not ur game fps. lower = more headroom" })

		local DS = ctx.tabs.Desync

		local dsSelf = DS:Section({ Side = "Left" })
		dsSelf:Header({ Name = "Anti AutoParry" })
		feature(dsSelf, {
			Title = "Anti AutoParry", Flag = "DS_Test",
			get = function() return _D.DesyncTest.on end,
			set = function(v)
				if (_D.DesyncTest.on and true or false) ~= v then pcall(toggleDesyncTest) end
			end,
			Desc = "fakes a swing while u move\nenemy autoparry bites on nothing",
		})
		slider(dsSelf, { Name = "Send Frequency", Flag = "DS_SendHz", Default = Config.DesyncSendHz or 0,
			Min = 0, Max = 20, Suffix = " Hz", Callback = function(v) Config.DesyncSendHz = v end })
		dsSelf:SubLabel({ Text = "decoy re-sends per second\n0 = auto" })
		boolToggle(dsSelf, "Client Visible", "Desync Client Visible",
			function() return Config.DesyncClientVisible end,
			function(v) Config.DesyncClientVisible = v end)

		local dsAtk = DS:Section({ Side = "Right" })
		dsAtk:Header({ Name = "Attack Desync" })
		feature(dsAtk, {
			Title = "Attack Desync", Flag = "DS_Attack",
			get = function() return Config.DesyncAttack end,
			set = function(v) Config.DesyncAttack = v end,
			Desc = "desyncs ur swings so enemies mistime the parry",
		})
		dsAtk:Dropdown({
			Name = "Desync Mode", 			Options = { "delay", "firedelay", "idlemask", "prerun" },
			Default = Config.DesyncMode or "delay",
			Callback = function(v)
				Config.DesyncMode = v
				pcall(function() if _D.DZ and _D.DZ.applyDesyncMode then _D.DZ.applyDesyncMode() end end)
				notify("Desync Mode", "Selected: " .. tostring(v))
			end,
		}, ctx.flag("DS_Mode"))
		dsAtk:SubLabel({ Text = "not working shit  but i will fix it later ok?" })
		slider(dsAtk, { Name = "Desync Delay", Flag = "DS_Delay", Default = Config.DesyncDelayMs or 140,
			Min = 40, Max = 400, Suffix = " ms", Callback = function(v) Config.DesyncDelayMs = v end })
		boolToggle(dsAtk, "Apply to M1", "Desync M1", function() return Config.DesyncApplyM1 end, function(v) Config.DesyncApplyM1 = v end)
		boolToggle(dsAtk, "Apply to M2", "Desync M2", function() return Config.DesyncApplyM2 end, function(v) Config.DesyncApplyM2 = v end)

		local dsInv = DS:Section({ Side = "Left" })
		dsInv:Header({ Name = "Invisible" })
		feature(dsInv, {
			Title = "Invisible", Flag = "DS_Invisible",
			get = function() return Config.InvisibleOn end,
			set = function(v) pcall(function() _D.IV.setInvisible(v) end) end,
			Desc = "drops ur body underground for everyone else\nu still look normal to urself",
		})
		slider(dsInv, { Name = "Invisible Height", Flag = "DS_InvHeight", Default = Config.InvisibleHeight or 0,
			Min = 0, Max = 15, Suffix = " studs", Callback = function(v) Config.InvisibleHeight = v end })
		dsInv:SubLabel({ Text = "extra studs\n2-3 is good" })
		boolToggle(dsInv, "Contort Anim", "Invisible Anim",
			function() return Config.InvisibleAnim end, function(v) Config.InvisibleAnim = v end)

		local DB = ctx.tabs.Debug

		local dbLog = DB:Section({ Side = "Left" })
		dbLog:Header({ Name = "Status Log" })
		local statusPara = dbLog:Paragraph({ Header = "Live events", Body = "—" })
		local function renderStatus()
			local n = #_D.StatusLog
			if n == 0 then statusPara:UpdateBody("No events yet."); return end
			local shown = math.min(16, n)
			local out = { string.format("Showing %d of %d (newest first):", shown, n), "" }
			for i = n, n - shown + 1, -1 do
				out[#out + 1] = "• " .. tostring(_D.StatusLog[i])
			end
			statusPara:UpdateBody(table.concat(out, "\n"))
		end
		renderStatus()
		dbLog:Button({ Name = "Refresh", Callback = renderStatus })
		dbLog:Button({ Name = "Clear", Callback = function()
			table.clear(_D.StatusLog); statusPara:UpdateBody("No events yet.")
		end })
		task.spawn(function()
			while statusPara do
				task.wait(1.5)
				pcall(renderStatus)
			end
		end)

		local dbDiag = DB:Section({ Side = "Right" })
		dbDiag:Header({ Name = "Diagnostics" })
		local copyDiag = false
		dbDiag:Button({
			Name = "Save AutoParry diag",
			Callback = function()
				local body  = summary() .. "\n\n" .. table.concat(_D.DiagLog, "\n") .. "\n"
				local fname = string.format("autoparry_diag_%d.txt", os.time() % 1000000)
				local wrote = pcall(function() if writefile then writefile(fname, body) end end) and (writefile ~= nil)
				if copyDiag and type(setclipboard) == "function" then
					pcall(setclipboard, body)
				end
				if wrote then
					notify("Diagnostics", (copyDiag and "Saved + copied: " or "Saved: ") .. fname)
				elseif copyDiag and type(setclipboard) == "function" then
					notify("Diagnostics", "writefile unavailable — copied log to clipboard")
				else
					notify("Diagnostics", "writefile/clipboard unavailable")
				end
			end,
		})
		boolToggle(dbDiag, "Copy", "Diag Copy",
			function() return copyDiag end,
			function(v) copyDiag = v end)

		task.defer(function() uiReady = true end)
	end

	return M
end

