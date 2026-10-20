-- TRAUMA Health System - Health Item Replacement
-- Replaces HL2 health items with TRAUMA medical items when enabled

if SERVER then
    -- Table of TRAUMA medical items to randomly spawn
    local traumaHealthItems = {
        "ent_jack_hmcd_bandage",        -- Small Bandage
        "ent_jack_hmcd_bandagebig",     -- Large Bandage
        "ent_jack_hmcd_medkit",         -- Medkit
        "ent_jack_hmcd_painpills"       -- Painkillers
    }
    
    -- HL2 health items to replace
    local hl2HealthItems = {
        "item_healthkit",
        "item_healthvial",
        "item_battery"
    }
    
    -- Function to check if an entity is an HL2 health item
    local function IsHL2HealthItem(className)
        for _, item in ipairs(hl2HealthItems) do
            if className == item then
                return true
            end
        end
        return false
    end
    
    -- Function to spawn a random TRAUMA medical item
    local function SpawnRandomTraumaItem(pos, ang)
        local randomItem = traumaHealthItems[math.random(1, #traumaHealthItems)]
        local ent = ents.Create(randomItem)
        
        if IsValid(ent) then
            ent:SetPos(pos)
            ent:SetAngles(ang or Angle(0, 0, 0))
            ent:Spawn()
            ent:Activate()
            return ent
        end
        
        return nil
    end
    
    -- Hook into entity creation to replace HL2 health items
    hook.Add("OnEntityCreated", "TRAUMA_ReplaceHealthItems", function(ent)
        -- Wait a tick to ensure the entity is fully initialized
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            
            -- Check if replacement is enabled
            local replaceConVar = GetConVar("rads_replace_health_items")
            if not replaceConVar or replaceConVar:GetInt() == 0 then return end
            
            -- Check if this is an HL2 health item
            local className = ent:GetClass()
            if IsHL2HealthItem(className) then
                -- Get position and angles before removing
                local pos = ent:GetPos()
                local ang = ent:GetAngles()
                
                -- Remove the original entity
                ent:Remove()
                
                -- Spawn a random TRAUMA medical item in its place
                SpawnRandomTraumaItem(pos, ang)
            end
        end)
    end)
    
    -- Function to replace all existing HL2 health items on the map
    local function ReplaceAllMapHealthItems()
        local replaceConVar = GetConVar("rads_replace_health_items")
        if not replaceConVar or replaceConVar:GetInt() == 0 then return end
        
        -- Find and replace existing HL2 health items on the map
        for _, className in ipairs(hl2HealthItems) do
            local entities = ents.FindByClass(className)
            for _, ent in ipairs(entities) do
                if IsValid(ent) then
                    local pos = ent:GetPos()
                    local ang = ent:GetAngles()
                    
                    ent:Remove()
                    SpawnRandomTraumaItem(pos, ang)
                end
            end
        end
    end
    
    -- Hook into map initialization to replace items that exist on map load
    hook.Add("InitPostEntity", "TRAUMA_ReplaceMapHealthItems", function()
        timer.Simple(1, function() -- Wait a bit for map to fully load
            ReplaceAllMapHealthItems()
        end)
    end)
    
    -- Hook into player spawn to check for health items that might spawn when players join
    hook.Add("PlayerSpawn", "TRAUMA_CheckHealthItemsOnSpawn", function(ply)
        timer.Simple(0.5, function() -- Small delay to let any spawn-related entities appear
            ReplaceAllMapHealthItems()
        end)
    end)
    
    -- Periodic check for new health items (every 30 seconds)
    timer.Create("TRAUMA_PeriodicHealthItemCheck", 30, 0, function()
        ReplaceAllMapHealthItems()
    end)
    
    -- Console command for testing
    concommand.Add("rads_test_spawn_trauma_item", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsAdmin() then return end
        
        local tr = ply:GetEyeTrace()
        if tr.Hit then
            SpawnRandomTraumaItem(tr.HitPos + tr.HitNormal * 10, Angle(0, 0, 0))
            ply:ChatPrint("Spawned random TRAUMA medical item")
        end
    end)
end