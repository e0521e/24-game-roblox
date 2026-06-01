local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit
local Zone = require(ReplicatedStorage.Zone)
local LobbyConfig = require(ReplicatedStorage.Shared.constants.LobbyConfig)
local ZoneColors = {
	AFK = Color3.fromRGB(50, 255, 100),
	Teleport = Color3.fromRGB(50, 150, 255),
	Competition = Color3.fromRGB(255, 200, 50),
	Empty = Color3.fromRGB(180, 180, 180),
}

local LobbyService = Knit.CreateService {
	Name = "LobbyService",
	Client = {},
}

local afkZone
local teleportZone
local afkTrack = {}

local function createLobbyFloor()
	local existing = Workspace:FindFirstChild("Lobby")
	if existing then
		return
	end

	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = Workspace

	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(140, 1, 130)
	platform.Position = Vector3.new(0, 0, 0)
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Medium stone grey")
	platform.Material = Enum.Material.Concrete
	platform.Parent = lobby

	local function makeZoneFloor(name, pos, size, color)
		local part = Instance.new("Part")
		part.Name = name .. "_Floor"
		part.Size = Vector3.new(size.X, 0.2, size.Z)
		part.Position = Vector3.new(pos.X, 0.1, pos.Z)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 0.65
		part.Color = color
		part.Material = Enum.Material.Neon
		part.Parent = lobby
		return part
	end

	local function makeLabelPart(name, cf, text, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(6, 0.5, 0.5)
		part.CFrame = cf
		part.Anchored = true
		part.Transparency = 0.2
		part.Color = color
		part.Parent = lobby

		local gui = Instance.new("BillboardGui")
		gui.Name = "LabelGui"
		gui.Size = UDim2.fromOffset(320, 70)
		gui.Adornee = part
		gui.AlwaysOnTop = true
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 22
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.3
		label.Parent = gui

		return part
	end

	local function makeTeleportGate(pos)
		local gate = Instance.new("Model")
		gate.Name = "TeleportGate"
		gate.Parent = lobby

		local color = ZoneColors.Teleport
		local pillarW = 1
		local gateW = 8
		local gateH = 7

		local left = Instance.new("Part")
		left.Name = "PillarLeft"
		left.Size = Vector3.new(pillarW, gateH, pillarW)
		left.Position = Vector3.new(pos.X - gateW / 2, gateH / 2, pos.Z)
		left.Anchored = true
		left.CanCollide = false
		left.Transparency = 0.3
		left.Color = color
		left.Material = Enum.Material.Neon
		left.Parent = gate

		local right = left:Clone()
		right.Name = "PillarRight"
		right.Position = Vector3.new(pos.X + gateW / 2, gateH / 2, pos.Z)
		right.Parent = gate

		local beam = Instance.new("Part")
		beam.Name = "Beam"
		beam.Size = Vector3.new(gateW + pillarW, pillarW, pillarW)
		beam.Position = Vector3.new(pos.X, gateH - pillarW / 2, pos.Z)
		beam.Anchored = true
		beam.CanCollide = false
		beam.Transparency = 0.3
		beam.Color = color
		beam.Material = Enum.Material.Neon
		beam.Parent = gate

		local floorGlow = Instance.new("Part")
		floorGlow.Name = "FloorGlow"
		floorGlow.Size = Vector3.new(gateW, 0.2, pillarW)
		floorGlow.Position = Vector3.new(pos.X, 0.1, pos.Z)
		floorGlow.Anchored = true
		floorGlow.CanCollide = false
		floorGlow.Transparency = 0.5
		floorGlow.Color = color
		floorGlow.Material = Enum.Material.Neon
		floorGlow.Parent = gate

		local gui = Instance.new("BillboardGui")
		gui.Name = "GateLabel"
		gui.Size = UDim2.fromOffset(160, 40)
		gui.Adornee = beam
		gui.AlwaysOnTop = true
		gui.StudsOffset = Vector3.new(0, 1.5, 0)
		gui.Parent = beam

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = "🚪 传送"
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextSize = 20
		text.Font = Enum.Font.GothamBold
		text.TextStrokeTransparency = 0.3
		text.Parent = gui
	end

	local c = LobbyConfig

	makeZoneFloor("AFK", c.AFKZone.Position, c.AFKZone.Size, ZoneColors.AFK)
	makeTeleportGate(c.TeleportZone.Position)
	makeZoneFloor("Competition", c.CompetitionZone.Position, c.CompetitionZone.Size, ZoneColors.Competition)
	makeZoneFloor("Empty", c.EmptyZone.Position, c.EmptyZone.Size, ZoneColors.Empty)

	makeLabelPart("AFKLabel", CFrame.new(c.AFKZone.Position.X, 4, c.AFKZone.Position.Z), "🏠 挂机区\n每秒 +" .. c.AFKZone.CoinsPerSecond .. " 金币", ZoneColors.AFK)
	makeLabelPart("CompetitionLabel", CFrame.new(c.CompetitionZone.Position.X, 4, c.CompetitionZone.Position.Z), "🏆 比赛区", ZoneColors.Competition)
	makeLabelPart("EmptyLabel", CFrame.new(c.EmptyZone.Position.X, 4, c.EmptyZone.Position.Z), "❓ 未知区域\n敬请期待", ZoneColors.Empty)

end

local function setupZones()
	local c = LobbyConfig
	afkZone = Zone.fromRegion(CFrame.new(c.AFKZone.Position), c.AFKZone.Size)
	teleportZone = Zone.fromRegion(CFrame.new(c.TeleportZone.Position), c.TeleportZone.Size)

	afkZone.playerEntered:Connect(function(player)
		afkTrack[player] = true
	end)
	afkZone.playerExited:Connect(function(player)
		afkTrack[player] = nil
	end)

	teleportZone.playerEntered:Connect(function(player)
		local towerService = Knit.GetService("TowerService")
		towerService:TeleportToFloor(player)
	end)
end

local function startAFKTimer()
	local service = Knit.GetService("PlayerDataService")
	task.spawn(function()
		while true do
			task.wait(1)
			for player, active in afkTrack do
				if active and player.Parent then
					service:UpdateCoins(player, LobbyConfig.AFKZone.CoinsPerSecond)
				end
			end
		end
	end)
end

function LobbyService:KnitStart()
	createLobbyFloor()
	setupZones()
	startAFKTimer()
end

return LobbyService
