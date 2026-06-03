local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit
local OnlineRewards = require(ReplicatedStorage.Shared.constants.OnlineRewards)
local SignInConfig = require(ReplicatedStorage.Shared.constants.SignInConfig)
local PlayerLevels = require(ReplicatedStorage.Shared.constants.PlayerLevels)
local PlayerDataModule = require(ReplicatedStorage.Shared.DataStructures.PlayerData)

local PlayerDataController = Knit.CreateController {
	Name = "PlayerDataController",
}

local player = Players.LocalPlayer
local cachedData = nil
local notificationGui
local floaterGui
local prevCoins = 0

local coinValue, floorValue
local progressFill, progressTimer
local milestoneDots = {}
local milestoneLabels = {}

local WIDTH = 260
local PAD = 12
local BAR_WIDTH = WIDTH - PAD * 2

local function formatNumber(n)
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(n)
end

local function formatTimeCompact(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if s == 0 then
		return string.format("%d分钟", m)
	end
	return string.format("%d分%d秒", m, s)
end

local nameTagGui

local function refreshNameTag()
	local data = cachedData
	local level = data and data.PlayerLevel or 1
	local levelCfg = PlayerLevels[level]
	local prefix = ""
	if level > 1 and levelCfg then
		prefix = levelCfg.Emoji .. " "
	end
	local displayText = prefix .. player.Name
	if nameTagGui then
		local label = nameTagGui:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = displayText
			if levelCfg and level > 1 then
				label.TextColor3 = levelCfg.Color
			end
		end
	end
end

local function createNameTag(char)
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end

	local old = head:FindFirstChild("NameTag")
	if old then
		old:Destroy()
	end

	local bg = Instance.new("BillboardGui")
	bg.Name = "NameTag"
	bg.Size = UDim2.fromOffset(200, 30)
	bg.Adornee = head
	bg.StudsOffset = Vector3.new(0, 2.5, 0)
	bg.AlwaysOnTop = true
	bg.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = player.Name
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 18
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.4
	label.Parent = bg

	nameTagGui = bg
	refreshNameTag()
end

local function showCoinFloater(amount)
	local char = player.Character
	if char then
		local head = char:FindFirstChild("Head")
		if head then
			local bg = Instance.new("BillboardGui")
			bg.Name = "CoinFloater"
			bg.Size = UDim2.fromOffset(100, 40)
			bg.Adornee = head
			bg.StudsOffset = Vector3.new(0, 3, 0)
			bg.AlwaysOnTop = true
			bg.Parent = head

			local text = Instance.new("TextLabel")
			text.Size = UDim2.new(1, 0, 1, 0)
			text.BackgroundTransparency = 1
			text.Text = "+" .. formatNumber(amount)
			text.TextColor3 = Color3.fromRGB(255, 215, 80)
			text.TextSize = 28
			text.Font = Enum.Font.GothamBold
			text.TextStrokeTransparency = 0.3
			text.Parent = bg

			local tw = TweenService:Create(bg, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffset = Vector3.new(0, 6, 0),
			})
			tw:Play()
			task.wait(0.8)

			local fade = TweenService:Create(text, TweenInfo.new(0.3), { TextTransparency = 1 })
			fade:Play()
			task.wait(0.3)
			bg:Destroy()
		end
	end
end

local function showHUDFloater(amount)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(80, 24)
	label.Position = UDim2.fromOffset(12, 8)
	label.BackgroundTransparency = 1
	label.Text = "+" .. formatNumber(amount)
	label.TextColor3 = Color3.fromRGB(255, 215, 80)
	label.TextSize = 18
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = floaterGui

	local tw = TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(12, -20),
		TextTransparency = 1,
	})
	tw:Play()
	tw.Completed:Wait()
	label:Destroy()
end

local gmPanelOpen = false
local gmPanel, gmTextBox, gmResult

local signInPanelOpen = false
local signInPanel, signInDaySlots = nil, {}
local signInStatusLabel, signInLevelLabel

local function toggleGMPanel()
	gmPanelOpen = not gmPanelOpen
	gmPanel.Visible = gmPanelOpen
end

local function refreshSignInPanel()
	if not signInPanel then
		return
	end

	local data = cachedData
	local signInData = data and data.SignInData
	local claimedDays = signInData and signInData.ClaimedDays or {}
	local firstJoin = data and data.FirstJoinTime or os.time()
	local daysSinceJoin = PlayerDataModule.GetDaysSinceJoin(firstJoin)
	local maxAvailable = math.min(daysSinceJoin, 7)

	local function isClaimed(day)
		for _, d in claimedDays do
			if d == day then
				return true
			end
		end
		return false
	end

	local level = data and data.PlayerLevel or 1
	local levelCfg = PlayerLevels[level]
	if levelCfg then
		signInLevelLabel.Text = levelCfg.Emoji .. " " .. levelCfg.DisplayName
		signInLevelLabel.TextColor3 = levelCfg.Color
	else
		signInLevelLabel.Text = "Lv." .. tostring(level)
		signInLevelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	local claimedCount = #claimedDays
	signInStatusLabel.Text = "已签到 " .. claimedCount .. " 天" .. "  |  当前可签第 " .. maxAvailable .. " 天"
	signInStatusLabel.TextColor3 = Color3.fromRGB(255, 215, 80)

	for day = 1, 7 do
		local slot = signInDaySlots[day]
		if slot then
			local claimed = isClaimed(day)
			local available = day <= maxAvailable

			if claimed then
				slot.cell.BackgroundColor3 = Color3.fromRGB(100, 200, 120)
				slot.cell.BackgroundTransparency = 0.6
				slot.dayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				slot.coinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				slot.statusIcon.Text = "✅"
				slot.statusIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
			elseif available then
				slot.cell.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
				slot.cell.BackgroundTransparency = 0.3
				slot.dayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				slot.coinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				slot.statusIcon.Text = "🎁"
				slot.statusIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				slot.cell.BackgroundColor3 = Color3.fromRGB(28, 28, 48)
				slot.cell.BackgroundTransparency = 0
				slot.dayLabel.TextColor3 = Color3.fromRGB(100, 100, 130)
				slot.coinLabel.TextColor3 = Color3.fromRGB(100, 100, 130)
				slot.statusIcon.Text = "🔒"
				slot.statusIcon.TextColor3 = Color3.fromRGB(80, 80, 100)
			end
		end
	end
end

local function toggleSignInPanel()
	signInPanelOpen = not signInPanelOpen
	signInPanel.Visible = signInPanelOpen
	if signInPanelOpen then
		refreshSignInPanel()
	end
end

local function createGMPanel(guiParent)
	local bg = Instance.new("Frame")
	bg.Name = "GMPanel"
	bg.Size = UDim2.fromOffset(300, 200)
	bg.Position = UDim2.new(0.5, -150, 0.5, -100)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 36)
	bg.BackgroundTransparency = 0.1
	bg.BorderSizePixel = 0
	bg.Visible = false
	bg.Parent = guiParent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.85
	stroke.Thickness = 1
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Text = "GM 工具"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = bg

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(24, 24)
	closeBtn.Position = UDim2.new(1, -32, 0, 8)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = bg
	closeBtn.MouseButton1Click:Connect(toggleGMPanel)

	gmTextBox = Instance.new("TextBox")
	gmTextBox.Size = UDim2.new(1, -24, 0, 70)
	gmTextBox.Position = UDim2.fromOffset(12, 44)
	gmTextBox.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
	gmTextBox.BackgroundTransparency = 0.2
	gmTextBox.BorderSizePixel = 0
	gmTextBox.Text = '{"Floor": 2}'
	gmTextBox.TextColor3 = Color3.fromRGB(200, 200, 220)
	gmTextBox.TextSize = 14
	gmTextBox.Font = Enum.Font.SourceSans
	gmTextBox.TextXAlignment = Enum.TextXAlignment.Left
	gmTextBox.TextYAlignment = Enum.TextYAlignment.Top
	gmTextBox.ClearTextOnFocus = false
	gmTextBox.Parent = bg

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = gmTextBox

	local printBtn = Instance.new("TextButton")
	printBtn.Name = "PrintBtn"
	printBtn.Size = UDim2.fromOffset(88, 32)
	printBtn.Position = UDim2.fromOffset(58, 164)
	printBtn.BackgroundColor3 = Color3.fromRGB(100, 160, 255)
	printBtn.BackgroundTransparency = 0.2
	printBtn.BorderSizePixel = 0
	printBtn.Text = "打印"
	printBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	printBtn.TextSize = 16
	printBtn.Font = Enum.Font.GothamBold
	printBtn.Parent = bg

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 6)
	pCorner.Parent = printBtn

	printBtn.MouseButton1Click:Connect(function()
		local dataController = Knit.GetController("PlayerDataController")
		local data = dataController and dataController:GetData()
		if data then
			print("[GM] PlayerData:", HttpService:JSONEncode(data))
		else
			print("[GM] No cached player data")
		end
	end)

	local modifyBtn = Instance.new("TextButton")
	modifyBtn.Name = "ModifyBtn"
	modifyBtn.Size = UDim2.fromOffset(88, 32)
	modifyBtn.Position = UDim2.fromOffset(154, 164)
	modifyBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	modifyBtn.BackgroundTransparency = 0.2
	modifyBtn.BorderSizePixel = 0
	modifyBtn.Text = "修改"
	modifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	modifyBtn.TextSize = 16
	modifyBtn.Font = Enum.Font.GothamBold
	modifyBtn.Parent = bg

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = modifyBtn

	gmResult = Instance.new("TextLabel")
	gmResult.Size = UDim2.new(1, -24, 0, 20)
	gmResult.Position = UDim2.fromOffset(12, 1)
	gmResult.BackgroundTransparency = 1
	gmResult.Text = ""
	gmResult.TextColor3 = Color3.fromRGB(100, 255, 100)
	gmResult.TextSize = 13
	gmResult.Font = Enum.Font.Gotham
	gmResult.TextXAlignment = Enum.TextXAlignment.Left
	gmResult.Parent = bg

	modifyBtn.MouseButton1Click:Connect(function()
		local json = gmTextBox.Text
		local success, data = pcall(HttpService.JSONDecode, HttpService, json)
		if not success or type(data) ~= "table" then
			gmResult.Text = "JSON 格式错误"
			gmResult.TextColor3 = Color3.fromRGB(255, 100, 100)
			return
		end
		local service = Knit.GetService("PlayerDataService")
		local ok = service:GMUpdateData(data)
		if ok then
			gmResult.Text = "修改成功"
			gmResult.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			gmResult.Text = "修改失败，不允许的 key"
			gmResult.TextColor3 = Color3.fromRGB(255, 100, 100)
		end
	end)

	gmPanel = bg
end

local function createGMButton(guiParent)
	local btn = Instance.new("TextButton")
	btn.Name = "GMButton"
	btn.Size = UDim2.fromOffset(56, 40)
	btn.Position = UDim2.new(1, -60, 0.5, 26)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.Text = "GM"
	btn.TextColor3 = Color3.fromRGB(255, 200, 50)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.Parent = guiParent

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 50)
	stroke.Transparency = 0.7
	stroke.Thickness = 1
	stroke.Parent = btn

	btn.MouseButton1Click:Connect(toggleGMPanel)
end

local function createSignInPanel(guiParent)
	local W = 380
	local H = 340
	local bg = Instance.new("Frame")
	bg.Name = "SignInPanel"
	bg.Size = UDim2.fromOffset(W, H)
	bg.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
	bg.BackgroundColor3 = Color3.fromRGB(18, 18, 34)
	bg.BackgroundTransparency = 0.08
	bg.BorderSizePixel = 0
	bg.Visible = false
	bg.Parent = guiParent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 80)
	stroke.Transparency = 0.7
	stroke.Thickness = 1.5
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.fromOffset(10, 10)
	title.BackgroundTransparency = 1
	title.Text = "每日签到"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = bg

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(28, 28)
	closeBtn.Position = UDim2.new(1, -36, 0, 10)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = bg
	closeBtn.MouseButton1Click:Connect(toggleSignInPanel)

	signInLevelLabel = Instance.new("TextLabel")
	signInLevelLabel.Size = UDim2.new(1, -20, 0, 22)
	signInLevelLabel.Position = UDim2.fromOffset(10, 44)
	signInLevelLabel.BackgroundTransparency = 1
	signInLevelLabel.Text = ""
	signInLevelLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	signInLevelLabel.TextSize = 14
	signInLevelLabel.Font = Enum.Font.Gotham
	signInLevelLabel.TextXAlignment = Enum.TextXAlignment.Left
	signInLevelLabel.Parent = bg

	local sep1 = Instance.new("Frame")
	sep1.Size = UDim2.new(1, -20, 0, 1)
	sep1.Position = UDim2.fromOffset(10, 68)
	sep1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sep1.BackgroundTransparency = 0.88
	sep1.BorderSizePixel = 0
	sep1.Parent = bg

	local CELL_W = 72
	local CELL_H = 60
	local CELL_GAP = 8
	local totalCellsW = 4 * CELL_W + 3 * CELL_GAP
	local gridStartX = (W - totalCellsW) / 2
	local ROW1_Y = 78
	local ROW2_Y = ROW1_Y + CELL_H + CELL_GAP

	local cellPositions = {
		{ x = gridStartX, y = ROW1_Y, w = CELL_W, h = CELL_H },
		{ x = gridStartX + (CELL_W + CELL_GAP), y = ROW1_Y, w = CELL_W, h = CELL_H },
		{ x = gridStartX + 2 * (CELL_W + CELL_GAP), y = ROW1_Y, w = CELL_W, h = CELL_H },
		{ x = gridStartX, y = ROW2_Y, w = CELL_W, h = CELL_H },
		{ x = gridStartX + (CELL_W + CELL_GAP), y = ROW2_Y, w = CELL_W, h = CELL_H },
		{ x = gridStartX + 2 * (CELL_W + CELL_GAP), y = ROW2_Y, w = CELL_W, h = CELL_H },
		{ x = gridStartX + 3 * (CELL_W + CELL_GAP), y = ROW1_Y, w = CELL_W, h = 2 * CELL_H + CELL_GAP },
	}

	for day = 1, 7 do
		local pos = cellPositions[day]
		local cfg = SignInConfig[day]

		local cell = Instance.new("Frame")
		cell.Name = "SignInDay_" .. day
		cell.Size = UDim2.fromOffset(pos.w, pos.h)
		cell.Position = UDim2.fromOffset(pos.x, pos.y)
		cell.BackgroundColor3 = Color3.fromRGB(28, 28, 48)
		cell.BorderSizePixel = 0
		cell.Parent = bg

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 8)
		cCorner.Parent = cell

		local dayLabel = Instance.new("TextLabel")
		dayLabel.Size = UDim2.new(1, 0, 0, 18)
		dayLabel.Position = UDim2.fromOffset(0, 6)
		dayLabel.BackgroundTransparency = 1
		dayLabel.Text = "第" .. day .. "天"
		dayLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
		dayLabel.TextSize = 12
		dayLabel.Font = Enum.Font.Gotham
		dayLabel.Parent = cell

		local coinLabel = Instance.new("TextLabel")
		coinLabel.Size = UDim2.new(1, 0, 0, 24)
		coinLabel.Position = UDim2.fromOffset(0, 26)
		coinLabel.BackgroundTransparency = 1
		coinLabel.TextSize = 13
		coinLabel.Font = Enum.Font.GothamBold
		coinLabel.TextScaled = true
		coinLabel.Parent = cell

		if cfg.LevelUp then
			local lvCfg = PlayerLevels[cfg.LevelUp]
			coinLabel.Text = lvCfg and (lvCfg.Emoji .. " " .. lvCfg.Name) or ("Lv." .. cfg.LevelUp)
			coinLabel.TextColor3 = lvCfg and lvCfg.Color or Color3.fromRGB(255, 215, 80)
			if day == 7 then
				coinLabel.Size = UDim2.new(1, 0, 0.7, 0)
			end
		else
			coinLabel.Text = "💰" .. formatNumber(cfg.Coins)
			coinLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
		end

		local statusIcon = Instance.new("TextLabel")
		statusIcon.Size = UDim2.new(1, 0, 0, 16)
		statusIcon.Position = UDim2.fromOffset(0, pos.h - 22)
		statusIcon.BackgroundTransparency = 1
		statusIcon.Text = ""
		statusIcon.TextSize = 12
		statusIcon.Font = Enum.Font.GothamBold
		statusIcon.Parent = cell

		local claimBtn = Instance.new("TextButton")
		claimBtn.Size = UDim2.new(1, 0, 1, 0)
		claimBtn.BackgroundTransparency = 1
		claimBtn.Text = ""
		claimBtn.Parent = cell
		local claimDay = day
		claimBtn.MouseButton1Click:Connect(function()
			local data = cachedData
			if not data then
				return
			end
			if not PlayerDataModule.CanClaimDay(data.SignInData, claimDay, data.FirstJoinTime) then
				return
			end
			local service = Knit.GetService("PlayerDataService")
			local ok = service:ClaimDailySignIn(claimDay)
			if ok then
				refreshSignInPanel()
			end
		end)

		signInDaySlots[day] = {
			cell = cell,
			dayLabel = dayLabel,
			coinLabel = coinLabel,
			statusIcon = statusIcon,
			claimBtn = claimBtn,
		}
	end

	local STATUS_Y = ROW2_Y + CELL_H + 14
	signInStatusLabel = Instance.new("TextLabel")
	signInStatusLabel.Size = UDim2.new(1, -20, 0, 26)
	signInStatusLabel.Position = UDim2.fromOffset(10, STATUS_Y)
	signInStatusLabel.BackgroundTransparency = 1
	signInStatusLabel.Text = ""
	signInStatusLabel.TextSize = 13
	signInStatusLabel.Font = Enum.Font.GothamBold
	signInStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
	signInStatusLabel.Parent = bg

	refreshSignInPanel()
	signInPanel = bg
end

local function createSignInTrigger(guiParent)
	local btn = Instance.new("TextButton")
	btn.Name = "SignInTrigger"
	btn.Size = UDim2.fromOffset(56, 40)
	btn.Position = UDim2.new(1, -60, 0.5, -20)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.Text = "签到"
	btn.TextColor3 = Color3.fromRGB(255, 215, 80)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.Parent = guiParent

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 50)
	stroke.Transparency = 0.7
	stroke.Thickness = 1
	stroke.Parent = btn

	btn.MouseButton1Click:Connect(toggleSignInPanel)
end

local function createHUD()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlayerHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromOffset(WIDTH, 104)
	container.Position = UDim2.new(1, -(WIDTH + 12), 0, 16)
	container.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
	container.BackgroundTransparency = 0.15
	container.BorderSizePixel = 0
	container.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.88
	stroke.Thickness = 1
	stroke.Parent = container

	local coinIcon = Instance.new("TextLabel")
	coinIcon.Size = UDim2.fromOffset(24, 24)
	coinIcon.Position = UDim2.fromOffset(12, 10)
	coinIcon.BackgroundTransparency = 1
	coinIcon.Text = "💰"
	coinIcon.TextColor3 = Color3.fromRGB(255, 200, 50)
	coinIcon.TextSize = 22
	coinIcon.Font = Enum.Font.GothamBold
	coinIcon.Parent = container

	coinValue = Instance.new("TextLabel")
	coinValue.Size = UDim2.fromOffset(90, 22)
	coinValue.Position = UDim2.fromOffset(42, 12)
	coinValue.BackgroundTransparency = 1
	coinValue.Text = "0"
	coinValue.TextColor3 = Color3.fromRGB(255, 215, 80)
	coinValue.TextSize = 20
	coinValue.Font = Enum.Font.GothamBold
	coinValue.TextXAlignment = Enum.TextXAlignment.Left
	coinValue.Parent = container

	local divider = Instance.new("Frame")
	divider.Size = UDim2.fromOffset(1, 28)
	divider.Position = UDim2.fromOffset(134, 8)
	divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	divider.BackgroundTransparency = 0.82
	divider.BorderSizePixel = 0
	divider.Parent = container

	local floorIcon = Instance.new("TextLabel")
	floorIcon.Size = UDim2.fromOffset(24, 24)
	floorIcon.Position = UDim2.fromOffset(152, 10)
	floorIcon.BackgroundTransparency = 1
	floorIcon.Text = "🗼"
	floorIcon.TextColor3 = Color3.fromRGB(90, 175, 255)
	floorIcon.TextSize = 20
	floorIcon.Font = Enum.Font.GothamBold
	floorIcon.Parent = container

	floorValue = Instance.new("TextLabel")
	floorValue.Size = UDim2.fromOffset(70, 22)
	floorValue.Position = UDim2.fromOffset(180, 12)
	floorValue.BackgroundTransparency = 1
	floorValue.Text = "1"
	floorValue.TextColor3 = Color3.fromRGB(140, 200, 255)
	floorValue.TextSize = 20
	floorValue.Font = Enum.Font.GothamBold
	floorValue.TextXAlignment = Enum.TextXAlignment.Left
	floorValue.Parent = container

	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, -(PAD * 2), 0, 1)
	sep.Position = UDim2.fromOffset(PAD, 44)
	sep.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sep.BackgroundTransparency = 0.88
	sep.BorderSizePixel = 0
	sep.Parent = container

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromOffset(80, 14)
	title.Position = UDim2.fromOffset(PAD, 50)
	title.BackgroundTransparency = 1
	title.Text = "在线奖励"
	title.TextColor3 = Color3.fromRGB(180, 180, 200)
	title.TextSize = 11
	title.Font = Enum.Font.Gotham
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = container

	progressTimer = Instance.new("TextLabel")
	progressTimer.Size = UDim2.fromOffset(100, 14)
	progressTimer.Position = UDim2.fromOffset(WIDTH - PAD - 100, 50)
	progressTimer.BackgroundTransparency = 1
	progressTimer.Text = "0:00 / 10:00"
	progressTimer.TextColor3 = Color3.fromRGB(180, 180, 200)
	progressTimer.TextSize = 11
	progressTimer.Font = Enum.Font.Gotham
	progressTimer.TextXAlignment = Enum.TextXAlignment.Right
	progressTimer.Parent = container

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.fromOffset(BAR_WIDTH, 6)
	barBg.Position = UDim2.fromOffset(PAD, 70)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	barBg.BorderSizePixel = 0
	barBg.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 3)
	barCorner.Parent = barBg

	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromOffset(0, 6)
	progressFill.BackgroundColor3 = Color3.fromRGB(255, 215, 80)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = progressFill

	local milestoneRow = Instance.new("Frame")
	milestoneRow.Size = UDim2.fromOffset(BAR_WIDTH, 20)
	milestoneRow.Position = UDim2.fromOffset(PAD, 80)
	milestoneRow.BackgroundTransparency = 1
	milestoneRow.BorderSizePixel = 0
	milestoneRow.Parent = container

	local maxTime = OnlineRewards[#OnlineRewards].Time
	for i, reward in OnlineRewards do
		local dot = Instance.new("Frame")
		dot.Name = "Milestone" .. i
		dot.Size = UDim2.fromOffset(8, 8)
		dot.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		dot.BorderSizePixel = 0
		dot.Parent = milestoneRow

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0, 4)
		dotCorner.Parent = dot

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromOffset(40, 14)
		lbl.Position = UDim2.fromOffset(-16, 10)
		lbl.BackgroundTransparency = 1
		lbl.Text = tostring(reward.Coins)
		lbl.TextColor3 = Color3.fromRGB(100, 100, 120)
		lbl.TextSize = 10
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.Parent = dot

		local x = math.floor((reward.Time / maxTime) * BAR_WIDTH) - 4
		dot.Position = UDim2.fromOffset(x, 0)

		milestoneDots[i] = dot
		milestoneLabels[i] = lbl
	end

	return gui
end

local function showRewardNotification(rewardTime, coins)
	local container = Instance.new("Frame")
	container.Name = "RewardToast"
	container.Size = UDim2.fromOffset(260, 60)
	container.Position = UDim2.new(0.5, -130, 0.5, -30)
	container.BackgroundColor3 = Color3.fromRGB(24, 24, 42)
	container.BackgroundTransparency = 0.15
	container.BorderSizePixel = 0
	container.Parent = notificationGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 80)
	stroke.Transparency = 0.6
	stroke.Thickness = 1.5
	stroke.Parent = container

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromOffset(28, 28)
	icon.Position = UDim2.fromOffset(14, 16)
	icon.BackgroundTransparency = 1
	icon.Text = "💰"
	icon.TextColor3 = Color3.fromRGB(255, 255, 255)
	icon.TextSize = 24
	icon.Font = Enum.Font.GothamBold
	icon.Parent = container

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -56, 0, 22)
	label.Position = UDim2.fromOffset(48, 10)
	label.BackgroundTransparency = 1
	label.Text = string.format("+%s 在线奖励", formatNumber(coins))
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 17
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local sublabel = Instance.new("TextLabel")
	sublabel.Size = UDim2.new(1, -56, 0, 16)
	sublabel.Position = UDim2.fromOffset(48, 34)
	sublabel.BackgroundTransparency = 1
	sublabel.Text = string.format("已在线 %s", formatTime(rewardTime))
	sublabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	sublabel.TextSize = 13
	sublabel.Font = Enum.Font.Gotham
	sublabel.TextXAlignment = Enum.TextXAlignment.Left
	sublabel.Parent = container

	local tween = TweenService
	local rise = tween:Create(container, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -130, 0, 20),
	})
	rise:Play()
	rise.Completed:Wait()

	task.wait(1)

	local fadeOut = tween:Create(container, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Wait()

	container:Destroy()
end

local function updateHUD(data)
	if not data then
		return
	end
	coinValue.Text = formatNumber(data.Coins)
	floorValue.Text = tostring(data.Floor)
end

local function updateProgress(elapsed, claimed)
	local maxTime = OnlineRewards[#OnlineRewards].Time

	local prevTime = 0
	local nextTime = maxTime
	for _, reward in OnlineRewards do
		if elapsed >= reward.Time then
			prevTime = reward.Time
		elseif nextTime == maxTime then
			nextTime = reward.Time
		end
	end

	progressTimer.Text = string.format("%s / %s", formatTimeCompact(elapsed), formatTimeCompact(maxTime))

	local segmentProgress = math.min((elapsed - prevTime) / (nextTime - prevTime), 1)
	local startX = (prevTime / maxTime) * BAR_WIDTH
	local segmentW = ((nextTime - prevTime) / maxTime) * BAR_WIDTH
	local targetWidth = math.floor(startX + segmentW * segmentProgress)

	if math.abs(progressFill.AbsoluteSize.X - targetWidth) > 1 then
		local tw = TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
			Size = UDim2.fromOffset(targetWidth, 6),
		})
		tw:Play()
	end

	for i, reward in OnlineRewards do
		local dot = milestoneDots[i]
		local lbl = milestoneLabels[i]
		local isClaimed = elapsed >= reward.Time
		dot.BackgroundColor3 = isClaimed and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(60, 60, 80)
		lbl.TextColor3 = isClaimed and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(100, 100, 120)
	end
end

function PlayerDataController:KnitStart()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = createHUD()
	gui.Parent = playerGui

	notificationGui = Instance.new("ScreenGui")
	notificationGui.Name = "RewardNotifications"
	notificationGui.ResetOnSpawn = false
	notificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	notificationGui.IgnoreGuiInset = true
	notificationGui.Parent = playerGui

	floaterGui = Instance.new("ScreenGui")
	floaterGui.Name = "CoinFloaters"
	floaterGui.ResetOnSpawn = false
	floaterGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	floaterGui.IgnoreGuiInset = true
	floaterGui.Parent = playerGui

	local gmGui = Instance.new("ScreenGui")
	gmGui.Name = "GMTool"
	gmGui.ResetOnSpawn = false
	gmGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gmGui.IgnoreGuiInset = true
	gmGui.Parent = playerGui

	createGMPanel(gmGui)
	createGMButton(gmGui)
	createSignInTrigger(gmGui)

	local signInGui = Instance.new("ScreenGui")
	signInGui.Name = "SignInPanel"
	signInGui.ResetOnSpawn = false
	signInGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	signInGui.IgnoreGuiInset = true
	signInGui.Parent = playerGui

	createSignInPanel(signInGui)

	player.CharacterAdded:Connect(function(char)
		createNameTag(char)
	end)
	if player.Character then
		createNameTag(player.Character)
	end

	local service = Knit.GetService("PlayerDataService")
	service.GetData:Connect(function(data)
		cachedData = data
		prevCoins = data.Coins
		updateHUD(data)
		refreshSignInPanel()
		refreshNameTag()
	end)
	service.DataChanged:Connect(function(data)
		cachedData = data
		local diff = data.Coins - prevCoins
		prevCoins = data.Coins
		updateHUD(data)
		refreshSignInPanel()
		refreshNameTag()
		if diff > 0 then
			task.spawn(showCoinFloater, diff)
			task.spawn(showHUDFloater, diff)
		end
	end)
	service.RewardGranted:Connect(function(rewardTime, coins)
		showRewardNotification(rewardTime, coins)
	end)
	service.RewardProgress:Connect(function(elapsed, claimed)
		updateProgress(elapsed, claimed)
	end)
end

function PlayerDataController:GetData()
	return cachedData
end

function PlayerDataController:ClaimDailySignIn(day)
	local service = Knit.GetService("PlayerDataService")
	return service:ClaimDailySignIn(day)
end

return PlayerDataController
