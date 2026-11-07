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

### Stage 5 – Contracts and automation (PLAN, not implemented yet)
Split into **5a contracts** and **5b automation**, one commit each. Principles stay: no failure, no deadlines, offline-safe.

#### 5a – Contracts
- **Idea:** XYMYX can take on client work. A contract turns part of his coding output into a bigger one-off reward. Contracts are optional – without them the game runs exactly as now.
- **How progress works:** while a contract is active, **50 % of the coding income** (`Game.base_income("code")`) goes into the contract instead of the wallet. The contract has a workload `W` in CHF of coding output. When `W` is reached, the reward is `W × reward_mult`.
  - `reward_mult` is 1.5 (script) up to 3.0 (enterprise), so contracts always pay off, but you «invest» time.
  - **Speed bonus:** finished within `target_min` → reward ×1.25. Slower is fine, there is no failure.
  - Workload is scaled to the current coding income when the offer is created (`W = coding/s × 60 × work_min`), so contracts stay relevant late game.
  - Contracts progress **offline** too (same 8 h cap, same 50 % share).
- **Contract types** (data in `scripts/contract_data.gd`, English names + German in CSV):

  | Type | work_min | target_min | reward_mult | Requires |
  |---|---|---|---|---|
  | Script | 3 | 5 | 1.5 | – |
  | Website | 10 | 15 | 1.8 | `monitor_2` |
  | App | 30 | 45 | 2.2 | `gaming_pc` |
  | Client project | 90 | 120 | 2.6 | `homeserver` |
  | Enterprise | 240 | 360 | 3.0 | `rack` |

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

#### 5b – Automation
New upgrade category **«Automation»** (unlocked by owning `homeserver`), one line, tiers in order:

| Tier | Effect |
|---|---|
| Unit tests | contract progress +25 % |
| CI builds | contract progress +50 % (stacks) |
| Auto-accept | free slots automatically take the best offer |
| Release pipeline | finished contracts deliver themselves |
| Nightly backups | halves the penalty of bad events (e.g. «Broken update») |

From «Release pipeline» on, contracts run completely hands-off – the «first manual, later watch your infrastructure do it» moment.

#### Order of work
1. `contract_data.gd` + `contracts.gd` with offers, slots, progress, delivery (no UI) → headless test.
2. Income split and offline progress in `game.gd`, save version 3 + migration → headless test incl. old save.
3. Terminal view «Contracts» + translations → `check_i18n` must report no missing keys.
4. Extend the balancing simulation (greedy player also takes contracts): total time for everything should stay around 26–35 h → tune `reward_mult`.
5. Commit 5a. Then 5b (upgrades in `economy.gd`, effects in `contracts.gd`, translations, sim), commit 5b.

#### Open questions for MYX
- Is 50 % of the coding income the right share, or should contracts use a separate «developer time» resource?
- Should XYMYX show it visually (e.g. a small folder icon or a different typing animation while working on a contract)? Would need a sprite.
- Final names and flavour titles of the contract types.

### Stage 6 – Passive income and reputation
- Own products (app, developer tool, hosting): users and subscriptions bring money, need updates now and then.
- Open source projects bring stars → better contracts, contributors, sponsors.

### Stage 7 – Fine-tuning
- Heat/overclocking as a **switch**: more performance, more heat. When overheating, the PC throttles automatically, no input needed.
- «Speed ↔ quality» slider: fast = more money now, less income later (instead of a separate bug/support system).

### Events (done 2026-11-07, data in `scripts/event_data.gd`)
- Every 10–25 min (only while the user is present) a «!» bubble appears above XYMYX. Clicking him opens the choice in the terminal.
- Without a choice the default applies after 3 min. Amounts are in «minutes of income» of the affected source.
- Effects are timed (shown in the terminal header), everything goes to the log.
- 9 events: viral, broken update, sponsor, coffee machine, power outage, heatwave, CTF, bug bounty, RGB sale.

### Stage 8 – Milestones
- CTFs and bug bounties (in-game only, authorized test environments) as milestones: rewards money, reputation, rare tools.
- Homelab/server room (merged): virtual servers consume RAM, unlock abilities and projects.

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
