-- Shows an inbound CB Friends invite while the player is in game. The launcher owns accepting it;
-- this only says one arrived, because the launcher's own notification cannot draw over the game.
-- Called from C++ when an invite is delivered, never polled.

CBInvites = CBInvites or {}

function CBInvites.show( name )
	if type( name ) ~= "string" or name == "" then
		return
	end

	-- Everything here runs off an external event, so a failure must not escape into the caller.
	local ok, err = pcall( function ()
		local controller = 0
		if Engine.GetFirstActiveController then
			controller = Engine.GetFirstActiveController()
		end

		LUI.FlowManager.RequestAddMenu( nil, "notification_modal", true, controller, false, {
			titleText = Engine.Localize( "Friend Invite" ),
			descText = Engine.Localize( name .. " invited you. Accept it in the CB Launcher." ),
			icon = nil,
			modalType = ModalUtils.NotificationModalType.GeneralNotifications,
			accept_func = function ()
			end,
			cancel_func = function ()
			end,
			choices = {}
		} )
	end )

	if not ok then
		print( "CBInvites.show failed: " .. tostring( err ) )
	end
end
