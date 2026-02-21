@tool
extends RefCounted
class_name EditorStateNativeBridge

const NATIVE_CLASS_NAME := "BrushForgeNative"
const NATIVE_EXTENSION_PATH := "res://addons/brush_forge_editor/native/brush_forge_native/brush_forge_native.gdextension"

static var _availability_checked := false
static var _native_available := false
static var _extension_resource: Resource
static var _native_instance: Object
static var _native_error_once: Dictionary = {}

static func is_available() -> bool:
	if not _availability_checked:
		if ResourceLoader.exists(NATIVE_EXTENSION_PATH):
			_extension_resource = load(NATIVE_EXTENSION_PATH)
		_native_available = ClassDB.class_exists(NATIVE_CLASS_NAME)
		_availability_checked = true
	return _native_available

static func states_equal(a: Array, b: Array) -> Variant:
	return _call_native("states_equal", [a, b])

static func structure_states_equal(a: Array, b: Array) -> Variant:
	return _call_native("structure_states_equal", [a, b])

static func clone_state(state: Array) -> Variant:
	return _call_native("clone_state", [state])

static func build_candidate_edges(
	plane_normals: PackedVector3Array,
	plane_distances: PackedFloat32Array,
	vertices_world: PackedVector3Array,
	epsilon: float = 0.02,
	min_incident: int = 3
) -> Variant:
	return _call_native(
		"build_candidate_edges",
		[plane_normals, plane_distances, vertices_world, epsilon, min_incident]
	)

static func face_vertex_indices(
	plane_normals: PackedVector3Array,
	plane_distances: PackedFloat32Array,
	vertices_world: PackedVector3Array,
	face_index: int,
	epsilon: float = 0.02
) -> Variant:
	return _call_native(
		"face_vertex_indices",
		[plane_normals, plane_distances, vertices_world, face_index, epsilon]
	)

static func nearest_vertex_index(vertices_world: PackedVector3Array, point: Vector3) -> Variant:
	return _call_native("nearest_vertex_index", [vertices_world, point])

static func incident_plane_indices_for_vertex(
	plane_normals: PackedVector3Array,
	plane_distances: PackedFloat32Array,
	vertex: Vector3,
	epsilon: float = 0.02,
	min_incident: int = 3
) -> Variant:
	return _call_native(
		"incident_plane_indices_for_vertex",
		[plane_normals, plane_distances, vertex, epsilon, min_incident]
	)

static func best_fit_plane_indices(
	plane_normals: PackedVector3Array,
	plane_distances: PackedFloat32Array,
	vertices_world: PackedVector3Array,
	target_count: int = 3
) -> Variant:
	return _call_native("best_fit_plane_indices", [plane_normals, plane_distances, vertices_world, target_count])

static func build_plane_vertex_incidence(
	plane_normals: PackedVector3Array,
	plane_distances: PackedFloat32Array,
	vertices_world: PackedVector3Array,
	epsilon: float = 0.02
) -> Variant:
	return _call_native(
		"build_plane_vertex_incidence",
		[plane_normals, plane_distances, vertices_world, epsilon]
	)

static func resolve_drag_plane_indices(
	plane_normals: PackedVector3Array,
	plane_distances: PackedFloat32Array,
	selected_vertices_world: PackedVector3Array,
	target_count: int = 3,
	epsilon: float = 0.02,
	min_incident: int = 3
) -> Variant:
	return _call_native(
		"resolve_drag_plane_indices",
		[plane_normals, plane_distances, selected_vertices_world, target_count, epsilon, min_incident]
	)

static func pick_vertex_screen(
	screen_positions: PackedVector2Array,
	mouse_pos: Vector2,
	threshold: float = 16.0
) -> Variant:
	return _call_native("pick_vertex_screen", [screen_positions, mouse_pos, threshold])

static func pick_edge_screen(
	screen_positions: PackedVector2Array,
	edges: Array,
	mouse_pos: Vector2,
	threshold: float = 14.0
) -> Variant:
	return _call_native("pick_edge_screen", [screen_positions, edges, mouse_pos, threshold])

static func fit_plane_from_points(points: PackedVector3Array, reference_normal: Vector3) -> Variant:
	return _call_native("fit_plane_from_points", [points, reference_normal])

static func face_center(
	plane_normals: PackedVector3Array,
	plane_distances: PackedFloat32Array,
	vertices_world: PackedVector3Array,
	face_index: int,
	epsilon: float = 0.02
) -> Variant:
	return _call_native("face_center", [plane_normals, plane_distances, vertices_world, face_index, epsilon])

static func align_copied_uv_transform(
	src_basis: Dictionary,
	dst_basis: Dictionary,
	src_uv: Dictionary,
	anchor_world: Vector3
) -> Variant:
	return _call_native("align_copied_uv_transform", [src_basis, dst_basis, src_uv, anchor_world])

static func compute_bounds_from_vertices(vertices_world: PackedVector3Array, min_extent: float = 0.001) -> Variant:
	return _call_native("compute_bounds_from_vertices", [vertices_world, min_extent])

static func uv_basis_from_face_index(face_index: int) -> Variant:
	return _call_native("uv_basis_from_face_index", [face_index])

static func face_basis_from_index(face_index: int) -> Variant:
	return _call_native("face_basis_from_index", [face_index])

static func ray_plane_hit_normal(
	ray_origin: Vector3,
	ray_dir: Vector3,
	plane_origin: Vector3,
	plane_normal: Vector3
) -> Variant:
	return _call_native("ray_plane_hit_normal", [ray_origin, ray_dir, plane_origin, plane_normal])

static func ray_plane_hit_y(ray_origin: Vector3, ray_dir: Vector3, plane_y: float) -> Variant:
	return _call_native("ray_plane_hit_y", [ray_origin, ray_dir, plane_y])

static func snap_float(value: float, step: float) -> Variant:
	return _call_native("snap_float", [value, step])

static func snap_vector(v: Vector3, step: float) -> Variant:
	return _call_native("snap_vector", [v, step])

static func world_units_per_pixel_at(distance_to_world_pos: float, camera_fov_degrees: float, viewport_height: float) -> Variant:
	return _call_native("world_units_per_pixel_at", [distance_to_world_pos, camera_fov_degrees, viewport_height])

static func axis_delta_from_screen(
	screen_origin: Vector2,
	screen_axis_tip: Vector2,
	mouse_pos: Vector2,
	drag_start_mouse: Vector2
) -> Variant:
	return _call_native("axis_delta_from_screen", [screen_origin, screen_axis_tip, mouse_pos, drag_start_mouse])

static func apply_vertex_drag_delta(
	start_vertices: PackedVector3Array,
	selected_vertex_indices: PackedInt32Array,
	plane_indices: PackedInt32Array,
	plane_vertex_incidence: Array,
	start_plane_normals: PackedVector3Array,
	start_plane_distances: PackedFloat32Array,
	delta: Vector3
) -> Variant:
	return _call_native(
		"apply_vertex_drag_delta",
		[
			start_vertices,
			selected_vertex_indices,
			plane_indices,
			plane_vertex_incidence,
			start_plane_normals,
			start_plane_distances,
			delta,
		]
	)

static func _get_native_instance() -> Object:
	if _native_instance == null or not is_instance_valid(_native_instance):
		_native_instance = ClassDB.instantiate(NATIVE_CLASS_NAME)
	return _native_instance

static func _call_native(method_name: String, args: Array) -> Variant:
	if not is_available():
		_report_native_error_once(method_name, "native extension unavailable: %s" % NATIVE_EXTENSION_PATH)
		return null
	var native_obj = _get_native_instance()
	if native_obj == null:
		_report_native_error_once(method_name, "failed to instantiate %s" % NATIVE_CLASS_NAME)
		return null
	if not native_obj.has_method(method_name):
		_report_native_error_once(method_name, "missing native method on %s" % NATIVE_CLASS_NAME)
		return null
	return native_obj.callv(method_name, args)

static func _report_native_error_once(method_name: String, reason: String) -> void:
	var key := "%s|%s" % [method_name, reason]
	if _native_error_once.has(key):
		return
	_native_error_once[key] = true
	push_error("[BrushForgeNative] %s failed: %s" % [method_name, reason])
