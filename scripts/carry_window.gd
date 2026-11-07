class_name CarryWindow
extends Window
## Kleines, randloses, transparentes Fenster, das XYMYX zeigt, solange er getragen
## wird oder fällt. So muss das Hauptfenster (die Leiste) nie wachsen oder springen.
## Klicks gehen durch (mouse_passthrough), die Maus bleibt beim Hauptfenster.

var sprite: AnimatedSprite2D


func setup(frames: SpriteFrames, pixel_scale: int, figure: int) -> void:
	borderless = true
	transparent = true
	transparent_bg = true
	unresizable = true
	unfocusable = true
	mouse_passthrough = true
	# Gehört zum Hauptfenster (das immer oben ist): bleibt darüber, kein Taskleisten-Eintrag.
	transient = true
	visible = false
	size = Vector2i(figure * pixel_scale, figure * pixel_scale)
	sprite = AnimatedSprite2D.new()
	sprite.centered = false
	sprite.scale = Vector2(pixel_scale, pixel_scale)
	sprite.sprite_frames = frames
	add_child(sprite)


## Bild der Figur übernehmen und an die Bildschirmposition (linke obere Ecke) setzen.
func follow(src: AnimatedSprite2D, screen_pos: Vector2i) -> void:
	if sprite.animation != src.animation:
		sprite.animation = src.animation
	sprite.frame = src.frame
	sprite.flip_h = src.flip_h
	if position != screen_pos:
		position = screen_pos
	if not visible:
		show()
