if SERVER then
	AddCSLuaFile()
elseif CLIENT then
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 55
	SWEP.Slot = 3
	SWEP.SlotPos = 3
	killicon.AddFont("wep_jack_hmcd_bandage", "HL2MPTypeDeath", "5", Color(0, 0, 255, 255))
	function SWEP:Initialize()
		--wat
	end

	function SWEP:DrawViewModel()
		return false
	end

	function SWEP:DrawWorldModel()
		self:DrawModel()
	end

	function SWEP:DrawHUD()
		--
	end
end

SWEP.Base = "weapon_base"
SWEP.ViewModel = "models/bandages.mdl"
SWEP.WorldModel = "models/bandages.mdl"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_bandage")
	SWEP.BounceWeaponIcon = false
end

SWEP.PrintName = "Large Bandage"
SWEP.Instructions = "A large bandage for treating moderate wounds. Stops most bleeding and removes many wounds.\n\nLMB to bandage (self or others/ragdolls)"
SWEP.Author = ""
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.BobScale = 3
SWEP.SwayScale = 3
SWEP.Weight = 3
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false
SWEP.CommandDroppable = true
SWEP.DeathDroppable = true
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "Medical Items"
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
SWEP.ENT = "ent_jack_hmcd_bandagebig"
SWEP.DownAmt = 0
SWEP.HomicideSWEP = true
SWEP.CarryWeight = 600
function SWEP:Initialize()
	self:SetHoldType("slam")
	self.DownAmt = 20
end

function SWEP:SetupDataTables()
	--
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	self:SetNextPrimaryFire(CurTime() + 1)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	if CLIENT then return end
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	-- Check if player can use medical items on ragdolls
	local target = ply
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * 80,
		filter = ply
	})

	-- Check if aiming at another player or ragdoll
	if IsValid(tr.Entity) then
		if tr.Entity:IsPlayer() then
			target = tr.Entity
		elseif tr.Entity:IsRagdoll() and tr.Entity:GetNWEntity("owner") and tr.Entity:GetNWEntity("owner"):IsPlayer() then
			target = tr.Entity:GetNWEntity("owner")
		end
	end

	-- Initialize bleeding variables if needed
	if not target.BloodLosing then target.BloodLosing = 0 end
	if not target.wounds then target.wounds = {} end

	-- Check if target needs bandaging
	local BloodLosing = target.BloodLosing or 0
	local woundCount = #target.wounds
	if BloodLosing <= 0 and woundCount <= 0 then
		return
	end

	-- Bandage target

	sound.Play("snd_jack_hmcd_bandage.wav", target:GetShootPos(), 60, math.random(90, 100))
	ply:ViewPunch(Angle(-10, 0, 0))

	if BloodLosing > 0 or woundCount > 0 then
		-- Large bandage can stop heavy bleeding (up to 40 units)
		if BloodLosing <= 40 then
			target.BloodLosing = 0
			-- Clear wounds (large bandage can handle up to 12 wounds)
			local woundsToRemove = math.min(12, woundCount)
			for i = 1, woundsToRemove do
				table.remove(target.wounds, 1)
			end
		else
			-- Reduce bleeding by 35 units (extremely effective)
			target.BloodLosing = math.max(0, BloodLosing - 35)
			-- Remove up to 12 wounds
			local woundsToRemove = math.min(12, woundCount)
			for i = 1, woundsToRemove do
				table.remove(target.wounds, 1)
			end
		end

		-- Add health restoration
		target:SetHealth(math.Clamp(target:Health() + 12, 0, target:GetMaxHealth()))

		-- Add significant pain relief
		if not target.pain then target.pain = 0 end
		target.pain = math.max(0, target.pain - 75)

		-- Add bleeding resistance for 60 seconds
		target.bleedingResistanceEndTime = CurTime() + 60
		target.bleedingResistanceMultiplier = 0.5 -- Reduce bleeding rate by 50%

		-- Stop minor internal bleeding (InternalBleeding6)
		if target.InternalBleeding6 and target.InternalBleeding6 > 0 then
			target.InternalBleeding6 = 0
		end

		-- Send pain update if available
		if net and net.Start and IsValid(target) and target:IsPlayer() and not target:IsBot() then
			net.Start('RADS_PainUpdate')
			net.WriteFloat(target.pain or 0)
			net.Send(target)
		end


	end

	-- Remove blood decals
	util.Decal("Blood", target:GetPos() + Vector(0, 0, 50), target:GetPos() + Vector(0, 0, -50), target)
	util.Decal("", target:GetPos() + Vector(0, 0, 50), target:GetPos() + Vector(0, 0, -50), target)

	self:Remove()
end

function SWEP:Deploy()
	self:SetNextPrimaryFire(CurTime() + 1)
	self.DownAmt = 20
	self:EmitSound("player/weapon_draw_0" .. math.random(1, 5) .. ".wav", 70, self.HandlingPitch)
	return true
end

function SWEP:SecondaryAttack()
	-- Secondary attack is now the same as primary attack for consistency
	self:PrimaryAttack()
end

function SWEP:Think()
	if SERVER then
		local HoldType = "slam"
		if self:GetOwner():IsSprinting() and self:GetOwner():KeyDown(IN_FORWARD) then HoldType = "normal" end
		self:SetHoldType(HoldType)
	end
end

function SWEP:Reload()
	--
end

function SWEP:OnDrop()
	-- Check if owner is getting up from ragdoll to prevent duplication
	local owner = self:GetOwner()
	if IsValid(owner) and owner.gettingUpFromRagdoll then
		return
	end
	
	-- Check if the weapon itself has the flag (for when owner becomes invalid)
	if self.ownerGettingUpFromRagdoll then
		return
	end
	
	local Ent = ents.Create(self.ENT)
	Ent.HmcdSpawned = self.HmcdSpawned
	Ent:SetPos(self:GetPos())
	Ent:SetAngles(self:GetAngles())
	Ent:Spawn()
	Ent:Activate()
	Ent:GetPhysicsObject():SetVelocity(self:GetVelocity() / 2)
	self:Remove()
end

if CLIENT then
	function SWEP:PreDrawViewModel(vm, ply, wep)
		--
	end

	function SWEP:GetViewModelPosition(pos, ang)
		if not self.DownAmt then self.DownAmt = 0 end
		if self:GetOwner():IsSprinting() and self:GetOwner():KeyDown(IN_FORWARD) then
			self.DownAmt = math.Clamp(self.DownAmt + .2, 0, 20)
		else
			self.DownAmt = math.Clamp(self.DownAmt - .2, 0, 20)
		end

		pos = pos - ang:Up() * (self.DownAmt + 9) + ang:Forward() * 25 + ang:Right() * 8
		ang:RotateAroundAxis(ang:Up(), 90)
		ang:RotateAroundAxis(ang:Right(), -15)
		ang:RotateAroundAxis(ang:Forward(), -10)
		return pos, ang
	end

	function SWEP:DrawWorldModel()
		local Pos, Ang = self:GetOwner():GetBonePosition(self:GetOwner():LookupBone("ValveBiped.Bip01_R_Hand"))
		if self.DatWorldModel then
			if Pos and Ang and IsValid(self:GetOwner()) then
				self.DatWorldModel:SetRenderOrigin(Pos + Ang:Forward() * 3)
				Ang:RotateAroundAxis(Ang:Up(), 90)
				Ang:RotateAroundAxis(Ang:Right(), 90)
				self.DatWorldModel:SetRenderAngles(Ang)
				self.DatWorldModel:DrawModel()
			end
		else
			self.DatWorldModel = ClientsideModel("models/bandages.mdl")
			self.DatWorldModel:SetPos(self:GetPos())
			self.DatWorldModel:SetParent(self)
			self.DatWorldModel:SetNoDraw(true)
		end
	end
end