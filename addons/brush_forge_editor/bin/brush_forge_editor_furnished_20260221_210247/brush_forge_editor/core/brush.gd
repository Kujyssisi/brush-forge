@tool
extends RefCounted
class_name BrushForge

var planes := []
var position := Vector3.ZERO
var size := Vector3.ONE
var face_material_paths: Dictionary = {}
var face_uv_transforms: Dictionary = {}
var face_paint_colors: Dictionary = {}
var face_paint_strokes: Dictionary = {}
var face_subdivisions: Dictionary = {}
var lock_uvs := false

static func create_box(center: Vector3, size: Vector3) -> BrushForge:
	var b := BrushForge.new()
	b.position = center
	b.size = size
	b.planes = []
	b.face_material_paths = {}
	b.face_uv_transforms = {}
	b.face_paint_colors = {}
	b.face_paint_strokes = {}
	b.face_subdivisions = {}
	b.lock_uvs = false
	# simple planes for box
	b.planes.append(NeoPlane.new(Vector3.RIGHT, center.x + size.x/2))
	b.planes.append(NeoPlane.new(Vector3.LEFT, -(center.x - size.x/2)))
	b.planes.append(NeoPlane.new(Vector3.UP, center.y + size.y/2))
	b.planes.append(NeoPlane.new(Vector3.DOWN, -(center.y - size.y/2)))
	b.planes.append(NeoPlane.new(Vector3.FORWARD, -(center.z - size.z/2)))
	b.planes.append(NeoPlane.new(Vector3.BACK, center.z + size.z/2))
	return b
