-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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

-- SELF SECTION
local selfFrame = Instance.new("Frame", frame)
selfFrame.Size = UDim2.fromOffset(380,250)
selfFrame.Position = UDim2.fromOffset(10,90)
selfFrame.BackgroundTransparency = 1
selfFrame.Visible = false
local tag2 = Instance.new("StringValue", selfFrame)
tag2.Name = "SectionTag"
tag2.Value = "Self"

-- HITBOX VARIABLES
local hitboxEnabled=false
local hitboxSize=4
local hitboxVisual=false
local hitboxCollision=false
local hitboxData={}

-- HITBOX UI
local hitboxToggle = Instance.new("TextButton",mainFrame)
hitboxToggle.Position = UDim2.fromOffset(10,10)
hitboxToggle.Size = UDim2.fromOffset(140,35)
hitboxToggle.Text="Hitbox: OFF"
hitboxToggle.BackgroundColor3=Color3.fromRGB(200,50,50)
Instance.new("UICorner",hitboxToggle).CornerRadius=UDim.new(0,6)

local visualToggle = Instance.new("TextButton",mainFrame)
visualToggle.Position = UDim2.fromOffset(160,10)
visualToggle.Size = UDim2.fromOffset(140,35)
visualToggle.Text="Visualizer: OFF"
visualToggle.BackgroundColor3=Color3.fromRGB(200,50,50)
Instance.new("UICorner",visualToggle).CornerRadius=UDim.new(0,6)

local collisionToggle = Instance.new("TextButton",mainFrame)
collisionToggle.Position = UDim2.fromOffset(10,55)
collisionToggle.Size = UDim2.fromOffset(140,35)
collisionToggle.Text="Collision: OFF"
collisionToggle.BackgroundColor3=Color3.fromRGB(200,50,50)
Instance.new("UICorner",collisionToggle).CornerRadius=UDim.new(0,6)

collisionToggle.MouseButton1Click:Connect(function()
    hitboxCollision = not hitboxCollision
    collisionToggle.Text="Collision: "..(hitboxCollision and "ON" or "OFF")
    collisionToggle.BackgroundColor3=hitboxCollision and Color3.fromRGB(60,160,60) or Color3.fromRGB(200,50,50)
end)

-- FLY VARIABLES
local flying=false
local tpwalking=false
local ctrl={f=0,b=0,l=0,r=0}

local function startFly()
    local char=player.Character
    if not char then return end
    local hum=char:FindFirstChildWhichIsA("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    hum.PlatformStand=true
    flying=true
    tpwalking=true

    local bg=Instance.new("BodyGyro",root)
    bg.MaxTorque=Vector3.new(9e9,9e9,9e9)

    local bv=Instance.new("BodyVelocity",root)
    bv.MaxForce=Vector3.new(9e9,9e9,9e9)

    while tpwalking do
        RunService.RenderStepped:Wait()
        local camCF=workspace.CurrentCamera.CFrame
        local camLook=camCF.LookVector
        local camRight=camCF.RightVector

        local velocity=(camLook*(ctrl.f-ctrl.b)+camRight*(ctrl.r-ctrl.l))*50
        bv.Velocity=velocity
        bg.CFrame=camCF
    end

    hum.PlatformStand=false
    flying=false
    bv:Destroy()
    bg:Destroy()
end

-- FLY BUTTON
local flyBtn = Instance.new("TextButton", selfFrame)
flyBtn.Position = UDim2.fromOffset(10,10)
flyBtn.Size = UDim2.fromOffset(140,35)
flyBtn.Text="Fly: OFF"
flyBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
Instance.new("UICorner",flyBtn)

local function toggleFly()
    if flying then
        tpwalking=false
        flyBtn.Text="Fly: OFF"
        flyBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
    else
        flyBtn.Text="Fly: ON"
        flyBtn.BackgroundColor3=Color3.fromRGB(60,160,60)
        task.spawn(startFly)
    end
end

flyBtn.MouseButton1Click:Connect(toggleFly)

UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==Enum.KeyCode.U then toggleFly() end
    if i.KeyCode==Enum.KeyCode.W then ctrl.f=1 end
    if i.KeyCode==Enum.KeyCode.S then ctrl.b=1 end
    if i.KeyCode==Enum.KeyCode.A then ctrl.l=1 end
    if i.KeyCode==Enum.KeyCode.D then ctrl.r=1 end
end)

UserInputService.InputEnded:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==Enum.KeyCode.W then ctrl.f=0 end
    if i.KeyCode==Enum.KeyCode.S then ctrl.b=0 end
    if i.KeyCode==Enum.KeyCode.A then ctrl.l=0 end
    if i.KeyCode==Enum.KeyCode.D then ctrl.r=0 end
end)
