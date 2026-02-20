-- AdminServer (ServerScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("AdminRemotes")
local adminRequest = remotesFolder:WaitForChild("AdminRequest")
local adminResponse = remotesFolder:WaitForChild("AdminResponse")

-- Replace with your real admin UserIds
local AdminList = {
	[12345678] = true,
	[87654321] = true,
}

local bannedUsers = {} -- session-only ban list
local serverStart = os.time()
local totalJoined = 0

local function isAdmin(player)
	return AdminList[player.UserId] == true
end

local function reply(player, requestId, ok, message, data)
	adminResponse:FireClient(player, {
		requestId = requestId,
		ok = ok,
		message = message,
		data = data
	})
end

local function findPlayerByName(name)
	if not name then return nil end
	name = name:lower()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Name:lower() == name or plr.DisplayName:lower() == name then
			return plr
		end
	end
	return nil
end

local function getLeaderstatValue(plr, statName)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then return nil end
	return ls:FindFirstChild(statName)
end

Players.PlayerAdded:Connect(function(plr)
	totalJoined += 1
	if bannedUsers[plr.UserId] then
		plr:Kick("You are banned from this server.")
	end
end)

adminRequest.OnServerEvent:Connect(function(sender, packet)
	if typeof(packet) ~= "table" then return end
	local requestId = packet.requestId
	local action = packet.action
	local payload = packet.payload or {}

	if not isAdmin(sender) then
		reply(sender, requestId, false, "Access denied.")
		return
	end

	if action == "Init" then
		reply(sender, requestId, true, "OK", {
			serverStart = serverStart,
			totalJoined = totalJoined
		})
		return
	end

	if action == "GetPlayerData" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end

		local coins = getLeaderstatValue(target, "Coins")
		local level = getLeaderstatValue(target, "Level")
		local role = isAdmin(target) and "Admin" or "Player"

		reply(sender, requestId, true, "Player loaded.", {
			username = target.Name,
			displayName = target.DisplayName,
			userId = target.UserId,
			role = role,
			joinDate = "In this server session",
			stats = {
				Coins = coins and coins.Value or 0,
				Level = level and level.Value or 0
			}
		})
		return
	end

	if action == "AdjustStat" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end

		local statName = tostring(payload.statName or "")
		local delta = tonumber(payload.delta)
		if not delta then
			reply(sender, requestId, false, "Invalid delta.")
			return
		end

		local statObj = getLeaderstatValue(target, statName)
		if not statObj or not statObj:IsA("IntValue") then
			reply(sender, requestId, false, "Stat not found or not IntValue.")
			return
		end

		statObj.Value += delta
		reply(sender, requestId, true, string.format("%s %s changed by %d", target.Name, statName, delta))
		return
	end

	if action == "KickPlayer" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		local reason = tostring(payload.reason or "Kicked by admin.")
		target:Kick(reason)
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
		target:Kick(tostring(payload.reason or "Banned by admin."))
		reply(sender, requestId, true, "Player banned (session).")
		return
	end

	if action == "HealPlayer" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not hum then
			reply(sender, requestId, false, "Humanoid not found.")
			return
		end
		hum.Health = hum.MaxHealth
		reply(sender, requestId, true, "Player healed.")
		return
	end

	if action == "SetMovement" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not hum then
			reply(sender, requestId, false, "Humanoid not found.")
			return
		end

		if payload.walkSpeed then
			local ws = tonumber(payload.walkSpeed)
			if ws then hum.WalkSpeed = math.clamp(ws, 0, 200) end
		end
		if payload.jumpPower then
			local jp = tonumber(payload.jumpPower)
			if jp then hum.JumpPower = math.clamp(jp, 0, 300) end
		end

		reply(sender, requestId, true, "Movement updated.")
		return
	end

	if action == "SetTimeOfDay" then
		local t = tostring(payload.timeString or "")
		if not string.match(t, "^%d%d:%d%d:%d%d$") then
			reply(sender, requestId, false, "Use HH:MM:SS format.")
			return
		end
		Lighting.TimeOfDay = t
		reply(sender, requestId, true, "Time of day changed.")
		return
	end

	if action == "ServerAnnouncement" then
		local msg = tostring(payload.message or "")
		if msg == "" then
			reply(sender, requestId, false, "Announcement empty.")
			return
		end

		-- system chat-style broadcast (basic)
		for _, plr in ipairs(Players:GetPlayers()) do
			adminResponse:FireClient(plr, {
				type = "Status",
				ok = true,
				message = "[ANNOUNCEMENT] " .. msg
			})
		end

		reply(sender, requestId, true, "Announcement sent.")
		return
	end

	if action == "GiveTool" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end

		local toolName = tostring(payload.toolName or "")
		if toolName == "" then
			reply(sender, requestId, false, "Tool name is empty.")
			return
		end

		local template = ServerStorage:FindFirstChild("AdminTools")
			and ServerStorage.AdminTools:FindFirstChild(toolName)

		if not template or not template:IsA("Tool") then
			reply(sender, requestId, false, "Tool not found in ServerStorage/AdminTools.")
			return
		end

		template:Clone().Parent = target:WaitForChild("Backpack")
		reply(sender, requestId, true, "Tool given.")
		return
	end

	if action == "RemoveTool" then
		local target = findPlayerByName(payload.targetName)
		if not target then
			reply(sender, requestId, false, "Player not found.")
			return
		end

		local toolName = tostring(payload.toolName or "")
		if toolName == "" then
			reply(sender, requestId, false, "Tool name is empty.")
			return
		end

		local removed = false
		local backpack = target:FindFirstChild("Backpack")
		if backpack then
			local t = backpack:FindFirstChild(toolName)
			if t and t:IsA("Tool") then
				t:Destroy()
				removed = true
			end
		end
		if target.Character then
			local equipped = target.Character:FindFirstChild(toolName)
			if equipped and equipped:IsA("Tool") then
				equipped:Destroy()
				removed = true
			end
		end

		if removed then
			reply(sender, requestId, true, "Tool removed.")
		else
			reply(sender, requestId, false, "Tool not found on player.")
		end
		return
	end

	reply(sender, requestId, false, "Unknown action.")
end)
