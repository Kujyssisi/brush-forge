@tool
extends RefCounted
const EDITOR_STATE_NATIVE_BRIDGE_SCRIPT = preload("res://addons/brush_forge_editor/editor/editor_state_native_bridge.gd")
static var _native_error_once: Dictionary = {}

static func states_equal(a: Array, b: Array) -> bool:
	if EDITOR_STATE_NATIVE_BRIDGE_SCRIPT != null:
		var native_eq = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.states_equal(a, b)
		if native_eq is bool:
			return native_eq
	_report_native_error_once("states_equal unavailable: native method failed")
	return false

static func structure_states_equal(a: Array, b: Array) -> bool:
	if EDITOR_STATE_NATIVE_BRIDGE_SCRIPT != null:
		var native_eq = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.structure_states_equal(a, b)
		if native_eq is bool:
			return native_eq
	_report_native_error_once("structure_states_equal unavailable: native method failed")
	return false

static func clone_state(state: Array) -> Array:
	if EDITOR_STATE_NATIVE_BRIDGE_SCRIPT != null:
		var native_clone = EDITOR_STATE_NATIVE_BRIDGE_SCRIPT.clone_state(state)
		if native_clone is Array:
			return native_clone
	_report_native_error_once("clone_state unavailable: native method failed")
	return []

static func _report_native_error_once(msg: String) -> void:
	if _native_error_once.has(msg):
		return
	_native_error_once[msg] = true
	push_error("[BrushForgeNative] %s" % msg)
