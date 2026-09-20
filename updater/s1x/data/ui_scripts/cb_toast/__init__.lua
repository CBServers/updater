if (game:issingleplayer()) then
	return
end

-- Non-modal toast on the LUI root, raised from C++ via ui_scripting::notify("cb_toast", { kicker, title, body })
local HOLD_MS = 8000
local FADE_IN_MS = 150
local FADE_OUT_MS = 300

local WIDTH = 427
local HEIGHT = 80
local TOP = 70
local RIGHT = -27

local GOLD = { r = 1, g = 0.78, b = 0.29 }
local BORDER = { r = 0.4, g = 0.4, b = 0.4 }
local WHITE = { r = 1, g = 1, b = 1 }
local BLACK = { r = 0, g = 0, b = 0 }

local toast = nil

local function add_image(parent, state, color, alpha)
	state.material = RegisterMaterial("white")
	state.color = { r = color.r, g = color.g, b = color.b }
	state.alpha = alpha
	local image = LUI.UIImage.new(state)
	parent:addElement(image)
	return image
end

local function add_text(parent, font, size, top, color, alpha)
	local text = LUI.UIText.new({
		topAnchor = true,
		leftAnchor = true,
		rightAnchor = true,
		top = top,
		height = size,
		left = 17,
		right = -11,
		font = RegisterFont(font, size),
		alignment = LUI.Alignment.Left,
		color = { r = color.r, g = color.g, b = color.b },
		alpha = alpha
	})
	parent:addElement(text)
	return text
end

local function add_border(parent)
	local edges = {
		{ topAnchor = true, leftAnchor = true, rightAnchor = true, top = 0, height = 1, left = 0, right = 0 },
		{ bottomAnchor = true, leftAnchor = true, rightAnchor = true, bottom = 0, height = 1, left = 0, right = 0 },
		{ topAnchor = true, bottomAnchor = true, leftAnchor = true, top = 0, bottom = 0, left = 0, width = 1 },
		{ topAnchor = true, bottomAnchor = true, rightAnchor = true, top = 0, bottom = 0, right = 0, width = 1 }
	}

	for _, edge in ipairs(edges) do
		add_image(parent, edge, BORDER, 1)
	end
end

local function toast_state(alpha)
	return {
		topAnchor = true,
		rightAnchor = true,
		top = TOP,
		right = RIGHT,
		width = WIDTH,
		height = HEIGHT,
		alpha = alpha
	}
end

local function get_priority()
	local priorities = LUI.UIRoot and LUI.UIRoot.childPriorities
	local modal = priorities and priorities.modal or 500
	return modal + 100
end

local function build_toast(root)
	local element = LUI.UIElement.new(toast_state(0))
	element:registerAnimationState("hidden", toast_state(0))
	element:registerAnimationState("visible", toast_state(1))

	add_image(element, {
		topAnchor = true, bottomAnchor = true, leftAnchor = true, rightAnchor = true,
		top = 0, bottom = 0, left = 0, right = 0
	}, BLACK, 0.85)

	add_border(element)

	add_image(element, {
		topAnchor = true, bottomAnchor = true, leftAnchor = true,
		top = 0, bottom = 0, left = 0, width = 4
	}, GOLD, 1)

	element.kicker = add_text(element, "fonts/bodyFontBold", 16, 9, GOLD, 1)
	element.title = add_text(element, "fonts/bodyFont", 21, 28, WHITE, 1)
	element.body = add_text(element, "fonts/bodyFont", 16, 55, WHITE, 0.7)

	element:registerEventHandler("cb_toast_hide", function(self, event)
		if event.sequence == self.sequence then
			-- a disposable timer closes itself after this event; the two-argument fallback repeats until closed
			if self.hide_timer and not self.hide_timer_disposable then
				self.hide_timer:close()
			end

			self.hide_timer = nil
			self:animateToState("hidden", FADE_OUT_MS)
		end
	end)

	-- above modal popups, below the mouse cursor
	if element.setPriority then
		element:setPriority(get_priority())
	end

	root:addElement(element)
	return element
end

local function is_detached(element)
	if element.isClosed and element:isClosed() then
		return true
	end

	return not element:getParent()
end

local function show_toast(root, event)
	if not toast or is_detached(toast) then
		toast = build_toast(root)
	end

	toast.kicker:setText(event.kicker or "")
	toast.title:setText(event.title or "")
	toast.body:setText(event.body or "")

	toast.sequence = (toast.sequence or 0) + 1
	if toast.hide_timer then
		toast.hide_timer:close()
		toast.hide_timer = nil
	end

	toast:animateToState("visible", FADE_IN_MS)

	-- the sequence check stops an older timer from fading out a newer toast
	local hide_event = { name = "cb_toast_hide", sequence = toast.sequence }
	local ok, timer = pcall(LUI.UITimer.new, HOLD_MS, hide_event, nil, true, toast)
	toast.hide_timer_disposable = ok and timer ~= nil
	if not toast.hide_timer_disposable then
		-- S1 only proves the two-argument form; the event then goes to the parent, which is the toast
		timer = LUI.UITimer.new(HOLD_MS, hide_event)
	end

	toast.hide_timer = timer
	toast:addElement(timer)
end

local root = Engine.GetLuiRoot()
if root then
	root:registerEventHandler("cb_toast", function(element, event)
		local ok, err = pcall(show_toast, root, event)
		if not ok then
			print("[cb_lui] cb_toast: " .. tostring(err))
		end
	end)
else
	print("[cb_lui] cb_toast: no LUI root")
end
