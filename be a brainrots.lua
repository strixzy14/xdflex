local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer

--// ================== GAME MODULES & DATA ==================
local Remotes, PlayerState, BrainrotsData, RaritiesData, MutationsData
pcall(function()
    Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
    PlayerState = require(ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("PlayerState"):WaitForChild("PlayerStateClient"))
    BrainrotsData = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("BrainrotsData"))
    RaritiesData = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("RaritiesData"))
    MutationsData = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("MutationsData"))
    repeat task.wait() until PlayerState.IsReady()
end)

local function GetData(path)
    if not PlayerState then return nil end
    return PlayerState.GetPath(path)
end

--// ================== FIXED INTERVALS ==================
local collectInterval = 1
local rebirthInterval = 1
local speedUpgradeInterval = 1
local equipBestInterval = 4
local claimGiftsInterval = 1
local upgradeBaseInterval = 3
local sellInterval = 3

--// ================== CLEAN UP OLD GUI ==================
for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "xdflex_hub" or v.Name == "xdflex_notif" then
        v:Destroy()
    end
end

--// THEME SETTINGS
local Theme = {
    Background = Color3.fromRGB(15, 15, 20),
    Pattern = Color3.fromRGB(255, 255, 255),
    Card = Color3.fromRGB(22, 22, 30),
    CardHover = Color3.fromRGB(28, 28, 38),
    Accent = Color3.fromRGB(120, 80, 255), 
    Border = Color3.fromRGB(40, 40, 55),
    Text = Color3.fromRGB(245, 245, 255),
    TextDim = Color3.fromRGB(140, 140, 160),
    Success = Color3.fromRGB(80, 255, 120),
    Error = Color3.fromRGB(255, 80, 80)
}

local function Tween(obj, props, time, style)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.35, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

--// ================== NOTIFICATION SYSTEM ==================
local NotifGui = Instance.new("ScreenGui", CoreGui)
NotifGui.Name = "xdflex_notif"
NotifGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local NotifLayout = Instance.new("Frame", NotifGui)
NotifLayout.Size = UDim2.new(0, 300, 1, -50)
NotifLayout.Position = UDim2.new(1, -320, 0, 20)
NotifLayout.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", NotifLayout)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.VerticalAlignment = Enum.VerticalAlignment.Bottom
UIList.Padding = UDim.new(0, 10)

local function SendNotification(title, text, duration)
    local NotifCard = Instance.new("Frame", NotifLayout)
    NotifCard.Size = UDim2.new(1, 0, 0, 60)
    NotifCard.BackgroundColor3 = Theme.Card
    NotifCard.BackgroundTransparency = 1
    Instance.new("UICorner", NotifCard).CornerRadius = UDim.new(0, 8)
    
    local Stroke = Instance.new("UIStroke", NotifCard)
    Stroke.Color = Theme.Accent
    Stroke.Thickness = 1
    Stroke.Transparency = 1
    
    local T = Instance.new("TextLabel", NotifCard)
    T.Position = UDim2.new(0, 15, 0, 10)
    T.Size = UDim2.new(1, -30, 0, 20)
    T.BackgroundTransparency = 1
    T.Text = title
    T.Font = Enum.Font.GothamBold
    T.TextSize = 14
    T.TextColor3 = Theme.Text
    T.TextXAlignment = Enum.TextXAlignment.Left

    local D = Instance.new("TextLabel", NotifCard)
    D.Position = UDim2.new(0, 15, 0, 32)
    D.Size = UDim2.new(1, -30, 0, 18)
    D.BackgroundTransparency = 1
    D.Text = text
    D.Font = Enum.Font.Gotham
    D.TextSize = 12
    D.TextColor3 = Theme.TextDim
    D.TextXAlignment = Enum.TextXAlignment.Left

    Tween(NotifCard, {BackgroundTransparency = 0.1}, 0.5)
    Tween(Stroke, {Transparency = 0.5}, 0.5)
    
    task.delay(duration or 3, function()
        Tween(NotifCard, {BackgroundTransparency = 1}, 0.5)
        Tween(Stroke, {Transparency = 1}, 0.5)
        Tween(T, {TextTransparency = 1}, 0.5)
        local out = Tween(D, {TextTransparency = 1}, 0.5)
        out.Completed:Connect(function() NotifCard:Destroy() end)
    end)
end

--// ================== MAIN UI & DRAG LOGIC ==================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "xdflex_hub"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local Shadow = Instance.new("ImageLabel", ScreenGui)
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.Position = UDim2.fromScale(0.5, 0.5)
Shadow.Size = UDim2.fromOffset(630, 430)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://4743306766"
Shadow.ImageColor3 = Color3.fromRGB(0,0,0)
Shadow.ImageTransparency = 0.4
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(35, 35, 265, 265)

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.fromOffset(590, 390)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Theme.Background
Main.ClipsDescendants = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Main).Color = Theme.Border

local function MakeDraggable(dragObj, moveObj)
    local dragging, dragInput, dragStart, startPos
    dragObj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = moveObj.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragObj.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Tween(moveObj, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)}, 0.15)
        end
    end)
end

MakeDraggable(Main, Main)
Main:GetPropertyChangedSignal("Position"):Connect(function() Shadow.Position = Main.Position end)

local Mini = Instance.new("TextButton", ScreenGui)
Mini.Size = UDim2.fromOffset(45, 45)
Mini.Position = UDim2.new(0.1, 0, 0.2, 0)
Mini.Text = "XZ"
Mini.Font = Enum.Font.GothamBlack
Mini.TextSize = 16
Mini.TextColor3 = Theme.Accent
Mini.BackgroundColor3 = Theme.Background
Instance.new("UICorner", Mini).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Mini).Color = Theme.Border
MakeDraggable(Mini, Mini)

Mini.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
    Shadow.Visible = Main.Visible
end)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.LeftAlt then
        Main.Visible = not Main.Visible
        Shadow.Visible = Main.Visible
    end
end)

--// ================== SIDEBAR & PAGES ==================
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 140, 1, 0)
Sidebar.BackgroundColor3 = Theme.Card
Sidebar.BackgroundTransparency = 0.5
Sidebar.BorderSizePixel = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel", Sidebar)
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundTransparency = 1
Title.Text = "XDFLEX"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 18
Title.TextColor3 = Theme.Accent

local TabScroll = Instance.new("ScrollingFrame", Sidebar)
TabScroll.Position = UDim2.new(0, 0, 0, 60)
TabScroll.Size = UDim2.new(1, 0, 1, -60)
TabScroll.BackgroundTransparency = 1
TabScroll.ScrollBarThickness = 0
TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local TabLayout = Instance.new("UIListLayout", TabScroll)
TabLayout.Padding = UDim.new(0, 8)
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local Content = Instance.new("Frame", Main)
Content.Position = UDim2.new(0, 150, 0, 10)
Content.Size = UDim2.new(1, -160, 1, -20)
Content.BackgroundTransparency = 1

local Pages = {}

local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame", Content)
    Page.Size = UDim2.fromScale(1, 1)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.ScrollBarThickness = 2
    Page.ScrollBarImageColor3 = Theme.Accent
    Page.BorderSizePixel = 0
    
    local Layout = Instance.new("UIListLayout", Page)
    Layout.Padding = UDim.new(0, 10)
    Pages[name] = Page
    return Page
end

local function CreateTab(text, page)
    local Btn = Instance.new("TextButton", TabScroll)
    Btn.Size = UDim2.new(0.85, 0, 0, 32)
    Btn.Text = text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.TextColor3 = Theme.TextDim
    Btn.BackgroundColor3 = Theme.Card
    Btn.BackgroundTransparency = 1
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    
    local Indicator = Instance.new("Frame", Btn)
    Indicator.Size = UDim2.new(0, 3, 0.5, 0)
    Indicator.Position = UDim2.new(0, -5, 0.25, 0)
    Indicator.BackgroundColor3 = Theme.Accent
    Indicator.BackgroundTransparency = 1
    Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)

    Btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        page.Visible = true

        for _, b in pairs(TabScroll:GetChildren()) do
            if b:IsA("TextButton") then
                Tween(b, {TextColor3 = Theme.TextDim, BackgroundTransparency = 1}, 0.2)
                Tween(b:FindFirstChild("Frame"), {BackgroundTransparency = 1, Position = UDim2.new(0, -5, 0.25, 0)}, 0.2)
            end
        end
        Tween(Btn, {TextColor3 = Theme.Text, BackgroundTransparency = 0}, 0.2)
        Tween(Indicator, {BackgroundTransparency = 0, Position = UDim2.new(0, 4, 0.25, 0)}, 0.2)
    end)
end

--// ================== UI COMPONENTS LIBRARY ==================
local function CreateCard(parent, title, desc, height)
    local Card = Instance.new("Frame", parent)
    Card.Size = UDim2.new(1, -10, 0, height or 70)
    Card.Position = UDim2.new(0, 5, 0, 0)
    Card.BackgroundColor3 = Theme.Card
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 8)
    local Stroke = Instance.new("UIStroke", Card)
    Stroke.Color = Theme.Border
    Stroke.Thickness = 1
    
    local T = Instance.new("TextLabel", Card)
    T.Position = UDim2.new(0, 15, 0, 12)
    T.Size = UDim2.new(0.6, 0, 0, 18)
    T.BackgroundTransparency = 1
    T.Text = title
    T.Font = Enum.Font.GothamBold
    T.TextSize = 13
    T.TextColor3 = Theme.Text
    T.TextXAlignment = Enum.TextXAlignment.Left

    local D = Instance.new("TextLabel", Card)
    D.Position = UDim2.new(0, 15, 0, 34)
    D.Size = UDim2.new(0.6, 0, 0, 16)
    D.BackgroundTransparency = 1
    D.Text = desc or ""
    D.Font = Enum.Font.Gotham
    D.TextSize = 11
    D.TextColor3 = Theme.TextDim
    D.TextXAlignment = Enum.TextXAlignment.Left

    Card.MouseEnter:Connect(function()
        Tween(Card, {BackgroundColor3 = Theme.CardHover}, 0.2)
        Tween(Stroke, {Color = Theme.Accent, Transparency = 0.5}, 0.2)
    end)
    Card.MouseLeave:Connect(function()
        Tween(Card, {BackgroundColor3 = Theme.Card}, 0.2)
        Tween(Stroke, {Color = Theme.Border, Transparency = 0}, 0.2)
    end)

    return Card
end

local function AddToggle(card, defaultState, callback)
    local ToggleBG = Instance.new("Frame", card)
    ToggleBG.Size = UDim2.fromOffset(42, 22)
    ToggleBG.Position = UDim2.new(1, -55, 0, 24) 
    ToggleBG.BackgroundColor3 = Theme.Background
    Instance.new("UICorner", ToggleBG).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", ToggleBG).Color = Theme.Border

    local ToggleKnob = Instance.new("Frame", ToggleBG)
    ToggleKnob.Size = UDim2.fromOffset(16, 16)
    ToggleKnob.Position = UDim2.new(0, 3, 0.5, -8)
    ToggleKnob.BackgroundColor3 = Theme.TextDim
    Instance.new("UICorner", ToggleKnob).CornerRadius = UDim.new(1, 0)

    local Btn = Instance.new("TextButton", ToggleBG)
    Btn.Size = UDim2.fromScale(1, 1)
    Btn.BackgroundTransparency = 1
    Btn.Text = ""

    local enabled = defaultState or false

    local function UpdateVisuals(animTime)
        if enabled then
            Tween(ToggleBG, {BackgroundColor3 = Theme.Accent}, animTime)
            Tween(ToggleKnob, {Position = UDim2.new(1, -19, 0.5, -8), BackgroundColor3 = Theme.Text}, animTime)
        else
            Tween(ToggleBG, {BackgroundColor3 = Theme.Background}, animTime)
            Tween(ToggleKnob, {Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Theme.TextDim}, animTime)
        end
    end
    UpdateVisuals(0)

    Btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        UpdateVisuals(0.2)
        callback(enabled)
    end)

    if enabled then
        task.spawn(function() callback(enabled) end)
    end
end

local function AddButton(card, text, callback)
    local Btn = Instance.new("TextButton", card)
    Btn.Size = UDim2.fromOffset(90, 28)
    Btn.Position = UDim2.new(1, -105, 0, 21)
    Btn.Text = text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.TextColor3 = Theme.Text
    Btn.BackgroundColor3 = Theme.Background
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", Btn).Color = Theme.Border

    Btn.MouseButton1Click:Connect(function()
        Tween(Btn, {BackgroundColor3 = Theme.Accent}, 0.1)
        task.delay(0.1, function() Tween(Btn, {BackgroundColor3 = Theme.Background}, 0.2) end)
        callback()
    end)
    return Btn
end

local function CreateSmoothDropdown(parent, title, options, isMulti, callback)
    local DropdownData = { Selected = isMulti and {} or "" }
    
    local Card = Instance.new("Frame", parent)
    Card.Size = UDim2.new(1, -10, 0, 45)
    Card.Position = UDim2.new(0, 5, 0, 0)
    Card.BackgroundColor3 = Theme.Card
    Card.ClipsDescendants = true
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", Card).Color = Theme.Border

    local TopBar = Instance.new("TextButton", Card)
    TopBar.Size = UDim2.new(1, 0, 0, 45)
    TopBar.BackgroundTransparency = 1
    TopBar.Text = ""
    
    local T = Instance.new("TextLabel", TopBar)
    T.Position = UDim2.new(0, 15, 0, 0)
    T.Size = UDim2.new(0.8, 0, 1, 0)
    T.BackgroundTransparency = 1
    T.Text = title
    T.Font = Enum.Font.GothamBold
    T.TextSize = 13
    T.TextColor3 = Theme.Text
    T.TextXAlignment = Enum.TextXAlignment.Left

    local Icon = Instance.new("TextLabel", TopBar)
    Icon.Size = UDim2.fromOffset(30, 45)
    Icon.Position = UDim2.new(1, -35, 0, 0)
    Icon.BackgroundTransparency = 1
    Icon.Text = "+"
    Icon.Font = Enum.Font.GothamBold
    Icon.TextSize = 16
    Icon.TextColor3 = Theme.Accent

    local Scroll = Instance.new("ScrollingFrame", Card)
    Scroll.Position = UDim2.new(0, 10, 0, 50)
    Scroll.Size = UDim2.new(1, -20, 1, -60)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 3
    Scroll.ScrollBarImageColor3 = Theme.Accent
    Scroll.BorderSizePixel = 0

    local ListLayout = Instance.new("UIListLayout", Scroll)
    ListLayout.Padding = UDim.new(0, 4)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local expanded = false

    TopBar.MouseButton1Click:Connect(function()
        expanded = not expanded
        Icon.Text = expanded and "-" or "+"
        local contentHeight = ListLayout.AbsoluteContentSize.Y
        local targetHeight = expanded and math.clamp(contentHeight + 60, 100, 250) or 45
        Scroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
        Tween(Card, {Size = UDim2.new(1, -10, 0, targetHeight)}, 0.2, Enum.EasingStyle.Quart)
    end)

    function DropdownData:RefreshOptions(newOptions)
        for _, child in ipairs(Scroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        for i, opt in ipairs(newOptions) do
            local OptBtn = Instance.new("TextButton", Scroll)
            OptBtn.Size = UDim2.new(1, -5, 0, 30)
            OptBtn.BackgroundColor3 = Theme.Background
            OptBtn.Text = "  " .. opt
            OptBtn.Font = Enum.Font.Gotham
            OptBtn.TextSize = 12
            OptBtn.TextColor3 = Theme.TextDim
            OptBtn.TextXAlignment = Enum.TextXAlignment.Left
            Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 6)
            local OptStroke = Instance.new("UIStroke", OptBtn)
            OptStroke.Color = Theme.Border
            OptBtn.LayoutOrder = i

            local function UpdateVisual()
                local isSelected = isMulti and self.Selected[opt] or (not isMulti and self.Selected == opt)
                OptBtn.TextColor3 = isSelected and Theme.Text or Theme.TextDim
                OptStroke.Color = isSelected and Theme.Accent or Theme.Border
                OptBtn.BackgroundColor3 = isSelected and Theme.CardHover or Theme.Background
            end
            UpdateVisual()

            OptBtn.MouseButton1Click:Connect(function()
                if isMulti then
                    self.Selected[opt] = not self.Selected[opt]
                else
                    self.Selected = opt
                    for _, b in ipairs(Scroll:GetChildren()) do
                        if b:IsA("TextButton") then
                            b.TextColor3 = Theme.TextDim
                            b:FindFirstChild("UIStroke").Color = Theme.Border
                            b.BackgroundColor3 = Theme.Background
                        end
                    end
                end
                UpdateVisual()
                callback(self.Selected)
            end)
        end
    end

    DropdownData:RefreshOptions(options)
    task.spawn(function() callback(DropdownData.Selected) end)
    
    return DropdownData
end

local function CreateInputCard(parent, title, desc, default, placeholder, callback)
    local Card = CreateCard(parent, title, desc, 70)
    local InputBox = Instance.new("TextBox", Card)
    InputBox.Size = UDim2.fromOffset(100, 30)
    InputBox.Position = UDim2.new(1, -115, 0, 20)
    InputBox.BackgroundColor3 = Theme.Background
    InputBox.TextColor3 = Theme.Text
    InputBox.PlaceholderText = placeholder
    InputBox.Text = default
    InputBox.Font = Enum.Font.GothamBold
    InputBox.TextSize = 12
    Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", InputBox).Color = Theme.Border

    InputBox.FocusLost:Connect(function() callback(InputBox.Text) end)
    return Card
end

--// ================== INITIALIZE PAGES ==================
local PageMain = CreatePage("Main")
local PageUpgrade = CreatePage("Upgrade")
local PageFarm = CreatePage("Farm")
local PageSell = CreatePage("Sell Manage")
local PageMisc = CreatePage("Misc")
local PageAbout = CreatePage("About") -- [เพิ่มบรรทัดนี้]

CreateTab("Main", PageMain)
CreateTab("Upgrade", PageUpgrade)
CreateTab("Farm", PageFarm)
CreateTab("Sell Manage", PageSell)
CreateTab("Misc", PageMisc)
CreateTab("About", PageAbout) -- [เพิ่มบรรทัดนี้]

for _, p in pairs(Pages) do p.Visible = false end
PageMain.Visible = true

--// =========================================================================
--// ================== LOGIC INTEGRATION FROM FLUENT ==================
--// =========================================================================

--// ================== MAIN TAB ==================
local autoCollect = false
AddToggle(CreateCard(PageMain, "Auto Collect Cash", "Automatically collect cash"), false, function(state)
    autoCollect = state
    if state then
        task.spawn(function()
            while autoCollect do
                for i = 1, 20 do
                    task.spawn(function() pcall(function() Remotes.CollectCash:Fire(i) end) end)
                    task.wait(0.1)
                end
                task.wait(collectInterval)
            end
        end)
    end
end)

local autoRebirth = false
AddToggle(CreateCard(PageMain, "Auto Rebirth", "Rebirths automatically when ready"), false, function(state)
    autoRebirth = state
    if state then
        task.spawn(function()
            while autoRebirth do
                pcall(function()
                    local speed = GetData("Speed") or 0
                    local rebirths = GetData("Rebirths") or 0
                    local nextCost = 40 + rebirths * 10
                    if speed >= nextCost then Remotes.RequestRebirth:Fire() end
                end)
                task.wait(rebirthInterval)
            end
        end)
    end
end)

local autoEquipBest = false
AddToggle(CreateCard(PageMain, "Auto Equip Best Brainrots", "Equips your highest multiplier brainrots"), false, function(state)
    autoEquipBest = state
    if state then
        task.spawn(function()
            while autoEquipBest do
                pcall(function() Remotes.EquipBestBrainrots:Fire() end)
                task.wait(equipBestInterval)
            end
        end)
    end
end)

local autoClaimGifts = false
AddToggle(CreateCard(PageMain, "Auto Claim Free Gifts", "Claims playtime rewards automatically"), false, function(state)
    autoClaimGifts = state
    if state then
        task.spawn(function()
            while autoClaimGifts do
                for i = 1, 9 do
                    task.spawn(function() pcall(function() Remotes.ClaimGift:Fire(i) end) end)
                    task.wait(0.5)
                end
                task.wait(claimGiftsInterval)
            end
        end)
    end
end)

--// ================== UPGRADE TAB ==================
local autoSpeedUpgrade = false
local speedUpgradeAmount = 1
local SpeedUpCard = CreateCard(PageUpgrade, "Auto Upgrade Speed", "Automatically upgrades your speed")
AddToggle(SpeedUpCard, false, function(state)
    autoSpeedUpgrade = state
    if state then
        task.spawn(function()
            while autoSpeedUpgrade do
                pcall(function() Remotes.SpeedUpgrade:Fire(speedUpgradeAmount) end)
                task.wait(speedUpgradeInterval)
            end
        end)
    end
end)
CreateSmoothDropdown(PageUpgrade, "Speed Upgrade Amount", {"1", "5", "10"}, false, function(val)
    speedUpgradeAmount = tonumber(val) or 1
end).Selected = "1"

local autoUpgradeBase = false
AddToggle(CreateCard(PageUpgrade, "Auto Upgrade Base", "Automatically buys base buttons"), false, function(state)
    autoUpgradeBase = state
    if state then
        task.spawn(function()
            while autoUpgradeBase do
                pcall(function() Remotes.UpgradeBase:Fire() end)
                task.wait(upgradeBaseInterval)
            end
        end)
    end
end)

local isUpgradingBrainrots = false
local maxBrainrotLevel = 10
CreateInputCard(PageUpgrade, "Max Upgrade Level", "Stop upgrading at this level", "10", "10", function(val)
    maxBrainrotLevel = tonumber(val) or 10
end)

AddToggle(CreateCard(PageUpgrade, "Auto Upgrade Brainrots", "Upgrades slots on your podiums"), false, function(state)
    isUpgradingBrainrots = state
    if state then
        task.spawn(function()
            local function getMyPlot()
                for i = 1, 5 do
                    local plot = workspace.Plots[tostring(i)]
                    if plot and plot:FindFirstChild("YourBase") then return tostring(i) end
                end
                return nil
            end
            
            while isUpgradingBrainrots do
                local plotId = getMyPlot()
                if plotId then
                    for slot = 1, 30 do
                        if not isUpgradingBrainrots then break end
                        pcall(function()
                            local podium = workspace.Plots[plotId].Podiums[tostring(slot)]
                            local levelText = podium.Upgrade.SurfaceGui.Frame.LevelChange.Text
                            local currentLevel = tonumber(levelText:match("Level (%d+)%s*>"))
                            if currentLevel and currentLevel < maxBrainrotLevel then
                                Remotes.UpgradeBrainrot:Fire(slot)
                            end
                        end)
                        task.wait(0.05)
                    end
                end
                task.wait(1)
            end
        end)
    end
end)

--// ================== FARM TAB ==================
local loopToken = 0
local VIP_GAMEPASS_ID = 1760093100
local hasVIP = false
pcall(function() hasVIP = MarketplaceService:UserOwnsGamePassAsync(lp.UserId, VIP_GAMEPASS_ID) end)

local farmSelectedRarities = {}
local farmSelectedMutations = {}

CreateSmoothDropdown(PageFarm, "Rarity Filter", {"Brainrot God", "Secret", "Divine", "MEME", "OG"}, true, function(val)
    farmSelectedRarities = val
end)
CreateSmoothDropdown(PageFarm, "Mutation Filter", {"Normal", "Gold", "Diamond", "Rainbow", "Candy"}, true, function(val)
    farmSelectedMutations = val
end)

AddToggle(CreateCard(PageFarm, "Farm Selected Brainrots", "Auto Farm Brainrot"), false, function(state)
    if state then
        loopToken = loopToken + 1
        local token = loopToken
        task.spawn(function()
            local function getSelected(optValue)
                local t = {}
                for v, s in pairs(optValue) do if s then table.insert(t, v) end end
                return t
            end
            
            local function slotRefIsAllowed(model)
                local slotRef = model:GetAttribute("SlotRef")
                if not slotRef then return true end
                local slotNum = tonumber(slotRef:match("Slot(%d+)$"))
                if slotNum and slotNum >= 9 then return hasVIP end
                return true
            end
            
            local function modelMatchesFilters(model)
                if not slotRefIsAllowed(model) then return false end
                local selRarities = getSelected(farmSelectedRarities)
                local selMutations = getSelected(farmSelectedMutations)
                if #selRarities == 0 and #selMutations == 0 then return true end
                
                local rarity = model:GetAttribute("Rarity")
                local mutation = model:GetAttribute("Mutation")
                
                for _, r in ipairs(selRarities) do if rarity == r then return true end end
                for _, m in ipairs(selMutations) do
                    if m == "Normal" and not mutation then return true end
                    if mutation == m then return true end
                end
                return false
            end
            
            -- ฟังก์ชันช่วยสำหรับ Tween ตัวละคร
            local function TweenChar(root, targetCFrame, duration)
                if not root then return end
                local tInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
                local tween = game:GetService("TweenService"):Create(root, tInfo, {CFrame = targetCFrame})
                tween:Play()
                tween.Completed:Wait() -- รอจนกว่าจะลอยถึงเป้าหมาย
            end

            while loopToken == token do
                pcall(function()
                    local char = lp.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if not root then return end
                    
                    -- 1. วาร์ปไปจุดรอเกิด (ใช้ CFrame ธรรมดาเพื่อให้เริ่มไว)
                    root.CFrame = CFrame.new(708, 39, -2123)
                    task.wait(0.5)
                    
                    local validModels = {}
                    for _, m in ipairs(workspace.Brainrots:GetChildren()) do
                        if m:IsA("Model") and modelMatchesFilters(m) then table.insert(validModels, m) end
                    end
                    
                    if #validModels > 0 then
                        local target = validModels[math.random(1, #validModels)]
                        if target and target.Parent then
                            
                            -- 2. Tween ลอยไปหาเป้าหมาย (ใช้เวลา 0.3 วิ)
                            TweenChar(root, target:GetPivot() * CFrame.new(0, 3, 0), 0.3)
                            task.wait(0.1)
                            
                            -- กด Steal ไอเทม
                            for _, desc in ipairs(target:GetDescendants()) do
                                if desc:IsA("ProximityPrompt") and desc.Name == "Carry" and desc.ActionText == "Steal" then
                                    fireproximityprompt(desc)
                                    break
                                end
                            end
                            task.wait(0.2)
                            
                            -- 3. Tween ลอยดึงขึ้นฟ้า 15 Studs (สไตล์การเคลื่อนที่ใหม่)
                            TweenChar(root, root.CFrame * CFrame.new(0, 15, 0), 0.2)
                        end
                    end
                    
                    -- 4. Tween พุ่งไปจุดส่งของ (ใช้เวลา 0.4 วิ)
                    TweenChar(root, CFrame.new(739, 39, -2122), 0.4)
                    task.wait(0.5) -- หน่วงเวลารอของเข้ากระเป๋าก่อนวนลูปใหม่
                end)
            end
        end)
    else
        loopToken = loopToken + 1
    end
end)

--// ================== SELL MANAGE TAB ==================
local autoSell = false
local sellMode = "Sell All EXCEPT Selected"
local selectedRarities = {}
local selectedMutations = {}
local selectedNames = {}

-- ดึงข้อมูลจาก Data Tables
local dbRarityList = {}
if RaritiesData then for r, _ in pairs(RaritiesData) do table.insert(dbRarityList, r) end table.sort(dbRarityList) end

local dbMutationList = {"Default"}
if MutationsData then for m, _ in pairs(MutationsData) do table.insert(dbMutationList, m) end table.sort(dbMutationList) end

local dbNameList = {}
if BrainrotsData then for n, _ in pairs(BrainrotsData) do table.insert(dbNameList, n) end table.sort(dbNameList) end

AddToggle(CreateCard(PageSell, "Enable Auto Sell", "Auto Sell Brainrot Mode"), false, function(state)
    autoSell = state
    if state then
        task.spawn(function()
            while autoSell do
                pcall(function()
                    local stored = GetData("StoredBrainrots") or {}
                    for slotKey, brainrot in pairs(stored) do
                        local index = brainrot.Index
                        local mutation = brainrot.Mutation or "Default"
                        local data = BrainrotsData and BrainrotsData[index]
                        
                        if data then
                            local rarity = data.Rarity
                            local isSelected = false
                            
                            -- เช็คว่าของชิ้นนี้ตรงกับที่เราติ๊กเลือกไว้ใน Dropdown ไหม
                            if selectedRarities[rarity] then isSelected = true end
                            if not isSelected and selectedMutations[mutation] then isSelected = true end
                            if not isSelected and selectedNames[index] then isSelected = true end
                            
                            -- ลอจิกการทำงานตามโหมดที่เลือก
                            if (sellMode == "Sell All EXCEPT Selected" and not isSelected) or 
                               (sellMode == "Sell ONLY Selected" and isSelected) then
                                
                                task.spawn(function() Remotes.SellThis:Fire(slotKey) end)
                                task.wait(0.05)
                            end
                        end
                    end
                end)
                task.wait(sellInterval)
            end
        end)
    end
end)

CreateSmoothDropdown(PageSell, "Auto Sell  Mode", {"Sell All EXCEPT Selected", "Sell ONLY Selected"}, false, function(val)
    sellMode = val
end).Selected = "Sell All EXCEPT Selected"

CreateSmoothDropdown(PageSell, "Select Rarities", dbRarityList, true, function(val)
    selectedRarities = val
end)

CreateSmoothDropdown(PageSell, "Select Mutations", dbMutationList, true, function(val)
    selectedMutations = val
end)

CreateSmoothDropdown(PageSell, "Select Brainrots", dbNameList, true, function(val)
    selectedNames = val
end)

--// ================== MISC TAB ==================
local storedLasers = {}
AddToggle(CreateCard(PageMisc, "Remove Laser Doors", "Deletes all laser walls"), false, function(state)
    if state then
        for _, base in ipairs(workspace.Map.Bases:GetChildren()) do
            local lasers = base:FindFirstChild("LasersModel")
            if lasers and not storedLasers[lasers] then
                local clone = lasers:Clone()
                clone.Parent = nil
                storedLasers[lasers] = { Clone = clone, Parent = lasers.Parent }
                lasers:Destroy()
            end
        end
    else
        for _, data in pairs(storedLasers) do
            if data.Clone then data.Clone.Parent = data.Parent end
        end
        storedLasers = {}
    end
end)

local camSavedCFrame = workspace.CurrentCamera.CFrame
local antiShakeEnabled = false
RunService:BindToRenderStep("AntiShake_Pre", Enum.RenderPriority.Camera.Value, function()
    if antiShakeEnabled then camSavedCFrame = workspace.CurrentCamera.CFrame end
end)
RunService:BindToRenderStep("AntiShake_Post", Enum.RenderPriority.Camera.Value + 2, function()
    if antiShakeEnabled then workspace.CurrentCamera.CFrame = camSavedCFrame end
end)
AddToggle(CreateCard(PageMisc, "Anti Camera Shake", "Stops camera from shaking"), false, function(state)
    antiShakeEnabled = state
end)

local freezeChasing = false
local storedSpeeds = {}
local speedConn
local isShaking = false
local stopTimer

local function freezeBosses(mode)
    local function getHighestBase()
        local h = -1
        for _, b in ipairs(workspace.Bosses:GetChildren()) do
            local num = tonumber(b.Name:match("^base(%d+)$"))
            if num and num > h then h = num end
        end
        return h
    end
    
    local highest = getHighestBase()
    for _, boss in ipairs(workspace.Bosses:GetChildren()) do
        if mode == "Bad" and boss.Name == "base" .. highest then continue end
        local hum = boss:FindFirstChildOfClass("Humanoid")
        if hum and not storedSpeeds[boss] then
            storedSpeeds[boss] = hum.WalkSpeed
            hum.WalkSpeed = 0
        end
    end
    
    if speedConn then speedConn:Disconnect() end
    speedConn = RunService.Heartbeat:Connect(function()
        for _, boss in ipairs(workspace.Bosses:GetChildren()) do
            if mode == "Bad" and boss.Name == "base" .. highest then continue end
            local hum = boss:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 0 end
        end
    end)
end

local function restoreBosses()
    if speedConn then speedConn:Disconnect(); speedConn = nil end
    for _, boss in ipairs(workspace.Bosses:GetChildren()) do
        local hum = boss:FindFirstChildOfClass("Humanoid")
        if hum and storedSpeeds[boss] then hum.WalkSpeed = storedSpeeds[boss] end
    end
    storedSpeeds = {}
end

AddToggle(CreateCard(PageMisc, "Freeze Boss For Escape", "Freezes bosses when screen shakes"), false, function(state)
    freezeChasing = state
    if state then
        RunService:BindToRenderStep("ShakeDetect_Pre", Enum.RenderPriority.Camera.Value, function() camSavedCFrame = workspace.CurrentCamera.CFrame end)
        RunService:BindToRenderStep("ShakeDetect_Post", Enum.RenderPriority.Camera.Value + 2, function()
            local posDiff = (workspace.CurrentCamera.CFrame.Position - camSavedCFrame.Position).Magnitude
            local prevShaking = isShaking
            isShaking = posDiff > 0.01
            
            if isShaking and not prevShaking then
                if stopTimer then task.cancel(stopTimer); stopTimer = nil end
                freezeBosses("All")
            elseif not isShaking and prevShaking then
                if stopTimer then task.cancel(stopTimer) end
                stopTimer = task.delay(3, function() stopTimer = nil; restoreBosses() end)
            end
        end)
    else
        RunService:UnbindFromRenderStep("ShakeDetect_Pre")
        RunService:UnbindFromRenderStep("ShakeDetect_Post")
        isShaking = false
        if stopTimer then task.cancel(stopTimer); stopTimer = nil end
        restoreBosses()
    end
end)

AddToggle(CreateCard(PageMisc, "Noob Boss Ignore You", "All boss ignore you EXCEPT the last one"), false, function(state)
    if state then freezeBosses("Bad") else restoreBosses() end
end)

--// ================== ABOUT TAB ==================
local DISCORD_LINK = "https://discord.gg/paWWE2nZzf" -- เปลี่ยนลิ้งก์ตรงนี้เป็นของเซิร์ฟเวอร์คุณได้เลย

local InfoCard = CreateCard(PageAbout, "XDFLEX Hub", "OP FREE SCRIPT")

local DiscordCard = CreateCard(PageAbout, "Discord Community", "Join our server")
AddButton(DiscordCard, "COPY LINK", function()
    if setclipboard then
        setclipboard(DISCORD_LINK)
        SendNotification("Copied!", "Discord link copied to clipboard!", 3)
    else
        SendNotification("Error", "Your executor doesn't support copying.", 3)
    end
end)

SendNotification("Welcome Back!", "xdflex Hub loaded successfully.", 4)
