if (game:issingleplayer()) then
	return
end

-- Non-modal toast on the LUI root, raised from C++ via ui_scripting::notify("cb_toast", { kicker, title, body })
local TOAST_ID = "cb_toast"
local HOLD_MS = 8000
local FADE_IN_MS = 150
local FADE_OUT_MS = 300

local WIDTH = 427
local HEIGHT = 80
local GOLD = Colors.frontend_hilite
local BORDER = Colors.window_border_color

local function add_image(parent, state)
	state.material = RegisterMaterial("white")
	local image = LUI.UIImage.new(state)
	parent:addElement(image)
	return image
end

local function add_text(parent, font, top, height, color, alpha)
	local text = LUI.UIText.new({
		topAnchor = true,
		bottomAnchor = false,
		leftAnchor = true,
		rightAnchor = true,
		top = top,
		height = height,
		left = 17,
		right = -11,
		font = font.Font,
		alignment = LUI.Alignment.Left,
		red = color.r,
		green = color.g,
		blue = color.b,
		alpha = alpha
	})
	parent:addElement(text)
	return text
end

-- 1px lines on each edge; iw6 has no border element that survives decompilation cleanly
local function add_border(parent)
	local edges = {
		{ topAnchor = true, bottomAnchor = false, leftAnchor = true, rightAnchor = true, top = 0, height = 1, left = 0, right = 0 },
		{ topAnchor = false, bottomAnchor = true, leftAnchor = true, rightAnchor = true, bottom = 0, height = 1, left = 0, right = 0 },
		{ topAnchor = true, bottomAnchor = true, leftAnchor = true, rightAnchor = false, top = 0, bottom = 0, left = 0, width = 1 },
		{ topAnchor = true, bottomAnchor = true, leftAnchor = false, rightAnchor = true, top = 0, bottom = 0, right = 0, width = 1 }
	}

	for _, edge in ipairs(edges) do
		edge.red = BORDER.r
		edge.green = BORDER.g
		edge.blue = BORDER.b
		edge.alpha = 1
		add_image(parent, edge)
	end
end

local function build_toast(root)
	-- In a match the killfeed and score list own the top right, so drop below them
	local top = Engine.InFrontend() and 70 or 330

	local toast = LUI.UIElement.new({
		topAnchor = true,
		bottomAnchor = false,
		leftAnchor = false,
		rightAnchor = true,
		top = top,
		height = HEIGHT,
		right = -27,
		width = WIDTH,
		alpha = 0
	})
	toast.id = TOAST_ID
	toast:registerAnimationState("hidden", { alpha = 0 })
	toast:registerAnimationState("visible", { alpha = 1 })

	add_image(toast, {
		topAnchor = true, bottomAnchor = true, leftAnchor = true, rightAnchor = true,
		top = 0, bottom = 0, left = 0, right = 0,
		red = 0, green = 0, blue = 0, alpha = 0.85
	})
	add_border(toast)
	add_image(toast, {
		topAnchor = true, bottomAnchor = true, leftAnchor = true, rightAnchor = false,
		top = 0, bottom = 0, left = 0, width = 4,
		red = GOLD.r, green = GOLD.g, blue = GOLD.b, alpha = 1
	})

	toast.kicker = add_text(toast, CoD.TextSettings.BoldFont, 9, 16, GOLD, 1)
	toast.title = add_text(toast, CoD.TextSettings.NormalFont, 28, 21, Colors.white, 1)
	toast.body = add_text(toast, CoD.TextSettings.HudEuroConRegSmallFont, 55, 16, Colors.white, 0.7)

	toast:registerEventHandler("cb_toast_hide", function(element, event)
		if event.sequence == element.sequence then
			element:animateToState("hidden", FADE_OUT_MS)
		end
	end)

	-- above the menu stack and HUD layers, below the mouse cursor
	toast:setPriority(300)
	root:addElement(toast)
	return toast
end

local function show_toast(root, event)
	local toast = root:getChildById(TOAST_ID) or build_toast(root)
	toast.kicker:setText(event.kicker or "")
	toast.title:setText(event.title or "")
	toast.body:setText(event.body or "")

	toast.sequence = (toast.sequence or 0) + 1
	if toast.hide_timer then
		toast.hide_timer:close()
	end

	-- the sequence check stops an older timer from fading out a newer toast
	toast.hide_timer = LUI.UITimer.new(HOLD_MS, { name = "cb_toast_hide", sequence = toast.sequence }, nil, true, toast)
	toast:addElement(toast.hide_timer)
	toast:animateToState("visible", FADE_IN_MS)
end

local root = Engine.GetLuiRoot()
if root then
	root:registerEventHandler("cb_toast", show_toast)
end
