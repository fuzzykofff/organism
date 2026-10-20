if SERVER then
	AddCSLuaFile()
elseif CLIENT then
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 55
	SWEP.Slot = 3
	SWEP.SlotPos = 4
	killicon.AddFont("wep_jack_hmcd_painpills", "HL2MPTypeDeath", "5", Color(0, 0, 255, 255))
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
SWEP.ViewModel = "models/w_models/weapons/w_eq_painpills.mdl"
SWEP.WorldModel = "models/w_models/weapons/w_eq_painpills.mdl"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_painpills")
	SWEP.BounceWeaponIcon = false
end

SWEP.PrintName = "Pain Killers"
SWEP.Instructions = "Pain killers, Reduces pain. WARNING: Overuse will result in possible casulties. Overdose at 300%\n\nLMB to consume (self or others/ragdolls)"
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
SWEP.ENT = "ent_jack_hmcd_painpills"
SWEP.DownAmt = 0
SWEP.HomicideSWEP = true
SWEP.CarryWeight = 200
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

	-- Initialize painkiller tracking
	if not target.painkillerHistory then target.painkillerHistory = {} end
	if not target.pain then target.pain = 0 end

	-- Allow painkillers to be used preventively (removed pain requirement check)

	-- Clean old entries (older than 2 minutes)
	local currentTime = CurTime()
	for i = #target.painkillerHistory, 1, -1 do
		if currentTime - target.painkillerHistory[i] > 120 then
			table.remove(target.painkillerHistory, i)
		end
	end

	-- Add current consumption
	table.insert(target.painkillerHistory, currentTime)

	-- Check for overdose effects
	if #target.painkillerHistory >= 3 then
		-- 3+ pills: oxygen loss (no automatic death)
		target.painkillerOxygenOverdose = true
		target.oxygenOverdoseStartTime = currentTime
		target.oxygenLossRate = 10 -- Lose 10 oxygen per second
		
		-- Start oxygen depletion timer
		timer.Create("PainkillerOxygenOverdose_" .. target:SteamID(), 1, 0, function()
			if not IsValid(target) or not target.painkillerOxygenOverdose then
				timer.Remove("PainkillerOxygenOverdose_" .. target:SteamID())
				return
			end
			
			if not target.o2 then target.o2 = 100 end
			target.o2 = math.max(0, target.o2 - target.oxygenLossRate)
		end)
		
		-- Set timer to clear oxygen overdose flag after 2 minutes
		timer.Simple(120, function()
			if IsValid(target) then
				target.painkillerOxygenOverdose = nil
				timer.Remove("PainkillerOxygenOverdose_" .. target:SteamID())
			end
		end)
		
	elseif #target.painkillerHistory >= 2 then
		-- 2 pills: stamina loss
		target.painkillerStaminaOverdose = true
		target.staminaOverdoseStartTime = currentTime
		target.staminaLossRate = 5 -- Lose 20 stamina per second
		
		-- Start stamina depletion timer
		timer.Create("PainkillerStaminaOverdose_" .. target:SteamID(), 1, 0, function()
			if not IsValid(target) or not target.painkillerStaminaOverdose then
				timer.Remove("PainkillerStaminaOverdose_" .. target:SteamID())
				return
			end
			
			if not target.stamina then target.stamina = 100 end
			target.stamina = math.max(0, target.stamina - target.staminaLossRate)
			
			-- Send stamina update
			if net and net.Start and IsValid(target) and target:IsPlayer() and not target:IsBot() then
				net.Start('RADS_StaminaUpdate')
				net.WriteFloat(target.stamina)
				net.Send(target)
			end
		end)
		
		-- Set timer to clear stamina overdose flag after 2 minutes
		timer.Simple(120, function()
			if IsValid(target) then
				target.painkillerStaminaOverdose = nil
				timer.Remove("PainkillerStaminaOverdose_" .. target:SteamID())
			end
		end)
	else
		-- Normal painkiller effect
		if target.pain > 0 then
			target.pain = math.max(0, target.pain - 50) -- Immediate pain reduction
		end
		
		-- Set up pain reduction multiplier for 3 minutes
		target.painKillerEndTime = CurTime() + 180
		target.painKillerMultiplier = 0.5 -- Reduce pain gain by 50%
		
		if target == ply then
		else
			ply:PrintMessage(HUD_PRINTCENTER, "Gave painkillers to " .. target:Nick() .. ".")
			target:PrintMessage(HUD_PRINTCENTER, ply:Nick() .. " gave you painkillers.")
		end
	end

	sound.Play("snd_jack_hmcd_pillsuse.wav", target:GetShootPos() + VectorRand(), 70, math.random(95, 105))
	ply:ViewPunch(Angle(-2, math.Rand(-1,1), 0))

	-- Send pain update to client
	if net and net.Start and IsValid(target) and target:IsPlayer() and not target:IsBot() then
		net.Start('RADS_PainUpdate')
		net.WriteFloat(target.pain or 0)
		net.Send(target)
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
	--
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

-- Clean up painkiller timers on player death
if SERVER then
	hook.Add("PlayerDeath", "CleanupPainkillerTimers", function(victim)
		if IsValid(victim) and victim:IsPlayer() then
			-- Clean up painkiller timers
			timer.Remove("PainkillerOxygenOverdose_" .. victim:SteamID())
			timer.Remove("PainkillerStaminaOverdose_" .. victim:SteamID())
			
			-- Clear painkiller effects
			victim.painkillerOxygenOverdose = nil
			victim.painkillerStaminaOverdose = nil
			victim.painKillerEndTime = nil
			victim.painKillerMultiplier = nil
			victim.painkillerHistory = nil
		end
	end)
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

		pos = pos - ang:Up() * (self.DownAmt + 11) + ang:Forward() * 25 + ang:Right() * 7
		ang:RotateAroundAxis(ang:Up(), -40)
		ang:RotateAroundAxis(ang:Right(), -10)
		ang:RotateAroundAxis(ang:Forward(), -10)
		return pos, ang
	end

	function SWEP:DrawWorldModel()
		local Pos, Ang = self:GetOwner():GetBonePosition(self:GetOwner():LookupBone("ValveBiped.Bip01_R_Hand"))
		if self.DatWorldModel then
			if Pos and Ang and IsValid(self:GetOwner()) then
				self.DatWorldModel:SetRenderOrigin(Pos + Ang:Forward() * 3.5 + Ang:Right() * 2 - Ang:Up() * -1)
				Ang:RotateAroundAxis(Ang:Right(), 180)
				--Ang:RotateAroundAxis(Ang:Right(),90)
				self.DatWorldModel:SetRenderAngles(Ang)
				self.DatWorldModel:DrawModel()
			end
		else
			self.DatWorldModel = ClientsideModel("models/w_models/weapons/w_eq_painpills.mdl")
			self.DatWorldModel:SetPos(self:GetPos())
			self.DatWorldModel:SetParent(self)
			self.DatWorldModel:SetNoDraw(true)
			--self.DatWorldModel:SetModelScale(1,0)
		end
	end
end