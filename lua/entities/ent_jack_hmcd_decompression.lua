AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "ent_jack_hmcd_loot_base"
ENT.PrintName = "Decompression Needle"
ENT.SWEP = "wep_jack_hmcd_decompression"
ENT.ImpactSound = "snd_jack_hmcd_pillsbounce.wav"
if SERVER then
	function ENT:Initialize()
		self:SetModel("models/weapons/w_models/w_jyringe_jroj.mdl") -- Match SWEP world model
		self:PhysicsInitBox(Vector(-2,-2,-4), Vector(2,2,4)) -- Small box physics since model lacks physics
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(false)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON) -- Standard for pickupable items
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:SetMass(5)
			phys:SetMaterial("plastic")
		end

		self:SetUseType(SIMPLE_USE)
	end

	function ENT:Use(activator, caller)
		if IsValid(activator) and activator:IsPlayer() then
			self:PickUp(activator)
		end
	end

	function ENT:PickUp(ply)
		local SWEP = self.SWEP
		if not ply:HasWeapon(SWEP) then
			self:EmitSound(self.ImpactSound, 60, 100)
			ply:Give(SWEP)
			ply:GetWeapon(self.SWEP).HmcdSpawned = self.HmcdSpawned
			-- Removed Poisoned and Poisoner transfer
			self:Remove()
			ply:SelectWeapon(SWEP)
		else
			ply:PickupObject(self)
		end
	end
elseif CLIENT then
	function ENT:Initialize()
		--
	end

	function ENT:Draw()
		if self.DatWorldModel then
			self.DatWorldModel:SetRenderOrigin(self:GetPos())
			self.DatWorldModel:SetRenderAngles(Ang)
			self.DatWorldModel:DrawModel()
		else
			self.DatWorldModel = ClientsideModel("models/weapons/w_models/w_jyringe_jroj.mdl")
			self.DatWorldModel:SetPos(self:GetPos())
			self.DatWorldModel:SetParent(self)
			self.DatWorldModel:SetNoDraw(true)
		end
		
		-- Debug wireframe for PhysicsInitBox when developer 1 is enabled
		if GetConVar("developer"):GetInt() >= 1 then
			local mins = Vector(-2,-2,-4)
			local maxs = Vector(2,2,4)
			local pos = self:GetPos()
			local ang = self:GetAngles()
			
			-- Transform box corners to world space
			local corners = {}
			for i = 0, 7 do
				local corner = Vector(
					bit.band(i, 1) == 1 and maxs.x or mins.x,
					bit.band(i, 2) == 2 and maxs.y or mins.y,
					bit.band(i, 4) == 4 and maxs.z or mins.z
				)
				corner:Rotate(ang)
				corners[i + 1] = pos + corner
			end
			
			-- Draw wireframe box
			render.SetColorMaterial()
			render.DrawWireframeBox(pos, ang, mins, maxs, Color(0, 255, 0, 255), true)
		end
		-- self:DrawModel()
	end
end