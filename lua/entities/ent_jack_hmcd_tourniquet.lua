if SERVER then
	AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "ent_jack_hmcd_loot_base"
ENT.PrintName = "Tourniquet"
ENT.SWEP = "wep_jack_hmcd_tourniquet"
ENT.ImpactSound = "physics/plastic/plastic_box_impact_hard1.wav"

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/tourniquet/tourniquet.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(50)
			phys:Wake()
		end
	end
end

if SERVER then
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
else
	--
end