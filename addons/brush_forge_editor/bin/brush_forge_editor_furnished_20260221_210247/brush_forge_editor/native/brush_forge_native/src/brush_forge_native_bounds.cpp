#include "brush_forge_native.h"

using namespace godot;

Dictionary BrushForgeNative::compute_bounds_from_vertices(
	const PackedVector3Array &vertices_world,
	float min_extent) const {
	Dictionary out;
	if (vertices_world.is_empty()) {
		out["valid"] = false;
		return out;
	}
	Vector3 min_v = vertices_world[0];
	Vector3 max_v = vertices_world[0];
	for (int i = 1; i < vertices_world.size(); i++) {
		const Vector3 v = vertices_world[i];
		min_v.x = MIN(min_v.x, v.x);
		min_v.y = MIN(min_v.y, v.y);
		min_v.z = MIN(min_v.z, v.z);
		max_v.x = MAX(max_v.x, v.x);
		max_v.y = MAX(max_v.y, v.y);
		max_v.z = MAX(max_v.z, v.z);
	}
	const float extent = MAX(min_extent, 0.00001f);
	Vector3 size(
		MAX(max_v.x - min_v.x, extent),
		MAX(max_v.y - min_v.y, extent),
		MAX(max_v.z - min_v.z, extent));
	out["valid"] = true;
	out["min"] = min_v;
	out["max"] = max_v;
	out["center"] = (min_v + max_v) * 0.5f;
	out["size"] = size;
	return out;
}
