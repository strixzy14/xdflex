local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer

-- ==========================================
-- WIND UI SETUP
-- ==========================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

WindUI:AddTheme({
    Name = "SailorOcean",
    Accent = Color3.fromHex("#00aaff"), 
    Background = Color3.fromHex("#0b0e14"),
    Outline = Color3.fromHex("#1a1f26"),
    Text = Color3.fromHex("#ffffff"),
    Placeholder = Color3.fromHex("#7a7a7a"),
    Button = Color3.fromHex("#161b22"),
    Icon = Color3.fromHex("#00aaff"),
})

local Window = WindUI:CreateWindow({
    Title = "xdflex hub | Universal",
    Icon = "skull", 
    Author = "xdflex",
    Folder = "xdflex_hub_ui",
    Transparent = true
})

WindUI:SetTheme("SailorOcean")

-- ==========================================
-- FOV CIRCLE SETUP
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FOVCircleGui"
screenGui.Parent = CoreGui
screenGui.ResetOnSpawn = false

local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOVCircle"
fovCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.Size = UDim2.new(0, 100, 0, 100)
fovCircle.Visible = false
fovCircle.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = fovCircle

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness = 1.5
fovStroke.Parent = fovCircle

-- ==========================================
-- CORE FUNCTIONS & VARIABLES
-- ==========================================
local speedEnabled = false
local speedValue = 100
local flyEnabled = false
local flySpeed = 100
local flyNoClip = true
local flyMode = "Normal"
local flyBodyVelocity, flyBodyGyro
local moveDirection = Vector3.new(0, 0, 0)
local flyConnection
local wallhackEnabled = false
local espEnabled = false
local aimbotEnabled = false
local triggerBotEnabled = false
local aimbotFOV = 100
local aimbotSmoothness = 0.5
local aimbotTarget = "Head"
local fovColor = "White"
local aimbotConnection, triggerBotConnection
local selectedPlayer = nil

-- Anti Cheat Logic
local function enableAntiCheat(toggle)
    if not toggle then return end
    local maxWalkSpeed = 16
    local maxJumpPower = 50
    local checkInterval = 0.5

    RunService.Heartbeat:Connect(function()
        if not lp.Character or not lp.Character:FindFirstChild("Humanoid") or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
        local humanoid = lp.Character.Humanoid
        local rootPart = lp.Character.HumanoidRootPart

        if humanoid.WalkSpeed > (maxWalkSpeed * 1.5) and not speedEnabled then
            humanoid.WalkSpeed = maxWalkSpeed
            WindUI:Notify({Title = "Anti-Cheat", Content = "รีเซ็ตความเร็วแล้ว (ตรวจพบความเร็วผิดปกติ)", Duration = 3})
        end

        if humanoid.FloorMaterial == Enum.Material.Air and not flyEnabled then
            local velocity = rootPart.Velocity
            if velocity.Y > 0 or velocity.Magnitude > maxJumpPower then
                rootPart.Velocity = Vector3.new(0, 0, 0)
                WindUI:Notify({Title = "Anti-Cheat", Content = "รีเซ็ตตำแหน่งแล้ว (ตรวจพบการบิน)", Duration = 3})
            end
        end

        local lastPosition = rootPart.Position
        task.wait(checkInterval)
        if ((rootPart.Position - lastPosition).Magnitude > 50) and not flyEnabled then
            rootPart.CFrame = CFrame.new(lastPosition)
            WindUI:Notify({Title = "Anti-Cheat", Content = "รีเซ็ตตำแหน่งแล้ว (ตรวจพบการวาร์ป)", Duration = 3})
        end
    end)
end

-- Fly Logic
local function updateFly()
    local rootPart = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not flyEnabled or not flyBodyVelocity or not flyBodyGyro or not rootPart then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local moveVector = Vector3.new(moveDirection.X * flySpeed, moveDirection.Y * flySpeed, moveDirection.Z * flySpeed)
    moveVector = camera.CFrame:VectorToWorldSpace(moveVector)

    if flyMode == "Normal" then
        flyBodyVelocity.Velocity = moveVector
    elseif flyMode == "Fast" then
        flyBodyVelocity.Velocity = moveVector * 2
    elseif flyMode == "Teleport" then
        rootPart.CFrame = rootPart.CFrame + (moveVector * 0.15)
    end
    flyBodyGyro.CFrame = camera.CFrame

    if flyNoClip then
        for _, part in ipairs(lp.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end

-- Wallhack Logic
local function applyWallhack()
    if lp.Character then
        for _, part in ipairs(lp.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not wallhackEnabled
            end
        end
    end
end

-- ESP Loop (Optimized)
task.spawn(function()
    while task.wait(1) do
        if espEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= lp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                    local highlight = player.Character:FindFirstChild("ESPHighlight")
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "ESPHighlight"
                        highlight.FillColor = Color3.fromRGB(255, 0, 0)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.Parent = player.Character
                    end
                end
            end
        end
    end
end)

-- Aimbot, FOV & Wallcheck Logic
local function setFOVSize(size)
    fovCircle.Size = UDim2.new(0, size, 0, size)
end

local function setFOVColor(color)
    if color == "White" then fovStroke.Color = Color3.fromRGB(255, 255, 255)
    elseif color == "Red" then fovStroke.Color = Color3.fromRGB(255, 0, 0)
    elseif color == "Green" then fovStroke.Color = Color3.fromRGB(0, 255, 0)
    elseif color == "Yellow" then fovStroke.Color = Color3.fromRGB(255, 255, 0)
    elseif color == "Blue" then fovStroke.Color = Color3.fromRGB(0, 0, 255) end
end

local function isInFOV(targetPos)
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local screenPoint, onScreen = camera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local mousePos = UserInputService:GetMouseLocation()
    local fovRadius = aimbotFOV / 2
    local distance = (mousePos - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
    return distance <= fovRadius
end

-- Wallcheck (Raycast)
local function isVisible(targetPart)
    local camera = workspace.CurrentCamera
    if not camera or not lp.Character then return false end
    
    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {lp.Character, camera}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    
    local result = workspace:Raycast(origin, direction, raycastParams)
    
    if result then
        if result.Instance:IsDescendantOf(targetPart.Parent) then
            return true
        else
            return false
        end
    end
    return true
end

local function getClosestPlayerInFOV()
    local camera = workspace.CurrentCamera
    if not camera or not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local closestPlayer = nil
    local closestDistance = math.huge

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= lp and target.Character and target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health > 0 then
            local targetPart = target.Character:FindFirstChild(aimbotTarget)
            if targetPart and isInFOV(targetPart.Position) and isVisible(targetPart) then
                local distance = (lp.Character.HumanoidRootPart.Position - targetPart.Position).Magnitude
                if distance < closestDistance then
                    closestPlayer = target
                    closestDistance = distance
                end
            end
        end
    end
    return closestPlayer
end

local function aimAt(target)
    local camera = workspace.CurrentCamera
    if not camera then return end
    if target and target.Character and target.Character:FindFirstChild(aimbotTarget) then
        local targetPos = target.Character[aimbotTarget].Position
        if isInFOV(targetPos) then
            local currentLook = camera.CFrame.LookVector
            local targetDir = (targetPos - camera.CFrame.Position).Unit
            local newLook = currentLook:Lerp(targetDir, 1 - aimbotSmoothness)
            camera.CFrame = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + newLook)
        end
    end
end

local function triggerBot()
    local closestPlayer = getClosestPlayerInFOV()
    if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild(aimbotTarget) then
        pcall(function() mouse1click() end)
    end
end

-- Update Player List Function
local function getPlayersList()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            table.insert(list, player.Name)
        end
    end
    table.sort(list)
    return list
end

-- ==========================================
-- TABS & SECTIONS
-- ==========================================
local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
local MainSec = MainTab:Section({ Title = "Movement & Exploit", Text = "ตั้งค่าการเคลื่อนที่และสกิล" })

local PlayerTab = Window:Tab({ Title = "Players", Icon = "users" })
local PlayerSec = PlayerTab:Section({ Title = "Player Interactions", Text = "จัดการผู้เล่นอื่นในเซิร์ฟ" })

local AimTab = Window:Tab({ Title = "Aimbot", Icon = "crosshair" })
local AimSec = AimTab:Section({ Title = "Aim & Combat", Text = "ตั้งค่าการล็อคเป้าและโจมตี (Wallcheck เปิดใช้งานอัตโนมัติ)" })

local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
local SettingsSec = SettingsTab:Section({ Title = "UI Settings", Text = "ตั้งค่าเมนู" })

-- ==========================================
-- MAIN TAB
-- ==========================================
MainSec:Toggle({
    Title = "Anti-Cheat",
    Desc = "เปิดระบบป้องกันการตรวจจับ",
    Value = false,
    Callback = function(t)
        enableAntiCheat(t)
    end
})

MainSec:Toggle({
    Title = "Walk Speed",
    Desc = "เปิดใช้งานวิ่งไว",
    Value = false,
    Callback = function(t)
        speedEnabled = t
        if lp.Character and lp.Character:FindFirstChild("Humanoid") then
            lp.Character.Humanoid.WalkSpeed = t and speedValue or 16
            if t then pcall(function() lp.Character.HumanoidRootPart:SetNetworkOwner(lp) end) end
        end
    end
})

MainSec:Slider({
    Title = "Speed Value",
    Desc = "ตั้งค่าความเร็วเดิน",
    Step = 1,
    Value = {Min = 16, Max = 1000, Default = 100},
    Callback = function(val)
        speedValue = val
        if speedEnabled and lp.Character and lp.Character:FindFirstChild("Humanoid") then
            lp.Character.Humanoid.WalkSpeed = val
        end
    end
})

MainSec:Toggle({
    Title = "Flight",
    Desc = "เปิดใช้งานบิน",
    Value = false,
    Callback = function(t)
        flyEnabled = t
        local rootPart = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        if flyBodyVelocity then flyBodyVelocity:Destroy() end
        if flyBodyGyro then flyBodyGyro:Destroy() end
        if flyConnection then flyConnection:Disconnect() end
        moveDirection = Vector3.new(0, 0, 0)

        if t then
            pcall(function() rootPart:SetNetworkOwner(lp) end)
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = rootPart

            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flyBodyGyro.CFrame = rootPart.CFrame
            flyBodyGyro.Parent = rootPart

            flyConnection = RunService.RenderStepped:Connect(function()
                if not flyEnabled then flyConnection:Disconnect() return end
                updateFly()
            end)

            UserInputService.InputBegan:Connect(function(input)
                if not flyEnabled then return end
                if input.KeyCode == Enum.KeyCode.W then moveDirection = Vector3.new(moveDirection.X, moveDirection.Y, -1)
                elseif input.KeyCode == Enum.KeyCode.S then moveDirection = Vector3.new(moveDirection.X, moveDirection.Y, 1)
                elseif input.KeyCode == Enum.KeyCode.A then moveDirection = Vector3.new(-1, moveDirection.Y, moveDirection.Z)
                elseif input.KeyCode == Enum.KeyCode.D then moveDirection = Vector3.new(1, moveDirection.Y, moveDirection.Z)
                elseif input.KeyCode == Enum.KeyCode.Space then moveDirection = Vector3.new(moveDirection.X, 1, moveDirection.Z)
                elseif input.KeyCode == Enum.KeyCode.LeftControl then moveDirection = Vector3.new(moveDirection.X, -1, moveDirection.Z) end
            end)

            UserInputService.InputEnded:Connect(function(input)
                if not flyEnabled then return end
                if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then moveDirection = Vector3.new(moveDirection.X, moveDirection.Y, 0)
                elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then moveDirection = Vector3.new(0, moveDirection.Y, moveDirection.Z)
                elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.LeftControl then moveDirection = Vector3.new(moveDirection.X, 0, moveDirection.Z) end
            end)
        else
            for _, part in ipairs(lp.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
})

MainSec:Slider({
    Title = "Flight Speed",
    Desc = "ตั้งค่าความเร็วบิน",
    Step = 1,
    Value = {Min = 0, Max = 1000, Default = 100},
    Callback = function(val)
        flySpeed = val
        if flyEnabled then updateFly() end
    end
})

MainSec:Toggle({
    Title = "Flight NoClip",
    Desc = "บินทะลุกำแพง",
    Value = true,
    Callback = function(t)
        flyNoClip = t
        if flyEnabled then updateFly() end
    end
})

MainSec:Dropdown({
    Title = "Flight Mode",
    Desc = "โหมดการบิน",
    Values = {"Normal", "Fast", "Teleport"},
    Value = "Normal",
    Multi = false,
    Callback = function(val)
        flyMode = val
        if flyEnabled then updateFly() end
    end
})

MainSec:Toggle({
    Title = "Wallhack",
    Desc = "เดินทะลุกำแพง",
    Value = false,
    Callback = function(t)
        wallhackEnabled = t
        applyWallhack()
    end
})

-- ==========================================
-- PLAYERS TAB
-- ==========================================
PlayerSec:Toggle({
    Title = "ESP Player",
    Desc = "มองผู้เล่น",
    Value = false,
    Callback = function(t)
        espEnabled = t
        if not t then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= lp and player.Character then
                    local highlight = player.Character:FindFirstChild("ESPHighlight")
                    if highlight then highlight:Destroy() end
                end
            end
        end
    end
})

local PlayerDropdown = PlayerSec:Dropdown({
    Title = "Select Player",
    Desc = "เลือกเป้าหมาย",
    Values = getPlayersList(),
    Value = "",
    Multi = false,
    Callback = function(val)
        selectedPlayer = val
    end
})

PlayerSec:Button({
    Title = "Refresh Player List",
    Desc = "อัปเดตรายชื่อผู้เล่นล่าสุด",
    Callback = function()
        local newList = getPlayersList()
        PlayerDropdown:Refresh(newList)
        WindUI:Notify({Title = "Success", Content = "อัปเดตรายชื่อผู้เล่นแล้ว", Duration = 2})
    end
})

PlayerSec:Button({
    Title = "Teleport to Player",
    Desc = "วาร์ปไปหาผู้เล่นที่เลือก",
    Callback = function()
        if not selectedPlayer then
            WindUI:Notify({Title = "Error", Content = "กรุณาเลือกผู้เล่นก่อน", Duration = 3})
            return
        end
        local targetPlayer = Players:FindFirstChild(selectedPlayer)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                lp.Character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
                WindUI:Notify({Title = "Success", Content = "วาร์ปไปหา " .. selectedPlayer .. " แล้ว!", Duration = 3})
            end
        else
            WindUI:Notify({Title = "Error", Content = "ตัวละครเป้าหมายไม่พร้อม", Duration = 3})
        end
    end
})

-- ==========================================
-- AIMBOT TAB
-- ==========================================
AimSec:Toggle({
    Title = "Aimbot",
    Desc = "ล็อคเป้าอัตโนมัติ (ไม่ล็อคผ่านกำแพง)",
    Value = false,
    Callback = function(t)
        aimbotEnabled = t
        fovCircle.Visible = t or triggerBotEnabled
        if aimbotConnection then aimbotConnection:Disconnect() end
        if t then
            aimbotConnection = RunService.RenderStepped:Connect(function()
                if aimbotEnabled then
                    local closestPlayer = getClosestPlayerInFOV()
                    if closestPlayer then aimAt(closestPlayer) end
                end
            end)
        end
    end
})

AimSec:Toggle({
    Title = "Trigger Bot",
    Desc = "ยิงอัตโนมัติเมื่อเป้าตรงศัตรู (ไม่ยิงผ่านกำแพง)",
    Value = false,
    Callback = function(t)
        triggerBotEnabled = t
        fovCircle.Visible = t or aimbotEnabled
        if triggerBotConnection then triggerBotConnection:Disconnect() end
        if t then
            triggerBotConnection = RunService.RenderStepped:Connect(function()
                if triggerBotEnabled then triggerBot() end
            end)
        end
    end
})

AimSec:Slider({
    Title = "FOV Size",
    Desc = "ขนาดกรอบวงกลมการมองเห็น",
    Step = 10,
    Value = {Min = 50, Max = 1000, Default = 100},
    Callback = function(val)
        aimbotFOV = val
        setFOVSize(val)
    end
})

AimSec:Dropdown({
    Title = "Target Part",
    Desc = "เลือกส่วนที่จะล็อคเป้า",
    Values = {"Head", "Chest"},
    Value = "Head",
    Multi = false,
    Callback = function(val)
        aimbotTarget = (val == "Chest") and "UpperTorso" or "Head"
    end
})

AimSec:Slider({
    Title = "Smoothness",
    Desc = "ความนุ่มนวล (น้อย = ล็อคไว)",
    Step = 0.1,
    Value = {Min = 0, Max = 1, Default = 0.5},
    Callback = function(val)
        aimbotSmoothness = val
    end
})

AimSec:Dropdown({
    Title = "FOV Color",
    Desc = "สีของเส้นวงกลม FOV",
    Values = {"White", "Red", "Green", "Yellow", "Blue"},
    Value = "White",
    Multi = false,
    Callback = function(val)
        fovColor = val
        setFOVColor(val)
    end
})

-- ==========================================
-- EVENTS & MOBILE UI
-- ==========================================
lp.CharacterAdded:Connect(function()
    if wallhackEnabled then applyWallhack() end
    if flyEnabled then updateFly() end
end)

-- *** ส่วนที่แก้ไข: เปลี่ยนเป็นปุ่ม Delete ***
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Delete then
        Window:Toggle()
    end
end)
-- **************************************

if UserInputService.TouchEnabled then
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "xdflex_MobileToggle"
    ScreenGui.Parent = CoreGui

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Parent = ScreenGui
    ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
    ToggleBtn.Position = UDim2.new(0.12, 0, 0.15, 0)
    ToggleBtn.BackgroundColor3 = Color3.fromHex("#0b0e14")
    ToggleBtn.Text = "X Z"
    ToggleBtn.Font = Enum.Font.GothamBlack
    ToggleBtn.TextSize = 16
    ToggleBtn.TextColor3 = Color3.fromHex("#00aaff")
    ToggleBtn.AutoButtonColor = false
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0.5, 0)
    UICorner.Parent = ToggleBtn
    
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromHex("#00aaff")
    UIStroke.Thickness = 2
    UIStroke.Parent = ToggleBtn

    local DropShadow = Instance.new("ImageLabel")
    DropShadow.Parent = ToggleBtn
    DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadow.Size = UDim2.new(1, 30, 1, 30)
    DropShadow.BackgroundTransparency = 1
    DropShadow.Image = "rbxassetid://6015897043"
    DropShadow.ImageColor3 = Color3.new(0, 0, 0)
    DropShadow.ImageTransparency = 0.6
    DropShadow.ZIndex = 0

    local dragging, dragInput, dragStart, startPos
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = ToggleBtn.Position
        end
    end)
    ToggleBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            ToggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    ToggleBtn.MouseButton1Click:Connect(function()
        Window:Toggle()
    end)
end

Window:EditSettingsTab()

task.spawn(function()
    task.wait(0.1)
    MainTab:Select() 
end)

Window:Toggle(true)
WindUI:Notify({Title = "xdflex hub", Content = "Loaded Successfully! (Press DEL to toggle UI)", Duration = 4})
