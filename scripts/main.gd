extends Node2D
## Desktop pet window: transparent strip above the taskbar.
## Only the figure and the desk catch clicks, everything else passes through to the desktop.
##
## Mouse:
##   click XYMYX  = jump (combo)     drag XYMYX = pick up, carry, drop
##   click desk   = terminal         drag desk  = move the whole strip (saved)
##   right click  = menu

const GAME_HEIGHT := 58      # window height in game pixels (48 figure/desk + room for counter/jumps)
const BASE_SCALE := 2        # pixel scale at 100 % Windows scaling
const DESK_FROM_RIGHT := 120 # default distance of the desk from the right screen edge (game pixels)
const FIGURE := 48
const DRAG_START_PX := 3.0   # mouse travel (game pixels) after which a click becomes a drag
const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["de", "en"]

enum MenuId { INFO, TERMINAL, PAUSE, RESET, LANGUAGE, DEBUG_EVENT, QUIT }
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
var _last_rects: Array[Rect2] = []

var _usable := Rect2i()
var _desk_from_right := float(DESK_FROM_RIGHT)

# Current mouse action
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
	_load_language()
	_setup_window()
	_build_scene()
	_build_menu()
	_update_passthrough()


## Language from settings.cfg; on first start German if Windows is German, otherwise English.
func _load_language() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var fallback := "de" if OS.get_locale_language() == "de" else "en"
	var lang: String = cfg.get_value("settings", "language", fallback)
	TranslationServer.set_locale(lang if lang in LANGUAGES else "en")


func _toggle_language() -> void:
	var lang := "en" if TranslationServer.get_locale().begins_with("de") else "de"
	TranslationServer.set_locale(lang)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("settings", "language", lang)
	cfg.save(SETTINGS_PATH)
	_terminal.refresh_language()


func _setup_window() -> void:
	var screen := DisplayServer.get_primary_screen()
	_usable = DisplayServer.screen_get_usable_rect(screen)
	var dpi := DisplayServer.screen_get_dpi(screen)
	# screen_get_scale() always returns 1.0 on Windows (per the docs), hence DPI/96.
	pixel_scale = maxi(1, roundi(BASE_SCALE * dpi / 96.0))
	game_width = _usable.size.x / pixel_scale

	# Saved layout: distance of the strip from the bottom edge (pixels) and of the desk from the right edge.
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # if the file is missing, the defaults apply
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
	Game.changed.connect(_update_passthrough)  # new parts enlarge the click area

	# Animations: purchase -> repair + flash, milestone -> cheer, rolling -> hide the chair
	Game.bought.connect(func(id: String) -> void:
		_last_bought = id
		_xymyx.start_repair())
	_xymyx.repair_started.connect(func() -> void: _desk.flash(_last_bought))
	_xymyx.chair_taken.connect(func(taken: bool) -> void: _desk.chair_visible = not taken)
	Game.milestone.connect(func(_v: float) -> void: _xymyx.react("cheer"))
	Game.contract_delivered.connect(func(reward: float) -> void: _counter.show_gain(reward))
	Game.contract_done.connect(func(_kind: String) -> void: _xymyx.react("cheer"))
	Game.company_sold.connect(func(_points: int) -> void:
		_events.pending = {}  # a fresh company starts without an open event
		_xymyx.set_alert(false)
		_xymyx.react("cheer")
		_update_passthrough(true))
	Game.research_finished.connect(func(_id: String) -> void: _xymyx.react("cheer"))
	Game.company_acquired.connect(func(_id: String) -> void: _xymyx.react("cheer"))
	Game.flag_captured.connect(func(_id: String, reward: float) -> void:
		_xymyx.react("cheer")
		_counter.show_gain(reward))

	# Mouse reactions (mouse position only, no keys, no hook)
	_watch = MouseWatch.new()
	_watch.to_game = func(screen: Vector2i) -> Vector2:
		return Vector2(screen - get_window().position) / pixel_scale
	_watch.figure_center = func() -> Vector2: return _xymyx.position + Vector2(FIGURE, FIGURE) / 2.0
	_watch.figure_hit = func(g: Vector2) -> bool: return _xymyx.visible and _xymyx.hit(g)
	_watch.away.connect(func() -> void:
		_xymyx.fall_asleep()
		Game.note_stat("naps"))
	_watch.back.connect(_xymyx.wake_up)
	_watch.startled.connect(func() -> void:
		if _press == Press.NONE:  # don't get startled by our own dragging
			_xymyx.startle())
	_watch.hovered.connect(_xymyx.notice)
	_watch.sampled.connect(func(g: Vector2) -> void: _xymyx.face_toward(g.x))
	add_child(_watch)

	_carry = CarryWindow.new()
	_carry.setup(_xymyx.sprite_frames, pixel_scale, FIGURE)  # before add_child: starts hidden
	add_child(_carry)


## Align desk, counter and XYMYX's home spot with _desk_from_right.
func _place_desk() -> void:
	_desk.position = Vector2(game_width - _desk_from_right, GAME_HEIGHT - Desk.SIZE.y)
	_counter.position = _desk.position + Vector2(38, 2)  # above the laptop screen
	var home := _desk.position.x - 16  # hips on the chair in the desk sprite
	var repair := _desk.position.x + 18
	if _xymyx.home_x == 0.0 and _xymyx.repair_x == 0.0:
		_xymyx.home_x = home  # first call, setup() follows
		_xymyx.repair_x = repair
	else:
		_xymyx.set_home(home, repair)


func _build_menu() -> void:
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu_id)
	add_child(_menu)

	# Random events: «!» above XYMYX, clicking him opens the choice in the terminal
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


## Tray icon (notification area). Left = terminal, right = menu.
## Custom icon: art/tray_icon.png (32×32), otherwise a placeholder.
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
			_open_menu(true))
	add_child(tray)


## 32×32: black, white border, two white eyes (like the figure).
func _placeholder_tray_icon() -> Texture2D:
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.fill_rect(Rect2i(2, 2, 28, 28), Color.BLACK)
	img.fill_rect(Rect2i(9, 12, 4, 4), Color.WHITE)
	img.fill_rect(Rect2i(19, 12, 4, 4), Color.WHITE)
	return ImageTexture.create_from_image(img)


## Rebuild the menu on every open so numbers and language are current.
## The language switch only appears in the tray menu, not on the desktop right click.
func _fill_menu(from_tray := false) -> void:
	_menu.clear()
	_menu.add_item(tr("Money: %s CHF  (+%s CHF/s)")
		% [BigNum.format_chf(Game.money), BigNum.format_chf(Game.income())], MenuId.INFO)
	_menu.set_item_disabled(_menu.get_item_index(MenuId.INFO), true)
	_menu.add_separator()
	_menu.add_item(tr("Open terminal"), MenuId.TERMINAL)
	_menu.add_check_item(tr("Pause"), MenuId.PAUSE)
	_menu.set_item_checked(_menu.get_item_index(MenuId.PAUSE), Game.paused)
	_menu.add_item(tr("Reset strip"), MenuId.RESET)
	if from_tray:
		# Always shows the OTHER language in its own words, so anyone can find it.
		_menu.add_item("English" if TranslationServer.get_locale().begins_with("de") else "Deutsch", MenuId.LANGUAGE)
	if from_tray and OS.is_debug_build():
		# Only when started from the editor (debug build), never in an exported release
		_menu.add_item("[debug] Trigger event", MenuId.DEBUG_EVENT)
		_menu.set_item_disabled(_menu.get_item_index(MenuId.DEBUG_EVENT), not _events.pending.is_empty())
	_menu.add_separator()
	_menu.add_item(tr("Quit"), MenuId.QUIT)


# --- Mouse ----------------------------------------------------------------------

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
		# XYMYX (pixel-exact) takes priority over the desk behind him.
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
			_show_carry()  # currently falling
		elif _carry.visible:
			_on_landed()  # touched the ground: show the landing animation in the strip already
		return
	if not _dragging:
		var moved := Vector2(DisplayServer.mouse_get_position() - _press_screen).length()
		if moved > DRAG_START_PX * pixel_scale:
			_start_drag()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # missed the release
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
		_update_passthrough(true)  # the figure is in the carry window now, no longer in the strip
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
			_open_event()  # pending event: clicking XYMYX shows the choice
		else:
			_xymyx.bounce()  # the more often, the higher
			Game.note_stat("max_combo", _xymyx.combo_level())
	elif was == Press.DESK:
		if dragged:
			_save_layout()
		elif Rect2(_desk.position, Desk.SIZE).has_point(_press_p):
			_toggle_terminal()  # only the desk itself, not the parts next to it


## XYMYX hangs on the mouse. Game coordinates relative to the strip (y < 0 = above it).
func _drag_figure(delta: float) -> void:
	var m := Vector2(DisplayServer.mouse_get_position() - get_window().position)
	var p := m / pixel_scale - _grab_offset
	var top := float(_usable.position.y - get_window().position.y) / pixel_scale
	p.x = clampf(p.x, _xymyx.min_x, _xymyx.max_x)
	p.y = clampf(p.y, top, _xymyx.floor_y)
	_xymyx.drag_to(p)
	if delta > 0.0:  # throw speed, smoothed
		_throw_vel = _throw_vel.lerp((p - _last_drag_p) / delta, 0.5)
	_last_drag_p = p
	_show_carry()


## Move the whole strip: the window vertically, the desk inside it horizontally.
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


## Move the carry window to the figure's position and hide the figure in the strip.
func _show_carry() -> void:
	_xymyx.visible = false
	var screen := get_window().position + Vector2i(_xymyx.position * pixel_scale)
	_carry.follow(_xymyx, screen)


func _on_landed() -> void:
	_carry.hide()
	_xymyx.visible = true
	_update_passthrough()


# --- Saving the layout ----------------------------------------------------------

func _clamp_win_y(y: int) -> int:
	return clampi(y, _usable.position.y, _usable.end.y - GAME_HEIGHT * pixel_scale)


## Keep the desk incl. all parts to the left (board) and right (rack, AC) on screen.
func _clamp_desk_from_right(dfr: float) -> float:
	var left := -_desk.left_extent() if _desk else 0.0
	var right := _desk.width() if _desk else Desk.SIZE.x
	return clampf(dfr, right + 2.0, float(game_width) - left - 2.0)


## Strip right above the taskbar, desk back at its default place. Saved.
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
		push_error("Saving the layout failed: %s" % error_string(err))


# --- Menus ----------------------------------------------------------------------

func _toggle_terminal() -> void:
	if _terminal.visible:
		_terminal.hide()
		return
	# The click that closes the terminal (click outside) must not reopen it right away.
	if Time.get_ticks_msec() - _terminal.hidden_msec < 300:
		return
	# Bottom-right corner of the terminal = right edge of the desk area, top edge of the strip
	var right := int(_home_rect().end.x * pixel_scale)
	_terminal.open_at(get_window().position + Vector2i(right, 0))


func _open_event() -> void:
	var right := int(_home_rect().end.x * pixel_scale)
	_terminal.open_event(get_window().position + Vector2i(right, 0))


func _open_menu(from_tray := false) -> void:
	_fill_menu(from_tray)
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
		MenuId.LANGUAGE:
			_toggle_language()
		MenuId.DEBUG_EVENT:
			_events.trigger_now()
		MenuId.QUIT:
			Game.quit()


# --- Click area -----------------------------------------------------------------

## A click in the desk area that is not on a pixel of the figure.
func _desk_hit(p: Vector2) -> bool:
	return not _xymyx.hit(p)


func _figure_rect() -> Rect2:
	return Rect2(_xymyx.position.x, 0, FIGURE, GAME_HEIGHT)


## Click area around the figure: with margin and snapped to a 24 px grid. This way the area
## only changes every ~24 px while walking instead of on every pixel. On Windows every change
## briefly draws the newly exposed strip incorrectly (flicker in front of the figure).
const REGION_STEP := 24.0
const REGION_MARGIN := 8.0

func _figure_region() -> Rect2:
	var x0 := floorf((_xymyx.position.x - REGION_MARGIN) / REGION_STEP) * REGION_STEP
	var x1 := ceilf((_xymyx.position.x + FIGURE + REGION_MARGIN) / REGION_STEP) * REGION_STEP
	return Rect2(x0, 0, x1 - x0, GAME_HEIGHT)


func _home_rect() -> Rect2:
	var left: float = minf(_xymyx.home_x, _desk.position.x + _desk.left_extent())  # incl. parts left of the chair
	var right: float = _desk.position.x + maxf(_desk.width(), Desk.SIZE.x + 6)  # incl. rack, room for wide numbers
	return Rect2(left, 0, right - left, GAME_HEIGHT)


const OUTLINE_MARGIN := 1.0  # extra px around every part (anti-cut-off)


## One polygon covering all rectangles exactly (their union). The window takes only a
## single polygon, so everything gets connected: a 1 px bridge along the bottom edge and
## a 1 px string from every hanging part (board, AC, ...) down to it. Holes in the union
## are simply filled (covering a bit more is safe, cutting off a sprite is not).
func _outline(rects: Array[Rect2]) -> PackedVector2Array:
	var h := float(GAME_HEIGHT)
	var grown: Array[Rect2] = []
	var x0 := INF
	var x1 := -INF
	for r: Rect2 in rects:
		var g := Rect2(r.position - Vector2.ONE * OUTLINE_MARGIN, r.size + Vector2.ONE * 2.0 * OUTLINE_MARGIN)
		var top := clampf(floorf(g.position.y), 0.0, h)
		var left := floorf(g.position.x)
		g = Rect2(left, top, ceilf(g.end.x) - left, minf(ceilf(g.end.y), h) - top)
		x0 = minf(x0, g.position.x)
		x1 = maxf(x1, g.end.x)
		if g.end.y < h - 1.0:  # hanging part: string down to the bridge (merged first, so it connects)
			grown.append(Rect2(floorf(g.get_center().x), g.end.y - 1.0, 1.0, h - g.end.y + 1.0))
		grown.append(g)
	var acc := _rect_poly(Rect2(x0, h - 1.0, x1 - x0, 1.0))
	for g: Rect2 in grown:
		var merged := Geometry2D.merge_polygons(acc, _rect_poly(g))
		# connected shapes -> one outer polygon, the rest are holes (always smaller)
		var best := 0.0
		for poly: PackedVector2Array in merged:
			var ar := absf(_poly_area(poly))
			if ar > best:
				best = ar
				acc = poly
		if not Geometry2D.is_point_in_polygon(g.get_center(), acc):
			# should never happen: fall back to the plain bounding box rather than cut off a sprite
			return _rect_poly(Rect2(x0, 0.0, x1 - x0, h))
	return acc


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _poly_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return a / 2.0


## Clickable polygon = outline of everything the desk draws + the figure (full height,
## snapped to 24 px). On Windows everything outside this polygon is NOT drawn, so it
## must cover everything visible. While XYMYX is carried or falling, only the desk counts.
func _update_passthrough(force := false) -> void:
	var rects: Array[Rect2] = []
	for r: Rect2 in _desk.outline_rects():
		rects.append(Rect2(r.position + _desk.position, r.size))
	if not _xymyx.is_airborne():
		rects.append(_figure_region())  # full height: jumps, speech bubble, emotes
	if rects == _last_rects and not force:
		return  # nothing moved far enough (called on every step while walking)
	_last_rects = rects
	var pts := _outline(rects)
	for i in pts.size():
		pts[i] *= pixel_scale
	# Only set it when the area changes: on Windows every call redraws the window,
	# which can flicker while walking inside the room.
	if pts == _last_passthrough and not force:
		return
	_last_passthrough = pts
	DisplayServer.window_set_mouse_passthrough(pts)
