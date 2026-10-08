local constants = require("constants")
local state = require("state")
local network_module = require("network")
local craft_requests = require("craft_requests")

local M = {}
M.TAG = "global_storage_settings"

local function entity_name(entity)
    return entity.type == "entity-ghost" and entity.ghost_name or entity.name
end

local function quantity(value)
    if type(value) ~= "number" or value ~= value or value <= 0 then return 0 end
    return math.min(2147483647, math.floor(value))
end

local function copy_requests(requests, provider)
    local result = {}
    if type(requests) ~= "table" then return result end
    for name, request in pairs(requests) do
        if type(name) == "string" and prototypes.item[name] then
            if provider then
                local count = quantity(request)
                if count > 0 then result[name] = count end
            elseif type(request) == "table" then
                local minimum = quantity(request.min)
                local maximum = math.max(minimum, quantity(request.max))
                if maximum > 0 then result[name] = { min = minimum, max = maximum } end
            end
        end
    end
    return result
end

--- Take a detached, serializable snapshot. Ghosts already carry blueprint tags.
function M.capture(entity)
    if not entity or not entity.valid then return nil end
    state.migrate_network_types()
    if entity.type == "entity-ghost" then
        local tags = entity.tags
        return tags and tags[M.TAG]
    end
    if entity.name == constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME then
        local data = state.get_provider_data(entity.unit_number)
        return { version = 1, kind = "provider", requests = copy_requests(data and data.requests, true) }
    elseif entity.name == constants.GLOBAL_CHEST_ENTITY_NAME then
        local name = network_module.get_chest_network_name(entity)
        local network = name and storage.networks[name]
        if not network then return nil end
        local inventory = entity.get_inventory(defines.inventory.chest)
        return {
            version = 1, kind = "network", network = name,
            requests = copy_requests(network.requests, false), manual = network.manual or false,
            bar = inventory and inventory.supports_bar() and inventory.get_bar() or nil
        }
    elseif entity.name == constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME then
        local name = network_module.get_chest_network_name(entity)
        local network = name and storage.networks[name]
        if not network then return nil end
        craft_requests.ensure(name, network)
        return {
            version = 1, kind = "craft", craft_recipe = network.craft_recipe,
            craft_multiplier = network.craft_multiplier or 10,
            craft_output_slots = network.craft_output_slots or 1
        }
    end
end

--- Restore provider requests or resolve a linked network by name, never by saved link_id.
function M.apply(entity, settings)
    if not entity or not entity.valid or type(settings) ~= "table" or settings.version ~= 1 then return false end
    local name = entity_name(entity)
    local provider = name == constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME and settings.kind == "provider"
    local linked = name == constants.GLOBAL_CHEST_ENTITY_NAME and settings.kind == "network"
                   and type(settings.network) == "string" and settings.network ~= ""
    local craft = name == constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME and settings.kind == "craft"
    if not provider and not linked and not craft then return false end
    state.migrate_network_types()
    local saved = {
        version = 1, kind = settings.kind, requests = copy_requests(settings.requests, provider)
    }
    if linked then
        saved.network = settings.network
        saved.manual = settings.manual == true
        saved.bar = type(settings.bar) == "number" and math.max(1, quantity(settings.bar)) or nil
        local existing = storage.networks[saved.network]
        if existing and existing.entity_name ~= constants.GLOBAL_CHEST_ENTITY_NAME then return false end
    elseif craft then
        if settings.craft_recipe ~= nil then
            if type(settings.craft_recipe) ~= "string" or not prototypes.recipe[settings.craft_recipe] then return false end
            saved.craft_recipe = settings.craft_recipe
        end
        saved.craft_multiplier = settings.craft_multiplier == nil and 10 or math.max(1, quantity(settings.craft_multiplier))
        saved.craft_output_slots = math.max(1, quantity(settings.craft_output_slots))
    end
    if entity.type == "entity-ghost" then
        local tags = entity.tags or {}
        tags[M.TAG] = saved
        entity.tags = tags
        return true
    end
    if provider then
        if not state.get_provider_data(entity.unit_number) then state.register_provider_chest(entity) end
        state.get_provider_data(entity.unit_number).requests = saved.requests
    elseif craft then
        local network_name, network, is_new
        if saved.craft_recipe then
            network_name, network, is_new = craft_requests.get_recipe_network(saved.craft_recipe)
        else
            network_name, network = state.get_default_network(constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME)
        end
        if not network then return false end
        if is_new then
            craft_requests.set_multiplier(network, saved.craft_recipe, saved.craft_multiplier)
            network.craft_output_slots = saved.craft_output_slots
        end
        network_module.set_chest_network(entity, network_name)
        craft_requests.ensure(network_name, network)
        if network.craft_recipe then
            craft_requests.update_inventory_bar(entity.get_inventory(defines.inventory.chest), network)
        end
    else
        local is_new = storage.networks[saved.network] == nil
        network_module.set_chest_network(entity, saved.network, saved.manual)
        if is_new then
            storage.networks[saved.network].requests = saved.requests
            local inventory = entity.get_inventory(defines.inventory.chest)
            if saved.bar and inventory and inventory.supports_bar() then
                inventory.set_bar(math.min(#inventory + 1, saved.bar))
            end
        end
        -- Existing named networks keep their live shared settings.
    end
    return true
end

--- Vanilla Shift+right-click / Shift+left-click settings copy and paste.
function M.paste(source, destination)
    if not source or not source.valid or not destination or not destination.valid then return false end
    local target_name = entity_name(destination)
    if target_name ~= constants.GLOBAL_CHEST_ENTITY_NAME and target_name ~= constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME and target_name ~= constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME then
        return false
    end
    if entity_name(source) == target_name then
        return M.apply(destination, M.capture(source))
    end
    if source.type ~= "assembling-machine" and source.type ~= "furnace" then return false end
    if target_name == constants.GLOBAL_CHEST_ENTITY_NAME then return false end
    local recipe, quality = source.get_recipe()
    if not recipe or (quality and quality.name ~= "normal") then return false end
    local provider = target_name == constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME
    if not provider then
        return M.apply(destination, { version = 1, kind = "craft", craft_recipe = recipe.name,
            craft_multiplier = 10, craft_output_slots = 1 })
    end
    local requests = {}
    for _, ingredient in pairs(recipe.ingredients) do
        if ingredient.type == "item" and prototypes.item[ingredient.name] then
            requests[ingredient.name] = prototypes.item[ingredient.name].stack_size
        end
    end
    return M.apply(destination, { version = 1, kind = "provider", requests = requests })
end

--- The setup event also covers Ctrl+C, Ctrl+X and blueprint library records.
function M.on_player_setup_blueprint(event)
    local blueprint = event.record
    if not blueprint then
        local stack = event.stack
        if not stack or not stack.valid or not stack.valid_for_read or not stack.is_blueprint then return end
        blueprint = stack
    end
    if not blueprint.valid then return end
    local entities = blueprint.get_blueprint_entities()
    if not entities then return end
    local mapping = event.mapping.get()
    for _, blueprint_entity in pairs(entities) do
        local source = mapping[blueprint_entity.entity_number]
        if source and source.valid and entity_name(source) == blueprint_entity.name then
            local settings = M.capture(source)
            if settings then
                -- Change only our tag, retaining other mods' tags and native settings.
                blueprint.set_blueprint_entity_tag(blueprint_entity.entity_number, M.TAG, settings)
            end
        end
    end
end

return M
