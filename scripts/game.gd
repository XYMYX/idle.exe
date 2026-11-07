extends Node
## Autoload «Game»: Spielstand (Geld, Upgrade-Level), Speichern und Laden.
## Die Upgrade-Daten und die Rechnung stehen in economy.gd.

signal changed
signal bought(id: String)
signal milestone(value: float)  # total_earned erreicht 1K, 10K, 100K, ...

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const AUTOSAVE_SEC := 30.0
const OFFLINE_MAX_SEC := 8 * 3600.0

var money := 0.0         # CHF
var total_earned := 0.0
var levels := {}
var paused := false
var last_saved_at := 0.0  # Unix-Zeit des letzten Speicherns
var offline_gain := 0.0   # Geld aus der Abwesenheit (beim Start berechnet)
var offline_sec := 0.0

var buffs: Array = []      # zeitlich begrenzte Effekte: {target, mult, until, label}
var event_log: Array = []  # letzte Ereignisse: {t, text}, neuestes zuerst

const LOG_MAX := 10

var _income := {}  # Cache von Economy.income() OHNE Effekte, neu bei jedem Kauf
var _buffed_total := 0.0
var _buff_check := 0.0
var _totals := {}
var _autosave := 0.0
var _next_milestone := 1000.0


func _ready() -> void:
	for id in Economy.ids():
		levels[id] = 0
	load_game()
	_prune_buffs()
	_recalc()
	_apply_offline()
	while _next_milestone <= total_earned:  # schon erreichte Meilensteine überspringen
		_next_milestone *= 10.0


## Geld für die Zeit seit dem letzten Speichern, höchstens 8 Stunden.
## Uhr zurückgestellt (negative Zeit) = nichts.
func _apply_offline() -> void:
	if last_saved_at <= 0.0:
		return  # kein Spielstand
	offline_sec = clampf(Time.get_unix_time_from_system() - last_saved_at, 0.0, OFFLINE_MAX_SEC)
	offline_gain = income() * offline_sec
	money += offline_gain
	total_earned += offline_gain
	print("idle.exe: offline %d s -> +%s CHF" % [int(offline_sec), BigNum.format_chf(offline_gain)])


func _process(delta: float) -> void:
	if not paused:
		var gain := income() * delta
		money += gain
		total_earned += gain
		if total_earned >= _next_milestone:
			milestone.emit(_next_milestone)
			while _next_milestone <= total_earned:
				_next_milestone *= 10.0
	_buff_check += delta
	if _buff_check >= 1.0:
		_buff_check = 0.0
		if _prune_buffs():
			_apply_buffs()
			changed.emit()
	_autosave += delta
	if _autosave >= AUTOSAVE_SEC:
		_autosave = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func quit() -> void:
	save_game()
	get_tree().quit()


# --- Wirtschaft -------------------------------------------------------------

## Einkommen gesamt in CHF/s, inkl. laufender Effekte.
func income() -> float:
	return _buffed_total


## Einkommen ohne Effekte (Basis für «Minuten Einkommen» bei Ereignissen).
## part: total, code, storage, software, mining
func base_income(part := "total") -> float:
	return float(_income.get(part, _income["total"]))


## Einkommen pro Quelle: code, storage, software, mining, total.
func income_parts() -> Dictionary:
	return _income


## Summen inkl. Strom (power/power_cap) und Kühlung (heat/cool_cap).
func totals() -> Dictionary:
	return _totals


func level(id: String) -> int:
	return levels.get(id, 0)


func has(id: String) -> bool:
	return level(id) > 0


func cost(id: String) -> float:
	return Economy.cost(Economy.get_def(id), level(id))


func is_maxed(id: String) -> bool:
	return level(id) >= Economy.max_level(Economy.get_def(id))


## Fehlende Voraussetzungen (ohne Geld). Leer = kaufbar, sobald bezahlbar.
func missing(id: String) -> Array[String]:
	return Economy.missing(Economy.get_def(id), levels, _totals)


func can_buy(id: String) -> bool:
	return not is_maxed(id) and money >= cost(id) and missing(id).is_empty()


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	money -= cost(id)
	levels[id] += 1
	_recalc()
	changed.emit()
	bought.emit(id)
	save_game()
	return true


func _recalc() -> void:
	_totals = Economy.totals(levels)
	_income = Economy.income(levels)
	_apply_buffs()


# --- Effekte (Buffs) aus Ereignissen ------------------------------------------

func add_buff(target: String, mult: float, sec: float, label: String) -> void:
	buffs.append({"target": target, "mult": mult, "until": Time.get_unix_time_from_system() + sec, "label": label})
	_apply_buffs()
	changed.emit()


## Abgelaufene Effekte entfernen. true, wenn sich etwas geändert hat.
func _prune_buffs() -> bool:
	var now := Time.get_unix_time_from_system()
	var n := buffs.size()
	buffs = buffs.filter(func(b: Dictionary) -> bool: return float(b["until"]) > now)
	return buffs.size() != n


func _apply_buffs() -> void:
	var m := {"total": 1.0, "code": 1.0, "storage": 1.0, "software": 1.0, "mining": 1.0}
	for b: Dictionary in buffs:
		if m.has(b["target"]):
			m[b["target"]] *= float(b["mult"])
	_buffed_total = (_income["code"] * m["code"] + _income["storage"] * m["storage"]
		+ _income["software"] * m["software"] + _income["mining"] * m["mining"]) * m["total"]


func earn(amount: float) -> void:
	money += amount
	total_earned += amount
	changed.emit()


func spend(amount: float) -> bool:
	if money < amount:
		return false
	money -= amount
	changed.emit()
	return true


func log_event(text: String) -> void:
	event_log.push_front({"t": Time.get_unix_time_from_system(),
		"clock": Time.get_time_string_from_system().left(5), "text": text})
	if event_log.size() > LOG_MAX:
		event_log.resize(LOG_MAX)


# --- Speichern / Laden ------------------------------------------------------

func save_game() -> void:
	last_saved_at = Time.get_unix_time_from_system()
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"total_earned": total_earned,
		"levels": levels,
		"saved_at": last_saved_at,
		"buffs": buffs,
		"event_log": event_log,
	}
	# Erst in eine Temp-Datei schreiben, dann umbenennen: ein Absturz
	# mitten im Schreiben zerstört so nicht den alten Spielstand.
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(_abs(tmp), _abs(SAVE_PATH))
	if err != OK:
		push_error("Speichern (Umbenennen) fehlgeschlagen: %s" % error_string(err))


func load_game() -> void:
	var path := SAVE_PATH
	if not FileAccess.file_exists(path):
		if not FileAccess.file_exists(SAVE_PATH + ".tmp"):
			return  # erster Start
		path = SAVE_PATH + ".tmp"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Spielstand defekt, Kopie unter user://save.bad.json, starte neu.")
		DirAccess.copy_absolute(_abs(path), _abs("user://save.bad.json"))
		return
	# Version 1 hiess die Währung «commits»: 1:1 in CHF übernehmen.
	money = maxf(0.0, float(data.get("money", data.get("commits", 0.0))))
	total_earned = maxf(money, float(data.get("total_earned", data.get("total_commits", 0.0))))
	last_saved_at = float(data.get("saved_at", 0.0))
	var lv: Variant = data.get("levels", {})
	if lv is Dictionary:
		for id: String in levels:
			var u := Economy.get_def(id)
			levels[id] = clampi(int(lv.get(id, 0)), 0, Economy.max_level(u))
	var b: Variant = data.get("buffs", [])
	if b is Array:
		for x: Variant in b:
			if x is Dictionary and x.has_all(["target", "mult", "until"]):
				buffs.append({"target": String(x["target"]), "mult": float(x["mult"]),
					"until": float(x["until"]), "label": String(x.get("label", ""))})
	var lg: Variant = data.get("event_log", [])
	if lg is Array:
		for x: Variant in lg:
			if x is Dictionary and x.has("text"):
				event_log.append({"t": float(x.get("t", 0.0)), "clock": String(x.get("clock", "--:--")),
					"text": String(x["text"])})
		if event_log.size() > LOG_MAX:
			event_log.resize(LOG_MAX)
	print("idle.exe: Spielstand geladen aus %s" % _abs(path))


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)
