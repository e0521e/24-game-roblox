local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local U3 = require(ReplicatedStorage.Shared.DataStructures.U3)
local Knit = U3.Knit
local Questions = require(ReplicatedStorage.Shared.constants.Questions)

local GameController = Knit.CreateController {
	Name = "GameController",
}

local player = Players.LocalPlayer
	local panel, cardSlots, cardBtns, skillSlots
local startBtn, submitBtn, nextBtn, exitBtn, panelTitle
local resultFrame, formulaLabel, resultStatus, nextBtn
local commentScroll, commentInput, commentList
local selectedCard = nil
local selectedSkill = nil
local currentQuestion = nil
local currentFloor = nil
local submitCooldown = false

local SKILL_DISPLAY = { "+1", "-1", "*2", "/2" }
local SKILL_APPLY = {
	function(v) return v + 1 end,
	function(v) return v - 1 end,
	function(v) return v * 2 end,
	function(v) return math.floor(v / 2) end,
}
local CARD_COLORS = {
	Color3.fromRGB(100, 150, 255),
	Color3.fromRGB(100, 200, 150),
	Color3.fromRGB(255, 180, 80),
	Color3.fromRGB(200, 120, 255),
}

local function clearSelection()
	for _, s in cardSlots do
		if s then
			s.BorderSizePixel = 0
			s.BackgroundTransparency = 0.4
			s.Size = UDim2.fromOffset(80, 100)
		end
	end
	for _, s in skillSlots do
		if s then
			s.BorderSizePixel = 0
			s.BackgroundTransparency = 0.3
		end
	end
end

local function updateSelection()
	clearSelection()
	if selectedCard then
		local s = cardSlots[selectedCard]
		if s then
			s.BorderSizePixel = 3
			s.BorderColor3 = Color3.fromRGB(255, 255, 255)
			s.BackgroundTransparency = 0
			local tw = TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(88, 108),
			})
			tw:Play()
		end
	end
	if selectedSkill then
		local s = skillSlots[selectedSkill]
		if s then
			s.BorderSizePixel = 2
			s.BorderColor3 = Color3.fromRGB(255, 255, 255)
			s.BackgroundTransparency = 0
		end
	end
end

local function buildFormula(nums, cardIdx, skillIdx, total)
	local parts = {}
	for i, v in nums do
		if cardIdx == i and skillIdx then
			local skillFn = SKILL_APPLY[skillIdx]
			local newV = skillFn and skillFn(v) or v
			table.insert(parts, tostring(v) .. "→" .. tostring(newV) .. "(" .. SKILL_DISPLAY[skillIdx] .. ")")
		else
			table.insert(parts, tostring(v))
		end
	end
	return table.concat(parts, " + ") .. " = " .. total
end

local function showResultPanel(nums, cardIdx, skillIdx, total, correct)
	if correct then
		local formula = buildFormula(nums, cardIdx, skillIdx, total)
		formulaLabel.Text = formula .. "  ✅  正确! Floor+1"
		formulaLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		submitBtn.Visible = false
		nextBtn.Visible = true
	else
		formulaLabel.Text = "❌  " .. total .. " ≠ 24"
		formulaLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
		submitBtn.Visible = true
		nextBtn.Visible = false
	end
	resultFrame.Visible = true
end

local function hideResultPanel()
	resultFrame.Visible = false
	submitBtn.Visible = true
	nextBtn.Visible = false
end

local function submitAnswer()
	if not currentQuestion or submitCooldown then
		return
	end
	local nums = currentQuestion.numbers
	local total = 0
	for _, v in nums do
		total = total + v
	end
	if selectedCard and selectedSkill then
		local skillFn = SKILL_APPLY[selectedSkill]
		if skillFn then
			total = total - nums[selectedCard] + skillFn(nums[selectedCard])
		end
	end
	local service = Knit.GetService("GameService")
	local res, ok, msg = pcall(function()
		return service:SubmitAnswer(selectedCard, selectedSkill):expect()
	end)
	if not res or not ok then
		ok = false
		msg = tostring(msg or "提交失败")
	end
	if ok then
		currentFloor = currentQuestion.floor + 1
		showResultPanel(nums, selectedCard, selectedSkill, total, true)
	else
		showResultPanel(nums, selectedCard, selectedSkill, total, false)
		clearSelection()
		submitCooldown = true
		submitBtn.BackgroundTransparency = 0.6
		submitBtn.Text = "冷却中 5s"
		task.spawn(function()
			for i = 4, 1, -1 do
				task.wait(1)
				submitBtn.Text = "冷却中 " .. i .. "s"
			end
			submitBtn.Text = "通过"
			submitBtn.BackgroundTransparency = 0.2
			submitCooldown = false
		end)
	end
end

local function loadComments(comments)
	for _, child in commentScroll:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	if type(comments) ~= "table" or #comments == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -8, 0, 20)
		empty.Position = UDim2.fromOffset(4, 4)
		empty.BackgroundTransparency = 1
		empty.Text = "暂无评论"
		empty.TextColor3 = Color3.fromRGB(100, 100, 130)
		empty.TextSize = 13
		empty.Font = Enum.Font.Gotham
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Parent = commentScroll
		return
	end

	for i, c in comments do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -8, 0, 20)
		label.BackgroundTransparency = 1
		label.Text = c.PlayerName .. ": " .. c.Text
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 13
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.LayoutOrder = i
		label.Parent = commentScroll
	end
end

local function startNewQuestion()
	local floorNum = currentFloor
	if not floorNum then
		local dataController = Knit.GetController("PlayerDataController")
		local playerData = dataController:GetData()
		floorNum = (playerData and playerData.Floor) or 1
		currentFloor = floorNum
	end
	if not Questions or #Questions == 0 then
		return
	end
	local idx = math.min(floorNum, #Questions)
	local question = Questions[idx]
	if not question or not question.numbers or #question.numbers == 0 then
		question = { numbers = {24} }
	end
	local nums = question.numbers
	currentQuestion = { numbers = nums, floor = floorNum }
	selectedCard = nil
	selectedSkill = nil
	submitCooldown = false
	panel.Visible = true
	hideResultPanel()
	clearSelection()

	panelTitle.Text = "第 " .. floorNum .. " 题 - 24点"

	for i = 1, 4 do
		local slot = cardSlots[i]
		if not slot then
		elseif i <= #nums then
			slot.Visible = true
			slot.Size = UDim2.fromOffset(80, 100)
			local btn = cardBtns[i]
			if btn then
				btn.Text = tostring(nums[i])
			end
			slot.BackgroundColor3 = CARD_COLORS[i]
			slot.BackgroundTransparency = 0.4
		else
			slot.Visible = false
		end
	end

	submitBtn.Text = (floorNum == 1) and "通过 (24)" or "通过"
	submitBtn.BackgroundTransparency = 0.2

	local commentService = Knit.GetService("CommentService")
	local res, comments = pcall(function()
		return commentService:GetComments(floorNum):expect()
	end)
	if res and comments then
		loadComments(comments)
	end
end

local function createUI()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "GameUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	startBtn = Instance.new("TextButton")
	startBtn.Name = "StartBtn"
	startBtn.Size = UDim2.fromOffset(56, 40)
	startBtn.Position = UDim2.new(1, -60, 0.5, -66)
	startBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	startBtn.BackgroundTransparency = 0.15
	startBtn.BorderSizePixel = 0
	startBtn.Text = "答题"
	startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	startBtn.TextSize = 16
	startBtn.Font = Enum.Font.GothamBold
	startBtn.Parent = gui

	local sBtnCorner = Instance.new("UICorner")
	sBtnCorner.CornerRadius = UDim.new(0, 8)
	sBtnCorner.Parent = startBtn

	panel = Instance.new("Frame")
	panel.Name = "QuestionPanel"
	panel.Size = UDim2.fromOffset(560, 420)
	panel.Position = UDim2.new(0.5, -280, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 34)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 14)
	pCorner.Parent = panel

	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(255, 255, 255)
	pStroke.Transparency = 0.88
	pStroke.Thickness = 1
	pStroke.Parent = panel

	panelTitle = Instance.new("TextLabel")
	panelTitle.Size = UDim2.new(1, 0, 0, 32)
	panelTitle.Position = UDim2.fromOffset(0, 8)
	panelTitle.BackgroundTransparency = 1
	panelTitle.Text = "24点 答题"
	panelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	panelTitle.TextSize = 18
	panelTitle.Font = Enum.Font.GothamBold
	panelTitle.Parent = panel

	-- Card slots
	cardSlots = {}
	cardBtns = {}
	local CARD_Y = 50
	local CARD_W = 80
	local CARD_H = 100
	local CARD_GAP = 16
	local totalW = 4 * CARD_W + 3 * CARD_GAP
	local startX = (560 - totalW) / 2 - 40
	if startX < 10 then startX = 10 end

	for i = 1, 4 do
		local x = startX + (i - 1) * (CARD_W + CARD_GAP)
		local slot = Instance.new("Frame")
		slot.Name = "CardSlot_" .. i
		slot.Size = UDim2.fromOffset(CARD_W, CARD_H)
		slot.Position = UDim2.fromOffset(x, CARD_Y)
		slot.BackgroundColor3 = CARD_COLORS[i]
		slot.BackgroundTransparency = 0.4
		slot.BorderSizePixel = 0
		slot.Parent = panel

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 8)
		sCorner.Parent = slot

		local numLabel = Instance.new("TextLabel")
		numLabel.Name = "NumLabel"
		numLabel.Size = UDim2.new(1, 0, 1, 0)
		numLabel.BackgroundTransparency = 1
		numLabel.Text = ""
		numLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		numLabel.TextSize = 48
		numLabel.TextScaled = true
		numLabel.Font = Enum.Font.GothamBold
		numLabel.Parent = slot

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextSize = 48
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = slot
		local cardIdx = i
		btn.MouseButton1Click:Connect(function()
			local q = currentQuestion
			if q and q.numbers and cardIdx <= #q.numbers then
				if selectedCard == cardIdx then
					selectedCard = nil
				else
					selectedCard = cardIdx
				end
				updateSelection()
			end
		end)

		cardSlots[i] = slot
		cardBtns[i] = btn
	end

	-- Skill slots
	local SKILL_Y = 170
	local skillLabel = Instance.new("TextLabel")
	skillLabel.Size = UDim2.fromOffset(100, 20)
	skillLabel.Position = UDim2.fromOffset(startX, SKILL_Y - 4)
	skillLabel.BackgroundTransparency = 1
	skillLabel.Text = "技能:"
	skillLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	skillLabel.TextSize = 14
	skillLabel.Font = Enum.Font.Gotham
	skillLabel.TextXAlignment = Enum.TextXAlignment.Left
	skillLabel.Parent = panel

	skillSlots = {}
	local SKILL_W = 60
	local SKILL_GAP = 12
	local skillStartX = startX
	for i = 1, 4 do
		local slot = Instance.new("Frame")
		slot.Name = "SkillSlot_" .. i
		slot.Size = UDim2.fromOffset(SKILL_W, 36)
		slot.Position = UDim2.fromOffset(skillStartX + (i - 1) * (SKILL_W + SKILL_GAP), SKILL_Y)
		slot.BackgroundColor3 = Color3.fromRGB(255, 215, 80)
		slot.BackgroundTransparency = 0.3
		slot.BorderSizePixel = 0
		slot.Parent = panel

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 6)
		sCorner.Parent = slot

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = SKILL_DISPLAY[i]
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 16
		label.Font = Enum.Font.GothamBold
		label.Parent = slot

		local idx = i
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Parent = slot
		btn.MouseButton1Click:Connect(function()
			if selectedSkill == idx then
				selectedSkill = nil
			else
				selectedSkill = idx
			end
			updateSelection()
		end)

		skillSlots[i] = slot
	end

	-- Result text (above buttons, left-aligned)
	resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultFrame"
	resultFrame.Size = UDim2.new(1, -(startX * 2), 0, 30)
	resultFrame.Position = UDim2.fromOffset(startX, 220)
	resultFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	resultFrame.BackgroundTransparency = 0.2
	resultFrame.BorderSizePixel = 0
	resultFrame.Visible = false
	resultFrame.Parent = panel

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 6)
	rCorner.Parent = resultFrame

	formulaLabel = Instance.new("TextLabel")
	formulaLabel.Name = "ResultText"
	formulaLabel.Size = UDim2.new(1, -12, 1, 0)
	formulaLabel.Position = UDim2.fromOffset(6, 0)
	formulaLabel.BackgroundTransparency = 1
	formulaLabel.Text = ""
	formulaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	formulaLabel.TextSize = 15
	formulaLabel.Font = Enum.Font.GothamBold
	formulaLabel.TextXAlignment = Enum.TextXAlignment.Left
	formulaLabel.TextYAlignment = Enum.TextYAlignment.Center
	formulaLabel.Parent = resultFrame

	resultStatus = formulaLabel

	-- Comment section
	local commentLabel = Instance.new("TextLabel")
	commentLabel.Size = UDim2.fromOffset(100, 18)
	commentLabel.Position = UDim2.fromOffset(startX, 254)
	commentLabel.BackgroundTransparency = 1
	commentLabel.Text = "玩家评论:"
	commentLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	commentLabel.TextSize = 12
	commentLabel.Font = Enum.Font.Gotham
	commentLabel.TextXAlignment = Enum.TextXAlignment.Left
	commentLabel.Parent = panel

	commentScroll = Instance.new("ScrollingFrame")
	commentScroll.Size = UDim2.new(1, -(startX * 2 + 4), 0, 64)
	commentScroll.Position = UDim2.fromOffset(startX, 274)
	commentScroll.BackgroundColor3 = Color3.fromRGB(22, 22, 40)
	commentScroll.BackgroundTransparency = 0.4
	commentScroll.BorderSizePixel = 0
	commentScroll.ScrollBarThickness = 4
	commentScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
	commentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	commentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	commentScroll.Parent = panel

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 6)
	cCorner.Parent = commentScroll

	commentList = Instance.new("UIListLayout")
	commentList.Padding = UDim.new(0, 4)
	commentList.SortOrder = Enum.SortOrder.LayoutOrder
	commentList.Parent = commentScroll

	local commentInputBg = Instance.new("Frame")
	commentInputBg.Size = UDim2.new(1, -(startX * 2 + 4), 0, 28)
	commentInputBg.Position = UDim2.fromOffset(startX, 342)
	commentInputBg.BackgroundColor3 = Color3.fromRGB(22, 22, 40)
	commentInputBg.BackgroundTransparency = 0.3
	commentInputBg.BorderSizePixel = 0
	commentInputBg.Parent = panel

	local ciCorner = Instance.new("UICorner")
	ciCorner.CornerRadius = UDim.new(0, 6)
	ciCorner.Parent = commentInputBg

	commentInput = Instance.new("TextBox")
	commentInput.Size = UDim2.new(1, -52, 1, -2)
	commentInput.Position = UDim2.fromOffset(4, 1)
	commentInput.BackgroundTransparency = 1
	commentInput.PlaceholderText = "输入评论..."
	commentInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 150)
	commentInput.Text = ""
	commentInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	commentInput.TextSize = 14
	commentInput.Font = Enum.Font.Gotham
	commentInput.TextXAlignment = Enum.TextXAlignment.Left
	commentInput.ClearTextOnFocus = false
	commentInput.Parent = commentInputBg

	local sendBtn = Instance.new("TextButton")
	sendBtn.Size = UDim2.fromOffset(42, 28)
	sendBtn.Position = UDim2.new(1, -42, 0, 0)
	sendBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	sendBtn.BackgroundTransparency = 0.2
	sendBtn.BorderSizePixel = 0
	sendBtn.Text = "发送"
	sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sendBtn.TextSize = 12
	sendBtn.Font = Enum.Font.GothamBold
	sendBtn.Parent = commentInputBg

	local sCorner2 = Instance.new("UICorner")
	sCorner2.CornerRadius = UDim.new(0, 5)
	sCorner2.Parent = sendBtn

	sendBtn.MouseButton1Click:Connect(function()
		local text = commentInput.Text
		if #text > 0 then
			local service = Knit.GetService("CommentService")
			local res, ok, comments = pcall(function()
				return service:AddComment(currentFloor, text):expect()
			end)
			if res and ok then
				commentInput.Text = ""
				if comments then
					loadComments(comments)
				end
			end
		end
	end)

	-- Bottom button row
	local BTN_W = 120
	local BTN_H = 40
	local BTN_GAP = 16
	local rowW = 3 * BTN_W + 2 * BTN_GAP
	local rowX = (560 - rowW) / 2

	submitBtn = Instance.new("TextButton")
	submitBtn.Name = "SubmitBtn"
	submitBtn.Size = UDim2.fromOffset(BTN_W, BTN_H)
	submitBtn.Position = UDim2.new(0, rowX, 1, -BTN_H - 12)
	submitBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	submitBtn.BackgroundTransparency = 0.2
	submitBtn.BorderSizePixel = 0
	submitBtn.Text = "通过"
	submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	submitBtn.TextSize = 18
	submitBtn.Font = Enum.Font.GothamBold
	submitBtn.Parent = panel

	local sbCorner = Instance.new("UICorner")
	sbCorner.CornerRadius = UDim.new(0, 8)
	sbCorner.Parent = submitBtn

	nextBtn = Instance.new("TextButton")
	nextBtn.Name = "NextBtn"
	nextBtn.Size = UDim2.fromOffset(BTN_W, BTN_H)
	nextBtn.Position = UDim2.new(0, rowX + BTN_W + BTN_GAP, 1, -BTN_H - 12)
	nextBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
	nextBtn.BackgroundTransparency = 0.2
	nextBtn.BorderSizePixel = 0
	nextBtn.Text = "下一题"
	nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextBtn.TextSize = 18
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.Visible = false
	nextBtn.Parent = panel

	local nCorner2 = Instance.new("UICorner")
	nCorner2.CornerRadius = UDim.new(0, 8)
	nCorner2.Parent = nextBtn

	exitBtn = Instance.new("TextButton")
	exitBtn.Name = "ExitBtn"
	exitBtn.Size = UDim2.fromOffset(BTN_W, BTN_H)
	exitBtn.Position = UDim2.new(0, rowX + 2 * (BTN_W + BTN_GAP), 1, -BTN_H - 12)
	exitBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	exitBtn.BackgroundTransparency = 0.2
	exitBtn.BorderSizePixel = 0
	exitBtn.Text = "退出"
	exitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	exitBtn.TextSize = 18
	exitBtn.Font = Enum.Font.GothamBold
	exitBtn.Parent = panel

	local eCorner = Instance.new("UICorner")
	eCorner.CornerRadius = UDim.new(0, 8)
	eCorner.Parent = exitBtn

	startBtn.MouseButton1Click:Connect(function()
		startNewQuestion()
	end)
	submitBtn.MouseButton1Click:Connect(function()
		submitAnswer()
	end)
	nextBtn.MouseButton1Click:Connect(function()
		startNewQuestion()
	end)
	exitBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
		hideResultPanel()
		clearSelection()
	end)
end

function GameController:KnitStart()
	createUI()
end

return GameController
