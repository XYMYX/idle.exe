class_name Contracts
extends RefCounted
## Stage 5a contract logic: offers, slots, progress and delivery.
## Pure logic without UI or saving side effects, so it can be tested headless and
## driven both by the frame loop and by one big offline step.
## Not wired into the game yet (that is step 2: Game.gd income split, save version 3).
##
## Progress: running contracts divert a share of the coding income instead of it going
## to the wallet. The share grows with the number of running contracts:
## 1 → 50 %, 2 → 75 %, 3 → 87.5 %, 4 → 93.75 % (1 - 0.5^n), split equally.
## So extra slots convert more income at the higher contract rate.

const OFFER_MAX := 3
const OFFER_EVERY_SEC := 300.0   # a new offer every 5 min, up to OFFER_MAX
const BASE_SLOTS := 1
const MAX_SLOTS := 4
## Upgrades that add a slot: {id, level needed}
const SLOT_SOURCES := [{"id": "ram", "level": 25}, {"id": "workstation", "level": 1}, {"id": "rack", "level": 1}]
const BONUS_MULT := 1.25         # reward bonus when finished within target time
const MIN_WORK := 60.0           # minimum workload in CHF (very early game)

## Running contracts: {type, title, work, done, reward, target_sec, elapsed}
## A contract is finished when done >= work; it then waits for deliver().
var active: Array = []
## Offers on the board: {type, title, work, reward, target_sec}
var offers: Array = []
var next_offer_in := 0.0


# --- Slots and types --------------------------------------------------------------

static func slots(levels: Dictionary) -> int:
	var n := BASE_SLOTS
	for s: Dictionary in SLOT_SOURCES:
		if int(levels.get(s["id"], 0)) >= int(s["level"]):
			n += 1
	return mini(n, MAX_SLOTS)


func free_slots(levels: Dictionary) -> int:
	return maxi(0, slots(levels) - active.size())


static func unlocked_types(levels: Dictionary) -> Array:
	return ContractData.TYPES.filter(func(t: Dictionary) -> bool:
		return t["requires"] == "" or int(levels.get(t["requires"], 0)) > 0)


## Share of the coding income diverted with n running (unfinished) contracts.
static func share(n: int) -> float:
	return 0.0 if n <= 0 else 1.0 - pow(0.5, n)


# --- Offers -----------------------------------------------------------------------

## New offer, weighted towards the highest unlocked type. Workload scales with income.
func make_offer(levels: Dictionary, code_income: float) -> Dictionary:
	var types := unlocked_types(levels)
	if types.is_empty():
		return {}
	var total := 0
	for i in types.size():
		total += i + 1
	var r := randi() % total
	var t: Dictionary = types[0]
	for i in types.size():
		r -= i + 1
		if r < 0:
			t = types[i]
			break
	# work_min = minutes for ONE running contract at its 50 % share, so the speed bonus
	# (target_min > work_min) is reachable with a single slot; parallel contracts are slower.
	var work := maxf(MIN_WORK, code_income * share(1) * 60.0 * float(t["work_min"]))
	return {"type": t["id"], "title": (t["titles"] as Array).pick_random(), "work": work,
		"reward": work * float(t["reward_mult"]), "target_sec": float(t["target_min"]) * 60.0}


## Fill the board completely (e.g. on first start).
func fill_offers(levels: Dictionary, code_income: float) -> void:
	while offers.size() < OFFER_MAX:
		var o := make_offer(levels, code_income)
		if o.is_empty():
			return
		offers.append(o)
	next_offer_in = OFFER_EVERY_SEC


func accept(i: int, levels: Dictionary) -> bool:
	if i < 0 or i >= offers.size() or free_slots(levels) <= 0:
		return false
	var o: Dictionary = offers[i]
	offers.remove_at(i)
	active.append({"type": o["type"], "title": o["title"], "work": o["work"], "done": 0.0,
		"reward": o["reward"], "target_sec": o["target_sec"], "elapsed": 0.0})
	return true


# --- Progress ---------------------------------------------------------------------

static func is_finished(c: Dictionary) -> bool:
	return float(c["done"]) >= float(c["work"])


func running_count() -> int:
	return active.filter(func(c: Dictionary) -> bool: return not is_finished(c)).size()


func finished_count() -> int:
	return active.size() - running_count()


## Advance by delta seconds. Returns the amount of coding income diverted into contracts
## (the caller subtracts it from what goes to the wallet). Works for frame steps and for
## one big offline step: a contract never takes more than it still needs.
func tick(delta: float, code_income: float, levels: Dictionary) -> float:
	var running := active.filter(func(c: Dictionary) -> bool: return not is_finished(c))
	var diverted := 0.0
	if not running.is_empty():
		var each := share(running.size()) * code_income * delta / running.size()
		for c: Dictionary in running:
			var take := minf(each, float(c["work"]) - float(c["done"]))
			c["done"] = float(c["done"]) + take
			diverted += take
			# Only count the time actually spent working: if it finished halfway through
			# this step (e.g. offline), only that part counts. Waiting for delivery is free.
			c["elapsed"] = float(c["elapsed"]) + (delta * take / each if each > 0.0 else delta)
	# New offers over time (several at once after a long offline period)
	next_offer_in -= delta
	while next_offer_in <= 0.0:
		next_offer_in += OFFER_EVERY_SEC
		if offers.size() < OFFER_MAX:
			var o := make_offer(levels, code_income)
			if not o.is_empty():
				offers.append(o)
	return diverted


## Reward for a contract incl. speed bonus (only meaningful once finished).
static func reward_of(c: Dictionary) -> float:
	var bonus := BONUS_MULT if float(c["elapsed"]) <= float(c["target_sec"]) else 1.0
	return float(c["reward"]) * bonus


## Deliver finished contract i. Returns the reward (0 if not finished).
func deliver(i: int) -> float:
	if i < 0 or i >= active.size() or not is_finished(active[i]):
		return 0.0
	var amount := reward_of(active[i])
	active.remove_at(i)
	return amount


# --- Save / load ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"active": active.duplicate(true), "offers": offers.duplicate(true), "next_offer_in": next_offer_in}


func from_dict(d: Dictionary) -> void:
	active = []
	offers = []
	for c: Variant in d.get("active", []):
		if c is Dictionary and c.has_all(["type", "work", "done", "reward", "target_sec", "elapsed"]):
			active.append({"type": String(c["type"]), "title": String(c.get("title", "")),
				"work": float(c["work"]), "done": float(c["done"]), "reward": float(c["reward"]),
				"target_sec": float(c["target_sec"]), "elapsed": float(c["elapsed"])})
	for o: Variant in d.get("offers", []):
		if o is Dictionary and o.has_all(["type", "work", "reward", "target_sec"]):
			offers.append({"type": String(o["type"]), "title": String(o.get("title", "")),
				"work": float(o["work"]), "reward": float(o["reward"]), "target_sec": float(o["target_sec"])})
	if offers.size() > OFFER_MAX:
		offers.resize(OFFER_MAX)
	next_offer_in = clampf(float(d.get("next_offer_in", OFFER_EVERY_SEC)), 0.0, OFFER_EVERY_SEC)
