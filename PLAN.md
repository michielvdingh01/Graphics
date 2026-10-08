# Bouwplan

Een first person shooter met de best haalbare graphics die met AI te maken zijn, die in de komende maanden stap voor stap beter wordt naarmate er nieuwe AI-modellen uitkomen.

## Uitgangspunten

- **Engine: Godot 4 (Forward+ renderer).** Scènes, shaders en scripts zijn tekstbestanden, dus AI kan vrijwel alles zelf schrijven, draaien en testen. Unreal 5 heeft een hoger grafisch plafond, maar de assets zijn binair en het draait zwaar op 16 GB.
- **Hardware: MacBook Pro M1 Pro, 16 GB.** Fotorealisme op AAA-niveau met 60 fps is hierop niet haalbaar. Wel haalbaar is één kleine, dichte, goed belichte omgeving die er zeer overtuigend uitziet. Een snellere machine komt later.
- **Gameplay en graphics strikt gescheiden.** Elk asset krijgt een regel in een manifest (prompt, gebruikt model, versie), zodat het bij een nieuw model opnieuw gegenereerd kan worden zonder code aan te raken.
- **Performancebudget: 60 fps op 1440p met upscaling.** De benchmark bewaakt dit bij elke wijziging.

## Fasering

| Fase | Periode | Resultaat | Status |
|---|---|---|---|
| 0. Fundament | week 1–2 | Godot-project, git, FPS-controller in een greybox-level, vaste benchmarkscène met automatische screenshots en fps-meting | Klaar |
| 1. Gunfeel | week 3–6 | Beweging (sprint, crouch, slide), 2–3 wapens met recoil en ADS, hit-feedback, geluid, simpele vijanden met navigatie | Klaar |
| 2. Vertical slice | maand 2–3 | Eén klein level op maximale kwaliteit: PBR-materialen, gebakken lightmaps plus SDFGI, volumetrische mist, post-processing | Klaar; vaten, kratten en barrières zijn echte modellen, de overige props nog niet. Zie hieronder |
| 3. AI-assetpipeline | parallel aan fase 2 | Scripts die uit het manifest props, texturen, skyboxes en geluid genereren en importeren | Begin gemaakt: decals komen procedureel uit het manifest en modellen van Poly Haven worden via het manifest opgehaald. Zelf genereren van props, wapens, vijanden en geluid wacht op een generatiedienst |
| 4. Moderne shooter-eisen | maand 4–5 | Menu, grafische instellingen, controller-support, FSR-upscaling, checkpoints, meer wapens en vijandtypes, tweede level | Klaar, zie hieronder |
| 5. Upgrade-loop | doorlopend | Bij elk nieuw model één assetcategorie opnieuw genereren en A/B vergelijken in de benchmarkscène | |

## Waar de graphics vandaan komen

1. **Belichting eerst.** Goede lightmaps, reflectieprobes en tonemapping doen meer voor realisme dan betere modellen, en het is de goedkoopste winst op deze hardware.
2. **Gescande basis, AI als aanvulling.** CC0-scans (Poly Haven) voor oppervlakken en HDRI's. AI voor unieke props, variaties, decals en concept art.
3. **Hero-assets kritisch behandelen.** Het wapen in beeld en de vijanden zijn waar AI-gegenereerde 3D het zwakst is (topologie, rigging, animatie). Reken op handmatige opschoning in Blender, of gebruik voorlopig bestaande assets.
4. **Performancebudget vanaf dag één.** Zie de uitgangspunten.

## Upgrade-loop

- Elke maand, of bij een relevante modelrelease, één categorie kiezen: texturen, props, personages, animatie of audio.
- Die categorie opnieuw genereren vanuit het manifest, de benchmark draaien en screenshots en fps naast elkaar leggen.
- Alleen wat zichtbaar beter is én binnen het budget blijft, gaat naar `main`.

## Nulmeting (fase 0)

Gemeten op 6 oktober 2026 op de M1 Pro, 1920×1080, met SDFGI, SSAO en glow aan, greybox zonder echte assets.

| Camerastandpunt | Gemiddeld | 1% low |
|---|---|---|
| Overview | 164 fps | 68 fps |
| Corridor | 147 fps | 113 fps |
| Platform | 155 fps | 115 fps |

De benchmark draai je met `tools/benchmark.sh`; resultaten komen in `benchmark/results/`.

## Vertical slice (fase 2)

Het level is een verlaten fabriekshal bij zonsondergang: hal met kraanbaan en tussenvloer, plus een aanbouw met gang en twee kamers. De hoofdscène is `scenes/factory.tscn`; de greybox uit fase 0 en 1 staat nog in `scenes/main.tscn`.

**Wat er staat**

- Gescande PBR-materialen van Poly Haven (2K, CC0) en een HDRI als lucht, vastgelegd in `assets/manifest.json`.
- Gebakken lightmaps voor al het indirecte licht; zon en lampen zijn realtime met schaduwen.
- Volumetrische mist met lichtbundels, reflectieprobes per ruimte, screen-space reflecties, SSAO, SSIL, glow en AgX-tonemapping.
- Een natte-vloer-shader met plassen en een lenspass met vignette, filmkorrel en lichte chromatische aberratie.
- Vuil glas in alle ramen en dakramen, met hier en daar een ontbrekende ruit.
- Decals: lekstrepen onder de ramen, vuil langs de plinten en olievlekken op de vloer.
- Gescande CC0-modellen van Poly Haven (1K) voor vaten (drie varianten), houten kisten (twee) en betonnen wegbarrières. Ze staan in het manifest, krijgen bij import lightmap-UV's (importstandaard in `project.godot`) en worden door de levelbouwer geplaatst, die er zelf een eenvoudige botsvorm bij zet.

**Afwijking van het plan: SDFGI staat uit.** Naast de lightmaps gaf SDFGI geen zichtbaar verschil, maar het kostte circa 25 fps. Dynamische objecten krijgen hun indirecte licht van de lightmap-probes.

**SSIL staat alleen nog op Ultra aan.** Het kostte 1,25 ms van een frame van 14 ms (op 1440p met FSR 2), terwijl het naast de lightmaps alleen zonbeschenen objecten een fractie lichter maakt; in een vergelijking naast elkaar is het verschil niet te zien. Op High levert het weglaten 7 fps op.

**Werkwijze**

| Stap | Commando |
|---|---|
| Assets ophalen volgens het manifest (texturen, HDRI's en modellen) | `tools/fetch_assets.py` |
| Nieuw opgehaalde bestanden importeren | `godot --headless --path . --import` |
| Procedurele decals opnieuw genereren volgens het manifest | `tools/gen_decals.sh` |
| Levelgeometrie opnieuw genereren uit `tools/levels/<naam>.gd` | `tools/build_level.sh factory` of `depot` |
| Lightmaps bakken (nodig na elke geometrie- of lichtwijziging, 1 tot 1,5 minuut) | `tools/bake_lightmaps.sh [res://scenes/depot.tscn]` |
| Snel screenshots van de benchmarkstandpunten | `tools/shots.sh` |
| Meten wat elk effect per standpunt kost (schaduwen, SSAO, SSIL, SSR, mist, glow, props, decals, glas, lenspass) | `tools/benchmark.sh --profile` |
| Een run zonder bepaalde effecten, om screenshots te vergelijken | `tools/benchmark.sh --off=ssil,glow` |
| Gameplay en beide levels testen (headless) | `tools/selftest.sh` |

**Meting** op 8 oktober 2026, M1 Pro, 1920×1080, kwaliteit High (zonder SSIL), met glas, decals en modellen:

| Camerastandpunt | Gemiddeld | 1% low |
|---|---|---|
| Overview | 97 fps | 67 fps |
| Corridor | 101 fps | 82 fps |
| Platform | 94 fps | 76 fps |
| Hall | 103 fps | 84 fps |

De modellen brengen het aantal driehoeken per frame van circa 80 duizend naar 0,4 tot 1 miljoen en kosten op 1440p met FSR 2 hooguit 0,4 ms per frame. De lightmap van de fabriek groeide van 25 naar 37 MB, omdat elke prop een eigen stukje lightmap krijgt.

**Nog open in deze fase**

- Machines, containers, tanks, stellingen en pallets zijn nog samengesteld uit dozen en cilinders, en het wapen en de vijanden ook. Poly Haven heeft geen pallet en geen kubusvormige krat; de kratstapels bestaan daarom uit langwerpige kisten.

## Moderne shooter-eisen (fase 4)

**Wat er staat**

- **Menu.** Titelscherm over het geladen level, levelkeuze, pauzemenu (Esc of Start) en een instellingenscherm. Alles is met muis, toetsenbord en controller te bedienen. `--play` slaat het titelscherm over.
- **Instellingen**, bewaard in `user://settings.cfg`: kwaliteit (Low tot Ultra), upscaler, renderschaal, V-Sync, fullscreen, fps-teller, gezichtsveld, muis- en stickgevoeligheid, Y-as omkeren en volume. Een kwaliteitsniveau zet alleen effecten uit die het level zelf aan heeft staan.
- **Upscaling.** Bilinear, FSR 1, FSR 2 en op Apple-hardware MetalFX Spatial en Temporal.
- **Controller.** Linkerstick lopen, rechterstick kijken, RT vuren, LT richten, A springen, B bukken en sliden, X herladen, LB en RB wapen wisselen, linkerstick indrukken sprinten, Start pauze. Niet getest met een fysieke controller.
- **Checkpoints.** Elke wave die je bereikt is een checkpoint in `user://save.cfg`. Na een dood of een herstart van het spel ga je daar verder.
- **Wapens.** SMG (toets 4) en Marksman met reflexvizier (toets 5), naast rifle, pistol en shotgun.
- **Vijanden.** Naast de grunt een rusher (snel, zwak, slaat van dichtbij) en een heavy (traag, veel health, lange salvo's). Rushers komen vanaf wave 2, heavies vanaf wave 4. Elke vijand gaat 1,5 tot 4 seconden na het spawnen op zoek naar de speler.
- **Tweede level: Depot.** Een ommuurd containerterrein in de schemering met een overdekt laadperron en een portiersloge, verlicht door schijnwerpers. Hoofdscène `scenes/depot.tscn`, beschrijving in `tools/levels/depot.gd`. De gedeelde bouwstenen staan in `tools/level_builder.gd`.

**Meting op 1440p** op 8 oktober 2026, M1 Pro, 2560×1440, kwaliteit High (zonder SSIL), met de modellen. Het budget van 60 fps wordt met upscaling gehaald, met 15 fps over.

| Level | Instelling | Gemiddeld (laagste en hoogste standpunt) | 1% low |
|---|---|---|---|
| Fabriek | FSR 2 op 67% | 76–80 fps | 67–71 fps |
| Fabriek | MetalFX Temporal op 67% | 77–84 fps | 68–74 fps |
| Fabriek | Geen upscaling | 60–66 fps | 55–60 fps |
| Depot | FSR 2 op 67% | 75–81 fps | 67–73 fps |

Met SSIL erbij haalde de fabriek met FSR 2 gemiddeld 66–72 fps en een 1% low die per run tussen 52 en 66 fps lag, afhankelijk van wat de machine verder deed. Dat was te krap om er nog iets bij te zetten.

Het depot haalt op 1920×1080 zonder upscaling 94–108 fps gemiddeld en 75–87 fps 1% low.

De benchmark neemt hiervoor opties aan: `tools/benchmark.sh --res=2560x1440 --upscaler=fsr2 --scale=0.67 --scene=res://scenes/depot.tscn`. macOS tekent een bedekt venster niet; de benchmark mat dan steeds circa 145 fps, wat op een uitstekende meting lijkt. Hij telt daarom nu alleen een ononderbroken reeks getekende frames en begint een standpunt opnieuw zodra het venster weer zichtbaar is. Dat werkt: na een korte onderbreking ging een run vanzelf verder, en een run waarvan het venster tien minuten lang niet getekend werd, bleef al die tijd wachten. Een run met de melding `window is not being drawn` gooi je wel weg, want de frames eromheen zijn onbetrouwbaar (één zo'n run gaf een 1% low van 21 fps). Na een minuut zonder getekend frame hoort de benchmark met een fout te stoppen; dat is nog niet in het echt gebeurd. Een onbekende upscaler of een onbekend effect bij `--off` geeft een fout in plaats van een meting onder de verkeerde naam. Meet met niets anders op de GPU: een tweede Godot ernaast halveert de cijfers.

**In deze fase opgelost**

- Vijanden die buiten het zicht van de speler spawnden, bleven daar voor altijd staan, waardoor een wave kon stilvallen. Ze komen nu vanzelf naar de speler toe (`HUNT_DELAY` in `scripts/game.gd`).
- De tussenvloer en de twee kamers in de aanbouw zaten niet aan het navmesh vast: de trap en de deuren waren te smal. Vijanden die daar spawnden kwamen er niet af. De trap is nu 2,2 m breed en de deuren 1,6 m, en de selftest controleert voor elk level dat elk spawnpunt de speler kan bereiken.

**Nog open**

- Geen instelbare toetsen en geen aim assist voor de controller.
- De HUD schaalt niet mee op hoge resoluties; de tekst is daar klein.
