--[[
  FeatherHub UILib v4 — Essential-inspired glass
  Left icon rail · even rows · Lucide IMAGE icons (Iconify PNG + getcustomasset)
]]

local UIS      = game:GetService("UserInputService")
local TweenSvc = game:GetService("TweenService")
local CoreGui  = game:GetService("CoreGui")
local Players  = game:GetService("Players")

local LP = Players.LocalPlayer

local T = {
	Bg       = Color3.fromRGB(8, 8, 10),
	Glass    = Color3.fromRGB(18, 18, 22),
	Panel    = Color3.fromRGB(22, 22, 26),
	Rail     = Color3.fromRGB(14, 14, 16),
	Row      = Color3.fromRGB(28, 28, 32),
	RowHover = Color3.fromRGB(36, 36, 42),
	Accent   = Color3.fromRGB(255, 255, 255),
	Text     = Color3.fromRGB(240, 240, 245),
	Muted    = Color3.fromRGB(140, 140, 150),
	Dim      = Color3.fromRGB(70, 70, 80),
	Border   = Color3.fromRGB(48, 48, 56),
	Good     = Color3.fromRGB(80, 220, 120),
	Black    = Color3.new(0, 0, 0),
	White    = Color3.new(1, 1, 1),
}

local Library = {
	Flags = {}, Connections = {}, Theme = T,
	_gui = nil, _notifyHolder = nil,
}

local function conn(c) Library.Connections[#Library.Connections + 1] = c; return c end

local function tw(obj, props, t, style, dir)
	TweenSvc:Create(obj, TweenInfo.new(t or 0.16, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

function Library:SetText(label, text)
	text = tostring(text or "")
	if label and label.Text ~= text then
		label.Text = text
	end
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = p
	return c
end

local function stroke(p, trans, thick, col)
	local s = Instance.new("UIStroke")
	s.Color = col or T.Border
	s.Transparency = trans or 0.35
	s.Thickness = thick or 1
	s.Parent = p
	return s
end

local function pad(p, t, b, l, r)
	local u = Instance.new("UIPadding")
	u.PaddingTop = UDim.new(0, t or 10)
	u.PaddingBottom = UDim.new(0, b or 10)
	u.PaddingLeft = UDim.new(0, l or 12)
	u.PaddingRight = UDim.new(0, r or 12)
	u.Parent = p
	return u
end

local function frame(p, bg, trans)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = bg or T.Panel
	f.BackgroundTransparency = trans or 0
	f.BorderSizePixel = 0
	f.Parent = p
	return f
end

local function lbl(p, txt, sz, font, col, xa)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = txt or ""
	l.TextSize = sz or 13
	l.Font = font or Enum.Font.GothamMedium
	l.TextColor3 = col or T.Text
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.Parent = p
	return l
end

local function protect(gui)
	pcall(function()
		if syn and syn.protect_gui then syn.protect_gui(gui) end
	end)
	local ok = pcall(function() gui.Parent = CoreGui end)
	if not ok then
		gui.Parent = LP:FindFirstChildOfClass("PlayerGui")
	end
end

local function onHover(obj, enter, leave)
	obj.MouseEnter:Connect(enter)
	obj.MouseLeave:Connect(leave)
end

-- ═══════════════════════════ LUCIDE IMAGE ICONS ═══════════════════════════
local ICON_DIR = "feather_icons_v1/"
local ICON_CACHE = {} -- name -> content string (rbxassetid / getcustomasset path)
local ICON_PENDING = {}

local ICON_ALIAS = {
	knife = "sword",
	combat = "swords",
	throw = "crosshair",
	visuals = "eye",
	mode = "layers-2",
	skins = "sparkles",
	universal = "globe",
	dueling = "shield",
	sound = "music",
	farm = "zap",
	info = "user",
	settings = "settings",
	home = "home",
	sword = "sword",
	crosshair = "crosshair",
	eye = "eye",
	music = "music",
	zap = "zap",
	shield = "shield",
	folder = "folder",
	search = "search",
	user = "user",
	layers = "layers",
	sliders = "sliders-horizontal",
	gamepad = "gamepad-2",
	sparkles = "sparkles",
	box = "box",
	power = "power",
	globe = "globe",
	minus = "minus",
	x = "x",
}

local function resolveIconName(name)
	local key = string.lower(tostring(name or "box"))
	return ICON_ALIAS[key] or key
end

local function httpGetBytes(url)
	if syn and syn.request then
		local ok, res = pcall(function()
			return syn.request({ Url = url, Method = "GET" })
		end)
		if ok and res and (res.Body or res.body) then
			return res.Body or res.body
		end
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

local function toCustomAsset(path)
	local fn = getcustomasset or (syn and syn.getcustomasset) or getsynasset
	if not fn then return nil end
	local ok, asset = pcall(fn, path)
	if ok and type(asset) == "string" then return asset end
	return nil
end

local function ensureIconDir()
	if isfolder and makefolder then
		pcall(function()
			if not isfolder(ICON_DIR) then makefolder(ICON_DIR) end
		end)
	end
end

local function loadIconImage(name)
	name = resolveIconName(name)
	if ICON_CACHE[name] then return ICON_CACHE[name] end

	local path = ICON_DIR .. name .. ".png"
	ensureIconDir()

	-- reuse cached file
	if isfile and isfile(path) then
		local asset = toCustomAsset(path)
		if asset then
			ICON_CACHE[name] = asset
			return asset
		end
	end

	-- fetch Lucide PNG from Iconify (white, 64px)
	local url = string.format(
		"https://api.iconify.design/lucide/%s.png?height=64&width=64&color=ffffff",
		name
	)
	local body = httpGetBytes(url)
	if type(body) ~= "string" or #body < 40 then
		return nil
	end

	if writefile then
		pcall(writefile, path, body)
		local asset = toCustomAsset(path)
		if asset then
			ICON_CACHE[name] = asset
			return asset
		end
	end

	return nil
end

local function applyIconImage(imageLabel, name)
	name = resolveIconName(name)
	local cached = ICON_CACHE[name]
	if cached then
		imageLabel.Image = cached
		return
	end

	if ICON_PENDING[name] then
		table.insert(ICON_PENDING[name], imageLabel)
		return
	end

	ICON_PENDING[name] = { imageLabel }
	task.spawn(function()
		local asset = loadIconImage(name)
		local waiters = ICON_PENDING[name]
		ICON_PENDING[name] = nil
		if not asset or not waiters then return end
		for _, img in ipairs(waiters) do
			if img and img.Parent then
				img.Image = asset
			end
		end
	end)
end

local function makeIcon(parent, name, size, color)
	size = size or 18
	color = color or T.Muted

	local host = Instance.new("Frame")
	host.Name = "Icon_" .. tostring(name)
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Size = UDim2.fromOffset(size, size)
	host.Parent = parent

	local img = Instance.new("ImageLabel")
	img.Name = "Img"
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Size = UDim2.fromScale(1, 1)
	img.Image = ""
	img.ImageColor3 = color
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = host

	applyIconImage(img, name)

	return {
		Host = host,
		Image = img,
		SetColor = function(_, col)
			img.ImageColor3 = col
		end,
	}
end

Library.MakeIcon = makeIcon
Library.PreloadIcons = function(names)
	task.spawn(function()
		for _, n in ipairs(names or {}) do
			loadIconImage(n)
		end
	end)
end

-- ─────────────────────────── NOTIFICATIONS ────────────────────────────────
function Library:Notify(title, body, duration)
	duration = duration or 3.2
	local holder = self._notifyHolder
	if not holder then return end

	local card = frame(holder, T.Glass, 0.12)
	card.Size = UDim2.fromOffset(270, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.ClipsDescendants = true
	corner(card, 14)
	stroke(card, 0.25, 1)

	local inner = frame(card, nil, 1)
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	pad(inner, 12, 14, 14, 14)

	lbl(inner, title, 13, Enum.Font.GothamBold, T.Accent).Size = UDim2.new(1, 0, 0, 16)
	local bodyLbl = lbl(inner, body, 12, Enum.Font.Gotham, T.Muted)
	bodyLbl.Size = UDim2.new(1, 0, 0, 0)
	bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
	bodyLbl.Position = UDim2.fromOffset(0, 20)
	bodyLbl.TextWrapped = true

	local progBg = frame(card, T.Dim, 0.4)
	progBg.Size = UDim2.new(1, -24, 0, 2)
	progBg.Position = UDim2.new(0, 12, 1, -8)
	corner(progBg, 1)
	local prog = frame(progBg, T.Accent, 0)
	prog.Size = UDim2.new(1, 0, 1, 0)
	corner(prog, 1)

	card.BackgroundTransparency = 1
	tw(card, { BackgroundTransparency = 0.12 }, 0.18)
	local drain = TweenSvc:Create(prog, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })
	drain:Play()
	drain.Completed:Connect(function()
		tw(card, { BackgroundTransparency = 1 }, 0.18)
		task.delay(0.2, function() pcall(function() card:Destroy() end) end)
	end)
end

-- ─────────────────────────── WINDOW ───────────────────────────────────────
function Library:CreateWindow(opts)
	opts = opts or {}
	local W = opts.Size and Vector2.new(opts.Size.X, opts.Size.Y) or Vector2.new(560, 400)
	local titleTxt = opts.Title or "Feather"
	local subTxt = opts.Subtitle or ""
	local RAIL = 56

	-- warm common Lucide PNGs in background
	Library.PreloadIcons({
		"home", "settings", "sword", "swords", "crosshair", "eye",
		"music", "shield", "sparkles", "layers-2", "layers", "globe",
		"user", "minus", "box", "zap", "folder", "sliders-horizontal",
	})

	for _, g in ipairs({ CoreGui, LP and LP:FindFirstChildOfClass("PlayerGui") }) do
		if g then
			for _, n in ipairs({ "FeatherHubV4", "FeatherHubV3", "FeatherHubV2" }) do
				local old = g:FindFirstChild(n)
				if old then old:Destroy() end
			end
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FeatherHubV4"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	protect(gui)
	self._gui = gui

	local nHolder = frame(gui, nil, 1)
	nHolder.Size = UDim2.fromOffset(290, 520)
	nHolder.Position = UDim2.new(1, -304, 0, 16)
	local nLay = Instance.new("UIListLayout", nHolder)
	nLay.Padding = UDim.new(0, 8)
	nLay.HorizontalAlignment = Enum.HorizontalAlignment.Right
	self._notifyHolder = nHolder

	-- soft shadow
	local shadow = frame(gui, T.Black, 0.7)
	shadow.Size = UDim2.fromOffset(W.X + 16, W.Y + 16)
	shadow.Position = UDim2.new(0.5, -(W.X + 16) / 2, 0.5, -(W.Y + 16) / 2 + 6)
	shadow.ZIndex = 0
	corner(shadow, 24)

	-- glass window
	local win = frame(gui, T.Bg, 0.08)
	win.Size = UDim2.fromOffset(W.X, W.Y)
	win.Position = UDim2.new(0.5, -W.X / 2, 0.5, -W.Y / 2)
	win.ZIndex = 1
	corner(win, 20)
	stroke(win, 0.2, 1, Color3.fromRGB(70, 70, 80))

	win.BackgroundTransparency = 1
	win.Size = UDim2.fromOffset(math.floor(W.X * 0.96), math.floor(W.Y * 0.96))
	tw(win, { BackgroundTransparency = 0.08, Size = UDim2.fromOffset(W.X, W.Y) }, 0.24, Enum.EasingStyle.Quad)

	conn(win:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = UDim2.new(
			win.Position.X.Scale, win.Position.X.Offset - 8,
			win.Position.Y.Scale, win.Position.Y.Offset - 2
		)
		shadow.Visible = gui.Enabled
	end))

	-- header
	local header = frame(win, T.Glass, 0.25)
	header.Size = UDim2.new(1, 0, 0, 52)
	corner(header, 20)
	local headerFill = frame(header, T.Glass, 0.25)
	headerFill.Size = UDim2.new(1, 0, 0, 16)
	headerFill.Position = UDim2.new(0, 0, 1, -16)

	do
		local dragging, dragStart, startPos
		conn(header.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = win.Position
			end
		end))
		conn(UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end))
		conn(UIS.InputChanged:Connect(function(input)
			if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local d = input.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end))
	end

	local brand = lbl(header, titleTxt, 16, Enum.Font.GothamBold, T.Accent)
	brand.Size = UDim2.fromOffset(160, 20)
	brand.Position = UDim2.fromOffset(18, 9)

	local subLbl = lbl(header, subTxt, 11, Enum.Font.Gotham, T.Muted)
	subLbl.Size = UDim2.new(1, -120, 0, 14)
	subLbl.Position = UDim2.fromOffset(18, 30)

	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.fromOffset(28, 28)
	minBtn.Position = UDim2.new(1, -42, 0.5, -14)
	minBtn.BackgroundColor3 = T.Row
	minBtn.BackgroundTransparency = 0.2
	minBtn.BorderSizePixel = 0
	minBtn.AutoButtonColor = false
	minBtn.Text = ""
	minBtn.Parent = header
	corner(minBtn, 9)
	local minIcon = makeIcon(minBtn, "minus", 14, T.Muted)
	minIcon.Host.Position = UDim2.new(0.5, -7, 0.5, -7)
	onHover(minBtn,
		function()
			tw(minBtn, { BackgroundTransparency = 0 }, 0.12)
			minIcon:SetColor(T.Text)
		end,
		function()
			tw(minBtn, { BackgroundTransparency = 0.2 }, 0.12)
			minIcon:SetColor(T.Muted)
		end)

	-- left icon rail
	local rail = frame(win, T.Rail, 0.15)
	rail.Size = UDim2.new(0, RAIL, 1, -52)
	rail.Position = UDim2.fromOffset(0, 52)

	local railLay = Instance.new("UIListLayout", rail)
	railLay.Padding = UDim.new(0, 6)
	railLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	railLay.SortOrder = Enum.SortOrder.LayoutOrder
	pad(rail, 12, 12, 0, 0)

	-- content
	local content = frame(win, nil, 1)
	content.Size = UDim2.new(1, -(RAIL + 16), 1, -96)
	content.Position = UDim2.fromOffset(RAIL + 8, 58)

	-- footer status pill
	local footer = frame(win, T.Row, 0.25)
	footer.Size = UDim2.new(1, -(RAIL + 24), 0, 28)
	footer.Position = UDim2.new(0, RAIL + 12, 1, -38)
	corner(footer, 14)
	stroke(footer, 0.45, 1)

	local statusDot = frame(footer, T.Good, 0)
	statusDot.Size = UDim2.fromOffset(7, 7)
	statusDot.Position = UDim2.fromOffset(12, 10.5)
	corner(statusDot, 4)

	local footerLbl = lbl(footer, "Ready", 11, Enum.Font.GothamMedium, T.Muted)
	footerLbl.Size = UDim2.new(1, -36, 1, 0)
	footerLbl.Position = UDim2.fromOffset(26, 0)

	local collapsed = false
	minBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		tw(win, { Size = collapsed and UDim2.fromOffset(W.X, 52) or UDim2.fromOffset(W.X, W.Y) }, 0.22)
		tw(shadow, { Size = collapsed and UDim2.fromOffset(W.X + 16, 68) or UDim2.fromOffset(W.X + 16, W.Y + 16) }, 0.22)
		rail.Visible = not collapsed
		content.Visible = not collapsed
		footer.Visible = not collapsed
	end)

	conn(UIS.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if inp.KeyCode == Enum.KeyCode.RightShift then
			gui.Enabled = not gui.Enabled
			shadow.Visible = gui.Enabled
		end
	end))

	local WindowApi = { Gui = gui, Frame = win, Tabs = {}, _selected = nil, _tabOrder = {} }
	function WindowApi:SetSubtitle(t) Library:SetText(subLbl, t) end
	function WindowApi:SetFooter(t) Library:SetText(footerLbl, t) end

	function WindowApi:CreateTab(tabOpts)
		tabOpts = type(tabOpts) == "string" and { Name = tabOpts } or (tabOpts or {})
		local name = tabOpts.Name or "Tab"
		local iconName = tabOpts.Icon or "box"

		local tabBtn = Instance.new("TextButton")
		tabBtn.Size = UDim2.fromOffset(40, 40)
		tabBtn.BackgroundColor3 = T.Row
		tabBtn.BackgroundTransparency = 1
		tabBtn.BorderSizePixel = 0
		tabBtn.AutoButtonColor = false
		tabBtn.Text = ""
		tabBtn.Parent = rail
		corner(tabBtn, 12)

		local icon = makeIcon(tabBtn, iconName, 18, T.Muted)
		icon.Host.Position = UDim2.new(0.5, -9, 0.5, -9)

		local page = Instance.new("ScrollingFrame")
		page.Name = name
		page.Size = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = T.Dim
		page.CanvasSize = UDim2.new(0, 0, 0, 0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Visible = false
		page.Parent = content

		local pageLay = Instance.new("UIListLayout", page)
		pageLay.Padding = UDim.new(0, 10)
		pageLay.SortOrder = Enum.SortOrder.LayoutOrder
		pad(page, 4, 8, 4, 8)

		local TabApi = { Name = name, Button = tabBtn, Page = page, Icon = icon }

		local function selectTab()
			for _, t in pairs(WindowApi.Tabs) do
				t.Page.Visible = false
				tw(t.Button, { BackgroundTransparency = 1 }, 0.14)
				t.Icon:SetColor(T.Muted)
			end
			page.Visible = true
			tw(tabBtn, { BackgroundTransparency = 0.15 }, 0.14)
			tabBtn.BackgroundColor3 = T.Row
			icon:SetColor(T.Accent)
			WindowApi._selected = name
		end

		tabBtn.MouseButton1Click:Connect(selectTab)
		onHover(tabBtn,
			function()
				if WindowApi._selected ~= name then
					tw(tabBtn, { BackgroundTransparency = 0.45 }, 0.1)
					icon:SetColor(T.Text)
				end
			end,
			function()
				if WindowApi._selected ~= name then
					tw(tabBtn, { BackgroundTransparency = 1 }, 0.1)
					icon:SetColor(T.Muted)
				end
			end)

		WindowApi.Tabs[name] = TabApi
		WindowApi._tabOrder[#WindowApi._tabOrder + 1] = name
		if not WindowApi._selected then
			WindowApi._selected = name
			selectTab()
		end

		function TabApi:Section(secOpts)
			secOpts = type(secOpts) == "string" and { Name = secOpts } or (secOpts or {})
			local secName = secOpts.Name or ""

			local card = frame(page, T.Panel, 0.2)
			card.Size = UDim2.new(1, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			corner(card, 14)
			stroke(card, 0.4, 1)
			pad(card, 12, 12, 12, 12)

			local lay = Instance.new("UIListLayout", card)
			lay.Padding = UDim.new(0, 6)
			lay.SortOrder = Enum.SortOrder.LayoutOrder

			if secName ~= "" then
				local head = lbl(card, string.upper(secName), 10, Enum.Font.GothamBold, T.Muted)
				head.Size = UDim2.new(1, 0, 0, 14)
				head.LayoutOrder = -1
			end

			local SectionApi = {}
			local ROW_H = 42

			local function row(h)
				local r = frame(card, T.Row, 0.35)
				r.Size = UDim2.new(1, 0, 0, h or ROW_H)
				corner(r, 10)
				pad(r, 0, 0, 12, 12)
				return r
			end

			function SectionApi:Label(text)
				local wrap = row(0)
				wrap.AutomaticSize = Enum.AutomaticSize.Y
				wrap.BackgroundTransparency = 1
				local l = lbl(wrap, text, 12, Enum.Font.Gotham, T.Muted)
				l.Size = UDim2.new(1, 0, 0, 0)
				l.AutomaticSize = Enum.AutomaticSize.Y
				l.TextWrapped = true
				pad(wrap, 4, 4, 2, 2)
				return l
			end

			function SectionApi:Button(text, callback)
				local wrap = row(ROW_H)
				wrap.BackgroundTransparency = 1
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 1, 0)
				btn.BackgroundColor3 = T.Row
				btn.BackgroundTransparency = 0.15
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = false
				btn.Font = Enum.Font.GothamSemibold
				btn.TextSize = 13
				btn.TextColor3 = T.Text
				btn.Text = text or "Button"
				btn.Parent = wrap
				corner(btn, 10)
				stroke(btn, 0.5, 1)
				onHover(btn,
					function() tw(btn, { BackgroundTransparency = 0, BackgroundColor3 = T.RowHover }, 0.1) end,
					function() tw(btn, { BackgroundTransparency = 0.15, BackgroundColor3 = T.Row }, 0.1) end)
				btn.MouseButton1Click:Connect(function()
					if callback then task.spawn(callback) end
				end)
				return btn
			end

			function SectionApi:Toggle(text, default, callback, flag)
				local state = default and true or false
				local wrap = row(ROW_H)

				local textLbl = lbl(wrap, text or "Toggle", 13, Enum.Font.GothamMedium, T.Text)
				textLbl.Size = UDim2.new(1, -56, 1, 0)

				local track = frame(wrap, state and T.Accent or T.Dim, 0)
				track.Size = UDim2.fromOffset(42, 24)
				track.Position = UDim2.new(1, -42, 0.5, -12)
				corner(track, 12)

				local knob = frame(track, T.Bg, 0)
				knob.Size = UDim2.fromOffset(18, 18)
				knob.Position = UDim2.fromOffset(state and 21 or 3, 3)
				corner(knob, 9)

				local function paint()
					tw(track, { BackgroundColor3 = state and T.Accent or T.Dim }, 0.15)
					tw(knob, { Position = UDim2.fromOffset(state and 21 or 3, 3) }, 0.15, Enum.EasingStyle.Back)
					if flag then Library.Flags[flag] = state end
				end

				local function toggle()
					state = not state
					paint()
					if callback then task.spawn(callback, state) end
				end

				local hit = Instance.new("TextButton")
				hit.Size = UDim2.fromScale(1, 1)
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Parent = wrap
				hit.MouseButton1Click:Connect(toggle)
				if flag then Library.Flags[flag] = state end

				return {
					Set = function(_, v) state = v and true or false; paint() end,
					Get = function() return state end,
				}
			end

			function SectionApi:Slider(text, min, max, default, step, callback, flag)
				if type(step) == "function" then flag, callback, step = callback, step, nil end
				min, max, step = min or 0, max or 100, step or 0
				local value = math.clamp(default or min, min, max)

				local wrap = row(56)
				pad(wrap, 8, 8, 12, 12)

				local nameLbl = lbl(wrap, text or "Slider", 12, Enum.Font.GothamMedium, T.Text)
				nameLbl.Size = UDim2.new(1, -48, 0, 16)

				local valLbl = lbl(wrap, tostring(value), 12, Enum.Font.GothamBold, T.Accent, Enum.TextXAlignment.Right)
				valLbl.Size = UDim2.fromOffset(48, 16)
				valLbl.Position = UDim2.new(1, -48, 0, 0)

				local trackBg = frame(wrap, T.Dim, 0.3)
				trackBg.Size = UDim2.new(1, 0, 0, 6)
				trackBg.Position = UDim2.fromOffset(0, 28)
				corner(trackBg, 3)

				local fill = frame(trackBg, T.Accent, 0)
				fill.Size = UDim2.new((value - min) / math.max(max - min, 1), 0, 1, 0)
				corner(fill, 3)

				local thumb = frame(trackBg, T.Accent, 0)
				thumb.Size = UDim2.fromOffset(14, 14)
				thumb.AnchorPoint = Vector2.new(0.5, 0.5)
				thumb.Position = UDim2.new((value - min) / math.max(max - min, 1), 0, 0.5, 0)
				thumb.ZIndex = 4
				corner(thumb, 7)
				stroke(thumb, 0, 1, T.Bg)

				local function set(v)
					if step and step > 0 then v = math.floor((v - min) / step + 0.5) * step + min end
					value = math.clamp(tonumber(v) or min, min, max)
					local frac = (value - min) / math.max(max - min, 1)
					fill.Size = UDim2.new(frac, 0, 1, 0)
					thumb.Position = UDim2.new(frac, 0, 0.5, 0)
					local disp = (step >= 1 or step == 0) and math.floor(value + 0.5) or string.format("%.2f", value)
					Library:SetText(valLbl, disp)
					if flag then Library.Flags[flag] = value end
					if callback then callback(value) end
				end
				set(value)

				local sliding = false
				trackBg.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
				end)
				thumb.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
				end)
				conn(UIS.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
				end))
				conn(UIS.InputChanged:Connect(function(inp)
					if not sliding or inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					local rel = math.clamp((inp.Position.X - trackBg.AbsolutePosition.X) / math.max(trackBg.AbsoluteSize.X, 1), 0, 1)
					set(min + (max - min) * rel)
				end))

				return { Set = set, Get = function() return value end }
			end

			function SectionApi:TextBox(placeholder, callback)
				local wrap = row(ROW_H)
				wrap.BackgroundTransparency = 1
				local box = Instance.new("TextBox")
				box.Size = UDim2.new(1, 0, 1, 0)
				box.BackgroundColor3 = T.Row
				box.BackgroundTransparency = 0.15
				box.BorderSizePixel = 0
				box.Font = Enum.Font.Gotham
				box.TextSize = 13
				box.TextColor3 = T.Text
				box.PlaceholderColor3 = T.Dim
				box.PlaceholderText = placeholder or "Type here..."
				box.Text = ""
				box.ClearTextOnFocus = false
				box.Parent = wrap
				corner(box, 10)
				local s = stroke(box, 0.55, 1)
				pad(box, 0, 0, 12, 12)
				box.Focused:Connect(function() tw(s, { Transparency = 0.15, Color = T.Accent }, 0.12) end)
				box.FocusLost:Connect(function(enter)
					tw(s, { Transparency = 0.55, Color = T.Border }, 0.12)
					if callback then callback(box.Text, enter) end
				end)
				return box
			end

			function SectionApi:Dropdown(text, options, default, callback, flag)
				options = options or {}
				local current = default or options[1]
				local open = false

				local wrap = frame(card, nil, 1)
				wrap.Size = UDim2.new(1, 0, 0, 0)
				wrap.AutomaticSize = Enum.AutomaticSize.Y

				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, ROW_H)
				btn.BackgroundColor3 = T.Row
				btn.BackgroundTransparency = 0.15
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = false
				btn.Font = Enum.Font.GothamMedium
				btn.TextSize = 13
				btn.TextColor3 = T.Text
				btn.TextXAlignment = Enum.TextXAlignment.Left
				btn.Text = ""
				btn.Parent = wrap
				corner(btn, 10)
				stroke(btn, 0.5, 1)
				pad(btn, 0, 0, 12, 36)

				local chev = makeIcon(btn, "layers", 14, T.Muted)
				chev.Host.Position = UDim2.new(1, -28, 0.5, -7)

				local dropFrame = frame(wrap, T.Row, 0.1)
				dropFrame.Size = UDim2.new(1, 0, 0, 0)
				dropFrame.AutomaticSize = Enum.AutomaticSize.Y
				dropFrame.ClipsDescendants = true
				dropFrame.Visible = false
				dropFrame.Position = UDim2.fromOffset(0, ROW_H + 4)
				corner(dropFrame, 10)
				stroke(dropFrame, 0.4, 1)
				pad(dropFrame, 4, 4, 4, 4)
				local dropLay = Instance.new("UIListLayout", dropFrame)
				dropLay.Padding = UDim.new(0, 2)

				local function set(v)
					current = v
					Library:SetText(btn, (text and (text .. "  ·  ") or "") .. tostring(v))
					if flag then Library.Flags[flag] = v end
					if callback then callback(v) end
				end

				for _, opt in ipairs(options) do
					local ob = Instance.new("TextButton")
					ob.Size = UDim2.new(1, 0, 0, 32)
					ob.BackgroundTransparency = 1
					ob.BorderSizePixel = 0
					ob.AutoButtonColor = false
					ob.Font = Enum.Font.Gotham
					ob.TextSize = 12
					ob.TextColor3 = T.Muted
					ob.TextXAlignment = Enum.TextXAlignment.Left
					ob.Text = tostring(opt)
					ob.Parent = dropFrame
					corner(ob, 8)
					pad(ob, 0, 0, 10, 0)
					onHover(ob,
						function() tw(ob, { BackgroundTransparency = 0.6, TextColor3 = T.Text }, 0.1) end,
						function() tw(ob, { BackgroundTransparency = 1, TextColor3 = T.Muted }, 0.1) end)
					ob.MouseButton1Click:Connect(function()
						set(opt)
						open = false
						dropFrame.Visible = false
					end)
				end

				btn.MouseButton1Click:Connect(function()
					open = not open
					dropFrame.Visible = open
				end)

				if current then set(current) end
				return { Set = set, Get = function() return current end }
			end

			return SectionApi
		end

		return TabApi
	end

	function WindowApi:Unload() Library:Unload() end
	return WindowApi
end

function Library:Unload()
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	table.clear(self.Connections)
	if self._gui and self._gui.Parent then pcall(function() self._gui:Destroy() end) end
	self._gui = nil
	self._notifyHolder = nil
end

return Library
