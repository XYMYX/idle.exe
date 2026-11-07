extends Node
## Autoload «Game»: game state (money, upgrade levels), saving and loading.
## Upgrade data and the economy math live in economy.gd.

signal changed
signal bought(id: String)
signal milestone(value: float)  # total_earned reaches 1K, 10K, 100K, ...
signal contract_delivered(reward: float)
signal contract_done(kind: String)  # any delivered contract (client, update, oss)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 4  # 3 = contracts, 4 = product versions + stars
const AUTOSAVE_SEC := 30.0
const OFFLINE_MAX_SEC := 8 * 3600.0

var money := 0.0         # CHF
var total_earned := 0.0
var levels := {}
var paused := false
var last_saved_at := 0.0  # Unix time of the last save
var offline_gain := 0.0   # money earned while away (computed at start)
var offline_sec := 0.0

var buffs: Array = []      # timed effects: {target, mult, until, label}
var contracts := Contracts.new()  # stage 5a: offers, running contracts, delivery
var product_versions := {}  # stage 6: product id -> number of delivered updates (0..10)
var stars := 0.0            # stage 6: open-source stars (unlock tiers, not spent)
var overclock := false      # stage 7: overclocking switch
var contract_quality := 1   # stage 7: Progress.QUALITY index for newly accepted contracts
var _oc_mult := 1.0
var _star_fx := {"contract_reward": 1.0, "contract_speed": 1.0, "total_mult": 1.0}
## Recent events, newest first: {t, clock, title, label, auto} (English source strings,
## translated when shown). Old saves may contain {t, clock, text} instead.
var event_log: Array = []

const LOG_MAX := 10

var _income := {}  # cache of Economy.income() WITHOUT effects, recomputed on every purchase
var _buffed_total := 0.0
var _code_now := 0.0  # coding income incl. effects (contracts divert a share of it)
var _buff_check := 0.0
var _totals := {}
var _autosave := 0.0
var _next_milestone := 1000.0


func _ready() -> void:
	for id in Economy.ids():
		levels[id] = 0
	contracts.versions = product_versions  # shared reference for update offers
	load_game()
	_prune_buffs()
	_recalc()
	if contracts.offers.is_empty() and contracts.active.is_empty():
		contracts.fill_offers(levels, _code_now)  # first start or old save without contracts
	_apply_offline()
	while _next_milestone <= total_earned:  # skip milestones already reached
		_next_milestone *= 10.0


## Money for the time since the last save, at most 8 hours.
## Clock set back (negative time) = nothing.
func _apply_offline() -> void:
	if last_saved_at <= 0.0:
		return  # no save yet
	offline_sec = clampf(Time.get_unix_time_from_system() - last_saved_at, 0.0, OFFLINE_MAX_SEC)
	# Running contracts keep working offline and take their share of the coding income.
	var diverted := contracts.tick(offline_sec, _code_now, levels, contract_speed())
	offline_gain = income() * offline_sec - diverted
	# With the release pipeline, contracts finished while away are delivered right away.
	if _totals["auto_deliver"] > 0.0:
		for i in range(contracts.active.size() - 1, -1, -1):
			if Contracts.is_finished(contracts.active[i]):
				offline_gain += _deliver_internal(i)
	money += offline_gain
	total_earned += offline_gain
	print("idle.exe: offline %d s -> +%s CHF" % [int(offline_sec), BigNum.format_chf(offline_gain)])


func _process(delta: float) -> void:
	if not paused:
		var gain := income() * delta - contracts.tick(delta, _code_now, levels, contract_speed())
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
		_automate_contracts()
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


# --- Economy ------------------------------------------------------------------

## Total income in CHF/s, including active effects.
func income() -> float:
	return _buffed_total


## Income that actually reaches the wallet right now (total minus the contracts' share).
func wallet_income() -> float:
	return income() - contract_rate()


## CHF/s of coding income currently flowing into running contracts.
func contract_rate() -> float:
	return Contracts.share(contracts.running_count()) * _code_now


## Coding income incl. effects (what contracts draw from).
func code_income() -> float:
	return _code_now


## Income without effects (base for «minutes of income» in events).
## part: total, code, storage, software, mining
func base_income(part := "total") -> float:
	return float(_income.get(part, _income["total"]))


## Income per source: code, storage, software, mining, total.
func income_parts() -> Dictionary:
	return _income


## Sums incl. power (power/power_cap) and cooling (heat/cool_cap).
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


## Missing requirements (not counting money), translated. Empty = buyable once affordable.
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
	var base_totals := Economy.totals(levels)
	_oc_mult = Progress.overclock_mult(base_totals, overclock)
	_totals = Progress.with_overclock_heat(base_totals, overclock)  # overclocking occupies cooling
	_star_fx = Progress.star_fx(stars)
	_income = Progress.income(levels, product_versions, stars, overclock)
	_apply_buffs()


# --- Effects (buffs) from events ----------------------------------------------

func add_buff(target: String, mult: float, sec: float, label: String) -> void:
	buffs.append({"target": target, "mult": mult, "until": Time.get_unix_time_from_system() + sec, "label": label})
	_apply_buffs()
	changed.emit()


## Remove expired effects. true if something changed.
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
	_code_now = _income["code"] * m["code"] * m["total"]


# --- Contracts (stage 5a) -------------------------------------------------------

func set_overclock(on: bool) -> void:
	overclock = on
	_recalc()
	changed.emit()


## Current overclock multiplier on coding (1.0 off, 1.3 on, 1.1 throttled).
func overclock_mult() -> float:
	return _oc_mult


## Free cooling overclocking needs for x1.5 (based on heat without overclocking).
func overclock_need() -> float:
	return Progress.overclock_need(Economy.totals(levels))


func set_contract_quality(q: int) -> void:
	contract_quality = clampi(q, 0, Progress.QUALITY.size() - 1)
	changed.emit()


func accept_contract(i: int) -> bool:
	if not contracts.accept(i, levels, contract_quality):
		return false
	changed.emit()
	return true


## Stage 5b automation: deliver finished contracts and fill free slots by themselves.
func _automate_contracts() -> void:
	if _totals["auto_deliver"] > 0.0:
		for i in range(contracts.active.size() - 1, -1, -1):
			if Contracts.is_finished(contracts.active[i]):
				deliver_contract(i)
	if _totals["auto_accept"] > 0.0:
		while contracts.free_slots(levels) > 0 and not contracts.offers.is_empty():
			if not accept_contract(contracts.best_offer()):
				break


## Contract progress multiplier: automation upgrades × star tier «Contributors».
func contract_speed() -> float:
	return float(_totals["contract_speed"]) * float(_star_fx["contract_speed"])


## Money multiplier for client contracts from star tiers.
func contract_reward_mult() -> float:
	return float(_star_fx["contract_reward"])


## Deliver a finished contract: money, a product update or stars, depending on its kind.
func deliver_contract(i: int) -> float:
	var kind: String = contracts.active[i].get("kind", "client") if i >= 0 and i < contracts.active.size() else ""
	var reward := _deliver_internal(i)
	if kind == "":
		return 0.0
	if reward > 0.0:
		contract_delivered.emit(reward)
	contract_done.emit(kind)
	changed.emit()
	save_game()
	return reward


## Applies the effect of a finished contract without signals/saving (also used offline).
## Returns the money paid out (0 for updates and open source).
func _deliver_internal(i: int) -> float:
	var c := contracts.take_finished(i)
	if c.is_empty():
		return 0.0
	match c.get("kind", "client"):
		"update":
			var p: String = c.get("product", "")
			product_versions[p] = mini(Progress.MAX_VERSION, maxi(int(product_versions.get(p, 0)), int(c.get("version", 1))))
			_recalc()
			return 0.0
		"oss":
			stars += float(c["payout_stars"])
			_recalc()
			return 0.0
		_:
			var reward: float = float(c["payout"]) * contract_reward_mult()
			money += reward
			total_earned += reward
			return reward


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


## Log an event outcome. title/label are English source strings (translated when shown).
func log_event(title: String, label: String, auto: bool) -> void:
	event_log.push_front({"t": Time.get_unix_time_from_system(),
		"clock": Time.get_time_string_from_system().left(5),
		"title": title, "label": label, "auto": auto})
	if event_log.size() > LOG_MAX:
		event_log.resize(LOG_MAX)


# --- Save / load --------------------------------------------------------------

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
		"contracts": contracts.to_dict(),
		"product_versions": product_versions,
		"stars": stars,
		"overclock": overclock,
		"contract_quality": contract_quality,
	}
	# Write to a temp file first, then rename: a crash in the middle of
	# writing can't destroy the previous save this way.
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Saving failed: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(_abs(tmp), _abs(SAVE_PATH))
	if err != OK:
		push_error("Saving (rename) failed: %s" % error_string(err))


func load_game() -> void:
	var path := SAVE_PATH
	if not FileAccess.file_exists(path):
		if not FileAccess.file_exists(SAVE_PATH + ".tmp"):
			return  # first start
		path = SAVE_PATH + ".tmp"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file is broken, copy kept at user://save.bad.json, starting fresh.")
		DirAccess.copy_absolute(_abs(path), _abs("user://save.bad.json"))
		return
	# In version 1 the currency was called «commits»: carried over 1:1 as CHF.
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
			if not x is Dictionary:
				continue
			var e := {"t": float(x.get("t", 0.0)), "clock": String(x.get("clock", "--:--"))}
			if x.has("title"):
				e["title"] = String(x["title"])
				e["label"] = String(x.get("label", ""))
				e["auto"] = bool(x.get("auto", false))
			elif x.has("text"):
				e["text"] = String(x["text"])  # old format, shown as is
			else:
				continue
			event_log.append(e)
		if event_log.size() > LOG_MAX:
			event_log.resize(LOG_MAX)
	var pv: Variant = data.get("product_versions", {})  # missing before version 4
	if pv is Dictionary:
		for p: String in Progress.UPDATE_WORK_MIN:
			if pv.has(p):
				product_versions[p] = clampi(int(pv[p]), 0, Progress.MAX_VERSION)
	stars = maxf(0.0, float(data.get("stars", 0.0)))
	overclock = bool(data.get("overclock", false))
	contract_quality = clampi(int(data.get("contract_quality", 1)), 0, Progress.QUALITY.size() - 1)
	var ct: Variant = data.get("contracts", {})  # missing in saves before version 3
	if ct is Dictionary:
		contracts.from_dict(ct)
	print("idle.exe: save loaded from %s" % _abs(path))


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)
