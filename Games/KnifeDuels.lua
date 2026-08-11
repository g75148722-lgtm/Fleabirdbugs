--[[
  Knife Duels - liquid glass
  PlaceIds: 112731528776884, 85024203742894

  Instant kill: TP behind head + camera aim + melee stab
  Silent throw + UUID skins · Third person · ESP · death sounds

  RightShift = UI · V = insta nearest · I = toggle instakill · K = aura
]]

local okLoad, loadErr = pcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local CombatRE = RS:WaitForChild("CombatService"):WaitForChild("RE")
local ReportHit = CombatRE:WaitForChild("ReportHit")
local ThrowHit = CombatRE:FindFirstChild("ThrowHit")
local ThrowKnife = CombatRE:FindFirstChild("ThrowKnife")
local HitDummy = CombatRE:FindFirstChild("HitDummy")
local EquipKnifeRF = RS:WaitForChild("KnifeService"):WaitForChild("RF"):WaitForChild("EquipKnife")

do
	local prev = rawget(getgenv(), "KnifeDuels")
	if type(prev) == "table" and type(prev.Destroy) == "function" then
		pcall(prev.Destroy)
	end
	for _, g in ipairs({ CoreGui, LP:FindFirstChild("PlayerGui") }) do
		if g then
			local u = g:FindFirstChild("KnifeDuels")
			if u then u:Destroy() end
		end
	end
	for _, name in ipairs({ "KD_GlassBlur", "KD_AmbientCC", "KD_AmbientBloom", "KD_AmbientAtm" }) do
		local b = Lighting:FindFirstChild(name)
		if b then b:Destroy() end
	end
	local folder = workspace:FindFirstChild("KD_FX")
	if folder then folder:Destroy() end
end

local function dig(root, name, depth)
	if not root or depth > 8 then return nil end
	local m = root:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then return m end
	for _, c in ipairs(root:GetChildren()) do
		local f = dig(c, name, depth + 1)
		if f then return f end
	end
	return nil
end

local CombatRules
do
	local ps = LP:FindFirstChild("PlayerScripts")
	local inst = dig(RS, "CombatRules", 0) or dig(ps, "CombatRules", 0)
	if not inst and ps then
		-- shared modules sometimes live under Controllers packages
		for _, d in ipairs(ps:GetDescendants()) do
			if d:IsA("ModuleScript") and d.Name == "CombatRules" then
				inst = d
				break
			end
		end
	end
	if not inst then
		for _, d in ipairs(RS:GetDescendants()) do
			if d:IsA("ModuleScript") and d.Name == "CombatRules" then
				inst = d
				break
			end
		end
	end
	if inst then
		local ok, mod = pcall(require, inst)
		if ok then CombatRules = mod end
	end
end

local AT_KNIFE = (CombatRules and CombatRules.AttackType and CombatRules.AttackType.Knife) or "Knife"
local AT_THROW = (CombatRules and CombatRules.AttackType and CombatRules.AttackType.Throw) or "Throw"

local FALLBACK_SKINS = {
	"Default", "Classic", "Karambit", "Butterfly", "Bayonet", "Saber", "Shadow",
	"Gold", "Neon", "Ruby", "Sapphire", "Emerald", "Obsidian", "Crimson",
}

-- Apple liquid-glass palette (cool silver / soft sky — not purple AI slop)
local Theme = {
	Glass = Color3.fromRGB(255, 255, 255),
	Fill = Color3.fromRGB(245, 247, 250),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(28, 28, 30),
	Secondary = Color3.fromRGB(60, 60, 67),
	Muted = Color3.fromRGB(142, 142, 147),
	Accent = Color3.fromRGB(0, 122, 255), -- iOS system blue
	Green = Color3.fromRGB(52, 199, 89),
	Red = Color3.fromRGB(255, 59, 48),
	Orange = Color3.fromRGB(255, 149, 0),
	Separator = Color3.fromRGB(198, 198, 200),
}

local Cfg = {
	Aura = true,
	AuraRange = 9,
	AuraInterval = 0.1,
	HitsPerTick = 2,
	IncludeBots = true,
	SilentThrow = true,
	ThrowInterval = 1.02,
	ThrowRange = 400,
	ThrowSpeed = 3000,
	ThrowBurst = 1,
	ThrowKnifeEvery = 1.02,
	ThrowPredict = true,
	ThrowFovPriority = true,
	ThrowDropGravity = 100,
	KillAuraMelee = true,
	MeleeRange = 9,
	ThrowHitDelayScale = 0.88,
	HitConfirm = true, -- multi-window ReportHit after throw

	-- Instant kill: hold TP behind head + arm reach, then stab
	InstantKill = true,
	InstantKillRange = 220,
	InstantKillInterval = 0.18,
	BehindHeadStuds = 1.85,
	HoldBehind = 0.18, -- keep blinked in so server sees you
	BlinkBack = true,
	ArmSnap = true, -- Motor6D Transform reach (survives anims)

	Godmode = false,
	Speed = false,
	WalkSpeed = 28,
	BaseWalkSpeed = 16,

	Spinbot = false,
	SpinSpeed = 18,
	ThirdPerson = true,
	CameraDistance = 14,
	ZoomOutSpeed = 0.045,
	SelectedSkin = "Default",
	ESP = true,
	ESPTracers = true,
	AmbientRainbow = true,
	DeathSounds = true,
	RainbowTracer = true,
	TracerLife = 0.45,
}

local St = {
	Alive = true,
	Menu = true,
	Tab = "Combat",
	Status = "ready",
	Fires = 0,
	Throws = 0,
	Equips = 0,
	Stab = 0,
	LastAura = 0,
	LastThrow = 0,
	LastThrowKnife = 0,
	LastInstant = 0,
	InstantBusy = false,
	HoldConn = nil,
	ArmMotors = nil,
	SavedCamType = nil,
	ConfigLoaded = false,
	ConfigPath = "KnifeDuels_Config.json",
	Conns = {},
	Skins = {},
	SpinYaw = 0,
	OrigMinZoom = nil,
	OrigMaxZoom = nil,
	Hue = 0,
	DeathPool = {},
	EspNodes = {},
	FxFolder = nil,
	KnifeCtrl = nil,
	MatchCtrl = nil,
	BotCtrl = nil,
	TrainCtrl = nil,
	PendingThrows = {},
	LastCtrlScan = 0,
	LastEsp = 0,
	CachedTraining = false,
	CachedBot = false,
	EspOk = true,
	LastKillAt = 0,
	MarkedKills = {}, -- [model] = os.clock when we attacked
	OrigWalkSpeed = nil,
}

local function track(c)
	St.Conns[#St.Conns + 1] = c
	return c
end

local function tween(obj, props, t, style, dir)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t or 0.35, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function hsv(h, s, v)
	return Color3.fromHSV((h % 1 + 1) % 1, s or 1, v or 1)
end

local api = { Cfg = Cfg, St = St }

-- ── config auto load / save ─────────────────────────────────────────────────
local CONFIG_KEYS = {
	"Aura", "AuraRange", "AuraInterval", "HitsPerTick", "IncludeBots",
	"SilentThrow", "ThrowInterval", "ThrowRange", "ThrowPredict", "ThrowFovPriority",
	"KillAuraMelee", "MeleeRange", "HitConfirm",
	"InstantKill", "InstantKillRange", "InstantKillInterval", "BehindHeadStuds",
	"HoldBehind", "BlinkBack", "ArmSnap",
	"Godmode", "Speed", "WalkSpeed",
	"Spinbot", "SpinSpeed", "ThirdPerson", "CameraDistance",
	"SelectedSkin", "ESP", "ESPTracers", "AmbientRainbow", "DeathSounds",
	"RainbowTracer", "TracerLife",
}

local function saveConfig()
	if not writefile then return false end
	local data = {}
	for _, k in ipairs(CONFIG_KEYS) do
		data[k] = Cfg[k]
	end
	local ok, enc = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not ok or type(enc) ~= "string" then return false end
	local wok = pcall(function()
		writefile(St.ConfigPath, enc)
	end)
	return wok
end

local function loadConfig()
	if not readfile then return false end
	local exists = true
	if isfile then
		exists = isfile(St.ConfigPath)
	end
	if not exists then return false end
	local ok, raw = pcall(readfile, St.ConfigPath)
	if not ok or type(raw) ~= "string" or raw == "" then return false end
	local dok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not dok or type(data) ~= "table" then return false end
	for _, k in ipairs(CONFIG_KEYS) do
		if data[k] ~= nil then
			Cfg[k] = data[k]
		end
	end
	St.ConfigLoaded = true
	return true
end

local function queueSaveConfig()
	task.defer(function()
		task.wait(0.05)
		saveConfig()
	end)
end

-- auto-load before UI builds
pcall(loadConfig)

local function myRoot()
	local ch = LP.Character
	return ch and (ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart)
end

local function nextStabId()
	St.Stab += 1
	-- server expects GUID strings (KnifeController uses HttpService:GenerateGUID)
	return HttpService:GenerateGUID(false)
end

local function hasFn(t, name)
	local ok, v = pcall(function()
		return t[name]
	end)
	return ok and type(v) == "function"
end

local function scanControllers(force)
	local now = os.clock()
	if not force and now - (St.LastCtrlScan or 0) < 2 then
		return
	end
	St.LastCtrlScan = now
	if not getgc then return end
	for _, v in ipairs(getgc(true)) do
		if type(v) == "table" then
			if not St.KnifeCtrl and rawget(v, "reportHitSignal") and rawget(v, "throwKnifeSignal") and rawget(v, "player") == LP then
				St.KnifeCtrl = v
			end
			if not St.MatchCtrl and hasFn(v, "IsLocalPlayerAlive") and hasFn(v, "GetActiveMatchData") and hasFn(v, "IsPlayerEnemy") then
				St.MatchCtrl = v
			end
			if rawget(v, "enterTrainingRemote") ~= nil or rawget(v, "inTraining") ~= nil then
				St.TrainCtrl = v
			end
			if rawget(v, "BotDuelState") ~= nil then
				St.BotCtrl = v
			elseif not St.BotCtrl and rawget(v, "state") ~= nil and hasFn(v, "GetBotModel") and hasFn(v, "IsBotTarget") then
				St.BotCtrl = v
			end
		end
	end
end

local function getTrainBotFlags()
	scanControllers(false)
	local training = St.TrainCtrl and St.TrainCtrl.inTraining == true or false
	local bot = false
	if St.BotCtrl and hasFn(St.BotCtrl, "IsActive") then
		local ok, r = pcall(function()
			return St.BotCtrl:IsActive()
		end)
		bot = ok and r == true
	end
	St.CachedTraining = training
	St.CachedBot = bot
	return training, bot
end

local function isAliveModel(model)
	if not model or not model:IsA("Model") then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function isEnemy(model)
	if not isAliveModel(model) then return false end
	local plr = Players:GetPlayerFromCharacter(model)
	if plr then return plr ~= LP end
	if not Cfg.IncludeBots then return false end
	if model:GetAttribute("Dead") == true then return false end
	if model:GetAttribute("CombatTargetKind") == "Bot" then return true end
	if model:GetAttribute("IsTrainingDummy") == true then return true end
	local n = model.Name:lower()
	return n:find("dummy") or n:find("bot") or n:find("target") or false
end

local function getHeadPos(model)
	local head = model:FindFirstChild("Head")
	if head then return head.Position end
	local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if hrp then return hrp.Position + Vector3.new(0, 1.5, 0) end
	return nil
end

-- ── FX folder ───────────────────────────────────────────────────────────────
St.FxFolder = Instance.new("Folder")
St.FxFolder.Name = "KD_FX"
St.FxFolder.Parent = workspace

local function ensureFx()
	if St.FxFolder and St.FxFolder.Parent then return St.FxFolder end
	St.FxFolder = Instance.new("Folder")
	St.FxFolder.Name = "KD_FX"
	St.FxFolder.Parent = workspace
	return St.FxFolder
end

-- ── rainbow throw tracer ────────────────────────────────────────────────────
local function spawnRainbowTracer(fromPos, toPos)
	if not Cfg.RainbowTracer then return end
	local folder = ensureFx()
	local a = Instance.new("Part")
	a.Name = "KD_TraceA"
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(0.05, 0.05, 0.05)
	a.CFrame = CFrame.new(fromPos)
	a.Parent = folder
	local b = a:Clone()
	b.Name = "KD_TraceB"
	b.CFrame = CFrame.new(toPos)
	b.Parent = folder
	local att0 = Instance.new("Attachment", a)
	local att1 = Instance.new("Attachment", b)
	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.FaceCamera = true
	beam.Width0 = 0.35
	beam.Width1 = 0.08
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Texture = "rbxassetid://446111271"
	beam.TextureSpeed = 3
	beam.TextureLength = 1.2
	local h = St.Hue
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hsv(h, 0.85, 1)),
		ColorSequenceKeypoint.new(0.5, hsv(h + 0.33, 0.9, 1)),
		ColorSequenceKeypoint.new(1, hsv(h + 0.66, 0.85, 1)),
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.55),
	})
	beam.Parent = a
	Debris:AddItem(a, Cfg.TracerLife)
	Debris:AddItem(b, Cfg.TracerLife)
end

-- ── combat ──────────────────────────────────────────────────────────────────
local function getKnifeController()
	if St.KnifeCtrl and rawget(St.KnifeCtrl, "reportHitSignal") and rawget(St.KnifeCtrl, "player") == LP then
		return St.KnifeCtrl
	end
	scanControllers(true)
	return St.KnifeCtrl
end

local function getMatchController()
	if St.MatchCtrl and hasFn(St.MatchCtrl, "IsLocalPlayerAlive") then
		return St.MatchCtrl
	end
	scanControllers(true)
	return St.MatchCtrl
end

local function getEquippedKnifeId()
	local ch = LP.Character
	local eq = ch and ch:FindFirstChild("EquippedKnife")
	if eq then
		local main = eq:FindFirstChild("Main")
		if main then
			for _, c in ipairs(main:GetChildren()) do
				return c.Name
			end
		end
	end
	return LP:GetAttribute("EquippedKnife") or "Default"
end

local function combatReady()
	local ctrl = getKnifeController()
	local ch = LP.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not (ch and hum and hum.Health > 0) then
		return false, "dead", ctrl
	end
	if not ch:FindFirstChild("EquippedKnife") then
		return false, "no knife", ctrl
	end
	local training, bot = getTrainBotFlags()
	if training or bot then
		return true, training and "training" or "bot", ctrl
	end
	local mc = getMatchController()
	if mc then
		local okAlive, alive = pcall(function()
			return mc:IsLocalPlayerAlive()
		end)
		-- kills only register while InProgress + in alivePlayers (not lobby / RoundEnded)
		if okAlive and alive == true then
			return true, "LIVE", ctrl
		end
		local okData, data = pcall(function()
			return mc:GetActiveMatchData()
		end)
		local state = (okData and type(data) == "table") and data.state or nil
		return false, tostring(state or "lobby"), ctrl
	end
	return false, "no-match", ctrl
end

local function markAttack(model)
	if model then
		St.MarkedKills[model] = os.clock()
	end
end

local function fireReport(model, attackType, headshot, idA, idB, hitPos, stage)
	local ctrl = getKnifeController()
	if ctrl and ctrl.reportHitSignal and type(ctrl.reportHitSignal.Fire) == "function" then
		pcall(function()
			ctrl.reportHitSignal:Fire(model, attackType, headshot, idA, idB, hitPos, stage)
		end)
	end
	pcall(function()
		ReportHit:FireServer(model, attackType, headshot, idA, idB, hitPos, stage)
	end)
	if HitDummy and not Players:GetPlayerFromCharacter(model) then
		pcall(function()
			HitDummy:FireServer(model, attackType, headshot, idA, idB, hitPos, stage)
		end)
	end
	markAttack(model)
	St.Fires += 1
end

local function isValidCombatTarget(model)
	if not isAliveModel(model) then return false end
	local plr = Players:GetPlayerFromCharacter(model)
	local training, bot = getTrainBotFlags()
	if plr then
		if plr == LP then return false end
		if training or bot then return true end
		local mc = getMatchController()
		if not mc then return false end
		local okEn, isEn = pcall(function()
			return mc:IsPlayerEnemy(plr)
		end)
		local okAl, isAl = pcall(function()
			return mc:IsPlayerAlive(plr)
		end)
		return okEn and isEn == true and okAl and isAl == true
	end
	if not Cfg.IncludeBots then return false end
	if model:GetAttribute("Dead") == true then return false end
	if model.Name:find("RagdollVisualProxy") then return false end
	if model:GetAttribute("CombatTargetKind") == "Bot" then return true end
	if model:GetAttribute("CombatTargetKind") == "Dummy" then return training end
	if model:GetAttribute("IsTrainingDummy") == true then return training end
	return false
end

local function reportMelee(model, hitPos)
	local stage = (St.Stab % 3) + 1
	local stabId = nextStabId()
	local ctrl = getKnifeController()
	if ctrl then
		ctrl.attackStage = stage
		ctrl.currentStabId = stabId
		pcall(function()
			ctrl.lastKnifeTime = 0
			ctrl.nextKnifeTime = 0
			ctrl.throwStabDebounceUntil = 0
		end)
	end
	-- headshot=true => 100 dmg (KnifeHeadshotDamage)
	fireReport(model, AT_KNIFE, true, nil, stabId, hitPos, stage)
	-- also drive client hit-detection path (uses camera look + HRP box)
	if ctrl and hasFn(ctrl, "_PerformHitDetection") then
		pcall(function()
			ctrl:_PerformHitDetection()
		end)
	end
	if ctrl and hasFn(ctrl, "_ReportPredictedHit") then
		pcall(function()
			ctrl:_ReportPredictedHit(model, AT_KNIFE, true, stage, nil, stabId, hitPos)
		end)
	end
end

-- CFrame standing behind target head, facing through their skull (melee box in front)
local function behindHeadCFrame(model)
	local head = model:FindFirstChild("Head")
	local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not head and not hrp then return nil end
	local focus = head and head.Position or (hrp.Position + Vector3.new(0, 1.55, 0))
	-- prefer body look (head look can be noisy)
	local back = (hrp and hrp.CFrame.LookVector) or (head and head.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local flat = Vector3.new(back.X, 0, back.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	local studs = math.clamp(Cfg.BehindHeadStuds or 1.85, 0.8, 4)
	-- stand slightly above feet height relative to head
	local pos = focus - flat * studs - Vector3.new(0, 0.35, 0)
	return CFrame.lookAt(pos, focus), focus, pos
end

local function getArmMotors(char)
	local list = {}
	if not char then return list end
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") then
			local n = m.Name
			if n == "RightShoulder" or n == "RightElbow" or n == "RightWrist"
				or n == "Right Shoulder" or n == "Right Elbow"
				or (m.Part1 and (m.Part1.Name == "RightUpperArm" or m.Part1.Name == "RightLowerArm" or m.Part1.Name == "RightHand")) then
				list[#list + 1] = m
			end
		end
	end
	return list
end

local function stopArmAnims(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	pcall(function()
		for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
			-- don't kill movement core if possible — soft weight down
			pcall(function()
				tr:AdjustWeight(0.05, 0.05)
			end)
		end
	end)
end

-- Point R15 right arm at focus using Motor6D.Transform (overrides anims on Stepped)
local function applyArmReach(char, focus, rootPos)
	if not Cfg.ArmSnap or not char or not focus then return end
	local motors = St.ArmMotors
	if not motors or #motors == 0 then
		motors = getArmMotors(char)
		St.ArmMotors = motors
	end
	local shoulder, elbow, wrist
	for _, m in ipairs(motors) do
		if m.Name == "RightShoulder" or (m.Part1 and m.Part1.Name == "RightUpperArm") then
			shoulder = m
		elseif m.Name == "RightElbow" or (m.Part1 and m.Part1.Name == "RightLowerArm") then
			elbow = m
		elseif m.Name == "RightWrist" or (m.Part1 and m.Part1.Name == "RightHand") then
			wrist = m
		end
	end
	local origin = rootPos or (char:FindFirstChild("UpperTorso") and char.UpperTorso.Position) or char:GetPivot().Position
	local dir = focus - origin
	if dir.Magnitude < 0.05 then return end
	dir = dir.Unit
	-- approximate aim angles
	local pitch = math.asin(math.clamp(-dir.Y, -1, 1))
	local yaw = math.atan2(-dir.X, -dir.Z)
	local rootLook = char:FindFirstChild("HumanoidRootPart")
	local bodyYaw = 0
	if rootLook then
		local fl = rootLook.CFrame.LookVector
		bodyYaw = math.atan2(-fl.X, -fl.Z)
	end
	local relYaw = yaw - bodyYaw
	pcall(function()
		if shoulder then
			shoulder.Transform = CFrame.Angles(pitch - 0.4, 0, -1.15 + relYaw * 0.35)
				* CFrame.Angles(0, relYaw * 0.5, 0)
		end
		if elbow then
			elbow.Transform = CFrame.Angles(-0.15, 0, 0)
		end
		if wrist then
			wrist.Transform = CFrame.Angles(0.2, 0, 0)
		end
	end)
	-- knife handle toward head
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			local handle = t:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				pcall(function()
					handle.CFrame = CFrame.lookAt(focus - dir * 0.55, focus)
				end)
			end
		end
	end
end

local function clearHold()
	if St.HoldConn then
		pcall(function() St.HoldConn:Disconnect() end)
		St.HoldConn = nil
	end
	St.ArmMotors = nil
end

local function instantKillAt(model)
	if not model or St.InstantBusy then return false end
	local ready, why = combatReady()
	if not ready then
		St.Status = "wait: " .. tostring(why)
		return false
	end
	if not isValidCombatTarget(model) then
		St.Status = "bad target"
		return false
	end
	local root = myRoot()
	local char = LP.Character
	if not root or not char then return false end

	local behindCf, focus = behindHeadCFrame(model)
	if not behindCf or not focus then return false end

	St.InstantBusy = true
	clearHold()
	local savedCf = root.CFrame
	local savedCam = Cam.CFrame
	local savedCamType = Cam.CameraType
	local hum = char:FindFirstChildOfClass("Humanoid")
	local wasAuto = hum and hum.AutoRotate
	local holdFor = math.clamp(Cfg.HoldBehind or 0.18, 0.06, 0.6)
	local endsAt = os.clock() + holdFor
	St.ArmMotors = getArmMotors(char)
	stopArmAnims(char)

	local function applyBlinkPose()
		if not St.Alive or not char.Parent or not model.Parent then return false end
		local cf, foc = behindHeadCFrame(model)
		if not cf or not foc then return false end
		behindCf, focus = cf, foc
		pcall(function()
			if hum then hum.AutoRotate = false end
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			char:PivotTo(behindCf)
			root.CFrame = behindCf
			-- Scriptable so third-person lock can't overwrite look
			Cam.CameraType = Enum.CameraType.Scriptable
			local eye = behindCf.Position + Vector3.new(0, 1.35, 0)
			Cam.CFrame = CFrame.lookAt(eye, focus)
			applyArmReach(char, focus, behindCf.Position + Vector3.new(0, 1.2, 0))
		end)
		return true
	end

	applyBlinkPose()
	-- hold pose every Stepped (arm Transform must be post-anim)
	St.HoldConn = RunService.Stepped:Connect(function()
		if not St.Alive or os.clock() > endsAt then return end
		applyBlinkPose()
	end)

	-- stab while held behind
	local hits = math.max(Cfg.HitsPerTick or 2, 4)
	for i = 1, hits do
		if not applyBlinkPose() then break end
		reportMelee(model, focus)
		if i < hits then
			task.wait(0.03)
		end
	end

	-- keep held until HoldBehind elapses
	while os.clock() < endsAt and St.Alive do
		applyBlinkPose()
		task.wait()
	end
	clearHold()

	if Cfg.BlinkBack then
		pcall(function()
			char:PivotTo(savedCf)
			root.CFrame = savedCf
			root.AssemblyLinearVelocity = Vector3.zero
			Cam.CameraType = savedCamType or Enum.CameraType.Custom
			Cam.CFrame = savedCam
			if hum then hum.AutoRotate = wasAuto ~= false and not Cfg.Spinbot end
		end)
	else
		pcall(function()
			Cam.CameraType = savedCamType or Enum.CameraType.Custom
			if hum then hum.AutoRotate = wasAuto ~= false and not Cfg.Spinbot end
		end)
	end

	St.InstantBusy = false
	St.Status = "instakill " .. model.Name
	return true
end

local function reportThrowHit(model, hitPos, throwId, headshot)
	fireReport(model, AT_THROW, headshot ~= false, throwId, nil, hitPos, 1)
end

local function registerThrow(originCf, dir, guid, meta)
	local ctrl = getKnifeController()
	meta = meta or { isQuickShot = true, isSliding = false }
	if ctrl then
		-- clear client cooldown so AttemptThrow / projectile path accepts
		pcall(function()
			ctrl.lastThrowTime = 0
			ctrl.throwStabDebounceUntil = 0
		end)
	end
	if ctrl and ctrl.throwKnifeSignal and type(ctrl.throwKnifeSignal.Fire) == "function" then
		pcall(function()
			ctrl.throwKnifeSignal:Fire(originCf, dir, guid, meta)
		end)
	end
	if ThrowKnife then
		pcall(function()
			ThrowKnife:FireServer(originCf, dir, guid, meta)
		end)
	end
end

local function getAimPoint(model)
	local head = model:FindFirstChild("Head")
	if head then
		return head.Position, head
	end
	local upper = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if upper then
		return upper.Position + Vector3.new(0, 0.35, 0), upper
	end
	local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if hrp then
		return hrp.Position + Vector3.new(0, 1.55, 0), hrp
	end
	return nil, nil
end

local function getTargetVelocity(model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.AssemblyLinearVelocity
	end
	return Vector3.zero
end

local function predictThrowAim(model, origin)
	local pos = getAimPoint(model)
	if not pos then return nil end
	if not Cfg.ThrowPredict then return pos end
	local vel = getTargetVelocity(model)
	local speed = math.max(Cfg.ThrowSpeed, 1)
	local aim = pos
	for _ = 1, 4 do
		local dist = (aim - origin).Magnitude
		local t = dist / speed * 1.08
		local drop = 0.5 * Cfg.ThrowDropGravity * t * t
		aim = pos + vel * t + Vector3.new(0, drop * 0.35, 0)
	end
	return aim
end

local function screenScore(worldPos)
	if not Cam then return 1e9 end
	local v, onScreen = Cam:WorldToViewportPoint(worldPos)
	if not onScreen or v.Z <= 0 then
		return 1e9
	end
	local vp = Cam.ViewportSize
	local dx = v.X - vp.X * 0.5
	local dy = v.Y - vp.Y * 0.5
	return dx * dx + dy * dy
end

local function pickThrowTarget(targets)
	local root = myRoot()
	if not root or #targets == 0 then return nil end
	local origin = root.Position
	local best, bestScore = nil, 1e18
	for _, m in ipairs(targets) do
		local aim = getAimPoint(m)
		local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		if aim and hrp then
			local dist = (hrp.Position - origin).Magnitude
			local score = dist
			if Cfg.ThrowFovPriority then
				score = screenScore(aim) * 0.015 + dist
			end
			if score < bestScore then
				bestScore = score
				best = m
			end
		end
	end
	return best
end

local function silentThrowAt(model)
	local root = myRoot()
	if not root or not model then return end
	local ready, why, ctrl = combatReady()
	if not ready then
		St.Status = "wait: " .. tostring(why)
		return
	end
	if not isValidCombatTarget(model) then
		St.Status = "bad target"
		return
	end
	local headPos = getAimPoint(model)
	if not headPos then return end

	Cam = workspace.CurrentCamera
	-- Prefer camera (legit AttemptThrow), fall back to character eyes
	local camOrigin = (Cam and Cam.CFrame.Position) or (root.Position + Vector3.new(0, 1.5, 0))
	local aim = predictThrowAim(model, camOrigin) or headPos
	local dir = aim - camOrigin
	if dir.Magnitude < 0.05 then
		dir = (Cam and Cam.CFrame.LookVector) or root.CFrame.LookVector
	else
		dir = dir.Unit
	end

	local dist = (aim - camOrigin).Magnitude
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local meleeDist = hrp and (hrp.Position - root.Position).Magnitude or dist

	-- Close: melee is far more reliable than throws
	if Cfg.KillAuraMelee and meleeDist <= (Cfg.MeleeRange or 9) then
		for _ = 1, 3 do
			reportMelee(model, getAimPoint(model) or headPos)
		end
		St.Status = "melee " .. model.Name
	end

	local travel = math.clamp(dist / math.max(Cfg.ThrowSpeed, 1) * (Cfg.ThrowHitDelayScale or 0.88), 0.015, 0.5)
	local guid = HttpService:GenerateGUID(false)
	local meta = { isQuickShot = true, isSliding = false }
	local knifeId = getEquippedKnifeId()
	local originCf = CFrame.lookAt(camOrigin, camOrigin + dir)

	if Cfg.RainbowTracer then
		spawnRainbowTracer(camOrigin, aim)
	end

	registerThrow(originCf, dir, guid, meta)
	-- do not double-register same guid from eye — server may invalidate

	if ctrl and hasFn(ctrl, "_SpawnProjectile") then
		pcall(function()
			ctrl:_SpawnProjectile(originCf, dir, knifeId, nil, true, LP, guid)
		end)
	end

	St.Throws += 1
	St.PendingThrows[guid] = true
	St.Status = string.format("throw %.0fst", dist)
	markAttack(model)

	local function confirmHit(tag)
		if not St.Alive or not isAliveModel(model) then return end
		local hitPos = getAimPoint(model) or aim
		local along = camOrigin + dir * math.min(dist, (hitPos - camOrigin).Magnitude)
		-- headshot + body backup
		reportThrowHit(model, hitPos, guid, true)
		reportThrowHit(model, along, guid, true)
		reportThrowHit(model, hitPos, guid, false)
		St.Status = (tag or "hit") .. " " .. model.Name
	end

	if Cfg.HitConfirm ~= false then
		-- multi-window: early / on-time / late (moving targets + jitter)
		task.delay(travel * 0.55, function()
			confirmHit("early")
		end)
		task.delay(travel, function()
			confirmHit("hit")
		end)
		task.delay(travel * 1.25 + 0.02, function()
			confirmHit("late")
			St.PendingThrows[guid] = nil
		end)
	else
		task.delay(travel, function()
			confirmHit("hit")
			St.PendingThrows[guid] = nil
		end)
	end
end

local function collectTargets(range, opts)
	opts = opts or {}
	local root = myRoot()
	if not root then return {} end
	local origin = root.Position
	local list = {}
	local rangeSq = range * range
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			local ch = plr.Character
			local hrp = ch:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = hrp.Position - origin
				if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= rangeSq then
					if opts.skipValidate or isValidCombatTarget(ch) then
						list[#list + 1] = ch
					end
				end
			end
		end
	end
	-- bots only via controller (never workspace:GetDescendants — that was freezing)
	if Cfg.IncludeBots and St.BotCtrl and hasFn(St.BotCtrl, "GetBotModels") then
		local ok, bots = pcall(function()
			return St.BotCtrl:GetBotModels()
		end)
		if ok and type(bots) == "table" then
			for _, m in ipairs(bots) do
				if typeof(m) == "Instance" and m:IsA("Model") then
					local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
					if hrp then
						local d = hrp.Position - origin
						if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= rangeSq and isAliveModel(m) then
							list[#list + 1] = m
						end
					end
				end
			end
		end
	end
	return list
end

local function pickNearestTarget(range)
	local root = myRoot()
	if not root then return nil end
	local best, bestD = nil, range or 220
	for _, model in ipairs(collectTargets(bestD)) do
		local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if hrp then
			local d = (hrp.Position - root.Position).Magnitude
			if d < bestD then
				bestD = d
				best = model
			end
		end
	end
	return best, bestD
end

local function instantKillTick()
	if not Cfg.InstantKill or St.InstantBusy then return end
	local now = os.clock()
	if now - (St.LastInstant or 0) < (Cfg.InstantKillInterval or 0.12) then return end
	local target = pickNearestTarget(Cfg.InstantKillRange or 220)
	if not target then return end
	St.LastInstant = now
	instantKillAt(target)
end

local function auraTick()
	local ready, why = combatReady()
	if not ready then
		St.Status = "wait: " .. tostring(why)
		return
	end
	-- Instant kill supersedes plain aura (TP behind head then stab)
	if Cfg.InstantKill then
		instantKillTick()
		return
	end
	for _, model in ipairs(collectTargets(Cfg.AuraRange)) do
		local pos = getAimPoint(model)
		if pos then
			for _ = 1, Cfg.HitsPerTick do
				reportMelee(model, pos)
			end
		end
	end
end

local function throwTick()
	local ready, why = combatReady()
	if not ready then
		St.Status = "wait: " .. tostring(why)
		return
	end
	local targets = collectTargets(Cfg.ThrowRange)
	local best = pickThrowTarget(targets)
	if best then
		silentThrowAt(best)
	end
end

-- ── third person (reapply + auto scroll out) ────────────────────────────────
local function applyThirdPerson(on, animate)
	pcall(function()
		if on then
			if St.OrigMinZoom == nil then
				St.OrigMinZoom = LP.CameraMinZoomDistance
				St.OrigMaxZoom = LP.CameraMaxZoomDistance
			end
			LP.CameraMode = Enum.CameraMode.Classic
			local target = math.clamp(Cfg.CameraDistance, 4, 32)
			if animate ~= false then
				local start = math.min(LP.CameraMaxZoomDistance, 2)
				task.spawn(function()
					local steps = 18
					for i = 1, steps do
						if not St.Alive or not Cfg.ThirdPerson then return end
						local z = start + (target - start) * (i / steps)
						LP.CameraMinZoomDistance = z
						LP.CameraMaxZoomDistance = z
						task.wait(Cfg.ZoomOutSpeed)
					end
					LP.CameraMinZoomDistance = target
					LP.CameraMaxZoomDistance = target
				end)
			else
				LP.CameraMinZoomDistance = target
				LP.CameraMaxZoomDistance = target
			end
		else
			if St.OrigMinZoom ~= nil then
				LP.CameraMinZoomDistance = St.OrigMinZoom
				LP.CameraMaxZoomDistance = St.OrigMaxZoom
			else
				LP.CameraMinZoomDistance = 0.5
				LP.CameraMaxZoomDistance = 128
			end
		end
	end)
end

local function rebindThirdPerson(ch)
	if not Cfg.ThirdPerson then return end
	task.defer(function()
		task.wait(0.15)
		applyThirdPerson(true, true)
		task.wait(0.35)
		if Cfg.ThirdPerson then
			applyThirdPerson(true, false)
		end
	end)
	local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", 5)
	if hum then
		track(hum.Died:Connect(function()
			-- next CharacterAdded will re-apply
		end))
		if Cfg.Spinbot then
			hum.AutoRotate = false
		end
	end
end

local function applySpinbot(dt)
	if not Cfg.Spinbot then return end
	local root = myRoot()
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end
	hum.AutoRotate = false
	St.SpinYaw += Cfg.SpinSpeed * dt * 60
	if St.SpinYaw > 360 then St.SpinYaw -= 360 end
	local vel = root.AssemblyLinearVelocity
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(St.SpinYaw), 0)
	root.AssemblyLinearVelocity = vel
end

-- ── ambient rainbow ─────────────────────────────────────────────────────────
local ambientCC = Instance.new("ColorCorrectionEffect")
ambientCC.Name = "KD_AmbientCC"
ambientCC.Saturation = 0.12
ambientCC.Contrast = 0.04
ambientCC.Brightness = 0.02
ambientCC.Enabled = Cfg.AmbientRainbow
ambientCC.Parent = Lighting

local ambientBloom = Instance.new("BloomEffect")
ambientBloom.Name = "KD_AmbientBloom"
ambientBloom.Intensity = 0.35
ambientBloom.Size = 18
ambientBloom.Threshold = 0.92
ambientBloom.Enabled = Cfg.AmbientRainbow
ambientBloom.Parent = Lighting

local ambientAcc = 0
local function tickAmbient(dt)
	if not Cfg.AmbientRainbow then
		if ambientCC.Enabled then
			ambientCC.Enabled = false
			ambientBloom.Enabled = false
		end
		return
	end
	ambientAcc += dt
	if ambientAcc < 0.05 then return end
	ambientAcc = 0
	ambientCC.Enabled = true
	ambientBloom.Enabled = true
	St.Hue = (St.Hue + 0.045 * 0.05) % 1
	ambientCC.TintColor = hsv(St.Hue, 0.22, 1)
	ambientBloom.Intensity = 0.28 + 0.12 * math.sin(os.clock() * 1.4)
end

-- ── death sounds (GitHub fetch + fallback) ──────────────────────────────────
local FALLBACK_DEATH = {
	"rbxassetid://7079888470", -- classic oof
	"rbxassetid://5419399757",
	"rbxassetid://6760539597",
	"rbxassetid://9113826847",
	"rbxassetid://9114221308",
	"rbxassetid://9126214085",
	"rbxassetid://5912578917",
	"rbxassetid://5153734304",
	"rbxassetid://5869422451",
	"rbxassetid://138083961",
	"rbxassetid://157878578",
	"rbxassetid://131961136",
}

local function normalizeSoundId(v)
	if type(v) == "number" then
		return "rbxassetid://" .. tostring(v)
	end
	if type(v) ~= "string" then return nil end
	if v:find("rbxassetid://", 1, true) then return v end
	if tonumber(v) then return "rbxassetid://" .. v end
	return nil
end

local function loadDeathSounds()
	local pool = {}
	-- local workspace file first (Potassium)
	pcall(function()
		if isfile and isfile("kd_death_sounds.json") then
			local body = readfile("kd_death_sounds.json")
			local data = HttpService:JSONDecode(body)
			local list = (type(data) == "table" and data.sounds) or data
			if type(list) == "table" then
				for _, v in ipairs(list) do
					local id = normalizeSoundId(v)
					if id then pool[#pool + 1] = id end
				end
			end
		end
	end)
	local urls = {
		rawget(getgenv(), "KD_DeathSoundsURL"),
		"https://raw.githubusercontent.com/BloxStreet/assets/main/death_sounds.json",
		"https://raw.githubusercontent.com/rtxts/misc-assets/main/death_sounds.json",
		"https://cdn.jsdelivr.net/gh/BloxStreet/assets@main/death_sounds.json",
	}
	if #pool == 0 then
		for _, url in ipairs(urls) do
			if type(url) == "string" and #url > 8 then
				local ok, body = pcall(function()
					return game:HttpGet(url)
				end)
				if ok and type(body) == "string" and #body > 2 then
					local okj, data = pcall(function()
						return HttpService:JSONDecode(body)
					end)
					if okj then
						local list = data
						if type(data) == "table" and data.sounds then list = data.sounds end
						if type(list) == "table" then
							for _, v in ipairs(list) do
								local id = normalizeSoundId(v)
								if id then pool[#pool + 1] = id end
							end
						end
					else
						for id in body:gmatch("%d%d%d%d%d+") do
							pool[#pool + 1] = "rbxassetid://" .. id
						end
					end
				end
			end
			if #pool > 0 then break end
		end
	end
	if #pool == 0 then
		for _, id in ipairs(FALLBACK_DEATH) do
			pool[#pool + 1] = id
		end
		St.Status = "death sounds: fallback"
	else
		St.Status = "death sounds: " .. #pool
	end
	St.DeathPool = pool
end

task.spawn(loadDeathSounds)

local function playDeathSound(atPos)
	if not Cfg.DeathSounds then return end
	local now = os.clock()
	if now - (St.LastKillAt or 0) < 0.15 then return end -- debounce spam
	St.LastKillAt = now
	local pool = St.DeathPool
	if #pool == 0 then pool = FALLBACK_DEATH end
	local id = pool[math.random(1, #pool)]
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 1.6
	s.PlaybackSpeed = 0.92 + math.random() * 0.2
	s.RollOffMaxDistance = 140
	s.Parent = SoundService
	if atPos then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = CFrame.new(atPos)
		p.Parent = ensureFx()
		s.Parent = p
		Debris:AddItem(p, 4)
	else
		Debris:AddItem(s, 4)
	end
	pcall(function()
		s:Play()
	end)
	St.Status = "kill sound"
end

local function onOurKill(modelOrPos)
	local pos = nil
	if typeof(modelOrPos) == "Instance" then
		local hrp = modelOrPos:FindFirstChild("HumanoidRootPart") or modelOrPos.PrimaryPart
		pos = hrp and hrp.Position
	elseif typeof(modelOrPos) == "Vector3" then
		pos = modelOrPos
	end
	playDeathSound(pos)
end

local function wasOurKill(model)
	local t = St.MarkedKills[model]
	return t and (os.clock() - t) < 4.5
end

local function hookDeath(char)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if not hum then return end
	track(hum.Died:Connect(function()
		-- only when we attacked them recently (our kill)
		if wasOurKill(char) then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			onOurKill(hrp and hrp.Position or char)
			St.MarkedKills[char] = nil
		end
	end))
end

for _, plr in ipairs(Players:GetPlayers()) do
	if plr ~= LP then
		if plr.Character then hookDeath(plr.Character) end
		track(plr.CharacterAdded:Connect(hookDeath))
	end
end
track(Players.PlayerAdded:Connect(function(plr)
	if plr == LP then return end
	track(plr.CharacterAdded:Connect(hookDeath))
end))

-- Server kill confirmations (most reliable for "when I kill")
do
	local function handleKillPayload(...)
		local args = { ... }
		local pos
		for _, a in ipairs(args) do
			if typeof(a) == "Instance" and a:IsA("Model") then
				onOurKill(a)
				return
			elseif typeof(a) == "Vector3" then
				pos = a
			elseif type(a) == "table" then
				if typeof(a.targetModel) == "Instance" then
					onOurKill(a.targetModel)
					return
				end
				if a.fatal == true then
					onOurKill(a.position or a.hitPosition)
					return
				end
			end
		end
		onOurKill(pos)
	end
	for _, name in ipairs({ "TargetKilled" }) do
		local re = CombatRE:FindFirstChild(name)
		if re and re:IsA("RemoteEvent") then
			track(re.OnClientEvent:Connect(handleKillPayload))
		end
	end
	local pk = CombatRE:FindFirstChild("PlayerKilled")
	if pk and pk:IsA("RemoteEvent") then
		track(pk.OnClientEvent:Connect(function(...)
			-- only if we recently attacked someone
			local recent = false
			local now = os.clock()
			for model, t in pairs(St.MarkedKills) do
				if now - t < 3 then recent = true break end
			end
			if recent then handleKillPayload(...) end
		end))
	end
	local hc = CombatRE:FindFirstChild("HitConfirmed")
	if hc and hc:IsA("RemoteEvent") then
		track(hc.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" and payload.fatal then
				handleKillPayload(payload)
			end
		end))
	end
end

-- ── godmode + speed ─────────────────────────────────────────────────────────
local function applyMovement(ch)
	ch = ch or LP.Character
	if not ch then return end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if St.OrigWalkSpeed == nil then
		St.OrigWalkSpeed = hum.WalkSpeed
	end
	if Cfg.Speed then
		hum.WalkSpeed = math.clamp(Cfg.WalkSpeed or 28, 16, 64)
	else
		hum.WalkSpeed = St.OrigWalkSpeed or Cfg.BaseWalkSpeed or 16
	end
end

local function bindGodmode(ch)
	ch = ch or LP.Character
	if not ch then return end
	local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", 5)
	if not hum then return end
	applyMovement(ch)
	track(hum.HealthChanged:Connect(function()
		if not St.Alive or not Cfg.Godmode then return end
		if hum.Health < hum.MaxHealth and hum.Health > 0 then
			hum.Health = hum.MaxHealth
		end
	end))
	track(hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if Cfg.Speed and math.abs(hum.WalkSpeed - (Cfg.WalkSpeed or 28)) > 0.5 then
			hum.WalkSpeed = Cfg.WalkSpeed or 28
		end
	end))
end

track(LP.CharacterAdded:Connect(function(ch)
	task.defer(function()
		task.wait(0.1)
		bindGodmode(ch)
	end)
end))
if LP.Character then
	task.defer(function()
		bindGodmode(LP.Character)
	end)
end

-- ── ESP (Highlight parented to character — CoreGui Highlight hits Plugin cap) ─
local espGuiParent = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 5)
local espFolder = Instance.new("Folder")
espFolder.Name = "KD_ESP"
espFolder.Parent = espGuiParent

local function clearEsp(model)
	local node = St.EspNodes[model]
	if node then
		pcall(function()
			if node.Gui then node.Gui:Destroy() end
		end)
		pcall(function()
			if node.Highlight then node.Highlight:Destroy() end
		end)
		St.EspNodes[model] = nil
	end
end

local function ensureEsp(model)
	local existing = St.EspNodes[model]
	if existing and existing.Gui and existing.Gui.Parent then
		return existing
	end
	if existing then
		clearEsp(model)
	end
	local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not hrp then return nil end

	local hl
	-- Parent Highlight to the model (not CoreGui) to avoid Plugin capability errors
	local okHl, hlOrErr = pcall(function()
		local h = Instance.new("Highlight")
		h.Name = "KD_HL"
		h.Adornee = model
		h.FillTransparency = 0.72
		h.OutlineTransparency = 0.15
		h.FillColor = Color3.fromRGB(0, 122, 255)
		h.OutlineColor = Color3.fromRGB(255, 255, 255)
		pcall(function()
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		end)
		h.Parent = model
		return h
	end)
	if okHl then
		hl = hlOrErr
	else
		St.EspOk = false
	end

	local bb, label
	local okBb = pcall(function()
		bb = Instance.new("BillboardGui")
		bb.Name = "KD_BB"
		bb.Adornee = hrp
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(140, 42)
		bb.StudsOffset = Vector3.new(0, 3.1, 0)
		bb.Parent = espFolder
		label = Instance.new("TextLabel")
		label.BackgroundTransparency = 0.35
		label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 12
		label.TextColor3 = Theme.Text
		label.TextStrokeTransparency = 0.7
		label.Text = model.Name
		label.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label
	end)
	if not okBb then
		if hl then pcall(function() hl:Destroy() end) end
		return nil
	end

	local node = { Gui = bb, Highlight = hl, Label = label }
	St.EspNodes[model] = node
	return node
end

local function tickEsp()
	if not Cfg.ESP then
		for model in pairs(St.EspNodes) do
			clearEsp(model)
		end
		return
	end
	local now = os.clock()
	if now - (St.LastEsp or 0) < 0.2 then
		return
	end
	St.LastEsp = now

	local root = myRoot()
	local seen = {}
	-- players only, cheap; skip match validation for ESP visuals
	for _, model in ipairs(collectTargets(500, { skipValidate = true })) do
		if Players:GetPlayerFromCharacter(model) then
			seen[model] = true
			local node = ensureEsp(model)
			if node and node.Label then
				local hum = model:FindFirstChildOfClass("Humanoid")
				local hrp = model:FindFirstChild("HumanoidRootPart")
				local dist = (root and hrp) and math.floor((hrp.Position - root.Position).Magnitude + 0.5) or 0
				local hp = hum and math.floor(hum.Health + 0.5) or 0
				node.Label.Text = string.format("%s\n%d hp · %dm", model.Name, hp, dist)
				if node.Highlight then
					pcall(function()
						local col = hsv(St.Hue + dist * 0.002, 0.75, 1)
						node.Highlight.FillColor = col
						node.Highlight.OutlineColor = Color3.new(1, 1, 1)
						node.Highlight.Enabled = true
					end)
				end
			end
		end
	end
	for model in pairs(St.EspNodes) do
		if not seen[model] or not model.Parent then
			clearEsp(model)
		end
	end
end

-- ── skins ───────────────────────────────────────────────────────────────────
local function getKnivesOwned()
	local done, inv = false, nil
	task.spawn(function()
		local ok, r = pcall(function()
			return RS.InventoryReplicationService.RF.GetInventorySnapshot:InvokeServer()
		end)
		if ok then inv = r end
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 2.5 do
		task.wait()
	end
	if type(inv) == "table" and type(inv.KnivesOwned) == "table" then
		return inv.KnivesOwned
	end
	return {}
end

local function getKnifeUIController()
	local ps = LP:FindFirstChild("PlayerScripts")
	if not ps then return nil end
	for _, d in ipairs(ps:GetDescendants()) do
		if d:IsA("ModuleScript") and d.Name == "KnifeUIController" then
			local ok, ctrl = pcall(require, d)
			if ok and type(ctrl) == "table" and type(ctrl.Equip) == "function" then
				return ctrl
			end
		end
	end
	return nil
end

local function equipSkin(uuidOrName)
	if not uuidOrName or uuidOrName == "" then return end
	local owned = getKnivesOwned()
	local uuid, display = nil, tostring(uuidOrName)
	if owned[uuidOrName] then
		uuid = uuidOrName
		local d = owned[uuidOrName]
		if type(d) == "table" then
			display = d.ID or d.Id or d.KnifeId or display
		end
	else
		for id, data in pairs(owned) do
			local knifeId = type(data) == "table" and (data.ID or data.Id or data.KnifeId) or nil
			if tostring(id) == tostring(uuidOrName) or tostring(knifeId) == tostring(uuidOrName) then
				uuid = id
				display = knifeId or tostring(id)
				break
			end
		end
	end
	uuid = uuid or uuidOrName
	Cfg.SelectedSkin = display
	task.spawn(function()
		local ctrl = getKnifeUIController()
		local ok = false
		if ctrl then
			ok = pcall(function()
				ctrl:Equip(uuid)
			end)
		end
		if not ok then
			pcall(function()
				EquipKnifeRF:InvokeServer(uuid)
			end)
		end
		task.wait(0.3)
		St.Status = "equipped " .. tostring(LP:GetAttribute("EquippedKnife") or display)
	end)
	St.Equips += 1
end

local function refreshSkinList()
	local owned = getKnivesOwned()
	local list = {}
	for uuid, data in pairs(owned) do
		local knifeId = type(data) == "table" and (data.ID or data.Id or data.KnifeId) or tostring(uuid)
		list[#list + 1] = {
			Uuid = tostring(uuid),
			Id = tostring(knifeId),
			Label = tostring(knifeId),
		}
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	if #list == 0 then
		for _, n in ipairs(FALLBACK_SKINS) do
			list[#list + 1] = { Uuid = n, Id = n, Label = n }
		end
	end
	St.Skins = list
	return list
end

-- ── liquid glass UI (iOS-inspired) ──────────────────────────────────────────
local WIN_W, WIN_H = 440, 600
local blur = Instance.new("BlurEffect")
blur.Name = "KD_GlassBlur"
blur.Size = 18
blur.Parent = Lighting

local gui = Instance.new("ScreenGui")
gui.Name = "KnifeDuels"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 100
pcall(function()
	gui.Parent = CoreGui
end)
if not gui.Parent then
	gui.Parent = LP.PlayerGui
end

-- soft scrim behind panel
local scrim = Instance.new("Frame")
scrim.Name = "Scrim"
scrim.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
scrim.BackgroundTransparency = 0.78
scrim.BorderSizePixel = 0
scrim.Size = UDim2.fromScale(1, 1)
scrim.Visible = false
scrim.Parent = gui

local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.fromOffset(WIN_W, WIN_H)
window.Position = UDim2.new(1, -WIN_W - 24, 0.5, -math.floor(WIN_H / 2))
window.BackgroundColor3 = Theme.Fill
window.BackgroundTransparency = 0.12
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Parent = gui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 26)
local winStroke = Instance.new("UIStroke", window)
winStroke.Color = Theme.Stroke
winStroke.Transparency = 0.5
winStroke.Thickness = 1.1
local winGrad = Instance.new("UIGradient", window)
winGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(236, 242, 250)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 222, 238)),
})
winGrad.Rotation = 132
winGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.02),
	NumberSequenceKeypoint.new(1, 0.2),
})

-- specular highlight strip
local sheen = Instance.new("Frame")
sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sheen.BackgroundTransparency = 0.84
sheen.BorderSizePixel = 0
sheen.Size = UDim2.new(1, 0, 0, 58)
sheen.Parent = window
Instance.new("UICorner", sheen).CornerRadius = UDim.new(0, 26)
local sheenFill = Instance.new("Frame")
sheenFill.BackgroundColor3 = sheen.BackgroundColor3
sheenFill.BackgroundTransparency = sheen.BackgroundTransparency
sheenFill.BorderSizePixel = 0
sheenFill.Size = UDim2.new(1, 0, 0, 28)
sheenFill.Position = UDim2.new(0, 0, 1, -28)
sheenFill.Parent = sheen

do
	local dragging, dragStart, startPos = false, nil, nil
	track(window.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = window.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end))
	track(UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart
			window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
end

local pad = Instance.new("UIPadding", window)
pad.PaddingTop = UDim.new(0, 22)
pad.PaddingBottom = UDim.new(0, 18)
pad.PaddingLeft = UDim.new(0, 20)
pad.PaddingRight = UDim.new(0, 20)

local layout = Instance.new("UIListLayout", window)
layout.Padding = UDim.new(0, 14)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local headerRow = Instance.new("Frame")
headerRow.BackgroundTransparency = 1
headerRow.Size = UDim2.new(1, 0, 0, 34)
headerRow.LayoutOrder = 1
headerRow.Parent = window

local brand = Instance.new("TextLabel")
brand.BackgroundTransparency = 1
brand.Size = UDim2.new(1, -40, 1, 0)
brand.Font = Enum.Font.GothamBlack
brand.TextSize = 26
brand.TextXAlignment = Enum.TextXAlignment.Left
brand.TextYAlignment = Enum.TextYAlignment.Center
brand.TextColor3 = Theme.Text
brand.Text = "Knife"
brand.Parent = headerRow

local liveDot = Instance.new("Frame")
liveDot.Name = "LiveDot"
liveDot.Size = UDim2.fromOffset(9, 9)
liveDot.Position = UDim2.new(1, -42, 0.5, 0)
liveDot.AnchorPoint = Vector2.new(1, 0.5)
liveDot.BackgroundColor3 = Theme.Muted
liveDot.BorderSizePixel = 0
liveDot.Parent = headerRow
Instance.new("UICorner", liveDot).CornerRadius = UDim.new(1, 0)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(30, 30)
closeBtn.Position = UDim2.new(1, 0, 0.5, 0)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BackgroundTransparency = 0.35
closeBtn.Text = ""
closeBtn.AutoButtonColor = false
closeBtn.Parent = headerRow
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
local closeDot = Instance.new("Frame")
closeDot.Size = UDim2.fromOffset(10, 10)
closeDot.Position = UDim2.fromScale(0.5, 0.5)
closeDot.AnchorPoint = Vector2.new(0.5, 0.5)
closeDot.BackgroundColor3 = Theme.Red
closeDot.BorderSizePixel = 0
closeDot.Parent = closeBtn
Instance.new("UICorner", closeDot).CornerRadius = UDim.new(1, 0)

local caption = Instance.new("TextLabel")
caption.BackgroundTransparency = 1
caption.Size = UDim2.new(1, 0, 0, 16)
caption.Font = Enum.Font.GothamMedium
caption.TextSize = 13
caption.TextXAlignment = Enum.TextXAlignment.Left
caption.TextColor3 = Theme.Muted
caption.Text = "Combat · Player · Right Shift"
caption.LayoutOrder = 2
caption.Parent = window

-- iOS segmented control
local segment = Instance.new("Frame")
segment.Size = UDim2.new(1, 0, 0, 36)
segment.BackgroundColor3 = Color3.fromRGB(118, 118, 128)
segment.BackgroundTransparency = 0.82
segment.BorderSizePixel = 0
segment.LayoutOrder = 3
segment.Parent = window
Instance.new("UICorner", segment).CornerRadius = UDim.new(0, 11)
local segPad = Instance.new("UIPadding", segment)
segPad.PaddingTop = UDim.new(0, 3)
segPad.PaddingBottom = UDim.new(0, 3)
segPad.PaddingLeft = UDim.new(0, 3)
segPad.PaddingRight = UDim.new(0, 3)
local segLayout = Instance.new("UIListLayout", segment)
segLayout.FillDirection = Enum.FillDirection.Horizontal
segLayout.Padding = UDim.new(0, 2)

local TAB_NAMES = { "Combat", "Player", "Visuals", "Skins" }
local pages, tabButtons = {}, {}
local SEG_W = math.floor((WIN_W - 40 - 6 - 4) / #TAB_NAMES)

local contentHost = Instance.new("Frame")
contentHost.Size = UDim2.new(1, 0, 0, WIN_H - 168)
contentHost.BackgroundTransparency = 1
contentHost.ClipsDescendants = true
contentHost.LayoutOrder = 4
contentHost.Parent = window

local function makePage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Theme.Muted
	page.CanvasSize = UDim2.fromOffset(0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = contentHost
	local lay = Instance.new("UIListLayout", page)
	lay.Padding = UDim.new(0, 10)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	local p = Instance.new("UIPadding", page)
	p.PaddingBottom = UDim.new(0, 12)
	p.PaddingTop = UDim.new(0, 2)
	pages[name] = page
	return page
end

local function setTab(name)
	St.Tab = name
	for n, page in pairs(pages) do
		page.Visible = n == name
	end
	for n, btn in pairs(tabButtons) do
		local on = n == name
		tween(btn, {
			BackgroundTransparency = on and 0.08 or 1,
			TextColor3 = on and Theme.Text or Theme.Secondary,
		}, 0.22)
	end
end

for _, name in ipairs(TAB_NAMES) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1 / #TAB_NAMES, -2, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.TextColor3 = Theme.Secondary
	b.Text = name
	b.Parent = segment
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
	b.MouseButton1Click:Connect(function()
		setTab(name)
	end)
	tabButtons[name] = b
	makePage(name)
end

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Size = UDim2.new(1, 0, 0, 14)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Theme.Muted
status.Text = "..."
status.LayoutOrder = 5
status.Parent = window

-- card helper
local function card(parent)
	local c = Instance.new("Frame")
	c.Size = UDim2.new(1, 0, 0, 0)
	c.AutomaticSize = Enum.AutomaticSize.Y
	c.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	c.BackgroundTransparency = 0.32
	c.BorderSizePixel = 0
	c.Parent = parent
	Instance.new("UICorner", c).CornerRadius = UDim.new(0, 18)
	local s = Instance.new("UIStroke", c)
	s.Color = Color3.fromRGB(255, 255, 255)
	s.Transparency = 0.65
	s.Thickness = 1
	local p = Instance.new("UIPadding", c)
	p.PaddingTop = UDim.new(0, 12)
	p.PaddingBottom = UDim.new(0, 12)
	p.PaddingLeft = UDim.new(0, 14)
	p.PaddingRight = UDim.new(0, 14)
	local lay = Instance.new("UIListLayout", c)
	lay.Padding = UDim.new(0, 10)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	return c
end

local function sectionTitle(parent, text)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 14)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Theme.Muted
	l.Text = string.upper(text)
	l.Parent = parent
	return l
end

local function iosToggle(parent, label, get, set)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 32)
	row.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -58, 1, 0)
	t.Font = Enum.Font.GothamMedium
	t.TextSize = 15
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Theme.Text
	t.Text = label
	t.Parent = row
	local track = Instance.new("TextButton")
	track.Size = UDim2.fromOffset(50, 30)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.BackgroundColor3 = Theme.Green
	track.BorderSizePixel = 0
	track.Text = ""
	track.AutoButtonColor = false
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(26, 26)
	knob.Position = UDim2.new(1, -28, 0.5, 0)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	local ks = Instance.new("UIStroke", knob)
	ks.Transparency = 0.85
	ks.Color = Color3.fromRGB(0, 0, 0)
	local function paint()
		local on = get()
		tween(track, { BackgroundColor3 = on and Theme.Green or Color3.fromRGB(174, 174, 178) }, 0.2)
		tween(knob, { Position = on and UDim2.new(1, -28, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, 0.22, Enum.EasingStyle.Back)
	end
	paint()
	track.MouseButton1Click:Connect(function()
		set(not get())
		paint()
		queueSaveConfig()
	end)
	return row
end

local function iosSlider(parent, label, get, set, minV, maxV)
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.new(1, 0, 0, 52)
	wrap.Parent = parent
	local top = Instance.new("TextLabel")
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, 18)
	top.Font = Enum.Font.GothamMedium
	top.TextSize = 14
	top.TextXAlignment = Enum.TextXAlignment.Left
	top.TextColor3 = Theme.Text
	top.Parent = wrap
	local bar = Instance.new("TextButton")
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.Position = UDim2.new(0, 0, 0, 30)
	bar.BackgroundColor3 = Color3.fromRGB(174, 174, 178)
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.Parent = wrap
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0.5, 0, 1, 0)
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local function paint()
		local v = math.clamp(get(), minV, maxV)
		local a = (v - minV) / (maxV - minV)
		fill.Size = UDim2.new(a, 0, 1, 0)
		top.Text = string.format("%s  ·  %d", label, math.floor(v + 0.5))
	end
	paint()
	local function setFromX(x)
		local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local v = minV + (maxV - minV) * rel
		set(v)
		paint()
	end
	bar.MouseButton1Down:Connect(function()
		local move, up
		move = UIS.InputChanged:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
				setFromX(inp.Position.X)
			end
		end)
		up = UIS.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				move:Disconnect()
				up:Disconnect()
				queueSaveConfig()
			end
		end)
		setFromX(UIS:GetMouseLocation().X)
	end)
	return wrap
end

local function pillButton(parent, text, color, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 42)
	b.BackgroundColor3 = color or Theme.Accent
	b.BackgroundTransparency = 0.06
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 15
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = text
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)
	b.MouseButton1Down:Connect(function()
		tween(b, { BackgroundTransparency = 0.22 }, 0.1)
	end)
	b.MouseButton1Up:Connect(function()
		tween(b, { BackgroundTransparency = 0.06 }, 0.18)
	end)
	b.MouseButton1Click:Connect(onClick)
	return b
end

-- Combat tab
do
	local p = pages.Combat
	local c = card(p)
	sectionTitle(c, "Combat")
	iosToggle(c, "Kill Aura", function()
		return Cfg.Aura
	end, function(v)
		Cfg.Aura = v
	end)
	iosToggle(c, "Instant Kill (TP behind head)", function()
		return Cfg.InstantKill
	end, function(v)
		Cfg.InstantKill = v
	end)
	iosToggle(c, "Blink Back After Kill", function()
		return Cfg.BlinkBack
	end, function(v)
		Cfg.BlinkBack = v
	end)
	iosToggle(c, "Arm Snap To Head", function()
		return Cfg.ArmSnap
	end, function(v)
		Cfg.ArmSnap = v
	end)
	iosSlider(c, "Hold Behind (ms)", function()
		return (Cfg.HoldBehind or 0.18) * 1000
	end, function(v)
		Cfg.HoldBehind = math.clamp(v / 1000, 0.06, 0.6)
	end, 60, 600)
	iosSlider(c, "Behind Head Studs", function()
		return Cfg.BehindHeadStuds or 1.85
	end, function(v)
		Cfg.BehindHeadStuds = v
	end, 0.8, 4)
	iosToggle(c, "Silent Throw", function()
		return Cfg.SilentThrow
	end, function(v)
		Cfg.SilentThrow = v
	end)
	iosToggle(c, "Hit Confirm", function()
		return Cfg.HitConfirm
	end, function(v)
		Cfg.HitConfirm = v
	end)
	iosToggle(c, "Include Bots", function()
		return Cfg.IncludeBots
	end, function(v)
		Cfg.IncludeBots = v
	end)
	pillButton(c, "Insta Kill Nearest", Theme.Red, function()
		local best = pickNearestTarget(Cfg.InstantKillRange or 220)
		if not best then
			St.Status = "no target"
			return
		end
		instantKillAt(best)
	end)
	pillButton(c, "Nuke Nearest", Theme.Orange, function()
		local best = pickNearestTarget(math.max(Cfg.AuraRange, 18))
		if not best then
			St.Status = "no target"
			return
		end
		if Cfg.InstantKill then
			instantKillAt(best)
		else
			local pos = getAimPoint(best)
			for _ = 1, 12 do
				reportMelee(best, pos)
			end
			silentThrowAt(best)
			St.Status = "nuked " .. best.Name
		end
	end)
	pillButton(c, "Throw Nearest", Theme.Accent, function()
		throwTick()
	end)
	sectionTitle(c, "Config")
	pillButton(c, St.ConfigLoaded and "Reload Config" or "Load Config", Theme.Secondary, function()
		if loadConfig() then
			St.Status = "config loaded"
		else
			St.Status = "no config file"
		end
	end)
	pillButton(c, "Save Config Now", Theme.Accent, function()
		if saveConfig() then
			St.Status = "config saved"
		else
			St.Status = "save failed"
		end
	end)
end

-- Player tab
do
	local p = pages.Player
	local c = card(p)
	sectionTitle(c, "Local")
	iosToggle(c, "Godmode", function()
		return Cfg.Godmode
	end, function(v)
		Cfg.Godmode = v
		if v then
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = hum.MaxHealth end
		end
	end)
	iosToggle(c, "Speed", function()
		return Cfg.Speed
	end, function(v)
		Cfg.Speed = v
		applyMovement(LP.Character)
	end)
	iosSlider(c, "Walk Speed", function()
		return Cfg.WalkSpeed
	end, function(v)
		Cfg.WalkSpeed = math.floor(v + 0.5)
		if Cfg.Speed then applyMovement(LP.Character) end
	end, 16, 48)
	iosToggle(c, "Spinbot", function()
		return Cfg.Spinbot
	end, function(v)
		Cfg.Spinbot = v
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.AutoRotate = not v end
	end)
	iosToggle(c, "Third Person", function()
		return Cfg.ThirdPerson
	end, function(v)
		Cfg.ThirdPerson = v
		applyThirdPerson(v, true)
	end)
end

-- Visuals tab
do
	local p = pages.Visuals
	local c2 = card(p)
	sectionTitle(c2, "World")
	iosToggle(c2, "ESP", function()
		return Cfg.ESP
	end, function(v)
		Cfg.ESP = v
	end)
	iosToggle(c2, "Ambient Rainbow", function()
		return Cfg.AmbientRainbow
	end, function(v)
		Cfg.AmbientRainbow = v
	end)
	iosToggle(c2, "Rainbow Tracers", function()
		return Cfg.RainbowTracer
	end, function(v)
		Cfg.RainbowTracer = v
	end)
	iosToggle(c2, "Death Sounds (on your kills)", function()
		return Cfg.DeathSounds
	end, function(v)
		Cfg.DeathSounds = v
	end)
	pillButton(c2, "Reload Death Sounds", Theme.Orange, function()
		task.spawn(loadDeathSounds)
	end)
	pillButton(c2, "Test Kill Sound", Theme.Accent, function()
		playDeathSound(myRoot() and myRoot().Position)
	end)
end

-- Skins tab
do
	local p = pages.Skins
	local c = card(p)
	sectionTitle(c, "Owned knives")
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 38)
	box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	box.BackgroundTransparency = 0.4
	box.BorderSizePixel = 0
	box.Font = Enum.Font.Gotham
	box.TextSize = 14
	box.TextColor3 = Theme.Text
	box.PlaceholderText = "UUID or knife id"
	box.PlaceholderColor3 = Theme.Muted
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Parent = c
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
	pillButton(c, "Equip Typed", Theme.Green, function()
		equipSkin(box.Text)
	end)
	local listFrame = Instance.new("Frame")
	listFrame.Size = UDim2.new(1, 0, 0, 0)
	listFrame.AutomaticSize = Enum.AutomaticSize.Y
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = c
	Instance.new("UIListLayout", listFrame).Padding = UDim.new(0, 8)

	local function rebuild()
		for _, ch in ipairs(listFrame:GetChildren()) do
			if ch:IsA("TextButton") then
				ch:Destroy()
			end
		end
		for _, item in ipairs(refreshSkinList()) do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 36)
			b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			b.BackgroundTransparency = 0.45
			b.BorderSizePixel = 0
			b.AutoButtonColor = false
			b.Font = Enum.Font.GothamMedium
			b.TextSize = 14
			b.TextColor3 = Theme.Text
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = "  " .. item.Label
			b.Parent = listFrame
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
			b.MouseButton1Click:Connect(function()
				box.Text = item.Uuid
				equipSkin(item.Uuid)
			end)
		end
		St.Status = "owned " .. #St.Skins
	end
	pillButton(c, "Refresh", Theme.Accent, rebuild)
	task.defer(rebuild)
end

setTab("Combat")

-- open animation
window.Size = UDim2.fromOffset(WIN_W, 40)
tween(window, { Size = UDim2.fromOffset(WIN_W, WIN_H) }, 0.45, Enum.EasingStyle.Quint)

local collapsed = false
closeBtn.MouseButton1Click:Connect(function()
	collapsed = not collapsed
	contentHost.Visible = not collapsed
	segment.Visible = not collapsed
	status.Visible = not collapsed
	caption.Visible = not collapsed
	tween(window, { Size = collapsed and UDim2.fromOffset(WIN_W, 64) or UDim2.fromOffset(WIN_W, WIN_H) }, 0.35, Enum.EasingStyle.Quint)
	blur.Enabled = not collapsed
end)

track(UIS.InputBegan:Connect(function(inp, gpe)
	if not St.Alive or gpe then return end
	if inp.KeyCode == Enum.KeyCode.RightShift then
		gui.Enabled = not gui.Enabled
		blur.Enabled = gui.Enabled and not collapsed
	elseif inp.KeyCode == Enum.KeyCode.K then
		Cfg.Aura = not Cfg.Aura
		St.Status = Cfg.Aura and "aura on" or "aura off"
	elseif inp.KeyCode == Enum.KeyCode.I then
		Cfg.InstantKill = not Cfg.InstantKill
		St.Status = Cfg.InstantKill and "instakill on" or "instakill off"
	elseif inp.KeyCode == Enum.KeyCode.L then
		Cfg.SilentThrow = not Cfg.SilentThrow
		St.Status = Cfg.SilentThrow and "throw on" or "throw off"
	elseif inp.KeyCode == Enum.KeyCode.J then
		Cfg.Spinbot = not Cfg.Spinbot
		St.Status = Cfg.Spinbot and "spin on" or "spin off"
	elseif inp.KeyCode == Enum.KeyCode.V then
		local best = pickNearestTarget(Cfg.InstantKillRange or 220)
		if best then
			instantKillAt(best)
		else
			St.Status = "no target"
		end
	end
end))

track(RunService.RenderStepped:Connect(function(dt)
	if not St.Alive then return end
	applySpinbot(dt)
	tickAmbient(dt)
	-- keep third person locked if game resets zoom
	if Cfg.ThirdPerson then
		local d = Cfg.CameraDistance
		if math.abs(LP.CameraMinZoomDistance - d) > 0.4 or math.abs(LP.CameraMaxZoomDistance - d) > 0.4 then
			LP.CameraMinZoomDistance = d
			LP.CameraMaxZoomDistance = d
		end
	end
end))

local uiAcc = 0
local moveAcc = 0
track(RunService.Heartbeat:Connect(function(dt)
	if not St.Alive then return end
	local now = os.clock()
	if Cfg.Aura and now - St.LastAura >= Cfg.AuraInterval then
		St.LastAura = now
		auraTick()
	elseif Cfg.InstantKill and not Cfg.Aura and now - (St.LastInstant or 0) >= (Cfg.InstantKillInterval or 0.12) then
		-- Instant kill can run without Kill Aura toggle
		instantKillTick()
	end
	if Cfg.SilentThrow and now - St.LastThrow >= Cfg.ThrowInterval then
		St.LastThrow = now
		throwTick()
	end
	tickEsp()

	moveAcc += dt
	if moveAcc >= 0.15 then
		moveAcc = 0
		local ch = LP.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then
			if Cfg.Godmode and hum.Health > 0 and hum.Health < hum.MaxHealth then
				hum.Health = hum.MaxHealth
			end
			if Cfg.Speed then
				local want = Cfg.WalkSpeed or 28
				if math.abs(hum.WalkSpeed - want) > 0.5 then
					hum.WalkSpeed = want
				end
			end
		end
	end

	uiAcc += dt
	if uiAcc >= 0.2 then
		uiAcc = 0
		local ready, why = combatReady()
		status.Text = string.format(
			"%s · %s · hits %d · throws %d",
			St.Status,
			ready and "LIVE" or tostring(why),
			St.Fires,
			St.Throws
		)
		status.TextColor3 = ready and Theme.Green or Theme.Muted
		if liveDot then
			liveDot.BackgroundColor3 = ready and Theme.Green or Theme.Orange
		end
	end
end))

track(LP.CharacterAdded:Connect(function(ch)
	rebindThirdPerson(ch)
	St.OrigWalkSpeed = nil
end))
if LP.Character then
	rebindThirdPerson(LP.Character)
end
if Cfg.ThirdPerson then
	applyThirdPerson(true, true)
end

function api.Destroy()
	St.Alive = false
	Cfg.Aura = false
	Cfg.SilentThrow = false
	Cfg.InstantKill = false
	Cfg.Spinbot = false
	St.InstantBusy = false
	clearHold()
	pcall(saveConfig)
	Cfg.ESP = false
	Cfg.AmbientRainbow = false
	Cfg.Godmode = false
	Cfg.Speed = false
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		if St.OrigWalkSpeed then hum.WalkSpeed = St.OrigWalkSpeed end
	end
	applyThirdPerson(false)
	for model in pairs(St.EspNodes) do
		clearEsp(model)
	end
	for _, inst in ipairs({ blur, ambientCC, ambientBloom, espFolder, St.FxFolder, gui }) do
		if inst then
			pcall(function()
				inst:Destroy()
			end)
		end
	end
	for _, c in ipairs(St.Conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(St.Conns)
	if rawget(getgenv(), "KnifeDuels") == api then
		getgenv().KnifeDuels = nil
	end
end

getgenv().KnifeDuels = api
api.SaveConfig = saveConfig
api.LoadConfig = loadConfig
if not St.ConfigLoaded then
	pcall(saveConfig) -- write defaults on first run
	St.Status = "ready · config created"
else
	St.Status = "ready · config autoloaded"
end
print("[KnifeDuels] finished loading modules")

end)

if not okLoad then
	warn("[KnifeDuels] load failed:", loadErr)
end
