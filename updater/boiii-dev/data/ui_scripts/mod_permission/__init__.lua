-- Asks the player to trust a mod that called a blocked Lua function. The accept is validated in C++
-- (ui_scripting.cpp), since anything here shares a VM with the mod asking.

if CoD == nil or CoD.OverlayUtility == nil then
	return
end

local OVERLAY = "BoiiiModPermission"

BoiiiModPermission = BoiiiModPermission or {}

local state = BoiiiModPermission.state
if state == nil then
	state = {
		menu = nil,
		title = "",
		description = "",
		allow = nil
	}
	BoiiiModPermission.state = state
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

local function Close(menu, controller)
	state.menu = nil
	state.allow = nil
	Try(function() GoBack(menu, controller) end)
end

CoD.OverlayUtility.AddSystemOverlay(OVERLAY, {
	menuName = CoD.OverlayUtility.AutoSizeMenuFromDescription(OVERLAY),
	categoryType = CoD.OverlayUtility.OverlayTypes.Warning,
	title = function()
		return state.title
	end,
	description = function()
		return state.description
	end,
	listDatasource = function()
		DataSources[OVERLAY] = DataSourceHelpers.ListSetup(OVERLAY, function(controller)
			-- Deny first so a stray confirm press lands on the safe choice
			return {
				{
					models = {
						displayText = "DON'T ALLOW"
					},
					properties = {
						action = function(element, event, controller, param, menu)
							Close(menu, controller)
						end
					}
				},
				{
					models = {
						displayText = "ALLOW AND RESTART"
					},
					properties = {
						action = function(element, event, controller, param, menu)
							local allow = state.allow
							if allow ~= nil and Try(function() return allow() end) then
								Close(menu, controller)
							end
						end
					}
				}
			}
		end, true, nil)
		return OVERLAY
	end,
	[CoD.OverlayUtility.GoBackPropertyName] = function()
		return function(element, event, controller, menu)
			Close(menu, controller)
		end
	end
})

-- Called from C++; returns false while no menu can host it so the caller retries
BoiiiModPermission.Show = function(title, description, allow)
	if state.menu ~= nil then
		return true
	end

	local host = FindHostMenu()
	if host == nil then
		return false
	end

	state.title = title or ""
	state.description = description or ""
	state.allow = allow

	local controller = Engine.GetPrimaryController()
	local menu = Try(function()
		return CoD.OverlayUtility.CreateOverlay(controller, host, OVERLAY)
	end)

	if menu == nil then
		state.allow = nil
		return false
	end

	state.menu = menu
	return true
end
