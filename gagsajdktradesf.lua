-- ══════════════════════════════════════════════════════════════════════
--   XDFLEX Mail Sender  |  Premium UI v2.0 (Powered by Claude UI & Gemini Backend)
--   Theme : Modern SaaS / Script Hub  |  Deep Space + Indigo Gradient
-- ══════════════════════════════════════════════════════════════════════

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")
local Networking = require(SharedModules:WaitForChild("Networking"))

-- ─────────────────────────────────────────────
--  BACKEND CONFIG & LOGIC
-- ─────────────────────────────────────────────
local LIMIT       = 100000
local MAX_SLOTS_PER_MAIL = 20
local SEND_DELAY  = 1.5
local MAX_RETRIES = 5
local WAIT_BUFFER = 0.25
local DEFAULT_CATEGORY = "Seeds"

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
                if notifyFunc then notifyFunc("Wait " .. waitFor .. "s...", "warning") end
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

-- ─────────────────────────────────────────────
--  THEME  (Deep Space · Indigo · SaaS Premium)
-- ─────────────────────────────────────────────
local C = {
    BG          = Color3.fromRGB(12, 12, 16),       -- void black
    Surface     = Color3.fromRGB(20, 20, 27),       -- elevated card
    SurfaceHi   = Color3.fromRGB(26, 26, 35),       -- hovered card
    Input       = Color3.fromRGB(15, 15, 21),       -- text-box fill
    Border      = Color3.fromRGB(40, 40, 54),       -- subtle 1-px stroke
    BorderHi    = Color3.fromRGB(80, 80, 120),      -- active stroke
    Accent      = Color3.fromRGB(99,  102, 241),    -- indigo-500
    AccentHi    = Color3.fromRGB(129, 140, 248),    -- indigo-400
    AccentDark  = Color3.fromRGB(67,  56,  202),    -- indigo-700
    AddGreen    = Color3.fromRGB(34,  197, 94),     -- emerald-500
    AddGreenHi  = Color3.fromRGB(74,  222, 128),
    TxtTitle    = Color3.fromRGB(255, 255, 255),
    TxtPrimary  = Color3.fromRGB(220, 220, 230),
    TxtSub      = Color3.fromRGB(130, 130, 150),
    TxtMuted    = Color3.fromRGB(80,  80,  100),
    Success     = Color3.fromRGB(34,  197, 94),
    Warning     = Color3.fromRGB(251, 191, 36),
    Danger      = Color3.fromRGB(239, 68,  68),
    Overlay     = Color3.fromRGB(8,   8,   12),
}

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────
local function create(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function tween(obj, props, t, style, dir)
    local ti = TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, ti, props)
    tw:Play()
    return tw
end

local function corner(r, p)  create("UICorner",  {CornerRadius = UDim.new(0, r)}, p) end
local function stroke(c, th, p)
    return create("UIStroke", {Color = c, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p)
end
local function padding(l, r, t, b, p)
    create("UIPadding", {PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0)}, p)
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local drag, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; dragStart = i.Position; startPos = frame.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    local dragInput
    frame.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then dragInput = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i == dragInput and drag then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function hoverColor(btn, base, hi)
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = hi},   0.15) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = base}, 0.15) end)
end

-- ─────────────────────────────────────────────
--  ROOT GUI
-- ─────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "xdflexautotrade_premium"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder    = 50

local ok, cg = pcall(function() return CoreGui end)
local gui = (ok and cg) or LocalPlayer:WaitForChild("PlayerGui")
if gui:FindFirstChild(ScreenGui.Name) then gui[ScreenGui.Name]:Destroy() end
ScreenGui.Parent = gui

-- ─────────────────────────────────────────────
--  TOAST NOTIFICATION SYSTEM
-- ─────────────────────────────────────────────
local ToastContainer = create("Frame", {
    Size                = UDim2.new(0, 270, 0, 500),
    Position            = UDim2.new(1, -16, 1, -16),
    AnchorPoint         = Vector2.new(1, 1),
    BackgroundTransparency = 1,
    ZIndex              = 200,
}, ScreenGui)
create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8)}, ToastContainer)

local function notifyToast(text, state)
    local accent = C.Accent
    local icon   = "i"
    if state == "success" then accent = C.Success;  icon = "OK"
    elseif state == "error"   then accent = C.Danger;   icon = "X"
    elseif state == "warning" then accent = C.Warning;  icon = "!"
    elseif state == "info" then accent = C.Accent; icon = "i" end

    local toast = create("Frame", {Size = UDim2.new(0, 270, 0, 48), BackgroundColor3 = C.Surface, BackgroundTransparency = 0.05, ZIndex = 200}, ToastContainer)
    corner(10, toast)
    local sk = stroke(accent, 1, toast)

    local bar = create("Frame", {Size = UDim2.new(0, 3, 1, -12), Position = UDim2.new(0, 8, 0, 6), BackgroundColor3 = accent, ZIndex = 201}, toast)
    corner(2, bar)

    local icL = create("TextLabel", {Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(0, 18, 0, 0), BackgroundTransparency = 1, Text = icon, TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 15, ZIndex = 201}, toast)
    create("TextLabel", {Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 48, 0, 0), BackgroundTransparency = 1, Text = text, TextColor3 = C.TxtPrimary, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 201}, toast)

    toast.Size = UDim2.new(0, 270, 0, 0)
    toast.BackgroundTransparency = 1
    sk.Transparency = 1
    tween(toast, {Size = UDim2.new(0, 270, 0, 48), BackgroundTransparency = 0.05}, 0.3, Enum.EasingStyle.Back)
    tween(sk,    {Transparency = 0},  0.3)

    task.delay(4.0, function()
        tween(toast, {Size = UDim2.new(0, 270, 0, 0), BackgroundTransparency = 1}, 0.3)
        tween(sk,    {Transparency = 1}, 0.25)
        task.delay(0.35, function() toast:Destroy() end)
    end)
end

-- ─────────────────────────────────────────────
--  FLOATING TOGGLE BUTTON
-- ─────────────────────────────────────────────
local FloatingBtn = create("TextButton", {Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 18, 0.5, -22), BackgroundColor3 = C.Accent, Text = "UI", TextColor3 = C.TxtTitle, Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = false, ZIndex = 10}, ScreenGui)
corner(22, FloatingBtn)
stroke(C.AccentDark, 2, FloatingBtn)

local glowRing = create("Frame", {Size = UDim2.new(1, 10, 1, 10), Position = UDim2.new(0, -5, 0, -5), BackgroundColor3 = C.Accent, BackgroundTransparency = 0.75, ZIndex = 9}, FloatingBtn)
corner(27, glowRing)

local function pulseGlow()
    tween(glowRing, {BackgroundTransparency = 0.55, Size = UDim2.new(1, 16, 1, 16), Position = UDim2.new(0, -8, 0, -8)}, 0.9)
    task.delay(0.9, function()
        tween(glowRing, {BackgroundTransparency = 0.82, Size = UDim2.new(1, 8, 1, 8),  Position = UDim2.new(0, -4, 0, -4)}, 0.9)
        task.delay(0.9, pulseGlow)
    end)
end
pulseGlow()

hoverColor(FloatingBtn, C.Accent, C.AccentHi)
makeDraggable(FloatingBtn)

-- ─────────────────────────────────────────────
--  MAIN WINDOW
-- ─────────────────────────────────────────────
local W, H = 370, 520
local MainFrame = create("CanvasGroup", {Size = UDim2.new(0, W, 0, H), Position = UDim2.new(0.5, -W/2, 0.5, -H/2), BackgroundColor3 = C.BG, GroupTransparency = 1, BorderSizePixel = 0, ZIndex = 20}, ScreenGui)
corner(14, MainFrame)
stroke(C.Border, 1, MainFrame)
create("Frame", {Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = C.Overlay, ZIndex = 21}, MainFrame)

local Header = create("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.Surface, BorderSizePixel = 0, ZIndex = 22}, MainFrame)
corner(14, Header)
create("Frame", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = C.Surface, BorderSizePixel = 0, ZIndex = 22}, Header)
local logoDot = create("Frame", {Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 16, 0.5, -4), BackgroundColor3 = C.Accent, ZIndex = 23}, Header)
corner(4, logoDot)
local hLine = create("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = C.Border, ZIndex = 23}, Header)
create("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C.AccentDark), ColorSequenceKeypoint.new(0.4, C.Accent), ColorSequenceKeypoint.new(1, C.BG)})}, hLine)

create("TextLabel", {Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 32, 0, 0), BackgroundTransparency = 1, Text = "XDFLEX  Mail Sender", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.TxtTitle, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, Header)

local vBadge = create("TextLabel", {Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -88, 0.5, -9), BackgroundColor3 = C.AccentDark, Text = "v2.0", TextColor3 = C.AccentHi, Font = Enum.Font.GothamMedium, TextSize = 10, ZIndex = 23}, Header)
corner(4, vBadge)

local CloseBtn = create("TextButton", {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -38, 0.5, -14), BackgroundColor3 = Color3.fromRGB(60, 20, 20), Text = "X", TextColor3 = C.Danger, Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false, ZIndex = 24}, Header)
corner(7, CloseBtn)
hoverColor(CloseBtn, Color3.fromRGB(60, 20, 20), C.Danger)
CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, {TextColor3 = C.TxtTitle}, 0.15) end)
CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, {TextColor3 = C.Danger}, 0.15) end)

makeDraggable(MainFrame, Header)

local function makeCard(yPos, h, zIdx)
    local f = create("Frame", {Size = UDim2.new(1, -28, 0, h), Position = UDim2.new(0, 14, 0, yPos), BackgroundColor3 = C.Surface, ZIndex = zIdx or 22}, MainFrame)
    corner(10, f); stroke(C.Border, 1, f); return f
end
local function cardLabel(text, card, zIdx)
    return create("TextLabel", {Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 10), BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.TxtMuted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = zIdx or 23}, card)
end

-- [1] Profile
local ProfileCard = makeCard(52, 80)
cardLabel("RECIPIENT", ProfileCard)
local AvatarFrame = create("Frame", {Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(0, 12, 0, 22), BackgroundColor3 = C.Input, ZIndex = 23}, ProfileCard)
corner(23, AvatarFrame); stroke(C.Border, 1, AvatarFrame)
local AvatarImage = create("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "rbxasset://textures/ui/GuiImagePlaceholder.png", ZIndex = 24}, AvatarFrame)
corner(23, AvatarImage)
local onlineDot = create("Frame", {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(1, -2, 1, -2), BackgroundColor3 = C.TxtMuted, ZIndex = 25}, AvatarFrame)
corner(5, onlineDot); stroke(C.Surface, 2, onlineDot)

local UsernameInput = create("TextBox", {Size = UDim2.new(1, -76, 0, 32), Position = UDim2.new(0, 68, 0, 22), BackgroundColor3 = C.Input, TextColor3 = C.TxtPrimary, Font = Enum.Font.GothamMedium, TextSize = 13, PlaceholderText = "Enter recipient username…", PlaceholderColor3 = C.TxtMuted, Text = "", ClearTextOnFocus = true, ZIndex = 23}, ProfileCard)
corner(8, UsernameInput); padding(10, 8, 0, 0, UsernameInput)
local usStroke = stroke(C.Border, 1, UsernameInput)
UsernameInput.Focused:Connect(function()  tween(usStroke, {Color = C.Accent},  0.2) end)
UsernameInput.FocusLost:Connect(function() tween(usStroke, {Color = C.Border}, 0.2) end)

local DisplayNameLabel = create("TextLabel", {Size = UDim2.new(1, -76, 0, 16), Position = UDim2.new(0, 70, 0, 56), BackgroundTransparency = 1, Text = "Awaiting user…", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.TxtMuted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, ProfileCard)

-- [2] Item Selection
local ItemCard = makeCard(142, 126)
cardLabel("SELECT ITEM", ItemCard)
local RefreshBtn = create("TextButton", {Size = UDim2.new(0, 52, 0, 22), Position = UDim2.new(1, -64, 0, 6), BackgroundColor3 = C.Input, Text = "Sync", TextColor3 = C.TxtSub, Font = Enum.Font.GothamMedium, TextSize = 11, AutoButtonColor = false, ZIndex = 23}, ItemCard)
corner(6, RefreshBtn); stroke(C.Border, 1, RefreshBtn)
hoverColor(RefreshBtn, C.Input, C.SurfaceHi)
RefreshBtn.MouseEnter:Connect(function() tween(RefreshBtn, {TextColor3 = C.TxtPrimary}, 0.15) end)
RefreshBtn.MouseLeave:Connect(function() tween(RefreshBtn, {TextColor3 = C.TxtSub}, 0.15) end)

local TabStrip = create("Frame", {Size = UDim2.new(1, -24, 0, 28), Position = UDim2.new(0, 12, 0, 32), BackgroundColor3 = C.Input, ZIndex = 23}, ItemCard)
corner(8, TabStrip); stroke(C.Border, 1, TabStrip)
create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2)}, TabStrip)
padding(3, 3, 3, 3, TabStrip)

local tabs = {}
local tabNames = {"All", "Seeds", "Fruits", "Pets"}
for i, name in ipairs(tabNames) do
    local isFirst = (i == 1)
    local btn = create("TextButton", {Size = UDim2.new(0, 72, 1, 0), BackgroundColor3 = isFirst and C.Accent or Color3.fromRGB(0,0,0), BackgroundTransparency = isFirst and 0 or 1, Text = name, TextColor3 = isFirst and C.TxtTitle or C.TxtSub, Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false, ZIndex = 24}, TabStrip)
    corner(6, btn); tabs[name] = btn
end

local DropdownBtn = create("TextButton", {Size = UDim2.new(1, -138, 0, 32), Position = UDim2.new(0, 12, 0, 68), BackgroundColor3 = C.Input, Text = "  Select item…", TextColor3 = C.TxtMuted, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false, ZIndex = 23}, ItemCard)
corner(8, DropdownBtn)
local dbStroke = stroke(C.Border, 1, DropdownBtn)
create("TextLabel", {Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0), BackgroundTransparency = 1, Text = "v", TextColor3 = C.TxtMuted, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 24}, DropdownBtn)
DropdownBtn.MouseEnter:Connect(function() tween(dbStroke, {Color = C.BorderHi}, 0.15); tween(DropdownBtn, {BackgroundColor3 = C.SurfaceHi}, 0.15) end)
DropdownBtn.MouseLeave:Connect(function() tween(dbStroke, {Color = C.Border}, 0.15); tween(DropdownBtn, {BackgroundColor3 = C.Input}, 0.15) end)

local AmountInput = create("TextBox", {Size = UDim2.new(0, 48, 0, 32), Position = UDim2.new(1, -124, 0, 68), BackgroundColor3 = C.Input, TextColor3 = C.TxtPrimary, Font = Enum.Font.GothamMedium, TextSize = 13, PlaceholderText = "Qty", PlaceholderColor3 = C.TxtMuted, Text = "1", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23}, ItemCard)
corner(8, AmountInput)
local amStroke = stroke(C.Border, 1, AmountInput)
AmountInput.Focused:Connect(function()  tween(amStroke, {Color = C.Accent},  0.2) end)
AmountInput.FocusLost:Connect(function() tween(amStroke, {Color = C.Border}, 0.2) end)

local AddBtn = create("TextButton", {Size = UDim2.new(0, 60, 0, 32), Position = UDim2.new(1, -70, 0, 68), BackgroundColor3 = C.AddGreen, Text = "+  Add", TextColor3 = C.TxtTitle, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, ZIndex = 23}, ItemCard)
corner(8, AddBtn); hoverColor(AddBtn, C.AddGreen, C.AddGreenHi)

local itemCountBadge = create("TextLabel", {Size = UDim2.new(0, 22, 0, 18), Position = UDim2.new(1, -90, 0, 7), BackgroundColor3 = C.AccentDark, Text = "0", TextColor3 = C.AccentHi, Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 24}, ItemCard)
corner(5, itemCountBadge); itemCountBadge.Visible = false

-- [3] Queue Section
local QueueCard = makeCard(278, 152, 21)
local QueueTitle = cardLabel("MAIL QUEUE  —  0 slots", QueueCard)

local ClearQueueBtn = create("TextButton", {Size = UDim2.new(0, 56, 0, 18), Position = UDim2.new(1, -68, 0, 7), BackgroundTransparency = 1, Text = "Clear all", TextColor3 = C.Danger, Font = Enum.Font.GothamMedium, TextSize = 11, ZIndex = 24}, QueueCard)
ClearQueueBtn.MouseEnter:Connect(function() tween(ClearQueueBtn, {TextColor3 = Color3.fromRGB(255,120,120)}, 0.12) end)
ClearQueueBtn.MouseLeave:Connect(function() tween(ClearQueueBtn, {TextColor3 = C.Danger}, 0.12) end)

create("Frame", {Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 30), BackgroundColor3 = C.Border, ZIndex = 22}, QueueCard)
local QueueScroll = create("ScrollingFrame", {Size = UDim2.new(1, -16, 0, 108), Position = UDim2.new(0, 8, 0, 36), BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent, ScrollBarImageTransparency = 0.4, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 23}, QueueCard)
local QueueLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, QueueScroll)
padding(4, 4, 4, 4, QueueScroll)

-- Footer Action
local StatusLabel = create("TextLabel", {Size = UDim2.new(1, -28, 0, 16), Position = UDim2.new(0, 14, 0, H - 76), BackgroundTransparency = 1, Text = "System ready.", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.TxtMuted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22}, MainFrame)
local SendBtn = create("TextButton", {Size = UDim2.new(1, -28, 0, 44), Position = UDim2.new(0, 14, 0, H - 58), BackgroundColor3 = C.Accent, Text = "  Send Queue", TextColor3 = C.TxtTitle, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false, ZIndex = 22}, MainFrame)
corner(10, SendBtn)
create("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(99, 102, 241)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(139, 92, 246)), ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 85, 247))}), Rotation = 90}, SendBtn)

local sendShimmer = create("Frame", {Size = UDim2.new(0, 60, 1, 0), Position = UDim2.new(0, -80, 0, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.85, ZIndex = 23}, SendBtn)
corner(10, sendShimmer)
create("UIGradient", {Rotation = 20, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1)})}, sendShimmer)

SendBtn.MouseEnter:Connect(function()
    sendShimmer.Position = UDim2.new(0, -80, 0, 0)
    tween(sendShimmer, {Position = UDim2.new(1, 60, 0, 0)}, 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
end)

-- Dropdown Overlay
local DropdownScroll = create("CanvasGroup", {Size = UDim2.new(1, -138, 0, 0), Position = UDim2.new(0, 26, 0, 258), BackgroundColor3 = C.SurfaceHi, BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 50, ClipsDescendants = true}, MainFrame)
corner(8, DropdownScroll); stroke(C.BorderHi, 1, DropdownScroll)
local DropdownList = create("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 51}, DropdownScroll)
local UIListLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, DropdownList)
padding(4, 4, 4, 4, DropdownList)

-- ─────────────────────────────────────────────
--  LOGIC WIRING
-- ─────────────────────────────────────────────
local isUiOpen = true
local currentCategoryFilter = "All"
local selectedItemCleanName = ""
local currentItemData       = {}
local currentQueue          = {}

local function toggleUI(forceState)
    if forceState ~= nil then isUiOpen = forceState else isUiOpen = not isUiOpen end
    if isUiOpen then
        MainFrame.Visible = true
        MainFrame.GroupTransparency = 1
        MainFrame.Size = UDim2.new(0, W, 0, H - 20)
        tween(MainFrame, {GroupTransparency = 0, Size = UDim2.new(0, W, 0, H)}, 0.35, Enum.EasingStyle.Back)
        tween(FloatingBtn, {BackgroundColor3 = C.AccentDark}, 0.2)
        tween(glowRing, {BackgroundColor3 = C.AccentDark}, 0.2)
    else
        local t = tween(MainFrame, {GroupTransparency = 1, Size = UDim2.new(0, W, 0, H - 20)}, 0.25, Enum.EasingStyle.Quart)
        t.Completed:Connect(function() if not isUiOpen then MainFrame.Visible = false end end)
        tween(FloatingBtn, {BackgroundColor3 = C.Accent}, 0.2)
        tween(glowRing, {BackgroundColor3 = C.Accent}, 0.2)
    end
end
FloatingBtn.MouseButton1Click:Connect(function() toggleUI() end)
CloseBtn.MouseButton1Click:Connect(function() toggleUI(false) end)
UserInputService.InputBegan:Connect(function(input, gp) if not gp and input.KeyCode == Enum.KeyCode.RightShift then toggleUI() end end)

local function setActiveTab(name)
    for tName, tBtn in pairs(tabs) do
        if tName == name then
            tween(tBtn, {BackgroundColor3 = C.Accent, BackgroundTransparency = 0}, 0.18)
            tBtn.TextColor3 = C.TxtTitle
        else
            tween(tBtn, {BackgroundColor3 = C.Input, BackgroundTransparency = 1}, 0.18)
            tBtn.TextColor3 = C.TxtSub
        end
    end
end

local populateDropdown -- Forward
local function renderQueue()
    for _, child in ipairs(QueueScroll:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
    end

    local count, totalItems, layoutOrder = 0, 0, 1
    for name, data in pairs(currentQueue) do
        count = count + 1
        totalItems = totalItems + data.amount

        local row = create("Frame", {Size = UDim2.new(1, -8, 0, 30), BackgroundColor3 = C.Input, ZIndex = 24, LayoutOrder = layoutOrder}, QueueScroll)
        corner(8, row); stroke(C.Border, 1, row)
        layoutOrder = layoutOrder + 1

        local catColor = C.TxtMuted
        if data.category == "HarvestedFruits" then catColor = Color3.fromRGB(251,191,36)
        elseif data.category == "Pets"         then catColor = Color3.fromRGB(168,85,247)
        elseif data.category == "Seeds"        then catColor = C.AddGreen
        elseif data.category == "SeedPacks"   then catColor = C.AddGreenHi end

        local dot = create("Frame", {Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0, 10, 0.5, -3), BackgroundColor3 = catColor, ZIndex = 25}, row)
        corner(3, dot)

        create("TextLabel", {Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 22, 0, 0), BackgroundTransparency = 1, Text = name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.TxtPrimary, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 25}, row)
        local amtPill = create("TextLabel", {Size = UDim2.new(0, 36, 0, 20), Position = UDim2.new(1, -62, 0.5, -10), BackgroundColor3 = C.SurfaceHi, Text = "x" .. data.amount, TextColor3 = C.TxtSub, Font = Enum.Font.GothamMedium, TextSize = 11, ZIndex = 25}, row)
        corner(5, amtPill)

        local delBtn = create("TextButton", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -26, 0.5, -10), BackgroundColor3 = Color3.fromRGB(50,15,15), Text = "X", TextColor3 = C.Danger, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, ZIndex = 25}, row)
        corner(5, delBtn); hoverColor(delBtn, Color3.fromRGB(50,15,15), C.Danger)
        delBtn.MouseEnter:Connect(function() tween(delBtn, {TextColor3 = C.TxtTitle}, 0.1) end)
        delBtn.MouseLeave:Connect(function() tween(delBtn, {TextColor3 = C.Danger},   0.1) end)

        local capName = name
        delBtn.MouseButton1Click:Connect(function()
            tween(row, {BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0)}, 0.18)
            task.delay(0.2, function()
                currentQueue[capName] = nil
                renderQueue()
                if populateDropdown then populateDropdown() end
            end)
        end)
    end

    QueueTitle.Text = "MAIL QUEUE  —  " .. count .. (count == 1 and " slot" or " slots")
    if count > 0 then itemCountBadge.Text = tostring(count); itemCountBadge.Visible = true else itemCountBadge.Visible = false end
    QueueScroll.CanvasSize = UDim2.new(0, 0, 0, QueueLayout.AbsoluteContentSize.Y + 12)
    SendBtn.Text = totalItems > 0 and "  Send Queue  (" .. totalItems .. " items)" or "  Send Queue"
end

local isDropdownOpen = false
local function toggleDropdown(force)
    if force ~= nil then isDropdownOpen = force else isDropdownOpen = not isDropdownOpen end
    if isDropdownOpen then
        DropdownScroll.Visible = true
        local contentH = UIListLayout.AbsoluteContentSize.Y + 16
        local targetH  = math.min(170, math.max(40, contentH))
        tween(DropdownScroll, {GroupTransparency = 0, Size = UDim2.new(1, -138, 0, targetH)}, 0.25, Enum.EasingStyle.Back)
        tween(dbStroke, {Color = C.Accent}, 0.2)
    else
        local t = tween(DropdownScroll, {GroupTransparency = 1, Size = UDim2.new(1, -138, 0, 0)}, 0.18)
        t.Completed:Connect(function() if not isDropdownOpen then DropdownScroll.Visible = false end end)
        tween(dbStroke, {Color = C.Border}, 0.2)
    end
end

populateDropdown = function()
    for _, child in ipairs(DropdownList:GetChildren()) do if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end end
    DropdownList.CanvasPosition = Vector2.new(0, 0)
    
    local options, itemData = getBackpackItems()
    currentItemData = itemData
    local order = 0

    for _, opt in ipairs(options) do
        local rawOpt = string.gsub(opt, " %(x%d+%)$", "")
        local data   = itemData[rawOpt]
        local match = false
        if data then
            local cat = data.category
            if currentCategoryFilter == "All" then match = true
            elseif currentCategoryFilter == "Fruits" and cat == "HarvestedFruits" then match = true
            elseif currentCategoryFilter == "Pets"   and cat == "Pets"            then match = true
            elseif currentCategoryFilter == "Seeds"  and (cat == "Seeds" or cat == "SeedPacks") then match = true end
        end

        local inQueue   = currentQueue[rawOpt] and currentQueue[rawOpt].amount or 0
        local available = data and (data.count - inQueue) or 0

        if match and available > 0 then
            order = order + 1
            local displayOpt = rawOpt .. "  (x" .. available .. ")"
            local btn = create("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.SurfaceHi, BackgroundTransparency = 1, Text = "  " .. displayOpt, TextColor3 = C.TxtPrimary, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = order, ZIndex = 52}, DropdownList)
            corner(6, btn)
            btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = C.SurfaceHi, BackgroundTransparency = 0}, 0.1); tween(btn, {TextColor3 = C.TxtTitle}, 0.1) end)
            btn.MouseLeave:Connect(function() tween(btn, {BackgroundTransparency = 1}, 0.1); tween(btn, {TextColor3 = C.TxtPrimary}, 0.1) end)
            btn.MouseButton1Click:Connect(function()
                DropdownBtn.Text = "  " .. displayOpt
                DropdownBtn.TextColor3 = C.TxtPrimary
                selectedItemCleanName  = rawOpt
                toggleDropdown(false)
            end)
        end
    end

    if order == 0 then
        create("TextLabel", {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "No items available", TextColor3 = C.TxtMuted, Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 52, LayoutOrder = 1}, DropdownList)
    end
    DropdownList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 8)
    if isDropdownOpen then
        local targetH = math.min(170, math.max(40, UIListLayout.AbsoluteContentSize.Y + 16))
        tween(DropdownScroll, {Size = UDim2.new(1, -138, 0, targetH)}, 0.18)
    end
end

for name, btn in pairs(tabs) do
    btn.MouseButton1Click:Connect(function()
        if currentCategoryFilter == name then return end
        currentCategoryFilter = name; setActiveTab(name)
        DropdownBtn.Text = "  Select item…"; DropdownBtn.TextColor3 = C.TxtMuted; selectedItemCleanName = ""
        populateDropdown()
    end)
end

DropdownBtn.MouseButton1Click:Connect(function() toggleDropdown() end)
RefreshBtn.MouseButton1Click:Connect(function()
    populateDropdown(); DropdownBtn.Text = "  Select item…"; DropdownBtn.TextColor3 = C.TxtMuted; selectedItemCleanName = ""
    notifyToast("Inventory synced", "success")
end)

AmountInput.FocusLost:Connect(function()
    local n = tonumber(AmountInput.Text)
    if not n or n < 1 then
        AmountInput.Text = "1"
        tween(amStroke, {Color = C.Warning}, 0.1)
        task.delay(0.5, function() tween(amStroke, {Color = C.Border}, 0.2) end)
    end
end)

AddBtn.MouseButton1Click:Connect(function()
    local originalAmountText = AmountInput.Text
    local amt = tonumber(originalAmountText) or 1
    if selectedItemCleanName == "" then return notifyToast("Select an item first!", "error") end

    local data = currentItemData[selectedItemCleanName]
    if not data then return notifyToast("Item not found in inventory!", "error") end

    local inQueue   = currentQueue[selectedItemCleanName] and currentQueue[selectedItemCleanName].amount or 0
    local available = data.count - inQueue

    if available <= 0 then return notifyToast("All " .. selectedItemCleanName .. " are already queued!", "warning") end

    if amt > available then
        amt = available
        -- 🌟 AMOUNT MEMORY FIX 🌟 อัปเดตตัวเลขกลับเพื่อให้ไม่ Error เวลา Add เกิน
        AmountInput.Text = tostring(amt) 
        tween(amStroke, {Color = C.Warning}, 0.1)
        task.delay(0.5, function() tween(amStroke, {Color = C.Border}, 0.2) end)
        notifyToast("Adjusted to max available (" .. amt .. ")", "warning")
    else
        notifyToast("Added  x" .. amt .. "  " .. selectedItemCleanName, "success")
    end

    if not currentQueue[selectedItemCleanName] then
        currentQueue[selectedItemCleanName] = {amount = amt, rawName = data.rawName, category = data.category, isUUID = data.isUUID}
    else
        currentQueue[selectedItemCleanName].amount = currentQueue[selectedItemCleanName].amount + amt
    end

    if available - amt <= 0 then
        DropdownBtn.Text = "  Select item…"
        DropdownBtn.TextColor3 = C.TxtMuted
        selectedItemCleanName  = ""
    end
    renderQueue(); populateDropdown()
end)

ClearQueueBtn.MouseButton1Click:Connect(function() currentQueue = {}; renderQueue(); populateDropdown(); notifyToast("Queue cleared", "warning") end)

UsernameInput.FocusLost:Connect(function()
    local target = UsernameInput.Text
    if target == "" then
        AvatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
        DisplayNameLabel.Text = "Awaiting user…"
        DisplayNameLabel.TextColor3 = C.TxtMuted
        tween(onlineDot, {BackgroundColor3 = C.TxtMuted}, 0.2)
        return
    end
    DisplayNameLabel.Text = "Looking up…"
    DisplayNameLabel.TextColor3 = C.TxtSub
    task.spawn(function()
        local ok, userId = pcall(function() return Players:GetUserIdFromNameAsync(target) end)
        if ok and userId then
            local thumb = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            AvatarImage.Image = thumb
            DisplayNameLabel.Text = Players:GetNameFromUserIdAsync(userId)
            DisplayNameLabel.TextColor3 = C.Success
            tween(onlineDot, {BackgroundColor3 = C.Success}, 0.3)
        else
            AvatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
            DisplayNameLabel.Text = "User not found"
            DisplayNameLabel.TextColor3 = C.Danger
            tween(onlineDot, {BackgroundColor3 = C.Danger}, 0.2)
        end
    end)
end)

local isSending = false
SendBtn.MouseButton1Click:Connect(function()
    if isSending then return notifyToast("Already sending…", "warning") end
    local target = UsernameInput.Text
    if target == "" then return notifyToast("Enter a recipient username", "error") end

    local isEmpty = true; for _ in pairs(currentQueue) do isEmpty = false; break end
    if isEmpty then return notifyToast("Your queue is empty!", "error") end

    local _, freshData = getBackpackItems()
    local resolvedToPass = {}

    for dName, qData in pairs(currentQueue) do
        local fData = freshData[dName]
        if not fData or fData.count == 0 then return notifyToast("Missing: " .. dName .. " (inventory changed)", "error") end
        local finalAmt = math.min(qData.amount, fData.count)
        if qData.isUUID then
            for i = 1, finalAmt do table.insert(resolvedToPass, {Category = qData.category, ItemKey = fData.uuids[i], Count = 1, DisplayName = dName}) end
        else
            local cat, key = resolveItem(qData.rawName)
            table.insert(resolvedToPass, {Category = cat, ItemKey = key, Count = finalAmt, DisplayName = dName})
        end
    end

    isSending = true; StatusLabel.Text = "Sending mail queue…"; SendBtn.Text = "  Sending…"
    tween(SendBtn, {BackgroundColor3 = C.AccentDark}, 0.2)

    local pulsing = true
    task.spawn(function()
        while pulsing do tween(StatusLabel, {TextColor3 = C.Accent}, 0.5); task.wait(0.55); tween(StatusLabel, {TextColor3 = C.TxtMuted}, 0.5); task.wait(0.55) end
    end)

    task.spawn(function()
        local success, msg = Send(target, resolvedToPass, notifyToast)
        pulsing = false
        if success then
            notifyToast("All mails sent successfully!", "success")
            StatusLabel.Text = "System ready."; StatusLabel.TextColor3 = C.TxtMuted
            currentQueue = {}; renderQueue(); populateDropdown()
        else
            notifyToast("Failed: " .. msg, "error")
            StatusLabel.Text = "System ready."; StatusLabel.TextColor3 = C.TxtMuted
            renderQueue()
        end
        isSending = false; SendBtn.Text = "  Send Queue"; tween(SendBtn, {BackgroundColor3 = C.Accent}, 0.3)
    end)
end)

populateDropdown()
renderQueue()
toggleUI(true)
task.delay(1.5, function() notifyToast("Press RightShift to toggle the UI", "info") end)
