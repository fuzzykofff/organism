-- MDHomicide Weapons Configuration
-- This file contains all configuration for MDHomicide weapons in the ragdoll shooting system
-- Edit these values to customize weapon behavior, positioning, and properties

-- Weapon damage values (if not specified, uses SWEP damage)
MDHomicideDamage = {

}

-- Custom muzzle flash effects for MDHomicide weapons
-- This table defines custom muzzle flash particle effects for each weapon
MDHomicideMuzzleFlash = {
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
    ["wep_jack_mded_suppressed_p22"] = "pcf_jack_mf_suppressed",
    ["wep_daun_hmcd_usp"] = "pcf_jack_mf_spistol",
    ["wep_daun_hmcd_p99"] = "pcf_jack_mf_spistol",
    ["wep_daun_hmcd_fnp"] = "pcf_jack_mf_spistol",
    ["wep_daun_hmcd_cz"] = "pcf_jack_mf_spistol",
    ["wep_jack_mded_revolver"] = "pcf_jack_mf_spistol",
    ["wep_mann_hmcd_mateba"] = "pcf_jack_mf_spistol",
    ["wep_mann_hmcd_pl"] = "pcf_jack_mf_spistol",
    ["wep_mann_hmcd_pl_suppressed"] = "pcf_jack_mf_suppressed",
    ["wep_mann_hmcd_revolver_suppressed"] = "pcf_jack_mf_suppressed",
    ["wep_mann_hmcd_cobra"] = "pcf_jack_mf_spistol",
    ["wep_daun_hmcd_borz"] = "pcf_jack_mf_spistol",
    
    -- SMGs
    ["wep_daun_hmcd_mp5"] = "pcf_jack_mf_mrifle1",
    ["wep_daun_hmcd_ump"] = "pcf_jack_mf_mrifle1",
    ["wep_daun_hmcd_mp7"] = "pcf_jack_mf_mrifle1",
    ["wep_daun_hmcd_asval"] = "pcf_jack_mf_suppressed",
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
    ["wep_jack_mded_suppressedrifle"] = "pcf_jack_mf_suppressed",
    ["wep_mann_hmcd_ar2"] = "pcf_jack_mf_mrifle2",
    ["wep_mann_hmcd_rifle_noscope"] = "pcf_jack_mf_mrifle2",
    ["wep_mann_hmcd_m24"] = "pcf_jack_mf_mrifle2",
    ["wep_mann_hmcd_barrett"] = "pcf_jack_mf_mrifle2",
    
    -- Sniper Rifles
    ["wep_mann_hmcd_mosin"] = "pcf_jack_mf_mrifle1",
    ["wep_daun_hmcd_ptrd"] = "pcf_jack_mf_mrifle1",
    ["wep_daun_hmcd_sr25"] = "pcf_jack_mf_mrifle1",
    
    -- Shotguns
    ["wep_jack_mded_shotgun"] = "pcf_jack_mf_mshotgun",
    ["wep_jack_mded_r870bag"] = "pcf_jack_mf_mshotgun",
    ["wep_mann_hmcd_spas"] = "pcf_jack_mf_mshotgun",
    ["wep_mann_hmcd_sg"] = "pcf_jack_mf_mrifle1",
    ["wep_mann_hmcd_db"] = "pcf_jack_mf_mshotgun",
    ["wep_mann_hmcd_izhdb"] = "pcf_jack_mf_mshotgun",
    ["wep_jack_mded_r870bag"] = "pcf_jack_mf_mshotgun",
    ["wep_mann_hmcd_shorty"] = "pcf_jack_mf_mshotgun",
    
    -- Special/Heavy Weapons
    ["wep_mann_hmcd_rpg"] = "pcf_jack_mf_mrifle1",
    ["wep_mann_hmcd_pnevmat"] = "pcf_jack_mf_mrifle1",
}

-- Weapon positioning vectors (right hand position)
MDHomicideVectors = {
    -- Existing weapons that are confirmed to exist
    ["wep_mann_hmcd_akm"] = Vector(12, -1, 3),
    ["wep_mann_hmcd_glock"] = Vector(4, -0.8, -1),
    ["wep_jack_mded_pistol"] = Vector(0, 0, 0),
    ["wep_daun_hmcd_mp5"] = Vector(5, -2.3, -1),
    ["wep_jack_mded_shotgun"] = Vector(-2, -1, 2),
    ["wep_jack_mded_r870bag"] = Vector(3, -1, -2.6),
    ["wep_mann_hmcd_deagle"] = Vector(5, -1.2, -0.8),
    ["wep_mann_hmcd_spas"] = Vector(5, -1, -3),
    ["wep_jack_mded_rifle"] = Vector(0, -0.5, -1),
    ["wep_mann_hmcd_mosin"] = Vector(3, -2, -2),
    ["wep_mann_hmcd_sw500"] = Vector(-1, -1, 1),
    ["wep_mann_hmcd_cobra"] = Vector(1, -1, -1),
    ["wep_daun_hmcd_sr25"] = Vector(-3, -4, -6),
    ["wep_mann_hmcd_rpg"] = Vector(0, 0, 0),
    ["wep_mann_hmcd_sg"] = Vector(14, 0, 4.7),
    ["wep_mann_hmcd_m4a1"] = Vector(0, 0, 0),
    ["wep_jack_mded_revolver"] = Vector(-2, -1, 0),
    ["wep_mann_hmcd_pl"] = Vector(0, 0, 0),
    ["wep_daun_hmcd_asval"] = Vector(11, -1, 0),
    ["wep_daun_hmcd_battleworm"] = Vector(4.5, -1, -3),
    ["wep_daun_hmcd_cz"] = Vector(4, -1.1, -0.4),
    ["wep_daun_hmcd_fnp"] = Vector(6, -0.7, -1),
    ["wep_daun_hmcd_sw659"] = Vector(0, 0, 0),
    ["wep_daun_hmcd_p220"] = Vector(0, 0, 0),
    ["wep_daun_hmcd_mp7"] = Vector(4, -2, -2),
    ["wep_daun_hmcd_p99"] = Vector(3.5, -1.6, -1),
    ["wep_daun_hmcd_pm"] = Vector(4.5, -1.7, -1),
    ["wep_daun_hmcd_ptrd"] = Vector(2, -1, 1),
    ["wep_daun_hmcd_stg"] = Vector(0, -2, -1),
    ["wep_daun_hmcd_ump"] = Vector(12, -1, 4),
    ["wep_daun_hmcd_usp"] = Vector(2, -1.2, -1),
    ["wep_mann_hmcd_ak74u"] = Vector(0, 0, 0),
    ["wep_daun_hmcd_draco"] = Vector(2, -1.2, -1),
    ["wep_daun_hmcd_beretta"] = Vector(5, -1.2, -1),
    ["wep_mann_hmcd_m24"] = Vector(2,-1.6,-1),
    ["wep_mann_hmcd_barrett"] = Vector(2,-1.6,-1),
    ["wep_jack_mded_assaultrifle"] = Vector(3, -1, 0.2),
    ["wep_jack_mded_suppressed_p22"] = Vector(14, 0, 4),
    ["wep_jack_mded_suppressedrifle"] = Vector(0, -0.5, -1),
    ["wep_mann_hmcd_ar2"] = Vector(12, -1, 4),
    ["wep_mann_hmcd_db"] = Vector(1, -2, 1),
    ["wep_mann_hmcd_izhdb"] = Vector(2, 1, 1),
    ["wep_mann_hmcd_mateba"] = Vector(0, 0, 1),
    ["wep_mann_hmcd_pl_suppressed"] = Vector(14, 0, 4),
    ["wep_mann_hmcd_pnevmat"] = Vector(4.5, -1.7, -1),
    ["wep_mann_hmcd_revolver_suppressed"] = Vector(12, 0, 2),
    ["wep_mann_hmcd_rifle_noscope"] = Vector(0, -0.5, -1),
    ["wep_mann_hmcd_samopal"] = Vector(0, 0, 0),
    ["wep_mann_hmcd_shorty"] = Vector(1, -1, 0),
    ["wep_nab_hmcd_batram"] = Vector(12, -1, 4),
    ["wep_daun_hmcd_borz"] = Vector(12.7, -1, 3),
}

-- Weapon positioning vectors (left hand position for two-handed weapons)
MDHomicideVectors2 = {
    -- Existing weapons that are confirmed to exist
    ["wep_mann_hmcd_akm"] = Vector(12, -3, -4),
    ["wep_mann_hmcd_ak74u"] = Vector(12, -3, -4),
    ["wep_daun_hmcd_mp5"] = Vector(10, -4, -3.2),
    ["wep_mann_hmcd_deagle"] = Vector(400, 0, 2),
    ["wep_jack_mded_shotgun"] = Vector(11, -3, -1.3),
    ["wep_jack_mded_r870bag"] = Vector(11, -3, -1.3),
    ["wep_mann_hmcd_spas"] = Vector(17, -3, -3),
    ["wep_jack_mded_rifle"] = Vector(12, -2, -4),
    ["wep_daun_hmcd_draco"] = Vector(8, -2.6, -1.7),
    ["wep_mann_hmcd_mosin"] = Vector(12, -2, -4),
    ["wep_mann_hmcd_rpg"] = Vector(12, -2, -4),
    ["wep_mann_hmcd_sg"] = Vector(14, -1.2, -3),
    ["wep_daun_hmcd_sr25"] = Vector(12, -1.9, -2),
    ["wep_mann_hmcd_m4a1"] = Vector(12, -2, -4),
    ["wep_mann_hmcd_m24"] = Vector(10,-3.5,-1.5),
    ["wep_mann_hmcd_barrett"] = Vector(14,-3.5,-3),
    
    -- Missing weapons from mdhomicidesweps addon (two-handed only)
    ["wep_daun_hmcd_asval"] = Vector(12, -2, -4),
    ["wep_daun_hmcd_battleworm"] = Vector(14, -2, -7),
    ["wep_daun_hmcd_mp7"] = Vector(6, -3, 1),
    ["wep_daun_hmcd_ptrd"] = Vector(12, -2, -4),
    ["wep_daun_hmcd_stg"] = Vector(13, -3.6, -4.5),
    ["wep_daun_hmcd_ump"] = Vector(12, -2, -4),
    ["wep_jack_mded_assaultrifle"] = Vector(11, -2, -3),
    ["wep_jack_mded_suppressedrifle"] = Vector(12, -2, -4),
    ["wep_mann_hmcd_ar2"] = Vector(12, -2, -4),
    ["wep_mann_hmcd_db"] = Vector(5, -3, 0),
    ["wep_mann_hmcd_izhdb"] = Vector(5, -1, 0),
    ["wep_mann_hmcd_rifle_noscope"] = Vector(12, -2, -3),
    ["wep_mann_hmcd_samopal"] = Vector(12, -2, -4),
    ["wep_mann_hmcd_shorty"] = Vector(11, -3, -2.7),
    ["wep_nab_hmcd_batram"] = Vector(12, -2, -4),
}

-- Weapon fire rates (time between shots in seconds)
MDHomicideFireRate = {
    -- Existing weapons that are confirmed to exist
    ["wep_mann_hmcd_akm"] = 0.11,
    ["wep_mann_hmcd_ak74u"] = 0.10,
    ["wep_mann_hmcd_glock"] = 0.08,
    ["wep_jack_mded_pistol"] = 0.15,
    ["wep_daun_hmcd_mp5"] = 0.11,
    ["wep_jack_mded_shotgun"] = 0.8,
    ["wep_jack_mded_r870bag"] = 0.8,
    ["wep_mann_hmcd_deagle"] = 0.35,
    ["wep_mann_hmcd_spas"] = 0.4,
    ["wep_jack_mded_rifle"] = 1.3,
    ["wep_mann_hmcd_mosin"] = 1.5,
    ["wep_mann_hmcd_sw500"] = 0.5,
    ["wep_mann_hmcd_rpg"] = 2.0,
    ["wep_mann_hmcd_sg"] = 0.12,
    ["wep_mann_hmcd_m4a1"] = 0.09,
    ["wep_daun_hmcd_draco"] = 0.08,
    ["wep_jack_mded_revolver"] = 0.4,
    ["wep_daun_hmcd_beretta"] = 0.23,
    ["wep_daun_hmcd_p220"] = 0.22,
    ["wep_daun_hmcd_sw659"] = 0.24,
    ["wep_mann_hmcd_cobra"] = 0.9,
    ["wep_daun_hmcd_sr25"] = 0.2,
    ["wep_mann_hmcd_pl"] = 0.1,
    ["wep_daun_hmcd_borz"] = 0.08,
    ["wep_mann_hmcd_m24"] = 1.35,
    ["wep_mann_hmcd_barrett"] = 1.5,
    
    
    -- Missing weapons from mdhomicidesweps addon
    ["wep_daun_hmcd_asval"] = 0.08,
    ["wep_daun_hmcd_battleworm"] = 0.12,
    ["wep_daun_hmcd_cz"] = 0.102,
    ["wep_daun_hmcd_fnp"] = 0.2,
    ["wep_daun_hmcd_mp7"] = 0.084,
    ["wep_daun_hmcd_p99"] = 0.1,
    ["wep_daun_hmcd_pm"] = 0.12,
    ["wep_daun_hmcd_ptrd"] = 1.8,
    ["wep_daun_hmcd_stg"] = 0.11,
    ["wep_daun_hmcd_ump"] = 0.1,
    ["wep_daun_hmcd_usp"] = 0.1,
    ["wep_jack_mded_assaultrifle"] = 0.13,
    ["wep_jack_mded_suppressed_p22"] = 0.08,
    ["wep_jack_mded_suppressedrifle"] = 0.12,
    ["wep_mann_hmcd_ar2"] = 0.1,
    ["wep_mann_hmcd_db"] = 0.8,
    ["wep_mann_hmcd_izhdb"] = 0.8,
    ["wep_mann_hmcd_mateba"] = 0.4,
    ["wep_mann_hmcd_pl_suppressed"] = 0.1,
    ["wep_mann_hmcd_pnevmat"] = 0.12,
    ["wep_mann_hmcd_revolver_suppressed"] = 0.4,
    ["wep_mann_hmcd_rifle_noscope"] = 1.3,
    ["wep_mann_hmcd_samopal"] = 0.08,
    ["wep_mann_hmcd_shorty"] = 0.6,
    ["wep_nab_hmcd_batram"] = 0.15,
}

-- Weapon fire modes (true = automatic, false = semi-automatic)
MDHomicideAutomatic = {
    -- Existing weapons that are confirmed to exist
    ["wep_mann_hmcd_akm"] = true,
    ["wep_mann_hmcd_ak74u"] = true,
    ["wep_mann_hmcd_glock"] = false,
    ["wep_jack_mded_pistol"] = false,
    ["wep_daun_hmcd_mp5"] = true,
    ["wep_jack_mded_shotgun"] = false,
    ["wep_jack_mded_r870bag"] = false,
    ["wep_mann_hmcd_deagle"] = false,
    ["wep_mann_hmcd_spas"] = false,
    ["wep_jack_mded_rifle"] = true,
    ["wep_mann_hmcd_mosin"] = false,
    ["wep_mann_hmcd_sw500"] = false,
    ["wep_daun_hmcd_sr25"] = false,
    ["wep_mann_hmcd_rpg"] = false,
    ["wep_mann_hmcd_sg"] = true,
    ["wep_mann_hmcd_m4a1"] = true,
    ["wep_jack_mded_revolver"] = false,
    ["wep_mann_hmcd_pl"] = false,
    ["wep_daun_hmcd_borz"] = true,
    
    -- Missing weapons from mdhomicidesweps addon
    ["wep_daun_hmcd_asval"] = true,
    ["wep_daun_hmcd_battleworm"] = true,
    ["wep_daun_hmcd_cz"] = true,
    ["wep_daun_hmcd_fnp"] = false,
    ["wep_daun_hmcd_mp7"] = true,
    ["wep_daun_hmcd_p99"] = false,
    ["wep_daun_hmcd_pm"] = false,
    ["wep_daun_hmcd_ptrd"] = false,
    ["wep_daun_hmcd_stg"] = true,
    ["wep_daun_hmcd_ump"] = true,
    ["wep_daun_hmcd_usp"] = false,
    ["wep_jack_mded_assaultrifle"] = false,
    ["wep_jack_mded_suppressed_p22"] = false,
    ["wep_jack_mded_suppressedrifle"] = true,
    ["wep_mann_hmcd_ar2"] = true,
    ["wep_mann_hmcd_db"] = false,
    ["wep_mann_hmcd_izhdb"] = false,
    ["wep_mann_hmcd_mateba"] = false,
    ["wep_mann_hmcd_pl_suppressed"] = false,
    ["wep_mann_hmcd_pnevmat"] = false,
    ["wep_mann_hmcd_revolver_suppressed"] = false,
    ["wep_mann_hmcd_rifle_noscope"] = false,
    ["wep_mann_hmcd_samopal"] = true,
    ["wep_mann_hmcd_shorty"] = false,
    ["wep_nab_hmcd_batram"] = false,
}

-- Two-handed weapon status (if not specified, auto-detected based on weapon type)
MDHomicideTwoHanded = {
    -- Pistols (one-handed)
    ["wep_mann_hmcd_glock"] = false,
    ["wep_jack_mded_pistol"] = false,
    ["wep_mann_hmcd_deagle"] = false,
    ["wep_jack_mded_revolver"] = false,
    ["wep_mann_hmcd_sw500"] = false,
    ["wep_mann_hmcd_pl"] = false,
    ["wep_daun_hmcd_sr25"] = true,
    ["wep_daun_hmcd_cz"] = false,
    ["wep_daun_hmcd_fnp"] = false,
    ["wep_daun_hmcd_p99"] = false,
    ["wep_daun_hmcd_pm"] = false,
    ["wep_daun_hmcd_usp"] = false,
    ["wep_jack_mded_suppressed_p22"] = false,
    ["wep_mann_hmcd_mateba"] = false,
    ["wep_mann_hmcd_pl_suppressed"] = false,
    ["wep_mann_hmcd_revolver_suppressed"] = false,
    ["wep_daun_hmcd_borz"] = false,
    ["wep_mann_hmcd_m24"] = true,
    ["wep_mann_hmcd_barrett"] = true,
    
    -- Two-handed weapons (rifles, SMGs, shotguns, etc.)
    ["wep_mann_hmcd_akm"] = true,
    ["wep_mann_hmcd_ak74u"] = true,
    ["wep_daun_hmcd_mp5"] = true,
    ["wep_jack_mded_shotgun"] = true,
    ["wep_jack_mded_r870bag"] = true,
    ["wep_mann_hmcd_spas"] = true,
    ["wep_jack_mded_rifle"] = true,
    ["wep_mann_hmcd_mosin"] = true,
    ["wep_mann_hmcd_rpg"] = true,
    ["wep_mann_hmcd_sg"] = true,
    ["wep_mann_hmcd_m4a1"] = true,
    ["wep_daun_hmcd_asval"] = true,
    ["wep_daun_hmcd_battleworm"] = true,
    ["wep_daun_hmcd_mp7"] = true,
    ["wep_daun_hmcd_ptrd"] = true,
    ["wep_daun_hmcd_stg"] = true,
    ["wep_daun_hmcd_ump"] = true,
    ["wep_jack_mded_assaultrifle"] = true,
    ["wep_jack_mded_suppressedrifle"] = true,
    ["wep_mann_hmcd_ar2"] = true,
    ["wep_mann_hmcd_db"] = true,
    ["wep_mann_hmcd_izhdb"] = true,
    ["wep_mann_hmcd_pnevmat"] = false,
    ["wep_mann_hmcd_rifle_noscope"] = true,
    ["wep_mann_hmcd_samopal"] = true,
    ["wep_mann_hmcd_shorty"] = true,
    ["wep_nab_hmcd_batram"] = true,
    ["wep_daun_hmcd_draco"] = true,
}

-- Reload times (in seconds)
MDHomicideReloadTime = {
    -- Existing weapons that are confirmed to exist
    ["wep_mann_hmcd_akm"] = 2.5,
    ["wep_mann_hmcd_glock"] = 1.5,
    ["wep_jack_mded_pistol"] = 2.0,
    ["wep_daun_hmcd_mp5"] = 2.0,
    ["wep_jack_mded_shotgun"] = 3.0,
    ["wep_jack_mded_r870bag"] = 3.0,
    ["wep_mann_hmcd_deagle"] = 2.5,
    ["wep_mann_hmcd_spas"] = 3.5,
    ["wep_jack_mded_rifle"] = 2.8,
    ["wep_mann_hmcd_mosin"] = 4.0,
    ["wep_mann_hmcd_sw500"] = 3.0,
    ["wep_mann_hmcd_rpg"] = 5.0,
    ["wep_mann_hmcd_sg"] = 3.2,
    ["wep_mann_hmcd_m4a1"] = 2.3,
    ["wep_jack_mded_revolver"] = 3.0,
    ["wep_mann_hmcd_pl"] = 1.6,
    
    -- Missing weapons from mdhomicidesweps addon
    ["wep_daun_hmcd_asval"] = 2.2,
    ["wep_daun_hmcd_battleworm"] = 2.8,
    ["wep_daun_hmcd_cz"] = 1.1,
    ["wep_daun_hmcd_fnp"] = 2.2,
    ["wep_daun_hmcd_mp7"] = 1.8,
    ["wep_daun_hmcd_p99"] = 1.7,
    ["wep_daun_hmcd_pm"] = 1.8,
    ["wep_daun_hmcd_ptrd"] = 5.0,
    ["wep_daun_hmcd_stg"] = 2.6,
    ["wep_daun_hmcd_ump"] = 2.2,
    ["wep_daun_hmcd_usp"] = 1.6,
    ["wep_jack_mded_assaultrifle"] = 2.3,
    ["wep_jack_mded_suppressed_p22"] = 1.4,
    ["wep_jack_mded_suppressedrifle"] = 2.8,
    ["wep_mann_hmcd_ar2"] = 2.5,
    ["wep_mann_hmcd_db"] = 3.0,
    ["wep_mann_hmcd_izhdb"] = 3.0,
    ["wep_mann_hmcd_mateba"] = 3.0,
    ["wep_mann_hmcd_pl_suppressed"] = 1.6,
    ["wep_mann_hmcd_pnevmat"] = 4.0,
    ["wep_mann_hmcd_revolver_suppressed"] = 3.0,
    ["wep_mann_hmcd_rifle_noscope"] = 2.8,
    ["wep_mann_hmcd_samopal"] = 2.0,
    ["wep_mann_hmcd_shorty"] = 3.2,
    ["wep_nab_hmcd_batram"] = 2.5,
}

-- Weapon accuracy values (lower = more accurate)
MDHomicideAccuracy = {
    -- Existing weapons that are confirmed to exist
    ["wep_mann_hmcd_akm"] = 0.1,
    ["wep_mann_hmcd_ak74u"] = 0.1,
    ["wep_mann_hmcd_glock"] = 0.1,
    ["wep_jack_mded_pistol"] = 0.1,
    ["wep_daun_hmcd_mp5"] = 0.1,
    ["wep_mann_hmcd_deagle"] = 0.1,
    ["wep_jack_mded_rifle"] = 0.1,
    ["wep_mann_hmcd_mosin"] = 0.05, -- Sniper rifles more accurate
    ["wep_mann_hmcd_sw500"] = 0.1,
    ["wep_mann_hmcd_rpg"] = 0.2,
    ["wep_daun_hmcd_sr25"] = 0.01,
    ["wep_mann_hmcd_m4a1"] = 0.1,
    ["wep_daun_hmcd_beretta"] = 0.1,
    ["wep_daun_hmcd_draco"] = 0.1,
    ["wep_daun_hmcd_sw659"] = 0.1,
    ["wep_daun_hmcd_p220"] = 0.1,
    ["wep_jack_mded_revolver"] = 0.08, -- Revolvers accurate
    ["wep_mann_hmcd_pl"] = 0.1,
    ["wep_daun_hmcd_borz"] = 0.15,
    ["wep_mann_hmcd_barrett"] = 0.01,
    ["wep_mann_hmcd_m24"] = 0.01,
    
    
    -- Shotguns get lower accuracy (higher spread)
    ["wep_jack_mded_shotgun"] = 0.2,
    ["wep_jack_mded_r870bag"] = 0.2,
    ["wep_mann_hmcd_spas"] = 0.2,
    ["wep_mann_hmcd_sg"] = 0.05,
    
    -- Missing weapons from mdhomicidesweps addon
    ["wep_daun_hmcd_asval"] = 0.1,
    ["wep_daun_hmcd_battleworm"] = 0.04,
    ["wep_daun_hmcd_cz"] = 0.1,
    ["wep_daun_hmcd_fnp"] = 0.1,
    ["wep_daun_hmcd_mp7"] = 0.001,
    ["wep_daun_hmcd_p99"] = 0.1,
    ["wep_daun_hmcd_pm"] = 0.1,
    ["wep_daun_hmcd_ptrd"] = 0.02, -- Anti-tank rifle very accurate
    ["wep_daun_hmcd_stg"] = 0.03,
    ["wep_daun_hmcd_ump"] = 0.1,
    ["wep_daun_hmcd_usp"] = 0.1,
    ["wep_jack_mded_assaultrifle"] = 0.1,
    ["wep_jack_mded_suppressed_p22"] = 0.12, -- Small caliber less accurate
    ["wep_jack_mded_suppressedrifle"] = 0.1,
    ["wep_mann_hmcd_ar2"] = 0.1,
    ["wep_mann_hmcd_db"] = 0.4, -- Shotgun
    ["wep_mann_hmcd_izhdb"] = 0.4, -- Shotgun
    ["wep_mann_hmcd_mateba"] = 0.08, -- Revolver accurate
    ["wep_mann_hmcd_pl_suppressed"] = 0.1,
    ["wep_mann_hmcd_pnevmat"] = 0.15, -- Air rifle less accurate
    ["wep_mann_hmcd_revolver_suppressed"] = 0.08, -- Revolver accurate
    ["wep_mann_hmcd_rifle_noscope"] = 0.1,
    ["wep_mann_hmcd_samopal"] = 0.15, -- SMG slightly less accurate
    ["wep_mann_hmcd_shorty"] = 0.2, -- Shotgun
    ["wep_nab_hmcd_batram"] = 0.2, -- Explosive less accurate
}

-- Shotgun pellet counts
MDHomicidePellets = {
    ["wep_jack_mded_shotgun"] = 8,
    ["wep_jack_mded_r870bag"] = 8,
    ["wep_mann_hmcd_spas"] = 8,
    ["wep_mann_hmcd_db"] = 8,
    ["wep_mann_hmcd_sg"] = 1,
    ["wep_mann_hmcd_izhdb"] = 8,
    ["wep_mann_hmcd_shorty"] = 8,
}

-- Non-lethal weapon configuration (true = non-lethal, false = lethal)
MDHomicideNonlethal = {
    ["wep_jack_mded_r870bag"] = true, -- Beanbag shotgun is non-lethal by default
}

-- Function to check if weapon is non-lethal
function GetMDHomicideNonlethal(weaponName)
    if MDHomicideNonlethal[weaponName] ~= nil then
        return MDHomicideNonlethal[weaponName]
    end
    
    -- Fallback to SWEP Nonlethal property
    local weapon = weapons.Get(weaponName)
    if weapon and weapon.Nonlethal ~= nil then
        return weapon.Nonlethal
    end
    
    return false -- Default to lethal
end

-- Function to get MDHomicide weapon damage (with fallback to SWEP)
function GetMDHomicideDamage(weaponName)
    if MDHomicideDamage[weaponName] then
        return MDHomicideDamage[weaponName]
    end
    
    -- Fallback to SWEP damage
    local weapon = weapons.Get(weaponName)
    if weapon and weapon.Damage then
        return weapon.Damage
    elseif weapon and weapon.Primary and weapon.Primary.Damage then
        return weapon.Primary.Damage
    end
    
    -- Default damage based on weapon type
    if string.find(weaponName, "shotgun") or string.find(weaponName, "spas") or string.find(weaponName, "_sg") then
        return 15 -- Per pellet for shotguns
    elseif string.find(weaponName, "sniper") or string.find(weaponName, "awp") or string.find(weaponName, "barrett") or string.find(weaponName, "mosin") then
        return 85 -- High damage for snipers
    elseif string.find(weaponName, "deagle") or string.find(weaponName, "revolver") or string.find(weaponName, "sw500") then
        return 50 -- High damage for heavy pistols
    elseif string.find(weaponName, "rifle") or string.find(weaponName, "ak") or string.find(weaponName, "m4") or string.find(weaponName, "scar") then
        return 35 -- Assault rifles
    elseif string.find(weaponName, "pistol") or string.find(weaponName, "glock") or string.find(weaponName, "beretta") then
        return 25 -- Pistols
    else
        return 30 -- Default
    end
end

-- Function to auto-detect if weapon is two-handed
function GetMDHomicideTwoHanded(weaponName)
    if MDHomicideTwoHanded[weaponName] ~= nil then
        return MDHomicideTwoHanded[weaponName]
    end
    
    -- Auto-detection based on weapon name patterns
    local pistolPatterns = {"pistol", "glock", "beretta", "deagle", "usp", "p99", "fnp45", "cz75", "revolver", "sw500", "makarov", "p22", "colt1911"}
    
    for _, pattern in ipairs(pistolPatterns) do
        if string.find(weaponName, pattern) then
            return false -- One-handed
        end
    end
    
    return true -- Default to two-handed for rifles, SMGs, shotguns, etc.
end