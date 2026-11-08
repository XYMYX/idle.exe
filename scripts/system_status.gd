class_name SystemStatus
extends Node
## Reads live system values from the helper idle-sysinfo.exe (tools/sysinfo/) while
## the «System status» view is open. Opt-in in the settings, display only: the values
## never influence the game, are never saved and never leave the PC.
##
## The helper writes one JSON line per second. It is started with our process id and
## exits by itself when the game is gone; stop() ends it right away.

const HELPER := "idle-sysinfo.exe"

var values := {}          # latest line from the helper, {} = nothing yet
var error := ""           # English source string, translated when shown

var _pid := -1
var _pipe: FileAccess
var _buffer := ""


## Static info that Godot knows without the helper.
static func static_info() -> Dictionary:
	return {
		"cpu_name": OS.get_processor_name(),
		"cores": OS.get_processor_count(),
		"gpu_name": RenderingServer.get_video_adapter_name(),
	}


func _ready() -> void:
	set_process(false)


func is_running() -> bool:
	return _pid > 0


func start() -> void:
	if is_running():
		return
	values = {}
	error = ""
	var path := helper_path()
	if not FileAccess.file_exists(path):
		error = "Helper not found (idle-sysinfo.exe next to idle.exe)"
		return
	var p := OS.execute_with_pipe(path, PackedStringArray([str(OS.get_process_id())]), false)
	if p.is_empty():
		error = "Helper could not be started"
		return
	_pid = int(p["pid"])
	_pipe = p["stdio"]
	_buffer = ""
	set_process(true)


func stop() -> void:
	set_process(false)
	if _pid > 0:
		OS.kill(_pid)
	_pid = -1
	if _pipe:
		_pipe.close()
		_pipe = null


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	# Non-blocking pipe: returns what is there right now (possibly nothing).
	var chunk := _pipe.get_buffer(4096)
	if chunk.is_empty():
		return
	_buffer += chunk.get_string_from_utf8()
	var nl := _buffer.rfind("\n")
	if nl < 0:
		return
	var lines := _buffer.substr(0, nl).split("\n", false)
	_buffer = _buffer.substr(nl + 1)
	var parsed: Variant = JSON.parse_string(lines[lines.size() - 1])
	if parsed is Dictionary:
		values = parsed


## In the export next to idle.exe, in the editor in tools/sysinfo/.
static func helper_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://tools/sysinfo/" + HELPER)
	return OS.get_executable_path().get_base_dir().path_join(HELPER)
