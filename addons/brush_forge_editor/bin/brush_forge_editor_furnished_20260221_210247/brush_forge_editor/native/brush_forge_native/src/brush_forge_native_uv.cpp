#include "brush_forge_native.h"

#include <algorithm>
#include <vector>

using namespace godot;

namespace {
Vector2 compute_uv_with_basis(const Vector3 &point_world, const Dictionary &basis, const Dictionary &uv_dict) {
	const Vector3 u_axis = basis.get("u", Vector3(1.0, 0.0, 0.0));
	const Vector3 v_axis = basis.get("v", Vector3(0.0, 1.0, 0.0));
	Vector2 uv(point_world.dot(u_axis), point_world.dot(v_axis));
	const float rotation = (double)uv_dict.get("rotation", 0.0);
	if (Math::abs(rotation) > 0.00001f) {
		uv = uv.rotated(rotation);
	}
	const Vector2 scale = uv_dict.get("scale", Vector2(1.0, 1.0));
	const float sx = Math::abs(scale.x) > 0.00001f ? scale.x : 1.0f;
	const float sy = Math::abs(scale.y) > 0.00001f ? scale.y : 1.0f;
	uv = Vector2(uv.x / sx, uv.y / sy);
	const Vector2 offset = uv_dict.get("offset", Vector2(0.0, 0.0));
	return uv + offset;
}
} // namespace

Dictionary BrushForgeNative::fit_plane_from_points(
	const PackedVector3Array &points,
	const Vector3 &reference_normal) const {
	Dictionary out;
	if (points.size() < 3) {
		return out;
	}
	Vector3 center = Vector3();
	for (int i = 0; i < points.size(); i++) {
		center += points[i];
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
	ordered.reserve((size_t)points.size());
	for (int i = 0; i < points.size(); i++) {
		const Vector3 d = points[i] - center;
		const float ang = Math::atan2(d.dot(bitangent), d.dot(tangent));
		ordered.push_back({ ang, points[i] });
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

Vector3 BrushForgeNative::face_center(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const PackedVector3Array &vertices_world,
	int face_index,
	float epsilon) const {
	const int plane_count = plane_normals.size();
	if (plane_count == 0 || plane_distances.size() != plane_count) {
		return Vector3();
	}
	if (face_index < 0 || face_index >= plane_count || vertices_world.is_empty()) {
		return Vector3();
	}
	const Vector3 normal = plane_normals[face_index];
	const float distance = plane_distances[face_index];
	Vector3 center = Vector3();
	int count = 0;
	for (int i = 0; i < vertices_world.size(); i++) {
		const Vector3 v = vertices_world[i];
		if (Math::abs(normal.dot(v) - distance) <= epsilon) {
			center += v;
			count += 1;
		}
	}
	if (count == 0) {
		return Vector3();
	}
	return center / (float)count;
}

Dictionary BrushForgeNative::align_copied_uv_transform(
	const Dictionary &src_basis,
	const Dictionary &dst_basis,
	const Dictionary &src_uv,
	const Vector3 &anchor_world) const {
	if (src_basis.is_empty() || dst_basis.is_empty() || src_uv.is_empty()) {
		return src_uv;
	}
	const Vector3 src_u = src_basis.get("u", Vector3(1.0, 0.0, 0.0));
	const Vector3 src_v = src_basis.get("v", Vector3(0.0, 1.0, 0.0));
	const Vector3 dst_u = dst_basis.get("u", Vector3(1.0, 0.0, 0.0));
	const Vector3 dst_v = dst_basis.get("v", Vector3(0.0, 1.0, 0.0));
	const Vector3 dst_n = dst_basis.get("normal", Vector3(0.0, 1.0, 0.0));
	const float src_rot = (double)src_uv.get("rotation", 0.0);

	const Vector3 src_u_rot = (src_u * Math::cos(src_rot) - src_v * Math::sin(src_rot)).normalized();
	const Vector3 src_v_rot = (src_u * Math::sin(src_rot) + src_v * Math::cos(src_rot)).normalized();
	const Vector3 projected_u = src_u_rot - dst_n * src_u_rot.dot(dst_n);
	const Vector3 projected_v = src_v_rot - dst_n * src_v_rot.dot(dst_n);
	if (projected_u.length() < 0.00001f && projected_v.length() < 0.00001f) {
		return src_uv;
	}

	std::vector<float> rot_candidates;
	if (projected_u.length() >= 0.00001f) {
		const Vector3 t_u = projected_u.normalized();
		rot_candidates.push_back(Math::atan2(-t_u.dot(dst_v), t_u.dot(dst_u)));
	}
	if (projected_v.length() >= 0.00001f) {
		const Vector3 t_v = projected_v.normalized();
		rot_candidates.push_back(Math::atan2(t_v.dot(dst_u), t_v.dot(dst_v)));
	}
	if (rot_candidates.empty()) {
		return src_uv;
	}

	float best_rot = rot_candidates[0];
	float best_err = Math_INF;
	for (float rr : rot_candidates) {
		for (float off : { 0.0f, (float)Math_PI }) {
			const float cand = rr + off;
			const Vector3 pred_u = (dst_u * Math::cos(cand) - dst_v * Math::sin(cand)).normalized();
			const Vector3 pred_v = (dst_u * Math::sin(cand) + dst_v * Math::cos(cand)).normalized();
			float err = 0.0f;
			if (projected_u.length() >= 0.00001f) {
				const Vector3 t_u = projected_u.normalized();
				err += 1.0f - Math::clamp(pred_u.dot(t_u), -1.0f, 1.0f);
			}
			if (projected_v.length() >= 0.00001f) {
				const Vector3 t_v = projected_v.normalized();
				err += 1.0f - Math::clamp(pred_v.dot(t_v), -1.0f, 1.0f);
			}
			if (err < best_err) {
				best_err = err;
				best_rot = cand;
			}
		}
	}

	Dictionary copied_uv = src_uv.duplicate(true);
	copied_uv["rotation"] = best_rot;
	const Vector2 src_anchor_uv = compute_uv_with_basis(anchor_world, src_basis, src_uv);
	Dictionary dst_uv_no_offset;
	dst_uv_no_offset["scale"] = src_uv.get("scale", Vector2(1.0, 1.0));
	dst_uv_no_offset["rotation"] = best_rot;
	dst_uv_no_offset["offset"] = Vector2(0.0, 0.0);
	const Vector2 dst_anchor_uv = compute_uv_with_basis(anchor_world, dst_basis, dst_uv_no_offset);
	copied_uv["offset"] = src_anchor_uv - dst_anchor_uv;
	return copied_uv;
}
