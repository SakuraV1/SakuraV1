-- SERVICES & CORE GUI
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)

-- SETTINGS
local settings = {
    boxEnabled        = true,
    dirEnabled        = true,
    linesEnabled      = true,
    billboardEnabled  = true,
    friendlyEspEnabled = true,  -- New setting for friendly ESP

    boxColor          = Color3.fromRGB(255,  50,  50),
    dirLineColor      = Color3.fromRGB(50, 255,  50),
    centerLineColor   = Color3.fromRGB(50,  50, 255),

    friendlyBoxColor  = Color3.fromRGB(50,  50, 255),
    friendlyDirLineColor = Color3.fromRGB(50, 255, 255),
    friendlyCenterLineColor = Color3.fromRGB(255,  50, 255),

    boxPadding        = Vector3.new(0.2, 0.2, 0.2),
}

-- TRACKERS
local adornMap      = {}  -- [Player] = BoxHandleAdornment
local dirMap        = {}  -- [Player] = Drawing.Line (pointer)
local lineMap       = {}  -- [Player] = Drawing.Line (center)
local billboardMap  = {}  -- [Player] = BillboardGui

-- UTIL: pick the root part
local function getRootPart(char)
    if char.PrimaryPart then return char.PrimaryPart end
    return char:FindFirstChild("HumanoidRootPart")
end

-- UTIL: check if players are on the same team
local function areTeammates(plr1, plr2)
    local team1 = plr1.Team
    local team2 = plr2.Team
    return team1 and team2 and team1 == team2
end

-- CLEANUP
local function clearAdornment(plr)
    if adornMap[plr] then
        adornMap[plr]:Destroy()
        adornMap[plr] = nil
    end
end
local function clearDirection(plr)
    if dirMap[plr] then
        dirMap[plr]:Remove()
        dirMap[plr] = nil
    end
end
local function clearLine(plr)
    if lineMap[plr] then
        lineMap[plr]:Remove()
        lineMap[plr] = nil
    end
end
local function clearBillboard(plr)
    if billboardMap[plr] then
        billboardMap[plr]:Destroy()
        billboardMap[plr] = nil
    end
end

-- PLAYER LIFECYCLE
local function onCharacterRemoving(plr)
    clearAdornment(plr)
    clearDirection(plr)
    clearLine(plr)
    clearBillboard(plr)
end

local function onPlayer(plr)
    plr.CharacterAdded:Connect(function(char)
        char.ChildAdded:Connect(function(child)
            if child:IsA("HumanoidRootPart") then
                ensure3DBox(plr)
                ensureDirection(plr)
                ensureLine(plr)
                ensureBillboard(plr)
            end
        end)
        char.ChildRemoved:Connect(function(child)
            if child:IsA("HumanoidRootPart") then
                clearAdornment(plr)
                clearDirection(plr)
                clearLine(plr)
                clearBillboard(plr)
            end
        end)
    end)
    plr.CharacterRemoving:Connect(function()
        onCharacterRemoving(plr)
    end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, plr in ipairs(Players:GetPlayers()) do
    onPlayer(plr)
end
Players.PlayerRemoving:Connect(onCharacterRemoving)

-- 1) 3D BOX AROUND ROOT, 10% SHORTER & LOWERED BY 15%
local function ensure3DBox(plr)
    if not settings.boxEnabled then
        clearAdornment(plr)
        return
    end

    local char = plr.Character
    if not (char and char.Parent) then
        clearAdornment(plr)
        return
    end

    local root = getRootPart(char)
    if not root then
        clearAdornment(plr)
        return
    end

    -- compute original stacked height: 3× part height + padding
    local origY        = root.Size.Y
    local unscaledH    = origY * 2.5 + settings.boxPadding.Y
    -- shorten by 10%
    local scaledHeight = unscaledH * 0.9

    -- create adornment if missing
    local adorn = adornMap[plr]
    if not adorn then
        adorn = Instance.new("BoxHandleAdornment")
        adorn.Adornee      = root
        adorn.AlwaysOnTop  = true
        adorn.ZIndex       = 0
        adorn.Parent       = root
        adornMap[plr]      = adorn
    end

    -- update size & color
    adorn.Size         = Vector3.new(
        root.Size.X + settings.boxPadding.X,
        scaledHeight,
        root.Size.Z + settings.boxPadding.Z
    )
    adorn.Color3       = areTeammates(LocalPlayer, plr) and settings.friendlyBoxColor or settings.boxColor
    adorn.Transparency = 0.85

    -- lower by 15% of unscaled height so box sits lower
    local baseOffsetY = origY + settings.boxPadding.Y * 0.5
    local offsetY     = baseOffsetY - (unscaledH * 0.23)
    adorn.CFrame      = CFrame.new(0, offsetY, 0)
end

-- 2) DIRECTION POINTER (with 15% lowered look vector)
local function ensureDirection(plr)
    if not settings.dirEnabled then
        clearDirection(plr)
        return
    end

    local char = plr.Character
    if not (char and char.Parent) then
        clearDirection(plr)
        return
    end

    local root = getRootPart(char)
    if not root then
        clearDirection(plr)
        return
    end

    local bboxCFrame, bboxSize = char:GetBoundingBox()
    local originWorld  = bboxCFrame.Position + Vector3.new(0, bboxSize.Y/4.5, 0)
    -- Lower the forwardWorld by 15% on the Y-axis
    local forwardWorld = originWorld + root.CFrame.LookVector * 3
    forwardWorld = Vector3.new(forwardWorld.X, forwardWorld.Y - (bboxSize.Y * 0.001), forwardWorld.Z)

    local cam = workspace.CurrentCamera
    local o2, onO = cam:WorldToViewportPoint(originWorld)
    local f2, onF = cam:WorldToViewportPoint(forwardWorld)
    if not (onO and onF) then
        clearDirection(plr)
        return
    end

    local line = dirMap[plr]
    if not line then
        line = Drawing.new("Line")
        line.Thickness    = 2
        line.Transparency = 1
        line.Visible      = false
        dirMap[plr]       = line
    end

    line.From    = Vector2.new(o2.X, o2.Y)
    line.To      = Vector2.new(f2.X, f2.Y)
    line.Color   = areTeammates(LocalPlayer, plr) and settings.friendlyDirLineColor or settings.dirLineColor
    line.Visible = true
end

-- 3) CENTER‐SCREEN LINE
local function ensureLine(plr)
    if not settings.linesEnabled then
        clearLine(plr)
        return
    end

    local char = plr.Character
    if not (char and char.Parent) then
        clearLine(plr)
        return
    end

    local root = getRootPart(char)
    if not root then
        clearLine(plr)
        return
    end

    local cam = workspace.CurrentCamera
    local pos, onS = cam:WorldToViewportPoint(root.Position)
    local line = lineMap[plr]
    if not line then
        line = Drawing.new("Line")
        line.Thickness    = 1
        line.Transparency = 1
        line.Visible      = false
        lineMap[plr]      = line
    end

    if onS then
        line.From    = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        line.To      = Vector2.new(pos.X, pos.Y)
        line.Color   = areTeammates(LocalPlayer, plr) and settings.friendlyCenterLineColor or settings.centerLineColor
        line.Visible = true
    else
        line.Visible = false
    end
end

-- 4) BILLBOARD TAG
local function ensureBillboard(plr)
    if not settings.billboardEnabled then
        clearBillboard(plr)
        return
    end

    local char = plr.Character
    if not (char and char.Parent) then
        clearBillboard(plr)
        return
    end

    local root = getRootPart(char)
    if not root then
        clearBillboard(plr)
        return
    end

    local BG = billboardMap[plr]
    if not BG then
        BG = Instance.new("BillboardGui")
        BG.Name        = "ESPTag"
        BG.Adornee     = root
        BG.Size        = UDim2.new(0,80,0,40)  -- Increased height and adjusted position
        BG.AlwaysOnTop = true
        BG.Parent      = char

        local lbl = Instance.new("TextLabel", BG)
        lbl.Name                   = "Label"
        lbl.Size                   = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.TextScaled             = true
        lbl.Font                   = Enum.Font.SourceSansBold
        lbl.TextColor3             = Color3.new(1,1,1)

        billboardMap[plr] = BG
    else
        BG.Adornee = root
    end

    local lbl = billboardMap[plr]:FindFirstChild("Label")
    if lbl then
        local dist = math.floor((workspace.CurrentCamera.CFrame.Position - root.Position).Magnitude)
        lbl.Text = string.format("%s | %d stud%s",
            plr.Name, dist, dist == 1 and "" or "s")
    end
    billboardMap[plr].Enabled = true
    billboardMap[plr].StudsOffset = Vector3.new(0, 3.5, 0)  -- Move billboard higher
end

-- CHEAT MENU UI
local menuGui = Instance.new("ScreenGui")
menuGui.Name           = "CheatMenu"
menuGui.Parent         = LocalPlayer:WaitForChild("PlayerGui")
menuGui.IgnoreGuiInset = true
menuGui.ResetOnSpawn   = false
menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
menuGui.Enabled        = false

local menuFrame = Instance.new("Frame", menuGui)
menuFrame.Size             = UDim2.new(0,280,0,600)  -- Increased height
menuFrame.Position         = UDim2.new(0.5,-130,0.5,-290)  -- Adjusted position
menuFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
menuFrame.BorderSizePixel  = 0

Instance.new("UICorner",  menuFrame).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke", menuFrame)
stroke.Color         = Color3.fromRGB(80, 80, 80)
stroke.Thickness     = 1

local title = Instance.new("TextLabel", menuFrame)
title.Size                   = UDim2.new(1,0,0,30)
title.Position               = UDim2.new(0,0,0,0)
title.BackgroundTransparency = 1
title.Text                  = "Cheat Menu"
title.TextColor3            = Color3.new(1,1,1)
title.Font                  = Enum.Font.SourceSansBold
title.TextSize              = 24
title.TextXAlignment        = Enum.TextXAlignment.Center
title.TextYAlignment        = Enum.TextYAlignment.Center

local toggles, colorBtns = {}, {}

local function addToggle(label, y, key)
    local btn = Instance.new("TextButton", menuFrame)
    btn.Name            = label.."Btn"
    btn.Size            = UDim2.new(0,200,0,30)
    btn.Position        = UDim2.new(0,30,0,y)
    btn.Font            = Enum.Font.SourceSansBold
    btn.TextSize        = 18
    btn.TextColor3      = Color3.new(1,1,1)
    btn.BorderSizePixel = 0
    btn.BackgroundColor3= Color3.fromRGB(100,100,100)
    btn.Text            = label
    btn.MouseButton1Click:Connect(function()
        settings[key] = not settings[key]
    end)
    toggles[label] = {button=btn,key=key}
end

local function addColorPicker(label, y, key)
    local lbl = Instance.new("TextLabel", menuFrame)
    lbl.Size                   = UDim2.new(0,140,0,30)
    lbl.Position               = UDim2.new(0,15,0,y)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = Color3.new(1,1,1)
    lbl.Font                   = Enum.Font.SourceSansBold
    lbl.TextSize               = 18
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Text                   = label

    local cb = Instance.new("TextButton", menuFrame)
    cb.Name               = label.."ColorBtn"
    cb.Size               = UDim2.new(0,35,0,35)
    cb.Position           = UDim2.new(1,-45,0,y)
    cb.BorderSizePixel    = 0
    cb.Text               = ""
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0,4)

    local function refresh()
        cb.BackgroundColor3 = settings[key]
    end

    cb.MouseButton1Click:Connect(function()
        settings[key] = Color3.fromRGB(
            math.random(0,255),
            math.random(0,255),
            math.random(0,255)
        )
        refresh()
    end)

    colorBtns[label] = {button=cb,key=key}
    refresh()
end

addToggle("Box",       50,  "boxEnabled")
addToggle("Pointer",   100, "dirEnabled")
addToggle("Lines",     150, "linesEnabled")
addToggle("Billboard", 200, "billboardEnabled")
addToggle("Friendly ESP", 250, "friendlyEspEnabled")  -- Toggle for friendly ESP

addColorPicker("Box Color",        300, "boxColor")
addColorPicker("Pointer Color",    350, "dirLineColor")
addColorPicker("Center Line Color",400, "centerLineColor")
addColorPicker("Friendly Box Color", 450, "friendlyBoxColor")
addColorPicker("Friendly Pointer Color", 500, "friendlyDirLineColor")
addColorPicker("Friendly Center Line Color", 550, "friendlyCenterLineColor")

UserInputService.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        menuGui.Enabled = not menuGui.Enabled
        if menuGui.Enabled then
            UserInputService.MouseBehavior    = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        else
            UserInputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
        end
    end
end)

-- MAIN LOOP
RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if settings.friendlyEspEnabled or not areTeammates(LocalPlayer, plr) then
                ensure3DBox(plr)
                ensureDirection(plr)
                ensureLine(plr)
                ensureBillboard(plr)
            else
                clearAdornment(plr)
                clearDirection(plr)
                clearLine(plr)
                clearBillboard(plr)
            end
        end
    end

    -- update toggles
    for label, data in pairs(toggles) do
        local btn, state = data.button, settings[data.key]
        btn.Text             = label .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,0,0)
    end
end)
