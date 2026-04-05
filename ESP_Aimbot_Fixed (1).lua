-- ============================================================
--  ESP + AimAssist + Silent Aim + Wall Bang
--  v4 — silent aim fires bullets toward target regardless of
--       where you're actually looking; wall bang bypasses
--       workspace raycasts so shots register through geometry.
--       Sticky aim applies to BOTH regular and silent aim.
-- ============================================================

local Rayfield    = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============================================================
--  SETTINGS
-- ============================================================
local Settings = {
    -- Extraction ESP
    ExtractionEnabled          = true,
    ExtractionTextSize         = 11,
    ExtractionTextColor        = Color3.fromRGB(255, 50, 50),
    ExtractionChamTransparency = 0.3,

    -- Player ESP
    PlayerEnabled              = true,
    PlayerChamColor            = Color3.fromRGB(255, 0, 0),
    PlayerChamTransparency     = 0.4,
    ShowPlayerDistance         = true,

    -- Loot ESP
    LootEnabled                = true,
    LootChamColor              = Color3.fromRGB(0, 255, 0),
    LootChamTransparency       = 0.3,
    ShowLootDistance           = true,
    LootMaxDistance            = 500,

    -- Regular Aim Assist (camera lerp, hold RMB)
    AimbotEnabled              = true,
    Smoothness                 = 0.15,
    AimPart                    = "Head",
    FOV                        = 200,
    ActivationKey              = Enum.UserInputType.MouseButton2,
    ActivationIsKeyCode        = false,
    StickyAim                  = true,   -- shared with silent aim

    -- Silent Aim (LMB-triggered camera snap then restore)
    SilentAimEnabled           = false,
    SilentAimPart              = "Head",
    SilentAimHitChance         = 100,    -- 1-100%
    SilentAimWallBang          = false,  -- ignore geometry when picking target
    SilentAimMaxDistance       = 800,    -- studs
}

-- ============================================================
--  EXTRACTION POSITIONS
-- ============================================================
local ExtractionPositions = {
    Vector3.new(-294.7966,  5.886, 1000.371),
    Vector3.new( 699.640,   4.487,  868.338),
    Vector3.new(-530.892,  21.904,  597.135),
}

-- ============================================================
--  GUI CONTAINER
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "ESP_Hub"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--  HELPERS
-- ============================================================
local function makeLabel(color, size)
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0, 140, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = color or Color3.new(1,1,1)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.new(0,0,0)
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextSize               = size or 10
    lbl.Visible                = false
    lbl.Parent                 = ScreenGui
    return lbl
end

local function makeHighlight(adornee, fill, fillTrans, outline, outlineTrans)
    local h = Instance.new("Highlight")
    h.FillColor           = fill         or Color3.new(1,0,0)
    h.FillTransparency    = fillTrans    or 0.4
    h.OutlineColor        = outline      or Color3.new(1,1,1)
    h.OutlineTransparency = outlineTrans or 0.2
    h.Adornee             = adornee
    h.Parent              = adornee
    return h
end

local function getObjectPosition(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        local p = obj:FindFirstChildWhichIsA("BasePart")
        if p then return p.Position end
    end
    return nil
end

-- ============================================================
--  EXTRACTION ESP
-- ============================================================
local extractionObjects = {}

local function initExtractionESP()
    for i, pos in ipairs(ExtractionPositions) do
        local part = Instance.new("Part")
        part.Name         = "ExtractionAnchor_" .. i
        part.Size         = Vector3.new(5,5,5)
        part.Position     = pos
        part.Anchored     = true
        part.CanCollide   = false
        part.Transparency = 1
        part.Parent       = workspace

        local lbl = makeLabel(Settings.ExtractionTextColor, Settings.ExtractionTextSize)
        lbl.Text = "extraction | ---"

        extractionObjects[i] = {
            part      = part,
            highlight = makeHighlight(part, Color3.fromRGB(255,0,0),
                            Settings.ExtractionChamTransparency,
                            Color3.fromRGB(255,255,255), 0.2),
            label     = lbl,
            position  = pos,
        }
    end
end

-- ============================================================
--  PLAYER ESP
-- ============================================================
local playerObjects = {}

local function removePlayerESP(player)
    local d = playerObjects[player]
    if not d then return end
    pcall(function() if d.highlight then d.highlight:Destroy() end end)
    pcall(function() if d.label     then d.label:Destroy()     end end)
    playerObjects[player] = nil
end

local function addPlayerESP(player, character)
    if not character then return end
    if not character:FindFirstChildOfClass("Humanoid") then return end
    removePlayerESP(player)

    local label = nil
    if Settings.ShowPlayerDistance then
        label = makeLabel(Color3.new(1,1,1), 10)
        label.Text = player.Name .. " | ---"
    end

    playerObjects[player] = {
        highlight = makeHighlight(character,
                        Settings.PlayerChamColor, Settings.PlayerChamTransparency,
                        Color3.fromRGB(255,255,255), 0.2),
        label     = label,
        character = character,
        rootPart  = character:FindFirstChild("HumanoidRootPart")
                     or character:FindFirstChild("Torso")
                     or character:FindFirstChildWhichIsA("BasePart"),
    }
end

local function connectPlayerEvents(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(character)
        task.wait(0.1)
        addPlayerESP(player, character)
    end)
    if player.Character then
        task.defer(addPlayerESP, player, player.Character)
    end
end

local function initPlayerESP()
    for _, player in ipairs(Players:GetPlayers()) do
        connectPlayerEvents(player)
    end
end

Players.PlayerAdded:Connect(connectPlayerEvents)
Players.PlayerRemoving:Connect(removePlayerESP)

-- ============================================================
--  LOOT CRATE ESP
-- ============================================================
local lootObjects = {}

local function removeLootESP(crate)
    local d = lootObjects[crate]
    if not d then return end
    pcall(function() if d.highlight then d.highlight:Destroy() end end)
    pcall(function() if d.label     then d.label:Destroy()     end end)
    lootObjects[crate] = nil
end

local function addLootESP(obj)
    if lootObjects[obj] then return end
    local label = nil
    if Settings.ShowLootDistance then
        label = makeLabel(Color3.fromRGB(0,255,0), 10)
        label.Text = "CRATE | ---"
    end
    lootObjects[obj] = {
        highlight = makeHighlight(obj, Settings.LootChamColor,
                        Settings.LootChamTransparency,
                        Color3.fromRGB(255,255,255), 0.3),
        label  = label,
        object = obj,
    }
    obj.AncestryChanged:Connect(function()
        if not obj:IsDescendantOf(workspace) then removeLootESP(obj) end
    end)
end

local function scanForCrates(container)
    if not container then return end
    for _, obj in ipairs(container:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and obj.Name:lower():find("crate") then
            addLootESP(obj)
        end
    end
end

local function initLootESP()
    local function watchFolder(f)
        scanForCrates(f)
        f.DescendantAdded:Connect(function(obj)
            if (obj:IsA("Model") or obj:IsA("BasePart")) and obj.Name:lower():find("crate") then
                addLootESP(obj)
            end
        end)
    end
    local folder = workspace:FindFirstChild("SpawnedCrates")
    if folder then
        watchFolder(folder)
    else
        workspace.ChildAdded:Connect(function(child)
            if child.Name == "SpawnedCrates" then
                task.wait(0.5); watchFolder(child)
            end
        end)
    end
end

-- ============================================================
--  SHARED TARGET SELECTION
--  stickyTarget is shared between aim assist and silent aim.
--  wallBangMode = true → skip on-screen and LOS checks entirely
-- ============================================================
local stickyTarget = nil

local function getMyRoot()
    local c = LocalPlayer.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end

-- Check if a player is still a usable target
local function isValidTarget(player, wallBangMode)
    if not player or not player.Parent then return false end
    local data = playerObjects[player]
    if not data or not data.character then return false end

    -- Resolve the part we're aiming at (silent aim uses SilentAimPart)
    local aimPart = data.character:FindFirstChild(Settings.SilentAimPart)
        or data.character:FindFirstChild("HumanoidRootPart")
    if not aimPart then return false end

    local humanoid = data.character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    -- Distance cap
    local myRoot = getMyRoot()
    if myRoot and (aimPart.Position - myRoot.Position).Magnitude > Settings.SilentAimMaxDistance then
        return false
    end

    if wallBangMode then
        return true  -- behind walls is fine, skip screen/LOS checks
    end

    -- Must be on screen
    local _, onScreen = Camera:WorldToScreenPoint(aimPart.Position)
    if not onScreen then return false end

    -- Sticky leash: stay locked as long as target is within 2x FOV of mouse
    if Settings.StickyAim then
        local mouse    = LocalPlayer:GetMouse()
        local mousePos = Vector2.new(mouse.X, mouse.Y)
        local sp, _    = Camera:WorldToScreenPoint(aimPart.Position)
        if (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude > Settings.FOV * 2 then
            return false
        end
    end

    return true
end

-- Pick the closest valid target; respects sticky aim
-- wallBangMode: if true, rank by 3D distance (off-screen targets valid too)
local function getBestTarget(wallBangMode)
    if Settings.StickyAim and stickyTarget and isValidTarget(stickyTarget, wallBangMode) then
        return stickyTarget
    end

    local myRoot   = getMyRoot()
    local mouse    = LocalPlayer:GetMouse()
    local mousePos = Vector2.new(mouse.X, mouse.Y)
    local best, bestScore = nil, math.huge

    for player, data in pairs(playerObjects) do
        if player == LocalPlayer then continue end
        local char = data.character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local aimPart = char:FindFirstChild(Settings.SilentAimPart)
            or char:FindFirstChild("HumanoidRootPart")
        if not aimPart then continue end

        if myRoot and (aimPart.Position - myRoot.Position).Magnitude > Settings.SilentAimMaxDistance then
            continue
        end

        local score
        if wallBangMode then
            -- Off-screen OK: score by 3D distance
            score = myRoot and (aimPart.Position - myRoot.Position).Magnitude or 0
        else
            local sp, onScreen = Camera:WorldToScreenPoint(aimPart.Position)
            if not onScreen then continue end
            score = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
            if score > Settings.FOV then continue end
        end

        if score < bestScore then
            bestScore = score
            best      = player
        end
    end

    stickyTarget = best
    return best
end

-- ============================================================
--  LINE-OF-SIGHT CHECK  (used by silent aim when wall bang is OFF)
-- ============================================================
local function hasLineOfSight(origin, targetPos)
    -- Build exclude list: all player characters (so the ray doesn't
    -- stop on our own body or teammates)
    local exclude = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(exclude, p.Character) end
    end
    local params = RaycastParams.new()
    params.FilterType                 = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude
    local dir    = targetPos - origin
    local result = workspace:Raycast(origin, dir, params)
    return result == nil  -- no hit = clear path
end

-- ============================================================
--  REGULAR AIM ASSIST  (hold RMB → camera lerps toward target)
-- ============================================================
local aimbotActive = false

local function aimAtPlayer(player)
    local data = playerObjects[player]
    if not data or not data.character then return end
    -- Regular aim uses AimPart (can differ from SilentAimPart)
    local aimPart = data.character:FindFirstChild(Settings.AimPart)
    if not aimPart then return end
    local targetCF = CFrame.lookAt(Camera.CFrame.Position, aimPart.Position)
    if Settings.Smoothness <= 0.01 then
        Camera.CFrame = targetCF
    else
        Camera.CFrame = Camera.CFrame:Lerp(targetCF, Settings.Smoothness)
    end
end

UIS.InputBegan:Connect(function(input, gp)
    if gp or not Settings.AimbotEnabled then return end
    if Settings.ActivationIsKeyCode then
        if input.KeyCode == Settings.ActivationKey then aimbotActive = true end
    else
        if input.UserInputType == Settings.ActivationKey then aimbotActive = true end
    end
end)

UIS.InputEnded:Connect(function(input)
    if Settings.ActivationIsKeyCode then
        if input.KeyCode == Settings.ActivationKey then
            aimbotActive = false
            if not Settings.SilentAimEnabled then stickyTarget = nil end
        end
    else
        if input.UserInputType == Settings.ActivationKey then
            aimbotActive = false
            if not Settings.SilentAimEnabled then stickyTarget = nil end
        end
    end
end)

-- ============================================================
--  SILENT AIM
--
--  On LMB press:
--    1. Roll hit chance — abort if unlucky
--    2. Find best target (wall bang mode if enabled)
--    3. If wall bang is OFF, verify line-of-sight ray
--    4. Save real Camera.CFrame
--    5. Snap Camera.CFrame to look at target part
--       → game's client-side tool raycast now originates toward target
--    6. Flag restore so next RenderStepped reverts the camera
--       before the player sees the snap
-- ============================================================
local silentRestorePending = false
local savedCameraCF        = nil

local function doSilentAim()
    if not Settings.SilentAimEnabled then return end

    -- Hit chance roll
    if math.random(1, 100) > Settings.SilentAimHitChance then return end

    local target = getBestTarget(Settings.SilentAimWallBang)
    if not target then return end

    local data = playerObjects[target]
    if not data or not data.character then return end
    local aimPart = data.character:FindFirstChild(Settings.SilentAimPart)
        or data.character:FindFirstChild("HumanoidRootPart")
    if not aimPart then return end

    -- LOS check (skip when wall bang is ON)
    if not Settings.SilentAimWallBang then
        local myRoot = getMyRoot()
        if myRoot and not hasLineOfSight(myRoot.Position, aimPart.Position) then
            return  -- blocked by geometry and wall bang is off
        end
    end

    -- Snap camera toward target; restore happens next frame in RenderStepped
    savedCameraCF        = Camera.CFrame
    Camera.CFrame        = CFrame.lookAt(Camera.CFrame.Position, aimPart.Position)
    silentRestorePending = true
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        doSilentAim()
    end
end)

-- ============================================================
--  ESP RENDER UPDATE
-- ============================================================
local function updateESP()
    local character = LocalPlayer.Character
    local rootPart  = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local myPos = rootPart.Position

    -- Extraction
    for _, obj in ipairs(extractionObjects) do
        if obj.highlight then obj.highlight.Enabled = Settings.ExtractionEnabled end
        if obj.label then
            if Settings.ExtractionEnabled then
                obj.label.Text = "extraction | " .. math.floor((obj.position - myPos).Magnitude) .. "s"
                local vec, onScreen = Camera:WorldToScreenPoint(obj.position)
                obj.label.Visible = onScreen
                if onScreen then obj.label.Position = UDim2.fromOffset(vec.X - 70, vec.Y - 30) end
            else
                obj.label.Visible = false
            end
        end
    end

    -- Players
    for player, data in pairs(playerObjects) do
        if data.character and (not data.rootPart or not data.rootPart.Parent) then
            data.rootPart = data.character:FindFirstChild("HumanoidRootPart")
                or data.character:FindFirstChild("Torso")
                or data.character:FindFirstChildWhichIsA("BasePart")
        end
        local rp    = data.rootPart
        local valid = rp and rp.Parent

        if data.highlight then
            data.highlight.FillColor        = Settings.PlayerChamColor
            data.highlight.FillTransparency = Settings.PlayerChamTransparency
            data.highlight.Enabled          = Settings.PlayerEnabled and valid
        end
        if data.label then
            if Settings.PlayerEnabled and Settings.ShowPlayerDistance and valid then
                data.label.Text = player.Name .. " | " .. math.floor((rp.Position - myPos).Magnitude) .. "s"
                local vec, onScreen = Camera:WorldToScreenPoint(rp.Position)
                data.label.Visible = onScreen
                if onScreen then data.label.Position = UDim2.fromOffset(vec.X - 55, vec.Y - 40) end
            else
                data.label.Visible = false
            end
        end
    end

    -- Loot crates
    for crate, data in pairs(lootObjects) do
        if not (data.object and data.object.Parent) then removeLootESP(crate); continue end
        local cratePos = getObjectPosition(data.object)
        local show     = cratePos and Settings.LootEnabled
            and (cratePos - myPos).Magnitude <= Settings.LootMaxDistance

        if data.highlight then
            data.highlight.FillColor        = Settings.LootChamColor
            data.highlight.FillTransparency = Settings.LootChamTransparency
            data.highlight.Enabled          = show and true or false
        end
        if data.label then
            if show and Settings.ShowLootDistance and cratePos then
                data.label.Text = "CRATE | " .. math.floor((cratePos - myPos).Magnitude) .. "s"
                local vec, onScreen = Camera:WorldToScreenPoint(cratePos)
                data.label.Visible = onScreen
                if onScreen then data.label.Position = UDim2.fromOffset(vec.X - 55, vec.Y - 28) end
            else
                data.label.Visible = false
            end
        end
    end
end

-- ============================================================
--  MAIN LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    -- Restore camera after silent aim snap (must happen before next render)
    if silentRestorePending and savedCameraCF then
        Camera.CFrame        = savedCameraCF
        savedCameraCF        = nil
        silentRestorePending = false
    end

    updateESP()

    -- Regular aim assist
    if aimbotActive and Settings.AimbotEnabled then
        local target = getBestTarget(false)
        if target then aimAtPlayer(target) end
    end
end)

-- ============================================================
--  RAYFIELD GUI
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "ESP Hub",
    LoadingTitle = "Loading...",
    ConfigurationSaving = { Enabled = true, FileName = "ESPHub_Config" },
})

-- ──────────────── Extraction Tab ────────────────
local ExTab = Window:CreateTab("Extraction", 4483362458)
ExTab:CreateToggle({ Name = "Extraction ESP", CurrentValue = Settings.ExtractionEnabled, Flag = "ExtractionEnabled",
    Callback = function(v) Settings.ExtractionEnabled = v end })
ExTab:CreateColorPicker({ Name = "Text Color", Color = Settings.ExtractionTextColor, Flag = "ExtractionTextColor",
    Callback = function(c)
        Settings.ExtractionTextColor = c
        for _, obj in ipairs(extractionObjects) do if obj.label then obj.label.TextColor3 = c end end
    end })
ExTab:CreateSlider({ Name = "Text Size", Range = {8,20}, Increment = 1, CurrentValue = Settings.ExtractionTextSize, Flag = "ExtractionTextSize",
    Callback = function(v)
        Settings.ExtractionTextSize = v
        for _, obj in ipairs(extractionObjects) do if obj.label then obj.label.TextSize = v end end
    end })
ExTab:CreateSlider({ Name = "Cham Transparency", Range = {0,1}, Increment = 0.05, CurrentValue = Settings.ExtractionChamTransparency, Flag = "ExtractionChamTrans",
    Callback = function(v)
        Settings.ExtractionChamTransparency = v
        for _, obj in ipairs(extractionObjects) do if obj.highlight then obj.highlight.FillTransparency = v end end
    end })

-- ──────────────── Player Tab ────────────────
local PlTab = Window:CreateTab("Players", 4483362458)
PlTab:CreateToggle({ Name = "Player ESP", CurrentValue = Settings.PlayerEnabled, Flag = "PlayerEnabled",
    Callback = function(v) Settings.PlayerEnabled = v end })
PlTab:CreateColorPicker({ Name = "Cham Color", Color = Settings.PlayerChamColor, Flag = "PlayerChamColor",
    Callback = function(c) Settings.PlayerChamColor = c end })
PlTab:CreateSlider({ Name = "Cham Transparency", Range = {0,1}, Increment = 0.05, CurrentValue = Settings.PlayerChamTransparency, Flag = "PlayerChamTrans",
    Callback = function(v) Settings.PlayerChamTransparency = v end })
PlTab:CreateToggle({ Name = "Show Distance", CurrentValue = Settings.ShowPlayerDistance, Flag = "ShowPlayerDist",
    Callback = function(v)
        Settings.ShowPlayerDistance = v
        for player, data in pairs(playerObjects) do
            if v and not data.label then
                local lbl = makeLabel(Color3.new(1,1,1), 10)
                lbl.Text = player.Name .. " | ---"
                data.label = lbl
            elseif not v and data.label then
                data.label:Destroy(); data.label = nil
            end
        end
    end })

-- ──────────────── Loot Tab ────────────────
local LootTab = Window:CreateTab("Loot", 4483362458)
LootTab:CreateToggle({ Name = "Loot Crate ESP", CurrentValue = Settings.LootEnabled, Flag = "LootEnabled",
    Callback = function(v) Settings.LootEnabled = v end })
LootTab:CreateColorPicker({ Name = "Cham Color", Color = Settings.LootChamColor, Flag = "LootChamColor",
    Callback = function(c)
        Settings.LootChamColor = c
        for _, data in pairs(lootObjects) do if data.highlight then data.highlight.FillColor = c end end
    end })
LootTab:CreateSlider({ Name = "Cham Transparency", Range = {0,1}, Increment = 0.05, CurrentValue = Settings.LootChamTransparency, Flag = "LootChamTrans",
    Callback = function(v)
        Settings.LootChamTransparency = v
        for _, data in pairs(lootObjects) do if data.highlight then data.highlight.FillTransparency = v end end
    end })
LootTab:CreateToggle({ Name = "Show Distance", CurrentValue = Settings.ShowLootDistance, Flag = "ShowLootDist",
    Callback = function(v) Settings.ShowLootDistance = v end })
LootTab:CreateSlider({ Name = "Max Crate Distance", Range = {50,1000}, Increment = 10, CurrentValue = Settings.LootMaxDistance, Flag = "LootMaxDist",
    Callback = function(v) Settings.LootMaxDistance = v end })

-- ──────────────── Aim Assist Tab ────────────────
local AimTab = Window:CreateTab("Aim Assist", 4483362458)
AimTab:CreateToggle({ Name = "Enable Aim Assist", CurrentValue = Settings.AimbotEnabled, Flag = "AimbotEnabled",
    Callback = function(v)
        Settings.AimbotEnabled = v
        if not v then aimbotActive = false end
    end })
AimTab:CreateSlider({ Name = "Smoothness (higher = smoother)", Range = {0,1}, Increment = 0.01, CurrentValue = Settings.Smoothness, Flag = "Smoothness",
    Callback = function(v) Settings.Smoothness = v end })
AimTab:CreateSlider({ Name = "FOV Radius (pixels)", Range = {50,600}, Increment = 10, CurrentValue = Settings.FOV, Flag = "FOV",
    Callback = function(v) Settings.FOV = v end })
AimTab:CreateDropdown({ Name = "Aim Part",
    Options = {"Head","HumanoidRootPart","Torso","UpperTorso"},
    CurrentOption = {"Head"}, Flag = "AimPart",
    Callback = function(o)
        Settings.AimPart = type(o) == "table" and (o[1] or "Head") or o
    end })
AimTab:CreateLabel("Activation: Right Mouse Button (hold)")
AimTab:CreateToggle({ Name = "Sticky Aim", CurrentValue = Settings.StickyAim, Flag = "StickyAim",
    Callback = function(v)
        Settings.StickyAim = v
        if not v then stickyTarget = nil end
    end })

-- ──────────────── Silent Aim Tab ────────────────
local SilTab = Window:CreateTab("Silent Aim", 4483362458)

SilTab:CreateToggle({ Name = "Enable Silent Aim", CurrentValue = Settings.SilentAimEnabled, Flag = "SilentAimEnabled",
    Callback = function(v)
        Settings.SilentAimEnabled = v
        if not v then stickyTarget = nil end
    end })

SilTab:CreateLabel("Activation: Left Mouse Button (fires on every click)")

-- Hit chance: 100 = always, 50 = 50/50 per shot
SilTab:CreateSlider({ Name = "Hit Chance (%)", Range = {1,100}, Increment = 1,
    CurrentValue = Settings.SilentAimHitChance, Flag = "SilentHitChance",
    Callback = function(v) Settings.SilentAimHitChance = v end })

-- Which body part silent aim redirects toward
SilTab:CreateDropdown({
    Name    = "Target Body Part",
    Options = {
        "Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso",
        "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"
    },
    CurrentOption = {"Head"},
    Flag          = "SilentAimPart",
    Callback = function(o)
        Settings.SilentAimPart = type(o) == "table" and (o[1] or "Head") or o
    end })

-- Max distance: targets beyond this stud range are ignored
SilTab:CreateSlider({ Name = "Max Target Distance (studs)", Range = {50,2000}, Increment = 50,
    CurrentValue = Settings.SilentAimMaxDistance, Flag = "SilentAimMaxDist",
    Callback = function(v) Settings.SilentAimMaxDistance = v end })

-- Wall Bang: ON = targets behind walls are valid, LOS check is skipped
SilTab:CreateToggle({ Name = "Wall Bang (shoot through walls)", CurrentValue = Settings.SilentAimWallBang, Flag = "SilentWallBang",
    Callback = function(v) Settings.SilentAimWallBang = v end })

-- Sticky aim is shared — mirrored here for convenience
SilTab:CreateToggle({ Name = "Sticky Aim (shared with Aim Assist)", CurrentValue = Settings.StickyAim, Flag = "StickyAim2",
    Callback = function(v)
        Settings.StickyAim = v
        if not v then stickyTarget = nil end
    end })

-- ============================================================
--  INITIALIZE
-- ============================================================
initExtractionESP()
initPlayerESP()
initLootESP()

Rayfield:LoadConfiguration()

print("[ESP Hub v4] Loaded successfully")
print("  RMB (hold) = Aim Assist camera lerp")
print("  LMB        = Silent Aim (when enabled)")
print("  Sticky aim is shared between both modes")
