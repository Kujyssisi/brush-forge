@tool
extends RefCounted

static func collect_bake_geometry_from_meshes(
	brush_position: Vector3,
	render_mesh: ArrayMesh,
	collision_mesh: ArrayMesh,
	mesh_groups: Dictionary,
	collision_faces: PackedVector3Array,
	skip_material_path: String,
	clip_material_path: String
) -> void:
	if render_mesh == null:
		return
	for surface_index in range(render_mesh.get_surface_count()):
		var arrays := render_mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if src_verts.size() < 3:
			continue
		var src_material := render_mesh.surface_get_material(surface_index)
		var mode := _surface_bake_mode(src_material, skip_material_path, clip_material_path)
		if mode == "skip":
			continue
		if collision_mesh != null and surface_index < collision_mesh.get_surface_count():
			var collision_arrays := collision_mesh.surface_get_arrays(surface_index)
			if not collision_arrays.is_empty():
				var collision_verts: PackedVector3Array = collision_arrays[Mesh.ARRAY_VERTEX]
				if collision_verts.size() >= 3:
					var translated_collision := PackedVector3Array()
					translated_collision.resize(collision_verts.size())
					for ci in range(collision_verts.size()):
						translated_collision[ci] = collision_verts[ci] + brush_position
					collision_faces.append_array(translated_collision)
		if mode != "solid":
			continue
		var translated_verts := PackedVector3Array()
		translated_verts.resize(src_verts.size())
		for i in range(src_verts.size()):
			translated_verts[i] = src_verts[i] + brush_position
		var group_key := _mesh_group_key_for_material(src_material)
		var group: Dictionary = mesh_groups.get(group_key, {})
		if group.is_empty():
			group = {
				"material": src_material,
				"verts": PackedVector3Array(),
				"normals": PackedVector3Array(),
				"uvs": PackedVector2Array(),
				"colors": PackedColorArray(),
			}
		var group_verts: PackedVector3Array = group["verts"]
		group_verts.append_array(translated_verts)
		group["verts"] = group_verts
		var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if src_normals.size() == src_verts.size():
			var group_normals: PackedVector3Array = group["normals"]
			group_normals.append_array(src_normals)
			group["normals"] = group_normals
		var src_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if src_uvs.size() == src_verts.size():
			var group_uvs: PackedVector2Array = group["uvs"]
			group_uvs.append_array(src_uvs)
			group["uvs"] = group_uvs
		var src_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if src_colors.size() == src_verts.size():
			var group_colors: PackedColorArray = group["colors"]
			group_colors.append_array(src_colors)
			group["colors"] = group_colors
		mesh_groups[group_key] = group

static func build_baked_mesh_from_groups(mesh_groups: Dictionary) -> ArrayMesh:
	if mesh_groups.is_empty():
		return ArrayMesh.new()
	var keys := mesh_groups.keys()
	keys.sort()
	var out_mesh := ArrayMesh.new()
	for key in keys:
		var group: Dictionary = mesh_groups.get(key, {})
		if group.is_empty():
			continue
		var verts: PackedVector3Array = group.get("verts", PackedVector3Array())
		if verts.size() < 3:
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		var normals: PackedVector3Array = group.get("normals", PackedVector3Array())
		if normals.size() == verts.size():
			arr[Mesh.ARRAY_NORMAL] = normals
		var uvs: PackedVector2Array = group.get("uvs", PackedVector2Array())
		if uvs.size() == verts.size():
			arr[Mesh.ARRAY_TEX_UV] = uvs
		var colors: PackedColorArray = group.get("colors", PackedColorArray())
		if colors.size() == verts.size():
			arr[Mesh.ARRAY_COLOR] = colors
		out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var surf_idx := out_mesh.get_surface_count() - 1
		var material: Material = group.get("material", null)
		if material != null:
			out_mesh.surface_set_material(surf_idx, material)
	return out_mesh

static func clone_brush_with_no_subdivisions(src: BrushForge) -> BrushForge:
	var copy := BrushForge.create_box(src.position, src.size)
	copy.planes.clear()
	for pp in src.planes:
		var p: NeoPlane = pp as NeoPlane
		if p != null:
			copy.planes.append(NeoPlane.new(p.normal, p.distance))
	copy.face_material_paths = src.face_material_paths.duplicate(true)
	copy.face_uv_transforms = src.face_uv_transforms.duplicate(true)
	copy.face_paint_colors = src.face_paint_colors.duplicate(true)
	copy.face_paint_strokes = src.face_paint_strokes.duplicate(true)
	copy.face_subdivisions = {}
	copy.lock_uvs = src.lock_uvs
	return copy

static func _mesh_group_key_for_material(material: Material) -> String:
	if material == null:
		return "__null_material__"
	var path := material.resource_path
	if path != "":
		return "path:" + path.to_lower()
	return "obj:%d" % material.get_instance_id()

static func _surface_bake_mode(material: Material, skip_material_path: String, clip_material_path: String) -> String:
	if material == null:
		return "solid"
	var mat_path := material.resource_path.to_lower()
	if mat_path == skip_material_path.to_lower():
		return "skip"
	if mat_path == clip_material_path.to_lower():
		return "clip"
	return "solid"
