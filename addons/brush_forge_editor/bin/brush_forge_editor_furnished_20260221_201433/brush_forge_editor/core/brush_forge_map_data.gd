@tool
extends Resource
class_name BrushForgeMapData

@export var map_name := "BrushForge Map"
@export var brush_payload: Array[Dictionary] = []
@export var collision_enabled := true
@export var collision_layer := 1
@export var collision_mask := 1
@export var collision_margin := 0.01
@export var baked_collision: Array[Dictionary] = []
@export var metadata: Dictionary = {}

func clear_all() -> void:
	brush_payload.clear()
	baked_collision.clear()

func from_brush_array(brushes: Array) -> void:
	brush_payload.clear()
	for item in brushes:
		var brush: BrushForge = item as BrushForge
		if brush == null:
			continue
		var planes: Array[Dictionary] = []
		for pp in brush.planes:
			var p: NeoPlane = pp as NeoPlane
			if p == null:
				continue
			planes.append({
				"normal": p.normal,
				"distance": p.distance,
			})
		brush_payload.append({
			"position": brush.position,
			"size": brush.size,
			"planes": planes,
			"face_material_paths": brush.face_material_paths.duplicate(true),
			"face_uv_transforms": brush.face_uv_transforms.duplicate(true),
			"face_paint_colors": brush.face_paint_colors.duplicate(true),
			"face_paint_strokes": brush.face_paint_strokes.duplicate(true),
			"face_subdivisions": brush.face_subdivisions.duplicate(true),
			"lock_uvs": brush.lock_uvs,
		})

func to_brush_array() -> Array:
	var out: Array = []
	for item in brush_payload:
		var pos: Vector3 = item.get("position", Vector3.ZERO)
		var size: Vector3 = item.get("size", Vector3.ONE)
		var brush := BrushForge.create_box(pos, size)
		brush.planes.clear()
		var planes: Array = item.get("planes", [])
		for plane_item in planes:
			var normal: Vector3 = plane_item.get("normal", Vector3.UP)
			var distance := float(plane_item.get("distance", 0.0))
			brush.planes.append(NeoPlane.new(normal, distance))
		if brush.planes.size() < 4:
			var rebuilt := BrushForge.create_box(pos, size)
			brush.planes = rebuilt.planes.duplicate()
		var face_material_paths: Dictionary = item.get("face_material_paths", {})
		brush.face_material_paths = face_material_paths.duplicate(true)
		var face_uv_transforms: Dictionary = item.get("face_uv_transforms", {})
		brush.face_uv_transforms = face_uv_transforms.duplicate(true)
		var face_paint_colors: Dictionary = item.get("face_paint_colors", {})
		brush.face_paint_colors = face_paint_colors.duplicate(true)
		var face_paint_strokes: Dictionary = item.get("face_paint_strokes", {})
		brush.face_paint_strokes = face_paint_strokes.duplicate(true)
		var face_subdivisions: Dictionary = item.get("face_subdivisions", {})
		brush.face_subdivisions = face_subdivisions.duplicate(true)
		brush.lock_uvs = bool(item.get("lock_uvs", false))
		out.append(brush)
	return out

func bake_collision_data_from_brushes(brushes: Array) -> void:
	baked_collision.clear()
	for item in brushes:
		var brush: BrushForge = item as BrushForge
		if brush == null:
			continue
		baked_collision.append({
			"type": "box",
			"position": brush.position,
			"size": brush.size,
			"layer": collision_layer,
			"mask": collision_mask,
			"margin": collision_margin,
		})
