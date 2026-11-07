class_name MouseWatch
extends Node
## Watches ONLY the mouse position (DisplayServer.mouse_get_position, no hook,
## no keys) and derives simple events for XYMYX from it.
## Samples 10× per second, which costs practically nothing.

signal away      # mouse has not moved for AWAY_SEC
signal back      # mouse moves again
signal startled  # fast movement close to XYMYX
signal hovered   # cursor rests on XYMYX for HOVER_SEC
signal sampled(game_pos: Vector2)  # cursor position in game pixels (for looking after it)

const SAMPLE_SEC := 0.1
const AWAY_SEC := 600.0          # 10 minutes
const HOVER_SEC := 1.5
const STARTLE_SPEED := 2500.0    # screen pixels per second
const STARTLE_RADIUS := 60.0     # game pixels around the figure's center
const STARTLE_COOLDOWN := 6.0

## Set by main: screen pixels -> game pixels, figure center, hit test.
var to_game: Callable
var figure_center: Callable
var figure_hit: Callable

var is_away := false

var _last := Vector2i.ZERO
var _acc := 0.0
var _still := 0.0
var _hover := 0.0
var _hover_done := false
var _cooldown := 0.0


func _ready() -> void:
	_last = DisplayServer.mouse_get_position()


func _process(delta: float) -> void:
	_acc += delta
	_cooldown -= delta
	if _acc < SAMPLE_SEC:
		return
	var dt := _acc
	_acc = 0.0

	var p := DisplayServer.mouse_get_position()
	var dist_px := Vector2(p - _last).length()
	_last = p

	if dist_px > 0.0:
		_still = 0.0
		if is_away:
			is_away = false
			back.emit()
	else:
		_still += dt
		if not is_away and _still >= AWAY_SEC:
			is_away = true
			away.emit()

	var g: Vector2 = to_game.call(p)
	sampled.emit(g)
	var near := g.distance_to(figure_center.call()) < STARTLE_RADIUS
	if near and dist_px / dt > STARTLE_SPEED and _cooldown <= 0.0:
		_cooldown = STARTLE_COOLDOWN
		startled.emit()

	if figure_hit.call(g) and dist_px < 4.0:
		_hover += dt
		if _hover >= HOVER_SEC and not _hover_done:
			_hover_done = true
			hovered.emit()
	elif not figure_hit.call(g):
		_hover = 0.0
		_hover_done = false
