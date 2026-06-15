-- DailyRewardManager

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Events = ReplicatedStorage:WaitForChild("Events")
local GetDailyRewardData = Events:WaitForChild("GetDailyRewardData")
local ClaimDailyReward = Events:WaitForChild("ClaimDailyReward")

local rewardStore = DataStoreService:GetDataStore("DailyRewardsV2")

local rewards = {}

for day = 1, 90 do
	local amount = 10 + (day * 3)

	if day % 7 == 0 then
		amount += 75
	end

	if day % 30 == 0 then
		amount += 300
	end

	rewards[day] = amount
end

local playerData = {}

local function todayNumber()
	return math.floor(os.time() / 86400)
end

local function getDayFromStreak(streak)
	return ((streak - 1) % 90) + 1
end

local function loadData(player)
	local data = {
		streak = 0,
		lastClaim = 0
	}

	local success, saved = pcall(function()
		return rewardStore:GetAsync(tostring(player.UserId))
	end)

	if success and typeof(saved) == "table" then
		data.streak = saved.streak or 0
		data.lastClaim = saved.lastClaim or 0
	end

	playerData[player] = data
end

local function saveData(player)
	local data = playerData[player]
	if not data then return end

	pcall(function()
		rewardStore:SetAsync(tostring(player.UserId), data)
	end)
end

local function sendData(player)
	local data = playerData[player]
	if not data then return end

	local today = todayNumber()
	local canClaim = data.lastClaim < today

	local nextStreak = data.streak

	if canClaim then
		if data.lastClaim == today - 1 then
			nextStreak += 1
		else
			nextStreak = 1
		end
	end

	local rewardDay = getDayFromStreak(math.max(nextStreak, 1))
	local remaining = 0

	if not canClaim then
		local nextReset = (today + 1) * 86400
		remaining = math.max(0, nextReset - os.time())
	end

	GetDailyRewardData:FireClient(player, {
		streak = data.streak,
		nextDay = rewardDay,
		canClaim = canClaim,
		reward = rewards[rewardDay],
		rewards = rewards,
		remaining = remaining,
		maxDays = 90,
		pageSize = 30
	})
end

Players.PlayerAdded:Connect(function(player)
	loadData(player)
	task.wait(2)
	sendData(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player] = nil
end)

GetDailyRewardData.OnServerEvent:Connect(function(player)
	sendData(player)
end)

ClaimDailyReward.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then return end

	local today = todayNumber()

	if data.lastClaim >= today then
		sendData(player)
		return
	end

	if data.lastClaim == today - 1 then
		data.streak += 1
	else
		data.streak = 1
	end

	if data.streak > 90 then
		data.streak = 1
	end

	local rewardDay = getDayFromStreak(data.streak)
	local amount = rewards[rewardDay]

	data.lastClaim = today
	saveData(player)

	if _G.awardCoins then
		_G.awardCoins(player, amount)
	end

	sendData(player)
end)