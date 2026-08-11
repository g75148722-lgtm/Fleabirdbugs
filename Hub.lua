--[[
  FeatherHub - core router
  Detects PlaceId and mounts the matching game module into the UILib window.
]]

return function(Library, helpers)
	helpers = helpers or {}

	local Players = game:GetService("Players")
	local MarketplaceService = game:GetService("MarketplaceService")
	local RunService = game:GetService("RunService")

	local placeId = game.PlaceId
	local placeName = "Unknown"
	pcall(function()
		placeName = MarketplaceService:GetProductInfo(placeId).Name
	end)

	-- wipe prior hub session
	local prev = rawget(getgenv(), "FeatherHubSession")
	if type(prev) == "table" and type(prev.Destroy) == "function" then
		pcall(prev.Destroy)
	end

	local session = {
		Connections = {},
		Game = nil,
		GameDestroy = nil,
		Destroy = function(self)
			if self.GameDestroy then
				pcall(self.GameDestroy)
			end
			if self.Game and self.Game.Destroy then
				pcall(self.Game.Destroy, self.Game)
			end
			for _, c in ipairs(self.Connections) do
				pcall(function() c:Disconnect() end)
			end
			table.clear(self.Connections)
			Library:Unload()
			if rawget(getgenv(), "FeatherHubSession") == self then
				getgenv().FeatherHubSession = nil
			end
		end,
	}
	getgenv().FeatherHubSession = session

	local function track(c)
		table.insert(session.Connections, c)
		return c
	end

	local Window = Library:CreateWindow({
		Title = "Feather Hub",
		Subtitle = placeName .. "  |  " .. tostring(placeId),
		Size = Vector2.new(580, 420),
		Blur = 16,
	})

	local home = Window:CreateTab({ Name = "Home", Icon = "H" })
	local info = home:Section("SESSION")
	info:Label("Game: " .. placeName)
	info:Label("PlaceId: " .. tostring(placeId))
	info:Label("User: " .. Players.LocalPlayer.Name)
	info:Label("Hub auto-selects the module for this place.")
	info:Button("Unload Hub", function()
		session:Destroy()
	end)

	local statusSec = home:Section("STATUS")
	local statusLabel = statusSec:Label("Resolving game module...")

	local function setStatus(t)
		statusLabel.Text = tostring(t)
		Window:SetFooter(t)
	end

	-- registry from helpers.Games list
	local games = helpers.Games or {}
	local matched = nil
	for _, mod in ipairs(games) do
		if type(mod) == "table" and not mod._Stub and type(mod.PlaceIds) == "table" then
			for _, id in ipairs(mod.PlaceIds) do
				if tonumber(id) == placeId then
					matched = mod
					break
				end
			end
		end
		if matched then break end
	end

	local catalog = home:Section("SUPPORTED GAMES")
	for _, mod in ipairs(games) do
		local ids = {}
		for _, id in ipairs(mod.PlaceIds or {}) do
			ids[#ids + 1] = tostring(id)
		end
		local icon = mod.Icon and (mod.Icon .. " ") or ""
		local mark = (matched and matched.Name == mod.Name) and "  < active" or ""
		catalog:Label(icon .. (mod.Name or "?") .. "  [" .. table.concat(ids, ", ") .. "]" .. mark)
	end

	if not matched then
		setStatus("No module for this place - universal tools only")
		local uni = Window:CreateTab({ Name = "Universal" })
		local u = uni:Section("QUICK")
		u:Label("This place is not mapped yet. Add a module under FeatherHub/Games.")
		u:Button("Notify PlaceId", function()
			Library:Notify("PlaceId", tostring(placeId), 4)
			if setclipboard then pcall(setclipboard, tostring(placeId)) end
		end)
		Library:Notify("Feather Hub", "Unsupported place " .. tostring(placeId), 4)
		return session
	end

	setStatus("Loading " .. (matched.Name or "module") .. "...")
	Window:SetSubtitle(matched.Name .. "  |  " .. tostring(placeId))

	local ok, err = pcall(function()
		session.Game = matched
		if matched.Init then
			local ctx = {
				PlaceId = placeId,
				PlaceName = placeName,
				Track = track,
				SetStatus = setStatus,
				Helpers = helpers,
				GameDestroy = nil,
			}
			matched.Init(Library, Window, ctx)
			session.GameDestroy = ctx.GameDestroy
		end
	end)

	if ok then
		setStatus(matched.Name .. " ready")
		Library:Notify("Feather Hub", matched.Name .. " loaded", 3)
	else
		setStatus("Module error: " .. tostring(err))
		Library:Notify("Feather Hub", "Load failed: " .. tostring(err), 5)
		warn("[FeatherHub] module error:", err)
	end

	return session
end
