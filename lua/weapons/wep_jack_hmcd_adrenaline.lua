if SERVER then
	AddCSLuaFile()
elseif CLIENT then
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 65
	SWEP.Slot = 5
	SWEP.SlotPos = 2
	killicon.AddFont("wep_jack_hmcd_adrenaline", "HL2MPTypeDeath", "5", Color(0, 0, 255, 255))
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
SWEP.ViewModel = "models/weapons/w_models/w_jyringe_jroj.mdl"
SWEP.WorldModel = "models/weapons/w_models/w_jyringe_jroj.mdl"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_adrenaline")
	SWEP.BounceWeaponIcon = false
end

SWEP.PrintName = "Epinephrine Autoinjector"
SWEP.Instructions = "An epinephrine autoinjector. Maximizes adrenaline levels for enhanced performance.\n\nLMB to inject (self or others/ragdolls)"
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
SWEP.ENT = "ent_jack_hmcd_adrenaline"
SWEP.HomicideSWEP = true
function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:SetupDataTables()
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

	sound.Play("snd_jack_hmcd_needleprick.wav", target:GetShootPos() + VectorRand(), 70, math.random(95, 105))
	ply:ViewPunch(Angle(-5, math.Rand(-2,2), 0))

	-- Initialize adrenaline system if needed
	if not target.adrenaline then target.adrenaline = 0 end
	if not target.adrenalineActive then target.adrenalineActive = false end
	if not target.adrenalineEndTime then target.adrenalineEndTime = 0 end
	if not target.adrenalineCooldownEnd then target.adrenalineCooldownEnd = 0 end

	-- Max out adrenaline using the existing system
	target.adrenaline = 100
	target.adrenalineActive = true
	target.adrenalineEndTime = CurTime() + 60 -- 1 minute duration
	target.adrenalineCooldownEnd = target.adrenalineEndTime + 120 -- 2 minute cooldown

	-- Apply immediate benefits
	if target.pain then
		target.pain = math.max(0, target.pain - 200) -- Immediate pain reduction
	end

	-- Boost pulse significantly
	if target.pulse then
		target.pulse = math.min(180, target.pulse + 60)
	end

	-- Restore stamina
	local maxStamina = target.MaxStamina or 100
	target.stamina = maxStamina

	-- Send network update
	if net and net.Start then
		net.Start('RADS_AdrenalineUpdate')
		net.WriteFloat(target.adrenaline)
		net.WriteBool(target.adrenalineActive)
		net.WriteFloat(60) -- duration
		net.WriteFloat(120) -- cooldown
		net.Send(target)
	end

	if target == ply then
		ply:PrintMessage(HUD_PRINTCENTER, "Injected Adrenaline.")
	else
		ply:PrintMessage(HUD_PRINTCENTER, "Injected adrenaline into " .. target:Nick() .. ".")
		target:PrintMessage(HUD_PRINTCENTER, ply:Nick() .. " pinched something into your body.")
	end

	self:Remove()
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