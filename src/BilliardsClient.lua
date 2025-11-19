-- ═══════════════════════════════════════════════════════════
--  🎱 PREMIUM BILLIARDS CLIENT
--  Modern UI with Smooth Animations
--  Author: GitHub Copilot
--  Date: 2025-11-19
-- ═══════════════════════════════════════════════════════════

print("🎱 ═══════════════════════════════════════")
print("   PREMIUM BILLIARDS CLIENT LOADING")
print("🎱 ═══════════════════════════════════════")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ SERVICES & REFERENCES ═══
local system = ReplicatedStorage:WaitForChild("BilliardsSystem", 30)
if not system then 
	warn("❌ BilliardsSystem not found!") 
	return 
end

local remoteFolder = system:WaitForChild("RemoteEvents", 10)
local joinQueueRemote = remoteFolder:WaitForChild("Billiards_JoinQueue")
local startMatchRemote = remoteFolder:WaitForChild("Billiards_StartMatch")
local shotRemote = remoteFolder:WaitForChild("Billiards_Shot")
local updateStateRemote = remoteFolder:WaitForChild("Billiards_UpdateState")

-- ═══ COLOR PALETTE ═══
local COLORS = {
	Background = Color3.fromRGB(26, 26, 46),
	BackgroundDark = Color3.fromRGB(22, 33, 62),
	Felt = Color3.fromRGB(15, 81, 50),
	FeltLight = Color3.fromRGB(20, 100, 60),
	Wood = Color3.fromRGB(101, 67, 33),
	CueWood = Color3.fromRGB(139, 69, 19),
	CueWoodLight = Color3.fromRGB(160, 82, 45),
	PowerYellow = Color3.fromRGB(255, 217, 61),
	PowerRed = Color3.fromRGB(255, 107, 107),
	PowerBg = Color3.fromRGB(45, 45, 68),
	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(0, 0, 0),
	Shadow = Color3.fromRGB(0, 0, 0)
}

-- ═══ UI REFERENCES ═══
local billiardsUI = system.UI:Clone()
billiardsUI.Parent = playerGui
billiardsUI.Enabled = false

local mainFrame = billiardsUI:WaitForChild("MainFrame")
local tableFrame = mainFrame:WaitForChild("TableFrame")
local powerBarContainer = mainFrame:WaitForChild("PowerBarContainer")
local powerBarFill = powerBarContainer:WaitForChild("PowerBarFill")
local powerLabel = powerBarContainer:WaitForChild("PowerLabel")
local turnLabel = mainFrame:WaitForChild("TurnLabel")
local closeButton = mainFrame:WaitForChild("CloseButton")

-- ═══ GAME STATE ═══
local currentMatch = nil
local playerNumber = 0
local isAiming = false
local aimAngle = 0
local shotPower = 0
local ballElements = {}

-- ═══════════════════════════════════════════════════════════
--  BALL RENDERING (with shadows)
-- ═══════════════════════════════════════════════════════════

local function createBallElement(ball)
	-- Ball container
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, ball.radius * 2, 0, ball.radius * 2)
	container.BackgroundTransparency = 1
	container.Parent = tableFrame
	
	-- Shadow (behind ball)
	local shadow = Instance.new("Frame")
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, 2, 0, 2)
	shadow.BackgroundColor3 = COLORS.Shadow
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = container
	
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(1, 0)
	shadowCorner.Parent = shadow
	
	-- Ball button
	local ballButton = Instance.new("ImageButton")
	ballButton.Size = UDim2.new(1, 0, 1, 0)
	ballButton.BackgroundColor3 = ball.color
	ballButton.BorderSizePixel = 2
	ballButton.BorderColor3 = COLORS.White
	ballButton.AutoButtonColor = false
	ballButton.ZIndex = 2
	ballButton.Parent = container
	
	local ballCorner = Instance.new("UICorner")
	ballCorner.CornerRadius = UDim.new(1, 0)
	ballCorner.Parent = ballButton
	
	-- Gradient for 3D effect
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, ball.color),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
	})
	gradient.Rotation = 135
	gradient.Parent = ballButton
	
	-- Number label (if not cue ball)
	if ball.type ~= 0 then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.7, 0, 0.7, 0)
		label.Position = UDim2.new(0.15, 0, 0.15, 0)
		label.BackgroundTransparency = 1
		label.Text = tostring(ball.id)
		label.TextColor3 = COLORS.White
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.5
		label.ZIndex = 3
		label.Parent = ballButton
	end
	
	-- Click handler for cue ball
	if ball.id == 0 then
		ballButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if currentMatch and currentMatch.state.currentPlayer == playerNumber and currentMatch.state.canShoot then
					isAiming = true
				end
			end
		end)
	end
	
	return container
end

-- ═══════════════════════════════════════════════════════════
--  UPDATE BALLS POSITIONS
-- ═══════════════════════════════════════════════════════════

local function updateBalls(gameState)
	-- Clear existing balls
	for _, element in pairs(ballElements) do
		element:Destroy()
	end
	ballElements = {}
	
	-- Create new ball elements
	for _, ball in ipairs(gameState.balls) do
		if not ball.pocketed then
			local element = createBallElement(ball)
			element.Position = UDim2.new(0, ball.x - ball.radius, 0, ball.y - ball.radius)
			ballElements[ball.id] = element
		end
	end
end

-- ═══════════════════════════════════════════════════════════
--  CUE STICK RENDERING
-- ═══════════════════════════════════════════════════════════

local cueStick = Instance.new("Frame")
cueStick.Size = UDim2.new(0, 100, 0, 6)
cueStick.AnchorPoint = Vector2.new(0, 0.5)
cueStick.BackgroundColor3 = COLORS.CueWood
cueStick.BorderSizePixel = 0
cueStick.Visible = false
cueStick.ZIndex = 5
cueStick.Parent = tableFrame

local cueGradient = Instance.new("UIGradient")
cueGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLORS.CueWood),
	ColorSequenceKeypoint.new(1, COLORS.CueWoodLight)
})
cueGradient.Rotation = 90
cueGradient.Parent = cueStick

local cueCorner = Instance.new("UICorner")
cueCorner.CornerRadius = UDim.new(0.5, 0)
cueCorner.Parent = cueStick

-- ═══════════════════════════════════════════════════════════
--  AIMING MECHANICS
-- ═══════════════════════════════════════════════════════════

local function updateAiming(gameState)
	if not gameState or not gameState.canShoot or gameState.currentPlayer ~= playerNumber then
		cueStick.Visible = false
		return
	end
	
	local cueBall = gameState.balls[1]
	if cueBall.pocketed then
		cueStick.Visible = false
		return
	end
	
	if isAiming then
		cueStick.Visible = true
		
		local mousePos = UserInputService:GetMouseLocation()
		local cueBallScreenX = tableFrame.AbsolutePosition.X + cueBall.x
		local cueBallScreenY = tableFrame.AbsolutePosition.Y + cueBall.y
		
		local dx = mousePos.X - cueBallScreenX
		local dy = mousePos.Y - cueBallScreenY
		aimAngle = math.atan2(dy, dx)
		
		local distance = math.sqrt(dx * dx + dy * dy)
		shotPower = math.clamp(distance / 150, 0, 1)
		
		-- Update cue stick
		cueStick.Position = UDim2.new(0, cueBall.x, 0, cueBall.y)
		cueStick.Rotation = math.deg(aimAngle)
		cueStick.Size = UDim2.new(0, 80 + shotPower * 60, 0, 6)
		
		-- Update power bar
		local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(powerBarFill, tweenInfo, {
			Size = UDim2.new(shotPower, 0, 1, 0)
		})
		tween:Play()
		
		-- Update power bar color (yellow to red gradient)
		local color = COLORS.PowerYellow:Lerp(COLORS.PowerRed, shotPower)
		powerBarFill.BackgroundColor3 = color
		
		-- Update label
		powerLabel.Text = "POWER: " .. math.floor(shotPower * 100) .. "%"
	else
		cueStick.Visible = false
		powerBarFill.Size = UDim2.new(0, 0, 1, 0)
		powerLabel.Text = "POWER: 0%"
	end
end

-- ═══════════════════════════════════════════════════════════
--  INPUT HANDLING
-- ═══════════════════════════════════════════════════════════

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and isAiming then
		isAiming = false
		
		if currentMatch and shotPower > 0.1 then
			shotRemote:FireServer(aimAngle, shotPower)
			print("💥 Shot fired! Angle:", math.deg(aimAngle), "Power:", shotPower)
			shotPower = 0
		end
	end
end)

-- ═══════════════════════════════════════════════════════════
--  MATCH START HANDLER
-- ═══════════════════════════════════════════════════════════

startMatchRemote.OnClientEvent:Connect(function(matchData)
	print("📥 Match data received:", matchData.opponent, "| Player #:", matchData.playerNumber)
	
	if matchData.opponent == "left" then
		billiardsUI.Enabled = false
		currentMatch = nil
		turnLabel.Text = "Opponent left the game"
		return
	end
	
	currentMatch = matchData
	playerNumber = matchData.playerNumber
	
	-- Fade in UI
	mainFrame.BackgroundTransparency = 1
	billiardsUI.Enabled = true
	
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(mainFrame, tweenInfo, {
		BackgroundTransparency = 0
	})
	tween:Play()
	
	updateBalls(matchData.state)
	
	local turnText = (matchData.state.currentPlayer == playerNumber) and "🎯 YOUR TURN" or "⏳ " .. matchData.opponent:upper() .. "'S TURN"
	turnLabel.Text = turnText .. " | VS " .. matchData.opponent:upper()
	
	print("✅ UI displayed! Playing as Player", playerNumber)
end)

-- ═══════════════════════════════════════════════════════════
--  STATE UPDATE HANDLER
-- ═══════════════════════════════════════════════════════════

updateStateRemote.OnClientEvent:Connect(function(gameState)
	if not currentMatch then return end
	
	currentMatch.state = gameState
	updateBalls(gameState)
	
	if gameState.gameOver then
		local isWinner = (gameState.winner == playerNumber)
		local statusText = isWinner and "🎉 YOU WIN!" or "😢 YOU LOSE"
		
		turnLabel.Text = statusText
		turnLabel.TextColor3 = isWinner and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100)
		
		-- Animate win/lose
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
		local tween = TweenService:Create(turnLabel, tweenInfo, {
			TextSize = 40
		})
		tween:Play()
		
		task.wait(3)
		
		-- Fade out
		local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fadeTween = TweenService:Create(mainFrame, fadeInfo, {
			BackgroundTransparency = 1
		})
		fadeTween:Play()
		fadeTween.Completed:Wait()
		
		billiardsUI.Enabled = false
		currentMatch = nil
		turnLabel.TextSize = 26
		turnLabel.TextColor3 = COLORS.White
	else
		local turnText = (gameState.currentPlayer == playerNumber) and "🎯 YOUR TURN" or "⏳ OPPONENT'S TURN"
		turnLabel.Text = turnText
	end
end)

-- ═══════════════════════════════════════════════════════════
--  PROXIMITY PROMPT CONNECTION
-- ═══════════════════════════════════════════════════════════

task.spawn(function()
	print("🔍 Searching for BilliardTable...")
	
	local billiardTable = workspace:WaitForChild("BilliardTable", 60)
	if not billiardTable then
		warn("❌ BilliardTable not found in Workspace!")
		return
	end
	
	print("✅ BilliardTable found!")
	
	local tableTop = billiardTable:WaitForChild("TableTop", 30)
	if not tableTop then
		warn("❌ TableTop not found!")
		return
	end
	
	print("✅ TableTop found!")
	
	local prompt = tableTop:WaitForChild("ProximityPrompt", 30)
	if not prompt then
		warn("❌ ProximityPrompt not found!")
		return
	end
	
	print("✅ ProximityPrompt found!")
	print("   ActionText:", prompt.ActionText)
	print("   MaxActivationDistance:", prompt.MaxActivationDistance)
	
	prompt.Triggered:Connect(function()
		print("🔘 ProximityPrompt triggered! Joining queue...")
		
		if not currentMatch then
			joinQueueRemote:FireServer()
			turnLabel.Text = "⏳ WAITING FOR OPPONENT..."
			billiardsUI.Enabled = true
			
			-- Fade in waiting screen
			mainFrame.BackgroundTransparency = 1
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(mainFrame, tweenInfo, {
				BackgroundTransparency = 0
			})
			tween:Play()
			
			print("✅ Waiting screen displayed")
		else
			print("⚠️ Already in a match!")
		end
	end)
	
	print("✅ ProximityPrompt connected!")
end)

-- ═══════════════════════════════════════════════════════════
--  CLOSE BUTTON
-- ═══════════════════════════════════════════════════════════

closeButton.MouseButton1Click:Connect(function()
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tween = TweenService:Create(mainFrame, tweenInfo, {
		BackgroundTransparency = 1
	})
	tween:Play()
	tween.Completed:Wait()
	
	billiardsUI.Enabled = false
	currentMatch = nil
	print("🚪 UI closed by player")
end)

-- ═══════════════════════════════════════════════════════════
--  RENDER LOOP
-- ═══════════════════════════════════════════════════════════

RunService.RenderStepped:Connect(function()
	if currentMatch and currentMatch.state then
		updateAiming(currentMatch.state)
	end
end)

print("✅ ═══════════════════════════════════════")
print("   BILLIARDS CLIENT READY!")
print("   Player:", player.Name)
print("✅ ═══════════════════════════════════════")
