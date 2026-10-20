-- Client-side Armor Effects
-- Handles visual and audio effects for armor impacts

if not CLIENT then return end

-- Network strings for armor effects
util.AddNetworkString("RADS_ArmorImpact")
util.AddNetworkString("RADS_ArmorBreak")
util.AddNetworkString("RADS_ArmorPickupHint")

-- Armor impact effect
net.Receive("RADS_ArmorImpact", function()
    local pos = net.ReadVector()
    local normal = net.ReadVector()
    local damage = net.ReadFloat()
    local armorType = net.ReadString()
    
    -- Create metal spark effect
    local effectData = EffectData()
    effectData:SetOrigin(pos)
    effectData:SetNormal(normal)
    effectData:SetMagnitude(math.Clamp(damage / 25, 1, 4))
    effectData:SetScale(math.Clamp(damage / 30, 0.5, 2.0))
    util.Effect("MetalSpark", effectData)
    
    -- Additional effects for high damage
    if damage > 30 then
        -- Create additional sparks
        for i = 1, 3 do
            timer.Simple(i * 0.05, function()
                local sparkData = EffectData()
                sparkData:SetOrigin(pos + VectorRand() * 5)
                sparkData:SetNormal(normal + VectorRand() * 0.3)
                sparkData:SetMagnitude(2)
                sparkData:SetScale(1)
                util.Effect("MetalSpark", sparkData)
            end)
        end
    end
    
    -- Screen shake for local player if close enough
    local localPly = LocalPlayer()
    if IsValid(localPly) then
        local distance = localPly:GetPos():Distance(pos)
        if distance < 200 then
            local intensity = math.Clamp((200 - distance) / 200 * damage / 50, 0.1, 2.0)
            util.ScreenShake(pos, intensity, 5, 0.3, 200)
        end
    end
end)

-- Armor break effect
net.Receive("RADS_ArmorBreak", function()
    local pos = net.ReadVector()
    local armorName = net.ReadString()
    
    -- Create explosion effect for armor breaking
    local effectData = EffectData()
    effectData:SetOrigin(pos)
    effectData:SetMagnitude(3)
    effectData:SetScale(1.5)
    util.Effect("Explosion", effectData)
    
    -- Create debris effect
    for i = 1, 8 do
        timer.Simple(i * 0.02, function()
            local debrisData = EffectData()
            debrisData:SetOrigin(pos + VectorRand() * 10)
            debrisData:SetNormal(VectorRand())
            debrisData:SetMagnitude(1)
            debrisData:SetScale(0.5)
            util.Effect("MetalSpark", debrisData)
        end)
    end
end)

-- Armor pickup hint system
local armorPickupHints = {}
local hintFadeTime = 3 -- Seconds to fade out hint

net.Receive("RADS_ArmorPickupHint", function()
    local entIndex = net.ReadUInt(16)
    local armorName = net.ReadString()
    local durability = net.ReadFloat()
    local maxDurability = net.ReadFloat()
    
    armorPickupHints[entIndex] = {
        name = armorName,
        durability = durability,
        maxDurability = maxDurability,
        startTime = CurTime(),
        alpha = 255
    }
end)

-- Draw armor pickup hints
hook.Add("HUDPaint", "RADS_DrawArmorPickupHints", function()
    local localPly = LocalPlayer()
    if not IsValid(localPly) then return end
    
    for entIndex, hint in pairs(armorPickupHints) do
        local ent = Entity(entIndex)
        if IsValid(ent) and ent:GetClass() == "ent_jack_gmod_ezarmor" then
            local pos = ent:GetPos() + Vector(0, 0, 20)
            local screenPos = pos:ToScreen()
            
            if screenPos.visible then
                local distance = localPly:GetPos():Distance(ent:GetPos())
                if distance <= 100 then -- Only show hint when close
                    -- Calculate fade
                    local timeSinceStart = CurTime() - hint.startTime
                    if timeSinceStart > hintFadeTime then
                        armorPickupHints[entIndex] = nil
                        continue
                    end
                    
                    local fadeProgress = math.Clamp(timeSinceStart / hintFadeTime, 0, 1)
                    hint.alpha = 255 * (1 - fadeProgress)
                    
                    -- Draw hint
                    local x, y = screenPos.x, screenPos.y
                    
                    -- Background
                    draw.RoundedBox(4, x - 80, y - 25, 160, 50, Color(0, 0, 0, hint.alpha * 0.7))
                    
                    -- Armor name
                    draw.SimpleText(hint.name, "DermaDefault", x, y - 10, Color(255, 255, 255, hint.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    
                    -- Durability bar
                    local barWidth = 120
                    local barHeight = 8
                    local durabilityPercent = hint.durability / hint.maxDurability
                    
                    -- Background bar
                    draw.RoundedBox(2, x - barWidth/2, y + 5, barWidth, barHeight, Color(100, 100, 100, hint.alpha))
                    
                    -- Durability bar
                    local barColor = Color(255, 255, 255, hint.alpha)
                    if durabilityPercent > 0.6 then
                        barColor = Color(0, 255, 0, hint.alpha) -- Green
                    elseif durabilityPercent > 0.3 then
                        barColor = Color(255, 255, 0, hint.alpha) -- Yellow
                    else
                        barColor = Color(255, 0, 0, hint.alpha) -- Red
                    end
                    
                    draw.RoundedBox(2, x - barWidth/2, y + 5, barWidth * durabilityPercent, barHeight, barColor)
                    
                    -- Use key hint
                    draw.SimpleText("[E] Pick up", "DermaDefault", x, y + 20, Color(200, 200, 200, hint.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        else
            armorPickupHints[entIndex] = nil
        end
    end
end)

-- Enhanced armor status HUD
local function DrawArmorStatus()
    local localPly = LocalPlayer()
    if not IsValid(localPly) or not localPly:Alive() then return end
    if not localPly.EZarmor or not localPly.EZarmor.items then return end
    
    local x, y = 20, ScrH() - 200
    local armorCount = 0
    
    -- Count armor pieces
    for slot, armorInfo in pairs(localPly.EZarmor.items) do
        if armorInfo and armorInfo.name then
            armorCount = armorCount + 1
        end
    end
    
    if armorCount == 0 then return end
    
    -- Background
    draw.RoundedBox(8, x - 10, y - 10, 200, armorCount * 25 + 30, Color(0, 0, 0, 150))
    
    -- Title
    draw.SimpleText("Armor Status", "DermaDefaultBold", x, y, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    y = y + 20
    
    -- Draw each armor piece
    for slot, armorInfo in pairs(localPly.EZarmor.items) do
        if armorInfo and armorInfo.name and JMod and JMod.ArmorTable then
            local armorData = JMod.ArmorTable[armorInfo.name]
            if armorData then
                local durabilityPercent = armorInfo.dur / armorData.dur
                local color = Color(255, 255, 255)
                
                if durabilityPercent <= 0.2 then
                    color = Color(255, 100, 100) -- Red for critical
                elseif durabilityPercent <= 0.5 then
                    color = Color(255, 255, 100) -- Yellow for damaged
                end
                
                -- Armor name and durability
                local text = string.format("%s: %.0f/%.0f", armorData.name, armorInfo.dur, armorData.dur)
                draw.SimpleText(text, "DermaDefault", x, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                
                y = y + 20
            end
        end
    end
end

-- Add armor status to HUD
hook.Add("HUDPaint", "RADS_DrawArmorStatus", DrawArmorStatus)

-- Enhanced crosshair for armor entities
hook.Add("HUDPaint", "RADS_ArmorCrosshair", function()
    local localPly = LocalPlayer()
    if not IsValid(localPly) then return end
    
    local trace = localPly:GetEyeTrace()
    if IsValid(trace.Entity) and trace.Entity:GetClass() == "ent_jack_gmod_ezarmor" and trace.Entity:GetNWBool("CanPickup", false) then
        local distance = localPly:GetPos():Distance(trace.Entity:GetPos())
        if distance <= 100 then
            -- Draw enhanced crosshair
            local x, y = ScrW() / 2, ScrH() / 2
            
            -- Outer ring
            surface.SetDrawColor(255, 255, 255, 200)
            surface.DrawOutlinedCircle(x, y, 20, 2)
            
            -- Inner dot
            surface.SetDrawColor(0, 255, 0, 255)
            surface.DrawOutlinedCircle(x, y, 3, 2)
            
            -- Use hint
            draw.SimpleText("[E] Pick up armor", "DermaDefault", x, y + 30, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end)

-- Console command to toggle armor HUD
CreateConVar("rads_armor_hud", "1", FCVAR_ARCHIVE, "Show armor status HUD")

concommand.Add("rads_toggle_armor_hud", function()
    local current = GetConVar("rads_armor_hud"):GetInt()
    RunConsoleCommand("rads_armor_hud", current == 1 and "0" or "1")
    LocalPlayer():ChatPrint("Armor HUD " .. (current == 1 and "disabled" or "enabled"))
end)

-- Override armor HUD drawing based on ConVar
local originalDrawArmorStatus = DrawArmorStatus
DrawArmorStatus = function()
    if GetConVar("rads_armor_hud"):GetInt() == 1 then
        originalDrawArmorStatus()
    end
end

print("[Enhanced Armor] Client-side armor effects loaded successfully!")