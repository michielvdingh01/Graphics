---
name: buit
description: Maak een nieuw voorwerp om om te vechten bij capture the flag (een "buit") uit een beschrijving van Michiel, zoals "maak een rubberen eend als buit", "doe een tuinkabouter erbij" of "/buit gitaar", ook terwijl hij met vrienden speelt. Bouwt het model in Blender zonder venster en zonder GPU, zet het waar het spel het vindt en controleert het in het spel.
---

# Een buit maken uit een beschrijving

Michiel typt wat hij als buit wil en speelt er een paar minuten later mee. Hij zit dan vaak midden in een avond met vrienden: werk snel, vraag alleen iets als de beschrijving echt twee kanten op kan, en laat het spel dat hij speelt met rust.

Een gemaakte buit is een map op deze machine, `~/Library/Application Support/Godot/app_userdata/Graphics FPS/prizes/<naam>/` (in het spel `user://prizes/<naam>/`), met het model als `model.glb` en een `prize.json`. Het spel leest die map als het scherm "Multiplayer" opent: een buit die gemaakt is terwijl het spel draait, staat er dan bij, zonder herstart en zonder build. Hoe het spel zo'n map leest staat in `scripts/prize.gd`; de buiten die met het spel meekomen staan in `assets/prizes.json`.

## Stappen

1. **Naam.** Kies een naam in kleine letters met underscores, in het Engels zoals de rest van het spel (`garden_gnome`), een titel zoals het menu hem toont ("Garden gnome") en hoe een zin hem noemt ("the gnome"). Kijk in de map hierboven en in `assets/prizes.json` of de naam vrij is; een naam uit de tabel laat het spel weg.
2. **Script.** Schrijf een script dat het voorwerp bouwt met `tools/prizes/kit.py`. Zet het in je scratchpad; met het voorwerp gaat een kopie mee als `build.py`. Begin bij het voorbeeld dat er het meest op lijkt:
   - `tools/prizes/rubber_duck.py`: rond en zacht, als afstandsveld (`kit.Field`: bollen, staven en blokken die in elkaar overlopen);
   - `tools/prizes/traffic_cone.py`: gedraaide profielen (`kit.lathe`) en een blok;
   - `tools/prizes/trophy.py`: allebei, met hengsels als ring waarvan een deel is weggesneden.
3. **Maken.** `tools/make_prize.sh <script>` draait het script in Blender, zet de buit in de map, maakt `preview.png` op de processor en controleert de buit in het spel (`tools/prize_check.sh`). Lees de regels met `WARNING`.
4. **Kijken.** Bekijk `preview.png` (met Read). Lijkt het niet op wat hij vroeg, of klopt de maat niet naast de figuur van 1,8 m, pas dan het script aan en maak hem opnieuw: dezelfde naam overschrijft de vorige.
5. **Blad in het spel**, alleen als niemand speelt. `ps -axo pid,etime,args | grep '[G]odot'`: staat er een Godot met `--path` zonder `--headless`, of de editor, dan speelt hij; sla dit dan over. Anders maakt `tools/prize_sheet.py <naam>` in anderhalve minuut met de GPU het blad met de buit thuis, gedragen door een soldaat en gevallen, als `sheet.jpg` in de map van de buit.
6. **Zeggen.** De buit staat onder "Multiplayer", bij capture the flag, achter de knop "Prize", met "made here" erachter. Stond dat scherm al open, dan moet hij het één keer opnieuw openen. Stuur hem het blad of anders `preview.png` als bestand, met één regel erbij.

## Maten

- **Meters, Z omhoog, de voorkant naar -Y.** `kit.save()` zet het voorwerp met zijn onderkant op de grond en midden boven de oorsprong.
- **Groot genoeg om door een hal te zien:** de langste kant 0,5 tot 1,1 m, niet hoger dan 1,5 m. De banaan is 1,05 m lang en de eend 83 cm. Iets wat in het echt klein is, wordt reuzengroot.
- **1 000 tot 5 000 driehoeken.** Geef dat aan `kit.shape(..., triangles=...)`; kleine bolletjes (`kit.ball`) kiezen hun detail zelf.
- **Iets in de kleur van het team**, met `team=True`, dat je van achteren en van opzij ziet: een band, kraag, lint, strik, sjaal of pet. Het materiaal ervan maakt in het spel plaats voor dat van een team; kies met `save(team_material=...)` tussen `team_paint` (verf), `team_ribbon` (lint, stof) en `team_leather`.
- **Waar hij op staat:** `football_stand`, een stip met een ring in de teamkleur, voor wat zelf staat; `banana_stand`, een kist, voor wat ligt of laag is; `flag_stand` alleen voor iets op een stok.
- **Houding:** laat `poses` weg; het spel rekent ze uit de maat. Thuis staat hij midden op zijn standaard, gevallen rechtop waar hij viel, en gedragen hangt hij als een rugzak tegen de rug, met zijn brede kant ertegen. Geef hooguit een draaiing om de verticale as, bijvoorbeeld `poses={"down": {"turn": [0, 40, 0]}}`. Een kanteling laat hem zweven of in de vloer zakken, want het spel rekent met de doos eromheen en niet met de vorm.

## Wat nog niet kan

- **Vrienden krijgen een gemaakte buit nog niet.** Hij staat alleen op deze machine. Wedstrijden over het netwerk bestaan nog niet (stap 4 van "Wedstrijden" in `PLAN.md`); als ze er zijn, moet de host zijn gemaakte buiten meesturen.
- **Een gemaakte buit zit niet in git.** Wil hij er een voor iedereen, dan gaat het script naar `tools/prizes/` en moet er een manier komen om hem mee te leveren.
