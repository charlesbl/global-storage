# Chest skin assets

## Current uniform skins

The craft chest is the common source for both other skins. The craft image was
left unchanged. Both edits used the built-in imagegen tool, transparent output,
and the exact same source image:
`C:/Users/Charles/.codex/generated_images/01a11be4-222e-7be2-9d86-97b77785c325/exec-83ccf394-91f2-4e56-aab5-7ba7d2fe421a.png`.

Storage edit prompt:

> Edit the supplied BLUE CRAFT CHEST image as the actual edit source. Produce a matching sibling skin for the same chest. Strictly preserve its exact silhouette, outer contour, dimensions, placement, front latch and long vertical metal strap, every reinforced corner, bolt, vent, lid edges, camera perspective, lighting, scratches and transparent alpha background. Do not redesign any mechanical parts. Change ONLY the blue painted panels and the cyan gear emblem. Recolour all blue painted panels emerald green. Replace the gear on the lid with a large bright mint green network emblem consisting of three circular nodes connected in a triangle. Match the original emblem's flat painted weathered style and approximate bounding area. No gear, no text, no arrows.

Provider edit prompt:

> Edit the supplied BLUE CRAFT CHEST image as the actual edit source. Produce a matching sibling skin for the same chest. Strictly preserve its exact silhouette, outer contour, dimensions, placement, front latch and long vertical metal strap, every reinforced corner, bolt, vent, lid edges, camera perspective, lighting, scratches and transparent alpha background. Do not redesign any mechanical parts. Change ONLY the blue painted panels and the cyan gear emblem. Recolour all blue painted panels burnt orange. Replace the gear on the lid with a large amber yellow logistic flying robot pictogram: rounded central body, two lateral rotor discs on arms and a small cargo gripper underneath. The symbol is flat painted and weathered on the lid, not a separate flying object. Match the original emblem's approximate bounding area. No gear, no arrows, no text.

## Original generation history

Generated with the built-in imagegen tool, with transparent backgrounds.
The `import_skin.ps1` script performs only resizing to 64-pixel entity sprites
and 32-pixel inventory icons, preserving transparency. Runtime assets live in
`graphics/entity/` and `graphics/icons/`.

Each image used this prompt, replacing `{variant}` with the corresponding line:

> Create ONE production-ready Factorio-style game sprite of a small industrial storage chest. Orthographic overhead three-quarter view: front face visible at bottom, lid visible from above, left and right symmetry, front edge horizontal, NO isometric diamond angle. Square chest footprint. Detailed weathered dark gunmetal frame, bolts, reinforced corners, {variant}. Cohesive realistic pre-rendered strategy-game asset, crisp silhouette readable at 32 pixels, restrained detail, lighting from upper left. Closed lid. Single isolated chest centered, fills 85 percent of square canvas. Transparent alpha background, no ground, no cast shadow, no scenery, no text, no letters, no other objects. Deliver a square sprite image.

- `global-chest`: emerald green panels, bright mint network symbol of three connected nodes on the lid
- `global-craft-chest`: cobalt blue panels, bright cyan mechanical gear symbol on the lid
- `global-provider-chest`: burnt orange panels, bright amber outgoing arrow symbol on the lid

The provider was subsequently edited with the built-in imagegen tool using the
original provider image as the edit target and this prompt:

> Edit this Factorio industrial chest sprite. Preserve the exact chest silhouette, orange colour, metal frame, bolts, perspective, lighting, centered composition and transparent background. Replace ONLY the yellow outgoing arrow on the lid with a bold, easily recognizable yellow/amber emblem of a Factorio-style logistic flying robot: compact central rounded metal body, two lateral rotor arms/discs, and a small dangling cargo gripper. A painted/embossed simple robot pictogram on the lid, not an actual hovering separate robot. Make the robot symbol large and readable even on a 32-pixel game sprite. No arrows, no text. Everything else identical.
