"""Science absorption checks with inventory doubles; never launches Factorio."""
from pathlib import Path
from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().mod_root = Path(__file__).resolve().parents[1].as_posix()
lua.execute("package.path = mod_root .. '/?.lua;' .. package.path")
lua.execute(r'''
prototypes = {item = {
    science = {type = 'tool', get_durability = function(quality) assert(quality == 'normal'); return 1 end},
    iron = {type = 'item'},
    spoiled = {type = 'tool', spoil_result = 'spoilage'},
    triggered = {type = 'tool', spoil_to_trigger_result = {}},
    ammo = {type = 'ammo'},
}}
local function stack(name, count, quality, durability)
    return {valid_for_read = true, name = name, count = count,
        quality = {name = quality or 'normal'}, durability = durability}
end
local function inventory(stacks)
    local inv = stacks
    inv.get_contents = function()
        local contents = {}
        for _, s in ipairs(inv) do
            if s.valid_for_read and s.count > 0 then
                local key = s.name .. ':' .. s.quality.name
                local c = contents[key] or {name = s.name, quality = s.quality.name, count = 0}
                c.count = c.count + s.count; contents[key] = c
            end
        end
        return contents
    end
    inv.remove = function(args)
        -- Any tool removal through this API would risk consuming used packs first.
        assert(args.name ~= 'science', 'Tool removal must select fresh stacks explicitly')
        local removed = 0
        for _, s in ipairs(inv) do
            if s.name == args.name and s.quality.name == args.quality then
                local take = math.min(args.count - removed, s.count)
                s.count = s.count - take; removed = removed + take
            end
        end
        return removed
    end
    inv.insert = function(args)
        assert(args.name == 'science')
        inv[2].count = inv[2].count + args.count
        return args.count
    end
    inv.get_item_count = function() return 0 end
    return inv
end
local inv = inventory({stack('science', 3, 'normal', 0.5), stack('science', 10, 'normal', 1),
    stack('science', 5, 'rare', 1), stack('iron', 12), stack('spoiled', 20, 'normal', 1)})
local pool = require('pool_items')
assert(pool.can_store({name = 'science', quality = 'normal'}))
assert(not pool.can_store({name = 'science', quality = 'rare'}))
assert(not pool.can_store({name = 'science', durability = 0.5}))
assert(not pool.can_store({name = 'spoiled'}))
assert(not pool.can_store({name = 'triggered'}))
assert(not pool.can_store({name = 'ammo'}))
local counts = pool.get_counts(inv)
assert(counts.science == 10 and counts.iron == 12 and counts.spoiled == nil)
assert(not pool.can_store_all(inv))

storage = {inventory = {}, limits = {}, networks = {
    test = {entity_name = 'global-chest', link_id = 1, requests = {}}
}, player_data = {}, provider_chests = {}, chest_type_schema = 1}
defines = {inventory = {character_trash = 1, chest = 2}}
local force = {get_linked_inventory = function() return inv end}
game = {forces = {force}, players = {}}
local processor = require('processor')
processor.process()
assert(storage.limits.science == 0 and storage.inventory.science == nil)
assert(inv[2].count == 10) -- Fresh packs are discovered but default limits still apply.
storage.limits.science = 5
processor.process()
assert(storage.inventory.science == 5 and inv[2].count == 5)
assert(inv[1].count == 3 and inv[1].durability == 0.5)
assert(inv[3].count == 5 and inv[5].count == 20)
storage.limits.science = -1
processor.process()
assert(storage.inventory.science == 10 and inv[2].count == 0)
assert(inv[1].count == 3)
storage.networks.test.requests.science = {min = 7, max = 7}
processor.process()
assert(storage.inventory.science == 6 and inv[2].count == 4)
assert(inv[1].count == 3 and inv[1].durability == 0.5)
processor.process()
assert(storage.inventory.science == 6 and inv[2].count == 4) -- Used packs prevent repeated overfilling.
assert(not require('state').can_delete_network('test'))
local clean = inventory({stack('science', 7, 'normal', 1), stack('science', 2, 'normal', 1)})
assert(pool.can_store_all(clean))
assert(pool.remove(clean, 'science', 8) == 8 and clean[1].count == 0 and clean[2].count == 1)

-- Personal trash follows the same durability-safe path.
local trash = inventory({stack('science', 1, 'normal', 0.25), stack('science', 6, 'normal', 1)})
local player = {index = 1, connected = true,
    character = {valid = true, get_requester_point = function() return nil end},
    get_main_inventory = function() return {} end,
    get_inventory = function() return trash end}
game.players = {player}
require('state').get_player_data(1).logistics_enabled = true
require('player_logistics').process()
assert(storage.inventory.science == 12 and trash[2].count == 0)
assert(trash[1].count == 1 and trash[1].durability == 0.25)

-- Retained used packs also count toward max, so only the true fresh surplus remains.
storage.networks.test.requests.science = {min = 0, max = 7}
inv[2].count = 10
processor.process()
assert(storage.inventory.science == 18 and inv[2].count == 4 and inv[1].count == 3)
''')
print("Passed: fresh science collection, limits, redistribution, quality/spoilage exclusions,")
print("partial durability preservation, deletion guard and personal trash collection.")
