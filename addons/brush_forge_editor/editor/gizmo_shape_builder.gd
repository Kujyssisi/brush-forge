@tool
extends RefCounted

static func build_vertex_markers_mesh(points: Array[Vector3], half_extent: float, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var h := Vector3.ONE * maxf(half_extent, 0.01)
	for p in points:
		var c := [
			p + Vector3(-h.x, -h.y, -h.z),
			p + Vector3(h.x, -h.y, -h.z),
			p + Vector3(h.x, h.y, -h.z),
			p + Vector3(-h.x, h.y, -h.z),
			p + Vector3(-h.x, -h.y, h.z),
			p + Vector3(h.x, -h.y, h.z),
			p + Vector3(h.x, h.y, h.z),
			p + Vector3(-h.x, h.y, h.z),
		]
		var edges := PackedInt32Array([
			0, 1, 1, 2, 2, 3, 3, 0,
			4, 5, 5, 6, 6, 7, 7, 4,
			0, 4, 1, 5, 2, 6, 3, 7,
		])
		for ei in edges:
			verts.append(c[ei])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func build_rotate_rings_mesh(
	center: Vector3,
	radius: float,
	active_axis: Vector3,
	rotate_x_material: Material,
	rotate_y_material: Material,
	rotate_z_material: Material,
	rotate_active_material: Material
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var ring_defs := [
		{"axis": Vector3.RIGHT, "material": rotate_x_material},
		{"axis": Vector3.UP, "material": rotate_y_material},
		{"axis": Vector3.BACK, "material": rotate_z_material},
	]
	for ring in ring_defs:
		var verts := PackedVector3Array()
		var axis: Vector3 = ring["axis"]
		var material: Material = ring["material"]
		if active_axis.length() > 0.0 and axis.dot(active_axis.normalized()) > 0.99:
			material = rotate_active_material
		# Draw three concentric line rings to make handles visually thicker/easier to grab.
		_append_ring_segments(verts, center, axis, radius * 0.965, 56)
		_append_ring_segments(verts, center, axis, radius, 56)
		_append_ring_segments(verts, center, axis, radius * 1.035, 56)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
		var surface_idx := mesh.get_surface_count() - 1
		mesh.surface_set_material(surface_idx, material)
	return mesh

static func build_edges_wire_mesh(vertices: Array[Vector3], edges: Array, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	for e in edges:
		var ai := int(e.get("a", -1))
		var bi := int(e.get("b", -1))
		if ai < 0 or bi < 0 or ai >= vertices.size() or bi >= vertices.size():
			continue
		verts.append(vertices[ai])
		verts.append(vertices[bi])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func build_polygon_wire_mesh(points: Array[Vector3], material: Material) -> ArrayMesh:
	if points.size() < 3:
		return ArrayMesh.new()
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var normal := Vector3.ZERO
	for i in range(points.size()):
		var a := points[i] - center
		var b := points[(i + 1) % points.size()] - center
		normal += a.cross(b)
	if normal.length() < 0.0001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := normal.cross(tangent).normalized()
	var ordered := []
	for p in points:
		var d := p - center
		var ang := atan2(d.dot(bitangent), d.dot(tangent))
		ordered.append({"a": ang, "p": p})
	ordered.sort_custom(func(x, y): return x["a"] < y["a"])
	var verts := PackedVector3Array()
	for i in range(ordered.size()):
		var p0: Vector3 = ordered[i]["p"]
		var p1: Vector3 = ordered[(i + 1) % ordered.size()]["p"]
		verts.append(p0)
		verts.append(p1)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func mesh_bounds_world(mesh: MeshInstance3D) -> Dictionary:
	if mesh == null or mesh.mesh == null:
		var c := mesh.global_position if mesh != null else Vector3.ZERO
		return {"min": c, "max": c, "center": c, "half_size": Vector3.ONE * 0.5}
	var aabb := mesh.mesh.get_aabb()
	var minp := mesh.global_position + aabb.position
	var maxp := minp + aabb.size
	var center := (minp + maxp) * 0.5
	var half := (maxp - minp) * 0.5
	return {"min": minp, "max": maxp, "center": center, "half_size": half}

static func build_face_wire_mesh_from_corners(corners: Array[Vector3], material: Material) -> ArrayMesh:
	if corners.size() < 3:
		return ArrayMesh.new()
	var verts := PackedVector3Array()
	for i in range(corners.size()):
		var p0: Vector3 = corners[i]
		var p1: Vector3 = corners[(i + 1) % corners.size()]
		verts.append(p0)
		verts.append(p1)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

static func compute_brush_face_hull(vertices: Array[Vector3], plane_normal: Vector3, plane_distance: float, eps: float = 0.02) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var face_vertices: Array[Vector3] = []
	for v in vertices:
		if absf(plane_normal.dot(v) - plane_distance) <= eps:
			face_vertices.append(v)
	if face_vertices.size() < 3:
		return out
	var tangent := Vector3.RIGHT
	if absf(plane_normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - plane_normal * tangent.dot(plane_normal)).normalized()
	var bitangent := plane_normal.cross(tangent).normalized()
	var unique_projected := []
	var seen := {}
	for v in face_vertices:
		var key := "%d|%d|%d" % [int(round(v.x * 1000.0)), int(round(v.y * 1000.0)), int(round(v.z * 1000.0))]
		if seen.has(key):
			continue
		seen[key] = true
		var uv := Vector2(v.dot(tangent), v.dot(bitangent))
		unique_projected.append({"uv": uv, "v": v})
	if unique_projected.size() < 3:
		return out
	unique_projected.sort_custom(func(a, b):
		var auv: Vector2 = a["uv"]
		var buv: Vector2 = b["uv"]
		if absf(auv.x - buv.x) <= 0.000001:
			return auv.y < buv.y
		return auv.x < buv.x
	)
	var lower := []
	for item in unique_projected:
		while lower.size() >= 2:
			var a: Vector2 = lower[lower.size() - 2]["uv"]
			var b: Vector2 = lower[lower.size() - 1]["uv"]
			var c: Vector2 = item["uv"]
			if _cross_2d_vec2(b - a, c - b) <= 0.000001:
				lower.pop_back()
			else:
				break
		lower.append(item)
	var upper := []
	for i in range(unique_projected.size() - 1, -1, -1):
		var item = unique_projected[i]
		while upper.size() >= 2:
			var a: Vector2 = upper[upper.size() - 2]["uv"]
			var b: Vector2 = upper[upper.size() - 1]["uv"]
			var c: Vector2 = item["uv"]
			if _cross_2d_vec2(b - a, c - b) <= 0.000001:
				upper.pop_back()
			else:
				break
		upper.append(item)
	for i in range(maxi(lower.size() - 1, 0)):
		out.append(lower[i]["v"])
	for i in range(maxi(upper.size() - 1, 0)):
		out.append(upper[i]["v"])
	return out

static func get_box_face_corners(center: Vector3, half_size: Vector3, face_index: int) -> Array[Vector3]:
	var hx := half_size.x
	var hy := half_size.y
	var hz := half_size.z
	match face_index:
		0:
			return [
				center + Vector3(hx, -hy, -hz),
				center + Vector3(hx, hy, -hz),
				center + Vector3(hx, hy, hz),
				center + Vector3(hx, -hy, hz),
			]
		1:
			return [
				center + Vector3(-hx, -hy, hz),
				center + Vector3(-hx, hy, hz),
				center + Vector3(-hx, hy, -hz),
				center + Vector3(-hx, -hy, -hz),
			]
		2:
			return [
				center + Vector3(-hx, hy, -hz),
				center + Vector3(hx, hy, -hz),
				center + Vector3(hx, hy, hz),
				center + Vector3(-hx, hy, hz),
			]
		3:
			return [
				center + Vector3(-hx, -hy, hz),
				center + Vector3(hx, -hy, hz),
				center + Vector3(hx, -hy, -hz),
				center + Vector3(-hx, -hy, -hz),
			]
		4:
			return [
				center + Vector3(-hx, -hy, hz),
				center + Vector3(-hx, hy, hz),
				center + Vector3(hx, hy, hz),
				center + Vector3(hx, -hy, hz),
			]
		5:
			return [
				center + Vector3(hx, -hy, -hz),
				center + Vector3(hx, hy, -hz),
				center + Vector3(-hx, hy, -hz),
				center + Vector3(-hx, -hy, -hz),
			]
	var empty: Array[Vector3] = []
	return empty

static func _append_ring_segments(verts: PackedVector3Array, center: Vector3, normal: Vector3, radius: float, segments: int) -> void:
	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := normal.cross(tangent).normalized()
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := center + (tangent * cos(a0) + bitangent * sin(a0)) * radius
		var p1 := center + (tangent * cos(a1) + bitangent * sin(a1)) * radius
		verts.append(p0)
		verts.append(p1)

static func _cross_2d_vec2(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x
