AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "ent_jack_hmcd_loot_base"
ENT.PrintName = "Handcuffs"
ENT.SWEP = "wep_jack_hmcd_handcuffs"
ENT.ImpactSound = "physics/metal/metal_solid_impact_hard5.wav"
if SERVER then
	function ENT:Initialize()
		self:SetModel("models/weapons/spy/w_handcuffs.mdl")
		self:SetModelScale(1.0, 0)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(true)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(15)
			phys:Wake()
			phys:EnableMotion(true)
		end
	end

	function ENT:PickUp(ply)
		local SWEP = self.SWEP
		if not ply:HasWeapon(self.SWEP) then
			self:EmitSound(self.ImpactSound, 60, 110)
			ply:Give(self.SWEP)
			ply:GetWeapon(self.SWEP).HmcdSpawned = self.HmcdSpawned
			self:Remove()
			ply:SelectWeapon(SWEP)
		else
			ply:PickupObject(self)
		end
	end
elseif CLIENT then
	--
end