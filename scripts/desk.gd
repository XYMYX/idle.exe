class_name Desk
extends Node2D
## Desk mit dem gekauften Setup. Grund-Bild je nach Stufe (Laptop oder Gaming-PC),
## darüber die einzelnen Teile. Fehlt ein PNG, wird ein grauer Platzhalter-Kasten
## in genau der Grösse gezeichnet, die das Sprite haben muss.

const SIZE := Vector2(61, 48)  # Grund-Bild (Stuhl + Tisch)

const BASE_LAPTOP := "res://art/desk_laptop.png"
const BASE_PC := "res://art/desk_pc.png"

## Teile in Zeichen-Reihenfolge. Koordinaten relativ zur linken oberen Ecke des Desks
## (Boden = y 48, Fenster-Oberkante = y -10, Bildschirmrand rechts = x 118).
## needs = Upgrade, das man besitzen muss; hide_if = wird ausgeblendet, wenn das besessen wird.
## behind = hinter dem Grund-Bild zeichnen (Tower unter dem Tisch, Tischplatte verdeckt ihn).
## fps = Animation: das PNG ist ein horizontales Sheet, Frames = Breite / size.x.
const PARTS := [
	# Am Desk
	{"tex": "res://art/pc_tower.png", "pos": Vector2(40, 29), "size": Vector2(12, 18), "needs": "gaming_pc", "hide_if": "water", "behind": true},
	{"tex": "res://art/pc_tower_water.png", "pos": Vector2(40, 29), "size": Vector2(12, 18), "needs": "water", "hide_if": "workstation", "behind": true},
	{"tex": "res://art/pc_workstation.png", "pos": Vector2(40, 29), "size": Vector2(12, 18), "needs": "workstation", "behind": true, "fps": 2.0},
	{"tex": "res://art/monitor_wall.png", "pos": Vector2(10, -8), "size": Vector2(40, 18), "needs": "monitor_wall", "behind": true, "fps": 2.0},
	{"tex": "res://art/monitor_2.png", "pos": Vector2(16, 11), "size": Vector2(14, 17), "needs": "monitor_2"},
	{"tex": "res://art/monitor_3.png", "pos": Vector2(46, 11), "size": Vector2(14, 17), "needs": "monitor_3"},
	{"tex": "res://art/keyboard_mech.png", "pos": Vector2(18, 24), "size": Vector2(16, 4), "needs": "keyboard"},
	# Rechts vom Desk
	{"tex": "res://art/rack.png", "pos": Vector2(63, 0), "size": Vector2(24, 48), "needs": "rack"},
	{"tex": "res://art/rack_cooling.png", "pos": Vector2(63, 0), "size": Vector2(24, 48), "needs": "rack_cooling", "fps": 2.0},
	{"tex": "res://art/fan.png", "pos": Vector2(90, 24), "size": Vector2(12, 24), "needs": "fan", "fps": 8.0},
	{"tex": "res://art/ups.png", "pos": Vector2(104, 36), "size": Vector2(10, 12), "needs": "ups", "fps": 1.0},
	{"tex": "res://art/ac.png", "pos": Vector2(90, -8), "size": Vector2(24, 10), "needs": "ac", "fps": 3.0},
	# Links vom Stuhl (XYMYX läuft davor durch)
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

## Standort-Tafel an der Wand: grosse Anlagen, die nicht ins Zimmer passen,
## erscheinen als 8x8-Symbole (art/icon_<id>.png, optional 2 Frames = 16x8).
## Die Tafel ist nur so gross wie nötig (bis 8 Symbole pro Reihe) und hängt direkt
## links neben dem linkesten Teil im Zimmer. Rahmen- und Füllfarbe aus board.png.
const BOARD_TEX := "res://art/board.png"
const BOARD_TOP := -8.0
const BOARD_COLS := 8
const BOARD_GAP := 3.0       # Abstand zum nächsten Teil rechts
const BOARD_PAD := 2         # Innenrand zwischen Rahmen und Symbolen
const BOARD_ICON_GAP := 2    # Abstand zwischen den Symbolen
const BOARD_TRAY := 2.0      # Höhe der Ablage-Leiste unter der Tafel
const BOARD_MAX_RIGHT := -18.0  # nie näher an den Stuhl
const BOARD_FPS := 2.0
const BOARD_ITEMS := [
	"plugin", "desktop_app", "saas", "platform", "ecosystem", "storage_server",
	"storage_cloud", "leased", "dc_link", "solar", "battery", "own_grid",
	"cool_loop", "industrial_cooling", "mining_container", "mining_farm",
]
const ANIM_TICK := 0.125  # höchstens 8 Prüfungen pro Sekunde für Animationen

const CHAIR := "res://art/chair.png"
const CHAIR_POS := Vector2(0, 14)
const FLASH_SEC := 0.6
const LAPTOP_RECT := Rect2(30, 10, 16, 17)  # Aufblink-Fläche, solange es keinen Tower gibt
const TOWER_RECT := Rect2(40, 29, 12, 18)

## Aus, solange XYMYX mit dem Stuhl rollt (der Stuhl steckt dann in seinem Sprite).
var chair_visible := true:
	set(value):
		chair_visible = value
		queue_redraw()

var _cache := {}  # Pfad -> Texture2D oder null
var _flash_rect := Rect2()
var _flash_left := 0.0


var _anim_left := 0.0
var _anim_key := ""


func _ready() -> void:
	Game.changed.connect(queue_redraw)


## Kurzes weisses Aufblinken am gekauften Teil (Einbau-Effekt).
func flash(id: String) -> void:
	_flash_rect = TOWER_RECT if Game.has("gaming_pc") else LAPTOP_RECT
	for part: Dictionary in PARTS:
		if part["needs"] == id and _shown(part):
			_flash_rect = Rect2(part["pos"], part["size"])
	if BOARD_ITEMS.has(id) and Game.has(id):
		_flash_rect = Rect2(_board_slot(_board_owned().find(id)), Vector2(8, 8))
	_flash_left = FLASH_SEC


## Neu zeichnen nur, wenn ein Animations-Frame wechselt oder gerade etwas blinkt.
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


## Breite inkl. Teilen, die über den Tisch hinausragen (Rack). Für den Klickbereich.
func width() -> float:
	var w := SIZE.x
	for part: Dictionary in PARTS:
		if _shown(part):
			w = maxf(w, part["pos"].x + part["size"].x)
	return w


## Linkeste x-Koordinate (negativ, wenn Teile links vom Stuhl stehen). Für den Klickbereich.
func left_extent() -> float:
	var x := 0.0
	for part: Dictionary in PARTS:
		if _shown(part):
			x = minf(x, part["pos"].x)
	if _board_count() > 0:
		x = minf(x, _board_rect().position.x - 1)  # -1: Ablage-Leiste ragt 1 px hinaus
	return x


func _draw() -> void:
	_draw_board()
	_draw_parts(true)
	var base := BASE_PC if Game.has("gaming_pc") else BASE_LAPTOP
	var t := _tex(base)
	if t == null and base == BASE_PC:
		t = _tex(BASE_LAPTOP)  # bis desk_pc.png existiert
	if t:
		draw_texture(t, Vector2.ZERO)
	else:
		_placeholder(Rect2(Vector2(12, 28), Vector2(48, 4)))
	if chair_visible:
		var c := _tex(CHAIR)
		if c:
			draw_texture(c, CHAIR_POS)
	_draw_parts(false)
	# Blinken: 3× an/aus in FLASH_SEC
	if _flash_left > 0.0 and int(_flash_left / FLASH_SEC * 6.0) % 2 == 1:
		draw_rect(_flash_rect, Color(1, 1, 1, 0.75))


func _draw_parts(behind: bool) -> void:
	for part: Dictionary in PARTS:
		if not _shown(part) or part.get("behind", false) != behind:
			continue
		_draw_sprite(part["tex"], part["pos"], part["size"], part.get("fps", 0.0))


## Zeichnet ein (evtl. animiertes) Sprite oder den Platzhalter in Sollgrösse.
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
	# Ablage-Leiste unter der Tafel (wie bei einer Wandtafel), 1 px breiter auf jeder Seite
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


## Rechteck der Tafel: wächst mit den Symbolen, rechts bündig vor dem linkesten Teil.
func _board_rect() -> Rect2:
	var n := _board_count()
	var cols := mini(n, BOARD_COLS)
	var rows := ceili(n / float(BOARD_COLS))
	# 1 px Rahmen + Innenrand auf beiden Seiten, Symbole 8 px mit Abstand dazwischen
	var size := Vector2(2 + 2 * BOARD_PAD + cols * 8 + (cols - 1) * BOARD_ICON_GAP,
		2 + 2 * BOARD_PAD + rows * 8 + (rows - 1) * BOARD_ICON_GAP)
	var right := BOARD_MAX_RIGHT
	for part: Dictionary in PARTS:
		if _shown(part) and part["pos"].x < 0.0:
			right = minf(right, part["pos"].x)
	right -= BOARD_GAP
	return Rect2(Vector2(right - size.x, BOARD_TOP), size)


## Platz i (nur gekaufte Symbole, lückenlos).
func _board_slot(i: int) -> Vector2:
	var pitch := 8 + BOARD_ICON_GAP
	return _board_rect().position + Vector2(1 + BOARD_PAD + (i % BOARD_COLS) * pitch,
		1 + BOARD_PAD + (i / BOARD_COLS) * pitch)


## [Rahmen, Füllung] aus board.png (Rand links Mitte, Mitte). Ohne PNG: Grautöne.
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
	return Game.has(part["needs"]) and not (part.has("hide_if") and Game.has(part["hide_if"]))


func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Grauer Kasten mit hellem Rand: zeigt Position und Grösse des fehlenden Sprites.
func _placeholder(r: Rect2) -> void:
	draw_rect(r, Color("#d6d9ee"))
	draw_rect(r.grow(-1), Color("#3a3a48"))
