-- RADS Name Display System
-- Shows player names below screen center when looking at them with fade-in effect

if CLIENT then
    -- Font creation
    surface.CreateFont("RADS_NameDisplay", {
        font = "Coolvetica",
        size = 34,
        weight = 600,
        antialias = true,
        shadow = false
    })
    
    -- Variables for fade effect
    local currentTarget = nil
    local fadeAlpha = 0
    local fadeSpeed = 215 -- Alpha units per second (slower for smoother fade)
    local maxTraceDistance = 100 -- Maximum trace distance
    
    -- Helper function to convert player color vector to Color object
    local function PlayerColorToColor(colorVec)
        if not colorVec or colorVec == Vector(0,0,0) then
            return Color(255, 255, 255, 255) -- Default white
        end
        
        return Color(
            math.Clamp(colorVec.x * 255, 0, 255),
            math.Clamp(colorVec.y * 255, 0, 255),
            math.Clamp(colorVec.z * 255, 0, 255),
            255
        )
    end
    
    -- Function to get player name from entity
    local function GetPlayerName(ent)
        if ent:IsPlayer() then
            return ent:Name()
        elseif ent:IsRagdoll() then
            -- Check if it's a RADS ragdoll
            local owner = ent:GetNWEntity("owner")
            local deadbodyowner = ent:GetNWEntity("deadbodyowner")
            
            if IsValid(owner) and owner:IsPlayer() then
                return owner:Name()
            elseif IsValid(deadbodyowner) and deadbodyowner:IsPlayer() then
                return deadbodyowner:Name()
            end
        end
        
        return nil
    end
    
    -- Function to get player color from entity
    local function GetPlayerColor(ent)
        if ent:IsPlayer() then
            local playerColor = ent:GetPlayerColor()
            return playerColor or Vector(1,1,1)
        elseif ent:IsRagdoll() then
            -- Check if ragdoll has GetPlayerColor function (set by ragplayercolor network message)
            if ent.GetPlayerColor then
                return ent:GetPlayerColor()
            end
            
            -- Fallback to owner's color
            local owner = ent:GetNWEntity("owner")
            local deadbodyowner = ent:GetNWEntity("deadbodyowner")
            
            if IsValid(owner) and owner:IsPlayer() then
                local playerColor = owner:GetPlayerColor()
                return playerColor or Vector(1,1,1)
            elseif IsValid(deadbodyowner) and deadbodyowner:IsPlayer() then
                local playerColor = deadbodyowner:GetPlayerColor()
                return playerColor or Vector(1,1,1)
            end
        end
        
        return Vector(1,1,1) -- Default white
    end
    
    -- Function to find target being looked at
    local function FindLookedAtTarget()
        local localPlayer = LocalPlayer()
        if not IsValid(localPlayer) then return nil end
        
        local eyePos = localPlayer:EyePos()
        local eyeAngles = localPlayer:EyeAngles()
        local eyeDir = eyeAngles:Forward()
        
        -- Perform trace
        local trace = util.TraceLine({
            start = eyePos,
            endpos = eyePos + eyeDir * maxTraceDistance,
            filter = localPlayer
        })
        
        if not trace.Hit or not IsValid(trace.Entity) then return nil end
        
        local ent = trace.Entity
        
        -- Check if it's a player
        if ent:IsPlayer() then
            return ent
        end
        
        -- Check if it's a RADS ragdoll
        if ent:GetClass() == "prop_ragdoll" then
            local owner = ent:GetNWEntity("owner")
            local deadbodyowner = ent:GetNWEntity("deadbodyowner")
            
            if IsValid(owner) or IsValid(deadbodyowner) then
                return ent
            end
        end
        
        return nil
    end
    
    -- Main HUD drawing function
    hook.Add("HUDPaint", "RADS_NameDisplay", function()
        local localPlayer = LocalPlayer()
        if not IsValid(localPlayer) then return end
        
        local target = FindLookedAtTarget()
        local frameTime = FrameTime()
        
        -- Handle target changes and fade logic
        if target and IsValid(target) then
            currentTarget = target
            -- Fade in
            fadeAlpha = math.min(255, fadeAlpha + fadeSpeed * frameTime)
        else
            -- Fade out only when no target is found
            fadeAlpha = math.max(0, fadeAlpha - fadeSpeed * frameTime)
            if fadeAlpha <= 0 then
                currentTarget = nil
            end
        end
        
        -- Draw name if we have alpha
        if fadeAlpha > 0 and currentTarget and IsValid(currentTarget) then
            local name = GetPlayerName(currentTarget)
            if name then
                local playerColor = GetPlayerColor(currentTarget)
                local color = PlayerColorToColor(playerColor)
                color.a = fadeAlpha
                
                -- Get screen dimensions
                local scrW, scrH = ScrW(), ScrH()
                local centerX = scrW / 2
                local belowCenterY = scrH / 2 + 65 -- Position slightly below center to avoid UI conflicts
                
                -- Draw name with outline below screen center
                -- Draw outline (thinner and more transparent)
                local outlineColor = Color(0, 0, 0, fadeAlpha * 0.7)
                for x = -1, 1 do
                    for y = -1, 1 do
                        if x ~= 0 or y ~= 0 then
                            draw.SimpleText(name, "RADS_NameDisplay", centerX + x, belowCenterY + y, outlineColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        end
                    end
                end
                
                -- Draw main text
                draw.SimpleText(name, "RADS_NameDisplay", centerX, belowCenterY, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end)
    
    if GetConVar("developer"):GetInt() > 0 then
    print("[RADS] Name Display System loaded successfully!")
end
end