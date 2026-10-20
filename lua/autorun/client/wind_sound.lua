-- TRAUMA Wind Sound System
-- Client-side wind sound effects based on player velocity

if CLIENT then
    local windSound = nil
    local lastVelocity = 0
    local soundPlaying = false
    local fadingOut = false
    local fadeStartTime = 0
    local targetVolume = 0
    local currentVolume = 0
    
    -- Wind sound configuration
    local WIND_START_VELOCITY = 400
    local WIND_TRIGGER_VELOCITY = 445
    local WIND_PEAK_VELOCITY = 550
    local WIND_SOUND_PATH = "windLoop.mp3"
    local FADE_OUT_TIME = 1.5 -- Fade out duration in seconds
    
    -- Function to get player velocity
    local function GetPlayerVelocity(ply)
        if not IsValid(ply) then return 0 end
        
        -- Check if player is ragdolled
        if ply:GetNWBool("radsfa", false) then
            local ragdoll = ply:GetNWEntity("player_ragdoll")
            if IsValid(ragdoll) then
                return ragdoll:GetVelocity():Length()
            end
        end
        
        -- Normal player velocity
        return ply:GetVelocity():Length()
    end
    
    -- Function to calculate wind volume based on velocity
    local function CalculateWindVolume(velocity)
        if velocity < WIND_START_VELOCITY then
            return 0
        elseif velocity >= WIND_PEAK_VELOCITY then
            return 1.0
        else
            -- Linear interpolation between start and peak velocity
            local progress = (velocity - WIND_START_VELOCITY) / (WIND_PEAK_VELOCITY - WIND_START_VELOCITY)
            return math.Clamp(progress, 0, 1)
        end
    end
    
    -- Function to start wind sound
    local function StartWindSound()
        if soundPlaying then return end
        
        windSound = CreateSound(LocalPlayer(), WIND_SOUND_PATH)
        if windSound then
            windSound:Play()
            soundPlaying = true
        end
    end
    
    -- Function to stop wind sound immediately
    local function StopWindSound()
        if not soundPlaying then return end
        
        if windSound then
            windSound:Stop()
            windSound = nil
        end
        soundPlaying = false
        fadingOut = false
        currentVolume = 0
        targetVolume = 0
    end
    
    -- Function to start fade out
    local function StartFadeOut()
        if not soundPlaying or fadingOut then return end
        
        fadingOut = true
        fadeStartTime = CurTime()
        targetVolume = 0
    end
    
    -- Function to update wind sound volume
    local function UpdateWindSound(velocity)
        local windSoundsConVar = GetConVar("rads_wind_sounds")
        if not windSoundsConVar or not windSoundsConVar:GetBool() then
            if soundPlaying then
                StopWindSound()
            end
            return
        end
        
        local volume = CalculateWindVolume(velocity)
        
        if velocity >= WIND_TRIGGER_VELOCITY and volume > 0 then
            -- Start sound if not playing
            if not soundPlaying then
                StartWindSound()
                fadingOut = false
            end
            
            -- Cancel fade out if velocity is back up
            if fadingOut then
                fadingOut = false
            end
            
            targetVolume = volume
            
            if windSound then
                windSound:ChangeVolume(volume, 0.1)
                currentVolume = volume
            end
        else
            -- Start fade out instead of stopping immediately
            if soundPlaying and not fadingOut then
                StartFadeOut()
            end
        end
        
        -- Handle fade out process
        if fadingOut and soundPlaying then
            local fadeProgress = (CurTime() - fadeStartTime) / FADE_OUT_TIME
            
            if fadeProgress >= 1.0 then
                -- Fade out complete, stop the sound
                StopWindSound()
            else
                -- Calculate fade volume
                local fadeVolume = currentVolume * (1.0 - fadeProgress)
                if windSound then
                    windSound:ChangeVolume(fadeVolume, 0.05)
                end
            end
        end
    end
    
    -- Main wind sound think hook
    hook.Add("Think", "TRAUMA_WindSound", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then
            if soundPlaying then
                StopWindSound()
            end
            return
        end
        
        local currentVelocity = GetPlayerVelocity(ply)
        
        -- Only update if velocity changed significantly to avoid constant updates
        if math.abs(currentVelocity - lastVelocity) > 5 then
            UpdateWindSound(currentVelocity)
            lastVelocity = currentVelocity
        end
    end)
    
    -- Clean up wind sound when player disconnects or dies
    hook.Add("PlayerDeath", "TRAUMA_WindSound_Cleanup", function(victim)
        if victim == LocalPlayer() and soundPlaying then
            StopWindSound()
        end
    end)
    
    -- Clean up on shutdown
    hook.Add("ShutDown", "TRAUMA_WindSound_Shutdown", function()
        if soundPlaying then
            StopWindSound()
        end
    end)
end