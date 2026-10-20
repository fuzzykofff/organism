local fps = 1 / 24 --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM --SPAGHETTI CODE ALARM
local delay = 0
bloodparticels2 = bloodparticels2 or {}
local bloodparticels = bloodparticels2
bloodparticels_hook = {}
local bloodparticels_hook = bloodparticels_hook
local tr = {
    filter = function(ent) return not ent:IsPlayer() and not ent:IsRagdoll() end
}

local vecZero = Vector(0, 0, 0)
local LerpVector = LerpVector
local math_random = math.random
local table_remove = table.remove
local util_Decal = util.Decal
local util_TraceLine = util.TraceLine
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
local surface_SetDrawColor = surface.SetDrawColor
local color = Color(255, 255, 255, 255)
bloodparticels_hook[3] = function(anim_pos)
    local time = CurTime()
    for i = 1, #bloodparticels2 do
        local part = bloodparticels2[i]
        color.a = 255 * (part[7] - time) / part[8]
        render_SetMaterial(part[4])
        render_DrawSprite(LerpVector(anim_pos, part[2], part[1]), part[5], part[6], color)
    end
end

bloodparticels_hook[4] = function(mul)
    local time = CurTime()
    for i = 1, #bloodparticels2 do
        local part = bloodparticels2[i]
        if not part then break end
        local pos = part[1]
        local posSet = part[2]
        tr.start = posSet
        tr.endpos = tr.start + part[3] * mul
        result = util_TraceLine(tr)
        local hitPos = result.HitPos
        if result.Hit or part[7] - time <= 0 then
            table_remove(bloodparticels2, i)
            continue
        else
            pos:Set(posSet)
            posSet:Set(hitPos)
        end

        part[3] = LerpVector(0.5 * mul, part[3], vecZero)
    end
end

local math_min = math.min
local CurTime, FrameTime = CurTime, FrameTime
bloodparticels_hook = bloodparticels_hook or {}
local bloodparticels_hook = bloodparticels_hook
hook.Add("PostDrawOpaqueRenderables", "bloodpartciels", function()
    local time = CurTime()
    if delay <= time then
        delay = time + fps
        bloodparticels_hook[2](fps)
        bloodparticels_hook[4](fps)
    end

    local animpos = math_min((delay - time) / fps, 1)
    bloodparticels_hook[1](animpos)
    bloodparticels_hook[3](animpos)
end)

bloodparticels1 = bloodparticels1 or {}
bloodparticels_hook = bloodparticels_hook or {}
local bloodparticels1 = bloodparticels1
local bloodparticels_hook = bloodparticels_hook
local tr = {
    filter = function(ent) return not ent:IsPlayer() and not ent:IsRagdoll() end
}

local vecDown = Vector(0, 0, -40)
local vecZero = Vector(0, 0, 0)
local LerpVector = LerpVector
local math_random = math.random
local table_remove = table.remove
local util_Decal = util.Decal
local util_TraceLine = util.TraceLine
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
bloodparticels_hook[1] = function(anim_pos)
    for i = 1, #bloodparticels1 do
        local part = bloodparticels1[i]
        render_SetMaterial(part[4])
        render_DrawSprite(LerpVector(anim_pos, part[2], part[1]), part[5], part[6])
    end
end

bloodparticels_hook[2] = function(mul)
    for i = 1, #bloodparticels1 do
        local part = bloodparticels1[i]
        if not part then break end
        local pos = part[1]
        local posSet = part[2]
        tr.start = posSet
        tr.endpos = tr.start + part[3] * mul
        result = util_TraceLine(tr)
        local hitPos = result.HitPos
        if result.Hit then
            table_remove(bloodparticels1, i)
            local dir = result.HitNormal
            util_Decal("Blood", hitPos + dir, hitPos - dir)
            sound.Play("blooddrip" .. math_random(1, 4) .. ".wav", hitPos, 60, math_random(100, 120))
            continue
        else
            pos:Set(posSet)
            posSet:Set(hitPos)
        end

        part[3] = LerpVector(0.25 * mul, part[3], vecZero)
        part[3]:Add(vecDown)
    end
end

local function create_materials(mat_names)
    local mats = {}
    for _, v in ipairs(mat_names) do
        local imat = Material(v)
        table.insert(mats, imat)
    end
    return mats
end

local blood_materials = create_materials({"decals/blood1", "decals/blood2", "decals/blood3", "decals/blood4", "decals/blood5", "decals/blood6",})
local mats = {}
for i = 1, 8 do
    mats[i] = Material("decals/blood" .. i)
end

local countmats = #mats
local random = math.random
local Rand = math.Rand
local bloodparticels1 = bloodparticels1
local bloodparticels2 = bloodparticels2
local vecZero = Vector(0, 0, 0)
local function addBloodPart(pos, vel, mat, w, h)
    pos = pos + vecZero
    vel = vel + vecZero
    local pos2 = Vector()
    pos2:Set(pos)
    bloodparticels1[#bloodparticels1 + 1] = {pos, pos2, vel, mat, w, h}
end

local vecR = Vector(10, 10, 10)
net.Receive("blood particle headshoot", function()
    local pos, vel = net.ReadVector(), net.ReadVector()
    local dir = Vector()
    dir:Set(vel)
    dir:Normalize()
    dir:Mul(25)
    local l1, l2 = pos - dir / 2, pos + dir / 2
    local r = random(10, 15)
    for i = 1, r do
        local vel = Vector(vel[1], vel[2], vel[3])
        vel:Rotate(Angle(Rand(-15, 15) * Rand(0.9, 1.1), Rand(-15, 15) * Rand(0.9, 1.1)))
        -- Made blood particles wider: increased width from random(1, 2) to random(2, 4)
        addBloodPart(Lerp(i / r * Rand(0.9, 1.1), l1, l2), vel, mats[random(1, #mats)], random(2, 4), random(4, 8))
    end

    for i = 1, 8 do
        -- Made blood particles wider: increased width from random(3, 5) to random(4, 7)
        addBloodPart2(pos, vecZero, mats[random(1, #mats)], random(4, 7), random(8, 12), Rand(1, 2))
    end
end)

net.Receive("blood particle", function() 
    local pos, vel = net.ReadVector(), net.ReadVector()
    -- Reduced artery velocity and added slight randomization
    vel = vel * 0.6 + Vector(Rand(-2, 2), Rand(-2, 2), Rand(-1, 1))
    -- Made blood particles wider: increased width from random(1, 2) to random(2, 4)
    addBloodPart(pos, vel, mats[random(1, #mats)], random(2, 4), random(4, 8)) 
end)
local Rand = math.Rand
local function explode(pos)
    local xx, yy = 12, 12
    local w, h = 360 / xx, 360 / yy
    for x = 1, xx do
        for y = 1, yy do
            local dir = Vector(0, 0, -1)
            dir:Rotate(Angle(h * y * Rand(0.9, 1.1), w * x * Rand(0.9, 1.1), 0))
            dir[3] = dir[3] + Rand(0.5, 1.5)
            dir:Mul(250)
            -- Made blood particles wider: increased width from random(1, 2) to random(2, 4)
            addBloodPart(pos, dir, mats[random(1, #mats)], random(2, 4), random(3, 6))
        end
    end
end

net.Receive("blood particle explode", function() explode(net.ReadVector()) end)
net.Receive("blood particle more", function()
    local pos, vel = net.ReadVector(), net.ReadVector()
    for i = 1, random(8, 12) do -- Reduced from 10-15 to 8-12 for less dripping
        -- Reduced artery velocity and randomization
        local randomVel = vel * 0.6 + Vector(Rand(-12, 12), Rand(-12, 12), Rand(-5, 5))
        -- Made blood particles wider: increased width from random(1, 2) to random(2, 4)
        addBloodPart(pos, randomVel, mats[random(1, #mats)], random(2, 4), random(4, 8))
    end
end)

function addBloodPart2(pos, vel, mat, w, h, time)
    pos = pos + vecZero
    vel = vel + vecZero
    local pos2 = Vector()
    pos2:Set(pos)
    bloodparticels2[#bloodparticels2 + 1] = {pos, pos2, vel, mat, w, h, CurTime() + time, time}
end

-- Clear effects on death
hook.Add("PostPlayerDeath", "RADS_ClearUtilEffects", function()
    adrenaline = 0
    blood = 5000  -- Reset to full blood
end)

-- Reset effects on spawn
hook.Add("PlayerSpawn", "RADS_ResetUtilEffects", function(ply)
    if ply == LocalPlayer() then
        adrenaline = 0
        blood = 5000
    end
end)
blood = 5000
adrenaline = 0
net.Receive("info_blood", function() blood = net.ReadFloat() end)
net.Receive("info_adrenaline", function() adrenaline = net.ReadFloat() end)
local math_Clamp = math.Clamp
local tab = {
    ["$pp_colour_addr"] = 0,
    ["$pp_colour_addg"] = 0,
    ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"] = 0,
    ["$pp_colour_colour"] = 1,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0
}

local ScrH = ScrH
hook.Add("RenderScreenspaceEffects", "ToyssssnssssEffect", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    
    -- Make sure adrenaline and blood are valid numbers
    local currentAdrenaline = adrenaline or 0
    local currentBlood = blood or 5000
    
    local fraction = math_Clamp(1 - ((currentBlood - 3200) / ((5000 - 1400) - 2000)), 0, 1)
    DrawToyTown(fraction * 8, ScrH() * fraction * 1.5)
    DrawSharpen(5, currentAdrenaline / 5)
    if fraction <= 0.7 then return end
    DrawMotionBlur(0.2, 0.9, 0.03)
end)

-- Global storage for client-side TRAUMA data
RADS_ClientData = RADS_ClientData or {}

net.Receive("organism_info", function(len)
    local organs = net.ReadTable()
    local stringinfo = net.ReadString()
    
    -- Store organ data
    RADS_ClientData.organs = organs
    
    -- Parse pain from string info (format: "Боль: 150")
    local painValue = string.match(stringinfo, "Боль: (%d+)")
    if painValue then
        RADS_ClientData.pain = tonumber(painValue) or 0
    end
    
    -- Parse blood from string info (format: "Кровь (мл): 4500")
    local bloodValue = string.match(stringinfo, "Кровь %(мл%): (%d+)")
    if bloodValue then
        RADS_ClientData.blood = tonumber(bloodValue) or 5000
    end
    
    -- Parse bleeding from string info (format: "Кровотечение (мл/удар): 15")
    local bleedingValue = string.match(stringinfo, "Кровотечение %(мл/удар%): (%d+)")
    if bleedingValue then
        RADS_ClientData.bleeding = tonumber(bleedingValue) or 0
    end
    
    PrintTable(organs)
    if GetConVar("developer"):GetInt() > 0 then
        print(stringinfo)
        print("[RADS DEBUG] Parsed Pain: " .. (RADS_ClientData.pain or 0))
    end
end)

hook.Add("ScalePlayerDamage", "no_effects", function(ent, dmginfo) return true end)
sound.list = {}
local list = sound.list
local meta = {}
local globalEyePos = EyePos()
function meta:Stop()
    if self:IsPlaying() then
        self.snd:Stop()
        self.snd = nil
    end

    if IsValid(self.model) then
        self.model:Remove()
        self.model = nil
    end
end

function meta:IsValid()
    return not self.remove
end

function meta:IsPlaying()
    return self.snd and self.snd:IsPlaying()
end

local SysTime, SoundDuration = SysTime, SoundDuration
local string_sub = string.sub
function meta:Play(name)
    self:Stop()
    if not IsValid(self.model) then
        self.model = ClientsideModel("models/hunter/plates/plate.mdl")
        self.model:SetNoDraw(true)
    end

    if name then
        self.sndPath = name
    else
        name = self.sndPath
    end

    self:Think()
    self.snd = CreateSound(self.model, self.sndPath)
    self.snd:SetSoundLevel(150)
    self:Apply(true)
    self.snd:PlayEx(self.volumeTrue, self.pitch * 100)
    return true
end

local Remove = FindMetaTable("Entity")
function meta:Remove()
    if self.remove then return end
    self:Stop()
    self.remove = true
    list[self.id] = nil
end

local clamp = math.Clamp
local function getDSP(pos, alwaysView)
    local count = sound.InTheWall(pos, 3, 16)
    if count == 3 then
        return 0
    elseif count == 2 then
        return 15
    elseif count == 1 then
        return 16
    else
        return alwaysView and 16
    end
end

function meta:Think()
    local pos
    local parent = self.parent
    if parent then
        pos = parent:GetPos()
        pos:Add(self.pos)
    else
        pos = self.pos
    end

    local dsp = getDSP(pos, self.alwaysView)
    if dsp then
        self.dsp = dsp
    else
        self.volumeTrue = 0
        return
    end

    local diff = globalEyePos - pos
    local dir = diff:GetNormalized()
    local dis = diff:Length()
    local disEnd = self.dis
    local k = 1 - clamp(dis / disEnd, 0, 1)
    local disK = self.disK
    if k < disK then
        k = k / disK
        self.volumeTrue = k * self.volume
        dis = dis - self.disFadeout * (1 - k)
    else
        self.volumeTrue = self.volume
    end

    if self.fadeStart then
        local k = (self.fadeStart + self.fadeDelay - SysTime()) / self.fadeDelay
        self.volumeTrue = self.volumeTrue * k
        if k <= 0 then
            self.remove = nil
            self:Remove()
            return
        end
    end

    dir:Mul(dis)
    self.modelPos = pos + dir
end

function meta:Apply(dontEquial)
    if not IsValid(self.model) then return end
    self.model:SetRenderOrigin((self.modelPos or Vector()) + VectorRand(-0.1, 0.1))
    if dontEquial or self.oldDsp ~= self.dsp then
        self.oldDsp = self.dsp
        self.snd:SetDSP(self.dsp)
    end

    self.snd:ChangePitch(self.pitch * 100, 0.1)
    self.snd:ChangeVolume(self.volumeTrue, 0.1)
end

function meta:FadeOut(value)
    self.remove = true
    self.IsValid = nil
    self.fadeStart = SysTime()
    self.fadeDelay = value
end

sound.count = sound.count or 0
function sound.CreatePoint(id, sndName, pos, dis, disK)
    if not id then
        id = sound.count
        sound.count = sound.count + 1
    end

    local point = list[id]
    if not point then
        point = {}
        list[id] = point
        point.loop = false
        point.pitch = 1
        point.volume = 1
        point.volumeTrue = 1
        point.dsp = 0
        for k, v in pairs(meta) do
            point[k] = v
        end

        point.id = id
    end

    point.sndPath = sndName
    if pos then
        if TypeID(pos) == TYPE_ENTITY then
            point.parent = pos
        else
            point.pos = pos
        end
    end

    if dis == nil then dis = 750 end
    point.fadeStart = nil
    point.IsValid = meta.IsValid
    point.remove = nil
    point.dis = dis
    point.disK = disK or 1
    point.disFadeout = 12
    return point
end

local tr = {}
local TraceLine = util.TraceLine
local function filter(ent)
    return not ent:IsPlayer() and not ent:IsNPC() and not ent:IsRagdoll()
end

local PointContents = util.PointContents
local bit_band = bit.band
function sound.InTheWall(pos, count, mul)
    tr.start = pos
    tr.endpos = globalEyePos
    tr.filter = filter
    local dir = globalEyePos - pos
    dir:Normalize()
    dir:Mul(mul)
    local result = TraceLine(tr)
    if result.HitPos:Distance(globalEyePos) <= 32 then return count end
    if result.Hit then
        pos = result.HitPos
        for i = 1, count do
            pos:Add(dir)
            if bit_band(PointContents(pos), CONTENTS_EMPTY) then
                count = count - i
                if count <= 0 then return count end
                return sound.InTheWall(pos, count - i + 1, mul)
            end
        end
        return 0
    else
        return count
    end
end

hook.Add("Frame", "Sounds", function(pos)
    globalEyePos = pos + VectorRand(-0.0001, 0.0001)
    local time = SysTime()
    for id, point in pairs(list) do
        local parent = point.parent
        if parent and not IsValid(parent) then
            point:Remove()
            continue
        end

        if not IsValid(point.model) or not point:IsPlaying() then point:Play() end
        point:Think()
        point:Apply()
    end
end)

function sound.Emit(ent, sndName, level, volume, pitch, dsp)
    local pos = ent:GetPos()
    local _dsp = getDSP(pos)
    if not _dsp then return end
    EmitSound(sndName, pos, ent:EntIndex(), nil, volume, level, nil, pitch, _dsp == 0 and dsp or _dsp)
end

net.Receive("sound", function()
    local packet = net.ReadTable()
    local dsp = getDSP(packet[2])
    if not dsp then return end
    EmitSound(packet[1], packet[2], packet[3], nil, packet[4], packet[5], nil, packet[6], dsp == 0 and packet[7] or dsp)
end)

net.Receive("sound surface", function() surface.PlaySound(net.ReadString()) end)

-- Blood vomit warning sound receiver
net.Receive("RADS_BloodVomitWarning", function()
	surface.PlaySound("bloodvomitwarning.mp3")
end)

concommand.Add("testsound", function() sound.EmitSound("weapons/357_fire2.wav", EyePos()) end)
--бесплоезный модуль..................................