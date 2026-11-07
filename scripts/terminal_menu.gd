class_name TerminalMenu
extends PopupPanel
## Upgrade terminal: categories on the left, lines or upgrade tiers on the right.
## Per line: bought tiers collapsed, plus the current tier and the next two.
## Fully usable with the mouse. Closes on a click outside or Esc.
## Also: «! Event» (only while one is pending) and «Log» in the category list.
## All texts go through tr() (English source strings, German in i18n/translations.csv).
##
## Rows are only rebuilt when their content changes (signature comparison),
## otherwise the hover flickers and it wastes CPU.

const REFRESH_SEC := 0.25
const COLS := 76        # width in characters
const ROWS := 28        # height in lines
const CAT_COLS := 20
const SHOW_NEXT := 3    # current + next two tiers

const C_TEXT := Color.WHITE
const C_DIM := Color(1, 1, 1, 0.45)  # bought / secondary info
const C_OK := Color("#6fdc6f")       # affordable
const C_WARN := Color("#e8c547")     # requirement missing

const CAT_EVENT := "!event"
const CAT_LOG := "!log"

var hidden_msec := 0  # time of closing (prevents immediate reopening)

var _fs := 14
var _money: Label
var _income: Label
var _capacity: Label
var _effects: Label
var _cats_title: Label
var _countdown: Label  # only in the event view, otherwise null
var _events: EventDirector
var _cat_box: VBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _btn_afford: Button
var _btn_next: Button
var _btn_back: Button

var _cat := "hardware"
var _line := ""
var _afford_mode := false
var _expanded := {}  # "cat/line" -> true
var _cat_sig := ""
var _body_sig := ""
var _nav_sig := ""
var _anchor := Vector2i.ZERO
var _refresh := 0.0


func setup(pixel_scale: int, events: EventDirector) -> void:
	_events = events
	_events.resolved.connect(func(_e: Dictionary, _c: Dictionary, _a: bool) -> void:
		if _cat == CAT_EVENT:
			_cat = CAT_LOG  # after the choice, show the outcome in the log
		_refresh_all())
	_events.started.connect(func(_e: Dictionary) -> void: _refresh_all())
	_fs = roundi(14.0 * pixel_scale / 3.0)  # 14 px at 100 %
	theme = _make_theme(_fs, maxi(1, roundi(pixel_scale / 3.0)))
	_build_ui()
	popup_hide.connect(func() -> void: hidden_msec = Time.get_ticks_msec())
	Game.changed.connect(_refresh_all)


## Language switched: rebuild everything with the new texts.
func refresh_language() -> void:
	_cat_sig = ""
	_body_sig = ""
	_refresh_all()


## Opens the pending event directly.
func open_event(anchor: Vector2i) -> void:
	_cat = CAT_EVENT
	_afford_mode = false
	if visible:
		_refresh_all()
	else:
		open_at(anchor)


## Opens the terminal so that its bottom-right corner is at anchor.
func open_at(anchor: Vector2i) -> void:
	_anchor = anchor
	_refresh_all()
	var s := Vector2i(get_contents_minimum_size())
	popup(Rect2i(Vector2i(maxi(0, _anchor.x - s.x), maxi(0, _anchor.y - s.y)), s))


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_SEC
		_refresh_all()


# --- Building -------------------------------------------------------------------

func _build_ui() -> void:
	var font: Font = theme.default_font
	var cw := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
	var lh := font.get_height(_fs)

	var root := _vbox()
	root.custom_minimum_size = Vector2(cw * COLS, lh * ROWS)
	add_child(root)

	root.add_child(_label("XYMYX OS // UPGRADE TERMINAL"))
	root.add_child(_rule())
	var head := HBoxContainer.new()
	_money = _label("")
	_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_income = _label("")
	head.add_child(_money)
	head.add_child(_income)
	root.add_child(head)
	_capacity = _label("", C_DIM)
	root.add_child(_capacity)
	_effects = _label("", C_OK, true)
	root.add_child(_effects)
	root.add_child(_rule())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(cw))
	root.add_child(body)

	var left := _vbox()
	left.custom_minimum_size.x = cw * CAT_COLS
	_cats_title = _label("", C_DIM)
	left.add_child(_cats_title)
	_cat_box = _vbox()
	left.add_child(_cat_box)
	body.add_child(left)

	var vline := ColorRect.new()
	vline.color = C_DIM
	vline.custom_minimum_size.x = 1
	body.add_child(vline)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content = _vbox()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	body.add_child(_scroll)

	root.add_child(_rule())
	var foot := HBoxContainer.new()
	_btn_afford = _button("", C_TEXT, _toggle_afford)
	foot.add_child(_btn_afford)
	_btn_next = _button("", C_TEXT, _goto_next)
	foot.add_child(_btn_next)
	_btn_back = _button("", C_TEXT, _go_back)
	foot.add_child(_btn_back)
	root.add_child(foot)


# --- Refreshing -----------------------------------------------------------------

func _refresh_all() -> void:
	_money.text = tr("Money: %s CHF") % BigNum.format_chf(Game.money)
	_income.text = tr("Income: %s CHF/s") % BigNum.format_chf(Game.income())
	var t := Game.totals()
	_capacity.text = tr("Power %s / %s kW · Cooling %s / %s") % [
		Economy._num(t["power"]), Economy._num(t["power_cap"]),
		Economy._num(t["heat"]), Economy._num(t["cool_cap"])] + (tr("  [paused]") if Game.paused else "")
	_effects.text = _effects_text()
	_effects.visible = _effects.text != ""

	_cats_title.text = tr("CATEGORIES")
	_btn_afford.text = tr("[Show all]") if _afford_mode else tr("[Show affordable]")
	_btn_next.text = tr("[Next upgrade]")
	_btn_back.text = tr("[Back]")
	_btn_back.disabled = not (_afford_mode or (_line != "" and Economy.lines(_cat).size() > 1))

	var cats := _cat_rows()
	var sig := str(cats)
	if sig != _cat_sig:
		_cat_sig = sig
		_render_cats(cats)

	var rows := _body_rows()
	var nav := "%s|%s|%s" % [_afford_mode, _cat, _line]
	sig = nav + str(_expanded) + str(rows)
	if sig != _body_sig:
		_body_sig = sig
		_render_body(rows)
		if nav != _nav_sig:
			_nav_sig = nav
			_scroll.scroll_vertical = 0
	# Event countdown: change the text in place (no rebuild, no hover flicker)
	if _countdown and is_instance_valid(_countdown) and not _events.pending.is_empty():
		var d: Dictionary = _events.pending["choices"][_events.default_index(_events.pending)]
		_countdown.text = tr("No choice in %s: %s") % [_mmss(_events.pending_left), tr(d["label"])]


# --- Model: what is shown (plain data, easy to compare) ------------------------

func _cat_rows() -> Array:
	var rows := []
	for c: Dictionary in Economy.CATEGORIES:
		var id: String = c["id"]
		var afford := false
		for u: Dictionary in Economy.UPGRADES:
			if u["cat"] == id and Game.can_buy(u["id"]):
				afford = true
				break
		rows.append({"id": id, "name": tr(c["name"]), "sel": id == _cat and not _afford_mode,
			"locked": not Economy.category_unlocked(id, Game.levels), "afford": afford})
	if not _events.pending.is_empty():
		rows.push_front({"id": CAT_EVENT, "name": tr("! Event"), "sel": _cat == CAT_EVENT and not _afford_mode,
			"locked": false, "afford": false, "special": true})
	rows.append({"id": CAT_LOG, "name": tr("Log"), "sel": _cat == CAT_LOG and not _afford_mode,
		"locked": false, "afford": false, "special": true})
	return rows


func _body_rows() -> Array:
	var rows := []
	if not _afford_mode and _cat == CAT_EVENT:
		return _event_rows()
	if not _afford_mode and _cat == CAT_LOG:
		return _log_rows()
	if _afford_mode:
		rows.append({"t": "title", "text": tr("AFFORDABLE")})
		var ids: Array = Economy.ids().filter(func(id: String) -> bool: return Game.can_buy(id))
		ids.sort_custom(func(a: String, b: String) -> bool: return Game.cost(a) < Game.cost(b))
		if ids.is_empty():
			rows.append({"t": "text", "text": tr("Nothing is affordable right now."), "c": C_DIM})
		for id: String in ids:
			var u := Economy.get_def(id)
			rows.append(_entry_row(id, "%s / %s" % [tr(Economy.get_category(u["cat"])["name"]), tr(u["line"])]))
		return rows

	var cat := Economy.get_category(_cat)
	var cat_name := tr(cat["name"]).to_upper()
	var lines := Economy.lines(_cat)
	if not Economy.category_unlocked(_cat, Game.levels):
		rows.append({"t": "title", "text": tr("%s  [LOCKED]") % cat_name})
		var names: Array[String] = []
		for req: String in cat["requires"]:
			if not Game.has(req):
				names.append(tr(Economy.name_of(req)))
		rows.append({"t": "text", "text": tr("Requires: %s") % " + ".join(names), "c": C_WARN})
		return rows

	# Several lines: choose one first (e.g. Hardware -> CPU, RAM, GPU ...)
	if lines.size() > 1 and _line == "":
		rows.append({"t": "title", "text": cat_name})
		for line in lines:
			rows.append(_line_row(line))
		return rows

	var line: String = lines[0] if lines.size() == 1 else _line
	var title := cat_name
	if lines.size() > 1:
		title += " / " + tr(line).to_upper()
	rows.append({"t": "title", "text": title})

	var items := Economy.line_items(_cat, line)
	var bought: Array[String] = []
	var open: Array[String] = []
	for u: Dictionary in items:
		var id: String = u["id"]
		if Economy.max_level(u) == 1 and Game.has(id):
			bought.append(id)
		else:
			open.append(id)
	var key := _cat + "/" + line
	if not bought.is_empty():
		var is_open: bool = _expanded.get(key, false)
		rows.append({"t": "toggle", "key": key,
			"text": (tr("[-] hide bought") if is_open else tr("[+] show %d bought") % bought.size())})
		if is_open:
			for id in bought:
				rows.append(_entry_row(id))
	for i in mini(SHOW_NEXT, open.size()):
		rows.append(_entry_row(open[i]))
	if open.size() > SHOW_NEXT:
		rows.append({"t": "text", "text": tr("... %d more tiers") % (open.size() - SHOW_NEXT), "c": C_DIM})
	if open.is_empty():
		rows.append({"t": "text", "text": tr("All tiers bought."), "c": C_DIM})
	return rows


func _line_row(line: String) -> Dictionary:
	var items := Economy.line_items(_cat, line)
	var afford := false
	var done := 0
	var all_done := true
	var summary := ""
	for u: Dictionary in items:
		var id: String = u["id"]
		afford = afford or Game.can_buy(id)
		if Game.is_maxed(id):
			done += 1
		else:
			all_done = false
		if Economy.max_level(u) > 1:
			summary = "lvl %d/%d" % [Game.level(id), Economy.max_level(u)]
	if summary == "":
		summary = "%d/%d" % [done, items.size()]
	var c := C_OK if afford else (C_DIM if all_done else C_TEXT)
	return {"t": "line", "line": line, "c": c,
		"text": "> %s %s%s" % [tr(line).rpad(18), summary.rpad(10), "*" if afford else ""]}


## One upgrade entry. sub = optional origin line (in affordable mode).
func _entry_row(id: String, sub := "") -> Dictionary:
	var u := Economy.get_def(id)
	var maxl := Economy.max_level(u)
	var title := tr(u["name"])
	if maxl > 1:
		title += "  (lvl %d/%d)" % [Game.level(id), maxl]
	var state := "buy"
	var miss: Array[String] = []
	if Game.is_maxed(id):
		state = "bought"
	else:
		miss = Game.missing(id)
		if not miss.is_empty():
			state = "locked"
		elif Game.money < Game.cost(id):
			state = "poor"
	return {"t": "entry", "id": id, "name": title, "state": state, "sub": sub,
		"cost": "" if state == "bought" else BigNum.format_chf(Game.cost(id)),
		"fx": Economy.effect_text(u), "miss": miss}


# --- Rendering ------------------------------------------------------------------

func _render_cats(rows: Array) -> void:
	_clear(_cat_box)
	for r: Dictionary in rows:
		var text: String = (">" if r["sel"] else " ") + " " + String(r["name"]).rpad(10)
		var c := C_TEXT
		if r.get("special", false) and r["id"] == CAT_EVENT:
			c = C_WARN
		elif r["locked"]:
			text += tr("locked")
			c = C_DIM
		elif r["afford"]:
			text += "*"
			c = C_OK
		_cat_box.add_child(_button(text, c, _select_cat.bind(r["id"])))


func _render_body(rows: Array) -> void:
	_clear(_content)
	_countdown = null
	for r: Dictionary in rows:
		match r["t"]:
			"title":
				_content.add_child(_label(r["text"], C_DIM))
			"text":
				_content.add_child(_label(r["text"], r["c"], true))
			"line":
				_content.add_child(_button(r["text"], r["c"], _select_line.bind(r["line"])))
			"toggle":
				_content.add_child(_button(r["text"], C_DIM, _toggle_expand.bind(r["key"])))
			"entry":
				_render_entry(r)
			"choice":
				_render_choice(r)
			"countdown":
				_countdown = _label("", C_DIM)
				_content.add_child(_countdown)


func _render_entry(r: Dictionary) -> void:
	_content.add_child(_label(" "))
	var row := HBoxContainer.new()
	var bought: bool = r["state"] == "bought"
	var name_lbl := _label(r["name"], C_DIM if bought else C_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	match r["state"]:
		"buy":
			row.add_child(_button(tr("[BUY]"), C_OK, _buy.bind(r["id"])))
		"bought":
			row.add_child(_label(tr("[BOUGHT]") + " ", C_DIM))
		"locked":
			row.add_child(_label(tr("[LOCKED]") + " ", C_WARN))
		"poor":
			row.add_child(_label(tr("[TOO EXPENSIVE]") + " ", C_DIM))
	_content.add_child(row)
	if r["sub"] != "":
		_content.add_child(_label("  " + r["sub"], C_DIM))
	if not bought:
		_content.add_child(_label("  " + tr("Cost: %s CHF") % r["cost"]))
	_content.add_child(_label("  " + tr("Effect: %s") % r["fx"], C_DIM if bought else C_TEXT, true))
	if not r["miss"].is_empty():
		_content.add_child(_label("  " + tr("Requires: %s") % " + ".join(r["miss"]), C_WARN, true))


# --- Events, log, effects -------------------------------------------------------

func _event_rows() -> Array:
	var rows := []
	var ev := _events.pending
	if ev.is_empty():
		rows.append({"t": "title", "text": tr("EVENT")})
		rows.append({"t": "text", "text": tr("No event is pending right now."), "c": C_DIM})
		return rows
	rows.append({"t": "title", "text": tr("EVENT: %s") % tr(ev["title"]).to_upper()})
	rows.append({"t": "text", "text": tr(ev["text"]), "c": C_TEXT})
	var d := _events.default_index(ev)
	var choices: Array = ev["choices"]
	for i in choices.size():
		var c: Dictionary = choices[i]
		rows.append({"t": "choice", "i": i, "label": tr(c["label"]), "info": _choice_info(c),
			"problem": _events.choice_problem(c), "default": i == d})
	rows.append({"t": "text", "text": " ", "c": C_DIM})
	rows.append({"t": "countdown"})
	return rows


func _log_rows() -> Array:
	var rows := [{"t": "title", "text": tr("LOG")}]
	if Game.event_log.is_empty():
		rows.append({"t": "text", "text": tr("No events yet."), "c": C_DIM})
	for e: Dictionary in Game.event_log:
		var text: String
		if e.has("title"):
			text = "%s: %s%s" % [tr(e["title"]), tr(e["label"]), tr(" (automatic)") if e.get("auto", false) else ""]
		else:
			text = e.get("text", "")  # old save format, stored as is
		rows.append({"t": "text", "c": C_TEXT, "text": "%s  %s" % [e.get("clock", "--:--"), text]})
	return rows


func _render_choice(r: Dictionary) -> void:
	_content.add_child(_label(" "))
	var ok: bool = r["problem"] == ""
	var text := "[%d] %s%s" % [r["i"] + 1, r["label"], tr("  (default)") if r["default"] else ""]
	if ok:
		_content.add_child(_button(text, C_OK, func() -> void: _events.choose(r["i"])))
	else:
		_content.add_child(_label(text, C_DIM))
	_content.add_child(_label("    " + r["info"], C_TEXT if ok else C_DIM, true))
	if not ok:
		_content.add_child(_label("    " + r["problem"], C_WARN))


## «costs 12,000 CHF · Subscriptions x2 for 15 min» etc.
func _choice_info(c: Dictionary) -> String:
	var parts: Array[String] = []
	if c.has("cost_min"):
		parts.append(tr("costs %s CHF") % BigNum.format_chf(_events.cost_of(c)))
	if c.has("gain_min"):
		parts.append("+%s CHF" % BigNum.format_chf(_events.gain_of(c)))
	for b: Dictionary in c.get("buffs", []):
		parts.append(tr("%s %s for %d min") % [tr(EventData.TARGET_NAMES.get(b["target"], b["target"])),
			EventData.mult_text(b["mult"]), int(b["min"])])
	return " · ".join(parts) if not parts.is_empty() else tr("no effect")


## Active effects: «Effects: Subscriptions x2 (12:31) · Coding x0.9 (3:05)».
func _effects_text() -> String:
	if Game.buffs.is_empty():
		return ""
	var now := Time.get_unix_time_from_system()
	var parts: Array[String] = []
	for b: Dictionary in Game.buffs:
		parts.append("%s %s (%s)" % [tr(EventData.TARGET_NAMES.get(b["target"], b["target"])),
			EventData.mult_text(b["mult"]), _mmss(float(b["until"]) - now)])
	return tr("Effects: %s") % " · ".join(parts)


func _mmss(sec: float) -> String:
	var s := maxi(0, int(sec))
	return "%d:%02d" % [s / 60, s % 60]


# --- Actions --------------------------------------------------------------------

func _buy(id: String) -> void:
	Game.buy(id)  # triggers Game.changed -> _refresh_all


func _select_cat(id: String) -> void:
	_cat = id
	_line = ""
	_afford_mode = false
	_refresh_all()


func _select_line(line: String) -> void:
	_line = line
	_refresh_all()


func _toggle_expand(key: String) -> void:
	_expanded[key] = not _expanded.get(key, false)
	_refresh_all()


func _toggle_afford() -> void:
	_afford_mode = not _afford_mode
	_refresh_all()


## Jumps to the cheapest upgrade without missing requirements.
## One-off purchases take priority over RAM/CPU (those are almost always the cheapest).
func _goto_next() -> void:
	var best := ""
	var best_rep := ""
	for id in Economy.ids():
		if Game.is_maxed(id) or not Game.missing(id).is_empty():
			continue
		if Economy.max_level(Economy.get_def(id)) == 1:
			if best == "" or Game.cost(id) < Game.cost(best):
				best = id
		elif best_rep == "" or Game.cost(id) < Game.cost(best_rep):
			best_rep = id
	if best == "":
		best = best_rep
	if best == "":
		return
	var u := Economy.get_def(best)
	_cat = u["cat"]
	_line = u["line"]
	_afford_mode = false
	_refresh_all()


func _go_back() -> void:
	if _afford_mode:
		_afford_mode = false
	else:
		_line = ""
	_refresh_all()


# --- Building blocks ------------------------------------------------------------

func _label(text: String, c := C_TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # texts are translated in code
	l.add_theme_color_override("font_color", c)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, c: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", c)
	b.pressed.connect(cb)
	return b


func _rule() -> Label:
	var l := _label("─".repeat(COLS), C_DIM)
	l.clip_text = true
	return l


func _vbox() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	return v


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _make_theme(fs: int, border: int) -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "Monospace"])
	t.default_font = font
	t.default_font_size = fs

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color.BLACK
	panel.border_color = Color.WHITE
	panel.set_border_width_all(border)
	panel.set_content_margin_all(fs * 0.6)
	t.set_stylebox("panel", "PopupPanel", panel)

	# Buttons look like text lines, hover = inverted (black on white)
	var pad := fs * 0.1
	var plain := StyleBoxEmpty.new()
	plain.set_content_margin_all(pad)
	var inverted := StyleBoxFlat.new()
	inverted.bg_color = Color.WHITE
	inverted.set_content_margin_all(pad)
	for s in ["normal", "disabled", "focus"]:
		t.set_stylebox(s, "Button", plain)
	for s in ["hover", "pressed", "hover_pressed"]:
		t.set_stylebox(s, "Button", inverted)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.25))
	for c in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color.BLACK)
	return t
