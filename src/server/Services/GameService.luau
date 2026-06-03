local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit
local Questions = require(ReplicatedStorage.Shared.constants.Questions)
local SkillCarks = require(ReplicatedStorage.Shared.constants.SkillCarks)

local GameService = Knit.CreateService {
	Name = "GameService",
	Client = {},
}

local playerService

function GameService:GetQuestionForFloor(floor)
	local idx = math.min(floor, #Questions)
	return Questions[idx]
end

function GameService.Client:StartQuestion(player)
	local data = playerService:GetData(player)
	if not data then
		return 1
	end
	return data.Floor
end

function GameService.Client:SubmitAnswer(player, cardIndex, skillIndex)
	print("SubmitAnswer", player.Name, "card", cardIndex, "skill", skillIndex)
	local data = playerService:GetData(player)
	if not data then
		print("SubmitAnswer: no data")
		return false, "no data"
	end

	local floor = data.Floor
	local question = GameService:GetQuestionForFloor(floor)
	if not question then
		print("SubmitAnswer: no question for floor", floor)
		return false, "no question"
	end

	local hand = data.SkillHand or { 1, 10, 20, 29 }

	local nums = {}
	for _, n in question.numbers do
		table.insert(nums, n)
	end
	print("SubmitAnswer: original nums", table.concat(nums, ","))

	if cardIndex and skillIndex then
		if cardIndex < 1 or cardIndex > #nums then
			return false, "invalid card"
		end
		if skillIndex < 1 or skillIndex > #hand then
			return false, "invalid skill"
		end
		local cardIdx = hand[skillIndex]
		local skill = SkillCarks.All[cardIdx]
		if not skill then
			return false, "invalid skill"
		end
		local old = nums[cardIndex]
		nums[cardIndex] = skill.apply(nums[cardIndex])
		print("SubmitAnswer: applied", skill.display, "on index", cardIndex, old, "->", nums[cardIndex])
	end

	local total = 0
	for _, n in nums do
		total += n
	end
	print("SubmitAnswer: final nums", table.concat(nums, ","), "total", total)

	if total == 24 then
		data.Floor = data.Floor + 1
		playerService.Client.DataChanged:Fire(player, data)
		print("SubmitAnswer: CORRECT, floor now", data.Floor)
		return true, "correct"
	end

	print("SubmitAnswer: WRONG", total)
	return false, tostring(total)
end

function GameService:KnitInit()
	playerService = Knit.GetService("PlayerDataService")
end

return GameService
