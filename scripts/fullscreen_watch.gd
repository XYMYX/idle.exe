class_name FullscreenWatch
extends Node
## Hides XYMYX while a fullscreen program (game, video) covers his monitor.
## Uses the helper idle-sysinfo.exe in «--fullscreen» mode: it only checks whether the
## foreground window fills the monitor, never its title or content, and prints 1/0 on changes.
## Without the helper this simply does nothing.

signal changed(fullscreen: bool)

const RESTART_SEC := 30.0  # retry if the helper ended unexpectedly

var fullscreen := false

var _pid := -1
var _pipe: FileAccess
var _buffer := ""
var _check := 0.0


func _ready() -> void:
	Settings.changed.connect(func(key: String) -> void:
		if key == "hide_fullscreen":
			_apply_setting())
	_apply_setting()


func _exit_tree() -> void:
	_stop()


func _apply_setting() -> void:
	if Settings.get_value("hide_fullscreen"):
		_start()
	else:
		_stop()
		_set_fullscreen(false)


func _start() -> void:
	if _pid > 0:
		return
	var path := SystemStatus.helper_path()
	if not FileAccess.file_exists(path):
		set_process(false)
		return
	var p := OS.execute_with_pipe(path, PackedStringArray(["--fullscreen", str(OS.get_process_id())]), false)
	if p.is_empty():
		set_process(false)
		return
	_pid = int(p["pid"])
	_pipe = p["stdio"]
	_buffer = ""
	set_process(true)


func _stop() -> void:
	set_process(false)
	if _pid > 0:
		OS.kill(_pid)
	_pid = -1
	if _pipe:
		_pipe.close()
		_pipe = null


func _process(delta: float) -> void:
	var chunk := _pipe.get_buffer(64)
	if not chunk.is_empty():
		_buffer += chunk.get_string_from_utf8()
		var nl := _buffer.rfind("\n")
		if nl >= 0:
			var lines := _buffer.substr(0, nl).split("\n", false)
			_buffer = _buffer.substr(nl + 1)
			_set_fullscreen(lines[lines.size() - 1].strip_edges() == "1")
	# If the helper died (killed, crashed), show XYMYX again and try once more later.
	_check -= delta
	if _check <= 0.0:
		_check = RESTART_SEC
		if not OS.is_process_running(_pid):
			_stop()
			_set_fullscreen(false)
			_start()


func _set_fullscreen(value: bool) -> void:
	if value == fullscreen:
		return
	fullscreen = value
	changed.emit(value)
