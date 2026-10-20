
if SERVER then
	AddCSLuaFile()
	SWEP.Spawnable = true
	SWEP.Weight = 5
	SWEP.AutoSwitchTo = false
	SWEP.AutoSwitchFrom = false
else
	SWEP.PrintName = "Hands"
	SWEP.Slot = 0
	SWEP.SlotPos = 1
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 69
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_hands")
	SWEP.BounceWeaponIcon = false
	local HandTex, ClosedTex = surface.GetTextureID("vgui/hud/hmcd_hand"), surface.GetTextureID("vgui/hud/hmcd_closedhand")

	function SWEP:DrawHUD()
		local owner = self:GetOwner()
		local Fake = owner:GetNWEntity("Ragdoll")
		if self:GetFists() then return end
		local Tr = util.QuickTrace(owner:GetShootPos(), owner:GetAimVector() * self.ReachDistance, {owner})

		if Tr.Hit then
			if self:CanPickup(Tr.Entity) then
				local Size = math.Clamp(1 - ((Tr.HitPos - owner:GetShootPos()):Length() / self.ReachDistance) ^ 2, .2, 1)

				if owner:KeyDown(IN_ATTACK2) then
					surface.SetTexture(ClosedTex)
				else
					surface.SetTexture(HandTex)
				end

				surface.SetDrawColor(Color(255, 255, 255, 255 * Size))
				surface.DrawTexturedRect(ScrW() / 2 - (64 * Size), ScrH() / 2 - (64 * Size), 128 * Size, 128 * Size)
			end
		end
	end
end

SWEP.Category = "Other"
SWEP.SwayScale = 3
SWEP.BobScale = 3
SWEP.Author = ""
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.Instructions = "Your hands. /n/n RMB To Pick up objects /n R to lower your fists"
SWEP.DrawWeaponInfoBox = false
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.HoldType = "normal"
SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = "models/props_junk/cardboard_box004a.mdl"
SWEP.AttackSlowDown = .5
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Spawnable = true
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.ReachDistance = 60
SWEP.HomicideSWEP = true

SWEP.NextPump = 0
SWEP.DangerLevel = 0
SWEP.NotLoot = true
SWEP.UseHands = true
SWEP.NextIdle = 0
SWEP.Fists = false
SWEP.Blocking = false
SWEP.UppercutWindow = 0
SWEP.LastBlockEnd = 0
SWEP.LastUppercutTime = 0
SWEP.BlockStartTime = 0
SWEP.BlockChargeTime = 0
SWEP.BlockCooldownEnd = 0

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "NextIdle")
	self:NetworkVar("Bool", 2, "Fists")
	self:NetworkVar("Float", 1, "NextDown")
	self:NetworkVar("Bool", 3, "Blocking")
	self:NetworkVar("Float", 4, "UppercutWindow")
	self:NetworkVar("Float", 5, "LastBlockEnd")
	self:NetworkVar("Float", 6, "LastUppercutTime")
	self:NetworkVar("Float", 7, "BlockStartTime")
	self:NetworkVar("Float", 8, "BlockChargeTime")
	self:NetworkVar("Float", 9, "BlockCooldownEnd")
end

-- Getter and setter methods for BlockStartTime
function SWEP:GetBlockStartTime()
	return self:GetNWFloat("BlockStartTime", 0)
end

function SWEP:SetBlockStartTime(time)
	self:SetNWFloat("BlockStartTime", time)
end

function SWEP:PreDrawViewModel(vm, wep, ply)
	if self:GetOwner().in_handcuff then return end

	vm:SetMaterial("engine/occlusionproxy")
end

function SWEP:Initialize()
	self:SetNextIdle(CurTime() + 5)
	self:SetNextDown(CurTime() + 5)
	self:SetHoldType(self.HoldType)
	self:SetFists(false)
	self:SetBlocking(false)
end

function SWEP:Deploy()
	if self:GetOwner().in_handcuff then return false end
	if not IsFirstTimePredicted() then
		self:DoBFSAnimation("fists_draw")
		self:GetOwner():GetViewModel():SetPlaybackRate(.1)

		return
	end

	self:SetNextPrimaryFire(CurTime() + .1)
	self:SetFists(false)
	self.DangerLevel = 0
	self:SetNextDown(CurTime())
	self:DoBFSAnimation("fists_draw")

	return true
end

function SWEP:Holster()
	self:OnRemove()

	return true
end

function SWEP:CanPrimaryAttack()
	if self:GetOwner().in_handcuff then return false end
	return true
end

local pickupWhiteList = {
	["prop_ragdoll"] = true,
	["prop_physics"] = true,
	["prop_physics_multiplayer"] = true,
	["func_physbox"] = true
}

function SWEP:CanPickup(ent)
	if self:GetOwner().Lost then return false end
	if string.find(ent:GetModel(), "zombie") ~= nil then return false end
	if ent:IsNPC() then return false end
	if self:GetOwner():GetGroundEntity() == ent then return false end
	if ent.IsLoot then return true end
	local class = ent:GetClass()
	if pickupWhiteList[class] then return true end

	return false
end

function SWEP:SecondaryAttack()
	if self:GetOwner().in_handcuff then return end
	if not IsFirstTimePredicted() then return end
	if self:GetFists() then return end
	
	-- Check for block cooldown after uppercut
	if CurTime() < self:GetBlockCooldownEnd() then
		return -- Block is on cooldown, cannot block
	end

	if SERVER then
		self:SetCarrying()
		local tr = self:GetOwner():GetEyeTraceNoCursor()

		if IsValid(tr.Entity) and self:CanPickup(tr.Entity) and not tr.Entity:IsPlayer() then
			local Dist = (self:GetOwner():GetShootPos() - tr.HitPos):Length()

			if Dist < self.ReachDistance then

				sound.Play("Flesh.ImpactSoft", self:GetOwner():GetShootPos(), 65, math.random(90, 110))
				self:SetCarrying(tr.Entity, tr.PhysicsBone, tr.HitPos, Dist)
				tr.Entity.Touched = true
				self:ApplyForce()
			end
		elseif IsValid(tr.Entity) and tr.Entity:IsPlayer() then
			local Dist = (self:GetOwner():GetShootPos() - tr.HitPos):Length()

			if Dist < self.ReachDistance then
				sound.Play("Flesh.ImpactSoft", self:GetOwner():GetShootPos(), 65, math.random(90, 110))
				self:GetOwner():SetVelocity(self:GetOwner():GetAimVector() * 20)
				tr.Entity:SetVelocity(-self:GetOwner():GetAimVector() * 50)
				self:SetNextSecondaryFire(CurTime() + .25)
			end
		end
	end
end

function SWEP:ApplyForce()
	local target = self:GetOwner():GetAimVector() * self.CarryDist + self:GetOwner():GetShootPos()
	local phys = self.CarryEnt:GetPhysicsObjectNum(self.CarryBone)

	if IsValid(phys) then
		local TargetPos = phys:GetPos()

		if self.CarryPos then
			TargetPos = self.CarryEnt:LocalToWorld(self.CarryPos)
		end

		local vec = target - TargetPos
		local len, mul = vec:Length(), self.CarryEnt:GetPhysicsObject():GetMass()

		if (len > self.ReachDistance) or (mul > 170) then
			self:SetCarrying()

			return
		end

		if self.CarryEnt:GetClass() == "prop_ragdoll" then
			mul = mul

			if self.LightBone then
				mul = mul / 6
			end
		end

		vec:Normalize()
		local avec, velo = vec * len, phys:GetVelocity() - self:GetOwner():GetVelocity()
		local CounterDir, CounterAmt = velo:GetNormalized(), velo:Length()

		if self.CarryPos then
			phys:ApplyForceOffset((avec - velo / 2) * mul, self.CarryEnt:LocalToWorld(self.CarryPos))
		else
			phys:ApplyForceCenter((avec - velo / 2) * mul)
		end

		phys:ApplyForceCenter(Vector(0, 0, mul))
		phys:AddAngleVelocity(-phys:GetAngleVelocity() / 10)
	end
end

function SWEP:OnRemove()
	if IsValid(self:GetOwner()) and CLIENT and self:GetOwner():IsPlayer() then
		local vm = self:GetOwner():GetViewModel()

		if IsValid(vm) then
			vm:SetMaterial("")
		end
	end
end

local handBones = {
	["swat_male"] = {11, 13},
	["military"] = {11, 13},
	["monolithservers/mpd"] = {11, 13},
	["gordon_freeman"] = {10, 7}
}

function SWEP:SetCarrying(ent, bone, pos, dist)
	if IsValid(ent) then
		self.CarryEnt = ent
		self.CarryEnt.Carrier = self:GetOwner()
		self.CarryBone = bone
		self.CarryDist = dist

		local hands = {5, 7}

		local mod = self.CarryEnt:GetModel()

		for i, info in pairs(handBones) do
			if string.find(mod, i) then
				hands = info
				break
			end
		end

		self.LightBone = ent:GetPhysicsObjectNum(bone):GetMass() < 3
		self.HandBones = hands

		if not (ent:GetClass() == "prop_ragdoll") then
			self.CarryPos = ent:WorldToLocal(pos)
		else
			self.CarryPos = nil
		end

		ent.LastCarrier = self:GetOwner()
	else
		if IsValid(self.CarryEnt) then
			self.CarryEnt.Carrier = nil
		end

		self.CarryEnt = nil
		self.CarryBone = nil
		self.CarryPos = nil
		self.CarryDist = nil
	end
end
function SWEP:CheckStatus(ply)
	if CLIENT then return end
	if self.NextPulseCheck >= CurTime() then return end
	local owner = RagdollOwner(ply)
	self.NextPulseCheck = CurTime() + 1
	self:GetOwner():PrintMessage(HUD_PRINTTALK, "Body is " .. self.CarryEnt.temp)
	self:GetOwner():PrintMessage(HUD_PRINTTALK, "Eyes is " .. (self.CarryEnt.eye == true and "open") or "close")
	if self.CarryEnt.temp == "Cold" then
		self.CarryEnt.canaccept_dead = true
	end
end



function SWEP:Think()
	if self:GetOwner().in_handcuff then return end
	if IsValid(self:GetOwner()) and self:GetOwner():KeyDown(IN_ATTACK2) and not self:GetFists() then
		if IsValid(self.CarryEnt) and not (IsValid(self:GetOwner():GetGroundEntity()) and self:GetOwner():GetGroundEntity() == self.CarryEnt) then
			self:ApplyForce()
		end
	elseif self.CarryEnt then
		self:SetCarrying()
	end

	if self:GetFists() and self:GetOwner():KeyDown(IN_ATTACK2) then
		-- Check for block cooldown after uppercut
		if CurTime() < self:GetBlockCooldownEnd() then
			-- Block is on cooldown, cannot block
			self:SetBlocking(false)
		else
			self:SetNextPrimaryFire(CurTime() + .1)
			-- Track when blocking starts for charge system
			if not self:GetBlocking() then
				self:SetBlockStartTime(CurTime())
			end
			self:SetBlocking(true)
		end
	else
		-- Track when blocking stops for uppercut window and charge calculation
		if self:GetBlocking() then
			self:SetLastBlockEnd(CurTime())
			self:SetUppercutWindow(CurTime() + 2) -- 2 second window
			-- Calculate block charge time (capped at 5 seconds)
			local chargeTime = math.min(CurTime() - self:GetBlockStartTime(), 5)
			self:SetBlockChargeTime(chargeTime)
		end
		self:SetBlocking(false)
	end

	local HoldType = "fist"

	if self:GetFists() then
		HoldType = "fist"
		local Time = CurTime()

		if self:GetNextIdle() < Time then
			self:DoBFSAnimation("fists_idle_0" .. math.random(1, 2))
			self:UpdateNextIdle()
		end

		if self:GetBlocking() then
			self:SetNextDown(Time + 1)
			HoldType = "camera"
		end

		if (self:GetNextDown() < Time) or self:GetOwner():KeyDown(IN_SPEED) then
			self:SetNextDown(Time + 1)
			self:SetFists(false)
			self.DangerLevel = 0
			self:SetBlocking(false)
		end
	else
		HoldType = "normal"
		self:DoBFSAnimation("fists_draw")
	end

	if IsValid(self.CarryEnt) or self.CarryEnt then
		HoldType = "magic"
	end

	if self:GetOwner():KeyDown(IN_SPEED) then
		HoldType = "normal"
	end
	if SERVER then
		if self.CarryEnt != nil then
			local bone = self.CarryEnt:TranslatePhysBoneToBone(self.CarryBone)
			local Lhand = self.CarryEnt:LookupBone("ValveBiped.Bip01_L_Hand")
			local Rhand = self.CarryEnt:LookupBone("ValveBiped.Bip01_R_Hand")

			local Lprhand = self.CarryEnt:LookupBone("ValveBiped.Bip01_L_Forearm")
			local Rprhand = self.CarryEnt:LookupBone("ValveBiped.Bip01_R_Forearm")

			if fs and self:GetOwner():KeyDown(IN_RELOAD) then
				self:CheckStatus(self.CarryEnt)
			end
		end
		self:SetHoldType(HoldType)
	end
end

function SWEP:PrimaryAttack()
	if self:GetOwner().in_handcuff then return end
	local vehicle = self:GetOwner():GetVehicle()
	if IsValid(vehicle) and IsValid(vehicle:GetParent()) and vehicle:GetParent().Base == "lunasflightschool_basescript_heli" then return end

	if self:GetOwner():KeyDown(IN_ATTACK2) then
		if IsValid(self.CarryEnt) then
			local owner = RagdollOwner(self.CarryEnt)

			if IsValid(self.CarryEnt) and IsValid(owner) and owner.DrownTime then
				local Tr = util.QuickTrace(self.CarryEnt:GetPos(), vector_up * -10, {self.CarryEnt, self:GetOwner()})

				if not self.CarryEnt.NextPump then
					self.CarryEnt.NextPump = 0
				end

				if Tr.Hit and self.CarryEnt.NextPump < CurTime() then
					local phys = self.CarryEnt:GetPhysicsObjectNum(self.CarryBone)

					if not self.CarryEnt.Pumps then
						self.CarryEnt.Pumps = 0
						self.CarryEnt.PumpsRequired = math.random(20, 30)
					end

					self.CarryEnt.Pumps = self.CarryEnt.Pumps + 1
					phys:ApplyForceCenter(Vector(0, 0, -5000))

					if self.CarryEnt.Pumps >= self.CarryEnt.PumpsRequired and not ((owner.DigestedContents["RightLung_BloodLevel"] or 0) + (owner.DigestedContents["LeftLung_BloodLevel"] or 0) == 90) then
						owner.DrownTime = nil
						owner.HeartAttack = nil
						owner.NextAgonalMoan = nil

						if owner:CanWakeUp() then
							owner:SetUnconscious(false)
						end

						self.CarryEnt.Pumps = nil
						self.CarryEnt.PumpsRequired = nil
					end

					self.CarryEnt.NextPump = CurTime() + 0.5
				end
			end
		end

		return
	end
	local sideright = math.random(1, 1.2)
	local side = "fists_left"

	if sideright == 1 then
		side = "fists_right"
	end

	self:SetNextDown(CurTime() + 7)

	if not self:GetFists() then
		self:SetFists(true)
		self.DangerLevel = 40
		self:DoBFSAnimation("fists_draw")
		self:SetNextPrimaryFire(CurTime() + .35)

		return
	end
	if self:GetBlocking() then return end

	if not IsFirstTimePredicted() then
		self:DoBFSAnimation(side)
		self:GetOwner():GetViewModel():SetPlaybackRate(1.25)

		return
	end

	self:GetOwner():ViewPunch(Angle(0, 0, math.random(-0.2, 0.5)))
	self:DoBFSAnimation(side)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	local ply = self:GetOwner()
	if ply:GetNWFloat("RightArm", 1) < 0.5 then
		self:GetOwner():GetViewModel():SetPlaybackRate(0.75)
	elseif ply:GetNWFloat("LeftArm", 1) < 0.5 then
		self:GetOwner():GetViewModel():SetPlaybackRate(0.75)
	else
		self:GetOwner():GetViewModel():SetPlaybackRate(1.25)
	end
	self:UpdateNextIdle()
	sound.Play("weapons/slam/throw.wav", self:GetPos(), 65, math.random(90, 110))
	if SERVER then
		self:GetOwner():ViewPunch(Angle(0, 0, math.random(-2, 2)))
		local isUppercut = false
		
		-- Check if we're in the uppercut window, not in uppercut cooldown, and reset it immediately to prevent multiple triggers
		if self:GetUppercutWindow() > 0 and CurTime() <= self:GetUppercutWindow() and CurTime() >= self:GetLastUppercutTime() + 1 then
			isUppercut = true
			self:SetUppercutWindow(0) -- Reset immediately to prevent multiple attacks
			self:SetLastUppercutTime(CurTime()) -- Set uppercut cooldown
			-- Immediately trigger uppercut animation and stronger viewpunch
			self:DoBFSAnimation("fists_uppercut")
			self:GetOwner():ViewPunch(Angle(-12, 0, 0)) -- Stronger upward viewpunch for attacker
			-- Add blocking cooldown after uppercut to prevent spam
			self:SetNextSecondaryFire(CurTime() + 0.75)
			-- Reset block charge time after using it
			self:SetBlockChargeTime(0)
		end

		timer.Simple(.075, function()
			if IsValid(self) then
				if isUppercut then
			self:UppercutAttack()
			-- Set 2-second cooldown for uppercut
			self:SetNextPrimaryFire(CurTime() + 0.65)
			-- Set 2-second block cooldown after uppercut
			self:SetBlockCooldownEnd(CurTime() + 0.75)
		else
					self:AttackFront()
				end
			end
		end)
	end
	
	-- Only set normal cooldowns if it's not an uppercut
	if not isUppercut then
		if ply:GetNWFloat("RightArm", 1) < 0.5 and ply:GetNWFloat("LeftArm", 1) < 0.5 then
			self:SetNextPrimaryFire(CurTime() + 2)
		elseif ply:GetNWFloat("RightArm", 1) < 0.5 or ply:GetNWFloat("LeftArm", 1) < 0.5 then
			self:SetNextPrimaryFire(CurTime() + 1)
		else
			self:SetNextPrimaryFire(CurTime() + .35)
		end
	end
	self:SetNextSecondaryFire(CurTime() + .35)
end

function SWEP:AttackFront()
	if self:GetOwner().in_handcuff then return end
	if CLIENT then return end
	self:GetOwner():LagCompensation(true)
	local Ent, HitPos, HitNorm, Hitbox = HMCD_WhomILookinAt(self:GetOwner(), .3, 55)
	local AimVec = self:GetOwner():GetAimVector()

	if IsValid(Ent) or (Ent and Ent.IsWorld and Ent:IsWorld()) then
		local owner = Ent

		if Ent:GetClass() == "prop_ragdoll" then
			local Tr = util.QuickTrace(self:GetOwner():GetShootPos(), self:GetOwner():GetAimVector() * self.ReachDistance, {self:GetOwner()})

		end

		local SelfForce, Mul = 125, 1

		if self:IsEntSoft(Ent) then
			SelfForce = 25

			if Ent:IsPlayer() and IsValid(Ent:GetActiveWeapon()) and Ent:GetActiveWeapon().GetBlocking and Ent:GetActiveWeapon():GetBlocking() then
				local pos, ang = Ent:GetBonePosition(Ent:LookupBone("ValveBiped.Bip01_R_Hand"))
				ang:RotateAroundAxis(ang:Right(), 90)

				if util.IntersectRayWithOBB(self:GetOwner():GetShootPos(), self:GetOwner():GetAimVector() * self.ReachDistance, pos + ang:Right() * 5, ang, Vector(-10, -10, -7), Vector(10, 10, 7)) ~= nil then
					sound.Play("Flesh.ImpactSoft", HitPos, 65, math.random(90, 110))
					Mul = Mul * 0.2
					local pos_l = Ent:GetBonePosition(Ent:LookupBone("ValveBiped.Bip01_L_Hand"))
					local startpos = self:GetOwner():GetShootPos() + self:GetOwner():GetAimVector() * 3
				else
					sound.Play("Flesh.ImpactHard", HitPos, 65, math.random(90, 110))
				end
			else
				sound.Play("Flesh.ImpactHard", HitPos, 65, math.random(90, 110))
			end
		else
			sound.Play("Flesh.ImpactSoft", HitPos, 65, math.random(90, 110))
		end

		local DamageAmt = math.random(2, 4)
		local Dam = DamageInfo()
		Dam:SetAttacker(self:GetOwner())
		Dam:SetInflictor(self.Weapon)
		Dam:SetDamage(DamageAmt * Mul)
		Dam:SetDamageForce(AimVec * Mul ^ 1.2 / 2)
		Dam:SetDamageType(DMG_CLUB)
		Dam:SetDamagePosition(HitPos)

		if owner:IsPlayer() or owner:IsRagdoll() or owner:IsNPC() then
		end

		Dam:SetDamage(math.Clamp(Dam:GetDamage(), 0, DamageAmt))
		Ent:TakeDamageInfo(Dam)
		
		-- Strong upward viewpunch for victim regardless of hit location
		if Ent:IsPlayer() then
			Ent:ViewPunch(Angle(-8, 0, 0)) -- Strong upward viewpunch for victim
		end
		local Phys = Ent:GetPhysicsObject()

		if IsValid(Phys) then
			if Ent:IsPlayer() then
				Ent:SetVelocity(AimVec * SelfForce * 1.5)
			end

			Phys:ApplyForceOffset(AimVec * 5000 * Mul, HitPos)
			self:GetOwner():SetVelocity(AimVec * SelfForce * .8)
		end	

		if SERVER then	
			if Ent.HP == nil then
				Ent.HP = 100
			end
			if Ent:GetClass() == "func_breakable_surf" then
				Ent.HP = Ent.HP - Dam:GetDamage() * 4
				print(Ent.HP)
				if Ent.HP <= 0 then
					Ent:Fire("break", "", 0)
					if SERVER then
						if Ent:GetMaterialType() == MAT_GLASS then
							self:GetOwner().Bleed = self:GetOwner().Bleed + 40
						else
							self:GetOwner().Bleed = self:GetOwner().Bleed + 15
						end
					end
				end
			end
		end
	end

	self:GetOwner():LagCompensation(false)
end

function SWEP:UppercutAttack()
	if self:GetOwner().in_handcuff then return end
	if CLIENT then return end
	self:GetOwner():LagCompensation(true)
	local Ent, HitPos, HitNorm, Hitbox = HMCD_WhomILookinAt(self:GetOwner(), .3, 55)
	local AimVec = self:GetOwner():GetAimVector()

	if IsValid(Ent) or (Ent and Ent.IsWorld and Ent:IsWorld()) then
		local owner = Ent
		local isHeadHit = false
		local isJawHit = false

		if Ent:GetClass() == "prop_ragdoll" then
			local Tr = util.QuickTrace(self:GetOwner():GetShootPos(), self:GetOwner():GetAimVector() * self.ReachDistance, {self:GetOwner()})
			-- Check if hit is targeting head/jaw area
			local headBone = Ent:LookupBone("ValveBiped.Bip01_Head1")
			if headBone then
				local headPos = Ent:GetBonePosition(headBone)
				local distToHead = HitPos:Distance(headPos)
				if distToHead < 15 then -- Within head area
					isHeadHit = true
					-- Check if hit is in jaw area (lower part of head)
					if HitPos.z < headPos.z - 3 then
						isJawHit = true
					end
				end
			end
		end

		local SelfForce, Mul = 200, 1.5 -- Increased force for uppercut

		if self:IsEntSoft(Ent) then
			SelfForce = 50

			if Ent:IsPlayer() and IsValid(Ent:GetActiveWeapon()) and Ent:GetActiveWeapon().GetBlocking and Ent:GetActiveWeapon():GetBlocking() then
				local pos, ang = Ent:GetBonePosition(Ent:LookupBone("ValveBiped.Bip01_R_Hand"))
				ang:RotateAroundAxis(ang:Right(), 90)

				if util.IntersectRayWithOBB(self:GetOwner():GetShootPos(), self:GetOwner():GetAimVector() * self.ReachDistance, pos + ang:Right() * 5, ang, Vector(-10, -10, -7), Vector(10, 10, 7)) ~= nil then
					sound.Play("Flesh.ImpactSoft", HitPos, 65, math.random(90, 110))
					Mul = Mul * 0.3 -- Reduced effectiveness against blocking
				else
					sound.Play("Flesh.ImpactHard", HitPos, 65, math.random(90, 110))
				end
			else
				sound.Play("Flesh.ImpactHard", HitPos, 65, math.random(90, 110))
			end
		else
			sound.Play("Flesh.ImpactSoft", HitPos, 65, math.random(90, 110))
		end

		-- Enhanced damage calculation for uppercut with charge system
		local baseDamage = math.random(15, 25) -- Significantly increased base uppercut damage
		-- Calculate charge multiplier (1.0 to 3.0 based on 0-5 second charge)
		local chargeMultiplier = 1 + (self:GetBlockChargeTime() / 5) * 2 -- 1x to 3x damage based on charge
		local DamageAmt = baseDamage * chargeMultiplier
		
		if isHeadHit then
			DamageAmt = DamageAmt * 1.5 -- 50% more damage to head
			if isJawHit then
				DamageAmt = DamageAmt * 1.3 -- Additional 30% for jaw hits
			end
		end
		
		-- Consciousness reduction for head hits
		if SERVER and isHeadHit and Ent:IsPlayer() then
			-- Every uppercut to head reduces consciousness by 10
			if Ent.consciousness then
				Ent.consciousness = math.max(0, Ent.consciousness - 10)
			else
				Ent.consciousness = 90 -- Default consciousness is 100, reduce by 10
			end
		end

		local Dam = DamageInfo()
		Dam:SetAttacker(self:GetOwner())
		Dam:SetInflictor(self.Weapon)
		Dam:SetDamage(DamageAmt * Mul)
		-- Upward force vector for uppercut
		local uppercutForce = AimVec + Vector(0, 0, 0.8) -- Add significant upward component
		uppercutForce:Normalize()
		Dam:SetDamageForce(uppercutForce * Mul ^ 1.2)
		Dam:SetDamageType(DMG_CLUB)
		Dam:SetDamagePosition(HitPos)

		if owner:IsPlayer() or owner:IsRagdoll() or owner:IsNPC() then
		end

		Dam:SetDamage(math.Clamp(Dam:GetDamage(), 0, DamageAmt))
		Ent:TakeDamageInfo(Dam)
		
		-- Strong upward viewpunch for victim regardless of hit location
		if Ent:IsPlayer() then
			Ent:ViewPunch(Angle(-20, 0, 0)) -- Strong upward viewpunch for victim
		end
		
		local Phys = Ent:GetPhysicsObject()

		if IsValid(Phys) then
			if Ent:IsPlayer() then
				-- Apply upward velocity for uppercut effect
				local uppercutVel = AimVec * SelfForce + Vector(0, 0, SelfForce * 0.8)
				Ent:SetVelocity(uppercutVel)
			end

			-- Apply upward force to physics object
			local uppercutPhysForce = uppercutForce * 8000 * Mul
			Phys:ApplyForceOffset(uppercutPhysForce, HitPos)
			self:GetOwner():SetVelocity(AimVec * SelfForce * .6)
		end

		-- Special ragdoll effect for clean head/jaw hits
		if SERVER and isHeadHit and Ent:IsPlayer() and not Ent:GetNWBool("radsfa") then
			-- Force ragdoll on clean uppercut to head
			timer.Simple(0.1, function()
				if IsValid(Ent) and Ent:Alive() then
					rads(Ent, false) -- Trigger ragdoll
					-- Apply additional upward force to ragdoll head
					timer.Simple(0.2, function()
						if IsValid(Ent) then
							local ragdoll = Ent:GetNWEntity("player_ragdoll")
							if IsValid(ragdoll) then
								local headBoneIndex = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
								if headBoneIndex then
									local physBone = ragdoll:TranslateBoneToPhysBone(headBoneIndex)
									if physBone >= 0 then
										local headPhys = ragdoll:GetPhysicsObjectNum(physBone)
										if IsValid(headPhys) then
											-- Apply strong upward force from jaw position
											local jawPos = ragdoll:GetBonePosition(headBoneIndex) + Vector(0, 0, -5)
											headPhys:ApplyForceOffset(Vector(0, 0, 15000) + AimVec * 5000, jawPos)
										end
									end
								end
							end
						end
					end)
				end
			end)
		end

		if SERVER then
			if Ent.HP == nil then
				Ent.HP = 100
			end
			if Ent:GetClass() == "func_breakable_surf" then
				Ent.HP = Ent.HP - Dam:GetDamage() * 4
				if Ent.HP <= 0 then
					Ent:Fire("break", "", 0)
					if SERVER then
						if Ent:GetMaterialType() == MAT_GLASS then
							self:GetOwner().Bleed = self:GetOwner().Bleed + 40
						else
							self:GetOwner().Bleed = self:GetOwner().Bleed + 15
						end
					end
				end
			end
		end
	end

	self:GetOwner():LagCompensation(false)
end

function SWEP:Reload()
	if not IsFirstTimePredicted() then return end
	self:SetFists(false)
	self.DangerLevel = 0
	self:SetBlocking(false)
end

function SWEP:DrawWorldModel()
end

-- no, do nothing
function SWEP:DoBFSAnimation(anim)
	local vm = self:GetOwner():GetViewModel()

	if IsValid(vm) then
		vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
	end
end

function SWEP:UpdateNextIdle()
	if self:GetOwner().in_handcuff then return end
	local vm = self:GetOwner():GetViewModel()

	if IsValid(self) and IsValid(vm) then
		self:SetNextIdle(CurTime() + vm:SequenceDuration())
	end
end

function SWEP:IsEntSoft(ent)
	return ent:IsNPC() or ent:IsPlayer() or (ent:IsRagdoll() and ent.fleshy)
end

-- Prevent dropping the hands weapon when the system is enabled
function SWEP:CanDrop()
	-- Check if the fists on spawn system is enabled
	local fistsOnSpawn = GetConVar("rads_fists_on_spawn")
	if fistsOnSpawn and fistsOnSpawn:GetInt() == 1 then
		return false -- Prevent dropping when system is enabled
	end
	return true -- Allow dropping when system is disabled
end

if CLIENT then
	local BlockAmt = 0

	function SWEP:GetViewModelPosition(pos, ang)
		if self:GetBlocking() then
			BlockAmt = math.Clamp(BlockAmt + FrameTime() * 1.5, 0, 1)
		else
			BlockAmt = math.Clamp(BlockAmt - FrameTime() * 1.5, 0, 1)
		end

		pos = pos - ang:Up() * 15 * BlockAmt
		ang:RotateAroundAxis(ang:Right(), BlockAmt * 60)

		return pos, ang
	end
end