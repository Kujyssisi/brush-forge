# BrushForge Editor

A custom **Godot 4** in-editor blockout/brush workflow plugin.

BrushForge gives you Quake/TrenchBroom-style brush editing directly in the 3D editor with tools for face/vertex/edge editing, UV controls, vertex paint, subdivision, and one-click bake to runtime mesh + collision.

## Features

- Brush-based level editing inside Godot editor
- Toolset:
  - Add Brush
  - Move Brush
  - Brush Tool (draw/extrude)
  - Clip Tool
  - Vertex Tool
  - Edge Tool
  - Face Tool
  - Rotate Tool
  - Paint Tool
  - Subdivide Tool
  - Texture Tool
- Vertex Paint:
  - Brush paint mode
  - Bucket fill mode (fills full face)
  - Blend modes: Normal, Add, Multiply, Subtract, Burn
- Per-face texturing and UV editor:
  - Scale / Offset / Rotation
  - UV preview + UV snap
  - Alt-copy material/UV from face to face
- UV Lock/Unlock toggle
- Face subdivision with visual subdivide gizmo
- Bake Mesh + Collision button:
  - Creates `idk map baked` node
  - Hides editable `BrushForgeMap`
  - Auto-generates UV2 unwrap for baked mesh
  - Collision can ignore visual subdivisions
- Utility material behavior for baking:
  - `clip.tres` = collision only
  - `skip.tres` = no mesh, no collision

## Requirements

- Godot `4.x`
- Plugin folder in project:
  - `res://addons/brush_forge_editor/`

## Installation

1. Copy this repository/plugin into your project.
2. In Godot: `Project > Project Settings > Plugins`.
3. Enable **BrushForge Editor**.

## Furnished Addon Package (No `godot-cpp` Copy)

Use this command from repo root:

```bash
./scripts/package_furnished_addon.sh
```

It will:

- Build native libraries (`template_debug` + `template_release`)
- Create a ready-to-drop packaged addon under:
  - `addons/brush_forge_editor/bin/`
- Exclude:
  - `addons/brush_forge_editor/native/brush_forge_native/godot-cpp-godot-4.5-stable`

## Quick Start

1. Select your scene root and enable the plugin.
2. Use or create a `BrushForgeMap` node.
3. Click **Add Brush** to spawn a brush.
4. Enable **Move Brush** and pick a sub-tool (Face, Vertex, Rotate, etc.).
5. Use **Texture Tool** to assign materials and tune UVs.
6. Use **Paint Tool** for vertex colors.
7. When ready, click **Bake Mesh+Collision**.

## Toolbar Reference

- **Add Brush**: Create new brush.
- **Move Brush**: Main edit mode required by move sub-tools.
- **Brush Tool**: Draw brush footprint on face, then extrude.
- **Clip Tool**: Slice brush geometry.
- **Vertex/Edge/Face Tools**: Direct shape editing.
- **Rotate Tool**: Rotate brush around selected axis.
- **Paint Tool**: Vertex painting.
- **Subdivide Tool**: Set per-face subdivision amount.
- **Texture Tool**: Per-face material + UV editing.
- **Lock/Unlock UVs**: Preserve/move UV mapping behavior when editing.
- **Bake Mesh+Collision**: Bake editable map into runtime geometry.

## Paint Tool Notes

- **Paint: Brush** = stamp-based painting with radius/strength.
- **Paint: Bucket** = full face fill (base face color layer).
- Brush strokes blend on top of face fill.
- Designed to stay responsive on subdivided faces.

## Bake Behavior

Baking creates a sibling node named:

- `idk map baked` (`StaticBody3D`)

Inside it:

- `BakedMesh` (`MeshInstance3D`) - merged by shared material
- `BakedCollision` (`CollisionShape3D`) - combined collision shape

Bake material rules (per face/surface):

- `clip.tres`: contributes to collision only
- `skip.tres`: excluded from mesh and collision
- any other material: contributes to both mesh and collision

## UV / Texture Workflow

- Assign material per face in **Texture Tool**.
- Tune `Scale`, `Offset`, `Rotation` in UV controls.
- Use **Alt + click/drag** in Texture Tool to copy material/UV to other faces.
- UV copy attempts world-aligned continuity across faces.

## Important Paths

- Plugin config: `addons/brush_forge_editor/plugin.cfg`
- Main editor script: `addons/brush_forge_editor/editor/editor_plugin.gd`
- Mesh builder: `addons/brush_forge_editor/mesh/brush_mesh_builder.gd`
- Utility materials:
  - `addons/brush_forge_editor/utility_textures/clip.tres`
  - `addons/brush_forge_editor/utility_textures/skip.tres`

## Troubleshooting

- If node icon/tool updates don’t appear, disable/re-enable plugin.
- If material list is empty, verify your material folder and `.tres/.res` files.
- If bake output already exists, a new bake replaces the existing `idk map baked` node.

## Credits

- Plugin: **BrushForge Editor** by `Kujyssisi`
- Utility `clip` / `skip` texture credit: **funcgodot**
- Editing workflow/style inspiration credit: **TrenchBroom**
