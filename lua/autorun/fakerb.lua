-- Global variables for SERVER context
local lastPainSoundTime = {}
local lastFreeFallSoundTime = {}

-- Rapid hit tracking for shotgun knockdown system
local playerHitTracking = {}
local RAPID_HIT_WINDOW = 0.5 -- Time window in seconds to track rapid hits

if SERVER then
    
    -- Function to clean up old hit data to prevent memory leaks
    local function CleanupOldHitData()
        local currentTime = CurTime()
        for steamID, hitData in pairs(playerHitTracking) do
            -- Remove hits older than the tracking window
            for i = #hitData.hits, 1, -1 do
                if currentTime - hitData.hits[i] > RAPID_HIT_WINDOW then
                    table.remove(hitData.hits, i)
                end
            end
            
            -- Remove player entry if no recent hits
            if #hitData.hits == 0 then
                playerHitTracking[steamID] = nil
            end
        end
    end
    
    -- Clean up old hit data every 2 seconds
    timer.Create("RADS_CleanupHitData", 2, 0, CleanupOldHitData)
    
    -- vFire integration variables
    local vFireSupported = false
    
    -- Check for vFire support
    timer.Simple(0.5, function()
        if vFireInstalled then
            vFireSupported = true
            if GetConVar("developer"):GetInt() > 0 then
    print("[RADS] vFire integration enabled in ragdoll system")
end
        end


if SERVER then
    -- Automatic shock ragdoll system
    hook.Add("Think", "RADS_ShockRagdollCheck", function()
        if not GetConVar("rads_shock_enable"):GetBool() then return end
        
        local ragdollThreshold = GetConVar("rads_shock_ragdoll_threshold"):GetFloat()
        
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:GetNWBool("radsfa", false) then
                local shock = ply:GetNWFloat("RADS_Shock", 0)
                
                if shock >= ragdollThreshold then
                    -- Force ragdoll due to shock
                    if not ply.lastShockRagdollTime or CurTime() - ply.lastShockRagdollTime > 2 then
                        rads(ply, false) -- Not manual ragdoll
                        ply.lastShockRagdollTime = CurTime()
                    end
                end
            end
        end
    end)
    
    -- Store shock responsiveness factor for ragdolls
    hook.Add("Think", "RADS_ShockRagdollSlowMovement", function()
        if not GetConVar("rads_shock_enable"):GetBool() then return end
        
        for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
            if IsValid(rag) and rag.isShockRagdoll then
                local owner = rag:GetNWEntity("owner")
                if IsValid(owner) and owner:IsPlayer() then
                    local shock = owner:GetNWFloat("RADS_Shock", 0)
                    
                    -- Calculate control responsiveness factor based on shock level
                    -- Higher shock = slower/less responsive controls (not physics)
                    local responsivenessFactor = math.Clamp(1 - (shock / 150), 0.2, 1) -- Max 80% control slowdown
                    
                    -- Store the responsiveness factor on the ragdoll for use in control systems
                    rag.shockResponsiveness = responsivenessFactor
                    
                    -- Update shock ragdoll status
                    local ragdollThreshold = GetConVar("rads_shock_ragdoll_threshold"):GetFloat()
                    if shock < ragdollThreshold then
                        rag.isShockRagdoll = false
                        rag.shockLevel = nil
                        rag.shockResponsiveness = 1.0 -- Reset to normal responsiveness
                    end
                else
                    -- Clean up if owner is invalid
                    rag.isShockRagdoll = false
                    rag.shockLevel = nil
                    rag.shockResponsiveness = 1.0
                end
            end
        end
    end)
end
    end)
    
    -- Transfer vFire from player to ragdoll
    function RADS_TransferVFire(ply, rag)
        if not vFireInstalled or not IsValid(ply) or not IsValid(rag) then return end
        
        -- Check if player is on fire
        if ply:IsOnFire() then
            -- Get fires on player
            local fires = vFireGetFires(ply)
            if fires and #fires > 0 then
                -- Extinguish player
                ply:Extinguish()
                
                -- Create fires on ragdoll
                local fireCount = math.min(#fires, 8) -- Limit fire count
                CreateVFireEntFires(rag, fireCount)
                
                -- Set fire owner for kill tracking
                timer.Simple(0.1, function()
                    if IsValid(rag) then
                        local ragFires = vFireGetFires(rag)
                        if ragFires then
                            for _, fire in pairs(ragFires) do
                                if IsValid(fire) and fire.SetOwner then
                                    fire:SetOwner(ply.LastAttacker or ply)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
    
    -- Transfer vFire from ragdoll back to player
    function RADS_TransferVFireToPlayer(rag, ply)
        if not vFireInstalled or not IsValid(rag) or not IsValid(ply) then return end
        
        -- Check if ragdoll is on fire
        if rag:IsOnFire() then
            -- Get fires on ragdoll
            local fires = vFireGetFires(rag)
            if fires and #fires > 0 then
                -- Store fire owner for tracking
                local fireOwner = nil
                if fires[1] and IsValid(fires[1]) and fires[1].GetOwner then
                    fireOwner = fires[1]:GetOwner()
                end
                
                -- Extinguish ragdoll
                rag:Extinguish()
                
                -- Ignite player
                local fireCount = math.min(#fires, 6)
                CreateVFireEntFires(ply, fireCount)
                
                -- Restore fire owner
                if IsValid(fireOwner) then
                    timer.Simple(0.1, function()
                        if IsValid(ply) then
                            local playerFires = vFireGetFires(ply)
                            if playerFires then
                                for _, fire in pairs(playerFires) do
                                    if IsValid(fire) and fire.SetOwner then
                                        fire:SetOwner(fireOwner)
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
    
    -- Gore System: Head Explosion Function
    -- Old RADS_TriggerHeadExplosion function removed - using newer version with proper positioning
    
    -- Gore System: Blood Explosion Effect
    function RADS_CreateBloodExplosion(pos, target)
        if not IsValid(target) then return end
        
        -- Create multiple blood spurts in different directions
        for i = 1, 12 do
            local bloodDir = VectorRand():GetNormalized()
            bloodDir.z = math.abs(bloodDir.z) * 0.5 -- Bias upward
            
            local effectdata = EffectData()
            effectdata:SetOrigin(pos + VectorRand() * 2)
            effectdata:SetNormal(bloodDir)
            effectdata:SetMagnitude(math.random(50, 100))
            effectdata:SetScale(math.random(1, 3))
            util.Effect("BloodImpact", effectdata)
        end
        
        -- Create blood decals on nearby surfaces
        for i = 1, 8 do
            local traceDir = VectorRand():GetNormalized()
            local trace = util.TraceLine({
                start = pos,
                endpos = pos + traceDir * 200,
                filter = target
            })
            
            if trace.Hit then
                util.Decal("Blood", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal)
            end
        end
    end
    
    -- Gore System: Continuous Blood Stream
    function RADS_StartBloodStream(target, pos)
        if not IsValid(target) then return end
        
        local bloodDuration = GetConVar("rads_gore_blood_duration"):GetFloat()
        local timerName = "RADS_BloodStream_" .. target:EntIndex()
        
        -- Remove existing timer if any
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
        
        -- Start blood stream timer
        timer.Create(timerName, 0.1, bloodDuration * 10, function()
            if not IsValid(target) or not target.hasGoreExplosion then
                timer.Remove(timerName)
                return
            end
            
            -- Get current neck position
            local currentPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Neck1") or 0)
            if currentPos == Vector(0,0,0) then
                currentPos = pos
            end
            
            -- Create blood drip effect
            local effectdata = EffectData()
            effectdata:SetOrigin(currentPos)
            effectdata:SetNormal(Vector(0, 0, -1))
            effectdata:SetMagnitude(math.random(10, 30))
            effectdata:SetScale(1)
            util.Effect("BloodImpact", effectdata)
            
            -- Occasionally create blood decals below
            if math.random(1, 3) == 1 then
                local trace = util.TraceLine({
                    start = currentPos,
                    endpos = currentPos + Vector(0, 0, -100),
                    filter = target
                })
                
                if trace.Hit then
                    util.Decal("Blood", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal)
                end
            end
        end)
    end
    
    function RADS.PainSound(ply)
        if not IsValid(ply) then return end
        local model = ply:GetModel()
        if not model or type(model) ~= "string" then return end
        
        local g = "man"
        if string.find(model, "alyx.mdl") or string.find(model, "mossman.mdl") or string.find(model, "mossman_arctic.mdl") or string.find(model, "p2_chell.mdl") or string.find(model, "female_") then g = "woman" end
        if string.find(model, "combine") or string.find(model, "police.mdl") then g = "combine" end
        if GetConVar("rads_painsounds"):GetBool() then
            local curTime = CurTime()
            local cooldown = 0.3
            if g == "man" then
                if not lastPainSoundTime[ply] or curTime - lastPainSoundTime[ply] >= cooldown then
                    local rndmsnd = math.random(1, #RADS.MalePain)
                    local randomSound = RADS.MalePain[rndmsnd]
                    ply:EmitSound(randomSound)
                    lastPainSoundTime[ply] = curTime
                end
            elseif g == "woman" then
                if not lastPainSoundTime[ply] or curTime - lastPainSoundTime[ply] >= cooldown then
                    local rndmsnd = math.random(1, #RADS.FemalePain)
                    local randomSound = RADS.FemalePain[rndmsnd]
                    ply:EmitSound(randomSound)
                    lastPainSoundTime[ply] = curTime
                end
            elseif g == "combine" then
                if not lastPainSoundTime[ply] or curTime - lastPainSoundTime[ply] >= cooldown then
                    local rndmsnd = math.random(1, #RADS.CombinePain)
                    local randomSound = RADS.CombinePain[rndmsnd]
                    ply:EmitSound(randomSound)
                    lastPainSoundTime[ply] = curTime
                end
            end
        end
    end

    function RADS.FreeFall(ply)
        if not IsValid(ply) then return end
        local model = ply:GetModel()
        if not model or type(model) ~= "string" then return end
        
        local g = "man"
        if string.find(model, "alyx.mdl") or string.find(model, "mossman.mdl") or string.find(model, "female_") then g = "woman" end
        if string.find(model, "combine") or string.find(model, "police.mdl") then g = "combine" end
        if GetConVar("rads_painsounds"):GetBool() then
            local curTime = CurTime()
            local cooldown = 0.3
            if g == "man" then
                if not lastFreeFallSoundTime[ply] or curTime - lastFreeFallSoundTime[ply] >= cooldown then
                    local rndmsnd = math.random(1, #RADS.MaleFall)
                    local randomSound = RADS.MaleFall[rndmsnd]
                    ply:EmitSound(randomSound)
                    lastFreeFallSoundTime[ply] = curTime
                end
            elseif g == "woman" then
                if not lastFreeFallSoundTime[ply] or curTime - lastFreeFallSoundTime[ply] >= cooldown then
                    local rndmsnd = math.random(1, #RADS.FemaleFall)
                    local randomSound = RADS.FemaleFall[rndmsnd]
                    ply:EmitSound(randomSound)
                    lastFreeFallSoundTime[ply] = curTime
                end
            elseif g == "combine" then
                if not lastFreeFallSoundTime[ply] or curTime - lastFreeFallSoundTime[ply] >= cooldown then
                    local rndmsnd = math.random(1, #RADS.CombineFall)
                    local randomSound = RADS.CombineFall[rndmsnd]
                    ply:EmitSound(randomSound)
                    lastFreeFallSoundTime[ply] = curTime
                end
            end
        end
    end

    _P = FindMetaTable("Player")
    _ENT = FindMetaTable("Entity")
    function _P:IsRag()
        return self:GetNWBool("radsfa")
    end

    function _P:GetRads()
        return self:GetNWEntity("player_ragdoll")
    end

    function RADS.IsTTT()
        if engine.ActiveGamemode() == "terrortown" then return true end
        return false
    end

    function _ENT:GetOwnerrr()
        if self:GetNWEntity("owner") ~= nil then return self:GetNWEntity("owner") end
        return nil
    end

    function _ENT:IsRads()
        if self:GetNWEntity("owner") ~= nil then return true end
        return false
    end

    function RADS.IsJmodAct()
        return type(JMod) == "table"
    end

    hook.Add("PhysgunDrop", "RADS.Drop", function(ply, ent)
        if ply:IsSuperAdmin() and ent:IsRagdoll() and ent:IsRads() then ent.physgunned = false end
        if ply:IsSuperAdmin() and ent:IsPlayer() then ent.physgunned = false end
    end)

    hook.Add("PhysgunPickup", "RADS.Pickup", function(ply, ent)
        if ply:IsSuperAdmin() and ent:IsPlayer() and not ent.fake then
            rads(ent)
            ent.physgunned = true
            return false
        end

        if ent:IsRagdoll() and ent:IsRads() then ent.physgunned = true end
    end)

    hook.Add("CanPlayerSuicide", "RADS.SuicideAllow", function(ply)
        if not GetConVar("rads_enablekill"):GetBool() and ply.Otrub then
            ply:ChatPrint("No easy way out.")
            return false
        end
        return true
    end)

    local CurTime = CurTime
    local time
    local player_GetAll = player.GetAll
    local tbl
    hook.Add("PlayerSpawn", "RADS.SpawnReset", function(ply)
        ply:SetParent(nil)
        while not ply:IsInWorld() and not timer.Exists("respawntimer" .. ply:EntIndex()) do
            ply:Spawn()
        end

        if timer.Exists("respawntimer" .. ply:EntIndex()) then return end
        if timer.Exists("radstimer" .. ply:EntIndex()) then timer.Remove("radstimer" .. ply:EntIndex()) end
        
        -- Always remove calcview on spawn to ensure clean state
        net.Start('REMOVECALC')
        net.Send(ply)
        
        -- Clear death first-person flag
        ply:SetNWBool('rads_dead_firstperson', false)
        local exr = ply:GetNWEntity("player_ragdoll")
        if IsValid(exr) then
            ply:SetNWBool('radsfa', false)
            exr:RemoveEFlags(EFL_KEEP_ON_RECREATE_ENTITIES)
            ply:SetNWEntity('deadbody', exr)
            exr:SetNWEntity('deadbodyowner', ply)
            ply:SetNWEntity("player_ragdoll", nil)
            exr:SetNWEntity("RagdollController", nil)
            exr:SetNWEntity("owner", nil)
        end

        ply.fake = false
        ply.physgunned = false
        ply.brokenspine = false
        ply.gettingUp = false
        ply.upValue = 0
        ply.lastGetUpAttempt = 0
        ply.lastGetUpTime = nil  -- Reset the get up timer on spawn
        
        -- NEW: Reset lung oxygen system states on spawn
        ply.lungOxygenActive = false
        ply.lungStaminaDrain = false
        if IsValid(ply.wheezeEntity) then
            ply.wheezeEntity:Remove()
            ply.wheezeEntity = nil
        end
        

    end)

    util.AddNetworkString("ragscale")
    util.AddNetworkString("ragplayercolor")
    util.AddNetworkString("showiconleft")
    util.AddNetworkString("hideiconleft")
    util.AddNetworkString("showiconright")
    util.AddNetworkString("hideiconright")
    
    -- Improved color transfer function
    function _ENT:BetterSetPlayerColor(col)
        if not (col or self) then return end
        timer.Simple(
            .1,
            function()
                if not IsValid(self) then return end
                net.Start("ragplayercolor")
                net.WriteEntity(self)
                net.WriteVector(col)
                net.Broadcast()
            end
        )
    end
    hook.Add("Think", "RADS.PlayerThink", function(ply)
        tbl = player_GetAll()
        time = CurTime()
        for i = 1, #tbl do
            hook.Run("Player Think", tbl[i], time)
        end
    end)
    

    
    -- NEW: Hook to ensure wheeze sounds follow ragdolls
    hook.Add("Think", "RADS_UpdateWheezePosition", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() and IsValid(ply.wheezeEntity) then
                local targetPos
                
                -- If player is ragdolled, follow the ragdoll
                if ply:GetNWBool("radsfa") then
                    local ragdoll = ply:GetNWEntity("player_ragdoll")
                    if IsValid(ragdoll) then
                        -- Try to get head position from ragdoll
                        local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
                        if headBone then
                            targetPos = ragdoll:GetBonePosition(headBone)
                        else
                            targetPos = ragdoll:GetPos() + Vector(0, 0, 64)
                        end
                    else
                        targetPos = ply:GetPos() + Vector(0, 0, 64)
                    end
                else
                    -- Follow the player
                    local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
                    if headBone then
                        targetPos = ply:GetBonePosition(headBone)
                    else
                        targetPos = ply:GetPos() + Vector(0, 0, 64)
                    end
                end
                
                -- Update wheeze entity position
                if targetPos then
                    ply.wheezeEntity:SetPos(targetPos)
                end
            end
        end
    end)
     
     -- NEW: Clean up wheeze entities when player disconnects
     hook.Add("PlayerDisconnected", "RADS_CleanupWheezeOnDisconnect", function(ply)
         if IsValid(ply) and IsValid(ply.wheezeEntity) then
             ply.wheezeEntity:Remove()
             ply.wheezeEntity = nil
         end
     end)
 
     util.AddNetworkString('REMOVECALC')
    util.AddNetworkString("ADDCALC")
    fallChanceTable = {
        [HITGROUP_HEAD] = 0.45,      -- Reduced from 0.75 to 0.45 (45% chance)
        [HITGROUP_CHEST] = 0.35,     -- Reduced from 0.65 to 0.35 (35% chance)
        [HITGROUP_STOMACH] = 0.40,   -- Reduced from 0.50 to 0.40 (40% chance)
        [HITGROUP_LEFTARM] = 0.15,   -- Reduced from 0.25 to 0.15 (15% chance)
        [HITGROUP_RIGHTARM] = 0.15,  -- Reduced from 0.25 to 0.15 (15% chance)
        [HITGROUP_LEFTLEG] = 0.25,   -- Reduced from 0.35 to 0.25 (25% chance)
        [HITGROUP_RIGHTLEG] = 0.25,  -- Reduced from 0.35 to 0.25 (25% chance)
        [HITGROUP_GENERIC] = 0.55    -- NEW: Pelvis hitgroup - high fall chance due to balance importance
    }

    -- Improved shouldFall function that works with damage and body part
    function shouldFall(bodyPart, damage, damageType, ply)
        local baseChance = fallChanceTable[bodyPart] or 0.20 -- Default 20% for unknown body parts
        
        -- NEW: Special pelvis handling - check for existing pelvis damage
        if bodyPart == HITGROUP_GENERIC and IsValid(ply) then
            -- If pelvis is broken, extremely high fall chance
            if ply.brokenpelvis then
                baseChance = 0.95 -- 95% chance if pelvis is already broken
            elseif ply.Organs and ply.Organs['pelvis'] then
                -- Increase fall chance based on pelvis damage level
                local pelvisHealth = ply.Organs['pelvis']
                local pelvisDamagePercent = 1 - (pelvisHealth / 25) -- 25 is max pelvis health
                baseChance = baseChance + (pelvisDamagePercent * 0.3) -- Up to 30% additional fall chance
            end
        end
        
        -- General pelvis damage modifier for all body parts
        local pelvisModifier = 1.0
        if IsValid(ply) and ply.brokenpelvis then
            pelvisModifier = 1.4 -- 40% higher fall chance for any damage when pelvis is broken
        elseif IsValid(ply) and ply.Organs and ply.Organs['pelvis'] then
            local pelvisHealth = ply.Organs['pelvis']
            if pelvisHealth < 15 then -- Severely damaged pelvis
                pelvisModifier = 1.2 -- 20% higher fall chance
            elseif pelvisHealth < 20 then -- Moderately damaged pelvis
                pelvisModifier = 1.1 -- 10% higher fall chance
            end
        end
        
        -- Damage scaling: higher damage increases chance
        local damageMultiplier = 1.0
        if damage then
            if damage >= 75 then
                damageMultiplier = 1.8 -- Very high damage
            elseif damage >= 50 then
                damageMultiplier = 1.5 -- High damage
            elseif damage >= 35 then
                damageMultiplier = 1.2 -- Medium damage
            elseif damage >= 25 then
                damageMultiplier = 1.0 -- Normal damage
            else
                damageMultiplier = 0.7 -- Low damage
            end
        end
        
        -- Damage type modifiers
        local typeMultiplier = 1.0
        if damageType then
            if bit.band(damageType, DMG_BLAST) ~= 0 then
                typeMultiplier = 1.4 -- Explosions more likely to knock down
            elseif bit.band(damageType, DMG_BUCKSHOT) ~= 0 then
                typeMultiplier = 1.2 -- Shotguns more likely
            elseif bit.band(damageType, DMG_CLUB) ~= 0 then
                typeMultiplier = 0.8 -- Club damage less likely
            end
        end
        
        local finalChance = baseChance * damageMultiplier * typeMultiplier * pelvisModifier
        finalChance = math.min(finalChance, 0.95) -- Cap at 95%
        
        return math.random() < finalChance
    end

    concommand.Add("rads_viewrag", function(ply, cmd, args)
        if not ply:IsSuperAdmin() then return end
        local tr = ply:GetEyeTrace()
        if not IsValid(tr.Entity) or not tr.Entity:IsPlayer() then return end
        local tarpp = tr.Entity
        rads(tarpp)
    end)
    
    -- Console command to remove handcuffs from ragdolls
    concommand.Add("rads_remove_handcuffs", function(ply, cmd, args)
        if not IsValid(ply) then return end
        
        local tr = util.TraceLine({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * 80,
            filter = ply
        })
        
        if IsValid(tr.Entity) and tr.Entity:IsRagdoll() then
            local ragdollOwner = tr.Entity:GetNWEntity("owner")
            
            -- Check if it's a handcuffed player ragdoll
            if IsValid(ragdollOwner) and ragdollOwner:IsPlayer() and tr.Entity:GetNWBool("RADS_Handcuffed", false) then
                -- Remove handcuff status
                tr.Entity:SetNWBool("RADS_Handcuffed", false)
                ragdollOwner:SetNWBool("RADS_Handcuffed", false)
                
                -- Remove handcuff model
                if IsValid(tr.Entity.HandcuffModel) then
                    tr.Entity.HandcuffModel:Remove()
                    tr.Entity.HandcuffModel = nil
                end
                
                -- Play sound
                tr.Entity:EmitSound("physics/metal/metal_solid_impact_soft1.wav", 60, 100)
                
                -- Notify players
                ply:PrintMessage(HUD_PRINTCENTER, "Removed handcuffs from " .. ragdollOwner:Nick() .. ".")
                ragdollOwner:PrintMessage(HUD_PRINTCENTER, ply:Nick() .. " removed your handcuffs!")
                
                -- Create handcuffs item on ground
                local handcuffsEnt = ents.Create("ent_jack_hmcd_handcuffs")
                handcuffsEnt:SetPos(tr.Entity:GetPos() + Vector(0, 0, 10))
                handcuffsEnt:SetAngles(Angle(0, math.random(0, 360), 0))
                handcuffsEnt:Spawn()
                handcuffsEnt:Activate()
                
                -- Add some velocity to the dropped handcuffs
                local phys = handcuffsEnt:GetPhysicsObject()
                if IsValid(phys) then
                    phys:SetVelocity(Vector(math.random(-50, 50), math.random(-50, 50), math.random(20, 50)))
                end
            else
                ply:PrintMessage(HUD_PRINTCENTER, "No handcuffed ragdoll in range.")
            end
        else
            ply:PrintMessage(HUD_PRINTCENTER, "No ragdoll in range.")
        end
    end)

    -- Removed damage interruption hook as it was causing issues with getting up
    -- hook.Add("EntityTakeDamage", "RADS.RagdollDamageInterrupt", function(target, dmginfo)
    --     local owner = nil
    --     if IsValid(target) and target:IsRagdoll() then
    --         owner = target:GetNWEntity("owner") or target:GetNWEntity('deadbodyowner')
    --     elseif IsValid(target) and target:IsPlayer() then
    --         owner = target
    --     end
    -- 
    --     if IsValid(owner) and owner:IsPlayer() and owner:GetNWBool("radsfa") then
    --         owner.takingDamage = true
    --     end
    -- end)
end

local CustomWeight = {
    ["models/player/police_fem.mdl"] = 50,
    ["models/player/police.mdl"] = 60,
    ["models/player/combine_soldier.mdl"] = 70,
    ["models/player/combine_super_soldier.mdl"] = 80,
    ["models/player/combine_soldier_prisonguard.mdl"] = 70,
    ['models/player/charple.mdl'] = 5
}

if SERVER then
    util.AddNetworkString("SendSavedPlayerWeaponsToActivator")
    util.AddNetworkString("SavedPlayerWeapons")
    -- ConVars removed - values are now hardcoded
    -- rads_waketime = 2.5, rads_upspeed = 400, rads_maxupspeed = 400
    CreateConVar("rads_namedisplay_server", "1", {FCVAR_ARCHIVE, "Enable server-side name display support"})
    function SendSavedPlayerWeapons(ply)
        net.Start("SavedPlayerWeapons")
        net.WriteTable(ply.Info.Weapons3)
        net.Send(ply)
    end

    savedPlayerState = {}
    function RADS_EzArmorSaveInfo(ply)
        local steamID = ply:SteamID()
        savedPlayerState[steamID] = {
            EZarmor = {},
            EZhealth = ply.EZhealth or nil,
            EZirradiated = ply.EZirradiated or nil,
            o2 = ply.o2 or nil,
            EZbleeding = ply.EZbleeding or nil,
            EZvirus = ply.EZvirus or nil,
            -- NEW: Save lung damage oxygen system states
            lungOxygenActive = ply.lungOxygenActive or false,
            lungStaminaDrain = ply.lungStaminaDrain or false,
            wheezeEntity = ply.wheezeEntity or nil
        }

        if ply.EZarmor then
            savedPlayerState[steamID].EZarmor = {
                items = ply.EZarmor.items or nil,
                speedFrac = ply.EZarmor.speedFrac or nil,
                effects = ply.EZarmor.effects or nil,
                mskmat = ply.EZarmor.mskmat or nil,
                sndlop = ply.EZarmor.sndlop or nil,
                suited = ply.EZarmor.suited or nil,
                bodygroups = ply.EZarmor.bodygroups or nil,
                totalWeight = ply.EZarmor.totalWeight or nil
            }
        end
    end

    function RADS_RestoreEzArmor(ply) -- SendSavedPlayerWeapons(ply)
        local steamID = ply:SteamID()
        if savedPlayerState[steamID] then
            local state = savedPlayerState[steamID]
            if RADS.IsJmodAct() and ply.EZarmor then
                ply.EZarmor = {
                    items = state.EZarmor.items,
                    speedFrac = state.EZarmor.speedFrac,
                    effects = state.EZarmor.effects,
                    mskmat = state.EZarmor.mskmat,
                    sndlop = state.EZarmor.sndlop,
                    suited = state.EZarmor.suited,
                    bodygroups = state.EZarmor.bodygroups,
                    totalWeight = state.EZarmor.totalWeight
                }

                ply.EZhealth = state.EZhealth
                ply.EZirradiated = state.EZirradiated
                ply.o2 = state.o2
                ply.EZbleeding = state.EZbleeding
                ply.EZvirus = state.EZvirus
                
                -- NEW: Restore lung damage oxygen system states
                ply.lungOxygenActive = state.lungOxygenActive
                ply.lungStaminaDrain = state.lungStaminaDrain
                
                -- Clean up any existing wheeze entity before restoring
                if IsValid(ply.wheezeEntity) then
                    ply.wheezeEntity:Remove()
                    ply.wheezeEntity = nil
                end
            end

            savedPlayerState[steamID] = nil
        end
    end

    function RADS_SavePlyInfo(ply)
        ply.Info = {}
        local info = ply.Info
        info.HasSuit = ply:IsSuitEquipped()
        info.SuitPower = ply:GetSuitPower()
        info.Ammo = ply:GetAmmo()
        info.ActiveWeapon = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or nil
        info.runspeed = ply:GetRunSpeed()
        info.walkspeed = ply:GetWalkSpeed()
        info.ActiveWeapon2 = ply:GetActiveWeapon()
        GetFakeWeapon(ply)
        info.Angles = ply:GetAngles()
        info.Weapons = {}
        for i, wep in pairs(ply:GetWeapons()) do
            info.Weapons[wep:GetClass()] = {
                Clip1 = wep:Clip1(),
                Clip2 = wep:Clip2(),
                AmmoType = wep:GetPrimaryAmmoType()
            }
            
            -- RADS Grappling Hook Compatibility: Save grappling hook state
            if wep:GetClass() == "wep_jack_hmcd_grapl" and wep.SaveGrapplingState then
                wep:SaveGrapplingState()
            end
            
            -- IED Compatibility: Save IED rigged state for proper restoration
            if wep:GetClass() == "wep_jack_hmcd_ied" and wep.GetRigged then
                info.Weapons[wep:GetClass()].IEDRigged = wep:GetRigged()
            end
        end

        info.Weapons2 = {}
        for i, wep in ipairs(ply:GetWeapons()) do
            info.Weapons2[i - 1] = wep:GetClass()
        end

        info.Weapons3 = {}
        for i, wep in ipairs(ply:GetWeapons()) do
        end

        SendSavedPlayerWeapons(ply) -- info.Weapons3[wep:GetClass()] = wep:GetPrintName()
        info.eyeviewcvar = ply:GetInfoNum('eyeview_enabled', 1)
        info.AllAmmo = {}
        local i
        for ammo, amt in pairs(ply:GetAmmo()) do
            i = i or 0
            i = i + 1
            info.AllAmmo[ammo] = {i, amt}
        end
        return info
    end

    function RADS_ReturnPlyInfo(ply)
        ClearFakeWeapon(ply)
        ply:SetSuppressPickupNotices(true)
        local info = ply.Info
        if not info then return end
        
        -- CRITICAL FIX: Enhanced weapon duplication prevention for guns1 compatibility
        if ply.gettingUpFromRagdoll then
            -- Store the flag on ALL existing weapons before stripping
            for _, weapon in pairs(ply:GetWeapons()) do
                if IsValid(weapon) then
                    weapon.ownerGettingUpFromRagdoll = true
                    -- Special handling for guns1 weapons
                    if string.find(weapon:GetClass(), "wep_jack_") or string.find(weapon:GetClass(), "wep_mann_") or string.find(weapon:GetClass(), "wep_viz_") then
                        weapon.preventDuplication = true
                    end
                end
            end
            
            -- Clean up any existing dropped weapon entities from guns1 that might cause duplication
            -- Only remove dropped weapon boxes, not planted explosives
            for _, ent in pairs(ents.FindByClass("prop_physics")) do
                if IsValid(ent) and ent.IEDAttacker == ply then
                    -- Check if this is a dropped weapon box (not a planted explosive)
                    -- Planted explosives should have ExplodeIED function, dropped weapons don't
                    if not ent.ExplodeIED then
                        ent:Remove()
                    end
                end
            end
        end
        
        ply:StripWeapons()
        ply:StripAmmo()
        ply.slots = {}
        
        -- Enhanced weapon restoration with duplication prevention
        for name, wepinfo in pairs(info.Weapons or {}) do
            local weapon = ply:Give(name, true)
            if IsValid(weapon) then
                -- Set gettingUpFromRagdoll flag on newly given weapons
                if ply.gettingUpFromRagdoll then
                    weapon.ownerGettingUpFromRagdoll = true
                    weapon.preventDuplication = true
                end
                
                -- Restore clip data
                if wepinfo.Clip1 ~= nil and wepinfo.Clip2 ~= nil then
                    weapon:SetClip1(wepinfo.Clip1)
                    weapon:SetClip2(wepinfo.Clip2)
                end
                
                -- RADS Grappling Hook Compatibility: Restore grappling hook state
                if weapon:GetClass() == "wep_jack_hmcd_grapl" and weapon.RestoreGrapplingState then
                    timer.Simple(0.1, function()
                        if IsValid(weapon) and IsValid(ply) then
                            weapon:RestoreGrapplingState()
                        end
                    end)
                end
                
                -- IED Compatibility: Restore IED state if needed
                if weapon:GetClass() == "wep_jack_hmcd_ied" and wepinfo.IEDRigged then
                    timer.Simple(0.05, function()
                        if IsValid(weapon) and IsValid(ply) then
                            weapon:SetRigged(wepinfo.IEDRigged)
                            
                            -- Reconnect to planted explosive if it exists
                            for _, ent in pairs(ents.FindByClass("prop_physics")) do
                                if IsValid(ent) and ent.IEDAttacker == ply and ent.ExplodeIED then
                                    weapon.Explosive = ent
                                    break
                                end
                            end
                        end
                    end)
                end
            end
        end

        for ammo, amt in pairs(info.Ammo or {}) do
            ply:GiveAmmo(amt, ammo)
        end

        if info.ActiveWeapon then ply:SelectWeapon(info.ActiveWeapon) end
        if info.HasSuit then
            ply:EquipSuit()
            ply:SetSuitPower(info.SuitPower or 0)
        else
            ply:RemoveSuit()
        end

        ply:SetRunSpeed(info.runspeed)
        ply:SetWalkSpeed(info.walkspeed)
        ply:SetHealth(info.Hp or 0)
        ply:SetArmor(info.Armor or 0)
        ply:SetEyeAngles(info.Angles)
        info.Weapons3 = nil
        
        -- CRITICAL: Clear gettingUpFromRagdoll flag after restoration to prevent lingering effects
        if ply.gettingUpFromRagdoll then
            timer.Simple(0.2, function()
                if IsValid(ply) then
                    ply.gettingUpFromRagdoll = nil
                    -- Clear flags from all weapons as well
                    for _, weapon in pairs(ply:GetWeapons()) do
                        if IsValid(weapon) then
                            weapon.ownerGettingUpFromRagdoll = nil
                            weapon.preventDuplication = nil
                        end
                    end
                end
            end)
        end
    end

    function GetFakeWeapon(ply)
        ply.curweapon = ply.Info.ActiveWeapon
    end

    function ClearFakeWeapon(ply)
        if ply.FakeShooting then 
			if _G.DespawnWeapon then
				_G.DespawnWeapon(ply)
			else
				if GetConVar("developer"):GetInt() > 0 then
        print("[RADS] ERROR: DespawnWeapon function not available globally at line 470!")
    end
			end
		end
    end

    function RADS_RagBones(ent) --     util.AddNetworkString('RetrieveWeaponFromRagdoll') -- net.Receive("RetrieveWeaponFromRagdoll", function(len, ply) --  weaponClass = net.ReadTable() --     local tr = ply:GetEyeTrace() --     if IsValid(tr.Entity) and tr.Entity:GetClass() == "prop_ragdoll" then --         local owner = tr.Entity:GetNWEntity("owner") --         local deadbodyowner = tr.Entity:GetNWEntity('deadbodyowner') --         if IsValid(owner) and owner:IsPlayer() or IsValid(deadbodyowner) and deadbodyowner:IsPlayer() then --             if owner.Info and owner.Info.Weapons3 then --                 owner.Info.Weapons3[weaponClass] = nil --                 ply:Give(weaponClass) --             else --                 ply:Give(weaponClass) --             end --         end --     end -- end) 
        local rag = ent:GetNWEntity("player_ragdoll")
        local ragdollBones = rag:GetPhysicsObjectCount()
        local vel = ent:GetVelocity() / 1
        for i = 0, rag:GetPhysicsObjectCount() - 1 do
            local physobj = rag:GetPhysicsObjectNum(i)
            local ragbonename = rag:GetBoneName(rag:TranslatePhysBoneToBone(i))
            local bone = ent:LookupBone(ragbonename)
            if bone then
                local bonemat = ent:GetBoneMatrix(bone)
                if bonemat then
                    local bonepos = bonemat:GetTranslation()
                    local boneang = bonemat:GetAngles()
                    physobj:SetPos(bonepos, true)
                    physobj:SetAngles(boneang)
                    if ent:Alive() then vel = vel end
                    if not ent:Alive() then vel = vel / 2 end
                    physobj:AddVelocity(vel)
                end
            end
        end
    end

    -- RADS_ValidPos function removed due to being buggy
    -- function RADS_ValidPos(originalPos, ply)
    --     This function is removed due to being buggy
    -- end

    -- Function to remove all armors from a ragdoll
    local function RemoveRag(rag)
        if not IsValid(rag) then return end
        if rag.armors then
            for id, ent in pairs(rag.armors) do
                if IsValid(ent) then
                    ent.override = true
                    ent:Remove()
                end
            end
        end
        
        -- Clean up gore system when ragdoll is removed
        if rag.hasGoreExplosion then
            -- Remove gore stump
            if IsValid(rag.goreStump) then
                rag.goreStump:Remove()
                rag.goreStump = nil
            end
            
            -- Stop blood stream timer
            local timerName = "RADS_BloodStream_" .. rag:EntIndex()
            if timer.Exists(timerName) then
                timer.Remove(timerName)
            end
            
            rag.hasGoreExplosion = nil
        end
    end

    hook.Add("RADS_Ready", "RADS.CustomApi", function(rag) if GetConVar("developer"):GetInt() > 0 then print("") end end)
    
    -- RADS Grappling Hook Compatibility Hook
    hook.Add("RADS_Ready", "RADS.GrapplingHookCompat", function(rag)
        local ply = rag:GetNWEntity("owner")
        if not IsValid(ply) then return end
        
        -- Handle grappling hook physics interactions with ragdoll
        if ply.GrapplingHookData and ply.GrapplingHookData.pos then
            timer.Simple(0.1, function()
                if IsValid(rag) and IsValid(ply) then
                    -- Find the grappling hook entity
                    local hookEnt = nil
                    for _, ent in pairs(ents.FindByClass("ent_jack_hmcd_grapl")) do
                        if ent.Owner == ply then
                            hookEnt = ent
                            break
                        end
                    end
                    
                    if IsValid(hookEnt) then
                        -- Get the pelvis bone and physics object for proper attachment
                        local pelvisBone = rag:LookupBone("ValveBiped.Bip01_Pelvis")
                        local pelvisPhysBone = rag:TranslateBoneToPhysBone(pelvisBone)
                        local pelvisPhys = rag:GetPhysicsObjectNum(pelvisPhysBone)
                        
                        if IsValid(pelvisPhys) then
                            -- Create a rope constraint between hook and ragdoll pelvis (invisible)
                            local ropeConstraint = constraint.Rope(
                                hookEnt, rag,
                                0, pelvisPhysBone,
                                Vector(0,0,0), Vector(0,0,0),
                                ply.GrapplingHookData.ropeLength or 1000,
                                0, 0, 0, "cable/rope", false
                            )
                            
                            -- Store constraint for cleanup
                            rag.GrapplingRopeConstraint = ropeConstraint
                            
                            -- Apply grappling forces to pelvis physics object
                            local hookPos = hookEnt:GetPos()
                            local pelvisPos = pelvisPhys:GetPos()
                            local dist = hookPos:Distance(pelvisPos)
                            local desiredDist = ply.GrapplingHookData.ropeLength or 1000
                            
                            if dist > desiredDist then
                                local dir = (hookPos - pelvisPos):GetNormalized()
                                local force = dir * math.min((dist - desiredDist) * 100, 3000)
                                pelvisPhys:ApplyForceCenter(force)
                                
                                -- Apply counter-force to hook for realistic physics
                                hookEnt:GetPhysicsObject():ApplyForceCenter(-dir * force * 0.3)
                            end
                            
                            -- Create a think timer for continuous grappling physics
                            timer.Create("GrapplingPhysics_" .. rag:EntIndex(), 0.1, 0, function()
                                if not IsValid(rag) or not IsValid(hookEnt) or not IsValid(pelvisPhys) then
                                    timer.Remove("GrapplingPhysics_" .. rag:EntIndex())
                                    return
                                end
                                
                                local hookPos = hookEnt:GetPos()
                                local pelvisPos = pelvisPhys:GetPos()
                                local dist = hookPos:Distance(pelvisPos)
                                local desiredDist = ply.GrapplingHookData.ropeLength or 1000
                                
                                if dist > desiredDist then
                                    local dir = (hookPos - pelvisPos):GetNormalized()
                                    local force = dir * math.min((dist - desiredDist) * 80, 2500)
                                    pelvisPhys:ApplyForceCenter(force)
                                    
                                    -- Apply counter-force to hook
                                    hookEnt:GetPhysicsObject():ApplyForceCenter(-dir * force * 0.2)
                                end
                            end)
                        end
                    end
                end
            end)
        end
    end)
    
    -- RADS Grappling Hook Cleanup Hooks
    hook.Add("PlayerDisconnected", "RADS.GrapplingHookCleanup", function(ply)
        if not IsValid(ply) then return end
        
        -- Clean up grappling physics timer
        local rag = ply:GetNWEntity("player_ragdoll")
        if IsValid(rag) then
            timer.Remove("GrapplingPhysics_" .. rag:EntIndex())
            
            -- Clean up rope constraint
            if rag.GrapplingRopeConstraint and IsValid(rag.GrapplingRopeConstraint) then
                rag.GrapplingRopeConstraint:Remove()
                rag.GrapplingRopeConstraint = nil
            end
        end
        
        -- Clean up any grappling hooks owned by disconnecting player
        for _, ent in pairs(ents.FindByClass("ent_jack_hmcd_grapl")) do
            if ent.Owner == ply then
                ent:Remove()
            end
        end
        
        -- Clean up stored grappling hook data
        ply.GrapplingHookState = nil
        ply.GrapplingHookData = nil
    end)
    
    hook.Add("PlayerDeath", "RADS.GrapplingHookCleanup", function(ply)
        if not IsValid(ply) then return end
        
        -- Clean up grappling physics timer
        local rag = ply:GetNWEntity("player_ragdoll")
        if IsValid(rag) then
            timer.Remove("GrapplingPhysics_" .. rag:EntIndex())
            
            -- Clean up rope constraint
            if rag.GrapplingRopeConstraint and IsValid(rag.GrapplingRopeConstraint) then
                rag.GrapplingRopeConstraint:Remove()
                rag.GrapplingRopeConstraint = nil
            end
        end
        
        -- Clean up grappling hooks on death
        for _, ent in pairs(ents.FindByClass("ent_jack_hmcd_grapl")) do
            if ent.Owner == ply then
                ent:Remove()
            end
        end
        
        -- Clean up grappling hook weapon state
        local grapplingWeapon = ply:GetWeapon("wep_jack_hmcd_grapl")
        if IsValid(grapplingWeapon) and grapplingWeapon.CleanupGrapplingHook then
            grapplingWeapon:CleanupGrapplingHook()
        end
        
        -- Clean up stored data
        ply.GrapplingHookState = nil
        ply.GrapplingHookData = nil
    end)
    function rads(ply, isManual)
        if not GetConVar("rads_status"):GetBool() then
            if GetConVar("developer"):GetInt() > 0 then
    print("Script is disabled. Not executing functionality.")
end
            return
        end

        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then 
            if GetConVar("developer"):GetInt() > 0 then
                print("[RADS] Failed validation - IsValid: " .. tostring(IsValid(ply)) .. ", IsPlayer: " .. tostring(ply:IsPlayer()) .. ", Alive: " .. tostring(ply:Alive()))
            end
            return 
        end
        if timer.Exists("radstimer" .. ply:EntIndex()) then 
            if GetConVar("developer"):GetInt() > 0 then
                print("[RADS] Timer exists for player: " .. ply:Nick())
            end
            return 
        end
        if ply:GetNWBool("gh.Ghosted") then 
            if GetConVar("developer"):GetInt() > 0 then
                print("[RADS] Player is ghosted: " .. ply:Nick())
            end
            return 
        end
        
        if GetConVar("developer"):GetInt() > 0 then
            print("[RADS] Attempting to ragdoll player: " .. ply:Nick() .. ", Manual: " .. tostring(isManual))
        end
        
        -- Only apply 2-second protection for manual ragdolling
        if isManual and ply.lastGetUpTime and CurTime() - ply.lastGetUpTime < 1 then
            ply:ChatPrint("You need to wait a moment before you can ragdoll again.")
            return
        end
        
        local rag = ply:GetNWEntity("player_ragdoll")
        if IsValid(rag) then
            if ply.brokenspine then
                ply:ChatPrint("You are Paralyzed.")
                return
            end
            
            -- Prevent getting up from shock ragdoll
            local shock = ply:GetNWFloat("RADS_Shock", 0)
            local ragdollThreshold = GetConVar("rads_shock_ragdoll_threshold"):GetFloat()
            if shock >= ragdollThreshold and rag.isShockRagdoll then
                return
            end

            ply:SetNWBool("radsfa", false)
        local health = ply:Health()
        ragpos = rag:GetPos()
        respawnmodel = ply:GetModel()
        spawnpos = rag:GetPos() -- Direct position without room checking
        
        -- Transfer vFire from ragdoll back to player
        RADS_TransferVFireToPlayer(rag, ply)
        
        -- Mark player as getting up from ragdoll to preserve adrenaline
        ply.gettingUpFromRagdoll = true
        
        -- Set the get up time to prevent immediate re-ragdolling
        ply.lastGetUpTime = CurTime()
        
        -- Restore normal NPC targeting when getting up from ragdoll
        ply:SetNoTarget(false)
        
        ply:Spawn()
            ply:SetPos(spawnpos) -- RADS_PostRag(ply)
            
            -- Clean up bullseye entity when ragdoll is removed
            if IsValid(rag.bullseye) then
                print("[BULLSEYE DEBUG] Cleaning up bullseye entity for player: " .. ply:Name())
                rag.bullseye:Remove()
                rag.bullseye = nil
            end
            
            rag:Remove()
            if table.HasValue(BleedingEntities, rag) then table.insert(BleedingEntities, ply) end
            ply.fake = false
            ply:SetModel(respawnmodel)
            ply.resetinv = true
            hook.Run("RADSLoadout", ply)
            ply.resetinv = false
            ply:SetParent(nil)
            ply:SetNoDraw(false)
            ply:SetMoveType(MOVETYPE_WALK)
            ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
            ply:DrawViewModel(true)
            ply:DrawWorldModel(true)
            ply:SetSuppressPickupNotices(false)
            ply:SetShouldPlayPickupSound(true)
            ply.FakeShooting = false
            ply:SetNWEntity("player_ragdoll", nil)
            ply:SetViewEntity(ply)
            ply:SetHealth(health)
            net.Start("REMOVECALC")
        net.Send(ply)
        if IsValid(rag.target) then rag.target:Remove() end
        timer.Remove("respawntimer" .. ply:EntIndex())
        
        -- Clean up grappling physics timer when getting up
        timer.Remove("GrapplingPhysics_" .. rag:EntIndex())
        
        -- Clean up rope constraint
        if rag.GrapplingRopeConstraint and IsValid(rag.GrapplingRopeConstraint) then
            rag.GrapplingRopeConstraint:Remove()
            rag.GrapplingRopeConstraint = nil
        end
        
        -- Clear the flag after a short delay
        timer.Simple(0.2, function()
            if IsValid(ply) then
                ply.gettingUpFromRagdoll = nil
            end
        end)
        else
            local veh
            if ply:InVehicle() then
                veh = ply:GetVehicle()
                ply:ExitVehicle()
            end

            ply:SetNoDraw(true)
            timer.Create("respawntimer" .. ply:EntIndex(), 99999, 1, function() end)
            ply.fake = true
            if ply.IsBleeding or (ply.BloodLosing or 0) > 0 then
                rag.IsBleeding = true
                rag.bloodNext = CurTime()
                rag.Blood = ply.Blood
                RADS_Bleed(rag)
            end

            RADS_SavePlyInfo(ply)
            RADS_EzArmorSaveInfo(ply)
            if not ply:IsInWorld() then return end
            net.Start("ADDCALC")
            net.Send(ply)
            local rag = ents.Create("prop_ragdoll")
            rag:SetModel(ply:GetModel())
            rag:SetSkin(ply:GetSkin())
            for k, v in pairs(ply:GetBodyGroups()) do
                rag:SetBodygroup(v.id, ply:GetBodygroup(v.id))
            end

            -- Get player color and transfer it
            local playerColor = ply:GetPlayerColor()
            if playerColor then
                rag:BetterSetPlayerColor(playerColor)
            else
                -- Simple fallback
                rag:BetterSetPlayerColor(Vector(1, 1, 1))
            end
            
            rag:SetAngles(ply:GetAngles())
            rag:Spawn()
            
            timer.Simple(0, function()
                if IsValid(ply) and IsValid(rag) then
                    ply:SetNWBool("radsfa", true) -- RADS_PreRag(ply)
                    ply:SetParent(rag)
                    ply:SetMoveType(MOVETYPE_NONE)
                    ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
                end
            end)

            rag:Activate()
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and table.HasValue(Guns, wep:GetClass()) then
                if _G.SpawnWeapon then
                    _G.SpawnWeapon(ply)
                    ply.FakeShooting = true
                else
                    if GetConVar("developer"):GetInt() > 0 then
                        print("[RADS] ERROR: SpawnWeapon function not available globally!")
                    end
                end
            end

            rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
            ply:SetNWEntity("player_ragdoll", rag)
            rag:SetNWEntity("owner", ply)
            rag:SetPos(ply:GetPos())
            RADS_RagBones(ply)
            rag:Activate()
            
            -- Transfer vFire to ragdoll with proper timing
            timer.Simple(0.1, function()
                if IsValid(ply) and IsValid(rag) then
                    RADS_TransferVFire(ply, rag)
                end
            end)
            -- Supersus feature removed - convar no longer exists
            --[[
            if GetConVar("rads_supersus"):GetBool() then
                local light = ents.Create("light_dynamic")
                light:SetPos(rag:GetPos() + Vector(0, 0, 20))
                light:SetKeyValue("brightness", "5")
                light:SetKeyValue("distance", "200")
                light:SetKeyValue("style", "0")
                light:Spawn()
                light:Activate()
                light:Fire("TurnOn", "", 0)
                light:SetParent(rag)
            end
            --]]

            local rpos = rag:GetPos()
            timer.Simple(0, function()
                if RADS.IsJmodAct() then
                    local armors = {}
                    for id, info in pairs(ply.EZarmor.items) do
                        local ent = CreateArmor(rag, info)
                        ent.armorID = id
                        ent.ragdoll = rag
                        ent.Owner = ply
                        armors[id] = ent
                        ent:CallOnRemove("Fake", function() 
                            if ent.override then return end
                            rag.armors[ent.armorID] = nil
                            JMod.RemoveArmorByID(ply, ent.armorID, true)
                        end)
                    end

                    rag.armors = armors
                    rag:CallOnRemove("ArmorCleanup", function(ragdoll) 
                        if IsValid(ragdoll) then 
                            RemoveRag(ragdoll) 
                        end 
                    end)
                end
            end)

            if IsValid(rag:GetPhysicsObject()) then rag:GetPhysicsObject():SetMass(CustomWeight[rag:GetModel()] or 20) end
            rag:AddEFlags(EFL_KEEP_ON_RECREATE_ENTITIES)
            ply:SetActiveWeapon(nil)
            ply:DropObject()
            ply:SetPos(rag:GetPos())
            rag.pulse = ply.pulse or 0
            RADS_RagBones(ply)
            
            -- Transfer player velocity to ragdoll (FIX FOR EXCESSIVE INERTIA)
            
            -- Mark as shock ragdoll if applicable
            local shock = ply:GetNWFloat("RADS_Shock", 0)
            local ragdollThreshold = GetConVar("rads_shock_ragdoll_threshold"):GetFloat()
            if shock >= ragdollThreshold then
                rag.isShockRagdoll = true
                rag.shockLevel = shock
            end
            local playerVel = ply:GetVelocity()
            if playerVel:Length() > 0 then
                -- Apply velocity to main physics object with reduced multiplier to prevent excessive speed
                local velocityMultiplier = 0.85 -- Reduce from default 1.0 to prevent speed doubling/tripling
                
                -- GOALKEEPER DIVING MECHANICS
                -- Check if player was jumping (vertical velocity > 100) and holding A or D
                local isJumping = playerVel.z > 100
                local holdingLeft = ply:KeyDown(IN_MOVELEFT)
                local holdingRight = ply:KeyDown(IN_MOVERIGHT)
                
                if isJumping and (holdingLeft or holdingRight) then
                    -- Player is diving like a goalkeeper
                    local diveForce = 130 -- Reduced horizontal dive force to prevent excessive flinging
                    local diveDirection = Vector(0, 0, 0)
                    local angularVelocity = Vector(0, 0, 0)
                    
                    -- Use player's right vector for proper lateral diving
                    local playerRight = ply:GetRight()
                    local playerForward = ply:GetForward()
                    
                    if holdingLeft then
                        diveDirection = playerRight * -diveForce -- Dive left (negative right)
                        -- Angular velocity to lean left (roll around forward axis) - increased for more dramatic lean
                        angularVelocity = playerForward * -25 -- Negative roll for left lean
                    elseif holdingRight then
                        diveDirection = playerRight * diveForce -- Dive right (positive right)
                        -- Angular velocity to lean right (roll around forward axis) - increased for more dramatic lean
                        angularVelocity = playerForward * 25 -- Positive roll for right lean
                    end
                    
                    -- Apply diving velocity with original player velocity
                    local finalVelocity = (playerVel * velocityMultiplier) + diveDirection
                    rag:GetPhysicsObject():SetVelocity(finalVelocity)
                    
                    -- Mark ragdoll as diving to prevent rolling until landing
                    rag.isDiving = true
                    rag.diveStartTime = CurTime()
                    
                    -- Set timer to return to normal rolling after landing (3 seconds max)
                    timer.Simple(3, function()
                        if IsValid(rag) then
                            rag.isDiving = false
                        end
                    end)
                    
                    -- Apply diving velocity and angular velocity to all physics objects for realistic goalkeeper dive
                    for i = 0, rag:GetPhysicsObjectCount() - 1 do
                        local physObj = rag:GetPhysicsObjectNum(i)
                        if IsValid(physObj) then
                            physObj:SetVelocity(finalVelocity)
                            -- Add angular velocity to make the ragdoll lean/rotate during dive
                            physObj:AddAngleVelocity(angularVelocity)
                        end
                    end
                else
                    -- Normal ragdoll velocity transfer
                    rag:GetPhysicsObject():SetVelocity(playerVel * velocityMultiplier)
                    
                    -- Also apply to other physics objects for more realistic momentum transfer
                    for i = 0, rag:GetPhysicsObjectCount() - 1 do
                        local physObj = rag:GetPhysicsObjectNum(i)
                        if IsValid(physObj) then
                            physObj:SetVelocity(playerVel * velocityMultiplier)
                        end
                    end
                end
            end
            
            hook.Run("RADS_Ready", rag)
            
            -- Create npc_bullseye for ragdolled player
            if IsValid(rag) and IsValid(ply) then
                local bullseye = ents.Create("npc_bullseye")
                if IsValid(bullseye) then
                    -- Position bullseye slightly outside ragdoll body for NPC visibility
                    local ragPos = rag:GetPos()
                    local ragAngles = rag:GetAngles()
                    local offset = ragAngles:Forward() * 10 + Vector(0, 0, 15) -- 10 units forward, 15 units up
                    bullseye:SetPos(ragPos + offset)
                    bullseye:SetAngles(ragAngles)
                    bullseye:Spawn()
                    bullseye:Activate()
                    
                    -- Make bullseye bigger
                    bullseye:SetModelScale(2.0, 0)
                    
                    -- Make bullseye nodraw and remove physics
                    bullseye:SetNoDraw(true)
                    bullseye:SetSolid(SOLID_NONE)
                    bullseye:SetMoveType(MOVETYPE_NONE)
                    bullseye:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
                    
                    -- Parent bullseye to ragdoll
                    bullseye:SetParent(rag)
                    
                    -- Store references
                    rag:SetNWEntity("bullseye", bullseye)
                    bullseye:SetNWEntity("owner", ply)
                    bullseye:SetNWEntity("ragdoll", rag)
                    
                    -- Set NPC relationships based on player's relationships
                    timer.Simple(0.1, function()
                        if IsValid(bullseye) and IsValid(ply) then
                            for _, npc in pairs(ents.FindByClass("npc_*")) do
                                if IsValid(npc) then
                                    local playerDisposition = D_HT -- Default to hate disposition
                                    if npc.Disposition then
                                        playerDisposition = npc:Disposition(ply)
                                        print("[RADS BULLSEYE] NPC " .. npc:GetClass() .. " disposition to player: " .. playerDisposition)
                                    else
                                        print("[RADS BULLSEYE] NPC " .. npc:GetClass() .. " has no Disposition method, using default: " .. playerDisposition)
                                    end
                                    npc:AddEntityRelationship(bullseye, playerDisposition, 99)
                                end
                            end
                            print("[RADS BULLSEYE] Created bullseye for player: " .. ply:Nick() .. " at position: " .. tostring(bullseye:GetPos()))
                        end
                    end)
                    
                    -- Make NPCs ignore the ragdolled player and target the bullseye instead
                    ply:SetNoTarget(true)
                end
            end
        end

        if IsValid(veh) then rag:GetPhysicsObject():SetVelocity(veh:GetPhysicsObject():GetVelocity() * 5) end
    end

    function CC(ply, message)
        if not IsValid(ply) then return end
        local curTime = CurTime()
        if ply.lastChatTime == nil or curTime - ply.lastChatTime >= 3 then
            ply.lastChatTime = curTime
            ply:ChatPrint(message)
        end
    end

    hook.Add("PlayerFootstep", "RADS.BrokenBones", function(ply, pos, foot, sound, volume, filter)
        if ply.LeftLeg <= 0.6 or ply.RightLeg <= 0.6 then
            if ply:IsSprinting() then
                ply.pain = ply.pain + 35
            end
        end
    end)

    hook.Add("Player Think", "RADS.SYNCPOS", function(ply)
        local qw = ply:GetNWEntity('player_ragdoll')
        if IsValid(qw) and ply:IsRag() then
            local qe = qw:GetAttachment(qw:LookupAttachment("eyes")).Pos
            ply:SetPos(qe)
        end
    end)

    util.AddNetworkString("CheckPulseAndLink")
    net.Receive("CheckPulseAndLink", function(len, ply)
        local ragdoll = net.ReadEntity()
        if IsValid(ragdoll) and ragdoll:IsRagdoll() then
            -- Check if this is a dead body first
            local deadOwner = ragdoll:GetNWEntity('deadbodyowner')
            local livingOwner = ragdoll:GetNWEntity('owner')
            
            -- Enhanced debug info
            local debugMsg = "[STATUS DEBUG] "
            if IsValid(deadOwner) then
                debugMsg = debugMsg .. "DeadOwner: " .. deadOwner:Nick() .. " (HP: " .. deadOwner:Health() .. ") "
            end
            if IsValid(livingOwner) then
                debugMsg = debugMsg .. "LivingOwner: " .. livingOwner:Nick() .. " (HP: " .. livingOwner:Health() .. ") "
            end
            
            if GetConVar("developer"):GetInt() > 0 then
                print(debugMsg)
            end
            ply:ChatPrint(debugMsg)
            
            if IsValid(deadOwner) and deadOwner:IsPlayer() then
                -- This is a dead body - always show no vitals
                ply:ChatPrint("No Pulse")
                ply:ChatPrint("Not Breathing")
                ply:ChatPrint("No Reaction")
                return
            end
            
            if IsValid(livingOwner) and livingOwner:IsPlayer() then
                local owner = livingOwner
                -- FIXED: Get pulse from networked value or ragdoll
                local pulse = owner:GetNWInt("PlayerPulse", owner.pulse or 70)
                local hp = owner:Health()
                local isDead = hp <= 0
                -- FIXED: Check networked Otrub value instead of direct property
                local isUnconscious = owner:GetNWBool("Otrub", false)
                
                -- Enhanced debug info to chat and console
                local statusDebug = "[LIVING] HP: " .. hp .. ", Pulse: " .. pulse .. ", Otrub: " .. tostring(isUnconscious) .. " (networked)"
                if GetConVar("developer"):GetInt() > 0 then
                    print(statusDebug)
                end
                ply:ChatPrint(statusDebug)
                
                -- If player is dead, show no vitals
                if isDead then
                    ply:ChatPrint("No Pulse")
                    ply:ChatPrint("Not Breathing")
                    ply:ChatPrint("No Reaction")
                    return
                end
                
                -- Get organ health (default to healthy values if not set)
                local leftLungHealth = (owner.Organs and owner.Organs['left_lung']) or 5
                local rightLungHealth = (owner.Organs and owner.Organs['right_lung']) or 5
                local heartHealth = (owner.Organs and owner.Organs['heart']) or 9
                
                local organDebug = "[ORGANS] Heart: " .. heartHealth .. ", Left Lung: " .. leftLungHealth .. ", Right Lung: " .. rightLungHealth
                if GetConVar("developer"):GetInt() > 0 then
                    print(organDebug)
                end
                ply:ChatPrint(organDebug)
                
                -- Pulse status (based on heart health and pulse value)
                if heartHealth <= 0 or pulse <= 0 then
                    ply:ChatPrint("No Pulse")
                elseif pulse >= 130 then
                    ply:ChatPrint("Has High Pulse")
                elseif pulse >= 60 then
                    ply:ChatPrint("Has Normal Pulse")
                elseif pulse >= 30 and pulse < 60 then
                    ply:ChatPrint("Has Low Pulse")
                else
                    ply:ChatPrint("No Pulse")
                end
                
                -- Breathing status (based on lung health)
                if leftLungHealth <= 0 and rightLungHealth <= 0 then
                    ply:ChatPrint("Not Breathing")
                else
                    ply:ChatPrint("Breathing")
                end
                
                -- Consciousness status (based on Otrub variable) - FIXED
                local consciousnessDebug = "[CONSCIOUSNESS] Otrub value: " .. tostring(owner.Otrub) .. " (" .. type(owner.Otrub) .. "), isUnconscious: " .. tostring(isUnconscious)
                if GetConVar("developer"):GetInt() > 0 then
                    print(consciousnessDebug)
                end
                ply:ChatPrint(consciousnessDebug)
                
                -- FIXED: Use the isUnconscious variable we already calculated
                if isUnconscious then
                    ply:ChatPrint("No Reaction")
                else
                    ply:ChatPrint("Has Reaction")
                end
            else
                -- No valid owner found - treat as dead body
                ply:ChatPrint("[NO OWNER] No Pulse")
                ply:ChatPrint("[NO OWNER] Not Breathing")
                ply:ChatPrint("[NO OWNER] No Reaction")
            end
        end
    end)

    util.AddNetworkString("rads.bloodcheck")
    net.Receive("rads.bloodcheck", function(len, ply)
        local r = net.ReadEntity()
        if IsValid(r) and r:IsRagdoll() then
            net.Start("rads.bloodcheck")
            local i = r.Blood or 0
            net.WriteInt(i, 14)
            net.Send(ply)
        end
    end)

    function _P:PickupEnt()
        local ply = self
        local rag = ply:GetNWEntity("player_ragdoll")
        local phys = rag:GetPhysicsObjectNum(7)
        local offset = phys:GetAngles():Right() * 5
        local traceinfo = {
            start = phys:GetPos(),
            endpos = phys:GetPos() + offset,
            filter = rag,
            output = trace,
        }

        local trace = util.TraceLine(traceinfo)
        if trace.Entity == Entity(0) or trace.Entity == NULL or not trace.Entity.canpickup then return end
        if trace.Entity:GetClass() == "wep" then
            ply:Give(trace.Entity.curweapon, true):SetClip1(trace.Entity.Clip)
            ply.wep.Clip = trace.Entity.Clip
            trace.Entity:Remove()
        end
    end

    function _P:DropWeapon1(wep)
        local ply = self
        wep = wep or ply:GetActiveWeapon()
        if not IsValid(wep) then return end
        ply:DropWeapon(wep)
        wep.Spawned = true
        ply:SetActiveWeapon(nil)
    end

    hook.Add("PlayerSay", "dropweaponhuy", function(ply, text)
        if string.lower(text) == "#drop" or string.lower(text) == "*drop" or string.lower(text) == "!drop" then
            if not ply.fake then
                ply:DropWeapon1()
                return ""
            else
                if IsValid(ply.wep) then
                    if IsValid(ply.WepCons) then
                        ply.WepCons:Remove()
                        ply.WepCons = nil
                    end

                    if IsValid(ply.WepCons2) then
                        ply.WepCons2:Remove()
                        ply.WepCons2 = nil
                    end

                    ply.wep.canpickup = true
                    ply.wep:SetOwner()
                    ply.wep.curweapon = ply.curweapon
                    -- Preserve weapon data instead of deleting it
                    if ply.Info.Weapons[ply.Info.ActiveWeapon] then
                        ply.Info.Weapons[ply.Info.ActiveWeapon].Clip1 = ply.wep.Clip
                        -- Don't delete the weapon data, just mark it as not active
                        ply.Info.Weapons[ply.Info.ActiveWeapon].IsActive = false
                    end
                    ply:StripWeapon(ply.Info.ActiveWeapon)
                    ply.wep = nil
                    ply.Info.ActiveWeapon = nil
                    ply.Info.ActiveWeapon2 = nil
                    ply:SetActiveWeapon(nil)
                    ply.FakeShooting = false
                else
                    ply:PickupEnt()
                end
                return ""
            end
        end
    end)

    hook.Add("Think", "radsshoot", function()
        for i, ply in pairs(player.GetAll()) do
            if ply:Alive() then
                if IsValid(ply:GetNWEntity("player_ragdoll")) and ply.FakeShooting then
                    if _G.SpawnWeapon then
                        _G.SpawnWeapon(ply)
                    else
                        if GetConVar("developer"):GetInt() > 0 then
                            print("[RADS] ERROR: SpawnWeapon function not available globally at line 1772!")
                        end
                    end
                else
                    if IsValid(ply.wep) then 
			if _G.DespawnWeapon then
				_G.DespawnWeapon(ply)
			else
				if GetConVar("developer"):GetInt() > 0 then
					print("[RADS] ERROR: DespawnWeapon function not available globally!")
				end
			end
		end
                end
            end
        end
    end)

    function _P:PickupEnt()
        local ply = self
        local rag = ply:GetNWEntity("player_ragdoll")
        local phys = rag:GetPhysicsObjectNum(7)
        local offset = phys:GetAngles():Right() * 5
        local traceinfo = {
            start = phys:GetPos(),
            endpos = phys:GetPos() + offset,
            filter = rag,
            output = trace,
        }

        local trace = util.TraceLine(traceinfo)
        if trace.Entity == Entity(0) or trace.Entity == NULL or not trace.Entity.canpickup then return end
        if trace.Entity:GetClass() == "wep" then
            ply:Give(trace.Entity.curweapon, true):SetClip1(trace.Entity.Clip)
            ply.wep.Clip = trace.Entity.Clip
            trace.Entity:Remove()
        end
    end

    util.AddNetworkString("Unload")
    net.Receive("Unload", function(len, ply)
        local wep = net.ReadEntity()
        local oldclip = wep:Clip1()
        local ammo = wep:GetPrimaryAmmoType()
        wep:EmitSound("snd_jack_hmcd_ammotake.wav")
        wep:SetClip1(0)
        ply:GiveAmmo(oldclip, ammo)
    end)

    -- Network strings for inventory system
    util.AddNetworkString("RequestRagdollInventory")
    util.AddNetworkString("SendRagdollInventory")
    util.AddNetworkString("TakeWeaponFromRagdoll")
    util.AddNetworkString("TakeAllWeaponsFromRagdoll")

    -- Handle inventory request
    net.Receive("RequestRagdollInventory", function(len, ply)
        local ragdoll = net.ReadEntity()
        if not IsValid(ragdoll) or not ragdoll:IsRagdoll() then return end
        
        local owner = ragdoll:GetNWEntity("owner") or ragdoll:GetNWEntity('deadbodyowner')
        if not IsValid(owner) or not owner:IsPlayer() then return end
        
        -- Check distance
        local distance = ply:GetPos():Distance(ragdoll:GetPos())
        if distance > 100 then return end
        
        -- Get weapons from owner's saved info
        local weaponsData = {}
        if owner.Info and owner.Info.Weapons then
            for weaponClass, weaponInfo in pairs(owner.Info.Weapons) do
                local weaponTable = weapons.Get(weaponClass)
                weaponsData[weaponClass] = {
                    name = weaponTable and weaponTable.PrintName or weaponClass,
                    clip1 = weaponInfo.Clip1 or 0,
                    clip2 = weaponInfo.Clip2 or 0,
                    ammoType = weaponInfo.AmmoType or -1
                }
            end
        end
        
        -- Send inventory to client
        net.Start("SendRagdollInventory")
        net.WriteTable(weaponsData)
        net.Send(ply)
    end)

    -- Handle taking single weapon
    net.Receive("TakeWeaponFromRagdoll", function(len, ply)
        local ragdoll = net.ReadEntity()
        local weaponClass = net.ReadString()
        
        if not IsValid(ragdoll) or not ragdoll:IsRagdoll() then return end
        
        local owner = ragdoll:GetNWEntity("owner") or ragdoll:GetNWEntity('deadbodyowner')
        if not IsValid(owner) or not owner:IsPlayer() then return end
        
        -- Check distance
        local distance = ply:GetPos():Distance(ragdoll:GetPos())
        if distance > 100 then return end
        
        -- Check if weapon exists in ragdoll's inventory
        if owner.Info and owner.Info.Weapons and owner.Info.Weapons[weaponClass] then
            local weaponInfo = owner.Info.Weapons[weaponClass]
            
            -- Give weapon to player
            local weapon = ply:Give(weaponClass, true)
            if IsValid(weapon) then
                weapon:SetClip1(weaponInfo.Clip1 or 0)
                weapon:SetClip2(weaponInfo.Clip2 or 0)
                
                -- Remove from ragdoll's inventory
                owner.Info.Weapons[weaponClass] = nil
                
                ply:ChatPrint("Taken: " .. (weapons.Get(weaponClass) and weapons.Get(weaponClass).PrintName or weaponClass))
            end
        end
    end)

    -- Handle taking all weapons
    net.Receive("TakeAllWeaponsFromRagdoll", function(len, ply)
        local ragdoll = net.ReadEntity()
        
        if not IsValid(ragdoll) or not ragdoll:IsRagdoll() then return end
        
        local owner = ragdoll:GetNWEntity("owner") or ragdoll:GetNWEntity('deadbodyowner')
        if not IsValid(owner) or not owner:IsPlayer() then return end
        
        -- Check distance
        local distance = ply:GetPos():Distance(ragdoll:GetPos())
        if distance > 100 then return end
        
        local takenCount = 0
        
        -- Give all weapons to player
        if owner.Info and owner.Info.Weapons then
            for weaponClass, weaponInfo in pairs(owner.Info.Weapons) do
                local weapon = ply:Give(weaponClass, true)
                if IsValid(weapon) then
                    weapon:SetClip1(weaponInfo.Clip1 or 0)
                    weapon:SetClip2(weaponInfo.Clip2 or 0)
                    takenCount = takenCount + 1
                end
            end
            
            -- Clear ragdoll's inventory
            owner.Info.Weapons = {}
            
            if takenCount > 0 then
                ply:ChatPrint("Taken " .. takenCount .. " weapons from " .. owner:Name())
            else
                ply:ChatPrint("No weapons to take")
            end
        end
    end)

    hook.Add("KeyPress", "Shooting", function(ply, key)
        if not ply:Alive() then return end
        -- if key == IN_RELOAD then Reload(ply.wep) end -- Removed undefined Reload call
        
        -- Jump pain for broken/dislocated bones
        if key == IN_JUMP then
            local hasLegInjury = false
            local painAmount = 0
            
            -- Check for broken legs
            if ply:GetNWBool("RADS_LeftLegBroken") or ply:GetNWBool("RADS_RightLegBroken") then
                hasLegInjury = true
                painAmount = painAmount + math.random(15, 25) -- High pain for broken bones
            end
            
            -- Check for dislocated legs
            if ply:GetNWBool("RADS_LeftLegDislocated") or ply:GetNWBool("RADS_RightLegDislocated") then
                hasLegInjury = true
                painAmount = painAmount + math.random(8, 15) -- Moderate pain for dislocated bones
            end
            
            -- Check for other broken bones that would affect jumping
            if ply:GetNWBool("RADS_LeftArmBroken") or ply:GetNWBool("RADS_RightArmBroken") then
                painAmount = painAmount + math.random(3, 8) -- Minor pain for arm injuries
            end
            
            if ply.brokenspine or ply.brokenupperspine then
                painAmount = painAmount + math.random(20, 35) -- Severe pain for spine injuries
            end
            
            -- Apply realistic pain system for jumping with injuries
            if hasLegInjury or painAmount > 0 then
                local damageIntensity = painAmount
                
                -- Check for severe bone injury pain (instant pain threshold)
                if painAmount >= 20 or (ply.brokenspine or ply.brokenupperspine) then
                    -- Severe injuries: instant pain + pain debt
                    local instantPain = painAmount * 0.5 -- 50% instant for severe jumping pain
                    local painDebt = painAmount * 0.5 -- 50% debt
                    
                    ply.pain = (ply.pain or 0) + instantPain
                    ply.painDebt = (ply.painDebt or 0) + painDebt
                    ply.lastDamageTime = CurTime()
                    ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    
                    ply:ChatPrint("Jumping with your injuries causes excruciating pain!")
                elseif painAmount >= 8 then
                    -- Moderate injuries: mostly pain debt
                    local instantPain = painAmount * 0.2 -- 20% instant
                    local painDebt = painAmount * 0.8 -- 80% debt
                    
                    ply.pain = (ply.pain or 0) + instantPain
                    ply.painDebt = (ply.painDebt or 0) + painDebt
                    ply.lastDamageTime = CurTime()
                    ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    
                    ply:ChatPrint("Jumping with your injuries hurts badly.")
                else
                    -- Minor injuries: almost all pain debt
                    local instantPain = painAmount * 0.1 -- 10% instant
                    local painDebt = painAmount * 0.9 -- 90% debt
                    
                    ply.pain = (ply.pain or 0) + instantPain
                    ply.painDebt = (ply.painDebt or 0) + painDebt
                    ply.lastDamageTime = CurTime()
                    ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    
                    ply:ChatPrint("Jumping with your injuries causes some pain.")
                end
            end
        end
    end)

    local lbt = 0 -- util.AddNetworkString('RequestRagdollInfo') -- util.AddNetworkString('SendPlayerWeaponsAndAmmo') --     util.AddNetworkString('RequestRagdollInfo') --     net.Receive("RequestRagdollInfo", function(len, ply) --         local ragdoll = net.ReadEntity() --         if IsValid(ragdoll) and ragdoll:GetClass() == "prop_ragdoll" then --             owner = ragdoll:GetNWEntity("owner") --             deadbodyowner = ragdoll:GetNWEntity('deadbodyowner') --             if IsValid(owner) and owner:IsPlayer() or IsValid(deadbodyowner) and deadbodyowner:IsPlayer() then --                 local weaponsData = owner.Info and owner.Info.Weapons3 or {} --                 local ammoData = owner.Info and owner.Info.AllAmmo or {} --                 if not weaponsData or not AmmoData then --                 local weaponsData = deadbodyowner.Info and deadbodyowner.Info.AllAmmo or {} --                 end --                 net.Start("SendPlayerWeaponsAndAmmo") --                 net.WriteTable({weapons = weaponsData, ammo = ammoData}) --                 net.Send(ply) --             end --         end --     end
    util.AddNetworkString("RADS.CHATSAY")
    hook.Add('Think', "RADS.CHAT", function()
        if CurTime() - lbt >= 600 then
            net.Start('RADS.CHATSAY')
            net.Broadcast()
            lbt = CurTime()
        end
    end)

    hook.Add("PlayerUse", "nouse", function(ply, ent) if ply.fake then return false end end)
    function deathrem(victim)
        local rag = victim:GetNWEntity("player_ragdoll")
        
        -- If player dies while in ragdoll state, set to spectator mode to prevent entity appearance
        if victim.fake then
            victim:Spectate(OBS_MODE_ROAMING)
            victim:SetMoveType(MOVETYPE_OBSERVER)
        end
        
        net.Start('ADDCALC')
        net.Send(victim)
        timer.Remove('respawntimer' .. victim:EntIndex())
        if victim.IsBleeding or (victim.BloodLosing or 0) > 0 then
            rag.IsBleeding = true
            rag.bloodNext = CurTime()
            rag.Blood = victim.Blood
            RADS_Bleed(rag)
        end

        if IsValid(rag.ZacConsLH) then
            rag.ZacConsLH:Remove()
            rag.ZacConsLH = nil
        end

        if IsValid(rag.ZacConsRH) then
            rag.ZacConsRH:Remove()
            rag.ZacConsRH = nil
        end

        if not IsValid(rag) and not RADS.IsTTT() then
            victim:SetNWBool("radsfa", false)
            rag = ents.Create("prop_ragdoll")
            rag:SetModel(victim:GetModel())
            rag:SetPos(victim:GetPos())
            rag:SetAngles(victim:GetAngles())
            rag:Spawn()
            rag:Activate()
            rag:SetSkin(victim:GetSkin())
            for key, value in pairs(victim:GetBodyGroups()) do
                rag:SetBodygroup(value.id, victim:GetBodygroup(value.id))
            end

            if victim.IsBleeding or (victim.BloodLosing or 0) > 0 then
                rag.IsBleeding = true
                rag.bloodNext = CurTime()
                rag.Blood = victim.Blood
                RADS_Bleed(rag)
            end

            -- Get player color and transfer it
            local playerColor = victim:GetPlayerColor()
            if playerColor then
                rag:BetterSetPlayerColor(playerColor)
            else
                -- Simple fallback
                rag:BetterSetPlayerColor(Vector(1, 1, 1))
            end
            
            victim:SetNWEntity("player_ragdoll", rag)
            rag:SetNWEntity("owner", victim)
            RADS_RagBones(victim)
            if IsValid(rag:GetPhysicsObject()) then
                local CustomWeightt = CustomWeight[rag:GetModel()]
                rag:GetPhysicsObject():SetMass(30)
            end

            victim:SetPos(rag:GetPos())
            if RADS.IsJmodAct() then
                local armors = {}
                for id, info in pairs(victim.EZarmor.items) do
                    local ent = CreateArmor(rag, info)
                    ent.armorID = id
                    ent.ragdoll = rag
                    ent.Owner = victim
                    armors[id] = ent
                    ent:CallOnRemove("Fake", Remove, victim)
                end

                rag.armors = armors
                rag:CallOnRemove("Armors", RemoveRag)
            end

            victim:SetParent(nil)
            if not victim:IsBot() then
                local steamID = victim:SteamID()
                if victim.Info then
                    victim.Info.Hp = nil
                    victim.Info.Armor = nil
                end

                if victim.Info then
                    -- Don't clear weapons on death - preserve inventory for looting
                    -- victim.Info.Weapons2 = {}
                    -- victim.Info.Weapons = {}
                    -- victim.Info.AllAmmo = {}
                end

                savedPlayerState[steamID] = nil
                if victim:HasGodMode() then victim:GodDisable() end
            end
        end
        -- This is the correct place to apply rigor mortis, after 'rag' is guaranteed to be the active ragdoll.
        if victim.rigorMortis and IsValid(rag) then
            ApplyRigorMortis(rag)
            victim.rigorMortis = nil -- Clear the flag after applying
        end
    end

    hook.Add("DoPlayerDeath", "RADS.DeathH3", function(ply, att, dmg) deathrem(ply) end)
    hook.Add("PlayerDeath", "RADS.DeathH1", function(v, i, a)
        v:SetParent(nil)
        v:SetNWBool('brokenspine', false)
        v.pulse = 0
    end)

    hook.Add("PlayerDeath", "RADS.DeathH2", function(victim, inflictor, attacker)
        local rag = victim:GetNWEntity('player_ragdoll')
        victim:SetParent(nil)
        victim:SetNWBool('brokenspine', false)
        
        -- Check if death first-person is enabled, if not remove calcview
        if not GetConVar('rads_death_firstperson'):GetBool() then
            if GetConVar('rads_spectatorfix'):GetBool() then
                net.Start('REMOVECALC')
                net.Send(victim)
            end
        else
            -- Mark player as dead for calcview system
            victim:SetNWBool('rads_dead_firstperson', true)
        end

        victim.pulse = 0
        
        -- Clean up delayed bone pain timers to prevent pain after death
        local entIndex = victim:EntIndex()
        local limbNames = {"head", "neck", "chest", "stomach", "leftarm", "rightarm", "leftleg", "rightleg"}
        for _, limb in ipairs(limbNames) do
            timer.Remove("RADS_DelayedBonePain_" .. entIndex .. "_" .. limb)
            timer.Remove("RADS_DelayedBonePain_" .. entIndex .. "_" .. limb .. "_dislocated")
            timer.Remove("RADS_DelayedBonePain_" .. entIndex .. "_" .. limb .. "_escalation")
        end
        
        -- Clean up gore system on death
        if victim.hasGoreExplosion then
            victim.hasGoreExplosion = nil
        end
        
        if IsValid(rag) and rag.hasGoreExplosion then
            -- Stop blood stream timer
            local timerName = "RADS_BloodStream_" .. rag:EntIndex()
            if timer.Exists(timerName) then
                timer.Remove(timerName)
            end
        end
        
        -- Clean up fear system on death
        if victim.fearLevel then
            victim.fearLevel = 0
        end
        if victim.fearDecayTimer then
            timer.Remove(victim.fearDecayTimer)
            victim.fearDecayTimer = nil
        end
    end)

    concommand.Add("fake", function(ply, cmd, args)
        if ply:GetMoveType() == MOVETYPE_OBSERVER then return end
        if ply.fake then -- If already in ragdoll, try to get up
            if ply:IsRag() then if ply:GetRads().physgunned then return nil end end
            if timer.Exists("radstimer" .. ply:EntIndex()) then return nil end
            if timer.Exists("StunTime" .. ply:EntIndex()) then return nil end
            if timer.Exists("Epilepsy" .. ply:EntIndex()) then return nil end
            if ply.brokenspine or ply.brokenupperspine then return nil end
            if ply.Blood < GetConVar("rads_bloodlimit"):GetInt() then return end
            if IsValid(ply:GetNWEntity("player_ragdoll")) and ply:GetNWEntity("player_ragdoll"):GetVelocity():Length() > 300 then return nil end
            
            if table.Count(constraint.FindConstraints(ply:GetNWEntity("player_ragdoll"), 'Rope')) > 0 then
                ply:ChatPrint("You\'re tied up, Space to struggle.")
                return nil
            end
            
            -- Check if player is handcuffed
            if ply:GetNWBool("RADS_Handcuffed", false) or (IsValid(ply:GetNWEntity("player_ragdoll")) and ply:GetNWEntity("player_ragdoll"):GetNWBool("RADS_Handcuffed", false)) then
                ply:ChatPrint("You are handcuffed and cannot get up.")
                return nil
            end
            
            -- Check for conditions that prevent getting up
            if ply.Otrub then
                return nil
            end
            
            if ply.concussionActive then
                ply:ChatPrint("You are too disoriented from the concussion to get up.")
                return nil
            end
            
            -- Check for extreme shock preventing get up
            local shockLevel = ply:GetNWFloat("RADS_Shock", 0)
            if shockLevel >= 75 then
                ply:ChatPrint("You are in too much shock to even attempt getting up.")
                return nil
            end
            
            -- Check if player is fully submerged in water (prevent getting up)
            local ragdoll = ply:GetNWEntity("player_ragdoll")
            if IsValid(ragdoll) then
                local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
                if headBone then
                    local headPos = ragdoll:GetBonePosition(headBone)
                    local waterLevel = util.PointContents(headPos)
                    local isUnderwater = bit.band(waterLevel, CONTENTS_WATER) ~= 0
                    
                    if isUnderwater then
                        ply:ChatPrint("You cannot get up while fully submerged in water.")
                        return nil
                    end
                end
            end

            -- Check if instant get up is enabled
            if GetConVar("rads_instant_getup"):GetBool() then
                -- Instant get up - bypass the get up process but respect all blocking conditions
                rads(ply)
                return
            end

            ply.gettingUp = true
            ply.lastGetUpAttempt = CurTime()
            ply:ChatPrint("Attempting to get up...")
        else -- If not in ragdoll, ragdoll the player
            rads(ply, true) -- Pass true to indicate this is manual
            if not RADS.IsTTT() and not ply.fake then timer.Create("radstimer" .. ply:EntIndex(), 1.5, 1, function() end) end
        end
    end)

    hook.Add("PlayerDisconnected", "removeallwhenleave", function(ply)
        local steamID = ply:SteamID()
        savedPlayerState[steamID] = nil
        if ply.Info then
            ply.Info.Hp = nil
            ply.Info.Armor = nil
            ply.Info = nil
        end

        if savedPlayerState[steamID] then savedPlayerState[steamID] = nil end
        local exr = ply:GetNWEntity("player_ragdoll")
        if IsValid(exr) then
            -- Clean up bullseye entity when player disconnects
            if IsValid(exr.bullseye) then
                print("[BULLSEYE DEBUG] Cleaning up bullseye entity for disconnected player: " .. ply:Name())
                exr.bullseye:Remove()
                exr.bullseye = nil
            end
            
            -- Clean up gore system when player disconnects
            if exr.hasGoreExplosion then
                -- Remove gore stump
                if IsValid(exr.goreStump) then
                    exr.goreStump:Remove()
                    exr.goreStump = nil
                end
                
                -- Stop blood stream timer
                local timerName = "RADS_BloodStream_" .. exr:EntIndex()
                if timer.Exists(timerName) then
                    timer.Remove(timerName)
                end
                
                exr.hasGoreExplosion = nil
            end
            
            ply:SetNWEntity("player_ragdoll", nil)
            exr:SetNWEntity('owner', nil)
            exr:SetNWEntity("RagdollController", nil)
        end
        
        -- Clean up player gore state
        if ply.hasGoreExplosion then
            ply.hasGoreExplosion = nil
        end
    end)

    hook.Add("OnPlayerHitGround", "GovnoJopa", function(ply, a, b, speed)
        if speed > 200 then
            local tr = {}
            tr.start = ply:GetPos()
            tr.endpos = ply:GetPos() - Vector(0, 0, 10)
            tr.mins = ply:OBBMins()
            tr.maxs = ply:OBBMaxs()
            tr.filter = ply
            local traceResult = util.TraceHull(tr)
            if traceResult.Entity:IsPlayer() and not traceResult.Entity.fake then rads(traceResult.Entity) end
        end
    end)



    hook.Add("Think", "RemoveRagdoll", function()
        for _, ply in ipairs(player.GetAll()) do -- end
            local ragdoll_entity = ply:GetRagdollEntity()
            if IsValid(ragdoll_entity) then ragdoll_entity:Remove() end
        end
    end)

    function propknocked(ply)
        if timer.Exists("propknocked" .. ply:UserID()) then
            return true
        else
            timer.Create("propknocked" .. ply:UserID(), 1, 1, function() end)
            return false
        end
    end

    hook.Add("EntityTakeDamage", "fallfromclub", function(target, dmginfo)
        local random = math.Rand(1, 2)
        if target:IsPlayer() and GetConVar('rads_fallonclub'):GetBool() and dmginfo:IsDamageType(DMG_CLUB) and not target.fake then
            -- Make club damage more reasonable - only 10% chance instead of guaranteed
            if GetConVar('rads_randomfallfromclub'):GetBool() then 
                if random > 1.9 then rads(target) end 
            else
                -- Instead of always ragdolling, add damage threshold and chance
                if dmginfo:GetDamage() >= 25 and math.random() < 0.1 then -- 10% chance for significant club damage
                    rads(target)
                end
            end
        end
    end)

    hook.Add("EntityTakeDamage", "fallondamage", function(target, dmginfo)
        if target:IsPlayer() then -- ply.pain = ply.pain + 5
            if GetConVar('rads_fallchance'):GetBool() and not target.fake then
                -- Add damage threshold to prevent ragdolling from minor damage
                local damage = dmginfo:GetDamage()
                if damage >= 15 then -- Increased threshold from 10 to 15
                    local damagePosition = dmginfo:GetDamagePosition()
                    local bodyPart = target:LastHitGroup(damagePosition)
                    
                    -- Initialize pain and consciousness if not set
                    target.pain = target.pain or 0
                    
                    -- Check for knockdown protection (1 second after getting up)
                    if target.lastGetUpTime and CurTime() - target.lastGetUpTime < 1.0 then
                        return -- Player has knockdown protection
                    end
                    
                    -- Use the improved shouldFall function for base calculation
                    local shouldRagdoll = shouldFall(bodyPart, damage, dmginfo:GetDamageType(), target)
                    
                    if not shouldRagdoll then
                        -- Additional chance modifiers for special conditions
                        local extraChance = 0
                    
                        -- Pain-based modifier: Higher pain increases knockdown chance
                        if target.pain and target.pain > 100 then
                            extraChance = extraChance + 0.20 -- 20% extra for very high pain
                        elseif target.pain and target.pain > 50 then
                            extraChance = extraChance + 0.10 -- 10% extra for high pain
                        end
                        
                        -- Consciousness-based modifier: Unconscious players more likely to be knocked down
                        if target.Otrub then -- Player is unconscious
                            extraChance = extraChance + 0.30 -- 30% extra when unconscious
                        end
                        
                        -- Rapid hit tracking for shotguns (preserved from original system)
                        if dmginfo:IsDamageType(DMG_BUCKSHOT) then
                            local steamID = target:SteamID()
                            local currentTime = CurTime()
                            
                            -- Initialize hit tracking for this player if not exists
                            if not playerHitTracking[steamID] then
                                playerHitTracking[steamID] = {
                                    hits = {},
                                    lastCleanup = currentTime
                                }
                            end
                            
                            local hitData = playerHitTracking[steamID]
                            
                            -- Add current hit
                            table.insert(hitData.hits, currentTime)
                            
                            -- Count hits within the rapid hit window
                            local recentHits = 0
                            for _, hitTime in ipairs(hitData.hits) do
                                if currentTime - hitTime <= RAPID_HIT_WINDOW then
                                    recentHits = recentHits + 1
                                end
                            end
                            
                            -- Apply rapid hit bonus based on hit count
                            if recentHits >= 4 then
                                extraChance = extraChance + 0.40 -- 40% extra for 4+ rapid hits
                            elseif recentHits >= 3 then
                                extraChance = extraChance + 0.25 -- 25% extra for 3+ rapid hits
                            elseif recentHits >= 2 then
                                extraChance = extraChance + 0.15 -- 15% extra for 2+ rapid hits
                            end
                        end
                        
                        -- Apply extra chance if any modifiers are present
                        if extraChance > 0 then
                            shouldRagdoll = math.random() < extraChance
                        end
                    end
                    
                    -- Execute ragdoll if shouldRagdoll is true
                    if shouldRagdoll then 
                        rads(target) 
                    end
                end
            end
        end
    end)

    hook.Add("EntityTakeDamage", "stundmg", function(target, dmginfo)
        if IsValid(target) and not target.fake then -- target.pain = target.pain + 7
            if IsValid(dmginfo:GetAttacker()) then
                local attacker = dmginfo:GetAttacker()
                local inflictor = dmginfo:GetInflictor()
                if IsValid(attacker) and IsValid(inflictor) then if attacker:IsPlayer() and attacker:GetActiveWeapon() and attacker:GetActiveWeapon():IsValid() then if attacker:GetActiveWeapon():GetClass() == "weapon_stunstick" then Stun(target) end end end
            end
        end
    end)

    -- Removed duplicate damage interruption hook
    -- hook.Add("EntityTakeDamage", "RADS.RagdollDamageInterrupt", function(target, dmginfo)
    --     local owner = nil
    --     if IsValid(target) and target:IsRagdoll() then
    --         owner = target:GetNWEntity("owner") or target:GetNWEntity('deadbodyowner')
    --     elseif IsValid(target) and target:IsPlayer() then
    --         owner = target
    --     end
    -- 
    --     if IsValid(owner) and owner:IsPlayer() and owner:GetNWBool("radsfa") then
    --         owner.takingDamage = true
    --     end
    -- end)

    function Seizure(ent) -- target.pain = target.pain + 20
        if ent:IsRagdoll() then
            local seizuret = math.random(1, 6)
            local iterrr = seizuret * 10
            RagdollOwner(ent):ChatPrint("Cramps")
            timer.Create("seizuret_" .. ent:EntIndex(), seizuret, 1, function() end)
            timer.Create("seizuret_" .. ent:EntIndex(), 0.1, iterrr, function() ent:GetPhysicsObjectNum(1):SetVelocity(ent:GetPhysicsObjectNum(1):GetVelocity() + Vector(math.random(-45, 45), math.random(-45, 45), 0)) end)
        end
    end

    function Stun(Entity)
        if Entity:IsPlayer() then
            rads(Entity)
            local stuntime = math.random(1, 15)
            local iter = stuntime * 10
            timer.Create("StunTime" .. Entity:EntIndex(), stuntime, 1, function() end)
            local radsrag = Entity:GetNWEntity("player_ragdoll")
            if not IsValid(radsrag) then return end
            timer.Create("StunEffect" .. Entity:EntIndex(), 0.1, iter, function()
                local rand = math.random(1, 2)
                if rand == 2 then end
                radsrag:GetPhysicsObjectNum(1):SetVelocity(radsrag:GetPhysicsObjectNum(1):GetVelocity() + Vector(math.random(-85, 85), math.random(-85, 85), 0)) -- Entity:Say('#drop')
                radsrag:EmitSound("ambient/energy/spark2.wav")
            end)
        end
    end

    function RADS_Epilepsy(Entity)
        if Entity:IsPlayer() then
            local rag = Entity:GetNWEntity('player_ragdoll')
            if IsValid(rag) then return end
            rads(Entity)
            local mineptime, maxeptime = GetConVar('rads_mineptime'):GetInt(), GetConVar('rads_maxeptime'):GetInt()
            local eptime = math.random(mineptime, maxeptime)
            local iterr = eptime * 10
            timer.Create("Epilepsy" .. Entity:EntIndex(), eptime, 1, function() end)
            local radsrag = Entity:GetNWEntity("player_ragdoll")
            if not IsValid(radsrag) then return end
            timer.Create("EpilepsyM" .. Entity:EntIndex(), 0.1, iterr, function()
                local rand = math.random(1, 2)
                if rand == 2 then end
                radsrag:GetPhysicsObjectNum(1):SetVelocity(radsrag:GetPhysicsObjectNum(1):GetVelocity() + Vector(math.random(-125, 125), math.random(-125, 125), 0)) -- Entity:Say('#drop')
            end)

            radsrag:EmitSound("lol.wav")
        end
    end

    concommand.Add('rads_epil', function(ply) RADS_Epilepsy(ply) end)
    function RADS_RagdollCollision(ragdoll, collisionData)
        if GetConVar('rads_doorbreach'):GetBool() then
            local collidedEntity = collisionData.HitEntity
            if IsValid(collidedEntity) and (collidedEntity:GetClass() == "prop_door_rotating" or collidedEntity:GetClass() == "func_door") then
                local ragdollVelocity = collisionData.OurOldVelocity:Length()
                if ragdollVelocity >= 450 then BreachDoor(ragdoll, collidedEntity, collisionData) end
            end
        end
    end

    hook.Add("PlayerInitialSpawn", "rads-knocked-callback", function(ply)
        ply:AddCallback("PhysicsCollide", function(phys, data) hook.Run("Player Collide", ply, data.HitEntity, data) end)
        net.Start("RADS.CHATSAY")
        net.Send(ply)
    end)

    hook.Add("Player Collide", "rads-knocked", function(ply, hitEnt, data)
        if GetConVar('rads_propknock'):GetBool() and not ply:HasGodMode() and data.Speed > 8000 or not GetConVar('rads_propknock'):GetBool() and not ply:HasGodMode() and data.Speed >= math.max(5000, 8000 / hitEnt:GetPhysicsObject():GetMass() * 20) and not ply.fake and hitEnt:IsPlayerHolding() and hitEnt:GetVelocity():Length() > 1500 then
            timer.Simple(0, function()
                if not IsValid(ply) or ply.fake then return end
                if hook.Run("Should Fake Collide", ply, hitEnt, data) == false then return end
                rads(ply)
                RADS.PainSound(ply)
            end)
        end
    end)
    
    -- Enhanced Player Collide hook based on reference addon
    hook.Add("Player Collide", "homigrad-fake", function(ply, hitEnt, data)
        if not ply:HasGodMode() and not ply.fake then
            local speed = data.Speed
            local threshold = 6000
            
            -- Calculate speed threshold based on entity mass if it has physics
            -- Use much higher base values and ensure minimum threshold
            if IsValid(hitEnt) and IsValid(hitEnt:GetPhysicsObject()) then
                threshold = math.max(5000, 8000 / hitEnt:GetPhysicsObject():GetMass() * 20)
            end
            
            -- Additional check: only ragdoll if the entity is moving fast or player is moving very fast
            local entityVelocity = IsValid(hitEnt) and hitEnt:GetVelocity():Length() or 0
            local shouldRagdoll = speed > threshold and (entityVelocity > 200 or speed > threshold * 1.5)
            
            if shouldRagdoll then
                timer.Simple(0, function()
                    if IsValid(ply) and not ply.fake then
                        rads(ply)
                    end
                end)
            end
        end
    end)

    util.AddNetworkString('nodraw_helmet')
    function CreateArmor(ragdoll, info)
        local item = JMod.ArmorTable[info.name]
        if not item then return end
        local Index = ragdoll:LookupBone(item.bon)
        if not Index then return end
        local Pos, Ang = (ply or ragdoll):GetBonePosition(Index)
        if not Pos then return end
        local ent = ents.Create(item.ent)
        local Right, Forward, Up = Ang:Right(), Ang:Forward(), Ang:Up()
        Pos = Pos + Right * item.pos.x + Forward * item.pos.y + Up * item.pos.z
        Ang:RotateAroundAxis(Right, item.ang.p)
        Ang:RotateAroundAxis(Up, item.ang.y)
        Ang:RotateAroundAxis(Forward, item.ang.r)
        ent.IsArmor = true
        ent:SetPos(Pos)
        ent:SetAngles(Ang)
        local color = info.col
        ent:SetColor(Color(color.r, color.g, color.b, color.a))
        ent:Spawn() -- timer.Simple(.1,function()
        ent:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE) -- ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        if IsValid(ent:GetPhysicsObject()) then
            ent:GetPhysicsObject():SetMaterial("Armorflesh")
            ent:GetPhysicsObject():SetMass(1)
            ent:GetPhysicsObject():EnableCollisions(false)
        end

        timer.Simple(0.1, function()
            local ply = RagdollOwner(ragdoll) -- end)
            if item.bon == "ValveBiped.Bip01_Head1" and ply and IsValid(ply) and ply:IsPlayer() then
                net.Start("nodraw_helmet")
                net.WriteEntity(ent)
                net.Send(ply)
            end
        end)

        constraint.Weld(ent, ragdoll, 0, ragdoll:TranslateBoneToPhysBone(Index), 0, true, false)
        ragdoll:DeleteOnRemove(ent)
        return ent
    end

    local function Remove(self, ply)
        if self.override then return end
        self.ragdoll.armors[self.armorID] = nil
        JMod.RemoveArmorByID(ply, self.armorID, true)
    end

    -- RemoveRag function moved earlier in the file

    hook.Add("OnEntityCreated", "ragdoor", function(ent) if IsValid(ent) and ent:IsRagdoll() and GetConVar('rads_doorbreach'):GetBool() then ent:AddCallback("PhysicsCollide", function(ragdoll, collisionData) RADS_RagdollCollision(ragdoll, collisionData) end) end end)
    
    -- Ragdoll tackling system based on reference addon
    hook.Add('Think', 'RADS_RagdollTackleCheck', function()
        for _, ragdoll in pairs(ents.FindByClass('prop_ragdoll')) do
            if IsValid(ragdoll) then
                local velocity = ragdoll:GetVelocity():Length()
                
                if velocity > 200 then
                    ragdoll:SetCollisionGroup(COLLISION_GROUP_NONE)
                    
                    -- Trace ahead of the ragdoll to detect potential player collisions
                    local traceData = {
                        start = ragdoll:GetPos(),
                        endpos = ragdoll:GetPos() + ragdoll:GetVelocity():GetNormalized() * 40,
                        filter = ragdoll
                    }
                    local trace = util.TraceLine(traceData)
                    
                    if IsValid(trace.Entity) and trace.Entity:IsPlayer() then
                        local ragdollOwner = ragdoll:GetNWEntity("owner")
                        if IsValid(ragdollOwner) and ragdollOwner ~= trace.Entity and not trace.Entity.fake then
                            -- Trigger tackling on the hit player
                            rads(trace.Entity)
                        end
                    end
                else
                    ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
                end
            end
        end
    end)
    function BreachDoor(ragdoll, door, collisionData)
        if GetConVar('rads_doorbreach'):GetBool() then
            local ragdollVelocity = collisionData.OurOldVelocity:GetNormalized()
            local breachedDoor = ents.Create("prop_physics")
            breachedDoor:SetModel(door:GetModel())
            breachedDoor:SetSkin(door:GetSkin())
            for key, value in pairs(door:GetBodyGroups()) do
                breachedDoor:SetBodygroup(value.id, door:GetBodygroup(value.id))
            end

            breachedDoor:SetPos(door:GetPos())
            breachedDoor:SetAngles(door:GetAngles())
            door:Remove()
            breachedDoor:Spawn()
            local phys = breachedDoor:GetPhysicsObject()
            if IsValid(phys) then
                local force = ragdollVelocity * phys:GetMass()
                phys:ApplyForceCenter(force, collisionData.HitPos)
            end
        end
    end

    concommand.Add("rads_god", function(ply, cmd, args)
        if IsValid(ply) and ply:IsSuperAdmin() then
            if ply:HasGodMode() then
                ply:GodDisable()
                ply:PrintMessage(HUD_PRINTTALK, "God disabled.")
            else
                ply:GodEnable()
                ply:EmitSound("restains.wav", 150, 200, 1, CHAN_ITEM)
                ply:PrintMessage(HUD_PRINTTALK, "God enabled.")
            end
        end
    end)



    -- Initialize cumulative damage tracking tables
    if not RADS_CumulativeDamage then
        RADS_CumulativeDamage = {}
    end
    
    -- Function to clean up old damage entries
    local function RADS_CleanupOldDamage()
        local currentTime = CurTime()
        for targetID, data in pairs(RADS_CumulativeDamage) do
            if currentTime - data.lastHit > 0.5 then
                RADS_CumulativeDamage[targetID] = nil
            end
        end
    end
    
    -- Gore System: Head Explosion on Extreme Damage
    hook.Add("EntityTakeDamage", "RADS_GoreSystem", function(target, dmginfo)
        -- Check if gore system is enabled
        if not GetConVar('rads_gore_enable'):GetBool() then return end
        
        local damage = dmginfo:GetDamage()
        local baseDamageThreshold = GetConVar('rads_gore_head_damage_threshold'):GetFloat()
        
        -- Apply damage type multipliers
        local damageThreshold = baseDamageThreshold
        local damageType = dmginfo:GetDamageType()
        
        -- Explicitly exclude fall and crush damage from triggering head explosions
        if bit.band(damageType, DMG_FALL) > 0 or bit.band(damageType, DMG_CRUSH) > 0 or dmginfo:IsFallDamage() then
            return -- Fall and crush damage should not cause head explosions
        end
        
        local isBuckshot = bit.band(damageType, DMG_BUCKSHOT) > 0
        
        if bit.band(damageType, DMG_CLUB) > 0 then
            damageThreshold = baseDamageThreshold * 2 -- DMG_CLUB needs 2x damage
        elseif bit.band(damageType, DMG_BULLET) > 0 then
            damageThreshold = baseDamageThreshold * 1.0 -- DMG_BULLET uses base threshold
        elseif isBuckshot then
            damageThreshold = baseDamageThreshold * 1.0 -- DMG_BUCKSHOT uses base threshold
        else
            -- Other damage types don't trigger head explosions (including DMG_BLAST)
            return
        end
        
        -- Handle cumulative damage for buckshot and bullet (shotgun pellets and bullets)
        local finalDamage = damage
        local isBulletOrBuckshot = bit.band(damageType, DMG_BULLET) > 0 or isBuckshot
        if isBulletOrBuckshot then
            -- Clean up old damage entries periodically
            RADS_CleanupOldDamage()
            
            local targetID = target:EntIndex()
            local currentTime = CurTime()
            
            -- Initialize or update cumulative damage for this target
            if not RADS_CumulativeDamage[targetID] then
                RADS_CumulativeDamage[targetID] = {
                    totalDamage = 0,
                    lastHit = currentTime
                }
            end
            
            local damageData = RADS_CumulativeDamage[targetID]
            
            -- Check if this hit is within the 0.5 second window
            if currentTime - damageData.lastHit <= 0.5 then
                -- Add to cumulative damage
                damageData.totalDamage = damageData.totalDamage + damage
                damageData.lastHit = currentTime
                finalDamage = damageData.totalDamage
            else
                -- Reset cumulative damage (new damage window)
                damageData.totalDamage = damage
                damageData.lastHit = currentTime
                finalDamage = damage
            end
        end
        
        -- Check if target is valid and damage is above threshold
        if not IsValid(target) or finalDamage < damageThreshold then return end
        
        local isPlayer = target:IsPlayer()
        local isRagdoll = target:IsRagdoll()
        
        -- Completely disable head explosions for ragdolls
        if isRagdoll then return end
        
        -- Only process players (ragdolls are now excluded)
        if not isPlayer then return end
        
        -- Check if head already exploded to prevent multiple explosions
        if target.headExploded then return end
        
        -- For players, check if damage is to the head
        local damagePosition = dmginfo:GetDamagePosition()
        local bodyPart = target:LastHitGroup(damagePosition)
        
        if bodyPart == HITGROUP_HEAD and not target.fake then
            -- Mark head as exploded to prevent multiple explosions
            target.headExploded = true
            
            -- Trigger head explosion
            RADS_TriggerHeadExplosion(target, dmginfo)
            
            -- Force instant death
            target:Kill()
            target:SetHealth(0)
        end
    end)

    hook.Add("EntityTakeDamage", "falldamage", function(target, dmginfo)
        if GetConVar('rads_ragonfall'):GetBool() then
            if target:IsPlayer() and dmginfo:IsFallDamage() and not target.fake then
                -- Increased threshold from 8 to 25 for more realistic ragdolling
                if dmginfo:GetDamage() > 25 then
                    target:EmitSound("NPC_Barnacle.BreakNeck", 511, 200, 1, CHAN_ITEM)
                    rads(target)
                    
                    -- NEW: Trigger adrenaline based on fall damage severity
                    if SERVER then
                        local fallDamage = dmginfo:GetDamage()
                        local adrenalineGain = 0
                        
                        -- More reasonable thresholds
                        if fallDamage >= 50 then
                            adrenalineGain = 35 -- Severe fall (was 50)
                            RADS_TriggerSevereFallEffects(target, fallDamage)
                            -- Trigger internal bleeding for extreme fall damage
                            RADS_TriggerInternalBleeding(target, "fall", fallDamage)
                        elseif fallDamage >= 40 then
                            adrenalineGain = 15 -- Medium fall damage (was 15)
                            RADS_TriggerLightFallEffects(target, fallDamage)
                        elseif fallDamage >= 35 then
                            adrenalineGain = 25 -- High fall damage (was 30)
                            RADS_TriggerModerateFallEffects(target, fallDamage)
                            -- Trigger internal bleeding for severe fall damage
                            RADS_TriggerInternalBleeding(target, "fall", fallDamage)
                        elseif fallDamage >= 25 then
                            adrenalineGain = 10 -- Light fall damage (was 8)
                        end
                        
                        if adrenalineGain > 0 then
                            UpdateAdrenaline(target, adrenalineGain)
                            if GetConVar("developer"):GetInt() > 0 then
                                print("[FALL DAMAGE] Triggered adrenaline for " .. target:Name() .. " with gain: " .. adrenalineGain)
                            end
                        end
                    end
                end
            end
        end
    end)

    -- NEW: Fall damage effect functions
    if SERVER then
        -- Network strings for fall effects

        
        function RADS_TriggerSevereFallEffects(ply, damage)
            if not IsValid(ply) or not ply:IsPlayer() then return end
            
            -- Add significant pain
            ply.pain = (ply.pain or 0) + math.min(damage * 2, 80)
            
            -- Severe speed reduction for 15-25 seconds
            local duration = math.Rand(15, 25)
            ply.fallSpeedDebuff = true
            ply:SetWalkSpeed(20) -- Very slow
            ply:SetRunSpeed(35)
            
            -- Timer to restore speed
            timer.Create("RADS_FallSpeedRestore_" .. ply:UserID(), duration, 1, function()
                if IsValid(ply) and ply:IsPlayer() then
                    ply.fallSpeedDebuff = false
                    -- Restore normal speed (check if other debuffs are active)
                    if not (ply:GetNWBool("RADS_LeftLegDislocated") or ply:GetNWBool("RADS_RightLegDislocated") or 
                           ply:GetNWBool("RADS_LeftLegBroken") or ply:GetNWBool("RADS_RightLegBroken")) then
                        ply:SetWalkSpeed(160)
                        ply:SetRunSpeed(250)
                    end
                end
            end)
        end
        
        function RADS_TriggerModerateFallEffects(ply, damage)
            if not IsValid(ply) or not ply:IsPlayer() then return end
            
            -- Add moderate pain
            ply.pain = (ply.pain or 0) + math.min(damage * 1, 50)
            
            -- Moderate speed reduction for 8-15 seconds
            local duration = math.Rand(8, 15)
            ply.fallSpeedDebuff = true
            ply:SetWalkSpeed(40)
            ply:SetRunSpeed(70)
            
            -- Timer to restore speed
            timer.Create("RADS_FallSpeedRestore_" .. ply:UserID(), duration, 1, function()
                if IsValid(ply) and ply:IsPlayer() then
                    ply.fallSpeedDebuff = false
                    if not (ply:GetNWBool("RADS_LeftLegDislocated") or ply:GetNWBool("RADS_RightLegDislocated") or 
                           ply:GetNWBool("RADS_LeftLegBroken") or ply:GetNWBool("RADS_RightLegBroken")) then
                        ply:SetWalkSpeed(160)
                        ply:SetRunSpeed(250)
                    end
                end
            end)
        end
        
        function RADS_TriggerLightFallEffects(ply, damage)
            if not IsValid(ply) or not ply:IsPlayer() then return end
            
            -- Add light pain
            ply.pain = (ply.pain or 0) + math.min(damage * 0.6, 30)
            
            -- Light speed reduction for 5-10 seconds
            local duration = math.Rand(5, 10)
            ply.fallSpeedDebuff = true
            ply:SetWalkSpeed(80)
            ply:SetRunSpeed(120)
            
            -- Timer to restore speed
            timer.Create("RADS_FallSpeedRestore_" .. ply:UserID(), duration, 1, function()
                if IsValid(ply) and ply:IsPlayer() then
                    ply.fallSpeedDebuff = false
                    if not (ply:GetNWBool("RADS_LeftLegDislocated") or ply:GetNWBool("RADS_RightLegDislocated") or 
                           ply:GetNWBool("RADS_LeftLegBroken") or ply:GetNWBool("RADS_RightLegBroken")) then
                        ply:SetWalkSpeed(160)
                        ply:SetRunSpeed(250)
                    end
                end
            end)
        end
        
        -- Gore System: Head Explosion Function
        function RADS_TriggerHeadExplosion(target, dmginfo)
            if not IsValid(target) then return end
            
            local isPlayer = target:IsPlayer()
            
            -- COMPLETELY DISABLE HEAD EXPLOSIONS FOR RAGDOLLS
            if not isPlayer then
                return -- Block all ragdoll head explosions
            end
            
            local ragdoll = nil
            
            -- Ensure instant death for players
            if isPlayer then
                -- Destroy brain organ to cause instant death
                target.Organs = target.Organs or {
                    ["brain"] = 1,
                    ["heart"] = 1,
                    ["lungs"] = 1,
                    ["liver"] = 1,
                    ["stomach"] = 1,
                    ["intestines"] = 1,
                    ["spine"] = 1
                }
                target.Organs["brain"] = 0
                
                -- Set consciousness to 0 for instant unconsciousness
                if target.consciousness then
                    target.consciousness = 0
                    target:SetNWInt("PlayerConsciousness", 0)
                    target.Otrub = true
                    target:SetNWBool("Otrub", true)
                    target.consciousnessBasedUnconscious = false
                end
                
                -- Force instant death
                target:Kill()
                target:SetHealth(0)
            end
            
            -- Get or create ragdoll
            if isPlayer then
                -- If player, get their ragdoll (create one if needed)
                ragdoll = target:GetNWEntity('player_ragdoll')
                if not IsValid(ragdoll) then
                    -- Player doesn't have ragdoll yet, create one
                    rads(target)
                    timer.Simple(0.1, function()
                        if IsValid(target) then
                            ragdoll = target:GetNWEntity('player_ragdoll')
                            if IsValid(ragdoll) then
                                RADS_ProcessHeadExplosion(ragdoll, dmginfo)
                            end
                        end
                    end)
                    return
                end
            else
                -- Target is already a ragdoll
                ragdoll = target
            end
            
            if IsValid(ragdoll) then
                RADS_ProcessHeadExplosion(ragdoll, dmginfo)
            end
        end
        
        function RADS_ProcessHeadExplosion(ragdoll, dmginfo)
            if not IsValid(ragdoll) then return end
            
            -- Prevent multiple explosions on same ragdoll
            if ragdoll.headExploded then return end
            ragdoll.headExploded = true
            
            -- Find head bone
            local headBone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
            if not headBone then return end
            
            local headPos, headAng = ragdoll:GetBonePosition(headBone)
            if not headPos then return end
            
            -- Mark head as exploded for gore system (prevents conflicts with other head hiding code)
            ragdoll.goreHeadExploded = true
            
            -- Hide the head bone by scaling it to 0
            ragdoll:ManipulateBoneScale(headBone, Vector(0, 0, 0))
            
            -- Find neck bone for stump placement
            local neckBone = ragdoll:LookupBone("ValveBiped.Bip01_Neck1")
            local stumpPos = headPos
            local stumpAng = headAng
            
            -- ADJUSTABLE STUMP POSITIONING VARIABLES (modify these to adjust stump placement)
            local STUMP_OFFSET_FORWARD = 7.45    -- Forward/backward offset from neck bone
            local STUMP_OFFSET_RIGHT = 3     -- Left/right offset from neck bone
            local STUMP_OFFSET_UP = -0.7         -- Up/down offset from neck bone (positive = up)
            local STUMP_ANGLE_PITCH = -253       -- Pitch angle adjustment (positive = nose down)
            local STUMP_ANGLE_YAW = 0       -- Yaw angle adjustment (positive = turn right)
            local STUMP_ANGLE_ROLL = 75         -- Roll angle adjustment (positive = roll right)
            
            -- Always use neck bone for positioning if available, with improved fallback
            if neckBone then
                stumpPos, stumpAng = ragdoll:GetBonePosition(neckBone)
                
                -- Apply adjustable positioning offsets
                local forward = stumpAng:Forward() * STUMP_OFFSET_FORWARD
                local right = stumpAng:Right() * STUMP_OFFSET_RIGHT
                local up = stumpAng:Up() * STUMP_OFFSET_UP
                
                stumpPos = stumpPos + forward + right + up
                
                -- Apply adjustable angle offsets
                stumpAng = stumpAng + Angle(STUMP_ANGLE_PITCH, STUMP_ANGLE_YAW, STUMP_ANGLE_ROLL)
            else
                -- Fallback: Use head position but adjust for better stump placement
                -- Move the stump slightly down from head position to simulate neck cut
                stumpPos = headPos + Vector(0, 0, -8) -- Move down 8 units from head
                
                -- Try to get a more appropriate angle for the stump
                -- Use the ragdoll's root bone angle as reference if available
                local spineBone = ragdoll:LookupBone("ValveBiped.Bip01_Spine4") or ragdoll:LookupBone("ValveBiped.Bip01_Spine3") or ragdoll:LookupBone("ValveBiped.Bip01_Spine2")
                if spineBone then
                    local _, spineAng = ragdoll:GetBonePosition(spineBone)
                    if spineAng then
                        stumpAng = spineAng + Angle(STUMP_ANGLE_PITCH, STUMP_ANGLE_YAW, STUMP_ANGLE_ROLL)
                    end
                else
                    -- Last resort: use head angle with adjustments
                    stumpAng = headAng + Angle(STUMP_ANGLE_PITCH, STUMP_ANGLE_YAW, STUMP_ANGLE_ROLL)
                end
            end
            
            -- Create gore stump model
            local stump = ents.Create("prop_physics")
            if IsValid(stump) then
                stump:SetModel("models/mosi/fnv/props/character/headcap.mdl")
                stump:SetPos(stumpPos)
                stump:SetAngles(stumpAng)
                stump:Spawn()
                
                -- Make stump non-collidable and attach to ragdoll
                stump:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
                if IsValid(stump:GetPhysicsObject()) then
                    stump:GetPhysicsObject():SetMass(1)
                    stump:GetPhysicsObject():EnableCollisions(false)
                end
                
                -- Weld stump to neck bone
                if neckBone then
                    local neckPhysBone = ragdoll:TranslateBoneToPhysBone(neckBone)
                    if neckPhysBone >= 0 then
                        constraint.Weld(stump, ragdoll, 0, neckPhysBone, 0, true, false)
                    end
                end
                
                -- Clean up stump when ragdoll is removed
                ragdoll:DeleteOnRemove(stump)
                
                -- Store stump reference for blood effects
                ragdoll.goreStump = stump
            end
            
            -- Play explosion sound with random pitch
            local pitch = math.random(95, 115)
            ragdoll:EmitSound("head_explodie_01.mp3", 75, pitch, 1, CHAN_AUTO)
            
            -- Create initial blood explosion effect
            RADS_CreateBloodExplosion(ragdoll, headPos)
            
            -- Start continuous blood stream from stump
            RADS_StartBloodStream(ragdoll, stumpPos)
        end
        
        function RADS_CreateBloodExplosion(ragdoll, position)
            if not IsValid(ragdoll) or not position then return end
            
            -- Create dramatic arterial blood spurts in all directions
            for i = 1, 15 do
                local direction = VectorRand():GetNormalized()
                direction.z = math.abs(direction.z) * 0.8 -- Bias upward for arterial spurting
                
                -- Create high-pressure arterial blood spurts
                local effectdata = EffectData()
                effectdata:SetOrigin(position + VectorRand() * 3)
                effectdata:SetNormal(direction)
                effectdata:SetMagnitude(math.random(80, 150)) -- Increased magnitude for arterial spurting
                effectdata:SetScale(math.random(3, 6)) -- Larger scale for dramatic effect
                util.Effect("BloodImpact", effectdata)
                
                -- Add secondary smaller spurts for realism
                if math.random(1, 3) == 1 then
                    local secondaryDir = (direction + VectorRand() * 0.3):GetNormalized()
                    local secondaryEffect = EffectData()
                    secondaryEffect:SetOrigin(position + direction * math.random(10, 25))
                    secondaryEffect:SetNormal(secondaryDir)
                    secondaryEffect:SetMagnitude(math.random(40, 80))
                    secondaryEffect:SetScale(math.random(1, 3))
                    util.Effect("BloodImpact", secondaryEffect)
                end
            end
            
            -- Create extensive blood decals around the explosion
            for i = 1, 12 do
                local traceDir = VectorRand():GetNormalized()
                local trace = util.TraceLine({
                    start = position,
                    endpos = position + traceDir * 200, -- Increased range for arterial spurting
                    filter = ragdoll
                })
                
                if trace.Hit then
                    util.Decal("Blood", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal)
                    
                    -- Add additional blood splatters nearby
                    for j = 1, 3 do
                        local nearbyPos = trace.HitPos + VectorRand() * 15
                        local nearbyTrace = util.TraceLine({
                            start = nearbyPos + Vector(0, 0, 10),
                            endpos = nearbyPos - Vector(0, 0, 10),
                            filter = ragdoll
                        })
                        if nearbyTrace.Hit then
                            util.Decal("Blood", nearbyTrace.HitPos + nearbyTrace.HitNormal, nearbyTrace.HitPos - nearbyTrace.HitNormal)
                        end
                    end
                end
            end
        end
        
        function RADS_StartBloodStream(ragdoll, stumpPos)
            if not IsValid(ragdoll) or not stumpPos then return end
            
            local bloodDuration = GetConVar('rads_gore_blood_duration'):GetFloat()
            local timerName = "RADS_BloodStream_" .. ragdoll:EntIndex()
            
            -- Create blood stream effect every 0.5 seconds
            timer.Create(timerName, 0.5, bloodDuration * 2, function()
                if not IsValid(ragdoll) then
                    timer.Remove(timerName)
                    return
                end
                
                -- Update stump position if it exists
                local currentStumpPos = stumpPos
                if IsValid(ragdoll.goreStump) then
                    currentStumpPos = ragdoll.goreStump:GetPos()
                end
                
                -- Create downward blood stream
                local effectdata = EffectData()
                effectdata:SetOrigin(currentStumpPos)
                effectdata:SetNormal(Vector(0, 0, -1))
                effectdata:SetMagnitude(30)
                effectdata:SetScale(1.5)
                util.Effect("BloodImpact", effectdata)
                
                -- Create blood decal on ground
                local trace = util.TraceLine({
                    start = currentStumpPos,
                    endpos = currentStumpPos + Vector(0, 0, -200),
                    filter = ragdoll
                })
                
                if trace.Hit then
                    util.Decal("Blood", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal)
                end
            end)
            
            -- Clean up timer when ragdoll is removed
            ragdoll:CallOnRemove("CleanupBloodStream", function()
                timer.Remove(timerName)
            end)
        end
        
        -- Cleanup cumulative damage tracking when ragdoll is removed
        if IsValid(ragdoll) then
            ragdoll:CallOnRemove("CleanupCumulativeDamage", function()
                local targetID = ragdoll:EntIndex()
                if RADS_CumulativeDamage and RADS_CumulativeDamage[targetID] then
                    RADS_CumulativeDamage[targetID] = nil
                end
            end)
        end
    end
    
    -- Cleanup cumulative damage tracking when player disconnects
    hook.Add("PlayerDisconnected", "RADS_CleanupCumulativeDamage", function(ply)
        if not RADS_CumulativeDamage then return end
        
        local playerID = ply:EntIndex()
        if RADS_CumulativeDamage[playerID] then
            RADS_CumulativeDamage[playerID] = nil
        end
        
        -- Also cleanup any ragdoll associated with this player
        local ragdoll = ply:GetNWEntity('player_ragdoll')
        if IsValid(ragdoll) then
            local ragdollID = ragdoll:EntIndex()
            if RADS_CumulativeDamage[ragdollID] then
                RADS_CumulativeDamage[ragdollID] = nil
            end
        end
    end)

    -- Blast damage ragdoll system with knockback
    hook.Add("EntityTakeDamage", "RADS_BlastRagdoll", function(target, dmginfo)
        if IsValid(target) and target:IsPlayer() and not target.fake and dmginfo:IsDamageType(DMG_BLAST) then
            -- Check if player is already ragdolled to prevent double ragdolling
            local existingRag = target:GetNWEntity('player_ragdoll')
            if IsValid(existingRag) then
                -- Player is already ragdolled, just apply knockback to existing ragdoll
                local forceMagnitude = math.min(dmginfo:GetDamage() * 15, 35000)
                local explosionPosition = dmginfo:GetDamagePosition()
                
                for i = 0, existingRag:GetPhysicsObjectCount() - 1 do
                    local physobj = existingRag:GetPhysicsObjectNum(i)
                    if IsValid(physobj) then
                        local bonePosition = physobj:GetPos()
                        local forceDirection = (bonePosition - explosionPosition):GetNormalized()
                        -- Add some upward force for more realistic blast effect
                        forceDirection = forceDirection + Vector(0, 0, 0.6)
                        forceDirection:Normalize()
                        physobj:ApplyForceOffset(forceDirection * forceMagnitude, bonePosition)
                    end
                end
                return
            end
            
            -- Player is not ragdolled, ragdoll them first
            rads(target)
            
            -- Store damage info before timer since dmginfo becomes invalid
            local damage = dmginfo:GetDamage()
            local explosionPos = dmginfo:GetDamagePosition()
            
            -- Apply knockback after a short delay to ensure ragdoll is created
            timer.Simple(0.1, function()
                if IsValid(target) then
                    local rag = target:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local forceMagnitude = math.min(damage * 30, 2000)
                        
                        for i = 0, rag:GetPhysicsObjectCount() - 1 do
                            local physobj = rag:GetPhysicsObjectNum(i)
                            if IsValid(physobj) then
                                local bonePosition = physobj:GetPos()
                                local forceDirection = (bonePosition - explosionPos):GetNormalized()
                                -- Add some upward force for more realistic blast effect
                                forceDirection = forceDirection + Vector(0, 0, 0.3)
                                forceDirection:Normalize()
                                physobj:ApplyForceOffset(forceDirection * forceMagnitude, bonePosition)
                            end
                        end
                    end
                end
            end)
        end
    end)

    -- Club and slash damage knockback system (only applies to existing ragdolls)
    -- Directional Club/Slash Knockback System - Applies force only to specific hit body parts
    hook.Add("EntityTakeDamage", "RADS_ClubSlashKnockback", function(target, dmginfo)
        if IsValid(target) and target:IsPlayer() and not target.fake and (dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_SLASH)) then
            -- Prevent multiple knockback applications with cooldown
            target.lastKnockbackTime = target.lastKnockbackTime or 0
            if CurTime() - target.lastKnockbackTime < 0.5 then
                return -- Ignore if knockback was applied recently
            end
            target.lastKnockbackTime = CurTime()
            
            -- Store damage info before timer since dmginfo becomes invalid
            local hitGroup = target:LastHitGroup() or HITGROUP_GENERIC
            local damage = dmginfo:GetDamage()
            local attacker = dmginfo:GetAttacker()
            local damagePos = dmginfo:GetDamagePosition()
            
            -- Calculate precise directional force from attacker to hit location
            local forceDirection = Vector(0, 0, 0)
            if IsValid(attacker) and attacker:IsPlayer() then
                -- Get attacker's aim direction for more realistic knockback
                local attackerEyes = attacker:EyePos()
                local targetHitPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine2") or 0)
                
                -- Adjust target position based on hit group for accuracy
                if hitGroup == HITGROUP_HEAD then
                    targetHitPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Head1") or 0)
                elseif hitGroup == HITGROUP_LEFTARM then
                    targetHitPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_L_UpperArm") or 0)
                elseif hitGroup == HITGROUP_RIGHTARM then
                    targetHitPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_R_UpperArm") or 0)
                elseif hitGroup == HITGROUP_LEFTLEG then
                    targetHitPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_L_Thigh") or 0)
                elseif hitGroup == HITGROUP_RIGHTLEG then
                    targetHitPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_R_Thigh") or 0)
                end
                
                forceDirection = (targetHitPos - attackerEyes):GetNormalized()
            elseif damagePos and damagePos ~= Vector(0,0,0) then
                forceDirection = (target:GetPos() - damagePos):GetNormalized()
            else
                -- Fallback to attacker's forward direction
                if IsValid(attacker) then
                    forceDirection = attacker:GetAngles():Forward()
                else
                    forceDirection = target:GetAngles():Forward()
                end
            end
            
            -- Store knockback data for later application
            target.pendingKnockback = {
                hitGroup = hitGroup,
                damage = damage,
                forceDirection = forceDirection,
                attacker = attacker,
                timestamp = CurTime()
            }
            
            -- Apply knockback with delay to ensure ragdoll is fully created
            timer.Simple(0.15, function()
                if IsValid(target) and target.pendingKnockback and (CurTime() - target.pendingKnockback.timestamp) < 2.5 then
                    local rag = target:GetNWEntity('player_ragdoll')
                    if IsValid(rag) then
                        local knockbackData = target.pendingKnockback
                        
                        -- Calculate force magnitude based on damage (further reduced to prevent neck breaking)
                        local baseForceMagnitude = math.min(knockbackData.damage * 120, 10000)
                        
                        -- Apply force only to the specific hit body part for realistic effect
                        local targetBoneName = ""
                        local forceMultiplier = 1.0
                        local upwardComponent = 0.2 -- Reduced upward force
                        
                        if knockbackData.hitGroup == HITGROUP_HEAD then
                            targetBoneName = "ValveBiped.Bip01_Head1"
                            forceMultiplier = 1.4 -- Further reduced from 2.5 to make neck breaking harder
                            upwardComponent = 0.3 -- Further reduced upward snap
                        elseif knockbackData.hitGroup == HITGROUP_CHEST then
                            targetBoneName = "ValveBiped.Bip01_Spine2"
                            forceMultiplier = 2.0 -- Reduced
                            upwardComponent = 0.3
                        elseif knockbackData.hitGroup == HITGROUP_STOMACH then
                            targetBoneName = "ValveBiped.Bip01_Spine1"
                            forceMultiplier = 1.8 -- Reduced
                            upwardComponent = 0.2
                        elseif knockbackData.hitGroup == HITGROUP_LEFTARM then
                            targetBoneName = "ValveBiped.Bip01_L_UpperArm"
                            forceMultiplier = 2.2 -- Reduced from 4.0
                            upwardComponent = 0.3
                        elseif knockbackData.hitGroup == HITGROUP_RIGHTARM then
                            targetBoneName = "ValveBiped.Bip01_R_UpperArm"
                            forceMultiplier = 2.2 -- Reduced from 4.0
                            upwardComponent = 0.3
                        elseif knockbackData.hitGroup == HITGROUP_LEFTLEG then
                            targetBoneName = "ValveBiped.Bip01_L_Thigh"
                            forceMultiplier = 2.0 -- Reduced
                            upwardComponent = 0.4
                        elseif knockbackData.hitGroup == HITGROUP_RIGHTLEG then
                            targetBoneName = "ValveBiped.Bip01_R_Thigh"
                            forceMultiplier = 2.0 -- Reduced
                            upwardComponent = 0.4
                        else
                            -- Generic hit - apply to torso
                            targetBoneName = "ValveBiped.Bip01_Spine2"
                            forceMultiplier = 1.5 -- Reduced
                            upwardComponent = 0.2
                        end
                        
                        -- Find and apply force to the specific bone
                        local boneIndex = rag:LookupBone(targetBoneName)
                        if boneIndex then
                            local physBone = rag:TranslateBoneToPhysBone(boneIndex)
                            if physBone >= 0 then
                                local physobj = rag:GetPhysicsObjectNum(physBone)
                                if IsValid(physobj) then
                                    -- Validate and fix force direction to prevent zero force
                                    local finalForce = knockbackData.forceDirection
                                    
                                    -- Check if force direction is invalid (zero vector or very small)
                                     if not finalForce or finalForce:Length() < 0.1 then
                                         -- Fallback: use attacker's forward direction or random horizontal direction
                                         if IsValid(knockbackData.attacker) then
                                             finalForce = knockbackData.attacker:GetAngles():Forward()
                                         else
                                             finalForce = Vector(math.random(-1, 1), math.random(-1, 1), 0):GetNormalized()
                                         end
                                         if GetConVar("developer"):GetInt() > 0 then
                                             print("[DIRECTIONAL KNOCKBACK] Fixed invalid force direction for " .. target:Name())
                                         end
                                     end
                                    
                                    -- Add upward component
                                    finalForce = finalForce + Vector(0, 0, upwardComponent)
                                    finalForce:Normalize()
                                    
                                    local forceMagnitude = baseForceMagnitude * forceMultiplier
                                    
                                    -- Ensure minimum force magnitude
                                    if forceMagnitude < 500 then
                                        forceMagnitude = 7500
                                        if GetConVar("developer"):GetInt() > 0 then
                                            print("[DIRECTIONAL KNOCKBACK] Applied minimum force to " .. target:Name())
                                        end
                                    end
                                    
                                    -- Apply force using ApplyForceCenter for more controlled physics
                                    physobj:ApplyForceCenter(finalForce * forceMagnitude)
                                    
                                    -- For head hits, add even more minimal rotational effect to prevent neck breaking
                                    if knockbackData.hitGroup == HITGROUP_HEAD then
                                        timer.Simple(0.05, function()
                                            if IsValid(physobj) then
                                                -- Add extremely gentle rotational force
                                                local rotForce = knockbackData.forceDirection:Cross(Vector(0, 0, 1)) * forceMagnitude * 0.05
                                                physobj:ApplyForceCenter(rotForce)
                                            end
                                        end)
                                    end
                                    
                                    -- Debug print
                                    if GetConVar("developer"):GetInt() > 0 then
                                        print("[DIRECTIONAL KNOCKBACK] Applied " .. math.Round(forceMagnitude) .. " force to " .. target:Name() .. "'s " .. targetBoneName .. " (hitgroup: " .. knockbackData.hitGroup .. ")")
                                    end
                                end
                            end
                        end
                        
                        -- Clear the pending knockback
                        target.pendingKnockback = nil
                    else
                        -- Player didn't ragdoll, clear pending knockback
                        target.pendingKnockback = nil
                    end
                end
            end)
        end
    end)



    hook.Add("PlayerDeathSound", "DeFlatline", function()
        return true
    end)

    local noise = Sound("death.wav")
    hook.Add("PlayerDeath", "NewSound", function(vic, unused1, unused2) vic:EmitSound(noise) end)
    hook.Add("PlayerTick", "CheckPlayerSpeed", function(ply, mv)
        if GetConVar('rads_fallonspeedlimit'):GetBool() and not ply.fake then
            local speed = ply:GetVelocity():Length()
            local rag = ply:GetNWEntity('player_ragdoll')
            if not IsValid(rag) and ply:GetMoveType() ~= MOVETYPE_NOCLIP and not ply:HasGodMode() and ply:GetMoveType() ~= MOVETYPE_OBSERVER then
                -- Use ConVar for velocity threshold
                local velocityThreshold = GetConVar("rads_fallonspeedlimit_threshold"):GetInt()
                if speed >= velocityThreshold then
                    rads(ply)
                    RADS.FreeFall(ply)
                end
            end
        end
    end)

    -- Optimized ragdoll velocity adrenaline system with performance scaling
    local lastRagdollVelocityCheck = 0
    local ragdollVelocityInterval = 0.5
    
    hook.Add("Think", "RADS_RagdollVelocityAdrenaline", function()
        if not SERVER then return end
        
        local cheapEffectsCvar = GetConVar("rads_cheapeffects")
        local cheapEffects = cheapEffectsCvar and cheapEffectsCvar:GetInt() or 0
        
        -- Performance scaling based on cheapeffects
        if cheapEffects >= 2 then
            ragdollVelocityInterval = 2.0 -- Very slow updates for max performance
        elseif cheapEffects >= 1 then
            ragdollVelocityInterval = 1.0 -- Moderate updates
        else
            ragdollVelocityInterval = 0.5 -- Normal updates
        end
        
        if CurTime() - lastRagdollVelocityCheck < ragdollVelocityInterval then return end
        lastRagdollVelocityCheck = CurTime()
        
        -- Skip entirely if cheapeffects is 2
        if cheapEffects >= 2 then return end
        
        for _, ply in pairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local rag = ply:GetNWEntity('player_ragdoll')
                
                -- Check if non-ragdolled player is fully submerged and auto-ragdoll them
                if not IsValid(rag) then
                    local headPos = ply:GetPos() + Vector(0, 0, 64) -- Approximate head position
                    local waterLevel = util.PointContents(headPos)
                    local isUnderwater = bit.band(waterLevel, CONTENTS_WATER) ~= 0
                    
                    if isUnderwater then
                        -- Force ragdoll the player when fully submerged
                        rads(ply, false) -- Auto-ragdoll when submerged
                    end
                    return -- Skip drowning logic for non-ragdolled players
                end
                
                if IsValid(rag) then
                    -- Initialize cooldown tracking
                    ply.ragdollAdrenalineCooldown = ply.ragdollAdrenalineCooldown or 0
                    
                    -- Check if cooldown has passed (15 seconds)
                    if CurTime() >= ply.ragdollAdrenalineCooldown then
                        -- Get main physics object (torso)
                        local mainPhys = rag:GetPhysicsObjectNum(1)
                        if IsValid(mainPhys) then
                            local velocity = mainPhys:GetVelocity():Length()
                            
                            -- Trigger adrenaline based on velocity thresholds
                            if velocity >= 1100 then
                                UpdateAdrenaline(ply, 35) -- Extreme velocity
                                ply.ragdollAdrenalineCooldown = CurTime() + 15
                                if cheapEffects == 0 then
                                    if GetConVar("developer"):GetInt() > 0 then
                                        print("[ADRENALINE DEBUG] " .. ply:Name() .. " ragdoll extreme velocity: " .. math.Round(velocity) .. " units/s")
                                    end
                                end
                            elseif velocity >= 850 then
                                UpdateAdrenaline(ply, 25) -- High velocity
                                ply.ragdollAdrenalineCooldown = CurTime() + 15
                                if cheapEffects == 0 then
                                    if GetConVar("developer"):GetInt() > 0 then
                                        print("[ADRENALINE DEBUG] " .. ply:Name() .. " ragdoll high velocity: " .. math.Round(velocity) .. " units/s")
                                    end
                                end
                            elseif velocity >= 650 then
                                UpdateAdrenaline(ply, 15) -- Medium velocity
                                ply.ragdollAdrenalineCooldown = CurTime() + 15
                                if cheapEffects == 0 then
                                    if GetConVar("developer"):GetInt() > 0 then
                                        print("[ADRENALINE DEBUG] " .. ply:Name() .. " ragdoll medium velocity: " .. math.Round(velocity) .. " units/s")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    -- Drowning System for Ragdolls
    local drowningPlayers = {}
    local lastDrowningCheck = 0
    local drowningCheckInterval = 0.5
    local swimmingPlayers = {} -- Track swimming state
    local lastSplashTime = {} -- Track splash sound cooldown
    local lastSwimTime = {} -- Track individual swimming cooldown (0.5 seconds)
    
    hook.Add("Think", "RADS_DrowningSystem", function()
        if not SERVER then return end
        
        if CurTime() - lastDrowningCheck < drowningCheckInterval then return end
        lastDrowningCheck = CurTime()
        
        for _, ply in pairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local rag = ply:GetNWEntity('player_ragdoll')
                if IsValid(rag) then
                    -- Initialize drowning data
                    if not drowningPlayers[ply] then
                        drowningPlayers[ply] = {
                            submergedTime = 0,
                            isDrowning = false,
                            drowningStartTime = 0,
                            soundPlaying = false
                        }
                    end
                    
                    local drowningData = drowningPlayers[ply]
                    
                    -- Check if ragdoll head is underwater
                    local head = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Head1")))
                    if IsValid(head) then
                        local headPos = head:GetPos()
                        local waterLevel = util.PointContents(headPos)
                        local isUnderwater = bit.band(waterLevel, CONTENTS_WATER) ~= 0
                        
                        if isUnderwater then
                            drowningData.submergedTime = drowningData.submergedTime + drowningCheckInterval
                            
                            -- Start drowning after 20 seconds underwater
                            if drowningData.submergedTime >= GetConVar("rads_drowning_threshold_time"):GetFloat() and not drowningData.isDrowning then
                                drowningData.isDrowning = true
                                drowningData.drowningStartTime = CurTime()
                                -- Set player drowning state for damage.lua
                                ply.isDrowning = true
                                ply.drowningStartTime = CurTime()
                                
                                -- Start drowning sound with continuous looping (clientside only)
                                if not drowningData.soundPlaying then
                                    if SERVER then
                                        net.Start("PlayDrowningSound")
                                        net.Send(ply)
                                    end
                                    drowningData.soundPlaying = true
                                    
                                    -- Create looping timer for drowning sound (loop every 10 seconds)
                                    timer.Create("DrowningLoop_" .. ply:EntIndex(), 10, 0, function()
                                        if IsValid(ply) and drowningData and drowningData.soundPlaying and drowningData.isDrowning and ply:Alive() then
                                            if SERVER then
                                                net.Start("PlayDrowningSound")
                                                net.Send(ply)
                                            end
                                        else
                                            timer.Remove("DrowningLoop_" .. ply:EntIndex())
                                        end
                                    end)
                                end
                            end
                            
                            -- Apply continuous sinking physics with gravity-like force
                            -- But reduce sinking significantly when player is actively swimming
                            local sinkForce = GetConVar("rads_drowning_sink_force"):GetFloat()
                            local isSwimming = swimmingPlayers[ply] and (CurTime() - swimmingPlayers[ply]) < 0.5
                            local sinkMultiplier = isSwimming and 0.05 or 1.0 -- Reduce sinking by 95% when swimming
                            
                            for i = 0, rag:GetPhysicsObjectCount() - 1 do
                                local phys = rag:GetPhysicsObjectNum(i)
                                if IsValid(phys) then
                                    local pos = phys:GetPos()
                                    local waterCheck = util.PointContents(pos)
                                    if bit.band(waterCheck, CONTENTS_WATER) ~= 0 then
                                        local mass = phys:GetMass()
                                        -- Apply continuous downward force proportional to mass (like gravity) - reduced intensity
                        local gravityForce = Vector(0, 0, -sinkForce * mass * 0.003 * sinkMultiplier) -- Reduced from 0.005 to 0.003 (40% additional reduction for even slower sinking)
                                        phys:ApplyForceCenter(gravityForce)
                                        -- Set buoyancy based on swimming state
                                        phys:SetBuoyancyRatio(isSwimming and 0.8 or 0)
                                        -- Add underwater drag for more realistic movement
                                        local velocity = phys:GetVelocity()
                                        local drag = velocity * -0.2
                                        phys:ApplyForceCenter(drag)
                                    end
                                end
                            end
                        else
                            -- Reset drowning when head is above water
                            if drowningData.isDrowning or drowningData.submergedTime > 0 then
                                -- Stop looping sound immediately (clientside)
                                if drowningData.soundPlaying then
                                    timer.Remove("DrowningLoop_" .. ply:EntIndex())
                                    timer.Remove("DrowningFadeOut_" .. ply:EntIndex())
                                    
                                    if SERVER then
                                        net.Start("StopDrowningSound")
                                        net.Send(ply)
                                    end
                                    drowningData.soundPlaying = false
                                end
                                
                                drowningData.submergedTime = 0
                                drowningData.isDrowning = false
                                drowningData.drowningStartTime = 0
                                -- Reset player drowning state for damage.lua
                                ply.isDrowning = false
                                ply.drowningStartTime = nil
                            end
                        end
                        
                        -- Check for death after 1 minute of drowning
                        if drowningData.isDrowning then
                            local drowningTime = CurTime() - drowningData.drowningStartTime
                            if drowningTime >= GetConVar("rads_drowning_death_time"):GetFloat() then
                                -- Kill player after drowning time limit
                                ply:Kill()
                                -- Clean up drowning data
                                drowningPlayers[ply] = nil
                                timer.Remove("DrowningLoop_" .. ply:EntIndex())
                                timer.Remove("DrowningFadeOut_" .. ply:EntIndex())
                                if SERVER then
                                    net.Start("StopDrowningSound")
                                    net.Send(ply)
                                end
                            end
                        end
                    end
                end
            else
                -- Clean up drowning data for dead/invalid players
                if drowningPlayers[ply] then
                    if drowningPlayers[ply].soundPlaying then
                        if SERVER then
                            net.Start("StopDrowningSound")
                            net.Send(ply)
                        end
                    end
                    drowningPlayers[ply] = nil
                    timer.Remove("DrowningLoop_" .. ply:EntIndex())
                    timer.Remove("DrowningFadeOut_" .. ply:EntIndex())
                end
            end
        end
    end)
    
    -- Swimming Controls for Ragdolls (Individual Arm Control)
    hook.Add("PlayerButtonDown", "RADS_SwimmingControls", function(ply, button)
        if not IsValid(ply) or not ply:Alive() then return end
        
        local rag = ply:GetNWEntity('player_ragdoll')
        if not IsValid(rag) then return end
        
        -- Check if ragdoll is in water first
        local head = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Head1")))
        if not IsValid(head) then return end
        
        local headPos = head:GetPos()
        local waterLevel = util.PointContents(headPos)
        local isUnderwater = bit.band(waterLevel, CONTENTS_WATER) ~= 0
        
        if not isUnderwater then return end
        
        -- Check swimming cooldown (0.5 seconds between strokes)
        if lastSwimTime[ply] and (CurTime() - lastSwimTime[ply]) < 0.5 then
            return -- Prevent swimming spam
        end
        
        local swimForce = GetConVar("rads_drowning_swim_force"):GetFloat()
        
        -- Update swimming cooldown
        lastSwimTime[ply] = CurTime()
        
        -- Track swimming state for sinking reduction
        swimmingPlayers[ply] = CurTime()
        
        -- Play splash sound with cooldown
        if not lastSplashTime[ply] or (CurTime() - lastSplashTime[ply]) > 1.0 then
            ply:EmitSound("physics/water/water_impact_soft" .. math.random(1,3) .. ".wav", 60, math.random(90, 110), 0.7)
            lastSplashTime[ply] = CurTime()
        end
        
        -- LMB - Left Arm Swimming
        if button == MOUSE_LEFT then
            local leftArmBone = rag:LookupBone("ValveBiped.Bip01_L_UpperArm")
            if leftArmBone then
                local leftArmPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(leftArmBone))
                if IsValid(leftArmPhys) then
                    -- Get player's view direction for more intuitive swimming
                    local viewAngles = ply:EyeAngles()
                    local armDirection = viewAngles:Forward()
                    
                    -- Add slight left bias for left arm swimming
                    local leftBias = viewAngles:Right() * -0.3
                    armDirection = (armDirection + leftBias):GetNormalized()
                    
                    -- Apply stronger force to multiple body parts for better swimming
                    local torso = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine")))
                    local pelvis = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Pelvis")))
                    local chest = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine2")))
                    
                    -- Enhanced force multiplier for more dynamic swimming
                    local forceMultiplier = 3.2 -- Reduced from 4.0 to 3.2 for more balanced swimming strokes
                    -- Add upward component to help surface above water
                    local upwardForce = Vector(0, 0, swimForce * 2.8) -- Reduced from 3.5 to 2.8 for more balanced upward movement
                    
                    if IsValid(torso) then
                        torso:ApplyForceCenter(armDirection * swimForce * forceMultiplier + upwardForce)
                        -- Add angular velocity for more natural swimming motion
                        local torqueForce = viewAngles:Right() * swimForce * 0.3
                        torso:ApplyTorqueCenter(torqueForce)
                    end
                    if IsValid(pelvis) then
                        pelvis:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.8 + upwardForce * 0.7)
                        -- Add slight rotational force to pelvis
                        local pelvisTorque = viewAngles:Up() * swimForce * 0.2
                        pelvis:ApplyTorqueCenter(pelvisTorque)
                    end
                    if IsValid(chest) then
                        chest:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.6 + upwardForce * 0.5)
                        -- Add chest rotation for swimming stroke
                        local chestTorque = viewAngles:Right() * swimForce * -0.2
                        chest:ApplyTorqueCenter(chestTorque)
                    end
                    
                    -- Add leg paddling for left arm swimming
                    local leftThighBone = rag:LookupBone("ValveBiped.Bip01_L_Thigh")
                    local rightThighBone = rag:LookupBone("ValveBiped.Bip01_R_Thigh")
                    local leftCalfBone = rag:LookupBone("ValveBiped.Bip01_L_Calf")
                    local rightCalfBone = rag:LookupBone("ValveBiped.Bip01_R_Calf")
                    
                    if leftThighBone then
                        local leftThighPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(leftThighBone))
                        if IsValid(leftThighPhys) then
                            leftThighPhys:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.4 + upwardForce * 0.3)
                        end
                    end
                    if rightThighBone then
                        local rightThighPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rightThighBone))
                        if IsValid(rightThighPhys) then
                            rightThighPhys:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.4 + upwardForce * 0.3)
                        end
                    end
                    if leftCalfBone then
                        local leftCalfPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(leftCalfBone))
                        if IsValid(leftCalfPhys) then
                            leftCalfPhys:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.3 + upwardForce * 0.2)
                        end
                    end
                    if rightCalfBone then
                        local rightCalfPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rightCalfBone))
                        if IsValid(rightCalfPhys) then
                            rightCalfPhys:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.3 + upwardForce * 0.2)
                        end
                    end
                end
            end
        end
        
        -- RMB - Right Arm Swimming
        if button == MOUSE_RIGHT then
            local rightArmBone = rag:LookupBone("ValveBiped.Bip01_R_UpperArm")
            if rightArmBone then
                local rightArmPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rightArmBone))
                if IsValid(rightArmPhys) then
                    -- Get player's view direction for more intuitive swimming
                    local viewAngles = ply:EyeAngles()
                    local armDirection = viewAngles:Forward()
                    
                    -- Add slight right bias for right arm swimming
                    local rightBias = viewAngles:Right() * 0.3
                    armDirection = (armDirection + rightBias):GetNormalized()
                    
                    -- Apply stronger force to multiple body parts for better swimming
                    local torso = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine")))
                    local pelvis = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Pelvis")))
                    local chest = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine2")))
                    
                    -- Enhanced force multiplier for more dynamic swimming
                    local forceMultiplier = 3.2 -- Reduced from 4.0 to 3.2 for more balanced swimming strokes
                    -- Add upward component to help surface above water
                    local upwardForce = Vector(0, 0, swimForce * 2.8) -- Reduced from 3.5 to 2.8 for more balanced upward movement
                    
                    if IsValid(torso) then
                        torso:ApplyForceCenter(armDirection * swimForce * forceMultiplier + upwardForce)
                        -- Add angular velocity for more natural swimming motion
                        local torqueForce = viewAngles:Right() * swimForce * -0.3 -- Opposite direction for right arm
                        torso:ApplyTorqueCenter(torqueForce)
                    end
                    if IsValid(pelvis) then
                        pelvis:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.8 + upwardForce * 0.7)
                        -- Add slight rotational force to pelvis
                        local pelvisTorque = viewAngles:Up() * swimForce * -0.2 -- Opposite direction for right arm
                        pelvis:ApplyTorqueCenter(pelvisTorque)
                    end
                    if IsValid(chest) then
                        chest:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.6 + upwardForce * 0.5)
                        -- Add chest rotation for swimming stroke
                        local chestTorque = viewAngles:Right() * swimForce * 0.2 -- Opposite direction for right arm
                        chest:ApplyTorqueCenter(chestTorque)
                    end
                    
                    -- Add leg paddling for right arm swimming
                    local leftThighBone = rag:LookupBone("ValveBiped.Bip01_L_Thigh")
                    local rightThighBone = rag:LookupBone("ValveBiped.Bip01_R_Thigh")
                    local leftCalfBone = rag:LookupBone("ValveBiped.Bip01_L_Calf")
                    local rightCalfBone = rag:LookupBone("ValveBiped.Bip01_R_Calf")
                    
                    if leftThighBone then
                        local leftThighPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(leftThighBone))
                        if IsValid(leftThighPhys) then
                            leftThighPhys:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.4 + upwardForce * 0.3)
                        end
                    end
                    if rightThighBone then
                        local rightThighPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rightThighBone))
                        if IsValid(rightThighPhys) then
                            rightThighPhys:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.4 + upwardForce * 0.3)
                        end
                    end
                    if leftCalfBone then
                        local leftCalfPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(leftCalfBone))
                        if IsValid(leftCalfPhys) then
                            leftCalfPhys:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.3 + upwardForce * 0.2)
                        end
                    end
                    if rightCalfBone then
                        local rightCalfPhys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rightCalfBone))
                        if IsValid(rightCalfPhys) then
                            rightCalfPhys:ApplyForceCenter(armDirection * swimForce * forceMultiplier * 0.3 + upwardForce * 0.2)
                        end
                    end
                end
            end
        end
    end)

    -- Death state cleanup for drowning system
    hook.Add("PlayerDeath", "RADS_DrowningDeathCleanup", function(victim, inflictor, attacker)
        if not IsValid(victim) then return end
        
        -- Clean up drowning data and sounds on death
        if drowningPlayers[victim] then
            if drowningPlayers[victim].soundPlaying then
                victim:StopSound("drowning.ogg")
            end
            drowningPlayers[victim] = nil
        end
        
        -- Clean up swimming state tracking
        swimmingPlayers[victim] = nil
        lastSplashTime[victim] = nil
        lastSwimTime[victim] = nil
        
        -- Remove all drowning-related timers
        timer.Remove("DrowningLoop_" .. victim:EntIndex())
        timer.Remove("DrowningFadeOut_" .. victim:EntIndex())
        
        -- Reset drowning state variables
        victim.isDrowning = false
        victim.drowningStartTime = nil
    end)
    
    -- Respawn cleanup for drowning system
    hook.Add("PlayerSpawn", "RADS_DrowningRespawnCleanup", function(ply)
        if not IsValid(ply) then return end
        
        -- Ensure clean state on respawn
        if drowningPlayers[ply] then
            drowningPlayers[ply] = nil
        end
        
        -- Clean up swimming state tracking
        swimmingPlayers[ply] = nil
        lastSplashTime[ply] = nil
        lastSwimTime[ply] = nil
        
        -- Remove any lingering timers
        timer.Remove("DrowningLoop_" .. ply:EntIndex())
        timer.Remove("DrowningFadeOut_" .. ply:EntIndex())
        
        -- Stop any drowning sounds
        ply:StopSound("drowning.ogg")
        
        -- Reset drowning state variables
        ply.isDrowning = false
        ply.drowningStartTime = nil
    end)

    hook.Add("RADSLoadout", "RADSLuaLoad", function(ply)
        if not ply.resetinv and not GetConVar('rads_loadoutusinglua'):GetBool() then
            return
        else
            RADS_ReturnPlyInfo(ply)
            RADS_RestoreEzArmor(ply)
        end

        if RADS.IsTTT() then
            ply:Give('weapon_zm_improvised')
            ply:Give('weapon_zm_carry')
            ply:Give('weapon_ttt_unarmed')
        end
    end)

    hook.Add("PreCleanupMap", "getupnoobis", function()
        for i, v in pairs(player.GetAll()) do
            if v.brokenspine then v:Kill() end
            if v.fake then rads(v) end
        end
    end)

    util.AddNetworkString("ebal_chellele")
    hook.Add("PlayerSwitchWeapon", "fakewep", function(ply, oldwep, newwep)
        rag = ply:GetNWEntity('player_ragdoll')
        if IsValid(rag) then
            if ply.fake then
                if IsValid(ply.Info.ActiveWeapon2) and IsValid(ply.wep) and ply.wep.Clip ~= nil and ply.wep.Amt ~= nil and ply.wep.AmmoType ~= nil then
                    ply.Info.ActiveWeapon2:SetClip1(ply.wep.Clip or 0)
                    ply:SetAmmo(ply.wep.Amt or 0, ply.wep.AmmoType or 0)
                end

                if table.HasValue(Guns, newwep:GetClass()) then
                    if IsValid(ply.wep) then 
					if _G.DespawnWeapon then
						_G.DespawnWeapon(ply)
					else
						if GetConVar("developer"):GetInt() > 0 then
							print("[RADS] ERROR: DespawnWeapon function not available globally at line 1770!")
						end
					end
				end
                    ply:SetActiveWeapon(newwep)
                    ply.Info.ActiveWeapon = newwep
                    ply.curweapon = newwep:GetClass()
                    RADS_SavePlyInfo(ply)
                    ply:SetActiveWeapon(nil)
                    if _G.SpawnWeapon then
                        _G.SpawnWeapon(ply)
                    else
                        if GetConVar("developer"):GetInt() > 0 then
                            print("[RADS] ERROR: SpawnWeapon function not available globally at line 1776!")
                        end
                    end
                    ply.FakeShooting = true
                else
                    if IsValid(ply.wep) then 
					if _G.DespawnWeapon then
						_G.DespawnWeapon(ply)
					else
						if GetConVar("developer"):GetInt() > 0 then
							print("[RADS] ERROR: DespawnWeapon function not available globally at line 1783!")
						end
					end
				end
                    ply:SetActiveWeapon(nil)
                    ply.curweapon = nil
                    ply.FakeShooting = false
                end

                net.Start("ebal_chellele")
                net.WriteEntity(ply)
                net.WriteString(ply.curweapon or "")
                net.Broadcast()
                return true
            end
        end
    end)

    hook.Add("Player Think", "ragmovement", function(ply, time)
        if not ply:Alive() then return end
        local rag = ply:GetNWEntity('player_ragdoll')
        if not IsValid(rag) or not ply:Alive() then return end
        local walkTime = 1 -- rag:SetFlexWeight(5,0)
        local eyeangs = ply:EyeAngles()
        local head = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Head1")))
        
        -- Rolling functionality for ragdolls
        -- Roll left (A key) - but not while diving
        if ply:KeyDown(IN_MOVELEFT) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not (rag.isDiving or false) and not ply.brokenupperspine then
            local torso = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine")))
            local pelvis = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Pelvis")))
            
            if IsValid(torso) and IsValid(pelvis) then
                -- Get the ragdoll's up vector to determine which way is "up"
                local ragUp = torso:GetAngles():Up()
                -- Only roll if the ragdoll is somewhat upright (not already on its side)
                local upDot = ragUp:Dot(Vector(0,0,1))
                
                -- Get world-aligned roll direction (left is -Y in Source)
                local rollDirection = Vector(0, -1, 0)
                
                -- Reduced force and torque values
                local rollForce = 40
                local rollTorque = 80
                
                -- Apply downward force on the "high" side to initiate roll
                local sideOffset = torso:GetPos() + Vector(0, -20, 0) -- Left side
                torso:ApplyForceOffset(Vector(0, 0, -rollForce*2), sideOffset)
                
                -- Apply gentle torque for rotation assistance
                torso:ApplyTorqueCenter(Vector(rollTorque, 0, 0))
                pelvis:ApplyTorqueCenter(Vector(rollTorque, 0, 0))
                
                -- Apply main rolling force to the body center
                torso:ApplyForceCenter(rollDirection * rollForce)
                pelvis:ApplyForceCenter(rollDirection * rollForce)
            end
        end
        
        -- Roll right (D key) - but not while diving
        if ply:KeyDown(IN_MOVERIGHT) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not (rag.isDiving or false) and not ply.brokenupperspine then
            local torso = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine")))
            local pelvis = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Pelvis")))
            
            if IsValid(torso) and IsValid(pelvis) then
                -- Get the ragdoll's up vector to determine which way is "up"
                local ragUp = torso:GetAngles():Up()
                -- Only roll if the ragdoll is somewhat upright (not already on its side)
                local upDot = ragUp:Dot(Vector(0,0,1))
                
                -- Get world-aligned roll direction (right is +Y in Source)
                local rollDirection = Vector(0, 1, 0)
                
                -- Reduced force and torque values
                local rollForce = 40
                local rollTorque = 80
                
                -- Apply downward force on the "high" side to initiate roll
                local sideOffset = torso:GetPos() + Vector(0, 20, 0) -- Right side
                torso:ApplyForceOffset(Vector(0, 0, -rollForce*2), sideOffset)
                
                -- Apply gentle torque for rotation assistance
                torso:ApplyTorqueCenter(Vector(-rollTorque, 0, 0))
                pelvis:ApplyTorqueCenter(Vector(-rollTorque, 0, 0))
                
                -- Apply main rolling force to the body center
                torso:ApplyForceCenter(rollDirection * rollForce)
                pelvis:ApplyForceCenter(rollDirection * rollForce)
            end
        end
        
        if ply:KeyDown(IN_ATTACK) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then
            local pos = ply:EyePos()
            pos[3] = head:GetPos()[3]
            if not ply.FakeShooting then
                local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_L_Hand")))
                local ang = ply:EyeAngles()
                ang:RotateAroundAxis(eyeangs:Forward(), 90)
                ang:RotateAroundAxis(eyeangs:Right(), 75)
                -- Apply shock responsiveness factor
                local responsivenessFactor = rag.responsivenessFactor or 1
                local shadowparams = {
                    secondstoarrive = 0.4 / responsivenessFactor,
                    pos = head:GetPos() + eyeangs:Forward() * 50 + eyeangs:Right() * -5,
                    angle = ang,
                    maxangular = 670 * responsivenessFactor,
                    maxangulardamp = 600,
                    maxspeeddamp = 50,
                    maxspeed = 500 * responsivenessFactor,
                    teleportdistance = 0,
                    deltatime = 0.01,
                }

                phys:Wake()
                phys:ComputeShadowControl(shadowparams)
            end
        end

        -- Check if weapon is automatic using the Automatic table
        if ply.curweapon and Automatic and Automatic[ply.curweapon] then
            -- Debug: Print automatic weapon detection
            if ply.curweapon == "wep_mann_hmcd_akm" then
                if GetConVar("developer"):GetInt() > 0 then
                    print("[RADS DEBUG] AKM detected as AUTOMATIC, using KeyDown for continuous fire")
                end
            end
            if ply:KeyDown(IN_ATTACK) then if ply.FakeShooting then 
			if _G.FireShot then
				_G.FireShot(ply.wep)
			else
				if GetConVar("developer"):GetInt() > 0 then
				print("[RADS] ERROR: FireShot function not available globally at line 1898!")
			end
			end
		end end
        else
            -- Debug: Print semi-automatic weapon detection
            if ply.curweapon == "wep_mann_hmcd_akm" then
                if GetConVar("developer"):GetInt() > 0 then
                    print("[RADS DEBUG] AKM detected as SEMI-AUTO, using KeyPressed for single shots")
                    print("[RADS DEBUG] Automatic table value for AKM:", Automatic and Automatic["wep_mann_hmcd_akm"] or "nil")
                end
            end
            if ply:KeyPressed(IN_ATTACK) then if ply.FakeShooting then 
			if _G.FireShot then
				_G.FireShot(ply.wep)
			else
				if GetConVar("developer"):GetInt() > 0 then
				print("[RADS] ERROR: FireShot function not available globally at line 1900!")
			end
			end
		end end
        end

        if ply:KeyDown(IN_JUMP) and (table.Count(constraint.FindConstraints(ply:GetNWEntity("player_ragdoll"), 'Rope')) > 0 or ((rag.IsWeld or 0) > 0)) and (ply.lastuntietry or 0) < CurTime() and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then -- if(ply:KeyDown(IN_MOVERIGHT)) and !timer.Exists("StunTime"..ply:EntIndex()) and !timer.Exists("Epilepsy"..ply:EntIndex()) and not ply.Otrub then --     local pos = ply:EyePos() --     pos[3] = head:GetPos()[3] --         local phys = rag:GetPhysicsObjectNum( rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_R_Calf" )) ) --         local ang=ply:EyeAngles() --         ang:RotateAroundAxis(eyeangs:Forward(),90) --         ang:RotateAroundAxis(eyeangs:Right(),80) --         local shadowparams = { --             secondstoarrive=0.4, --             pos=head:GetPos()+eyeangs:Forward()*55+eyeangs:Right()*2, --             angle=ang, --             maxangular=670, --             maxangulardamp=600, --             maxspeeddamp=50, --             maxspeed=500, --             teleportdistance=0, --             deltatime=0.01, --         } --         phys:Wake() --         phys:ComputeShadowControl(shadowparams) --     end -- if(ply:KeyDown(IN_MOVELEFT)) and !timer.Exists("StunTime"..ply:EntIndex()) and !timer.Exists("Epilepsy"..ply:EntIndex()) and not ply.Otrub then --     local pos = ply:EyePos() --     pos[3] = head:GetPos()[3] --         local phys = rag:GetPhysicsObjectNum( rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_L_Calf" )) ) --         local ang=ply:EyeAngles() --         ang:RotateAroundAxis(eyeangs:Forward(),90) --         ang:RotateAroundAxis(eyeangs:Right(),80) --         local shadowparams = { --             secondstoarrive=0.4, --             pos=head:GetPos()+eyeangs:Forward()*55+eyeangs:Right()*2, --             angle=ang, --             maxangular=670, --             maxangulardamp=600, --             maxspeeddamp=50, --             maxspeed=500, --             teleportdistance=0, --             deltatime=0.01, --         } --         phys:Wake() --         phys:ComputeShadowControl(shadowparams) --     end
            ply.lastuntietry = CurTime() + 1
            rag.IsWeld = math.max((rag.IsWeld or 0) - 0.1, 0)
            local RopeCount = table.Count(constraint.FindConstraints(ply:GetNWEntity("player_ragdoll"), 'Rope'))
            Ropes = constraint.FindConstraints(ply:GetNWEntity("player_ragdoll"), 'Rope')
            Try = math.random(1, 10 * RopeCount)
            local phys = rag:GetPhysicsObjectNum(1)
            local speed = 200
            -- Apply shock responsiveness factor
            local responsivenessFactor = rag.responsivenessFactor or 1
            local shadowparams = {
                secondstoarrive = 0.05 / responsivenessFactor,
                pos = phys:GetPos() + phys:GetAngles():Forward() * 20,
                angle = phys:GetAngles(),
                maxangulardamp = 30,
                maxspeeddamp = 30,
                maxangular = 90 * responsivenessFactor,
                maxspeed = speed * responsivenessFactor,
                teleportdistance = 0,
                deltatime = 0.01,
            }

            phys:Wake()
            phys:ComputeShadowControl(shadowparams)
            if Try > (7 * RopeCount) or ((rag.IsWeld or 0) > 0) then
                if RopeCount > 1 or (rag.IsWeld or 0 > 0) then
                    if RopeCount > 1 then ply:ChatPrint("Left: " .. RopeCount - 1) end
                    if (rag.IsWeld or 0) > 0 then ply:ChatPrint("All that's left is to knock off the nails: " .. tostring(math.ceil(rag.IsWeld))) end
                else
                    ply:ChatPrint("You've come untied")
                end

                Ropes[1].Constraint:Remove()
                rag:EmitSound("restains.wav", 90, 50, 0.5, CHAN_AUTO)
            end
        end

        if ply:KeyDown(IN_USE) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then
            -- Mark that player is intentionally raising upper body to prevent neck breaking
            ply.raisingUpperBody = true
            
            local phys = head
            local angs = ply:EyeAngles()
            angs:RotateAroundAxis(angs:Forward(), 90)
            -- Apply shock responsiveness factor
            local responsivenessFactor = rag.responsivenessFactor or 1
            
            -- Check if ragdoll is airborne or has high velocity
            local ragVelocity = rag:GetVelocity():Length()
            local isAirborne = ragVelocity > 100 -- Threshold for high velocity/airborne
            
            local shadowparams
            if isAirborne then
                -- Use current settings for mid-air/high velocity
                shadowparams = {
                    secondstoarrive = 0.45 / responsivenessFactor,  -- Increased from 0.5 for smoother movement
                    pos = head:GetPos() + Vector(0, 0, 20 / math.Clamp(rag:GetVelocity():Length() / 300, 1, 12)),
                    angle = angs,
                    maxangulardamp = 20,    -- Increased from 10 for more damping
                    maxspeeddamp = 20,      -- Increased from 10 for more damping
                    maxangular = 360 * responsivenessFactor,       -- Reduced from 370 to prevent neck stress
                    maxspeed = 39 * responsivenessFactor,          -- Reduced from 40 for gentler movement
                    teleportdistance = 0,
                    deltatime = deltatime,
                }
            else
                -- Use new settings for grounded/low velocity
                shadowparams = {
                    secondstoarrive = 0.15 / responsivenessFactor,  -- Increased from 0.5 for smoother movement
                    pos = head:GetPos() + Vector(0, 0, 20 / math.Clamp(rag:GetVelocity():Length() / 300, 1, 12)),
                    angle = angs,
                    maxangulardamp = 35,    -- Increased from 10 for more damping
                    maxspeeddamp = 25,      -- Increased from 10 for more damping
                    maxangular = 450 * responsivenessFactor,       -- Reduced from 370 to prevent neck stress
                    maxspeed = 45 * responsivenessFactor,          -- Reduced from 40 for gentler movement
                    teleportdistance = 0,
                    deltatime = deltatime,
                }
            end

            head:Wake()
            head:ComputeShadowControl(shadowparams)
        else
            -- Clear the flag when not holding E
            if ply.raisingUpperBody then
                ply.raisingUpperBody = false
            end
        end

        if ply:KeyDown(IN_ATTACK2) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then
            local physa = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_R_Hand")))
            local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_L_Hand"))) --rhand
            local ang = ply:EyeAngles()
            ang:RotateAroundAxis(eyeangs:Forward(), 90)
            ang:RotateAroundAxis(eyeangs:Right(), 75)
            local pos = ply:EyePos()
            pos[3] = head:GetPos()[3]
            -- Apply shock responsiveness factor
            local responsivenessFactor = rag.responsivenessFactor or 1
            local shadowparams = {
                secondstoarrive = 0.4 / responsivenessFactor,
                pos = head:GetPos() + eyeangs:Forward() * 50 + eyeangs:Right() * 15,
                angle = ang,
                maxangular = 670 * responsivenessFactor,
                maxangulardamp = 600,
                maxspeeddamp = 50,
                maxspeed = 500 * responsivenessFactor,
                teleportdistance = 0,
                deltatime = 0.01,
            }

            physa:Wake()
            if not ply.suiciding or TwoHandedOrNo[ply.curweapon] then
                if TwoHandedOrNo[ply.curweapon] and IsValid(ply.wep) then
                    local ang = ply:EyeAngles()
                    ang:RotateAroundAxis(ang:Forward(), 90)
                    ang:RotateAroundAxis(ang:Up(), 20)
                    ang:RotateAroundAxis(ang:Right(), 10)
                    shadowparams.angle = ang
                    local wepPhys = ply.wep:GetPhysicsObject()
                    if IsValid(wepPhys) then
                        wepPhys:ComputeShadowControl(shadowparams)
                    end
                    shadowparams.pos = shadowparams.pos
                    phys:ComputeShadowControl(shadowparams)
                    shadowparams.pos = shadowparams.pos + eyeangs:Forward() * -50 + eyeangs:Right() * -15
                    physa:ComputeShadowControl(shadowparams)
                elseif IsValid(ply.wep) and IsValid(ply.wep:GetPhysicsObject()) then
                    -- One-handed weapon (pistol) aiming with counter-force to prevent excessive movement
                    ang:RotateAroundAxis(ply:EyeAngles():Forward(), 90)
                    ang:RotateAroundAxis(ply:EyeAngles():Up(), 110)
                    ang:RotateAroundAxis(eyeangs:Right(), -30)
                    shadowparams.angle = ang
                    shadowparams.pos = shadowparams.pos + eyeangs:Right() * -15
                    
                    -- Apply stronger constraint for pistols to prevent going beyond hand
                    local pistolShadowParams = {
                        secondstoarrive = 0.2 / responsivenessFactor,  -- Faster response
                        pos = physa:GetPos() + eyeangs:Forward() * 8 + eyeangs:Right() * -5,  -- Closer to hand
                        angle = ang,
                        maxangular = 400 * responsivenessFactor,  -- Reduced angular movement
                        maxangulardamp = 800,  -- Higher damping
                        maxspeeddamp = 100,  -- Higher speed damping
                        maxspeed = 200 * responsivenessFactor,  -- Reduced max speed
                        teleportdistance = 0,
                        deltatime = 0.01,
                    }
                    
                    local wepPhys = ply.wep:GetPhysicsObject()
                    if IsValid(wepPhys) then
                        wepPhys:ComputeShadowControl(pistolShadowParams)
                    end
                    physa:ComputeShadowControl(shadowparams)
                else
                    physa:ComputeShadowControl(shadowparams)
                end
            else
                if ply.FakeShooting and IsValid(ply.wep) then
                    shadowparams.maxspeed = 500
                    shadowparams.maxangular = 500
                    shadowparams.pos = head:GetPos() - ply.wep:GetAngles():Forward() * 12
                    local wepPhys = ply.wep:GetPhysicsObject()
                    if IsValid(wepPhys) then
                        shadowparams.angle = wepPhys:GetAngles()
                        wepPhys:ComputeShadowControl(shadowparams)
                    end
                    physa:ComputeShadowControl(shadowparams)
                end
            end
        end

        if ply:KeyDown(IN_SPEED) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then
            local bone = rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_L_Hand"))
            local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_L_Hand")))
            if not IsValid(rag.ZacConsLH) and (not rag.ZacNextGrLH or rag.ZacNextGrLH <= CurTime()) then -- if !TwoHandedOrNo[ply.curweapon] then --     local shadowparams = { --     secondstoarrive=0.5, --     pos=head:GetPos(), --     angle=angs, --     maxangulardamp=10, --     maxspeeddamp=10, --     maxangular=370, --     maxspeed=1120, --     teleportdistance=0, --     deltatime=deltatime, --     } --     phys:Wake() --     phys:ComputeShadowControl(shadowparams)
                rag.ZacNextGrLH = CurTime() + 0.1
                for i = 1, 3 do
                    local offset = phys:GetAngles():Up() * -5
                    if i == 2 then offset = phys:GetAngles():Right() * 5 end
                    if i == 3 then offset = phys:GetAngles():Right() * -5 end
                    local traceinfo = {
                        start = phys:GetPos(),
                        endpos = phys:GetPos() + offset,
                        filter = rag,
                        output = trace,
                    }

                    local trace = util.TraceLine(traceinfo)
                    if trace.Hit and not trace.HitSky then
                        local cons = constraint.Weld(rag, trace.Entity, bone, trace.PhysicsBone, GetConVar('rads_lefthandlimit'):GetInt(), false, false)
                        if IsValid(cons) then
                            rag.ZacConsLH = cons
                            local pos = rag.ZacConsLH:GetPos() -- rag:EmitSound("physics/rubber/rubber_tire_strain3.wav", 100, 100, 1)   -- if IsValid(rag.ZacConsLH) then
                            net.Start("CapturePositionLH")
                            net.WriteVector(pos)
                            net.Send(ply)
                            
                            -- NEW: Hand grappling finger manipulation
                            local gripAngle = Angle(-25, 0, 0)
                            for i = 0, 4 do -- 5 fingers
                                for j = 1, 3 do -- 3 joints per finger
                                    local fingerBone = "ValveBiped.Bip01_L_Finger" .. i .. j
                                    if rag:LookupBone(fingerBone) then
                                        rag:ManipulateBoneAngles(rag:LookupBone(fingerBone), gripAngle)
                                    end
                                end
                            end
                            
                            -- Send grappling icon message
                            net.Start("showiconleft")
                            net.Send(ply)
                            
                            if trace.Entity:IsPlayer() and GetConVar('rads_fallwhengrabbed'):GetBool() then -- end 
                                rads(trace.Entity)
                            end
                        end

                        break
                    end
                end
            end
        else
            if IsValid(rag.ZacConsLH) then
                rag.ZacConsLH:Remove()
                rag.ZacConsLH = nil
                
                -- NEW: Reset finger angles when releasing grip
                local zeroAng = Angle(0, 0, 0)
                for i = 0, 4 do -- 5 fingers
                    for j = 1, 3 do -- 3 joints per finger
                        local fingerBone = "ValveBiped.Bip01_L_Finger" .. i .. j
                        if rag:LookupBone(fingerBone) then
                            rag:ManipulateBoneAngles(rag:LookupBone(fingerBone), zeroAng)
                        end
                    end
                end
                
                -- Hide grappling icon
                net.Start("hideiconleft")
                net.Send(ply)
            end
        end

        if ply:KeyDown(IN_WALK) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then -- end
            local bone = rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_R_Hand"))
            local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_R_Hand")))
            if not IsValid(rag.ZacConsRH) and (not rag.ZacNextGrRH or rag.ZacNextGrRH <= CurTime()) then
                rag.ZacNextGrRH = CurTime() + 0.1
                for i = 1, 3 do
                    local offset = phys:GetAngles():Up() * 5
                    if i == 2 then offset = phys:GetAngles():Right() * 5 end
                    if i == 3 then offset = phys:GetAngles():Right() * -5 end
                    local traceinfo = {
                        start = phys:GetPos(),
                        endpos = phys:GetPos() + offset,
                        filter = rag,
                        output = trace,
                    }

                    local trace = util.TraceLine(traceinfo)
                    if trace.Hit and not trace.HitSky then
                        local cons = constraint.Weld(rag, trace.Entity, bone, trace.PhysicsBone, GetConVar('rads_righthandlimit'):GetInt(), false, false)
                        if IsValid(cons) then
                            rag.ZacConsRH = cons
                            local pos = rag.ZacConsRH:GetPos() -- rag:EmitSound("physics/rubber/rubber_tire_strain3.wav", 100, 100, 1)  -- if IsValid(rag.ZacConsRH) then
                            net.Start("CapturePositionRH")
                            net.WriteVector(pos)
                            net.Send(ply)
                            
                            -- NEW: Hand grappling finger manipulation for right hand
                            local gripAngle = Angle(25, 0, 0) -- Different angle for right hand to prevent "snapped" appearance
                            for i = 0, 4 do -- 5 fingers
                                for j = 1, 3 do -- 3 joints per finger
                                    local fingerBone = "ValveBiped.Bip01_R_Finger" .. i .. j
                                    if rag:LookupBone(fingerBone) then
                                        rag:ManipulateBoneAngles(rag:LookupBone(fingerBone), gripAngle)
                                    end
                                end
                            end
                            
                            -- Send grappling icon message
                            net.Start("showiconright")
                            net.Send(ply)
                            
                            if trace.Entity:IsPlayer() and GetConVar('rads_fallwhengrabbed'):GetBool() then -- end
                                rads(trace.Entity)
                            end
                        end

                        break
                    end
                end
            end
        else
            if IsValid(rag.ZacConsRH) then
                rag.ZacConsRH:Remove()
                rag.ZacConsRH = nil
                
                -- NEW: Reset finger angles when releasing grip
                local zeroAng = Angle(0, 0, 0)
                for i = 0, 4 do -- 5 fingers
                    for j = 1, 3 do -- 3 joints per finger
                        local fingerBone = "ValveBiped.Bip01_R_Finger" .. i .. j
                        if rag:LookupBone(fingerBone) then
                            rag:ManipulateBoneAngles(rag:LookupBone(fingerBone), zeroAng)
                        end
                    end
                end
                
                -- Hide grappling icon
                net.Start("hideiconright")
                net.Send(ply)
            end
        end

        if (ply:KeyDown(IN_FORWARD) and IsValid(rag.ZacConsLH)) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then
            local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine")))
            local lh = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_L_Hand")))
            local angs = ply:EyeAngles()
            angs:RotateAroundAxis(angs:Forward(), 90)
            angs:RotateAroundAxis(angs:Up(), 90)
            local speed = GetConVar('rads_pullupspeed'):GetInt()
            if rag.ZacConsLH.Ent2:GetVelocity():LengthSqr() < 1000 then
                -- Apply shock responsiveness factor
                local responsivenessFactor = rag.responsivenessFactor or 1
                local shadowparams = {
                    secondstoarrive = 0.5 / responsivenessFactor,
                    pos = lh:GetPos(),
                    angle = phys:GetAngles(),
                    maxangulardamp = 10,
                    maxspeeddamp = 10,
                    maxangular = 50 * responsivenessFactor,
                    maxspeed = speed * responsivenessFactor,
                    teleportdistance = 0,
                    deltatime = deltatime,
                }

                phys:Wake()
                phys:ComputeShadowControl(shadowparams)
            end
        end

        if (ply:KeyDown(IN_FORWARD) and IsValid(rag.ZacConsRH)) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then
            local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine")))
            local rh = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_R_Hand")))
            local angs = ply:EyeAngles()
            angs:RotateAroundAxis(angs:Forward(), 90)
            angs:RotateAroundAxis(angs:Up(), 90)
            local speed = GetConVar('rads_pullupspeed'):GetInt()
            if rag.ZacConsRH.Ent2:GetVelocity():LengthSqr() < 1000 then
                -- Apply shock responsiveness factor
                local responsivenessFactor = rag.responsivenessFactor or 1
                local shadowparams = {
                    secondstoarrive = 0.5 / responsivenessFactor,
                    pos = rh:GetPos(),
                    angle = phys:GetAngles(),
                    maxangulardamp = 10,
                    maxspeeddamp = 10,
                    maxangular = 50 * responsivenessFactor,
                    maxspeed = speed * responsivenessFactor,
                    teleportdistance = 0,
                    deltatime = deltatime,
                }

                phys:Wake()
                phys:ComputeShadowControl(shadowparams)
            end
        end

        if (ply:KeyDown(IN_BACK) and IsValid(rag.ZacConsLH)) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then
            local phys = rag:GetPhysicsObjectNum(1)
            local chst = rag:GetPhysicsObjectNum(0)
            local angs = ply:EyeAngles()
            angs:RotateAroundAxis(angs:Forward(), 90)
            angs:RotateAroundAxis(angs:Up(), 90)
            local speed = 30
            if rag.ZacConsLH.Ent2:GetVelocity():LengthSqr() < 1000 then
                -- Apply shock responsiveness factor
                local responsivenessFactor = rag.responsivenessFactor or 1
                local shadowparams = {
                    secondstoarrive = 0.5 / responsivenessFactor,
                    pos = chst:GetPos(),
                    angle = phys:GetAngles(),
                    maxangulardamp = 10,
                    maxspeeddamp = 10,
                    maxangular = 50 * responsivenessFactor,
                    maxspeed = speed * responsivenessFactor,
                    teleportdistance = 0,
                    deltatime = deltatime,
                }

                phys:Wake()
                phys:ComputeShadowControl(shadowparams)
            end
        end

        if (ply:KeyDown(IN_BACK) and IsValid(rag.ZacConsRH)) and not timer.Exists("StunTime" .. ply:EntIndex()) and not timer.Exists("Epilepsy" .. ply:EntIndex()) and not ply.Otrub and not ply.brokenupperspine then
            local phys = rag:GetPhysicsObjectNum(1)
            local chst = rag:GetPhysicsObjectNum(0)
            local angs = ply:EyeAngles()
            angs:RotateAroundAxis(angs:Forward(), 90)
            angs:RotateAroundAxis(angs:Up(), 90)
            local speed = 30
            if rag.ZacConsRH.Ent2:GetVelocity():LengthSqr() < 1000 then
                -- Apply shock responsiveness factor
                local responsivenessFactor = rag.responsivenessFactor or 1
                local shadowparams = {
                    secondstoarrive = 0.5 / responsivenessFactor,
                    pos = chst:GetPos(),
                    angle = phys:GetAngles(),
                    maxangulardamp = 10,
                    maxspeeddamp = 10,
                    maxangular = 50 * responsivenessFactor,
                    maxspeed = speed * responsivenessFactor,
                    teleportdistance = 0,
                    deltatime = deltatime,
                }

                phys:Wake()
                phys:ComputeShadowControl(shadowparams)
            end
        end

        -- Getting up logic
        local head = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Head1")))
        if head and IsValid(head) then
            -- REMOVED: Leg restriction code - players can now get up regardless of leg condition
            local ragdollVelocity = rag:GetVelocity():Length()
            local MaxUp = 400 -- Hardcoded from rads_maxupspeed
            local UpSpeed = 400 -- Hardcoded from rads_upspeed
            local wakeTime = 2.5 -- Hardcoded from rads_waketime
            
            -- Prevent get up if traveling at high speed (500-600 units/second)
            if ragdollVelocity >= 500 and ply.gettingUp then
                ply.gettingUp = false
                ply.upValue = 0
                ply.lastGetUpAttempt = CurTime()
                ply:ChatPrint("You're moving too fast to get up safely!")
                return
            end


            
            -- Height-based automatic get up for airborne ragdolls that are already getting up
            if ply.gettingUp then
                -- Check if ragdoll is airborne by tracing downward
                local traceData = {
                    start = rag:GetPos(),
                    endpos = rag:GetPos() + Vector(0, 0, -200), -- Trace 200 units down
                    filter = rag
                }
                local trace = util.TraceLine(traceData)
                local heightAboveGround = rag:GetPos().z - trace.HitPos.z
                
                -- If ragdoll is high enough above ground (120+ units) and already getting up, auto-complete get up
                if heightAboveGround >= 120 then
                    rads(ply)
                    ply.gettingUp = false
                    ply.upValue = 0
                    ply.lastGetUpAttempt = CurTime()
                    return -- Exit early since we completed the get up
                end
            end
            
            -- Improved interruption logic - less sensitive to damage
            if ragdollVelocity > 300 then -- Increased threshold from 200 to 300
                ply.gettingUp = false
                ply.upValue = 0
                ply.lastGetUpAttempt = CurTime()
                -- Remove takingDamage interruption entirely
            -- REMOVED: Automatic get up triggering based on time and velocity
            -- elseif not ply.gettingUp and CurTime() - ply.lastGetUpAttempt >= wakeTime and not ply.brokenspine and not ply.Otrub then
            --     -- Only start getting up if ragdoll is relatively still and enough time has passed
            --     if ragdollVelocity < 60 then -- Reduced threshold from 80 to 60 for faster response
            --         ply.gettingUp = true
            --         ply.upValue = 0
            --     end
            end

            -- KEEP: Manual get up physics (triggered by rads_ragdolize command)
            if ply.gettingUp then
                -- Check for failure conditions during get up process
                local shouldFailGetUp = false
                local failureReason = ""
                
                -- Check if player becomes unconscious during get up
                if ply.Otrub then
                    shouldFailGetUp = true
                    failureReason = "You lost consciousness while trying to get up."
                end
                
                -- Check if player gets concussion during get up
                if ply.concussionActive then
                    shouldFailGetUp = true
                    failureReason = "The concussion makes it impossible to get up."
                end
                
                -- If failure conditions are met, interrupt the get up process
                if shouldFailGetUp then
                    ply.gettingUp = false
                    ply.upValue = 0
                    ply.lastGetUpAttempt = CurTime()
                    ply:ChatPrint(failureReason)
                    return -- Exit early to prevent further get up physics
                end
                
                if ply.upValue < MaxUp then
                    ply.upValue = math.Approach(ply.upValue, MaxUp, FrameTime() * UpSpeed)
                    -- Enhanced getting up physics - stronger and more coordinated
                    local spine = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine")))
                    local pelvis = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Pelvis")))
                    local chest = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone("ValveBiped.Bip01_Spine2")))
                    
                    -- Apply stronger force to multiple body parts for better body raising
                    if IsValid(head) then
                        head:ApplyForceCenter(Vector(0, 0, 1) * ply.upValue * 0.5) -- Increased from 0.4 to 0.5
                    end
                    if IsValid(chest) then
                        chest:ApplyForceCenter(Vector(0, 0, 1) * ply.upValue * 0.6) -- New chest force for better torso lifting
                    end
                    if IsValid(spine) then
                        spine:ApplyForceCenter(Vector(0, 0, 1) * ply.upValue * 0.5) -- Increased from 0.4 to 0.5
                    end
                    if IsValid(pelvis) then
                        pelvis:ApplyForceCenter(Vector(0, 0, 1) * ply.upValue * 0.3) -- Increased from 0.2 to 0.3
                    end
                    
                    -- Add slight forward momentum to help with getting up motion
                    local forward = rag:GetForward()
                    if IsValid(pelvis) then
                        pelvis:ApplyForceCenter(forward * ply.upValue * 0.1)
                    end
                else
                    -- Ragdoll is fully up, restore player
                    rads(ply)
                    ply.gettingUp = false
                    ply.upValue = 0
                    ply.lastGetUpAttempt = CurTime()
                end
            end
        end
    end)

    util.AddNetworkString('CapturePositionRH')
    util.AddNetworkString('CapturePositionLH')
    hook.Add("Player Think", "Pulse", function(ply, curTime)
        if not ply.pulse and ply:Alive() then ply.pulse = 70 end
        local rag = ply:GetNWEntity('player_ragdoll')
        local lastPulseChange = ply.lastPulseChange or 0
        if curTime - lastPulseChange >= 2 then
            local change = math.random(-7, 7)
            if ply.pulse >= 130 then
                ply.pulse = math.max(ply.pulse - math.random(3, 5), 0)
                ply:SetNWBool("radshighpulse", true)
            elseif ply.pulse <= 50 and ply:Alive() then
                ply.pulse = math.min(ply.pulse + math.random(10, 20), 100)
                ply:SetNWBool("radshighpulse", false)
            end

            if not ply:Alive() then ply.pulse = 0 end
            if ply.pulse >= 55 and ply.pulse <= 129 then ply:SetNWBool("radshighpulse", false) end
            ply.pulse = ply.pulse + change
            rag.pulse = ply.pulse
            -- FIXED: Network the pulse value to clients
            ply:SetNWInt("PlayerPulse", ply.pulse)
            ply.lastPulseChange = curTime
        end
    end)

    -- Utility function to apply heavy fall effects (sound, organ damage, pain)
    local function RADS_HeavyFallEffect(ent, impactPos)
        if not IsValid(ent) then return end
        -- Play random heavy fall sound
        local sounds = {"fallheavy1.wav", "fallheavy2.wav", "fallheavy3.wav", "fallheavy4.wav"}
        local snd = sounds[math.random(1, #sounds)]
        ent:EmitSound(snd, 80, 100, 1, CHAN_AUTO)

        -- Get the player (for ragdoll, get owner)
        local ply = ent
        if ent:IsRagdoll() and ent:GetNWEntity("owner") and ent:GetNWEntity("owner"):IsPlayer() then
            ply = ent:GetNWEntity("owner")
        end
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if not ply.Organs then return end

        -- Damage all inner organs except brain and arteries, but including skull
        local ignore_organs = {
            brain = true,
            artery = true,
            radial_artery_l = true,
            radial_artery_r = true,
            femoral_artery_l = true,
            femoral_artery_r = true,
            popliteal_artery_l = true,
            popliteal_artery_r = true
        }
        for organ, _ in pairs(ply.Organs) do
            if not ignore_organs[organ] then
                -- Damage: set to 0 or reduce by a large amount (here, set to 0 for dramatic effect)
                if organ == "skull" then
                    ply.Organs[organ] = math.max(ply.Organs[organ] - 15, 0) -- skull: not instant break
                else
                    ply.Organs[organ] = math.max(ply.Organs[organ] - 999, 0)
                end
            end
        end
        -- Add moderate pain (reduced from 800)
        ply.pain = (ply.pain or 0) + 160
    end

    -- Utility function for extreme fall: smash all organs, kill, loud sound
    local function RADS_DeathFallEffect(ent, impactPos)
        if not IsValid(ent) then return end
        -- Play random heavy fall sound, louder
        local sounds = {"fallheavy1.wav", "fallheavy2.wav", "fallheavy3.wav", "fallheavy4.wav"}
        local snd = sounds[math.random(1, #sounds)]
        ent:EmitSound(snd, 120, 100, 1, CHAN_AUTO)

        -- Get the player (for ragdoll, get owner)
        local ply = ent
        if ent:IsRagdoll() and ent:GetNWEntity("owner") and ent:GetNWEntity("owner"):IsPlayer() then
            ply = ent:GetNWEntity("owner")
        end
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if not ply.Organs then return end

        -- Smash all organs
        for organ, _ in pairs(ply.Organs) do
            ply.Organs[organ] = 0
        end
        ply.pain = (ply.pain or 0) + 400
        -- Kill the player if possible
        if ply:Alive() then ply:Kill() end
    end

    -- Extend OnPlayerHitGround for heavy and death fall logic
    hook.Add("OnPlayerHitGround", "RADS_HeavyFallImpact", function(ply, a, b, speed)
        -- Increased thresholds for more realistic fall damage
        local velocityThreshold = GetConVar("rads_fallonspeedlimit_threshold"):GetInt()
        if speed >= velocityThreshold then -- Use ConVar for death fall threshold
            local impactPos = ply:GetPos()
            RADS_DeathFallEffect(ply, impactPos)
        elseif speed >= 800 then -- Increased from 500 for heavy fall
            local impactPos = ply:GetPos()
            RADS_HeavyFallEffect(ply, impactPos)
        end
        
        -- Velocity-based pain for broken/dislocated legs on ground impact
        if speed >= 200 then -- Only apply pain for significant impacts
            local hasLegInjury = false
            local painMultiplier = 1.0
            
            -- Check for broken legs (higher pain multiplier)
            if ply:GetNWBool("RADS_LeftLegBroken") or ply:GetNWBool("RADS_RightLegBroken") then
                hasLegInjury = true
                painMultiplier = painMultiplier + 2.0 -- 3x pain for broken legs
            end
            
            -- Check for dislocated legs (moderate pain multiplier)
            if ply:GetNWBool("RADS_LeftLegDislocated") or ply:GetNWBool("RADS_RightLegDislocated") then
                hasLegInjury = true
                painMultiplier = painMultiplier + 1.0 -- 2x pain for dislocated legs
            end
            
            -- Apply velocity-based pain if leg injuries are present
            if hasLegInjury then
                -- Calculate pain based on impact velocity
                -- Speed ranges from 200 (minimum) to 1200+ (maximum)
                local velocityFactor = math.Clamp((speed - 200) / 1000, 0, 1) -- Normalize to 0-1 range
                local basePain = 5 + (velocityFactor * 25) -- 5-30 base pain
                local finalPain = basePain * painMultiplier
                
                -- Apply realistic pain system for impact on injured legs
                local damageIntensity = finalPain
                
                -- Check for severe impact pain (instant pain threshold)
                if finalPain >= 40 or speed >= 800 then
                    -- Severe impact: instant pain + pain debt
                    local instantPain = finalPain * 0.6 -- 60% instant for severe impact
                    local painDebt = finalPain * 0.4 -- 40% debt
                    
                    ply.pain = (ply.pain or 0) + instantPain
                    ply.painDebt = (ply.painDebt or 0) + painDebt
                    ply.lastDamageTime = CurTime()
                    ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    
                    ply:ChatPrint("The impact on your injured legs causes agonizing pain!")
                elseif finalPain >= 20 then
                    -- Moderate impact: balanced pain
                    local instantPain = finalPain * 0.3 -- 30% instant
                    local painDebt = finalPain * 0.7 -- 70% debt
                    
                    ply.pain = (ply.pain or 0) + instantPain
                    ply.painDebt = (ply.painDebt or 0) + painDebt
                    ply.lastDamageTime = CurTime()
                    ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    
                    ply:ChatPrint("Landing hard on your injured legs hurts terribly.")
                elseif finalPain >= 10 then
                    -- Minor impact: mostly pain debt
                    local instantPain = finalPain * 0.15 -- 15% instant
                    local painDebt = finalPain * 0.85 -- 85% debt
                    
                    ply.pain = (ply.pain or 0) + instantPain
                    ply.painDebt = (ply.painDebt or 0) + painDebt
                    ply.lastDamageTime = CurTime()
                    ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    
                    ply:ChatPrint("The impact aggravates your leg injuries.")
                else
                    -- Light impact: almost all pain debt
                    local instantPain = finalPain * 0.1 -- 10% instant
                    local painDebt = finalPain * 0.9 -- 90% debt
                    
                    ply.pain = (ply.pain or 0) + instantPain
                    ply.painDebt = (ply.painDebt or 0) + painDebt
                    ply.lastDamageTime = CurTime()
                    ply.damageIntensity = (ply.damageIntensity or 0) + damageIntensity
                    
                    ply:ChatPrint("Your injured legs ache from the impact.")
                end
            end
        end
    end)

    -- Add PhysicsCollide callback for ragdolls to detect heavy and death ground impacts
    hook.Add("OnEntityCreated", "RADS_RagdollHeavyFall", function(ent)
        if not ent:IsRagdoll() then return end
        -- Only add once
        if ent._radsHeavyFallPhysicsCollide then return end
        ent._radsHeavyFallPhysicsCollide = true
        ent:AddCallback("PhysicsCollide", function(ragdoll, data)
            -- Check for diving landing (any ground impact while diving)
            if ragdoll.isDiving and data.HitNormal.z > 0.5 then
                -- End diving state when ragdoll hits ground
                ragdoll.isDiving = false
            end
            
            -- Only care about ground impacts (normal.z > 0.7)
            local now = CurTime()
            -- Increased thresholds for ragdoll impacts
            if data.Speed >= 1300 and data.HitNormal.z > 0.7 then -- Increased from 950
                if not ragdoll._lastDeathFallTime or now - ragdoll._lastDeathFallTime > 1 then
                    ragdoll._lastDeathFallTime = now
                    RADS_DeathFallEffect(ragdoll, data.HitPos)
                end
            elseif data.Speed >= 750 and data.HitNormal.z > 0.7 then -- Increased from 450
                if not ragdoll._lastHeavyFallTime or now - ragdoll._lastHeavyFallTime > 1 then
                    ragdoll._lastHeavyFallTime = now
                    RADS_HeavyFallEffect(ragdoll, data.HitPos)
                end
            end
        end)
    end)

    -- Utility: Apply realistic body relaxation (gradual rigor mortis release)
    function ApplyRigorMortis(rag)
        if not IsValid(rag) then return end
        
        -- Initial pose: arms and legs extended, head tilted back (mimicking immediate post-mortem state)
        local poseBones = {
            {"ValveBiped.Bip01_L_UpperArm", Angle(0, 0, -80)},
            {"ValveBiped.Bip01_R_UpperArm", Angle(0, 0, 80)},
            {"ValveBiped.Bip01_L_Forearm", Angle(0, 0, -40)},
            {"ValveBiped.Bip01_R_Forearm", Angle(0, 0, 40)},
            {"ValveBiped.Bip01_L_Thigh", Angle(0, 0, -30)},
            {"ValveBiped.Bip01_R_Thigh", Angle(0, 0, 30)},
            {"ValveBiped.Bip01_L_Calf", Angle(0, 0, 0)},
            {"ValveBiped.Bip01_R_Calf", Angle(0, 0, 0)},
            {"ValveBiped.Bip01_Head1", Angle(-60, 0, 0)}
        }
        
        -- Apply initial pose
        for _, v in ipairs(poseBones) do
            local bone = rag:LookupBone(v[1])
            if bone then
                rag:ManipulateBoneAngles(bone, v[2])
            end
        end
        
        -- Create strong initial welds (rigor mortis)
        local pelvis = rag:LookupBone("ValveBiped.Bip01_Pelvis")
        rag._rigorWelds = {}
        rag._rigorStrength = {} -- Store strength values separately
        rag._rigorStartTime = CurTime()
        
        local function createGradualWeld(boneName, initialStrength)
            local bone = rag:LookupBone(boneName)
            if bone and pelvis then
                local phys1 = rag:TranslateBoneToPhysBone(bone)
                local phys2 = rag:TranslateBoneToPhysBone(pelvis)
                if phys1 and phys2 and phys1 ~= phys2 then
                    -- Create weld with initial strength
                    local cons = constraint.Weld(rag, rag, phys1, phys2, initialStrength, true, false)
                    if cons then
                        table.insert(rag._rigorWelds, cons)
                        rag._rigorStrength[cons] = initialStrength -- Store strength separately
                    end
                end
            end
        end
        
        -- Create initial welds (much reduced strength for less stiffness)
        createGradualWeld("ValveBiped.Bip01_L_UpperArm", 2500)
        createGradualWeld("ValveBiped.Bip01_R_UpperArm", 2500)
        createGradualWeld("ValveBiped.Bip01_L_Thigh", 2500)
        createGradualWeld("ValveBiped.Bip01_R_Thigh", 2500)
        
        -- Less stiff rigor mortis: shorter stiff period, faster relaxation
        local stiffDuration = math.Rand(1.5, 3) -- Reduced initial stiffness period
        local relaxDuration = math.Rand(4, 8) -- Faster relaxation period
        local totalDuration = stiffDuration + relaxDuration
        
        -- Keep initial strong welds for stiff period, then relax quickly
        timer.Simple(stiffDuration, function()
            if not IsValid(rag) then return end
            
            -- Quick relaxation steps over the relaxDuration
            local relaxationSteps = 8
            local stepInterval = relaxDuration / relaxationSteps
            
            for step = 1, relaxationSteps do
                timer.Simple(step * stepInterval, function()
                    if not IsValid(rag) then return end
                    
                    -- Rapidly reduce weld strength
                    if rag._rigorWelds and rag._rigorStrength then
                        for _, cons in ipairs(rag._rigorWelds) do
                            if IsValid(cons) and rag._rigorStrength[cons] then
                                -- Sharp drop in strength for realistic relaxation
                                local progress = step / relaxationSteps
                                local initialStrength = rag._rigorStrength[cons]
                                local remainingStrength = initialStrength * math.pow(1 - progress, 2) -- Exponential decay
                                
                                -- Update weld strength with faster decay
                                cons:SetTable({
                                    forcelimit = math.max(50, remainingStrength),
                                    torquelimit = math.max(25, remainingStrength * 0.3)
                                })
                            end
                        end
                    end
                    
                    -- Faster bone relaxation with natural variation
                    local boneProgress = math.pow(step / relaxationSteps, 1.5) -- Accelerated return
                    for _, v in ipairs(poseBones) do
                        local bone = rag:LookupBone(v[1])
                        if bone then
                            local targetAngle = Angle(
                                math.Rand(-5, 5), -- Natural variation
                                math.Rand(-5, 5), 
                                math.Rand(-5, 5)
                            )
                            local currentAngle = rag:GetManipulateBoneAngles(bone)
                            local relaxedAngle = LerpAngle(boneProgress, currentAngle, targetAngle)
                            rag:ManipulateBoneAngles(bone, relaxedAngle)
                        end
                    end
                end)
            end
        end)
        
        -- Final cleanup after relaxation is complete
        timer.Simple(totalDuration + 0.5, function()
            if not IsValid(rag) then return end
            
            -- Remove all remaining welds
            if rag._rigorWelds then
                for _, cons in ipairs(rag._rigorWelds) do
                    if IsValid(cons) then cons:Remove() end
                end
                rag._rigorWelds = nil
            end
            
            if rag._rigorStrength then
                rag._rigorStrength = nil
            end
            
            -- Ensure final relaxed pose with natural variation
            for _, v in ipairs(poseBones) do
                local bone = rag:LookupBone(v[1])
                if bone then
                    rag:ManipulateBoneAngles(bone, Angle(
                        math.Rand(-2, 2),
                        math.Rand(-2, 2), 
                        math.Rand(-2, 2)
                    ))
                end
            end
        end)
    end
end

if CLIENT then
    surface.CreateFont("ScFont", {
        font = "Coolvetica",
        size = 24,
        weight = 1100,
        outline = false
    })

    lastView = nil
    local organData = {}
    
    -- Enhanced debug display system
    surface.CreateFont("RADS_DebugTitle", {
        font = "Coolvetica",
        size = 18,
        weight = 600,
        outline = true
    })
    
    surface.CreateFont("RADS_DebugText", {
        font = "Coolvetica",
        size = 14,
        weight = 500,
        outline = true
    })
    
    surface.CreateFont("RADS_DebugValue", {
        font = "Coolvetica",
        size = 13,
        weight = 400,
        outline = true
    })
    
    local function GetHealthColor(percentage)
        if percentage >= 75 then return Color(46, 204, 113) end -- Green
        if percentage >= 50 then return Color(241, 196, 15) end -- Yellow
        if percentage >= 25 then return Color(230, 126, 34) end -- Orange
        return Color(231, 76, 60) -- Red
    end
    
    local function DrawEnhancedDebugDisplay()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local scrW, scrH = ScrW(), ScrH()
        local panelW, panelH = 280, 380
        local x, y = scrW - panelW - 20, 20
        
        -- Semi-transparent background
        draw.RoundedBox(8, x, y, panelW, panelH, Color(0, 0, 0, 180))
        draw.RoundedBox(8, x + 2, y + 2, panelW - 4, panelH - 4, Color(20, 20, 20, 120))
        
        -- Title
        draw.SimpleText("TRAUMA DEBUG", "RADS_DebugTitle", x + panelW/2, y + 15, Color(255, 255, 255), TEXT_ALIGN_CENTER)
        
        local yOffset = 45
        local lineHeight = 18
        
        -- Player Health
        local health = ply:Health()
        local healthColor = GetHealthColor(health)
        draw.SimpleText("Health:", "RADS_DebugText", x + 15, y + yOffset, Color(200, 200, 200))
        draw.SimpleText(health .. "/100", "RADS_DebugValue", x + panelW - 15, y + yOffset, healthColor, TEXT_ALIGN_RIGHT)
        yOffset = yOffset + lineHeight
        
        -- Blood Level (using RADS_ClientData or networked variable as fallback)
        local blood = (RADS_ClientData and RADS_ClientData.blood) or ply:GetNWInt("PlayerBlood", 5000)
        local bloodPercentage = math.Clamp((blood / 5000) * 100, 0, 100)
        local bloodColor = GetHealthColor(bloodPercentage)
        draw.SimpleText("Blood:", "RADS_DebugText", x + 15, y + yOffset, Color(200, 200, 200))
        draw.SimpleText(blood .. "ml", "RADS_DebugValue", x + panelW - 15, y + yOffset, bloodColor, TEXT_ALIGN_RIGHT)
        yOffset = yOffset + lineHeight
        
        -- Pain Level (using RADS_ClientData)
        local pain = (RADS_ClientData and RADS_ClientData.pain) or 0
        local painLimitConVar = GetConVar("rads_painlimit")
        local painLimit = painLimitConVar and painLimitConVar:GetInt() or 190
        local painColor = pain > 150 and Color(231, 76, 60) or (pain > 100 and Color(230, 126, 34) or Color(46, 204, 113))
        draw.SimpleText("Pain:", "RADS_DebugText", x + 15, y + yOffset, Color(200, 200, 200))
        draw.SimpleText(pain .. "/" .. painLimit, "RADS_DebugValue", x + panelW - 15, y + yOffset, painColor, TEXT_ALIGN_RIGHT)
        yOffset = yOffset + lineHeight
        
        -- Shock Level (using correct networked variable)
        local shock = ply:GetNWFloat("RADS_Shock", 0)
        local shockColor = shock > 60 and Color(231, 76, 60) or (shock > 30 and Color(230, 126, 34) or Color(46, 204, 113))
        draw.SimpleText("Shock:", "RADS_DebugText", x + 15, y + yOffset, Color(200, 200, 200))
        draw.SimpleText(math.floor(shock) .. "/100", "RADS_DebugValue", x + panelW - 15, y + yOffset, shockColor, TEXT_ALIGN_RIGHT)
        yOffset = yOffset + lineHeight
        
        -- Pulse Rate (using correct networked variable)
        local pulse = ply:GetNWInt("PlayerPulse", 70)
        local pulseColor = (pulse > 120 or pulse < 50) and Color(231, 76, 60) or Color(46, 204, 113)
        draw.SimpleText("Pulse:", "RADS_DebugText", x + 15, y + yOffset, Color(200, 200, 200))
        draw.SimpleText(pulse .. " BPM", "RADS_DebugValue", x + panelW - 15, y + yOffset, pulseColor, TEXT_ALIGN_RIGHT)
        yOffset = yOffset + lineHeight
        
        -- Consciousness Status (using correct networked variable)
        local isUnconscious = ply:GetNWBool("Otrub", false)
        local consciousnessColor = isUnconscious and Color(231, 76, 60) or Color(46, 204, 113)
        draw.SimpleText("Consciousness:", "RADS_DebugText", x + 15, y + yOffset, Color(200, 200, 200))
        draw.SimpleText(isUnconscious and "Unconscious" or "Conscious", "RADS_DebugValue", x + panelW - 15, y + yOffset, consciousnessColor, TEXT_ALIGN_RIGHT)
        yOffset = yOffset + lineHeight
        
        -- Breathing Status (calculated from lung health)
        local leftLungHealth = (ply.Organs and ply.Organs['left_lung']) or 5
        local rightLungHealth = (ply.Organs and ply.Organs['right_lung']) or 5
        local isBreathing = leftLungHealth > 0 or rightLungHealth > 0
        local breathColor = isBreathing and Color(46, 204, 113) or Color(231, 76, 60)
        draw.SimpleText("Breathing:", "RADS_DebugText", x + 15, y + yOffset, Color(200, 200, 200))
        draw.SimpleText(isBreathing and "Normal" or "Not Breathing", "RADS_DebugValue", x + panelW - 15, y + yOffset, breathColor, TEXT_ALIGN_RIGHT)
        yOffset = yOffset + lineHeight + 10
        
        -- Organ Health Section
        draw.SimpleText("ORGAN HEALTH", "RADS_DebugText", x + 15, y + yOffset, Color(255, 255, 255))
        yOffset = yOffset + lineHeight + 5
        
        -- Organ maximum health values
        local maxHealth = {
            ["liver"] = 15,
            ["stomach"] = 15,
            ["intestines"] = 30,
            ["heart"] = 9,
            ["left_lung"] = 5,
            ["right_lung"] = 5
        }
        
        -- Display organ data if available
        local organsToDisplay = (RADS_ClientData and RADS_ClientData.organs) or (organData and organData.organs)
        if organsToDisplay and next(organsToDisplay) ~= nil then
            for organ, health in pairs(organsToDisplay) do
                local maxHP = maxHealth[organ] or 10
                local organPercentage = math.Clamp((health / maxHP) * 100, 0, 100)
                local organColor = GetHealthColor(organPercentage)
                local organName = string.gsub(organ, "_", " ")
                organName = string.upper(string.sub(organName, 1, 1)) .. string.sub(organName, 2)
                
                draw.SimpleText(organName .. ":", "RADS_DebugValue", x + 25, y + yOffset, Color(180, 180, 180))
                draw.SimpleText(math.floor(organPercentage) .. "%", "RADS_DebugValue", x + panelW - 15, y + yOffset, organColor, TEXT_ALIGN_RIGHT)
                yOffset = yOffset + 15
            end
        else
            draw.SimpleText("No organ data available", "RADS_DebugValue", x + 25, y + yOffset, Color(150, 150, 150))
        end
    end
    
    net.Receive("info_org", function()
        organData = net.ReadTable()
    end)
    
    -- Timer to request organism_info data periodically
    timer.Create("RADS_RequestOrganismInfo", 1, 0, function()
        local drawOrgConVar = GetConVar('rads_draworg')
        if drawOrgConVar and drawOrgConVar:GetBool() and IsValid(LocalPlayer()) then
            net.Start("request_organism_info")
            net.SendToServer()
        end
    end)
    
    hook.Add("HUDPaint", "DrawEnhancedDebugDisplay", function() 
        local drawOrgConVar = GetConVar('rads_draworg')
        if drawOrgConVar and drawOrgConVar:GetBool() then 
            DrawEnhancedDebugDisplay() 
        end 
    end)
    CreateClientConVar("rads_draworg", "0", {FCVAR_ARCHIVE, ""})
    CreateClientConVar("rads_thirdperson", "0", {FCVAR_ARCHIVE, "Thirdperson"})
    -- Server-side admin-only viewmode command
    if SERVER then
        CreateConVar("rads_viewmode", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "0 means view from eyes but with movement,1 means from eyes without movement - Admin only")
        
        concommand.Add("rads_viewmode", function(ply, cmd, args)
            if not IsValid(ply) or not ply:IsAdmin() then
                if IsValid(ply) then
                    ply:ChatPrint("[RADS] Only admins can change the view mode for all players.")
                end
                return
            end
            
            if not args[1] then
                ply:ChatPrint("[RADS] Usage: rads_viewmode <0|1>")
                return
            end
            
            local newMode = tonumber(args[1])
            if newMode ~= 0 and newMode ~= 1 then
                ply:ChatPrint("[RADS] Invalid mode. Use 0 or 1.")
                return
            end
            
            GetConVar("rads_viewmode"):SetInt(newMode)
            
            local modeText = newMode == 0 and "free camera movement" or "locked to ragdoll eyes"
            for _, p in pairs(player.GetAll()) do
                p:ChatPrint("[RADS] Admin " .. ply:Name() .. " changed view mode to: " .. modeText)
            end
        end)
    else
        -- Client-side: Get viewmode from server convar
        function GetViewMode()
            local serverCvar = GetConVar("rads_viewmode")
            return serverCvar and serverCvar:GetInt() or 1
        end
    end

    CreateClientConVar("rads_mouthscale", "6", {FCVAR_ARCHIVE, "Mouth Scale while speaking"})
    CreateClientConVar("rads_viewfov", "100", {FCVAR_ARCHIVE, "Fov in ragdoll."})
    CreateClientConVar("rads_disablelerp", "0", {FCVAR_ARCHIVE, ""})
    CreateClientConVar("rads_drawmotd", "1", {FCVAR_ARCHIVE, "Draw motd"})
    
    -- Key binding for handcuff removal
    hook.Add("PlayerButtonDown", "RADS_HandcuffRemoval", function(ply, button)
        if button == KEY_H and input.IsKeyDown(KEY_LALT) then
            RunConsoleCommand("rads_remove_handcuffs")
        end
    end)


    -- Simple ragdoll color sync from server
    net.Receive(
        "ragplayercolor",
        function()
            local ent = net.ReadEntity()
            local col = net.ReadVector()
            if IsValid(ent) and isvector(col) then
                function ent:GetPlayerColor()
                    return col
                end
            end
        end
    )

    local helmEnt
    net.Receive("nodraw_helmet", function() helmEnt = net.ReadEntity() end)
    if IsValid(helmEnt) then
        helmEnt:SetNoDraw(true)
        helmEnt:SetColor(Color(0, 0, 0, 0))
        helmEnt:SetRenderMode(RENDERMODE_TRANSCOLOR)
    end

    hook.Add("Think", "mouthanim", function()
        for i, ply in pairs(player.GetAll()) do
            local ent = IsValid(ply:GetNWEntity("player_ragdoll")) and ply:GetNWEntity("player_ragdoll") or ply
            local flexes = {ent:GetFlexIDByName("jaw_drop"), ent:GetFlexIDByName("left_part"), ent:GetFlexIDByName("right_part"), ent:GetFlexIDByName("left_mouth_drop"), ent:GetFlexIDByName("right_mouth_drop")}
            local volume = ply:VoiceVolume()
            local weight = math.Clamp(volume * 75, 0, 1.5) or 0  -- Further reduced from 150 to 75, and max from 3 to 1.5
            if ply:IsSpeaking() then
                for k, v in pairs(flexes) do
                    ent:SetFlexWeight(v, weight)
                end
            end
        end
    end)
    local oldFakeOrigin = Vector(0, 0, 0)
    local oldFakeAng = Angle(0, 0, 0)
    local oldOrigin = Vector(0, 0, 0)
    local oldAng = Angle(0, 0, 0)
    local lerping = 1
    local MyLerp = 0
    function HomigradCam(ply, vec, ang, fov, znear, zfar)
        local eye = ply:GetAttachment(ply:LookupAttachment("eyes"))
        local org = eye.Pos
        local ang1 = LerpAngle(0, ply:EyeAngles(), eye.Ang)
        local org1 = eye.Pos + eye.Ang:Up() * 2 + eye.Ang:Forward() * 2.5
        if ply:GetNWBool("radsfa") == true and IsValid(ply:GetNWEntity("player_ragdoll")) then
            local attach = ply:GetNWEntity("player_ragdoll"):GetAttachment(1)
            local headBoneIndex = ply:GetNWEntity("player_ragdoll"):LookupBone("ValveBiped.Bip01_Head1")
            
            -- Only hide head if not already exploded by gore system
            if not ply:GetNWEntity("player_ragdoll").goreHeadExploded then
                ply:GetNWEntity("player_ragdoll"):ManipulateBoneScale(headBoneIndex, Vector(0, 0, 0))
            end
            lerping = Lerp(3 * FrameTime(), lerping, 0)
            local view = {
                origin = LerpVector(lerping, attach.Pos, oldOrigin),
                angles = LerpAngle(lerping, LerpAngle(0.35, ang1, attach.Ang), oldAng),
                fov = fov,
                drawviewer = true
            }

            oldFakeOrigin = view.origin
            oldFakeAng = view.angles
            return view
        end

        if ply:InVehicle() == true then
            -- org = eye.Pos + eye.Ang:Forward() * 0.8
            ang = eye.Ang
            MyLerp = 1
            ply:ManipulateBoneScale(ply:LookupBone("ValveBiped.Bip01_Head1"), vector_origin)
            anglerp = LerpAngle(MyLerp, ang1, ang)
        else
            -- Restore head visibility when not in vehicle (unless head exploded)
            local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
            if headBone and not ply.headExploded then
                ply:ManipulateBoneScale(headBone, Vector(1, 1, 1))
            end
            anglerp = LerpAngle(MyLerp / 2, ang1, sightAng or Angle(0, 0, 0))
        end

        lerping = Lerp(3 * FrameTime(), lerping, 1)
        local view = {
            origin = LerpVector(lerping, oldFakeOrigin, LerpVector(MyLerp, org1, org)),
            angles = LerpAngle(lerping, oldFakeAng, LerpAngle(0.01, anglerp, ang1)),
            fov = fov,
            drawviewer = true,
            -- znear = 0.2
        }

        oldOrigin = view.origin
        oldAng = view.angles
        return view
    end

    function RadsMM(ply, origin, angles, fov)
        local rag = ply:GetNWEntity("player_ragdoll")
        if IsValid(rag) then
            local att = rag:GetAttachment(rag:LookupAttachment("eyes"))
            if att then
                local view = {}
                local v = angles
                if lastView == nil then
                    lastView = {
                        origin = att.Pos,
                        angles = att.Ang,
                        fov = fov
                    }
                end

                local lerpedAngles = LerpAngle(0.8, lastView.angles, att.Ang)
                local lerpedang = LerpAngle(0.8, lastView.angles, v)
                
                if GetViewMode() == 1 then
                    -- Mode 1: Camera locked to ragdoll eyes (original behavior)
                    view.origin = att.Pos
                    view.angles = lerpedAngles
                else
                    -- Mode 0: Camera at ragdoll eyes but allows mouse movement
                    if GetConVar("rads_disablelerp"):GetInt() == 1 then
                        view.origin = att.Pos
                        view.angles = Angle(lerpedang.p, lerpedang.y, 0)
                    else
                        view.origin = att.Pos
                        view.angles = lerpedang
                    end
                end

                view.znear = 1
                view.fov = fov
                view.drawviewer = true
                lastView = {
                    origin = view.origin,
                    angles = view.angles,
                    fov = fov
                }
                return view
            end
        end
    end

    net.Receive("REMOVECALC", function(ply) hook.Remove('CalcView', 'govnishe') end)
    net.Receive('ADDCALC', function(ply) 
    -- hook.Add("CalcView", "govnishe", RadsMM) 
    -- hook.Add("CalcView", "govnishe", HomigradCam) 
    end)

    hook.Add("CalcView", "RADS.ForceFirstPerson", function(ply, origin, angles, fov)
        -- Handle ragdoll first-person view
        if ply:GetNWBool("radsfa") == true and IsValid(ply:GetNWEntity("player_ragdoll")) then
            local rag = ply:GetNWEntity("player_ragdoll")
            local attachIndex = rag:LookupAttachment("eyes")
            local att = attachIndex and rag:GetAttachment(attachIndex)
            local camPos = att and att.Pos or rag:GetPos()
            -- Clamp camera distance to ragdoll origin (prevents flying away)
            if (camPos - rag:GetPos()):Length() > 50 then
                camPos = rag:GetPos()
            end
            
            local finalAngles
            if GetViewMode() == 0 then
                -- Free camera movement - use player's current view angles
                finalAngles = angles
            else
                -- Locked camera - use ragdoll's eye angles (default behavior)
                finalAngles = att and att.Ang or rag:GetAngles()
            end
            
            -- Apply tinnitus screenshake for ragdolls
            if (tinnitusRagdollActive and CurTime() < tinnitusRagdollEndTime) or tinnitusFadeOutActive then
                local currentShakeStrength
                
                if tinnitusFadeOutActive then
                    -- During fade-out, use fade multiplier to gradually reduce shake to 0
                    local elapsed = CurTime() - tinnitusFadeOutStartTime
                    local progress = math.Clamp(elapsed / tinnitusFadeOutDuration, 0, 1)
                    local fadeMultiplier = 1 - progress
                    currentShakeStrength = tinnitusRagdollShakeStrength * fadeMultiplier
                    
                    -- Check if fade-out is complete
                    if progress >= 1 then
                        tinnitusFadeOutActive = false
                        tinnitusRagdollActive = false
                    end
                else
                    -- During normal tinnitus, gradually reduce shake strength over the duration
                    local elapsed = CurTime() - tinnitusRagdollStartTime
                    local totalDuration = tinnitusRagdollEndTime - tinnitusRagdollStartTime
                    local progress = math.Clamp(elapsed / totalDuration, 0, 1)
                    currentShakeStrength = tinnitusRagdollShakeStrength * (1 - progress * 0.7) -- Reduce to 30% by the end
                    
                    -- Check if duration ended, start fade-out
                    if CurTime() >= tinnitusRagdollEndTime then
                        tinnitusFadeOutActive = true
                        tinnitusFadeOutStartTime = CurTime()
                    end
                end
                
                -- Apply continuous shake with varying frequency (same as damage.lua)
                local t = CurTime()
                local tinnitusShake = Angle(
                    math.sin(t * 8) * currentShakeStrength,
                    math.cos(t * 8 * 0.8) * currentShakeStrength,
                    math.sin(t * 8 * 0.6) * currentShakeStrength * 0.5
                )
                finalAngles = finalAngles + tinnitusShake
            end
            
            return {
                origin = camPos,
                angles = finalAngles,
                fov = GetConVar("rads_ragdoll_fov"):GetFloat(),
                drawviewer = true
            }
        end
        
        -- Handle death first-person view
        local deathFirstPersonCvar = GetConVar("rads_death_firstperson")
        if deathFirstPersonCvar and deathFirstPersonCvar:GetBool() and ply:GetNWBool("rads_dead_firstperson") and not ply:Alive() then
            -- Keep the camera at the death position in first-person
            return {
                origin = origin,
                angles = angles,
                fov = fov,
                drawviewer = false
            }
        end
        
        return nil
    end)

    scrw, scrh = ScrW(), ScrH()
    hook.Add("RenderScreenspaceEffects", "RADS.FFAFAPFPAP", function()
        local ply = LocalPlayer()
        local rag = ply:GetNWBool('radsfa')
        local pulsehigh = ply:GetNWBool('radshighpulse')
        local thirdPersonCvar = GetConVar("rads_thirdperson")
        if rag and thirdPersonCvar and not thirdPersonCvar:GetBool() then  end
        if pulsehigh then
        end
    end)

    local grtodown = Material("vgui/gradient-u")
    local grtoup = Material("vgui/gradient-d")
    local grtoright = Material("vgui/gradient-l")
    local grtoleft = Material("vgui/gradient-r")
    pain, painlosing, impulse = 0, 0, 0
    net.Receive("info_pain", function()
        pain = net.ReadFloat()
        painlosing = net.ReadFloat()
    end)
    
    -- Tinnitus screenshake variables for ragdolls
    local tinnitusRagdollActive = false
    local tinnitusRagdollEndTime = 0
    local tinnitusRagdollStartTime = 0
    local tinnitusRagdollShakeStrength = 0
    local tinnitusFadeOutActive = false
    local tinnitusFadeOutStartTime = 0
    local tinnitusFadeOutDuration = 3 -- Same as damage.lua
    
    -- Network receiver for tinnitus screenshake state
    net.Receive("RADS_TinnitusScreenshake", function()
        local isActive = net.ReadBool()
        local duration = net.ReadFloat()
        local shakeStrength = net.ReadFloat()
        
        if isActive then
            -- Start tinnitus screenshake for ragdoll
            tinnitusRagdollActive = true
            tinnitusRagdollStartTime = CurTime()
            tinnitusRagdollEndTime = CurTime() + duration
            tinnitusRagdollShakeStrength = shakeStrength
            tinnitusFadeOutActive = false
        else
            -- Stop tinnitus screenshake for ragdoll
            tinnitusRagdollActive = false
            tinnitusRagdollEndTime = 0
            tinnitusRagdollStartTime = 0
            tinnitusRagdollShakeStrength = 0
            tinnitusFadeOutActive = false
        end
    end)

    local ScrW, ScrH = ScrW, ScrH
    local math_Clamp = math.Clamp
    local k = 0
    local k4 = 0
    local time = 0

    local icons = {}
    net.Receive("CapturePositionLH", function()
        local posLH = net.ReadVector()
        table.insert(icons, {
            pos = posLH,
            time = CurTime()
        })
    end)

    net.Receive("CapturePositionRH", function()
        local posRH = net.ReadVector()
        table.insert(icons, {
            pos = posRH,
            time = CurTime()
        })
    end)

    hook.Add("HUDPaint", "DrawIcons", function()
        if posLH ~= nil or posRH ~= nil then
            for i, icon in ipairs(icons) do
                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(Material("vgui/gmod_hand"))
                surface.DrawTexturedRect(icon.pos.x, icon.pos.y, iconWidth, iconHeight)
                if CurTime() - icon.time >= 5 then table.remove(icons, i) end
            end
        end
    end)



    local addmat_r = Material("CA/add_r")
    local addmat_g = Material("CA/add_g")
    local addmat_b = Material("CA/add_b")
    local vgbm = Material("vgui/black")
    local function DrawCA(rx, gx, bx, ry, gy, by)
        render.UpdateScreenEffectTexture()
        addmat_r:SetTexture("$basetexture", render.GetScreenEffectTexture())
        addmat_g:SetTexture("$basetexture", render.GetScreenEffectTexture())
        addmat_b:SetTexture("$basetexture", render.GetScreenEffectTexture())
        render.SetMaterial(vgbm)
        render.DrawScreenQuad()
        render.SetMaterial(addmat_r)
        render.DrawScreenQuadEx(-rx / 2, -ry / 2, ScrW() + rx, ScrH() + ry)
        render.SetMaterial(addmat_g)
        render.DrawScreenQuadEx(-gx / 2, -gy / 2, ScrW() + gx, ScrH() + gy)
        render.SetMaterial(addmat_b)
        render.DrawScreenQuadEx(-bx / 2, -by / 2, ScrW() + bx, ScrH() + by)
    end

    net.Receive("info_impulse", function() impulse = net.ReadFloat() * 50 end)
    local k3 = 0
    hook.Add("RenderScreenspaceEffects", "renderimpulse", function()
        local cheapEffectsCvar = GetConVar("rads_cheapeffects")
        local cheapEffects = cheapEffectsCvar and cheapEffectsCvar:GetInt() or 0
        
        -- Skip chromatic aberration entirely if cheapeffects >= 2
        if cheapEffects >= 2 then return end
        
        k3 = math.Clamp(Lerp(0.01, k3, impulse), 0, 50)
        
        -- Reduce intensity based on cheapeffects level
        local intensity = cheapEffects >= 1 and 0.5 or 1.0
        DrawCA(4 * k3 * intensity, 2 * k3 * intensity, 0, 2 * k3 * intensity, 1 * k3 * intensity, 0)
    end)

    net.Receive('RADS.CHATSAY', function()
        chat.AddText(Color(255, 0, 221), " ") -- end
    end)
    
    -- REMOVED: Consciousness network receiver - migrated to damage.lua
    
    -- Vision enhancement variables
    local visionSharpness = 0
    local accumulationBlur = 0
    local smoothShakeStrength = 0
    local smoothShakeSeed = math.random(1000)
    local lastShakeTime = 0
    local shakeDecay = 2.0
    
    -- Accumulation blur variables (reduced intensity)
    local blurAccumulation = 0
    local maxBlurAccumulation = 0.3  -- Reduced from 0.8 to 0.3
    local blurDecayRate = 0.03       -- Increased decay rate for faster recovery
    
    -- Add vision enhancement CalcView hook with FOV control (separate from ragdoll camera)
    hook.Add("CalcView", "RADS_VisionEnhancement", function(ply, pos, angles, fov)
        -- Only apply to alive players, not ragdolled ones
        if not ply:Alive() or ply:GetNWBool("radsfa") then return end
        
        local shake = Angle(0, 0, 0)
        
        -- Smooth screenshake based on adrenaline/stress
        if smoothShakeStrength > 0.1 then
            local t = CurTime() + smoothShakeSeed
            -- Reduced frequency multipliers for smoother shake
            shake = Angle(
                math.sin(t * 0.8) * smoothShakeStrength * 0.5,  -- Reduced from 2.5 to 0.8
                math.cos(t * 0.6) * smoothShakeStrength * 0.3,  -- Reduced from 2.2 to 0.6
                math.sin(t * 0.4) * smoothShakeStrength * 0.15  -- Reduced from 1.8 to 0.4
            )
            
            -- Smoother decay with interpolation
            smoothShakeStrength = Lerp(FrameTime() * shakeDecay * 0.5, smoothShakeStrength, 0)  -- Added 0.5 multiplier for gentler decay
        end
        
        -- Trigger shake on damage or high stress (with reduced sensitivity)
        local pulse = ply:GetNWInt("PlayerPulse", 70)
        if pulse > 120 and CurTime() - lastShakeTime > 1.0 then  -- Increased cooldown from 0.5 to 1.0
            smoothShakeStrength = math.min(smoothShakeStrength + (pulse - 120) * 0.01, 1.0)  -- Reduced from 0.02 to 0.01 and max from 2.0 to 1.0
            lastShakeTime = CurTime()
        end
        
        -- Check if player is using a scoped weapon and is aiming
        local weapon = ply:GetActiveWeapon()
        local useScopedFOV = false
        local scopedFOV = nil
        
        if IsValid(weapon) and weapon.Scoped and weapon.ScopeFoV then
            -- Check if weapon is currently aiming (using the GetAiming method)
            if weapon.GetAiming and weapon:GetAiming() > 99 then
                useScopedFOV = true
                scopedFOV = weapon.ScopeFoV
            end
        end
        
        -- Apply custom FOV for standing players, unless using a scoped weapon
        local playerFovCvar = GetConVar("rads_player_fov")
        local customFOV = useScopedFOV and scopedFOV or (playerFovCvar and playerFovCvar:GetFloat() or 90)
        
        -- Always return a view table to ensure FOV is applied
        return {
            origin = pos,
            angles = angles + shake,
            fov = customFOV
        }
    end)
    
    -- Optimized vision sharpening and accumulation blur effects with performance scaling
    local lastVisionEffectUpdate = 0
    local visionEffectInterval = 0.016 -- ~60fps base
    
    hook.Add("RenderScreenspaceEffects", "RADS_VisionEffects", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        
        -- Don't apply effects if ragdolled (to avoid interfering with ragdoll camera)
        if ply:GetNWBool("radsfa") then return end
        
        local cheapEffectsCvar = GetConVar("rads_cheapeffects")
        local cheapEffects = cheapEffectsCvar and cheapEffectsCvar:GetInt() or 0
        
        -- Skip all vision effects if cheapeffects >= 2
        if cheapEffects >= 2 then return end
        
        -- Throttle updates based on cheapeffects level
        if cheapEffects >= 1 then
            visionEffectInterval = 0.033 -- ~30fps for moderate performance
            if CurTime() - lastVisionEffectUpdate < visionEffectInterval then return end
        end
        lastVisionEffectUpdate = CurTime()
        
        local pulse = ply:GetNWInt("PlayerPulse", 70)
        local adrenalineLevel = ply.adrenaline or 0
        
        -- Vision sharpening based on adrenaline (reduced for cheapeffects)
        if adrenalineLevel > 20 then
            local targetSharpness = math.Clamp(adrenalineLevel / 100, 0, cheapEffects >= 1 and 0.4 or 0.8)
            visionSharpness = Lerp(FrameTime() * 3, visionSharpness, targetSharpness)
        else
            visionSharpness = Lerp(FrameTime() * 2, visionSharpness, 0)
        end
        
        -- Apply vision sharpening (reduced intensity for cheapeffects)
        if visionSharpness > 0.1 and cheapEffects < 1 then
            local intensity = cheapEffects >= 1 and 0.5 or 1.0
            local sharpenTab = {
                ["$pp_colour_addr"] = 0,
                ["$pp_colour_addg"] = 0,
                ["$pp_colour_addb"] = 0,
                ["$pp_colour_brightness"] = visionSharpness * 0.1 * intensity,
                ["$pp_colour_contrast"] = 1 + (visionSharpness * 0.3 * intensity),
                ["$pp_colour_colour"] = 1 + (visionSharpness * 0.2 * intensity),
                ["$pp_colour_mulr"] = 1,
                ["$pp_colour_mulg"] = 1,
                ["$pp_colour_mulb"] = 1
            }
            DrawColorModify(sharpenTab)
        end
        
        -- Skip blur effects entirely if cheapeffects >= 1
        if cheapEffects >= 1 then return end
        
        -- Accumulation blur based on stress/fatigue (only for full quality)
        local stressFactor = 0
        if pulse > 100 then
            stressFactor = math.Clamp((pulse - 100) / 50, 0, 1)
        end
        
        if ply.pain and ply.pain > 50 then
            stressFactor = stressFactor + math.Clamp(ply.pain / 200, 0, 0.5)
        end
        
        -- Accumulate blur over time when stressed (reduced accumulation rate)
        if stressFactor > 0.2 then
            blurAccumulation = math.min(blurAccumulation + (stressFactor * FrameTime() * 0.15), maxBlurAccumulation)
        else
            blurAccumulation = math.max(blurAccumulation - (FrameTime() * blurDecayRate), 0)
        end
        
        -- Apply accumulation blur (reduced intensity)
        if blurAccumulation > 0.05 then
            DrawMotionBlur(0.05, blurAccumulation * 0.6, 0.005)
        end
    end)
    
    -- Trigger enhanced shake on damage
    hook.Add("EntityTakeDamage", "RADS_VisionShakeOnDamage", function(target, dmginfo)
        if target == LocalPlayer() and dmginfo:GetDamage() > 5 then
            local shakeAmount = math.Clamp(dmginfo:GetDamage() / 20, 0.5, 3.0)
            smoothShakeStrength = math.min(smoothShakeStrength + shakeAmount, 4.0)
            lastShakeTime = CurTime()
        end
    end)
    
    -- Reset pulse-related visual effects on player death
    hook.Add("PostPlayerDeath", "RADS_ClearPulseEffects", function()
        -- Reset vision enhancement variables
        visionSharpness = 0
        accumulationBlur = 0
        smoothShakeStrength = 0
        smoothShakeSeed = math.random(1000)
        lastShakeTime = 0
        
        -- Reset accumulation blur variables
        blurAccumulation = 0
        
        -- Reset impulse effects
        impulse = 0
        k3 = 0
        
        -- Reset pain effects
        pain = 0
        painlosing = 0
        
        -- NOTE: Consciousness effects are now handled in damage.lua
    end)
    
    -- Reset pulse-related visual effects on player spawn
    hook.Add("PlayerSpawn", "RADS_ResetPulseEffects", function(ply)
        if ply == LocalPlayer() then
            -- Reset vision enhancement variables
            visionSharpness = 0
            accumulationBlur = 0
            smoothShakeStrength = 0
            smoothShakeSeed = math.random(1000)
            lastShakeTime = 0
            
            -- Reset accumulation blur variables
            blurAccumulation = 0
            
            -- Reset impulse effects
            impulse = 0
            k3 = 0
            
            -- Reset pain effects
            pain = 0
            painlosing = 0
            
            -- NOTE: Consciousness effects are now handled in damage.lua
        end
    end)
    
    -- Bullseye damage redirection hook
    hook.Add("EntityTakeDamage", "RADS_BullseyeDamageRedirect", function(target, dmginfo)
        if IsValid(target) and target:GetClass() == "npc_bullseye" then
            local owner = target:GetNWEntity("owner")
            local ragdoll = target:GetNWEntity("ragdoll")
            
            if IsValid(owner) and IsValid(ragdoll) then
                -- Check if player is dead - if so, don't redirect damage
                if owner:Health() <= 0 then
                    print("[RADS BULLSEYE] Player " .. owner:Nick() .. " is dead, blocking damage redirection")
                    -- Remove bullseye since player is dead
                    if IsValid(target) then
                        print("[RADS BULLSEYE] Removing bullseye for dead player: " .. owner:Nick())
                        target:Remove()
                        if IsValid(ragdoll) then
                            ragdoll.bullseye = nil
                        end
                    end
                    return true -- Block damage to bullseye
                end
                
                print("[RADS BULLSEYE] Redirecting damage from bullseye to player: " .. owner:Nick() .. " (Damage: " .. dmginfo:GetDamage() .. ")")
                
                -- Create new damage info for the player
                local newDmgInfo = DamageInfo()
                newDmgInfo:SetDamage(dmginfo:GetDamage())
                newDmgInfo:SetAttacker(dmginfo:GetAttacker())
                newDmgInfo:SetInflictor(dmginfo:GetInflictor())
                newDmgInfo:SetDamageType(dmginfo:GetDamageType())
                newDmgInfo:SetDamagePosition(dmginfo:GetDamagePosition())
                newDmgInfo:SetDamageForce(dmginfo:GetDamageForce())
                newDmgInfo:SetReportedPosition(dmginfo:GetReportedPosition())
                
                -- Apply damage to the player
                owner:TakeDamageInfo(newDmgInfo)
                
                -- Prevent the bullseye from taking damage
                return true
            else
                print("[RADS BULLSEYE] Warning: Bullseye damaged but owner or ragdoll is invalid")
            end
        end
    end)
    
    -- Death check timer for bullseye cleanup
    timer.Create("RADS_BullseyeDeathCheck", 1, 0, function()
        for _, ragdoll in pairs(ents.FindByClass("prop_ragdoll")) do
            if IsValid(ragdoll) and IsValid(ragdoll.bullseye) then
                local owner = ragdoll:GetNWEntity("owner")
                if IsValid(owner) and owner:Health() <= 0 then
                    print("[RADS BULLSEYE] Death check: Removing bullseye for dead player: " .. owner:Nick())
                    ragdoll.bullseye:Remove()
                    ragdoll.bullseye = nil
                    -- Set all NPCs to neutral towards this bullseye (cleanup)
                    for _, npc in pairs(ents.FindByClass("npc_*")) do
                        if IsValid(npc) and npc.AddEntityRelationship then
                            npc:AddEntityRelationship(ragdoll.bullseye, D_NU, 99)
                        end
                    end
                end
            end
        end
    end)

    -- Clientside drowning sound handling
    if CLIENT then
        local drowningSound = nil
        
        net.Receive("PlayDrowningSound", function()
            if drowningSound then
                drowningSound:Stop()
            end
            drowningSound = CreateSound(LocalPlayer(), "drowning.ogg")
            if drowningSound then
                drowningSound:SetSoundLevel(75)
                drowningSound:ChangeVolume(GetConVar("rads_drowning_sound_volume"):GetFloat())
                drowningSound:Play()
            end
        end)
        
        net.Receive("StopDrowningSound", function()
            if drowningSound then
                drowningSound:Stop()
                drowningSound = nil
            end
        end)
        
        -- Clean up sound on player death/disconnect
        hook.Add("PlayerDisconnected", "RADS_CleanupDrowningSound", function(ply)
            if ply == LocalPlayer() and drowningSound then
                drowningSound:Stop()
                drowningSound = nil
            end
        end)
        
        hook.Add("PostPlayerDeath", "RADS_CleanupDrowningSound", function(ply)
            if ply == LocalPlayer() and drowningSound then
                drowningSound:Stop()
                drowningSound = nil
            end
        end)
    end

end