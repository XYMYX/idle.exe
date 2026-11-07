class_name EventData
extends RefCounted
## Random events. All amounts are in «minutes of income» so they scale with the game.
## Texts are English source strings; the German translation lives in i18n/translations.csv.
##
## Event:   id, title, text, requires_any (own at least one, optional), choices, default (index)
## Choice:  label
##          cost_min  = costs this many minutes of income (choice locked if not enough money)
##          gain_min  = gives this many minutes of income right away
##          base      = which income source the minutes refer to (default total):
##                      keeps «costs 5 min of subscriptions» fair no matter how big they are
##          buffs     = [{target, mult, min}]  target: total, code, storage, software, mining
##          requires  = upgrades you must own for this choice
##          react     = XYMYX animation afterwards (cheer, headdesk, ...)
## If the default choice is locked, the last available choice is used.

const EVENTS := [
	{"id": "viral", "title": "Viral!",
		"text": "One of your products goes viral. The servers groan under the rush.",
		"requires_any": ["plugin", "desktop_app", "saas", "platform"],
		"choices": [
			{"label": "Scale up the servers", "cost_min": 5.0, "base": "software",
				"buffs": [{"target": "software", "mult": 2.0, "min": 15.0}], "react": "cheer"},
			{"label": "Throttle and wait",
				"buffs": [{"target": "software", "mult": 1.25, "min": 15.0}]},
		], "default": 1},
	{"id": "bad_update", "title": "Broken update",
		"text": "An update takes down your subscribers. The support inbox overflows.",
		"requires_any": ["saas", "platform", "ecosystem"],
		"choices": [
			{"label": "Hotfix right now", "cost_min": 5.0, "base": "software", "react": "stretch"},
			{"label": "Fix it tomorrow",
				"buffs": [{"target": "software", "mult": 0.5, "min": 20.0}], "react": "headdesk"},
		], "default": 1},
	{"id": "sponsor", "title": "Sponsor offer",
		"text": "A sponsor offers money but wants exclusivity for your subscriptions.",
		"requires_any": ["plugin", "desktop_app", "saas"],
		"choices": [
			{"label": "Accept", "gain_min": 20.0, "base": "software",
				"buffs": [{"target": "software", "mult": 0.8, "min": 60.0}], "react": "cheer"},
			{"label": "Decline"},
		], "default": 1},
	{"id": "coffee", "title": "Coffee machine broken",
		"text": "The coffee machine gives up. XYMYX stares sadly into his empty cup.",
		"choices": [
			{"label": "Buy a new one", "cost_min": 3.0, "base": "code",
				"buffs": [{"target": "code", "mult": 1.2, "min": 30.0}], "react": "drink"},
			{"label": "Drink tea",
				"buffs": [{"target": "code", "mult": 0.9, "min": 15.0}]},
		], "default": 1},
	{"id": "outage", "title": "Power outage",
		"text": "The power goes out in the whole neighbourhood.",
		"choices": [
			{"label": "Backup power takes over", "requires": ["ups"], "react": "cheer"},
			{"label": "Wait it out",
				"buffs": [{"target": "total", "mult": 0.5, "min": 5.0}], "react": "headdesk"},
		], "default": 0},
	{"id": "heatwave", "title": "Heatwave",
		"text": "35 degrees outside. The hardware is running hot.",
		"requires_any": ["gaming_pc"],
		"choices": [
			{"label": "Turn the AC up to max", "requires": ["ac"]},
			{"label": "Throttle performance",
				"buffs": [{"target": "total", "mult": 0.8, "min": 10.0}], "react": "headdesk"},
		], "default": 0},
	{"id": "ctf", "title": "CTF starting",
		"text": "A capture-the-flag contest begins. Joining costs time but pays prize money.",
		"choices": [
			{"label": "Join", "gain_min": 15.0,
				"buffs": [{"target": "code", "mult": 0.5, "min": 10.0}], "react": "cheer"},
			{"label": "Not this time"},
		], "default": 1},
	{"id": "bug_bounty", "title": "Vulnerability found",
		"text": "You find a vulnerability in an authorized test environment.",
		"choices": [
			{"label": "Report it (bug bounty)", "gain_min": 20.0, "react": "cheer"},
			{"label": "Ignore it"},
		], "default": 0},
	{"id": "zero_day", "title": "Zero-day",
		"text": "A zero-day hits a popular library. Your security clients need help right now.",
		"requires_any": ["test_server", "sec_lab", "monitoring"],
		"choices": [
			{"label": "Emergency response for all clients", "cost_min": 5.0, "base": "security",
				"buffs": [{"target": "security", "mult": 2.0, "min": 20.0}], "react": "cheer"},
			{"label": "Publish an advisory only",
				"buffs": [{"target": "security", "mult": 1.2, "min": 20.0}]},
		], "default": 1},
	{"id": "rgb", "title": "RGB sale",
		"text": "An online shop is dumping RGB fans. More light, more power?",
		"requires_any": ["gaming_pc"],
		"choices": [
			{"label": "Grab them", "cost_min": 3.0, "base": "code",
				"buffs": [{"target": "code", "mult": 1.3, "min": 20.0}], "react": "cheer"},
			{"label": "Stay sensible"},
		], "default": 1},
]

const TARGET_NAMES := {"total": "Everything", "code": "Coding", "storage": "Storage",
	"software": "Subscriptions", "mining": "Mining", "security": "Security", "office": "Offices"}


## Factor as text: 2 -> «x2», 1.25 -> «x1.25»
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
