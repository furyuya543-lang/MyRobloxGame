-- PurchasesHandler
-- Put in ServerScriptService

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local VIP_GAMEPASS_ID = 1853783770

local PRODUCTS = {
	[3596875000] = 100,
	[3596875233] = 500,
	[3596875385] = 1000,
}

local function giveCoins(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("No leaderstats for", player.Name)
		return false
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		warn("No Coins value for", player.Name)
		return false
	end

	coins.Value += amount
	print("Gave", amount, "coins to", player.Name)
	return true
end

local function giveVIP(player)
	player:SetAttribute("VIP", true)
	print(player.Name .. " has VIP")
end

Players.PlayerAdded:Connect(function(player)
	local success, ownsVIP = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)

	if success and ownsVIP then
		giveVIP(player)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
	if gamePassId == VIP_GAMEPASS_ID and purchased then
		giveVIP(player)
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	print("Purchase received:", receiptInfo.ProductId)

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local coinAmount = PRODUCTS[receiptInfo.ProductId]
	if not coinAmount then
		warn("Unknown product:", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success = giveCoins(player, coinAmount)

	if success then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end