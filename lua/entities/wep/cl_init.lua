include("shared.lua")

-- Magazine models for weapons that need them
local MagazineModels = {
    ["wep_daun_hmcd_draco"] = "models/weapons/w_draco_mag.mdl"
}

function ENT:Draw()
    self:DrawModel()
    
    -- Get the weapon class from the owner's networked variable
    local owner = self:GetOwner()
    local weaponClass = ""
    
    if IsValid(owner) and owner:IsPlayer() then
        weaponClass = owner:GetNWString("curweapon", "")
    elseif IsValid(owner) and owner:IsRagdoll() then
        -- Try to find the player who owns this ragdoll
        for _, ply in pairs(player.GetAll()) do
            if ply:GetNWEntity("player_ragdoll") == owner then
                weaponClass = ply:GetNWString("curweapon", "")
                break
            end
        end
    else
        -- Fallback to the entity's curweapon if networked variable fails
        weaponClass = self.curweapon or ""
    end
    
    -- Track current weapon class for cleanup
    if self.LastWeaponClass ~= weaponClass then
        if self.LastWeaponClass == "wep_daun_hmcd_draco" and IsValid(self.WorldMagModel) then
            -- Clean up magazine when switching away from Draco
            self.WorldMagModel:Remove()
            self.WorldMagModel = nil
        end
        self.LastWeaponClass = weaponClass
    end
    
    -- Check if this is a Draco weapon
    if weaponClass == "wep_daun_hmcd_draco" then
        -- Create magazine model if it doesn't exist
        if not IsValid(self.WorldMagModel) then
            local modelPath = "models/weapons/w_draco_mag.mdl"
            
            if file.Exists(modelPath, "GAME") then
                self.WorldMagModel = ClientsideModel(modelPath)
                if IsValid(self.WorldMagModel) then
                    self.WorldMagModel:SetNoDraw(true)
                end
            end
        end
        
        -- Draw magazine model using exact positioning from Draco entity
        if IsValid(self.WorldMagModel) then
            local boneIndex = self:LookupBone("W_MAGAZINE")
            if boneIndex and boneIndex >= 0 then
                local pos, ang = self:GetBonePosition(boneIndex)
                if pos and ang then
                    -- Use exact positioning from Draco weapon file
                    ang:RotateAroundAxis(ang:Right(), 360)
                    ang:RotateAroundAxis(ang:Forward(), 0)
                    ang:RotateAroundAxis(ang:Up(), 267)
                    pos = pos + ang:Up() * 0.89
                    pos = pos + ang:Forward() * -6.45
                    pos = pos + ang:Right() * 0.17
                    
                    self.WorldMagModel:SetPos(pos)
                    self.WorldMagModel:SetAngles(ang)
                    self.WorldMagModel:SetNoDraw(false)
                    self.WorldMagModel:DrawModel()
                end
            end
        end
    end
end

function ENT:OnRemove()
    if IsValid(self.WorldMagModel) then
        self.WorldMagModel:Remove()
    end
end

-- Console command to test magazine functionality
if CLIENT then
    concommand.Add("test_draco_magazine", function()
        if GetConVar("developer"):GetInt() > 0 then
    print("[TEST] Testing Draco magazine functionality...")
end
        
        -- Check if the magazine model exists
        local modelPath = "models/weapons/w_draco_mag.mdl"
        if file.Exists(modelPath, "GAME") then
            if GetConVar("developer"):GetInt() > 0 then
    print("[TEST] Magazine model exists: " .. modelPath)
end
        else
            if GetConVar("developer"):GetInt() > 0 then
    print("[TEST] Magazine model NOT found: " .. modelPath)
end
        end
        
        if GetConVar("developer"):GetInt() > 0 then
    print("[TEST] Draco magazine system is active")
end
    end)
end