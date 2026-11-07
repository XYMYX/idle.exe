class_name EventDirector
extends Node
## Plant Zufallsereignisse, hält das offene Ereignis und wendet die Wahl an.
## Kein Zwang: Wer nicht reagiert, bekommt nach TIMEOUT_SEC die Standardwahl.
## Ereignisse kommen nur, wenn der User da ist (Maus bewegt) und das Spiel nicht pausiert.

signal started(event: Dictionary)
signal resolved(event: Dictionary, choice: Dictionary, auto: bool)

const INTERVAL_MIN := Vector2(10.0, 25.0)  # Minuten zwischen Ereignissen
const TIMEOUT_SEC := 180.0                 # so lange wartet ein Ereignis auf deine Wahl
const NO_REPEAT := 3                       # die letzten n Ereignisse nicht wiederholen

## Von main gesetzt: true, wenn der User weg ist (Maus lange unbewegt).
var is_away: Callable = func() -> bool: return false

var pending := {}         # offenes Ereignis, {} = keins
var pending_left := 0.0   # Sekunden bis zur automatischen Wahl

var _next := 0.0
var _recent: Array[String] = []


func _ready() -> void:
	_schedule()


func _process(delta: float) -> void:
	if not pending.is_empty():
		pending_left -= delta
		if pending_left <= 0.0:
			choose(default_index(pending), true)
		return
	if Game.paused or is_away.call():
		return  # Zeit läuft nicht, solange niemand da ist
	_next -= delta
	if _next <= 0.0:
		trigger()


## Sofort ein Ereignis starten (zufällig oder per id, z. B. zum Testen).
func trigger(id := "") -> void:
	if not pending.is_empty():
		return
	var ev := EventData.get_event(id) if id != "" else _pick()
	_schedule()
	if ev.is_empty():
		return
	pending = ev
	pending_left = TIMEOUT_SEC
	_recent.push_front(ev["id"])
	if _recent.size() > NO_REPEAT:
		_recent.resize(NO_REPEAT)
	started.emit(ev)


## Wahl i anwenden. auto = von selbst nach Ablauf der Zeit.
func choose(i: int, auto := false) -> void:
	if pending.is_empty():
		return
	var ev := pending
	var c: Dictionary = ev["choices"][i]
	if not choice_available(c):
		if not auto:
			return
		c = {"label": "verpasst"}  # nichts wählbar: Ereignis verstreicht ohne Wirkung
	if c.has("cost_min") and not Game.spend(cost_of(c)):
		return
	if c.has("gain_min"):
		Game.earn(gain_of(c))
	for b: Dictionary in c.get("buffs", []):
		Game.add_buff(b["target"], b["mult"], float(b["min"]) * 60.0, ev["title"])
	Game.log_event("%s: %s%s" % [ev["title"], c["label"], " (automatisch)" if auto else ""])
	pending = {}
	resolved.emit(ev, c, auto)


## Wahl möglich? (Voraussetzungen erfüllt und genug Geld)
func choice_available(c: Dictionary) -> bool:
	return choice_problem(c) == ""


## Grund, warum eine Wahl gesperrt ist, sonst "".
func choice_problem(c: Dictionary) -> String:
	for req: String in c.get("requires", []):
		if not Game.has(req):
			return "Benötigt: " + Economy.name_of(req)
	if c.has("cost_min") and Game.money < cost_of(c):
		return "Zu wenig Geld"
	return ""


func cost_of(c: Dictionary) -> float:
	return Game.base_income(c.get("base", "total")) * 60.0 * float(c.get("cost_min", 0.0))


func gain_of(c: Dictionary) -> float:
	return Game.base_income(c.get("base", "total")) * 60.0 * float(c.get("gain_min", 0.0))


## Standardwahl; ist sie gesperrt, die letzte freie Wahl.
func default_index(ev: Dictionary) -> int:
	var choices: Array = ev["choices"]
	var d: int = ev.get("default", choices.size() - 1)
	if choice_available(choices[d]):
		return d
	for i in range(choices.size() - 1, -1, -1):
		if choice_available(choices[i]):
			return i
	return d


func _schedule() -> void:
	_next = randf_range(INTERVAL_MIN.x, INTERVAL_MIN.y) * 60.0


## Zufälliges Ereignis, das zum Spielstand passt und nicht gerade erst kam.
func _pick() -> Dictionary:
	var pool: Array = EventData.EVENTS.filter(func(e: Dictionary) -> bool:
		if _recent.has(e["id"]):
			return false
		var any: Array = e.get("requires_any", [])
		return any.is_empty() or any.any(func(id: String) -> bool: return Game.has(id)))
	return pool.pick_random() if not pool.is_empty() else {}
