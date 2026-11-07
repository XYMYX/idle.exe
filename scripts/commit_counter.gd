class_name CommitCounter
extends Node2D
## Shows the money as a pixel number, centered on position.
## Right after start, the offline gain is shown above it for a moment («+1.23K»),
## the same for delivered contracts (show_gain).
## Only redraws when the displayed text changes (saves CPU/GPU).

const OFFLINE_SHOW_SEC := 10.0
const GAIN_SHOW_SEC := 4.0

var _text := ""
var _offline_text := ""
var _offline_left := 0.0


func _ready() -> void:
	if Game.offline_gain >= 1.0:
		_offline_text = "+" + BigNum.format(Game.offline_gain)
		_offline_left = OFFLINE_SHOW_SEC


## Show «+amount» above the counter for a few seconds.
func show_gain(amount: float) -> void:
	_offline_text = "+" + BigNum.format(amount)
	_offline_left = GAIN_SHOW_SEC
	queue_redraw()


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
