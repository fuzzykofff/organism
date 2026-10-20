-- Consciousness Timer UI System
-- Client-side HUD drawing for unconscious players

if not CLIENT then return end

-- Last Stand System Variables (shared with damage.lua)
local lastStandActive = false
local lastStandTinnitusActive = false
local lastStandTextActive = false

-- Local variables for consciousness timer
local consciousnessTimerActive = false
local consciousnessLevel = 100
local targetConsciousnessLevel = 100
local smoothConsciousnessLevel = 100
local textAnimationTime = 0
local textAnimationStates = {".", "..", "..."}
local deathTextAnimationStates = {".!", "..!", "...!"}
local currentTextState = 1
local lastTextUpdate = 0

-- Death state variables
local isInDeathState = false
local deathStateTimer = 0
local deathStateSound = nil
local unconsciousSound = nil

-- Animation variables
local uiAlpha = 0
local targetUIAlpha = 0
local uiStartTime = 0
local fadeInDuration = 5
local lastFrameTime = 0

-- UI Configuration
local TIMER_CONFIG = {
    centerX = ScrW() / 2,
    centerY = ScrH() / 2,
    radius = 120, -- Increased size
    thickness = 12, -- Increased thickness
    backgroundColor = Color(0, 0, 0, 100),
    progressColor = Color(255, 255, 255, 255), -- White for unconscious
    deathProgressColor = Color(255, 0, 0, 255), -- Red for death state
    textColor = Color(255, 255, 255, 255),
    textFont = "DermaLarge",
    animationSpeed = 0.8 -- Faster text animation for scav prototype feel
}

-- Network receiver for consciousness timer data
net.Receive("RADS_ConsciousnessTimer", function()
    local isUnconscious = net.ReadBool()
    local consciousness = net.ReadFloat()
    
    local wasActive = consciousnessTimerActive
    consciousnessTimerActive = isUnconscious
    targetConsciousnessLevel = consciousness
    
    -- Handle UI fade in/out
    if isUnconscious and not wasActive then
        -- Starting to be unconscious - fade in
        uiStartTime = CurTime()
        targetUIAlpha = 1.0
        textAnimationTime = CurTime()
        currentTextState = 1
        lastTextUpdate = CurTime()
        
        -- Play unconscious sound if not in death state
        if not isInDeathState then
            if unconsciousSound then
                unconsciousSound:Stop()
            end
            unconsciousSound = CreateSound(LocalPlayer(), "isthistheend.mp3")
            if unconsciousSound then
                unconsciousSound:Play()
                unconsciousSound:SetSoundLevel(0)
            end
        end
    elseif not isUnconscious and wasActive then
        -- Regaining consciousness - fade out
        targetUIAlpha = 0.0
        
        -- Stop unconscious sound
        if unconsciousSound then
            unconsciousSound:Stop()
            unconsciousSound = nil
        end
    end
end)

-- Network receiver for death state
net.Receive("RADS_DeathState", function()
    local inDeathState = net.ReadBool()
    local timer = net.ReadFloat()
    
    local wasInDeathState = isInDeathState
    isInDeathState = inDeathState
    deathStateTimer = timer
    
    if inDeathState and not wasInDeathState then
        -- Clear last stand effects when entering death state
        if lastStandActive then
            lastStandActive = false
            lastStandTinnitusActive = false
            lastStandTextActive = false
            timer.Remove("RADS_LastStandTimer")
        end
        
        -- Only play sound when entering death state for the first time
        -- Stop unconscious sound and play dying sound
        if unconsciousSound then
            unconsciousSound:Stop()
            unconsciousSound = nil
        end
        
        if deathStateSound then
            deathStateSound:Stop()
            deathStateSound = nil
        end
        
        sound.PlayFile("sound/dying.mp3", "noplay", function(station)
            if IsValid(station) then
                deathStateSound = station
                station:EnableLooping(true)
                station:SetVolume(0.8)
                station:Play()
            end
        end)
    elseif not inDeathState then
        -- Stop death sound when exiting death state
        if deathStateSound then
            deathStateSound:Stop()
            deathStateSound = nil
        end
    end
    -- If already in death state, just update the timer without restarting sound
end)

-- Network receivers to sync lastStandActive with damage.lua
net.Receive('RADS_StartLastStand', function()
    lastStandActive = true
    lastStandTinnitusActive = false
    lastStandTextActive = false
end)

net.Receive('RADS_StopLastStand', function()
    lastStandActive = false
    lastStandTinnitusActive = false
    lastStandTextActive = false
end)

-- Function to draw circular progress indicator
local function DrawCircularProgress(x, y, radius, progress, thickness, bgColor, fgColor)
    -- Draw background circle
    draw.NoTexture()
    surface.SetDrawColor(bgColor)
    
    local segments = 64
    local angleStep = (2 * math.pi) / segments
    
    -- Background circle
    for i = 0, segments do
        local angle1 = i * angleStep
        local angle2 = (i + 1) * angleStep
        
        local x1_outer = x + math.cos(angle1) * radius
        local y1_outer = y + math.sin(angle1) * radius
        local x1_inner = x + math.cos(angle1) * (radius - thickness)
        local y1_inner = y + math.sin(angle1) * (radius - thickness)
        
        local x2_outer = x + math.cos(angle2) * radius
        local y2_outer = y + math.sin(angle2) * radius
        local x2_inner = x + math.cos(angle2) * (radius - thickness)
        local y2_inner = y + math.sin(angle2) * (radius - thickness)
        
        surface.DrawPoly({
            {x = x1_outer, y = y1_outer},
            {x = x2_outer, y = y2_outer},
            {x = x2_inner, y = y2_inner},
            {x = x1_inner, y = y1_inner}
        })
    end
    
    -- Progress circle (fills clockwise from top)
    surface.SetDrawColor(fgColor)
    local progressSegments = math.floor(segments * progress)
    
    for i = 0, progressSegments do
        local angle1 = (i * angleStep) - (math.pi / 2) -- Start from top
        local angle2 = ((i + 1) * angleStep) - (math.pi / 2)
        
        local x1_outer = x + math.cos(angle1) * radius
        local y1_outer = y + math.sin(angle1) * radius
        local x1_inner = x + math.cos(angle1) * (radius - thickness)
        local y1_inner = y + math.sin(angle1) * (radius - thickness)
        
        local x2_outer = x + math.cos(angle2) * radius
        local y2_outer = y + math.sin(angle2) * radius
        local x2_inner = x + math.cos(angle2) * (radius - thickness)
        local y2_inner = y + math.sin(angle2) * (radius - thickness)
        
        surface.DrawPoly({
            {x = x1_outer, y = y1_outer},
            {x = x2_outer, y = y2_outer},
            {x = x2_inner, y = y2_inner},
            {x = x1_inner, y = y1_inner}
        })
    end
end

-- Smooth interpolation function with easing
local function SmoothLerp(current, target, speed, deltaTime)
    local diff = target - current
    if math.abs(diff) < 0.01 then
        return target
    end
    return current + diff * speed * deltaTime
end

-- Easing function for smooth fade-in
local function EaseInOut(t)
    return t * t * (3.0 - 2.0 * t)
end

-- Function to update text animation (continuous cycling)
local function UpdateTextAnimation()
    local currentTime = CurTime()
    
    -- Continuous text animation when UI is active
    if consciousnessTimerActive and uiAlpha > 0.1 then
        if currentTime - lastTextUpdate >= TIMER_CONFIG.animationSpeed then
            currentTextState = currentTextState + 1
            local animationStates = isInDeathState and deathTextAnimationStates or textAnimationStates
            if currentTextState > #animationStates then
                currentTextState = 1
            end
            lastTextUpdate = currentTime
        end
    end
end

-- Function to update all animations
local function UpdateAnimations()
    local currentTime = CurTime()
    local deltaTime = currentTime - lastFrameTime
    lastFrameTime = currentTime
    
    -- Update UI alpha with smooth fade
    if consciousnessTimerActive then
        local fadeProgress = math.Clamp((currentTime - uiStartTime) / fadeInDuration, 0, 1)
        fadeProgress = EaseInOut(fadeProgress)
        uiAlpha = SmoothLerp(uiAlpha, targetUIAlpha * fadeProgress, 4.0, deltaTime)
    else
        uiAlpha = SmoothLerp(uiAlpha, 0, 6.0, deltaTime)
    end
    
    -- Smooth consciousness level interpolation (slower, more gradual)
    smoothConsciousnessLevel = SmoothLerp(smoothConsciousnessLevel, targetConsciousnessLevel, 2.0, deltaTime)
end

-- Main HUD drawing hook
hook.Add("HUDPaint", "RADS_ConsciousnessTimer", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    -- Check if consciousness timer is enabled
    local timerEnabled = GetConVar("rads_consciousness_timer_client"):GetBool()
    if not timerEnabled then return end
    
    -- Update all animations
    UpdateAnimations()
    
    -- Only draw when UI has some alpha
    if uiAlpha <= 0.01 then return end
    
    -- Update screen center in case of resolution change
    TIMER_CONFIG.centerX = ScrW() / 2
    TIMER_CONFIG.centerY = ScrH() / 2
    
    -- Calculate progress (0 consciousness = full circle, 100 consciousness = empty circle)
    local progress = 1.0 - (smoothConsciousnessLevel / 100.0)
    progress = math.Clamp(progress, 0, 1)
    
    -- For death state, use timer instead of consciousness for progress
    if isInDeathState then
        -- deathStateTimer is timeLeft (decreases from 19 to 0)
        -- progress should start at 1 (full circle) and decrease to 0 (empty circle)
        progress = deathStateTimer / 19.0 -- Convert timeLeft to progress (1.0 to 0.0)
        progress = math.Clamp(progress, 0, 1)
    end
    
    -- Apply alpha to colors
    local bgColor = Color(
        TIMER_CONFIG.backgroundColor.r,
        TIMER_CONFIG.backgroundColor.g,
        TIMER_CONFIG.backgroundColor.b,
        TIMER_CONFIG.backgroundColor.a * uiAlpha
    )
    
    -- Choose color based on death state
    local baseProgressColor = isInDeathState and TIMER_CONFIG.deathProgressColor or TIMER_CONFIG.progressColor
    local progressColor = Color(
        baseProgressColor.r,
        baseProgressColor.g,
        baseProgressColor.b,
        baseProgressColor.a * uiAlpha
    )
    
    local textColor = Color(
        TIMER_CONFIG.textColor.r,
        TIMER_CONFIG.textColor.g,
        TIMER_CONFIG.textColor.b,
        TIMER_CONFIG.textColor.a * uiAlpha
    )
    
    -- Draw circular progress indicator
    DrawCircularProgress(
        TIMER_CONFIG.centerX,
        TIMER_CONFIG.centerY,
        TIMER_CONFIG.radius,
        progress,
        TIMER_CONFIG.thickness,
        bgColor,
        progressColor
    )
    
    -- Update and draw animated text
    UpdateTextAnimation()
    
    local animationStates = isInDeathState and deathTextAnimationStates or textAnimationStates
    local currentText = animationStates[currentTextState]
    
    -- Set font and get text size
    surface.SetFont(TIMER_CONFIG.textFont)
    local textW, textH = surface.GetTextSize(currentText)
    
    -- Draw text in center of circle
    draw.SimpleText(
        currentText,
        TIMER_CONFIG.textFont,
        TIMER_CONFIG.centerX,
        TIMER_CONFIG.centerY,
        textColor,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )
end)

-- Initialize client convar check
hook.Add("InitPostEntity", "RADS_ConsciousnessTimer_Init", function()
    -- Ensure client convar exists
    if not GetConVar("rads_consciousness_timer_client") then
        print("[RADS Health] Warning: rads_consciousness_timer_client convar not found!")
    end
end)

-- Stop death sound and clear UI on player death
hook.Add("PlayerDeath", "RADS_ClearDeathStateUI", function(victim, inflictor, attacker)
    if victim == LocalPlayer() then
        -- Immediately clear death state UI
        isInDeathState = false
        deathStateTimer = 0
        consciousnessTimerActive = false
        uiAlpha = 0
        targetUIAlpha = 0
        
        -- Stop death sound
        if deathStateSound then
            deathStateSound:Stop()
            deathStateSound = nil
        end
        if unconsciousSound then
            unconsciousSound:Stop()
            unconsciousSound = nil
        end
    end
end)

-- Stop death sound on respawn
hook.Add("PlayerSpawn", "RADS_StopDeathSound", function(ply)
    if ply == LocalPlayer() then
        if deathStateSound then
            deathStateSound:Stop()
            deathStateSound = nil
        end
        if unconsciousSound then
            unconsciousSound:Stop()
            unconsciousSound = nil
        end
        
        -- Reset death state
        isInDeathState = false
        deathStateTimer = 0
        consciousnessTimerActive = false
        uiAlpha = 0
        targetUIAlpha = 0
    end
end)