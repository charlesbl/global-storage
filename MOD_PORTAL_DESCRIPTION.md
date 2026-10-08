# Global Network

A powerful networked storage system that lets you manage items across your entire factory through a unified global inventory pool.

## Features

### Global Chests - Shared Network Storage
- Place **Global Chests** and assign them a network ID (like "iron" or "copper")
- All chests with the same network ID share the same inventory instantly
- Set **min/max requests** per network to automate item distribution

### Global Craft Chests
- Dedicated recipe interface, separate from normal chests
- Select a recipe directly or paste it from an assembler/furnace
- All recipes catalogue includes hidden, locked and modded recipes
- Share ingredient requests, multiplier and output slots per recipe network

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

### Player Logistics Integration
- Your personal logistics requests pull from global storage
- Trash items automatically go into the global pool
- Pin items to HUD for real-time monitoring

### Network Management GUI (Shift+G)
- View all networks and their status
- Browse global inventory with current quantities
- Configure storage limits from one central location

## Perfect For
- **Megabases** - Scales efficiently with network-based processing
- **Mall builds** - Easy item distribution to crafting areas
- **Organized storage** - Logical grouping by network ID

## How to Use
1. Craft and place Global Chests
2. Click a chest and set its Network ID
3. Add requests (min/max) for items you need
4. Place more chests with the same ID to expand capacity
5. Use Shift+G to manage networks and view global inventory

## Compatibility
Requires Factorio 2.0.77 or newer in the 2.0 series. The global quantity pool handles
ordinary items, modules and capsules of normal quality. Higher-quality and perishable
items, ammo, tools, blueprints, armor and other stacks with individual data stay in
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
and confirm with Apply/Enter. Copy/paste and blueprints retain the multiplier.

Existing normal chests retain their inventory and requests. Former craft networks
become editable manual networks; use the new craft chest for recipe controls.
