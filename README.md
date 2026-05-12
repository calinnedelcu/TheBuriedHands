# TheBuriedHands

**TheBuriedHands** este un joc stealth / survival / escape / puzzle adventure, low-poly dark stylized, plasat într-un sector istoric-plauzibil al complexului funerar Qin Shi Huang, la Lishan, în 210 î.Hr.

Jucătorul este un meșteșugar Qin prins în timpul sigilării mausoleului. Nu este un erou de acțiune și nu schimbă istoria. Este un om mic prins într-o decizie imperială brutală, care încearcă să scape, să salveze un ucenic sau să trimită adevărul afară înainte ca porțile să se închidă pentru totdeauna.

## Start rapid pentru AI / agenți

Pentru un chat nou, începe cu:

> Citește `AGENTS.md` și `docs/AI_START_HERE.md`, apoi lucrează în stilul proiectului TheBuriedHands.

Fișierele importante:

- [AGENTS.md](AGENTS.md) - instrucțiuni scurte pentru orice AI care lucrează în repo.
- [docs/AI_START_HERE.md](docs/AI_START_HERE.md) - contextul de intrare și ordinea recomandată de citire.
- [docs/GAME_DESIGN_BRIEF.md](docs/GAME_DESIGN_BRIEF.md) - designul complet condensat al jocului.
- [docs/HISTORICAL_PLAUSIBILITY.md](docs/HISTORICAL_PLAUSIBILITY.md) - regulile istorice: ce este permis și ce trebuie evitat.
- [docs/LEVEL_AND_MAP_SPEC.md](docs/LEVEL_AND_MAP_SPEC.md) - harta, camerele și rutele.
- [docs/GAMEPLAY_SYSTEMS.md](docs/GAMEPLAY_SYSTEMS.md) - stealth, zgomot, vapori, lampă, inventar.
- [docs/UI_HUD_SPEC.md](docs/UI_HUD_SPEC.md) - HUD, meniuri, prompturi și ecrane.
- [docs/ASSET_PRODUCTION_GUIDE.md](docs/ASSET_PRODUCTION_GUIDE.md) - lista de asseturi și direcții de generare/modelare.
- [docs/CHARACTERS.md](docs/CHARACTERS.md) - protagonist, soldați, paznici, ucenic.
- [docs/NARRATIVE_AND_DIALOGUE.md](docs/NARRATIVE_AND_DIALOGUE.md) - premisă, scene, dialoguri și finaluri.
- [docs/CURRENT_PROJECT_STATE.md](docs/CURRENT_PROJECT_STATE.md) - ce există acum în proiectul Godot.
- [docs/IMPLEMENTATION_ROADMAP.md](docs/IMPLEMENTATION_ROADMAP.md) - pași practici de producție.
- [docs/AI_TASK_TEMPLATES.md](docs/AI_TASK_TEMPLATES.md) - șabloane de prompt pentru chat-uri noi și task-uri punctuale.

## Tehnologie curentă

- Engine: Godot 4.6
- Main scene: `res://scenes/main_menu.tscn`
- Level scene: `res://scenes/tomb_layout.tscn`
- Scripturi existente: `Scripts/player_controller.gd`, `Scripts/main_menu.gd`, `Scripts/auto_play_first_animation.gd`
- Asseturi existente: modele importate în `TripoModels/`, background meniu în `scenes/ui/main_menu_bg.png`

## Regula de aur

Jocul este **istoric-plauzibil, nu fantasy**.

Formulare de folosit în materiale:

> Reconstrucție istoric-plauzibilă inspirată de descrierile lui Sima Qian și de descoperirile arheologice ale complexului Qin Shi Huang.
