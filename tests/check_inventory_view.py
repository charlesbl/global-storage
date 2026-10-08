"""Static GUI regression checks using Lua API doubles; never starts Factorio."""
from pathlib import Path
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().mod_root = root.as_posix()
lua.execute("package.path = mod_root .. '/?.lua;' .. package.path")
parse = lua.eval("function(s, name) local f, e = load(s, name); return f ~= nil, e end")
for path in root.glob("*.lua"):
    ok, error = parse(path.read_text(encoding="utf-8-sig"), str(path))
    assert ok, error

lua.execute(r'''
storage = {
    inventory = {iron = 25, copper = 80, steel = 0},
    limits = {iron = 100, copper = 200, steel = -1},
    player_data = {}, networks = {},
}
prototypes = {item = {
    iron = {localised_name = 'Minerai de fer'},
    copper = {localised_name = 'Équipement cuivre'},
    steel = {localised_name = 'Acier'},
}, recipe = {iron = {}, ['iron-smelting'] = {}}}
defines = {rich_text_setting = {enabled = true}}
local state = require('state')
local view = require('inventory_view')
local gui = require('network_gui')
local C = require('constants')
local G = C.GUI

-- Bound LuaGuiElement methods and dynamic child indices, including destruction.
local function node(spec, parent)
    local e = spec or {}
    e.name = e.name or ''; e.valid = true; e.style = {}; e.children = {}; e.parent = parent
    e.add = function(args)
        local child = node(args, e)
        e.children[#e.children + 1] = child
        if child.name ~= '' then e[child.name] = child end
        return child
    end
    e.clear = function()
        while #e.children > 0 do e.children[1].destroy() end
    end
    e.destroy = function()
        e.clear(); e.valid = false
        if parent then
            for i, child in ipairs(parent.children) do
                if child == e then table.remove(parent.children, i); break end
            end
            if e.name ~= '' then parent[e.name] = nil end
        end
    end
    e.get_index_in_parent = function()
        for i, child in ipairs(parent.children) do if child == e then return i end end
        error('Detached element')
    end
    e.swap_children = function(a, b)
        assert(e.children[a] and e.children[b], 'Invalid child index')
        e.children[a], e.children[b] = e.children[b], e.children[a]
    end
    e.focus = function() e.focused = true end
    return e
end
local pending, next_id = {}, 0
local player = {index = 1, gui = {screen = node(), left = node()}}
player.request_translation = function(text)
    next_id = next_id + 1; pending[next_id] = text; return next_id
end
game = {get_player = function(index) if index == 1 then return player end end}
local pdata = state.get_player_data(1)
local frame = player.gui.screen.add({name = G.NETWORK_FRAME, type = 'frame'})
local tabs = frame.add({name = G.NETWORK_TABS, type = 'tabbed-pane', selected_tab_index = 2})
local content = tabs.add({type = 'frame'})
gui.build_inventory_tab(content, player)
local field = gui.find_element(frame, G.INVENTORY_SEARCH)
local function search(text)
    field.text = text
    gui.on_gui_text_changed({element = field, player_index = 1})
    assert(field.valid and gui.find_element(frame, G.INVENTORY_SEARCH) == field, 'Search lost focus target')
end
search('minerai')
assert(next(pdata.inventory_grid_cache) == nil)
-- Ignore other mods' callbacks, then receive this player's actual translations.
gui.on_string_translated({player_index = 1, id = 9999, translated = true, result = 'Other mod'})
for id, text in pairs(pending) do
    gui.on_string_translated({player_index = 1, id = id, translated = true, result = text})
end
gui.update_live(player)
assert(pdata.inventory_grid_cache.iron and not pdata.inventory_grid_cache.copper)
search('EQUIPEMENT')
assert(pdata.inventory_grid_cache.copper and not pdata.inventory_grid_cache.iron)
search('IRON') -- Internal names still work with translated labels.
assert(pdata.inventory_grid_cache.iron)
assert(not view.matches('iron', 'minerai', state.get_player_data(2)), 'Translation leaked across players')
search('%[') -- Queries are literal, never Lua patterns.
assert(next(pdata.inventory_grid_cache) == nil)
assert(gui.find_element(frame, G.INVENTORY_EMPTY_LABEL).visible)
local clear = gui.find_element(frame, G.INVENTORY_SEARCH_CLEAR)
gui.on_gui_click({element = clear, player_index = 1})
assert(pdata.inventory_search == '' and field.text == '' and field.focused)
local filter = gui.find_element(frame, G.INVENTORY_FILTER_NO_LIMIT_CHECKBOX)
filter.state = true
gui.on_gui_checked_state_changed({element = filter, player_index = 1})
assert(next(pdata.inventory_grid_cache) == nil)
storage.inventory.iron = 30; storage.limits.iron = 0
search('minerai')
assert(pdata.inventory_grid_cache.iron and not pdata.inventory_grid_cache.copper)
filter.state = false
gui.on_gui_checked_state_changed({element = filter, player_index = 1})
storage.limits.iron = 100

local items = {iron = true, copper = true, steel = true}
local function sorted(mode) return table.concat(view.sorted(items, pdata, mode), ',') end
assert(sorted('name') == 'steel,copper,iron')
assert(sorted('name-desc') == 'iron,copper,steel')
assert(sorted('quantity') == 'steel,iron,copper')
assert(sorted('quantity-desc') == 'copper,iron,steel')
assert(sorted('fill') == 'iron,copper,steel')
assert(sorted('fill-desc') == 'copper,iron,steel') -- Unlimited always last.
storage.inventory.iron = 80
assert(sorted('quantity-desc') == 'copper,iron,steel') -- Stable name tie-break.
storage.inventory.iron = 30

pdata.pinned_items = items
gui.restore_pin_hud(player)
local hud = player.gui.left[G.PIN_HUD_FRAME]
local dropdown = gui.find_element(frame, G.PIN_SORT)
dropdown.selected_index = 4
gui.on_gui_selection_state_changed({element = dropdown, player_index = 1})
assert(gui.find_element(hud, G.PIN_SORT) == nil)
assert(hud[G.PIN_HUD_MANUAL_SECTION].children[1].name == G.PIN_HUD_FLOW .. 'copper')
storage.inventory.iron = 90
pdata.hud_needs_refresh = false
gui.update_pin_hud(player)
assert(player.gui.left[G.PIN_HUD_FRAME] == hud, 'Compact HUD was unnecessarily rebuilt')
assert(hud[G.PIN_HUD_MANUAL_SECTION].children[1].name == G.PIN_HUD_FLOW .. 'iron')
assert(state.get_player_data(1).pin_sort == 4)
gui.add_auto_pin_to_hud(player, 'copper', 0.05)
gui.add_auto_pin_to_hud(player, 'iron', 0.01)
gui.sort_pin_hud(player)
assert(hud[G.PIN_HUD_AUTO_SECTION].children[1].name == G.PIN_HUD_AUTO_HEADER)
assert(hud[G.PIN_HUD_AUTO_SECTION].children[2].name == G.AUTO_PIN_HUD_FLOW .. 'iron')

storage.networks['craft:iron #2'] = {entity_name = C.GLOBAL_CRAFT_CHEST_ENTITY_NAME, craft_recipe = 'iron'}
assert(state.network_caption('craft:iron #2') == 'craft: [recipe=iron] #2')
assert(storage.networks['craft:iron #2'].craft_recipe == 'iron')
storage.networks['craft:iron-smelting'] = {entity_name = C.GLOBAL_CRAFT_CHEST_ENTITY_NAME, craft_recipe = 'iron-smelting'}
assert(state.network_caption('craft:iron-smelting') == 'craft: [recipe=iron-smelting]')
assert(state.network_caption('manual') == 'manual')
prototypes.recipe.iron = nil
assert(state.network_caption('craft:iron #2') == 'craft:iron #2')

gui.on_player_locale_changed({player_index = 1})
assert(pdata.item_names.iron == nil and pdata.inventory_view_dirty == false)
assert(pdata.pin_sort == 4 and pdata.inventory_search == 'minerai')

-- New entries are picked up while open; failed translations fall back safely.
prototypes.item.new = {localised_name = 'Unknown translation'}
storage.inventory.new = 0
search('new')
local request_id
for id, name in pairs(pdata.item_name_requests) do if name == 'new' then request_id = id end end
assert(request_id)
gui.on_string_translated({player_index = 1, id = request_id, translated = false, result = ''})
gui.update_live(player)
assert(pdata.item_names.new == 'new' and pdata.inventory_grid_cache.new)
search('')
prototypes.item.other = {localised_name = 'Other'}
storage.inventory.other = 10
gui.update_live(player)
assert(pdata.inventory_grid_cache.other)

-- Removing a zero-stock entry must remove its HUD row too.
pdata.pinned_items.new = true
gui.add_item_to_hud(player, 'new')
local row = player.gui.left[G.PIN_HUD_FRAME][G.PIN_HUD_MANUAL_SECTION][G.PIN_HUD_FLOW .. 'new']
storage.previous_limits = {}
gui.on_gui_click({player_index = 1, element = {valid = true, name = G.INVENTORY_EDIT_REMOVE,
    tags = {item_name = 'new'}}})
assert(not row.valid and pdata.pinned_items.new == nil)
assert(pdata.inventory_grid_cache.new == nil)

-- Saved HUDs from the previous layout lose the dropdown on their next refresh.
local old_hud = player.gui.left[G.PIN_HUD_FRAME]
gui.add_pin_sort_control(old_hud, pdata)
gui.update_pin_hud(player)
local compact_hud = player.gui.left[G.PIN_HUD_FRAME]
assert(not old_hud.valid and compact_hud ~= old_hud)
assert(gui.find_element(compact_hud, G.PIN_SORT) == nil)
assert(pdata.pin_sort == 4 and gui.find_element(frame, G.PIN_SORT).valid)
''')
print("Passed: Lua syntax, translated/literal search, focus and filters, six pin sorts,")
print("live HUD reorder, per-player settings, recipe icon captions and locale changes.")
