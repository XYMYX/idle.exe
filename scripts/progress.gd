class_name Progress
extends RefCounted
## Stage 6: product updates (versions) and open-source stars.
## Pure functions shared by the game and the balancing simulation, so both compute the same.
##
## Product updates: each delivered update gives that product +5 % of its subscription
## income for good (up to version 1.10 = +50 %). Nothing ever decays.
## Stars: not a currency. Reaching a tier unlocks a permanent bonus.

const UPDATE_BONUS := 0.05
const MAX_VERSION := 10
## Products that can get updates, with the update's workload (minutes, like contracts)
const UPDATE_WORK_MIN := {"plugin": 5.0, "desktop_app": 10.0, "saas": 20.0, "platform": 40.0, "ecosystem": 60.0}

## Star tiers in order. fx: contract_reward / contract_speed / total_mult (multipliers)
const STAR_TIERS := [
	{"stars": 10, "name": "Better contracts", "fx": {"contract_reward": 1.1}},
	{"stars": 50, "name": "Contributors", "fx": {"contract_speed": 1.1}},
	{"stars": 150, "name": "Sponsors", "fx": {"total_mult": 1.05}},
	{"stars": 500, "name": "Famous", "fx": {"contract_reward": 1.25, "total_mult": 1.05}},
]


## Combined multipliers of all reached star tiers.
static func star_fx(stars: float) -> Dictionary:
	var fx := {"contract_reward": 1.0, "contract_speed": 1.0, "total_mult": 1.0}
	for tier: Dictionary in STAR_TIERS:
		if stars >= float(tier["stars"]):
			for k: String in tier["fx"]:
				fx[k] *= float(tier["fx"][k])
	return fx


## Next tier not reached yet, {} if all are reached.
static func next_tier(stars: float) -> Dictionary:
	for tier: Dictionary in STAR_TIERS:
		if stars < float(tier["stars"]):
			return tier
	return {}


static func reached_tiers(stars: float) -> Array:
	return STAR_TIERS.filter(func(t: Dictionary) -> bool: return stars >= float(t["stars"]))


## Owned products that can still get an update: {id: next_version}
static func updatable(levels: Dictionary, versions: Dictionary) -> Dictionary:
	var out := {}
	for p: String in UPDATE_WORK_MIN:
		if int(levels.get(p, 0)) > 0 and int(versions.get(p, 0)) < MAX_VERSION:
			out[p] = int(versions.get(p, 0)) + 1
	return out


## Income per source like Economy.income(), plus product update bonuses and the
## star income multiplier. Effects from events (buffs) are applied on top by Game.
static func income(levels: Dictionary, versions: Dictionary, stars: float) -> Dictionary:
	var inc := Economy.income(levels)
	var t := Economy.totals(levels)
	var bonus := 0.0
	for p: String in UPDATE_WORK_MIN:
		if int(levels.get(p, 0)) > 0:
			bonus += float(Economy.get_def(p)["fx"]["software"]) * UPDATE_BONUS * int(versions.get(p, 0))
	var m: float = star_fx(stars)["total_mult"]
	var code: float = inc["code"] * m
	var storage: float = inc["storage"] * m
	var software: float = (inc["software"] + bonus * t["net_mult"]) * m
	var mining: float = inc["mining"] * m
	return {"code": code, "storage": storage, "software": software, "mining": mining,
		"total": code + storage + software + mining}
