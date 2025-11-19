-- ═══════════════════════════════════════════════════════════
--  🎱 PREMIUM BILLIARDS SERVER
--  Modern 8-Ball Pool with Realistic Physics
--  Author: GitHub Copilot
--  Date: 2025-11-19
-- ═══════════════════════════════════════════════════════════

print("🎱 ═══════════════════════════════════════")
print("   PREMIUM BILLIARDS SERVER STARTING")
print("🎱 ═══════════════════════════════════════")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ═══ SERVICES & REFERENCES ═══
local system = ReplicatedStorage:WaitForChild("BilliardsSystem", 30)
if not system then 
	error("❌ BilliardsSystem not found in ReplicatedStorage!") 
end

local remoteFolder = system:WaitForChild("RemoteEvents", 10)
local joinQueueRemote = remoteFolder:WaitForChild("Billiards_JoinQueue")
local startMatchRemote = remoteFolder:WaitForChild("Billiards_StartMatch")
local shotRemote = remoteFolder:WaitForChild("Billiards_Shot")
local updateStateRemote = remoteFolder:WaitForChild("Billiards_UpdateState")

-- ═══ GAME STATE ═══
local matchQueue = {}
local activeMatches = {}
local playerInMatch = {}

-- ═══ CONSTANTS ═══
local BALL_TYPES = {
	CUE = 0,
	SOLID = 1,
	STRIPE = 2,
	EIGHT = 8
}

local PHYSICS = {
	FRICTION = 0.985,
	BOUNCE = 0.75,
	MIN_SPEED = 0.08,
	COLLISION_ELASTICITY = 0.95
}

local TABLE = {
	WIDTH = 700,
	HEIGHT = 300,
	MARGIN = 15,
	POCKET_RADIUS = 14
}

local POCKETS = {
	{x = 20, y = 20},
	{x = 350, y = 20},
	{x = 680, y = 20},
	{x = 20, y = 280},
	{x = 350, y = 280},
	{x = 680, y = 280}
}

-- ═══ BALL COLORS (Professional) ═══
local BALL_COLORS = {
	[0] = Color3.fromRGB(255, 255, 255),  -- Cue (white)
	[1] = Color3.fromRGB(255, 215, 0),    -- Yellow
	[2] = Color3.fromRGB(0, 100, 255),    -- Blue
	[3] = Color3.fromRGB(255, 50, 50),    -- Red
	[4] = Color3.fromRGB(128, 0, 128),    -- Purple
	[5] = Color3.fromRGB(255, 140, 0),    -- Orange
	[6] = Color3.fromRGB(34, 139, 34),    -- Green
	[7] = Color3.fromRGB(139, 0, 0),      -- Maroon
	[8] = Color3.fromRGB(0, 0, 0),        -- Eight (black)
	[9] = Color3.fromRGB(255, 235, 100),  -- Yellow stripe
	[10] = Color3.fromRGB(100, 150, 255), -- Blue stripe
	[11] = Color3.fromRGB(255, 120, 120), -- Red stripe
	[12] = Color3.fromRGB(180, 100, 180), -- Purple stripe
	[13] = Color3.fromRGB(255, 180, 100), -- Orange stripe
	[14] = Color3.fromRGB(100, 180, 100), -- Green stripe
	[15] = Color3.fromRGB(180, 80, 80)    -- Maroon stripe
}

-- ═══════════════════════════════════════════════════════════
--  GAME STATE CREATION
-- ═══════════════════════════════════════════════════════════

local function createGameState()
	local balls = {}
	
	-- Cue ball (white)
	table.insert(balls, {
		id = 0,
		type = BALL_TYPES.CUE,
		x = 180,
		y = 150,
		vx = 0,
		vy = 0,
		radius = 10,
		pocketed = false,
		color = BALL_COLORS[0]
	})
	
	-- Rack setup (triangle formation)
	local rackX, rackY = 520, 150
	local spacing = 22
	
	local ballOrder = {1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15}
	local positions = {
		{0, 0},                                      -- Row 1: 1 ball
		{1, -0.5}, {1, 0.5},                        -- Row 2: 2 balls
		{2, -1}, {2, 0}, {2, 1},                    -- Row 3: 3 balls
		{3, -1.5}, {3, -0.5}, {3, 0.5}, {3, 1.5},  -- Row 4: 4 balls
		{4, -2}, {4, -1}, {4, 0}, {4, 1}, {4, 2}   -- Row 5: 5 balls
	}
	
	for i, ballNum in ipairs(ballOrder) do
		local pos = positions[i]
		local ballType
		
		if ballNum == 8 then
			ballType = BALL_TYPES.EIGHT
		elseif ballNum > 8 then
			ballType = BALL_TYPES.STRIPE
		else
			ballType = BALL_TYPES.SOLID
		end
		
		table.insert(balls, {
			id = ballNum,
			type = ballType,
			x = rackX + pos[1] * spacing,
			y = rackY + pos[2] * spacing,
			vx = 0,
			vy = 0,
			radius = 10,
			pocketed = false,
			color = BALL_COLORS[ballNum]
		})
	end
	
	return {
		balls = balls,
		currentPlayer = 1,
		player1Type = nil,
		player2Type = nil,
		turnPhase = "aiming",
		canShoot = true,
		gameOver = false,
		winner = nil,
		score = {player1 = 0, player2 = 0}
	}
end

-- ═══════════════════════════════════════════════════════════
--  MATCHMAKING
-- ═══════════════════════════════════════════════════════════

local function findMatch(player)
	table.insert(matchQueue, player)
	print("📝 Player queued:", player.Name, "| Queue size:", #matchQueue)
	
	-- ✅ TEST MODE: Change to >= 2 for normal multiplayer
	if #matchQueue >= 1 then
		local p1 = matchQueue[1]
		local p2 = matchQueue[1]  -- Solo test: play against yourself
		table.remove(matchQueue, 1)
		
		local matchId = p1.UserId .. "_" .. os.time()
		local gameState = createGameState()
		
		activeMatches[matchId] = {
			player1 = p1,
			player2 = p2,
			state = gameState,
			startTime = os.time()
		}
		
		playerInMatch[p1] = matchId
		
		startMatchRemote:FireClient(p1, {
			opponent = p2.Name,
			playerNumber = 1,
			state = gameState
		})
		
		print("🎮 Match started:", p1.Name, "vs", p2.Name, "| ID:", matchId)
		return true
	end
	
	return false
end

joinQueueRemote.OnServerEvent:Connect(function(player)
	if playerInMatch[player] then
		warn("⚠️ Player already in match:", player.Name)
		return
	end
	
	-- Remove from queue if already there
	for i, queuedPlayer in ipairs(matchQueue) do
		if queuedPlayer == player then
			table.remove(matchQueue, i)
			print("🔄 Player re-queued:", player.Name)
			return
		end
	end
	
	findMatch(player)
end)

-- ═══════════════════════════════════════════════════════════
--  PHYSICS SIMULATION (Realistic)
-- ═══════════════════════════════════════════════════════════

local function simulatePhysics(balls, deltaTime)
	local moving = false
	
	-- ═══ STEP 1: Update positions ═══
	for _, ball in ipairs(balls) do
		if not ball.pocketed then
			-- Apply velocity
			ball.x = ball.x + ball.vx
			ball.y = ball.y + ball.vy
			
			-- Apply friction
			ball.vx = ball.vx * PHYSICS.FRICTION
			ball.vy = ball.vy * PHYSICS.FRICTION
			
			-- Stop if too slow
			if math.abs(ball.vx) < PHYSICS.MIN_SPEED and math.abs(ball.vy) < PHYSICS.MIN_SPEED then
				ball.vx = 0
				ball.vy = 0
			end
			
			if ball.vx ~= 0 or ball.vy ~= 0 then
				moving = true
			end
		end
	end
	
	-- ═══ STEP 2: Wall collisions ═══
	for _, ball in ipairs(balls) do
		if not ball.pocketed then
			local margin = TABLE.MARGIN
			
			if ball.x - ball.radius < margin then
				ball.x = margin + ball.radius
				ball.vx = -ball.vx * PHYSICS.BOUNCE
			elseif ball.x + ball.radius > TABLE.WIDTH - margin then
				ball.x = TABLE.WIDTH - margin - ball.radius
				ball.vx = -ball.vx * PHYSICS.BOUNCE
			end
			
			if ball.y - ball.radius < margin then
				ball.y = margin + ball.radius
				ball.vy = -ball.vy * PHYSICS.BOUNCE
			elseif ball.y + ball.radius > TABLE.HEIGHT - margin then
				ball.y = TABLE.HEIGHT - margin - ball.radius
				ball.vy = -ball.vy * PHYSICS.BOUNCE
			end
		end
	end
	
	-- ═══ STEP 3: Ball collisions ═══
	for i = 1, #balls do
		for j = i + 1, #balls do
			local b1, b2 = balls[i], balls[j]
			
			if not b1.pocketed and not b2.pocketed then
				local dx = b2.x - b1.x
				local dy = b2.y - b1.y
				local dist = math.sqrt(dx * dx + dy * dy)
				local minDist = b1.radius + b2.radius
				
				if dist < minDist and dist > 0 then
					-- Separate balls
					local overlap = minDist - dist
					local nx = dx / dist
					local ny = dy / dist
					
					b1.x = b1.x - nx * overlap * 0.5
					b1.y = b1.y - ny * overlap * 0.5
					b2.x = b2.x + nx * overlap * 0.5
					b2.y = b2.y + ny * overlap * 0.5
					
					-- Elastic collision
					local dvx = b2.vx - b1.vx
					local dvy = b2.vy - b1.vy
					local dotProduct = dvx * nx + dvy * ny
					
					if dotProduct < 0 then
						local impulse = dotProduct * PHYSICS.COLLISION_ELASTICITY
						b1.vx = b1.vx + nx * impulse
						b1.vy = b1.vy + ny * impulse
						b2.vx = b2.vx - nx * impulse
						b2.vy = b2.vy - ny * impulse
					end
				end
			end
		end
	end
	
	-- ═══ STEP 4: Pocket detection ═══
	for _, ball in ipairs(balls) do
		if not ball.pocketed then
			for _, pocket in ipairs(POCKETS) do
				local dx = ball.x - pocket.x
				local dy = ball.y - pocket.y
				local dist = math.sqrt(dx * dx + dy * dy)
				
				if dist < TABLE.POCKET_RADIUS then
					ball.pocketed = true
					ball.vx = 0
					ball.vy = 0
					print("🕳️ Ball", ball.id, "pocketed!")
					break
				end
			end
		end
	end
	
	return moving
end

-- ═══════════════════════════════════════════════════════════
--  SHOT HANDLING
-- ═══════════════════════════════════════════════════════════

shotRemote.OnServerEvent:Connect(function(player, angle, power)
	local matchId = playerInMatch[player]
	if not matchId then 
		warn("⚠️ Shot from player not in match:", player.Name)
		return 
	end
	
	local match = activeMatches[matchId]
	if not match then 
		warn("⚠️ Match not found:", matchId)
		return 
	end
	
	local state = match.state
	local playerNum = (match.player1 == player) and 1 or 2
	
	-- Validate turn
	if state.currentPlayer ~= playerNum then
		warn("⚠️ Wrong turn:", player.Name)
		return
	end
	
	if not state.canShoot then
		warn("⚠️ Cannot shoot yet:", player.Name)
		return
	end
	
	-- Find cue ball
	local cueBall = state.balls[1]
	if cueBall.pocketed then
		warn("⚠️ Cue ball pocketed!")
		return
	end
	
	-- Apply force
	local maxForce = 15
	local forceMagnitude = power * maxForce
	cueBall.vx = math.cos(angle) * forceMagnitude
	cueBall.vy = math.sin(angle) * forceMagnitude
	
	state.canShoot = false
	state.turnPhase = "simulating"
	
	print("💥 Shot fired by", player.Name, "| Power:", math.floor(power * 100) .. "%")
	
	-- Simulate physics
	task.spawn(function()
		local frameCount = 0
		local moving = true
		
		while moving do
			moving = simulatePhysics(state.balls, 0.016)
			
			-- Update clients every frame
			updateStateRemote:FireClient(match.player1, state)
			if match.player2 ~= match.player1 then
				updateStateRemote:FireClient(match.player2, state)
			end
			
			frameCount = frameCount + 1
			task.wait(0.016)  -- 60 FPS
		end
		
		print("⏱️ Physics simulation complete:", frameCount, "frames")
		
		-- Switch turns
		state.currentPlayer = (state.currentPlayer == 1) and 2 or 1
		state.canShoot = true
		state.turnPhase = "aiming"
		
		-- Check win condition (8-ball pocketed)
		local eightBall = state.balls[9]  -- Index 9 = ball ID 8
		if eightBall.pocketed then
			state.gameOver = true
			state.winner = playerNum
			print("🏆 GAME OVER! Winner:", playerNum)
		end
		
		-- Final update
		updateStateRemote:FireClient(match.player1, state)
		if match.player2 ~= match.player1 then
			updateStateRemote:FireClient(match.player2, state)
		end
	end)
end)

-- ═══════════════════════════════════════════════════════════
--  PLAYER DISCONNECT HANDLING
-- ═══════════════════════════════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
	-- Remove from queue
	for i, queuedPlayer in ipairs(matchQueue) do
		if queuedPlayer == player then
			table.remove(matchQueue, i)
			print("🚪 Player left queue:", player.Name)
			break
		end
	end
	
	-- End active match
	local matchId = playerInMatch[player]
	if matchId then
		local match = activeMatches[matchId]
		if match then
			local opponent = (match.player1 == player) and match.player2 or match.player1
			if opponent and opponent ~= player then
				startMatchRemote:FireClient(opponent, {opponent = "left", playerNumber = 0})
				print("🚪 Match ended - player left:", player.Name)
			end
			activeMatches[matchId] = nil
		end
		playerInMatch[player] = nil
	end
end)

print("✅ ═══════════════════════════════════════")
print("   BILLIARDS SERVER READY!")
print("   Test Mode: ENABLED (solo play)")
print("✅ ═══════════════════════════════════════")


