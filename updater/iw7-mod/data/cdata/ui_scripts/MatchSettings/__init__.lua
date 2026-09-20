if not Engine.InFrontend() then
	return
end

-- "MATCH SETTINGS" in the MP and Zombies private match lobbies; the popup only sets dvars that nat.cpp reads in-match
local POPUP_ID = "CBMatchSettingsPopup"
local POPUP_WIDTH = _1080p * 500

local function fit_to_popup(element, height)
	element:SetAnchors(0, 1, 1, 0, 0)
	element:SetLeft(0, 0)
	element:SetRight(POPUP_WIDTH, 0)
	element:SetTop(0, 0)
	element:SetBottom(height, 0)
end

local function build_description(text)
	local container = LUI.UIElement.new()
	container.id = "Description"
	fit_to_popup(container, _1080p * 64)

	local label = LUI.UIText.new()
	label:SetFont(FONTS.GetFont(FONTS.MainCondensed.File))
	label:SetFontSize(22 * _1080p)
	label:SetAlignment(LUI.Alignment.Left)
	label:SetWordWrap(true)
	label:SetRGBFromTable(SWATCHES.Popups.bodyTxt, 0)
	label:SetAlpha(0.8, 0)
	label:SetAnchorsAndPosition(0, 1, 0, 1, _1080p * 12, POPUP_WIDTH - _1080p * 12, _1080p * 8, _1080p * 30)
	label:setText(text)
	container:addElement(label)

	return container
end

MenuBuilder.m_types[POPUP_ID] = function(menu, props)
	local controllerIndex = props.controllerIndex or Engine.GetFirstActiveController()

	local OpenToFriends = MenuBuilder.BuildRegisteredType("GenericArrowButton", {
		controllerIndex = controllerIndex
	})
	OpenToFriends.id = "OpenToFriends"
	OpenToFriends.Title:setText(ToUpperCase("Open To Friends"), 0)
	fit_to_popup(OpenToFriends, _1080p * 35)
	LUI.AddUIArrowTextButtonLogic(OpenToFriends, controllerIndex, {
		labels = { Engine.Localize("LUA_MENU_DISABLED"), Engine.Localize("LUA_MENU_ENABLED") },
		wrapAround = true,
		defaultValue = Engine.GetDvarBool("nat_autoOpen") and 2 or 1,
		action = function(valueIndex)
			Engine.SetDvarBool("nat_autoOpen", valueIndex == 2)
		end
	})

	local Description = build_description(
		"Open the match to friends as soon as it starts. Stays set until you restart the game.")

	local ButtonHelperBar = MenuBuilder.BuildRegisteredType("button_helper_text_main", {
		left_inset = 0,
		right_inset = -30,
		top_margin = 0,
		bottom_margin = 0,
		height = GenericFooterDims.Height,
		spacing = 5,
		background_alpha = 1,
		list_left_inset = 0,
		controllerIndex = controllerIndex
	})
	ButtonHelperBar.id = "ButtonHelperBar"
	fit_to_popup(ButtonHelperBar, 0)
	ButtonHelperBar:SetTop(_1080p * -50, 0)

	local popup = MenuBuilder.BuildRegisteredType("PopupList", {
		title = "MATCH SETTINGS",
		width = POPUP_WIDTH,
		defaultFocusIndex = 1,
		cancelClosesPopup = true,
		listContent = { OpenToFriends, Description, ButtonHelperBar }
	})
	popup.id = POPUP_ID
	popup:AddButtonHelperTextToElement(ButtonHelperBar, {
		helper_text = Engine.Localize("MENU_BACK"),
		button_ref = "button_secondary",
		side = "left",
		priority = 1,
		clickable = true
	})

	return popup
end

-- Only the host's settings matter, so members get it disabled like GAME SETUP
local function build_lobby_button(list, controllerIndex, buttonType)
	local host = LUI.DataSourceInGlobalModel.new("frontEnd.lobby.areWeGameHost")
	local is_host = function()
		return host:GetValue(controllerIndex) == true
	end

	local button = MenuBuilder.BuildRegisteredType(buttonType, {
		controllerIndex = controllerIndex
	})
	button.id = "MatchSettings"
	button.buttonDescription = "Choose whether friends can join as soon as the match starts."
	button.Text:setText(ToUpperCase("Match Settings"), 0)
	button:addEventHandler("button_action", function(element, event)
		if is_host() then
			LUI.FlowManager.RequestPopupMenu(element, POPUP_ID, true, event.controller or controllerIndex, false, {})
		end
	end)

	button:SetButtonDisabled(not is_host())
	list:SubscribeToModel(host:GetModel(controllerIndex), function()
		button:SetButtonDisabled(not is_host())
	end)

	list.MatchSettings = button
	return button
end

local function controller_index_of(controller)
	return (controller and controller.controllerIndex) or Engine.GetFirstActiveController()
end

local PrivateMatchLobbyButtons = MenuBuilder.m_types["PrivateMatchLobbyButtons"]
MenuBuilder.m_types["PrivateMatchLobbyButtons"] = function(menu, controller)
	local self = PrivateMatchLobbyButtons(menu, controller)

	local ok, err = pcall(function()
		local button = build_lobby_button(self, controller_index_of(controller), "GenericButton")
		button:SetAnchorsAndPosition(0, 0, 0, 1, 0, 0, 0, _1080p * 30)
		button:addElementBefore(self.ButtonDescription)
	end)
	if not ok then
		print("MatchSettings: " .. tostring(err))
	end

	return self
end

local CPPrivateMatchButtons = MenuBuilder.m_types["CPPrivateMatchButtons"]
MenuBuilder.m_types["CPPrivateMatchButtons"] = function(menu, controller)
	local self = CPPrivateMatchButtons(menu, controller)
	if type(isAliensSolo) == "function" and isAliensSolo() then
		return self
	end

	local ok, err = pcall(function()
		-- The zombies list is absolutely positioned: slot in under Armory and push the rest down a row
		local step = _1080p * 40
		local _, top, _, bottom = self.Armory:getLocalRect()

		local button = build_lobby_button(self, controller_index_of(controller), "MenuButton")
		button:SetAnchorsAndPosition(0, 1, 0, 1, 0, _1080p * 340, top + step, bottom + step)
		button:addElementBefore(self.ForSpacing)

		for _, element in ipairs({ self.ForSpacing, self.ButtonDescription, self.ContractsButton }) do
			local _, elementTop, _, elementBottom = element:getLocalRect()
			element:SetTop(elementTop + step, 0)
			element:SetBottom(elementBottom + step, 0)
		end
	end)
	if not ok then
		print("MatchSettings: " .. tostring(err))
	end

	return self
end
