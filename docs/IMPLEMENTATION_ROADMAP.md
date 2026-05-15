# Implementation Roadmap

> Ultima actualizare: 2026-05-15.
> Vezi `CURRENT_PROJECT_STATE.md` pentru detalii tehnice ale codului existent.

## Obiectiv

Transformă proiectul existent într-un vertical slice jucabil care demonstrează identitatea TheBuriedHands:

> atelier întunecat, ordin de sigilare, stealth, capcană cu arbalete, mercur toxic, poartă mecanică și o rută de evacuare.

## Status pe faze

- [x] **Faza 1** — Blockout + lighting de bază (camere etichetate, rute, lumini calde, volumetric fog, praf, vapori mercur)
- [x] **Faza 2** — Controller stealth (WASD + crouch/crawl/sprint, head bob, jump, mouse look, noise emit)
- [~] **Faza 3** — HUD (vitalitate ✓, oil phial ✓ dinamic per-lampă, left-hand slot ✓, slot bar nou cu texturi Qin ✓, iconițe tool ✓, prompts contextual cu key prefix ✓, debug overlay F3 ✓; lipsește doar frame mare „mâna dreaptă")
- [~] **Faza 4** — Iteme și interacțiuni (lampă ✓ cu start/drop drain + Movement Oil Spill pe idle/crouch/crawl/sprint/jump, pickup item ✓, ceramic shard ✓ throw, lever ✓; daltă/pană/tăbliță există ca pickup placeholder fără asset 3D)
- [ ] **Faza 5** — Capcane + AI gardian (crossbow trap existent, guard AI cu PATROL/SUSPICIOUS/ALERT, dar lipsește walk cycle + plasare în nivel)
- [ ] **Faza 6** — Sala Mercurului (camera + vapori vizuali există; gameplay damage/blur încă neimplementat)
- [ ] **Faza 7** — Poarta + mecanisme
- [ ] **Faza 8** — Finaluri
- [~] **Faza 9** — Polish vizual (volumetric fog + dust + flicker + mercury breath + brazier embers ✓; audio minimal)

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

Stare actuală: vertical slice are sistem complet de lumini + lampe + inventar + offhand + HUD; lipsește gameplay-ul real de stealth.

1. **Right-hand HUD frame** — completează vizualul mâinii drepte ca piesă mare oglindă pentru OilPhial. Iconițele tool sunt deja integrate.
2. **Plasare gardieni + waypoints** în Workshop + Crossbow Corridor (există `Scene_guard` și `GuardWaypoints` în Workshop, dar nu sunt populate cu instanțe live patrulând în toate camerele).
3. **Walk cycle pentru guard** — modelul curent are doar idle (`guard1-idle.glb`). Fie regenerăm cu walk, fie atașăm walk anim peste idle.
4. **Crossbow Trap funcțional în nivel** — există script `crossbow_trap.gd` și `bolt.gd`, dar capcanele nu sunt plasate fizic în `03_CrossbowCorridor`. Adaugă plăci de presiune + dezactivare cu daltă/pană.
5. **Sala Mercurului — gameplay vapori** — vizualul există (MercuryVapor + MercuryGlow); de adăugat zonă damage la player + slow + overlay.
6. **ObjectiveTriggers la praguri** — există `objective_trigger.gd`, lipsesc instanțele plasate la intrările camerelor.
7. **Audio minim**: pași spațiali pe surface (clay/stone/wood/wet_stone), strigăte gardieni la DETECT, hum mecanism, scârțâit poartă.

## Quick wins (1-2h fiecare)

- Tuning cu overlay F3: reglează `idle/crouch/crawl/sprint/jump` oil multipliers + `viewmodel_sway` până când lampa se simte fizică
- Înlocuiește fallback SFX pentru pickup / drop / lamp toggle / refill cu asseturi dedicate Qin-flavored
- Variație random a `oil_drain_rate` la fiecare lampă instanță (între 0.4 și 0.8) pentru variație gameplay
