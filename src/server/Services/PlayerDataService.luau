local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit
local PlayerDataModule = require(ReplicatedStorage.Shared.DataStructures.PlayerData)
local OnlineRewards = require(ReplicatedStorage.Shared.constants.OnlineRewards)
local SignInConfig = require(ReplicatedStorage.Shared.constants.SignInConfig)
local SkillCarks = require(ReplicatedStorage.Shared.constants.SkillCarks)
local PlayerLevels = require(ReplicatedStorage.Shared.constants.PlayerLevels)

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

function PlayerDataService.Client:ClaimDailySignIn(player, day)
	local data = playerDataMap[player.UserId]
	if not data then
		return false
	end

	if not PlayerDataModule.CanClaimDay(data.SignInData, day, data.FirstJoinTime) then
		return false
	end

	table.insert(data.SignInData.ClaimedDays, day)

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

function PlayerDataService.Client:SaveSkillHand(player, skillIndices)
	local data = playerDataMap[player.UserId]
	if not data then
		return false
	end

	if type(skillIndices) ~= "table" then
		return false
	end

	local level = data.PlayerLevel or 1
	local levelCfg = PlayerLevels[level]
	local maxSlots = levelCfg and levelCfg.SkillSlots or 4

	if #skillIndices > maxSlots then
		return false
	end

	local seen = {}
	for _, idx in skillIndices do
		if type(idx) ~= "number" or idx < 1 or idx > #SkillCarks.All then
			return false
		end
		if seen[idx] then
			return false
		end
		seen[idx] = true
	end

	data.SkillHand = skillIndices
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
			data.SignInData = { ClaimedDays = {} }
		elseif not data.SignInData.ClaimedDays then
			local totalDays = data.SignInData.TotalSignInDays or data.SignInData.ConsecutiveDays or 0
			local claimed = {}
			for i = 1, totalDays do
				table.insert(claimed, i)
			end
			data.SignInData = { ClaimedDays = claimed }
		end
		if not data.SkillHand or type(data.SkillHand) ~= "table" or #data.SkillHand == 0 then
			local lv = data.PlayerLevel or 1
			local cfg = PlayerLevels[lv]
			local slots = cfg and cfg.SkillSlots or 4
			local defaultIndices = { 1, 10, 20, 29 }
			local hand = {}
			for i = 1, math.min(slots, #defaultIndices) do
				table.insert(hand, defaultIndices[i])
			end
			data.SkillHand = hand
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
