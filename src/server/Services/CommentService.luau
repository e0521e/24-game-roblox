local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit

local CommentService = Knit.CreateService {
	Name = "CommentService",
	Client = {},
}

local dataStore = DataStoreService:GetDataStore("Comments_24Game")
local commentCache = {}

local function getKey(floor)
	return "floor_" .. tostring(floor)
end

function CommentService.Client:GetComments(player, floor)
	local key = getKey(floor)

	if not commentCache[key] then
		local success, data = pcall(function()
			return dataStore:GetAsync(key)
		end)
		if success and type(data) == "table" then
			commentCache[key] = data
		else
			commentCache[key] = {}
		end
	end

	return commentCache[key]
end

function CommentService.Client:AddComment(player, floor, text)
	if type(text) ~= "string" or #text == 0 or #text > 200 then
		return false, "评论长度需在1-200字之间"
	end

	local key = getKey(floor)

	if not commentCache[key] then
		commentCache[key] = {}
	end

	local comment = {
		PlayerName = player.Name,
		Text = text,
		Time = os.time(),
	}

	table.insert(commentCache[key], comment)

	if #commentCache[key] > 50 then
		table.remove(commentCache[key], 1)
	end

	task.spawn(function()
		pcall(function()
			dataStore:SetAsync(key, commentCache[key])
		end)
	end)

	return true, commentCache[key]
end

return CommentService
