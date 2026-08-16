if Engine.GetCurrentMap() ~= "core_frontend" then
	return
end

DataSources.BoiiiLobbySettings = DataSourceHelpers.ListSetup("BoiiiLobbySettings", function(controller)
	local optionsTable = {}

	local updateDvar = function(f1_arg0, f1_arg1, f1_arg2, dvarName, f1_arg4)
		UpdateInfoModels(f1_arg1)
		if Engine.DvarInt(nil, dvarName) == f1_arg1.value then
			return
		end
		Engine.SetDvar(dvarName, f1_arg1.value)
	end

	table.insert(optionsTable,
		CoD.OptionsUtility.CreateDvarSettings(controller, "Open To Friends",
			"Open the match to friends as soon as it starts, instead of opening it from the pause menu. Stays set until you restart the game.",
			"BoiiiLobbySettings_auto_open", "nat_autoOpen", {
				{
					option = "MENU_DISABLED",
					value = 0,
					default = true
				},
				{
					option = "MENU_ENABLED",
					value = 1
				},
			}, nil, updateDvar))

	local sessionMode = Engine.CurrentSessionMode()
	if sessionMode == Enum.eModes.MODE_ZOMBIES or sessionMode == Enum.eModes.MODE_CAMPAIGN then
		-- 0 means "use the live lobby count", which has no meaning without a lobby; show it as 1.
		if Engine.DvarInt(nil, "lobby_min_players") == 0 then
			Engine.SetDvar("lobby_min_players", 1)
		end

		local minPlayerOptions = {}
		for count = 1, 4 do
			table.insert(minPlayerOptions, {
				option = tostring(count),
				value = count,
				default = count == 1
			})
		end

		table.insert(optionsTable,
			CoD.OptionsUtility.CreateDvarSettings(controller, "Players To Start",
				"The match waits for this many players to join before it starts. Set it above 1 only if friends are joining.",
				"BoiiiLobbySettings_min_players", "lobby_min_players", minPlayerOptions, nil, updateDvar))
	end

	return optionsTable
end)

LUI.createMenu.BoiiiLobbySettingsMenu = function(controller)
	local self = CoD.Menu.NewForUIEditor("BoiiiLobbySettingsMenu")
	if PreLoadFunc then
		PreLoadFunc(self, controller)
	end
	self.soundSet = "ChooseDecal"
	self:setOwner(controller)
	self:setLeftRight(true, true, 0, 0)
	self:setTopBottom(true, true, 0, 0)
	self:playSound("menu_open", controller)
	self.buttonModel = Engine.CreateModel(Engine.GetModelForController(controller), "BoiiiLobbySettingsMenu.buttonPrompts")
	self.anyChildUsesUpdateState = true

	local GameSettingsBackground = CoD.GameSettings_Background.new(self, controller)
	GameSettingsBackground:setLeftRight(true, true, 0, 0)
	GameSettingsBackground:setTopBottom(true, true, 0, 0)
	GameSettingsBackground.MenuFrame.titleLabel:setText(Engine.Localize("MATCH SETTINGS"))
	GameSettingsBackground.MenuFrame.cac3dTitleIntermediary0.FE3dTitleContainer0.MenuTitle.TextBox1.Label0:setText(
	Engine.Localize("MATCH SETTINGS"))
	GameSettingsBackground.GameSettingsSelectedItemInfo.GameModeInfo:setAlpha(0)
	GameSettingsBackground.GameSettingsSelectedItemInfo.GameModeName:setAlpha(0)
	self:addElement(GameSettingsBackground)
	self.GameSettingsBackground = GameSettingsBackground

	local Options = CoD.Competitive_SettingsList.new(self, controller)
	Options:setLeftRight(true, false, 26, 741)
	Options:setTopBottom(true, false, 135, 720)
	Options.Title.DescTitle:setText(Engine.Localize("Match"))
	Options.ButtonList:setVerticalCount(6)
	Options.ButtonList:setDataSource("BoiiiLobbySettings")
	self:addElement(Options)
	self.Options = Options

	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_XBB_PSCIRCLE, nil,
		function(element, menu, controller, model)
			GoBack(self, controller)
			SetPerControllerTableProperty(controller, "disableGameSettingsOptions", nil)
			return true
		end, function(element, menu, controller)
			CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBB_PSCIRCLE, "MENU_BACK")
			return true
		end, false)

	GameSettingsBackground.MenuFrame:setModel(self.buttonModel, controller)
	Options.id = "Options"

	self:processEvent({
		name = "menu_loaded",
		controller = controller
	})
	self:processEvent({
		name = "update_state",
		menu = self
	})
	if not self:restoreState() then
		self.Options:processEvent({
			name = "gain_focus",
			controller = controller
		})
	end

	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		element.GameSettingsBackground:close()
		element.Options:close()
		Engine.UnsubscribeAndFreeModel(Engine.GetModel(Engine.GetModelForController(controller),
			"BoiiiLobbySettingsMenu.buttonPrompts"))
	end)

	if PostLoadFunc then
		PostLoadFunc(self, controller)
	end

	return self
end
