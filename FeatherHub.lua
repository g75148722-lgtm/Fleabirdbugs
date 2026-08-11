--[[
  Feather Hub — remote-only loader (Fleabirdbugs)
  Fetches UILib + Hub + current PlaceId module from GitHub raw.

  loadstring(game:HttpGet("https://raw.githubusercontent.com/g75148722-lgtm/Fleabirdbugs/main/FeatherHub.lua"))()
]]

local okAll, errAll = pcall(function()

local PlaceId = game.PlaceId

local REMOTE = rawget(getgenv(), "FeatherHubURL")
	or rawget(getgenv(), "FEATHER_HUB_URL")
	or "https://raw.githubusercontent.com/g75148722-lgtm/Fleabirdbugs/main/"

if type(REMOTE) ~= "string" or #REMOTE < 12 then
	error("set getgenv().FeatherHubURL to your raw GitHub base (trailing slash)")
end
if not REMOTE:match("/$") then
	REMOTE = REMOTE .. "/"
end

local PLACE_MODULE = {
	[2677609345] = "SoundSpace.lua",
	[112731528776884] = "KnifeDuels.lua",
	[85024203742894] = "KnifeDuels.lua",
	[94217045453265] = "DuelingGrounds.lua",
}

local function stripBom(s)
	if type(s) == "string" and s:sub(1, 3) == "\239\187\191" then
		return s:sub(4)
	end
	return s
end

local function httpGet(url)
	if syn and syn.request then
		local ok, res = pcall(function()
			return syn.request({ Url = url, Method = "GET" })
		end)
		if ok and res and res.Body then return res.Body end
	end
	if request then
		local ok, res = pcall(function()
			return request({ Url = url, Method = "GET" })
		end)
		if ok and res and (res.Body or res.body) then
			return res.Body or res.body
		end
	end
	if http_request then
		local ok, res = pcall(function()
			return http_request({ Url = url, Method = "GET" })
		end)
		if ok and res and (res.Body or res.body) then
			return res.Body or res.body
		end
	end
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok then return body end
	return nil
end

local function fetch(rel)
	local url = REMOTE .. rel
	local body = httpGet(url)
	if type(body) ~= "string" or #body < 20 or body:find("404: Not Found", 1, true) then
		error("FeatherHub fetch failed: " .. url)
	end
	return stripBom(body), url
end

local function loadRel(rel)
	local src, from = fetch(rel)
	local chunk, err = loadstring(src, "@" .. (from or rel))
	if not chunk then
		error("compile " .. tostring(rel) .. ": " .. tostring(err))
	end
	return chunk()
end

local Library = loadRel("UILib.lua")
local startHub = loadRel("Hub.lua")

local games = {}
local needed = PLACE_MODULE[PlaceId]
local ALL = {
	{ "SoundSpace.lua", "Sound Space", { 2677609345 }, "M" },
	{ "KnifeDuels.lua", "Knife Duels", { 112731528776884, 85024203742894 }, "K" },
	{ "DuelingGrounds.lua", "Dueling Grounds", { 94217045453265 }, "D" },
}

for _, row in ipairs(ALL) do
	local file, name, ids, icon = row[1], row[2], row[3], row[4]
	if file == needed then
		local ok, mod = pcall(loadRel, "Games/" .. file)
		if ok and type(mod) == "table" then
			mod.Icon = mod.Icon or icon
			games[#games + 1] = mod
		else
			warn("[FeatherHub] module fail", file, mod)
		end
	else
		games[#games + 1] = {
			Name = name,
			Icon = icon,
			PlaceIds = ids,
			Init = function() end,
			Destroy = function() end,
			_Stub = true,
		}
	end
end

local session = startHub(Library, {
	Games = games,
	Remote = REMOTE,
	Fetch = fetch,
})
if session then
	getgenv().FeatherHub = session
	print("[FeatherHub] ready PlaceId=", PlaceId, "module=", tostring(needed))
end

end)

if not okAll then
	warn("[FeatherHub] FATAL:", errAll)
	if setclipboard then pcall(setclipboard, tostring(errAll)) end
end
