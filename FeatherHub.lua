--[[
  Feather Hub — fast remote loader (Junkie-friendly)
  Caches modules to disk · only fetches the matched game · parallel core fetch

  loadstring(game:HttpGet("https://raw.githubusercontent.com/g75148722-lgtm/Fleabirdbugs/main/FeatherHub.lua"))()
]]

local okAll, errAll = pcall(function()

local PlaceId = game.PlaceId
local t0 = os.clock()

local REMOTE = rawget(getgenv(), "FeatherHubURL")
	or rawget(getgenv(), "FEATHER_HUB_URL")
	or "https://raw.githubusercontent.com/g75148722-lgtm/Fleabirdbugs/main/"

if type(REMOTE) ~= "string" or #REMOTE < 12 then
	error("set getgenv().FeatherHubURL to your raw GitHub base (trailing slash)")
end
if not REMOTE:match("/$") then
	REMOTE = REMOTE .. "/"
end

local CACHE = "feather_cache_v4/"
local CACHE_TTL = 600 -- seconds

-- PlaceId → game file (fetch only what we need)
local PLACE_FILE = {
	[112731528776884] = "KnifeDuels.lua",
	[85024203742894]  = "KnifeDuels.lua",
	[2677609345]      = "SoundSpace.lua",
	[94217045453265]  = "DuelingGrounds.lua",
}

local function stripBom(s)
	if type(s) == "string" and s:sub(1, 3) == "\239\187\191" then
		return s:sub(4)
	end
	return s
end

local function httpGet(url)
	-- Prefer game:HttpGet first — it yields. syn.request can freeze Essential (30s watchdog).
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and #body > 20 then
		return body
	end
	if syn and syn.request then
		local ok2, res = pcall(function()
			return syn.request({ Url = url, Method = "GET" })
		end)
		if ok2 and res and res.Body then return res.Body end
	end
	if request then
		local ok2, res = pcall(function()
			return request({ Url = url, Method = "GET" })
		end)
		if ok2 and res and (res.Body or res.body) then
			return res.Body or res.body
		end
	end
	return nil
end

local canFS = (writefile and readfile and isfile and isfolder and makefolder) ~= nil

local function ensureCacheDir()
	if not canFS then return end
	pcall(function()
		if not isfolder(CACHE) then makefolder(CACHE) end
	end)
end

local function cachePath(rel)
	return CACHE .. rel:gsub("/", "_")
end

local function readCache(rel)
	if not canFS then return nil end
	local path = cachePath(rel)
	local meta = path .. ".t"
	local ok, body = pcall(function()
		if not isfile(path) or not isfile(meta) then return nil end
		local ts = tonumber(readfile(meta))
		if not ts or (os.time() - ts) > CACHE_TTL then return nil end
		return readfile(path)
	end)
	if ok and type(body) == "string" and #body > 20 then
		return body
	end
	return nil
end

local function writeCache(rel, body)
	if not canFS or type(body) ~= "string" then return end
	ensureCacheDir()
	pcall(function()
		writefile(cachePath(rel), body)
		writefile(cachePath(rel) .. ".t", tostring(os.time()))
	end)
end

local function fetch(rel)
	local cached = readCache(rel)
	if cached then return stripBom(cached), "cache:" .. rel end

	local url = REMOTE .. rel
	local body = httpGet(url)
	if type(body) ~= "string" or #body < 20 or body:find("404: Not Found", 1, true) then
		error("FeatherHub fetch failed: " .. url)
	end
	writeCache(rel, body)
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

-- Parallel-ish: kick UILib + Hub fetches close together via cache warm
ensureCacheDir()

local Library = loadRel("UILib.lua")
local startHub = loadRel("Hub.lua")

-- Only load the game module for this PlaceId (huge win vs fetching all)
local games = {}
local file = PLACE_FILE[PlaceId]
if file then
	local ok, mod = pcall(loadRel, "Games/" .. file)
	if ok and type(mod) == "table" then
		games[1] = mod
	else
		warn("[FeatherHub] module fail", file, mod)
	end
else
	-- unknown place: catalog stubs only (no full downloads)
	games = {
		{ Name = "Knife Duels", PlaceIds = { 112731528776884, 85024203742894 }, Icon = "sword", _Stub = true },
		{ Name = "Sound Space", PlaceIds = { 2677609345 }, Icon = "music", _Stub = true },
		{ Name = "Dueling Grounds", PlaceIds = { 94217045453265 }, Icon = "shield", _Stub = true },
	}
end

-- Skip MarketplaceService yield — use module name / place id
local placeName = (games[1] and not games[1]._Stub and games[1].Name) or ("Place " .. tostring(PlaceId))

local session = startHub(Library, {
	Games = games,
	Remote = REMOTE,
	Fetch = fetch,
	PlaceName = placeName,
})

if session then
	getgenv().FeatherHub = session
	print(string.format("[FeatherHub] ready PlaceId=%s in %.2fs", tostring(PlaceId), os.clock() - t0))
end

end)

if not okAll then
	warn("[FeatherHub] FATAL:", errAll)
	if setclipboard then pcall(setclipboard, tostring(errAll)) end
end
