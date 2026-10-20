-- Status Check System
surface.CreateFont("StatusCheckFont", {
    font = "Coolvetica",
    extended = true,
    size = 22,
    weight = 600,
    antialias = true,
})

local showStatusText = false
local statusTextAlpha = 0
local targetRagdoll = nil
local lastRagdollCheck = 0
local lastStatusCheck = 0
local statusCheckCooldown = 1.0

-- Check if player is looking at a ragdoll within range
local function CheckRagdollInRange()
    if CurTime() - lastRagdollCheck < 0.1 then return end
    lastRagdollCheck = CurTime()
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 150,
        filter = ply
    })
    
    if IsValid(tr.Entity) and tr.Entity:IsRagdoll() then
        local owner = tr.Entity:GetNWEntity('owner') or tr.Entity:GetNWEntity('deadbodyowner')
        if IsValid(owner) and owner:IsPlayer() then
            local distance = ply:GetPos():Distance(tr.Entity:GetPos())
            if distance <= 100 then
                showStatusText = true
                targetRagdoll = tr.Entity
                return true
            end
        end
    end
    
    showStatusText = false
    targetRagdoll = nil
    return false
end

-- Draw status check prompt text
local function DrawStatusPrompt()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetNWBool('radsfa') then
        statusTextAlpha = 0
        return
    end
    
    if not showStatusText then
        statusTextAlpha = math.max(0, statusTextAlpha - FrameTime() * 500)
    else
        statusTextAlpha = math.min(255, statusTextAlpha + FrameTime() * 500)
    end
    
    if statusTextAlpha > 0 then
        local text = "[RMB + R] Check status"
        local textColor = Color(255, 255, 255, statusTextAlpha)
        local outlineColor = Color(0, 0, 0, statusTextAlpha * 0.7)
        local scrw, scrh = ScrW(), ScrH()
        local x, y = scrw/2, scrh/2 + 130
        
        -- Draw outline
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    draw.SimpleText(text, "StatusCheckFont", x + dx, y + dy, outlineColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
        
        -- Draw main text
        draw.SimpleText(text, "StatusCheckFont", x, y, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

net.Receive("rads.bloodcheck", function()
    local b = net.ReadInt(14)
    if b < 0 then b = b + 16384 end
    chat.AddText(Color(255, 255, 255), tostring(b))
end)

function CheckBlood() -- function CheckBlood() --     local tr = util.TraceLine({ --         start = LocalPlayer():GetShootPos(), --         endpos = LocalPlayer():GetShootPos() + LocalPlayer():GetAimVector() * 200, --         filter = function(ent) --             if ent:IsValid() and ent:IsRagdoll() then --                 local owner = ent:GetNWEntity('owner') --                 if IsValid(owner) and owner:IsPlayer() then --                     chat.AddText(Color(255,255,255),"Примерная кровь: "..ent.Blood + math.random(400,150)) --                 end --                 return true --             end --             return false --         end --     }) -- end
    local tr = util.TraceLine({
        start = LocalPlayer():GetShootPos(),
        endpos = LocalPlayer():GetShootPos() + LocalPlayer():GetAimVector() * 200,
        filter = function(ent)
            if ent:IsValid() and ent:IsRagdoll() then
                local owner = ent:GetNWEntity('owner')
                if IsValid(owner) and owner:IsPlayer() then
                    net.Start("rads.bloodcheck")
                    net.WriteEntity(ent)
                    net.SendToServer()
                end
                return true
            end
            return false
        end
    })
end

-- Enhanced status check function
function CheckPlayerStatus()
    if not IsValid(targetRagdoll) then return end
    if CurTime() - lastStatusCheck < statusCheckCooldown then return end
    
    lastStatusCheck = CurTime()
    
    local owner = targetRagdoll:GetNWEntity('owner')
    local deadOwner = targetRagdoll:GetNWEntity('deadbodyowner')
    
    -- Debug info
    if GetConVar("developer"):GetInt() > 0 then
        print("[CLIENT DEBUG] Checking ragdoll - Owner: " .. tostring(IsValid(owner)) .. ", DeadOwner: " .. tostring(IsValid(deadOwner)))
    end
    
    if IsValid(deadOwner) and deadOwner:IsPlayer() then
        -- Player is dead - use deadbodyowner
        if GetConVar("developer"):GetInt() > 0 then
            print("[CLIENT DEBUG] Dead body detected")
        end
        chat.AddText(Color(255, 100, 100), "No Pulse")
        chat.AddText(Color(255, 100, 100), "Not Breathing")
        chat.AddText(Color(255, 100, 100), "No Reaction")
    elseif IsValid(owner) and owner:IsPlayer() then
        -- Player is alive but unconscious
        -- FIXED: Get pulse from networked value
        local pulse = owner:GetNWInt("PlayerPulse", owner.pulse or 70)
        local health = owner:Health()
        local isDead = health <= 0
        -- FIXED: Check networked Otrub value
        local isUnconscious = owner:GetNWBool("Otrub", false)
        
        if GetConVar("developer"):GetInt() > 0 then
            print("[CLIENT DEBUG] Living player - HP: " .. health .. ", Pulse: " .. pulse .. ", Otrub: " .. tostring(isUnconscious) .. " (networked)")
        end
        
        -- If player is dead but still has owner, treat as dead
        if isDead then
            chat.AddText(Color(255, 100, 100), "No Pulse")
            chat.AddText(Color(255, 100, 100), "Not Breathing")
            chat.AddText(Color(255, 100, 100), "No Reaction")
            return
        end
        
        -- Get organ health
        local leftLungHealth = (owner.Organs and owner.Organs['left_lung']) or 5
        local rightLungHealth = (owner.Organs and owner.Organs['right_lung']) or 5
        local heartHealth = (owner.Organs and owner.Organs['heart']) or 9
        
        if GetConVar("developer"):GetInt() > 0 then
            print("[CLIENT DEBUG] Organs - Heart: " .. heartHealth .. ", Left Lung: " .. leftLungHealth .. ", Right Lung: " .. rightLungHealth)
        end
        
        -- Pulse status (based on heart health and pulse value)
        if heartHealth <= 0 or pulse <= 0 then
            chat.AddText(Color(255, 100, 100), "No Pulse")
        elseif pulse >= 130 then
            chat.AddText(Color(255, 200, 100), "Has High Pulse")
        elseif pulse >= 60 then
            chat.AddText(Color(100, 255, 100), "Has Normal Pulse")
        elseif pulse >= 30 and pulse < 60 then
            chat.AddText(Color(255, 150, 100), "Has Low Pulse")
        else
            chat.AddText(Color(255, 100, 100), "No Pulse")
        end
        
        -- Breathing status (based on lung health)
        if leftLungHealth <= 0 and rightLungHealth <= 0 then
            chat.AddText(Color(255, 100, 100), "Not Breathing")
        else
            chat.AddText(Color(100, 255, 100), "Breathing")
        end
        
        -- Consciousness status (based on networked Otrub variable)
        if GetConVar("developer"):GetInt() > 0 then
            print("[CLIENT DEBUG] Consciousness check - Otrub: " .. tostring(isUnconscious) .. " (networked), isUnconscious: " .. tostring(isUnconscious))
        end
        if isUnconscious then
            chat.AddText(Color(255, 150, 100), "No Reaction")
        else
            chat.AddText(Color(100, 255, 100), "Has Reaction")
        end
    else
        if GetConVar("developer"):GetInt() > 0 then
            print("[CLIENT DEBUG] No valid owner found")
        end
        chat.AddText(Color(255, 100, 100), "[NO OWNER] No Pulse")
        chat.AddText(Color(255, 100, 100), "[NO OWNER] Not Breathing")
        chat.AddText(Color(255, 100, 100), "[NO OWNER] No Reaction")
    end
end

function CheckPulseAndLink()
    CheckPlayerStatus()
end

function LOOT()
    local tr = util.TraceLine({
        start = LocalPlayer():GetShootPos(),
        endpos = LocalPlayer():GetShootPos() + LocalPlayer():GetAimVector() * 200,
        filter = function(ent)
            if ent:IsValid() and ent:IsRagdoll() then
                local owner = ent:GetNWEntity('owner')
                if IsValid(owner) and owner:IsPlayer() then
                    net.Start("RequestRagdollInfo")
                    net.WriteEntity(ent)
                    net.SendToServer()
                else
                    chat.AddText(Color(255, 255, 255), "It is impossible to fill the emptiness. ")
                end
                return true
            end
            return false
        end
    })
end

function IsPlayerLookingAtRagdoll()
    local tr = util.TraceLine({
        start = LocalPlayer():GetShootPos(),
        endpos = LocalPlayer():GetShootPos() + LocalPlayer():GetAimVector() * 200,
        filter = function(ent)
            if ent:IsValid() and ent:IsRagdoll() then
                net.Start("RequestRagdollInfo")
                net.WriteEntity(ent)
                net.SendToServer()
                return true
            end
            return false
        end
    })
    return tr and tr.Hit and tr.Entity:IsValid() and tr.Entity:IsRagdoll()
end

-- Input handling for RMB + R status check
hook.Add("Think", "StatusCheckInput", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetNWBool('radsfa') then return end
    
    CheckRagdollInRange()
    
    local holdingRMB = input.IsMouseDown(MOUSE_RIGHT)
    local holdingR = input.IsKeyDown(KEY_R)
    
    if holdingRMB and holdingR and showStatusText and IsValid(targetRagdoll) then
        CheckPlayerStatus()
    end
end)

-- Optimized status check system with performance scaling
local lastStatusUpdate = 0
local statusUpdateInterval = 0.1 -- Base 10fps
-- Status check menu has been removed as requested

-- HUD Paint hook for status text
hook.Add("HUDPaint", "DrawStatusPrompt", function()
    -- Don't run if spawnmenu is open
    if g_SpawnMenu and g_SpawnMenu:IsVisible() then return end
    
    -- Don't interfere with brain damage overlays
    local ply = LocalPlayer()
    if IsValid(ply) and ply.BrainDamageFXActive then
        return
    end
    
    DrawStatusPrompt()
end)
-- Status check system implementation complete