@tool
extends RefCounted

func read_face_subdivision_xy(brush: BrushForge, face_index: int) -> Dictionary:
	var out := {"x": 1, "y": 1}
	if brush == null:
		return out
	var raw = brush.face_subdivisions.get(str(face_index), 1)
	if raw is Dictionary:
		out["x"] = clampi(int((raw as Dictionary).get("x", 1)), 1, 10)
		out["y"] = clampi(int((raw as Dictionary).get("y", out["x"])), 1, 10)
	else:
		var amount := clampi(int(raw), 1, 10)
		out["x"] = amount
		out["y"] = amount
	return out

func write_face_subdivision_xy(brush: BrushForge, face_index: int, sx: int, sy: int) -> void:
	if brush == null:
		return
	brush.face_subdivisions[str(face_index)] = {
		"x": clampi(sx, 1, 10),
		"y": clampi(sy, 1, 10),
	}

func apply_subdivide_xy_from_ui(plugin, axis: int, value: float) -> void:
	if plugin.subdivide_controls_updating:
		return
	if plugin.subdivide_tool_button == null or not plugin.subdivide_tool_button.button_pressed:
		return
	if plugin.map_node == null or plugin.selected_brush_index < 0 or plugin.selected_face_index < 0:
		return
	if plugin.selected_brush_index >= plugin.map_node.brush_data.size():
		return
	var brush: BrushForge = plugin.map_node.brush_data[plugin.selected_brush_index] as BrushForge
	if brush == null:
		return
	var amount := int(clampi(int(round(value)), 1, 10))
	var xy := read_face_subdivision_xy(brush, plugin.selected_face_index)
	var sx := int(xy.get("x", 1))
	var sy := int(xy.get("y", 1))
	var prev_sx := sx
	var prev_sy := sy
	if axis == 0:
		sx = amount
		if plugin.subdivide_lock_xy_button != null and plugin.subdivide_lock_xy_button.button_pressed:
			sy = amount
	else:
		sy = amount
		if plugin.subdivide_lock_xy_button != null and plugin.subdivide_lock_xy_button.button_pressed:
			sx = amount
	if plugin.subdivide_x_spinbox != null and absf(plugin.subdivide_x_spinbox.value - sx) > 0.00001:
		plugin.subdivide_x_spinbox.value = sx
	if plugin.subdivide_y_spinbox != null and absf(plugin.subdivide_y_spinbox.value - sy) > 0.00001:
		plugin.subdivide_y_spinbox.value = sy
	if sx == prev_sx and sy == prev_sy:
		return
	plugin._begin_history_action()
	write_face_subdivision_xy(brush, plugin.selected_face_index, sx, sy)
	var meshes: Array = plugin._get_brush_meshes()
	if plugin.selected_brush_index >= 0 and plugin.selected_brush_index < meshes.size():
		var mesh: MeshInstance3D = meshes[plugin.selected_brush_index] as MeshInstance3D
		if mesh != null:
			mesh.mesh = plugin._build_brush_mesh(brush)
	plugin._end_history_action()
	plugin._update_gizmos()

func sync_subdivide_lock_mode_for_selected_face(plugin) -> void:
	if plugin.subdivide_tool_button == null or not plugin.subdivide_tool_button.button_pressed:
		return
	if plugin.subdivide_lock_xy_button == null or not plugin.subdivide_lock_xy_button.button_pressed:
		return
	if plugin.map_node == null or plugin.selected_brush_index < 0 or plugin.selected_face_index < 0 or plugin.selected_brush_index >= plugin.map_node.brush_data.size():
		return
	var brush: BrushForge = plugin.map_node.brush_data[plugin.selected_brush_index] as BrushForge
	if brush == null:
		return
	var xy := read_face_subdivision_xy(brush, plugin.selected_face_index)
	var sx := int(xy.get("x", 1))
	var sy := int(xy.get("y", 1))
	if sx != sy:
		plugin.subdivide_lock_xy_button.button_pressed = false

func on_subdivide_x_changed(plugin, value: float) -> void:
	apply_subdivide_xy_from_ui(plugin, 0, value)

func on_subdivide_y_changed(plugin, value: float) -> void:
	apply_subdivide_xy_from_ui(plugin, 1, value)

func on_subdivide_lock_xy_toggled(plugin, enabled: bool) -> void:
	if plugin.subdivide_y_spinbox != null:
		plugin.subdivide_y_spinbox.editable = not enabled
	if enabled and plugin.subdivide_x_spinbox != null and plugin.subdivide_y_spinbox != null:
		if absf(plugin.subdivide_y_spinbox.value - plugin.subdivide_x_spinbox.value) > 0.00001:
			on_subdivide_x_changed(plugin, plugin.subdivide_x_spinbox.value)

func handle_subdivide_tool_mouse_button(plugin, camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return plugin.AFTER_GUI_INPUT_PASS
	var pick: Dictionary = plugin._pick_brush_and_face(camera, mb.position)
	if pick.is_empty():
		return plugin.AFTER_GUI_INPUT_PASS
	var target_mesh := pick["mesh"] as MeshInstance3D
	var target_index := int(pick["index"])
	if target_mesh == null or target_index < 0:
		return plugin.AFTER_GUI_INPUT_PASS
	var exact_hit: Dictionary = plugin.EDITOR_BRUSH_PICK_UTILS_SCRIPT.pick_exact_face_on_brush(plugin.map_node, target_index, camera, mb.position)
	if exact_hit.is_empty():
		return plugin.AFTER_GUI_INPUT_PASS
	var target_face := int(exact_hit.get("face_index", -1))
	if target_face < 0:
		return plugin.AFTER_GUI_INPUT_PASS
	plugin._select_brush(target_mesh, target_index)
	plugin._select_face(target_face)
	return plugin.AFTER_GUI_INPUT_STOP if plugin.selected_face_index >= 0 else plugin.AFTER_GUI_INPUT_PASS
