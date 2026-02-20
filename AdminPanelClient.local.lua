--[[
Place this LocalScript in: StarterPlayer > StarterPlayerScripts
Auto-generates a light frosted admin panel with mobile support + 3D character viewport.
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
local currentTargetUserId = nil
local selectedBodyPart = nil

local viewportState = {
	model = nil,
	camera = nil,
	yaw = 0,
	pitch = -8,
	distance = 7,
	targetY = 2.6,
	highlightPart = nil,
	baseColor = nil,
	rotating = false,
	rotateInput = nil,
	rotateStart = nil,
	yawStart = 0,
	pitchStart = 0,
}

local function addRound(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
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
	addRound(frame, radius or 6)
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
	label.TextScaled = false
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
	button.TextScaled = false
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Parent = parent
	addRound(button, 6)
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
	box.TextScaled = false
	box.BorderSizePixel = 0
	box.Parent = parent
	addRound(box, 6)
	return box
end

local function setStatus(text, isError)
	if not ui.StatusLabel then
		return
	end
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

local function mapPartNameForActions(partName)
	if not partName then
		return nil
	end
	if partName == "Head" then return "Head" end
	if partName == "Torso" or partName == "UpperTorso" or partName == "LowerTorso" then return "Torso" end
	if string.find(partName, "Left") and string.find(partName, "Arm") then return "Left Arm" end
	if string.find(partName, "Right") and string.find(partName, "Arm") then return "Right Arm" end
	if string.find(partName, "Left") and string.find(partName, "Leg") then return "Left Leg" end
	if string.find(partName, "Right") and string.find(partName, "Leg") then return "Right Leg" end
	if partName == "LeftHand" then return "Left Arm" end
	if partName == "RightHand" then return "Right Arm" end
	if partName == "LeftFoot" then return "Left Leg" end
	if partName == "RightFoot" then return "Right Leg" end
	return nil
end

local function clearViewportHighlight()
	if viewportState.highlightPart and viewportState.highlightPart.Parent and viewportState.baseColor then
		viewportState.highlightPart.Color = viewportState.baseColor
	end
	viewportState.highlightPart = nil
	viewportState.baseColor = nil
end

local function updateViewportCamera()
	if not viewportState.camera then
		return
	end
	local yaw = math.rad(viewportState.yaw)
	local pitch = math.rad(viewportState.pitch)
	local lookAt = Vector3.new(0, viewportState.targetY, 0)
	local x = math.cos(pitch) * math.sin(yaw)
	local y = math.sin(pitch)
	local z = math.cos(pitch) * math.cos(yaw)
	local camPos = lookAt + Vector3.new(x, y, z) * viewportState.distance
	viewportState.camera.CFrame = CFrame.lookAt(camPos, lookAt)
end

local function buildFallbackDummy()
	local model = Instance.new("Model")
	model.Name = "ViewportDummy"

	local function part(name, size, cframe)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Color = Color3.fromRGB(201, 210, 224)
		p.Material = Enum.Material.SmoothPlastic
		p.Size = size
		p.CFrame = cframe
		p.Parent = model
		return p
	end

	part("Head", Vector3.new(2, 1, 1), CFrame.new(0, 5, 0))
	part("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3.5, 0))
	part("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3.5, 0))
	part("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3.5, 0))
	part("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1.5, 0))
	part("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1.5, 0))

	return model
end

local function loadCharacterInViewport(targetPlayer)
	if not ui.WorldModel then
		return
	end

	clearViewportHighlight()
	selectedBodyPart = nil

	for _, child in ipairs(ui.WorldModel:GetChildren()) do
		child:Destroy()
	end

	local modelToUse = nil
	if targetPlayer and targetPlayer.Character then
		local char = targetPlayer.Character
		local oldArchivable = char.Archivable
		char.Archivable = true
		local ok, clone = pcall(function()
			return char:Clone()
		end)
		char.Archivable = oldArchivable
		if ok and clone then
			for _, desc in ipairs(clone:GetDescendants()) do
				if desc:IsA("Script") or desc:IsA("LocalScript") then
					desc:Destroy()
				elseif desc:IsA("BasePart") then
					desc.Anchored = true
					desc.CanCollide = false
				elseif desc:IsA("Humanoid") then
					desc.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end
			modelToUse = clone
		end
	end

	if not modelToUse then
		modelToUse = buildFallbackDummy()
	end

	modelToUse.Parent = ui.WorldModel
	viewportState.model = modelToUse
	viewportState.yaw = 0
	viewportState.pitch = -8
	viewportState.distance = 7
	updateViewportCamera()
end

local function trySelectPartFromViewport(screenPoint)
	if not ui.ViewportFrame or not viewportState.camera or not ui.WorldModel then
		return
	end

	local absPos = ui.ViewportFrame.AbsolutePosition
	local rel = screenPoint - absPos
	local ray = viewportState.camera:ViewportPointToRay(rel.X, rel.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ui.WorldModel }
	params.IgnoreWater = true

	local ok, result = pcall(function()
		return ui.WorldModel:Raycast(ray.Origin, ray.Direction * 500, params)
	end)

	if not ok or not result or not result.Instance or not result.Instance:IsA("BasePart") then
		return
	end

	local mapped = mapPartNameForActions(result.Instance.Name)
	if not mapped then
		return
	end

	clearViewportHighlight()
	viewportState.highlightPart = result.Instance
	viewportState.baseColor = result.Instance.Color
	result.Instance.Color = Colors.Blue
	selectedBodyPart = mapped
	setStatus("Selected part: " .. mapped, false)
end

local function fillPlayerData(data)
	ui.AccountName.Text = "Name: " .. tostring(data.displayName or data.username or "-")
	ui.AccountUserId.Text = "UserId: " .. tostring(data.userId or "-")
	ui.AccountRole.Text = "Role: " .. tostring(data.role or "Player")
	ui.DataCoins.Text = "Coins: " .. tostring((data.stats and data.stats.Coins) or 0)
	ui.DataLevel.Text = "Level: " .. tostring((data.stats and data.stats.Level) or 0)

	if data.userId then
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(data.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			end)
			if ok and ui.ProfileImage then
				ui.ProfileImage.Image = image
			end
		end)
	end
end

local function setupSmoothPanelDrag(dragHandle, panel)
	local dragging = false
	local dragInput
	local dragStart = Vector2.zero
	local panelStart = Vector2.zero
	local targetPos = panel.Position
	local lerpAlpha = 0.22

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragInput = input
			dragStart = input.Position
			panelStart = Vector2.new(panel.Position.X.Scale, panel.Position.Y.Scale)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - dragStart
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			local dx = delta.X / viewport.X
			local dy = delta.Y / viewport.Y
			targetPos = UDim2.fromScale(panelStart.X + dx, panelStart.Y + dy)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == dragInput then
			dragging = false
			dragInput = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local current = panel.Position
		local newX = current.X.Scale + (targetPos.X.Scale - current.X.Scale) * lerpAlpha
		local newY = current.Y.Scale + (targetPos.Y.Scale - current.Y.Scale) * lerpAlpha
		panel.Position = UDim2.fromScale(newX, newY)
	end)
end

local function setupViewportInteraction()
	local vp = ui.ViewportFrame
	if not vp then
		return
	end

	local rotating = false
	local rotateInput
	local rotateStart = Vector2.zero
	local startYaw = 0
	local startPitch = 0
	local moved = false

	vp.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			rotating = true
			rotateInput = input
			rotateStart = input.Position
			startYaw = viewportState.yaw
			startPitch = viewportState.pitch
			moved = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if rotating and input == rotateInput then
			local delta = input.Position - rotateStart
			if delta.Magnitude > 4 then
				moved = true
			end
			viewportState.yaw = startYaw - (delta.X * 0.35)
			viewportState.pitch = math.clamp(startPitch - (delta.Y * 0.2), -35, 35)
			updateViewportCamera()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if rotating and input == rotateInput then
			rotating = false
			if not moved then
				trySelectPartFromViewport(input.Position)
			end
			rotateInput = nil
		end
	end)
end

local function buildGui()
	local screen = Instance.new("ScreenGui")
	screen.Name = "AutoAdminPanel"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	ui.ToggleButton = makeButton(screen, "MobileToggle", "Admin", UDim2.fromScale(0.11, 0.05), UDim2.fromScale(0.015, 0.03), Colors.Blue, Colors.White)
	ui.ToggleButton.TextScaled = true

	local panel = makeFrame(screen, "MainPanel", UDim2.fromScale(0.82, 0.8), UDim2.fromScale(0.09, 0.1), Colors.Panel, 0.2, 6)
	addStroke(panel, Color3.fromRGB(200, 210, 225), 0.2)
	panel.Visible = false
	ui.MainPanel = panel

	local panelAspect = Instance.new("UIAspectRatioConstraint")
	panelAspect.AspectRatio = 1.75
	panelAspect.Parent = panel

	local panelSizeLimit = Instance.new("UISizeConstraint")
	panelSizeLimit.MinSize = Vector2.new(700, 420)
	panelSizeLimit.MaxSize = Vector2.new(1600, 980)
	panelSizeLimit.Parent = panel

	local topBar = makeFrame(panel, "TopBar", UDim2.fromScale(0.98, 0.1), UDim2.fromScale(0.01, 0.01), Colors.PanelAlt, 0.15, 6)
	addStroke(topBar, Color3.fromRGB(210, 220, 235), 0.3)

	local stat1 = makeLabel(topBar, "UptimeTitle", "Server up-time:", UDim2.fromScale(0.17, 1), UDim2.fromScale(0.015, 0), 14, Colors.Text, true)
	stat1.TextYAlignment = Enum.TextYAlignment.Center
	ui.UptimeValue = makeLabel(topBar, "UptimeValue", "0m", UDim2.fromScale(0.1, 1), UDim2.fromScale(0.19, 0), 14, Colors.Text, true)
	ui.UptimeValue.TextYAlignment = Enum.TextYAlignment.Center
	local stat2 = makeLabel(topBar, "PlayersTitle", "Players:", UDim2.fromScale(0.1, 1), UDim2.fromScale(0.42, 0), 14, Colors.Text, true)
	stat2.TextYAlignment = Enum.TextYAlignment.Center
	ui.PlayersValue = makeLabel(topBar, "PlayersValue", "0", UDim2.fromScale(0.08, 1), UDim2.fromScale(0.52, 0), 14, Colors.Text, true)
	ui.PlayersValue.TextYAlignment = Enum.TextYAlignment.Center

	local sidebar = makeFrame(panel, "Sidebar", UDim2.fromScale(0.21, 0.86), UDim2.fromScale(0.01, 0.125), Colors.PanelAlt, 0.1, 6)
	addStroke(sidebar, Color3.fromRGB(210, 220, 235), 0.3)
	local profile = makeFrame(sidebar, "Profile", UDim2.fromScale(0.96, 0.1), UDim2.fromScale(0.02, 0.01), Colors.PanelSoft, 0.15, 6)
	makeLabel(profile, "UserName", localPlayer.DisplayName, UDim2.fromScale(0.95, 0.44), UDim2.fromScale(0.03, 0.08), 15, Colors.Text, true)
	makeLabel(profile, "AtUser", "@" .. localPlayer.Name, UDim2.fromScale(0.95, 0.3), UDim2.fromScale(0.03, 0.56), 13, Colors.TextSoft, false)

	local navHolder = Instance.new("Frame")
	navHolder.Name = "NavHolder"
	navHolder.BackgroundTransparency = 1
	navHolder.Size = UDim2.fromScale(0.96, 0.86)
	navHolder.Position = UDim2.fromScale(0.02, 0.125)
	navHolder.Parent = sidebar

	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0.016, 0)
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.Parent = navHolder

	local content = makeFrame(panel, "Content", UDim2.fromScale(0.76, 0.86), UDim2.fromScale(0.23, 0.125), Colors.PanelAlt, 0.1, 6)
	addStroke(content, Color3.fromRGB(210, 220, 235), 0.3)
	ui.StatusLabel = makeLabel(panel, "StatusLabel", "Ready", UDim2.fromScale(0.98, 0.03), UDim2.fromScale(0.01, 0.965), 14, Colors.Text, true)

	local dataPage = Instance.new("Frame")
	dataPage.Name = "DataPage"
	dataPage.BackgroundTransparency = 1
	dataPage.Size = UDim2.fromScale(0.98, 0.98)
	dataPage.Position = UDim2.fromScale(0.01, 0.01)
	dataPage.Parent = content

	local characterPage = dataPage:Clone(); characterPage.Name = "CharacterPage"; characterPage.Parent = content; characterPage.Visible = false
	local worldPage = dataPage:Clone(); worldPage.Name = "WorldPage"; worldPage.Parent = content; worldPage.Visible = false
	local toolsPage = dataPage:Clone(); toolsPage.Name = "ToolsPage"; toolsPage.Parent = content; toolsPage.Visible = false

	ui.Pages = { Data = dataPage, Character = characterPage, World = worldPage, Tools = toolsPage }
	ui.NavButtons = {}
	for _, tabName in ipairs({ "Data", "Character", "World", "Tools" }) do
		local b = makeButton(navHolder, tabName .. "Btn", tabName, UDim2.fromScale(0.98, 0.1), UDim2.fromScale(0, 0), Colors.PanelSoft, Colors.Text)
		ui.NavButtons[tabName] = b
		b.MouseButton1Click:Connect(function() selectTab(tabName) end)
	end

	ui.SearchBox = makeTextBox(dataPage, "SearchBox", "Username...", UDim2.fromScale(0.98, 0.09), UDim2.fromScale(0.01, 0.01))
	local account = makeFrame(dataPage, "AccountSection", UDim2.fromScale(0.98, 0.34), UDim2.fromScale(0.01, 0.12), Colors.PanelSoft, 0.15, 6)
	makeLabel(account, "AccountTitle", "Account info", UDim2.fromScale(0.8, 0.2), UDim2.fromScale(0.02, 0.05), 18, Colors.Text, true)

	ui.ProfileImage = Instance.new("ImageLabel")
	ui.ProfileImage.Name = "ProfileImage"
	ui.ProfileImage.Size = UDim2.fromScale(0.14, 0.44)
	ui.ProfileImage.Position = UDim2.fromScale(0.84, 0.05)
	ui.ProfileImage.BackgroundColor3 = Colors.Panel
	ui.ProfileImage.BackgroundTransparency = 0.1
	ui.ProfileImage.BorderSizePixel = 0
	ui.ProfileImage.Parent = account
	addRound(ui.ProfileImage, 6)

	ui.AccountName = makeLabel(account, "AccountName", "Name: -", UDim2.fromScale(0.8, 0.17), UDim2.fromScale(0.02, 0.32), 14, Colors.TextSoft, false)
	ui.AccountUserId = makeLabel(account, "AccountUserId", "UserId: -", UDim2.fromScale(0.8, 0.17), UDim2.fromScale(0.02, 0.54), 14, Colors.TextSoft, false)
	ui.AccountRole = makeLabel(account, "AccountRole", "Role: -", UDim2.fromScale(0.8, 0.17), UDim2.fromScale(0.02, 0.76), 14, Colors.TextSoft, false)

	local dataSection = makeFrame(dataPage, "DataSection", UDim2.fromScale(0.98, 0.24), UDim2.fromScale(0.01, 0.48), Colors.PanelSoft, 0.15, 6)
	makeLabel(dataSection, "DataTitle", "Data", UDim2.fromScale(0.5, 0.24), UDim2.fromScale(0.02, 0.05), 18, Colors.Text, true)
	ui.DataCoins = makeLabel(dataSection, "Coins", "Coins: -", UDim2.fromScale(0.47, 0.24), UDim2.fromScale(0.02, 0.44), 14, Colors.TextSoft, false)
	ui.DataLevel = makeLabel(dataSection, "Level", "Level: -", UDim2.fromScale(0.47, 0.24), UDim2.fromScale(0.5, 0.44), 14, Colors.TextSoft, false)

	local viewportWrap = makeFrame(characterPage, "ViewportWrap", UDim2.fromScale(0.45, 0.7), UDim2.fromScale(0.01, 0.02), Colors.PanelSoft, 0.1, 6)
	makeLabel(viewportWrap, "ViewportTitle", "3D Body Selector", UDim2.fromScale(0.96, 0.1), UDim2.fromScale(0.02, 0.01), 14, Colors.Text, true)

	ui.ViewportFrame = Instance.new("ViewportFrame")
	ui.ViewportFrame.Name = "CharacterViewport"
	ui.ViewportFrame.Size = UDim2.fromScale(0.96, 0.87)
	ui.ViewportFrame.Position = UDim2.fromScale(0.02, 0.11)
	ui.ViewportFrame.BackgroundColor3 = Colors.Panel
	ui.ViewportFrame.BackgroundTransparency = 0.15
	ui.ViewportFrame.BorderSizePixel = 0
	ui.ViewportFrame.LightDirection = Vector3.new(-1, -2, -1)
	ui.ViewportFrame.Ambient = Color3.fromRGB(180, 185, 200)
	ui.ViewportFrame.Parent = viewportWrap
	addRound(ui.ViewportFrame, 6)

	ui.WorldModel = Instance.new("WorldModel")
	ui.WorldModel.Parent = ui.ViewportFrame
	local cam = Instance.new("Camera")
	cam.Parent = ui.ViewportFrame
	ui.ViewportFrame.CurrentCamera = cam
	viewportState.camera = cam

	local actionPane = makeFrame(characterPage, "ActionPane", UDim2.fromScale(0.53, 0.7), UDim2.fromScale(0.46, 0.02), Colors.PanelSoft, 0.1, 6)
	ui.RemovePartButton = makeButton(actionPane, "RemovePartButton", "Remove Part", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.02, 0.02), Colors.Blue, Colors.White)
	ui.IgnitePartButton = makeButton(actionPane, "IgnitePartButton", "Ignite Part", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.5, 0.02), Colors.Blue, Colors.White)
	ui.FreezeButton = makeButton(actionPane, "FreezeButton", "Freeze", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.02, 0.15), Colors.Blue, Colors.White)
	ui.ThawButton = makeButton(actionPane, "ThawButton", "Thaw", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.5, 0.15), Colors.Blue, Colors.White)
	ui.ForceFieldButton = makeButton(actionPane, "ForceFieldButton", "ForceField", UDim2.fromScale(0.96, 0.1), UDim2.fromScale(0.02, 0.28), Colors.Blue, Colors.White)
	ui.WalkSpeedBox = makeTextBox(actionPane, "WalkSpeedBox", "WalkSpeed", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.02, 0.41))
	ui.JumpPowerBox = makeTextBox(actionPane, "JumpPowerBox", "JumpPower", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.5, 0.41))
	ui.ApplyStatsButton = makeButton(actionPane, "ApplyStatsButton", "Apply Stats", UDim2.fromScale(0.96, 0.1), UDim2.fromScale(0.02, 0.54), Colors.Blue, Colors.White)
	ui.KickButton = makeButton(actionPane, "KickButton", "Kick", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.02, 0.67), Colors.Blue, Colors.White)
	ui.BanButton = makeButton(actionPane, "BanButton", "Ban", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.5, 0.67), Colors.Blue, Colors.White)
	ui.HealButton = makeButton(actionPane, "HealButton", "Heal", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.02, 0.8), Colors.Blue, Colors.White)
	ui.TeleportButton = makeButton(actionPane, "TeleportButton", "Bring", UDim2.fromScale(0.48, 0.1), UDim2.fromScale(0.5, 0.8), Colors.Blue, Colors.White)

	ui.TimeBox = makeTextBox(worldPage, "TimeBox", "HH:MM:SS", UDim2.fromScale(0.27, 0.09), UDim2.fromScale(0.01, 0.02))
	ui.TimeBox.Text = "14:00:00"
	ui.SetTimeButton = makeButton(worldPage, "SetTimeButton", "Set Time", UDim2.fromScale(0.2, 0.09), UDim2.fromScale(0.29, 0.02), Colors.Blue, Colors.White)
	makeLabel(toolsPage, "ToolsLabel", "Tools tab ready for your custom actions.", UDim2.fromScale(0.98, 0.08), UDim2.fromScale(0.01, 0.02), 14, Colors.TextSoft, false)

	setupSmoothPanelDrag(topBar, panel)
	setupViewportInteraction()
	loadCharacterInViewport(nil)
	selectTab("Data")

	return panel
end

local function requireTarget()
	if not currentTargetName then
		setStatus("Search a player first", true)
		return false
	end
	return true
end

local function wireActions(mainPanel)
	ui.SearchBox.FocusLost:Connect(function(enterPressed)
		if not enterPressed then return end
		local target = ui.SearchBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if target == "" then setStatus("Player not found", true) return end

		sendRequest("GetPlayerData", { targetName = target }, function(packet)
			if not packet.ok then setStatus(packet.message or "Player not found", true) return end
			currentTargetName = packet.data and packet.data.username
			currentTargetUserId = packet.data and packet.data.userId
			selectedBodyPart = nil
			clearViewportHighlight()
			fillPlayerData(packet.data or {})

			local targetPlayer = Players:FindFirstChild(currentTargetName)
			loadCharacterInViewport(targetPlayer)
			setStatus("Loaded " .. tostring(currentTargetName), false)
		end)
	end)

	ui.RemovePartButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		if not selectedBodyPart then setStatus("Select a body part in the 3D viewport", true) return end
		sendRequest("RemoveBodyPart", { targetName = currentTargetName, partName = selectedBodyPart }, function(packet)
			setStatus(packet.message or "Remove part complete", not packet.ok)
		end)
	end)

	ui.IgnitePartButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		if not selectedBodyPart then setStatus("Select a body part in the 3D viewport", true) return end
		sendRequest("IgniteBodyPart", { targetName = currentTargetName, partName = selectedBodyPart }, function(packet)
			setStatus(packet.message or "Ignite complete", not packet.ok)
		end)
	end)

	ui.FreezeButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		sendRequest("SetFrozen", { targetName = currentTargetName, frozen = true }, function(packet)
			setStatus(packet.message or "Freeze complete", not packet.ok)
		end)
	end)

	ui.ThawButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		sendRequest("SetFrozen", { targetName = currentTargetName, frozen = false }, function(packet)
			setStatus(packet.message or "Thaw complete", not packet.ok)
		end)
	end)

	ui.ForceFieldButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		sendRequest("GiveForceField", { targetName = currentTargetName, duration = 8 }, function(packet)
			setStatus(packet.message or "ForceField applied", not packet.ok)
		end)
	end)

	ui.ApplyStatsButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		local ws = tonumber(ui.WalkSpeedBox.Text)
		local jp = tonumber(ui.JumpPowerBox.Text)
		if not ws and not jp then setStatus("Enter WalkSpeed and/or JumpPower", true) return end
		sendRequest("SetMovement", { targetName = currentTargetName, walkSpeed = ws, jumpPower = jp }, function(packet)
			setStatus(packet.message or "Stats updated", not packet.ok)
		end)
	end)

	ui.KickButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		sendRequest("KickPlayer", { targetName = currentTargetName }, function(packet)
			setStatus(packet.message or "Kick done", not packet.ok)
		end)
	end)

	ui.BanButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		sendRequest("BanPlayer", { targetName = currentTargetName, reason = "Banned by admin panel", duration = 3600 }, function(packet)
			setStatus(packet.message or "Ban done", not packet.ok)
		end)
	end)

	ui.HealButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
		sendRequest("HealPlayer", { targetName = currentTargetName }, function(packet)
			setStatus(packet.message or "Heal done", not packet.ok)
		end)
	end)

	ui.TeleportButton.MouseButton1Click:Connect(function()
		if not requireTarget() then return end
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
	local function togglePanel()
		opened = not opened
		mainPanel.Visible = opened
	end

	ui.ToggleButton.MouseButton1Click:Connect(togglePanel)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			togglePanel()
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
	setStatus("Press RightShift or tap Admin button", false)

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
