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

## Running contracts: {kind, type, title, work, done, reward, target_sec, elapsed, ...}
## kind: "client" (money), "update" (+product, version), "oss" (+stars).
## A contract is finished when done >= work; it then waits for delivery.
var active: Array = []
## Offers on the board: same fields without done/elapsed
var offers: Array = []
var next_offer_in := 0.0
## Product versions of the game (shared reference, set by Game), used for update offers.
var versions := {}
## Skills of the game (shared reference, set by Game), used for course offers and skill-locked types.
var skills := {}


# --- Slots and types --------------------------------------------------------------

static func slots(levels: Dictionary) -> int:
	var n := BASE_SLOTS
	for s: Dictionary in SLOT_SOURCES:
		if int(levels.get(s["id"], 0)) >= int(s["level"]):
			n += 1
	return mini(n, MAX_SLOTS)


func free_slots(levels: Dictionary) -> int:
	return maxi(0, slots(levels) - active.size())


static func unlocked_types(levels: Dictionary, skill_levels: Dictionary = {}) -> Array:
	return ContractData.TYPES.filter(func(t: Dictionary) -> bool:
		if t["requires"] != "" and int(levels.get(t["requires"], 0)) <= 0:
			return false
		if t.has("requires_skill"):
			var rs: Dictionary = t["requires_skill"]
			return int(skill_levels.get(rs["skill"], 0)) >= int(rs["level"])
		return true)


## Share of the coding income diverted with n running (unfinished) contracts.
static func share(n: int) -> float:
	return 0.0 if n <= 0 else 1.0 - pow(0.5, n)


# --- Offers -----------------------------------------------------------------------

## New offer: sometimes a product update or an open-source project (stage 6),
## otherwise a client contract weighted towards the highest unlocked type.
func make_offer(levels: Dictionary, code_income: float) -> Dictionary:
	var r := randf()
	var upd := _free_updates(levels)
	if not upd.is_empty() and r < ContractData.UPDATE_CHANCE:
		var p: String = upd.keys().pick_random()
		var w := maxf(MIN_WORK, code_income * share(1) * 60.0 * float(Progress.UPDATE_WORK_MIN[p]))
		return {"kind": "update", "type": "update", "product": p, "version": upd[p], "title": "",
			"work": w, "reward": 0.0, "target_sec": float(Progress.UPDATE_WORK_MIN[p]) * 90.0}
	var course := _free_course(levels)
	if not course.is_empty() and r >= 1.0 - SkillData.COURSE_CHANCE:
		var sid: String = course.keys().pick_random()
		var cmin: float = SkillData.COURSE_WORK_MIN[int(course[sid]) - 1]
		var cw := maxf(MIN_WORK, code_income * share(1) * 60.0 * cmin)
		return {"kind": "course", "type": "course", "skill": sid, "level": course[sid], "title": "",
			"work": cw, "reward": 0.0, "target_sec": cmin * 90.0}
	var oss: Dictionary = ContractData.OSS_TYPE
	if int(levels.get(oss["requires"], 0)) > 0 and r >= ContractData.UPDATE_CHANCE \
			and r < ContractData.UPDATE_CHANCE + ContractData.OSS_CHANCE:
		var w := maxf(MIN_WORK, code_income * share(1) * 60.0 * float(oss["work_min"]))
		return {"kind": "oss", "type": "oss", "title": (oss["titles"] as Array).pick_random(),
			"work": w, "reward": 0.0, "stars": 5 + 5 * unlocked_types(levels, skills).size(),
			"target_sec": float(oss["target_min"]) * 60.0}
	return _client_offer(levels, code_income)


## Learnable skills, but only if no course is already on the board or running.
func _free_course(levels: Dictionary) -> Dictionary:
	for c: Dictionary in offers + active:
		if c.get("kind", "client") == "course":
			return {}
	return SkillData.learnable(levels, skills)


## Updatable products that don't already have an update on the board or running.
func _free_updates(levels: Dictionary) -> Dictionary:
	var upd := Progress.updatable(levels, versions)
	for c: Dictionary in offers + active:
		if c.get("kind", "client") == "update":
			upd.erase(c.get("product", ""))
	return upd


func _client_offer(levels: Dictionary, code_income: float) -> Dictionary:
	var types := unlocked_types(levels, skills)
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
	return {"kind": "client", "type": t["id"], "title": (t["titles"] as Array).pick_random(), "work": work,
		"reward": work * float(t["reward_mult"]), "target_sec": float(t["target_min"]) * 60.0}


## Fill the board completely (e.g. on first start).
func fill_offers(levels: Dictionary, code_income: float) -> void:
	while offers.size() < OFFER_MAX:
		var o := make_offer(levels, code_income)
		if o.is_empty():
			return
		offers.append(o)
	next_offer_in = OFFER_EVERY_SEC


## Accept offer i with a quality level (Progress.QUALITY index, product updates stay normal).
func accept(i: int, levels: Dictionary, quality := 1) -> bool:
	if i < 0 or i >= offers.size() or free_slots(levels) <= 0:
		return false
	var o: Dictionary = offers[i].duplicate()
	offers.remove_at(i)
	if o.get("kind", "client") not in ["update", "course"]:
		var q: Dictionary = Progress.QUALITY[clampi(quality, 0, Progress.QUALITY.size() - 1)]
		o["work"] = float(o["work"]) * float(q["work"])
		o["reward"] = float(o["reward"]) * float(q["reward"])
		if o.has("stars"):
			o["stars"] = float(o["stars"]) * float(q["stars"])
		o["quality"] = quality
	o["done"] = 0.0
	o["elapsed"] = 0.0
	active.append(o)
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
## speed (automation upgrades): each diverted CHF counts as `speed` CHF of work.
func tick(delta: float, code_income: float, levels: Dictionary, speed := 1.0) -> float:
	var running := active.filter(func(c: Dictionary) -> bool: return not is_finished(c))
	var diverted := 0.0
	if not running.is_empty():
		var each := share(running.size()) * code_income * delta / running.size()
		for c: Dictionary in running:
			var need := (float(c["work"]) - float(c["done"])) / speed
			var take := minf(each, need)
			# On the last step set it to exactly the full work (avoids 999.9999 < 1000 float leftovers)
			c["done"] = float(c["work"]) if take >= need else float(c["done"]) + take * speed
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


## Index of the most lucrative offer (highest reward per work, then highest reward), -1 if none.
## Updates and open-source projects have no money reward, so auto-accept takes them only
## when no client contract is on the board.
func best_offer() -> int:
	var best := -1
	for i in offers.size():
		if best < 0:
			best = i
			continue
		var a: Dictionary = offers[i]
		var b: Dictionary = offers[best]
		var ra := float(a["reward"]) / float(a["work"])
		var rb := float(b["reward"]) / float(b["work"])
		if ra > rb + 0.0001 or (absf(ra - rb) <= 0.0001 and float(a["reward"]) > float(b["reward"])):
			best = i
	return best


static func has_bonus(c: Dictionary) -> bool:
	return float(c["elapsed"]) <= float(c["target_sec"])


## Reward for a contract incl. speed bonus (only meaningful once finished).
static func reward_of(c: Dictionary) -> float:
	return float(c["reward"]) * (BONUS_MULT if has_bonus(c) else 1.0)


## Stars of an open-source project incl. speed bonus.
static func stars_of(c: Dictionary) -> float:
	return float(c.get("stars", 0.0)) * (BONUS_MULT if has_bonus(c) else 1.0)


## Remove finished contract i and return it with «payout» (money) and «payout_stars».
## Game applies the effect depending on «kind». {} if not finished.
func take_finished(i: int) -> Dictionary:
	if i < 0 or i >= active.size() or not is_finished(active[i]):
		return {}
	var c: Dictionary = active[i]
	c["payout"] = reward_of(c)
	c["payout_stars"] = stars_of(c)
	active.remove_at(i)
	return c


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
			var e := _clean(c)
			e["done"] = float(c["done"])
			e["elapsed"] = float(c["elapsed"])
			active.append(e)
	for o: Variant in d.get("offers", []):
		if o is Dictionary and o.has_all(["type", "work", "reward", "target_sec"]):
			offers.append(_clean(o))
	if offers.size() > OFFER_MAX:
		offers.resize(OFFER_MAX)
	next_offer_in = clampf(float(d.get("next_offer_in", OFFER_EVERY_SEC)), 0.0, OFFER_EVERY_SEC)


## Typed copy of a saved offer/contract (unknown keys dropped, old saves get kind «client»).
static func _clean(o: Dictionary) -> Dictionary:
	var e := {"kind": String(o.get("kind", "client")), "type": String(o["type"]),
		"title": String(o.get("title", "")), "work": float(o["work"]), "reward": float(o["reward"]),
		"target_sec": float(o["target_sec"])}
	if o.has("skill"):
		e["skill"] = String(o["skill"])
		e["level"] = int(o.get("level", 1))
	if o.has("product"):
		e["product"] = String(o["product"])
		e["version"] = int(o.get("version", 1))
	if o.has("stars"):
		e["stars"] = float(o["stars"])
	return e
