-- Hands Weapon Spawn System
-- Automatically gives players the hands weapon on spawn and prevents dropping

if SERVER then
    -- Give hands weapon on player spawn
    hook.Add("PlayerSpawn", "TRAUMA_GiveHandsOnSpawn", function(ply)
        if not IsValid(ply) then return end
        
        -- Check if the system is enabled
        local fistsOnSpawn = GetConVar("rads_fists_on_spawn")
        if not fistsOnSpawn or fistsOnSpawn:GetInt() == 0 then return end
        
        -- Small delay to ensure player is fully spawned
        timer.Simple(0.1, function()
            if IsValid(ply) and ply:Alive() then
                -- Check if player already has the hands weapon
                local hasHands = false
                for _, weapon in pairs(ply:GetWeapons()) do
                    if weapon:GetClass() == "wep_jack_hmcd_hands" then
                        hasHands = true
                        break
                    end
                end
                
                -- Give hands weapon if they don't have it
                if not hasHands then
                    ply:Give("wep_jack_hmcd_hands")
                end
            end
        end)
    end)
    
    -- Prevent dropping the hands weapon
    hook.Add("CanPlayerDropWeapon", "TRAUMA_PreventHandsDrop", function(ply, weapon)
        if not IsValid(ply) or not IsValid(weapon) then return end
        
        -- Check if the system is enabled
        local fistsOnSpawn = GetConVar("rads_fists_on_spawn")
        if not fistsOnSpawn or fistsOnSpawn:GetInt() == 0 then return end
        
        -- Prevent dropping the hands weapon
        if weapon:GetClass() == "wep_jack_hmcd_hands" then
            return false
        end
    end)
    
    -- Ensure hands weapon is always available when system is enabled
    hook.Add("PlayerDeath", "TRAUMA_EnsureHandsOnRespawn", function(victim, inflictor, attacker)
        if not IsValid(victim) then return end
        
        -- Check if the system is enabled
        local fistsOnSpawn = GetConVar("rads_fists_on_spawn")
        if not fistsOnSpawn or fistsOnSpawn:GetInt() == 0 then return end
        
        -- Mark player for hands weapon on next spawn
        victim.NeedsHandsWeapon = true
    end)
    
    -- Give hands weapon back immediately if dropped
    hook.Add("PlayerDroppedWeapon", "TRAUMA_HandsDroppedGiveBack", function(ply, weapon)
        if not IsValid(ply) or not IsValid(weapon) then return end
        
        -- Check if the system is enabled
        local fistsOnSpawn = GetConVar("rads_fists_on_spawn")
        if not fistsOnSpawn or fistsOnSpawn:GetInt() == 0 then return end
        
        -- Check if the dropped weapon is the hands weapon
        if weapon:GetClass() == "wep_jack_hmcd_hands" then
            -- Remove the dropped weapon entity
            timer.Simple(0.1, function()
                if IsValid(weapon) then
                    weapon:Remove()
                end
            end)
            
            -- Give the hands weapon back to the player
            timer.Simple(0.2, function()
                if IsValid(ply) and ply:Alive() then
                    ply:Give("wep_jack_hmcd_hands")
                end
            end)
        end
    end)
end