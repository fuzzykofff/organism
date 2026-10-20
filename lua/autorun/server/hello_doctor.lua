CreateConVar( "sv_no_spawn_sweps", "1", { FCVAR_ARCHIVE } ) 
hook.Add("PlayerLoadout", "NoWeaponsOnSpawn", function(ply)
    if GetConVarNumber( "sv_no_spawn_sweps" ) == 1 then
    ply:StripWeapons()
    return true
end
end)