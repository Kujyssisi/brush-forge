@tool
extends EditorPlugin

const BRUSH_MESH_BUILDER_SCRIPT = preload("res://addons/brush_forge_editor/mesh/brush_mesh_builder.gd")
const BRUSH_FORGE_MAP_SCRIPT = preload("res://addons/brush_forge_editor/core/brush_forge_map.gd")
const BRUSH_FORGE_MAP_ICON = preload("res://addons/brush_forge_editor/icons/BrushForgeMap_Node_Icon.svg")

var map_node: BrushForgeMap
var add_brush_button: Button
var move_brush_button: Button
var brush_tool_button: Button
var clip_tool_button: Button
var vertex_tool_button: Button
var edge_tool_button: Button
var face_tool_button: Button
var rotate_tool_button: Button
var paint_tool_button: Button
var subdivide_tool_button: Button
var texture_tool_button: Button
var bake_mesh_collision_button: Button
var lock_uvs_button: Button
var grid_size_spinbox: SpinBox
var texture_menu: PopupMenu
var texture_panel: PanelContainer
var texture_list: ItemList
var texture_title_label: Label
var uv_section_toggle_button: Button
var uv_section_container: VBoxContainer
var uv_preview_mode_button: Button
var mesh_preview_mode_button: Button
var uv_snap_toggle_button: Button
var uv_snap_step_spinbox: SpinBox
var uv_zoom_spinbox: SpinBox
var uv_scale_x_spinbox: SpinBox
var uv_scale_y_spinbox: SpinBox
var uv_offset_x_spinbox: SpinBox
var uv_offset_y_spinbox: SpinBox
var uv_rotation_spinbox: SpinBox
var uv_preview_rect: TextureRect
var uv_preview_help_label: Label
var paint_section_label: Label
var paint_color_picker: ColorPickerButton
var paint_apply_mode_option: OptionButton
var paint_vertex_preview_button: Button
var paint_blend_mode_option: OptionButton
var paint_radius_spinbox: SpinBox
var paint_strength_spinbox: SpinBox
var paint_drag_active := false
var paint_last_stamp := Vector3(1e20, 1e20, 1e20)
var paint_ui_updating := false
var paint_hover_valid := false
var paint_hover_point := Vector3.ZERO
var subdivide_section_label: Label
var subdivide_amount_spinbox: SpinBox
var texture_panel_in_bottom := false
var plugin_active := false

var selected_mesh: MeshInstance3D
var selected_brush_index := -1
var selected_face_index := -1

var move_drag_active := false
var drag_start_brush_pos := Vector3.ZERO
var drag_plane_y := 0.0
var drag_start_plane_hit := Vector3.ZERO
var drag_start_mouse := Vector2.ZERO
var drag_alt_mode := false
var face_drag_active := false
var face_drag_start_center := Vector3.ZERO
var face_drag_start_size := Vector3.ONE
var face_drag_axis := Vector3.ZERO
var face_drag_sign := 1.0
var face_drag_face_index := -1
var face_drag_ctrl_mode := false
var face_drag_extrude_index := -1
var face_drag_start_planes: Array = []
var pending_click_active := false
var pending_click_pick: Dictionary = {}
var pending_click_mouse := Vector2.ZERO
var surface_draw_active := false
var surface_draw_start := Vector3.ZERO
var surface_draw_brush_index := -1
var brush_draw_active := false
var brush_draw_face_normal := Vector3.ZERO
var brush_draw_plane_origin := Vector3.ZERO
var brush_draw_axis_u := Vector3.ZERO
var brush_draw_axis_v := Vector3.ZERO
var brush_draw_start_u := 0.0
var brush_draw_start_v := 0.0
var brush_draw_min_u := 0.0
var brush_draw_max_u := 0.0
var brush_draw_min_v := 0.0
var brush_draw_max_v := 0.0
var brush_draw_has_rect := false
var brush_extrude_active := false
var brush_extrude_depth := 0.0
var clip_points: Array[Vector3] = []
var clip_face_normal := Vector3.ZERO
var clip_line_gizmo: MeshInstance3D
var clip_line_material: StandardMaterial3D
var vertex_drag_active := false
var selected_vertex_indices: Array[int] = []
var selected_vertex_anchor := Vector3.ZERO
var vertex_drag_start_anchor := Vector3.ZERO
var vertex_drag_plane_indices: Array[int] = []
var vertex_drag_start_planes: Array = []
var vertex_drag_start_vertices: Array[Vector3] = []
var vertex_drag_plane_vertex_indices: Array = []
var rotate_drag_active := false
var rotate_drag_axis := Vector3.UP
var rotate_drag_center := Vector3.ZERO
var rotate_drag_start_planes: Array = []

const DEFAULT_GRID_SIZE := 0.25
var grid_size := DEFAULT_GRID_SIZE
const NUDGE_STEP := 1.0
const EDIT_LOCK_META := "_edit_lock_"
const PICK_FALLBACK_RADIUS := 48.0
const MOVE_SENSITIVITY_XZ_FALLBACK := 0.02
const MOVE_SENSITIVITY_Y_SCALE := 1.1
const CLICK_DRAG_THRESHOLD := 4.0
const SURFACE_DRAW_HEIGHT := 1.0
const ROTATE_RADIANS_PER_PIXEL := 0.012
const ROTATE_SNAP_RADIANS := 0.2617993878 # 15 degrees
const INVALID_STAMP_POINT := Vector3(1e20, 1e20, 1e20)
const BAKE_NODE_NAME := "idk map baked"
const CLIP_MATERIAL_PATH := "res://addons/brush_forge_editor/utility_textures/clip.tres"
const SKIP_MATERIAL_PATH := "res://addons/brush_forge_editor/utility_textures/skip.tres"
const BAKE_UV2_TEXEL_SIZE := 0.2
const PAINT_MODE_NORMAL := 0
const PAINT_MODE_ADD := 1
const PAINT_MODE_MULTIPLY := 2
const PAINT_MODE_SUBTRACT := 3
const PAINT_MODE_BURN := 4
const PAINT_APPLY_BRUSH := 0
const PAINT_APPLY_BUCKET := 1

var brush_gizmo: MeshInstance3D
var face_gizmo: MeshInstance3D
var edge_gizmo: MeshInstance3D
var paint_brush_gizmo: MeshInstance3D
var subdivide_outline_gizmo: MeshInstance3D
var subdivide_grid_gizmo: MeshInstance3D
var rotate_gizmo: MeshInstance3D
var red_gizmo_material: StandardMaterial3D
var yellow_gizmo_material: StandardMaterial3D
var purple_face_gizmo_material: StandardMaterial3D
var edge_gizmo_material: StandardMaterial3D
var paint_brush_gizmo_material: StandardMaterial3D
var subdivide_outline_material: StandardMaterial3D
var subdivide_grid_material: StandardMaterial3D
var rotate_gizmo_material: StandardMaterial3D
var rotate_x_material: StandardMaterial3D
var rotate_y_material: StandardMaterial3D
var rotate_z_material: StandardMaterial3D
var rotate_active_material: StandardMaterial3D
var brush_rect_gizmo: MeshInstance3D
var brush_preview_gizmo: MeshInstance3D
var vertex_all_gizmo: MeshInstance3D
var vertex_selected_gizmo: MeshInstance3D
var cyan_gizmo_material: StandardMaterial3D
var preview_gizmo_material: StandardMaterial3D
var vertex_all_gizmo_material: StandardMaterial3D
var vertex_selected_gizmo_material: StandardMaterial3D

var pending_undo_state: Array = []
var history_action_active := false
var texture_material_paths: Array = []
var texture_material_names: Array = []
var texture_preview_cache: Dictionary = {}
var uv_controls_updating := false
var uv_preview_drag_active := false
var uv_preview_rotate_drag := false
var uv_preview_last_mouse := Vector2.ZERO
var uv_preview_zoom := 1.0
var uv_snap_enabled := true
var uv_snap_step := 0.125
var uv_preview_vertex_mode := false
var map_custom_type_registered := false

func _build_brush_mesh(brush: BrushForge) -> ArrayMesh:
	if BRUSH_MESH_BUILDER_SCRIPT != null:
		return BRUSH_MESH_BUILDER_SCRIPT.build_brush_mesh(brush)
	return ArrayMesh.new()

func _build_box_mesh(size: Vector3) -> ArrayMesh:
	if BRUSH_MESH_BUILDER_SCRIPT != null:
		return BRUSH_MESH_BUILDER_SCRIPT.build_box_mesh(size)
	return ArrayMesh.new()

func _get_brush_vertices_world(brush: BrushForge) -> Array[Vector3]:
	if BRUSH_MESH_BUILDER_SCRIPT != null:
		return BRUSH_MESH_BUILDER_SCRIPT.get_brush_vertices_world(brush)
	var empty: Array[Vector3] = []
	return empty

func _enter_tree():
	if not map_custom_type_registered:
		add_custom_type("BrushForgeMap", "Node3D", BRUSH_FORGE_MAP_SCRIPT, BRUSH_FORGE_MAP_ICON)
		map_custom_type_registered = true
	set_process(true)
	if has_method("set_input_event_forwarding_always_enabled"):
		call("set_input_event_forwarding_always_enabled")
	add_brush_button = Button.new()
	add_brush_button.text = ""
	add_brush_button.icon = load("res://addons/brush_forge_editor/icons/Add_Brush.svg")
	add_brush_button.tooltip_text = "Add Brush"
	add_brush_button.pressed.connect(_on_add_brush)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, add_brush_button)

	move_brush_button = Button.new()
	move_brush_button.text = ""
	move_brush_button.icon = load("res://addons/brush_forge_editor/icons/Move_Brush.svg")
	move_brush_button.tooltip_text = "Move Brush"
	move_brush_button.toggle_mode = true
	move_brush_button.button_pressed = false
	move_brush_button.toggled.connect(_on_move_brush_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, move_brush_button)

	brush_tool_button = Button.new()
	brush_tool_button.text = ""
	brush_tool_button.icon = load("res://addons/brush_forge_editor/icons/Brush_Tool.svg")
	brush_tool_button.tooltip_text = "Brush Tool"
	brush_tool_button.toggle_mode = true
	brush_tool_button.button_pressed = false
	brush_tool_button.toggled.connect(_on_brush_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, brush_tool_button)

	clip_tool_button = Button.new()
	clip_tool_button.text = ""
	clip_tool_button.icon = load("res://addons/brush_forge_editor/icons/Clip_Tool.svg")
	clip_tool_button.tooltip_text = "Clip Tool"
	clip_tool_button.toggle_mode = true
	clip_tool_button.button_pressed = false
	clip_tool_button.toggled.connect(_on_clip_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, clip_tool_button)

	vertex_tool_button = Button.new()
	vertex_tool_button.text = ""
	vertex_tool_button.icon = load("res://addons/brush_forge_editor/icons/Vertex_Tool.svg")
	vertex_tool_button.tooltip_text = "Vertex Tool"
	vertex_tool_button.toggle_mode = true
	vertex_tool_button.button_pressed = false
	vertex_tool_button.toggled.connect(_on_vertex_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, vertex_tool_button)

	edge_tool_button = Button.new()
	edge_tool_button.text = ""
	edge_tool_button.icon = load("res://addons/brush_forge_editor/icons/Edge_Tool.svg")
	edge_tool_button.tooltip_text = "Edge Tool"
	edge_tool_button.toggle_mode = true
	edge_tool_button.button_pressed = false
	edge_tool_button.toggled.connect(_on_edge_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, edge_tool_button)

	face_tool_button = Button.new()
	face_tool_button.text = ""
	face_tool_button.icon = load("res://addons/brush_forge_editor/icons/Face_Tool.svg")
	face_tool_button.tooltip_text = "Face Tool"
	face_tool_button.toggle_mode = true
	face_tool_button.button_pressed = false
	face_tool_button.toggled.connect(_on_face_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, face_tool_button)

	rotate_tool_button = Button.new()
	rotate_tool_button.text = ""
	rotate_tool_button.icon = load("res://addons/brush_forge_editor/icons/Rotate_Tool.svg")
	rotate_tool_button.tooltip_text = "Rotate Tool"
	rotate_tool_button.toggle_mode = true
	rotate_tool_button.button_pressed = false
	rotate_tool_button.toggled.connect(_on_rotate_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, rotate_tool_button)

	paint_tool_button = Button.new()
	paint_tool_button.text = ""
	paint_tool_button.icon = load("res://addons/brush_forge_editor/icons/Paint_Tool.svg")
	paint_tool_button.tooltip_text = "Paint Tool"
	paint_tool_button.toggle_mode = true
	paint_tool_button.button_pressed = false
	paint_tool_button.toggled.connect(_on_paint_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, paint_tool_button)

	subdivide_tool_button = Button.new()
	subdivide_tool_button.text = ""
	subdivide_tool_button.icon = load("res://addons/brush_forge_editor/icons/Subdivide_Tool.svg")
	subdivide_tool_button.tooltip_text = "Subdivide Tool"
	subdivide_tool_button.toggle_mode = true
	subdivide_tool_button.button_pressed = false
	subdivide_tool_button.toggled.connect(_on_subdivide_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, subdivide_tool_button)

	texture_tool_button = Button.new()
	texture_tool_button.text = ""
	texture_tool_button.icon = load("res://addons/brush_forge_editor/icons/Texture_Tool.svg")
	texture_tool_button.tooltip_text = "Texture Tool"
	texture_tool_button.toggle_mode = true
	texture_tool_button.button_pressed = false
	texture_tool_button.toggled.connect(_on_texture_tool_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, texture_tool_button)

	bake_mesh_collision_button = Button.new()
	bake_mesh_collision_button.text = ""
	bake_mesh_collision_button.icon = load("res://addons/brush_forge_editor/icons/Bake_Tool.svg")
	bake_mesh_collision_button.tooltip_text = "Bake visible geometry/collision and hide BrushForgeMap"
	bake_mesh_collision_button.pressed.connect(_on_bake_mesh_collision_pressed)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, bake_mesh_collision_button)

	lock_uvs_button = Button.new()
	lock_uvs_button.text = ""
	lock_uvs_button.toggle_mode = true
	lock_uvs_button.button_pressed = false
	lock_uvs_button.toggled.connect(_on_lock_uvs_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, lock_uvs_button)
	_refresh_lock_uv_button_text()
	grid_size_spinbox = SpinBox.new()
	grid_size_spinbox.min_value = 0.03125
	grid_size_spinbox.max_value = 1024.0
	grid_size_spinbox.step = 0.03125
	grid_size_spinbox.custom_minimum_size = Vector2(90.0, 0.0)
	grid_size_spinbox.value = grid_size
	grid_size_spinbox.tooltip_text = "Grid"
	grid_size_spinbox.value_changed.connect(_on_grid_size_spinbox_changed)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, grid_size_spinbox)
	texture_menu = PopupMenu.new()
	texture_menu.name = "__BrushForgeTextureMenu"
	texture_menu.id_pressed.connect(_on_texture_menu_id_pressed)
	get_editor_interface().get_base_control().add_child(texture_menu)
	texture_panel = PanelContainer.new()
	texture_panel.name = "__BrushForgeTexturePanel"
	texture_panel.custom_minimum_size = Vector2(320.0, 520.0)
	var texture_vbox := VBoxContainer.new()
	texture_panel.add_child(texture_vbox)
	texture_title_label = Label.new()
	texture_title_label.text = "BrushForge Materials"
	texture_vbox.add_child(texture_title_label)

	uv_section_toggle_button = Button.new()
	uv_section_toggle_button.text = "Hide UV Editor"
	uv_section_toggle_button.toggle_mode = true
	uv_section_toggle_button.button_pressed = true
	uv_section_toggle_button.toggled.connect(_on_uv_section_toggle_toggled)
	texture_vbox.add_child(uv_section_toggle_button)

	uv_section_container = VBoxContainer.new()
	texture_vbox.add_child(uv_section_container)

	var uv_title := Label.new()
	uv_title.text = "UV Controls"
	uv_section_container.add_child(uv_title)

	var uv_tools_row := HBoxContainer.new()
	uv_section_container.add_child(uv_tools_row)

	mesh_preview_mode_button = Button.new()
	mesh_preview_mode_button.toggle_mode = true
	mesh_preview_mode_button.button_pressed = false
	mesh_preview_mode_button.text = "Mesh: Textures"
	mesh_preview_mode_button.toggled.connect(_on_mesh_preview_mode_toggled)
	uv_tools_row.add_child(mesh_preview_mode_button)

	uv_preview_mode_button = Button.new()
	uv_preview_mode_button.toggle_mode = true
	uv_preview_mode_button.button_pressed = false
	uv_preview_mode_button.text = "Preview: Texture"
	uv_preview_mode_button.toggled.connect(_on_uv_preview_mode_toggled)
	uv_tools_row.add_child(uv_preview_mode_button)

	uv_snap_toggle_button = Button.new()
	uv_snap_toggle_button.toggle_mode = true
	uv_snap_toggle_button.button_pressed = uv_snap_enabled
	uv_snap_toggle_button.text = "UV Snap"
	uv_snap_toggle_button.toggled.connect(_on_uv_snap_toggled)
	uv_tools_row.add_child(uv_snap_toggle_button)

	uv_snap_step_spinbox = SpinBox.new()
	uv_snap_step_spinbox.min_value = 0.001
	uv_snap_step_spinbox.max_value = 64.0
	uv_snap_step_spinbox.step = 0.001
	uv_snap_step_spinbox.value = uv_snap_step
	uv_snap_step_spinbox.prefix = "Step "
	uv_snap_step_spinbox.custom_minimum_size = Vector2(100.0, 0.0)
	uv_snap_step_spinbox.value_changed.connect(_on_uv_snap_step_changed)
	uv_tools_row.add_child(uv_snap_step_spinbox)

	var uv_grid := GridContainer.new()
	uv_grid.columns = 2
	uv_section_container.add_child(uv_grid)

	var uv_scale_x_label := Label.new()
	uv_scale_x_label.text = "Scale X"
	uv_grid.add_child(uv_scale_x_label)
	uv_scale_x_spinbox = SpinBox.new()
	uv_scale_x_spinbox.min_value = 0.01
	uv_scale_x_spinbox.max_value = 128.0
	uv_scale_x_spinbox.step = 0.01
	uv_scale_x_spinbox.value_changed.connect(_on_uv_control_changed)
	uv_grid.add_child(uv_scale_x_spinbox)

	var uv_scale_y_label := Label.new()
	uv_scale_y_label.text = "Scale Y"
	uv_grid.add_child(uv_scale_y_label)
	uv_scale_y_spinbox = SpinBox.new()
	uv_scale_y_spinbox.min_value = 0.01
	uv_scale_y_spinbox.max_value = 128.0
	uv_scale_y_spinbox.step = 0.01
	uv_scale_y_spinbox.value_changed.connect(_on_uv_control_changed)
	uv_grid.add_child(uv_scale_y_spinbox)

	var uv_offset_x_label := Label.new()
	uv_offset_x_label.text = "Offset X"
	uv_grid.add_child(uv_offset_x_label)
	uv_offset_x_spinbox = SpinBox.new()
	uv_offset_x_spinbox.min_value = -1024.0
	uv_offset_x_spinbox.max_value = 1024.0
	uv_offset_x_spinbox.step = 0.01
	uv_offset_x_spinbox.value_changed.connect(_on_uv_control_changed)
	uv_grid.add_child(uv_offset_x_spinbox)

	var uv_offset_y_label := Label.new()
	uv_offset_y_label.text = "Offset Y"
	uv_grid.add_child(uv_offset_y_label)
	uv_offset_y_spinbox = SpinBox.new()
	uv_offset_y_spinbox.min_value = -1024.0
	uv_offset_y_spinbox.max_value = 1024.0
	uv_offset_y_spinbox.step = 0.01
	uv_offset_y_spinbox.value_changed.connect(_on_uv_control_changed)
	uv_grid.add_child(uv_offset_y_spinbox)

	var uv_rotation_label := Label.new()
	uv_rotation_label.text = "Rotation"
	uv_grid.add_child(uv_rotation_label)
	uv_rotation_spinbox = SpinBox.new()
	uv_rotation_spinbox.min_value = -360.0
	uv_rotation_spinbox.max_value = 360.0
	uv_rotation_spinbox.step = 1.0
	uv_rotation_spinbox.suffix = " deg"
	uv_rotation_spinbox.value_changed.connect(_on_uv_control_changed)
	uv_grid.add_child(uv_rotation_spinbox)

	uv_preview_help_label = Label.new()
	uv_preview_help_label.text = "UV Preview: LMB move, RMB rotate, Wheel zoom"
	uv_section_container.add_child(uv_preview_help_label)
	uv_zoom_spinbox = SpinBox.new()
	uv_zoom_spinbox.min_value = 0.25
	uv_zoom_spinbox.max_value = 16.0
	uv_zoom_spinbox.step = 0.05
	uv_zoom_spinbox.value = uv_preview_zoom
	uv_zoom_spinbox.prefix = "Zoom "
	uv_zoom_spinbox.custom_minimum_size = Vector2(120.0, 0.0)
	uv_zoom_spinbox.value_changed.connect(_on_uv_zoom_changed)
	uv_section_container.add_child(uv_zoom_spinbox)
	uv_preview_rect = TextureRect.new()
	uv_preview_rect.custom_minimum_size = Vector2(300.0, 220.0)
	uv_preview_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	uv_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	uv_preview_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	uv_preview_rect.gui_input.connect(_on_uv_preview_gui_input)
	uv_section_container.add_child(uv_preview_rect)

	paint_section_label = Label.new()
	paint_section_label.text = "Paint"
	texture_vbox.add_child(paint_section_label)
	paint_color_picker = ColorPickerButton.new()
	paint_color_picker.custom_minimum_size = Vector2(0.0, 28.0)
	paint_color_picker.color = Color(1, 1, 1, 1)
	paint_color_picker.color_changed.connect(_on_paint_color_changed)
	texture_vbox.add_child(paint_color_picker)
	paint_apply_mode_option = OptionButton.new()
	paint_apply_mode_option.custom_minimum_size = Vector2(0.0, 28.0)
	paint_apply_mode_option.add_item("Paint: Brush", PAINT_APPLY_BRUSH)
	paint_apply_mode_option.add_item("Paint: Bucket", PAINT_APPLY_BUCKET)
	paint_apply_mode_option.select(0)
	texture_vbox.add_child(paint_apply_mode_option)
	paint_vertex_preview_button = Button.new()
	paint_vertex_preview_button.toggle_mode = true
	paint_vertex_preview_button.button_pressed = BRUSH_MESH_BUILDER_SCRIPT.use_vertex_color_preview
	paint_vertex_preview_button.text = "Disable Materials (Show Vertex)"
	paint_vertex_preview_button.toggled.connect(_on_paint_vertex_preview_toggled)
	texture_vbox.add_child(paint_vertex_preview_button)
	paint_blend_mode_option = OptionButton.new()
	paint_blend_mode_option.custom_minimum_size = Vector2(0.0, 28.0)
	paint_blend_mode_option.add_item("Blend: Normal", PAINT_MODE_NORMAL)
	paint_blend_mode_option.add_item("Blend: Add", PAINT_MODE_ADD)
	paint_blend_mode_option.add_item("Blend: Multiply", PAINT_MODE_MULTIPLY)
	paint_blend_mode_option.add_item("Blend: Subtract", PAINT_MODE_SUBTRACT)
	paint_blend_mode_option.add_item("Blend: Burn", PAINT_MODE_BURN)
	paint_blend_mode_option.select(0)
	texture_vbox.add_child(paint_blend_mode_option)
	paint_radius_spinbox = SpinBox.new()
	paint_radius_spinbox.min_value = 0.05
	paint_radius_spinbox.max_value = 64.0
	paint_radius_spinbox.step = 0.05
	paint_radius_spinbox.value = 0.25
	paint_radius_spinbox.prefix = "Range "
	texture_vbox.add_child(paint_radius_spinbox)
	paint_strength_spinbox = SpinBox.new()
	paint_strength_spinbox.min_value = 0.01
	paint_strength_spinbox.max_value = 1.0
	paint_strength_spinbox.step = 0.01
	paint_strength_spinbox.value = 0.35
	paint_strength_spinbox.prefix = "Strength "
	texture_vbox.add_child(paint_strength_spinbox)

	subdivide_section_label = Label.new()
	subdivide_section_label.text = "Subdivision"
	texture_vbox.add_child(subdivide_section_label)
	subdivide_amount_spinbox = SpinBox.new()
	subdivide_amount_spinbox.min_value = 1
	subdivide_amount_spinbox.max_value = 10
	subdivide_amount_spinbox.step = 1
	subdivide_amount_spinbox.value = 1
	subdivide_amount_spinbox.prefix = "Amount "
	subdivide_amount_spinbox.value_changed.connect(_on_subdivide_amount_changed)
	texture_vbox.add_child(subdivide_amount_spinbox)

	texture_list = ItemList.new()
	texture_list.select_mode = ItemList.SELECT_SINGLE
	texture_list.fixed_column_width = 240
	texture_list.max_columns = 1
	texture_list.same_column_width = true
	texture_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_list.custom_minimum_size = Vector2(0.0, 220.0)
	texture_list.item_selected.connect(_on_texture_list_item_selected)
	texture_vbox.add_child(texture_list)
	var inspector_added := false
	var editor := get_editor_interface()
	if editor != null and editor.has_method("get_inspector"):
		var inspector := editor.call("get_inspector")
		if inspector is Control:
			(inspector as Control).add_child(texture_panel)
			inspector_added = true
	if not inspector_added:
		add_control_to_bottom_panel(texture_panel, "BrushForge Materials")
		texture_panel_in_bottom = true
	_set_plugin_active(false)

func _exit_tree():
	if map_custom_type_registered:
		remove_custom_type("BrushForgeMap")
		map_custom_type_registered = false
	set_process(false)
	if add_brush_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, add_brush_button)
		add_brush_button.queue_free()
	if move_brush_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, move_brush_button)
		move_brush_button.queue_free()
	if brush_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, brush_tool_button)
		brush_tool_button.queue_free()
	if clip_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, clip_tool_button)
		clip_tool_button.queue_free()
	if vertex_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, vertex_tool_button)
		vertex_tool_button.queue_free()
	if edge_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, edge_tool_button)
		edge_tool_button.queue_free()
	if face_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, face_tool_button)
		face_tool_button.queue_free()
	if rotate_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, rotate_tool_button)
		rotate_tool_button.queue_free()
	if paint_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, paint_tool_button)
		paint_tool_button.queue_free()
	if subdivide_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, subdivide_tool_button)
		subdivide_tool_button.queue_free()
	if texture_tool_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, texture_tool_button)
		texture_tool_button.queue_free()
	if bake_mesh_collision_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, bake_mesh_collision_button)
		bake_mesh_collision_button.queue_free()
	if lock_uvs_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, lock_uvs_button)
		lock_uvs_button.queue_free()
	if grid_size_spinbox:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, grid_size_spinbox)
		grid_size_spinbox.queue_free()
	if texture_menu != null:
		texture_menu.queue_free()
	if texture_panel != null:
		if texture_panel_in_bottom:
			remove_control_from_bottom_panel(texture_panel)
		texture_panel.queue_free()
	_clear_selection()
	_remove_gizmo_nodes()

func _on_add_brush():
	if not _ensure_map_node():
		return
	_set_plugin_active(true)
	var before_count := map_node.brush_data.size()
	var new_b := BrushForge.create_box(Vector3.ZERO, Vector3.ONE * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_brush_mesh(new_b)
	mi.position = new_b.position
	mi.set_meta(EDIT_LOCK_META, true)

	if history_action_active:
		_end_history_action()
	_begin_history_action()
	map_node.add_brush(new_b, mi)
	_select_brush(mi, map_node.brush_data.size() - 1)
	var selection := get_editor_interface().get_selection()
	if selection != null:
		selection.clear()
		selection.add_node(map_node)
	_end_history_action()
	map_node.sync_data_from_scene()
	var after_count := map_node.brush_data.size()
	if after_count <= before_count:
		# Hard fallback when UndoRedo or restore flow cancels the add.
		var fb := BrushForge.create_box(Vector3.ZERO, Vector3.ONE * 2.0)
		var fmi := MeshInstance3D.new()
		fmi.mesh = _build_brush_mesh(fb)
		fmi.position = fb.position
		fmi.set_meta(EDIT_LOCK_META, true)
		map_node.add_brush(fb, fmi)
		_select_brush(fmi, map_node.brush_data.size() - 1)
		map_node.sync_data_from_scene()

func _on_bake_mesh_collision_pressed() -> void:
	if not _ensure_map_node():
		return
	if map_node == null:
		return
	var parent := map_node.get_parent()
	if parent == null:
		push_warning("BrushForge bake failed: map node has no parent.")
		return
	_remove_existing_baked_node(parent)
	var baked_body := StaticBody3D.new()
	baked_body.name = BAKE_NODE_NAME
	baked_body.transform = map_node.transform
	if map_node.map_data != null:
		baked_body.collision_layer = int(map_node.map_data.collision_layer)
		baked_body.collision_mask = int(map_node.map_data.collision_mask)
	parent.add_child(baked_body)
	baked_body.owner = _resolve_scene_owner(parent)
	var mesh_groups := {}
	var collision_faces := PackedVector3Array()
	for i in range(map_node.brush_data.size()):
		var brush: BrushForge = map_node.brush_data[i] as BrushForge
		if brush == null:
			continue
		_collect_brush_bake_geometry(brush, mesh_groups, collision_faces)
	var baked_mesh := _build_baked_mesh_from_groups(mesh_groups)
	if baked_mesh != null and baked_mesh.get_surface_count() > 0:
		baked_mesh.lightmap_unwrap(Transform3D.IDENTITY, BAKE_UV2_TEXEL_SIZE)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "BakedMesh"
		mesh_instance.mesh = baked_mesh
		baked_body.add_child(mesh_instance)
		mesh_instance.owner = baked_body.owner
	if collision_faces.size() >= 3:
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "BakedCollision"
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(collision_faces)
		collision_shape.shape = concave
		baked_body.add_child(collision_shape)
		collision_shape.owner = baked_body.owner
	map_node.visible = false

func _remove_existing_baked_node(parent: Node) -> void:
	if parent == null:
		return
	var existing := parent.get_node_or_null(BAKE_NODE_NAME)
	if existing != null:
		parent.remove_child(existing)
		existing.queue_free()

func _resolve_scene_owner(fallback_parent: Node) -> Node:
	var scene_root := get_tree().edited_scene_root
	if scene_root != null:
		return scene_root
	if map_node != null and map_node.owner != null:
		return map_node.owner
	return fallback_parent

func _collect_brush_bake_geometry(brush: BrushForge, mesh_groups: Dictionary, collision_faces: PackedVector3Array) -> void:
	if brush == null:
		return
	var render_mesh := _build_brush_mesh(brush)
	if render_mesh == null:
		return
	var collision_brush := _clone_brush_with_no_subdivisions(brush)
	var collision_mesh := _build_brush_mesh(collision_brush)
	for surface_index in range(render_mesh.get_surface_count()):
		var arrays := render_mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if src_verts.size() < 3:
			continue
		var src_material := render_mesh.surface_get_material(surface_index)
		var mode := _surface_bake_mode(src_material)
		if mode == "skip":
			continue
		if collision_mesh != null and surface_index < collision_mesh.get_surface_count():
			var collision_arrays := collision_mesh.surface_get_arrays(surface_index)
			if not collision_arrays.is_empty():
				var collision_verts: PackedVector3Array = collision_arrays[Mesh.ARRAY_VERTEX]
				if collision_verts.size() >= 3:
					var translated_collision := PackedVector3Array()
					translated_collision.resize(collision_verts.size())
					for ci in range(collision_verts.size()):
						translated_collision[ci] = collision_verts[ci] + brush.position
					collision_faces.append_array(translated_collision)
		if mode != "solid":
			continue
		var translated_verts := PackedVector3Array()
		translated_verts.resize(src_verts.size())
		for i in range(src_verts.size()):
			translated_verts[i] = src_verts[i] + brush.position
		var group_key := _mesh_group_key_for_material(src_material)
		var group: Dictionary = mesh_groups.get(group_key, {})
		if group.is_empty():
			group = {
				"material": src_material,
				"verts": PackedVector3Array(),
				"normals": PackedVector3Array(),
				"uvs": PackedVector2Array(),
				"colors": PackedColorArray(),
			}
		var group_verts: PackedVector3Array = group["verts"]
		group_verts.append_array(translated_verts)
		group["verts"] = group_verts
		var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if src_normals.size() == src_verts.size():
			var group_normals: PackedVector3Array = group["normals"]
			group_normals.append_array(src_normals)
			group["normals"] = group_normals
		var src_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if src_uvs.size() == src_verts.size():
			var group_uvs: PackedVector2Array = group["uvs"]
			group_uvs.append_array(src_uvs)
			group["uvs"] = group_uvs
		var src_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if src_colors.size() == src_verts.size():
			var group_colors: PackedColorArray = group["colors"]
			group_colors.append_array(src_colors)
			group["colors"] = group_colors
		mesh_groups[group_key] = group

func _mesh_group_key_for_material(material: Material) -> String:
	if material == null:
		return "__null_material__"
	var path := material.resource_path
	if path != "":
		return "path:" + path.to_lower()
	return "obj:%d" % material.get_instance_id()

func _build_baked_mesh_from_groups(mesh_groups: Dictionary) -> ArrayMesh:
	if mesh_groups.is_empty():
		return ArrayMesh.new()
	var keys := mesh_groups.keys()
	keys.sort()
	var out_mesh := ArrayMesh.new()
	for key in keys:
		var group: Dictionary = mesh_groups.get(key, {})
		if group.is_empty():
			continue
		var verts: PackedVector3Array = group.get("verts", PackedVector3Array())
		if verts.size() < 3:
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		var normals: PackedVector3Array = group.get("normals", PackedVector3Array())
		if normals.size() == verts.size():
			arr[Mesh.ARRAY_NORMAL] = normals
		var uvs: PackedVector2Array = group.get("uvs", PackedVector2Array())
		if uvs.size() == verts.size():
			arr[Mesh.ARRAY_TEX_UV] = uvs
		var colors: PackedColorArray = group.get("colors", PackedColorArray())
		if colors.size() == verts.size():
			arr[Mesh.ARRAY_COLOR] = colors
		out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var surf_idx := out_mesh.get_surface_count() - 1
		var material: Material = group.get("material", null)
		if material != null:
			out_mesh.surface_set_material(surf_idx, material)
	return out_mesh

func _clone_brush_with_no_subdivisions(src: BrushForge) -> BrushForge:
	var copy := BrushForge.create_box(src.position, src.size)
	copy.planes.clear()
	for pp in src.planes:
		var p: NeoPlane = pp as NeoPlane
		if p != null:
			copy.planes.append(NeoPlane.new(p.normal, p.distance))
	copy.face_material_paths = src.face_material_paths.duplicate(true)
	copy.face_uv_transforms = src.face_uv_transforms.duplicate(true)
	copy.face_paint_colors = src.face_paint_colors.duplicate(true)
	copy.face_paint_strokes = src.face_paint_strokes.duplicate(true)
	copy.face_subdivisions = {}
	copy.lock_uvs = src.lock_uvs
	return copy

func _surface_bake_mode(material: Material) -> String:
	if material == null:
		return "solid"
	var mat_path := material.resource_path.to_lower()
	if mat_path == SKIP_MATERIAL_PATH.to_lower():
		return "skip"
	if mat_path == CLIP_MATERIAL_PATH.to_lower():
		return "clip"
	return "solid"

func _on_move_brush_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			move_brush_button.button_pressed = false
			return
		_set_plugin_active(true)
	if not enabled:
		move_drag_active = false
		face_drag_active = false
		face_drag_ctrl_mode = false
		face_drag_extrude_index = -1
		surface_draw_active = false
		surface_draw_brush_index = -1
		pending_click_active = false
		pending_click_pick = {}
		_clear_face_selection()
	if enabled and brush_tool_button != null and brush_tool_button.button_pressed:
		brush_tool_button.button_pressed = false
	if enabled and clip_tool_button != null and clip_tool_button.button_pressed:
		clip_tool_button.button_pressed = false
	if enabled and vertex_tool_button != null and vertex_tool_button.button_pressed:
		vertex_tool_button.button_pressed = false
	if enabled and edge_tool_button != null and edge_tool_button.button_pressed:
		edge_tool_button.button_pressed = false
	if enabled and face_tool_button != null and face_tool_button.button_pressed:
		face_tool_button.button_pressed = false
	if enabled and rotate_tool_button != null and rotate_tool_button.button_pressed:
		rotate_tool_button.button_pressed = false
	if enabled and paint_tool_button != null and paint_tool_button.button_pressed:
		paint_tool_button.button_pressed = false
	if enabled and subdivide_tool_button != null and subdivide_tool_button.button_pressed:
		subdivide_tool_button.button_pressed = false
	if enabled and texture_tool_button != null and texture_tool_button.button_pressed:
		texture_tool_button.button_pressed = false

func _on_brush_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			brush_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled and move_brush_button != null and move_brush_button.button_pressed:
		move_brush_button.button_pressed = false
	if enabled and clip_tool_button != null and clip_tool_button.button_pressed:
		clip_tool_button.button_pressed = false
	if enabled and vertex_tool_button != null and vertex_tool_button.button_pressed:
		vertex_tool_button.button_pressed = false
	if enabled and edge_tool_button != null and edge_tool_button.button_pressed:
		edge_tool_button.button_pressed = false
	if enabled and face_tool_button != null and face_tool_button.button_pressed:
		face_tool_button.button_pressed = false
	if enabled and rotate_tool_button != null and rotate_tool_button.button_pressed:
		rotate_tool_button.button_pressed = false
	if enabled and paint_tool_button != null and paint_tool_button.button_pressed:
		paint_tool_button.button_pressed = false
	if enabled and subdivide_tool_button != null and subdivide_tool_button.button_pressed:
		subdivide_tool_button.button_pressed = false
	if enabled and texture_tool_button != null and texture_tool_button.button_pressed:
		texture_tool_button.button_pressed = false
	if not enabled:
		brush_draw_active = false
		brush_extrude_active = false
		brush_draw_has_rect = false
		brush_extrude_depth = 0.0
		_update_brush_tool_gizmos()

func _on_clip_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			clip_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled:
		if move_brush_button == null or not move_brush_button.button_pressed:
			clip_tool_button.button_pressed = false
			return
		if brush_tool_button != null and brush_tool_button.button_pressed:
			brush_tool_button.button_pressed = false
		if vertex_tool_button != null and vertex_tool_button.button_pressed:
			vertex_tool_button.button_pressed = false
		if edge_tool_button != null and edge_tool_button.button_pressed:
			edge_tool_button.button_pressed = false
		if face_tool_button != null and face_tool_button.button_pressed:
			face_tool_button.button_pressed = false
		if rotate_tool_button != null and rotate_tool_button.button_pressed:
			rotate_tool_button.button_pressed = false
		if paint_tool_button != null and paint_tool_button.button_pressed:
			paint_tool_button.button_pressed = false
		if subdivide_tool_button != null and subdivide_tool_button.button_pressed:
			subdivide_tool_button.button_pressed = false
		if texture_tool_button != null and texture_tool_button.button_pressed:
			texture_tool_button.button_pressed = false
	if not enabled:
		clip_points.clear()
		clip_face_normal = Vector3.ZERO
		_update_clip_tool_gizmo()

func _on_vertex_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			vertex_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled:
		if move_brush_button == null or not move_brush_button.button_pressed:
			vertex_tool_button.button_pressed = false
			return
		if selected_brush_index < 0:
			vertex_tool_button.button_pressed = false
			return
		if clip_tool_button != null and clip_tool_button.button_pressed:
			clip_tool_button.button_pressed = false
		if edge_tool_button != null and edge_tool_button.button_pressed:
			edge_tool_button.button_pressed = false
		if face_tool_button != null and face_tool_button.button_pressed:
			face_tool_button.button_pressed = false
		if rotate_tool_button != null and rotate_tool_button.button_pressed:
			rotate_tool_button.button_pressed = false
		if paint_tool_button != null and paint_tool_button.button_pressed:
			paint_tool_button.button_pressed = false
		if subdivide_tool_button != null and subdivide_tool_button.button_pressed:
			subdivide_tool_button.button_pressed = false
		if texture_tool_button != null and texture_tool_button.button_pressed:
			texture_tool_button.button_pressed = false
	if not enabled:
		vertex_drag_active = false
		selected_vertex_indices.clear()
		selected_vertex_anchor = Vector3.ZERO
		vertex_drag_plane_indices.clear()
		vertex_drag_start_planes.clear()
		vertex_drag_start_vertices.clear()
		vertex_drag_plane_vertex_indices.clear()
		_update_gizmos()

func _on_edge_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			edge_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled:
		if move_brush_button == null or not move_brush_button.button_pressed or selected_brush_index < 0:
			edge_tool_button.button_pressed = false
			return
		if clip_tool_button != null and clip_tool_button.button_pressed:
			clip_tool_button.button_pressed = false
		if vertex_tool_button != null and vertex_tool_button.button_pressed:
			vertex_tool_button.button_pressed = false
		if face_tool_button != null and face_tool_button.button_pressed:
			face_tool_button.button_pressed = false
		if rotate_tool_button != null and rotate_tool_button.button_pressed:
			rotate_tool_button.button_pressed = false
		if paint_tool_button != null and paint_tool_button.button_pressed:
			paint_tool_button.button_pressed = false
		if subdivide_tool_button != null and subdivide_tool_button.button_pressed:
			subdivide_tool_button.button_pressed = false
		if texture_tool_button != null and texture_tool_button.button_pressed:
			texture_tool_button.button_pressed = false

func _on_face_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			face_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled:
		if move_brush_button == null or not move_brush_button.button_pressed or selected_brush_index < 0:
			face_tool_button.button_pressed = false
			return
		if clip_tool_button != null and clip_tool_button.button_pressed:
			clip_tool_button.button_pressed = false
		if vertex_tool_button != null and vertex_tool_button.button_pressed:
			vertex_tool_button.button_pressed = false
		if edge_tool_button != null and edge_tool_button.button_pressed:
			edge_tool_button.button_pressed = false
		if rotate_tool_button != null and rotate_tool_button.button_pressed:
			rotate_tool_button.button_pressed = false
		if texture_tool_button != null and texture_tool_button.button_pressed:
			texture_tool_button.button_pressed = false

func _on_rotate_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			rotate_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled:
		if move_brush_button == null or not move_brush_button.button_pressed or selected_brush_index < 0:
			rotate_tool_button.button_pressed = false
			return
		if clip_tool_button != null and clip_tool_button.button_pressed:
			clip_tool_button.button_pressed = false
		if vertex_tool_button != null and vertex_tool_button.button_pressed:
			vertex_tool_button.button_pressed = false
		if edge_tool_button != null and edge_tool_button.button_pressed:
			edge_tool_button.button_pressed = false
		if face_tool_button != null and face_tool_button.button_pressed:
			face_tool_button.button_pressed = false
		if paint_tool_button != null and paint_tool_button.button_pressed:
			paint_tool_button.button_pressed = false
		if subdivide_tool_button != null and subdivide_tool_button.button_pressed:
			subdivide_tool_button.button_pressed = false
		if texture_tool_button != null and texture_tool_button.button_pressed:
			texture_tool_button.button_pressed = false
	if not enabled:
		rotate_drag_active = false
		rotate_drag_start_planes.clear()

func _on_paint_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			paint_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled:
		if move_brush_button == null or not move_brush_button.button_pressed or selected_brush_index < 0:
			paint_tool_button.button_pressed = false
			return
		if clip_tool_button != null and clip_tool_button.button_pressed:
			clip_tool_button.button_pressed = false
		if vertex_tool_button != null and vertex_tool_button.button_pressed:
			vertex_tool_button.button_pressed = false
		if edge_tool_button != null and edge_tool_button.button_pressed:
			edge_tool_button.button_pressed = false
		if face_tool_button != null and face_tool_button.button_pressed:
			face_tool_button.button_pressed = false
		if rotate_tool_button != null and rotate_tool_button.button_pressed:
			rotate_tool_button.button_pressed = false
		if subdivide_tool_button != null and subdivide_tool_button.button_pressed:
			subdivide_tool_button.button_pressed = false
			if texture_tool_button != null and texture_tool_button.button_pressed:
				texture_tool_button.button_pressed = false
			_refresh_uv_controls_from_selection()
			_set_mesh_vertex_preview(true)
		else:
			paint_drag_active = false
			paint_last_stamp = INVALID_STAMP_POINT
			paint_hover_valid = false
		_update_gizmos()

func _on_subdivide_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			subdivide_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled:
		if move_brush_button == null or not move_brush_button.button_pressed or selected_brush_index < 0:
			subdivide_tool_button.button_pressed = false
			return
		if clip_tool_button != null and clip_tool_button.button_pressed:
			clip_tool_button.button_pressed = false
		if vertex_tool_button != null and vertex_tool_button.button_pressed:
			vertex_tool_button.button_pressed = false
		if edge_tool_button != null and edge_tool_button.button_pressed:
			edge_tool_button.button_pressed = false
		if face_tool_button != null and face_tool_button.button_pressed:
			face_tool_button.button_pressed = false
		if rotate_tool_button != null and rotate_tool_button.button_pressed:
			rotate_tool_button.button_pressed = false
		if paint_tool_button != null and paint_tool_button.button_pressed:
			paint_tool_button.button_pressed = false
		if texture_tool_button != null and texture_tool_button.button_pressed:
			texture_tool_button.button_pressed = false
	_update_gizmos()

func _on_texture_tool_toggled(enabled: bool) -> void:
	if not plugin_active and enabled:
		if not _ensure_map_node(false):
			texture_tool_button.button_pressed = false
			return
		_set_plugin_active(true)
	if enabled:
		if texture_menu != null:
			texture_menu.hide()
		if move_brush_button != null and move_brush_button.button_pressed:
			move_brush_button.button_pressed = false
		if brush_tool_button != null and brush_tool_button.button_pressed:
			brush_tool_button.button_pressed = false
		if clip_tool_button != null and clip_tool_button.button_pressed:
			clip_tool_button.button_pressed = false
		if vertex_tool_button != null and vertex_tool_button.button_pressed:
			vertex_tool_button.button_pressed = false
		if edge_tool_button != null and edge_tool_button.button_pressed:
			edge_tool_button.button_pressed = false
		if face_tool_button != null and face_tool_button.button_pressed:
			face_tool_button.button_pressed = false
		if rotate_tool_button != null and rotate_tool_button.button_pressed:
			rotate_tool_button.button_pressed = false
		if paint_tool_button != null and paint_tool_button.button_pressed:
			paint_tool_button.button_pressed = false
		if subdivide_tool_button != null and subdivide_tool_button.button_pressed:
			subdivide_tool_button.button_pressed = false
		_refresh_texture_menu()
		_sync_texture_list_selection()
	else:
		if texture_menu != null:
			texture_menu.hide()

func _popup_texture_menu() -> void:
	if selected_brush_index < 0 or selected_face_index < 0:
		return
	_refresh_texture_menu()
	if texture_menu == null:
		return
	if texture_material_paths.is_empty():
		return
	texture_menu.reset_size()
	texture_menu.popup_centered(Vector2i(420, 360))

func _on_lock_uvs_toggled(enabled: bool) -> void:
	if map_node == null:
		return
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	if brush.lock_uvs != enabled:
		_adjust_brush_uv_offsets_for_lock_toggle(brush, enabled)
	brush.lock_uvs = enabled
	_refresh_lock_uv_button_text()
	var meshes := _get_brush_meshes()
	if selected_brush_index >= 0 and selected_brush_index < meshes.size():
		var mesh := meshes[selected_brush_index]
		if mesh != null:
			mesh.mesh = _build_brush_mesh(brush)
	map_node.sync_data_from_scene()

func _refresh_lock_uv_button_text() -> void:
	if lock_uvs_button == null:
		return
	lock_uvs_button.text = ""
	if lock_uvs_button.button_pressed:
		lock_uvs_button.icon = load("res://addons/brush_forge_editor/icons/Lock_Tool.svg")
		lock_uvs_button.tooltip_text = "Unlock UVs"
	else:
		lock_uvs_button.icon = load("res://addons/brush_forge_editor/icons/Unlock_Tool.svg")
		lock_uvs_button.tooltip_text = "Lock UVs"

func _on_grid_size_spinbox_changed(value: float) -> void:
	grid_size = clampf(value, 0.03125, 1024.0)
	if grid_size_spinbox != null and absf(grid_size_spinbox.value - grid_size) > 0.00001:
		grid_size_spinbox.value = grid_size

func _on_uv_control_changed(_value: float) -> void:
	if uv_controls_updating:
		return
	if uv_snap_enabled:
		uv_controls_updating = true
		uv_scale_x_spinbox.value = _snap_uv_value(float(uv_scale_x_spinbox.value))
		uv_scale_y_spinbox.value = _snap_uv_value(float(uv_scale_y_spinbox.value))
		uv_offset_x_spinbox.value = _snap_uv_value(float(uv_offset_x_spinbox.value))
		uv_offset_y_spinbox.value = _snap_uv_value(float(uv_offset_y_spinbox.value))
		uv_rotation_spinbox.value = _snap_uv_value(float(uv_rotation_spinbox.value))
		uv_controls_updating = false
	_apply_uv_controls_to_selected_face()

func _on_uv_section_toggle_toggled(enabled: bool) -> void:
	if uv_section_container != null:
		uv_section_container.visible = enabled
	if uv_section_toggle_button != null:
		uv_section_toggle_button.text = "Hide UV Editor" if enabled else "Show UV Editor"

func _on_uv_preview_mode_toggled(enabled: bool) -> void:
	uv_preview_vertex_mode = enabled
	if uv_preview_mode_button != null:
		uv_preview_mode_button.text = "Preview: Vertex Colors" if enabled else "Preview: Texture"
	_refresh_uv_controls_from_selection()

func _on_mesh_preview_mode_toggled(enabled: bool) -> void:
	_set_mesh_vertex_preview(enabled)

func _on_paint_color_changed(color: Color) -> void:
	if paint_ui_updating:
		return
	# Color selection is passive; only mouse painting should apply strokes.
	# Keep this callback to preserve signal wiring.
	pass

func _on_paint_vertex_preview_toggled(enabled: bool) -> void:
	_set_mesh_vertex_preview(enabled)

func _set_mesh_vertex_preview(enabled: bool) -> void:
	BRUSH_MESH_BUILDER_SCRIPT.use_vertex_color_preview = enabled
	if mesh_preview_mode_button != null:
		if mesh_preview_mode_button.button_pressed != enabled:
			mesh_preview_mode_button.button_pressed = enabled
		mesh_preview_mode_button.text = "Mesh: Vertex Colors" if enabled else "Mesh: Textures"
	if paint_vertex_preview_button != null:
		if paint_vertex_preview_button.button_pressed != enabled:
			paint_vertex_preview_button.button_pressed = enabled
	_rebuild_all_brush_meshes()

func _paint_from_pick(camera: Camera3D, pick: Dictionary, mouse_pos: Vector2) -> void:
	var target_index := int(pick.get("index", -1))
	var target_face := int(pick.get("face_index", -1))
	if target_index < 0 or target_face < 0:
		return
	if target_index >= map_node.brush_data.size():
		return
	var meshes := _get_brush_meshes()
	if target_index >= meshes.size():
		return
	var target_mesh := meshes[target_index]
	if target_mesh == null:
		return
	var precise_hit := _pick_exact_face_on_brush(target_index, camera, mouse_pos)
	var hit: Vector3 = _get_pick_hit_point_from_mouse(camera, pick, mouse_pos)
	if not precise_hit.is_empty():
		target_face = int(precise_hit.get("face_index", target_face))
		var exact_hit = precise_hit.get("hit", hit)
		if exact_hit is Vector3:
			hit = exact_hit
	_select_brush(target_mesh, target_index)
	_select_face(target_face)
	var radius := float(paint_radius_spinbox.value) if paint_radius_spinbox != null else 1.0
	var strength := float(paint_strength_spinbox.value) if paint_strength_spinbox != null else 0.35
	var col := paint_color_picker.color if paint_color_picker != null else Color.WHITE
	# Interpolate stamps along drag distance so strokes stay continuous like a brush.
	var min_step: float = maxf(radius * 0.2, 0.005)
	if paint_last_stamp == INVALID_STAMP_POINT:
		_paint_at_world_point(target_index, target_face, hit, col, radius, strength, false)
		paint_last_stamp = hit
		_rebuild_painted_brush_mesh(target_index)
		return
	var segment: Vector3 = hit - paint_last_stamp
	var segment_len: float = segment.length()
	if segment_len < 0.0001:
		return
	if segment_len < min_step:
		return
	var stamp_count: int = int(ceil(segment_len / min_step))
	for i in range(1, stamp_count + 1):
		var t: float = float(i) / float(stamp_count)
		var stamp_point: Vector3 = paint_last_stamp.lerp(hit, t)
		_paint_at_world_point(target_index, target_face, stamp_point, col, radius, strength, false)
	paint_last_stamp = hit
	_rebuild_painted_brush_mesh(target_index)

func _pick_exact_face_on_brush(brush_index: int, camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	if map_node == null:
		return {}
	if brush_index < 0 or brush_index >= map_node.brush_data.size():
		return {}
	var brush: BrushForge = map_node.brush_data[brush_index] as BrushForge
	if brush == null:
		return {}
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos).normalized()
	var best_t: float = INF
	var best_face_index: int = -1
	var best_hit: Vector3 = Vector3.ZERO
	var planes: Array = brush.planes
	for i in range(planes.size()):
		var plane: NeoPlane = planes[i] as NeoPlane
		if plane == null:
			continue
		var denom: float = plane.normal.dot(dir)
		if absf(denom) < 0.00001:
			continue
		var t: float = (plane.distance - plane.normal.dot(origin)) / denom
		if t < 0.0:
			continue
		var hit: Vector3 = origin + dir * t
		if not _point_inside_brush_planes(hit, planes, 0.005):
			continue
		if t < best_t:
			best_t = t
			best_face_index = i
			best_hit = hit
	if best_face_index < 0:
		return {}
	return {
		"face_index": best_face_index,
		"hit": best_hit,
		"t": best_t,
	}

func _point_inside_brush_planes(point: Vector3, planes: Array, eps: float) -> bool:
	for p in planes:
		var plane: NeoPlane = p as NeoPlane
		if plane == null:
			continue
		if plane.normal.dot(point) > plane.distance + eps:
			return false
	return true

func _rebuild_painted_brush_mesh(brush_index: int) -> void:
	var meshes := _get_brush_meshes()
	if brush_index < 0 or brush_index >= meshes.size():
		return
	if map_node == null or brush_index >= map_node.brush_data.size():
		return
	var mesh: MeshInstance3D = meshes[brush_index]
	var brush: BrushForge = map_node.brush_data[brush_index] as BrushForge
	if mesh == null or brush == null:
		return
	mesh.mesh = _build_brush_mesh(brush)
	_update_gizmos()

func _paint_at_world_point(brush_index: int, face_index: int, hit: Vector3, color: Color, radius: float, strength: float, rebuild_mesh: bool = true) -> void:
	if map_node == null or brush_index < 0 or brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[brush_index] as BrushForge
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
		"mode": int(paint_blend_mode_option.get_selected_id()) if paint_blend_mode_option != null else PAINT_MODE_NORMAL,
	})
	# Keep only recent strokes for performance and responsiveness.
	if strokes.size() > 8192:
		strokes = strokes.slice(strokes.size() - 8192, strokes.size())
	brush.face_paint_strokes[face_key] = strokes
	if rebuild_mesh:
		_rebuild_painted_brush_mesh(brush_index)

func _on_subdivide_amount_changed(value: float) -> void:
	if subdivide_tool_button == null or not subdivide_tool_button.button_pressed:
		return
	if map_node == null or selected_brush_index < 0 or selected_face_index < 0:
		return
	if selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	var amount := int(clampi(int(round(value)), 1, 10))
	subdivide_amount_spinbox.value = amount
	_begin_history_action()
	brush.face_subdivisions[str(selected_face_index)] = amount
	var meshes := _get_brush_meshes()
	if selected_brush_index >= 0 and selected_brush_index < meshes.size():
		var mesh := meshes[selected_brush_index]
		if mesh != null:
			mesh.mesh = _build_brush_mesh(brush)
	_end_history_action()
	_update_gizmos()

func _on_uv_snap_toggled(enabled: bool) -> void:
	uv_snap_enabled = enabled

func _on_uv_snap_step_changed(value: float) -> void:
	uv_snap_step = clampf(value, 0.001, 64.0)
	if uv_snap_step_spinbox != null and absf(uv_snap_step_spinbox.value - uv_snap_step) > 0.00001:
		uv_snap_step_spinbox.value = uv_snap_step

func _on_uv_zoom_changed(value: float) -> void:
	uv_preview_zoom = clampf(value, 0.25, 16.0)
	if uv_zoom_spinbox != null and absf(uv_zoom_spinbox.value - uv_preview_zoom) > 0.00001:
		uv_zoom_spinbox.value = uv_preview_zoom
	_refresh_uv_controls_from_selection()

func _snap_uv_value(v: float) -> float:
	if not uv_snap_enabled:
		return v
	var step := uv_snap_step if uv_snap_step > 0.000001 else 0.000001
	return round(v / step) * step

func _scale_grid_size(multiplier: float) -> void:
	grid_size = clampf(grid_size * multiplier, 0.03125, 1024.0)
	if grid_size_spinbox != null:
		grid_size_spinbox.value = grid_size

func _apply_uv_controls_to_selected_face() -> void:
	if map_node == null:
		return
	if selected_brush_index < 0 or selected_face_index < 0:
		return
	if selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	var face_key := str(selected_face_index)
	var face_uv = brush.face_uv_transforms.get(face_key, {})
	var uv_dict: Dictionary = {}
	if face_uv is Dictionary:
		uv_dict = (face_uv as Dictionary).duplicate(true)
	uv_dict["scale"] = Vector2(
		_snap_uv_value(float(uv_scale_x_spinbox.value)),
		_snap_uv_value(float(uv_scale_y_spinbox.value))
	)
	uv_dict["offset"] = Vector2(
		_snap_uv_value(float(uv_offset_x_spinbox.value)),
		_snap_uv_value(float(uv_offset_y_spinbox.value))
	)
	uv_dict["rotation"] = deg_to_rad(_snap_uv_value(float(uv_rotation_spinbox.value)))
	var started_here := false
	if not history_action_active:
		_begin_history_action()
		started_here = true
	brush.face_uv_transforms[face_key] = uv_dict
	var meshes := _get_brush_meshes()
	if selected_brush_index >= 0 and selected_brush_index < meshes.size():
		var mesh := meshes[selected_brush_index]
		if mesh != null:
			mesh.mesh = _build_brush_mesh(brush)
	if started_here:
		_end_history_action()
	_refresh_uv_controls_from_selection()

func _refresh_uv_controls_from_selection() -> void:
	if uv_scale_x_spinbox == null:
		return
	uv_controls_updating = true
	if map_node == null or selected_brush_index < 0 or selected_face_index < 0 or selected_brush_index >= map_node.brush_data.size():
		uv_scale_x_spinbox.editable = false
		uv_scale_y_spinbox.editable = false
		uv_offset_x_spinbox.editable = false
		uv_offset_y_spinbox.editable = false
		uv_rotation_spinbox.editable = false
		uv_scale_x_spinbox.value = 1.0
		uv_scale_y_spinbox.value = 1.0
		uv_offset_x_spinbox.value = 0.0
		uv_offset_y_spinbox.value = 0.0
		uv_rotation_spinbox.value = 0.0
		uv_controls_updating = false
		_refresh_uv_preview({})
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		uv_controls_updating = false
		_refresh_uv_preview({})
		return
	uv_scale_x_spinbox.editable = true
	uv_scale_y_spinbox.editable = true
	uv_offset_x_spinbox.editable = true
	uv_offset_y_spinbox.editable = true
	uv_rotation_spinbox.editable = true
	var face_key := str(selected_face_index)
	var face_uv = brush.face_uv_transforms.get(face_key, {})
	var uv_dict: Dictionary = {}
	if face_uv is Dictionary:
		uv_dict = face_uv as Dictionary
	var scale: Vector2 = uv_dict.get("scale", Vector2.ONE)
	var offset: Vector2 = uv_dict.get("offset", Vector2.ZERO)
	var rotation: float = float(uv_dict.get("rotation", 0.0))
	uv_scale_x_spinbox.value = scale.x
	uv_scale_y_spinbox.value = scale.y
	uv_offset_x_spinbox.value = offset.x
	uv_offset_y_spinbox.value = offset.y
	uv_rotation_spinbox.value = rad_to_deg(rotation)
	uv_controls_updating = false
	_refresh_uv_preview(uv_dict)

func _refresh_uv_preview(face_uv: Dictionary) -> void:
	if uv_preview_rect == null:
		return
	var preview_tex := _build_uv_preview_texture(face_uv)
	uv_preview_rect.texture = preview_tex

func _build_uv_preview_texture(face_uv: Dictionary) -> Texture2D:
	var w := 192
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var scale: Vector2 = face_uv.get("scale", Vector2.ONE)
	var offset: Vector2 = face_uv.get("offset", Vector2.ZERO)
	var rotation: float = float(face_uv.get("rotation", 0.0))
	var sx := scale.x if absf(scale.x) > 0.00001 else 1.0
	var sy := scale.y if absf(scale.y) > 0.00001 else 1.0
	var tiles := 8.0 / maxf(uv_preview_zoom, 0.0001)
	for y in range(h):
		for x in range(w):
			var uv := Vector2(float(x) / float(w), float(y) / float(h))
			var p := (uv - Vector2(0.5, 0.5)) * tiles
			var q := p.rotated(-rotation)
			q = Vector2(q.x * sx, q.y * sy) + offset
			var cx := int(floor(q.x))
			var cy := int(floor(q.y))
			var is_dark := ((cx + cy) & 1) == 0
			var fx: float = q.x - floor(q.x)
			var fy: float = q.y - floor(q.y)
			var c := Color(0.20, 0.20, 0.20, 1.0) if is_dark else Color(0.32, 0.32, 0.32, 1.0)
			if uv_preview_vertex_mode:
				c = Color(fx, fy, 1.0 - fx, 1.0)
			elif absf(fx - 0.5) < 0.03 or absf(fy - 0.5) < 0.03:
				c = Color(0.60, 0.60, 0.60, 1.0)
			img.set_pixel(x, y, c)
	var mid_y := int(h / 2)
	var mid_x := int(w / 2)
	for x_axis in range(w):
		img.set_pixel(x_axis, mid_y, Color(1.0, 0.2, 0.2, 1.0))
	for y_axis in range(h):
		img.set_pixel(mid_x, y_axis, Color(0.2, 0.8, 1.0, 1.0))
	return ImageTexture.create_from_image(img)

func _on_uv_preview_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if map_node == null or selected_brush_index < 0 or selected_face_index < 0:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_on_uv_zoom_changed(uv_preview_zoom * 1.15)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_uv_zoom_changed(uv_preview_zoom / 1.15)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				uv_preview_drag_active = true
				uv_preview_rotate_drag = false
				uv_preview_last_mouse = mb.position
				_begin_history_action()
			else:
				uv_preview_drag_active = false
				if history_action_active:
					_end_history_action()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				uv_preview_drag_active = true
				uv_preview_rotate_drag = true
				uv_preview_last_mouse = mb.position
				_begin_history_action()
			else:
				uv_preview_drag_active = false
				if history_action_active:
					_end_history_action()
		return
	if event is InputEventMouseMotion and uv_preview_drag_active:
		var mm := event as InputEventMouseMotion
		var delta: Vector2 = mm.position - uv_preview_last_mouse
		uv_preview_last_mouse = mm.position
		if uv_preview_rotate_drag:
			var rot := float(uv_rotation_spinbox.value) + delta.x * 0.5
			uv_rotation_spinbox.value = _snap_uv_value(rot)
		else:
			var ox := float(uv_offset_x_spinbox.value) + delta.x * 0.02 / maxf(uv_preview_zoom, 0.0001)
			var oy := float(uv_offset_y_spinbox.value) - delta.y * 0.02 / maxf(uv_preview_zoom, 0.0001)
			uv_offset_x_spinbox.value = _snap_uv_value(ox)
			uv_offset_y_spinbox.value = _snap_uv_value(oy)
		_apply_uv_controls_to_selected_face()

func _refresh_texture_menu() -> void:
	texture_material_paths.clear()
	texture_material_names.clear()
	if texture_menu != null:
		texture_menu.clear()
	if texture_list != null:
		texture_list.clear()
	if map_node == null:
		return
	var folder := map_node.material_folder_path.strip_edges()
	if folder == "":
		folder = "res://Mats"
	var material_paths := _collect_material_paths_recursive(folder)
	var utility_materials := [CLIP_MATERIAL_PATH, SKIP_MATERIAL_PATH]
	for p in utility_materials:
		if ResourceLoader.exists(p) and material_paths.find(p) < 0:
			material_paths.append(p)
	material_paths.sort()
	for path in material_paths:
		var mat = load(path)
		if not (mat is Material):
			continue
		var display_name := path.get_file()
		texture_material_paths.append(path)
		texture_material_names.append(display_name)
		texture_menu.add_item(display_name, texture_material_paths.size() - 1)
		var preview := _get_material_preview_texture(path, mat as Material)
		if texture_list != null:
			texture_list.add_item(display_name, preview, true)
			texture_list.set_item_metadata(texture_list.get_item_count() - 1, path)
	if texture_list != null and texture_list.get_item_count() == 0:
		texture_list.add_item("No .tres/.res materials found", null, false)
	_sync_texture_list_selection()

func _collect_material_paths_recursive(root_folder: String) -> Array[String]:
	var out: Array[String] = []
	var stack: Array[String] = [root_folder]
	while not stack.is_empty():
		var current: String = str(stack.pop_back())
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var name := dir.get_next()
			if name == "":
				break
			if name == "." or name == "..":
				continue
			var path: String = current.path_join(name)
			if dir.current_is_dir():
				stack.append(path)
				continue
			var lower := name.to_lower()
			if lower.ends_with(".tres") or lower.ends_with(".res"):
				out.append(path)
		dir.list_dir_end()
	out.sort()
	return out

func _on_texture_menu_id_pressed(id: int) -> void:
	if id < 0 or id >= texture_material_paths.size():
		return
	var material_path: String = str(texture_material_paths[id])
	_apply_texture_material_path(material_path)

func _on_texture_list_item_selected(index: int) -> void:
	if texture_list == null:
		return
	if index < 0 or index >= texture_list.get_item_count():
		return
	var metadata = texture_list.get_item_metadata(index)
	if metadata == null:
		return
	var material_path: String = str(metadata)
	_apply_texture_material_path(material_path)

func _apply_texture_material_path(material_path: String) -> void:
	if selected_brush_index < 0 or selected_face_index < 0:
		return
	if selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	var face_key := str(selected_face_index)
	if str(brush.face_material_paths.get(face_key, "")) == material_path:
		return
	_begin_history_action()
	brush.face_material_paths[face_key] = material_path
	var meshes := _get_brush_meshes()
	if selected_brush_index >= 0 and selected_brush_index < meshes.size():
		var mesh := meshes[selected_brush_index]
		if mesh != null:
			mesh.mesh = _build_brush_mesh(brush)
	_end_history_action()
	_sync_texture_list_selection()
	_refresh_uv_controls_from_selection()
	_update_gizmos()

func _get_material_preview_texture(material_path: String, mat: Material) -> Texture2D:
	if texture_preview_cache.has(material_path):
		var cached = texture_preview_cache[material_path]
		if cached is Texture2D:
			return cached as Texture2D
	var fallback: Texture2D = get_editor_interface().get_base_control().get_theme_icon("Material", "EditorIcons")
	var preview := fallback
	var editor := get_editor_interface()
	if editor != null and editor.has_method("make_mesh_previews"):
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.0, 1.0)
		plane.material = mat
		var meshes: Array = [plane]
		var previews = editor.call("make_mesh_previews", meshes, 64)
		if previews is Array and previews.size() > 0:
			var tex = previews[0]
			if tex is Texture2D:
				preview = tex as Texture2D
	texture_preview_cache[material_path] = preview
	return preview

func _sync_texture_list_selection() -> void:
	if texture_list == null:
		_refresh_uv_controls_from_selection()
		return
	if selected_brush_index < 0 or selected_face_index < 0:
		texture_list.deselect_all()
		_refresh_uv_controls_from_selection()
		return
	if map_node == null or selected_brush_index >= map_node.brush_data.size():
		texture_list.deselect_all()
		_refresh_uv_controls_from_selection()
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		texture_list.deselect_all()
		_refresh_uv_controls_from_selection()
		return
	var face_key := str(selected_face_index)
	var material_path := str(brush.face_material_paths.get(face_key, ""))
	if material_path == "":
		texture_list.deselect_all()
		_refresh_uv_controls_from_selection()
		return
	for i in range(texture_list.get_item_count()):
		var metadata = texture_list.get_item_metadata(i)
		if metadata != null and str(metadata) == material_path:
			texture_list.select(i)
			texture_list.ensure_current_is_visible()
			_refresh_uv_controls_from_selection()
			return
	texture_list.deselect_all()
	_refresh_uv_controls_from_selection()

func _adjust_brush_uv_offsets_for_lock_toggle(brush: BrushForge, enabling_lock: bool) -> void:
	if brush == null:
		return
	var keys := {}
	for k in brush.face_uv_transforms.keys():
		keys[k] = true
	for k in brush.face_material_paths.keys():
		keys[k] = true
	for i in range(6):
		keys[str(i)] = true
	for key in keys.keys():
		var face_index := int(str(key))
		if face_index < 0 or face_index > 5:
			continue
		var uv_basis := _uv_basis_from_face_index(face_index)
		var u_axis: Vector3 = uv_basis["u"]
		var v_axis: Vector3 = uv_basis["v"]
		var shift := Vector2(brush.position.dot(u_axis), brush.position.dot(v_axis))
		var existing = brush.face_uv_transforms.get(str(face_index), {})
		var face_uv: Dictionary = {}
		if existing is Dictionary:
			face_uv = (existing as Dictionary).duplicate(true)
		var scale: Vector2 = face_uv.get("scale", Vector2.ONE)
		var rotation: float = float(face_uv.get("rotation", 0.0))
		var offset: Vector2 = face_uv.get("offset", Vector2.ZERO)
		var sx := scale.x if absf(scale.x) > 0.00001 else 1.0
		var sy := scale.y if absf(scale.y) > 0.00001 else 1.0
		var rotated_shift := shift.rotated(rotation)
		var transformed_shift := Vector2(rotated_shift.x / sx, rotated_shift.y / sy)
		if enabling_lock:
			offset += transformed_shift
		else:
			offset -= transformed_shift
		face_uv["offset"] = offset
		face_uv["scale"] = scale
		face_uv["rotation"] = rotation
		brush.face_uv_transforms[str(face_index)] = face_uv

func _uv_basis_from_face_index(face_index: int) -> Dictionary:
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

func _handles(object: Object) -> bool:
	return true

func _edit(object: Object) -> void:
	if object is BrushForgeMap:
		map_node = object as BrushForgeMap
		_set_plugin_active(true)
		_refresh_texture_menu()
		_sync_texture_list_selection()
		return
	if object is MeshInstance3D:
		var mesh := object as MeshInstance3D
		if mesh.get_parent() is BrushForgeMap:
			map_node = mesh.get_parent() as BrushForgeMap
			_set_plugin_active(true)
			_refresh_texture_menu()
			var idx := _get_brush_meshes().find(mesh)
			if idx >= 0 and idx < map_node.brush_data.size() and _is_custom_tool_enabled():
				_select_brush(mesh, idx)
			return
	# Do not immediately deactivate on unrelated editor focus changes.
	# Activation/deactivation is handled from current selection context in _process().

func _process(_delta: float) -> void:
	var selection_active := _selection_targets_map()
	var custom_tool_active := _is_custom_tool_enabled()
	var should_be_active := selection_active or (custom_tool_active and map_node != null)
	if should_be_active != plugin_active:
		_set_plugin_active(should_be_active)
	if not plugin_active:
		return
	if not _ensure_map_node(false):
		_set_plugin_active(false)
		return
	_lock_all_brush_nodes()
	_sync_selection_refs()
	if _is_custom_tool_enabled():
		_lock_editor_selection()
	_update_tool_button_states()
	_update_texture_panel_visibility()

func _selection_targets_map() -> bool:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return false
	var nodes := selection.get_selected_nodes()
	for node in nodes:
		if node is BrushForgeMap:
			map_node = node as BrushForgeMap
			return true
		if node is MeshInstance3D and (node as MeshInstance3D).get_parent() is BrushForgeMap:
			map_node = (node as MeshInstance3D).get_parent() as BrushForgeMap
			return true
	return false

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not plugin_active:
		return AFTER_GUI_INPUT_PASS
	if not _ensure_map_node(false):
		return AFTER_GUI_INPUT_PASS
	if not _is_custom_tool_enabled():
		return AFTER_GUI_INPUT_PASS

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_MINUS or key_event.keycode == KEY_KP_SUBTRACT:
				_scale_grid_size(0.5)
				return AFTER_GUI_INPUT_STOP
			if key_event.keycode == KEY_EQUAL or key_event.keycode == KEY_PLUS or key_event.keycode == KEY_KP_ADD:
				_scale_grid_size(2.0)
				return AFTER_GUI_INPUT_STOP
			if _is_arrow_key(key_event.keycode):
				if move_brush_button != null and move_brush_button.button_pressed and _handle_trenchbroom_keybinds(key_event):
					return AFTER_GUI_INPUT_STOP
				return AFTER_GUI_INPUT_STOP
			if key_event.keycode == KEY_PAGEUP or key_event.keycode == KEY_PAGEDOWN:
				if move_brush_button != null and move_brush_button.button_pressed and _handle_trenchbroom_keybinds(key_event):
					return AFTER_GUI_INPUT_STOP
				return AFTER_GUI_INPUT_STOP
			if clip_tool_button != null and clip_tool_button.button_pressed:
				if key_event.keycode == KEY_ENTER:
					if _apply_clip_from_points():
						return AFTER_GUI_INPUT_STOP
				if key_event.keycode == KEY_BACKSPACE or key_event.keycode == KEY_DELETE:
					if clip_points.size() > 0:
						clip_points.remove_at(clip_points.size() - 1)
						_update_clip_tool_gizmo()
						return AFTER_GUI_INPUT_STOP
			if move_brush_button != null and move_brush_button.button_pressed and _handle_trenchbroom_keybinds(key_event):
				return AFTER_GUI_INPUT_STOP
			if brush_tool_button != null and brush_tool_button.button_pressed and key_event.keycode == KEY_ENTER:
				if _commit_brush_tool_preview():
					return AFTER_GUI_INPUT_STOP
			if move_brush_button != null and move_brush_button.button_pressed and _is_blocked_editor_transform_key(key_event):
				return AFTER_GUI_INPUT_STOP

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if texture_tool_button != null and texture_tool_button.button_pressed:
			return _handle_texture_tool_mouse_button(camera, mb)
		if paint_tool_button != null and paint_tool_button.button_pressed:
			return _handle_paint_tool_mouse_button(camera, mb)
		if subdivide_tool_button != null and subdivide_tool_button.button_pressed:
			return _handle_subdivide_tool_mouse_button(camera, mb)
		if clip_tool_button != null and clip_tool_button.button_pressed:
			return _handle_clip_tool_mouse_button(camera, mb)
		if brush_tool_button != null and brush_tool_button.button_pressed:
			return _handle_brush_tool_mouse_button(camera, mb)
		if vertex_tool_button != null and vertex_tool_button.button_pressed:
			return _handle_vertex_tool_mouse_button(camera, mb)
		if edge_tool_button != null and edge_tool_button.button_pressed:
			return _handle_edge_tool_mouse_button(camera, mb)
		if face_tool_button != null and face_tool_button.button_pressed:
			return _handle_face_tool_mouse_button(camera, mb)
		if rotate_tool_button != null and rotate_tool_button.button_pressed:
			return _handle_rotate_tool_mouse_button(camera, mb)
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var pick := _pick_brush_and_face(camera, mb.position)
			if pick.is_empty():
				if _is_mouse_near_selected_brush(camera, mb.position):
					if move_brush_button != null and move_brush_button.button_pressed:
						_begin_history_action()
						_begin_move_drag(camera, mb.position, mb.alt_pressed, mb.ctrl_pressed)
					return AFTER_GUI_INPUT_STOP
				_clear_selection()
				return AFTER_GUI_INPUT_STOP

			pending_click_active = true
			pending_click_pick = pick
			pending_click_mouse = mb.position
			if mb.shift_pressed:
				var face_index := int(pick["face_index"])
				_select_brush(pick["mesh"] as MeshInstance3D, int(pick["index"]))
				_select_face(face_index)
				_begin_history_action()
				_begin_face_drag(mb.position, face_index, mb.ctrl_pressed)
				return AFTER_GUI_INPUT_STOP

			_select_brush(pick["mesh"] as MeshInstance3D, int(pick["index"]))
			_clear_face_selection()
			_begin_history_action()
			_begin_move_drag(camera, mb.position, mb.alt_pressed, mb.ctrl_pressed)
			return AFTER_GUI_INPUT_STOP

		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if pending_click_active and not surface_draw_active and not move_drag_active and not face_drag_active:
				_select_brush(pending_click_pick["mesh"] as MeshInstance3D, int(pending_click_pick["index"]))
				_clear_face_selection()

			if move_drag_active or face_drag_active:
				_end_history_action()

			if surface_draw_active:
				_end_history_action()
				var meshes := _get_brush_meshes()
				if surface_draw_brush_index >= 0 and surface_draw_brush_index < meshes.size():
					var mesh := meshes[surface_draw_brush_index]
					if mesh != null:
						_select_brush(mesh, surface_draw_brush_index)

			move_drag_active = false
			face_drag_active = false
			face_drag_ctrl_mode = false
			face_drag_extrude_index = -1
			surface_draw_active = false
			surface_draw_brush_index = -1
			pending_click_active = false
			pending_click_pick = {}
			return AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion and brush_tool_button != null and brush_tool_button.button_pressed:
		var bmm := event as InputEventMouseMotion
		return _handle_brush_tool_mouse_motion(camera, bmm)
	if event is InputEventMouseMotion and paint_tool_button != null and paint_tool_button.button_pressed:
		var pmm := event as InputEventMouseMotion
		return _handle_paint_tool_mouse_motion(camera, pmm)
	if event is InputEventMouseMotion and texture_tool_button != null and texture_tool_button.button_pressed:
		var tmm := event as InputEventMouseMotion
		return _handle_texture_tool_mouse_motion(camera, tmm)
	if event is InputEventMouseMotion and rotate_tool_button != null and rotate_tool_button.button_pressed and rotate_drag_active:
		var rmm := event as InputEventMouseMotion
		_update_rotate_drag(camera, rmm.position)
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and vertex_tool_button != null and vertex_tool_button.button_pressed:
		var vmm := event as InputEventMouseMotion
		return _handle_vertex_tool_mouse_motion(camera, vmm)
	if event is InputEventMouseMotion and edge_tool_button != null and edge_tool_button.button_pressed and vertex_drag_active:
		var emm := event as InputEventMouseMotion
		return _handle_vertex_tool_mouse_motion(camera, emm)
	if event is InputEventMouseMotion and face_tool_button != null and face_tool_button.button_pressed and vertex_drag_active:
		var fsm := event as InputEventMouseMotion
		return _handle_vertex_tool_mouse_motion(camera, fsm)

	if event is InputEventMouseMotion and pending_click_active and not move_drag_active and not face_drag_active and not surface_draw_active:
		var pmm := event as InputEventMouseMotion
		if pmm.position.distance_to(pending_click_mouse) > CLICK_DRAG_THRESHOLD:
			var pending_index := int(pending_click_pick.get("index", -1))
			if pending_index >= 0 and pending_index == selected_brush_index:
				_begin_history_action()
				var pending_mesh := pending_click_pick.get("mesh", null)
				if pending_mesh is MeshInstance3D:
					_select_brush(pending_mesh as MeshInstance3D, pending_index)
				_clear_face_selection()
				_begin_move_drag(camera, pending_click_mouse, false, false)
				return AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion and surface_draw_active:
		var smm := event as InputEventMouseMotion
		_update_surface_draw(camera, smm.position)
		return AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion and face_drag_active:
		var fmm := event as InputEventMouseMotion
		_update_face_drag(camera, fmm.position)
		return AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion and move_drag_active:
		var mm := event as InputEventMouseMotion
		_update_move_drag(camera, mm.position, mm.alt_pressed)
		return AFTER_GUI_INPUT_STOP

	return AFTER_GUI_INPUT_PASS

func _handle_texture_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS
	if not mb.pressed:
		return AFTER_GUI_INPUT_PASS
	var src_brush_index := selected_brush_index
	var src_face_index := selected_face_index
	var pick := _pick_brush_and_face(camera, mb.position)
	if pick.is_empty():
		paint_hover_valid = false
		_update_gizmos()
		return AFTER_GUI_INPUT_PASS
	var target_mesh := pick["mesh"] as MeshInstance3D
	var target_index := int(pick["index"])
	var target_face := int(pick["face_index"])
	if target_mesh == null or target_index < 0 or target_face < 0:
		return AFTER_GUI_INPUT_PASS
	_select_brush(target_mesh, target_index)
	_select_face(target_face)
	_sync_texture_list_selection()
	if mb.alt_pressed and src_brush_index >= 0 and src_face_index >= 0:
		var anchor := _get_pick_hit_point_from_mouse(camera, pick, mb.position)
		_copy_face_texture(src_brush_index, src_face_index, target_index, target_face, anchor)
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_STOP

func _handle_paint_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS
	if not mb.pressed:
		paint_drag_active = false
		paint_last_stamp = INVALID_STAMP_POINT
		if history_action_active:
			_end_history_action()
		return AFTER_GUI_INPUT_STOP
	var pick := _pick_brush_and_face(camera, mb.position)
	if pick.is_empty():
		return AFTER_GUI_INPUT_PASS
	var target_mesh := pick["mesh"] as MeshInstance3D
	var target_index := int(pick["index"])
	var target_face := int(pick["face_index"])
	if target_mesh == null or target_index < 0 or target_face < 0:
		return AFTER_GUI_INPUT_PASS
	_select_brush(target_mesh, target_index)
	_select_face(target_face)
	if paint_apply_mode_option != null and paint_apply_mode_option.get_selected_id() == PAINT_APPLY_BUCKET:
		if not history_action_active:
			_begin_history_action()
		var col := paint_color_picker.color if paint_color_picker != null else Color.WHITE
		_paint_fill_face(target_index, target_face, col)
		_end_history_action()
		paint_drag_active = false
		paint_last_stamp = INVALID_STAMP_POINT
		return AFTER_GUI_INPUT_STOP
	paint_drag_active = true
	paint_last_stamp = INVALID_STAMP_POINT
	if not history_action_active:
		_begin_history_action()
	paint_hover_valid = true
	paint_hover_point = _get_pick_hit_point_from_mouse(camera, pick, mb.position)
	_paint_from_pick(camera, pick, mb.position)
	return AFTER_GUI_INPUT_STOP

func _paint_fill_face(brush_index: int, face_index: int, color: Color) -> void:
	if map_node == null or brush_index < 0 or brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[brush_index] as BrushForge
	if brush == null:
		return
	var key := str(face_index)
	brush.face_paint_colors[key] = color
	# Bucket is an explicit flat fill mode; clear procedural strokes for this face.
	brush.face_paint_strokes[key] = []
	_rebuild_painted_brush_mesh(brush_index)

func _handle_paint_tool_mouse_motion(camera: Camera3D, mm: InputEventMouseMotion) -> int:
	var pick := _pick_brush_and_face(camera, mm.position)
	if pick.is_empty():
		paint_hover_valid = false
		_update_gizmos()
		return AFTER_GUI_INPUT_PASS
	var hit := _get_pick_hit_point_from_mouse(camera, pick, mm.position)
	paint_hover_valid = true
	paint_hover_point = hit
	if paint_drag_active:
		_paint_from_pick(camera, pick, mm.position)
		return AFTER_GUI_INPUT_STOP
	_update_gizmos()
	return AFTER_GUI_INPUT_PASS

func _handle_subdivide_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return AFTER_GUI_INPUT_PASS
	var pick := _pick_brush_and_face(camera, mb.position)
	if pick.is_empty():
		return AFTER_GUI_INPUT_PASS
	var target_mesh := pick["mesh"] as MeshInstance3D
	var target_index := int(pick["index"])
	var target_face := int(pick["face_index"])
	if target_mesh == null or target_index < 0 or target_face < 0:
		return AFTER_GUI_INPUT_PASS
	_select_brush(target_mesh, target_index)
	_select_face(target_face)
	return AFTER_GUI_INPUT_STOP

func _handle_texture_tool_mouse_motion(camera: Camera3D, mm: InputEventMouseMotion) -> int:
	if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return AFTER_GUI_INPUT_PASS
	if not mm.alt_pressed:
		return AFTER_GUI_INPUT_PASS
	if selected_brush_index < 0 or selected_face_index < 0:
		return AFTER_GUI_INPUT_PASS
	var src_brush_index := selected_brush_index
	var src_face_index := selected_face_index
	var pick := _pick_brush_and_face(camera, mm.position)
	if pick.is_empty():
		return AFTER_GUI_INPUT_PASS
	var target_mesh := pick["mesh"] as MeshInstance3D
	var target_index := int(pick["index"])
	var target_face := int(pick["face_index"])
	if target_mesh == null or target_index < 0 or target_face < 0:
		return AFTER_GUI_INPUT_PASS
	if src_brush_index == target_index and src_face_index == target_face:
		return AFTER_GUI_INPUT_PASS
	var anchor := _get_pick_hit_point_from_mouse(camera, pick, mm.position)
	_copy_face_texture(src_brush_index, src_face_index, target_index, target_face, anchor)
	_select_brush(target_mesh, target_index)
	_select_face(target_face)
	_sync_texture_list_selection()
	return AFTER_GUI_INPUT_STOP

func _copy_face_texture(src_brush_index: int, src_face_index: int, dst_brush_index: int, dst_face_index: int, anchor_world: Variant = null) -> void:
	if map_node == null:
		return
	if src_brush_index < 0 or src_brush_index >= map_node.brush_data.size():
		return
	if dst_brush_index < 0 or dst_brush_index >= map_node.brush_data.size():
		return
	var src_brush: BrushForge = map_node.brush_data[src_brush_index] as BrushForge
	var dst_brush: BrushForge = map_node.brush_data[dst_brush_index] as BrushForge
	if src_brush == null or dst_brush == null:
		return
	var src_mat_key := str(src_face_index)
	if not src_brush.face_material_paths.has(src_mat_key):
		return
	var dst_mat_key := str(dst_face_index)
	var src_mat_path := str(src_brush.face_material_paths[src_mat_key])
	var dst_mat_path := str(dst_brush.face_material_paths.get(dst_mat_key, ""))
	var src_uv := src_brush.face_uv_transforms.get(src_mat_key, null)
	var dst_uv = dst_brush.face_uv_transforms.get(dst_mat_key, null)
	if src_mat_path == dst_mat_path and src_uv == dst_uv:
		return
	_begin_history_action()
	dst_brush.face_material_paths[dst_mat_key] = src_mat_path
	if src_brush.face_uv_transforms.has(src_mat_key):
		var copied_uv: Dictionary = src_brush.face_uv_transforms[src_mat_key].duplicate(true)
		dst_brush.face_uv_transforms[dst_mat_key] = _align_copied_uv_transform(src_brush, src_face_index, dst_brush, dst_face_index, copied_uv, anchor_world)
	var meshes := _get_brush_meshes()
	if dst_brush_index >= 0 and dst_brush_index < meshes.size():
		var mesh := meshes[dst_brush_index]
		if mesh != null:
			mesh.mesh = _build_brush_mesh(dst_brush)
	_end_history_action()
	_refresh_uv_controls_from_selection()
	_update_gizmos()

func _align_copied_uv_transform(src_brush: BrushForge, src_face_index: int, dst_brush: BrushForge, dst_face_index: int, copied_uv: Dictionary, anchor_world: Variant = null) -> Dictionary:
	if copied_uv.is_empty():
		return copied_uv
	var src_basis := _face_uv_basis_from_brush_face(src_brush, src_face_index)
	var dst_basis := _face_uv_basis_from_brush_face(dst_brush, dst_face_index)
	if src_basis.is_empty() or dst_basis.is_empty():
		return copied_uv
	var src_uv := copied_uv.duplicate(true)
	var src_u: Vector3 = src_basis["u"]
	var src_v: Vector3 = src_basis["v"]
	var dst_u: Vector3 = dst_basis["u"]
	var dst_v: Vector3 = dst_basis["v"]
	var dst_n: Vector3 = dst_basis["normal"]
	var src_rot := float(src_uv.get("rotation", 0.0))
	var src_u_rot := (src_u * cos(src_rot) - src_v * sin(src_rot)).normalized()
	var src_v_rot := (src_u * sin(src_rot) + src_v * cos(src_rot)).normalized()
	var projected_u := src_u_rot - dst_n * src_u_rot.dot(dst_n)
	var projected_v := src_v_rot - dst_n * src_v_rot.dot(dst_n)
	if projected_u.length() < 0.00001 and projected_v.length() < 0.00001:
		return copied_uv
	var rot_candidates: Array[float] = []
	if projected_u.length() >= 0.00001:
		var t_u := projected_u.normalized()
		rot_candidates.append(atan2(-t_u.dot(dst_v), t_u.dot(dst_u)))
	if projected_v.length() >= 0.00001:
		var t_v := projected_v.normalized()
		rot_candidates.append(atan2(t_v.dot(dst_u), t_v.dot(dst_v)))
	if rot_candidates.is_empty():
		return copied_uv
	var best_rot: float = float(rot_candidates[0])
	var best_err: float = INF
	for rr in rot_candidates:
		var rrf: float = float(rr)
		for off in [0.0, PI]:
			var cand: float = rrf + float(off)
			var pred_u := (dst_u * cos(cand) - dst_v * sin(cand)).normalized()
			var pred_v := (dst_u * sin(cand) + dst_v * cos(cand)).normalized()
			var err: float = 0.0
			if projected_u.length() >= 0.00001:
				var t_u := projected_u.normalized()
				err += 1.0 - clampf(pred_u.dot(t_u), -1.0, 1.0)
			if projected_v.length() >= 0.00001:
				var t_v := projected_v.normalized()
				err += 1.0 - clampf(pred_v.dot(t_v), -1.0, 1.0)
			if err < best_err:
				best_err = err
				best_rot = cand
	var aligned_rot: float = best_rot
	copied_uv["rotation"] = aligned_rot
	var anchor: Vector3 = anchor_world if anchor_world is Vector3 else _face_center_world(dst_brush, dst_face_index)
	var src_anchor_uv := _compute_uv_with_face_basis(anchor, src_basis, src_uv)
	var dst_uv_no_offset := _compute_uv_with_face_basis(anchor, dst_basis, {
		"scale": src_uv.get("scale", Vector2.ONE),
		"rotation": aligned_rot,
		"offset": Vector2.ZERO,
	})
	copied_uv["offset"] = src_anchor_uv - dst_uv_no_offset
	return copied_uv

func _face_uv_basis_from_brush_face(brush: BrushForge, face_index: int) -> Dictionary:
	if brush == null or face_index < 0 or face_index >= brush.planes.size():
		return {}
	var plane: NeoPlane = brush.planes[face_index] as NeoPlane
	if plane == null:
		return {}
	var normal := plane.normal.normalized()
	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := normal.cross(tangent).normalized()
	return {"normal": normal, "u": tangent, "v": bitangent}

func _compute_uv_with_face_basis(point_world: Vector3, basis: Dictionary, uv_dict: Dictionary) -> Vector2:
	var u_axis: Vector3 = basis.get("u", Vector3.RIGHT)
	var v_axis: Vector3 = basis.get("v", Vector3.UP)
	var uv := Vector2(point_world.dot(u_axis), point_world.dot(v_axis))
	var rotation := float(uv_dict.get("rotation", 0.0))
	if absf(rotation) > 0.00001:
		uv = uv.rotated(rotation)
	var scale: Vector2 = uv_dict.get("scale", Vector2.ONE)
	var sx := scale.x if absf(scale.x) > 0.00001 else 1.0
	var sy := scale.y if absf(scale.y) > 0.00001 else 1.0
	uv = Vector2(uv.x / sx, uv.y / sy)
	var offset: Vector2 = uv_dict.get("offset", Vector2.ZERO)
	return uv + offset

func _face_center_world(brush: BrushForge, face_index: int) -> Vector3:
	if brush == null or face_index < 0 or face_index >= brush.planes.size():
		return brush.position if brush != null else Vector3.ZERO
	var plane: NeoPlane = brush.planes[face_index] as NeoPlane
	if plane == null:
		return brush.position
	var verts := _get_brush_vertices_world(brush)
	if verts.is_empty():
		return brush.position
	var center := Vector3.ZERO
	var count := 0
	for v in verts:
		if absf(plane.normal.dot(v) - plane.distance) <= 0.02:
			center += v
			count += 1
	if count == 0:
		return brush.position
	return center / float(count)

func _handle_brush_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS

	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if mb.shift_pressed and brush_draw_has_rect:
			brush_extrude_active = true
			drag_start_mouse = mb.position
			brush_extrude_depth = grid_size
			_update_brush_tool_gizmos()
			return AFTER_GUI_INPUT_STOP

		var pick := _pick_brush_and_face(camera, mb.position)
		if pick.is_empty():
			return AFTER_GUI_INPUT_STOP
		_select_brush(pick["mesh"] as MeshInstance3D, int(pick["index"]))
		var face_index := int(pick["face_index"])
		var hit := _get_pick_hit_point_from_mouse(camera, pick, mb.position)
		_begin_brush_rect_draw(face_index, hit)
		brush_draw_active = true
		return AFTER_GUI_INPUT_STOP

	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		brush_draw_active = false
		brush_extrude_active = false
		return AFTER_GUI_INPUT_STOP

	return AFTER_GUI_INPUT_STOP

func _handle_brush_tool_mouse_motion(camera: Camera3D, mm: InputEventMouseMotion) -> int:
	if brush_draw_active:
		_update_brush_rect_from_mouse(camera, mm.position)
		return AFTER_GUI_INPUT_STOP
	if brush_extrude_active and brush_draw_has_rect:
		var raw := _axis_delta_from_mouse(camera, brush_draw_plane_origin, brush_draw_face_normal, mm.position)
		brush_extrude_depth = _snap_float(raw, grid_size)
		if absf(brush_extrude_depth) < grid_size:
			brush_extrude_depth = signf(brush_extrude_depth) * grid_size if absf(brush_extrude_depth) > 0.0 else grid_size
		_update_brush_tool_gizmos()
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _handle_vertex_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS

	if mb.pressed:
		if selected_brush_index < 0:
			var pick := _pick_brush_and_face(camera, mb.position)
			if pick.is_empty():
				return AFTER_GUI_INPUT_STOP
			_select_brush(pick["mesh"] as MeshInstance3D, int(pick["index"]))
		var vertex_index := _pick_vertex_on_selected_brush(camera, mb.position)
		if vertex_index < 0:
			if not mb.ctrl_pressed:
				selected_vertex_indices.clear()
				selected_vertex_anchor = Vector3.ZERO
			_update_gizmos()
			return AFTER_GUI_INPUT_STOP

		if mb.ctrl_pressed:
			var existing := selected_vertex_indices.find(vertex_index)
			if existing >= 0:
				selected_vertex_indices.remove_at(existing)
			else:
				selected_vertex_indices.append(vertex_index)
			var anchor = _get_selected_vertices_anchor_world()
			if anchor is Vector3:
				selected_vertex_anchor = anchor
			else:
				selected_vertex_anchor = Vector3.ZERO
			_update_gizmos()
			return AFTER_GUI_INPUT_STOP

		selected_vertex_indices.clear()
		selected_vertex_indices.append(vertex_index)
		var selected_anchor = _get_selected_vertices_anchor_world()
		if not (selected_anchor is Vector3):
			return AFTER_GUI_INPUT_STOP
		var selected_anchor_v: Vector3 = selected_anchor
		selected_vertex_anchor = selected_anchor_v
		_begin_history_action()
		_begin_vertex_drag(camera, mb.position, mb.alt_pressed, selected_anchor_v)
		_update_gizmos()
		return AFTER_GUI_INPUT_STOP

	if vertex_drag_active:
		_end_history_action()
	vertex_drag_active = false
	vertex_drag_plane_indices.clear()
	vertex_drag_start_planes.clear()
	vertex_drag_start_vertices.clear()
	vertex_drag_plane_vertex_indices.clear()
	return AFTER_GUI_INPUT_STOP

func _handle_vertex_tool_mouse_motion(camera: Camera3D, mm: InputEventMouseMotion) -> int:
	if not vertex_drag_active:
		return AFTER_GUI_INPUT_PASS
	_update_vertex_drag(camera, mm.position, mm.alt_pressed)
	return AFTER_GUI_INPUT_STOP

func _handle_edge_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS
	if mb.pressed:
		if selected_brush_index < 0:
			var pick := _pick_brush_and_face(camera, mb.position)
			if pick.is_empty():
				return AFTER_GUI_INPUT_STOP
			_select_brush(pick["mesh"] as MeshInstance3D, int(pick["index"]))
		var edge := _pick_edge_on_selected_brush(camera, mb.position)
		if edge.is_empty():
			if not mb.ctrl_pressed:
				selected_vertex_indices.clear()
			_update_gizmos()
			return AFTER_GUI_INPUT_STOP
		var edge_indices: Array[int] = [int(edge["a"]), int(edge["b"])]
		if mb.ctrl_pressed:
			_toggle_vertex_indices(edge_indices)
			var ctrl_anchor := _get_selected_vertices_anchor_world()
			if ctrl_anchor is Vector3:
				selected_vertex_anchor = ctrl_anchor
			else:
				selected_vertex_anchor = Vector3.ZERO
			_update_gizmos()
			return AFTER_GUI_INPUT_STOP
		selected_vertex_indices.clear()
		for idx in edge_indices:
			if selected_vertex_indices.find(idx) < 0:
				selected_vertex_indices.append(idx)
		_clear_face_selection()
		var anchor := _get_selected_vertices_anchor_world()
		if not (anchor is Vector3):
			return AFTER_GUI_INPUT_STOP
		selected_vertex_anchor = anchor
		_begin_history_action()
		_begin_vertex_drag(camera, mb.position, mb.alt_pressed, selected_vertex_anchor)
		_update_gizmos()
		return AFTER_GUI_INPUT_STOP
	if vertex_drag_active:
		_end_history_action()
	vertex_drag_active = false
	vertex_drag_plane_indices.clear()
	vertex_drag_start_planes.clear()
	vertex_drag_start_vertices.clear()
	vertex_drag_plane_vertex_indices.clear()
	return AFTER_GUI_INPUT_STOP

func _handle_face_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS
	if mb.pressed:
		var pick := _pick_brush_and_face(camera, mb.position)
		if pick.is_empty():
			if not mb.ctrl_pressed:
				selected_vertex_indices.clear()
				_clear_face_selection()
				_update_gizmos()
			return AFTER_GUI_INPUT_STOP
		_select_brush(pick["mesh"] as MeshInstance3D, int(pick["index"]))
		var face_index := int(pick["face_index"])
		var face_vertices := _get_face_vertex_indices(face_index)
		if mb.ctrl_pressed:
			_toggle_vertex_indices(face_vertices)
			_select_face(face_index)
			var ctrl_anchor := _get_selected_vertices_anchor_world()
			if ctrl_anchor is Vector3:
				selected_vertex_anchor = ctrl_anchor
			else:
				selected_vertex_anchor = Vector3.ZERO
			_update_gizmos()
			return AFTER_GUI_INPUT_STOP
		_select_face(face_index)
		selected_vertex_indices.clear()
		for idx in face_vertices:
			if selected_vertex_indices.find(idx) < 0:
				selected_vertex_indices.append(idx)
		if selected_vertex_indices.is_empty():
			return AFTER_GUI_INPUT_STOP
		var anchor := _get_selected_vertices_anchor_world()
		if not (anchor is Vector3):
			return AFTER_GUI_INPUT_STOP
		selected_vertex_anchor = anchor
		_begin_history_action()
		_begin_vertex_drag(camera, mb.position, mb.alt_pressed, selected_vertex_anchor)
		_update_gizmos()
		return AFTER_GUI_INPUT_STOP
	if vertex_drag_active:
		_end_history_action()
	vertex_drag_active = false
	vertex_drag_plane_indices.clear()
	vertex_drag_start_planes.clear()
	vertex_drag_start_vertices.clear()
	vertex_drag_plane_vertex_indices.clear()
	return AFTER_GUI_INPUT_STOP

func _handle_rotate_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS
	if mb.pressed:
		var pick := _pick_brush_and_face(camera, mb.position)
		if pick.is_empty():
			return AFTER_GUI_INPUT_STOP
		_select_brush(pick["mesh"] as MeshInstance3D, int(pick["index"]))
		var axis_override := _pick_rotate_axis(camera, mb.position)
		_begin_history_action()
		_begin_rotate_drag(int(pick["face_index"]), mb.position, axis_override)
	else:
		if rotate_drag_active:
			_end_history_action()
		rotate_drag_active = false
		rotate_drag_start_planes.clear()
		_update_gizmos()
	return AFTER_GUI_INPUT_STOP

func _begin_rotate_drag(face_index: int, mouse_pos: Vector2, axis_override: Vector3 = Vector3.ZERO) -> void:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	rotate_drag_active = true
	drag_start_mouse = mouse_pos
	rotate_drag_center = brush.position
	rotate_drag_start_planes = _clone_plane_array(brush.planes)
	if axis_override.length() > 0.0:
		rotate_drag_axis = axis_override.normalized()
		return
	match face_index:
		0, 1:
			rotate_drag_axis = Vector3.RIGHT
		2, 3:
			rotate_drag_axis = Vector3.UP
		_:
			rotate_drag_axis = Vector3.BACK

func _update_rotate_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if not rotate_drag_active:
		return
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	var meshes := _get_brush_meshes()
	if selected_brush_index < 0 or selected_brush_index >= meshes.size():
		return
	var mesh := meshes[selected_brush_index]
	if mesh == null:
		return
	var screen_delta := mouse_pos - drag_start_mouse
	var axis_sign := 1.0
	if rotate_drag_axis == Vector3.RIGHT:
		axis_sign = -1.0
	elif rotate_drag_axis == Vector3.BACK:
		axis_sign = -1.0
	var raw_angle: float = (screen_delta.x + screen_delta.y * 0.35) * ROTATE_RADIANS_PER_PIXEL * axis_sign
	var angle: float = float(round(raw_angle / ROTATE_SNAP_RADIANS)) * ROTATE_SNAP_RADIANS
	var rot_basis := Basis(rotate_drag_axis.normalized(), angle)
	_restore_brush_planes_from_snapshot(brush, rotate_drag_start_planes)
	for i in range(brush.planes.size()):
		var src: NeoPlane = rotate_drag_start_planes[i] as NeoPlane
		if src == null:
			continue
		var n0: Vector3 = src.normal
		var n1 := (rot_basis * n0).normalized()
		var d1 := src.distance + n1.dot(rotate_drag_center) - n0.dot(rotate_drag_center)
		brush.planes[i] = NeoPlane.new(n1, d1)
	var rotated_vertices := _get_brush_vertices_world(brush)
	if rotated_vertices.size() < 4:
		_restore_brush_planes_from_snapshot(brush, rotate_drag_start_planes)
		mesh.mesh = _build_brush_mesh(brush)
		_update_gizmos()
		return
	_refresh_brush_bounds_from_planes(brush, mesh)
	_update_gizmos()

func _pick_rotate_axis(camera: Camera3D, mouse_pos: Vector2) -> Vector3:
	if selected_mesh == null:
		return Vector3.ZERO
	var b := _mesh_bounds_world(selected_mesh)
	var center: Vector3 = b["center"]
	var half_size: Vector3 = b["half_size"]
	var radius := maxf(maxf(half_size.x, half_size.y), half_size.z) * 1.25
	radius = maxf(radius, grid_size)
	var screen_center := camera.unproject_position(center)
	var best_axis := Vector3.ZERO
	var best_dist := INF
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for axis in axes:
		var tip := camera.unproject_position(center + axis * radius)
		var nearest := Geometry2D.get_closest_point_to_segment(mouse_pos, screen_center, tip)
		var d := nearest.distance_to(mouse_pos)
		if d < best_dist:
			best_dist = d
			best_axis = axis
	if best_dist <= 18.0:
		return best_axis
	return Vector3.ZERO

func _begin_vertex_drag(camera: Camera3D, mouse_pos: Vector2, alt_pressed: bool, start_anchor: Vector3) -> void:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	if selected_vertex_indices.is_empty():
		return
	vertex_drag_active = true
	vertex_drag_start_anchor = start_anchor
	vertex_drag_start_planes = _clone_plane_array(brush.planes)
	vertex_drag_start_vertices = _get_brush_vertices_world(brush)
	vertex_drag_plane_vertex_indices = _build_plane_vertex_incidence(brush, vertex_drag_start_vertices)
	var selected_vertices := _get_selected_vertices_world(brush)
	vertex_drag_plane_indices = _resolve_drag_plane_indices(brush, selected_vertices)
	drag_start_mouse = mouse_pos
	drag_alt_mode = alt_pressed
	drag_plane_y = start_anchor.y
	var plane_hit_hit := _ray_plane_hit(camera, mouse_pos, drag_plane_y)
	if plane_hit_hit != null:
		var plane_hit: Vector3 = plane_hit_hit
		drag_start_plane_hit = plane_hit
	else:
		drag_start_plane_hit = start_anchor

func _update_vertex_drag(camera: Camera3D, mouse_pos: Vector2, alt_pressed: bool) -> void:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	var meshes := _get_brush_meshes()
	if selected_brush_index < 0 or selected_brush_index >= meshes.size():
		return
	var mesh := meshes[selected_brush_index]
	if mesh == null:
		return

	if alt_pressed != drag_alt_mode:
		drag_alt_mode = alt_pressed
		drag_start_mouse = mouse_pos
		vertex_drag_start_anchor = selected_vertex_anchor
		vertex_drag_start_planes = _clone_plane_array(brush.planes)
		vertex_drag_start_vertices = _get_brush_vertices_world(brush)
		vertex_drag_plane_vertex_indices = _build_plane_vertex_incidence(brush, vertex_drag_start_vertices)
		var selected_vertices := _get_selected_vertices_world(brush)
		vertex_drag_plane_indices = _resolve_drag_plane_indices(brush, selected_vertices)
		drag_plane_y = vertex_drag_start_anchor.y
		var new_plane_hit_hit := _ray_plane_hit(camera, mouse_pos, drag_plane_y)
		if new_plane_hit_hit != null:
			var new_plane_hit: Vector3 = new_plane_hit_hit
			drag_start_plane_hit = new_plane_hit

	var target := vertex_drag_start_anchor
	if alt_pressed:
		var dy := drag_start_mouse.y - mouse_pos.y
		var units_per_pixel := _world_units_per_pixel_at(camera, vertex_drag_start_anchor)
		var raw_y := vertex_drag_start_anchor.y + dy * units_per_pixel * MOVE_SENSITIVITY_Y_SCALE
		var y_delta := raw_y - vertex_drag_start_anchor.y
		y_delta = _snap_float(y_delta, grid_size)
		target.y = vertex_drag_start_anchor.y + y_delta
	else:
		var plane_hit_hit := _ray_plane_hit(camera, mouse_pos, drag_plane_y)
		if plane_hit_hit != null:
			var plane_hit: Vector3 = plane_hit_hit
			var delta_plane: Vector3 = plane_hit - drag_start_plane_hit
			target.x = vertex_drag_start_anchor.x + delta_plane.x
			target.z = vertex_drag_start_anchor.z + delta_plane.z
			target.y = drag_plane_y
		else:
			var screen_delta := mouse_pos - drag_start_mouse
			var right := camera.global_transform.basis.x
			var forward := -camera.global_transform.basis.z
			right.y = 0.0
			forward.y = 0.0
			if right.length() > 0.0001:
				right = right.normalized()
			if forward.length() > 0.0001:
				forward = forward.normalized()
			var world_delta := right * screen_delta.x * MOVE_SENSITIVITY_XZ_FALLBACK
			world_delta += forward * screen_delta.y * MOVE_SENSITIVITY_XZ_FALLBACK
			target.x = vertex_drag_start_anchor.x + world_delta.x
			target.z = vertex_drag_start_anchor.z + world_delta.z
			target.y = drag_plane_y

	var delta := target - vertex_drag_start_anchor
	delta = _snap_vector(delta, grid_size)
	_restore_brush_planes_from_snapshot(brush, vertex_drag_start_planes)

	var moved_vertices: Array[Vector3] = []
	for v in vertex_drag_start_vertices:
		moved_vertices.append(v)
	for vi in selected_vertex_indices:
		if vi >= 0 and vi < moved_vertices.size():
			moved_vertices[vi] = moved_vertices[vi] + delta

	for plane_idx in vertex_drag_plane_indices:
		var pi := int(plane_idx)
		if pi < 0 or pi >= brush.planes.size():
			continue
		if pi >= vertex_drag_plane_vertex_indices.size():
			continue
		var incident: Array = vertex_drag_plane_vertex_indices[pi]
		if incident.is_empty():
			continue
		var points: Array[Vector3] = []
		for vi in incident:
			var idx := int(vi)
			if idx >= 0 and idx < moved_vertices.size():
				points.append(moved_vertices[idx])
		if points.size() < 3:
			continue
		var ref_plane: NeoPlane = vertex_drag_start_planes[pi] as NeoPlane
		if ref_plane == null:
			continue
		var fitted := _fit_plane_from_points(points, ref_plane.normal)
		if fitted == null:
			continue
		brush.planes[pi] = fitted
	selected_vertex_anchor = vertex_drag_start_anchor + delta
	_refresh_brush_bounds_from_planes(brush, mesh)
	_update_gizmos()

func _pick_vertex_on_selected_brush(camera: Camera3D, mouse_pos: Vector2) -> int:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return -1
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return -1
	var vertices := _get_brush_vertices_world(brush)
	if vertices.is_empty():
		return -1
	var best_idx := -1
	var best_dist := INF
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		var s := camera.unproject_position(v)
		var d := s.distance_to(mouse_pos)
		if d < best_dist:
			best_dist = d
			best_idx = i
	if best_dist > 16.0:
		return -1
	return best_idx

func _pick_edge_on_selected_brush(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return {}
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return {}
	var vertices := _get_brush_vertices_world(brush)
	if vertices.size() < 2:
		return {}
	var edges := _build_candidate_edges(brush, vertices)
	if edges.is_empty():
		return {}
	var best := {}
	var best_d := INF
	for e in edges:
		var a := int(e["a"])
		var b := int(e["b"])
		var sa := camera.unproject_position(vertices[a])
		var sb := camera.unproject_position(vertices[b])
		var d := Geometry2D.get_closest_point_to_segment(mouse_pos, sa, sb).distance_to(mouse_pos)
		if d < best_d:
			best_d = d
			best = e
	if best_d > 14.0:
		return {}
	return best

func _build_candidate_edges(brush: BrushForge, vertices: Array[Vector3]) -> Array:
	var edges := []
	for i in range(vertices.size()):
		var pi := _incident_plane_indices_for_vertex(brush, vertices[i])
		for j in range(i + 1, vertices.size()):
			var pj := _incident_plane_indices_for_vertex(brush, vertices[j])
			var shared := 0
			for idx in pi:
				if pj.find(idx) >= 0:
					shared += 1
			if shared >= 2:
				edges.append({"a": i, "b": j})
	return edges

func _set_selected_vertices_from_face_index(face_index: int) -> void:
	selected_vertex_indices.clear()
	var face_indices := _get_face_vertex_indices(face_index)
	for idx in face_indices:
		if selected_vertex_indices.find(idx) < 0:
			selected_vertex_indices.append(idx)

func _get_face_vertex_indices(face_index: int) -> Array[int]:
	var out: Array[int] = []
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return out
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return out
	var vertices := _get_brush_vertices_world(brush)
	if vertices.is_empty() or face_index < 0 or face_index >= brush.planes.size():
		return out
	var plane: NeoPlane = brush.planes[face_index] as NeoPlane
	if plane == null:
		return out
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		if absf(plane.normal.dot(v) - plane.distance) <= 0.02:
			out.append(i)
	return out

func _toggle_vertex_indices(indices: Array[int]) -> void:
	for idx in indices:
		var existing := selected_vertex_indices.find(idx)
		if existing >= 0:
			selected_vertex_indices.remove_at(existing)
		else:
			selected_vertex_indices.append(idx)

func _find_nearest_vertex_index(vertices: Array[Vector3], point: Vector3) -> int:
	if vertices.is_empty():
		return -1
	var best_idx := -1
	var best_d := INF
	for i in range(vertices.size()):
		var d := vertices[i].distance_to(point)
		if d < best_d:
			best_d = d
			best_idx = i
	return best_idx

func _get_selected_vertices_world(brush: BrushForge) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if brush == null:
		return out
	var vertices := _get_brush_vertices_world(brush)
	if vertices.is_empty():
		return out
	for idx in selected_vertex_indices:
		if idx >= 0 and idx < vertices.size():
			out.append(vertices[idx])
	return out

func _get_selected_vertices_anchor_world() -> Variant:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return null
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return null
	var selected_vertices := _get_selected_vertices_world(brush)
	if selected_vertices.is_empty():
		return null
	var acc := Vector3.ZERO
	for v in selected_vertices:
		acc += v
	return acc / float(selected_vertices.size())

func _shared_plane_indices_for_vertices(brush: BrushForge, vertices: Array[Vector3]) -> Array[int]:
	var out: Array[int] = []
	if brush == null or vertices.is_empty():
		return out
	var shared := _incident_plane_indices_for_vertex(brush, vertices[0])
	for i in range(1, vertices.size()):
		var vv: Vector3 = vertices[i]
		var inc := _incident_plane_indices_for_vertex(brush, vv)
		var next_shared: Array[int] = []
		for idx in shared:
			if inc.find(idx) >= 0:
				next_shared.append(idx)
		shared = next_shared
	if shared.is_empty():
		shared = _incident_plane_indices_for_vertex(brush, vertices[0])
	return shared

func _resolve_drag_plane_indices(brush: BrushForge, vertices: Array[Vector3]) -> Array[int]:
	var out: Array[int] = []
	if brush == null or vertices.is_empty():
		return out
	if vertices.size() == 1:
		var single: Vector3 = vertices[0]
		return _best_fit_plane_indices_for_vertices(brush, [single], 3)
	var shared := _shared_plane_indices_for_vertices(brush, vertices)
	if not shared.is_empty():
		return shared
	# If strict shared-set fails, use union of incident planes so selected elements still move.
	var union_map := {}
	for vv in vertices:
		var incident := _incident_plane_indices_for_vertex(brush, vv)
		for pi in incident:
			union_map[int(pi)] = true
	for k in union_map.keys():
		out.append(int(k))
	out.sort()
	return out

func _best_fit_plane_indices_for_vertices(brush: BrushForge, vertices: Array[Vector3], target_count: int) -> Array[int]:
	var scored := []
	if brush == null or vertices.is_empty():
		var empty: Array[int] = []
		return empty
	for i in range(brush.planes.size()):
		var plane: NeoPlane = brush.planes[i] as NeoPlane
		if plane == null:
			continue
		var max_err := 0.0
		var sum_err := 0.0
		for v in vertices:
			var err := absf(plane.normal.dot(v) - plane.distance)
			max_err = maxf(max_err, err)
			sum_err += err
		scored.append({
			"i": i,
			"max_err": max_err,
			"avg_err": sum_err / float(vertices.size()),
		})
	scored.sort_custom(func(a, b):
		if a["max_err"] == b["max_err"]:
			return a["avg_err"] < b["avg_err"]
		return a["max_err"] < b["max_err"]
	)
	var out: Array[int] = []
	for s in scored:
		out.append(int(s["i"]))
		if out.size() >= max(target_count, 1):
			break
	return out

func _build_plane_vertex_incidence(brush: BrushForge, vertices: Array[Vector3]) -> Array:
	var out: Array = []
	if brush == null:
		return out
	out.resize(brush.planes.size())
	for pi in range(brush.planes.size()):
		var incident := []
		var plane: NeoPlane = brush.planes[pi] as NeoPlane
		if plane != null:
			for vi in range(vertices.size()):
				var v: Vector3 = vertices[vi]
				if absf(plane.normal.dot(v) - plane.distance) <= 0.02:
					incident.append(vi)
		out[pi] = incident
	return out

func _fit_plane_from_points(points: Array[Vector3], reference_normal: Vector3) -> Variant:
	if points.size() < 3:
		return null
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var normal_ref := reference_normal
	if normal_ref.length() < 0.0001:
		normal_ref = Vector3.UP
	else:
		normal_ref = normal_ref.normalized()
	var tangent := Vector3.RIGHT
	if absf(normal_ref.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal_ref * tangent.dot(normal_ref)).normalized()
	var bitangent := normal_ref.cross(tangent).normalized()
	var ordered := []
	for p in points:
		var d := p - center
		var ang := atan2(d.dot(bitangent), d.dot(tangent))
		ordered.append({"a": ang, "p": p})
	ordered.sort_custom(func(x, y): return x["a"] < y["a"])
	var normal := Vector3.ZERO
	for i in range(ordered.size()):
		var p0: Vector3 = ordered[i]["p"]
		var p1: Vector3 = ordered[(i + 1) % ordered.size()]["p"]
		normal += p0.cross(p1)
	if normal.length() < 0.0001:
		return null
	normal = normal.normalized()
	if normal.dot(normal_ref) < 0.0:
		normal = -normal
	var first: Vector3 = ordered[0]["p"]
	var distance := normal.dot(first)
	return NeoPlane.new(normal, distance)

func _incident_plane_indices_for_vertex(brush: BrushForge, vertex: Vector3) -> Array[int]:
	var out: Array[int] = []
	if brush == null:
		return out
	var scored := []
	for i in range(brush.planes.size()):
		var plane: NeoPlane = brush.planes[i] as NeoPlane
		if plane == null:
			continue
		var err := absf(plane.normal.dot(vertex) - plane.distance)
		scored.append({"i": i, "e": err})
		if err <= 0.02:
			out.append(i)
	if out.size() >= 3:
		return out
	scored.sort_custom(func(a, b): return a["e"] < b["e"])
	for s in scored:
		var idx := int(s["i"])
		if out.find(idx) < 0:
			out.append(idx)
		if out.size() >= 3:
			break
	return out

func _clone_plane_array(planes: Array) -> Array:
	var out: Array = []
	for p in planes:
		var plane: NeoPlane = p as NeoPlane
		if plane == null:
			out.append(null)
			continue
		out.append(NeoPlane.new(plane.normal, plane.distance))
	return out

func _restore_brush_planes_from_snapshot(brush: BrushForge, snapshot: Array) -> void:
	if brush == null:
		return
	brush.planes.clear()
	for p in snapshot:
		var plane: NeoPlane = p as NeoPlane
		if plane == null:
			continue
		brush.planes.append(NeoPlane.new(plane.normal, plane.distance))

func _refresh_brush_bounds_from_planes(brush: BrushForge, mesh: MeshInstance3D) -> void:
	if brush == null or mesh == null:
		return
	var vertices := _get_brush_vertices_world(brush)
	if vertices.is_empty():
		# Recover from invalid plane sets by rebuilding a box from current bounds.
		var safe_size := Vector3(
			maxf(absf(brush.size.x), grid_size),
			maxf(absf(brush.size.y), grid_size),
			maxf(absf(brush.size.z), grid_size)
		)
		var rebuilt := BrushForge.create_box(brush.position, safe_size)
		brush.planes = rebuilt.planes.duplicate()
		brush.size = safe_size
		mesh.position = brush.position
		mesh.mesh = _build_brush_mesh(brush)
		return
	var min_v: Vector3 = vertices[0]
	var max_v: Vector3 = vertices[0]
	for v in vertices:
		min_v.x = minf(min_v.x, v.x)
		min_v.y = minf(min_v.y, v.y)
		min_v.z = minf(min_v.z, v.z)
		max_v.x = maxf(max_v.x, v.x)
		max_v.y = maxf(max_v.y, v.y)
		max_v.z = maxf(max_v.z, v.z)
	brush.position = (min_v + max_v) * 0.5
	brush.size = Vector3(
		maxf(max_v.x - min_v.x, grid_size),
		maxf(max_v.y - min_v.y, grid_size),
		maxf(max_v.z - min_v.z, grid_size)
	)
	mesh.position = brush.position
	mesh.mesh = _build_brush_mesh(brush)

func _begin_brush_rect_draw(face_index: int, hit: Vector3) -> void:
	brush_draw_has_rect = false
	brush_extrude_depth = 0.0
	var basis := _face_basis_from_index(face_index)
	brush_draw_face_normal = basis["normal"]
	brush_draw_axis_u = basis["u"]
	brush_draw_axis_v = basis["v"]
	var plane_dist := hit.dot(brush_draw_face_normal)
	brush_draw_plane_origin = brush_draw_face_normal * plane_dist
	brush_draw_start_u = _snap_float(hit.dot(brush_draw_axis_u), grid_size)
	brush_draw_start_v = _snap_float(hit.dot(brush_draw_axis_v), grid_size)
	brush_draw_min_u = brush_draw_start_u
	brush_draw_max_u = brush_draw_start_u
	brush_draw_min_v = brush_draw_start_v
	brush_draw_max_v = brush_draw_start_v
	_update_brush_tool_gizmos()

func _update_brush_rect_from_mouse(camera: Camera3D, mouse_pos: Vector2) -> void:
	var hit := _ray_plane_hit_normal(camera, mouse_pos, brush_draw_plane_origin, brush_draw_face_normal)
	if hit == null:
		return
	var hp: Vector3 = hit
	var u := _snap_float(hp.dot(brush_draw_axis_u), grid_size)
	var v := _snap_float(hp.dot(brush_draw_axis_v), grid_size)
	brush_draw_min_u = minf(brush_draw_start_u, u)
	brush_draw_max_u = maxf(brush_draw_start_u, u)
	brush_draw_min_v = minf(brush_draw_start_v, v)
	brush_draw_max_v = maxf(brush_draw_start_v, v)
	if brush_draw_max_u - brush_draw_min_u < grid_size:
		brush_draw_max_u = brush_draw_min_u + grid_size
	if brush_draw_max_v - brush_draw_min_v < grid_size:
		brush_draw_max_v = brush_draw_min_v + grid_size
	brush_draw_has_rect = true
	_update_brush_tool_gizmos()

func _face_basis_from_index(face_index: int) -> Dictionary:
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

func _ray_plane_hit_normal(camera: Camera3D, mouse_pos: Vector2, plane_origin: Vector3, plane_normal: Vector3) -> Variant:
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var denom := dir.dot(plane_normal)
	if absf(denom) < 0.0001:
		return null
	var t := (plane_origin - origin).dot(plane_normal) / denom
	if t < 0.0:
		return null
	return origin + dir * t

func _get_pick_hit_point_from_mouse(camera: Camera3D, pick: Dictionary, mouse_pos: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var t := float(pick.get("t", 0.0))
	if t == INF or t == -INF:
		var picked_mesh := pick.get("mesh", null)
		if picked_mesh is MeshInstance3D:
			return (picked_mesh as MeshInstance3D).global_position
		return origin
	return origin + dir * t

func _commit_brush_tool_preview() -> bool:
	if not brush_draw_has_rect:
		return false
	if absf(brush_extrude_depth) < grid_size:
		return false
	var box := _build_brush_tool_box()
	if box.is_empty():
		return false
	var center: Vector3 = box["center"]
	var size: Vector3 = box["size"]
	_begin_history_action()
	var new_b := BrushForge.create_box(center, size)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_brush_mesh(new_b)
	mi.position = center
	mi.set_meta(EDIT_LOCK_META, true)
	map_node.add_brush(new_b, mi)
	_select_brush(mi, map_node.brush_data.size() - 1)
	_end_history_action()
	brush_draw_has_rect = false
	brush_extrude_depth = 0.0
	_update_brush_tool_gizmos()
	return true

func _build_brush_tool_box() -> Dictionary:
	if not brush_draw_has_rect:
		return {}
	var p0 := brush_draw_plane_origin + brush_draw_axis_u * brush_draw_min_u + brush_draw_axis_v * brush_draw_min_v
	var p1 := brush_draw_plane_origin + brush_draw_axis_u * brush_draw_max_u + brush_draw_axis_v * brush_draw_max_v
	var base_min := Vector3(minf(p0.x, p1.x), minf(p0.y, p1.y), minf(p0.z, p1.z))
	var base_max := Vector3(maxf(p0.x, p1.x), maxf(p0.y, p1.y), maxf(p0.z, p1.z))
	var depth := brush_extrude_depth
	if absf(depth) < grid_size:
		depth = grid_size
	var p2 := p0 + brush_draw_face_normal * depth
	var p3 := p1 + brush_draw_face_normal * depth
	var all_min := Vector3(minf(minf(base_min.x, p2.x), p3.x), minf(minf(base_min.y, p2.y), p3.y), minf(minf(base_min.z, p2.z), p3.z))
	var all_max := Vector3(maxf(maxf(base_max.x, p2.x), p3.x), maxf(maxf(base_max.y, p2.y), p3.y), maxf(maxf(base_max.z, p2.z), p3.z))
	var size := all_max - all_min
	size.x = maxf(size.x, grid_size)
	size.y = maxf(size.y, grid_size)
	size.z = maxf(size.z, grid_size)
	var center := (all_min + all_max) * 0.5
	return {"center": center, "size": size}

func _is_custom_tool_enabled() -> bool:
	return (move_brush_button != null and move_brush_button.button_pressed) \
		or (brush_tool_button != null and brush_tool_button.button_pressed) \
		or (clip_tool_button != null and clip_tool_button.button_pressed) \
		or (vertex_tool_button != null and vertex_tool_button.button_pressed) \
		or (edge_tool_button != null and edge_tool_button.button_pressed) \
		or (face_tool_button != null and face_tool_button.button_pressed) \
		or (rotate_tool_button != null and rotate_tool_button.button_pressed) \
		or (paint_tool_button != null and paint_tool_button.button_pressed) \
		or (subdivide_tool_button != null and subdivide_tool_button.button_pressed) \
		or (texture_tool_button != null and texture_tool_button.button_pressed)

func _update_tool_button_states() -> void:
	var can_use_clip := plugin_active and move_brush_button != null and move_brush_button.button_pressed and selected_brush_index >= 0
	var can_use_move_subtools := plugin_active and move_brush_button != null and move_brush_button.button_pressed and selected_brush_index >= 0
	if brush_tool_button != null:
		brush_tool_button.disabled = not plugin_active
	if clip_tool_button != null:
		clip_tool_button.disabled = not can_use_clip
		if not can_use_clip and clip_tool_button.button_pressed:
			clip_tool_button.button_pressed = false
	if vertex_tool_button != null:
		vertex_tool_button.disabled = not can_use_move_subtools
		if not can_use_move_subtools and vertex_tool_button.button_pressed:
			vertex_tool_button.button_pressed = false
	if edge_tool_button != null:
		edge_tool_button.disabled = not can_use_move_subtools
		if not can_use_move_subtools and edge_tool_button.button_pressed:
			edge_tool_button.button_pressed = false
	if face_tool_button != null:
		face_tool_button.disabled = not can_use_move_subtools
		if not can_use_move_subtools and face_tool_button.button_pressed:
			face_tool_button.button_pressed = false
	if rotate_tool_button != null:
		rotate_tool_button.disabled = not can_use_move_subtools
		if not can_use_move_subtools and rotate_tool_button.button_pressed:
			rotate_tool_button.button_pressed = false
	if paint_tool_button != null:
		paint_tool_button.disabled = not can_use_move_subtools
		if not can_use_move_subtools and paint_tool_button.button_pressed:
			paint_tool_button.button_pressed = false
	if subdivide_tool_button != null:
		subdivide_tool_button.disabled = not can_use_move_subtools
		if not can_use_move_subtools and subdivide_tool_button.button_pressed:
			subdivide_tool_button.button_pressed = false
	if texture_tool_button != null:
		texture_tool_button.disabled = not plugin_active
	if lock_uvs_button != null:
		lock_uvs_button.disabled = not (plugin_active and selected_brush_index >= 0)
		if lock_uvs_button.disabled:
			lock_uvs_button.button_pressed = false
			_refresh_lock_uv_button_text()
		else:
			if map_node != null and selected_brush_index < map_node.brush_data.size():
				var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
				if brush != null:
					lock_uvs_button.button_pressed = brush.lock_uvs
					_refresh_lock_uv_button_text()
	if grid_size_spinbox != null:
		grid_size_spinbox.editable = plugin_active
		if absf(grid_size_spinbox.value - grid_size) > 0.00001:
			grid_size_spinbox.value = grid_size
	if mesh_preview_mode_button != null:
		mesh_preview_mode_button.button_pressed = BRUSH_MESH_BUILDER_SCRIPT.use_vertex_color_preview
		mesh_preview_mode_button.text = "Mesh: Vertex Colors" if mesh_preview_mode_button.button_pressed else "Mesh: Textures"
	var show_texture_ui := plugin_active and texture_tool_button != null and texture_tool_button.button_pressed
	if texture_title_label != null:
		texture_title_label.visible = show_texture_ui
	if uv_section_toggle_button != null:
		uv_section_toggle_button.visible = show_texture_ui
	if uv_section_container != null:
		uv_section_container.visible = show_texture_ui and uv_section_toggle_button != null and uv_section_toggle_button.button_pressed
	if texture_list != null:
		texture_list.visible = show_texture_ui
	if paint_color_picker != null:
		paint_color_picker.visible = plugin_active and paint_tool_button != null and paint_tool_button.button_pressed
	if paint_section_label != null:
		paint_section_label.visible = paint_color_picker != null and paint_color_picker.visible
	if paint_radius_spinbox != null:
		paint_radius_spinbox.visible = paint_color_picker != null and paint_color_picker.visible
	if paint_strength_spinbox != null:
		paint_strength_spinbox.visible = paint_color_picker != null and paint_color_picker.visible
	if paint_blend_mode_option != null:
		paint_blend_mode_option.visible = paint_color_picker != null and paint_color_picker.visible
	if paint_vertex_preview_button != null:
		paint_vertex_preview_button.visible = paint_color_picker != null and paint_color_picker.visible
		if paint_vertex_preview_button.button_pressed != BRUSH_MESH_BUILDER_SCRIPT.use_vertex_color_preview:
			paint_vertex_preview_button.button_pressed = BRUSH_MESH_BUILDER_SCRIPT.use_vertex_color_preview
	if subdivide_amount_spinbox != null:
		subdivide_amount_spinbox.visible = plugin_active and subdivide_tool_button != null and subdivide_tool_button.button_pressed
		if subdivide_amount_spinbox.visible and map_node != null and selected_brush_index >= 0 and selected_face_index >= 0 and selected_brush_index < map_node.brush_data.size():
			var brush2: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
			if brush2 != null:
				var amount := int(brush2.face_subdivisions.get(str(selected_face_index), 1))
				subdivide_amount_spinbox.value = amount
	if subdivide_section_label != null:
		subdivide_section_label.visible = subdivide_amount_spinbox != null and subdivide_amount_spinbox.visible

func _sync_selection_refs() -> void:
	if selected_brush_index < 0:
		selected_mesh = null
		selected_vertex_indices.clear()
		return
	var meshes := _get_brush_meshes()
	if selected_brush_index >= meshes.size():
		selected_mesh = null
		selected_brush_index = -1
		selected_face_index = -1
		selected_vertex_indices.clear()
		return
	selected_mesh = meshes[selected_brush_index]

func _handle_clip_tool_mouse_button(camera: Camera3D, mb: InputEventMouseButton) -> int:
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return AFTER_GUI_INPUT_PASS
	if selected_brush_index < 0:
		return AFTER_GUI_INPUT_STOP
	var pick := _pick_brush_and_face(camera, mb.position)
	if pick.is_empty():
		return AFTER_GUI_INPUT_STOP
	var pick_index := int(pick["index"])
	if pick_index != selected_brush_index:
		return AFTER_GUI_INPUT_STOP
	var face_index := int(pick["face_index"])
	var basis := _face_basis_from_index(face_index)
	var n: Vector3 = basis["normal"]
	if clip_points.is_empty():
		clip_face_normal = n
	else:
		if clip_face_normal.dot(n) < 0.95:
			clip_points.clear()
			clip_face_normal = n
	var p := _get_pick_hit_point_from_mouse(camera, pick, mb.position)
	p = _snap_vector(p, grid_size)
	if clip_points.size() >= 3:
		clip_points.clear()
	clip_points.append(p)
	_update_clip_tool_gizmo()
	return AFTER_GUI_INPUT_STOP

func _apply_clip_from_points() -> bool:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return false
	if clip_points.size() < 2:
		return false
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return false
	var p1 := clip_points[0]
	var p2 := clip_points[1]
	if p1.distance_to(p2) < 0.001:
		return false
	var p3 := Vector3.ZERO
	if clip_points.size() >= 3:
		p3 = clip_points[2]
	else:
		var mid := (p1 + p2) * 0.5
		var h := maxf(maxf(brush.size.x, brush.size.y), brush.size.z)
		var fallback_n := clip_face_normal if clip_face_normal.length() > 0.0 else Vector3.UP
		p3 = mid - fallback_n * h
	var n := (p2 - p1).cross(p3 - p1).normalized()
	if n.length() < 0.0001:
		return false
	var d := n.dot(p1)
	if n.dot(brush.position) > d:
		n = -n
		d = -d
	_begin_history_action()
	brush.planes.append(NeoPlane.new(n, d))
	var meshes := _get_brush_meshes()
	if selected_brush_index >= 0 and selected_brush_index < meshes.size():
		var mesh := meshes[selected_brush_index]
		if mesh != null:
			mesh.mesh = _build_brush_mesh(brush)
	_end_history_action()
	clip_points.clear()
	_update_clip_tool_gizmo()
	_update_gizmos()
	return true

func _begin_move_drag(camera: Camera3D, mouse_pos: Vector2, alt_pressed: bool, ctrl_pressed: bool) -> void:
	if selected_mesh == null or selected_brush_index < 0:
		return
	face_drag_active = false
	if ctrl_pressed:
		_duplicate_selected_brush()
		if selected_mesh == null or selected_brush_index < 0:
			return

	move_drag_active = true
	drag_start_brush_pos = selected_mesh.position
	drag_plane_y = drag_start_brush_pos.y
	drag_start_mouse = mouse_pos
	drag_alt_mode = alt_pressed

	var plane_hit_hit := _ray_plane_hit(camera, mouse_pos, drag_plane_y)
	if plane_hit_hit != null:
		var plane_hit: Vector3 = plane_hit_hit
		drag_start_plane_hit = plane_hit
	else:
		drag_start_plane_hit = drag_start_brush_pos

func _update_move_drag(camera: Camera3D, mouse_pos: Vector2, alt_pressed: bool) -> void:
	if selected_mesh == null or selected_brush_index < 0:
		return

	if alt_pressed != drag_alt_mode:
		drag_alt_mode = alt_pressed
		drag_start_brush_pos = selected_mesh.position
		drag_plane_y = drag_start_brush_pos.y
		drag_start_mouse = mouse_pos
		var new_plane_hit_hit := _ray_plane_hit(camera, mouse_pos, drag_plane_y)
		if new_plane_hit_hit != null:
			var new_plane_hit: Vector3 = new_plane_hit_hit
			drag_start_plane_hit = new_plane_hit

	var next_pos := drag_start_brush_pos
	if alt_pressed:
		var dy := drag_start_mouse.y - mouse_pos.y
		var units_per_pixel := _world_units_per_pixel_at(camera, drag_start_brush_pos)
		var raw_y := drag_start_brush_pos.y + dy * units_per_pixel * MOVE_SENSITIVITY_Y_SCALE
		var snapped_dy := _snap_float(raw_y - drag_start_brush_pos.y, grid_size)
		next_pos.y = drag_start_brush_pos.y + snapped_dy
		drag_plane_y = next_pos.y
	else:
		var plane_hit_hit := _ray_plane_hit(camera, mouse_pos, drag_plane_y)
		if plane_hit_hit != null:
			var plane_hit: Vector3 = plane_hit_hit
			var delta: Vector3 = plane_hit - drag_start_plane_hit
			next_pos.x = drag_start_brush_pos.x + delta.x
			next_pos.z = drag_start_brush_pos.z + delta.z
			next_pos.y = drag_plane_y
		else:
			# Fallback for camera angles where ground-plane intersection is unstable.
			var screen_delta := mouse_pos - drag_start_mouse
			var right := camera.global_transform.basis.x
			var forward := -camera.global_transform.basis.z
			right.y = 0.0
			forward.y = 0.0
			if right.length() > 0.0001:
				right = right.normalized()
			if forward.length() > 0.0001:
				forward = forward.normalized()
			var world_delta := right * screen_delta.x * MOVE_SENSITIVITY_XZ_FALLBACK
			world_delta += forward * screen_delta.y * MOVE_SENSITIVITY_XZ_FALLBACK
			next_pos.x = drag_start_brush_pos.x + world_delta.x
			next_pos.z = drag_start_brush_pos.z + world_delta.z
			next_pos.y = drag_plane_y

	var drag_delta := next_pos - drag_start_brush_pos
	drag_delta = _snap_vector(drag_delta, grid_size)
	next_pos = drag_start_brush_pos + drag_delta
	_apply_selected_brush_position(next_pos)

func _begin_face_drag(mouse_pos: Vector2, face_index: int, ctrl_pressed: bool = false) -> void:
	if selected_mesh == null or selected_brush_index < 0:
		return
	if selected_brush_index >= map_node.brush_data.size():
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	face_drag_active = true
	move_drag_active = false
	face_drag_ctrl_mode = ctrl_pressed
	face_drag_extrude_index = -1
	face_drag_face_index = face_index
	face_drag_start_center = selected_mesh.position
	face_drag_start_size = brush.size
	face_drag_start_planes = _clone_plane_array(brush.planes)
	drag_start_mouse = mouse_pos
	if face_index < 0 or face_index >= brush.planes.size():
		face_drag_axis = Vector3.ZERO
		face_drag_active = false
		return
	var p: NeoPlane = brush.planes[face_index] as NeoPlane
	if p == null:
		face_drag_axis = Vector3.ZERO
		face_drag_active = false
		return
	face_drag_axis = p.normal.normalized()
	face_drag_sign = 1.0

func _update_face_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if not face_drag_active:
		return
	if selected_mesh == null or selected_brush_index < 0:
		return
	if selected_brush_index >= map_node.brush_data.size():
		return
	if face_drag_face_index < 0:
		return

	var axis_delta := _axis_delta_from_mouse(camera, face_drag_start_center, face_drag_axis, mouse_pos)
	var axis_delta_snapped := _snap_float(axis_delta * face_drag_sign, grid_size)
	if absf(axis_delta_snapped) < 0.0001:
		return

	if face_drag_ctrl_mode:
		_update_face_extrude(axis_delta_snapped)
		_update_gizmos()
		return
	_apply_face_plane_delta_from_snapshot(selected_brush_index, face_drag_face_index, axis_delta_snapped, face_drag_start_planes)
	_update_gizmos()

func _apply_selected_face_plane_by_bounds(axis_id: int, min_v: float, max_v: float, sign: float) -> void:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return
	var meshes := _get_brush_meshes()
	if selected_brush_index < 0 or selected_brush_index >= meshes.size():
		return
	var mesh := meshes[selected_brush_index]
	if mesh == null:
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return

	if axis_id == 0:
		if sign > 0.0:
			_set_or_add_plane_distance(brush, Vector3.RIGHT, max_v)
		else:
			_set_or_add_plane_distance(brush, Vector3.LEFT, -min_v)
		brush.position.x = (min_v + max_v) * 0.5
		brush.size.x = maxf(max_v - min_v, grid_size)
	elif axis_id == 1:
		if sign > 0.0:
			_set_or_add_plane_distance(brush, Vector3.UP, max_v)
		else:
			_set_or_add_plane_distance(brush, Vector3.DOWN, -min_v)
		brush.position.y = (min_v + max_v) * 0.5
		brush.size.y = maxf(max_v - min_v, grid_size)
	else:
		if sign > 0.0:
			_set_or_add_plane_distance(brush, Vector3.BACK, max_v)
		else:
			_set_or_add_plane_distance(brush, Vector3.FORWARD, -min_v)
		brush.position.z = (min_v + max_v) * 0.5
		brush.size.z = maxf(max_v - min_v, grid_size)

	mesh.position = brush.position
	mesh.mesh = _build_brush_mesh(brush)
	_update_gizmos()

func _update_face_extrude(axis_delta: float) -> void:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return
	if face_drag_face_index < 0 or face_drag_start_planes.is_empty():
		return
	if face_drag_extrude_index == -1:
		face_drag_extrude_index = _create_extrude_brush_from_selected()
		if face_drag_extrude_index == -1:
			return
	var start_plane: NeoPlane = face_drag_start_planes[face_drag_face_index] as NeoPlane
	if start_plane == null:
		return
	var cut_depth := maxf(absf(axis_delta), grid_size)
	var max_cut_depth := _max_cut_depth_from_snapshot(selected_brush_index, face_drag_face_index, face_drag_start_planes)
	if max_cut_depth <= 0.0:
		return
	cut_depth = minf(cut_depth, max_cut_depth)
	var cut_distance := start_plane.distance - cut_depth
	var meshes := _get_brush_meshes()
	if selected_brush_index >= 0 and selected_brush_index < meshes.size():
		var src_mesh := meshes[selected_brush_index]
		var src_brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
		if src_mesh != null and src_brush != null:
			_restore_brush_planes_from_snapshot(src_brush, face_drag_start_planes)
			src_brush.planes[face_drag_face_index] = NeoPlane.new(start_plane.normal, cut_distance)
			_refresh_brush_bounds_from_planes(src_brush, src_mesh)
	if face_drag_extrude_index < 0 or face_drag_extrude_index >= map_node.brush_data.size():
		return
	var extrude_brush: BrushForge = map_node.brush_data[face_drag_extrude_index] as BrushForge
	if extrude_brush == null:
		return
	_restore_brush_planes_from_snapshot(extrude_brush, face_drag_start_planes)
	extrude_brush.planes[face_drag_face_index] = NeoPlane.new(start_plane.normal, start_plane.distance)
	extrude_brush.planes.append(NeoPlane.new(-start_plane.normal, -cut_distance))
	if face_drag_extrude_index >= 0 and face_drag_extrude_index < meshes.size():
		var mesh := meshes[face_drag_extrude_index]
		if mesh != null:
			_refresh_brush_bounds_from_planes(extrude_brush, mesh)
	_update_gizmos()

func _max_cut_depth_from_snapshot(brush_index: int, face_index: int, snapshot: Array) -> float:
	if brush_index < 0 or brush_index >= map_node.brush_data.size():
		return 0.0
	if snapshot.is_empty() or face_index < 0 or face_index >= snapshot.size():
		return 0.0
	var base_brush: BrushForge = map_node.brush_data[brush_index] as BrushForge
	if base_brush == null:
		return 0.0
	var temp := BrushForge.create_box(base_brush.position, base_brush.size)
	_restore_brush_planes_from_snapshot(temp, snapshot)
	var plane: NeoPlane = snapshot[face_index] as NeoPlane
	if plane == null:
		return 0.0
	var verts := _get_brush_vertices_world(temp)
	if verts.is_empty():
		return 0.0
	var min_proj := INF
	for v in verts:
		min_proj = minf(min_proj, plane.normal.dot(v))
	var available := plane.distance - min_proj - grid_size
	return maxf(available, 0.0)

func _apply_face_plane_delta_from_snapshot(brush_index: int, face_index: int, delta: float, snapshot: Array) -> void:
	if brush_index < 0 or brush_index >= map_node.brush_data.size():
		return
	if snapshot.is_empty() or face_index < 0 or face_index >= snapshot.size():
		return
	var brush: BrushForge = map_node.brush_data[brush_index] as BrushForge
	if brush == null:
		return
	var base_plane: NeoPlane = snapshot[face_index] as NeoPlane
	if base_plane == null:
		return
	_restore_brush_planes_from_snapshot(brush, snapshot)
	brush.planes[face_index] = NeoPlane.new(base_plane.normal, base_plane.distance + delta)
	var meshes := _get_brush_meshes()
	if brush_index >= 0 and brush_index < meshes.size():
		var mesh := meshes[brush_index]
		if mesh != null:
			_refresh_brush_bounds_from_planes(brush, mesh)

func _create_extrude_brush_from_selected() -> int:
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return -1
	var src: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if src == null:
		return -1
	var copy := BrushForge.create_box(src.position, src.size)
	copy.planes.clear()
	for p in src.planes:
		copy.planes.append(NeoPlane.new(p.normal, p.distance))
	copy.face_material_paths = src.face_material_paths.duplicate(true)
	copy.face_uv_transforms = src.face_uv_transforms.duplicate(true)
	copy.face_paint_colors = src.face_paint_colors.duplicate(true)
	copy.face_paint_strokes = src.face_paint_strokes.duplicate(true)
	copy.face_subdivisions = src.face_subdivisions.duplicate(true)
	copy.lock_uvs = src.lock_uvs
	var mi := MeshInstance3D.new()
	mi.mesh = _build_brush_mesh(copy)
	mi.position = copy.position
	mi.set_meta(EDIT_LOCK_META, true)
	map_node.add_brush(copy, mi)
	return map_node.brush_data.size() - 1

func _pick_brush_and_face(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var best_t := INF
	var best_mesh: MeshInstance3D = null
	var best_index := -1
	var best_face_index := -1
	var best_screen_dist := INF
	var brush_meshes := _get_brush_meshes()

	for i in range(map_node.brush_data.size()):
		if i >= brush_meshes.size():
			break
		var mesh := brush_meshes[i]
		if mesh == null:
			continue
		var exact_hit := _pick_exact_face_on_brush(i, camera, mouse_pos)
		if exact_hit.is_empty():
			var b := _mesh_bounds_world(mesh)
			var center: Vector3 = b["center"]
			var screen_pos := camera.unproject_position(center)
			var screen_dist := screen_pos.distance_to(mouse_pos)
			if screen_dist < PICK_FALLBACK_RADIUS and screen_dist < best_screen_dist and best_t == INF:
				best_screen_dist = screen_dist
				best_mesh = mesh
				best_index = i
				best_face_index = 4
		else:
			var t := float(exact_hit["t"])
			if t < best_t:
				best_t = t
				best_mesh = mesh
				best_index = i
				best_face_index = int(exact_hit["face_index"])

	if best_mesh == null:
		return {}
	return {
		"mesh": best_mesh,
		"index": best_index,
		"face_index": best_face_index,
		"t": best_t,
	}

func _get_pick_hit_point(camera: Camera3D, pick: Dictionary) -> Vector3:
	var origin := camera.project_ray_origin(pending_click_mouse)
	var dir := camera.project_ray_normal(pending_click_mouse)
	var t := float(pick.get("t", 0.0))
	if t == INF or t == -INF:
		var picked_mesh := pick.get("mesh", null)
		if picked_mesh is MeshInstance3D:
			return (picked_mesh as MeshInstance3D).global_position
		return origin
	return origin + dir * t

func _begin_surface_draw() -> void:
	if surface_draw_active:
		return
	if map_node == null:
		return
	var init_size := Vector3(grid_size, SURFACE_DRAW_HEIGHT, grid_size)
	var init_center := Vector3(surface_draw_start.x, surface_draw_start.y + SURFACE_DRAW_HEIGHT * 0.5, surface_draw_start.z)
	var new_b := BrushForge.create_box(init_center, init_size)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_brush_mesh(new_b)
	mi.position = init_center
	mi.set_meta(EDIT_LOCK_META, true)
	map_node.add_brush(new_b, mi)
	surface_draw_brush_index = map_node.brush_data.size() - 1
	surface_draw_active = true

func _update_surface_draw(camera: Camera3D, mouse_pos: Vector2) -> void:
	if not surface_draw_active:
		return
	if surface_draw_brush_index < 0:
		return
	var hit := _ray_plane_hit(camera, mouse_pos, surface_draw_start.y)
	if hit == null:
		return
	var hit_pos: Vector3 = hit
	var min_x := _snap_float(minf(surface_draw_start.x, hit_pos.x), grid_size)
	var max_x := _snap_float(maxf(surface_draw_start.x, hit_pos.x), grid_size)
	var min_z := _snap_float(minf(surface_draw_start.z, hit_pos.z), grid_size)
	var max_z := _snap_float(maxf(surface_draw_start.z, hit_pos.z), grid_size)
	if max_x - min_x < grid_size:
		max_x = min_x + grid_size
	if max_z - min_z < grid_size:
		max_z = min_z + grid_size

	var center := Vector3(
		(min_x + max_x) * 0.5,
		surface_draw_start.y + SURFACE_DRAW_HEIGHT * 0.5,
		(min_z + max_z) * 0.5
	)
	var size := Vector3(max_x - min_x, SURFACE_DRAW_HEIGHT, max_z - min_z)
	_apply_brush_shape(surface_draw_brush_index, center, size)

func _select_brush(mesh: MeshInstance3D, brush_index: int) -> void:
	selected_mesh = mesh
	selected_brush_index = brush_index
	selected_vertex_indices.clear()
	selected_vertex_anchor = Vector3.ZERO
	_lock_editor_selection()
	_update_gizmos()

func _select_face(face_index: int) -> void:
	selected_face_index = face_index
	_sync_texture_list_selection()
	_update_gizmos()

func _clear_face_selection() -> void:
	selected_face_index = -1
	_sync_texture_list_selection()
	_update_gizmos()

func _clear_selection() -> void:
	selected_mesh = null
	selected_brush_index = -1
	selected_face_index = -1
	move_drag_active = false
	face_drag_active = false
	face_drag_ctrl_mode = false
	face_drag_extrude_index = -1
	pending_click_active = false
	pending_click_pick = {}
	surface_draw_active = false
	surface_draw_brush_index = -1
	brush_draw_active = false
	brush_extrude_active = false
	brush_draw_has_rect = false
	brush_extrude_depth = 0.0
	clip_points.clear()
	clip_face_normal = Vector3.ZERO
	vertex_drag_active = false
	selected_vertex_indices.clear()
	selected_vertex_anchor = Vector3.ZERO
	vertex_drag_plane_indices.clear()
	vertex_drag_start_planes.clear()
	vertex_drag_start_vertices.clear()
	vertex_drag_plane_vertex_indices.clear()
	rotate_drag_active = false
	rotate_drag_start_planes.clear()
	paint_drag_active = false
	paint_hover_valid = false
	paint_last_stamp = INVALID_STAMP_POINT
	_sync_texture_list_selection()
	_update_gizmos()

func _apply_selected_brush_position(pos: Vector3) -> void:
	if selected_mesh == null:
		return
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return

	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		return
	var delta: Vector3 = pos - brush.position
	if delta.length_squared() != 0.0:
		for i in range(brush.planes.size()):
			var plane: NeoPlane = brush.planes[i] as NeoPlane
			if plane == null:
				continue
			plane.distance += plane.normal.dot(delta)
			brush.planes[i] = plane
	brush.position = pos
	selected_mesh.position = pos
	if not brush.lock_uvs:
		selected_mesh.mesh = _build_brush_mesh(brush)
	_update_gizmos()

func _apply_selected_brush_shape(pos: Vector3, size: Vector3) -> void:
	_apply_brush_shape(selected_brush_index, pos, size)
	_update_gizmos()

func _apply_brush_shape(brush_index: int, pos: Vector3, size: Vector3) -> void:
	if brush_index < 0 or brush_index >= map_node.brush_data.size():
		return
	var brush_meshes := _get_brush_meshes()
	if brush_index >= brush_meshes.size():
		return
	var mesh := brush_meshes[brush_index]
	if mesh == null:
		return

	var clamped_size := Vector3(
		maxf(size.x, grid_size),
		maxf(size.y, grid_size),
		maxf(size.z, grid_size)
	)
	var brush: BrushForge = map_node.brush_data[brush_index] as BrushForge
	if brush == null:
		return
	var old_pos: Vector3 = brush.position
	mesh.position = pos
	brush.position = pos
	brush.size = clamped_size
	if brush.planes.size() >= 6:
		var delta: Vector3 = pos - old_pos
		if delta.length_squared() != 0.0:
			for i in range(brush.planes.size()):
				var plane: NeoPlane = brush.planes[i] as NeoPlane
				if plane == null:
					continue
				plane.distance += plane.normal.dot(delta)
				brush.planes[i] = plane

		var min_x := pos.x - clamped_size.x * 0.5
		var max_x := pos.x + clamped_size.x * 0.5
		var min_y := pos.y - clamped_size.y * 0.5
		var max_y := pos.y + clamped_size.y * 0.5
		var min_z := pos.z - clamped_size.z * 0.5
		var max_z := pos.z + clamped_size.z * 0.5
		_set_or_add_plane_distance(brush, Vector3.RIGHT, max_x)
		_set_or_add_plane_distance(brush, Vector3.LEFT, -min_x)
		_set_or_add_plane_distance(brush, Vector3.UP, max_y)
		_set_or_add_plane_distance(brush, Vector3.DOWN, -min_y)
		_set_or_add_plane_distance(brush, Vector3.FORWARD, -min_z)
		_set_or_add_plane_distance(brush, Vector3.BACK, max_z)
	else:
		var rebuilt := BrushForge.create_box(pos, clamped_size)
		brush.planes = rebuilt.planes.duplicate()
	mesh.mesh = _build_brush_mesh(brush)

func _find_plane_index_by_normal(brush: BrushForge, target: Vector3, dot_threshold: float = 0.999) -> int:
	if brush == null:
		return -1
	for i in range(brush.planes.size()):
		var plane: NeoPlane = brush.planes[i] as NeoPlane
		if plane == null:
			continue
		if plane.normal.dot(target) >= dot_threshold:
			return i
	return -1

func _set_or_add_plane_distance(brush: BrushForge, normal: Vector3, distance: float) -> void:
	if brush == null:
		return
	var idx := _find_plane_index_by_normal(brush, normal)
	if idx >= 0:
		var plane: NeoPlane = brush.planes[idx] as NeoPlane
		if plane == null:
			brush.planes[idx] = NeoPlane.new(normal, distance)
			return
		plane.distance = distance
		brush.planes[idx] = plane
		return
	brush.planes.append(NeoPlane.new(normal, distance))

func _is_mouse_near_selected_brush(camera: Camera3D, mouse_pos: Vector2) -> bool:
	if selected_mesh == null:
		return false
	var screen_pos := camera.unproject_position(selected_mesh.global_position)
	return screen_pos.distance_to(mouse_pos) <= PICK_FALLBACK_RADIUS * 1.5

func _axis_delta_from_mouse(camera: Camera3D, world_origin: Vector3, axis: Vector3, mouse_pos: Vector2) -> float:
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

func _delete_selected_brush() -> void:
	if selected_mesh == null or selected_brush_index < 0:
		return
	if selected_brush_index >= map_node.brush_data.size():
		return
	var mesh_to_remove := selected_mesh
	map_node.brush_data.remove_at(selected_brush_index)
	if mesh_to_remove.get_parent() == map_node:
		map_node.remove_child(mesh_to_remove)
	mesh_to_remove.queue_free()
	_clear_selection()

func _duplicate_selected_brush() -> void:
	if selected_mesh == null or selected_brush_index < 0:
		return
	if selected_brush_index >= map_node.brush_data.size():
		return
	var src: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if src == null:
		return
	var copy := BrushForge.create_box(src.position, src.size)
	copy.planes.clear()
	for p in src.planes:
		copy.planes.append(NeoPlane.new(p.normal, p.distance))
	copy.face_material_paths = src.face_material_paths.duplicate(true)
	copy.face_uv_transforms = src.face_uv_transforms.duplicate(true)
	copy.face_paint_colors = src.face_paint_colors.duplicate(true)
	copy.face_paint_strokes = src.face_paint_strokes.duplicate(true)
	copy.face_subdivisions = src.face_subdivisions.duplicate(true)
	copy.lock_uvs = src.lock_uvs
	var mi := MeshInstance3D.new()
	mi.mesh = _build_brush_mesh(copy)
	mi.position = copy.position
	map_node.add_brush(copy, mi)
	_select_brush(mi, map_node.brush_data.size() - 1)

func _handle_trenchbroom_keybinds(event: InputEventKey) -> bool:
	if selected_mesh == null or selected_brush_index < 0:
		return false
	if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
		_begin_history_action()
		_delete_selected_brush()
		_end_history_action()
		return true
	if event.keycode == KEY_ESCAPE:
		if move_drag_active:
			move_drag_active = false
			_apply_selected_brush_position(drag_start_brush_pos)
			return true
		return false

	var delta := Vector3.ZERO
	if event.keycode == KEY_LEFT:
		delta.x -= NUDGE_STEP
	elif event.keycode == KEY_RIGHT:
		delta.x += NUDGE_STEP
	elif event.keycode == KEY_UP:
		delta.z -= NUDGE_STEP
	elif event.keycode == KEY_DOWN:
		delta.z += NUDGE_STEP
	elif event.keycode == KEY_PAGEUP:
		delta.y += NUDGE_STEP
	elif event.keycode == KEY_PAGEDOWN:
		delta.y -= NUDGE_STEP

	if delta != Vector3.ZERO:
		_begin_history_action()
		if event.ctrl_pressed:
			_duplicate_selected_brush()
		var target := selected_mesh.position + delta
		_apply_selected_brush_position(_snap_vector(target, grid_size))
		_end_history_action()
		return true

	return false

func _is_blocked_editor_transform_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_W \
		or event.keycode == KEY_E \
		or event.keycode == KEY_R \
		or event.keycode == KEY_T \
		or event.keycode == KEY_G

func _is_arrow_key(keycode: int) -> bool:
	return keycode == KEY_LEFT or keycode == KEY_RIGHT or keycode == KEY_UP or keycode == KEY_DOWN

func _lock_all_brush_nodes() -> void:
	if map_node == null:
		return
	for mesh in _get_brush_meshes():
		if mesh != null:
			mesh.set_meta(EDIT_LOCK_META, true)

func _lock_editor_selection() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	var selected_nodes := selection.get_selected_nodes()
	for node in selected_nodes:
		if node is Node:
			selection.remove_node(node)

func _ray_plane_hit(camera: Camera3D, mouse_pos: Vector2, plane_y: float) -> Variant:
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

func _snap_float(value: float, step: float) -> float:
	return round(value / step) * step

func _snap_vector(v: Vector3, step: float) -> Vector3:
	return Vector3(_snap_float(v.x, step), _snap_float(v.y, step), _snap_float(v.z, step))

func _world_units_per_pixel_at(camera: Camera3D, world_pos: Vector3) -> float:
	var viewport := camera.get_viewport()
	if viewport == null:
		return 0.01
	var viewport_h := viewport.get_visible_rect().size.y
	if viewport_h <= 1.0:
		return 0.01
	var dist := camera.global_position.distance_to(world_pos)
	var fov_rad := deg_to_rad(camera.fov)
	return maxf((2.0 * dist * tan(fov_rad * 0.5)) / viewport_h, 0.0001)

func _begin_history_action() -> void:
	if history_action_active:
		return
	pending_undo_state = _capture_map_state()
	history_action_active = true

func _end_history_action() -> void:
	if not history_action_active:
		return
	var current_state := _capture_map_state()
	if not _states_equal(pending_undo_state, current_state):
		var undo_state := _clone_state(pending_undo_state)
		var do_state := _clone_state(current_state)
		var undo_redo := get_undo_redo()
		undo_redo.create_action("BrushForge Edit")
		undo_redo.add_do_method(self, "_restore_map_state", do_state)
		undo_redo.add_undo_method(self, "_restore_map_state", undo_state)
		undo_redo.commit_action()
	if map_node != null:
		map_node.sync_data_from_scene()
	history_action_active = false
	pending_undo_state = []

func _capture_map_state() -> Array:
	var state: Array = []
	if map_node == null:
		return state
	for i in range(map_node.brush_data.size()):
		var brush: BrushForge = map_node.brush_data[i] as BrushForge
		if brush == null:
			continue
		var planes_state: Array = []
		for p in brush.planes:
			var plane: NeoPlane = p as NeoPlane
			if plane == null:
				continue
			planes_state.append({
				"normal": plane.normal,
				"distance": plane.distance,
			})
		state.append({
			"position": brush.position,
			"size": brush.size,
			"planes": planes_state,
			"face_material_paths": brush.face_material_paths.duplicate(true),
			"face_uv_transforms": brush.face_uv_transforms.duplicate(true),
			"face_paint_colors": brush.face_paint_colors.duplicate(true),
			"face_paint_strokes": brush.face_paint_strokes.duplicate(true),
			"face_subdivisions": brush.face_subdivisions.duplicate(true),
			"lock_uvs": brush.lock_uvs,
		})
	return state

func _restore_map_state(state: Array) -> void:
	if map_node == null:
		return
	# On normal edit commit, UndoRedo immediately runs "do" with the current state.
	# Rebuilding in that case can desync editor refs and make brushes appear to vanish.
	var current_state := _capture_map_state()
	if _states_equal(current_state, state):
		map_node.sync_data_from_scene()
		return
	var previous_selected_index := selected_brush_index
	var previous_face_index := selected_face_index
	var brush_meshes := _get_brush_meshes()
	for mesh in brush_meshes:
		if mesh != null and mesh.get_parent() == map_node:
			map_node.remove_child(mesh)
			mesh.queue_free()
	map_node.brush_data.clear()

	for item in state:
		var pos: Vector3 = item["position"]
		var size: Vector3 = item["size"]
		var brush := BrushForge.create_box(pos, size)
		brush.planes.clear()
		var planes_state: Array = item.get("planes", [])
		for p in planes_state:
			var normal: Vector3 = p.get("normal", Vector3.UP)
			var distance: float = float(p.get("distance", 0.0))
			brush.planes.append(NeoPlane.new(normal, distance))
		if brush.planes.size() < 4:
			var rebuilt := BrushForge.create_box(pos, size)
			brush.planes = rebuilt.planes.duplicate()
		var face_material_paths: Dictionary = item.get("face_material_paths", {})
		brush.face_material_paths = face_material_paths.duplicate(true)
		var face_uv_transforms: Dictionary = item.get("face_uv_transforms", {})
		brush.face_uv_transforms = face_uv_transforms.duplicate(true)
		var face_paint_colors: Dictionary = item.get("face_paint_colors", {})
		brush.face_paint_colors = face_paint_colors.duplicate(true)
		var face_paint_strokes: Dictionary = item.get("face_paint_strokes", {})
		brush.face_paint_strokes = face_paint_strokes.duplicate(true)
		var face_subdivisions: Dictionary = item.get("face_subdivisions", {})
		brush.face_subdivisions = face_subdivisions.duplicate(true)
		brush.lock_uvs = bool(item.get("lock_uvs", false))
		var mi := MeshInstance3D.new()
		mi.mesh = _build_brush_mesh(brush)
		mi.position = pos
		mi.set_meta(EDIT_LOCK_META, true)
		map_node.add_brush(brush, mi)

	map_node.sync_data_from_scene()
	var rebuilt_meshes := _get_brush_meshes()
	if previous_selected_index >= 0 and previous_selected_index < rebuilt_meshes.size():
		var selected := rebuilt_meshes[previous_selected_index]
		if selected != null:
			_select_brush(selected, previous_selected_index)
			if previous_face_index >= 0:
				_select_face(previous_face_index)
			return
	_clear_selection()

func _states_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		var ai = a[i]
		var bi = b[i]
		if ai["position"] != bi["position"]:
			return false
		if ai["size"] != bi["size"]:
			return false
		var ap: Array = ai.get("planes", [])
		var bp: Array = bi.get("planes", [])
		if ap.size() != bp.size():
			return false
		for j in range(ap.size()):
			var api = ap[j]
			var bpi = bp[j]
			if api.get("normal", Vector3.ZERO) != bpi.get("normal", Vector3.ZERO):
				return false
			if float(api.get("distance", 0.0)) != float(bpi.get("distance", 0.0)):
				return false
		var afm: Dictionary = ai.get("face_material_paths", {})
		var bfm: Dictionary = bi.get("face_material_paths", {})
		if afm != bfm:
			return false
		var afuv: Dictionary = ai.get("face_uv_transforms", {})
		var bfuv: Dictionary = bi.get("face_uv_transforms", {})
		if afuv != bfuv:
			return false
		var afc: Dictionary = ai.get("face_paint_colors", {})
		var bfc: Dictionary = bi.get("face_paint_colors", {})
		if afc != bfc:
			return false
		var afst: Dictionary = ai.get("face_paint_strokes", {})
		var bfst: Dictionary = bi.get("face_paint_strokes", {})
		if afst != bfst:
			return false
		var afs: Dictionary = ai.get("face_subdivisions", {})
		var bfs: Dictionary = bi.get("face_subdivisions", {})
		if afs != bfs:
			return false
		if bool(ai.get("lock_uvs", false)) != bool(bi.get("lock_uvs", false)):
			return false
	return true

func _clone_state(state: Array) -> Array:
	var out: Array = []
	for item in state:
		var planes_copy: Array = []
		var planes_src: Array = item.get("planes", [])
		for p in planes_src:
			planes_copy.append({
				"normal": p.get("normal", Vector3.UP),
				"distance": float(p.get("distance", 0.0)),
			})
		out.append({
			"position": item["position"],
			"size": item["size"],
			"planes": planes_copy,
			"face_material_paths": item.get("face_material_paths", {}).duplicate(true),
			"face_uv_transforms": item.get("face_uv_transforms", {}).duplicate(true),
			"face_paint_colors": item.get("face_paint_colors", {}).duplicate(true),
			"face_paint_strokes": item.get("face_paint_strokes", {}).duplicate(true),
			"face_subdivisions": item.get("face_subdivisions", {}).duplicate(true),
			"lock_uvs": bool(item.get("lock_uvs", false)),
		})
	return out

func _ensure_map_node(create_if_missing: bool = true) -> bool:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return false
	var found_maps := root.find_children("*", "BrushForgeMap", true, false)
	if found_maps.size() > 0:
		map_node = found_maps[0] as BrushForgeMap
	else:
		map_node = root.get_node_or_null("BrushForgeMap")
	if map_node == null and create_if_missing:
		map_node = BrushForgeMap.new()
		map_node.name = "BrushForgeMap"
		root.add_child(map_node)
		map_node.owner = root
	if map_node == null:
		return false
	_lock_all_brush_nodes()
	_ensure_gizmo_nodes()
	return true

func _set_plugin_active(active: bool) -> void:
	plugin_active = active
	if add_brush_button != null:
		add_brush_button.visible = active
	if move_brush_button != null:
		move_brush_button.visible = active
		if not active:
			move_brush_button.button_pressed = false
	if brush_tool_button != null:
		brush_tool_button.visible = active
		if not active:
			brush_tool_button.button_pressed = false
	if clip_tool_button != null:
		clip_tool_button.visible = active
		if not active:
			clip_tool_button.button_pressed = false
	if vertex_tool_button != null:
		vertex_tool_button.visible = active
		if not active:
			vertex_tool_button.button_pressed = false
	if edge_tool_button != null:
		edge_tool_button.visible = active
		if not active:
			edge_tool_button.button_pressed = false
	if face_tool_button != null:
		face_tool_button.visible = active
		if not active:
			face_tool_button.button_pressed = false
	if rotate_tool_button != null:
		rotate_tool_button.visible = active
		if not active:
			rotate_tool_button.button_pressed = false
	if paint_tool_button != null:
		paint_tool_button.visible = active
		if not active:
			paint_tool_button.button_pressed = false
	if subdivide_tool_button != null:
		subdivide_tool_button.visible = active
		if not active:
			subdivide_tool_button.button_pressed = false
	if texture_tool_button != null:
		texture_tool_button.visible = active
		if not active:
			texture_tool_button.button_pressed = false
	if bake_mesh_collision_button != null:
		bake_mesh_collision_button.visible = active
	if lock_uvs_button != null:
		lock_uvs_button.visible = active
		if not active:
			lock_uvs_button.button_pressed = false
		_refresh_lock_uv_button_text()
	if grid_size_spinbox != null:
		grid_size_spinbox.visible = active
		grid_size_spinbox.editable = active
	_update_texture_panel_visibility()
	if not active:
		_clear_selection()
		_remove_gizmo_nodes()
	elif map_node != null:
		_ensure_gizmo_nodes()
		_refresh_texture_menu()
		_sync_texture_list_selection()

func _update_texture_panel_visibility() -> void:
	if texture_panel == null:
		return
	texture_panel.visible = plugin_active and _is_custom_tool_enabled()

func _get_brush_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child in map_node.get_children():
		if child is MeshInstance3D and not String(child.name).begins_with("__BrushForge"):
			meshes.append(child as MeshInstance3D)
	return meshes

func _rebuild_all_brush_meshes() -> void:
	if map_node == null:
		return
	var meshes := _get_brush_meshes()
	for i in range(mini(meshes.size(), map_node.brush_data.size())):
		var mesh := meshes[i]
		var brush: BrushForge = map_node.brush_data[i] as BrushForge
		if mesh == null or brush == null:
			continue
		mesh.mesh = _build_brush_mesh(brush)

func _ray_aabb_hit(origin: Vector3, dir: Vector3, min_b: Vector3, max_b: Vector3) -> Dictionary:
	var tmin := -INF
	var tmax := INF
	var enter_face := -1

	var xhit := _ray_axis_interval(origin.x, dir.x, min_b.x, max_b.x, 0)
	if xhit.is_empty():
		return {}
	if float(xhit["near"]) > tmin:
		tmin = float(xhit["near"])
		enter_face = int(xhit["face_near"])
	tmax = minf(tmax, float(xhit["far"]))
	if tmin > tmax:
		return {}

	var yhit := _ray_axis_interval(origin.y, dir.y, min_b.y, max_b.y, 1)
	if yhit.is_empty():
		return {}
	if float(yhit["near"]) > tmin:
		tmin = float(yhit["near"])
		enter_face = int(yhit["face_near"])
	tmax = minf(tmax, float(yhit["far"]))
	if tmin > tmax:
		return {}

	var zhit := _ray_axis_interval(origin.z, dir.z, min_b.z, max_b.z, 2)
	if zhit.is_empty():
		return {}
	if float(zhit["near"]) > tmin:
		tmin = float(zhit["near"])
		enter_face = int(zhit["face_near"])
	tmax = minf(tmax, float(zhit["far"]))
	if tmin > tmax:
		return {}

	if tmax < 0.0:
		return {}
	var t_hit := tmin if tmin >= 0.0 else tmax
	return {
		"t": t_hit,
		"face_index": enter_face,
	}

func _ray_axis_interval(origin: float, dir: float, min_b: float, max_b: float, axis: int) -> Dictionary:
	if absf(dir) < 0.00001:
		if origin < min_b or origin > max_b:
			return {}
		return {
			"near": -INF,
			"far": INF,
			"face_near": -1,
		}

	var t1 := (min_b - origin) / dir
	var t2 := (max_b - origin) / dir
	var face_near := -1
	if t1 > t2:
		var tmp := t1
		t1 = t2
		t2 = tmp

	if axis == 0:
		face_near = 1 if dir > 0.0 else 0
	elif axis == 1:
		face_near = 3 if dir > 0.0 else 2
	else:
		face_near = 5 if dir > 0.0 else 4

	return {
		"near": t1,
		"far": t2,
		"face_near": face_near,
	}

func _ensure_gizmo_nodes() -> void:
	if map_node == null:
		return
	if red_gizmo_material == null:
		red_gizmo_material = StandardMaterial3D.new()
		red_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		red_gizmo_material.albedo_color = Color(1.0, 0.1, 0.1, 1.0)
		red_gizmo_material.no_depth_test = true
	if yellow_gizmo_material == null:
		yellow_gizmo_material = StandardMaterial3D.new()
		yellow_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		yellow_gizmo_material.albedo_color = Color(1.0, 0.9, 0.1, 1.0)
		yellow_gizmo_material.no_depth_test = true
	if purple_face_gizmo_material == null:
		purple_face_gizmo_material = StandardMaterial3D.new()
		purple_face_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		purple_face_gizmo_material.albedo_color = Color(0.72, 0.32, 1.0, 1.0)
		purple_face_gizmo_material.no_depth_test = true
	if edge_gizmo_material == null:
		edge_gizmo_material = StandardMaterial3D.new()
		edge_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		edge_gizmo_material.albedo_color = Color(1.0, 0.55, 0.1, 1.0)
		edge_gizmo_material.no_depth_test = true
	if paint_brush_gizmo_material == null:
		paint_brush_gizmo_material = StandardMaterial3D.new()
		paint_brush_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint_brush_gizmo_material.albedo_color = Color(0.1, 1.0, 0.9, 1.0)
		paint_brush_gizmo_material.no_depth_test = true
	if subdivide_outline_material == null:
		subdivide_outline_material = StandardMaterial3D.new()
		subdivide_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		subdivide_outline_material.albedo_color = Color(0.2, 0.55, 1.0, 1.0)
		subdivide_outline_material.no_depth_test = true
	if subdivide_grid_material == null:
		subdivide_grid_material = StandardMaterial3D.new()
		subdivide_grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		subdivide_grid_material.albedo_color = Color(0.35, 0.75, 1.0, 0.9)
		subdivide_grid_material.no_depth_test = true
	if rotate_gizmo_material == null:
		rotate_gizmo_material = StandardMaterial3D.new()
		rotate_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rotate_gizmo_material.albedo_color = Color(0.8, 0.25, 1.0, 1.0)
		rotate_gizmo_material.no_depth_test = true
	if rotate_x_material == null:
		rotate_x_material = StandardMaterial3D.new()
		rotate_x_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rotate_x_material.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
		rotate_x_material.no_depth_test = true
	if rotate_y_material == null:
		rotate_y_material = StandardMaterial3D.new()
		rotate_y_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rotate_y_material.albedo_color = Color(0.2, 1.0, 0.2, 1.0)
		rotate_y_material.no_depth_test = true
	if rotate_z_material == null:
		rotate_z_material = StandardMaterial3D.new()
		rotate_z_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rotate_z_material.albedo_color = Color(0.2, 0.45, 1.0, 1.0)
		rotate_z_material.no_depth_test = true
	if rotate_active_material == null:
		rotate_active_material = StandardMaterial3D.new()
		rotate_active_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rotate_active_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		rotate_active_material.no_depth_test = true
	if clip_line_material == null:
		clip_line_material = StandardMaterial3D.new()
		clip_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		clip_line_material.albedo_color = Color(1.0, 0.4, 0.1, 1.0)
		clip_line_material.no_depth_test = true
	if cyan_gizmo_material == null:
		cyan_gizmo_material = StandardMaterial3D.new()
		cyan_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cyan_gizmo_material.albedo_color = Color(0.1, 0.9, 1.0, 1.0)
		cyan_gizmo_material.no_depth_test = true
	if preview_gizmo_material == null:
		preview_gizmo_material = StandardMaterial3D.new()
		preview_gizmo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		preview_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		preview_gizmo_material.albedo_color = Color(0.3, 0.8, 1.0, 0.35)
		preview_gizmo_material.no_depth_test = true
	if vertex_all_gizmo_material == null:
		vertex_all_gizmo_material = StandardMaterial3D.new()
		vertex_all_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vertex_all_gizmo_material.albedo_color = Color(0.2, 0.8, 1.0, 1.0)
		vertex_all_gizmo_material.no_depth_test = true
	if vertex_selected_gizmo_material == null:
		vertex_selected_gizmo_material = StandardMaterial3D.new()
		vertex_selected_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vertex_selected_gizmo_material.albedo_color = Color(0.2, 1.0, 0.2, 1.0)
		vertex_selected_gizmo_material.no_depth_test = true

	if brush_gizmo == null:
		brush_gizmo = MeshInstance3D.new()
		brush_gizmo.name = "__BrushForgeBrushGizmo"
		map_node.add_child(brush_gizmo)
		brush_gizmo.visible = false
	if face_gizmo == null:
		face_gizmo = MeshInstance3D.new()
		face_gizmo.name = "__BrushForgeFaceGizmo"
		map_node.add_child(face_gizmo)
		face_gizmo.visible = false
	if edge_gizmo == null:
		edge_gizmo = MeshInstance3D.new()
		edge_gizmo.name = "__BrushForgeEdgeGizmo"
		map_node.add_child(edge_gizmo)
		edge_gizmo.visible = false
	if paint_brush_gizmo == null:
		paint_brush_gizmo = MeshInstance3D.new()
		paint_brush_gizmo.name = "__BrushForgePaintBrushGizmo"
		map_node.add_child(paint_brush_gizmo)
		paint_brush_gizmo.visible = false
	if subdivide_outline_gizmo == null:
		subdivide_outline_gizmo = MeshInstance3D.new()
		subdivide_outline_gizmo.name = "__BrushForgeSubdivideOutlineGizmo"
		map_node.add_child(subdivide_outline_gizmo)
		subdivide_outline_gizmo.visible = false
	if subdivide_grid_gizmo == null:
		subdivide_grid_gizmo = MeshInstance3D.new()
		subdivide_grid_gizmo.name = "__BrushForgeSubdivideGridGizmo"
		map_node.add_child(subdivide_grid_gizmo)
		subdivide_grid_gizmo.visible = false
	if rotate_gizmo == null:
		rotate_gizmo = MeshInstance3D.new()
		rotate_gizmo.name = "__BrushForgeRotateGizmo"
		map_node.add_child(rotate_gizmo)
		rotate_gizmo.visible = false
	if brush_rect_gizmo == null:
		brush_rect_gizmo = MeshInstance3D.new()
		brush_rect_gizmo.name = "__BrushForgeRectGizmo"
		map_node.add_child(brush_rect_gizmo)
		brush_rect_gizmo.visible = false
	if brush_preview_gizmo == null:
		brush_preview_gizmo = MeshInstance3D.new()
		brush_preview_gizmo.name = "__BrushForgePreviewGizmo"
		map_node.add_child(brush_preview_gizmo)
		brush_preview_gizmo.visible = false
	if clip_line_gizmo == null:
		clip_line_gizmo = MeshInstance3D.new()
		clip_line_gizmo.name = "__BrushForgeClipGizmo"
		map_node.add_child(clip_line_gizmo)
		clip_line_gizmo.visible = false
	if vertex_all_gizmo == null:
		vertex_all_gizmo = MeshInstance3D.new()
		vertex_all_gizmo.name = "__BrushForgeVertexAllGizmo"
		map_node.add_child(vertex_all_gizmo)
		vertex_all_gizmo.visible = false
	if vertex_selected_gizmo == null:
		vertex_selected_gizmo = MeshInstance3D.new()
		vertex_selected_gizmo.name = "__BrushForgeVertexSelectedGizmo"
		map_node.add_child(vertex_selected_gizmo)
		vertex_selected_gizmo.visible = false

func _remove_gizmo_nodes() -> void:
	if brush_gizmo != null:
		brush_gizmo.queue_free()
	if face_gizmo != null:
		face_gizmo.queue_free()
	if edge_gizmo != null:
		edge_gizmo.queue_free()
	if paint_brush_gizmo != null:
		paint_brush_gizmo.queue_free()
	if subdivide_outline_gizmo != null:
		subdivide_outline_gizmo.queue_free()
	if subdivide_grid_gizmo != null:
		subdivide_grid_gizmo.queue_free()
	if rotate_gizmo != null:
		rotate_gizmo.queue_free()
	if brush_rect_gizmo != null:
		brush_rect_gizmo.queue_free()
	if brush_preview_gizmo != null:
		brush_preview_gizmo.queue_free()
	if clip_line_gizmo != null:
		clip_line_gizmo.queue_free()
	if vertex_all_gizmo != null:
		vertex_all_gizmo.queue_free()
	if vertex_selected_gizmo != null:
		vertex_selected_gizmo.queue_free()
	brush_gizmo = null
	face_gizmo = null
	edge_gizmo = null
	paint_brush_gizmo = null
	subdivide_outline_gizmo = null
	subdivide_grid_gizmo = null
	rotate_gizmo = null
	brush_rect_gizmo = null
	brush_preview_gizmo = null
	clip_line_gizmo = null
	vertex_all_gizmo = null
	vertex_selected_gizmo = null
	red_gizmo_material = null
	yellow_gizmo_material = null
	purple_face_gizmo_material = null
	edge_gizmo_material = null
	paint_brush_gizmo_material = null
	subdivide_outline_material = null
	subdivide_grid_material = null
	rotate_gizmo_material = null
	rotate_x_material = null
	rotate_y_material = null
	rotate_z_material = null
	rotate_active_material = null
	cyan_gizmo_material = null
	preview_gizmo_material = null
	clip_line_material = null
	vertex_all_gizmo_material = null
	vertex_selected_gizmo_material = null

func _update_gizmos() -> void:
	if map_node == null:
		return
	_ensure_gizmo_nodes()
	if brush_gizmo == null or face_gizmo == null:
		return
	if selected_mesh == null or selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		brush_gizmo.visible = false
		face_gizmo.visible = false
		if edge_gizmo != null:
			edge_gizmo.visible = false
		if paint_brush_gizmo != null:
			paint_brush_gizmo.visible = false
		if subdivide_outline_gizmo != null:
			subdivide_outline_gizmo.visible = false
		if subdivide_grid_gizmo != null:
			subdivide_grid_gizmo.visible = false
		if rotate_gizmo != null:
			rotate_gizmo.visible = false
		if vertex_all_gizmo != null:
			vertex_all_gizmo.visible = false
		if vertex_selected_gizmo != null:
			vertex_selected_gizmo.visible = false
		return

	var b := _mesh_bounds_world(selected_mesh)
	var center: Vector3 = b["center"]
	var half_size: Vector3 = b["half_size"]
	brush_gizmo.mesh = _build_wire_box_mesh(center, half_size, red_gizmo_material)
	brush_gizmo.visible = true
	var active_face_material: Material = yellow_gizmo_material
	if face_drag_active and face_drag_ctrl_mode:
		active_face_material = purple_face_gizmo_material if purple_face_gizmo_material != null else yellow_gizmo_material

	var face_idx := selected_face_index
	var face_visible := face_idx >= 0
	if not face_visible and face_tool_button != null and face_tool_button.button_pressed:
		face_idx = 2
		face_visible = true
	if face_visible:
		if face_tool_button != null and face_tool_button.button_pressed and selected_vertex_indices.size() >= 3:
			var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
			if brush != null:
				var selected_vertices := _get_selected_vertices_world(brush)
				face_gizmo.mesh = _build_polygon_wire_mesh(selected_vertices, active_face_material)
				face_gizmo.visible = selected_vertices.size() >= 3
			else:
				face_gizmo.mesh = _build_face_wire_mesh(center, half_size, face_idx, active_face_material)
				face_gizmo.visible = true
		else:
			face_gizmo.mesh = _build_face_wire_mesh(center, half_size, face_idx, active_face_material)
			face_gizmo.visible = true
	else:
		face_gizmo.visible = false
	_update_edge_tool_gizmo(center, half_size)
	_update_paint_brush_gizmo()
	_update_subdivide_tool_gizmo(center, half_size)
	_update_rotate_tool_gizmo(center, half_size)
	_update_brush_tool_gizmos()
	_update_clip_tool_gizmo()
	_update_vertex_tool_gizmo()

func _update_clip_tool_gizmo() -> void:
	_ensure_gizmo_nodes()
	if clip_line_gizmo == null:
		return
	if clip_points.size() == 0:
		clip_line_gizmo.visible = false
		return
	var pts := []
	for p in clip_points:
		pts.append(p)
	if clip_points.size() == 3:
		pts.append(clip_points[0])
	clip_line_gizmo.mesh = _build_polyline_mesh(pts, clip_line_material)
	clip_line_gizmo.visible = true

func _update_brush_tool_gizmos() -> void:
	_ensure_gizmo_nodes()
	if brush_rect_gizmo == null or brush_preview_gizmo == null:
		return
	if not brush_draw_has_rect:
		brush_rect_gizmo.visible = false
		brush_preview_gizmo.visible = false
		return

	var p00 := brush_draw_plane_origin + brush_draw_axis_u * brush_draw_min_u + brush_draw_axis_v * brush_draw_min_v
	var p10 := brush_draw_plane_origin + brush_draw_axis_u * brush_draw_max_u + brush_draw_axis_v * brush_draw_min_v
	var p11 := brush_draw_plane_origin + brush_draw_axis_u * brush_draw_max_u + brush_draw_axis_v * brush_draw_max_v
	var p01 := brush_draw_plane_origin + brush_draw_axis_u * brush_draw_min_u + brush_draw_axis_v * brush_draw_max_v
	brush_rect_gizmo.mesh = _build_polyline_mesh([p00, p10, p11, p01, p00], cyan_gizmo_material)
	brush_rect_gizmo.visible = true

	var box := _build_brush_tool_box()
	if box.is_empty():
		brush_preview_gizmo.visible = false
		return
	var center: Vector3 = box["center"]
	var size: Vector3 = box["size"]
	brush_preview_gizmo.mesh = _build_box_mesh(size)
	brush_preview_gizmo.position = center
	brush_preview_gizmo.material_override = preview_gizmo_material
	brush_preview_gizmo.visible = brush_extrude_active or absf(brush_extrude_depth) >= grid_size

func _update_edge_tool_gizmo(center: Vector3, half_size: Vector3) -> void:
	_ensure_gizmo_nodes()
	if edge_gizmo == null:
		return
	if edge_tool_button == null or not edge_tool_button.button_pressed:
		edge_gizmo.visible = false
		return
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		edge_gizmo.visible = false
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		edge_gizmo.visible = false
		return
	var vertices := _get_brush_vertices_world(brush)
	if vertices.size() < 2:
		edge_gizmo.visible = false
		return
	var edges := _build_candidate_edges(brush, vertices)
	edge_gizmo.mesh = _build_edges_wire_mesh(vertices, edges, edge_gizmo_material)
	edge_gizmo.visible = true
	if selected_vertex_indices.size() == 2:
		var sv_edges := [{"a": selected_vertex_indices[0], "b": selected_vertex_indices[1]}]
		face_gizmo.mesh = _build_edges_wire_mesh(vertices, sv_edges, yellow_gizmo_material)
		face_gizmo.visible = true

func _update_paint_brush_gizmo() -> void:
	_ensure_gizmo_nodes()
	if paint_brush_gizmo == null:
		return
	if paint_tool_button == null or not paint_tool_button.button_pressed:
		paint_brush_gizmo.visible = false
		return
	if not paint_hover_valid:
		paint_brush_gizmo.visible = false
		return
	var radius := float(paint_radius_spinbox.value) if paint_radius_spinbox != null else 1.0
	paint_brush_gizmo.mesh = _build_wire_sphere_mesh(paint_hover_point, maxf(radius, 0.01), paint_brush_gizmo_material)
	paint_brush_gizmo.visible = true

func _update_subdivide_tool_gizmo(center: Vector3, half_size: Vector3) -> void:
	_ensure_gizmo_nodes()
	if subdivide_outline_gizmo == null or subdivide_grid_gizmo == null:
		return
	if subdivide_tool_button == null or not subdivide_tool_button.button_pressed:
		subdivide_outline_gizmo.visible = false
		subdivide_grid_gizmo.visible = false
		return
	if selected_face_index < 0:
		subdivide_outline_gizmo.visible = false
		subdivide_grid_gizmo.visible = false
		return
	var face_corners := _get_selected_brush_face_corners(selected_face_index)
	if face_corners.size() < 3:
		subdivide_outline_gizmo.visible = false
		subdivide_grid_gizmo.visible = false
		return
	var outline_pts := []
	for p in face_corners:
		outline_pts.append(p)
	outline_pts.append(face_corners[0])
	subdivide_outline_gizmo.mesh = _build_polyline_mesh(outline_pts, subdivide_outline_material)
	subdivide_outline_gizmo.visible = true
	var amount := 1
	if map_node != null and selected_brush_index >= 0 and selected_brush_index < map_node.brush_data.size():
		var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
		if brush != null:
			amount = int(brush.face_subdivisions.get(str(selected_face_index), 1))
	amount = clampi(amount, 1, 10)
	if amount <= 1:
		subdivide_grid_gizmo.visible = false
		return
	subdivide_grid_gizmo.mesh = _build_face_grid_mesh(face_corners, amount, subdivide_grid_material)
	subdivide_grid_gizmo.visible = true

func _update_rotate_tool_gizmo(center: Vector3, half_size: Vector3) -> void:
	_ensure_gizmo_nodes()
	if rotate_gizmo == null:
		return
	if rotate_tool_button == null or not rotate_tool_button.button_pressed:
		rotate_gizmo.visible = false
		return
	var radius := maxf(maxf(half_size.x, half_size.y), half_size.z) * 1.25
	var active_axis := rotate_drag_axis if rotate_drag_active else Vector3.ZERO
	rotate_gizmo.mesh = _build_rotate_rings_mesh(center, maxf(radius, grid_size), active_axis)
	rotate_gizmo.visible = true

func _update_vertex_tool_gizmo() -> void:
	_ensure_gizmo_nodes()
	if vertex_all_gizmo == null or vertex_selected_gizmo == null:
		return
	if vertex_tool_button == null or not vertex_tool_button.button_pressed:
		vertex_all_gizmo.visible = false
		vertex_selected_gizmo.visible = false
		return
	if selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		vertex_all_gizmo.visible = false
		vertex_selected_gizmo.visible = false
		return
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null:
		vertex_all_gizmo.visible = false
		vertex_selected_gizmo.visible = false
		return
	var vertices := _get_brush_vertices_world(brush)
	if vertices.is_empty():
		vertex_all_gizmo.visible = false
		vertex_selected_gizmo.visible = false
		return
	vertex_all_gizmo.mesh = _build_vertex_markers_mesh(vertices, grid_size * 0.14, vertex_all_gizmo_material)
	vertex_all_gizmo.visible = true
	var selected_vertices: Array[Vector3] = []
	for idx in selected_vertex_indices:
		if idx >= 0 and idx < vertices.size():
			selected_vertices.append(vertices[idx])
	if selected_vertices.is_empty():
		vertex_selected_gizmo.visible = false
	else:
		vertex_selected_gizmo.mesh = _build_vertex_markers_mesh(selected_vertices, grid_size * 0.22, vertex_selected_gizmo_material)
		vertex_selected_gizmo.visible = true

func _build_vertex_markers_mesh(points: Array[Vector3], half_extent: float, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var h := Vector3.ONE * maxf(half_extent, 0.01)
	for p in points:
		var c := [
			p + Vector3(-h.x, -h.y, -h.z),
			p + Vector3(h.x, -h.y, -h.z),
			p + Vector3(h.x, h.y, -h.z),
			p + Vector3(-h.x, h.y, -h.z),
			p + Vector3(-h.x, -h.y, h.z),
			p + Vector3(h.x, -h.y, h.z),
			p + Vector3(h.x, h.y, h.z),
			p + Vector3(-h.x, h.y, h.z),
		]
		var edges := PackedInt32Array([
			0, 1, 1, 2, 2, 3, 3, 0,
			4, 5, 5, 6, 6, 7, 7, 4,
			0, 4, 1, 5, 2, 6, 3, 7,
		])
		for ei in edges:
			verts.append(c[ei])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _build_rotate_axes_mesh(center: Vector3, radius: float, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array([
		center + Vector3.LEFT * radius, center + Vector3.RIGHT * radius,
		center + Vector3.DOWN * radius, center + Vector3.UP * radius,
		center + Vector3.FORWARD * radius, center + Vector3.BACK * radius,
	])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _build_rotate_rings_mesh(center: Vector3, radius: float, active_axis: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var ring_defs := [
		{"axis": Vector3.RIGHT, "material": rotate_x_material},
		{"axis": Vector3.UP, "material": rotate_y_material},
		{"axis": Vector3.BACK, "material": rotate_z_material},
	]
	for ring in ring_defs:
		var verts := PackedVector3Array()
		var axis: Vector3 = ring["axis"]
		var material: Material = ring["material"]
		if active_axis.length() > 0.0 and axis.dot(active_axis.normalized()) > 0.99:
			material = rotate_active_material
		_append_ring_segments(verts, center, axis, radius, 48)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
		var surface_idx := mesh.get_surface_count() - 1
		mesh.surface_set_material(surface_idx, material)
	return mesh

func _append_ring_segments(verts: PackedVector3Array, center: Vector3, normal: Vector3, radius: float, segments: int) -> void:
	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := normal.cross(tangent).normalized()
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := center + (tangent * cos(a0) + bitangent * sin(a0)) * radius
		var p1 := center + (tangent * cos(a1) + bitangent * sin(a1)) * radius
		verts.append(p0)
		verts.append(p1)

func _build_edges_wire_mesh(vertices: Array[Vector3], edges: Array, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	for e in edges:
		var ai := int(e.get("a", -1))
		var bi := int(e.get("b", -1))
		if ai < 0 or bi < 0 or ai >= vertices.size() or bi >= vertices.size():
			continue
		verts.append(vertices[ai])
		verts.append(vertices[bi])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _build_polygon_wire_mesh(points: Array[Vector3], material: Material) -> ArrayMesh:
	if points.size() < 3:
		return ArrayMesh.new()
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= float(points.size())
	var normal := Vector3.ZERO
	for i in range(points.size()):
		var a := points[i] - center
		var b := points[(i + 1) % points.size()] - center
		normal += a.cross(b)
	if normal.length() < 0.0001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	var tangent := Vector3.RIGHT
	if absf(normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	var bitangent := normal.cross(tangent).normalized()
	var ordered := []
	for p in points:
		var d := p - center
		var ang := atan2(d.dot(bitangent), d.dot(tangent))
		ordered.append({"a": ang, "p": p})
	ordered.sort_custom(func(x, y): return x["a"] < y["a"])
	var verts := PackedVector3Array()
	for i in range(ordered.size()):
		var p0: Vector3 = ordered[i]["p"]
		var p1: Vector3 = ordered[(i + 1) % ordered.size()]["p"]
		verts.append(p0)
		verts.append(p1)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _build_polyline_mesh(points: Array, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	for p in points:
		verts.append(p)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _build_wire_sphere_mesh(center: Vector3, radius: float, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 32
	for i in range(steps):
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		verts.append(center + Vector3(cos(a0), sin(a0), 0.0) * radius)
		verts.append(center + Vector3(cos(a1), sin(a1), 0.0) * radius)
		verts.append(center + Vector3(cos(a0), 0.0, sin(a0)) * radius)
		verts.append(center + Vector3(cos(a1), 0.0, sin(a1)) * radius)
		verts.append(center + Vector3(0.0, cos(a0), sin(a0)) * radius)
		verts.append(center + Vector3(0.0, cos(a1), sin(a1)) * radius)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _mesh_bounds_world(mesh: MeshInstance3D) -> Dictionary:
	if mesh == null or mesh.mesh == null:
		var c := mesh.global_position if mesh != null else Vector3.ZERO
		return {"min": c, "max": c, "center": c, "half_size": Vector3.ONE * 0.5}
	var aabb := mesh.mesh.get_aabb()
	var minp := mesh.global_position + aabb.position
	var maxp := minp + aabb.size
	var center := (minp + maxp) * 0.5
	var half := (maxp - minp) * 0.5
	return {"min": minp, "max": maxp, "center": center, "half_size": half}

func _build_wire_box_mesh(center: Vector3, half_size: Vector3, material: Material) -> ArrayMesh:
	var c := [
		center + Vector3(-half_size.x, -half_size.y, -half_size.z),
		center + Vector3(half_size.x, -half_size.y, -half_size.z),
		center + Vector3(half_size.x, half_size.y, -half_size.z),
		center + Vector3(-half_size.x, half_size.y, -half_size.z),
		center + Vector3(-half_size.x, -half_size.y, half_size.z),
		center + Vector3(half_size.x, -half_size.y, half_size.z),
		center + Vector3(half_size.x, half_size.y, half_size.z),
		center + Vector3(-half_size.x, half_size.y, half_size.z),
	]
	var edges := PackedInt32Array([
		0, 1, 1, 2, 2, 3, 3, 0,
		4, 5, 5, 6, 6, 7, 7, 4,
		0, 4, 1, 5, 2, 6, 3, 7,
	])
	var verts := PackedVector3Array()
	for i in edges:
		verts.append(c[i])

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _build_face_wire_mesh(center: Vector3, half_size: Vector3, face_index: int, material: Material) -> ArrayMesh:
	var corners := _get_selected_brush_face_corners(face_index)
	if corners.size() < 3:
		corners = _get_face_corners(center, half_size, face_index)
	if corners.size() < 3:
		return ArrayMesh.new()
	var verts := PackedVector3Array()
	for i in range(corners.size()):
		var p0: Vector3 = corners[i]
		var p1: Vector3 = corners[(i + 1) % corners.size()]
		verts.append(p0)
		verts.append(p1)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _build_face_grid_mesh(corners: Array[Vector3], amount: int, material: Material) -> ArrayMesh:
	if corners.size() < 3:
		return ArrayMesh.new()
	var verts := PackedVector3Array()
	var steps := max(1, amount)
	if steps > 1:
		var fan_root: Vector3 = corners[0]
		for i in range(1, corners.size() - 1):
			var b: Vector3 = corners[i]
			var c: Vector3 = corners[i + 1]
			_append_subdivided_triangle_grid_lines(verts, fan_root, b, c, steps)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, material)
	return mesh

func _append_subdivided_triangle_grid_lines(verts: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, steps: int) -> void:
	for i in range(steps):
		for j in range(steps - i):
			var p0 := _triangle_grid_point(a, b, c, steps, i, j)
			var p1 := _triangle_grid_point(a, b, c, steps, i + 1, j)
			var p2 := _triangle_grid_point(a, b, c, steps, i, j + 1)
			_append_line_segment(verts, p0, p1)
			_append_line_segment(verts, p1, p2)
			_append_line_segment(verts, p2, p0)
			if i + j + 1 < steps:
				var p3 := _triangle_grid_point(a, b, c, steps, i + 1, j + 1)
				_append_line_segment(verts, p1, p3)
				_append_line_segment(verts, p3, p2)
				_append_line_segment(verts, p2, p1)

func _append_line_segment(verts: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	verts.append(a)
	verts.append(b)

func _triangle_grid_point(a: Vector3, b: Vector3, c: Vector3, n: int, i: int, j: int) -> Vector3:
	var fi := float(i) / float(n)
	var fj := float(j) / float(n)
	var fk := 1.0 - fi - fj
	return a * fk + b * fi + c * fj

func _get_selected_brush_face_corners(face_index: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if map_node == null or selected_brush_index < 0 or selected_brush_index >= map_node.brush_data.size():
		return out
	var brush: BrushForge = map_node.brush_data[selected_brush_index] as BrushForge
	if brush == null or face_index < 0 or face_index >= brush.planes.size():
		return out
	var plane: NeoPlane = brush.planes[face_index] as NeoPlane
	if plane == null:
		return out
	var vertices := _get_brush_vertices_world(brush)
	if vertices.is_empty():
		return out
	var face_vertices: Array[Vector3] = []
	for v in vertices:
		if absf(plane.normal.dot(v) - plane.distance) <= 0.02:
			face_vertices.append(v)
	if face_vertices.size() < 3:
		return out
	var center := Vector3.ZERO
	for v in face_vertices:
		center += v
	center /= float(face_vertices.size())
	var tangent := Vector3.RIGHT
	if absf(plane.normal.dot(tangent)) > 0.95:
		tangent = Vector3.UP
	tangent = (tangent - plane.normal * tangent.dot(plane.normal)).normalized()
	var bitangent := plane.normal.cross(tangent).normalized()
	var ordered := []
	for v in face_vertices:
		var d := v - center
		var ang := atan2(d.dot(bitangent), d.dot(tangent))
		ordered.append({"a": ang, "v": v})
	ordered.sort_custom(func(x, y): return x["a"] < y["a"])
	for item in ordered:
		out.append(item["v"])
	return out

func _get_face_corners(center: Vector3, half_size: Vector3, face_index: int) -> Array[Vector3]:
	var hx := half_size.x
	var hy := half_size.y
	var hz := half_size.z
	match face_index:
		0:
			return [
				center + Vector3(hx, -hy, -hz),
				center + Vector3(hx, hy, -hz),
				center + Vector3(hx, hy, hz),
				center + Vector3(hx, -hy, hz),
			]
		1:
			return [
				center + Vector3(-hx, -hy, hz),
				center + Vector3(-hx, hy, hz),
				center + Vector3(-hx, hy, -hz),
				center + Vector3(-hx, -hy, -hz),
			]
		2:
			return [
				center + Vector3(-hx, hy, -hz),
				center + Vector3(hx, hy, -hz),
				center + Vector3(hx, hy, hz),
				center + Vector3(-hx, hy, hz),
			]
		3:
			return [
				center + Vector3(-hx, -hy, hz),
				center + Vector3(hx, -hy, hz),
				center + Vector3(hx, -hy, -hz),
				center + Vector3(-hx, -hy, -hz),
			]
		4:
			return [
				center + Vector3(-hx, -hy, hz),
				center + Vector3(-hx, hy, hz),
				center + Vector3(hx, hy, hz),
				center + Vector3(hx, -hy, hz),
			]
		5:
			return [
				center + Vector3(hx, -hy, -hz),
				center + Vector3(hx, hy, -hz),
				center + Vector3(-hx, hy, -hz),
				center + Vector3(-hx, -hy, -hz),
			]
	var empty: Array[Vector3] = []
	return empty
