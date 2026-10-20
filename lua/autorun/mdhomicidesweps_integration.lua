-- MDHomicideSweps Integration for Ragdoll Shooting System
-- This file automatically extracts weapon properties from mdhomicidesweps and adds them to the ragdoll shooting system

-- Include the MDHomicide weapons configuration
include("entities/wep/mdhomicide_weps.lua")
AddCSLuaFile("entities/wep/mdhomicide_weps.lua")

-- Initialize configuration tables if they don't exist (after include)
MDHomicideDamage = MDHomicideDamage or {}
MDHomicideMuzzleFlash = MDHomicideMuzzleFlash or {}
MDHomicideVectors = MDHomicideVectors or {}
MDHomicideVectors2 = MDHomicideVectors2 or {}
MDHomicideFireRate = MDHomicideFireRate or {}
MDHomicideAutomatic = MDHomicideAutomatic or {}
MDHomicideTwoHanded = MDHomicideTwoHanded or {}
MDHomicideReloadTime = MDHomicideReloadTime or {}
MDHomicideAccuracy = MDHomicideAccuracy or {}
MDHomicidePellets = MDHomicidePellets or {}

-- Debug: Print loaded configuration
if GetConVar("developer"):GetInt() > 0 then
    print("[DEBUG] MDHomicide config loaded:")
    print("[DEBUG] AKM Automatic: " .. tostring(MDHomicideAutomatic["wep_mann_hmcd_akm"]))
    print("[DEBUG] AKM Vector: " .. tostring(MDHomicideVectors["wep_mann_hmcd_akm"]))
end
for k, v in pairs(MDHomicideAutomatic) do
    if GetConVar("developer"):GetInt() > 0 then
    print("[DEBUG] Auto config: " .. k .. " = " .. tostring(v))
end
end

local function AddMDHomicideWeapons()
    -- List of all mdhomicidesweps firearms (excluding melee weapons)
    local mdWeapons = {
        "wep_mann_hmcd_akm",
        "wep_daun_hmcd_draco",
        "wep_mann_hmcd_glock", 
        "wep_jack_mded_pistol",
        "wep_daun_hmcd_mp5",
        "wep_jack_mded_shotgun",
        "wep_mann_hmcd_deagle",
        "wep_mann_hmcd_spas",
        "wep_jack_mded_rifle",
        "wep_mann_hmcd_mosin",
        "wep_mann_hmcd_sw500",
        "wep_daun_hmcd_p220",
        "wep_mann_hmcd_m24",
        "wep_mann_hmcd_rpg",
        "wep_mann_hmcd_sg",
        "wep_daun_hmcd_beretta",
        "wep_daun_hmcd_sw659",
        "wep_mann_hmcd_barrett",
        "wep_mann_hmcd_samopal",
        "wep_jack_mded_r870bag",
        "wep_mann_hmcd_revolver_suppressed",
        "wep_jack_mded_assaultrifle",
        "wep_daun_hmcd_ump",
        "wep_jack_mded_fakepistol",
        "wep_daun_hmcd_pm",
        "wep_daun_hmcd_asval",
        "wep_mann_hmcd_pl_suppressed",
        "wep_daun_hmcd_stg",
        "wep_mann_hmcd_m4a1",
        "wep_daun_hmcd_mp7",
        "wep_mann_hmcd_pl",
        "wep_daun_hmcd_borz",
        "wep_mann_hmcd_pnevmat",
        "wep_jack_mded_suppressed_p22",
        "wep_mann_hmcd_db",
        "wep_daun_hmcd_battleworm",
        "wep_daun_hmcd_ptrd",
        "wep_daun_hmcd_usp",
        "wep_mann_hmcd_izhdb",
        "wep_mann_hmcd_ar2",
        "wep_mann_hmcd_shorty",
        "wep_daun_hmcd_sr25",
        "wep_mann_hmcd_mateba",
        "wep_jack_mded_suppressedrifle",
        "wep_daun_hmcd_p99",
        "wep_daun_hmcd_fnp",
        "wep_mann_hmcd_ak74u",
        "wep_daun_hmcd_cz",
        "wep_mann_hmcd_cobra",
        "wep_jack_mded_revolver",
        "wep_mann_hmcd_rifle_noscope"
    }
    
    -- Add weapons to the main Guns table
    for _, weaponName in ipairs(mdWeapons) do
        if not table.HasValue(Guns, weaponName) then
            table.insert(Guns, weaponName)
        end
    end
    
    -- Function to safely get weapon table
    local function GetWeaponTable(weaponName)
        return weapons.Get(weaponName)
    end
    
    -- Function to extract fire rate from weapon
    local function GetFireRate(wepTable)
        if wepTable.TriggerDelay then
            return wepTable.TriggerDelay
        elseif wepTable.CycleTime then
            return wepTable.CycleTime
        elseif wepTable.Primary and wepTable.Primary.Delay then
            return wepTable.Primary.Delay
        end
        return 0.1 -- Default fire rate
    end
    
    -- Function to determine if weapon is automatic
    local function IsAutomatic(wepTable, weaponName)
        if wepTable.Primary and wepTable.Primary.Automatic ~= nil then
            return wepTable.Primary.Automatic
        end
        
        -- Known automatic weapons
        local automaticWeapons = {
            "wep_mann_hmcd_akm", "wep_daun_hmcd_mp5", "wep_jack_mded_assaultrifle",
            "wep_daun_hmcd_ump", "wep_daun_hmcd_asval", "wep_daun_hmcd_stg",
            "wep_mann_hmcd_m4a1", "wep_daun_hmcd_mp7", "wep_daun_hmcd_battleworm",
            "wep_mann_hmcd_ak74u",
            "wep_mann_hmcd_ar2", "wep_mann_hmcd_sg"
        }
        
        if table.HasValue(automaticWeapons, weaponName) then
            return true
        end
        
        -- Check weapon category/type for automatic indicators
        local printName = string.lower(wepTable.PrintName or "")
        if string.find(printName, "assault") or string.find(printName, "submachine") or 
           string.find(printName, "machine") or string.find(printName, "auto") then
            return true
        end
        
        return false -- Default to semi-automatic
    end
    
    -- Function to determine if weapon is two-handed
    local function IsTwoHanded(wepTable, weaponName)
        -- Special cases for known pistols that should be one-handed
        local pistolNames = {
            "wep_mann_hmcd_glock", "wep_jack_mded_pistol", "wep_mann_hmcd_deagle",
            "wep_daun_hmcd_pm", "wep_jack_mded_fakepistol", "wep_jack_mded_suppressed_p22",
            "wep_daun_hmcd_usp", "wep_daun_hmcd_p99", "wep_daun_hmcd_fnp",
            "wep_daun_hmcd_cz", "wep_jack_mded_revolver", "wep_mann_hmcd_sw500",
            "wep_daun_hmcd_p220", "wep_daun_hmcd_sw659", "wep_daun_hmcd_beretta",
            "wep_mann_hmcd_revolver_suppressed", "wep_mann_hmcd_mateba",
            "wep_mann_hmcd_pl", "wep_mann_hmcd_pl_suppressed", "wep_mann_hmcd_cobra"
        }
        
        if table.HasValue(pistolNames, weaponName) then
            return false -- Force pistols to be one-handed
        end
        
        if wepTable.TwoHanded ~= nil then
            return wepTable.TwoHanded
        end
        
        -- Check hold type to determine handedness
        local holdType = wepTable.HipHoldType or wepTable.HoldType or "pistol"
        if holdType == "pistol" or holdType == "revolver" then
            return false -- One-handed
        end
        
        -- Check category for pistols
        if wepTable.Category and string.find(string.lower(wepTable.Category), "pistol") then
            return false
        end
        
        return true -- Two-handed for rifles, shotguns, etc.
    end
    
    -- Function to get fire sounds
    local function GetFireSounds(wepTable)
        local closeSound = wepTable.CloseFireSound or wepTable.Primary.Sound or "weapons/pistol/pistol_fire2.wav"
        local farSound = wepTable.FarFireSound or closeSound
        return closeSound, farSound
    end
    
    -- Function to get reload time
    local function GetReloadTime(wepTable)
        if wepTable.ReloadTime then
            return wepTable.ReloadTime
        end
        return 2 -- Default reload time
    end
    
    -- Function to get world model
    local function GetWorldModel(wepTable)
        return wepTable.WorldModel or "models/weapons/w_pistol.mdl"
    end
    
    -- Configuration tables are now loaded from mdhomicide_weps.lua
    
    -- Process each weapon and add properties
    for _, weaponName in ipairs(mdWeapons) do
        local wepTable = GetWeaponTable(weaponName)
        if wepTable then
            -- Use configuration tables with fallbacks
        ShootWait[weaponName] = MDHomicideFireRate[weaponName] or GetFireRate(wepTable)
        Automatic[weaponName] = MDHomicideAutomatic[weaponName]
        if Automatic[weaponName] == nil then
            Automatic[weaponName] = IsAutomatic(wepTable, weaponName)
        end
        TwoHandedOrNo[weaponName] = MDHomicideTwoHanded[weaponName]
        if TwoHandedOrNo[weaponName] == nil then
            TwoHandedOrNo[weaponName] = IsTwoHanded(wepTable, weaponName)
        end
        ReloadTime[weaponName] = MDHomicideReloadTime[weaponName] or GetReloadTime(wepTable)
        GunsModel[weaponName] = GetWorldModel(wepTable)
        
        -- Use configured vectors or defaults
        Vectors[weaponName] = MDHomicideVectors[weaponName] or (TwoHandedOrNo[weaponName] and Vector(12, -1, 2) or Vector(14, 0, 4))
        if TwoHandedOrNo[weaponName] then
            Vectors2[weaponName] = MDHomicideVectors2[weaponName] or Vector(12, -2, -4)
        end
        
        -- Debug print for key weapons
        if weaponName == "wep_mann_hmcd_akm" then
            if GetConVar("developer"):GetInt() > 0 then
    print("[DEBUG] AKM Config - Auto from config: " .. tostring(MDHomicideAutomatic[weaponName]) .. ", Final: " .. tostring(Automatic[weaponName]))
    print("[DEBUG] AKM Vector from config: " .. tostring(MDHomicideVectors[weaponName]) .. ", Final: " .. tostring(Vectors[weaponName]))
end
        end
        
        -- Set pellet count for shotguns
        bullets[weaponName] = MDHomicidePellets[weaponName] or (string.find(string.lower(weaponName), "shotgun") or string.find(string.lower(weaponName), "spas") or string.find(string.lower(weaponName), "db") or string.find(string.lower(weaponName), "_sg") and 8 or nil)
        
        -- Set weapon accuracy
        if not WeaponAccuracy then WeaponAccuracy = {} end
        WeaponAccuracy[weaponName] = MDHomicideAccuracy[weaponName] or (bullets[weaponName] and 0.4 or 0.1)
        
        -- Set weapon damage
        if not WeaponDamage then WeaponDamage = {} end
        WeaponDamage[weaponName] = MDHomicideDamage[weaponName] or (wepTable.Primary and wepTable.Primary.Damage) or 30
        
        -- Set custom muzzle flash effect
        if not WeaponMuzzleFlash then WeaponMuzzleFlash = {} end
        if MDHomicideMuzzleFlash[weaponName] then
            WeaponMuzzleFlash[weaponName] = MDHomicideMuzzleFlash[weaponName]
        end
            
            if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Added weapon: " .. weaponName .. " (Auto: " .. tostring(Automatic[weaponName]) .. ", TwoHanded: " .. tostring(TwoHandedOrNo[weaponName]) .. ", FireRate: " .. (ShootWait[weaponName] or "N/A") .. ")")
        end
        else
            if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Warning: Could not find weapon table for " .. weaponName)
        end
        end
    end
    
    if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Successfully integrated " .. #mdWeapons .. " weapons into ragdoll shooting system")
    end
end

-- Custom getsound function for mdhomicidesweps
local originalGetSound = getsound
function getsound(weaponClassName)
    local wepTable = weapons.Get(weaponClassName)
    if wepTable then
        -- Check for mdhomicidesweps specific sound properties
        local closeSound = wepTable.CloseFireSound or wepTable.Primary.Sound or "weapons/pistol/pistol_fire2.wav"
        local farSound = wepTable.FarFireSound or closeSound
        return closeSound, farSound
    end
    
    -- Fallback to original function
    return originalGetSound(weaponClassName)
end

-- Hook to add weapons after all addons are loaded
hook.Add("Initialize", "MDHomicideSwepsIntegration", function()
    timer.Simple(1, function() -- Delay to ensure all weapons are loaded
        AddMDHomicideWeapons()
    end)
end)

-- Also run on client
if CLIENT then
    hook.Add("InitPostEntity", "MDHomicideSwepsIntegrationClient", function()
        timer.Simple(2, function() -- Longer delay for client
            AddMDHomicideWeapons()
        end)
    end)
end

-- Function to reload configuration from file
local function ReloadConfiguration()
    if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Reloading configuration...")
    end
    
    -- Clear existing configuration tables
    MDHomicideDamage = {}
    MDHomicideMuzzleFlash = {}
    MDHomicideVectors = {}
    MDHomicideVectors2 = {}
    MDHomicideFireRate = {}
    MDHomicideAutomatic = {}
    MDHomicideTwoHanded = {}
    MDHomicideReloadTime = {}
    MDHomicideAccuracy = {}
    MDHomicidePellets = {}
    
    -- Reload the configuration file
    include("entities/wep/mdhomicide_weps.lua")
    if CLIENT then
        AddCSLuaFile("entities/wep/mdhomicide_weps.lua")
    end
    
    -- Re-initialize configuration tables if they don't exist after include
    MDHomicideDamage = MDHomicideDamage or {}
    MDHomicideMuzzleFlash = MDHomicideMuzzleFlash or {}
    MDHomicideVectors = MDHomicideVectors or {}
    MDHomicideVectors2 = MDHomicideVectors2 or {}
    MDHomicideFireRate = MDHomicideFireRate or {}
    MDHomicideAutomatic = MDHomicideAutomatic or {}
    MDHomicideTwoHanded = MDHomicideTwoHanded or {}
    MDHomicideReloadTime = MDHomicideReloadTime or {}
    MDHomicideAccuracy = MDHomicideAccuracy or {}
    MDHomicidePellets = MDHomicidePellets or {}
    
    if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Configuration reloaded successfully!")
    end
end

-- Console command for manual integration (useful for testing)
concommand.Add("mdhomicide_integrate", function(ply, cmd, args)
    if SERVER and (not IsValid(ply) or ply:IsSuperAdmin()) then
        if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Manually triggering weapon integration...")
    end
        AddMDHomicideWeapons()
    elseif CLIENT then
        if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Manually triggering weapon integration on client...")
        end
        AddMDHomicideWeapons()
    end
end, nil, "Manually integrate MDHomicide weapons into ragdoll shooting system")

-- Console command for live configuration reload
concommand.Add("mdhomicide_reload", function(ply, cmd, args)
    if SERVER and (not IsValid(ply) or ply:IsSuperAdmin()) then
        if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Live reloading configuration and weapons...")
    end
        ReloadConfiguration()
        AddMDHomicideWeapons()
        if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Live reload complete! All settings updated.")
    end
    elseif CLIENT then
        if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Live reloading configuration on client...")
        end
        ReloadConfiguration()
        AddMDHomicideWeapons()
        if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Client live reload complete!")
        end
    end
end, nil, "Live reload MDHomicide weapon configuration without server restart")

-- Console command for quick property updates
concommand.Add("mdhomicide_update", function(ply, cmd, args)
    if SERVER and (not IsValid(ply) or ply:IsSuperAdmin()) then
        if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Quick updating weapon properties...")
    end
        
        -- Update existing weapons with new configuration values
        for _, weaponName in ipairs(mdWeapons) do
            if table.HasValue(Guns, weaponName) then
                local wepTable = GetWeaponTable(weaponName)
                if wepTable then
                    -- Update fire rate
                    if MDHomicideFireRate[weaponName] then
                        ShootWait[weaponName] = MDHomicideFireRate[weaponName]
                    end
                    
                    -- Update automatic status
                    if MDHomicideAutomatic[weaponName] ~= nil then
                        Automatic[weaponName] = MDHomicideAutomatic[weaponName]
                    end
                    
                    -- Update two-handed status
                    if MDHomicideTwoHanded[weaponName] ~= nil then
                        TwoHandedOrNo[weaponName] = MDHomicideTwoHanded[weaponName]
                    end
                    
                    -- Update vectors
                    if MDHomicideVectors[weaponName] then
                        Vectors[weaponName] = MDHomicideVectors[weaponName]
                    end
                    if MDHomicideVectors2[weaponName] and TwoHandedOrNo[weaponName] then
                        Vectors2[weaponName] = MDHomicideVectors2[weaponName]
                    end
                    
                    -- Update damage
                    if MDHomicideDamage[weaponName] then
                        WeaponDamage[weaponName] = MDHomicideDamage[weaponName]
                    end
                    
                    -- Update accuracy
                    if MDHomicideAccuracy[weaponName] then
                        WeaponAccuracy[weaponName] = MDHomicideAccuracy[weaponName]
                    end
                    
                    -- Update pellet count
                    if MDHomicidePellets[weaponName] then
                        bullets[weaponName] = MDHomicidePellets[weaponName]
                    end
                    
                    -- Update reload time
                    if MDHomicideReloadTime[weaponName] then
                        ReloadTime[weaponName] = MDHomicideReloadTime[weaponName]
                    end
                    
                    -- Update muzzle flash effect
                    if MDHomicideMuzzleFlash[weaponName] then
                        if not WeaponMuzzleFlash then WeaponMuzzleFlash = {} end
                        WeaponMuzzleFlash[weaponName] = MDHomicideMuzzleFlash[weaponName]
                    end
                end
            end
        end
        
        if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Quick update complete! Properties updated for all weapons.")
    end
    end
end, nil, "Quick update weapon properties from current configuration")

-- Auto-reload system with file monitoring
local lastConfigCheck = 0
local autoReloadEnabled = false

-- Function to check if configuration file has been modified
local function CheckConfigurationChanges()
    if not autoReloadEnabled then return end
    
    local currentTime = CurTime()
    if currentTime - lastConfigCheck < 2 then return end -- Check every 2 seconds
    
    lastConfigCheck = currentTime
    
    -- Simple change detection by re-including and comparing a key value
    local oldAKMAuto = MDHomicideAutomatic["wep_mann_hmcd_akm"]
    local oldAKMVector = MDHomicideVectors["wep_mann_hmcd_akm"]
    
    -- Temporarily reload config to check for changes
    local tempDamage = table.Copy(MDHomicideDamage or {})
    local tempVectors = table.Copy(MDHomicideVectors or {})
    local tempAutomatic = table.Copy(MDHomicideAutomatic or {})
    
    include("entities/wep/mdhomicide_weps.lua")
    
    -- Check if anything changed
    local configChanged = false
    if MDHomicideAutomatic["wep_mann_hmcd_akm"] ~= oldAKMAuto then
        configChanged = true
    end
    if tostring(MDHomicideVectors["wep_mann_hmcd_akm"]) ~= tostring(oldAKMVector) then
        configChanged = true
    end
    
    if configChanged then
        if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Configuration file changes detected! Auto-reloading...")
        end
        ReloadConfiguration()
        AddMDHomicideWeapons()
        if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Auto-reload complete!")
        end
    end
end

-- Hook for auto-reload checking
hook.Add("Think", "MDHomicideAutoReload", CheckConfigurationChanges)

-- Console command to enable/disable auto-reload
concommand.Add("mdhomicide_autoreload", function(ply, cmd, args)
    if SERVER and (not IsValid(ply) or ply:IsSuperAdmin()) then
        local enable = args[1]
        if enable == "1" or enable == "on" or enable == "true" then
            autoReloadEnabled = true
            if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Auto-reload enabled! Configuration will be monitored for changes.")
        end
        elseif enable == "0" or enable == "off" or enable == "false" then
            autoReloadEnabled = false
            if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Auto-reload disabled.")
        end
        else
            autoReloadEnabled = not autoReloadEnabled
            if GetConVar("developer"):GetInt() > 0 then
            print("[MDHomicide Integration] Auto-reload " .. (autoReloadEnabled and "enabled" or "disabled") .. ".")
        end
        end
    end
end, nil, "Enable/disable automatic configuration reloading (usage: mdhomicide_autoreload [1/0/on/off])")

-- Console command for help
concommand.Add("mdhomicide_help", function(ply, cmd, args)
    if SERVER and (not IsValid(ply) or ply:IsSuperAdmin()) then
        if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Available Commands:")
        print("  mdhomicide_reload     - Full reload of configuration and weapons")
        print("  mdhomicide_update     - Quick update of weapon properties only")
        print("  mdhomicide_integrate  - Manual weapon integration")
        print("  mdhomicide_autoreload - Toggle automatic configuration monitoring")
        print("  mdhomicide_list       - List all integrated weapons")
        print("  mdhomicide_help       - Show this help")
        print("")
        print("[MDHomicide Integration] Live Configuration System:")
        print("  • Edit mdhomicide_weps.lua and use 'mdhomicide_reload' for full reload")
        print("  • Use 'mdhomicide_update' for quick property updates")
        print("  • Enable 'mdhomicide_autoreload 1' for automatic change detection")
        print("  • No server restart required for any configuration changes!")
    end
    end
end, nil, "Show help for MDHomicide live configuration system")

-- Debug command to list integrated weapons
concommand.Add("mdhomicide_list", function(ply, cmd, args)
    if SERVER and (not IsValid(ply) or ply:IsSuperAdmin()) then
        if GetConVar("developer"):GetInt() > 0 then
        print("[MDHomicide Integration] Integrated weapons:")
    end
        for i, weapon in ipairs(Guns) do
            if string.find(weapon, "hmcd") or string.find(weapon, "mded") then
                local auto = Automatic[weapon] and "AUTO" or "SEMI"
                local handed = TwoHandedOrNo[weapon] and "2H" or "1H"
                local rate = ShootWait[weapon] or "N/A"
                local damage = WeaponDamage[weapon] or "N/A"
                local accuracy = WeaponAccuracy[weapon] or "N/A"
                if GetConVar("developer"):GetInt() > 0 then
            print(string.format("%d. %s [%s] [%s] [Rate: %s] [Dmg: %s] [Acc: %s]", i, weapon, auto, handed, rate, damage, accuracy))
        end
            end
        end
        if GetConVar("developer"):GetInt() > 0 then
        print("")
        print("Auto-reload status: " .. (autoReloadEnabled and "ENABLED" or "DISABLED"))
    end
    end
end, nil, "List all integrated MDHomicide weapons with current properties")