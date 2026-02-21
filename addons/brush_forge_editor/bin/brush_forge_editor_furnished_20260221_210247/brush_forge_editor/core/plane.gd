@tool
extends RefCounted
class_name NeoPlane

var normal: Vector3
var distance: float

func _init(_normal: Vector3, _distance: float):
	normal = _normal
	distance = _distance
