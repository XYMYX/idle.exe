class_name TerminalMenu
extends PopupPanel
## Upgrade terminal: categories on the left, lines or upgrade tiers on the right.
## Per line: bought tiers collapsed, plus the current tier and the next two.
## Fully usable with the mouse. Closes on a click outside or Esc.
## Also: «! Event» (only while one is pending), «Contracts» and «Log» in the category list.
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
const CAT_CONTRACTS := "!contracts"
const CAT_CTF := "!ctf"
const CAT_COMPANY := "!company"
const CAT_SKILLS := "!skills"
const CAT_RESEARCH := "!research"
const CAT_ACQ := "!acquisitions"
const CAT_PET := "!cat"
const CAT_SETTINGS := "!settings"
const CAT_STATS := "!stats"
const CAT_SYSTEM := "!system"
## Settings view: key -> [label, [option texts in the order of Settings.OPTIONS]]
const SETTING_ROWS := [
	["scale", "Size", ["auto", "1x", "2x", "3x", "4x"]],
	["monitor", "Monitor", ["main", "1", "2", "3"]],
	["mouse_reactions", "Mouse reactions", ["on", "off"]],
	["sleep_min", "Fall asleep after", ["5 min", "10 min", "20 min", "never"]],
	["events", "Events", ["off", "rarely", "normal", "often"]],
	["show_cat", "Show pets", ["on", "off"]],
	["max_fps", "Max. FPS", ["10", "20"]],
	["system_status", "System status", ["off", "on"]],
	["hide_fullscreen", "Hide during fullscreen", ["on", "off"]],
	["taskbar", "Taskbar entry", ["off", "on"]],
]
const SELL_CONFIRM_SEC := 5.0  # second click must come within this time
const BAR_LEN := 20  # progress bar width in characters

var hidden_msec := 0  # time of closing (prevents immediate reopening)

var _fs := 14
var _money: Label
var _income: Label
var _capacity: Label
var _effects: Label
var _cats_title: Label
var _countdown: Label  # only in the event view, otherwise null
var _contract_labels := {}  # active index -> progress Label (contracts view, updated in place)
var _next_offer_label: Label
var _events: EventDirector
var _cat_box: VBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _btn_afford: Button
var _btn_next: Button
var _btn_back: Button
var _btn_oc: Button
var _btn_settings: Button
var _next_spec := ""           # specialization chosen for the next run
var _sell_armed_until := 0     # ticks (ms) until the confirm button is active
var _live_labels := {}         # key -> Label whose text changes every refresh (no rebuild)
var _sys: SystemStatus         # helper reader for the «System status» view (opt-in)

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
	_sys = SystemStatus.new()
	add_child(_sys)
	popup_hide.connect(func() -> void:
		hidden_msec = Time.get_ticks_msec()
		_sys.stop())  # the helper only runs while the view is open
	Game.changed.connect(_refresh_all)
	Settings.changed.connect(func(_k: String) -> void: _refresh_all())


## Language switched: rebuild everything with the new texts.
func refresh_language() -> void:
	_cat_sig = ""
	_body_sig = ""
	_refresh_all()


## Opens the «System status» view directly (right-click menu).
func open_system(anchor: Vector2i) -> void:
	_cat = CAT_SYSTEM
	_afford_mode = false
	if visible:
		_refresh_all()
	else:
		open_at(anchor)


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

	# Title bar: name on the left, settings in the top right corner (not in the category list)
	var title_row := HBoxContainer.new()
	var title := _label("XYMYX OS // UPGRADE TERMINAL")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_btn_settings = _button("", C_TEXT, func() -> void:
		_cat = CAT_SETTINGS if _cat != CAT_SETTINGS else "hardware"
		_afford_mode = false
		_refresh_all())
	title_row.add_child(_btn_settings)
	root.add_child(title_row)
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
	# Scrollable: with all stages there are more categories than fit in the window
	var cat_scroll := ScrollContainer.new()
	cat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_scroll.add_child(_cat_box)
	left.add_child(cat_scroll)
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
	_btn_oc = _button("", C_TEXT, func() -> void: Game.set_overclock(not Game.overclock))
	foot.add_child(_btn_oc)
	root.add_child(foot)


# --- Refreshing -----------------------------------------------------------------

func _refresh_all() -> void:
	_money.text = tr("Money: %s CHF") % BigNum.format_chf(Game.money)
	_income.text = tr("Income: %s CHF/s") % BigNum.format_chf(Game.income())
	var t := Game.totals()
	_capacity.text = tr("Power %s / %s kW · Cooling %s / %s") % [
		Economy._num(t["power"]), Economy._num(t["power_cap"]),
		Economy._num(t["heat"]), Economy._num(t["cool_cap"])] + _overclock_text() \
		+ (tr(" · RAM %s / %s GB") % [Economy._num(t["ram"]), Economy._num(t["ram_cap"])] if t["ram_cap"] > 0.0 else "") \
		+ (tr("  [paused]") if Game.paused else "")
	_effects.text = _effects_text()
	_effects.visible = _effects.text != ""

	_cats_title.text = tr("CATEGORIES")
	_btn_afford.text = tr("[Show all]") if _afford_mode else tr("[Show affordable]")
	_btn_next.text = tr("[Next upgrade]")
	_btn_settings.text = tr("[Settings]")
	_btn_settings.add_theme_color_override("font_color", C_OK if _cat == CAT_SETTINGS else C_TEXT)
	_btn_back.text = tr("[Back]")
	_btn_oc.text = tr("[Overclock: ON]") if Game.overclock else tr("[Overclock: OFF]")
	_btn_oc.add_theme_color_override("font_color", C_OK if Game.overclock else C_TEXT)
	_btn_back.disabled = not (_afford_mode or (_line != "" and Economy.lines(_cat).size() > 1))

	var cats := _cat_rows()
	var sig := str(cats)
	if sig != _cat_sig:
		_cat_sig = sig
		_render_cats(cats)

	if _cat != CAT_SYSTEM or _afford_mode or not visible:
		_sys.stop()  # only runs while the «System status» view is shown
	var rows := _body_rows()
	var nav := "%s|%s|%s" % [_afford_mode, _cat, _line]
	sig = nav + str(_expanded) + str(rows)
	if sig != _body_sig:
		_body_sig = sig
		_render_body(rows)
		if nav != _nav_sig:
			_nav_sig = nav
			_scroll.scroll_vertical = 0
	_update_contract_labels()
	_update_live_labels()
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
			"locked": not Economy.category_unlocked(id, Game.levels, Game.skills), "afford": afford})
	if not _events.pending.is_empty():
		rows.push_front({"id": CAT_EVENT, "name": tr("! Event"), "sel": _cat == CAT_EVENT and not _afford_mode,
			"locked": false, "afford": false, "special": true})
	var ct: Contracts = Game.contracts
	var contracts_ready: bool = ct.finished_count() > 0 or (not ct.offers.is_empty() and ct.free_slots(Game.levels) > 0)
	rows.insert(1 if not _events.pending.is_empty() else 0, {"id": CAT_CONTRACTS, "name": tr("Contracts"),
		"sel": _cat == CAT_CONTRACTS and not _afford_mode, "locked": false, "afford": contracts_ready, "special": true})
	rows.append({"id": CAT_SKILLS, "name": tr("Training"), "sel": _cat == CAT_SKILLS and not _afford_mode,
		"locked": false, "afford": false, "special": true})
	var research_ready := Game.research_active.is_empty() and ResearchData.PROJECTS.any(
		func(p: Dictionary) -> bool: return Game.research_problem(p["id"]) == "")
	rows.append({"id": CAT_RESEARCH, "name": tr("Research"), "sel": _cat == CAT_RESEARCH and not _afford_mode,
		"locked": false, "afford": research_ready, "special": true})
	var acq_ready := AcquisitionData.COMPANIES.any(
		func(c: Dictionary) -> bool: return Game.acquisition_problem(c["id"]) == "")
	rows.append({"id": CAT_ACQ, "name": tr("Acquisitions"), "sel": _cat == CAT_ACQ and not _afford_mode,
		"locked": false, "afford": acq_ready, "special": true})
	rows.append({"id": CAT_PET, "name": tr("Pets"), "sel": _cat == CAT_PET and not _afford_mode,
		"locked": false, "afford": PetData.PETS.any(func(pd: Dictionary) -> bool: return Game.can_adopt_pet(pd["id"])),
		"special": true})
	rows.append({"id": CAT_STATS, "name": tr("Stats"), "sel": _cat == CAT_STATS and not _afford_mode,
		"locked": false, "afford": false, "special": true})
	if Settings.get_value("system_status"):
		rows.append({"id": CAT_SYSTEM, "name": tr("System status"), "sel": _cat == CAT_SYSTEM and not _afford_mode,
			"locked": false, "afford": false, "special": true})
	rows.append({"id": CAT_COMPANY, "name": tr("Company"), "sel": _cat == CAT_COMPANY and not _afford_mode,
		"locked": false, "afford": Game.can_sell(), "special": true})
	rows.append({"id": CAT_CTF, "name": tr("CTF"), "sel": _cat == CAT_CTF and not _afford_mode,
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
	if not _afford_mode and _cat == CAT_CONTRACTS:
		return _contract_rows()
	if not _afford_mode and _cat == CAT_CTF:
		return _ctf_rows()
	if not _afford_mode and _cat == CAT_COMPANY:
		return _company_rows()
	if not _afford_mode and _cat == CAT_SKILLS:
		return _skill_rows()
	if not _afford_mode and _cat == CAT_RESEARCH:
		return _research_rows()
	if not _afford_mode and _cat == CAT_ACQ:
		return _acq_rows()
	if not _afford_mode and _cat == CAT_PET:
		return _pet_rows()
	if not _afford_mode and _cat == CAT_SETTINGS:
		return _settings_rows()
	if not _afford_mode and _cat == CAT_STATS:
		return _stats_rows()
	if not _afford_mode and _cat == CAT_SYSTEM:
		return _system_rows()
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
	if not Economy.category_unlocked(_cat, Game.levels, Game.skills):
		rows.append({"t": "title", "text": tr("%s  [LOCKED]") % cat_name})
		var names: Array[String] = []
		for req: String in cat["requires"]:
			if not Game.has(req):
				names.append(tr(Economy.name_of(req)))
		if not Economy._skill_ok(cat, Game.skills):
			names.append(Economy.skill_req_text(cat))
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
			summary = "lvl %d/%d" % [Game.level(id), Game.max_level(id)]
	if summary == "":
		summary = "%d/%d" % [done, items.size()]
	var c := C_OK if afford else (C_DIM if all_done else C_TEXT)
	return {"t": "line", "line": line, "c": c,
		"text": "> %s %s%s" % [tr(line).rpad(18), summary.rpad(10), "*" if afford else ""]}


## One upgrade entry. sub = optional origin line (in affordable mode).
func _entry_row(id: String, sub := "") -> Dictionary:
	var u := Economy.get_def(id)
	var maxl := Game.max_level(id)
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
	_live_labels = {}
	_contract_labels = {}
	_next_offer_label = null
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
			"contract":
				_render_contract(r)
			"offer":
				_render_offer(r)
			"quality":
				_render_quality(r["q"])
			"spec":
				_render_spec(r)
			"project":
				_render_project(r)
			"company":
				_render_company(r)
			"setting":
				_render_setting(r)
			"adopt":
				var row := HBoxContainer.new()
				var pid: String = r["id"]
				var lbl := _label(tr(PetData.get_pet(pid)["name"]), C_DIM if r["owned"] else C_TEXT)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(lbl)
				if r["owned"]:
					row.add_child(_label(tr("[OWNED]") + " ", C_OK))
				elif r["can"]:
					row.add_child(_button(tr("[ADOPT]"), C_OK, func() -> void: Game.adopt_pet(pid)))
				else:
					row.add_child(_label(tr("[LOCKED]") + " ", C_DIM))
				_content.add_child(row)
			"live":
				var lbl := _label("", r["c"])
				_live_labels[r["key"]] = lbl
				_content.add_child(lbl)
			"sell":
				_render_sell(r)
			"next_offer":
				_next_offer_label = _label("", C_DIM)
				_content.add_child(_next_offer_label)


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


# --- Contracts (stage 5a) -------------------------------------------------------

## Rows for the contracts view. Progress texts are NOT part of the rows (they change every
## refresh); they are written into labels in place by _update_contract_labels().
func _contract_rows() -> Array:
	var ct: Contracts = Game.contracts
	var rows := []
	rows.append({"t": "title", "text": tr("CONTRACTS  ·  slots %d/%d") % [ct.active.size(), Contracts.slots(Game.levels, ct.bonus_slots)]})
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("Running contracts take a share of the coding income and pay it back multiplied.")})
	rows.append({"t": "text", "c": C_OK, "text": _stars_text()})
	rows.append({"t": "quality", "q": Game.contract_quality})
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("Normal: best with 1–2 contracts · Thorough: best with 3–4 · Fast: money sooner")})
	if ct.active.is_empty():
		rows.append({"t": "text", "text": tr("No running contracts."), "c": C_DIM})
	for i in ct.active.size():
		var c: Dictionary = ct.active[i]
		rows.append({"t": "contract", "i": i, "title": _contract_title(c),
			"type": tr(ContractData.type_name(c["type"])),
			"finished": Contracts.is_finished(c),
			"reward": BigNum.format_chf(Contracts.reward_of(c)) if Contracts.is_finished(c) else ""})
	rows.append({"t": "text", "text": " ", "c": C_DIM})
	rows.append({"t": "title", "text": tr("OFFERS")})
	if ct.offers.is_empty():
		rows.append({"t": "text", "text": tr("No offers right now."), "c": C_DIM})
	var free := ct.free_slots(Game.levels) > 0
	for i in ct.offers.size():
		var o: Dictionary = ct.offers[i]
		var alone_sec: float = o["work"] / maxf(Contracts.share(1) * Game.code_income(), 0.001)
		rows.append({"t": "offer", "i": i, "title": _contract_title(o),
			"type": tr(ContractData.type_name(o["type"])), "can": free,
			"info": _offer_info(o, alone_sec / Game.contract_speed())})
	rows.append({"t": "next_offer"})
	return rows


## Display title: client/oss use their stored title, updates are «Desktop app v1.3».
func _contract_title(c: Dictionary) -> String:
	if c.get("kind", "client") == "update":
		return tr("%s v1.%d") % [tr(Economy.name_of(c["product"])), int(c["version"])]
	if c.get("kind", "client") == "course":
		return tr("%s (level %d)") % [tr(SkillData.get_skill(c["skill"])["course"]), int(c["level"])]
	return tr(c["title"])


## Offer info as it would be accepted with the current quality level (updates stay normal).
func _offer_info(o: Dictionary, sec: float) -> String:
	if o.get("kind", "client") == "update":
		return tr("Work ~%s · %s subscriptions +5 %% for good") % [_dur(sec), tr(Economy.name_of(o["product"]))]
	if o.get("kind", "client") == "course":
		return tr("Work ~%s · %s level %d, stays forever") % [_dur(sec), tr(SkillData.get_skill(o["skill"])["name"]), int(o["level"])]
	var q: Dictionary = Progress.QUALITY[Game.contract_quality]
	sec *= float(q["work"])
	if o.get("kind", "client") == "oss":
		return tr("Work ~%s · +%d stars (+25 %% if done within %s)") % [
			_dur(sec), int(float(o["stars"]) * float(q["stars"])), _dur(o["target_sec"])]
	return tr("Work ~%s · Reward %s CHF · +25 %% if done within %s") % [
		_dur(sec), BigNum.format_chf(float(o["reward"]) * float(q["reward"]) * Game.contract_reward_mult()
			* Game.skill_reward_mult(o.get("type", ""))),
		_dur(o["target_sec"])]


## «Quality: [Fast] [Normal] [Thorough]» – the selected one in green.
func _render_quality(selected: int) -> void:
	var row := HBoxContainer.new()
	row.add_child(_label(tr("Quality:")))
	for i in Progress.QUALITY.size():
		var q: Dictionary = Progress.QUALITY[i]
		var text := "[%s]" % tr(q["name"])
		row.add_child(_button(text, C_OK if i == selected else C_DIM, Game.set_contract_quality.bind(i)))
	_content.add_child(row)


## « · overclocked x1.3» or « · throttled x1.1 (needs 3 free cooling)», empty when off.
func _overclock_text() -> String:
	if not Game.overclock:
		return ""
	var m := Game.overclock_mult()
	if m >= Progress.OC_MULT:
		return tr(" · overclocked x%s") % EventData.mult_text(m).substr(1)
	return tr(" · throttled x%s (needs %s free cooling)") % [EventData.mult_text(m).substr(1),
		Economy._num(Game.overclock_need())]


## «★ 42 stars · Better contracts · next: Contributors at 50»
func _stars_text() -> String:
	var parts: Array[String] = [tr("★ %d stars") % int(Game.stars)]
	for t: Dictionary in Progress.reached_tiers(Game.stars):
		parts.append(tr(t["name"]))
	var nxt := Progress.next_tier(Game.stars)
	if not nxt.is_empty():
		parts.append(tr("next: %s at %d") % [tr(nxt["name"]), int(nxt["stars"])])
	return " · ".join(parts)


func _render_contract(r: Dictionary) -> void:
	_content.add_child(_label(" "))
	var row := HBoxContainer.new()
	var name_lbl := _label("%s: %s" % [r["type"], r["title"]])
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	if r["finished"]:
		row.add_child(_button(tr("[DELIVER]"), C_OK, _deliver.bind(r["i"])))
	_content.add_child(row)
	var progress := _label("", C_OK if r["finished"] else C_TEXT)
	_contract_labels[r["i"]] = progress
	_content.add_child(progress)


func _render_offer(r: Dictionary) -> void:
	_content.add_child(_label(" "))
	var row := HBoxContainer.new()
	var name_lbl := _label("%s: %s" % [r["type"], r["title"]])
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	if r["can"]:
		row.add_child(_button(tr("[ACCEPT]"), C_OK, _accept.bind(r["i"])))
	else:
		row.add_child(_label(tr("[NO FREE SLOT]") + " ", C_DIM))
	_content.add_child(row)
	_content.add_child(_label("  " + r["info"], C_TEXT if r["can"] else C_DIM, true))


## Progress bars, ETA, bonus time and «next offer» – updated in place every refresh.
func _update_contract_labels() -> void:
	var ct: Contracts = Game.contracts
	var running := ct.running_count()
	var rate := Contracts.share(running) * Game.code_income() / maxf(running, 1) * Game.contract_speed()
	for i: int in _contract_labels:
		var lbl: Label = _contract_labels[i]
		if not is_instance_valid(lbl) or i >= ct.active.size():
			continue
		var c: Dictionary = ct.active[i]
		var frac := clampf(float(c["done"]) / maxf(float(c["work"]), 0.001), 0.0, 1.0)
		var filled := int(frac * BAR_LEN)
		var bar := "[" + "#".repeat(filled) + ".".repeat(BAR_LEN - filled) + "] %3d%%" % int(frac * 100.0)
		if Contracts.is_finished(c):
			var bonus := float(c["elapsed"]) <= float(c["target_sec"])
			lbl.text = "  " + bar + "  " + (tr("done, with bonus") if bonus else tr("done"))
		else:
			var eta := (float(c["work"]) - float(c["done"])) / maxf(rate, 0.001)
			var left := float(c["target_sec"]) - float(c["elapsed"])
			var bonus_txt := tr("bonus %s") % _dur(left) if left > 0.0 else tr("no bonus")
			lbl.text = "  " + bar + "  " + tr("ETA %s") % _dur(eta) + "  " + bonus_txt
	if _next_offer_label and is_instance_valid(_next_offer_label):
		_next_offer_label.text = "" if ct.offers.size() >= Contracts.OFFER_MAX \
			else tr("Next offer in %s") % _dur(ct.next_offer_in)


## 4:05 or 1:02:03
func _dur(sec: float) -> String:
	var s := maxi(0, int(sec))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


# --- Research (stage 12) -------------------------------------------------------------

func _research_rows() -> Array:
	var rows := [{"t": "title", "text": tr("RESEARCH")}]
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("One project at a time, runs in the background (also offline). Reset when the company is sold.")})
	for p: Dictionary in ResearchData.PROJECTS:
		rows.append({"t": "text", "text": " ", "c": C_DIM})
		var id: String = p["id"]
		var running: bool = Game.research_active.get("id", "") == id
		rows.append({"t": "project", "id": id, "done": Game.research_done.get(id, false), "running": running,
			"problem": Game.research_problem(id)})
		if running:
			rows.append({"t": "live", "key": "research", "c": C_OK})
	return rows


func _render_project(r: Dictionary) -> void:
	var p := ResearchData.get_project(r["id"])
	var row := HBoxContainer.new()
	var name_lbl := _label(tr(p["name"]), C_DIM if r["done"] else C_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	if r["done"]:
		row.add_child(_label(tr("[DONE]") + " ", C_DIM))
	elif r["running"]:
		row.add_child(_label(tr("[RUNNING]") + " ", C_OK))
	elif r["problem"] == "":
		row.add_child(_button(tr("[START]"), C_OK, func() -> void: Game.start_research(r["id"])))
	else:
		row.add_child(_label(tr("[LOCKED]") + " ", C_DIM))
	_content.add_child(row)
	_content.add_child(_label("  " + tr("Effect: %s") % tr(p["desc"]), C_DIM if r["done"] else C_TEXT))
	if not r["done"] and not r["running"]:
		_content.add_child(_label("  " + tr("Cost: %s CHF") % BigNum.format_chf(p["cost"]) + " · "
			+ tr("Duration: %s") % _dur(float(p["minutes"]) * 60.0)))
		if r["problem"] != "":
			_content.add_child(_label("  " + r["problem"], C_WARN))


# --- System status (opt-in, display only) -------------------------------------------

func _system_rows() -> Array:
	var on: bool = Settings.get_value("system_status") and visible and not _afford_mode
	if on:
		_sys.start()  # no-op while it runs
	else:
		_sys.stop()
	var rows := [{"t": "title", "text": tr("SYSTEM STATUS")}]
	if not Settings.get_value("system_status"):
		rows.append({"t": "text", "c": C_DIM, "text": tr("Switched off. Turn it on in the settings.")})
		return rows
	var info := SystemStatus.static_info()
	rows.append({"t": "text", "c": C_DIM, "text": "CPU  %s  (%d %s)" % [info["cpu_name"], info["cores"], tr("threads")]})
	if info["gpu_name"] != "":
		rows.append({"t": "text", "c": C_DIM, "text": "GPU  %s" % info["gpu_name"]})
	rows.append({"t": "text", "text": " ", "c": C_DIM})
	for key in ["sys_cpu", "sys_ram", "sys_disk", "sys_gpu", "sys_up"]:
		rows.append({"t": "live", "key": key, "c": C_TEXT})
	rows.append({"t": "live", "key": "sys_err", "c": C_WARN})
	rows.append({"t": "text", "text": " ", "c": C_DIM})
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("Display only: nothing is saved or sent. Updates once per second while this view is open.")})
	return rows


func _update_system_labels() -> void:
	if not _live_labels.has("sys_cpu") or not is_instance_valid(_live_labels["sys_cpu"]):
		return
	var v := _sys.values
	var gb := 1024.0 * 1024.0 * 1024.0
	var wait := tr("waiting for data ...")
	if v.is_empty():
		_live_labels["sys_cpu"].text = "CPU    " + wait
		for key in ["sys_ram", "sys_disk", "sys_gpu", "sys_up"]:
			_live_labels[key].text = ""
	else:
		_live_labels["sys_cpu"].text = "CPU    %s %3d %%" % [_pct_bar(float(v["cpu"])), roundi(float(v["cpu"]))]
		var ram_used := float(v["ram_used"]) / gb
		var ram_total := float(v["ram_total"]) / gb
		_live_labels["sys_ram"].text = "RAM    %s  %.1f / %.1f GB" % [
			_pct_bar(100.0 * ram_used / maxf(ram_total, 0.001)), ram_used, ram_total]
		var free := float(v["disk_free"]) / gb
		var total := float(v["disk_total"]) / gb
		_live_labels["sys_disk"].text = tr("Disk") + "   %s  " % _pct_bar(100.0 * (1.0 - free / maxf(total, 0.001))) \
			+ tr("%s free of %s") % [_size_text(free), _size_text(total)]
		var gpu := float(v["gpu"])
		var temp := int(v["gpu_temp"])
		var gpu_text := "GPU    " + ("%s %3d %%" % [_pct_bar(gpu), roundi(gpu)] if gpu >= 0.0 else tr("load unknown"))
		if temp >= 0:
			gpu_text += "  ·  %d °C" % temp
		_live_labels["sys_gpu"].text = gpu_text
		var up := int(v["uptime"])
		_live_labels["sys_up"].text = tr("Uptime") + " " + (tr("%d d ") % (up / 86400) if up >= 86400 else "") \
			+ "%d:%02d h" % [(up % 86400) / 3600, (up % 3600) / 60]
	_live_labels["sys_err"].text = tr(_sys.error) if _sys.error != "" else ""


func _pct_bar(pct: float) -> String:
	var n := clampi(roundi(pct / 100.0 * 10.0), 0, 10)
	return "[" + "#".repeat(n) + ".".repeat(10 - n) + "]"


func _size_text(gb: float) -> String:
	return "%.2f TB" % (gb / 1024.0) if gb >= 1024.0 else "%.0f GB" % gb


# --- Stats -------------------------------------------------------------------------

func _stats_rows() -> Array:
	var st: Dictionary = Game.stats
	var owned := 0
	var one_off := 0
	for u: Dictionary in Economy.UPGRADES:
		if Economy.max_level(u) == 1:
			one_off += 1
			if Game.has(u["id"]):
				owned += 1
	var flags := 0
	for f: Dictionary in FlagData.FLAGS:
		if Game.flags.get(f["id"], false):
			flags += 1
	var skill_sum := 0
	for s: Dictionary in SkillData.SKILLS:
		skill_sum += int(Game.skills.get(s["id"], 0))
	var sec := int(st.get("play_sec", 0))
	var lines := [
		[tr("Playtime"), (tr("%d d ") % (sec / 86400) if sec >= 86400 else "") + "%d:%02d h" % [(sec % 86400) / 3600, (sec % 3600) / 60]],
		[tr("Earned in total"), BigNum.format_chf(Game.total_earned) + " CHF"],
		[tr("Earned this run"), BigNum.format_chf(Game.run_earned) + " CHF"],
		[tr("Companies sold"), str(int(st.get("sales", 0)))],
		[tr("Know-how points"), str(Game.knowhow)],
		[tr("Contracts delivered"), str(int(st.get("contracts", 0)))],
		[tr("Events resolved"), str(int(st.get("events", 0)))],
		[tr("CTF flags"), "%d / %d" % [flags, FlagData.FLAGS.size()]],
		[tr("Upgrades owned"), "%d / %d" % [owned, one_off]],
		[tr("Research projects"), "%d / %d" % [Game.research_done.size(), ResearchData.PROJECTS.size()]],
		[tr("Acquisitions"), "%d / %d" % [Game.acquisitions.size(), AcquisitionData.COMPANIES.size()]],
		[tr("Skill levels"), "%d / %d" % [skill_sum, SkillData.SKILLS.size() * SkillData.MAX_LEVEL]],
		[tr("Stars"), BigNum.format(Game.stars)],
		[tr("Best combo jump"), str(int(st.get("max_combo", 0)))],
		[tr("Naps"), str(int(st.get("naps", 0)))],
	]
	if Game.cat:
		lines.append([tr("Cat petted"), str(int(st.get("pets", 0)))])
	var rows := [{"t": "title", "text": tr("STATS")}]
	for l: Array in lines:
		rows.append({"t": "text", "c": C_TEXT, "text": "%s %s" % [(l[0] + " ").rpad(24, "."), l[1]]})
	return rows


# --- Settings ----------------------------------------------------------------------

func _settings_rows() -> Array:
	var rows := [{"t": "title", "text": tr("SETTINGS")}]
	for s: Array in SETTING_ROWS:
		rows.append({"t": "setting", "key": s[0], "value": Settings.get_value(s[0])})
	rows.append({"t": "text", "text": " ", "c": C_DIM})
	rows.append({"t": "text", "c": C_DIM, "text": tr("The taskbar entry changes after a restart. The language is changed in the tray menu.")})
	rows.append({"t": "text", "c": C_DIM, "text": tr("System status (right-click XYMYX) reads CPU, RAM, disk and GPU values. Display only, nothing is saved or sent.")})
	return rows


func _render_setting(r: Dictionary) -> void:
	var def: Array = []
	for s: Array in SETTING_ROWS:
		if s[0] == r["key"]:
			def = s
	var options: Array = Settings.OPTIONS[r["key"]]["options"]
	var row := HBoxContainer.new()
	var name_lbl := _label(tr(def[1]))
	name_lbl.custom_minimum_size.x = 170
	row.add_child(name_lbl)
	for i in options.size():
		var v: Variant = options[i]
		var text := "[%s]" % tr(def[2][i])
		row.add_child(_button(text, C_OK if v == r["value"] else C_DIM, Settings.set_value.bind(r["key"], v)))
	_content.add_child(row)


# --- Cat (decoration) -----------------------------------------------------------------

func _pet_rows() -> Array:
	var rows := [{"t": "title", "text": tr("PETS")}]
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("Pure decoration, no effect on the game. Pets stay when the company is sold.")})
	for pd: Dictionary in PetData.PETS:
		rows.append({"t": "text", "text": " ", "c": C_DIM})
		rows.append({"t": "adopt", "id": pd["id"], "owned": Game.has_pet(pd["id"]), "can": Game.can_adopt_pet(pd["id"])})
		rows.append({"t": "text", "c": C_DIM if Game.has_pet(pd["id"]) else C_TEXT, "text": "  " + tr(pd["desc"])})
		if not Game.has_pet(pd["id"]):
			rows.append({"t": "text", "c": C_TEXT, "text": "  " + tr("Cost: %s CHF") % BigNum.format_chf(pd["cost"])})
		elif pd["id"] == "cat":
			rows.append({"t": "text", "c": C_DIM, "text": "  " + tr("Petted: %d times") % int(Game.stats.get("pets", 0))})
	return rows


# --- Acquisitions (stage 14) -----------------------------------------------------------

func _acq_rows() -> Array:
	var rows := [{"t": "title", "text": tr("ACQUISITIONS")}]
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("Buy other companies once, their effect lasts for this run. Reset when the company is sold.")})
	for c: Dictionary in AcquisitionData.COMPANIES:
		rows.append({"t": "text", "text": " ", "c": C_DIM})
		rows.append({"t": "company", "id": c["id"], "owned": Game.acquisitions.get(c["id"], false),
			"problem": Game.acquisition_problem(c["id"])})
	return rows


func _render_company(r: Dictionary) -> void:
	var c := AcquisitionData.get_company(r["id"])
	var row := HBoxContainer.new()
	var name_lbl := _label(c["name"] + "  (" + tr(c["kind"]) + ")", C_DIM if r["owned"] else C_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	if r["owned"]:
		row.add_child(_label(tr("[OWNED]") + " ", C_DIM))
	elif r["problem"] == "":
		row.add_child(_button(tr("[BUY]"), C_OK, func() -> void: Game.acquire(r["id"])))
	else:
		row.add_child(_label(tr("[LOCKED]") + " ", C_DIM))
	_content.add_child(row)
	_content.add_child(_label("  " + tr("Effect: %s") % tr(c["desc"]), C_DIM if r["owned"] else C_TEXT))
	if not r["owned"]:
		_content.add_child(_label("  " + tr("Cost: %s CHF") % BigNum.format_chf(c["cost"])))
		if r["problem"] != "":
			_content.add_child(_label("  " + r["problem"], C_WARN))


# --- Training (stage 10) -------------------------------------------------------------

func _skill_rows() -> Array:
	var rows := [{"t": "title", "text": tr("TRAINING")}]
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("Courses appear on the contract board. Skills stay when the company is sold.")})
	for s: Dictionary in SkillData.SKILLS:
		var lv := int(Game.skills.get(s["id"], 0))
		var bar := "[" + "#".repeat(lv) + ".".repeat(SkillData.MAX_LEVEL - lv) + "]"
		rows.append({"t": "text", "text": " ", "c": C_DIM})
		rows.append({"t": "text", "c": C_OK if lv > 0 else C_TEXT,
			"text": "%s %s %d/%d" % [tr(s["name"]).rpad(12), bar, lv, SkillData.MAX_LEVEL]})
		var fx := _skill_fx_text(s, maxi(lv, 1))
		rows.append({"t": "text", "c": C_TEXT if lv > 0 else C_DIM,
			"text": "    " + (tr("Now: %s") % _skill_fx_text(s, lv) if lv > 0 else tr("Per level: %s") % fx)})
		if s["requires"] != "" and not Game.has(s["requires"]):
			rows.append({"t": "text", "c": C_WARN,
				"text": "    " + tr("Courses after: %s") % tr(Economy.name_of(s["requires"]))})
	return rows


## «Script, Client project +20 %, Contracts +4 %» for a skill at a level.
func _skill_fx_text(s: Dictionary, lv: int) -> String:
	var parts: Array[String] = []
	if not (s["boosts"] as Array).is_empty():
		var names: Array[String] = []
		for t: String in s["boosts"]:
			names.append(tr(ContractData.type_name(t)))
		parts.append(tr("%s rewards +%d %%") % [", ".join(names), int(round(SkillData.REWARD_PER_LEVEL * 100.0 * lv))])
	var labels := {"contract_speed": "Contracts +%d %%", "net_income": "Storage+subscriptions +%d %%",
		"event_gain": "Event gains +%d %%", "security_income": "Security +%d %%"}
	for k: String in s["fx"]:
		parts.append(tr(labels[k]) % int(round(float(s["fx"][k]) * 100.0 * lv)))
	return ", ".join(parts)


# --- Company / prestige (stage 9) ----------------------------------------------------

func _company_rows() -> Array:
	if _next_spec == "":
		_next_spec = Game.specialization if Game.specialization != "" else "software"
	var rows := [{"t": "title", "text": tr("COMPANY")}]
	rows.append({"t": "live", "key": "earned", "c": C_TEXT})
	rows.append({"t": "text", "c": C_OK, "text": tr("Know-how: %d points (+%d %% on everything)") % [
		Game.knowhow, int(round(Progress.KNOWHOW_BONUS * 100.0 * Game.knowhow))]})
	var cur := tr(Progress.SPECS[Game.specialization]["name"]) if Game.specialization != "" else tr("none")
	rows.append({"t": "text", "c": C_TEXT, "text": tr("Specialization: %s") % cur})
	rows.append({"t": "text", "text": " ", "c": C_DIM})
	rows.append({"t": "title", "text": tr("SELL THE COMPANY")})
	if Game.can_sell():
		rows.append({"t": "live", "key": "points", "c": C_OK})
	else:
		rows.append({"t": "text", "c": C_WARN,
			"text": tr("Possible from %s CHF earned in this run.") % BigNum.format_chf(Progress.SELL_MIN)})
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("Kept: CTF flags and tools, stars, statistics. Reset: money, upgrades, contracts, product versions.")})
	rows.append({"t": "text", "text": " ", "c": C_DIM})
	rows.append({"t": "text", "c": C_TEXT, "text": tr("Specialization for the next run:")})
	for id: String in Progress.SPECS:
		rows.append({"t": "spec", "id": id, "sel": id == _next_spec})
	rows.append({"t": "text", "text": " ", "c": C_DIM})
	rows.append({"t": "sell", "can": Game.can_sell(), "armed": Time.get_ticks_msec() < _sell_armed_until})
	return rows


## Company numbers that change all the time, written in place (no rebuild, clicks stay safe).
func _update_live_labels() -> void:
	if _live_labels.has("earned") and is_instance_valid(_live_labels["earned"]):
		_live_labels["earned"].text = tr("Earned this run: %s CHF") % BigNum.format_chf(Game.run_earned)
	if _live_labels.has("research") and is_instance_valid(_live_labels["research"]) and not Game.research_active.is_empty():
		var ra: Dictionary = Game.research_active
		var p := ResearchData.get_project(ra["id"])
		var total: float = float(p["minutes"]) * 60.0
		var frac := clampf(1.0 - float(ra["left"]) / total, 0.0, 1.0)
		var filled := int(frac * BAR_LEN)
		_live_labels["research"].text = "  [" + "#".repeat(filled) + ".".repeat(BAR_LEN - filled) + "] %3d%%  " % int(frac * 100.0) \
			+ tr("ETA %s") % _dur(maxf(float(ra["left"]), 0.0))
	_update_system_labels()
	if _live_labels.has("points") and is_instance_valid(_live_labels["points"]):
		_live_labels["points"].text = tr("A sale now gives +%d know-how points.") % Game.sell_points()


func _render_spec(r: Dictionary) -> void:
	var spec: Dictionary = Progress.SPECS[r["id"]]
	_content.add_child(_button("%s [%s]" % [">" if r["sel"] else " ", tr(spec["name"])],
		C_OK if r["sel"] else C_TEXT, func() -> void:
			_next_spec = r["id"]
			_refresh_all()))
	_content.add_child(_label("    " + tr(spec["desc"]), C_DIM, true))


func _render_sell(r: Dictionary) -> void:
	if not r["can"]:
		_content.add_child(_label(tr("[SELL COMPANY]"), C_DIM))
	elif r["armed"]:
		_content.add_child(_button(tr("[CONFIRM: sell and start over]"), C_WARN, func() -> void:
			_sell_armed_until = 0
			Game.sell_company(_next_spec)))
	else:
		_content.add_child(_button(tr("[SELL COMPANY]"), C_OK, func() -> void:
			_sell_armed_until = Time.get_ticks_msec() + int(SELL_CONFIRM_SEC * 1000.0)
			_refresh_all()))


# --- CTF flags (stage 8a) ---------------------------------------------------------

func _ctf_rows() -> Array:
	var got := 0
	for f: Dictionary in FlagData.FLAGS:
		if Game.flags.get(f["id"], false):
			got += 1
	var rows := [{"t": "title", "text": tr("CTF  ·  %d/%d flags") % [got, FlagData.FLAGS.size()]}]
	rows.append({"t": "text", "c": C_DIM,
		"text": tr("Each flag pays once and unlocks a tool with a permanent bonus.")})
	for f: Dictionary in FlagData.FLAGS:
		rows.append({"t": "text", "text": " ", "c": C_DIM})
		var tool := "%s (%s)" % [tr(f["tool"]["name"]), _tool_fx_text(f["tool"]["fx"])]
		if Game.flags.get(f["id"], false):
			rows.append({"t": "text", "c": C_OK, "text": "[x] %s  ·  %s" % [FlagData.flag_name(f), tr(f["text"])]})
			rows.append({"t": "text", "c": C_OK, "text": "    " + tr("Tool: %s") % tool})
		else:
			var cur := Game.flag_progress(f)
			var target := Game.flag_target(f)
			var prog := ""
			if f["goal"] not in ["owns", "all_upgrades", "pet"]:
				prog = "  (%s / %s)" % [BigNum.format(minf(cur, target)), BigNum.format(target)]
			rows.append({"t": "text", "c": C_TEXT, "text": "[ ] %s  ·  %s%s" % [FlagData.flag_name(f), tr(f["text"]), prog]})
			rows.append({"t": "text", "c": C_DIM, "text": "    " + tr("Tool: %s") % tool})
	return rows


func _tool_fx_text(fx: Dictionary) -> String:
	var names := {"code_mult": "Coding %s", "net_mult": "Storage+subscriptions %s", "software_mult": "Subscriptions %s",
		"total_mult": "Income %s", "contract_reward": "Contract rewards %s", "contract_speed": "Contracts %s",
		"star_mult": "Stars %s", "event_gain": "Event gains %s"}
	var parts: Array[String] = []
	for k: String in fx:
		parts.append(tr(names.get(k, k + " %s")) % Economy._mult(float(fx[k])))
	return ", ".join(parts)


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

func _accept(i: int) -> void:
	Game.accept_contract(i)  # triggers Game.changed -> _refresh_all


func _deliver(i: int) -> void:
	Game.deliver_contract(i)


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
