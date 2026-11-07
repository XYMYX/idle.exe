class_name ContractData
extends RefCounted
## Contract types for stage 5a. English source strings; German translations will be
## added to i18n/translations.csv together with the terminal view (step 3).
##
## work_min    = minutes one contract takes alone (at its 50 % share of the coding income,
##               scaled to the income at offer time); parallel contracts take longer
## target_min  = finish within this time for the speed bonus (no failure if slower)
## reward_mult = reward = workload × reward_mult
## requires    = upgrade that unlocks the type ("" = always)

const TYPES := [
	{"id": "script", "name": "Script", "work_min": 3.0, "target_min": 5.0, "reward_mult": 1.3, "requires": "",
		"titles": ["Fix a broken Excel macro", "Write a backup script", "Discord bot for a gaming clan"]},
	{"id": "website", "name": "Website", "work_min": 10.0, "target_min": 15.0, "reward_mult": 1.5, "requires": "monitor_2",
		"titles": ["Website for a bakery", "Portfolio site for a photographer", "Fix a client's WordPress"]},
	{"id": "app", "name": "App", "work_min": 30.0, "target_min": 45.0, "reward_mult": 1.8, "requires": "gaming_pc",
		"titles": ["Inventory app for a bike shop", "Fitness tracker app", "Booking app for a hair salon"]},
	{"id": "client", "name": "Client project", "work_min": 90.0, "target_min": 120.0, "reward_mult": 2.1, "requires": "homeserver",
		"titles": ["Online shop for a watchmaker", "CRM for a small agency", "Data dashboard for a city"]},
	{"id": "enterprise", "name": "Enterprise", "work_min": 240.0, "target_min": 360.0, "reward_mult": 2.4, "requires": "rack",
		"titles": ["Banking API migration", "Logistics platform", "Hospital scheduling system"]},
]


static func get_type(id: String) -> Dictionary:
	for t: Dictionary in TYPES:
		if t["id"] == id:
			return t
	return {}
