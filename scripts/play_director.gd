class_name PlayDirector
extends Node2D
## Play rounds at the toy box (pure decoration): the box opens, the duck reacts, the walking pets and
## the robot toy come over and play with their props, the aquarium fish follow a laser dot.
## Afterwards the props are put away and the box closes. Random every 20–45 min, or a click on the box.
##
## The props are separate sprites (art, native size = game pixels), placed at the contact anchors
## from the integration notes. The dog's fetch frames 1–3 contain the ball themselves.

signal shape_changed   # props appeared/disappeared: main updates the click area

const INTERVAL_MIN := Vector2(20.0, 45.0)
const OPEN_SEC := 1.0
const ROUND_SEC := 30.0
const SPOT_START := 104.0   # first play spot right of the toy box origin
const SPOT_GAP := 36.0
const PLAY_SEQ := [0, 1, 2, 3, 2, 1]  # p_play frame order of elephant, hamster, robot toy
const ELEPHANT_BALL := [Vector2(93, 84), Vector2(93, 84), Vector2(95, 84), Vector2(96, 84)]

var desk: Desk
var walkers: Array[Cat] = []
var toy: RoboToy
var paused := false

var _phase := "idle"   # idle, opening, playing
var _timer := 0.0
var _next := 0.0
var _players: Array = []
var _tex := {}


func _ready() -> void:
	_schedule()


func _schedule() -> void:
	_next = randf_range(INTERVAL_MIN.x, INTERVAL_MIN.y) * 60.0


func is_busy() -> bool:
	return _phase != "idle"


## Start a round (also from a click on the toy box). Needs the toy box and at least one pet.
func start_round() -> void:
	if _phase != "idle" or desk == null or desk.toybox_origin() == Vector2.INF:
		return
	_phase = "opening"
	_timer = OPEN_SEC
	desk.set_toybox("opening")
	desk.duck_react()


func _process(delta: float) -> void:
	if paused:
		return
	match _phase:
		"idle":
			_next -= delta
			if _next <= 0.0:
				_schedule()
				start_round()
		"opening":
			_timer -= delta
			if _timer <= 0.0:
				_begin_play()
		"playing":
			_timer -= delta
			queue_redraw()
			if _timer <= 0.0:
				_end_round()


func _begin_play() -> void:
	_phase = "playing"
	_timer = ROUND_SEC
	desk.set_toybox("open")
	desk.aquarium_play = true
	var box := desk.position + desk.toybox_origin()
	var x := box.x + SPOT_START
	_players.clear()
	for p: Object in walkers + [toy]:
		if p != null and p.can_play():
			p.start_play(x)
			_players.append(p)
			x += p.size + SPOT_GAP
	shape_changed.emit()


func _end_round() -> void:
	for p: Object in _players:
		if is_instance_valid(p):
			p.end_play()
	_players.clear()
	desk.aquarium_play = false
	desk.duck_react()
	desk.set_toybox("closing")
	_phase = "idle"
	queue_redraw()
	shape_changed.emit()


## Click areas of the props (game coordinates), so Windows draws them.
func outline_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _phase != "playing":
		return out
	for p: Object in _players:
		if is_instance_valid(p) and p.visible:
			out.append(Rect2(p.play_spot, p.floor_y, p.size + 150.0, p.size))
	return out


func _draw() -> void:
	if _phase != "playing":
		return
	var t := Time.get_ticks_msec() / 1000.0
	for p: Object in _players:
		if not is_instance_valid(p) or not p.in_play_round():
			continue
		var o := Vector2(p.position.x, p.floor_y)
		if p is RoboToy:
			_sprite("robo_toy_gear", o + Vector2(36, 24), 24, PLAY_SEQ[p.frame % PLAY_SEQ.size()])
			continue
		match p.kind:
			"cat":
				# laser pointer next to the box, dot on the floor ahead of the cat (it pounces 45 px)
				var box := desk.position + desk.toybox_origin()
				_sprite("pet_laser_emitter", Vector2(box.x + 98, p.floor_y + p.size - 24), 24, int(t * 4) % 2)
				var wob := roundf(sin(t * 3.0) * 4.0)
				_sprite("pet_laser", Vector2(p.play_spot + Cat.POUNCE_LEAP + 83 + wob, p.floor_y + 87), 12, int(t * 6) % 2)
			"dog":
				var held: bool = (p.animation == "p_fetch" and p.frame >= 1) or p.animation == "p_carry" \
					or (p.animation == "p_drop" and p.frame <= 2)
				if not held:
					_sprite("pet_ball", Vector2(p.play_spot + 74, p.floor_y + 72), 24, 0)
			"elephant":
				var f: int = PLAY_SEQ[p.frame % PLAY_SEQ.size()]
				_sprite("elephant_toy", o + ELEPHANT_BALL[f], 36, f)
			"hamster":
				_sprite("hamster_play_ring", o + Vector2(36, 12), 36, PLAY_SEQ[p.frame % PLAY_SEQ.size()])


## Draws frame f of a square-frame prop sheet (native size = game pixels).
func _sprite(name: String, pos: Vector2, size: int, f: int) -> void:
	if not _tex.has(name):
		var path := "res://art/%s.png" % name
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	var tex: Texture2D = _tex[name]
	if tex == null:
		return
	var frames := maxi(1, tex.get_width() / size)
	draw_texture_rect_region(tex, Rect2(pos.round(), Vector2(size, size)),
		Rect2(Vector2((f % frames) * size, 0), Vector2(size, size)))
