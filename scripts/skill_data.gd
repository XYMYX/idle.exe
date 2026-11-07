class_name SkillData
extends RefCounted
## Stage 10: training. Courses appear on the contract board (kind «course»), cost coding
## time like a contract, pay no money and raise a skill by one level (0–5).
## Skills stay when the company is sold (knowledge is never lost).
##
## boosts:  contract types whose rewards get +REWARD_PER_LEVEL per level
## fx:      extra effects per level: contract_speed, net_income (storage + subscriptions),
##          event_gain (all multiplicative per level: 1 + value × level)
## requires: upgrade needed before courses for this skill appear ("" = always)

const MAX_LEVEL := 5
const REWARD_PER_LEVEL := 0.10
const COURSE_WORK_MIN := [10.0, 20.0, 40.0, 80.0, 160.0]  # course for level 1..5
const COURSE_CHANCE := 0.15  # share of new offers that are courses (if one can be learned)

const SKILLS := [
	{"id": "python", "name": "Python", "course": "Learn Python", "requires": "",
		"boosts": ["script", "client", "automation"], "fx": {}},
	{"id": "javascript", "name": "JavaScript", "course": "Learn JavaScript", "requires": "monitor_2",
		"boosts": ["website", "app"], "fx": {}},
	{"id": "rust", "name": "Rust", "course": "Learn Rust", "requires": "gaming_pc",
		"boosts": ["enterprise"], "fx": {"contract_speed": 0.02}},
	{"id": "devops", "name": "DevOps", "course": "Learn DevOps", "requires": "homeserver",
		"boosts": [], "fx": {"net_income": 0.03}},
	{"id": "pentesting", "name": "Pentesting", "course": "Pentesting course", "requires": "gaming_pc",
		"boosts": ["audit"], "fx": {"event_gain": 0.10}},
]


static func get_skill(id: String) -> Dictionary:
	for s: Dictionary in SKILLS:
		if s["id"] == id:
			return s
	return {}


## Skills whose next course can appear now: {id: next_level}
static func learnable(levels: Dictionary, skills: Dictionary) -> Dictionary:
	var out := {}
	for s: Dictionary in SKILLS:
		var lv := int(skills.get(s["id"], 0))
		if lv < MAX_LEVEL and (s["requires"] == "" or int(levels.get(s["requires"], 0)) > 0):
			out[s["id"]] = lv + 1
	return out


## Reward multiplier for a contract type from all skills that boost it.
static func reward_mult(skills: Dictionary, contract_type: String) -> float:
	var m := 1.0
	for s: Dictionary in SKILLS:
		if contract_type in s["boosts"]:
			m *= 1.0 + REWARD_PER_LEVEL * int(skills.get(s["id"], 0))
	return m


## Combined extra effects: {contract_speed, net_income, event_gain} as multipliers.
static func fx(skills: Dictionary) -> Dictionary:
	var out := {"contract_speed": 1.0, "net_income": 1.0, "event_gain": 1.0}
	for s: Dictionary in SKILLS:
		var lv := int(skills.get(s["id"], 0))
		for k: String in s["fx"]:
			out[k] *= 1.0 + float(s["fx"][k]) * lv
	return out


## Number of skills with at least level 1 (for the certificates on the wall).
static func learned_count(skills: Dictionary) -> int:
	var n := 0
	for s: Dictionary in SKILLS:
		if int(skills.get(s["id"], 0)) > 0:
			n += 1
	return n
