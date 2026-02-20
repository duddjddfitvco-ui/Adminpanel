--[[
Place this Script in: ServerScriptService
Creates remotes, validates AdminList, and executes secure admin commands.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local serverStart = os.time()

-- Replace with your real admin UserIds
local AdminList = {
	[12345678] = true,
	[87654321] = true,
}

local function isAdmin(player)
	return player and AdminList[player.UserId] == true
end

local remotesFolder = ReplicatedStorage:FindFirstChild("AdminRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "AdminRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local adminRequest = remotesFolder:FindFirstChild("AdminRequest")
if not adminRequest then
	adminRequest = Instance.new("RemoteEvent")
	adminRequest.Name = "AdminRequest"
	adminRequest.Parent = remotesFolder
end

local adminResponse = remotesFolder:FindFirstChild("AdminResponse")
if not adminResponse then
	adminResponse = Instance.new("RemoteEvent")
	adminResponse.Name = "AdminResponse"
	adminResponse.Parent = remotesFolder
end

local function reply(player, requestId, ok, message, data)
	adminResponse:FireClient(player, {
		requestId = requestId,
		ok = ok,
		message = message,
		data = data,
	})
end

local function findPlayer(name)
	if type(name) ~= "string" then
		return nil
	end
	local lower = string.lower(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
			return p
		end
	end
	return nil
end

local function getIntStat(player, statName)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end
	local stat = leaderstats:FindFirstChild(statName)
	if stat and stat:IsA("IntValue") then
		return stat
	end
	return nil
end

local function handleBan(requester, targetPlayer, payload)
	local duration = tonumber(payload.duration) or -1
	local reason = tostring(payload.reason or "Banned by admin panel")

	local ok, err = pcall(function()
		Players:BanAsync({
			UserIds = { targetPlayer.UserId },
			ApplyToUniverse = true,
			Duration = duration,
			DisplayReason = reason,
			PrivateReason = string.format("Banned by %s (%d)", requester.Name, requester.UserId),
			ExcludeAltAccounts = false,
		})
	end)

	if not ok then
		return false, "BanAsync failed: " .. tostring(err)
	end

	targetPlayer:Kick(reason)
	return true, "Player banned with BanAsync."
end

local function handleTeleportToAdmin(adminPlayer, targetPlayer)
	local adminCharacter = adminPlayer.Character
	local targetCharacter = targetPlayer.Character
	if not adminCharacter or not targetCharacter then
		return false, "Character not loaded."
	end

	local adminRoot = adminCharacter:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not adminRoot or not targetRoot then
		return false, "HumanoidRootPart not found."
	end

	targetRoot.CFrame = adminRoot.CFrame * CFrame.new(0, 0, -4)
	return true, "Player teleported to admin."
end

adminRequest.OnServerEvent:Connect(function(sender, packet)
	if typeof(packet) ~= "table" then
		return
	end

	local requestId = packet.requestId
	local action = packet.action
	local payload = packet.payload or {}

	if action == "Init" then
		if not isAdmin(sender) then
			reply(sender, requestId, false, "Access denied.")
			return
		end
		reply(sender, requestId, true, "Authorized", { serverStart = serverStart })
		return
	end

	if not isAdmin(sender) then
		reply(sender, requestId, false, "Access denied.")
		return
	end

	if action == "GetPlayerData" then
		local target = findPlayer(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end

		local coins = getIntStat(target, "Coins")
		local level = getIntStat(target, "Level")
		reply(sender, requestId, true, "Player data loaded.", {
			username = target.Name,
			displayName = target.DisplayName,
			userId = target.UserId,
			role = isAdmin(target) and "Admin" or "Player",
			stats = {
				Coins = coins and coins.Value or 0,
				Level = level and level.Value or 0,
			},
		})
		return
	end

	if action == "HealPlayer" then
		local target = findPlayer(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			reply(sender, requestId, false, "Humanoid not found.")
			return
		end
		humanoid.Health = humanoid.MaxHealth
		reply(sender, requestId, true, "Player healed.")
		return
	end

	if action == "KickPlayer" then
		local target = findPlayer(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		target:Kick(tostring(payload.reason or "Kicked by admin panel"))
		reply(sender, requestId, true, "Player kicked.")
		return
	end

	if action == "BanPlayer" then
		local target = findPlayer(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end

		local success, message = handleBan(sender, target, payload)
		reply(sender, requestId, success, message)
		return
	end

	if action == "TeleportPlayerToMe" then
		local target = findPlayer(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		local success, message = handleTeleportToAdmin(sender, target)
		reply(sender, requestId, success, message)
		return
	end

	if action == "SetTimeOfDay" then
		local timeString = tostring(payload.timeString or "")
		if not string.match(timeString, "^%d%d:%d%d:%d%d$") then
			reply(sender, requestId, false, "Invalid time, use HH:MM:SS")
			return
		end
		Lighting.TimeOfDay = timeString
		reply(sender, requestId, true, "Time changed to " .. timeString)
		return
	end

	reply(sender, requestId, false, "Unknown action.")
end)
