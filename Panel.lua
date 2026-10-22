local _, IDPeek = ...

-- In-game checks (run after /reload, with /console scriptErrors 1):
--  1. /idp toggles the panel; Escape closes it; drag moves it; after /reload it reopens at the same place.
--  2. kit + "55752, 80801" + Enter -> "1 / 2 · kit 55752"; Next -> "2 / 2 · kit 80801"; Next -> "1 / 2 · kit 55752".
--  3. "55752,,x abc" -> "1 / 1 · kit 55752" and chat 'IDPeek: ignored "x"', 'IDPeek: ignored "abc"';
--     empty box + Enter -> "0 / 0", no error.
--  4. With 55752 entered, switch the dropdown to texture -> "1 / 1 · texture 55752".
--  5. Panel open, edit box unfocused: Left/Right flip entries, WASD and keybinds still work.
--     Panel closed: Left/Right turn the character. Typing in the box: Left/Right move the cursor.

local TYPES = { "kit", "spell", "display", "model", "texture", "worldeffect" }

IDPeek.kind = "kit"
IDPeek.entries = {}
IDPeek.index = 0

local frame = CreateFrame("Frame", "IDPeekFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(420, 480)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
tinsert(UISpecialFrames, "IDPeekFrame")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", 0, -5)
title:SetText("IDPeek")

local typeMenu = CreateFrame("Frame", "IDPeekTypeMenu", frame, "UIDropDownMenuTemplate")
typeMenu:SetPoint("TOPLEFT", -6, -30)
UIDropDownMenu_SetWidth(typeMenu, 100)

local idBox = CreateFrame("EditBox", "IDPeekIDBox", frame, "InputBoxTemplate")
idBox:SetSize(250, 20)
idBox:SetPoint("LEFT", typeMenu, "RIGHT", 0, 2)
idBox:SetAutoFocus(false)

local preview = CreateFrame("Frame", nil, frame)
preview:SetSize(380, 300)
preview:SetPoint("TOP", 0, -66)
frame.preview = preview
IDPeek.Preview:Init(preview)

local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
label:SetPoint("TOP", preview, "BOTTOM", 0, -8)
label:SetWidth(390)
label:SetWordWrap(true)

local prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
prev:SetSize(80, 22)
prev:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -40)
prev:SetText("Prev")

local nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
nextButton:SetSize(80, 22)
nextButton:SetPoint("TOPRIGHT", preview, "BOTTOMRIGHT", 0, -40)
nextButton:SetText("Next")
frame.nextButton = nextButton

local replay = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
replay:SetSize(80, 22)
replay:SetPoint("TOP", preview, "BOTTOM", 0, -40)
replay:SetText("Replay")
replay:SetScript("OnClick", function() IDPeek.Preview:Replay() end)

local standInBox = CreateFrame("EditBox", "IDPeekStandInBox", frame, "InputBoxTemplate")
standInBox:SetSize(90, 20)
standInBox:SetPoint("TOPRIGHT", nextButton, "BOTTOMRIGHT", 0, -8)
standInBox:SetAutoFocus(false)
standInBox:SetNumeric(true)
standInBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    IDPeek.Preview:SetStandIn(tonumber(self:GetText()))
end)
standInBox:SetScript("OnEscapePressed", standInBox.ClearFocus)

local standInLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
standInLabel:SetPoint("RIGHT", standInBox, "LEFT", -10, 0)
standInLabel:SetText("Kit stand-in display (empty = you):")

function IDPeek.Go(delta)
    local n = #IDPeek.entries
    if n == 0 then
        IDPeek.index = 0
        label:SetText("0 / 0")
        IDPeek.Preview:Clear()
        return
    end
    IDPeek.index = (IDPeek.index - 1 + delta) % n + 1
    local entry = IDPeek.entries[IDPeek.index]
    label:SetText(string.format("%d / %d · %s", IDPeek.index, n, entry.chain))
    IDPeek.Preview:Show(entry)
end

function IDPeek.Build()
    local ids, bad = IDPeek.Parse(idBox:GetText())
    for _, token in ipairs(bad) do
        print(string.format('IDPeek: ignored "%s"', token))
    end
    IDPeek.entries = IDPeek.BuildEntries(IDPeek.kind, ids)
    IDPeek.index = 0
    IDPeek.Go(1)
end

UIDropDownMenu_Initialize(typeMenu, function()
    for _, kind in ipairs(TYPES) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = kind
        info.checked = kind == IDPeek.kind
        info.func = function()
            IDPeek.kind = kind
            UIDropDownMenu_SetText(typeMenu, kind)
            IDPeek.Build()
        end
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_SetText(typeMenu, IDPeek.kind)

idBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    IDPeek.Build()
end)
idBox:SetScript("OnEscapePressed", idBox.ClearFocus)

prev:SetScript("OnClick", function() IDPeek.Go(-1) end)
nextButton:SetScript("OnClick", function() IDPeek.Go(1) end)

-- Left/Right flip entries while the panel is open; every other key goes on to the game.
frame:EnableKeyboard(true)
frame:SetPropagateKeyboardInput(true)
frame:SetScript("OnKeyDown", function(self, key)
    local flip = (key == "LEFT" or key == "RIGHT") and not idBox:HasFocus() and not standInBox:HasFocus()
    self:SetPropagateKeyboardInput(not flip)
    if flip then
        IDPeek.Go(key == "LEFT" and -1 or 1)
    end
end)
-- Let key-ups through again, so a movement key held across a flip is not left running.
frame:SetScript("OnKeyUp", function(self)
    self:SetPropagateKeyboardInput(true)
end)

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    IDPeekDB.point = { point, relativePoint, x, y }
end)

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= "IDPeek" then return end
    self:UnregisterEvent("ADDON_LOADED")
    IDPeekDB = IDPeekDB or {}
    local p = IDPeekDB.point
    if p then
        self:ClearAllPoints()
        self:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    IDPeek.Go(0)
end)

SLASH_IDPEEK1 = "/idp"
SlashCmdList.IDPEEK = function()
    frame:SetShown(not frame:IsShown())
end
