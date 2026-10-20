-- Server-side radial menu functionality
-- Handles weapon unloading with proper client-server communication

util.AddNetworkString("RadialUnloadWeapon")

-- Handle weapon unloading from client
net.Receive("RadialUnloadWeapon", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:Clip1() <= 0 then return end
	
	-- Get ammo information
	local ammoType = wep:GetPrimaryAmmoType()
	local ammoCount = wep:Clip1()
	
	if ammoType == -1 or ammoCount <= 0 then return end
	
	-- Use TakePrimaryAmmo method for mdhomicidesweps compatibility
	if wep.TakePrimaryAmmo then
		-- mdhomicidesweps weapon - use their method
		wep:TakePrimaryAmmo(ammoCount)
		ply:GiveAmmo(ammoCount, ammoType)
	else
		-- Standard weapon - set clip to 0 and give ammo
		wep:SetClip1(0)
		ply:GiveAmmo(ammoCount, ammoType)
	end
	
	-- Optional: Play unload sound
	ply:EmitSound("snd_jack_hmcd_ammotake.wav", 50, 100)
end)