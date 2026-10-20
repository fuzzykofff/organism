-- Inventory Looting System - Proper VGUI Implementation with Performance Optimizations
local inventoryFrame = nil
local targetRagdoll = nil
local ragdollWeapons = {}
local showLootText = false
local lootTextAlpha = 0
local lastRagdollCheck = 0
local lastWeaponTake = 0
local currentRagdollOwner = nil

-- Performance optimization: Cache weapon icons and materials
local weaponIconCache = {}
local weaponMaterialCache = {}
local weaponNameCache = {}

-- Fonts
surface.CreateFont('InventoryTitle', {
    font = 'Coolvetica',
    size = 30,
    weight = 700,
    antialias = true,
})

surface.CreateFont('InventoryItem', {
    font = 'Coolvetica',
    size = 20,
    weight = 500,
    antialias = true,
})

surface.CreateFont('LootPrompt', {
    font = 'Coolvetica',
    size = 22,
    weight = 600,
    antialias = true,
})

-- Clear weapon caches for performance optimization
local function ClearWeaponCaches()
    weaponIconCache = {}
    weaponMaterialCache = {}
    weaponNameCache = {}
end


-- Check if player already has weapon
local function PlayerHasWeapon(weaponClass)
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    
    for _, weapon in pairs(ply:GetWeapons()) do
        if weapon:GetClass() == weaponClass then
            return true
        end
    end
    return false
end

-- Check if player is looking at a ragdoll within range (optimized frequency)
local function CheckRagdollInRange()
    if CurTime() - lastRagdollCheck < 0.2 then return end -- Reduced frequency for better performance
    lastRagdollCheck = CurTime()
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 150,
        filter = ply
    })
    
    if IsValid(tr.Entity) and tr.Entity:IsRagdoll() then
        local owner = tr.Entity:GetNWEntity('owner') or tr.Entity:GetNWEntity('deadbodyowner')
        if IsValid(owner) and owner:IsPlayer() then
            local distance = ply:GetPos():Distance(tr.Entity:GetPos())
            if distance <= 100 then
                -- Check if we're looking at a different ragdoll
                if targetRagdoll ~= tr.Entity then
                    if IsValid(inventoryFrame) then
                        inventoryFrame:Remove()
                        inventoryFrame = nil
                    end
                    ragdollWeapons = {}
                    currentRagdollOwner = nil
                    -- Clear caches when switching ragdolls
                    ClearWeaponCaches()
                end
                
                showLootText = true
                targetRagdoll = tr.Entity
                return true
            end
        end
    end
    
    showLootText = false
    if targetRagdoll ~= tr.Entity then
        if IsValid(inventoryFrame) then
            inventoryFrame:Remove()
            inventoryFrame = nil
        end
        targetRagdoll = nil
        ragdollWeapons = {}
        currentRagdollOwner = nil
        -- Clear caches when losing ragdoll target
        ClearWeaponCaches()
    end
    return false
end

-- Draw loot prompt text - updated to match image format
local function DrawLootPrompt()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetNWBool('radsfa') then
        lootTextAlpha = 0
        return
    end
    
    if not showLootText then
        lootTextAlpha = math.max(0, lootTextAlpha - FrameTime() * 500)
    else
        lootTextAlpha = math.min(255, lootTextAlpha + FrameTime() * 500)
    end
    
    if lootTextAlpha > 0 then
        local text = "[RMB+E] Loot"
        local textColor = Color(255, 255, 255, lootTextAlpha)
        local outlineColor = Color(0, 0, 0, lootTextAlpha * 0.7)
        local scrw, scrh = ScrW(), ScrH()
        local x, y = scrw/2, scrh/2 + 100
        
        -- Draw outline
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    draw.SimpleText(text, "LootPrompt", x + dx, y + dy, outlineColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
        
        -- Draw main text
        draw.SimpleText(text, "LootPrompt", x, y, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- Get weapon icon with proper fallback hierarchy and caching
local function GetWeaponIcon(weaponClass)
    -- Check cache first for performance
    if weaponIconCache[weaponClass] then
        return weaponIconCache[weaponClass]
    end
    
    local weaponTable = weapons.Get(weaponClass)
    
    -- First priority: weapon-specific icons
    if weaponTable then
        if weaponTable.IconOverride then
            local mat = Material(weaponTable.IconOverride)
            if mat and not mat:IsError() then
                weaponIconCache[weaponClass] = weaponTable.IconOverride
                return weaponTable.IconOverride
            end
        end
        
        if weaponTable.WepSelectIcon then
            local mat = Material(weaponTable.WepSelectIcon)
            if mat and not mat:IsError() then
                weaponIconCache[weaponClass] = weaponTable.WepSelectIcon
                return weaponTable.WepSelectIcon
            end
        end
    end
    
    -- Second priority: try various weapon icon paths
    local weaponIconPaths = {
        "weapons/" .. weaponClass,
        "weapons/" .. weaponClass .. ".png",
        "weapons/" .. weaponClass .. ".vmt",
        "vgui/weapons/" .. weaponClass,
        "vgui/weapons/" .. weaponClass .. ".vmt"
    }
    
    for _, path in ipairs(weaponIconPaths) do
        local mat = Material(path)
        if mat and not mat:IsError() then
            weaponIconCache[weaponClass] = path
            return path
        end
    end
    
    -- Third priority: try entity icons
    local entityIconPaths = {
        "entities/" .. weaponClass,
        "entities/" .. weaponClass .. ".png",
        "entities/" .. weaponClass .. ".vmt",
        "vgui/entities/" .. weaponClass,
        "vgui/entities/" .. weaponClass .. ".vmt",
        "materials/entities/" .. weaponClass .. ".png"
    }
    
    for _, path in ipairs(entityIconPaths) do
        local mat = Material(path)
        if mat and not mat:IsError() then
            weaponIconCache[weaponClass] = path
            return path
        end
    end
    
    -- Last resort: default weapon icon
    weaponIconCache[weaponClass] = "weapons/swep"
    return "weapons/swep"
end

-- Cache weapon materials for performance
local function GetCachedWeaponMaterial(weaponClass)
    if weaponMaterialCache[weaponClass] then
        return weaponMaterialCache[weaponClass]
    end
    
    local iconPath = GetWeaponIcon(weaponClass)
    local material = Material(iconPath)
    weaponMaterialCache[weaponClass] = material
    return material
end

-- Cache weapon names for performance
local function GetCachedWeaponName(weaponClass, weaponData)
    if weaponNameCache[weaponClass] then
        return weaponNameCache[weaponClass]
    end
    
    local weaponName = weaponData.name or weaponClass
    local weaponTable = weapons.Get(weaponClass)
    if weaponTable and weaponTable.PrintName then
        weaponName = weaponTable.PrintName
    end
    
    if string.len(weaponName) > 10 then
        weaponName = string.sub(weaponName, 1, 7) .. "..."
    end
    
    weaponNameCache[weaponClass] = weaponName
    return weaponName
end

-- Create inventory VGUI panel with proper GMod styling
local function CreateInventoryPanel()
    if IsValid(inventoryFrame) then
        inventoryFrame:Remove()
    end
    
    local scrw, scrh = ScrW(), ScrH()
    local panelW = scrw * 0.6
    local panelH = scrh * 0.7
    
    -- Create main frame with default GMod styling
    inventoryFrame = vgui.Create("DFrame")
    inventoryFrame:SetSize(panelW, panelH)
    inventoryFrame:Center()
    inventoryFrame:SetDraggable(true)
    inventoryFrame:SetDeleteOnClose(false)
    inventoryFrame:ShowCloseButton(true)
    inventoryFrame:SetSizable(false)
    
    -- Set title dynamically
    local owner = targetRagdoll:GetNWEntity('owner') or targetRagdoll:GetNWEntity('deadbodyowner')
    local titleText = "Unknown's Inventory"
    if IsValid(owner) then
        titleText = owner:Name() .. "'s Body"
    end
    inventoryFrame:SetTitle(titleText)
    
    -- Override paint to use grey theme with transparency
    inventoryFrame.Paint = function(self, w, h)
        -- Semi-transparent grey background
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 200))
        -- Title bar
        draw.RoundedBox(4, 0, 0, w, 24, Color(80, 80, 80, 220))
    end
    
    -- Create scrollable panel for items
    local scrollPanel = vgui.Create("DScrollPanel", inventoryFrame)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(10, 10, 10, 10)
    
    -- Create grid layout
    local itemSize = 64
    local itemSpacing = 8
    local itemsPerRow = math.floor((panelW - 60) / (itemSize + itemSpacing))
    
    local row = 0
    local col = 0
    
    for weaponClass, weaponData in pairs(ragdollWeapons) do
        -- Create item button with light grey styling
        local itemButton = vgui.Create("DButton", scrollPanel)
        itemButton:SetSize(itemSize, itemSize + 20)
        itemButton:SetPos(col * (itemSize + itemSpacing), row * (itemSize + itemSpacing + 30))
        itemButton:SetText("")
        
        -- Light grey button styling
        itemButton.Paint = function(self, w, h)
            local bgColor = Color(180, 180, 180, 255) -- Light grey
            if self:IsHovered() then
                bgColor = Color(220, 220, 100, 255) -- Light yellow on hover
            end
            if CurTime() - lastWeaponTake < 1.0 then
                bgColor = Color(150, 150, 150, 200) -- Darker grey during cooldown
            end
            
            draw.RoundedBox(2, 0, 0, w, h - 20, bgColor)
            draw.RoundedBox(2, 0, 0, w, h - 20, Color(100, 100, 100, 100)) -- Border
        end
        
        -- Cache weapon data when button is created for performance
        local cachedMaterial = GetCachedWeaponMaterial(weaponClass)
        local cachedWeaponName = GetCachedWeaponName(weaponClass, weaponData)
        local cachedFallbackText = nil
        
        -- Pre-calculate fallback text if material is invalid
        if not cachedMaterial or cachedMaterial:IsError() then
            local weaponTable = weapons.Get(weaponClass)
            if weaponTable and weaponTable.PrintName then
                cachedFallbackText = string.sub(weaponTable.PrintName, 1, 3):upper()
            else
                cachedFallbackText = string.sub(weaponClass, 1, 3):upper()
            end
        end
        
        -- Optimized PaintOver function using cached data
        itemButton.PaintOver = function(self, w, h)
            if cachedMaterial and not cachedMaterial:IsError() then
                surface.SetMaterial(cachedMaterial)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(4, 4, w - 8, h - 28)
            else
                -- Use pre-calculated fallback text
                draw.SimpleText(cachedFallbackText or "?", "InventoryItem", w/2, (h-20)/2, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            
            -- Use cached weapon name
            draw.SimpleText(cachedWeaponName, "DermaDefault", w/2, h - 10, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        -- Handle click
        itemButton.DoClick = function()
            local canTake = CurTime() - lastWeaponTake >= 1.0
            if not canTake then return end
            
            if PlayerHasWeapon(weaponClass) then
                chat.AddText(Color(255, 100, 100), "You already have this weapon")
            else
                net.Start("TakeWeaponFromRagdoll")
                net.WriteEntity(targetRagdoll)
                net.WriteString(weaponClass)
                net.SendToServer()
                
                -- Remove from local table and refresh panel
                ragdollWeapons[weaponClass] = nil
                lastWeaponTake = CurTime()
                
                -- Refresh the panel
                timer.Simple(0.1, function()
                    if IsValid(inventoryFrame) then
                        inventoryFrame:Remove()
                        inventoryFrame = nil
                        -- Clear caches when inventory changes
                        ClearWeaponCaches()
                        -- Request fresh inventory data
                        net.Start("RequestRagdollInventory")
                        net.WriteEntity(targetRagdoll)
                        net.SendToServer()
                    end
                end)
            end
        end
        
        -- Tooltip
        itemButton:SetTooltip(weaponData.name or weaponClass)
        
        col = col + 1
        if col >= itemsPerRow then
            col = 0
            row = row + 1
        end
    end
    
    -- Handle close
    inventoryFrame.OnClose = function()
        inventoryFrame = nil
        -- Clear caches when closing inventory
        ClearWeaponCaches()
    end
    
    inventoryFrame:MakePopup()
end





-- Network handlers
net.Receive("SendRagdollInventory", function()
    local weapons = net.ReadTable()
    ragdollWeapons = weapons
    
    -- Create the inventory panel when we receive the data
    if IsValid(targetRagdoll) and table.Count(ragdollWeapons) > 0 then
        CreateInventoryPanel()
    end
end)



-- Handle ragdoll head manipulation (keep existing functionality)
hook.Add("HUDPaint", "ManipulateRagdollHUDPaint", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local ragdoll = ply:GetNWEntity('player_ragdoll')
    if IsValid(ragdoll) then
        local headBoneIndex = ragdoll:LookupBone("ValveBiped.Bip01_Head1")
        if headBoneIndex then
            if ply:GetNWBool("radsfa") and not GetConVar('rads_thirdperson'):GetBool() then
                ragdoll:ManipulateBoneScale(headBoneIndex, Vector(0, 0, 0))
            else
                ragdoll:ManipulateBoneScale(headBoneIndex, Vector(1, 1, 1))
            end
        end
    end
end)

-- Main HUD paint hook - only for loot prompt now
hook.Add("HUDPaint", "InventoryLootingSystem", function()
    -- Don't run if spawnmenu is open
    if g_SpawnMenu and g_SpawnMenu:IsVisible() then return end
    
    -- Don't interfere with brain damage overlays
    local ply = LocalPlayer()
    if IsValid(ply) and ply.BrainDamageFXActive then
        -- Still allow loot checking but don't draw interface during brain damage
        CheckRagdollInRange()
        if not IsValid(inventoryFrame) then
            DrawLootPrompt()
        end
        return
    end
    
    CheckRagdollInRange()
    if not IsValid(inventoryFrame) then
        DrawLootPrompt()
    end
end)

-- Input handling - modified to use VGUI panels
hook.Add("Think", "InventoryLootingInput", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetNWBool('radsfa') then return end
    
    -- Don't open inventory during brain damage effects to prevent conflicts
    if ply.BrainDamageFXActive then
        if IsValid(inventoryFrame) then
            inventoryFrame:Remove()
            inventoryFrame = nil
        end
        return
    end
    
    -- Check if spawnmenu is open and disable our system
    if g_SpawnMenu and g_SpawnMenu:IsVisible() then
        if IsValid(inventoryFrame) then
            inventoryFrame:Remove()
            inventoryFrame = nil
        end
        return
    end
    
    local holdingRMB = input.IsMouseDown(MOUSE_RIGHT)
    local holdingE = input.IsKeyDown(KEY_E)
    
    if holdingRMB and holdingE and showLootText and IsValid(targetRagdoll) then
        if not IsValid(inventoryFrame) then
            -- Request inventory from server
            net.Start("RequestRagdollInventory")
            net.WriteEntity(targetRagdoll)
            net.SendToServer()
            
            currentRagdollOwner = targetRagdoll:GetNWEntity('owner') or targetRagdoll:GetNWEntity('deadbodyowner')
        end
    else
        if IsValid(inventoryFrame) then
            inventoryFrame:Remove()
            inventoryFrame = nil
        end
    end
end)