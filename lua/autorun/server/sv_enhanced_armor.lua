-- Enhanced Armor Protection System
-- Integrates with JMod armor to provide better protection and organ-specific coverage

if not SERVER then return end

-- Armor slot to organ mapping
local ArmorOrganMapping = {
    ["head"] = {"skull", "brain", "jaw"},
    ["eyes"] = {"skull", "brain"},
    ["mouthnose"] = {"skull", "jaw"},
    ["ears"] = {"skull"},
    ["torso"] = {"heart", "left_lung", "right_lung", "liver", "stomach", "ribs", "upper_spine"},
    ["pelvis"] = {"intestines", "bladder", "lower_spine"},
    ["leftarm"] = {},
    ["rightarm"] = {},
    ["leftleg"] = {"femoral_artery_l", "popliteal_artery_l"},
    ["rightleg"] = {"femoral_artery_r", "popliteal_artery_r"}
}

-- Damage type protection multipliers for different armor types
local ArmorProtectionProfiles = {
    ["BasicArmorProtectionProfile"] = {
        [DMG_BULLET] = 0.4,
        [DMG_BUCKSHOT] = 0.5,
        [DMG_CLUB] = 0.6,
        [DMG_SLASH] = 0.7,
        [DMG_BLAST] = 0.8,
        [DMG_BURN] = 0.9,
        [DMG_GENERIC] = 0.7
    },
    ["PoorArmorProtectionProfile"] = {
        [DMG_BULLET] = 0.7,
        [DMG_BUCKSHOT] = 0.8,
        [DMG_CLUB] = 0.8,
        [DMG_SLASH] = 0.9,
        [DMG_BLAST] = 0.9,
        [DMG_BURN] = 0.95,
        [DMG_GENERIC] = 0.85
    },
    ["NonArmorProtectionProfile"] = {
        [DMG_BULLET] = 0.95,
        [DMG_BUCKSHOT] = 0.95,
        [DMG_CLUB] = 0.9,
        [DMG_SLASH] = 0.85,
        [DMG_BLAST] = 0.98,
        [DMG_BURN] = 0.8,
        [DMG_GENERIC] = 0.9
    }
}

-- Function to get armor protection for a specific hitgroup
local function GetArmorProtectionForHitgroup(target, ply, hitgroup, damageType)
    local protection = 1.0
    local hitArmorSlots = {}
    
    -- Map hitgroup to armor slots
    if hitgroup == HITGROUP_HEAD then
        hitArmorSlots = {"head", "eyes", "mouthnose", "ears"}
    elseif hitgroup == HITGROUP_CHEST then
        hitArmorSlots = {"torso"}
    elseif hitgroup == HITGROUP_STOMACH then
        hitArmorSlots = {"torso", "pelvis"}
    elseif hitgroup == HITGROUP_LEFTARM then
        hitArmorSlots = {"leftarm"}
    elseif hitgroup == HITGROUP_RIGHTARM then
        hitArmorSlots = {"rightarm"}
    elseif hitgroup == HITGROUP_LEFTLEG then
        hitArmorSlots = {"leftleg"}
    elseif hitgroup == HITGROUP_RIGHTLEG then
        hitArmorSlots = {"rightleg"}
    end
    
    -- Check armor based on target type
    if target:GetClass() == "prop_ragdoll" then
        -- For ragdolls, check armor entities attached to the ragdoll
        if target.armors then
            for _, armorEnt in pairs(target.armors) do
                if IsValid(armorEnt) and armorEnt.armorID then
                    local armorData = JMod.ArmorTable[armorEnt.armorID]
                    if armorData then
                        -- Check if this armor protects the hit area
                        local armorSlot = armorData.slot
                        if table.HasValue(hitArmorSlots, armorSlot) then
                            local protectionProfile = armorData.def
                            
                            if ArmorProtectionProfiles[protectionProfile] then
                                local damageProtection = ArmorProtectionProfiles[protectionProfile][damageType]
                                if damageProtection then
                                    -- Get durability from armor entity
                                    local currentDur = armorEnt:GetNWFloat("EZarmorDur", armorData.dur)
                                    local durabilityFactor = math.max(0.1, currentDur / armorData.dur)
                                    local actualProtection = damageProtection + (1 - damageProtection) * (1 - durabilityFactor)
                                    protection = math.min(protection, actualProtection)
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        -- For standing players, check EZarmor.items
        if IsValid(ply) and ply.EZarmor and ply.EZarmor.items then
            for _, slot in ipairs(hitArmorSlots) do
                local armorInfo = ply.EZarmor.items[slot]
                if armorInfo and armorInfo.name and JMod.ArmorTable[armorInfo.name] then
                    local armorData = JMod.ArmorTable[armorInfo.name]
                    local protectionProfile = armorData.def
                    
                    if ArmorProtectionProfiles[protectionProfile] then
                        local damageProtection = ArmorProtectionProfiles[protectionProfile][damageType]
                        if damageProtection then
                            -- Apply durability scaling - less protection as armor degrades
                            local durabilityFactor = math.max(0.1, armorInfo.dur / armorData.dur)
                            local actualProtection = damageProtection + (1 - damageProtection) * (1 - durabilityFactor)
                            protection = math.min(protection, actualProtection)
                        end
                    end
                end
            end
        end
    end
    
    return protection
end

-- Function to trigger armor impact effects
local function TriggerArmorImpactEffects(target, hitPos, damageAmount)
    if not IsValid(target) then return end
    
    -- Create metal impact sound
    local impactSounds = {
        "physics/metal/metal_solid_impact_bullet1.wav",
        "physics/metal/metal_solid_impact_bullet2.wav",
        "physics/metal/metal_solid_impact_bullet3.wav",
        "physics/metal/metal_solid_impact_hard1.wav",
        "physics/metal/metal_solid_impact_hard2.wav",
        "physics/metal/metal_solid_impact_hard3.wav"
    }
    
    local sound = table.Random(impactSounds)
    local volume = math.Clamp(damageAmount / 50, 0.3, 1.0)
    local pitch = math.random(90, 110)
    
    -- Emit sound from the target (ragdoll or player)
    target:EmitSound(sound, 75, pitch, volume)
    
    -- Create spark particle effect at exact hit position
    local effectData = EffectData()
    effectData:SetOrigin(hitPos)
    effectData:SetNormal(Vector(0, 0, 1))
    effectData:SetMagnitude(math.Clamp(damageAmount / 25, 1, 4))
    effectData:SetScale(math.Clamp(damageAmount / 30, 0.5, 2.0))
    util.Effect("MetalSpark", effectData)
    
    -- Additional ricochet effect for high damage
    if damageAmount > 30 then
        target:EmitSound("weapons/fx/rics/ric" .. math.random(1, 5) .. ".wav", 70, math.random(95, 105), 0.8)
    end
end

-- Function to damage armor durability
local function DamageArmorDurability(target, ply, hitgroup, damageAmount)
    local hitArmorSlots = {}
    
    -- Map hitgroup to armor slots
    if hitgroup == HITGROUP_HEAD then
        hitArmorSlots = {"head", "eyes", "mouthnose", "ears"}
    elseif hitgroup == HITGROUP_CHEST then
        hitArmorSlots = {"torso"}
    elseif hitgroup == HITGROUP_STOMACH then
        hitArmorSlots = {"torso", "pelvis"}
    elseif hitgroup == HITGROUP_LEFTARM then
        hitArmorSlots = {"leftarm"}
    elseif hitgroup == HITGROUP_RIGHTARM then
        hitArmorSlots = {"rightarm"}
    elseif hitgroup == HITGROUP_LEFTLEG then
        hitArmorSlots = {"leftleg"}
    elseif hitgroup == HITGROUP_RIGHTLEG then
        hitArmorSlots = {"rightleg"}
    end
    
    local durabilityDamage = math.ceil(damageAmount * 0.1) -- 10% of damage dealt to armor
    
    -- Handle armor damage based on target type
    if target:GetClass() == "prop_ragdoll" then
        -- For ragdolls, damage armor entities attached to the ragdoll
        if target.armors then
            for _, armorEnt in pairs(target.armors) do
                if IsValid(armorEnt) and armorEnt.armorID then
                    local armorData = JMod.ArmorTable[armorEnt.armorID]
                    if armorData then
                        local armorSlot = armorData.slot
                        if table.HasValue(hitArmorSlots, armorSlot) then
                            local currentDur = armorEnt:GetNWFloat("EZarmorDur", armorData.dur)
                            local newDur = math.max(0, currentDur - durabilityDamage)
                            armorEnt:SetNWFloat("EZarmorDur", newDur)
                            
                            -- Remove armor if durability reaches 0
                            if newDur <= 0 then
                                if IsValid(ply) then
                                    ply:ChatPrint("Your " .. armorData.name .. " has been destroyed!")
                                    ply:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 75, 100, 0.8)
                                end
                                armorEnt:Remove()
                            elseif newDur <= armorData.dur * 0.2 then
                                -- Warn when armor is critically damaged
                                if not armorEnt.warnedCritical and IsValid(ply) then
                                    ply:ChatPrint("Your " .. armorData.name .. " is critically damaged!")
                                    armorEnt.warnedCritical = true
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        -- For standing players, damage EZarmor.items
        if IsValid(ply) and ply.EZarmor and ply.EZarmor.items then
            for _, slot in ipairs(hitArmorSlots) do
                local armorInfo = ply.EZarmor.items[slot]
                if armorInfo and armorInfo.name and JMod.ArmorTable[armorInfo.name] then
                    local armorData = JMod.ArmorTable[armorInfo.name]
                    
                    armorInfo.dur = math.max(0, armorInfo.dur - durabilityDamage)
                    
                    -- Remove armor if durability reaches 0
                    if armorInfo.dur <= 0 then
                        ply.EZarmor.items[slot] = nil
                        ply:ChatPrint("Your " .. armorData.name .. " has been destroyed!")
                        ply:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 75, 100, 0.8)
                    elseif armorInfo.dur <= armorData.dur * 0.2 then
                        -- Warn when armor is critically damaged
                        if not armorInfo.warnedCritical then
                            ply:ChatPrint("Your " .. armorData.name .. " is critically damaged!")
                            armorInfo.warnedCritical = true
                        end
                    end
                    
                    -- Sync armor changes
                    if JMod and JMod.EZarmorSync then
                        JMod.EZarmorSync(ply)
                    end
                end
            end
        end
    end
end

-- Main armor protection hook - runs before the main damage hook
hook.Add("EntityTakeDamage", "RADS_EnhancedArmorProtection", function(target, dmginfo)
    -- Only process player damage
    if not IsValid(target) then return end
    
    local ply = target
    if target:GetClass() == "prop_ragdoll" then
        ply = target:GetNWEntity("owner")
        if not IsValid(ply) or not ply:IsPlayer() then return end
    elseif not target:IsPlayer() then
        return
    end
    
    -- Skip if player is ghosted or has god mode
    if ply:GetNWBool("gh.Ghosted", false) or ply:HasGodMode() then return end
    
    -- Get damage information
    local damage = dmginfo:GetDamage()
    local damageType = dmginfo:GetDamageType()
    local hitPos = dmginfo:GetDamagePosition()
    
    -- If no hit position is available, use target center
    if hitPos == Vector(0, 0, 0) then
        if target:GetClass() == "prop_ragdoll" then
            hitPos = target:GetPos()
        else
            hitPos = target:GetPos() + target:OBBCenter()
        end
    end
    
    -- Determine hitgroup - try multiple methods
    local hitgroup = HITGROUP_GENERIC
    if ply.LastHitGroup then
        hitgroup = ply.LastHitGroup
    elseif target.LastHitGroup then
        hitgroup = target.LastHitGroup
    else
        -- Try to determine hitgroup from hit position for ragdolls
        if target:GetClass() == "prop_ragdoll" then
            local headPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Head1") or 0)
            local chestPos = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Spine2") or 0)
            
            if headPos and hitPos:Distance(headPos) < 15 then
                hitgroup = HITGROUP_HEAD
            elseif chestPos and hitPos:Distance(chestPos) < 25 then
                hitgroup = HITGROUP_CHEST
            end
        end
    end
    
    -- Get armor protection
    local protection = GetArmorProtectionForHitgroup(target, ply, hitgroup, damageType)
    
    -- Always trigger effects if there's any armor (even if no protection)
    local hasArmor = false
    if target:GetClass() == "prop_ragdoll" then
        hasArmor = target.armors and table.Count(target.armors) > 0
    else
        hasArmor = IsValid(ply) and ply.EZarmor and ply.EZarmor.items and table.Count(ply.EZarmor.items) > 0
    end
    
    -- Apply protection if armor exists
    if protection < 1.0 then
        local originalDamage = damage
        local newDamage = damage * protection
        local blockedDamage = originalDamage - newDamage
        
        -- Apply reduced damage
        dmginfo:SetDamage(newDamage)
        
        -- Trigger armor effects
        TriggerArmorImpactEffects(target, hitPos, blockedDamage)
        
        -- Damage armor durability
        DamageArmorDurability(target, ply, hitgroup, originalDamage)
        
        -- Debug output
        if GetConVar("developer") and GetConVar("developer"):GetInt() > 0 then
            print(string.format("[Enhanced Armor] %s took %.1f damage (%.1f blocked by armor)", 
                ply:Name(), newDamage, blockedDamage))
        end
    elseif hasArmor then
        -- Trigger effects even if no protection (user requested effects on any damage)
        TriggerArmorImpactEffects(target, hitPos, damage * 0.3) -- Reduced effect for unprotected hits
    end
end)

-- Console command for testing armor protection
concommand.Add("rads_test_armor_protection", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    if ply.EZarmor and ply.EZarmor.items then
        ply:ChatPrint("Current armor:")
        for slot, armorInfo in pairs(ply.EZarmor.items) do
            if armorInfo and armorInfo.name then
                local armorData = JMod.ArmorTable[armorInfo.name]
                if armorData then
                    ply:ChatPrint(string.format("  %s: %s (%.1f/%.1f durability)", 
                        slot, armorData.name, armorInfo.dur, armorData.dur))
                end
            end
        end
    else
        ply:ChatPrint("No armor equipped.")
    end
end)

print("[Enhanced Armor] Armor protection system loaded successfully!")