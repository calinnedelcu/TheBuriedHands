# Gameplay Systems

## Stealth

Paznicii au trei stări:

1. **Niciun risc** - nu au observat nimic.
2. **Suspiciune** - au auzit ceva sau au văzut o umbră.
3. **Văzut** - playerul a fost detectat.

Indicator vizual:

- ochi pal/gri = niciun risc;
- ochi cu semn de întrebare = suspiciune;
- ochi roșu cu semn de exclamare = văzut.

Comportament recomandat pentru prima implementare:

- paznicii au con de vedere;
- sunetele generează puncte de interes;
- suspiciunea scade lent dacă playerul dispare;
- detectarea completă duce la urmărire scurtă sau fail în zone stricte.

## Zgomot

Trei niveluri:

1. **Zgomot redus** - mers încet.
2. **Zgomot mediu** - alergare ușoară, interacțiuni mici.
3. **Zgomot mare** - ceramică spartă, capcane declanșate, uși forțate.

Vizual:

- cerc mic gri;
- unde maro;
- unde roșii.

Surse de zgomot:

- pași;
- ceramică spartă;
- mecanisme;
- capcane;
- uși grele;
- obiecte împinse.

## Vitalitate

Sistem simplu de health, afișat ca segmente.

Poate fi afectată de:

- săgeți;
- lovituri;
- căderi;
- expunere toxică severă.

## Vapori

Apare doar în zone toxice, în special Sala Mercurului.

Crește când playerul stă aproape de mercur sau pe rute slab ventilate.

Efecte:

- vedere încețoșată;
- respirație grea;
- sunet înfundat;
- mișcare mai lentă;
- la expunere severă, pierdere de vitalitate.

Pânza umedă poate reduce temporar creșterea expunerii.

## Lampă / ulei

Lampa luminează zonele întunecate.

Uleiul scade lent.

Dacă se termină:

- vizibilitatea scade;
- capcanele sunt mai greu de observat;
- atmosfera devine mai tensionată;
- unele rute devin mai riscante, dar nu imposibile.

Regulă de design: lampa ajută playerul, dar poate atrage atenția prin crăpături sau în zone de stealth.

## Inventar rapid

3 sloturi rapide.

Sloturi inițiale recomandate:

1. lampă;
2. daltă;
3. pană de lemn.

Alte iteme:

- funie;
- pânză umedă;
- sigiliu Qin;
- tăbliță cu dovada;
- ceramică spartă pentru distragere.

## Interacțiuni

Prompt implicit: `E`

Acțiuni:

- Ia lampa;
- Deschide;
- Împinge;
- Dezactivează capcana;
- Citește tăblița;
- Blochează mecanismul.

## Puzzle-uri

Tipuri potrivite:

- blocarea unei roți cu pană de lemn;
- dezactivarea unui fir de declanșare;
- împingerea unei lăzi pentru acces;
- folosirea funiei pentru traversare;
- alegerea unei rute scurte, dar toxice, sau lungi, dar sigură;
- manipularea contragreutăților pentru o poartă.

Evită puzzle-uri moderne cu simboluri fantasy sau coduri abstracte care nu par integrate în spațiu.

