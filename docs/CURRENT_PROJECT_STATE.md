# Current Project State

Ultima inventariere: 2026-05-16.

## Checkpoint polish HUD + cinematic NPC (2026-05-16)

Sesiune de polish atmosferic + UX. Tot ce mai jos e validat in joc.

### 1. Animatii obiectiv mai dramatice
- `Scripts/hud_pov.gd::_animate_objective_in/_replace/_out` rescrise. Cardul vine acum cu slide + scale (TRANS_BACK overshoot), flash cald care se topeste in alb, apoi reveal text decalat ~0.3s.
- La replace, vechiul obiectiv e confirmat vizibil (flash + scale + slide stanga + label fade), pauza 0.45s, **abia apoi** schimba textul. Jucatorul vede CLAR cand obiectivul s-a schimbat (inainte era ~0.37s total, acum ~1.85s).
- La complete (out), puls cald scurt inainte de fade.
- Hidden offset crescut la `(110, -24)` pentru intrare mai vizibila din coltul dreapta-sus.

### 2. Font in tema pentru obiective si dialog
- `_OBJ_FONT_NAMES` (static var, NU const — vezi feedback) — cascada serif: Trajan Pro -> Trajan -> Cinzel -> IM FELL English -> Cormorant Garamond -> Cardo -> Cambria -> Constantia -> Palatino Linotype -> Book Antiqua -> Garamond -> Georgia -> serif. `SystemFont` ia primul instalat pe Windows (de obicei Cambria/Constantia/Palatino).
- Text obiectiv: sepia inchis `Color(0.11, 0.06, 0.025, 0.97)` cu outline cald `Color(0.92, 0.78, 0.5, 0.35)`, size 2 — arata ca o inscriptie pe pergament.

### 3. Caseta de dialog redesignata (`_build_dialogue_panel`)
- Inlocuit `Label` cu `RichTextLabel` + `bbcode_enabled=true` + `fit_content=true`.
- Style sepia-pergament: bg `(0.05, 0.032, 0.018, 0.88)`, border aur cald 2px, corner radius 6, padding intern 28x20, **drop shadow** offset (0,4) size 10.
- 3 variante SystemFont (normal/bold/italic), aceeasi cascada serif.
- `_format_dialogue_text(text)` — detecteaza prefix "Speaker:" si formateaza ca **`[color=#e8b86a][b]Ucenic:[/b][/color]  [i]restul replicii[/i]`**. Fara prefix sau prefix > 26 caractere → tot text italic.
- Animatii:
  - `_animate_dialogue_show`: slide-up 28px + fade 0.32s + scale 0.96→1 cu TRANS_BACK 0.45s
  - `_animate_dialogue_text_swap`: puls scale 1.03→1 cu typewriter restart
  - `_animate_dialogue_hide`: fade 0.3s + slide-down 0.35s
  - `_start_dialogue_reveal`: typewriter via `visible_ratio` 0→1 la ~42 char/s, clamped 0.5–2.6s
- `_DLG_BASE_OFFSET_TOP/BOTTOM`, `_DLG_HIDDEN_SHIFT`, `_DLG_SPEAKER_COLOR` constante pentru tuning rapid.

### 4. Sistem cinematic focus pe NPC
- `Scripts/player_controller.gd::play_cinematic_focus(world_pos, pan_duration=0.7, hold_time=0.7, zoom_fov=42.0, return_duration=0.55)`:
  - Calculeaza yaw (atan2 pe XZ) + pitch (atan2 pe Y/orizontal), clampat la `tilt_lower/upper_limit`.
  - Yaw delta cu `wrapf(target - current, -PI, PI)` → shortest path.
  - Skip automat daca `dot(forward, to_target) > 0.88` (deja se uita acolo).
  - Tween secvential explicit: faza 1 paralel (yaw + pitch + fov-in) `TRANS_CUBIC EASE_IN_OUT`, faza 2 interval (hold), faza 3 fov-out `TRANS_SINE EASE_IN_OUT`, faza 4 callback `_cinematic_active = false`.
  - **IMPORTANT pattern**: NU folosi `set_parallel(true)` + `chain()` o data, pentru ca `chain()` e one-shot in Godot 4 si tweenele de dupa revin la paralel = callback-ul se trigger-uieste prea devreme. Foloseste mod default sequential + `.parallel()` per tween din pasul curent.
- Input gating in `_unhandled_input` (early return daca `_cinematic_active`) + zero pe `input_dir` in `_physics_process`. Mouse + miscare + jump/interact/etc. blocate **pana la finalul fazei 4** (zoom-out complet).
- `Scripts/npc_dialogue_interactable.gd::_trigger_focus_cinematic()` — exporturi `focus_player_on_objective`, `focus_target_path` (default = parent global_position), `focus_target_offset`, `focus_delay`, `focus_pan_duration`, `focus_hold_time`, `focus_zoom_fov`, `focus_zoom_return_duration`. Apelat din `_apply_initial_objective` cand obiectivul e setat (gate prin `wait_for_intro`).
- Activat pe nodul `ApprenticeInteractBody/Dialogue` cu valori: `focus_target_offset=(0,1,0)`, `focus_delay=0.6`, `focus_pan_duration=0.85`, `focus_hold_time=1.5`, `focus_zoom_fov=40`, `focus_zoom_return_duration=0.6`. Total cinematic ~3.55s input blocat.

### 5. Foc pentru cuptoare (`scenes/items/furnace_fire.tscn`)
- Scena reutilizabila drag-and-drop. Refoloseste `oil_flame.gdshader` + `flame_teardrop.obj` (deja in proiect).
- Structura: `Light` (OmniLight3D warm) + `FlameCore` + `FlameCrossA/B` (rotite 60°/120° pe Y pentru volum) + `FlameSide1/2` (la ±0.55m offset orizontal) + `FlameInnerGlow` + `Embers` (GPUParticles3D 36 scantei) + `Smoke` (32 puff-uri) + `CrackleSFX` (AudioStreamPlayer3D).
- `Scripts/furnace_fire.gd` — flicker per instanta cu `FastNoiseLite` (seed random), exporturi pentru `flicker_speed/range`, `flame_jitter`, `base_energy/range`, `light_color`, `sound_enabled/volume_db/bus/pitch_random`. Pitch random per instanta + offset random in loop → cuptoarele alaturate nu suna sincronizat.
- Audio: `audio/sfx/fire_crackle.mp3` (dragon-studio-fire-sounds-356121.mp3, copiat din Downloads). `.import` cu `loop=true`. `unit_size=10`, `max_distance=25`, `volume_db=6` pe AudioStreamPlayer3D ca sa se auda decent prin atenuarea 3D.
- Defaults vizuale calibrate dupa screenshot user: portocaliu cald (NU galben), volum mare (3 flame-uri centrale + 2 laterale), fum moderat. Ajusteaza per instanta cu `scale` pe nodul radacina daca cuptorul e mai mare/mic.

### 6. Obiectiv refill lampa: ramane pana la 50%
- `Scripts/lamp.gd::_play_empty_tutorial` — dupa monologul de empty, **NU mai restaureaza imediat obiectivul vechi**. Asteapta `oil_changed` in loop pana `oil_level >= oil_max * 0.5`. Daca alt sistem setezeaza alt obiectiv intre timp, da return (quest progression are prioritate).
- Textul din `tomb_layout.tscn` (4 lampi de workshop) actualizat: *"Reumple lampa la o sconcă de pe perete (ține apăsat E). Trebuie să umpli măcar până la jumătate."* — explicit ca jucatorul sa stie pragul.

### 7. Obiectiv apprentice — gate pe intro finished
- `Scripts/game_events.gd` — semnal nou `intro_finished`, flag `intro_done`, helper `notify_intro_finished()` (idempotent).
- `Scripts/scene_intro_dialogue.gd` cheama `events.notify_intro_finished()` dupa ultima replica.
- `Scripts/npc_dialogue_interactable.gd` — export nou `wait_for_intro: bool`. Daca true, `_ready` face `await events.intro_finished` inainte de `_apply_initial_objective`. Activat pe ucenic in scena.

### 8. Plasa de siguranta pentru dialogue_lines (BUG RECURENT — vezi feedback)
- `Scripts/npc_dialogue_interactable.gd` — trei nivele fallback in `_effective_lines()`:
  1. `dialogue_lines` (export, din .tscn)
  2. `fallback_dialogue_lines` (export, backup din .tscn)
  3. `_get_baked_lines(key)` — **replici hardcodate in cod** sub `match` pe `baked_dialogue_key` sau `initial_objective_id`. **Imun la save-uri Godot/agenti care curata .tscn**.
- Adaugat case-ul `"talk_to_apprentice"` cu cele 4 replici. Extinde cu alte case-uri pentru NPC noi.
- `_ready` face `push_warning` daca toate 3 sursele sunt goale — debugging mai rapid data viitoare.

### 9. Bugfixe colaterale
- `Scripts/clay_application_station.gd::_do_chisel_tap` — parametru `by` → `_by` (era nefolosit).
- `Scripts/hud_pov.gd:195-196` — `count_label.grow_horizontal/vertical = 0` → `Control.GROW_DIRECTION_BEGIN` (Godot 4.6 mai strict cu int→enum).
- `scenes/tomb_layout.tscn::ApprenticeInteractBody` — scale non-uniform `(1.30, 2.08, 1.20)` baked in capsula (`radius 0.45→0.56`, `height 1.6→3.33`), transform setat la scale uniform `(1,1,1)`. Jolt nu mai da warning.

### De facut imediat (urmatorul prompt)
- (optional) **Sunet pentru obiectiv** — user a cerut explicit FARA sunet, doar font + animatie. Daca se razgandeste, exista pattern-ul `_make_objective_chime()` (procedural PCM16 din `furnace_fire.gd` ca referinta).
- (optional) **Cinematic focus pe alti NPC** — paznici, mester etc. Doar bifezi `focus_player_on_objective=true` + setezi `focus_target_offset`.

### De urmarit dupa playtest
- Daca cinematic-ul pe ucenic se simte prea lung sau abrupt → ajusteaza `focus_pan_duration` (curent 0.85) si `focus_hold_time` (curent 1.5) in inspector pe nodul Dialogue.
- Daca zoom-ul (FOV 40°) e prea agresiv → urci la 50–55°.
- Furnace fire poate fi prea zgomotos cu mai multe cuptoare aproape → scade `volume_db` per instanta sau bus dedicat.

---

## Checkpoint atelier si narațiune (2026-05-15 seara)

Am ramas la flow-ul de inceput din `scenes/tomb_layout.tscn`, in Atelierul de Teracota. Scena are acum un traseu jucabil mai clar:

1. Monolog intro despre moartea lui Qin Shi Huang si armata aproape terminata.
2. Obiectiv initial: vorbeste cu ucenicul.
3. Dupa dialogul cu ucenicul apare obiectivul: ia lampa de pe suport.
4. Lampile din atelier sunt blocate pana la obiectivul `take_lamp`, deci promptul de pickup nu apare prea devreme.
5. Dupa ce iei lampa, obiectivul devine: ia barbotina din magazie.
6. Modelul `claybowl.glb` a fost adaugat in scena pentru bolul cu barbotina.
7. Cand iei barbotina, bolul dispare de la statie si apare in mana dreapta a playerului.
8. Cand aplici barbotina pe soldatul de teracota, bolul din mana dispare si apare langa zona de lucru.
9. Textul si replicile au fost corectate sa vorbeasca despre picioarele soldatului, nu despre mana/brat.
10. Dupa recuperarea daltei, obiectivul cere continuarea modelarii picioarelor.
11. Continuarea modelarii porneste secventa cu gardienii si ordinul de sigilare, apoi obiectivul devine gasirea lui Liang.

Scripturi noi/recente care sustin flow-ul:

- `Scripts/npc_dialogue_interactable.gd` - dialog secvential pe interactiune, cu obiective inainte/dupa dialog.
- `Scripts/dialogue_sequence_interactable.gd` - secvente automate de replici dupa o interactiune.
- `Scripts/scene_intro_dialogue.gd` - monolog de inceput la pornirea scenei.
- `Scripts/quest_step_interactable.gd` - interactiuni conditionate de obiectiv; suporta ascundere/afisare noduri si obiect purtat in mana dreapta.

Asset nou/folosit:

- `scenes/items/claybowl.glb` - bolul cu barbotina/lut fluid. Daca pozitia sau scara in mana nu se simte bine la test, ajusteaza `carried_transform` pe interactable-urile `ClaySlipStation`.

De retinut pentru urmatorul pas:

- Userul a testat promptul de la ucenic/lampa si a confirmat ca e bine.
- Ultima modificare a fost pentru pickup vizual la bolul de barbotina si corectarea textelor catre "picioarele soldatului".
- Urmatorul test recomandat in Godot: verifica daca bolul apare natural in mana, daca dispare corect cand aplici barbotina si daca prompturile raman in ordinea corecta.
- Dupa ce acest inceput e validat, continuam cu zona urmatoare: drumul catre Liang / Coridorul Arbaletelor / Camera Administrativa, in functie de ce vrea userul sa construiasca mai intai.

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
│   ├── entities/
│   │   └── guard.tscn
│   ├── items/
│   │   ├── oil_lamp.tscn
│   │   ├── pickup_item.tscn
│   │   ├── crossbow_trap.tscn
│   │   ├── ceramic_shard.tscn
│   │   ├── lever.tscn
│   │   └── TerracottaRoom2.glb
│   └── ui/
│       ├── hud_pov.tscn
│       ├── pause_menu.tscn
│       ├── fail_screen.tscn
│       ├── main_menu_bg.png
│       ├── OilPhial/                   # texturi phial ulei (frame/backing/oil/surface)
│       ├── Vitalitate/                 # texturi vitalitate
│       └── Slots/                      # slot_1.png ... slot_4.png + slot_left_hand.png + Icons/*
├── Scripts/
│   ├── player_controller.gd
│   ├── main_menu.gd
│   ├── auto_play_first_animation.gd
│   ├── lamp.gd
│   ├── guard.gd
│   ├── cycle_animations_preview.gd
│   ├── add_lamp_lights.gd
│   ├── static_lamp_flicker.gd          # flicker generic per Light3D
│   ├── oil_reservoir.gd                # rezervor de ulei attached la AddedLight-uri
│   ├── inventory.gd
│   ├── interactable.gd
│   ├── interaction.gd
│   ├── hud_debug.gd
│   ├── pickup_item.gd
│   ├── game_events.gd
│   ├── objectives.gd
│   ├── noise_bus.gd
│   ├── objective_trigger.gd
│   ├── tool_required_interactable.gd
│   ├── viewmodel_sway.gd
│   ├── crossbow_trap.gd
│   ├── bolt.gd
│   ├── fail_screen.gd
│   └── pause_menu.gd
├── TripoModels/
│   ├── guard1-idle.glb
│   ├── statue1-idle.glb
│   ├── ucenic.glb
│   ├── mester-mestesugar-real.glb
│   ├── in-hand-lamp.glb
│   ├── samurai_armor_3d_model/
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
- sneak, walk, sprint, crouch, crawl.
- **Movement Feel**: sprintul accelerează mai progresiv (`sprint_acceleration_multiplier=0.58`), schimbările bruște de direcție sunt încetinite discret (`direction_change_acceleration_multiplier=0.72`), crouch/crawl au accelerație și headbob reduse, iar landing-ul aplică un mic camera dip (`land_camera_kick=0.035`).
- Helper-e debug pentru HUD F3: `horizontal_speed()`, `current_target_speed()`, `current_step_noise()`, `current_surface_key()`, `current_acceleration_multiplier()`, `current_deceleration_multiplier()`, `current_head_bob_multiplier()`.
- **Interaction Audio**: player-ul creează runtime `AudioStreamPlayer` pentru pickup/drop/lamp select/lamp toggle/refill. Are stream-uri exportabile, dar fallback imediat pe `menu_click.wav` / `menu_play_start.wav` până avem SFX dedicate.

### `Scripts/lamp.gd`

Lampă cu ulei pe Node3D:
- OmniLight cu flicker + SpotLight pe cameră (direcțional în față)
- `toggle()` (L), `set_raised()` (Shift), `refill()`
- `set_stored()` păstrează starea internă a flăcării, dar inventory ascunde lampa; `set_equipped(false)` lasă lampa drop-uită să lumineze pe jos dacă era aprinsă
- Drop cu lampa aprinsă = lampa luminează pe jos (OmniLight), SpotLight cameră se stinge
- `base_energy = 5.0`, `base_range = 20.0`, `spot_base_energy = 4.2`, `spot_base_range = 32.0`
- Fără umbre pe OmniLight (previne auto-blocarea de corpul lămpii)
- **`start_equipped` (export, default true)**: pune `false` pentru lămpi în lume → pickup activ
- **`dropped_drain_multiplier` (0.25)**: lampa pe jos consumă 4× mai încet decât în mână
- **Movement Oil Spill**: consum diferențiat când lampa este în mână. Statul pe loc consumă cel mai puțin, crouch/crawl și mersul atent consumă puțin, mersul normal consumă moderat, iar sprint/jump/airborne consumă mult mai mult ca efect de ulei vărsat. Setări curente: `idle_drain_multiplier=0.25`, `careful_walk_drain_multiplier=0.72`, `crouch_drain_multiplier=0.48`, `crawl_drain_multiplier=0.35`, `sprint_drain_multiplier=3.4`, `airborne_drain_multiplier=2.4`, `jump_spill_drain_multiplier=3.1`. Cache pe `CharacterBody3D` parent găsit prin traversare.
- **Low Oil Light**: sub `low_oil_warning_threshold_pct=0.14`, flacăra portabilă pierde treptat energie/range și devine mai instabilă înainte să se stingă. F3 afișează `light` strength.

### `Scripts/oil_reservoir.gd`

Rezervor de ulei atașat la orice nod (de obicei lângă o `Light3D`):
- `oil_amount` / `oil_max` (export) — capacitate rezervor
- `idle_drain_rate` (0.025 default; suprascris la 0.2 pe `TerracottaRoom2`) — drain pasiv per secundă
- `refill_per_second` (8) — viteză transfer rezervor → lampa player-ului
- `reservoir_drain_multiplier` (2.0) — rezervorul pierde dublu față de cât câștigă lampa (pierderi prin vărsare)
- `light_path` (NodePath) — Light3D pe care îl stinge când oil_amount=0
- **Low Oil Light**: sub `low_oil_warning_threshold_pct=0.14`, rezervorul trimite `set_oil_light_strength()` către `static_lamp_flicker.gd`, deci lămpile statice se sting gradual înainte de depletion.
- Necesită copii: `Interactable` (cu `hold_action = true`) + `StaticBody3D + CollisionShape3D` pentru raycast
- Semnale: `oil_changed`, `depleted`

### `Scripts/static_lamp_flicker.gd`

Flicker generic pentru lumini statice (`extends Light3D`):
- Capturează în `_ready` energy, fog_energy, omni_range
- Modulează cu `FastNoiseLite` per lampă cu `seed_offset` unic (ritm independent)
- Opțional `breath_amount` + `breath_period` pentru pulsație lentă suprapusă (folosit pe MercuryGlow)
- Detectează OmniLight3D vs SpotLight3D runtime via `"omni_range" in self`
- `set_oil_light_strength(strength)` permite rezervorului să reducă gradual energy/fog/range când uleiul e aproape terminat

### `Scripts/add_lamp_lights.gd` (@tool)

Atașat la nodul `TerracottaRoom2`. La `_ready()` caută noduri după `name_filter` (default `"tripo_node_e3fb4dc2"`) și adaugă pentru fiecare:
1. `OmniLight3D` (numit `AddedLight`) — parametri din inspector
2. `OilReservoir` (Node3D cu script `oil_reservoir.gd`) — copil cu `StaticBody3D + CollisionShape3D + Interactable` + light_path pe AddedLight-ul vecin
3. Oil-ul inițial este randomizat per instanță între `reservoir_initial_oil_min_pct` și `reservoir_initial_oil_max_pct` (50%–100% default)
4. În editor randomul nu fluctuează — folosește max-ul

Setări curente pe `TerracottaRoom2` în scenă: `reservoir_idle_drain = 0.2` (lămpi durează ~17 min idle).

### `Scripts/cycle_animations_preview.gd`

Script pentru preview animații pe modele importate:
- `animation_name` – setează o singură animație fixă (fără cycle)
- `lock_y_position` + `y_offset` – anulează root motion pe Y
- `move_with_animation` – oprește glisarea stânga-dreapta
- Folosit pe `ucenic` (`NlaTrack_003_Armature`, y_offset=-0.15) și `mester-mestesugar-real` (`NlaTrack_004_Armature`, y_offset=-0.23)

### `Scripts/viewmodel_sway.gd`

Sway pentru `ViewmodelRig`:
- mouse sway + bob + breathing + land kick
- offset diferit pentru crouch/crawl
- multiplicatori de stance: sprint/airborne cresc sway-ul, crouch/crawl îl reduc
- `movement_sway_amount` adaugă inerție laterală/forward din viteza playerului

### `Scripts/guard.gd`

AI paznic cu stări PATROL/SUSPICIOUS/ALERT/DETECT:
- `_face_toward_player()` – se uită spre player în SUSPICIOUS/ALERT/DETECT
- Rotație smooth (`lerp 0.08`)
- Modelul din `guard.tscn` e rotit -90° pe Y pentru aliniere forward corectă
- Modelul e `guard1-idle.glb` – **are doar animație idle, NU are walk cycle**

## Atmosferă și lighting (setat 2026-05-15)

### Environment (`tomb_layout.tscn`)
- **Ambient light**: `energy 0.0` (zero – doar lămpile produc lumină)
- **Tonemap**: ACES (mode 3), `exposure 0.85`, `white 6.0`
- **Fog (depth)**: `density 0.022`, culoare caldă `(0.06, 0.035, 0.012)`, `height_density 0.008`, `aerial_perspective 0.18`
- **Volumetric fog**: **ENABLED**. `density 0.038`, `albedo (0.85, 0.7, 0.5)`, `anisotropy 0.45`, `length 36.0`. Produce raze vizibile prin praf din fiecare lampă care are `light_volumetric_fog_energy` setat
- **Glow**: `intensity 0.55`, `strength 1.0`, `bloom 0.1`, `hdr_threshold 0.9`, `hdr_scale 2.2`
- **SSAO**: `intensity 1.7`, `radius 1.4`, `light_affect 0.18`
- **SSIL**: enabled, `radius 3.5`, `intensity 0.6` – indirect light bounce de la lămpi
- **Adjustment**: `brightness 0.98`, `contrast 1.18`, `saturation 0.62`
- **Background**: aproape negru `(0.003, 0.002, 0.0015)`
- **SunLight**: practic stins (`energy 0.02`)

### Lămpi cameră
- Lămpile decorative (Bowl/Chain/Flame) din Workshop au fost șterse complet
- Lămpile din TerracottaRoom2 primesc auto OmniLight prin `add_lamp_lights.gd`
- Pickup items: Glow oprit (`visible=false`, `energy=0`)
- **Toate lămpile statice din `Rooms/*`** au atașat `Scripts/static_lamp_flicker.gd` cu seed_offset unic – flicker independent per lampă, modulează `light_energy`, `light_volumetric_fog_energy` și `omni_range`
- **MercuryGlow_A / MercuryGlow_B** au `breath_amount` 0.22 / 0.26 și `breath_period` ~7–9s → pulsație lentă, ne-naturală, peste flicker subtil
- **GateBrazier**: flicker mai puternic (`amount 0.32`, `speed 6.5`) — e foc deschis, nu lampă cu ulei

### Particule
- **GlobalDust** (`GPUParticles3D` la `World/GlobalDust`): 350 particule pe 240×6×160m, drift lent, culoare caldă. Material `shading_mode=1` (per_pixel) → praful **se aprinde** doar când trece prin conul unei lămpi (efect „dust shaft")
- **TerracottaWorkshop/Dust**: 220 particule local mai dense, același tratament shading_mode=1
- **06_MercuryHall/MercuryVapor**: 70 puffs de vapori cyan-verzui aproape de podea, drift orizontal foarte lent, emission slabă; reprezintă vaporii toxici ai râurilor de mercur (Sima Qian)
- **07_MiddleGate/BrazierEmbers**: 90 scântei mici care urcă din brazier, self-emissive portocaliu, lifetime 2.4s

### Sub-resources noi
- `ParticleProc_mercury_vapor`, `Mat_mercury_vapor`, `Quad_mercury_vapor`
- `ParticleProc_brazier_embers`, `Mat_brazier_embers`, `Quad_brazier_embers`

### Scripturi noi
- `Scripts/static_lamp_flicker.gd`: extinde `Light3D`. Capturează în `_ready` valorile de bază, modulează cu `FastNoiseLite` per lampă (`seed_offset` unic = ritm independent). Opțional `breath_amount` + `breath_period` pentru pulsație lentă suprapusă.

## Sistem control și interacțiuni (setat 2026-05-15)

### Keybinds
| Tasta | Acțiune | Cod |
|---|---|---|
| WASD | Mișcare | `move_*` |
| Space | Jump | `jump` |
| Shift | Sprint | `sprint` |
| Ctrl | Crouch | `crouch` |
| C | Crawl | `crawl` |
| **E** | Use (lever, hold-to-refill) | `interact` |
| **F** | Pickup item | `pickup` |
| **X** | Drop tool activ / lampă doar dacă lampa e selectată | `drop` |
| **Z** | Selectează lampa din offhand | `select_lamp` |
| L | Toggle lamp on/off (doar când e selectată cu Z) | `toggle_lamp` |
| Alt | Ridică lampa (doar când e selectată cu Z) | `raise_lamp` |
| 1-4 | Selectează slot tool | `slot_1`..`slot_4` |
| 0 | Mâini libere | `slot_0` |
| G | Throw ceramic | `throw` |

**Q și R sunt libere** — lean stânga/dreapta a fost eliminat complet.

### `Scripts/interactable.gd`
- `prompt_text`, `enabled`, `one_shot` — props standard
- `hold_action: bool` — dacă true, folosește `interact_held()` apelat per frame; `interact()` devine no-op
- `is_pickup: bool` — dacă true, necesită tasta F (nu E)
- Semnale: `interacted(by)`, `held(by, dt)`

### `Scripts/interaction.gd`
- `try_interact()` — E pressed (skip pickup și hold)
- `try_pickup()` — F pressed (doar pe Interactable cu `is_pickup=true`)
- `try_interact_hold(dt)` — apelat din `_physics_process` cât timp E e ținut; refill-ul de rezervor are efect doar dacă lampa este selectată cu Z (`active_lamp()`)
- `prompt_linger_time=0.08` — menține promptul o fracțiune de secundă când raycast-ul pierde marginea colliderului, ca să reducă pâlpâirea prompturilor
- `prompt_changed(text, key)` semnal — HUD afișează `[F] Ia lampa`, `[E] Toarnă ulei`, `[X] Pune jos`

## Inventory și mâini

### `Scripts/inventory.gd`
- 4 sloturi pentru unelte (`_slots`) + 1 slot offhand separat pentru lampă (`_lamp_entry`)
- Lampa NU intră în cele 4 sloturi — merge automat în offhand (mâna stângă, `LampSocket`)
- Selecția 1-4 schimbă tool-ul din mâna dreaptă (`ToolSocket`); lampa rămâne mereu echipată în stânga
- **Z / `select_lamp()`** selectează lampa ca slot special (`LAMP_SLOT_INDEX=-2`). Doar când e selectată poți face refill cu E sau drop cu X.
- **`add_item("lamp", node)`** rutează la `_set_lamp_offhand` — auto-swap dacă există deja una (ejecție la sol)
- **`find_lamp()`** — returnează lampa din `_lamp_entry`, pentru HUD/OilPhial.
- **`active_lamp()`** — returnează lampa doar dacă este selectată cu Z; rezervorul de ulei și pickup-urile de oil folosesc asta pentru refill.
- **`drop_current(player)`** contextual:
  - Tool selectat → aruncă tool-ul, lampa rămâne în stânga
  - Lampa selectată cu Z → aruncă lampa din offhand
  - Mâini libere (slot 0) → nu aruncă lampa
- **`lamp_equipped_transform: Transform3D`** (export) — transform-ul cu care lampa se așază în LampSocket (setat în scenă pe nodul Inventory)

### Sockete în scenă (`tomb_layout.tscn`)
- `LampSocket` la `(-0.32, -0.26, -0.55)` — mâna stângă (offhand pentru lampă)
- `ToolSocket` la `(0.28, -0.22, -0.5)` — mâna dreaptă (unelte din slot 1-4)

### Player start
- Player **nu mai pornește cu lampa în mână**. `OilLamp` din `LampSocket` a fost eliminat din scenă.
- `initial_lamp_path` golit pe Inventory.
- Lampa trebuie ridicată din lume (F) — instanțe disponibile: `WorkshopLamp_W` și `WorkshopLamp_E` în Workshop, oricare alte instanțe `oil_lamp.tscn` plasate.

## HUD (setat 2026-05-15)

### `scenes/ui/hud_pov.tscn`
- **OilPhial** (jos-stânga, ~133×270) — phial cu ulei, vizibil **doar când o lampă e în offhand**. Animație drain + bob (slosh aplicat și pe fill și pe surface în sincron), plus tint/pulse low-oil sub ~14%. Conectat dinamic la lampa din offhand prin `_sync_active_lamp`.
- **LeftHandSlot** (jos-stânga, lângă OilPhial) — frame separat pentru lampa din offhand, cu `icon_lamp.png`; dim când nu ai lampă, owned când ai lampă, warm active + pulse subtil când lampa este selectată cu Z.
- **SlotBar** (jos-dreapta, ~274×68) — 4 sloturi 64×68 ca `TextureRect` cu texturile `scenes/ui/Slots/slot_N.png`. Modulate per stare:
  - Active: `Color(1.25, 1.08, 0.78)` — bronz cald-luminos
  - Owned (item în slot): `Color.WHITE`
  - Empty: `Color(0.62, 0.62, 0.62, 0.88)` — dim
- **Tool icons** — iconițe în `scenes/ui/Slots/Icons/` mapate dinamic pentru `chisel`, `wedge`, `ceramic`, `hammer`, `wax_tablet`; există și iconițe pregătite pentru `lamp`, `rope`, `wet_cloth`, `qin_seal`.
- **Debug overlay F3** — ascuns implicit; afișează stance, speed, movement feel multipliers, surface, noise, oil level, drain/sec, oil multiplier, light strength, slot activ și interactable curent.
- **ItemLabel** deasupra SlotBar — numele tool-ului din slotul selectat
- **InteractLabel** central-jos — `[E/F/X] Acțiune` cu key prefix dinamic
- **ObjectiveLabel** dreapta-sus, **StanceLabel** stânga-sus

### `Scripts/hud_pov.gd`
- `_sync_active_lamp()` — atașează signal-urile `oil_changed`/`lit_changed` la `find_lamp()`; OilPhial visible doar dacă există lampă în offhand
- `_attach_lamp(lamp)` / `_detach_lamp()` — connect/disconnect curat la schimbarea de lampă (auto-swap, drop, pickup)
- `_refresh_slots()` — modulate state + icon per slot pe baza `inventory.slot_item_id` și `current_slot`
- `debug_overlay` input action (F3) este creată runtime de HUD pentru tuning.

## Lămpi de inventar plasate

| Loc | Nod | Oil inițial | Stare | Notă |
|---|---|---|---|---|
| `Rooms/01_TerracottaWorkshop/WorkshopLamp_W` | instance `oil_lamp.tscn` | 60 | aprinsă | scale 4× |
| `Rooms/01_TerracottaWorkshop/WorkshopLamp_E` | instance `oil_lamp.tscn` | 35 | stinsă | scale 4× |

Lămpile-rezervor de pe pereții `TerracottaRoom2` (~21 instanțe) sunt auto-create de `add_lamp_lights.gd` cu oil random 50-100% × 200.

## Personaje în scenă

| Personaj | Model | Animație | Y Offset | Mișcare |
|----------|-------|----------|----------|---------|
| Ucenic | `ucenic.glb` | NlaTrack_003_Armature | -0.15 | oprită |
| Meșter | `mester-mestesugar-real.glb` | NlaTrack_004_Armature | -0.23 | oprită |

## De reținut

- **Guard model**: `guard1-idle.glb` are DOAR animație idle. Pentru walk/chase animație trebuie model nou cu walk cycle.
- **Guard rotation**: Modelul din `guard.tscn` e rotit `Transform3D(0, 0, -3.25, 0, 3.25, 0, 3.25, 0, 0, ...)` – dacă se înlocuiește modelul, verifică alinierea forward.
- **Lampă (in-hand)**: SpotLight-ul e pe `Camera3D/LampSpot` și e controlat dinamic de `lamp.gd`. Când e pe jos, doar OmniLight-ul lămpii luminează.
- **add_lamp_lights.gd**: Dacă adaugi modele noi cu lămpi, ajustează `name_filter` pe `TerracottaRoom2`. Reservoir-urile se creează automat alături.
- **y_offset**: Dacă personajele levitează după schimbarea animației, ajustează `y_offset` în inspector (negativ = mai jos).
- **Lamp scale în lume**: când plasezi instanțe `oil_lamp.tscn` în scenă, folosește scale `(4, 4, 4)` ca să compense scale 0.24 al corpului în mână. Tot scale 4 e aplicat automat de player la drop.
- **Bug existent în inventory**: dacă ai deja un tool de tip X în slot și ridici altul de același id non-stackable, al doilea face `queue_free()` (dedup pe id). Lampile NU mai au această problemă (rutate separat în offhand).
- **Bug existent în inventory pentru lampă duală**: doar UN slot de lampă în offhand. Pickup a doua lampă auto-ejectează prima la sol — comportament Minecraft-like. Dacă vrem să cărăm mai multe simultan, ar trebui extins `_lamp_entry` la array.

## Ce urmează

### Imediat (UI/gameplay)
- **Frame mare „mâna dreaptă"** pe HUD (analog OilPhial-ului stânga) — dezign descris în `IMAGE_PROMPTS.md`, asset încă neegnerat
- **Tuning movement/lamp feel** cu overlay-ul F3: ajustează multiplicatorii de consum ulei, sway, bob și viteze până când stealth-ul se simte tensionat dar corect.
- (opțional) **Refill rezervor de la player** — momentan transfer e doar rezervor → lampă, nu invers
- (opțional) **Tuning prag low-oil** pentru lampa portabilă și lămpile-rezervor după test în joc

### Niveluri și entități
- Model nou pentru gardieni cu animație de mers
- Audio 3D pentru gardieni: pași spațiali
- Bus/reverb de mormânt pentru SFX
- Seturi dedicate de pași pentru clay/stone/wood/wet_stone
- Plasează gardieni și capcane în camerele corespunzătoare
- `ObjectiveTrigger` la pragul fiecărei camere

### Asseturi de generat (vezi `docs/IMAGE_PROMPTS.md`)
- Frame mare „mâna dreaptă" (oglindă OilPhial)
- (opțional) iconițe pentru iteme viitoare dacă se adaugă noi `item_id`-uri în inventar. Iconițele actuale pentru tool-uri există deja în `scenes/ui/Slots/Icons/`.

### Roadmap general (vezi `docs/IMPLEMENTATION_ROADMAP.md`)
- Faza 5 (capcane + AI gardian)
- Faza 6 (Sala Mercurului — gameplay vapori)
- Faza 7 (poarta + mecanisme)
- Faza 8 (finaluri)
