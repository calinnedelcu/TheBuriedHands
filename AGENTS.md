# AGENTS.md - Context Pentru AI

Acest repo este proiectul Godot **TheBuriedHands**.

Înainte să modifici cod, scene, UI sau asseturi, citește:

1. `docs/AI_START_HERE.md`
2. `docs/GAME_DESIGN_BRIEF.md`
3. documentul specific zonei la care lucrezi: hartă, gameplay, UI, asseturi, personaje sau narațiune.

## Identitate proiect

- Titlu: **TheBuriedHands**
- Gen: stealth / survival / escape / puzzle adventure
- Loc: sector interior istoric-plauzibil al mausoleului Qin Shi Huang, Lishan
- Perioadă: 210 î.Hr., imediat după moartea Primului Împărat
- Stil: low-poly, stylized, dark, cinematic, nu realist, nu cartoon
- Ton: întunecat, tensionat, tragic, lent, cu momente de panică

## Reguli creative obligatorii

- Jocul este istoric-plauzibil, nu fantasy.
- Nu introduce magie, monștri, super-puteri, explozibili, arcade combat sau distrugeri spectaculoase de tip fantasy.
- Nu pretinde că știm exact cum arată camera funerară reală a împăratului.
- Folosește formularea: „Reconstrucție istoric-plauzibilă inspirată de descrierile lui Sima Qian și de descoperirile arheologice ale complexului Qin Shi Huang.”
- Protagonistul este meșteșugar, nu soldat. Avantajul lui este înțelegerea construcției, nu lupta.
- Amenințarea principală vine din sigilare, paznici, capcane, întuneric, lipsă de timp și vapori toxici.

## Godot project state

- Engine țintă: Godot 4.6
- Main scene: `res://scenes/main_menu.tscn`
- Level scene: `res://scenes/tomb_layout.tscn`
- Script folder: `Scripts/`
- Imported model folder: `TripoModels/`
- Tripo bridge plugin există în `addons/Tripo3d_Godot_Bridge/`

Vezi `docs/CURRENT_PROJECT_STATE.md` pentru detalii.

## Stil de implementare

- Menține schimbările mici și verificabile.
- Respectă structura Godot existentă.
- Nu șterge asseturi importate sau scene existente fără cerere explicită.
- Pentru gameplay, preferă sisteme simple și clare: stealth, obiective, interacțiuni, trigger-e de cameră.
- Pentru UI, păstrează limbajul vizual: pergament, bronz, lemn, piatră, crem, maro, negru transparent, roșu închis, fără sci-fi.
- Pentru level design, păstrează scara propusă: sector de aproximativ 185 m est-vest x 120 m nord-sud.

## Când creezi sau modifici asseturi

Direcție generală:

> Low-poly stylized 3D game asset, dark ancient Chinese Qin dynasty tomb atmosphere, simple geometry, readable silhouette, muted earth tones, terracotta, bronze and dark stone materials, warm oil lamp lighting, not realistic, not cartoon, suitable for indie stealth game environment.

Pentru UI:

> Ancient Qin-inspired game UI, parchment, wood, bronze, simple geometric border, readable Romanian text, clean white background for asset sheets, transparent in-game overlays, no modern sci-fi elements.

## Prioritate actuală de producție (2026-05-15)

Sisteme de bază sunt complete (controller, lumini, lampi cu offhand, oil reservoirs, HUD slot bar cu texturi Qin, keybinds F/E/X). Următoarele priorități:

1. **Right-hand HUD frame + iconițe tool** pentru slot-urile 1-4 (asset prompt în `docs/IMAGE_PROMPTS.md`).
2. **Plasare gardieni patrulanți** + walk cycle pentru `guard1-idle.glb`.
3. **Crossbow Trap funcțional** în `03_CrossbowCorridor` (plăci presiune, dezactivare cu daltă, blocare cu pană).
4. **Sala Mercurului — damage gameplay** peste vizualul vaporilor existent.
5. **ObjectiveTriggers** plasate la praguri pentru flow narrativ.

Pentru detalii: `docs/IMPLEMENTATION_ROADMAP.md`, `docs/CURRENT_PROJECT_STATE.md`.

