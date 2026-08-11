--[[
  FeatherHub UILib v2  —  by Elemuo
  Modern, polished UI library with:
    • Deep navy dark theme + electric-blue accent
    • iOS-style pill toggle switches
    • Thumb-handle sliders with value bubble
    • Animated hover / active states on every element
    • Slide-in notifications with progress bar
    • Smooth spring open / collapse / tab transitions
    • Sidebar tab icons with glow indicator
    • Draggable window
    • RightShift to hide / show

  API (backward-compatible with FeatherHub game modules):
    local Lib  = loadstring(...)()              -- or require() the file
    local Win  = Lib:CreateWindow({ Title, Subtitle, Size })
    local Tab  = Win:CreateTab({ Name, Icon })
    local Sec  = Tab:Section({ Name })
    Sec:Label(text)
    Sec:Button(text, callback)
    Sec:Toggle(text, default, callback, flag)   -> api { Set, Get }
    Sec:Slider(text, min, max, default, step?, callback, flag) -> api { Set, Get }
    Sec:TextBox(placeholder, callback)
    Sec:Dropdown(text, options, default, callback, flag) -> api { Set, Get }
    Lib:Notify(title, text, duration)
    Lib:Unload()
]]

local UIS         = game:GetService("UserInputService")
local TweenSvc    = game:GetService("TweenService")
local RunSvc      = game:GetService("RunService")
local CoreGui     = game:GetService("CoreGui")
local Players     = game:GetService("Players")

local LP = Players.LocalPlayer

-- ─────────────────────────── THEME  (monochrome) ──────────────────────────
local T = {
	-- backgrounds
	Bg       = Color3.fromRGB(8,   8,   8),
	Panel    = Color3.fromRGB(14,  14,  14),
	Surface  = Color3.fromRGB(20,  20,  20),
	Surface2 = Color3.fromRGB(28,  28,  28),
	-- accent (white spectrum)
	Accent   = Color3.fromRGB(230, 230, 230),
	AccentB  = Color3.fromRGB(160, 160, 160),
	AccentT  = Color3.fromRGB(255, 255, 255),
	-- text
	Text     = Color3.fromRGB(240, 240, 240),
	Muted    = Color3.fromRGB(120, 120, 120),
	Dim      = Color3.fromRGB(55,  55,  55),
	-- status (kept subtle grays for monochrome)
	Success  = Color3.fromRGB(200, 200, 200),
	Danger   = Color3.fromRGB(180, 180, 180),
	Warning  = Color3.fromRGB(160, 160, 160),
	-- misc
	Border   = Color3.fromRGB(40,  40,  40),
	White    = Color3.new(1,1,1),
	Black    = Color3.new(0,0,0),
}

-- ─────────────────────────── LIBRARY ──────────────────────────────────────
local Library = {
	Flags       = {},
	Connections = {},
	Theme       = T,
	_gui        = nil,
	_blur       = nil,
	_notifyHolder = nil,
}

-- ─────────────────────────── HELPERS ──────────────────────────────────────
local function conn(c)
	Library.Connections[#Library.Connections + 1] = c
	return c
end

local function tw(obj, props, t, style, dir)
	TweenSvc:Create(obj, TweenInfo.new(
		t     or 0.2,
		style or Enum.EasingStyle.Quint,
		dir   or Enum.EasingDirection.Out
	), props):Play()
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
	return c
end

local function stroke(p, trans, thick, col)
	local s = Instance.new("UIStroke")
	s.Color       = col   or T.Border
	s.Transparency= trans or 0
	s.Thickness   = thick or 1
	s.Parent = p
	return s
end

local function pad(p, t, b, l, r)
	local u = Instance.new("UIPadding")
	u.PaddingTop    = UDim.new(0, t or 8)
	u.PaddingBottom = UDim.new(0, b or 8)
	u.PaddingLeft   = UDim.new(0, l or 8)
	u.PaddingRight  = UDim.new(0, r or 8)
	u.Parent = p
	return u
end

local function gradient(p, c0, c1, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rot or 0
	g.Parent = p
	return g
end

local function lbl(p, txt, sz, font, col, xa)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = false
	l.Text = txt or ""
	l.TextSize = sz or 13
	l.Font = font or Enum.Font.Gotham
	l.TextColor3 = col or T.Text
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.Parent = p
	return l
end

local function frame(p, bg, trans)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = bg or T.Panel
	f.BackgroundTransparency = trans or 0
	f.BorderSizePixel = 0
	f.Parent = p
	return f
end

local function protect(gui)
	local ok = pcall(function()
		if syn and syn.protect_gui then syn.protect_gui(gui) end
	end)
	ok = pcall(function() gui.Parent = CoreGui end)
	if not ok then gui.Parent = LP:FindFirstChildOfClass("PlayerGui") end
end

-- hover effect helper
local function onHover(obj, enter, leave)
	obj.MouseEnter:Connect(function() task.spawn(enter) end)
	obj.MouseLeave:Connect(function() task.spawn(leave) end)
end

-- ─────────────────────────── NOTIFICATIONS ────────────────────────────────
function Library:Notify(title, body, duration)
	duration = duration or 3.5
	local holder = self._notifyHolder
	if not holder then return end

	local card = frame(holder, T.Panel, 1)
	card.Size = UDim2.fromOffset(290, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.ClipsDescendants = true
	corner(card, 12)
	stroke(card, 0, 1, T.Border)

	-- accent left bar (white → gray)
	local bar = frame(card, T.Accent, 0)
	bar.Size = UDim2.new(0, 3, 1, 0)
	corner(bar, 2)
	gradient(bar, T.AccentT, T.Dim, 90)

	local inner = frame(card, T.Black, 1)
	inner.Size = UDim2.new(1, -12, 1, 0)
	inner.Position = UDim2.fromOffset(10, 0)
	pad(inner, 10, 10, 4, 8)
	inner.AutomaticSize = Enum.AutomaticSize.Y

	local titleLbl = lbl(inner, title, 13, Enum.Font.GothamBold, T.AccentT)
	titleLbl.Size = UDim2.new(1, 0, 0, 16)

	local bodyLbl = lbl(inner, body, 12, Enum.Font.Gotham, T.Muted)
	bodyLbl.Size = UDim2.new(1, 0, 0, 0)
	bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
	bodyLbl.Position = UDim2.fromOffset(0, 20)
	bodyLbl.TextWrapped = true

	-- progress bar
	local progBg = frame(card, T.Surface, 0)
	progBg.Size = UDim2.new(1, 0, 0, 2)
	progBg.AnchorPoint = Vector2.new(0, 1)
	progBg.Position = UDim2.new(0, 0, 1, 0)
	local prog = frame(progBg, T.Accent, 0)
	prog.Size = UDim2.new(1, 0, 1, 0)
	gradient(prog, T.AccentT, T.Dim, 0)

	-- animate in
	tw(card, { BackgroundTransparency = 0.05 }, 0.25)
	tw(bar,  { BackgroundTransparency = 0 },    0.25)

	-- progress drain
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < duration do
			local frac = 1 - (os.clock() - start) / duration
			prog.Size = UDim2.new(math.max(0, frac), 0, 1, 0)
			task.wait()
		end
		tw(card, { BackgroundTransparency = 1 }, 0.2)
		task.wait(0.25)
		pcall(function() card:Destroy() end)
	end)
end

-- ─────────────────────────── WINDOW ───────────────────────────────────────
function Library:CreateWindow(opts)
	opts = opts or {}
	local W      = opts.Size and Vector2.new(opts.Size.X, opts.Size.Y) or Vector2.new(570, 420)
	local titleTxt = opts.Title    or "Feather Hub"
	local subTxt   = opts.Subtitle or ""

	-- wipe old gui
	for _, g in ipairs({ CoreGui, LP and LP:FindFirstChildOfClass("PlayerGui") }) do
		if g then
			local old = g:FindFirstChild("FeatherHubV2")
			if old then old:Destroy() end
		end
	end

	-- screen gui
	local gui = Instance.new("ScreenGui")
	gui.Name            = "FeatherHubV2"
	gui.ResetOnSpawn    = false
	gui.IgnoreGuiInset  = true
	gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
	protect(gui)
	self._gui = gui

	-- notification holder
	local nHolder = frame(gui, T.Black, 1)
	nHolder.Name   = "Notifications"
	nHolder.Size   = UDim2.fromOffset(300, 600)
	nHolder.Position = UDim2.new(1, -310, 0, 16)
	nHolder.AnchorPoint = Vector2.new(0, 0)
	local nLay = Instance.new("UIListLayout", nHolder)
	nLay.Padding = UDim.new(0, 8)
	nLay.HorizontalAlignment = Enum.HorizontalAlignment.Right
	nLay.VerticalAlignment   = Enum.VerticalAlignment.Top
	self._notifyHolder = nHolder

	-- ── main window frame ──────────────────────────────────────────────────
	local win = frame(gui, T.Bg, 1)
	win.Name           = "Window"
	win.Size           = UDim2.fromOffset(W.X, W.Y)
	win.Position       = UDim2.new(0.5, -W.X/2, 0.5, -W.Y/2)
	win.ClipsDescendants = false
	corner(win, 18)
	stroke(win, 0, 1, T.Border)

	-- background gradient (monochrome)
	local winGrad = Instance.new("UIGradient", win)
	winGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(14, 14, 14)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8,  8,  8)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(12, 12, 12)),
	})
	winGrad.Rotation = 135

	-- open animation
	win.BackgroundTransparency = 1
	win.Size = UDim2.fromOffset(math.floor(W.X * 0.9), math.floor(W.Y * 0.9))
	tw(win, { BackgroundTransparency = 0, Size = UDim2.fromOffset(W.X, W.Y) }, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	-- ── drag ──────────────────────────────────────────────────────────────
	do
		local dragging, dragStart, startPos = false
		conn(win.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging  = true
				dragStart = input.Position
				startPos  = win.Position
			end
		end))
		conn(UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end))
		conn(UIS.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local d = input.Position - dragStart
				win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
				                         startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end))
	end

	-- ── header ────────────────────────────────────────────────────────────
	local header = frame(win, T.Panel, 0.3)
	header.Size  = UDim2.new(1, 0, 0, 58)
	corner(header, 18)

	-- fill bottom-left/right corners of header so it merges with body
	local headerFill = frame(header, T.Panel, 0.3)
	headerFill.Size     = UDim2.new(1, 0, 0, 18)
	headerFill.Position = UDim2.new(0, 0, 1, -18)

	-- decorative divider line under header (white → transparent)
	local accentLine = frame(win, T.AccentT, 0)
	accentLine.Size     = UDim2.new(1, -36, 0, 1)
	accentLine.Position = UDim2.fromOffset(18, 59)
	gradient(accentLine, T.AccentT, T.Bg, 0)

	-- icon dot
	local dot = frame(header, T.Accent, 0)
	dot.Size     = UDim2.fromOffset(8, 8)
	dot.Position = UDim2.fromOffset(20, 25)
	corner(dot, 4)
	-- animated pulse (monochrome: white ↔ mid-gray)
	task.spawn(function()
		while dot and dot.Parent do
			tw(dot, { BackgroundColor3 = Color3.fromRGB(90, 90, 90) }, 1.2)
			task.wait(1.2)
			if not (dot and dot.Parent) then break end
			tw(dot, { BackgroundColor3 = T.Accent }, 1.2)
			task.wait(1.2)
		end
	end)

	local titleLbl = lbl(header, titleTxt, 18, Enum.Font.GothamBlack, T.Text)
	titleLbl.Size     = UDim2.new(1, -110, 0, 22)
	titleLbl.Position = UDim2.fromOffset(36, 10)

	local subLbl = lbl(header, subTxt, 12, Enum.Font.Gotham, T.Muted)
	subLbl.Size     = UDim2.new(1, -110, 0, 14)
	subLbl.Position = UDim2.fromOffset(36, 34)

	-- minimize button
	local minBtn = Instance.new("TextButton")
	minBtn.Size                 = UDim2.fromOffset(28, 28)
	minBtn.Position             = UDim2.new(1, -44, 0.5, -14)
	minBtn.BackgroundColor3     = T.Surface2
	minBtn.BackgroundTransparency = 0.2
	minBtn.BorderSizePixel      = 0
	minBtn.AutoButtonColor      = false
	minBtn.Font                 = Enum.Font.GothamBold
	minBtn.TextSize             = 16
	minBtn.TextColor3           = T.Muted
	minBtn.Text                 = "—"
	minBtn.Parent               = header
	corner(minBtn, 8)
	stroke(minBtn, 0, 1, T.Border)
	onHover(minBtn,
		function() tw(minBtn, { TextColor3 = T.Text,  BackgroundColor3 = T.Surface }, 0.15) end,
		function() tw(minBtn, { TextColor3 = T.Muted, BackgroundColor3 = T.Surface2 }, 0.15) end
	)

	-- ── sidebar ───────────────────────────────────────────────────────────
	local sidebar = frame(win, T.Panel, 0.25)
	sidebar.Name     = "Sidebar"
	sidebar.Size     = UDim2.new(0, 142, 1, -76)
	sidebar.Position = UDim2.fromOffset(10, 66)
	corner(sidebar, 14)
	stroke(sidebar, 0, 1, T.Border)
	local sideLay = Instance.new("UIListLayout", sidebar)
	sideLay.Padding            = UDim.new(0, 4)
	sideLay.SortOrder          = Enum.SortOrder.LayoutOrder
	sideLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pad(sidebar, 8, 8, 6, 6)

	-- ── content area ──────────────────────────────────────────────────────
	local contentArea = frame(win, T.Panel, 0.3)
	contentArea.Name     = "Content"
	contentArea.Size     = UDim2.new(1, -168, 1, -76)
	contentArea.Position = UDim2.fromOffset(158, 66)
	corner(contentArea, 14)
	stroke(contentArea, 0, 1, T.Border)

	-- ── footer ────────────────────────────────────────────────────────────
	local footerLbl = lbl(win, "RightShift to hide  •  Feather Hub", 11, Enum.Font.Gotham, T.Dim)
	footerLbl.Size     = UDim2.new(1, -24, 0, 14)
	footerLbl.Position = UDim2.new(0, 12, 1, -18)

	-- ── collapse ──────────────────────────────────────────────────────────
	local collapsed = false
	minBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		local target = collapsed and UDim2.fromOffset(W.X, 58) or UDim2.fromOffset(W.X, W.Y)
		tw(win, { Size = target }, 0.3, Enum.EasingStyle.Quint)
		sidebar.Visible    = not collapsed
		contentArea.Visible= not collapsed
		footerLbl.Visible  = not collapsed
		accentLine.Visible = not collapsed
		minBtn.Text        = collapsed and "+" or "—"
	end)

	-- ── RightShift toggle ─────────────────────────────────────────────────
	conn(UIS.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if inp.KeyCode == Enum.KeyCode.RightShift then
			gui.Enabled = not gui.Enabled
		end
	end))

	-- ══════════════════════════════════════════════════════════════════════
	local WindowApi = {
		Gui    = gui,
		Frame  = win,
		Tabs   = {},
		_selected = nil,
	}

	function WindowApi:SetSubtitle(text) subLbl.Text = tostring(text or "") end
	function WindowApi:SetFooter(text)   footerLbl.Text = tostring(text or "") end

	-- ─────────────────────────── CREATE TAB ───────────────────────────────
	function WindowApi:CreateTab(tabOpts)
		tabOpts = type(tabOpts) == "string" and { Name = tabOpts } or (tabOpts or {})
		local name = tabOpts.Name or "Tab"
		local icon = tabOpts.Icon or ""

		-- sidebar button
		local tabBtn = Instance.new("TextButton")
		tabBtn.Size                 = UDim2.new(1, 0, 0, 34)
		tabBtn.BackgroundColor3     = T.Surface
		tabBtn.BackgroundTransparency = 1
		tabBtn.BorderSizePixel      = 0
		tabBtn.AutoButtonColor      = false
		tabBtn.Font                 = Enum.Font.GothamSemibold
		tabBtn.TextSize             = 12
		tabBtn.TextColor3           = T.Muted
		tabBtn.TextXAlignment       = Enum.TextXAlignment.Left
		tabBtn.Text                 = (icon ~= "" and icon .. "  " or "  ") .. name
		tabBtn.Parent               = sidebar
		corner(tabBtn, 9)
		pad(tabBtn, 0, 0, 10, 4)

		-- active left indicator
		local indicator = frame(tabBtn, T.Accent, 1)
		indicator.Size     = UDim2.fromOffset(3, 20)
		indicator.Position = UDim2.fromOffset(0, 7)
		corner(indicator, 2)

		-- page
		local page = Instance.new("ScrollingFrame")
		page.Name              = name
		page.Size              = UDim2.new(1, -16, 1, -16)
		page.Position          = UDim2.fromOffset(8, 8)
		page.BackgroundTransparency = 1
		page.BorderSizePixel   = 0
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = T.Accent
		page.ScrollBarImageTransparency = 0.4
		page.CanvasSize        = UDim2.new(0,0,0,0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Visible           = false
		page.Parent            = contentArea
		local pageLay = Instance.new("UIListLayout", page)
		pageLay.Padding     = UDim.new(0, 10)
		pageLay.SortOrder   = Enum.SortOrder.LayoutOrder
		pad(page, 6, 10, 4, 6)

		local TabApi = { Name = name, Button = tabBtn, Page = page }

		local function selectTab()
			for _, t in pairs(WindowApi.Tabs) do
				t.Page.Visible = false
				tw(t.Button, { BackgroundTransparency = 1, TextColor3 = T.Muted }, 0.18)
				pcall(function() tw(t.Button:FindFirstChild("Frame"), { BackgroundTransparency = 1 }, 0.18) end)
			end
			page.Visible = true
			-- monochrome active: white text, very dark slightly-lifted bg, white indicator
			tw(tabBtn, { BackgroundTransparency = 0.82, TextColor3 = T.AccentT }, 0.18)
			tw(indicator, { BackgroundTransparency = 0 }, 0.18)
			tabBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
			WindowApi._selected = name
		end

		tabBtn.MouseButton1Click:Connect(selectTab)
		onHover(tabBtn,
			function()
				if WindowApi._selected ~= name then
					tw(tabBtn, { TextColor3 = T.Text }, 0.15)
				end
			end,
			function()
				if WindowApi._selected ~= name then
					tw(tabBtn, { TextColor3 = T.Muted }, 0.15)
				end
			end
		)

		WindowApi.Tabs[name] = TabApi
		if not WindowApi._selected then
			WindowApi._selected = name
			selectTab()
		end

		-- ═══════════════════════════════════════════════════════════════
		function TabApi:Section(secOpts)
			secOpts = type(secOpts) == "string" and { Name = secOpts } or (secOpts or {})
			local secName = secOpts.Name or ""

			local card = frame(page, T.Surface, 0)
			card.Size = UDim2.new(1, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			corner(card, 12)
			stroke(card, 0, 1, T.Border)

			local inner = frame(card, T.Black, 1)
			inner.Size = UDim2.new(1, 0, 0, 0)
			inner.AutomaticSize = Enum.AutomaticSize.Y
			pad(inner, 12, 14, 14, 14)

			local body = frame(inner, T.Black, 1)
			body.Size = UDim2.new(1, 0, 0, 0)
			body.AutomaticSize = Enum.AutomaticSize.Y
			local bodyLay = Instance.new("UIListLayout", body)
			bodyLay.Padding   = UDim.new(0, 8)
			bodyLay.SortOrder = Enum.SortOrder.LayoutOrder

			if secName ~= "" then
				-- section header row
				local headRow = frame(inner, T.Black, 1)
				headRow.Size = UDim2.new(1, 0, 0, 22)
				headRow.LayoutOrder = -1

				local headBar = frame(headRow, T.Accent, 0)
				headBar.Size = UDim2.fromOffset(3, 14)
				headBar.Position = UDim2.fromOffset(0, 4)
				corner(headBar, 2)
				gradient(headBar, T.AccentT, T.Dim, 90)

				local headLbl = lbl(headRow, string.upper(secName), 11, Enum.Font.GothamBold, T.Muted)
				headLbl.Size     = UDim2.new(1, -12, 1, 0)
				headLbl.Position = UDim2.fromOffset(10, 0)

				body.Position = UDim2.fromOffset(0, 26)

				local innerLay = Instance.new("UIListLayout", inner)
				innerLay.Padding   = UDim.new(0, 0)
				innerLay.SortOrder = Enum.SortOrder.LayoutOrder
			end

			body.Parent = inner

			local SectionApi = {}

			-- ── helpers ────────────────────────────────────────────────
			local function rowBase(h)
				local r = frame(body, T.Panel, 0.5)
				r.Size = UDim2.new(1, 0, 0, h or 38)
				corner(r, 9)
				return r
			end

			-- ── LABEL ─────────────────────────────────────────────────
			function SectionApi:Label(text)
				local l = lbl(body, text, 12, Enum.Font.Gotham, T.Muted)
				l.Size = UDim2.new(1, 0, 0, 0)
				l.AutomaticSize = Enum.AutomaticSize.Y
				l.TextWrapped = true
				return l
			end

			-- ── BUTTON ────────────────────────────────────────────────
			function SectionApi:Button(text, callback, color)
				local btn = Instance.new("TextButton")
				btn.Size                 = UDim2.new(1, 0, 0, 38)
				btn.BackgroundColor3     = color or T.Accent
				btn.BackgroundTransparency = 0.55
				btn.BorderSizePixel      = 0
				btn.AutoButtonColor      = false
				btn.Font                 = Enum.Font.GothamSemibold
				btn.TextSize             = 13
				btn.TextColor3           = T.Text
				btn.Text                 = text or "Button"
				btn.Parent               = body
				corner(btn, 9)
				stroke(btn, 0, 1, color or T.Accent)

				onHover(btn,
					function() tw(btn, { BackgroundTransparency = 0.3 }, 0.15) end,
					function() tw(btn, { BackgroundTransparency = 0.55 }, 0.15) end
				)
				btn.MouseButton1Down:Connect(function()
					tw(btn, { BackgroundTransparency = 0.15, Size = UDim2.new(1, -4, 0, 36) }, 0.08)
				end)
				btn.MouseButton1Up:Connect(function()
					tw(btn, { BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 38) }, 0.12)
				end)
				btn.MouseButton1Click:Connect(function()
					if callback then task.spawn(callback) end
				end)
				return btn
			end

			-- ── TOGGLE ────────────────────────────────────────────────
			function SectionApi:Toggle(text, default, callback, flag)
				local state = default and true or false

				local row = rowBase(40)
				pad(row, 0, 0, 12, 12)

				local textLbl = lbl(row, text or "Toggle", 13, Enum.Font.GothamSemibold, T.Text)
				textLbl.Size     = UDim2.new(1, -56, 1, 0)

				-- pill switch
				local pillBg = frame(row, state and T.Accent or T.Surface2, 0)
				pillBg.Size        = UDim2.fromOffset(42, 22)
				pillBg.Position    = UDim2.new(1, -42, 0.5, -11)
				pillBg.AnchorPoint = Vector2.new(0, 0)
				corner(pillBg, 11)
				stroke(pillBg, 0, 1, state and T.Accent or T.Border)

				local thumb = frame(pillBg, T.White, 0)
				thumb.Size        = UDim2.fromOffset(16, 16)
				thumb.Position    = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
				thumb.AnchorPoint = Vector2.new(0, 0)
				corner(thumb, 8)

				local function paint()
					tw(pillBg, {
						BackgroundColor3 = state and Color3.fromRGB(220,220,220) or T.Surface2,
					}, 0.2)
					tw(thumb, {
						BackgroundColor3 = state and T.Black or Color3.fromRGB(90,90,90),
						Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
					}, 0.2, Enum.EasingStyle.Back)
					local pillStroke = pillBg:FindFirstChildOfClass("UIStroke")
					if pillStroke then
						tw(pillStroke, { Color = state and Color3.fromRGB(200,200,200) or T.Border }, 0.2)
					end
					if flag then Library.Flags[flag] = state end
				end

				local function toggle()
					state = not state
					paint()
					if callback then task.spawn(callback, state) end
				end

				row.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then toggle() end
				end)
				pillBg.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then toggle() end
				end)

				onHover(row,
					function() tw(row, { BackgroundTransparency = 0.35 }, 0.15) end,
					function() tw(row, { BackgroundTransparency = 0.5  }, 0.15) end
				)

				if flag then Library.Flags[flag] = state end

				return {
					Set = function(_, v)
						state = v and true or false
						paint()
					end,
					Get = function() return state end,
				}
			end

			-- ── SLIDER ────────────────────────────────────────────────
			function SectionApi:Slider(text, min, max, default, step, callback, flag)
				-- allow old call signature (no step arg)
				if type(step) == "function" then
					flag, callback, step = callback, step, nil
				end
				min  = min  or 0
				max  = max  or 100
				step = step or 0
				local value = math.clamp(default or min, min, max)

				local wrap = frame(body, T.Black, 1)
				wrap.Size = UDim2.new(1, 0, 0, 52)

				-- label row
				local topRow = frame(wrap, T.Black, 1)
				topRow.Size = UDim2.new(1, 0, 0, 20)

				local nameLbl = lbl(topRow, text or "Slider", 13, Enum.Font.GothamSemibold, T.Text)
				nameLbl.Size = UDim2.new(1, -60, 1, 0)

				local valLbl = lbl(topRow, tostring(value), 12, Enum.Font.GothamBold, T.AccentT, Enum.TextXAlignment.Right)
				valLbl.Size     = UDim2.fromOffset(55, 20)
				valLbl.Position = UDim2.new(1, -55, 0, 0)
				valLbl.AnchorPoint = Vector2.new(0, 0)

				-- track
				local trackBg = frame(wrap, T.Surface2, 0)
				trackBg.Size     = UDim2.new(1, 0, 0, 8)
				trackBg.Position = UDim2.fromOffset(0, 30)
				corner(trackBg, 4)

				local fill = frame(trackBg, T.Accent, 0)
				fill.Size = UDim2.new((value - min) / math.max(max - min, 1), 0, 1, 0)
				corner(fill, 4)
				gradient(fill, T.AccentT, T.AccentB, 0)

				-- thumb
				local thumb = frame(trackBg, T.White, 0)
				thumb.Size        = UDim2.fromOffset(16, 16)
				thumb.AnchorPoint = Vector2.new(0.5, 0.5)
				thumb.Position    = UDim2.new((value - min) / math.max(max - min, 1), 0, 0.5, 0)
				thumb.ZIndex      = 4
				corner(thumb, 8)
				stroke(thumb, 0.3, 2, T.Accent)

				local function set(v)
					if step and step > 0 then
						v = math.floor((v - min) / step + 0.5) * step + min
					end
					value = math.clamp(tonumber(v) or min, min, max)
					local frac = (value - min) / math.max(max - min, 1)
					fill.Size  = UDim2.new(frac, 0, 1, 0)
					thumb.Position = UDim2.new(frac, 0, 0.5, 0)
					local disp = (step >= 1 or step == 0) and math.floor(value + 0.5) or string.format("%.2f", value)
					valLbl.Text = tostring(disp)
					if flag then Library.Flags[flag] = value end
					if callback then callback(value) end
				end
				set(value)

				local sliding = false
				trackBg.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then
						sliding = true
						tw(thumb, { Size = UDim2.fromOffset(18, 18) }, 0.1)
					end
				end)
				conn(UIS.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 and sliding then
						sliding = false
						tw(thumb, { Size = UDim2.fromOffset(16, 16) }, 0.1)
					end
				end))
				conn(UIS.InputChanged:Connect(function(inp)
					if not sliding then return end
					if inp.UserInputType == Enum.UserInputType.MouseMovement then
						local rel = math.clamp(
							(inp.Position.X - trackBg.AbsolutePosition.X) / math.max(trackBg.AbsoluteSize.X, 1),
							0, 1
						)
						set(min + (max - min) * rel)
					end
				end))

				return { Set = set, Get = function() return value end }
			end

			-- ── TEXTBOX ───────────────────────────────────────────────
			function SectionApi:TextBox(placeholder, callback)
				local box = Instance.new("TextBox")
				box.Size                 = UDim2.new(1, 0, 0, 38)
				box.BackgroundColor3     = T.Surface2
				box.BackgroundTransparency = 0
				box.BorderSizePixel      = 0
				box.Font                 = Enum.Font.Gotham
				box.TextSize             = 13
				box.TextColor3           = T.Text
				box.PlaceholderColor3    = T.Dim
				box.PlaceholderText      = placeholder or "Type here..."
				box.Text                 = ""
				box.ClearTextOnFocus     = false
				box.Parent               = body
				corner(box, 9)
				local boxStroke = stroke(box, 0, 1, T.Border)

				box.Focused:Connect(function()
					tw(boxStroke, { Color = T.AccentT }, 0.15)
				end)
				box.FocusLost:Connect(function(enter)
					tw(boxStroke, { Color = T.Border }, 0.15)
					if callback then callback(box.Text, enter) end
				end)
				return box
			end

			-- ── DROPDOWN ──────────────────────────────────────────────
			function SectionApi:Dropdown(text, options, default, callback, flag)
				options = options or {}
				local current = default or options[1]
				local open    = false

				local container = frame(body, T.Black, 1)
				container.Size = UDim2.new(1, 0, 0, 0)
				container.AutomaticSize = Enum.AutomaticSize.Y
				container.ClipsDescendants = false

				-- header button
				local btn = Instance.new("TextButton")
				btn.Size                 = UDim2.new(1, 0, 0, 38)
				btn.BackgroundColor3     = T.Surface2
				btn.BackgroundTransparency = 0
				btn.BorderSizePixel      = 0
				btn.AutoButtonColor      = false
				btn.Font                 = Enum.Font.GothamSemibold
				btn.TextSize             = 13
				btn.TextColor3           = T.Text
				btn.TextXAlignment       = Enum.TextXAlignment.Left
				btn.Text                 = ""
				btn.Parent               = container
				corner(btn, 9)
				local btnStroke = stroke(btn, 0, 1, T.Border)
				pad(btn, 0, 0, 12, 40)

				-- label inside button
				local btnLbl = lbl(btn, "", 13, Enum.Font.GothamSemibold, T.Text)
				btnLbl.Size = UDim2.new(1, -42, 1, 0)

				-- arrow icon
				local arrow = lbl(btn, "▾", 14, Enum.Font.GothamBold, T.Muted, Enum.TextXAlignment.Right)
				arrow.Size     = UDim2.fromOffset(30, 38)
				arrow.Position = UDim2.new(1, -32, 0, 0)

				-- drop list
				local dropFrame = frame(body, T.Surface2, 0)
				dropFrame.Size    = UDim2.new(1, 0, 0, 0)
				dropFrame.AutomaticSize = Enum.AutomaticSize.Y
				dropFrame.ClipsDescendants = true
				dropFrame.Visible = false
				dropFrame.ZIndex  = 8
				corner(dropFrame, 9)
				stroke(dropFrame, 0, 1, T.Border)
				pad(dropFrame, 4, 4, 4, 4)
				local dropLay = Instance.new("UIListLayout", dropFrame)
				dropLay.Padding   = UDim.new(0, 2)
				dropLay.SortOrder = Enum.SortOrder.LayoutOrder

				local function set(v)
					current = v
					btnLbl.Text = (text and (text .. ": ") or "") .. tostring(v)
					if flag then Library.Flags[flag] = v end
					if callback then callback(v) end
				end

				for _, opt in ipairs(options) do
					local ob = Instance.new("TextButton")
					ob.Size                 = UDim2.new(1, 0, 0, 30)
					ob.BackgroundColor3     = T.Surface
					ob.BackgroundTransparency = 1
					ob.BorderSizePixel      = 0
					ob.AutoButtonColor      = false
					ob.Font                 = Enum.Font.Gotham
					ob.TextSize             = 12
					ob.TextColor3           = T.Muted
					ob.TextXAlignment       = Enum.TextXAlignment.Left
					ob.Text                 = tostring(opt)
					ob.Parent               = dropFrame
					corner(ob, 7)
					pad(ob, 0, 0, 10, 0)
					onHover(ob,
						function() tw(ob, { BackgroundTransparency = 0.5, TextColor3 = T.Text }, 0.12) end,
						function() tw(ob, { BackgroundTransparency = 1,   TextColor3 = T.Muted }, 0.12) end
					)
					ob.MouseButton1Click:Connect(function()
						set(opt)
						open = false
						dropFrame.Visible = false
						tw(btnStroke, { Color = T.Border }, 0.15)
						
						tw(arrow, { Rotation = 0 }, 0.2)
					end)
				end

				btn.MouseButton1Click:Connect(function()
					open = not open
					dropFrame.Visible = open
					tw(btnStroke, { Color = open and T.AccentT or T.Border }, 0.15)
					tw(arrow, { Rotation = open and 180 or 0 }, 0.2)
				end)

				if current then set(current) end
				return { Set = set, Get = function() return current end }
			end

			return SectionApi
		end -- Section

		return TabApi
	end -- CreateTab

	function WindowApi:Unload()
		Library:Unload()
	end

	return WindowApi
end -- CreateWindow

-- ─────────────────────────── UNLOAD ───────────────────────────────────────
function Library:Unload()
	for _, c in ipairs(self.Connections) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(self.Connections)
	if self._gui and self._gui.Parent then
		pcall(function() self._gui:Destroy() end)
	end
	self._gui = nil
	self._notifyHolder = nil
end

return Library
