@tool
extends RefCounted

static func pick_exact_face_on_brush(map_node: BrushForgeMap, brush_index: int, camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	if map_node == null:
		return {}
	if brush_index < 0 or brush_index >= map_node.brush_data.size():
		return {}
	var brush: BrushForge = map_node.brush_data[brush_index] as BrushForge
	if brush == null:
		return {}
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos).normalized()
	var best_t: float = INF
	var best_face_index: int = -1
	var best_hit: Vector3 = Vector3.ZERO
	var planes: Array = brush.planes
	for i in range(planes.size()):
		var plane: NeoPlane = planes[i] as NeoPlane
		if plane == null:
			continue
		var denom: float = plane.normal.dot(dir)
		if absf(denom) < 0.00001:
			continue
		var t: float = (plane.distance - plane.normal.dot(origin)) / denom
		if t < 0.0:
			continue
		var hit: Vector3 = origin + dir * t
		if not _point_inside_brush_planes(hit, planes, 0.005):
			continue
		if t < best_t:
			best_t = t
			best_face_index = i
			best_hit = hit
	if best_face_index < 0:
		return {}
	return {
		"face_index": best_face_index,
		"hit": best_hit,
		"t": best_t,
	}

static func _point_inside_brush_planes(point: Vector3, planes: Array, eps: float) -> bool:
	for p in planes:
		var plane: NeoPlane = p as NeoPlane
		if plane == null:
			continue
		if plane.normal.dot(point) > plane.distance + eps:
			return false
	return true
