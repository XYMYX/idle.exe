class_name EventDirector
extends Node
## Schedules random events, holds the pending event and applies the player's choice.
## No pressure: if nobody reacts, the default choice is applied after TIMEOUT_SEC.
## Events only happen while the user is present (mouse moving) and the game is not paused.

signal started(event: Dictionary)
signal resolved(event: Dictionary, choice: Dictionary, auto: bool)

const INTERVAL_MIN := Vector2(10.0, 25.0)  # minutes between events
const TIMEOUT_SEC := 180.0                 # how long an event waits for your choice
const NO_REPEAT := 3                       # don't repeat the last n events

## Set by main: true while the user is away (mouse idle for a long time).
var is_away: Callable = func() -> bool: return false

var pending := {}         # pending event, {} = none
var pending_left := 0.0   # seconds until the automatic choice

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
		return  # the timer doesn't run while nobody is there
	_next -= delta
	if _next <= 0.0:
		trigger()


## Start an event right away (random or by id, e.g. for testing).
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


## Debug: start a random fitting event right now, ignoring the no-repeat list.
func trigger_now() -> void:
	_recent.clear()
	trigger()


## Apply choice i. auto = chosen automatically after the timeout.
func choose(i: int, auto := false) -> void:
	if pending.is_empty():
		return
	var ev := pending
	var c: Dictionary = ev["choices"][i]
	if not choice_available(c):
		if not auto:
			return
		c = {"label": "missed"}  # nothing available: the event passes without effect
	if c.has("cost_min") and not Game.spend(cost_of(c)):
		return
	if c.has("gain_min"):
		Game.earn(gain_of(c))
	for b: Dictionary in c.get("buffs", []):
		var mult := float(b["mult"])
		if mult < 1.0 and Game.totals()["event_shield"] > 0.0:
			mult = 1.0 - (1.0 - mult) / 2.0  # nightly backups halve the penalty
		Game.add_buff(b["target"], mult, float(b["min"]) * 60.0, ev["title"])
	Game.log_event(ev["title"], c["label"], auto)
	Game.note_stat("events")
	pending = {}
	resolved.emit(ev, c, auto)


## Is the choice possible? (requirements met and enough money)
func choice_available(c: Dictionary) -> bool:
	return choice_problem(c) == ""


## Translated reason why a choice is locked, otherwise "".
func choice_problem(c: Dictionary) -> String:
	for req: String in c.get("requires", []):
		if not Game.has(req):
			return tr("Requires: %s") % tr(Economy.name_of(req))
	if c.has("cost_min") and Game.money < cost_of(c):
		return tr("Not enough money")
	return ""


func cost_of(c: Dictionary) -> float:
	return Game.base_income(c.get("base", "total")) * 60.0 * float(c.get("cost_min", 0.0))


func gain_of(c: Dictionary) -> float:
	return Game.base_income(c.get("base", "total")) * 60.0 * float(c.get("gain_min", 0.0)) * Game.event_gain_mult()


## Default choice; if it is locked, the last available one.
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


## Random event that fits the current game state and didn't just happen.
func _pick() -> Dictionary:
	var pool: Array = EventData.EVENTS.filter(func(e: Dictionary) -> bool:
		if _recent.has(e["id"]):
			return false
		var any: Array = e.get("requires_any", [])
		return any.is_empty() or any.any(func(id: String) -> bool: return Game.has(id)))
	return pool.pick_random() if not pool.is_empty() else {}
