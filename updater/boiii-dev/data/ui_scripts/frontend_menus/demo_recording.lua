require("ui.uieditor.widgets.Lobby.Common.FE_List1ButtonLarge_PH")
local utils = require("utils")

-- demo_enabled gates every recording path in Demo_ShouldRecord and nothing else reads it
local isEnabled = function()
  return Dvar.demo_enabled:get()
end

CoD.LobbyButtons.DEMO_RECORDING = {
  stringRef = "DEMO RECORDING",
  action = function(self, element, controller, param, menu)
    Dvar.demo_enabled:set(not isEnabled())
    if element.refreshDemoRecording then
      element.refreshDemoRecording()
    end
  end,
  customId = "btnDemoRecording",
}

-- Recording indicator from the cut PS4 alpha private lobby button
local attachIndicator = function(button)
  local recImage = LUI.UIImage.new()
  recImage:setLeftRight(false, true, 10, 40)
  recImage:setTopBottom(false, false, -15, 15)
  recImage:setImage(RegisterMaterial("codtv_recording"))
  recImage:setAlpha(0)
  button:addElement(recImage)

  local recText = LUI.UIText.new()
  recText:setLeftRight(false, true, 44, 104)
  recText:setTopBottom(false, false, -10, 10)
  recText:setRGB(0.79, 0.79, 0.79)
  recText:setTTF("fonts/escom.ttf")
  recText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
  recText:setAlpha(0)
  button:addElement(recText)

  local isDemoButton = false
  local refresh = function()
    if not isDemoButton then
      recImage:setAlpha(0)
      recText:setAlpha(0)
      return
    end

    recImage:setAlpha(1)
    recText:setAlpha(1)
    if isEnabled() then
      recImage:setRGB(1, 0, 0)
      recText:setText("ON")
    else
      recImage:setRGB(0.3, 0.3, 0.3)
      recText:setText("OFF")
    end
  end

  button.refreshDemoRecording = refresh
  recImage:linkToElementModel(button, "customId", true, function(model)
    isDemoButton = Engine.GetModelValue(model) == CoD.LobbyButtons.DEMO_RECORDING.customId
    refresh()
  end)
end

if CoD.FE_List1ButtonLarge_PH and not CoD.FE_List1ButtonLarge_PH.hasDemoRecordingIndicator then
  local originalNew = CoD.FE_List1ButtonLarge_PH.new
  CoD.FE_List1ButtonLarge_PH.new = function(menu, controller)
    local button = originalNew(menu, controller)
    attachIndicator(button)
    return button
  end
  CoD.FE_List1ButtonLarge_PH.hasDemoRecordingIndicator = true
end

-- Joins the group of the button it follows, taking over that group's trailing spacer
local addButton = function(controller, buttonTable, after)
  -- Nothing records with a mod loaded, same as stock
  if Engine.IsUsingMods() then
    return
  end

  local index = utils.GetButtonIndex(buttonTable, after)
  if index == nil then
    utils.AddSmallButton(controller, buttonTable, CoD.LobbyButtons.DEMO_RECORDING)
    return
  end

  utils.AddSmallButton(controller, buttonTable, CoD.LobbyButtons.DEMO_RECORDING, index + 1)
  if buttonTable[index].isLastButtonInGroup then
    buttonTable[index].isLastButtonInGroup = false
    buttonTable[index + 1].isLastButtonInGroup = true
  end
end

return {
  AddButton = addButton
}
