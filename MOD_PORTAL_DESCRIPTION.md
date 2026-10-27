# Global Storage

A powerful networked storage system that lets you manage items across your entire factory through a unified global inventory pool.

**Version 0.1.4 introduces a third chest type.** Version 0.1.3 had two:
the Global Chest and the Global Provider Chest. There are now **three**:
Global Chest for manual storage networks, Global Craft Chest for recipe-driven
networks, and Global Provider Chest for logistics bots.

## Features

### Global Chests - Shared Network Storage
- Place **Global Chests** and assign them a network ID (like "iron" or "copper")
- All chests with the same network ID share the same inventory instantly
- Set **min/max requests** per network to automate item distribution
- More chests add access points to the same inventory; they do not increase its capacity

### Global Craft Chests
- Dedicated recipe interface, separate from normal chests
- Select a recipe directly or paste it from an assembler/furnace
- All recipes catalogue includes hidden, locked and modded recipes
- Share ingredient requests, multiplier and output slots per recipe network
- Reserve filtered slots for ingredients and item outputs, with capacity warnings
- Craft chests supply and collect items; assembling machines and furnaces perform the crafting

### Global Provider Chests
- Pull specific items from the global pool into logistics networks
- Configure per-chest item requests
- Perfect for feeding assemblers or buffering items

### Smart Item Distribution
- **Surplus collection**: Items above max are sent to global pool
- **Demand fulfillment**: Items below min are pulled from global pool
- Round-robin processing optimized for thousands of chests

### Storage Limits
- Control what items enter your global storage
- Set numeric limits or unlimited storage per item
- Block unwanted items from clogging your system
- New items are blocked until you configure their limit; personal trash collection and network deletion bypass limits

### Player Logistics Integration
- Your personal logistics requests pull from global storage
- Trash items automatically go into the global pool
- Pin items to HUD for real-time monitoring

### Network Management GUI (Shift+G)
- View all networks and their status
- Browse global inventory with current quantities
- Configure storage limits from one central location
- Search translated or internal item names, ignoring case and accents
- Sort the inventory by name, quantity or fill ratio in either direction
- Sort HUD pins independently from the Player tab, with settings saved per player
- Display craft recipe icons in network names

## Perfect For
- **Megabases** - Scales efficiently with network-based processing
- **Mall builds** - Easy item distribution to crafting areas
- **Organized storage** - Logical grouping by network ID

## How to Use
1. Craft and place Global Chests
2. Click a chest and set its Network ID
3. Add requests (min/max) for items you need
4. Place more chests with the same ID to access the shared inventory elsewhere
5. Use Shift+G to manage networks and view global inventory

## Compatibility
Requires Factorio 2.1.23 or newer in the 2.1 series. The global quantity pool handles
ordinary items, modules, capsules and fresh non-perishable science packs/tools of
normal quality. Higher-quality and perishable items, partially consumed tool
stacks, ammo, blueprints, armor and other stacks with individual data stay in
physical inventories. Remove them before deleting a network. Network configuration
and the global pool are shared across forces; linked chest inventories are per force.

## Tips
- Copy-paste from an assembler to a craft chest to auto-fill requests with recipe ingredients
- Use meaningful network names like "science-red" or "green-circuits"
- Set storage limits to prevent overflow of unwanted items

## Copy/Paste and Blueprints
Use Shift+right-click to copy chest settings and Shift+left-click to paste onto
another chest of the same type. Provider requests and linked network settings
are retained by Ctrl+C, Ctrl+X and blueprints. Existing named networks keep their
live configuration. Craft and provider chests also accept recipes copied from
assemblers or furnaces. Network lists are sorted alphabetically.

## Resource Icons in Network IDs
The network ID editor has one native signal selector beside the text field.
Combine text and multiple icons, such as `Iron [img=item/iron-ore]`. Icon tags are
part of the exact ID and survive copy/paste and blueprints. Lists sort by the
text of the name; changing the ID selects or creates a different network.

## Craft Multipliers
Global Craft Chests request the exact item ingredients for ten crafts (x10) by default.
Use their shared linear x10-x500 slider to multiply the quantities, or type any positive integer
and confirm with Apply/Enter, up to 2147483647 items per ingredient request.
Copy/paste and blueprints retain the multiplier and output reservations. Each
distinct item output requires at least one slot; fluid-only outputs reserve none.

## Upgrading from 0.1.3: Two Chest Types Become Three
Previously, pasting an assembler or furnace recipe onto a normal Global Chest
created a `craft:` network requesting one stack of each item ingredient.
In 0.1.4, paste recipes onto the new **Global Craft Chest**, or select a recipe
in its interface. It requests exact ingredient quantities multiplied by the
shared craft factor (x10 by default), with dedicated input/output slot filters.
Normal Global Chests now use manual requests and no longer import machine recipes.

Existing Global Chests are not replaced or converted into craft chests. They
keep their linked inventories and requests, including old `craft:` networks.
Place a Global Craft Chest to use the new recipe controls; its recipe inventory
is separate from the old normal-chest inventory. Global Provider Chests remain
the bridge to logistics bots and can also import one-stack-per-ingredient requests
from an assembler or furnace.
