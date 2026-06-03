local PlayerData = {}

function PlayerData.GetDefaultData()
	return {
		Coins = 0,
		Floor = 1,
		PlayerLevel = 1,
		FirstJoinTime = os.time(),
		SignInData = {
			ClaimedDays = {},
		},
		SkillHand = { 1, 10, 20, 29 },
	}
end

function PlayerData.GetDaysSinceJoin(firstJoinTime, now)
	local current = now or os.time()
	local tJoin = os.date("*t", firstJoinTime)
	local tCur = os.date("*t", current)
	local joinDayStart = os.time({
		year = tJoin.year, month = tJoin.month, day = tJoin.day,
		hour = 0, min = 0, sec = 0,
	})
	local curDayStart = os.time({
		year = tCur.year, month = tCur.month, day = tCur.day,
		hour = 0, min = 0, sec = 0,
	})
	return math.floor((curDayStart - joinDayStart) / 86400) + 1
end

function PlayerData.CanClaimDay(signInData, day, firstJoinTime)
	if not signInData or not signInData.ClaimedDays then
		return false
	end
	if day < 1 or day > 7 then
		return false
	end
	local daysSinceJoin = PlayerData.GetDaysSinceJoin(firstJoinTime)
	if daysSinceJoin < day then
		return false
	end
	for _, claimedDay in signInData.ClaimedDays do
		if claimedDay == day then
			return false
		end
	end
	return true
end

return PlayerData
