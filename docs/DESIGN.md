# idle.exe – Design

Stand: 7.11.2026. Grundsatz: Alles läuft von allein. Eingreifen ist optional und wird belohnt, nie bestraft.

## Kern
- **Sichtbares Setup auf der Leiste.** Alles Gekaufte erscheint neben dem Desk: alter Laptop → Gaming-PC → mehrere Monitore → Wasserkühlung → Serverraum/Homelab. Jedes Teil = ein Sprite (siehe «Grafiken»).
- **Eine Währung: Geld (CHF).** Einnahmequellen: Coding (XYMYX + Hardware), Speicher (Backups, Vermietung), Software (Abos), Mining. Sterne (Open Source) sind später keine Währung, sondern eine Freischalt-Hürde.

## Upgrade-Struktur (seit 7.11.2026, Daten in `scripts/economy.gd`)
- Kategorien → Linien → Stufen. Eine Stufe ist erst kaufbar, wenn die vorherige der Linie gekauft ist.
- Mehrere Voraussetzungen pro Stufe (z. B. NAS braucht Heimserver, Cloud braucht Zweite Leitung).
- **Strom (kW) und Kühlung** sind Budgets: Maschinen verbrauchen sie, Strom- und Kühlungs-Upgrades erhöhen sie. Mining-Farm geht nur mit genug Strom und Kühlung.
- Netzwerk wirkt als Multiplikator auf Speicher- und Software-Einnahmen (mehr Hosting-Kunden).
- Terminal: links Kategorien (* = etwas bezahlbar, «gesperrt»), rechts Linien bzw. aktuelle + nächste zwei Stufen, gekaufte eingeklappt. Grün = bezahlbar, Grau = gekauft, Gelb = Voraussetzung fehlt; der Text sagt den Status immer zusätzlich.
- Balancing-Ziel: optimaler Dauerspieler braucht ~26 h für alles (Simulation), mit Offline-Grenze mehrere Tage.
- Später: Build-Infrastruktur, Security, Weiterbildung, Standorte, Forschung, Übernahmen. Strom-Betriebskosten (eigener Strom senkt sie) noch nicht umgesetzt.

## Systeme nach Etappe

### Etappe 4 – Fundament
- Offline-Fortschritt, max. 8 Stunden.
- Upgrade-Menü im Terminal-Look (Klick auf XYMYX).
- Setup-Stufen sichtbar: Laptop → PC → Monitore.
- Hardware zuerst als einfache Multiplikatoren: CPU (Build-Tempo), RAM (parallele Projekte).

### Etappe 5 – Aufträge und Geld
- Coding-Aufträge: Skripte → Websites → Apps → Kundenprojekte.
- **Keine Deadlines mit Scheitern**, nur ein Bonus für schnelle Lieferung (wegen Offline-Zeit).
- Automatisierung freischalten: Tests, Builds, Releases, Backups. Ab dann laufen Aufträge ohne Zutun weiter.

### Etappe 6 – Passives Einkommen und Ruf
- Eigene Produkte (App, Entwicklertool, Hosting): Nutzer und Abos bringen Geld, brauchen ab und zu Updates.
- Open-Source-Projekte bringen Sterne → bessere Aufträge, Mitwirkende, Sponsoren.

### Etappe 7 – Feintuning
- Hitze/Übertakten als **Schalter**: mehr Leistung, mehr Hitze. Bei Überhitzung drosselt der PC automatisch, kein Eingreifen nötig.
- Regler «Tempo ↔ Qualität»: schnell = mehr Geld sofort, weniger Ertrag später (statt eines eigenen Bug-/Support-Systems).
- GPU, Leitung (Uploads, Serverbetrieb) als weitere Hardware.

### Ereignisse (umgesetzt 7.11.2026, Daten in `scripts/event_data.gd`)
- Alle 10–25 min (nur wenn der User da ist) blinkt «!» über XYMYX. Klick auf ihn öffnet die Wahl im Terminal.
- Ohne Wahl gilt nach 3 min die Standardwahl. Beträge in «Minuten Einkommen» der betroffenen Quelle.
- Effekte laufen zeitlich begrenzt (Anzeige im Terminal-Kopf), alles landet im Logbuch.
- 9 Ereignisse: Viral, fehlerhaftes Update, Sponsor, Kaffeemaschine, Stromausfall, Hitzewelle, CTF, Bug Bounty, RGB-Sale.

### Etappe 8 – Ereignisse und Meilensteine
- Zufallsereignisse mit Entscheidungen erscheinen als kleines «!» über XYMYX, **kein Popup**. Klick = selbst entscheiden, sonst nach Zeitablauf Standardwahl.
- CTFs und Bug Bounties (nur im Spiel, erlaubte Testumgebungen) als Meilensteine: Belohnung Geld, Ruf, seltene Tools.
- Homelab/Serverraum (zusammengelegt): virtuelle Server verbrauchen RAM, schalten Fähigkeiten und Projekte frei.

### Etappe 9 – Prestige
- Firma verkaufen und neu starten. Kontakte, Wissen, Baupläne bleiben.
- Spezialisierung im nächsten Durchlauf: Security, Software oder Rechenzentrum.

## Offen / vielleicht nie
- Mining und Investieren: Glücksfaktor durch schwankenden Kurs und zusätzliche Ressource Strom. Wenig Nutzen für viel Aufwand. Nur als Option, ganz am Schluss.

## Regeln, die immer gelten
- Das Spiel liest nichts vom echten System (keine Tastatur, keine Dateien, kein Git).
- Farbige Pixel-Art in Seitenansicht, XYMYX schwarz mit weissen Augen, 48×48-Figur, Nearest-Neighbor.
- Wenig CPU/GPU: max. 20 FPS, nur neu zeichnen, wenn sich etwas ändert.

## Grafiken (Ablage in `art/`, horizontale Sprite-Sheets, transparenter Hintergrund)
| Datei | Grösse | Frames | Inhalt |
|---|---|---|---|
| `xymyx_sit.png` | 96×48 | 2 | Sitzen und Tippen, Blick nach rechts |
| `xymyx_walk.png` | 192×48 | 4 | Laufzyklus nach rechts |
| `desk_laptop.png` | 61×48 | 1 | Stuhl, Tisch, Laptop, Tasse, Pflanze (Start-Setup) |

### Frontansicht, Packen und Fallen (48×48 pro Frame, Boden = unterer Rand)
Fehlt eine Datei, wird die Animation übersprungen bzw. durch «walk» ersetzt.

| Datei | Grösse | Frames | fps | Wann | Inhalt pro Frame |
|---|---|---|---|---|---|
| `xymyx_look.png` | 144×48 | 3 | 4 | Pause beim Tippen | 0 Kopf dreht zum User, 1 schaut nach vorne, 2 blinzelt |
| `xymyx_front.png` | 192×48 | 4 | 4 | Pause beim Spazieren (50 %) | 0 dreht sich, 1 frontal stehend, 2 blinzelt, 3 winkt |
| `xymyx_dangle.png` | 192×48 | 4 | 6 | Gepackt (Loop) | frontal hängend, Beine zappeln (4 Phasen) |
| `xymyx_fall.png` | 96×48 | 2 | 8 | Fallen (Loop) | Arme hoch, 2 Phasen |
| `xymyx_land.png` | 192×48 | 4 | 8 | Landung | 0 Aufprall/Hocke, 1 tiefste Hocke, 2 richtet sich auf, 3 steht |
| `xymyx_sleep.png` | 192×48 | 4 | 2 | Maus 10 min unbewegt (Loop) | sitzend eingeschlafen, Kopf nickt/sinkt, Atmen |
| `xymyx_startle.png` | 144×48 | 3 | 8 | schnelle Maus nahe bei ihm | sitzend: 0 normal, 1 zuckt hoch, 2 Augen weit/Arme hoch |

### Maus-Reaktionen (nur Mausposition, keine Tasten, kein Hook)
- Maus 10 min unbewegt → schläft am Desk ein (Zzz), Maus bewegt → wacht auf und streckt sich.
- Schnelle Maus nahe bei ihm → zuckt zusammen, «!».
- Zeiger ruht 1.5 s auf ihm → schaut zum User (look / front).
- Steht er unterwegs, dreht er sich zum Zeiger.
- Zzz/! werden mit der Pixel-Schrift gezeichnet, Position `BUBBLE_POS` in `xymyx.gd`.

### Setup-Teile (Position relativ zur linken oberen Ecke des Desks, Boden = y 48)
Animiert = horizontales Sheet, Breite = Frames × Breite. Fehlt ein PNG, zeigt das Spiel einen grauen Kasten in Sollgrösse.

| Datei | Grösse (1 Frame) | Frames | fps | Position | Inhalt |
|---|---|---|---|---|---|
| `pc_workstation.png` | 12×18 | 2 | 2 | 40, 29 | Workstation-Tower (ersetzt Wasser-Tower), LEDs |
| `monitor_wall.png` | 40×18 | 2 | 2 | 10, -8 | Monitorwand hinter dem Desk, Code scrollt |
| `rack_cooling.png` | 24×48 | 2 | 2 | 63, 0 | Overlay aufs Rack: Rohre/Kühler, Rest transparent |
| `fan.png` | 12×24 | 4 | 8 | 90, 24 | Standventilator, Rotor dreht |
| `ups.png` | 10×12 | 2 | 1 | 104, 36 | Notstrombatterie, LED blinkt |
| `ac.png` | 24×10 | 2 | 3 | 90, -8 | Klimaanlage an der Wand, Luftstrom |
| `homeserver.png` | 14×22 | 2 | 2 | -36, 26 | Heimserver (Tower am Boden), LEDs |
| `router.png` | 12×6 | 2 | 4 | -35, 20 | Router auf dem Heimserver, LEDs flackern |
| `fiber.png` | 8×10 | 2 | 1 | -46, 10 | Glasfaser-Box an der Wand |
| `line2.png` | 8×10 | 2 | 1 | -36, 4 | Zweite Leitung, Box an der Wand |
| `nas.png` | 10×12 | 2 | 2 | -50, 36 | NAS am Boden |
| `ssd_raid.png` | 10×5 | 1 | – | -50, 31 | SSD-Verbund (Gehäuse auf dem NAS) |
| `grid.png` | 12×16 | 1 | – | -62, 8 | Stromkasten an der Wand |
| `asic.png` | 10×8 | 2 | 6 | -62, 40 | Einzelner ASIC am Boden |
| `asic_shelf.png` | 20×30 | 4 | 4 | -84, 18 | Regal mit ASICs |
| `mining_rack.png` | 24×48 | 4 | 4 | -110, 0 | Mining-Rack |
| `board.png` | 57×30 | 1 | – | -170, -8 | Standort-Tafel (Rahmen 1 px, Innenfläche frei) |
| `icon_<id>.png` | 8×8 | 1–2 | 2 | auf der Tafel | 16 Symbole, siehe unten |

Tafel-Symbole (`icon_<id>.png`), Reihenfolge = Platz auf der Tafel (6 pro Zeile):
plugin, desktop_app, saas, platform, ecosystem, storage_server, storage_cloud, leased, dc_link, solar, battery, own_grid, cool_loop, industrial_cooling, mining_container, mining_farm.

Keine Sprites: CPU, RAM, GPU, SSD (im PC verbaut).
