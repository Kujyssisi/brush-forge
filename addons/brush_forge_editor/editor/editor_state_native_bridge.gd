@tool
extends RefCounted
class_name EditorStateNativeBridge

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

static func states_equal(a: Array, b: Array) -> Variant:
	if not is_available():
		return null
	var native_obj = _get_native_instance()
	if native_obj == null or not native_obj.has_method("states_equal"):
		return null
	return native_obj.call("states_equal", a, b)

static func structure_states_equal(a: Array, b: Array) -> Variant:
	if not is_available():
		return null
	var native_obj = _get_native_instance()
	if native_obj == null or not native_obj.has_method("structure_states_equal"):
		return null
	return native_obj.call("structure_states_equal", a, b)

static func clone_state(state: Array) -> Variant:
	if not is_available():
		return null
	var native_obj = _get_native_instance()
	if native_obj == null or not native_obj.has_method("clone_state"):
		return null
	return native_obj.call("clone_state", state)

static func _get_native_instance() -> Object:
	if _native_instance == null or not is_instance_valid(_native_instance):
		_native_instance = ClassDB.instantiate(NATIVE_CLASS_NAME)
	return _native_instance
