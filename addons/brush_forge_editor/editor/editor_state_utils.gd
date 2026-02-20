@tool
extends RefCounted

static func states_equal(a: Array, b: Array) -> bool:
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
		if ai.get("face_material_paths", {}) != bi.get("face_material_paths", {}):
			return false
		if ai.get("face_uv_transforms", {}) != bi.get("face_uv_transforms", {}):
			return false
		if ai.get("face_paint_colors", {}) != bi.get("face_paint_colors", {}):
			return false
		if ai.get("face_paint_strokes", {}) != bi.get("face_paint_strokes", {}):
			return false
		if ai.get("face_subdivisions", {}) != bi.get("face_subdivisions", {}):
			return false
		if bool(ai.get("lock_uvs", false)) != bool(bi.get("lock_uvs", false)):
			return false
	return true

static func clone_state(state: Array) -> Array:
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
