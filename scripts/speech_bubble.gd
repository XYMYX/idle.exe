class_name SpeechBubble
extends Node2D
## Sprechblase von XYMYX: weisses Kästchen mit schwarzem Rand und Zipfel zum Kopf,
## darin ein 7×7-Pixel-Emote. Dazu frei schwebende «Z Z Z» beim Schlafen.
##
## Vorrang: kurzes Emote (flash) > offenes Ereignis (alert, wippt) > Zzz.
## Zeichnet nur neu, wenn sich etwas ändert.

const ZZZ_FPS := 1.5    # neues Z pro Sekunde (bis 3, dann von vorne)
const ALERT_HZ := 2.0   # Wippen pro Sekunde beim offenen Ereignis

const BOX := Vector2(11, 11)   # Blase: 1 px Rand + 1 px Luft + 7 px Emote + 1 + 1
const TAIL := [Vector2(1, 11), Vector2(2, 11), Vector2(0, 12)]  # Zipfel unten links, zeigt zum Kopf
const C_LINE := Color.BLACK
const C_FILL := Color.WHITE

## Emotes 7×7: «#» = Pixel in der Farbe des Emotes.
const EMOTES := {
	"heart": {"c": Color.BLACK, "px": [
		".##.##.",
		"#######",
		"#######",
		"#######",
		".#####.",
		"..###..",
		"...#..."]},
	"angry": {"c": Color("#d62828"), "px": [  # Zornesader wie im Manga
		".#...#.",
		"##...##",
		".......",
		".......",
		".......",
		"##...##",
		".#...#."]},
	"note": {"c": Color.BLACK, "px": [
		"...###.",
		"...#.#.",
		"...#.#.",
		"...#.#.",
		".###.#.",
		"####...",
		".##...."]},
	"dots": {"c": Color.BLACK, "px": [
		".......",
		".......",
		".......",
		".......",
		".......",
		"#.#.#..",
		"......."]},
	"question": {"c": Color.BLACK, "px": [
		"..###..",
		".#...#.",
		".....#.",
		"...##..",
		"...#...",
		".......",
		"...#..."]},
	"excl": {"c": Color("#d62828"), "px": [
		"...#...",
		"..###..",
		"..###..",
		"..###..",
		"...#...",
		".......",
		"..###.."]},
}

var _flash := ""
var _flash_left := 0.0
var _alert := false
var _alert_up := true
var _zzz := false
var _zzz_t := 0.0
var _zzz_n := -1


func _ready() -> void:
	set_process(false)


## Schlaf-Anzeige ein/aus.
func set_zzz(on: bool) -> void:
	_zzz = on
	_zzz_t = 0.0
	_zzz_n = -1
	_changed()


## Offenes Ereignis: «!»-Blase, wippt, bleibt bis set_alert(false).
func set_alert(on: bool) -> void:
	_alert = on
	_alert_up = true
	_changed()


## Emote kurz zeigen: heart, angry, note, dots, question, excl.
func flash(emote: String, sec: float) -> void:
	if not EMOTES.has(emote):
		return
	_flash = emote
	_flash_left = sec
	_changed()


func is_busy() -> bool:
	return _flash != "" or _alert or _zzz


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash = ""
			queue_redraw()
	if _alert:
		var up := int(Time.get_ticks_msec() / 1000.0 * ALERT_HZ * 2.0) % 2 == 0
		if up != _alert_up:
			_alert_up = up
			queue_redraw()
	if _zzz:
		_zzz_t += delta
		var n := int(_zzz_t * ZZZ_FPS) % 4  # 0..3 Z sichtbar
		if n != _zzz_n:
			_zzz_n = n
			queue_redraw()
	set_process(_zzz or _alert or _flash_left > 0.0)


func _changed() -> void:
	set_process(_zzz or _alert or _flash_left > 0.0)
	queue_redraw()


func _draw() -> void:
	if _flash != "":
		_draw_bubble(_flash, Vector2.ZERO)
	elif _alert:
		_draw_bubble("excl", Vector2(0, 0 if _alert_up else 1))
	elif _zzz:
		for i in _zzz_n:  # steigen schräg nach rechts oben
			PixelFont.draw_text(self, "Z", Vector2(i * 4, 4 - i * 3))


func _draw_bubble(emote: String, at: Vector2) -> void:
	var box := Rect2(at, BOX)
	draw_rect(box, C_LINE)
	draw_rect(box.grow(-1), C_FILL)
	for p: Vector2 in TAIL:
		draw_rect(Rect2(at + p, Vector2.ONE), C_LINE)
	var e: Dictionary = EMOTES[emote]
	var rows: Array = e["px"]
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] == "#":
				draw_rect(Rect2(at + Vector2(2 + x, 2 + y), Vector2.ONE), e["c"])
