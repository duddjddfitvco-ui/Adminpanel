--[[
Place this Script in: ServerScriptService
Creates remotes, validates AdminList, and executes secure admin commands.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

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

local function getTarget(payload)
	local target = findPlayer(payload and payload.targetName)
	if not target then
		return nil, "Player not found."
	end
	return target
end

local function getCharacter(target)
	local character = target and target.Character
	if not character then
		return nil, "Character not loaded."
	end
	return character
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

local function normalizeBodyPartName(partName)
	if type(partName) ~= "string" then
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

local function getBodyPart(character, requestedPartName)
	local normalized = normalizeBodyPartName(requestedPartName)
	if not normalized then
		return nil, "Invalid part name."
	end

	if normalized == "Head" then
		local part = character:FindFirstChild("Head")
		if part and part:IsA("BasePart") then
			return part
		end
	end

	if normalized == "Torso" then
		local part = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("LowerTorso")
		if part and part:IsA("BasePart") then
			return part
		end
	end

	local function firstPart(names)
		for _, n in ipairs(names) do
			local p = character:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				return p
			end
		end
		return nil
	end

	if normalized == "Left Arm" then
		local p = firstPart({"Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"})
		if p then return p end
	end
	if normalized == "Right Arm" then
		local p = firstPart({"Right Arm", "RightUpperArm", "RightLowerArm", "RightHand"})
		if p then return p end
	end
	if normalized == "Left Leg" then
		local p = firstPart({"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"})
		if p then return p end
	end
	if normalized == "Right Leg" then
		local p = firstPart({"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"})
		if p then return p end
	end

	return nil, "Part not found on target character."
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
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end

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
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then reply(sender, requestId, false, "Humanoid not found.") return end
		humanoid.Health = humanoid.MaxHealth
		reply(sender, requestId, true, "Player healed.")
		return
	end

	if action == "KickPlayer" then
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		target:Kick(tostring(payload.reason or "Kicked by admin panel"))
		reply(sender, requestId, true, "Player kicked.")
		return
	end

	if action == "BanPlayer" then
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		local success, message = handleBan(sender, target, payload)
		reply(sender, requestId, success, message)
		return
	end

	if action == "TeleportPlayerToMe" then
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		local success, message = handleTeleportToAdmin(sender, target)
		reply(sender, requestId, success, message)
		return
	end

	if action == "RemoveBodyPart" then
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		local character, cErr = getCharacter(target)
		if not character then reply(sender, requestId, false, cErr) return end
		local part, pErr = getBodyPart(character, payload.partName)
		if not part then reply(sender, requestId, false, pErr) return end
		part:Destroy()
		reply(sender, requestId, true, "Removed part: " .. tostring(payload.partName))
		return
	end

	if action == "IgniteBodyPart" then
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		local character, cErr = getCharacter(target)
		if not character then reply(sender, requestId, false, cErr) return end
		local part, pErr = getBodyPart(character, payload.partName)
		if not part then reply(sender, requestId, false, pErr) return end
		local fire = part:FindFirstChildOfClass("Fire")
		if not fire then
			fire = Instance.new("Fire")
			fire.Heat = 8
			fire.Size = 6
			fire.Parent = part
		end
		reply(sender, requestId, true, "Ignited part: " .. tostring(payload.partName))
		return
	end

	if action == "SetFrozen" then
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		local character, cErr = getCharacter(target)
		if not character then reply(sender, requestId, false, cErr) return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then reply(sender, requestId, false, "HumanoidRootPart not found.") return end
		root.Anchored = payload.frozen == true
		reply(sender, requestId, true, root.Anchored and "Player frozen." or "Player thawed.")
		return
	end

	if action == "GiveForceField" then
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		local character, cErr = getCharacter(target)
		if not character then reply(sender, requestId, false, cErr) return end
		local ff = Instance.new("ForceField")
		ff.Visible = true
		ff.Parent = character
		Debris:AddItem(ff, math.clamp(tonumber(payload.duration) or 8, 1, 60))
		reply(sender, requestId, true, "ForceField granted.")
		return
	end

	if action == "SetMovement" then
		local target, err = getTarget(payload)
		if not target then reply(sender, requestId, false, err) return end
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then reply(sender, requestId, false, "Humanoid not found.") return end
		local changed = false
		local ws = tonumber(payload.walkSpeed)
		if ws then humanoid.WalkSpeed = math.clamp(ws, 0, 200); changed = true end
		local jp = tonumber(payload.jumpPower)
		if jp then humanoid.JumpPower = math.clamp(jp, 0, 300); changed = true end
		if not changed then reply(sender, requestId, false, "No valid movement values.") return end
		reply(sender, requestId, true, "Movement stats updated.")
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
