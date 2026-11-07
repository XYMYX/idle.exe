class_name Desk
extends Node2D
## Desk with the purchased setup. Base image depends on the tier (laptop or gaming PC),
## the individual parts are drawn on top. If a PNG is missing, a grey placeholder box
## is drawn in exactly the size the sprite needs to have.

const SIZE := Vector2(61, 48)  # base image (chair + table)

const BASE_LAPTOP := "res://art/desk_laptop.png"
const BASE_PC := "res://art/desk_pc.png"

## Parts in drawing order. Coordinates relative to the desk's top-left corner
## (floor = y 48, window top = y -10, right screen edge = x 118).
## needs = upgrade you must own; hide_if = hidden once that upgrade is owned.
## behind = drawn behind the base image (tower under the table, the tabletop covers it).
## fps = animation: the PNG is a horizontal sheet, frames = width / size.x.
const PARTS := [
	# At the desk
	{"tex": "res://art/pc_tower.png", "pos": Vector2(40, 29), "size": Vector2(12, 18), "needs": "gaming_pc", "hide_if": "water", "behind": true},
	{"tex": "res://art/pc_tower_water.png", "pos": Vector2(40, 29), "size": Vector2(12, 18), "needs": "water", "hide_if": "workstation", "behind": true},
	{"tex": "res://art/pc_workstation.png", "pos": Vector2(40, 29), "size": Vector2(12, 18), "needs": "workstation", "behind": true, "fps": 2.0},
	{"tex": "res://art/monitor_wall.png", "pos": Vector2(10, -8), "size": Vector2(40, 18), "needs": "monitor_wall", "behind": true, "fps": 2.0},
	{"tex": "res://art/monitor_2.png", "pos": Vector2(16, 11), "size": Vector2(14, 17), "needs": "monitor_2"},
	{"tex": "res://art/monitor_3.png", "pos": Vector2(46, 11), "size": Vector2(14, 17), "needs": "monitor_3"},
	{"tex": "res://art/keyboard_mech.png", "pos": Vector2(18, 24), "size": Vector2(16, 4), "needs": "keyboard"},
	# Stage 10: certificates on the wall, one frame per learned skill (sheet with 5 frames)
	{"tex": "res://art/certificates.png", "pos": Vector2(52, -6), "size": Vector2(10, 12), "needs": "", "skill_frames": true},
	# Right of the desk
	{"tex": "res://art/rack.png", "pos": Vector2(63, 0), "size": Vector2(24, 48), "needs": "rack"},
	{"tex": "res://art/rack_cooling.png", "pos": Vector2(63, 0), "size": Vector2(24, 48), "needs": "rack_cooling", "fps": 2.0},
	{"tex": "res://art/fan.png", "pos": Vector2(90, 24), "size": Vector2(12, 24), "needs": "fan", "fps": 8.0},
	{"tex": "res://art/ups.png", "pos": Vector2(104, 36), "size": Vector2(10, 12), "needs": "ups", "fps": 1.0},
	{"tex": "res://art/ac.png", "pos": Vector2(90, -8), "size": Vector2(24, 10), "needs": "ac", "fps": 3.0},
	# Left of the chair (XYMYX walks in front of these)
	{"tex": "res://art/homeserver.png", "pos": Vector2(-36, 26), "size": Vector2(14, 22), "needs": "homeserver", "fps": 2.0},
	{"tex": "res://art/router.png", "pos": Vector2(-35, 20), "size": Vector2(12, 6), "needs": "router", "fps": 4.0},
	{"tex": "res://art/fiber.png", "pos": Vector2(-46, 10), "size": Vector2(8, 10), "needs": "fiber", "fps": 1.0},
	{"tex": "res://art/line2.png", "pos": Vector2(-36, 4), "size": Vector2(8, 10), "needs": "line2", "fps": 1.0},
	{"tex": "res://art/nas.png", "pos": Vector2(-50, 36), "size": Vector2(10, 12), "needs": "nas", "fps": 2.0},
	{"tex": "res://art/ssd_raid.png", "pos": Vector2(-50, 31), "size": Vector2(10, 5), "needs": "ssd_raid"},
	{"tex": "res://art/grid.png", "pos": Vector2(-62, 8), "size": Vector2(12, 16), "needs": "grid"},
	{"tex": "res://art/asic.png", "pos": Vector2(-62, 40), "size": Vector2(10, 8), "needs": "asic", "fps": 6.0},
	{"tex": "res://art/asic_shelf.png", "pos": Vector2(-84, 18), "size": Vector2(20, 30), "needs": "asic_shelf", "fps": 4.0},
	{"tex": "res://art/mining_rack.png", "pos": Vector2(-110, 0), "size": Vector2(24, 48), "needs": "mining_rack", "fps": 4.0},
]

## Location board on the wall: big installations that don't fit into the room
## appear as 8x8 icons (art/icon_<id>.png, optionally 2 frames = 16x8).
## The board is only as big as needed (up to 8 icons per row) and hangs right next to
## the leftmost part in the room. Border and fill color come from board.png.
const BOARD_TEX := "res://art/board.png"
const BOARD_TOP := -8.0
const BOARD_COLS := 8
const BOARD_GAP := 3.0       # gap to the next part on the right
const BOARD_PAD := 2         # padding between border and icons
const BOARD_ICON_GAP := 2    # gap between icons
const BOARD_TRAY := 2.0      # height of the tray below the board
const BOARD_MAX_RIGHT := -18.0  # never closer to the chair
const BOARD_FPS := 2.0
const BOARD_ITEMS := [
	"plugin", "desktop_app", "saas", "platform", "ecosystem", "storage_server",
	"storage_cloud", "leased", "dc_link", "solar", "battery", "own_grid",
	"cool_loop", "industrial_cooling", "mining_container", "mining_farm",
]
const ANIM_TICK := 0.125  # at most 8 animation checks per second

const CHAIR := "res://art/chair.png"
const CHAIR_POS := Vector2(0, 14)
const FLASH_SEC := 0.6
const LAPTOP_RECT := Rect2(30, 10, 16, 17)  # flash area while there is no tower
const TOWER_RECT := Rect2(40, 29, 12, 18)

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


func _ready() -> void:
	Game.changed.connect(queue_redraw)


## Short white flash on the purchased part (installation effect).
func flash(id: String) -> void:
	_flash_rect = TOWER_RECT if Game.has("gaming_pc") else LAPTOP_RECT
	for part: Dictionary in PARTS:
		if part["needs"] == id and _shown(part):
			_flash_rect = Rect2(part["pos"], part["size"])
	if BOARD_ITEMS.has(id) and Game.has(id):
		_flash_rect = Rect2(_board_slot(_board_owned().find(id)), Vector2(8, 8))
	_flash_left = FLASH_SEC


## Only redraw when an animation frame changes or something is flashing.
func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		queue_redraw()
		return
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
		x = minf(x, _board_rect().position.x - 1)  # -1: the tray sticks out by 1 px
	return x


func _draw() -> void:
	_draw_board()
	_draw_parts(true)
	var base := BASE_PC if Game.has("gaming_pc") else BASE_LAPTOP
	var t := _tex(base)
	if t == null and base == BASE_PC:
		t = _tex(BASE_LAPTOP)  # until desk_pc.png exists
	if t:
		draw_texture(t, Vector2.ZERO)
	else:
		_placeholder(Rect2(Vector2(12, 28), Vector2(48, 4)))
	if chair_visible:
		var c := _tex(CHAIR)
		if c:
			draw_texture(c, CHAIR_POS)
	_draw_parts(false)
	# Flash: 3× on/off within FLASH_SEC
	if _flash_left > 0.0 and int(_flash_left / FLASH_SEC * 6.0) % 2 == 1:
		draw_rect(_flash_rect, Color(1, 1, 1, 0.75))


func _draw_parts(behind: bool) -> void:
	for part: Dictionary in PARTS:
		if not _shown(part) or part.get("behind", false) != behind:
			continue
		if part.get("skill_frames", false):
			_draw_frame(part["tex"], part["pos"], part["size"], SkillData.learned_count(Game.skills) - 1)
		else:
			_draw_sprite(part["tex"], part["pos"], part["size"], part.get("fps", 0.0))


## Draws a fixed frame of a sheet (clamped to the frames that exist) or the placeholder.
func _draw_frame(path: String, pos: Vector2, size: Vector2, f: int) -> void:
	var t := _tex(path)
	if t == null:
		_placeholder(Rect2(pos, size))
		return
	var frames := maxi(1, int(t.get_width() / size.x))
	f = clampi(f, 0, frames - 1)
	draw_texture_rect_region(t, Rect2(pos, size), Rect2(Vector2(f * size.x, 0), size))


## Draws a (possibly animated) sprite or the placeholder in its target size.
func _draw_sprite(path: String, pos: Vector2, size: Vector2, fps: float) -> void:
	var t := _tex(path)
	if t == null:
		_placeholder(Rect2(pos, size))
		return
	var f := _frame(path, size, fps)
	draw_texture_rect_region(t, Rect2(pos, size), Rect2(Vector2(f * size.x, 0), size))


func _frame(path: String, size: Vector2, fps: float) -> int:
	var t := _tex(path)
	if t == null or fps <= 0.0:
		return 0
	var frames := maxi(1, int(t.get_width() / size.x))
	return int(Time.get_ticks_msec() / 1000.0 * fps) % frames


func _draw_board() -> void:
	var owned := _board_owned()
	if owned.is_empty():
		return
	var r := _board_rect()
	var cols := _board_colors()
	draw_rect(r, cols[0])
	draw_rect(r.grow(-1), cols[1])
	# Tray below the board (like a chalkboard), 1 px wider on each side
	draw_rect(Rect2(r.position.x - 1, r.end.y, r.size.x + 2, BOARD_TRAY), cols[0])
	for i in owned.size():
		_draw_sprite("res://art/icon_%s.png" % owned[i], _board_slot(i), Vector2(8, 8), BOARD_FPS)


func _board_owned() -> Array[String]:
	var out: Array[String] = []
	for id: String in BOARD_ITEMS:
		if Game.has(id):
			out.append(id)
	return out


func _board_count() -> int:
	return _board_owned().size()


## Board rectangle: grows with the icons, right-aligned before the leftmost part.
func _board_rect() -> Rect2:
	var n := _board_count()
	var cols := mini(n, BOARD_COLS)
	var rows := ceili(n / float(BOARD_COLS))
	# 1 px border + padding on both sides, 8 px icons with gaps between them
	var size := Vector2(2 + 2 * BOARD_PAD + cols * 8 + (cols - 1) * BOARD_ICON_GAP,
		2 + 2 * BOARD_PAD + rows * 8 + (rows - 1) * BOARD_ICON_GAP)
	var right := BOARD_MAX_RIGHT
	for part: Dictionary in PARTS:
		if _shown(part) and part["pos"].x < 0.0:
			right = minf(right, part["pos"].x)
	right -= BOARD_GAP
	return Rect2(Vector2(right - size.x, BOARD_TOP), size)


## Slot i (owned icons only, no gaps).
func _board_slot(i: int) -> Vector2:
	var pitch := 8 + BOARD_ICON_GAP
	return _board_rect().position + Vector2(1 + BOARD_PAD + (i % BOARD_COLS) * pitch,
		1 + BOARD_PAD + (i / BOARD_COLS) * pitch)


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
	return Game.has(part["needs"]) and not (part.has("hide_if") and Game.has(part["hide_if"]))


func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Grey box with a light border: shows position and size of the missing sprite.
func _placeholder(r: Rect2) -> void:
	draw_rect(r, Color("#d6d9ee"))
	draw_rect(r.grow(-1), Color("#3a3a48"))
