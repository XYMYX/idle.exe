class_name Art
extends RefCounted
## Art resolution. Since 2026-11-08 the game works in 3× finer coordinates: XYMYX is
## 144×144 game pixels (was 48). Sprites drawn at the new size are shown 1:1, sprites still
## in the old size are shown 3× bigger, so both work side by side while the art is redrawn.
## List of all sizes: docs/ART_3X.md.

const SCALE := 3


## Square frames of a horizontal sheet (frame size = sheet height), [] if the file is missing.
static func sheet_frames(path: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if not ResourceLoader.exists(path):
		return out
	var sheet: Texture2D = load(path)
	var s := sheet.get_height()
	for i in sheet.get_width() / s:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * s, 0, s, s)
		out.append(atlas)
	return out


## Node scale so that a frame of tex_height is shown target game pixels tall (old sheets: 3).
static func fit(tex_height: float, target: float) -> float:
	return target / maxf(tex_height, 1.0)
