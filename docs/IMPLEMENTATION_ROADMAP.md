# Implementation Roadmap

> Ultima actualizare: 2026-05-17.
> Vezi `CURRENT_PROJECT_STATE.md` pentru detalii tehnice ale codului existent.

## Obiectiv

Transformă proiectul existent într-un vertical slice jucabil care demonstrează identitatea TheBuriedHands:

> atelier întunecat, ordin de sigilare, stealth, capcană cu arbalete, mercur toxic, poartă mecanică și o rută de evacuare.

## Status pe faze

- [x] **Faza 1** — Blockout + lighting de bază (camere etichetate, rute, lumini calde, volumetric fog, praf, vapori mercur)
- [x] **Faza 2** — Controller stealth (WASD + crouch/crawl/sprint, head bob, jump, mouse look, noise emit)
- [~] **Faza 3** — HUD/UI (vitalitate ✓, oil phial ✓ dinamic per-lampă, left-hand slot ✓, slot bar nou cu texturi Qin ✓, iconițe tool ✓, prompts contextual cu key prefix ✓, debug overlay F3 ✓, dialogue panel cu skip [J] ✓, pause/settings menu cu slidere funcționale ✓; lipsește doar frame mare „mâna dreaptă")
- [~] **Faza 4** — Iteme și interacțiuni (lampă ✓ cu start/drop drain + Movement Oil Spill pe idle/crouch/crawl/sprint/jump, pickup item ✓, ceramic shard ✓ throw, lever ✓; daltă/pană/tăbliță există ca pickup placeholder fără asset 3D; wedges ✓, BreakableInteractable ✓ pe TunnelEntrance2)
- [~] **Faza 5** — Capcane + AI gardian (crossbow trap script existent; guard AI cu PATROL/SUSPICIOUS/ALERT + **walk/idle anim dinamic** ✓; Liang NPC cu 23 replici + animații per-replică ✓; dialogue skip J ✓; monolog post-obiectiv ✓; **samurai.glb model nou pe TOȚI gardienii** ✓; **trap_tile + spike_trap scripturi + scene importate din branch Vlad** ✓; **guard conversation cinematic complet polish** ✓ — approach walk, dialog gesticulare, exit walk smooth, focus decuplat; lipsește **plasare live capcane + AI live patrolling** + gameplay crossbow corridor full)
- [ ] **Faza 6** — Sala Mercurului (camera + vapori vizuali există; gameplay damage/blur încă neimplementat)
- [ ] **Faza 7** — Poarta + mecanisme
- [ ] **Faza 8** — Finaluri
- [~] **Faza 9** — Polish vizual/audio (volumetric fog + dust + flicker + mercury breath + brazier embers ✓; bus-uri Music/SFX/Dialogue/Tomb ✓; audio minimal încă în lucru)

**Adițional implementat (sesiunea 2026-05-16 seara):**
- Import selectiv din branch Vlad (`bosregefixes-scripts`): 14 scripturi noi (ladder, mercury×4, spike_trap, trap_tile), 8 scene `.tscn`, 7 GLB-uri, 5 audio MP3, fără overwrite la fișiere existente
- Integrare ladder în `player_controller.gd` (climb, mount, exit cu propulsie)
- Înlocuire model gardian: `guard1-idle.glb` → `samurai.glb` (3.8 MB, 8 animații NLA)
- Distribuție animații per-instanță pe 7 TerracottaGuards + samurai_armor_3d_model
- Walk/idle dinamic în `guard.gd` (AI patrul comută între animații în funcție de viteză)
- Polish complet cinematic guard conversation: cross-fade animații, ease-in la exit walk, decuplare focus camera de exit walk (gardienii pleacă la prima linie Meșteșugar, camera rămâne locked)
- Replici extinse cu mențiune arbalete + trape secrete (motivație narativă pentru rută alternativă)

**Adițional implementat (sesiunea 2026-05-17):**
- Meniu in-game separat de meniul principal: `PauseArt` cu `meniu-ingame.png`, deschis la Escape/F6.
- Ecran de setări separat: `SettingsArt` cu `meniu-tbh.png`, scalat runtime la `settings_height_ratio = 0.95`.
- Butoanele și sliderele din `pause_menu.tscn` sunt poziționabile manual; scriptul le păstrează offseturile din editor.
- Hover/click polish pe pause menu, în stilul meniului principal, cu glow cald și sunet pe bus `SFX`.
- Slidere funcționale pentru sensitivity X/Y, zoom sensitivity, master/music/effects/dialogue volume; valorile se salvează în `user://settings.cfg`.
- Audio bus layout extins: `Music`, `SFX`, `Dialogue`, plus `Tomb` pentru ambianță/reverb.
- `main_menu.gd` aplică setările audio salvate, iar `player_controller.gd` aplică live look sensitivity separat pe X/Y + zoom multiplier.
- Importate `TripoModels/Testamente.glb` și `TripoModels/TreasureRoomUpdated.glb` cu `.import`; încă nu sunt plasate în nivel.

**Adițional implementat în afara roadmap-ului original:**
- Sistem complet de oil reservoirs (lămpile de pe perete au oil propriu, drain idle lent, refill prin hold E, dim/depleted)
- Movement Oil Spill pe lampa portativă: idle consumă cel mai puțin, crouch/crawl/slow walk economisesc ulei, sprint/jump consumă mult mai mult ca efect de ulei vărsat
- Slot offhand permanent pentru lampă (mâna stângă), independent de cele 4 sloturi tool
- Selectare lampă cu Z ca slot special offhand; refill/drop funcționează doar când lampa este selectată
- Left-hand HUD slot + iconițe inventar dinamice pentru tool slots
- Debug overlay F3 pentru tuning: speed/stance/noise/movement feel/oil multiplier/drain/light strength/interactable
- Viewmodel sway pe stance/speed: sprint/airborne mai instabil, crouch/crawl mai stabil
- Movement feel pass: sprint accelerează mai progresiv, schimbările bruște de direcție sunt mai puțin instant, crouch/crawl reduc headbob-ul, landing-ul are camera dip subtil
- Low-oil light feedback: lampa portabilă și lămpile statice cu rezervor pierd gradual energie/range și devin mai instabile înainte să se stingă
- Feedback audio simplu pentru pickup/drop/lamp select/lamp toggle/refill, cu fallback pe SFX existente până la asseturi dedicate
- Keybinds reorganizate: F=pickup, X=drop, E=use (lean Q/R eliminat)
- Auto-swap lampă la pickup duplicate (Minecraft-style)
- Dialogue skip cu J: typewriter instant + panou ascuns în 0.2s; hint [J] skip în panou; merge și în cinematic-uri
- NPC Liang cu monk.glb, 23 replici din NARRATIVE_AND_DIALOGUE.md, animații per-replică (sitting/surprised/frustrated), script liang.gd
- Monolog interior post-obiectiv "find_liang" cu delay configurabil
- BreakableInteractable pe TunnelEntrance2 (necesită wedge+hammer)
- Objective "cross_crossbow_corridor" după terminarea dialogului cu Liang

## Faza 1 - Organizare și blockout

- Creează sau curăță un blockout clar pentru ruta principală.
- Etichetează zonele: Atelier, Curtea cuptoarelor, Depozite, Coridor arbalete, Sala procesională, Sala mercurului, Poarta de mijloc, Camera mecanismelor, Drenaj, Puț.
- Pune trigger-e de obiectiv între zone.
- Adaugă lumini temporare calde și zone întunecate.
- Marchează rutele alternative fără să fie toate finalizate.

Rezultat: playerul poate parcurge harta de la start la ieșire într-o formă brută.

## Faza 2 - Controller stealth

- Ajustează `player_controller.gd` pentru stealth:
  - mers lent;
  - alergare riscantă;
  - crouch/strecurare dacă se potrivește;
  - emitere nivel zgomot.
- Adaugă interacțiune contextuală `E`.
- Adaugă sistem simplu de obiective.

Rezultat: playerul simte că este meșteșugar vulnerabil, nu soldat.

## Faza 3 - HUD

- Vitalitate stânga sus.
- Vapori sub vitalitate, ascuns în afara zonelor toxice.
- Obiectiv curent dreapta sus.
- Inventar rapid stânga jos.
- Lampă / ulei dreapta jos.
- Prompt contextual central-jos sau lângă obiect.

Rezultat: HUD funcțional, atmosferic, fără sci-fi.

## Faza 4 - Interacțiuni și iteme

Iteme inițiale:

- lampă;
- daltă;
- pană de lemn;
- ceramică pentru distragere;
- pânză umedă;
- tăbliță cu dovada.

Interacțiuni:

- ridicare item;
- citire tăbliță;
- împingere obiect;
- blocare mecanism;
- dezactivare capcană;
- deschidere poartă / trecere.

## Faza 5 - Capcane și stealth

- Creează o capcană de arbaletă simplă:
  - placă de presiune;
  - direcție de tragere;
  - bolț vizibil;
  - cooldown / declanșare unică;
  - dezactivare cu daltă;
  - blocare cu pană de lemn.
- Creează primul paznic cu:
  - patrulare;
  - con de vedere;
  - suspiciune;
  - detectare.

## Faza 6 - Sala Mercurului

- Creează zone de mercur cu trigger de Vapori.
- Adaugă poduri și rute.
- Adaugă efecte simple:
  - blur sau overlay;
  - sunet respirator;
  - reducere viteză;
  - damage la expunere severă.
- Pânza umedă reduce temporar expunerea.

## Faza 7 - Poarta și mecanismele

- Poarta de mijloc este blocată.
- Camera mecanismelor permite:
  - tras pârghie;
  - blocat roată;
  - folosit pană / daltă;
  - deschisă o trecere mică;
  - alegere de timp pentru ucenic sau dovadă.

## Faza 8 - Finaluri

Implementează întâi două finaluri:

- scapi singur;
- porțile s-au închis.

Apoi adaugă:

- salvezi dovada;
- salvezi ucenicul;
- secret ending.

## Faza 9 - Polish vizual și audio

- Lumini calde, umbre puternice.
- Praf, fum, cenușă.
- Lanțuri, roți, porți, soldați strigând.
- Materiale simple: teracotă, bronz, piatră întunecată, lemn.
- UI în stil pergament/bronz.

## Prioritatea următoare recomandată

Stare actuală: meniul in-game de pauză și ecranul de setări sunt integrate cu asseturi parchment, hover/click polish, slidere funcționale și salvare în `user://settings.cfg`. Audio are bus-uri dedicate (`Music`, `SFX`, `Dialogue`, `Tomb`). `Testamente.glb` și `TreasureRoomUpdated.glb` sunt importate, dar încă neplasate în nivel. Cinematicul gardienilor, samurai.glb, ladder/mercury/trap imports rămân baza gameplay deja pregătită.

1. **Playtest pause/settings fullscreen** — ajustează manual pozițiile sliderelor sub `SettingsArt` și verifică flow-ul fără `BackButton`.
2. **Plasare `TreasureRoomUpdated.glb` / `Testamente.glb`** — decide unde intră în ruta următoare și plasează-le în nivel cu coliziuni/verificare scară.
3. **Right-hand HUD frame** — completează vizualul mâinii drepte ca piesă mare oglindă pentru OilPhial. Iconițele tool sunt deja integrate.
4. **Plasare gardieni live + waypoints** — există `Scene_guard` (GuardLive2) și `GuardWaypoints` în Workshop; walk/idle dinamic funcționează, deci se pot popula coridoarele cheie.
5. **Crossbow Trap funcțional în nivel** — există script `crossbow_trap.gd` și `bolt.gd`, dar capcanele nu sunt plasate fizic în `03_CrossbowCorridor`. Adaugă plăci de presiune + dezactivare cu daltă/pană.
6. **Plasare `trap_tile.tscn` + `spike_trap.tscn`** — scripturile + scenele sunt importate din branch Vlad; verifică plasarea și declanșarea.
7. **Plasare BreakableInteractable la celelalte TunnelEntrance-uri** (1, 3, etc.) — există deja pe TunnelEntrance2.
8. **Sistem Mercury portabil** — scripturile (mercury_vase/extracting/spilling/flowing) sunt importate, dar nu sunt încă plasate în scena Sala Mercurului.
9. **Sala Mercurului — gameplay vapori toxici** — vizualul există (MercuryVapor + MercuryGlow); de adăugat zonă damage la player + slow + overlay.
10. **ObjectiveTriggers la praguri** — există `objective_trigger.gd`, lipsesc instanțele plasate la intrările camerelor.

## Quick wins (1-2h fiecare)

- [x] **Dialogue skip (tasta J)** — typewriter instant, merge și în cinematic-uri
- [x] **NPC Liang cu dialog complet** — 23 replici, animații per-replică, monolog post-obiectiv
- [x] **BreakableInteractable** — demonstrație pe TunnelEntrance2
- [x] **Pause/settings menu** — asseturi parchment separate, hover/click polish, slidere funcționale audio/sensitivity
- [ ] **Frame mare „mâna dreaptă" HUD** — încă nelivrat, design în `IMAGE_PROMPTS.md`
- [ ] Tuning cu overlay F3: reglează `idle/crouch/crawl/sprint/jump` oil multipliers + `viewmodel_sway` până când lampa se simte fizică
- [ ] Înlocuiește fallback SFX pentru pickup / drop / lamp toggle / refill cu asseturi dedicate Qin-flavored
- [ ] Variație random a `oil_drain_rate` la fiecare lampă instanță (între 0.4 și 0.8) pentru variație gameplay
