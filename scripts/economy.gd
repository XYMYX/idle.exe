class_name Economy
extends RefCounted
## All upgrades and the economy math. Pure data + static functions,
## no state: the game state (levels) is passed in each time.
## Names are English source strings; translations live in i18n/translations.csv.
##
## Income (CHF/s) =
##     Coding    (BASE_CODE + sum code_add) * product code_mult
##   + Storage   sum storage  * network multiplier
##   + Software  sum software * network multiplier
##   + Mining    sum mining
## Machines need power (kW) and produce heat: buying is only possible if enough
## power capacity (power_cap) and cooling (cool_cap) is free.

const BASE_CODE := 1.0   # CHF/s with the old laptop
const BASE_POWER := 1.5  # kW household connection
const BASE_COOL := 0.0

## Categories in menu order. requires = upgrades you must own.
const CATEGORIES := [
	{"id": "hardware", "name": "Hardware", "requires": []},
	{"id": "cooling", "name": "Cooling", "requires": []},
	{"id": "power", "name": "Power", "requires": []},
	{"id": "storage", "name": "Storage", "requires": []},
	{"id": "network", "name": "Network", "requires": ["ssd"]},
	{"id": "software", "name": "Software", "requires": ["gaming_pc"]},
	{"id": "mining", "name": "Mining", "requires": ["ups", "fan"]},
	{"id": "automation", "name": "Automation", "requires": ["homeserver"]},
	{"id": "homelab", "name": "Homelab", "requires": ["homeserver"]},
	{"id": "security", "name": "Security", "requires": [], "requires_skill": {"skill": "pentesting", "level": 2}},
]

## Upgrades. Within a line (cat + line) the order is the build order:
## a tier can only be bought once the previous one is owned.
## cost = price (if max > 1: cost * growth^level)
## fx   = effect per level: code_add, code_mult, storage, software, mining, net_mult, power_cap, cool_cap,
##        contract_speed (mult), auto_accept, auto_deliver, event_shield (flags, 1 = on),
##        software_mult, star_mult (mult), ram_cap (GB), security / bounty (CHF/s, «security» income)
## requires_skill = optional {skill, level} (stage 11: security business needs pentesting)
## uses: power (kW), heat, ram (GB) – buying needs enough free capacity of each
## uses = consumption per level: power (kW), heat
## requires = additional upgrades you must own
const UPGRADES := [
	# --- Hardware --------------------------------------------------------------
	{"id": "gaming_pc", "cat": "hardware", "line": "PC", "name": "Gaming PC", "cost": 2500.0,
		"fx": {"code_mult": 2.0}},
	{"id": "workstation", "cat": "hardware", "line": "PC", "name": "Workstation", "cost": 2.0e6,
		"fx": {"code_mult": 2.0}, "uses": {"power": 1.0, "heat": 2.0}, "requires": ["water", "monitor_3"]},
	{"id": "cpu", "cat": "hardware", "line": "CPU", "name": "CPU upgrade", "cost": 100.0, "growth": 1.6, "max": 25,
		"fx": {"code_mult": 1.05}},
	{"id": "ram", "cat": "hardware", "line": "RAM", "name": "RAM stick", "cost": 10.0, "growth": 1.15, "max": 999,
		"fx": {"code_add": 0.5, "ram_cap": 1.0}},
	{"id": "gpu_mid", "cat": "hardware", "line": "GPU", "name": "Mid-range GPU", "cost": 8000.0,
		"fx": {"code_mult": 1.25}, "uses": {"power": 0.3, "heat": 1.0}, "requires": ["gaming_pc"]},
	{"id": "gpu_high", "cat": "hardware", "line": "GPU", "name": "High-end GPU", "cost": 300000.0,
		"fx": {"code_mult": 1.5}, "uses": {"power": 0.5, "heat": 2.0}},
	{"id": "keyboard", "cat": "hardware", "line": "Monitors & more", "name": "Mechanical keyboard", "cost": 50.0,
		"fx": {"code_add": 2.0}},
	{"id": "monitor_2", "cat": "hardware", "line": "Monitors & more", "name": "Second monitor", "cost": 500.0,
		"fx": {"code_mult": 1.2}},
	{"id": "monitor_3", "cat": "hardware", "line": "Monitors & more", "name": "Third monitor", "cost": 10000.0,
		"fx": {"code_mult": 1.2}, "requires": ["gaming_pc"]},
	{"id": "monitor_wall", "cat": "hardware", "line": "Monitors & more", "name": "Monitor wall", "cost": 5.0e6,
		"fx": {"code_mult": 1.5}, "uses": {"power": 0.5}, "requires": ["workstation"]},
	{"id": "homeserver", "cat": "hardware", "line": "Server", "name": "Home server", "cost": 50000.0,
		"fx": {"code_mult": 1.25}, "uses": {"power": 0.5, "heat": 1.0}, "requires": ["gaming_pc"]},
	{"id": "rack", "cat": "hardware", "line": "Server", "name": "Server rack", "cost": 250000.0,
		"fx": {"code_mult": 2.0}, "uses": {"power": 2.0, "heat": 3.0}, "requires": ["water"]},

	# --- Cooling ---------------------------------------------------------------
	{"id": "fan", "cat": "cooling", "line": "Cooling", "name": "Standing fan", "cost": 300.0,
		"fx": {"cool_cap": 2.0}},
	{"id": "water", "cat": "cooling", "line": "Cooling", "name": "Water cooling", "cost": 40000.0,
		"fx": {"cool_cap": 4.0, "code_mult": 1.5}, "requires": ["gaming_pc"]},
	{"id": "ac", "cat": "cooling", "line": "Cooling", "name": "Air conditioning", "cost": 150000.0,
		"fx": {"cool_cap": 10.0}},
	{"id": "rack_cooling", "cat": "cooling", "line": "Cooling", "name": "Rack cooling", "cost": 3.0e6,
		"fx": {"cool_cap": 30.0}, "requires": ["rack"]},
	{"id": "cool_loop", "cat": "cooling", "line": "Cooling", "name": "Custom cooling loop", "cost": 50.0e6,
		"fx": {"cool_cap": 120.0}},
	{"id": "industrial_cooling", "cat": "cooling", "line": "Cooling", "name": "Industrial cooling plant", "cost": 800.0e6,
		"fx": {"cool_cap": 500.0}},

	# --- Power -----------------------------------------------------------------
	{"id": "ups", "cat": "power", "line": "Power", "name": "Backup battery", "cost": 1000.0,
		"fx": {"power_cap": 1.0}},
	{"id": "grid", "cat": "power", "line": "Power", "name": "Bigger power connection", "cost": 60000.0,
		"fx": {"power_cap": 5.0}},
	{"id": "solar", "cat": "power", "line": "Power", "name": "Solar panels", "cost": 1.0e6,
		"fx": {"power_cap": 15.0}},
	{"id": "battery", "cat": "power", "line": "Power", "name": "Battery storage", "cost": 20.0e6,
		"fx": {"power_cap": 60.0}},
	{"id": "own_grid", "cat": "power", "line": "Power", "name": "Own power grid", "cost": 400.0e6,
		"fx": {"power_cap": 360.0}},  # 300 until stage 11; the security business needs the extra power

	# --- Storage (backups, rented storage) -------------------------------------
	{"id": "ssd", "cat": "storage", "line": "Storage", "name": "NVMe SSD", "cost": 800.0,
		"fx": {"code_mult": 1.1}},
	{"id": "ssd_raid", "cat": "storage", "line": "Storage", "name": "SSD array", "cost": 18000.0,
		"fx": {"storage": 25.0}},
	{"id": "nas", "cat": "storage", "line": "Storage", "name": "NAS", "cost": 200000.0,
		"fx": {"storage": 150.0}, "uses": {"power": 0.3, "heat": 0.5}, "requires": ["homeserver"]},
	{"id": "storage_server", "cat": "storage", "line": "Storage", "name": "Storage server", "cost": 4.0e6,
		"fx": {"storage": 1500.0}, "uses": {"power": 3.0, "heat": 4.0}, "requires": ["rack", "fiber"]},
	{"id": "storage_cloud", "cat": "storage", "line": "Storage", "name": "Own storage cloud", "cost": 80.0e6,
		"fx": {"storage": 15000.0}, "uses": {"power": 20.0, "heat": 25.0}, "requires": ["line2"]},

	# --- Network (more hosting customers: boosts storage and software) ---------
	{"id": "router", "cat": "network", "line": "Network", "name": "Better router", "cost": 5000.0,
		"fx": {"net_mult": 1.25}},
	{"id": "fiber", "cat": "network", "line": "Network", "name": "Fiber connection", "cost": 120000.0,
		"fx": {"net_mult": 1.5}},
	{"id": "line2", "cat": "network", "line": "Network", "name": "Second internet line", "cost": 2.0e6,
		"fx": {"net_mult": 1.25}},
	{"id": "leased", "cat": "network", "line": "Network", "name": "Business leased line", "cost": 40.0e6,
		"fx": {"net_mult": 1.5}},
	{"id": "dc_link", "cat": "network", "line": "Network", "name": "Data center link", "cost": 1.0e9,
		"fx": {"net_mult": 2.0}, "requires": ["storage_cloud"]},

	# --- Software (own products, subscriptions) --------------------------------
	{"id": "plugin", "cat": "software", "line": "Products", "name": "Small plugin", "cost": 3000.0,
		"fx": {"software": 5.0}},
	{"id": "desktop_app", "cat": "software", "line": "Products", "name": "Desktop app", "cost": 60000.0,
		"fx": {"software": 50.0}},
	{"id": "saas", "cat": "software", "line": "Products", "name": "Subscription software", "cost": 1.0e6,
		"fx": {"software": 450.0}, "requires": ["homeserver", "router"]},
	{"id": "platform", "cat": "software", "line": "Products", "name": "Developer platform", "cost": 20.0e6,
		"fx": {"software": 5000.0}, "requires": ["rack", "fiber"]},
	{"id": "ecosystem", "cat": "software", "line": "Products", "name": "Software ecosystem", "cost": 500.0e6,
		"fx": {"software": 60000.0}, "requires": ["storage_cloud", "leased"]},

	# --- Mining (dedicated devices, the coding PC stays free) ------------------
	{"id": "asic", "cat": "mining", "line": "Mining", "name": "Single ASIC", "cost": 5000.0,
		"fx": {"mining": 8.0}, "uses": {"power": 0.5, "heat": 1.0}},
	{"id": "asic_shelf", "cat": "mining", "line": "Mining", "name": "ASIC shelf", "cost": 100000.0,
		"fx": {"mining": 90.0}, "uses": {"power": 2.0, "heat": 3.0}},
	{"id": "mining_rack", "cat": "mining", "line": "Mining", "name": "Mining rack", "cost": 2.0e6,
		"fx": {"mining": 1000.0}, "uses": {"power": 8.0, "heat": 10.0}, "requires": ["rack"]},
	{"id": "mining_container", "cat": "mining", "line": "Mining", "name": "Mining container", "cost": 50.0e6,
		"fx": {"mining": 14000.0}, "uses": {"power": 40.0, "heat": 50.0}},
	{"id": "mining_farm", "cat": "mining", "line": "Mining", "name": "Mining farm", "cost": 1.0e9,
		"fx": {"mining": 160000.0}, "uses": {"power": 250.0, "heat": 300.0}},

	# --- Automation (stage 5b: contracts run by themselves) --------------------
	{"id": "unit_tests", "cat": "automation", "line": "Automation", "name": "Unit tests", "cost": 80000.0,
		"fx": {"contract_speed": 1.1}},
	{"id": "ci_builds", "cat": "automation", "line": "Automation", "name": "CI builds", "cost": 600000.0,
		"fx": {"contract_speed": 1.15}, "uses": {"power": 0.5, "heat": 1.0}},
	{"id": "auto_accept", "cat": "automation", "line": "Automation", "name": "Auto-accept", "cost": 3.0e6,
		"fx": {"auto_accept": 1.0}},
	{"id": "release_pipeline", "cat": "automation", "line": "Automation", "name": "Release pipeline", "cost": 15.0e6,
		"fx": {"auto_deliver": 1.0}, "requires": ["rack"]},
	{"id": "nightly_backups", "cat": "automation", "line": "Automation", "name": "Nightly backups", "cost": 60.0e6,
		"fx": {"event_shield": 1.0}, "requires": ["nas"]},

	# --- Homelab (stage 8b: virtual machines use RAM, 1 RAM stick = 1 GB) -------
	{"id": "vm_ci", "cat": "homelab", "line": "CI runner", "name": "CI runner VM", "cost": 1.5e6, "growth": 2.5, "max": 5,
		"fx": {"contract_speed": 1.05}, "uses": {"ram": 4.0, "power": 0.3, "heat": 0.5}},
	{"id": "vm_game", "cat": "homelab", "line": "Game server", "name": "Game server VM", "cost": 4.0e6, "growth": 2.5, "max": 5,
		"fx": {"software_mult": 1.06}, "uses": {"ram": 6.0, "power": 0.5, "heat": 1.0}},
	{"id": "vm_honeypot", "cat": "homelab", "line": "Honeypot", "name": "Honeypot VM", "cost": 2.5e6, "growth": 2.5, "max": 5,
		"fx": {"star_mult": 1.15}, "uses": {"ram": 4.0, "power": 0.3, "heat": 0.5}},

	# --- Security business (stage 11: needs pentesting 2) ----------------------
	{"id": "test_server", "cat": "security", "line": "Security", "name": "Test server", "cost": 300000.0,
		"fx": {"security": 100.0}, "uses": {"power": 0.5, "heat": 1.0}},
	{"id": "sec_lab", "cat": "security", "line": "Security", "name": "Security lab", "cost": 3.0e6,
		"fx": {"security": 700.0}, "uses": {"power": 2.0, "heat": 3.0}},
	{"id": "vuln_scanner", "cat": "security", "line": "Security", "name": "Vulnerability scanner", "cost": 25.0e6,
		"fx": {"bounty": 4500.0}, "uses": {"power": 3.0, "heat": 4.0}},
	{"id": "monitoring", "cat": "security", "line": "Security", "name": "Monitoring service", "cost": 200.0e6,
		"fx": {"security": 30000.0}, "uses": {"power": 15.0, "heat": 20.0}, "requires_skill": {"skill": "pentesting", "level": 3}},
	{"id": "sec_platform", "cat": "security", "line": "Security", "name": "Security platform", "cost": 1.2e9,
		"fx": {"security": 160000.0}, "uses": {"power": 60.0, "heat": 80.0}, "requires_skill": {"skill": "pentesting", "level": 3}},
]

const FX_ADD := ["code_add", "storage", "software", "mining", "power_cap", "cool_cap",
	"auto_accept", "auto_deliver", "event_shield", "ram_cap", "security", "bounty"]
const FX_MULT := ["code_mult", "net_mult", "contract_speed", "software_mult", "star_mult"]

static var _index := {}


# --- Lookup -------------------------------------------------------------------

static func get_def(id: String) -> Dictionary:
	if _index.is_empty():
		for u: Dictionary in UPGRADES:
			_index[u["id"]] = u
	return _index[id]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for u: Dictionary in UPGRADES:
		out.append(u["id"])
	return out


static func get_category(cat_id: String) -> Dictionary:
	for c: Dictionary in CATEGORIES:
		if c["id"] == cat_id:
			return c
	return {}


## Lines of a category in order of first appearance.
static func lines(cat_id: String) -> Array[String]:
	var out: Array[String] = []
	for u: Dictionary in UPGRADES:
		if u["cat"] == cat_id and not out.has(u["line"]):
			out.append(u["line"])
	return out


static func line_items(cat_id: String, line: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in UPGRADES:
		if u["cat"] == cat_id and u["line"] == line:
			out.append(u)
	return out


static func max_level(u: Dictionary) -> int:
	return int(u.get("max", 1))


static func cost(u: Dictionary, level: int) -> float:
	return float(u["cost"]) * pow(float(u.get("growth", 1.0)), level)


## English source name (translate for display).
static func name_of(id: String) -> String:
	return get_def(id)["name"]


## Translate a source string (static functions have no tr()).
static func tx(text: String) -> String:
	return String(TranslationServer.translate(text))


# --- Math ---------------------------------------------------------------------

## Sums of all effects and consumption.
static func totals(levels: Dictionary) -> Dictionary:
	var t := {"code_add": 0.0, "storage": 0.0, "software": 0.0, "mining": 0.0,
		"power_cap": BASE_POWER, "cool_cap": BASE_COOL,
		"code_mult": 1.0, "net_mult": 1.0, "power": 0.0, "heat": 0.0,
		"contract_speed": 1.0, "auto_accept": 0.0, "auto_deliver": 0.0, "event_shield": 0.0,
		"software_mult": 1.0, "star_mult": 1.0, "ram_cap": 0.0, "ram": 0.0, "security": 0.0, "bounty": 0.0}
	for u: Dictionary in UPGRADES:
		var lv: int = levels.get(u["id"], 0)
		if lv <= 0:
			continue
		var fx: Dictionary = u.get("fx", {})
		for k: String in fx:
			if k in FX_MULT:
				t[k] *= pow(float(fx[k]), lv)
			else:
				t[k] += float(fx[k]) * lv
		var uses: Dictionary = u.get("uses", {})
		for k: String in uses:
			t[k] += float(uses[k]) * lv
	return t


## Income per source and in total (CHF/s).
static func income(levels: Dictionary) -> Dictionary:
	var t := totals(levels)
	var code: float = (BASE_CODE + t["code_add"]) * t["code_mult"]
	var storage: float = t["storage"] * t["net_mult"]
	var software: float = t["software"] * t["net_mult"] * t["software_mult"]
	var mining: float = t["mining"]
	var security: float = t["security"] + t["bounty"]
	return {"code": code, "storage": storage, "software": software, "mining": mining, "security": security,
		"total": code + storage + software + mining + security}


static func category_unlocked(cat_id: String, levels: Dictionary, skills: Dictionary = {}) -> bool:
	var cat := get_category(cat_id)
	for req: String in cat.get("requires", []):
		if levels.get(req, 0) <= 0:
			return false
	return _skill_ok(cat, skills)


## true if the optional «requires_skill» of a category/upgrade is met.
static func _skill_ok(d: Dictionary, skills: Dictionary) -> bool:
	if not d.has("requires_skill"):
		return true
	var rs: Dictionary = d["requires_skill"]
	return int(skills.get(rs["skill"], 0)) >= int(rs["level"])


## «Pentesting 3» for a requires_skill entry.
static func skill_req_text(d: Dictionary) -> String:
	var rs: Dictionary = d["requires_skill"]
	return "%s %d" % [tx(SkillData.get_skill(rs["skill"]).get("name", rs["skill"])), int(rs["level"])]


## Missing requirements (not counting money) as translated, readable texts.
## Empty = buyable as soon as affordable.
static func missing(u: Dictionary, levels: Dictionary, totals_now: Dictionary = {},
		skills: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var cat := get_category(u["cat"])
	if not category_unlocked(u["cat"], levels, skills):
		for req: String in cat["requires"]:
			if levels.get(req, 0) <= 0:
				out.append(tx(name_of(req)))
		if not _skill_ok(cat, skills):
			out.append(skill_req_text(cat))
	if not _skill_ok(u, skills):
		out.append(skill_req_text(u))
	# Previous tier of the same line
	var items := line_items(u["cat"], u["line"])
	var i := items.find(u)
	if i > 0 and max_level(items[i - 1]) == 1 and levels.get(items[i - 1]["id"], 0) <= 0:
		var prev := tx(items[i - 1]["name"])
		if not out.has(prev):
			out.append(prev)
	for req: String in u.get("requires", []):
		if levels.get(req, 0) <= 0 and not out.has(tx(name_of(req))):
			out.append(tx(name_of(req)))
	# Power and cooling
	var tot := totals_now if not totals_now.is_empty() else totals(levels)
	var uses: Dictionary = u.get("uses", {})
	var need_p := float(uses.get("power", 0.0))
	var free_p: float = tot["power_cap"] - tot["power"]
	if need_p > 0.0 and need_p > free_p + 0.0001:
		out.append(tx("%s kW power (free: %s)") % [_num(need_p), _num(maxf(free_p, 0.0))])
	var need_h := float(uses.get("heat", 0.0))
	var free_h: float = tot["cool_cap"] - tot["heat"]
	if need_h > 0.0 and need_h > free_h + 0.0001:
		out.append(tx("%s cooling (free: %s)") % [_num(need_h), _num(maxf(free_h, 0.0))])
	var need_r := float(uses.get("ram", 0.0))
	var free_r: float = tot["ram_cap"] - tot["ram"]
	if need_r > 0.0 and need_r > free_r + 0.0001:
		out.append(tx("%s GB RAM (free: %s)") % [_num(need_r), _num(maxf(free_r, 0.0))])
	return out


## Translated effect text, e.g. «Coding x1.5, +40 CHF/s storage · needs 2 kW, 3 heat».
static func effect_text(u: Dictionary) -> String:
	var parts: Array[String] = []
	var fx: Dictionary = u.get("fx", {})
	for k: String in fx:
		var v := float(fx[k])
		match k:
			"code_add": parts.append(tx("+%s CHF/s coding") % BigNum.format_rate(v))
			"code_mult": parts.append(tx("Coding %s") % _mult(v))
			"storage": parts.append(tx("+%s CHF/s storage") % BigNum.format_chf(v))
			"software": parts.append(tx("+%s CHF/s subscriptions") % BigNum.format_chf(v))
			"mining": parts.append(tx("+%s CHF/s mining") % BigNum.format_chf(v))
			"net_mult": parts.append(tx("Storage+subscriptions %s") % _mult(v))
			"power_cap": parts.append(tx("+%s kW power") % _num(v))
			"cool_cap": parts.append(tx("+%s cooling") % _num(v))
			"security": parts.append(tx("+%s CHF/s security subscriptions") % BigNum.format_chf(v))
			"bounty": parts.append(tx("+%s CHF/s bug bounties") % BigNum.format_chf(v))
			"contract_speed": parts.append(tx("Contracts %s") % _mult(v))
			"auto_accept": parts.append(tx("Free slots take the best offer"))
			"auto_deliver": parts.append(tx("Finished contracts deliver themselves"))
			"event_shield": parts.append(tx("Halves penalties from bad events"))
			"software_mult": parts.append(tx("Subscriptions %s") % _mult(v))
			"star_mult": parts.append(tx("Stars %s") % _mult(v))
			"ram_cap": parts.append(tx("+%s GB RAM") % _num(v))
	var text := ", ".join(parts)
	var uses: Dictionary = u.get("uses", {})
	if not uses.is_empty():
		var u_parts: Array[String] = []
		if uses.has("power"):
			u_parts.append("%s kW" % _num(uses["power"]))
		if uses.has("heat"):
			u_parts.append(tx("%s heat") % _num(uses["heat"]))
		if uses.has("ram"):
			u_parts.append("%s GB RAM" % _num(uses["ram"]))
		text += " · " + tx("needs %s") % ", ".join(u_parts)
	return text


static func _mult(v: float) -> String:
	if v < 1.5:
		return "+%d%%" % roundi((v - 1.0) * 100.0)
	return "x" + _num(v)


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else "%.1f" % v
