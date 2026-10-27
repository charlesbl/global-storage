"""Craft migration and blueprint checks with Lua API doubles; never starts Factorio."""
from pathlib import Path
from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().mod_root = Path(__file__).resolve().parents[1].as_posix()
lua.execute("package.path = mod_root .. '/?.lua;' .. package.path")
lua.execute(r'''
local C = require('constants')
local state = require('state')
local craft = require('craft_requests')
local settings = require('chest_settings')
prototypes = {item = {
    iron = {stack_size = 100}, gear = {stack_size = 100}, copper = {stack_size = 50},
}, recipe = {
    solid = {ingredients = {{type = 'item', name = 'iron', amount = 2}},
             products = {{type = 'item', name = 'gear'}}},
    fluid = {ingredients = {{type = 'item', name = 'iron', amount = 1}},
             products = {{type = 'fluid', name = 'water'}}},
}}
defines = {inventory = {chest = 1}}
local filters, bar = {}, nil
local inv = {{}, {}, {}, {}, {}, {}}
inv.supports_bar = function() return true end
inv.supports_filters = function() return true end
inv.set_filter = function(index, value)
    assert(index >= 1 and index <= #inv)
    filters[index] = value
end
inv.set_bar = function(value) assert(value <= #inv + 1); bar = value end
game = {forces = {{get_linked_inventory = function() return inv end}}}
storage = {}
state.init()
local name, net = craft.get_recipe_network('solid')
assert(craft.set_multiplier(net, 'solid', 20))
net.craft_output_slots = 2
assert(craft.ensure(name, net))
assert(net.requests.iron.min == 40 and filters[1].name == 'iron')

-- A mod update changes ingredients, products, stack sizes and chest capacity.
prototypes.recipe.solid.ingredients = {{type = 'item', name = 'copper', amount = 3}}
prototypes.recipe.solid.products = {{type = 'item', name = 'iron'}, {type = 'item', name = 'gear'}}
prototypes.item.copper.stack_size = 25
inv[6] = nil
state.init() -- Same path used by on_configuration_changed.
assert(net.craft_slot_layout_version == nil)
assert(craft.ensure(name, net))
assert(net.requests.iron == nil and net.requests.copper.min == 60)
assert(net.craft_multiplier == 20 and net.craft_output_slots == 2)
assert(filters[1].name == 'copper' and filters[3].name == 'copper')
assert(filters[4].name == 'gear' and filters[5].name == 'iron' and bar == 6)

-- Fluid-only output recipes retain zero reserved slots through blueprint tags.
local ghost = {valid = true, type = 'entity-ghost', ghost_name = C.GLOBAL_CRAFT_CHEST_ENTITY_NAME}
assert(settings.apply(ghost, {version = 1, kind = 'craft', craft_recipe = 'fluid',
    craft_multiplier = 1, craft_output_slots = 0}))
assert(ghost.tags[settings.TAG].craft_output_slots == 0)
local chest = {valid = true, name = C.GLOBAL_CRAFT_CHEST_ENTITY_NAME, unit_number = 1,
    get_inventory = function() return inv end}
assert(settings.apply(chest, settings.capture(ghost)))
local fluid = storage.networks[storage.recipe_networks.fluid]
assert(fluid.craft_multiplier == 1 and fluid.craft_output_slots == 0 and bar == 2)
assert(settings.capture(chest).craft_output_slots == 0)
fluid.craft_output_slots = 8 -- Repair reservations imported from older blueprints.
assert(craft.slot_layout(fluid).output_slots == 0)
assert(craft.set_multiplier(fluid, 'fluid', 1) and fluid.craft_output_slots == 0)

-- Solid outputs still enforce one reserved slot per distinct output on import.
local solid_ghost = {valid = true, type = 'entity-ghost', ghost_name = C.GLOBAL_CRAFT_CHEST_ENTITY_NAME}
assert(settings.apply(solid_ghost, {version = 1, kind = 'craft', craft_recipe = 'solid',
    craft_multiplier = 1, craft_output_slots = 0}))
storage.networks[name] = nil
assert(settings.apply(chest, settings.capture(solid_ghost)))
assert(storage.networks[storage.recipe_networks.solid].craft_output_slots == 2)
''')
print("Passed: craft configuration rebuild, preserved settings, resized inventory filters,")
print("zero-output blueprint round trips and minimum solid output reservations.")
