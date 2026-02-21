#include "brush_forge_native.h"

#include <algorithm>
#include <vector>

using namespace godot;

namespace {
Dictionary fit_plane_from_points_internal(const std::vector<Vector3> &points, const Vector3 &reference_normal) {
	Dictionary out;
	if ((int)points.size() < 3) {
		return out;
	}
	Vector3 center = Vector3();
	for (const Vector3 &p : points) {
		center += p;
	}
	center /= (float)points.size();

	Vector3 normal_ref = reference_normal;
	if (normal_ref.length() < 0.0001f) {
		normal_ref = Vector3(0.0, 1.0, 0.0);
	} else {
		normal_ref = normal_ref.normalized();
	}
	Vector3 tangent = Vector3(1.0, 0.0, 0.0);
	if (Math::abs(normal_ref.dot(tangent)) > 0.95f) {
		tangent = Vector3(0.0, 1.0, 0.0);
	}
	tangent = (tangent - normal_ref * tangent.dot(normal_ref)).normalized();
	const Vector3 bitangent = normal_ref.cross(tangent).normalized();

	std::vector<std::pair<float, Vector3>> ordered;
	ordered.reserve(points.size());
	for (const Vector3 &p : points) {
		const Vector3 d = p - center;
		const float ang = Math::atan2(d.dot(bitangent), d.dot(tangent));
		ordered.push_back({ ang, p });
	}
	std::sort(ordered.begin(), ordered.end(), [](const std::pair<float, Vector3> &a, const std::pair<float, Vector3> &b) {
		return a.first < b.first;
	});

	Vector3 normal = Vector3();
	for (int i = 0; i < (int)ordered.size(); i++) {
		const Vector3 &p0 = ordered[(size_t)i].second;
		const Vector3 &p1 = ordered[(size_t)((i + 1) % ordered.size())].second;
		normal += p0.cross(p1);
	}
	if (normal.length() < 0.0001f) {
		return out;
	}
	normal = normal.normalized();
	if (normal.dot(normal_ref) < 0.0f) {
		normal = -normal;
	}
	const float distance = normal.dot(ordered[0].second);
	out["normal"] = normal;
	out["distance"] = distance;
	return out;
}
} // namespace

Dictionary BrushForgeNative::apply_vertex_drag_delta(
	const PackedVector3Array &start_vertices,
	const PackedInt32Array &selected_vertex_indices,
	const PackedInt32Array &plane_indices,
	const Array &plane_vertex_incidence,
	const PackedVector3Array &start_plane_normals,
	const PackedFloat32Array &start_plane_distances,
	const Vector3 &delta) const {
	Dictionary out;
	if (start_vertices.is_empty() || start_plane_normals.is_empty() || start_plane_distances.size() != start_plane_normals.size()) {
		return out;
	}
	PackedVector3Array moved_vertices = start_vertices;
	for (int i = 0; i < selected_vertex_indices.size(); i++) {
		const int vi = selected_vertex_indices[i];
		if (vi >= 0 && vi < moved_vertices.size()) {
			moved_vertices.set(vi, moved_vertices[vi] + delta);
		}
	}

	PackedVector3Array out_normals = start_plane_normals;
	PackedFloat32Array out_distances = start_plane_distances;
	for (int i = 0; i < plane_indices.size(); i++) {
		const int pi = plane_indices[i];
		if (pi < 0 || pi >= out_normals.size()) {
			continue;
		}
		if (pi >= plane_vertex_incidence.size()) {
			continue;
		}
		Variant inc_v = plane_vertex_incidence[pi];
		PackedInt32Array incident;
		if (inc_v.get_type() == Variant::PACKED_INT32_ARRAY) {
			incident = inc_v;
		} else if (inc_v.get_type() == Variant::ARRAY) {
			Array inc_arr = inc_v;
			for (int ii = 0; ii < inc_arr.size(); ii++) {
				incident.push_back((int)(int64_t)inc_arr[ii]);
			}
		} else {
			continue;
		}
		if (incident.size() < 3) {
			continue;
		}
		std::vector<Vector3> points;
		points.reserve((size_t)incident.size());
		for (int ii = 0; ii < incident.size(); ii++) {
			const int vi = incident[ii];
			if (vi >= 0 && vi < moved_vertices.size()) {
				points.push_back(moved_vertices[vi]);
			}
		}
		if ((int)points.size() < 3) {
			continue;
		}
		const Vector3 ref_normal = start_plane_normals[pi];
		Dictionary fitted = fit_plane_from_points_internal(points, ref_normal);
		if (fitted.is_empty()) {
			continue;
		}
		Variant nv = fitted.get("normal", Variant());
		Variant dv = fitted.get("distance", Variant());
		if (nv.get_type() != Variant::VECTOR3) {
			continue;
		}
		if (dv.get_type() != Variant::FLOAT && dv.get_type() != Variant::INT) {
			continue;
		}
		out_normals.set(pi, (Vector3)nv);
		float dist_value = 0.0f;
		if (dv.get_type() == Variant::FLOAT) {
			dist_value = (float)(double)dv;
		} else {
			dist_value = (float)(int64_t)dv;
		}
		out_distances.set(pi, dist_value);
	}

	out["plane_normals"] = out_normals;
	out["plane_distances"] = out_distances;
	return out;
}
