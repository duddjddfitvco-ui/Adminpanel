--[[
Place this LocalScript in: StarterPlayer > StarterPlayerScripts
Builds a light frosted-glass Admin Panel entirely with Instance.new().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("AdminRemotes")
local requestRemote = remotes:WaitForChild("AdminRequest")
local responseRemote = remotes:WaitForChild("AdminResponse")

local Colors = {
	Panel = Color3.fromRGB(245, 245, 250),
	PanelAlt = Color3.fromRGB(237, 241, 247),
	PanelSoft = Color3.fromRGB(230, 236, 245),
	Blue = Color3.fromRGB(59, 130, 246),
	Text = Color3.fromRGB(51, 65, 85),
	TextSoft = Color3.fromRGB(100, 116, 139),
	White = Color3.fromRGB(255, 255, 255),
	Error = Color3.fromRGB(220, 38, 38),
}

local ui = {}
local pendingCallbacks = {}
local requestId = 0
local currentTargetName = nil

local function addRound(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
end

local function makeFrame(parent, name, size, position, color, transparency, radius)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent
	addRound(frame, radius or 18)
	return frame
end

local function makeLabel(parent, name, text, size, position, textSize, color, bold)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Colors.Text
	label.TextSize = textSize or 14
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, size, position, bgColor, textColor)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = bgColor
	button.TextColor3 = textColor or Colors.Text
	button.Text = text
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 14
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Parent = parent
	addRound(button, 12)
	return button
end

local function makeTextBox(parent, name, placeholder, size, position)
	local box = Instance.new("TextBox")
	box.Name = name
	box.Size = size
	box.Position = position
	box.BackgroundColor3 = Colors.PanelSoft
	box.BackgroundTransparency = 0.2
	box.TextColor3 = Colors.Text
	box.PlaceholderColor3 = Colors.TextSoft
	box.PlaceholderText = placeholder
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.TextSize = 14
	box.BorderSizePixel = 0
	box.Parent = parent
	addRound(box, 12)
	return box
end

local function setStatus(text, isError)
	ui.StatusLabel.Text = text
	ui.StatusLabel.TextColor3 = isError and Colors.Error or Colors.Text
end

local function sendRequest(action, payload, callback)
	requestId += 1
	local id = requestId
	if callback then
		pendingCallbacks[id] = callback
	end
	requestRemote:FireServer({
		requestId = id,
		action = action,
		payload = payload or {},
	})
end

responseRemote.OnClientEvent:Connect(function(packet)
	if typeof(packet) ~= "table" then
		return
	end

	if packet.requestId and pendingCallbacks[packet.requestId] then
		pendingCallbacks[packet.requestId](packet)
		pendingCallbacks[packet.requestId] = nil
	elseif packet.type == "Broadcast" then
		setStatus(packet.message or "Server message", false)
	end
end)

local function selectTab(tabName)
	for name, page in pairs(ui.Pages) do
		page.Visible = (name == tabName)
	end
	for name, button in pairs(ui.NavButtons) do
		local target = (name == tabName) and Colors.Blue or Colors.PanelSoft
		local textColor = (name == tabName) and Colors.White or Colors.Text
		TweenService:Create(button, TweenInfo.new(0.15), {
			BackgroundColor3 = target,
			TextColor3 = textColor,
		}):Play()
	end
end

local function fillPlayerData(data)
	ui.AccountName.Text = "Name: " .. tostring(data.displayName or data.username or "-")
	ui.AccountUserId.Text = "UserId: " .. tostring(data.userId or "-")
	ui.AccountRole.Text = "Role: " .. tostring(data.role or "Player")
	ui.DataCoins.Text = "Coins: " .. tostring((data.stats and data.stats.Coins) or 0)
	ui.DataLevel.Text = "Level: " .. tostring((data.stats and data.stats.Level) or 0)
end

local function setupSmoothDrag(dragHandle, panel)
	local dragging = false
	local dragStart = Vector2.zero
	local panelStart = Vector2.zero
	local targetPos = panel.Position
	local lerpAlpha = 0.22

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = UserInputService:GetMouseLocation()
			panelStart = Vector2.new(panel.Position.X.Scale, panel.Position.Y.Scale)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		if dragging then
			local now = UserInputService:GetMouseLocation()
			local delta = now - dragStart
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			local dxScale = delta.X / viewport.X
			local dyScale = delta.Y / viewport.Y
			targetPos = UDim2.fromScale(panelStart.X + dxScale, panelStart.Y + dyScale)
		end

		local current = panel.Position
		local newX = current.X.Scale + (targetPos.X.Scale - current.X.Scale) * lerpAlpha
		local newY = current.Y.Scale + (targetPos.Y.Scale - current.Y.Scale) * lerpAlpha
		panel.Position = UDim2.fromScale(newX, newY)
	end)
end

local function buildGui()
	local screen = Instance.new("ScreenGui")
	screen.Name = "AutoAdminPanel"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = makeFrame(
		screen,
		"MainPanel",
		UDim2.fromScale(0.78, 0.74),
		UDim2.fromScale(0.11, 0.13),
		Colors.Panel,
		0.2,
		16
	)
	addStroke(panel, Color3.fromRGB(200, 210, 225), 0.2)
	panel.Visible = false
	ui.MainPanel = panel

	local topBar = makeFrame(panel, "TopBar", UDim2.new(1, -16, 0, 56), UDim2.new(0, 8, 0, 8), Colors.PanelAlt, 0.15, 14)
	addStroke(topBar, Color3.fromRGB(210, 220, 235), 0.3)

	local stat1 = makeLabel(topBar, "UptimeTitle", "Server up-time:", UDim2.new(0, 130, 1, 0), UDim2.new(0, 12, 0, 0), 14, Colors.Text, true)
	stat1.TextYAlignment = Enum.TextYAlignment.Center
	ui.UptimeValue = makeLabel(topBar, "UptimeValue", "0m", UDim2.new(0, 120, 1, 0), UDim2.new(0, 148, 0, 0), 14, Colors.Text, true)
	ui.UptimeValue.TextYAlignment = Enum.TextYAlignment.Center

	local stat2 = makeLabel(topBar, "PlayersTitle", "Players:", UDim2.new(0, 80, 1, 0), UDim2.new(0, 300, 0, 0), 14, Colors.Text, true)
	stat2.TextYAlignment = Enum.TextYAlignment.Center
	ui.PlayersValue = makeLabel(topBar, "PlayersValue", "0", UDim2.new(0, 70, 1, 0), UDim2.new(0, 380, 0, 0), 14, Colors.Text, true)
	ui.PlayersValue.TextYAlignment = Enum.TextYAlignment.Center

	local sidebar = makeFrame(panel, "Sidebar", UDim2.new(0, 190, 1, -96), UDim2.new(0, 8, 0, 70), Colors.PanelAlt, 0.1, 14)
	addStroke(sidebar, Color3.fromRGB(210, 220, 235), 0.3)

	local profile = makeFrame(sidebar, "Profile", UDim2.new(1, -12, 0, 60), UDim2.new(0, 6, 0, 6), Colors.PanelSoft, 0.15, 12)
	makeLabel(profile, "UserName", localPlayer.DisplayName, UDim2.new(1, -12, 0, 22), UDim2.new(0, 8, 0, 6), 15, Colors.Text, true)
	makeLabel(profile, "AtUser", "@" .. localPlayer.Name, UDim2.new(1, -12, 0, 18), UDim2.new(0, 8, 0, 30), 13, Colors.TextSoft, false)

	local navHolder = Instance.new("Frame")
	navHolder.Name = "NavHolder"
	navHolder.BackgroundTransparency = 1
	navHolder.Size = UDim2.new(1, -12, 1, -78)
	navHolder.Position = UDim2.new(0, 6, 0, 72)
	navHolder.Parent = sidebar

	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 8)
	navLayout.Parent = navHolder

	local content = makeFrame(panel, "Content", UDim2.new(1, -206, 1, -96), UDim2.new(0, 198, 0, 70), Colors.PanelAlt, 0.1, 14)
	addStroke(content, Color3.fromRGB(210, 220, 235), 0.3)

	ui.StatusLabel = makeLabel(panel, "StatusLabel", "Ready", UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 1, -26), 14, Colors.Text, true)

	local dataPage = Instance.new("Frame")
	dataPage.Name = "DataPage"
	dataPage.BackgroundTransparency = 1
	dataPage.Size = UDim2.new(1, -12, 1, -12)
	dataPage.Position = UDim2.new(0, 6, 0, 6)
	dataPage.Parent = content

	local characterPage = dataPage:Clone()
	characterPage.Name = "CharacterPage"
	characterPage.Parent = content
	characterPage.Visible = false

	local worldPage = dataPage:Clone()
	worldPage.Name = "WorldPage"
	worldPage.Parent = content
	worldPage.Visible = false

	local toolsPage = dataPage:Clone()
	toolsPage.Name = "ToolsPage"
	toolsPage.Parent = content
	toolsPage.Visible = false

	ui.Pages = {
		Data = dataPage,
		Character = characterPage,
		World = worldPage,
		Tools = toolsPage,
	}

	ui.NavButtons = {}
	for _, tabName in ipairs({ "Data", "Character", "World", "Tools" }) do
		local b = makeButton(navHolder, tabName .. "Btn", tabName, UDim2.new(1, 0, 0, 38), UDim2.new(), Colors.PanelSoft, Colors.Text)
		ui.NavButtons[tabName] = b
		b.MouseButton1Click:Connect(function()
			selectTab(tabName)
		end)
	end

	ui.SearchBox = makeTextBox(dataPage, "SearchBox", "Username...", UDim2.new(1, -16, 0, 36), UDim2.new(0, 8, 0, 8))
	local account = makeFrame(dataPage, "AccountSection", UDim2.new(1, -16, 0, 110), UDim2.new(0, 8, 0, 54), Colors.PanelSoft, 0.15, 12)
	makeLabel(account, "AccountTitle", "Account info", UDim2.new(1, -12, 0, 24), UDim2.new(0, 8, 0, 6), 18, Colors.Text, true)
	ui.AccountName = makeLabel(account, "AccountName", "Name: -", UDim2.new(1, -12, 0, 20), UDim2.new(0, 8, 0, 35), 14, Colors.TextSoft, false)
	ui.AccountUserId = makeLabel(account, "AccountUserId", "UserId: -", UDim2.new(1, -12, 0, 20), UDim2.new(0, 8, 0, 58), 14, Colors.TextSoft, false)
	ui.AccountRole = makeLabel(account, "AccountRole", "Role: -", UDim2.new(1, -12, 0, 20), UDim2.new(0, 8, 0, 81), 14, Colors.TextSoft, false)

	local dataSection = makeFrame(dataPage, "DataSection", UDim2.new(1, -16, 0, 90), UDim2.new(0, 8, 0, 170), Colors.PanelSoft, 0.15, 12)
	makeLabel(dataSection, "DataTitle", "Data", UDim2.new(1, -12, 0, 24), UDim2.new(0, 8, 0, 6), 18, Colors.Text, true)
	ui.DataCoins = makeLabel(dataSection, "Coins", "Coins: -", UDim2.new(0.5, -8, 0, 20), UDim2.new(0, 8, 0, 38), 14, Colors.TextSoft, false)
	ui.DataLevel = makeLabel(dataSection, "Level", "Level: -", UDim2.new(0.5, -8, 0, 20), UDim2.new(0.5, 0, 0, 38), 14, Colors.TextSoft, false)

	ui.KickButton = makeButton(characterPage, "KickButton", "Kick", UDim2.new(0, 120, 0, 36), UDim2.new(0, 8, 0, 8), Colors.Blue, Colors.White)
	ui.BanButton = makeButton(characterPage, "BanButton", "Ban", UDim2.new(0, 120, 0, 36), UDim2.new(0, 136, 0, 8), Colors.Blue, Colors.White)
	ui.HealButton = makeButton(characterPage, "HealButton", "Heal", UDim2.new(0, 120, 0, 36), UDim2.new(0, 264, 0, 8), Colors.Blue, Colors.White)
	ui.TeleportButton = makeButton(characterPage, "TeleportButton", "Bring", UDim2.new(0, 120, 0, 36), UDim2.new(0, 392, 0, 8), Colors.Blue, Colors.White)

	ui.TimeBox = makeTextBox(worldPage, "TimeBox", "HH:MM:SS", UDim2.new(0, 180, 0, 36), UDim2.new(0, 8, 0, 8))
	ui.TimeBox.Text = "14:00:00"
	ui.SetTimeButton = makeButton(worldPage, "SetTimeButton", "Set Time", UDim2.new(0, 120, 0, 36), UDim2.new(0, 196, 0, 8), Colors.Blue, Colors.White)

	makeLabel(toolsPage, "ToolsLabel", "Tools tab ready for your custom actions.", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 8), 14, Colors.TextSoft, false)

	setupSmoothDrag(topBar, panel)
	selectTab("Data")

	return panel
end

local function wireActions(mainPanel)
	ui.SearchBox.FocusLost:Connect(function(enterPressed)
		if not enterPressed then
			return
		end
		local target = ui.SearchBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if target == "" then
			setStatus("Player not found", true)
			return
		end

		sendRequest("GetPlayerData", { targetName = target }, function(packet)
			if not packet.ok then
				setStatus(packet.message or "Player not found", true)
				return
			end
			currentTargetName = packet.data and packet.data.username
			fillPlayerData(packet.data or {})
			setStatus("Loaded " .. tostring(currentTargetName), false)
		end)
	end)

	ui.KickButton.MouseButton1Click:Connect(function()
		if not currentTargetName then
			setStatus("Search a player first", true)
			return
		end
		sendRequest("KickPlayer", { targetName = currentTargetName }, function(packet)
			setStatus(packet.message or "Kick done", not packet.ok)
		end)
	end)

	ui.BanButton.MouseButton1Click:Connect(function()
		if not currentTargetName then
			setStatus("Search a player first", true)
			return
		end
		sendRequest("BanPlayer", {
			targetName = currentTargetName,
			reason = "Banned by admin panel",
			duration = 3600,
		}, function(packet)
			setStatus(packet.message or "Ban done", not packet.ok)
		end)
	end)

	ui.HealButton.MouseButton1Click:Connect(function()
		if not currentTargetName then
			setStatus("Search a player first", true)
			return
		end
		sendRequest("HealPlayer", { targetName = currentTargetName }, function(packet)
			setStatus(packet.message or "Heal done", not packet.ok)
		end)
	end)

	ui.TeleportButton.MouseButton1Click:Connect(function()
		if not currentTargetName then
			setStatus("Search a player first", true)
			return
		end
		sendRequest("TeleportPlayerToMe", { targetName = currentTargetName }, function(packet)
			setStatus(packet.message or "Teleport done", not packet.ok)
		end)
	end)

	ui.SetTimeButton.MouseButton1Click:Connect(function()
		sendRequest("SetTimeOfDay", { timeString = ui.TimeBox.Text }, function(packet)
			setStatus(packet.message or "Time set", not packet.ok)
		end)
	end)

	local opened = false
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightShift then
			opened = not opened
			mainPanel.Visible = opened
		end
	end)
end

sendRequest("Init", {}, function(packet)
	if not packet.ok then
		warn("Admin panel not available for this account: " .. tostring(packet.message))
		return
	end

	local mainPanel = buildGui()
	wireActions(mainPanel)
	setStatus("Press RightShift to open panel", false)

	local serverStart = (packet.data and packet.data.serverStart) or os.time()
	task.spawn(function()
		while mainPanel.Parent do
			task.wait(1)
			local elapsed = math.max(0, os.time() - serverStart)
			local min = math.floor(elapsed / 60)
			ui.UptimeValue.Text = string.format("%dm", min)
			ui.PlayersValue.Text = tostring(#Players:GetPlayers())
		end
	end)
end)
