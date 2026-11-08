class_name Desk
extends Node2D
## Desk with the purchased setup. Base image depends on the tier (laptop or gaming PC),
## the individual parts are drawn on top. If a PNG is missing, a grey placeholder box
## is drawn in exactly the size the sprite needs to have.

## Since 2026-11-08 all positions and sizes are in 3× finer game pixels (Art.SCALE). Sheets can be
## old (1×) or redrawn (3×): the draw functions read the frame size from the sheet height.
const SIZE := Vector2(183, 144)  # base image (chair + table)
const CHAIR_SIZE := Vector2(48, 102)
const ICON := 24.0               # board icon size

const BASE_LAPTOP := "res://art/desk_laptop.png"
const BASE_PC := "res://art/desk_pc.png"

## Parts in drawing order. Coordinates relative to the desk's top-left corner
## (floor = y 48, window top = y -10, right screen edge = x 118).
## needs = upgrade you must own; hide_if = hidden once that upgrade is owned.
## behind = drawn behind the base image (tower under the table, the tabletop covers it).
## fps = animation: the PNG is a horizontal sheet, frames = width / size.x.
const PARTS := [
	# At the desk
	{"tex": "res://art/pc_tower.png", "pos": Vector2(120, 87), "size": Vector2(36, 54), "needs": "gaming_pc", "hide_if": "water", "behind": true},
	{"tex": "res://art/pc_tower_water.png", "pos": Vector2(120, 87), "size": Vector2(36, 54), "needs": "water", "hide_if": "workstation", "behind": true},
	{"tex": "res://art/pc_workstation.png", "pos": Vector2(120, 87), "size": Vector2(36, 54), "needs": "workstation", "behind": true, "fps": 2.0},
	{"tex": "res://art/monitor_wall.png", "pos": Vector2(30, -24), "size": Vector2(120, 54), "needs": "monitor_wall", "behind": true, "fps": 2.0},
	{"tex": "res://art/monitor_2.png", "pos": Vector2(48, 33), "size": Vector2(42, 51), "needs": "monitor_2"},
	{"tex": "res://art/monitor_3.png", "pos": Vector2(138, 33), "size": Vector2(42, 51), "needs": "monitor_3"},
	{"tex": "res://art/keyboard_mech.png", "pos": Vector2(54, 72), "size": Vector2(48, 12), "needs": "keyboard"},
	# Stage 10: certificates on the wall, one frame per learned skill (sheet with 5 frames)
	{"tex": "res://art/certificates.png", "pos": Vector2(156, -18), "size": Vector2(30, 36), "needs": "", "skill_frames": true},
	# Stage 13: wall map, one more lit dot per location (sheet with 5 frames)
	{"tex": "res://art/world_map.png", "pos": Vector2(312, 18), "size": Vector2(42, 30), "needs": "", "location_frames": true},
	# Right of the desk
	{"tex": "res://art/rack.png", "pos": Vector2(189, 0), "size": Vector2(72, 144), "needs": "rack"},
	{"tex": "res://art/rack_cooling.png", "pos": Vector2(189, 0), "size": Vector2(72, 144), "needs": "rack_cooling", "fps": 2.0},
	{"tex": "res://art/fan.png", "pos": Vector2(270, 72), "size": Vector2(36, 72), "needs": "fan", "fps": 8.0},
	{"tex": "res://art/ups.png", "pos": Vector2(312, 108), "size": Vector2(30, 36), "needs": "ups", "fps": 1.0},
	{"tex": "res://art/ac.png", "pos": Vector2(270, -24), "size": Vector2(72, 30), "needs": "ac", "fps": 3.0},
	# Left of the chair (XYMYX walks in front of these)
	{"tex": "res://art/homeserver.png", "pos": Vector2(-108, 78), "size": Vector2(42, 66), "needs": "homeserver", "fps": 2.0},
	{"tex": "res://art/router.png", "pos": Vector2(-105, 60), "size": Vector2(36, 18), "needs": "router", "fps": 4.0},
	{"tex": "res://art/fiber.png", "pos": Vector2(-138, 30), "size": Vector2(24, 30), "needs": "fiber", "fps": 1.0},
	{"tex": "res://art/line2.png", "pos": Vector2(-108, 12), "size": Vector2(24, 30), "needs": "line2", "fps": 1.0},
	{"tex": "res://art/nas.png", "pos": Vector2(-150, 108), "size": Vector2(30, 36), "needs": "nas", "fps": 2.0},
	{"tex": "res://art/ssd_raid.png", "pos": Vector2(-150, 93), "size": Vector2(30, 15), "needs": "ssd_raid"},
	{"tex": "res://art/grid.png", "pos": Vector2(-186, 24), "size": Vector2(36, 48), "needs": "grid"},
	{"tex": "res://art/asic.png", "pos": Vector2(-186, 120), "size": Vector2(30, 24), "needs": "asic", "fps": 6.0},
	{"tex": "res://art/asic_shelf.png", "pos": Vector2(-252, 54), "size": Vector2(60, 90), "needs": "asic_shelf", "fps": 4.0},
	{"tex": "res://art/mining_rack.png", "pos": Vector2(-330, 0), "size": Vector2(72, 144), "needs": "mining_rack", "fps": 4.0},
	# Stage 11: security business
	{"tex": "res://art/test_server.png", "pos": Vector2(-381, 72), "size": Vector2(48, 72), "needs": "test_server", "fps": 2.0},
	{"tex": "res://art/sec_lab.png", "pos": Vector2(-438, 24), "size": Vector2(60, 120), "needs": "sec_lab", "fps": 3.0},
]

## Location board on the wall: big installations that don't fit into the room
## appear as 8x8 icons (art/icon_<id>.png, optionally 2 frames = 16x8).
## The board is only as big as needed (up to 10 icons per row) and hangs right next to
## the leftmost part in the room. Border and fill color come from board.png.
const BOARD_TEX := "res://art/board.png"
const BOARD_TOP := -24.0
const BOARD_COLS := 10
const BOARD_MAX_ROWS := 4    # more icons make the board wider, not taller (the strip is only 58 px)
const BOARD_GAP := 9.0       # gap to the next part on the right
const BOARD_PAD := 6         # padding between border and icons
const BOARD_ICON_GAP := 6    # gap between icons
const BOARD_TRAY := 6.0      # height of the tray below the board
const BOARD_LINE := 3        # border width
const BOARD_MAX_RIGHT := -54.0  # never closer to the chair
const BOARD_FPS := 2.0
const BOARD_ITEMS := [
	"plugin", "desktop_app", "saas", "platform", "ecosystem", "storage_server",
	"storage_cloud", "leased", "dc_link", "solar", "battery", "own_grid",
	"cool_loop", "industrial_cooling", "mining_container", "mining_farm",
	"vuln_scanner", "monitoring", "sec_platform",
	# endgame (2026-11-08)
	"holo_display", "server_row", "power_plant", "mining_hall", "soc",
	"gpu_cluster", "training_servers", "own_llm", "cryo_cooler", "qubit_chip", "quantum_cloud",
	"sat_uplink", "own_satellite", "orbital_dc",
	# more tiers in the classic lines (2026-11-08)
	"server_workstation", "gpu_rack", "ai_accelerator", "immersion_cooling", "cooling_tower", "arctic_hall",
	"hydro_dam", "fusion_reactor", "tape_library", "exabyte_cluster", "dna_storage", "backbone", "subsea_cable",
	"dev_platform", "operating_system", "global_cloud", "mining_island", "self_healing", "ai_agents",
	"threat_intel", "cyber_defense", "second_campus", "global_hq", "bunker_dc",
]
const ANIM_TICK := 0.125  # at most 8 animation checks per second

## Pets drawn by the desk (PetData). The duck sits on the table, the aquarium stands on the floor
## directly left of the chair (between home server and chair). The hamster runs free (cat.gd).
const DUCK_RECT := Rect2(141, 48, 36, 36)
const DUCK_IDLE := "res://art/pet_duck_idle.png"      # 2 frames
const DUCK_SQUEAK := "res://art/pet_duck_squeak.png"  # 3 frames
const SQUEAK_SEC := 0.6
const AQUARIUM_RECT := Rect2(-63, 72, 60, 72)
const AQUARIUM_TEX := "res://art/pet_aquarium.png"  # 6 frames
const AQUARIUM_FPS := 4.0
const CORNER_GAP := 9.0  # gap of the seasonal decoration to the leftmost thing in the room

## Seasonal decoration (setting «Seasonal decorations»): stands in the corner left of the pets.
## Only the date is read. from/to = [month, day], inclusive; a range may wrap over New Year.
## art/season_<id>.png, 20x28 per frame.
const SEASONS := [
	{"id": "newyear", "from": [12, 31], "to": [1, 2], "fps": 4.0},
	{"id": "swiss", "from": [7, 31], "to": [8, 1], "fps": 3.0},
	{"id": "halloween", "from": [10, 24], "to": [11, 1], "fps": 3.0},
	{"id": "birthday", "from": [11, 8], "to": [11, 8], "fps": 2.0},
	{"id": "xmas", "from": [12, 1], "to": [12, 26], "fps": 2.0},
]
const SEASON_SIZE := Vector2(60, 84)
const SEASON_CHECK_SEC := 60.0

## Charging cabinet (art/charging_station.png, 8 frames 144×144): replaces the server rack once the
## sheet exists. Sheet origin 36 px left of the rack, the open doors use 30 px on each side.
## Frames: 0 closed, 0–5 opening, 5/6 charging, 7 fully charged; closing 5→0.
const STATION_TEX := "res://art/charging_station.png"
const STATION_OFFSET := Vector2(-36, 0)   # relative to the rack's position
const STATION_SIZE := Vector2(144, 144)
const STATION_FPS := 8.0                  # opening / closing
const STATION_CHARGE_FPS := 2.0           # 5 <-> 6 while charging

## Server repair (visual only): a device shows its <part>_fault.png (2 frames, only the status light
## differs) until XYMYX has repaired it. Only devices whose fault sheet has the part's frame size.
const FAULT_PARTS := ["homeserver", "nas", "asic_shelf", "mining_rack", "test_server", "sec_lab"]
const FAULT_FPS := 2.0
## Toolbox on the floor under the desk, right part (72×48 frames: 0 closed … 3 tool removed).
const TOOLBOX_TEX := "res://art/toolbox.png"
const TOOLBOX_RECT := Rect2(96, 96, 72, 48)
## Toy box for the pets' play rounds (96×72 frames: 0 closed, 1–4 opening, 5 ready), left corner.
const TOYBOX_TEX := "res://art/toy_box.png"
const TOYBOX_SIZE := Vector2(96, 72)
const TOYBOX_FPS := 6.0
## Duck reacts during play rounds, aquarium fish follow a laser dot next to the tank.
const DUCK_PLAY := "res://art/pet_duck_play.png"        # 3 frames
const AQUARIUM_PLAY := "res://art/pet_aquarium_play.png"  # 6 frames
const LASER_TEX := "res://art/pet_laser.png"            # 12×12, 2 frames
const AQUARIUM_LASER := [Vector2(58, 23), Vector2(62, 20), Vector2(66, 22), Vector2(63, 26), Vector2(59, 25), Vector2(55, 23)]

const CHAIR := "res://art/chair.png"
const CHAIR_POS := Vector2(0, 42)
const FLASH_SEC := 0.6
const LAPTOP_RECT := Rect2(90, 30, 48, 51)  # flash area while there is no tower
const TOWER_RECT := Rect2(120, 87, 36, 54)

## Off while XYMYX rolls on the chair (the chair is then part of his sprite).
var chair_visible := true:
	set(value):
		chair_visible = value
		queue_redraw()

var _cache := {}  # path -> Texture2D or null
var _flash_rect := Rect2()
var _flash_left := 0.0


var _anim_left := 0.0
var _anim_key := ""
var _squeak_left := 0.0
var _season := ""            # current seasonal decoration id, "" = none
var fault_id := ""           # part («needs» id) that currently shows its fault sheet
var toolbox_frame := 0       # set by XYMYX while he takes out / puts back the wrench
var aquarium_play := false   # play round: fish follow the laser dot
var _toybox := "closed"      # closed, opening, open, closing
var _toybox_t := 0.0
var _duck_play_left := 0.0
var _station := "closed"     # closed, opening, charging, full, closing
var _station_t := 0.0        # seconds since the phase started

signal shape_changed         # the drawn area changed (cabinet doors): main updates the click area
var _season_check := 0.0


func _ready() -> void:
	Game.changed.connect(queue_redraw)


## Short white flash on the purchased part (installation effect).
func flash(id: String) -> void:
	_flash_rect = TOWER_RECT if Game.has("gaming_pc") else LAPTOP_RECT
	for part: Dictionary in PARTS:
		if part["needs"] == id and _shown(part):
			_flash_rect = Rect2(part["pos"], part["size"])
	if BOARD_ITEMS.has(id) and Game.has(id):
		_flash_rect = Rect2(_board_slot(_board_owned().find(id)), Vector2(ICON, ICON))
	_flash_left = FLASH_SEC


## Only redraw when an animation frame changes or something is flashing.
func _process(delta: float) -> void:
	if _toybox != "closed":
		_toybox_t += delta
		if _toybox == "closing" and _toybox_frame() == 0:
			_toybox = "closed"
		queue_redraw()
	if _duck_play_left > 0.0:
		_duck_play_left -= delta
		queue_redraw()
	if fault_id != "" or aquarium_play:
		queue_redraw()
	if _station != "closed":
		_station_t += delta
		if _station == "closing" and _station_frame() == 0:
			_station = "closed"
			shape_changed.emit()
		queue_redraw()
	if _flash_left > 0.0:
		_flash_left -= delta
		queue_redraw()
		return
	if _squeak_left > 0.0:
		_squeak_left -= delta
		queue_redraw()
	_season_check -= delta
	if _season_check <= 0.0:
		_season_check = SEASON_CHECK_SEC
		var s := season_now() if Settings.get_value("seasons") else ""
		if s != _season:
			_season = s
			Game.changed.emit()  # click area and redraw
	_anim_left -= delta
	if _anim_left > 0.0:
		return
	_anim_left = ANIM_TICK
	var key := ""
	for part: Dictionary in PARTS:
		if part.has("fps") and _shown(part):
			key += str(_frame(part["tex"], part["size"], part["fps"]))
	if _board_count() > 0:
		key += "b" + str(int(Time.get_ticks_msec() / 1000.0 * BOARD_FPS) % 2)
	if _pet_shown("duck"):
		key += "d" + str(_frame(DUCK_IDLE, DUCK_RECT.size, 1.0))
	if _pet_shown("aquarium"):
		key += "a" + str(_frame(AQUARIUM_TEX, AQUARIUM_RECT.size, AQUARIUM_FPS))
	if _season != "":
		key += "s" + str(_frame(_season_tex(), SEASON_SIZE, _season_fps()))
	if key != _anim_key:
		_anim_key = key
		queue_redraw()


## Width incl. parts sticking out past the table (rack). Used for the click area.
func width() -> float:
	var w := SIZE.x
	for part: Dictionary in PARTS:
		if _shown(part):
			w = maxf(w, part["pos"].x + part["size"].x)
	return w


## Leftmost x coordinate (negative if parts stand left of the chair). Used for the click area.
func left_extent() -> float:
	var x := 0.0
	for part: Dictionary in PARTS:
		if _shown(part):
			x = minf(x, part["pos"].x)
	if _board_count() > 0:
		x = minf(x, _board_rect().position.x - BOARD_LINE)  # the tray sticks out by one border width
	for r: Rect2 in _corner_rects().values():
		x = minf(x, r.position.x)
	return x


# --- Server repair -----------------------------------------------------------------

func _fault_tex(id: String) -> String:
	return "res://art/%s_fault.png" % id


## Owned devices that can show a fault (fault sheet with the part's frame size).
func faultable() -> Array[String]:
	var out: Array[String] = []
	for part: Dictionary in PARTS:
		var id: String = part["needs"]
		if not FAULT_PARTS.has(id) or not _shown(part):
			continue
		var t := _tex(_fault_tex(id))
		if t != null and t.get_height() == int(part["size"].y) and t.get_width() % int(part["size"].x) == 0:
			out.append(id)
	return out


## Top-left corner and height of a device (desk coordinates).
func part_rect(id: String) -> Rect2:
	for part: Dictionary in PARTS:
		if part["needs"] == id:
			return Rect2(part["pos"], part["size"])
	return Rect2()


func set_fault(id: String) -> void:
	fault_id = id
	queue_redraw()


func set_toolbox_frame(f: int) -> void:
	if f != toolbox_frame:
		toolbox_frame = f
		queue_redraw()


func toolbox_shown() -> bool:
	return _tex(TOOLBOX_TEX) != null and not faultable().is_empty()


# --- Toy box (pet play rounds) -------------------------------------------------------

func toybox_shown() -> bool:
	if _tex(TOYBOX_TEX) == null:
		return false
	for pd: Dictionary in PetData.PETS:
		if _pet_shown(pd["id"]):
			return true
	return false


## Top-left corner of the toy box (desk coordinates), Vector2.INF if not shown.
func toybox_origin() -> Vector2:
	var c := _corner_rects()
	return c["toybox"].position if c.has("toybox") else Vector2.INF


func toybox_hit(p: Vector2) -> bool:
	var c := _corner_rects()
	return c.has("toybox") and c["toybox"].has_point(p)


func set_toybox(phase: String) -> void:
	if phase == _toybox or (phase == "closing" and _toybox == "closed"):
		return
	_toybox = phase
	_toybox_t = 0.0
	queue_redraw()


func _toybox_frame() -> int:
	match _toybox:
		"opening": return mini(5, int(_toybox_t * TOYBOX_FPS))
		"open": return 5
		"closing": return maxi(0, 5 - int(_toybox_t * TOYBOX_FPS))
	return 0


func duck_react(sec := 1.5) -> void:
	_duck_play_left = sec
	queue_redraw()


# --- Charging cabinet --------------------------------------------------------------

## The cabinet replaces the rack once the rack is owned and the sheet exists.
func station_available() -> bool:
	return Game.has("rack") and _tex(STATION_TEX) != null


## Top-left corner of the cabinet sheet (desk coordinates).
func station_origin() -> Vector2:
	for part: Dictionary in PARTS:
		if part["needs"] == "rack":
			return part["pos"] + STATION_OFFSET
	return Vector2.ZERO


## Phase from XYMYX: opening, charging, full, closing.
func set_station(phase: String) -> void:
	if phase == _station:
		return
	if phase == "closing" and _station == "closed":
		return
	_station = phase
	_station_t = 0.0
	queue_redraw()
	shape_changed.emit()


func _station_frame() -> int:
	match _station:
		"opening": return mini(5, int(_station_t * STATION_FPS))
		"charging": return 5 + int(_station_t * STATION_CHARGE_FPS) % 2
		"full": return 7
		"closing": return maxi(0, 5 - int(_station_t * STATION_FPS))
	return 0


# --- Pets on the desk and in the pet corner ---------------------------------------

func _pet_shown(id: String) -> bool:
	return Game.has_pet(id) and Settings.get_value("show_cat")


## Seasonal decoration, on the floor left of everything else in the room (left of the board).
func _corner_rects() -> Dictionary:
	var out := {}
	var right := 0.0
	for part: Dictionary in PARTS:
		if _shown(part):
			right = minf(right, part["pos"].x)
	if _board_count() > 0:
		right = minf(right, _board_rect().position.x - BOARD_LINE)
	if _pet_shown("aquarium"):
		right = minf(right, AQUARIUM_RECT.position.x)
	if toybox_shown():
		out["toybox"] = Rect2(Vector2(right - CORNER_GAP - TOYBOX_SIZE.x, SIZE.y - TOYBOX_SIZE.y), TOYBOX_SIZE)
		right = out["toybox"].position.x
	if _season != "":
		out["season"] = Rect2(Vector2(right - CORNER_GAP - SEASON_SIZE.x, SIZE.y - SEASON_SIZE.y), SEASON_SIZE)
	return out


## Seasonal decoration for today ("" = none). date = Time.get_date_dict_from_system() (for tests).
static func season_now(date: Dictionary = {}) -> String:
	var d := date if not date.is_empty() else Time.get_date_dict_from_system()
	var md := int(d["month"]) * 100 + int(d["day"])
	for s: Dictionary in SEASONS:
		var a: int = s["from"][0] * 100 + s["from"][1]
		var b: int = s["to"][0] * 100 + s["to"][1]
		if (a <= b and md >= a and md <= b) or (a > b and (md >= a or md <= b)):
			return s["id"]
	return ""


func _season_tex() -> String:
	return "res://art/season_%s.png" % _season


func _season_fps() -> float:
	for s: Dictionary in SEASONS:
		if s["id"] == _season:
			return s["fps"]
	return 2.0


## Click on the duck (desk coordinates)?
func duck_hit(p: Vector2) -> bool:
	return _pet_shown("duck") and DUCK_RECT.has_point(p)


func squeak() -> void:
	_squeak_left = SQUEAK_SEC
	queue_redraw()


func _draw_pets() -> void:
	if _pet_shown("duck") and _duck_play_left > 0.0 and _tex(DUCK_PLAY) != null:
		_draw_sprite(DUCK_PLAY, DUCK_RECT.position, DUCK_RECT.size, 6.0)
	elif _pet_shown("duck"):
		if _squeak_left > 0.0:
			_draw_sprite(DUCK_SQUEAK, DUCK_RECT.position, DUCK_RECT.size, 8.0)
		else:
			_draw_sprite(DUCK_IDLE, DUCK_RECT.position, DUCK_RECT.size, 1.0)
	if _pet_shown("aquarium") and aquarium_play and _tex(AQUARIUM_PLAY) != null:
		var f := _frame(AQUARIUM_PLAY, AQUARIUM_RECT.size, 4.0)
		_draw_frame(AQUARIUM_PLAY, AQUARIUM_RECT.position, AQUARIUM_RECT.size, f)
		if _tex(LASER_TEX) != null:
			_draw_sprite(LASER_TEX, AQUARIUM_RECT.position + AQUARIUM_LASER[f % AQUARIUM_LASER.size()] - Vector2(6, 6),
				Vector2(12, 12), 6.0)
	elif _pet_shown("aquarium"):
		_draw_sprite(AQUARIUM_TEX, AQUARIUM_RECT.position, AQUARIUM_RECT.size, AQUARIUM_FPS)
	var tb := _corner_rects()
	if tb.has("toybox"):
		_draw_frame(TOYBOX_TEX, tb["toybox"].position, TOYBOX_SIZE, _toybox_frame())
	var corner := _corner_rects()
	if corner.has("season"):
		_draw_sprite(_season_tex(), corner["season"].position, SEASON_SIZE, _season_fps())


func _draw() -> void:
	_draw_board()
	_draw_parts(true)
	var base := BASE_PC if Game.has("gaming_pc") else BASE_LAPTOP
	var t := _tex(base)
	if t == null and base == BASE_PC:
		t = _tex(BASE_LAPTOP)  # until desk_pc.png exists
	if t:
		draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false)  # old 61×48 or new 183×144
	else:
		_placeholder(Rect2(Vector2(36, 84), Vector2(144, 12)))
	if chair_visible:
		var c := _tex(CHAIR)
		if c:
			draw_texture_rect(c, Rect2(CHAIR_POS, CHAIR_SIZE), false)
	if toolbox_shown():
		_draw_frame(TOOLBOX_TEX, TOOLBOX_RECT.position, TOOLBOX_RECT.size, toolbox_frame)
	_draw_parts(false)
	_draw_pets()
	# Flash: 3× on/off within FLASH_SEC
	if _flash_left > 0.0 and int(_flash_left / FLASH_SEC * 6.0) % 2 == 1:
		draw_rect(_flash_rect, Color(1, 1, 1, 0.75))


func _draw_parts(behind: bool) -> void:
	for part: Dictionary in PARTS:
		if not _shown(part) or part.get("behind", false) != behind:
			continue
		if part["needs"] == "rack" and station_available():
			_draw_frame(STATION_TEX, station_origin(), STATION_SIZE, _station_frame())
			continue
		if part["needs"] == "rack_cooling" and station_available() and _station != "closed":
			continue  # the cooling overlay would cover the open cabinet
		if part["needs"] == fault_id and fault_id != "":
			_draw_sprite(_fault_tex(fault_id), part["pos"], part["size"], FAULT_FPS)
			continue
		if part.get("skill_frames", false):
			_draw_frame(part["tex"], part["pos"], part["size"], SkillData.learned_count(Game.skills) - 1)
		elif part.get("location_frames", false):
			_draw_frame(part["tex"], part["pos"], part["size"], Economy.location_count(Game.levels) - 1)
		else:
			_draw_sprite(part["tex"], part["pos"], part["size"], part.get("fps", 0.0))


## Draws a fixed frame of a sheet (clamped to the frames that exist) or the placeholder.
func _draw_frame(path: String, pos: Vector2, size: Vector2, f: int) -> void:
	var t := _tex(path)
	if t == null:
		_placeholder(Rect2(pos, size))
		return
	var src := _src_size(t, size)
	var frames := maxi(1, int(t.get_width() / src.x))
	f = clampi(f, 0, frames - 1)
	draw_texture_rect_region(t, Rect2(pos, size), Rect2(Vector2(f * src.x, 0), src))


## Draws a (possibly animated) sprite or the placeholder in its target size.
func _draw_sprite(path: String, pos: Vector2, size: Vector2, fps: float) -> void:
	var t := _tex(path)
	if t == null:
		_placeholder(Rect2(pos, size))
		return
	var f := _frame(path, size, fps)
	var src := _src_size(t, size)
	draw_texture_rect_region(t, Rect2(pos, size), Rect2(Vector2(f * src.x, 0), src))


## Frame size inside the sheet: the sheet height decides (old sheets are a third of the target).
func _src_size(t: Texture2D, size: Vector2) -> Vector2:
	var k := t.get_height() / size.y
	return Vector2(roundf(size.x * k), t.get_height())


func _frame(path: String, size: Vector2, fps: float) -> int:
	var t := _tex(path)
	if t == null or fps <= 0.0:
		return 0
	var frames := maxi(1, int(t.get_width() / _src_size(t, size).x))
	return int(Time.get_ticks_msec() / 1000.0 * fps) % frames


func _draw_board() -> void:
	var owned := _board_owned()
	if owned.is_empty():
		return
	var r := _board_rect()
	var cols := _board_colors()
	draw_rect(r, cols[0])
	draw_rect(r.grow(-BOARD_LINE), cols[1])
	# Tray below the board (like a chalkboard), one border width wider on each side
	draw_rect(Rect2(r.position.x - BOARD_LINE, r.end.y, r.size.x + 2 * BOARD_LINE, BOARD_TRAY), cols[0])
	for i in owned.size():
		_draw_sprite("res://art/icon_%s.png" % owned[i], _board_slot(i), Vector2(ICON, ICON), BOARD_FPS)


## Everything the desk draws, as rectangles relative to the desk's top-left corner.
## main.gd builds the clickable outline («skyline») from these.
func outline_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(Vector2.ZERO, SIZE)]  # base image incl. chair
	out.append(Rect2(24, -18, 180, 42))  # money counter above the laptop (+ gain line), room for wide numbers
	for part: Dictionary in PARTS:
		if _shown(part):
			out.append(Rect2(part["pos"], part["size"]))
	if _board_count() > 0:
		var r := _board_rect()
		out.append(Rect2(r.position.x - BOARD_LINE, r.position.y, r.size.x + 2 * BOARD_LINE, r.size.y + BOARD_TRAY))
	if station_available() and _station != "closed":
		out.append(Rect2(station_origin(), STATION_SIZE))  # open doors
	if toolbox_shown():
		out.append(TOOLBOX_RECT)
	if aquarium_play and _pet_shown("aquarium"):
		out.append(Rect2(AQUARIUM_RECT.position + Vector2(46, 11), Vector2(30, 24)))  # laser dot next to the tank
	if _pet_shown("duck"):
		out.append(DUCK_RECT)
	if _pet_shown("aquarium"):
		out.append(AQUARIUM_RECT)
	for r: Rect2 in _corner_rects().values():
		out.append(r)
	return out


func _board_owned() -> Array[String]:
	var out: Array[String] = []
	for id: String in BOARD_ITEMS:
		if Game.has(id):
			out.append(id)
	# Stage 14: logos of acquired companies (art/icon_acq_<id>.png)
	for c: Dictionary in AcquisitionData.COMPANIES:
		if Game.acquisitions.get(c["id"], false):
			out.append("acq_" + c["id"])
	return out


func _board_count() -> int:
	return _board_owned().size()


## Board rectangle: grows with the icons, right-aligned before the leftmost part.
func _board_rect() -> Rect2:
	var n := _board_count()
	var per_row := _board_per_row()
	var cols := mini(n, per_row)
	var rows := ceili(n / float(per_row))
	# border + padding on both sides, icons with gaps between them
	var size := Vector2(2 * BOARD_LINE + 2 * BOARD_PAD + cols * ICON + (cols - 1) * BOARD_ICON_GAP,
		2 * BOARD_LINE + 2 * BOARD_PAD + rows * ICON + (rows - 1) * BOARD_ICON_GAP)
	var right := BOARD_MAX_RIGHT
	for part: Dictionary in PARTS:
		if _shown(part) and part["pos"].x < 0.0:
			right = minf(right, part["pos"].x)
	right -= BOARD_GAP
	return Rect2(Vector2(right - size.x, BOARD_TOP), size)


## Slot i (owned icons only, no gaps).
func _board_slot(i: int) -> Vector2:
	var pitch := ICON + BOARD_ICON_GAP
	var per_row := _board_per_row()
	return _board_rect().position + Vector2(BOARD_LINE + BOARD_PAD + (i % per_row) * pitch,
		BOARD_LINE + BOARD_PAD + (i / per_row) * pitch)


## Icons per row: at least BOARD_COLS, more once BOARD_MAX_ROWS rows would not be enough.
func _board_per_row() -> int:
	return maxi(BOARD_COLS, ceili(_board_count() / float(BOARD_MAX_ROWS)))


## [border, fill] from board.png (left edge middle, center). Without the PNG: grey tones.
var _board_cols: Array[Color] = []

func _board_colors() -> Array[Color]:
	if _board_cols.is_empty():
		_board_cols = [Color("#d6d9ee"), Color("#1c2333")]
		var t := _tex(BOARD_TEX)
		if t:
			var img := t.get_image()
			if img:
				var h := img.get_height()
				_board_cols = [img.get_pixel(0, h / 2), img.get_pixel(img.get_width() / 2, h / 2)]
	return _board_cols


func _shown(part: Dictionary) -> bool:
	if part.get("skill_frames", false):
		return SkillData.learned_count(Game.skills) > 0
	if part.get("location_frames", false):
		return Economy.location_count(Game.levels) > 0
	return Game.has(part["needs"]) and not (part.has("hide_if") and Game.has(part["hide_if"]))


func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Grey box with a light border: shows position and size of the missing sprite.
func _placeholder(r: Rect2) -> void:
	draw_rect(r, Color("#d6d9ee"))
	draw_rect(r.grow(-Art.SCALE), Color("#3a3a48"))
