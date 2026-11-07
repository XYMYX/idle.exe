class_name SpeechBubble
extends Node2D
## Kleine Pixel-Anzeige über dem Kopf von XYMYX: «Z Z Z» beim Schlafen,
## kurz «!» beim Erschrecken. Zeichnet nur neu, wenn sich etwas ändert.

const ZZZ_FPS := 1.5  # neues Z pro Sekunde (bis 3, dann von vorne)

var _text := ""
var _text_left := 0.0
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
	_update_process()
	queue_redraw()


## Text kurz anzeigen (z. B. «!»), danach verschwindet er.
func flash(text: String, sec: float) -> void:
	_text = text
	_text_left = sec
	_update_process()
	queue_redraw()


func _process(delta: float) -> void:
	if _text_left > 0.0:
		_text_left -= delta
		if _text_left <= 0.0:
			_text = ""
			queue_redraw()
	if _zzz:
		_zzz_t += delta
		var n := int(_zzz_t * ZZZ_FPS) % 4  # 0..3 Z sichtbar
		if n != _zzz_n:
			_zzz_n = n
			queue_redraw()
	_update_process()


func _update_process() -> void:
	set_process(_zzz or _text_left > 0.0)


func _draw() -> void:
	if _text != "":
		PixelFont.draw_text(self, _text, Vector2(-floorf(PixelFont.text_width(_text) / 2.0), 0))
	elif _zzz:
		for i in _zzz_n:  # steigen schräg nach rechts oben
			PixelFont.draw_text(self, "Z", Vector2(4 + i * 4, -i * 3))
