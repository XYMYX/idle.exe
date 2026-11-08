# idle.exe – Design

As of 2026-11-07. Principle: everything runs on its own. Interacting is optional and rewarded, never punished.

## Core
- **Visible setup on the strip.** Everything bought appears next to the desk: old laptop → gaming PC → several monitors → water cooling → server room/homelab. Every part = one sprite (see «Graphics»).
- **One currency: money (CHF).** Income sources: coding (XYMYX + hardware), storage (backups, rented storage), software (subscriptions), mining. Stars (open source) will not be a currency but an unlock requirement.
- **Bilingual:** English and German. English is the source language in the code, German lives in `i18n/translations.csv`. On first start the language follows Windows; it can be switched in the right-click menu.

## Upgrade structure (since 2026-11-07, data in `scripts/economy.gd`)
- Categories → lines → tiers. A tier can only be bought once the previous tier of its line is owned.
- Several requirements per tier (e.g. the NAS needs the home server, the cloud needs the second line).
- **Power (kW) and cooling** are budgets: machines consume them, power and cooling upgrades raise them. The mining farm only works with enough power and cooling.
- The network acts as a multiplier on storage and software income (more hosting customers).
- Terminal: categories on the left (* = something affordable, «locked»), lines or the current + next two tiers on the right, bought tiers collapsed. Green = affordable, grey = bought, yellow = requirement missing; the text always states the status as well.
- Balancing goal: an optimal always-on player needs ~26 h for everything (simulation); with the offline cap it takes several days.
- Later: build infrastructure, security, training, locations, research, acquisitions. Power running costs (own power lowers them) are not implemented yet.

## Systems by stage

### Stage 4 – Foundation (done)
- Offline progress, max. 8 hours.
- Upgrade menu in terminal style.
- Visible setup tiers: laptop → PC → monitors.

### Stage 5 – Contracts and automation (done 2026-11-07)
Split into **5a contracts** and **5b automation**, one commit each. Principles stay: no failure, no deadlines, offline-safe.

#### 5a – Contracts
- **Idea:** XYMYX can take on client work. A contract turns part of his coding output into a bigger one-off reward. Contracts are optional – without them the game runs exactly as now.
- **How progress works:** while a contract is active, **50 % of the coding income** (`Game.base_income("code")`) goes into the contract instead of the wallet. The contract has a workload `W` in CHF of coding output. When `W` is reached, the reward is `W × reward_mult`.
  - `reward_mult` is 1.3 (script) up to 2.4 (enterprise), so contracts always pay off, but you «invest» time.
  - **Speed bonus:** finished within `target_min` → reward ×1.25. Slower is fine, there is no failure.
  - Workload is scaled to the current coding income when the offer is created (`W = coding/s × 60 × work_min`), so contracts stay relevant late game.
  - Contracts progress **offline** too (same 8 h cap, same 50 % share).
- **Contract types** (data in `scripts/contract_data.gd`, English names + German in CSV):

  | Type | work_min | target_min | reward_mult | Requires |
  |---|---|---|---|---|
  | Script | 3 | 5 | 1.3 | – |
  | Website | 10 | 15 | 1.5 | `monitor_2` |
  | App | 30 | 45 | 1.8 | `gaming_pc` |
  | Client project | 90 | 120 | 2.1 | `homeserver` |
  | Enterprise | 240 | 360 | 2.4 | `rack` |

  Each type gets 3–4 flavour titles (e.g. «Fix a client's WordPress», «Discord bot», «Inventory app for a bakery»).
- **Offers:** 3 offers on the board, a new one every 5 min (max. 3). Picked from the unlocked types, weighted towards the highest unlocked type.
- **Slots (parallel projects):** 1 base slot, +1 each from `ram` level 25, `workstation`, `rack` (max. 4). This gives RAM the «parallel projects» meaning from the original idea.
- **Delivery:** a finished contract waits with **[DELIVER]** until clicked (reward is safe, never lost). XYMYX cheers and shows a heart emote; the money counter shows «+X». Automation (5b) makes this automatic.
- **Terminal:** new category **«Contracts»** at the top of the list:
  - active contracts with an ASCII progress bar `[#######.....] 58%  ETA 4:12  bonus 2:30`
  - finished contracts with **[DELIVER]** (green)
  - offers with **[ACCEPT]** (grey if no free slot), showing workload, reward and bonus time
  - category marker `*` when something can be delivered or accepted
- **Save:** `save.json` version 3 with `contracts: {active: [...], offers: [...], next_offer_in}`; loading a version 2 save starts with an empty board.
- **New/changed files:** `scripts/contract_data.gd`, `scripts/contracts.gd` (Node, owned by `Game` or a child of main), `game.gd` (income split, save/load, offline), `terminal_menu.gd` (new view), `i18n/translations.csv`.

#### 5b – Automation (done)
Upgrade category **«Automation»** (unlocked by owning `homeserver`), one line, tiers in order:

| Tier | Cost | Effect |
|---|---|---|
| Unit tests | 80K | contract progress +10 % |
| CI builds | 600K | contract progress +15 % (stacks, needs 0.5 kW and 1 cooling) |
| Auto-accept | 3M | free slots automatically take the best offer (once per second) |
| Release pipeline | 15M, needs `rack` | finished contracts deliver themselves, also after offline time |
| Nightly backups | 60M, needs `nas` | penalty effects of events are halved (x0.5 → x0.75) |

The first draft had +25 %/+50 % speed: the simulation dropped to 18 h, because speed multiplies the reward per diverted CHF. Automation is meant for convenience, not as a speed boost, so it was lowered to +10 %/+15 %.
**Balancing after 5b** (greedy player, perfect contract handling): 27.0 h without contracts, **22.2 h** with contracts. A real player handles contracts less perfectly before the release pipeline (~5 h in) and should land around 23–24 h.

From «Release pipeline» on, contracts run completely hands-off – the «first manual, later watch your infrastructure do it» moment.

#### Decisions made while building step 1 (2026-11-07)
- **Diverted share grows with running contracts:** `1 - 0.5^n` (1 → 50 %, 2 → 75 %, 3 → 87.5 %, 4 → 93.75 %), split equally. Extra slots therefore convert more income at the contract rate instead of just queueing.
- **`work_min` = minutes one contract takes alone** (workload `W = coding/s × 0.5 × 60 × work_min`). The first draft counted full coding output, which made the speed bonus unreachable. Parallel contracts take longer and may miss the bonus – a real trade-off.
- **Only working time counts for the bonus**: waiting for [DELIVER] is free, and in a long offline step only the time until completion counts.
- `Contracts` is a plain `RefCounted` with `tick(delta, code_income, levels) -> diverted`, `fill_offers`, `accept`, `deliver`, `to_dict`/`from_dict`. Step 2 calls `tick` from `Game._process` and `_apply_offline` and subtracts the diverted amount from the wallet.
- Contract names/titles are not translated yet – add them to `i18n/translations.csv` in step 3 and extend `check_i18n` to scan `contract_data.gd` (`"name"` and the `"titles"` arrays).

#### Order of work
1. ✅ `contract_data.gd` + `contracts.gd` with offers, slots, progress, delivery (no UI) → headless test passed (offers, slots, progress, bonus, waiting, offline, save roundtrip, broken data).
2. ✅ Income split and offline progress in `game.gd`, save version 3 (old saves get a fresh board) → headless test passed.
3. ✅ Terminal view «Contracts» (progress bars, ETA, bonus countdown, [ACCEPT]/[DELIVER]) + 36 new translations → no missing keys.
4. ✅ Balancing simulation (greedy player, best offer, instant delivery): without contracts 26.2 h, with the first draft multipliers 21.9 h (too fast), after lowering `reward_mult` by ~20 % **23.7 h**. A real player delivers less often and lands in the 26–35 h target. Contracts ≈ 10 % faster: worth it, not mandatory.
5. ✅ Commit 5a. 5b: upgrades in `economy.gd`, effects in `contracts.gd`/`game.gd`/`event_director.gd`, 10 translations, simulation, headless tests – done.

#### Open questions for MYX
- Is 50 % of the coding income the right share, or should contracts use a separate «developer time» resource?
- Should XYMYX show it visually (e.g. a small folder icon or a different typing animation while working on a contract)? Would need a sprite.
- Final names and flavour titles of the contract types.

### Stage 6 – Product updates and open-source stars (done 2026-11-07)
Both run through the contract board (no new screen). Rules stay: nothing decays, nothing is lost. Math in `scripts/progress.gd` (shared with the simulation).
- **Product updates:** offers like «Update: Desktop app v1.3» (25 % of new offers, if a product can still be updated). Delivered, the product gets **+5 % of its subscription income for good**, up to v1.10 (+50 %). No money, no decay without updates. At most one update per product on the board/running at a time.
- **Open-source projects:** offers without money that give **stars** (5 + 5 × unlocked client types, ×1.25 speed bonus). 20 % of new offers, unlocked by the gaming PC.
- **Star tiers** (permanent, stars are not spent):

  | Stars | Tier | Effect |
  |---|---|---|
  | 10 | Better contracts | client contract rewards ×1.1 |
  | 50 | Contributors | contract speed ×1.1 |
  | 150 | Sponsors | total income ×1.05 |
  | 500 | Famous | rewards ×1.25 and income ×1.05 more |
- Auto-accept prefers client contracts; updates and open source are taken when no client offer is left.
- Save version 4: `product_versions`, `stars`; contract entries carry `kind` (client/update/oss).
- **Balancing** (greedy player): no contracts 27.0 h, client contracts only 22.4 h, with updates + open source **21.1 h** (≈ 6 % faster, reaches all 4 star tiers, 18 updates). A layer of depth, not a shortcut.

### Stage 7 – Overclocking and contract quality (done 2026-11-07)
Math in `scripts/progress.gd`. Power running costs were dropped on purpose (they would feel like a permanent penalty).
- **Overclocking switch** (terminal footer, saved): coding ×1.3. Needs free cooling of 50 % of the current heat and **occupies it** – that cooling is not available for new machines while overclocking. Without enough cooling the PC throttles itself to ×1.1 and uses what is left. Never worse than off.
  - First draft (×1.5, 30 % cooling, nothing occupied) had no downside: 18.7 h instead of 21.1 h. Now 20.1 h (≈ 5 % faster). Honest note: it stays a net plus; the decision is «coding speed now vs. cooling for the next machine».
- **Contract quality** (selector in the contracts view, applies to newly accepted contracts, not to product updates; the bonus target time stays the same):

  | Level | Work | Reward / stars | Best when |
  |---|---|---|---|
  | Fast | ×0.6 | ×0.57 | you want the money soon (≈ 3× sooner, ×1.19 per work with 3–4 parallel) |
  | Normal | ×1 | ×1 | 1–2 contracts in parallel (bonus reachable, ×1.25 per work) |
  | Thorough | ×1.75 | ×2.1 | 3–4 contracts in parallel (no bonus, ×1.20 per work) |

  Checked for all 6 contract types and 1–4 parallel contracts. The first draft (×0.7/×0.8 and ×1.4/×1.6) made «Normal» always the worst choice, the second (×1.5/×1.725) made «Thorough» almost always the best.

### Events (done 2026-11-07, data in `scripts/event_data.gd`)
- Every 10–25 min (only while the user is present) a «!» bubble appears above XYMYX. Clicking him opens the choice in the terminal.
- Without a choice the default applies after 3 min. Amounts are in «minutes of income» of the affected source.
- Effects are timed (shown in the terminal header), everything goes to the log.
- 9 events: viral, broken update, sponsor, coffee machine, power outage, heatwave, CTF, bug bounty, RGB sale.

#### Second event set (2026-11-08)
Feedback: «always the same RGB event». The selection was fine (equally distributed), there were just only 10 events and 9 possible. Now **33 events**, spread over all stages: early (Q&A site down, hackathon, code review, phishing, coffee on the keyboard, firmware), products (DDoS, Black Friday, big client bug), mining (boom, crash, power price), storage (disk failure), locations (conference, intern, office party), AI lab (GPU shortage, AI hype, model leak), quantum (decoherence), space (solar storm) and the cat (`requires_cat`: cat on the keyboard, chewed cable). No repeat of the last **6** events (was 3). With a late save 28 events are possible.

### Stage 8 – CTF flags and homelab (done 2026-11-07)
**8a – CTF flags** (data in `scripts/flag_data.gd`, terminal category «CTF»): 12 milestones named like `flag{first_client}`. Capturing one pays once (5–60 min of income) and unlocks a **tool** with a permanent bonus. Goals: total earned, delivered contracts, owned upgrades, stars, resolved events, product updates, highest combo jump, XYMYX falling asleep, owning every one-off upgrade. Checked once per second, saved (version 5: `flags`, `stats`).

| Flag | Goal | Tool |
|---|---|---|
| hello_world | earn 1,000 CHF | Nano: coding +5 % |
| first_client | deliver 1 contract | Git: contract rewards +5 % |
| power_nap | XYMYX falls asleep | Coffee script: coding +3 % |
| trampoline | highest combo jump | Spring boots: coding +3 % |
| root_access | own a home server | SSH keys: contracts +5 % |
| packet_sniffer | own fiber | Wireshark: storage+subscriptions +5 % |
| crisis_manager | resolve 10 events | Incident runbook: event gains +25 % |
| open_source | 50 stars | Ghidra: stars +10 % |
| ship_it | 10 product updates | CI badges: subscriptions +5 % |
| bounty_hunter | deliver 25 contracts | Burp Suite: contract rewards +10 % |
| billionaire | earn 1B CHF | Nmap: income +5 % |
| full_stack | own every one-off upgrade | XYMYX OS: income +10 % |

Counters start with stage 8, so contracts delivered before do not count.

**8b – Homelab** (category «Homelab», unlocked by the home server): virtual machines use **RAM** (1 RAM stick = 1 GB, shown in the terminal header), plus a little power and cooling. Each type up to 5×, cost ×2.5 per level:
- CI runner VM (1.5M, 4 GB): contracts +5 %
- Game server VM (4M, 6 GB): subscriptions +6 %
- Honeypot VM (2.5M, 4 GB): stars +15 %

All 15 VMs need 70 GB – a real gate early, easy later. A first idea with 16 GB per VM was impossible (RAM costs ×1.15 per stick, 280 GB would cost over 10^18 CHF).
**Balancing:** total time stays ~20.2 h (VMs mostly change *when* things are bought); flag tools are not simulated and should save about another hour.

#### Second flag set (2026-11-08)
16 more flags (28 in total), only existing tool bonuses. New goal types, each reading a counter that already exists: `pets`, `sales`, `research`, `acquisitions`, `locations`, `skill` ("id:level"), `flags` (all other flags).
missing_byte (100K earned), lost_packet (10 contracts), midnight_breach (10 naps), ghost_session (pet the cat 25×), kernel_panic (25 events), secret_branch (25 updates), last_commit (100 contracts), phantom_port (honeypot VM), forgotten_backup (nightly backups), broken_cipher (pentesting 3), black_box (3 research projects), zero_trust (3 locations), shadow_admin (3 acquisitions), cold_boot (1 sale), terminal_zero (3 sales), final_flag (every other flag).
- The new tools add together about total ×1.19, coding ×1.11, contract rewards ×1.16, contract speed ×1.08, net ×1.10, events ×1.27. All 28 tools: total ×1.37, coding ×1.24, contract rewards ×1.33.
- Not in the simulation (it doesn't model flags); they only make later runs a bit faster, since flags stay after a sale.

#### Pet flags (2026-11-08)
8 more flags (36 in total): rubber_duck_debugging (squeak the duck 10×), phantom_firmware (wind up the robot toy 10×),
infinite_loop (hamster), neon_firewall (aquarium), dead_drop (dog), encrypted_echo (baby elephant), last_handshake
(pet cat/dog/elephant 50×), orphaned_container (all 7 pets). New goal types `pet`, `pets_owned`, `pets_all`, `squeaks`,
`winds` with new stats `pets_all`, `squeaks`, `winds` (`pets_all` starts at the old cat count). Small bonuses (+2–5 %).

### Stage 9 – Prestige: selling the company (done 2026-11-07)
Terminal category «Company». Math in `scripts/progress.gd`, logic in `Game.sell_company()`. Save version 6.
- **Sale** possible from 1B CHF earned in the current run. Gives **know-how points** = floor(5 × sqrt(run earnings / 1B)): 1B → 5, 10B → 15, 100B → 50. Each point: **+2 % on everything**, forever.
- **Kept:** CTF flags and tools, stars and star tiers, statistics, event log, settings. **Reset:** money, upgrades, contracts, product versions, effects, overclocking.
- **Specialization per run** (chosen at the sale, can change with every sale):

  | Specialization | Effect |
  |---|---|
  | Security | contract rewards ×1.3, event gains ×2, event penalties halved, flag rewards ×2 |
  | Software | subscriptions ×1.5, product updates +10 % instead of +5 % |
  | Data center | storage and mining ×1.3, power and cooling capacity +25 % |
- **Two clicks:** [SELL COMPANY] arms a confirm button for 5 s that says what is reset.
- **Balancing:** run 1 takes ~20.2 h and earns ~11.4B → 16 know-how (+32 %). Run 2: data center 13.4 h, security 14.5 h, software 14.6 h. First draft had data center ×1.5 (12.7 h) and security without contract bonus (16.3 h, events are not simulated) – evened out.

### Stage 10 – Training (done 2026-11-07)
Data in `scripts/skill_data.gd`, terminal category «Training». Save version 7 (`skills`).
- **Courses** appear on the contract board (≈15 % of new offers, at most one at a time), cost coding time like a contract (10, 20, 40, 80, 160 min for level 1–5), pay no money, ignore the quality setting. Delivered: the skill rises by one level.
- **Skills** (0–5, **kept when the company is sold**):

  | Skill | Courses from | Per level |
  |---|---|---|
  | Python | start | script, client project, automation job rewards +10 % |
  | JavaScript | second monitor | website, app rewards +10 % |
  | Rust | gaming PC | enterprise rewards +10 %, contracts +2 % faster |
  | DevOps | home server | storage + subscriptions +3 % |
  | Pentesting | gaming PC | security audit rewards +10 %, event gains +10 % |
- **New contract types:** automation job (Python 2, ×1.9) and security audit (Pentesting 2, ×2.4).
- **Room:** certificates on the wall next to the monitors, one frame per learned skill.
- **Balancing:** first run 19.5 h → 19.1 h with courses. Courses cost time early and pay off slowly; their real value is that skills carry over into every later run.
- The category list in the terminal is scrollable now (14+ categories).

### Stage 11 – Security business (done 2026-11-07)
Category «Security» (unlocked by **pentesting 2**), own income source «security» (in `Economy.income`, boosted in `Progress.income`).

| Tier | Cost | Effect | Needs |
|---|---|---|---|
| Test server | 300K | +100 CHF/s security subscriptions | – |
| Security lab | 3M | +700 CHF/s | – |
| Vulnerability scanner | 25M | +4,500 CHF/s bug bounties | – |
| Monitoring service | 200M | +30,000 CHF/s | pentesting 3 |
| Security platform | 1.2B | +160,000 CHF/s | pentesting 3 |

- Security income ×(1 + 0.1 × pentesting level), ×1.5 with the security specialization; event buffs can target it.
- New event «Zero-day» for companies with a security business.
- Room: test server and security lab on the left, scanner/monitoring/platform as board icons.
- Requirements can now also be skills (`requires_skill` on categories and upgrades).
- **Fixes found by testing:** owning everything needed 415 kW but only 382.5 kW existed → own power grid +360 kW (was +300). With 2B and pentesting 4 the platform came 18 h after everything else → 1.2B and pentesting 3.
- **Balancing:** first run with courses and the security business **27.6 h** (security starts around 16 h, the platform is the last purchase). The greedy simulation never switches overclocking off, so it got stuck on cooling – that is the intended trade-off, a real player switches it off before a big purchase.

### Stage 12 – Research (done 2026-11-08, data in `scripts/research_data.gd`)
Special category «Research». A project costs money once and then runs in real time in the background (also offline, not while paused). Only one project at a time. Research raises limits of existing systems and is reset when the company is sold.

| Project | Cost | Duration | Needs | Effect |
|---|---|---|---|---|
| Data compression | 5M | 30 min | NAS | storage ×1.25 |
| Long-term support | 20M | 1 h | subscription software | product updates up to v1.15 |
| VM density | 15M | 45 min | home server | up to 8 VMs per type |
| Parallel pipelines | 40M | 1.5 h | workstation | a 5th contract slot |
| Own chips | 500M | 4 h | workstation | coding ×1.5 |
| AI pair programmer | 2B | 6 h | platform | contracts 25 % faster |

- Save version 8 (`research_done`, `research_active`). XYMYX cheers and the log gets an entry when a project finishes.
- No room sprite yet (abstract system).
- **Simulated in stage 13:** with research the first run takes 24.6 h instead of 27.6 h.

### Stage 13 – Locations (done 2026-11-08)
Category «Locations» (unlocked by the server rack), one line in build order. Each location gives capacity (power, cooling, RAM) and a new income source «office» (the team there). Locations are normal upgrades, so they are reset when the company is sold.

| Location | Cost | Power | Cooling | RAM | Income |
|---|---|---|---|---|---|
| Coworking space | 500K | +5 kW | +5 | – | +100 CHF/s |
| Small office | 5M | +15 kW | +20 | +16 GB | +800 CHF/s |
| City office | 50M | +40 kW | +50 | +32 GB | +7,000 CHF/s |
| Colocation data center | 400M | +120 kW | +150 | +64 GB | +50,000 CHF/s |
| Tech campus | 3B | +250 kW | +300 | +128 GB | +300,000 CHF/s |

- Office income gets the global multipliers (stars, tools, know-how) and can be the target of event buffs.
- **Room:** wall map right of the AC (`world_map.png`), one more lit dot per location.
- **Balancing (greedy simulation, now also buying research):** first run without research **27.6 h**, with research **24.6 h** (the campus is part of «everything bought» now). Locations come at 3.1 / 5.4 / 9.2 / 14.4 / 22 h.

### Stage 14 – Acquisitions (done 2026-11-08, data in `scripts/acquisition_data.gd`)
Special category «Acquisitions». A fixed list of 5 made-up companies. Each costs money once and gives a permanent multiplier for the rest of the run. Acquisitions are reset when the company is sold.

| Company | Kind | Cost | Needs | Effect |
|---|---|---|---|---|
| PixelHost GmbH | hosting startup | 30M | small office | storage ×1.5 |
| Tiny Apps AG | indie app studio | 150M | subscription software | subscriptions ×1.5 |
| Byte & Partner | consulting agency | 300M | city office | contract rewards ×1.5 |
| RedLeaf Security | security boutique | 800M | security lab | security ×1.5 |
| Nullgate Silicon | chip designer | 2.5B | colocation data center | coding ×2, locations ×1.5 |

- Save version 9 (`acquisitions`). XYMYX cheers and the log gets an entry.
- Company names are proper names and are not translated, the kind is.
- **Room:** the logo of each acquired company appears on the board (8×8, `art/icon_acq_<id>.png`: hosting, app_studio, consulting, sec_boutique, chip_design; optionally 2 frames = 16×8).
- **Balancing (greedy simulation with research and acquisitions):** first run **23.3 h** (24.6 h without acquisitions, 27.6 h without both). All 5 companies are bought, the last at 20.8 h.

### Cat (decoration, 2026-11-08, `scripts/cat.gd`)
Adopted once in the terminal («Cat», 1,000 CHF), stays when the company is sold. No effect on the game. Save version 10 (`cat`, stat `pets`).
- **Own life:** stands, walks around her spot (in front of the rack, ±70 px), sits, grooms, curls up to sleep for 1–3 min. Sitting is the hub between the animations.
- **Petting:** click = heart bubble, she sits down and grooms. Counted in the stats.
- **Mouse:** cursor within 36 px: she rears up and looks at it, back down 1.5 s after it leaves, then 20 s cooldown (mouse position only).
- **Follows XYMYX:** on half of his walks she walks along and keeps 30 px distance, then goes back home.
- **User away (10 min):** she curls up too and wakes up shortly after the mouse moves again.
- Frame size = sheet height (now 32 px). Clickable area like XYMYX (snapped to 24 px, full height); she can't be carried.

### Endgame and longer first run (2026-11-08)
Goal: a first run (everything bought, greedy simulation with research and acquisitions) of about one week.
- **Prices:** every upgrade from 100M on costs 1.5× as much as before.
- **Longer lines:** Holo display (3B, coding ×1.3), Server row (12B, coding ×1.4), Power plant share (7.5B, +1,500 kW), Mining hall (22.5B, +1M/s mining), Security operations center (15B, +700K/s security, pentesting 4).
- **AI lab** (needs colocation): GPU cluster (18B, coding ×1.6), Training servers (60B, +2.5M/s subscriptions, 64 GB RAM), Own language model (180B, +7M/s subscriptions).
- **Quantum** (needs GPU cluster): Cryo cooler (300B, +1,500 cooling), Qubit chip (750B, coding ×2.5, 600 heat), Quantum cloud (2.25T, +35M/s security).
- **Space** (needs qubit chip): Satellite uplink (6T, storage+subscriptions ×1.5), Own satellite (10T, +120M/s storage), Orbital data center (55T, +400M/s storage).
- **Room:** all new tiers are 8×8 board icons (`art/icon_<id>.png`); the board is now up to 10 icons wide.
- **Balancing:** first run **162.8 h** (≈ 6.8 days, was 23.3 h). Campus at 25 h, AI lab 35–57 h, quantum 56–80 h, space 111–163 h. Power, cooling and RAM suffice for everything (all bought: 1,130/2,373 kW, 2,117/2,691 cooling, 134/1,239 GB). Income with everything: ~13B CHF/s.

### Settings and system status (2026-11-08)
New terminal category «Settings» (autoload `Settings`, `scripts/settings.gd`, stored in `settings.cfg` section `[settings]`):
size (auto/1x–4x, after a restart), mouse reactions on/off, fall asleep after 5/10/20 min/never, events off/rarely/normal/often
(minutes between events: –, 20–45, 10–25, 5–12), show cat, max. FPS 10/20, system status off/on.

**System status (opt-in, decided with MYX):** the only exception to «the game reads nothing from the system». Right-click → «System status»
opens a terminal view with CPU load, RAM, free disk space (system drive), uptime, GPU load and GPU temperature (NVIDIA via NVML).
No CPU temperature (would need a kernel driver). Display only: never saved, never sent, no effect on the game.
- Helper `tools/sysinfo/sysinfo.cpp` → `idle-sysinfo.exe` (MSYS2 g++, static, no console window). Started with
  `OS.execute_with_pipe(..., false)` only while the view is open, prints one JSON line per second, exits when idle.exe's
  process is gone. `scripts/system_status.gd` reads the pipe without blocking.
- Release: ZIP with `idle.exe` + `idle-sysinfo.exe` (the helper is optional, the game runs without it).

### Hide during fullscreen (2026-11-08)
Setting «Hide during fullscreen» (on by default). `scripts/fullscreen_watch.gd` keeps the helper running in
`--fullscreen` mode: once per second it checks `SHQueryUserNotificationState` (exclusive fullscreen / presentation)
and whether the foreground window covers the monitor idle.exe is on (desktop and taskbar don't count, other monitors
don't count). Prints 1/0 on changes. While hidden: the world isn't drawn and the passthrough polygon is a 1 px corner,
so every click goes through; the economy keeps running. If the helper dies, XYMYX shows again and it is restarted
after 30 s. Without the helper nothing happens.

### Monitor, taskbar entry, tray menu, stats (2026-11-08, for v0.3.0)
- **Monitor:** setting «Monitor» [main] [1] [2] [3]. `main.gd` checks every 2 s a signature of the monitor setup
  (number of monitors, chosen monitor, its usable rect and DPI, settings monitor/scale). On a change it saves the
  layout and reloads the main scene (`_rebuild`); the game state lives in the `Game` autoload and isn't touched.
  So size and monitor now apply immediately. `_save_layout` never writes when the screen size is 0 (headless).
- **Taskbar entry:** setting «Taskbar entry» (off by default, applies after a restart). The helper's `--watch` mode
  with `notaskbar` sets `WS_EX_TOOLWINDOW` on the main window (Godot 4.7 has no window flag for it).
- **Tray menu:** `_menu.grab_focus()` after opening, so it closes when you click elsewhere (needs a check on Windows).
- **Stats:** terminal category «Stats»: playtime (new stat `play_sec`, only while running, not offline), earnings,
  sales, know-how, contracts, events, flags, upgrades, research, acquisitions, skills, stars, combo, naps, cat.

### Pets (2026-11-08, for v0.3.0, data in `scripts/pet_data.gd`)
Terminal category «Pets» (was «Cat»), all decoration only, kept when the company is sold, save version 11 (`pets`).
The settings moved out of the category list into a `[Settings]` button in the top right corner of the terminal.

| Pet | Cost | Kind | Behaviour |
|---|---|---|---|
| Rubber duck | 500 | desk (desk.gd) | sits on the table right of the laptop (`DUCK_RECT` 47,16), click = squeak animation |
| Cat | 1K | walker (cat.gd) | as before |
| Robot toy | 5K | toy (robo_toy.gd) | walks ±50 px, battery 40–120 s, falls over and lies; click = wind up / beep and turn |
| Hamster | 25K | corner (desk.gd) | cage in the pet corner: run / eat / sleep, switches every 20–60 s |
| Dog | 250K | walker | like the cat: wag instead of grooming, bark instead of rearing up |
| Aquarium | 2.5M | corner | tank on a small cabinet, loop |
| Baby elephant | 50M | walker | like the cat: spray instead of grooming, trumpet instead of rearing up |

- Walkers: `Cat` with `kind` (cat/dog/elephant), sheet names in `Cat.SHEETS`; missing sheets are grey placeholder boxes.
- Pet corner: on the floor left of the board (or the leftmost part), right to left: hamster, aquarium. Part of the click outline.
- «Show pets» (setting key `show_cat`) hides all of them. Only petting the cat counts for the `pets` stat / flag.

### Stages 10–14 – Plan (decided with MYX on 2026-11-07)
Order: 10 → 11 → 12 → 13 → 14, one commit per stage. New room parts start as grey placeholders, the sprite list comes at the end of each stage; big things (locations, companies) become icons on the map/board.
On a company sale **skills stay** (knowledge), everything else of these stages resets like upgrades.

- **10 – Training:** courses («Learn Python», «Learn Rust», «Pentesting», …) appear on the contract board, cost coding time like a contract, no money. Each delivered course raises a skill (0–5). Skills improve matching contract types and unlock new ones.
- **11 – Security business:** own upgrade line (test server → security lab → vulnerability scanner → monitoring service → security platform) with its own income «security subscriptions» plus automatic bug bounty income. Needs the pentesting skill.
- **12 – Research:** projects cost money and run in the background for a while. They raise limits of existing systems: products up to v1.15, VMs up to 8, a 5th contract slot, compression (+storage), own chips (+coding).
- **13 – Locations + map:** second rack → rented space → own server room → data center → international sites. Each adds power, cooling and RAM capacity plus an income multiplier. A map on the wall shows active locations.
- **14 – Acquisitions:** fixed list of 5 companies (plugin studio, app company, hosting provider, security startup, software studio) with fixed prices; each brings its own income and can be upgraded.

## Backlog (smaller items, as of 2026-11-07)
- ~~Screenshot for the README~~ done 2026-11-08 (`docs/screenshot_strip.png`, `docs/screenshot_terminal.png`).
- ~~Settings in the terminal~~ done 2026-11-08.
- ~~Click area as an outline~~ done 2026-11-08: union of all drawn rectangles (`Desk.outline_rects`, `main._outline`), hanging parts connected by 1 px strings to a bridge at the bottom. Blocks about 20 % less desktop than the old bounding box; falls back to the box if the union ever loses a part.
- First release: export preset, include `*.ico` in the non-resource export filter, GitHub release with download.
- Mention Claude at the end of README.md shortly before the first release.
- ~~Multi-monitor support and reacting to resolution changes~~ done 2026-11-08.
- ~~Hide while a fullscreen app runs~~ done 2026-11-08 via the helper (not a GDExtension). ~~Hide the taskbar entry~~ done 2026-11-08.
- ~~Tray menu stays open~~ fixed 2026-11-08 (grab_focus).

## Open / maybe never
- Mining with a fluctuating price and investing: luck factor plus power as an extra resource. Little value for a lot of work. Only as an option, at the very end.

## Rules that always apply
- The game reads nothing from the real system (no keyboard, no files, no git). Only the mouse position is used.
- Colored pixel art in side view, XYMYX black with white eyes, 48×48 figure, nearest-neighbor.
- Low CPU/GPU: max. 20 FPS, only redraw when something changes.

## Interaction
- **Click XYMYX:** combo jumps in 7 levels, the faster the clicks the higher (up to ~80 game px, via the carry window).
- **Drag XYMYX:** pick up, carry, throw; he falls with gravity and lands. A hard landing makes him angry.
- **Click desk:** terminal. **Drag desk:** move the whole strip (saved in `user://settings.cfg`).
- **Right click / tray icon:** menu (money, terminal, pause, reset strip, language, quit).

### Mouse reactions (mouse position only, no keys, no hook)
- Mouse idle for 10 min → falls asleep at the desk (Zzz); mouse moves → wakes up and stretches.
- Fast mouse close to him → flinches, «!».
- Cursor rests on him for 1.5 s → looks at the user (look / front), heart emote.
- While standing he turns towards the cursor.

### Speech bubble
White box with a black outline and a tail, 7×7 pixel emotes: heart, angry, note, dots, question, exclamation. Shown while typing (random), after reactions, hard landings, waking up and for pending events. Defined in `scripts/speech_bubble.gd`, position `BUBBLE_POS` in `scripts/xymyx.gd`.

## Graphics (in `art/`, horizontal sprite sheets, transparent background)
| File | Size | Frames | Content |
|---|---|---|---|
| `xymyx_sit.png` | 96×48 | 2 | sitting and typing, facing right |
| `xymyx_walk.png` | 192×48 | 4 | walk cycle to the right |
| `desk_laptop.png` | 61×48 | 1 | chair, table, laptop, cup, plant (starter setup) |

### Front view, carrying and falling (48×48 per frame, floor = bottom edge)
If a file is missing, the animation is skipped or replaced by «walk».

| File | Size | Frames | fps | When | Content per frame |
|---|---|---|---|---|---|
| `xymyx_look.png` | 144×48 | 3 | 4 | pause while typing | 0 head turns to the user, 1 looks forward, 2 blinks |
| `xymyx_front.png` | 192×48 | 4 | 4 | pause while walking (50 %) | 0 turns, 1 standing front, 2 blinks, 3 waves |
| `xymyx_dangle.png` | 192×48 | 4 | 6 | grabbed (loop) | hanging, front view, legs wriggling (4 phases) |
| `xymyx_fall.png` | 96×48 | 2 | 8 | falling (loop) | arms up, 2 phases |
| `xymyx_land.png` | 192×48 | 4 | 8 | landing | 0 impact/crouch, 1 deepest crouch, 2 straightens up, 3 standing |
| `xymyx_sleep.png` | 192×48 | 4 | 2 | mouse idle for 10 min (loop) | asleep while sitting, head nodding/sinking, breathing |
| `xymyx_startle.png` | 144×48 | 3 | 8 | fast mouse close to him | sitting: 0 normal, 1 jolts up, 2 eyes wide/arms up |

### Setup parts (position relative to the desk's top-left corner, floor = y 48)
Animated = horizontal sheet, width = frames × width. If a PNG is missing, the game shows a grey box in the target size.

| File | Size (1 frame) | Frames | fps | Position | Content |
|---|---|---|---|---|---|
| `pc_workstation.png` | 12×18 | 2 | 2 | 40, 29 | workstation tower (replaces the water tower), LEDs |
| `monitor_wall.png` | 40×18 | 2 | 2 | 10, -8 | monitor wall behind the desk, scrolling code |
| `rack_cooling.png` | 24×48 | 2 | 2 | 63, 0 | overlay on the rack: pipes/coolers, rest transparent |
| `fan.png` | 12×24 | 4 | 8 | 90, 24 | standing fan, rotor spins |
| `ups.png` | 10×12 | 2 | 1 | 104, 36 | backup battery, LED blinks |
| `world_map.png` | 14×10 | 5 | – | 104, 6 | wall map, frame n = n+1 locations lit (fixed frame, no animation) |
| `cat_idle.png` / `cat_sit.png` / `cat_curl.png` / `cat_scratch.png` / `cat_rear.png` | 32×32 | 4 each | 1–8 | floor | cat: stand, sit down, lie down to curled up, groom, rear up (faces right) |
| `cat_walk.png` | 32×32 | 6 | 8 | floor | cat walking |
| `pet_duck_idle.png` / `pet_duck_squeak.png` | 12×12 | 2 / 3 | 1 / 8 | desk 47,16 | rubber duck idle / squeaking |
| `pet_hamster_run.png` / `_eat` / `_sleep` | 24×24 | 4 / 2 / 2 | 8 / 4 / 1 | pet corner | cage with wheel incl. hamster |
| `pet_aquarium.png` | 20×24 | 6 | 4 | pet corner | tank on a cabinet, fish, bubbles, purple LED |
| `dog_idle/walk/sit/lie/wag/bark.png` | 32×32 | 4/6/4/4/4/4 | like the cat | floor | dog, same structure as the cat sheets |
| `elephant_idle/walk/sit/lie/spray/trumpet.png` | 40×40 | 4/6/4/4/4/4 | like the cat | floor | baby elephant, same structure |
| `robo_toy_walk/idle/wind/fall.png` | 16×16 | 4/2/3/3 | 8/2/8/8 | floor | wind-up robot; last fall frame = lying |
| `ac.png` | 24×10 | 2 | 3 | 90, -8 | wall air conditioner, airflow |
| `homeserver.png` | 14×22 | 2 | 2 | -36, 26 | home server (tower on the floor), LEDs |
| `router.png` | 12×6 | 2 | 4 | -35, 20 | router on the home server, flickering LEDs |
| `fiber.png` | 8×10 | 2 | 1 | -46, 10 | fiber box on the wall |
| `line2.png` | 8×10 | 2 | 1 | -36, 4 | second line, box on the wall |
| `nas.png` | 10×12 | 2 | 2 | -50, 36 | NAS on the floor |
| `ssd_raid.png` | 10×5 | 1 | – | -50, 31 | SSD array (case on the NAS) |
| `grid.png` | 12×16 | 1 | – | -62, 8 | power box on the wall |
| `asic.png` | 10×8 | 2 | 6 | -62, 40 | single ASIC on the floor |
| `asic_shelf.png` | 20×30 | 4 | 4 | -84, 18 | shelf with ASICs |
| `mining_rack.png` | 24×48 | 4 | 4 | -110, 0 | mining rack |
| `board.png` | any | 1 | – | – | location board: only its border and fill colors are used |
| `icon_<id>.png` | 8×8 | 1–2 | 2 | on the board | 16 icons, see below |

The location board grows with the owned icons (up to 8 per row) and hangs right next to the leftmost part in the room.
Board icons (`icon_<id>.png`) in order: plugin, desktop_app, saas, platform, ecosystem, storage_server, storage_cloud, leased, dc_link, solar, battery, own_grid, cool_loop, industrial_cooling, mining_container, mining_farm.

No sprites: CPU, RAM, GPU, SSD (built into the PC).
