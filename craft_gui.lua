local constants = require("constants")
local state = require("state")
local network_module = require("network")
local craft_requests = require("craft_requests")
local M = {}
local GUI = constants.GUI

-- Factorio can retain old locale tables until restart during unpublished development.
local function tr(key, fallback, ...)
    return { "?", { "gui." .. key, ... }, fallback }
end

function M.create_relative_panel(player)
    local old = player.gui.relative[GUI.CRAFT_RELATIVE_PANEL]
    if old then old.destroy() end
    local panel = player.gui.relative.add({
        type = "frame", name = GUI.CRAFT_RELATIVE_PANEL, direction = "vertical",
        caption = tr("global-storage-craft-chest-title", "Global Craft Chest"),
        anchor = { gui = defines.relative_gui_type.linked_container_gui,
            position = defines.relative_gui_position.right, name = constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME }
    })
    panel.style.minimal_width = 380
    local inner = panel.add({ type = "frame", name = GUI.CRAFT_FRAME, direction = "vertical",
        style = "inside_shallow_frame_with_padding" })
    local row = inner.add({ type = "flow", name = "gn_craft_recipe_row", direction = "horizontal" })
    row.style.vertical_align = "center"
    row.add({ type = "label", caption = tr("global-storage-craft-recipe", "Recipe:") })
    row.add({ type = "choose-elem-button", name = GUI.CRAFT_RECIPE_PICKER, elem_type = "recipe",
        tooltip = tr("global-storage-craft-recipe-tooltip", "Select a recipe. All recipes includes hidden and locked recipes. Only items can be stored in this chest.") })
    row.add({ type = "button", name = "gn_craft_all_recipes", caption = tr("global-storage-all-recipes", "All recipes") }).style.minimal_width = 100
    local recipe_label = inner.add({ type = "label", name = GUI.CRAFT_RECIPE_NAME,
        caption = tr("global-storage-no-recipe", "Select a recipe") })
    recipe_label.style.font = "default-bold"
    recipe_label.style.maximal_width = 350
    local network_label = inner.add({ type = "label", name = GUI.CRAFT_NETWORK_LABEL, caption = "", visible = false })
    network_label.style.rich_text_setting = defines.rich_text_setting.enabled
    -- Recipe controls stay hidden until a recipe has been selected.
    local craft_flow = inner.add({ type = "flow", name = GUI.CHEST_CRAFT_FLOW, direction = "horizontal", visible = false })
    craft_flow.style.vertical_align = "center"
    craft_flow.style.horizontal_spacing = 6
    craft_flow.add({ type = "label", caption = { "gui.global-storage-craft-multiplier" } })
    local craft_slider = craft_flow.add({
        type = "slider", name = GUI.CHEST_CRAFT_SLIDER,
        minimum_value = 10, maximum_value = 500, value = 10,
        value_step = 10, discrete_values = true,
        tooltip = { "gui.global-storage-craft-multiplier-tooltip" }
    })
    craft_slider.style.width = 130
    local craft_field = craft_flow.add({
        type = "textfield", name = GUI.CHEST_CRAFT_FIELD, text = "10",
        numeric = true, allow_decimal = false, allow_negative = false,
        tooltip = { "gui.global-storage-craft-multiplier-tooltip" }
    })
    craft_field.style.width = 65
    craft_flow.add({
        type = "button", name = GUI.CHEST_CRAFT_APPLY,
        caption = { "gui.global-storage-craft-apply" }
    })

    local output_flow = inner.add({ type = "flow", name = GUI.CHEST_OUTPUT_FLOW, direction = "horizontal", visible = false })
    output_flow.style.vertical_align = "center"
    output_flow.style.horizontal_spacing = 8
    output_flow.add({ type = "label", caption = { "gui.global-storage-output-slots" } })
    local output_slider = output_flow.add({
        type = "slider", name = GUI.CHEST_OUTPUT_SLIDER, minimum_value = 1,
        maximum_value = 256, value = 1, value_step = 1, discrete_values = true
    })
    output_slider.style.width = 150
    output_flow.add({ type = "label", name = GUI.CHEST_OUTPUT_LABEL, caption = "1" })
    local summary = inner.add({
        type = "frame", name = GUI.CHEST_CRAFT_SUMMARY, direction = "vertical", visible = false,
        style = "inside_shallow_frame_with_padding"
    })
    summary.style.horizontally_stretchable = true

end

--- Recipe slot plan: green inputs, blue output capacity, and a compact capacity warning.
function M.update_craft_summary(frame, network, capacity)
    local factor = network.craft_multiplier or 10
    local reserved = network.craft_output_slots or 1
    local tags = frame.tags
    if tags.recipe == network.craft_recipe and tags.factor == factor
       and tags.reserved == reserved and tags.capacity == capacity
       and (tags.input_page or 1) == (tags.rendered_input_page or 1)
       and (tags.output_page or 1) == (tags.rendered_output_page or 1) then return end
    frame.clear()
    local input_page = tags.recipe == network.craft_recipe and (tags.input_page or 1) or 1
    local output_page = tags.recipe == network.craft_recipe and (tags.output_page or 1) or 1
    local content = frame.add({ type = "flow", direction = "vertical" })
    content.style.vertical_spacing = 6
    local layout = craft_requests.slot_layout(network)
    local title = content.add({ type = "label", caption = { "gui.global-storage-slot-total", layout.total, capacity } })
    title.style.font = "default-bold"
    local function section(caption, items, color, page, section_name)
        local pages = math.max(1, math.ceil(#items / 16))
        page = math.max(1, math.min(page, pages))
        local heading = content.add({ type = "flow", direction = "horizontal" })
        heading.style.vertical_align = "center"
        local header = heading.add({ type = "label", caption = caption })
        header.style.font = "default-bold"
        header.style.font_color = color
        if pages > 1 then
            heading.add({ type = "button", name = "gn_craft_slot_prev", caption = "<", style = "mini_button",
                enabled = page > 1, tags = { slot_section = section_name, delta = -1 } })
            heading.add({ type = "label", caption = page .. "/" .. pages }).style.font = "default-small"
            heading.add({ type = "button", name = "gn_craft_slot_next", caption = ">", style = "mini_button",
                enabled = page < pages, tags = { slot_section = section_name, delta = 1 } })
        end
        local grid = content.add({ type = "table", column_count = 4 })
        grid.style.horizontal_spacing = 8
        grid.style.vertical_spacing = 4
        for index = (page - 1) * 16 + 1, math.min(page * 16, #items) do
            local item = items[index]
            local tooltip = { "", prototypes.item[item.name].localised_name, "\n",
                tr("global-storage-slot-quantity", "Quantity: " .. item.count, item.count), "\n",
                { "gui.global-storage-slot-count", item.slots } }
            local cell = grid.add({ type = "flow", direction = "horizontal", tooltip = tooltip })
            cell.style.width = 82
            cell.style.horizontal_spacing = 4
            cell.style.vertical_align = "center"
            local icon = cell.add({ type = "sprite", sprite = "item/" .. item.name, tooltip = tooltip })
            icon.style.size = 28
            local details = cell.add({ type = "flow", direction = "vertical", tooltip = tooltip })
            details.style.vertical_spacing = 0
            local quantity = details.add({ type = "label", caption = tostring(item.count), tooltip = tooltip })
            quantity.style.font = "default-small"
            quantity.style.maximal_width = 50
            local slots = details.add({ type = "label", caption = { "gui.global-storage-slot-count", item.slots },
                tooltip = tooltip })
            slots.style.font = "default-small"
            slots.style.font_color = color
            slots.style.maximal_width = 50
        end
        return page
    end
    input_page = section({ "gui.global-storage-slot-inputs", layout.input_slots }, layout.inputs,
        { 0.4, 0.9, 0.4 }, input_page, "input")
    output_page = section({ "gui.global-storage-slot-outputs", layout.output_slots }, layout.outputs,
        { 0.5, 0.75, 1 }, output_page, "output")
    frame.tags = { recipe = network.craft_recipe, factor = factor, reserved = reserved, capacity = capacity,
        input_page = input_page, output_page = output_page,
        rendered_input_page = input_page, rendered_output_page = output_page }
    if layout.total > capacity then
        local warning = content.add({ type = "label", caption = { "gui.global-storage-slot-overflow", layout.total - capacity } })
        warning.style.font_color = { 1, 0.55, 0.2 }
    end
    if layout.missing_output then
        local warning = content.add({ type = "label", caption = { "gui.global-storage-output-missing-slot" } })
        warning.style.font_color = { 1, 0.55, 0.2 }
    end
end

--- Keep drafts intact on periodic refreshes when the shared multiplier has not changed.
function M.update_craft_controls(inner, name, network, chest)
    local flow = inner[GUI.CHEST_CRAFT_FLOW]
    if not flow then return end
    local ready = network and network.craft_recipe and prototypes.recipe[network.craft_recipe] ~= nil
    local output_flow = inner[GUI.CHEST_OUTPUT_FLOW]
    local summary = inner[GUI.CHEST_CRAFT_SUMMARY]
    flow.visible = ready == true
    if output_flow then output_flow.visible = ready == true end
    if summary then summary.visible = ready == true end
    inner[GUI.CRAFT_NETWORK_LABEL].visible = ready == true
    if not ready then return end
    flow[GUI.CHEST_CRAFT_SLIDER].enabled = ready == true
    flow[GUI.CHEST_CRAFT_FIELD].enabled = ready == true
    flow[GUI.CHEST_CRAFT_APPLY].enabled = ready == true
    local inventory = chest.get_inventory(defines.inventory.chest)
    local capacity = inventory and #inventory or 0
    local minimum_outputs = #craft_requests.output_names(network.craft_recipe)
    local output_slots = math.max(minimum_outputs, network.craft_output_slots or minimum_outputs)
    if output_flow then
        local slider = output_flow[GUI.CHEST_OUTPUT_SLIDER]
        slider.set_slider_minimum_maximum(minimum_outputs, math.max(minimum_outputs + 1, capacity))
        slider.enabled = minimum_outputs > 0 and capacity > minimum_outputs
        slider.slider_value = math.max(minimum_outputs, math.min(capacity, output_slots))
        slider.tooltip = tr("global-storage-output-slots-tooltip",
            "Reserve at least one slot per output item (minimum: " .. minimum_outputs .. "). Additional slots are shared evenly.", minimum_outputs)
        output_flow[GUI.CHEST_OUTPUT_LABEL].caption = tostring(output_slots)
    end
    if summary then M.update_craft_summary(summary, network, capacity) end
    local multiplier = network.craft_multiplier or 10
    local tags = flow.tags
    if tags.network ~= name or tags.multiplier ~= multiplier then
        flow[GUI.CHEST_CRAFT_SLIDER].slider_value = math.max(10, math.min(500, math.floor(multiplier / 10 + 0.5) * 10))
        flow[GUI.CHEST_CRAFT_FIELD].text = tostring(multiplier)
        flow.tags = { network = name, multiplier = multiplier }
    end
end

function M.apply_craft_multiplier(player, value)
    local pdata = state.get_player_data(player.index)
    local chest = pdata.opened_craft_chest
    if not chest or not chest.valid then return end
    local name = network_module.get_chest_network_name(chest)
    local network = name and storage.networks[name]
    if not name or not craft_requests.ensure(name, network) then return end
    if not craft_requests.set_multiplier(network, network.craft_recipe, tonumber(value)) then
        player.print({ "gui.global-storage-craft-invalid-multiplier" })
        return
    end
    network.craft_defaults_version = 2
    M.refresh_craft_network(name, network, true)
end

function M.apply_output_slots(player, slots)
    local chest = state.get_player_data(player.index).opened_craft_chest
    if not chest or not chest.valid then return end
    local name = network_module.get_chest_network_name(chest)
    local network = name and storage.networks[name]
    if not name or not craft_requests.ensure(name, network) then return end
    local inventory = chest.get_inventory(defines.inventory.chest)
    if not inventory then return end
    local minimum_outputs = #craft_requests.output_names(network.craft_recipe)
    network.craft_output_slots = math.max(minimum_outputs, math.min(#inventory, math.floor(slots)))
    M.refresh_craft_network(name, network)
end

function M.refresh_craft_network(name, network, reset_multiplier)
    for _, force in pairs(game.forces) do
        local inventory = force.get_linked_inventory(constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME, network.link_id)
        craft_requests.update_inventory_bar(inventory, network)
    end
    -- All chests on this network share both requests and the multiplier.
    for _, viewer in pairs(game.players) do
        local data = state.get_player_data(viewer.index)
        local opened = data.opened_craft_chest
        if opened and opened.valid and network_module.get_chest_network_name(opened) == name then
            local panel = viewer.gui.relative[GUI.CRAFT_RELATIVE_PANEL]
            local inner = panel and panel[GUI.CRAFT_FRAME]
            local flow = inner and inner[GUI.CHEST_CRAFT_FLOW]
            if flow and reset_multiplier then flow.tags = {} end
            M.update(viewer, opened)
        end
    end
end

function M.update(player, chest)
    state.migrate_network_types()
    local panel = player.gui.relative[GUI.CRAFT_RELATIVE_PANEL]
    if not panel then return end
    local inner = panel[GUI.CRAFT_FRAME]
    if not inner then return end
    local name = network_module.get_chest_network_name(chest)
    local network = name and storage.networks[name]
    if not network then return end
    craft_requests.ensure(name, network)
    local recipe = network.craft_recipe and prototypes.recipe[network.craft_recipe]
    local picker = inner.gn_craft_recipe_row[GUI.CRAFT_RECIPE_PICKER]
    local selected = recipe and recipe.name or nil
    if picker.elem_value ~= selected then picker.elem_value = selected end
    inner[GUI.CRAFT_RECIPE_NAME].caption = recipe and recipe.localised_name or tr("global-storage-no-recipe", "Select a recipe")
    inner[GUI.CRAFT_NETWORK_LABEL].caption = name
    M.update_craft_controls(inner, name, network, chest)
end

function M.update_live(player)
    local chest = state.get_player_data(player.index).opened_craft_chest
    if chest and chest.valid then M.update(player, chest) end
end

function M.select_recipe(player, recipe_name)
    local chest = state.get_player_data(player.index).opened_craft_chest
    if not chest or not chest.valid then return end
    local name, network
    if recipe_name then
        name, network = craft_requests.get_recipe_network(recipe_name)
        if not network then return end
    else
        name, network = state.get_default_network(constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME)
    end
    network_module.set_chest_network(chest, name)
    craft_requests.ensure(name, network)
    if network.craft_recipe then
        craft_requests.update_inventory_bar(chest.get_inventory(defines.inventory.chest), network)
    end
    M.update(player, chest)
end

local recipe_names
function M.fill_recipe_catalog(player)
    local popup = player.gui.screen.gn_craft_recipe_catalog
    if not popup then return end
    local query = string.lower(popup.gn_craft_recipe_search.text)
    local grid = popup.gn_craft_recipe_scroll.gn_craft_recipe_grid
    grid.clear()
    if not recipe_names then
        recipe_names = {}
        for name in pairs(prototypes.recipe) do recipe_names[#recipe_names + 1] = name end
        table.sort(recipe_names)
    end
    local matches = {}
    for _, name in ipairs(recipe_names) do
        if query == "" or name:lower():find(query, 1, true) then matches[#matches + 1] = name end
    end
    local page = math.max(1, math.min(popup.tags.page or 1, math.max(1, math.ceil(#matches / 120))))
    popup.tags = { page = page, total = math.max(1, math.ceil(#matches / 120)) }
    popup.gn_craft_recipe_paging.gn_craft_recipe_page.caption = tostring(page) .. " / " .. popup.tags.total
    for index = (page - 1) * 120 + 1, math.min(page * 120, #matches) do
        local name = matches[index]
        local sprite = "recipe/" .. name
        if not helpers.is_valid_sprite_path(sprite) then sprite = "item/" .. constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME end
        grid.add({ type = "sprite-button", sprite = sprite,
            tooltip = { "", prototypes.recipe[name].localised_name, "\n", name }, name = "gn_craft_recipe_choice_" .. index, tags = { craft_recipe = name } })
    end
end

function M.open_recipe_catalog(player)
    local old = player.gui.screen.gn_craft_recipe_catalog
    if old then old.destroy() end
    local popup = player.gui.screen.add({ type = "frame", name = "gn_craft_recipe_catalog",
        caption = tr("global-storage-all-recipes", "All recipes"), direction = "vertical", tags = { page = 1 } })
    popup.auto_center = true
    popup.add({ type = "textfield", name = "gn_craft_recipe_search", text = "",
        tooltip = tr("global-storage-recipe-search", "Search by internal recipe name (shown in recipe tooltips).") }).style.width = 400
    local scroll = popup.add({ type = "scroll-pane", name = "gn_craft_recipe_scroll" })
    scroll.style.maximal_height = 400
    scroll.add({ type = "table", name = "gn_craft_recipe_grid", column_count = 10 })
    local paging = popup.add({ type = "flow", name = "gn_craft_recipe_paging", direction = "horizontal" })
    paging.add({ type = "button", name = "gn_craft_recipe_prev", caption = "<" })
    paging.add({ type = "label", name = "gn_craft_recipe_page", caption = "" })
    paging.add({ type = "button", name = "gn_craft_recipe_next", caption = ">" })
    paging.add({ type = "button", name = "gn_craft_recipe_close", caption = { "gui.gn-cancel" } })
    M.fill_recipe_catalog(player)
    player.opened = popup
end

function M.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    if element.name == GUI.CHEST_CRAFT_APPLY then
        local panel = player.gui.relative[GUI.CRAFT_RELATIVE_PANEL]
        local inner = panel and panel[GUI.CRAFT_FRAME]
        local flow = inner and inner[GUI.CHEST_CRAFT_FLOW]
        if flow then M.apply_craft_multiplier(player, flow[GUI.CHEST_CRAFT_FIELD].text) end
    elseif element.name == "gn_craft_slot_prev" or element.name == "gn_craft_slot_next" then
        local panel = player.gui.relative[GUI.CRAFT_RELATIVE_PANEL]
        local inner = panel and panel[GUI.CRAFT_FRAME]
        local summary = inner and inner[GUI.CHEST_CRAFT_SUMMARY]
        if summary then
            local tags = summary.tags
            local key = element.tags.slot_section == "input" and "input_page" or "output_page"
            tags[key] = math.max(1, (tags[key] or 1) + element.tags.delta)
            summary.tags = tags
            M.update_live(player)
        end
    elseif element.name == "gn_craft_all_recipes" then
        M.open_recipe_catalog(player)
    elseif element.name:find("^gn_craft_recipe_choice_") and element.tags.craft_recipe then
        M.select_recipe(player, element.tags.craft_recipe)
        M.close_recipe_catalog(player)
    elseif element.name == "gn_craft_recipe_close" then
        M.close_recipe_catalog(player)
    elseif element.name == "gn_craft_recipe_prev" or element.name == "gn_craft_recipe_next" then
        local popup = player.gui.screen.gn_craft_recipe_catalog
        if popup then
            local tags = popup.tags
            local direction = element.name == "gn_craft_recipe_prev" and -1 or 1
            tags.page = math.max(1, math.min(tags.total, tags.page + direction))
            popup.tags = tags
            M.fill_recipe_catalog(player)
        end
    end
end

function M.close_recipe_catalog(player)
    local popup = player.gui.screen.gn_craft_recipe_catalog
    if popup then popup.destroy() end
    local chest = state.get_player_data(player.index).opened_craft_chest
    if chest and chest.valid then player.opened = chest end
end

function M.on_gui_elem_changed(event)
    local element = event.element
    if not element or not element.valid or element.name ~= GUI.CRAFT_RECIPE_PICKER then return end
    local player = game.get_player(event.player_index)
    if player then M.select_recipe(player, element.elem_value) end
end

function M.on_gui_value_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    if element.name == GUI.CHEST_CRAFT_SLIDER then M.apply_craft_multiplier(player, math.floor(element.slider_value))
    elseif element.name == GUI.CHEST_OUTPUT_SLIDER then M.apply_output_slots(player, element.slider_value) end
end

function M.on_gui_text_changed(event)
    local element = event.element
    if not element or not element.valid or element.name ~= "gn_craft_recipe_search" then return end
    local player = game.get_player(event.player_index)
    if player then
        local popup = player.gui.screen.gn_craft_recipe_catalog
        if popup then popup.tags = { page = 1 }; M.fill_recipe_catalog(player) end
    end
end

function M.on_gui_confirmed(event)
    local element = event.element
    if not element or not element.valid or element.name ~= GUI.CHEST_CRAFT_FIELD then return end
    local player = game.get_player(event.player_index)
    if player then M.apply_craft_multiplier(player, element.text) end
end

return M
