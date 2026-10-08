local constants = require("constants")
local state = require("state")
local M = {}

--- Quantities for one craft, including repeated item ingredients but excluding fluids.
function M.ingredients(recipe_name)
    if type(recipe_name) ~= "string" then return nil end
    local recipe = prototypes.recipe[recipe_name]
    if not recipe then return nil end
    local ingredients = {}
    for _, ingredient in pairs(recipe.ingredients) do
        if ingredient.type == "item" and prototypes.item[ingredient.name] then
            ingredients[ingredient.name] = (ingredients[ingredient.name] or 0) + ingredient.amount
        end
    end
    return ingredients
end

--- Every distinct item output needs its own filtered slot, including probabilistic outputs.
function M.output_names(recipe_name)
    local recipe = recipe_name and prototypes.recipe[recipe_name]
    local names, result = {}, {}
    for _, product in pairs(recipe and recipe.products or {}) do
        if product.type == "item" and prototypes.item[product.name] then names[product.name] = true end
    end
    for name in pairs(names) do result[#result + 1] = name end
    table.sort(result)
    return result
end

function M.set_multiplier(network, recipe_name, multiplier)
    if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1
       or multiplier == math.huge or multiplier ~= math.floor(multiplier) then return false end
    local ingredients = M.ingredients(recipe_name)
    if not ingredients then return false end
    local requests = {}
    for name, amount in pairs(ingredients) do
        local count = math.ceil(amount * multiplier)
        if count > 2147483647 then return false end
        requests[name] = { min = count, max = count }
    end
    network.craft_recipe = recipe_name
    network.craft_multiplier = multiplier
    local minimum_outputs = #M.output_names(recipe_name)
    network.craft_output_slots = math.max(minimum_outputs, network.craft_output_slots or minimum_outputs)
    network.requests = requests
    return true
end

--- Craft networks are isolated from manual linked inventories, even when names collide.
function M.get_recipe_network(recipe_name)
    if not M.ingredients(recipe_name) then return nil end
    state.migrate_network_types()
    storage.recipe_networks = storage.recipe_networks or {}
    local saved_name = storage.recipe_networks[recipe_name]
    local saved = saved_name and storage.networks[saved_name]
    if saved and saved.entity_name == constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME
       and saved.craft_recipe == recipe_name then return saved_name, saved, false end
    local base = constants.COPY_PASTE_NETWORK_PREFIX .. recipe_name
    local name, suffix = base, 1
    while storage.networks[name] and
          (storage.networks[name].entity_name ~= constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME
           or storage.networks[name].craft_recipe ~= recipe_name) do
        suffix = suffix + 1
        name = base .. " #" .. suffix
    end
    local is_new = storage.networks[name] == nil
    local network = state.get_or_create_network(name, false, constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME)
    if is_new then
        M.set_multiplier(network, recipe_name, 10)
        network.craft_defaults_version = 2
    end
    storage.recipe_networks[recipe_name] = name
    return name, network, is_new
end

function M.ensure(network_name, network)
    if not network or network.entity_name ~= constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME then return false end
    local recipe_name = network.craft_recipe
    if not recipe_name or not prototypes.recipe[recipe_name] then return false end
    -- One-time adjustment for networks still using the old x1 default.
    if network.craft_defaults_version ~= 2 then
        if not network.craft_multiplier or network.craft_multiplier == 1 then
            M.set_multiplier(network, recipe_name, 10)
            network.craft_slot_layout_version = nil
        end
        network.craft_defaults_version = 2
    end
    if network.craft_slot_layout_version == 2 then return true end
    local initialized = M.set_multiplier(network, recipe_name, network.craft_multiplier or 10)
    if initialized then
        if network.link_id then
            for _, force in pairs(game.forces) do
                local inventory = force.get_linked_inventory(constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME, network.link_id)
                M.update_inventory_bar(inventory, network)
            end
        end
        network.craft_slot_layout_version = 2
    end
    return initialized
end

--- Planned slots per ingredient and per output; output slots are shared evenly.
function M.slot_layout(network)
    local inputs, outputs, input_slots = {}, {}, 0
    for name, request in pairs(network.requests) do
        local prototype = prototypes.item[name]
        if prototype then
            local slots = math.ceil(request.min / prototype.stack_size)
            inputs[#inputs + 1] = { name = name, count = request.min, slots = slots }
            input_slots = input_slots + slots
        end
    end
    table.sort(inputs, function(a, b) return a.name < b.name end)
    for _, name in ipairs(M.output_names(network.craft_recipe)) do
        outputs[#outputs + 1] = { name = name }
    end
    local output_slots = math.max(#outputs, network.craft_output_slots or #outputs)
    local missing_output = false
    for index, output in ipairs(outputs) do
        output.slots = math.floor(output_slots / #outputs) + (index <= output_slots % #outputs and 1 or 0)
        output.count = output.slots * prototypes.item[output.name].stack_size
        if output.slots == 0 then missing_output = true end
    end
    return { inputs = inputs, outputs = outputs, input_slots = input_slots,
             output_slots = output_slots, total = input_slots + output_slots, missing_output = missing_output }
end

--- Reserve output space even when inputs exceed capacity. No existing items are removed.
function M.update_inventory_bar(inventory, network)
    if not inventory or not inventory.supports_bar() then return end
    local layout = M.slot_layout(network)
    if inventory.supports_filters() then
        local cursor = 1
        local input_capacity = math.max(0, #inventory - layout.output_slots)
        for _, item in ipairs(layout.inputs) do
            for _ = 1, math.min(item.slots, input_capacity - cursor + 1) do
                inventory.set_filter(cursor, { name = item.name, quality = "normal" })
                cursor = cursor + 1
            end
        end
        for _, item in ipairs(layout.outputs) do
            for _ = 1, math.min(item.slots, #inventory - cursor + 1) do
                inventory.set_filter(cursor, { name = item.name, quality = "normal" })
                cursor = cursor + 1
            end
        end
        for index = cursor, #inventory do inventory.set_filter(index, nil) end
    end
    inventory.set_bar(math.min(#inventory + 1, layout.total + 1))
end

return M
