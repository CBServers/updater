
-- Fix LUI_NULL_FUNCTION messages
function Engine.PIXBeginEvent() end
function Engine.PIXEndEvent() end

-- A ranked host quitting starts a host migration, which boiii can't do, so end the round instead
if CoDShared and CoDShared._originalTable then
	local quitGame = CoDShared.QuitGame
	CoDShared._originalTable.QuitGame = function(controller, unbalancedTeams)
		if not Engine.IsRunningUILevel() and CoDShared.IsHost() and CoDShared.IsRankedGame()
			and not Engine.HostMigrationWaitingForPlayers() and Engine.DvarInt(nil, "g_gameEnded") ~= 1 then
			Engine.UpdateStatsForQuit(controller, true)
			Engine.SendMenuResponse(controller, "popup_leavegame", "endround")
			return true
		end

		return quitGame(controller, unbalancedTeams)
	end
end
