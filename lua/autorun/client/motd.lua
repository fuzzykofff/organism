local scrw, scrh = ScrW(), ScrH()
local function CreateMainMenu()
    local frame = vgui.Create("DFrame")
    frame:SetSize(scrw * 0.9, scrh * 0.9)
    frame:SetTitle("")
    frame:Center()
    frame:ShowCloseButton(false)
    frame:MakePopup()
    local bgColor = Color(40, 40, 40, 200)
    local titleColor = Color(255, 255, 255)
    local btnColor = Color(100, 100, 100)
    frame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, bgColor) end
    local htmlPanel = vgui.Create("DHTML", frame)
    htmlPanel:SetSize(frame:GetWide() - 20, frame:GetTall() - 60)
    htmlPanel:SetPos(10, 50)
    htmlPanel:OpenURL("https://desync995.github.io/radsweb.github.io/")
    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("X")
    closeButton:SetTextColor(titleColor)
    closeButton:SetPos(frame:GetWide() - 100, 10)
    closeButton:SetSize(60, 30)
    closeButton.Paint = function(self, w, h) draw.RoundedBox(16, 0, 0, w, h, btnColor) end
    closeButton.DoClick = function() frame:Close() end
end

hook.Add("OnPlayerChat", "openmainmenu", function(ply, strText, bTeam, bDead)
    if ply ~= LocalPlayer() then return end
    strText = string.lower(strText)
    if strText == "!rads" then CreateMainMenu() end
end)

hook.Add("InitPostEntity", "AutoOpenMainMenu", function() timer.Simple(1, function() if GetConVar('rads_drawmotd'):GetBool() then CreateMainMenu() end end) end)
local scrw, scrh = ScrW(), ScrH()
local function CreateMainMenu()
    local frame = vgui.Create("DFrame")
    frame:SetSize(scrw * 0.9, scrh * 0.9)
    frame:SetTitle("")
    frame:Center()
    frame:ShowCloseButton(false)
    frame:MakePopup()
    local bgColor = Color(40, 40, 40, 200)
    local titleColor = Color(255, 255, 255)
    local btnColor = Color(100, 100, 100)
    frame.Paint = function(self, w, h) draw.RoundedBox(8, 0, 0, w, h, bgColor) end
    local htmlPanel = vgui.Create("DHTML", frame)
    htmlPanel:SetSize(frame:GetWide() - 20, frame:GetTall() - 60)
    htmlPanel:SetPos(10, 50)
    htmlPanel:OpenURL("https://desync995.github.io/radsweb.github.io/")
    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("X")
    closeButton:SetTextColor(titleColor)
    closeButton:SetPos(frame:GetWide() - 100, 10)
    closeButton:SetSize(60, 30)
    closeButton.Paint = function(self, w, h) draw.RoundedBox(16, 0, 0, w, h, btnColor) end
    closeButton.DoClick = function() frame:Close() end
end

hook.Add("OnPlayerChat", "openmainmenu", function(ply, strText, bTeam, bDead)
    if ply ~= LocalPlayer() then return end
    strText = string.lower(strText)
    if strText == "!rads" then CreateMainMenu() end
end)

hook.Add("InitPostEntity", "AutoOpenMainMenu", function() timer.Simple(1, function() if GetConVar('rads_drawmotd'):GetBool() then CreateMainMenu() end end) end)
local function CreateRadsMenu()
    local y_offset = 30
    local frame = vgui.Create("DFrame")
    frame:SetSize(900, 600)
    frame:SetTitle("RADS Settings")
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:Center()
    frame:MakePopup()
    local function DrawBlur(panel, amount)
        local x, y = panel:LocalToScreen(0, 0)
        local w, h = panel:GetSize()
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material("pp/blurscreen"))
        for i = 1, 3 do
            Material("pp/blurscreen"):SetFloat("$blur", (i / 3) * (amount or 6))
            Material("pp/blurscreen"):Recompute()
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
        end
    end

    frame.Paint = function(self, w, h)
        DrawBlur(self, 10)
        draw.RoundedBox(6, 0, 0, w, h, Color(70, 54, 70, 200))
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(FILL)
    layout:SetSpaceY(5)
    local function AddCheckBox(parent, label, convar)
        local checkbox = vgui.Create("DCheckBoxLabel", parent)
        checkbox:SetText(label)
        checkbox:SetConVar(convar)
        checkbox:SetPos(10, 30)
        checkbox:SetSize(200, 20)
        checkbox:SetDark(true)
        checkbox:SetTextColor(Color(255, 255, 255))
        layout:Add(checkbox)
        checkbox.Button.OnMousePressed = function(btn, mc)
            btn:SetChecked(not btn:GetChecked())
            RunConsoleCommand(convar, btn:GetChecked() and 1 or 0)
        end

        checkbox.Button.Paint = function(self, w, h)
            local color = checkbox:GetChecked() and Color(0, 255, 0) or Color(255, 0, 0)
            draw.RoundedBox(4, 0, 0, w, h, color)
        end
    end

    AddCheckBox(layout, "Enable Script", "rads_status")
    AddCheckBox(layout, "Kill Status", "rads_enablekill")
    AddCheckBox(layout, "SuperSus", "rads_supersus")
    AddCheckBox(layout, "Phys Dmg", "rads_physdmg")
    AddCheckBox(layout, "Fall on Club Dmg", "rads_fallonclub")
    AddCheckBox(layout, "Ragdoll on High Speed (900 units)", "rads_fallonspeedlimit")
    AddCheckBox(layout, "Door Breaching", "rads_doorbreach")
    AddCheckBox(layout, "Fall when Damaged", "rads_fallchance")
    AddCheckBox(layout, "Prop Knock System", "rads_propknock")
    AddCheckBox(layout, "Ragdoll on Fall", "rads_ragonfall")
    AddCheckBox(layout, "Fall when Grabbed by Ragdoll", "rads_fallwhengrabbed")
    -- Shooting in Ragdoll checkbox removed - now always enabled
    local function AddSlider(parent, text, convar, min, max)
        local slider = vgui.Create("DNumSlider", parent)
        slider:SetText(text)
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetDecimals(0)
        slider:SetConVar(convar)
        layout:Add(slider)
    end

    AddSlider(layout, "Right Hand Force Limit", "rads_righthandlimit", 0, 20000)
    AddSlider(layout, "Left Hand Force Limit", "rads_lefthandlimit", 0, 20000)
    AddSlider(layout, "Pull Up Speed", "rads_pullupspeed", 30, 60)
end

concommand.Add("open_rads_menu", CreateRadsMenu)