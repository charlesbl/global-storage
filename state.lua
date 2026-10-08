local constants = require("constants")
local pool_items = require("pool_items")

local M = {}

-- Display recipe icons without changing persistent network IDs or blueprint tags.
function M.network_caption(name)
    local network = storage.networks and storage.networks[name]
    local recipe = network and network.entity_name == constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME
        and network.craft_recipe
    if recipe and prototypes.recipe[recipe] then
        local suffix = name:match("( #%d+)$") or ""
        return "craft: [recipe=" .. recipe .. "]" .. suffix
    end
    return name
end

--- Alphabetical order for both network GUIs, ignoring ASCII letter case.
function M.get_sorted_network_names(manual_only)
    local names = {}
    for name, network in pairs(storage.networks or {}) do
        if not manual_only or (network.manual and (network.entity_name or constants.GLOBAL_CHEST_ENTITY_NAME) == constants.GLOBAL_CHEST_ENTITY_NAME) then names[#names + 1] = name end
    end
    local function sort_key(name)
        local text = name:gsub("%[item=[^%]]+%]", ""):gsub("%[fluid=[^%]]+%]", "")
                         :gsub("%[img=[^%]]+%]", "")
        text = text:match("^%s*(.-)%s*$")
        return string.lower(text ~= "" and text or name)
    end
    table.sort(names, function(a, b)
        local lower_a, lower_b = sort_key(a), sort_key(b)
        if lower_a == lower_b then return a < b end
        return lower_a < lower_b
    end)
    return names
end

--- Allocate a new unique link_id using a sequential counter
---@return number link_id
function M.allocate_link_id()
    local id = storage.next_link_id or 1
    storage.next_link_id = id + 1
    return id
end

--- Preserve old chests/inventories as manual networks when introducing the craft prototype.
function M.migrate_network_types()
    if storage.chest_type_schema == 1 then return end
    storage.recipe_networks = storage.recipe_networks or {}
    for _, network in pairs(storage.networks or {}) do
        network.entity_name = network.entity_name or constants.GLOBAL_CHEST_ENTITY_NAME
        if network.entity_name == constants.GLOBAL_CHEST_ENTITY_NAME and network.craft_recipe then
            network.legacy_recipe = network.craft_recipe
            network.manual = true
            network.craft_recipe, network.craft_multiplier, network.craft_output_slots = nil, nil, nil
            network.craft_slot_layout_version = nil
            for _, force in pairs(game.forces) do
                local inventory = force.get_linked_inventory(network.entity_name or constants.GLOBAL_CHEST_ENTITY_NAME, network.link_id)
                if inventory then
                    if inventory.supports_filters() then
                        for index = 1, #inventory do inventory.set_filter(index, nil) end
                    end
                    if inventory.supports_bar() then inventory.set_bar(#inventory + 1) end
                end
            end
        end
    end
    storage.chest_type_schema = 1
end

--- Initialize storage structure for new game
function M.init()
    storage.networks = storage.networks or {}
    M.migrate_network_types()
    storage.inventory = storage.inventory or {}
    storage.limits = storage.limits or {}
    storage.previous_limits = storage.previous_limits or {}  -- Remembers last numeric limit when switching to unlimited
    storage.link_id_to_network = storage.link_id_to_network or {}
    storage.player_data = storage.player_data or {}
    storage.provider_chests = storage.provider_chests or {}  -- Provider chests with per-chest requests
    storage.chest_networks = storage.chest_networks or {}  -- unit_number → network_name (for reliable tracking)

    -- Initialize sequential link_id counter
    storage.next_link_id = storage.next_link_id or 1

    -- Rebuild reverse mapping and ensure counter stays ahead of all allocated IDs
    for name, network in pairs(storage.networks) do
        if network.link_id then
            storage.link_id_to_network[network.link_id] = name
            if network.link_id >= storage.next_link_id then
                storage.next_link_id = network.link_id + 1
            end
        end
    end

    -- Reset round-robin state for rebuild
    storage.network_list = nil
    storage.network_index = 1
end

--- Recalculate chest_count for all networks by scanning all surfaces
--- Also rebuilds chest_networks tracking table
--- Called on configuration changed to fix any desync
function M.recalculate_chest_counts()
    -- Reset all counts to 0
    for _, network in pairs(storage.networks) do
        network.chest_count = 0
    end

    -- Reset chest tracking
    storage.chest_networks = {}

    -- Scan all surfaces for chests
    for _, surface in pairs(game.surfaces) do
        local chests = surface.find_entities_filtered({
            name = { constants.GLOBAL_CHEST_ENTITY_NAME, constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME }
        })

        for _, chest in pairs(chests) do
            if chest.valid then
                local link_id = chest.link_id
                if link_id and link_id ~= 0 then
                    local network_name = storage.link_id_to_network[link_id]
                    if network_name and storage.networks[network_name] then
                        storage.networks[network_name].chest_count =
                            (storage.networks[network_name].chest_count or 0) + 1
                        -- Also rebuild chest tracking
                        storage.chest_networks[chest.unit_number] = network_name
                    end
                end
            end
        end
    end
end

--- Get or create network by name
---@param name string Network name
---@param manual boolean|nil If true, marks network as manually created (shown in list)
---@return table network Network data
function M.get_or_create_network(name, manual, entity_name)
    M.migrate_network_types()
    entity_name = entity_name or constants.GLOBAL_CHEST_ENTITY_NAME
    if not name or name == "" then
        return nil
    end

    if not storage.networks[name] then
        local link_id = M.allocate_link_id()
        storage.networks[name] = {
            chest_count = 0,
            requests = {},
            manual = manual or false,
            link_id = link_id,
            entity_name = entity_name
        }
        -- Store reverse mapping
        storage.link_id_to_network[link_id] = name
        -- Invalidate network list for round-robin rebuild
        storage.network_list = nil
    elseif storage.networks[name].entity_name ~= entity_name then
        return nil
    elseif manual then
        -- If manually accessed, mark as manual
        storage.networks[name].manual = true
    end

    return storage.networks[name]
end

--- Pick a default of the correct chest type without colliding with user network IDs.
function M.get_default_network(entity_name)
    M.migrate_network_types()
    local base = entity_name == constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME
        and constants.DEFAULT_CRAFT_NETWORK_NAME or constants.DEFAULT_NETWORK_NAME
    local name, suffix = base, 1
    while storage.networks[name] and storage.networks[name].entity_name ~= entity_name do
        suffix = suffix + 1
        name = base .. " #" .. suffix
    end
    return name, M.get_or_create_network(name, false, entity_name)
end

--- Get network name from link_id
---@param link_id number
---@return string|nil network_name
function M.get_network_name(link_id)
    return storage.link_id_to_network[link_id]
end

--- Set tracked network for a chest (by unit_number)
---@param unit_number number
---@param network_name string
function M.set_chest_tracked_network(unit_number, network_name)
    storage.chest_networks = storage.chest_networks or {}
    storage.chest_networks[unit_number] = network_name
end

--- Get tracked network for a chest (by unit_number)
---@param unit_number number
---@return string|nil network_name
function M.get_chest_tracked_network(unit_number)
    if not storage.chest_networks then return nil end
    return storage.chest_networks[unit_number]
end

--- Remove tracking for a chest (by unit_number)
---@param unit_number number
function M.remove_chest_tracking(unit_number)
    if not storage.chest_networks then return end
    storage.chest_networks[unit_number] = nil
end

--- Reject deletion while the linked inventory contains stacks the pool cannot preserve.
function M.can_delete_network(name)
    local network = storage.networks[name]
    if not network then return true end
    for _, force in pairs(game.forces) do
        local inventory = force.get_linked_inventory(network.entity_name or constants.GLOBAL_CHEST_ENTITY_NAME, network.link_id)
        if inventory then
            for _, item in pairs(inventory.get_contents()) do
                if not pool_items.can_store(item) then return false end
            end
        end
    end
    return true
end

--- Delete a network and transfer its items to global pool across all forces.
---@param name string Network name
function M.delete_network(name)
    local network = storage.networks[name]
    if not network then return true end
    if not M.can_delete_network(name) then return false end

    -- Transfer items from linked inventory to global pool
    local link_id = network.link_id
    for _, inventory_force in pairs(game.forces) do
        local linked_inv = inventory_force.get_linked_inventory(network.entity_name or constants.GLOBAL_CHEST_ENTITY_NAME, link_id)
        if linked_inv then
            for _, item in pairs(linked_inv.get_contents()) do
                local removed = linked_inv.remove({ name = item.name, quality = "normal", count = item.count })
                -- Bypass limits, but only credit items actually removed.
                storage.inventory[item.name] = (storage.inventory[item.name] or 0) + removed
            end
        end
    end

    -- Drain inventories before detaching the last chest, then keep chests registered.
    M.reassign_network_chests(name, nil)

    -- Remove network
    storage.networks[name] = nil
    storage.link_id_to_network[link_id] = nil
    -- Invalidate network list for round-robin rebuild
    storage.network_list = nil
    return true
end

--- Get player data (create if needed)
---@param player_index number
---@return table player_data
function M.get_player_data(player_index)
    if not storage.player_data[player_index] then
        storage.player_data[player_index] = {
            opened_chest = nil,  -- LuaEntity (global-chest)
            opened_craft_chest = nil,  -- LuaEntity (global-craft-chest)
            opened_provider_chest = nil,  -- LuaEntity (global-provider-chest)
            opened_network_gui = false,
            pinned_items = {},  -- { ["iron-plate"] = true }
            pin_hud_elements = {},  -- cache HUD element references
            inventory_grid_cache = {},  -- cache grid element references
            auto_pin_low_stock_enabled = false,  -- auto-pin low stock items
            auto_pinned_items = {},  -- { ["iron-plate"] = true }
            auto_pin_hud_elements = {}  -- cache auto-pin HUD element references
        }
    end
    -- Migration: ensure new fields exist for existing player data
    local pdata = storage.player_data[player_index]
    if not pdata.pinned_items then pdata.pinned_items = {} end
    if not pdata.pin_hud_elements then pdata.pin_hud_elements = {} end
    if not pdata.inventory_grid_cache then pdata.inventory_grid_cache = {} end
    if not pdata.inventory_search then pdata.inventory_search = "" end
    if not pdata.pin_sort then pdata.pin_sort = 1 end
    if pdata.opened_provider_chest == nil then pdata.opened_provider_chest = nil end
    if pdata.auto_pin_low_stock_enabled == nil then pdata.auto_pin_low_stock_enabled = false end
    if not pdata.auto_pinned_items then pdata.auto_pinned_items = {} end
    if not pdata.auto_pin_hud_elements then pdata.auto_pin_hud_elements = {} end
    -- Flag to force HUD refresh on next update (set on migration/load)
    if pdata.hud_needs_refresh == nil then pdata.hud_needs_refresh = true end
    return pdata
end

--- Clean up zero quantities in global inventory
function M.cleanup_inventory()
    for item_name, count in pairs(storage.inventory) do
        if count <= 0 then
            storage.inventory[item_name] = nil
        end
    end
end

--- Reassign all chests from one network to another (or default)
--- Used when deleting a network that still has chests
---@param old_network_name string Network being deleted
---@param new_network_name string|nil Target network (nil = default)
---@return number count Number of chests reassigned
function M.reassign_network_chests(old_network_name, new_network_name)
    local old_network = storage.networks[old_network_name]
    if not old_network then return 0 end
    local old_link_id = old_network.link_id

    local target_network_name = new_network_name or M.get_default_network(old_network.entity_name)
    if target_network_name == old_network_name then
        local base = target_network_name .. "-replacement"
        local suffix = 1
        target_network_name = base
        while storage.networks[target_network_name] and storage.networks[target_network_name].entity_name ~= old_network.entity_name do
            suffix = suffix + 1
            target_network_name = base .. " #" .. suffix
        end
    end
    local target_net = M.get_or_create_network(target_network_name, false, old_network.entity_name)
    if not target_net then return 0 end
    local new_link_id = target_net.link_id

    local count = 0

    -- Scan all surfaces for chests with the old link_id
    for _, surface in pairs(game.surfaces) do
        local chests = surface.find_entities_filtered({
            name = old_network.entity_name or constants.GLOBAL_CHEST_ENTITY_NAME
        })

        for _, chest in pairs(chests) do
            if chest.valid and chest.link_id == old_link_id then
                chest.link_id = new_link_id
                M.set_chest_tracked_network(chest.unit_number, target_network_name)
                count = count + 1
            end
        end
    end

    -- Update target network chest count
    target_net.chest_count = (target_net.chest_count or 0) + count

    return count
end

--- Register a provider chest (called when built)
---@param entity LuaEntity
function M.register_provider_chest(entity)
    if not entity or not entity.valid then return end

    storage.provider_chests[entity.unit_number] = {
        entity = entity,
        requests = {}
    }
end

--- Unregister a provider chest (called when destroyed)
---@param unit_number number
function M.unregister_provider_chest(unit_number)
    storage.provider_chests[unit_number] = nil
end

--- Get provider chest data
---@param unit_number number
---@return table|nil data Provider chest data or nil
function M.get_provider_data(unit_number)
    return storage.provider_chests[unit_number]
end

--- Set a request on a provider chest
---@param unit_number number
---@param item_name string
---@param quantity number
function M.set_provider_request(unit_number, item_name, quantity)
    local data = storage.provider_chests[unit_number]
    if not data then return end

    if quantity and quantity > 0 then
        data.requests[item_name] = quantity
    else
        data.requests[item_name] = nil
    end
end

--- Remove a request from a provider chest
---@param unit_number number
---@param item_name string
function M.remove_provider_request(unit_number, item_name)
    local data = storage.provider_chests[unit_number]
    if not data then return end

    data.requests[item_name] = nil
end

--- Rescan all provider chests on all surfaces
--- Called on configuration changed to fix any desync
function M.rescan_provider_chests()
    -- Ensure storage exists
    storage.provider_chests = storage.provider_chests or {}

    -- Clean up invalid entries
    for unit_number, data in pairs(storage.provider_chests) do
        if not data.entity or not data.entity.valid then
            storage.provider_chests[unit_number] = nil
        end
    end

    -- Scan all surfaces for provider chests
    for _, surface in pairs(game.surfaces) do
        local chests = surface.find_entities_filtered({
            name = constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME
        })

        for _, chest in pairs(chests) do
            if chest.valid and not storage.provider_chests[chest.unit_number] then
                M.register_provider_chest(chest)
            end
        end
    end
end

return M
