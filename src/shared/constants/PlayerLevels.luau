local PlayerLevels = {
	[1] = {
		Name = "Normal",
		DisplayName = "普通玩家",
		Emoji = "🟢",
		Color = Color3.fromRGB(255, 255, 255),
		SignInDayRequired = 0,
		AutoRange = 0,
		AutoFireCooldown = 0,
		SkillSlots = 4,
	},
	[2] = {
		Name = "VIP",
		DisplayName = "VIP 玩家",
		Emoji = "💎",
		Color = Color3.fromRGB(255, 215, 80),
		SignInDayRequired = 2,
		AutoRange = 50,
		AutoFireCooldown = 0.5,
		SkillSlots = 6,
	},
	[3] = {
		Name = "SVIP",
		DisplayName = "SVIP 玩家",
		Emoji = "👑",
		Color = Color3.fromRGB(255, 69, 0),
		SignInDayRequired = 7,
		AutoRange = 80,
		AutoFireCooldown = 0.3,
		SkillSlots = 10,
	},
}

return PlayerLevels
