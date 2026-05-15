# Current Project State

Ultima inventariere: 2026-05-15.

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
