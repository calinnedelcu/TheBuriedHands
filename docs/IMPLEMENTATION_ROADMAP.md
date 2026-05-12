# Implementation Roadmap

## Obiectiv

Transformă proiectul existent într-un vertical slice jucabil care demonstrează identitatea TheBuriedHands:

> atelier întunecat, ordin de sigilare, stealth, capcană cu arbalete, mercur toxic, poartă mecanică și o rută de evacuare.

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

1. Creează sistemul de obiective și prompturi.
2. Adaugă HUD minimal.
3. Adaugă itemele lampă/daltă/pană.
4. Conectează ruta Atelier -> Coridor arbalete.
5. Fă primul puzzle de capcană.

