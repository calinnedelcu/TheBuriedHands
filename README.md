# The Buried Hands / Mâinile Îngropate

Joc first-person de stealth și supraviețuire, plasat în mausoleul lui Qin Shi Huang, la Lishan, în anul 210 î.Hr. Ești un meșteșugar care modelează armata de lut. Mormântul se pecetluiește — cu tine înăuntru — iar ordinul e ca nimeni din cei care l-au văzut să nu iasă viu.

Reconstrucție istoric-plauzibilă, nu fantasy: pornește de la descrierea lui Sima Qian (*Shiji*, cap. 6) — râurile de mercur, cerul cu stele de pe boltă, arbaletele care trag singure — și de la ce s-a găsit în gropile armatei de teracotă.

Jocul e în **română și engleză** (se schimbă din meniu sau din Opțiuni).

## Povestea, pe scurt

1. **Atelierul.** Termini un soldat de lut. Poarta de bronz se închide; doi gardieni discută ordinul. Ucenicul tău îți cere lampa — i-o dai sau nu.
2. **Arhivele.** Gardieni cu torțe patrulează printre mesele scribilor. Găsește-l pe Liang, inginerul mecanismelor; registrul lucrătorilor e o dovadă, dacă ai curaj să-l iei.
3. **Sub munte.** Coridorul arbaletelor și tunelurile de serviciu: plăci de presiune, dale care se prăbușesc, o piatră de spart cu pana și ciocanul.
4. **Râuri de argint viu.** Sala Mercurului: harta imperiului cu râuri de mercur sub o boltă înstelată. Umple ulciorul fără să te otrăvești, înclină marea balanță și ridică podul de piatră.
5. **Tezaurul.** Canalul de scurgere, apoi lumina zilei.

Fiecare capitol se deschide cu un titlu pe ecran. Epilogul — scris cu cerneală pe hârtie, sub sigiliul meșteșugarilor — depinde de ce ai făcut pe drum: registrul, ucenicul.

## Mecanici

- **Lumină și întuneric:** gardienii te văd după cât de luminat ești — lampa ta, făcliile lor, opaițele de pe pereți. Stinge opaițele, ține lampa jos, mergi ghemuit.
- **Zgomot:** alergatul, săritul, obiectele aruncate se aud. Cioburile aruncate îi trimit pe gardieni în altă parte.
- **Lampa cu ulei:** se golește mai repede dacă alergi; o reumpli din opaițe (ține apăsat). Fără ea ești orb.
- **Poziții:** în picioare, ghemuit, târâș (prin locuri joase).
- **Mercurul:** vaporii te otrăvesc; cârpa umedă ajută, ținutul respirației la fel.
- **Inventar:** 4 sloturi în mâini plus obiecte în traistă; uneltele (daltă, pană, ciocan) au mai multe întrebuințări.
- **Numele meșteșugarilor:** ca pe soldații reali de teracotă, unele statui poartă numele celor care le-au făcut, apăsate în lut. Citește-le pe drum: epilogul spune câte nume ai scos din munte.
- **Checkpoint-uri:** la momentele importante; după moarte reîncepi de acolo, iar „Continuă" din meniu încarcă ultimul.

## Controale (implicite, se pot schimba din Opțiuni)

| Acțiune | Tastă |
| --- | --- |
| Mers | W A S D |
| Alergare | Shift |
| Ghemuit / Târâș | Ctrl sau C / Z |
| Săritură | Space |
| Folosește (apasă sau ține) | E |
| Aprinde / stinge lampa | F |
| Ridică lampa | click dreapta |
| Aruncă | click stânga sau G |
| Lasă jos | X |
| Sloturi | 1–4, rotița mouse-ului, H pentru mâini goale |
| Ține respirația | Q |
| Jurnal (obiectiv) | Tab |
| Pauză | Esc |
| Treci peste replică | Enter |

## Rulare

Proiectul e pentru **Godot 4.7.2** (Forward+). Deschide folderul în editor și apasă Play; scena principală este `scenes/menu/title.tscn`.

Modelele `.glb` sunt în Git LFS: după clonare rulează `git lfs pull`.

## Structura proiectului

- `Scripts/core/` — autoload-uri: `Settings`, `Sfx`, `Dialogue`, `Quest`, `Stealth`, `Game` (salvări, checkpoint-uri, moarte, final), `Music`.
- `Scripts/data/` — povestea ca date: pașii questului (`quest_db.gd`), dialogurile (`dialogue_db.gd`), creditele.
- `Scripts/player/`, `Scripts/ai/` (gardieni, NPC-uri), `Scripts/world/` (lămpi, capcane, mercur, atmosferă), `Scripts/level/` (momentele de poveste), `Scripts/ui/`.
- `scenes/level/mausoleum.tscn` — nivelul; `scenes/menu/title.tscn` — meniul; `scenes/dev/test_room.tscn` — camera de test.
- `localization/strings.csv` — toate textele, EN + RO (`tools/dev/edit_strings.py` le editează sigur).
- `assets/` — shadere, materiale, texturi, fonturi, tema UI, modele (`assets/models/`); `audio/` — sunet și muzică.
- `tools/blender/` — scripturi Blender care construiesc modelele și animațiile (gardianul Qin cu halebarda *ji*, meșteșugarii, ucenicul, bunurile funerare din tezaur, orașele în miniatură de pe harta imperiului, versiunile ușoare ale hărții și arhivelor). Se rulează cu `blender -b --python tools/blender/<script>.py`, apoi `godot --headless --import`.

## Unelte și teste

Toate se rulează prin `tools/dev/run.gd`:

```bash
godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/quest_bot_runner.gd
```

- `autopilot_runner` — joacă tot jocul cu input real (mers, scări, folosire), de la `--from=act1` la `act5`.
- `quest_bot_runner` — joacă toată povestea automat și verifică fiecare pas.
- `checkpoint_test_runner` — salvare, moarte, reîncercare, „Continuă".
- `test_player_runner`, `test_guard_runner` — mișcare, poziții, lampă; vedere, auz și atac la gardieni (au nevoie de fereastră: fără `--headless`, cu `--out=/folder`).
- `music_test_runner` — muzica și ambianța pe zone.
- `level_tour_runner`, `map_render_runner`, `title_shots_runner`, `look_runner`, `sequence_shots_runner` (`--seq=opening|sealing|chase|climb|causeway|ending`), `anim_sheet_runner` — capturi pentru verificare vizuală.
- `patch_level_runner` — modificări automate în nivel, fără să piardă ce s-a editat în editor.
- `tools/dev/check_scripts.gd` — compilează toate scripturile.
- `tools/audio/synth_ambience.sh`, `tools/audio/synth_echoes.py` — regenerează ambianțele și ecourile sintetizate.

## Credite

Vezi [CREDITS.md](CREDITS.md).
