-- AdminClient (LocalScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local mainPanel = gui:WaitForChild("MainPanel")

local remotesFolder = ReplicatedStorage:WaitForChild("AdminRemotes")
local adminRequest = remotesFolder:WaitForChild("AdminRequest")
local adminResponse = remotesFolder:WaitForChild("AdminResponse")

-- UI refs
local sidebar = mainPanel:WaitForChild("Sidebar")
local content = mainPanel:WaitForChild("Content")
local bottomBar = mainPanel:WaitForChild("BottomBar")
local statusLabel = bottomBar:WaitForChild("StatusLabel")

local topBar = mainPanel:WaitForChild("TopBar")
local uptimeLabel = topBar:WaitForChild("UptimeCard"):WaitForChild("ValueLabel")
local playingLabel = topBar:WaitForChild("PlayingCard"):WaitForChild("ValueLabel")
local totalJoinedLabel = topBar:WaitForChild("TotalJoinedCard"):WaitForChild("ValueLabel")
local playersLabel = topBar:WaitForChild("PlayersCard"):WaitForChild("ValueLabel")

local profileFrame = sidebar:WaitForChild("ProfileFrame")
profileFrame:WaitForChild("DisplayNameLabel").Text = player.DisplayName
profileFrame:WaitForChild("UsernameLabel").Text = "@" .. player.Name
pcall(function()
	profileFrame:WaitForChild("AvatarImage").Image =
		Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)

local pages = {
	Data = content:WaitForChild("DataPage"),
	Character = content:WaitForChild("CharacterPage"),
	World = content:WaitForChild("WorldPage"),
	Tools = content:WaitForChild("ToolsPage"),
	Flocks = content:WaitForChild("FlocksPage"),
	Mailbox = content:WaitForChild("MailboxPage"),
}

local navButtons = {
	Data = sidebar:WaitForChild("NavButtons"):WaitForChild("DataButton"),
	Character = sidebar.NavButtons:WaitForChild("CharacterButton"),
	World = sidebar.NavButtons:WaitForChild("WorldButton"),
	Tools = sidebar.NavButtons:WaitForChild("ToolsButton"),
	Flocks = sidebar.NavButtons:WaitForChild("FlocksButton"),
	Mailbox = sidebar.NavButtons:WaitForChild("MailboxButton"),
}

local selectedColor = Color3.fromRGB(59,130,246)
local normalColor = Color3.fromRGB(33,39,49)

local function setStatus(text, isError)
	statusLabel.Text = text
	statusLabel.TextColor3 = isError and Color3.fromRGB(239,68,68) or Color3.fromRGB(255,255,255)
end

local function switchTab(tabName)
	for name, page in pairs(pages) do
		page.Visible = (name == tabName)
	end
	for name, button in pairs(navButtons) do
		local targetColor = (name == tabName) and selectedColor or normalColor
		TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
	end
end

for tabName, button in pairs(navButtons) do
	button.MouseButton1Click:Connect(function()
		switchTab(tabName)
	end)
end

-- Toggle panel with RightShift
mainPanel.Visible = false
local open = false
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		open = not open
		mainPanel.Visible = open
	end
end)

-- Request/response helper
local requestId = 0
local pending = {}

adminResponse.OnClientEvent:Connect(function(packet)
	-- packet = {requestId=?, ok=?, message=?, data=?, type=?}
	if packet and packet.requestId and pending[packet.requestId] then
		pending[packet.requestId](packet)
		pending[packet.requestId] = nil
	elseif packet and packet.type == "Status" then
		setStatus(packet.message or "Status update", not packet.ok)
	end
end)

local function sendRequest(action, payload, callback)
	requestId += 1
	local id = requestId
	if callback then
		pending[id] = callback
	end
	adminRequest:FireServer({
		requestId = id,
		action = action,
		payload = payload or {}
	})
end

-- Data page refs
local dataPage = pages.Data
local searchBar = dataPage:WaitForChild("SearchBar")
local accountSection = dataPage:WaitForChild("AccountInfoSection")
local dataSection = dataPage:WaitForChild("DataSection")

local coinsLabel = dataSection:WaitForChild("CoinsLabel")
local levelLabel = dataSection:WaitForChild("LevelLabel")

local currentTargetName = nil

local function fillPlayerData(data)
	-- data: {username, displayName, userId, role, joinDate, stats={Coins=,Level=}}
	accountSection.RoleLabel.Text = "Role: " .. (data.role or "Player")
	accountSection.JoinDateLabel.Text = "Join date: " .. (data.joinDate or "Unknown")
	accountSection.UserIdLabel.Text = "UserId: " .. tostring(data.userId or "N/A")

	coinsLabel.Text = "Coins: " .. tostring((data.stats and data.stats.Coins) or 0)
	levelLabel.Text = "Level: " .. tostring((data.stats and data.stats.Level) or 0)
end

searchBar.FocusLost:Connect(function(enterPressed)
	if not enterPressed then return end
	local username = searchBar.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if username == "" then
		setStatus("Please enter a username", true)
		return
	end

	sendRequest("GetPlayerData", {targetName = username}, function(packet)
		if not packet.ok then
			setStatus(packet.message or "Player not found", true)
			return
		end
		currentTargetName = username
		fillPlayerData(packet.data)
		setStatus("Loaded " .. username, false)
	end)
end)

dataSection.AddCoinsButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	sendRequest("AdjustStat", {
		targetName = currentTargetName,
		statName = "Coins",
		delta = 100
	}, function(packet)
		setStatus(packet.message or "Done", not packet.ok)
	end)
end)

dataSection.RemoveCoinsButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	sendRequest("AdjustStat", {
		targetName = currentTargetName,
		statName = "Coins",
		delta = -100
	}, function(packet)
		setStatus(packet.message or "Done", not packet.ok)
	end)
end)

-- Character page
local charPage = pages.Character
charPage.KickButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	sendRequest("KickPlayer", {targetName = currentTargetName, reason = "Kicked by admin panel"}, function(packet)
		setStatus(packet.message or "Kick sent", not packet.ok)
	end)
end)

charPage.BanButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	sendRequest("BanPlayer", {targetName = currentTargetName, reason = "Banned by admin panel"}, function(packet)
		setStatus(packet.message or "Ban sent", not packet.ok)
	end)
end)

charPage.HealButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	sendRequest("HealPlayer", {targetName = currentTargetName}, function(packet)
		setStatus(packet.message or "Healed", not packet.ok)
	end)
end)

charPage.SetWalkSpeedButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	local ws = tonumber(charPage.WalkSpeedBox.Text)
	if not ws then setStatus("Invalid WalkSpeed", true) return end
	sendRequest("SetMovement", {targetName = currentTargetName, walkSpeed = ws}, function(packet)
		setStatus(packet.message or "WalkSpeed set", not packet.ok)
	end)
end)

charPage.SetJumpPowerButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	local jp = tonumber(charPage.JumpPowerBox.Text)
	if not jp then setStatus("Invalid JumpPower", true) return end
	sendRequest("SetMovement", {targetName = currentTargetName, jumpPower = jp}, function(packet)
		setStatus(packet.message or "JumpPower set", not packet.ok)
	end)
end)

-- World page
local worldPage = pages.World
worldPage.SetTimeButton.MouseButton1Click:Connect(function()
	sendRequest("SetTimeOfDay", {timeString = worldPage.TimeOfDayBox.Text}, function(packet)
		setStatus(packet.message or "Time changed", not packet.ok)
	end)
end)

worldPage.AnnounceButton.MouseButton1Click:Connect(function()
	local msg = worldPage.AnnouncementBox.Text
	if msg == "" then setStatus("Announcement is empty", true) return end
	sendRequest("ServerAnnouncement", {message = msg}, function(packet)
		setStatus(packet.message or "Announcement sent", not packet.ok)
	end)
end)

-- Tools page
local toolsPage = pages.Tools
toolsPage.GiveToolButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	local toolName = toolsPage.ToolNameBox.Text
	sendRequest("GiveTool", {targetName = currentTargetName, toolName = toolName}, function(packet)
		setStatus(packet.message or "Tool given", not packet.ok)
	end)
end)

toolsPage.RemoveToolButton.MouseButton1Click:Connect(function()
	if not currentTargetName then setStatus("Search a player first", true) return end
	local toolName = toolsPage.ToolNameBox.Text
	sendRequest("RemoveTool", {targetName = currentTargetName, toolName = toolName}, function(packet)
		setStatus(packet.message or "Tool removed", not packet.ok)
	end)
end)

-- Init request (access + top stats)
sendRequest("Init", {}, function(packet)
	if not packet.ok then
		mainPanel.Visible = false
		setStatus(packet.message or "Not authorized", true)
		return
	end

	local data = packet.data or {}
	local serverStart = data.serverStart or os.time()
	local totalJoined = data.totalJoined or 0
	totalJoinedLabel.Text = tostring(totalJoined)

	task.spawn(function()
		while task.wait(1) do
			local elapsed = os.time() - serverStart
			local mins = math.floor(elapsed / 60)
			local secs = elapsed % 60
			uptimeLabel.Text = string.format("%02dm %02ds", mins, secs)
			playingLabel.Text = tostring(#Players:GetPlayers())
			playersLabel.Text = tostring(#Players:GetPlayers())
		end
	end)
end)

switchTab("Data")
setStatus("Press RightShift to open panel", false)
