if (game:issingleplayer() or not Engine.InFrontend()) then
    return
end

-- "MATCH SETTINGS" in the private match lobby; the popup only sets dvars that nat.cpp reads in-match
local Lobby = luiglobals.Lobby
local POPUP_ID = "cb_match_settings_popup"
local LOBBY_MENU = "menu_xboxlive_privatelobby"

local function toggle_auto_open()
    Engine.SetDvarBool("nat_autoOpen", not Engine.GetDvarBool("nat_autoOpen"))
end

local function add_description(list, text)
    local font = CoD.TextSettings.BodyFontSmall or CoD.TextSettings.BodyFont
    local state = CoD.CreateState(0, 0, 0, nil, CoD.AnchorTypes.TopLeftRight)
    state.height = font.Height
    state.font = font.Font
    state.alignment = LUI.Alignment.Left
    state.alpha = 0.8

    local text_element = LUI.UIText.new(state)
    text_element:setText(text)
    list:addElement(text_element)
end

local function match_settings_popup()
    local popup = LUI.MenuBuilder.BuildRegisteredType("generic_selectionList_popup", {
        popup_title = "MATCH SETTINGS",
        popup_width = 500
    })

    local list = popup:getFirstDescendentById("generic_selectionList_content_id")

    add_description(list, "Open the match to friends as soon as it starts.")
    add_description(list, "Stays set until you restart the game.")
    list:addElement(LUI.UIElement.new(CoD.CreateState(0, 0, 0, 10, CoD.AnchorTypes.TopLeft)))

    LUI.MenuBuilder.BuildAddChild(list, {
        type = "UIGenericButton",
        id = "cb_match_settings_open_to_friends",
        properties = {
            variant = GenericButtonSettings.Variants.Select,
            button_text = "OPEN TO FRIENDS",
            button_display_func = function()
                return Engine.Localize(Engine.GetDvarBool("nat_autoOpen") and "@LUA_MENU_ENABLED" or "@LUA_MENU_DISABLED")
            end,
            button_left_func = toggle_auto_open,
            button_right_func = toggle_auto_open,
            buttonActionIsRightAction = true,
            maxLabelWidth = 200
        }
    })

    LUI.MenuBuilder.BuildAddChild(list, {
        type = "UIGenericButton",
        id = "cb_match_settings_back",
        properties = {
            button_text = Engine.Localize("@LUA_MENU_BACK"),
            button_action_func = function(element)
                LUI.FlowManager.RequestLeaveMenu(element)
            end
        }
    })

    return popup
end

LUI.MenuBuilder.registerPopupType(POPUP_ID, match_settings_popup)

-- Host-only like START GAME and GAME SETUP, slotted in right after GAME SETUP
LUI.onmenuopen(LOBBY_MENU, function(menu)
    local ok, err = pcall(function()
        if not menu.list or not Lobby.IsGameHost() then
            return
        end

        local button = menu:AddButton("MATCH SETTINGS", function(element, event)
            if Lobby.IsGameHost() then
                LUI.FlowManager.RequestPopupMenu(element, POPUP_ID, true, event.controller, false, {})
            end
        end, function()
            return not Lobby.IsGameHost()
        end, nil, nil, {
            desc_text = "Choose whether friends can join as soon as the match starts."
        }, true)

        button:setDisabledRefreshRate(500)

        local game_setup = menu.list:getChildById(LOBBY_MENU .. "_button_1")
        if game_setup then
            menu.list:removeElement(button)
            button:addElementAfter(game_setup)
        end
    end)

    if not ok then
        print("match_settings: " .. tostring(err))
    end
end)
