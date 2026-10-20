-- RADS Movement and Stamina System
-- Integrates with the existing RADS ragdoll system

-- Create convar for enabling/disabling the movement system (disabled by default)
CreateConVar("rads_movement_enabled", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable/disable the RADS movement and stamina system")

if SERVER then
    util.AddNetworkString("RADS_StaminaUpdate")
end

-- Movement speeds
local WALK_SPEED = 200
local RUN_SPEED = 435
local CROUCH_SPEED = 60  -- Made more punishing
local SLOW_WALK_SPEED = 100
local LOW_STAMINA_RUN_SPEED = 210

-- Acceleration settings
local ACCELERATION_RATE = 4 -- How quickly to reach target speed
local DECELERATION_RATE = 3 -- How quickly to slow down
local CROUCH_ACCELERATION_MULTIPLIER = 0.7 -- Slower acceleration while crouching

-- Stamina settings
local MAX_STAMINA = 100
local STAMINA_DRAIN_RATE = 3.5
local STAMINA_REGEN_RATE = 1.8
local BREATHING_THRESHOLD = 50
local RAPID_BREATHING_THRESHOLD = 30
local LOW_STAMINA_THRESHOLD = 35
local STAMINA_RECOVERY_THRESHOLD = 50

-- Jumping settings
local BASE_JUMP_COOLDOWN = 5
local STAMINA_JUMP_COOLDOWN_MULTIPLIER = 2.0
local LANDING_PUNISHMENT_TIME = 0.5
local LANDING_SPEED_REDUCTION = 0.5
local JUMP_STAMINA_COST = 30

-- Movement penalty settings
local TURN_PENALTY_THRESHOLD = 15
local MAX_TURN_PENALTY = 0.6  -- More aggressive
local TURN_PENALTY_DECAY = 6
local CROUCH_TURN_PENALTY_MULTIPLIER = 1.6  -- Extra penalty for crouching

-- ViewPunch settings
local VIEWPUNCH_STRENGTH = 1.45
local VIEWPUNCH_FREQUENCY = 0.15 -- Increased frequency for more rapid viewpunch

-- Breathing sound intervals
local BREATHING_INTERVALS = {
    [50] = {1.9, 2.0},
    [40] = {1.5, 1.6},
    [30] = {1.0, 1.1}
}

-- Gender detection function
local function GetPlayerGender(ply)
    local model = ply:GetModel():lower()
    if string.find(model, "alyx.mdl") or 
       string.find(model, "mossman.mdl") or 
       string.find(model, "mossman_arctic.mdl") or 
       string.find(model, "p2_chell.mdl") or 
       string.find(model, "female_") then
        return "female"
    end
    return "male"
end

-- Get breathing sound based on gender
local function GetBreathingSound(ply)
    local gender = GetPlayerGender(ply)
    local soundNum = math.random(1, 6)
    local prefix = gender == "female" and "f" or "m"
    return "snds_jack_hmcd_breathing/" .. prefix .. soundNum .. ".wav"
end

-- Get breathing interval based on stamina
local function GetBreathingInterval(stamina)
    for threshold, interval in pairs(BREATHING_INTERVALS) do
        if stamina <= threshold then
            return math.Rand(interval[1], interval[2])
        end
    end
    return 2.0
end

if SERVER then
    -- Initialize player stamina when they first join
    hook.Add("PlayerInitialSpawn", "RADS_InitStaminaOnJoin", function(ply)
        ply.stamina = MAX_STAMINA
        ply.turnPenalty = 0
        ply.lowStaminaMode = false
        ply.lastJumpTime = 0
        ply.lastViewPunchTime = 0
        ply.landingPunishmentEnd = 0
        ply.lastLandTime = 0
        ply.wasOnGround = true
        ply.currentMoveSpeed = WALK_SPEED
        ply.targetMoveSpeed = WALK_SPEED
    end)
    
    -- Initialize player stamina on spawn
    hook.Add("PlayerSpawn", "RADS_InitStamina", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) then
                -- Only initialize if movement system is enabled
                if not GetConVar("rads_movement_enabled"):GetBool() then
                    -- Reset to default speeds if system is disabled
                    ply:SetWalkSpeed(200)
                    ply:SetRunSpeed(400)
                    ply:SetCrouchedWalkSpeed(64)
                    ply:SetSlowWalkSpeed(100)
                    return
                end

                ply.stamina = MAX_STAMINA
                ply.lastJumpTime = 0
                ply.lastBreathTime = 0
                ply.isRunning = false
                ply.lastDirection = ply:GetAngles().yaw
                ply.turnPenalty = 0
                ply.lowStaminaMode = false
                ply.lastViewPunchTime = 0
                ply.landingPunishmentEnd = 0
                ply.lastLandTime = 0
                ply.wasOnGround = true
                ply.currentMoveSpeed = WALK_SPEED -- Track current movement speed
                ply.targetMoveSpeed = WALK_SPEED -- Track target movement speed
                
                -- Set default movement speeds
                ply:SetWalkSpeed(WALK_SPEED)
                ply:SetRunSpeed(RUN_SPEED)
                ply:SetCrouchedWalkSpeed(CROUCH_SPEED)
                ply:SetSlowWalkSpeed(SLOW_WALK_SPEED)
                
                -- Network stamina to client
                net.Start("RADS_StaminaUpdate")
                net.WriteFloat(ply.stamina)
                net.Send(ply)
            end
        end)
    end)
    
    -- Ensure stamina is fully reset on player death
    hook.Add("PostPlayerDeath", "RADS_ResetStaminaOnDeath", function(ply)
        ply.stamina = MAX_STAMINA
        ply.lastJumpTime = 0
        ply.lastBreathTime = 0
        ply.isRunning = false
        ply.lastDirection = ply:GetAngles().yaw
        ply.turnPenalty = 0
        ply.lowStaminaMode = false
        ply.lastViewPunchTime = 0
        ply.landingPunishmentEnd = 0
        ply.lastLandTime = 0
        ply.wasOnGround = true
        ply.currentMoveSpeed = WALK_SPEED
        ply.targetMoveSpeed = WALK_SPEED
    end)
    
    -- Ensure movement variables exist for all players
    hook.Add("SetupMove", "RADS_EnsureMovementVars", function(ply, mv, cmd)
        if not IsValid(ply) then return end
        
        -- Skip if movement system is disabled
        if not GetConVar("rads_movement_enabled"):GetBool() then return end
        
        -- Initialize movement variables if they don't exist
        if ply.currentMoveSpeed == nil then
            ply.currentMoveSpeed = WALK_SPEED
        end
        if ply.targetMoveSpeed == nil then
            ply.targetMoveSpeed = WALK_SPEED
        end
    end)
    
    -- Main movement and stamina system
    hook.Add("SetupMove", "RADS_MovementSystem", function(ply, mv, cmd)
        if not IsValid(ply) or not ply:Alive() or ply:GetNWBool("radsfa") or not GetConVar("rads_movement_enabled"):GetBool() then return end
        
        local curTime = CurTime()
        local frameTime = FrameTime()
        local isSprinting = cmd:KeyDown(IN_SPEED) and mv:GetForwardSpeed() > 0
        local isCrouching = cmd:KeyDown(IN_DUCK)
        local isOnGround = ply:OnGround()
        local vel = mv:GetVelocity()
        
        -- Initialize stamina and movement variables if not set
        if not ply.stamina then
            ply.stamina = MAX_STAMINA
        end
        if not ply.turnPenalty then
            ply.turnPenalty = 0
        end
        if not ply.lastDirection then
            ply.lastDirection = cmd:GetViewAngles().yaw
        end
        if not ply.landingPunishmentEnd then
            ply.landingPunishmentEnd = 0
        end
        if ply.wasOnGround == nil then
            ply.wasOnGround = true
        end
        
        -- Jump cooldown enforcement
        if ply.lastJumpTime and curTime < ply.lastJumpTime then
            cmd:RemoveKey(IN_JUMP)
        end
        
        -- Handle jumping and stamina consumption
        if cmd:KeyDown(IN_JUMP) and isOnGround and ply.stamina >= JUMP_STAMINA_COST then
            -- Consume stamina when jumping
            ply.stamina = math.max(0, ply.stamina - JUMP_STAMINA_COST)
            
            -- Network updated stamina to client
            net.Start("RADS_StaminaUpdate")
            net.WriteFloat(ply.stamina)
            net.Send(ply)
        elseif cmd:KeyDown(IN_JUMP) and isOnGround and ply.stamina < JUMP_STAMINA_COST then
            -- Prevent jumping if not enough stamina
            cmd:RemoveKey(IN_JUMP)
        end
        
        -- Handle landing punishment
        if isOnGround and not ply.wasOnGround then
            ply.lastLandTime = curTime
            ply.landingPunishmentEnd = curTime + LANDING_PUNISHMENT_TIME
            
            -- Set jump cooldown
            local cooldownMultiplier = 1
            if ply.stamina and ply.stamina <= LOW_STAMINA_THRESHOLD then
                cooldownMultiplier = STAMINA_JUMP_COOLDOWN_MULTIPLIER
            end
            ply.lastJumpTime = curTime + (BASE_JUMP_COOLDOWN * cooldownMultiplier)
        end
        ply.wasOnGround = isOnGround
        
        -- Apply landing punishment
        local landingPenalty = 1
        if ply.landingPunishmentEnd and curTime < ply.landingPunishmentEnd then
            landingPenalty = LANDING_SPEED_REDUCTION
        end
        
        -- Handle air movement with smooth deceleration
        if not isOnGround then
            local currentSpeed = vel:Length2D()
            if currentSpeed > 0 then
                local maxAirSpeed = RUN_SPEED * 0.9
                local targetSpeed = math.min(currentSpeed, maxAirSpeed)
                
                -- Apply smooth deceleration if over speed limit
                if currentSpeed > maxAirSpeed then
                    local lerpFactor = math.Clamp(frameTime * 2, 0, 1) -- Adjust the 2 to control deceleration speed
                    targetSpeed = Lerp(lerpFactor, currentSpeed, maxAirSpeed)
                end
                
                -- Apply the new velocity while preserving direction and vertical speed
                if targetSpeed ~= currentSpeed then
                    local newVel = vel:GetNormalized()
                    newVel.x = newVel.x * targetSpeed
                    newVel.y = newVel.y * targetSpeed
                    newVel.z = vel.z -- Preserve vertical velocity
                    mv:SetVelocity(newVel)
                end
            end
        end
        
        -- Movement penalties and turn detection
        if isOnGround and (isSprinting or isCrouching) then
            local currentDirection = cmd:GetViewAngles().yaw
            local directionDiff = math.abs(math.AngleDifference(currentDirection, ply.lastDirection or currentDirection))
            
            -- Calculate turn penalty
            if directionDiff > TURN_PENALTY_THRESHOLD then
                local penaltyAmount = math.min(MAX_TURN_PENALTY, directionDiff / 45)
                
                -- Extra penalty for crouching
                if isCrouching then
                    penaltyAmount = penaltyAmount * CROUCH_TURN_PENALTY_MULTIPLIER
                end
                
                ply.turnPenalty = math.max(ply.turnPenalty, penaltyAmount)
                
                -- Apply immediate velocity reduction for sharp turns
                local speedReduction = 1 - penaltyAmount
                vel.x = vel.x * speedReduction
                vel.y = vel.y * speedReduction
                mv:SetVelocity(vel)
            else
                ply.turnPenalty = math.max(0, ply.turnPenalty - TURN_PENALTY_DECAY * frameTime)
            end
            
            ply.lastDirection = currentDirection
        end
        

        
        -- Calculate target speeds with all modifiers
        local targetRunSpeed = RUN_SPEED
        local targetCrouchSpeed = CROUCH_SPEED
        
        -- Apply shock movement penalties
        local shock = ply:GetNWFloat("RADS_Shock", 0)
        local movementThresholdConVar = GetConVar("rads_shock_movement_threshold")
        local movementThreshold = movementThresholdConVar and movementThresholdConVar:GetFloat() or 50
        if shock >= movementThreshold then
            local shockPenalty = ((shock - movementThreshold) / 100) * 0.6 -- Up to 60% speed reduction
            targetRunSpeed = targetRunSpeed * (1 - shockPenalty)
            targetCrouchSpeed = targetCrouchSpeed * (1 - shockPenalty)
        end
        
        -- Apply turn penalty
        if ply.turnPenalty and ply.turnPenalty > 0 then
            targetRunSpeed = targetRunSpeed * (1 - ply.turnPenalty)
            targetCrouchSpeed = targetCrouchSpeed * (1 - ply.turnPenalty * 0.8)
        end
        
        -- Apply landing punishment
        targetRunSpeed = targetRunSpeed * landingPenalty
        targetCrouchSpeed = targetCrouchSpeed * landingPenalty
        
        -- Apply low stamina speed cap
        if ply.stamina and ply.stamina <= LOW_STAMINA_THRESHOLD then
            targetRunSpeed = math.min(targetRunSpeed, LOW_STAMINA_RUN_SPEED)
            ply.lowStaminaMode = true
        elseif ply.stamina and ply.stamina >= STAMINA_RECOVERY_THRESHOLD then
            ply.lowStaminaMode = false
        end
        
        if ply.lowStaminaMode then
            targetRunSpeed = math.min(targetRunSpeed, LOW_STAMINA_RUN_SPEED)
        end

        -- Determine target speed based on movement state
        local targetSpeed = isSprinting and targetRunSpeed or (isCrouching and targetCrouchSpeed or WALK_SPEED)
        ply.targetMoveSpeed = targetSpeed

        -- Calculate acceleration rate
        local accelerationRate = ACCELERATION_RATE
        if isCrouching then
            accelerationRate = accelerationRate * CROUCH_ACCELERATION_MULTIPLIER
        end

        -- Smoothly interpolate to target speed
        local rate = ply.targetMoveSpeed > ply.currentMoveSpeed and accelerationRate or DECELERATION_RATE
        ply.currentMoveSpeed = Lerp(frameTime * rate, ply.currentMoveSpeed, ply.targetMoveSpeed)

        -- Apply smoothed speeds
        ply:SetRunSpeed(targetRunSpeed)
        ply:SetCrouchedWalkSpeed(targetCrouchSpeed)

        -- Allow full air control without restrictions when not on ground
        if ply:IsOnGround() then
            -- Apply smooth velocity changes only when on ground
            local currentVel = vel:Length2D()
            if currentVel > 0 then
                local maxAllowedSpeed = isSprinting and targetRunSpeed or (isCrouching and targetCrouchSpeed or WALK_SPEED)
                local targetSpeed = math.min(ply.currentMoveSpeed, maxAllowedSpeed)
                
                -- Only apply smoothing when actively moving
                if ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT) then
                    local newSpeed = Lerp(frameTime * ACCELERATION_RATE, currentVel, targetSpeed)
                    local newVel = vel:GetNormalized() * newSpeed
                    newVel.z = vel.z -- Preserve vertical velocity
                    mv:SetVelocity(newVel)
                end
            end
            
            -- Gentle velocity clamping only when on ground and exceeding speed
            local maxSpeed = isSprinting and targetRunSpeed or (isCrouching and targetCrouchSpeed or WALK_SPEED)
            local currentSpeed = vel:Length2D()
            
            if currentSpeed > maxSpeed * 1.5 then
                local newVel = vel:GetNormalized() * maxSpeed
                newVel.z = vel.z
                mv:SetVelocity(newVel)
            end
        end
    end)
    
    -- Stamina system think hook
    hook.Add("Think", "RADS_StaminaSystem", function()
        for _, ply in ipairs(player.GetAll()) do
            local movementEnabledConVar = GetConVar("rads_movement_enabled")
            if IsValid(ply) and ply:Alive() and not ply:GetNWBool("radsfa") and (movementEnabledConVar and movementEnabledConVar:GetBool() or true) then
                -- Initialize movement variables for all players
                if ply.currentMoveSpeed == nil then
                    ply.currentMoveSpeed = WALK_SPEED
                end
                if ply.targetMoveSpeed == nil then
                    ply.targetMoveSpeed = WALK_SPEED
                end
                
                local curTime = CurTime()
                local isRunning = ply:KeyDown(IN_SPEED) and ply:GetVelocity():Length() > 200
                
                -- Initialize stamina if not set
                if not ply.stamina then
                    ply.stamina = MAX_STAMINA
                end
                
                -- Check for lung damage (integration with new lung system)
                local leftLungHealth = (ply.Organs and ply.Organs['left_lung']) or 5
                local rightLungHealth = (ply.Organs and ply.Organs['right_lung']) or 5
                local damagedLungs = 0
                if leftLungHealth <= 0 then damagedLungs = damagedLungs + 1 end
                if rightLungHealth <= 0 then damagedLungs = damagedLungs + 1 end
                
                -- Check for lung damage that affects stamina
                local lungDamageAffectsStamina = false
                if ply.Organs then
                    local leftLungHealth = ply.Organs['left_lung'] or 5
                    local rightLungHealth = ply.Organs['right_lung'] or 5
                    
                    -- If either lung is at 0 health, force stamina to 0 and prevent regen
                    if leftLungHealth <= 0 or rightLungHealth <= 0 then
                        lungDamageAffectsStamina = true
                    end
                end
                
                -- Check for shock effects
                local shock = ply:GetNWFloat("RADS_Shock", 0)
                local movementThresholdConVar = GetConVar("rads_shock_movement_threshold")
                local movementThreshold = movementThresholdConVar and movementThresholdConVar:GetFloat() or 50
                local shockAffectsMovement = shock >= movementThreshold
                
                -- Stamina drain/regen with lung damage and shock integration
                if lungDamageAffectsStamina then
                    -- Force stamina to 0 and keep it there when lung is damaged
                    ply.stamina = 0
                    ply.isRunning = false
                elseif isRunning then
                    local staminaDrain = STAMINA_DRAIN_RATE
                    
                    -- Increase stamina drain based on shock level
                    if shockAffectsMovement then
                        local shockMultiplier = 1 + ((shock - movementThreshold) / 100) * 3 -- Up to 3x drain at max shock
                        staminaDrain = staminaDrain * shockMultiplier
                    end
                    
                    ply.stamina = math.max(0, ply.stamina - staminaDrain * FrameTime())
                    ply.isRunning = true
                else
                    -- Only regenerate stamina if no lung damage or if lungStaminaDrain flag is not set
                    if not ply.lungStaminaDrain and damagedLungs == 0 then
                        local staminaRegen = STAMINA_REGEN_RATE
                        
                        -- Reduce stamina regeneration based on shock level
                        if shockAffectsMovement then
                            local shockPenalty = ((shock - movementThreshold) / 100) * 0.8 -- Up to 80% reduction
                            staminaRegen = staminaRegen * (1 - shockPenalty)
                        end
                        
                        ply.stamina = math.min(MAX_STAMINA, ply.stamina + staminaRegen * FrameTime())
                    end
                    ply.isRunning = false
                    
                    -- Reset penalties when not running
                    if ply.turnPenalty then
                        ply.turnPenalty = math.max(0, ply.turnPenalty - 2 * FrameTime())
                    end
                end
                
                -- Force stamina to 0 if lung damage is active (handled by lung system)
                if ply.lungStaminaDrain or damagedLungs >= 1 then
                    ply.stamina = 0
                end
                
                -- Breathing sounds (works for both normal and ragdolled players)
                if ply.stamina <= BREATHING_THRESHOLD then
                    local breathInterval = GetBreathingInterval(ply.stamina)
                    
                    if curTime - (ply.lastBreathTime or 0) >= breathInterval then
                        local soundFile = GetBreathingSound(ply)
                        local isRagdolled = ply:GetNWBool("radsfa")
                        
                        -- Emit sound directly from player or ragdoll entity
                        if isRagdolled then
                            local ragdoll = ply:GetNWEntity("player_ragdoll")
                            if IsValid(ragdoll) then
                                -- Emit sound from ragdoll with short range
                                ragdoll:EmitSound(soundFile, 45, 100, 0.7, CHAN_VOICE)
                            end
                        else
                            -- Emit sound from player with short range
                            ply:EmitSound(soundFile, 45, 100, 0.7, CHAN_VOICE)
                        end
                        
                        ply.lastBreathTime = curTime
                    end
                end
                
                -- Update heartrate based on stamina consumption
                if ply.stamina < 40 and ply.isRunning then
                    if ply.heartRate then
                        ply.heartRate = math.min(180, ply.heartRate + 2)
                    end
                end
                
                -- Network stamina to client
                net.Start("RADS_StaminaUpdate")
                net.WriteFloat(ply.stamina)
                net.Send(ply)
            end
        end
    end)
    
    -- Preserve stamina during ragdoll transitions
    hook.Add("RADS_Ready", "RADS_PreserveStamina", function(rag)
        local owner = rag:GetNWEntity("owner")
        if IsValid(owner) and owner:IsPlayer() then
            owner.preservedStamina = owner.stamina or MAX_STAMINA
            -- Reset breathing timer to prevent double sounds when ragdolled
            owner.lastBreathTime = CurTime()
        end
    end)
    
    -- Restore stamina when getting up from ragdoll
    hook.Add("PlayerSpawn", "RADS_RestoreStamina", function(ply)
        timer.Simple(0.2, function()
            if IsValid(ply) and ply.preservedStamina then
                ply.stamina = ply.preservedStamina
                ply.preservedStamina = nil
                -- Reset breathing timer to prevent double sounds when getting up
                ply.lastBreathTime = CurTime()
                
                net.Start("RADS_StaminaUpdate")
                net.WriteFloat(ply.stamina)
                net.Send(ply)
            end
        end)
    end)
end

if CLIENT then
    local playerStamina = MAX_STAMINA
    
    -- Receive stamina updates
    net.Receive("RADS_StaminaUpdate", function()
        playerStamina = net.ReadFloat()
    end)
    
    -- ViewPunch for sprinting footsteps using the new mod's function
    hook.Add("PlayerFootstep", "RADS_SprintViewPunch", function(ply, pos, foot, sound, volume, rf)
        local movementEnabledConVar = GetConVar("rads_movement_enabled")
        if ply == LocalPlayer() and ply:KeyDown(IN_SPEED) and ply:GetVelocity():Length() > 200 and (movementEnabledConVar and movementEnabledConVar:GetBool() or true) then
            local curTime = CurTime()
            
            if not ply.lastViewPunchTime then
                ply.lastViewPunchTime = 0
            end
            
            -- Trigger viewpunch on footstep (or similar rapid event)
            -- Assuming PlayerFootstep hook is still used or a similar mechanism
            -- For now, I'll just make it more frequent and ensure it goes down.
            if curTime - ply.lastViewPunchTime > VIEWPUNCH_FREQUENCY then
                ply.lastViewPunchTime = curTime
                
                -- Ensure viewpunch goes downwards (negative pitch)
                local pitch = math.Rand(-VIEWPUNCH_STRENGTH * 1.5, -VIEWPUNCH_STRENGTH * 0.8) -- More negative for downward punch
                local yaw = math.Rand(-VIEWPUNCH_STRENGTH * 0.3, VIEWPUNCH_STRENGTH * 0.3)
                local roll = math.Rand(-VIEWPUNCH_STRENGTH * 0.2, VIEWPUNCH_STRENGTH * 0.2)
                
                -- If using the new mod's functions, call them directly
                -- Assuming these functions are globally available client-side
                if CLIENT then
                    if Viewpunch then
                        Viewpunch(Angle(pitch, yaw, roll))
                    elseif SetViewPunchAngles then
                        SetViewPunchAngles(Angle(pitch, yaw, roll))
                    elseif SetViewPunchVelocity then
                        SetViewPunchVelocity(Angle(pitch, yaw, roll))
                    else
                        -- Fallback to old net message if new functions aren't found
                        net.Start("RADS_ViewPunch")
                        net.WriteFloat(pitch)
                        net.WriteFloat(yaw)
                        net.WriteFloat(roll)
                        net.Send(ply)
                    end
                end
            end
        end
    end)
    
    -- Mouse sensitivity adjustment during sprinting
    hook.Add("AdjustMouseSensitivity", "RADS_MouseStiffening", function(def)
        local ply = LocalPlayer()
        if IsValid(ply) and ply:KeyDown(IN_SPEED) and ply:KeyDown(IN_FORWARD) then
            return 0.5
        end
        return 1
    end)
end

-- Console commands for testing (admin only)
if SERVER then
    concommand.Add("rads_stamina_set", function(ply, cmd, args)
        if not ply:IsSuperAdmin() then return end
        
        local amount = tonumber(args[1]) or MAX_STAMINA
        amount = math.Clamp(amount, 0, MAX_STAMINA)
        
        ply.stamina = amount
        ply:ChatPrint("Stamina set to: " .. amount)
        
        net.Start("RADS_StaminaUpdate")
        net.WriteFloat(ply.stamina)
        net.Send(ply)
    end)
    
    concommand.Add("rads_stamina_info", function(ply, cmd, args)
        if not ply:IsSuperAdmin() then return end
        
        ply:ChatPrint("Current stamina: " .. (ply.stamina or "Not initialized"))
        ply:ChatPrint("Low stamina mode: " .. tostring(ply.lowStaminaMode or false))
        ply:ChatPrint("Turn penalty: " .. (ply.turnPenalty or 0))
        ply:ChatPrint("Landing punishment: " .. math.max(0, (ply.landingPunishmentEnd or 0) - CurTime()))
        ply:ChatPrint("Jump cooldown: " .. math.max(0, (ply.lastJumpTime or 0) - CurTime()))
    end)
end