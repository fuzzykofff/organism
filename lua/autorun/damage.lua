if SERVER then
    util.AddNetworkString('info_org')
    -- Add adrenaline network strings
    util.AddNetworkString('RADS_AdrenalineUpdate')
    util.AddNetworkString('RADS_AdrenalineEffects')
    -- Add organ burn network string
    util.AddNetworkString('RADS_OrganBurn')
    -- NEW: Add oxygen system network strings
    util.AddNetworkString('RADS_LungOxygenUpdate')
    -- Add Last Stand network strings
    util.AddNetworkString('RADS_StartLastStand')
    util.AddNetworkString('RADS_StopLastStand')
    -- Add Concussion network string
    util.AddNetworkString('RADS_TriggerConcussion')
    -- Add Last Stand interruption sound network string
    util.AddNetworkString('RADS_PlayInterruptionSound')
    -- Add neck breaking network string
    util.AddNetworkString('RADS_NeckBreak')
    -- Add consciousness network string
    util.AddNetworkString('RADS_UpdateConsciousness')
    -- Add consciousness timer network string
    util.AddNetworkString('RADS_ConsciousnessTimer')
    -- Add death state network strings
    util.AddNetworkString('RADS_StartDeathState')
    util.AddNetworkString('RADS_EndDeathState')
    util.AddNetworkString('RADS_DeathStateTimer')
    util.AddNetworkString('RADS_PlayDeathSound')
    -- Add fear system network strings
    util.AddNetworkString('RADS_FearUpdate')
    util.AddNetworkString('RADS_FearEffects')
    
    -- Last Stand System Server Functions
    function TriggerLastStand(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end

-- ========================================
-- SPINE STRESS MONITORING SYSTEM
-- ========================================

if SERVER then
    -- Spine stress monitoring variables
    local spineStressData = {}
    
    -- Spine bone names for monitoring (pelvis to top of spine)
    local spineBones = {
        "ValveBiped.Bip01_Pelvis",
        "ValveBiped.Bip01_Spine",
        "ValveBiped.Bip01_Spine1", 
        "ValveBiped.Bip01_Spine2",
        "ValveBiped.Bip01_Spine4"
    }
    
    -- Stress thresholds and damage rates (lowered for better detection)
    local SPINE_STRESS_CONFIG = {
        safeStretchThreshold = 1.15,    -- 15% stretch is safe
        damageStretchThreshold = 1.25,  -- 25% stretch starts damage
        severeStretchThreshold = 1.5,   -- 50% stretch is severe
        criticalStretchThreshold = 1.8, -- 80% stretch is critical
        
        baseDamageRate = 0.8,           -- Base damage per second
        severeDamageRate = 2.0,         -- Severe damage per second
        criticalDamageRate = 4.0,       -- Critical damage per second
        
        velocityDamageMultiplier = 0.002, -- Additional damage from velocity
        maxVelocityDamage = 3.0,        -- Max additional damage from velocity
        
        painPerDamage = 8,              -- Pain added per damage point
        adrenalinePerDamage = 5,        -- Adrenaline added per damage point
        
        soundCooldown = 1.5             -- Cooldown between spine damage sounds
    }
    
    -- Initialize spine stress data for a player
    local function InitializeSpineStress(ply)
        if not IsValid(ply) then return end
        
        local ragdoll = ply:GetNWEntity("player_ragdoll")
        if not IsValid(ragdoll) then return end
        
        local data = {
            baselineDistances = {},
            lastSoundTime = 0,
            accumulatedStress = 0
        }
        
        -- Calculate baseline distances between spine bones
        local bonePositions = {}
        for i, boneName in ipairs(spineBones) do
            local boneIndex = ragdoll:LookupBone(boneName)
            if boneIndex then
                bonePositions[i] = ragdoll:GetBonePosition(boneIndex)
            end
        end
        
        -- Store baseline distances between consecutive spine bones
        for i = 1, #bonePositions - 1 do
            if bonePositions[i] and bonePositions[i + 1] then
                local distance = bonePositions[i]:Distance(bonePositions[i + 1])
                data.baselineDistances[i] = distance
            end
        end
        
        spineStressData[ply:EntIndex()] = data
    end
    
    -- Calculate spine stress and apply damage
    local function CalculateSpineStress(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
        if not ply:GetNWBool("radsfa") then return end -- Only check when ragdolled
        
        local ragdoll = ply:GetNWEntity("player_ragdoll")
        if not IsValid(ragdoll) then return end
        
        local entIndex = ply:EntIndex()
        local data = spineStressData[entIndex]
        
        if not data or not data.baselineDistances then
            InitializeSpineStress(ply)
            return
        end
        
        local currentTime = CurTime()
        local frameTime = FrameTime()
        local maxStress = 0
        local totalVelocity = 0
        
        -- Get current bone positions and velocities
        local bonePositions = {}
        local boneVelocities = {}
        
        for i, boneName in ipairs(spineBones) do
            local boneIndex = ragdoll:LookupBone(boneName)
            if boneIndex then
                bonePositions[i] = ragdoll:GetBonePosition(boneIndex)
                
                -- Get physics object for velocity
                local physBone = ragdoll:GetPhysicsObjectNum(ragdoll:TranslateBoneToPhysBone(boneIndex))
                if IsValid(physBone) then
                    boneVelocities[i] = physBone:GetVelocity():Length()
                    totalVelocity = totalVelocity + boneVelocities[i]
                end
            end
        end
        
        -- Calculate current distances and stress levels with connection-specific tracking
        local pelvisToSpineStress = 0  -- Connection 1: Pelvis to Spine (affects lower_spine)
        local spineStress = 0          -- Connections 2-4: Spine segments (affects upper_spine)
        
        for i = 1, #bonePositions - 1 do
            if bonePositions[i] and bonePositions[i + 1] and data.baselineDistances[i] then
                local currentDistance = bonePositions[i]:Distance(bonePositions[i + 1])
                local baselineDistance = data.baselineDistances[i]
                
                if baselineDistance > 0 then
                    local stretchRatio = currentDistance / baselineDistance
                    maxStress = math.max(maxStress, stretchRatio)
                    
                    -- Track specific connection stress
                    if i == 1 then
                        -- Pelvis to Spine connection (most critical for lower spine)
                        pelvisToSpineStress = stretchRatio
                    else
                        -- Spine segment connections (upper spine)
                        spineStress = math.max(spineStress, stretchRatio)
                    end
                end
            end
        end
        
        -- Only apply damage if stress exceeds safe threshold
        if maxStress > SPINE_STRESS_CONFIG.safeStretchThreshold then
            local damageAmount = 0
            local stressLevel = "normal"
            
            -- Determine damage based on stress level
            if maxStress >= SPINE_STRESS_CONFIG.criticalStretchThreshold then
                damageAmount = SPINE_STRESS_CONFIG.criticalDamageRate * frameTime
                stressLevel = "critical"
            elseif maxStress >= SPINE_STRESS_CONFIG.severeStretchThreshold then
                damageAmount = SPINE_STRESS_CONFIG.severeDamageRate * frameTime
                stressLevel = "severe"
            elseif maxStress >= SPINE_STRESS_CONFIG.damageStretchThreshold then
                damageAmount = SPINE_STRESS_CONFIG.baseDamageRate * frameTime
                stressLevel = "moderate"
            end
            
            -- Add velocity-based damage
            local velocityDamage = math.min(
                (totalVelocity * SPINE_STRESS_CONFIG.velocityDamageMultiplier) * frameTime,
                SPINE_STRESS_CONFIG.maxVelocityDamage * frameTime
            )
            damageAmount = damageAmount + velocityDamage
            
            -- Apply damage to spine organs based on connection type
            if damageAmount > 0 then
                -- Calculate damage distribution based on stress location
                local lowerSpineDamage = 0
                local upperSpineDamage = 0
                
                -- Pelvis-to-spine stress primarily damages lower spine
                if pelvisToSpineStress > SPINE_STRESS_CONFIG.safeStretchThreshold then
                    lowerSpineDamage = damageAmount * 0.8
                    upperSpineDamage = damageAmount * 0.2
                else
                    -- Spine segment stress primarily damages upper spine
                    lowerSpineDamage = damageAmount * 0.3
                    upperSpineDamage = damageAmount * 0.7
                end
                
                -- Apply lower spine damage
                if ply.Organs and ply.Organs['lower_spine'] and lowerSpineDamage > 0 then
                    ply.Organs['lower_spine'] = math.max(0, ply.Organs['lower_spine'] - lowerSpineDamage)
                    
                    -- Check if lower spine is destroyed
                    if ply.Organs['lower_spine'] <= 0 and not ply.brokenspine then
                        ply.brokenspine = true
                        ply:EmitSound("physics/body/body_medium_break" .. math.random(2, 4) .. ".wav", 75, 100)
                        RADS_AddThought(ply, "Your lower spine snaps at the waist!", 1.0, true)
                    end
                end
                
                -- Apply upper spine damage
                if ply.Organs and ply.Organs['upper_spine'] and upperSpineDamage > 0 then
                    ply.Organs['upper_spine'] = math.max(0, ply.Organs['upper_spine'] - upperSpineDamage)
                    
                    -- Check if upper spine is destroyed
                    if ply.Organs['upper_spine'] <= 0 and not ply.brokenupperspine then
                        ply.brokenupperspine = true
                        ply:EmitSound("physics/body/body_medium_break" .. math.random(2, 4) .. ".wav", 75, 100)
                        RADS_AddThought(ply, "Your upper spine is severely damaged!", 1.0, true)
                    end
                end
                
                -- Add pain and adrenaline
                if ply.pain then
                    ply.pain = ply.pain + (damageAmount * SPINE_STRESS_CONFIG.painPerDamage)
                end
                
                if ply.adrenaline then
                    ply.adrenaline = math.min(100, ply.adrenaline + (damageAmount * SPINE_STRESS_CONFIG.adrenalinePerDamage))
                end
                
                -- Play spine stress sound with cooldown
                if currentTime - data.lastSoundTime > SPINE_STRESS_CONFIG.soundCooldown then
                    local soundPitch = math.Clamp(120 - (maxStress - 1) * 30, 80, 120)
                    
                    if stressLevel == "critical" then
                        ragdoll:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 70, soundPitch)
                    elseif stressLevel == "severe" then
                        ragdoll:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 65, soundPitch)
                    else
                        ragdoll:EmitSound("physics/flesh/flesh_strider_impact_bullet" .. math.random(1, 3) .. ".wav", 60, soundPitch)
                    end
                    
                    data.lastSoundTime = currentTime
                end
                
                -- Accumulate stress for potential thoughts
                data.accumulatedStress = data.accumulatedStress + damageAmount
                
                -- Add stress-based thoughts
                if data.accumulatedStress > 2 then
                    if stressLevel == "critical" then
                        RADS_AddThought(ply, "Your spine is being torn apart!", 0.8, true)
                    elseif stressLevel == "severe" then
                        RADS_AddThought(ply, "Intense pain shoots through your spine!", 0.6, false)
                    else
                        RADS_AddThought(ply, "Your spine aches from the stress.", 0.4, false)
                    end
                    data.accumulatedStress = 0
                end
            end
        end
    end
    
    -- Main spine stress monitoring hook
    hook.Add("Think", "RADS_SpineStressMonitor", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:GetNWBool("radsfa") then
                CalculateSpineStress(ply)
            end
        end
    end)
    
    -- Initialize spine stress when player becomes ragdoll
    hook.Add("Think", "RADS_InitializeSpineStress", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:GetNWBool("radsfa") then
                local entIndex = ply:EntIndex()
                if not spineStressData[entIndex] then
                    InitializeSpineStress(ply)
                end
            end
        end
    end)
    
    -- Clean up spine stress data when player stops being ragdoll or disconnects
    hook.Add("Think", "RADS_CleanupSpineStress", function()
        for entIndex, data in pairs(spineStressData) do
            local ply = Entity(entIndex)
            if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not ply:GetNWBool("radsfa") then
                spineStressData[entIndex] = nil
            end
        end
    end)
    
    -- Reset spine stress on spawn
    hook.Add("PlayerSpawn", "RADS_ResetSpineStress", function(ply)
        if IsValid(ply) then
            spineStressData[ply:EntIndex()] = nil
        end
    end)
    
    -- Test command for spine stress
    concommand.Add("rads_test_spine_stress", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        if not ply:GetNWBool("radsfa") then
            ply:ChatPrint("You must be ragdolled to test spine stress.")
            return
        end
        
        local entIndex = ply:EntIndex()
        local data = spineStressData[entIndex]
        
        if data then
            ply:ChatPrint("Spine stress data initialized. Baseline distances: " .. table.Count(data.baselineDistances))
            ply:ChatPrint("Accumulated stress: " .. (data.accumulatedStress or 0))
        else
            ply:ChatPrint("No spine stress data found. Initializing...")
            InitializeSpineStress(ply)
        end
    end)
end
        
        -- Check if player is already in last stand or dead
        if ply.lastStandActive or not ply:Alive() then return end
        
        -- Set last stand state
        ply.lastStandActive = true
        ply.lastStandEndTime = CurTime() + 60 -- 60 seconds duration (1 minute)
        
        -- Send network message to client (this will start music and effects)
        net.Start('RADS_StartLastStand')
        net.Send(ply)
        
        -- Keep player unconscious for the first 15 seconds
        ply.Otrub = true
        ply:SetNWBool("Otrub", true)
        ply.lastStandUnconscious = true
        
        -- Store original values for later restoration
        if ply.Blood then
            ply.lastStandOriginalBlood = ply.Blood
        end
        if ply.consciousness then
            ply.lastStandOriginalConsciousness = ply.consciousness
        end
        
        -- Apply restriction bypasses after 15 seconds
        timer.Create("RADS_LastStandBypass_" .. ply:EntIndex(), 15, 1, function()
            if IsValid(ply) and ply.lastStandActive then
                -- BYPASS ALL RESTRICTIONS: Force player awake
                ply.Otrub = false
                ply:SetNWBool("Otrub", false)
                ply.lastStandUnconscious = false
                
                -- Apply surge effects - BYPASSES ALL RESTRICTIONS
                ply:SetHealth(math.max(ply:Health(), 50)) -- Higher minimum HP
                ply:SetRunSpeed(500) -- Even faster speed
                ply:SetWalkSpeed(300) -- Faster walk speed
                
                -- Drastically reduce pain
                if ply.pain then
                    ply.pain = math.max(0, ply.pain - 500) -- Massive pain reduction
                end
                
                -- BYPASS: Temporarily boost blood and consciousness to prevent interference
                if ply.Blood then
                    ply.Blood = math.max(ply.Blood, 4000) -- Boost blood temporarily
                end
                
                if ply.consciousness then
                    ply.consciousness = 100 -- Full consciousness during last stand
                end
            end
        end)
        
        -- Auto-end last stand after 1 minute (guaranteed death)
        timer.Create("RADS_LastStandEnd_" .. ply:EntIndex(), 60, 1, function()
            if IsValid(ply) then
                EndLastStand(ply)
            end
        end)
        
    end
    
    -- REMOVED: InterruptLastStand function - no longer needed since last stand bypasses all restrictions
    
    function EndLastStand(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        -- Reset last stand state
        ply.lastStandActive = false
        ply.lastStandUnconscious = false
        
        -- Send network message to client
        net.Start('RADS_StopLastStand')
        net.Send(ply)
        
        -- Reset player stats
        ply:SetRunSpeed(250) -- Normal speed
        ply:SetWalkSpeed(160) -- Normal walk speed
        
        -- Restore original blood and consciousness values if they were stored
        if ply.lastStandOriginalBlood then
            ply.Blood = ply.lastStandOriginalBlood
            ply.lastStandOriginalBlood = nil
        end
        
        if ply.lastStandOriginalConsciousness then
            ply.consciousness = ply.lastStandOriginalConsciousness
            ply.lastStandOriginalConsciousness = nil
        end
        
        -- Remove timers
        timer.Remove("RADS_LastStandEnd_" .. ply:EntIndex())
        timer.Remove("RADS_LastStandBypass_" .. ply:EntIndex())
        timer.Remove("RADS_LastStandWakeup_" .. ply:EntIndex())
        timer.Remove("RADS_LastStandRetryWakeup_" .. ply:EntIndex())
        timer.Remove("RADS_LastStandMonitor_" .. ply:EntIndex())
        
        -- GUARANTEED DEATH: No matter what, player dies after 1 minute
        -- Set brain health to 0, causing death
        if ply.Organs and ply.Organs['brain'] then
            ply.Organs['brain'] = 0
        end
        
        -- Force player death immediately - no delays, no exceptions
        timer.Simple(0.1, function()
            if IsValid(ply) then
                -- Create respawn timer to prevent immediate respawn
                timer.Create("respawntimer" .. ply:EntIndex(), 99999, 1, function() end)
                TriggerDeathState(ply)
            end
        end)
    end
    
    -- Optimized last stand trigger conditions with performance scaling
    local lastStandCheckTime = 0
    local lastStandCheckInterval = 1.0 -- Base 1 second interval
    
    hook.Add("Think", "RADS_LastStandCheck", function()
        local cheapEffects = GetConVar("rads_cheapeffects") and GetConVar("rads_cheapeffects"):GetInt() or 0
        
        -- Adjust check frequency based on performance settings
        if cheapEffects >= 2 then
            lastStandCheckInterval = 5.0 -- 5 second interval for max performance
        elseif cheapEffects >= 1 then
            lastStandCheckInterval = 2.0 -- 2 second interval for moderate performance
        else
            lastStandCheckInterval = 1.0 -- 1 second interval for full quality
        end
        
        if CurTime() - lastStandCheckTime < lastStandCheckInterval then return end
        lastStandCheckTime = CurTime()
        
        -- Skip Last Stand checks entirely if cheapeffects >= 2
        if cheapEffects >= 2 then return end
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
                -- Only trigger when player is unconscious (otrub=true)
                if not ply.Otrub then continue end
                
                -- Don't trigger if already in last stand or recently triggered
                if ply.lastStandActive or (ply.lastStandCooldown and ply.lastStandCooldown > CurTime()) then
                    continue
                end
                
                -- Don't trigger during brain hemorrhage
                if ply.BrainDamageFXActive then
                    continue
                end
                
                -- Check trigger conditions
                local shouldTrigger = false
                
                -- Low health trigger
                if ply:Health() <= 15 and ply:Health() > 0 then
                    shouldTrigger = true
                end
                
                -- Critical blood loss trigger
                if ply.Blood and ply.Blood <= 1500 then
                    shouldTrigger = true
                end
                
                -- Extreme pain trigger
                if ply.pain and ply.pain >= 800 then
                    shouldTrigger = true
                end
                
                -- Simplified organ damage check for performance
                if ply.Organs and cheapEffects < 1 then
                    if (ply.Organs['heart'] and ply.Organs['heart'] <= 2) or
                       (ply.Organs['brain'] and ply.Organs['brain'] <= 2) or
                       (ply.Organs['left_lung'] and ply.Organs['right_lung'] and 
                        ply.Organs['left_lung'] <= 1 and ply.Organs['right_lung'] <= 1) then
                        shouldTrigger = true
                    end
                end
                
                -- Reduce trigger chance for performance modes
                local triggerChance = cheapEffects >= 1 and 0.00005 or 0.0001
                if shouldTrigger and math.random() < triggerChance then
                    TriggerLastStand(ply)
                    ply.lastStandCooldown = CurTime() + 300 -- 5 minute cooldown
                end
            end
        end
    end)
    
    -- Test command for last stand
    concommand.Add("rads_testlaststand", function(ply, cmd, args)
        if IsValid(ply) and ply:IsPlayer() then
            -- Set player comatose first and add bypass flag
            ply.Otrub = true
            ply:SetNWBool("Otrub", true)
            ply.testLastStandBypass = true -- Bypass IsUnconscious override
            
            -- Trigger last stand after 3 seconds
            timer.Simple(3, function()
                if IsValid(ply) and ply:IsPlayer() then
                    -- Remove bypass flag and trigger last stand (which will handle unconsciousness)
                    ply.testLastStandBypass = false -- Remove bypass flag
                    TriggerLastStand(ply)
                    
                    -- ADDED: Ensure death timer for test (backup in case normal timer fails)
                    timer.Create("RADS_TestLastStandForceEnd_" .. ply:EntIndex(), 60, 1, function()
                        if IsValid(ply) and ply:IsPlayer() and ply.lastStandActive then
                            EndLastStand(ply)
                        end
                    end)
                end
            end)
        end
    end)
    
    -- Reset last stand on death
    hook.Add("PostPlayerDeath", "RADS_ResetLastStand", function(ply)
        if IsValid(ply) then
            ply.lastStandActive = false
            ply.lastStandUnconscious = false
            timer.Remove("RADS_LastStandEnd_" .. ply:EntIndex())
            timer.Remove("RADS_LastStandBypass_" .. ply:EntIndex())
            timer.Remove("RADS_LastStandWakeup_" .. ply:EntIndex())
            timer.Remove("RADS_LastStandRetryWakeup_" .. ply:EntIndex())
            timer.Remove("RADS_LastStandMonitor_" .. ply:EntIndex())
            timer.Remove("RADS_TestLastStandForceEnd_" .. ply:EntIndex()) -- ADDED
            
            -- Send stop signal to client
            net.Start('RADS_StopLastStand')
            net.Send(ply)
        end
    end)
    
    -- Reset last stand on spawn
    hook.Add("PlayerSpawn", "RADS_ResetLastStandOnSpawn", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) then
                ply.lastStandActive = false
                ply.lastStandUnconscious = false
                ply.lastStandCooldown = nil
                timer.Remove("RADS_LastStandEnd_" .. ply:EntIndex())
                timer.Remove("RADS_LastStandBypass_" .. ply:EntIndex())
                timer.Remove("RADS_LastStandWakeup_" .. ply:EntIndex())
                timer.Remove("RADS_LastStandRetryWakeup_" .. ply:EntIndex())
                timer.Remove("RADS_LastStandMonitor_" .. ply:EntIndex())
                timer.Remove("RADS_TestLastStandForceEnd_" .. ply:EntIndex()) -- ADDED
            end
        end)
    end)
    
    -- Ensure player stays unconscious during last stand
    hook.Add("Think", "RADS_EnforceLastStandUnconscious", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply.lastStandUnconscious then
                -- Force unconscious state during last stand
                if not ply.Otrub then
                    ply.Otrub = true
                    ply:SetNWBool("Otrub", true)
                end
            end
        end
    end)
    
    -- Death State System
    function TriggerDeathState(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        -- Check if death state is enabled via convar
        if not GetConVar("rads_death_state"):GetBool() then
            -- If death state is disabled, just kill the player immediately
            timer.Simple(0.1, function()
                if IsValid(ply) then
                    timer.Create("respawntimer" .. ply:EntIndex(), 99999, 1, function() end)
                    ply:Kill()
                end
            end)
            return
        end
        
        -- Check if player is already in death state or dead
        if ply.deathStateActive or not ply:Alive() then return end
        
        -- Set death state
        ply.deathStateActive = true
        ply.deathStateStartTime = CurTime()
        ply.deathStateEndTime = CurTime() + 19 -- 19 seconds duration
        
        -- Set consciousness to 0 and keep player unconscious
        ply.consciousness = 0
        ply.Otrub = true
        ply:SetNWBool("Otrub", true)
        ply:SetNWBool("RADS_InDeathState", true)
        
        -- Send death state to client
        net.Start("RADS_DeathState")
        net.WriteBool(true)
        net.WriteFloat(19.0) -- 19 seconds timer
        net.Send(ply)
        
        -- Send consciousness update
        net.Start("RADS_ConsciousnessTimer")
        net.WriteBool(true) -- Is unconscious
        net.WriteFloat(0) -- Consciousness level
        net.Send(ply)
        
        -- Create 19-second death timer with countdown updates
        timer.Create("RADS_DeathTimer_" .. ply:SteamID64(), 19, 1, function()
            if IsValid(ply) and ply.deathStateActive then
                -- Play death.mp3 sound (client-side only)
                net.Start('RADS_PlayDeathSound')
                net.Send(ply)
                
                -- Actually kill the player after 19 seconds
                EndDeathState(ply)
            end
        end)
        
        -- Timer to update death state countdown
        timer.Create("RADS_DeathStateUpdate_" .. ply:SteamID64(), 0.1, 190, function()
            if IsValid(ply) and ply.deathStateActive then
                local timeLeft = 19.0 - (CurTime() - ply.deathStateStartTime)
                timeLeft = math.max(0, timeLeft)
                
                -- Send updated timer to client
                net.Start("RADS_DeathState")
                net.WriteBool(true)
                net.WriteFloat(timeLeft)
                net.Send(ply)
            end
        end)
    end
    
    function EndDeathState(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        -- Reset death state
        ply.deathStateActive = false
        ply.deathStateStartTime = nil
        ply.deathStateEndTime = nil
        ply:SetNWBool("RADS_InDeathState", false)
        
        -- Send network message to client to stop death state UI
        net.Start("RADS_DeathState")
        net.WriteBool(false)
        net.WriteFloat(0)
        net.Send(ply)
        
        -- Remove timers
        timer.Remove("RADS_DeathTimer_" .. ply:SteamID64())
        timer.Remove("RADS_DeathStateUpdate_" .. ply:SteamID64())
        
        -- Actually kill the player now
        timer.Simple(0.1, function()
            if IsValid(ply) then
                -- Create respawn timer to prevent immediate respawn
                timer.Create("respawntimer" .. ply:EntIndex(), 99999, 1, function() end)
                ply:Kill()
            end
        end)
    end
    
    -- Reset death state on spawn
    hook.Add("PlayerSpawn", "RADS_ResetDeathStateOnSpawn", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) then
                ply.deathStateActive = false
                ply.deathStateStartTime = nil
                ply.deathStateEndTime = nil
                ply:SetNWBool("RADS_InDeathState", false)
                timer.Remove("RADS_DeathTimer_" .. ply:SteamID64())
                timer.Remove("RADS_DeathStateUpdate_" .. ply:SteamID64())
                
                -- Send network message to stop death sounds
                net.Start("RADS_DeathState")
                net.WriteBool(false)
                net.WriteFloat(0)
                net.Send(ply)
            end
        end)
    end)
    
    -- Reset death state on death (cleanup)
    hook.Add("PostPlayerDeath", "RADS_ResetDeathState", function(ply)
        if IsValid(ply) then
            ply.deathStateActive = false
            ply.deathStateStartTime = nil
            ply.deathStateEndTime = nil
            ply:SetNWBool("RADS_InDeathState", false)
            timer.Remove("RADS_DeathTimer_" .. ply:SteamID64())
            timer.Remove("RADS_DeathStateUpdate_" .. ply:SteamID64())
        end
    end)
    
    -- Neck Breaking System
    local function TriggerNeckBreak(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
        if ply.neckBroken then return end -- Prevent multiple triggers
        
        ply.neckBroken = true
        
        -- Apply knockback effect to the head/neck
        local ragdoll = ply:GetNWEntity("player_ragdoll")
        if IsValid(ragdoll) then
            -- Find head bone and apply knockback
            for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
                local boneName = ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i))
                if boneName == "ValveBiped.Bip01_Head1" then
                    local headBone = ragdoll:GetPhysicsObjectNum(i)
                    if IsValid(headBone) then
                        -- Apply backward knockback force
                        local knockbackForce = Vector(0, 0, 0)
                        local headPos = headBone:GetPos()
                        local ragdollPos = ragdoll:GetPos()
                        local direction = (headPos - ragdollPos):GetNormalized()
                        direction.z = math.max(direction.z, 0.3) -- Ensure some upward force
                        knockbackForce = direction * 800 -- Strong knockback
                        headBone:ApplyForceCenter(knockbackForce)
                    end
                    break
                end
            end
        end
        
        -- Play neck snap sound as entity sound (audible to nearby players)
        local soundEnt = ragdoll
        if not IsValid(ragdoll) then
            soundEnt = ply
        end
        
        -- Play sound with limited range
        soundEnt:EmitSound("neck_snap_01.wav", 75, 100, 0.8, CHAN_BODY)
        
        -- Send network message to client for effects
        net.Start('RADS_NeckBreak')
        net.Send(ply)
        
        -- Add thought message
        RADS_AddThought(ply, "Your neck is broken.", 1.0, true)
        
        -- Trigger rigor mortis for neck break
        ply.rigorMortis = true
        -- 30% chance to trigger agonal breathing when rigor mortis occurs from neck break
        if math.random() < 0.1 then
            StartAgonalBreathing(ply)
        end
        
        -- Instant death
        timer.Simple(0.1, function()
            if IsValid(ply) and ply:Alive() then
                -- Set brain health to 0
                if ply.Organs and ply.Organs['brain'] then
                    ply.Organs['brain'] = 0
                end
                
                -- Create respawn timer to prevent immediate respawn
                timer.Create("respawntimer" .. ply:EntIndex(), 99999, 1, function() end)
                TriggerDeathState(ply)
            end
        end)
    end
    
    -- Function to check neck stress during ragdoll
    local function CheckNeckStress(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end
        if not ply:GetNWBool("radsfa") then return end -- Only check when ragdolled
        if ply.neckBroken then return end
        
        -- Skip neck breaking when player is intentionally raising upper body with E key
        if ply.raisingUpperBody then return end
        
        -- Skip neck breaking when player is being strangled by fiber wire
        if ply.fiberWireStrangling or ply:GetNWBool("FiberWireStrangling") then return end
        
        local ragdoll = ply:GetNWEntity("player_ragdoll")
        if not IsValid(ragdoll) then return end
        
        -- Find the head/neck physics object
        local headBone = nil
        local neckBone = nil
        
        for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
            local boneName = ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i))
            if boneName == "ValveBiped.Bip01_Head1" then
                headBone = ragdoll:GetPhysicsObjectNum(i)
            elseif boneName == "ValveBiped.Bip01_Neck1" then
                neckBone = ragdoll:GetPhysicsObjectNum(i)
            end
        end
        
        if not IsValid(headBone) then return end
        
        -- Check for high velocity impact with head
        local headVel = headBone:GetVelocity()
        local headSpeed = headVel:Length()
        
        -- Check if head is moving fast and hits something (70% chance)
        if headSpeed > 1650 then -- High velocity threshold
            local tr = util.TraceLine({
                start = headBone:GetPos(),
                endpos = headBone:GetPos() + headVel:GetNormalized() * 50,
                filter = {ply, ragdoll}
            })
            
            if tr.Hit and tr.HitWorld then
                -- High velocity head impact with world - 70% chance to break neck
                if math.random() < 0.7 then -- 70% chance
                    TriggerNeckBreak(ply)
                    return
                end
            end
        end
        
        -- Check for excessive stress/force on neck (HARDER TO BREAK + CHANCE BASED)
        if IsValid(neckBone) then
            local neckVel = neckBone:GetVelocity()
            local neckSpeed = neckVel:Length()
            
            -- Calculate relative velocity between head and neck
            local relativeVel = (headVel - neckVel):Length()
            
            -- If there's excessive relative motion, chance to break neck (30% chance)
            if relativeVel > 2000 then -- Increased stress threshold from 600 to 750
                if math.random() < 0.15 then -- 30% chance
                    TriggerNeckBreak(ply)
                    return
                end
            end
        end
        
        -- Check for extreme angular velocity (head spinning too fast) - HARDER + CHANCE BASED
        local headAngVel = headBone:GetAngleVelocity()
        if headAngVel:Length() > 2000 then -- Increased threshold from 1000 to 1200
            if math.random() < 0.15 then -- 30% chance
                TriggerNeckBreak(ply)
                return
            end
        end
    end
    
    -- Hook to monitor neck stress during ragdoll
    hook.Add("Think", "RADS_NeckStressMonitor", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
                CheckNeckStress(ply)
            end
        end
    end)
    
    -- Reset neck breaking state on spawn
    hook.Add("PlayerSpawn", "RADS_ResetNeckBreaking", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) then
                ply.neckBroken = false
            end
        end)
    end)
    
    -- Test command for neck breaking
    concommand.Add("rads_testneckbreak", function(ply, cmd, args)
        if IsValid(ply) and ply:IsPlayer() then
            TriggerNeckBreak(ply)
        end
    end)
    
    -- vFire integration variables
    local vFireSupported = false
    local vFireInstalled = false
    
    -- Check for vFire on server start
    timer.Simple(1, function()
        -- Check if vFire functions exist
        if vFireGetVersion and vFireGetBurningEntities then
            vFireInstalled = true
            vFireSupported = true
            print("[RADS] vFire detected! Version: " .. (vFireGetVersion() or "Unknown"))
        else
            print("[RADS] vFire not detected - fire features disabled")
        end
    end)
    
    -- NEW LUNG-BASED OXYGEN SYSTEM
    
    -- Gender detection function for wheeze sounds
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
    
    -- Wheeze sounds removed - simplified oxygen system
    
    -- Main lung damage and oxygen system
    local function UpdateLungOxygenSystem(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        
        -- Initialize oxygen if not set
        if not ply.o2 then
            ply.o2 = 100
        end
        
        -- Check for drowning state and apply oxygen reduction
        if ply.isDrowning then
            local drownOxygenRate = GetConVar("rads_drowning_o2_reduction_rate"):GetFloat()
            ply.o2 = math.max(0, ply.o2 - drownOxygenRate * 2) -- Double the rate for rapid oxygen loss
            
            -- Add fear during drowning using correct network variable
            local currentFear = ply:GetNWFloat("FearAMT", 0)
            local fearMultiplier = GetConVar("rads_drowning_fear_multiplier"):GetFloat()
            local newFear = math.min(3, currentFear + (fearMultiplier * 0.1)) -- Rapid fear increase
            ply:SetNWFloat("FearAMT", newFear)
            
            -- Check drowning duration for death
            if ply.drowningStartTime then
                local drowningDuration = CurTime() - ply.drowningStartTime
                local deathTime = GetConVar("rads_drowning_death_time"):GetFloat()
                
                if drowningDuration >= deathTime then
                    -- Player has been drowning for more than the death time - trigger death state
                    if not ply.deathStateActive then
                        TriggerDeathState(ply)
                    end
                end
            end
        end
        
        -- Get lung health
        local leftLungHealth = (ply.Organs and ply.Organs['left_lung']) or 5
        local rightLungHealth = (ply.Organs and ply.Organs['right_lung']) or 5
        
        -- Count damaged lungs (0 health = damaged)
        local damagedLungs = 0
        if leftLungHealth <= 0 then damagedLungs = damagedLungs + 1 end
        if rightLungHealth <= 0 then damagedLungs = damagedLungs + 1 end
        
        -- Handle stamina effects for 1 damaged lung
        if damagedLungs >= 1 then
            if ply.stamina then
                ply.stamina = 0 -- Drain stamina to 0 and keep it there
            end
            ply.lungStaminaDrain = true
        else
            ply.lungStaminaDrain = false
        end
        
        -- Handle oxygen depletion for 2 damaged lungs
        if damagedLungs >= 2 then
            -- Check if decompression needle is active
            local decompressionActive = ply.decompressionActive and ply.decompressionEndTime and CurTime() < ply.decompressionEndTime
            
            if decompressionActive then
                -- Decompression needle is active - stabilize oxygen at saved level
                if ply.decompressionOxygenLevel then
                    ply.o2 = ply.decompressionOxygenLevel
                end
                -- No oxygen loss while decompression is active
            else
                -- Normal oxygen depletion
                ply.o2 = math.max(0, ply.o2 - 1.5) -- 1.5 oxygen per second
            end
            
            -- Below 50 oxygen: unconsciousness (simplified)
            if ply.o2 <= 50 then
                if not ply.Otrub then
                    ply.Otrub = true
                    ply:SetNWBool("Otrub", true)
                    ply.oxygenUnconscious = true
                end
            else
                -- Above 50 oxygen: wake up if unconscious due to oxygen
                if ply.Otrub and ply.oxygenUnconscious then
                    ply.Otrub = false
                    ply.oxygenUnconscious = false
                    ply:SetNWBool("Otrub", false)
                end
            end
            
            -- Below 20 oxygen: brain damage (oxygen affects brain through blood circulation, not physical trauma)
            if ply.o2 <= 20 and not decompressionActive then
                if ply.Organs and ply.Organs['brain'] then
                    ply.Organs['brain'] = math.max(0, ply.Organs['brain'] - 0.1) -- Slower brain damage
                    if ply.Organs['brain'] <= 0 then
                        -- Death from brain damage
                        timer.Simple(0.1, function()
                            if IsValid(ply) and ply:Alive() then
                                TriggerDeathState(ply)
                            end
                        end)
                    end
                end
            end
        else
            -- No oxygen depletion if less than 2 damaged lungs
            -- Slowly restore oxygen if not at max
            if ply.o2 < 100 then
                ply.o2 = math.min(100, ply.o2 + 0.5) -- Slow recovery
            end
            
            -- Wake up if unconscious due to oxygen
            if ply.Otrub and ply.oxygenUnconscious then
                ply.Otrub = false
                ply.oxygenUnconscious = false
                ply:SetNWBool("Otrub", false)
            end
        end
    end
    
    -- Main lung oxygen system timer
    timer.Create("RADS_LungOxygenSystem", 1, 0, function()
        for _, ply in pairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                UpdateLungOxygenSystem(ply)
            end
        end
    end)
    
    -- Reset lung effects on spawn
    hook.Add("PlayerSpawn", "RADS_ResetLungEffects", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) then
                ply.lungStaminaDrain = false
                ply.oxygenUnconscious = false
                ply.LungWheezeActive = false -- Reset wheeze sound flag
                timer.Remove("RADS_LungWheezeTimer_" .. ply:EntIndex()) -- Stop any existing wheeze timers
                -- Reset decompression effects
                ply.decompressionActive = false
                ply.decompressionEndTime = nil
                ply.decompressionOxygenLevel = nil
                timer.Remove("DecompressionNeedle_" .. ply:EntIndex())
                if not ply.o2 then
                    ply.o2 = 100
                end
            end
        end)
    end)
    
    -- Reset lung effects on death
    hook.Add("PostPlayerDeath", "RADS_ResetLungEffectsOnDeath", function(ply)
        if IsValid(ply) then
            ply.lungStaminaDrain = false
            ply.oxygenUnconscious = false
            -- Reset decompression effects
            ply.decompressionActive = false
            ply.decompressionEndTime = nil
            ply.decompressionOxygenLevel = nil
            timer.Remove("DecompressionNeedle_" .. ply:EntIndex())
        end
    end)
    
    -- Reset decompression effects on disconnect
    hook.Add("PlayerDisconnected", "RADS_ResetDecompressionOnDisconnect", function(ply)
        if IsValid(ply) then
            timer.Remove("DecompressionNeedle_" .. ply:EntIndex())
        end
    end)
    
    -- Console command for testing
    concommand.Add("rads_setoxygen", function(ply, cmd, args)
        if IsValid(ply) and ply:IsPlayer() then
            local amount = tonumber(args[1]) or 100
            amount = math.Clamp(amount, 0, 100)
            ply.o2 = amount
            ply:ChatPrint("Oxygen set to: " .. amount .. "%")
        end
    end)
    
    -- Add test command for concussion effects
    concommand.Add("test_concussion", function(ply, cmd, args)
        if not IsValid(ply) or not ply:Alive() then return end
        
        local intensity = tonumber(args[1]) or 1.0
        intensity = math.Clamp(intensity, 0.1, 3.0)
        
        -- Send concussion effect to client
        net.Start('RADS_TriggerConcussion')
        net.WriteFloat(intensity)
        net.Send(ply)
        
        ply:ChatPrint("Concussion effect triggered with intensity: " .. intensity)
    end)
end
if CLIENT then
    surface.CreateFont( "RADS_ThoughtFont", {
        font = "Coolvetica",
        size = 30,
        weight = 500,
        antialias = true,
        outline = true,
    })
    
    -- Last Stand System Variables
    local lastStandActive = false
    local lastStandEndTime = 0
    local lastStandTinnitusActive = false
    local lastStandTinnitusEndTime = 0
    local lastStandTextActive = false
    local lastStandTextEndTime = 0
    local lastStandCurrentText = ""
    local lastStandTextShake = 0
    
    -- Concussion System Variables
    local concussionActive = false
    local concussionEndTime = 0
    local concussionIntensity = 1.0
    local concussionBlurStrength = 0
    local concussionShakeStrength = 0
    local concussionBloomStrength = 0
    
    -- Import blur function from via_crowbar addon
    local mat_blur = Material("effects/shaders/merc_blur")
    local function DrawConcussionBlur(strength)
        if mat_blur and not mat_blur:IsError() then
            render.UpdateScreenEffectTexture()
            mat_blur:SetFloat("$c0_x", strength)
            render.SetMaterial(mat_blur)
            render.DrawScreenQuad()
        end
    end
    
    -- Network receiver for concussion
    net.Receive('RADS_TriggerConcussion', function()
        local intensity = net.ReadFloat()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Play headhit sound with increased volume
        ply:EmitSound("headhit.mp3", 90, 100, 1) -- Increased from 75 to 90
        
        -- Set concussion parameters
        concussionActive = true
        concussionIntensity = intensity
        concussionEndTime = CurTime() + (8 * intensity) -- Duration scales with intensity
        
        -- Set initial effect strengths
        concussionBlurStrength = 0.4 * intensity
        concussionShakeStrength = 15 * intensity
        concussionBloomStrength = 5.0 * intensity
    end)
    
    -- Network receiver for last stand interruption sound
    net.Receive('RADS_PlayInterruptionSound', function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Play concussion sound when last stand is interrupted
        ply:EmitSound("concussion1.mp3", 75, 100, 1, CHAN_STATIC)
    end)
    
    -- Network receiver for death sound (client-side only)
    net.Receive('RADS_PlayDeathSound', function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Play death.mp3 sound locally
        ply:EmitSound("death.mp3", 75, 100, 1, CHAN_AUTO)
    end)
    
    -- Last Stand Text Display Function
    local function ShowLastStandText(text, duration)
        lastStandCurrentText = text
        lastStandTextActive = true
        lastStandTextEndTime = CurTime() + duration
        lastStandTextShake = 1
    end
    
    -- Last Stand Network Receivers
    net.Receive('RADS_StartLastStand', function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Activate last stand mode
        lastStandActive = true
        lastStandEndTime = CurTime() + 60 -- 60 seconds duration (1 minute)
        
        -- Play last stand sound that follows the player
        ply:EmitSound("laststand.mp3", 75, 100, 1, CHAN_STATIC)
        
        -- Show initial text
        ShowLastStandText("You are heavily injured.", 5)
        
        -- Schedule additional text messages
        timer.Simple(5, function()
            if lastStandActive then
                ShowLastStandText("Your body is fighting for its life.", 5)
            end
        end)
        
        timer.Simple(10, function()
            if lastStandActive then
                ShowLastStandText("This is your last chance.", 5)
            end
        end)
        
        timer.Simple(15, function()
            if lastStandActive then
                ShowLastStandText("Get up.", 5)
            end
        end)
        
        -- Auto-deactivate after duration
        timer.Create("RADS_LastStandTimer", 60, 1, function()
            lastStandActive = false
            lastStandTinnitusActive = false
            lastStandTextActive = false
        end)
    end)
    
    net.Receive('RADS_StopLastStand', function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Deactivate last stand mode
        lastStandActive = false
        lastStandTinnitusActive = false
        lastStandTextActive = false
        
        -- Remove timers
        timer.Remove("RADS_LastStandTimer")
    end)
    
    -- Last Stand HUD Paint
    hook.Add("HUDPaint", "RADS_LastStandText", function()
        if lastStandTextActive and lastStandTextEndTime and CurTime() < lastStandTextEndTime then
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            
            local scrW, scrH = ScrW(), ScrH()
            local centerX, centerY = scrW / 2, scrH / 2
            
            -- Calculate fade and shake
            local timeLeft = lastStandTextEndTime - CurTime()
            local totalDuration = 3 -- Each text shows for 3 seconds
            local fadeProgress = timeLeft / totalDuration
            
            -- Shake effect
            local shakeX = math.sin(CurTime() * 20) * lastStandTextShake * 1.5
            local shakeY = math.cos(CurTime() * 25) * lastStandTextShake * 1
            
            -- Alpha calculation (fade in and out)
            local alpha = 255
            if fadeProgress > 0.8 then
                alpha = math.Clamp((1 - fadeProgress) * 5 * 255, 0, 255) -- Fade in
            elseif fadeProgress < 0.2 then
                alpha = math.Clamp(fadeProgress * 5 * 255, 0, 255) -- Fade out
            end
            
            -- Draw text with coolvetica font
            surface.SetFont("RADS_ThoughtFont")
            surface.SetTextColor(255, 255, 255, alpha)
            local textW, textH = surface.GetTextSize(lastStandCurrentText)
            surface.SetTextPos(centerX - textW/2 + shakeX, centerY - textH/2 + shakeY)
            surface.DrawText(lastStandCurrentText)
            
            -- Reduce shake over time
            lastStandTextShake = math.max(0, lastStandTextShake - FrameTime() * 2)
        end
    end)
    
    -- Last Stand Screen Effects
    hook.Add("RenderScreenspaceEffects", "RADS_LastStandEffects", function()
        if lastStandActive then
            -- Motion blur
            DrawMotionBlur(0.09, 0.70, 0.02)
            
            -- Film grain effect
            render.DrawMercFilmGrain(2, 1.3426, 1.6204, 0.5324, 0.3380)
        end
    end)
    
    -- Add color modification hook for Last Stand
    hook.Add("RenderScreenspaceEffects", "RADS_LastStandColorMod", function()
        if lastStandActive then
            local tab = {
                ["$pp_colour_addr"] = 0,
                ["$pp_colour_addg"] = 0,
                ["$pp_colour_addb"] = 0,
                ["$pp_colour_brightness"] = -0.02,
                ["$pp_colour_contrast"] = 0.85,
                ["$pp_colour_colour"] = 0.58,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(tab)
        end
    end)
    
    -- Last Stand Camera Shake
    hook.Add("CalcView", "RADS_LastStandCameraShake", function(ply, pos, angles, fov)
        if not lastStandActive then return end
        if not ply:Alive() or ply:GetNWBool("fake", false) or ply:GetNWBool("radsfa", false) then return end
        
        local currentTime = CurTime()
        local shake = Angle(0, 0, 0)
        
        -- Intense shake during tinnitus phase
        if lastStandTinnitusActive and currentTime < lastStandTinnitusEndTime then
            local shakeIntensity = 5
            shake = Angle(
                math.sin(currentTime * 10) * shakeIntensity,
                math.cos(currentTime * 8) * shakeIntensity,
                0
            )
        else
            -- Gradual shake that increases over time
            local timeElapsed = currentTime - (lastStandEndTime - 60)
            local intensity = math.Clamp(timeElapsed / 60, 0, 1)
            local shakeIntensity = intensity * 3
            
            shake = Angle(
                math.sin(currentTime * 5) * shakeIntensity,
                math.cos(currentTime * 4) * shakeIntensity,
                0
            )
        end
        
        if shake ~= Angle(0, 0, 0) then
            return {origin = pos, angles = angles + shake, fov = fov}
        end
    end)
    
    -- Concussion camera shake
    hook.Add("CalcView", "RADS_ConcussionCameraShake", function(ply, pos, angles, fov)
        if not concussionActive then return end
        if not ply:Alive() or ply:GetNWBool("fake", false) or ply:GetNWBool("radsfa", false) then return end
        
        local currentTime = CurTime()
        if currentTime >= concussionEndTime then
            concussionActive = false
            return
        end
        
        -- Calculate fade-out progress
        local timeLeft = concussionEndTime - currentTime
        local totalDuration = 8 * concussionIntensity
        local fadeProgress = timeLeft / totalDuration
        
        -- Smooth camera shake with fade-out
        local currentShakeStrength = (15 * concussionIntensity) * fadeProgress
        
        if currentShakeStrength > 0.1 then
            local shake = Angle(
                math.sin(currentTime * 8) * currentShakeStrength * 0.5,
                math.cos(currentTime * 6) * currentShakeStrength * 0.7,
                math.sin(currentTime * 4) * currentShakeStrength * 0.3
            )
            
            return {origin = pos, angles = angles + shake, fov = fov}
        end
    end)
    
    -- Clean up concussion on death
    hook.Add("PostPlayerDeath", "RADS_CleanupConcussion", function()
        concussionActive = false
        concussionBlurStrength = 0
        concussionShakeStrength = 0
        concussionBloomStrength = 0
        concussionIntensity = 1.0
        concussionEndTime = 0
    end)
    
    -- Clean up last stand on death
    hook.Add("PostPlayerDeath", "RADS_CleanupLastStand", function()
        lastStandActive = false
        lastStandTinnitusActive = false
        lastStandTextActive = false
        
        if lastStandSoundChannel and IsValid(lastStandSoundChannel) then
            lastStandSoundChannel:Stop()
            lastStandSoundChannel = nil
        end
    end)
    
    -- Shared vignette variables for both pain and oxygen systems (GLOBAL within CLIENT scope)
    mat_PainVignette = Material( "effects/shaders/merc_vignette" )
    currentVignetteOuter = 3.700 -- Start with no vignette
    targetVignetteOuter = 0.650
    vignetteTransitionSpeed = 2.0 -- How fast the vignette transitions
    
    -- REMOVED: Oxygen vignette variables - oxygen now directly affects consciousness
    
    -- Oxygen system client variables
    local currentOxygen = 100
    local oxygenEffectsActive = false
    local lastOxygenWarning = 0
    local oxygenBreathingSound = nil
    
    -- Oxygen visual effects removed - simplified system
    
    -- Concussion visual effects
    hook.Add("RenderScreenspaceEffects", "RADS_ConcussionEffects", function()
        if not concussionActive then return end
        
        local currentTime = CurTime()
        if currentTime >= concussionEndTime then
            concussionActive = false
            concussionBlurStrength = 0
            concussionShakeStrength = 0
            concussionBloomStrength = 0
            concussionIntensity = 1.0
            concussionEndTime = 0
            return
        end
        
        -- Calculate fade-out progress
        local timeLeft = concussionEndTime - currentTime
        local totalDuration = 8 * concussionIntensity
        local fadeProgress = timeLeft / totalDuration
        
        -- Apply blur effect with fade-out
        local currentBlur = (0.4 * concussionIntensity) * fadeProgress
        if currentBlur > 0.01 then
            DrawConcussionBlur(currentBlur)
        end
        
        -- Apply bloom effect with fade-out (FIXED: Bloom now properly fades out)
        local currentBloom = (5.0 * concussionIntensity) * fadeProgress
        if currentBloom > 0.01 then -- Reduced threshold from 0.1 to 0.01 for smoother fade
            DrawBloom(0.65, currentBloom, 9, 9, 1, 1, 1, 1, 1)
        end
    end)
    
    -- Pain-based film grain effect with PNG overlay
    local mat_PainFilmgrain = Material("effects/shaders/merc_filmgrain")
    local mat_DamageOverlay = Material("overlays/damage.png")
 
    if mat_DamageOverlay then
     
    end
    local painDroneSound = nil
    local lastPainDroneVolume = 0
    
    -- Fade-in system variables
    local currentEffectIntensity = 0
    local targetEffectIntensity = 0
    local fadeInSpeed = 3.0  -- How fast the effect fades in
    local fadeOutSpeed = 1.5 -- How fast the effect fades out
    
    -- Pulsating effect variables
    local pulseTime = 0
    local pulseSpeed = 2.5 -- How fast the pulse effect cycles
    
    -- Note: pain variable is global and updated via info_pain network message in fakerb.lua
    
    hook.Add("RenderScreenspaceEffects", "RADS_PainFilmGrain", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then 
            -- Reset effect when dead
            currentEffectIntensity = 0
            targetEffectIntensity = 0
            unconsciousnessFade = 1.0
    
            return 
        end
        
        -- Check if player is unconscious (Otrub)
        local isUnconscious = ply:GetNWBool("Otrub", false)

        
        -- Initialize unconsciousness fade if it doesn't exist
        if unconsciousnessFade == nil then
            unconsciousnessFade = 1.0

        end
        
        -- Handle unconsciousness fade (slower fade than pain effects)
        local unconsciousFadeSpeed = 1.5 -- Slower fade for unconsciousness (was 4.0)
        local targetUnconsciousFade = isUnconscious and 0.0 or 1.0
        
        local frameTime = FrameTime()
        if unconsciousnessFade ~= targetUnconsciousFade then
            local fadeStep = unconsciousFadeSpeed * frameTime
            if targetUnconsciousFade > unconsciousnessFade then
                unconsciousnessFade = math.min(unconsciousnessFade + fadeStep, targetUnconsciousFade)
            else
                unconsciousnessFade = math.max(unconsciousnessFade - fadeStep, targetUnconsciousFade)
            end
    
        end
        
        -- Get pain limit from ConVar with nil check
        local painLimitConVar = GetConVar("rads_painlimit")
        local painLimit = painLimitConVar and painLimitConVar:GetFloat() or 190
        
        -- Calculate pain intensity (0 to 1) using global pain variable
        local painIntensity = math.Clamp((pain or 0) / painLimit, 0, 1)
        
        -- Calculate target effect intensity based on pain
        if painIntensity > 0.1 then
            -- Scale intensity from 0.1-1.0 pain to 0-1.0 effect
            targetEffectIntensity = math.Clamp((painIntensity - 0.1) / 0.9, 0, 1)
        else
            targetEffectIntensity = 0
        end
        
        -- Apply unconsciousness fade to target intensity
        targetEffectIntensity = targetEffectIntensity * unconsciousnessFade
        
        -- Smoothly fade the effect in/out
        if currentEffectIntensity < targetEffectIntensity then
            -- Fade in
            currentEffectIntensity = math.min(currentEffectIntensity + frameTime * fadeInSpeed, targetEffectIntensity)
        elseif currentEffectIntensity > targetEffectIntensity then
            -- Fade out
            currentEffectIntensity = math.max(currentEffectIntensity - frameTime * fadeOutSpeed, targetEffectIntensity)
        end
        
        -- Only apply film grain effect if there's any intensity
        if currentEffectIntensity > 0.01 then
            local effectIntensity = currentEffectIntensity
            
            -- Update pulse time
            pulseTime = pulseTime + frameTime * pulseSpeed
            
            -- Calculate pulsating multiplier (smooth sine wave between 0.7 and 1.3)
            local pulseMultiplier = 1.0 + (math.sin(pulseTime) * 0.3 * effectIntensity)
            
            -- Film grain parameters based on pain intensity with pulsating effect (reduced intensity)
            local blendMode = 3 -- Addition
            local speed = 2.4057 * effectIntensity * pulseMultiplier
            local intensity = 0.035 * effectIntensity * pulseMultiplier -- Reduced from 0.075 to 0.035
            local mean = 0.1274 * effectIntensity
            local variance = 0.4575 * effectIntensity * pulseMultiplier
            
            -- Apply film grain effect
            render.UpdateScreenEffectTexture()
            mat_PainFilmgrain:SetInt("$c0_y", blendMode)
            mat_PainFilmgrain:SetFloat("$c0_z", speed)
            mat_PainFilmgrain:SetFloat("$c0_w", intensity)
            mat_PainFilmgrain:SetFloat("$c1_x", mean)
            mat_PainFilmgrain:SetFloat("$c1_y", variance)
            
            render.SetMaterial(mat_PainFilmgrain)
            render.DrawScreenQuad()
        end
    end)
    
    -- PNG damage overlay system (separate from film grain)
    hook.Add("HUDPaint", "RADS_PainOverlay", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then 
            return 
        end
        
        -- Only apply PNG overlay if there's any intensity
        if currentEffectIntensity > 0.01 then
            local effectIntensity = currentEffectIntensity
            
            -- Calculate pulsating multiplier for alpha
            local pulseMultiplier = 1.0 + (math.sin(pulseTime) * 0.3 * effectIntensity)
            
            -- Calculate PNG overlay alpha with pulsating effect (increased visibility)
            local overlayAlpha = math.Clamp(effectIntensity * pulseMultiplier * 320, 0, 255) -- Increased from 255 to 320 for better visibility
            
            -- Calculate pulsating scale effect (1.3x to 1.7x, base 1.5x)
            local baseScale = 1.4
            local scaleVariation = 0.2 * effectIntensity -- Scale variation based on pain intensity
            local scalePulse = math.sin(pulseTime * 0.8) * scaleVariation
            local currentScale = baseScale + scalePulse
            
            -- Calculate scaled dimensions
            local scaledWidth = ScrW() * currentScale
            local scaledHeight = ScrH() * currentScale
            local baseX = (ScrW() - scaledWidth) / 2
            local baseY = (ScrH() - scaledHeight) / 2
            
            -- Add subtle pulsating movement
            local positionPulseMagnitudeX = 8 * effectIntensity
            local positionPulseMagnitudeY = 8 * effectIntensity
            local currentPositionalOffsetX = math.sin(pulseTime * 1.2) * positionPulseMagnitudeX
            local currentPositionalOffsetY = math.cos(pulseTime * 1.1) * positionPulseMagnitudeY
            
            -- Add rapid but subtle shaking effect
            local shakeIntensity = 3 * effectIntensity -- Max 3 pixels shake
            local shakeX = (math.random() - 0.5) * 2 * shakeIntensity
            local shakeY = (math.random() - 0.5) * 2 * shakeIntensity
            
            -- Combine all position effects
            local finalX = baseX + currentPositionalOffsetX + shakeX
            local finalY = baseY + currentPositionalOffsetY + shakeY
            
            -- Check material status
            if not mat_DamageOverlay then
                return
            end
            
            -- Draw the PNG overlay using surface functions
            surface.SetDrawColor(255, 255, 255, overlayAlpha)
            surface.SetMaterial(mat_DamageOverlay)
            surface.DrawTexturedRect(finalX, finalY, scaledWidth, scaledHeight)
        end
    end)
    
    -- Pain drone sound system
    hook.Add("Think", "RADS_PainDroneSound", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then
            -- Stop pain drone if player is invalid or dead
            if painDroneSound then
                painDroneSound:Stop()
                painDroneSound = nil
                lastPainDroneVolume = 0
            end
            return
        end
        
        -- Check if player is unconscious (Otrub) - affects sound too
        local isUnconscious = ply:GetNWBool("Otrub", false)
        
        -- Get pain limit from ConVar with nil check
        local painLimitConVar = GetConVar("rads_painlimit")
        local painLimit = painLimitConVar and painLimitConVar:GetFloat() or 190
        
        -- Calculate pain intensity (0 to 1) using global pain variable
        local painIntensity = math.Clamp((pain or 0) / painLimit, 0, 1)
        
        -- Only play drone if pain is above 40% of limit AND player is conscious
        if painIntensity > 0.4 and not isUnconscious then
            -- Scale volume from 0.4-1.0 pain to 0-1.0 volume
            local droneVolume = math.Clamp((painIntensity - 0.4) / 0.6, 0, 1) * 0.8
            
            -- Start or update pain drone sound
            if not painDroneSound then
                painDroneSound = CreateSound(ply, "PainDrone.mp3")
                if painDroneSound then
                    painDroneSound:Play()
                    painDroneSound:SetSoundLevel(0) -- Only audible to local player
                end
            end
            
            -- Update volume if it changed significantly
            if painDroneSound and math.abs(droneVolume - lastPainDroneVolume) > 0.05 then
                painDroneSound:ChangeVolume(droneVolume, 0.2)
                lastPainDroneVolume = droneVolume
            end
        else
            -- Stop pain drone if pain is too low OR player is unconscious
            if painDroneSound then
                painDroneSound:FadeOut(0.5)
                painDroneSound = nil
                lastPainDroneVolume = 0
            end
        end
    end)
    
    -- REMOVED: Oxygen vignette system - oxygen now directly affects consciousness instead of vignette
end
if SERVER then
    util.AddNetworkString('RADS_BrainDamageFX')
    util.AddNetworkString('RADS_StopBrainDamageFX')
    util.AddNetworkString('RADS_PlayerUnconscious')
    util.AddNetworkString('RADS_BrainDeathSound') -- New network string for brain death sound
    util.AddNetworkString('RADS_BrainShutdown') -- New network string for brain shutdown
    util.AddNetworkString('RADS_BrainMeltdownStart') -- New network string for initiating brain meltdown
    util.AddNetworkString('RADS_SetHearingState') -- New network string for controlling player hearing
    util.AddNetworkString('RADS_StopLungFX') -- New network string for stopping lung effects
util.AddNetworkString('RADS_PlayLungWheeze') -- New network string for playing lung wheeze sound
util.AddNetworkString('RADS_PlayAgonalBreathing') -- Network string for agonal breathing sounds
util.AddNetworkString('RADS_StopAgonalBreathing') -- Network string for stopping agonal breathing
util.AddNetworkString('RADS_TinnitusScreenshake') -- Network string for tinnitus screenshake state
util.AddNetworkString('RADS_ExplosionTinnitus') -- Network string for explosion-triggered tinnitus
util.AddNetworkString('RADS_BlastUnconsciousSound') -- Network string for blast-induced unconsciousness sound
    -- Add new network string for thoughts system
    util.AddNetworkString('RADS_AddThought')
util.AddNetworkString('RADS_EyeLossShake')
end

local organOBBs = {
    skull = {
        bone = "ValveBiped.Bip01_Head1",
        min = Vector(-1, -4, -4),
        max = Vector(7, 4, 3),
        color = Color(255, 255, 0, 100) -- yellow
    },
    jaw = {
        bone = "ValveBiped.Bip01_Head1",
        min = Vector(-2, -6, -3),
        max = Vector(3, -1, 3),
        color = Color(200, 200, 100, 100) -- light yellow
    },
    brain = {
        bone = "ValveBiped.Bip01_Head1",
        min = Vector(1.3, -3, -2.9),
        max = Vector(6.3, 3, 2.8),
        color = Color(0, 0, 255, 100) -- Blue for brain
    },
    artery = {
        bone = "ValveBiped.Bip01_Neck1",
        min = Vector(-2, -4, -1), -- Reverted to smaller size
        max = Vector(3, 0, 2),    -- Reverted to smaller size
        color = Color(255, 0, 0, 150) -- Red, slightly more opaque
    },
    radial_artery_l = {
        bone = "ValveBiped.Bip01_L_Hand",
        min = Vector(-1, -1, -1), -- Reverted to smaller size
        max = Vector(1, 1, 1),    -- Reverted to smaller size
        color = Color(255, 0, 0, 100) -- red
    },
    radial_artery_r = {
        bone = "ValveBiped.Bip01_R_Hand",
        min = Vector(-1, -1, -1), -- Reverted to smaller size
        max = Vector(1, 1, 1),    -- Reverted to smaller size
        color = Color(255, 0, 0, 100) -- red
    },
    femoral_artery_l = {
        bone = "ValveBiped.Bip01_L_Thigh",
        min = Vector(0, -1, -1), -- Reverted to smaller size
        max = Vector(11, 0, 0),
        color = Color(255, 0, 0, 100) -- red
    },
    femoral_artery_r = {
        bone = "ValveBiped.Bip01_R_Thigh",
        min = Vector(-0, -1, -1),
        max = Vector(11, 0, -0),
        color = Color(255, 0, 0, 100) -- red
    },
    popliteal_artery_l = {
        bone = "ValveBiped.Bip01_L_Calf",
        min = Vector(-2, -2, -2), -- Adjusted for behind the knee
        max = Vector(4, 2, 1),    -- Adjusted for behind the knee
        color = Color(255, 0, 0, 100) -- red
    },
    popliteal_artery_r = {
        bone = "ValveBiped.Bip01_R_Calf",
        min = Vector(-2, -2, -2), -- Adjusted for behind the knee
        max = Vector(4, 2, 1),    -- Adjusted for behind the knee
        color = Color(255, 0, 0, 100) -- red
    },
    ribs = {
        bone = "ValveBiped.Bip01_Spine2", -- Centered on the chest area
        min = Vector(-3, -1, -8), -- Expanded to cover sides and up/down
        max = Vector(10, 8, 8),    -- Expanded to cover sides and up/down
        color = Color(150, 150, 150, 100) -- Greyish color
    },
    left_lung = {
        bone = "ValveBiped.Bip01_Spine2", -- Left chest area, near heart
        min = Vector(-2, -1, -5), -- Adjusted for left side
        max = Vector(8, 5, 2),
        color = Color(0, 200, 200, 150) -- Cyan
    },
    right_lung = {
        bone = "ValveBiped.Bip01_Spine2", -- Right chest area, near heart
        min = Vector(-2, -1, 0), -- Adjusted for right side
        max = Vector(8, 5, 6),
        color = Color(0, 200, 200, 200) -- Cyan
    },
    liver = {
        bone = "ValveBiped.Bip01_Spine1", -- Upper abdomen
        min = Vector(-4, -1, -6),
        max = Vector(2, 5, -1),
        color = Color(200, 100, 0, 100) -- Orange
    },
    stomach = {
        bone = "ValveBiped.Bip01_Spine1", -- Mid abdomen
        min = Vector(-4, -1, -1),
        max = Vector(2, 5, 6),
        color = Color(150, 50, 150, 100) -- Purple
    },
    intestines = {
        bone = "ValveBiped.Bip01_Spine", -- Lower abdomen
        min = Vector(-4, -1, -6),
        max = Vector(1, 5, 6),
        color = Color(100, 200, 50, 100) -- Greenish
    },
    heart = {
        bone = "ValveBiped.Bip01_Spine2", -- Left chest
        min = Vector(1, 0, -1),
        max = Vector(5, 4, 3),
        color = Color(255, 0, 0, 150) -- Red, slightly more opaque
    },
    upper_spine = {
        bone = "ValveBiped.Bip01_Spine4", -- Upper spine area
        min = Vector(-8, -3, -1),
        max = Vector(2, 0, 1),
        color = Color(100, 100, 100, 100) -- Dark Grey
    },
    lower_spine = {
        bone = "ValveBiped.Bip01_Spine2", -- Lower spine area
        min = Vector(-12, -4, -1),
        max = Vector(1, 0, 1),
        color = Color(100, 100, 100, 100) -- Dark Grey
    },
    bladder = {
        bone = "ValveBiped.Bip01_Pelvis", -- Pelvic area
        min = Vector(-2, -2, -2),
        max = Vector(2, 2, 2),
        color = Color(100, 100, 255, 100) -- Light Blue
    },
    left_eye = {
        bone = "ValveBiped.Bip01_Head1",
        min = Vector(2, -5, 1),
        max = Vector(5, 1, -3),
        color = Color(255, 255, 255, 150) -- White
    },
    right_eye = {
        bone = "ValveBiped.Bip01_Head1",
        min = Vector(2, -5, 1),
        max = Vector(5, 1, 2),
        color = Color(255, 255, 255, 150) -- White
    },
    pelvis = {
        bone = "ValveBiped.Bip01_Pelvis",
        min = Vector(-7, -4, -3),
        max = Vector(7, 4, 3),
        color = Color(200, 150, 100, 100) -- Light brown
    }
}

-- Helper function to get adjusted organ OBB coordinates for ragdolls
local function GetAdjustedOrganOBB(ent, organName)
    local organData = organOBBs[organName]
    if not organData then return nil, nil end
    
    -- Always return original coordinates - let render.DrawBox handle the bone matrix transformation
    -- The previous complex transformation was causing scaling and positioning issues
    return organData.min, organData.max
end

if CLIENT then
    local SND_LOOP = 1 -- Define SND_LOOP for looping sounds
    print("damage.lua: Client-side code loaded!")
    local organData = organData or {} -- Initialize organData to prevent nil access
    
    -- Heartbeat and pulse system variables
    local lastHeartbeatTime = 0
    local heartbeatInterval = 1 -- Default 60 BPM
    
    -- Update heartbeat based on pulse
    local function UpdateHeartbeat()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        
        -- Get pulse from NWInt instead of ply.pulse
        local pulse = ply:GetNWInt("PlayerPulse", 70)
        local heartbeatThreshold = 95 -- Only play heartbeat when pulse is above this
        
        -- Only play heartbeat if pulse is above threshold
        if pulse <= heartbeatThreshold then return end
        
        -- Calculate heartbeat interval (60 BPM = 1 second interval)
        heartbeatInterval = 60 / pulse
        
        -- Play heartbeat sound if enough time has passed
        if CurTime() >= lastHeartbeatTime + heartbeatInterval then
            -- Calculate volume based on pulse (higher pulse = louder heartbeat)
            local pulseRatio = math.Clamp((pulse - heartbeatThreshold) / (200 - heartbeatThreshold), 0, 1)
            local heartbeatVolume = math.Clamp(0.3 + (pulseRatio * 0.7), 0.3, 1.0) -- Volume increases with pulse
            
            ply:EmitSound("heartbeat_single.wav", 75, 100, heartbeatVolume, CHAN_AUTO)
            lastHeartbeatTime = CurTime()
        end
    end
    
    -- Hook to update heartbeat continuously
    hook.Add("Think", "RADS_HeartbeatSystem", UpdateHeartbeat)




    -- Vignette variables already declared at the top of CLIENT block
    
    -- Add performance optimization variables
    local cheapEffectsEnabled = false
    local lastCheapEffectsCheck = 0
    
    -- Cache convar check (only check every 0.5 seconds for performance)
    local function ShouldUseCheapEffects()
        local currentTime = CurTime()
        if currentTime - lastCheapEffectsCheck > 0.5 then
            local convar = GetConVar("rads_cheapeffects")
            if convar then
                cheapEffectsEnabled = convar:GetBool()
            else
                cheapEffectsEnabled = false -- Default to false if convar doesn't exist
            end
            lastCheapEffectsCheck = currentTime
        end
        return cheapEffectsEnabled
    end

    -- Adrenaline system variables
    local adrenalineLevel = 0 -- Current adrenaline level (0-100)
    local adrenalineActive = false -- Whether adrenaline effects are active
    local adrenalineEndTime = 0 -- When adrenaline effects end
    local adrenalineCooldownEnd = 0 -- When cooldown ends
    local adrenalineShakeStrength = 0 -- Current shake intensity
    local adrenalineShakeSpeed = 2.0
    local adrenalineShakeAngle = Angle(0,0,0)
    local adrenalineShakeSeed = math.Rand(0, 1000)
    local currentRadialBlur = 0 -- Current radial blur amount
    local targetRadialBlur = 0 -- Target radial blur amount
    local adrenalineTransitionSpeed = 3.0 -- How fast effects transition
    
    -- Radial blur material (assuming it exists or we'll create a fallback)
    local mat_RadialBlur = Material("effects/shaders/merc_radialblur")
    
    -- Optimized radial blur function with cheap effects check
    local function DrawAdrenalineRadialBlur(intensity)
        -- Skip radial blur entirely if cheap effects are enabled
        if ShouldUseCheapEffects() then
            return
        end
        
        if mat_RadialBlur and not mat_RadialBlur:IsError() then
            render.UpdateScreenEffectTexture()
            mat_RadialBlur:SetFloat("$c0_x", 0.5)
            mat_RadialBlur:SetFloat("$c0_y", 0.5)
            mat_RadialBlur:SetFloat("$c0_z", intensity)
            render.SetMaterial(mat_RadialBlur)
            render.DrawScreenQuad()
        else
            -- Fallback: use lighter motion blur only if cheap effects disabled
            DrawMotionBlur(intensity * 0.3, 0.6, 0.005) -- Reduced intensity
        end
    end
    
    -- Network receiver for adrenaline updates
    net.Receive('RADS_AdrenalineUpdate', function()
        adrenalineLevel = net.ReadFloat()
        local isActive = net.ReadBool()
        local duration = net.ReadFloat()
        local cooldownDuration = net.ReadFloat()
        
        if isActive and not adrenalineActive then
            -- Starting adrenaline
            adrenalineActive = true
            adrenalineEndTime = CurTime() + duration
            adrenalineCooldownEnd = adrenalineEndTime + cooldownDuration
            
            -- Calculate target effects based on adrenaline level (REMOVED SHAKE)
            -- adrenalineShakeStrength = (adrenalineLevel / 100) * 5 -- Max 5 degrees shake
            targetRadialBlur = (adrenalineLevel / 100) * 0.2 -- Max 0.2 radial blur
            
            -- Remove muffled hearing effect - conflicts with unconsciousness
            
        elseif not isActive and adrenalineActive then
            -- Ending adrenaline - check if it's due to death (adrenalineLevel = 0)
            adrenalineActive = false
            
            if adrenalineLevel <= 0 then
                -- Player died or adrenaline completely depleted - immediately clear effects
                targetRadialBlur = 0
                currentRadialBlur = 0  -- Immediately clear blur
                -- adrenalineShakeStrength = 0
 
            else
                -- Normal adrenaline end - set target to 0 for fade-out
                targetRadialBlur = 0
                -- Force faster fade-out by reducing current blur significantly
                currentRadialBlur = currentRadialBlur * 0.3
                -- adrenalineShakeStrength = 0
            end
            
            -- Remove hearing restoration code - no longer needed
        elseif isActive then
            -- Update effects based on current adrenaline level during active period (REMOVED SHAKE)
            -- adrenalineShakeStrength = (adrenalineLevel / 100) * 5
            targetRadialBlur = (adrenalineLevel / 100) * 0.2
        elseif adrenalineLevel <= 0 then
            -- Handle case where adrenaline level drops to 0 but we missed the isActive change
            adrenalineActive = false
            targetRadialBlur = 0
            currentRadialBlur = 0  -- Immediately clear blur
            -- adrenalineShakeStrength = 0
            -- Remove hearing restoration code - no longer needed
  
        end
    end)

    -- Overlay paths
    local BRAIN_HEMORRHAGE_OVERLAY = Material("overlays/brainhemorrhageoverlay.png")
    local DAMAGE_OVERLAY = Material("overlays/damageOverlay.png") -- Corrected: Removed '3' from filename
    local INNER_SHADOW_OVERLAY = Material("overlays/innershadow.png")
    local LEFT_EYE_GONE_OVERLAY = Material("overlays/lefteyegone.png")
    local RIGHT_EYE_GONE_OVERLAY = Material("overlays/righteyegone.png")
    local FLASHING_OVERLAYS = {
        Material("overlays/peripheralorboverlay.png"),
        Material("overlays/photopsiaoverlay1.png"),
        Material("overlays/photopsiaoverlay2.png"),
        Material("overlays/photopsiaoverlay3.png"),
        Material("overlays/photopsiaoverlay4.png"),
        Material("overlays/tallflash1.png"),
        Material("overlays/tallflash2.png"),
        Material("overlays/tallflash3.png"),
    }

    local MALE_WHEEZE_SOUNDS = {
        "male_wheeze1.wav",
        "male_wheeze2.wav",
        "male_wheeze3.wav",
        "male_wheeze4.wav",
        "male_wheeze5.wav",
    }

    local FEMALE_WHEEZE_SOUNDS = {
        "female_wheeze1.wav",
        "female_wheeze2.wav",
        "female_wheeze3.wav",
        "female_wheeze4.wav",
        "female_wheeze5.wav",
    }

    local AGONAL_BREATHING_SOUNDS = {
        "breathing/agonalbreathing_1.wav",
        "breathing/agonalbreathing_2.wav",
        "breathing/agonalbreathing_3.wav",
        "breathing/agonalbreathing_4.wav",
        "breathing/agonalbreathing_5.wav",
        "breathing/agonalbreathing_6.wav",
        "breathing/agonalbreathing_7.wav",
        "breathing/agonalbreathing_8.wav",
        "breathing/agonalbreathing_9.wav",
        "breathing/agonalbreathing_10.wav",
        "breathing/agonalbreathing_11.wav",
        "breathing/agonalbreathing_12.wav",
        "breathing/agonalbreathing_13.wav",
    }

    local flashingOverlayIndex = 1
    local isHemorrhageOverlayActive = false

    local lastFlashStartTime = 0 -- To track when the current flash started
    local currentFlashDuration = 0 -- To track how long the current flash should last
    local flashTriggerTimerName = "RADS_BrainDamageFlashTrigger" -- New timer name for flashing intervals

    -- New: Client-side variables for fade-in effect
    local RADS_DamageOverlayFadeStartTime = 0
    local RADS_DamageOverlayFadeDuration = 0.5 -- Fast fade duration (0.5 seconds)

    -- Function to trigger the next flash and schedule the next interval
    local function TriggerNextFlash()
        if not isHemorrhageOverlayActive then
            timer.Remove(flashTriggerTimerName)
            return
        end

        lastFlashStartTime = CurTime()
        currentFlashDuration = math.Rand(0.2, 0.5) -- Flash stays on screen for 0.2 to 0.5 seconds

        flashingOverlayIndex = flashingOverlayIndex + 1
        if flashingOverlayIndex > #FLASHING_OVERLAYS then
            flashingOverlayIndex = 1 -- Loop back to the first flashing overlay
        end

        -- Trigger a momentary screen shake with each flash
        local ply = LocalPlayer()
        if IsValid(ply) and ply:Alive() and not ply:GetNWBool("radsfa", false) then
            util.ScreenShake(ply:GetPos(), 2, 2, 0.1, 500) -- Small, brief shake
        end

        local nextInterval = math.Rand(0.5, 5.0) -- Next flash occurs randomly between 0.5 and 5 seconds
        timer.Create(flashTriggerTimerName, nextInterval, 1, TriggerNextFlash)
    end

    hook.Add("PostPlayerDraw", "DrawOrganHitboxes", function(ply)
        if not GetConVar("developer"):GetBool() then return end
        if not ply:Alive() then return end
        for organ, data in pairs(organOBBs) do
            local bone = ply:LookupBone(data.bone)
            if bone then
                local pos, ang = ply:GetBonePosition(bone)
                if pos and ang then
                    render.SetColorMaterial()
                    render.DrawBox(pos, ang, data.min, data.max, data.color, true)
                end
            end
        end
    end)

    -- Draw organ OBBs for ragdolls when developer mode is enabled
    hook.Add("PostDrawOpaqueRenderables", "DrawRagdollOrganHitboxes", function()
        if not GetConVar("developer"):GetBool() then return end
        
        -- Find all ragdolls in the world
        for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
            if IsValid(ent) then
                -- Draw organ OBBs for this ragdoll
                for organ, data in pairs(organOBBs) do
                    local bone = ent:LookupBone(data.bone)
                    if bone then
                        local boneMatrix = ent:GetBoneMatrix(bone)
                        if boneMatrix then
                            local pos = boneMatrix:GetTranslation()
                            local ang = boneMatrix:GetAngles()
                            
                            -- Get adjusted OBB coordinates for ragdolls
                            local adjustedMin, adjustedMax = GetAdjustedOrganOBB(ent, organ)
                            if adjustedMin and adjustedMax then
                                render.SetColorMaterial()
                                render.DrawBox(pos, ang, adjustedMin, adjustedMax, data.color, true)
                            end
                        end
                    end
                end
            end
        end
    end)

    function DrawOrganRect(x, y, width, height, healthPercentage, organName)
        local filledHeight = height * healthPercentage
        
        -- Draw black outline first
        draw.RoundedBox(0, x - 1, y - 1, width + 2, height + 2, Color(0, 0, 0))
        
        -- Draw red background (damaged portion)
        draw.RoundedBox(0, x, y, width, height, Color(255, 0, 0))
        
        -- Draw green foreground (healthy portion)
        draw.RoundedBox(0, x, y + (height - filledHeight), width, filledHeight, Color(0, 255, 0))
        
        -- Draw organ name and health percentage
        draw.SimpleText(organName, "DefaultFixedDropShadow", x + width / 2, y + height + 5, Color(255, 255, 255), TEXT_ALIGN_CENTER)
        draw.SimpleText(math.floor(healthPercentage * 100) .. "%", "DefaultFixedDropShadow", x + width / 2, y + height + 15, Color(255, 255, 255), TEXT_ALIGN_CENTER)
    end

    function DrawOrganHealth()
        if not organData.organs or next(organData.organs) == nil then return end
        local startX = 55
        local startY = 55
        local width = 35
        local height = 100
        
        -- Organ maximum health values
        local maxHealth = {
            ["liver"] = 15,
            ["stomach"] = 15,
            ["intestines"] = 30,
            ["heart"] = 9,
            ["left_lung"] = 5,
            ["right_lung"] = 5
        }
        
        for organ, health in pairs(organData.organs) do
            local maxHP = maxHealth[organ] or 10
            local healthPercentage = math.Clamp(health / maxHP, 0, 1)
            local organName = organ
            DrawOrganRect(startX, startY, width, height, healthPercentage, organName)
            startX = startX + width + 25
        end
    end

    net.Receive("info_org", function()
        local data = net.ReadTable()
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply.pain = data.pain
            ply.painlosing = data.painlosing
            ply.Organs = data.organs
            ply.pulse = data.pulse or 70  -- Add this line to receive pulse data
            

 
            
            -- ply.Blood = data.blood -- REMOVED: Now using NWInt
        end
        organData = data
        DrawOrganHealth()
    end)

    hook.Add("HUDPaint", "DrawOrganHealth", function() 
    local drawOrgConVar = GetConVar('rads_draworg')
    if drawOrgConVar and drawOrgConVar:GetBool() then 
        DrawOrganHealth() 
    end 
end)

    hook.Add("PlayerThink", "RADS_DebugPain", function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            local currentPain = ply.pain or 0
            local painLosing = ply.painlosing or 0
            local painLimit = GetConVar("rads_painlimit"):GetInt() or 0
        end
    end)

    -- Removed sound.Play("ko.wav") from here to centralize sound control
    net.Receive('RADS_PlayerUnconscious', function(len)
        local isBecomingUnconscious = net.ReadBool() -- Read the boolean sent from server

        if not isBecomingUnconscious then -- Player is becoming conscious
            RADS_DamageOverlayFadeStartTime = CurTime()
        else -- Player is becoming unconscious
            RADS_DamageOverlayFadeStartTime = 0 -- Stop any ongoing fade-in, as it will be hidden by Otrub check
            
            -- REMOVED: ko.wav sound - user requested to disable this sound
            -- sound.PlayFile("sound/ko.wav", "noplay", function(station)
            --     if IsValid(station) then
            --         station:SetVolume(1.0)
            --         station:Play()
            --     end
            -- end)
        end
    end)

    -- New client-side handler for hearing state
    net.Receive('RADS_SetHearingState', function()
        local shouldMute = net.ReadBool()
        if shouldMute then
            LocalPlayer():ConCommand("soundfade 100 99999") -- Fade out sound
        else
            LocalPlayer():ConCommand("soundfade 0 1") -- Fade in sound
        end
    end)
    
    -- Client-side handler for blast unconsciousness sound
    local blastUnconsciousSound = nil
    
    net.Receive('RADS_BlastUnconsciousSound', function()
        -- Stop any existing blast unconscious sound
        if blastUnconsciousSound then
            blastUnconsciousSound:Stop()
            blastUnconsciousSound = nil
        end
        
        -- Play sonarouch.mp3 using sound.PlayFile to match tinnitus system implementation
        sound.PlayFile("sound/sonarouch.mp3", "noplay", function(channel, errorID, errorName)
            if IsValid(channel) then
                blastUnconsciousSound = channel
                channel:SetVolume(1.0) -- Full volume
                channel:EnableLooping(false) -- Single play
                channel:Play()
            end
        end)
    end)

    -- Unconscious sound system for isthistheend.mp3
    local unconsciousSound = nil
    local isUnconsciousActive = false
    local unconsciousSoundVolume = 0
    
    -- Function to start unconscious sound
    local function StartUnconsciousSound()
        if unconsciousSound then
            unconsciousSound:Stop()
            unconsciousSound = nil
        end
        
        sound.PlayFile("sound/isthistheend.mp3", "noplay", function(station)
            if IsValid(station) then
                unconsciousSound = station
                station:EnableLooping(true)
                station:SetVolume(unconsciousSoundVolume)
                station:Play()
            end
        end)
    end
    
    -- Function to stop unconscious sound
    local function StopUnconsciousSound()
        if unconsciousSound then
            unconsciousSound:Stop()
            unconsciousSound = nil
        end
        isUnconsciousActive = false
    end
    
    -- Monitor unconscious state and manage sound
    hook.Add("Think", "RADS_UnconsciousSound", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local isUnconscious = ply:GetNWBool("Otrub", false)
        local hp = ply:Health()
        local isDead = hp <= 0
        
        -- Stop sound if player dies
        if isDead and isUnconsciousActive then
            StopUnconsciousSound()
            return
        end
        
        -- Start sound when becoming unconscious
        if isUnconscious and not isUnconsciousActive then
            isUnconsciousActive = true
            -- Calculate volume based on HP (lower HP = higher volume)
            unconsciousSoundVolume = math.Clamp(1.0 - (hp / 100), 0.1, 1.0)
            StartUnconsciousSound()
        end
        
        -- Stop sound when becoming conscious or healed
        if not isUnconscious and isUnconsciousActive then
            StopUnconsciousSound()
        end
        
        -- Update volume based on current HP while unconscious
        if isUnconsciousActive and unconsciousSound then
            local newVolume = math.Clamp(1.0 - (hp / 100), 0.1, 1.0)
            if math.abs(newVolume - unconsciousSoundVolume) > 0.05 then
                unconsciousSoundVolume = newVolume
                unconsciousSound:SetVolume(unconsciousSoundVolume)
            end
        end
    end)

    local brainDmgShakeTimerName = "RADS_BrainShakeLoop"

    -- Tinnitus effect variables
    local TINNITUS_SOUNDS = {
        "tinnitus1.wav",
        "tinnitus2.wav",
        "tinnitus3.wav"
    }
    local tinnitusActive = false
    local tinnitusEndTime = 0
    local nextTinnitusTime = 0
    local tinnitusDuration = 4.5 -- seconds of blur/camera shake after each tinnitus (increased from 2.5)
    local cameraShakeStrength = 18 -- degrees (increased from 8)
    local cameraShakeSpeed = 2.5
    local cameraShakeDecay = 3.5 -- seconds to decay after tinnitus (increased from 1.5)
    local lastTinnitusAngle = Angle(0,0,0)
    local lastTinnitusTime = 0
    -- Helper to trigger tinnitus
    -- Tinnitus sound fade-out variables
    local tinnitusCurrentSound = nil
    local tinnitusFadeOutActive = false
    local tinnitusFadeOutStartTime = 0
    local tinnitusFadeOutDuration = 2.0 -- 2 seconds fade-out
    local tinnitusOriginalVolume = 80
    local tinnitusConfigurableDuration = 10 -- Default 10 seconds as requested
    local tinnitusLoopChannel = nil -- Channel for looping tinnitus sound
    local tinnitusBlurIntensity = 0 -- Current blur intensity for fade-out
    local tinnitusStartTime = 0 -- Track when tinnitus started for continuous shake calculation

    local function TriggerTinnitus(duration)
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        
        -- Use provided duration or default to 10 seconds
        local actualDuration = duration or tinnitusConfigurableDuration
        
        -- Stop any existing tinnitus first
        RemoveTinnitusDummy()
        
        local snd = TINNITUS_SOUNDS[math.random(1, #TINNITUS_SOUNDS)]
        tinnitusCurrentSound = snd
        tinnitusActive = true
        tinnitusEndTime = CurTime() + actualDuration
        tinnitusStartTime = CurTime() -- Track when tinnitus started
        tinnitusBlurIntensity = 1.0 -- Start with full blur intensity
        lastTinnitusTime = CurTime()
        
        -- Create looping sound using sound.PlayFile
        sound.PlayFile("sound/" .. snd, "noplay", function(channel, errorID, errorName)
            if IsValid(channel) then
                tinnitusLoopChannel = channel
                channel:SetVolume(tinnitusOriginalVolume / 100) -- Convert to 0-1 range
                channel:EnableLooping(true)
                channel:Play()
            end
        end)
        
        -- Schedule fade-out to start when duration ends
        timer.Create("RADS_TinnitusFadeOut", actualDuration, 1, function()
            if tinnitusActive and IsValid(LocalPlayer()) then
                StartTinnitusFadeOut()
            end
        end)
        
        -- Randomize shake direction
        lastTinnitusAngle = Angle(math.Rand(-cameraShakeStrength, cameraShakeStrength), math.Rand(-cameraShakeStrength, cameraShakeStrength), 0)
        
        -- Send network message to inform about tinnitus screenshake state
        if SERVER then
            net.Start("RADS_TinnitusScreenshake")
            net.WriteBool(true) -- Tinnitus started
            net.WriteFloat(actualDuration) -- Duration
            net.WriteFloat(cameraShakeStrength) -- Shake strength
            net.Send(ply)
        end
    end

    -- Function to start tinnitus fade-out effect (global to be called by timer)
    function StartTinnitusFadeOut()
        if not tinnitusActive then return end
        
        tinnitusFadeOutActive = true
        tinnitusFadeOutStartTime = CurTime()
        
        -- Capture the current blur intensity at the start of fade-out
        local startingBlurIntensity = tinnitusBlurIntensity
        
        -- Create fade-out timer that updates volume and blur
        timer.Create("RADS_TinnitusFadeOutUpdate", 0.1, math.ceil(tinnitusFadeOutDuration / 0.1), function()
            local ply = LocalPlayer()
            if not IsValid(ply) or not tinnitusFadeOutActive then 
                timer.Remove("RADS_TinnitusFadeOutUpdate")
                return 
            end
            
            local elapsed = CurTime() - tinnitusFadeOutStartTime
            local progress = math.Clamp(elapsed / tinnitusFadeOutDuration, 0, 1)
            local fadeMultiplier = 1 - progress
            
            -- Fade out sound volume
            if IsValid(tinnitusLoopChannel) then
                tinnitusLoopChannel:SetVolume((tinnitusOriginalVolume / 100) * fadeMultiplier)
            end
            
            -- Fade out blur intensity from starting intensity to 0
            tinnitusBlurIntensity = startingBlurIntensity * fadeMultiplier
            
            if progress >= 1 then
                -- Fade-out complete, stop everything
                RemoveTinnitusDummy()
                timer.Remove("RADS_TinnitusFadeOutUpdate")
            end
        end)
    end

    -- Function to properly stop tinnitus (used on death/disconnect)
    function RemoveTinnitusDummy()
        local ply = LocalPlayer()
        if IsValid(ply) and tinnitusCurrentSound then
            ply:StopSound(tinnitusCurrentSound)
        end
        
        -- Stop looping sound channel
        if IsValid(tinnitusLoopChannel) then
            tinnitusLoopChannel:Stop()
            tinnitusLoopChannel = nil
        end
        
        -- Clean up all tinnitus-related timers
        timer.Remove("RADS_TinnitusFadeOut")
        timer.Remove("RADS_TinnitusFadeOutUpdate")
        timer.Remove("RADS_TinnitusTimer")
        
        -- Reset all tinnitus variables
        tinnitusActive = false
        tinnitusEndTime = 0
        tinnitusStartTime = 0
        tinnitusFadeOutActive = false
        tinnitusCurrentSound = nil
        tinnitusBlurIntensity = 0
        
        -- Send network message to inform about tinnitus screenshake stop
        if SERVER then
            net.Start("RADS_TinnitusScreenshake")
            net.WriteBool(false) -- Tinnitus stopped
            net.WriteFloat(0) -- No duration
            net.WriteFloat(0) -- No shake strength
            net.Send(ply)
        end
    end

    -- Network receiver for explosion tinnitus
    net.Receive("RADS_ExplosionTinnitus", function()
        local duration = net.ReadFloat()
        TriggerTinnitus(duration)
    end)

    -- Constant (low) smooth screenshake and blur during brain damage
    local constantShakeStrength = 3 -- degrees (small)
    local constantShakeSpeed = 1.2
    local constantShakeAngle = Angle(0,0,0)
    local constantShakeSeed = math.Rand(0, 1000)

    -- Optimized RenderScreenspaceEffects hook with eye damage blur
    hook.Add("RenderScreenspaceEffects", "RADS_TinnitusBlur", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then 
            currentRadialBlur = 0
            return 
        end
        
        local useCheapEffects = ShouldUseCheapEffects()
        
        -- Eye damage blur effects
        -- Use networked values for reliable client-server synchronization
        local leftEyeHealth = ply:GetNWInt("LeftEyeHealth", ply.Organs and ply.Organs["left_eye"] or 3)
        local rightEyeHealth = ply:GetNWInt("RightEyeHealth", ply.Organs and ply.Organs["right_eye"] or 3)
        local eyeDamageBlur = 0
        
        -- Calculate blur intensity based on eye damage
        if leftEyeHealth <= 0 and rightEyeHealth <= 0 then
            -- Both eyes damaged - severe blur
            eyeDamageBlur = 0.4
        elseif leftEyeHealth <= 0 or rightEyeHealth <= 0 then
            -- One eye damaged - moderate blur
            eyeDamageBlur = 0.2
        end
        
        -- Apply eye damage blur and motion blur
        if eyeDamageBlur > 0 then
            if useCheapEffects then
                DrawMotionBlur(0.08 * eyeDamageBlur, 0.9 * eyeDamageBlur, 0.01)
            else
                -- Use the existing blur material for better quality
                if mat_blur and not mat_blur:IsError() then
                    mat_blur:SetFloat("$c0_x", eyeDamageBlur * 0.6)
                    render.SetMaterial(mat_blur)
                    render.DrawScreenQuad()
                end
                -- Add motion blur on top
                DrawMotionBlur(0.06 * eyeDamageBlur, 0.8 * eyeDamageBlur, 0.008)
            end
        end
        
        -- Tinnitus blur with fade-out (reduce intensity if cheap effects enabled)
        if (tinnitusActive and CurTime() < tinnitusEndTime) or tinnitusFadeOutActive then
            local blurStrength = tinnitusBlurIntensity
            if useCheapEffects then
                DrawMotionBlur(0.05 * blurStrength, 0.8 * blurStrength, 0.005) -- Much lighter blur with fade
            else
                DrawMotionBlur(0.1 * blurStrength, 1 * blurStrength, 0.01) -- Original intensity with fade
            end
        end
        
        -- Adrenaline radial blur (completely disabled if cheap effects enabled)
        if adrenalineActive and adrenalineLevel > 0 then
            currentRadialBlur = Lerp(FrameTime() * adrenalineTransitionSpeed, currentRadialBlur, targetRadialBlur)
            
            if currentRadialBlur > 0.01 and not useCheapEffects then
                DrawAdrenalineRadialBlur(currentRadialBlur)
            end
        else
            -- Faster fade-out when adrenaline is not active
            if currentRadialBlur > 0.01 then
                -- Use faster transition speed for fade-out (3x faster)
                currentRadialBlur = Lerp(FrameTime() * adrenalineTransitionSpeed * 3, currentRadialBlur, 0)
                if currentRadialBlur > 0.01 and not useCheapEffects then
                    DrawAdrenalineRadialBlur(currentRadialBlur)
                else
                    -- Force clear when very close to zero
                    currentRadialBlur = 0
                end
            end
        end
    end)

    -- Add CalcView hook for smooth camera shake (now includes constant shake and adrenaline)
    hook.Add("CalcView", "RADS_TinnitusCameraShake", function(ply, pos, angles, fov)
        -- Don't apply camera effects if player is ragdolled OR if heartbeat is playing
        -- Ragdolled players will have their screenshake handled by the ragdoll calcview system
        if not ply:Alive() or ply:GetNWBool("fake", false) or ply:GetNWBool("radsfa", false) then return end
        
        -- Additional check: don't apply effects if pulse is high (heartbeat playing)
        local pulse = ply.pulse or 70
        if pulse > 95 then return end -- Skip camera effects when heartbeat is active
        
        local shake = Angle(0,0,0)
        if isHemorrhageOverlayActive then
            -- Constant smooth shake
            local t = CurTime() + constantShakeSeed
            constantShakeAngle = Angle(
                math.sin(t * constantShakeSpeed) * constantShakeStrength,
                math.cos(t * constantShakeSpeed * 0.9) * constantShakeStrength,
                0
            )
            shake = shake + constantShakeAngle
        end
        if (tinnitusActive and CurTime() < tinnitusEndTime) or tinnitusFadeOutActive then
            local currentShakeStrength
            
            if tinnitusFadeOutActive then
                -- During fade-out, use fade multiplier to gradually reduce shake to 0
                local elapsed = CurTime() - tinnitusFadeOutStartTime
                local progress = math.Clamp(elapsed / tinnitusFadeOutDuration, 0, 1)
                local fadeMultiplier = 1 - progress
                currentShakeStrength = cameraShakeStrength * fadeMultiplier
            else
                -- During normal tinnitus, gradually reduce shake strength over the duration
                local elapsed = CurTime() - tinnitusStartTime
                local totalDuration = tinnitusEndTime - tinnitusStartTime
                local progress = math.Clamp(elapsed / totalDuration, 0, 1)
                currentShakeStrength = cameraShakeStrength * (1 - progress * 0.7) -- Reduce to 30% by the end
            end
            
            -- Continuous shake with varying frequency
            local t = CurTime()
            local tinnitusShake = Angle(
                math.sin(t * cameraShakeSpeed) * currentShakeStrength,
                math.cos(t * cameraShakeSpeed * 0.8) * currentShakeStrength,
                math.sin(t * cameraShakeSpeed * 0.6) * currentShakeStrength * 0.5
            )
            shake = shake + tinnitusShake
        end
        
            -- REMOVED: Add adrenaline shake with proper fade-out
        --[[
        if adrenalineActive and adrenalineShakeStrength > 0 then
            local t = CurTime() + adrenalineShakeSeed
            local adrenalineShake = Angle(
                math.sin(t * adrenalineShakeSpeed) * adrenalineShakeStrength,
                math.cos(t * adrenalineShakeSpeed * 0.8) * adrenalineShakeStrength,
                0
            )
            shake = shake + adrenalineShake
        elseif adrenalineShakeStrength > 0 then
            -- Fade out shake when adrenaline is not active
            adrenalineShakeStrength = Lerp(FrameTime() * adrenalineTransitionSpeed, adrenalineShakeStrength, 0)
            if adrenalineShakeStrength > 0.1 then
                local t = CurTime() + adrenalineShakeSeed
                local adrenalineShake = Angle(
                    math.sin(t * adrenalineShakeSpeed) * adrenalineShakeStrength,
                    math.cos(t * adrenalineShakeSpeed * 0.8) * adrenalineShakeStrength,
                    0
                )
                shake = shake + adrenalineShake
            end
        end
        ]]
        
        if shake ~= Angle(0,0,0) then
            return {origin = pos, angles = angles + shake, fov = fov}
        end
    end)

    hook.Add("CalcView", "RADS_PainShake", function(ply, pos, angles, fov)
        -- Don't apply camera effects if player is ragdolled OR if heartbeat is playing
        if not ply:Alive() or ply:GetNWBool("fake", false) or ply:GetNWBool("radsfa", false) then return end
        
        -- Additional check: don't apply effects if pulse is high (heartbeat playing)
        local pulse = ply.pulse or 70
        if pulse > 95 then return end -- Skip camera effects when heartbeat is active
        
        local shake = Angle(0,0,0)
        
        -- Pain-based shake (existing code)
        if ply.pain and ply.pain > 0 then
            local shakeIntensity = math.min(ply.pain / 100, 10) -- Cap at 10 degrees
            local t = CurTime()
            shake = Angle(
                math.sin(t * 3) * shakeIntensity,
                math.cos(t * 2.5) * shakeIntensity,
                0
            )
        end
        
        -- REMOVED: Adrenaline shake that was breaking ragdoll camera
        --[[
        if adrenalineActive and adrenalineShakeStrength > 0 and adrenalineLevel > 0 then
            local t = CurTime() + adrenalineShakeSeed
            local adrenalineShake = Angle(
                math.sin(t * adrenalineShakeSpeed) * adrenalineShakeStrength,
                math.cos(t * adrenalineShakeSpeed * 0.8) * adrenalineShakeStrength,
                0
            )
            shake = shake + adrenalineShake
        end
        ]]
        
        if shake ~= Angle(0,0,0) then
            return {origin = pos, angles = angles + shake, fov = fov}
        end
    end)
    
    -- Removed pulse-based FOV hook to prevent ragdoll camera issues

    -- Console command to manually trigger tinnitus
    concommand.Add("rads_starttinnitus", function(ply, cmd, args)
        local duration = tonumber(args[1]) or tinnitusConfigurableDuration
        if duration <= 0 then
            duration = tinnitusConfigurableDuration
        end
        TriggerTinnitus(duration)
        print("Tinnitus triggered for " .. duration .. " seconds")
    end, nil, "Trigger tinnitus effect with optional duration (e.g., rads_starttinnitus 20)")

    -- During brain damage, randomly trigger tinnitus
    local function ScheduleNextTinnitus()
        if not isHemorrhageOverlayActive then return end
        local interval = math.Rand(4, 12)
        nextTinnitusTime = CurTime() + interval
        timer.Create("RADS_TinnitusTimer", interval, 1, function()
            if isHemorrhageOverlayActive then
                TriggerTinnitus()
                ScheduleNextTinnitus()
            end
        end)
    end

    -- Modify net.Receive('RADS_BrainDamageFX') to start tinnitus
    local old_BrainDamageFX = net.Receivers["RADS_BrainDamageFX"]
    net.Receive("RADS_BrainDamageFX", function(len)
        if old_BrainDamageFX then old_BrainDamageFX(len) end
        -- Start tinnitus scheduling
        timer.Remove("RADS_TinnitusTimer")
        ScheduleNextTinnitus()
    end)

    -- Stop tinnitus when brain damage ends
    local old_StopBrainDamageFX = net.Receivers["RADS_StopBrainDamageFX"]
    net.Receive("RADS_StopBrainDamageFX", function(len)
        if old_StopBrainDamageFX then old_StopBrainDamageFX(len) end
        RemoveTinnitusDummy() -- Use new cleanup function
    end)

    net.Receive('RADS_BrainDamageFX', function(len)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local braindmgLoopTimerName = "RADS_BrainDamageLoopSound"
        local braindmgRepeatCounter = 0
        local brainDmgSoundChannel = CHAN_STATIC -- Define a specific channel for the sound

        -- Stop any existing loop first and associated sound
        timer.Remove(braindmgLoopTimerName)
        ply:StopSound("braindamage.wav", brainDmgSoundChannel)
        braindmgRepeatCounter = 0

        local function playBraindmgSound()
            if IsValid(ply) and ply:Alive() and braindmgRepeatCounter < 1000 then
                ply:EmitSound("braindamage.wav", 75, 100, 1, brainDmgSoundChannel) -- Emit braindamage.wav from player
                braindmgRepeatCounter = braindmgRepeatCounter + 1
            else
                timer.Remove(braindmgLoopTimerName)
                ply:StopSound("braindamage.wav", brainDmgSoundChannel) -- Stop the sound when loop finishes
            end
        end

        -- Play initial sound immediately
        playBraindmgSound()
        -- Start timer for subsequent plays
        timer.Create(braindmgLoopTimerName, 4.65, 999, playBraindmgSound) -- 999 more repetitions after the initial one

        -- Stop any existing brain damage sound and shake timers to prevent overlapping effects
        timer.Remove(brainDmgShakeTimerName) -- REMOVE the old constant util.ScreenShake
        
        isHemorrhageOverlayActive = true
        -- Stop any existing flashing timer before starting a new one
        timer.Remove(flashTriggerTimerName)
        TriggerNextFlash() -- Trigger the first flash immediately

        -- REMOVE the old constant screen shake timer
        --[[timer.Create(brainDmgShakeTimerName, 0.1, 0, function()
            if IsValid(ply) and ply:Alive() then -- Check general player validity
                util.ScreenShake(ply:GetPos(), 5, 5, 0.1, 2000)
            else
                timer.Remove(brainDmgShakeTimerName)
            end
        end)]]

        -- Start tinnitus scheduling
        timer.Remove("RADS_TinnitusTimer")
        ScheduleNextTinnitus()

        -- After 50-60 seconds, set player's brain health to 0 and end effect
        timer.Create("RADS_BrainDamageKillTimer", math.Rand(50, 60), 1, function()
            if IsValid(ply) and ply:Alive() then
                -- Set brain health to 0 and notify server
                net.Start("RADS_BrainMeltdownStart")
                net.SendToServer()
            end
        end)
    end)

    net.Receive('RADS_StopBrainDamageFX', function(len)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local braindmgLoopTimerName = "RADS_BrainDamageLoopSound"
        local brainDmgSoundChannel = CHAN_STATIC -- Ensure channel is defined for stopping

        timer.Remove(braindmgLoopTimerName)
        ply:StopSound("braindamage.wav", brainDmgSoundChannel) -- Stop the sound when loop is explicitly stopped

        timer.Remove(brainDmgShakeTimerName)
        timer.Remove(flashTriggerTimerName) -- Stop flashing overlay timer
        isHemorrhageOverlayActive = false
        lastFlashStartTime = 0 -- Reset flash state
        currentFlashDuration = 0 -- Reset flash state

        -- Stop tinnitus
        RemoveTinnitusDummy() -- Use new cleanup function
        -- Stop brain damage kill timer
        timer.Remove("RADS_BrainDamageKillTimer")
    end)

    net.Receive('RADS_BrainDeathSound', function(len)
        local ply = LocalPlayer()
        if IsValid(ply) then
            sound.Play("braindeath.wav", ply:GetPos(), 75, 100, 1) -- Play braindeath.wav on client
        end
    end)

    -- Optimized HUDPaint hooks with reduced calculation frequency
    local lastOverlayUpdate = 0
    local overlayUpdateInterval = 0.016 -- ~60 FPS max
    
    hook.Add("HUDPaint", "DrawBrainHemorrhageOverlay", function()
        if not isHemorrhageOverlayActive then return end
        
        local currentTime = CurTime()
        if currentTime - lastOverlayUpdate < overlayUpdateInterval then return end
        lastOverlayUpdate = currentTime
        
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(BRAIN_HEMORRHAGE_OVERLAY)

        -- Reduce shake intensity if cheap effects enabled
        local shakeIntensity = ShouldUseCheapEffects() and 1 or 2
        local shakeX = math.sin(currentTime * 10) * shakeIntensity
        local shakeY = math.cos(currentTime * 12) * shakeIntensity

        surface.DrawTexturedRect(shakeX, shakeY, ScrW(), ScrH())
    end)

    hook.Add("HUDPaint", "DrawFlashingOverlay", function()
        if not (isHemorrhageOverlayActive and CurTime() < lastFlashStartTime + currentFlashDuration) then return end
        
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(FLASHING_OVERLAYS[flashingOverlayIndex])

        -- Reduce shake intensity if cheap effects enabled
        local shakeIntensity = ShouldUseCheapEffects() and 2 or 5
        local shakeX = math.sin(CurTime() * 20) * shakeIntensity
        local shakeY = math.cos(CurTime() * 25) * shakeIntensity

        surface.DrawTexturedRect(shakeX, shakeY, ScrW(), ScrH())
    end)

    -- Eye overlay sway tracking variables
    local lastViewAngles = Angle(0, 0, 0)
    local eyeOverlayOffset = {x = 0, y = 0}
    local eyeOverlayVelocity = {x = 0, y = 0}
    local lastEyeOverlayUpdate = 0
    local eyeOverlayUpdateInterval = 0.016 -- ~60 FPS
    
    -- Eye loss overlay rendering with camera sway
    hook.Add("HUDPaint", "DrawEyeLossOverlay", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        if ply:GetNWBool("Otrub", false) then return end -- Don't show overlays when unconscious
        
        -- Use networked values for reliable client-server synchronization
        local leftEyeHealth = ply:GetNWInt("LeftEyeHealth", ply.Organs and ply.Organs["left_eye"] or 3)
        local rightEyeHealth = ply:GetNWInt("RightEyeHealth", ply.Organs and ply.Organs["right_eye"] or 3)
        
        -- If both eyes are destroyed, make player blind (like unconscious)
        if leftEyeHealth <= 0 and rightEyeHealth <= 0 then
            -- Draw black screen for complete blindness
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, ScrW(), ScrH())
            return
        end
        
        -- Calculate camera sway for eye overlays
        local currentTime = CurTime()
        if currentTime - lastEyeOverlayUpdate > eyeOverlayUpdateInterval then
            lastEyeOverlayUpdate = currentTime
            
            local currentAngles = ply:EyeAngles()
            local angleDiff = currentAngles - lastViewAngles
            
            -- Normalize angle differences to prevent wrapping issues
            angleDiff.p = math.NormalizeAngle(angleDiff.p)
            angleDiff.y = math.NormalizeAngle(angleDiff.y)
            
            -- Calculate sway based on camera movement (reduced intensity)
            local swayIntensity = 15 -- Reduced from potential higher values
            local targetOffsetX = math.Clamp(angleDiff.y * swayIntensity, -30, 30)
            local targetOffsetY = math.Clamp(-angleDiff.p * swayIntensity, -20, 20)
            
            -- Apply smooth interpolation to the offset
            local lerpSpeed = 8
            eyeOverlayOffset.x = Lerp(FrameTime() * lerpSpeed, eyeOverlayOffset.x, targetOffsetX)
            eyeOverlayOffset.y = Lerp(FrameTime() * lerpSpeed, eyeOverlayOffset.y, targetOffsetY)
            
            -- Add slight decay to make overlays settle
            eyeOverlayOffset.x = eyeOverlayOffset.x * 0.95
            eyeOverlayOffset.y = eyeOverlayOffset.y * 0.95
            
            lastViewAngles = currentAngles
        end
        
        -- Draw individual eye overlays with sway and rapid shaking
        local rapidShakeX = math.random(-8, 8) -- Rapid horizontal shake
        local rapidShakeY = math.random(-6, 6) -- Rapid vertical shake
        
        -- Calculate 25% bigger size
        local overlayWidth = ScrW() * 1.25
        local overlayHeight = ScrH() * 1.25
        
        -- Move overlay left and adjust for larger size to prevent going offscreen
        local leftOffset = -50 -- Move 50 pixels to the left
        local topOffset = -(overlayHeight - ScrH()) / 2 -- Center vertically for larger overlay
        
        if leftEyeHealth <= 0 then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(LEFT_EYE_GONE_OVERLAY)
            surface.DrawTexturedRect(
                eyeOverlayOffset.x + leftOffset + rapidShakeX, 
                eyeOverlayOffset.y + topOffset + rapidShakeY, 
                overlayWidth, 
                overlayHeight
            )
        end
        
        if rightEyeHealth <= 0 then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(RIGHT_EYE_GONE_OVERLAY)
            surface.DrawTexturedRect(
                eyeOverlayOffset.x + leftOffset + rapidShakeX, 
                eyeOverlayOffset.y + topOffset + rapidShakeY, 
                overlayWidth, 
                overlayHeight
            )
        end
    end)

    -- Optimized damage overlay with reduced calculation frequency
    local lastDamageOverlayCalc = 0
    local damageOverlayInterval = 0.033 -- ~30 FPS for damage overlay
    local cachedDamageOverlayAlpha = 0
    local cachedDamageOverlayPos = {x = 0, y = 0}
    
    hook.Add("HUDPaint", "DrawDamageOverlay", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        local isCurrentlyUnconscious = ply:GetNWBool("Otrub", false)
        if isCurrentlyUnconscious and RADS_DamageOverlayFadeStartTime == 0 then return end

        local currentTime = CurTime()
        local shouldRecalculate = currentTime - lastDamageOverlayCalc > damageOverlayInterval
        
        if shouldRecalculate then
            lastDamageOverlayCalc = currentTime
            
            local blood = ply:GetNWInt("PlayerBlood", 0)
            local minBlood = 2900
            local maxBlood = 3800

            local alphaBasedOnBlood = 0
            if blood <= maxBlood and blood >= minBlood then
                alphaBasedOnBlood = math.Remap(blood, maxBlood, minBlood, 0, 255)
            elseif blood < minBlood then
                alphaBasedOnBlood = 255
            end

            cachedDamageOverlayAlpha = alphaBasedOnBlood

            if RADS_DamageOverlayFadeStartTime > 0 then
                local timeElapsed = currentTime - RADS_DamageOverlayFadeStartTime
                if timeElapsed < RADS_DamageOverlayFadeDuration then
                    local fadeProgress = math.Clamp(timeElapsed / RADS_DamageOverlayFadeDuration, 0, 1)
                    local function EaseOutQuad(t) return 1 - (1 - t) * (1 - t) end
                    cachedDamageOverlayAlpha = Lerp(EaseOutQuad(fadeProgress), 0, alphaBasedOnBlood)
                else
                    RADS_DamageOverlayFadeStartTime = 0
                end
            end
            
            -- Cache position calculations
            local useCheapEffects = ShouldUseCheapEffects()
            local scale = 1.1
            local scaledWidth = ScrW() * scale
            local scaledHeight = ScrH() * scale
            local baseX = (ScrW() - scaledWidth) / 2
            local baseY = (ScrH() - scaledHeight) / 2
            
            if useCheapEffects then
                -- No movement when cheap effects enabled
                cachedDamageOverlayPos.x = baseX
                cachedDamageOverlayPos.y = baseY
            else
                -- Reduced movement intensity
                local positionPulseMagnitudeX = 8
                local positionPulseMagnitudeY = 8
                local currentPositionalOffsetX = math.sin(currentTime * 4) * positionPulseMagnitudeX
                local currentPositionalOffsetY = math.cos(currentTime * 3.5) * positionPulseMagnitudeY
                cachedDamageOverlayPos.x = baseX + currentPositionalOffsetX
                cachedDamageOverlayPos.y = baseY + currentPositionalOffsetY
            end
        end

        if cachedDamageOverlayAlpha > 0 then
            -- Reduce transparency pulse if cheap effects enabled
            local transparencyPulseMagnitude = ShouldUseCheapEffects() and 10 or 25
            local transparencyPulseSpeed = ShouldUseCheapEffects() and 3 or 5
            local currentTransparencyOffset = math.sin(currentTime * transparencyPulseSpeed) * transparencyPulseMagnitude
            local finalAlpha = math.Clamp(cachedDamageOverlayAlpha + currentTransparencyOffset, 0, 255)

            surface.SetDrawColor(255, 255, 255, finalAlpha)
            surface.SetMaterial(DAMAGE_OVERLAY)

            local scale = 1.1
            local scaledWidth = ScrW() * scale
            local scaledHeight = ScrH() * scale

            surface.DrawTexturedRect(cachedDamageOverlayPos.x, cachedDamageOverlayPos.y, scaledWidth, scaledHeight)
        end
    end)

    -- Client-side handler for playing lung wheeze sound
    net.Receive('RADS_PlayLungWheeze', function()
        local ply = net.ReadEntity()
        if not IsValid(ply) then return end
        
        -- Determine model/gender
        local model = ply:GetModel() or ""
        local soundToPlay
        if string.find(string.lower(model), "female") or
           string.find(string.lower(model), "alyx") or
           string.find(string.lower(model), "chell") or
           string.find(string.lower(model), "lana") then
            soundToPlay = FEMALE_WHEEZE_SOUNDS[math.random(1, #FEMALE_WHEEZE_SOUNDS)]
        else
            soundToPlay = MALE_WHEEZE_SOUNDS[math.random(1, #MALE_WHEEZE_SOUNDS)]
        end

        -- Determine entity: player or ragdoll
        local ent = ply
        local rag = ply:GetNWEntity("player_ragdoll")
        if IsValid(rag) then
            ent = rag
        end

        -- Play sound as entity sound with short range (50 units)
        ent:EmitSound(soundToPlay, 50, 100, 0.8, CHAN_VOICE)
    end)

    -- Client-side handler for playing agonal breathing sound
    net.Receive('RADS_PlayAgonalBreathing', function()
        local ply = net.ReadEntity()
        if not IsValid(ply) then return end
        
        -- Select random agonal breathing sound
        local soundToPlay = AGONAL_BREATHING_SOUNDS[math.random(1, #AGONAL_BREATHING_SOUNDS)]

        -- Determine entity: player or ragdoll
        local ent = ply
        local rag = ply:GetNWEntity("player_ragdoll")
        if IsValid(rag) then
            ent = rag
        end

        -- Play sound as entity sound with short range (60 units for agonal breathing)
        ent:EmitSound(soundToPlay, 60, 100, 0.9, CHAN_VOICE)
    end)

    -- Client-side handler for stopping agonal breathing
    net.Receive('RADS_StopAgonalBreathing', function()
        local ply = net.ReadEntity()
        if not IsValid(ply) then return end
        
        -- Stop agonal breathing timer
        timer.Remove("RADS_AgonalBreathingTimer_" .. ply:EntIndex())
    end)

    -- Client-side handler for stopping lung effects
    net.Receive('RADS_StopLungFX', function()
        timer.Remove( "RADS_LungWheezeTimer_" .. LocalPlayer():EntIndex() )
    end)

    -- Client-side handler for eye loss shake effect
    net.Receive('RADS_EyeLossShake', function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Don't shake if player is in ragdoll (since it uses calcview)
        if ply:GetNWBool("radsfa", false) then return end
        
        -- Set fear to maximum
        ply:SetNWFloat("FearAMT", 3)
        
        -- Create rapid screen shake for short duration
        local shakeCount = 0
        local maxShakes = 15 -- Number of rapid shakes
        local shakeInterval = 0.05 -- Very fast shaking
        
        timer.Create("RADS_EyeLossRapidShake_" .. ply:EntIndex(), shakeInterval, maxShakes, function()
            if not IsValid(ply) or ply:GetNWBool("radsfa", false) then 
                timer.Remove("RADS_EyeLossRapidShake_" .. ply:EntIndex())
                return 
            end
            
            shakeCount = shakeCount + 1
            local intensity = math.max(0, 8 - (shakeCount * 0.4)) -- Decreasing intensity
            util.ScreenShake(ply:GetPos(), intensity, intensity * 2, 0.1, 1000)
        end)
    end)

    -- New: Client-side PlayerSpawn hook to initialize player blood
    hook.Add("PlayerSpawn", "InitializeClientBlood", function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            -- Ensure client-side blood is initialized to full on spawn.
            -- This value will be overwritten by server updates via info_org.
            ply.Blood = ply.Blood or 5000
        end
    end)

    -- Stop tinnitus sounds when the player dies
    hook.Add("PostPlayerDeath", "StopTinnitusOnDeath", function()
        RemoveTinnitusDummy()
    end)

    -- Stop tinnitus sounds when the player disconnects
    hook.Add("ShutDown", "StopTinnitusOnDisconnect", function()
        RemoveTinnitusDummy()
    end)

    -- Stop adrenaline effects when player dies
    hook.Add("PostPlayerDeath", "RADS_StopAdrenalineOnDeath", function()
        -- Immediately stop adrenaline effects
        adrenalineActive = false
        targetRadialBlur = 0
        currentRadialBlur = 0  -- Immediately clear current blur
        adrenalineShakeStrength = 0
        
        -- Reset heartbeat system
            lastHeartbeatTime = 0
        
        -- Restore hearing immediately
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:ConCommand("soundfade 0 1")
        end
   
    end)

    -- Reset adrenaline variables on client when player spawns
    hook.Add("PlayerSpawn", "RADS_ResetClientAdrenaline", function(ply)
        if ply == LocalPlayer() then
            -- Don't reset adrenaline if player is getting up from ragdoll
            if ply.gettingUpFromRagdoll then
                return
            end
            
            -- Reset all client-side adrenaline variables
            adrenalineLevel = 0
            adrenalineActive = false
            adrenalineEndTime = 0
            adrenalineCooldownEnd = 0
            adrenalineShakeStrength = 0
            adrenalineShakeSeed = math.random(1000, 9999)
            adrenalineShakeSpeed = 8
            currentRadialBlur = 0
            targetRadialBlur = 0
            adrenalineTransitionSpeed = 3.0
            
            -- Reset heartbeat system
            lastHeartbeatTime = 0
            
            -- Stop any adrenaline-related sound fading
            ply:ConCommand("soundfade 0 1")
            

        end
    end)

    -- Fade sound back in on respawn (keep this if you want, or remove if not needed)
    hook.Add("PlayerSpawn", "UnfadeSoundOnSpawn", function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:ConCommand("soundfade 0 1")
        end
    end)

    -- Arm dislocation shake variables
    local leftArmShake = false
    local rightArmShake = false
    local bothArmsShake = false
    local armShakeStrength = 1.5
    local armShakeSpeed = 1.2
    local viewmodelShakeStrength = 0.5
    -- Update shake state from server
    hook.Add("Think", "RADS_ArmDislocationState", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        leftArmShake = ply:GetNWBool("RADS_LeftArmDislocated", false)
        rightArmShake = ply:GetNWBool("RADS_RightArmDislocated", false)
        bothArmsShake = ply:GetNWBool("RADS_BothArmsDislocated", false)
    end)
    -- Viewmodel shake for left/right/both arms
    hook.Add("CalcViewModelView", "RADS_ArmDislocationViewmodelShake", function(wep, vm, oldPos, oldAng, pos, ang)
        if leftArmShake or rightArmShake or bothArmsShake then
            local t = CurTime()
            local strength = viewmodelShakeStrength
            if bothArmsShake then strength = strength * 2 end
            ang:RotateAroundAxis(ang:Right(), math.sin(t * 2) * strength)
            ang:RotateAroundAxis(ang:Up(), math.cos(t * 2.2) * strength)
            return pos, ang
        end
    end)
    -- Block pickup if both arms are dislocated
    hook.Add("AllowPlayerPickup", "RADS_BlockPickupBothArms", function(ply, ent)
        if ply:GetNWBool("RADS_BothArmsDislocated", false) then
            return false
        end
    end)

    -- Thoughts system: store current thought and state
    RADS_Thoughts = RADS_Thoughts or {}
    RADS_CurrentThought = nil
    RADS_ThoughtFadeStart = 0
    RADS_ThoughtFadeDuration = 0.5 -- seconds
    RADS_ThoughtCutShort = false
    RADS_ThoughtScramble = false
    RADS_ThoughtIntensity = 0
    RADS_ThoughtText = ""
    RADS_ThoughtActive = false

    -- Receive a thought from the server
    net.Receive('RADS_AddThought', function()
        local text = net.ReadString()
        local intensity = net.ReadFloat()
        local scramble = net.ReadBool()
        RADS_ThoughtText = text
        RADS_ThoughtFadeStart = CurTime()
        RADS_ThoughtScramble = scramble
        RADS_ThoughtIntensity = intensity
        RADS_ThoughtActive = true
        RADS_ThoughtCutShort = false
    end)

    -- Function to cut short the current thought (for unconsciousness)
    function RADS_CutThoughtShort()
        if RADS_ThoughtActive and not RADS_ThoughtCutShort then
            -- Cut the text at current fade-in progress and add '-'
            local elapsed = CurTime() - RADS_ThoughtFadeStart
            local progress = math.Clamp(elapsed / RADS_ThoughtFadeDuration, 0, 1)
            local cutLen = math.max(1, math.floor(#RADS_ThoughtText * progress))
            RADS_ThoughtText = string.sub(RADS_ThoughtText, 1, cutLen) .. "-"
            RADS_ThoughtCutShort = true
        end
    end

    -- Add HUDPaint hook to draw the current thought
    hook.Add("HUDPaint", "RADS_DrawThought", function()
        local ply = LocalPlayer()
        if not RADS_ThoughtActive or not RADS_ThoughtText or RADS_ThoughtText == "" then return end
        if not IsValid(ply) or ply:GetNWBool("Otrub", false) then return end -- Prevent thoughts when unconscious
        -- Scramble if brain damage FX is active
        if isHemorrhageOverlayActive then
            RADS_ThoughtScramble = true
        else
            RADS_ThoughtScramble = false
        end
        local fadeDuration = RADS_ThoughtFadeDuration or 0.5
        local displayDuration = 3.0 -- seconds to show after fade-in
        local elapsed = CurTime() - (RADS_ThoughtFadeStart or 0)
        local alpha = 255
        if elapsed < fadeDuration then
            alpha = math.Clamp((elapsed / fadeDuration) * 255, 0, 255)
        elseif elapsed > fadeDuration + displayDuration then
            -- Fade out over fadeDuration
            local fadeOutElapsed = elapsed - (fadeDuration + displayDuration)
            alpha = math.Clamp(255 - (fadeOutElapsed / fadeDuration) * 255, 0, 255)
            if alpha <= 0 then
                RADS_ThoughtActive = false
                return
            end
        end
        -- Scramble text if needed
        local text = RADS_ThoughtText
        if RADS_ThoughtScramble then
            local t = {}
            for i = 1, #text do
                t[i] = string.char(math.random(65, 90))
            end
            text = table.concat(t)
        end
        -- Color based on intensity (redder for higher intensity)
        local intensity = RADS_ThoughtIntensity or 0
        local baseColor = Color(255, 255 - intensity * 200, 255 - intensity * 200, alpha)
        surface.SetFont("RADS_ThoughtFont")
        local w, h = surface.GetTextSize(text)
        if not w or not h then w, h = 512, 64 end
        local x = ScrW() / 2
        local y = ScrH() * 0.8
        -- Smooth shake effect
        local shakeMagnitude = 10 -- pixels (subtle)
        local shakeSpeed = 3 -- Hz
        local shakeX = math.sin(CurTime() * shakeSpeed) * shakeMagnitude
        local shakeY = math.cos(CurTime() * shakeSpeed * 0.8) * (shakeMagnitude * 0.7)
        draw.SimpleText(text, "RADS_ThoughtFont", x + shakeX, y + shakeY, baseColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end)

    -- Clear thought on player death
    hook.Add("PostPlayerDeath", "RADS_ClearThoughtOnDeath", function()
        RADS_ThoughtActive = false
        RADS_ThoughtText = ""
    end)

    -- Consciousness-based vignette material (using merc_vignette shader)
    -- REMOVED: Consciousness vignette system - visual effects removed per user request
    
    -- Receive consciousness updates for immediate vignette effect
    net.Receive("RADS_UpdateConsciousness", function()
        local consciousness = net.ReadInt(8)
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:SetNWInt("PlayerConsciousness", consciousness)
            print("[RADS] Consciousness updated to: " .. consciousness .. " (Client-side)")
        end
    end)
    
    -- REMOVED: Consciousness vignette hooks - visual effects removed per user request
end

-- Adrenaline system variables and functions (moved outside SERVER block)
local function InitializeAdrenaline(ply)
    ply.adrenaline = ply.adrenaline or 0
    ply.adrenalineActive = ply.adrenalineActive or false
    ply.adrenalineEndTime = ply.adrenalineEndTime or 0
    ply.adrenalineCooldownEnd = ply.adrenalineCooldownEnd or 0
    ply.adrenalineLastUpdate = ply.adrenalineLastUpdate or 0
    ply.adrenalineLastDamageTime = ply.adrenalineLastDamageTime or 0 -- NEW: Track last damage time
    ply.adrenalineInitialLevel = ply.adrenalineInitialLevel or nil -- NEW: Track initial level for scaling
    ply.adrenalineLastThink = ply.adrenalineLastThink or nil -- NEW: Track last think time
end

function UpdateAdrenaline(ply, damage) -- Changed from 'local function' to 'function' and moved outside SERVER block
    if not IsValid(ply) or not ply:Alive() then return end
    if not SERVER then return end -- Add SERVER check inside the function
    
    InitializeAdrenaline(ply)
    
    local currentTime = CurTime()
    
    -- Generate adrenaline based on damage (extreme damage = more adrenaline)
    if damage and damage > 0 then
        ply.adrenalineLastDamageTime = currentTime -- NEW: Update last damage time
        local adrenalineGain = 0
        
        -- Scale adrenaline gain based on damage amount
        if damage >= 50 then
            adrenalineGain = 40 -- Extreme damage
        elseif damage >= 30 then
            adrenalineGain = 25 -- High damage
        elseif damage >= 15 then
            adrenalineGain = 15 -- Medium damage
        elseif damage >= 5 then
            adrenalineGain = 8 -- Low damage
        else
            adrenalineGain = 3 -- Minimal damage
        end
        
        -- Reduce adrenaline gain if unconscious
        if ply.Otrub then
            adrenalineGain = adrenalineGain * 0.3
        end
        
        -- Don't generate adrenaline during cooldown
        if currentTime < ply.adrenalineCooldownEnd then
            adrenalineGain = adrenalineGain * 0.1
        end
        
        ply.adrenaline = math.min(100, ply.adrenaline + adrenalineGain)
        
        -- NEW: Adrenaline increases pulse
        local pulseIncrease = adrenalineGain * 2 -- 2 pulse points per adrenaline point
        ply.pulse = math.min(200, ply.pulse + pulseIncrease)
    end
    
    -- NEW: Time-based adrenaline decay (starts after 10 seconds without damage)
    if not ply.adrenalineActive and currentTime - ply.adrenalineLastDamageTime > 10 and currentTime - ply.adrenalineLastUpdate > 1 then
        ply.adrenaline = math.max(0, ply.adrenaline - 3) -- Decay 3 points per second after 10s without damage
        ply.adrenalineLastUpdate = currentTime
    end
    
    -- Check if adrenaline should activate (threshold: 5)
    if ply.adrenaline >= 5 and not ply.adrenalineActive and currentTime >= ply.adrenalineCooldownEnd then
        ply.adrenalineActive = true
        ply.adrenalineEndTime = currentTime + 25 -- FIXED: 25 seconds duration (was 60)
        local cooldownDuration = math.random(30, 40) -- Random cooldown between 30-40 seconds
        ply.adrenalineCooldownEnd = ply.adrenalineEndTime + cooldownDuration
        
        -- Store initial adrenaline level for scaling calculations
        ply.adrenalineInitialLevel = ply.adrenaline
        
        -- FIXED: Immediate pain reduction upon activation (up to 400 pain points based on adrenaline level)
        local painReduction = math.min(400, (ply.adrenaline / 100) * 400)
        ply.pain = math.max(0, ply.pain - painReduction)
        
        -- NEW: Significant pulse increase when adrenaline activates
        ply.pulse = math.min(200, ply.pulse + 30)
        
        -- Apply adrenaline benefits based on current level
        local adrenalineMultiplier = ply.adrenaline / 100
        ply:SetRunSpeed(400 * (1 + 0.2 * adrenalineMultiplier)) -- Up to 20% faster
        ply:SetWalkSpeed(200 * (1 + 0.15 * adrenalineMultiplier)) -- Up to 15% faster walk
        
        -- Send to client
        net.Start('RADS_AdrenalineUpdate')
        net.WriteFloat(ply.adrenaline)
        net.WriteBool(true) -- Active
        net.WriteFloat(25) -- FIXED: Duration (was 60)
        net.WriteFloat(cooldownDuration) -- Random cooldown duration
        net.Send(ply)
        
    elseif ply.adrenalineActive and currentTime >= ply.adrenalineEndTime then
        -- End adrenaline
        ply.adrenalineActive = false
        ply.adrenaline = 0
        ply.adrenalineInitialLevel = nil
        
        -- Apply debuffs during cooldown
        ply:SetRunSpeed(400 * 0.85) -- 15% slower than normal
        ply:SetWalkSpeed(200 * 0.9) -- 10% slower than normal
        
        local remainingCooldown = ply.adrenalineCooldownEnd - currentTime
        
        -- Send to client with explicit end signal
        net.Start('RADS_AdrenalineUpdate')
        net.WriteFloat(0) -- Set adrenaline level to 0
        net.WriteBool(false) -- Not active
        net.WriteFloat(0) -- No duration
        net.WriteFloat(remainingCooldown) -- Send remaining cooldown time
        net.Send(ply)
        
        -- Send a second update to ensure effects are cleared
        timer.Simple(0.1, function()
            if IsValid(ply) then
                net.Start('RADS_AdrenalineUpdate')
                net.WriteFloat(0)
                net.WriteBool(false)
                net.WriteFloat(0)
                net.WriteFloat(math.max(0, ply.adrenalineCooldownEnd - CurTime()))
                net.Send(ply)
            end
        end)
        
    elseif currentTime >= ply.adrenalineCooldownEnd and not ply.adrenalineActive then
        -- Restore normal speeds after cooldown
        ply:SetRunSpeed(400) -- Default run speed
        ply:SetWalkSpeed(200) -- Default walk speed
    end
    
    -- REMOVED: Natural adrenaline decay when not active (now handled above with 10s delay)
end

-- NEW: Think hook for gradual adrenaline decay and continuous effects during active state
hook.Add("Think", "RADS_AdrenalineThink", function()
    if not SERVER then return end
    
    local currentTime = CurTime()
    
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        
        InitializeAdrenaline(ply)
        
        -- Only process if adrenaline is active
        if ply.adrenalineActive and currentTime < ply.adrenalineEndTime then
            -- Initialize last think time if not set
            if not ply.adrenalineLastThink then
                ply.adrenalineLastThink = currentTime
            end
            
            local deltaTime = currentTime - ply.adrenalineLastThink
            
            -- Process every 0.5 seconds to avoid excessive calculations
            if deltaTime >= 0.5 then
                -- FIXED: Gradual adrenaline decay during active state (2 points per second)
                local decayAmount = 2 * deltaTime -- 2 points per second
                ply.adrenaline = math.max(0, ply.adrenaline - decayAmount)
                
                -- FIXED: Continuous pain reduction (5 pain per second)
                local painReduction = 5 * deltaTime
                ply.pain = math.max(0, ply.pain - painReduction)
                
                -- FIXED: Scale effects with current adrenaline level
                if ply.adrenalineInitialLevel and ply.adrenalineInitialLevel > 0 then
                    local currentMultiplier = ply.adrenaline / ply.adrenalineInitialLevel
                    
                    -- Update speed based on current adrenaline level
                    ply:SetRunSpeed(400 * (1 + 0.2 * currentMultiplier))
                    ply:SetWalkSpeed(200 * (1 + 0.15 * currentMultiplier))
                end
                
                -- FIXED: Send regular updates to client for proper effect scaling
                net.Start('RADS_AdrenalineUpdate')
                net.WriteFloat(ply.adrenaline)
                net.WriteBool(true) -- Still active
                net.WriteFloat(math.max(0, ply.adrenalineEndTime - currentTime)) -- Remaining duration
                net.WriteFloat(math.max(0, ply.adrenalineCooldownEnd - currentTime)) -- Remaining cooldown
                net.Send(ply)
                
                ply.adrenalineLastThink = currentTime
            end
        else
            -- Reset think timer when not active
            ply.adrenalineLastThink = nil
        end
    end
end)

if SERVER then
    function PlayGlobalWheeze(ply)
        -- Send wheeze sound to all clients via network
        net.Start("RADS_PlayLungWheeze")
        net.WriteEntity(ply)
        net.Broadcast() -- Send to all clients so they can hear it
    end

    -- Function to play agonal breathing
    function PlayAgonalBreathing(ply)
        if not IsValid(ply) then return end
        
        -- Send agonal breathing sound to all clients via network
        net.Start("RADS_PlayAgonalBreathing")
        net.WriteEntity(ply)
        net.Broadcast() -- Send to all clients so they can hear it
    end

    -- Function to stop agonal breathing
    function StopAgonalBreathing(ply)
        if not IsValid(ply) then return end
        
        -- Stop agonal breathing timer
        timer.Remove("RADS_AgonalBreathingTimer_" .. ply:EntIndex())
        
        -- Send stop signal to all clients
        net.Start("RADS_StopAgonalBreathing")
        net.WriteEntity(ply)
        net.Broadcast()
    end

    -- Function to check if agonal breathing should trigger
    function CheckAgonalBreathing(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if ply.agonalBreathingActive then return end -- Already active
        
        -- Check critical conditions for agonal breathing
        local shouldTrigger = false
        
        -- Brain damage ≤ 2
        if ply.Organs and ply.Organs['brain'] and ply.Organs['brain'] <= 2 then
            shouldTrigger = true
        end
        
        -- Heart damage ≤ 1
        if ply.Organs and ply.Organs['heart'] and ply.Organs['heart'] <= 1 then
            shouldTrigger = true
        end
        
        -- Blood ≤ 1000
        if ply.Blood and ply.Blood <= 2350 then
            shouldTrigger = true
        end
        
        -- Oxygen ≤ 10
        if ply.oxygen and ply.oxygen <= 10 then
            shouldTrigger = true
        end
    
        
        if shouldTrigger then
            StartAgonalBreathing(ply)
        end
    end

    -- Function to start agonal breathing
    function StartAgonalBreathing(ply)
        if not IsValid(ply) or ply.agonalBreathingActive then return end
        
        ply.agonalBreathingActive = true
        
        -- Play first agonal breathing sound immediately
        PlayAgonalBreathing(ply)
        
        -- Set up timer for repeated agonal breathing sounds
        local function playAgonalSound()
            if IsValid(ply) and ply:Alive() and ply.agonalBreathingActive then
                PlayAgonalBreathing(ply)
                -- Random interval between 8-15 seconds for agonal breathing
                timer.Create("RADS_AgonalBreathingTimer_" .. ply:EntIndex(), math.Rand(8, 15), 1, playAgonalSound)
            else
                ply.agonalBreathingActive = false
                timer.Remove("RADS_AgonalBreathingTimer_" .. ply:EntIndex())
            end
        end
        
        -- Start the timer for the next sound
        timer.Create("RADS_AgonalBreathingTimer_" .. ply:EntIndex(), math.Rand(8, 15), 1, playAgonalSound)
    end
    
    -- Pulse recovery timer
    timer.Create("RADS_PulseRecovery", 2, 0, function() -- Changed from 10 to 2 seconds
        for _, ply in pairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                if not ply.pulse then ply.pulse = 70 end
                
                -- Gradually reduce pulse towards resting rate (70 BPM)
                local restingPulse = 70
                if ply.pulse > restingPulse then
                    local recoveryRate = 3 -- Increased from 0.5 to 3
                    if ply.pulse > 150 then
                        recoveryRate = 5 -- Increased from 1 to 5
                    elseif ply.pulse > 120 then
                        recoveryRate = 4 -- Increased from 0.75 to 4
                    end
                    
                    -- Less harsh penalties for pain and bleeding
                    if ply.pain and ply.pain > 100 then
                        recoveryRate = recoveryRate * 0.7 -- Changed from 0.3 to 0.7
                    end
                    if ply.IsBleeding then
                        recoveryRate = recoveryRate * 0.8 -- Changed from 0.5 to 0.8
                    end
                    
                    ply.pulse = math.max(restingPulse, ply.pulse - recoveryRate)
                    
                    -- Ensure pulse is networked to client for heartbeat sound
                    ply:SetNWInt("PlayerPulse", ply.pulse)
                end
            end
        end
    end)
    
    -- Hook into damage system
    hook.Add("EntityTakeDamage", "RADS_AdrenalineSystem", function(target, dmginfo)
        if target:IsPlayer() and dmginfo:GetDamage() > 0 then
            UpdateAdrenaline(target, dmginfo:GetDamage())
        end
    end)
    

    
    -- Initialize adrenaline on spawn
    hook.Add("PlayerSpawn", "RADS_AdrenalineInit", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) then
                -- Don't reset adrenaline if player is getting up from ragdoll
                if ply.gettingUpFromRagdoll then
                    return
                end
                
                -- Force reset all adrenaline values on spawn
                ply.adrenaline = 0
                ply.adrenalineActive = false
                ply.adrenalineEndTime = 0
                ply.adrenalineCooldownEnd = 0
                ply.adrenalineLastUpdate = 0
                ply.adrenalineLastDamageTime = 0
                
                ply:SetRunSpeed(400) -- Reset to default
                ply:SetWalkSpeed(200) -- Reset to default
                
                -- Send immediate reset to client
                net.Start('RADS_AdrenalineUpdate')
                net.WriteFloat(0)
                net.WriteBool(false)
                net.WriteFloat(0)
                net.WriteFloat(0)
                net.Send(ply)
            end
        end)
    end)
    

    
    -- Adrenaline reduces bleeding
    local oldRADS_Bleed = RADS_Bleed
    function RADS_Bleed(ent)
        if oldRADS_Bleed then
            -- Modify bleeding rate based on adrenaline
            if ent:IsPlayer() and ent.adrenalineActive then
                -- Temporarily reduce bleeding during adrenaline
                local oldBlood = ent.Blood
                ent.Blood = ent.Blood * 1.3 -- Effectively reduce bleeding rate
                oldRADS_Bleed(ent)
                ent.Blood = oldBlood
            else
                oldRADS_Bleed(ent)
            end
        end
    end
end

function RADS_SendINFO(ply)
    if not IsValid(ply) then return end
    
    net.Start("info_org")
    net.WriteTable({
        pain = ply.pain or 0,
        painlosing = ply.painlosing or false,
        organs = ply.Organs,
        pulse = ply.pulse or 70
    })
    net.Send(ply)
end

function RADS_Bleed(ent)
    table.insert(BleedingEntities, ent)
end

hook.Add("HomigradDamage", tostring(math.random(9999, 99999)), function(ply, hitGroup, dmginfo, rag)
    if dmginfo:GetAttacker():IsRagdoll() then return end
    
    -- Enhanced pain multiplier system based on damage types and hit location
    local pain_multiplier = 0.25 -- Significantly reduced from 1.1 to 0.25
    local is_head_hit = (hitGroup == HITGROUP_HEAD)
    
    -- Trigger concussion effects for head hits with significant damage (MADE EASIER TO TRIGGER)
    if is_head_hit and dmginfo:GetDamage() > 8 then -- Reduced from 15 to 8
        local shouldTriggerConcussion = false
        local concussionIntensity = 1.0
        
        -- Check damage types that can cause concussion (ADJUSTED FOR MAX INTENSITY 1.0)
        if dmginfo:IsDamageType(DMG_BULLET) then
            shouldTriggerConcussion = true
            concussionIntensity = math.min(dmginfo:GetDamage() / 50, 1.0) -- Capped at 1.0
        elseif dmginfo:IsDamageType(DMG_CLUB) then
            shouldTriggerConcussion = true
            concussionIntensity = math.min(dmginfo:GetDamage() / 40, 1.0) -- Capped at 1.0
        elseif dmginfo:IsDamageType(DMG_SLASH) and dmginfo:GetDamage() > 20 then
            shouldTriggerConcussion = true
            concussionIntensity = math.min(dmginfo:GetDamage() / 60, 1.0) -- Capped at 1.0
        elseif dmginfo:IsDamageType(DMG_BLAST) then
            shouldTriggerConcussion = true
            concussionIntensity = math.min(dmginfo:GetDamage() / 30, 1.0) -- Capped at 1.0
        elseif dmginfo:IsDamageType(DMG_BUCKSHOT) then
            shouldTriggerConcussion = true
            concussionIntensity = math.min(dmginfo:GetDamage() / 45, 1.0) -- Capped at 1.0
        elseif dmginfo:IsDamageType(DMG_CRUSH) then
            shouldTriggerConcussion = true
            concussionIntensity = math.min(dmginfo:GetDamage() / 50, 1.0) -- Capped at 1.0
        elseif dmginfo:IsDamageType(DMG_FALL) and dmginfo:GetDamage() > 25 then
            shouldTriggerConcussion = true
            concussionIntensity = math.min(dmginfo:GetDamage() / 80, 1.0) -- Capped at 1.0
        end
        
        -- FALLBACK: Trigger concussion on skull damage
        if not shouldTriggerConcussion and ply.Organs and ply.Organs['skull'] then
            local skullHealth = ply.Organs['skull']
            if skullHealth <= 15 and dmginfo:GetDamage() > 5 then
                shouldTriggerConcussion = true
                concussionIntensity = math.min((25 - skullHealth) / 25, 1.0) -- Capped at 1.0
            end
        end
        
        -- ADDITIONAL FALLBACK: Random chance for any head hit above 5 damage
        if not shouldTriggerConcussion and dmginfo:GetDamage() > 5 and math.random() < 0.15 then
            shouldTriggerConcussion = true
            concussionIntensity = math.min(dmginfo:GetDamage() / 60, 1.0) -- Capped at 1.0
        end
        
        if shouldTriggerConcussion and IsValid(ply) and ply:Alive() then
            -- Store concussion data on player for consciousness loss
            ply.concussionActive = true
            ply.concussionIntensity = concussionIntensity
            ply.concussionEndTime = CurTime() + (8 * concussionIntensity)
            
            -- Send concussion effect to client
            net.Start('RADS_TriggerConcussion')
            net.WriteFloat(concussionIntensity)
            net.Send(ply)
        end
    end
    
    -- Apply specific multipliers for different damage types (significantly reduced)
    if dmginfo:IsDamageType(DMG_BULLET) then
        pain_multiplier = is_head_hit and 0.35 or 0.25 -- Further reduced by 40%
    elseif dmginfo:IsDamageType(DMG_CLUB) then
        pain_multiplier = is_head_hit and 0.5 or 0.35 -- Further reduced by 40%
    elseif dmginfo:IsDamageType(DMG_SLASH) then
        pain_multiplier = is_head_hit and 0.4 or 0.3 -- Further reduced by 40%
    elseif dmginfo:IsDamageType(DMG_BLAST) then
        pain_multiplier = is_head_hit and 0.5 or 0.35 -- Further reduced by 40%
    elseif dmginfo:IsDamageType(DMG_BUCKSHOT) then
        pain_multiplier = is_head_hit and 0.4 or 0.3 -- Further reduced by 40%
    elseif dmginfo:IsDamageType(DMG_CRUSH) then
        pain_multiplier = is_head_hit and 0.55 or 0.35 -- Further reduced by 40%
    end
    
    local dmg = dmginfo:GetDamage()
    
    -- FIXED: Blood shutdown system - directly trigger unconsciousness when blood drops below limit
    local bloodLimit = GetConVar("rads_bloodlimit"):GetInt()
    if ply.Blood < bloodLimit and not ply.Otrub then
        -- Set player as comatose (non-consciousness based unconsciousness)
        ply.Otrub = true
        ply.consciousnessBasedUnconscious = false -- Mark as non-consciousness based
        ply.consciousness = 0 -- Set consciousness to 0 for comatose state
        ply:SetNWBool("Otrub", true)
        ply:SetNWInt("PlayerConsciousness", 0)
        ply.gotuncon = true
        
        if SERVER then
            net.Start("RADS_PlayerUnconscious")
            net.WriteBool(true)
            net.Send(ply)
            net.Start("RADS_SetHearingState")
            net.WriteBool(true)
            net.Send(ply)
        end
        
        print("[RADS] Player " .. ply:Name() .. " went comatose due to blood loss (" .. ply.Blood .. "/" .. bloodLimit .. ")")
    end
    
    -- Other unconsciousness triggers (pain, etc.)
    if ply.painlosing > 10 or ply.pain > GetConVar("rads_painlimit"):GetInt() then
        if not ply.Otrub then
            ply.gotuncon = true
        end
    end

    if dmginfo:IsDamageType(DMG_CLUB + DMG_GENERIC) then dmginfo:ScaleDamage((IsValid(wep) and wep.GetBlocking and not wep:GetBlocking()) and 1 or 0.75) end
    if dmginfo:IsDamageType(DMG_CRUSH) then
        dmginfo:ScaleDamage(GetConVar("rads_scalefalldmg"):GetFloat())
        dmg = dmg * GetConVar("rads_scalefalldmg"):GetFloat()
    end

    dmg = (dmg / ply.painlosing) * pain_multiplier -- Apply the damage-type and location-specific pain multiplier
    
    -- NEW: Realistic Pain System - Initialize tracking variables
    ply.damageHistory = ply.damageHistory or {}
    ply.painDebt = ply.painDebt or 0
    ply.lastDamageTime = ply.lastDamageTime or 0
    ply.recentDamageCount = ply.recentDamageCount or 0
    ply.totalRecentDamage = ply.totalRecentDamage or 0
    
    local currentTime = CurTime()
    local timeSinceLastDamage = currentTime - ply.lastDamageTime
    
    -- Reset recent damage tracking if enough time has passed (3 seconds)
    if timeSinceLastDamage > 3 then
        ply.recentDamageCount = 0
        ply.totalRecentDamage = 0
        ply.damageHistory = {}
    end
    
    -- Track this damage instance
    ply.lastDamageTime = currentTime
    ply.recentDamageCount = ply.recentDamageCount + 1
    ply.totalRecentDamage = ply.totalRecentDamage + dmg
    table.insert(ply.damageHistory, {damage = dmg, time = currentTime, type = dmginfo:GetDamageType()})
    
    -- Clean old damage history (keep only last 5 seconds)
    for i = #ply.damageHistory, 1, -1 do
        if currentTime - ply.damageHistory[i].time > 5 then
            table.remove(ply.damageHistory, i)
        end
    end
    
    -- Determine if this should cause instant pain
    local instantPain = 0
    local shouldCauseInstantPain = false
    
    -- Instant pain conditions (significantly reduced thresholds and percentages):
    -- 1. Very high single damage (shotgun blast, explosion)
    if dmg >= 150 then -- Increased threshold from 80 to 150
        shouldCauseInstantPain = true
        instantPain = dmg * 0.2 -- Further reduced from 30% to 20% of damage as instant pain
    -- 2. Repetitive damage (constant stabbing, multiple hits)
    elseif ply.recentDamageCount >= 5 and timeSinceLastDamage < 2 then -- Increased from 3 to 5 hits
        shouldCauseInstantPain = true
        instantPain = dmg * 0.12 -- Further reduced from 20% to 12% of damage as instant pain
    -- 3. High damage types that should hurt immediately
    elseif (dmginfo:IsDamageType(DMG_BLAST) and dmg >= 80) or -- Increased from 40 to 80
           (dmginfo:IsDamageType(DMG_BUCKSHOT) and dmg >= 100) or -- Increased from 50 to 100
           (dmginfo:IsDamageType(DMG_CRUSH) and dmg >= 120) then -- Increased from 60 to 120
        shouldCauseInstantPain = true
        instantPain = dmg * 0.15 -- Further reduced from 25% to 15% of damage as instant pain
    -- 4. Accumulated recent damage threshold
    elseif ply.totalRecentDamage >= 200 then -- Increased from 120 to 200
        shouldCauseInstantPain = true
        instantPain = dmg * 0.1 -- Further reduced from 15% to 10% of damage as instant pain
    end
    
    -- Apply adrenaline reduction to instant pain
    if shouldCauseInstantPain and ply.adrenalineActive and ply.adrenaline then
        local adrenalineReduction = (ply.adrenaline / 100) * 0.6 -- Up to 60% reduction
        instantPain = instantPain * (1 - adrenalineReduction)
    end
    
    -- Add instant pain immediately
    if shouldCauseInstantPain then
        ply.pain = ply.pain + instantPain
        -- Remaining damage goes to pain debt
        local remainingDamage = dmg - instantPain
        ply.painDebt = ply.painDebt + remainingDamage
    else
        -- All damage goes to pain debt for gradual application
        ply.painDebt = ply.painDebt + dmg
    end
    
    -- Apply adrenaline reduction to pain debt accumulation
    if ply.adrenalineActive and ply.adrenaline then
        local adrenalineDebtReduction = (ply.adrenaline / 100) * 0.4 -- Up to 40% reduction
        ply.painDebt = ply.painDebt * (1 - adrenalineDebtReduction)
    end
    
    -- Initialize pain debt timer if not already running
    if not timer.Exists("pain_debt_" .. ply:EntIndex()) and IsValid(ply) and ply:Alive() then
        timer.Create("pain_debt_" .. ply:EntIndex(), 0.2, 0, function() -- 0.2 second intervals
            if not IsValid(ply) or not ply:Alive() then
                timer.Remove("pain_debt_" .. ply:EntIndex())
                return
            end
            
            if ply.painDebt and ply.painDebt > 0 then
                -- Calculate pain debt application rate (much slower for gradual buildup)
                local debtRate = math.max(ply.painDebt * 0.015, 0.5) -- Reduced from 3% to 1.5% of debt per tick, minimum 0.5
                
                -- Apply adrenaline reduction to debt application rate
                if ply.adrenalineActive and ply.adrenaline then
                    local adrenalineRateReduction = (ply.adrenaline / 100) * 0.5 -- Up to 50% slower
                    debtRate = debtRate * (1 - adrenalineRateReduction)
                end
                
                local painToAdd = math.min(debtRate, ply.painDebt)
                ply.pain = ply.pain + painToAdd
                ply.painDebt = ply.painDebt - painToAdd
                
                -- Remove timer when no more pain debt
                if ply.painDebt <= 0.1 then
                    ply.painDebt = 0
                    timer.Remove("pain_debt_" .. ply:EntIndex())
                end
            else
                timer.Remove("pain_debt_" .. ply:EntIndex())
            end
        end)
    end
    
    ply.cock = ply.pain / 50
    if GetConVar("rads_adjusttimer"):GetBool() then
        if timer.Exists("radstimer" .. ply:EntIndex()) and ply.fake then
            timer.Adjust("radstimer" .. ply:EntIndex(), ply.cock, nil, nil)
        else
            timer.Create("radstimer" .. ply:EntIndex(), ply.cock, 1, function() end)
        end
    end
end)

concommand.Add("getcd", function(ply) ply:ChatPrint(timer.TimeLeft("radstimer" .. ply:EntIndex()) or "lol") end)

-- Console commands for testing consciousness system
concommand.Add("rads_setconsciousness", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local value = tonumber(args[1]) or 100
    value = math.Clamp(value, 0, 100)
    ply.consciousness = value
    ply:SetNWInt("PlayerConsciousness", math.floor(ply.consciousness))
    
    -- FIXED: Force update consciousness effect on client immediately
    if SERVER then
        net.Start("RADS_UpdateConsciousness")
        net.WriteInt(math.floor(ply.consciousness), 8)
        net.Send(ply)
    end
    
    ply:ChatPrint("Consciousness set to: " .. value .. " (Vignette should now be visible if below 90)")
end)

concommand.Add("rads_getconsciousness", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local consciousness = ply.consciousness or 100
    local isUnconscious = ply.Otrub and "Yes" or "No"
    ply:ChatPrint("Consciousness: " .. consciousness .. " | Unconscious: " .. isUnconscious)
end)
local empty = {}
hook.Add("Player Think", "oopsie", function(ply, time)
    if not ply:Alive() or (ply.painNext or time) > time or ply:HasGodMode() then return end
    ply.painNext = time + 0.1
    if ply.pain >= 1500 then
        ply.pain = 1200 -- Set pain to 1200 instead of unconsciousness
        return
    end
    
    -- NEW: Adrenaline-based pain recovery (reduced rates)
    local painRecovery = 0.5 -- Increased base recovery rate from 0.3 to 0.5
    if ply.adrenalineActive and ply.adrenaline then
        -- Faster recovery based on adrenaline level (up to 2x faster at max adrenaline)
        local adrenalineMultiplier = 1 + ((ply.adrenaline / 100) * 1) -- Reduced from 2x to 1x multiplier (1x to 2x total)
        painRecovery = painRecovery * adrenalineMultiplier
    end
    
    -- NEW: 5x faster pain recovery when unconscious (otrub)
    if ply.Otrub then
        painRecovery = painRecovery * 3
    end
    
    ply.pain = math.max(ply.pain - painRecovery, 0)
    ply.painlosing = math.max(ply.painlosing - 0.1, 1)
    if ply.painNextNet <= time then
        ply.painNextNet = time + 0.25
        net.Start("info_pain")
        net.WriteFloat(ply.pain)
        net.WriteFloat(ply.painlosing)
        net.Send(ply)
        -- RADS_SendINFO(ply) -- Removed: Will update NWInt directly for blood
    end

    -- New: Update player blood NWInt periodically
    ply:SetNWInt("PlayerBlood", ply.Blood)

    -- Artery blood spurt effect (player and ragdoll)
    if ply.Organs and ply.Organs['artery'] ~= nil then
        ply._lastArtery = ply._lastArtery or ply.Organs['artery']
        if ply.Organs['artery'] <= 0 and (not ply.ArteryBursting) then
            ply.ArteryBursting = true
            timer.Create("artery_burst_" .. ply:EntIndex(), 0.1, 0, function()
                if IsValid(ply) and ply:Alive() and ply.ArteryBursting and ply.Organs and ply.Organs['artery'] <= 0 then
                    local boneId = ply:LookupBone("ValveBiped.Bip01_Neck1")
                    if boneId then
                        local bonePos, boneAng = ply:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local pos = bonePos
                            local ang = boneAng
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 90 + randomizedAng:Up() * -50
                            pos = pos + vel:GetNormalized() * 5
                            -- Use blood particle system
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                ply.Blood = math.max((ply.Blood or 0) - 35, 0)
                            end
                        end
                    else
                        -- Fallback if neck bone not found
                        local pos = ply:GetPos() + Vector(0,0,60)
                        local ang = ply:EyeAngles()
                        -- Add randomness to blood spurt angle
                        local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                        local randomizedAng = ang + randomAngle
                        local vel = randomizedAng:Forward() * 90 + randomizedAng:Up() * -50
                        -- Use blood particle system
                        if BloodParticle then
                            BloodParticle(pos, vel)
                            ply.Blood = math.max((ply.Blood or 0) - 35, 0)
                        end
                    end
                elseif IsValid(ply) and (not ply:Alive()) and ply.ArteryBursting and ply.Organs and ply.Organs['artery'] <= 0 then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local boneId = rag:LookupBone("ValveBiped.Bip01_Neck1")
                        if boneId then
                            local pos
                            local ang
                            local phys = rag:GetPhysicsObjectNum(boneId)
                            if IsValid(phys) then
                                pos = phys:GetPos()
                                ang = phys:GetAngles()
                            else
                                local bonePos, boneAng = rag:GetBonePosition(boneId)
                                pos = bonePos
                                ang = boneAng
                            end

                            if pos and ang then
                                -- Add randomness to blood spurt angle
                                local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                                local randomizedAng = ang + randomAngle
                                local vel = randomizedAng:Forward() * 90 + randomizedAng:Up() * -50
                                pos = pos + vel:GetNormalized() * 5
                                -- Use blood particle system
                                if BloodParticle then
                                    BloodParticle(pos, vel)
                                    rag.Blood = math.max((rag.Blood or 0) - 35, 0)
                                end
                            end
                        else
                            -- Fallback if neck bone not found for ragdoll
                            local pos = rag:GetPos() + Vector(0,0,60)
                            local ang = rag:GetAngles()
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 90 + randomizedAng:Up() * -50
                            -- Use blood particle system
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                rag.Blood = math.max((rag.Blood or 0) - 35, 0)
                            end
                        end
                    end
                else
                    timer.Remove("artery_burst_" .. ply:EntIndex())
                    ply.ArteryBursting = false
                end
            end)
        elseif ply.Organs['artery'] > 0 and ply.ArteryBursting then
            ply.ArteryBursting = false
            timer.Remove("artery_burst_" .. ply:EntIndex())
        end
        ply._lastArtery = ply.Organs['artery']
    end

    -- Radial Artery Left blood spurt effect (player and ragdoll)
    if ply.Organs and ply.Organs['radial_artery_l'] ~= nil then
        ply._lastRadialArteryL = ply._lastRadialArteryL or ply.Organs['radial_artery_l']
        if ply.Organs['radial_artery_l'] <= 0 and (not ply.RadialArteryLBursting) then
            ply.RadialArteryLBursting = true
            timer.Create("radial_artery_l_burst_" .. ply:EntIndex(), 0.1, 0, function()
                if IsValid(ply) and ply:Alive() and ply.RadialArteryLBursting and ply.Organs and ply.Organs['radial_artery_l'] <= 0 then
                    local boneId = ply:LookupBone("ValveBiped.Bip01_L_Hand")
                    if boneId then
                        local bonePos, boneAng = ply:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local pos = bonePos
                            local ang = boneAng
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                            pos = pos + vel:GetNormalized() * 5
                            -- Use blood particle system
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                ply.Blood = math.max((ply.Blood or 0) - 15, 0) -- Less blood loss
                            end
                        end
                    else
                        -- Fallback for left wrist (player)
                        local pos = ply:GetPos() + Vector(-15, -10, 45) -- Approx left wrist position
                        local ang = ply:GetAngles()
                        -- Add randomness to blood spurt angle
                        local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                        local randomizedAng = ang + randomAngle
                        local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                        -- Use blood particle system
                        if BloodParticle then
                            BloodParticle(pos, vel)
                            ply.Blood = math.max((ply.Blood or 0) - 15, 0)
                        end
                    end
                elseif IsValid(ply) and (not ply:Alive()) and ply.RadialArteryLBursting and ply.Organs and ply.Organs['radial_artery_l'] <= 0 then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local boneId = rag:LookupBone("ValveBiped.Bip01_L_Hand")
                        if boneId then
                            local pos
                            local ang
                            local phys = rag:GetPhysicsObjectNum(boneId)
                            if IsValid(phys) then
                                pos = phys:GetPos()
                                ang = phys:GetAngles()
                            else
                                local bonePos, boneAng = rag:GetBonePosition(boneId)
                                pos = bonePos
                                ang = boneAng
                            end

                            if pos and ang then
                                -- Add randomness to blood spurt angle
                                local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                                local randomizedAng = ang + randomAngle
                                local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                                pos = pos + vel:GetNormalized() * 5
                                -- Use blood particle system
                                if BloodParticle then
                                    BloodParticle(pos, vel)
                                    rag.Blood = math.max((rag.Blood or 0) - 15, 0)
                                end
                            end
                        else
                            -- Fallback for left wrist (ragdoll)
                            local pos = rag:GetPos() + Vector(-15, -10, 45) -- Approx left wrist position for ragdoll
                            local ang = rag:GetAngles()
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                            -- Use blood particle system
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                rag.Blood = math.max((rag.Blood or 0) - 15, 0)
                            end
                        end
                    end
                else
                    timer.Remove("radial_artery_l_burst_" .. ply:EntIndex())
                    ply.RadialArteryLBursting = false
                end
            end)
        elseif ply.Organs['radial_artery_l'] > 0 and ply.RadialArteryLBursting then
            ply.RadialArteryLBursting = false
            timer.Remove("radial_artery_l_burst_" .. ply:EntIndex())
        end
        ply._lastRadialArteryL = ply.Organs['radial_artery_l']
    end

    -- Radial Artery Right blood spurt effect (player and ragdoll)
    if ply.Organs and ply.Organs['radial_artery_r'] ~= nil then
        ply._lastRadialArteryR = ply._lastRadialArteryR or ply.Organs['radial_artery_r']
        if ply.Organs['radial_artery_r'] <= 0 and (not ply.RadialArteryRBursting) then
            ply.RadialArteryRBursting = true
            timer.Create("radial_artery_r_burst_" .. ply:EntIndex(), 0.1, 0, function()
                if IsValid(ply) and ply:Alive() and ply.RadialArteryRBursting and ply.Organs and ply.Organs['radial_artery_r'] <= 0 then
                    local boneId = ply:LookupBone("ValveBiped.Bip01_R_Hand")
                    if boneId then
                        local bonePos, boneAng = ply:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local pos = bonePos
                            local ang = boneAng
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                            pos = pos + vel:GetNormalized() * 5
                            -- Use blood particle system
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                ply.Blood = math.max((ply.Blood or 0) - 15, 0)
                            end
                        end
                    else
                        -- Fallback for right wrist (player)
                        local pos = ply:GetPos() + ply:GetAngles():Right() * 15 + ply:GetAngles():Forward() * 5 + ply:GetAngles():Up() * 45
                        local ang = ply:GetAngles()
                        -- Add randomness to blood spurt angle
                        local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                        local randomizedAng = ang + randomAngle
                        local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                        -- Use blood particle system
                        if BloodParticle then
                            BloodParticle(pos, vel)
                            ply.Blood = math.max((ply.Blood or 0) - 15, 0)
                        end
                    end
                elseif IsValid(ply) and (not ply:Alive()) and ply.RadialArteryRBursting and ply.Organs and ply.Organs['radial_artery_r'] <= 0 then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local boneId = rag:LookupBone("ValveBiped.Bip01_R_Hand")
                        if boneId then
                            local pos
                            local ang
                            local phys = rag:GetPhysicsObjectNum(boneId)
                            if IsValid(phys) then
                                pos = phys:GetPos()
                                ang = phys:GetAngles()
                            else
                                local bonePos, boneAng = rag:GetBonePosition(boneId)
                                pos = bonePos
                                ang = boneAng
                            end

                            if pos and ang then
                                -- Add randomness to blood spurt angle
                                local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                                local randomizedAng = ang + randomAngle
                                local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                                pos = pos + vel:GetNormalized() * 5
                                -- Use blood particle system
                                if BloodParticle then
                                    BloodParticle(pos, vel)
                                    rag.Blood = math.max((rag.Blood or 0) - 15, 0)
                                end
                            end
                        else
                            -- Fallback for right wrist (ragdoll)
                            local pos = rag:GetPos() + rag:GetAngles():Right() * 15 + rag:GetAngles():Forward() * 5 + rag:GetAngles():Up() * 45
                            local ang = rag:GetAngles()
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                rag.Blood = math.max((rag.Blood or 0) - 15, 0)
                            end
                        end
                    end
                else
                    timer.Remove("radial_artery_r_burst_" .. ply:EntIndex())
                    ply.RadialArteryRBursting = false
                end
            end)
        elseif ply.Organs['radial_artery_r'] > 0 and ply.RadialArteryRBursting then
            ply.RadialArteryRBursting = false
            timer.Remove("radial_artery_r_burst_" .. ply:EntIndex())
        end
        ply._lastRadialArteryR = ply.Organs['radial_artery_r']
    end

    -- Femoral Artery Left blood spurt effect (player and ragdoll)
    if ply.Organs and ply.Organs['femoral_artery_l'] ~= nil then
        ply._lastFemoralArteryL = ply._lastFemoralArteryL or ply.Organs['femoral_artery_l']
        if ply.Organs['femoral_artery_l'] <= 0 and (not ply.FemoralArteryLBursting) then
            ply.FemoralArteryLBursting = true
            timer.Create("femoral_artery_l_burst_" .. ply:EntIndex(), 0.1, 0, function()
                if IsValid(ply) and ply:Alive() and ply.FemoralArteryLBursting and ply.Organs and ply.Organs['femoral_artery_l'] <= 0 then
                    local boneId = ply:LookupBone("ValveBiped.Bip01_L_Thigh")
                    if boneId then
                        local bonePos, boneAng = ply:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local pos = bonePos
                            local ang = boneAng
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 60 + randomizedAng:Up() * -30
                            pos = pos + vel:GetNormalized() * 5
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                ply.Blood = math.max((ply.Blood or 0) - 25, 0) -- Moderate blood loss
                            end
                        end
                    else
                        -- Fallback for left thigh (player)
                        local pos = ply:GetPos() + ply:GetAngles():Right() * -10 + ply:GetAngles():Forward() * 10 + ply:GetAngles():Up() * 30
                        local ang = ply:GetAngles()
                        -- Add randomness to blood spurt angle
                        local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                        local randomizedAng = ang + randomAngle
                        local vel = randomizedAng:Forward() * 60 + randomizedAng:Up() * -30
                        if BloodParticle then
                            BloodParticle(pos, vel)
                            ply.Blood = math.max((ply.Blood or 0) - 25, 0)
                        end
                    end
                elseif IsValid(ply) and (not ply:Alive()) and ply.FemoralArteryLBursting and ply.Organs and ply.Organs['femoral_artery_l'] <= 0 then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local boneId = rag:LookupBone("ValveBiped.Bip01_L_Thigh")
                        if boneId then
                            local pos
                            local ang
                            local phys = rag:GetPhysicsObjectNum(boneId)
                            if IsValid(phys) then
                                pos = phys:GetPos()
                                ang = phys:GetAngles()
                            else
                                local bonePos, boneAng = rag:GetBonePosition(boneId)
                                pos = bonePos
                                ang = boneAng
                            end

                            if pos and ang then
                                -- Add randomness to blood spurt angle
                                local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                                local randomizedAng = ang + randomAngle
                                local vel = randomizedAng:Forward() * 60 + randomizedAng:Up() * -30
                                pos = pos + vel:GetNormalized() * 5
                                if BloodParticle then
                                    BloodParticle(pos, vel)
                                    rag.Blood = math.max((rag.Blood or 0) - 25, 0)
                                end
                            end
                        else
                            -- Fallback for left thigh (ragdoll)
                            local pos = rag:GetPos() + rag:GetAngles():Right() * -10 + rag:GetAngles():Forward() * 10 + rag:GetAngles():Up() * 30
                            local ang = rag:GetAngles()
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 60 + randomizedAng:Up() * -30
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                rag.Blood = math.max((rag.Blood or 0) - 25, 0)
                            end
                        end
                    end
                else
                    timer.Remove("femoral_artery_l_burst_" .. ply:EntIndex())
                    ply.FemoralArteryLBursting = false
                end
            end)
        elseif ply.Organs['femoral_artery_l'] > 0 and ply.FemoralArteryLBursting then
            ply.FemoralArteryLBursting = false
            timer.Remove("femoral_artery_l_burst_" .. ply:EntIndex())
        end
        ply._lastFemoralArteryL = ply.Organs['femoral_artery_l']
    end

    -- Femoral Artery Right blood spurt effect (player and ragdoll)
    if ply.Organs and ply.Organs['femoral_artery_r'] ~= nil then
        ply._lastFemoralArteryR = ply._lastFemoralArteryR or ply.Organs['femoral_artery_r']
        if ply.Organs['femoral_artery_r'] <= 0 and (not ply.FemoralArteryRBursting) then
            ply.FemoralArteryRBursting = true
            timer.Create("femoral_artery_r_burst_" .. ply:EntIndex(), 0.1, 0, function()
                if IsValid(ply) and ply:Alive() and ply.FemoralArteryRBursting and ply.Organs and ply.Organs['femoral_artery_r'] <= 0 then
                    local boneId = ply:LookupBone("ValveBiped.Bip01_R_Thigh")
                    if boneId then
                        local bonePos, boneAng = ply:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local pos = bonePos
                            local ang = boneAng
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 60 + randomizedAng:Up() * -30
                            pos = pos + vel:GetNormalized() * 5
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                ply.Blood = math.max((ply.Blood or 0) - 25, 0)
                            end
                        end
                    else
                        -- Fallback for right thigh (player)
                        local pos = ply:GetPos() + ply:GetAngles():Right() * 10 + ply:GetAngles():Forward() * 10 + ply:GetAngles():Up() * 30
                        local ang = ply:GetAngles()
                        -- Add randomness to blood spurt angle
                        local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                        local randomizedAng = ang + randomAngle
                        local vel = randomizedAng:Forward() * 60 + randomizedAng:Up() * -30
                        if BloodParticle then
                            BloodParticle(pos, vel)
                            ply.Blood = math.max((ply.Blood or 0) - 25, 0)
                        end
                    end
                elseif IsValid(ply) and (not ply:Alive()) and ply.FemoralArteryRBursting and ply.Organs and ply.Organs['femoral_artery_r'] <= 0 then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local boneId = rag:LookupBone("ValveBiped.Bip01_R_Thigh")
                        if boneId then
                            local pos
                            local ang
                            local phys = rag:GetPhysicsObjectNum(boneId)
                            if IsValid(phys) then
                                pos = phys:GetPos()
                                ang = phys:GetAngles()
                            else
                                local bonePos, boneAng = rag:GetBonePosition(boneId)
                                pos = bonePos
                                ang = boneAng
                            end

                            if pos and ang then
                                -- Add randomness to blood spurt angle
                                local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                                local randomizedAng = ang + randomAngle
                                local vel = randomizedAng:Forward() * 60 + randomizedAng:Up() * -30
                                pos = pos + vel:GetNormalized() * 5
                                if BloodParticle then
                                    BloodParticle(pos, vel)
                                    rag.Blood = math.max((rag.Blood or 0) - 25, 0)
                                end
                            end
                        else
                            -- Fallback for right thigh (ragdoll)
                            local pos = rag:GetPos() + rag:GetAngles():Right() * 10 + rag:GetAngles():Forward() * 10 + rag:GetAngles():Up() * 30
                            local ang = rag:GetAngles()
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 60 + randomizedAng:Up() * -30
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                rag.Blood = math.max((rag.Blood or 0) - 25, 0)
                            end
                        end
                    end
                else
                    timer.Remove("femoral_artery_r_burst_" .. ply:EntIndex())
                    ply.FemoralArteryRBursting = false
                end
            end)
        elseif ply.Organs['femoral_artery_r'] > 0 and ply.FemoralArteryRBursting then
            ply.FemoralArteryRBursting = false
            timer.Remove("femoral_artery_r_burst_" .. ply:EntIndex())
        end
        ply._lastFemoralArteryR = ply.Organs['femoral_artery_r']
    end

    -- Popliteal Artery Left blood spurt effect (player and ragdoll)
    if ply.Organs and ply.Organs['popliteal_artery_l'] ~= nil then
        ply._lastPoplitealArteryL = ply._lastPoplitealArteryL or ply.Organs['popliteal_artery_l']
        if ply.Organs['popliteal_artery_l'] <= 0 and (not ply.PoplitealArteryLBursting) then
            ply.PoplitealArteryLBursting = true
            timer.Create("popliteal_artery_l_burst_" .. ply:EntIndex(), 0.1, 0, function()
                if IsValid(ply) and ply:Alive() and ply.PoplitealArteryLBursting and ply.Organs and ply.Organs['popliteal_artery_l'] <= 0 then
                    local boneId = ply:LookupBone("ValveBiped.Bip01_L_Calf")
                    if boneId then
                        local bonePos, boneAng = ply:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local pos = bonePos + boneAng:Forward() * -5
                            local ang = boneAng
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * -100 + randomizedAng:Up() * -30 -- Spray backwards
                            pos = pos + vel:GetNormalized() * 5
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                ply.Blood = math.max((ply.Blood or 0) - 5, 0) -- Very less blood loss
                            end
                        end
                    else
                        -- Fallback for left calf (player)
                        local pos = ply:GetPos() + ply:GetAngles():Right() * -5 + ply:GetAngles():Forward() * -5 + ply:GetAngles():Up() * 15
                        local ang = ply:GetAngles()
                        -- Add randomness to blood spurt angle
                        local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                        local randomizedAng = ang + randomAngle
                        local vel = randomizedAng:Forward() * -100 + randomizedAng:Up() * -30
                        if BloodParticle then
                            BloodParticle(pos, vel)
                            ply.Blood = math.max((ply.Blood or 0) - 5, 0)
                        end
                    end
                elseif IsValid(ply) and (not ply:Alive()) and ply.PoplitealArteryLBursting and ply.Organs and ply.Organs['popliteal_artery_l'] <= 0 then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local boneId = rag:LookupBone("ValveBiped.Bip01_L_Calf")
                        if boneId then
                            local pos
                            local ang
                            local phys = rag:GetPhysicsObjectNum(boneId)
                            if IsValid(phys) then
                                pos = phys:GetPos() + phys:GetAngles():Forward() * -5
                                ang = phys:GetAngles()
                            else
                                local bonePos, boneAng = rag:GetBonePosition(boneId)
                                pos = bonePos + boneAng:Forward() * -5
                                ang = boneAng
                            end

                            if pos and ang then
                                -- Add randomness to blood spurt angle
                                local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                                local randomizedAng = ang + randomAngle
                                local vel = randomizedAng:Forward() * -100 + randomizedAng:Up() * -30
                                pos = pos + vel:GetNormalized() * 5
                                if BloodParticle then
                                    BloodParticle(pos, vel)
                                    rag.Blood = math.max((rag.Blood or 0) - 5, 0)
                                end
                            end
                        else
                            -- Fallback for left calf (ragdoll)
                            local pos = rag:GetPos() + rag:GetAngles():Right() * -5 + rag:GetAngles():Forward() * -5 + rag:GetAngles():Up() * 15
                            local ang = rag:GetAngles()
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * -100 + randomizedAng:Up() * -30
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                rag.Blood = math.max((rag.Blood or 0) - 5, 0)
                            end
                        end
                    end
                else
                    timer.Remove("popliteal_artery_l_burst_" .. ply:EntIndex())
                    ply.PoplitealArteryLBursting = false
                end
            end)
        elseif ply.Organs['popliteal_artery_l'] > 0 and ply.PoplitealArteryLBursting then
            ply.PoplitealArteryLBursting = false
            timer.Remove("popliteal_artery_l_burst_" .. ply:EntIndex())
        end
        ply._lastPoplitealArteryL = ply.Organs['popliteal_artery_l']
    end

    -- Popliteal Artery Right blood spurt effect (player and ragdoll)
    if ply.Organs and ply.Organs['popliteal_artery_r'] ~= nil then
        ply._lastPoplitealArteryR = ply._lastPoplitealArteryR or ply.Organs['popliteal_artery_r']
        if ply.Organs['popliteal_artery_r'] <= 0 and (not ply.PoplitealArteryRBursting) then
            ply.PoplitealArteryRBursting = true
            timer.Create("popliteal_artery_r_burst_" .. ply:EntIndex(), 0.1, 0, function()
                if IsValid(ply) and ply:Alive() and ply.PoplitealArteryRBursting and ply.Organs and ply.Organs['popliteal_artery_r'] <= 0 then
                    local boneId = ply:LookupBone("ValveBiped.Bip01_R_Calf")
                    if boneId then
                        local bonePos, boneAng = ply:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local pos = bonePos + boneAng:Forward() * -5
                            local ang = boneAng
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * -100 + randomizedAng:Up() * -30
                            pos = pos + vel:GetNormalized() * 5
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                ply.Blood = math.max((ply.Blood or 0) - 5, 0)
                            end
                        end
                    else
                        -- Fallback for right calf (player)
                        local pos = ply:GetPos() + ply:GetAngles():Right() * 5 + ply:GetAngles():Forward() * -5 + ply:GetAngles():Up() * 15
                        local ang = ply:GetAngles()
                        -- Add randomness to blood spurt angle
                        local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                        local randomizedAng = ang + randomAngle
                        local vel = randomizedAng:Forward() * -500 + randomizedAng:Up() * -30
                        if BloodParticle then
                            BloodParticle(pos, vel)
                            ply.Blood = math.max((ply.Blood or 0) - 5, 0)
                        end
                    end
                elseif IsValid(ply) and (not ply:Alive()) and ply.PoplitealArteryRBursting and ply.Organs and ply.Organs['popliteal_artery_r'] <= 0 then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local boneId = rag:LookupBone("ValveBiped.Bip01_R_Calf")
                        if boneId then
                            local pos
                            local ang
                            local phys = rag:GetPhysicsObjectNum(boneId)
                            if IsValid(phys) then
                                pos = phys:GetPos() + phys:GetAngles():Forward() * -5
                                ang = phys:GetAngles()
                            else
                                local bonePos, boneAng = rag:GetBonePosition(boneId)
                                pos = bonePos + boneAng:Forward() * -5
                                ang = boneAng
                            end

                            if pos and ang then
                                -- Add randomness to blood spurt angle
                                local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                                local randomizedAng = ang + randomAngle
                                local vel = randomizedAng:Forward() * -100 + randomizedAng:Up() * -30
                                pos = pos + vel:GetNormalized() * 5
                                if BloodParticle then
                                    BloodParticle(pos, vel)
                                    rag.Blood = math.max((rag.Blood or 0) - 5, 0)
                                end
                            end
                        else
                            -- Fallback for right calf (ragdoll)
                            local pos = rag:GetPos() + rag:GetAngles():Right() * 5 + rag:GetAngles():Forward() * -5 + rag:GetAngles():Up() * 15
                            local ang = rag:GetAngles()
                            -- Add randomness to blood spurt angle
                            local randomAngle = Angle(math.random(-15, 15), math.random(-15, 15), 0)
                            local randomizedAng = ang + randomAngle
                            local vel = randomizedAng:Forward() * 100 + randomizedAng:Up() * -30
                            if BloodParticle then
                                BloodParticle(pos, vel)
                                rag.Blood = math.max((rag.Blood or 0) - 5, 0)
                            end
                        end
                    end
                else
                    timer.Remove("popliteal_artery_r_burst_" .. ply:EntIndex())
                    ply.PoplitealArteryRBursting = false
                end
            end)
        elseif ply.Organs['popliteal_artery_r'] > 0 and ply.PoplitealArteryRBursting then
            ply.PoplitealArteryRBursting = false
            timer.Remove("popliteal_artery_r_burst_" .. ply:EntIndex())
        end
        ply._lastPoplitealArteryR = ply.Organs['popliteal_artery_r']
    end

    -- Stop radial artery bleeding on respawn
    if ply.RadialArteryLBursting and ply:Alive() and ply.Organs and ply.Organs['radial_artery_l'] > 0 then
        timer.Remove("radial_artery_l_burst_" .. ply:EntIndex())
        ply.RadialArteryLBursting = false
        local rag = ply:GetNWEntity('player_ragdoll')
        if IsValid(rag) then
            timer.Remove("radial_artery_l_burst_rag_" .. rag:EntIndex())
            rag.RadialArteryLBursting = false
        end
    end

    if ply.RadialArteryRBursting and ply:Alive() and ply.Organs and ply.Organs['radial_artery_r'] > 0 then
        timer.Remove("radial_artery_r_burst_" .. ply:EntIndex())
        ply.RadialArteryRBursting = false
        local rag = ply:GetNWEntity('player_ragdoll')
        if IsValid(rag) then
            timer.Remove("radial_artery_r_burst_rag_" .. rag:EntIndex())
            rag.RadialArteryRBursting = false
        end
    end

    if ply.FemoralArteryLBursting and ply:Alive() and ply.Organs and ply.Organs['femoral_artery_l'] > 0 then
        timer.Remove("femoral_artery_l_burst_" .. ply:EntIndex())
        ply.FemoralArteryLBursting = false
        local rag = ply:GetNWEntity('player_ragdoll')
        if IsValid(rag) then
            timer.Remove("femoral_artery_l_burst_rag_" .. rag:EntIndex())
            rag.FemoralArteryLBursting = false
        end
    end

    if ply.FemoralArteryRBursting and ply:Alive() and ply.Organs and ply.Organs['femoral_artery_r'] > 0 then
        timer.Remove("femoral_artery_r_burst_" .. ply:EntIndex())
        ply.FemoralArteryRBursting = false
        local rag = ply:GetNWEntity('player_ragdoll')
        if IsValid(rag) then
            timer.Remove("femoral_artery_r_burst_rag_" .. rag:EntIndex())
            rag.FemoralArteryRBursting = false
        end
    end

    -- NEW: Update concussion status
    if ply.concussionActive and ply.concussionEndTime and CurTime() >= ply.concussionEndTime then
        ply.concussionActive = false
        ply.concussionIntensity = nil
        ply.concussionEndTime = nil
    end
    
    -- NEW: Process consciousness system
    ProcessConsciousness(ply)
    
    -- NEW: Process consciousness-based punishments
    ProcessConsciousnessPunishments(ply)
    
    if IsUnconscious(ply) then
        GetUnconscious(ply)
    else
        ply:ConCommand("soundfade 0 1")
    end
end)

if SERVER then 
    util.AddNetworkString("info_pain")
    util.AddNetworkString("RADS_UpdateConsciousness")
end
hook.Add("PostPlayerDeath", "RefreshPain", function(ply)
    ply.pain = 0
    ply.painlosing = 1
    ply:ConCommand("soundfade 0 1")
    ply.Otrub = false
    ply.BrainDamageFXActive = false -- Reset the flag on death
    ply.LungFailureOngoing = false -- Reset lung failure ongoing flag on death
    
    -- NEW: Reset concussion system on death
    ply.concussionActive = false
    ply.concussionIntensity = nil
    ply.concussionEndTime = nil
    
    -- NEW: Reset consciousness punishment system on death
    ply.lastConsciousnessRagdollCheck = nil
    ply.nextConsciousnessRagdollTime = nil
    ply.consciousnessRagdoll = nil
    
    -- Reset skull break consciousness depletion variables
    ply.skullBreakTimer = nil
    ply.skullBreakStartConsciousness = nil
    ply.lastSkullTimerDebug = nil
    ply.brainDamageConsciousnessApplied = nil
    ply.lastConsciousnessDebug = nil
    
    timer.Remove("RADS_LungMsg1Timer_" .. ply:EntIndex()) -- Stop lung message timer on death
    timer.Remove("RADS_LungMsg2Timer_" .. ply:EntIndex()) -- Stop lung message timer on death
    timer.Remove("RADS_LungWheezeTimer_" .. ply:EntIndex()) -- Stop wheeze timer on death
    timer.Remove("RADS_OxygenWheezeTimer_" .. ply:EntIndex()) -- Stop oxygen wheeze timer on death
    timer.Remove("RADS_LungFailureDeathTimer_" .. ply:EntIndex()) -- Stop lung failure death timer on death
    if SERVER then -- Explicitly stop client FX on death
        net.Start("RADS_StopBrainDamageFX")
        net.Send(ply)
        net.Start("RADS_StopLungFX") -- Send signal to client to stop lung FX (if any)
        net.Send(ply)
    end
    net.Start("info_pain")
    net.WriteFloat(ply.pain)
    net.WriteFloat(ply.painlosing)
    net.Send(ply)
end)

-- Add this new hook to reset pain on death
hook.Add("PlayerDeath", "RADS_ResetPainOnDeath", function(ply)
    if IsValid(ply) then
        -- Reset server-side pain
        ply.pain = 0
        ply.painlosing = 0
        
        -- Also reset other pain-related timers if they exist
        if ply.JawPainTimerActive then
            ply.JawPainTimerActive = false
        end
    end
end)

-- NEW: Consciousness-based punishment system
function ProcessConsciousnessPunishments(ply)
    if not IsValid(ply) or not ply:Alive() or ply.Otrub then return end
    if not ply.consciousness then return end
    
    local currentTime = CurTime()
    
    -- Initialize punishment timers if they don't exist
    if not ply.lastConsciousnessRagdollCheck then ply.lastConsciousnessRagdollCheck = 0 end
    if not ply.nextConsciousnessRagdollTime then ply.nextConsciousnessRagdollTime = 0 end
    
    -- Check for consciousness-based ragdolling (70-65 consciousness)
    if ply.consciousness >= 65 and ply.consciousness <= 70 then
        -- Only check every 2-5 seconds to avoid spam
        if currentTime >= ply.lastConsciousnessRagdollCheck + math.random(2, 5) then
            ply.lastConsciousnessRagdollCheck = currentTime
            
            -- Check if player is not already ragdolled
            if not ply.fake and not ply:GetNWBool("radsfa", false) then
                -- Random chance to ragdoll (10-20% chance per check)
                if math.random(1, 100) <= math.random(10, 20) then
                    -- Additional safety checks
                    if not timer.Exists("StunTime" .. ply:EntIndex()) and 
                       not timer.Exists("Epilepsy" .. ply:EntIndex()) and
                       not ply:InVehicle() then
                        
                        -- Trigger ragdoll due to consciousness loss
                        rads(ply, false) -- false = not manual ragdoll
                        
                        -- Mark this as a consciousness-induced ragdoll for weapon dropping
                        ply.consciousnessRagdoll = true
                        
                        -- Clear the flag after a short delay
                        timer.Simple(0.5, function()
                            if IsValid(ply) then
                                ply.consciousnessRagdoll = nil
                            end
                        end)
                    end
                end
            end
        end
    end
    
    -- Check for weapon dropping (60-55 consciousness) when ragdolled
    if ply.consciousness >= 55 and ply.consciousness <= 60 then
        -- Only drop weapon if player just got ragdolled due to consciousness
        if ply.consciousnessRagdoll and ply.fake then
            local activeWeapon = ply:GetActiveWeapon()
            if IsValid(activeWeapon) then
                -- Drop the weapon
                ply:DropWeapon(activeWeapon)
                
                -- Clear the flag to prevent multiple drops
                ply.consciousnessRagdoll = nil
            end
        end
    end
end

-- NEW: Consciousness processing function
function ProcessConsciousness(ply)
    if not ply.consciousness then ply.consciousness = 100 end
    if not ply.consciousnessLastUpdate then ply.consciousnessLastUpdate = CurTime() end
    
    local currentTime = CurTime()
    local deltaTime = currentTime - ply.consciousnessLastUpdate
    ply.consciousnessLastUpdate = currentTime
    
    -- Natural consciousness regeneration (FIXED: Reduced rates to prevent too fast recovery)
    if ply.consciousness < 100 then
        if ply.Otrub then
            -- Slower recovery during unconsciousness (1.5 per second)
            ply.consciousness = math.min(100, ply.consciousness + (deltaTime * 1.5))
        else
            -- Normal recovery rate (1 per second - reduced for easier consciousness loss)
            ply.consciousness = math.min(100, ply.consciousness + (deltaTime * 1))
        end
    end
    
    -- Consciousness loss factors
    local consciousnessLoss = 0
    
    -- 1. Pain-based consciousness loss (when pain exceeds limit) - ENHANCED FOR FASTER LOSS
    local painLimit = GetConVar("rads_painlimit"):GetInt() or 190
    if ply.pain > painLimit then
        local painExcess = ply.pain - painLimit
        -- Much faster consciousness loss from pain (2 to 10 per second - doubled)
        local painLossRate = math.Clamp(painExcess / 40, 0.5, 2.5)
        consciousnessLoss = consciousnessLoss + (painLossRate * deltaTime)
    end
    
    -- Additional pain-based consciousness loss even below limit for faster effect
    if ply.pain > (painLimit * 0.7) then
        local painRatio = ply.pain / painLimit
        local additionalLoss = math.Clamp((painRatio - 0.7) * 0.75, 0, 0.5)
        consciousnessLoss = consciousnessLoss + (additionalLoss * deltaTime)
    end
    
    -- 2. Rapid blood loss consciousness loss (INCREASED THRESHOLD)
    if ply.BloodLosing and ply.BloodLosing > 200 then  -- Increased from 50 to 200
        local bloodLossRate = math.Clamp(ply.BloodLosing / 70, 0.3, 2)  -- Increased divisor from 50 to 70
        consciousnessLoss = consciousnessLoss + (bloodLossRate * deltaTime)
    end
    
    -- 3. Low blood volume consciousness loss (INCREASED THRESHOLD)
    if ply.Blood < 2500 then  -- Decreased from 3500 to 2500 (requires more blood loss)
        local bloodRatio = ply.Blood / 5000
        local bloodLossRate = math.Clamp((1 - bloodRatio) * 2.5, 0, 2)  -- Reduced multiplier from 3 to 2.5, max from 2.5 to 2
        consciousnessLoss = consciousnessLoss + (bloodLossRate * deltaTime)
    end
    
    -- 3b. Critical blood loss (near shutdown limit) - rapid consciousness loss
    local bloodLimit = GetConVar("rads_bloodlimit"):GetInt()
    if ply.Blood < (bloodLimit + 800) and ply.Blood > bloodLimit then  -- Increased range from 500 to 800
        -- Rapid consciousness loss when approaching blood shutdown
        local criticalBloodLoss = math.Clamp((bloodLimit + 800 - ply.Blood) / 800, 0, 1)
        consciousnessLoss = consciousnessLoss + (criticalBloodLoss * 5 * deltaTime) -- Increased from 3 to 5 consciousness per second
    end
    
    -- 3c. Extreme blood loss (very close to shutdown) - massive consciousness loss
    if ply.Blood < (bloodLimit + 300) and ply.Blood > bloodLimit then
        -- Extreme consciousness loss when very close to blood shutdown
        local extremeBloodLoss = math.Clamp((bloodLimit + 300 - ply.Blood) / 300, 0, 1)
        consciousnessLoss = consciousnessLoss + (extremeBloodLoss * 8 * deltaTime) -- Up to 8 consciousness per second
    end
    
    -- 4. Head trauma consciousness depletion (skull damage) - 15 SECOND TIMER SYSTEM
    if ply.Organs and ply.Organs['skull'] < 5 then
        -- Initialize skull break timer if not already started
        if not ply.skullBreakTimer then
            ply.skullBreakTimer = currentTime
            ply.skullBreakStartConsciousness = ply.consciousness

        end
        
        -- Calculate elapsed time since skull break
        local elapsedTime = currentTime - ply.skullBreakTimer
        
        -- Apply effects for 15 seconds
        if elapsedTime <= 15 then
            -- Rapidly decrease consciousness over 15 seconds
            if ply.consciousness > 0 then
                local consciousnessDepletionRate = 6.67 -- Deplete ~100 consciousness over 15 seconds
                ply.consciousness = math.max(0, ply.consciousness - (consciousnessDepletionRate * deltaTime))
            end
            
            -- Max out fear during the 15-second period
            if ply.fear then
                ply.fear = 100
            end
            
            -- Debug message every 2 seconds during timer
            if not ply.lastSkullTimerDebug then ply.lastSkullTimerDebug = 0 end
            if currentTime - ply.lastSkullTimerDebug >= 2 then
                ply.lastSkullTimerDebug = currentTime
                local timeRemaining = 15 - elapsedTime
            end
        else
            -- Timer finished, reset timer variables
            ply.skullBreakTimer = nil
            ply.skullBreakStartConsciousness = nil
            ply.lastSkullTimerDebug = nil

        end
    else
        -- Skull healed, reset timer if it was active
        if ply.skullBreakTimer then
            ply.skullBreakTimer = nil
            ply.skullBreakStartConsciousness = nil
            ply.lastSkullTimerDebug = nil

        end
    end
    
    -- 5. Brain damage consciousness loss - EVENT BASED (ONE TIME ONLY)
    if ply.Organs and ply.Organs['brain'] < 5 then
        -- Check if brain damage consciousness drop has already been applied
        if not ply.brainDamageConsciousnessApplied then
            -- Calculate consciousness loss based on brain damage severity
            local brainRatio = ply.Organs['brain'] / 9
            local consciousnessReduction = math.Clamp((1 - brainRatio) * 30, 10, 30) -- One-time loss of 10-30 consciousness
            ply.consciousness = math.max(55, ply.consciousness - consciousnessReduction) -- Cap at 55 minimum
            ply.brainDamageConsciousnessApplied = true

        end
    else
        -- Reset the flag when brain heals above 5 (allows for re-application if damage occurs again)
        if ply.brainDamageConsciousnessApplied then
            ply.brainDamageConsciousnessApplied = false
        end
    end
    
    -- 6. Oxygen deprivation consciousness loss (simplified)
    if ply.o2 and ply.o2 < 50 then
        local oxygenRatio = ply.o2 / 100
        -- Simple consciousness loss from oxygen deprivation
        local oxygenLossRate = math.Clamp((1 - oxygenRatio) * 2, 0, 2)
        consciousnessLoss = consciousnessLoss + (oxygenLossRate * deltaTime)
    end
    
    -- 7. NEW: Concussion-based consciousness loss
    if ply.concussionActive and ply.concussionIntensity then
        -- Rapid consciousness loss during concussion based on intensity
        local concussionLossRate = ply.concussionIntensity * 6 -- Up to 6 consciousness per second at max intensity
        consciousnessLoss = consciousnessLoss + (concussionLossRate * deltaTime)
    end
    
    -- 8. NEW: Drowning-based consciousness loss
    if ply.isDrowning then
        -- Consciousness loss during drowning - panic and oxygen deprivation
        local drowningLossRate = 1.5 -- 1.5 consciousness per second during drowning
        consciousnessLoss = consciousnessLoss + (drowningLossRate * deltaTime)
    end
    
    -- BALANCE FIX: Prevent consciousness loss when unconscious (except for comatose states)
    if ply.Otrub and ply.consciousnessBasedUnconscious then
        consciousnessLoss = 0
        
        -- BALANCE FIX: Gradually reduce blood loss rate when unconscious to allow eventual wake-up
        if ply.BloodLosing and ply.BloodLosing > 0 then
            -- Reduce blood loss rate by 2 per second when unconscious (since bleeding is stopped)
            ply.BloodLosing = math.max(0, ply.BloodLosing - (2 * deltaTime))
        end
    end
    
    -- Apply consciousness loss
    if consciousnessLoss > 0 then
        ply.consciousness = math.max(0, ply.consciousness - consciousnessLoss)
    end


    
    -- If manually set unconscious (like comatose), keep consciousness at 0
    if ply.Otrub and not ply.consciousnessBasedUnconscious then
        ply.consciousness = 0
    end
    
    -- DEBUG: Print consciousness information every 2 seconds
    if not ply.lastConsciousnessDebug then ply.lastConsciousnessDebug = 0 end
    if currentTime - ply.lastConsciousnessDebug >= 2 then
        ply.lastConsciousnessDebug = currentTime
        
        -- Build debug message with contributing factors
        local debugFactors = {}
        
        -- Check each factor that contributed to consciousness loss
        local painLimit = GetConVar("rads_painlimit"):GetInt() or 190
        if ply.pain > painLimit then
            table.insert(debugFactors, string.format("Pain: %d/%d", math.floor(ply.pain), painLimit))
        end
        
        if ply.BloodLosing and ply.BloodLosing > 200 then  -- Updated to match new threshold
            table.insert(debugFactors, string.format("Blood Loss Rate: %d/min", math.floor(ply.BloodLosing)))
        end
        
        if ply.Blood < 2500 then  -- Updated to match new threshold
            table.insert(debugFactors, string.format("Low Blood: %d/5000", math.floor(ply.Blood)))
        end
        
        local bloodLimit = GetConVar("rads_bloodlimit"):GetInt()
        if ply.Blood < (bloodLimit + 500) and ply.Blood > bloodLimit then
            table.insert(debugFactors, string.format("Critical Blood: %d/%d", math.floor(ply.Blood), bloodLimit))
        end
        
        if ply.Organs and ply.Organs['skull'] < 15 then
            table.insert(debugFactors, string.format("Head Trauma: %d/25", math.floor(ply.Organs['skull'])))
        end
        
        if ply.Organs and ply.Organs['brain'] < 5 then
            table.insert(debugFactors, string.format("Brain Damage: %d/9", math.floor(ply.Organs['brain'])))
        end
        
        if ply.o2 and ply.o2 < 70 then
            table.insert(debugFactors, string.format("Low Oxygen: %d/100", math.floor(ply.o2)))
        end
        
        -- Print consciousness debug info
        local factorsText = #debugFactors > 0 and (" | Factors: " .. table.concat(debugFactors, ", ")) or ""
        local unconsciousText = ply.Otrub and " [UNCONSCIOUS]" or ""
        
        if GetConVar("developer"):GetInt() >= 1 then
            print(string.format("[CONSCIOUSNESS DEBUG] %s: %.1f/100%s%s", 
                ply:Name(), ply.consciousness, factorsText, unconsciousText))
        end
    end
    
    -- Update networked value
    ply:SetNWInt("PlayerConsciousness", math.floor(ply.consciousness))
    
    -- Send consciousness timer data to client if enabled
    if GetConVar("rads_consciousness_timer"):GetBool() then
        SyncConsciousnessTimer(ply)
    end
end

-- Function to sync consciousness timer data to client
function SyncConsciousnessTimer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    local isUnconscious = ply:GetNWBool("Otrub", false)
    local consciousness = ply.consciousness or 100
    
    net.Start("RADS_ConsciousnessTimer")
    net.WriteBool(isUnconscious)
    net.WriteFloat(consciousness)
    net.Send(ply)
end

function IsUnconscious(ply)
    local wasOtrub = ply.Otrub -- Store current state
    
    -- Don't override unconsciousness during last stand
    if ply.lastStandUnconscious then
        return ply.Otrub
    end
    
    -- NEW: Consciousness-based unconsciousness system
    -- If player is manually set unconscious (like comatose), set consciousness to 0
    if ply.Otrub and not ply.consciousnessBasedUnconscious then
        ply.consciousness = 0
        ply:SetNWInt("PlayerConsciousness", ply.consciousness)
        return ply.Otrub
    end
    
    -- Check for consciousness-based unconsciousness (45 or below) - FIXED: Lowered threshold to prevent oscillation
    -- Check if consciousness loss is disabled
    if not GetConVar("rads_disable_consciousness"):GetBool() and ply.consciousness <= 45 then
        if not ply.Otrub or not ply.consciousnessBasedUnconscious then
            ply.Otrub = true
            ply.consciousnessBasedUnconscious = true
            ply:SetNWBool("Otrub", true)
            
            -- DEBUG: Print when player becomes unconscious due to consciousness
            if GetConVar("developer"):GetInt() >= 1 then
                print(string.format("[CONSCIOUSNESS DEBUG] %s became UNCONSCIOUS due to low consciousness: %.1f/100", 
                    ply:Name(), ply.consciousness))
            end
            
            if SERVER then
                net.Start("RADS_PlayerUnconscious")
                net.WriteBool(true)
                net.Send(ply)
                net.Start("RADS_SetHearingState")
                net.WriteBool(true)
                net.Send(ply)
                
                -- Check if unconsciousness was caused by recent blast damage (within 2 seconds)
                if ply.lastBlastDamageTime and (CurTime() - ply.lastBlastDamageTime) <= 2 then
                    -- Send blast unconsciousness sound to client
                    net.Start("RADS_BlastUnconsciousSound")
                    net.Send(ply)
                end
                
                -- Force ragdoll state for unconsciousness
                if not ply.fake then
                    -- Check if player is already ragdolled to prevent teleportation bug
                    local existingRag = ply:GetNWEntity("player_ragdoll")
                    if not IsValid(existingRag) then
                        -- Only create new ragdoll if one doesn't exist
                        rads(ply)
                    else
                        -- Player is already ragdolled, just ensure unconscious state is set
                        ply.Otrub = true
                        ply:SetNWBool("Otrub", true)
                    end
                end
            end
        end
    else
        -- Wake up if consciousness is above 55 (FIXED: Added hysteresis - higher wake-up threshold prevents oscillation)
        -- FIXED: Simplified wake-up conditions to prevent getting stuck unconscious
        local canWakeUp = ply.consciousnessBasedUnconscious and ply.consciousness > 55
        
        -- Only prevent wake-up if blood is at critical shutdown levels (not just near)
        local bloodLimit = GetConVar("rads_bloodlimit"):GetInt()
        if ply.Blood <= (bloodLimit + 200) then  -- Reduced from 600 to 200 - only prevent wake-up when very close to death
            canWakeUp = false
        end
        
        -- Only prevent wake-up if blood loss rate is extremely high
        if ply.BloodLosing and ply.BloodLosing > 550 then  -- Increased threshold from 80 to 250 to match new consciousness threshold
            canWakeUp = false
        end
        
        -- Only prevent wake-up if pain is absolutely extreme
        local painLimit = GetConVar("rads_painlimit"):GetInt() or 190
        if ply.pain > (painLimit + 100) then  -- Lowered threshold from 200 to 100
            canWakeUp = false
        end
        
        if canWakeUp then
            ply.Otrub = false
            ply.consciousnessBasedUnconscious = false
            ply:SetNWBool("Otrub", false)
            
            -- DEBUG: Print when player wakes up due to consciousness recovery
            if GetConVar("developer"):GetInt() >= 1 then
                print(string.format("[CONSCIOUSNESS DEBUG] %s WOKE UP due to consciousness recovery: %.1f/100", 
                    ply:Name(), ply.consciousness))
            end
            
            if SERVER then
                net.Start("RADS_PlayerUnconscious")
                net.WriteBool(false)
                net.Send(ply)
                net.Start("RADS_SetHearingState")
                net.WriteBool(false)
                net.Send(ply)
            end
        end
    end

    return ply.Otrub
end

function GetUnconscious(ply)
    if ply:Alive() then
        ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 0.5, 0.5)
    else
    end

    if not ply.fake then
        -- Check if player is already ragdolled to prevent teleportation bug
        local existingRag = ply:GetNWEntity("player_ragdoll")
        if not IsValid(existingRag) then
            -- Only create new ragdoll if one doesn't exist
            rads(ply)
        end
    end
    if ply.gotuncon then ply.pain = ply.pain + 100 end
    ply.gotuncon = false
    local rag = ply:GetNWEntity("player_ragdoll")
    if IsValid(rag) and ply.Otrub then rag:SetEyeTarget(Vector(0, 0, 0)) end
end

hook.Add("PlayerSpawn", "Damage", function(ply)
    if timer.Exists('respawntimer' .. ply:EntIndex()) then return end
    rag = ply:GetNWEntity('player_ragdoll')
    ply.Organs = {
        ['skull'] = 40,
        ['jaw'] = 10,
        ['brain'] = 15,
        ['left_lung'] = 5,
        ['right_lung'] = 5,
        ['liver'] = 15,
        ['stomach'] = 15,
        ['intestines'] = 30,
        ['heart'] = 9,
        ['artery'] = 3,
        ['upper_spine'] = 7,
        ['lower_spine'] = 7,
        ['bladder'] = 3,
        ['radial_artery_l'] = 3,
        ['radial_artery_r'] = 3,
        ['femoral_artery_l'] = 9,
        ['femoral_artery_r'] = 9,
        ['popliteal_artery_l'] = 3,
        ['popliteal_artery_r'] = 3,
        ['ribs'] = 240, -- Initialize with 240 health for 24 ribs (10 health per rib)
        ['left_eye'] = 3,
        ['right_eye'] = 3,
        ['pelvis'] = 25 -- Pelvis organ with moderate health, critical for stability
    }
    
    -- Synchronize eye health values to client for overlay system
    if SERVER then
        ply:SetNWInt("LeftEyeHealth", ply.Organs['left_eye'])
        ply:SetNWInt("RightEyeHealth", ply.Organs['right_eye'])
    end
    if SERVER then
        timer.Remove("jaw_pain_" .. ply:EntIndex())
        ply.JawPainTimerActive = false
    end

    -- Set player health from ConVar with timer to override GMod defaults
    timer.Simple(0.1, function()
        if IsValid(ply) then
            local healthConVar = GetConVar("rads_player_health")
            local defaultHealth = healthConVar and healthConVar:GetInt() or 300
            ply:SetHealth(defaultHealth)
            ply:SetMaxHealth(defaultHealth)
        end
    end)
    
    ply.pulse = 70
    ply:SetNWInt("PlayerPulse", ply.pulse) -- Network the pulse directly
    ply.mental = 100
    ply.nobrain = false
    ply.painlosing = 1
    ply.pain = 0
    ply.painNext = 0
    ply.painNextNet = 0
    ply.Blood = 5000
    ply.cock = 0
    ply.bloodtype = math.random(1, 4)
    ply.InternalBleeding = nil
    ply.InternalBleeding2 = nil
    ply.InternalBleeding3 = nil
    ply.InternalBleeding4 = nil
    ply.InternalBleeding5 = nil
    ply:SetNWBool('radshighpulse', false)
    ply.brokenspine = false
    ply.brokenupperspine = false
    ply.brokenpelvis = false -- NEW: Add pelvis break tracking
    ply.LeftLeg = 1
    ply.RightArm = 1
    ply.RightLeg = 1
    ply.LeftArm = 1
    ply.Jaw = 1  -- NEW: Add jaw health tracking
    ply.Pelvis = 1 -- NEW: Add pelvis health tracking
    ply.msgLeftArm = 0
    ply.msgRightArm = 0
    ply.msgLeftLeg = 0
    ply.msgRightLeg = 0
    ply.msgJaw = 0  -- NEW: Add jaw message timer
    ply.msgPelvis = 0 -- NEW: Add pelvis message timer
    ply.LastDMGInfo = nil
    ply.LastHitPhysicsBone = nil
    ply.LastHitBoneName = nil
    ply.LastHitGroup = nil
    ply.LastAttacker = nil
    ply.BrainDamageFXActive = false -- Initialize the flag
    ply._brokenRibs = 0 -- Initialize broken ribs count
    ply.LungFailureOngoing = false -- Initialize lung failure ongoing flag
    ply.LungsChatMsg1 = false -- Initialize flag for "Something is filling my lungs"
    ply.LungsChatMsg2 = false -- Initialize flag for "Im struggling to breathe"
    
    -- NEW: Initialize oxygen system (using o2 variable)
    ply.o2 = 100 -- Initialize oxygen to 100%
    ply.oxygen = ply.o2 -- Keep compatibility with existing code
    ply.oxygenDepletionRate = 0 -- Base depletion rate
    ply.oxygenEffectsActive = false
    ply.oxygenCriticalEffects = false
    ply.oxygenWheezeActive = false
    ply.oxygenUnconscious = false
    ply.oxygenDeathTimer = false
    ply.lastOxygenThought = 0
    ply:SetNWInt("PlayerOxygen", ply.o2)
    
    -- NEW: Initialize consciousness system
    ply.consciousness = 100 -- Initialize consciousness to 100
    ply.consciousnessLastUpdate = CurTime()
    ply.consciousnessEffectsActive = false
    ply:SetNWInt("PlayerConsciousness", ply.consciousness)
    
    -- NEW: Initialize consciousness punishment system
    ply.lastConsciousnessRagdollCheck = 0
    ply.nextConsciousnessRagdollTime = 0
    ply.consciousnessRagdoll = nil
    
    -- Initialize concussion system
    ply.concussionActive = false
    ply.concussionIntensity = nil
    ply.concussionEndTime = nil
    
    -- NEW: Reset adrenaline system on spawn/death
    ply.adrenaline = 0
    ply.adrenalineActive = false
    ply.adrenalineEndTime = 0
    ply.adrenalineCooldownEnd = 0
    ply.adrenalineLastUpdate = 0
    ply.adrenalineLastDamageTime = 0
    
    RADS_SendINFO(ply)
    ply:SetNWInt("PlayerBlood", ply.Blood) -- New: Set NWInt for initial blood on spawn
    ply:SetNWBool("Otrub", false) -- New: Initialize Otrub to false on spawn
    ply:ChatPrint("Your blood type: " .. tostring(ply.bloodtype))
end)

if SERVER then
    concommand.Add("setskullhealth0", function(ply, cmd, args) -- Keep this for now
        if IsValid(ply) and ply:IsPlayer() then
            ply.Organs['skull'] = 0
            RADS_SendINFO(ply)
            ply:ChatPrint("Your skull health has been set to 0.")

            -- Trigger the brain damage sound loop for braindamage.wav
            net.Send(ply)
        end
    end)

    -- New server-side handler for initiating brain meltdown
    if SERVER then
        net.Receive('RADS_BrainMeltdownStart', function(len, ply)
            if IsValid(ply) and ply:IsPlayer() then
                local delay = math.random(15, 20) -- Random delay between 15 and 20 seconds
                timer.Simple(delay, function()
                    if IsValid(ply) and ply:IsPlayer() then
                        -- Check if brain is not already melted before setting to 0 and triggering effects
                        if ply.Organs and ply.Organs['brain'] > 0 then
                            ply.Organs['brain'] = 0
                            RADS_AddThought(ply, "Your brain has melted.", 0.7, false)
                            -- Trigger brain death sound to client
                            net.Start("RADS_BrainDeathSound")
                            net.Send(ply)
                            -- Only apply rigor mortis rarely, and if brain death
                            if math.random() < 0.9 then -- 10% chance
                                ply.rigorMortis = true -- Set rigor mortis flag for brain death
                            end
                            TriggerDeathState(ply) -- Ensure player dies
                        end
                    end
                end)
            end
        end)
    end

    concommand.Add("rads_damagelungs", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local damageAmount = 20
        local damageType = DMG_BULLET -- As requested

        -- Get the world position and angles of the 'ValveBiped.Bip01_Spine2' bone (chest/spine)
        local boneId = ply:LookupBone("ValveBiped.Bip01_Spine2")
        local bonePos, boneAng = ply:GetBonePosition(boneId)

        if not bonePos then -- Fallback if bone not found (shouldn't happen for players)
            bonePos = ply:GetPos() + Vector(0,0,60)
            boneAng = ply:EyeAngles()
        end

        -- Create a dummy DamageInfo object to simulate damage
        local dmginfo = DamageInfo()
        dmginfo:SetAttacker(ply) -- Attacker is the player themselves for self-damage
        dmginfo:SetInflictor(ply) -- Inflictor is also the player
        dmginfo:SetDamage(damageAmount)
        dmginfo:SetDamageType(damageType)
        -- Set damage position slightly in front of the chest bone, and force inwards
        dmginfo:SetDamagePosition(bonePos + boneAng:Forward() * -20)
        dmginfo:SetDamageForce(boneAng:Forward() * 500) -- Force pointing into the chest

        -- Apply damage to the player, which will trigger the HomigradDamage hook
        ply:TakeDamageInfo(dmginfo)

        ply:ChatPrint("Admin command: Applied " .. damageAmount .. " " .. tostring(damageType) .. " damage to lungs.")
        print("Admin command: " .. ply:Name() .. " applied " .. damageAmount .. " " .. tostring(damageType) .. " damage to lungs.")

    end)

    -- New concommand to reduce player blood for testing the damage overlay
    concommand.Add("rads_reduceblood", function(ply, cmd, args)
        if IsValid(ply) and ply:IsPlayer() then
            local amount = tonumber(args[1]) or 1000 -- Default to reducing by 1000 if no amount is specified
            ply.Blood = math.max(0, (ply.Blood or 5000) - amount)
            ply:ChatPrint("Your blood has been reduced by " .. amount .. ". Current blood: " .. ply.Blood)
            RADS_SendINFO(ply)
        end
    end)

    hook.Add("Think", "RADS_UpdateLimbDislocationEffects", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() then
                -- Leg dislocation speed
                if ply.LeftLeg and ply.RightLeg then
                    local bothLegsBroken = ply.LeftLeg <= 0.4 and ply.RightLeg <= 0.4
                    local bothLegsDislocated = ply.LeftLeg <= 0.8 and ply.RightLeg <= 0.8
                    local oneBroken = ply.LeftLeg <= 0.4 or ply.RightLeg <= 0.4
                    local oneDislocated = ply.LeftLeg <= 0.8 or ply.RightLeg <= 0.8
                    
                    if bothLegsBroken then
                    -- Both legs broken: severe but not crippling
                    ply:SetWalkSpeed(80)  -- Was 30, now 50% of normal
                    ply:SetRunSpeed(125)  -- Was 50, now 50% of normal
                elseif bothLegsDislocated then
                    -- Both legs dislocated: significant reduction
                    ply:SetWalkSpeed(100) -- Was 60, now 62.5% of normal
                    ply:SetRunSpeed(155)  -- Was 90, now 62% of normal
                elseif oneBroken then
                    -- One leg broken: moderate reduction
                    ply:SetWalkSpeed(110) -- Was 50, now 69% of normal
                    ply:SetRunSpeed(175)  -- Was 80, now 70% of normal
                elseif oneDislocated then
                    -- One leg dislocated: minor reduction
                    ply:SetWalkSpeed(130) -- Was 80, now 81% of normal
                    ply:SetRunSpeed(200)  -- Was 120, now 80% of normal
                    else
                        -- Normal
                        ply:SetWalkSpeed(160)
                        ply:SetRunSpeed(250)
                    end
                end
                -- Arm dislocation/broken NWBools
                if ply.LeftArm and ply.RightArm then
                    ply:SetNWBool("RADS_LeftArmDislocated", ply.LeftArm <= 0.8 and ply.LeftArm > 0.4)
                    ply:SetNWBool("RADS_RightArmDislocated", ply.RightArm <= 0.8 and ply.RightArm > 0.4)
                    ply:SetNWBool("RADS_LeftArmBroken", ply.LeftArm <= 0.4)
                    ply:SetNWBool("RADS_RightArmBroken", ply.RightArm <= 0.4)
                    ply:SetNWBool("RADS_BothArmsDislocated", (ply.LeftArm <= 0.8 and ply.LeftArm > 0.4) and (ply.RightArm <= 0.8 and ply.RightArm > 0.4))
                    ply:SetNWBool("RADS_BothArmsBroken", ply.LeftArm <= 0.4 and ply.RightArm <= 0.4)
                end
                
                -- Jaw states
                if ply.Jaw then
                    ply:SetNWBool("RADS_JawDislocated", ply.Jaw <= 0.8 and ply.Jaw > 0.4)
                    ply:SetNWBool("RADS_JawBroken", ply.Jaw <= 0.4)
                end
            end
        end
    end)
end

RagdollDamageBoneMul = {
    [HITGROUP_LEFTLEG] = 0.7,
    [HITGROUP_RIGHTLEG] = 0.7,
    [HITGROUP_GENERIC] = 0.9,
    [HITGROUP_LEFTARM] = 0.6,
    [HITGROUP_RIGHTARM] = 0.6,
    [HITGROUP_CHEST] = 1,
    [HITGROUP_STOMACH] = 0.9,
    [HITGROUP_HEAD] = 2,
}

bonetohitgroup = {
    ["ValveBiped.Bip01_Head1"] = 1,
    ["ValveBiped.Bip01_R_UpperArm"] = 5,
    ["ValveBiped.Bip01_R_Forearm"] = 5,
    ["ValveBiped.Bip01_R_Hand"] = 5,
    ["ValveBiped.Bip01_L_UpperArm"] = 4,
    ["ValveBiped.Bip01_L_Forearm"] = 4,
    ["ValveBiped.Bip01_L_Hand"] = 4,
    ["ValveBiped.Bip01_Pelvis"] = 3,
    ["ValveBiped.Bip01_Spine2"] = 2,
    ["ValveBiped.Bip01_L_Thigh"] = 6,
    ["ValveBiped.Bip01_L_Calf"] = 6,
    ["ValveBiped.Bip01_L_Foot"] = 6,
    ["ValveBiped.Bip01_R_Thigh"] = 7,
    ["ValveBiped.Bip01_R_Calf"] = 7,
    ["ValveBiped.Bip01_R_Foot"] = 7
}

local util_TraceLine = util.TraceLine
function GetPhysicsBoneDamageInfo(ent, dmgInfo)
    local pos = dmgInfo:GetDamagePosition()
    local dir = dmgInfo:GetDamageForce():GetNormalized()
    dir:Mul(1024 * 8)
    local tr = {}
    tr.start = pos
    tr.endpos = pos + dir
    tr.filter = filter
    filterEnt = ent
    tr.ignoreworld = true
    local result = util_TraceLine(tr)
    if result.Entity ~= ent then
        tr.endpos = pos - dir
        return util_TraceLine(tr).PhysicsBone
    else
        return result.PhysicsBone
    end
end

function RagdollOwner(rag)
    if not IsValid(rag) then return end
    local ent = rag:GetNWEntity("owner")
    return IsValid(ent) and ent
end

hook.Add("HomigradDamage", "Organs", function(ply, hitgroup, dmginfo, rag)
    local ent = rag or ply
    local inf = dmginfo:GetInflictor()

    if dmginfo:IsDamageType(DMG_BLAST) then
        if IsValid(ply) and ply:IsPlayer() and not ply.Otrub then
        end
    end

    if hitgroup == HITGROUP_HEAD then
        if dmginfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then
            dmginfo:ScaleDamage(1)
            ply:SetDSP(37)
        end

        if dmginfo:IsDamageType(DMG_CRUSH) and dmginfo:GetDamage() >= 6 and ent:GetVelocity():Length() > 1300 then
            -- Neck break: removed ChatPrint for immersion, only play sound and apply fatal damage
            ent:EmitSound("bones/bone7.mp3", 100, 98, 1, CHAN_ITEM)
            dmginfo:ScaleDamage(5555 * 5)
            return
        end
    end

    if GetConVar("rads_bones"):GetBool() then
        if IsValid(ply) and ply:IsPlayer() then
            local damage = dmginfo:GetDamage()
            local velocity = ent:GetVelocity():Length()
            
            -- NEW: Higher damage thresholds for bone damage
            local dislocationThreshold = 75  -- Increased from 55
            local brokenThreshold = 120      -- New threshold for broken bones
            
            -- Special lower thresholds for club weapons
            if dmginfo:IsDamageType(DMG_CLUB) then
                dislocationThreshold = 40  -- Much lower for clubs
                brokenThreshold = 70       -- Much lower for clubs
            end
            
            -- Check for dislocation damage (75+ damage or specific conditions)
            local canDislocate = damage >= dislocationThreshold or 
                               (dmginfo:IsDamageType(DMG_CRUSH + DMG_BULLET) and damage >= 25 and velocity > 800) or
                               (dmginfo:IsDamageType(DMG_CLUB) and damage >= 30) -- Additional club condition
            
            -- Check for broken bone damage (120+ damage or severe conditions)
            local canBreak = damage >= brokenThreshold or 
                            (dmginfo:IsDamageType(DMG_CRUSH + DMG_BULLET) and damage >= 50 and velocity > 1200) or
                            (dmginfo:IsDamageType(DMG_CLUB) and damage >= 50) -- Additional club condition
            
            -- NEW: Damage-based bone breaking chance for clubs
            if dmginfo:IsDamageType(DMG_CLUB) then
                local breakChance = 0
                if damage >= 30 then
                    breakChance = math.min((damage - 30) * 0.02, 0.8) -- 2% chance per damage point above 30, max 80%
                end
                
                -- Higher chance for headshots
                if hitgroup == HITGROUP_HEAD then
                    breakChance = breakChance * 1.5 -- 50% bonus for head hits
                end
                
                -- Roll for additional break chance
                if math.random() <= breakChance then
                    canBreak = true
                end
                
                -- Similar logic for dislocation
                local dislocateChance = 0
                if damage >= 20 then
                    dislocateChance = math.min((damage - 20) * 0.03, 0.9) -- 3% chance per damage point above 20, max 90%
                end
                
                if math.random() <= dislocateChance then
                    canDislocate = true
                end
            end
            
            if canDislocate or canBreak then
                local targetLimb = nil
                local limbName = ""
                
                -- Determine which limb was hit
                if hitgroup == HITGROUP_LEFTLEG then
                    targetLimb = "LeftLeg"
                    limbName = "left leg"
                elseif hitgroup == HITGROUP_RIGHTLEG then
                    targetLimb = "RightLeg" 
                    limbName = "right leg"
                elseif hitgroup == HITGROUP_LEFTARM then
                    targetLimb = "LeftArm"
                    limbName = "left arm"
                elseif hitgroup == HITGROUP_RIGHTARM then
                    targetLimb = "RightArm"
                    limbName = "right arm"
                elseif hitgroup == HITGROUP_HEAD then
                    -- Handle jaw damage separately
                    local jawBone = ent:LookupBone('ValveBiped.Bip01_Head1')
                    if jawBone then
                        local jawPos, jawAng = ent:GetBonePosition(jawBone)
                        local jawMin, jawMax = GetAdjustedOrganOBB(ent, "jaw")
                local hitJaw = util.IntersectRayWithOBB(dmginfo:GetDamagePosition(), dmginfo:GetDamageForce() * 0.01, jawPos, jawAng, jawMin, jawMax)
                        
                        if hitJaw then
                            targetLimb = "Jaw"
                            limbName = "jaw"
                            if ply.Organs['jaw'] == 0 then
                                RADS_AddThought(ply, RandomThought(organThoughts.jaw), 0.8, false)
                            end
                        end
                    end
                end
                
                if targetLimb and ply[targetLimb] then
                    local currentHealth = ply[targetLimb]
                    local msgTimer = "msg" .. targetLimb
                    
                    -- Prevent spam messages
                    if ply[msgTimer] and ply[msgTimer] > CurTime() then return end
                    ply[msgTimer] = CurTime() + 2
                    
                    local damageReduction = damage / 15  -- Reduced damage impact
                    
                    -- Club weapons cause more limb damage
                    if dmginfo:IsDamageType(DMG_CLUB) then
                        damageReduction = damage / 8  -- Clubs cause more severe limb damage
                    end
                    
                    -- Crush damage can break/dislocate jaw with 1.3x multiplier
                    if dmginfo:IsDamageType(DMG_CRUSH) and targetLimb == "Jaw" then
                        damageReduction = (damage * 2.0) / 12  -- Crush damage with 1.3x multiplier for jaw
                    end
                    
                    local newHealth = math.max(0, currentHealth - damageReduction)
                    
                    -- Determine current state
                    local wasHealthy = currentHealth > 0.8
                    local wasDislocated = currentHealth <= 0.8 and currentHealth > 0.4
                    local wasBroken = currentHealth <= 0.4
                    
                    -- Determine new state
                    local isHealthy = newHealth > 0.8
                    local isDislocated = newHealth <= 0.8 and newHealth > 0.4
                    local isBroken = newHealth <= 0.4
                    
                    ply[targetLimb] = newHealth
                    
                    -- Only trigger effects if state changed
                    if wasHealthy and (isDislocated or isBroken) then
                        -- First time injury
                        if canBreak and isBroken then
                            -- Broken (severe) - NEW DELAYED PAIN SYSTEM
                            ent:EmitSound("bones/bone" .. math.random(1,8) .. ".mp3", 100, math.random(70,90), 1, CHAN_ITEM)
                            ply.pain = ply.pain + 30  -- Initial pain (reduced from 150)
                            ply.pulse = ply.pulse + 80  -- Increased pulse
                            UpdateAdrenaline(ply, 60)  -- High adrenaline
                            RADS_AddThought(ply, GetLimbThought(limbName, false, true), 0.9, false)
                            
                            -- Special effect for jaw break: rapid consciousness depletion
                            if targetLimb == "Jaw" and SERVER then
                                StartJawConsciousnessDepletion(ply)
                            end
                            
                            -- Schedule delayed pain kick-in (1-5 seconds)
                            local delayTime = math.random(1, 5)
                            timer.Create("RADS_DelayedBonePain_" .. ply:EntIndex() .. "_" .. targetLimb, delayTime, 1, function()
                                if IsValid(ply) and ply:Alive() and ply:Health() > 0 and not ply:GetNWBool('radsfa') then
                                    ply.pain = ply.pain + 80  -- Additional pain (reduced from 400)
                                else
                                    -- Clean up timer if player is dead/invalid
                                    timer.Remove("RADS_DelayedBonePain_" .. ply:EntIndex() .. "_" .. targetLimb)
                                end
                            end)
                        else
                            -- Dislocated (moderate) - ALSO GETS DELAYED PAIN
                            ent:EmitSound("bones/bone" .. math.random(1,8) .. ".mp3", 80, math.random(90,110), 0.8, CHAN_ITEM)
                            ply.pain = ply.pain + 60  -- Initial pain (reduced from 300)
                            ply.pulse = ply.pulse + 50  -- Current pulse increase
                            UpdateAdrenaline(ply, 30)  -- Moderate adrenaline
                            RADS_AddThought(ply, GetLimbThought(limbName, true, false), 0.7, false)
                            
                            -- Schedule delayed pain kick-in for dislocation (1-5 seconds)
                            local delayTime = math.random(1, 3)
                            timer.Create("RADS_DelayedBonePain_" .. ply:EntIndex() .. "_" .. targetLimb .. "_dislocated", delayTime, 1, function()
                                if IsValid(ply) and ply:Alive() and ply:Health() > 0 and not ply:GetNWBool('radsfa') then
                                    ply.pain = ply.pain + 100  -- Additional pain (reduced from 500)
                                    ply:EmitSound("player/pl_pain" .. math.random(1, 4) .. ".wav", 60, math.random(90, 110), 0.6)
                                else
                                    -- Clean up timer if player is dead/invalid
                                    timer.Remove("RADS_DelayedBonePain_" .. ply:EntIndex() .. "_" .. targetLimb .. "_dislocated")
                                end
                            end)
                        end
                    elseif wasDislocated and isBroken then
                        -- Escalation from dislocated to broken - DELAYED PAIN SYSTEM
                        ent:EmitSound("bones/bone" .. math.random(1,8) .. ".mp3", 100, math.random(60,80), 1, CHAN_ITEM)
                        ply.pain = ply.pain + 50  -- Initial additional pain (reduced from 250)
                        ply.pulse = ply.pulse + 40  -- Additional pulse
                        UpdateAdrenaline(ply, 40)  -- Additional adrenaline
                        RADS_AddThought(ply, GetLimbThought(limbName, false, true), 0.8, false)
                        
                        -- Special effect for jaw break escalation: rapid consciousness depletion
                        if targetLimb == "Jaw" and SERVER then
                            StartJawConsciousnessDepletion(ply)
                        end
                        
                        -- Schedule delayed pain kick-in for escalation (1-5 seconds)
                        local delayTime = math.random(1, 5)
                        timer.Create("RADS_DelayedBonePain_" .. ply:EntIndex() .. "_" .. targetLimb .. "_escalation", delayTime, 1, function()
                            if IsValid(ply) and ply:Alive() and ply:Health() > 0 and not ply:GetNWBool('radsfa') then
                                ply.pain = ply.pain + 120  -- Additional pain (reduced from 600)
                                ply:EmitSound("player/pl_pain" .. math.random(5, 7) .. ".wav", 70, math.random(80, 120), 0.8)
                                RADS_AddThought(ply, "Your broken " .. limbName .. " sends waves of agony!", 0.8, false)
                            else
                                -- Clean up timer if player is dead/invalid
                                timer.Remove("RADS_DelayedBonePain_" .. ply:EntIndex() .. "_" .. targetLimb .. "_escalation")
                            end
                        end)
                    end
                    
                    -- Apply debuffs based on current state
                    ApplyLimbDebuffs(ply, targetLimb, limbName, isDislocated, isBroken)
                end
            end
        end
    end

    local skullHealth = ply.Organs and ply.Organs['skull'] or 0
    local brainHealth = ply.Organs and ply.Organs['brain'] or 0
    local jawHealth = ply.Organs and ply.Organs['jaw'] or 0
    local originalDmg = dmginfo:GetDamage()
    local dmgpos = dmginfo:GetDamagePosition()
    local penetration = dmginfo:GetDamageForce()

    if dmginfo:IsDamageType(DMG_BULLET + DMG_SLASH) then
        penetration:Mul(0.015)
    else
        penetration:Mul(0.004)
    end

    -- A new, unified logic for head trauma (jaw, skull, and brain).
    if hitgroup == HITGROUP_HEAD then
        local currentDmg = originalDmg

        -- If damage is from a fall, multiply the damage to make skull fracture more likely.
        if dmginfo:IsDamageType(DMG_CRUSH) then
            currentDmg = currentDmg * 0.6  -- Increased from 1 to 1.3 to make fall damage more likely to break skull
        end
        
        local damageAbsorbedBySkull = 0
        local damageToBrain = 0  -- Initialize to 0, only set if skull is broken
        local skullDamage = 0
        
        -- Handle skull damage for different damage types
        if dmginfo:IsDamageType(DMG_BULLET) and currentDmg > 15 then
            -- Bullet damage: damage skull first, then brain if skull breaks
            skullDamage = currentDmg
            if skullHealth > 0 then
                -- Skull absorbs damage
                damageAbsorbedBySkull = math.min(skullHealth, skullDamage)
                ply.Organs['skull'] = skullHealth - damageAbsorbedBySkull
                
                -- If damage exceeds skull health, remaining goes to brain
                if skullDamage > skullHealth then
                    damageToBrain = skullDamage - skullHealth
                end
            else
                -- Skull already broken, all damage goes to brain
                damageToBrain = currentDmg
            end
        elseif dmginfo:IsDamageType(DMG_CRUSH) and currentDmg > 20 then
            -- Fall damage: damage skull first, then brain if skull breaks
            skullDamage = currentDmg * 0.8  -- 80% of fall damage goes to skull
            if skullHealth > 0 then
                damageAbsorbedBySkull = math.min(skullHealth, skullDamage)
                ply.Organs['skull'] = skullHealth - damageAbsorbedBySkull
                
                -- If damage exceeds skull health, remaining goes to brain
                if skullDamage > skullHealth then
                    damageToBrain = skullDamage - skullHealth
                end
            else
                -- Skull already broken, damage goes to brain
                damageToBrain = currentDmg * 0.8
            end
        elseif dmginfo:IsDamageType(DMG_CLUB) and currentDmg > 15 then
            -- Club damage: damage skull first, then brain if skull breaks
            skullDamage = currentDmg * 0.9  -- 90% of club damage goes to skull
            
            -- Check if weapon is non-lethal to prevent brain penetration
            local isNonlethal = false
            local attacker = dmginfo:GetAttacker()
            if IsValid(attacker) and attacker:IsPlayer() then
                local weapon = attacker:GetActiveWeapon()
                if IsValid(weapon) then
                    -- Check MDHomicideNonlethal table first, then SWEP property
                    if GetMDHomicideNonlethal and GetMDHomicideNonlethal(weapon:GetClass()) then
                        isNonlethal = true
                    elseif weapon.Nonlethal then
                        isNonlethal = true
                    end
                end
            end
            
            if skullHealth > 0 then
                damageAbsorbedBySkull = math.min(skullHealth, skullDamage)
                ply.Organs['skull'] = skullHealth - damageAbsorbedBySkull
                
                -- Non-lethal weapons don't penetrate to brain even if skull breaks
                if not isNonlethal and skullDamage > skullHealth then
                    damageToBrain = skullDamage - skullHealth
                end
            else
                -- Skull already broken, damage goes to brain (unless non-lethal)
                if not isNonlethal then
                    damageToBrain = currentDmg * 0.9
                end
            end
        elseif dmginfo:IsDamageType(DMG_BLAST) and currentDmg > 25 then
            -- Blast damage: damage skull first, then brain if skull breaks
            skullDamage = currentDmg * 0.7  -- 70% of blast damage goes to skull
            if skullHealth > 0 then
                damageAbsorbedBySkull = math.min(skullHealth, skullDamage)
                ply.Organs['skull'] = skullHealth - damageAbsorbedBySkull
                
                -- If damage exceeds skull health, remaining goes to brain
                if skullDamage > skullHealth then
                    damageToBrain = skullDamage - skullHealth
                end
            else
                -- Skull already broken, damage goes to brain
                damageToBrain = currentDmg * 0.7
            end
        else
            -- For all other damage types, damage skull first, then brain if skull breaks
            skullDamage = currentDmg
            if skullHealth > 0 then
                damageAbsorbedBySkull = math.min(skullHealth, skullDamage)
                ply.Organs['skull'] = skullHealth - damageAbsorbedBySkull
                
                -- If damage exceeds skull health, remaining goes to brain
                if skullDamage > skullHealth then
                    damageToBrain = skullDamage - skullHealth
                end
            else
                -- Skull already broken, all damage goes to brain
                damageToBrain = currentDmg
            end
        end

        -- Only damage brain if skull is broken (health <= 0) and there's damage to apply
        if damageToBrain > 0 and ply.Organs['skull'] <= 0 then
            -- Only damage brain if it's a penetrating hit
            local brainBone = ent:LookupBone('ValveBiped.Bip01_Head1')
            local brainPos, brainAng = ent:GetBonePosition(brainBone)
            local brainMin, brainMax = GetAdjustedOrganOBB(ent, "brain")
            local hitBrain = util.IntersectRayWithOBB(dmgpos, penetration, brainPos, brainAng, brainMin, brainMax)

            if hitBrain then
                ply.Organs['brain'] = math.max(0, brainHealth - damageToBrain)
            end
        end

        if ply.Organs['skull'] == 0 and skullHealth > 0 then
            ent:EmitSound("bones/bone8.mp3", 100, 100, 1, CHAN_ITEM)
            -- Skull break: removed ChatPrint for immersion, only play sound and apply effects
            RADS_AddThought(ply, RandomThought(organThoughts.skull), 0.9, false)
            ply.pain = ply.pain + 80
            -- NEW: Trigger adrenaline for skull fracture
            if SERVER then
                UpdateAdrenaline(ply, 80) -- 30 adrenaline for skull fracture
            end
            -- Start rapid consciousness depletion when skull breaks
            print(string.format("[SKULL BREAK] %s skull broken! Starting rapid consciousness depletion.", ply:Name()))
            -- Only 30% chance for brain hemorrhage when skull is broken
            -- DISABLED BY USER REQUEST - User wants to create a new brain hemorrhage system
            --[[ DISABLED BRAIN HEMORRHAGE TRIGGER
        if math.random() < 0.3 then
            if SERVER and not ply.BrainDamageFXActive then -- Only send if FX are not already active
                net.Start("RADS_BrainDamageFX")
                net.Send(ply)
                ply.BrainDamageFXActive = true
                ply.BrainDamageStartTime = CurTime() -- Track when brain damage started
            end
        end
            --]]
    -- Changed: Only allow stopping brain damage after it's been active for at least 5 seconds
    elseif ply.Organs['skull'] > 0 and ply.BrainDamageFXActive and (ply.BrainDamageStartTime and CurTime() - ply.BrainDamageStartTime > 5) then
        if SERVER then
            net.Start("RADS_StopBrainDamageFX")
            net.Send(ply)
            ply.BrainDamageFXActive = false
            ply.BrainDamageStartTime = nil
        end
        end

        -- Eye damage handling for specific damage types
        local leftEyeHealth = ply.Organs and ply.Organs['left_eye'] or 0
        local rightEyeHealth = ply.Organs and ply.Organs['right_eye'] or 0
        
        if (dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_SLASH) or 
            dmginfo:IsDamageType(DMG_BUCKSHOT) or dmginfo:IsDamageType(DMG_CLUB) or 
            dmginfo:IsDamageType(DMG_BLAST)) and currentDmg > 5 then
            
            -- Check if left eye is hit
            local leftEyeBone = ent:LookupBone('ValveBiped.Bip01_Head1')
            if leftEyeBone then
                local leftEyePos, leftEyeAng = ent:GetBonePosition(leftEyeBone)
                local leftEyeMin, leftEyeMax = GetAdjustedOrganOBB(ent, "left_eye")
                local hitLeftEye = util.IntersectRayWithOBB(dmgpos, penetration, leftEyePos, leftEyeAng, leftEyeMin, leftEyeMax)
                
                if hitLeftEye and leftEyeHealth > 0 then
                    ply.Organs['left_eye'] = 0
                    
                    -- Synchronize organ health to client for overlay system
                    if SERVER then
                        ply:SetNWInt("LeftEyeHealth", 0)
                    end
                    
                    RADS_AddThought(ply, RandomThought(organThoughts.left_eye), 0.9, false)
                    ply.pain = ply.pain + 100
                    -- Trigger fear and screen shake
                    if SERVER then
                        ply.fear = 100 -- Max fear
                        
                        -- Start 4-minute continuous fear effect
                        StartContinuousFearEffect(ply, "left_eye")
                        
                        -- Start rapid consciousness depletion
                        StartEyeConsciousnessDepletion(ply, "left_eye")
                        
                        net.Start("RADS_EyeLossShake")
                        net.WriteString("left")
                        net.Send(ply)
                    end
                end
            end
            
            -- Check if right eye is hit
            local rightEyeBone = ent:LookupBone('ValveBiped.Bip01_Head1')
            if rightEyeBone then
                local rightEyePos, rightEyeAng = ent:GetBonePosition(rightEyeBone)
                local rightEyeMin, rightEyeMax = GetAdjustedOrganOBB(ent, "right_eye")
                local hitRightEye = util.IntersectRayWithOBB(dmgpos, penetration, rightEyePos, rightEyeAng, rightEyeMin, rightEyeMax)
                
                if hitRightEye and rightEyeHealth > 0 then
                    ply.Organs['right_eye'] = 0
                    
                    -- Synchronize organ health to client for overlay system
                    if SERVER then
                        ply:SetNWInt("RightEyeHealth", 0)
                    end
                    
                    RADS_AddThought(ply, RandomThought(organThoughts.right_eye), 0.9, false)
                    ply.pain = ply.pain + 100
                    -- Trigger fear and screen shake
                    if SERVER then
                        ply.fear = 100 -- Max fear
                        
                        -- Start 4-minute continuous fear effect
                        StartContinuousFearEffect(ply, "right_eye")
                        
                        -- Start rapid consciousness depletion
                        StartEyeConsciousnessDepletion(ply, "right_eye")
                        
                        net.Start("RADS_EyeLossShake")
                        net.WriteString("right")
                        net.Send(ply)
                    end
                end
            end
        end

        -- We set the damage to 0 because we have manually handled it via organ health.
        -- This prevents the player from taking normal health damage on top of organ damage.
        dmginfo:SetDamage(0)
    end
    
    -- Brain damage and kill logic
    if ply.Organs['brain'] ~= nil and ply.Organs['brain'] <= 0 and brainHealth > 0 then
        -- Brain damage: removed ChatPrint for immersion, only play sound and apply effects
        RADS_AddThought(ply, RandomThought(organThoughts.brain), 1.0, false)
        if SERVER then -- Send brain death sound to client
            net.Start("RADS_BrainDeathSound")
            net.Send(ply)
            -- Only apply rigor mortis rarely, and if brain death
            if math.random() < 0.6 then -- 10% chance
                ply.rigorMortis = true -- Set rigor mortis flag for brain death
                -- 30% chance to trigger agonal breathing when rigor mortis occurs
                if math.random() < 0.3 then
                    StartAgonalBreathing(ply)
                end
            end
        end
        TriggerDeathState(ply)
    end
    


    local penetration_local = dmginfo:GetDamageForce()
    if dmginfo:IsDamageType(DMG_BULLET + DMG_SLASH) then
        penetration_local:Mul(0.015)
    else
        penetration_local:Mul(0.004)
    end

    if not rag or (rag and not dmginfo:IsDamageType(DMG_CRUSH)) then
        local dmg_local = dmginfo:GetDamage()

        -- Apply damage reduction to inner organs if ribs were hit
        local ribsMin, ribsMax = GetAdjustedOrganOBB(ent, "ribs")
        local spine2Bone = ent:LookupBone('ValveBiped.Bip01_Spine2')
        if spine2Bone then
            local ribsHit = util.IntersectRayWithOBB(dmgpos, penetration, ent:GetBonePosition(spine2Bone), ent:GetBoneMatrix(spine2Bone):GetAngles(), ribsMin, ribsMax)
        else
            print("[TRAUMA DEBUG] Entity missing ValveBiped.Bip01_Spine2 bone for ribs check")
            local ribsHit = false
        end
        if ribsHit then
            if dmginfo:IsDamageType(DMG_BULLET) then
                dmg_local = dmg_local * 0.5 -- 50% damage to inner organs
            elseif dmginfo:IsDamageType(DMG_SLASH) then
                dmg_local = dmg_local * 0.3 -- 30% damage to inner organs
            elseif dmginfo:IsDamageType(DMG_CLUB) then
                dmg_local = dmg_local * 0.4 -- 40% damage to inner organs
            elseif dmginfo:IsDamageType(DMG_BLAST) then
                dmg_local = dmg_local * 0.7 -- 70% damage to inner organs
            end
        end

        if hitgroup == HITGROUP_HEAD and math.random(1, math.max(math.floor(dmginfo:GetDamage()), 1)) == 1 and dmginfo:IsDamageType(DMG_BULLET + DMG_SLASH + DMG_CLUB + DMG_GENERIC + DMG_BUCKSHOT) then
            timer.Simple(0.01, function()
                local wep = ply:GetActiveWeapon()
                if ply:Alive() and not ply.fake and (IsValid(wep) and (not wep.GetBlocking or not wep:GetBlocking())) then
                    -- Trigger headshot blood particles if skull is broken, otherwise regular blood
                    if ply.Organs and ply.Organs['skull'] and ply.Organs['skull'] <= 0 then
                        -- Skull is broken - trigger headshot blood particles
                        if BloodParticleHeadshoot and dmginfo and IsValid(dmginfo) then
                            local damagePos = dmginfo:GetDamagePosition()
                            local damageForce = dmginfo:GetDamageForce()
                            if damagePos and damageForce then
                                BloodParticleHeadshoot(damagePos, damageForce:GetNormalized() * 50)
                            end
                        end
                        rads(ply)
                    else
                        -- Skull intact - regular blood particles
                        rads(ply)
                    end
                    ply.pulse = ply.pulse + 35
                end
            end)
        end
        
        -- NEW: Consciousness loss from head trauma and blast damage
        if hitgroup == HITGROUP_HEAD then
            local consciousnessLoss = 0
            if dmginfo:IsDamageType(DMG_BULLET + DMG_SLASH + DMG_CLUB + DMG_GENERIC + DMG_BUCKSHOT) then
                consciousnessLoss = math.Clamp(dmginfo:GetDamage() * 0.8, 5, 25)
            elseif dmginfo:IsDamageType(DMG_BLAST) then
                consciousnessLoss = math.Clamp(dmginfo:GetDamage() * 1.2, 10, 40)
            end
            
            if consciousnessLoss > 0 and ply.consciousness then
                ply.consciousness = math.max(0, ply.consciousness - consciousnessLoss)
                ply:SetNWInt("PlayerConsciousness", math.floor(ply.consciousness))
            end
        end
        
        -- NEW: General blast trauma consciousness loss (affects whole body)
        if dmginfo:IsDamageType(DMG_BLAST) then
            local blastConsciousnessLoss = math.Clamp(dmginfo:GetDamage() * 0.5, 3, 20)
            if ply.consciousness then
                ply.consciousness = math.max(0, ply.consciousness - blastConsciousnessLoss)
                ply:SetNWInt("PlayerConsciousness", math.floor(ply.consciousness))
                -- Mark that this player took blast damage recently for unconsciousness tracking
                ply.lastBlastDamageTime = CurTime()
            end
        end
        
        -- NEW: General consciousness loss for all damage types (critical damage)
        if ply.consciousness then
            local generalConsciousnessLoss = 0
            local damage = dmginfo:GetDamage()
            
            -- Apply consciousness loss based on damage severity for all damage types
            if damage >= 50 then
                generalConsciousnessLoss = math.Clamp(damage * 0.4, 8, 20) -- Severe damage
            elseif damage >= 30 then
                generalConsciousnessLoss = math.Clamp(damage * 0.3, 5, 15) -- Heavy damage
            elseif damage >= 20 then
                generalConsciousnessLoss = math.Clamp(damage * 0.2, 3, 10) -- Moderate damage
            elseif damage >= 10 then
                generalConsciousnessLoss = math.Clamp(damage * 0.1, 1, 5) -- Light damage
            end
            
            -- Apply hitgroup modifiers for general consciousness loss
            if hitgroup == HITGROUP_HEAD then
                generalConsciousnessLoss = generalConsciousnessLoss * 1.5 -- Head hits are more severe
            elseif hitgroup == HITGROUP_CHEST then
                generalConsciousnessLoss = generalConsciousnessLoss * 1.2 -- Chest hits affect breathing
            elseif hitgroup == HITGROUP_STOMACH then
                generalConsciousnessLoss = generalConsciousnessLoss * 1.1 -- Gut shots are painful
            end
            
            -- Apply the consciousness loss
            if generalConsciousnessLoss > 0 then
                ply.consciousness = math.max(0, ply.consciousness - generalConsciousnessLoss)
                ply:SetNWInt("PlayerConsciousness", math.floor(ply.consciousness))
            end
        end

        local dmgpos_local = dmginfo:GetDamagePosition()
        local spine2Bone = ent:LookupBone('ValveBiped.Bip01_Spine2')
        if not spine2Bone then
            print("[TRAUMA DEBUG] Entity missing ValveBiped.Bip01_Spine2 bone for lung check")
            return
        end
        local pos, ang = ent:GetBonePosition(spine2Bone)
        local lung_left_min, lung_left_max = GetAdjustedOrganOBB(ent, "left_lung")
        local lung_right_min, lung_right_max = GetAdjustedOrganOBB(ent, "right_lung")

        local hitLeftLung = util.IntersectRayWithOBB(dmgpos, penetration, pos, ang, lung_left_min, lung_left_max)
        local hitRightLung = util.IntersectRayWithOBB(dmgpos, penetration, pos, ang, lung_right_min, lung_right_max)

        if hitLeftLung or hitRightLung then
            if hitLeftLung then
            -- Check if weapon is non-lethal
            local isNonlethal = false
            if dmginfo:IsDamageType(DMG_CLUB) then
                local attacker = dmginfo:GetAttacker()
                if IsValid(attacker) and attacker:IsPlayer() then
                    local weapon = attacker:GetActiveWeapon()
                    if IsValid(weapon) then
                        -- Check MDHomicideNonlethal table first, then SWEP property
                        if GetMDHomicideNonlethal and GetMDHomicideNonlethal(weapon:GetClass()) then
                            isNonlethal = true
                        elseif weapon.Nonlethal then
                            isNonlethal = true
                        end
                    end
                end
            end
            
            if ply.Organs['left_lung'] ~= 0 and not isNonlethal then
                ply.Organs['left_lung'] = math.max(ply.Organs['left_lung'] - dmg_local, 0)
                ply.pulse = ply.pulse + dmg_local / 15
                if ply.Organs['left_lung'] == 0 then
                    RADS_AddThought(ply, RandomThought(organThoughts.left_lung), 0.7, false)
                end
                -- NEW: Trigger adrenaline for lung damage
                if SERVER then
                    UpdateAdrenaline(ply, dmg_local * 0.8) -- Lung damage gives adrenaline based on damage
                end
                if ply:GetNWBool('radsfa') then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    rag.Blood = ply.Blood
                    RADS_Bleed(rag)
                else
                    ply.Blood = ply.Blood
                    RADS_Bleed(ply)
                end

                if ply.Organs['left_lung'] > 0 and ply.LungFailureOngoing then -- Reset flags when lung health recovers
                    ply.LungFailureOngoing = false
                    ply.LungsChatMsg1 = false
                    ply.LungsChatMsg2 = false
                    net.Start("RADS_StopLungFX")
                    net.Send(ply)
                    timer.Remove("RADS_LungFailureDeathTimer_" .. ply:EntIndex())
                end
            end
        end

            if hitRightLung then
                -- Check if weapon is non-lethal
                local isNonlethal = false
                if dmginfo:IsDamageType(DMG_CLUB) then
                    local attacker = dmginfo:GetAttacker()
                    if IsValid(attacker) and attacker:IsPlayer() then
                        local weapon = attacker:GetActiveWeapon()
                        if IsValid(weapon) then
                            -- Check MDHomicideNonlethal table first, then SWEP property
                            if GetMDHomicideNonlethal and GetMDHomicideNonlethal(weapon:GetClass()) then
                                isNonlethal = true
                            elseif weapon.Nonlethal then
                                isNonlethal = true
                            end
                        end
                    end
                end
                
                if ply.Organs['right_lung'] ~= 0 and not isNonlethal then
                    ply.Organs['right_lung'] = math.max(ply.Organs['right_lung'] - dmg_local, 0)
                    ply.pulse = ply.pulse + dmg_local / 15
                    if ply.Organs['right_lung'] == 0 then
                        RADS_AddThought(ply, RandomThought(organThoughts.right_lung), 0.7, false)
                    end
                    -- NEW: Trigger adrenaline for lung damage
                    if SERVER then
                        UpdateAdrenaline(ply, dmg_local * 0.8)
                    end
                    if ply:GetNWBool('radsfa') then
                        local rag = ply:GetNWEntity('player_ragdoll')
                        rag.Blood = ply.Blood
                        RADS_Bleed(rag)
                    else
                        ply.Blood = ply.Blood
                        RADS_Bleed(ply)
                    end

                    if ply.Organs['right_lung'] > 0 and ply.LungFailureOngoing then -- Reset flags when lung health recovers
                        ply.LungFailureOngoing = false
                        ply.LungsChatMsg1 = false
                        ply.LungsChatMsg2 = false
                        net.Start("RADS_StopLungFX")
                        net.Send(ply)
                        timer.Remove("RADS_LungFailureDeathTimer_" .. ply:EntIndex())
                    end
                end
            end
        end

        -- Remove lung failure death logic - COMMENTED OUT
        --[[
        if ply.Organs['left_lung'] <= 0 and ply.Organs['right_lung'] <= 0 and not ply.LungFailureOngoing then
            ply.LungFailureOngoing = true
            -- Timer for "Something is filling my lungs"
            timer.Simple(6, function()
                if IsValid(ply) and ply:Alive() and ply.LungFailureOngoing and not ply.LungsChatMsg1 then
                    RADS_AddThought(ply, "I can feel Blood filling my right lung..", 0.7, false)
                    ply.LungsChatMsg1 = true
                end
            end)

            -- Timer for "Im struggling to breathe" and starting wheeze sounds
            timer.Simple(10, function()
                if IsValid(ply) and ply:Alive() and ply.LungFailureOngoing and not ply.LungsChatMsg2 then
                    RADS_AddThought(ply, "Im struggling to breathe", 0.7, false)
                    ply.LungsChatMsg2 = true
                    -- Start wheeze sound loop
                    local function playWheezeSound()
                        if IsValid(ply) and ply:Alive() and ply.LungFailureOngoing then
                            net.Start("RADS_PlayLungWheeze")
                            net.WriteEntity(ply) -- Send player entity to client
                            net.Send(ply) -- Send only to this specific player
                            timer.Create("RADS_LungWheezeTimer_" .. ply:EntIndex(), math.Rand(5, 10), 1, playWheezeSound)
                        else
                            timer.Remove("RADS_LungWheezeTimer_" .. ply:EntIndex())
                        end
                    end
                    playWheezeSound() -- Play first sound immediately after "Im struggling to breathe" message

                    -- Start 2-minute brain damage timer
                    timer.Create("RADS_LungFailureDeathTimer_" .. ply:EntIndex(), 120, 1, function()
                        if IsValid(ply) and ply:Alive() and ply.LungFailureOngoing then
                            ply.pain = ply.pain + 200
                            RADS_AddThought(ply, "Your body collapses as your lungs give out.", 1, false) -- A new message for this final stage
                            timer.Simple(5, function()
                                if IsValid(ply) and ply:Alive() then
                                    ply.Organs['brain'] = 0
                                    RADS_AddThought(ply, "Your brain shuts down.", 1, false)
                                    ply:Kill()
                                end
                            end)
                        else
                            -- Clean up timer if player is dead/invalid
                            timer.Remove("RADS_LungFailureDeathTimer_" .. ply:EntIndex())
                        end
                        ply.LungFailureOngoing = false -- Reset flag after final effect
                        ply.LungsChatMsg1 = false -- Reset chat message flags
                        ply.LungsChatMsg2 = false
                    end)
                end
            end)
        end
        --]]

        local spine1Bone = ent:LookupBone('ValveBiped.Bip01_Spine1')
        if not spine1Bone then
            print("[TRAUMA DEBUG] Entity missing ValveBiped.Bip01_Spine1 bone for liver check")
            return
        end
        local pos, ang = ent:GetBonePosition(spine1Bone)
        local liverMin, liverMax = GetAdjustedOrganOBB(ent, "liver")
        local AAA = util.IntersectRayWithOBB(dmgpos_local, penetration_local, pos, ang, liverMin, liverMax)
        if AAA then
            if ply.Organs['liver'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['liver'] = math.max(ply.Organs['liver'] - dmg_local, 0)
                ply.pulse = ply.pulse + dmg_local / 10
                if ply.Organs['liver'] == 0 then
                    RADS_AddThought(ply, RandomThought(organThoughts.liver), 0.7, false)
                end
                -- NEW: Trigger adrenaline for liver damage
                if SERVER then
                    UpdateAdrenaline(ply, dmg_local * 1.2) -- Liver damage gives high adrenaline
                end
                -- New liver pain logic - FIXED: Added proper death checks
                timer.Simple(2, function()
                    if IsValid(ply) and ply:Alive() and ply:Health() > 0 and not ply:GetNWBool('radsfa') then
                        ply.pain = ply.pain + 70
                    end
                end)
            elseif ply.Organs['liver'] == 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                -- If liver is already at 0 health and takes damage again - FIXED: Added proper death checks
                timer.Simple(2, function()
                    if IsValid(ply) and ply:Alive() and ply:Health() > 0 and not ply:GetNWBool('radsfa') then
                        ply.pain = ply.pain + 85
                        if ply.Organs['liver'] == 0 then
                            RADS_AddThought(ply, RandomThought(organThoughts.liver), 0.7, false)
                        end
                    end
                end)
            end
        end

        local pos, ang = ent:GetBonePosition(ent:LookupBone('ValveBiped.Bip01_Spine1'))
        local stomachMin, stomachMax = GetAdjustedOrganOBB(ent, "stomach")
        local AAA = util.IntersectRayWithOBB(dmgpos_local, penetration_local, pos, ang, stomachMin, stomachMax)
        if AAA then
            if ply.Organs['stomach'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['stomach'] = math.max(ply.Organs['stomach'] - dmg_local, 0)
                ply.pulse = ply.pulse + dmg_local / 5
                if ply.Organs['stomach'] == 0 then
                    RADS_AddThought(ply, RandomThought(organThoughts.stomach), 0.7, false)
                end
                -- NEW: Trigger adrenaline for stomach damage
                if SERVER then
                    UpdateAdrenaline(ply, dmg_local * 0.9)
                end
                if ply.Organs['stomach'] == 0 then RADS_AddThought(ply, RandomThought(organThoughts.stomach), 0.7, false) end
            end
        end

        local pos, ang = ent:GetBonePosition(ent:LookupBone('ValveBiped.Bip01_Spine'))
        local intestinesMin, intestinesMax = GetAdjustedOrganOBB(ent, "intestines")
        local AAA = util.IntersectRayWithOBB(dmgpos_local, penetration_local, pos, ang, intestinesMin, intestinesMax)
        if AAA then
            if ply.Organs['intestines'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['intestines'] = math.max(ply.Organs['intestines'] - dmg_local, 0)
                ply.pulse = ply.pulse + dmg_local / 5
                if ply.Organs['intestines'] == 0 then
                    RADS_AddThought(ply, RandomThought(organThoughts.intestines), 0.7, false)
                end
                -- NEW: Trigger adrenaline for intestine damage
                if SERVER then
                    UpdateAdrenaline(ply, dmg_local * 0.7)
                end
                if ply:GetNWBool('radsfa') then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    rag.Blood = ply.Blood
                    RADS_Bleed(rag)
                else
                    ply.Blood = ply.Blood
                    RADS_Bleed(ply)
                end
            end
        end

        local pos, ang = ent:GetBonePosition(ent:LookupBone('ValveBiped.Bip01_Spine2'))
        local heartMin, heartMax = GetAdjustedOrganOBB(ent, "heart")
        local AAA = util.IntersectRayWithOBB(dmgpos_local, penetration_local, pos, ang, heartMin, heartMax)
        if AAA then
            if ply.Organs['heart'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['heart'] = math.max(ply.Organs['heart'] - dmg_local, 0)
                ply.pulse = ply.pulse - dmg_local
                if ply.Organs['heart'] == 0 then
                    RADS_AddThought(ply, RandomThought(organThoughts.heart), 0.7, false)
                end
                -- NEW: Trigger adrenaline for heart damage
                if SERVER then
                    UpdateAdrenaline(ply, dmg_local * 1.5) -- Heart damage gives very high adrenaline
                end
                if ply:GetNWBool('radsfa') then
                    local rag = ply:GetNWEntity('player_ragdoll')
                    rag.Blood = ply.Blood
                    RADS_Bleed(rag)
                else
                    ply.Blood = ply.Blood
                    RADS_Bleed(ply)
                end

                if ply.Organs['heart'] <= 0 then
                    -- FIXED: Added proper death checks and timer management
                    local timerName = "RADS_HeartFailure_" .. ply:EntIndex()
                    timer.Remove(timerName) -- Remove any existing timer
                    timer.Create(timerName, 3, 1, function()
                        if IsValid(ply) and ply:Alive() and ply:Health() > 0 then
                            RADS_AddThought(ply, "Your heart fails. ", 1, false)
                            TriggerDeathState(ply)
                        end
                        timer.Remove(timerName) -- Clean up timer
                    end)
                end
            end
        end

        if dmginfo:IsDamageType(DMG_BULLET + DMG_SLASH + DMG_BLAST + DMG_ENERGYBEAM + DMG_NEVERGIB + DMG_ALWAYSGIB + DMG_PLASMA + DMG_AIRBOAT + DMG_SNIPER + DMG_BUCKSHOT) then
            local pos, ang = ent:GetBonePosition(ent:LookupBone('ValveBiped.Bip01_Head1'))
            local arteryMin, arteryMax = GetAdjustedOrganOBB(ent, "artery")
            local AAA = util.IntersectRayWithOBB(dmgpos, penetration, pos, ang, arteryMin, arteryMax)
            local AAA2 = false -- Secondary artery check removed for simplicity
            if AAA or AAA2 then
                if ply.Organs['artery'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                    ply.Organs['artery'] = math.max(ply.Organs['artery'] - dmg_local, 0)
                    -- RADS_AddThought(ply, RandomThought(organThoughts.artery), 0.7, false) -- REMOVED
                    -- NEW: Trigger adrenaline for artery damage
                    if SERVER then
                        UpdateAdrenaline(ply, dmg_local * 1.3) -- Artery damage gives high adrenaline
                    end
                    ply.BloodLosing = ply.BloodLosing + 45
                end
            end
            -- Radial Artery Left damage logic
            local ra_l_bone = ent:LookupBone('ValveBiped.Bip01_L_Hand')
            local ra_l_pos, ra_l_ang = ent:GetBonePosition(ra_l_bone)
            local ra_l_min, ra_l_max = GetAdjustedOrganOBB(ent, "radial_artery_l")
            local hitRAL = util.IntersectRayWithOBB(dmgpos, penetration, ra_l_pos, ra_l_ang, ra_l_min, ra_l_max)

            if hitRAL and ply.Organs['radial_artery_l'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['radial_artery_l'] = math.max(ply.Organs['radial_artery_l'] - dmg_local, 0)
                -- RADS_AddThought(ply, RandomThought(organThoughts.radial_artery_l), 0.7, false) -- REMOVED
                ply.BloodLosing = ply.BloodLosing + 20 -- Less blood loss for radial artery
            end

            -- Radial Artery Right damage logic
            local ra_r_bone = ent:LookupBone('ValveBiped.Bip01_R_Hand')
            local ra_r_pos, ra_r_ang = ent:GetBonePosition(ra_r_bone)
            local ra_r_min, ra_r_max = GetAdjustedOrganOBB(ent, "radial_artery_r")
            local hitRAR = util.IntersectRayWithOBB(dmgpos, penetration, ra_r_pos, ra_r_ang, ra_r_min, ra_r_max)

            if hitRAR and ply.Organs['radial_artery_r'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['radial_artery_r'] = math.max(ply.Organs['radial_artery_r'] - dmg_local, 0)
                -- RADS_AddThought(ply, RandomThought(organThoughts.radial_artery_r), 0.7, false) -- REMOVED
                ply.BloodLosing = ply.BloodLosing + 20 -- Less blood loss for radial artery
            end

            -- Femoral Artery Left damage logic
            local fa_l_bone = ent:LookupBone('ValveBiped.Bip01_L_Thigh')
            local fa_l_pos, fa_l_ang = ent:GetBonePosition(fa_l_bone)
            local fa_l_min, fa_l_max = GetAdjustedOrganOBB(ent, "femoral_artery_l")
            local hitFAL = util.IntersectRayWithOBB(dmgpos, penetration, fa_l_pos, fa_l_ang, fa_l_min, fa_l_max)

            if hitFAL and ply.Organs['femoral_artery_l'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['femoral_artery_l'] = math.max(ply.Organs['femoral_artery_l'] - dmg_local, 0)
                -- RADS_AddThought(ply, RandomThought(organThoughts.femoral_artery_l), 0.7, false) -- REMOVED
                ply.BloodLosing = ply.BloodLosing + 30 -- Moderate blood loss for femoral artery
            end

            -- Femoral Artery Right damage logic
            local fa_r_bone = ent:LookupBone('ValveBiped.Bip01_R_Thigh')
            local fa_r_pos, fa_r_ang = ent:GetBonePosition(fa_r_bone)
            local fa_r_min, fa_r_max = GetAdjustedOrganOBB(ent, "femoral_artery_r")
            local hitFAR = util.IntersectRayWithOBB(dmgpos, penetration, fa_r_pos, fa_r_ang, fa_r_min, fa_r_max)

            if hitFAR and ply.Organs['femoral_artery_r'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['femoral_artery_r'] = math.max(ply.Organs['femoral_artery_r'] - dmg_local, 0)
                -- RADS_AddThought(ply, RandomThought(organThoughts.femoral_artery_r), 0.7, false) -- REMOVED
                ply.BloodLosing = ply.BloodLosing + 30 -- Moderate blood loss for femoral artery
            end

            -- Popliteal Artery Left damage logic
            local pa_l_bone = ent:LookupBone('ValveBiped.Bip01_L_Calf')
            local pa_l_pos, pa_l_ang = ent:GetBonePosition(pa_l_bone)
            local pa_l_min, pa_l_max = GetAdjustedOrganOBB(ent, "popliteal_artery_l")
            local hitPAL = util.IntersectRayWithOBB(dmgpos, penetration, pa_l_pos, pa_l_ang, pa_l_min, pa_l_max)

            if hitPAL and ply.Organs['popliteal_artery_l'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['popliteal_artery_l'] = math.max(ply.Organs['popliteal_artery_l'] - dmg_local, 0)
                -- RADS_AddThought(ply, RandomThought(organThoughts.popliteal_artery_l), 0.7, false) -- REMOVED
                ply.BloodLosing = ply.BloodLosing + 10 -- Very less blood loss for popliteal artery
            end

            -- Popliteal Artery Right damage logic
            local pa_r_bone = ent:LookupBone('ValveBiped.Bip01_R_Calf')
            local pa_r_pos, pa_r_ang = ent:GetBonePosition(pa_r_bone)
            local pa_r_min, pa_r_max = GetAdjustedOrganOBB(ent, "popliteal_artery_r")
            local hitPAR = util.IntersectRayWithOBB(dmgpos, penetration, pa_r_pos, pa_r_ang, pa_r_min, pa_r_max)

            if hitPAR and ply.Organs['popliteal_artery_r'] ~= 0 and not dmginfo:IsDamageType(DMG_CLUB) then
                ply.Organs['popliteal_artery_r'] = math.max(ply.Organs['popliteal_artery_r'] - dmg_local, 0)
                -- RADS_AddThought(ply, RandomThought(organThoughts.popliteal_artery_r), 0.7, false) -- REMOVED
                ply.BloodLosing = ply.BloodLosing + 10 -- Very less blood loss for popliteal artery
            end
        end

        RADS_SendINFO(ply)
        
        -- Spine damage detection (only for specific damage types)
        if dmginfo:IsDamageType(DMG_BLAST + DMG_CRUSH + DMG_FALL + DMG_BULLET + DMG_BUCKSHOT) then
            -- Upper spine damage detection
            local upperSpineBone = ent:LookupBone('ValveBiped.Bip01_Spine4')
            local upperSpinePos, upperSpineAng = ent:GetBonePosition(upperSpineBone)
            local upperSpineMin, upperSpineMax = GetAdjustedOrganOBB(ent, "upper_spine")
            local upperSpineHit = util.IntersectRayWithOBB(dmgpos, penetration, upperSpinePos, upperSpineAng, upperSpineMin, upperSpineMax)
            
            if upperSpineHit then
                if ply.Organs['upper_spine'] ~= 0 then
                    ply.Organs['upper_spine'] = math.Clamp(ply.Organs['upper_spine'] - dmg_local, 0, 1)
                    -- NEW: Trigger adrenaline for upper spine damage
                    if SERVER then
                        UpdateAdrenaline(ply, dmg_local * 1.8) -- Upper spine damage gives very high adrenaline
                    end
                    if ply.Organs['upper_spine'] == 0 then
                        timer.Simple(.4, function() if not ply.fake then rads(ply) end end)
                        ply.brokenupperspine = true
                        RADS_AddThought(ply, "Your upper spine is damaged.", 0.7, false)
                        ent:EmitSound("bones/bone5.mp3", 70, 125, 0.7, CHAN_ITEM)
                    end
                end
            end
            
            -- Lower spine damage detection
            local lowerSpineBone = ent:LookupBone('ValveBiped.Bip01_Spine2')
            local lowerSpinePos, lowerSpineAng = ent:GetBonePosition(lowerSpineBone)
            local lowerSpineMin, lowerSpineMax = GetAdjustedOrganOBB(ent, "lower_spine")
            local lowerSpineHit = util.IntersectRayWithOBB(dmgpos, penetration, lowerSpinePos, lowerSpineAng, lowerSpineMin, lowerSpineMax)
            
            if lowerSpineHit then
                if ply.Organs['lower_spine'] ~= 0 then
                    ply.Organs['lower_spine'] = math.Clamp(ply.Organs['lower_spine'] - dmg_local, 0, 1)
                    -- NEW: Trigger adrenaline for lower spine damage
                    if SERVER then
                        UpdateAdrenaline(ply, dmg_local * 1.8) -- Lower spine damage gives very high adrenaline
                    end
                    if ply.Organs['lower_spine'] == 0 then
                        timer.Simple(.4, function() if not ply.fake then rads(ply) end end)
                        ply.brokenspine = true
                        RADS_AddThought(ply, "Your lower spine is damaged.", 0.7, false)
                        ent:EmitSound("bones/bone5.mp3", 70, 125, 0.7, CHAN_ITEM)
                    end
                end
            end
        end
        
        -- Pelvis damage detection (accepts all damage types)
        local pelvisBone = ent:LookupBone('ValveBiped.Bip01_Pelvis')
        if pelvisBone then
            local pelvisPos, pelvisAng = ent:GetBonePosition(pelvisBone)
            local pelvisMin, pelvisMax = GetAdjustedOrganOBB(ent, "pelvis")
            local pelvisHit = util.IntersectRayWithOBB(dmgpos, penetration, pelvisPos, pelvisAng, pelvisMin, pelvisMax)
            
            if pelvisHit then
                if ply.Organs['pelvis'] and ply.Organs['pelvis'] > 0 then
                    local previousPelvisHealth = ply.Organs['pelvis']
                    ply.Organs['pelvis'] = math.max(0, ply.Organs['pelvis'] - dmg_local)
                    
                    -- Trigger adrenaline for pelvis damage
                    if SERVER then
                        UpdateAdrenaline(ply, dmg_local * 2.0) -- High adrenaline for pelvis damage
                    end
                    
                    -- Add pain for pelvis damage
                    ply.pain = ply.pain + (dmg_local * 15)
                    
                    -- Check if pelvis just broke
                    if ply.Organs['pelvis'] <= 0 and previousPelvisHealth > 0 then
                        ply.brokenpelvis = true
                        RADS_AddThought(ply, "Your pelvis is broken.", 0.9, false)
                        ent:EmitSound("bones/bone" .. math.random(1,8) .. ".mp3", 80, math.random(90,110), 1, CHAN_ITEM)
                        
                        -- Immediate knockover when pelvis breaks
                        if SERVER then
                            timer.Simple(0.1, function()
                                if IsValid(ply) and ply:Alive() and not ply.fake then
                                    rads(ply) -- Force ragdoll immediately
                                end
                            end)
                        end
                    elseif ply.Organs['pelvis'] > 0 then
                        -- Pelvis damaged but not broken
                        RADS_AddThought(ply, "Your pelvis is damaged.", 0.7, false)
                        ent:EmitSound("bones/bone" .. math.random(1,8) .. ".mp3", 60, math.random(100,120), 0.8, CHAN_ITEM)
                    end
                end
            end
        end
    end

    -- Ribs damage logic (protects lungs, heart, liver)
    local ribsBone = ent:LookupBone('ValveBiped.Bip01_Spine2')
    if not ribsBone then
        print("[TRAUMA DEBUG] Ribs bone not found for entity: " .. tostring(ent))
        return -- Skip ribs damage if bone doesn't exist
    end
    
    local ribsPos, ribsAng = ent:GetBonePosition(ribsBone)
    local ribsMin, ribsMax = GetAdjustedOrganOBB(ent, "ribs")
    local hitRibs = util.IntersectRayWithOBB(dmgpos, penetration, ribsPos, ribsAng, ribsMin, ribsMax)

    if hitRibs then
        local currentRibHealth = ply.Organs['ribs'] or 0
        local oldBrokenRibs = ply._brokenRibs or 0
        local damageToRibs = originalDmg

        -- Apply multiplier for DMG_SLASH
        if dmginfo:IsDamageType(DMG_SLASH) then
            damageToRibs = damageToRibs * 0.10
        end
        
        -- Apply multiplier for DMG_CRUSH (crush damage can break ribs with 1.3x multiplier)
        if dmginfo:IsDamageType(DMG_CRUSH) then
            damageToRibs = damageToRibs * 1.3
        end

        -- Only apply damage if it's one of the allowed types
        if dmginfo:IsDamageType(DMG_CRUSH + DMG_BLAST + DMG_BULLET + DMG_CLUB + DMG_SLASH) then
            if currentRibHealth > 0 then
                local previousRibHealth = currentRibHealth
                ply.Organs['ribs'] = math.max(0, currentRibHealth - damageToRibs)
                local damageAbsorbedByRibs = previousRibHealth - ply.Organs['ribs']
                
                local newlyBrokenRibs = math.floor(damageAbsorbedByRibs / 10)
                if newlyBrokenRibs > 0 then
                    -- NEW: Trigger adrenaline for rib breaks
                    UpdateAdrenaline(ply, newlyBrokenRibs * 8) -- 8 adrenaline per broken rib
                    
                    -- Update total broken ribs count first
                    ply._brokenRibs = math.min(24, oldBrokenRibs + newlyBrokenRibs)
                    
                    -- Show total broken ribs count in thought
                    local totalBrokenRibs = ply._brokenRibs
                    local ribThought = "You broke " .. totalBrokenRibs .. " ribs"
                    RADS_AddThought(ply, ribThought, 0.7, false)
                    
                    local soundTable = {"bones/bone1.mp3", "bones/bone2.mp3", "bones/bone3.mp3", "bones/bone4.mp3", "bones/bone5.mp3", "bones/bone6.mp3", "bones/bone7.mp3", "bones/bone8.mp3"}
                    local randomSound = soundTable[math.random(1, #soundTable)]
                    ent:EmitSound(randomSound, 50, 125, 1, CHAN_ITEM)

                    -- Apply realistic pain system for rib breaks
                    local ribPainAmount = newlyBrokenRibs * 85
                    local damageIntensity = ribPainAmount
                    
                    -- Check for severe rib damage (instant pain threshold)
                    if newlyBrokenRibs >= 3 or ribPainAmount >= 200 then
                        -- Severe rib breaks: instant pain + pain debt
                        local instantPain = ribPainAmount * 0.4 -- 40% instant
                        local painDebt = ribPainAmount * 0.6 -- 60% debt
                        
                        ply.pain = ply.pain + instantPain
                        ply.painDebt = (ply.painDebt or 0) + painDebt
                        ply.lastDamageTime = CurTime()
                        ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    else
                        -- Minor rib breaks: mostly pain debt
                        local instantPain = ribPainAmount * 0.1 -- 10% instant
                        local painDebt = ribPainAmount * 0.9 -- 90% debt
                        
                        ply.pain = ply.pain + instantPain
                        ply.painDebt = (ply.painDebt or 0) + painDebt
                        ply.lastDamageTime = CurTime()
                        ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    end
                end

                -- Reduce incoming damage for other organs if ribs are hit
                dmginfo:ScaleDamage(0.5) -- Ribs absorb 50% of the damage
                
                if ply.Organs['ribs'] == 0 and previousRibHealth > 0 then
                    local totalBrokenRibs = ply._brokenRibs or 0
                end
            end
        else
            -- If damage type is not allowed, do not damage ribs and do not scale damage
            dmginfo:ScaleDamage(1.0) 
        end
    end

    -- New lung damage wheeze system - triggers when BOTH lungs are at 0 health
    if ply.Organs['left_lung'] <= 0 and ply.Organs['right_lung'] <= 0 and not ply.LungWheezeActive then
        ply.LungWheezeActive = true
        
        -- Start wheeze sound loop immediately
        local function playWheezeSound()
            if IsValid(ply) and ply:Alive() and ply.LungWheezeActive and 
               ply.Organs['left_lung'] <= 0 and ply.Organs['right_lung'] <= 0 then
                -- Send wheeze sound to all nearby clients
                net.Start("RADS_PlayLungWheeze")
                net.WriteEntity(ply)
                net.Broadcast() -- Send to all clients for short-range entity sound
                
                -- Schedule next wheeze sound at random interval
                timer.Create("RADS_LungWheezeTimer_" .. ply:EntIndex(), math.Rand(3, 8), 1, playWheezeSound)
            else
                -- Stop wheeze sounds if conditions no longer met
                ply.LungWheezeActive = false
                timer.Remove("RADS_LungWheezeTimer_" .. ply:EntIndex())
            end
        end
        
        -- Start wheeze sounds immediately
        playWheezeSound()
    elseif (ply.Organs['left_lung'] > 0 or ply.Organs['right_lung'] > 0) and ply.LungWheezeActive then
        -- Stop wheeze sounds if either lung heals above 0
        ply.LungWheezeActive = false
        timer.Remove("RADS_LungWheezeTimer_" .. ply:EntIndex())
    end
end)

hook.Add("HomigradDamage", "BurnDamage", function(ply, hitgroup, dmginfo)
    if dmginfo:IsDamageType(DMG_BURN) then
        local dmg = dmginfo:GetDamage()
        ply.pulse = ply.pulse + dmg
        dmginfo:ScaleDamage(5)
    end
end)

hook.Add("EntityTakeDamage", "ragdmg", function(ent, dmginfo)
    if ent:IsPlayer() and ent:GetNWBool("gh.Ghosted", false) then return end
    if IsValid(ent:GetPhysicsObject()) and dmginfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT + DMG_CLUB + DMG_GENERIC + DMG_BLAST) then
        print(dmginfo:GetDamageForce()) -- print(dmginfo:GetDamageForce():GetNormalized(),"сила дмг11",dmginfo:GetDamage(),"урон11") -- ent:GetPhysicsObject():ApplyForceOffset(dmginfo:GetDamage(),dmginfo:GetDamagePosition())
        ent:GetPhysicsObject():ApplyForceOffset(dmginfo:GetDamageForce():GetNormalized() * math.min(dmginfo:GetDamage(), 3000), dmginfo:GetDamagePosition())
    end

    local ply = RagdollOwner(ent) or ent -- print(tostring(dmginfo:GetDamage()))
    if not ply or not ply:IsPlayer() or not ply:Alive() or ply:HasGodMode() then return end
    local rag = ply ~= ent and ent
    local physics_bone = GetPhysicsBoneDamageInfo(ent, dmginfo)
    local hitgroup
    local isfall
    local bonename = ent:GetBoneName(ent:TranslatePhysBoneToBone(physics_bone))
    ply.LastHitBoneName = bonename
    if bonetohitgroup[bonename] then hitgroup = bonetohitgroup[bonename] end
    local mul = RagdollDamageBoneMul[hitgroup]
    local entAtt = dmginfo:GetAttacker()
    local att = (entAtt:IsPlayer() and entAtt:Alive() and entAtt) or (entAtt:GetClass() == "wep" and entAtt:GetOwner())
    att = dmginfo:GetDamageType() ~= DMG_CRUSH and att or ply.LastAttacker
    ply.LastAttacker = att
    ply.LastHitGroup = hitgroup
    if dmginfo:IsDamageType(DMG_BLAST) then -- if not rag then --     return -- end
        dmginfo:ScaleDamage(2)
    end

    dmginfo:SetDamage(dmginfo:GetDamage())
    kekw = DamageInfo()
    kekw:SetAttacker(dmginfo:GetAttacker())
    
    -- Fix NULL entity error by validating inflictor
    local inflictor = dmginfo:GetInflictor()
    if IsValid(inflictor) then
        kekw:SetInflictor(inflictor)
    else
        kekw:SetInflictor(game.GetWorld()) -- Use world as fallback
    end
    
    kekw:SetDamage(dmginfo:GetDamage())
    kekw:SetDamageType(dmginfo:GetDamageType())
    kekw:SetDamagePosition(dmginfo:GetDamagePosition())
    kekw:SetDamageForce(dmginfo:GetDamageForce())
    if rag and mul then dmginfo:ScaleDamage(mul) end
    ply.LastDMGInfo = kekw
    local ply = RagdollOwner(ent) or ent
    if not ply.pulse then ply.pulse = 70 end
    
    -- Realistic pulse increase based on damage amount, type, and location
    local damage = dmginfo:GetDamage()
    local pulseIncrease = 0
    
    -- Base pulse increase based on damage severity
    if damage >= 50 then
        pulseIncrease = 25 -- Severe damage
    elseif damage >= 30 then
        pulseIncrease = 15 -- Heavy damage
    elseif damage >= 15 then
        pulseIncrease = 8 -- Moderate damage
    elseif damage >= 5 then
        pulseIncrease = 4 -- Light damage
    else
        pulseIncrease = 2 -- Minimal damage
    end
    
    -- Damage type modifiers
    if dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_BUCKSHOT) then
        pulseIncrease = pulseIncrease * 1.5 -- Bullets are more shocking
    elseif dmginfo:IsDamageType(DMG_BLAST) then
        pulseIncrease = pulseIncrease * 2.0 -- Explosions cause major shock
    elseif dmginfo:IsDamageType(DMG_BURN) then
        pulseIncrease = pulseIncrease * 1.3 -- Burns are painful
    end
    
    -- Hitgroup modifiers
    if hitgroup == HITGROUP_HEAD then
        pulseIncrease = pulseIncrease * 1.8 -- Head wounds are more shocking
    elseif hitgroup == HITGROUP_CHEST then
        pulseIncrease = pulseIncrease * 1.4 -- Chest wounds affect breathing
    elseif hitgroup == HITGROUP_STOMACH then
        pulseIncrease = pulseIncrease * 1.2 -- Gut shots are painful
    end
    
    -- Apply pulse increase with cap
    ply.pulse = math.min(200, ply.pulse + pulseIncrease)
    ply:SetNWInt("PlayerPulse", ply.pulse)
    if IsValid(rag) then 
        rag.pulse = math.min(200, (rag.pulse or 70) + pulseIncrease)
        rag:SetNWInt("PlayerPulse", rag.pulse)
    end
    
    -- Gore System: Head Explosion Detection
    if GetConVar("rads_gore_enable"):GetBool() and hitgroup == HITGROUP_HEAD then
        local headDamageThreshold = GetConVar("rads_gore_head_damage_threshold"):GetFloat()
        local damageType = dmginfo:GetDamageType()
        
        -- Explicitly exclude fall and crush damage from triggering head explosions
        if bit.band(damageType, DMG_FALL) > 0 or bit.band(damageType, DMG_CRUSH) > 0 or dmginfo:IsFallDamage() then
            -- Fall and crush damage should not cause head explosions
        elseif damage >= headDamageThreshold then
            -- Only allow head explosions for valid damage types and standing players
            local validDamageType = bit.band(damageType, DMG_CLUB) > 0 or 
                                   bit.band(damageType, DMG_BULLET) > 0 or 
                                   bit.band(damageType, DMG_BUCKSHOT) > 0
            
            -- Only trigger head explosion if player is standing (not ragdolled) and damage type is valid
            if validDamageType and not rag then
                -- Trigger head explosion gore effect
                RADS_TriggerHeadExplosion(ply, ply, dmginfo)
                -- Ensure instant death
                dmginfo:SetDamage(ply:Health() + 100)
            end
        end
    end
    
    dmginfo:ScaleDamage(1.2)
    hook.Run("HomigradDamage", ply, hitgroup, dmginfo, rag)
    RADS.PainSound(ent)
    dmginfo:ScaleDamage(0.2) -- RADS_PreRag(rag)
    if rag then
        if dmginfo:GetDamageType() == DMG_CRUSH then dmginfo:ScaleDamage(0.25) end -- 25% instead of 0.167%
        RADS_SendINFO(ply)
        ply:SetHealth(ply:Health() - dmginfo:GetDamage())
        if ply:Health() <= 0 then
            TriggerDeathState(ply) -- Ensure player enters death state when health reaches 0
            if ttt then
                rag = ply:GetNWEntity('player_ragdoll')
                ply:SetNWEntity('player_ragdoll', nil)
                rag:SetNWEntity('owner', nil)
                rag:Remove()
            end
        end
    end
end)

hook.Add('DoPlayerDeath', tostring(math.random(0, 9999)), function(ply)
    local rag = ply:GetNWEntity('player_ragdoll')
    
    -- Check if ragdoll entity is valid before accessing it
    if IsValid(rag) then
        rag.IsBleeding = true
        rag.Blood = ply.Blood / 10 -- rag.bloodNext = CurTime()
        RADS_Bleed(rag)
    end
    
    ply:SetNWBool('radsfa', false)
    ply:SetNWBool('brokenspine', false)
    
    -- Stop lung wheeze sounds on death
    ply.LungWheezeActive = false
    timer.Remove("RADS_LungWheezeTimer_" .. ply:EntIndex())
    
    if SERVER then
        net.Start("RADS_StopBrainDamageFX")
        net.Send(ply)
    end
end)

-- NEW: Function to apply limb-specific debuffs
function ApplyLimbDebuffs(ply, limbType, limbName, isDislocated, isBroken)
    if not IsValid(ply) then return end
    
    if limbType == "LeftLeg" or limbType == "RightLeg" then
        -- Leg debuffs
        local bothLegsDislocated = ply.LeftLeg <= 0.8 and ply.RightLeg <= 0.8
        local bothLegsBroken = ply.LeftLeg <= 0.4 and ply.RightLeg <= 0.4
        local oneDislocated = ply.LeftLeg <= 0.8 or ply.RightLeg <= 0.8
        local oneBroken = ply.LeftLeg <= 0.4 or ply.RightLeg <= 0.4
        
        if bothLegsBroken then
            -- Both legs broken: severe but not crippling
            ply:SetWalkSpeed(80)  -- Was 30, now 50% of normal
            ply:SetRunSpeed(125)  -- Was 50, now 50% of normal
        elseif bothLegsDislocated then
            -- Both legs dislocated: significant reduction
            ply:SetWalkSpeed(100) -- Was 60, now 62.5% of normal
            ply:SetRunSpeed(155)  -- Was 90, now 62% of normal
        elseif oneBroken then
            -- One leg broken: moderate reduction
            ply:SetWalkSpeed(110) -- Was 50, now 69% of normal
            ply:SetRunSpeed(175)  -- Was 80, now 70% of normal
        elseif oneDislocated then
            -- One leg dislocated: minor reduction
            ply:SetWalkSpeed(130) -- Was 80, now 81% of normal
            ply:SetRunSpeed(200)  -- Was 120, now 80% of normal
        else
            -- Normal mobility
            ply:SetWalkSpeed(160)
            ply:SetRunSpeed(250)
        end
        
    elseif limbType == "LeftArm" or limbType == "RightArm" then
        -- Arm debuffs - set NWBools for client-side effects
        ply:SetNWBool("RADS_LeftArmDislocated", ply.LeftArm <= 0.8 and ply.LeftArm > 0.4)
        ply:SetNWBool("RADS_RightArmDislocated", ply.RightArm <= 0.8 and ply.RightArm > 0.4)
        ply:SetNWBool("RADS_LeftArmBroken", ply.LeftArm <= 0.4)
        ply:SetNWBool("RADS_RightArmBroken", ply.RightArm <= 0.4)
        ply:SetNWBool("RADS_BothArmsDislocated", (ply.LeftArm <= 0.8 and ply.LeftArm > 0.4) and (ply.RightArm <= 0.8 and ply.RightArm > 0.4))
        ply:SetNWBool("RADS_BothArmsBroken", ply.LeftArm <= 0.4 and ply.RightArm <= 0.4)
        
    elseif limbType == "Jaw" then
        -- Jaw debuffs
        if isBroken then
            -- Broken jaw: severe speech impediment, can't eat/drink
            ply:SetNWBool("RADS_JawBroken", true)
            ply:SetNWBool("RADS_JawDislocated", false)
        elseif isDislocated then
            -- Dislocated jaw: moderate speech issues
            ply:SetNWBool("RADS_JawDislocated", true)
            ply:SetNWBool("RADS_JawBroken", false)
        else
            ply:SetNWBool("RADS_JawDislocated", false)
            ply:SetNWBool("RADS_JawBroken", false)
        end
    end
end

-- 1. Make dislocations harder and increase pain
local function IsLegDislocated(ply)
    return ply.LeftLeg <= 0.6 or ply.RightLeg <= 0.6
end
local function AreBothLegsDislocated(ply)
    return ply.LeftLeg <= 0.6 and ply.RightLeg <= 0.6
end
local function IsArmDislocated(ply)
    return ply.LeftArm <= 0.6 or ply.RightArm <= 0.6
end
local function AreBothArmsDislocated(ply)
    return ply.LeftArm <= 0.6 and ply.RightArm <= 0.6
end

if CLIENT then
    -- Thoughts system: store current thought and state
    RADS_Thoughts = RADS_Thoughts or {}
    RADS_CurrentThought = nil
    RADS_ThoughtFadeStart = 0
    RADS_ThoughtFadeDuration = 0.5 -- seconds
    RADS_ThoughtCutShort = false
    RADS_ThoughtScramble = false
    RADS_ThoughtIntensity = 0
    RADS_ThoughtText = ""
    RADS_ThoughtActive = false

    -- Receive a thought from the server
    net.Receive('RADS_AddThought', function()
        local text = net.ReadString()
        local intensity = net.ReadFloat()
        local scramble = net.ReadBool()
        RADS_ThoughtText = text
        RADS_ThoughtFadeStart = CurTime()
        RADS_ThoughtScramble = scramble
        RADS_ThoughtIntensity = intensity
        RADS_ThoughtActive = true
        RADS_ThoughtCutShort = false
    end)

    -- Function to cut short the current thought (for unconsciousness)
    function RADS_CutThoughtShort()
        if RADS_ThoughtActive and not RADS_ThoughtCutShort then
            -- Cut the text at current fade-in progress and add '-'
            local elapsed = CurTime() - RADS_ThoughtFadeStart
            local progress = math.Clamp(elapsed / RADS_ThoughtFadeDuration, 0, 1)
            local cutLen = math.max(1, math.floor(#RADS_ThoughtText * progress))
            RADS_ThoughtText = string.sub(RADS_ThoughtText, 1, cutLen) .. "-"
            RADS_ThoughtCutShort = true
        end
    end
end

-- Server-side function to send a thought to a player
if SERVER then
function RADS_AddThought(ply, text, intensity, scramble)
    if not IsValid(ply) then return end
    net.Start('RADS_AddThought')
    net.WriteString(text)
    net.WriteFloat(intensity or 0)
    net.WriteBool(scramble or false)
    net.Send(ply)
end
end

organThoughts = {
    jaw = {
        "Your jaw is dislocated.",
        "Your jaw is broken."
    },
    skull = {
        "Your skull is broken."
    },
    brain = {
        "Your brain is damaged."
    },
    left_lung = {
        "Your left lung is punctured.",
        "Your left lung is damaged."
    },
    right_lung = {
        "Your right lung is punctured.",
        "Your right lung is damaged."
    },
    liver = {
        "Your liver is damaged."
    },
    stomach = {
        "Your stomach is damaged."
    },
    intestines = {
        "Your intestines are damaged."
    },
    heart = {
        "Your heart is damaged."
    },
    spine = {
        "Your spine is damaged."
    },
    ribs = {
        "You feel a rib crack.",
        "You hear your ribs breaking.",
        "Sharp pain shoots through your chest.",
        "You feel multiple ribs snap."
    },
    bladder = {
        "Your bladder is damaged."
    },
    left_eye = {
        "Your left eye is destroyed.",
        "You can't see from your left eye.",
        "Your left eye is gone."
    },
    right_eye = {
        "Your right eye is destroyed.",
        "You can't see from your right eye.",
        "Your right eye is gone."
    },
    -- Limb-specific thoughts
    leftarm_dislocated = {
        "Your left arm is dislocated.",
    },
    leftarm_broken = {
        "Your left arm is broken.",
    },
    rightarm_dislocated = {
        "Your right arm is dislocated.",
    },
    rightarm_broken = {
        "Your right arm is broken.",
    },
    leftleg_dislocated = {
        "Your left leg is dislocated.",
    },
    leftleg_broken = {
        "Your left leg is broken.",
    },
    rightleg_dislocated = {
        "Your right leg is dislocated.",
    },
    rightleg_broken = {
        "Your right leg is broken.",
    }
}
function RandomThought(tbl) return tbl[math.random(1, #tbl)] end

-- Function to get limb-specific thought
function GetLimbThought(limbName, isDislocated, isBroken)
    local thoughtKey = ""
    
    if limbName == "left arm" then
        thoughtKey = isDislocated and "leftarm_dislocated" or "leftarm_broken"
    elseif limbName == "right arm" then
        thoughtKey = isDislocated and "rightarm_dislocated" or "rightarm_broken"
    elseif limbName == "left leg" then
        thoughtKey = isDislocated and "leftleg_dislocated" or "leftleg_broken"
    elseif limbName == "right leg" then
        thoughtKey = isDislocated and "rightleg_dislocated" or "rightleg_broken"
    elseif limbName == "jaw" then
        -- Handle jaw-specific messages
        if isBroken then
            return "Your jaw is broken."
        elseif isDislocated then
            return "Your jaw is dislocated."
        else
            return "You feel pain in your jaw."
        end
    else
        -- Return a generic fallback message for unrecognized limbs
        return "You feel pain in your " .. (limbName or "body") .. "."
    end
    
    -- Check if the thoughtKey exists in organThoughts before calling RandomThought
    if organThoughts[thoughtKey] and #organThoughts[thoughtKey] > 0 then
        return RandomThought(organThoughts[thoughtKey])
    else
        -- Return a generic fallback message if no thoughts are available
        return "You feel pain in your " .. (limbName or "body") .. "."
    end
end

-- vFire Integration Hooks
if SERVER then
    -- Add network string for stopping fire sounds
    util.AddNetworkString("RADS_StopFireSound")
    util.AddNetworkString("RADS_FireSpread")
    util.AddNetworkString("RADS_OrganBurn")
    
    -- Painkiller effect hook
    hook.Add("Think", "RADS_PainkillerEffect", function()
        for _, ply in pairs(player.GetAll()) do
            if IsValid(ply) and ply.painKillerEndTime and ply.painKillerEndTime > CurTime() then
                -- Painkiller is active, apply multiplier to new pain
                if ply.lastPainCheck and ply.pain and ply.lastPain then
                    local painIncrease = ply.pain - ply.lastPain
                    if painIncrease > 0 and ply.painKillerMultiplier then
                        -- Reduce the pain increase by the multiplier
                        local reducedIncrease = painIncrease * ply.painKillerMultiplier
                        ply.pain = ply.lastPain + reducedIncrease
                    end
                end
            elseif IsValid(ply) and ply.painKillerEndTime and ply.painKillerEndTime <= CurTime() then
                -- Painkiller effect has worn off
                ply.painKillerEndTime = nil
                ply.painKillerMultiplier = nil
                if ply.pain and ply.pain > 0 then
                end
            end
            
            -- Store current pain for next check
            if IsValid(ply) and ply.pain then
                ply.lastPain = ply.pain
                ply.lastPainCheck = CurTime()
            end
        end
    end)

    -- Hook when entity starts burning
    hook.Add("vFireEntityStartedBurning", "RADS_FireDamage", function(ent)
        if not vFireInstalled then return end
        
        local ply = RagdollOwner(ent) or (ent:IsPlayer() and ent)
        if not ply or not ply:IsPlayer() then return end
        
        -- Initialize fire spread system
        ply.FireSpreadAreas = ply.FireSpreadAreas or {}
        ply.FireSpreadTimer = ply.FireSpreadTimer or 0
        
        -- Add fire-related thoughts
        local fireThoughts = {
            -- Burning thoughts removed
        }
        
        -- RADS_AddThought(ply, fireThoughts[math.random(1, #fireThoughts)], 1.0, false)
        
        -- Increase pulse dramatically when catching fire
        ply.pulse = math.min(200, (ply.pulse or 70) + 40)
        ply:SetNWInt("PlayerPulse", ply.pulse)
        
        -- Trigger adrenaline from fire panic
        UpdateAdrenaline(ply, 60)
        
        -- Start fire damage and spreading timer
        local timerName = "RADS_FireDamage_" .. ply:EntIndex()
        timer.Create(timerName, 1.0, 0, function()
            if not IsValid(ply) or not ply:Alive() then
                timer.Remove(timerName)
                return
            end
            
            local targetEnt = ply:GetNWBool("radsfa") and ply:GetNWEntity("player_ragdoll") or ply
            if not IsValid(targetEnt) then
                timer.Remove(timerName)
                return
            end
            
            -- Check if still on fire
            local stillOnFire = false
            if vFireInstalled and vFireIsEntityBurning then
                stillOnFire = vFireIsEntityBurning(targetEnt)
            else
                stillOnFire = targetEnt:IsOnFire()
            end
            
            if not stillOnFire then
                timer.Remove(timerName)
                ply.FireSpreadAreas = {}
                ply.OrganBurnDamage = {}
                return
            end
            
            -- Fire spreading logic with random timing (1.5 to 4 seconds)
            ply.FireSpreadTimer = (ply.FireSpreadTimer or 0) + 1
            ply.FireSpreadInterval = ply.FireSpreadInterval or math.random(15, 40) / 10 -- 1.5 to 4.0 seconds
            
            if ply.FireSpreadTimer >= ply.FireSpreadInterval then
                ply.FireSpreadTimer = 0
                ply.FireSpreadInterval = math.random(15, 40) / 10 -- Set new random interval
                RADS_SpreadFire(ply, targetEnt)
            end
            
            -- Apply burn damage based on spread areas
            local spreadMultiplier = 1 + (#ply.FireSpreadAreas * 0.3) -- More spread = more damage
            local damage = math.floor(3 * spreadMultiplier) -- Reduced from 10 to 3 (70% less lethal damage)
            
            -- Apply organ burning damage
            RADS_ApplyOrganBurnDamage(ply, targetEnt)
            
            if targetEnt:IsPlayer() then
                -- Fix: Use proper DamageInfo for players too to avoid the error
                local dmgInfo = DamageInfo()
                dmgInfo:SetDamage(damage)
                dmgInfo:SetDamageType(DMG_BURN)
                dmgInfo:SetAttacker(ply.LastAttacker or game.GetWorld())
                dmgInfo:SetInflictor(game.GetWorld())
                dmgInfo:SetDamagePosition(targetEnt:GetPos())
                
                targetEnt:TakeDamageInfo(dmgInfo)
            else
                local dmgInfo = DamageInfo()
                dmgInfo:SetDamage(damage)
                dmgInfo:SetDamageType(DMG_BURN)
                dmgInfo:SetAttacker(ply.LastAttacker or game.GetWorld())
                dmgInfo:SetInflictor(game.GetWorld())
                dmgInfo:SetDamagePosition(targetEnt:GetPos())
                
                targetEnt:TakeDamageInfo(dmgInfo)
            end
            
            -- Increase pain from burning (more pain as fire spreads)
            -- Significantly increased pain from fire damage
            local basePain = math.random(45, 65) -- Increased from 25-35 to 80-120 (much higher base pain)
            local spreadPain = #ply.FireSpreadAreas * math.random(20, 30) -- Increased from 8-12 to 25-40 per spread area
            ply.pain = (ply.pain or 0) + (basePain + spreadPain)
        end)
        
        -- Fire persistence system - re-ignites fire periodically
        local function RADS_MaintainFire(ply, targetEnt)
            if not IsValid(ply) or not IsValid(targetEnt) then return end
            
            -- Check if fire should be maintained
            if #ply.FireSpreadAreas > 0 then
                -- 30% chance every 5 seconds to re-ignite if fire goes out
                if math.random(1, 100) <= 30 then
                    if CreateVFireEntFires then
                        CreateVFireEntFires(targetEnt, math.random(3, 6))
                    else
                        targetEnt:Ignite(300) -- Re-ignite for 5 minutes
                    end
                end
            end
        end
        
        timer.Create("RADS_FirePersistence_" .. ply:EntIndex(), 5.0, 0, function()
            if IsValid(ply) and ply:Alive() then
                local targetEnt = ply:GetNWBool("radsfa") and ply:GetNWEntity("player_ragdoll") or ply
                if IsValid(targetEnt) then
                    RADS_MaintainFire(ply, targetEnt)
                end
            else
                timer.Remove("RADS_FirePersistence_" .. ply:EntIndex())
            end
        end)
    end)
    

    
    -- New function for organ burning damage
    function RADS_ApplyOrganBurnDamage(ply, targetEnt)
        if not ply.OrganBurnDamage then ply.OrganBurnDamage = {} end
        
        -- Define organs that can be burned
        local organs = {
            "heart", "lungs", "liver", "kidneys", "stomach", 
            "intestines", "brain", "spleen", "pancreas"
        }
        
        -- Randomly damage organs over time (slower than external burning)
        if math.random(1, 100) <= 15 then -- 15% chance per second
            local organ = organs[math.random(1, #organs)]
            
            if not ply.OrganBurnDamage[organ] then
                ply.OrganBurnDamage[organ] = 0
            end
            
            -- Increase organ damage
            ply.OrganBurnDamage[organ] = ply.OrganBurnDamage[organ] + math.random(1, 3)
            
            -- Apply specific organ effects
            if organ == "heart" and ply.OrganBurnDamage[organ] > 10 then
                ply.pulse = math.min(250, (ply.pulse or 70) + 20)
                ply:SetNWInt("PlayerPulse", ply.pulse)
                
                local heartThoughts = {
                    -- Heart burning thoughts removed
                }
                RADS_AddThought(ply, heartThoughts[math.random(1, #heartThoughts)], 1.0, false)
                
            elseif organ == "lungs" and ply.OrganBurnDamage[organ] > 8 then
                ply.pain = (ply.pain or 0) + math.random(7, 9) -- Reduced from 35-45
                -- Lung burning thoughts removed
            elseif organ == "brain" and ply.OrganBurnDamage[organ] > 5 then
                ply.pain = (ply.pain or 0) + math.random(10, 13) -- Reduced from 50-65
                -- Brain burning thoughts removed
            elseif organ == "liver" and ply.OrganBurnDamage[organ] > 12 then
                -- Liver burning thoughts removed
            end
            
            -- Send organ burn notification to client
            net.Start("RADS_OrganBurn")
            net.WriteString(organ)
            net.WriteInt(ply.OrganBurnDamage[organ], 8)
            net.Send(ply)
        end
    end

    -- Fire spreading function
    function RADS_SpreadFire(ply, targetEnt)
        if not ply.FireSpreadAreas then ply.FireSpreadAreas = {} end
        
        -- Define body areas that fire can spread to
        local bodyAreas = {
            "chest", "left_arm", "right_arm", "left_leg", "right_leg", 
            "head", "back", "stomach", "left_hand", "right_hand"
        }
        
        -- Find areas not yet on fire
        local availableAreas = {}
        for _, area in ipairs(bodyAreas) do
            if not table.HasValue(ply.FireSpreadAreas, area) then
                table.insert(availableAreas, area)
            end
        end
        
        -- Spread to a new area if available
        if #availableAreas > 0 and #ply.FireSpreadAreas < #bodyAreas then
            local newArea = availableAreas[math.random(1, #availableAreas)]
            table.insert(ply.FireSpreadAreas, newArea)
            
            -- Create additional vFire on the entity
            if CreateVFireEntFires then
                CreateVFireEntFires(targetEnt, math.random(2, 4))
            end
            
            -- Send fire spread notification to client
            net.Start("RADS_FireSpread")
            net.WriteString(newArea)
            net.Send(ply)
            
            -- Add spreading thoughts
            local spreadThoughts = {
                -- Fire spreading thoughts removed
            }
            
            -- RADS_AddThought(ply, spreadThoughts[math.random(1, #spreadThoughts)], 1.0, false)
        end
    end
    
    -- Hook when entity stops burning
    hook.Add("vFireEntityStoppedBurning", "RADS_FireExtinguished", function(ent)
        if not vFireInstalled then return end
        
        local ply = RagdollOwner(ent) or (ent:IsPlayer() and ent)
        if not ply or not ply:IsPlayer() then return end
        
        -- Remove fire damage timer
        local timerName = "RADS_FireDamage_" .. ply:EntIndex()
        timer.Remove(timerName)
        
        -- Remove fire persistence timer
        timer.Remove("RADS_FirePersistence_" .. ply:EntIndex())
        
        -- Clear fire spread data and organ damage
        ply.FireSpreadAreas = {}
        ply.FireSpreadTimer = 0
        ply.OrganBurnDamage = {}
        
        -- Stop fire sound on client
        if IsValid(ply) then
            net.Start("RADS_StopFireSound")
            net.Send(ply)
        end
        
        -- Add relief thought
        local reliefThoughts = {
            -- Fire relief thoughts removed
        }
        
        -- RADS_AddThought(ply, reliefThoughts[math.random(1, #reliefThoughts)], 0.5, false)
    end)
    
    -- Rolling-based fire extinguishment system
    -- Track player movement for fire extinguishment
    local function RADS_TrackMovementForFireExtinguishment(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        local rag = ply:GetNWEntity('player_ragdoll')
        if not IsValid(rag) then return end
        
        -- Check if player is on fire
        local isOnFire = false
        if vFireInstalled and vFireIsEntityBurning then
            isOnFire = vFireIsEntityBurning(rag) or vFireIsEntityBurning(ply)
        else
            isOnFire = rag:IsOnFire() or ply:IsOnFire()
        end
        
        if not isOnFire then
            -- Reset movement tracking if not on fire
            ply.FireExtinguishMovement = nil
            ply.LastFireExtinguishPos = nil
            ply.FireExtinguishRolls = nil
            return
        end
        
        -- Initialize tracking variables
        ply.FireExtinguishMovement = ply.FireExtinguishMovement or 0
        ply.LastFireExtinguishPos = ply.LastFireExtinguishPos or rag:GetPos()
        ply.FireExtinguishRolls = ply.FireExtinguishRolls or 0
        ply.LastRollDirection = ply.LastRollDirection or 0
        
        -- Calculate movement since last check
        local currentPos = rag:GetPos()
        local movement = currentPos:Distance(ply.LastFireExtinguishPos)
        ply.LastFireExtinguishPos = currentPos
        
        -- Track rolling with direction changes for more realistic fire extinguishing
        local currentRollDirection = 0
        if ply:KeyDown(IN_MOVELEFT) then
            currentRollDirection = -1
        elseif ply:KeyDown(IN_MOVERIGHT) then
            currentRollDirection = 1
        end
        
        -- Count actual rolls (direction changes) and movement
        if currentRollDirection ~= 0 then
            ply.FireExtinguishMovement = ply.FireExtinguishMovement + movement
            
            -- Count direction changes as "rolls"
            if ply.LastRollDirection ~= 0 and ply.LastRollDirection ~= currentRollDirection then
                ply.FireExtinguishRolls = ply.FireExtinguishRolls + 1
            end
            
            ply.LastRollDirection = currentRollDirection
        else
            -- Reset roll direction when not rolling
            ply.LastRollDirection = 0
        end
        
        -- Balanced requirements for fire extinguishment
        local movementThreshold = 150 -- Reduced from 200 (easier to reach)
        local rollThreshold = 1 -- Reduced from 6 (fewer rolls needed)
        local extinguishChance = 0.8 -- Increased from 0.1 (better base chance)
        local requiredMovement = 250 -- Reduced from 500 (less movement needed)
        local requiredRolls = 4 -- Reduced from 12 (fewer rolls for max effectiveness)
        
        if ply.FireExtinguishMovement >= movementThreshold and ply.FireExtinguishRolls >= rollThreshold then
            local extinguishRoll = math.random()
            local movementBonus = math.min(ply.FireExtinguishMovement / requiredMovement, 1.0)
            local rollBonus = math.min(ply.FireExtinguishRolls / requiredRolls, 1.0)
            
            -- Combine movement and roll bonuses
            local finalChance = extinguishChance + (movementBonus * 0.25) + (rollBonus * 0.35) -- Up to 80% chance with good rolling
            
            if extinguishRoll <= finalChance then
                -- Extinguish fire
                if vFireInstalled then
                    RADS_ExtinguishVFire(rag)
                    RADS_ExtinguishVFire(ply)
                else
                    rag:Extinguish()
                    ply:Extinguish()
                end
                
                -- Reset tracking
                ply.FireExtinguishMovement = 0
                ply.LastFireExtinguishPos = nil
                ply.FireExtinguishRolls = 0
                ply.LastRollDirection = 0
                
                -- Reduce some fire spread areas
                if ply.FireSpreadAreas and #ply.FireSpreadAreas > 0 then
                    local areasToRemove = math.min(2, #ply.FireSpreadAreas)
                    for i = 1, areasToRemove do
                        table.remove(ply.FireSpreadAreas, math.random(1, #ply.FireSpreadAreas))
                    end
                end
            else
                -- Less punishing reset on failed attempt - keep more progress
                ply.FireExtinguishMovement = ply.FireExtinguishMovement * 0.8
                ply.FireExtinguishRolls = math.max(0, ply.FireExtinguishRolls - 1)
            end
        end
    end
    
    -- Hook into player think to track movement
    hook.Add("Think", "RADS_FireExtinguishmentTracking", function()
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetNWBool('radsfa') then -- Only for ragdolled players
                RADS_TrackMovementForFireExtinguishment(ply)
            end
        end
    end)
    
    -- Clean up fire timers when player dies or disconnects
    hook.Add("PlayerDeath", "RADS_CleanupFireTimers", function(ply)
        local timerName = "RADS_FireDamage_" .. ply:EntIndex()
        timer.Remove(timerName)
        
        -- Remove fire persistence timer
        timer.Remove("RADS_FirePersistence_" .. ply:EntIndex())
        
        -- Clear fire spread data and organ damage
        ply.FireSpreadAreas = {}
        ply.FireSpreadTimer = 0
        ply.OrganBurnDamage = {}
        
        -- Stop fire sound
        if IsValid(ply) then
            net.Start("RADS_StopFireSound")
            net.Send(ply)
        end
    end)
    
    -- Clean up tracking on player death/disconnect
    hook.Add("PlayerDeath", "RADS_CleanupFireExtinguishTracking", function(ply)
        ply.FireExtinguishMovement = nil
        ply.LastFireExtinguishPos = nil
        ply.FireExtinguishRolls = nil
        ply.LastRollDirection = nil
    end)
    
    hook.Add("PlayerDisconnected", "RADS_CleanupFireTimers", function(ply)
        local timerName = "RADS_FireDamage_" .. ply:EntIndex()
        timer.Remove(timerName)
        timer.Remove("RADS_FirePersistence_" .. ply:EntIndex())
    end)
    
    hook.Add("PlayerDisconnected", "RADS_CleanupFireExtinguishTracking", function(ply)
        ply.FireExtinguishMovement = nil
        ply.LastFireExtinguishPos = nil
        ply.FireExtinguishRolls = nil
        ply.LastRollDirection = nil
    end)
    
    -- Function to ignite player/ragdoll with vFire (persistent fire)
    function RADS_IgniteWithVFire(ent, duration, attacker)
        if not vFireInstalled or not IsValid(ent) then return false end
        
        -- Use vFire's ignite system with very long duration
        if vFireGetIgniteOverride and vFireGetIgniteOverride() then
            ent:Ignite(duration or 999999)
        elseif CreateVFireEntFires then
            local fireCount = math.random(5, 8)
            CreateVFireEntFires(ent, fireCount)
        else
            ent:Ignite(duration or 999999)
        end
        
        return true
    end
    
    -- Function to extinguish vFire on entity
    function RADS_ExtinguishVFire(ent)
        if not IsValid(ent) then return false end
        
        ent:Extinguish()
        return true
    end
end

-- Client-side vFire effects
if CLIENT then
    -- Variable to track fire sound
    local fireSoundChannel = nil
    
    -- Hook for vFire creation effects
    hook.Add("vFireCreated", "RADS_FireEffects", function(fire, parent)
        if not vFireInstalled then return end
        
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Check if the fire is on the local player or their ragdoll
        local isPlayerFire = false
        if parent == ply then
            isPlayerFire = true
        elseif IsValid(parent) and parent:GetNWEntity("owner") == ply then
            isPlayerFire = true
        end
        
        if isPlayerFire then
            -- Only apply screenshake if player is NOT ragdolled to avoid camera interference
            if not ply:GetNWBool("radsfa") then
                util.ScreenShake(ply:GetPos(), 5, 5, 1, 500)
            end
            
            -- Stop any existing fire sound safely
            if fireSoundChannel and IsValid(fireSoundChannel) then
                fireSoundChannel:Stop()
                fireSoundChannel = nil
            end
            
            -- Use entity-based sound so other players can hear it
            local targetEnt = ply:GetNWBool("radsfa") and ply:GetNWEntity('player_ragdoll') or ply
            if IsValid(targetEnt) then
                -- Stop any existing fire sound on the entity
                targetEnt:StopSound("ambient/fire/fire_med_loop1.wav")
                -- Play fire sound on the entity so others can hear it
                targetEnt:EmitSound("ambient/fire/fire_med_loop1.wav", 75, 100, 0.3)
            end
        end
    end)
    
    -- Network receiver to stop fire sound
    net.Receive("RADS_StopFireSound", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Stop entity-based fire sound
        local targetEnt = ply:GetNWBool("radsfa") and ply:GetNWEntity('player_ragdoll') or ply
        if IsValid(targetEnt) then
            targetEnt:StopSound("ambient/fire/fire_med_loop1.wav")
        end
        
        -- Also stop any remaining channel-based sound
        if fireSoundChannel and IsValid(fireSoundChannel) then
            fireSoundChannel:Stop()
            fireSoundChannel = nil
        end
    end)
    
    -- Network receiver for fire spread notifications
    net.Receive("RADS_FireSpread", function()
        local area = net.ReadString()
        local ply = LocalPlayer()
        
        -- Only apply screenshake if player is NOT ragdolled to avoid camera interference
        if not ply:GetNWBool("radsfa") then
            util.ScreenShake(ply:GetPos(), 3, 3, 0.5, 300)
        end
        

    end)
    
    -- Network receiver for organ burn notifications
    net.Receive("RADS_OrganBurn", function()
        local organ = net.ReadString()
        local damage = net.ReadInt(8)
        local ply = LocalPlayer()
        
        -- Visual effects for organ burning
        if organ == "heart" then
            -- Heart burn effect - red screen flash
            ply:ScreenFade(SCREENFADE.IN, Color(255, 0, 0, 100), 0.2, 0.3)
        elseif organ == "lungs" then
            -- Lung burn effect - breathing sound
            ply:EmitSound("player/pl_pain" .. math.random(5, 7) .. ".wav", 70, math.random(80, 120), 0.6)
        elseif organ == "brain" then
            -- Brain burn effect - screen distortion (only if not ragdolled)
            if not ply:GetNWBool("radsfa") then
                util.ScreenShake(ply:GetPos(), 8, 8, 1, 400)
            end
        end
    end)
    
    -- Clean up fire sound on player spawn
    hook.Add("PlayerSpawn", "RADS_CleanupFireSound", function(ply)
        if ply == LocalPlayer() then
            -- Stop entity-based fire sound
            local targetEnt = ply:GetNWBool("radsfa") and ply:GetNWEntity('player_ragdoll') or ply
            if IsValid(targetEnt) then
                targetEnt:StopSound("ambient/fire/fire_med_loop1.wav")
            end
            
            -- Also stop any remaining channel-based sound
            if fireSoundChannel and IsValid(fireSoundChannel) then
                fireSoundChannel:Stop()
                fireSoundChannel = nil
            end
        end
    end)
end

if CLIENT then
    -- Thoughts system: store multiple thoughts in a stack
    RADS_ThoughtStack = RADS_ThoughtStack or {}
    local maxThoughts = 3
    local thoughtDisplayTime = 4.0 -- seconds each thought stays visible
    local thoughtFadeTime = 0.3 -- fade in/out time
    
    -- Receive a thought from the server
    net.Receive('RADS_AddThought', function()
        local text = net.ReadString()
        local intensity = net.ReadFloat()
        local scramble = net.ReadBool()
        
        -- Don't add thoughts during unconsciousness
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:GetNWBool("Otrub", false) then return end
        
        -- Add new thought to stack
        local newThought = {
            text = text,
            startTime = CurTime(),
            intensity = intensity,
            scramble = scramble
        }
        
        table.insert(RADS_ThoughtStack, newThought)
        
        -- Remove oldest thought if we exceed max
        if #RADS_ThoughtStack > maxThoughts then
            table.remove(RADS_ThoughtStack, 1)
        end
    end)
    
    -- Function to cut short thoughts (for unconsciousness)
    function RADS_CutThoughtShort()
        RADS_ThoughtStack = {}
    end
    
    -- Draw all thoughts in stack
    hook.Add("HUDPaint", "RADS_DrawThought", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:GetNWBool("Otrub", false) then 
            RADS_ThoughtStack = {} -- Clear thoughts when unconscious
            return 
        end
        
        if #RADS_ThoughtStack == 0 then return end
        
        local currentTime = CurTime()
        local baseY = ScrH() * 0.75 -- Start position for thoughts
        local thoughtHeight = 35 -- Space between thoughts
        
        -- Remove expired thoughts
        for i = #RADS_ThoughtStack, 1, -1 do
            local thought = RADS_ThoughtStack[i]
            if currentTime - thought.startTime > thoughtDisplayTime then
                table.remove(RADS_ThoughtStack, i)
            end
        end
        
        -- Draw each thought
        for i, thought in ipairs(RADS_ThoughtStack) do
            local elapsed = currentTime - thought.startTime
            local alpha = 255
            
            -- Fade in
            if elapsed < thoughtFadeTime then
                alpha = math.Clamp((elapsed / thoughtFadeTime) * 255, 0, 255)
            -- Fade out
            elseif elapsed > thoughtDisplayTime - thoughtFadeTime then
                local fadeOutElapsed = elapsed - (thoughtDisplayTime - thoughtFadeTime)
                alpha = math.Clamp(255 - (fadeOutElapsed / thoughtFadeTime) * 255, 0, 255)
            end
            
            if alpha > 0 then
            
            -- Scramble text if needed (brain damage)
            local text = thought.text
            if thought.scramble and isHemorrhageOverlayActive then
                local t = {}
                for j = 1, #text do
                    t[j] = string.char(math.random(65, 90))
                end
                text = table.concat(t)
            end
            
            -- White text with black outline
            local textColor = Color(255, 255, 255, alpha)
            
            -- Calculate position
            local x = ScrW() / 2
            local y = baseY + ((i - 1) * thoughtHeight)
            
            -- Shake effect for appearing and disappearing thoughts
            local shakeIntensity = 0
            if elapsed < thoughtFadeTime or elapsed > thoughtDisplayTime - thoughtFadeTime then
                shakeIntensity = 3
            end
            
            local shakeX = math.sin(currentTime * 8) * shakeIntensity
            local shakeY = math.cos(currentTime * 6) * shakeIntensity
            
            -- Draw the text
            draw.SimpleText(text, "RADS_ThoughtFont", x + shakeX, y + shakeY, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end)
    
    -- Clear thoughts on player death
    hook.Add("PostPlayerDeath", "RADS_ClearThoughtOnDeath", function()
        RADS_ThoughtStack = {}
    end)
end

if SERVER then
    -- Function to check and add heavy pain thought
    local function CheckHeavyPain(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if ply:GetNWBool("Otrub", false) then return end -- No thoughts when unconscious
        
        local currentPain = ply.pain or 0
        local painThreshold = 281 -- Adjust this value for when "heavy pain" triggers
        
        if currentPain >= painThreshold then
            -- Only add thought if we haven't recently added one (prevent spam)
            ply.lastHeavyPainThought = ply.lastHeavyPainThought or 0
            if CurTime() - ply.lastHeavyPainThought > 5 then -- 5 second cooldown
                ply.lastHeavyPainThought = CurTime()
            end
        end
    end
    
    -- Hook to check pain levels periodically
    timer.Create("RADS_HeavyPainCheck", 2, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            CheckHeavyPain(ply)
        end
    end)
    
    -- Comprehensive cleanup on player death to prevent pain triggers from persisting
    hook.Add("PostPlayerDeath", "RADS_ComprehensivePainCleanup", function(ply)
        if not IsValid(ply) then return end
        
        local entIndex = ply:EntIndex()
        
        -- Clean up all pain debt timers
        timer.Remove("pain_debt_" .. entIndex)
        
        -- Clean up all bone pain timers for all limbs
        local limbs = {"LeftLeg", "RightLeg", "LeftArm", "RightArm", "Jaw"}
        for _, limb in ipairs(limbs) do
            timer.Remove("RADS_DelayedBonePain_" .. entIndex .. "_" .. limb)
            timer.Remove("RADS_DelayedBonePain_" .. entIndex .. "_" .. limb .. "_dislocated")
            timer.Remove("RADS_DelayedBonePain_" .. entIndex .. "_" .. limb .. "_escalation")
        end
        
        -- Clean up artery blood spurt timers
        timer.Remove("artery_burst_" .. entIndex)
        timer.Remove("radial_artery_l_burst_" .. entIndex)
        timer.Remove("radial_artery_r_burst_" .. entIndex)
        timer.Remove("femoral_artery_l_burst_" .. entIndex)
        timer.Remove("femoral_artery_r_burst_" .. entIndex)
        timer.Remove("popliteal_artery_l_burst_" .. entIndex)
        timer.Remove("popliteal_artery_r_burst_" .. entIndex)
        
        -- Clean up lung failure and fire timers
        timer.Remove("RADS_LungFailureDeathTimer_" .. entIndex)
        timer.Remove("RADS_LungWheezeTimer_" .. entIndex)
        timer.Remove("RADS_FirePersistence_" .. entIndex)
        timer.Remove("RADS_FireDamage_" .. entIndex)
        
        -- Clean up other pain-related timers
        timer.Remove("RADS_TinnitusTimer_" .. entIndex)
        timer.Remove("RADS_BrainDamageKillTimer_" .. entIndex)
        
        -- FIXED: Clean up heart failure timers
        timer.Remove("RADS_HeartFailure_" .. entIndex)
        
        -- Reset concussion state variables
        ply.concussionActive = false
        ply.concussionIntensity = 0
        ply.concussionEndTime = 0
        
        -- Reset artery bursting flags
        ply.ArteryBursting = false
        ply.RadialArteryLBursting = false
        ply.RadialArteryRBursting = false
        ply.FemoralArteryLBursting = false
        ply.FemoralArteryRBursting = false
        
        -- Reset new pain system variables
        ply.painDebt = 0
        ply.damageHistory = {}
        ply.lastDamageTime = 0
        ply.recentDamageCount = 0
        ply.totalRecentDamage = 0
        
        -- Reset heavy pain thought tracking
        ply.lastHeavyPainThought = 0
        
        -- Reset condition effects
        ply.conditionEffectIntensity = 0
        ply.conditionSoundPlaying = false
    end)
end

-- Condition-based visual effects system
if CLIENT then
    -- Condition effect variables
    local conditionEffectIntensity = 0
    local targetConditionIntensity = 0
    local conditionFadeSpeed = 1.5
    local conditionSound = nil

    local mat_WhiteOverlay = Material("vgui/white")
    
    -- Condition effects hook
    hook.Add("RenderScreenspaceEffects", "RADS_ConditionEffects_Unique", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then 
            conditionEffectIntensity = 0
            targetConditionIntensity = 0
            return 
        end
        
        -- Calculate condition based on health (0-100)
        local health = ply:Health()
        local maxHealth = ply:GetMaxHealth()
        local healthPercentage = math.Clamp(health / maxHealth, 0, 1)
        
        -- Only apply effects when health is below 50% (less frequent)
        if healthPercentage < 0.5 then
            -- Scale from 0.5-0.0 health to 0-1.0 effect intensity
            targetConditionIntensity = math.Clamp((0.5 - healthPercentage) / 0.5, 0, 1)
        else
            targetConditionIntensity = 0
        end
        
        -- Smooth fade in/out
        local frameTime = FrameTime()
        if conditionEffectIntensity < targetConditionIntensity then
            conditionEffectIntensity = math.min(conditionEffectIntensity + frameTime * conditionFadeSpeed, targetConditionIntensity)
        elseif conditionEffectIntensity > targetConditionIntensity then
            conditionEffectIntensity = math.max(conditionEffectIntensity - frameTime * conditionFadeSpeed, targetConditionIntensity)
        end
        
        -- Apply effects if intensity is significant
        if conditionEffectIntensity > 0.01 then
            local effectIntensity = conditionEffectIntensity
            
            -- Color modification effects - reduced darkness, color multiplier starts at 1
            local colorTab = {
                ["$pp_colour_brightness"] = -0.1 * effectIntensity, -- Reduced darkness
                ["$pp_colour_contrast"] = 1 + (0.05 * effectIntensity), -- Reduced contrast
                ["$pp_colour_colour"] = 1 - (effectIntensity * 0.8), -- Gradual desaturation, starts at 1
                ["$pp_colour_mulr"] = 0, -- Black color add
                ["$pp_colour_mulg"] = 0, -- Black color add
                ["$pp_colour_mulb"] = 0  -- Black color add
            }
            
            DrawColorModify(colorTab)
            

            

        end
    end)
    
    -- Condition sound system
    hook.Add("Think", "RADS_ConditionSound", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then
            if conditionSound then
                conditionSound:Stop()
                conditionSound = nil
            end
            return
        end
        
        -- Calculate condition based on health
        local health = ply:Health()
        local maxHealth = ply:GetMaxHealth()
        local healthPercentage = math.Clamp(health / maxHealth, 0, 1)
        
        -- Play sound when health is below 25% (earlier than overlay for gradual buildup)
        if healthPercentage < 0.25 then
            if not conditionSound then
                conditionSound = CreateSound(ply, "isthistheend.mp3")
                if conditionSound then
                    conditionSound:Play()
                    conditionSound:SetSoundLevel(0) -- Only audible to local player
                    
                    -- Calculate volume based on condition severity (max GMod volume minus 25)
                    local maxVolume = 75 -- Max GMod volume (100) minus 25
                    local volume = math.Clamp((0.25 - healthPercentage) / 0.25, 0, 1) * (maxVolume / 100)
                    conditionSound:ChangeVolume(volume, 0.5) -- Slower volume transitions
                end
            else
                -- Update volume based on condition with smooth scaling
                local maxVolume = 75 -- Max GMod volume (100) minus 25
                local volumeIntensity = math.Clamp((0.25 - healthPercentage) / 0.25, 0, 1)
                -- Apply exponential curve for more dramatic effect at lower health
                local volume = math.pow(volumeIntensity, 1.5) * (maxVolume / 100)
                conditionSound:ChangeVolume(volume, 0.3) -- Smooth volume transitions
            end
        else
            -- Stop sound if health is above threshold with longer fade
            if conditionSound then
                conditionSound:FadeOut(2.0) -- Longer fade out
                conditionSound = nil
            end
        end
    end)
    
    -- Clean up condition effects on death
    hook.Add("PostPlayerDeath", "RADS_CleanupConditionEffects", function()
        conditionEffectIntensity = 0
        targetConditionIntensity = 0
        
        if conditionSound then
            conditionSound:Stop()
            conditionSound = nil
        end
    end)
end

-- Server-side agonal breathing monitoring system
if SERVER then
    local agonalBreathingCheckTime = 0
    local agonalBreathingCheckInterval = 2.0 -- Check every 2 seconds
    
    hook.Add("Think", "RADS_AgonalBreathingMonitor", function()
        if CurTime() - agonalBreathingCheckTime < agonalBreathingCheckInterval then return end
        agonalBreathingCheckTime = CurTime()
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
                local shouldPlayAgonal = CheckAgonalBreathing(ply)
                
                if shouldPlayAgonal and not ply.agonalBreathingActive then
                    StartAgonalBreathing(ply)
                elseif not shouldPlayAgonal and ply.agonalBreathingActive then
                    StopAgonalBreathing(ply)
                end
            end
        end
    end)
    
    -- Clean up agonal breathing on death
    hook.Add("PostPlayerDeath", "RADS_CleanupAgonalBreathing", function(ply)
        if IsValid(ply) then
            StopAgonalBreathing(ply)
        end
    end)
    
    -- Clean up agonal breathing on spawn
    hook.Add("PlayerSpawn", "RADS_CleanupAgonalBreathingOnSpawn", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) then
                StopAgonalBreathing(ply)
            end
        end)
    end)
end

-- ========================================
-- SHOCK SYSTEM
-- ========================================

-- Initialize shock system
if SERVER then
    -- Initialize player shock values (only on actual spawn, not ragdoll get up)
    hook.Add("PlayerSpawn", "RADS_InitializeShock", function(ply)
        -- Only reset shock on actual spawn/respawn, not when getting up from ragdoll
        if not ply.gettingUpFromRagdoll then
            ply:SetNWFloat("RADS_Shock", 0)
        end
        ply.lastShockUpdate = CurTime()
    end)
    
    -- Shock decay system
    hook.Add("Think", "RADS_ShockDecay", function()
        if not GetConVar("rads_shock_enable"):GetBool() then return end
        
        local currentTime = CurTime()
        local decayRate = GetConVar("rads_shock_decay_rate"):GetFloat()
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local currentShock = ply:GetNWFloat("RADS_Shock", 0)
                if currentShock > 0 then
                    local timeDelta = currentTime - (ply.lastShockUpdate or currentTime)
                    local newShock = math.max(0, currentShock - (decayRate * timeDelta))
                    ply:SetNWFloat("RADS_Shock", newShock)
                end
                ply.lastShockUpdate = currentTime
            end
        end
    end)
    
    -- Function to add shock to player
    function AddPlayerShock(ply, amount, reason)
        if not IsValid(ply) or not GetConVar("rads_shock_enable"):GetBool() then return end
        
        local currentShock = ply:GetNWFloat("RADS_Shock", 0)
        local newShock = math.min(100, currentShock + amount)
        ply:SetNWFloat("RADS_Shock", newShock)
        
        -- Debug print
        if reason then
            print("[RADS Shock] " .. ply:Name() .. " gained " .. amount .. " shock from " .. reason .. " (Total: " .. newShock .. ")")
        end
    end
    
    -- Shock triggers
    
    -- Blood loss shock
    hook.Add("Think", "RADS_ShockBloodLoss", function()
        if not GetConVar("rads_shock_enable"):GetBool() then return end
        
        local threshold = GetConVar("rads_shock_blood_threshold"):GetFloat()
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local bloodVolume = ply:GetNWFloat("bloodvolume", 5000)
                local maxBlood = 5000
                local bloodLossPercent = ((maxBlood - bloodVolume) / maxBlood) * 100
                
                if bloodLossPercent >= threshold then
                    local shockAmount = (bloodLossPercent - threshold) * 0.3
                    if (ply.lastBloodShockCheck or 0) + 1 < CurTime() then
                        AddPlayerShock(ply, shockAmount, "blood loss")
                        ply.lastBloodShockCheck = CurTime()
                    end
                end
            end
        end
    end)
    
    -- Pain shock
    hook.Add("Think", "RADS_ShockPain", function()
        if not GetConVar("rads_shock_enable"):GetBool() then return end
        
        local threshold = GetConVar("rads_shock_pain_threshold"):GetFloat()
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local pain = ply:GetNWFloat("pain", 0)
                
                if pain >= threshold then
                    local shockAmount = (pain - threshold) * 0.5
                    if (ply.lastPainShockCheck or 0) + 1 < CurTime() then
                        AddPlayerShock(ply, shockAmount, "extreme pain")
                        ply.lastPainShockCheck = CurTime()
                    end
                end
            end
        end
    end)
    
    -- Fall damage shock
    hook.Add("OnPlayerHitGround", "RADS_ShockFallDamage", function(ply, inWater, onFloater, speed)
        if not IsValid(ply) or not GetConVar("rads_shock_enable"):GetBool() then return end
        
        local threshold = GetConVar("rads_shock_fall_threshold"):GetFloat()
        
        if speed >= threshold then
            local shockAmount = (speed - threshold) * 0.06
            AddPlayerShock(ply, shockAmount, "fall damage")
        end
    end)
    
    -- Explosion shock
    hook.Add("EntityTakeDamage", "RADS_ShockExplosion", function(target, dmginfo)
        if not IsValid(target) or not target:IsPlayer() or not GetConVar("rads_shock_enable"):GetBool() then return end
        
        local damageType = dmginfo:GetDamageType()
        if bit.band(damageType, DMG_BLAST) > 0 then
            local damage = dmginfo:GetDamage()
            local shockAmount = damage * 1.5
            AddPlayerShock(target, shockAmount, "explosion damage")
        end
    end)
    
    -- Nearby explosion shock and tinnitus
    hook.Add("EntityRemoved", "RADS_ShockNearbyExplosion", function(ent)
        if ent:GetClass() == "env_explosion" then
            local explosionPos = ent:GetPos()
            
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() then
                    local distance = ply:GetPos():Distance(explosionPos)
                    
                    -- Shock system
                    if GetConVar("rads_shock_enable"):GetBool() then
                        local shockRange = GetConVar("rads_shock_explosion_range"):GetFloat()
                        if distance <= shockRange then
                            local shockAmount = (1 - (distance / shockRange)) * 45
                            AddPlayerShock(ply, shockAmount, "nearby explosion")
                        end
                    end
                    
                    -- Tinnitus system
                    if GetConVar("rads_tinnitus_explosions"):GetBool() then
                        local tinnitusRange = 500 -- Maximum range for tinnitus effect
                        if distance <= tinnitusRange then
                            -- Calculate duration based on distance (closer = longer)
                            -- Max 25 seconds at distance 0, min 2 seconds at max range
                            local maxDuration = 25
                            local minDuration = 2
                            local distanceRatio = distance / tinnitusRange
                            local duration = maxDuration - (distanceRatio * (maxDuration - minDuration))
                            duration = math.Clamp(duration, minDuration, maxDuration)
                            
                            -- Send tinnitus trigger to client
                            net.Start("RADS_ExplosionTinnitus")
                            net.WriteFloat(duration)
                            net.Send(ply)
                        end
                    end
                end
            end
        end
    end)
    
    -- Artery damage shock
    hook.Add("Think", "RADS_ShockArteryDamage", function()
        if not GetConVar("rads_shock_enable"):GetBool() then return end
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                if ply.ArteryBursting or ply.RadialArteryLBursting or ply.RadialArteryRBursting or 
                   ply.FemoralArteryLBursting or ply.FemoralArteryRBursting then
                    if (ply.lastArteryShockCheck or 0) + 2 < CurTime() then
                        AddPlayerShock(ply, 15, "artery damage")
                        ply.lastArteryShockCheck = CurTime()
                    end
                end
            end
        end
    end)
    
    -- Concussion shock (if concussion system exists)
    hook.Add("Think", "RADS_ShockConcussion", function()
        if not GetConVar("rads_shock_enable"):GetBool() then return end
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local concussion = ply:GetNWFloat("concussion", 0)
                if concussion > 50 then
                    if (ply.lastConcussionShockCheck or 0) + 3 < CurTime() then
                        AddPlayerShock(ply, concussion * 0.3, "concussion")
                        ply.lastConcussionShockCheck = CurTime()
                    end
                end
            end
        end
    end)
    
    -- Shock pulse/heartrate effects
    hook.Add("Think", "RADS_ShockPulseEffects", function()
        if not GetConVar("rads_shock_enable"):GetBool() then return end
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local shock = ply:GetNWFloat("RADS_Shock", 0)
                
                if shock > 0 then
                    -- Initialize pulse if not set
                    if not ply.pulse then
                        ply.pulse = 70 -- Normal resting heart rate
                    end
                    
                    -- Calculate shock-based pulse increase
                    local basePulse = 70
                    local maxShockPulse = 160 -- Maximum pulse from shock
                    local shockPulseIncrease = (shock / 100) * (maxShockPulse - basePulse)
                    local targetPulse = basePulse + shockPulseIncrease
                    
                    -- Smoothly adjust pulse towards target
                    local pulseAdjustRate = 2.0 -- How fast pulse adjusts per second
                    local frameTime = FrameTime()
                    
                    if ply.pulse < targetPulse then
                        ply.pulse = math.min(ply.pulse + pulseAdjustRate * frameTime, targetPulse)
                    elseif ply.pulse > targetPulse then
                        ply.pulse = math.max(ply.pulse - pulseAdjustRate * frameTime, targetPulse)
                    end
                    
                    -- Ensure pulse doesn't go below normal when shock is present
                    ply.pulse = math.max(ply.pulse, basePulse)
                end
            end
        end
    end)
    
    -- Debug commands
    concommand.Add("rads_shock_add", function(ply, cmd, args)
        if not IsValid(ply) then return end
        local amount = tonumber(args[1]) or 10
        AddPlayerShock(ply, amount, "debug command")
        ply:ChatPrint("Added " .. amount .. " shock. Current: " .. ply:GetNWFloat("RADS_Shock", 0))
    end)
    
    concommand.Add("rads_shock_set", function(ply, cmd, args)
        if not IsValid(ply) then return end
        local amount = math.Clamp(tonumber(args[1]) or 0, 0, 100)
        ply:SetNWFloat("RADS_Shock", amount)
        ply:ChatPrint("Set shock to " .. amount)
    end)
    
    concommand.Add("rads_shock_clear", function(ply, cmd, args)
        if not IsValid(ply) then return end
        ply:SetNWFloat("RADS_Shock", 0)
        ply:ChatPrint("Cleared shock")
    end)
    
    -- Function to scramble text for broken jaw
    local function ScrambleTextForBrokenJaw(text)
        local words = string.Split(text, " ")
        local scrambledWords = {}
        
        -- Random words to replace with for broken jaw
        local randomWords = {"ugh", "mmph", "grr", "argh", "oof", "gah", "urgh", "mgh", "ngh", "hrm", "mph", "grh"}
        
        for i, word in ipairs(words) do
            local rand = math.random(1, 100)
            
            if rand <= 25 then
                -- Replace word with random pain sound
                table.insert(scrambledWords, randomWords[math.random(1, #randomWords)])
            elseif rand <= 50 then
                -- Replace word with dashes
                local dashes = ""
                for j = 1, string.len(word) do
                    dashes = dashes .. "-"
                end
                table.insert(scrambledWords, dashes)
            elseif rand <= 75 then
                -- Scramble the word
                local chars = {}
                for j = 1, string.len(word) do
                    table.insert(chars, string.sub(word, j, j))
                end
                
                -- Fisher-Yates shuffle
                for j = #chars, 2, -1 do
                    local k = math.random(j)
                    chars[j], chars[k] = chars[k], chars[j]
                end
                
                table.insert(scrambledWords, table.concat(chars))
            else
                -- Keep word unchanged
                table.insert(scrambledWords, word)
            end
        end
        
        return table.concat(scrambledWords, " ")
    end
    
    -- Communication restrictions for unconscious and broken jaw players
    hook.Add("PlayerSay", "RADS_CommunicationRestriction", function(ply, text)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        -- Check if player is unconscious (otrub)
        if ply.Otrub or ply:GetNWBool("Otrub", false) then
            return "" -- Return empty string to block the message
        end
        
        -- Check if player has broken jaw
        if ply:GetNWBool("RADS_BrokenJaw", false) then
            return ScrambleTextForBrokenJaw(text)
        end
    end)
    
    -- Voice chat restrictions for unconscious players and broken jaw pain
    hook.Add("PlayerCanHearPlayersVoice", "RADS_VoiceRestriction", function(listener, talker)
        if not IsValid(listener) or not IsValid(talker) then return end
        if not listener:IsPlayer() or not talker:IsPlayer() then return end
        
        -- If the talker is unconscious, no one can hear them
        if talker.Otrub or talker:GetNWBool("Otrub", false) then
            return false
        end
        
        -- If the listener is unconscious, they can't hear anyone
        if listener.Otrub or listener:GetNWBool("Otrub", false) then
            return false
        end
    end)
    
    -- Broken jaw voice chat pain system
    hook.Add("PlayerStartVoice", "RADS_BrokenJawVoicePain", function(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        -- Check if player has broken jaw
        if ply:GetNWBool("RADS_BrokenJaw", false) then
            -- Apply pain/damage for using voice chat with broken jaw
            local damage = math.random(2, 5)
            ply:SetHealth(math.max(1, ply:Health() - damage))
            
            -- Add some shock from the pain
            if ply.AddPlayerShock then
                ply:AddPlayerShock(math.random(5, 10), "broken jaw voice pain")
            end
        end
    end)
    
    -- Console command to break player's jaw for testing
    concommand.Add("rads_break_jaw", function(ply, cmd, args)
        if not IsValid(ply) then return end
        
        local targetName = args[1]
        local target = ply
        
        -- If a target name is provided, find that player
        if targetName then
            for _, p in ipairs(player.GetAll()) do
                if string.lower(p:Nick()) == string.lower(targetName) or string.find(string.lower(p:Nick()), string.lower(targetName)) then
                    target = p
                    break
                end
            end
        end
        
        if IsValid(target) then
            target:SetNWBool("RADS_BrokenJaw", true)
            ply:ChatPrint("Broke " .. target:Nick() .. "'s jaw")
            if target ~= ply then
                target:ChatPrint("Your jaw has been broken!")
            end
        end
    end)
    
    -- Console command to heal broken jaw
    concommand.Add("rads_heal_jaw", function(ply, cmd, args)
        if not IsValid(ply) then return end
        
        local targetName = args[1]
        local target = ply
        
        -- If a target name is provided, find that player
        if targetName then
            for _, p in ipairs(player.GetAll()) do
                if string.lower(p:Nick()) == string.lower(targetName) or string.find(string.lower(p:Nick()), string.lower(targetName)) then
                    target = p
                    break
                end
            end
        end
        
        if IsValid(target) then
            target:SetNWBool("RADS_BrokenJaw", false)
            ply:ChatPrint("Healed " .. target:Nick() .. "'s jaw")
            if target ~= ply then
                target:ChatPrint("Your jaw has been healed!")
            end
        end
    end)
    
    -- Clear broken jaw status on player death
    hook.Add("PlayerDeath", "RADS_ClearBrokenJawOnDeath", function(victim, inflictor, attacker)
        if IsValid(victim) and victim:IsPlayer() then
            victim:SetNWBool("RADS_BrokenJaw", false)
        end
    end)
    
    -- Clear broken jaw status on player spawn (respawn/revival)
    hook.Add("PlayerSpawn", "RADS_ClearBrokenJawOnSpawn", function(ply)
        if IsValid(ply) and ply:IsPlayer() then
            ply:SetNWBool("RADS_BrokenJaw", false)
        end
    end)
end

-- Client-side shock effects
if CLIENT then
    -- Shock effect variables
    local shockEffectIntensity = 0
    local targetShockIntensity = 0
    local shockFadeSpeed = 2.0
    local shockSound = nil
    local shockDSPEnabled = false
    
    -- Shock visual effect materials (using crowbar addon technique)
    local mat_ShockFisheye = Material("effects/shaders/merc_fisheye")
    local mat_ShockBlur = Material("effects/shaders/merc_blur")
    
    -- Shock visual effects
    hook.Add("RenderScreenspaceEffects", "RADS_ShockEffects", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then 
            shockEffectIntensity = 0
            targetShockIntensity = 0
            return 
        end
        
        if not (GetConVar("rads_shock_enable") and GetConVar("rads_shock_enable"):GetBool()) then
            shockEffectIntensity = 0
            targetShockIntensity = 0
            return
        end
        
        local shock = ply:GetNWFloat("RADS_Shock", 0)
        local visualIntensity = (GetConVar("rads_shock_visual_intensity") and GetConVar("rads_shock_visual_intensity"):GetFloat()) or 1.0
        
        -- Calculate target intensity (0-1 based on shock 0-100)
        targetShockIntensity = math.Clamp(shock / 100, 0, 1) * visualIntensity
        
        -- Smooth fade in/out
        local frameTime = FrameTime()
        if shockEffectIntensity < targetShockIntensity then
            shockEffectIntensity = math.min(shockEffectIntensity + frameTime * shockFadeSpeed, targetShockIntensity)
        elseif shockEffectIntensity > targetShockIntensity then
            shockEffectIntensity = math.max(shockEffectIntensity - frameTime * shockFadeSpeed, targetShockIntensity)
        end
        
        -- Apply effects if intensity is significant
        if shockEffectIntensity > 0.01 then
            local effectIntensity = shockEffectIntensity
            
            -- Fisheye effect (using crowbar addon technique with reduced intensity)
            local fisheyeStrength = effectIntensity * 0.150 -- Reduced from 0.200 to 0.150
            if fisheyeStrength > 0.001 and mat_ShockFisheye and not mat_ShockFisheye:IsError() then
                render.UpdateScreenEffectTexture()
                mat_ShockFisheye:SetFloat("$c0_x", fisheyeStrength)
                render.SetMaterial(mat_ShockFisheye)
                render.DrawScreenQuad()
            end
            
            -- Blur effect - use motion blur for cheapeffects=1, regular blur otherwise
            local cheapEffects = GetConVar("rads_cheapeffects") and GetConVar("rads_cheapeffects"):GetInt() or 0
            local blurStrength = effectIntensity * 0.3 -- Using crowbar's default strength range
            
            if blurStrength > 0.001 then
                if cheapEffects >= 1 then
                    -- Use motion blur for better performance when cheapeffects is enabled
                    local motionBlurStrength = blurStrength * 2.0 -- Make motion blur thicker/more intense
                    DrawMotionBlur(motionBlurStrength, motionBlurStrength, 0.01)
                else
                    -- Use regular blur for full quality
                    if mat_ShockBlur and not mat_ShockBlur:IsError() then
                        render.UpdateScreenEffectTexture()
                        mat_ShockBlur:SetFloat("$c0_x", blurStrength)
                        render.SetMaterial(mat_ShockBlur)
                        render.DrawScreenQuad()
                    end
                end
            end
            
            -- Color desaturation and darkening
            local colorTab = {
                ["$pp_colour_brightness"] = -0.15 * effectIntensity,
                ["$pp_colour_contrast"] = 1 + (0.1 * effectIntensity),
                ["$pp_colour_colour"] = 1 - (effectIntensity * 0.6),
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            
            DrawColorModify(colorTab)
        end
    end)
    
    -- Shock sound and DSP effects
    hook.Add("Think", "RADS_ShockSound", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then
            if shockSound then
                shockSound:Stop()
                shockSound = nil
            end
            if shockDSPEnabled then
                ply:SetDSP(0)
                shockDSPEnabled = false
            end
            return
        end
        
        if not (GetConVar("rads_shock_enable") and GetConVar("rads_shock_enable"):GetBool()) then
            if shockSound then
                shockSound:Stop()
                shockSound = nil
            end
            if shockDSPEnabled then
                ply:SetDSP(0)
                shockDSPEnabled = false
            end
            return
        end
        
        local shock = ply:GetNWFloat("RADS_Shock", 0)
        local muffledThreshold = (GetConVar("rads_shock_muffled_threshold") and GetConVar("rads_shock_muffled_threshold"):GetFloat()) or 50.0
        
        -- Muffled sound effect (DSP)
        if shock >= muffledThreshold then
            if not shockDSPEnabled then
                ply:SetDSP(30) -- Same DSP as pain effect
                shockDSPEnabled = true
            end
        else
            if shockDSPEnabled then
                ply:SetDSP(0)
                shockDSPEnabled = false
            end
        end
        
        -- Tired.mp3 sound when shock > 30
        if shock > 30 then
            if not shockSound then
                shockSound = CreateSound(ply, "tired.mp3")
                if shockSound then
                    shockSound:Play()
                    shockSound:SetSoundLevel(0) -- Only audible to local player
                    
                    -- Calculate volume based on shock level
                    local volume = math.Clamp((shock - 30) / 70, 0, 1) * 1.2 -- Max 120% volume
                    shockSound:ChangeVolume(volume, 0.5)
                end
            else
                -- Update volume based on shock level
                local volume = math.Clamp((shock - 30) / 70, 0, 1) * 1.2
                shockSound:ChangeVolume(volume, 0.3)
            end
        else
            if shockSound then
                shockSound:FadeOut(1.5)
                shockSound = nil
            end
        end
    end)
    
    -- Clean up shock effects on death
    hook.Add("PostPlayerDeath", "RADS_CleanupShockEffects", function()
        shockEffectIntensity = 0
        targetShockIntensity = 0
        
        if shockSound then
            shockSound:Stop()
            shockSound = nil
        end
        
        if shockDSPEnabled then
            LocalPlayer():SetDSP(0)
            shockDSPEnabled = false
        end
    end)
end

-- ============================================================================
-- FEAR SYSTEM (Exact copy of gmpublisher suppression system)
-- ============================================================================

-- Enhanced Fear ConVars
fear_vignette_size = CreateConVar("fear_vignette_size", 1, FCVAR_ARCHIVE + FCVAR_REPLICATED)
local fear_buildupspeed = CreateConVar("fear_buildupspeed", 1, FCVAR_ARCHIVE + FCVAR_REPLICATED)
local fear_enabled = CreateConVar("fear_enabled", 1, FCVAR_ARCHIVE + FCVAR_REPLICATED)
local fear_damage_scale = CreateConVar("fear_damage_scale", 0.06, FCVAR_ARCHIVE + FCVAR_REPLICATED) -- Increased 3x from 0.02
local fear_pain_scale = CreateConVar("fear_pain_scale", 0.001, FCVAR_ARCHIVE + FCVAR_REPLICATED)
local fear_velocity_scale = CreateConVar("fear_velocity_scale", 0.0001, FCVAR_ARCHIVE + FCVAR_REPLICATED) -- Reduced to 1/5 from 0.0005
local fear_ragdoll_multiplier = CreateConVar("fear_ragdoll_multiplier", 2.0, FCVAR_ARCHIVE + FCVAR_REPLICATED)
local fear_adrenaline_boost = CreateConVar("fear_adrenaline_boost", 0.5, FCVAR_ARCHIVE + FCVAR_REPLICATED)
local fear_decay_rate = CreateConVar("fear_decay_rate", 0.05, FCVAR_ARCHIVE + FCVAR_REPLICATED) -- Increased from 0.02 for faster decay

if SERVER then
	util.AddNetworkString( "fear_punch" )
end

-- Enhanced ApplyFearEffect function with smooth scaling and otrub handling
function ApplyFearEffect(target, fearAmount, source)
	if not IsValid(target) or not target:IsPlayer() or not target:Alive() then return end
	if not fear_enabled:GetBool() then return end
	
	-- Check if player is unconscious (otrub) - max out fear immediately
	if target:GetNWBool("otrub", false) then
		target:SetNWFloat("FearAMT", 3) -- Max fear during otrub
		return
	end
	
	-- Get current fear level
	local currentFear = target:GetNWFloat("FearAMT", 0)
	
	-- Apply fear with smooth scaling
	local newFear = math.Clamp(currentFear + fearAmount * fear_buildupspeed:GetFloat(), 0, 3)
	target:SetNWFloat("FearAMT", newFear)
	
	-- Boost adrenaline based on fear level
	if SERVER and newFear > 0.5 then
		-- Initialize adrenaline system if needed
		if not target.adrenaline then target.adrenaline = 0 end
		if not target.adrenalineActive then target.adrenalineActive = false end
		
		-- Boost adrenaline proportional to fear
		local adrenalineBoost = newFear * fear_adrenaline_boost:GetFloat() * 10
		target.adrenaline = math.Clamp((target.adrenaline or 0) + adrenalineBoost, 0, 100)
		
		-- Activate adrenaline if fear is high enough
		if newFear > 1.5 and not target.adrenalineActive then
			target.adrenalineActive = true
			target.adrenalineEndTime = CurTime() + 30 -- 30 second duration
			target.adrenalineCooldownEnd = (target.adrenalineEndTime or CurTime()) + 60 -- 1 minute cooldown
		end
	end
	
	-- Reset decay timer (but not during otrub)
	timer.Remove(target:Name() .. "fearreset")
	timer.Create(target:Name() .. "fearreset", 0.1, 0, function()
		if not IsValid(target) then 
			timer.Remove(target:Name() .. "fearreset")
			return 
		end
		
		-- Don't decay fear if player is unconscious (otrub)
		if target:GetNWBool("otrub", false) then
			target:SetNWFloat("FearAMT", 3) -- Keep fear maxed during otrub
			return
		end
		
		local fear = target:GetNWFloat("FearAMT", 0)
		if fear > 0 then
			fear = math.max(0, fear - fear_decay_rate:GetFloat())
			target:SetNWFloat("FearAMT", fear)
		else
			timer.Remove(target:Name() .. "fearreset")
		end
	end)
end

-- Hook to monitor otrub state changes and max out fear
hook.Add("Think", "FearFromOtrub", function()
	for _, ply in pairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() then
			-- Check if player just became unconscious (otrub)
			if ply:GetNWBool("otrub", false) then
				-- Immediately max out fear and keep it there
				ply:SetNWFloat("FearAMT", 3)
			else
				-- Player is no longer unconscious, allow normal fear decay
				-- This is handled by the normal decay timer
			end
		elseif IsValid(ply) and not ply:Alive() then
			-- Player is dead, clear fear immediately
			ply:SetNWFloat("FearAMT", 0)
			timer.Remove(ply:Name() .. "fearreset")
		end
	end
end)

-- Hook into damage events with smooth scaling
hook.Add("PlayerHurt", "FearFromDamage", function(ply, attacker, health, damage)
	if damage > 0 then
		-- Scale fear based on damage amount
		local fearAmount = damage * fear_damage_scale:GetFloat()
		
		-- Increase fear if player is ragdolled
		if ply:GetNWBool("radsfa", false) then
			fearAmount = fearAmount * fear_ragdoll_multiplier:GetFloat()
		end
		
		ApplyFearEffect(ply, fearAmount, "damage")
	end
end)

-- Hook into velocity events with smooth scaling (drastically reduced)
local lastVelocityCheck = {}
hook.Add("Think", "FearFromVelocity", function()
	for _, ply in pairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() then
			local velocity = ply:GetVelocity():Length()
			local steamID = ply:SteamID()
			
			-- Only check every 0.3 seconds to avoid spam
			if not lastVelocityCheck[steamID] or CurTime() - lastVelocityCheck[steamID] > 0.3 then
				lastVelocityCheck[steamID] = CurTime()
				
				-- Scale fear based on velocity (threshold at 400, drastically reduced sensitivity)
				if velocity > 400 then
					-- Drastically reduced fear calculation (1/20 of original)
					local fearAmount = (velocity - 400) * fear_velocity_scale:GetFloat() * 0.05
					
					-- Increase fear if player is ragdolled and moving fast
					if ply:GetNWBool("radsfa", false) and velocity > 500 then
						fearAmount = fearAmount * fear_ragdoll_multiplier:GetFloat()
					end
					
					ApplyFearEffect(ply, fearAmount, "velocity")
				end
			end
		end
	end
end)

-- Hook into explosion events with smooth scaling
hook.Add("OnDamagedByExplosion", "FearExplosion", function(ply, dmginfo)
	if dmginfo:GetDamage() >= 1 and ply:Alive() then
		-- Scale fear based on explosion damage
		local fearAmount = dmginfo:GetDamage() * 0.05 -- Base explosion fear
		ApplyFearEffect(ply, fearAmount, "explosion")
	end
end)

-- Hook into pain system for fear
hook.Add("Think", "FearFromPain", function()
	for _, ply in pairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() and ply.pain then
			local steamID = ply:SteamID()
			
			-- Only check every 0.5 seconds
			if not ply.lastPainFearCheck or CurTime() - ply.lastPainFearCheck > 0.5 then
				ply.lastPainFearCheck = CurTime()
				
				-- Scale fear based on pain level
				if ply.pain > 50 then
					local fearAmount = (ply.pain - 50) * fear_pain_scale:GetFloat()
					ApplyFearEffect(ply, fearAmount, "pain")
				end
			end
		end
	end
end)

-- Initialize fear on spawn
hook.Add("PlayerInitialSpawn", "InitializeFear", function(ply)
	ply:SetNWFloat("FearAMT", 0)
end)

-- Clean up fear on death
hook.Add("PlayerDeath", "ClearFearDeath", function(ply, i, a)
	ply:SetNWFloat("FearAMT", 0)
	timer.Remove(ply:Name() .. "fearreset")
end)

-- Enhanced Fear vignette rendering with ultra-smooth scaling and shake effect
local m = Material("vignette/vignette.png")
local m_w = Material("vignette/vignette_white.png")
local alpha_saved = 255
local alphanew = 0
local lastFearLevel = 0
local smoothTransition = 0
local shakeOffset = {x = 0, y = 0}
local shakeTime = 0
hook.Add("RenderScreenspaceEffects", "fear_vignette", function()
	if not render.SupportsPixelShaders_2_0() then return end
	
	local fearLevel = LocalPlayer():GetNWFloat("FearAMT", 0)
	local frameTime = FrameTime()
	local currentTime = CurTime()
	
	-- Ultra-smooth interpolation with multiple layers
	if fearLevel == 0 then 
		-- Slower fade out for smoother transition
		alphanew = Lerp(3 * frameTime, alphanew, 0)
		smoothTransition = Lerp(2 * frameTime, smoothTransition, 0)
		if alphanew < 0.005 and smoothTransition < 0.005 then return end
	else
		-- Smoother fade in with gradual buildup
		alphanew = Lerp(4 * frameTime, alphanew, fearLevel)
		smoothTransition = Lerp(5 * frameTime, smoothTransition, fearLevel)
	end
	
	-- Calculate shake effect proportional to fear level
	local shakeIntensity = math.Clamp(fearLevel * 0.8, 0, 2) -- Max shake at high fear
	if shakeIntensity > 0.1 then
		-- Generate subtle shake with varying frequency based on fear
		local shakeFreq = 15 + (fearLevel * 10) -- Higher fear = faster shake
		local shakeAmp = shakeIntensity * 1.5 -- Amplitude based on fear level
		
		-- Smooth shake calculation with multiple sine waves for natural movement
		shakeOffset.x = math.sin(currentTime * shakeFreq) * shakeAmp + math.sin(currentTime * shakeFreq * 1.7) * (shakeAmp * 0.3)
		shakeOffset.y = math.cos(currentTime * shakeFreq * 1.3) * shakeAmp + math.cos(currentTime * shakeFreq * 0.8) * (shakeAmp * 0.4)
		
		-- Smooth the shake transitions
		shakeOffset.x = Lerp(8 * frameTime, shakeOffset.x or 0, shakeOffset.x)
		shakeOffset.y = Lerp(8 * frameTime, shakeOffset.y or 0, shakeOffset.y)
	else
		-- Gradually reduce shake when fear is low
		shakeOffset.x = Lerp(6 * frameTime, shakeOffset.x or 0, 0)
		shakeOffset.y = Lerp(6 * frameTime, shakeOffset.y or 0, 0)
	end
	
	-- Multi-layer smooth alpha calculation for ultra-smooth transitions
	local baseAlpha = math.Clamp(alphanew * 1.2, 0, 2.5)
	local smoothAlpha = math.Clamp(smoothTransition * 0.8, 0, 2)
	local finalAlpha = (baseAlpha + smoothAlpha) * 0.6 -- Blend both for ultra-smoothness
	
	-- Apply shake offset to the rendering matrix
	local scrW, scrH = ScrW(), ScrH()
	local matrix = Matrix()
	matrix:Translate(Vector(shakeOffset.x, shakeOffset.y, 0))
	
	cam.PushModelMatrix(matrix)
	
	render.SetMaterial(m)
	m:SetFloat("$alpha", finalAlpha)
	
	-- Smoother quad count scaling with gradual intensity changes
	local intensityFactor = (alphanew + smoothTransition) * 0.5
	local quadCount = math.Clamp(math.floor(4 * fear_vignette_size:GetFloat() * (1 + intensityFactor * 0.3)), 1, 10)
	for i = 1, quadCount do 
		render.DrawScreenQuad() 
	end
	
	cam.PopModelMatrix()
	
	lastFearLevel = fearLevel
end)

-- Health check hook to prevent death from health reaching 0
if SERVER then
    hook.Add("PlayerShouldTakeDamage", "RADS_PreventHealthDeath", function(ply, attacker)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        -- If player is already in death state, prevent all damage
        if ply.deathStateActive then
            return false
        end
        
        -- Check if this damage would kill the player
        if ply:Health() <= 1 then
            -- Trigger death state instead of actual death
            TriggerDeathState(ply)
            return false -- Prevent the damage that would kill
        end
    end)
    
    -- Additional hook to catch health changes
    hook.Add("Think", "RADS_HealthMonitor", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and ply:Health() <= 0 and not ply.deathStateActive then
                TriggerDeathState(ply)
            end
        end
    end)
end

-- Functions for advanced damage effects
if SERVER then
    -- Function to start continuous fear effect for 4 minutes
    function StartContinuousFearEffect(ply, eyeType)
        if not IsValid(ply) then return end
        
        local timerName = "continuous_fear_" .. ply:EntIndex() .. "_" .. eyeType
        
        -- Remove existing timer to prevent duplicates
        timer.Remove(timerName)
        
        -- Apply fear every 0.5 seconds for 4 minutes (240 seconds)
        local fearDuration = 240 -- 4 minutes
        local fearInterval = 0.5
        local fearTicks = 0
        local maxTicks = fearDuration / fearInterval
        
        timer.Create(timerName, fearInterval, maxTicks, function()
            if not IsValid(ply) or not ply:Alive() then
                timer.Remove(timerName)
                return
            end
            
            fearTicks = fearTicks + 1
            
            -- Apply continuous fear (gradually decreasing over time)
            local fearIntensity = math.max(0.3, 1.0 - (fearTicks / maxTicks) * 0.7) -- Start at 1.0, end at 0.3
            ApplyFearEffect(ply, fearIntensity, "eye_trauma_continuous")
            
            -- Stop timer when duration is reached
            if fearTicks >= maxTicks then
                timer.Remove(timerName)
            end
        end)
    end
    
    -- Function to start rapid consciousness depletion for eye destruction
    function StartEyeConsciousnessDepletion(ply, eyeType)
        if not IsValid(ply) then return end
        
        local timerName = "eye_consciousness_depletion_" .. ply:EntIndex() .. "_" .. eyeType
        
        -- Remove existing timer to prevent duplicates
        timer.Remove(timerName)
        
        -- Rapidly deplete consciousness until it reaches 0
        timer.Create(timerName, 0.1, 0, function() -- Every 0.1 seconds, infinite repeats
            if not IsValid(ply) or not ply:Alive() then
                timer.Remove(timerName)
                return
            end
            
            -- Check if consciousness is already 0 or below
            if not ply.consciousness or ply.consciousness <= 0 then
                timer.Remove(timerName)
                return
            end
            
            -- Rapidly deplete consciousness (10 points per second)
            ply.consciousness = math.max(0, ply.consciousness - 1)
            ply:SetNWInt("PlayerConsciousness", math.floor(ply.consciousness))
            
            -- Stop when consciousness reaches 0
            if ply.consciousness <= 0 then
                timer.Remove(timerName)
            end
        end)
    end
    
    -- Function to start rapid consciousness depletion for jaw break
    function StartJawConsciousnessDepletion(ply)
        if not IsValid(ply) then return end
        
        local timerName = "jaw_consciousness_depletion_" .. ply:EntIndex()
        
        -- Remove existing timer to prevent duplicates
        timer.Remove(timerName)
        
        -- Rapidly deplete consciousness until it reaches 0
        timer.Create(timerName, 0.1, 0, function() -- Every 0.1 seconds, infinite repeats
            if not IsValid(ply) or not ply:Alive() then
                timer.Remove(timerName)
                return
            end
            
            -- Check if consciousness is already 0 or below
            if not ply.consciousness or ply.consciousness <= 0 then
                timer.Remove(timerName)
                return
            end
            
            -- Rapidly deplete consciousness (10 points per second)
            ply.consciousness = math.max(0, ply.consciousness - 1)
            ply:SetNWInt("PlayerConsciousness", math.floor(ply.consciousness))
            
            -- Stop when consciousness reaches 0
            if ply.consciousness <= 0 then
                timer.Remove(timerName)
            end
        end)
    end
end

-- Debug console commands for destroying eye organs
if SERVER then
    concommand.Add("rads_destroy_left_eye", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        -- Check if player has organs initialized
        if not ply.Organs or not ply.Organs.left_eye then
            return
        end
        
        -- Set left eye health to 0
        ply.Organs['left_eye'] = 0
        
        -- Synchronize organ health to client for overlay system
        ply:SetNWInt("LeftEyeHealth", 0)
        
        -- Add 100 pain
        ply.pain = ply.pain + 100
        
        -- Add organ thought
        if ply.organThoughts then
            table.insert(ply.organThoughts, "Your left eye is destroyed")
        end
        
        -- Trigger fear effect
        ApplyFearEffect(ply, 0.8, "eye_loss")
        
        -- Start 4-minute continuous fear effect
        StartContinuousFearEffect(ply, "left_eye")
        
        -- Start rapid consciousness depletion
        StartEyeConsciousnessDepletion(ply, "left_eye")
        
        -- Send network message for screen shake and effects
        net.Start("RADS_EyeLossShake")
        net.WriteString("left")
        net.Send(ply)
    end)
    
    concommand.Add("rads_destroy_right_eye", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        -- Check if player has organs initialized
        if not ply.Organs or not ply.Organs.right_eye then
            return
        end
        
        -- Set right eye health to 0
        ply.Organs['right_eye'] = 0
        
        -- Synchronize organ health to client for overlay system
        ply:SetNWInt("RightEyeHealth", 0)
        
        -- Add 100 pain
        ply.pain = ply.pain + 100
        
        -- Add organ thought
        if ply.organThoughts then
            table.insert(ply.organThoughts, "Your right eye is destroyed")
        end
        
        -- Trigger fear effect
        ApplyFearEffect(ply, 0.8, "eye_loss")
        
        -- Start 4-minute continuous fear effect
        StartContinuousFearEffect(ply, "right_eye")
        
        -- Start rapid consciousness depletion
        StartEyeConsciousnessDepletion(ply, "right_eye")
        
        -- Send network message for screen shake and effects
        net.Start("RADS_EyeLossShake")
        net.WriteString("right")
        net.Send(ply)
    end)
end