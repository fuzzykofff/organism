if SERVER then
	AddCSLuaFile()
elseif CLIENT then
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 55
	SWEP.Slot = 3
	SWEP.SlotPos = 3
	killicon.AddFont("wep_jack_hmcd_medkit", "HL2MPTypeDeath", "5", Color(0, 0, 255, 255))
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
SWEP.ViewModel = "models/w_models/weapons/w_eq_medkit.mdl"
SWEP.WorldModel = "models/w_models/weapons/w_eq_medkit.mdl"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_medkit")
	SWEP.BounceWeaponIcon = false
end

SWEP.PrintName = "First-Aid Kit"
SWEP.Instructions = "A comprehensive first-aid kit. Stops bleeding, provides pain relief, and treats arterial bleeding.\n\nLMB to treat (self or others/ragdolls)"
SWEP.Author = ""
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.BobScale = 3
SWEP.SwayScale = 3
SWEP.Weight = 3
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false
SWEP.CommandDroppable = true
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
SWEP.ENT = "ent_jack_hmcd_medkit"
SWEP.DownAmt = 0
SWEP.HomicideSWEP = true
SWEP.DeathDroppable = true
SWEP.CarryWeight = 1800
function SWEP:Initialize()
	self:SetHoldType("slam")
	self.DownAmt = 20
end

function SWEP:SetupDataTables()
	--
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	self:SetNextPrimaryFire(CurTime() + 2) -- Longer cooldown for medkit
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

	-- Initialize variables if needed
	if not target.BloodLosing then target.BloodLosing = 0 end
	if not target.wounds then target.wounds = {} end
	if not target.pain then target.pain = 0 end
	-- Check if target needs medical treatment
	local needsTreatment = false
	if target.BloodLosing and target.BloodLosing > 0 then needsTreatment = true end
	if target.wounds and #target.wounds > 0 then needsTreatment = true end
	if target.pain and target.pain > 0 then needsTreatment = true end
	-- Check for internal bleeding (using the numbered system)
	if (target.InternalBleeding and target.InternalBleeding > 0) or
	   (target.InternalBleeding2 and target.InternalBleeding2 > 0) or
	   (target.InternalBleeding3 and target.InternalBleeding3 > 0) or
	   (target.InternalBleeding4 and target.InternalBleeding4 > 0) or
	   (target.InternalBleeding5 and target.InternalBleeding5 > 0) or
	   (target.InternalBleeding6 and target.InternalBleeding6 > 0) then
		needsTreatment = true
	end
	if target:Health() < target:GetMaxHealth() then needsTreatment = true end

	-- Prevent use if no treatment needed
	if not needsTreatment then
		return
	end

	sound.Play("snd_jack_hmcd_bandage.wav", target:GetShootPos(), 60, math.random(90, 110))
	ply:ViewPunch(Angle(-10, 0, 0))

	-- Stop most bleeding (medkit is extremely effective)
	local BloodLosing = target.BloodLosing or 0
	local woundCount = #target.wounds

	-- Medkit can stop severe bleeding (up to 75 units)
	if BloodLosing <= 75 then
		target.BloodLosing = 0
	else
		target.BloodLosing = math.max(0, BloodLosing - 60)
	end

	-- Remove most wounds (medkit can handle up to 15 wounds)
	local woundsToRemove = math.min(15, woundCount)
	for i = 1, woundsToRemove do
		table.remove(target.wounds, 1)
	end

	-- Stop the most dangerous arterial bleeding
	-- Stop internal bleeding (using the numbered system)
	local stoppedBleeding = false
	local organName = ""
	
	-- Find and stop the most severe internal bleeding
	if target.InternalBleeding4 and target.InternalBleeding4 > 0 then
		target.InternalBleeding4 = 0
		organName = "heart"
		stoppedBleeding = true
	elseif target.InternalBleeding and target.InternalBleeding > 0 then
		target.InternalBleeding = 0
		organName = "liver"
		stoppedBleeding = true
	elseif target.InternalBleeding5 and target.InternalBleeding5 > 0 then
		target.InternalBleeding5 = 0
		organName = "lungs"
		stoppedBleeding = true
	elseif target.InternalBleeding2 and target.InternalBleeding2 > 0 then
		target.InternalBleeding2 = 0
		organName = "stomach"
		stoppedBleeding = true
	elseif target.InternalBleeding3 and target.InternalBleeding3 > 0 then
		target.InternalBleeding3 = 0
		organName = "intestines"
		stoppedBleeding = true
	elseif target.InternalBleeding6 and target.InternalBleeding6 > 0 then
		target.InternalBleeding6 = 0
		organName = "general"
		stoppedBleeding = true
	end
	
	if stoppedBleeding then
	end

	-- Provide significant pain relief (painkiller effect)
	if target.pain and target.pain > 0 then
		target.pain = math.max(0, target.pain - 200)
		-- Set up pain reduction multiplier for 5 minutes
		target.painKillerEndTime = CurTime() + 300
		target.painKillerMultiplier = 0.2 -- Reduce pain gain by 80%
	end

	-- Stop all types of internal bleeding
	local internalBleedingStopped = false
	if target.InternalBleeding1 and target.InternalBleeding1 > 0 then
		target.InternalBleeding1 = 0
		internalBleedingStopped = true
	end
	if target.InternalBleeding2 and target.InternalBleeding2 > 0 then
		target.InternalBleeding2 = 0
		internalBleedingStopped = true
	end
	if target.InternalBleeding3 and target.InternalBleeding3 > 0 then
		target.InternalBleeding3 = 0
		internalBleedingStopped = true
	end
	if target.InternalBleeding4 and target.InternalBleeding4 > 0 then
		target.InternalBleeding4 = 0
		internalBleedingStopped = true
	end
	if target.InternalBleeding5 and target.InternalBleeding5 > 0 then
		target.InternalBleeding5 = 0
		internalBleedingStopped = true
	end
	if target.InternalBleeding6 and target.InternalBleeding6 > 0 then
		target.InternalBleeding6 = 0
		internalBleedingStopped = true
	end

	-- Add infection resistance for 10 minutes
	target.infectionResistanceEndTime = CurTime() + 600
	target.infectionResistanceMultiplier = 0.1 -- Reduce infection chance by 90%

	-- Boost food and pain tolerance
	local Boost = math.Clamp((target.FoodBoost or 0) - CurTime(), 0, 1000)
	Boost = Boost + 120
	target.FoodBoost = CurTime() + Boost
	if net and net.Start and IsValid(target) and target:IsPlayer() and not target:IsBot() then
		net.Start("HMCD_FoodBoost")
		net.WriteInt(Boost, 16)
		net.Send(target)
	end
	local Boost2 = math.Clamp((target.PainBoost or 0) - CurTime(), 0, 1000)
	Boost2 = Boost2 + 120
	target.PainBoost = CurTime() + Boost2
	if net and net.Start and IsValid(target) and target:IsPlayer() and not target:IsBot() then
		net.Start("HMCD_PainBoost")
		net.WriteInt(Boost2, 16)
		net.Send(target)
	end

	-- Restore health significantly
	target:SetHealth(math.Clamp(target:Health() + 40, 0, target:GetMaxHealth()))
	target:RemoveAllDecals()

	-- Send pain update if available
	if net and net.Start and IsValid(target) and target:IsPlayer() and not target:IsBot() then
		net.Start('RADS_PainUpdate')
		net.WriteFloat(target.pain or 0)
		net.Send(target)
	end

	-- Enhanced feedback messages
	local additionalEffects = {}
	if internalBleedingStopped then
		table.insert(additionalEffects, "internal bleeding treated")
	end
	table.insert(additionalEffects, "infection resistance applied")
	table.insert(additionalEffects, "extended pain relief")

	local effectsText = ""
	if #additionalEffects > 0 then
		effectsText = " (" .. table.concat(additionalEffects, ", ") .. ")"
	end



	self:Remove()
end

function SWEP:Deploy()
	self:SetNextPrimaryFire(CurTime() + 1)
	self.DownAmt = 20
	self:EmitSound("player/weapon_draw_0" .. math.random(1, 5) .. ".wav", 70, math.random(95, 110))
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

		pos = pos - ang:Up() * (self.DownAmt + 8) + ang:Forward() * 25 + ang:Right() * 12
		ang:RotateAroundAxis(ang:Forward(), -90)
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
			self.DatWorldModel = ClientsideModel("models/w_models/weapons/w_eq_medkit.mdl")
			self.DatWorldModel:SetPos(self:GetPos())
			self.DatWorldModel:SetParent(self)
			self.DatWorldModel:SetNoDraw(true)
		end
	end
end