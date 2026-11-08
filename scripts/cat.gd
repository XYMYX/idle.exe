class_name Cat
extends AnimatedSprite2D
## The cat (pure decoration, adopted in the terminal). Lives on her own: walks around,
## sits, grooms, curls up to sleep. Follows XYMYX now and then on his walks, rears up
## when the mouse comes close (mouse position only) and can be petted with a click.
##
## Sitting is the hub: from there she grooms, lies down, rears up or stands up.
## The sheets (art/<kind>_*.png, square frames: frame size = sheet height) face right, left = mirrored.
##
## Also used for the other walking pets (set «kind» before adding the node):
##   dog:      wag (instead of grooming), bark (instead of rearing up)
##   elephant: spray (instead of grooming), trumpet (instead of rearing up)
##   hamster:  eat (instead of grooming), stand (stands up on its hind legs instead of rearing up)
## Missing sheets are drawn as grey placeholder boxes in the right size.

signal moved

enum State { STAND, WALK, SIT, GROOM, SLEEP, REAR, BUSY, GRABBED, FALLING }

const GRAVITY := 600.0  # game pixels per second² (like XYMYX)

const SPEED := 14.0                          # game pixels per second
const STAND_TIME := Vector2(3.0, 8.0)
const SIT_TIME := Vector2(6.0, 15.0)
const GROOM_TIME := Vector2(2.0, 4.0)
const SLEEP_TIME := Vector2(60.0, 180.0)
const ROAM := 70.0                           # walks around her home spot at most this far
const FOLLOW_CHANCE := 0.5                   # share of XYMYX's walks she joins
const FOLLOW_GAP := 30.0                     # distance she keeps to him
const MOUSE_RADIUS := 36.0                   # game pixels around her center
const MOUSE_GONE_SEC := 1.5
const REAR_COOLDOWN := 20.0
const HEART_SEC := 2.5

## Set by main: XYMYX's x while he is out walking, -1.0 otherwise.
var xymyx_out_x: Callable
var home_x := 0.0
var min_x := 0.0
var max_x := 0.0
var paused := false:
	set(value):
		paused = value
		if paused:
			pause()
		else:
			play()

var _state := State.SIT
var _timer := 0.0
var _x := 0.0
var _target_x := 0.0
var _after_walk := State.STAND
var _next: Callable                 # runs when a transition animation ends
var _following := false
var _follow_decided := false        # decided once per walk of XYMYX
var _follow_check := 0.0
var _mouse_gone := 0.0
var _rear_cooldown := 0.0
var _forced_sleep := false          # user away: sleeps until the mouse moves again
var _image_cache := {}
var _bubble: SpeechBubble
var size := 48.0  # frame size in game px (sheet height)
var kind := "cat"
var floor_y := 0.0      # y on the floor (top edge of the sprite)
var _vel := Vector2.ZERO

## Sheet names per kind: hub animation -> file suffix. Placeholder size if a sheet is missing.
const SHEETS := {
	"cat": {"idle": "idle", "walk": "walk", "sit": "sit", "curl": "curl", "groom": "scratch", "rear": "rear", "size": 32},
	"dog": {"idle": "idle", "walk": "walk", "sit": "sit", "curl": "lie", "groom": "wag", "rear": "bark", "size": 32},
	"elephant": {"idle": "idle", "walk": "walk", "sit": "sit", "curl": "lie", "groom": "spray", "rear": "trumpet", "size": 40},
	"hamster": {"idle": "idle", "walk": "walk", "sit": "sit", "curl": "sleep", "groom": "eat", "rear": "stand", "size": 16},
}
## Lifting (optional sheets <kind>_dangle/_fall/_land.png); without them existing frames stand in.
const LIFT_SHEETS := ["dangle", "fall", "land"]
## Frames per sheet for the placeholders (same as the cat's sheets).
const PLACEHOLDER_FRAMES := {"idle": 4, "walk": 6, "sit": 4, "curl": 4, "groom": 4, "rear": 4}


func _ready() -> void:
	centered = false
	var sf := SpriteFrames.new()
	size = float(SHEETS[kind]["size"])
	var idle := _frames("idle")
	var walk := _frames("walk")
	var sit := _frames("sit")
	var curl := _frames("curl")
	var groom := _frames("groom")
	var rear := _frames("rear")
	_add(sf, "stand", idle, 3.0, [], true)
	_add(sf, "walk", walk, 8.0, [], true)
	_add(sf, "sit_down", sit, 6.0, [0, 1, 2, 3], false)
	_add(sf, "sit", sit, 1.0, [3], true)
	_add(sf, "stand_up", sit, 6.0, [3, 2, 1, 0], false)
	_add(sf, "groom", groom, 6.0, [], true)
	_add(sf, "lie_down", curl, 4.0, [0, 1, 2, 3], false)
	_add(sf, "sleep", curl, 1.0, [2, 3], true)
	_add(sf, "get_up", curl, 4.0, [3, 2, 1, 0], false)
	_add(sf, "rear_up", rear, 6.0, [0, 1, 2], false)
	_add(sf, "rear", rear, 2.0, [2, 3], true)
	_add(sf, "rear_down", rear, 6.0, [2, 1, 0], false)
	# Lifted with the mouse: hang, fall, land. Missing sheets: idle (hang), walk frame 1 (fall).
	var dangle := _lift_frames("dangle", idle)
	var fall := _lift_frames("fall", [walk[0]] as Array[Texture2D])
	var land := _lift_frames("land", [idle[0]] as Array[Texture2D])
	_add(sf, "dangle", dangle, 6.0, [], true)
	_add(sf, "fall", fall, 8.0, [], true)
	_add(sf, "land", land, 8.0, [], false)
	sprite_frames = sf
	animation_finished.connect(_on_animation_finished)
	_bubble = SpeechBubble.new()
	_bubble.position = Vector2(roundf(size * 0.7), 2.0 - roundf(size * 0.2))  # above her head
	add_child(_bubble)


func setup(home: float, lo: float, hi: float) -> void:
	min_x = lo
	max_x = hi
	floor_y = position.y
	home_x = clampf(home, lo, hi)
	_x = home_x
	position.x = home_x
	_sit()


## The desk was moved: new home spot. She walks there the next time she gets up.
func set_home(home: float) -> void:
	home_x = clampf(home, min_x, max_x)


func _process(delta: float) -> void:
	if paused:
		return
	# Carried or falling: shown in the carry window, so the strip sprite is hidden meanwhile
	if _state == State.FALLING:
		_process_fall(delta)
		return
	if _state == State.GRABBED or not visible:
		return
	_rear_cooldown -= delta
	_follow_check -= delta
	if _follow_check <= 0.0:
		_follow_check = 1.0
		_check_follow()
	match _state:
		State.STAND:
			_timer -= delta
			if _timer <= 0.0:
				if randf() < 0.5:
					_walk_to(_roam_target(), State.STAND)
				else:
					_play_then("sit_down", _sit)
		State.WALK:
			if _step_towards(_target_x, SPEED * delta):
				if _after_walk == State.SIT:
					_play_then("sit_down", _sit)
				else:
					_stand()
		State.SIT:
			_timer -= delta
			if _timer <= 0.0:
				var r := randf()
				if r < 0.35:
					_groom()
				elif r < 0.6:
					_play_then("lie_down", _sleep)
				else:
					_play_then("stand_up", _stand)
		State.GROOM:
			_timer -= delta
			if _timer <= 0.0:
				_sit()
		State.SLEEP:
			if not _forced_sleep:
				_timer -= delta
				if _timer <= 0.0:
					_play_then("get_up", _sit)
		State.REAR:
			_mouse_gone += delta
			if _mouse_gone >= MOUSE_GONE_SEC:
				_rear_cooldown = REAR_COOLDOWN
				_play_then("rear_down", _sit)


# --- Public -------------------------------------------------------------------

## Click: heart. Standing or sitting she sits down and grooms herself.
func pet() -> void:
	_bubble.flash("heart", HEART_SEC)
	match _state:
		State.STAND:
			_play_then("sit_down", _groom)
		State.SIT:
			_groom()


# --- Lifting with the mouse -------------------------------------------------------

func is_lifted() -> bool:
	return _state == State.GRABBED or _state == State.FALLING


func grab() -> void:
	_state = State.GRABBED
	_next = Callable()
	_following = false
	flip_h = false
	_bubble.flash("excl", 1.0)
	play("dangle")


## Hang from the cursor: p = grip point (top centre of the sprite). top = highest y (may be
## above the strip, up to the top of the screen).
func drag_to(p: Vector2, top := 0.0) -> void:
	var pos := (p - Vector2(size * 0.5, 1.0)).round()
	pos.x = clampf(pos.x, min_x, max_x)
	pos.y = clampf(pos.y, top, floor_y)
	if pos != position:
		position = pos
		_x = pos.x
		moved.emit()


func drop(vel: Vector2) -> void:
	_vel = vel
	_state = State.FALLING
	play("fall")


func _process_fall(delta: float) -> void:
	_vel.y += GRAVITY * delta
	var pos := position + _vel * delta
	if pos.x < min_x or pos.x > max_x:
		_vel.x = 0.0
		pos.x = clampf(pos.x, min_x, max_x)
	if pos.y >= floor_y:
		pos.y = floor_y
		position = pos.round()
		_x = position.x
		moved.emit()
		_play_then("land", _stand)
		return
	position = pos
	_x = pos.x
	moved.emit()


## Mouse position in game pixels (10× per second). Close by: she rears up and looks at it.
func mouse_at(g: Vector2) -> void:
	if not visible or paused or is_lifted():
		return
	var near := g.distance_to(position + Vector2(size * 0.5, size * 0.6)) < MOUSE_RADIUS
	if _state == State.REAR:
		if near:
			_mouse_gone = 0.0
			flip_h = g.x < position.x + size * 0.5
		return
	if not near or _rear_cooldown > 0.0 or _following:
		return
	match _state:
		State.SIT, State.GROOM:
			_rear_up()
		State.STAND:
			_play_then("sit_down", _rear_up)


## User away: she curls up too; back: she wakes up.
func set_away(away: bool) -> void:
	_forced_sleep = away
	if is_lifted():
		return
	if away and _state in [State.STAND, State.SIT, State.GROOM]:
		if _state == State.STAND:
			_play_then("sit_down", func() -> void: _play_then("lie_down", _sleep))
		else:
			_play_then("lie_down", _sleep)
	elif not away and _state == State.SLEEP:
		_timer = randf_range(2.0, 6.0)  # wakes up shortly after


## Pixel-exact hit test (like XYMYX).
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


func state_name() -> String:
	return State.keys()[_state]


# --- Following XYMYX ------------------------------------------------------------

func _check_follow() -> void:
	if not xymyx_out_x.is_valid() or is_lifted() or _state == State.BUSY:
		return
	var xx: float = xymyx_out_x.call()
	if xx < 0.0:  # he is home again
		_follow_decided = false
		if _following:
			_following = false
			if _state in [State.STAND, State.WALK]:
				_walk_to(home_x, State.SIT)
		return
	if not _follow_decided:
		_follow_decided = true
		_following = randf() < FOLLOW_CHANCE and _state != State.SLEEP
	if not _following:
		return
	var side := -1.0 if _x < xx else 1.0
	var target := clampf(xx + side * FOLLOW_GAP, min_x, max_x)
	match _state:
		State.STAND, State.WALK:
			if absf(target - _x) > 4.0:
				_walk_to(target, State.STAND)
		State.SIT, State.GROOM:
			_play_then("stand_up", _stand)
		State.REAR:
			_play_then("rear_down", _sit)


# --- States ---------------------------------------------------------------------

func _stand() -> void:
	_state = State.STAND
	_timer = randf_range(STAND_TIME.x, STAND_TIME.y)
	play("stand")


func _sit() -> void:
	_state = State.SIT
	_timer = randf_range(SIT_TIME.x, SIT_TIME.y)
	play("sit")


func _groom() -> void:
	_state = State.GROOM
	_timer = randf_range(GROOM_TIME.x, GROOM_TIME.y)
	play("groom")


func _sleep() -> void:
	_state = State.SLEEP
	_timer = randf_range(SLEEP_TIME.x, SLEEP_TIME.y)
	play("sleep")


func _rear_up() -> void:
	_mouse_gone = 0.0
	_play_then("rear_up", func() -> void:
		_state = State.REAR
		play("rear"))


func _walk_to(x: float, after: State) -> void:
	_state = State.WALK
	_target_x = x
	_after_walk = after
	flip_h = x < _x
	play("walk")


func _play_then(anim: String, next: Callable) -> void:
	_state = State.BUSY
	_next = next
	play(anim)


func _on_animation_finished() -> void:
	if _state == State.BUSY and _next.is_valid():
		var n := _next
		_next = Callable()
		n.call()


func _roam_target() -> float:
	return clampf(home_x + randf_range(-ROAM, ROAM), min_x, max_x)


func _step_towards(target: float, step: float) -> bool:
	_x = move_toward(_x, target, step)
	var px := roundf(_x)
	if px != position.x:
		position.x = px
		moved.emit()
	return _x == target


## Square frames from a sheet, frame size = sheet height (works for 48, 32, 24 ...).
func _frames(anim: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var path := "res://art/%s_%s.png" % [kind, SHEETS[kind][anim]]
	if not ResourceLoader.exists(path):
		return _placeholder(anim)
	var sheet: Texture2D = load(path)
	size = sheet.get_height()
	for i in sheet.get_width() / sheet.get_height():
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * size, 0, size, size)
		out.append(atlas)
	return out


## Optional lifting sheet; without it the given frames stand in.
func _lift_frames(anim: String, fallback: Array[Texture2D]) -> Array[Texture2D]:
	var path := "res://art/%s_%s.png" % [kind, anim]
	if not ResourceLoader.exists(path):
		return fallback
	var out: Array[Texture2D] = []
	var sheet: Texture2D = load(path)
	var s := sheet.get_height()
	for i in sheet.get_width() / s:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * s, 0, s, s)
		out.append(atlas)
	return out


## Grey box (body) on the floor with a lighter outline, one per frame. Sitting/lying frames get lower.
func _placeholder(anim: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var n: int = PLACEHOLDER_FRAMES[anim]
	var s := int(size)
	for i in n:
		var h := s * 3 / 5
		if anim == "sit" or anim == "curl":
			h = maxi(s / 4, h - (s / 8) * i)  # sinks down over the frames
		var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
		img.fill_rect(Rect2i(s / 8, s - h, s * 3 / 4, h), Color(0.85, 0.85, 0.85))
		img.fill_rect(Rect2i(s / 8 + 1, s - h + 1, s * 3 / 4 - 2, h - 2), Color(0.45, 0.45, 0.45))
		out.append(ImageTexture.create_from_image(img))
	return out


func _add(sf: SpriteFrames, anim: String, frames: Array[Texture2D], fps: float, seq: Array, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	if frames.is_empty():
		return
	if seq.is_empty():
		for t in frames:
			sf.add_frame(anim, t)
	else:
		for i: int in seq:
			sf.add_frame(anim, frames[mini(i, frames.size() - 1)])
