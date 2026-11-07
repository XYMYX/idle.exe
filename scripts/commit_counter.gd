class_name CommitCounter
extends Node2D
## Zeigt das Geld als Pixelzahl, zentriert über position.
## Nach dem Start steht darüber kurz der Offline-Gewinn («+1.23K»).
## Zeichnet nur neu, wenn sich der angezeigte Text ändert (spart CPU/GPU).

const OFFLINE_SHOW_SEC := 10.0

var _text := ""
var _offline_text := ""
var _offline_left := 0.0


func _ready() -> void:
	if Game.offline_gain >= 1.0:
		_offline_text = "+" + BigNum.format(Game.offline_gain)
		_offline_left = OFFLINE_SHOW_SEC


func _process(delta: float) -> void:
	if _offline_left > 0.0:
		_offline_left -= delta
		if _offline_left <= 0.0:
			_offline_text = ""
			queue_redraw()
	var t := BigNum.format(Game.money)
	if t != _text:
		_text = t
		queue_redraw()


func _draw() -> void:
	_draw_centered(_text, 0.0)
	if _offline_text != "":
		_draw_centered(_offline_text, -7.0)


func _draw_centered(text: String, y: float) -> void:
	var w := PixelFont.text_width(text)
	PixelFont.draw_text(self, text, Vector2(-floorf(w / 2.0), y))
