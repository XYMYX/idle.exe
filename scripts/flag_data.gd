class_name FlagData
extends RefCounted
## Stage 8a: CTF flags (milestones). Capturing a flag pays money once and unlocks a
## rare tool with a permanent bonus. Nothing is required, nothing can be lost.
## Flag names stay as they are (they are flags); goal texts are translated.
##
## goal:   earned (total CHF earned), contracts (delivered), owns (upgrade id), stars,
##         events (resolved), updates (product updates delivered), combo (highest jump level),
##         naps (times XYMYX fell asleep), all_upgrades (every one-off upgrade owned),
##         pets (cat petted), sales (company sold), research (projects finished),
##         acquisitions (companies bought), locations (owned), skill ("id:level"),
##         flags (all other flags captured)
## target: number to reach (for owns/all_upgrades: 1, skill: "id:level", flags: ignored)
## reward_min: one-time money in minutes of income
## tool:   {name, fx} with fx keys: code_mult, net_mult, software_mult, total_mult,
##         contract_reward, contract_speed, star_mult, event_gain

const FLAGS := [
	{"id": "hello_world", "goal": "earned", "target": 1000.0, "reward_min": 5.0,
		"text": "Earn 1,000 CHF in total", "tool": {"name": "Nano", "fx": {"code_mult": 1.05}}},
	{"id": "first_client", "goal": "contracts", "target": 1.0, "reward_min": 5.0,
		"text": "Deliver your first contract", "tool": {"name": "Git", "fx": {"contract_reward": 1.05}}},
	{"id": "power_nap", "goal": "naps", "target": 1.0, "reward_min": 5.0,
		"text": "Let XYMYX fall asleep once", "tool": {"name": "Coffee script", "fx": {"code_mult": 1.03}}},
	{"id": "trampoline", "goal": "combo", "target": 7.0, "reward_min": 5.0,
		"text": "Reach the highest combo jump", "tool": {"name": "Spring boots", "fx": {"code_mult": 1.03}}},
	{"id": "root_access", "goal": "owns", "target": "homeserver", "reward_min": 10.0,
		"text": "Own a home server", "tool": {"name": "SSH keys", "fx": {"contract_speed": 1.05}}},
	{"id": "packet_sniffer", "goal": "owns", "target": "fiber", "reward_min": 10.0,
		"text": "Own a fiber connection", "tool": {"name": "Wireshark", "fx": {"net_mult": 1.05}}},
	{"id": "crisis_manager", "goal": "events", "target": 10.0, "reward_min": 15.0,
		"text": "Resolve 10 events", "tool": {"name": "Incident runbook", "fx": {"event_gain": 1.25}}},
	{"id": "open_source", "goal": "stars", "target": 50.0, "reward_min": 15.0,
		"text": "Collect 50 stars", "tool": {"name": "Ghidra", "fx": {"star_mult": 1.1}}},
	{"id": "ship_it", "goal": "updates", "target": 10.0, "reward_min": 20.0,
		"text": "Deliver 10 product updates", "tool": {"name": "CI badges", "fx": {"software_mult": 1.05}}},
	{"id": "bounty_hunter", "goal": "contracts", "target": 25.0, "reward_min": 20.0,
		"text": "Deliver 25 contracts", "tool": {"name": "Burp Suite", "fx": {"contract_reward": 1.1}}},
	{"id": "billionaire", "goal": "earned", "target": 1.0e9, "reward_min": 30.0,
		"text": "Earn 1B CHF in total", "tool": {"name": "Nmap", "fx": {"total_mult": 1.05}}},
	{"id": "full_stack", "goal": "all_upgrades", "target": 1.0, "reward_min": 60.0,
		"text": "Own every one-off upgrade", "tool": {"name": "XYMYX OS", "fx": {"total_mult": 1.1}}},
	# --- Second set (2026-11-08) ---------------------------------------------------
	{"id": "missing_byte", "goal": "earned", "target": 100000.0, "reward_min": 5.0,
		"text": "Earn 100K CHF in total", "tool": {"name": "Hex editor", "fx": {"code_mult": 1.03}}},
	{"id": "lost_packet", "goal": "contracts", "target": 10.0, "reward_min": 10.0,
		"text": "Deliver 10 contracts", "tool": {"name": "Retry loop", "fx": {"contract_speed": 1.03}}},
	{"id": "midnight_breach", "goal": "naps", "target": 10.0, "reward_min": 10.0,
		"text": "Let XYMYX fall asleep 10 times", "tool": {"name": "Night shift", "fx": {"code_mult": 1.03}}},
	{"id": "ghost_session", "goal": "pets", "target": 25.0, "reward_min": 10.0,
		"text": "Pet the cat 25 times", "tool": {"name": "Purr.exe", "fx": {"event_gain": 1.1}}},
	{"id": "kernel_panic", "goal": "events", "target": 25.0, "reward_min": 15.0,
		"text": "Resolve 25 events", "tool": {"name": "Watchdog", "fx": {"event_gain": 1.15}}},
	{"id": "secret_branch", "goal": "updates", "target": 25.0, "reward_min": 20.0,
		"text": "Deliver 25 product updates", "tool": {"name": "Feature flags", "fx": {"software_mult": 1.05}}},
	{"id": "last_commit", "goal": "contracts", "target": 100.0, "reward_min": 30.0,
		"text": "Deliver 100 contracts", "tool": {"name": "Commit hooks", "fx": {"contract_reward": 1.1}}},
	{"id": "phantom_port", "goal": "owns", "target": "vm_honeypot", "reward_min": 15.0,
		"text": "Own a honeypot VM", "tool": {"name": "Port scanner", "fx": {"star_mult": 1.1}}},
	{"id": "forgotten_backup", "goal": "owns", "target": "nightly_backups", "reward_min": 20.0,
		"text": "Own nightly backups", "tool": {"name": "Restore script", "fx": {"net_mult": 1.05}}},
	{"id": "broken_cipher", "goal": "skill", "target": "pentesting:3", "reward_min": 20.0,
		"text": "Reach pentesting level 3", "tool": {"name": "Hashcat", "fx": {"contract_reward": 1.05}}},
	{"id": "black_box", "goal": "research", "target": 3.0, "reward_min": 20.0,
		"text": "Finish 3 research projects", "tool": {"name": "Lab notes", "fx": {"contract_speed": 1.05}}},
	{"id": "zero_trust", "goal": "locations", "target": 3.0, "reward_min": 20.0,
		"text": "Own 3 locations", "tool": {"name": "VPN mesh", "fx": {"net_mult": 1.05}}},
	{"id": "shadow_admin", "goal": "acquisitions", "target": 3.0, "reward_min": 30.0,
		"text": "Acquire 3 companies", "tool": {"name": "Holding", "fx": {"total_mult": 1.03}}},
	{"id": "cold_boot", "goal": "sales", "target": 1.0, "reward_min": 10.0,
		"text": "Sell your company once", "tool": {"name": "Bootloader", "fx": {"code_mult": 1.05}}},
	{"id": "terminal_zero", "goal": "sales", "target": 3.0, "reward_min": 30.0,
		"text": "Sell your company 3 times", "tool": {"name": "Root shell", "fx": {"total_mult": 1.05}}},
	{"id": "final_flag", "goal": "flags", "target": 0.0, "reward_min": 60.0,
		"text": "Capture every other flag", "tool": {"name": "Hall of fame", "fx": {"total_mult": 1.1}}},
]


static func get_flag(id: String) -> Dictionary:
	for f: Dictionary in FLAGS:
		if f["id"] == id:
			return f
	return {}


## Display name «flag{first_client}».
static func flag_name(f: Dictionary) -> String:
	return "flag{%s}" % f["id"]


## Combined tool bonuses of all captured flags.
static func tool_fx(captured: Dictionary) -> Dictionary:
	var fx := {"code_mult": 1.0, "net_mult": 1.0, "software_mult": 1.0, "total_mult": 1.0,
		"contract_reward": 1.0, "contract_speed": 1.0, "star_mult": 1.0, "event_gain": 1.0}
	for f: Dictionary in FLAGS:
		if captured.get(f["id"], false):
			for k: String in f["tool"]["fx"]:
				fx[k] *= float(f["tool"]["fx"][k])
	return fx
