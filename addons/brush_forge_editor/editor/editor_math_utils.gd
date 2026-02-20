@tool
extends RefCounted

static func uv_basis_from_face_index(face_index: int) -> Dictionary:
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

static func face_basis_from_index(face_index: int) -> Dictionary:
	match face_index:
		0:
			return {"normal": Vector3.RIGHT, "u": Vector3.FORWARD, "v": Vector3.UP}
		1:
			return {"normal": Vector3.LEFT, "u": Vector3.BACK, "v": Vector3.UP}
		2:
			return {"normal": Vector3.UP, "u": Vector3.RIGHT, "v": Vector3.BACK}
		3:
			return {"normal": Vector3.DOWN, "u": Vector3.RIGHT, "v": Vector3.FORWARD}
		4:
			return {"normal": Vector3.BACK, "u": Vector3.RIGHT, "v": Vector3.UP}
		5:
			return {"normal": Vector3.FORWARD, "u": Vector3.LEFT, "v": Vector3.UP}
	return {"normal": Vector3.UP, "u": Vector3.RIGHT, "v": Vector3.FORWARD}

static func ray_plane_hit_normal(camera: Camera3D, mouse_pos: Vector2, plane_origin: Vector3, plane_normal: Vector3) -> Variant:
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var denom := dir.dot(plane_normal)
	if absf(denom) < 0.0001:
		return null
	var t := (plane_origin - origin).dot(plane_normal) / denom
	if t < 0.0:
		return null
	return origin + dir * t

static func ray_plane_hit_y(camera: Camera3D, mouse_pos: Vector2, plane_y: float) -> Variant:
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var denom := dir.dot(Vector3.UP)
	if absf(denom) < 0.0001:
		return null
	var t := (plane_y - origin.y) / denom
	if t < 0.0:
		return null
	return Vector3(
		origin.x + dir.x * t,
		plane_y,
		origin.z + dir.z * t
	)

static func snap_float(value: float, step: float) -> float:
	if step <= 0.000001:
		return value
	return round(value / step) * step

static func snap_vector(v: Vector3, step: float) -> Vector3:
	return Vector3(snap_float(v.x, step), snap_float(v.y, step), snap_float(v.z, step))

static func world_units_per_pixel_at(camera: Camera3D, world_pos: Vector3) -> float:
	var viewport := camera.get_viewport()
	if viewport == null:
		return 0.01
	var viewport_h := viewport.get_visible_rect().size.y
	if viewport_h <= 1.0:
		return 0.01
	var dist := camera.global_position.distance_to(world_pos)
	var fov_rad := deg_to_rad(camera.fov)
	return maxf((2.0 * dist * tan(fov_rad * 0.5)) / viewport_h, 0.0001)

static func axis_delta_from_mouse(camera: Camera3D, world_origin: Vector3, axis: Vector3, mouse_pos: Vector2, drag_start_mouse: Vector2) -> float:
	var screen_origin := camera.unproject_position(world_origin)
	var screen_axis_tip := camera.unproject_position(world_origin + axis)
	var axis_screen := screen_axis_tip - screen_origin
	var axis_len := axis_screen.length()
	if axis_len < 0.0001:
		return 0.0
	var axis_dir := axis_screen / axis_len
	var mouse_delta := mouse_pos - drag_start_mouse
	var pixels_along_axis := mouse_delta.dot(axis_dir)
	return pixels_along_axis / axis_len

static func is_blocked_editor_transform_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_W \
		or event.keycode == KEY_E \
		or event.keycode == KEY_R \
		or event.keycode == KEY_T \
		or event.keycode == KEY_G

static func is_arrow_key(keycode: int) -> bool:
	return keycode == KEY_LEFT or keycode == KEY_RIGHT or keycode == KEY_UP or keycode == KEY_DOWN
