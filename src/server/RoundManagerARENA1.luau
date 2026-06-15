-- RoundManagerArena1

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ARENA_NAME = "ARENA1"

local GameAreas = workspace:WaitForChild("GameAreas")
local arena = GameAreas:WaitForChild("ARENA1")

local QueueArea = arena:WaitForChild("QueueArea")
local StageArea = arena:WaitForChild("StageArea")

local ChairsFolder = StageArea:WaitForChild("Chairs")
local QueueZone = QueueArea:WaitForChild("QueueZone")
local StageSpawn = StageArea:WaitForChild("StageSpawn")

local LobbySpawn =
	GameAreas:FindFirstChild("LobbySpawn")
	or GameAreas:FindFirstChild("lobby")
	or workspace:FindFirstChild("SpawnLocation")

local GameStatus = ReplicatedStorage:WaitForChild("GameStatus")
local TimerUpdate = ReplicatedStorage:WaitForChild("TimerUpdate")
local Events = ReplicatedStorage:WaitForChild("Events")

local SubmitVote = Events:WaitForChild("SubmitVote")
local WinnerPass = Events:WaitForChild("WinnerPass")
local RewardPopup = Events:WaitForChild("RewardPopup")
local LeaveMatch = Events:WaitForChild("LeaveMatch")
local FinishPerformance = Events:WaitForChild("FinishPerformance")

local GROUP_SIZE = 8
local START_DELAY = 10
local PERFORMANCE_TIME = 60
local VOTE_TIME = 15
local RETURN_TIME = 10

local STAGE_POS = StageSpawn.Position
local LOBBY_POS = LobbySpawn.Position

local activePlayers = {}
local playerGroups = {}
local eliminatedPlayers = {}
local leftMatchPlayers = {}
local rewardedPlayers = {}
local votes = {}
local currentPerformer = {}
local finishRequested = {}

local placementRewards = {
	[1] = {coins = 200, xp = 300, text = "?? Winner!"},
	[2] = {coins = 120, xp = 220, text = "?? Finalist!"},
	[3] = {coins = 80, xp = 160, text = "?? Third place!"},
	[4] = {coins = 60, xp = 120, text = "4th place!"},
	[5] = {coins = 35, xp = 80, text = "? Eliminated"},
	[6] = {coins = 30, xp = 70, text = "? Eliminated"},
	[7] = {coins = 25, xp = 60, text = "? Eliminated"},
	[8] = {coins = 20, xp = 50, text = "? Eliminated"},
}

local function fireGroup(group, remote, ...)
	for _, player in ipairs(group) do
		if player and player.Parent == Players and not leftMatchPlayers[player] then
			remote:FireClient(player, ...)
		end
	end
end

local function getSeats()
	local seats = {}

	for _, obj in ipairs(ChairsFolder:GetDescendants()) do
		if obj:IsA("Seat") then
			table.insert(seats, obj)
		end
	end

	table.sort(seats, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	return seats
end

local function setInvisible(player, invisible)
	local char = player.Character
	if not char then return end

	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") then
			if obj.Name ~= "HumanoidRootPart" then
				obj.Transparency = invisible and 1 or 0
			end
			obj.CanCollide = false
		elseif obj:IsA("Decal") then
			obj.Transparency = invisible and 1 or 0
		end
	end
end

local function hardReset(player)
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChild("Humanoid")

	if hrp then
		hrp.Anchored = false
	end

	if hum then
		hum.Sit = false
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end

	setInvisible(player, false)
end

local function teleportToLobby(player)
	hardReset(player)
	task.wait(0.1)

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	if hrp then
		hrp.CFrame = CFrame.new(LOBBY_POS)
	end
end

local function hideEliminated(player)
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChild("Humanoid")

	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end

	if hrp then
		hrp.Anchored = true
	end

	setInvisible(player, true)
end

local function teleportToStage(player)
	hardReset(player)
	task.wait(0.15)

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")

	if hrp then
		hrp.CFrame = CFrame.lookAt(STAGE_POS, STAGE_POS + Vector3.new(0, 0, 100))
		task.wait(0.15)
		hrp.Anchored = true
	end

	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end
end

local function teleportToSeat(player, seat)
		hardReset(player)
		task.wait(0.05)

		local char = player.Character
		local hum = char and char:FindFirstChild("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")

		if not hum or not hrp or not seat then
			return false
		end

		if seat.Occupant then
			return false
		end

		hrp.Anchored = false
		hum.Sit = false
		hum.PlatformStand = false
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.Jump = false

		for i = 1, 3 do
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, 0)

			task.wait(0.12)

			seat:Sit(hum)

			task.wait(0.25)

			if hum.SeatPart == seat then
				hum.WalkSpeed = 0
				hum.JumpPower = 0
				hum.Jump = false
				return true
			end
		end

		-- final backup: freeze directly above chair instead of floating away
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
		hrp.Anchored = true
		hum.WalkSpeed = 0
		hum.JumpPower = 0

		return true
	end

	local function teleportToAudienceFallback(player, index)
		hardReset(player)
		task.wait(0.05)

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChild("Humanoid")

		if hrp then
			local pos = STAGE_POS + Vector3.new(-20 + (index * 5), 0, 15)
			hrp.CFrame = CFrame.lookAt(pos, STAGE_POS)
			task.wait(0.05)
			hrp.Anchored = true
		end

		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
	end

	local function isPlayerInQueueZone(player)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end

		local relative = QueueZone.CFrame:PointToObjectSpace(hrp.Position)
		local half = QueueZone.Size / 2

		return math.abs(relative.X) <= half.X
			and math.abs(relative.Y) <= half.Y
			and math.abs(relative.Z) <= half.Z
	end

	local function cleanGroup(group)
		local cleaned = {}

		for _, player in ipairs(group) do
			if player and player.Parent == Players then
				table.insert(cleaned, player)
			end
		end

		return cleaned
	end

	local function getWaitingPlayers()
		local waiting = {}

		for _, player in ipairs(Players:GetPlayers()) do
			if not activePlayers[player] and isPlayerInQueueZone(player) then
				table.insert(waiting, player)
			end
		end

		return waiting
	end

	local function makeGroup()
		local waiting = getWaitingPlayers()
		if #waiting < GROUP_SIZE then return nil end

		local group = {}

		for i = 1, GROUP_SIZE do
			table.insert(group, waiting[i])
			activePlayers[waiting[i]] = true
		end

		return group
	end

	local function awardSinglePlayer(player, place)
		if not player or player.Parent ~= Players then return end
		if rewardedPlayers[player] then return end

		local reward = placementRewards[place]
		if not reward then return end

		rewardedPlayers[player] = true

		if _G.awardCoins then
			_G.awardCoins(player, reward.coins)
		end

		if _G.awardXP then
			_G.awardXP(player, reward.xp)
		end

		RewardPopup:FireClient(player, reward)
	end

	local function eliminatePlayers(originalGroup, advancing, scores, startingPlace)
		local advancingSet = {}

		for _, player in ipairs(advancing) do
			advancingSet[player] = true
			eliminatedPlayers[player] = nil
		end

		local eliminated = {}

		for _, player in ipairs(originalGroup) do
			if player and player.Parent == Players and not advancingSet[player] then
				table.insert(eliminated, player)
			end
		end

		table.sort(eliminated, function(a, b)
			return (scores[a.Name] or 0) > (scores[b.Name] or 0)
		end)

		for index, player in ipairs(eliminated) do
			eliminatedPlayers[player] = true
			awardSinglePlayer(player, startingPlace + index - 1)

			if not leftMatchPlayers[player] then
				hideEliminated(player)
				GameStatus:FireClient(player, "? Eliminated! You can still vote or return to lobby.", 0, GROUP_SIZE)
				TimerUpdate:FireClient(player, 0, false)
			end
		end
	end

	SubmitVote.OnServerEvent:Connect(function(player, rating)
		local groupId = playerGroups[player]
		if not groupId then return end
		if leftMatchPlayers[player] then return end

		local voteData = votes[groupId]
		if not voteData then return end
		if not voteData.open then return end
		if voteData.performer == player then return end
		if voteData.votes[player.UserId] ~= nil then return end

		voteData.votes[player.UserId] = math.clamp(tonumber(rating) or 1, 1, 10)
	end)

	WinnerPass.OnServerEvent:Connect(function(player)
	end)

	FinishPerformance.OnServerEvent:Connect(function(player)
		local groupId = playerGroups[player]

		if groupId and currentPerformer[groupId] == player then
			finishRequested[groupId] = true
		end
	end)

	LeaveMatch.OnServerEvent:Connect(function(player)
		if activePlayers[player] then
			leftMatchPlayers[player] = true
			eliminatedPlayers[player] = true

			teleportToLobby(player)

			GameStatus:FireClient(player, "Returned to lobby.", 0, GROUP_SIZE)
			TimerUpdate:FireClient(player, 0, false)
		end
	end)

	local function openVoting(groupId, fullGroup, performer)
		votes[groupId] = {
			open = true,
			performer = performer,
			votes = {}
		}

		local StartVoting = Events:FindFirstChild("StartVoting")
		if StartVoting then
			fireGroup(fullGroup, StartVoting, {
				performer = performer.Name
			})
		end
	end

	local function closeVoting(groupId)
		local voteData = votes[groupId]
		if not voteData then return 0 end

		voteData.open = false

		local total = 0
		local count = 0

		for _, score in pairs(voteData.votes) do
			total += score
			count += 1
		end

		return count > 0 and math.floor(total / count) or 0
	end

	local function runCountdown(group, seconds, groupId, allowFinish)
		for t = seconds, 1, -1 do
			if allowFinish and finishRequested[groupId] then
				break
			end

			fireGroup(group, TimerUpdate, t, true)
			task.wait(1)
		end

		fireGroup(group, TimerUpdate, 0, false)
	end

	local function prepareActivePlayers(activeRoundPlayers)
		for _, player in ipairs(activeRoundPlayers) do
			if player and player.Parent == Players then
				eliminatedPlayers[player] = nil
				leftMatchPlayers[player] = nil
				hardReset(player)
			end
		end
	end

	local function keepEliminatedHidden(fullGroup, activeRoundPlayers)
		local activeSet = {}

		for _, player in ipairs(activeRoundPlayers) do
			activeSet[player] = true
		end

		for _, player in ipairs(fullGroup) do
			if player
				and player.Parent == Players
				and eliminatedPlayers[player]
				and not leftMatchPlayers[player]
				and not activeSet[player]
			then
				hideEliminated(player)
			end
		end
	end

	local function runFullRound(groupId, fullGroup, activeRoundPlayers)
		local scores = {}

		activeRoundPlayers = cleanGroup(activeRoundPlayers)
		prepareActivePlayers(activeRoundPlayers)

		for _, player in ipairs(activeRoundPlayers) do
			scores[player.Name] = 0
		end

		for _, performer in ipairs(activeRoundPlayers) do
			activeRoundPlayers = cleanGroup(activeRoundPlayers)
			prepareActivePlayers(activeRoundPlayers)

			if #activeRoundPlayers < 2 then break end
			if not performer or performer.Parent ~= Players then continue end

			keepEliminatedHidden(fullGroup, activeRoundPlayers)

			currentPerformer[groupId] = performer
			finishRequested[groupId] = false

			fireGroup(fullGroup, GameStatus, "?? " .. performer.Name .. " is on stage!", #activeRoundPlayers, GROUP_SIZE)

			teleportToStage(performer)

			local seats = getSeats()
			local seatIndex = 1

			for _, player in ipairs(activeRoundPlayers) do
				if player ~= performer then
					local seated = false

					while seats[seatIndex] and not seated do
						seated = teleportToSeat(player, seats[seatIndex])
						seatIndex += 1
					end

					if not seated then
						teleportToAudienceFallback(player, seatIndex)
					end
				end
			end

			runCountdown(fullGroup, PERFORMANCE_TIME, groupId, true)

			currentPerformer[groupId] = nil
			finishRequested[groupId] = false

			fireGroup(fullGroup, GameStatus, "??? Vote for " .. performer.Name .. "!", #activeRoundPlayers, GROUP_SIZE)

			openVoting(groupId, fullGroup, performer)
			runCountdown(fullGroup, VOTE_TIME, groupId, false)

			local avgScore = closeVoting(groupId)
			scores[performer.Name] = avgScore

			fireGroup(fullGroup, GameStatus, performer.Name .. " got " .. avgScore .. "/10 cringe! ??", #activeRoundPlayers, GROUP_SIZE)

			local RoundResult = Events:FindFirstChild("RoundResult")
			if RoundResult then
				fireGroup(fullGroup, RoundResult, {
					performer = performer.Name,
					score = avgScore,
					scores = scores
				})
			end

			task.wait(1)
		end

		return scores
	end

	local function getTopPlayers(playerList, scores, count)
		local sorted = {}

		for _, player in ipairs(playerList) do
			table.insert(sorted, {
				player = player,
				score = scores[player.Name] or 0
			})
		end

		table.sort(sorted, function(a, b)
			return a.score > b.score
		end)

		local top = {}

		for i = 1, math.min(count, #sorted) do
			table.insert(top, sorted[i].player)
		end

		return top
	end

	local function showAdvancing(fullGroup, advancing)
		for _, player in ipairs(advancing) do
			eliminatedPlayers[player] = nil
			leftMatchPlayers[player] = nil
			hardReset(player)
		end

		local names = {}

		for _, player in ipairs(advancing) do
			table.insert(names, player.Name)
		end

		fireGroup(fullGroup, GameStatus, "? Advancing: " .. table.concat(names, ", "), #advancing, GROUP_SIZE)
		task.wait(5)
	end

	local function addUnique(list, player)
		if not player then return end

		for _, existing in ipairs(list) do
			if existing == player then return end
		end

		table.insert(list, player)
	end

	local function runTournament(groupId, group)
		for _, player in ipairs(group) do
			activePlayers[player] = true
			playerGroups[player] = groupId
			eliminatedPlayers[player] = nil
			leftMatchPlayers[player] = nil
			rewardedPlayers[player] = nil
			hardReset(player)
		end

		fireGroup(group, GameStatus, "?? Tournament starting!", #group, GROUP_SIZE)
		task.wait(3)

		local scores8 = runFullRound(groupId, group, group)
		local top4 = getTopPlayers(cleanGroup(group), scores8, 4)
		if #top4 < 2 then return end

		showAdvancing(group, top4)
		eliminatePlayers(group, top4, scores8, 5)
		task.wait(2)

		prepareActivePlayers(top4)

		fireGroup(group, GameStatus, "? TOP 4!", #top4, GROUP_SIZE)
		task.wait(2)

		local scores4 = runFullRound(groupId, group, top4)
		local top2 = getTopPlayers(cleanGroup(top4), scores4, 2)
		if #top2 < 1 then return end

		showAdvancing(group, top2)
		eliminatePlayers(top4, top2, scores4, 3)
		task.wait(2)

		prepareActivePlayers(top2)

		fireGroup(group, GameStatus, "?? FINALS!", #top2, GROUP_SIZE)
		task.wait(2)

		local scoresFinal = runFullRound(groupId, group, top2)
		local winner = getTopPlayers(cleanGroup(top2), scoresFinal, 1)

		local placements = {}

		addUnique(placements, winner[1])

		for _, player in ipairs(top2) do
			if player ~= winner[1] then
				addUnique(placements, player)
			end
		end

		for _, player in ipairs(top4) do
			addUnique(placements, player)
		end

		for _, player in ipairs(group) do
			addUnique(placements, player)
		end

		for place, player in ipairs(placements) do
			awardSinglePlayer(player, place)
		end

		if winner[1] then
			fireGroup(group, GameStatus, "?? " .. winner[1].Name .. " WINS!", 1, GROUP_SIZE)

			local UpdateUI = Events:FindFirstChild("UpdateUI")
			if UpdateUI then
				fireGroup(group, UpdateUI, {
					type = "podium",
					winner = winner[1].Name,
					placements = {
						[1] = placements[1] and placements[1].Name or "",
						[2] = placements[2] and placements[2].Name or "",
						[3] = placements[3] and placements[3].Name or "",
						[4] = placements[4] and placements[4].Name or "",
					}
				})
			end
		end

		local returnTime = RETURN_TIME

		while returnTime > 0 do
			fireGroup(group, GameStatus, "Returning everyone to lobby in " .. returnTime .. "s...", 0, GROUP_SIZE)
			fireGroup(group, TimerUpdate, returnTime, true)

			task.wait(1)
			returnTime -= 1
		end

		fireGroup(group, TimerUpdate, 0, false)

		for _, player in ipairs(group) do
			if player and player.Parent == Players then
				teleportToLobby(player)
			end

			activePlayers[player] = nil
			playerGroups[player] = nil
			eliminatedPlayers[player] = nil
			leftMatchPlayers[player] = nil
			rewardedPlayers[player] = nil
		end

		votes[groupId] = nil
		currentPerformer[groupId] = nil
		finishRequested[groupId] = nil
	end

	Players.PlayerRemoving:Connect(function(player)
		activePlayers[player] = nil
		playerGroups[player] = nil
		eliminatedPlayers[player] = nil
		leftMatchPlayers[player] = nil
		rewardedPlayers[player] = nil
	end)

	task.spawn(function()
		local groupCounter = 0

		while true do
			local waiting = getWaitingPlayers()

			for _, player in ipairs(Players:GetPlayers()) do
				if not activePlayers[player] then
					if isPlayerInQueueZone(player) then
						GameStatus:FireClient(player, ARENA_NAME .. " Queue: " .. #waiting .. "/" .. GROUP_SIZE, #waiting, GROUP_SIZE)
					end

					TimerUpdate:FireClient(player, 0, false)
				end
			end

			local group = makeGroup()

			if group then
				groupCounter += 1
				local groupId = ARENA_NAME .. "_Group_" .. groupCounter

				for t = START_DELAY, 1, -1 do
					group = cleanGroup(group)

					local stillInZone = {}

					for _, player in ipairs(group) do
						if player and player.Parent == Players and isPlayerInQueueZone(player) then
							table.insert(stillInZone, player)
						else
							activePlayers[player] = nil
							playerGroups[player] = nil

							if player and player.Parent == Players then
								GameStatus:FireClient(player, "You left the queue. Countdown cancelled.", 0, GROUP_SIZE)
								TimerUpdate:FireClient(player, 0, false)
							end
						end
					end

					group = stillInZone

					if #group < GROUP_SIZE then
						fireGroup(group, GameStatus, "Not enough players. Queue cancelled.", #group, GROUP_SIZE)

						for _, player in ipairs(group) do
							activePlayers[player] = nil
							playerGroups[player] = nil
							TimerUpdate:FireClient(player, 0, false)
						end

						break
					end

					fireGroup(group, GameStatus, ARENA_NAME .. " starting in " .. t .. "s!", #group, GROUP_SIZE)
					fireGroup(group, TimerUpdate, t, true)

					task.wait(1)
				end

				local finalGroup = {}

				for _, player in ipairs(group) do
					if player and player.Parent == Players and isPlayerInQueueZone(player) then
						table.insert(finalGroup, player)
					else
						activePlayers[player] = nil
						playerGroups[player] = nil
					end
				end

				if #finalGroup >= GROUP_SIZE then
					task.spawn(function()
						runTournament(groupId, finalGroup)
					end)
				else
					for _, player in ipairs(finalGroup) do
						activePlayers[player] = nil
						playerGroups[player] = nil
					end
				end
			end

			task.wait(2)
		end
	end)