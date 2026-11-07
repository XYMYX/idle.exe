class_name AcquisitionData
extends RefCounted
## Stage 14: acquisitions. A fixed list of 5 (made-up) companies. Buying one costs money
## once and gives a permanent multiplier for the rest of the run. Acquisitions are reset
## when the company is sold.
##
## fx keys (multipliers): storage_mult, software_mult, security_mult, office_mult,
##                        code_mult, contract_reward

const COMPANIES := [
	{"id": "hosting", "name": "PixelHost GmbH", "kind": "Hosting startup", "cost": 30.0e6, "requires": "office_small",
		"desc": "Storage x1.5", "fx": {"storage_mult": 1.5}},
	{"id": "app_studio", "name": "Tiny Apps AG", "kind": "Indie app studio", "cost": 150.0e6, "requires": "saas",
		"desc": "Subscriptions x1.5", "fx": {"software_mult": 1.5}},
	{"id": "consulting", "name": "Byte & Partner", "kind": "Consulting agency", "cost": 300.0e6, "requires": "office_city",
		"desc": "Contract rewards x1.5", "fx": {"contract_reward": 1.5}},
	{"id": "sec_boutique", "name": "RedLeaf Security", "kind": "Security boutique", "cost": 800.0e6, "requires": "sec_lab",
		"desc": "Security x1.5", "fx": {"security_mult": 1.5}},
	{"id": "chip_design", "name": "Nullgate Silicon", "kind": "Chip designer", "cost": 2.5e9, "requires": "colocation",
		"desc": "Coding x2, locations x1.5", "fx": {"code_mult": 2.0, "office_mult": 1.5}},
]

const FX_KEYS := ["storage_mult", "software_mult", "security_mult", "office_mult", "code_mult", "contract_reward"]


static func get_company(id: String) -> Dictionary:
	for c: Dictionary in COMPANIES:
		if c["id"] == id:
			return c
	return {}


## Combined multipliers of all owned companies.
static func fx(owned: Dictionary) -> Dictionary:
	var out := {}
	for k: String in FX_KEYS:
		out[k] = 1.0
	for c: Dictionary in COMPANIES:
		if owned.get(c["id"], false):
			for k: String in c["fx"]:
				out[k] = float(out[k]) * float(c["fx"][k])
	return out


## Research fx and acquisition fx together (multipliers with the same key multiply,
## everything else is taken over). Progress.income reads the result.
static func merge(research_fx: Dictionary, acq_fx: Dictionary) -> Dictionary:
	var out := research_fx.duplicate()
	for k: String in acq_fx:
		out[k] = float(out.get(k, 1.0)) * float(acq_fx[k])
	return out
