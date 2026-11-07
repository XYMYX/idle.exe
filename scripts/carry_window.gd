class_name CarryWindow
extends Window
## Small borderless transparent window that shows XYMYX while he is carried or falling.
## This way the main window (the strip) never has to grow or jump.
## Clicks pass through (mouse_passthrough), the mouse stays with the main window.

var sprite: AnimatedSprite2D


func setup(frames: SpriteFrames, pixel_scale: int, figure: int) -> void:
	borderless = true
	transparent = true
	transparent_bg = true
	unresizable = true
	unfocusable = true
	mouse_passthrough = true
	# Owned by the main window (which is always on top): stays above it, no taskbar entry.
	transient = true
	visible = false
	size = Vector2i(figure * pixel_scale, figure * pixel_scale)
	sprite = AnimatedSprite2D.new()
	sprite.centered = false
	sprite.scale = Vector2(pixel_scale, pixel_scale)
	sprite.sprite_frames = frames
	add_child(sprite)


## Copy the figure's current frame and move to the screen position (top-left corner).
func follow(src: AnimatedSprite2D, screen_pos: Vector2i) -> void:
	if sprite.animation != src.animation:
		sprite.animation = src.animation
	sprite.frame = src.frame
	sprite.flip_h = src.flip_h
	if position != screen_pos:
		position = screen_pos
	if not visible:
		show()
