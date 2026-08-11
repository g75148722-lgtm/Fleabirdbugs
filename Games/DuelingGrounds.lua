--[[ Dueling Grounds hub module ]]
return {
	Name = "Dueling Grounds",
	PlaceIds = { 94217045453265 },
	Init = function(Library, Window, ctx)
		local Players = game:GetService("Players")
		local RunService = game:GetService("RunService")
		local RS = game:GetService("ReplicatedStorage")
		local LP = Players.LocalPlayer
		local Req = RS.Remotes.PlayerCharacter.Request
		local hitboxRemote = Req.RequestHitboxOnImpact
		local resolveRemote = Req.ResolveImpact

		local Cfg = {
			AutoParry = true,
			ParryChance = 100, -- % of hits that auto-parry
			ForceResolveParry = true,
			TapBlockOnThreat = true,
			HitboxExpand = true,
			ShowHitbox = true,
			ReachStuds = 6,
			SizeMult = 2.0,
			ThreatRange = 18,
			BaseHitbox = Vector3.new(10, 4, 8),
		}

		local function shouldParry()
			if not Cfg.AutoParry then return false end
			local chance = math.clamp(tonumber(Cfg.ParryChance) or 100, 0, 100)
			if chance >= 100 then return true end
			if chance <= 0 then return false end
			return (math.random() * 100) <= chance
		end
		local St = {
			Alive = true,
			Parries = 0,
			Expands = 0,
			OrigHitbox = {},
			LastParry = 0,
			Handler = nil,
			HandlerAt = 0,
			Viz = nil,
			unhookRemote = nil,
		}

		local function getLocalHandler(force)
			local now = os.clock()
			if not force and St.Handler and (now - St.HandlerAt) < 2 and St.Handler.Root and St.Handler.Root.Parent then
				return St.Handler
			end
			St.Handler = nil
			if not getgc then return nil end
			for _, v in ipairs(getgc(true)) do
				if type(v) == "table" and rawget(v, "ActionManager") and rawget(v, "Root")
					and rawget(v, "IsLocalPlayer") and v.IsLocalPlayer then
					St.Handler = v
					St.HandlerAt = now
					return v
				end
			end
			St.HandlerAt = now
			return nil
		end

		local function expandHitboxTables(on)
			local root = RS:FindFirstChild("WeaponModulesShared")
			if not root then return end
			for _, mod in ipairs(root:GetDescendants()) do
				if mod:IsA("ModuleScript") and mod.Name:find("Attack", 1, true) then
					local ok, data = pcall(require, mod)
					if ok and type(data) == "table" and type(data.impacts) == "table" then
						for i, imp in pairs(data.impacts) do
							if type(imp) == "table" and typeof(imp.hitboxSize) == "Vector3" then
								local key = mod:GetFullName() .. "#" .. tostring(i)
								if on then
									if not St.OrigHitbox[key] then St.OrigHitbox[key] = imp.hitboxSize end
									imp.hitboxSize = St.OrigHitbox[key] * Cfg.SizeMult
									Cfg.BaseHitbox = St.OrigHitbox[key]
								elseif St.OrigHitbox[key] then
									imp.hitboxSize = St.OrigHitbox[key]
								end
							end
						end
					end
				end
			end
		end

		if hookfunction then
			local probe = Instance.new("RemoteEvent")
			local oldFS
			oldFS = hookfunction(probe.FireServer, function(self, a1, a2, a3, a4, a5, a6, a7, a8)
				if St.Alive and self == hitboxRemote and Cfg.HitboxExpand and typeof(a1) == "CFrame" then
					St.Expands += 1
					return oldFS(self, a1 * CFrame.new(0, 0, -Cfg.ReachStuds), a2, a3, a4, a5, a6, a7, a8)
				end
				if St.Alive and self == resolveRemote and Cfg.ForceResolveParry and a2 == "GetHit" and shouldParry() then
					St.Parries += 1
					return oldFS(self, a1, "Parry", a3, a4, a5, a6, a7, a8)
				end
				return oldFS(self, a1, a2, a3, a4, a5, a6, a7, a8)
			end)
			probe:Destroy()
			St.unhookRemote = function()
				pcall(function() hookfunction(Instance.new("RemoteEvent").FireServer, oldFS) end)
			end
		end

		if Cfg.HitboxExpand then pcall(expandHitboxTables, true) end

		local function destroyViz()
			if St.Viz then pcall(function() St.Viz:Destroy() end); St.Viz = nil end
		end

		local function updateViz(handler)
			if not Cfg.ShowHitbox or not Cfg.HitboxExpand or not handler or not handler.Root then
				destroyViz()
				return
			end
			if not St.Viz or not St.Viz.Parent then
				local p = Instance.new("Part")
				p.Name = "DG_HitboxViz"
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Material = Enum.Material.ForceField
				p.Color = Color3.fromRGB(220, 80, 90)
				p.Transparency = 0.72
				p.Parent = workspace.CurrentCamera or workspace
				St.Viz = p
			end
			local base = Cfg.BaseHitbox
			St.Viz.Size = Vector3.new(base.X * Cfg.SizeMult, base.Y * Cfg.SizeMult, base.Z * Cfg.SizeMult + Cfg.ReachStuds)
			local forward = Cfg.ReachStuds * 0.5
			St.Viz.CFrame = handler.Root.CFrame * CFrame.new(0, 0, -(forward + base.Z * Cfg.SizeMult * 0.5 - base.Z * 0.5))
		end

		local function tapParry(handler)
			if not handler or not handler._blockInputQueue then return end
			if os.clock() - St.LastParry < 0.22 then return end
			St.LastParry = os.clock()
			if #handler._blockInputQueue < 2 then
				handler._blockInputQueue[#handler._blockInputQueue + 1] = { state = true }
			end
			task.delay(0.18, function()
				if not St.Alive or not handler._blockInputQueue then return end
				for i = #handler._blockInputQueue, 1, -1 do
					local e = handler._blockInputQueue[i]
					if e and e.state == true then e.state = 0.05 end
				end
				pcall(function() Req.ReleaseBlock:FireServer() end)
			end)
			St.Parries += 1
		end

		local function hookResolve(handler)
			local am = handler.ActionManager
			if not am or am._dgHooked then return end
			am._dgHooked = true
			local old = am._computeImpactResolution
			if type(old) ~= "function" then return end
			am._computeImpactResolution = function(self, impact, a1, a2, a3, a4, a5, a6, a7, a8)
				local doParry = Cfg.ForceResolveParry and shouldParry()
				if doParry then handler.IsParrying = true end
				local res = old(self, impact, a1, a2, a3, a4, a5, a6, a7, a8)
				if doParry and type(res) == "table" then
					if res.result == "GetHit" or res.result == "Block" then
						local ir = impact.impactResults and impact.impactResults.Parry
						if ir then
							res.result = "Parry"
							res.resultData = ir
							St.Parries += 1
						end
					end
				end
				return res
			end
		end

		local tab = Window:CreateTab({ Name = "Dueling", Icon = "⚔" })
		local sec = tab:Section("COMBAT")
		sec:Toggle("Auto Parry", Cfg.AutoParry, function(v) Cfg.AutoParry = v end)
		sec:Slider("Parry Chance %", 0, 100, Cfg.ParryChance, function(v) Cfg.ParryChance = v end)
		sec:Toggle("Force Resolve Parry", Cfg.ForceResolveParry, function(v) Cfg.ForceResolveParry = v end)
		sec:Toggle("Hitbox Expand", Cfg.HitboxExpand, function(v)
			Cfg.HitboxExpand = v
			pcall(expandHitboxTables, v)
			if not v then destroyViz() end
		end)
		sec:Toggle("Show Hitbox", Cfg.ShowHitbox, function(v) Cfg.ShowHitbox = v; if not v then destroyViz() end end)
		sec:Toggle("Tap Block On Threat", Cfg.TapBlockOnThreat, function(v) Cfg.TapBlockOnThreat = v end)
		sec:Slider("Reach Studs", 0, 20, Cfg.ReachStuds, function(v) Cfg.ReachStuds = v end)
		sec:Slider("Size Mult (x10)", 10, 40, math.floor(Cfg.SizeMult * 10), function(v) Cfg.SizeMult = v / 10 end)

		local lastStatus = 0
		ctx.Track(RunService.Heartbeat:Connect(function()
			if not St.Alive then return end
			local handler = getLocalHandler(false)
			if handler then
				if not handler.ActionManager._dgHooked then pcall(hookResolve, handler) end
				local am = handler.ActionManager
				local pending = am and am.UnresolvedImpacts and next(am.UnresolvedImpacts) ~= nil
				if Cfg.TapBlockOnThreat and pending and shouldParry() then
					handler.IsParrying = true
					tapParry(handler)
				end
				updateViz(handler)
			else
				destroyViz()
			end
			local now = os.clock()
			if now - lastStatus > 0.2 then
				lastStatus = now
				ctx.SetStatus(string.format("DG parries:%d reach:%d", St.Parries, St.Expands))
			end
		end))

		ctx.GameDestroy = function()
			St.Alive = false
			Cfg.AutoParry = false
			Cfg.HitboxExpand = false
			destroyViz()
			pcall(expandHitboxTables, false)
			if St.unhookRemote then pcall(St.unhookRemote) end
		end
	end,
	Destroy = function() end,
}
