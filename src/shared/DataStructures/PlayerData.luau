local PlayerData = {}

function PlayerData.GetDefaultData()
	return {
		Coins = 0,
		Floor = 1,
		FirstJoinTime = os.time(),
		SignInData = {
			LastSignInDate = "",
			ConsecutiveDays = 0,
		},
	}
end

function PlayerData.GetTodayDate()
	return os.date("%Y%m%d")
end

function PlayerData.GetYesterdayDate()
	local today = os.date("*t")
	local yesterday = os.time({ year = today.year, month = today.month, day = today.day }) - 86400
	return os.date("%Y%m%d", yesterday)
end

function PlayerData.CanSignIn(signInData)
	local today = PlayerData.GetTodayDate()
	return signInData.LastSignInDate ~= today
end

function PlayerData.ProcessSignIn(signInData)
	local today = PlayerData.GetTodayDate()
	local newData = {
		LastSignInDate = today,
		ConsecutiveDays = 1,
	}

	if signInData.LastSignInDate ~= "" then
		local yesterday = PlayerData.GetYesterdayDate()
		if signInData.LastSignInDate == yesterday then
			newData.ConsecutiveDays = math.min(signInData.ConsecutiveDays + 1, 7)
		end
	end

	return newData
end

return PlayerData
