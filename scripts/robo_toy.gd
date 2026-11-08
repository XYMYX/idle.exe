class_name RoboToy
extends AnimatedSprite2D
## A small wind-up robot toy on the floor (pure decoration). It walks back and forth until the
## battery is empty, then falls over and lies there. A click winds it up again; a click while it
## walks makes it beep and turn around.
##
## Sheets (art/robo_toy_*.png, square frames, facing right): walk, idle, wind, fall.
## Missing sheets are drawn as grey placeholder boxes.

signal moved

enum State { WALK, IDLE, WIND, FALL, LYING, HELD, DROP }

const GRAVITY := 600.0

const SPEED := 10.0
const ROAM := 50.0
const BATTERY_SEC := Vector2(40.0, 120.0)
const IDLE_SEC := Vector2(2.0, 5.0)
const FRAMES := {"walk": 4, "idle": 2, "wind": 3, "fall": 3, "held": 4}
const PLACEHOLDER_SIZE := 16

var home_x := 0.0
var floor_y := 0.0
var _vel := Vector2.ZERO
var min_x := 0.0
var max_x := 0.0
var size := float(PLACEHOLDER_SIZE)
var paused := false:
	set(value):
		paused = value
		if paused:
			pause()
		else:
			play()

var _state := State.IDLE
var _x := 0.0
var _target := 0.0
var _battery := 0.0
var _timer := 0.0
var _image_cache := {}
var _bubble: SpeechBubble


func _ready() -> void:
	centered = false
	var sf := SpriteFrames.new()
	_add(sf, "walk", _frames("walk"), 8.0, [], true)
	_add(sf, "idle", _frames("idle"), 2.0, [], true)
	_add(sf, "wind", _frames("wind"), 8.0, [], false)
	_add(sf, "fall", _frames("fall"), 8.0, [], false)
	var fall := _frames("fall")
	_add(sf, "lying", fall, 1.0, [fall.size() - 1], true)
	# Lifted: legs keep stepping in the air (robo_toy_held.png, else the walk frames)
	var held := _frames("held") if ResourceLoader.exists("res://art/robo_toy_held.png") else _frames("walk")
	_add(sf, "held", held, 10.0, [], true)
	sprite_frames = sf
	animation_finished.connect(_on_animation_finished)
	_bubble = SpeechBubble.new()
	_bubble.position = Vector2(roundf(size * 0.5), -12.0)
	add_child(_bubble)


func setup(home: float, lo: float, hi: float) -> void:
	min_x = lo
	max_x = hi
	floor_y = position.y
	home_x = clampf(home, lo, hi)
	_x = home_x
	position.x = home_x
	_wind_up()


func set_home(home: float) -> void:
	home_x = clampf(home, min_x, max_x)


## Click: wind it up (lying or idle) or beep and turn around (walking).
## Returns true if it was wound up (counted for the CTF flag).
func poke() -> bool:
	match _state:
		State.LYING, State.IDLE:
			_state = State.WIND
			flip_h = false
			play("wind")
			return true
		State.WALK:
			_bubble.flash("excl", 1.0)
			_target = clampf(_x + (-ROAM if _target > _x else ROAM), min_x, max_x)
			flip_h = _target < _x
	return false


func _process(delta: float) -> void:
	if paused or not visible:
		return
	if _state == State.DROP:
		_vel.y += GRAVITY * delta
		var pos := position + _vel * delta
		pos.x = clampf(pos.x, min_x, max_x)
		if pos.y >= floor_y:
			pos.y = floor_y
			_state = State.FALL  # dropped: it tips over and has to be wound up again
			play("fall")
		position = pos.round() if _state == State.FALL else pos
		_x = position.x
		moved.emit()
		return
	match _state:
		State.WALK:
			_battery -= delta
			if _battery <= 0.0:
				_state = State.FALL
				play("fall")
				return
			_x = move_toward(_x, _target, SPEED * delta)
			var px := roundf(_x)
			if px != position.x:
				position.x = px
				moved.emit()
			if _x == _target:
				_state = State.IDLE
				_timer = randf_range(IDLE_SEC.x, IDLE_SEC.y)
				play("idle")
		State.IDLE:
			_battery -= delta * 0.25  # standing uses less battery
			_timer -= delta
			if _timer <= 0.0:
				_walk_somewhere()


func _wind_up() -> void:
	_battery = randf_range(BATTERY_SEC.x, BATTERY_SEC.y)
	_walk_somewhere()


func _walk_somewhere() -> void:
	_state = State.WALK
	_target = clampf(home_x + randf_range(-ROAM, ROAM), min_x, max_x)
	flip_h = _target < _x
	play("walk")


func _on_animation_finished() -> void:
	match _state:
		State.WIND:
			_bubble.flash("note", 1.5)
			_wind_up()
		State.FALL:
			_state = State.LYING
			play("lying")


func hit(p: Vector2) -> bool:
	if not visible:
		return false
	var tex := sprite_frames.get_frame_texture(animation, frame)
	if tex == null:
		return false
	var local := (p - position - offset).floor()
	if flip_h:
		local.x = tex.get_width() - 1 - local.x
	if local.x < 0 or local.y < 0 or local.x >= tex.get_width() or local.y >= tex.get_height():
		return false
	if not _image_cache.has(tex):
		_image_cache[tex] = tex.get_image()
	var img: Image = _image_cache[tex]
	return img != null and img.get_pixelv(Vector2i(local)).a > 0.1


func is_lifted() -> bool:
	return _state == State.HELD or _state == State.DROP


func grab() -> void:
	_state = State.HELD
	flip_h = false
	play("held")


func drag_to(p: Vector2) -> void:
	var pos := (p - Vector2(size * 0.5, 1.0)).round()
	pos.x = clampf(pos.x, min_x, max_x)
	pos.y = clampf(pos.y, 0.0, floor_y)
	if pos != position:
		position = pos
		_x = pos.x
		moved.emit()


func drop(vel: Vector2) -> void:
	_vel = vel
	_state = State.DROP


func state_name() -> String:
	return State.keys()[_state]


func _frames(anim: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var path := "res://art/robo_toy_%s.png" % anim
	if ResourceLoader.exists(path):
		var sheet: Texture2D = load(path)
		size = sheet.get_height()
		for i in sheet.get_width() / sheet.get_height():
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * size, 0, size, size)
			out.append(atlas)
		return out
	var s := PLACEHOLDER_SIZE
	for i in FRAMES[anim]:
		var h := s * 3 / 4 if anim != "fall" else maxi(4, s * 3 / 4 - i * 3)
		var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
		img.fill_rect(Rect2i(s / 4, s - h, s / 2, h), Color(0.85, 0.85, 0.85))
		img.fill_rect(Rect2i(s / 4 + 1, s - h + 1, s / 2 - 2, h - 2), Color(0.45, 0.45, 0.45))
		out.append(ImageTexture.create_from_image(img))
	return out


func _add(sf: SpriteFrames, anim: String, frames: Array[Texture2D], fps: float, seq: Array, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	if seq.is_empty():
		for t in frames:
			sf.add_frame(anim, t)
	else:
		for i: int in seq:
			sf.add_frame(anim, frames[mini(i, frames.size() - 1)])
