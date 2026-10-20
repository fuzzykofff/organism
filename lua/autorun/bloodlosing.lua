hook.Add("PlayerSpawn","homigrad-blood",function(ply)
	if timer.Exists("respawntimer"..ply:EntIndex()) then return end
	ply.IsBleeding = false
	BleedingEntities[ply] = nil
	ply.Blood = 5000
	ply.BloodLosing=0
	ply.stamina = 100
	ply.LeftLeg = 1
	ply.RightLeg = 1
	ply.RightArm = 1
	ply.LeftArm = 1
	ply.Attacker = nil
	ply.Blood = 5000
	ply:ConCommand("soundfade 0 1")
	ply.bloodNext = CurTime()
	ply.OrgansNextThink = CurTime()
	-- Initialize wound positions table
	ply.WoundPositions = {}
	-- Store wound positions for ragdoll compatibility
	ply.StoredWoundPositions = {}
end)
if SERVER then
function player.GetListByName(name)
	local list = {}

	if name == "^" then
		return
	elseif name == "*" then

		return player.GetAll()
	end

	for i,ply in pairs(player.GetAll()) do
		if string.find(string.lower(ply:Name()),string.lower(name)) then list[#list + 1] = ply end
	end

	return list
end
util.AddNetworkString("info_blood")
util.AddNetworkString("info_adrenaline")
util.AddNetworkString("blood particle")
util.AddNetworkString("blood particle headshoot")
util.AddNetworkString("blood particle explode")
util.AddNetworkString("blood particle more")
util.AddNetworkString("organism_info")
end
function BloodParticle(pos,vel)
	net.Start("blood particle")
	net.WriteVector(pos)
	net.WriteVector(vel)
	net.Broadcast()
end
function BloodParticleHeadshoot(pos,vel)
	net.Start("blood particle headshoot")
	net.WriteVector(pos)
	net.WriteVector(vel)
	net.Broadcast()
end
function BloodParticleExplode(pos)
	net.Start("blood particle explode")
	net.WriteVector(pos)
	net.Broadcast()
end
function BloodParticleMore(pos,vel)
	net.Start("blood particle more")
	net.WriteVector(pos)
	net.WriteVector(vel)
	net.Broadcast()
end
BleedingEntities = BleedingEntities or {}

hook.Add("HomigradDamage","phildcorn",function(ply,hitGroup,dmginfo,rag)
	if not dmginfo:IsDamageType(DMG_BULLET+DMG_SLASH+DMG_BLAST+DMG_ENERGYBEAM+DMG_NEVERGIB+DMG_ALWAYSGIB+DMG_PLASMA+DMG_AIRBOAT+DMG_SNIPER+DMG_BUCKSHOT+DMG_CRUSH+DMG_CLUB+DMG_FALL) then return end
	local dmg
	if dmginfo:IsDamageType(DMG_BUCKSHOT+DMG_SLASH) then 
		dmg = dmginfo:GetDamage() * 0.5  -- Reduced from 1 to 0.5
	elseif dmginfo:IsDamageType(DMG_CRUSH+DMG_CLUB+DMG_FALL) then
		-- Blunt damage only causes internal bleeding in extreme cases
		if dmginfo:GetDamage() >= 60 then
			dmg = dmginfo:GetDamage() * 0.02  -- Reduced from 0.05 to 0.02
		else
			dmg = 0  -- No bleeding for minor blunt damage
		end
	else 
		dmg = dmginfo:GetDamage() * 0.15  -- Reduced from 0.25 to 0.15
	end

	ply.BloodLosing = ply.BloodLosing + dmg
	
	-- Trigger internal bleeding for specific damage types and hit locations
	if dmginfo:IsDamageType(DMG_BLAST) then
		-- Blast damage always causes internal bleeding
		RADS_TriggerInternalBleeding(ply, "blast", dmginfo:GetDamage())
	elseif dmginfo:IsDamageType(DMG_BULLET+DMG_SNIPER+DMG_BUCKSHOT) then
		-- Bullet damage to torso organs causes internal bleeding
		if hitGroup == HITGROUP_CHEST or hitGroup == HITGROUP_STOMACH then
			RADS_TriggerInternalBleeding(ply, "bullet", dmginfo:GetDamage())
		end
	elseif dmginfo:IsDamageType(DMG_CRUSH+DMG_CLUB+DMG_FALL) then
		-- Blunt/fall damage causes internal bleeding based on severity
		local damage = dmginfo:GetDamage()
		if damage >= 60 then
			-- Use fall damage type for better organ targeting
			RADS_TriggerInternalBleeding(ply, "fall", damage)
		end
	end
	
	-- Store wound position based on damage position
	ply.WoundPositions = ply.WoundPositions or {}
	
	-- Skip wound creation for blunt/fall damage (internal bleeding only)
	if dmginfo:IsDamageType(DMG_CRUSH+DMG_CLUB+DMG_FALL) then
		return -- No visible wounds for blunt damage, only internal bleeding
	end
	
	-- Special handling for explosion damage - create multiple scattered wounds
	if dmginfo:IsDamageType(DMG_BLAST) then
		-- Calculate number of wounds based on blood loss amount - more wounds for explosions
		local numWounds = math.Clamp(math.floor(dmg / 12), 3, 9) -- 3-9 wounds based on damage (reduced threshold from 15 to 8)
		
		-- Array of possible body parts for random wound placement - expanded for more explosion wounds
		local bodyParts = {
			{bone = "ValveBiped.Bip01_Head1", hitGroup = HITGROUP_HEAD},
			{bone = "ValveBiped.Bip01_Neck1", hitGroup = HITGROUP_HEAD},
			{bone = "ValveBiped.Bip01_Spine4", hitGroup = HITGROUP_CHEST},
			{bone = "ValveBiped.Bip01_Spine2", hitGroup = HITGROUP_CHEST},
			{bone = "ValveBiped.Bip01_Spine1", hitGroup = HITGROUP_STOMACH},
			{bone = "ValveBiped.Bip01_Spine", hitGroup = HITGROUP_STOMACH},
			{bone = "ValveBiped.Bip01_L_UpperArm", hitGroup = HITGROUP_LEFTARM},
			{bone = "ValveBiped.Bip01_R_UpperArm", hitGroup = HITGROUP_RIGHTARM},
			{bone = "ValveBiped.Bip01_L_Forearm", hitGroup = HITGROUP_LEFTARM},
			{bone = "ValveBiped.Bip01_R_Forearm", hitGroup = HITGROUP_RIGHTARM},
			{bone = "ValveBiped.Bip01_L_Hand", hitGroup = HITGROUP_LEFTARM},
			{bone = "ValveBiped.Bip01_R_Hand", hitGroup = HITGROUP_RIGHTARM},
			{bone = "ValveBiped.Bip01_L_Thigh", hitGroup = HITGROUP_LEFTLEG},
			{bone = "ValveBiped.Bip01_R_Thigh", hitGroup = HITGROUP_RIGHTLEG},
			{bone = "ValveBiped.Bip01_L_Calf", hitGroup = HITGROUP_LEFTLEG},
			{bone = "ValveBiped.Bip01_R_Calf", hitGroup = HITGROUP_RIGHTLEG},
			{bone = "ValveBiped.Bip01_L_Foot", hitGroup = HITGROUP_LEFTLEG},
			{bone = "ValveBiped.Bip01_R_Foot", hitGroup = HITGROUP_RIGHTLEG},
			{bone = "ValveBiped.Bip01_L_Clavicle", hitGroup = HITGROUP_CHEST},
			{bone = "ValveBiped.Bip01_R_Clavicle", hitGroup = HITGROUP_CHEST}
		}
		
		-- Create multiple wounds at random body locations
		for i = 1, numWounds do
			local randomBodyPart = bodyParts[math.random(1, #bodyParts)]
			local ent = IsValid(rag) and rag or ply
			local woundPos
			
			-- Get bone position for wound
			local boneIndex = ent:LookupBone(randomBodyPart.bone)
			if boneIndex then
				local boneMatrix = ent:GetBoneMatrix(boneIndex)
				if boneMatrix then
					woundPos = boneMatrix:GetTranslation() + VectorRand(-5, 5) -- Add randomness
				else
					woundPos = ent:GetPos() + ent:OBBCenter() + VectorRand(-10, 10)
				end
			else
				woundPos = ent:GetPos() + ent:OBBCenter() + VectorRand(-10, 10)
			end
			
			local playerPos = ply:GetPos()
			local relativePos = woundPos - playerPos
			
			-- Create wound with reduced individual damage but multiple wounds
			local woundDamage = dmg / numWounds
			
			table.insert(ply.WoundPositions, {
				pos = woundPos,
				playerPos = playerPos,
				relativePos = relativePos,
				damage = woundDamage,
				time = CurTime(),
				bloodStack = math.random(1, 2), -- Start explosion wounds with more blood
				nextBleed = CurTime() + math.random(0.1, 2.5), -- Randomized initial bleeding for explosions
				nextStack = CurTime() + math.random(0.05, 1.2), -- Randomized blood stacking for explosions
				boneName = randomBodyPart.bone,
				hitGroup = randomBodyPart.hitGroup,
				isExplosionWound = true, -- Mark as explosion wound
				maxBloodStack = 5 -- Explosion wounds can stack more blood (up to 5 instead of 3)
			})
			
			-- Create immediate blood spurt for each explosion wound with reduced velocity
            BloodParticle(woundPos, VectorRand(-12, 12) + Vector(math.random(-3, 3), math.random(-3, 3), math.random(-2, 2)))
            -- Add default GMod blood particle effect
            local effectdata = EffectData()
            effectdata:SetOrigin(woundPos)
            effectdata:SetNormal(VectorRand())
            util.Effect("BloodImpact", effectdata)
            -- Additional blood particles for more dramatic effect with reduced randomization
            if math.random(1, 3) == 1 then -- Reduced frequency from 1/2 to 1/3
                BloodParticle(woundPos + VectorRand(-2, 2), VectorRand(-10, 10) + Vector(math.random(-3, 3), math.random(-3, 3), math.random(-1, 1)))
            end
		end
		
	else
		-- Normal single wound handling for non-explosion damage
		local woundPos = dmginfo:GetDamagePosition()
		
		-- If no damage position available, use hit group to estimate position
		if not woundPos or woundPos == Vector(0,0,0) then
			local ent = IsValid(rag) and rag or ply
			local boneName = ""
			
			-- Map hit groups to bone names
			if hitGroup == HITGROUP_HEAD then
				boneName = "ValveBiped.Bip01_Head1"
			elseif hitGroup == HITGROUP_CHEST then
				boneName = "ValveBiped.Bip01_Spine2"
			elseif hitGroup == HITGROUP_STOMACH then
				boneName = "ValveBiped.Bip01_Spine1"
			elseif hitGroup == HITGROUP_LEFTARM then
				boneName = "ValveBiped.Bip01_L_UpperArm"
			elseif hitGroup == HITGROUP_RIGHTARM then
				boneName = "ValveBiped.Bip01_R_UpperArm"
			elseif hitGroup == HITGROUP_LEFTLEG then
				boneName = "ValveBiped.Bip01_L_Thigh"
			elseif hitGroup == HITGROUP_RIGHTLEG then
				boneName = "ValveBiped.Bip01_R_Thigh"
			else
				boneName = "ValveBiped.Bip01_Spine1" -- Default to stomach
			end
			
			local boneIndex = ent:LookupBone(boneName)
			if boneIndex then
				local boneMatrix = ent:GetBoneMatrix(boneIndex)
				if boneMatrix then
					woundPos = boneMatrix:GetTranslation()
				else
					woundPos = ent:GetPos() + ent:OBBCenter() -- Fallback
				end
			else
				woundPos = ent:GetPos() + ent:OBBCenter() -- Fallback
			end
		end
		
		-- Add wound position with blood stacking system and bone information
		local playerPos = ply:GetPos()
		local relativePos = woundPos - playerPos -- Store relative position to player
		
		-- Store bone information for better ragdoll mapping
		local targetBoneName = ""
		if hitGroup == HITGROUP_HEAD then
			targetBoneName = "ValveBiped.Bip01_Head1"
		elseif hitGroup == HITGROUP_CHEST then
			targetBoneName = "ValveBiped.Bip01_Spine2"
		elseif hitGroup == HITGROUP_STOMACH then
			targetBoneName = "ValveBiped.Bip01_Spine1"
		elseif hitGroup == HITGROUP_LEFTARM then
			targetBoneName = "ValveBiped.Bip01_L_UpperArm"
		elseif hitGroup == HITGROUP_RIGHTARM then
			targetBoneName = "ValveBiped.Bip01_R_UpperArm"
		elseif hitGroup == HITGROUP_LEFTLEG then
			targetBoneName = "ValveBiped.Bip01_L_Thigh"
		elseif hitGroup == HITGROUP_RIGHTLEG then
			targetBoneName = "ValveBiped.Bip01_R_Thigh"
		else
			targetBoneName = "ValveBiped.Bip01_Spine1" -- Default to stomach
		end
		
		table.insert(ply.WoundPositions, {
			pos = woundPos, 
			playerPos = playerPos, 
			relativePos = relativePos, 
			damage = dmg, 
			time = CurTime(), 
			bloodStack = 0, -- Blood particles accumulated (max 3)
			nextBleed = CurTime() + math.random(0.5, 4), -- More randomized initial bleed time
			nextStack = CurTime() + math.random(0.2, 3), -- More randomized stacking time
			boneName = targetBoneName, -- Store target bone name for ragdoll mapping
			hitGroup = hitGroup -- Store hit group for reference
		})
		
		-- Initial blood spurt when wound is created with reduced velocity
        BloodParticle(woundPos, VectorRand(-8, 8) + Vector(math.random(-2, 2), math.random(-2, 2), math.random(-1, 1)))
        
        -- Add default GMod blood particle effect for all wounds
        local effectdata = EffectData()
        effectdata:SetOrigin(woundPos)
        effectdata:SetNormal(VectorRand())
        util.Effect("BloodImpact", effectdata)
        
        -- For bullet damage, create exit wound if damage is sufficient
        if dmginfo:IsDamageType(DMG_BULLET) and dmg > 15 then
            local attacker = dmginfo:GetAttacker()
            local damageForce = dmginfo:GetDamageForce()
            
            if IsValid(attacker) and damageForce:Length() > 0 then
                -- Calculate exit wound position
                local forceDir = damageForce:GetNormalized()
                local exitPos = woundPos + forceDir * 15 -- Exit wound 15 units behind entry
                
                -- Create exit wound with additional blood loss
                table.insert(ply.WoundPositions, {
                    pos = exitPos,
                    playerPos = playerPos,
                    relativePos = exitPos - playerPos,
                    damage = dmg * 0.6, -- Exit wound causes 60% of entry damage
                    time = CurTime(),
                    bloodStack = 1, -- Start with some blood
                    nextBleed = CurTime() + math.random(0.3, 2),
                    nextStack = CurTime() + math.random(0.1, 1.5),
                    boneName = targetBoneName,
                    hitGroup = hitGroup,
                    isExitWound = true
                })
                
                -- Create exit wound blood spurt with velocity
                BloodParticle(exitPos, forceDir * 8 + VectorRand(-4, 4))
                
                -- Add default GMod blood effect for exit wound
                local exitEffectdata = EffectData()
                exitEffectdata:SetOrigin(exitPos)
                exitEffectdata:SetNormal(forceDir)
                util.Effect("BloodImpact", exitEffectdata)
            end
        end
	end
	
	-- Don't clean up wounds automatically - they should persist until bleeding stops
end)

local tr = {filter = {}}
local math_Clamp = math.Clamp
bleedinginterval = math.random(0.25,1)
local util_TraceHull = util.TraceHull
local math_Rand = math.Rand
local util_Decal = util.Decal



hook.Add("Player Think", "homigrad-blood", function(ply, CurTime)
    -- Initialize bloodNext if it doesn't exist to prevent nil comparison errors
    ply.bloodNext = ply.bloodNext or 0
    if not ply:Alive() or ply:HasGodMode() or ply.bloodNext > CurTime then return end
    local ragg = ply:GetNWEntity('player_ragdoll')
	local rg = ply:GetNWEntity('player_ragdoll')
    local ent
    if IsValid(ragg) and ply:IsRag() then
        ent = ragg
    else
        ent = ply 
    end
    ply.Organs = ply.Organs or {}
    -- Initialize blood-related properties to prevent nil comparison errors
    ply.BloodLosing = ply.BloodLosing or 0
    ply.Blood = ply.Blood or 5000
    ply.pain = ply.pain or 0
    
	if ply.BloodLosing == 0 then
		BleedingEntities[rg] = nil
	end
	if ply.Blood == 0 then
	ply:Kill()
	end
	-- Remove the problematic neck bone check that could cause errors
	-- if ent:IsPlayer() and ent:GetMoveType() ~= MOVETYPE_OBSERVER then
	--	local neck = ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_Neck1")):GetTranslation()
	-- end
 
    if ply.BloodLosing > 0 then
        ply.BloodLosing = ply.BloodLosing - 0.1  -- Reduced from 0.25 to 0.1 (slower healing)
        
        -- Apply blood loss (continues even when unconscious)
        ply.Blood = math.max(ply.Blood - ply.BloodLosing / 5, 0)  -- Reduced from /4 to /8 (half blood loss rate)
        ply.pain = ply.pain + ply.BloodLosing / 20  -- Reduced from /10 to /20 (less pain)
        
        -- Check both current wounds and stored wounds (for ragdoll compatibility)
        local woundList = ply.WoundPositions or {}
        if ply:IsRag() and ply.StoredWoundPositions then
            woundList = ply.StoredWoundPositions
        end
        
        -- Process each wound with blood stacking system
        if woundList and #woundList > 0 then
            for _, wound in ipairs(woundList) do
                -- Initialize wound properties if missing
                wound.bloodStack = wound.bloodStack or 0
                wound.nextBleed = wound.nextBleed or CurTime + math.random(1, 3)
                wound.nextStack = wound.nextStack or CurTime + math.random(0.5, 2)
                
                -- Calculate blood loss severity factor (0.1 to 2.0 multiplier)
                local bloodLossFactor = math.Clamp(ply.BloodLosing / 100, 0.1, 2.0)
                
                -- Stack blood particles based on damage, wound type, and blood loss
                local maxStack = wound.maxBloodStack or 3 -- Use custom max or default to 3
                if wound.nextStack <= CurTime and wound.bloodStack < maxStack then
                    wound.bloodStack = wound.bloodStack + 1
                    -- Next stacking time based on damage, wound type, and blood loss severity
                    local baseStackDelay = math.Clamp(5 / (wound.damage / 10), 0.5, 3)
                    local stackDelay = baseStackDelay / bloodLossFactor -- More blood loss = faster stacking
                    if wound.isExplosionWound then
                        stackDelay = stackDelay * 0.6 -- Explosion wounds stack 40% faster
                    end
                    -- Add randomness to prevent synchronization
                    wound.nextStack = CurTime + math.random(stackDelay * 0.3, stackDelay * 1.8)
                end
                
                -- Drip blood based on stack size with random intervals
                if wound.nextBleed <= CurTime and wound.bloodStack > 0 then
                    local bloodPos = wound.pos
                    
                    -- Transform wound position based on player state
                    if ply:IsRag() then
                        local ragdoll = ply:GetNWEntity('player_ragdoll')
                        if IsValid(ragdoll) then
                            -- Use stored bone information for accurate positioning
                            if wound.boneName and wound.boneName ~= "" then
                                -- Try to find the exact bone on the ragdoll
                                local targetBoneIndex = ragdoll:LookupBone(wound.boneName)
                                if targetBoneIndex then
                                    local boneMatrix = ragdoll:GetBoneMatrix(targetBoneIndex)
                                    if boneMatrix then
                                        -- Use the bone position with slight offset based on relative position
                                        local bonePos = boneMatrix:GetTranslation()
                                        local relativePos = wound.relativePos or Vector(0,0,0)
                                        bloodPos = bonePos + relativePos * 0.2 + VectorRand(-2, 2)
                                    else
                                        -- Fallback to physics object search
                                        bloodPos = ragdoll:GetPos() + (wound.relativePos or Vector(0,0,0)) + VectorRand(-3, 3)
                                    end
                                else
                                    -- Fallback to physics object search
                                    bloodPos = ragdoll:GetPos() + (wound.relativePos or Vector(0,0,0)) + VectorRand(-3, 3)
                                end
                            else
                                -- Legacy fallback for wounds without bone information
                                local relativePos = wound.relativePos or (wound.pos - (wound.playerPos or ply:GetPos()))
                                
                                -- Try to find the closest matching bone on the ragdoll
                                local closestDist = math.huge
                                local closestPos = ragdoll:GetPos() + relativePos
                                
                                -- Check all physics objects on the ragdoll and find the best match
                                for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
                                    local physobj = ragdoll:GetPhysicsObjectNum(i)
                                    if IsValid(physobj) then
                                        local boneIndex = ragdoll:TranslatePhysBoneToBone(i)
                                        if boneIndex and boneIndex >= 0 then
                                            local boneMatrix = ragdoll:GetBoneMatrix(boneIndex)
                                            if boneMatrix then
                                                local bonePos = boneMatrix:GetTranslation()
                                                local dist = (wound.pos):Distance(bonePos)
                                                if dist < closestDist then
                                                    closestDist = dist
                                                    closestPos = bonePos + relativePos * 0.3
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                bloodPos = closestPos + VectorRand(-3, 3)
                            end
                        end
                    else
                        -- For standing players, update wound position relative to current player position
                        if wound.relativePos and wound.playerPos then
                            bloodPos = ply:GetPos() + wound.relativePos + VectorRand(-2, 2)
                        else
                            -- Fallback to original position with slight randomness
                            bloodPos = wound.pos + VectorRand(-2, 2)
                        end
                    end
                    
                    -- Spawn blood particle and reduce stack with reduced velocity for less dripping
                    BloodParticle(bloodPos, VectorRand(-5, 5) + Vector(math.random(-2, 2), math.random(-2, 2), math.random(-1, 1)))
                    wound.bloodStack = wound.bloodStack - 1
                    
                    -- Set next drip time based on blood stack, blood loss severity, and randomness
                    local baseDripDelay = math.Clamp(3 / (wound.bloodStack + 1), 0.3, 2)
                    local bloodLossMultiplier = math.Clamp(2.0 / bloodLossFactor, 0.2, 3.0) -- More blood loss = faster dripping
                    local finalDripDelay = baseDripDelay * bloodLossMultiplier
                    
                    -- Add significant randomness to prevent synchronization (±50% variance)
                    local minDelay = finalDripDelay * 0.5
                    local maxDelay = finalDripDelay * 1.5
                    wound.nextBleed = CurTime + math.random() * (maxDelay - minDelay) + minDelay
                end
            end
        end
        
		if GetConVar("developer"):GetInt() > 0 then
    print(tostring(ply:Nick().." "..ply.BloodLosing .. " Blood loss Current blood: " .. ply.Blood .. ". Pain: " .. ply.pain))
end
    else
        -- Clear wounds when bleeding stops completely
        if ply.BloodLosing <= 0 and ply.WoundPositions and #ply.WoundPositions > 0 then
            ply.WoundPositions = {}
            ply.StoredWoundPositions = {}
        end
    end
    
    if ply.Blood < 5000 and ply.BloodLosing <= 0 then
        ply.Blood = ply.Blood
    end

    local randomDelay = math.random(0.75, 3)

    ply.bloodNext = CurTime + 1.8  -- Increased from 1.5 to 1.8 (even slower bleeding frequency for less dripping)
end)


local math_random = math.random
local CurTime = CurTime
local time

local tr = {}

local randVec = Vector(0,0,-1)
OrgansNextThink = 0
-- New Internal Bleeding System
-- Network strings for blood vomiting (server-side only)
if SERVER then
	util.AddNetworkString("RADS_BloodVomitWarning")
	util.AddNetworkString("RADS_BloodVomit")
	util.AddNetworkString("request_organism_info")
end

-- Gender detection function
local function GetPlayerGender(ply)
	local model = ply:GetModel():lower()
	if string.find(model, "alyx.mdl") or string.find(model, "mossman.mdl") or string.find(model, "mossman_arctic.mdl") or string.find(model, "p2_chell.mdl") or string.find(model, "female_") then
		return "female"
	end
	return "male"
end

-- Function to get head/mouth position for vomiting
local function GetMouthPosition(ply)
	local ent = ply
	if ply:IsRag() then
		local rag = ply:GetNWEntity('player_ragdoll')
		if IsValid(rag) then
			ent = rag
		end
	end
	
	-- Try to get head bone position
	local headBone = ent:LookupBone("ValveBiped.Bip01_Head1")
	if headBone then
		local headMatrix = ent:GetBoneMatrix(headBone)
		if headMatrix then
			return headMatrix:GetTranslation() + Vector(0, 0, -2) -- Slightly below head for mouth
		end
	end
	
	-- Fallback to entity position + offset
	return ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z * 0.8)
end

-- Function to trigger blood vomiting with enhanced effects
local function TriggerBloodVomit(ply)
	if not IsValid(ply) or not ply:Alive() or not SERVER then return end
	
	local intensity = ply.InternalBleedingIntensity or 0
	if intensity <= 0 then return end
	
	if GetConVar("developer"):GetInt() > 0 then
    print("[DEBUG] TriggerBloodVomit called for " .. ply:Name() .. " with intensity: " .. intensity)
end
	
	-- Calculate health and blood loss based on intensity
	local healthLoss = 5 + (intensity / 10) -- Base 5 + intensity scaling
	local bloodLoss = 60 + (intensity * 2) -- Base 60 + intensity scaling
	
	-- Apply damage
	ply:SetHealth(math.max(0, ply:Health() - healthLoss))
	ply.Blood = math.max(0, (ply.Blood or 5000) - bloodLoss)
	
	-- Heal organs when vomiting to reduce internal bleeding by 15-20 points
	local organHealAmount = math.random(15, 20) / 100 -- Convert to percentage (0.15-0.20)
	if ply.Organs then
		for organName, organHealth in pairs(ply.Organs) do
			if organHealth < 1 then -- Only heal damaged organs
				ply.Organs[organName] = math.min(1, organHealth + organHealAmount)
			end
		end
	end
	
	-- Removed ducking functionality due to SetDucking errors
	
	-- Send viewpunch to client for looking down effect
	if ply:Alive() and not ply:IsRag() then
		ply:ViewPunch(Angle(15, 0, 0)) -- Look down smoothly but fast
	end
	
	-- Start vomiting sequence with timer for 1.5 seconds
	local vomitStartTime = CurTime()
	local vomitDuration = 1.5
	local timerName = "RADS_VomitSequence_" .. ply:UserID()
	
	-- Initial velocity for vomit
	local baseVelocity = -24
	
	timer.Create(timerName, 0.15, math.floor(vomitDuration / 0.15), function()
		if not IsValid(ply) or not ply:Alive() then 
			timer.Remove(timerName)
			return 
		end
		
		local elapsed = CurTime() - vomitStartTime
		local progress = elapsed / vomitDuration
		
		-- Calculate decreasing velocity over time
		local currentVelocity = baseVelocity * (1 - progress)
		
		-- Get mouth position
		local mouthPos = GetMouthPosition(ply)
		
		-- Create fewer blood particles with decreasing velocity
		local particleCount = 1 -- Only 1 particle per spurt
		if math.random() < 0.7 then -- 70% chance to spawn particle
			local vel = Vector(
				math.random(-currentVelocity/2, currentVelocity/2),
				currentVelocity + math.random(-8, 8), -- Forward direction with more variation
				math.random(-currentVelocity/3, currentVelocity/4)
			)
			local particlePos = mouthPos + VectorRand(-1, 1)
			if GetConVar("developer"):GetInt() > 0 then
    print("[DEBUG] Creating blood particle at:", particlePos, "with velocity:", vel)
end
			BloodParticleMore(particlePos, vel)
		end
		
		-- Add slight viewpunch throughout vomiting
		if ply:Alive() and not ply:IsRag() and math.random() < 0.3 then
			ply:ViewPunch(Angle(math.random(2, 5), math.random(-2, 2), 0))
		end
	end)
	
	-- Play gender-specific cough sound
	local gender = GetPlayerGender(ply)
	local soundFile
	if gender == "female" then
		soundFile = "female_cough" .. math.random(1, 4) .. ".mp3"
	else
		soundFile = "male_cough" .. math.random(1, 4) .. ".mp3"
	end
	
	-- Play sound from the entity (player or ragdoll)
	local soundEnt = ply
	if ply:IsRag() then
		local rag = ply:GetNWEntity('player_ragdoll')
		if IsValid(rag) then
			soundEnt = rag
		end
	end
	soundEnt:EmitSound(soundFile, 75, 100, 1, CHAN_VOICE)
	
	-- Removed ducking reset functionality
	
	-- Update blood info
	net.Start("info_blood")
	net.WriteFloat(ply.Blood)
	net.Send(ply)
end

-- Function to send warning sound to client and schedule vomiting
local function SendVomitWarning(ply)
	if not IsValid(ply) or not ply:Alive() or not SERVER then return end
	net.Start("RADS_BloodVomitWarning")
	net.Send(ply)
	
	-- Schedule vomiting exactly 5 seconds after warning
	timer.Create("RADS_VomitTimer_" .. ply:UserID(), 5, 1, function()
		if IsValid(ply) and ply:Alive() then
			TriggerBloodVomit(ply)
		end
	end)
	
	if GetConVar("developer"):GetInt() > 0 then
    print("[INTERNAL BLEEDING] Warning sent to " .. ply:Name() .. ", vomiting in 5 seconds")
end
end

-- Function to trigger internal bleeding from various sources
function RADS_TriggerInternalBleeding(ply, source, damage)
	if not SERVER or not IsValid(ply) or not ply:IsPlayer() then return end
	
	-- Initialize organs if not present
	ply.Organs = ply.Organs or {
		["brain"] = 1,
		["heart"] = 1,
		["left_lung"] = 1,
		["right_lung"] = 1,
		["liver"] = 1,
		["stomach"] = 1,
		["intestines"] = 1,
		["spine"] = 1
	}
	
	local organDamage = 0
	
	if source == "fall" then
		-- Fall damage affects multiple organs based on severity (FURTHER REDUCED RATES)
		if damage >= 50 then
			-- Extreme fall - damage multiple organs severely
			organDamage = math.random(0.075, 0.15) -- Reduced from 15-30% to 7.5-15% organ damage
			ply.Organs["liver"] = math.max(0, ply.Organs["liver"] - organDamage)
			ply.Organs["stomach"] = math.max(0, ply.Organs["stomach"] - organDamage * 0.3) -- Reduced from 0.6
			ply.Organs["intestines"] = math.max(0, ply.Organs["intestines"] - organDamage * 0.25) -- Reduced from 0.5
			ply.Organs["left_lung"] = math.max(0, ply.Organs["left_lung"] - organDamage * 0.075) -- Reduced from 0.15
			ply.Organs["right_lung"] = math.max(0, ply.Organs["right_lung"] - organDamage * 0.075) -- Reduced from 0.15
		elseif damage >= 35 then
			-- Severe fall - damage some organs moderately
			organDamage = math.random(0.05, 0.1) -- Reduced from 10-20% to 5-10% organ damage
			ply.Organs["liver"] = math.max(0, ply.Organs["liver"] - organDamage)
			ply.Organs["stomach"] = math.max(0, ply.Organs["stomach"] - organDamage * 0.2) -- Reduced from 0.4
			ply.Organs["intestines"] = math.max(0, ply.Organs["intestines"] - organDamage * 0.15) -- Reduced from 0.3
			ply.Organs["left_lung"] = math.max(0, ply.Organs["left_lung"] - organDamage * 0.05) -- Reduced from 0.1
			ply.Organs["right_lung"] = math.max(0, ply.Organs["right_lung"] - organDamage * 0.05) -- Reduced from 0.1
		end
	elseif source == "bullet" then
		-- Bullet damage to organs based on hit location (FURTHER REDUCED RATES)
		organDamage = math.random(0.025, 0.075) -- Reduced from 5-15% to 2.5-7.5% organ damage
		local targetOrgan = "stomach" -- Default
		
		-- Determine which organ was hit (this would be passed from damage system)
		if damage > 25 then -- Significant bullet damage
			ply.Organs[targetOrgan] = math.max(0, ply.Organs[targetOrgan] - organDamage)
		end
	elseif source == "blast" then
		-- Blast damage affects multiple organs (FURTHER REDUCED RATES)
		organDamage = math.random(0.05, 0.125) -- Reduced from 10-25% to 5-12.5% organ damage
		ply.Organs["liver"] = math.max(0, ply.Organs["liver"] - organDamage * 0.3) -- Reduced from 0.6
		ply.Organs["stomach"] = math.max(0, ply.Organs["stomach"] - organDamage * 0.35) -- Reduced from 0.7
		ply.Organs["intestines"] = math.max(0, ply.Organs["intestines"] - organDamage * 0.3) -- Reduced from 0.6
		ply.Organs["left_lung"] = math.max(0, ply.Organs["left_lung"] - organDamage * 0.1) -- Reduced from 0.2
		ply.Organs["right_lung"] = math.max(0, ply.Organs["right_lung"] - organDamage * 0.1) -- Reduced from 0.2
		ply.Organs["heart"] = math.max(0, ply.Organs["heart"] - organDamage * 0.125) -- Reduced from 0.25
	end
	
	if GetConVar("developer"):GetInt() > 0 then
    print("[INTERNAL BLEEDING] Triggered for " .. ply:Name() .. " from " .. source .. " with damage: " .. damage)
end
end

local player_GetAll = player.GetAll

hook.Add("Player Think","InternalBleeding",function(ply,time)
	if not SERVER then return end
	for i,ply in pairs(player_GetAll()) do
		-- Death check - skip if player is dead
		if not ply:Alive() then continue end
		
		ply.OrgansNextThink = ply.OrgansNextThink or CurTime()
		-- Initialize blood properties to prevent nil errors
		ply.Blood = ply.Blood or 5000
		ply.InternalBleedingIntensity = ply.InternalBleedingIntensity or 0
		ply.NextVomitTime = ply.NextVomitTime or 0
		ply.VomitWarningTime = ply.VomitWarningTime or 0
		ply.FirstBleedingDetected = ply.FirstBleedingDetected or false
		
		if not(ply.OrgansNextThink>CurTime())then
			ply.OrgansNextThink=CurTime() + math.random(0.3, 0.8)
			if ply.Organs and ply:Alive() then
				if ply.Organs["brain"]==0 then
					TriggerDeathState(ply)
				end
				
				if ply.Organs["spine"]==0 then
					ply.brokenspine=true
					if !ply.fake then rads(ply) end
				end
				
				-- New internal bleeding system - calculate intensity based on organ damage
				local totalIntensity = 0
				
				-- Each damaged organ contributes to internal bleeding intensity
				-- Normalize organ health (0-100% instead of raw values)
				local maxHealth = {
					["liver"] = 15,
					["stomach"] = 15,
					["intestines"] = 30,
					["heart"] = 9,
					["left_lung"] = 5,
					["right_lung"] = 5
				}
				
				if ply.Organs["liver"] and maxHealth["liver"] then
					local healthPercent = math.Clamp(ply.Organs["liver"] / maxHealth["liver"], 0, 1)
					totalIntensity = totalIntensity + (1 - healthPercent) * 25
				end
				if ply.Organs["stomach"] and maxHealth["stomach"] then
					local healthPercent = math.Clamp(ply.Organs["stomach"] / maxHealth["stomach"], 0, 1)
					totalIntensity = totalIntensity + (1 - healthPercent) * 20
				end
				if ply.Organs["intestines"] and maxHealth["intestines"] then
					local healthPercent = math.Clamp(ply.Organs["intestines"] / maxHealth["intestines"], 0, 1)
					totalIntensity = totalIntensity + (1 - healthPercent) * 15
				end
				if ply.Organs["heart"] and maxHealth["heart"] then
					local healthPercent = math.Clamp(ply.Organs["heart"] / maxHealth["heart"], 0, 1)
					totalIntensity = totalIntensity + (1 - healthPercent) * 35
				end
				if ply.Organs["left_lung"] and maxHealth["left_lung"] then
					local healthPercent = math.Clamp(ply.Organs["left_lung"] / maxHealth["left_lung"], 0, 1)
					totalIntensity = totalIntensity + (1 - healthPercent) * 10
				end
				if ply.Organs["right_lung"] and maxHealth["right_lung"] then
					local healthPercent = math.Clamp(ply.Organs["right_lung"] / maxHealth["right_lung"], 0, 1)
					totalIntensity = totalIntensity + (1 - healthPercent) * 10
				end
				
				-- Store previous intensity to detect when bleeding first starts
				local previousIntensity = ply.InternalBleedingIntensity
				
				-- Clamp intensity to 0-100
				ply.InternalBleedingIntensity = math.Clamp(totalIntensity, 0, 100)
				
				-- Apply blood loss based on intensity (invisible bleeding)
				if ply.InternalBleedingIntensity > 0 then
					local bloodLossRate = ply.InternalBleedingIntensity * 0.15 -- Reduced from 0.3 to 0.15 blood per intensity point
					ply.Blood = ply.Blood - bloodLossRate
					
					-- Enhanced passive organ healing for gradual internal bleeding reduction
				local passiveHealRate = 0.005 -- Base passive healing rate
				
				-- Increase healing rate when internal bleeding is low
				if ply.InternalBleedingIntensity < 35 then
					passiveHealRate = 0.015 -- Faster healing when bleeding is low
				elseif ply.InternalBleedingIntensity < 60 then
					passiveHealRate = 0.008 -- Moderate healing for medium bleeding
				end
				
				-- Apply passive healing to all damaged organs
				for organ, health in pairs(ply.Organs) do
					if health < 1 and health > 0 then -- Only heal damaged organs
						ply.Organs[organ] = math.min(1, health + passiveHealRate)
					end
				end
					
					-- Check if this is the first time internal bleeding is detected
					if previousIntensity == 0 and ply.InternalBleedingIntensity > 0 and not ply.FirstBleedingDetected then
						-- First time getting internal bleeding - set random delay before first vomit
						ply.FirstBleedingDetected = true
						local initialDelay = math.random(5, 30) -- 30-90 seconds before first vomit
						ply.NextVomitTime = CurTime() + initialDelay
						if GetConVar("developer"):GetInt() > 0 then
    print("[INTERNAL BLEEDING] First bleeding detected for " .. ply:Name() .. ", first vomit in " .. initialDelay .. " seconds")
end
					elseif CurTime() >= ply.NextVomitTime and ply.InternalBleedingIntensity >= 30 then -- Reduced from 45 to 30
						-- Calculate vomit frequency based on intensity (higher intensity = more frequent vomiting)
						local baseInterval = 20 -- Reduced from 45 to 25 seconds for more frequent vomiting
						local intensityFactor = (100 - ply.InternalBleedingIntensity) / 100
						local vomitInterval = baseInterval * intensityFactor + math.random(5, 15) -- Reduced random range
						
						-- Set next vomit time and trigger warning immediately
						ply.NextVomitTime = CurTime() + vomitInterval
						SendVomitWarning(ply) -- This will play warning and schedule vomiting in 5 seconds
					end
				else
					-- No internal bleeding - reset first bleeding flag
					ply.FirstBleedingDetected = false
				end
			end
			end
		end
end)
function remtbl(entf)
    for i, ent in ipairs(BleedingEntities) do
        if ent == entf then
            table.remove(BleedingEntities, i)
            break 
        end
    end
end
concommand.Add("zblood",function(ply)
	local r = ply:GetEyeTrace().Entity
	remtbl(r)
end)
hook.Add("Think","homigrad-bleeding-ents",function()
	time = CurTime()
	for i,ent in pairs(BleedingEntities) do
		if not IsValid(ent) or ent:IsPlayer() then continue end

		ent.bloodNext = ent.bloodNext or time
		if ent.bloodNext > time then continue end
		ent.bloodNext = time + 0.7  -- Increased from 0.5 to 0.7 (slower bleeding for entities)
        BloodParticle(ent:GetPos() + ent:OBBCenter(),VectorRand(-4,4)) -- Reduced velocity
		ent.Blood = ent.Blood or 1500
		ent.Blood = math.min(0,ent.Blood - 15)  -- Reduced from 35 to 15
		if ent.Blood <= math.random(-3500,-100) then remtbl(ent) end
	end
end)

hook.Add("PlayerDeath","deathblood",function(ply)
	if not SERVER then return end
	ply.Blood = 5000
	ply.BloodLosing = 0
	ply.LeftLeg = 1
	ply.RightLeg = 1
	ply.RightArm = 1
	ply.LeftArm = 1
	ply.brokenspine = false
	-- Clear wound positions on death
	ply.WoundPositions = {}
	-- Reset new internal bleeding system
	ply.InternalBleedingIntensity = 0
	ply.NextVomitTime = 0
	ply.FirstBleedingDetected = false
	-- Remove any pending vomit timers
	timer.Remove("RADS_VomitTimer_" .. ply:UserID())
	timer.Remove("RADS_VomitSequence_" .. ply:UserID())
	ply:ConCommand("soundfade 0 1")
	ply:SetDSP(0)
	net.Start("info_blood")
	net.WriteFloat(ply.Blood)
	net.Send(ply)
end)

concommand.Add("!r_organisminfo", function(ply, cmd, args)
    if not SERVER or not ply:IsAdmin() then return end
    local targetPlayer = nil
    local targetName = args[1]
    for _, playerObj in ipairs(player.GetAll()) do
        if playerObj:Name() == targetName then
            targetPlayer = playerObj
            break
        end
    end
    if not targetPlayer then
        targetPlayer = ply
    end
    net.Start("organism_info")
    net.WriteTable(targetPlayer.Organs)
    net.WriteString(
        "Кровь (мл): " .. tostring(targetPlayer.Blood) .. "\n" ..
        "Кровотечение (мл/удар): " .. tostring(targetPlayer.BloodLosing) .. "\n" ..
        "Боль: " .. tostring(targetPlayer.pain) .. "\n" ..
        "Игрок: " .. targetPlayer:Name()
    )
    net.Send(ply)
end)

-- Network message handler for requesting organism info
if SERVER then
    net.Receive("request_organism_info", function(len, ply)
        if not IsValid(ply) then return end
        
        -- Initialize player data if not present
        ply.Organs = ply.Organs or {
            ["brain"] = 1,
            ["heart"] = 9,
            ["left_lung"] = 5,
            ["right_lung"] = 5,
            ["liver"] = 15,
            ["stomach"] = 15,
            ["intestines"] = 30,
            ["spine"] = 1
        }
        ply.Blood = ply.Blood or 5000
        ply.BloodLosing = ply.BloodLosing or 0
        ply.pain = ply.pain or 0
        
        -- Send organism info to requesting player
        net.Start("organism_info")
        net.WriteTable(ply.Organs)
        net.WriteString(
            "Кровь (мл): " .. tostring(ply.Blood) .. "\n" ..
            "Кровотечение (мл/удар): " .. tostring(ply.BloodLosing) .. "\n" ..
            "Боль: " .. tostring(ply.pain) .. "\n" ..
            "Игрок: " .. ply:Name()
        )
        net.Send(ply)
    end)
end


concommand.Add("!r_organismsetvalue",function(ply,cmd,args)
	if not SERVER or not ply:IsAdmin() then return end
	
	local huyply = args[3] and player.GetListByName(args[3])[1] or ply
	
	huyply.Organs[args[1]] = args[2]
end)

-- Debug commands for internal bleeding system
concommand.Add("rads_trigger_vomit", function(ply, cmd, args)
	if not SERVER or not ply:IsAdmin() then return end
	
	local targetPly = ply
	if args[1] then
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Name()), string.lower(args[1])) then
				targetPly = p
				break
			end
		end
	end
	
	if IsValid(targetPly) then
		-- Set minimum internal bleeding intensity for vomiting
		targetPly.InternalBleedingIntensity = math.max(targetPly.InternalBleedingIntensity or 0, 20)
		-- Trigger warning and vomiting
		SendVomitWarning(targetPly)
		ply:ChatPrint("Triggered blood vomit for " .. targetPly:Name() .. " with warning")
	else
		ply:ChatPrint("Player not found")
	end
end)

concommand.Add("rads_set_internal_bleeding", function(ply, cmd, args)
	if not SERVER or not ply:IsAdmin() then return end
	
	local intensity = tonumber(args[1]) or 50
	intensity = math.Clamp(intensity, 0, 100)
	
	local targetPly = ply
	if args[2] then
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Name()), string.lower(args[2])) then
				targetPly = p
				break
			end
		end
	end
	
	if IsValid(targetPly) then
		-- Initialize organs if not present
		targetPly.Organs = targetPly.Organs or {
			["brain"] = 1,
			["heart"] = 1,
			["lungs"] = 1,
			["liver"] = 1,
			["stomach"] = 1,
			["intestines"] = 1,
			["spine"] = 1
		}
		
		-- Damage organs to achieve the desired intensity based on max health values
		local maxHealth = {
			["liver"] = 15,
			["stomach"] = 15,
			["intestines"] = 30,
			["heart"] = 9
		}
		
		local targetDamage = intensity / 100
		targetPly.Organs["liver"] = math.max(0, maxHealth["liver"] * (1 - targetDamage * 0.4))
		targetPly.Organs["stomach"] = math.max(0, maxHealth["stomach"] * (1 - targetDamage * 0.3))
		targetPly.Organs["intestines"] = math.max(0, maxHealth["intestines"] * (1 - targetDamage * 0.2))
		targetPly.Organs["heart"] = math.max(0, maxHealth["heart"] * (1 - targetDamage * 0.1))
		
		targetPly.InternalBleedingIntensity = intensity
		ply:ChatPrint("Set internal bleeding intensity to " .. intensity .. " for " .. targetPly:Name())
	else
		ply:ChatPrint("Player not found")
	end
end)

concommand.Add("rads_internal_bleeding_info", function(ply, cmd, args)
	if not SERVER or not ply:IsAdmin() then return end
	
	local targetPly = ply
	if args[1] then
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Name()), string.lower(args[1])) then
				targetPly = p
				break
			end
		end
	end
	
	if IsValid(targetPly) then
		local intensity = targetPly.InternalBleedingIntensity or 0
		local nextVomit = targetPly.NextVomitTime or 0
		local timeToVomit = math.max(0, nextVomit - CurTime())
		
		ply:ChatPrint("=== Internal Bleeding Info for " .. targetPly:Name() .. " ===")
		ply:ChatPrint("Intensity: " .. math.Round(intensity, 2) .. "/100")
		ply:ChatPrint("Time to next vomit: " .. math.Round(timeToVomit, 1) .. " seconds")
		ply:ChatPrint("Blood: " .. (targetPly.Blood or 5000))
		
		-- Show organ status
		if targetPly.Organs then
			ply:ChatPrint("=== Organ Status ===")
			for organ, health in pairs(targetPly.Organs) do
				ply:ChatPrint(organ .. ": " .. math.Round(health * 100, 1) .. "%")
			end
		end
	else
		ply:ChatPrint("Player not found")
	end
end)

-- Debug command to damage specific organs
concommand.Add("rads_damage_organ", function(ply, cmd, args)
	if not SERVER or not ply:IsAdmin() then return end
	
	local organName = args[1]
	local damage = tonumber(args[2]) or 0.5
	local targetName = args[3]
	
	if not organName then
		ply:ChatPrint("Usage: rads_damage_organ <organ> [damage] [player]")
		ply:ChatPrint("Organs: brain, heart, lungs, liver, stomach, intestines, spine")
		return
	end
	
	local targetPly = ply
	if targetName then
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Name()), string.lower(targetName)) then
				targetPly = p
				break
			end
		end
	end
	
	if IsValid(targetPly) then
		-- Initialize organs if not present
		targetPly.Organs = targetPly.Organs or {
			["brain"] = 1,
			["heart"] = 1,
			["lungs"] = 1,
			["liver"] = 1,
			["stomach"] = 1,
			["intestines"] = 1,
			["spine"] = 1
		}
		
		if targetPly.Organs[organName] then
			targetPly.Organs[organName] = math.max(0, targetPly.Organs[organName] - damage)
			ply:ChatPrint("Damaged " .. organName .. " by " .. damage .. " for " .. targetPly:Name())
			ply:ChatPrint("New " .. organName .. " health: " .. math.Round(targetPly.Organs[organName] * 100, 1) .. "%")
		else
			ply:ChatPrint("Invalid organ name: " .. organName)
		end
	else
		ply:ChatPrint("Player not found")
	end
end)

-- Compatibility hooks for fakerb.lua ragdoll system
-- Transfer wound positions when player becomes ragdoll
hook.Add("RADS_Ready", "TransferWoundsToRagdoll", function(rag)
	local owner = rag:GetNWEntity("owner")
	if IsValid(owner) and owner:IsPlayer() then
		-- Store wound positions for ragdoll state with full data including blood stacking and bone info
		if owner.WoundPositions and #owner.WoundPositions > 0 then
			owner.StoredWoundPositions = {}
			for _, wound in ipairs(owner.WoundPositions) do
				-- Deep copy wound data including blood stacking properties and bone information
				table.insert(owner.StoredWoundPositions, {
					pos = wound.pos,
					playerPos = wound.playerPos,
					relativePos = wound.relativePos,
					damage = wound.damage,
					time = wound.time,
					bloodStack = wound.bloodStack or 0,
					nextBleed = wound.nextBleed,
					nextStack = wound.nextStack,
					boneName = wound.boneName or "", -- Store bone name for accurate ragdoll mapping
					hitGroup = wound.hitGroup or HITGROUP_GENERIC -- Store hit group for reference
				})
			end
		end
	end
end)

-- Transfer wound positions back when player gets up from ragdoll
hook.Add("Player Think", "TransferWoundsFromRagdoll", function(ply, time)
	-- Check if player just got up from ragdoll state
	if ply.wasRagdolled and not ply:IsRag() then
		-- Restore wound positions from stored data and update player position
		if ply.StoredWoundPositions and #ply.StoredWoundPositions > 0 then
			ply.WoundPositions = {}
			local currentPlayerPos = ply:GetPos()
			for _, wound in ipairs(ply.StoredWoundPositions) do
				-- Update wound position based on new player position with blood stacking data and bone info
				table.insert(ply.WoundPositions, {
					pos = currentPlayerPos + wound.relativePos,
					playerPos = currentPlayerPos,
					relativePos = wound.relativePos,
					damage = wound.damage,
					time = wound.time,
					bloodStack = wound.bloodStack or 0,
					nextBleed = wound.nextBleed,
					nextStack = wound.nextStack,
					boneName = wound.boneName or "", -- Restore bone name for continued accurate positioning
					hitGroup = wound.hitGroup or HITGROUP_GENERIC -- Restore hit group for reference
				})
			end
			-- Clear stored wounds after transfer
			ply.StoredWoundPositions = {}
		end
		ply.wasRagdolled = false
	elseif ply:IsRag() then
		ply.wasRagdolled = true
	end
end)