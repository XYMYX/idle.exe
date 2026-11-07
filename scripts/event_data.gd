class_name EventData
extends RefCounted
## Zufallsereignisse. Alle Beträge in «Minuten Einkommen», damit sie mit dem Spiel mitwachsen.
##
## Ereignis:  id, title, text, requires_any (eins davon besitzen, optional), choices, default (Index)
## Wahl:      label
##            cost_min  = kostet so viele Minuten Einkommen (Wahl gesperrt, wenn zu wenig Geld)
##            gain_min  = bringt so viele Minuten Einkommen sofort
##            base      = welche Einkommensquelle die Minuten meinen (Standard total):
##                        so bleibt «kostet 5 min Abos» fair, egal wie gross die Abos sind
##            buffs     = [{target, mult, min}]  target: total, code, storage, software, mining
##            requires  = Upgrades, die man für diese Wahl besitzen muss
##            react     = Animation von XYMYX danach (cheer, headdesk, ...)
## Ist die Standardwahl gesperrt, gilt die letzte freie Wahl.

const EVENTS := [
	{"id": "viral", "title": "Viral!",
		"text": "Eines deiner Produkte geht viral. Die Server ächzen unter dem Ansturm.",
		"requires_any": ["plugin", "desktop_app", "saas", "platform"],
		"choices": [
			{"label": "Server hochfahren", "cost_min": 5.0, "base": "software",
				"buffs": [{"target": "software", "mult": 2.0, "min": 15.0}], "react": "cheer"},
			{"label": "Drosseln und abwarten",
				"buffs": [{"target": "software", "mult": 1.25, "min": 15.0}]},
		], "default": 1},
	{"id": "bad_update", "title": "Fehlerhaftes Update",
		"text": "Ein Update legt die Abo-Kunden lahm. Das Support-Postfach läuft über.",
		"requires_any": ["saas", "platform", "ecosystem"],
		"choices": [
			{"label": "Sofort Hotfix", "cost_min": 5.0, "base": "software", "react": "stretch"},
			{"label": "Morgen fixen",
				"buffs": [{"target": "software", "mult": 0.5, "min": 20.0}], "react": "headdesk"},
		], "default": 1},
	{"id": "sponsor", "title": "Sponsor-Angebot",
		"text": "Ein Sponsor bietet Geld, verlangt aber Exklusivität für deine Abos.",
		"requires_any": ["plugin", "desktop_app", "saas"],
		"choices": [
			{"label": "Annehmen", "gain_min": 20.0, "base": "software",
				"buffs": [{"target": "software", "mult": 0.8, "min": 60.0}], "react": "cheer"},
			{"label": "Ablehnen"},
		], "default": 1},
	{"id": "coffee", "title": "Kaffeemaschine kaputt",
		"text": "Die Kaffeemaschine gibt den Geist auf. XYMYX schaut traurig in die leere Tasse.",
		"choices": [
			{"label": "Neue kaufen", "cost_min": 3.0, "base": "code",
				"buffs": [{"target": "code", "mult": 1.2, "min": 30.0}], "react": "drink"},
			{"label": "Tee trinken",
				"buffs": [{"target": "code", "mult": 0.9, "min": 15.0}]},
		], "default": 1},
	{"id": "outage", "title": "Stromausfall",
		"text": "Im ganzen Quartier fällt der Strom aus.",
		"choices": [
			{"label": "Notstrom übernimmt", "requires": ["ups"], "react": "cheer"},
			{"label": "Abwarten",
				"buffs": [{"target": "total", "mult": 0.5, "min": 5.0}], "react": "headdesk"},
		], "default": 0},
	{"id": "heatwave", "title": "Hitzewelle",
		"text": "Draussen 35 Grad. Die Hardware läuft heiss.",
		"requires_any": ["gaming_pc"],
		"choices": [
			{"label": "Klimaanlage voll aufdrehen", "requires": ["ac"]},
			{"label": "Leistung drosseln",
				"buffs": [{"target": "total", "mult": 0.8, "min": 10.0}], "react": "headdesk"},
		], "default": 0},
	{"id": "ctf", "title": "CTF beginnt",
		"text": "Ein Capture-the-Flag-Wettbewerb startet. Mitmachen kostet Zeit, bringt aber Preisgeld.",
		"choices": [
			{"label": "Mitmachen", "gain_min": 15.0,
				"buffs": [{"target": "code", "mult": 0.5, "min": 10.0}], "react": "cheer"},
			{"label": "Diesmal nicht"},
		], "default": 1},
	{"id": "bug_bounty", "title": "Sicherheitslücke gefunden",
		"text": "In einer erlaubten Testumgebung findest du eine Lücke.",
		"choices": [
			{"label": "Melden (Bug Bounty)", "gain_min": 20.0, "react": "cheer"},
			{"label": "Ignorieren"},
		], "default": 0},
	{"id": "rgb", "title": "RGB-Sale",
		"text": "Ein Online-Shop verschleudert RGB-Lüfter. Mehr Licht, mehr Leistung?",
		"requires_any": ["gaming_pc"],
		"choices": [
			{"label": "Zuschlagen", "cost_min": 3.0, "base": "code",
				"buffs": [{"target": "code", "mult": 1.3, "min": 20.0}], "react": "cheer"},
			{"label": "Vernünftig bleiben"},
		], "default": 1},
]

const TARGET_NAMES := {"total": "Alles", "code": "Coding", "storage": "Speicher",
	"software": "Abos", "mining": "Mining"}


## Faktor als Text: 2 -> «x2», 1.25 -> «x1.25»
static func mult_text(v: float) -> String:
	var t := String.num(v, 2)
	if t.ends_with(".0"):
		t = t.left(-2)
	return "x" + t


static func get_event(id: String) -> Dictionary:
	for e: Dictionary in EVENTS:
		if e["id"] == id:
			return e
	return {}
