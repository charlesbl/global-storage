"""Blueprint-over-existing-chest event checks with doubles; never starts Factorio."""
from pathlib import Path
from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().mod_root = Path(__file__).resolve().parents[1].as_posix()
lua.execute("package.path = mod_root .. '/?.lua;' .. package.path")
lua.execute(r'''
local C = require('constants')
local state = require('state')
local settings = require('chest_settings')
prototypes = {item = {iron = {stack_size = 100}, gear = {stack_size = 100}},
    recipe = {gear = {ingredients = {{type = 'item', name = 'iron', amount = 2}},
                     products = {{type = 'item', name = 'gear'}}}}}
defines = {inventory = {chest = 1}, events = setmetatable({}, {
    __index = function(t, key) rawset(t, key, key); return key end,
})}
local handlers = {}
script = {on_event = function(name, handler) handlers[name] = handler end}
local inv = {{}, {}, {}, {}}
inv.supports_filters = function() return false end
inv.supports_bar = function() return false end
game = {forces = {{get_linked_inventory = function() return inv end}},
    players = {{index = 1}, {index = 2}, {index = 3}}}
storage = {}
state.init()
local refreshed = {network = {}, craft = {}, provider = {}}
for kind, module in pairs({network = 'chest_gui', craft = 'craft_gui', provider = 'provider_gui'}) do
    require(module).update = function(player, entity)
        refreshed[kind][player.index] = entity
    end
end
require('events').register()
local paste = assert(handlers.on_blueprint_settings_pasted, 'Blueprint paste handler not registered')
local function watch(field, entity)
    for _, player in ipairs(game.players) do
        state.get_player_data(player.index)[field] = player.index <= 2 and entity
            or {valid = true, unit_number = 999}
    end
end

-- Built providers take the source tags and refresh every viewer of that chest.
local provider = {valid = true, name = C.GLOBAL_PROVIDER_CHEST_ENTITY_NAME, unit_number = 1}
state.register_provider_chest(provider)
state.get_provider_data(1).requests = {gear = 5}
watch('opened_provider_chest', provider)
paste({entity = provider, tags = {[settings.TAG] = {
    version = 1, kind = 'provider', requests = {iron = 37}}}})
assert(state.get_provider_data(1).requests.iron == 37)
assert(state.get_provider_data(1).requests.gear == nil)
assert(refreshed.provider[1] == provider and refreshed.provider[2] == provider)
assert(refreshed.provider[3] == nil)

-- Existing craft chests join the pasted recipe network without a build event.
local craft_chest = {valid = true, name = C.GLOBAL_CRAFT_CHEST_ENTITY_NAME, unit_number = 2,
    get_inventory = function() return inv end}
assert(settings.apply(craft_chest, {version = 1, kind = 'craft'}))
watch('opened_craft_chest', craft_chest)
paste({entity = craft_chest, tags = {[settings.TAG] = {
    version = 1, kind = 'craft', craft_recipe = 'gear', craft_multiplier = 25, craft_output_slots = 2}}})
local network = storage.networks[state.get_chest_tracked_network(2)]
assert(network.craft_recipe == 'gear' and network.craft_multiplier == 25)
assert(network.requests.iron.min == 50 and network.craft_output_slots == 2)
assert(refreshed.craft[1] == craft_chest and refreshed.craft[2] == craft_chest)
assert(refreshed.craft[3] == nil)

local chest = {valid = true, name = C.GLOBAL_CHEST_ENTITY_NAME, unit_number = 3,
    get_inventory = function() return inv end}
watch('opened_chest', chest)
paste({entity = chest, tags = {[settings.TAG] = {
    version = 1, kind = 'network', network = 'manual', manual = true,
    requests = {iron = {min = 10, max = 20}}}}})
assert(storage.networks.manual.requests.iron.max == 20)
assert(refreshed.network[1] == chest and refreshed.network[2] == chest)
assert(refreshed.network[3] == nil)

-- Ghost tags live on the entity; absent, unrelated or mismatched tags are harmless.
local ghost = {valid = true, type = 'entity-ghost', ghost_name = C.GLOBAL_PROVIDER_CHEST_ENTITY_NAME,
    tags = {other_mod = 'preserved', [settings.TAG] = {
        version = 1, kind = 'provider', requests = {iron = 12.9}}}}
paste({entity = ghost})
assert(ghost.tags[settings.TAG].requests.iron == 12 and ghost.tags.other_mod == 'preserved')
paste({entity = provider})
paste({entity = provider, tags = {other_mod = true}})
paste({entity = provider, tags = {[settings.TAG] = {version = 1, kind = 'craft'}}})
paste({entity = {valid = false}})
paste({entity = {valid = true, name = 'steel-chest'}, tags = ghost.tags})
assert(state.get_provider_data(1).requests.iron == 37)
''')
print("Passed: blueprint paste events on built providers, craft/manual chests and ghosts,")
print("open panels for multiple viewers, and missing or incompatible tags.")
