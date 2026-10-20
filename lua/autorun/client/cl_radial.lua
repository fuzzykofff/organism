-- Radial Menu System for CATSRAGDOLLSTABLEWORK
-- Standalone circular radial menu implementation

if SERVER then return end

-- Network message is handled on server side

-- Create fonts for the radial menu
surface.CreateFont("Radial_QM", {
	font = "Coolvetica",
	size = math.ceil(ScrW() / 38),
	weight = 500,
	antialias = true,
	italic = false
})

surface.CreateFont("RadialSmall_QM", {
	font = "Coolvetica",
	size = math.ceil(ScrW() / 80),
	weight = 100,
	antialias = true,
	italic = false
})

-- Radial menu variables
local ments = {}
local radialOpen = false
local prevSelected, prevSelectedVertex
local circleVertex
local fontHeight = draw.GetFontHeight("Radial_QM")
local tex = surface.GetTextureID("VGUI/white.vmt")

-- Open radial menu
local function OpenRadialMenu(elements)
	if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() then return end
	radialOpen = true
	gui.EnableScreenClicker(true)
	ments = elements or {}
	prevSelected = nil
	circleVertex = nil -- Reset circle vertex cache
end

-- Close radial menu
local function CloseRadialMenu()
	radialOpen = false
	gui.EnableScreenClicker(false)
end

-- Get selected menu item based on mouse position
local function getSelected()
	if #ments == 0 then return nil end
	
	local mx, my = gui.MousePos()
	local sw, sh = ScrW(), ScrH()
	local total = #ments
	local w = math.min(sw * 0.3, sh * 0.3)
	local sx, sy = sw / 2, sh / 2
	local x2, y2 = mx - sx, my - sy
	local dis = math.sqrt(x2 ^ 2 + y2 ^ 2)
	
	-- Check if mouse is within the circle
	if dis < 50 or dis > w then return nil end
	
	-- Calculate angle
	local ang = math.atan2(y2, x2)
	if ang < 0 then ang = ang + math.pi * 2 end
	
	-- Convert angle to menu item index
	local segmentSize = (math.pi * 2) / total
	local adjustedAngle = (ang + math.pi / 2) % (math.pi * 2)
	local selected = math.floor(adjustedAngle / segmentSize) + 1
	
	if selected > total then selected = 1 end
	return selected
end

-- Handle menu actions
local function executeAction(code)
	local lply = LocalPlayer()
	if not IsValid(lply) then return end
	
	if code == "drop" then
		lply:ConCommand("say *drop")
	elseif code == "unloadwep" then
		local wep = lply:GetActiveWeapon()
		if IsValid(wep) and wep:Clip1() > 0 then
			-- Send net message to server to handle unloading
			net.Start("RadialUnloadWeapon")
			net.SendToServer()
		end
	elseif code == "phrase" then
		-- Open phrase menu (placeholder)
		chat.AddText(Color(255, 255, 0), "[Phrase Menu] Feature coming soon!")
	elseif code == "suicide" then
		-- Trigger suicide command for compatible weapons
		lply:ConCommand("suicide")
	end
end

-- Add element to menu
local function addElement(elements, transCode, code)
	local t = {}
	t.TransCode = transCode
	t.Code = code
	table.insert(elements, t)
end

-- Build menu elements based on current weapon
local function buildMenuElements()
	local elements = {}
	local lply = LocalPlayer()
	if not IsValid(lply) then return elements end
	
	local wep = lply:GetActiveWeapon()
	
	-- Always available options
	addElement(elements, "Phrase", "phrase")
	
	-- Weapon-specific options
	if IsValid(wep) and wep:GetClass() ~= "weapon_physgun" and wep:GetClass() ~= "gmod_tool" then
		-- Don't allow dropping the hands weapon
		if wep:GetClass() ~= "wep_jack_hmcd_hands" then
			addElement(elements, "Drop Weapon", "drop")
		end
		
		if wep:Clip1() > 0 then
			addElement(elements, "Unload Weapon", "unloadwep")
		end
		
		-- Add suicide option only for weapons with suicide capability
		if wep.SuicidePos and wep.SuicideAng then
			addElement(elements, "Suicide", "suicide")
		end
	end
	
	return elements
end

-- Console command to toggle radial menu
concommand.Add("radial", function()
	local lply = LocalPlayer()
	if not IsValid(lply) or not lply:Alive() then return end
	
	-- Toggle radial menu
	if radialOpen then
		CloseRadialMenu()
	else
		local elements = buildMenuElements()
		if #elements > 0 then
			OpenRadialMenu(elements)
		end
	end
end)

-- Mouse input handling
hook.Add("GUIMousePressed", "RadialMenuMousePressed", function(mouseCode, aimVector)
	if not radialOpen then return end
	
	if mouseCode == MOUSE_LEFT then
		local selected = getSelected()
		if selected and ments[selected] then
			executeAction(ments[selected].Code)
		end
		CloseRadialMenu()
		return true
	elseif mouseCode == MOUSE_RIGHT then
		CloseRadialMenu()
		return true
	end
end)

-- Keyboard input handling
hook.Add("PlayerButtonDown", "RadialMenuKeyPressed", function(ply, button)
	if ply ~= LocalPlayer() or not radialOpen then return end
	
	if button == KEY_ESCAPE then
		CloseRadialMenu()
	end
end)

-- Note: Manual key binding required
-- Bind any key to 'radial' in console: bind q radial

-- Drawing variables
local tex = surface.GetTextureID("VGUI/white.vmt")
local circleVertex
local fontHeight = draw.GetFontHeight("Radial_QM")

-- Drawing helper function
local function drawShadow(text, font, x, y, color, align)
	draw.DrawText(text, font, x + 1, y + 1, color_black, align)
	draw.DrawText(text, font, x, y, color, align)
end

-- Draw the radial menu
local function DrawRadialMenu()
	if not radialOpen or #ments == 0 then return end
	
	local sw, sh = ScrW(), ScrH()
	local total = #ments
	local radius = math.min(sw * 0.3, sh * 0.3)
	local sx, sy = sw / 2, sh / 2
	local selected = getSelected()
	
	-- Create circle vertices if needed
	if not circleVertex then
		circleVertex = {}
		local segments = 64
		for i = 0, segments do
			local angle = (math.pi * 2) * i / segments
			local vx, vy = math.cos(angle), math.sin(angle)
			table.insert(circleVertex, {x = sx + radius * vx, y = sy + radius * vy})
		end
	end
	
	-- Draw background circle
	surface.SetTexture(tex)
	surface.SetDrawColor(30, 30, 30, 200)
	surface.DrawPoly(circleVertex)
	
	-- Draw menu segments
	for k, ment in pairs(ments) do
		local segmentAngle = (math.pi * 2) / total
		local startAngle = (k - 1) * segmentAngle - math.pi / 2
		local endAngle = k * segmentAngle - math.pi / 2
		
		-- Draw selection highlight
		if selected == k then
			local vertices = {}
			table.insert(vertices, {x = sx, y = sy})
			
			local segments = 16
			for i = 0, segments do
				local angle = startAngle + (endAngle - startAngle) * i / segments
				local vx, vy = math.cos(angle), math.sin(angle)
				table.insert(vertices, {x = sx + radius * vx, y = sy + radius * vy})
			end
			
			surface.SetTexture(tex)
			
			-- Color coding for different actions
			if ment.Code == "suicide" then
				surface.SetDrawColor(255, 50, 50, 150)
			elseif ment.Code == "drop" then
				surface.SetDrawColor(255, 150, 50, 150)
			elseif ment.Code == "unloadwep" then
				surface.SetDrawColor(255, 255, 50, 150)
			else
				surface.SetDrawColor(50, 150, 255, 150)
			end
			
			surface.DrawPoly(vertices)
		end
		
		-- Calculate text position
		local textAngle = startAngle + segmentAngle / 2
		local textRadius = radius * 0.65
		local textX = sx + math.cos(textAngle) * textRadius
		local textY = sy + math.sin(textAngle) * textRadius
		
		-- Determine text content
		local mainText, subText
		if ment.TransCode == "Drop Weapon" then
			mainText = "Drop"
			subText = "Weapon"
		elseif ment.TransCode == "Unload Weapon" then
			mainText = "Unload"
			subText = "Weapon"
		elseif ment.TransCode == "Phrase" then
			mainText = "Phrase"
			subText = "Menu"
		elseif ment.TransCode == "Suicide" then
			mainText = "Suicide"
			subText = ""
		else
			mainText = ment.TransCode or "?"
			subText = ""
		end
		
		-- Text color
		local textColor = selected == k and color_white or Color(200, 200, 200)
		
		-- Draw text
		drawShadow(mainText, "Radial_QM", textX, textY - fontHeight / 2, textColor, TEXT_ALIGN_CENTER)
		if subText ~= "" then
			drawShadow(subText, "RadialSmall_QM", textX, textY + fontHeight / 4, textColor, TEXT_ALIGN_CENTER)
		end
	end
	
	-- Draw center circle
	surface.SetDrawColor(50, 50, 50, 220)
	surface.SetTexture(tex)
	
	-- Create center circle vertices
	local centerVertices = {}
	local centerRadius = 40
	local segments = 32
	for i = 0, segments do
		local angle = (math.pi * 2) * i / segments
		local vx, vy = math.cos(angle), math.sin(angle)
		table.insert(centerVertices, {x = sx + centerRadius * vx, y = sy + centerRadius * vy})
	end
	
	surface.DrawPoly(centerVertices)
end

-- Hook into HUD painting
hook.Add("HUDPaint", "DrawRadialMenu", function()
	DrawRadialMenu()
end)

print("[CATSRAGDOLLSTABLEWORK] Radial menu system loaded!")