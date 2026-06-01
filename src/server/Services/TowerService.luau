local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit

local TOWER_HEIGHT = 15
local TOWER_DEPTH = 150
local TOWER_WIDTH = 140

local TowerService = Knit.CreateService {
	Name = "TowerService",
	Client = {},
}

function TowerService:GetRoomPosition(floor)
	local towerBase = Workspace:FindFirstChild("Tower")
	if not towerBase then
		return Vector3.new(0, 5, 80)
	end
	local y = (floor - 1) * TOWER_HEIGHT + 5
	return Vector3.new(0, y, 80)
end

function TowerService:TeleportToFloor(player)
	local data = self.Server:GetData(player)
	if not data then
		return
	end
	local floor = data.Floor
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pos = self:GetRoomPosition(floor)
	root.CFrame = CFrame.new(pos)
end

function TowerService:BuildTower()
	local existing = Workspace:FindFirstChild("Tower")
	if existing then
		return
	end

	local tower = Instance.new("Model")
	tower.Name = "Tower"
	tower.Parent = Workspace

	local TOWER_Z = 65
	local HALF_W = TOWER_WIDTH / 2

	for level = 1, 10 do
		local y = (level - 1) * TOWER_HEIGHT

		local floor = Instance.new("Part")
		floor.Name = "Floor_" .. level
		floor.Size = Vector3.new(TOWER_WIDTH, 1, TOWER_DEPTH)
		floor.Position = Vector3.new(0, y + 0.5, TOWER_Z + TOWER_DEPTH / 2)
		floor.Anchored = true
		floor.BrickColor = BrickColor.new("Medium stone grey")
		floor.Material = Enum.Material.Concrete
		floor.Parent = tower

		local backWall = Instance.new("Part")
		backWall.Name = "BackWall"
		backWall.Size = Vector3.new(TOWER_WIDTH, TOWER_HEIGHT - 1, 0.5)
		backWall.Position = Vector3.new(0, y + TOWER_HEIGHT / 2, TOWER_Z + TOWER_DEPTH)
		backWall.Anchored = true
		backWall.BrickColor = BrickColor.new("Dark stone grey")
		backWall.Material = Enum.Material.Brick
		backWall.Parent = tower

		local leftWall = Instance.new("Part")
		leftWall.Name = "LeftWall"
		leftWall.Size = Vector3.new(0.5, TOWER_HEIGHT - 1, TOWER_DEPTH)
		leftWall.Position = Vector3.new(-HALF_W, y + TOWER_HEIGHT / 2, TOWER_Z + TOWER_DEPTH / 2)
		leftWall.Anchored = true
		leftWall.BrickColor = BrickColor.new("Dark stone grey")
		leftWall.Material = Enum.Material.Brick
		leftWall.Parent = tower

		local rightWall = Instance.new("Part")
		rightWall.Name = "RightWall"
		rightWall.Size = Vector3.new(0.5, TOWER_HEIGHT - 1, TOWER_DEPTH)
		rightWall.Position = Vector3.new(HALF_W, y + TOWER_HEIGHT / 2, TOWER_Z + TOWER_DEPTH / 2)
		rightWall.Anchored = true
		rightWall.BrickColor = BrickColor.new("Dark stone grey")
		rightWall.Material = Enum.Material.Brick
		rightWall.Parent = tower

		local sg = Instance.new("SurfaceGui")
		sg.Name = "FloorDisplay"
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(600, 160)
		sg.AlwaysOnTop = false
		sg.Parent = backWall

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = "FLOOR " .. level
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextSize = 72
		text.Font = Enum.Font.GothamBold
		text.TextStrokeTransparency = 0.9
		text.TextScaled = true
		text.Parent = sg

		local spawnPad = Instance.new("Part")
		spawnPad.Name = "SpawnPoint"
		spawnPad.Size = Vector3.new(6, 0.5, 6)
		spawnPad.Position = Vector3.new(0, y + 1, TOWER_Z + TOWER_DEPTH / 2)
		spawnPad.Anchored = true
		spawnPad.Transparency = 0.8
		spawnPad.BrickColor = BrickColor.new("Bright green")
		spawnPad.Parent = tower
	end
end

function TowerService:KnitInit()
	self.Server = Knit.GetService("PlayerDataService")
end

function TowerService:KnitStart()
	self:BuildTower()
end

return TowerService
