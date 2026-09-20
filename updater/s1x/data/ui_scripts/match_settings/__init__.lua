if (game:issingleplayer() or not Engine.InFrontend()) then
	return
end

-- "MATCH SETTINGS" in the private match lobby (MP, Exo Zombies, Exo Survival); only sets nat_autoOpen, which nat.cpp reads in-match
local LOBBY_MENU = "menu_xboxlive_privatelobby"
local POPUP_ID = "cb_match_settings_popup"
local MENU_ID = "cb_match_settings_menu"
local BUTTON_ID = "cb_match_settings_button"

local DESCRIPTION = "Choose whether friends can join as soon as the match starts."

game:addlocalizedstring("CB_MATCH_SETTINGS_OPEN_TO_FRIENDS", "Open To Friends")
game:addlocalizedstring("CB_MATCH_SETTINGS_OPEN_TO_FRIENDS_DESC",
	"Open the match to friends as soon as it starts. Stays set until you restart the game.")

local function log(message)
	print("[cb_lui] match_settings: " .. tostring(message))
end

local function is_host()
	local ok, host = pcall(Lobby.IsGameHost)
	return ok and host
end

local function auto_open_text()
	return Engine.Localize(Engine.GetDvarBool("nat_autoOpen") and "@LUA_MENU_ENABLED" or "@LUA_MENU_DISABLED")
end

local function toggle_auto_open()
	Engine.SetDvarBool("nat_autoOpen", not Engine.GetDvarBool("nat_autoOpen"))
end

local builders = LUI.MenuBuilder.m_types_build

-- Stock popup (same in IW6 and H1); unverified in S1, so the options menu below covers its absence.
local use_popup = type(builders["generic_selectionList_popup"]) == "function"
	and GenericButtonSettings and GenericButtonSettings.Variants and GenericButtonSettings.Variants.Select
	and LUI.UIElement.getFirstDescendentById ~= nil

local function add_description(list, text)
	local text_element = LUI.UIText.new({
		topAnchor = true,
		leftAnchor = true,
		rightAnchor = true,
		top = 0,
		height = 16,
		left = 10,
		right = -10,
		font = RegisterFont("fonts/bodyFont", 16),
		alignment = LUI.Alignment.Left,
		alpha = 0.8
	})
	text_element:setText(text)
	list:addElement(text_element)
end

local match_settings_menu

local function match_settings_popup(a1, a2)
	local built, popup = pcall(LUI.MenuBuilder.BuildRegisteredType, "generic_selectionList_popup", {
		popup_title = "MATCH SETTINGS",
		popup_width = 500
	})

	local list = built and popup and popup:getFirstDescendentById("generic_selectionList_content_id")
	if not list then
		log(built and "generic_selectionList_content_id not found, using an options menu" or popup)
		if built and popup and popup.close then
			pcall(popup.close, popup)
		end

		use_popup = false
		return match_settings_menu(a1, a2)
	end

	list:addElement(LUI.UIElement.new({ topAnchor = true, leftAnchor = true, top = 0, height = 5, left = 0, width = 1 }))
	add_description(list, "Open the match to friends as soon as it starts.")
	add_description(list, "Stays set until you restart the game.")
	list:addElement(LUI.UIElement.new({ topAnchor = true, leftAnchor = true, top = 0, height = 10, left = 0, width = 1 }))

	LUI.MenuBuilder.BuildAddChild(list, {
		type = "UIGenericButton",
		id = "cb_match_settings_open_to_friends",
		properties = {
			variant = GenericButtonSettings.Variants.Select,
			button_text = "OPEN TO FRIENDS",
			button_display_func = auto_open_text,
			button_left_func = toggle_auto_open,
			button_right_func = toggle_auto_open,
			buttonActionIsRightAction = true,
			maxLabelWidth = 200
		}
	})

	LUI.MenuBuilder.BuildAddChild(list, {
		type = "UIGenericButton",
		id = "cb_match_settings_back",
		properties = {
			button_text = "BACK",
			button_action_func = function(element)
				LUI.FlowManager.RequestLeaveMenu(element)
			end
		}
	})

	return popup
end

-- Same pattern as the mod's stats menu, so every call here is known to exist in S1.
match_settings_menu = function(a1, a2)
	local menu = LUI.MenuTemplate.new(a1, {
		menu_title = "MATCH SETTINGS",
		menu_width = GenericMenuDims.menu_right_wide - GenericMenuDims.menu_left,
		menu_height = 548
	})

	menu:setClass(LUI.Options)
	menu.controller = a2 and a2.exclusiveController

	menu:AddButtonVariant(GenericButtonSettings.Variants.Select, "@CB_MATCH_SETTINGS_OPEN_TO_FRIENDS",
		"@CB_MATCH_SETTINGS_OPEN_TO_FRIENDS_DESC", auto_open_text, toggle_auto_open, toggle_auto_open)

	menu:AddBottomDescription(menu:InitScrolling())
	menu:AddBackButton(function()
		LUI.common_menus.Options.HideOptionsBackground()
		LUI.FlowManager.RequestLeaveMenu(menu)
	end)

	LUI.common_menus.Options.ShowOptionsBackground()
	return menu
end

local registered = pcall(function()
	if use_popup then
		if type(LUI.MenuBuilder.registerPopupType) == "function" then
			LUI.MenuBuilder.registerPopupType(POPUP_ID, match_settings_popup)
		else
			LUI.MenuBuilder.registerType(POPUP_ID, match_settings_popup)
		end
	else
		log("generic_selectionList_popup unavailable, using an options menu")
	end

	LUI.MenuBuilder.registerType(MENU_ID, match_settings_menu)
end)

if not registered then
	log("failed to register the match settings menu")
	return
end

local function open_match_settings(element, event)
	if not is_host() then
		return
	end

	local controller = (event and event.controller) or Engine.GetFirstActiveController()
	if use_popup then
		LUI.FlowManager.RequestPopupMenu(element, POPUP_ID, true, controller, false, {})
	else
		LUI.FlowManager.RequestAddMenu(element, MENU_ID, true, controller, false)
	end
end

local function button_text(child)
	if child.properties and type(child.properties.button_text) == "string" then
		return child.properties.button_text
	end

	if child.textLabel and child.textLabel.getText then
		local ok, text = pcall(child.textLabel.getText, child.textLabel)
		if ok and type(text) == "string" then
			return text
		end
	end

	return nil
end

-- GAME SETUP's slot can differ per mode, so find it by label and fall back to H1's id.
local function find_game_setup(list)
	local label = Engine.ToUpperCase(Engine.Localize("@LUA_MENU_GAME_SETUP"))
	local child = list:getFirstChild()
	while child do
		local text = button_text(child)
		if text and Engine.ToUpperCase(Engine.Localize(text)) == label then
			return child
		end

		child = child:getNextSibling()
	end

	return list.getChildById and list:getChildById(LOBBY_MENU .. "_button_1") or nil
end

local function add_match_settings(menu)
	-- LUI elements are userdata, not tables
	if not menu or menu.cb_match_settings_added then
		return
	end

	menu.cb_match_settings_added = true

	if not menu.list or not menu.AddButton then
		log(LOBBY_MENU .. " has no button list (type " .. type(menu) .. ")")
		return
	end

	-- Host-only like START GAME and GAME SETUP
	if not is_host() then
		return
	end

	local button = menu:AddButton("Match Settings", open_match_settings, function()
		return not is_host()
	end, nil, nil, { desc_text = DESCRIPTION })

	if not button then
		log("AddButton returned nothing")
		return
	end

	if button.rename then
		button:rename(BUTTON_ID)
	end

	if button.setDisabledRefreshRate then
		button:setDisabledRefreshRate(500)
	end

	local game_setup = find_game_setup(menu.list)
	if game_setup and game_setup ~= button then
		menu.list:removeElement(button)
		button:addElementAfter(game_setup)
	else
		log("GAME SETUP button not found; MATCH SETTINGS left at the end of the list")
	end
end

local function after_build(menu)
	local ok, err = pcall(add_match_settings, menu)
	if not ok then
		log(err)
	end

	return menu
end

if type(builders[LOBBY_MENU]) == "function" then
	local build_lobby = builders[LOBBY_MENU]
	builders[LOBBY_MENU] = function(...)
		return after_build(build_lobby(...))
	end
elseif type(LUI.MenuBuilder.buildMenu) == "function" then
	log(LOBBY_MENU .. " builder not registered yet, hooking buildMenu")
	local build_menu = LUI.MenuBuilder.buildMenu
	LUI.MenuBuilder.buildMenu = function(name, ...)
		local menu = build_menu(name, ...)
		if name == LOBBY_MENU then
			after_build(menu)
		end

		return menu
	end
else
	log("no way to hook " .. LOBBY_MENU)
end
