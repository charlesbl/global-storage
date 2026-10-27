local state = require("state")
local network_module = require("network")
local pool_items = require("pool_items")

local M = {}

--- Process a single player's logistics
---@param player LuaPlayer
local function process_player(player)
    local player_data = state.get_player_data(player.index)
    if not player_data.logistics_enabled then return end

    local character = player.character
    if not character or not character.valid then return end

    local main_inv = player.get_main_inventory()
    if not main_inv then return end

    -- 1. Build requests map from personal logistics
    local requests = {} -- { item_name = { min, max } }
    local logistic_point = character.get_requester_point()
    if logistic_point and logistic_point.enabled then
        for _, section in pairs(logistic_point.sections) do
            if section.active and section.multiplier > 0 then
                for i = 1, section.filters_count do
                    local filter = section.get_slot(i)
                    if filter and filter.value then
                        local value = filter.value
                        local item_name = type(value) == "table" and value.name or value
                        local quality = type(value) == "table" and value.quality or "normal"
                        if type(quality) ~= "string" and quality then quality = quality.name end
                        if type(item_name) == "string" and pool_items.can_store({ name = item_name, quality = quality })
                           and (type(value) ~= "table" or (value.type == nil or value.type == "item"))
                           and (type(value) ~= "table" or value.comparator == nil or value.comparator == "=") then
                            local request = requests[item_name] or { min = 0 }
                            request.min = request.min + math.floor((filter.min or 0) * section.multiplier)
                            requests[item_name] = request
                        end
                    end
                end
            end
        end
    end

    -- 2. SUPPLY: For each request, supply if current < min
    for item_name, req in pairs(requests) do
        if req.min and req.min > 0 then
            local current = main_inv.get_item_count(item_name)
            if current < req.min then
                local needed = req.min - current
                local available = storage.inventory[item_name] or 0
                local to_insert = math.min(needed, available)
                if to_insert > 0 then
                    local inserted = main_inv.insert({ name = item_name, quality = "normal", count = to_insert })
                    network_module.remove_from_inventory(item_name, inserted)
                end
            end
        end
    end

    -- 3. COLLECT TRASH: Empty trash into global pool (bypass limits)
    local trash_inv = player.get_inventory(defines.inventory.character_trash)
    if trash_inv then
        for name, count in pairs(pool_items.get_counts(trash_inv)) do
            local removed = pool_items.remove(trash_inv, name, count)
            if removed > 0 then
                storage.inventory[name] = (storage.inventory[name] or 0) + removed
            end
        end
    end
end

--- Process all players' logistics
function M.process()
    for _, player in pairs(game.players) do
        if player.connected and player.character then
            process_player(player)
        end
    end
end

return M
