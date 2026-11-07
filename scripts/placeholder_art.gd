class_name PlaceholderArt
extends RefCounted
## Loads sprite sheets from res://art/ or creates placeholders
## while the real graphics are missing.

const SIZE := 48


## Returns the frames of a horizontal sprite sheet (SIZE×SIZE per frame).
## If the file is missing, the fallback frames are returned.
static func load_frames(path: String, fallback: Array[Texture2D]) -> Array[Texture2D]:
	if not ResourceLoader.exists(path):
		return fallback
	var sheet: Texture2D = load(path)
	var frames: Array[Texture2D] = []
	for i in sheet.get_width() / SIZE:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * SIZE, 0, SIZE, SIZE)
		frames.append(atlas)
	return frames


## Black square with a white 1 px outline and two white eye pixels.
## bob moves the body down by n pixels (bobbing motion).
static func box(eye_a: Vector2i, eye_b: Vector2i, bob: int = 0) -> Texture2D:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, bob, SIZE, SIZE - bob), Color.WHITE)
	img.fill_rect(Rect2i(1, bob + 1, SIZE - 2, SIZE - bob - 2), Color.BLACK)
	img.set_pixelv(eye_a + Vector2i(0, bob), Color.WHITE)
	img.set_pixelv(eye_b + Vector2i(0, bob), Color.WHITE)
	return ImageTexture.create_from_image(img)


static func sit_frames() -> Array[Texture2D]:
	# Looking down-right at the laptop, bobbing while typing
	return [box(Vector2i(20, 9), Vector2i(25, 9)), box(Vector2i(21, 10), Vector2i(26, 10), 1)]


static func walk_frames() -> Array[Texture2D]:
	# Looking right, bobbing while walking
	var up := box(Vector2i(19, 8), Vector2i(24, 8))
	var down := box(Vector2i(19, 8), Vector2i(24, 8), 1)
	return [up, down, up, down]
