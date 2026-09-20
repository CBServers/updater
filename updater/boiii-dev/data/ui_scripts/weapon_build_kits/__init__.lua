if Engine.GetCurrentMap() ~= "core_frontend" then
  return
end

require("ui.uieditor.actions")

-- stock FocusWeaponBuildKit/SelectWeaponBuildKit index list[#list] on an empty variant cache and throw

local function GetVariantToDisplay(controller, weaponIndex)
  local gunsmith = CoD.CraftUtility.Gunsmith
  local variants = gunsmith.GetSortedWeaponVariantList(weaponIndex)
  local entry = variants[#variants]

  if entry ~= nil then
    return gunsmith.GetVariantByIndex(controller, entry.variantIndex)
  end

  return {
    attachment = gunsmith.GetEmptyTable(gunsmith.MAX_ATTACHMENTS),
    attachmentVariant = gunsmith.GetEmptyTable(gunsmith.MAX_ATTACHMENTS),
    variantName = "",
    camoIndex = gunsmith.CAMO_NONE,
    reticleIndex = gunsmith.RETICLE_NONE,
    paintjobSlot = Enum.CustomizationPaintjobInvalidID.CUSTOMIZATION_INVALID_PAINTJOB_SLOT,
    paintjobIndex = Enum.CustomizationPaintjobInvalidID.CUSTOMIZATION_INVALID_PAINTJOB_INDEX,
    weaponIndex = weaponIndex,
    variantIndex = gunsmith.EMPTY_ITEM_INDEX,
    sortIndex = gunsmith.EMPTY_ITEM_INDEX
  }
end

-- stock IsVariantIndexOccupied indexes an empty cache without checking
local function IsVariantOccupied(variantIndex)
  local slot = CoD.CraftUtility.Gunsmith.CachedVariants[variantIndex + 1]
  return slot ~= nil and slot.weaponIndex ~= CoD.CraftUtility.Gunsmith.EMPTY_ITEM_INDEX
end

local function BuildVariantModel(controller, weaponIndex, variant)
  local variantModel = Engine.CreateModel(Engine.GetModelForController(controller), "WeaponBuildKitVariant")

  DataSources.GunsmithVariantList.createVariantModel(controller, weaponIndex, variant, 1, variantModel)
  CoD.perController[controller].gunsmithVariantModel = variantModel
  CoD.CraftUtility.Gunsmith.DisplayWeaponWithVariant(controller, CoD.perController[controller].gunsmithVariantModel)

  return variantModel
end

function FocusWeaponBuildKit(self, element, controller)
  Gunsmith_GainFocus(self, element, controller)

  local weaponIndex = CoD.GetCustomization(controller, "weapon_index")
  if not weaponIndex then
    return
  end

  local variant = GetVariantToDisplay(controller, weaponIndex)
  local variantModel = BuildVariantModel(controller, weaponIndex, variant)

  self:setModel(variantModel)
  self.WeaponBuildKitsAttachmentsPreview:processEvent({
    name = "update_state",
    controller = controller
  })
end

function SelectWeaponBuildKit(self, element, controller)
  Gunsmith_BrowseVariants(self, element, controller)

  local weaponIndex = CoD.GetCustomization(controller, "weapon_index")
  if not weaponIndex then
    return
  end

  local variant = GetVariantToDisplay(controller, weaponIndex)
  local variantModel = BuildVariantModel(controller, weaponIndex, variant)

  if not IsVariantOccupied(variant.variantIndex) then
    Engine.SetModelValue(
      Engine.CreateModel(Engine.GetModelForController(controller), "Gunsmith.validVariantNameEntered"), false)

    local textEntry = Engine.GetModel(variantModel, "variantTextEntry")
    if textEntry then
      Engine.SetModelValue(textEntry, "")
      Engine.SetModelValue(
        Engine.CreateModel(Engine.GetModelForController(controller), "Gunsmith.validVariantNameEntered"), true)
      -- stock reads textEntry back here unguarded
      Engine.SetModelValue(Engine.GetModel(variantModel, "variantName"), Engine.GetModelValue(textEntry))
    end
  end

  OpenOverlay(self, "WeaponBuildKitsCustomizeVariant", controller)
  Gunsmith_ChooseWeaponList(self, element, controller)
end
