--[[ Knife Duels - fixed ReportHit args, char spin, 3rd person zoom ]]
return {
	Name = "Knife Duels",
	Icon = "K",
	PlaceIds = { 112731528776884, 85024203742894 },
	Init = function(Library, Window, ctx)
		local Players = game:GetService("Players")
		local RunService = game:GetService("RunService")
		local RS = game:GetService("ReplicatedStorage")
		local HttpService = game:GetService("HttpService")
		local LP = Players.LocalPlayer

		local CombatRE = RS:WaitForChild("CombatService"):WaitForChild("RE")
		local ReportHit = CombatRE:WaitForChild("ReportHit")
		local ThrowHit = CombatRE:FindFirstChild("ThrowHit")
		local ThrowKnife = CombatRE:FindFirstChild("ThrowKnife")
		local HitDummy = CombatRE:FindFirstChild("HitDummy")
		local EquipKnifeRF = RS:WaitForChild("KnifeService"):WaitForChild("RF"):WaitForChild("EquipKnife")

		-- AttackType strings (CombatRules.AttackType.Knife = "Knife")
		local AT_KNIFE = "Knife"
		local AT_THROW = "Throw"
		pcall(function()
			local rules
			for _, d in ipairs(RS:GetDescendants()) do
				if d:IsA("ModuleScript") and d.Name == "CombatRules" then
					rules = require(d)
					break
				end
			end
			if rules and rules.AttackType then
				AT_KNIFE = rules.AttackType.Knife or AT_KNIFE
				AT_THROW = rules.AttackType.Throw or AT_THROW
			end
		end)

		local Cfg = {
			Aura = true,
			Range = 32,
			Hits = 10,
			SilentThrow = true,
			ThrowRange = 400,
			IncludeBots = true,
			Spinbot = false,
			SpinSpeed = 22,
			ThirdPerson = true,
			CameraDistance = 12,
		}
		local St = {
			Stab = 0,
			Fires = 0,
			Throws = 0,
			Yaw = 0,
			OrigMinZoom = nil,
			OrigMaxZoom = nil,
		}

		local function rootPart()
			local ch = LP.Character
			return ch and (ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart)
		end

		local function headPos(model)
			local h = model:FindFirstChild("Head")
			if h then return h.Position end
			local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			return r and (r.Position + Vector3.new(0, 1.5, 0))
		end

		local function isEnemy(model)
			if not model then return false end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return false end
			local plr = Players:GetPlayerFromCharacter(model)
			if plr then return plr ~= LP end
			if not Cfg.IncludeBots then return false end
			local n = model.Name:lower()
			return n:find("dummy") or n:find("bot") or n:find("target") or model:GetAttribute("IsTrainingDummy") == true
		end

		--[[
		  KnifeController fires ReportHit as:
		    Fire(model, attackType, charged, p217, p218, p219, attackStage)
		  Knife call: (model, Knife, false, nil, stabId, hitPos, stage)
		  Throw call: (model, Throw, charged, throwId, nil, hitPos, 1)
		]]
		local function reportKnife(model, pos)
			St.Stab += 1
			local stage = (St.Stab % 3) + 1
			local stabId = St.Stab
			pcall(function()
				ReportHit:FireServer(model, AT_KNIFE, false, nil, stabId, pos, stage)
			end)
			if HitDummy and not Players:GetPlayerFromCharacter(model) then
				pcall(function()
					HitDummy:FireServer(model, AT_KNIFE, false, nil, stabId, pos, stage)
				end)
			end
			St.Fires += 1
		end

		local function silentThrow(model)
			local r = rootPart()
			local cam = workspace.CurrentCamera
			if not r or not model then return end
			local head = model:FindFirstChild("Head")
			local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			local pos = head and head.Position or (hrp and (hrp.Position + Vector3.new(0, 1.55, 0)))
			if not pos then return end
			local origin = (cam and cam.CFrame.Position) or (r.Position + Vector3.new(0, 1.5, 0))
			local vel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
			local speed = 3000
			local aim = pos
			for _ = 1, 4 do
				local dist = (aim - origin).Magnitude
				local t = (dist / speed) * 1.08
				aim = pos + vel * t + Vector3.new(0, 0.5 * 100 * t * t * 0.35, 0)
			end
			local dir = aim - origin
			if dir.Magnitude < 0.05 then return end
			dir = dir.Unit
			local guid = HttpService:GenerateGUID(false)
			if ThrowKnife then
				pcall(function()
					ThrowKnife:FireServer(
						CFrame.lookAt(origin, origin + dir),
						dir,
						guid,
						{ isQuickShot = true, isSliding = false }
					)
				end)
			end
			local offsets = {
				Vector3.zero,
				Vector3.new(0, 0.12, 0),
				Vector3.new(0, -0.08, 0),
				Vector3.new(0.1, 0.05, 0),
				Vector3.new(-0.1, 0.05, 0),
				Vector3.new(0, 0.2, 0),
			}
			for i = 1, 6 do
				local hitPos = (i <= 2) and aim or (pos + offsets[i])
				pcall(function()
					ReportHit:FireServer(model, AT_THROW, true, guid, nil, hitPos, 1)
				end)
				if ThrowHit then
					pcall(function()
						ThrowHit:FireServer(model, AT_THROW, true, guid, nil, hitPos, 1)
					end)
				end
			end
			St.Throws += 1
		end

		local function targets(range)
			local r = rootPart()
			if not r then return {} end
			local out = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LP and plr.Character and isEnemy(plr.Character) then
					local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
					if hrp and (hrp.Position - r.Position).Magnitude <= range then
						out[#out + 1] = plr.Character
					end
				end
			end
			if Cfg.IncludeBots then
				for _, m in ipairs(workspace:GetChildren()) do
					if m:IsA("Model") and isEnemy(m) and not Players:GetPlayerFromCharacter(m) then
						local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
						if hrp and (hrp.Position - r.Position).Magnitude <= range then
							out[#out + 1] = m
						end
					end
				end
			end
			return out
		end

		local function applyThirdPerson(on)
			pcall(function()
				if on then
					if St.OrigMinZoom == nil then
						St.OrigMinZoom = LP.CameraMinZoomDistance
						St.OrigMaxZoom = LP.CameraMaxZoomDistance
					end
					LP.CameraMode = Enum.CameraMode.Classic
					LP.CameraMinZoomDistance = Cfg.CameraDistance
					LP.CameraMaxZoomDistance = Cfg.CameraDistance
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
		applyThirdPerson(Cfg.ThirdPerson)

		local combat = Window:CreateTab({ Name = "Combat", Icon = "K" })
		local csec = combat:Section("KILL AURA")
		csec:Toggle("Enable Aura", Cfg.Aura, function(v) Cfg.Aura = v end)
		csec:Toggle("Include Bots/Dummies", Cfg.IncludeBots, function(v) Cfg.IncludeBots = v end)
		csec:Slider("Range", 5, 80, Cfg.Range, function(v) Cfg.Range = v end)
		csec:Slider("Hits / tick", 1, 25, Cfg.Hits, function(v) Cfg.Hits = v end)
		csec:Button("Nuke Nearest", function()
			local list = targets(Cfg.Range)
			if #list == 0 then
				ctx.SetStatus("no target")
				return
			end
			local r = rootPart()
			local best, bestD = list[1], 1e9
			for _, m in ipairs(list) do
				local h = m:FindFirstChild("HumanoidRootPart")
				if h and r then
					local d = (h.Position - r.Position).Magnitude
					if d < bestD then bestD = d; best = m end
				end
			end
			local pos = headPos(best)
			for _ = 1, 30 do
				reportKnife(best, pos)
				silentThrow(best)
			end
			ctx.SetStatus("nuked " .. best.Name)
			Library:Notify("Knife Duels", "Nuked " .. best.Name, 2)
		end)

		local throw = Window:CreateTab({ Name = "Throw", Icon = "T" })
		local tsec = throw:Section("SILENT THROW")
		tsec:Toggle("Auto Silent Throw", Cfg.SilentThrow, function(v) Cfg.SilentThrow = v end)
		tsec:Slider("Throw Range", 20, 400, Cfg.ThrowRange, function(v) Cfg.ThrowRange = v end)
		tsec:Button("Throw Nearest", function()
			local list = targets(Cfg.ThrowRange)
			if #list > 0 then silentThrow(list[1]) end
		end)

		local vis = Window:CreateTab({ Name = "Visuals", Icon = "V" })
		local vsec = vis:Section("MOVEMENT / CAM")
		vsec:Toggle("Spinbot (character only)", Cfg.Spinbot, function(v)
			Cfg.Spinbot = v
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.AutoRotate = not v
			end
		end)
		vsec:Toggle("Third Person", Cfg.ThirdPerson, function(v)
			Cfg.ThirdPerson = v
			applyThirdPerson(v)
		end)
		vsec:Slider("Spin Speed", 1, 50, Cfg.SpinSpeed, function(v) Cfg.SpinSpeed = v end)
		vsec:Slider("Camera Distance", 4, 24, Cfg.CameraDistance, function(v)
			Cfg.CameraDistance = v
			if Cfg.ThirdPerson then applyThirdPerson(true) end
		end)
		vsec:Label("Spin rotates HumanoidRootPart only. Cam stays on Roblox camera.")

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

		-- Equip needs OwnedUuid from KnivesOwned, not display name
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
				task.wait(0.35)
				local equipped = LP:GetAttribute("EquippedKnife")
				ctx.SetStatus("equipped " .. tostring(equipped or display))
				Library:Notify("Knife Duels", "Equipped " .. tostring(equipped or display), 2)
			end)
		end

		local skins = Window:CreateTab({ Name = "Skins", Icon = "S" })
		local ssec = skins:Section("OWNED KNIVES (UUID)")
		local box = ssec:TextBox("UUID or knife ID", function(text, enter)
			if enter and text ~= "" then
				equipSkin(text)
			end
		end)
		ssec:Button("Equip Typed", function()
			if box.Text ~= "" then
				equipSkin(box.Text)
			end
		end)
		ssec:Button("Refresh Owned List", function()
			local owned = getKnivesOwned()
			local list = {}
			for uuid, data in pairs(owned) do
				local knifeId = type(data) == "table" and (data.ID or data.Id or data.KnifeId) or tostring(uuid)
				list[#list + 1] = { Uuid = tostring(uuid), Id = tostring(knifeId) }
			end
			table.sort(list, function(a, b)
				return a.Id < b.Id
			end)
			if #list == 0 then
				Library:Notify("Knife Duels", "No owned knives found", 2)
				return
			end
			for i, item in ipairs(list) do
				if i > 40 then break end
				ssec:Button(item.Id .. " (" .. string.sub(item.Uuid, 1, 8) .. ")", function()
					box.Text = item.Uuid
					equipSkin(item.Uuid)
				end)
			end
			Library:Notify("Knife Duels", "Loaded " .. #list .. " knives", 2)
		end)
		ssec:Label("Click Refresh, then pick a knife. Names alone do not equip.")

		ctx.Track(LP.CharacterAdded:Connect(function(ch)
			task.wait(0.3)
			if Cfg.ThirdPerson then applyThirdPerson(true) end
			local hum = ch:FindFirstChildOfClass("Humanoid")
			if hum and Cfg.Spinbot then hum.AutoRotate = false end
		end))

		-- character-only spin (never touch Camera.CFrame)
		ctx.Track(RunService.RenderStepped:Connect(function(dt)
			if not Cfg.Spinbot then return end
			local r = rootPart()
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if not r or not hum or hum.Health <= 0 then return end
			hum.AutoRotate = false
			St.Yaw += Cfg.SpinSpeed * dt * 60
			if St.Yaw > 360 then St.Yaw -= 360 end
			local vel = r.AssemblyLinearVelocity
			r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, math.rad(St.Yaw), 0)
			r.AssemblyLinearVelocity = vel
		end))

		local lastAura, lastThrow = 0, 0
		ctx.Track(RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if Cfg.Aura and now - lastAura > 0.035 then
				lastAura = now
				for _, m in ipairs(targets(Cfg.Range)) do
					local pos = headPos(m)
					if pos then
						for _ = 1, Cfg.Hits do
							reportKnife(m, pos)
						end
					end
				end
			end
			if Cfg.SilentThrow and now - lastThrow > 0.05 then
				lastThrow = now
				local list = targets(Cfg.ThrowRange)
				if #list > 0 then
					local cam = workspace.CurrentCamera
					local best, bestScore = list[1], 1e18
					for _, m in ipairs(list) do
						local h = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
						if h and cam then
							local v, on = cam:WorldToViewportPoint(h.Position)
							local score = (h.Position - (rootPart() and rootPart().Position or h.Position)).Magnitude
							if on and v.Z > 0 then
								local vp = cam.ViewportSize
								local dx, dy = v.X - vp.X * 0.5, v.Y - vp.Y * 0.5
								score = score + (dx * dx + dy * dy) * 0.015
							else
								score = score + 5000
							end
							if score < bestScore then bestScore = score; best = m end
						end
					end
					silentThrow(best)
				end
			end
			ctx.SetStatus(string.format("KD hits:%d throws:%d spin:%s 3p:%s", St.Fires, St.Throws, tostring(Cfg.Spinbot), tostring(Cfg.ThirdPerson)))
		end))

		ctx.GameDestroy = function()
			Cfg.Aura = false
			Cfg.SilentThrow = false
			Cfg.Spinbot = false
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.AutoRotate = true end
			applyThirdPerson(false)
		end

		Library:Notify("Knife Duels", "ReportHit args fixed", 3)
	end,
	Destroy = function() end,
}
