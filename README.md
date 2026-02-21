# BrushForge Editor

BrushForge is a Godot 4 editor plugin for brush-based blockout and level editing.

## What You Get

- Brush editing tools in the 3D editor (move, face/edge/vertex, rotate, clip)
- Texture + UV editing per face
- Vertex paint
- Face subdivision controls
- Bake to runtime mesh + collision

## Requirements

- Godot 4.x
- Plugin path: `res://addons/brush_forge_editor/`

## Install

1. Put this addon in your project under `addons/brush_forge_editor`.
2. Open Godot.
3. Enable **BrushForge Editor** in `Project > Project Settings > Plugins`.

## Build And Package

From repo root:

```bash
go-task build-plugin
go-task package-plugin
go-task full-plugin
go-task clear-bin
```

Task summary:

- `go-task build-plugin`: build native debug + release libraries
- `go-task package-plugin`: build and create furnished addon archive in `addons/brush_forge_editor/bin/`
- `go-task full-plugin`: clear `bin`, then build + package
- `go-task clear-bin`: clear everything in `addons/brush_forge_editor/bin/`

Direct packaging script:

```bash
./scripts/package_furnished_addon.sh
```

## Quick Use

1. Add or select a `BrushForgeMap` in your scene.
2. Use toolbar tools to create and edit brushes.
3. Use Texture Tool for per-face material/UV.
4. Use Paint Tool for vertex paint.
5. Click **Bake Mesh+Collision** when ready.

## Bake Material Rules

- `clip.tres`: collision only
- `skip.tres`: no mesh and no collision

Paths:

- `addons/brush_forge_editor/utility_textures/clip.tres`
- `addons/brush_forge_editor/utility_textures/skip.tres`

## Troubleshooting

- If native features fail, rebuild: `go-task build-plugin`
- If editor still shows old behavior, restart Godot after rebuilding
- If packaging warnings appear, run `go-task clear-bin` then `go-task package-plugin`

## Credits

- BrushForge Editor: `Kujyssisi`
- `clip` / `skip` texture credit: **funcgodot**
- Editing workflow/style inspiration: **TrenchBroom**
