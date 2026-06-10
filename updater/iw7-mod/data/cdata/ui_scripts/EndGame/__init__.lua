if Engine.InFrontend() then
	return
end

local RequestLeaveMenu = function(f1_arg0, f1_arg1)
	LUI.FlowManager.RequestLeaveMenu(f1_arg0)
end

local PopupMessage = function(f2_arg0, f2_arg1)
	f2_arg0:setText(f2_arg1.message_text)
	f2_arg0:dispatchEventToRoot({
		name = "resize_popup",
	})
end

local Backout = function(f3_arg0)
	Engine.ExecFirstClient("xpartybackout")
	Engine.ExecFirstClient("disconnect")
end

local DisbandAfterRound = function(f4_arg0)
	Engine.ExecFirstClient("xpartydisbandafterround")
	Engine.ExecFirstClient("disconnect")
end

local OnlineGame = function(f5_arg0)
	return Engine.GetDvarBool("onlinegame")
end

local Quit1 = function(f6_arg0)
	if OnlineGame(f6_arg0) then
		Engine.ExecFirstClient("xstopprivateparty")
		Engine.ExecFirstClient("disconnect")
		Engine.ExecFirstClient("xblive_privatematch 0")
		Engine.ExecFirstClient("onlinegame 1")
		Engine.ExecFirstClient("xstartprivateparty")
	else
		Engine.ExecFirstClient("disconnect")
	end
end

local Quit2 = function(f7_arg0)
	Engine.ExecFirstClient("xstopprivateparty")
	Engine.ExecFirstClient("xpartydisbandafterround")
	if Engine.GetDvarBool("sv_running") then
		Engine.NotifyServer("end_game", 1)
		Engine.ExecFirstClient("xblive_privatematch 0")
		Engine.ExecFirstClient("onlinegame 1")
		Engine.ExecFirstClient("xstartprivateparty")
	else
		Quit1(f7_arg0)
	end
end

local Quit3 = function(f7_arg0, f7_arg1)
	if Engine.GetDvarBool("sv_running") then
		if Engine.IsAliensMode() then
			Engine.Unpause()
			if Engine.IsAliensMode() and not IsSystemLink() then
				for f7_local0 = 0, Engine.GetMaxControllerCount() - 1, 1 do
					if Engine.HasActiveLocalClient(f7_local0) then
						Loot.ConsumeAll(f7_local0)
					end
				end
			end
		end
		Engine.NotifyServer("end_game", 1)
		Engine.ExecNow("set endgame_called 1")
	else
		if Engine.IsAliensMode() and not IsSystemLink() then
			for f7_local0 = 0, Engine.GetMaxControllerCount() - 1, 1 do
				if Engine.HasActiveLocalClient(f7_local0) then
					Loot.ConsumeAll(f7_local0)
				end
			end
		end
		Quit1(f7_arg0)
	end
	LUI.FlowManager.RequestCloseAllMenus()
end

local LeaveWithParty = function(f8_arg0, f8_arg1)
	LUI.FlowManager.RequestLeaveMenu(f8_arg0)
	Engine.Exec("onPlayerQuit")
	if Engine.GetDvarBool("sv_running") then
		DisbandAfterRound(f8_arg0)
	else
		Backout(f8_arg0)
	end
	LUI.FlowManager.RequestCloseAllMenus()
end

local LeaveSolo = function(f9_arg0, f9_arg1)
	LUI.FlowManager.RequestLeaveMenu(f9_arg0)
	Engine.Exec("onPlayerQuit")
	if Engine.GetDvarBool("sv_running") then
		Engine.NotifyServer("end_game", 2)
		Quit2(f9_arg0)
	else
		Quit1(f9_arg0)
	end
	LUI.FlowManager.RequestCloseAllMenus()
end

local IsPartyHost = function(f10_arg0)
	local f10_local0 = Lobby.IsInPrivateParty()
	if f10_local0 then
		f10_local0 = Lobby.IsPrivatePartyHost()
		if f10_local0 then
			f10_local0 = not Lobby.IsAloneInPrivateParty()
		end
	end
	return f10_local0
end

local ManualQuit = function(f11_arg0, f11_arg1)
	Engine.ExecNow("uploadStats")
	if Engine.IsAliensMode() and not IsSystemLink() then
		for f11_local0 = 0, Engine.GetMaxControllerCount() - 1, 1 do
			if Engine.HasActiveLocalClient(f11_local0) then
				Loot.ConsumeAll(f11_local0)
			end
		end
	end
	if IsPartyHost(f11_arg0) then
		LUI.FlowManager.RequestLeaveMenu(f11_arg0, true)
		LUI.FlowManager.RequestPopupMenu(f11_arg0, "PullPartyPopup", false)
	else
		Engine.Exec("onPlayerQuit")
		if Engine.GetDvarBool("sv_running") then
			Quit2(f11_arg0)
		else
			Quit1(f11_arg0)
		end
		LUI.FlowManager.RequestCloseAllMenus()
	end
end

local EndGamePopup = function()
	local self = LUI.UIElement.new()
	self.id = "end_game_id"
	self:registerAnimationState("default", {
		topAnchor = true,
		leftAnchor = true,
		bottomAnchor = true,
		rightAnchor = true,
		top = -50,
		left = 0,
		bottom = 0,
		right = 0,
		alpha = 1,
	})
	self:animateToState("default", 0)
	local f12_local1 = Engine.Localize("@LUA_MENU_END_GAME_DESC")
	local f12_local2 = Engine.Localize("@LUA_MENU_LEAVE_GAME_TITLE")
	if Engine.IsAliensMode() and Game.GetOmnvar("zm_ui_is_solo") then
		f12_local1 = Engine.Localize("@CP_ZMB_LEAVE_GAME_DESC")
		f12_local2 = Engine.Localize("@MENU_NOTICE")
	end
	MenuBuilder.BuildAddChild(self, {
		type = "generic_yesno_popup",
		id = "privateGame_options_list_id",
		properties = {
			message_text_alignment = LUI.Alignment.Center,
			message_text = f12_local1,
			popup_title = f12_local2,
			padding_top = 12,
			yes_action = Quit3,
		},
	})
	local f12_local3 = LUI.UIBindButton.new()
	f12_local3.id = "endBackToGameStartButton"
	f12_local3:registerEventHandler("button_start", RequestLeaveMenu)
	self:addElement(f12_local3)
	return self
end

local LeaveGamePopup = function()
	local self = LUI.UIElement.new()
	self.id = "leave_game_id"
	self:registerAnimationState("default", {
		topAnchor = true,
		leftAnchor = true,
		bottomAnchor = true,
		rightAnchor = true,
		top = -50,
		left = 0,
		bottom = 0,
		right = 0,
		alpha = 1,
	})
	self:animateToState("default", 0)
	MenuBuilder.BuildAddChild(self, {
		type = "generic_yesno_popup",
		id = "publicGame_options_list_id",
		properties = {
			message_text_alignment = LUI.Alignment.Center,
			message_text = Engine.IsAliensMode() and Engine.Localize("@CP_ZMB_LEAVE_GAME_DESC")
				or Engine.Localize("@LUA_MENU_LEAVE_GAME_DESC"),
			popup_title = Engine.IsAliensMode() and Engine.Localize("@MENU_NOTICE")
				or Engine.Localize("@LUA_MENU_LEAVE_GAME_TITLE"),
			padding_top = 12,
			yes_action = ManualQuit,
		},
	})
	local f13_local1 = LUI.UIBindButton.new()
	f13_local1.id = "leaveBackToGameStartButton"
	f13_local1:registerEventHandler("button_start", RequestLeaveMenu)
	self:addElement(f13_local1)
	return self
end

local PullPartyPopup = function(f14_arg0, f14_arg1)
	local f14_local0 = MenuBuilder.BuildRegisteredType("PopupMessageAndButtons", {
		title = Engine.Localize("LUA_MENU_LEAVE_GAME_TITLE"),
		message = Engine.Localize("LUA_MENU_PULL_PARTY_DESC"),
		defaultFocusIndex = 2,
		cancelClosesPopup = true,
		buttonsClosePopup = true,
		buttons = {
			{
				label = Engine.Localize("LUA_MENU_YES"),
				action = LeaveWithParty,
			},
			{
				label = Engine.Localize("LUA_MENU_NO"),
				action = LeaveSolo,
			},
		},
	})
	f14_local0.id = "PullPartyPopup"
	return f14_local0
end

MenuBuilder.m_types["popup_end_game"] = EndGamePopup
MenuBuilder.m_types["popup_leave_game"] = LeaveGamePopup
MenuBuilder.m_types["PullPartyPopup"] = PullPartyPopup

-- nat_friends: "Open/Close to Friends" toggle injected into the pause button list.
-- iw7-mod uses the native PauseMenuButtons/CPPauseMenuButtons (not overridden like
-- h1/iw6x), so we wrap them and append our button. Host-only (sv_running); SP untouched.
pcall(function()
	local function friends_button_text()
		return Engine.GetDvarBool("nat_open") and "CLOSE TO FRIENDS" or "OPEN TO FRIENDS"
	end

	-- Close the menu so the button label reflects the new state on reopen.
	local function nat_friends_confirmed(element)
		pcall(function() element:dispatchEventToRoot({ name = "toggle_pause_off" }) end)
		pcall(function() LUI.FlowManager.RequestCloseAllMenus(element) end)
	end

	-- Popup reads nat_open (already flipped by the synchronous ExecNow below).
	MenuBuilder.m_types["popup_nat_friends"] = function()
		local is_open = Engine.GetDvarBool("nat_open")
		local self = LUI.UIElement.new()
		self.id = "popup_nat_friends_id"
		self:registerAnimationState("default", {
			topAnchor = true, leftAnchor = true, bottomAnchor = true, rightAnchor = true,
			top = -50, left = 0, bottom = 0, right = 0, alpha = 1,
		})
		self:animateToState("default", 0)
		MenuBuilder.BuildAddChild(self, {
			type = "generic_confirmation_popup",
			id = "popup_nat_friends_inner",
			properties = {
				popup_title = is_open and "OPENED TO FRIENDS" or "CLOSED TO FRIENDS",
				message_text = is_open and "Friends can now join this match."
					or "Friends can no longer join this match.",
				confirmation_action = nat_friends_confirmed,
			},
		})
		return self
	end

	local function on_toggle_friends(button, event)
		-- ExecNow so nat_open updates synchronously before the popup reads it.
		Engine.ExecNow("nat_host")
		local controller = (event and event.controller) or Engine.GetFirstActiveController()
		local shown = pcall(function()
			LUI.FlowManager.RequestPopupMenu(button, "popup_nat_friends", true, controller)
		end)
		if not shown then
			nat_friends_confirmed(button)
		end
	end

	local function inject_friends_button(button_type, list, ...)
		-- sv_running is true only on the listen-server host.
		if not Engine.GetDvarBool("sv_running") then
			return
		end

		local args = { ... }
		local props = args[2]
		local controllerIndex = (props and (props.controllerIndex or props.exclusiveController))
			or Engine.GetFirstActiveController()

		local button = MenuBuilder.BuildRegisteredType(button_type, { controllerIndex = controllerIndex })
		button.id = "nat_friends_button"
		if button.Text then
			button.Text:setText(friends_button_text(), 0)
		end
		button:addEventHandler("button_action", on_toggle_friends)
		list:addElement(button)
	end

	-- Wrap whichever pause button list the current mode registered, using the same
	-- button type that list builds natively (GenericButton in MP, MenuButton in Zombies)
	-- so our button matches the others' width/style.
	local function wrap_pause_buttons(name, button_type)
		local original = MenuBuilder.m_types[name]
		if type(original) == "function" then
			MenuBuilder.m_types[name] = function(...)
				local list = original(...)
				if list then
					pcall(inject_friends_button, button_type, list, ...)
				end
				return list
			end
		end
	end

	wrap_pause_buttons("PauseMenuButtons", "GenericButton")
	wrap_pause_buttons("CPPauseMenuButtons", "MenuButton")
end)
