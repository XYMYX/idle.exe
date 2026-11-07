class_name Xymyx
extends AnimatedSprite2D
## XYMYX: sitzt am Desk und tippt, macht kleine Pausen-Animationen,
## läuft ab und zu herum, reagiert auf Ereignisse und schraubt nach Käufen.
## Kann mit der Maus gepackt, herumgetragen und fallen gelassen werden.

signal moved
signal chair_taken(taken: bool)  # true = Stuhl steckt im Roll-Sprite, Desk blendet seinen aus
signal repair_started            # Desk lässt das gekaufte Teil aufblinken
signal landed                    # nach dem Fallenlassen wieder auf dem Boden

enum State { SITTING, WALKING_OUT, STANDING, WALKING_HOME, WALKING_TO_REPAIR, ACTION,
	GRABBED, FALLING, LANDING, SLEEPING }

const WALK_SPEED := 18.0                     # Spielpixel pro Sekunde
const SIT_TIME := Vector2(25.0, 70.0)        # Sekunden am Desk bis zum Spaziergang
const STAND_TIME := Vector2(2.0, 5.0)        # Pause unterwegs
const IDLE_ACTION_TIME := Vector2(12.0, 30.0) # Abstand der Pausen-Animationen beim Tippen
const MIN_WALK := 40.0
const REPAIR_SEC := 2.5
const ROLL_DIST := 12.0
const ROLL_SPEED := 16.0
const GRAVITY := 600.0       # Spielpixel pro Sekunde²
const MAX_THROW := 250.0     # höchstes Wurf-Tempo (Spielpixel pro Sekunde)
const FRONT_CHANCE := 0.5    # Anteil der Steh-Pausen mit Blick zum User

## Sonder-Animationen aus art/xymyx_<name>.png: Tempo und Frame-Folge (Indizes im Sheet).
## Fehlt eine Datei, wird die Animation einfach übersprungen.
const ACTIONS := {
	"cheer": {"fps": 8.0, "seq": [0, 1, 2, 3, 2, 3, 2, 3, 2, 1, 0]},
	"stretch": {"fps": 4.0, "seq": [0, 1, 2, 3, 3, 3, 2, 1, 0]},
	"headdesk": {"fps": 6.0, "seq": [0, 1, 2, 3, 2, 2, 2, 2, 2, 2, 4, 0]},
	"drink": {"fps": 4.0, "seq": [0, 1, 2, 3, 3, 3, 2, 1, 0]},
	"roll": {"fps": 6.0, "seq": [0, 1, 2, 3], "loop": true},
	"repair": {"fps": 8.0, "seq": [0, 1, 2, 3], "loop": true},
	# Frontansicht: sitzend kurz zum User schauen / stehend umdrehen, blinzeln, winken
	"look": {"fps": 4.0, "seq": [0, 1, 1, 2, 1, 1, 1, 0]},
	"front": {"fps": 4.0, "seq": [0, 1, 1, 2, 1, 3, 3, 1, 0]},
	# Gepackt (zappelt, schaut zum User), Fallen, Landen
	"dangle": {"fps": 6.0, "seq": [0, 1, 2, 3], "loop": true},
	"fall": {"fps": 8.0, "seq": [0, 1], "loop": true},
	"land": {"fps": 8.0, "seq": [0, 1, 2, 3]},
	# Maus-Reaktionen (optional): am Desk einschlafen, zusammenzucken
	"sleep": {"fps": 2.0, "seq": [0, 1, 2, 3], "loop": true},
	"startle": {"fps": 8.0, "seq": [0, 1, 2, 2, 1, 0]},
}
const BUBBLE_POS := Vector2(26, -2)  # Zzz / ! über dem Kopf (relativ zur Sprite-Ecke)
## Zufällige Pausen beim Tippen mit Gewicht (headdesk später durch Bug-Ereignisse)
const IDLE_ACTIONS := {"stretch": 3, "drink": 3, "roll": 1, "headdesk": 1, "look": 3}

var home_x := 0.0
var repair_x := 0.0
var min_x := 0.0
var max_x := 0.0
var floor_y := 0.0  # y-Position auf dem Boden (oberer Sprite-Rand)
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
var _image_cache := {}  # Textur -> Image, für die pixelgenaue Treffer-Prüfung
var _sleepy := false    # User weg: beim nächsten Hinsetzen einschlafen
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
	sprite_frames = sf
	animation_finished.connect(_on_animation_finished)
	_bubble = SpeechBubble.new()
	_bubble.position = BUBBLE_POS
	add_child(_bubble)


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
			if _timer <= 0.0:
				_walk_to(_pick_target(), State.WALKING_OUT)
			elif _idle_timer <= 0.0:
				_play_random_idle()
		State.STANDING:
			_timer -= delta
			if _timer <= 0.0:
				_walk_to(home_x, State.WALKING_HOME)
		State.WALKING_OUT, State.WALKING_HOME, State.WALKING_TO_REPAIR:
			if _step_towards(_target_x, WALK_SPEED * delta):
				match _state:
					State.WALKING_OUT: _stand()
					State.WALKING_HOME: _sit()
					State.WALKING_TO_REPAIR: _begin_repair()
		State.ACTION:
			if _action == "roll":
				_process_roll(delta)
			elif _action == "repair":
				_repair_left -= delta
				if _repair_left <= 0.0:
					_walk_to(home_x, State.WALKING_HOME)


# --- Öffentlich ---------------------------------------------------------------

## Sitz-Reaktion (cheer, headdesk, ...). Nur wenn er gerade am Desk sitzt.
func react(anim: String) -> void:
	if _state == State.SITTING and sprite_frames.has_animation(anim):
		_play_action(anim)


## Nach einem Kauf: zum PC laufen, knien, schrauben. Mehrere Käufe verlängern nur.
func start_repair() -> void:
	if not sprite_frames.has_animation("repair"):
		return
	if _state == State.ACTION and _action == "repair":
		_repair_left = REPAIR_SEC
		repair_started.emit()
		return
	if _action == "roll":
		chair_taken.emit(false)
	_walk_to(repair_x, State.WALKING_TO_REPAIR)


## Liegt der Punkt (Spielpixel) auf einem sichtbaren Pixel der Figur?
func hit(p: Vector2) -> bool:
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


func can_grab() -> bool:
	return not paused


## User ist weg (Maus lange unbewegt): am Desk einschlafen. Ist er unterwegs,
## schläft er ein, sobald er wieder sitzt.
func fall_asleep() -> void:
	_sleepy = true
	if _state == State.SITTING:
		_sleep()


## User ist zurück: aufwachen und strecken.
func wake_up() -> void:
	_sleepy = false
	if _state != State.SLEEPING:
		return
	_bubble.set_zzz(false)
	if sprite_frames.has_animation("stretch"):
		_play_action("stretch")
	else:
		_sit()


## Schnelle Maus nahe bei ihm: zusammenzucken, «!».
func startle() -> void:
	if _state == State.SLEEPING:
		wake_up()
	elif is_airborne() or _state == State.LANDING:
		return
	_bubble.flash("!", 1.2)
	if _state == State.SITTING and sprite_frames.has_animation("startle"):
		_play_action("startle")
	else:
		_flinch()


## Zeiger ruht auf ihm: zum User schauen.
func notice() -> void:
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


## Beim Stehen zum Mauszeiger drehen (nur seitlich, Sprites schauen nach rechts).
func face_toward(game_x: float) -> void:
	if _state == State.STANDING and animation != "front":
		var want := game_x < position.x + 24.0
		if flip_h != want:
			flip_h = want


## Getragen oder im Fall: wird dann im Tragefenster gezeigt, nicht in der Leiste.
func is_airborne() -> bool:
	return _state == State.GRABBED or _state == State.FALLING


## Desk wurde verschoben: neue Sitz- und Schraub-Position. Sitzt er, wandert er mit.
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


## Gepackt: zappeln und zum User schauen. Laufende Aktionen werden abgebrochen.
func grab() -> void:
	if _state == State.ACTION and _action == "roll":
		chair_taken.emit(false)
	_bubble.set_zzz(false)
	_state = State.GRABBED
	_action = ""
	offset = Vector2.ZERO
	flip_h = false
	_play_or("dangle", "walk")


## Während des Tragens: Position direkt setzen (Spielpixel, kann über dem Streifen liegen).
func drag_to(p: Vector2) -> void:
	position = p.round()
	_x = position.x


## Loslassen mit Wurf-Tempo vel (Spielpixel pro Sekunde).
func drop(vel: Vector2) -> void:
	_vel = vel.clamp(Vector2(-MAX_THROW, -MAX_THROW), Vector2(MAX_THROW, MAX_THROW))
	_fall_pos = position
	if position.y >= floor_y and _vel.y >= 0.0:
		_land()
		return
	_state = State.FALLING
	_play_or("fall", "dangle")


## Zusammenzucken ohne eigenes Sprite: hochschrecken und kurz zittern (~0.5 s).
func _flinch() -> void:
	var tw := create_tween()
	tw.tween_property(self, "offset", Vector2(0, -6), 0.05)
	for dx in [2.0, -2.0, 2.0, -1.0]:
		tw.tween_property(self, "offset", Vector2(dx, -4), 0.05)
	tw.tween_property(self, "offset", Vector2.ZERO, 0.15)


## Kleiner Hüpfer als Klick-Feedback.
func hop() -> void:
	var tw := create_tween()
	tw.tween_property(self, "offset:y", -3.0, 0.08)
	tw.tween_property(self, "offset:y", 0.0, 0.12)


# --- Zustände -----------------------------------------------------------------

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
		play("sit")  # ohne Schlaf-Sprite: stillsitzen, nur die Zzz zeigen
		pause()
	_bubble.set_zzz(true)


func _stand() -> void:
	_state = State.STANDING
	_timer = randf_range(STAND_TIME.x, STAND_TIME.y)
	if sprite_frames.has_animation("front") and randf() < FRONT_CHANCE:
		# Zum User drehen, blinzeln, winken. Dauer der Pause mindestens so lang wie die Animation.
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
	if _fall_pos.x < min_x or _fall_pos.x > max_x:  # am Bildschirmrand abprallen
		_fall_pos.x = clampf(_fall_pos.x, min_x, max_x)
		_vel.x = -_vel.x * 0.5
	if _fall_pos.y >= floor_y:
		_fall_pos.y = floor_y
		position = _fall_pos.round()
		_land()
		return
	position = _fall_pos.round()


func _land() -> void:
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


## Spielt anim, sonst fallback, sonst «walk» (solange die Sprites fehlen).
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
	flip_h = x < _x  # Sprites schauen nach rechts, links = gespiegelt
	play("walk")


func _play_action(anim: String) -> void:
	_state = State.ACTION
	_action = anim
	flip_h = false
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
		if sprite_frames.has_animation(a):
			total += IDLE_ACTIONS[a]
	_idle_timer = randf_range(IDLE_ACTION_TIME.x, IDLE_ACTION_TIME.y)
	if total == 0:
		return
	var r := randi() % total
	for a: String in IDLE_ACTIONS:
		if not sprite_frames.has_animation(a):
			continue
		r -= IDLE_ACTIONS[a]
		if r < 0:
			_play_action(a)
			return


## Mit dem Stuhl ein Stück nach hinten rollen und zurück.
func _process_roll(delta: float) -> void:
	var target := home_x if _roll_back else home_x - ROLL_DIST
	if _step_towards(target, ROLL_SPEED * delta):
		if _roll_back:
			chair_taken.emit(false)
			_sit(false)
		else:
			_roll_back = true


func _on_animation_finished() -> void:
	# Nur die nicht-loopenden Animationen enden von selbst.
	match _state:
		State.ACTION:
			if _action != "roll" and _action != "repair":
				_sit(false)
		State.LANDING:
			_after_land()
		State.STANDING:
			_stand_still()  # Frontansicht fertig, wieder seitlich hinstellen


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


## seq = Frame-Folge (leer = alle Frames der Reihe nach)
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
