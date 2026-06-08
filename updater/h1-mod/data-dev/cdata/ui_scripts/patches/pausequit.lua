if (Engine.InFrontend()) then
    return
end

if game:issingleplayer() and Engine.GetDvarString("mapname") == "coup" then
    LUI.onmenuopen("sp_pause_menu", function(element)
        local menu = element:getFirstChild()
        menu:AddButton("@MENU_SP_SKIP_MISSION", function()
            Engine.Exec("map blackout")
        end)
    end)
end

if game:issingleplayer() then
    LUI.onmenuopen("sp_pause_menu", function(element)
        local menu = element:getFirstChild()
        menu:AddButton("@MENU_QUIT_TO_DESKTOP", function()
            LUI.FlowManager.RequestAddMenu(nil, "quit_popmenu")
        end)
    end)
end

if not game:issingleplayer() then
    local function friends_button_text()
        return Engine.GetDvarBool("nat_open") and "Close to Friends" or "Open to Friends"
    end

    -- Closes the pause menu so the button label reflects the new state on reopen.
    local function nat_friends_confirmed(element)
        element:dispatchEventToRoot({ name = "toggle_pause_off" })
        LUI.FlowManager.RequestCloseAllMenus(element)
    end

    -- Reads nat_open (already flipped by the synchronous ExecNow below) to describe the result.
    pcall(function()
        LUI.MenuBuilder.registerDef("popup_nat_friends", function()
            local is_open = Engine.GetDvarBool("nat_open")
            return {
                type = "generic_confirmation_popup",
                id = "popup_nat_friends_id",
                properties = {
                    popup_title = is_open and "OPENED TO FRIENDS" or "CLOSED TO FRIENDS",
                    message_text = is_open and "Friends can now join this match."
                        or "Friends can no longer join this match.",
                    confirmation_action = nat_friends_confirmed
                }
            }
        end)
    end)

    local function on_toggle_friends(element, menuItem)
        -- ExecNow so nat_open updates synchronously before the popup reads it.
        Engine.ExecNow("nat_host")

        local ok = pcall(function()
            local controller = (menuItem and menuItem.controller) or Engine.GetFirstActiveController()
            LUI.FlowManager.RequestPopupMenu(element, "popup_nat_friends", true, controller)
        end)

        -- If the popup couldn't show, still close the menu so the label refreshes.
        if (not ok) then
            nat_friends_confirmed(element)
        end
    end

    local quitToDesktop = function()
        LUI.FlowManager.RequestAddMenu(nil, "quit_popmenu")
    end
    local addPauseButtons = function(element)
        local menu = element
        -- Listen-server host (sv_running): show the friends toggle in place of quit-to-desktop.
        if (Engine.GetDvarBool("sv_running")) then
            pcall(function()
                local button = menu:AddButton(friends_button_text(), on_toggle_friends)
                if (button and button.rename) then
                    button:rename("mp_pause_menu_open_to_friends")
                end
            end)
        else
            menu:AddButton("@MENU_QUIT_TO_DESKTOP", quitToDesktop)
        end
    end
    LUI.onmenuopen("mp_pause_menu", addPauseButtons)
end
