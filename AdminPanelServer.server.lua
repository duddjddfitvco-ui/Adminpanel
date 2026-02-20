--[[
Place this Script in: ServerScriptService
It creates remotes, validates admin access, and performs secure admin actions.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local serverStart = os.time()
local bannedUsers = {}

-- Replace these with your real UserIds
local AdminList = {
	[12345678] = true,
	[87654321] = true,
}

local function isAdmin(player)
	return AdminList[player.UserId] == true
end

local remotesFolder = ReplicatedStorage:FindFirstChild("AdminRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "AdminRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local requestRemote = remotesFolder:FindFirstChild("AdminRequest")
if not requestRemote then
	requestRemote = Instance.new("RemoteEvent")
	requestRemote.Name = "AdminRequest"
	requestRemote.Parent = remotesFolder
end

local responseRemote = remotesFolder:FindFirstChild("AdminResponse")
if not responseRemote then
	responseRemote = Instance.new("RemoteEvent")
	responseRemote.Name = "AdminResponse"
	responseRemote.Parent = remotesFolder
end

local function reply(player, requestId, ok, message, data)
	responseRemote:FireClient(player, {
		requestId = requestId,
		ok = ok,
		message = message,
		data = data,
	})
end

local function findPlayerByName(name)
	if type(name) ~= "string" then
		return nil
	end
	local wanted = string.lower(name)
	for _, plr in ipairs(Players:GetPlayers()) do
		if string.lower(plr.Name) == wanted or string.lower(plr.DisplayName) == wanted then
			return plr
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

Players.PlayerAdded:Connect(function(player)
	if bannedUsers[player.UserId] then
		player:Kick("You are banned from this server.")
	end
end)

requestRemote.OnServerEvent:Connect(function(sender, packet)
	if typeof(packet) ~= "table" then
		return
	end

	local requestId = packet.requestId
	local action = packet.action
	local payload = packet.payload or {}

	if action == "Init" then
		if not isAdmin(sender) then
			reply(sender, requestId, false, "Access denied. You are not in AdminList.")
			return
		end
		reply(sender, requestId, true, "Authorized", {
			serverStart = serverStart,
		})
		return
	end

	if not isAdmin(sender) then
		reply(sender, requestId, false, "Access denied.")
		return
	end

	if action == "GetPlayerData" then
		local target = findPlayerByName(payload.targetName)
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
			stats = {
				Coins = coins and coins.Value or 0,
				Level = level and level.Value or 0,
			},
		})
		return
	end

	if action == "KickPlayer" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		target:Kick("Kicked by admin.")
		reply(sender, requestId, true, "Player kicked.")
		return
	end

	if action == "BanPlayer" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		bannedUsers[target.UserId] = true
		target:Kick("Banned by admin.")
		reply(sender, requestId, true, "Player banned for this server session.")
		return
	end

	if action == "HealPlayer" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		local character = target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			reply(sender, requestId, false, "Target humanoid not found.")
			return
		end
		humanoid.Health = humanoid.MaxHealth
		reply(sender, requestId, true, "Player healed.")
		return
	end

	if action == "SetTimeOfDay" then
		local timeString = tostring(payload.timeString or "")
		if not string.match(timeString, "^%d%d:%d%d:%d%d$") then
			reply(sender, requestId, false, "Invalid time. Use HH:MM:SS")
			return
		end
		Lighting.TimeOfDay = timeString
		reply(sender, requestId, true, "Time of day changed to " .. timeString)
		return
	end

	reply(sender, requestId, false, "Unknown action: " .. tostring(action))
end)
