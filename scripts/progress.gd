class_name Progress
extends RefCounted
## Stage 6: product updates (versions) and open-source stars.
## Stage 7: overclocking switch and contract quality levels.
## Stage 9: prestige (selling the company): know-how points and specializations.
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


# --- Stage 7: overclocking ---------------------------------------------------------
## Coding x1.3 while switched on. Needs free cooling (50 % of the current heat, at least 1)
## and OCCUPIES it: that cooling is not available for new machines while overclocking.
## Without enough cooling the PC throttles itself to x1.1 and uses what is left –
## never worse than switched off. The trade-off: coding speed now vs. room to expand.
const OC_MULT := 1.3
const OC_THROTTLED := 1.1
const OC_HEAT_SHARE := 0.5

static func overclock_need(t: Dictionary) -> float:
	return maxf(1.0, float(t["heat"]) * OC_HEAT_SHARE)


## Totals with the cooling that overclocking occupies added to «heat».
static func with_overclock_heat(t: Dictionary, on: bool) -> Dictionary:
	if not on:
		return t
	var out := t.duplicate()
	var free := float(t["cool_cap"]) - float(t["heat"])
	out["heat"] = float(t["heat"]) + clampf(overclock_need(t), 0.0, maxf(free, 0.0))
	return out


static func overclock_mult(t: Dictionary, on: bool) -> float:
	if not on:
		return 1.0
	return OC_MULT if float(t["cool_cap"]) - float(t["heat"]) >= overclock_need(t) else OC_THROTTLED


# --- Stage 7: contract quality ------------------------------------------------------
## Applied when a contract is accepted (not to product updates). The bonus target time stays
## the same, which makes it a real trade-off (checked for all types and 1–4 parallel contracts):
##   Normal:   best with 1–2 parallel contracts (bonus reachable, x1.25 per work)
##   Thorough: best with 3–4 parallel (never gets the bonus, but x1.20 per work)
##   Fast:     almost as good as thorough with 3–4 parallel (x1.19, bonus always reached),
##             pays out about 3x sooner – for when you need the money soon
const QUALITY := [
	{"name": "Fast", "work": 0.6, "reward": 0.57, "stars": 0.57},
	{"name": "Normal", "work": 1.0, "reward": 1.0, "stars": 1.0},
	{"name": "Thorough", "work": 1.75, "reward": 2.1, "stars": 2.1},
]


# --- Stage 9: prestige ---------------------------------------------------------------
## Selling is possible from SELL_MIN CHF earned in the current run. Points for this run:
## floor(5 × sqrt(run_earned / 1B)) → 1B: 5, 10B: 15, 100B: 50. Each point: +2 % on everything.
const SELL_MIN := 1.0e9
const KNOWHOW_BONUS := 0.02
const SPECS := {
	"security": {"name": "Security", "desc": "Contract rewards x1.3, event gains x2, event penalties halved, flag rewards x2"},
	"software": {"name": "Software", "desc": "Subscriptions x1.5, product updates +10 % instead of +5 %"},
	"datacenter": {"name": "Data center", "desc": "Storage and mining x1.3, power and cooling capacity +25 %"},
}

static func knowhow_points(run_earned: float) -> int:
	if run_earned < SELL_MIN:
		return 0
	return int(floor(5.0 * sqrt(run_earned / 1.0e9)))


## Contract reward multiplier of the specialization (security audits pay well).
static func spec_contract_reward(spec: String) -> float:
	return 1.3 if spec == "security" else 1.0


static func knowhow_mult(knowhow: int) -> float:
	return 1.0 + KNOWHOW_BONUS * knowhow


## Totals with the data center specialization (+25 % power and cooling capacity).
static func spec_totals(t: Dictionary, spec: String) -> Dictionary:
	if spec != "datacenter":
		return t
	var out := t.duplicate()
	out["power_cap"] = float(t["power_cap"]) * 1.25
	out["cool_cap"] = float(t["cool_cap"]) * 1.25
	return out


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
static func updatable(levels: Dictionary, versions: Dictionary, max_v := MAX_VERSION) -> Dictionary:
	var out := {}
	for p: String in UPDATE_WORK_MIN:
		if int(levels.get(p, 0)) > 0 and int(versions.get(p, 0)) < max_v:
			out[p] = int(versions.get(p, 0)) + 1
	return out


## Income per source like Economy.income(), plus product update bonuses and the
## star income multiplier. Effects from events (buffs) are applied on top by Game.
## tools: FlagData.tool_fx() of the captured CTF flags (stage 8).
## spec / knowhow: specialization and know-how points of the prestige system (stage 9).
## skill_fx: SkillData.fx() of the learned skills (stage 10), uses «net_income».
static func income(levels: Dictionary, versions: Dictionary, stars: float, overclock := false,
		tools: Dictionary = {}, spec := "", knowhow := 0, skill_fx: Dictionary = {},
		research_fx: Dictionary = {}) -> Dictionary:
	var inc := Economy.income(levels)
	var t := spec_totals(Economy.totals(levels), spec)
	var per_update := UPDATE_BONUS * (2.0 if spec == "software" else 1.0)
	var bonus := 0.0
	for p: String in UPDATE_WORK_MIN:
		if int(levels.get(p, 0)) > 0:
			bonus += float(Economy.get_def(p)["fx"]["software"]) * per_update * int(versions.get(p, 0))
	var m: float = star_fx(stars)["total_mult"] * float(tools.get("total_mult", 1.0)) * knowhow_mult(knowhow)
	var spec_sw := 1.5 if spec == "software" else 1.0
	var spec_dc := 1.3 if spec == "datacenter" else 1.0
	var net := float(tools.get("net_mult", 1.0)) * float(skill_fx.get("net_income", 1.0))
	var code: float = inc["code"] * m * overclock_mult(t, overclock) * float(tools.get("code_mult", 1.0)) \
		* float(research_fx.get("code_mult", 1.0))
	var storage: float = inc["storage"] * m * net * spec_dc * float(research_fx.get("storage_mult", 1.0))
	var software: float = (inc["software"] + bonus * t["net_mult"] * t["software_mult"]) * m * net \
		* float(tools.get("software_mult", 1.0)) * spec_sw
	var mining: float = inc["mining"] * m * spec_dc
	# Stage 11: security business, boosted by pentesting and the security specialization
	var security: float = inc["security"] * m * float(skill_fx.get("security_income", 1.0)) \
		* (1.5 if spec == "security" else 1.0)
	return {"code": code, "storage": storage, "software": software, "mining": mining, "security": security,
		"total": code + storage + software + mining + security}
