local PlayerData = {}

function PlayerData.GetDefaultData()
	return {
		Coins = 0,
		Floor = 1,
		PlayerLevel = 1,
		FirstJoinTime = os.time(),
		SignInData = {
			LastSignInDate = "",
			TotalSignInDays = 0,
		},
	}
end

function PlayerData.GetTodayDate()
	return os.date("%Y%m%d")
end

function PlayerData.CanSignIn(signInData)
	local today = PlayerData.GetTodayDate()
	if signInData.LastSignInDate == today then
		return false
	end
	if signInData.TotalSignInDays >= 7 then
		return false
	end
	return true
end

function PlayerData.ProcessSignIn(signInData)
	local today = PlayerData.GetTodayDate()
	local newData = {
		LastSignInDate = today,
		TotalSignInDays = math.min(signInData.TotalSignInDays + 1, 7),
	}
	return newData
end

return PlayerData
