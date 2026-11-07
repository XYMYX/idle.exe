extends Node2D
## Desktop-Pet-Fenster: transparenter Streifen über der Taskleiste.
## Nur Figur und Desk fangen Klicks ab, alles andere geht zum Desktop durch.
##
## Maus:
##   XYMYX kurz klicken  = hüpfen        XYMYX ziehen = packen, tragen, fallen lassen
##   Desk kurz klicken   = Terminal      Desk ziehen  = ganze Leiste verschieben (wird gespeichert)
##   Rechtsklick         = Menü

const GAME_HEIGHT := 58      # Fensterhöhe in Spielpixeln (48 Figur/Desk + Platz für Zähler/Hüpfer)
const BASE_SCALE := 2        # Pixel-Skalierung bei 100 % Windows-Skalierung
const DESK_FROM_RIGHT := 120 # Standard-Abstand Desk zum rechten Bildschirmrand (Spielpixel)
const FIGURE := 48
const DRAG_START_PX := 3.0   # ab so viel Mausweg (Spielpixel) wird aus einem Klick ein Ziehen
const SETTINGS_PATH := "user://settings.cfg"

enum MenuId { INFO, TERMINAL, PAUSE, RESET, QUIT }
enum Press { NONE, FIGURE, DESK }

var pixel_scale := BASE_SCALE
var game_width := 0

var _world: Node2D
var _desk: Desk
var _xymyx: Xymyx
var _counter: CommitCounter
var _carry: CarryWindow
var _menu: PopupMenu
var _terminal: TerminalMenu
var _watch: MouseWatch
var _events: EventDirector
var _last_bought := ""
var _last_passthrough := PackedVector2Array()

var _usable := Rect2i()
var _desk_from_right := float(DESK_FROM_RIGHT)

# Laufende Maus-Aktion
var _press := Press.NONE
var _press_screen := Vector2i.ZERO
var _press_p := Vector2.ZERO
var _dragging := false
var _grab_offset := Vector2.ZERO
var _last_drag_p := Vector2.ZERO
var _throw_vel := Vector2.ZERO
var _move_start_win := Vector2i.ZERO
var _move_start_desk := 0.0


func _ready() -> void:
	_setup_window()
	_build_scene()
	_build_menu()
	_update_passthrough()


func _setup_window() -> void:
	var screen := DisplayServer.get_primary_screen()
	_usable = DisplayServer.screen_get_usable_rect(screen)
	var dpi := DisplayServer.screen_get_dpi(screen)
	# screen_get_scale() liefert unter Windows immer 1.0 (laut Doku), darum DPI/96.
	pixel_scale = maxi(1, roundi(BASE_SCALE * dpi / 96.0))
	game_width = _usable.size.x / pixel_scale

	# Gespeicherte Lage: Abstand der Leiste zum unteren Rand (Pixel) und des Desks zum rechten Rand.
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # fehlt die Datei, gelten die Standardwerte
	var lift: int = cfg.get_value("layout", "lift_px", 0)
	_desk_from_right = cfg.get_value("layout", "desk_from_right", float(DESK_FROM_RIGHT))

	var win := get_window()
	var win_size := Vector2i(game_width * pixel_scale, GAME_HEIGHT * pixel_scale)
	win.size = win_size
	win.position = Vector2i(_usable.position.x, _clamp_win_y(_usable.end.y - win_size.y - lift))
	print("idle.exe: usable=%s dpi=%d scale=%d window=%s at %s"
		% [_usable, dpi, pixel_scale, win_size, win.position])


func _build_scene() -> void:
	_world = Node2D.new()
	_world.scale = Vector2(pixel_scale, pixel_scale)
	add_child(_world)

	_desk = Desk.new()
	_world.add_child(_desk)

	_xymyx = Xymyx.new()
	_xymyx.position.y = GAME_HEIGHT - FIGURE
	_world.add_child(_xymyx)

	_counter = CommitCounter.new()
	_world.add_child(_counter)

	_desk_from_right = _clamp_desk_from_right(_desk_from_right)
	_place_desk()
	_xymyx.setup(_xymyx.home_x, _xymyx.repair_x, 8.0, game_width - FIGURE - 8.0)
	_xymyx.moved.connect(_update_passthrough)
	_xymyx.landed.connect(_on_landed)
	Game.changed.connect(_update_passthrough)  # neue Teile vergrössern den Klickbereich

	# Animationen: Kauf -> schrauben + Aufblinken, Meilenstein -> jubeln, Rollen -> Stuhl ausblenden
	Game.bought.connect(func(id: String) -> void:
		_last_bought = id
		_xymyx.start_repair())
	_xymyx.repair_started.connect(func() -> void: _desk.flash(_last_bought))
	_xymyx.chair_taken.connect(func(taken: bool) -> void: _desk.chair_visible = not taken)
	Game.milestone.connect(func(_v: float) -> void: _xymyx.react("cheer"))

	# Maus-Reaktionen (nur Mausposition, keine Tasten, kein Hook)
	_watch = MouseWatch.new()
	_watch.to_game = func(screen: Vector2i) -> Vector2:
		return Vector2(screen - get_window().position) / pixel_scale
	_watch.figure_center = func() -> Vector2: return _xymyx.position + Vector2(FIGURE, FIGURE) / 2.0
	_watch.figure_hit = func(g: Vector2) -> bool: return _xymyx.visible and _xymyx.hit(g)
	_watch.away.connect(_xymyx.fall_asleep)
	_watch.back.connect(_xymyx.wake_up)
	_watch.startled.connect(func() -> void:
		if _press == Press.NONE:  # nicht beim eigenen Ziehen erschrecken
			_xymyx.startle())
	_watch.hovered.connect(_xymyx.notice)
	_watch.sampled.connect(func(g: Vector2) -> void: _xymyx.face_toward(g.x))
	add_child(_watch)

	_carry = CarryWindow.new()
	_carry.setup(_xymyx.sprite_frames, pixel_scale, FIGURE)  # vor add_child: startet unsichtbar
	add_child(_carry)


## Desk, Zähler und XYMYX-Heimatpunkt an _desk_from_right ausrichten.
func _place_desk() -> void:
	_desk.position = Vector2(game_width - _desk_from_right, GAME_HEIGHT - Desk.SIZE.y)
	_counter.position = _desk.position + Vector2(38, 2)  # über dem Laptop-Bildschirm
	var home := _desk.position.x - 16  # Hüfte auf dem Stuhl im Desk-Sprite
	var repair := _desk.position.x + 18
	if _xymyx.home_x == 0.0 and _xymyx.repair_x == 0.0:
		_xymyx.home_x = home  # erster Aufruf, setup() folgt
		_xymyx.repair_x = repair
	else:
		_xymyx.set_home(home, repair)


func _build_menu() -> void:
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu_id)
	add_child(_menu)

	# Zufallsereignisse: «!» über XYMYX, Klick auf ihn öffnet die Wahl im Terminal
	_events = EventDirector.new()
	_events.is_away = func() -> bool: return _watch.is_away
	_events.started.connect(func(_e: Dictionary) -> void: _xymyx.set_alert(true))
	_events.resolved.connect(func(_e: Dictionary, c: Dictionary, _auto: bool) -> void:
		_xymyx.set_alert(false)
		if c.has("react"):
			_xymyx.react(c["react"]))
	add_child(_events)

	_terminal = TerminalMenu.new()
	add_child(_terminal)
	_terminal.setup(pixel_scale, _events)

	_build_tray()


## Tray-Icon (Infobereich der Taskleiste). Links = Terminal, rechts = Menü.
## Eigenes Icon: art/tray_icon.png (32×32), sonst Platzhalter.
const TRAY_ICON := "res://art/tray_icon.png"

func _build_tray() -> void:
	var tray := StatusIndicator.new()
	tray.tooltip = "idle.exe – XYMYX"
	tray.icon = load(TRAY_ICON) if ResourceLoader.exists(TRAY_ICON) else _placeholder_tray_icon()
	tray.pressed.connect(func(button: int, _pos: Vector2i) -> void:
		if button == MOUSE_BUTTON_LEFT:
			if not _events.pending.is_empty():
				_open_event()
			else:
				_toggle_terminal()
		else:
			_open_menu())
	add_child(tray)


## 32×32: schwarz, weisser Rand, zwei weisse Augen (wie die Figur).
func _placeholder_tray_icon() -> Texture2D:
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.fill_rect(Rect2i(2, 2, 28, 28), Color.BLACK)
	img.fill_rect(Rect2i(9, 12, 4, 4), Color.WHITE)
	img.fill_rect(Rect2i(19, 12, 4, 4), Color.WHITE)
	return ImageTexture.create_from_image(img)


## Menü bei jedem Öffnen neu aufbauen, damit die Zahlen stimmen.
func _fill_menu() -> void:
	_menu.clear()
	_menu.add_item("Geld: %s CHF  (+%s CHF/s)"
		% [BigNum.format_chf(Game.money), BigNum.format_chf(Game.income())], MenuId.INFO)
	_menu.set_item_disabled(_menu.get_item_index(MenuId.INFO), true)
	_menu.add_separator()
	_menu.add_item("Terminal öffnen", MenuId.TERMINAL)
	_menu.add_check_item("Pause", MenuId.PAUSE)
	_menu.set_item_checked(_menu.get_item_index(MenuId.PAUSE), Game.paused)
	_menu.add_item("Leiste zurücksetzen", MenuId.RESET)
	_menu.add_separator()
	_menu.add_item("Beenden", MenuId.QUIT)


# --- Maus -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _press == Press.NONE:
		_open_menu()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		var p := mb.position / pixel_scale
		# XYMYX (pixelgenau) hat Vorrang vor dem Desk dahinter.
		if not _xymyx.is_airborne() and _xymyx.hit(p) and _xymyx.can_grab():
			_press = Press.FIGURE
			_grab_offset = p - _xymyx.position
		elif _home_rect().has_point(p) and _desk_hit(p):
			_press = Press.DESK
		_press_screen = DisplayServer.mouse_get_position()
		_press_p = p
	else:
		_release()


func _process(delta: float) -> void:
	if _press == Press.NONE:
		if _xymyx.is_airborne():
			_show_carry()  # fällt gerade
		elif _carry.visible:
			_on_landed()  # Boden berührt: Landeanimation schon in der Leiste zeigen
		return
	if not _dragging:
		var moved := Vector2(DisplayServer.mouse_get_position() - _press_screen).length()
		if moved > DRAG_START_PX * pixel_scale:
			_start_drag()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # Loslassen verpasst
		_release()
		return
	match _press:
		Press.FIGURE:
			_drag_figure(delta)
		Press.DESK:
			_drag_bar()


func _start_drag() -> void:
	_dragging = true
	if _terminal.visible:
		_terminal.hide()
	if _press == Press.FIGURE:
		_last_drag_p = _xymyx.position
		_throw_vel = Vector2.ZERO
		_xymyx.grab()
		_update_passthrough(true)  # Figur ist jetzt im Tragefenster, nicht mehr in der Leiste
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	else:
		_move_start_win = get_window().position
		_move_start_desk = _desk_from_right
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)


func _release() -> void:
	var was := _press
	var dragged := _dragging
	_press = Press.NONE
	_dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if was == Press.FIGURE:
		if dragged:
			_xymyx.drop(_throw_vel)
		elif not _events.pending.is_empty():
			_open_event()  # offenes Ereignis: Klick auf XYMYX zeigt die Wahl
		else:
			_xymyx.bounce()  # je öfter, desto höher
	elif was == Press.DESK:
		if dragged:
			_save_layout()
		elif Rect2(_desk.position, Desk.SIZE).has_point(_press_p):
			_toggle_terminal()  # nur der Desk selbst, nicht die Teile daneben


## XYMYX hängt an der Maus. Spiel-Koordinaten relativ zur Leiste (y < 0 = darüber).
func _drag_figure(delta: float) -> void:
	var m := Vector2(DisplayServer.mouse_get_position() - get_window().position)
	var p := m / pixel_scale - _grab_offset
	var top := float(_usable.position.y - get_window().position.y) / pixel_scale
	p.x = clampf(p.x, _xymyx.min_x, _xymyx.max_x)
	p.y = clampf(p.y, top, _xymyx.floor_y)
	_xymyx.drag_to(p)
	if delta > 0.0:  # Wurf-Tempo, geglättet
		_throw_vel = _throw_vel.lerp((p - _last_drag_p) / delta, 0.5)
	_last_drag_p = p
	_show_carry()


## Ganze Leiste verschieben: senkrecht das Fenster, waagrecht den Desk darin.
func _drag_bar() -> void:
	var d := DisplayServer.mouse_get_position() - _press_screen
	var win := get_window()
	var y := _clamp_win_y(_move_start_win.y + d.y)
	if win.position.y != y:
		win.position = Vector2i(win.position.x, y)
	var dfr := _clamp_desk_from_right(_move_start_desk - float(d.x) / pixel_scale)
	if roundf(dfr) != roundf(_desk_from_right):
		_desk_from_right = roundf(dfr)
		_place_desk()
		_update_passthrough()


## Tragefenster an die Position der Figur setzen, Figur in der Leiste ausblenden.
func _show_carry() -> void:
	_xymyx.visible = false
	var screen := get_window().position + Vector2i(_xymyx.position * pixel_scale)
	_carry.follow(_xymyx, screen)


func _on_landed() -> void:
	_carry.hide()
	_xymyx.visible = true
	_update_passthrough()


# --- Lage speichern -------------------------------------------------------------

func _clamp_win_y(y: int) -> int:
	return clampi(y, _usable.position.y, _usable.end.y - GAME_HEIGHT * pixel_scale)


## Desk inkl. aller Teile links (Tafel) und rechts (Rack, Klima) bleibt auf dem Bildschirm.
func _clamp_desk_from_right(dfr: float) -> float:
	var left := -_desk.left_extent() if _desk else 0.0
	var right := _desk.width() if _desk else Desk.SIZE.x
	return clampf(dfr, right + 2.0, float(game_width) - left - 2.0)


## Leiste direkt über die Taskleiste, Desk an den Standardplatz. Wird gespeichert.
func _reset_layout() -> void:
	var win := get_window()
	win.position = Vector2i(win.position.x, _clamp_win_y(_usable.end.y - GAME_HEIGHT * pixel_scale))
	_desk_from_right = _clamp_desk_from_right(float(DESK_FROM_RIGHT))
	_place_desk()
	_update_passthrough()
	_save_layout()


func _save_layout() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var lift := _usable.end.y - GAME_HEIGHT * pixel_scale - get_window().position.y
	cfg.set_value("layout", "lift_px", lift)
	cfg.set_value("layout", "desk_from_right", _desk_from_right)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("Lage speichern fehlgeschlagen: %s" % error_string(err))


# --- Menüs ------------------------------------------------------------------------

func _toggle_terminal() -> void:
	if _terminal.visible:
		_terminal.hide()
		return
	# Der Klick, der das Terminal schliesst (Klick daneben), soll es nicht gleich wieder öffnen.
	if Time.get_ticks_msec() - _terminal.hidden_msec < 300:
		return
	# Rechte untere Ecke des Terminals = rechter Rand des Desk-Bereichs, Oberkante des Streifens
	var right := int(_home_rect().end.x * pixel_scale)
	_terminal.open_at(get_window().position + Vector2i(right, 0))


func _open_event() -> void:
	var right := int(_home_rect().end.x * pixel_scale)
	_terminal.open_event(get_window().position + Vector2i(right, 0))


func _open_menu() -> void:
	_fill_menu()
	var menu_size := Vector2i(_menu.get_contents_minimum_size())
	var at := DisplayServer.mouse_get_position() - Vector2i(0, menu_size.y)
	_menu.popup(Rect2i(at, menu_size))


func _on_menu_id(id: int) -> void:
	match id:
		MenuId.PAUSE:
			Game.paused = not Game.paused
			_xymyx.paused = Game.paused
		MenuId.TERMINAL:
			_toggle_terminal()
		MenuId.RESET:
			_reset_layout()
		MenuId.QUIT:
			Game.quit()


# --- Klickbereich -----------------------------------------------------------

## Klick im Desk-Bereich, der nicht auf einem Pixel der Figur liegt.
func _desk_hit(p: Vector2) -> bool:
	return not _xymyx.hit(p)


func _figure_rect() -> Rect2:
	return Rect2(_xymyx.position.x, 0, FIGURE, GAME_HEIGHT)


## Klickfläche um die Figur: mit Luft und auf ein 24-px-Raster gerundet. So ändert sich
## die Fläche beim Laufen nur alle ~24 px statt bei jedem Pixel. Jede Änderung zeichnet
## unter Windows den neu freigegebenen Streifen kurz falsch (Flackern vor der Figur).
const REGION_STEP := 24.0
const REGION_MARGIN := 8.0

func _figure_region() -> Rect2:
	var x0 := floorf((_xymyx.position.x - REGION_MARGIN) / REGION_STEP) * REGION_STEP
	var x1 := ceilf((_xymyx.position.x + FIGURE + REGION_MARGIN) / REGION_STEP) * REGION_STEP
	return Rect2(x0, 0, x1 - x0, GAME_HEIGHT)


func _home_rect() -> Rect2:
	var left: float = minf(_xymyx.home_x, _desk.position.x + _desk.left_extent())  # inkl. Teile links vom Stuhl
	var right: float = _desk.position.x + maxf(_desk.width(), Desk.SIZE.x + 6)  # inkl. Rack, Platz für breite Zahlen
	return Rect2(left, 0, right - left, GAME_HEIGHT)


## Klickbares Polygon = Desk-Bereich + Figur. Unter Windows wird alles
## ausserhalb dieses Polygons NICHT gezeichnet, es muss also alles Sichtbare
## abdecken. Sind Figur und Desk getrennt, verbindet sie ein 1 Spielpixel
## hoher Steg am unteren Rand (ein einziges Polygon ist Pflicht).
## Wird XYMYX getragen oder fällt, zählt nur der Desk-Bereich.
func _update_passthrough(force := false) -> void:
	var a := _home_rect()
	var b := a if _xymyx.is_airborne() else _figure_region()
	var pts: PackedVector2Array
	if a.intersects(b, true):
		var m := a.merge(b)
		pts = PackedVector2Array([m.position, Vector2(m.end.x, m.position.y), m.end, Vector2(m.position.x, m.end.y)])
	else:
		var l := a if a.position.x < b.position.x else b
		var r := b if l == a else a
		var h := float(GAME_HEIGHT)
		pts = PackedVector2Array([
			Vector2(l.position.x, 0), Vector2(l.end.x, 0), Vector2(l.end.x, h - 1),
			Vector2(r.position.x, h - 1), Vector2(r.position.x, 0), Vector2(r.end.x, 0),
			Vector2(r.end.x, h), Vector2(l.position.x, h),
		])
	for i in pts.size():
		pts[i] *= pixel_scale
	# Nur setzen, wenn sich die Fläche ändert: Unter Windows zeichnet jedes Setzen
	# das Fenster neu, was beim Laufen innerhalb des Zimmers flackern kann.
	if pts == _last_passthrough and not force:
		return
	_last_passthrough = pts
	DisplayServer.window_set_mouse_passthrough(pts)
