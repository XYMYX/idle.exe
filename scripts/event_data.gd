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
## requires_cat = only when the cat is adopted (optional)
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
	# --- Second set (2026-11-08) ---------------------------------------------------
	{"id": "stack_down", "title": "Q&A site down",
		"text": "The site with all the answers is offline. XYMYX has to think for himself.",
		"choices": [
			{"label": "Read the docs", "buffs": [{"target": "code", "mult": 1.1, "min": 20.0}], "react": "stretch"},
			{"label": "Wait until it's back", "buffs": [{"target": "code", "mult": 0.85, "min": 10.0}]},
		], "default": 1},
	{"id": "hackathon", "title": "Hackathon",
		"text": "A weekend hackathon with prize money. It eats coding time.",
		"choices": [
			{"label": "Join the team", "gain_min": 12.0,
				"buffs": [{"target": "code", "mult": 0.7, "min": 15.0}], "react": "cheer"},
			{"label": "Keep working"},
		], "default": 1},
	{"id": "code_review", "title": "Brutal code review",
		"text": "A senior dev tears XYMYX's pull request apart. 87 comments.",
		"choices": [
			{"label": "Fix every comment", "cost_min": 3.0, "base": "code",
				"buffs": [{"target": "code", "mult": 1.25, "min": 30.0}], "react": "stretch"},
			{"label": "Mark as resolved", "react": "headdesk"},
		], "default": 1},
	{"id": "phishing", "title": "Phishing mail",
		"text": "«Your account will be closed, click here.» The sender looks suspicious.",
		"choices": [
			{"label": "Report it", "gain_min": 5.0, "react": "cheer"},
			{"label": "Click the link", "buffs": [{"target": "total", "mult": 0.7, "min": 10.0}], "react": "headdesk"},
		], "default": 0},
	{"id": "keyboard_spill", "title": "Coffee on the keyboard",
		"text": "A whole cup of coffee in the mechanical keyboard. The space bar sticks.",
		"requires_any": ["keyboard"],
		"choices": [
			{"label": "Buy a new keyboard", "cost_min": 2.0, "base": "code", "react": "drink"},
			{"label": "Dry it with a hair dryer", "buffs": [{"target": "code", "mult": 0.85, "min": 15.0}]},
		], "default": 1},
	{"id": "firmware", "title": "Firmware update",
		"text": "The router wants a firmware update. It promises more speed.",
		"requires_any": ["router"],
		"choices": [
			{"label": "Update now", "buffs": [{"target": "storage", "mult": 1.2, "min": 30.0}], "react": "stretch"},
			{"label": "Never touch a running system"},
		], "default": 0},
	{"id": "ddos", "title": "DDoS attack",
		"text": "Thousands of bots hammer your subscription servers.",
		"requires_any": ["saas", "platform", "ecosystem"],
		"choices": [
			{"label": "Turn on DDoS protection", "cost_min": 5.0, "base": "software", "react": "cheer"},
			{"label": "Ride it out", "buffs": [{"target": "software", "mult": 0.5, "min": 15.0}], "react": "headdesk"},
		], "default": 1},
	{"id": "black_friday", "title": "Black Friday",
		"text": "Everyone wants a deal. Should your products join in?",
		"requires_any": ["plugin", "desktop_app", "saas"],
		"choices": [
			{"label": "Run a sale", "buffs": [{"target": "software", "mult": 1.6, "min": 30.0}], "react": "cheer"},
			{"label": "No discounts"},
		], "default": 0},
	{"id": "big_bug", "title": "Bug report from a big client",
		"text": "A big client found a bug on Friday evening. They pay extra for a quick fix.",
		"requires_any": ["saas", "platform"],
		"choices": [
			{"label": "Fix it over the weekend", "gain_min": 15.0, "base": "software",
				"buffs": [{"target": "code", "mult": 0.7, "min": 15.0}], "react": "drink"},
			{"label": "Fix it on Monday"},
		], "default": 1},
	{"id": "crypto_boom", "title": "Crypto boom",
		"text": "Prices are exploding. Every hash counts right now.",
		"requires_any": ["asic", "asic_shelf", "mining_rack"],
		"choices": [
			{"label": "Mine at full power", "buffs": [{"target": "mining", "mult": 2.0, "min": 20.0}], "react": "cheer"},
			{"label": "Sell the reserves", "gain_min": 15.0, "base": "mining"},
		], "default": 0},
	{"id": "crypto_crash", "title": "Crypto crash",
		"text": "Overnight the coin lost half its value.",
		"requires_any": ["asic", "asic_shelf", "mining_rack"],
		"choices": [
			{"label": "Switch to another coin", "cost_min": 3.0, "base": "mining", "react": "stretch"},
			{"label": "Hold on", "buffs": [{"target": "mining", "mult": 0.5, "min": 30.0}], "react": "headdesk"},
		], "default": 1},
	{"id": "power_price", "title": "Power price spike",
		"text": "The electricity bill for the mining hardware is suddenly twice as high.",
		"requires_any": ["mining_rack", "mining_container", "mining_farm"],
		"choices": [
			{"label": "Throttle mining", "buffs": [{"target": "mining", "mult": 0.7, "min": 30.0}]},
			{"label": "Pay the bill", "cost_min": 5.0, "base": "mining"},
		], "default": 0},
	{"id": "disk_failure", "title": "Disk failure",
		"text": "A disk in the storage array dies with a loud click.",
		"requires_any": ["nas", "storage_server", "storage_cloud"],
		"choices": [
			{"label": "Restore from backup", "requires": ["nightly_backups"], "react": "cheer"},
			{"label": "Rebuild the array", "buffs": [{"target": "storage", "mult": 0.5, "min": 20.0}], "react": "headdesk"},
		], "default": 0},
	{"id": "conference", "title": "Conference talk",
		"text": "XYMYX is invited to give a talk. Good for the reputation, bad for the schedule.",
		"requires_any": ["coworking", "office_small"],
		"choices": [
			{"label": "Give the talk", "cost_min": 3.0, "base": "code",
				"buffs": [{"target": "total", "mult": 1.2, "min": 30.0}], "react": "cheer"},
			{"label": "Stay home"},
		], "default": 1},
	{"id": "intern", "title": "New intern",
		"text": "An intern starts at the office today and asks a lot of questions.",
		"requires_any": ["coworking", "office_small", "office_city"],
		"choices": [
			{"label": "Mentor them", "buffs": [{"target": "office", "mult": 1.5, "min": 30.0},
				{"target": "code", "mult": 0.9, "min": 30.0}], "react": "stretch"},
			{"label": "Give them the docs"},
		], "default": 1},
	{"id": "office_party", "title": "Office party",
		"text": "The team wants a party. Morale or budget?",
		"requires_any": ["office_city", "colocation", "campus"],
		"choices": [
			{"label": "Throw a party", "cost_min": 3.0, "base": "office",
				"buffs": [{"target": "office", "mult": 1.6, "min": 30.0}], "react": "cheer"},
			{"label": "Maybe next quarter", "buffs": [{"target": "office", "mult": 0.9, "min": 20.0}]},
		], "default": 1},
	{"id": "gpu_shortage", "title": "GPU shortage",
		"text": "No graphics cards available anywhere. The cluster can't grow.",
		"requires_any": ["gpu_cluster"],
		"choices": [
			{"label": "Rent cloud GPUs", "cost_min": 4.0, "base": "code",
				"buffs": [{"target": "code", "mult": 1.3, "min": 20.0}]},
			{"label": "Wait for stock", "buffs": [{"target": "code", "mult": 0.85, "min": 20.0}]},
		], "default": 1},
	{"id": "ai_hype", "title": "AI hype",
		"text": "Everyone suddenly wants AI in everything. Investors are calling.",
		"requires_any": ["training_servers", "own_llm"],
		"choices": [
			{"label": "Ride the hype", "buffs": [{"target": "software", "mult": 2.0, "min": 20.0}], "react": "cheer"},
			{"label": "Stay calm", "buffs": [{"target": "software", "mult": 1.2, "min": 20.0}]},
		], "default": 1},
	{"id": "model_leak", "title": "Model weights leaked",
		"text": "Someone published the weights of your language model.",
		"requires_any": ["own_llm"],
		"choices": [
			{"label": "Make it open source", "gain_min": 10.0, "base": "software", "react": "cheer"},
			{"label": "Call the lawyers", "cost_min": 5.0, "base": "software", "react": "headdesk"},
		], "default": 0},
	{"id": "decoherence", "title": "Qubit decoherence",
		"text": "The qubits lose their state too early. The results are noise.",
		"requires_any": ["qubit_chip"],
		"choices": [
			{"label": "Recalibrate", "cost_min": 3.0, "base": "code", "react": "stretch"},
			{"label": "Live with the noise", "buffs": [{"target": "code", "mult": 0.8, "min": 20.0}], "react": "headdesk"},
		], "default": 1},
	{"id": "solar_storm", "title": "Solar storm",
		"text": "A solar storm hits the satellites. Data links are flickering.",
		"requires_any": ["sat_uplink", "own_satellite"],
		"choices": [
			{"label": "Shield the satellites", "cost_min": 4.0, "base": "storage", "react": "cheer"},
			{"label": "Switch to safe mode", "buffs": [{"target": "storage", "mult": 0.7, "min": 15.0}]},
		], "default": 1},
	{"id": "cat_keyboard", "title": "Cat on the keyboard",
		"text": "The cat lies down on the keyboard and purrs. «asdfjjjjjjjjjjj»",
		"requires_cat": true,
		"choices": [
			{"label": "Let her sleep there", "buffs": [{"target": "code", "mult": 0.8, "min": 10.0}], "react": "drink"},
			{"label": "Pet her and lift her down", "buffs": [{"target": "code", "mult": 1.1, "min": 10.0}], "react": "cheer"},
		], "default": 0},
	{"id": "cat_cable", "title": "Chewed cable",
		"text": "The cat has found a new toy: the network cable.",
		"requires_cat": true,
		"choices": [
			{"label": "Buy cable protectors", "cost_min": 2.0, "base": "code"},
			{"label": "Hope she stops", "buffs": [{"target": "total", "mult": 0.9, "min": 10.0}], "react": "headdesk"},
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
