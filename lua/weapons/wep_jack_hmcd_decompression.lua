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
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_decompression")
	SWEP.BounceWeaponIcon = false
end

SWEP.PrintName = "Decompression Needle"
SWEP.Instructions = "A decompression needle is a medical device used to relieve pressure from a tension pneumothorax by puncturing the chest wall and allowing trapped air to escape. Temporarily stops oxygen loss from lung failure.\n\nLMB to use (self or others/ragdolls)"
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
SWEP.ENT = "ent_jack_hmcd_decompression"
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

	-- Death check - cannot use on dead players
	if not target:Alive() then
		ply:PrintMessage(HUD_PRINTCENTER, "Cannot use decompression needle on dead patient.")
		self:Remove()
		return
	end

	-- Check if player has lung damage that would cause oxygen loss
	local leftLungHealth = (target.Organs and target.Organs['left_lung']) or 5
	local rightLungHealth = (target.Organs and target.Organs['right_lung']) or 5
	local damagedLungs = 0
	if leftLungHealth <= 0 then damagedLungs = damagedLungs + 1 end
	if rightLungHealth <= 0 then damagedLungs = damagedLungs + 1 end

	-- Only effective if both lungs are damaged (pneumothorax - causing oxygen loss)
	if damagedLungs < 2 then
		if target == ply then
		else
		end
		-- Don't remove the weapon since no pneumothorax was detected
		return
	end

	-- Check if decompression is already active
	if target.decompressionActive then
		if target == ply then
		else
		end
		self:Remove()
		return
	end

	-- Apply decompression effect
	target.decompressionActive = true
	target.decompressionEndTime = CurTime() + math.random(180, 300) -- 3-5 minutes

	-- Stabilize oxygen at current level (prevent further loss)
	if not target.o2 then target.o2 = 100 end
	target.decompressionOxygenLevel = target.o2

	-- Create timer to end decompression effect
	timer.Create("DecompressionNeedle_" .. target:EntIndex(), target.decompressionEndTime - CurTime(), 1, function()
		if IsValid(target) then
			target.decompressionActive = false
			target.decompressionEndTime = nil
			target.decompressionOxygenLevel = nil
			if target:Alive() then
			end
		end
	end)

	if target == ply then
	else
		ply:PrintMessage(HUD_PRINTCENTER, "Applied decompression needle to " .. target:Nick() .. ".")
		target:PrintMessage(HUD_PRINTCENTER, ply:Nick() .. " applied a decompression needle to relieve chest pressure.")
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