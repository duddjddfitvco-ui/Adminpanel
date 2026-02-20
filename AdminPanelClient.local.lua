--[[
Place this LocalScript in: StarterPlayer > StarterPlayerScripts
It generates the entire admin UI at runtime using Instance.new().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("AdminRemotes")
local requestRemote = remotesFolder:WaitForChild("AdminRequest")
local responseRemote = remotesFolder:WaitForChild("AdminResponse")

local pending = {}
local reqId = 0

local function sendRequest(action, payload, callback)
	reqId += 1
	local id = reqId
	if callback then
		pending[id] = callback
	end
	requestRemote:FireServer({
		requestId = id,
		action = action,
		payload = payload or {}
	})
end

responseRemote.OnClientEvent:Connect(function(packet)
	if typeof(packet) ~= "table" then
		return
	end
	local id = packet.requestId
	if id and pending[id] then
		pending[id](packet)
		pending[id] = nil
	end
end)

local COLORS = {
	bg = Color3.fromRGB(22, 27, 34),
	panel = Color3.fromRGB(30, 36, 45),
	panel2 = Color3.fromRGB(36, 43, 54),
	accent = Color3.fromRGB(59, 130, 246), -- #3B82F6
	text = Color3.fromRGB(245, 247, 250),
	muted = Color3.fromRGB(170, 180, 195),
	error = Color3.fromRGB(239, 68, 68)
}

local function round(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = instance
end

local function makeLabel(parent, name, text, size, pos, color, align)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or COLORS.text
	lbl.TextXAlignment = align or Enum.TextXAlignment.Left
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 14
	lbl.Size = size
	lbl.Position = pos
	lbl.Parent = parent
	return lbl
end

local function makeButton(parent, name, text, size, pos, bg)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.TextColor3 = COLORS.text
	btn.BackgroundColor3 = bg or COLORS.panel2
	btn.Size = size
	btn.Position = pos
	btn.AutoButtonColor = false
	btn.Parent = parent
	round(btn, 8)
	return btn
end

local ui = {}

local function setStatus(text, isError)
	if ui.StatusLabel then
		ui.StatusLabel.Text = text
		ui.StatusLabel.TextColor3 = isError and COLORS.error or COLORS.text
	end
end

local function setSelected(navButton)
	for _, b in pairs(ui.NavButtons) do
		local target = (b == navButton) and COLORS.accent or COLORS.panel2
		TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = target}):Play()
	end
end

local function switchTab(name)
	for tabName, frame in pairs(ui.Pages) do
		frame.Visible = (tabName == name)
	end
	setSelected(ui.NavButtons[name])
end

local function buildUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "AutoAdminPanel"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	local main = Instance.new("Frame")
	main.Name = "MainPanel"
	main.Size = UDim2.fromScale(0.78, 0.72)
	main.Position = UDim2.fromScale(0.11, 0.14)
	main.BackgroundColor3 = COLORS.bg
	main.BackgroundTransparency = 0.15
	main.Visible = false
	main.Parent = screen
	round(main, 14)

	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.Size = UDim2.new(1, -16, 0, 54)
	top.Position = UDim2.new(0, 8, 0, 8)
	top.BackgroundColor3 = COLORS.panel
	top.Parent = main
	round(top, 12)

	ui.UptimeLabel = makeLabel(top, "Uptime", "Up-time: 00m 00s", UDim2.new(0.5, -8, 1, 0), UDim2.new(0, 10, 0, 0))
	ui.PlayersLabel = makeLabel(top, "Players", "Players: 0", UDim2.new(0.5, -8, 1, 0), UDim2.new(0.5, 0, 0, 0))

	local side = Instance.new("Frame")
	side.Name = "Sidebar"
	side.Size = UDim2.new(0, 180, 1, -92)
	side.Position = UDim2.new(0, 8, 0, 70)
	side.BackgroundColor3 = COLORS.panel
	side.Parent = main
	round(side, 12)

	makeLabel(side, "Title", "ADMIN", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 8), COLORS.text, Enum.TextXAlignment.Center)

	local navContainer = Instance.new("Frame")
	navContainer.Name = "NavContainer"
	navContainer.BackgroundTransparency = 1
	navContainer.Size = UDim2.new(1, -16, 1, -50)
	navContainer.Position = UDim2.new(0, 8, 0, 42)
	navContainer.Parent = side

	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 8)
	navLayout.FillDirection = Enum.FillDirection.Vertical
	navLayout.Parent = navContainer

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -204, 1, -92)
	content.Position = UDim2.new(0, 196, 0, 70)
	content.BackgroundColor3 = COLORS.panel
	content.Parent = main
	round(content, 12)

	local status = Instance.new("TextLabel")
	status.Name = "StatusLabel"
	status.Size = UDim2.new(1, -16, 0, 22)
	status.Position = UDim2.new(0, 8, 1, -26)
	status.BackgroundTransparency = 1
	status.Text = "Ready"
	status.Font = Enum.Font.Gotham
	status.TextSize = 13
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = COLORS.text
	status.Parent = main
	ui.StatusLabel = status

	ui.Pages = {}
	local function makePage(name)
		local page = Instance.new("Frame")
		page.Name = name .. "Page"
		page.BackgroundTransparency = 1
		page.Size = UDim2.new(1, -14, 1, -14)
		page.Position = UDim2.new(0, 7, 0, 7)
		page.Visible = false
		page.Parent = content
		ui.Pages[name] = page
		return page
	end

	local dataPage = makePage("Data")
	local charPage = makePage("Character")
	local worldPage = makePage("World")
	local toolsPage = makePage("Tools")

	ui.NavButtons = {}
	for _, name in ipairs({"Data", "Character", "World", "Tools"}) do
		local btn = makeButton(navContainer, name, name, UDim2.new(1, 0, 0, 36), UDim2.new(), COLORS.panel2)
		ui.NavButtons[name] = btn
		btn.MouseButton1Click:Connect(function()
			switchTab(name)
		end)
	end

	-- Data page
	ui.SearchBox = Instance.new("TextBox")
	ui.SearchBox.Name = "SearchBox"
	ui.SearchBox.Size = UDim2.new(1, -16, 0, 34)
	ui.SearchBox.Position = UDim2.new(0, 8, 0, 8)
	ui.SearchBox.BackgroundColor3 = COLORS.panel2
	ui.SearchBox.PlaceholderText = "Username..."
	ui.SearchBox.Text = ""
	ui.SearchBox.Font = Enum.Font.Gotham
	ui.SearchBox.TextSize = 14
	ui.SearchBox.TextColor3 = COLORS.text
	ui.SearchBox.PlaceholderColor3 = COLORS.muted
	ui.SearchBox.Parent = dataPage
	round(ui.SearchBox, 8)

	local account = Instance.new("Frame")
	account.Name = "AccountInfo"
	account.Size = UDim2.new(1, -16, 0, 110)
	account.Position = UDim2.new(0, 8, 0, 52)
	account.BackgroundColor3 = COLORS.panel2
	account.Parent = dataPage
	round(account, 10)
	makeLabel(account, "Title", "Account info", UDim2.new(1, -12, 0, 24), UDim2.new(0, 8, 0, 4), COLORS.text)
	ui.NameLabel = makeLabel(account, "Name", "Name: -", UDim2.new(1, -12, 0, 20), UDim2.new(0, 8, 0, 30), COLORS.muted)
	ui.UserIdLabel = makeLabel(account, "UserId", "UserId: -", UDim2.new(1, -12, 0, 20), UDim2.new(0, 8, 0, 52), COLORS.muted)

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Size = UDim2.new(1, -16, 0, 94)
	stats.Position = UDim2.new(0, 8, 0, 170)
	stats.BackgroundColor3 = COLORS.panel2
	stats.Parent = dataPage
	round(stats, 10)
	makeLabel(stats, "Title", "Data", UDim2.new(1, -12, 0, 24), UDim2.new(0, 8, 0, 4), COLORS.text)
	ui.CoinsLabel = makeLabel(stats, "Coins", "Coins: -", UDim2.new(1, -12, 0, 20), UDim2.new(0, 8, 0, 30), COLORS.muted)
	ui.LevelLabel = makeLabel(stats, "Level", "Level: -", UDim2.new(1, -12, 0, 20), UDim2.new(0, 8, 0, 52), COLORS.muted)

	-- Character page
	ui.KickBtn = makeButton(charPage, "Kick", "Kick", UDim2.new(0, 120, 0, 34), UDim2.new(0, 8, 0, 8), COLORS.accent)
	ui.BanBtn = makeButton(charPage, "Ban", "Ban", UDim2.new(0, 120, 0, 34), UDim2.new(0, 136, 0, 8), COLORS.accent)
	ui.HealBtn = makeButton(charPage, "Heal", "Heal", UDim2.new(0, 120, 0, 34), UDim2.new(0, 264, 0, 8), COLORS.accent)

	-- World page
	ui.TimeBox = Instance.new("TextBox")
	ui.TimeBox.Name = "TimeBox"
	ui.TimeBox.Size = UDim2.new(0, 180, 0, 34)
	ui.TimeBox.Position = UDim2.new(0, 8, 0, 8)
	ui.TimeBox.BackgroundColor3 = COLORS.panel2
	ui.TimeBox.PlaceholderText = "HH:MM:SS"
	ui.TimeBox.Text = "14:00:00"
	ui.TimeBox.Font = Enum.Font.Gotham
	ui.TimeBox.TextSize = 14
	ui.TimeBox.TextColor3 = COLORS.text
	ui.TimeBox.PlaceholderColor3 = COLORS.muted
	ui.TimeBox.Parent = worldPage
	round(ui.TimeBox, 8)

	ui.SetTimeBtn = makeButton(worldPage, "SetTime", "Set Time", UDim2.new(0, 120, 0, 34), UDim2.new(0, 196, 0, 8), COLORS.accent)

	-- Tools page placeholder
	makeLabel(toolsPage, "Info", "Tools tab scaffolded (add your own tool actions here).", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 8), COLORS.muted)

	return screen, main
end

local currentTarget = nil

sendRequest("Init", {}, function(initPacket)
	if not initPacket.ok then
		warn("Admin panel denied: " .. tostring(initPacket.message))
		return
	end

	local _, mainPanel = buildUI()
	switchTab("Data")
	setStatus("Press RightShift to open/close", false)

	local serverStart = (initPacket.data and initPacket.data.serverStart) or os.time()
	task.spawn(function()
		while mainPanel.Parent do
			task.wait(1)
			local elapsed = os.time() - serverStart
			local mins = math.floor(elapsed / 60)
			local secs = elapsed % 60
			ui.UptimeLabel.Text = string.format("Up-time: %02dm %02ds", mins, secs)
			ui.PlayersLabel.Text = "Players: " .. tostring(#Players:GetPlayers())
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			mainPanel.Visible = not mainPanel.Visible
		end
	end)

	ui.SearchBox.FocusLost:Connect(function(enterPressed)
		if not enterPressed then return end
		local username = ui.SearchBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if username == "" then
			setStatus("Type a username first", true)
			return
		end

		sendRequest("GetPlayerData", {targetName = username}, function(packet)
			if not packet.ok then
				setStatus(packet.message or "Player not found", true)
				return
			end
			local data = packet.data or {}
			currentTarget = data.username
			ui.NameLabel.Text = "Name: " .. tostring(data.displayName or data.username or "-")
			ui.UserIdLabel.Text = "UserId: " .. tostring(data.userId or "-")
			ui.CoinsLabel.Text = "Coins: " .. tostring((data.stats and data.stats.Coins) or 0)
			ui.LevelLabel.Text = "Level: " .. tostring((data.stats and data.stats.Level) or 0)
			setStatus("Loaded " .. tostring(currentTarget), false)
		end)
	end)

	ui.KickBtn.MouseButton1Click:Connect(function()
		if not currentTarget then
			setStatus("Search a player first", true)
			return
		end
		sendRequest("KickPlayer", {targetName = currentTarget}, function(packet)
			setStatus(packet.message or "Kick complete", not packet.ok)
		end)
	end)

	ui.BanBtn.MouseButton1Click:Connect(function()
		if not currentTarget then
			setStatus("Search a player first", true)
			return
		end
		sendRequest("BanPlayer", {targetName = currentTarget}, function(packet)
			setStatus(packet.message or "Ban complete", not packet.ok)
		end)
	end)

	ui.HealBtn.MouseButton1Click:Connect(function()
		if not currentTarget then
			setStatus("Search a player first", true)
			return
		end
		sendRequest("HealPlayer", {targetName = currentTarget}, function(packet)
			setStatus(packet.message or "Heal complete", not packet.ok)
		end)
	end)

	ui.SetTimeBtn.MouseButton1Click:Connect(function()
		sendRequest("SetTimeOfDay", {timeString = ui.TimeBox.Text}, function(packet)
			setStatus(packet.message or "Time changed", not packet.ok)
		end)
	end)
end)
