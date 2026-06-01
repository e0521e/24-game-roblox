local LobbyConfig = {
	AFKZone = {
		Position = Vector3.new(0, 2.5, -40),
		Size = Vector3.new(40, 5, 40),
		CoinsPerSecond = 2,
	},
	TeleportZone = {
		Position = Vector3.new(0, 3, 40),
		Size = Vector3.new(10, 6, 5),
	},
	CompetitionZone = {
		Position = Vector3.new(45, 2.5, 0),
		Size = Vector3.new(40, 5, 40),
		RoomCount = 3,
	},
	EmptyZone = {
		Position = Vector3.new(-45, 2.5, 0),
		Size = Vector3.new(30, 5, 30),
	},
}

return LobbyConfig
