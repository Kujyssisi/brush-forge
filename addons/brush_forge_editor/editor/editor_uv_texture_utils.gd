@tool
extends RefCounted

static func build_uv_preview_texture(face_uv: Dictionary, uv_preview_zoom: float, uv_preview_vertex_mode: bool) -> Texture2D:
	var w := 192
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var scale: Vector2 = face_uv.get("scale", Vector2.ONE)
	var offset: Vector2 = face_uv.get("offset", Vector2.ZERO)
	var rotation: float = float(face_uv.get("rotation", 0.0))
	var sx := scale.x if absf(scale.x) > 0.00001 else 1.0
	var sy := scale.y if absf(scale.y) > 0.00001 else 1.0
	var tiles := 8.0 / maxf(uv_preview_zoom, 0.0001)
	for y in range(h):
		for x in range(w):
			var uv := Vector2(float(x) / float(w), float(y) / float(h))
			var p := (uv - Vector2(0.5, 0.5)) * tiles
			var q := p.rotated(-rotation)
			q = Vector2(q.x * sx, q.y * sy) + offset
			var cx := int(floor(q.x))
			var cy := int(floor(q.y))
			var is_dark := ((cx + cy) & 1) == 0
			var fx: float = q.x - floor(q.x)
			var fy: float = q.y - floor(q.y)
			var c := Color(0.20, 0.20, 0.20, 1.0) if is_dark else Color(0.32, 0.32, 0.32, 1.0)
			if uv_preview_vertex_mode:
				c = Color(fx, fy, 1.0 - fx, 1.0)
			elif absf(fx - 0.5) < 0.03 or absf(fy - 0.5) < 0.03:
				c = Color(0.60, 0.60, 0.60, 1.0)
			img.set_pixel(x, y, c)
	var mid_y := int(h / 2)
	var mid_x := int(w / 2)
	for x_axis in range(w):
		img.set_pixel(x_axis, mid_y, Color(1.0, 0.2, 0.2, 1.0))
	for y_axis in range(h):
		img.set_pixel(mid_x, y_axis, Color(0.2, 0.8, 1.0, 1.0))
	return ImageTexture.create_from_image(img)

static func collect_material_paths_recursive(root_folder: String) -> Array[String]:
	var out: Array[String] = []
	var stack: Array[String] = [root_folder]
	while not stack.is_empty():
		var current: String = str(stack.pop_back())
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var name := dir.get_next()
			if name == "":
				break
			if name == "." or name == "..":
				continue
			var path: String = current.path_join(name)
			if dir.current_is_dir():
				stack.append(path)
				continue
			var lower := name.to_lower()
			if lower.ends_with(".tres") or lower.ends_with(".res"):
				out.append(path)
		dir.list_dir_end()
	out.sort()
	return out

static func get_material_preview_texture(
	material_path: String,
	mat: Material,
	texture_preview_cache: Dictionary,
	editor_interface: EditorInterface
) -> Texture2D:
	if texture_preview_cache.has(material_path):
		var cached = texture_preview_cache[material_path]
		if cached is Texture2D:
			return cached as Texture2D
	var fallback: Texture2D = editor_interface.get_base_control().get_theme_icon("Material", "EditorIcons")
	var preview := fallback
	if editor_interface != null and editor_interface.has_method("make_mesh_previews"):
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.0, 1.0)
		plane.material = mat
		var meshes: Array = [plane]
		var previews = editor_interface.call("make_mesh_previews", meshes, 64)
		if previews is Array and previews.size() > 0:
			var tex = previews[0]
			if tex is Texture2D:
				preview = tex as Texture2D
	texture_preview_cache[material_path] = preview
	return preview

static func adjust_brush_uv_offsets_for_lock_toggle(brush: BrushForge, enabling_lock: bool) -> void:
	if brush == null:
		return
	var keys := {}
	for k in brush.face_uv_transforms.keys():
		keys[k] = true
	for k in brush.face_material_paths.keys():
		keys[k] = true
	for i in range(6):
		keys[str(i)] = true
	for key in keys.keys():
		var face_index := int(str(key))
		if face_index < 0 or face_index > 5:
			continue
		var uv_basis := _uv_basis_from_face_index(face_index)
		var u_axis: Vector3 = uv_basis["u"]
		var v_axis: Vector3 = uv_basis["v"]
		var shift := Vector2(brush.position.dot(u_axis), brush.position.dot(v_axis))
		var existing = brush.face_uv_transforms.get(str(face_index), {})
		var face_uv: Dictionary = {}
		if existing is Dictionary:
			face_uv = (existing as Dictionary).duplicate(true)
		var scale: Vector2 = face_uv.get("scale", Vector2.ONE)
		var rotation: float = float(face_uv.get("rotation", 0.0))
		var offset: Vector2 = face_uv.get("offset", Vector2.ZERO)
		var sx := scale.x if absf(scale.x) > 0.00001 else 1.0
		var sy := scale.y if absf(scale.y) > 0.00001 else 1.0
		var rotated_shift := shift.rotated(rotation)
		var transformed_shift := Vector2(rotated_shift.x / sx, rotated_shift.y / sy)
		if enabling_lock:
			offset += transformed_shift
		else:
			offset -= transformed_shift
		face_uv["offset"] = offset
		face_uv["scale"] = scale
		face_uv["rotation"] = rotation
		brush.face_uv_transforms[str(face_index)] = face_uv

static func _uv_basis_from_face_index(face_index: int) -> Dictionary:
	var normal := Vector3.UP
	match face_index:
		0:
			normal = Vector3.RIGHT
		1:
			normal = Vector3.LEFT
		2:
			normal = Vector3.UP
		3:
			normal = Vector3.DOWN
		4:
			normal = Vector3.BACK
		5:
			normal = Vector3.FORWARD
	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := normal.cross(tangent).normalized()
	return {"u": tangent, "v": bitangent}
