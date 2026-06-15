-- CoinManager (ServerScriptService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local Events = ReplicatedStorage:WaitForChild("Events")

local AwardCoins = Events:WaitForChild("AwardCoins")
local GetCoins = Events:WaitForChild("GetCoins")
local BuySound = Events:WaitForChild("BuySound")
local EquipSound = Events:WaitForChild("EquipSound")
local PlaySound = Events:WaitForChild("PlaySound")
local ClaimDailySpin = Events:WaitForChild("ClaimDailySpin")

local VIP_PASS_ID = 1853783770

local coinStore = DataStoreService:GetDataStore("CringeCoins")
local ownedStore = DataStoreService:GetDataStore("OwnedSounds")
local equippedStore = DataStoreService:GetDataStore("EquippedSound")
local dailyStore = DataStoreService:GetDataStore("DailySpinData")

local playerCoins = {}
local playerOwnedSounds = {}
local playerEquipped = {}
local playerDailyData = {}
local soundCooldowns = {}

local SOUNDS = {

	-- FREE
	{id = "airhorn", name = "?? Air Horn", price = 0, soundId = "rbxassetid://9120416941"},
	{id = "bruh", name = "?? Bruh", price = 0, soundId = "rbxassetid://5153845638"},
	{id = "vineboom", name = "?? Vine Boom", price = 0, soundId = "rbxassetid://5153846175"},

	-- COMMON
	{id = "wow", name = "?? Wow", price = 50, soundId = "rbxassetid://4910676083"},
	{id = "wronganswer", name = "? Wrong Answer", price = 75, soundId = "rbxassetid://4910602463"},
	{id = "missionpassed", name = "?? Mission Passed", price = 100, soundId = "rbxassetid://1843520820"},
	{id = "laugh", name = "?? Laugh", price = 120, soundId = "rbxassetid://9067224553"},
	{id = "sad", name = "?? Sad", price = 130, soundId = "rbxassetid://1845935736"},

	-- RARE
	{id = "emotional", name = "?? Emotional Damage", price = 180, soundId = "rbxassetid://8104607351"},
	{id = "rizz", name = "?? Rizz", price = 220, soundId = "rbxassetid://9042248376"},
	{id = "scream", name = "?? Scream", price = 250, soundId = "rbxassetid://9114395535"},
	{id = "boowomp", name = "?? Boo Womp", price = 260, soundId = "rbxassetid://1837635126"},

	-- EPIC
	{id = "sigma", name = "?? Sigma", price = 400, soundId = "rbxassetid://9048375035"},
	{id = "gigachad", name = "?? Gigachad", price = 450, soundId = "rbxassetid://8755253823"},
	{id = "metalpipe", name = "?? Metal Pipe", price = 500, soundId = "rbxassetid://9118828561"},
	{id = "vinebass", name = "?? Vine Bass", price = 550, soundId = "rbxassetid://6389463761"},

	-- LEGENDARY
	{id = "johncena", name = "?? John Cena", price = 800, soundId = "rbxassetid://650898624"},
	{id = "troll", name = "?? Troll Laugh", price = 950, soundId = "rbxassetid://8466593009"},
	{id = "goofy", name = "?? Goofy Ahh", price = 1200, soundId = "rbxassetid://9074555470"},
}

local DAILY_REWARDS = {
	{type = "coins", amount = 50},
	{type = "coins", amount = 75},
	{type = "coins", amount = 100},
	{type = "coins", amount = 150},
	{type = "coins", amount = 250},
	{type = "xp", amount = 100},
	{type = "xp", amount = 200},
}

local function isVIP(player)
	local success, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(
			player.UserId,
			VIP_PASS_ID
		)
	end)

	return success and ownsPass
end

local function getSoundData(soundId)
	for _, sound in ipairs(SOUNDS) do
		if sound.id == soundId then
			return sound
		end
	end

	return nil
end

local function ownsSound(player, soundId)
	local owned = playerOwnedSounds[player.Name] or {}

	for _, id in ipairs(owned) do
		if id == soundId then
			return true
		end
	end

	return false
end

local function addOwnedSound(player, soundId)
	if not playerOwnedSounds[player.Name] then
		playerOwnedSounds[player.Name] = {}
	end

	if not ownsSound(player, soundId) then
		table.insert(playerOwnedSounds[player.Name], soundId)
	end
end

local function giveFreeSounds(player)
	addOwnedSound(player, "airhorn")
	addOwnedSound(player, "bruh")
	addOwnedSound(player, "vineboom")

	if not playerEquipped[player.Name] then
		playerEquipped[player.Name] = "airhorn"
	end
end

local function sendData(player)
	GetCoins:FireClient(
		player,
		playerCoins[player.Name] or 0,
		playerOwnedSounds[player.Name] or {},
		playerEquipped[player.Name]
	)
end

local function savePlayer(player)

	pcall(function()
		coinStore:SetAsync(
			tostring(player.UserId),
			playerCoins[player.Name] or 0
		)
	end)

	pcall(function()
		ownedStore:SetAsync(
			tostring(player.UserId),
			playerOwnedSounds[player.Name] or {}
		)
	end)

	pcall(function()
		equippedStore:SetAsync(
			tostring(player.UserId),
			playerEquipped[player.Name]
		)
	end)

	pcall(function()
		dailyStore:SetAsync(
			tostring(player.UserId),
			playerDailyData[player.Name] or {lastClaim = 0}
		)
	end)
end

local function awardCoins(player, amount)

	if not player or not player.Parent then
		return
	end

	local finalAmount = amount

	-- VIP BONUS
	if isVIP(player) then
		finalAmount = math.floor(amount * 1.25)
	end

	playerCoins[player.Name] =
		(playerCoins[player.Name] or 0) + finalAmount

	sendData(player)

	print(player.Name .. " awarded " .. finalAmount .. " coins")
end

_G.awardCoins = awardCoins
_G.SOUNDS = SOUNDS

Players.PlayerAdded:Connect(function(player)

	local coins = 0
	local owned = {}
	local equipped = nil
	local dailyData = {lastClaim = 0}

	pcall(function()
		local data = coinStore:GetAsync(tostring(player.UserId))
		if type(data) == "number" then
			coins = data
		end
	end)

	pcall(function()
		local data = ownedStore:GetAsync(tostring(player.UserId))
		if type(data) == "table" then
			owned = data
		end
	end)

	pcall(function()
		local data = equippedStore:GetAsync(tostring(player.UserId))
		if type(data) == "string" then
			equipped = data
		end
	end)

	pcall(function()
		local data = dailyStore:GetAsync(tostring(player.UserId))
		if type(data) == "table" then
			dailyData = data
		end
	end)

	playerCoins[player.Name] = coins
	playerOwnedSounds[player.Name] = owned
	playerEquipped[player.Name] = equipped
	playerDailyData[player.Name] = dailyData

	giveFreeSounds(player)

	task.wait(1)
	sendData(player)
end)

Players.PlayerRemoving:Connect(function(player)

	savePlayer(player)

	playerCoins[player.Name] = nil
	playerOwnedSounds[player.Name] = nil
	playerEquipped[player.Name] = nil
	playerDailyData[player.Name] = nil
	soundCooldowns[player.Name] = nil
end)

GetCoins.OnServerEvent:Connect(function(player)
	sendData(player)
end)

BuySound.OnServerEvent:Connect(function(player, soundId)

	local soundData = getSoundData(soundId)

	if not soundData then
		return
	end

	if ownsSound(player, soundId) then
		return
	end

	local coins = playerCoins[player.Name] or 0

	if coins < soundData.price then
		return
	end

	playerCoins[player.Name] =
		playerCoins[player.Name] - soundData.price

	addOwnedSound(player, soundId)

	sendData(player)
	savePlayer(player)

	BuySound:FireClient(player, soundId, true)
end)

EquipSound.OnServerEvent:Connect(function(player, soundId)

	if not ownsSound(player, soundId) then
		return
	end

	playerEquipped[player.Name] = soundId

	sendData(player)
	savePlayer(player)

	EquipSound:FireClient(player, soundId)
end)

PlaySound.OnServerEvent:Connect(function(player, soundId)

	if playerEquipped[player.Name] ~= soundId then
		return
	end

	local soundData = getSoundData(soundId)

	if not soundData then
		return
	end

	local now = os.clock()

	if soundCooldowns[player.Name]
		and now - soundCooldowns[player.Name] < 3 then
		return
	end

	soundCooldowns[player.Name] = now

	local sound = Instance.new("Sound")
	sound.SoundId = soundData.soundId
	sound.Volume = 1
	sound.RollOffMaxDistance = 100
	sound.Parent = workspace

	sound:Play()

	Debris:AddItem(sound, 10)
end)

ClaimDailySpin.OnServerEvent:Connect(function(player)

	local data = playerDailyData[player.Name]

	if not data then
		return
	end

	local now = os.time()

	if now - (data.lastClaim or 0) < 86400 then

		ClaimDailySpin:FireClient(player, {
			type = "cooldown"
		})

		return
	end

	data.lastClaim = now

	local reward =
		DAILY_REWARDS[math.random(1, #DAILY_REWARDS)]

	if reward.type == "coins" then

		awardCoins(player, reward.amount)

	elseif reward.type == "xp" then

		if _G.awardXP then
			_G.awardXP(player, reward.amount)
		end
	end

	savePlayer(player)

	ClaimDailySpin:FireClient(player, reward)
end)