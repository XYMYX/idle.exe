# Art at 3× resolution

Every sprite is redrawn at **3× width and 3× height** (same number of frames, same order).
XYMYX becomes 144×144 per frame instead of 48×48. On a 4K screen at 150 % Windows scaling the game
then draws every art pixel as one screen pixel: same size on screen, 9× the pixels for detail.
Positions are relative to the desk's top-left corner (already ×3), floor = y 144.
Not affected: `app_icon.png`, `tray_icon.png`, `xymyx.ico` (Windows icons).

The code is switched (2026-11-08): a file that isn't redrawn yet is shown upscaled 3× (looks like before),
so the sprites can be replaced one by one. Just overwrite the file in `art/`.

## Fixed spots (new, ×3)

| What | Position | Size per frame |
|---|---|---|
| Desk base (`desk_laptop.png` / `desk_pc.png`) | 0, 0 | 183×144 |
| Chair (`chair.png`) | 0, 42 | 48×102 |
| Rubber duck | 141, 48 | 36×36 |
| Aquarium | -63, 72 | 60×72 |
| Seasonal decoration | left of the room, on the floor | 60×84 |
| XYMYX | sits with his hips on the chair | 144×144 |
| Cat, dog / elephant / hamster, robot toy | on the floor | 96×96 / 120×120 / 48×48, 48×48 |

## XYMYX

| Done | File | Today | New (whole sheet) | Frames | Frame size new | Position new |
|---|---|---|---|---|---|---|
| [x] | `xymyx_cheer.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_dangle.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_drink.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_duck_talk.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_fall.png` | 96×48 | **288×144** | 2 | 144×144 | – |
| [x] | `xymyx_front.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_headdesk.png` | 240×48 | **720×144** | 5 | 144×144 | – |
| [x] | `xymyx_kneel.png` | 240×48 | **720×144** | 5 | 144×144 | – |
| [x] | `xymyx_land.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_look.png` | 144×48 | **432×144** | 3 | 144×144 | – |
| [x] | `xymyx_phone.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_repair.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_roll.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_sit.png` | 96×48 | **288×144** | 2 | 144×144 | – |
| [x] | `xymyx_sleep.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_startle.png` | 144×48 | **432×144** | 3 | 144×144 | – |
| [x] | `xymyx_stretch.png` | 192×48 | **576×144** | 4 | 144×144 | – |
| [x] | `xymyx_walk.png` | 192×48 | **576×144** | 4 | 144×144 | – |

## Desk and room

| Done | File | Today | New (whole sheet) | Frames | Frame size new | Position new |
|---|---|---|---|---|---|---|
| [x] | `ac.png` | 48×10 | **144×30** | 2 | 72×30 | 270, -24 |
| [x] | `asic.png` | 20×8 | **60×24** | 2 | 30×24 | -186, 120 |
| [x] | `asic_shelf.png` | 80×30 | **240×90** | 4 | 60×90 | -252, 54 |
| [x] | `board.png` | 57×30 | **171×90** | 1 | 171×90 | – |
| [x] | `chair.png` | 16×34 | **48×102** | 1 | 48×102 | – |
| [x] | `desk_laptop.png` | 61×48 | **183×144** | 1 | 183×144 | – |
| [x] | `desk_pc.png` | 61×48 | **183×144** | 1 | 183×144 | – |
| [x] | `fan.png` | 48×24 | **144×72** | 4 | 36×72 | 270, 72 |
| [x] | `fiber.png` | 16×10 | **48×30** | 2 | 24×30 | -138, 30 |
| [x] | `grid.png` | 12×16 | **36×48** | 1 | 36×48 | -186, 24 |
| [x] | `homeserver.png` | 28×22 | **84×66** | 2 | 42×66 | -108, 78 |
| [x] | `keyboard_mech.png` | 16×4 | **48×12** | 1 | 48×12 | 54, 72 |
| [x] | `line2.png` | 16×10 | **48×30** | 2 | 24×30 | -108, 12 |
| [x] | `mining_rack.png` | 96×48 | **288×144** | 4 | 72×144 | -330, 0 |
| [x] | `monitor_2.png` | 14×17 | **42×51** | 1 | 42×51 | 48, 33 |
| [x] | `monitor_3.png` | 14×17 | **42×51** | 1 | 42×51 | 138, 33 |
| [x] | `monitor_wall.png` | 80×18 | **240×54** | 2 | 120×54 | 30, -24 |
| [x] | `nas.png` | 20×12 | **60×36** | 2 | 30×36 | -150, 108 |
| [x] | `pc_tower.png` | 12×18 | **36×54** | 1 | 36×54 | 120, 87 |
| [x] | `pc_tower_water.png` | 12×18 | **36×54** | 1 | 36×54 | 120, 87 |
| [x] | `pc_workstation.png` | 24×18 | **72×54** | 2 | 36×54 | 120, 87 |
| [x] | `rack.png` | 24×48 | **72×144** | 1 | 72×144 | 189, 0 |
| [x] | `rack_cooling.png` | 48×48 | **144×144** | 2 | 72×144 | 189, 0 |
| [x] | `router.png` | 24×6 | **72×18** | 2 | 36×18 | -105, 60 |
| [x] | `ssd_raid.png` | 10×5 | **30×15** | 1 | 30×15 | -150, 93 |
| [x] | `ups.png` | 20×12 | **60×36** | 2 | 30×36 | 312, 108 |
| [x] | `world_map.png` | 70×10 | **210×30** | 5 | 42×30 | 312, 18 |

## Board icons

All board icons: **24×24** (2 frames side by side = 48×24). 59 files:

`icon_acq_app_studio.png`, `icon_acq_chip_design.png`, `icon_acq_consulting.png`, `icon_acq_hosting.png`, `icon_acq_sec_boutique.png`, `icon_ai_accelerator.png`, `icon_ai_agents.png`, `icon_arctic_hall.png`, `icon_backbone.png`, `icon_battery.png`, `icon_bunker_dc.png`, `icon_cool_loop.png`, `icon_cooling_tower.png`, `icon_cryo_cooler.png`, `icon_cyber_defense.png`, `icon_dc_link.png`, `icon_desktop_app.png`, `icon_dev_platform.png`, `icon_dna_storage.png`, `icon_ecosystem.png`, `icon_exabyte_cluster.png`, `icon_fusion_reactor.png`, `icon_global_cloud.png`, `icon_global_hq.png`, `icon_gpu_cluster.png`, `icon_gpu_rack.png`, `icon_holo_display.png`, `icon_hydro_dam.png`, `icon_immersion_cooling.png`, `icon_industrial_cooling.png`, `icon_leased.png`, `icon_mining_container.png`, `icon_mining_farm.png`, `icon_mining_hall.png`, `icon_mining_island.png`, `icon_operating_system.png`, `icon_orbital_dc.png`, `icon_own_grid.png`, `icon_own_llm.png`, `icon_own_satellite.png`, `icon_platform.png`, `icon_plugin.png`, `icon_power_plant.png`, `icon_quantum_cloud.png`, `icon_qubit_chip.png`, `icon_saas.png`, `icon_sat_uplink.png`, `icon_second_campus.png`, `icon_self_healing.png`, `icon_server_row.png`, `icon_server_workstation.png`, `icon_soc.png`, `icon_solar.png`, `icon_storage_cloud.png`, `icon_storage_server.png`, `icon_subsea_cable.png`, `icon_tape_library.png`, `icon_threat_intel.png`, `icon_training_servers.png`

## Pets

| Done | File | Today | New (whole sheet) | Frames | Frame size new | Position new |
|---|---|---|---|---|---|---|
| [x] | `cat_curl.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `cat_dangle.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `cat_fall.png` | 64×32 | **192×96** | 2 | 96×96 | – |
| [x] | `cat_idle.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `cat_land.png` | 96×32 | **288×96** | 3 | 96×96 | – |
| [x] | `cat_rear.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `cat_scratch.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `cat_sit.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `cat_walk.png` | 192×32 | **576×96** | 6 | 96×96 | – |
| [x] | `dog_bark.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `dog_dangle.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `dog_fall.png` | 64×32 | **192×96** | 2 | 96×96 | – |
| [x] | `dog_idle.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `dog_land.png` | 96×32 | **288×96** | 3 | 96×96 | – |
| [x] | `dog_lie.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `dog_sit.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `dog_wag.png` | 128×32 | **384×96** | 4 | 96×96 | – |
| [x] | `dog_walk.png` | 192×32 | **576×96** | 6 | 96×96 | – |
| [x] | `elephant_dangle.png` | 160×40 | **480×120** | 4 | 120×120 | – |
| [x] | `elephant_fall.png` | 80×40 | **240×120** | 2 | 120×120 | – |
| [x] | `elephant_idle.png` | 160×40 | **480×120** | 4 | 120×120 | – |
| [x] | `elephant_land.png` | 120×40 | **360×120** | 3 | 120×120 | – |
| [x] | `elephant_lie.png` | 160×40 | **480×120** | 4 | 120×120 | – |
| [x] | `elephant_sit.png` | 160×40 | **480×120** | 4 | 120×120 | – |
| [x] | `elephant_spray.png` | 160×40 | **480×120** | 4 | 120×120 | – |
| [x] | `elephant_trumpet.png` | 160×40 | **480×120** | 4 | 120×120 | – |
| [x] | `elephant_walk.png` | 240×40 | **720×120** | 6 | 120×120 | – |
| [x] | `hamster_dangle.png` | 64×16 | **192×48** | 4 | 48×48 | – |
| [x] | `hamster_eat.png` | 64×16 | **192×48** | 4 | 48×48 | – |
| [x] | `hamster_fall.png` | 32×16 | **96×48** | 2 | 48×48 | – |
| [x] | `hamster_idle.png` | 64×16 | **192×48** | 4 | 48×48 | – |
| [x] | `hamster_land.png` | 48×16 | **144×48** | 3 | 48×48 | – |
| [x] | `hamster_sit.png` | 64×16 | **192×48** | 4 | 48×48 | – |
| [x] | `hamster_sleep.png` | 64×16 | **192×48** | 4 | 48×48 | – |
| [x] | `hamster_stand.png` | 64×16 | **192×48** | 4 | 48×48 | – |
| [x] | `hamster_walk.png` | 96×16 | **288×48** | 6 | 48×48 | – |
| [x] | `pet_aquarium.png` | 120×24 | **360×72** | 6 | 60×72 | – |
| [x] | `pet_duck_idle.png` | 24×12 | **72×36** | 2 | 36×36 | – |
| [x] | `pet_duck_squeak.png` | 36×12 | **108×36** | 3 | 36×36 | – |
| [x] | `robo_toy_fall.png` | 48×16 | **144×48** | 3 | 48×48 | – |
| [x] | `robo_toy_held.png` | 64×16 | **192×48** | 4 | 48×48 | – |
| [x] | `robo_toy_idle.png` | 32×16 | **96×48** | 2 | 48×48 | – |
| [x] | `robo_toy_walk.png` | 64×16 | **192×48** | 4 | 48×48 | – |
| [x] | `robo_toy_wind.png` | 48×16 | **144×48** | 3 | 48×48 | – |

## Seasons

| Done | File | Today | New (whole sheet) | Frames | Frame size new | Position new |
|---|---|---|---|---|---|---|
| [x] | `season_birthday.png` | 40×28 | **120×84** | 2 | 60×84 | – |
| [x] | `season_halloween.png` | 40×28 | **120×84** | 2 | 60×84 | – |
| [x] | `season_newyear.png` | 80×28 | **240×84** | 4 | 60×84 | – |
| [x] | `season_swiss.png` | 80×28 | **240×84** | 4 | 60×84 | – |
| [x] | `season_xmas.png` | 40×28 | **120×84** | 2 | 60×84 | – |

## Previously missing (drawn 2026-11-08)

| File | New (whole sheet) | Frames | Position new |
|---|---|---|---|
| `certificates.png` | 150×36 | 5 | 156, -18 |
| `test_server.png` | 72×60 | 2 | -378, 84 |
| `sec_lab.png` | 120×120 | 2 | -450, 24 |
