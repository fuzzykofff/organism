if SERVER then
	AddCSLuaFile()
	-- Add network strings for M99 etorphine effects
	util.AddNetworkString('RADS_M99_Injection')
	util.AddNetworkString('RADS_M99_Recovery')
	util.AddNetworkString('RADS_M99_Overdose')
	
	-- Clean up M99 effects on player spawn
	hook.Add("PlayerSpawn", "RADS_M99_CleanupOnSpawn", function(ply)
		timer.Simple(0.1, function()
			if IsValid(ply) then
				ply.m99Active = false
				ply.m99StartTime = nil
				ply.m99OnsetTime = nil
				ply.m99OriginalConsciousness = nil
				ply.m99InjectionSite = nil
				ply.m99InjectionCount = 0
				ply.m99InjectionTimes = {}
				ply.m99OxygenLoss = false
				
				-- Remove any active M99 timers
				timer.Remove("M99_Effect_" .. ply:EntIndex())
				timer.Remove("M99_Recovery_" .. ply:EntIndex())
				timer.Remove("M99_Recovery_Process_" .. ply:EntIndex())
				timer.Remove("M99_OxygenLoss_" .. ply:EntIndex())
			end
		end)
	end)
	
	-- Clean up M99 effects on player disconnect
	hook.Add("PlayerDisconnected", "RADS_M99_CleanupOnDisconnect", function(ply)
		if IsValid(ply) then
			-- Remove any active M99 timers
			timer.Remove("M99_Effect_" .. ply:EntIndex())
			timer.Remove("M99_Recovery_" .. ply:EntIndex())
			timer.Remove("M99_Recovery_Process_" .. ply:EntIndex())
			timer.Remove("M99_OxygenLoss_" .. ply:EntIndex())
		end
	end)
elseif CLIENT then
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 65
	SWEP.Slot = 5
	SWEP.SlotPos = 2
	killicon.AddFont("wep_jack_hmcd_m99", "HL2MPTypeDeath", "5", Color(255, 0, 0, 255))
	
	-- Register Coolvetica font for injection UI
	surface.CreateFont("M99_InjectionFont", {
		font = "Coolvetica",
		size = 24,
		weight = 500,
		antialias = true,
		shadow = false,
		extended = false,
		scanlines = 0,
		blur = 0
	})
	
	-- Store target info for UI
	SWEP.TargetInfo = {}
	
	function SWEP:DrawViewModel()
		return false
	end

	function SWEP:DrawWorldModel()
		self:DrawModel()
	end

	-- Function to get hitgroup from bone name for ragdolls
	function SWEP:GetRagdollHitgroup(ragdoll, boneIndex)
		if not IsValid(ragdoll) or not boneIndex then return HITGROUP_GENERIC end
		
		local boneName = ragdoll:GetBoneName(boneIndex)
		if not boneName then return HITGROUP_GENERIC end
		
		boneName = string.lower(boneName)
		
		-- Head and neck bones
		if string.find(boneName, "head") or string.find(boneName, "neck") or string.find(boneName, "skull") then
			return HITGROUP_HEAD
		-- Chest and upper torso
		elseif string.find(boneName, "chest") or string.find(boneName, "spine") or string.find(boneName, "ribcage") then
			return HITGROUP_CHEST
		-- Stomach and lower torso
		elseif string.find(boneName, "pelvis") or string.find(boneName, "stomach") or string.find(boneName, "hip") then
			return HITGROUP_STOMACH
		-- Left arm
		elseif string.find(boneName, "l_") and (string.find(boneName, "arm") or string.find(boneName, "hand") or string.find(boneName, "shoulder") or string.find(boneName, "clavicle")) then
			return HITGROUP_LEFTARM
		-- Right arm
		elseif string.find(boneName, "r_") and (string.find(boneName, "arm") or string.find(boneName, "hand") or string.find(boneName, "shoulder") or string.find(boneName, "clavicle")) then
			return HITGROUP_RIGHTARM
		-- Left leg
		elseif string.find(boneName, "l_") and (string.find(boneName, "leg") or string.find(boneName, "foot") or string.find(boneName, "thigh") or string.find(boneName, "calf")) then
			return HITGROUP_LEFTLEG
		-- Right leg
		elseif string.find(boneName, "r_") and (string.find(boneName, "leg") or string.find(boneName, "foot") or string.find(boneName, "thigh") or string.find(boneName, "calf")) then
			return HITGROUP_RIGHTLEG
		else
			return HITGROUP_GENERIC
		end
	end

	function SWEP:DrawHUD()
		local ply = self:GetOwner()
		if not IsValid(ply) then return end
		
		-- Check for valid injection target
		local tr = util.TraceLine({
			start = ply:GetShootPos(),
			endpos = ply:GetShootPos() + ply:GetAimVector() * 80,
			filter = ply
		})
		
		local target = nil
		local bodyPart = ""
		local hitgroup = tr.HitGroup
		
		if IsValid(tr.Entity) then
			if tr.Entity:IsPlayer() and tr.Entity ~= ply then
				target = tr.Entity
				bodyPart = self:GetBodyPartName(hitgroup)
			elseif tr.Entity:IsRagdoll() and tr.Entity:GetNWEntity("owner") and tr.Entity:GetNWEntity("owner"):IsPlayer() then
				target = tr.Entity:GetNWEntity("owner")
				-- For ragdolls, try to get more accurate hitgroup from bone
				if tr.PhysicsBone then
					local boneIndex = tr.Entity:TranslatePhysBoneToBone(tr.PhysicsBone)
					if boneIndex and boneIndex >= 0 then
						hitgroup = self:GetRagdollHitgroup(tr.Entity, boneIndex)
					end
				end
				bodyPart = self:GetBodyPartName(hitgroup)
			end
		end
		
		if target and bodyPart ~= "" then
			-- Draw injection text in red M99_InjectionFont
			surface.SetFont("M99_InjectionFont")
			local text = "Inject to " .. bodyPart
			local textW, textH = surface.GetTextSize(text)
			
			local x = ScrW() / 2 - textW / 2
			local y = ScrH() / 2 - 50
			
			-- Draw text shadow
			surface.SetTextColor(0, 0, 0, 200)
			surface.SetTextPos(x + 1, y + 1)
			surface.DrawText(text)
			
			-- Draw main text
			surface.SetTextColor(255, 0, 0, 255)
			surface.SetTextPos(x, y)
			surface.DrawText(text)
		end
	end
	
	function SWEP:GetBodyPartName(hitgroup)
		if hitgroup == HITGROUP_HEAD then
			return "jugular"
		elseif hitgroup == HITGROUP_CHEST then
			return "Chest"
		elseif hitgroup == HITGROUP_STOMACH then
			return "Stomach"
		elseif hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM then
			return "Arm"
		elseif hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG then
			return "Leg"
		else
			return "Torso"
		end
	end
end

SWEP.Base = "weapon_base"
SWEP.ViewModel = "models/weapons/w_models/w_jyringe_jroj.mdl"
SWEP.WorldModel = "models/weapons/w_models/w_jyringe_jroj.mdl"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_m99")
	SWEP.BounceWeaponIcon = false
end

SWEP.PrintName = "M99 Etorphine Syringe"
SWEP.Instructions = "A powerful synthetic opioid used primarily in veterinary medicine to immobilize large animals. Repurposed for tactical use—capable of rendering a human unconscious within seconds of injection depending on injection site. Jugular/head injections work fastest, extremities take longer. Due to its extreme potency, it is dangerous even in trace amounts.\n\nLMB to inject others/ragdolls (location-dependent effects)"
SWEP.Author = ""
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.BobScale = 2
SWEP.SwayScale = 2
SWEP.Weight = 3
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "Medical Items"
SWEP.CommandDroppable = true
SWEP.Primary.Delay = 0.5
SWEP.Primary.Recoil = 3
SWEP.Primary.Damage = 120
SWEP.Primary.NumShots = 1
SWEP.Primary.Cone = 0.04
SWEP.Primary.ClipSize = -1
SWEP.Primary.Force = 20
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.Delay = 0.9
SWEP.Secondary.Recoil = 0
SWEP.Secondary.Damage = 0
SWEP.Secondary.NumShots = 1
SWEP.Secondary.Cone = 0
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.ENT = "ent_jack_hmcd_m99"
SWEP.HomicideSWEP = true
function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:SetupDataTables()
	--
end

function SWEP:OnDrop()
	local Ent = ents.Create(self.ENT)
	Ent.HmcdSpawned = self.HmcdSpawned
	Ent:SetPos(self:GetPos())
	Ent:SetAngles(self:GetAngles())
	Ent:Spawn()
	Ent:Activate()
	Ent:GetPhysicsObject():SetVelocity(self:GetVelocity() / 2)
	self:Remove()
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	self:SetNextPrimaryFire(CurTime() + 1)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	if CLIENT then return end
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	-- Trace to find target
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * 80,
		filter = ply
	})

	local target = nil
	local hitgroup = tr.HitGroup or HITGROUP_CHEST
	
	-- Only allow injection on OTHER players or ragdolls (no self-injection)
	if IsValid(tr.Entity) then
		if tr.Entity:IsPlayer() and tr.Entity ~= ply then
			target = tr.Entity
		elseif tr.Entity:IsRagdoll() and tr.Entity:GetNWEntity("owner") and tr.Entity:GetNWEntity("owner"):IsPlayer() and tr.Entity:GetNWEntity("owner") ~= ply then
			target = tr.Entity:GetNWEntity("owner")
			-- For ragdolls, try to get more accurate hitgroup from bone
			if tr.PhysicsBone then
				local boneIndex = tr.Entity:TranslatePhysBoneToBone(tr.PhysicsBone)
				if boneIndex and boneIndex >= 0 then
					local boneName = tr.Entity:GetBoneName(boneIndex)
					if boneName then
						-- Map bone names to hitgroups
						if string.find(boneName, "Head") or string.find(boneName, "Neck") then
							hitgroup = HITGROUP_HEAD
						elseif string.find(boneName, "Spine2") or string.find(boneName, "Spine1") then
							hitgroup = HITGROUP_CHEST
						elseif string.find(boneName, "Spine") and not string.find(boneName, "Spine1") and not string.find(boneName, "Spine2") then
							hitgroup = HITGROUP_STOMACH
						elseif string.find(boneName, "L_") and (string.find(boneName, "Arm") or string.find(boneName, "Hand") or string.find(boneName, "Finger")) then
							hitgroup = HITGROUP_LEFTARM
						elseif string.find(boneName, "R_") and (string.find(boneName, "Arm") or string.find(boneName, "Hand") or string.find(boneName, "Finger")) then
							hitgroup = HITGROUP_RIGHTARM
						elseif string.find(boneName, "L_") and (string.find(boneName, "Leg") or string.find(boneName, "Foot") or string.find(boneName, "Toe")) then
							hitgroup = HITGROUP_LEFTLEG
						elseif string.find(boneName, "R_") and (string.find(boneName, "Leg") or string.find(boneName, "Foot") or string.find(boneName, "Toe")) then
							hitgroup = HITGROUP_RIGHTLEG
						else
							hitgroup = HITGROUP_CHEST -- Default fallback
						end
					end
				end
			end
		end
	end

	-- If no valid target, don't inject
	if not target then
		return
	end

	-- Play injection sound
	sound.Play("snd_jack_hmcd_needleprick.wav", target:GetShootPos() + VectorRand(), 70, math.random(95, 105))
	ply:ViewPunch(Angle(-5, math.Rand(-2,2), 0))

	-- Get body part and calculate onset time
	local bodyPart = self:GetBodyPartName(hitgroup)
	local onsetTime = self:GetOnsetTime(hitgroup)
	
	-- Initialize M99 tracking variables
	if not target.m99InjectionCount then target.m99InjectionCount = 0 end
	if not target.m99InjectionTimes then target.m99InjectionTimes = {} end
	if not target.m99OxygenLoss then target.m99OxygenLoss = false end
	
	-- Track this injection
	target.m99InjectionCount = target.m99InjectionCount + 1
	table.insert(target.m99InjectionTimes, CurTime())
	
	-- Clean up old injection times (older than 2 minutes)
	local currentTime = CurTime()
	for i = #target.m99InjectionTimes, 1, -1 do
		if currentTime - target.m99InjectionTimes[i] > 120 then
			table.remove(target.m99InjectionTimes, i)
		end
	end
	
	-- Count recent injections (within 2 minutes)
	local recentInjections = #target.m99InjectionTimes
	
	-- Check for overdose effects
	if target.m99InjectionCount >= 4 then
		-- 4th dose - DELAYED DEATH (2-5 seconds)
		-- Send overdose network message
		net.Start('RADS_M99_Overdose')
		net.WriteEntity(target)
		net.WriteString("FATAL")
		net.Broadcast()
		
		-- Delayed death timer
		timer.Simple(math.random(2, 5), function()
			if IsValid(target) and target:Alive() then
				target.consciousness = 0
				target.Otrub = true
				target:SetNWBool("Otrub", true)
				target:Kill()
			end
		end)
		
		self:Remove()
		return
	elseif recentInjections >= 2 then
		-- 2+ doses in 2 minutes - Gradual oxygen loss
		if not target.m99OxygenLoss then
			target.m99OxygenLoss = true
			
			-- Send overdose network message
			net.Start('RADS_M99_Overdose')
			net.WriteEntity(target)
			net.WriteString("OXYGEN_LOSS")
			net.Broadcast()
			
			-- Start gradual oxygen loss effect
			timer.Create("M99_OxygenLoss_" .. target:EntIndex(), 3, 0, function()
				if not IsValid(target) or not target:Alive() or not target.m99OxygenLoss then
					timer.Remove("M99_OxygenLoss_" .. target:EntIndex())
					return
				end
				
				-- Slowly reduce oxygen (slower rate)
				if target.oxygen then
					target.oxygen = math.max(0, target.oxygen - 2)
				end
			end)
		end
	end
	
	-- Store original consciousness level if not already stored
	if not target.m99OriginalConsciousness then
		target.m99OriginalConsciousness = target.consciousness or 100
	end
	
	-- Start M99 effect
	target.m99Active = true
	target.m99StartTime = CurTime()
	target.m99OnsetTime = onsetTime
	target.m99InjectionSite = bodyPart
	
	-- Send network message for client effects
	net.Start('RADS_M99_Injection')
	net.WriteEntity(target)
	net.WriteString(bodyPart)
	net.WriteFloat(onsetTime)
	net.Broadcast()
	
	-- Messages removed for stealth injection
	
	-- Start unconsciousness timer
	timer.Create("M99_Effect_" .. target:EntIndex(), 0.1, 0, function()
		if not IsValid(target) or not target:Alive() or not target.m99Active then
			timer.Remove("M99_Effect_" .. target:EntIndex())
			return
		end
		
		local elapsed = CurTime() - target.m99StartTime
		local progress = math.min(elapsed / target.m99OnsetTime, 1)
		
		-- Gradually reduce consciousness
		if progress < 1 then
			target.consciousness = target.m99OriginalConsciousness * (1 - progress)
			
			-- Force unconsciousness when consciousness drops below 20
			if target.consciousness <= 20 and not target.Otrub then
				target.Otrub = true
				target:SetNWBool("Otrub", true)
			end
		else
			-- Full effect reached - completely unconscious
			target.consciousness = 0
			target.Otrub = true
			target:SetNWBool("Otrub", true)
			
			-- Start recovery timer (2-5 minutes)
			local recoveryTime = math.random(120, 300)
			timer.Create("M99_Recovery_" .. target:EntIndex(), recoveryTime, 1, function()
				if IsValid(target) and target:Alive() and target.m99Active then
					self:StartRecovery(target)
				end
			end)
			
			timer.Remove("M99_Effect_" .. target:EntIndex())
		end
	end)

	self:Remove()
end

function SWEP:GetBodyPartName(hitgroup)
	if hitgroup == HITGROUP_HEAD then
		return "jugular"
	elseif hitgroup == HITGROUP_CHEST then
		return "Chest"
	elseif hitgroup == HITGROUP_STOMACH then
		return "Stomach"
	elseif hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM then
		return "Arm"
	elseif hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG then
		return "Leg"
	else
		return "Torso"
	end
end

function SWEP:GetOnsetTime(hitgroup)
	-- Return onset time in seconds based on injection site (much faster)
	if hitgroup == HITGROUP_HEAD then
		return math.random(1, 2) -- Head/Neck (jugular) - fastest
	elseif hitgroup == HITGROUP_CHEST then
		return math.random(3, 4) -- Chest
	elseif hitgroup == HITGROUP_STOMACH then
		return math.random(4, 5) -- Stomach
	elseif hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM then
		return math.random(5, 6) -- Arms
	elseif hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG then
		return math.random(6, 7) -- Legs - slowest
	else
		return math.random(4, 5) -- Default (torso)
	end
end

function SWEP:StartRecovery(target)
	if not IsValid(target) or not target:Alive() then return end
	
	-- Send recovery network message
	net.Start('RADS_M99_Recovery')
	net.WriteEntity(target)
	net.Broadcast()
	
	-- Stop oxygen loss effect during recovery
	target.m99OxygenLoss = false
	timer.Remove("M99_OxygenLoss_" .. target:EntIndex())
	
	-- Start gradual consciousness recovery
	timer.Create("M99_Recovery_Process_" .. target:EntIndex(), 1, 0, function()
		if not IsValid(target) or not target:Alive() or not target.m99Active then
			timer.Remove("M99_Recovery_Process_" .. target:EntIndex())
			return
		end
		
		-- Gradually restore consciousness
		target.consciousness = math.min((target.consciousness or 0) + 2, target.m99OriginalConsciousness or 100)
		
		-- Wake up when consciousness reaches 30
		if target.consciousness >= 30 then
			target.Otrub = false
			target:SetNWBool("Otrub", false)
		end
		
		-- Full recovery when consciousness is restored
		if target.consciousness >= (target.m99OriginalConsciousness or 100) then
			target.m99Active = false
			target.m99StartTime = nil
			target.m99OnsetTime = nil
			target.m99OriginalConsciousness = nil
			target.m99InjectionSite = nil
			-- Note: Keep injection count and times for tracking future overdoses
			
			timer.Remove("M99_Recovery_Process_" .. target:EntIndex())
			timer.Remove("M99_Recovery_" .. target:EntIndex())
		end
	end)
end

function SWEP:Deploy()
	if not IsFirstTimePredicted() then return end
	self.DownAmt = 8
	return true
end

function SWEP:Holster()
	return true
end

function SWEP:OnRemove()
	--
end

function SWEP:SecondaryAttack()
	--
end

function SWEP:Think()
	--
end

function SWEP:Reload()
	--
end

if CLIENT then
	function SWEP:GetViewModelPosition(pos, ang)
		if not self.DownAmt then self.DownAmt = 8 end
		if self:GetOwner():IsSprinting() and self:GetOwner():KeyDown(IN_FORWARD) then
			self.DownAmt = math.Clamp(self.DownAmt + .1, 0, 8)
		else
			self.DownAmt = math.Clamp(self.DownAmt - .1, 0, 8)
		end

		local NewPos = pos + ang:Forward() * 30 - ang:Up() * (8 + self.DownAmt) + ang:Right() * 10
		ang:RotateAroundAxis(ang:Right(), 60)
		return NewPos, ang
	end

	function SWEP:DrawWorldModel()
		local Pos, Ang = self:GetOwner():GetBonePosition(self:GetOwner():LookupBone("ValveBiped.Bip01_R_Hand"))
		if self.DatWorldModel then
			if Pos and Ang and IsValid(self:GetOwner()) then
				self.DatWorldModel:SetRenderOrigin(Pos + Ang:Forward() * 4 - Ang:Up() * 3 + Ang:Right() * 1.1)
				Ang:RotateAroundAxis(Ang:Right(), -90)
				self.DatWorldModel:SetRenderAngles(Ang)
				self.DatWorldModel:DrawModel()
				self.DatWorldModel:SetModelScale(.9, 0)
			end
		else
			self.DatWorldModel = ClientsideModel("models/weapons/w_models/w_jyringe_jroj.mdl")
			self.DatWorldModel:SetPos(self:GetPos())
			self.DatWorldModel:SetParent(self)
			self.DatWorldModel:SetNoDraw(true)
			self.DatWorldModel:SetModelScale(1, 0)
		end
	end

	function SWEP:ViewModelDrawn()
		--
	end
end