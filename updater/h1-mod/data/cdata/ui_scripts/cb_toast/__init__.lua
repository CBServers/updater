-- Non-modal toast on the LUI root, raised from C++ via ui_scripting::notify("cb_toast", { kicker, title, body })
local HOLD_MS = 8000
local FADE_IN_MS = 150
local FADE_OUT_MS = 300

local WIDTH = 427
local HEIGHT = 80
local GOLD = Colors.s1Hud_gold or { r = 1, g = 0.78, b = 0.29 }
local BORDER = Colors.window_border_color or { r = 0.4, g = 0.4, b = 0.4 }
local WHITE = Colors.white or { r = 1, g = 1, b = 1 }

local toast = nil

local function add_image(parent, state, color, alpha)
    state.material = RegisterMaterial("white")
    state.color = { r = color.r, g = color.g, b = color.b }
    state.alpha = alpha
    local image = LUI.UIImage.new(state)
    parent:addElement(image)
    return image
end

local function add_text(parent, font, top, height, color, alpha)
    local text = LUI.UIText.new({
        topAnchor = true,
        leftAnchor = true,
        rightAnchor = true,
        top = top,
        height = height,
        left = 17,
        right = -11,
        font = font.Font,
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

local function build_toast(root)
    local element = LUI.UIElement.new({
        topAnchor = true,
        rightAnchor = true,
        top = 70,
        right = -27,
        width = WIDTH,
        height = HEIGHT,
        alpha = 0
    })

    element:registerAnimationState("hidden", {
        topAnchor = true,
        rightAnchor = true,
        top = 70,
        right = -27,
        width = WIDTH,
        height = HEIGHT,
        alpha = 0
    })

    element:registerAnimationState("visible", {
        topAnchor = true,
        rightAnchor = true,
        top = 70,
        right = -27,
        width = WIDTH,
        height = HEIGHT,
        alpha = 1
    })

    add_image(element, {
        topAnchor = true, bottomAnchor = true, leftAnchor = true, rightAnchor = true,
        top = 0, bottom = 0, left = 0, right = 0
    }, { r = 0, g = 0, b = 0 }, 0.85)

    add_border(element)

    add_image(element, {
        topAnchor = true, bottomAnchor = true, leftAnchor = true,
        top = 0, bottom = 0, left = 0, width = 4
    }, GOLD, 1)

    element.kicker = add_text(element, CoD.TextSettings.BodyFontBold, 9, 16, GOLD, 1)
    element.title = add_text(element, CoD.TextSettings.BodyFont, 28, 21, WHITE, 1)
    element.body = add_text(element, CoD.TextSettings.BodyFontSmall or CoD.TextSettings.BodyFont, 55, 16, WHITE, 0.7)

    element:registerEventHandler("cb_toast_hide", function(self, event)
        if event.sequence == self.sequence then
            -- disposable: the timer closes itself after this event
            self.hide_timer = nil
            self:animateToState("hidden", FADE_OUT_MS)
        end
    end)

    -- above modal popups (500), below the mouse cursor (1000)
    element:setPriority(600)
    root:addElement(element)
    return element
end

local function show_toast(root, event)
    if not toast or toast:isClosed() or not toast:getParent() then
        toast = build_toast(root)
    end

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
    root:registerEventHandler("cb_toast", function(element, event)
        local ok, err = pcall(show_toast, root, event)
        if not ok then
            print("[cb_toast] " .. tostring(err))
        end
    end)
end
