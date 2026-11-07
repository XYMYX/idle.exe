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

### Stage 9 – Prestige
- Sell the company and start over. Contacts, knowledge, blueprints remain.
- Specialization in the next run: security, software or data center.

## Backlog (smaller items, as of 2026-11-07)
- Screenshot for the README (`docs/screenshot.png`, then uncomment the line in README.md).
- Settings in the terminal: scale, mouse reactions on/off, sleep delay, event frequency.
- Click area as an outline of rectangles instead of one bounding box (a full room blocks up to ~197 game px of desktop clicks).
- First release: export preset, include `*.ico` in the non-resource export filter, GitHub release with download.
- Mention Claude at the end of README.md shortly before the first release.
- Multi-monitor support (currently primary screen only) and reacting to resolution changes at runtime.
- Windows API via a C++ GDExtension: hide while a fullscreen app runs, hide the main window's taskbar entry.
- Known quirk: the tray menu may stay open after clicking elsewhere.

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
