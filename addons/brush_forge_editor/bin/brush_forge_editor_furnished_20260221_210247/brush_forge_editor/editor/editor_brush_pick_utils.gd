@tool
extends RefCounted

const NATIVE_CLASS_NAME := "BrushForgeNative"
const NATIVE_EXTENSION_PATH := "res://addons/brush_forge_editor/native/brush_forge_native/brush_forge_native.gdextension"

static var _native_checked := false
static var _native_available := false
static var _native_extension_resource: Resource
static var _native_instance: Object
static var _brush_plane_cache: Dictionary = {}
static var _native_error_once: Dictionary = {}

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
	return _pick_exact_face_native(brush, origin, dir)

static func _pick_exact_face_native(brush: BrushForge, origin: Vector3, dir: Vector3) -> Dictionary:
	if brush == null:
		return {}
	if not _is_native_available():
		_report_native_error_once("pick_exact_face", "native extension unavailable: %s" % NATIVE_EXTENSION_PATH)
		return {}
	var native_obj = _get_native_instance()
	if native_obj == null:
		_report_native_error_once("pick_exact_face", "failed to instantiate %s" % NATIVE_CLASS_NAME)
		return {}
	if not native_obj.has_method("pick_exact_face"):
		_report_native_error_once("pick_exact_face", "missing native method on %s" % NATIVE_CLASS_NAME)
		return {}
	var cache := _get_or_build_plane_cache(brush)
	var plane_normals: PackedVector3Array = cache.get("normals", PackedVector3Array())
	var plane_distances: PackedFloat32Array = cache.get("distances", PackedFloat32Array())
	var result = native_obj.call("pick_exact_face", plane_normals, plane_distances, origin, dir)
	if result is Dictionary:
		return result
	_report_native_error_once("pick_exact_face", "native returned invalid result type")
	return {}

static func invalidate_brush_pick_cache(brush: BrushForge) -> void:
	if brush == null:
		return
	_brush_plane_cache.erase(brush.get_instance_id())

static func invalidate_all_pick_cache() -> void:
	_brush_plane_cache.clear()

static func get_brush_plane_cache(brush: BrushForge) -> Dictionary:
	return _get_or_build_plane_cache(brush)

static func _get_or_build_plane_cache(brush: BrushForge) -> Dictionary:
	if brush == null:
		return {}
	var key := brush.get_instance_id()
	if _brush_plane_cache.has(key):
		return _brush_plane_cache[key]
	var plane_normals := PackedVector3Array()
	var plane_distances := PackedFloat32Array()
	for p in brush.planes:
		var plane: NeoPlane = p as NeoPlane
		if plane == null:
			continue
		plane_normals.append(plane.normal)
		plane_distances.append(plane.distance)
	var cached := {
		"normals": plane_normals,
		"distances": plane_distances,
	}
	_brush_plane_cache[key] = cached
	return cached

static func _is_native_available() -> bool:
	if not _native_checked:
		if ResourceLoader.exists(NATIVE_EXTENSION_PATH):
			_native_extension_resource = load(NATIVE_EXTENSION_PATH)
		_native_available = ClassDB.class_exists(NATIVE_CLASS_NAME)
		_native_checked = true
	return _native_available

static func _get_native_instance() -> Object:
	if _native_instance == null or not is_instance_valid(_native_instance):
		_native_instance = ClassDB.instantiate(NATIVE_CLASS_NAME)
	return _native_instance

static func _report_native_error_once(method_name: String, reason: String) -> void:
	var key := "%s|%s" % [method_name, reason]
	if _native_error_once.has(key):
		return
	_native_error_once[key] = true
	push_error("[BrushForgeNative] %s failed: %s" % [method_name, reason])
