-- Non-modal toast on the LUI root, raised from C++ via ui_scripting::notify("cb_toast", { kicker, title, body })
local TOAST_ID = "CBToast"
local HOLD_MS = 6000
local FADE_IN_MS = 150
local FADE_OUT_MS = 300

local function add_text(parent, font, size, top, color, alpha)
    local text = LUI.UIText.new()
    text:SetFont(FONTS.GetFont(font.File))
    text:SetFontSize(size * _1080p)
    text:SetAlignment(LUI.Alignment.Left)
    text:SetWordWrap(false)
    text:SetRGBFromTable(color, 0)
    text:SetAlpha(alpha, 0)
    text:SetAnchorsAndPosition(0, 0, 0, 1, _1080p * 26, _1080p * -16, _1080p * top, _1080p * (top + size))
    parent:addElement(text)
    return text
end

local function build_toast(root)
    local toast = LUI.UIElement.new()
    toast.id = TOAST_ID
    toast:SetAnchorsAndPosition(1, 0, 0, 1, _1080p * -680, _1080p * -40, _1080p * 70, _1080p * 190)
    toast:SetAlpha(0, 0)

    local background = LUI.UIImage.new()
    background:SetRGBFromTable(SWATCHES.Popups.backgroundPopup, 0)
    background:SetAlpha(0.85, 0)
    toast:addElement(background)

    local border = LUI.UIBorder.new({
        borderThicknessLeft = _1080p * 1,
        borderThicknessRight = _1080p * 1,
        borderThicknessTop = _1080p * 1,
        borderThicknessBottom = _1080p * 1
    })
    border:SetRGBFromTable(SWATCHES.genericMenu.border, 0)
    toast:addElement(border)

    local accent = LUI.UIImage.new()
    accent:SetRGBFromTable(SWATCHES.genericButton.highlight, 0)
    accent:SetAnchorsAndPosition(0, 1, 0, 0, 0, _1080p * 6, 0, 0)
    toast:addElement(accent)

    toast.Kicker = add_text(toast, FONTS.MainBold, 24, 14, SWATCHES.genericButton.highlight, 1)
    toast.Title = add_text(toast, FONTS.MainMedium, 32, 44, SWATCHES.Popups.bodyTxt, 1)
    toast.Body = add_text(toast, FONTS.MainCondensed, 24, 82, SWATCHES.Popups.bodyTxt, 0.7)

    -- draw above the menu stack and HUD layers
    toast:setPriority(10000)
    root:addElement(toast)
    return toast
end

local function show_toast(root, event)
    local toast = root:getChildById(TOAST_ID) or build_toast(root)
    toast.Kicker:setText(event.kicker or "")
    toast.Title:setText(event.title or "")
    toast.Body:setText(event.body or "")

    toast.sequence = (toast.sequence or 0) + 1
    local sequence = toast.sequence

    toast:SetAlpha(1, FADE_IN_MS)
    toast:Wait(HOLD_MS).onComplete = function()
        if toast.sequence == sequence then
            toast:SetAlpha(0, FADE_OUT_MS)
        end
    end
end

scheduler.once(function()
    Engine.GetLuiRoot():registerEventHandler("cb_toast", show_toast)
end)
