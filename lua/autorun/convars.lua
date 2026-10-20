-- TRAUMA Configuration Variables
-- All settings are server-side only and can only be changed by server administrators

if SERVER then
    -- Core System Settings
    CreateConVar("rads_status", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable or disable the entire TRAUMA system")
    CreateConVar("rads_enablekill", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Allow players to be killed by the system")
    CreateConVar("rads_player_health", "300", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Default player health on spawn")
    -- rads_cheapeffects moved to client-side
    
    -- Fall and Ragdoll System
    CreateConVar("rads_fallchance", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable the custom fall chance system")
    CreateConVar("rads_ragonfall", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable ragdoll state when players fall")
    CreateConVar("rads_fallonspeedlimit", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable ragdoll when player velocity exceeds threshold")
    CreateConVar("rads_fallonspeedlimit_threshold", "900", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Velocity threshold for ragdoll activation (units per second)")
    CreateConVar("rads_fallwhengrabbed", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Allow players to fall when grabbed by a ragdoll")
    CreateConVar("rads_firefall", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable falling when taking damage from gunfire")
    CreateConVar("rads_fallonclub", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable falling when taking melee damage")
    CreateConVar("rads_randomfallfromclub", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Add randomness to melee damage falls")
    CreateConVar("rads_allow_fov_change", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Allow players to change their FOV (admin only setting)")
    
    -- Damage and Physics
    CreateConVar("rads_realisticdmg", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable realistic fall damage calculations")
    CreateConVar("rads_physdmg", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable physical damage from falls")
    CreateConVar("rads_scalefalldmg", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Multiplier for fall damage scaling")
    CreateConVar("rads_propknock", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable prop knockdown system")
    
    -- Pain and Audio System (DISABLED - Pain sounds and indicators are permanently disabled)
    CreateConVar("rads_painstatus", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable the pain system")
    CreateConVar("rads_painsounds", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable pain sound effects (DISABLED)")
    CreateConVar("rads_painlimit", "190", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Maximum pain threshold before effects trigger")
    CreateConVar("rads_drawpain", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Display pain indicators on screen (DISABLED)")
    
    -- Movement and Interaction
    CreateConVar("rads_pullupspeed", "30", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Speed multiplier for pull-up actions")
    CreateConVar("rads_handspeed", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Speed multiplier for hand movements")
    CreateConVar("rads_righthandlimit", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Force limit for right hand grip (0 = unlimited)")
    CreateConVar("rads_lefthandlimit", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Force limit for left hand grip (0 = unlimited)")
    CreateConVar("rads_doorbreach", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable door breaching while in ragdoll state")
    CreateConVar("rads_movement_enabled", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable/disable the RADS movement and stamina system")
    
    -- Timer and Performance
    CreateConVar("rads_timer", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable the RADS timer system")
    CreateConVar("rads_adjusttimer", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Allow automatic timer adjustments")
    CreateConVar("rads_vehicleragspeed", "15", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Minimum speed for vehicle-induced ragdoll")
    
    -- Bone and Body System
    CreateConVar("rads_bones", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable bone damage system")
    
    -- Blood and Effects
    CreateConVar("rads_bloodlimit", "2500", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Blood limit, Below this value will cause the player to go comatose.")
    
    -- Gore System
    CreateConVar("rads_gore_enable", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable or disable the gore system")
    CreateConVar("rads_gore_head_damage_threshold", "150", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Damage threshold for head explosion gore effect")
    CreateConVar("rads_gore_blood_duration", "30", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Duration of blood stream from gore stump in seconds")
    
    -- Epilepsy and Medical Effects
    CreateConVar("rads_mineptime", "10", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Minimum duration for epilepsy effects (seconds)")
    CreateConVar("rads_maxeptime", "25", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Maximum duration for epilepsy effects (seconds)")
    
    -- Weapon and Loadout System
    CreateConVar("rads_loadoutusinglua", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Use Lua-based weapon loadout system")
    CreateConVar("rads_fists_on_spawn", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Give hands weapon on spawn and prevent dropping")
    CreateConVar("rads_replace_health_items", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Replace HL2 health items with TRAUMA medical items")
    
    -- Gamemode Compatibility
    CreateConVar("rads_spectatorfix", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable spectator fixes for Murder and other gamemodes")
    
    -- Shock System
    CreateConVar("rads_shock_enable", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable the shock system")
    CreateConVar("rads_shock_decay_rate", "0.5", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Rate at which shock decays per second")
    CreateConVar("rads_shock_blood_threshold", "15", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Blood loss percentage that triggers shock")
    CreateConVar("rads_shock_pain_threshold", "150", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Pain level that triggers shock")
    CreateConVar("rads_shock_fall_threshold", "600", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Fall damage speed that triggers shock")
    CreateConVar("rads_shock_explosion_range", "300", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Range for explosion-induced shock")
    CreateConVar("rads_tinnitus_explosions", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable tinnitus effects from nearby explosions")
    CreateConVar("rads_shock_muffled_threshold", "30", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Shock level for muffled sound effects")
    CreateConVar("rads_shock_ragdoll_threshold", "60", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Shock level for forced ragdoll state")
    CreateConVar("rads_shock_movement_threshold", "45", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Shock level for movement penalties")
    CreateConVar("rads_shock_visual_intensity", "1.0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Intensity multiplier for shock visual effects")
    
    -- Fear System
    CreateConVar("rads_fear_enable", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable the fear system")
    CreateConVar("rads_fear_decay_rate", "1.0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Rate at which fear decays per second")
    CreateConVar("rads_fear_damage_multiplier", "0.8", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Multiplier for fear gained from damage")
    CreateConVar("rads_fear_velocity_threshold", "800", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Velocity threshold that triggers fear")
    CreateConVar("rads_fear_explosion_range", "400", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Range for explosion-induced fear")
    CreateConVar("rads_fear_pain_threshold", "100", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Pain level that triggers fear")
    CreateConVar("rads_fear_vignette_intensity", "1.0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Intensity multiplier for fear vignette effect")
    CreateConVar("rads_fear_adrenaline_multiplier", "0.5", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Multiplier for adrenaline gained from fear")
    
    -- Drowning System
    CreateConVar("rads_drowning_enable", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable the drowning system for ragdolls")
    CreateConVar("rads_drowning_threshold_time", "20", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Time in seconds before drowning starts when submerged")
    CreateConVar("rads_drowning_death_time", "60", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Time in seconds of drowning before death")
    CreateConVar("rads_drowning_o2_reduction_rate", "1.67", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Oxygen reduction rate per second during drowning")
    CreateConVar("rads_drowning_fear_multiplier", "2.0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Fear multiplier during drowning")
    CreateConVar("rads_drowning_sound_volume", "0.8", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Volume of drowning sound effects")
    CreateConVar("rads_drowning_sink_force", "500", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Force applied to make ragdolls sink in water")
    CreateConVar("rads_drowning_swim_force", "1000", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Force applied when swimming with LMB+RMB")
    
    -- Consciousness and Get-Up System
    CreateConVar("rads_disable_consciousness", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Disable consciousness loss system - players will not go unconscious")
    CreateConVar("rads_instant_getup", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable instant get up from ragdoll - bypasses get up process but respects blocking conditions")
    
    -- Wind Sound System
    CreateConVar("rads_wind_sounds", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable wind sound effects based on player velocity")
    
    -- Death Camera System
    CreateConVar("rads_death_firstperson", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Keep first-person view when player dies (similar to ragdoll view)")
    
    -- Consciousness Timer System
    CreateConVar("rads_consciousness_timer", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable consciousness timer UI when unconscious")
    
    -- Death State System
    CreateConVar("rads_death_state", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Enable death state functionality - players enter death state when critically injured")
    
    -- Camera and View Settings moved to client-side
    
    -- Client View Settings (Server-controlled)
    CreateConVar("rads_thirdperson", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "OBSOLETE, DONT USE")
    CreateConVar("rads_disablelerp", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "OBSOLETE, DONT USE")
    -- rads_draworg moved to client-side
    CreateConVar("rads_viewmode", "1", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "OBSOLETE, DONT USE")
    CreateConVar("rads_viewfov", "100", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "OBSOLETE, DONT USE")
    CreateConVar("rads_mouthscale", "6", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "OBSELETE, DONT USE")
    CreateConVar("rads_drawmotd", "0", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "OBSELETE, DONT USE")

    
    -- Force pain sounds and indicators to stay disabled
    timer.Create("RADS_ForcePainDisabled", 1, 0, function()
        local painSoundsConVar = GetConVar("rads_painsounds")
        local drawPainConVar = GetConVar("rads_drawpain")
        
        if painSoundsConVar and painSoundsConVar:GetInt() ~= 0 then
            painSoundsConVar:SetInt(0)
        end
        
        if drawPainConVar and drawPainConVar:GetInt() ~= 0 then
            drawPainConVar:SetInt(0)
        end
    end)
end

if CLIENT then
    -- Client-side convars that each player can control individually
    CreateClientConVar("rads_draworg", "0", true, false, "Show debug organ information")
    CreateClientConVar("rads_cheapeffects", "0", true, false, "Enable performance mode - disables intensive visual effects like radial blur")
    
    -- Camera and View Settings (Client-side)
    CreateClientConVar("rads_ragdoll_fov", "100", true, false, "Field of view for ragdoll camera (calcview)")
    CreateClientConVar("rads_player_fov", "100", true, false, "Field of view for standing player")
    
    -- Consciousness Timer (Client-side)
    CreateClientConVar("rads_consciousness_timer_client", "1", true, false, "Enable consciousness timer UI display on client")
    
    -- Function to reset all convars to their default values
    local function ResetToDefaults(convars)
        for convar, defaultValue in pairs(convars) do
            RunConsoleCommand(convar, tostring(defaultValue))
        end
        chat.AddText(Color(0, 255, 0), "[TRAUMA] ", Color(255, 255, 255), "Settings reset to default values.")
    end
    
    hook.Add("PopulateToolMenu", "TRAUMA_AdminMenu", function()
        -- Core System Settings
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "CoreSystem", "Core System", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Core System Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Enable TRAUMA System",
                Command = "rads_status"
            })
            panel:Help("Enables or disables the entire TRAUMA system. When disabled, all TRAUMA features are turned off.")
            
            panel:AddControl("CheckBox", {
                Label = "Allow player suicide during unconscious",
                Command = "rads_enablekill"
            })
            panel:Help("Allows players to kill themselves while unconscious/ragdolled using the kill command.")
            
            panel:AddControl("CheckBox", {
                Label = "Disable Consciousness Loss",
                Command = "rads_disable_consciousness"
            })
            panel:Help("Disables the consciousness loss system - players will not go unconscious from low consciousness.")
            
            panel:AddControl("CheckBox", {
                Label = "Instant Get Up",
                Command = "rads_instant_getup"
            })
            panel:Help("Enables instant get up from ragdoll - bypasses get up process but respects all blocking conditions.")
            
            panel:NumSlider("Default Player Health", "rads_player_health", 50, 1000, 0)
            panel:Help("Sets the default health value for players when they spawn.")
            
         
           
            
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_status"] = 1,
                    ["rads_enablekill"] = 1,
                    ["rads_disable_consciousness"] = 0,
                    ["rads_instant_getup"] = 0,
                    ["rads_player_health"] = 300,
                    ["rads_cheapeffects"] = 0,

                    ["rads_draworg"] = 0,
                    ["rads_drawmotd"] = 1,
                    ["rads_thirdperson"] = 0,
                    ["rads_disablelerp"] = 0,
                    ["rads_viewmode"] = 1,
                    ["rads_viewfov"] = 100,
                    ["rads_mouthscale"] = 6
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- Fall and Ragdoll Settings
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "FallRagdoll", "Fall & Ragdoll", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Fall and Ragdoll Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Enable Fall Chance System",
                Command = "rads_fallchance"
            })
            panel:Help("Enables the custom fall chance system that determines when players fall based on various conditions.")
            
            panel:AddControl("CheckBox", {
                Label = "Fall at High Speed",
                Command = "rads_fallonspeedlimit"
            })
            panel:Help("Makes players ragdoll when their velocity is high.")
            
            panel:AddControl("CheckBox", {
                Label = "Fall When Grabbed",
                Command = "rads_fallwhengrabbed"
            })
            panel:Help("Allows players to fall and ragdoll when grabbed by another ragdolled player.")
            
            panel:AddControl("CheckBox", {
                Label = "Fall from Melee Damage",
                Command = "rads_fallonclub"
            })
            panel:Help("Enables Ragdolling from club damage.")
            
            panel:AddControl("CheckBox", {
                Label = "Random Melee Falls",
                Command = "rads_randomfallfromclub"
            })
            panel:Help("Club damage can cause the victim to randomly ragdoll.")
            
            panel:NumSlider("Vehicle Ragdoll Speed", "rads_vehicleragspeed", 5, 50, 0)
            panel:Help("Speed threshold for vehicle-related ragdoll effects.")
            
            panel:NumSlider("Velocity Ragdoll Threshold", "rads_fallonspeedlimit_threshold", 100, 2000, 0)
            panel:Help("Velocity threshold for ragdoll activation when speed limit is reached (units per second).")
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_fallchance"] = 1,
                    ["rads_fallonspeedlimit"] = 1,
                    ["rads_fallonspeedlimit_threshold"] = 900,
                    ["rads_fallwhengrabbed"] = 1,
                    ["rads_fallonclub"] = 1,
                    ["rads_randomfallfromclub"] = 1,
                    ["rads_vehicleragspeed"] = 15
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- Damage and Physics Settings
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "DamagePhysics", "Damage & Physics", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Damage and Physics Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Realistic Fall Damage",
                Command = "rads_realisticdmg"
            })
            panel:Help("Enables realistic fall damage.")
            
            
            panel:NumSlider("Fall Damage Scale", "rads_scalefalldmg", 0.1, 5.0, 1)
            panel:Help("Multiplier for fall damage scaling. Higher values make falls more deadly.")
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_realisticdmg"] = 1,
                    ["rads_propknock"] = 1,
                    ["rads_bones"] = 1,
                    ["rads_scalefalldmg"] = 1
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- Pain and Audio Settings
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "PainAudio", "Pain & Blood", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Pain and Blood Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Enable Pain System",
                Command = "rads_painstatus"
            })
            panel:Help("Enables the pain system which tracks player pain levels and applies effects.")
            
            
            panel:NumSlider("Pain Threshold", "rads_painlimit", 50, 500, 0)
            panel:Help("Maximum pain threshold, After passing the threshold the player will start to lose consciousness..")
            
            panel:NumSlider("Blood Loss Limit", "rads_bloodlimit", 100, 5000, 0)
            panel:Help("Blood loss limit, the player will go comatose if their blood volume is lower than the limit.")
            
            -- Gore System Settings
            panel:AddControl("Header", {Text = "Gore System Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Enable Gore System",
                Command = "rads_gore_enable"
            })
            panel:Help("Enables the gore system with head explosions and blood effects.")
            
            panel:NumSlider("Head Explosion Damage Threshold", "rads_gore_head_damage_threshold", 50, 500, 0)
            panel:Help("Damage threshold required to trigger head explosion gore effect.")
            
            panel:NumSlider("Blood Stream Duration (seconds)", "rads_gore_blood_duration", 5, 120, 0)
            panel:Help("Duration of blood stream from gore stump in seconds.")
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_painstatus"] = 1,
                    ["rads_painsounds"] = 0,
                    ["rads_drawpain"] = 0,
                    ["rads_painlimit"] = 190,
                    ["rads_bloodlimit"] = 2500,
                    ["rads_gore_enable"] = 1,
                    ["rads_gore_head_damage_threshold"] = 150,
                    ["rads_gore_blood_duration"] = 30
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- Movement and Interaction Settings
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "Movement", "Movement & Interaction", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Movement and Interaction Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Door Breaching in Ragdoll",
                Command = "rads_doorbreach"
            })
            panel:Help("Allows players to breach and break down doors while in ragdoll state.")
            
            panel:AddControl("CheckBox", {
                Label = "Movement & Stamina System",
                Command = "rads_movement_enabled"
            })
            panel:Help("Enables the advanced movement and stamina system with realistic movement speeds and stamina consumption.")
            
            panel:AddControl("CheckBox", {
                Label = "Give Hands on Spawn",
                Command = "rads_fists_on_spawn"
            })
            panel:Help("Automatically gives players the hands weapon on spawn and prevents them from dropping it.")
            
            panel:AddControl("CheckBox", {
                Label = "Replace HL2 Health Items with Medical Items",
                Command = "rads_replace_health_items"
            })
            panel:Help("When enabled, replaces default HL2 health items with TRAUMA medical items (bandages, medkits, painkillers).")
            
            panel:NumSlider("Pull-up Speed", "rads_pullupspeed", 10, 150, 0)
            panel:Help("Speed multiplier for grapple, the higher the faster.")
            
            
            panel:NumSlider("Right Hand Force Limit", "rads_righthandlimit", 0, 20000, 0)
            panel:Help("Force limit for right hand grip strength. 0 = unlimited force.")
            
            panel:NumSlider("Left Hand Force Limit", "rads_lefthandlimit", 0, 20000, 0)
            panel:Help("Force limit for left hand grip strength. 0 = unlimited force.")
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_doorbreach"] = 1,
                    ["rads_movement_enabled"] = 0,
                    ["rads_fists_on_spawn"] = 1,
                    ["rads_replace_health_items"] = 1,
                    ["rads_pullupspeed"] = 30,
                    ["rads_handspeed"] = 1,
                    ["rads_righthandlimit"] = 0,
                    ["rads_lefthandlimit"] = 0
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- Shock System Settings
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "ShockSystem", "Shock System", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Shock System Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Enable Shock System",
                Command = "rads_shock_enable"
            })
            panel:Help("Enables the shock system which simulates traumatic shock from injuries and blood loss.")
            
            panel:NumSlider("Shock Decay Rate", "rads_shock_decay_rate", 0.1, 2.0, 1)
            panel:Help("Rate at which shock levels naturally decay over time (per second).")
            
            panel:NumSlider("Blood Loss Threshold (%)", "rads_shock_blood_threshold", 5, 50, 0)
            panel:Help("Percentage of blood loss required to trigger shock effects.")
            
            panel:NumSlider("Pain Threshold", "rads_shock_pain_threshold", 50, 500, 0)
            panel:Help("Pain level required to trigger shock from pain alone.")
            
            panel:NumSlider("Fall Damage Threshold", "rads_shock_fall_threshold", 200, 1500, 0)
            panel:Help("Fall damage speed threshold that triggers shock from impact trauma.")
            
            panel:NumSlider("Explosion Range", "rads_shock_explosion_range", 100, 1000, 0)
            panel:Help("Range within which explosions can cause shock effects.")
            
            panel:AddControl("CheckBox", {
                Label = "Enable Explosion Tinnitus",
                Command = "rads_tinnitus_explosions"
            })
            panel:Help("Enables tinnitus effects from nearby explosions. Duration is based on proximity to explosion (max 50 seconds).")
            
            panel:NumSlider("Muffled Sound Threshold", "rads_shock_muffled_threshold", 10, 80, 0)
            panel:Help("Shock level at which sound becomes muffled and distorted.")
            
            panel:NumSlider("Ragdoll Threshold", "rads_shock_ragdoll_threshold", 30, 90, 0)
            panel:Help("Shock level that forces players into ragdoll state.")
            
            panel:NumSlider("Movement Penalty Threshold", "rads_shock_movement_threshold", 20, 80, 0)
            panel:Help("Shock level at which movement speed penalties begin to apply.")
            
            panel:NumSlider("Visual Effect Intensity", "rads_shock_visual_intensity", 0.1, 3.0, 1)
            panel:Help("Intensity multiplier for shock-related visual effects like screen distortion.")
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_shock_enable"] = 1,
                    ["rads_shock_decay_rate"] = 0.5,
                    ["rads_shock_blood_threshold"] = 15,
                    ["rads_shock_pain_threshold"] = 150,
                    ["rads_shock_fall_threshold"] = 600,
                    ["rads_shock_explosion_range"] = 300,
                    ["rads_tinnitus_explosions"] = 1,
                    ["rads_shock_muffled_threshold"] = 30,
                    ["rads_shock_ragdoll_threshold"] = 60,
                    ["rads_shock_movement_threshold"] = 45,
                    ["rads_shock_visual_intensity"] = 1.0
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- Fear System Settings
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "FearSystem", "Fear System", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Fear System Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Enable Fear System",
                Command = "rads_fear_enable"
            })
            panel:Help("Enables the fear system which simulates psychological fear from trauma, damage, and dangerous situations.")
            
            panel:NumSlider("Fear Decay Rate", "rads_fear_decay_rate", 0.1, 5.0, 1)
            panel:Help("Rate at which fear levels naturally decay over time (per second).")
            
            panel:NumSlider("Damage Fear Multiplier", "rads_fear_damage_multiplier", 0.1, 5.0, 1)
            panel:Help("Multiplier for fear gained from taking damage.")
            
            panel:NumSlider("Velocity Threshold", "rads_fear_velocity_threshold", 100, 2000, 0)
            panel:Help("Velocity threshold above which high-speed impacts cause fear.")
            
            panel:NumSlider("Explosion Fear Range", "rads_fear_explosion_range", 100, 1500, 0)
            panel:Help("Range within which explosions can cause fear effects.")
            

            
            panel:NumSlider("Pain Fear Threshold", "rads_fear_pain_threshold", 50, 500, 0)
            panel:Help("Pain level required to trigger fear from pain alone.")
            
            panel:NumSlider("Vignette Intensity", "rads_fear_vignette_intensity", 0.1, 3.0, 1)
            panel:Help("Intensity multiplier for fear-related vignette effects.")
            
            panel:NumSlider("Adrenaline Multiplier", "rads_fear_adrenaline_multiplier", 0.1, 3.0, 1)
            panel:Help("Multiplier for adrenaline gained from fear levels.")
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_fear_enable"] = 1,
                    ["rads_fear_decay_rate"] = 1.0,
                    ["rads_fear_damage_multiplier"] = 1.5,
                    ["rads_fear_velocity_threshold"] = 500,
                    ["rads_fear_explosion_range"] = 400,

                    ["rads_fear_pain_threshold"] = 100,
                    ["rads_fear_vignette_intensity"] = 1.0,
                    ["rads_fear_adrenaline_multiplier"] = 0.5
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- System and Compatibility Settings
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "System", "System & Compatibility", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "System and Compatibility Settings"})
            
            panel:AddControl("CheckBox", {
                Label = "Enable Timer System",
                Command = "rads_timer"
            })
            panel:Help("i forgot what this was for")
            
            panel:AddControl("CheckBox", {
                Label = "Enable Wind Sounds",
                Command = "rads_wind_sounds"
            })
            panel:Help("Enables wind sound effects based on high player velocity.")
            
            panel:AddControl("CheckBox", {
                Label = "Enable Consciousness Timer",
                Command = "rads_consciousness_timer"
            })
            panel:Help("Shows a circular timer UI when unconscious that indicates time until regaining consciousness.")
            
            panel:AddControl("CheckBox", {
                Label = "Enable Death State System",
                Command = "rads_death_state"
            })
            panel:Help("Enables the death state system where critically injured players enter a 19-second death state before dying.")


            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_timer"] = 1,
                    ["rads_adjusttimer"] = 1,
                    ["rads_loadoutusinglua"] = 1,
                    ["rads_spectatorfix"] = 0,
                    ["rads_wind_sounds"] = 1,
                    ["rads_consciousness_timer"] = 1,
                    ["rads_death_state"] = 1
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- Admin Settings (Admin-only controls)
        spawnmenu.AddToolMenuOption("TRAUMA", "Server Settings", "AdminControls", "Admin Controls", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Admin Control Settings"})
            panel:Help("These settings can only be changed by server administrators.")
            
            panel:AddControl("CheckBox", {
                Label = "Allow Players to Change FOV",
                Command = "rads_allow_fov_change"
            })
            panel:Help("When disabled, prevents players from changing their field of view settings.")
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                ResetToDefaults({
                    ["rads_allow_fov_change"] = 1
                })
            end
            panel:AddItem(resetBtn)
        end)
        
        -- Client Settings (Player-specific settings)
        spawnmenu.AddToolMenuOption("TRAUMA", "Client Settings", "ClientFOV", "Field of View", "", "", function(panel)
            panel:ClearControls()
            panel:AddControl("Header", {Text = "Field of View Settings"})
            panel:Help("These settings are client-side and only affect your own view.")
            
            -- Check if FOV changes are allowed
            local allowFOVChange = GetConVar("rads_allow_fov_change"):GetBool()
            
            if allowFOVChange then
                panel:NumSlider("Standing Player FOV", "rads_player_fov", 50, 150, 0)
                panel:Help("Field of view for standing/alive player camera.")
                
                panel:NumSlider("Ragdoll Camera FOV", "rads_ragdoll_fov", 50, 150, 0)
                panel:Help("Field of view for ragdoll camera view.")
            else
                panel:Help("FOV changes have been disabled by the server administrator.")
            end
            
            -- Reset to Defaults button
            local resetBtn = vgui.Create("DButton")
            resetBtn:SetText("Reset FOV to Defaults")
            resetBtn:SetSize(150, 25)
            resetBtn.DoClick = function()
                RunConsoleCommand("rads_player_fov", "100")
                RunConsoleCommand("rads_ragdoll_fov", "100")
                chat.AddText(Color(0, 255, 0), "[TRAUMA] ", Color(255, 255, 255), "FOV settings reset to default values.")
            end
            panel:AddItem(resetBtn)
        end)

    end)
end
