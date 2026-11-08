extends Node
## Player settings (autoload «Settings»), stored in user://settings.cfg, section [settings].
## The language is stored in the same section but is only changed via the tray menu.

signal changed(key: String)

const PATH := "user://settings.cfg"

## key -> {options, default}. «scale» 0 = automatic (from Windows scaling), takes effect after a restart.
## «system_status» is opt-in: the only feature that reads data from the system (display only).
const OPTIONS := {
	"scale": {"options": [0, 1, 2, 3, 4], "default": 0},
	"mouse_reactions": {"options": [true, false], "default": true},
	"sleep_min": {"options": [5, 10, 20, 0], "default": 10},
	"events": {"options": [0, 1, 2, 3], "default": 2},
	"show_cat": {"options": [true, false], "default": true},
	"max_fps": {"options": [10, 20], "default": 20},
	"system_status": {"options": [false, true], "default": false},
	"hide_fullscreen": {"options": [true, false], "default": true},
}

## Minutes between events per «events» level: 0 = off, 1 = rarely, 2 = normal, 3 = often.
const EVENT_INTERVALS := [Vector2.ZERO, Vector2(20.0, 45.0), Vector2(10.0, 25.0), Vector2(5.0, 12.0)]

var _values := {}


func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # missing file: defaults
	for key: String in OPTIONS:
		var v: Variant = cfg.get_value("settings", key, OPTIONS[key]["default"])
		_values[key] = v if OPTIONS[key]["options"].has(v) else OPTIONS[key]["default"]
	Engine.max_fps = int(_values["max_fps"])


func get_value(key: String) -> Variant:
	return _values[key]


func set_value(key: String, value: Variant) -> void:
	if not OPTIONS.has(key) or not OPTIONS[key]["options"].has(value) or _values[key] == value:
		return
	_values[key] = value
	if key == "max_fps":
		Engine.max_fps = int(value)
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # keep layout and language
	cfg.set_value("settings", key, value)
	cfg.save(PATH)
	changed.emit(key)


## Seconds without mouse movement until XYMYX falls asleep (INF = never).
func away_sec() -> float:
	var m := int(_values["sleep_min"])
	return INF if m == 0 else m * 60.0


func event_interval() -> Vector2:
	return EVENT_INTERVALS[int(_values["events"])]
