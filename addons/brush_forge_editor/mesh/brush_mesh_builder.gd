@tool
extends RefCounted
class_name BrushMeshBuilder
static var use_vertex_color_preview := false
const PAINT_MODE_NORMAL := 0
const PAINT_MODE_ADD := 1
const PAINT_MODE_MULTIPLY := 2
const PAINT_MODE_SUBTRACT := 3
const PAINT_MODE_BURN := 4

func build_box_mesh_call(size: Vector3) -> ArrayMesh:
	return build_box_mesh(size)

func build_brush_mesh_call(brush: BrushForge) -> ArrayMesh:
	return build_brush_mesh(brush)

func get_brush_vertices_world_call(brush: BrushForge) -> Array[Vector3]:
	return get_brush_vertices_world(brush)

static func build_box_mesh(size: Vector3) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	box.size = size
	var arrs := box.surface_get_arrays(0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return mesh

static func build_brush_mesh(brush: BrushForge) -> ArrayMesh:
	if brush == null or brush.planes.size() < 4:
		return build_box_mesh(Vector3.ONE)

	var planes: Array = brush.planes
	var vertices := _compute_brush_vertices(planes)
	if vertices.size() < 4:
		return build_box_mesh(brush.size)

	var local_origin := brush.position
	var brush_center := Vector3.ZERO
	for v in vertices:
		brush_center += v
	brush_center /= float(vertices.size())
	var face_surfaces: Array = []
	for face_index in range(planes.size()):
		var plane: NeoPlane = planes[face_index] as NeoPlane
		if plane == null:
			continue
		var face := _collect_face_vertices(plane, vertices)
		if face.size() < 3:
			continue
		var mat_key := ""
		if brush.face_material_paths.has(str(face_index)):
			mat_key = str(brush.face_material_paths[str(face_index)])
		elif brush.face_material_paths.has(str(_face_index_from_normal(plane.normal))):
			# Backward compatibility with older 6-face axis keys.
			mat_key = str(brush.face_material_paths[str(_face_index_from_normal(plane.normal))])
		var face_color: Color = Color.WHITE
		# Stored face fill color is the base layer for both bucket and brush strokes.
		var face_key := str(face_index)
		var face_strokes: Array = brush.face_paint_strokes.get(face_key, [])
		if brush.face_paint_colors.has(face_key):
			face_color = brush.face_paint_colors[str(face_index)]
		var g_verts := PackedVector3Array()
		var g_normals := PackedVector3Array()
		var g_uvs := PackedVector2Array()
		var g_colors := PackedColorArray()
		var uv_basis := _uv_basis_from_normal(plane.normal)
		var u_axis: Vector3 = uv_basis["u"]
		var v_axis: Vector3 = uv_basis["v"]
		var face_uv: Dictionary = brush.face_uv_transforms.get(str(face_index), {})
		if face_uv.is_empty():
			face_uv = brush.face_uv_transforms.get(str(_face_index_from_normal(plane.normal)), {})
		var subdiv := int(brush.face_subdivisions.get(str(face_index), 1))
		subdiv = clampi(subdiv, 1, 10)
		var paint_accel := _build_paint_stroke_accel(face_strokes)
		var ordered := _sort_face_vertices(face, plane.normal)
		for i in range(1, ordered.size() - 1):
			var a: Vector3 = ordered[0]
			var b: Vector3 = ordered[i]
			var c: Vector3 = ordered[i + 1]
			var tri_n := (b - a).cross(c - a).normalized()
			if tri_n.dot(plane.normal) < 0.0:
				var tmp := b
				b = c
				c = tmp
				tri_n = (b - a).cross(c - a).normalized()
			if tri_n.dot(a - brush_center) < 0.0:
				var tmp2 := b
				b = c
				c = tmp2
				tri_n = (b - a).cross(c - a).normalized()
			_emit_subdivided_triangle(
				a, b, c, subdiv, tri_n,
				brush, face_index, face_color, local_origin,
				u_axis, v_axis, face_uv, paint_accel,
				g_verts, g_normals, g_uvs, g_colors
			)
		if g_verts.size() >= 3:
			face_surfaces.append({
				"verts": g_verts,
				"normals": g_normals,
				"uvs": g_uvs,
				"colors": g_colors,
				"material_path": mat_key,
				"face_color": face_color,
			})

	if face_surfaces.size() == 0:
		return build_box_mesh(brush.size)

	var mesh := ArrayMesh.new()
	for gg in face_surfaces:
		var tri_verts: PackedVector3Array = gg["verts"]
		if tri_verts.size() < 3:
			continue
		var tri_normals: PackedVector3Array = gg["normals"]
		var tri_uvs: PackedVector2Array = gg["uvs"]
		var tri_colors: PackedColorArray = gg["colors"]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = tri_verts
		arr[Mesh.ARRAY_NORMAL] = tri_normals
		arr[Mesh.ARRAY_TEX_UV] = tri_uvs
		arr[Mesh.ARRAY_COLOR] = tri_colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var material_path := str(gg.get("material_path", ""))
		var face_color = gg.get("face_color", Color.WHITE)
		if not (face_color is Color):
			face_color = Color.WHITE
		var surf_idx := mesh.get_surface_count() - 1
		if use_vertex_color_preview:
			var preview_mat := StandardMaterial3D.new()
			preview_mat.vertex_color_use_as_albedo = true
			preview_mat.albedo_color = Color.WHITE
			preview_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(surf_idx, preview_mat)
		elif material_path != "":
			var mat_res := load(material_path)
			if mat_res is Material:
				mesh.surface_set_material(surf_idx, mat_res)
	return mesh

static func get_brush_vertices_world(brush: BrushForge) -> Array[Vector3]:
	if brush == null:
		var empty: Array[Vector3] = []
		return empty
	var planes: Array = brush.planes
	return _compute_brush_vertices(planes)

static func _compute_brush_vertices(planes: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var eps := 0.001
	for i in range(planes.size()):
		for j in range(i + 1, planes.size()):
			for k in range(j + 1, planes.size()):
				var p1: NeoPlane = planes[i]
				var p2: NeoPlane = planes[j]
				var p3: NeoPlane = planes[k]
				var v := _intersect_three_planes(p1, p2, p3)
				if v == null:
					continue
				var vv: Vector3 = v
				if not _point_inside_all_planes(vv, planes, eps):
					continue
				var duplicate := false
				for e in out:
					if e.distance_to(vv) < eps:
						duplicate = true
						break
				if not duplicate:
					out.append(vv)
	return out

static func _intersect_three_planes(a: NeoPlane, b: NeoPlane, c: NeoPlane) -> Variant:
	var n1 := a.normal
	var n2 := b.normal
	var n3 := c.normal
	var denom := n1.dot(n2.cross(n3))
	if absf(denom) < 0.00001:
		return null
	var p := (a.distance * n2.cross(n3) + b.distance * n3.cross(n1) + c.distance * n1.cross(n2)) / denom
	return p

static func _point_inside_all_planes(p: Vector3, planes: Array, eps: float) -> bool:
	for pp in planes:
		var pl: NeoPlane = pp
		if pl.normal.dot(p) > pl.distance + eps:
			return false
	return true

static func _collect_face_vertices(plane: NeoPlane, vertices: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var eps := 0.002
	for v in vertices:
		if absf(plane.normal.dot(v) - plane.distance) <= eps:
			out.append(v)
	return out

static func _sort_face_vertices(face: Array[Vector3], normal: Vector3) -> Array[Vector3]:
	if face.size() <= 2:
		return face
	var center := Vector3.ZERO
	for v in face:
		center += v
	center /= float(face.size())

	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := normal.cross(tangent).normalized()

	var pts := []
	for v in face:
		var d := v - center
		var a := atan2(d.dot(bitangent), d.dot(tangent))
		pts.append({"a": a, "v": v})
	pts.sort_custom(func(x, y): return x["a"] < y["a"])

	var out: Array[Vector3] = []
	for p in pts:
		out.append(p["v"])
	return out

static func _face_index_from_normal(normal: Vector3) -> int:
	var n := normal.normalized()
	var d_right := n.dot(Vector3.RIGHT)
	var d_up := n.dot(Vector3.UP)
	var d_back := n.dot(Vector3.BACK)
	var ax := absf(d_right)
	var ay := absf(d_up)
	var az := absf(d_back)
	if ax >= ay and ax >= az:
		return 0 if d_right >= 0.0 else 1
	if ay >= ax and ay >= az:
		return 2 if d_up >= 0.0 else 3
	return 4 if d_back >= 0.0 else 5

static func _uv_basis_from_normal(normal: Vector3) -> Dictionary:
	var n := normal.normalized()
	var tangent := Vector3.RIGHT
	if absf(n.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - n * tangent.dot(n)).normalized()
	var bitangent := n.cross(tangent).normalized()
	return {"u": tangent, "v": bitangent}

static func _compute_uv(p_world: Vector3, brush: BrushForge, u_axis: Vector3, v_axis: Vector3, face_uv: Dictionary) -> Vector2:
	var p := p_world
	# Default is global/world UVs; lock switches to object-space UVs.
	if brush != null and brush.lock_uvs:
		p = p_world - brush.position
	var u := p.dot(u_axis)
	var v := p.dot(v_axis)
	var uv := Vector2(u, v)
	var scale: Vector2 = face_uv.get("scale", Vector2.ONE)
	var offset: Vector2 = face_uv.get("offset", Vector2.ZERO)
	var rotation: float = float(face_uv.get("rotation", 0.0))
	if absf(rotation) > 0.00001:
		uv = uv.rotated(rotation)
	var sx := scale.x if absf(scale.x) > 0.00001 else 1.0
	var sy := scale.y if absf(scale.y) > 0.00001 else 1.0
	uv = Vector2(uv.x / sx, uv.y / sy) + offset
	return uv

static func _emit_subdivided_triangle(
	a: Vector3, b: Vector3, c: Vector3, subdiv: int, tri_n: Vector3,
	brush: BrushForge, face_index: int, base_color: Color, local_origin: Vector3,
	u_axis: Vector3, v_axis: Vector3, face_uv: Dictionary, paint_accel: Dictionary,
	g_verts: PackedVector3Array, g_normals: PackedVector3Array, g_uvs: PackedVector2Array, g_colors: PackedColorArray
) -> void:
	if subdiv <= 1:
		_emit_triangle(a, b, c, tri_n, brush, face_index, base_color, local_origin, u_axis, v_axis, face_uv, paint_accel, g_verts, g_normals, g_uvs, g_colors)
		return
	var n := subdiv
	for i in range(n):
		for j in range(n - i):
			var p0 := _triangle_grid_point(a, b, c, n, i, j)
			var p1 := _triangle_grid_point(a, b, c, n, i + 1, j)
			var p2 := _triangle_grid_point(a, b, c, n, i, j + 1)
			_emit_triangle(p0, p1, p2, tri_n, brush, face_index, base_color, local_origin, u_axis, v_axis, face_uv, paint_accel, g_verts, g_normals, g_uvs, g_colors)
			if i + j < n - 1:
				var p3 := _triangle_grid_point(a, b, c, n, i + 1, j + 1)
				_emit_triangle(p1, p3, p2, tri_n, brush, face_index, base_color, local_origin, u_axis, v_axis, face_uv, paint_accel, g_verts, g_normals, g_uvs, g_colors)

static func _triangle_grid_point(a: Vector3, b: Vector3, c: Vector3, n: int, i: int, j: int) -> Vector3:
	var fi := float(i) / float(n)
	var fj := float(j) / float(n)
	var w := 1.0 - fi - fj
	return a * w + b * fi + c * fj

static func _emit_triangle(
	a: Vector3, b: Vector3, c: Vector3, tri_n: Vector3,
	brush: BrushForge, face_index: int, base_color: Color, local_origin: Vector3,
	u_axis: Vector3, v_axis: Vector3, face_uv: Dictionary, paint_accel: Dictionary,
	g_verts: PackedVector3Array, g_normals: PackedVector3Array, g_uvs: PackedVector2Array, g_colors: PackedColorArray
) -> void:
	# Godot's front-face winding is clockwise, so emit a, c, b.
	g_verts.append(a - local_origin)
	g_verts.append(c - local_origin)
	g_verts.append(b - local_origin)
	g_normals.append(tri_n)
	g_normals.append(tri_n)
	g_normals.append(tri_n)
	g_uvs.append(_compute_uv(a, brush, u_axis, v_axis, face_uv))
	g_uvs.append(_compute_uv(c, brush, u_axis, v_axis, face_uv))
	g_uvs.append(_compute_uv(b, brush, u_axis, v_axis, face_uv))
	# Per-vertex brush evaluation gives smooth blended strokes instead of bucket-like fills.
	g_colors.append(_compute_paint_color(a, base_color, paint_accel))
	g_colors.append(_compute_paint_color(c, base_color, paint_accel))
	g_colors.append(_compute_paint_color(b, base_color, paint_accel))

static func _compute_paint_color(p_world: Vector3, base_color: Color, paint_accel: Dictionary) -> Color:
	var strokes: Array = paint_accel.get("strokes", [])
	if strokes.is_empty():
		return base_color
	var color: Color = base_color
	var candidate_indices: Array = _get_candidate_stroke_indices(paint_accel, p_world)
	var use_candidates := float(paint_accel.get("cell_size", 0.0)) > 0.0
	if use_candidates and candidate_indices.is_empty():
		return color
	# Layer strokes in draw order so paint remains locked in and does not fade to white.
	var count := candidate_indices.size() if use_candidates else strokes.size()
	for i in range(count):
		var stroke_index := int(candidate_indices[i]) if use_candidates else i
		if stroke_index < 0 or stroke_index >= strokes.size():
			continue
		var s = strokes[stroke_index]
		if not (s is Dictionary):
			continue
		var sd: Dictionary = s
		var sp: Vector3 = sd.get("point", p_world)
		var sc = sd.get("color", base_color)
		if not (sc is Color):
			sc = base_color
		var radius: float = maxf(float(sd.get("radius", 0.0)), 0.0001)
		var strength: float = clampf(float(sd.get("strength", 1.0)), 0.0, 1.0)
		var delta: Vector3 = p_world - sp
		var dist_sq := delta.length_squared()
		var radius_sq := radius * radius
		if dist_sq > radius_sq:
			continue
		var d := sqrt(dist_sq)
		var t := 1.0 - d / radius
		var influence: float = clampf(t * t, 0.0, 1.0) * strength
		var mode: int = int(sd.get("mode", PAINT_MODE_NORMAL))
		color = _apply_paint_blend(color, sc, influence, mode)
	return color

static func _build_paint_stroke_accel(strokes: Array) -> Dictionary:
	var out := {
		"strokes": strokes,
		"cell_size": 0.0,
		"grid": {},
	}
	if strokes.size() < 48:
		return out
	var radius_sum := 0.0
	var radius_count := 0
	for s in strokes:
		if not (s is Dictionary):
			continue
		radius_sum += maxf(float((s as Dictionary).get("radius", 0.0)), 0.0001)
		radius_count += 1
	if radius_count == 0:
		return out
	var cell_size := maxf(radius_sum / float(radius_count), 0.05)
	var grid := {}
	for i in range(strokes.size()):
		var s = strokes[i]
		if not (s is Dictionary):
			continue
		var sd: Dictionary = s
		var p: Vector3 = sd.get("point", Vector3.ZERO)
		var r: float = maxf(float(sd.get("radius", 0.0)), 0.0001)
		var min_x := int(floor((p.x - r) / cell_size))
		var min_y := int(floor((p.y - r) / cell_size))
		var min_z := int(floor((p.z - r) / cell_size))
		var max_x := int(floor((p.x + r) / cell_size))
		var max_y := int(floor((p.y + r) / cell_size))
		var max_z := int(floor((p.z + r) / cell_size))
		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				for z in range(min_z, max_z + 1):
					var key := _paint_cell_key(x, y, z)
					var ids: Array = grid.get(key, [])
					ids.append(i)
					grid[key] = ids
	out["cell_size"] = cell_size
	out["grid"] = grid
	return out

static func _get_candidate_stroke_indices(paint_accel: Dictionary, p_world: Vector3) -> Array:
	var cell_size := float(paint_accel.get("cell_size", 0.0))
	if cell_size <= 0.0:
		return []
	var grid: Dictionary = paint_accel.get("grid", {})
	var x := int(floor(p_world.x / cell_size))
	var y := int(floor(p_world.y / cell_size))
	var z := int(floor(p_world.z / cell_size))
	var key := _paint_cell_key(x, y, z)
	return grid.get(key, [])

static func _paint_cell_key(x: int, y: int, z: int) -> String:
	return "%d|%d|%d" % [x, y, z]

static func _apply_paint_blend(dst: Color, src: Color, influence: float, mode: int) -> Color:
	var a: float = clampf(influence, 0.0, 1.0)
	if a <= 0.0:
		return dst
	var blended := src
	match mode:
		PAINT_MODE_ADD:
			blended = Color(
				clampf(dst.r + src.r, 0.0, 1.0),
				clampf(dst.g + src.g, 0.0, 1.0),
				clampf(dst.b + src.b, 0.0, 1.0),
				1.0
			)
		PAINT_MODE_MULTIPLY:
			blended = Color(dst.r * src.r, dst.g * src.g, dst.b * src.b, 1.0)
		PAINT_MODE_SUBTRACT:
			blended = Color(
				clampf(dst.r - src.r, 0.0, 1.0),
				clampf(dst.g - src.g, 0.0, 1.0),
				clampf(dst.b - src.b, 0.0, 1.0),
				1.0
			)
		PAINT_MODE_BURN:
			var br := 1.0 if src.r <= 0.0001 else clampf(1.0 - (1.0 - dst.r) / src.r, 0.0, 1.0)
			var bg := 1.0 if src.g <= 0.0001 else clampf(1.0 - (1.0 - dst.g) / src.g, 0.0, 1.0)
			var bb := 1.0 if src.b <= 0.0001 else clampf(1.0 - (1.0 - dst.b) / src.b, 0.0, 1.0)
			blended = Color(br, bg, bb, 1.0)
		_:
			blended = src
	return Color(
		lerpf(dst.r, blended.r, a),
		lerpf(dst.g, blended.g, a),
		lerpf(dst.b, blended.b, a),
		1.0
	)
