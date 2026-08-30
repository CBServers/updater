if Engine.GetCurrentMap() ~= "core_frontend" then
  return
end

-- Stock GetAttachmentImageFromIndex (ui/uieditor/modifyfunctions.lua) does:
--
--   local cosmetic = Engine.GetAttachmentCosmeticVariant( ..., index )
--   image = cosmetic.image
--
-- with no check. Engine.GetAttachmentCosmeticVariant returns nil for an attachment that has a
-- non-zero attachmentVariant but no cosmetic variant entry, which is the normal state for ported
-- or custom weapons. Indexing that nil throws inside the weapon list's row builder, so the error
-- takes down the whole row and every remaining row on the page - a mod that replaces the weapon
-- set loses entire categories in Create-A-Class rather than one icon.
--
-- Reimplemented with the guard, falling back to the plain attachment image so the slot still
-- draws. Behaviour is unchanged for weapons that do have a cosmetic entry.
function GetAttachmentImageFromIndex(controller, slot, attachmentIndex)
  local index = tonumber(attachmentIndex)
  local slotIndex = tonumber(slot)
  local image = ""

  if index == nil or slotIndex == nil then
    return image
  end

  if index <= CoD.CraftUtility.Gunsmith.EMPTY_ITEM_INDEX then
    return image
  end

  local weaponIndex = CoD.GetCustomization(controller, "weapon_index")
  local perController = CoD.perController[controller]
  local variantModel = perController and perController.gunsmithVariantModel

  local plainImage = function()
    return Engine.GetAttachmentUniqueImageByAttachmentIndex(CoD.CraftUtility.GetCraftMode(), weaponIndex, index)
  end

  if variantModel == nil then
    return plainImage()
  end

  local variantSlot = Engine.GetModel(variantModel, "attachmentVariant" .. slotIndex)
  local attachmentVariant = variantSlot and Engine.GetModelValue(variantSlot)

  if attachmentVariant == nil or attachmentVariant == 0 then
    return plainImage()
  end

  local cosmetic = Engine.GetAttachmentCosmeticVariant(
    CoD.CraftUtility.Gunsmith.GetWeaponPlusAttachmentsForVariant(controller, variantModel), index)

  if cosmetic ~= nil and cosmetic.image ~= nil then
    return cosmetic.image
  end

  -- No cosmetic entry for this attachment: the base icon is still correct.
  return plainImage()
end
