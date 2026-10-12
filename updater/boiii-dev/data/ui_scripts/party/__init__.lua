local modeInfo = LobbyData:UITargetFromId(Engine.GetLobbyUIScreen())
local maxClients = modeInfo.maxClients

-- Stock privacy enforcement stays off; boiii maps LOBBY PRIVACY to its own open state (native_party.cpp)
Engine.SetDvar("partyprivacyenabled", 0)
Engine.SetDvar("tu4_partyprivacyuseglobal", 0)
Engine.SetDvar("tu4_partyprivacyluacheck", 0)

-- PLAYER LIMIT shows a profile var, but lobby navigation resets the live limit to party_maxplayers; show the live one
local function syncPartyLimit(controller)
	if not Engine.IsLobbyHost(Enum.LobbyType.LOBBY_TYPE_PRIVATE) then
		return
	end

	-- Capped at the dropdown's own range, or its refresh would pick (and save) 1
	local target = LobbyData:UITargetFromId(Engine.GetLobbyUIScreen())
	local limit = math.min(Engine.GetLobbyMaxClients(Enum.LobbyType.LOBBY_TYPE_PRIVATE), target.maxClients)
	if limit >= 1 then
		Engine.SetProfileVar(controller, "party_maxplayers", limit)
	end
end

-- The PC list leaves out INVITE ONLY; boiii supports it (no Join button, friends Ask to Join, invites work)
-- Frontend only: the widget doesn't exist in a match, and loading into a dedicated server isn't "in game" yet
if not Engine.IsInGame() and pcall(require, "ui.uieditor.widgets.Social.Social_Party_PC") then
	DataSources.SocialPartyPrivacyPresets = DataSourceHelpers.ListSetup("PC.SocialPartyPrivacyPresets", function()
		local presets = {}
		for _, entry in ipairs({
			{Enum.PartyPrivacy.PARTY_PRIVACY_OPEN, "MENU_PARTY_PRIVACY_OPEN"},
			{Enum.PartyPrivacy.PARTY_PRIVACY_FRIENDS_ONLY, "MENU_PARTY_PRIVACY_FRIENDS_ONLY"},
			{Enum.PartyPrivacy.PARTY_PRIVACY_INVITE_ONLY, "MENU_PARTY_PRIVACY_INVITE_ONLY"},
			{Enum.PartyPrivacy.PARTY_PRIVACY_CLOSED, "MENU_PARTY_PRIVACY_CLOSED"},
		}) do
			table.insert(presets, {models = {value = entry[1], valueDisplay = entry[2]}})
		end
		return presets
	end, true)
end

-- The PARTY tab greys out while partyprivacyenabled is 0, so lift it only while the tab list builds
if DataSources.SocialTabs and not DataSources.SocialTabs.cbPartyTab then
	local prepare = DataSources.SocialTabs.prepare
	DataSources.SocialTabs.cbPartyTab = true
	DataSources.SocialTabs.prepare = function(controller, ...)
		pcall(syncPartyLimit, controller)
		Engine.SetDvar("partyprivacyenabled", 1)
		local ok, err = pcall(prepare, controller, ...)
		Engine.SetDvar("partyprivacyenabled", 0)
		if not ok then
			error(err)
		end
	end
end

-- Fix for invisible bots in custom games
if maxClients >= 1 then
	Engine.SetDvar("party_maxplayers", maxClients)
end

if not Engine.IsInGame() then
	return
end

-- Removed check for public matches to allow team change in ranked matches
CoD.IsTeamChangeAllowed = function()
	if Engine.GetGametypeSetting("allowInGameTeamChange") == 1 then
		return true
	else
		return false
	end
end

-- Set com_maxclients InGame so players can join via direct connect (default from lobbydata)
Engine.SetDvar("com_maxclients", maxClients)

require("datasources_start_menu_game_options")
require("zombie_toast")
