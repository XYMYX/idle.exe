class_name MouseWatch
extends Node
## Beobachtet NUR die Mausposition (DisplayServer.mouse_get_position, kein Hook,
## keine Tasten) und meldet daraus einfache Ereignisse für XYMYX.
## Prüft 10× pro Sekunde, das kostet praktisch nichts.

signal away      # Maus seit AWAY_SEC unbewegt
signal back      # Maus bewegt sich wieder
signal startled  # schnelle Bewegung nahe bei XYMYX
signal hovered   # Zeiger ruht HOVER_SEC lang auf XYMYX
signal sampled(game_pos: Vector2)  # Zeigerposition in Spielpixeln (für Nachschauen)

const SAMPLE_SEC := 0.1
const AWAY_SEC := 600.0          # 10 Minuten
const HOVER_SEC := 1.5
const STARTLE_SPEED := 2500.0    # Bildschirm-Pixel pro Sekunde
const STARTLE_RADIUS := 60.0     # Spielpixel um die Mitte der Figur
const STARTLE_COOLDOWN := 6.0

## Von main gesetzt: Bildschirm-Pixel -> Spielpixel, Mittelpunkt der Figur, Treffer-Test.
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
