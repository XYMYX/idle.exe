class_name ResearchData
extends RefCounted
## Stage 12: research. A project costs money once and then runs in real time in the
## background (also offline). Only one project at a time. Research raises limits of
## existing systems. It is reset when the company is sold.
##
## fx keys: storage_mult, code_mult, contract_speed (multipliers),
##          max_version (product updates up to this version), vm_max (VMs per type),
##          bonus_slots (extra contract slots)

const PROJECTS := [
	{"id": "compression", "name": "Data compression", "cost": 5.0e6, "minutes": 30.0, "requires": "nas",
		"desc": "Storage x1.25", "fx": {"storage_mult": 1.25}},
	{"id": "lts", "name": "Long-term support", "cost": 20.0e6, "minutes": 60.0, "requires": "saas",
		"desc": "Product updates up to v1.15", "fx": {"max_version": 15}},
	{"id": "vm_density", "name": "VM density", "cost": 15.0e6, "minutes": 45.0, "requires": "homeserver",
		"desc": "Up to 8 VMs per type", "fx": {"vm_max": 8}},
	{"id": "pipelines", "name": "Parallel pipelines", "cost": 40.0e6, "minutes": 90.0, "requires": "workstation",
		"desc": "A 5th contract slot", "fx": {"bonus_slots": 1}},
	{"id": "own_chips", "name": "Own chips", "cost": 500.0e6, "minutes": 240.0, "requires": "workstation",
		"desc": "Coding x1.5", "fx": {"code_mult": 1.5}},
	{"id": "ai_pair", "name": "AI pair programmer", "cost": 2.0e9, "minutes": 360.0, "requires": "platform",
		"desc": "Contracts 25 % faster", "fx": {"contract_speed": 1.25}},
]

const BASE_MAX_VERSION := 10
const BASE_VM_MAX := 5
const VM_IDS := ["vm_ci", "vm_game", "vm_honeypot"]


static func get_project(id: String) -> Dictionary:
	for p: Dictionary in PROJECTS:
		if p["id"] == id:
			return p
	return {}


## Combined effects of all finished projects.
static func fx(done: Dictionary) -> Dictionary:
	var out := {"storage_mult": 1.0, "code_mult": 1.0, "contract_speed": 1.0,
		"max_version": BASE_MAX_VERSION, "vm_max": BASE_VM_MAX, "bonus_slots": 0}
	for p: Dictionary in PROJECTS:
		if not done.get(p["id"], false):
			continue
		for k: String in p["fx"]:
			if k in ["max_version", "vm_max"]:
				out[k] = maxi(int(out[k]), int(p["fx"][k]))
			elif k == "bonus_slots":
				out[k] = int(out[k]) + int(p["fx"][k])
			else:
				out[k] = float(out[k]) * float(p["fx"][k])
	return out


## Highest level an upgrade can reach with the given research (VMs can go above 5).
static func max_level(u: Dictionary, research_fx: Dictionary) -> int:
	if u["id"] in VM_IDS:
		return int(research_fx.get("vm_max", BASE_VM_MAX))
	return Economy.max_level(u)
