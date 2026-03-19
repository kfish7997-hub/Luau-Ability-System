--[[ 
	20 20 20 drop kick Ability Remake Made by Killer Fish
	
	This is designed to meet Luau Scripter requirements
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

--// ANIMATION IDS
local PlayerAnimation = "rbxassetid://90467914187137"
local HitSuccessAnimation = "rbxassetid://75425356277639"
local EnemyAnimation = "rbxassetid://99147563134834"

--// SPEED BOOST FUNCTION
-- Gradually increases velocity to create smoother dash acceleration
local function SpeedUpVelocity(velocity)
	for i = 1, 10 do
		if velocity then
			task.spawn(function()
				if velocity and velocity.Parent then
					-- Use Magnitude instead of incorrect vector comparison
					if velocity.Velocity.Magnitude >= 150 then return end
					velocity.Velocity *= 1.2
				end
			end)
		end
		task.wait(0.05)
	end
end

--// VFX FUNCTION
-- Clones and emits particle effects at character position
local function EmitVFX(character, vfx)
	task.spawn(function()
		local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not HumanoidRootPart then return end

		local clonedVFX = vfx:Clone()
		clonedVFX.Parent = workspace:FindFirstChild("VFX") or workspace
		clonedVFX.CFrame = HumanoidRootPart.CFrame

		task.wait(0.01)

		for _, v in pairs(clonedVFX:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(5)
			end
		end

		Debris:AddItem(clonedVFX, 3)
	end)
end

--// SPEED LINE EFFECT
-- Creates a visual effect attached to player while dashing
local function CloneSpeedLineEffect(character)
	local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return end

	local speedLine = script:WaitForChild("VFX"):WaitForChild("SpeedLines"):Clone()
	speedLine.Parent = workspace:FindFirstChild("VFX") or workspace
	speedLine.CFrame = HumanoidRootPart.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HumanoidRootPart
	weld.Part1 = speedLine
	weld.Parent = speedLine

	return speedLine
end

--// HITBOX SYSTEM
-- Creates a temporary hitbox in front of the player
local function HitBoxSetup(character)
	local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return end

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(7,7,7)
	hitbox.Transparency = 0.7
	hitbox.CanCollide = false
	hitbox.Massless = true
	hitbox.Color = Color3.fromRGB(255,0,0)
	hitbox.CFrame = HumanoidRootPart.CFrame * CFrame.new(0,0,-4)
	hitbox.Parent = HumanoidRootPart

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HumanoidRootPart
	weld.Part1 = hitbox
	weld.Parent = hitbox

	return hitbox
end

--// PLAYER HANDLING
Players.PlayerAdded:Connect(function(player)

	player.CharacterAdded:Connect(function(character)

		local ability = Instance.new("Tool")
		ability.Name = "DashAbility"
		ability.RequiresHandle = false
		ability.Parent = player.Backpack

		-- Cooldown attribute
		ability:SetAttribute("OnCooldown", false)

		--// ACTIVATION
		ability.Activated:Connect(function()

			-- Prevent spam usage
			if ability:GetAttribute("OnCooldown") then return end
			ability:SetAttribute("OnCooldown", true)

			-- Cooldown reset
			task.delay(15, function()
				if ability then
					ability:SetAttribute("OnCooldown", false)
				end
			end)

			local humanoid = character:WaitForChild("Humanoid")
			local animator = humanoid:FindFirstChild("Animator")
			local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")

			if not animator or not HumanoidRootPart then return end

			-- Load animation
			local animation = Instance.new("Animation")
			animation.AnimationId = PlayerAnimation

			local track = animator:LoadAnimation(animation)
			track:Play()

			-- Variables
			local bodyVelocity
			local hitbox
			local hitOnce = false
			local speedLine
			local connection

			--// DASH START
			track:GetMarkerReachedSignal("Dash"):Connect(function()

				-- Create velocity
				bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.MaxForce = Vector3.new(100000,100000,100000)
				bodyVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * 100
				bodyVelocity.Parent = HumanoidRootPart

				-- Smooth acceleration
				SpeedUpVelocity(bodyVelocity)

				-- Create hitbox
				hitbox = HitBoxSetup(character)

				-- Create VFX
				speedLine = CloneSpeedLineEffect(character)

				-- Hit detection
				hitbox.Touched:Connect(function(hit)

					if hitOnce then return end
					if not hit.Parent or hit.Parent == character then return end

					local enemyHumanoid = hit.Parent:FindFirstChild("Humanoid")
					local enemyRoot = hit.Parent:FindFirstChild("HumanoidRootPart")

					if enemyHumanoid and enemyRoot then

						hitOnce = true

						-- Remove dash VFX
						if speedLine then speedLine:Destroy() end

						-- Emit hit VFX
						EmitVFX(hit.Parent, script.VFX.FirstHit)

						-- Stop movement safely
						if connection then connection:Disconnect() end
						if bodyVelocity then bodyVelocity:Destroy() end

						-- Stop animation
						track:Stop()

						if hitbox then hitbox:Destroy() end

						-- Anchor both characters for cinematic hit
						enemyRoot.Anchored = true
						HumanoidRootPart.Anchored = true
						humanoid.AutoRotate = false

						-- Position enemy
						enemyRoot.CFrame = HumanoidRootPart.CFrame * CFrame.new(0,0,-10)
						enemyRoot.CFrame = CFrame.lookAt(enemyRoot.Position, HumanoidRootPart.Position)
						HumanoidRootPart.CFrame = CFrame.lookAt(HumanoidRootPart.Position, enemyRoot.Position)

						-- Play hit animations
						local hitAnim = Instance.new("Animation")
						hitAnim.AnimationId = HitSuccessAnimation

						local hitTrack = animator:LoadAnimation(hitAnim)
						hitTrack:Play()

						local enemyAnim = Instance.new("Animation")
						enemyAnim.AnimationId = EnemyAnimation

						local enemyTrack = enemyHumanoid.Animator:LoadAnimation(enemyAnim)
						enemyTrack:Play()

						-- Damage when enemy animation ends
						enemyTrack.Ended:Connect(function()
							enemyRoot.Anchored = false
							enemyHumanoid:TakeDamage(100)
						end)

						-- Restore player control
						hitTrack.Ended:Connect(function()
							HumanoidRootPart.Anchored = false
							humanoid.AutoRotate = true
						end)
					end
				end)
			end)

			-- Maintain forward force
			connection = RunService.Heartbeat:Connect(function()
				if bodyVelocity and bodyVelocity.Parent then
					bodyVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * 150
				end
			end)

			--// DASH END CLEANUP
			track:GetMarkerReachedSignal("End"):Connect(function()

				if connection then connection:Disconnect() end
				if bodyVelocity then bodyVelocity:Destroy() end
				if hitbox then hitbox:Destroy() end
				if speedLine then speedLine:Destroy() end

				humanoid.AutoRotate = true
			end)

		end)
	end)
end)
