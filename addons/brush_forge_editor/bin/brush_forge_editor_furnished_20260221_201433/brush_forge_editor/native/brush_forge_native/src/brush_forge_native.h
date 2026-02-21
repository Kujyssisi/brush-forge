#ifndef BRUSH_FORGE_NATIVE_H
#define BRUSH_FORGE_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

class BrushForgeNative : public RefCounted {
	GDCLASS(BrushForgeNative, RefCounted);

protected:
	static void _bind_methods();

public:
	PackedVector3Array compute_brush_vertices(const PackedVector3Array &plane_normals, const PackedFloat32Array &plane_distances) const;
	PackedVector3Array compute_face_hull(const PackedVector3Array &plane_normals, const PackedFloat32Array &plane_distances, int face_index, float epsilon = 0.02f) const;
	Array build_brush_surfaces(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const PackedVector3Array &vertices_world,
		const Vector3 &local_origin,
		bool lock_uvs,
		const Dictionary &face_uv_transforms,
		const Dictionary &face_paint_colors,
		const Dictionary &face_paint_strokes,
		const Dictionary &face_subdivisions) const;
	Dictionary pick_exact_face(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const Vector3 &ray_origin,
		const Vector3 &ray_dir) const;
	Array build_candidate_edges(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const PackedVector3Array &vertices_world,
		float epsilon = 0.02f,
		int min_incident = 3) const;
	PackedInt32Array face_vertex_indices(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const PackedVector3Array &vertices_world,
		int face_index,
		float epsilon = 0.02f) const;
	int nearest_vertex_index(const PackedVector3Array &vertices_world, const Vector3 &point) const;
	PackedInt32Array incident_plane_indices_for_vertex(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const Vector3 &vertex,
		float epsilon = 0.02f,
		int min_incident = 3) const;
	PackedInt32Array best_fit_plane_indices(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const PackedVector3Array &vertices_world,
		int target_count = 3) const;
	Array build_plane_vertex_incidence(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const PackedVector3Array &vertices_world,
		float epsilon = 0.02f) const;
	PackedInt32Array resolve_drag_plane_indices(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const PackedVector3Array &selected_vertices_world,
		int target_count = 3,
		float epsilon = 0.02f,
		int min_incident = 3) const;
	int pick_vertex_screen(
		const PackedVector2Array &screen_positions,
		const Vector2 &mouse_pos,
		float threshold = 16.0f) const;
	Dictionary pick_edge_screen(
		const PackedVector2Array &screen_positions,
		const Array &edges,
		const Vector2 &mouse_pos,
		float threshold = 14.0f) const;
	Dictionary fit_plane_from_points(
		const PackedVector3Array &points,
		const Vector3 &reference_normal) const;
	Vector3 face_center(
		const PackedVector3Array &plane_normals,
		const PackedFloat32Array &plane_distances,
		const PackedVector3Array &vertices_world,
		int face_index,
		float epsilon = 0.02f) const;
	Dictionary align_copied_uv_transform(
		const Dictionary &src_basis,
		const Dictionary &dst_basis,
		const Dictionary &src_uv,
		const Vector3 &anchor_world) const;
	Dictionary compute_bounds_from_vertices(
		const PackedVector3Array &vertices_world,
		float min_extent = 0.001f) const;
	Dictionary uv_basis_from_face_index(int face_index) const;
	Dictionary face_basis_from_index(int face_index) const;
	Variant ray_plane_hit_normal(
		const Vector3 &ray_origin,
		const Vector3 &ray_dir,
		const Vector3 &plane_origin,
		const Vector3 &plane_normal) const;
	Variant ray_plane_hit_y(
		const Vector3 &ray_origin,
		const Vector3 &ray_dir,
		float plane_y) const;
	float snap_float(float value, float step) const;
	Vector3 snap_vector(const Vector3 &v, float step) const;
	float world_units_per_pixel_at(
		float distance_to_world_pos,
		float camera_fov_degrees,
		float viewport_height) const;
	float axis_delta_from_screen(
		const Vector2 &screen_origin,
		const Vector2 &screen_axis_tip,
		const Vector2 &mouse_pos,
		const Vector2 &drag_start_mouse) const;
	Dictionary apply_vertex_drag_delta(
		const PackedVector3Array &start_vertices,
		const PackedInt32Array &selected_vertex_indices,
		const PackedInt32Array &plane_indices,
		const Array &plane_vertex_incidence,
		const PackedVector3Array &start_plane_normals,
		const PackedFloat32Array &start_plane_distances,
		const Vector3 &delta) const;
	bool structure_states_equal(const Array &a, const Array &b) const;
	bool states_equal(const Array &a, const Array &b) const;
	Array clone_state(const Array &state) const;
};

} // namespace godot

#endif // BRUSH_FORGE_NATIVE_H
