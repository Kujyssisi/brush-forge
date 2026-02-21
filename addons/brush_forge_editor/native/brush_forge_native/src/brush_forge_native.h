#ifndef BRUSH_FORGE_NATIVE_H
#define BRUSH_FORGE_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
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
	bool structure_states_equal(const Array &a, const Array &b) const;
	bool states_equal(const Array &a, const Array &b) const;
	Array clone_state(const Array &state) const;
};

} // namespace godot

#endif // BRUSH_FORGE_NATIVE_H
