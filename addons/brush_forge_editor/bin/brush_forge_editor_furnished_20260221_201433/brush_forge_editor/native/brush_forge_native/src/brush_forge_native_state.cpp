#include "brush_forge_native.h"

using namespace godot;

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
