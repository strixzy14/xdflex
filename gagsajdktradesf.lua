local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")
local Networking = require(SharedModules:WaitForChild("Networking"))

-- ── Config ──
local LIMIT       = 100000
local MAX_SLOTS_PER_MAIL = 20
local SEND_DELAY  = 1.5
local MAX_RETRIES = 5
local WAIT_BUFFER = 0.25
local DEFAULT_CATEGORY = "Seeds"

-- ── Backend Logic ──
local CATEGORY_SOURCES = {
	{ module = "SeedData",        category = "Seeds",        fields = { "SeedName" } },
	{ module = "SprinklerData",   category = "Sprinklers",   fields = { "SprinklerName" } },
	{ module = "WateringcanData", category = "WateringCans", fields = { "Name" } },
	{ module = "MushroomData",    category = "Mushrooms",    fields = { "Name" } },
	{ module = "RaccoonData",     category = "Raccoons",     fields = { "Name" } },
	{ module = "GnomeData",       category = "Gnomes",       fields = { "Name" } },
	{ module = "SeedPackData",    category = "SeedPacks",    fields = { "PackName" } },
	{ module = "PropData",        category = "Props",        fields = { "PropName" } },
	{ module = "PetData",         category = "Pets",         fields = { "PetName", "Name" } },
}

local CATEGORY_OVERRIDES = {}
local function requireData(name)
	local mod = SharedModules:FindFirstChild(name)
	if mod and mod:IsA("ModuleScript") then
		local ok, data = pcall(require, mod)
		if ok then return data end
	end
	return nil
end

local index = {}
local function indexData(data, category, fields)
	if typeof(data) ~= "table" then return end
	local list = (typeof(data.Data) == "table") and data.Data or data
	for _, entry in list do
		if typeof(entry) == "table" then
			for _, field in fields do
				local v = entry[field]
				if typeof(v) == "string" and v ~= "" then
					local k = string.lower(v)
					if not index[k] then index[k] = { category = category, key = v } end
				end
			end
		end
	end
end

for _, src in CATEGORY_SOURCES do indexData(requireData(src.module), src.category, src.fields) end

local function resolveItem(name)
	local k = string.lower(name)
	if CATEGORY_OVERRIDES[k] then return CATEGORY_OVERRIDES[k], name end
	local hit = index[k] or index[(string.gsub(k, "%s+seed$", ""))] or index[k .. " seed"]
	if hit then return hit.category, hit.key end
	return DEFAULT_CATEGORY, name
end

local function buildNote(batch)
	local parts, nameCounts = {}, {}
	for _, item in ipairs(batch) do
		local dName = item.DisplayName or item.ItemKey
		if item.Category == "Seeds" and not string.match(string.lower(dName), "seed$") then
			dName = dName .. " Seed"
		end
		nameCounts[dName] = (nameCounts[dName] or 0) + item.Count
	end
	for name, count in pairs(nameCounts) do table.insert(parts, ("%s %dx"):format(name, count)) end
	local note = table.concat(parts, ", ")
	if utf8.len(note) and utf8.len(note) > 100 then
		local cut = utf8.offset(note, 101)
		note = cut and string.sub(note, 1, cut - 1) or string.sub(note, 1, 100)
	end
	return note
end

local function buildBatches(resolved, limit)
	local batches, current, currentCount = {}, {}, 0
	for _, it in ipairs(resolved) do
		local remaining = it.Count
		while remaining > 0 do
			if currentCount >= limit or #current >= MAX_SLOTS_PER_MAIL then 
                table.insert(batches, current)
                current, currentCount = {}, 0 
            end
			local take = math.min(limit - currentCount, remaining)
			table.insert(current, { Category = it.Category, ItemKey = it.ItemKey, Count = take, DisplayName = it.DisplayName })
			currentCount = currentCount + take
			remaining = remaining - take
		end
	end
	if #current > 0 then table.insert(batches, current) end
	return batches
end

local function parseWait(message)
	if type(message) ~= "string" then return nil end
	local lower = string.lower(message)
	if not (string.find(lower, "wait") or string.find(lower, "cooldown")) then return nil end
	local n = string.match(message, "(%d+%.?%d*)")
	return n and tonumber(n) or nil
end

local function Send(username, resolvedItems, notifyFunc)
	local ok1, userId = pcall(function() return Networking.Mailbox.LookupPlayer:Fire(username) end)
	if not ok1 or type(userId) ~= "number" or userId <= 0 then return false, "User not found!" end
	if #resolvedItems == 0 then return false, "No valid items!" end
	
	local batches = buildBatches(resolvedItems, LIMIT)
	local cooldown = SEND_DELAY

	for i, batch in ipairs(batches) do
		local note = buildNote(batch)
		local cleanBatch = {}
		for _, item in ipairs(batch) do table.insert(cleanBatch, { Category = item.Category, ItemKey = item.ItemKey, Count = item.Count }) end
		
        local sent = false
        local lastMessage = "Unknown Error"
        
		for attempt = 1, MAX_RETRIES + 1 do
			local ok2, success, message = pcall(function() return Networking.Mailbox.SendBatch:Fire(userId, cleanBatch, note) end)
			if ok2 and success then sent = true; break end
            lastMessage = (type(message) == "string") and message or "System error."
			
            local waitFor = parseWait(message)
			if waitFor then 
                cooldown = math.max(cooldown, waitFor)
                if notifyFunc then notifyFunc("Rate Limit: Waiting " .. waitFor .. "s...", "warning") end
                task.wait(waitFor + WAIT_BUFFER) 
            else 
                break 
            end
		end
        
        if not sent then return false, "Failed (" .. i .. "/" .. #batches .. "): " .. lastMessage end
		if sent and i < #batches then task.wait(cooldown) end
	end
	return true, "All mails sent successfully!"
end

local function getBackpackItems()
    local itemData, options = {}, {}
    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
        local rawName = item.Name
        local displayName = rawName
        local isFruit = item:GetAttribute("HarvestedFruit")
        local fruitId = item:GetAttribute("Id")
        local fruitCleanName = item:GetAttribute("FruitName")
        local mutation = item:GetAttribute("Mutation")
        local petId = item:GetAttribute("PetId")
        local petCleanName = item:GetAttribute("Pet")
        local itemCountAmt = item:GetAttribute("Count")
        local isUUIDItem = false
        local uuidValue = nil
        local category = "Seeds"

        if isFruit and fruitId then
            isUUIDItem, uuidValue, category = true, fruitId, "HarvestedFruits"
            if mutation and mutation ~= "None" and mutation ~= "" then
                displayName = fruitCleanName .. " [" .. mutation .. "]"
            else displayName = fruitCleanName end
        elseif petId then
            isUUIDItem, uuidValue, category = true, petId, "Pets"
            displayName = petCleanName or rawName
        else
            category, _ = resolveItem(rawName)
        end

        if not itemData[displayName] then itemData[displayName] = { count = 0, isUUID = isUUIDItem, uuids = {}, category = category, rawName = rawName } end

        if isUUIDItem then
            table.insert(itemData[displayName].uuids, uuidValue)
            itemData[displayName].count = itemData[displayName].count + 1
        else
            local amt = tonumber(itemCountAmt)
            if not amt or amt <= 0 then amt = 1 end
            itemData[displayName].count = itemData[displayName].count + amt
        end
    end
    for name, data in pairs(itemData) do table.insert(options, name .. " (x" .. data.count .. ")") end
    if #options == 0 then table.insert(options, "No items found") end
    table.sort(options)
    return options, itemData
end

-- ── Custom UI SETUP ──

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "xdflexautotarde_v7"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local targetGui = pcall(function() return CoreGui end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui")
if targetGui:FindFirstChild(ScreenGui.Name) then targetGui[ScreenGui.Name]:Destroy() end
ScreenGui.Parent = targetGui

-- Variables & Theme
local selectedItemCleanName = ""
local currentItemData = {}
local currentQueue = {}
local isUiOpen = true
local currentCategoryFilter = "All"

local Colors = {
    Background = Color3.fromRGB(18, 18, 22),     
    CardBg = Color3.fromRGB(28, 28, 34),         
    InputBg = Color3.fromRGB(18, 18, 22),        
    Border = Color3.fromRGB(45, 45, 55),         
    Accent = Color3.fromRGB(41, 100, 230),       
    AccentHover = Color3.fromRGB(55, 120, 255),
    AddBtn = Color3.fromRGB(50, 180, 100),
    TextTitle = Color3.fromRGB(255, 255, 255),
    TextPrimary = Color3.fromRGB(230, 230, 230),
    TextSecondary = Color3.fromRGB(150, 150, 160),
    Success = Color3.fromRGB(50, 200, 100),
    Warning = Color3.fromRGB(250, 180, 50),
    Danger = Color3.fromRGB(240, 80, 80)
}

local function create(className, properties, parent)
    local obj = Instance.new(className)
    for k, v in pairs(properties) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

local function tween(obj, props, time, style)
    time = time or 0.2
    style = style or Enum.EasingStyle.Quad
    local t = TweenService:Create(obj, TweenInfo.new(time, style, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function makeDraggable(guiObject, dragHandle)
    dragHandle = dragHandle or guiObject
    local dragging, dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = guiObject.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ====================
-- TOAST NOTIFICATION SYSTEM (Safe ASCII)
-- ====================
local ToastContainer = create("Frame", {
    Size = UDim2.new(0, 250, 0, 400), Position = UDim2.new(1, -20, 1, -20), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, ZIndex = 100
}, ScreenGui)
local ToastLayout = create("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 10)
}, ToastContainer)

local function notifyToast(text, state)
    local toast = create("Frame", {Size = UDim2.new(0, 250, 0, 45), BackgroundColor3 = Colors.CardBg, BackgroundTransparency = 1}, ToastContainer)
    local stroke = create("UIStroke", {Color = Colors.Border, Thickness = 1, Transparency = 1}, toast)
    create("UICorner", {CornerRadius = UDim.new(0, 6)}, toast)
    
    local iconStr = "i"
    local iconColor = Colors.Accent
    if state == "error" then iconStr = "X"; iconColor = Colors.Danger; stroke.Color = Colors.Danger
    elseif state == "success" then iconStr = "OK"; iconColor = Colors.Success; stroke.Color = Colors.Success
    elseif state == "warning" then iconStr = "!"; iconColor = Colors.Warning; stroke.Color = Colors.Warning end
    
    local icon = create("TextLabel", {Size = UDim2.new(0, 35, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, TextTransparency = 1, Text = iconStr, TextColor3 = iconColor, Font = Enum.Font.GothamBold, TextSize = 14}, toast)
    local msg = create("TextLabel", {Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 40, 0, 0), BackgroundTransparency = 1, TextTransparency = 1, Text = text, TextColor3 = Colors.TextTitle, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true}, toast)

    tween(toast, {BackgroundTransparency = 0}, 0.3)
    tween(stroke, {Transparency = 0}, 0.3)
    tween(icon, {TextTransparency = 0}, 0.3)
    tween(msg, {TextTransparency = 0}, 0.3)

    task.delay(4.5, function()
        local t = tween(toast, {BackgroundTransparency = 1, Size = UDim2.new(0, 250, 0, 0)}, 0.4)
        tween(stroke, {Transparency = 1}, 0.3)
        tween(icon, {TextTransparency = 1}, 0.3)
        tween(msg, {TextTransparency = 1}, 0.3)
        t.Completed:Connect(function() toast:Destroy() end)
    end)
end

-- ====================
-- MAIN INTERFACE
-- ====================
local FloatingBtn = create("TextButton", {Size = UDim2.new(0, 60, 0, 40), Position = UDim2.new(0, 20, 0.5, -20), BackgroundColor3 = Colors.CardBg, Text = "Menu", TextColor3 = Colors.TextPrimary, Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false}, ScreenGui)
create("UICorner", {CornerRadius = UDim.new(0, 8)}, FloatingBtn)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, FloatingBtn)
makeDraggable(FloatingBtn)

local MainFrame = create("CanvasGroup", {Size = UDim2.new(0, 360, 0, 530), Position = UDim2.new(0.5, -180, 0.5, -265), BackgroundColor3 = Colors.Background, BorderSizePixel = 0, GroupTransparency = 0}, ScreenGui)
create("UICorner", {CornerRadius = UDim.new(0, 10)}, MainFrame)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, MainFrame)

local Header = create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, MainFrame)
create("TextLabel", {Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 15, 0, 0), Text = "XDFLEX Mail Sender", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Colors.TextTitle, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1}, Header)
makeDraggable(MainFrame, Header)
local CloseBtn = create("TextButton", {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -35, 0, 5), BackgroundTransparency = 1, Text = "X", TextColor3 = Colors.TextSecondary, Font = Enum.Font.GothamBold, TextSize = 14}, Header)

-- [1] Profile Section
local ProfileCard = create("Frame", {Size = UDim2.new(1, -30, 0, 75), Position = UDim2.new(0, 15, 0, 45), BackgroundColor3 = Colors.CardBg}, MainFrame)
create("UICorner", {CornerRadius = UDim.new(0, 8)}, ProfileCard)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, ProfileCard)
local AvatarFrame = create("Frame", {Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 12, 0.5, -25), BackgroundColor3 = Colors.InputBg}, ProfileCard)
create("UICorner", {CornerRadius = UDim.new(1, 0)}, AvatarFrame)
local AvatarImage = create("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"}, AvatarFrame)
create("UICorner", {CornerRadius = UDim.new(1, 0)}, AvatarImage)
local UsernameInput = create("TextBox", {Size = UDim2.new(1, -84, 0, 30), Position = UDim2.new(0, 74, 0, 12), BackgroundColor3 = Colors.InputBg, TextColor3 = Colors.TextPrimary, Font = Enum.Font.GothamMedium, TextSize = 13, PlaceholderText = "Recipient Username", Text = "", ClearTextOnFocus = true}, ProfileCard)
create("UICorner", {CornerRadius = UDim.new(0, 6)}, UsernameInput)
create("UIPadding", {PaddingLeft = UDim.new(0, 8)}, UsernameInput)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, UsernameInput)
local DisplayNameLabel = create("TextLabel", {Size = UDim2.new(1, -84, 0, 20), Position = UDim2.new(0, 74, 0, 44), Text = "Awaiting user...", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Colors.TextSecondary, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1}, ProfileCard)

-- [2] Item Selection & Add to Queue
local ItemCard = create("Frame", {Size = UDim2.new(1, -30, 0, 115), Position = UDim2.new(0, 15, 0, 130), BackgroundColor3 = Colors.CardBg, ZIndex = 1}, MainFrame)
create("UICorner", {CornerRadius = UDim.new(0, 8)}, ItemCard)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, ItemCard)
create("TextLabel", {Size = UDim2.new(1, -60, 0, 20), Position = UDim2.new(0, 12, 0, 10), Text = "Select Item & Add to Queue", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Colors.TextPrimary, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1}, ItemCard)

local RefreshBtn = create("TextButton", {Size = UDim2.new(0, 45, 0, 30), Position = UDim2.new(1, -57, 0, 5), BackgroundColor3 = Colors.InputBg, Text = "Sync", TextColor3 = Colors.TextPrimary, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false}, ItemCard)
create("UICorner", {CornerRadius = UDim.new(0, 6)}, RefreshBtn)

-- TABS
local TabContainer = create("Frame", {Size = UDim2.new(1, -24, 0, 25), Position = UDim2.new(0, 12, 0, 35), BackgroundTransparency = 1}, ItemCard)
local TabListLayout = create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, Padding = UDim.new(0, 5)}, TabContainer)
local tabs = {}
local function createTab(name)
    local btn = create("TextButton", {Size = UDim2.new(0, 65, 1, 0), BackgroundColor3 = (name == "All") and Colors.Accent or Colors.InputBg, Text = name, TextColor3 = (name == "All") and Colors.TextTitle or Colors.TextSecondary, Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false}, TabContainer)
    create("UICorner", {CornerRadius = UDim.new(0, 6)}, btn)
    create("UIStroke", {Color = Colors.Border, Thickness = 1}, btn)
    tabs[name] = btn; return btn
end
local tabAll = createTab("All"); local tabSeeds = createTab("Seeds"); local tabFruits = createTab("Fruits"); local tabPets = createTab("Pets")

local DropdownBtn = create("TextButton", {Size = UDim2.new(1, -165, 0, 35), Position = UDim2.new(0, 12, 0, 68), BackgroundColor3 = Colors.InputBg, Text = "Select Item...", TextColor3 = Colors.TextSecondary, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false}, ItemCard)
create("UICorner", {CornerRadius = UDim.new(0, 6)}, DropdownBtn)
create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 5)}, DropdownBtn)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, DropdownBtn)

local AmountInput = create("TextBox", {Size = UDim2.new(0, 65, 0, 35), Position = UDim2.new(1, -145, 0, 68), BackgroundColor3 = Colors.InputBg, TextColor3 = Colors.TextPrimary, Font = Enum.Font.GothamMedium, TextSize = 13, PlaceholderText = "Qty", Text = "1", ClearTextOnFocus = true}, ItemCard)
create("UICorner", {CornerRadius = UDim.new(0, 6)}, AmountInput)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, AmountInput)

local AddBtn = create("TextButton", {Size = UDim2.new(0, 65, 0, 35), Position = UDim2.new(1, -75, 0, 68), BackgroundColor3 = Colors.AddBtn, Text = "Add", TextColor3 = Colors.TextTitle, Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false}, ItemCard)
create("UICorner", {CornerRadius = UDim.new(0, 6)}, AddBtn)

-- [3] Queue Section
local QueueCard = create("Frame", {Size = UDim2.new(1, -30, 0, 140), Position = UDim2.new(0, 15, 0, 255), BackgroundColor3 = Colors.CardBg, ZIndex = 1}, MainFrame)
create("UICorner", {CornerRadius = UDim.new(0, 8)}, QueueCard)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, QueueCard)

local QueueTitle = create("TextLabel", {Size = UDim2.new(1, -24, 0, 20), Position = UDim2.new(0, 12, 0, 10), Text = "Mail Queue (0)", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Colors.TextPrimary, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1}, QueueCard)
local ClearQueueBtn = create("TextButton", {Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -62, 0, 10), BackgroundTransparency = 1, Text = "Clear", TextColor3 = Colors.Danger, Font = Enum.Font.Gotham, TextSize = 12}, QueueCard)

local QueueScroll = create("ScrollingFrame", {Size = UDim2.new(1, -16, 0, 95), Position = UDim2.new(0, 8, 0, 35), BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = Colors.Border, BorderSizePixel = 0, ZIndex = 2}, QueueCard)
local QueueLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, QueueScroll)

-- Forward Declaration of populateDropdown
local populateDropdown

-- [4] Action Section
local StatusLabel = create("TextLabel", {Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 405), Text = "System Ready.", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Colors.TextSecondary, BackgroundTransparency = 1}, MainFrame)
local SendBtn = create("TextButton", {Size = UDim2.new(1, -30, 0, 45), Position = UDim2.new(0, 15, 0, 435), BackgroundColor3 = Colors.Accent, Text = "Send All Queue", TextColor3 = Colors.TextTitle, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false}, MainFrame)
create("UICorner", {CornerRadius = UDim.new(0, 8)}, SendBtn)

-- Dropdown List (ZIndex 50)
local DropdownScroll = create("CanvasGroup", {Size = UDim2.new(1, -185, 0, 0), Position = UDim2.new(0, 27, 0, 235), BackgroundColor3 = Colors.InputBg, BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 50}, MainFrame)
create("UICorner", {CornerRadius = UDim.new(0, 6)}, DropdownScroll)
create("UIStroke", {Color = Colors.Border, Thickness = 1}, DropdownScroll)
local DropdownList = create("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = Colors.Border, BorderSizePixel = 0, ZIndex = 51}, DropdownScroll)
local UIListLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, DropdownList)

-- ── Interactions & Core Logic ──

local function applyHover(btn, originalColor, hoverColor)
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = hoverColor}, 0.15) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = originalColor}, 0.15) end)
end
applyHover(FloatingBtn, Colors.CardBg, Colors.Border)
applyHover(RefreshBtn, Colors.InputBg, Colors.CardBg)
applyHover(DropdownBtn, Colors.InputBg, Colors.CardBg)
applyHover(AddBtn, Colors.AddBtn, Color3.fromRGB(60, 200, 110))
applyHover(SendBtn, Colors.Accent, Colors.AccentHover)

local function toggleUI(forceState)
    if forceState ~= nil then isUiOpen = forceState else isUiOpen = not isUiOpen end
    if isUiOpen then
        MainFrame.Visible = true; tween(MainFrame, {GroupTransparency = 0, Size = UDim2.new(0, 360, 0, 500)}, 0.3, Enum.EasingStyle.Back)
    else
        local t = tween(MainFrame, {GroupTransparency = 1, Size = UDim2.new(0, 340, 0, 480)}, 0.2)
        t.Completed:Connect(function() if not isUiOpen then MainFrame.Visible = false end end)
    end
end
FloatingBtn.MouseButton1Click:Connect(function() toggleUI() end)
CloseBtn.MouseButton1Click:Connect(function() toggleUI(false) end)
UserInputService.InputBegan:Connect(function(input, gp) if not gp and input.KeyCode == Enum.KeyCode.RightShift then toggleUI() end end)

UsernameInput.FocusLost:Connect(function()
    local target = UsernameInput.Text
    if target == "" then AvatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"; DisplayNameLabel.Text = "Awaiting user..."; return end
    DisplayNameLabel.Text = "Searching database..."
    task.spawn(function()
        local ok, userId = pcall(function() return Players:GetUserIdFromNameAsync(target) end)
        if ok and userId then
            local content = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            AvatarImage.Image = content; DisplayNameLabel.Text = "User: " .. Players:GetNameFromUserIdAsync(userId)
            DisplayNameLabel.TextColor3 = Colors.Success
        else
            AvatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"; DisplayNameLabel.Text = "User not found!"
            DisplayNameLabel.TextColor3 = Colors.Danger
        end
    end)
end)

local function renderQueue()
    for _, child in ipairs(QueueScroll:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    
    local count = 0
    local totalItemsInQueue = 0
    
    for name, data in pairs(currentQueue) do
        count = count + 1
        totalItemsInQueue = totalItemsInQueue + data.amount
        
        local itemFrame = create("Frame", {Size = UDim2.new(1, -10, 0, 25), Position = UDim2.new(0, 5, 0, 0), BackgroundColor3 = Colors.InputBg, BorderSizePixel = 0, ZIndex = 3}, QueueScroll)
        create("UICorner", {CornerRadius = UDim.new(0, 4)}, itemFrame)
        create("TextLabel", {Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = string.format("%s (x%d)", name, data.amount), TextColor3 = Colors.TextPrimary, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4}, itemFrame)
        
        local delBtn = create("TextButton", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -25, 0.5, -10), BackgroundColor3 = Colors.CardBg, Text = "X", TextColor3 = Colors.Danger, Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 5}, itemFrame)
        create("UICorner", {CornerRadius = UDim.new(0, 4)}, delBtn)
        
        delBtn.MouseButton1Click:Connect(function()
            currentQueue[name] = nil
            renderQueue()
            populateDropdown() -- อัปเดต Dropdown ให้ของกลับมาโชว์
        end)
    end
    
    QueueTitle.Text = "Mail Queue (" .. count .. " Slots)"
    QueueScroll.CanvasSize = UDim2.new(0, 0, 0, QueueLayout.AbsoluteContentSize.Y)
    
    if totalItemsInQueue > 0 then
        SendBtn.Text = "Send Queue (" .. totalItemsInQueue .. " Items)"
    else
        SendBtn.Text = "Send All Queue"
    end
end

ClearQueueBtn.MouseButton1Click:Connect(function()
    currentQueue = {}; renderQueue(); populateDropdown(); notifyToast("Queue Cleared", "warning")
end)

local isDropdownOpen = false
local function toggleDropdown(force)
    if force ~= nil then isDropdownOpen = force else isDropdownOpen = not isDropdownOpen end
    if isDropdownOpen then
        DropdownScroll.Visible = true
        local targetHeight = math.min(160, math.max(40, UIListLayout.AbsoluteContentSize.Y + 10))
        tween(DropdownScroll, {GroupTransparency = 0, Size = UDim2.new(1, -185, 0, targetHeight)}, 0.25, Enum.EasingStyle.Back)
    else
        local t = tween(DropdownScroll, {GroupTransparency = 1, Size = UDim2.new(1, -185, 0, 0)}, 0.2)
        t.Completed:Connect(function() if not isDropdownOpen then DropdownScroll.Visible = false end end)
    end
end

-- [FIXED] ลดจำนวนที่มีตามคิว และซ่อนถ้ายัดลงคิวหมดแล้ว
populateDropdown = function()
    for _, child in ipairs(DropdownList:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
    DropdownList.CanvasPosition = Vector2.new(0, 0)
    
    local options, itemData = getBackpackItems()
    currentItemData = itemData

    local count = 0
    for i, opt in ipairs(options) do
        local rawOpt = string.gsub(opt, " %(x%d+%)$", "")
        local data = itemData[rawOpt]
        
        local match = false
        if data then
            local cat = data.category
            if currentCategoryFilter == "All" then match = true
            elseif currentCategoryFilter == "Fruits" and cat == "HarvestedFruits" then match = true
            elseif currentCategoryFilter == "Pets" and cat == "Pets" then match = true
            elseif currentCategoryFilter == "Seeds" and (cat == "Seeds" or cat == "SeedPacks") then match = true
            end
        end

        local inQueue = currentQueue[rawOpt] and currentQueue[rawOpt].amount or 0
        local available = data and (data.count - inQueue) or 0

        if match and available > 0 then
            count = count + 1
            local displayOpt = rawOpt .. " (x" .. available .. ")"
            
            local btn = create("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "  " .. displayOpt, TextColor3 = Colors.TextPrimary, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = count, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 52}, DropdownList)
            btn.MouseEnter:Connect(function() tween(btn, {BackgroundTransparency = 0.8}, 0.1) end)
            btn.MouseLeave:Connect(function() tween(btn, {BackgroundTransparency = 1}, 0.1) end)
            btn.MouseButton1Click:Connect(function()
                DropdownBtn.Text = " " .. displayOpt; DropdownBtn.TextColor3 = Colors.TextPrimary
                selectedItemCleanName = rawOpt
                toggleDropdown(false)
            end)
        end
    end
    if count == 0 then create("TextLabel", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "  No items available", TextColor3 = Colors.TextSecondary, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 52}, DropdownList) end
    DropdownList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
    
    if isDropdownOpen then tween(DropdownScroll, {Size = UDim2.new(1, -185, 0, math.min(160, math.max(40, UIListLayout.AbsoluteContentSize.Y + 10)))}, 0.2) end
end

for name, btn in pairs(tabs) do
    btn.MouseButton1Click:Connect(function()
        if currentCategoryFilter == name then return end
        currentCategoryFilter = name
        for tName, tBtn in pairs(tabs) do
            if tName == name then tween(tBtn, {BackgroundColor3 = Colors.Accent}, 0.2); tBtn.TextColor3 = Colors.TextTitle
            else tween(tBtn, {BackgroundColor3 = Colors.InputBg}, 0.2); tBtn.TextColor3 = Colors.TextSecondary end
        end
        DropdownBtn.Text = "Select Item..."; DropdownBtn.TextColor3 = Colors.TextSecondary; selectedItemCleanName = ""
        populateDropdown()
    end)
end

DropdownBtn.MouseButton1Click:Connect(function() toggleDropdown() end)
RefreshBtn.MouseButton1Click:Connect(function()
    populateDropdown(); DropdownBtn.Text = "Select Item..."; DropdownBtn.TextColor3 = Colors.TextSecondary; selectedItemCleanName = ""
    notifyToast("Inventory Refreshed", "success")
end)

AmountInput.FocusLost:Connect(function()
    local text = AmountInput.Text
    local num = tonumber(text)
    if not num or num < 1 then AmountInput.Text = "1" end
end)

-- Add to Queue Logic
AddBtn.MouseButton1Click:Connect(function()
    local amt = tonumber(AmountInput.Text) or 1
    if selectedItemCleanName == "" then return notifyToast("Select an item first!", "error") end
    
    local data = currentItemData[selectedItemCleanName]
    if not data then return notifyToast("Item not found in inventory!", "error") end

    local currentInQueue = currentQueue[selectedItemCleanName] and currentQueue[selectedItemCleanName].amount or 0
    local availableToAdd = data.count - currentInQueue

    if availableToAdd <= 0 then
        return notifyToast("All " .. selectedItemCleanName .. " are already in queue!", "warning")
    end

    if amt > availableToAdd then
        amt = availableToAdd
        AmountInput.Text = tostring(amt)
        notifyToast("Auto-adjusted to max (" .. amt .. ")", "warning")
    else
        notifyToast("Added to Queue", "success")
    end

    if not currentQueue[selectedItemCleanName] then
        currentQueue[selectedItemCleanName] = {amount = amt, rawName = data.rawName, category = data.category, isUUID = data.isUUID}
    else
        currentQueue[selectedItemCleanName].amount = currentQueue[selectedItemCleanName].amount + amt
    end

    -- เคลียร์ปุ่มเลือกถ้าของชิ้นนั้นลงคิวหมดแล้ว
    if availableToAdd - amt <= 0 then
        DropdownBtn.Text = "Select Item..."
        DropdownBtn.TextColor3 = Colors.TextSecondary
        selectedItemCleanName = ""
    end

    renderQueue()
    populateDropdown() -- อัปเดตเพื่อหักลบยอดของในลิสต์ Dropdown
end)

-- Send All Queue Logic
local isSending = false
SendBtn.MouseButton1Click:Connect(function()
    if isSending then return notifyToast("Currently sending...", "warning") end
    
    local target = UsernameInput.Text
    if target == "" then return notifyToast("Please enter a username", "error") end
    
    local isEmpty = true
    for k, v in pairs(currentQueue) do isEmpty = false; break end
    if isEmpty then return notifyToast("Your queue is empty!", "error") end

    local _, freshData = getBackpackItems()
    local resolvedToPass = {}

    for dName, qData in pairs(currentQueue) do
        local fData = freshData[dName]
        
        if not fData or fData.count == 0 then
            return notifyToast("Missing item: " .. dName .. " (Inventory changed)", "error")
        end

        local finalAmountToSend = math.min(qData.amount, fData.count)

        if qData.isUUID then
            for i = 1, finalAmountToSend do
                table.insert(resolvedToPass, { Category = qData.category, ItemKey = fData.uuids[i], Count = 1, DisplayName = dName })
            end
        else
            local cat, key = resolveItem(qData.rawName)
            table.insert(resolvedToPass, { Category = cat, ItemKey = key, Count = finalAmountToSend, DisplayName = dName })
        end
    end

    isSending = true
    SendBtn.Text = "Sending Queue..."
    tween(SendBtn, {BackgroundColor3 = Colors.Border}, 0.2)
    StatusLabel.Text = "Processing Mail Queue..."

    task.spawn(function()
        local success, msg = Send(target, resolvedToPass, notifyToast)
        if success then
            notifyToast("All Mails Sent Successfully!", "success")
            StatusLabel.Text = "System Ready."
            currentQueue = {} 
            renderQueue()
            populateDropdown() 
        else
            notifyToast("Failed: " .. msg, "error")
            StatusLabel.Text = "System Ready."
            renderQueue()
        end
        isSending = false
        tween(SendBtn, {BackgroundColor3 = Colors.Accent}, 0.2)
    end)
end)

populateDropdown()
renderQueue()
toggleUI(true)
