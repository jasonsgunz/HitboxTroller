local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- // Variables
local Active = false
local Keybind = Enum.KeyCode.Unknown
local TargetPartName = "HumanoidRootPart"
local Mode = "Hold"
local Prediction = 0 
local Smoothing = 0.5 
local SettingKey = false
local LockedPlayer = nil 
local Checks = {
    Alive = false,
    Team = false,
    Wall = false
}

local selfOptions = {
    speed = {value = 16, enabled = false},
    jump = {value = 50, enabled = false},
    fly = {enabled = false, speed = 1}
}

local espOptions = {
    tracers = false,
    names = false,
    dot = false
}

local antiFlingEnabled = false
local lastSafeCF = CFrame.new()
local teleportThreshold = 20    
local ctrl = {f = 0, b = 0, l = 0, r = 0}

local hitboxEnabled = false
local hitboxSize = 8
local hitboxVisual = false
local hitboxData = {}
local originalSizes = {} 
local collisionEnabled = false

local espCache = {} 
local _Connections = {}

-- // Logic Functions (V23 Standard)
local function isVisible(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local char = targetPart.Parent
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, rayParams)
    return result == nil 
end

local function isValid(p, isAcquiring) 
    if not p or not p.Character or not p.Character:FindFirstChild(TargetPartName) then return false end
    local targetPart = p.Character[TargetPartName]
    local hum = p.Character:FindFirstChildOfClass("Humanoid")
    
    if Checks.Alive and (not hum or hum.Health <= 0) then return false end
    if Checks.Team and p.Team == LocalPlayer.Team then return false end
    
    -- V23 logic for sticky targeting
    if isAcquiring and Checks.Wall and not isVisible(targetPart) then return false end
    
    return true
end

local function findBestTarget()
    local target, dist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isValid(p, true) then 
            local pos, onScreen = Camera:WorldToViewportPoint(p.Character[TargetPartName].Position)
            if onScreen then
                local mag = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                if mag < dist then 
                    dist = mag
                    target = p 
                end
            end
        end
    end
    return target
end

-- // Hitbox Functions
local function findBestHitboxPart(character)
    if not character then return nil end
    local priority = {"HumanoidRootPart","UpperTorso","LowerTorso","Torso","Head"}
    for _,name in ipairs(priority) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
    return character:FindFirstChildOfClass("BasePart")
end

local function applyHitbox(plr)
    if not hitboxEnabled or plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hrp = findBestHitboxPart(char)
    if not hrp then return end
    
    if not originalSizes[plr] then originalSizes[plr] = hrp.Size end 
    
    if hitboxData[plr] then
        if hitboxData[plr].conn then hitboxData[plr].conn:Disconnect() end
        if hitboxData[plr].viz then hitboxData[plr].viz:Destroy() end
    end
    
    local viz
    if hitboxVisual then
        viz = Instance.new("Part")
        viz.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        viz.Anchored = true
        viz.CanCollide = false
        viz.Transparency = 0.7
        viz.Color = Color3.fromRGB(255, 0, 0)
        viz.Material = Enum.Material.Neon
        viz.Parent = workspace
    end
    
    local conn = RunService.RenderStepped:Connect(function()
        if not hrp or not hrp.Parent then
            if viz then viz:Destroy() end
            return
        end
        hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        hrp.CanCollide = collisionEnabled
        if viz then 
            viz.CFrame = hrp.CFrame
            viz.Size = hrp.Size 
        end
    end)
    hitboxData[plr] = {conn = conn, viz = viz}
end

local function reapplyHitboxes()
    for _, v in pairs(hitboxData) do
        if v.conn then v.conn:Disconnect() end
        if v.viz then v.viz:Destroy() end
    end
    hitboxData = {}
    if not hitboxEnabled then
        for _, p in pairs(Players:GetPlayers()) do
            local char = p.Character
            if char then
                local hrp = findBestHitboxPart(char)
                if hrp then 
                    hrp.Size = originalSizes[p] or Vector3.new(2, 2, 1)
                    hrp.CanCollide = true 
                end
            end
        end
        return
    end
    for _, p in pairs(Players:GetPlayers()) do 
        applyHitbox(p) 
    end
end

-- // UI Framework
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "UniversalAimbot_V23_Fixed"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true 

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 380, 0, 300)
Main.Position = UDim2.new(0.5, -190, 0.5, -150)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Main.Active = true
Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

-- // Dragging Fix
local dragging, dragInput, dragStart, startPos
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

table.insert(_Connections, RunService.RenderStepped:Connect(function()
    if dragging and dragInput then
        local delta = dragInput.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, -60, 0, 35)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "UniversalAimbot V23"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = "GothamBold"; Title.TextSize = 14; Title.TextXAlignment = "Left"

local Close = Instance.new("TextButton", Main)
Close.Size = UDim2.new(0, 25, 0, 25); Close.Position = UDim2.new(1, -30, 0, 5); Close.BackgroundColor3 = Color3.fromRGB(200, 50, 50); Close.Text = "X"; Close.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 4)

local TabHolder = Instance.new("Frame", Main)
TabHolder.Size = UDim2.new(1, -20, 0, 30); TabHolder.Position = UDim2.new(0, 10, 0, 35); TabHolder.BackgroundTransparency = 1

-- // Page Setup
local MainPage = Instance.new("ScrollingFrame", Main)
MainPage.Size = UDim2.new(1, 0, 1, -75); MainPage.Position = UDim2.new(0, 0, 0, 75); MainPage.BackgroundTransparency = 1; MainPage.BorderSizePixel = 0; MainPage.CanvasSize = UDim2.new(0, 0, 0, 450); MainPage.ScrollBarThickness = 0
local SelfPage = MainPage:Clone(); SelfPage.Parent = Main; SelfPage.Visible = false
local HitPage = MainPage:Clone(); HitPage.Parent = Main; HitPage.Visible = false
local EspPage = MainPage:Clone(); EspPage.Parent = Main; EspPage.Visible = false

Instance.new("UIListLayout", MainPage).HorizontalAlignment = "Center"; MainPage.UIListLayout.Padding = UDim.new(0, 8)
Instance.new("UIListLayout", SelfPage).HorizontalAlignment = "Center"; SelfPage.UIListLayout.Padding = UDim.new(0, 8)
Instance.new("UIListLayout", HitPage).HorizontalAlignment = "Center"; HitPage.UIListLayout.Padding = UDim.new(0, 8)
Instance.new("UIListLayout", EspPage).HorizontalAlignment = "Center"; EspPage.UIListLayout.Padding = UDim.new(0, 8)

-- // Tab Creation
local function createTab(name, pos, page)
    local btn = Instance.new("TextButton", TabHolder)
    btn.Size = UDim2.new(0, 80, 1, 0); btn.Position = pos; btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40); btn.Text = name; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = "GothamBold"; Instance.new("UICorner", btn)
    btn.MouseButton1Click:Connect(function()
        MainPage.Visible, SelfPage.Visible, HitPage.Visible, EspPage.Visible = false, false, false, false
        page.Visible = true
    end)
    return btn
end

local MainTab = createTab("MAIN", UDim2.new(0, 0, 0, 0), MainPage); MainTab.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
local S_Tab = createTab("SELF", UDim2.new(0, 85, 0, 0), SelfPage)
local H_Tab = createTab("HITBOX", UDim2.new(0, 170, 0, 0), HitPage)
local E_Tab = createTab("ESP", UDim2.new(0, 255, 0, 0), EspPage)

-- // Main Page Content
local ModeBtn = Instance.new("TextButton", MainPage); ModeBtn.Size = UDim2.new(0, 340, 0, 35); ModeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50); ModeBtn.Text = "MODE: HOLD"; ModeBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", ModeBtn)
ModeBtn.MouseButton1Click:Connect(function() Mode = (Mode == "Hold" and "Toggle" or "Hold"); ModeBtn.Text = "MODE: "..Mode:upper() end)

local PartBtn = ModeBtn:Clone(); PartBtn.Parent = MainPage; PartBtn.Text = "TARGET: HumanoidRootPart"
local ChecksBtn = ModeBtn:Clone(); ChecksBtn.Parent = MainPage; ChecksBtn.Text = "CHECKS"

-- // Self Page Content (Populating missing sections)
local SpeedBtn = ModeBtn:Clone(); SpeedBtn.Parent = SelfPage; SpeedBtn.Text = "WALKSPEED: OFF"
SpeedBtn.MouseButton1Click:Connect(function() selfOptions.speed.enabled = not selfOptions.speed.enabled; SpeedBtn.Text = "WALKSPEED: "..(selfOptions.speed.enabled and "ON" or "OFF") end)

local JumpBtn = ModeBtn:Clone(); JumpBtn.Parent = SelfPage; JumpBtn.Text = "JUMPPOWER: OFF"
JumpBtn.MouseButton1Click:Connect(function() selfOptions.jump.enabled = not selfOptions.jump.enabled; JumpBtn.Text = "JUMPPOWER: "..(selfOptions.jump.enabled and "ON" or "OFF") end)

local FlingBtn = ModeBtn:Clone(); FlingBtn.Parent = SelfPage; FlingBtn.Text = "ANTI-FLING: OFF"
FlingBtn.MouseButton1Click:Connect(function() antiFlingEnabled = not antiFlingEnabled; FlingBtn.Text = "ANTI-FLING: "..(antiFlingEnabled and "ON" or "OFF") end)

-- // Hitbox Page Content
local HitToggle = ModeBtn:Clone(); HitToggle.Parent = HitPage; HitToggle.Text = "HITBOX: OFF"
HitToggle.MouseButton1Click:Connect(function() hitboxEnabled = not hitboxEnabled; HitToggle.Text = "HITBOX: "..(hitboxEnabled and "ON" or "OFF"); reapplyHitboxes() end)

local VizToggle = ModeBtn:Clone(); VizToggle.Parent = HitPage; VizToggle.Text = "VISUALS: OFF"
VizToggle.MouseButton1Click:Connect(function() hitboxVisual = not hitboxVisual; VizToggle.Text = "VISUALS: "..(hitboxVisual and "ON" or "OFF"); reapplyHitboxes() end)

-- // ESP Page Content
local TracerBtn = ModeBtn:Clone(); TracerBtn.Parent = EspPage; TracerBtn.Text = "TRACERS: OFF"
TracerBtn.MouseButton1Click:Connect(function() espOptions.tracers = not espOptions.tracers; TracerBtn.Text = "TRACERS: "..(espOptions.tracers and "ON" or "OFF") end)

local NameBtn = ModeBtn:Clone(); NameBtn.Parent = EspPage; NameBtn.Text = "NAMES: OFF"
NameBtn.MouseButton1Click:Connect(function() espOptions.names = not espOptions.names; NameBtn.Text = "NAMES: "..(espOptions.names and "ON" or "OFF") end)

-- // Main Loop (V23 Logic)
table.insert(_Connections, RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = selfOptions.speed.enabled and 50 or 16
            hum.JumpPower = selfOptions.jump.enabled and 100 or 50
        end
        if antiFlingEnabled then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.AssemblyAngularVelocity = Vector3.zero end
        end
    end

    if Active and isValid(LockedPlayer, false) then 
        local pPart = LockedPlayer.Character[TargetPartName]
        local predPos = pPart.Position + (pPart.Velocity * (Prediction / 100))
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predPos), Smoothing)
    elseif Active then
        Active = false; LockedPlayer = nil
    end
end))

-- // Keybinds
table.insert(_Connections, UIS.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Keybind then
        if Mode == "Hold" then 
            LockedPlayer = findBestTarget()
            Active = true 
        else 
            Active = not Active
            if Active then LockedPlayer = findBestTarget() end
        end
    end
end))

table.insert(_Connections, UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Keybind and Mode == "Hold" then Active = false end
end))

Close.MouseButton1Click:Connect(function()
    for _, c in pairs(_Connections) do c:Disconnect() end
    ScreenGui:Destroy()
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "VERSION V.3.1",
        Text = "This Script was made by jasonsgunz on Github.",
        Icon = "rbxassetid://6031094670",
        Duration = 6
    })
end)
