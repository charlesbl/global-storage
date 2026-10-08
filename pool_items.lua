-- The global pool stores quantities, not LuaItemStacks. Never flatten qualities,
-- spoilage, ammo, durability, equipment grids, inventories or custom item data.
local M = {}

function M.can_store(item)
    if item.quality and item.quality ~= "normal" then return false end
    local prototype = prototypes.item[item.name]
    if not prototype then return false end
    if prototype.spoil_result or prototype.spoil_to_trigger_result then return false end
    local item_type = prototype.type
    return item_type == "item" or item_type == "module" or item_type == "capsule"
end

function M.get_counts(inventory)
    local counts = {}
    for _, item in pairs(inventory.get_contents()) do
        if M.can_store(item) then
            counts[item.name] = (counts[item.name] or 0) + item.count
        end
    end
    return counts
end

return M
