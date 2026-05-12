# AI Task Templates

Folosește aceste șabloane când deschizi chat-uri noi sau când dai task-uri scurte unui agent.

## Start general

```text
Lucrăm la proiectul Godot TheBuriedHands. Citește AGENTS.md și docs/AI_START_HERE.md, apoi respectă regulile din docs/HISTORICAL_PLAUSIBILITY.md. Vreau să lucrezi la: [TASK].
```

## Task de implementare Godot

```text
Lucrăm în proiectul Godot TheBuriedHands. Citește AGENTS.md, docs/CURRENT_PROJECT_STATE.md și documentul relevant pentru task.

Task: [descrie task-ul]

Constrângeri:
- păstrează stilul low-poly dark cinematic;
- nu adăuga fantasy;
- nu șterge scene sau asseturi existente fără motiv;
- verifică schimbările la final;
- spune-mi exact ce fișiere ai modificat.
```

## Task pentru HUD / UI

```text
Lucrăm la UI pentru TheBuriedHands. Citește docs/UI_HUD_SPEC.md și docs/HISTORICAL_PLAUSIBILITY.md.

Task: creează / modifică [HUD, pause menu, fail screen, prompturi, iconițe].

Stil: pergament, bronz, lemn, piatră, crem, maro, negru transparent, fără sci-fi, fără fantasy.
Texte în română unde sunt specificate în document.
```

## Task pentru level design

```text
Lucrăm la harta TheBuriedHands. Citește docs/LEVEL_AND_MAP_SPEC.md și docs/GAMEPLAY_SYSTEMS.md.

Task: construiește / rafinează zona [Atelier, Coridor arbalete, Sala Mercurului, Camera mecanismelor].

Important:
- sectorul total este istoric-plauzibil, nu camera reală centrală;
- păstrează rutele principale și alternative;
- folosește lumină caldă, umbre puternice și materiale mate;
- gameplay-ul trebuie să susțină stealth, puzzle-uri și tensiune.
```

## Task pentru gameplay systems

```text
Lucrăm la sistemele de gameplay pentru TheBuriedHands. Citește docs/GAMEPLAY_SYSTEMS.md.

Task: implementează [stealth / zgomot / vapori / lampă / inventar / interacțiune E / obiective].

Păstrează sistemul simplu, clar și extensibil. Protagonistul este meșteșugar, nu soldat.
```

## Task pentru asset generation

```text
Lucrăm la asseturi pentru TheBuriedHands. Citește docs/ASSET_PRODUCTION_GUIDE.md, docs/CHARACTERS.md și docs/IMAGE_PROMPTS.md.

Task: generează / modelează [asset].

Direcție: low-poly stylized, Qin dynasty tomb atmosphere, muted earth tones, terracotta, bronze, dark stone, warm oil lamp lighting, not realistic, not cartoon, no fantasy.
```

## Task pentru personaje

```text
Lucrăm la personajele TheBuriedHands. Citește docs/CHARACTERS.md și docs/HISTORICAL_PLAUSIBILITY.md.

Task: creează / modifică [protagonist, soldat Qin, paznic cu suliță, paznic cu lanternă, ucenic].

Important:
- soldații trebuie să pară Qin / China antică, nu samurai;
- protagonistul este meșteșugar, nu războinic;
- stilul este low-poly, cinematic, nu realist și nu cartoon.
```

## Task pentru narațiune

```text
Lucrăm la narațiunea TheBuriedHands. Citește docs/NARRATIVE_AND_DIALOGUE.md și docs/HISTORICAL_PLAUSIBILITY.md.

Task: scrie / rafinează [dialog, intro, final, obiective, text de tăbliță].

Ton: tragic, reținut, istoric, tensionat. Nu folosi magie, profeții fantasy sau explicații moderne.
```

## Prompt scurt pentru continuare

```text
Continuă TheBuriedHands din repo. Respectă AGENTS.md. Următorul pas este: [TASK].
```

