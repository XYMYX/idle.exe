<div align="center">

```text
██╗██████╗ ██╗     ███████╗   ███████╗██╗  ██╗███████╗
██║██╔══██╗██║     ██╔════╝   ██╔════╝╚██╗██╔╝██╔════╝
██║██║  ██║██║     █████╗     █████╗   ╚███╔╝ █████╗
██║██║  ██║██║     ██╔══╝     ██╔══╝   ██╔██╗ ██╔══╝
██║██████╔╝███████╗███████╗██╗███████╗██╔╝ ██╗███████╗
╚═╝╚═════╝ ╚══════╝╚══════╝╚═╝╚══════╝╚═╝  ╚═╝╚══════╝
```

**A tiny idle game that lives on your Windows desktop.**

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)
![Windows](https://img.shields.io/badge/platform-Windows-0078d6)
![Code: MIT](https://img.shields.io/badge/code-MIT-green)
![Art: CC BY-NC 4.0](https://img.shields.io/badge/art-CC%20BY--NC%204.0-lightgrey)

</div>

<!-- Screenshot: add docs/screenshot.png and uncomment the next line -->
<!-- ![XYMYX at his desk above the taskbar](docs/screenshot.png) -->

```text
  ▄██████▄
 ██████████
 ██  ██  ██           ┌────────────────────┐
 ██████████           │ $ ./work --idle    │
  ▀██████▀            │ > +1.2K CHF/s      │
    ████              │ > commits: 1337    │
 ▄████████▄           │ $ _                │
██ ██████ ██          └──────────┬─────────┘
██ ██████ ██      ═══════════════╧════════════
   ██  ██          ║                        ║
   ██  ██          ║                        ║
```

## `$ whoami`

**XYMYX** is a glossy black android with glowing white eyes. He sits at a mini desk right above your taskbar and codes all day. He earns money, you buy him better hardware, and his setup grows visibly in his little room.

## `$ ls features/`

```text
features/
├── desktop-pet         transparent always-on-top strip above the taskbar, clicks pass through
├── idle-economy        45 upgrades · 7 categories · power & cooling budget
├── visible-setup       laptop → gaming PC → monitor wall → server racks → data center
├── random-events       a «!» pops up, click to decide or let the default happen
├── personality         types, stretches, drinks coffee, waves, naps, shows emotes
├── interaction         pick him up, throw him, combo jumps, drag the whole desk
├── offline-progress    keeps earning while closed (up to 8 h)
├── i18n                English + German, switch via the tray icon
└── low-footprint       max. 20 FPS, only redraws when something changes
```

## `$ cat privacy.txt`

```text
keyboard ......... not read
files ............ not read
git repos ........ not read
network .......... none
mouse position ... used, so XYMYX can react to your cursor
save file ........ stays on your computer
```

## `$ man controls`

| Input | Effect |
|---|---|
| `click` XYMYX | jump · click faster for higher combo jumps |
| `drag` XYMYX | pick him up, carry and throw him |
| `click` desk | open the upgrade terminal |
| `drag` desk | move the whole strip (position is saved) |
| `right click` | menu: pause, reset strip, quit |
| tray icon | left: terminal · right: menu incl. language |

## `$ ./run`

No release build yet. Run it from source:

```bash
# 1. install Godot 4.7 (standard, not .NET): https://godotengine.org/download
# 2. clone
git clone https://github.com/XYMYX/idle.exe.git
# 3. Godot -> Import -> select idle.exe/project.godot
# 4. press F5
```

> If the game opens inside the editor's «Game» tab, turn off embedding there, otherwise the transparent window won't work.

Windows only. Tested on Windows 11 at 150 % display scaling.

## `$ ls %APPDATA%\Godot\app_userdata\idle.exe\`

```text
save.json      game progress, auto-saved every 30 s and on quit
settings.cfg   strip position and language
```

## `$ tree -L 1`

```text
idle.exe/
├── scripts/          GDScript source: economy, events, XYMYX, terminal, ...
├── art/              sprites and icons (pixel art)
├── art_src/          Aseprite source files
├── i18n/             translations.csv (English source → German)
├── docs/DESIGN.md    game design, roadmap, sprite specs
└── project.godot     Godot 4.7 project
```

## `$ cat LICENSE`

```text
code ............ MIT           → LICENSE
art & XYMYX ..... CC BY-NC 4.0  → LICENSE-ART.md
```

- **Code:** [MIT](LICENSE) – use, modify and share freely, keep the copyright notice.
- **Artwork and the character XYMYX:** [CC BY-NC 4.0](LICENSE-ART.md) – share and adapt with credit, but not for commercial use.
