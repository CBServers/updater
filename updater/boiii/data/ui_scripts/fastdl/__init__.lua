-- Native LUI front-end for FastDL: a Yes/No system overlay and a live progress overlay.

if CoD == nil or CoD.OverlayUtility == nil then
	return
end

local CONFIRM_OVERLAY = "BoiiiFastDLConfirm"
local PROGRESS_OVERLAY = "BoiiiFastDLProgress"

local BAR_LEFT = 422
local BAR_RIGHT = 1170
local BAR_WIDTH = BAR_RIGHT - BAR_LEFT

-- shared through the global so a double load (appdata + game folder) still talks to one state
BoiiiFastDL = BoiiiFastDL or {}

local state = BoiiiFastDL.state
if state == nil then
	state = {
		confirmMenu = nil,
		progressMenu = nil,
		answered = false,
		title = "",
		description = "",
		percent = 0
	}
	BoiiiFastDL.state = state
end

local function GetController()
	return Engine.GetPrimaryController()
end

local function Try(fn)
	local ok, result = pcall(fn)
	if ok then
		return result
	end
	return nil
end

-- Overlays open on a parent menu; called from C++ we have none, so find the topmost live one.
local function FindHostMenu()
	if LUI == nil or LUI.roots == nil then
		return nil
	end

	local host = nil
	for _, root in pairs(LUI.roots) do
		local child = Try(function() return root:getFirstChild() end)
		while child do
			local isMenu = Try(function() return child.menuName ~= nil and child.openPopup ~= nil end)
			local occluded = Try(function() return child.occludedBy ~= nil end)
			if isMenu and not occluded then
				host = child
			end
			child = Try(function() return child:getNextSibling() end)
		end
	end

	return host
end

local function CloseMenu(menu)
	if menu == nil then
		return
	end
	local controller = GetController()
	Try(function() GoBack(menu, controller) end)
end

-- Progress frame: the stock compact frame plus a fill bar driven by progressPercentage.

CoD.BoiiiFastDLFrame = InheritFrom(LUI.UIElement)
CoD.BoiiiFastDLFrame.new = function(menu, controller)
	local self = LUI.UIElement.new()
	self:setUseStencil(false)
	self:setClass(CoD.BoiiiFastDLFrame)
	self.id = "BoiiiFastDLFrame"
	self.soundSet = "default"
	self:setLeftRight(true, false, 0, 1280)
	self:setTopBottom(true, false, 0, 191)
	self:makeFocusable()
	self.onlyChildrenFocusable = true
	self.anyChildUsesUpdateState = true

	local base = CoD.systemOverlay_Compact_BasicFrame.new(menu, controller)
	base:setLeftRight(true, true, 0, 0)
	base:setTopBottom(true, true, 0, 0)
	base:linkToElementModel(self, nil, false, function(model)
		base:setModel(model, controller)
	end)
	self:addElement(base)
	self.base = base

	local barBacking = LUI.UIImage.new()
	barBacking:setLeftRight(true, false, BAR_LEFT, BAR_RIGHT)
	barBacking:setTopBottom(true, false, 64, 72)
	barBacking:setRGB(1, 1, 1)
	barBacking:setAlpha(0.12)
	self:addElement(barBacking)
	self.barBacking = barBacking

	local barFill = LUI.UIImage.new()
	barFill:setLeftRight(true, false, BAR_LEFT, BAR_LEFT)
	barFill:setTopBottom(true, false, 64, 72)
	barFill:setRGB(0.98, 0.76, 0.16)
	barFill:setAlpha(0.9)
	barFill:linkToElementModel(self, "progressPercentage", true, function(model)
		local percent = Engine.GetModelValue(model) or 0
		if percent < 0 then
			percent = 0
		elseif 100 < percent then
			percent = 100
		end
		barFill:setLeftRight(true, false, BAR_LEFT, BAR_LEFT + BAR_WIDTH * percent / 100)
	end)
	self:addElement(barFill)
	self.barFill = barFill

	self:registerEventHandler("gain_focus", function(element, event)
		if element.m_focusable and element.base:processEvent(event) then
			return true
		end
		return LUI.UIElement.gainFocus(element, event)
	end)

	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		element.base:close()
	end)

	return self
end

-- Confirm overlay

local function AnswerConfirm(accept, menu, controller)
	if state.answered then
		return
	end
	state.answered = true
	state.confirmMenu = nil

	if game ~= nil and game.fastdlAnswer ~= nil then
		Try(function() game.fastdlAnswer(accept) end)
	end

	CloseMenu(menu)
end

CoD.OverlayUtility.AddSystemOverlay(CONFIRM_OVERLAY, {
	menuName = "SystemOverlay_Compact",
	categoryType = CoD.OverlayUtility.OverlayTypes.Notice,
	title = function()
		return state.title
	end,
	description = function()
		return state.description
	end,
	listDatasource = function()
		DataSources[CONFIRM_OVERLAY] = DataSourceHelpers.ListSetup(CONFIRM_OVERLAY, function(controller)
			return {
				{
					models = {
						displayText = Engine.Localize("MENU_YES")
					},
					properties = {
						action = function(element, event, controller, param, menu)
							AnswerConfirm(true, menu, controller)
						end
					}
				},
				{
					models = {
						displayText = Engine.Localize("MENU_NO")
					},
					properties = {
						action = function(element, event, controller, param, menu)
							AnswerConfirm(false, menu, controller)
						end
					}
				}
			}
		end, true, nil)
		return CONFIRM_OVERLAY
	end,
	[CoD.OverlayUtility.GoBackPropertyName] = function()
		return function(element, event, controller, menu)
			AnswerConfirm(false, menu, controller)
		end
	end
})

-- Progress overlay

local function CancelDownload(menu, controller)
	if game ~= nil and game.fastdlCancel ~= nil then
		Try(function() game.fastdlCancel() end)
	end

	state.progressMenu = nil
	CloseMenu(menu)
end

local function RefreshProgress(menu)
	if game == nil or game.fastdlIsDownloading == nil then
		return
	end

	if not game.fastdlIsDownloading() then
		if state.progressMenu == menu then
			state.progressMenu = nil
			CloseMenu(menu)
		end
		return
	end

	state.percent = game.fastdlPercent() or 0
	-- one line only: the frame has ~80px above the button list, so a second line runs under the bar
	local status = game.fastdlStatus() or ""
	if status ~= "" then
		status = status .. "   "
	end

	state.description = status .. (game.fastdlDetail() or "")
	Try(function() menu:refreshData(nil) end)
end

CoD.OverlayUtility.AddSystemOverlay(PROGRESS_OVERLAY, {
	menuName = "SystemOverlay_Compact",
	frameWidget = "CoD.BoiiiFastDLFrame",
	categoryType = CoD.OverlayUtility.OverlayTypes.Connection,
	title = function()
		return state.title
	end,
	description = function()
		return state.description
	end,
	progressPercentage = function()
		return state.percent
	end,
	postCreateStep = function(menu, controller)
		menu.unusedControllerAllowed = true
		menu:addElement(LUI.UITimer.newElementTimer(250, false, function()
			RefreshProgress(menu)
		end))
	end,
	listDatasource = function()
		DataSources[PROGRESS_OVERLAY] = DataSourceHelpers.ListSetup(PROGRESS_OVERLAY, function(controller)
			return {
				{
					models = {
						displayText = Engine.Localize("MENU_CANCEL_CAPS")
					},
					properties = {
						action = function(element, event, controller, param, menu)
							CancelDownload(menu, controller)
						end
					}
				}
			}
		end, true, nil)
		return PROGRESS_OVERLAY
	end,
	[CoD.OverlayUtility.GoBackPropertyName] = function()
		return function(element, event, controller, menu)
			CancelDownload(menu, controller)
		end
	end
})

-- Entry points called from C++ (fastdl.cpp, via ui_scripting)

BoiiiFastDL.ShowConfirm = function(title, description)
	if state.confirmMenu ~= nil then
		return true
	end

	-- report not-ready so the caller retries once the frontend has rebuilt
	local host = FindHostMenu()
	if host == nil then
		return false
	end

	state.answered = false
	state.title = title or "MISSING MAP"
	state.description = description or ""

	local controller = GetController()
	local menu = Try(function()
		return CoD.OverlayUtility.CreateOverlay(controller, host, CONFIRM_OVERLAY)
	end)

	if menu == nil then
		return false
	end

	state.confirmMenu = menu
	return true
end

BoiiiFastDL.ShowProgress = function(title)
	if state.progressMenu ~= nil then
		return true
	end

	local host = FindHostMenu()
	if host == nil then
		return false
	end

	state.title = title or "DOWNLOADING MAP"
	state.description = ""
	state.percent = 0

	local controller = GetController()
	local menu = Try(function()
		return CoD.OverlayUtility.CreateOverlay(controller, host, PROGRESS_OVERLAY)
	end)

	if menu == nil then
		return false
	end

	state.progressMenu = menu
	return true
end

BoiiiFastDL.Close = function()
	local confirmMenu = state.confirmMenu
	local progressMenu = state.progressMenu

	state.confirmMenu = nil
	state.progressMenu = nil

	CloseMenu(confirmMenu)
	CloseMenu(progressMenu)

	return true
end
