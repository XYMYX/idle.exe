class_name Xymyx
extends AnimatedSprite2D
## XYMYX: sits at the desk and types, plays small idle animations,
## walks around now and then, reacts to events and tinkers after purchases.
## Can be picked up with the mouse, carried around and dropped.

signal moved
signal chair_taken(taken: bool)  # true = the chair is part of the roll sprite, the desk hides its own
signal repair_started            # the desk flashes the purchased part
signal landed                    # back on the ground after being dropped
signal petted(target: Object)    # kneeled next to a pet: main lets it react (heart, wind-up)
signal charge_phase(phase: String)  # charging cabinet: opening, charging, full, closing

enum State { SITTING, WALKING_OUT, STANDING, WALKING_HOME, WALKING_TO_REPAIR, ACTION,
	GRABBED, FALLING, LANDING, SLEEPING, WALKING_TO_STATION, CHARGING }

const SIZE := 48.0 * Art.SCALE               # figure size in game pixels (144)
const WALK_SPEED := 18.0 * Art.SCALE         # game pixels per second
const SIT_TIME := Vector2(25.0, 70.0)        # seconds at the desk before a walk
const STAND_TIME := Vector2(2.0, 5.0)        # pause while out walking
const IDLE_ACTION_TIME := Vector2(12.0, 30.0) # gap between idle animations while typing
const MIN_WALK := 40.0 * Art.SCALE
const REPAIR_SEC := 2.5
const ROLL_DIST := 12.0 * Art.SCALE
const ROLL_SPEED := 16.0 * Art.SCALE
const GRAVITY := 600.0 * Art.SCALE    # game pixels per second²
const MAX_THROW := 250.0 * Art.SCALE  # highest throw speed (game pixels per second)
const FRONT_CHANCE := 0.5    # share of standing pauses with a look at the user

## Special animations from art/xymyx_<name>.png: speed and frame sequence (indices in the sheet).
## If a file is missing, the animation is simply skipped.
const ACTIONS := {
	"cheer": {"fps": 8.0, "seq": [0, 1, 2, 3, 2, 3, 2, 3, 2, 1, 0]},
	"stretch": {"fps": 4.0, "seq": [0, 1, 2, 3, 3, 3, 2, 1, 0]},
	"headdesk": {"fps": 6.0, "seq": [0, 1, 2, 3, 2, 2, 2, 2, 2, 2, 4, 0]},
	"drink": {"fps": 4.0, "seq": [0, 1, 2, 3, 3, 3, 2, 1, 0]},
	"roll": {"fps": 6.0, "seq": [0, 1, 2, 3], "loop": true},
	"repair": {"fps": 8.0, "seq": [0, 1, 2, 3], "loop": true},
	# Front view: seated quick look at the user / standing turn around, blink, wave
	"look": {"fps": 4.0, "seq": [0, 1, 1, 2, 1, 1, 1, 0]},
	"front": {"fps": 4.0, "seq": [0, 1, 1, 2, 1, 3, 3, 1, 0]},
	# Grabbed (wriggles, looks at the user), falling, landing
	"dangle": {"fps": 6.0, "seq": [0, 1, 2, 3], "loop": true},
	"fall": {"fps": 8.0, "seq": [0, 1], "loop": true},
	"land": {"fps": 8.0, "seq": [0, 1, 2, 3]},
	# Mouse reactions (optional): fall asleep at the desk, flinch
	"sleep": {"fps": 2.0, "seq": [0, 1, 2, 3], "loop": true},
	"startle": {"fps": 8.0, "seq": [0, 1, 2, 2, 1, 0]},
	# With the pets (optional): phone call and talking to the duck while seated, kneeling on a walk
	"phone": {"fps": 4.0, "seq": [0, 1, 2, 3, 2, 3, 2, 3, 2, 3, 2, 1, 0]},
	"duck_talk": {"fps": 4.0, "seq": [0, 1, 2, 3, 2, 3, 2, 3, 1, 0]},
	"kneel": {"fps": 6.0, "seq": [0, 1, 2, 3, 4, 3, 4, 3, 4, 2, 1, 0]},
}
const BUBBLE_POS := Vector2(32, -8) * Art.SCALE  # speech bubble in front of/above the face (game pixels from the corner)
## Occasional emote while typing (weights) and how long it stays
const IDLE_EMOTES := {"note": 4, "dots": 3, "heart": 2, "angry": 1}
const IDLE_EMOTE_TIME := Vector2(45.0, 120.0)
const EMOTE_SEC := 3.0
## Reaction -> emote (after events, milestones)
const REACT_EMOTES := {"cheer": "heart", "headdesk": "angry", "drink": "heart", "stretch": "dots"}
const HARD_LANDING := 300.0 * Art.SCALE  # from this fall speed on he gets angry
## Click jumps: every click within COMBO_SEC raises the level (height in game pixels).
## Up to TWEEN_MAX it stays a small hop inside the strip (he keeps typing),
## above that he really jumps (carry window, can go above the strip).
const JUMP_HEIGHTS := [12.0, 30.0, 54.0, 90.0, 135.0, 195.0, 270.0]  # old values ×3
const COMBO_SEC := 1.2
const TWEEN_MAX := 24.0
## Random pauses while typing, weighted (headdesk later via bug events)
const IDLE_ACTIONS := {"stretch": 3, "drink": 3, "roll": 1, "headdesk": 1, "look": 3, "phone": 2, "duck_talk": 2}
const KNEEL_CHANCE := 0.6  # standing on a walk with a pet close by: share of pauses with a kneel
## Charging cabinet (art/xymyx_charge.png, 4 frames front view; frame 3 = eyes off).
const CHARGE_CHANCE := 0.25          # share of breaks spent charging instead of walking
const CHARGE_SEC := Vector2(30.0, 60.0)
const CHARGE_RISE := 4.0             # stands 4 px higher than the cabinet's origin
const OPEN_SEC := 0.8                # doors opening (6 frames at 8 fps)
const FULL_SEC := 1.5                # shows the full battery before stepping out

var home_x := 0.0
var has_duck := false       # set by main: «duck_talk» only with the duck on the desk
var pet_near: Callable      # set by main: (x) -> pet object close to x or null
var station_x: Callable     # set by main: () -> x of the charging cabinet, -1 if there is none
var _charge_step := ""      # open, in, charge, full, out
var _kneel_target: Object = null
var repair_x := 0.0
var min_x := 0.0
var max_x := 0.0
var floor_y := 0.0  # y position on the floor (top edge of the sprite)
var paused := false:
	set(value):
		paused = value
		if paused:
			pause()
		elif _state != State.STANDING and not (_state == State.SLEEPING and animation != "sleep"):
			play()

var _state := State.SITTING
var _timer := 0.0
var _idle_timer := 0.0
var _x := 0.0
var _target_x := 0.0
var _action := ""
var _roll_back := false
var _repair_left := 0.0
var _fall_pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _combo := -1
var _last_click_ms := -100000
var _image_cache := {}  # texture -> Image, for the pixel-exact hit test
var _sleepy := false    # user away: fall asleep the next time he sits down
var _emote_timer := 60.0
var _bubble: SpeechBubble


func _ready() -> void:
	centered = false
	var sf := SpriteFrames.new()
	_add_anim(sf, "sit", PlaceholderArt.load_frames("res://art/xymyx_sit.png", PlaceholderArt.sit_frames()), 3.0, [])
	_add_anim(sf, "walk", PlaceholderArt.load_frames("res://art/xymyx_walk.png", PlaceholderArt.walk_frames()), 6.0, [])
	var none: Array[Texture2D] = []
	for anim: String in ACTIONS:
		var frames := PlaceholderArt.load_frames("res://art/xymyx_%s.png" % anim, none)
		if frames.is_empty():
			continue
		var a: Dictionary = ACTIONS[anim]
		_add_anim(sf, anim, frames, a["fps"], a["seq"], a.get("loop", false))
	var charge := PlaceholderArt.load_frames("res://art/xymyx_charge.png", none)
	if not charge.is_empty():
		_add_anim(sf, "charge_in", charge, 4.0, [0, 1, 2, 3], false)
		_add_anim(sf, "charge", charge, 1.0, [3], true)
		_add_anim(sf, "charge_out", charge, 4.0, [3, 2, 1, 0], false)
	sprite_frames = sf
	animation_finished.connect(_on_animation_finished)
	_bubble = SpeechBubble.new()
	add_child(_bubble)
	animation_changed.connect(_fit)
	_fit()


## Old 48 px sheets are shown ×3, new 144 px sheets 1:1. The speech bubble keeps its size.
func _fit() -> void:
	var tex := sprite_frames.get_frame_texture(animation, 0) if sprite_frames else null
	var s := Art.fit(tex.get_height(), SIZE) if tex else float(Art.SCALE)
	if scale.x != s:
		scale = Vector2(s, s)
	_bubble.scale = Vector2.ONE * Art.SCALE / s
	_bubble.position = BUBBLE_POS / s


## Old pixels -> local units (offset is in texture pixels, the node may be scaled 1× or 3×).
func _px(v: float) -> float:
	return v * Art.SCALE / scale.x


func setup(home: float, repair: float, lo: float, hi: float) -> void:
	home_x = home
	repair_x = repair
	min_x = lo
	max_x = hi
	_x = home
	position.x = home
	floor_y = position.y
	_sit()


func _process(delta: float) -> void:
	if _state == State.FALLING:
		_process_fall(delta)
		return
	if paused or _state == State.GRABBED or _state == State.LANDING or _state == State.SLEEPING:
		return
	match _state:
		State.SITTING:
			_timer -= delta
			_idle_timer -= delta
			_emote_timer -= delta
			if _timer <= 0.0:
				var sx: float = station_x.call() if station_x.is_valid() else -1.0
				if sx >= 0.0 and sprite_frames.has_animation("charge_in") and randf() < CHARGE_CHANCE:
					_walk_to(sx, State.WALKING_TO_STATION)
				else:
					_walk_to(_pick_target(), State.WALKING_OUT)
			elif _idle_timer <= 0.0:
				_play_random_idle()
			elif _emote_timer <= 0.0:
				_random_emote()
		State.STANDING:
			_timer -= delta
			if _timer <= 0.0:
				_walk_to(home_x, State.WALKING_HOME)
		State.WALKING_OUT, State.WALKING_HOME, State.WALKING_TO_REPAIR, State.WALKING_TO_STATION:
			if _step_towards(_target_x, WALK_SPEED * delta):
				match _state:
					State.WALKING_OUT: _stand()
					State.WALKING_HOME: _sit()
					State.WALKING_TO_REPAIR: _begin_repair()
					State.WALKING_TO_STATION: _begin_charge()
		State.CHARGING:
			_process_charge(delta)
		State.ACTION:
			if _action == "roll":
				_process_roll(delta)
			elif _action == "repair":
				_repair_left -= delta
				if _repair_left <= 0.0:
					_walk_to(home_x, State.WALKING_HOME)


# --- Public -------------------------------------------------------------------

## Seated reaction (cheer, headdesk, ...). Only while he sits at the desk.
func react(anim: String) -> void:
	if REACT_EMOTES.has(anim):
		emote(REACT_EMOTES[anim])
	if _state == State.SITTING and sprite_frames.has_animation(anim):
		_play_action(anim)


## Show an emote in the speech bubble (heart, angry, note, dots, question, excl).
func emote(kind: String, sec := EMOTE_SEC) -> void:
	_bubble.flash(kind, sec)


func _random_emote() -> void:
	_emote_timer = randf_range(IDLE_EMOTE_TIME.x, IDLE_EMOTE_TIME.y)
	if _bubble.is_busy():
		return
	var total := 0
	for e: String in IDLE_EMOTES:
		total += IDLE_EMOTES[e]
	var r := randi() % total
	for e: String in IDLE_EMOTES:
		r -= IDLE_EMOTES[e]
		if r < 0:
			emote(e)
			return


## After a purchase: walk to the PC, kneel, tinker. Several purchases just extend it.
func start_repair() -> void:
	if not sprite_frames.has_animation("repair"):
		return
	if _state == State.ACTION and _action == "repair":
		_repair_left = REPAIR_SEC
		repair_started.emit()
		return
	if _action == "roll":
		chair_taken.emit(false)
	_leave_station()
	_walk_to(repair_x, State.WALKING_TO_REPAIR)


## Is the point (game pixels) on a visible pixel of the figure?
func hit(p: Vector2) -> bool:
	var tex := sprite_frames.get_frame_texture(animation, frame)
	if tex == null:
		return false
	var local := ((p - position) / scale - offset).floor()
	if flip_h:
		local.x = tex.get_width() - 1 - local.x
	if local.x < 0 or local.y < 0 or local.x >= tex.get_width() or local.y >= tex.get_height():
		return false
	if not _image_cache.has(tex):
		_image_cache[tex] = tex.get_image()
	var img: Image = _image_cache[tex]
	return img != null and img.get_pixelv(Vector2i(local)).a > 0.1


func can_grab() -> bool:
	return not paused


## User is away (mouse idle for long): fall asleep at the desk. If he is out walking,
## he falls asleep as soon as he sits down again.
func fall_asleep() -> void:
	_sleepy = true
	if _state == State.SITTING:
		_sleep()


## User is back: wake up and stretch.
func wake_up() -> void:
	_sleepy = false
	if _state != State.SLEEPING:
		return
	_bubble.set_zzz(false)
	emote("question", 2.0)
	if sprite_frames.has_animation("stretch"):
		_play_action("stretch")
	else:
		_sit()


## Pending event: «!» bubble above the head.
func set_alert(on: bool) -> void:
	_bubble.set_alert(on)


## Fast mouse close to him: flinch, «!».
func startle() -> void:
	if _state == State.SLEEPING:
		wake_up()
	elif is_airborne() or _state == State.LANDING:
		return
	emote("excl", 1.2)
	if _state == State.SITTING and sprite_frames.has_animation("startle"):
		_play_action("startle")
	else:
		_flinch()


## Cursor rests on him: look at the user.
func notice() -> void:
	if _state == State.SITTING or _state == State.STANDING:
		emote("heart", 2.5)
	match _state:
		State.SITTING:
			if sprite_frames.has_animation("look"):
				_play_action("look")
		State.STANDING:
			if sprite_frames.has_animation("front") and animation != "front":
				flip_h = false
				play("front")
				var n := sprite_frames.get_frame_count("front")
				_timer = maxf(_timer, n / sprite_frames.get_animation_speed("front") + 0.5)


## While standing, turn towards the cursor (sideways only, sprites face right).
func face_toward(game_x: float) -> void:
	if _state == State.STANDING and animation != "front":
		var want := game_x < position.x + SIZE * 0.5
		if flip_h != want:
			flip_h = want


## Out on a walk (walking out or standing around): his x, otherwise -1. For the cat.
func out_x() -> float:
	return _x if _state == State.WALKING_OUT or _state == State.STANDING else -1.0


## Carried or falling: shown in the carry window instead of the strip.
func is_airborne() -> bool:
	return _state == State.GRABBED or _state == State.FALLING


## The desk was moved: new sitting and repair position. If he is sitting, he moves along.
func set_home(home: float, repair: float) -> void:
	var dx := home - home_x
	home_x = home
	repair_x = repair
	match _state:
		State.SITTING, State.ACTION:
			_x += dx
			position.x = roundf(_x)
			moved.emit()
		State.WALKING_HOME:
			_target_x = home
		State.WALKING_TO_REPAIR:
			_target_x = repair
		State.WALKING_TO_STATION, State.CHARGING:
			_leave_station()  # the cabinet moved with the desk: go back to work
			_walk_to(home, State.WALKING_HOME)


## Grabbed: wriggle and look at the user. Running actions are cancelled.
func grab() -> void:
	if _state == State.ACTION and _action == "roll":
		chair_taken.emit(false)
	_leave_station()
	_bubble.set_zzz(false)
	_state = State.GRABBED
	_action = ""
	offset = Vector2.ZERO
	flip_h = false
	_play_or("dangle", "walk")


## While carried: set the position directly (game pixels, may be above the strip).
func drag_to(p: Vector2) -> void:
	position = p.round()
	_x = position.x


## Release with throw speed vel (game pixels per second).
func drop(vel: Vector2) -> void:
	_vel = vel.clamp(Vector2(-MAX_THROW, -MAX_THROW), Vector2(MAX_THROW, MAX_THROW))
	_fall_pos = position
	if position.y >= floor_y and _vel.y >= 0.0:
		_land()
		return
	_state = State.FALLING
	_play_or("fall", "dangle")


## Flinch without its own sprite: jolt up and shake briefly (~0.5 s).
func _flinch() -> void:
	var tw := create_tween()
	tw.tween_property(self, "offset", Vector2(0, _px(-6)), 0.05)
	for dx in [2.0, -2.0, 2.0, -1.0]:
		tw.tween_property(self, "offset", Vector2(_px(dx), _px(-4)), 0.05)
	tw.tween_property(self, "offset", Vector2.ZERO, 0.15)


## Click on XYMYX: the faster the clicks follow each other, the higher the jump.
func bounce() -> void:
	if is_airborne():
		return
	var now := Time.get_ticks_msec()
	_combo = mini(_combo + 1, JUMP_HEIGHTS.size() - 1) if now - _last_click_ms < COMBO_SEC * 1000.0 else 0
	_last_click_ms = now
	var h: float = JUMP_HEIGHTS[_combo]
	if h <= TWEEN_MAX:
		var tw := create_tween()
		var hh := h / Art.SCALE  # timing as before
		tw.tween_property(self, "offset:y", -h / scale.y, 0.08 + hh * 0.01)
		tw.tween_property(self, "offset:y", 0.0, 0.12 + hh * 0.01)
		return
	# Real jump: up with v = sqrt(2·g·h), landing like after being dropped
	if _state == State.ACTION and _action == "roll":
		chair_taken.emit(false)
	_bubble.set_zzz(false)
	offset = Vector2.ZERO
	_vel = Vector2(0.0, -sqrt(2.0 * GRAVITY * h))
	_fall_pos = position
	_state = State.FALLING
	_action = ""
	flip_h = false
	_play_or("fall", "dangle")


## Current combo level 1..7 (for the «trampoline» flag).
func combo_level() -> int:
	return _combo + 1


## Small hop as click feedback.
func hop() -> void:
	var tw := create_tween()
	tw.tween_property(self, "offset:y", _px(-3.0), 0.08)
	tw.tween_property(self, "offset:y", 0.0, 0.12)


# --- States -------------------------------------------------------------------

func _sit(reset_walk_timer := true) -> void:
	_state = State.SITTING
	_action = ""
	if reset_walk_timer:
		_timer = randf_range(SIT_TIME.x, SIT_TIME.y)
	_idle_timer = randf_range(IDLE_ACTION_TIME.x, IDLE_ACTION_TIME.y)
	flip_h = false
	play("sit")
	if _sleepy:
		_sleep()


func _sleep() -> void:
	_state = State.SLEEPING
	_action = ""
	if sprite_frames.has_animation("sleep"):
		play("sleep")
	else:
		play("sit")  # without a sleep sprite: sit still, only show the Zzz
		pause()
	_bubble.set_zzz(true)


func _stand() -> void:
	_state = State.STANDING
	_timer = randf_range(STAND_TIME.x, STAND_TIME.y)
	if sprite_frames.has_animation("kneel") and pet_near.is_valid() and randf() < KNEEL_CHANCE:
		var target: Object = pet_near.call(position.x + SIZE * 0.5)
		if target != null:
			# Crouch down next to the pet: stroke it or wind up the robot toy (main lets it react)
			_kneel_target = target
			flip_h = target.position.x + target.size * 0.5 < position.x + SIZE * 0.5
			play("kneel")
			var k := sprite_frames.get_frame_count("kneel")
			_timer = maxf(_timer, k / sprite_frames.get_animation_speed("kneel") + 0.5)
			return
	if sprite_frames.has_animation("front") and randf() < FRONT_CHANCE:
		# Turn to the user, blink, wave. The pause lasts at least as long as the animation.
		flip_h = false
		play("front")
		var n := sprite_frames.get_frame_count("front")
		_timer = maxf(_timer, n / sprite_frames.get_animation_speed("front") + 0.5)
		return
	_stand_still()


func _stand_still() -> void:
	animation = "walk"
	stop()
	frame = 0


func _process_fall(delta: float) -> void:
	_vel.y += GRAVITY * delta
	_fall_pos += _vel * delta
	if _fall_pos.x < min_x or _fall_pos.x > max_x:  # bounce off the screen edge
		_fall_pos.x = clampf(_fall_pos.x, min_x, max_x)
		_vel.x = -_vel.x * 0.5
	if _fall_pos.y >= floor_y:
		_fall_pos.y = floor_y
		position = _fall_pos.round()
		_land()
		return
	position = _fall_pos.round()


func _land() -> void:
	if _vel.y >= HARD_LANDING:
		emote("angry")
	_last_click_ms = Time.get_ticks_msec()  # combo window starts at landing, not at the click
	_vel = Vector2.ZERO
	position.y = floor_y
	_x = position.x
	if sprite_frames.has_animation("land"):
		_state = State.LANDING
		_action = "land"
		flip_h = false
		play("land")
	else:
		_after_land()


func _after_land() -> void:
	landed.emit()
	moved.emit()
	_walk_to(home_x, State.WALKING_HOME)


## Plays anim, otherwise fallback, otherwise «walk» (while sprites are missing).
func _play_or(anim: String, fallback: String) -> void:
	for a in [anim, fallback]:
		if sprite_frames.has_animation(a):
			play(a)
			return
	play("walk")


func _walk_to(x: float, state: State) -> void:
	_state = state
	_action = ""
	_target_x = x
	flip_h = x < _x  # sprites face right, left = mirrored
	play("walk")


func _play_action(anim: String) -> void:
	_state = State.ACTION
	_action = anim
	flip_h = false
	if anim == "duck_talk" or anim == "phone":
		emote("dots")
	if anim == "roll":
		_roll_back = false
		chair_taken.emit(true)
	play(anim)


func _begin_repair() -> void:
	_play_action("repair")
	_repair_left = REPAIR_SEC
	repair_started.emit()


func _play_random_idle() -> void:
	var total := 0
	for a: String in IDLE_ACTIONS:
		if _idle_ok(a):
			total += IDLE_ACTIONS[a]
	_idle_timer = randf_range(IDLE_ACTION_TIME.x, IDLE_ACTION_TIME.y)
	if total == 0:
		return
	var r := randi() % total
	for a: String in IDLE_ACTIONS:
		if not _idle_ok(a):
			continue
		r -= IDLE_ACTIONS[a]
		if r < 0:
			_play_action(a)
			return


func _idle_ok(anim: String) -> bool:
	return sprite_frames.has_animation(anim) and (anim != "duck_talk" or has_duck)


# --- Charging cabinet --------------------------------------------------------------

## Arrived in front of the cabinet: the doors open, then he steps in.
func _begin_charge() -> void:
	_state = State.CHARGING
	_charge_step = "open"
	_timer = OPEN_SEC
	_stand_still()
	charge_phase.emit("opening")


func _process_charge(delta: float) -> void:
	if _charge_step == "in" or _charge_step == "out":
		return  # waiting for the animation
	_timer -= delta
	if _timer > 0.0:
		return
	match _charge_step:
		"open":
			# Inside the cabinet: same origin, 4 px higher, front view, eyes go off
			_charge_step = "in"
			flip_h = false
			position.y = floor_y - CHARGE_RISE
			moved.emit()
			play("charge_in")
			charge_phase.emit("charging")
		"charge":
			_charge_step = "full"
			_timer = FULL_SEC
			charge_phase.emit("full")
		"full":
			_charge_step = "out"
			play("charge_out")


## Leave the cabinet (done or interrupted): back on the floor, the doors close.
func _leave_station() -> void:
	if _charge_step == "" and _state != State.CHARGING:
		return
	_charge_step = ""
	position.y = floor_y
	moved.emit()
	charge_phase.emit("closing")


## Roll back a bit on the chair and return.
func _process_roll(delta: float) -> void:
	var target := home_x if _roll_back else home_x - ROLL_DIST
	if _step_towards(target, ROLL_SPEED * delta):
		if _roll_back:
			chair_taken.emit(false)
			_sit(false)
		else:
			_roll_back = true


func _on_animation_finished() -> void:
	# Only non-looping animations end by themselves.
	match _state:
		State.CHARGING:
			if _charge_step == "in":  # eyes off: charging
				_charge_step = "charge"
				_timer = randf_range(CHARGE_SEC.x, CHARGE_SEC.y)
				play("charge")
			elif _charge_step == "out":  # awake again: step out, the cabinet closes behind him
				_leave_station()
				_walk_to(home_x, State.WALKING_HOME)
		State.ACTION:
			if _action != "roll" and _action != "repair":
				_sit(false)
		State.LANDING:
			_after_land()
		State.STANDING:
			if animation == "kneel" and _kneel_target != null:
				petted.emit(_kneel_target)
				_kneel_target = null
			_stand_still()  # front view / kneeling done, stand sideways again


func _step_towards(target: float, step: float) -> bool:
	_x = move_toward(_x, target, step)
	var px := roundf(_x)
	if px != position.x:
		position.x = px
		moved.emit()
	return _x == target


func _pick_target() -> float:
	for i in 10:
		var t := randf_range(min_x, max_x)
		if absf(t - home_x) >= MIN_WALK:
			return t
	return min_x


## seq = frame sequence (empty = all frames in order)
func _add_anim(sf: SpriteFrames, anim: String, frames: Array[Texture2D], fps: float,
		seq: Array, loop := true) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	if seq.is_empty():
		for t in frames:
			sf.add_frame(anim, t)
	else:
		for i: int in seq:
			sf.add_frame(anim, frames[mini(i, frames.size() - 1)])
