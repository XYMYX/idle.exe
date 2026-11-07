extends Node
## Autoload «Game»: game state (money, upgrade levels), saving and loading.
## Upgrade data and the economy math live in economy.gd.

signal changed
signal bought(id: String)
signal milestone(value: float)  # total_earned reaches 1K, 10K, 100K, ...
signal contract_delivered(reward: float)
signal contract_done(kind: String)  # any delivered contract (client, update, oss)
signal flag_captured(id: String, reward: float)  # stage 8a: CTF flag
signal company_sold(points: int)  # stage 9: prestige
signal research_finished(id: String)  # stage 12

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 8  # 3 = contracts, 4 = versions + stars, 5 = flags + stats, 6 = prestige, 7 = skills, 8 = research
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
var flags := {}  # stage 8a: captured CTF flags, id -> true
## Counters for flags: delivered contracts, resolved events, highest combo level, naps
var stats := {"contracts": 0, "events": 0, "max_combo": 0, "naps": 0, "sales": 0}
var knowhow := 0             # stage 9: know-how points from selling the company (+2 % each)
var run_earned := 0.0        # money earned in the current run (since the last sale)
var specialization := ""     # stage 9: "", "security", "software" or "datacenter"
var skills := {}             # stage 10: skill id -> level 0..5 (kept when the company is sold)
var _skill_fx := SkillData.fx({})
var research_done := {}      # stage 12: project id -> true
var research_active := {}    # stage 12: {id, left} of the running project, {} = none
var _research_fx := ResearchData.fx({})
var _tools := FlagData.tool_fx({})
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
	contracts.skills = skills  # shared reference for course offers and skill-locked types
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
	if not research_active.is_empty():
		research_active["left"] = float(research_active["left"]) - offline_sec
	var diverted := contracts.tick(offline_sec, _code_now, levels, contract_speed())
	offline_gain = income() * offline_sec - diverted
	# With the release pipeline, contracts finished while away are delivered right away.
	if _totals["auto_deliver"] > 0.0:
		for i in range(contracts.active.size() - 1, -1, -1):
			if Contracts.is_finished(contracts.active[i]):
				offline_gain += _deliver_internal(i)
	money += offline_gain
	total_earned += offline_gain
	run_earned += offline_gain
	print("idle.exe: offline %d s -> +%s CHF" % [int(offline_sec), BigNum.format_chf(offline_gain)])


func _process(delta: float) -> void:
	if not paused:
		if not research_active.is_empty():
			research_active["left"] = float(research_active["left"]) - delta
		var gain := income() * delta - contracts.tick(delta, _code_now, levels, contract_speed())
		money += gain
		total_earned += gain
		run_earned += gain
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
		_check_flags()
		_check_research()
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
	return level(id) >= max_level(id)


## Highest level of an upgrade, incl. research (VM density raises VMs from 5 to 8).
func max_level(id: String) -> int:
	return ResearchData.max_level(Economy.get_def(id), _research_fx)


## Missing requirements (not counting money), translated. Empty = buyable once affordable.
func missing(id: String) -> Array[String]:
	return Economy.missing(Economy.get_def(id), levels, _totals, skills)


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
	var base_totals := Progress.spec_totals(Economy.totals(levels), specialization)
	_oc_mult = Progress.overclock_mult(base_totals, overclock)
	_totals = Progress.with_overclock_heat(base_totals, overclock)  # overclocking occupies cooling
	_star_fx = Progress.star_fx(stars)
	_tools = FlagData.tool_fx(flags)
	_skill_fx = SkillData.fx(skills)
	_research_fx = ResearchData.fx(research_done)
	contracts.bonus_slots = int(_research_fx["bonus_slots"])
	contracts.max_version = int(_research_fx["max_version"])
	_income = Progress.income(levels, product_versions, stars, overclock, _tools, specialization, knowhow,
		_skill_fx, _research_fx)
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
	var m := {"total": 1.0, "code": 1.0, "storage": 1.0, "software": 1.0, "mining": 1.0, "security": 1.0}
	for b: Dictionary in buffs:
		if m.has(b["target"]):
			m[b["target"]] *= float(b["mult"])
	_buffed_total = (_income["code"] * m["code"] + _income["storage"] * m["storage"]
		+ _income["software"] * m["software"] + _income["mining"] * m["mining"]
		+ _income["security"] * m["security"]) * m["total"]
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
	return float(_totals["contract_speed"]) * float(_star_fx["contract_speed"]) * float(_tools["contract_speed"]) \
		* float(_skill_fx["contract_speed"]) * float(_research_fx["contract_speed"])


## Money multiplier for client contracts from star tiers.
func contract_reward_mult() -> float:
	return float(_star_fx["contract_reward"]) * float(_tools["contract_reward"]) * Progress.spec_contract_reward(specialization)


## Multiplier for money gained from events (tool «Incident runbook»).
func event_gain_mult() -> float:
	return float(_tools["event_gain"]) * (2.0 if specialization == "security" else 1.0) * float(_skill_fx["event_gain"])


## Reward multiplier of the learned skills for a contract type (stage 10).
func skill_reward_mult(contract_type: String) -> float:
	return SkillData.reward_mult(skills, contract_type)


## Penalties of bad events are halved (nightly backups or the security specialization).
func event_shield() -> bool:
	return float(_totals["event_shield"]) > 0.0 or specialization == "security"


# --- Prestige (stage 9) -------------------------------------------------------------

func can_sell() -> bool:
	return Progress.knowhow_points(run_earned) > 0


## Know-how points a sale would give right now.
func sell_points() -> int:
	return Progress.knowhow_points(run_earned)


## Sell the company: know-how points, then start over with a specialization.
## Kept: flags + tools, stars, stats, event log, settings. Reset: money, upgrades,
## contracts, product versions, effects, overclocking.
func sell_company(next_spec: String) -> bool:
	var points := sell_points()
	if points <= 0 or not Progress.SPECS.has(next_spec):
		return false
	knowhow += points
	stats["sales"] = int(stats.get("sales", 0)) + 1
	specialization = next_spec
	money = 0.0
	run_earned = 0.0
	for id: String in levels:
		levels[id] = 0
	product_versions.clear()  # keeps the shared reference used by contracts
	contracts = Contracts.new()
	contracts.versions = product_versions
	contracts.skills = skills  # skills stay after a sale
	buffs.clear()
	overclock = false
	research_done.clear()  # research is reset like upgrades
	research_active = {}
	_recalc()
	contracts.fill_offers(levels, _code_now)
	log_event("Company sold", Progress.SPECS[next_spec]["name"], false)
	company_sold.emit(points)
	changed.emit()
	save_game()
	return true


## Combined tool bonuses of the captured flags (for display).
func tools() -> Dictionary:
	return _tools


# --- Research (stage 12) -----------------------------------------------------------

## Translated reason why a project can't be started, "" if it can.
func research_problem(id: String) -> String:
	var p := ResearchData.get_project(id)
	if research_done.get(id, false):
		return tr("Done")
	if not research_active.is_empty():
		return tr("Another project is running")
	if p["requires"] != "" and not has(p["requires"]):
		return tr("Requires: %s") % tr(Economy.name_of(p["requires"]))
	if money < float(p["cost"]):
		return tr("Not enough money")
	return ""


func start_research(id: String) -> bool:
	if research_problem(id) != "":
		return false
	var p := ResearchData.get_project(id)
	money -= float(p["cost"])
	research_active = {"id": id, "left": float(p["minutes"]) * 60.0}
	changed.emit()
	save_game()
	return true


func _check_research() -> void:
	if research_active.is_empty() or float(research_active["left"]) > 0.0:
		return
	var id: String = research_active["id"]
	research_done[id] = true
	research_active = {}
	_recalc()
	log_event("Research finished", ResearchData.get_project(id)["name"], false)
	research_finished.emit(id)
	changed.emit()
	save_game()


# --- CTF flags (stage 8a) ---------------------------------------------------------

func note_stat(key: String, value := 1) -> void:
	if key == "max_combo":
		stats[key] = maxi(int(stats.get(key, 0)), value)
	else:
		stats[key] = int(stats.get(key, 0)) + value


## Current value towards a flag's goal.
func flag_progress(f: Dictionary) -> float:
	match f["goal"]:
		"earned": return total_earned
		"contracts": return float(stats["contracts"])
		"events": return float(stats["events"])
		"combo": return float(stats["max_combo"])
		"naps": return float(stats["naps"])
		"stars": return stars
		"updates":
			var n := 0
			for p: String in product_versions:
				n += int(product_versions[p])
			return float(n)
		"owns": return 1.0 if has(f["target"]) else 0.0
		"all_upgrades":
			for u: Dictionary in Economy.UPGRADES:
				if Economy.max_level(u) == 1 and not has(u["id"]):
					return 0.0
			return 1.0
	return 0.0


static func flag_target(f: Dictionary) -> float:
	return 1.0 if f["goal"] in ["owns", "all_upgrades"] else float(f["target"])


## Capture every flag whose goal is reached: money once + permanent tool bonus.
func _check_flags() -> void:
	for f: Dictionary in FlagData.FLAGS:
		if flags.get(f["id"], false) or flag_progress(f) < flag_target(f):
			continue
		flags[f["id"]] = true
		var reward: float = base_income() * 60.0 * float(f["reward_min"]) * (2.0 if specialization == "security" else 1.0)
		money += reward
		total_earned += reward
		run_earned += reward
		_recalc()
		log_event("Flag captured", FlagData.flag_name(f), false)
		flag_captured.emit(f["id"], reward)
		changed.emit()
		save_game()


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
	note_stat("contracts")
	match c.get("kind", "client"):
		"update":
			var p: String = c.get("product", "")
			product_versions[p] = mini(int(_research_fx["max_version"]), maxi(int(product_versions.get(p, 0)), int(c.get("version", 1))))
			_recalc()
			return 0.0
		"oss":
			stars += float(c["payout_stars"]) * float(_totals["star_mult"]) * float(_tools["star_mult"])
			_recalc()
			return 0.0
		"course":
			var sid: String = c.get("skill", "")
			skills[sid] = mini(SkillData.MAX_LEVEL, maxi(int(skills.get(sid, 0)), int(c.get("level", 1))))
			_recalc()
			return 0.0
		_:
			var reward: float = float(c["payout"]) * contract_reward_mult() * skill_reward_mult(c.get("type", ""))
			money += reward
			total_earned += reward
			run_earned += reward
			return reward


func earn(amount: float) -> void:
	money += amount
	total_earned += amount
	run_earned += amount
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
		"flags": flags,
		"stats": stats,
		"knowhow": knowhow,
		"run_earned": run_earned,
		"specialization": specialization,
		"skills": skills,
		"research_done": research_done,
		"research_active": research_active,
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
			# upper bound incl. research (VMs up to 8); research itself is loaded further below
			levels[id] = clampi(int(lv.get(id, 0)), 0, ResearchData.max_level(u, {"vm_max": 8}))
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
				product_versions[p] = clampi(int(pv[p]), 0, 15)  # up to v1.15 with long-term support
	stars = maxf(0.0, float(data.get("stars", 0.0)))
	overclock = bool(data.get("overclock", false))
	var fl: Variant = data.get("flags", {})  # missing before version 5
	if fl is Dictionary:
		for f: Dictionary in FlagData.FLAGS:
			if fl.get(f["id"], false):
				flags[f["id"]] = true
	knowhow = maxi(0, int(data.get("knowhow", 0)))  # missing before version 6
	run_earned = maxf(0.0, float(data.get("run_earned", total_earned)))  # first run: all earnings
	var sp := String(data.get("specialization", ""))
	specialization = sp if Progress.SPECS.has(sp) else ""
	var rd: Variant = data.get("research_done", {})  # missing before version 8
	if rd is Dictionary:
		for p: Dictionary in ResearchData.PROJECTS:
			if rd.get(p["id"], false):
				research_done[p["id"]] = true
	var ra: Variant = data.get("research_active", {})
	if ra is Dictionary and ra.has("id") and not ResearchData.get_project(String(ra["id"])).is_empty():
		research_active = {"id": String(ra["id"]), "left": float(ra.get("left", 0.0))}
	var sk: Variant = data.get("skills", {})  # missing before version 7
	if sk is Dictionary:
		for s: Dictionary in SkillData.SKILLS:
			if sk.has(s["id"]):
				skills[s["id"]] = clampi(int(sk[s["id"]]), 0, SkillData.MAX_LEVEL)
	var st: Variant = data.get("stats", {})
	if st is Dictionary:
		for k: String in stats:
			stats[k] = maxi(0, int(st.get(k, 0)))
	contract_quality = clampi(int(data.get("contract_quality", 1)), 0, Progress.QUALITY.size() - 1)
	var ct: Variant = data.get("contracts", {})  # missing in saves before version 3
	if ct is Dictionary:
		contracts.from_dict(ct)
	var rfx := ResearchData.fx(research_done)
	for id: String in ResearchData.VM_IDS:
		levels[id] = mini(int(levels[id]), ResearchData.max_level(Economy.get_def(id), rfx))
	print("idle.exe: save loaded from %s" % _abs(path))


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)
