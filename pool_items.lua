-- The global pool stores quantities, not LuaItemStacks. Never flatten qualities,
-- spoilage, ammo, spent durability, equipment grids, inventories or custom item data.
local M = {}

function M.can_store(item)
    local quality = item.quality
    if quality and type(quality) ~= "string" then quality = quality.name end
    if quality and quality ~= "normal" then return false end
    local prototype = prototypes.item[item.name]
    if not prototype then return false end
    if prototype.spoil_result or prototype.spoil_to_trigger_result then return false end
    local item_type = prototype.type
    -- Science packs are tools in Factorio. Fresh tools can be represented by
    -- quantities; partially used stacks must retain their remaining durability.
    if item_type == "tool" then
        return item.durability == nil or item.durability == prototype.get_durability("normal")
    end
    return item_type == "item" or item_type == "module" or item_type == "capsule"
end

function M.can_store_stack(stack)
    if not stack.valid_for_read then return false end
    local prototype = prototypes.item[stack.name]
    if not prototype then return false end
    return M.can_store({ name = stack.name, quality = stack.quality,
        durability = prototype.type == "tool" and stack.durability or nil })
end

function M.get_counts(inventory, include_used_tools)
    local counts = {}
    local has_tools = false
    for _, item in pairs(inventory.get_contents()) do
        if M.can_store(item) then
            if prototypes.item[item.name].type == "tool" and not include_used_tools then
                has_tools = true
            else
                counts[item.name] = (counts[item.name] or 0) + item.count
            end
        end
    end
    if has_tools then
        -- get_contents() omits durability, so inspect tool stacks individually.
        for index = 1, #inventory do
            local stack = inventory[index]
            if stack.valid_for_read and prototypes.item[stack.name].type == "tool"
               and M.can_store_stack(stack) then
                counts[stack.name] = (counts[stack.name] or 0) + stack.count
            end
        end
    end
    return counts
end

function M.remove(inventory, name, count)
    local prototype = prototypes.item[name]
    if not prototype or prototype.type ~= "tool" then
        return inventory.remove({ name = name, quality = "normal", count = count })
    end
    -- remove() cannot select durability and could otherwise consume a used pack.
    local removed = 0
    for index = 1, #inventory do
        local stack = inventory[index]
        if stack.valid_for_read and stack.name == name and M.can_store_stack(stack) then
            local take = math.min(count - removed, stack.count)
            stack.count = stack.count - take
            removed = removed + take
            if removed >= count then break end
        end
    end
    return removed
end

function M.can_store_all(inventory)
    local counts = M.get_counts(inventory)
    for _, item in pairs(inventory.get_contents()) do
        if not M.can_store(item) or counts[item.name] ~= item.count then return false end
    end
    return true
end

return M
