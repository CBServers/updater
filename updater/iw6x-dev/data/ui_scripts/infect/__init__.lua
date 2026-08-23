f0_local0 = function ( f1_arg0, f1_arg1 )
	f1_arg0:processEvent( LUI.ButtonHelperText.CommonEvents.addBackButton )
end

f0_local1 = function ( f2_arg0, f2_arg1, f2_arg2 )
	Engine.NotifyServer( "class_select", f2_arg2 )
	LUI.FlowManager.RequestLeaveMenu( f2_arg0 )
end

f0_local2 = function ( f3_arg0, f3_arg1 )
	local f3_local0 = LUI.FlowManager.GetMenuScopedDataFromElement( f3_arg0 )
	if f3_local0.defaultLoadouts then
		f3_arg0:dispatchEventToMenuRoot( {
			name = "refresh_char_select_list",
			defaultLoadouts = false
		} )
	else
		LUI.FlowManager.RequestLeaveMenu( f3_arg0 )
	end
end

local f0_local3 = function ( f4_arg0, f4_arg1, f4_arg2 )
	local f4_local0 = GameX.GetGameMode()
	if f4_local0 == "infect" and not Cac.IsClassInUse( f4_arg0, f4_arg1, f4_arg2, "defaultClassesTeam" .. Game.GetPlayerTeam(), 0 ) then
		return true
	elseif f4_local0 ~= "infect" and GameX.UsesFakeLoadout() then
		return true
	else
		return false
	end
end

local f0_local4 = function ( f5_arg0 )
	if f5_arg0 == "infect" then
		return true
	else

	end
end

local f0_local5 = function ( f6_arg0 )
	local f6_local0 = ""
	if GameX.GetGameMode() == "infect" then
		if f6_arg0 == Teams.allies then
			f6_local0 = Engine.Localize( Engine.Localize( "LUA_MENU_MP_SURVIVOR_LOADOUT" ) )
		elseif f6_arg0 == Teams.axis then
			f6_local0 = Engine.Localize( Engine.Localize( "LUA_MENU_MP_INFECTED_LOADOUT" ) )
		end
	else
		f6_local0 = Engine.Localize( "@LUA_MENU_DEFAULT_LOADOUT" )
	end
	return f6_local0
end

local f0_local6 = function ( f7_arg0, f7_arg1 )
	if f7_arg1.value > -1 then
		return
	else
		f7_arg0:dispatchEventToRoot( {
			name = "toggle_pause_off"
		} )
		LUI.FlowManager.RequestCloseAllMenus( f7_arg0 )
	end
end

local f0_local7 = function ( f8_arg0, f8_arg1 )
	f8_arg0:dispatchEventToMenuRoot( {
		name = "cac_set_slot",
		slot = f8_arg0.properties.slot,
		controller = f8_arg0.properties.controller,
		classLocation = f8_arg0.properties.classLocation,
		immediate = true
	} )
	f8_arg0:processEvent( {
		name = "hide_restrictions_icon"
	} )
	f8_arg0:dispatchEventToMenuRoot( {
		name = "refresh_specialist_abilities_recap",
		controller = f8_arg0.properties.controller,
		specialistType = Cac.GetPerk( f8_arg0.properties.controller, f8_arg0.properties.squadLocation, f8_arg0.properties.squadMemberIndex, f8_arg0.properties.classLocation, f8_arg0.properties.slot, Cac.Indices.StreakType ) == "streaktype_specialist",
		selected = false,
		immediate = true
	} )
end

local f0_local8 = function ( f9_arg0, f9_arg1, f9_arg2, f9_arg3 )
	if GameX.GetGameMode() == "sd" or GameX.GetGameMode() == "sr" then
		for f9_local0 = 0, Cac.GetNumCustomSlots( f9_arg0, f9_arg3 ) - 1, 1 do
			if f9_local0 ~= 5 and Cac.IsClassInUse( f9_arg0, f9_arg1, f9_arg2, f9_arg3, f9_local0 ) then
				return false
			end
		end
		return true
	else

	end
end

function UpdateRestrictionsIcon( f10_arg0, f10_arg1 )
	local f10_local0 = f10_arg0:getParent()
	if MatchRules.AllowCustomClasses( f10_arg0.properties.classLocation ) and MatchRules.CustomClassIsRestricted( f10_arg0.properties.controller, CoD.GetStatsGroupForGameMode(), f10_arg0.properties.squadLocation, f10_arg0.properties.squadMemberIndex, f10_arg0.properties.classLocation, f10_arg0.properties.slot ) then
		f10_arg0:animateToState( "visible" )
	else
		f10_arg0:animateToState( "default" )
	end
end

function HideRestrictionsIcon( f11_arg0, f11_arg1 )
	if MatchRules.AllowCustomClasses( f11_arg0.properties.classLocation ) and MatchRules.CustomClassIsRestricted( f11_arg0.properties.controller, CoD.GetStatsGroupForGameMode(), f11_arg0.properties.squadLocation, f11_arg0.properties.squadMemberIndex, f11_arg0.properties.classLocation, f11_arg0.properties.slot ) then
		f11_arg0:dispatchEventToMenuRoot( {
			name = "show_class_restrictions_warning"
		} )
	else
		f11_arg0:dispatchEventToMenuRoot( {
			name = "hide_class_restrictions_warning"
		} )
	end
	f11_arg0:animateToState( "default" )
end

local f0_local9 = function ( f12_arg0, f12_arg1, f12_arg2, f12_arg3, f12_arg4, f12_arg5, f12_arg6, f12_arg7 )
	local f12_local0 = Game.GetPlayerTeam()
	if f12_local0 == Teams.free then
		f12_local0 = Teams.allies
	end
	if Cac.IsDefaultClass( f12_arg3 ) then
		f12_arg6 = f12_arg6 - Cac.Settings.DataLoc[f12_arg7].maxClassSlots + Cac.Settings.DataLoc[f12_arg3].maxClassSlots * (f12_local0 - 1)
	end
	local f12_local1 = {
		type = "UIGenericButton",
		id = "btn_MPLoadout_" .. f12_arg3 .. f12_arg4,
		disabledFunc = function ( f13_arg0, f13_arg1 )
			local f13_local0 = Cac.IsCaCSlotLocked( f12_arg0, f12_arg1, f12_arg2, f12_arg3, f12_arg4 )
			if not f13_local0 then
				f13_local0 = Cac.IsCaCSlotRestricted( f12_arg0, f12_arg1, f12_arg2, f12_arg3, f12_arg4 )
			end
			return f13_local0
		end
	}
	local f12_local2 = {
		childNum = f12_arg4 + 1,
		squadLocation = f12_arg1,
		squadMemberIndex = f12_arg2,
		classLocation = f12_arg3,
		slot = f12_arg4,
		controller = f12_arg0,
		button_text = f12_arg5,
		button_action_func = function ( f14_arg0, f14_arg1 )
			local f14_local0 = f12_arg4
			if Cac.IsDefaultClass( f14_arg0.properties.classLocation ) and f12_arg7 then
				f14_local0 = f14_local0 + Cac.Settings.DataLoc[f12_arg7].maxClassSlots + Cac.Settings.DataLoc[f12_arg3].maxClassSlots * (f12_local0 - 1)
			end
			Engine.ExecNow( "set current_class_location " .. f12_arg3 )
			Engine.NotifyServer( "class_select", f14_local0 )
			local f14_local1 = MBh.EmitEventToRoot( "toggle_pause_off" )
			f14_local1( f14_arg0 )
			LUI.FlowManager.RequestCloseAllMenus( f14_arg0 )
		end,
		button_over_func = f0_local7,
		button_over_disable_func = f0_local7,
		button_up_func = MBh.EmitEvent( {
			name = "show_restrictions_icon"
		} )
	}
	if f12_arg6 == f12_arg4 then
		local f12_local3 = Engine.GetDvarString( "current_class_location" )
		local f12_local4 = Colors.yellow
	end
	f12_local2.text_default_color = f12_local3 and f12_local4 or Colors.generic_button_text_default_color
	f12_local1.properties = f12_local2
	f12_local1.handlers = {
		menu_create = function ( f15_arg0, f15_arg1 )
			f15_arg0.listDefaultFocus = f12_arg6 == f12_arg4
		end,
		button_disable = MBh.EmitEvent( {
			name = "show_restrictions_icon"
		} )
	}
	f12_local1.children = {
		{
			type = "UIImage",
			id = "weapon_restriction_icon",
			states = {
				default = {
					rightAnchor = true,
					leftAnchor = false,
					topAnchor = false,
					bottomAnchor = true,
					right = 32,
					bottom = -7,
					width = 32,
					height = 32,
					material = RegisterMaterial( "icon_new_3" ),
					alpha = 0
				},
				visible = {
					alpha = 1
				}
			},
			properties = {
				controller = MBh.Property( "controller" ),
				squadLocation = MBh.Property( "squadLocation" ),
				squadMemberIndex = MBh.Property( "squadMemberIndex" ),
				classLocation = MBh.Property( "classLocation" ),
				slot = MBh.Property( "slot" )
			},
			handlers = {
				hide_restrictions_icon = HideRestrictionsIcon,
				show_restrictions_icon = UpdateRestrictionsIcon,
				menu_create = UpdateRestrictionsIcon
			}
		}
	}
	return f12_local1
end

local f0_local10 = function ( f16_arg0, f16_arg1 )
	local f16_local0 = f16_arg0.exclusiveController
	if not f16_local0 then
		DebugPrint( "[WARNING] CAC: using controller index 0, this is only ok if you are editing a menu" )
		f16_local0 = 0
	end
	local f16_local1 = Cac.Settings.DataLoc.privateMatchSquadMembers.maxClassSlots
	if Engine.UsingSplitscreenUpscaling() then
		local f16_local2 = f16_local1
	end
	local self = LUI.UIElement.new( {
		topAnchor = true,
		leftAnchor = true,
		bottomAnchor = false,
		rightAnchor = false,
		top = GenericMenuDims.menu_top,
		left = GenericMenuDims.menu_left,
		height = GenericButtonSettings.Styles.GradientButton.height * (f16_local2 or f16_local1 * 2 + 1),
		right = GenericMenuDims.menu_right,
		alignment = LUI.Alignment.Top
	} )
	self:setUseStencil( true )
	local f16_local4 = LUI.UIVerticalList.new( {
		topAnchor = true,
		leftAnchor = true,
		bottomAnchor = true,
		rightAnchor = true,
		alignment = LUI.Alignment.Top
	}, true )
	f16_local4.id = "change_loadout_selections_id"
	f16_local4:makeFocusable()
	local f16_local5 = Cac.GetCustomClassLoc( "loadouts" )
	local f16_local6 = Cac.GetSquadLoc()
	local f16_local7 = Cac.GetActiveSquadMember( f16_local0 )
	local f16_local8 = Game.GetOmnvar( "ui_loadout_selected" )
	local f16_local9 = Game.GetPlayerTeam()
	local f16_local10 = f0_local5( f16_local9 )
	if f0_local3( f16_local0, f16_local6, f16_local7 ) then
		LUI.MenuBuilder.BuildAddChild( f16_local4, {
			type = "UIGenericButton",
			id = "btn_fakeLoadout",
			properties = {
				childNum = 1,
				button_text = f16_local10,
				button_action_func = function ( f17_arg0, f17_arg1 )
					Engine.NotifyServer( "class_select", 0 )
					local f17_local0 = MBh.EmitEventToRoot( "toggle_pause_off" )
					f17_local0( f17_arg0 )
					LUI.FlowManager.RequestCloseAllMenus( f17_arg0 )
				end,
				text_default_color = Colors.yellow
			}
		} )
	else
		if not f16_arg1 and GameX.GetGameMode() ~= "infect" then
			for f16_local11 = 0, Cac.GetNumCustomSlots( f16_local0, "loadouts" ) - 1, 1 do
				LUI.MenuBuilder.BuildAddChild( f16_local4, f0_local9( f16_local0, f16_local6, f16_local7, f16_local5, f16_local11, Cac.GetLoadoutName( f16_local0, f16_local6, f16_local7, f16_local5, f16_local11 ), f16_local8 ) )
			end
		end
		local f16_local11 = "defaultClassesTeam" .. Game.GetPlayerTeam()
		if f16_local11 == "defaultClassesTeam0" then
			f16_local11 = "defaultClassesTeam2"
		end
		if Cac.HasCustomClasses( f16_local0, f16_local6, f16_local7, f16_local11 ) and not f0_local8( f16_local0, f16_local6, f16_local7, f16_local11 ) then
			if not f16_arg1 and GameX.GetGameMode() ~= "infect" then
				LUI.MenuBuilder.BuildAddChild( f16_local4, {
					type = "UIImage",
					id = "dividing_line",
					states = {
						default = {
							leftAnchor = true,
							rightAnchor = false,
							topAnchor = true,
							bottomAnchor = false,
							left = 8,
							right = 450,
							top = 0,
							bottom = 2,
							material = RegisterMaterial( "white" ),
							alpha = 0.3
						}
					}
				} )
				LUI.MenuBuilder.BuildAddChild( f16_local4, {
					type = "UIImage",
					id = "dividing_spacer",
					states = {
						default = {
							leftAnchor = true,
							rightAnchor = true,
							topAnchor = true,
							bottomAnchor = false,
							left = 0,
							right = 0,
							top = 0,
							height = 5,
							alpha = 0
						}
					}
				} )
				LUI.MenuBuilder.BuildAddChild( f16_local4, {
					type = "UIGenericButton",
					id = "default_loadouts_btn",
					properties = {
						squadLocation = f16_local6,
						squadMemberIndex = f16_local7,
						classLocation = f16_local11,
						slot = Cac.GetFirstCustomClass( f16_local0, f16_local6, f16_local7, f16_local11 ),
						controller = f16_local0,
						button_text = Engine.Localize( "@LUA_MENU_DEFAULT_CLASSES" ),
						button_action_func = function ( f18_arg0, f18_arg1 )
							f18_arg0:dispatchEventToMenuRoot( {
								name = "refresh_char_select_list",
								defaultLoadouts = true
							} )
						end,
						text_default_color = Cac.Settings.DataLoc[f16_local5].maxClassSlots and Colors.yellow or Colors.generic_button_text_default_color,
						button_over_func = f0_local7
					}
				} )
			else
				for f16_local12 = 0, Cac.GetNumCustomSlots( f16_local0, f16_local11 ) - 1, 1 do
					if Cac.IsClassInUse( f16_local0, f16_local6, f16_local7, f16_local11, f16_local12 ) then
						if (GameX.GetGameMode() == "sd" or GameX.GetGameMode() == "sr") and f16_local12 == 5 then
							break
						end
						local f16_local15 = Cac.GetLoadoutName( f16_local0, f16_local6, f16_local7, f16_local11, f16_local12 )
						if GameX.GetGameMode() == "infect" then
							if f16_local9 == Teams.allies and f16_local12 == 0 then
								f16_local15 = Engine.Localize( "LUA_MENU_MP_SURVIVOR_LOADOUT" )
							elseif f16_local9 == Teams.axis and f16_local12 == 0 then
								f16_local15 = Engine.Localize( "LUA_MENU_MP_INFECTED_LOADOUT" )
							elseif f16_local9 == Teams.axis and f16_local12 == 1 then
								break
							end
						end
						LUI.MenuBuilder.BuildAddChild( f16_local4, f0_local9( f16_local0, f16_local6, f16_local7, f16_local11, f16_local12, f16_local15, f16_local8, f16_local5 ) )
					end
				end
			end
		end
	end
	self:addElement( f16_local4 )
	return self
end

local f0_local11 = function ()
	local self = LUI.UIElement.new()
	self.id = "class_restrictions_warning"
	self:registerAnimationState( "default", {
		leftAnchor = false,
		rightAnchor = true,
		topAnchor = true,
		bottomAnchor = false,
		top = 54,
		right = -100,
		width = 500,
		height = 28,
		alpha = 0
	} )
	self:registerAnimationState( "visible", {
		alpha = 1
	} )
	self:animateToState( "default" )
	self:registerEventHandler( "show_class_restrictions_warning", function ( element, event )
		element:animateToState( "visible" )
		return true
	end )
	self:registerEventHandler( "hide_class_restrictions_warning", function ( element, event )
		element:animateToState( "default" )
		return true
	end )
	local f19_local1 = LUI.UIImage.new()
	f19_local1.id = "class_restrictions_warning_icon"
	f19_local1:registerAnimationState( "default", {
		leftAnchor = false,
		rightAnchor = true,
		topAnchor = true,
		bottomAnchor = false,
		right = 0,
		top = 2,
		width = 28,
		height = 28,
		material = RegisterMaterial( "icon_new_3" ),
		alpha = 1
	} )
	f19_local1:animateToState( "default" )
	self:addElement( f19_local1 )
	local f19_local2 = LUI.UIText.new()
	f19_local2.id = "class_restrictions_warning_text"
	f19_local2:setText( Engine.Localize( "PATCH_MENU_ITEM_RESTRICTED" ) )
	f19_local2:registerAnimationState( "default", CoD.ColorizeState( Colors.orange, {
		leftAnchor = true,
		rightAnchor = true,
		topAnchor = true,
		bottomAnchor = false,
		font = CoD.TextSettings.NormalFont.Font,
		left = 0,
		right = -35,
		top = 5,
		bottom = 5 + CoD.TextSettings.NormalFont.Height,
		alignment = LUI.Alignment.Right
	} ) )
	f19_local2:animateToState( "default" )
	self:addElement( f19_local2 )
	return self
end

local f0_local12 = function ( f22_arg0 )
	local self = LUI.UIElement.new()
	self.id = "change_loadout_display_id"
	self:registerAnimationState( "default", {
		topAnchor = true,
		leftAnchor = true,
		bottomAnchor = true,
		rightAnchor = true,
		top = 0,
		left = 130,
		bottom = 0,
		right = 0,
		alpha = 1
	} )
	self:animateToState( "default", 0 )
	self:registerEventHandler( "menu_create", function ( element, event )
		element:disableTreeFocus()
	end )
	local f22_local1 = "defaultClassesTeam" .. Game.GetPlayerTeam()
	local f22_local2 = GameX.GetGameMode()
	local f22_local3 = LUI.MenuBuilder.BuildRegisteredType
	local f22_local4 = "cac_recap"
	local f22_local5 = {
		exclusiveController = f22_arg0.exclusiveController,
		squad_location = Cac.GetSquadLoc(),
		member_index = Cac.GetActiveSquadMember( f22_arg0.exclusiveController )
	}
	if f0_local4( f22_local2 ) then
		local f22_local6 = f22_local1
	end
	f22_local5.class_location = f22_local6 or Cac.GetCustomClassLoc( "loadouts" )
	f22_local5.loadout_slot = 0
	f22_local3 = f22_local3( f22_local4, f22_local5 )
	f22_local3.id = "change_loadout_recap_id"
	self:addElement( f22_local3 )
	if Engine.UsingSplitscreenUpscaling() then
		f22_local4 = {}
		f22_local4 = GameX.GetSafeZoneSize()
		f22_local5 = {}
		f22_local5 = f22_local3:getLocalRect()
		f22_local3:registerAnimationState( "default", {
			topAnchor = true,
			bottomAnchor = false,
			rightAnchor = true,
			leftAnchor = false,
			top = f22_local5[2],
			bottom = f22_local5[4],
			right = f22_local4[3],
			width = f22_local5[3] - f22_local5[1]
		} )
		f22_local3:animateToState( "default", 0 )
	end
	return self
end

LUI.MenuBuilder.m_types["class_select_main"] = function ( f24_arg0, f24_arg1, f24_arg2 )
	local f24_local0 = Engine.Localize( "@LUA_MENU_CHOOSE_CLASS_CAPS" )
	local self = LUI.UIElement.new()
	self.id = "mp_change_loadout_id"
	self:registerAnimationState( "default", {
		topAnchor = true,
		leftAnchor = true,
		bottomAnchor = true,
		rightAnchor = true,
		top = 0,
		left = 0,
		bottom = 0,
		right = 0,
		alpha = 1
	} )
	self:animateToState( "default", 0 )
	self:registerEventHandler( "menu_create", f0_local0 )
	self:registerOmnvarHandler( "ui_pause_menu_show", LUI.mp_hud.OptionsMenu.pauseMenuUpdate )
	self:registerOmnvarHandler( "ui_options_menu", f0_local6 )
	local f24_local2 = LUI.UIElement.new( {
		worldBlur = 5
	} )
	f24_local2:setupWorldBlur()
	f24_local2.id = "csWorldBlurOverlay"
	self:addElement( f24_local2 )
	self:addElement( LUI.mp_hud.OptionsMenu.mp_pause_menu_background_def() )
	LUI.MenuBuilder.BuildAddChild( self, {
		type = "button_helper_text_main",
		id = "cshelper_text_id"
	} )
	if GameX.IsOnlineMatch() and not GameX.IsSplitscreen() then
		local f24_local3 = LUI.MenuBuilder.BuildRegisteredType( "online_friends_widget" )
		f24_local3.id = "csfriends_widget_id"
		self:addElement( f24_local3 )
	end
	local f24_local3 = LUI.UIBindButton.new()
	f24_local3.id = "clBackToGameStartButton"
	f24_local3:registerEventHandler( "button_start", f0_local2 )
	f24_local3:registerEventHandler( "button_secondary", f0_local2 )
	self:addElement( f0_local11() )
	self:addElement( LUI.mp_hud.OptionsMenu.mp_pause_menu_title_def( f24_local0 ) )
	self:addElement( f24_local3 )
	self:addElement( f0_local12( f24_arg1 ) )
	local f24_local4 = LUI.UITimer.new( 250, {
		name = "menuCreationTimer"
	}, nil, true, self, false )
	f24_local4.id = "updateTimer"
	self:addElement( f24_local4 )
	self:registerEventHandler( "menuCreationTimer", function ( element, event )
		element.listOfLoadouts = f0_local10( f24_arg1 )
		self:addElement( element.listOfLoadouts )
		element.listOfLoadouts:processEvent( {
			name = "gain_focus"
		} )
	end )
	self:registerEventHandler( "refresh_char_select_list", function ( element, event )
		local f26_local0 = LUI.FlowManager.GetMenuScopedDataFromElement( element )
		f26_local0.defaultLoadouts = event.defaultLoadouts
		local f26_local1 = nil
		if event.defaultLoadouts then
			f26_local1 = Engine.Localize( "@PATCH_MENU_DEFAULT_CLASSES_CAPS" )
		else
			f26_local1 = Engine.Localize( "@LUA_MENU_CHOOSE_CLASS_CAPS" )
		end
		element:dispatchEventToMenuRoot( {
			name = "update_header_text",
			string = f26_local1
		} )
		element.listOfLoadouts:close()
		element.listOfLoadouts = f0_local10( f24_arg1, event.defaultLoadouts )
		self:addElement( element.listOfLoadouts )
		element.listOfLoadouts:processEvent( {
			name = "gain_focus"
		} )
	end )
	return self
end
