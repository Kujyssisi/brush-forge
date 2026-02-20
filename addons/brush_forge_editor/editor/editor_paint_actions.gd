@tool
extends RefCounted

func paint_from_pick(plugin, camera: Camera3D, pick: Dictionary, mouse_pos: Vector2) -> void:
	var target_index := int(pick.get("index", -1))
	var target_face := int(pick.get("face_index", -1))
	if target_index < 0 or target_face < 0:
		return
	if target_index >= plugin.map_node.brush_data.size():
		return
	var meshes := plugin._get_brush_meshes()
	if target_index >= meshes.size():
		return
	var target_mesh := meshes[target_index]
	if target_mesh == null:
		return
	var precise_hit := plugin.EDITOR_BRUSH_PICK_UTILS_SCRIPT.pick_exact_face_on_brush(plugin.map_node, target_index, camera, mouse_pos)
	var hit: Vector3 = plugin._get_pick_hit_point_from_mouse(camera, pick, mouse_pos)
	if not precise_hit.is_empty():
		target_face = int(precise_hit.get("face_index", target_face))
		var exact_hit = precise_hit.get("hit", hit)
		if exact_hit is Vector3:
			hit = exact_hit
	plugin._select_brush(target_mesh, target_index)
	plugin._select_face(target_face)
	var radius := float(plugin.paint_radius_spinbox.value) if plugin.paint_radius_spinbox != null else 1.0
	var strength := float(plugin.paint_strength_spinbox.value) if plugin.paint_strength_spinbox != null else 0.35
	var col := plugin.paint_color_picker.color if plugin.paint_color_picker != null else Color.WHITE
	var min_step: float = maxf(radius * 0.2, 0.005)
	if plugin.paint_last_stamp == plugin.INVALID_STAMP_POINT:
		paint_at_world_point(plugin, target_index, target_face, hit, col, radius, strength, false)
		plugin.paint_last_stamp = hit
		rebuild_painted_brush_mesh(plugin, target_index)
		return
	var segment: Vector3 = hit - plugin.paint_last_stamp
	var segment_len: float = segment.length()
	if segment_len < 0.0001:
		return
	if segment_len < min_step:
		return
	var stamp_count: int = int(ceil(segment_len / min_step))
	for i in range(1, stamp_count + 1):
		var t: float = float(i) / float(stamp_count)
		var stamp_point: Vector3 = plugin.paint_last_stamp.lerp(hit, t)
		paint_at_world_point(plugin, target_index, target_face, stamp_point, col, radius, strength, false)
	plugin.paint_last_stamp = hit
	rebuild_painted_brush_mesh(plugin, target_index)

func rebuild_painted_brush_mesh(plugin, brush_index: int) -> void:
	var meshes := plugin._get_brush_meshes()
	if brush_index < 0 or brush_index >= meshes.size():
		return
	if plugin.map_node == null or brush_index >= plugin.map_node.brush_data.size():
		return
	var mesh: MeshInstance3D = meshes[brush_index]
	var brush: BrushForge = plugin.map_node.brush_data[brush_index] as BrushForge
	if mesh == null or brush == null:
		return
	mesh.mesh = plugin._build_brush_mesh(brush)
	plugin._update_gizmos()

func paint_at_world_point(plugin, brush_index: int, face_index: int, hit: Vector3, color: Color, radius: float, strength: float, rebuild_mesh: bool = true) -> void:
	if plugin.map_node == null or brush_index < 0 or brush_index >= plugin.map_node.brush_data.size():
		return
	var brush: BrushForge = plugin.map_node.brush_data[brush_index] as BrushForge
	if brush == null:
		return
	var face_key := str(face_index)
	if not brush.face_paint_strokes.has(face_key):
		brush.face_paint_strokes[face_key] = []
	var strokes: Array = brush.face_paint_strokes[face_key]
	strokes.append({
		"point": hit,
		"color": color,
		"radius": maxf(radius, 0.01),
		"strength": clampf(strength, 0.0, 1.0),
		"mode": int(plugin.paint_blend_mode_option.get_selected_id()) if plugin.paint_blend_mode_option != null else plugin.PAINT_MODE_NORMAL,
	})
	if strokes.size() > 8192:
		strokes = strokes.slice(strokes.size() - 8192, strokes.size())
	brush.face_paint_strokes[face_key] = strokes
	if rebuild_mesh:
		rebuild_painted_brush_mesh(plugin, brush_index)

func paint_fill_face(plugin, brush_index: int, face_index: int, color: Color) -> void:
	if plugin.map_node == null or brush_index < 0 or brush_index >= plugin.map_node.brush_data.size():
		return
	var brush: BrushForge = plugin.map_node.brush_data[brush_index] as BrushForge
	if brush == null:
		return
	var key := str(face_index)
	brush.face_paint_colors[key] = color
	brush.face_paint_strokes[key] = []
	rebuild_painted_brush_mesh(plugin, brush_index)

func handle_paint_tool_mouse_button(plugin, camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return plugin.AFTER_GUI_INPUT_PASS
	if not mb.pressed:
		if plugin.paint_drag_active:
			plugin.paint_drag_active = false
			plugin.paint_last_stamp = plugin.INVALID_STAMP_POINT
			if plugin.history_action_active:
				plugin._end_history_action()
			return plugin.AFTER_GUI_INPUT_STOP
		return plugin.AFTER_GUI_INPUT_PASS
	var pick := plugin._pick_brush_and_face(camera, mb.position)
	if pick.is_empty():
		plugin.paint_hover_valid = false
		plugin._update_gizmos()
		return plugin.AFTER_GUI_INPUT_PASS
	var target_index := int(pick.get("index", -1))
	var target_face := int(pick.get("face_index", -1))
	if target_index < 0 or target_face < 0:
		return plugin.AFTER_GUI_INPUT_PASS
	if plugin.paint_apply_mode_option != null and plugin.paint_apply_mode_option.get_selected_id() == plugin.PAINT_APPLY_BUCKET:
		if not plugin.history_action_active:
			plugin._begin_history_action()
		var col := plugin.paint_color_picker.color if plugin.paint_color_picker != null else Color.WHITE
		paint_fill_face(plugin, target_index, target_face, col)
		plugin._end_history_action()
		plugin.paint_drag_active = false
		plugin.paint_last_stamp = plugin.INVALID_STAMP_POINT
		return plugin.AFTER_GUI_INPUT_STOP
	plugin.paint_drag_active = true
	plugin.paint_last_stamp = plugin.INVALID_STAMP_POINT
	if not plugin.history_action_active:
		plugin._begin_history_action()
	plugin.paint_hover_valid = true
	plugin.paint_hover_point = plugin._get_pick_hit_point_from_mouse(camera, pick, mb.position)
	paint_from_pick(plugin, camera, pick, mb.position)
	return plugin.AFTER_GUI_INPUT_STOP

func handle_paint_tool_mouse_motion(plugin, camera: Camera3D, mm: InputEventMouseMotion) -> int:
	var pick := plugin._pick_brush_and_face(camera, mm.position)
	if pick.is_empty():
		plugin.paint_hover_valid = false
		plugin._update_gizmos()
		return plugin.AFTER_GUI_INPUT_PASS
	var hit := plugin._get_pick_hit_point_from_mouse(camera, pick, mm.position)
	plugin.paint_hover_valid = true
	plugin.paint_hover_point = hit
	if plugin.paint_drag_active:
		paint_from_pick(plugin, camera, pick, mm.position)
		return plugin.AFTER_GUI_INPUT_STOP
	plugin._update_gizmos()
	return plugin.AFTER_GUI_INPUT_PASS
