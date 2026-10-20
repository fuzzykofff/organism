-- Network string registration for RADS medical system
if SERVER then
    -- Register network strings for pain updates
    util.AddNetworkString('RADS_PainUpdate')
    
    -- Register user messages for boost effects
    util.AddNetworkString('HMCD_FoodBoost')
    util.AddNetworkString('HMCD_PainBoost')
    
    -- Register network strings for stamina updates
    util.AddNetworkString('RADS_StaminaUpdate')
    
    -- Register network strings for view punch effects
    util.AddNetworkString('RADS_ViewPunch')
    
    -- Register network strings for name display system
    util.AddNetworkString('RADS_NameDisplay_UpdateColor')
    util.AddNetworkString('RADS_NameDisplay_UpdateName')
    
    -- Register network strings for death state system
    util.AddNetworkString('RADS_DeathState')
    util.AddNetworkString('RADS_ConsciousnessTimer')
    util.AddNetworkString('RADS_NeckBreak')
end