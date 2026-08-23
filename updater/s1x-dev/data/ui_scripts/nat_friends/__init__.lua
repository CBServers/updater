if (game:issingleplayer()) then
	return
end

-- Force the options-menu module to load so the pause menu is registered before we wrap it.
pcall(require, "LUI.mp_hud.OptionsMenu")

local function friends_button_text()
	return Engine.GetDvarBool("nat_open") and "Close to Friends" or "Open to Friends"
end

-- Closes the pause menu so the button label reflects the new state on reopen.
local function nat_friends_confirmed(element)
	element:dispatchEventToRoot({ name = "toggle_pause_off" })
	LUI.FlowManager.RequestCloseAllMenus(element)
end

-- Reads nat_open (already flipped by the synchronous ExecNow below) to describe the result.
pcall(function()
	LUI.MenuBuilder.registerDef("popup_nat_friends", function()
		local is_open = Engine.GetDvarBool("nat_open")
		return {
			type = "generic_confirmation_popup",
			id = "popup_nat_friends_id",
			properties = {
				popup_title = is_open and "OPENED TO FRIENDS" or "CLOSED TO FRIENDS",
				message_text = is_open and "Friends can now join this match."
					or "Friends can no longer join this match.",
				confirmation_action = nat_friends_confirmed
			}
		}
	end)
end)

local function on_toggle_friends(element, menuItem)
	-- ExecNow so nat_open updates synchronously before the popup reads it.
	Engine.ExecNow("nat_host")

	local ok = pcall(function()
		local controller = (menuItem and menuItem.controller) or Engine.GetFirstActiveController()
		LUI.FlowManager.RequestPopupMenu(element, "popup_nat_friends", true, controller)
	end)

	-- If the popup couldn't show, still close the menu so the label refreshes.
	if (not ok) then
		nat_friends_confirmed(element)
	end
end

-- MWR/h1-style: pause menu registered as m_types_build["mp_pause_menu"], built on inGameBase
-- which exposes :AddButton(text, callback) -- see h1-mod pausequit.lua.
local builders = LUI.MenuBuilder and LUI.MenuBuilder.m_types_build
if (builders and type(builders["mp_pause_menu"]) == "function") then
	local original_build = builders["mp_pause_menu"]
	builders["mp_pause_menu"] = function(...)
		local menu = original_build(...)
		if (menu and Engine.GetDvarBool("sv_running")) then
			pcall(function()
				local button = menu:AddButton(friends_button_text(), on_toggle_friends)
				if (button and button.rename) then
					button:rename("mp_pause_menu_open_to_friends")
				end
			end)
		end
		return menu
	end
end
