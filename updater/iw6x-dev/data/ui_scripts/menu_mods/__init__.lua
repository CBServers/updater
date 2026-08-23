function ModFeeder( f1_arg0 )
	local mod_buttons = {}
	if (not directoryexists("mods")) then
		return mod_buttons
	end

	local mods = listfiles("mods/")
	for i = 1, #mods do
		local mod_button = nil
		local mod_path = mods[i]
		local mod_name = mod_path:gsub("mods/", "")
		if (directoryexists(mods[i]) and not directoryisempty(mods[i])) then
			mod_button = {
				type = "UIGenericButton",
				id = "mod_button_" .. i,
				properties = {
					button_text = mod_name,
					button_action_func = MBh.EmitEventToRoot( {
						name = "select_mod",
						modtoload = mod_path
					} )
				}
			}
		end
		mod_buttons[#mod_buttons + 1] = mod_button
	end
	return mod_buttons
end

function SelectMod( f6_arg0, f6_arg1 )
	Engine.Exec("loadmod " .. f6_arg1.modtoload)
end

function UnloadMod()
	Engine.Exec("unloadmod")
end

function BackButtonFunc( f13_arg0 )
	LUI.FlowManager.RequestLeaveMenu( f13_arg0 )
end

function ModsMenuButtons( f2_arg0 )
	f2_arg0:dispatchEventToRoot( {
		name = "add_button_helper_text",
		button_ref = "button_secondary",
		helper_text = Engine.Localize( "@LUA_MENU_BACK" ),
		side = "left",
		clickable = true,
		immediate = true
	} )
	f2_arg0:dispatchEventToRoot( {
		name = "add_button_helper_text",
		button_ref = "button_action",
		helper_text = Engine.Localize( "@LUA_MENU_SELECT" ),
		side = "left",
		clickable = true,
		immediate = true
	} )
	f2_arg0:dispatchEventToRoot( {
		name = "add_button_helper_text",
		button_ref = "button_alt1",
		helper_text = "Unload Mod",
		side = "left",
		clickable = true,
		immediate = true
	} )
end

function mods_menu()
	return {
		type = "UIElement",
		id = "mods_menu_root",
		properties = {
			menu_title = "MODS",
			rotationAllowed = false
		},
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
		handlers = {
			menu_create = ModsMenuButtons,
			select_mod = SelectMod
		},
		children = {
			{
				type = "generic_menu_title",
				id = "mod_menu_title",
				properties = {
					menu_title = MBh.Property( "menu_title" )
				}
			},
			{
				type = "UIScrollingVerticalList",
				id = "modlist",
				childrenFeeder = ModFeeder,
				properties = {
					use_arrows = true,
					use_scrollbar = false,
					bar_width = 20
				},
				states = {
					default = {
						leftAnchor = true,
						rightAnchor = false,
						topAnchor = true,
						bottomAnchor = false,
						left = GenericMenuDims.menu_left,
						right = GenericMenuDims.menu_right,
						top = GenericMenuDims.menu_top,
						bottom = GenericMenuDims.menu_top + GenericButtonSettings.Styles.GradientButton.height * 11 + 2 + 60
					}
				}
			},
			{
				type = "UIBindButton",
				id = "mods_menu_bindbuttons",
				handlers = {
					button_secondary = BackButtonFunc,
					button_alt1 = UnloadMod
				}
			},
			{
				type = "button_helper_text_main",
				id = "mods_menu_button_helper_text_id"
			}
		}
	}
end

LUI.MenuBuilder.registerDef( "mods_menu", mods_menu )
