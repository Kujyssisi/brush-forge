@tool
extends RefCounted

static func build_polyline_mesh(points: Array, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	for p in points:
		verts.append(p)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func build_wire_sphere_mesh(center: Vector3, radius: float, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 32
	for i in range(steps):
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		verts.append(center + Vector3(cos(a0), sin(a0), 0.0) * radius)
		verts.append(center + Vector3(cos(a1), sin(a1), 0.0) * radius)
		verts.append(center + Vector3(cos(a0), 0.0, sin(a0)) * radius)
		verts.append(center + Vector3(cos(a1), 0.0, sin(a1)) * radius)
		verts.append(center + Vector3(0.0, cos(a0), sin(a0)) * radius)
		verts.append(center + Vector3(0.0, cos(a1), sin(a1)) * radius)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func build_wire_box_mesh(center: Vector3, half_size: Vector3, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	_append_wire_box_edges(verts, center, half_size)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func build_multi_wire_box_mesh(centers: Array[Vector3], half_sizes: Array[Vector3], material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var count := mini(centers.size(), half_sizes.size())
	for i in range(count):
		_append_wire_box_edges(verts, centers[i], half_sizes[i])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func build_face_grid_mesh(corners: Array[Vector3], subdiv_x: int, subdiv_y: int, material: Material) -> ArrayMesh:
	if corners.size() < 3:
		return ArrayMesh.new()
	if corners.size() > 24:
		# Guardrail for heavily subdivided/coplanar vertex sets that can freeze the editor.
		return ArrayMesh.new()
	var verts := PackedVector3Array()
	var sx := max(1, subdiv_x)
	var sy := max(1, subdiv_y)
	if sx <= 1 and sy <= 1:
		return ArrayMesh.new()
	var origin: Vector3 = corners[0]
	var normal := Vector3.ZERO
	for i in range(corners.size()):
		var p0: Vector3 = corners[i]
		var p1: Vector3 = corners[(i + 1) % corners.size()]
		normal += p0.cross(p1)
	if normal.length_squared() <= 0.0000001:
		normal = (corners[1] - corners[0]).cross(corners[2] - corners[0])
	if normal.length_squared() <= 0.0000001:
		return ArrayMesh.new()
	normal = normal.normalized()
	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := normal.cross(tangent).normalized()
	var poly_uv: Array[Vector2] = []
	for p in corners:
		poly_uv.append(Vector2((p - origin).dot(tangent), (p - origin).dot(bitangent)))
	if _polygon_area_signed_2d(poly_uv) < 0.0:
		poly_uv.reverse()
	var bounds := _polygon_bounds_2d(poly_uv)
	var min_u := float(bounds["min_u"])
	var max_u := float(bounds["max_u"])
	var min_v := float(bounds["min_v"])
	var max_v := float(bounds["max_v"])
	var du := max_u - min_u
	var dv := max_v - min_v
	if du <= 0.000001 or dv <= 0.000001:
		return ArrayMesh.new()
	var truncated := false
	var segment_budget := 4096
	var segment_count := 0
	for ix in range(sx):
		if truncated:
			break
		var u0 := min_u + du * float(ix) / float(sx)
		var u1 := min_u + du * float(ix + 1) / float(sx)
		for iy in range(sy):
			if truncated:
				break
			var v0 := min_v + dv * float(iy) / float(sy)
			var v1 := min_v + dv * float(iy + 1) / float(sy)
			var rect: Array[Vector2] = [
				Vector2(u0, v0),
				Vector2(u1, v0),
				Vector2(u1, v1),
				Vector2(u0, v1),
			]
			var clipped := _clip_polygon_convex_2d(rect, poly_uv)
			if clipped.size() < 3:
				continue
			for i in range(clipped.size()):
				var a2: Vector2 = clipped[i]
				var b2: Vector2 = clipped[(i + 1) % clipped.size()]
				var a3 := origin + tangent * a2.x + bitangent * a2.y
				var b3 := origin + tangent * b2.x + bitangent * b2.y
				_append_line_segment(verts, a3, b3)
				segment_count += 1
				if segment_count >= segment_budget:
					truncated = true
					break
	if verts.is_empty():
		return ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func _append_wire_box_edges(verts: PackedVector3Array, center: Vector3, half_size: Vector3) -> void:
	var c := [
		center + Vector3(-half_size.x, -half_size.y, -half_size.z),
		center + Vector3(half_size.x, -half_size.y, -half_size.z),
		center + Vector3(half_size.x, half_size.y, -half_size.z),
		center + Vector3(-half_size.x, half_size.y, -half_size.z),
		center + Vector3(-half_size.x, -half_size.y, half_size.z),
		center + Vector3(half_size.x, -half_size.y, half_size.z),
		center + Vector3(half_size.x, half_size.y, half_size.z),
		center + Vector3(-half_size.x, half_size.y, half_size.z),
	]
	var edges := PackedInt32Array([
		0, 1, 1, 2, 2, 3, 3, 0,
		4, 5, 5, 6, 6, 7, 7, 4,
		0, 4, 1, 5, 2, 6, 3, 7,
	])
	for i in edges:
		verts.append(c[i])

static func _polygon_bounds_2d(poly: Array[Vector2]) -> Dictionary:
	var min_u := INF
	var min_v := INF
	var max_u := -INF
	var max_v := -INF
	for p in poly:
		min_u = minf(min_u, p.x)
		min_v = minf(min_v, p.y)
		max_u = maxf(max_u, p.x)
		max_v = maxf(max_v, p.y)
	return {"min_u": min_u, "min_v": min_v, "max_u": max_u, "max_v": max_v}

static func _polygon_area_signed_2d(poly: Array[Vector2]) -> float:
	if poly.size() < 3:
		return 0.0
	var acc := 0.0
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		acc += a.x * b.y - a.y * b.x
	return acc * 0.5

static func _clip_polygon_convex_2d(subject: Array[Vector2], clipper: Array[Vector2]) -> Array[Vector2]:
	var output := subject.duplicate()
	if output.size() < 3 or clipper.size() < 3:
		var empty: Array[Vector2] = []
		return empty
	for i in range(clipper.size()):
		var cp1: Vector2 = clipper[i]
		var cp2: Vector2 = clipper[(i + 1) % clipper.size()]
		var input := output.duplicate()
		output.clear()
		if input.is_empty():
			break
		var s: Vector2 = input[input.size() - 1]
		for e in input:
			var e_inside := _is_inside_half_plane_2d(cp1, cp2, e)
			var s_inside := _is_inside_half_plane_2d(cp1, cp2, s)
			if e_inside:
				if not s_inside:
					output.append(_line_intersection_2d(cp1, cp2, s, e))
				output.append(e)
			elif s_inside:
				output.append(_line_intersection_2d(cp1, cp2, s, e))
			s = e
	return _dedupe_polygon_points_2d(output)

static func _is_inside_half_plane_2d(a: Vector2, b: Vector2, p: Vector2) -> bool:
	return _cross_2d_vec2(b - a, p - a) >= -0.00001

static func _line_intersection_2d(a: Vector2, b: Vector2, p: Vector2, q: Vector2) -> Vector2:
	var r := b - a
	var s := q - p
	var denom := _cross_2d_vec2(r, s)
	if absf(denom) < 0.0000001:
		return q
	var t := _cross_2d_vec2(p - a, s) / denom
	return a + r * t

static func _cross_2d_vec2(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x

static func _dedupe_polygon_points_2d(poly: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in poly:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.00001:
			out.append(p)
	if out.size() >= 2 and out[0].distance_to(out[out.size() - 1]) <= 0.00001:
		out.remove_at(out.size() - 1)
	return out

static func _append_line_segment(verts: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	verts.append(a)
	verts.append(b)
