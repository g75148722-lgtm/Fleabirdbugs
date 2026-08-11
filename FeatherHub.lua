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

-- All known game modules are fetched every time (each is a few KB, so this is
-- cheap) and Hub.lua matches the right one against the live game.PlaceId using
-- each module's own declared PlaceIds. Single source of truth = the module
-- itself, so there's no separate id table here that can drift out of sync
-- and silently fail to detect a place.
local ALL_FILES = { "SoundSpace.lua", "KnifeDuels.lua", "DuelingGrounds.lua" }

local games = {}
for _, file in ipairs(ALL_FILES) do
	local ok, mod = pcall(loadRel, "Games/" .. file)
	if ok and type(mod) == "table" then
		games[#games + 1] = mod
	else
		warn("[FeatherHub] module fail", file, mod)
	end
end

local session = startHub(Library, {
	Games = games,
	Remote = REMOTE,
	Fetch = fetch,
})
if session then
	getgenv().FeatherHub = session
	print("[FeatherHub] ready PlaceId=", PlaceId)
end

end)

if not okAll then
	warn("[FeatherHub] FATAL:", errAll)
	if setclipboard then pcall(setclipboard, tostring(errAll)) end
end
