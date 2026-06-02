local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit
local PlayerDataModule = require(ReplicatedStorage.Shared.DataStructures.PlayerData)
local OnlineRewards = require(ReplicatedStorage.Shared.constants.OnlineRewards)
local SignInConfig = require(ReplicatedStorage.Shared.constants.SignInConfig)

local DATASTORE_NAME = "PlayerData_24Game"
local AUTOSAVE_INTERVAL = 60

local PlayerDataService = Knit.CreateService {
	Name = "PlayerDataService",
	Client = {
		GetData = Knit.CreateSignal(),
		DataChanged = Knit.CreateSignal(),
		RewardGranted = Knit.CreateSignal(),
		RewardProgress = Knit.CreateSignal(),
	},
}

local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local playerDataMap = {}
local playerClaimedRewards = {}

function PlayerDataService.Client:ClaimDailySignIn(player)
	local data = playerDataMap[player.UserId]
	if not data then
		return false
	end
	if not PlayerDataModule.CanSignIn(data.SignInData) then
		return false
	end

	data.SignInData = PlayerDataModule.ProcessSignIn(data.SignInData)
	local day = data.SignInData.TotalSignInDays
	local config = SignInConfig[day]

	if config then
		if config.Coins then
			data.Coins = math.max(0, data.Coins + config.Coins)
		end
		if config.LevelUp then
			data.PlayerLevel = config.LevelUp
		end
	end

	PlayerDataService.Client.DataChanged:Fire(player, data)
	return true
end

function PlayerDataService.Client:GMUpdateData(player, kv)
	local data = playerDataMap[player.UserId]
	if not data or type(kv) ~= "table" then
		return false, "invalid"
	end
	local allowed = { Coins = true, Floor = true, PlayerLevel = true }
	for k, v in kv do
		if allowed[k] then
			if k == "Floor" then
				data[k] = math.max(1, v)
			elseif k == "Coins" then
				data[k] = math.max(0, v)
			elseif k == "PlayerLevel" then
				data[k] = math.max(1, v)
			end
		end
	end
	PlayerDataService.Client.DataChanged:Fire(player, data)
	return true
end

function PlayerDataService:GetData(player)
	return playerDataMap[player.UserId]
end

function PlayerDataService:UpdateCoins(player, amount)
	local data = playerDataMap[player.UserId]
	if data then
		data.Coins = math.max(0, data.Coins + amount)
		self.Client.DataChanged:Fire(player, data)
	end
end

function PlayerDataService:SetCoins(player, amount)
	local data = playerDataMap[player.UserId]
	if data then
		data.Coins = math.max(0, amount)
		self.Client.DataChanged:Fire(player, data)
	end
end

function PlayerDataService:SetFloor(player, floor)
	local data = playerDataMap[player.UserId]
	if data then
		data.Floor = math.max(1, floor)
		self.Client.DataChanged:Fire(player, data)
	end
end

function PlayerDataService:SavePlayerData(player)
	local userId = player.UserId
	local data = playerDataMap[userId]
	if not data then
		return
	end

	local success, err = pcall(function()
		dataStore:SetAsync(tostring(userId), data)
	end)
	if not success then
		warn("SavePlayerData failed for", player.Name, err)
	end
end

function PlayerDataService:LoadPlayerData(player)
	local userId = player.UserId

	local success, data = pcall(function()
		return dataStore:GetAsync(tostring(userId))
	end)

	if success and data then
		playerDataMap[userId] = data
		if data.FirstJoinTime == 0 or not data.FirstJoinTime then
			data.FirstJoinTime = os.time()
		end
		if not data.PlayerLevel then
			data.PlayerLevel = 1
		end
		if not data.SignInData then
			data.SignInData = { LastSignInDate = "", TotalSignInDays = 0 }
		elseif data.SignInData.ConsecutiveDays then
			data.SignInData.TotalSignInDays = data.SignInData.ConsecutiveDays
			data.SignInData.ConsecutiveDays = nil
		end
		return data
	end

	local defaultData = PlayerDataModule.GetDefaultData()
	playerDataMap[userId] = defaultData
	return defaultData
end

function PlayerDataService:SaveAllPlayers()
	for _, player in Players:GetPlayers() do
		self:SavePlayerData(player)
	end
end

function PlayerDataService:StartRewardTimer(player)
	local userId = player.UserId
	playerClaimedRewards[userId] = {}

	task.spawn(function()
		local elapsed = 0
		while playerClaimedRewards[userId] do
			task.wait(1)
			elapsed += 1

			local claimed = playerClaimedRewards[userId]
			for _, reward in OnlineRewards do
				if not claimed[reward.Time] and elapsed >= reward.Time then
					claimed[reward.Time] = true
					self:UpdateCoins(player, reward.Coins)
					self.Client.RewardGranted:Fire(player, reward.Time, reward.Coins)
				end
			end

			self.Client.RewardProgress:Fire(player, elapsed, claimed)
		end
	end)
end

function PlayerDataService:KnitInit()
	Players.PlayerAdded:Connect(function(player)
		local data = self:LoadPlayerData(player)
		self.Client.GetData:Fire(player, data)
		self:StartRewardTimer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayerData(player)
		playerDataMap[player.UserId] = nil
		playerClaimedRewards[player.UserId] = nil
	end)
end

function PlayerDataService:KnitStart()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			self:SaveAllPlayers()
		end
	end)
end

return PlayerDataService
