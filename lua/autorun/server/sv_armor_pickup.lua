-- Armor Pickup System
-- Allows players to pick up armor from ragdolls using the Use key

if not SERVER then return end

-- Function to check if player can pick up armor
local function CanPickupArmor(ply, armorEnt)
    if not IsValid(ply) or not IsValid(armorEnt) then return false end
    if not ply:IsPlayer() or not ply:Alive() then return false end
    if ply:GetNWBool("gh.Ghosted", false) then return false end
    
    -- Check if it's actually an armor entity
    if armorEnt:GetClass() ~= "ent_jack_gmod_ezarmor" then return false end
    
    -- Check if armor is attached to a ragdoll
    if not armorEnt.ragdoll or not IsValid(armorEnt.ragdoll) then return false end
    
    return true
end

-- Function to get armor slot from JMod armor name
local function GetArmorSlotFromName(armorName)
    if not armorName or not JMod or not JMod.ArmorTable then return nil end
    
    local armorData = JMod.ArmorTable[armorName]
    if not armorData or not armorData.eff then return nil end
    
    -- Return the first affected slot
    for slot, _ in pairs(armorData.eff) do
        return slot
    end
    
    return nil
end

-- Function to check if player already has armor in slot
local function HasArmorInSlot(ply, slot)
    if not IsValid(ply) or not slot then return false end
    if not ply.EZarmor or not ply.EZarmor.items then return false end
    
    return ply.EZarmor.items[slot] ~= nil
end

-- Function to equip armor to player
local function EquipArmorToPlayer(ply, armorEnt)
    if not IsValid(ply) or not IsValid(armorEnt) then return false end
    
    -- Get armor information
    local armorName = armorEnt.EZname or armorEnt:GetNWString("EZname", "")
    if armorName == "" then return false end
    
    local armorData = JMod.ArmorTable[armorName]
    if not armorData then return false end
    
    -- Get armor slot
    local slot = GetArmorSlotFromName(armorName)
    if not slot then return false end
    
    -- Check if player already has armor in this slot
    if HasArmorInSlot(ply, slot) then
        ply:ChatPrint("You already have armor equipped in the " .. slot .. " slot!")
        return false
    end
    
    -- Initialize player armor table if needed
    if not ply.EZarmor then
        ply.EZarmor = {items = {}}
    elseif not ply.EZarmor.items then
        ply.EZarmor.items = {}
    end
    
    -- Get armor durability
    local durability = armorEnt.EZdurability or armorData.dur or 100
    
    -- Equip armor to player
    ply.EZarmor.items[slot] = {
        name = armorName,
        dur = durability
    }
    
    -- Sync armor with JMod system
    if JMod and JMod.EZarmorSync then
        JMod.EZarmorSync(ply)
    end
    
    -- Notify player
    ply:ChatPrint("Equipped " .. armorData.name .. " (" .. math.ceil(durability) .. "/" .. armorData.dur .. " durability)")
    
    -- Play equip sound
    ply:EmitSound("items/ammo_pickup.wav", 60, 120, 0.8)
    
    return true
end

-- Function to handle armor pickup from ragdoll
local function HandleArmorPickup(ply, armorEnt)
    if not CanPickupArmor(ply, armorEnt) then return end
    
    -- Try to equip armor
    if EquipArmorToPlayer(ply, armorEnt) then
        -- Remove armor from ragdoll
        local ragdoll = armorEnt.ragdoll
        if IsValid(ragdoll) and ragdoll.armors then
            for i, armor in ipairs(ragdoll.armors) do
                if armor == armorEnt then
                    table.remove(ragdoll.armors, i)
                    break
                end
            end
        end
        
        -- Remove the armor entity
        armorEnt:Remove()
    end
end

-- Hook into player use to handle armor pickup
hook.Add("PlayerUse", "RADS_ArmorPickup", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    
    -- Check if it's an armor entity on a ragdoll
    if ent:GetClass() == "ent_jack_gmod_ezarmor" and ent.ragdoll then
        HandleArmorPickup(ply, ent)
        return true -- Prevent default use behavior
    end
end)

-- Enhanced armor creation function for ragdolls
-- This modifies the existing CreateArmor function to make armor pickupable
local originalCreateArmor = CreateArmor
if originalCreateArmor then
    function CreateArmor(rag, info)
        local armorEnt = originalCreateArmor(rag, info)
        
        if IsValid(armorEnt) then
            -- Make armor pickupable by overriding the Use function
            function armorEnt:Use(activator, caller)
                if IsValid(activator) and activator:IsPlayer() then
                    HandleArmorPickup(activator, self)
                end
            end
            
            -- Add visual indicator that armor can be picked up
            armorEnt:SetNWBool("CanPickup", true)
        end
        
        return armorEnt
    end
else
    -- If CreateArmor doesn't exist, create a hook to modify armor entities
    hook.Add("OnEntityCreated", "RADS_MakeArmorPickupable", function(ent)
        if not IsValid(ent) then return end
        
        timer.Simple(0.1, function()
            if IsValid(ent) and ent:GetClass() == "ent_jack_gmod_ezarmor" and ent.ragdoll then
                -- Make armor pickupable
                function ent:Use(activator, caller)
                    if IsValid(activator) and activator:IsPlayer() then
                        HandleArmorPickup(activator, self)
                    end
                end
                
                -- Add visual indicator
                ent:SetNWBool("CanPickup", true)
            end
        end)
    end)
end

-- Console command for testing armor pickup
concommand.Add("rads_test_armor_pickup", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    local trace = ply:GetEyeTrace()
    if IsValid(trace.Entity) and trace.Entity:GetClass() == "ent_jack_gmod_ezarmor" then
        ply:ChatPrint("Found armor entity: " .. (trace.Entity.EZname or "Unknown"))
        ply:ChatPrint("Ragdoll: " .. tostring(trace.Entity.ragdoll))
        ply:ChatPrint("Can pickup: " .. tostring(CanPickupArmor(ply, trace.Entity)))
    else
        ply:ChatPrint("No armor entity found in crosshair.")
    end
end)

-- Console command to drop armor
concommand.Add("rads_drop_armor", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    local slot = args[1]
    if not slot then
        ply:ChatPrint("Usage: rads_drop_armor <slot>")
        ply:ChatPrint("Available slots: head, eyes, mouthnose, ears, torso, pelvis, leftarm, rightarm, leftleg, rightleg")
        return
    end
    
    if not ply.EZarmor or not ply.EZarmor.items or not ply.EZarmor.items[slot] then
        ply:ChatPrint("No armor equipped in slot: " .. slot)
        return
    end
    
    local armorInfo = ply.EZarmor.items[slot]
    local armorData = JMod.ArmorTable[armorInfo.name]
    
    if not armorData then
        ply:ChatPrint("Invalid armor data for: " .. armorInfo.name)
        return
    end
    
    -- Create armor entity in front of player
    local pos = ply:GetPos() + ply:GetForward() * 50 + Vector(0, 0, 10)
    local ang = ply:GetAngles()
    
    local armorEnt = ents.Create("ent_jack_gmod_ezarmor")
    if IsValid(armorEnt) then
        armorEnt:SetPos(pos)
        armorEnt:SetAngles(ang)
        armorEnt.EZname = armorInfo.name
        armorEnt.EZdurability = armorInfo.dur
        armorEnt:Spawn()
        armorEnt:Activate()
        
        -- Set model and material
        if armorData.mdl then
            armorEnt:SetModel(armorData.mdl)
        end
        if armorData.mat then
            armorEnt:SetMaterial(armorData.mat)
        end
        
        -- Remove from player
        ply.EZarmor.items[slot] = nil
        
        -- Sync armor changes
        if JMod and JMod.EZarmorSync then
            JMod.EZarmorSync(ply)
        end
        
        ply:ChatPrint("Dropped " .. armorData.name)
        ply:EmitSound("items/ammo_pickup.wav", 60, 80, 0.6)
    end
end)

print("[Enhanced Armor] Armor pickup system loaded successfully!")