local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")
local Networking = require(SharedModules:WaitForChild("Networking"))

-- ── Config ──
local LIMIT       = 9999999
local SEND_DELAY  = 1.5
local MAX_RETRIES = 5
local WAIT_BUFFER = 0.25
local DEFAULT_CATEGORY = "Seeds"

-- ── Category auto-resolver ──
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
					if not index[k] then
						index[k] = { category = category, key = v }
					end
				end
			end
		end
	end
end

for _, src in CATEGORY_SOURCES do
	indexData(requireData(src.module), src.category, src.fields)
end

local function resolveItem(name)
	local k = string.lower(name)
	if CATEGORY_OVERRIDES[k] then return CATEGORY_OVERRIDES[k], name end
	local hit = index[k] or index[(string.gsub(k, "%s+seed$", ""))] or index[k .. " seed"]
	if hit then return hit.category, hit.key end
	return DEFAULT_CATEGORY, name
end

-- ── Custom Note Builder ──
local function buildNote(batch)
	local parts = {}
	local nameCounts = {}
	
	for _, item in ipairs(batch) do
		local dName = item.DisplayName or item.ItemKey
		if item.Category == "Seeds" and not string.match(string.lower(dName), "seed$") then
			dName = dName .. " Seed"
		end
		nameCounts[dName] = (nameCounts[dName] or 0) + item.Count
	end
	
	for name, count in pairs(nameCounts) do
		table.insert(parts, ("%s %dx"):format(name, count))
	end
	
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
			if currentCount >= limit then
				table.insert(batches, current)
				current, currentCount = {}, 0
			end
			local take = math.min(limit - currentCount, remaining)
			table.insert(current, { 
				Category = it.Category, 
				ItemKey = it.ItemKey, 
				Count = take, 
				DisplayName = it.DisplayName 
			})
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

-- ── Main Send Logic ──
local function Send(username, resolvedItems)
	local ok1, userId, displayName = pcall(function()
		return Networking.Mailbox.LookupPlayer:Fire(username)
	end)
	if not ok1 or type(userId) ~= "number" or userId <= 0 then
		return false, "User not found!"
	end
	
	if #resolvedItems == 0 then return false, "No valid items!" end
	local batches = buildBatches(resolvedItems, LIMIT)
	local cooldown = SEND_DELAY

	for i, batch in ipairs(batches) do
		local note = buildNote(batch)
		
		local cleanBatch = {}
		for _, item in ipairs(batch) do
			table.insert(cleanBatch, { Category = item.Category, ItemKey = item.ItemKey, Count = item.Count })
		end

		local sent = false
		for attempt = 1, MAX_RETRIES + 1 do
			local ok2, success, message = pcall(function()
				return Networking.Mailbox.SendBatch:Fire(userId, cleanBatch, note)
			end)
			if ok2 and success then
				sent = true
				break
			end
			local waitFor = parseWait(message)
			if waitFor then
				cooldown = math.max(cooldown, waitFor)
				task.wait(waitFor + WAIT_BUFFER)
			else
				break
			end
		end
		if sent and i < #batches then
			task.wait(cooldown)
		end
	end
	return true, "Mail Sent Successfully!"
end

-- ── UI SETUP (RAYFIELD LIBRARY) ──
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "📦 XDFLEX Mailbox Sender",
   LoadingTitle = "Applying Fixes...",
   LoadingSubtitle = "by xdflex",
   ConfigurationSaving = { Enabled = false },
   Discord = { Enabled = false },
   KeySystem = false,
})

local Tab = Window:CreateTab("Send Mail", 4483362458)
Tab:CreateSection("Mail Configuration")

local targetUsername = ""
local selectedItem = ""
local amountToSend = 1

Tab:CreateInput({
   Name = "Recipient Username",
   PlaceholderText = "Enter exact username...",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
       targetUsername = Text
   end,
})

-- ── ฟังก์ชันดึงไอเทม + แยกแยะตาม Attributes (อัปเดตใหม่) ──
local function getBackpackItems()
    local itemData = {}
    local options = {}

    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
        local rawName = item.Name
        local displayName = rawName
        
        -- อ่านค่าจาก Attributes ของเกม
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
            -- กรณีเป็น Fruit
            isUUIDItem = true
            uuidValue = fruitId
            category = "HarvestedFruits"
            -- ตัดน้ำหนักออกให้เหลือแค่ชื่อผลไม้ + กลายพันธุ์ เพื่อจัดกลุ่มใน Dropdown
            if mutation and mutation ~= "None" and mutation ~= "" then
                displayName = fruitCleanName .. " [" .. mutation .. "]"
            else
                displayName = fruitCleanName
            end
        elseif petId then
            -- กรณีเป็น Pet (ใช้ PetId)
            isUUIDItem = true
            uuidValue = petId
            category = "Pets"
            displayName = petCleanName or rawName
        else
            -- กรณีเป็นของทับซ้อน (Seeds, etc.)
            local resolvedCat, _ = resolveItem(rawName)
            category = resolvedCat
        end

        -- จัดกลุ่ม
        if not itemData[displayName] then
            itemData[displayName] = { 
                count = 0, 
                isUUID = isUUIDItem, 
                uuids = {}, 
                category = category,
                rawName = rawName -- เก็บชื่อต้นฉบับไว้ใช้ตอนส่ง
            }
        end

        if isUUIDItem then
            -- กรณีมี UUID ให้นับชิ้นละ 1 แล้วเก็บรหัสแยก
            table.insert(itemData[displayName].uuids, uuidValue)
            itemData[displayName].count = itemData[displayName].count + 1
        else
            -- กรณีของทับซ้อน (Seed) ให้ดึงจำนวนจาก Attribute 'Count'
            local amt = tonumber(itemCountAmt)
            if not amt or amt <= 0 then amt = 1 end
            itemData[displayName].count = itemData[displayName].count + amt
        end
    end

    for name, data in pairs(itemData) do
        -- โชว์จำนวนให้เห็นใน Dropdown เลย
        table.insert(options, name .. " (x" .. data.count .. ")")
    end
    if #options == 0 then table.insert(options, "No items found") end
    
    table.sort(options) -- เรียงตามตัวอักษร
    return options, itemData
end

local initialOptions, currentItemData = getBackpackItems()

local ItemDropdown = Tab:CreateDropdown({
   Name = "Select Item to Send",
   Options = initialOptions,
   CurrentOption = {""},
   MultipleOptions = false,
   Flag = "ItemDropdown",
   Callback = function(Options)
       -- ตัด (xจำนวน) ออก เพื่อเอาชื่อที่แท้จริงไปใช้งาน
       local cleanSelection = string.gsub(Options[1], " %(x%d+%)$", "")
       selectedItem = cleanSelection
   end,
})

Tab:CreateButton({
   Name = "🔄 Refresh Backpack Items",
   Callback = function()
       local newOptions, newData = getBackpackItems()
       currentItemData = newData
       ItemDropdown:Refresh(newOptions)
       Rayfield:Notify({Title = "Refreshed", Content = "Backpack updated.", Duration = 3})
   end,
})

Tab:CreateInput({
   Name = "Amount",
   PlaceholderText = "Enter amount (e.g. 10)",
   NumbersOnly = true,
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
       amountToSend = tonumber(Text) or 1
   end,
})

Tab:CreateSection("Action")

Tab:CreateButton({
   Name = "🚀 SEND MAIL",
   Callback = function()
       if targetUsername == "" then
           Rayfield:Notify({Title = "Error", Content = "Please enter a username!", Duration = 3})
           return
       end
       
       if selectedItem == "" or selectedItem == "No items found" then
           Rayfield:Notify({Title = "Error", Content = "Please select a valid item!", Duration = 3})
           return
       end

       local data = currentItemData[selectedItem]
       if not data or data.count == 0 then
           Rayfield:Notify({Title = "Error", Content = "You don't have this item!", Duration = 3})
           return
       end

       local finalAmount = math.min(amountToSend, data.count)
       local resolvedToPass = {}
       
       if data.isUUID then
           -- ส่ง Fruits / Pets ทีละรหัส (แต่ไปเป็นกล่องเดียวกัน)
           for i = 1, finalAmount do
               table.insert(resolvedToPass, {
                   Category = data.category,
                   ItemKey = data.uuids[i],
                   Count = 1,
                   DisplayName = selectedItem
               })
           end
       else
           -- ส่ง Seed / Stackable ตามจำนวนที่มีในช่อง 'Count'
           local cat, key = resolveItem(data.rawName)
           table.insert(resolvedToPass, {
               Category = cat,
               ItemKey = key,
               Count = finalAmount,
               DisplayName = selectedItem
           })
       end
       
       Rayfield:Notify({
           Title = "Sending...",
           Content = "Sending " .. finalAmount .. "x " .. selectedItem .. " to " .. targetUsername,
           Duration = 3,
       })

       local success, msg = Send(targetUsername, resolvedToPass)

       if success then
           Rayfield:Notify({Title = "Success", Content = msg, Duration = 5})
           local newOptions, newData = getBackpackItems()
           currentItemData = newData
           ItemDropdown:Refresh(newOptions)
       else
           Rayfield:Notify({Title = "Failed", Content = msg, Duration = 5})
       end
   end,
})
