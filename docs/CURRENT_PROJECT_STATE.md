# Current Project State

Ultima inventariere: 2026-05-12.

## Engine

- Godot 4.6
- Rendering: Forward Plus
- Physics: Jolt Physics
- Main scene: `res://scenes/main_menu.tscn`
- Game scene: `res://scenes/tomb_layout.tscn`

## Structură existentă

```text
.
├── project.godot
├── scenes/
│   ├── main_menu.tscn
│   ├── tomb_layout.tscn
│   └── ui/
│       └── main_menu_bg.png
├── Scripts/
│   ├── player_controller.gd
│   ├── main_menu.gd
│   └── auto_play_first_animation.gd
├── TripoModels/
│   ├── guard1-idle.glb
│   ├── statue1-idle.glb
│   └── imported FBX/texture folders
└── addons/
    └── Tripo3d_Godot_Bridge/
```

## Scripturi existente

### `Scripts/player_controller.gd`

Controller 3D pe `CharacterBody3D`, cu:

- mișcare WASD;
- jump;
- coyote time;
- jump buffer;
- mouse look;
- head bob;
- capturare / eliberare mouse cu `ui_cancel`.

Observație de design: jocul țintește stealth lent. Controllerul existent poate fi refolosit, dar va avea nevoie de stări de mers încet, alergare, crouch/strecurare, zgomot și interacțiune.

### `Scripts/main_menu.gd`

Meniu principal cu:

- background animat subtil;
- particule de dust/embers/drift;
- butoane Play, Continue, Options, Quit;
- Play/Continue încarcă `res://scenes/tomb_layout.tscn`;
- Options este placeholder.

Observație: brief-ul cere și buton Credits. Main menu-ul poate fi extins.

### `Scripts/auto_play_first_animation.gd`

Script util pentru redarea primei animații dintr-un model importat.

## Scene existente

### `scenes/main_menu.tscn`

Scena de meniu principal. Are deja atmosferă vizuală și background importat.

### `scenes/tomb_layout.tscn`

Scenă mare de nivel. Conține deja geometrie / asseturi importate. Trebuie tratată ca prototip sau blockout inițial, nu ca formă finală.

## Asseturi importate

În `TripoModels/` există:

- `guard1-idle.glb`
- `statue1-idle.glb`
- model FBX într-un folder cu id UUID;
- model `samurai_armor_3d_model`.

Observație critică: modelul cu nume samurai poate fi util temporar pentru prototip, dar pentru jocul final paznicii trebuie să arate Qin / China antică, nu samurai.

## Lipsuri majore

- HUD complet;
- sistem de interacțiune `E`;
- inventar rapid;
- stealth cu stări;
- noise system;
- lampă / ulei;
- vapori / toxicitate;
- obiective;
- logică de capcane;
- puzzle de mecanisme;
- fail screen;
- pause menu complet;
- obiecte interactive reale;
- structură clară de camere și rute în level.

## Checkpoint productie - 2026-05-12 seara

Starea curenta dupa sesiunea de prototipare:

- Jocul ruleaza prin `res://scenes/main_menu.tscn`, iar Play intra in `res://scenes/tomb_layout.tscn`.
- Meniul principal are muzica din `res://audio/music/main_menu_theme.mp3`, fade-in, sunet de click si sunet special la Play.
- HUD-ul de vitalitate este sus-stanga si foloseste imaginile importate in `scenes/ui/`: `vitality_0_full.png` pana la `vitality_8_empty.png`.
- Ordinea corecta a surselor originale pentru vitalitate a fost: 1 full, apoi 8, 4, 6, 3, 9, 7, 2, iar 5 este zero viata.
- Efectul de damage exista in `Scripts/hud_debug.gd`: schimbarea vitalitatii are un flash rosu slab si shake discret. Butonul temporar de debug pentru damage a fost scos.
- Controllerul jucatorului din `Scripts/player_controller.gd` are mers, sprint, crouch si crawl pe burta. Crawl este pe `C`.
- Jucatorul este ajustat sa se simta in jur de 1.80 m.
- Mainile POV importate din `TripoModels/viewmodel/bound_arms_pov.glb` au fost scoase momentan din scena, pentru ca nu aratau bine in camera.
- Paznicii / guardianii folosesc inca `TripoModels/guard1-idle.glb`, scalati la `3.25`, tinta vizuala fiind aproximativ 1.90 m.
- Atmosfera atelierului a fost mutata de la rosu agresiv spre intuneric cald de atelier: ceata mai mica, saturatie mai mica, lumini de ulei mai galbene.
- `scenes/items/oil_lamp.tscn` si `Scripts/lamp.gd` au lumina mai calda, mai putin rosie si cu volumetric mai discret.

Audio player:

- `Scripts/player_controller.gd` creeaza runtime playere audio pentru pasi, jump si landing.
- Pasii folosesc `AudioStreamRandomizer`, pitch/volum usor variate si detectie simpla de suprafata prin raycast in jos.
- Exista directoare pregatite pentru suprafete: `audio/sfx/player/footsteps/clay`, `stone`, `wood`, `wet_stone`.
- Exista deja mostre CC0 de pasi default in `audio/sfx/player/footsteps/`.
- Exista sunete CC0 pentru jump in `audio/sfx/player/jump/` si landing in `audio/sfx/player/land/`.
- Sursele/licentele pentru sample-uri sunt notate in `audio/sfx/player/README.md`.

De retinut pentru urmatoarea sesiune:

- Urmatorul pas recomandat este audio 3D pentru gardieni: pasi spatiali, apropiere/departare si eventual sunete discrete de armura/textil.
- Dupa gardieni, merita facut un bus/reverb de mormant pentru SFX, ca pasii si obiectele sa sune mai mult ca intr-un spatiu interior de piatra/pamant.
- Inca trebuie adaugate seturi dedicate de pasi pentru clay/stone/wood/wet_stone; momentan suprafetele sunt pregatite, dar pot folosi fallback daca folderele sunt goale.
