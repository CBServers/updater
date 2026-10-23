-- The party follows its leader into dedicated servers (party_follow.cpp): the leader's NOT ENOUGH ROOM prompt,
-- the lobby mode switch before the join, and QUIT WITH PARTY / QUIT ALONE in the leader's in-match quit

if CoD == nil or CoD.OverlayUtility == nil or game == nil then
	return
end

local ROOM_OVERLAY = "BoiiiPartyRoom"
local QUIT_LIST = "BoiiiPartyQuitList"

BoiiiParty = BoiiiParty or {}

local room = BoiiiParty.room
if room == nil then
	room = {title = "", description = "", answered = true}
	BoiiiParty.room = room
end

local function Try(fn, ...)
	local ok, result = pcall(fn, ...)
	if ok then
		return result
	end
	return nil
end

-- Called from C++ there is no parent menu; use the topmost live one, as the FastDL popups do
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

local function AnswerRoom(choice, menu, controller)
	if room.answered then
		return
	end
	room.answered = true

	Try(game.partyRoomAnswer, choice)
	Try(GoBack, menu, controller)
end

local function RoomButton(text, choice)
	return {
		models = {
			displayText = text
		},
		properties = {
			action = function(element, event, controller, param, menu)
				AnswerRoom(choice, menu, controller)
			end
		}
	}
end

CoD.OverlayUtility.AddSystemOverlay(ROOM_OVERLAY, {
	menuName = "SystemOverlay_Compact",
	categoryType = CoD.OverlayUtility.OverlayTypes.Notice,
	title = function()
		return room.title
	end,
	description = function()
		return room.description
	end,
	listDatasource = function()
		DataSources[ROOM_OVERLAY] = DataSourceHelpers.ListSetup(ROOM_OVERLAY, function(controller)
			return {
				RoomButton("JOIN WITH PARTY", 1),
				RoomButton("JOIN ALONE", 2),
				RoomButton(Engine.Localize("MENU_CANCEL_CAPS"), 0)
			}
		end, true, nil)
		return ROOM_OVERLAY
	end,
	[CoD.OverlayUtility.GoBackPropertyName] = function()
		return function(element, event, controller, menu)
			AnswerRoom(0, menu, controller)
		end
	end
})

BoiiiParty.ShowRoomPrompt = function(title, description)
	local host = FindHostMenu()
	if host == nil then
		return false
	end

	room.title = title or "NOT ENOUGH ROOM"
	room.description = description or ""
	room.answered = false

	local menu = Try(CoD.OverlayUtility.CreateOverlay, Engine.GetPrimaryController(), host, ROOM_OVERLAY)
	if menu == nil then
		room.answered = true
		return false
	end

	return true
end

-- Moves the lobby to a dedicated server's mode as the menus do, one stock GoBack/GoForward per call (party.cpp)
local MODE_LOBBIES = {
	[Enum.LobbyMainMode.LOBBY_MAINMODE_MP] = "UI_MPLOBBYMAIN",
	[Enum.LobbyMainMode.LOBBY_MAINMODE_ZM] = "UI_ZMLOBBYONLINE",
	[Enum.LobbyMainMode.LOBBY_MAINMODE_CP] = "UI_CPLOBBYONLINE"
}
local LOBBY_STEP_TIMEOUT = 15000

local lobbyStep = nil

local function LobbyBusy()
	return Engine.GetModelValue(Engine.CreateModel(Engine.GetGlobalModel(), "lobbyRoot.spinnerActive")) == true
end

BoiiiParty.StepLobbyToMode = function(mainMode)
	local targets = LobbyData.UITargets
	local target = targets[MODE_LOBBIES[mainMode] or ""]
	if target == nil then
		return "fail"
	end

	local current = LobbyData:UITargetFromId(Engine.GetLobbyUIScreen())
	if current ~= nil and current.mainMode == mainMode then
		lobbyStep = nil
		return LobbyBusy() and "wait" or "done"
	end

	-- The title screen still needs START to sign in
	if current == nil or current.id == targets.UI_MAIN.id or LobbyBusy() then
		return "wait"
	end

	if not Engine.IsLobbyHost(Enum.LobbyType.LOBBY_TYPE_PRIVATE) then
		return "member"
	end

	-- The next step waits until this one has moved the lobby
	local now = Engine.milliseconds()
	if lobbyStep ~= nil and lobbyStep.from == current.id and now - lobbyStep.at < LOBBY_STEP_TIMEOUT then
		return "wait"
	end
	lobbyStep = {from = current.id, at = now}

	local controller = Engine.GetPrimaryController()
	if current.id == targets.UI_MODESELECT.id then
		Engine.LobbyVM_CallFunc("GoForward", {controller = controller, navToMenu = target.name})
	else
		Engine.LobbyVM_CallFunc("GoBack", {controller = controller, withParty = LuaEnums.LEAVE_WITH_PARTY.WITH})
	end

	return "wait"
end

-- The leader's quit from a server the party followed it into offers to bring the party along
local endGame = CoD.OverlayUtility.Overlays.EndGamePopup
if endGame ~= nil and not endGame.boiiiParty then
	endGame.boiiiParty = true

	local stockList = endGame.listDatasource
	endGame.listDatasource = function(...)
		if game.partyCanBringParty == nil or not Try(game.partyCanBringParty) then
			return stockList(...)
		end

		local function Quit(controller, menu, withParty)
			if withParty then
				Try(game.partyBringParty)
			end

			if Engine.CanPauseGame() then
				Engine.SetDvar("cl_paused", 0)
			end

			CloseStartMenu(menu, controller)
			CoDShared.QuitGame(controller, false)
		end

		DataSources[QUIT_LIST] = DataSourceHelpers.ListSetup(QUIT_LIST, function(controller)
			return {
				{
					models = {
						displayText = "QUIT WITH PARTY"
					},
					properties = {
						action = function(element, event, controller, param, menu)
							Quit(controller, menu, true)
						end
					}
				},
				{
					models = {
						displayText = "QUIT ALONE"
					},
					properties = {
						action = function(element, event, controller, param, menu)
							Quit(controller, menu, false)
						end
					}
				},
				{
					models = {
						displayText = Engine.Localize("MENU_NO")
					},
					properties = {
						action = function(element, event, controller, param, menu)
							GoBack(menu, controller)
						end,
						selectIndex = true
					}
				}
			}
		end, true, nil)

		return QUIT_LIST
	end
end
