#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_DIR="$ROOT_DIR/addons/brush_forge_editor"
NATIVE_DIR="$ADDON_DIR/native/brush_forge_native"
OUT_DIR="$ADDON_DIR/bin"

STAMP="$(date +%Y%m%d_%H%M%S)"
PKG_BASENAME="brush_forge_editor_furnished_${STAMP}"
STAGE_DIR="$(mktemp -d)"
ZIP_PATH="$OUT_DIR/${PKG_BASENAME}.zip"
TAR_PATH="$OUT_DIR/${PKG_BASENAME}.tar.gz"

echo "[1/3] Building native extension (debug + release)..."
(
	cd "$NATIVE_DIR"
	scons -Q target=template_debug
	scons -Q target=template_release
)

echo "[2/3] Staging furnished addon..."
rm -rf "$OUT_DIR"/brush_forge_editor_furnished_* "$ZIP_PATH" "$TAR_PATH"
mkdir -p "$OUT_DIR" "$STAGE_DIR"

if command -v rsync >/dev/null 2>&1; then
	rsync -a "$ADDON_DIR/" "$STAGE_DIR/brush_forge_editor/" \
		--exclude "native/brush_forge_native/godot-cpp-godot-4.5-stable/" \
		--exclude "native/brush_forge_native/.sconsign.dblite" \
		--exclude "native/brush_forge_native/src/*.os" \
		--exclude "**/*.uid"
else
	cp -a "$ADDON_DIR" "$STAGE_DIR/brush_forge_editor"
	rm -rf "$STAGE_DIR/brush_forge_editor/native/brush_forge_native/godot-cpp-godot-4.5-stable"
	rm -f "$STAGE_DIR/brush_forge_editor/native/brush_forge_native/.sconsign.dblite"
	find "$STAGE_DIR/brush_forge_editor/native/brush_forge_native/src" -name "*.os" -type f -delete || true
	find "$STAGE_DIR/brush_forge_editor" -name "*.uid" -type f -delete || true
fi

echo "[3/3] Creating archive..."
if command -v zip >/dev/null 2>&1; then
	(
		cd "$STAGE_DIR"
		zip -qr "$ZIP_PATH" "brush_forge_editor"
	)
	echo "Done: $ZIP_PATH"
else
	(
		cd "$STAGE_DIR"
		tar -czf "$TAR_PATH" "brush_forge_editor"
	)
	echo "Done: $TAR_PATH"
fi

rm -rf "$STAGE_DIR"
echo "Excluded: native/brush_forge_native/godot-cpp-godot-4.5-stable"
