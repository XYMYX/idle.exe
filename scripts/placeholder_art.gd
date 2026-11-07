class_name PlaceholderArt
extends RefCounted
## Lädt Sprite-Sheets aus res://art/ oder erzeugt Platzhalter,
## solange die echten Grafiken fehlen.

const SIZE := 48


## Liefert die Frames eines horizontalen Sprite-Sheets (32×32 pro Frame).
## Fehlt die Datei, werden Platzhalter-Frames erzeugt.
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


## Schwarzes Quadrat mit weissem 1-px-Umriss und zwei weissen Augen-Pixeln.
## bob verschiebt den Körper um n Pixel nach unten (Wipp-Bewegung).
static func box(eye_a: Vector2i, eye_b: Vector2i, bob: int = 0) -> Texture2D:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, bob, SIZE, SIZE - bob), Color.WHITE)
	img.fill_rect(Rect2i(1, bob + 1, SIZE - 2, SIZE - bob - 2), Color.BLACK)
	img.set_pixelv(eye_a + Vector2i(0, bob), Color.WHITE)
	img.set_pixelv(eye_b + Vector2i(0, bob), Color.WHITE)
	return ImageTexture.create_from_image(img)


static func sit_frames() -> Array[Texture2D]:
	# Blick nach rechts unten auf den Laptop, wippt beim Tippen
	return [box(Vector2i(20, 9), Vector2i(25, 9)), box(Vector2i(21, 10), Vector2i(26, 10), 1)]


static func walk_frames() -> Array[Texture2D]:
	# Blick nach rechts, wippt beim Laufen
	var up := box(Vector2i(19, 8), Vector2i(24, 8))
	var down := box(Vector2i(19, 8), Vector2i(24, 8), 1)
	return [up, down, up, down]
