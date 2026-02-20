@tool
extends RefCounted

func on_texture_menu_id_pressed(plugin, id: int) -> void:
	if id < 0 or id >= plugin.texture_material_paths.size():
		return
	var material_path: String = str(plugin.texture_material_paths[id])
	apply_texture_material_path(plugin, material_path)

func on_texture_list_item_selected(plugin, index: int) -> void:
	if plugin.texture_list == null:
		return
	if index < 0 or index >= plugin.texture_list.get_item_count():
		return
	var metadata = plugin.texture_list.get_item_metadata(index)
	if metadata == null:
		return
	var material_path: String = str(metadata)
	apply_texture_material_path(plugin, material_path)

func apply_texture_material_path(plugin, material_path: String) -> void:
	if plugin.selected_brush_index < 0 or plugin.selected_face_index < 0:
		return
	if plugin.selected_brush_index >= plugin.map_node.brush_data.size():
		return
	var brush: BrushForge = plugin.map_node.brush_data[plugin.selected_brush_index] as BrushForge
	if brush == null:
		return
	var face_key := str(plugin.selected_face_index)
	if str(brush.face_material_paths.get(face_key, "")) == material_path:
		return
	plugin._begin_history_action()
	brush.face_material_paths[face_key] = material_path
	var meshes := plugin._get_brush_meshes()
	if plugin.selected_brush_index >= 0 and plugin.selected_brush_index < meshes.size():
		var mesh := meshes[plugin.selected_brush_index]
		if mesh != null:
			mesh.mesh = plugin._build_brush_mesh(brush)
	plugin._end_history_action()
	sync_texture_list_selection(plugin)
	plugin._refresh_uv_controls_from_selection()
	plugin._update_gizmos()

func sync_texture_list_selection(plugin) -> void:
	if plugin.texture_list == null:
		plugin._refresh_uv_controls_from_selection()
		return
	if plugin.selected_brush_index < 0 or plugin.selected_face_index < 0:
		plugin.texture_list.deselect_all()
		plugin._refresh_uv_controls_from_selection()
		return
	if plugin.map_node == null or plugin.selected_brush_index >= plugin.map_node.brush_data.size():
		plugin.texture_list.deselect_all()
		plugin._refresh_uv_controls_from_selection()
		return
	var brush: BrushForge = plugin.map_node.brush_data[plugin.selected_brush_index] as BrushForge
	if brush == null:
		plugin.texture_list.deselect_all()
		plugin._refresh_uv_controls_from_selection()
		return
	var face_key := str(plugin.selected_face_index)
	var material_path := str(brush.face_material_paths.get(face_key, ""))
	if material_path == "":
		plugin.texture_list.deselect_all()
		plugin._refresh_uv_controls_from_selection()
		return
	for i in range(plugin.texture_list.get_item_count()):
		var metadata = plugin.texture_list.get_item_metadata(i)
		if metadata != null and str(metadata) == material_path:
			plugin.texture_list.select(i)
			plugin.texture_list.ensure_current_is_visible()
			plugin._refresh_uv_controls_from_selection()
			return
	plugin.texture_list.deselect_all()
	plugin._refresh_uv_controls_from_selection()
