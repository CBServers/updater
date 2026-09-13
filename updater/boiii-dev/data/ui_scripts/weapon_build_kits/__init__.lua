if Engine.GetCurrentMap() ~= "core_frontend" then
  return
end

require("ui.uieditor.actions")

-- FocusWeaponBuildKit and SelectWeaponBuildKit (ui/uieditor/actions.lua) both open with:
--
--   local list = CoD.CraftUtility.Gunsmith.GetSortedWeaponVariantList( weaponIndex )
--   local variant = CoD.CraftUtility.Gunsmith.GetVariantByIndex( controller, list[#list].variantIndex )
--
-- GetSortedWeaponVariantList walks CoD.CraftUtility.Gunsmith.CachedVariants and keeps only the
-- entries whose weaponIndex matches this weapon, plus the first free slot; it returns an empty
-- table when the cache holds neither, and ParseDDL leaves the cache empty outright when there is
-- no gunsmith DDL root to read. list[#list] is then list[0], and indexing that nil throws - in the
-- weapon list's focus handler for the first, in the button handler for the second, so a whole
-- Create-A-Class category comes up empty instead of one weapon misbehaving.
--
-- Both are reimplemented below against a shared helper that falls back to the same empty variant
-- GetVariantByIndex itself builds when the DDL is missing, rather than borrowing whatever sits in
-- another weapon's slot. Weapons that do have a variant entry take the stock path unchanged.

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

-- IsVariantIndexOccupied indexes CachedVariants[index + 1] without checking it, which is the same
-- nil once the cache is empty. A slot that is not in the cache is not occupied.
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
      -- Stock reads textEntry back out here without leaving this branch, so a missing model took
      -- the same nil into Engine.GetModelValue. Kept inside the check.
      Engine.SetModelValue(Engine.GetModel(variantModel, "variantName"), Engine.GetModelValue(textEntry))
    end
  end

  OpenOverlay(self, "WeaponBuildKitsCustomizeVariant", controller)
  Gunsmith_ChooseWeaponList(self, element, controller)
end
