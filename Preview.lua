local _, IDPeek = ...

-- In-game checks:
--  1. kit 55752 -> gold glow on the player; Replay plays it again;
--     kit "55752, 80801", Next -> only the second kit shows.
--  2. Stand-in 71701 + kit 55752 -> kit on Krosus; clearing the stand-in box -> back on the player.
--  3. display 71701 -> Krosus; drag rotates, wheel zooms.
--  4. model 1381346 -> LootFX02 roughly centred; drag rotates, wheel zooms.
--  5. texture 136207 -> the icon, not stretched.
--  6. Switching between the four kinds shows only one view at a time.

local Preview = {}
IDPeek.Preview = Preview

local MIN_ZOOM, MAX_ZOOM = 0.3, 5
local CAMERA_START = { -8, 0, 1 }   -- used when the actor cannot report its bounding box

local region, model, scene, actor, texture
local current, standIn
local modelZoom, sceneZoom = 1, 1
local sceneTarget, sceneDistance = { 0, 0, 0 }, 8

-- Drag to rotate, wheel to zoom, on any frame of the preview.
local function makeInteractive(view, rotate, zoom)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseDown", function(self)
        self.lastX = GetCursorPosition()
    end)
    view:SetScript("OnMouseUp", function(self)
        self.lastX = nil
    end)
    view:SetScript("OnUpdate", function(self)
        if self.lastX then
            local x = GetCursorPosition()
            rotate((x - self.lastX) * 0.01)
            self.lastX = x
        end
    end)
    view:SetScript("OnMouseWheel", function(_, delta)
        zoom(delta > 0 and 0.9 or 1 / 0.9)
    end)
end

local function clampZoom(z)
    return math.min(MAX_ZOOM, math.max(MIN_ZOOM, z))
end

local function placeCamera()
    local d = sceneDistance * sceneZoom
    scene:SetCameraPosition(sceneTarget[1] - d, sceneTarget[2], sceneTarget[3])
    scene:SetCameraOrientationByYawPitchRoll(0, 0, 0)
end

-- Aim the camera at the loaded model's bounding box, if the actor can report one.
local function fitCamera()
    if actor.GetActiveBoundingBox then
        local x1, y1, z1, x2, y2, z2 = actor:GetActiveBoundingBox()
        if x1 and x2 and x2 > x1 then
            sceneTarget = { (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2 }
            sceneDistance = 2.5 * math.max(x2 - x1, y2 - y1, z2 - z1)
            placeCamera()
            return
        end
    end
    sceneTarget = { 0, 0, CAMERA_START[3] }
    sceneDistance = -CAMERA_START[1]
    placeCamera()
end

function Preview:Init(parent)
    region = parent

    model = CreateFrame("PlayerModel", nil, region)
    model:SetAllPoints()
    makeInteractive(model,
        function(d) model:SetFacing(model:GetFacing() + d) end,
        function(f)
            modelZoom = clampZoom(modelZoom * f)
            model:SetCamDistanceScale(modelZoom)
        end)

    scene = CreateFrame("ModelScene", nil, region)
    scene:SetAllPoints()
    actor = scene:CreateActor()
    actor:SetPosition(0, 0, 0)
    -- Actors are not frames; if this client's actor has no OnModelLoaded, fitCamera's fallback is used.
    pcall(actor.SetScript, actor, "OnModelLoaded", fitCamera)
    makeInteractive(scene,
        function(d) actor:SetYaw((actor:GetYaw() or 0) + d) end,
        function(f)
            sceneZoom = clampZoom(sceneZoom * f)
            placeCamera()
        end)

    self:Clear()
end

local function hideAll()
    model:Hide()
    scene:Hide()
    if texture then texture:Hide() end
end

local function showKit(id)
    model:ClearModel()
    if standIn then
        model:SetDisplayInfo(standIn)
    else
        model:SetUnit("player")
    end
    model:ApplySpellVisualKit(id, false)
end

local function showTexture(id)
    -- A texture with no size set takes the file's own size; fit that into the preview.
    if texture then texture:Hide() end
    texture = region:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("CENTER")
    texture:SetTexture(id)
    local w, h = texture:GetSize()
    local maxW, maxH = region:GetSize()
    if not (w and h and w > 0 and h > 0) then
        w, h = maxH, maxH
    end
    local scale = math.min(maxW / w, maxH / h)
    texture:SetSize(w * scale, h * scale)
end

function Preview:Show(entry)
    current = entry
    hideAll()
    if not entry or not entry.view then return end
    if entry.view == "model" then
        model:Show()
        model:SetCamDistanceScale(modelZoom)
        if entry.kind == "kit" then
            showKit(entry.id)
        else
            model:ClearModel()
            model:SetDisplayInfo(entry.id)
        end
    elseif entry.view == "scene" then
        scene:Show()
        actor:SetYaw(0)
        actor:SetModelByFileID(entry.id)
        fitCamera()
    elseif entry.view == "texture" then
        showTexture(entry.id)
    end
end

function Preview:Clear()
    self:Show(nil)
end

function Preview:Replay()
    self:Show(current)
end

-- displayID or nil (the player)
function Preview:SetStandIn(displayID)
    standIn = displayID
    if current and current.kind == "kit" then
        self:Show(current)
    end
end
