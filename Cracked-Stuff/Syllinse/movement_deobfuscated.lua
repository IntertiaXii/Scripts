-- deobf Luraph 14.8
-- ez
-- by Intertia

local Movement = {}

local function refGet(ref)
    return ref[1][ref[3]]
end

local function refSet(ref, value)
    ref[1][ref[3]] = value
end

function Movement.createSpeedStep(deps)
    local shouldSkipMovement = deps[1]
    local config = deps[0]
    local Vector3_new = deps[2]
    local getCharacterParts = deps[3]

    return function(dt)
        if not config.Speed_On then
            return
        end

        local character, humanoid, rootPart = getCharacterParts()
        if not humanoid then
            return
        end

        if shouldSkipMovement(character, rootPart) then
            return
        end

        local direction = humanoid.MoveDirection
        if direction.Magnitude < 1e-3 then
            return
        end

        local speed = config.Speed_Value

        if config.Speed_Mode == "Velocity" then
            local currentY = rootPart.AssemblyLinearVelocity.Y

            rootPart.AssemblyLinearVelocity =
                (direction * speed) + Vector3_new(0, currentY, 0)
        else
            rootPart.CFrame =
                rootPart.CFrame + (direction * speed * dt)
        end
    end
end

function Movement.createFlyStep(deps)
    local flyUpInputRef = deps[10]
    local workspaceService = deps[3]
    local transformMoveDirection = deps[12]
    local Vector3_new = deps[7]
    local activateFlyState = deps[0]
    local getCharacterParts = deps[8]
    local flyActiveRef = deps[1]
    local config = deps[4]
    local zeroVector = deps[2]
    local cleanupFlyB = deps[9]
    local makeFacingCFrame = deps[5]
    local shouldSkipMovement = deps[11]
    local cleanupFlyA = deps[6]
    local flyDownInputRef = deps[13]

    return function(dt)
        if not config.Fly_On then
            if refGet(flyActiveRef) then
                cleanupFlyA()
                cleanupFlyB()
            end
            return
        end

        local character, humanoid, rootPart = getCharacterParts()
        if not humanoid then
            return
        end

        if shouldSkipMovement(character, rootPart) then
            return
        end

        if not refGet(flyActiveRef) then
            refSet(flyActiveRef, true)
            activateFlyState()
        end

        if config.Fly_Face then
            humanoid.PlatformStand = true
            rootPart.RotVelocity = zeroVector

            local camera = workspaceService.CurrentCamera
            if camera then
                rootPart.CFrame =
                    makeFacingCFrame(
                        rootPart.Position,
                        camera.CFrame.LookVector
                    )
            end
        end

        local direction = humanoid.MoveDirection

        local horizontalDirection =
            config.Fly_Face
                and transformMoveDirection(direction)
                or direction

        local horizontalVelocity =
            horizontalDirection * config.Fly_Value

        local verticalVelocity =
            Vector3_new(
                0,
                (refGet(flyUpInputRef) + refGet(flyDownInputRef))
                    * config.Fly_Vertical,
                0
            )

        if config.Fly_Mode == "Velocity" then
            rootPart.AssemblyLinearVelocity =
                horizontalVelocity + verticalVelocity
        else
            rootPart.AssemblyLinearVelocity = zeroVector

            rootPart.CFrame =
                rootPart.CFrame
                + ((horizontalVelocity + verticalVelocity) * dt)
        end
    end
end

function Movement.createNoClipStep(deps)
    local applyNoClip = deps[0]
    local noClipActiveRef = deps[3]
    local isNoClipBlocked = deps[6]
    local config = deps[7]
    local getCharacter = deps[8]
    local nextAllowedRef = deps[1]
    local clock = deps[4]
    local getCarriedTarget = deps[9]
    local cleanupNoClip = deps[5]
    local blockedCooldown = deps[2]

    return function()
        if not config.NoClip_On then
            if refGet(noClipActiveRef) then
                cleanupNoClip()
                refSet(noClipActiveRef, false)
            end
            return
        end

        local character = getCharacter()
        if not character then
            return
        end

        if isNoClipBlocked(character) then
            refSet(nextAllowedRef, clock() + blockedCooldown)

            if refGet(noClipActiveRef) then
                cleanupNoClip()
                refSet(noClipActiveRef, false)
            end
            return
        end

        if clock() < refGet(nextAllowedRef) then
            if refGet(noClipActiveRef) then
                cleanupNoClip()
                refSet(noClipActiveRef, false)
            end
            return
        end

        refSet(noClipActiveRef, true)
        applyNoClip(character)

        if config.NoClip_Carry then
            local carriedTarget = getCarriedTarget(character)

            if carriedTarget then
                applyNoClip(carriedTarget)
            end
        end
    end
end

function Movement.createDodgeWrapper(deps)
    local blockingAttributeNames = deps[5]
    local callHelper = deps[3]
    local resetDodgeCooldownState = deps[7]
    local config = deps[0]
    local defaultCooldownRef = deps[6]
    local nextAllowedRef = deps[2]
    local clamp = deps[9]
    local clock = deps[10]
    local attributeMutationContext = deps[1]
    local originalDodgeRef = deps[4]
    local pairsFn = deps[8]
    local characterRef = deps[11]

    return function(...)
        local originalDodge = refGet(originalDodgeRef)

        if not config.Dodge_On then
            return originalDodge(...)
        end

        local defaultCooldown =
            refGet(defaultCooldownRef) or 1.5

        local cooldown =
            clamp(
                config.Dodge_Cooldown or defaultCooldown,
                0,
                defaultCooldown
            )

        local reducedCooldown =
            cooldown < defaultCooldown - 1e-4

        if not reducedCooldown and not config.Dodge_Everywhere then
            return originalDodge(...)
        end

        local now = clock()

        if now < refGet(nextAllowedRef) then
            return
        end

        if reducedCooldown then
            resetDodgeCooldownState()
        end

        refSet(nextAllowedRef, now + cooldown)

        if config.Dodge_Everywhere then
            local character = refGet(characterRef)

            if character then
                local savedAttributes

                for i = 1, #blockingAttributeNames do
                    local attributeName = blockingAttributeNames[i]
                    local oldValue = character:GetAttribute(attributeName)

                    if oldValue ~= nil then
                        savedAttributes = savedAttributes or {}
                        savedAttributes[attributeName] = oldValue

                        callHelper(
                            attributeMutationContext,
                            character,
                            attributeName,
                            nil
                        )
                    end
                end

                local ok, result1, result2 =
                    callHelper(originalDodge, ...)

                if savedAttributes then
                    for attributeName, oldValue in pairsFn(savedAttributes) do
                        callHelper(
                            attributeMutationContext,
                            character,
                            attributeName,
                            oldValue
                        )
                    end
                end

                if ok then
                    return result1, result2
                end

                return
            end
        end

        return originalDodge(...)
    end
end

function Movement.createNoDelayTrackHook(deps)
    local typeFn = deps[3]
    local animationSpeedContext = deps[9]
    local originalTrackSpeedMap = deps[2]
    local lookupNamedRuntimeValue = deps[6]
    local config = deps[5]
    local tonumberFn = deps[0]
    local ownerSourceFunction = deps[4]
    local getNoDelayMultiplier = deps[7]
    local adjustAnimationSpeed = deps[1]
    local getAllowedAnimationIds = deps[8]

    return function(track)
        if not config.NoDelay_On then
            return
        end

        local multiplier = getNoDelayMultiplier()

        if multiplier <= 1.001 then
            return
        end

        if typeFn(ownerSourceFunction) == "function" then
            local owners =
                lookupNamedRuntimeValue(
                    ownerSourceFunction(),
                    "__V0_COMBAT_TRACK_OWNERS"
                )

            if typeFn(owners) == "table" and owners[track] then
                return
            end
        end

        local animation = track and track.Animation

        if not animation then
            return
        end

        local animationId = animation.AnimationId

        if typeFn(animationId) ~= "string" or animationId == "" then
            return
        end

        local allowedAnimationIds = getAllowedAnimationIds()

        if not allowedAnimationIds
            or not allowedAnimationIds[animationId]
        then
            return
        end

        local originalSpeed = originalTrackSpeedMap[track]

        if not originalSpeed then
            originalSpeed = tonumberFn(track.Speed) or 1

            if originalSpeed <= 0 then
                originalSpeed = 1
            end

            originalTrackSpeedMap[track] = originalSpeed
        end

        adjustAnimationSpeed(
            animationSpeedContext,
            track,
            originalSpeed * multiplier
        )
    end
end

function Movement.createNumericScaleWrapper(deps)
    local getMultiplier = deps[2]
    local typeFn = deps[0]
    local originalFunctionRef = deps[1]

    return function(self, value, ...)
        local multiplier = getMultiplier()

        if multiplier > 1.001
            and typeFn(value) == "number"
            and value > 0
        then
            value = value * multiplier
        end

        return refGet(originalFunctionRef)(
            self,
            value,
            ...
        )
    end
end

function Movement.createAntiRagdollWrapper(deps)
    local config = deps[0]
    local originalRagdollRef = deps[1]
    local allowRagdollPredicate = deps[2]

    return function(target, ...)
        if config.AntiRagdoll_On
            and target
            and not allowRagdollPredicate(target)
        then
            return
        end

        return refGet(originalRagdollRef)(
            target,
            ...
        )
    end
end

function Movement.createArgumentTransformWrapper(deps)
    local transform = deps[0]
    local originalFunctionRef = deps[1]

    return function(self, value, ...)
        local transformed = transform(self, value)

        if transformed then
            return refGet(originalFunctionRef)(
                self,
                transformed,
                ...
            )
        end

        return refGet(originalFunctionRef)(
            self,
            value,
            ...
        )
    end
end

function Movement.createFeatureDispatcher(deps)
    local config = deps[1]
    local antiRagdollTick = deps[9]
    local noDelayTick = deps[7]
    local sprintContext = deps[2]
    local applySprint = deps[3]
    local markerPredicate = deps[0]
    local infiniteStaminaTick = deps[8]
    local nsOrSprintBypassTick = deps[4]
    local getSprintObject = deps[6]
    local dodgeTick = deps[5]

    return function()
        if config.NoDelay_On then
            noDelayTick()
        end

        if config.NS_On or config.Sprint_Bypass then
            nsOrSprintBypassTick()
        end

        if config.InfStamina_On then
            infiniteStaminaTick()
        end

        if config.Dodge_On then
            dodgeTick()
        end

        if config.AntiRagdoll_On then
            antiRagdollTick()
        end

        if config.Sprint_On then
            local sprintObject = getSprintObject()

            if sprintObject
                and markerPredicate(
                    sprintObject,
                    "_sprintInputDesired"
                ) ~= true
            then
                applySprint(sprintContext, sprintObject)
            end
        end
    end
end

function Movement.createFrameDispatcher(deps)
    local typeFn = deps[2]
    local noClipStep = deps[3]
    local callHelper = deps[0]
    local flyStep = deps[4]
    local speedStep = deps[1]

    return function(dt)
        dt =
            (typeFn(dt) == "number" and dt > 0)
            and dt
            or (1 / 60)

        callHelper(flyStep, dt)
        callHelper(speedStep, dt)
        callHelper(noClipStep)
    end
end

Movement.RecoveredConfigKeys = {
    "Speed_On",
    "Speed_Value",
    "Speed_Mode",

    "Fly_On",
    "Fly_Face",
    "Fly_Value",
    "Fly_Vertical",
    "Fly_Mode",

    "NoClip_On",
    "NoClip_Carry",

    "Dodge_On",
    "Dodge_Cooldown",
    "Dodge_Everywhere",

    "NoDelay_On",
    "NS_On",
    "Sprint_Bypass",
    "InfStamina_On",
    "AntiRagdoll_On",
    "Sprint_On",
}

Movement.RecoveredLiterals = {
    "Velocity",
    "__V0_COMBAT_TRACK_OWNERS",
    "_sprintInputDesired",
    "function",
    "table",
    "string",
    "number",
}

Movement.DependencyMap = {
    Speed = {
        [0] = "config",
        [1] = "shouldSkipMovement",
        [2] = "Vector3.new",
        [3] = "getCharacterParts",
    },

    Fly = {
        [0]  = "activateFlyState",
        [1]  = "flyActiveRef",
        [2]  = "zeroVector",
        [3]  = "workspaceService",
        [4]  = "config",
        [5]  = "makeFacingCFrame",
        [6]  = "cleanupFlyA",
        [7]  = "Vector3.new",
        [8]  = "getCharacterParts",
        [9]  = "cleanupFlyB",
        [10] = "flyUpInputRef",
        [11] = "shouldSkipMovement",
        [12] = "transformMoveDirection",
        [13] = "flyDownInputRef",
    },

    NoClip = {
        [0] = "applyNoClip",
        [1] = "nextNoClipAllowedRef",
        [2] = "blockedCooldown",
        [3] = "noClipActiveRef",
        [4] = "clock",
        [5] = "cleanupNoClip",
        [6] = "isNoClipBlocked",
        [7] = "config",
        [8] = "getCharacter",
        [9] = "getCarriedTarget",
    },

    Dodge = {
        [0]  = "config",
        [1]  = "attributeMutationContext",
        [2]  = "nextDodgeAllowedRef",
        [3]  = "callHelper",
        [4]  = "originalDodgeRef",
        [5]  = "blockingAttributeNames",
        [6]  = "defaultDodgeCooldownRef",
        [7]  = "resetDodgeCooldownState",
        [8]  = "pairs",
        [9]  = "math.clamp",
        [10] = "clock",
        [11] = "characterRef",
    },

    NoDelay = {
        [0] = "tonumber",
        [1] = "adjustAnimationSpeed",
        [2] = "originalTrackSpeedMap",
        [3] = "type",
        [4] = "ownerSourceFunction",
        [5] = "config",
        [6] = "lookupNamedRuntimeValue",
        [7] = "getNoDelayMultiplier",
        [8] = "getAllowedAnimationIds",
        [9] = "animationSpeedContext",
    },

    AntiRagdoll = {
        [0] = "config",
        [1] = "originalRagdollRef",
        [2] = "allowRagdollPredicate",
    },

    NumericScale = {
        [0] = "type",
        [1] = "originalFunctionRef",
        [2] = "getMultiplier",
    },

    ArgumentTransform = {
        [0] = "transform",
        [1] = "originalFunctionRef",
    },

    FeatureDispatcher = {
        [0] = "markerPredicate",
        [1] = "config",
        [2] = "sprintContext",
        [3] = "applySprint",
        [4] = "nsOrSprintBypassTick",
        [5] = "dodgeTick",
        [6] = "getSprintObject",
        [7] = "noDelayTick",
        [8] = "infiniteStaminaTick",
        [9] = "antiRagdollTick",
    },

    FrameDispatcher = {
        [0] = "callHelper",
        [1] = "speedStep",
        [2] = "type",
        [3] = "noClipStep",
        [4] = "flyStep",
    },
}

return Movement
