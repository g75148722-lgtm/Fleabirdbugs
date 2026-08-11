--[[ Sound Space - AutoPlay hard-locks note pos fast (v3 pipeline) ]]
return {
	Name = "Sound Space",
	Icon = "M",
	PlaceIds = { 2677609345 },
	Init = function(Library, Window, ctx)
		local RunService = game:GetService("RunService")
		local RF = game:GetService("ReplicatedFirst")
		local GM = require(RF.Modules:WaitForChild("GameManager"))
		local Input = assert(GM.Input, "GM.Input missing")

		local Cfg = {
			SoftAim = false,
			AutoPlay = true,
			SoftAimLegit = 30,
			AutoPlayLegit = 20,
			Lead = 0.90,
			Behind = 0.15,
		}
		local St = {
			Alive = true,
			Locks = 0,
			MissedOnPurpose = 0,
			Forced = nil,
			Skip = {},
			Bias = {},
			Phase = 0,
			IdleAng = 0,
			IdleCY = 3,
			IdleCZ = 0,
			Status = "idle",
		}

		local origUpdate = Input.Update
		local origGetPosClamped = Input.GetPosClamped
		local origPollMouse = Input.PollMouse

		local function Lauto()
			return math.clamp((tonumber(Cfg.AutoPlayLegit) or 0) / 100, 0, 1)
		end
		local function Lsoft()
			return math.clamp((tonumber(Cfg.SoftAimLegit) or 0) / 100, 0, 1)
		end

		local function musicTime(run)
			local t
			pcall(function()
				if run.Music and run.Music.GetTime then
					t = run.Music:GetTime()
				end
			end)
			return t
		end

		local function noteYZ(note)
			local cube = note.Cube
			if cube and cube.Parent then
				return cube.CFrame.Y, cube.CFrame.Z
			end
			return (note.Y or 0) * 2 + 1, (note.Z or 0) * 2 - 2
		end

		-- looser than v3 so we keep locking during chart
		local function playing(run)
			if not run then return false end
			if run._spectating or run._isPaused or run._awaitEnd then return false end
			if run.Running then return true end
			if run._wasPlaying and run._notes then return true end
			return false
		end

		local function clampPos(y, z)
			return math.clamp(y, 0.2625, 5.7375), math.clamp(z, -2.7375, 2.7375)
		end

		local function biasFor(key, L)
			local b = St.Bias[key]
			if b then return b end
			local ang = math.random() * math.pi * 2
			local rad = L * 0.12 * (0.3 + math.random() * 0.7)
			b = { y = math.cos(ang) * rad, z = math.sin(ang) * rad }
			St.Bias[key] = b
			return b
		end

		local function shouldMiss(key, L)
			if St.Skip[key] then return true end
			if L < 0.55 then return false end
			local chance = (L - 0.55) * (L - 0.55) * 0.4
			if math.random() < chance then
				St.Skip[key] = true
				St.MissedOnPurpose += 1
				return true
			end
			return false
		end

		local function nextNote(run, L, doMiss)
			local t = musicTime(run)
			if not t or not run._notes then return nil end
			local from = math.max(1, (run._noteIndex or 1) - 1)
			local to = math.min(#run._notes, (run._noteIndexLast or from) + 120)
			for i = from, to do
				local n = run._notes[i]
				if n and not run._processed[n] then
					local key = tostring(i) .. ":" .. tostring(n.Time)
					local dt = (n.Time or 0) - t
					if dt >= -Cfg.Behind and dt <= Cfg.Lead then
						if doMiss and shouldMiss(key, L) then
							-- continue
						else
							local y, z = noteYZ(n)
							local b = biasFor(key, L)
							return { i = i, y = y + b.y, z = z + b.z, dt = dt }
						end
					end
				end
			end
			return nil
		end

		local function idleCircle(dt, L)
			St.Phase += dt
			St.IdleAng += dt * (2.4 + L * 2)
			St.IdleCY += math.noise(St.Phase * 0.2, 1.4) * dt * 1.4
			St.IdleCZ += math.noise(St.Phase * 0.18, 3.1) * dt * 1.4
			St.IdleCY = math.clamp(St.IdleCY, 1.3, 4.7)
			St.IdleCZ = math.clamp(St.IdleCZ, -2.1, 2.1)
			local rad = 0.5 + L * 0.75
			local y = St.IdleCY + math.cos(St.IdleAng) * rad
			local z = St.IdleCZ + math.sin(St.IdleAng) * rad
			y, z = clampPos(y, z)
			return Vector3.new(0, y, z)
		end

		local function hardSet(self, pos)
			self._pos = pos
			self._posClamped = pos
			St.Forced = pos
		end

		local function applyAim(self)
			if not St.Alive then return end
			local useAuto = Cfg.AutoPlay == true
			local useSoft = (Cfg.SoftAim == true) and not useAuto
			if not useAuto and not useSoft then
				St.Forced = nil
				St.Status = "off"
				return
			end

			local run = GM._run
			if not playing(run) then
				St.Forced = nil
				St.Status = "waiting song"
				return
			end

			local L = useAuto and Lauto() or Lsoft()
			local tgt = nextNote(run, L, useAuto)

			if useAuto then
				if tgt then
					-- ALWAYS hard lock to note pos (fast). This is what makes hits register.
					local y, z = clampPos(tgt.y, tgt.z)
					hardSet(self, Vector3.new(0, y, z))
					St.Locks += 1
					St.Status = string.format("LOCK #%d dt=%.3f", tgt.i, tgt.dt)
				else
					hardSet(self, idleCircle(1 / 60, math.max(L, 0.35)))
					St.Status = "circle"
				end
				return
			end

			-- Soft aim
			St.Forced = nil
			if not tgt then
				St.Status = "soft idle"
				return
			end
			local cur = self._posClamped or self._pos or Vector3.new(0, 3, 0)
			if typeof(cur) ~= "Vector3" then cur = Vector3.new(0, 3, 0) end
			local gy, gz = clampPos(tgt.y, tgt.z)
			local a = math.clamp(0.88 - L * 0.5, 0.35, 0.88)
			local y = cur.Y + (gy - cur.Y) * a
			local z = cur.Z + (gz - cur.Z) * a
			y, z = clampPos(y, z)
			local pos = Vector3.new(0, y, z)
			self._pos = pos
			self._posClamped = pos
			St.Locks += 1
			St.Status = string.format("SOFT #%d", tgt.i)
		end

		Input.Update = function(self, a1, a2, a3, a4, a5, a6, a7, a8)
			local r = origUpdate(self, a1, a2, a3, a4, a5, a6, a7, a8)
			if St.Alive then
				pcall(applyAim, self)
			end
			return r
		end

		Input.GetPosClamped = function(self, a1, a2, a3, a4, a5, a6, a7, a8)
			if St.Alive and Cfg.AutoPlay and St.Forced ~= nil then
				return St.Forced
			end
			return origGetPosClamped(self, a1, a2, a3, a4, a5, a6, a7, a8)
		end

		Input.PollMouse = function(self, a1, a2, a3, a4, a5, a6, a7, a8)
			if St.Alive and Cfg.AutoPlay and playing(GM._run) then
				return
			end
			return origPollMouse(self, a1, a2, a3, a4, a5, a6, a7, a8)
		end

		local tab = Window:CreateTab({ Name = "Sound Space", Icon = "M" })
		local softT, autoT

		local aim = tab:Section("SOFT AIM")
		softT = aim:Toggle("Enable Soft Aim", Cfg.SoftAim, function(v)
			Cfg.SoftAim = v
			if v then
				Cfg.AutoPlay = false
				St.Forced = nil
				if autoT and autoT.Set then autoT:Set(false) end
			end
		end)
		aim:Slider("Soft Aim Legit", 0, 100, Cfg.SoftAimLegit, function(v)
			Cfg.SoftAimLegit = v
		end)

		local ap = tab:Section("AUTO PLAY")
		autoT = ap:Toggle("Enable Auto Play", Cfg.AutoPlay, function(v)
			Cfg.AutoPlay = v
			if v then
				Cfg.SoftAim = false
				if softT and softT.Set then softT:Set(false) end
			else
				St.Forced = nil
			end
		end)
		ap:Slider("Auto Play Legit", 0, 100, Cfg.AutoPlayLegit, function(v)
			Cfg.AutoPlayLegit = v
		end)
		ap:Label("AutoPlay hard-locks note position every frame. Legit = gap circles / rare misses.")

		local tune = tab:Section("TIMING")
		tune:Slider("Lead (ms)", 200, 1200, math.floor(Cfg.Lead * 1000), function(v)
			Cfg.Lead = v / 1000
		end)

		ctx.Track(RunService.Heartbeat:Connect(function()
			if not St.Alive then return end
			local run = GM._run
			local hs = run and string.format("H:%s M:%s", tostring(run._hit), tostring(run._missed)) or "-"
			ctx.SetStatus(string.format("SS locks:%d %s | %s", St.Locks, hs, St.Status))
		end))

		ctx.GameDestroy = function()
			St.Alive = false
			Cfg.AutoPlay = false
			Cfg.SoftAim = false
			St.Forced = nil
			Input.Update = origUpdate
			Input.GetPosClamped = origGetPosClamped
			Input.PollMouse = origPollMouse
		end

		Library:Notify("Sound Space", "AutoPlay ON - hard lock", 3)
	end,
	Destroy = function() end,
}
