@tool
extends RefCounted
class_name BrushMeshNativeBridge

const NATIVE_CLASS_NAME := "BrushForgeNative"
const NATIVE_EXTENSION_PATH := "res://addons/brush_forge_editor/native/brush_forge_native/brush_forge_native.gdextension"

static var _availability_checked := false
static var _native_available := false
static var _extension_resource: Resource
static var _native_instance: Object

static func is_available() -> bool:
	if not _availability_checked:
		if ResourceLoader.exists(NATIVE_EXTENSION_PATH):
			_extension_resource = load(NATIVE_EXTENSION_PATH)
		_native_available = ClassDB.class_exists(NATIVE_CLASS_NAME)
		_availability_checked = true
	return _native_available

static func compute_brush_vertices(planes: Array) -> Array[Vector3]:
	if not is_available():
		var empty: Array[Vector3] = []
		return empty
	var native_obj = _get_native_instance()
	if native_obj == null:
		var empty: Array[Vector3] = []
		return empty
	if not native_obj.has_method("compute_brush_vertices"):
		var empty: Array[Vector3] = []
		return empty
	var plane_normals := PackedVector3Array()
	var plane_distances := PackedFloat32Array()
	for pp in planes:
		if not (pp is NeoPlane):
			continue
		var plane: NeoPlane = pp
		plane_normals.append(plane.normal)
		plane_distances.append(plane.distance)
	var native_result = native_obj.call("compute_brush_vertices", plane_normals, plane_distances)
	if native_result is PackedVector3Array:
		var out: Array[Vector3] = []
		for v in native_result:
			out.append(v)
		return out
	var empty: Array[Vector3] = []
	return empty

static func build_brush_surfaces(brush: BrushForge, vertices_world: Array[Vector3]) -> Array:
	if brush == null or not is_available():
		return []
	var native_obj = _get_native_instance()
	if native_obj == null:
		return []
	if not native_obj.has_method("build_brush_surfaces"):
		return []
	var plane_normals := PackedVector3Array()
	var plane_distances := PackedFloat32Array()
	for pp in brush.planes:
		if not (pp is NeoPlane):
			continue
		var plane: NeoPlane = pp
		plane_normals.append(plane.normal)
		plane_distances.append(plane.distance)
	var packed_vertices := PackedVector3Array()
	for v in vertices_world:
		packed_vertices.append(v)
	var native_result = native_obj.call(
		"build_brush_surfaces",
		plane_normals,
		plane_distances,
		packed_vertices,
		brush.position,
		brush.lock_uvs,
		brush.face_uv_transforms,
		brush.face_paint_colors,
		brush.face_paint_strokes,
		brush.face_subdivisions
	)
	if native_result is Array:
		return native_result
	return []

static func compute_face_hull(brush: BrushForge, face_index: int, epsilon: float = 0.02) -> Array[Vector3]:
	if brush == null or not is_available():
		var empty: Array[Vector3] = []
		return empty
	var native_obj = _get_native_instance()
	if native_obj == null:
		var empty: Array[Vector3] = []
		return empty
	if not native_obj.has_method("compute_face_hull"):
		var empty: Array[Vector3] = []
		return empty
	var plane_normals := PackedVector3Array()
	var plane_distances := PackedFloat32Array()
	for pp in brush.planes:
		if not (pp is NeoPlane):
			continue
		var plane: NeoPlane = pp
		plane_normals.append(plane.normal)
		plane_distances.append(plane.distance)
	var native_result = native_obj.call("compute_face_hull", plane_normals, plane_distances, face_index, epsilon)
	if native_result is PackedVector3Array:
		var out: Array[Vector3] = []
		for v in native_result:
			out.append(v)
		return out
	var empty: Array[Vector3] = []
	return empty

static func _get_native_instance() -> Object:
	if _native_instance == null or not is_instance_valid(_native_instance):
		_native_instance = ClassDB.instantiate(NATIVE_CLASS_NAME)
	return _native_instance
