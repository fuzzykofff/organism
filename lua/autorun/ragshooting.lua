include( "autorun/weaponragshooting.lua" )
AddCSLuaFile( "autorun/weaponragshooting.lua" )
include( "autorun/mdhomicidesweps_integration.lua" )
AddCSLuaFile( "autorun/mdhomicidesweps_integration.lua" )
-- setmetatable(ShootWait, { __index = function() return 0.1 end })
cc = Vector

-- Custom muzzle flash effects mapping (from mdhomicidesweps)
WeaponMuzzleFlash = {
	-- Pistols
	["weapon_pwb_cz75"] = "pcf_jack_mf_spistol",
	["weapon_pwb_desert_eagle"] = "pcf_jack_mf_spistol",
	["weapon_pwb_fnp45"] = "pcf_jack_mf_spistol",
	["weapon_pwb_glock17"] = "pcf_jack_mf_spistol",
	["weapon_pwb_m9"] = "pcf_jack_mf_spistol",
	["weapon_pwb_p99"] = "pcf_jack_mf_spistol",
	["qwb_glock18"] = "pcf_jack_mf_spistol",
	["qwb_usp"] = "pcf_jack_mf_spistol",
	["weapon_sib_usp"] = "pcf_jack_mf_spistol",
	["weapon_sib_glock"] = "pcf_jack_mf_spistol",
	["weapon_sib_beretta"] = "pcf_jack_mf_spistol",
	["weapon_sib_deagle"] = "pcf_jack_mf_spistol",
	
	-- SMGs
	["weapon_pwb_mp5"] = "pcf_jack_mf_mrifle1",
	["weapon_pwb_uzi"] = "pcf_jack_mf_mrifle1",
	["weapon_pwb_tmp"] = "pcf_jack_mf_mrifle1",
	["weapon_pwb_p90"] = "pcf_jack_mf_mrifle1",
	["weapon_pwb_mp7"] = "pcf_jack_mf_mrifle1",
	["qwb_ump45"] = "pcf_jack_mf_mrifle1",
	["weapon_pwb2_vectorsmg"] = "pcf_jack_mf_mrifle1",
	
	-- Rifles
	["weapon_pwb_akm"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_aks74u"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_l85a1"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_hk416"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_hk417"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_tar21"] = "pcf_jack_mf_mrifle2",
	["weapon_sib_m14"] = "pcf_jack_mf_mrifle2",
	
	-- LMGs
	["weapon_pwb_rpk"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_hk23e"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_m249"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_pkm"] = "pcf_jack_mf_mrifle2",
	["weapon_pwb_m134"] = "pcf_jack_mf_mrifle2",
	["weapon_sib_m249"] = "pcf_jack_mf_mrifle2",
	
	-- Sniper Rifles
	["weapon_pwb_l96a1"] = "pcf_jack_mf_mrifle1",
	["weapon_pwb_m200"] = "pcf_jack_mf_mrifle1",
	["weapon_pwb_m98b"] = "pcf_jack_mf_mrifle1",
	["qwb_awp"] = "pcf_jack_mf_mrifle1",
	
	-- Shotguns
	["weapon_pwb_m590a1"] = "pcf_jack_mf_mshotgun",
	["weapon_pwb_remington_870"] = "pcf_jack_mf_mshotgun",
	["weapon_pwb_saiga_12"] = "pcf_jack_mf_mshotgun",
	["weapon_pwb_spas_12"] = "pcf_jack_mf_mshotgun",
	["weapon_pwb_protecta"] = "pcf_jack_mf_mshotgun",
	["weapon_pwb_xm1014"] = "pcf_jack_mf_mshotgun",
	["qwb_m3super"] = "pcf_jack_mf_mshotgun",
	
	-- Grenade Launchers
	["weapon_pwb_m320"] = "pcf_jack_mf_mrifle1",
	
	-- MDHomicide Weapons
	-- Pistols
	["wep_mann_hmcd_glock"] = "pcf_jack_mf_spistol",
	["wep_jack_mded_pistol"] = "pcf_jack_mf_spistol",
	["wep_mann_hmcd_deagle"] = "pcf_jack_mf_spistol",
	["wep_mann_hmcd_sw500"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_p220"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_beretta"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_sw659"] = "pcf_jack_mf_spistol",
	["wep_jack_mded_fakepistol"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_pm"] = "pcf_jack_mf_spistol",
	["wep_jack_mded_suppressed_p22"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_usp"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_p99"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_fnp"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_cz"] = "pcf_jack_mf_spistol",
	["wep_jack_mded_revolver"] = "pcf_jack_mf_spistol",
	["wep_mann_hmcd_mateba"] = "pcf_jack_mf_spistol",
	["wep_mann_hmcd_pl"] = "pcf_jack_mf_spistol",
	["wep_mann_hmcd_pl_suppressed"] = "pcf_jack_mf_spistol",
	["wep_mann_hmcd_revolver_suppressed"] = "pcf_jack_mf_spistol",
	["wep_mann_hmcd_cobra"] = "pcf_jack_mf_spistol",
	["wep_daun_hmcd_borz"] = "pcf_jack_mf_spistol",
	
	-- SMGs
	["wep_daun_hmcd_mp5"] = "pcf_jack_mf_mrifle1",
	["wep_daun_hmcd_ump"] = "pcf_jack_mf_mrifle1",
	["wep_daun_hmcd_mp7"] = "pcf_jack_mf_mrifle1",
	["wep_daun_hmcd_asval"] = "pcf_jack_mf_mrifle1",
	["wep_mann_hmcd_samopal"] = "pcf_jack_mf_mrifle1",
	
	-- Rifles/Assault Rifles
	["wep_mann_hmcd_akm"] = "pcf_jack_mf_mrifle2",
	["wep_daun_hmcd_draco"] = "pcf_jack_mf_mrifle2",
	["wep_jack_mded_rifle"] = "pcf_jack_mf_mrifle2",
	["wep_jack_mded_assaultrifle"] = "pcf_jack_mf_mrifle2",
	["wep_daun_hmcd_stg"] = "pcf_jack_mf_mrifle2",
	["wep_mann_hmcd_m4a1"] = "pcf_jack_mf_mrifle2",
	["wep_mann_hmcd_ak74u"] = "pcf_jack_mf_mrifle2",
	["wep_daun_hmcd_battleworm"] = "pcf_jack_mf_mrifle2",
	["wep_jack_mded_suppressedrifle"] = "pcf_jack_mf_mrifle2",
	["wep_mann_hmcd_ar2"] = "pcf_jack_mf_mrifle2",
	["wep_mann_hmcd_rifle_noscope"] = "pcf_jack_mf_mrifle2",
	
	-- Sniper Rifles
	["wep_mann_hmcd_mosin"] = "pcf_jack_mf_mrifle1",
	["wep_daun_hmcd_ptrd"] = "pcf_jack_mf_mrifle1",
	["wep_daun_hmcd_sr25"] = "pcf_jack_mf_mrifle1",
	
	-- Shotguns
	["wep_jack_mded_shotgun"] = "pcf_jack_mf_mshotgun",
	["wep_mann_hmcd_spas"] = "pcf_jack_mf_mshotgun",
	["wep_mann_hmcd_sg"] = "pcf_jack_mf_mshotgun",
	["wep_mann_hmcd_db"] = "pcf_jack_mf_mshotgun",
	["wep_mann_hmcd_izhdb"] = "pcf_jack_mf_mshotgun",
	["wep_mann_hmcd_shorty"] = "pcf_jack_mf_mshotgun",
	
	-- Special/Heavy Weapons
	["wep_mann_hmcd_rpg"] = "pcf_jack_mf_mrifle1",
	["wep_mann_hmcd_pnevmat"] = "pcf_jack_mf_mrifle1",
}


bullets = {
	["weapon_pwb_m590a1"] = 9,
	["weapon_pwb_remington_870"] = 9,
	["weapon_pwb_saiga_12"] = 6,
	["weapon_pwb_spas_12"] = 6,
	["weapon_pwb_protecta"] = 8,
	["qwb_m3super"] = 2,
}
cir = {
	["weapon_pwb_m590a1"] = 0.02,
	["weapon_pwb_mp5"] = 0.1,
	["weapon_pwb_akm"] = 0.1,
	["weapon_pwb_cz75"] = 0.1,
	["weapon_pwb_desert_eagle"] = 0.1,
	["weapon_pwb_rpk"] = 0.1,
	["weapon_pwb_aks74u"] = 0.1,
	["weapon_pwb_fnp45"] = 0.1,
	["weapon_pwb_hk416"] = 0.1,
	["weapon_pwb_l96a1"] = 0.1,
	["qwb_m3super"] = 0.1,
	["weapon_pwb_m134"] = 0.4,
}

Vectors = {
	["weapon_pwb_aks74u"] = Vector(14,-1,2),
	["qwb_glock18"] = cc(3,-1,1),
	["qwb_m3super"] = cc(12,-1,4),
	["qwb_usp"] = cc(5,0,4),
	["weapon_pwb2_vectorsmg"] = cc(0,0,0),
	["qwb_ump45"] = cc(12,-1,4),
	["weapon_pwb_akm"] =Vector(14,-1,2),
	["weapon_pwb_l85a1"]= Vector(12,-1,2),
	["weapon_pwb_cz75"] = Vector(14,0,4),
	["weapon_sib_usp"] = cc(1,-1,2),
	["weapon_pwb_desert_eagle"] = Vector(12,0,2),
	["weapon_pwb_fnp45"] = Vector(14,0,4),
	["weapon_pwb_glock17"] = Vector(14,0,4),
	["weapon_pwb_hk23e"] = Vector(3,-1,0),
	["weapon_pwb_mp5"] = cc(14,-1,2),
	["weapon_pwb_uzi"] = cc(14,0,4),
	["weapon_pwb_xm1014"] = cc(12,-1,4),
	["weapon_pwb_hk417"] = Vector(12,-1,4),
	["weapon_pwb_spas_12"] = cc(13,-1,2),
	["weapon_pwb_m9"]= cc(14,0,4),
	["weapon_pwb_hk416"] = Vector(12,-1,4),
	["weapon_pwb_rpk"] = cc(14,0,4),
	["weapon_pwb_l96a1"] = Vector(12,-1,4),
	["weapon_pwb_m134"] = Vector(3,-1,0),
	["weapon_pwb_remington_870"] = cc(12,-1,4),
	["weapon_pwb_m200"] = cc(12,-1,4),
	["weapon_pwb_m249"] = cc(12,-1,4),
	["weapon_pwb_saiga_12"] = cc(12,-1,4),
	["weapon_pwb_m320"] = cc(12,-1,4),
	["weapon_pwb_p99"] = cc(14,0,4),
	["weapon_pwb_tmp"] = cc(12,-1,4),
	["weapon_pwb_p90"] = cc(14,-1,2),
	["weapon_pwb_tar21"] = cc(12,-1,4),
	["weapon_pwb_mp7"] = cc(14,-1,2),
	["weapon_pwb_pkm"] = cc(14,-1,2),
	["weapon_pwb_protecta"] = cc(12,-1,4),
	["weapon_pwb_m590a1"] = cc(12,-1,4),
	["weapon_pwb_m98b"] = cc(12,-1,4),
	["weapon_sib_glock"] = cc(3,-1,1),
	["weapon_sib_m249"] = cc(12,-1,4),
	["weapon_sib_m14"] = cc(0,-2,2),
	["qwb_awp"] = cc(12,-1,4),
	["weapon_sib_beretta"] = cc(1,-1,2),
	["weapon_sib_deagle"] = cc(1,-2,1),
}

Vectors2 = {
	["weapon_pwb_saiga_12"] = cc(12,-2,-1),
	["qwb_m3super"] = cc(12,-2,-1),
	["weapon_pwb_m590a1"] = cc(12,-2,-1),
	["weapon_pwb_aks74u"] = cc(12,-3,-2),
	["weapon_pwb_xm1014"] = cc(12,-2,-1),
	["weapon_pwb_spas_12"] = cc(15,-4,-3),
	["weapon_pwb_p90"] = cc(3,-2,-4),
	["weapon_pwb_protecta"] = cc(12,-2,-1),
	["weapon_pwb_tmp"] = cc(7,-2,-4),
	["weapon_pwb_p99"] = cc(0,-3,-1),
	["qwb_glock18"] = cc(4,-3,-1),
	["qwb_ump45"] = cc(12,-2,-4),
	["weapon_pwb_akm"] = cc(12,-3,-2),
	["weapon_pwb_mp7"] = cc(12,-2,-4),
	["weapon_pwb2_vectorsmg"] = cc(0,0,0),
	["weapon_pwb_l85a1"]= cc(12,-2,-4),
	["weapon_pwb_m134"] = cc(12,-2,-2),
	["weapon_pwb_rpk"] = cc(12,-2,-2),
	["weapon_pwb_mp5"] = cc(12,-3,-2),
	["weapon_pwb_glock17"] = cc(4,-3,-1),
	["weapon_pwb_tar21"] = cc(7,-2,-4),
	["weapon_pwb_l96a1"] = cc(12,-2,-4),
	["weapon_pwb_pkm"] = cc(12,-2,-2),
	["weapon_pwb_hk23e"] = cc(12,-2,-2),
	["weapon_pwb_m249"] = cc(12,-2,-4),
	["weapon_pwb_hk416"] = cc(12,-2,-4),
	["weapon_pwb_m9"] = cc(0,-3,0),
	["weapon_pwb_hk417"] = cc(12,-2,-4),
	["weapon_pwb_m200"] = cc(12,-2,-4),
	["weapon_pwb_m98b"] = cc(12,-2,-4),
	["weapon_pwb_m320"] = cc(12,-2,-4),
	["weapon_pwb_remington_870"] = cc(12,-2,-1),
	["weapon_sib_glock"] = cc(0,-1,0),
	["weapon_sib_m249"] = cc(14,0,0),
	["weapon_sib_m14"] = cc(16,-4,-1),
	["qwb_awp"] = cc(7,-2,-4),
	["qwb_usp"] = cc(0,-3,-1),
	["weapon_sib_deagle"] = cc(-2,-2,1),
	["weapon_sib_usp"] = cc(-2,-2,1) 
}
function checkwepinfo(weaponName)
    -- First check our custom damage table
    if WeaponDamage and WeaponDamage[weaponName] then
        return WeaponDamage[weaponName]
    end
    
    -- Fallback to weapon table
    local weapon = weapons.Get(weaponName)
    if weapon and weapon.Damage then
        return weapon.Damage
    elseif weapon and weapon.Primary and weapon.Primary.Damage then
        return weapon.Primary.Damage
    end
    
    -- Default damage
    return 30
end
function getsound(weaponClassName)
    if not weapons.Get(weaponClassName) then
        return "weapons/pistol/pistol_fire2.wav", "weapons/pistol/pistol_fire2.wav"
    end
    local weaponTable = weapons.Get(weaponClassName)
    
    -- Get close and far sounds
    local closeSound = weaponTable.CloseFireSound or weaponTable.Primary.Sound or "weapons/pistol/pistol_fire2.wav"
    local farSound = weaponTable.FarFireSound or closeSound
    
    -- Return both sounds
    return closeSound, farSound
end

function getweaponpitch(weaponClassName)
    if not weapons.Get(weaponClassName) then
        return 100 -- Default pitch
    end
    local weaponTable = weapons.Get(weaponClassName)
    
    -- Get the ShotPitch property
    local shotPitch = weaponTable.ShotPitch
    
    -- If ShotPitch is a function (like math.random), execute it
    if type(shotPitch) == "function" then
        return shotPitch()
    elseif type(shotPitch) == "number" then
        return shotPitch
    else
        return 100 -- Default pitch if not found
    end
end
vecZero = Vector(0,0,0)
vecZero = Vector(0,0,0)
if true then
function SpawnWeapon(ply,clip1)
	if !IsValid(ply.wep) and table.HasValue(Guns,ply.curweapon) then
		local rag = ply:GetNWEntity("player_ragdoll")
		if IsValid(rag) then
			ply.FakeShooting=true
			ply.wep=ents.Create("wep")
			ply.wep:SetModel(GunsModel[ply.curweapon])
			ply.wep:SetOwner(ply)
			local vec1=rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_R_Hand" ))):GetPos()
			local vec2 = vecZero
			vec2:Set((Vectors[ply.curweapon] or Vector(0,0,0)))
			vec2:Rotate(rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_R_Hand" ))):GetAngles())
			ply.wep:SetPos(vec1+vec2)
			ply.wep:SetAngles(rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_R_Hand" ))):GetAngles()-Angle(0,0,180))
			ply.wep:SetCollisionGroup(COLLISION_GROUP_WEAPON)
			ply.wep:Spawn()
			ply:SetNWEntity("wep",ply.wep)
			
			-- Set weapon properties before CheckAmmo
			ply.wep.curweapon = ply.curweapon
			
			-- Initialize ammo values properly
			if ply.Info and ply.Info.Weapons and ply.Info.Weapons[ply.curweapon] then
				ply.wep.Clip = ply.Info.Weapons[ply.curweapon].Clip1 or 0
				ply.wep.AmmoType = ply.Info.Weapons[ply.curweapon].AmmoType or 0
			else
				-- Fallback to weapon table defaults
				local weaponTable = weapons.Get(ply.curweapon)
				if weaponTable and weaponTable.Primary then
					ply.wep.Clip = weaponTable.Primary.ClipSize or 30
					ply.wep.AmmoType = weaponTable.Primary.Ammo or "pistol"
				else
					ply.wep.Clip = 30
					ply.wep.AmmoType = "pistol"
				end
			end
			
			CheckAmmo(ply, ply.wep)
			if !IsValid(ply.WepCons) then
				local cons = constraint.Weld(ply.wep,rag,0,rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_R_Hand" )),0,true)
				if IsValid(cons) then
					ply.WepCons=cons
				end
			end

			net.Start("ebal_chellele")
			net.WriteEntity(ply)
			net.WriteString(ply.curweapon)
			net.Broadcast()
			rag.wep = ply.wep
			rag.wep:CallOnRemove("inv",remove,rag)
			ply.wep.rag = rag

			ply:SetNWString("curweapon",ply.wep.curweapon)
			if (TwoHandedOrNo[ply.curweapon]) then
				-- Two-handed weapon setup
				local wepPhys = ply.wep:GetPhysicsObject()
				if IsValid(wepPhys) then
					wepPhys:SetMass(1)
				end
				local vec1=rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_R_Hand" ))):GetPos()
				local vec22 = vecZero
				vec22:Set(Vectors2[ply.curweapon])
				vec22:Rotate(rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_R_Hand" ))):GetAngles())
				rag:GetPhysicsObjectNum( rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_L_Hand" )) ):SetPos(vec1+vec22)
				local modelhuy = ply:GetModel() == "models/knyaje pack/dibil/sso_politepeople.mdl"
				rag:GetPhysicsObjectNum( rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_L_Hand" )) ):SetAngles(ply:GetNWEntity("player_ragdoll"):GetPhysicsObjectNum( 7 ):GetAngles()-Angle(0,0,modelhuy and 90 or 180))
				if !IsValid(ply.WepCons2) then
					local cons2 = constraint.Weld(ply.wep,rag,0,rag:TranslateBoneToPhysBone(rag:LookupBone( "ValveBiped.Bip01_L_Hand" )),0,true)			--2hand constraint
					if IsValid(cons2) then
						ply.WepCons2=cons2
					end
				end
			else
				-- One-handed weapon (pistol) setup - set lighter mass to prevent excessive movement
				local wepPhys = ply.wep:GetPhysicsObject()
				if IsValid(wepPhys) then
					wepPhys:SetMass(0.5)
				end
		end
	end
end
end

function DespawnWeapon(ply)
	if not ply.Info then return end

	if not ply.Info.Weapons[ply.Info.ActiveWeapon] then return end
	-- Save current clip count to player info before despawning
	if IsValid(ply.wep) and ply.wep.Clip then
		ply.Info.Weapons[ply.Info.ActiveWeapon].Clip1 = ply.wep.Clip
	end
	ply.Info.ActiveWeapon2=ply.curweapon

		if IsValid(ply.wep) and ply:Alive() then
			ply.wep:Remove()
			ply.wep=nil
		elseif IsValid(ply.wep) and !ply:Alive() then
            ply.wep.canpickup=true
            ply.wep:SetOwner(nil)
            ply.wep.curweapon=ply.curweapon
            -- Preserve ammo data when player dies
            if ply.wep.Clip then
                ply.wep.DeadPlayerClip = ply.wep.Clip
            end
            if ply.wep.AmmoType then
                ply.wep.DeadPlayerAmmoType = ply.wep.AmmoType
            end
            ply.wep=nil
        end

		if IsValid(ply.WepCons) and ply:Alive() then
			ply.WepCons:Remove()
			ply.WepCons=nil
		elseif IsValid(ply.WepCons) then
			ply.WepCons=nil
		end

		if IsValid(ply.WepCons2) and ply:Alive() then
			ply.WepCons2:Remove()
			ply.WepCons2=nil
		elseif IsValid(ply.WepCons2) then
			ply.WepCons2=nil
		end
		ply.FakeShooting=false
end
function CheckAmmo(ply, wep)
	if ply:Alive() then
		wep.Clip = ply.Info.Weapons[ply.Info.ActiveWeapon].Clip1 or 0
		wep.MaxClip = ply.Info.ActiveWeapon2:GetMaxClip1() or 0
		-- print(ply:GetAmmoCount(ply.Info.ActiveWeapon2:GetPrimaryAmmoType()))
		wep.Amt=ply:GetAmmoCount(ply.Info.ActiveWeapon2:GetPrimaryAmmoType()) or 0
		wep.AmmoType=ply.Info.ActiveWeapon2:GetPrimaryAmmoType() or 0
	else
		-- For dead players, DON'T override ammo if it's already been set properly
		-- Only set MaxClip and Amt if they're missing
		if not wep.MaxClip then
			local weaponTable = weapons.Get(wep.curweapon or "weapon_pistol")
			wep.MaxClip = (weaponTable and weaponTable.Primary and weaponTable.Primary.ClipSize) or 30
		end
		if not wep.Amt then
			wep.Amt = 0
		end
	end
end

function SpawnWeaponEnt(weapon, pos, ply)
    local wep = ents.Create("wep")
    wep:SetModel(GunsModel[weapon])
    wep:SetPos(pos)
    wep:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    wep:Spawn()
    wep:SetAngles(ply:EyeAngles() or Angle(0,0,0))
    local wepPhys = wep:GetPhysicsObject()
    if IsValid(wepPhys) then
        wepPhys:ApplyForceOffset(VectorRand(-2,2),wep:GetPos())
    end
    wep.curweapon = ply.curweapon
    wep.Clip = ply.Clip
    wep.AmmoType = ply.AmmoType
    wep.canpickup=true
    return wep
end

function Reload(wep)
	if not wep then return end
	local weptable = weapons.Get(wep.curweapon)
	if !IsValid(wep) then return nil end
	if ShootWait[wep.curweapon]==nil then return nil end
	local ply = wep:GetOwner()
	if !timer.Exists("reload"..wep:EntIndex()) and wep.Clip!=wep.MaxClip and wep.Amt>0 then
		wep:EmitSound( "weapons/smg1/smg1_reload.wav", 75, 100, 1 )
		timer.Create("reload"..wep:EntIndex(), ReloadTime[wep.curweapon], 1, function()
			if IsValid(wep) then
				local oldclip = wep.Clip
				wep.Clip = math.Clamp(wep.Clip+wep.Amt,0,wep.MaxClip)
				local needed = wep.Clip-oldclip
				wep.Amt=wep.Amt-needed
				ply.Info.Ammo[wep.AmmoType]=wep.Amt
			end
		end)
	end
end

NextShot=0


HMCD_SurfaceHardness={
    [MAT_METAL]=.95,[MAT_COMPUTER]=.95,[MAT_VENT]=.95,[MAT_GRATE]=.95,[MAT_FLESH]=.5,[MAT_ALIENFLESH]=.3,
    [MAT_SAND]=.1,[MAT_DIRT]=.3,[74]=.1,[85]=.2,[MAT_WOOD]=.5,[MAT_FOLIAGE]=.5,
    [MAT_CONCRETE]=.9,[MAT_TILE]=.8,[MAT_SLOSH]=.05,[MAT_PLASTIC]=.3,[MAT_GLASS]=.6
}


local pos = Vector(0,0,0)

function FireShot(wep)
	if not IsValid(wep) then 
		if GetConVar("developer"):GetInt() > 0 then
			print("Weapon is not valid!")
		end
		return 
	end
	
	-- Get the weapon owner, but handle case where owner is nil (dead player)
	local ply = wep:GetOwner()
	local originalPly = ply
	if not IsValid(ply) then
		-- Find the player who owns this weapon through ragdoll connection
		if IsValid(wep.rag) then
			for _, player in pairs(player.GetAll()) do
				if player:GetNWEntity("player_ragdoll") == wep.rag then
					ply = player
					break
				end
			end
		end
		-- If still no valid player, create a dummy player reference
		if not IsValid(ply) then
			ply = game.GetWorld() -- Use world as fallback
		end
	end
	
	local weptable = weapons.Get(wep.curweapon)
	function wep:BulletCallbackFunc(dmgAmt,ply,tr,dmg,tracer,hard,multi)
		-- Prevent self-damage to player's own ragdoll arms and hands
		local shooter = self:GetOwner()
		-- Handle case where shooter is nil (dead player)
		if not IsValid(shooter) and IsValid(self.rag) then
			for _, player in pairs(player.GetAll()) do
				if player:GetNWEntity("player_ragdoll") == self.rag then
					shooter = player
					break
				end
			end
		end
		
		if IsValid(shooter) and IsValid(tr.Entity) then
			local shooterRag = shooter:GetNWEntity("player_ragdoll")
			if IsValid(shooterRag) and tr.Entity == shooterRag then
					-- Check if hit bone is arm or hand by comparing physics bone indices
			local hitPhysBone = tr.PhysicsBone
			if hitPhysBone then
				-- Get physics bone indices for hands and arms
				local handBones = {
					"ValveBiped.Bip01_L_Hand",
					"ValveBiped.Bip01_R_Hand",
					"ValveBiped.Bip01_L_Forearm",
					"ValveBiped.Bip01_R_Forearm",
					"ValveBiped.Bip01_L_UpperArm",
					"ValveBiped.Bip01_R_UpperArm"
				}
				
				for _, boneName in ipairs(handBones) do
					local boneIndex = shooterRag:LookupBone(boneName)
					if boneIndex then
						local physBone = shooterRag:TranslateBoneToPhysBone(boneIndex)
						if physBone == hitPhysBone then
							-- Skip damage for arms and hands
							return
						end
					end
				end
			end
			end
		end
		
		if(tr.MatType==MAT_FLESH)then
			util.Decal("Blood",tr.HitPos+tr.HitNormal,tr.HitPos-tr.HitNormal)
			local vPoint = tr.HitPos
			local effectdata = EffectData()
			effectdata:SetOrigin( vPoint )
			util.Effect( "BloodImpact", effectdata )
		end
		if(self.NumBullet or 1>1)then return end
		if(tr.HitSky)then return end
		if(hard)then self:RicochetOrPenetrate(tr) end
	end
	function wep:RicochetOrPenetrate(initialTrace)
		local AVec,IPos,TNorm,SMul=initialTrace.Normal,initialTrace.HitPos,initialTrace.HitNormal,HMCD_SurfaceHardness[initialTrace.MatType]
		if not(SMul)then SMul=.5 end
		local ApproachAngle=-math.deg(math.asin(TNorm:DotProduct(AVec)))
		local MaxRicAngle=80*SMul
		if(ApproachAngle>(MaxRicAngle*1.25))then 
			local MaxDist,SearchPos,SearchDist,Penetrated=(math.random(5,40)/SMul)*.15,IPos,5,false
			while((not(Penetrated))and(SearchDist<MaxDist))do
				SearchPos=IPos+AVec*SearchDist
				local PeneTrace=util.QuickTrace(SearchPos,-AVec*SearchDist)
				if((not(PeneTrace.StartSolid))and(PeneTrace.Hit))then
					Penetrated=true
				else
					SearchDist=SearchDist+5
				end
			end
			if(Penetrated)then
				self:FireBullets({
					Attacker=self:GetOwner(),
					Damage=1,
					Force=1,
					Num=1,
					Tracer=0,
					TracerName="",
					Dir=-AVec,
					Spread=Vector(0,0,0),
					Src=SearchPos+AVec
				})
				Damage = 0
				if checkwepinfo(wep.curweapon) ~= nil then
					Damage=checkwepinfo(wep.curweapon)
					else
					Damage=math.random(25,50)
					end
				self:FireBullets({
					Attacker=self:GetOwner(),
					Damage ,
					Force=math.random(20,60) / 40 *.65,
					Num=1,
					Tracer=0,
					TracerName="",
					Dir=AVec,
					Spread=Vector(0,0,0),
					Src=SearchPos+AVec
				})
			end
		elseif(ApproachAngle<(MaxRicAngle*.75))then -- ping whiiiizzzz
			sound.Play("snd_jack_hmcd_ricochet_"..math.random(1,2)..".wav",IPos,70,math.random(90,100))
			local NewVec=AVec:Angle()
			NewVec:RotateAroundAxis(TNorm,180)
			NewVec=NewVec:Forward()
			self:FireBullets({
				Attacker=self:GetOwner(),
				Damage=checkwepinfo(wep.curweapon),
				Force=math.random(5,20)/60,
				Num=1,
				Tracer=0,
				TracerName="",
				Dir=-NewVec,
				Spread=Vector(0,0,0),
				Src=IPos+TNorm
			})
		end
	end
	if wep.Clip<=0  then
		sound.Play("snd_jack_hmcd_click.wav",wep:GetPos(),65,100)
		wep.NextShot = CurTime() + ShootWait[wep.curweapon] 
	return nil end
	if timer.Exists("reload"..wep:EntIndex()) then 
		return nil 
	end
	-- wep:EmitSound( "weapons/smg1/smg1_reload.wav", 75, 100, 1 )
	local guninfo = wep.GunInfo
	
	wep.NextShot=wep.NextShot or NextShot
	shootWait = ShootWait[wep.curweapon]
	-- wep.NextShot = CurTime() + ShootWait[wep.curweapon]
	if ( wep.NextShot > CurTime() ) then return end

	wep.NextShot = CurTime() + (shootWait or 1)
	local Attachment = wep:GetAttachment(wep:LookupAttachment("muzzle"))

	local shootOrigin = Attachment and Attachment.Pos or wep:GetPos() + wep:GetAngles():Forward() * 10
	local shootAngles = Attachment and Attachment.Ang or wep:GetAngles()
	local shootDir = shootAngles:Forward()
	
	-- Get proper damage from our damage system
	local damage = checkwepinfo(wep.curweapon) or 30
	
	-- Get pellet count for shotguns
	local pelletCount = bullets[wep.curweapon] or 1
	
	-- Get weapon accuracy
	local accuracy = WeaponAccuracy[wep.curweapon] or 0.1
	
	-- Create filter to exclude player's ragdoll arms and hands
	local filterTable = {ply, wep}
	local playerRag = nil
	if IsValid(ply) and ply ~= game.GetWorld() then
		playerRag = ply:GetNWEntity("player_ragdoll")
	else
		-- For dead players, get ragdoll from weapon connection
		playerRag = wep.rag
	end
	if IsValid(playerRag) then
		-- Add specific hand and arm physics objects to filter
		local handBones = {
			"ValveBiped.Bip01_L_Hand",
			"ValveBiped.Bip01_R_Hand",
			"ValveBiped.Bip01_L_Forearm",
			"ValveBiped.Bip01_R_Forearm",
			"ValveBiped.Bip01_L_UpperArm",
			"ValveBiped.Bip01_R_UpperArm"
		}
		
		for _, boneName in ipairs(handBones) do
			local boneIndex = playerRag:LookupBone(boneName)
			if boneIndex then
				local physBone = playerRag:TranslateBoneToPhysBone(boneIndex)
				if physBone >= 0 then
					local physObj = playerRag:GetPhysicsObjectNum(physBone)
					if IsValid(physObj) then
						table.insert(filterTable, physObj)
					end
				end
			end
		end
		
		-- Also add the ragdoll itself as backup
		table.insert(filterTable, playerRag)
	end
	
	-- Check if weapon has non-lethal property for damage type
	local isNonlethal = false
	if wep.curweapon and MDHomicideNonlethal and MDHomicideNonlethal[wep.curweapon] then
		isNonlethal = MDHomicideNonlethal[wep.curweapon]
	end
	
	local bullet = {}
		bullet.Num 			= pelletCount
		bullet.Src 			= shootOrigin
		bullet.Dir 			= shootDir
		bullet.Spread 		= Vector(accuracy, accuracy, 0)
		bullet.Tracer		= 1
		bullet.TracerName 	= 4
		bullet.Force		= math.random(5,15)
		bullet.Damage		= damage
		bullet.Attacker 	= ply
		bullet.Filter		= filterTable
		bullet.Callback=function(ply,tr)
			-- Apply damage with appropriate damage type
			if tr.Hit and IsValid(tr.Entity) then
				local dmgInfo = DamageInfo()
				dmgInfo:SetDamage(damage)
				dmgInfo:SetAttacker(ply)
				dmgInfo:SetInflictor(wep)
				dmgInfo:SetDamagePosition(tr.HitPos)
				-- Use club damage for non-lethal weapons, bullet damage otherwise
				if isNonlethal then
					dmgInfo:SetDamageType(DMG_CLUB)
				else
					dmgInfo:SetDamageType(DMG_BULLET)
				end
				tr.Entity:TakeDamageInfo(dmgInfo)
			end
			-- Call original bullet callback for effects
			wep:BulletCallbackFunc(damage,ply,tr,damage,false,true,false)
		end

	wep:FireBullets( bullet )
	
	-- Play both close and far sounds
	local closeSound, farSound = getsound(wep.curweapon)
	local weaponPitch = getweaponpitch(wep.curweapon)
	if closeSound then
		wep:EmitSound( closeSound, 75, weaponPitch, 1, CHAN_WEAPON)
	end
	if farSound and farSound ~= closeSound then
		wep:EmitSound( farSound, 60, weaponPitch, 0.8, CHAN_WEAPON2)
	end
		-- Apply recoil forces
		local rag = nil
		if IsValid(ply) and ply ~= game.GetWorld() then
			rag = ply:GetNWEntity("player_ragdoll")
		else
			-- For dead players, use weapon's ragdoll connection
			rag = wep.rag
		end
		if IsValid(rag) then
			local forceDir = Vector(1,0,0) -- Default forward direction
			if IsValid(ply) and ply ~= game.GetWorld() then
				forceDir = ply:EyeAngles():Forward()
			else
				-- Use weapon's forward direction for dead players
				forceDir = wep:GetAngles():Forward()
			end
			rag:GetPhysicsObjectNum(0):ApplyForceCenter(forceDir*-damage*0.75)
		end
		-- Check if weapon physics object is valid before applying recoil force
		local wepPhys = wep:GetPhysicsObject()
		if IsValid(wepPhys) then
			wepPhys:ApplyForceCenter(wep:GetAngles():Forward()*-damage*0.05+wep:GetAngles():Right()*VectorRand(-90,90)+wep:GetAngles():Up()*100)
		end
	wep.Clip=wep.Clip-1
	-- Make a custom muzzle flash using ParticleEffect system
	local muzzleEffect = WeaponMuzzleFlash[wep.curweapon] or "pcf_jack_mf_spistol" -- Default to pistol effect
	
	-- Use ParticleEffect instead of util.Effect for custom muzzle flash
	if muzzleEffect then
		ParticleEffect(muzzleEffect, shootOrigin, shootAngles)
	end

end
end
-- Developer mode debugging features
if CLIENT then
	-- Developer mode visual debugging
	hook.Add("PostDrawOpaqueRenderables", "RagshootingDebugVisuals", function()
		local ply = LocalPlayer()
		local wep = ply:GetNWEntity('wep')
		local rag = ply:GetNWBool('radsfa')
		local isDeveloper = GetConVar("developer"):GetInt() > 0
		
		if IsValid(wep) and rag and isDeveloper then
			local Attachment = wep:GetAttachment(wep:LookupAttachment("muzzle"))
			if Attachment then
				local shootOrigin = Attachment.Pos
				local shootAngles = Attachment.Ang
				local shootDir = shootAngles:Forward()
				
				-- Draw muzzle position indicator
				render.DrawSphere(shootOrigin, 2, 8, 8, Color(0, 255, 0, 200))
				
				-- Draw bullet trajectory line
				local traceData = {}
				traceData.start = shootOrigin
				traceData.endpos = shootOrigin + shootDir * 10000
				traceData.filter = {ply, wep}
				local traceResult = util.TraceLine(traceData)
				
				render.DrawLine(shootOrigin, traceResult.HitPos, Color(255, 0, 0, 255), false)
				
				-- Draw hit point indicator
				if traceResult.Hit then
					render.DrawSphere(traceResult.HitPos, 3, 8, 8, Color(255, 255, 0, 200))
				end
			end
		end
	end)
	
	-- Developer mode HUD information
	hook.Add("HUDPaint", "RagshootingDebugHUD", function()
		local ply = LocalPlayer()
		local wep = ply:GetNWEntity('wep')
		local rag = ply:GetNWBool('radsfa')
		local isDeveloper = GetConVar("developer"):GetInt() > 0
		
		if IsValid(wep) and rag and isDeveloper and wep.curweapon then
			local weaponName = wep.curweapon
			local damage = WeaponDamage and WeaponDamage[weaponName] or checkwepinfo(weaponName)
			local fireRate = ShootWait and ShootWait[weaponName] or "N/A"
			local isAuto = AutomaticWeapons and AutomaticWeapons[weaponName] or false
			local isTwoHanded = TwoHandedOrNo and TwoHandedOrNo[weaponName] or false
			local accuracy = WeaponAccuracy and WeaponAccuracy[weaponName] or "N/A"
			local pellets = bullets and bullets[weaponName] or 1
			
			-- Draw debug info panel
			local x, y = 20, ScrH() - 200
			local panelW, panelH = 300, 150
			
			-- Background panel
			surface.SetDrawColor(0, 0, 0, 150)
			surface.DrawRect(x, y, panelW, panelH)
			
			-- Border
			surface.SetDrawColor(255, 255, 255, 100)
			surface.DrawOutlinedRect(x, y, panelW, panelH)
			
			-- Title
			draw.SimpleText("WEAPON DEBUG INFO", "DermaDefault", x + 10, y + 5, Color(255, 255, 0), TEXT_ALIGN_LEFT)
			
			-- Weapon info
			local infoY = y + 25
			draw.SimpleText("Weapon: " .. weaponName, "DermaDefault", x + 10, infoY, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			infoY = infoY + 15
			draw.SimpleText("Damage: " .. tostring(damage), "DermaDefault", x + 10, infoY, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			infoY = infoY + 15
			draw.SimpleText("Fire Rate: " .. tostring(fireRate) .. "s", "DermaDefault", x + 10, infoY, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			infoY = infoY + 15
			draw.SimpleText("Mode: " .. (isAuto and "AUTO" or "SEMI"), "DermaDefault", x + 10, infoY, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			infoY = infoY + 15
			draw.SimpleText("Hands: " .. (isTwoHanded and "TWO" or "ONE"), "DermaDefault", x + 10, infoY, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			infoY = infoY + 15
			draw.SimpleText("Accuracy: " .. tostring(accuracy), "DermaDefault", x + 10, infoY, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			infoY = infoY + 15
			draw.SimpleText("Pellets: " .. tostring(pellets), "DermaDefault", x + 10, infoY, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			
			-- Ammo info
			if wep.Clip and wep.MaxClip then
				infoY = infoY + 20
				draw.SimpleText("Ammo: " .. wep.Clip .. "/" .. wep.MaxClip, "DermaDefault", x + 10, infoY, Color(0, 255, 0), TEXT_ALIGN_LEFT)
			end
		end
	end)
end