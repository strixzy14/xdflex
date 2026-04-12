local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local lp = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = lp:GetMouse()

-- load wind ui
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
    Title = "xdflex hub | Universal [FPS]",
    Icon = "skull", 
    Author = "xdflex",
    Folder = "xdflex_hub_ui",
    Transparent = true
})

WindUI:SetTheme("SailorOcean")

-- fov drawing setup
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

-- main vars
local speedEnabled, speedValue = false, 100
local flyEnabled, flySpeed, flyNoClip, flyMode = false, 100, true, "Normal"
local flyBodyVelocity, flyBodyGyro, flyConnection
local moveDirection = Vector3.new(0, 0, 0)

local wallhackEnabled = false
local espHighlightEnabled, espBoxEnabled, espLineEnabled = false, false, false
local teamCheckEnabled = false

local aimbotEnabled, triggerBotEnabled = false, false
local aimbotFOV = 100
local aimbotSmoothness = 0.5
local aimbotTarget = "Head"
local aimbotMethod = "Crosshair"
local aimbotKey = "Auto" -- เปลี่ยนค่าเริ่มต้นเป็น Auto
local aimbotHolding = false
local aimbotConnection, triggerBotConnection
local selectedPlayer = nil

-- wall check
local function isVisible(targetPart)
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {lp.Character, Camera}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, raycastParams)
    if result then
        if result.Instance:IsDescendantOf(targetPart.Parent) then return true else return false end
    end
    return true
end

local function updateFly()
    local rootPart = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not flyEnabled or not flyBodyVelocity or not flyBodyGyro or not rootPart then return end
    local moveVector = Camera.CFrame:VectorToWorldSpace(Vector3.new(moveDirection.X * flySpeed, moveDirection.Y * flySpeed, moveDirection.Z * flySpeed))
    
    if flyMode == "Normal" then flyBodyVelocity.Velocity = moveVector
    elseif flyMode == "Fast" then flyBodyVelocity.Velocity = moveVector * 2
    elseif flyMode == "Teleport" then rootPart.CFrame = rootPart.CFrame + (moveVector * 0.15) end
    flyBodyGyro.CFrame = Camera.CFrame

    if flyNoClip then
        for _, part in ipairs(lp.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end

local function applyWallhack()
    if lp.Character then
        for _, part in ipairs(lp.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = not wallhackEnabled end
        end
    end
end

-- esp handling
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "xdflex_ESPHighlights"
ESPFolder.Parent = CoreGui

local ESPDrawings = {}

local function CreateDrawings(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(255, 255, 255)
    box.Thickness = 1.5
    box.Transparent = 1
    box.Filled = false

    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = Color3.fromRGB(255, 255, 255)
    line.Thickness = 1.5
    line.Transparent = 1

    ESPDrawings[player.Name] = {Box = box, Line = line}
end

local function RemoveDrawings(player)
    if ESPDrawings[player.Name] then
        ESPDrawings[player.Name].Box:Remove()
        ESPDrawings[player.Name].Line:Remove()
        ESPDrawings[player.Name] = nil
    end
end

Players.PlayerRemoving:Connect(function(player)
    local highlight = ESPFolder:FindFirstChild(player.Name)
    if highlight then highlight:Destroy() end
    RemoveDrawings(player)
end)

RunService.RenderStepped:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp then
            if not ESPDrawings[player.Name] then CreateDrawings(player) end
            local drawings = ESPDrawings[player.Name]
            local isTeammate = (teamCheckEnabled and player.Team == lp.Team)

            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and not isTeammate then
                local hrp = player.Character.HumanoidRootPart
                local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)

                if onScreen then
                    -- Box ESP
                    if espBoxEnabled then
                        local rootPartPos, _ = Camera:WorldToViewportPoint(hrp.Position)
                        local headPart = player.Character:FindFirstChild("Head")
                        local headPos = headPart and Camera:WorldToViewportPoint(headPart.Position + Vector3.new(0, 0.5, 0)) or Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height / 2

                        drawings.Box.Size = Vector2.new(width, height)
                        drawings.Box.Position = Vector2.new(rootPartPos.X - width / 2, headPos.Y)
                        drawings.Box.Visible = true
                    else
                        drawings.Box.Visible = false
                    end

                    -- Line ESP
                    if espLineEnabled then
                        drawings.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        drawings.Line.To = Vector2.new(vector.X, vector.Y)
                        drawings.Line.Visible = true
                    else
                        drawings.Line.Visible = false
                    end
                else
                    drawings.Box.Visible = false
                    drawings.Line.Visible = false
                end
            else
                drawings.Box.Visible = false
                drawings.Line.Visible = false
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do 
        if espHighlightEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= lp then
                    local isTeammate = (teamCheckEnabled and player.Team == lp.Team)
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and not isTeammate then
                        local highlight = ESPFolder:FindFirstChild(player.Name)
                        if not highlight then
                            highlight = Instance.new("Highlight")
                            highlight.Name = player.Name
                            highlight.FillColor = Color3.fromRGB(255, 0, 0)
                            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop 
                            highlight.Parent = ESPFolder
                        end
                        highlight.Adornee = player.Character
                    else
                        local highlight = ESPFolder:FindFirstChild(player.Name)
                        if highlight then highlight:Destroy() end
                    end
                end
            end
        else
            ESPFolder:ClearAllChildren()
        end
    end
end)

-- aimbot/trigger functions
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
    local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local mousePos = UserInputService:GetMouseLocation()
    local distance = (mousePos - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
    return distance <= (aimbotFOV / 2)
end

local function getClosestPlayerCam()
    if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local closestPlayer = nil
    local closestDistance = math.huge
    local mousePos = UserInputService:GetMouseLocation()

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= lp and target.Character and target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health > 0 then
            if teamCheckEnabled and target.Team == lp.Team then continue end
            local targetPart = target.Character:FindFirstChild(aimbotTarget)
            if targetPart and isInFOV(targetPart.Position) and isVisible(targetPart) then
                local checkDistance
                
                if aimbotMethod == "Crosshair" then
                    local screenPoint = Camera:WorldToViewportPoint(targetPart.Position)
                    checkDistance = (mousePos - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
                else
                    checkDistance = (lp.Character.HumanoidRootPart.Position - targetPart.Position).Magnitude
                end
                
                if checkDistance < closestDistance then
                    closestPlayer = target
                    closestDistance = checkDistance
                end
            end
        end
    end
    return closestPlayer
end

local function aimAt(target)
    if target and target.Character and target.Character:FindFirstChild(aimbotTarget) then
        local targetPos = target.Character[aimbotTarget].Position
        if isInFOV(targetPos) then
            local currentLook = Camera.CFrame.LookVector
            local targetDir = (targetPos - Camera.CFrame.Position).Unit
            local newLook = currentLook:Lerp(targetDir, 1 - aimbotSmoothness)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + newLook)
        end
    end
end

local function triggerBot()
    local closestPlayer = getClosestPlayerCam()
    if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild(aimbotTarget) then
        pcall(function() mouse1click() end)
    end
end

local function getPlayersList()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and player.Character then table.insert(list, player.Name) end
    end
    table.sort(list)
    return list
end

-- setup ui tabs
local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
local MainSec = MainTab:Section({ Title = "Movement & Exploit" })

local PlayerTab = Window:Tab({ Title = "Players", Icon = "users" })
local PlayerSec = PlayerTab:Section({ Title = "ESP & Interaction" })

local AimTab = Window:Tab({ Title = "Aimbot", Icon = "crosshair" })
local AimSec = AimTab:Section({ Title = "Camera Aim & Trigger" })

local MiscTab = Window:Tab({ Title = "Misc", Icon = "layout-grid" })
local MiscSec = MiscTab:Section({ Title = "Miscellaneous Tools" })

-- tab: main
MainSec:Toggle({ Title = "Walk Speed", Value = false, Callback = function(t) speedEnabled = t if lp.Character and lp.Character:FindFirstChild("Humanoid") then lp.Character.Humanoid.WalkSpeed = t and speedValue or 16 end end })
MainSec:Slider({ Title = "Speed Value", Step = 1, Value = {Min = 16, Max = 1000, Default = 100}, Callback = function(val) speedValue = val if speedEnabled and lp.Character then lp.Character.Humanoid.WalkSpeed = val end end })
MainSec:Toggle({ Title = "Flight", Value = false, Callback = function(t) flyEnabled = t; --[[Fly logic setup here]] end })
MainSec:Slider({ Title = "Flight Speed", Step = 1, Value = {Min = 0, Max = 1000, Default = 100}, Callback = function(val) flySpeed = val end })
MainSec:Toggle({ Title = "Flight NoClip", Value = true, Callback = function(t) flyNoClip = t end })
MainSec:Dropdown({ Title = "Flight Mode", Values = {"Normal", "Fast", "Teleport"}, Value = "Normal", Multi = false, Callback = function(val) flyMode = val end })
MainSec:Toggle({ Title = "Wallhack", Value = false, Callback = function(t) wallhackEnabled = t applyWallhack() end })

-- tab: players
PlayerSec:Toggle({ Title = "Team Check", Value = false, Callback = function(t) teamCheckEnabled = t end })

PlayerSec:Toggle({
    Title = "ESP Highlight",
    Desc = "มองเห็นตัวผู้เล่นทะลุกำแพง",
    Value = false,
    Callback = function(t) espHighlightEnabled = t end
})

PlayerSec:Toggle({
    Title = "ESP Box",
    Desc = "กรอบสี่เหลี่ยมตัวผู้เล่น",
    Value = false,
    Callback = function(t) espBoxEnabled = t end
})

PlayerSec:Toggle({
    Title = "ESP Line",
    Desc = "เส้นจากขอบจอด้านล่างหาผู้เล่น",
    Value = false,
    Callback = function(t) espLineEnabled = t end
})

local PlayerDropdown = PlayerSec:Dropdown({ Title = "Select Player", Values = getPlayersList(), Value = "", Multi = false, Callback = function(val) selectedPlayer = val end })
PlayerSec:Button({ Title = "Refresh Player List", Callback = function() PlayerDropdown:Refresh(getPlayersList()) end })
PlayerSec:Button({ Title = "Teleport to Player", Callback = function() if selectedPlayer then local targetPlayer = Players:FindFirstChild(selectedPlayer) if targetPlayer and lp.Character then lp.Character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame end end end })

-- tab: aimbot
AimSec:Toggle({
    Title = "Aimbot",
    Desc = "ล็อคเป้าอัตโนมัติ",
    Value = false,
    Callback = function(t)
        aimbotEnabled = t
        fovCircle.Visible = t or triggerBotEnabled
        if aimbotConnection then aimbotConnection:Disconnect() end
        if t then
            aimbotConnection = RunService.RenderStepped:Connect(function()
                -- เช็คเงื่อนไข: ถ้าเลือก Auto ไม่ต้องรอปุ่มกด, แต่ถ้าเลือกปุ่มอื่น ต้องกดค้างถึงจะล็อค
                if aimbotEnabled and (aimbotKey == "Auto" or aimbotHolding) then
                    local closest = getClosestPlayerCam()
                    if closest then aimAt(closest) end
                end
            end)
        end
    end
})

AimSec:Dropdown({
    Title = "Target Method",
    Desc = "วิธีเลือกเป้าหมาย",
    Values = {"Crosshair", "Distance"},
    Value = "Crosshair",
    Multi = false,
    Callback = function(val) aimbotMethod = val end
})

AimSec:Dropdown({
    Title = "Aimbot Key",
    Desc = "ปุ่มที่กดค้างเพื่อล็อคเป้า",
    Values = {"Auto", "MouseButton2", "MouseButton1", "E", "Q", "R", "F", "C", "LeftShift", "LeftAlt"},
    Value = "Auto", -- ตั้งค่าเริ่มต้นให้เป็น Auto เลย
    Multi = false,
    Callback = function(val) aimbotKey = val end
})

AimSec:Dropdown({
    Title = "Target Part",
    Desc = "ชิ้นส่วนที่ต้องการล็อคเป้า",
    Values = {"Head", "HumanoidRootPart"},
    Value = "Head",
    Multi = false,
    Callback = function(val) aimbotTarget = val end
})

AimSec:Toggle({
    Title = "Trigger Bot",
    Desc = "ยิงอัตโนมัติเมื่อเป้าตรงศัตรู",
    Value = false,
    Callback = function(t)
        triggerBotEnabled = t
        fovCircle.Visible = t or aimbotEnabled
        if triggerBotConnection then triggerBotConnection:Disconnect() end
        if t then triggerBotConnection = RunService.RenderStepped:Connect(function() if triggerBotEnabled then triggerBot() end end) end
    end
})

AimSec:Slider({
    Title = "FOV Size",
    Desc = "ขนาดวงกลมการล็อคเป้าหมาย",
    Step = 10,
    Value = {Min = 50, Max = 1000, Default = 100},
    Callback = function(val)
        aimbotFOV = val
        setFOVSize(val)
    end
})

AimSec:Dropdown({
    Title = "FOV Color",
    Values = {"White", "Red", "Green", "Yellow", "Blue"},
    Value = "White",
    Multi = false,
    Callback = function(val) setFOVColor(val) end
})

-- tab: misc
MiscSec:Button({ Title = "Server Hop", Callback = function() --[[Hop Logic]] end })
MiscSec:Button({ Title = "Copy Discord Link", Callback = function() if setclipboard then setclipboard("https://discord.gg/paWWE2nZzf") end end })

-- connections & binds
lp.CharacterAdded:Connect(function()
    if wallhackEnabled then applyWallhack() end
    if flyEnabled then updateFly() end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Delete then Window:Toggle() end
    
    local keyStr = input.KeyCode.Name
    local mouseStr = input.UserInputType.Name
    if keyStr == aimbotKey or mouseStr == aimbotKey then
        aimbotHolding = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    local keyStr = input.KeyCode.Name
    local mouseStr = input.UserInputType.Name
    if keyStr == aimbotKey or mouseStr == aimbotKey then
        aimbotHolding = false
    end
end)

Window:EditSettingsTab()
task.spawn(function() task.wait(0.1) MainTab:Select() end)
Window:Toggle(true)
WindUI:Notify({Title = "xdflex hub", Content = "Loaded Successfully! (Press DEL to toggle UI)", Duration = 4})
