#include "brush_forge_native.h"

using namespace godot;

Dictionary BrushForgeNative::uv_basis_from_face_index(int face_index) const {
	Vector3 normal = Vector3(0.0, 1.0, 0.0);
	switch (face_index) {
		case 0:
			normal = Vector3(1.0, 0.0, 0.0);
			break;
		case 1:
			normal = Vector3(-1.0, 0.0, 0.0);
			break;
		case 2:
			normal = Vector3(0.0, 1.0, 0.0);
			break;
		case 3:
			normal = Vector3(0.0, -1.0, 0.0);
			break;
		case 4:
			normal = Vector3(0.0, 0.0, 1.0);
			break;
		case 5:
			normal = Vector3(0.0, 0.0, -1.0);
			break;
		default:
			break;
	}
	Vector3 tangent = Vector3(1.0, 0.0, 0.0);
	if (Math::abs(normal.dot(tangent)) > 0.95f) {
		tangent = Vector3(0.0, 1.0, 0.0);
	}
	tangent = (tangent - normal * tangent.dot(normal)).normalized();
	const Vector3 bitangent = normal.cross(tangent).normalized();
	Dictionary out;
	out["u"] = tangent;
	out["v"] = bitangent;
	return out;
}

Dictionary BrushForgeNative::face_basis_from_index(int face_index) const {
	Dictionary out;
	switch (face_index) {
		case 0:
			out["normal"] = Vector3(1.0, 0.0, 0.0);
			out["u"] = Vector3(0.0, 0.0, -1.0);
			out["v"] = Vector3(0.0, 1.0, 0.0);
			return out;
		case 1:
			out["normal"] = Vector3(-1.0, 0.0, 0.0);
			out["u"] = Vector3(0.0, 0.0, 1.0);
			out["v"] = Vector3(0.0, 1.0, 0.0);
			return out;
		case 2:
			out["normal"] = Vector3(0.0, 1.0, 0.0);
			out["u"] = Vector3(1.0, 0.0, 0.0);
			out["v"] = Vector3(0.0, 0.0, 1.0);
			return out;
		case 3:
			out["normal"] = Vector3(0.0, -1.0, 0.0);
			out["u"] = Vector3(1.0, 0.0, 0.0);
			out["v"] = Vector3(0.0, 0.0, -1.0);
			return out;
		case 4:
			out["normal"] = Vector3(0.0, 0.0, 1.0);
			out["u"] = Vector3(1.0, 0.0, 0.0);
			out["v"] = Vector3(0.0, 1.0, 0.0);
			return out;
		case 5:
			out["normal"] = Vector3(0.0, 0.0, -1.0);
			out["u"] = Vector3(-1.0, 0.0, 0.0);
			out["v"] = Vector3(0.0, 1.0, 0.0);
			return out;
		default:
			break;
	}
	out["normal"] = Vector3(0.0, 1.0, 0.0);
	out["u"] = Vector3(1.0, 0.0, 0.0);
	out["v"] = Vector3(0.0, 0.0, -1.0);
	return out;
}

Variant BrushForgeNative::ray_plane_hit_normal(
	const Vector3 &ray_origin,
	const Vector3 &ray_dir,
	const Vector3 &plane_origin,
	const Vector3 &plane_normal) const {
	const float denom = ray_dir.dot(plane_normal);
	if (Math::abs(denom) < 0.0001f) {
		return Variant();
	}
	const float t = (plane_origin - ray_origin).dot(plane_normal) / denom;
	if (t < 0.0f) {
		return Variant();
	}
	return ray_origin + ray_dir * t;
}

Variant BrushForgeNative::ray_plane_hit_y(
	const Vector3 &ray_origin,
	const Vector3 &ray_dir,
	float plane_y) const {
	const float denom = ray_dir.dot(Vector3(0.0, 1.0, 0.0));
	if (Math::abs(denom) < 0.0001f) {
		return Variant();
	}
	const float t = (plane_y - ray_origin.y) / denom;
	if (t < 0.0f) {
		return Variant();
	}
	return Vector3(
		ray_origin.x + ray_dir.x * t,
		plane_y,
		ray_origin.z + ray_dir.z * t);
}

float BrushForgeNative::snap_float(float value, float step) const {
	if (step <= 0.000001f) {
		return value;
	}
	return Math::round(value / step) * step;
}

Vector3 BrushForgeNative::snap_vector(const Vector3 &v, float step) const {
	return Vector3(
		snap_float(v.x, step),
		snap_float(v.y, step),
		snap_float(v.z, step));
}

float BrushForgeNative::world_units_per_pixel_at(
	float distance_to_world_pos,
	float camera_fov_degrees,
	float viewport_height) const {
	if (viewport_height <= 1.0f) {
		return 0.01f;
	}
	const float fov_rad = Math::deg_to_rad(camera_fov_degrees);
	const float units = (2.0f * distance_to_world_pos * Math::tan(fov_rad * 0.5f)) / viewport_height;
	return MAX(units, 0.0001f);
}

float BrushForgeNative::axis_delta_from_screen(
	const Vector2 &screen_origin,
	const Vector2 &screen_axis_tip,
	const Vector2 &mouse_pos,
	const Vector2 &drag_start_mouse) const {
	const Vector2 axis_screen = screen_axis_tip - screen_origin;
	const float axis_len = axis_screen.length();
	if (axis_len < 0.0001f) {
		return 0.0f;
	}
	const Vector2 axis_dir = axis_screen / axis_len;
	const Vector2 mouse_delta = mouse_pos - drag_start_mouse;
	const float pixels_along_axis = mouse_delta.dot(axis_dir);
	return pixels_along_axis / axis_len;
}
