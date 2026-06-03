local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit
local SkillCarks = require(ReplicatedStorage.Shared.constants.SkillCarks)
local PlayerLevels = require(ReplicatedStorage.Shared.constants.PlayerLevels)

local SkillDeckController = Knit.CreateController {
	Name = "SkillDeckController",
}

local player = Players.LocalPlayer
local deckOpen = false
local deckPanel
local cardBtns = {}
local handSlots = {}
local handLabels = {}
local selectedHand = {}
local maxSlots = 4
local cachedHand = nil
local titleLabel, infoLabel, emptyBtn, emptyTip
local dataController

local NUMBERS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local OPS = { "+", "-", "*", "/" }

local SAFE_OP_NAME = {
	["+"] = "Add",
	["-"] = "Sub",
	["*"] = "Mul",
	["/"] = "Div",
}

local DISPLAY_OP = {
	["+"] = "+",
	["-"] = "-",
	["*"] = "*",
	["/"] = "÷",
}

local OP_COLORS = {
	["+"] = Color3.fromRGB(100, 200, 120),
	["-"] = Color3.fromRGB(255, 140, 100),
	["*"] = Color3.fromRGB(100, 160, 255),
	["/"] = Color3.fromRGB(200, 140, 255),
}

local function getCardIndex(op, n)
	return (table.find(OPS, op) - 1) * 9 + n
end

local function tableContains(t, v)
	for _, x in t do
		if x == v then
			return true
		end
	end
	return false
end

local function tableRemoveValue(t, v)
	for i = #t, 1, -1 do
		if t[i] == v then
			table.remove(t, i)
		end
	end
end

local function updateSelectionHighlight()
	for idx, btn in cardBtns do
		if btn then
			if tableContains(selectedHand, idx) then
				btn.BackgroundTransparency = 0
				btn.BorderSizePixel = 2
				btn.BorderColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.BackgroundTransparency = 0.55
				btn.BorderSizePixel = 0
			end
		end
	end

	for i = 1, maxSlots do
		local slot = handSlots[i]
		local lbl = handLabels[i]
		if not slot then
			continue
		end
		if i <= #selectedHand then
			local cardIdx = selectedHand[i]
			local card = SkillCarks.All[cardIdx]
			if card then
				slot.BackgroundTransparency = 0.15
				slot.BackgroundColor3 = OP_COLORS[card.operator] or Color3.fromRGB(255, 215, 80)
				lbl.Text = card.display
				lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		else
			slot.BackgroundTransparency = 0.8
			slot.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
			lbl.Text = "空"
			lbl.TextColor3 = Color3.fromRGB(100, 100, 130)
		end
	end

	local filled = #selectedHand
	if filled >= maxSlots then
		emptyBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
		emptyBtn.BackgroundTransparency = 0.5
	else
		emptyBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		emptyBtn.BackgroundTransparency = 0.2
	end
end

local function toggleCard(cardIndex)
	if tableContains(selectedHand, cardIndex) then
		tableRemoveValue(selectedHand, cardIndex)
	else
		if #selectedHand >= maxSlots then
			return
		end
		table.insert(selectedHand, cardIndex)
	end
	updateSelectionHighlight()
end

local function clearHand()
	selectedHand = {}
	updateSelectionHighlight()
end

local function saveHand()
	local service = Knit.GetService("PlayerDataService")
	local res, ok = pcall(function()
		return service:SaveSkillHand(selectedHand):expect()
	end)
	if res and ok then
		local dataController = Knit.GetController("PlayerDataController")
		if dataController then
			local data = dataController:GetData()
			if data then
				data.SkillHand = { table.unpack(selectedHand) }
				cachedHand = data.SkillHand
			end
		end
		deckPanel.Visible = false
		deckOpen = false
	end
end

local function loadHandFromData(data)
	if not data then
		return
	end
	local hand = data.SkillHand
	if not hand or type(hand) ~= "table" or #hand == 0 then
		local level = data.PlayerLevel or 1
		local cfg = PlayerLevels[level]
		local slots = cfg and cfg.SkillSlots or 4
		local defaults = {}
		local defaultIndices = { 1, 10, 20, 29 }
		for i = 1, math.min(slots, #defaultIndices) do
			table.insert(defaults, defaultIndices[i])
		end
		data.SkillHand = defaults
		hand = defaults
	end

	local level = data.PlayerLevel or 1
	local cfg = PlayerLevels[level]
	maxSlots = cfg and cfg.SkillSlots or 4

	cachedHand = hand
	selectedHand = {}
	for _, v in hand do
		if v >= 1 and v <= #SkillCarks.All then
			table.insert(selectedHand, v)
		end
	end
	if #selectedHand > maxSlots then
		local trimmed = {}
		for i = 1, maxSlots do
			table.insert(trimmed, selectedHand[i])
		end
		selectedHand = trimmed
	end

	local levelCfg = PlayerLevels[level]
	local displayName = levelCfg and levelCfg.DisplayName or "Lv." .. tostring(level)
	infoLabel.Text = displayName .. " - 可选" .. tostring(maxSlots) .. "张手牌"
end

local function createPanel(guiParent)
	local W = 520
	local H = 480

	deckPanel = Instance.new("Frame")
	deckPanel.Name = "SkillDeckPanel"
	deckPanel.Size = UDim2.fromOffset(W, H)
	deckPanel.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
	deckPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 34)
	deckPanel.BackgroundTransparency = 0.08
	deckPanel.BorderSizePixel = 0
	deckPanel.Visible = false
	deckPanel.Parent = guiParent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = deckPanel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 80)
	stroke.Transparency = 0.6
	stroke.Thickness = 1.5
	stroke.Parent = deckPanel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -20, 0, 36)
	titleLabel.Position = UDim2.fromOffset(10, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "技能牌库"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 20
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = deckPanel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.fromOffset(28, 28)
	closeBtn.Position = UDim2.new(1, -36, 0, 10)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = deckPanel
	closeBtn.MouseButton1Click:Connect(function()
		deckPanel.Visible = false
		deckOpen = false
	end)

	infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Size = UDim2.new(1, -20, 0, 22)
	infoLabel.Position = UDim2.fromOffset(10, 46)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "普通玩家 - 可选4张手牌"
	infoLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	infoLabel.TextSize = 13
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = deckPanel

	local sep = Instance.new("Frame")
	sep.Name = "Separator"
	sep.Size = UDim2.new(1, -20, 0, 1)
	sep.Position = UDim2.fromOffset(10, 72)
	sep.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sep.BackgroundTransparency = 0.85
	sep.BorderSizePixel = 0
	sep.Parent = deckPanel

	local OP_LABEL_W = 22
	local CARD_W = 42
	local CARD_GAP = 6
	local GRID_START_X = 16
	local GRID_START_Y = 82
	local ROW_HEIGHT = 36
	local ROW_GAP = 10

	local opLabelPos = {
		["+"] = GRID_START_Y,
		["-"] = GRID_START_Y + (ROW_HEIGHT + ROW_GAP),
		["*"] = GRID_START_Y + 2 * (ROW_HEIGHT + ROW_GAP),
		["/"] = GRID_START_Y + 3 * (ROW_HEIGHT + ROW_GAP),
	}

	for _, op in OPS do
		local opLabel = Instance.new("TextLabel")
		opLabel.Name = "OpLabel" .. SAFE_OP_NAME[op]
		opLabel.Size = UDim2.fromOffset(OP_LABEL_W, ROW_HEIGHT)
		opLabel.Position = UDim2.fromOffset(GRID_START_X, opLabelPos[op])
		opLabel.BackgroundTransparency = 1
		opLabel.Text = DISPLAY_OP[op]
		opLabel.TextColor3 = OP_COLORS[op]
		opLabel.TextSize = 22
		opLabel.Font = Enum.Font.GothamBold
		opLabel.TextXAlignment = Enum.TextXAlignment.Center
		opLabel.Parent = deckPanel

		for _, n in NUMBERS do
			local idx = getCardIndex(op, n)
			local col = n
			local x = GRID_START_X + OP_LABEL_W + 4 + (col - 1) * (CARD_W + CARD_GAP)
			local y = opLabelPos[op]

			local btn = Instance.new("TextButton")
			btn.Name = "CardBtn" .. idx
			btn.Size = UDim2.fromOffset(CARD_W, ROW_HEIGHT)
			btn.Position = UDim2.fromOffset(x, y)
			btn.BackgroundColor3 = OP_COLORS[op]
			btn.BackgroundTransparency = 0.55
			btn.BorderSizePixel = 0
			btn.Text = DISPLAY_OP[op] .. tostring(n)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextSize = 14
			btn.Font = Enum.Font.GothamBold
			btn.Parent = deckPanel

			local cCorner = Instance.new("UICorner")
			cCorner.Name = "Corner" .. idx
			cCorner.CornerRadius = UDim.new(0, 5)
			cCorner.Parent = btn

			btn.MouseButton1Click:Connect(function()
				toggleCard(idx)
			end)

			cardBtns[idx] = btn
		end
	end

	local HAND_PREVIEW_Y = GRID_START_Y + 4 * (ROW_HEIGHT + ROW_GAP) + 12
	local handLabel = Instance.new("TextLabel")
	handLabel.Name = "HandTitle"
	handLabel.Size = UDim2.fromOffset(80, 20)
	handLabel.Position = UDim2.fromOffset(GRID_START_X, HAND_PREVIEW_Y)
	handLabel.BackgroundTransparency = 1
	handLabel.Text = "当前手牌:"
	handLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	handLabel.TextSize = 13
	handLabel.Font = Enum.Font.Gotham
	handLabel.TextXAlignment = Enum.TextXAlignment.Left
	handLabel.Parent = deckPanel

	local SLOT_W = 46
	local SLOT_GAP = 6
	local SLOT_START_X = GRID_START_X + 76

	handSlots = {}
	handLabels = {}
	for i = 1, 10 do
		local x = SLOT_START_X + (i - 1) * (SLOT_W + SLOT_GAP)
		local slot = Instance.new("Frame")
		slot.Name = "HandSlot" .. i
		slot.Size = UDim2.fromOffset(SLOT_W, ROW_HEIGHT)
		slot.Position = UDim2.fromOffset(x, HAND_PREVIEW_Y)
		slot.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		slot.BackgroundTransparency = 0.8
		slot.BorderSizePixel = 0
		slot.Visible = false
		slot.Parent = deckPanel

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 5)
		sCorner.Parent = slot

		local lbl = Instance.new("TextLabel")
		lbl.Name = "HandLabel" .. i
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "空"
		lbl.TextColor3 = Color3.fromRGB(100, 100, 130)
		lbl.TextSize = 14
		lbl.Font = Enum.Font.GothamBold
		lbl.Parent = slot

		handSlots[i] = slot
		handLabels[i] = lbl
	end

	local BUTTON_Y = HAND_PREVIEW_Y + ROW_HEIGHT + 14
	local SAVE_BTN_W = 120
	local CLEAR_BTN_W = 90
	local CANCEL_BTN_W = 90
	local totalBtnW = SAVE_BTN_W + CLEAR_BTN_W + CANCEL_BTN_W + 20
	local btnStartX = (W - totalBtnW) / 2

	local saveBtn = Instance.new("TextButton")
	saveBtn.Name = "SaveBtn"
	saveBtn.Size = UDim2.fromOffset(SAVE_BTN_W, 36)
	saveBtn.Position = UDim2.fromOffset(btnStartX, BUTTON_Y)
	saveBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	saveBtn.BackgroundTransparency = 0.2
	saveBtn.BorderSizePixel = 0
	saveBtn.Text = "保存手牌"
	saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	saveBtn.TextSize = 16
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.Parent = deckPanel

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = saveBtn

	saveBtn.MouseButton1Click:Connect(function()
		saveHand()
	end)

	emptyBtn = Instance.new("TextButton")
	emptyBtn.Name = "EmptyBtn"
	emptyBtn.Size = UDim2.fromOffset(CLEAR_BTN_W, 36)
	emptyBtn.Position = UDim2.fromOffset(btnStartX + SAVE_BTN_W + 10, BUTTON_Y)
	emptyBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	emptyBtn.BackgroundTransparency = 0.2
	emptyBtn.BorderSizePixel = 0
	emptyBtn.Text = "清空"
	emptyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	emptyBtn.TextSize = 16
	emptyBtn.Font = Enum.Font.GothamBold
	emptyBtn.Parent = deckPanel

	local eCorner = Instance.new("UICorner")
	eCorner.CornerRadius = UDim.new(0, 8)
	eCorner.Parent = emptyBtn

	emptyBtn.MouseButton1Click:Connect(function()
		clearHand()
	end)

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Name = "CancelBtn"
	cancelBtn.Size = UDim2.fromOffset(CANCEL_BTN_W, 36)
	cancelBtn.Position = UDim2.fromOffset(btnStartX + SAVE_BTN_W + CLEAR_BTN_W + 20, BUTTON_Y)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
	cancelBtn.BackgroundTransparency = 0.3
	cancelBtn.BorderSizePixel = 0
	cancelBtn.Text = "取消"
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextSize = 16
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.Parent = deckPanel

	local cncCorner = Instance.new("UICorner")
	cncCorner.CornerRadius = UDim.new(0, 8)
	cncCorner.Parent = cancelBtn

	cancelBtn.MouseButton1Click:Connect(function()
		deckPanel.Visible = false
		deckOpen = false
		local data = dataController and dataController:GetData()
		if data then
			loadHandFromData(data)
		end
		updateSelectionHighlight()
	end)

	emptyTip = Instance.new("TextLabel")
	emptyTip.Name = "EmptyTip"
	emptyTip.Size = UDim2.new(1, -20, 0, 18)
	emptyTip.Position = UDim2.fromOffset(10, BUTTON_Y + 40)
	emptyTip.BackgroundTransparency = 1
	emptyTip.Text = ""
	emptyTip.TextColor3 = Color3.fromRGB(255, 180, 80)
	emptyTip.TextSize = 12
	emptyTip.Font = Enum.Font.Gotham
	emptyTip.TextXAlignment = Enum.TextXAlignment.Center
	emptyTip.Parent = deckPanel
end

local function toggleDeck()
	deckOpen = not deckOpen
	if deckOpen then
		local data = dataController and dataController:GetData()
		loadHandFromData(data)
		updateSelectionHighlight()
		for i = 1, 10 do
			local slot = handSlots[i]
			if slot then
				slot.Visible = i <= maxSlots
			end
		end
		deckPanel.Visible = true
	else
		deckPanel.Visible = false
	end
end

function SkillDeckController:KnitStart()
	dataController = Knit.GetController("PlayerDataController")
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillDeckUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	createPanel(gui)

	local triggerBtn = Instance.new("TextButton")
	triggerBtn.Name = "SkillDeckTrigger"
	triggerBtn.Size = UDim2.fromOffset(56, 40)
	triggerBtn.Position = UDim2.new(1, -60, 0.5, 72)
	triggerBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	triggerBtn.BackgroundTransparency = 0.15
	triggerBtn.BorderSizePixel = 0
	triggerBtn.Text = "卡牌"
	triggerBtn.TextColor3 = Color3.fromRGB(255, 215, 80)
	triggerBtn.TextSize = 14
	triggerBtn.Font = Enum.Font.GothamBold
	triggerBtn.Parent = gui

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = triggerBtn

	local stroke2 = Instance.new("UIStroke")
	stroke2.Color = Color3.fromRGB(255, 200, 50)
	stroke2.Transparency = 0.7
	stroke2.Thickness = 1
	stroke2.Parent = triggerBtn

	triggerBtn.MouseButton1Click:Connect(toggleDeck)

	local dataService = Knit.GetService("PlayerDataService")
	dataService.DataChanged:Connect(function(data)
		if deckOpen then
			loadHandFromData(data)
			updateSelectionHighlight()
			for i = 1, 10 do
				local slot = handSlots[i]
				if slot then
					slot.Visible = i <= maxSlots
				end
			end
		end
	end)
end

function SkillDeckController:GetSkillHand()
	return cachedHand or { 1, 10, 20, 29 }
end

return SkillDeckController
