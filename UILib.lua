--[[
  FeatherHub UILib v3 — monochrome, performance-first
  New layout: top segmented pill tabs (not a sidebar) + flat list-style rows.

  Perf rules this version follows:
    • No Lua while-loops with task.wait() for animation — everything idle-animated
      uses native TweenService looping (RepeatCount = -1), so 0 Lua cost while idle.
    • Notifications animate with a single Tween + Completed callback (no per-frame loop).
    • Minimal nested wrapper Instances per row.
    • Callers are responsible for not setting the same Text every frame — see
      Library:SetText(label, text) which no-ops if the text hasn't changed
      (prevents constant layout recalculation / stutter).

  API (same as v2, backward-compatible):
    local Lib  = loadstring(...)()
    local Win  = Lib:CreateWindow({ Title, Subtitle, Size })
    local Tab  = Win:CreateTab({ Name, Icon })
    local Sec  = Tab:Section({ Name })
    Sec:Label(text) Sec:Button(text, callback)
    Sec:Toggle(text, default, callback, flag)
    Sec:Slider(text, min, max, default, step?, callback, flag)
    Sec:TextBox(placeholder, callback)
    Sec:Dropdown(text, options, default, callback, flag)
    Lib:Notify(title, text, duration)
    Lib:SetText(label, text)   -- cheap no-op-if-unchanged setter
    Lib:Unload()
]]

local UIS      = game:GetService("UserInputService")
local TweenSvc = game:GetService("TweenService")
local CoreGui  = game:GetService("CoreGui")
local Players  = game:GetService("Players")

local LP = Players.LocalPlayer

-- ─────────────────────────── THEME  (monochrome) ──────────────────────────
local T = {
	Bg       = Color3.fromRGB(9,   9,   9),
	Panel    = Color3.fromRGB(15,  15,  15),
	Surface  = Color3.fromRGB(21,  21,  21),
	Surface2 = Color3.fromRGB(29,  29,  29),
	Accent   = Color3.fromRGB(230, 230, 230),
	AccentT  = Color3.fromRGB(255, 255, 255),
	Text     = Color3.fromRGB(240, 240, 240),
	Muted    = Color3.fromRGB(118, 118, 118),
	Dim      = Color3.fromRGB(52,  52,  52),
	Border   = Color3.fromRGB(38,  38,  38),
	White    = Color3.new(1,1,1),
	Black    = Color3.new(0,0,0),
}

local Library = {
	Flags = {}, Connections = {}, Theme = T,
	_gui = nil, _notifyHolder = nil,
}

-- ─────────────────────────── HELPERS ──────────────────────────────────────
local function conn(c) Library.Connections[#Library.Connections+1] = c; return c end

local function tw(obj, props, t, style, dir)
	TweenSvc:Create(obj, TweenInfo.new(t or 0.16, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

-- one-shot cheap setter: skips work if text unchanged (avoids per-frame layout thrash)
function Library:SetText(label, text)
	text = tostring(text or "")
	if label and label.Text ~= text then
		label.Text = text
	end
end

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c end
local function stroke(p, trans, thick, col) local s = Instance.new("UIStroke"); s.Color = col or T.Border; s.Transparency = trans or 0; s.Thickness = thick or 1; s.Parent = p; return s end
local function pad(p, t, b, l, r) local u = Instance.new("UIPadding"); u.PaddingTop=UDim.new(0,t or 8); u.PaddingBottom=UDim.new(0,b or 8); u.PaddingLeft=UDim.new(0,l or 8); u.PaddingRight=UDim.new(0,r or 8); u.Parent=p; return u end
local function frame(p, bg, trans) local f = Instance.new("Frame"); f.BackgroundColor3 = bg or T.Panel; f.BackgroundTransparency = trans or 0; f.BorderSizePixel = 0; f.Parent = p; return f end
local function lbl(p, txt, sz, font, col, xa)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = txt or ""
	l.TextSize = sz or 13
	l.Font = font or Enum.Font.Gotham
	l.TextColor3 = col or T.Text
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.Parent = p
	return l
end

local function protect(gui)
	local ok = pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	ok = pcall(function() gui.Parent = CoreGui end)
	if not ok then gui.Parent = LP:FindFirstChildOfClass("PlayerGui") end
end

local function onHover(obj, enter, leave)
	obj.MouseEnter:Connect(enter)
	obj.MouseLeave:Connect(leave)
end

-- native, zero-Lua-cost looping pulse (replaces old while+task.wait loops)
local function loopPulse(obj, prop, a, b, t)
	local info = TweenInfo.new(t or 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	obj[prop] = a
	TweenSvc:Create(obj, info, { [prop] = b }):Play()
end

-- ─────────────────────────── NOTIFICATIONS ────────────────────────────────
function Library:Notify(title, body, duration)
	duration = duration or 3.5
	local holder = self._notifyHolder
	if not holder then return end

	local card = frame(holder, T.Panel, 1)
	card.Size = UDim2.fromOffset(280, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.ClipsDescendants = true
	corner(card, 10)
	stroke(card, 0, 1, T.Border)

	local bar = frame(card, T.AccentT, 0)
	bar.Size = UDim2.new(0, 3, 1, 0)
	corner(bar, 2)

	local inner = frame(card, T.Black, 1)
	inner.Size = UDim2.new(1, -12, 1, 0)
	inner.Position = UDim2.fromOffset(10, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	pad(inner, 10, 10, 4, 8)

	local titleLbl = lbl(inner, title, 13, Enum.Font.GothamBold, T.AccentT)
	titleLbl.Size = UDim2.new(1, 0, 0, 16)

	local bodyLbl = lbl(inner, body, 12, Enum.Font.Gotham, T.Muted)
	bodyLbl.Size = UDim2.new(1, 0, 0, 0)
	bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
	bodyLbl.Position = UDim2.fromOffset(0, 20)
	bodyLbl.TextWrapped = true

	local progBg = frame(card, T.Surface, 0)
	progBg.Size = UDim2.new(1, 0, 0, 2)
	progBg.AnchorPoint = Vector2.new(0, 1)
	progBg.Position = UDim2.new(0, 0, 1, 0)
	local prog = frame(progBg, T.AccentT, 0)
	prog.Size = UDim2.new(1, 0, 1, 0)
	prog.AnchorPoint = Vector2.new(0, 0)

	tw(card, { BackgroundTransparency = 0.05 }, 0.2)
	tw(bar, { BackgroundTransparency = 0 }, 0.2)

	-- single tween drains the bar; Completed fires cleanup (no per-frame loop)
	local drain = TweenSvc:Create(prog, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })
	drain:Play()
	drain.Completed:Connect(function()
		tw(card, { BackgroundTransparency = 1 }, 0.2)
		task.delay(0.22, function() pcall(function() card:Destroy() end) end)
	end)
end

-- ─────────────────────────── WINDOW ───────────────────────────────────────
function Library:CreateWindow(opts)
	opts = opts or {}
	local W = opts.Size and Vector2.new(opts.Size.X, opts.Size.Y) or Vector2.new(540, 400)
	local titleTxt = opts.Title or "Feather Hub"
	local subTxt   = opts.Subtitle or ""

	for _, g in ipairs({ CoreGui, LP and LP:FindFirstChildOfClass("PlayerGui") }) do
		if g then
			local old = g:FindFirstChild("FeatherHubV3") or g:FindFirstChild("FeatherHubV2")
			if old then old:Destroy() end
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FeatherHubV3"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	protect(gui)
	self._gui = gui

	local nHolder = frame(gui, T.Black, 1)
	nHolder.Size = UDim2.fromOffset(300, 600)
	nHolder.Position = UDim2.new(1, -310, 0, 16)
	local nLay = Instance.new("UIListLayout", nHolder)
	nLay.Padding = UDim.new(0, 8)
	nLay.HorizontalAlignment = Enum.HorizontalAlignment.Right
	self._notifyHolder = nHolder

	-- ── window shell ────────────────────────────────────────────────────
	local win = frame(gui, T.Bg, 0)
	win.Size = UDim2.fromOffset(W.X, W.Y)
	win.Position = UDim2.new(0.5, -W.X/2, 0.5, -W.Y/2)
	corner(win, 14)
	stroke(win, 0, 1, T.Border)

	win.BackgroundTransparency = 1
	win.Size = UDim2.fromOffset(math.floor(W.X*0.94), math.floor(W.Y*0.94))
	tw(win, { BackgroundTransparency = 0, Size = UDim2.fromOffset(W.X, W.Y) }, 0.22, Enum.EasingStyle.Quad)

	-- drag by top bar only
	local topBar = frame(win, T.Panel, 0)
	topBar.Size = UDim2.new(1, 0, 0, 46)
	corner(topBar, 14)
	local topFill = frame(topBar, T.Panel, 0) -- squares off bottom corners
	topFill.Size = UDim2.new(1, 0, 0, 14)
	topFill.Position = UDim2.new(0, 0, 1, -14)

	do
		local dragging, dragStart, startPos = false, nil, nil
		conn(topBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true; dragStart = input.Position; startPos = win.Position
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

	local dot = frame(topBar, T.Accent, 0)
	dot.Size = UDim2.fromOffset(7, 7)
	dot.Position = UDim2.fromOffset(16, 20)
	corner(dot, 4)
	loopPulse(dot, "BackgroundTransparency", 0, 0.75, 1.1) -- native tween loop, zero Lua cost

	local titleLbl = lbl(topBar, titleTxt, 15, Enum.Font.GothamBold, T.Text)
	titleLbl.Size = UDim2.new(1, -180, 0, 18)
	titleLbl.Position = UDim2.fromOffset(30, 7)

	local subLbl = lbl(topBar, subTxt, 11, Enum.Font.Gotham, T.Muted)
	subLbl.Size = UDim2.new(1, -180, 0, 14)
	subLbl.Position = UDim2.fromOffset(30, 25)

	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.fromOffset(26, 26)
	minBtn.Position = UDim2.new(1, -36, 0.5, -13)
	minBtn.BackgroundColor3 = T.Surface2
	minBtn.BorderSizePixel = 0
	minBtn.AutoButtonColor = false
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 15
	minBtn.TextColor3 = T.Muted
	minBtn.Text = "—"
	minBtn.Parent = topBar
	corner(minBtn, 7)
	onHover(minBtn,
		function() tw(minBtn, { TextColor3 = T.Text, BackgroundColor3 = T.Surface }, 0.12) end,
		function() tw(minBtn, { TextColor3 = T.Muted, BackgroundColor3 = T.Surface2 }, 0.12) end)

	-- ── top segmented tab strip ──────────────────────────────────────────
	local tabStrip = Instance.new("ScrollingFrame")
	tabStrip.Size = UDim2.new(1, -20, 0, 34)
	tabStrip.Position = UDim2.fromOffset(10, 52)
	tabStrip.BackgroundTransparency = 1
	tabStrip.BorderSizePixel = 0
	tabStrip.ScrollBarThickness = 0
	tabStrip.ScrollingDirection = Enum.ScrollingDirection.X
	tabStrip.CanvasSize = UDim2.new(0,0,0,0)
	tabStrip.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabStrip.Parent = win
	local tabLay = Instance.new("UIListLayout", tabStrip)
	tabLay.FillDirection = Enum.FillDirection.Horizontal
	tabLay.Padding = UDim.new(0, 6)
	tabLay.SortOrder = Enum.SortOrder.LayoutOrder

	-- ── content ───────────────────────────────────────────────────────────
	local contentArea = frame(win, T.Panel, 0.25)
	contentArea.Size = UDim2.new(1, -20, 1, -134)
	contentArea.Position = UDim2.fromOffset(10, 92)
	corner(contentArea, 12)
	stroke(contentArea, 0, 1, T.Border)

	-- ── footer / status ───────────────────────────────────────────────────
	local footerLbl = lbl(win, "RightShift to hide", 11, Enum.Font.Gotham, T.Dim)
	footerLbl.Size = UDim2.new(1, -24, 0, 16)
	footerLbl.Position = UDim2.new(0, 12, 1, -22)

	local collapsed = false
	minBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		tw(win, { Size = collapsed and UDim2.fromOffset(W.X, 46) or UDim2.fromOffset(W.X, W.Y) }, 0.22, Enum.EasingStyle.Quad)
		tabStrip.Visible = not collapsed
		contentArea.Visible = not collapsed
		footerLbl.Visible = not collapsed
		minBtn.Text = collapsed and "+" or "—"
	end)

	conn(UIS.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if inp.KeyCode == Enum.KeyCode.RightShift then
			gui.Enabled = not gui.Enabled
		end
	end))

	local WindowApi = { Gui = gui, Frame = win, Tabs = {}, _selected = nil }
	function WindowApi:SetSubtitle(t) Library:SetText(subLbl, t) end
	function WindowApi:SetFooter(t)   Library:SetText(footerLbl, t) end

	-- ─────────────────────────── CREATE TAB ───────────────────────────────
	function WindowApi:CreateTab(tabOpts)
		tabOpts = type(tabOpts) == "string" and { Name = tabOpts } or (tabOpts or {})
		local name, icon = tabOpts.Name or "Tab", tabOpts.Icon or ""

		local tabBtn = Instance.new("TextButton")
		tabBtn.AutomaticSize = Enum.AutomaticSize.X
		tabBtn.Size = UDim2.new(0, 0, 1, 0)
		tabBtn.BackgroundColor3 = T.Surface2
		tabBtn.BackgroundTransparency = 1
		tabBtn.BorderSizePixel = 0
		tabBtn.AutoButtonColor = false
		tabBtn.Font = Enum.Font.GothamSemibold
		tabBtn.TextSize = 12
		tabBtn.TextColor3 = T.Muted
		tabBtn.Text = (icon ~= "" and icon .. "  " or "") .. name
		tabBtn.Parent = tabStrip
		corner(tabBtn, 8)
		pad(tabBtn, 0, 0, 12, 12)

		local page = Instance.new("ScrollingFrame")
		page.Name = name
		page.Size = UDim2.new(1, -16, 1, -16)
		page.Position = UDim2.fromOffset(8, 8)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = T.Accent
		page.ScrollBarImageTransparency = 0.4
		page.CanvasSize = UDim2.new(0,0,0,0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Visible = false
		page.Parent = contentArea
		local pageLay = Instance.new("UIListLayout", page)
		pageLay.Padding = UDim.new(0, 8)
		pageLay.SortOrder = Enum.SortOrder.LayoutOrder

		local TabApi = { Name = name, Button = tabBtn, Page = page }

		local function selectTab()
			for _, t in pairs(WindowApi.Tabs) do
				t.Page.Visible = false
				tw(t.Button, { BackgroundTransparency = 1, TextColor3 = T.Muted }, 0.14)
			end
			page.Visible = true
			tw(tabBtn, { BackgroundTransparency = 0, TextColor3 = T.Black }, 0.14)
			tabBtn.BackgroundColor3 = Color3.fromRGB(225,225,225)
			WindowApi._selected = name
		end

		tabBtn.MouseButton1Click:Connect(selectTab)
		onHover(tabBtn,
			function() if WindowApi._selected ~= name then tw(tabBtn, { TextColor3 = T.Text }, 0.1) end end,
			function() if WindowApi._selected ~= name then tw(tabBtn, { TextColor3 = T.Muted }, 0.1) end end)

		WindowApi.Tabs[name] = TabApi
		if not WindowApi._selected then WindowApi._selected = name; selectTab() end

		-- ═══════════════════════════════════════════════════════════════
		function TabApi:Section(secOpts)
			secOpts = type(secOpts) == "string" and { Name = secOpts } or (secOpts or {})
			local secName = secOpts.Name or ""

			local card = frame(page, T.Surface, 0)
			card.Size = UDim2.new(1, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			corner(card, 10)
			stroke(card, 0, 1, T.Border)
			pad(card, 10, 10, 12, 12)

			if secName ~= "" then
				local head = lbl(card, string.upper(secName), 10, Enum.Font.GothamBold, T.Muted)
				head.Size = UDim2.new(1, 0, 0, 16)
				head.LayoutOrder = -1
			end

			local lay = Instance.new("UIListLayout", card)
			lay.Padding = UDim.new(0, 0)
			lay.SortOrder = Enum.SortOrder.LayoutOrder

			local SectionApi = {}
			local rowIndex = 0

			-- list-style row with hairline divider (no per-row background box)
			local function row(h)
				rowIndex += 1
				local r = frame(card, T.Black, 1)
				r.Size = UDim2.new(1, 0, 0, h or 36)
				if rowIndex > 1 then
					local divider = frame(r, T.Border, 0)
					divider.Size = UDim2.new(1, 0, 0, 1)
					divider.Position = UDim2.fromOffset(0, 0)
				end
				return r
			end

			function SectionApi:Label(text)
				local wrap = row(0)
				wrap.AutomaticSize = Enum.AutomaticSize.Y
				pad(wrap, 6, 6, 0, 0)
				local l = lbl(wrap, text, 12, Enum.Font.Gotham, T.Muted)
				l.Size = UDim2.new(1, 0, 0, 0)
				l.AutomaticSize = Enum.AutomaticSize.Y
				l.TextWrapped = true
				return l
			end

			function SectionApi:Button(text, callback)
				local wrap = row(42)
				pad(wrap, 4, 4, 0, 0)
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 1, 0)
				btn.BackgroundColor3 = T.Surface2
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = false
				btn.Font = Enum.Font.GothamSemibold
				btn.TextSize = 13
				btn.TextColor3 = T.Text
				btn.Text = text or "Button"
				btn.Parent = wrap
				corner(btn, 8)
				onHover(btn,
					function() tw(btn, { BackgroundColor3 = T.Dim }, 0.1) end,
					function() tw(btn, { BackgroundColor3 = T.Surface2 }, 0.1) end)
				btn.MouseButton1Click:Connect(function()
					if callback then task.spawn(callback) end
				end)
				return btn
			end

			function SectionApi:Toggle(text, default, callback, flag)
				local state = default and true or false
				local wrap = row(40)
				local textLbl = lbl(wrap, text or "Toggle", 13, Enum.Font.Gotham, T.Text)
				textLbl.Size = UDim2.new(1, -56, 1, 0)

				local pillBg = frame(wrap, T.Surface2, 0)
				pillBg.Size = UDim2.fromOffset(40, 22)
				pillBg.Position = UDim2.new(1, -40, 0.5, -11)
				corner(pillBg, 11)

				local thumb = frame(pillBg, Color3.fromRGB(90,90,90), 0)
				thumb.Size = UDim2.fromOffset(16, 16)
				thumb.Position = UDim2.fromOffset(3, 3)
				corner(thumb, 8)

				local function paint()
					tw(pillBg, { BackgroundColor3 = state and Color3.fromRGB(225,225,225) or T.Surface2 }, 0.16)
					tw(thumb, {
						BackgroundColor3 = state and T.Black or Color3.fromRGB(90,90,90),
						Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
					}, 0.16, Enum.EasingStyle.Back)
					if flag then Library.Flags[flag] = state end
				end

				local function toggle()
					state = not state
					paint()
					if callback then task.spawn(callback, state) end
				end
				wrap.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then toggle() end
				end)
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

				local wrap = row(50)
				pad(wrap, 6, 0, 0, 0)

				local nameLbl = lbl(wrap, text or "Slider", 12, Enum.Font.Gotham, T.Text)
				nameLbl.Size = UDim2.new(1, -55, 0, 16)

				local valLbl = lbl(wrap, tostring(value), 12, Enum.Font.GothamBold, T.AccentT, Enum.TextXAlignment.Right)
				valLbl.Size = UDim2.fromOffset(55, 16)
				valLbl.Position = UDim2.new(1, -55, 0, 0)

				local trackBg = frame(wrap, T.Surface2, 0)
				trackBg.Size = UDim2.new(1, 0, 0, 6)
				trackBg.Position = UDim2.fromOffset(0, 24)
				corner(trackBg, 3)

				local fill = frame(trackBg, T.AccentT, 0)
				fill.Size = UDim2.new((value-min)/math.max(max-min,1), 0, 1, 0)
				corner(fill, 3)

				local thumb = frame(trackBg, T.White, 0)
				thumb.Size = UDim2.fromOffset(14, 14)
				thumb.AnchorPoint = Vector2.new(0.5, 0.5)
				thumb.Position = UDim2.new((value-min)/math.max(max-min,1), 0, 0.5, 0)
				thumb.ZIndex = 4
				corner(thumb, 7)

				local function set(v)
					if step and step > 0 then v = math.floor((v-min)/step + 0.5)*step + min end
					value = math.clamp(tonumber(v) or min, min, max)
					local frac = (value-min)/math.max(max-min,1)
					fill.Size = UDim2.new(frac, 0, 1, 0)
					thumb.Position = UDim2.new(frac, 0, 0.5, 0)
					local disp = (step >= 1 or step == 0) and math.floor(value+0.5) or string.format("%.2f", value)
					Library:SetText(valLbl, disp)
					if flag then Library.Flags[flag] = value end
					if callback then callback(value) end
				end
				set(value)

				local sliding = false
				trackBg.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
				end)
				conn(UIS.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
				end))
				conn(UIS.InputChanged:Connect(function(inp)
					if not sliding or inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					local rel = math.clamp((inp.Position.X - trackBg.AbsolutePosition.X)/math.max(trackBg.AbsoluteSize.X,1), 0, 1)
					set(min + (max-min)*rel)
				end))

				return { Set = set, Get = function() return value end }
			end

			function SectionApi:TextBox(placeholder, callback)
				local wrap = row(42)
				pad(wrap, 4, 4, 0, 0)
				local box = Instance.new("TextBox")
				box.Size = UDim2.new(1, 0, 1, 0)
				box.BackgroundColor3 = T.Surface2
				box.BorderSizePixel = 0
				box.Font = Enum.Font.Gotham
				box.TextSize = 13
				box.TextColor3 = T.Text
				box.PlaceholderColor3 = T.Dim
				box.PlaceholderText = placeholder or "Type here..."
				box.Text = ""
				box.ClearTextOnFocus = false
				box.Parent = wrap
				corner(box, 8)
				local s = stroke(box, 1, 1, T.Border)
				box.Focused:Connect(function() tw(s, { Transparency = 0, Color = T.AccentT }, 0.12) end)
				box.FocusLost:Connect(function(enter)
					tw(s, { Transparency = 1 }, 0.12)
					if callback then callback(box.Text, enter) end
				end)
				return box
			end

			function SectionApi:Dropdown(text, options, default, callback, flag)
				options = options or {}
				local current = default or options[1]
				local open = false

				local wrap = row(0)
				wrap.AutomaticSize = Enum.AutomaticSize.Y
				pad(wrap, 4, 4, 0, 0)

				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 38)
				btn.BackgroundColor3 = T.Surface2
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = false
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 13
				btn.TextColor3 = T.Text
				btn.TextXAlignment = Enum.TextXAlignment.Left
				btn.Text = ""
				btn.Parent = wrap
				corner(btn, 8)
				pad(btn, 0, 0, 12, 36)

				local arrow = lbl(btn, "▾", 13, Enum.Font.GothamBold, T.Muted, Enum.TextXAlignment.Right)
				arrow.Size = UDim2.fromOffset(28, 38)
				arrow.Position = UDim2.new(1, -30, 0, 0)

				local dropFrame = frame(wrap, T.Surface2, 0)
				dropFrame.Size = UDim2.new(1, 0, 0, 0)
				dropFrame.AutomaticSize = Enum.AutomaticSize.Y
				dropFrame.ClipsDescendants = true
				dropFrame.Visible = false
				dropFrame.Position = UDim2.fromOffset(0, 40)
				corner(dropFrame, 8)
				pad(dropFrame, 4, 4, 4, 4)
				local dropLay = Instance.new("UIListLayout", dropFrame)
				dropLay.Padding = UDim.new(0, 2)

				local function set(v)
					current = v
					Library:SetText(btn, (text and (text .. ": ") or "") .. tostring(v))
					if flag then Library.Flags[flag] = v end
					if callback then callback(v) end
				end

				for _, opt in ipairs(options) do
					local ob = Instance.new("TextButton")
					ob.Size = UDim2.new(1, 0, 0, 28)
					ob.BackgroundTransparency = 1
					ob.BorderSizePixel = 0
					ob.AutoButtonColor = false
					ob.Font = Enum.Font.Gotham
					ob.TextSize = 12
					ob.TextColor3 = T.Muted
					ob.TextXAlignment = Enum.TextXAlignment.Left
					ob.Text = tostring(opt)
					ob.Parent = dropFrame
					corner(ob, 6)
					pad(ob, 0, 0, 8, 0)
					onHover(ob,
						function() tw(ob, { BackgroundTransparency = 0.5, TextColor3 = T.Text }, 0.1) end,
						function() tw(ob, { BackgroundTransparency = 1, TextColor3 = T.Muted }, 0.1) end)
					ob.MouseButton1Click:Connect(function()
						set(opt); open = false; dropFrame.Visible = false
						tw(arrow, { Rotation = 0 }, 0.15)
					end)
				end

				btn.MouseButton1Click:Connect(function()
					open = not open
					dropFrame.Visible = open
					tw(arrow, { Rotation = open and 180 or 0 }, 0.15)
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
