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

