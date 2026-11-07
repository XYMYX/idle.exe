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


## Stage 6: special contract kinds that appear on the same board.
## «update»: a product update (no money, product +5 % subscriptions for good).
## «oss»: an open-source project (no money, stars).
const UPDATE_TYPE := {"id": "update", "name": "Update"}
const OSS_TYPE := {"id": "oss", "name": "Open source", "work_min": 20.0, "target_min": 30.0, "requires": "gaming_pc",
	"titles": ["Open-source logging library", "CLI tool for Git hooks", "Pixel art editor plugin",
		"Godot shader collection", "Security scanner for CI pipelines"]}
const UPDATE_CHANCE := 0.25  # share of new offers that are product updates (if possible)
const OSS_CHANCE := 0.2      # share of new offers that are open-source projects (if unlocked)


## Display name of any contract type id, incl. the special kinds.
static func type_name(id: String) -> String:
	if id == UPDATE_TYPE["id"]:
		return UPDATE_TYPE["name"]
	if id == OSS_TYPE["id"]:
		return OSS_TYPE["name"]
	return get_type(id).get("name", id)


static func get_type(id: String) -> Dictionary:
	for t: Dictionary in TYPES:
		if t["id"] == id:
			return t
	return {}
