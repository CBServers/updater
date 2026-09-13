if (game:issingleplayer() or not Engine.InFrontend()) then
	return
end

local Lobby = luiglobals.Lobby
local private_lobby = package.loaded["LUI.mp_menus.MPLivePrivateLobby"]
if (private_lobby == nil) then
	return
end

-- "MATCH SETTINGS" in the private match lobby; the popup only sets dvars that nat.cpp reads in-match
local POPUP_ID = "cb_match_settings_popup"
local POPUP_WIDTH = 500
local POPUP_HEIGHT = 185

local function is_not_host()
	return not Lobby.IsGameHost()
end

local function match_settings_items()
	return {
		{
			type = "UIGenericButton",
			id = "cb_match_settings_open_to_friends",
			properties = {
				style = GenericButtonSettings.Styles.GlassButton,
				substyle = GenericButtonSettings.Styles.GlassButton.SubStyles.SubMenu,
				variant = GenericButtonSettings.Variants.Select,
				content_width = 200,
				side = "left",
				button_text = "OPEN TO FRIENDS",
				button_display_func = function()
					return Engine.GetDvarBool("nat_autoOpen") and Engine.Localize("@LUA_MENU_ENABLED") or Engine.Localize("@LUA_MENU_DISABLED")
				end,
				button_left_func = function()
					Engine.SetDvarBool("nat_autoOpen", not Engine.GetDvarBool("nat_autoOpen"))
				end,
				button_right_func = function()
					Engine.SetDvarBool("nat_autoOpen", not Engine.GetDvarBool("nat_autoOpen"))
				end
			}
		},
		{
			type = "UIGenericButton",
			id = "cb_match_settings_back",
			properties = {
				style = GenericButtonSettings.Styles.GlassButton,
				substyle = GenericButtonSettings.Styles.GlassButton.SubStyles.SubMenu,
				button_text = Engine.Localize("@LUA_MENU_BACK"),
				button_action_func = MBh.LeaveMenu()
			}
		}
	}
end

local function description_line(id, text, top)
	return {
		type = "UIText",
		id = id,
		properties = {
			text = text
		},
		states = {
			default = {
				topAnchor = true,
				bottomAnchor = false,
				leftAnchor = true,
				rightAnchor = true,
				top = top,
				height = 18,
				left = 20,
				right = -20,
				alignment = LUI.Alignment.Left,
				font = CoD.TextSettings.SmallFont.Font,
				red = Colors.white.r,
				green = Colors.white.g,
				blue = Colors.white.b,
				alpha = 0.8
			}
		}
	}
end

local function match_settings_page()
	return {
		type = "UIElement",
		id = "cb_match_settings_page",
		states = {
			default = {
				topAnchor = true,
				bottomAnchor = true,
				leftAnchor = true,
				rightAnchor = true,
				top = AAR.Layout.TitleBarHeight + 1,
				bottom = -1,
				left = 1,
				right = -1
			}
		},
		children = {
			description_line("cb_match_settings_description_1", "Open the match to friends as soon as it starts.", 10),
			description_line("cb_match_settings_description_2", "Stays set until you restart the game.", 30),
			{
				type = "UIVerticalList",
				id = "cb_match_settings_list",
				states = {
					default = {
						topAnchor = false,
						bottomAnchor = true,
						leftAnchor = true,
						rightAnchor = true,
						top = -90,
						bottom = -8,
						left = 2,
						right = -2,
						spacing = 5
					}
				},
				childrenFeeder = match_settings_items
			}
		}
	}
end

local function match_settings_popup()
	return {
		type = "UIElement",
		id = "cb_match_settings_popup_container",
		states = {
			default = {
				topAnchor = true,
				bottomAnchor = true,
				leftAnchor = true,
				rightAnchor = true,
				top = 0,
				bottom = 0,
				left = 0,
				right = 0
			}
		},
		children = {
			{
				type = "UIImage",
				id = "cb_match_settings_darken",
				states = {
					default = CoD.ColorizeState(Swatches.Overlay.Color, {
						topAnchor = true,
						bottomAnchor = true,
						leftAnchor = true,
						rightAnchor = true,
						top = 0,
						bottom = 0,
						left = 0,
						right = 0,
						material = RegisterMaterial("white"),
						alpha = Swatches.Overlay.AlphaMore
					})
				}
			},
			{
				type = "UIElement",
				id = "cb_match_settings_window",
				states = {
					default = {
						topAnchor = false,
						bottomAnchor = false,
						leftAnchor = false,
						rightAnchor = false,
						top = -POPUP_HEIGHT / 2,
						width = POPUP_WIDTH,
						height = POPUP_HEIGHT
					}
				},
				children = {
					{
						type = "generic_drop_shadow",
						properties = {
							offset_shadow = 0
						}
					},
					{
						type = "generic_menu_titlebar",
						id = "cb_match_settings_title",
						properties = {
							title_bar_text = "MATCH SETTINGS",
							fill_alpha = 1
						}
					},
					{
						type = "generic_menu_background",
						id = "cb_match_settings_background",
						properties = {
							fill_alpha = 1
						}
					},
					{
						type = "cb_match_settings_page"
					},
					{
						type = "UIBindButton",
						id = "cb_match_settings_back_bind",
						handlers = {
							button_secondary = MBh.LeaveMenu()
						}
					}
				}
			}
		}
	}
end

LUI.MenuBuilder.m_definitions["cb_match_settings_page"] = match_settings_page
LUI.MenuBuilder.m_definitions[POPUP_ID] = match_settings_popup

-- Only the host's settings matter, so members get it disabled like GAME SETUP
local function match_settings_button()
	return {
		type = "UIGenericButton",
		id = "cb_match_settings_button",
		disabledFunc = is_not_host,
		properties = {
			disabledFunc = is_not_host,
			button_text = "MATCH SETTINGS",
			button_action_func = function(element, event)
				if not is_not_host() then
					LUI.FlowManager.RequestPopupMenu(element, POPUP_ID, true, event.controller, false, {})
				end
			end,
			desc_text = "Choose whether friends can join as soon as the match starts.",
			additional_handlers = {
				recheck_start_button_lock = private_lobby.RefreshButtonDisable
			},
			button_over_func = MBh.EmitEventToRoot({
				name = "lobby_slide_enable",
				dispatchChildren = true,
				immediate = true
			})
		}
	}
end

local options_feeder = private_lobby.LivePrivateLobbyOptionsFeeder
private_lobby.LivePrivateLobbyOptionsFeeder = function(props)
	local items = options_feeder(props)

	local ok, err = pcall(function()
		if props.aliensSoloMode == true then
			return
		end

		-- Slot it in right after GAME SETUP (or START MATCH when GAME SETUP is hidden)
		local index = 2
		for i, item in ipairs(items) do
			if item.id == "setup_match_button_id" then
				index = i + 1
				break
			end
		end

		table.insert(items, math.min(index, #items + 1), match_settings_button())
	end)

	if not ok then
		print("match_settings: " .. tostring(err))
	end

	return items
end
