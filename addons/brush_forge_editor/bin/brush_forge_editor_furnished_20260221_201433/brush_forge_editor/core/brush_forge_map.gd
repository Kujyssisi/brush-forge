@tool
extends Node3D
class_name BrushForgeMap

var brush_data: Array = []
@export var map_data: BrushForgeMapData = BrushForgeMapData.new()
@export_dir var material_folder_path: String = ""
const COLLISION_ROOT_NAME := "__BrushForgeCollisionRoot"

func _ready() -> void:
	_ensure_map_data()
	map_data.resource_local_to_scene = true
	call_deferred("_bootstrap_from_saved_data")

func _bootstrap_from_saved_data() -> void:
	_ensure_map_data()
	var has_payload := not map_data.brush_payload.is_empty()
	if has_payload:
		# `brush_data` is not serialized by Godot, so rebuild runtime brushes from saved payload.
		# Only do this when runtime brush state is empty to avoid clobbering active edits.
		if brush_data.is_empty():
			apply_data_to_scene(true)
		if map_data.collision_enabled and not map_data.baked_collision.is_empty():
			_rebuild_collision_children_from_data()
	else:
		if not brush_data.is_empty():
			sync_data_from_scene()

func add_brush(brush, mesh_instance: MeshInstance3D, sync: bool = true) -> void:
	brush_data.append(brush)
	add_child(mesh_instance)
	mesh_instance.owner = self
	if sync:
		sync_data_from_scene()

func remove_brush(mesh_instance: MeshInstance3D, sync: bool = true) -> void:
	var i = get_children().find(mesh_instance)
	if i != -1:
		brush_data.remove_at(i)
		remove_child(mesh_instance)
		mesh_instance.queue_free()
		if sync:
			sync_data_from_scene()

func clear_all() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	brush_data.clear()
	_ensure_map_data()
	map_data.clear_all()

func bake_collision_data() -> void:
	_ensure_map_data()
	map_data.bake_collision_data_from_brushes(brush_data)
	_rebuild_collision_children_from_data()

func clear_baked_collision() -> void:
	_clear_collision_children()
	_ensure_map_data()
	map_data.baked_collision.clear()

func sync_data_from_scene() -> void:
	_ensure_map_data()
	map_data.from_brush_array(brush_data)

func apply_data_to_scene(rebuild_meshes: bool = true) -> void:
	_ensure_map_data()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	brush_data.clear()
	var rebuilt := map_data.to_brush_array()
	for item in rebuilt:
		var brush: BrushForge = item as BrushForge
		if brush == null:
			continue
		brush_data.append(brush)
		if rebuild_meshes:
			var mi := MeshInstance3D.new()
			mi.mesh = BrushMeshBuilder.build_brush_mesh(brush)
			mi.position = brush.position
			add_child(mi)
			mi.owner = self

func _ensure_map_data() -> void:
	if map_data == null:
		map_data = BrushForgeMapData.new()
	map_data.resource_local_to_scene = true

# Save map in .bfm format
func save_to_file(path: String) -> void:
	sync_data_from_scene()
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot open .bfm for write: " + path)
		return
	
	for brush in brush_data:
		var bf: BrushForge = brush as BrushForge
		if bf == null:
			continue
		f.store_line("BRUSH")
		f.store_line("POS %f %f %f" % [bf.position.x, bf.position.y, bf.position.z])
		f.store_line("SIZE %f %f %f" % [bf.size.x, bf.size.y, bf.size.z])
		for p in bf.planes:
			var plane: NeoPlane = p as NeoPlane
			if plane == null:
				continue
			f.store_line("PLANE %f %f %f %f" % [plane.normal.x, plane.normal.y, plane.normal.z, plane.distance])
		f.store_line("END")
	f.close()

# Load map from .bfm
func load_from_file(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open .bfm for read: " + path)
		return
	
	# Clear existing
	clear_all()

	var current_brush: BrushForge = null
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line == "BRUSH":
			current_brush = BrushForge.new()
		elif line.begins_with("POS"):
			var pts = line.split(" ")
			current_brush.position = Vector3(pts[1].to_float(), pts[2].to_float(), pts[3].to_float())
		elif line.begins_with("SIZE"):
			var pts = line.split(" ")
			current_brush.size = Vector3(pts[1].to_float(), pts[2].to_float(), pts[3].to_float())
		elif line.begins_with("PLANE"):
			var pts = line.split(" ")
			current_brush.planes.append(NeoPlane.new(
				Vector3(pts[1].to_float(), pts[2].to_float(), pts[3].to_float()),
				pts[4].to_float()
			))
		elif line == "END":
			var mi = MeshInstance3D.new()
			mi.mesh = BrushMeshBuilder.build_brush_mesh(current_brush)
			mi.position = current_brush.position
			add_child(mi)
			mi.owner = self
			brush_data.append(current_brush)
			current_brush = null
	f.close()
	sync_data_from_scene()

func _clear_collision_children() -> void:
	var node := get_node_or_null(COLLISION_ROOT_NAME)
	if node != null:
		remove_child(node)
		node.queue_free()

func _get_or_create_collision_root() -> Node3D:
	var existing := get_node_or_null(COLLISION_ROOT_NAME)
	if existing is Node3D:
		return existing as Node3D
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var root := Node3D.new()
	root.name = COLLISION_ROOT_NAME
	add_child(root)
	root.owner = self
	return root

func _rebuild_collision_children_from_data() -> void:
	_clear_collision_children()
	_ensure_map_data()
	if not map_data.collision_enabled:
		return
	var root := _get_or_create_collision_root()
	for i in range(map_data.baked_collision.size()):
		var item: Dictionary = map_data.baked_collision[i]
		var body := StaticBody3D.new()
		body.name = "BrushCollision_%d" % i
		body.position = item.get("position", Vector3.ZERO)
		body.collision_layer = int(item.get("layer", map_data.collision_layer))
		body.collision_mask = int(item.get("mask", map_data.collision_mask))
		var shape_node := CollisionShape3D.new()
		var brush: BrushForge = null
		if i >= 0 and i < brush_data.size():
			brush = brush_data[i] as BrushForge
		var shape := _build_collision_shape_for_brush(brush, item)
		if shape == null:
			continue
		shape_node.shape = shape
		body.add_child(shape_node)
		shape_node.owner = self
		root.add_child(body)
		body.owner = self

func _build_collision_shape_for_brush(brush: BrushForge, item: Dictionary) -> Shape3D:
	if brush != null:
		var mesh := BrushMeshBuilder.build_brush_mesh(brush)
		if mesh != null:
			var faces := mesh.get_faces()
			if faces.size() >= 3:
				var concave := ConcavePolygonShape3D.new()
				concave.set_faces(faces)
				return concave
	var box := BoxShape3D.new()
	var raw_size: Vector3 = item.get("size", Vector3.ONE)
	box.size = Vector3(maxf(raw_size.x, 0.01), maxf(raw_size.y, 0.01), maxf(raw_size.z, 0.01))
	return box
