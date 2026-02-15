local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local applyHitbox
local removeHitbox
local reapplyHitboxes
local speedConn
local jumpConn
local hitboxConn

local player = Players.LocalPlayer
repeat task.wait() until player
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("HitboxTroller") then
    playerGui.HitboxTroller:Destroy()
end

-- GUI SETUP
local gui = Instance.new("ScreenGui")
gui.Name = "HitboxTroller"
gui.Parent = playerGui
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(400, 350)
frame.Position = UDim2.fromScale(0.5,0.5)
frame.AnchorPoint = Vector2.new(0.5,0.5)
frame.BackgroundColor3 = Color3.fromRGB(30,30,35)
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,12)

-- DRAGGING
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false
    end
end)

-- HEADER
local header = Instance.new("TextLabel", frame)
header.Size = UDim2.new(1,0,0,45)
header.BackgroundColor3 = Color3.fromRGB(45,45,50)
header.Text = "HitboxTroller"
header.TextColor3 = Color3.fromRGB(255,255,255)
header.Font = Enum.Font.GothamBold
header.TextSize = 22
Instance.new("UICorner", header).CornerRadius = UDim.new(0,12)

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.fromOffset(30,30)
closeBtn.Position = UDim2.new(1,-36,0,7)
closeBtn.Text = "X"
closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
Instance.new("UICorner", closeBtn)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- SECTIONS
local sections = {"Main","Self"}
local activeSection = "Main"
local sectionButtons = {}
for i,name in ipairs(sections) do
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromOffset(90,28)
    btn.Position = UDim2.fromOffset(10+(i-1)*100,55)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 16
    btn.BackgroundColor3 = Color3.fromRGB(70,70,75)
    Instance.new("UICorner", btn)
    btn.MouseButton1Click:Connect(function()
        activeSection=name
        for _,b in pairs(sectionButtons) do b.BackgroundColor3=Color3.fromRGB(70,70,75) end
        btn.BackgroundColor3=Color3.fromRGB(60,160,60)
        for _,v in pairs(frame:GetChildren()) do
            if v:IsA("Frame") and v:FindFirstChild("SectionTag") then
                v.Visible = (v.SectionTag.Value==activeSection)
            end
        end
    end)
    sectionButtons[i]=btn
end
sectionButtons[1].BackgroundColor3=Color3.fromRGB(60,160,60)

-- MAIN SECTION
local mainFrame = Instance.new("Frame", frame)
mainFrame.Size = UDim2.fromOffset(380,250)
mainFrame.Position = UDim2.fromOffset(10,90)
mainFrame.BackgroundTransparency = 1
local tag = Instance.new("StringValue", mainFrame)
tag.Name = "SectionTag"
tag.Value = "Main"
mainFrame.Visible = true
-- HITBOX VARIABLES --
local hitboxEnabled = false
local hitboxSize = 8
local hitboxVisual = false
local hitboxBillboard = false
local hitboxData = {}
local collisionEnabled = true

-- HITBOX UI
local hitboxToggle = Instance.new("TextButton", mainFrame)
hitboxToggle.Position = UDim2.fromOffset(10,10)
hitboxToggle.Size = UDim2.fromOffset(140,35)
hitboxToggle.Text = "Hitbox: OFF"
hitboxToggle.BackgroundColor3 = Color3.fromRGB(200,50,50)
Instance.new("UICorner", hitboxToggle).CornerRadius = UDim.new(0,6)

local hitboxInput = Instance.new("TextBox", mainFrame)
hitboxInput.Position = UDim2.fromOffset(160,10)
hitboxInput.Size = UDim2.fromOffset(60,35)
hitboxInput.Text = tostring(hitboxSize)
hitboxInput.ClearTextOnFocus = false
hitboxInput.BackgroundColor3 = Color3.fromRGB(50,50,55)
hitboxInput.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", hitboxInput).CornerRadius = UDim.new(0,6)

local visualToggle = Instance.new("TextButton", mainFrame)
visualToggle.Position = UDim2.fromOffset(230,10)
visualToggle.Size = UDim2.fromOffset(140,35)
visualToggle.Text = "Visualizer: OFF"
visualToggle.BackgroundColor3 = Color3.fromRGB(200,50,50)
Instance.new("UICorner", visualToggle).CornerRadius = UDim.new(0,6)

local billboardToggle = Instance.new("TextButton", mainFrame)
billboardToggle.Position = UDim2.fromOffset(10,100)
billboardToggle.Size = UDim2.fromOffset(140,35)
billboardToggle.Text = "Billboard: OFF"
billboardToggle.BackgroundColor3 = Color3.fromRGB(200,50,50)
Instance.new("UICorner", billboardToggle).CornerRadius = UDim.new(0,6)

local collisionToggle = Instance.new("TextButton", mainFrame)
collisionToggle.Position = UDim2.fromOffset(10,55)
collisionToggle.Size = UDim2.fromOffset(140,35)
collisionToggle.Text = "Collision: ON"
collisionToggle.BackgroundColor3 = Color3.fromRGB(60,160,60)
Instance.new("UICorner", collisionToggle).CornerRadius = UDim.new(0,6)

-- FIND BEST HITBOX PART
local function findBestHitboxPart(character)
    if not character then return nil end
    local priority = {"HumanoidRootPart","UpperTorso","LowerTorso","Torso","Head"}
    for _,name in ipairs(priority) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
    for _,v in ipairs(character:GetChildren()) do
        if v:IsA("BasePart") then return v end
    end
end

-- APPLY HITBOX
local function applyHitbox(plr)
    if not hitboxEnabled or plr == player then return end
    local char = plr.Character
    if not char then return end

    local hrp = findBestHitboxPart(char)
    if not hrp then return end
if hitboxData[plr] and hitboxData[plr].conn then
    hitboxData[plr].conn:Disconnect()
end


    if hitboxData[plr] then
        if hitboxData[plr].conn then hitboxData[plr].conn:Disconnect() end
        if hitboxData[plr].viz then hitboxData[plr].viz:Destroy() end
        if hitboxData[plr].billboard then hitboxData[plr].billboard:Destroy() end
    end

    local viz
    local billboard

  if hitboxVisual then
    viz = Instance.new("Part")
    viz.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
    viz.Anchored = true
    viz.CanCollide = false
    viz.Transparency = 0.7
    viz.Color = Color3.fromRGB(255,0,0)
    viz.Material = Enum.Material.Neon
    viz.CastShadow = false
    viz.Parent = workspace

    local followConn
    followConn = RunService.RenderStepped:Connect(function()
        if not hrp or not hrp.Parent then
            viz:Destroy()
            followConn:Disconnect()
            return
        end
        viz.CFrame = hrp.CFrame
    end)

    hitboxData[plr] = hitboxData[plr] or {}
    hitboxData[plr].viz = viz
    hitboxData[plr].vizConn = followConn
end

    if hitboxBillboard then
        billboard = Instance.new("BillboardGui")
        billboard.Parent = hrp
        billboard.Adornee = hrp
        billboard.Size = UDim2.new(4,0,4,0)
        billboard.AlwaysOnTop = true

        local frame = Instance.new("Frame", billboard)
        frame.Size = UDim2.fromScale(1,1)
        frame.BackgroundColor3 = Color3.fromRGB(255,0,0)
        frame.BackgroundTransparency = 0.3
        Instance.new("UICorner", frame)
    end
    
local conn
conn = RunService.RenderStepped:Connect(function()
    if not hrp.Parent then
        if viz then viz:Destroy() end
        if billboard then billboard:Destroy() end
        conn:Disconnect()
        return
    end

    hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
    hrp.CanCollide = collisionEnabled

    if viz then
        viz.CFrame = hrp.CFrame
        viz.Size = hrp.Size
    end
end)
    
    hitboxData[plr] = {conn=conn,viz=viz,billboard=billboard}
end

-- REAPPLY
local function reapplyHitboxes()
    for _,v in pairs(hitboxData) do
        if v.conn then v.conn:Disconnect() end
        if v.viz then v.viz:Destroy() end
        if v.billboard then v.billboard:Destroy() end
    end
    hitboxData = {}
    for _,p in pairs(Players:GetPlayers()) do
        applyHitbox(p)
    end
end

hitboxToggle.MouseButton1Click:Connect(function()
    hitboxEnabled=not hitboxEnabled
    hitboxToggle.Text="Hitbox: "..(hitboxEnabled and "ON" or "OFF")
    hitboxToggle.BackgroundColor3=hitboxEnabled and Color3.fromRGB(60,160,60) or Color3.fromRGB(200,50,50)
    reapplyHitboxes()
end)
hitboxInput.FocusLost:Connect(function()
    local val=tonumber(hitboxInput.Text)
    if val then hitboxSize=val reapplyHitboxes() end
end)
visualToggle.MouseButton1Click:Connect(function()
    hitboxVisual = not hitboxVisual
    visualToggle.Text = "Visualizer: "..(hitboxVisual and "ON" or "OFF")
    visualToggle.BackgroundColor3 =
        hitboxVisual and Color3.fromRGB(60,160,60)
        or Color3.fromRGB(200,50,50)

    reapplyHitboxes()
end)

billboardToggle.MouseButton1Click:Connect(function()
    hitboxBillboard = not hitboxBillboard
    billboardToggle.Text = "Billboard: "..(hitboxBillboard and "ON" or "OFF")
    billboardToggle.BackgroundColor3 =
        hitboxBillboard and Color3.fromRGB(60,160,60)
        or Color3.fromRGB(200,50,50)

    reapplyHitboxes()
end)

collisionToggle.MouseButton1Click:Connect(function()
    collisionEnabled = not collisionEnabled
    collisionToggle.Text = "Collision: "..(collisionEnabled and "ON" or "OFF")
    collisionToggle.BackgroundColor3 =
        collisionEnabled and Color3.fromRGB(60,160,60)
        or Color3.fromRGB(200,50,50)

    reapplyHitboxes()
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(0.1) applyHitbox(p) end)
end)
for _,p in pairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        task.wait(0.1)
        applyHitbox(p)
    end)
end

-- SELF SECTION
local selfFrame = Instance.new("Frame",frame)
selfFrame.Size=UDim2.fromOffset(380,250)
selfFrame.Position=UDim2.fromOffset(10,90)
selfFrame.BackgroundTransparency = 1
local tag2=Instance.new("StringValue",selfFrame)
tag2.Name="SectionTag"
tag2.Value="Self"
selfFrame.Visible = false

local selfOptions={
    speed={value=16,enabled=false,key=Enum.KeyCode.T},
    jump={value=50,enabled=false,key=Enum.KeyCode.Y},
    fly={value=1,enabled=false,key=Enum.KeyCode.U} -- DEFAULT FLY SPEED = 1
}

local yStart=10
for name,opt in pairs(selfOptions) do
    local toggle = Instance.new("TextButton",selfFrame)
    toggle.Position = UDim2.fromOffset(10,yStart)
    toggle.Size = UDim2.fromOffset(140,35)
    toggle.Text = name:sub(1,1):upper()..name:sub(2)..": OFF"
    toggle.BackgroundColor3 = Color3.fromRGB(200,50,50)
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,6)
    opt.toggleBtn = toggle

    local keyBtn = Instance.new("TextButton",selfFrame)
    keyBtn.Position = UDim2.fromOffset(160,yStart)
    keyBtn.Size = UDim2.fromOffset(60,35)
    keyBtn.Text = opt.key.Name
    keyBtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0,6)
    opt.keyBtn = keyBtn

    local powerBox = Instance.new("TextBox",selfFrame)
    powerBox.Position = UDim2.fromOffset(230,yStart)
    powerBox.Size = UDim2.fromOffset(60,35)
    powerBox.Text = tostring(opt.value)
    powerBox.ClearTextOnFocus=false
    powerBox.BackgroundColor3 = Color3.fromRGB(50,50,55)
    powerBox.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", powerBox).CornerRadius=UDim.new(0,6)
    opt.powerBox = powerBox

    yStart=yStart+45
end

local function updateBtn(btn,state)
    btn.BackgroundColor3 = state and Color3.fromRGB(60,160,60) or Color3.fromRGB(200,50,50)

    if state then
        btn.Text = btn.Text:gsub("OFF","ON")
    else
        btn.Text = btn.Text:gsub("ON","OFF")
    end
end


for _,opt in pairs(selfOptions) do
    opt.toggleBtn.MouseButton1Click:Connect(function()
        opt.enabled = not opt.enabled
        updateBtn(opt.toggleBtn,opt.enabled)
    end)
    opt.powerBox.FocusLost:Connect(function()
        local val=tonumber(opt.powerBox.Text)
        if val then opt.value=val end
    end)
end

UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    for _,opt in pairs(selfOptions) do
        if input.KeyCode==opt.key then
            opt.enabled = not opt.enabled
            updateBtn(opt.toggleBtn,opt.enabled)
        end
    end
end)

-- SPEED & JUMP APPLY LOOP
RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end

    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return end

    -- SPEED
    if selfOptions.speed.enabled then
        hum.WalkSpeed = tonumber(selfOptions.speed.powerBox.Text) or selfOptions.speed.value
    else
        hum.WalkSpeed = 16
    end

    -- JUMP
    if selfOptions.jump.enabled then
        hum.JumpPower = tonumber(selfOptions.jump.powerBox.Text) or selfOptions.jump.value
        hum.UseJumpPower = true
    else
        hum.JumpPower = 50
        hum.UseJumpPower = true
    end
end)

-- === FLY SCRIPT INTEGRATED (FIXED CAMERA-RELATIVE) ===
local flying = false
local tpwalking = false
local ctrl = {f=0,b=0,l=0,r=0}

local function startFly()
    local plr = Players.LocalPlayer
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not hum or not root then return end

    plr.Character.Animate.Disabled = true
    for _,v in next, hum:GetPlayingAnimationTracks() do v:AdjustSpeed(0) end

    hum.PlatformStand = true
    flying = true
    tpwalking = true

    local bg = Instance.new("BodyGyro", root)
    bg.P = 9e4
    bg.MaxTorque = Vector3.new(9e9,9e9,9e9)
    bg.CFrame = root.CFrame

    local bv = Instance.new("BodyVelocity", root)
    bv.MaxForce = Vector3.new(9e9,9e9,9e9)
    bv.Velocity = Vector3.new(0,0,0)

    while tpwalking and char.Parent and hum.Parent do
        RunService.RenderStepped:Wait()
        local moveSpeed = (tonumber(selfOptions.fly.powerBox.Text) or 1)*30

        -- Fixed camera-relative movement with Y movement
        local moveVec = Vector3.new(ctrl.r-ctrl.l,0,ctrl.f-ctrl.b)
        if moveVec.Magnitude>0 then moveVec = moveVec.Unit end

        local camCF = workspace.CurrentCamera.CFrame
        local camLook = camCF.LookVector.Unit
        local camRight = camCF.RightVector.Unit

        -- velocity includes camera tilt for forward/back
        local velocity = (camLook*moveVec.Z + camRight*moveVec.X)*moveSpeed
        bv.Velocity = velocity
        bg.CFrame = camCF
    end

    tpwalking = false
    flying = false
    bv:Destroy()
    bg:Destroy()
    hum.PlatformStand = false
    plr.Character.Animate.Disabled = false
    for _,v in next, hum:GetPlayingAnimationTracks() do v:AdjustSpeed(1) end
end

local function stopFly()
    tpwalking=false
end

-- FLY TOGGLE
selfOptions.fly.toggleBtn.MouseButton1Click:Connect(function()
    selfOptions.fly.enabled = not selfOptions.fly.enabled
    selfOptions.fly.toggleBtn.BackgroundColor3 = selfOptions.fly.enabled and Color3.fromRGB(60,160,60) or Color3.fromRGB(200,50,50)
    selfOptions.fly.toggleBtn.Text = "Fly: "..(selfOptions.fly.enabled and "ON" or "OFF")

    if selfOptions.fly.enabled and not flying then
        spawn(startFly)
    elseif not selfOptions.fly.enabled and flying then
        stopFly()
    end
end)

-- FLY WASD CONTROLS
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.W then ctrl.f=1 end
    if input.KeyCode == Enum.KeyCode.S then ctrl.b=1 end
    if input.KeyCode == Enum.KeyCode.A then ctrl.l=-1 end
    if input.KeyCode == Enum.KeyCode.D then ctrl.r=1 end
end)
UserInputService.InputEnded:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.W then ctrl.f=0 end
    if input.KeyCode == Enum.KeyCode.S then ctrl.b=0 end
    if input.KeyCode == Enum.KeyCode.A then ctrl.l=0 end
    if input.KeyCode == Enum.KeyCode.D then ctrl.r=0 end
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "LOADED!",
        Text = "This Script was made by jasonsgunz on Github. Show Love!",
        Icon = "rbxassetid://6031094670",
        Duration = 6
    })
end)
