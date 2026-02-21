#include "brush_forge_native.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace godot;

namespace {
static constexpr float kEpsilon = 0.001f;
static constexpr float kDenomEpsilon = 0.00001f;
static constexpr float kFacePlaneEpsilon = 0.002f;
static constexpr float kPolylineEpsilon = 0.00001f;

enum PaintMode {
	PAINT_MODE_NORMAL = 0,
	PAINT_MODE_ADD = 1,
	PAINT_MODE_MULTIPLY = 2,
	PAINT_MODE_SUBTRACT = 3,
	PAINT_MODE_BURN = 4,
};

struct PaintAccel {
	Array strokes;
	float cell_size = 0.0f;
	std::unordered_map<int64_t, std::vector<int>> grid;
	bool use_candidates = false;
};

int64_t paint_cell_key(int x, int y, int z) {
	// Stable mixed hash for 3D integer cell coordinates.
	return (int64_t)x * 73856093LL ^ (int64_t)y * 19349663LL ^ (int64_t)z * 83492791LL;
}

bool point_inside_all_planes(const Vector3 &p, const PackedVector3Array &normals, const PackedFloat32Array &distances, float eps) {
	const int count = normals.size();
	for (int i = 0; i < count; i++) {
		if (normals[i].dot(p) > distances[i] + eps) {
			return false;
		}
	}
	return true;
}

bool intersect_three_planes(const Vector3 &n1, float d1, const Vector3 &n2, float d2, const Vector3 &n3, float d3, Vector3 &out_point) {
	const float denom = n1.dot(n2.cross(n3));
	if (Math::abs(denom) < kDenomEpsilon) {
		return false;
	}
	out_point = (d1 * n2.cross(n3) + d2 * n3.cross(n1) + d3 * n1.cross(n2)) / denom;
	return true;
}

int face_index_from_normal(const Vector3 &normal) {
	const Vector3 n = normal.normalized();
	const float d_right = n.dot(Vector3(1.0, 0.0, 0.0));
	const float d_up = n.dot(Vector3(0.0, 1.0, 0.0));
	const float d_back = n.dot(Vector3(0.0, 0.0, 1.0));
	const float ax = Math::abs(d_right);
	const float ay = Math::abs(d_up);
	const float az = Math::abs(d_back);
	if (ax >= ay && ax >= az) {
		return d_right >= 0.0f ? 0 : 1;
	}
	if (ay >= ax && ay >= az) {
		return d_up >= 0.0f ? 2 : 3;
	}
	return d_back >= 0.0f ? 4 : 5;
}

Vector2 compute_uv(const Vector3 &p_world, const Vector3 &local_origin, bool lock_uvs, const Vector3 &u_axis, const Vector3 &v_axis, const Dictionary &face_uv) {
	Vector3 p = p_world;
	if (lock_uvs) {
		p = p_world - local_origin;
	}
	float u = p.dot(u_axis);
	float v = p.dot(v_axis);
	Vector2 uv(u, v);
	Vector2 scale = face_uv.get("scale", Vector2(1.0, 1.0));
	Vector2 offset = face_uv.get("offset", Vector2(0.0, 0.0));
	float rotation = (double)face_uv.get("rotation", 0.0);
	if (Math::abs(rotation) > 0.00001f) {
		uv = uv.rotated(rotation);
	}
	const float sx = Math::abs(scale.x) > 0.00001f ? scale.x : 1.0f;
	const float sy = Math::abs(scale.y) > 0.00001f ? scale.y : 1.0f;
	uv = Vector2(uv.x / sx, uv.y / sy) + offset;
	return uv;
}

Color apply_paint_blend(const Color &dst, const Color &src, float influence, int mode) {
	const float a = Math::clamp(influence, 0.0f, 1.0f);
	if (a <= 0.0f) {
		return dst;
	}
	Color blended = src;
	switch (mode) {
		case PAINT_MODE_ADD:
			blended = Color(
				Math::clamp(dst.r + src.r, 0.0f, 1.0f),
				Math::clamp(dst.g + src.g, 0.0f, 1.0f),
				Math::clamp(dst.b + src.b, 0.0f, 1.0f),
				1.0f);
			break;
		case PAINT_MODE_MULTIPLY:
			blended = Color(dst.r * src.r, dst.g * src.g, dst.b * src.b, 1.0f);
			break;
		case PAINT_MODE_SUBTRACT:
			blended = Color(
				Math::clamp(dst.r - src.r, 0.0f, 1.0f),
				Math::clamp(dst.g - src.g, 0.0f, 1.0f),
				Math::clamp(dst.b - src.b, 0.0f, 1.0f),
				1.0f);
			break;
		case PAINT_MODE_BURN: {
			const float br = src.r <= 0.0001f ? 1.0f : Math::clamp(1.0f - (1.0f - dst.r) / src.r, 0.0f, 1.0f);
			const float bg = src.g <= 0.0001f ? 1.0f : Math::clamp(1.0f - (1.0f - dst.g) / src.g, 0.0f, 1.0f);
			const float bb = src.b <= 0.0001f ? 1.0f : Math::clamp(1.0f - (1.0f - dst.b) / src.b, 0.0f, 1.0f);
			blended = Color(br, bg, bb, 1.0f);
		} break;
		default:
			blended = src;
			break;
	}
	return Color(
		Math::lerp(dst.r, blended.r, a),
		Math::lerp(dst.g, blended.g, a),
		Math::lerp(dst.b, blended.b, a),
		1.0f);
}

Color compute_paint_color(const Vector3 &p_world, const Color &base_color, const Array &strokes) {
	if (strokes.is_empty()) {
		return base_color;
	}
	Color color = base_color;
	for (int i = 0; i < strokes.size(); i++) {
		Variant sv = strokes[i];
		if (sv.get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary s = sv;
		Vector3 sp = s.get("point", p_world);
		Color sc = s.get("color", base_color);
		const float radius = Math::max((double)s.get("radius", 0.0), 0.0001);
		const float strength = Math::clamp((double)s.get("strength", 1.0), 0.0, 1.0);
		const Vector3 delta = p_world - sp;
		const float dist_sq = delta.length_squared();
		const float radius_sq = radius * radius;
		if (dist_sq > radius_sq) {
			continue;
		}
		const float d = Math::sqrt(dist_sq);
		const float t = 1.0f - d / radius;
		const float influence = Math::clamp(t * t, 0.0f, 1.0f) * strength;
		const int mode = (int)(int64_t)s.get("mode", PAINT_MODE_NORMAL);
		color = apply_paint_blend(color, sc, influence, mode);
	}
	return color;
}

PaintAccel build_paint_stroke_accel(const Array &strokes) {
	PaintAccel out;
	out.strokes = strokes;
	if (strokes.size() < 48) {
		return out;
	}
	float radius_sum = 0.0f;
	int radius_count = 0;
	for (int i = 0; i < strokes.size(); i++) {
		Variant sv = strokes[i];
		if (sv.get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary s = sv;
		radius_sum += Math::max((double)s.get("radius", 0.0), 0.0001);
		radius_count += 1;
	}
	if (radius_count == 0) {
		return out;
	}
	out.cell_size = Math::max(radius_sum / (float)radius_count, 0.05f);
	for (int i = 0; i < strokes.size(); i++) {
		Variant sv = strokes[i];
		if (sv.get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary s = sv;
		Vector3 p = s.get("point", Vector3());
		float r = Math::max((double)s.get("radius", 0.0), 0.0001);
		int min_x = (int)Math::floor((p.x - r) / out.cell_size);
		int min_y = (int)Math::floor((p.y - r) / out.cell_size);
		int min_z = (int)Math::floor((p.z - r) / out.cell_size);
		int max_x = (int)Math::floor((p.x + r) / out.cell_size);
		int max_y = (int)Math::floor((p.y + r) / out.cell_size);
		int max_z = (int)Math::floor((p.z + r) / out.cell_size);
		for (int x = min_x; x <= max_x; x++) {
			for (int y = min_y; y <= max_y; y++) {
				for (int z = min_z; z <= max_z; z++) {
					out.grid[paint_cell_key(x, y, z)].push_back(i);
				}
			}
		}
	}
	out.use_candidates = true;
	return out;
}

const std::vector<int> *get_candidate_stroke_indices(const PaintAccel &paint_accel, const Vector3 &p_world) {
	if (!paint_accel.use_candidates || paint_accel.cell_size <= 0.0f) {
		return nullptr;
	}
	int x = (int)Math::floor(p_world.x / paint_accel.cell_size);
	int y = (int)Math::floor(p_world.y / paint_accel.cell_size);
	int z = (int)Math::floor(p_world.z / paint_accel.cell_size);
	auto it = paint_accel.grid.find(paint_cell_key(x, y, z));
	if (it == paint_accel.grid.end()) {
		return nullptr;
	}
	return &it->second;
}

Color compute_paint_color_accel(const Vector3 &p_world, const Color &base_color, const PaintAccel &paint_accel) {
	const Array &strokes = paint_accel.strokes;
	if (strokes.is_empty()) {
		return base_color;
	}
	const std::vector<int> *candidate_indices = get_candidate_stroke_indices(paint_accel, p_world);
	if (paint_accel.use_candidates && candidate_indices == nullptr) {
		return base_color;
	}
	Color color = base_color;
	if (candidate_indices != nullptr) {
		for (int stroke_index : *candidate_indices) {
			if (stroke_index < 0 || stroke_index >= strokes.size()) {
				continue;
			}
			Variant sv = strokes[stroke_index];
			if (sv.get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary s = sv;
			Vector3 sp = s.get("point", p_world);
			Color sc = s.get("color", base_color);
			const float radius = Math::max((double)s.get("radius", 0.0), 0.0001);
			const float strength = Math::clamp((double)s.get("strength", 1.0), 0.0, 1.0);
			const Vector3 delta = p_world - sp;
			const float dist_sq = delta.length_squared();
			const float radius_sq = radius * radius;
			if (dist_sq > radius_sq) {
				continue;
			}
			const float d = Math::sqrt(dist_sq);
			const float t = 1.0f - d / radius;
			const float influence = Math::clamp(t * t, 0.0f, 1.0f) * strength;
			const int mode = (int)(int64_t)s.get("mode", PAINT_MODE_NORMAL);
			color = apply_paint_blend(color, sc, influence, mode);
		}
		return color;
	}
	return compute_paint_color(p_world, base_color, strokes);
}

Vector3 triangle_row_point(const Vector3 &a, const Vector3 &b, const Vector3 &c, int sx, int i, float v) {
	const float t = (float)i / (float)MAX(1, sx);
	const float u = (1.0f - v) * t;
	return a + (b - a) * u + (c - a) * v;
}

float triangle_area_sq(const Vector3 &a, const Vector3 &b, const Vector3 &c) {
	return ((b - a).cross(c - a)).length_squared();
}

struct PlaneScore {
	int index = -1;
	float max_err = 0.0f;
	float avg_err = 0.0f;
};

std::vector<int> incident_plane_indices_for_vertex_internal(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const Vector3 &vertex,
	float epsilon,
	int min_incident) {
	std::vector<int> out;
	std::vector<std::pair<float, int>> scored;
	const int plane_count = plane_normals.size();
	if (plane_count == 0 || plane_distances.size() != plane_count) {
		return out;
	}
	out.reserve((size_t)MAX(min_incident, 1));
	scored.reserve((size_t)plane_count);
	for (int i = 0; i < plane_count; i++) {
		const float err = Math::abs(plane_normals[i].dot(vertex) - plane_distances[i]);
		scored.push_back({ err, i });
		if (err <= epsilon) {
			out.push_back(i);
		}
	}
	if ((int)out.size() >= min_incident) {
		return out;
	}
	std::sort(scored.begin(), scored.end(), [](const std::pair<float, int> &a, const std::pair<float, int> &b) {
		return a.first < b.first;
	});
	for (const auto &entry : scored) {
		const int idx = entry.second;
		if (std::find(out.begin(), out.end(), idx) == out.end()) {
			out.push_back(idx);
		}
		if ((int)out.size() >= min_incident) {
			break;
		}
	}
	return out;
}

std::vector<int> best_fit_plane_indices_internal(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const PackedVector3Array &vertices_world,
	int target_count) {
	std::vector<int> out;
	const int plane_count = plane_normals.size();
	const int vertex_count = vertices_world.size();
	if (plane_count == 0 || plane_distances.size() != plane_count || vertex_count == 0) {
		return out;
	}
	std::vector<PlaneScore> scored;
	scored.reserve((size_t)plane_count);
	for (int i = 0; i < plane_count; i++) {
		float max_err = 0.0f;
		float sum_err = 0.0f;
		for (int v = 0; v < vertex_count; v++) {
			const float err = Math::abs(plane_normals[i].dot(vertices_world[v]) - plane_distances[i]);
			max_err = MAX(max_err, err);
			sum_err += err;
		}
		PlaneScore score;
		score.index = i;
		score.max_err = max_err;
		score.avg_err = sum_err / (float)vertex_count;
		scored.push_back(score);
	}
	std::sort(scored.begin(), scored.end(), [](const PlaneScore &a, const PlaneScore &b) {
		if (a.max_err == b.max_err) {
			return a.avg_err < b.avg_err;
		}
		return a.max_err < b.max_err;
	});
	const int desired = MAX(target_count, 1);
	out.reserve((size_t)desired);
	for (const PlaneScore &score : scored) {
		out.push_back(score.index);
		if ((int)out.size() >= desired) {
			break;
		}
	}
	return out;
}

float distance_to_segment_2d(const Vector2 &p, const Vector2 &a, const Vector2 &b) {
	const Vector2 ab = b - a;
	const float len_sq = ab.length_squared();
	if (len_sq <= 0.0000001f) {
		return p.distance_to(a);
	}
	const float t = Math::clamp((p - a).dot(ab) / len_sq, 0.0f, 1.0f);
	const Vector2 closest = a + ab * t;
	return p.distance_to(closest);
}

void emit_triangle(
	const Vector3 &a,
	const Vector3 &b,
	const Vector3 &c,
	const Vector3 &tri_n,
	const Vector3 &local_origin,
	bool lock_uvs,
	const Vector3 &u_axis,
	const Vector3 &v_axis,
	const Dictionary &face_uv,
	const Color &base_color,
	const PaintAccel &paint_accel,
	PackedVector3Array &g_verts,
	PackedVector3Array &g_normals,
	PackedVector2Array &g_uvs,
	PackedColorArray &g_colors) {
	g_verts.push_back(a - local_origin);
	g_verts.push_back(c - local_origin);
	g_verts.push_back(b - local_origin);
	g_normals.push_back(tri_n);
	g_normals.push_back(tri_n);
	g_normals.push_back(tri_n);
	g_uvs.push_back(compute_uv(a, local_origin, lock_uvs, u_axis, v_axis, face_uv));
	g_uvs.push_back(compute_uv(c, local_origin, lock_uvs, u_axis, v_axis, face_uv));
	g_uvs.push_back(compute_uv(b, local_origin, lock_uvs, u_axis, v_axis, face_uv));
	g_colors.push_back(compute_paint_color_accel(a, base_color, paint_accel));
	g_colors.push_back(compute_paint_color_accel(c, base_color, paint_accel));
	g_colors.push_back(compute_paint_color_accel(b, base_color, paint_accel));
}

float cross_2d(const Vector2 &a, const Vector2 &b) {
	return a.x * b.y - a.y * b.x;
}

bool is_inside_half_plane(const Vector2 &a, const Vector2 &b, const Vector2 &p) {
	return cross_2d(b - a, p - a) >= -0.00001f;
}

Vector2 line_intersection_2d(const Vector2 &p1, const Vector2 &p2, const Vector2 &q1, const Vector2 &q2) {
	const Vector2 r = p2 - p1;
	const Vector2 s = q2 - q1;
	const float denom = cross_2d(r, s);
	if (Math::abs(denom) < 0.0000001f) {
		return p2;
	}
	const float t = cross_2d(q1 - p1, s) / denom;
	return p1 + r * t;
}

std::vector<Vector2> dedupe_polygon_points_2d(const std::vector<Vector2> &poly) {
	std::vector<Vector2> out;
	out.reserve(poly.size());
	for (const Vector2 &p : poly) {
		if (out.empty() || out.back().distance_to(p) > kPolylineEpsilon) {
			out.push_back(p);
		}
	}
	if (out.size() >= 2 && out.front().distance_to(out.back()) <= kPolylineEpsilon) {
		out.pop_back();
	}
	return out;
}

std::vector<Vector2> clip_polygon_convex_2d(const std::vector<Vector2> &subject, const std::vector<Vector2> &clipper) {
	std::vector<Vector2> output = subject;
	if (output.size() < 3 || clipper.size() < 3) {
		return {};
	}
	for (int i = 0; i < (int)clipper.size(); i++) {
		const Vector2 cp1 = clipper[i];
		const Vector2 cp2 = clipper[(i + 1) % clipper.size()];
		std::vector<Vector2> input = output;
		output.clear();
		if (input.empty()) {
			break;
		}
		Vector2 s = input.back();
		for (const Vector2 &e : input) {
			const bool e_inside = is_inside_half_plane(cp1, cp2, e);
			const bool s_inside = is_inside_half_plane(cp1, cp2, s);
			if (e_inside) {
				if (!s_inside) {
					output.push_back(line_intersection_2d(s, e, cp1, cp2));
				}
				output.push_back(e);
			} else if (s_inside) {
				output.push_back(line_intersection_2d(s, e, cp1, cp2));
			}
			s = e;
		}
	}
	return dedupe_polygon_points_2d(output);
}

float polygon_area_signed_2d(const std::vector<Vector2> &poly) {
	if (poly.size() < 3) {
		return 0.0f;
	}
	float acc = 0.0f;
	for (int i = 0; i < (int)poly.size(); i++) {
		const Vector2 a = poly[i];
		const Vector2 b = poly[(i + 1) % poly.size()];
		acc += a.x * b.y - a.y * b.x;
	}
	return acc * 0.5f;
}

void emit_face_grid_tessellation(
	const std::vector<Vector3> &ordered,
	const Vector3 &plane_normal,
	int subdiv_x,
	int subdiv_y,
	const Vector3 &local_origin,
	bool lock_uvs,
	const Vector3 &u_axis,
	const Vector3 &v_axis,
	const Dictionary &face_uv,
	const Color &base_color,
	const PaintAccel &paint_accel,
	PackedVector3Array &g_verts,
	PackedVector3Array &g_normals,
	PackedVector2Array &g_uvs,
	PackedColorArray &g_colors) {
	if (ordered.size() < 3) {
		return;
	}
	const Vector3 tri_n = plane_normal.normalized();
	const int sx = MAX(1, subdiv_x);
	const int sy = MAX(1, subdiv_y);
	if (sx <= 1 && sy <= 1) {
		for (int i = 1; i < (int)ordered.size() - 1; i++) {
			emit_triangle(ordered[0], ordered[i], ordered[i + 1], tri_n, local_origin, lock_uvs, u_axis, v_axis, face_uv, base_color, paint_accel, g_verts, g_normals, g_uvs, g_colors);
		}
		return;
	}

	const Vector3 origin = ordered[0];
	std::vector<Vector2> poly_uv;
	poly_uv.reserve(ordered.size());
	for (const Vector3 &p : ordered) {
		poly_uv.push_back(Vector2((p - origin).dot(u_axis), (p - origin).dot(v_axis)));
	}
	if (polygon_area_signed_2d(poly_uv) < 0.0f) {
		std::reverse(poly_uv.begin(), poly_uv.end());
	}

	float min_u = Math_INF;
	float min_v = Math_INF;
	float max_u = -Math_INF;
	float max_v = -Math_INF;
	for (const Vector2 &p : poly_uv) {
		min_u = MIN(min_u, p.x);
		min_v = MIN(min_v, p.y);
		max_u = MAX(max_u, p.x);
		max_v = MAX(max_v, p.y);
	}
	const float du = max_u - min_u;
	const float dv = max_v - min_v;
	if (du <= 0.000001f || dv <= 0.000001f) {
		for (int i = 1; i < (int)ordered.size() - 1; i++) {
			emit_triangle(ordered[0], ordered[i], ordered[i + 1], tri_n, local_origin, lock_uvs, u_axis, v_axis, face_uv, base_color, paint_accel, g_verts, g_normals, g_uvs, g_colors);
		}
		return;
	}

	for (int ix = 0; ix < sx; ix++) {
		const float u0 = min_u + du * (float)ix / (float)sx;
		const float u1 = min_u + du * (float)(ix + 1) / (float)sx;
		for (int iy = 0; iy < sy; iy++) {
			const float v0 = min_v + dv * (float)iy / (float)sy;
			const float v1 = min_v + dv * (float)(iy + 1) / (float)sy;
			const std::vector<Vector2> rect = {
				Vector2(u0, v0),
				Vector2(u1, v0),
				Vector2(u1, v1),
				Vector2(u0, v1),
			};
			const std::vector<Vector2> clipped = clip_polygon_convex_2d(rect, poly_uv);
			if (clipped.size() < 3) {
				continue;
			}
			for (int i = 1; i < (int)clipped.size() - 1; i++) {
				const Vector3 p0 = origin + u_axis * clipped[0].x + v_axis * clipped[0].y;
				const Vector3 p1 = origin + u_axis * clipped[i].x + v_axis * clipped[i].y;
				const Vector3 p2 = origin + u_axis * clipped[i + 1].x + v_axis * clipped[i + 1].y;
				emit_triangle(p0, p1, p2, tri_n, local_origin, lock_uvs, u_axis, v_axis, face_uv, base_color, paint_accel, g_verts, g_normals, g_uvs, g_colors);
			}
		}
	}
}

} // namespace

void BrushForgeNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("compute_brush_vertices", "plane_normals", "plane_distances"), &BrushForgeNative::compute_brush_vertices);
	ClassDB::bind_method(D_METHOD("compute_face_hull", "plane_normals", "plane_distances", "face_index", "epsilon"), &BrushForgeNative::compute_face_hull, DEFVAL(0.02f));
	ClassDB::bind_method(
		D_METHOD(
			"build_brush_surfaces",
			"plane_normals",
			"plane_distances",
			"vertices_world",
			"local_origin",
			"lock_uvs",
			"face_uv_transforms",
			"face_paint_colors",
			"face_paint_strokes",
			"face_subdivisions"),
		&BrushForgeNative::build_brush_surfaces);
	ClassDB::bind_method(
		D_METHOD("pick_exact_face", "plane_normals", "plane_distances", "ray_origin", "ray_dir"),
		&BrushForgeNative::pick_exact_face);
	ClassDB::bind_method(
		D_METHOD("build_candidate_edges", "plane_normals", "plane_distances", "vertices_world", "epsilon", "min_incident"),
		&BrushForgeNative::build_candidate_edges,
		DEFVAL(0.02f),
		DEFVAL(3));
	ClassDB::bind_method(
		D_METHOD("face_vertex_indices", "plane_normals", "plane_distances", "vertices_world", "face_index", "epsilon"),
		&BrushForgeNative::face_vertex_indices,
		DEFVAL(0.02f));
	ClassDB::bind_method(D_METHOD("nearest_vertex_index", "vertices_world", "point"), &BrushForgeNative::nearest_vertex_index);
	ClassDB::bind_method(
		D_METHOD("incident_plane_indices_for_vertex", "plane_normals", "plane_distances", "vertex", "epsilon", "min_incident"),
		&BrushForgeNative::incident_plane_indices_for_vertex,
		DEFVAL(0.02f),
		DEFVAL(3));
	ClassDB::bind_method(
		D_METHOD("best_fit_plane_indices", "plane_normals", "plane_distances", "vertices_world", "target_count"),
		&BrushForgeNative::best_fit_plane_indices,
		DEFVAL(3));
	ClassDB::bind_method(
		D_METHOD("build_plane_vertex_incidence", "plane_normals", "plane_distances", "vertices_world", "epsilon"),
		&BrushForgeNative::build_plane_vertex_incidence,
		DEFVAL(0.02f));
	ClassDB::bind_method(
		D_METHOD("resolve_drag_plane_indices", "plane_normals", "plane_distances", "selected_vertices_world", "target_count", "epsilon", "min_incident"),
		&BrushForgeNative::resolve_drag_plane_indices,
		DEFVAL(3),
		DEFVAL(0.02f),
		DEFVAL(3));
	ClassDB::bind_method(
		D_METHOD("pick_vertex_screen", "screen_positions", "mouse_pos", "threshold"),
		&BrushForgeNative::pick_vertex_screen,
		DEFVAL(16.0f));
	ClassDB::bind_method(
		D_METHOD("pick_edge_screen", "screen_positions", "edges", "mouse_pos", "threshold"),
		&BrushForgeNative::pick_edge_screen,
		DEFVAL(14.0f));
	ClassDB::bind_method(D_METHOD("structure_states_equal", "a", "b"), &BrushForgeNative::structure_states_equal);
	ClassDB::bind_method(D_METHOD("states_equal", "a", "b"), &BrushForgeNative::states_equal);
	ClassDB::bind_method(D_METHOD("clone_state", "state"), &BrushForgeNative::clone_state);
}

PackedVector3Array BrushForgeNative::compute_brush_vertices(const PackedVector3Array &plane_normals, const PackedFloat32Array &plane_distances) const {
	PackedVector3Array out;
	const int count = plane_normals.size();
	if (count < 4 || plane_distances.size() != count) {
		return out;
	}

	for (int i = 0; i < count; i++) {
		for (int j = i + 1; j < count; j++) {
			for (int k = j + 1; k < count; k++) {
				Vector3 p;
				if (!intersect_three_planes(
						plane_normals[i], plane_distances[i],
						plane_normals[j], plane_distances[j],
						plane_normals[k], plane_distances[k],
						p)) {
					continue;
				}
				if (!point_inside_all_planes(p, plane_normals, plane_distances, kEpsilon)) {
					continue;
				}
				bool duplicate = false;
				for (int existing_idx = 0; existing_idx < out.size(); existing_idx++) {
					if (out[existing_idx].distance_to(p) < kEpsilon) {
						duplicate = true;
						break;
					}
				}
				if (!duplicate) {
					out.push_back(p);
				}
			}
		}
	}
	return out;
}

PackedVector3Array BrushForgeNative::compute_face_hull(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	int face_index,
	float epsilon) const {
	PackedVector3Array out;
	const int plane_count = plane_normals.size();
	if (plane_count < 4 || plane_distances.size() != plane_count) {
		return out;
	}
	if (face_index < 0 || face_index >= plane_count) {
		return out;
	}

	const PackedVector3Array vertices = compute_brush_vertices(plane_normals, plane_distances);
	if (vertices.size() < 3) {
		return out;
	}

	const Vector3 plane_normal = plane_normals[face_index];
	const float plane_distance = plane_distances[face_index];
	std::vector<Vector3> face;
	face.reserve(vertices.size());
	for (int i = 0; i < vertices.size(); i++) {
		const Vector3 v = vertices[i];
		if (Math::abs(plane_normal.dot(v) - plane_distance) <= epsilon) {
			face.push_back(v);
		}
	}
	if (face.size() < 3) {
		return out;
	}

	Vector3 center = Vector3();
	for (const Vector3 &v : face) {
		center += v;
	}
	center /= (float)face.size();

	Vector3 tangent = Vector3(1.0, 0.0, 0.0);
	if (Math::abs(plane_normal.dot(tangent)) > 0.95f) {
		tangent = Vector3(0.0, 1.0, 0.0);
	}
	tangent = (tangent - plane_normal * tangent.dot(plane_normal)).normalized();
	const Vector3 bitangent = plane_normal.cross(tangent).normalized();

	std::vector<std::pair<float, Vector3>> pts;
	pts.reserve(face.size());
	for (const Vector3 &v : face) {
		const Vector3 d = v - center;
		const float a = Math::atan2(d.dot(bitangent), d.dot(tangent));
		pts.push_back({ a, v });
	}
	std::sort(pts.begin(), pts.end(), [](const std::pair<float, Vector3> &x, const std::pair<float, Vector3> &y) {
		return x.first < y.first;
	});
	for (const auto &p : pts) {
		out.push_back(p.second);
	}
	return out;
}

Array BrushForgeNative::build_brush_surfaces(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const PackedVector3Array &vertices_world,
	const Vector3 &local_origin,
	bool lock_uvs,
	const Dictionary &face_uv_transforms,
	const Dictionary &face_paint_colors,
	const Dictionary &face_paint_strokes,
	const Dictionary &face_subdivisions) const {
	Array surfaces;
	const int plane_count = plane_normals.size();
	if (plane_count < 4 || plane_distances.size() != plane_count || vertices_world.size() < 4) {
		return surfaces;
	}

	for (int face_index = 0; face_index < plane_count; face_index++) {
		const Vector3 plane_normal = plane_normals[face_index];
		const float plane_distance = plane_distances[face_index];
		std::vector<Vector3> face;
		face.reserve(vertices_world.size());
		for (int i = 0; i < vertices_world.size(); i++) {
			const Vector3 v = vertices_world[i];
			if (Math::abs(plane_normal.dot(v) - plane_distance) <= kFacePlaneEpsilon) {
				face.push_back(v);
			}
		}
		if (face.size() < 3) {
			continue;
		}

		Vector3 center = Vector3();
		for (const Vector3 &v : face) {
			center += v;
		}
		center /= (float)face.size();

		Vector3 tangent = Vector3(1.0, 0.0, 0.0);
		if (Math::abs(plane_normal.dot(tangent)) > 0.95f) {
			tangent = Vector3(0.0, 1.0, 0.0);
		}
		tangent = (tangent - plane_normal * tangent.dot(plane_normal)).normalized();
		const Vector3 bitangent = plane_normal.cross(tangent).normalized();

		std::vector<std::pair<float, Vector3>> pts;
		pts.reserve(face.size());
		for (const Vector3 &v : face) {
			const Vector3 d = v - center;
			const float a = Math::atan2(d.dot(bitangent), d.dot(tangent));
			pts.push_back({ a, v });
		}
		std::sort(pts.begin(), pts.end(), [](const std::pair<float, Vector3> &x, const std::pair<float, Vector3> &y) {
			return x.first < y.first;
		});
		std::vector<Vector3> ordered;
		ordered.reserve(pts.size());
		for (const auto &p : pts) {
			ordered.push_back(p.second);
		}

		Vector3 u_axis = Vector3(1.0, 0.0, 0.0);
		if (Math::abs(plane_normal.dot(u_axis)) > 0.95f) {
			u_axis = Vector3(0.0, 1.0, 0.0);
		}
		u_axis = (u_axis - plane_normal * u_axis.dot(plane_normal)).normalized();
		const Vector3 v_axis = plane_normal.cross(u_axis).normalized();

		Dictionary face_uv;
		String key = String::num_int64(face_index);
		if (face_uv_transforms.has(key)) {
			face_uv = face_uv_transforms[key];
		} else {
			const int axis_face = face_index_from_normal(plane_normal);
			const String axis_key = String::num_int64(axis_face);
			if (face_uv_transforms.has(axis_key)) {
				face_uv = face_uv_transforms[axis_key];
			}
		}

		int subdiv_x = 1;
		int subdiv_y = 1;
		Variant raw_subdiv = face_subdivisions.get(key, 1);
		if (raw_subdiv.get_type() == Variant::DICTIONARY) {
			Dictionary sd = raw_subdiv;
			subdiv_x = CLAMP((int)(int64_t)sd.get("x", 1), 1, 10);
			subdiv_y = CLAMP((int)(int64_t)sd.get("y", subdiv_x), 1, 10);
		} else {
			int amount = CLAMP((int)(int64_t)raw_subdiv, 1, 10);
			subdiv_x = amount;
			subdiv_y = amount;
		}

		Color face_color = Color(1.0, 1.0, 1.0, 1.0);
		if (face_paint_colors.has(key)) {
			face_color = face_paint_colors[key];
		}
		Array face_strokes = face_paint_strokes.get(key, Array());
		PaintAccel paint_accel = build_paint_stroke_accel(face_strokes);

		PackedVector3Array g_verts;
		PackedVector3Array g_normals;
		PackedVector2Array g_uvs;
		PackedColorArray g_colors;
		emit_face_grid_tessellation(
			ordered,
			plane_normal,
			subdiv_x,
			subdiv_y,
			local_origin,
			lock_uvs,
			u_axis,
			v_axis,
			face_uv,
			face_color,
			paint_accel,
			g_verts,
			g_normals,
			g_uvs,
			g_colors);

		if (g_verts.size() >= 3) {
			Dictionary surface;
			surface["face_index"] = face_index;
			surface["verts"] = g_verts;
			surface["normals"] = g_normals;
			surface["uvs"] = g_uvs;
			surface["colors"] = g_colors;
			surfaces.push_back(surface);
		}
	}

	return surfaces;
}

Dictionary BrushForgeNative::pick_exact_face(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const Vector3 &ray_origin,
	const Vector3 &ray_dir) const {
	Dictionary out;
	const int plane_count = plane_normals.size();
	if (plane_count == 0 || plane_distances.size() != plane_count) {
		return out;
	}
	const Vector3 dir = ray_dir.normalized();
	float best_t = Math_INF;
	int best_face_index = -1;
	Vector3 best_hit = Vector3();
	for (int i = 0; i < plane_count; i++) {
		const Vector3 normal = plane_normals[i];
		const float distance = plane_distances[i];
		const float denom = normal.dot(dir);
		if (Math::abs(denom) < 0.00001f) {
			continue;
		}
		const float t = (distance - normal.dot(ray_origin)) / denom;
		if (t < 0.0f) {
			continue;
		}
		const Vector3 hit = ray_origin + dir * t;
		if (!point_inside_all_planes(hit, plane_normals, plane_distances, 0.005f)) {
			continue;
		}
		if (t < best_t) {
			best_t = t;
			best_face_index = i;
			best_hit = hit;
		}
	}
	if (best_face_index < 0) {
		return out;
	}
	out["face_index"] = best_face_index;
	out["hit"] = best_hit;
	out["t"] = best_t;
	return out;
}

Array BrushForgeNative::build_candidate_edges(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const PackedVector3Array &vertices_world,
	float epsilon,
	int min_incident) const {
	Array out;
	const int vertex_count = vertices_world.size();
	if (vertex_count < 2) {
		return out;
	}
	if (plane_normals.size() == 0 || plane_distances.size() != plane_normals.size()) {
		return out;
	}
	std::vector<std::vector<int>> incidence;
	incidence.reserve((size_t)vertex_count);
	for (int i = 0; i < vertex_count; i++) {
		incidence.push_back(incident_plane_indices_for_vertex_internal(
			plane_normals,
			plane_distances,
			vertices_world[i],
			epsilon,
			MAX(min_incident, 1)));
	}
	for (int i = 0; i < vertex_count; i++) {
		const std::vector<int> &pi = incidence[(size_t)i];
		std::unordered_set<int> pi_set(pi.begin(), pi.end());
		for (int j = i + 1; j < vertex_count; j++) {
			const std::vector<int> &pj = incidence[(size_t)j];
			int shared = 0;
			for (int idx : pj) {
				if (pi_set.find(idx) != pi_set.end()) {
					shared += 1;
					if (shared >= 2) {
						break;
					}
				}
			}
			if (shared >= 2) {
				Dictionary e;
				e["a"] = i;
				e["b"] = j;
				out.push_back(e);
			}
		}
	}
	return out;
}

PackedInt32Array BrushForgeNative::face_vertex_indices(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const PackedVector3Array &vertices_world,
	int face_index,
	float epsilon) const {
	PackedInt32Array out;
	const int plane_count = plane_normals.size();
	if (plane_count == 0 || plane_distances.size() != plane_count) {
		return out;
	}
	if (face_index < 0 || face_index >= plane_count) {
		return out;
	}
	const Vector3 normal = plane_normals[face_index];
	const float distance = plane_distances[face_index];
	for (int i = 0; i < vertices_world.size(); i++) {
		const Vector3 v = vertices_world[i];
		if (Math::abs(normal.dot(v) - distance) <= epsilon) {
			out.push_back(i);
		}
	}
	return out;
}

int BrushForgeNative::nearest_vertex_index(const PackedVector3Array &vertices_world, const Vector3 &point) const {
	if (vertices_world.is_empty()) {
		return -1;
	}
	int best_idx = -1;
	float best_d_sq = std::numeric_limits<float>::infinity();
	for (int i = 0; i < vertices_world.size(); i++) {
		const float d_sq = point.distance_squared_to(vertices_world[i]);
		if (d_sq < best_d_sq) {
			best_d_sq = d_sq;
			best_idx = i;
		}
	}
	return best_idx;
}

PackedInt32Array BrushForgeNative::incident_plane_indices_for_vertex(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const Vector3 &vertex,
	float epsilon,
	int min_incident) const {
	PackedInt32Array out;
	const std::vector<int> indices = incident_plane_indices_for_vertex_internal(
		plane_normals,
		plane_distances,
		vertex,
		epsilon,
		MAX(min_incident, 1));
	for (int idx : indices) {
		out.push_back(idx);
	}
	return out;
}

PackedInt32Array BrushForgeNative::best_fit_plane_indices(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const PackedVector3Array &vertices_world,
	int target_count) const {
	PackedInt32Array out;
	const std::vector<int> indices = best_fit_plane_indices_internal(
		plane_normals,
		plane_distances,
		vertices_world,
		target_count);
	for (int idx : indices) {
		out.push_back(idx);
	}
	return out;
}

Array BrushForgeNative::build_plane_vertex_incidence(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const PackedVector3Array &vertices_world,
	float epsilon) const {
	Array out;
	const int plane_count = plane_normals.size();
	if (plane_count == 0 || plane_distances.size() != plane_count) {
		return out;
	}
	out.resize(plane_count);
	for (int pi = 0; pi < plane_count; pi++) {
		PackedInt32Array incident;
		const Vector3 normal = plane_normals[pi];
		const float distance = plane_distances[pi];
		for (int vi = 0; vi < vertices_world.size(); vi++) {
			const Vector3 v = vertices_world[vi];
			if (Math::abs(normal.dot(v) - distance) <= epsilon) {
				incident.push_back(vi);
			}
		}
		out[pi] = incident;
	}
	return out;
}

PackedInt32Array BrushForgeNative::resolve_drag_plane_indices(
	const PackedVector3Array &plane_normals,
	const PackedFloat32Array &plane_distances,
	const PackedVector3Array &selected_vertices_world,
	int target_count,
	float epsilon,
	int min_incident) const {
	PackedInt32Array out;
	const int vertex_count = selected_vertices_world.size();
	const int plane_count = plane_normals.size();
	if (vertex_count == 0 || plane_count == 0 || plane_distances.size() != plane_count) {
		return out;
	}
	if (vertex_count == 1) {
		PackedVector3Array single;
		single.push_back(selected_vertices_world[0]);
		return best_fit_plane_indices(plane_normals, plane_distances, single, target_count);
	}

	std::vector<std::vector<int>> incidence;
	incidence.reserve((size_t)vertex_count);
	for (int i = 0; i < vertex_count; i++) {
		incidence.push_back(incident_plane_indices_for_vertex_internal(
			plane_normals,
			plane_distances,
			selected_vertices_world[i],
			epsilon,
			MAX(min_incident, 1)));
	}

	std::unordered_set<int> shared;
	for (int idx : incidence[0]) {
		shared.insert(idx);
	}
	for (int i = 1; i < vertex_count; i++) {
		std::unordered_set<int> next_shared;
		for (int idx : incidence[(size_t)i]) {
			if (shared.find(idx) != shared.end()) {
				next_shared.insert(idx);
			}
		}
		shared = next_shared;
	}
	if (!shared.empty()) {
		std::vector<int> sorted(shared.begin(), shared.end());
		std::sort(sorted.begin(), sorted.end());
		for (int idx : sorted) {
			out.push_back(idx);
		}
		return out;
	}

	std::unordered_set<int> uni;
	for (const std::vector<int> &inc : incidence) {
		for (int idx : inc) {
			uni.insert(idx);
		}
	}
	std::vector<int> sorted_union(uni.begin(), uni.end());
	std::sort(sorted_union.begin(), sorted_union.end());
	for (int idx : sorted_union) {
		out.push_back(idx);
	}
	return out;
}

int BrushForgeNative::pick_vertex_screen(
	const PackedVector2Array &screen_positions,
	const Vector2 &mouse_pos,
	float threshold) const {
	if (screen_positions.is_empty()) {
		return -1;
	}
	int best_idx = -1;
	float best_d = std::numeric_limits<float>::infinity();
	for (int i = 0; i < screen_positions.size(); i++) {
		const float d = screen_positions[i].distance_to(mouse_pos);
		if (d < best_d) {
			best_d = d;
			best_idx = i;
		}
	}
	if (best_d > threshold) {
		return -1;
	}
	return best_idx;
}

Dictionary BrushForgeNative::pick_edge_screen(
	const PackedVector2Array &screen_positions,
	const Array &edges,
	const Vector2 &mouse_pos,
	float threshold) const {
	Dictionary out;
	if (screen_positions.size() < 2 || edges.is_empty()) {
		return out;
	}
	float best_d = std::numeric_limits<float>::infinity();
	int best_a = -1;
	int best_b = -1;
	for (int i = 0; i < edges.size(); i++) {
		Variant ev = edges[i];
		if (ev.get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary e = ev;
		const int a = (int)(int64_t)e.get("a", -1);
		const int b = (int)(int64_t)e.get("b", -1);
		if (a < 0 || b < 0 || a >= screen_positions.size() || b >= screen_positions.size()) {
			continue;
		}
		const float d = distance_to_segment_2d(mouse_pos, screen_positions[a], screen_positions[b]);
		if (d < best_d) {
			best_d = d;
			best_a = a;
			best_b = b;
		}
	}
	if (best_a < 0 || best_b < 0 || best_d > threshold) {
		return out;
	}
	out["a"] = best_a;
	out["b"] = best_b;
	return out;
}

bool BrushForgeNative::structure_states_equal(const Array &a, const Array &b) const {
	if (a.size() != b.size()) {
		return false;
	}
	for (int i = 0; i < a.size(); i++) {
		if (a[i].get_type() != Variant::DICTIONARY || b[i].get_type() != Variant::DICTIONARY) {
			return false;
		}
		Dictionary ai = a[i];
		Dictionary bi = b[i];
		if (ai.get("position", Vector3()) != bi.get("position", Vector3())) {
			return false;
		}
		if (ai.get("size", Vector3()) != bi.get("size", Vector3())) {
			return false;
		}
		Array ap = ai.get("planes", Array());
		Array bp = bi.get("planes", Array());
		if (ap.size() != bp.size()) {
			return false;
		}
		for (int j = 0; j < ap.size(); j++) {
			if (ap[j].get_type() != Variant::DICTIONARY || bp[j].get_type() != Variant::DICTIONARY) {
				return false;
			}
			Dictionary api = ap[j];
			Dictionary bpi = bp[j];
			if (api.get("normal", Vector3()) != bpi.get("normal", Vector3())) {
				return false;
			}
			double ad = (double)api.get("distance", 0.0);
			double bd = (double)bpi.get("distance", 0.0);
			if (ad != bd) {
				return false;
			}
		}
	}
	return true;
}

bool BrushForgeNative::states_equal(const Array &a, const Array &b) const {
	if (a.size() != b.size()) {
		return false;
	}
	for (int i = 0; i < a.size(); i++) {
		if (a[i].get_type() != Variant::DICTIONARY || b[i].get_type() != Variant::DICTIONARY) {
			return false;
		}
		Dictionary ai = a[i];
		Dictionary bi = b[i];
		if (ai.get("position", Vector3()) != bi.get("position", Vector3())) {
			return false;
		}
		if (ai.get("size", Vector3()) != bi.get("size", Vector3())) {
			return false;
		}
		Array ap = ai.get("planes", Array());
		Array bp = bi.get("planes", Array());
		if (ap.size() != bp.size()) {
			return false;
		}
		for (int j = 0; j < ap.size(); j++) {
			if (ap[j].get_type() != Variant::DICTIONARY || bp[j].get_type() != Variant::DICTIONARY) {
				return false;
			}
			Dictionary api = ap[j];
			Dictionary bpi = bp[j];
			if (api.get("normal", Vector3()) != bpi.get("normal", Vector3())) {
				return false;
			}
			double ad = (double)api.get("distance", 0.0);
			double bd = (double)bpi.get("distance", 0.0);
			if (ad != bd) {
				return false;
			}
		}
		if (ai.get("face_material_paths", Dictionary()) != bi.get("face_material_paths", Dictionary())) {
			return false;
		}
		if (ai.get("face_uv_transforms", Dictionary()) != bi.get("face_uv_transforms", Dictionary())) {
			return false;
		}
		if (ai.get("face_paint_colors", Dictionary()) != bi.get("face_paint_colors", Dictionary())) {
			return false;
		}
		if (ai.get("face_paint_strokes", Dictionary()) != bi.get("face_paint_strokes", Dictionary())) {
			return false;
		}
		if (ai.get("face_subdivisions", Dictionary()) != bi.get("face_subdivisions", Dictionary())) {
			return false;
		}
		bool al = (bool)ai.get("lock_uvs", false);
		bool bl = (bool)bi.get("lock_uvs", false);
		if (al != bl) {
			return false;
		}
	}
	return true;
}

Array BrushForgeNative::clone_state(const Array &state) const {
	Array out;
	out.resize(state.size());
	for (int i = 0; i < state.size(); i++) {
		if (state[i].get_type() != Variant::DICTIONARY) {
			out[i] = Dictionary();
			continue;
		}
		Dictionary item = state[i];
		Array planes_copy;
		Array planes_src = item.get("planes", Array());
		for (int j = 0; j < planes_src.size(); j++) {
			if (planes_src[j].get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary p = planes_src[j];
			Dictionary pc;
			pc["normal"] = p.get("normal", Vector3(0.0, 1.0, 0.0));
			pc["distance"] = (double)p.get("distance", 0.0);
			planes_copy.push_back(pc);
		}
		Dictionary copied;
		copied["position"] = item.get("position", Vector3());
		copied["size"] = item.get("size", Vector3(1.0, 1.0, 1.0));
		copied["planes"] = planes_copy;
		Dictionary face_material_paths = item.get("face_material_paths", Dictionary());
		Dictionary face_uv_transforms = item.get("face_uv_transforms", Dictionary());
		Dictionary face_paint_colors = item.get("face_paint_colors", Dictionary());
		Dictionary face_paint_strokes = item.get("face_paint_strokes", Dictionary());
		Dictionary face_subdivisions = item.get("face_subdivisions", Dictionary());
		copied["face_material_paths"] = face_material_paths.duplicate(true);
		copied["face_uv_transforms"] = face_uv_transforms.duplicate(true);
		copied["face_paint_colors"] = face_paint_colors.duplicate(true);
		copied["face_paint_strokes"] = face_paint_strokes.duplicate(true);
		copied["face_subdivisions"] = face_subdivisions.duplicate(true);
		copied["lock_uvs"] = (bool)item.get("lock_uvs", false);
		out[i] = copied;
	}
	return out;
}
