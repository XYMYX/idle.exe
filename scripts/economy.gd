class_name Economy
extends RefCounted
## Alle Upgrades und die Wirtschafts-Rechnung. Reine Daten + statische Funktionen,
## kein Zustand: der Spielstand (levels) wird jeweils übergeben.
##
## Einkommen (CHF/s) =
##     Coding   (BASE_CODE + Summe code_add) * Produkt code_mult
##   + Speicher  Summe storage  * Netz-Multiplikator
##   + Software  Summe software * Netz-Multiplikator
##   + Mining    Summe mining
## Maschinen brauchen Strom (kW) und erzeugen Hitze: Kauf nur, wenn genug
## Stromanschluss (power_cap) und Kühlung (cool_cap) frei ist.

const BASE_CODE := 1.0   # CHF/s mit dem alten Laptop
const BASE_POWER := 1.5  # kW Hausanschluss
const BASE_COOL := 0.0

## Kategorien in Menü-Reihenfolge. requires = Upgrades, die man besitzen muss.
const CATEGORIES := [
	{"id": "hardware", "name": "Hardware", "requires": []},
	{"id": "kuehlung", "name": "Kühlung", "requires": []},
	{"id": "strom", "name": "Strom", "requires": []},
	{"id": "speicher", "name": "Speicher", "requires": []},
	{"id": "netzwerk", "name": "Netzwerk", "requires": ["ssd"]},
	{"id": "software", "name": "Software", "requires": ["gaming_pc"]},
	{"id": "mining", "name": "Mining", "requires": ["ups", "fan"]},
]

## Upgrades. Innerhalb einer Linie (cat + line) ist die Reihenfolge die Ausbau-Reihenfolge:
## eine Stufe ist erst kaufbar, wenn die vorherige gekauft ist.
## cost = Preis (bei max > 1: cost * growth^Level)
## fx   = Wirkung pro Level: code_add, code_mult, storage, software, mining, net_mult, power_cap, cool_cap
## uses = Verbrauch pro Level: power (kW), heat
## requires = zusätzliche Upgrades, die man besitzen muss
const UPGRADES := [
	# --- Hardware --------------------------------------------------------------
	{"id": "gaming_pc", "cat": "hardware", "line": "PC", "name": "Gaming-PC", "cost": 2500.0,
		"fx": {"code_mult": 2.0}},
	{"id": "workstation", "cat": "hardware", "line": "PC", "name": "Workstation", "cost": 2.0e6,
		"fx": {"code_mult": 2.0}, "uses": {"power": 1.0, "heat": 2.0}, "requires": ["water", "monitor_3"]},
	{"id": "cpu", "cat": "hardware", "line": "CPU", "name": "CPU-Upgrade", "cost": 100.0, "growth": 1.6, "max": 25,
		"fx": {"code_mult": 1.05}},
	{"id": "ram", "cat": "hardware", "line": "RAM", "name": "RAM-Riegel", "cost": 10.0, "growth": 1.15, "max": 999,
		"fx": {"code_add": 0.5}},
	{"id": "gpu_mid", "cat": "hardware", "line": "GPU", "name": "Mittelklasse-GPU", "cost": 8000.0,
		"fx": {"code_mult": 1.25}, "uses": {"power": 0.3, "heat": 1.0}, "requires": ["gaming_pc"]},
	{"id": "gpu_high", "cat": "hardware", "line": "GPU", "name": "High-End-GPU", "cost": 300000.0,
		"fx": {"code_mult": 1.5}, "uses": {"power": 0.5, "heat": 2.0}},
	{"id": "keyboard", "cat": "hardware", "line": "Monitore & Co.", "name": "Mech. Tastatur", "cost": 50.0,
		"fx": {"code_add": 2.0}},
	{"id": "monitor_2", "cat": "hardware", "line": "Monitore & Co.", "name": "Zweiter Monitor", "cost": 500.0,
		"fx": {"code_mult": 1.2}},
	{"id": "monitor_3", "cat": "hardware", "line": "Monitore & Co.", "name": "Dritter Monitor", "cost": 10000.0,
		"fx": {"code_mult": 1.2}, "requires": ["gaming_pc"]},
	{"id": "monitor_wall", "cat": "hardware", "line": "Monitore & Co.", "name": "Monitorwand", "cost": 5.0e6,
		"fx": {"code_mult": 1.5}, "uses": {"power": 0.5}, "requires": ["workstation"]},
	{"id": "homeserver", "cat": "hardware", "line": "Server", "name": "Heimserver", "cost": 50000.0,
		"fx": {"code_mult": 1.25}, "uses": {"power": 0.5, "heat": 1.0}, "requires": ["gaming_pc"]},
	{"id": "rack", "cat": "hardware", "line": "Server", "name": "Server-Rack", "cost": 250000.0,
		"fx": {"code_mult": 2.0}, "uses": {"power": 2.0, "heat": 3.0}, "requires": ["water"]},

	# --- Kühlung ---------------------------------------------------------------
	{"id": "fan", "cat": "kuehlung", "line": "Kühlung", "name": "Standventilator", "cost": 300.0,
		"fx": {"cool_cap": 2.0}},
	{"id": "water", "cat": "kuehlung", "line": "Kühlung", "name": "Wasserkühlung", "cost": 40000.0,
		"fx": {"cool_cap": 4.0, "code_mult": 1.5}, "requires": ["gaming_pc"]},
	{"id": "ac", "cat": "kuehlung", "line": "Kühlung", "name": "Klimaanlage", "cost": 150000.0,
		"fx": {"cool_cap": 10.0}},
	{"id": "rack_cooling", "cat": "kuehlung", "line": "Kühlung", "name": "Rack-Kühlung", "cost": 3.0e6,
		"fx": {"cool_cap": 30.0}, "requires": ["rack"]},
	{"id": "cool_loop", "cat": "kuehlung", "line": "Kühlung", "name": "Eigener Kühlkreislauf", "cost": 50.0e6,
		"fx": {"cool_cap": 120.0}},
	{"id": "industrial_cooling", "cat": "kuehlung", "line": "Kühlung", "name": "Industrielle Kühlanlage", "cost": 800.0e6,
		"fx": {"cool_cap": 500.0}},

	# --- Strom -----------------------------------------------------------------
	{"id": "ups", "cat": "strom", "line": "Strom", "name": "Notstrombatterie", "cost": 1000.0,
		"fx": {"power_cap": 1.0}},
	{"id": "grid", "cat": "strom", "line": "Strom", "name": "Grösserer Stromanschluss", "cost": 60000.0,
		"fx": {"power_cap": 5.0}},
	{"id": "solar", "cat": "strom", "line": "Strom", "name": "Solaranlage", "cost": 1.0e6,
		"fx": {"power_cap": 15.0}},
	{"id": "battery", "cat": "strom", "line": "Strom", "name": "Batteriespeicher", "cost": 20.0e6,
		"fx": {"power_cap": 60.0}},
	{"id": "own_grid", "cat": "strom", "line": "Strom", "name": "Eigenes Energienetz", "cost": 400.0e6,
		"fx": {"power_cap": 300.0}},

	# --- Speicher (Backups, vermieteter Speicher) ------------------------------
	{"id": "ssd", "cat": "speicher", "line": "Speicher", "name": "NVMe-SSD", "cost": 800.0,
		"fx": {"code_mult": 1.1}},
	{"id": "ssd_raid", "cat": "speicher", "line": "Speicher", "name": "SSD-Verbund", "cost": 18000.0,
		"fx": {"storage": 25.0}},
	{"id": "nas", "cat": "speicher", "line": "Speicher", "name": "NAS", "cost": 200000.0,
		"fx": {"storage": 150.0}, "uses": {"power": 0.3, "heat": 0.5}, "requires": ["homeserver"]},
	{"id": "storage_server", "cat": "speicher", "line": "Speicher", "name": "Storage-Server", "cost": 4.0e6,
		"fx": {"storage": 1500.0}, "uses": {"power": 3.0, "heat": 4.0}, "requires": ["rack", "fiber"]},
	{"id": "storage_cloud", "cat": "speicher", "line": "Speicher", "name": "Eigene Speicher-Cloud", "cost": 80.0e6,
		"fx": {"storage": 15000.0}, "uses": {"power": 20.0, "heat": 25.0}, "requires": ["line2"]},

	# --- Netzwerk (mehr Hosting-Kunden: wirkt auf Speicher und Software) -------
	{"id": "router", "cat": "netzwerk", "line": "Netzwerk", "name": "Besserer Router", "cost": 5000.0,
		"fx": {"net_mult": 1.25}},
	{"id": "fiber", "cat": "netzwerk", "line": "Netzwerk", "name": "Glasfaseranschluss", "cost": 120000.0,
		"fx": {"net_mult": 1.5}},
	{"id": "line2", "cat": "netzwerk", "line": "Netzwerk", "name": "Zweite Internetleitung", "cost": 2.0e6,
		"fx": {"net_mult": 1.25}},
	{"id": "leased", "cat": "netzwerk", "line": "Netzwerk", "name": "Firmen-Standleitung", "cost": 40.0e6,
		"fx": {"net_mult": 1.5}},
	{"id": "dc_link", "cat": "netzwerk", "line": "Netzwerk", "name": "Rechenzentrumsanbindung", "cost": 1.0e9,
		"fx": {"net_mult": 2.0}, "requires": ["storage_cloud"]},

	# --- Software (eigene Produkte, Abos) --------------------------------------
	{"id": "plugin", "cat": "software", "line": "Produkte", "name": "Kleines Plugin", "cost": 3000.0,
		"fx": {"software": 5.0}},
	{"id": "desktop_app", "cat": "software", "line": "Produkte", "name": "Desktop-App", "cost": 60000.0,
		"fx": {"software": 50.0}},
	{"id": "saas", "cat": "software", "line": "Produkte", "name": "Abo-Software", "cost": 1.0e6,
		"fx": {"software": 450.0}, "requires": ["homeserver", "router"]},
	{"id": "platform", "cat": "software", "line": "Produkte", "name": "Entwicklerplattform", "cost": 20.0e6,
		"fx": {"software": 5000.0}, "requires": ["rack", "fiber"]},
	{"id": "ecosystem", "cat": "software", "line": "Produkte", "name": "Software-Ökosystem", "cost": 500.0e6,
		"fx": {"software": 60000.0}, "requires": ["storage_cloud", "leased"]},

	# --- Mining (eigene Geräte, der Coding-PC bleibt frei) ---------------------
	{"id": "asic", "cat": "mining", "line": "Mining", "name": "Einzelner ASIC", "cost": 5000.0,
		"fx": {"mining": 8.0}, "uses": {"power": 0.5, "heat": 1.0}},
	{"id": "asic_shelf", "cat": "mining", "line": "Mining", "name": "ASIC-Regal", "cost": 100000.0,
		"fx": {"mining": 90.0}, "uses": {"power": 2.0, "heat": 3.0}},
	{"id": "mining_rack", "cat": "mining", "line": "Mining", "name": "Mining-Rack", "cost": 2.0e6,
		"fx": {"mining": 1000.0}, "uses": {"power": 8.0, "heat": 10.0}, "requires": ["rack"]},
	{"id": "mining_container", "cat": "mining", "line": "Mining", "name": "Mining-Container", "cost": 50.0e6,
		"fx": {"mining": 14000.0}, "uses": {"power": 40.0, "heat": 50.0}},
	{"id": "mining_farm", "cat": "mining", "line": "Mining", "name": "Mining-Farm", "cost": 1.0e9,
		"fx": {"mining": 160000.0}, "uses": {"power": 250.0, "heat": 300.0}},
]

const FX_ADD := ["code_add", "storage", "software", "mining", "power_cap", "cool_cap"]
const FX_MULT := ["code_mult", "net_mult"]

static var _index := {}


# --- Nachschlagen -------------------------------------------------------------

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


## Linien einer Kategorie in Reihenfolge des ersten Auftretens.
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


static func name_of(id: String) -> String:
	return get_def(id)["name"]


# --- Rechnen ------------------------------------------------------------------

## Summen aller Wirkungen und Verbräuche.
static func totals(levels: Dictionary) -> Dictionary:
	var t := {"code_add": 0.0, "storage": 0.0, "software": 0.0, "mining": 0.0,
		"power_cap": BASE_POWER, "cool_cap": BASE_COOL,
		"code_mult": 1.0, "net_mult": 1.0, "power": 0.0, "heat": 0.0}
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


## Einkommen pro Quelle und gesamt (CHF/s).
static func income(levels: Dictionary) -> Dictionary:
	var t := totals(levels)
	var code: float = (BASE_CODE + t["code_add"]) * t["code_mult"]
	var storage: float = t["storage"] * t["net_mult"]
	var software: float = t["software"] * t["net_mult"]
	var mining: float = t["mining"]
	return {"code": code, "storage": storage, "software": software, "mining": mining,
		"total": code + storage + software + mining}


static func category_unlocked(cat_id: String, levels: Dictionary) -> bool:
	for req: String in get_category(cat_id).get("requires", []):
		if levels.get(req, 0) <= 0:
			return false
	return true


## Fehlende Voraussetzungen (ohne Geld) als lesbare Texte. Leer = kaufbar, sobald bezahlbar.
static func missing(u: Dictionary, levels: Dictionary, t: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	if not category_unlocked(u["cat"], levels):
		for req: String in get_category(u["cat"])["requires"]:
			if levels.get(req, 0) <= 0:
				out.append(name_of(req))
	# Vorherige Stufe derselben Linie
	var items := line_items(u["cat"], u["line"])
	var i := items.find(u)
	if i > 0 and max_level(items[i - 1]) == 1 and levels.get(items[i - 1]["id"], 0) <= 0:
		var prev: String = items[i - 1]["name"]
		if not out.has(prev):
			out.append(prev)
	for req: String in u.get("requires", []):
		if levels.get(req, 0) <= 0 and not out.has(name_of(req)):
			out.append(name_of(req))
	# Strom und Kühlung
	if t.is_empty():
		t = totals(levels)
	var uses: Dictionary = u.get("uses", {})
	var need_p := float(uses.get("power", 0.0))
	var free_p: float = t["power_cap"] - t["power"]
	if need_p > 0.0 and need_p > free_p + 0.0001:
		out.append("%s kW Strom (frei: %s)" % [_num(need_p), _num(maxf(free_p, 0.0))])
	var need_h := float(uses.get("heat", 0.0))
	var free_h: float = t["cool_cap"] - t["heat"]
	if need_h > 0.0 and need_h > free_h + 0.0001:
		out.append("%s Kühlleistung (frei: %s)" % [_num(need_h), _num(maxf(free_h, 0.0))])
	return out


## Wirkung als Text, z. B. «Coding x1.5, +40 CHF/s Speicher · braucht 2 kW, 3 Kühlung».
static func effect_text(u: Dictionary) -> String:
	var parts: Array[String] = []
	var fx: Dictionary = u.get("fx", {})
	for k: String in fx:
		var v := float(fx[k])
		match k:
			"code_add": parts.append("+%s CHF/s Coding" % BigNum.format_rate(v))
			"code_mult": parts.append("Coding %s" % _mult(v))
			"storage": parts.append("+%s CHF/s Speicher" % BigNum.format_chf(v))
			"software": parts.append("+%s CHF/s Abos" % BigNum.format_chf(v))
			"mining": parts.append("+%s CHF/s Mining" % BigNum.format_chf(v))
			"net_mult": parts.append("Speicher+Abos %s" % _mult(v))
			"power_cap": parts.append("+%s kW Strom" % _num(v))
			"cool_cap": parts.append("+%s Kühlleistung" % _num(v))
	var text := ", ".join(parts)
	var uses: Dictionary = u.get("uses", {})
	if not uses.is_empty():
		var u_parts: Array[String] = []
		if uses.has("power"):
			u_parts.append("%s kW" % _num(uses["power"]))
		if uses.has("heat"):
			u_parts.append("%s Hitze" % _num(uses["heat"]))
		text += " · braucht " + ", ".join(u_parts)
	return text


static func _mult(v: float) -> String:
	if v < 1.5:
		return "+%d%%" % roundi((v - 1.0) * 100.0)
	return "x" + _num(v)


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else "%.1f" % v
