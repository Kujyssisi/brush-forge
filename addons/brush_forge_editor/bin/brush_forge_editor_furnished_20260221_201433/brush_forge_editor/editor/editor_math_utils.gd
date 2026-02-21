@tool
extends RefCounted
const EDITOR_STATE_NATIVE_BRIDGE_SCRIPT = preload("res://addons/brush_forge_editor/editor/editor_state_native_bridge.gd")
static var _native_error_once: Dictionary = {}

static func uv_basis_from_face_index(face_index: int) -> Dictionary:
	var native_basis = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.uv_basis_from_face_index(face_index)
	if native_basis is Dictionary:
		return native_basis
	_report_native_error_once("uv_basis_from_face_index")
	return {"u": Vector3.RIGHT, "v": Vector3.BACK}

static func face_basis_from_index(face_index: int) -> Dictionary:
	var native_basis = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.face_basis_from_index(face_index)
	if native_basis is Dictionary:
		return native_basis
	_report_native_error_once("face_basis_from_index")
	return {"normal": Vector3.UP, "u": Vector3.RIGHT, "v": Vector3.FORWARD}

static func ray_plane_hit_normal(camera: Camera3D, mouse_pos: Vector2, plane_origin: Vector3, plane_normal: Vector3) -> Variant:
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var hit = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.ray_plane_hit_normal(origin, dir, plane_origin, plane_normal)
	if hit is Vector3:
		return hit
	if hit == null:
		return null
	_report_native_error_once("ray_plane_hit_normal")
	return null

static func ray_plane_hit_y(camera: Camera3D, mouse_pos: Vector2, plane_y: float) -> Variant:
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var hit = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.ray_plane_hit_y(origin, dir, plane_y)
	if hit is Vector3:
		return hit
	if hit == null:
		return null
	_report_native_error_once("ray_plane_hit_y")
	return null

static func snap_float(value: float, step: float) -> float:
	var snapped = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.snap_float(value, step)
	if snapped is float:
		return snapped
	if snapped is int:
		return float(snapped)
	_report_native_error_once("snap_float")
	return value

static func snap_vector(v: Vector3, step: float) -> Vector3:
	var snapped = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.snap_vector(v, step)
	if snapped is Vector3:
		return snapped
	_report_native_error_once("snap_vector")
	return v

static func world_units_per_pixel_at(camera: Camera3D, world_pos: Vector3) -> float:
	var viewport := camera.get_viewport()
	if viewport == null:
		return 0.01
	var viewport_h := viewport.get_visible_rect().size.y
	if viewport_h <= 1.0:
		return 0.01
	var dist := camera.global_position.distance_to(world_pos)
	var units = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.world_units_per_pixel_at(dist, camera.fov, viewport_h)
	if units is float:
		return units
	if units is int:
		return float(units)
	_report_native_error_once("world_units_per_pixel_at")
	return 0.01

static func axis_delta_from_mouse(camera: Camera3D, world_origin: Vector3, axis: Vector3, mouse_pos: Vector2, drag_start_mouse: Vector2) -> float:
	var screen_origin := camera.unproject_position(world_origin)
	var screen_axis_tip := camera.unproject_position(world_origin + axis)
	var delta = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.axis_delta_from_screen(screen_origin, screen_axis_tip, mouse_pos, drag_start_mouse)
	if delta is float:
		return delta
	if delta is int:
		return float(delta)
	_report_native_error_once("axis_delta_from_screen")
	return 0.0

static func is_blocked_editor_transform_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_W \
		or event.keycode == KEY_E \
		or event.keycode == KEY_R \
		or event.keycode == KEY_T \
		or event.keycode == KEY_G

static func is_arrow_key(keycode: int) -> bool:
	return keycode == KEY_LEFT or keycode == KEY_RIGHT or keycode == KEY_UP or keycode == KEY_DOWN

static func _report_native_error_once(method_name: String) -> void:
	if _native_error_once.has(method_name):
		return
	_native_error_once[method_name] = true
	push_error("[BrushForgeNative] editor_math_utils.%s failed" % method_name)
