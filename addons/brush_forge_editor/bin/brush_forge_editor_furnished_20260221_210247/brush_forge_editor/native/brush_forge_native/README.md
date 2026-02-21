# Brush Forge Native (GDExtension)

This optional GDExtension accelerates heavy brush vertex computation.

When compiled and present, `BrushMeshBuilder` will automatically call the native class `BrushForgeNative`.
When missing, Brush Forge keeps using the existing GDScript path.

## Build (Linux/macOS/Windows)

1. In `addons/brush_forge_editor/native/brush_forge_native`, place `godot-cpp/` (matching your Godot version) next to `SConstruct`.
2. Build:

```bash
cd addons/brush_forge_editor/native/brush_forge_native
scons target=template_debug
scons target=template_release
```

3. Confirm output binaries are created under `addons/brush_forge_editor/bin/` with names referenced by:
`addons/brush_forge_editor/native/brush_forge_native/brush_forge_native.gdextension`.

## Current Native Scope

- `compute_brush_vertices(plane_normals, plane_distances) -> PackedVector3Array`

This maps to the previous `_compute_brush_vertices` hot loop in GDScript.
