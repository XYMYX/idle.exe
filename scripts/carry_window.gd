class_name CarryWindow
extends Window
## Small borderless transparent window that shows a figure (XYMYX or a pet) while it is
## carried or falling, also above the strip.
## This way the main window (the strip) never has to grow or jump.
## Clicks pass through (mouse_passthrough), the mouse stays with the main window.

var sprite: AnimatedSprite2D
var _pixel_scale := 1


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
	_pixel_scale = pixel_scale
	sprite.scale = Vector2(pixel_scale, pixel_scale)
	sprite.sprite_frames = frames
	add_child(sprite)


## Show another figure (pets: own frames and size).
func set_figure(frames: SpriteFrames, figure: int, pixel_scale: int) -> void:
	sprite.sprite_frames = frames
	size = Vector2i(figure * pixel_scale, figure * pixel_scale)


## Copy the figure's current frame and move to the screen position (top-left corner).
func follow(src: AnimatedSprite2D, screen_pos: Vector2i) -> void:
	if sprite.animation != src.animation:
		sprite.animation = src.animation
	sprite.frame = src.frame
	sprite.flip_h = src.flip_h
	sprite.scale = src.scale * _pixel_scale  # old sheets ×3, redrawn ones 1:1 (like in the strip)
	if position != screen_pos:
		position = screen_pos
	if not visible:
		show()
