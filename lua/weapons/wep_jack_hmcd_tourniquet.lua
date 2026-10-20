if SERVER then
	AddCSLuaFile()
elseif CLIENT then
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 55
	SWEP.Slot = 3
	SWEP.SlotPos = 3
	killicon.AddFont("wep_jack_hmcd_tourniquet", "HL2MPTypeDeath", "5", Color(255, 0, 0, 255))
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
SWEP.ViewModel = "models/tourniquet/tourniquet.mdl"
SWEP.WorldModel = "models/tourniquet/tourniquet.mdl"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_tourniquet")
	SWEP.BounceWeaponIcon = false
end

SWEP.PrintName = "Tourniquet"
SWEP.Instructions = "A medical tourniquet for stopping arterial bleeding. Stops one arterial bleeding instance.\n\nLMB to apply tourniquet (self or others/ragdolls)"
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
SWEP.ENT = "ent_jack_hmcd_tourniquet"
SWEP.DownAmt = 0
SWEP.HomicideSWEP = true
SWEP.CarryWeight = 400

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

	-- Death check
	if not target:Alive() then
		if target == ply then
			ply:PrintMessage(HUD_PRINTCENTER, "You are dead.")
		else
			ply:PrintMessage(HUD_PRINTCENTER, target:Nick() .. " is dead.")
		end
		return
	end

	-- Initialize organs if needed
	if not target.Organs then target.Organs = {} end

	-- List of all arteries to check (matching damage.lua)
	local arteries = {
		"artery",
		"radial_artery_l", "radial_artery_r",
		"femoral_artery_l", "femoral_artery_r",
		"popliteal_artery_l", "popliteal_artery_r"
	}

	-- Find first artery at 0 health (bleeding)
	local bleedingArtery = nil
	for _, artery in ipairs(arteries) do
		if target.Organs[artery] and target.Organs[artery] <= 0 then
			bleedingArtery = artery
			break
		end
	end

	-- Check if there's arterial bleeding to stop
	if not bleedingArtery then
		if target == ply then
			ply:PrintMessage(HUD_PRINTCENTER, "You have no arterial bleeding.")
		else
			ply:PrintMessage(HUD_PRINTCENTER, target:Nick() .. " has no arterial bleeding.")
		end
		return
	end

	-- Apply tourniquet
	sound.Play("snd_jack_hmcd_bandage.wav", target:GetShootPos(), 60, math.random(90, 100))
	ply:ViewPunch(Angle(-10, 0, 0))

	-- Stop arterial bleeding by setting artery health to 1
	target.Organs[bleedingArtery] = 1

	-- Remove blood spurt timer for this artery if it exists
	local timerName = bleedingArtery .. "_burst_" .. target:EntIndex()
	if timer.Exists(timerName) then
		timer.Remove(timerName)
	end

	-- Display minimal HUD messages
	if target == ply then
		ply:PrintMessage(HUD_PRINTCENTER, "Arterial bleeding stopped.")
	else
		ply:PrintMessage(HUD_PRINTCENTER, "Stopped " .. target:Nick() .. "'s arterial bleeding.")
		target:PrintMessage(HUD_PRINTCENTER, ply:Nick() .. " stopped your arterial bleeding.")
	end

	-- Remove tourniquet after use (single-use)
	self:Remove()
end

function SWEP:Deploy()
	self:SetNextPrimaryFire(CurTime() + 1)
	self.DownAmt = 20
	self:EmitSound("player/weapon_draw_0" .. math.random(1, 5) .. ".wav", 70, self.HandlingPitch)
	return true
end

function SWEP:SecondaryAttack()
	-- Secondary attack is the same as primary attack
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

		pos = pos - ang:Up() * (self.DownAmt + 9) + ang:Forward() * 30 + ang:Right() * 8
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
			self.DatWorldModel = ClientsideModel("models/tourniquet/tourniquet.mdl")
			self.DatWorldModel:SetPos(self:GetPos())
			self.DatWorldModel:SetParent(self)
			self.DatWorldModel:SetNoDraw(true)
		end
	end
end