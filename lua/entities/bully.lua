AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "dddd"
ENT.Category = 'test'
ENT.Author = "Your Name"
ENT.Spawnable = false
ENT.AdminSpawnable = false

function ENT:Initialize()
    local ragdoll = self:GetOwnerRagdoll()
    if IsValid(ragdoll) then
        local attachment = ragdoll:GetAttachment(ragdoll:LookupAttachment("eyes"))
        if attachment then
            self:SetPos(attachment.Pos)
            self:SetAngles(attachment.Ang)
        end
    end
end

function ENT:GetOwnerRagdoll()
    return self:GetNWEntity("player_ragdoll")
end
