# Global Network

A global item storage and logistics system for Factorio 2.0+. Manage a centralized inventory pool with network-based requests, perfect for megabases.

---

## Core Concept

Global Network provides a **shared global inventory** that all your chests can access. Instead of managing individual chest contents, you define **networks** with item requests, and the mod automatically distributes items to where they're needed.

**Key insight:** Requests are defined at the **network level**, not per-chest. This means the mod processes dozens of networks instead of thousands of individual chests, making it highly performant for large bases.

---

## Chests

All three chests use the craft chest's industrial body, frame and latch, with
custom skins and matching inventory icons:
green with a network symbol for storage, blue with a gear for crafting, and
orange with a logistic robot for the provider. Entity sprites are 64 × 64 pixels
and inventory icons are 32 × 32 pixels. The sprite scale compensates for
transparent margins so the visible chest fills the tile like a vanilla chest.
The provider uses a static
closed-lid sprite when opened; its logistics behaviour is unchanged.

### Global Chest

A linked container that shares its inventory with all other Global Chests on the same network.

- **Network ID**: Text-based identifier (e.g., "iron-gear-wheel", "main-storage", "mall")
- **Shared Inventory**: All chests with the same network ID share the exact same inventory
- **Requests**: Define min/max quantities per item at the network level

**How it works:**
- Items **above max** are collected into the global pool
- Items **below min** are supplied from the global pool

### Global Craft Chest

A separate linked chest with a dedicated recipe interface. Choose a recipe directly
with the native recipe selector, or open **All recipes** for a paginated catalogue
of every recipe prototype, including hidden, locked and modded recipes. The
catalogue searches internal recipe names, shown in tooltips. Settings can also be
pasted from assembling machines and furnaces.

All craft chests selecting the same recipe share a recipe network, its inventory,
multiplier and output reservation. These inventories are separate from normal
Global Chest networks. A new recipe network defaults to ten crafts (×10).

Existing Global Chests remain normal chests: their inventories and requests are
preserved, including former craft networks, which become editable manual networks.
Their former automatic slot filters are cleared. Place the new Global Craft Chest
to use the dedicated recipe controls.

### Global Provider Chest

A passive provider chest that pulls items FROM the global pool and makes them available to logistics bots.

- **Per-chest requests**: Each provider chest has its own item requests
- **Bot integration**: Works with your existing logistics network
- **Bridge**: Connects global storage to your robot logistics

---

## Global Inventory

Search the inventory by translated or internal item name. Search ignores case
and accents, works together with the no-limit filter, and remembers the query
for each player. Clear it with the button beside the search field.

Sort pinned HUD items from the inventory tab. The HUD contains only item rows. Choose
name A–Z/Z–A, quantity ascending/descending, or fill ratio ascending/descending.
Manual and automatic pins keep their separate sections; automatic selection
still prioritizes the ten lowest stock ratios. Items with unlimited or zero
limits appear last when sorting by fill ratio. The choice is saved per player.

Craft networks display `craft:` with their recipe icon in the network list and
craft chest panel. Hover over the name to see the persistent network ID.

The central item pool shared across all networks. Access it via **Shift+G**.

### Limits System

Every item has a storage limit that controls how much can be stored globally:

| Limit | Behavior |
|-------|----------|
| **0 (Blocked)** | Item cannot enter global storage |
| **Numeric** | Stores up to that amount |
| **Unlimited** | No limit on storage |

New items appear with a limit of 0 (blocked) until you configure them. This prevents unwanted items from flooding your storage.

In the item edit popup, limit, unlimited and HUD pin changes stay in draft until
you click **OK** or press **Enter**. Closing the popup discards the draft.

---

## Network Management GUI (Shift+G)

Press **Shift+G** to open the management interface with three tabs:

### Networks Tab
- View all networks with their chest count and request count
- See status: **Active** (has chests) or **Ghost** (no chests, keeps configuration)
- Delete networks (chests are reassigned to default network)

### Global Inventory Tab
- Grid view of all items in global storage
- Click any item to edit its limit and pin settings
- Filter to show only blocked items (limit = 0)
- Add limits for new items before they arrive

### Player Tab
- Enable/disable player logistics integration
- Toggle auto-pin for low stock items

---

## Features

### Copy-Paste from Assemblers

Copy settings from an assembling machine or furnace and paste onto a **Global
Craft Chest** to select its recipe and join that recipe's shared network. You can
also select the recipe directly in the chest interface. Provider chests keep their
one-stack-per-ingredient recipe import.

### Craft Network Multiplier

Global Craft Chests show their recipe controls and shared multiplier once a recipe
is selected. Without a recipe, only recipe selection is shown. At **×1**,
each item request equals its ingredient quantity in one craft; **×2** requests
twice that quantity, and so on. Both request minimum and maximum use that amount.
The slider runs linearly from **×10 to ×500** in steps of 10. Type any positive integer in the field and click **Apply** or
press **Enter**, including ×1 or values above ×500. The field always displays
the actual factor; the slider shows the closest available step. New networks
default to ×10. Networks still using the old ×1 default are adjusted once to ×10;
other existing factors and explicit blueprint factors are preserved.

Changing the factor recalculates the network's ingredient request list and expands
its inventory bar for the necessary stacks, subject to the chest's slot capacity.
The setting is shared by all chests on the network and preserved by copy/paste and
blueprints. Existing `craft:` networks adopt exact ingredient quantities at ×1.
Fluids cannot be stored in chests and are not included. Normal chests have their
own manual-request interface; provider chests keep their existing request behavior.

Craft requests are read-only and controlled by the multiplier. A second slider
selects the shared number of slots reserved for outputs. Each distinct item output
gets at least one slot by default, including probabilistic outputs; repeated products
of the same item share a filter. The slider cannot go below this minimum. Additional
slots are shared evenly, with the remainder assigned in alphabetical item order.
Fluid-only recipes need no item output slot. Existing networks and blueprints with
too few reserved slots are adjusted automatically.
Input slots and output slots are filtered by item. The summary displays each
item's icon, requested input quantity or reserved output capacity, and slot count
in compact input and output grids without individual frames. Hover an item for
its full name and exact quantities. Large recipes use 16-item pages instead of
a nested scroll pane.
It warns if planned inputs plus reserved outputs exceed the chest capacity or
an output has no slot. Available slots are limited by the inventory size, with
output space reserved before allocating the remaining capacity to inputs.
Existing items are not removed when changing filters. Blueprints preserve this setting.

### Resource Icons in Network IDs

Open a linked chest, click **Edit**, then use the single icon button beside the
ID field. It opens Factorio's native signal selector, with item, fluid, virtual
signal and other available signal icons. Each selection appends an icon to the
ID; click **Validate** to apply it. Multiple icons and text can be combined,
for example `Iron [img=item/iron-ore]` or `Oil [img=fluid/crude-oil]`.
You can also type or remove these tags directly.

The exact text, including icon tags, is the network ID. Adding an icon to an
existing ID selects or creates a different network, like any other ID edit.
Copy/paste and blueprints preserve the icons. Network lists sort by the text
outside icon tags; icon-only IDs use the full ID as their sort key.

### Copy/Paste and Blueprints

Use **Shift+right-click** on a configured chest to copy its settings, then
**Shift+left-click** on another chest of the same type to paste them. Provider
chests copy their complete item request list, replacing the destination requests.
Linked chests join the source network. Linked chests request the exact recipe ingredients × a multiplier; provider
chests keep their one-stack-per-ingredient recipe import.

**Ctrl+C**, **Ctrl+X** and blueprints retain provider requests and linked chest
network names, requests and inventory bars, plus craft chest recipes, multipliers
and output reservations. Settings are restored when a player,
construction robot or script builds the chest. Blueprint library records and
copying tagged ghosts are supported. Items inside chests and the global pool are
not included in blueprints.

When placing a linked chest blueprint, an existing network of the same name keeps
its current requests and shared inventory bar. A missing network is recreated
from the blueprint. This prevents pasting an old blueprint from overwriting a
live network's configuration. Craft blueprints similarly keep an existing recipe
network's live settings; missing recipe networks are recreated from the blueprint.

The network management table and the chest's manual-network chooser are sorted
alphabetically, ignoring ASCII letter case.

### Player Logistics Integration

When enabled, the global network integrates with your personal logistics:

- **Supply**: Items you request in your personal logistics are supplied from global storage
- **Trash Collection**: Items in your trash slots are automatically collected into global storage (bypasses limits)

### HUD Pins

Pin important items to your screen for at-a-glance monitoring:

- **Manual pins**: Click any item in the inventory grid and check "Pin to HUD"
- **Auto-pin low stock**: Automatically shows items below 10% of their limit (up to 10 items)

Pinned items display current quantity and limit on the left side of your screen.

### Network-Based Architecture

Unlike mods that process every chest individually, Global Network processes **networks**:

- All chests with the same network ID share one linked inventory
- The mod only needs to check each network once, not each chest
- Scales to thousands of chests without performance impact
- Round-robin processing distributes load across ticks

---

## Quick Start

1. **Craft Global Chests** and place them
2. **Open a chest** and set a Network ID (e.g., "iron")
3. **Add requests** with min/max quantities
4. **Press Shift+G** to open the network GUI
5. **Set limits** for items you want to store globally
6. Items automatically flow between chests and global storage

### Example Setup

**Iron plate distribution:**
1. Place Global Chests at your smelter output and assembler inputs
2. Set all to network "iron"
3. Add request: Iron Plate, min=100, max=1000
4. Set global limit for iron-plate to 50000 (or unlimited)

Items above 1000 are collected to global storage. When any chest drops below 100, items are supplied from global storage.

---

## Hotkeys

| Key | Action |
|-----|--------|
| **Shift+G** | Toggle Network Management GUI |

---

## Tips

- **Use meaningful network names** like "iron-production", "copper-bus", "mall-circuits"
- **Set limits before items arrive** to prevent blocking
- **Use unlimited** for common materials you always want to accept
- **Keep limits at 0** for items you don't want in global storage
- **Copy-paste from assemblers** is the fastest way to set up production
- **Provider chests** are great for mall setups where bots deliver finished products

---

## Compatibility

- **Factorio Version**: 2.0.77 or newer in the 2.0 series
- **Multiplayer**: Supported
- **Safe to add mid-game**: Yes

The global quantity pool accepts ordinary items, modules and capsules of **normal quality**.
Higher-quality items, perishable items, ammo, tools, blueprints, armor and other items
with stack-specific data remain in physical linked inventories or player trash slots.
They are never converted to normal items by the pool. Empty those items before deleting
a network. Personal logistics supplies normal-quality requests from active sections and
respects the personal logistics switch and section multipliers.

Linked inventories are separate per force, as in Factorio; the global quantity pool and
network request configuration are shared by all forces.

## Build the Mod Portal artifact

Requires Python 3.9 or newer; no additional Python packages are needed.
From the repository directory, run:

```powershell
python scripts/build_mod.py
```

The script reads the name and version from `info.json` and creates
`dist/global-storage_0.1.4.zip`, containing a single `global-storage_0.1.4/` directory.
It validates the metadata and ZIP integrity and includes runtime files, locale,
thumbnail, README and changelog. Git files, `.claude`, development scripts and generated
artifacts are excluded. Identical inputs produce identical archives.

To select another destination:

```powershell
python scripts/build_mod.py --output-dir E:/mod-releases
```

Upload the generated ZIP to the Mod Portal. To test locally, use this checkout in
`mods/global-storage/` or put the ZIP directly in `mods/`, then enable Global Storage
in Factorio's Mods menu. Use only one copy of this version at a time.

Validation for this update was limited to static Lua compilation, checks against
the bundled Factorio 2.0.77 API/prototypes, GUI behaviour with Lua API doubles,
and ZIP inspection. Run `python tests/check_inventory_view.py` with Python and
`lupa` installed to check search, sorting, recipe captions and GUI events without
starting the game. Factorio was not launched.
In-game validation remains to be done: crafting and opening both chests, recipe
copy/paste with a small inventory, provider requests without a linked network,
personal requests with a full inventory and inactive sections, quality/spoilage
preservation, network deletion, and loading an existing save.

---

## Technical Notes

- Processing runs every 10 ticks with round-robin distribution
- Uses Factorio's native linked-container system for shared inventories
- Network IDs receive sequential unique link IDs for the linked container system
- Ghost networks (no chests) retain their configuration for later use
