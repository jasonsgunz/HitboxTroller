local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Active = false
local Keybind = Enum.KeyCode.Unknown
local TargetPartName = "HumanoidRootPart"
local Mode = "Hold"
local Prediction = 0 
local Smoothing = 1.0
local SettingKey = false
local LockedPlayer = nil 
local Checks = { Alive = false, Team = false, Wall = false }

local selfOptions = {
    speed = {value = 16, enabled = false, key = Enum.KeyCode.Unknown, setting = false},
    jump = {value = 50, enabled = false, key = Enum.KeyCode.Unknown, setting = false},
    fly = {value = 1, enabled = false, key = Enum.KeyCode.Unknown, setting = false}
}
local espOptions = { tracers = false, names = false, dot = false }

local antiFlingEnabled = false
local lastSafeCF = CFrame.new()
local teleportThreshold = 20    
local tpwalking = false
local ctrl = {f=0,b=0,l=0,r=0}

local hitboxEnabled = false
local hitboxSize = 8
local hitboxVisual = false
local hitboxData = {}
local collisionEnabled = false

local espCache = {} 
local _Connections = {}

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

local function isValid(p, skipWallCheck) 
    if not p or not p.Character or not p.Character:FindFirstChild(TargetPartName) then return false end
    local targetPart = p.Character[TargetPartName]
    local hum = p.Character:FindFirstChildOfClass("Humanoid")

    if Checks.Alive and (not hum or hum.Health <= 0) then return false end
    if Checks.Team and p.Team == LocalPlayer.Team then return false end
    if not skipWallCheck and Checks.Wall and not isVisible(targetPart) then return false end

    return true
end

local function findBestTarget()
    local target, dist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isValid(p, false) then
            local pos, onScreen = Camera:WorldToViewportPoint(p.Character[TargetPartName].Position)
            if onScreen then
                local mag = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                if mag < dist then dist = mag; target = p end
            end
        end
    end
    return target
end

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

    if hitboxData[plr] then
        if hitboxData[plr].conn then hitboxData[plr].conn:Disconnect() end
        if hitboxData[plr].viz then hitboxData[plr].viz:Destroy() end
    end

    local viz
    if hitboxVisual then
        viz = Instance.new("Part")
        viz.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        viz.Anchored = true; viz.CanCollide = false; viz.Transparency = 0.7
        viz.Color = Color3.fromRGB(255,0,0); viz.Material = Enum.Material.Neon; viz.Parent = workspace
    end

    local conn = RunService.RenderStepped:Connect(function()
        if not hrp or not hrp.Parent then
            if viz then viz:Destroy() end
            return
        end
        hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        hrp.CanCollide = collisionEnabled
        if viz then viz.CFrame = hrp.CFrame; viz.Size = hrp.Size end
    end)
    hitboxData[plr] = {conn=conn,viz=viz}
end

local function reapplyHitboxes()
    for _,v in pairs(hitboxData) do
        if v.conn then v.conn:Disconnect() end
        if v.viz then v.viz:Destroy() end
    end
    hitboxData = {}
    if not hitboxEnabled then
        for _,p in pairs(Players:GetPlayers()) do
            local char = p.Character
            if char then
                local hrp = findBestHitboxPart(char)
                if hrp then hrp.Size = Vector3.new(2,2,1); hrp.CanCollide = true end
            end
        end
        return
    end
    for _,p in pairs(Players:GetPlayers()) do applyHitbox(p) end
end

local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "Universal_V23_FinalFix"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.IgnoreGuiInset = true 

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 380, 0, 300); Main.Position = UDim2.new(0.5, -190, 0.5, -150)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Main.Active = true; Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

local TracerContainer = Instance.new("Frame", ScreenGui)
TracerContainer.Size = UDim2.new(1,0,1,0); TracerContainer.BackgroundTransparency = 1; TracerContainer.Visible = true

local DropdownFrame = Instance.new("Frame", ScreenGui)
DropdownFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35); DropdownFrame.Visible = false; DropdownFrame.ZIndex = 100
Instance.new("UICorner", DropdownFrame)
Instance.new("UIListLayout", DropdownFrame).HorizontalAlignment = "Center"

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, -60, 0, 35); Title.Position = UDim2.new(0, 15, 0, 0); Title.BackgroundTransparency = 1
Title.Text = "UniversalAimbot"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = "GothamBold"; Title.TextSize = 14; Title.TextXAlignment = "Left"

local Close = Instance.new("TextButton", Main)
Close.Size = UDim2.new(0, 25, 0, 25); Close.Position = UDim2.new(1, -30, 0, 5); Close.BackgroundColor3 = Color3.fromRGB(200, 50, 50); Close.Text = "X"; Close.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 4)

local TabHolder = Instance.new("Frame", Main)
TabHolder.Size = UDim2.new(1, -20, 0, 30); TabHolder.Position = UDim2.new(0, 10, 0, 35); TabHolder.BackgroundTransparency = 1

local MainTab = Instance.new("TextButton", TabHolder)
MainTab.Size = UDim2.new(0, 80, 1, 0); MainTab.BackgroundColor3 = Color3.fromRGB(50, 50, 60); MainTab.Text = "MAIN"; MainTab.TextColor3 = Color3.new(1, 1, 1); MainTab.Font = "GothamBold"; Instance.new("UICorner", MainTab)

local SelfTab = MainTab:Clone(); SelfTab.Parent = TabHolder; SelfTab.Position = UDim2.new(0, 85, 0, 0); SelfTab.Text = "SELF"; SelfTab.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
local HitTab = MainTab:Clone(); HitTab.Parent = TabHolder; HitTab.Position = UDim2.new(0, 170, 0, 0); HitTab.Text = "HITBOX"; HitTab.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
local EspTab = MainTab:Clone(); EspTab.Parent = TabHolder; EspTab.Position = UDim2.new(0, 255, 0, 0); EspTab.Text = "ESP"; EspTab.BackgroundColor3 = Color3.fromRGB(35, 35, 40)

local MainPage = Instance.new("ScrollingFrame", Main)
MainPage.Size = UDim2.new(1, 0, 1, -75); MainPage.Position = UDim2.new(0, 0, 0, 75); MainPage.BackgroundTransparency = 1; MainPage.BorderSizePixel = 0; MainPage.CanvasSize = UDim2.new(0, 0, 0, 360); MainPage.ScrollBarThickness = 0
local SelfPage = MainPage:Clone(); SelfPage.Parent = Main; SelfPage.Visible = false
local HitPage = MainPage:Clone(); HitPage.Parent = Main; HitPage.Visible = false
local EspPage = MainPage:Clone(); EspPage.Parent = Main; EspPage.Visible = false

Instance.new("UIListLayout", MainPage).HorizontalAlignment = "Center"; MainPage.UIListLayout.Padding = UDim.new(0, 8)
Instance.new("UIListLayout", SelfPage).HorizontalAlignment = "Center"; SelfPage.UIListLayout.Padding = UDim.new(0, 8)
Instance.new("UIListLayout", HitPage).HorizontalAlignment = "Center"; HitPage.UIListLayout.Padding = UDim.new(0, 15)
Instance.new("UIListLayout", EspPage).HorizontalAlignment = "Center"; EspPage.UIListLayout.Padding = UDim.new(0, 8)

local Sliding = false
local PredRow = Instance.new("Frame", MainPage); PredRow.Size = UDim2.new(0, 340, 0, 45); PredRow.BackgroundTransparency = 1
local PredTxt = Instance.new("TextLabel", PredRow); PredTxt.Size = UDim2.new(1, 0, 0, 20); PredTxt.BackgroundTransparency = 1; PredTxt.Text = "Prediction: 0%"; PredTxt.TextColor3 = Color3.new(1,1,1); PredTxt.Font = "Gotham"; PredTxt.TextSize = 12
local SliderBack = Instance.new("Frame", PredRow); SliderBack.Size = UDim2.new(1, -20, 0, 10); SliderBack.Position = UDim2.new(0, 10, 0, 25); SliderBack.BackgroundColor3 = Color3.fromRGB(40, 40, 45); Instance.new("UICorner", SliderBack)
local SliderFill = Instance.new("Frame", SliderBack); SliderFill.Size = UDim2.new(0, 0, 1, 0); SliderFill.BackgroundColor3 = Color3.fromRGB(60, 160, 60); Instance.new("UICorner", SliderFill)

SliderBack.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then Sliding = true end end)
UIS.InputChanged:Connect(function(input) 
    if Sliding and input.UserInputType == Enum.UserInputType.MouseMovement then 
        local pos = math.clamp((input.Position.X - SliderBack.AbsolutePosition.X) / SliderBack.AbsoluteSize.X, 0, 1)
        SliderFill.Size = UDim2.new(pos, 0, 1, 0); Prediction = math.floor(pos * 100); PredTxt.Text = "Prediction: " .. Prediction .. "%"
    end 
end)

local SlidingM = false
local MagRow = Instance.new("Frame", MainPage); MagRow.Size = UDim2.new(0, 340, 0, 45); MagRow.BackgroundTransparency = 1
local MagTxt = Instance.new("TextLabel", MagRow); MagTxt.Size = UDim2.new(1, 0, 0, 20); MagTxt.BackgroundTransparency = 1; MagTxt.Text = "Lock-On Smoothning: 1"; MagTxt.TextColor3 = Color3.new(1,1,1); MagTxt.Font = "Gotham"; MagTxt.TextSize = 12
local SliderBackM = Instance.new("Frame", MagRow); SliderBackM.Size = UDim2.new(1, -20, 0, 10); SliderBackM.Position = UDim2.new(0, 10, 0, 25); SliderBackM.BackgroundColor3 = Color3.fromRGB(40, 40, 45); Instance.new("UICorner", SliderBackM)
local SliderFillM = Instance.new("Frame", SliderBackM); SliderFillM.Size = UDim2.new(0, 0, 1, 0); SliderFillM.BackgroundColor3 = Color3.fromRGB(60, 160, 60); Instance.new("UICorner", SliderFillM)

SliderBackM.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then SlidingM = true end end)
UIS.InputChanged:Connect(function(input) 
    if SlidingM and input.UserInputType == Enum.UserInputType.MouseMovement then 
local pos = math.clamp((input.Position.X - SliderBackM.AbsolutePosition.X) / SliderBackM.AbsoluteSize.X, 0, 1)
SliderFillM.Size = UDim2.new(pos, 0, 1, 0)

local val = math.floor(pos * 9) + 1
MagTxt.Text = "Lock-On Smoothning: " .. val 
Smoothing = (11 - val) / 10 
    end 
end)

UIS.InputEnded:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        Sliding = false 
        SlidingM = false
    end 
end)

local BindRow = Instance.new("Frame", MainPage); BindRow.Size = UDim2.new(0, 340, 0, 35); BindRow.BackgroundTransparency = 1
local BindTxt = Instance.new("TextLabel", BindRow); BindTxt.Size = UDim2.new(0, 100, 1, 0); BindTxt.BackgroundTransparency = 1; BindTxt.Text = "Keybind:"; BindTxt.TextColor3 = Color3.new(1,1,1); BindTxt.Font = "Gotham"; BindTxt.TextXAlignment = "Left"
local BindBtn = Instance.new("TextButton", BindRow); BindBtn.Size = UDim2.new(0, 80, 0, 25); BindBtn.Position = UDim2.new(0, 70, 0.5, -12); BindBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50); BindBtn.Text = "[NONE]"; BindBtn.TextColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", BindBtn)
BindBtn.MouseButton1Click:Connect(function() SettingKey = true; BindBtn.Text = "[...]" end)

local ModeBtn = Instance.new("TextButton", MainPage); ModeBtn.Size = UDim2.new(0, 340, 0, 35); ModeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50); ModeBtn.Text = "MODE: HOLD"; ModeBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", ModeBtn)
ModeBtn.MouseButton1Click:Connect(function() Mode = (Mode == "Hold" and "Toggle" or "Hold"); ModeBtn.Text = "MODE: "..Mode:upper() end)

local PartBtn = ModeBtn:Clone(); PartBtn.Parent = MainPage; PartBtn.Text = "TARGET: HumanoidRootPart"
local ChecksBtn = ModeBtn:Clone(); ChecksBtn.Parent = MainPage; ChecksBtn.Text = "CHECKS"

local function OpenDrop(btn, height)
    for _, v in pairs(DropdownFrame:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    DropdownFrame.Position = UDim2.fromOffset(btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2) - 100, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 5)
    DropdownFrame.Size = UDim2.fromOffset(200, height); DropdownFrame.Visible = not DropdownFrame.Visible
end

PartBtn.MouseButton1Click:Connect(function() 
    OpenDrop(PartBtn, 105) 
    for _, n in pairs({"HumanoidRootPart", "UpperTorso", "Head"}) do 
        local b = Instance.new("TextButton", DropdownFrame); b.Size = UDim2.new(1, 0, 0, 35); b.BackgroundColor3 = Color3.fromRGB(40, 40, 45); b.Text = n; b.TextColor3 = Color3.new(1,1,1); b.ZIndex = 101
        b.MouseButton1Click:Connect(function() TargetPartName = n; PartBtn.Text = "TARGET: "..n; DropdownFrame.Visible = false end)
    end 
end)

ChecksBtn.MouseButton1Click:Connect(function() 
    local hasTeams = #Teams:GetTeams() > 0
    OpenDrop(ChecksBtn, hasTeams and 105 or 70) 
    local function addC(txt, key)
        local b = Instance.new("TextButton", DropdownFrame); b.Size = UDim2.new(1, 0, 0, 35); b.BackgroundColor3 = Color3.fromRGB(40, 40, 45); b.ZIndex = 101
        b.Text = txt..": "..(Checks[key] and "ON" or "OFF"); b.TextColor3 = Checks[key] and Color3.new(0,1,0) or Color3.new(1,0,0)
        b.MouseButton1Click:Connect(function() Checks[key] = not Checks[key]; b.Text = txt..": "..(Checks[key] and "ON" or "OFF"); b.TextColor3 = Checks[key] and Color3.new(0,1,0) or Color3.new(1,0,0) end)
    end
    addC("ALIVE", "Alive"); if hasTeams then addC("TEAM", "Team") end; addC("WALL", "Wall")
end)

local function updateSelfBtn(btn, state, name)
    btn.BackgroundColor3 = state and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(200, 50, 50)
    btn.Text = name:sub(1,1):upper()..name:sub(2)..": "..(state and "ON" or "OFF")
end

function startFly()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    hum.PlatformStand = true; tpwalking = true
    local bg = Instance.new("BodyGyro", root); bg.P = 9e4; bg.MaxTorque = Vector3.new(9e9,9e9,9e9); bg.CFrame = root.CFrame
    local bv = Instance.new("BodyVelocity", root); bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.Velocity = Vector3.zero
    while tpwalking and char.Parent and ScreenGui.Parent do
        RunService.RenderStepped:Wait()
        local moveSpeed = (tonumber(selfOptions.fly.powerBox.Text) or selfOptions.fly.value)*30
        bv.Velocity = ((Camera.CFrame.LookVector * (ctrl.f-ctrl.b)) + (Camera.CFrame.RightVector * (ctrl.r-ctrl.l))) * moveSpeed
        bg.CFrame = Camera.CFrame
    end
    bv:Destroy(); bg:Destroy(); if hum then hum.PlatformStand = false end
end

for name, opt in pairs(selfOptions) do
    local row = Instance.new("Frame", SelfPage); row.Size = UDim2.new(0, 340, 0, 40); row.BackgroundTransparency = 1
    local toggle = Instance.new("TextButton", row); toggle.Size = UDim2.new(0, 140, 0, 35); updateSelfBtn(toggle, opt.enabled, name); Instance.new("UICorner", toggle)
    local kBtn = Instance.new("TextButton", row); kBtn.Size = UDim2.new(0, 60, 0, 35); kBtn.Position = UDim2.fromOffset(150, 0); kBtn.Text = "[NONE]"; Instance.new("UICorner", kBtn)
    local val = Instance.new("TextBox", row); val.Size = UDim2.new(0, 60, 0, 35); val.Position = UDim2.fromOffset(220, 0); val.Text = tostring(opt.value); Instance.new("UICorner", val)

    toggle.MouseButton1Click:Connect(function() 
        opt.enabled = not opt.enabled; updateSelfBtn(toggle, opt.enabled, name)
        if name == "fly" then if opt.enabled then task.spawn(startFly) else tpwalking = false end end
    end)
    kBtn.MouseButton1Click:Connect(function() opt.setting = true; kBtn.Text = "[...]" end)
    val.FocusLost:Connect(function() local n = tonumber(val.Text) if n then opt.value = n end end)
    opt.toggleBtn = toggle; opt.keyBtn = kBtn; opt.powerBox = val
end

local antiFlingBtn = ModeBtn:Clone(); antiFlingBtn.Parent = SelfPage; antiFlingBtn.Text = "Anti-Fling: OFF"; antiFlingBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
antiFlingBtn.MouseButton1Click:Connect(function()
    antiFlingEnabled = not antiFlingEnabled
    antiFlingBtn.Text = "Anti-Fling: "..(antiFlingEnabled and "ON" or "OFF")
    antiFlingBtn.BackgroundColor3 = antiFlingEnabled and Color3.fromRGB(60,160,60) or Color3.fromRGB(200,50,50)
end)

local function updateHitBtn(btn, state, txt)
    btn.BackgroundColor3 = state and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(200, 50, 50)
    btn.Text = txt .. ": " .. (state and "ON" or "OFF")
end

local hTog = Instance.new("TextButton", HitPage); hTog.Size = UDim2.new(0, 340, 0, 35); updateHitBtn(hTog, hitboxEnabled, "Hitbox"); Instance.new("UICorner", hTog)
hTog.MouseButton1Click:Connect(function() hitboxEnabled = not hitboxEnabled; updateHitBtn(hTog, hitboxEnabled, "Hitbox"); reapplyHitboxes() end)

local hSize = Instance.new("TextBox", HitPage); hSize.Size = UDim2.new(0, 340, 0, 35); hSize.BackgroundColor3 = Color3.fromRGB(45, 45, 50); hSize.Text = tostring(hitboxSize); hSize.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", hSize)
hSize.FocusLost:Connect(function() local n = tonumber(hSize.Text) if n then hitboxSize = n; reapplyHitboxes() end end)

local vTog = Instance.new("TextButton", HitPage); vTog.Size = UDim2.new(0, 340, 0, 35); updateHitBtn(vTog, hitboxVisual, "Visualizer"); Instance.new("UICorner", vTog)
vTog.MouseButton1Click:Connect(function() hitboxVisual = not hitboxVisual; updateHitBtn(vTog, hitboxVisual, "Visualizer"); reapplyHitboxes() end)

local cTog = Instance.new("TextButton", HitPage); cTog.Size = UDim2.new(0, 340, 0, 35); updateHitBtn(cTog, collisionEnabled, "Collision"); Instance.new("UICorner", cTog)
cTog.MouseButton1Click:Connect(function() collisionEnabled = not collisionEnabled; updateHitBtn(cTog, collisionEnabled, "Collision"); reapplyHitboxes() end)

local function updateEspBtn(btn, state, txt)
    btn.BackgroundColor3 = state and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(200, 50, 50)
    btn.Text = txt .. ": " .. (state and "ON" or "OFF")
end

local tracerTog = Instance.new("TextButton", EspPage); tracerTog.Size = UDim2.new(0, 340, 0, 35); updateEspBtn(tracerTog, espOptions.tracers, "Tracers"); Instance.new("UICorner", tracerTog)
tracerTog.MouseButton1Click:Connect(function() espOptions.tracers = not espOptions.tracers; updateEspBtn(tracerTog, espOptions.tracers, "Tracers") end)

local nameTog = Instance.new("TextButton", EspPage); nameTog.Size = UDim2.new(0, 340, 0, 35); updateEspBtn(nameTog, espOptions.names, "Name ESP"); Instance.new("UICorner", nameTog)
nameTog.MouseButton1Click:Connect(function() espOptions.names = not espOptions.names; updateEspBtn(nameTog, espOptions.names, "Name ESP") end)

local dotTog = Instance.new("TextButton", EspPage); dotTog.Size = UDim2.new(0, 340, 0, 35); updateEspBtn(dotTog, espOptions.dot, "Dot ESP"); Instance.new("UICorner", dotTog)
dotTog.MouseButton1Click:Connect(function() espOptions.dot = not espOptions.dot; updateEspBtn(dotTog, espOptions.dot, "Dot ESP") end)

table.insert(_Connections, RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")

    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = selfOptions.speed.enabled and selfOptions.speed.value or 16
            hum.JumpPower = selfOptions.jump.enabled and selfOptions.jump.value or 50
        end
        if antiFlingEnabled and myRoot then
            local currentCF = myRoot.CFrame
            if (currentCF.Position - lastSafeCF.Position).Magnitude > teleportThreshold and not tpwalking then
                myRoot.CFrame = lastSafeCF; myRoot.AssemblyLinearVelocity = Vector3.zero
            else lastSafeCF = currentCF end
            myRoot.AssemblyAngularVelocity = Vector3.zero 
            local vel = myRoot.AssemblyLinearVelocity
            if vel.Magnitude > 100 then myRoot.AssemblyLinearVelocity = Vector3.new(math.clamp(vel.X, -50, 50), vel.Y, math.clamp(vel.Z, -50, 50)) end
            for _, v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanTouch = false end end
            if hum then hum.Sit = false end
        elseif myRoot then lastSafeCF = myRoot.CFrame end
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local head = p.Character:FindFirstChild("Head")
            local show = not (Checks.Team and p.Team == LocalPlayer.Team)
            if not espCache[p] then espCache[p] = {} end
            local cache = espCache[p]

            if show and root and (espOptions.tracers or espOptions.names or espOptions.dot) then
                local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                if espOptions.tracers and myRoot then
                    local myPos, myOnScreen = Camera:WorldToViewportPoint(myRoot.Position)
                    if onScreen and myOnScreen then
                        if not cache.line then cache.line = Instance.new("Frame", TracerContainer); cache.line.BackgroundColor3 = Color3.new(1,1,1); cache.line.BorderSizePixel = 0; cache.line.AnchorPoint = Vector2.new(0.5, 0.5) end
                        local p1, p2 = Vector2.new(myPos.X, myPos.Y), Vector2.new(pos.X, pos.Y)
                        cache.line.Size = UDim2.new(0, (p2 - p1).Magnitude, 0, 1.5); cache.line.Position = UDim2.new(0, (p1.X + p2.X) / 2, 0, (p1.Y + p2.Y) / 2); cache.line.Rotation = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X)); cache.line.Visible = true
                    else if cache.line then cache.line.Visible = false end end
                else if cache.line then cache.line.Visible = false end end

                if espOptions.names and head then
                    if not cache.name then cache.name = Instance.new("BillboardGui", TracerContainer); cache.name.Size = UDim2.new(0,200,0,50); cache.name.AlwaysOnTop = true; local t = Instance.new("TextLabel", cache.name); t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1; t.TextColor3 = Color3.new(1,1,1); t.TextStrokeTransparency = 0; t.Text = p.DisplayName; end
                    cache.name.Adornee = head
                    cache.name.Enabled = true
                else if cache.name then cache.name.Enabled = false end end

                if espOptions.dot and root then
                    if not cache.dot then cache.dot = Instance.new("BillboardGui", TracerContainer); cache.dot.Size = UDim2.new(0,10,0,10); cache.dot.AlwaysOnTop = true; local f = Instance.new("Frame", cache.dot); f.Size = UDim2.new(1,0,1,0); f.BackgroundColor3 = Color3.fromRGB(255,50,50); Instance.new("UICorner", f, UDim.new(1,0)); end
                    cache.dot.Adornee = root
                    cache.dot.Enabled = true
                else if cache.dot then cache.dot.Enabled = false end end
            else
                if cache.line then cache.line.Visible = false end
                if cache.name then cache.name.Enabled = false end
                if cache.dot then cache.dot.Enabled = false end
            end
        end
    end

    if Active then
        if isValid(LockedPlayer, true) then
            local pPart = LockedPlayer.Character[TargetPartName]
            local targetCF = CFrame.new(Camera.CFrame.Position, pPart.Position + (pPart.Velocity * (Prediction / 100)))
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, Smoothing)
        else
            Active = false
            LockedPlayer = nil
        end
    else
        LockedPlayer = nil
    end
end))

table.insert(_Connections, UIS.InputBegan:Connect(function(input, gp)
    if SettingKey then Keybind = input.KeyCode; BindBtn.Text = "["..input.KeyCode.Name:upper().."]"; SettingKey = false; return end

    for name, opt in pairs(selfOptions) do 
        if opt.setting then opt.key = input.KeyCode; opt.keyBtn.Text = "["..input.KeyCode.Name:upper().."]"; opt.setting = false; return end 
        if not gp and input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == opt.key then 
            opt.enabled = not opt.enabled; updateSelfBtn(opt.toggleBtn, opt.enabled, name)
            if name == "fly" then if opt.enabled then task.spawn(startFly) else tpwalking = false end end
        end
    end

    if not gp then 
        if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == Keybind then 
            if Mode == "Hold" then 
                LockedPlayer = findBestTarget()
                Active = (LockedPlayer ~= nil) 
            else 
                Active = not Active
                if Active then
                    LockedPlayer = findBestTarget()
                    if not LockedPlayer then Active = false end 
                end
            end 
        end
        if input.KeyCode == Enum.KeyCode.W then ctrl.f=1 elseif input.KeyCode == Enum.KeyCode.S then ctrl.b=1 end
        if input.KeyCode == Enum.KeyCode.A then ctrl.l=1 elseif input.KeyCode == Enum.KeyCode.D then ctrl.r=1 end
    end
end))

table.insert(_Connections, UIS.InputEnded:Connect(function(input)
    if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == Keybind and Mode == "Hold" then Active = false; LockedPlayer = nil end
    if input.KeyCode == Enum.KeyCode.W then ctrl.f=0 elseif input.KeyCode == Enum.KeyCode.S then ctrl.b=0 end
    if input.KeyCode == Enum.KeyCode.A then ctrl.l=0 elseif input.KeyCode == Enum.KeyCode.D then ctrl.r=0 end
end))

local function switch(btn, page)
    MainPage.Visible, SelfPage.Visible, HitPage.Visible, EspPage.Visible = false, false, false, false
    MainTab.BackgroundColor3, SelfTab.BackgroundColor3, HitTab.BackgroundColor3, EspTab.BackgroundColor3 = Color3.fromRGB(35, 35, 40), Color3.fromRGB(35, 35, 40), Color3.fromRGB(35, 35, 40), Color3.fromRGB(35, 35, 40)
    page.Visible, btn.BackgroundColor3, DropdownFrame.Visible = true, Color3.fromRGB(50, 50, 60), false
end
MainTab.MouseButton1Click:Connect(function() switch(MainTab, MainPage) end)
SelfTab.MouseButton1Click:Connect(function() switch(SelfTab, SelfPage) end)
HitTab.MouseButton1Click:Connect(function() switch(HitTab, HitPage) end)
EspTab.MouseButton1Click:Connect(function() switch(EspTab, EspPage) end)

local dragging, dragStart, startPos
Main.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 and not Sliding and not SlidingM then dragging = true; dragStart = input.Position; startPos = Main.Position end end)
UIS.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart; Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y); DropdownFrame.Visible = false end end)
UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

Close.MouseButton1Click:Connect(function()
    hitboxEnabled, tpwalking, antiFlingEnabled = false, false, false; reapplyHitboxes() 
    for _, c in pairs(_Connections) do c:Disconnect() end; ScreenGui:Destroy()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
end)

Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(0.1); applyHitbox(p) end) end)
for _,p in pairs(Players:GetPlayers()) do p.CharacterAdded:Connect(function() task.wait(0.1); applyHitbox(p) end) end

Players.PlayerRemoving:Connect(function(p)
    if espCache[p] then
        if espCache[p].line then espCache[p].line:Destroy() end
        if espCache[p].name then espCache[p].name:Destroy() end
        if espCache[p].dot then espCache[p].dot:Destroy() end
        espCache[p] = nil
    end
    if hitboxData[p] then
        if hitboxData[p].conn then hitboxData[p].conn:Disconnect() end
        if hitboxData[p].viz then hitboxData[p].viz:Destroy() end
        hitboxData[p] = nil
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    selfOptions.fly.enabled = false
    tpwalking = false
    updateSelfBtn(selfOptions.fly.toggleBtn, false, "fly")
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "VERSION V.3.2",
        Text = "This Script was made by jasonsgunz on Github.",
        Icon = "rbxassetid://6031094670",
        Duration = 6
    })
end)
