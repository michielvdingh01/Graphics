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
| 2. Vertical slice | maand 2–3 | Eén klein level op maximale kwaliteit: PBR-materialen, gebakken lightmaps plus SDFGI, volumetrische mist, post-processing | Klaar; de meeste props zijn echte modellen, en machines, containers, tanks, kraan, pallets, kasten en kluisjes zijn in code uitgewerkt, net als de vijf wapens met de handen die ze vasthouden en de drie vijanden. Zie hieronder |
| 3. AI-assetpipeline | parallel aan fase 2 | Scripts die uit het manifest props, texturen, skyboxes en geluid genereren en importeren | Begin gemaakt: decals, opschriften, kogelgaten, slijtagemaskers en de normal maps voor oppervlakken van dichtbij komen procedureel uit het manifest en modellen van Poly Haven worden via het manifest opgehaald. Zelf genereren van props, wapens, vijanden en geluid wacht op een generatiedienst |
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

## Personages

Naast de drie robots kan het spel mensen opstellen: soldaten, zombies en clowns, en straks vrienden die met een iPhone zijn gescand. Eén commando maakt van een modelbestand een personage; `assets/characters/manifest.json` zegt wie in welk thema welke rol speelt. Hoe ze bewegen is van de rig (`assets/animations/`); hier staat hoe ze er komen.

**Wat er staat**

| Thema | Grunt | Rusher | Heavy | Wat het is |
|---|---|---|---|---|
| `soldiers` | `soldier_01`, `_02`, `_03` | `soldier_04` | `soldier_05` | Echte modellen: vijf soldaten uit de Rocketbox-bibliotheek van Microsoft (MIT), realistisch, met helm, vest en uitrusting |
| `zombies` | `zombie_01`, `_02`, `_03`, `_06` | `zombie_04` | `zombie_05` | Plaatshouders: Rocketbox-burgers (een man, een vrouw, een verpleegster, een hardloper, een brandweerman) die door `--look=zombie` bleek en bloederig zijn geschilderd. `zombie_06` is eerst tot proefscan gemaakt en via de scanroute binnengekomen, zoals een gescande vriend |
| `clowns` | `clown_05`, `_01`, `_02` | `clown_06` | `clown_04` | `clown_05` en `clown_06` zijn gegenereerd uit een beschrijving en zijn echte clowns: kraag, haar, bolneus en pak zijn vorm, geen verf. `clown_01`, `_02` en `_04` zijn plaatshouders: Rocketbox-burgers door `--look=clown` geschminkt, met een neus als los bolletje. `clown_03` is de plaatshouder die `clown_06` heeft vervangen; de dikke `clown_07` heeft zijn plaatje al en wacht op GPU-tijd |
| `zombies_blocky` | `zombie_blocky_01`, `_02` | `_03` | `_04` | Plaatshouders in een andere stijl, om te vergelijken: twee blokfiguren van Kenney (CC0), zes dozen elk |

- Een personage is 7 tot 15 duizend driehoeken (de scan 19,7 duizend), 1,3 tot 2,6 MB, één mesh met één materiaal en één textuurset van 1K: kleur, normal en ruwheid. Wie haar op doorzichtige kaarten heeft, krijgt een tweede materiaal op dezelfde texturen. Samen zijn de eenentwintig 35 MB.
- Het manifest geeft per rol het wapen (een model uit `scenes/models/`, of niets), de manier van bewegen en wat er aan `scripts/enemy.gd` anders is: een zombie slaat en schuifelt, de snelle zombie rent, een soldaat schiet, de dikke clown heeft een shotgun. Per personage staat er de bron, de licentie, de gemeten ooghoogte, en bij een plaatshouder waarom het er een is en wat ervoor in de plaats moet komen (`wanted`, bruikbaar als prompt).
- Van elk personage staat een contactblad in `assets/characters/sheets/<id>.jpg`: voor, opzij en achter in rusthouding, en twee houdingen die laten zien of de huid meebuigt. De houdingen worden gezet via de botnamen van het profiel, dus een blad dat klopt zegt ook dat de retarget is gelukt.

**De route**

`tools/import_character.sh <bestand> <id>` neemt een FBX, GLB, glTF, OBJ, USDZ of USD en doet in een halve minuut (een scan: een minuut):

1. **Blender, zonder venster** (`tools/characters/prepare.py`): alles weg behalve mesh en skelet, ook wat naar zijn naam een wapen is; in meters, voeten op de oorsprong, kijkend langs +Z; uitdunnen tot 20 duizend driehoeken; de texturen van alle materialen naar één set van 1K. Daarvoor worden de UV-indelingen van de materialen naast elkaar gezet, elk zo geschaald dat een centimeter huid overal evenveel texels krijgt en het hoofd 1,7 keer zoveel. De indelingen zelf blijven heel, dus de normal maps blijven geldig en er wordt niets gebakken. Een specular map wordt ruwheid.
2. **Het skelet** wordt dat van Godots `SkeletonProfileHumanoid`. De botten van het model worden herkend aan hun naam en aan waar ze in de boom hangen (3ds Max Biped, Mixamo, Unreal, Blender), hernoemd, en wat het profiel niet kent (twistbotten, gezichtsbotten) geeft zijn gewichten aan het dichtstbijzijnde bot dat blijft. Botten die het model mist komen erbij zonder huid, zodat elk personage dezelfde 56 heeft en een animatie ze allemaal gelijk beweegt.
3. **Godot importeert** de GLB met de retarget aan: het skelet wordt de unieke node `GeneralSkeleton` en zijn rusthouding de T-houding van het profiel. De voeten doen daar niet aan mee, want een voet die langs het platte voetbot van het profiel wordt gelegd staat op zijn hiel. Lightmap-UV's staan uit in het eigen `.import`-bestand.
4. **`check.gd`** houdt het resultaat tegen het contract: driehoeken, maat, voeten op de grond, kijkrichting, botnamen, de rusthouding van elk bot tegen die van het profiel, geen animaties, niets aan een bot gehangen, rond 5 MB.
5. **`sheet.gd`** maakt het contactblad en het personage krijgt zijn regel in het manifest.

Er zijn drie soorten invoer, en het commando ziet zelf welke het heeft:

- **Met skelet**: zoals hierboven.
- **Een standbeeld zonder skelet**, zoals een scan of een gegenereerd model (`tools/characters/scan.py`). Rechtop zetten in meters, de vloer eraf, losse stukjes weg. Dan wordt het lichaam op een raster van een halve centimeter dichtgemaakt: wat van buitenaf niet te bereiken is, is lichaam. Lekt de buitenkant naar binnen, door een gat in een scan of via de mouwen en broekspijpen van een gegenereerd kostuum, dan is een cel lichaam als hij aan bijna alle kanten ingesloten zit: vanuit een mouw is de enige weg naar buiten langs de mouw, vanuit de ruimte tussen arm en romp naar voren, naar achteren en alles daartussen. Een opbouw via een volume en wat gladstrijken halen de blokjes eraf. Dat wordt uitgedund en krijgt een eigen UV-indeling. Kleur en detail komen van de scan zelf: voor elke texel wordt langs de normaal naar de scan gekeken, en de normaal van de scan wordt de normal map. De gewrichten worden uit de vorm gevonden (`landmarks.py`): in horizontale plakjes zijn de benen twee eilanden die samenkomen, is elke arm een eiland naast de romp dat er bij de oksel aan vastgroeit, en is de nek waar de romp het smalst is. Daarop komt het profielskelet en Blenders automatische gewichten hangen de huid eraan. `delight.py` haalt het licht van de kamer uit de kleur: het past op de helderheid van alle texels tegelijk een licht dat langzaam met de normaal verandert, een verduistering waar het oppervlak ingesloten ligt en een eigen helderheid per soort oppervlak, zodat donker haar niet voor schaduw wordt aangezien.
- **Een figuur van losse stukken** zonder skelet (`parts.py`): hoofd, romp, armen en benen als aparte meshes, zoals de blokfiguren van Kenney. De gewrichten komen van de stukken zelf en armen en benen worden bij elleboog en knie doorgesneden, zodat ze daar buigen.

`--look=zombie` en `--look=clown` schilderen elk personage op, ook een gescande vriend (`looks.py`). De verf gaat erop in de ruimte en niet op de textuur: van elke texel is bekend waar op het lichaam hij ligt en aan welke botten hij hangt, dus "wit van haargrens tot kin" en "bloed van de mond naar beneden" kunnen zonder te weten hoe het model is uitgevouwen. `--seed` maakt van dezelfde persoon een andere zombie.

**Een vriend opnemen**

- **Houding.** Rechtop, voeten een voetlengte uit elkaar, armen 30 tot 45 graden van het lichaam, handen open met de vingers bij elkaar, recht vooruit kijken, mond dicht. Niet de armen horizontaal en niet tegen het lijf: de route vindt de armen als eilanden naast de romp. Twee à drie minuten doodstil; een punt om naar te kijken helpt. Haar vast, geen bril, geen jas die openhangt, geen rok of wijde broek waarin de benen niet los van elkaar te zien zijn. Kleren met tekening werken beter dan effen zwart, glimmend of doorzichtig.
- **Licht.** Gelijkmatig en zonder slagschaduw: buiten onder een bewolkte lucht, of binnen bij een groot raam zonder zon erin, niet onder één lamp. Het licht dat langzaam over het lichaam verloopt haalt de route eruit; de schaduw van een arm op de romp en een glimlicht niet. Een vloer met tekening, geen spiegelende.
- **App.** De lidar van een iPhone is te grof; neem een app die met foto's rekent, op het toestel zelf. Scaniverse (gratis, rekent op de telefoon, niets gaat naar een server) in de stand Mesh met de verwerking op Detail. Of maak zelf 80 tot 150 foto's met de gewone camera, in drie rondes om de persoon op knie-, borst- en hoofdhoogte met ruime overlap, plus een paar van boven op het hoofd, en laat Apple's Object Capture ze op de Mac tot een model rekenen. Polycam en RealityScan rekenen in de cloud: alleen als de vriend daar ja op zegt. Dit komt uit de beschrijvingen van de apps; geen ervan is hier geprobeerd.
- **Export.** USDZ, GLB of OBJ met textuur, op de hoogste kwaliteit; een paar honderdduizend driehoeken en een textuur van 4K zijn goed. Zet het bestand in `assets/characters/.source/` (dat staat niet in git) en draai `tools/import_character.sh assets/characters/.source/jan.usdz jan --source="scan van Jan" --license="eigen opname, met toestemming"`, met `--look=zombie` erbij voor een zombie. Bekijk het contactblad, en zet `jan` in het manifest bij een rol.
- **Als het misgaat.** Het commando zegt wat het niet vond ("de benen staan niet uit elkaar", "de linkerarm staat niet vrij van het lichaam"). Kijkt het personage de verkeerde kant op, geef dan `--yaw=180`; is de maat vreemd, `--height=1.82`.

**De proefscan**

Er is geen echte scan gemaakt. `tools/characters/test_scan.sh` maakt er een na van een Rocketbox-burger (`mock_scan.py`): het skelet weg, het licht van een kamer in de textuur gebakken, 593 duizend bobbelige driehoeken onder een UV-indeling van snippers, gaten waar een camera niet komt (zolen, kin, oksels, kruis), een vloer en losse stukjes erbij, 137 graden gedraaid en verschoven. Die gaat door de scanroute en het origineel door de gewone, en het script legt ze naast elkaar. Gemeten op 10 oktober 2026:

| | Origineel | Via de scanroute |
|---|---|---|
| Driehoeken | 8,1 duizend | 19,7 duizend (van 593 duizend) |
| Gewrichten | het skelet van de maker | gemiddeld 1,4 cm ernaast, het slechtste (hoofd) 2,6 cm |
| Teruggedraaid | | 135,2 van de 137 graden |
| Kleur binnen 15% van de echte helderheid | | 65% van het oppervlak, tegen 40% zoals gescand; donkerder dan 70%: 5% tegen 16% |
| USDZ, OBJ en GLB | | geven hetzelfde personage, op 3 mm in de lengte na |

De contactbladen staan naast elkaar in `assets/characters/sheets/scan_test_original.jpg` en `scan_test.jpg`: de knie buigt, de arm komt naar voren en de schouder zakt zonder dat de huid scheurt. Wat verschilt: de vingers zijn één want, het haar is een kap in plaats van lokken, en het hemd trekt bij de gebogen knie iets mee. De verhoudingen waarmee de gewrichten worden geplaatst zijn geijkt op vijftien Rocketbox-mensen (`calibrate.py`: gemiddeld 1,9 cm, slechtste 6,8 cm), en die delen één bouw; een echt mens zal er verder naast zitten.

**Werkwijze**

| Stap | Commando |
|---|---|
| Een model of een scan tot personage maken | `tools/import_character.sh <bestand> <id> --source=... --license=...` (zonder argumenten: alle opties) |
| Alle personages opnieuw bouwen uit hun bron, of één | `tools/characters/build_cast.sh [id]` |
| Een personage laten maken uit een beschrijving (plaatje door FLUX.1-schnell, model door TRELLIS.2, beide gratis op Hugging Face) | `tools/characters/generate.py <id> "<prompt>"`, dan `tools/import_character.sh <glb> <id> --height=1.8 --prompt=... --model=...` |
| De scanroute testen op de proefscan | `tools/characters/test_scan.sh` |
| De gewrichtsvinder ijken op modellen waarvan het skelet bekend is | `blender -b --python tools/characters/calibrate.py -- <modellen>` |
| Nagaan of de botnamen van andere skeletten worden herkend (Mixamo, Unreal, Rigify, Quaternius) | `blender -b --python tools/characters/test_names.py` |
| Een personage in het level bekijken | `tools/benchmark.sh --quick --spawn="res://assets/characters/<id>/<id>.glb@0,0,1.5,80,1" --at="4,1.7,2.5,80,-10"` |
| Contactbladen opnieuw maken | `tools/godot.sh --script res://tools/characters/sheet.gd -- <id> [id ...]` |
| Na een nieuwe Godot-versie het profiel opnieuw uitlezen | `godot --headless --path . --script tools/characters/dump_profile.gd` |

Blender (5.2, via `brew install --cask blender`) draait alleen zonder venster. De bronbestanden, 1,4 GB aan Rocketbox-avatars en de proefscans, staan in `assets/characters/.source/` en niet in git; `build_cast.sh` haalt ze opnieuw op.

**Wat het kost** is niet betrouwbaar gemeten: tijdens het bouwen deelden drie sessies de GPU en gaf hetzelfde standpunt zonder personages 36 en 47 fps. Wat vaststaat: een personage is één of twee tekenopdrachten (een robot zestien), 7 tot 15 duizend driehoeken met 56 botten, en drie texturen van 1K. Dat moet nog eens op een rustige machine naast een wave robots worden gelegd.

**Nog open**

- Zombies en clowns zijn plaatshouders. Een realistisch model van een van beide is nergens te krijgen onder een licentie die gebruik in een eigen spel toestaat zonder account; er is een generatiedienst voor nodig. Het manifest heeft per plaatshouder de prompt klaarstaan.
- Eén personage is gegenereerd (`generate.py`, 10 oktober 2026): FLUX.1-schnell (Apache-2.0) schilderde de clown uit de prompt, `cutout.py` maakte hem hier vrijstaand, TRELLIS.2 (MIT) maakte er in een minuut een model van 298 duizend driehoeken van, en de scanroute gaf dat een skelet. Beide draaien als gratis demo op Hugging Face en vragen een (gratis) account: zonder krijg je twee minuten GPU-tijd en drie beurten per dag, en TRELLIS.2 vraagt twee beurten van twee minuten. Het token staat in `~/.cache/huggingface/token`. Reken op ongeveer één model per dag. Wat ervan te leren viel: een gegenereerd model is een holle huls die openstaat bij mouwen en broekspijpen, en de mouwen waren aan de romp vastgegroeid. Het eerste kan de route nu aan. Het tweede niet: wie de armen zijwaarts heft, trekt een vlies mee, zoals op het contactblad in rusthouding te zien is; met de armen omlaag of naar voren valt het weg. Vraag in de prompt dus om armen die 30 tot 45 graden van het lijf staan, en kijk of het plaatje dat ook doet: van drie voldeed er één. Bij de tweede clown (`clown_06`) stond dat in de prompt en zijn de armen vrij: zijn rusthouding heeft geen vlies. Wel hield hij op het plaatje de ellebogen gebogen, en omdat de route een arm als rechte lijn neemt, zit zijn elleboog niet waar de arm knikt en staan de onderarmen krom. Vraag dus ook om gestrekte armen. Een derde model op dezelfde dag lukte niet meer: het gratis rantsoen was na twee modellen en vijf plaatjes op. De kleuren zijn donkerder en blauwer dan op het plaatje, en onder een hak zit een scherfje vloer.
- Alleen skeletten met de botnamen van 3ds Max zijn echt door de route gegaan, want daar komt de hele bezetting vandaan. De namen van Mixamo, Unreal, Rigify en Quaternius worden herkend op een kaal skelet (`test_names.py`); een model ermee is nog niet geïmporteerd.
- De scanroute is op nagemaakte scans en op één gegenereerd model geprobeerd, niet op een echte scan. Een echte scan heeft bewegingsonscherpte, haar als klomp en kleren die tegen elkaar aan liggen; wat daarvan misgaat blijkt pas bij de eerste vriend.
- Een scan krijgt één ruwheid voor het hele lichaam en vingers zonder botten: de hand is één stuk. Ogen kijken niet en een mond gaat niet open, bij geen enkel personage.
- Het ontlichten haalt geen slagschaduwen en geen glimlichten weg.
- De soldaten dragen het digitale camouflagepatroon van het Amerikaanse leger en een vlag op de mouw.
- De blokfiguren hebben geen voeten of handen die bewegen: een arm is een doos met één knik.

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
- Een natte-vloer-shader met plassen met een grillige rand en een lenspass met vignette en filmkorrel. De lichte chromatische aberratie zit alleen nog in Ultra: daarvoor moet het beeld worden teruggelezen, en dat kostte op 1440p circa 2 fps voor iets wat je nauwelijks ziet.
- Vuil glas in alle ramen en dakramen, met hier en daar een ontbrekende ruit.
- Decals: lekstrepen onder de ramen, vuil langs de plinten en olievlekken op de vloer.
- Gescande CC0-modellen van Poly Haven (1K), 45 in totaal: vaten, houten kisten, betonnen wegbarrières, stellingen, hallampen, schakelkasten, een bureau, banden, gasflessen, cementzakken op pallets, een compressor, een lasset, gereedschapswagens, een ladder, een steekwagen, werkbanken met twee kolomboren, een bankschroef en een gereedschapskist, een kruk en groepenkasten. Daarbij het kleine spul dat een ruimte bewoond maakt: brandblussers en brandmelders bij de deuren, jerrycans en olieblikken bij de machines, gereedschap op de werkbank, een voorhamer en een koevoet tegen de muur, bezems, vuilniszakken, kartonnen dozen, plastic stoelen, putdeksels in de vloer en een waarschuwingsbord bij de plas in de gang. Ze staan in het manifest, krijgen bij import lightmap-UV's (importstandaard in `project.godot`) en worden door de levelbouwer geplaatst, die er zelf een eenvoudige botsvorm bij zet; los gereedschap (`drop`) krijgt geen botsvorm en geen lightmap.
- Een excenterpers en een draaibank van zes meter, in code opgebouwd (`_press` en `_lathe` in `tools/levels/factory.gd`), omdat er van grote machines geen gescande modellen zijn. De levelbouwer heeft daarvoor afgeronde blokken, omwentelingslichamen en slangen gekregen (`rounded_box`, `revolve`, `hose`). Samen zijn ze circa 26 duizend driehoeken; ze horen bij de gewone levelgeometrie en krijgen dus een lightmap. Blank staal, donker staal, rubber, messing en rode lak zijn materialen zonder eigen kleurtextuur. De werklamp van de draaibank brandt en boven de werkbank hangt een tl-buis, anders stond die hoek in het donker.
- Ook in code opgebouwd, omdat Poly Haven er geen modellen van heeft: zeecontainers van geperste panelen met deuren en sluitstangen (`container`, met `corrugated` voor het geperste staal), twee opslagtanks met mangat, peilglas, afsluiters, kooiladder en leidingwerk naar de wand (`_tank`), een bovenloopkraan met loopkat, haakblok, kabelslingers en hangende bediening (`_crane`), roldeuren van lamellen (`roller_door`), pallets van losse planken, ronde buisleuningen met schopplaat, werkplaatskasten en een rij kluisjes waarvan er twee openstaan (`cupboard`, `lockers`). De gedeelde bouwstenen staan in `tools/level_builder.gd` en gelden dus ook voor het depot.
- Al het gelakte staal (machines, containers, tanks, kraan, leuningen, leidingen) gebruikt één shader, `shaders/worn_paint.gdshader`: een laklaag in een kleur naar keuze over een gescande laktextuur, met roestplekken die strepen naar beneden trekken, afgebladderde randen die op de rand zelf blank zijn gesleten, en stof op wat naar boven wijst. De levelbouwer geeft daarvoor elk vlak mee hoe ver een punt van de rand ligt, verpakt in de vertexkleur (`_edge`). De ruis komt uit een procedureel masker in het manifest (`wear`), de roest uit een scan van Poly Haven.
- Vloerbelijning in de hal: een rijpad van de laaddeur naar de aanbouw met een aftakking naar de trap, zwart-gele randen om de pers en de draaibank, arcering voor de laaddeur en de schakelkasten, en opslagvakken langs de zuidwand. Een level beschrijft de belijning met `floor_line`, `floor_frame` en `floor_hatch`; de levelbouwer tekent daar één textuur van en de vloershader legt die over het beton en laat de verf slijten.
- Opschriften, gesjabloneerd met de bruggetjes die een sjabloon nodig heeft: nummers op de containers, de hijslast op de kraan, tanknummers, deurnummers op het perron van het depot en vaknummers op de vloer. De pers en de draaibank hebben een machinenummer, tekst op hun typeplaatje, de perskracht op de kop en waarschuwingsdriehoeken waar iets beweegt (soort `warning` in het manifest). Elk opschrift staat als decal in het manifest (soort `text`) en wordt gezet in het ingebouwde lettertype van de engine, dus zonder extra bestand; `label` plaatst het en `floor_text` schildert het mee in de vloerverf. Ze kosten geen meetbare rekentijd.
- De aanbouw is ingericht als het kantoor- en magazijngedeelte van een fabriek. De muren hebben een lambrisering: glansverf tot heuphoogte met een bies erboven en een donkere plint, afgebladderd waar karren en schoenen ertegen stoten en vuil vanaf de vloer (`shaders/dado_wall.gdshader`, materiaal `plaster_dado`; het kost geen geometrie). Beide kamers hebben een stalen kozijn met dubbele deuren die openstaan, met een ruitje, een schopplaat, klinken en scharnieren (`_door` en `_leaf` in `tools/levels/factory.gd`), en een nummerplaatje ernaast. Onder het plafond van de gang lopen een luchtkanaal van verzinkt plaatstaal met roosters en een kabelladder met kabels; vanaf de ladder komt een buis naar een schakelaar bij elke deur. Op de gangmuur hangt een prikbord. De scharnieren zitten aan de buitenkant van het kozijn, zodat een open deur de doorgang niet smaller maakt: die is precies zo breed als de robots nodig hebben.
- Stof in de lucht van de hal: 4000 deeltjes die alleen oplichten waar licht op valt, dus in de zonnebundels en onder de lampen (`shaders/dust.gdshader`). Kost 0,1 tot 0,2 ms.
- Massieve props krijgen een eigen stukje lightmap. Props van dunne staven (stellingen, lampen, ladder, steekwagen) lost een lightmap niet op; die krijgen hun licht van de lightmap-probes. Het probe-raster staat daarvoor op de fijnste stand: met het grove standaardraster lichtten zulke props in een donkere hoek spookachtig op.
- Wat de levelbouwer zelf zonder lightmap bouwt (spanten, kraan, leuningen, raamroeden) is in blokken van 14 × 6 × 12 m geknipt. Een mesh zonder lightmap leest de probes op één punt uit, zijn midden; als één mesh lag dat punt voor de hele hal boven het dak, zodat de kraan en de spanten door de buitenlucht werden verlicht en feller geel waren dan hun omgeving. Nu krijgen ze het licht van de plek waar ze hangen: donkerder en warmer, zoals de rest van de hal.

**Wapens en vijanden**

- De vijf wapens zijn onderdeel voor onderdeel in code opgebouwd (`tools/models/weapons.gd`), omdat er geen gescande of gegenereerde modellen voor zijn: een karabijn met een open richtkijker en een lamp, een dienstpistool, een pompgeweer met reservepatronen op de kast, een pistoolmitrailleur met draadkolf en een scherpschuttersgeweer met kijker en tweepoot. Elk is 11 tot 17 duizend driehoeken, inclusief de handschoenen en mouwen van de schutter.
- Een modelbouwer (`tools/model_builder.gd`) gebruikt daarvoor dezelfde bouwstenen als de levelbouwer en verdeelt de driehoeken over onderdelen met een eigen draaipunt, zodat een slede, een grendel, een pomp of een magazijn kan bewegen. Een model wordt één bestand in `scenes/models/`. De levelbouwer heeft er `slab` bij gekregen: een plaat die naar een omtrek is gesneden, met afgeronde randen. Daar zijn de kasten, kolven, grepen en magazijnen van gemaakt.
- Wapens en robots gebruiken één shader, `shaders/finish.gdshader`: een deklaag (bruinering, anodiseerlaag, lak of het kunststof zelf) die langs de randen tot op het metaal is weggesleten, met krassen en schuurplekken op de vlakken en vet waar het wordt vastgepakt. De randen komen uit dezelfde vertexkleur als bij de lakshader. Handschoenen en mouwen hebben een stofshader met een weefsel (`shaders/cloth.gdshader`). Vier naadloze normal maps voor wat je van een handbreedte afstand ziet (weefsel, korrel van kunststof, gestraald metaal, ruitjes van een greep) worden uit het manifest gegenereerd (soort `grain`).
- De rode stip van de richtkijker is niet op het glas geschilderd: de shader tekent hem waar de kijklijn door het glas evenwijdig aan de loop loopt, zoals een echte gecollimeerde stip. Hij blijft dus op het doel als het wapen beweegt.
- Het wapen in beeld wordt met een eigen kijkhoek van 58 graden getekend, hoe de kijkhoek van de wereld ook staat ingesteld of ingezoomd: het wordt daarvoor voor de camera zijwaarts en omhoog uitgerekt, wat op hetzelfde neerkomt als een smallere lens. Een zwak invullicht over de linkerschouder, dat alleen het wapen raakt, houdt de vorm zichtbaar waar het level het in het donker laat. Vlak voor een muur wordt het wapen teruggetrokken met de loop omhoog, in plaats van erdoorheen te steken.
- De vijanden zijn drie bewakingsrobots op één skelet (`tools/models/enemies.gd`), 6 tot 9 duizend driehoeken in 16 onderdelen: de grunt met een geweer als onderarm en een schild aan de andere arm, de rusher klein en voorovergebogen met een lemmet aan elke arm, de heavy breed met een draaiend meerloopskanon en de munitie op zijn rug. `scripts/enemy_rig.gd` laat zien wat `scripts/enemy.gd` beslist: de benen stappen in de maat van de snelheid en de richting waarin het lijf beweegt, de wapenarm komt omhoog tot op de speler en slaat terug bij elk schot, alles wat gloeit licht op vóór een aanval, een treffer laat de romp terugdeinzen en oplichten, en een robot die kapot gaat valt in losse stukken uiteen die met physics neerkomen en een paar seconden blijven liggen.

**Wat je ziet als er geschoten wordt**

- **Mondingsvlam.** Een vlam die de shader bij elk schot opnieuw tekent uit een eigen willekeurig getal, zodat geen twee gelijk zijn (`shaders/muzzle_flash.gdshader`): een hete kern met tongen van ongelijke lengte en dunne strepen brandend kruit, van opzij een vlam in de lengte. Elk wapen heeft zijn eigen maat en vorm (`flash_size` en `flash_prongs` in de wapengegevens): vier tongen uit de vlamdemper van de karabijn, een bol uit het pompgeweer, twee stralen opzij uit de mondingsrem van het scherpschuttersgeweer. De vlam licht de omgeving een ogenblik aan en is over het vizier kleiner, zodat hij het doel niet bedekt. Als het schieten stopt, kringelt er rook uit de loop, meer naarmate er langer is gevuurd.
- **Tracers.** Een korte gloeiende streep die met 260 m/s van de loop naar het doel reist, in plaats van een balk die er in één keer staat. De robots schieten rood.
- **Inslagen per ondergrond.** De levelbouwer merkt elke botsvorm met waar hij van gemaakt is (`_surface` in `tools/level_builder.gd`; een model noemt het in het manifest als het geen staal is), en een schot leest dat af van wat het raakt. Beton en baksteen geven een stofwolk, wegspattende scherven en af en toe een vonk; staal een waaier vonken die de kant op gaat waarheen het schot afketst, op de vloer stuitert en van wit naar dofrood afkoelt; hout splinters en fijn stof; zakken, banden en karton alleen een pluimpje.
- **Kogelgaten** zijn echte decals met een eigen normal map, zodat het licht in de krater valt: een uitgebroken krater in beton (rood getint in baksteen), een gat met een rand van blank staal en roet eromheen in staal, dat een kleine seconde nagloeit, en een langs de nerf opengescheurd gat in hout. Ze komen uit het manifest (soort `hole`) en de laatste 80 blijven staan.
- **Een robot die kapot gaat** geeft een lichtflits, een vuurbal, een regen van vonken, rook die een paar seconden blijft hangen en roet op de vloer eronder (soort `scorch`). Een treffer op een robot geeft vonken en een lichtje.
- **Hoe het werkt.** Vonken, scherven en rook komen in salvo's: één mesh van losse vierkantjes waarvan de shader voor elk deeltje uitrekent waar het is uit de tijd sinds het salvo begon, inclusief de stuit op de vloer (`shaders/fx_common.gdshaderinc`). Er wordt dus niets per frame gesimuleerd en een salvo kost het script niets terwijl het speelt. Stof en rook worden belicht zoals de rest van het level: donker in een donkere hoek, oplichtend in een zonnebundel. Alles loopt op één eigen klok (`Fx.time`), die stilstaat als het spel pauzeert en die voor een screenshot op een exact moment kan worden stilgezet.

**Wat er ontploft**

- **Brandstofvaten, gasflessen en jerrycans** zijn geen decor meer. Het rode vat met de explosiesticker (een van de drie vatmodellen), de gasfles en de jerrycan gaan de lucht in als erop geschoten wordt. Een gat erin steekt ze eerst aan: langs een vat of een jerrycan likt een vlam omhoog, uit een gasfles komt een steekvlam. Na één tot twee seconden ontploffen ze. Dat is lang genoeg om weg te komen, of om een robot erlangs te zien lopen. Meer schade, of een ontploffing ernaast, laat ze meteen afgaan, dus wat bij elkaar staat gaat achter elkaar de lucht in. Een verdwaald schot van een robot steekt ze net zo goed aan. De blauwe en grijze vaten doen niets.
- **De klap** doet schade die afneemt met de afstand (150 in het hart van een vat, niets meer op 6,5 m), gooit robots, de speler en losse stukken weg en schudt het beeld. Wie achter een muur, een container of een betonblok staat, krijgt niets: de klap kijkt op drie hoogtes of hij je kan zien, dus half achter dekking is de helft van de schade. De speler krijgt de helft van wat een robot krijgt, zodat een vergissing te overleven is. Een robot die door een klap kapot gaat, valt in stukken uiteen die van de klap weg vliegen.
- **Wat er overblijft.** Het vat zelf vliegt zwartgeblakerd en gedeukt de lucht in en blijft liggen waar het neerkomt. De brandstof brandt nog zeven seconden na op de vloer en doet schade aan wie erin staat, robot of speler. Op de vloer blijft een roetvlek achter.
- **Handgranaten.** Drie per wave, met G of Y op de controller. De linkerhand laat het wapen los, wat een herlaadbeurt afbreekt; de granaat stuitert, rolt en gaat na 2,2 seconden af met dezelfde klap als een vat. Het model is in code gebouwd (`tools/models/props.gd`) en de HUD toont hoeveel er nog zijn.
- **Waar ze staan.** `fuel` in de levelbouwer zet een rood vat neer. In de fabriek staan er negen: langs het rijpad waar de robots overheen komen, aan de kop van de containers, in een laadvak en één op de tussenvloer. In het depot acht, waar de gangpaden tussen de containers kruisen en op het perron. Daarnaast de gasflessen en jerrycans die er al stonden.
- **Hoe het eruitziet.** Een explosie is een lichtflits, een drukgolf die een derde seconde lang het beeld erachter vervormt (`shaders/shockwave.gdshader`), een vuurbal die van witgeel via oranje tot roet uitbrandt, een ring van stof die over de vloer wegschiet, vonken en brokstukken. Vuurbal en rook zijn dezelfde zachte bollen als het stof van een inslag, maar ze branden: het heetst waar ze het dikst zijn, en de dunne randen gaan het eerst uit, zodat het vuur opbreekt in de rook die het achterlaat. Vuur dat blijft branden is een eigen shader (`shaders/flames.gdshader`): bollen vlam die van de grond opstijgen, onderweg tot een punt worden uitgerekt en uitbranden, en onderaan opnieuw beginnen, elk in zijn eigen ritme. Met een lange reikwijdte en een hoog tempo is dezelfde shader de steekvlam van een gasfles. Het licht van een vuur flakkert en neemt af zoals dat van een echte vlam, zodat het bij het vuur blijft.
- **Hoe het werkt.** De levelbouwer geeft elk model dat kan ontploffen een eigen botsvorm met `scripts/explosive.gd` erop, in plaats van een vorm in het ene grote lichaam van het level; alleen zo kan het uit het level verdwijnen. Het model houdt zijn stukje lightmap, het wrak is een kopie die door de probes wordt belicht waar het ook terechtkomt. `scripts/blast.gd` doet de schade, het wegslingeren en de kettingreactie; wat er te zien is, is van `Fx.explosion` en `Fx.fire`. Een blast zoekt alleen op de lagen van speler, robots, losse stukken en explosieven, want het level zelf is één lichaam met duizenden vormen.
- **De rook van een explosie wordt niet per pixel belicht.** Dat was de eerste opzet, zoals bij het stof van een inslag, en het kostte een derde van de framerate: een wolk die een kwart van het beeld vult, moet dan voor elke pixel van elke bol de lampen en schaduwen opzoeken. Met één explosie per seconde vol in beeld zakte het van 74 naar 48 fps. Schaduwen weglaten gaf 53 fps, belichten per hoekpunt 57, niet belichten 67. De rook van explosies en vuur gebruikt daarom `shaders/smoke.gdshader`, dezelfde bollen zonder belichting (beide shaders delen `shaders/puff.gdshaderinc`). In plaats daarvan krijgt een wolk één helderheid mee: één straal naar de zon zegt of hij in de schaduw hangt of in het licht. Roet is zo donker dat het verschil met echte belichting niet te zien is.

- **Wat het kost.** Zolang er niets ontploft: niets. Gemeten op 9 oktober 2026 in de fabriek op 1440p met FSR 2 op 67%, met de karabijn in beeld en elke seconde een explosie met nabrandend vuur, negen meter voor elk standpunt:

| | Gemiddeld (laagste en hoogste standpunt) | 1% low | Traagste frame |
|---|---|---|---|
| Wapen in beeld, er ontploft niets | 65–74 fps | (laptop in gebruik, zie hieronder) | |
| Elke seconde een explosie | 64–66 fps | 60–61 fps | 17–20 ms |

  Dat is 1 tot 8 fps, voor iets wat in het spel een paar keer per wave gebeurt en niet elke seconde. De traagste frame van zo'n run duurde 20 ms tegen 14 tot 16 normaal: de eerste explosie hapert niet. De benchmark drukt die traagste frame nu bij elke meting af.

**Afwijking van het plan: SDFGI staat uit.** Naast de lightmaps gaf SDFGI geen zichtbaar verschil, maar het kostte circa 25 fps. Dynamische objecten krijgen hun indirecte licht van de lightmap-probes.

**SSIL staat alleen nog op Ultra aan.** Het kostte 1,25 ms van een frame van 14 ms (op 1440p met FSR 2), terwijl het naast de lightmaps alleen zonbeschenen objecten een fractie lichter maakt; in een vergelijking naast elkaar is het verschil niet te zien. Op High levert het weglaten 7 fps op.

**Werkwijze**

| Stap | Commando |
|---|---|
| Assets ophalen volgens het manifest (texturen, HDRI's en modellen) | `tools/fetch_assets.py` |
| Nieuw opgehaalde bestanden importeren | `godot --headless --path . --import` |
| Procedurele decals en maskers opnieuw genereren volgens het manifest | `tools/gen_decals.sh` |
| Levelgeometrie opnieuw genereren uit `tools/levels/<naam>.gd` | `tools/build_level.sh factory` of `depot` |
| Een bouwsteen van dichtbij bekijken zonder een level te bakken: alles wat in code is opgebouwd staat naast elkaar in de showroom (`tools/levels/showroom.gd`) | `tools/build_level.sh showroom`, dan `tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="-23,2.2,9,0,-5"` |
| Lightmaps bakken (nodig na elke geometrie- of lichtwijziging, 2 minuten). De bake drukt op de knop van de editor zelf en zet daarvoor eerst de 3D-weergave voor | `tools/bake_lightmaps.sh [res://scenes/depot.tscn]` |
| Wapens, vijanden of de granaat opnieuw genereren uit `tools/models/<naam>.gd` | `tools/build_model.sh weapons`, `enemies` of `props` |
| Een wapen bekijken zoals de speler het vasthoudt (nummer in de loadout vanaf 0; `,1` erachter is gericht, `,0,0.4` is 40% van het herladen) | `tools/benchmark.sh --quick --weapon=2 --at="2,1.7,3,-120,0"` |
| Een model of een vijand in een level neerzetten om te bekijken (x,y,z,draaiing,schaal,houding: 1 richt, 2 loopt, 3 ligt in stukken, 4 vuurt) | `tools/benchmark.sh --quick --spawn="res://scenes/enemy_heavy.tscn@-2,0,-1,-100,1,1" --at="2.5,1.7,3,90,-4"` |
| Een schot bekijken op een exact moment erna (seconden, aantal schoten, spreiding in graden): vlam, tracer en inslag | `tools/benchmark.sh --quick --weapon=0 --shoot=0.01 --at="6.3,1.5,-2.5,-90,-3"` of `--shoot=0.2,4,5` |
| Een ontploffende robot bekijken op een exact moment erna | `tools/benchmark.sh --quick --hold=0.4 --spawn="res://scenes/enemy.tscn@0,0,1.5,-100,1,3" --at="4,1.7,2.5,80,-18"` |
| Een explosie bekijken op een exact moment erna (x,y,z, dan de grootte en de breedte van het vuur dat blijft branden) | `tools/benchmark.sh --quick --blast="8,0.45,2,1,1.2" --hold=0.3 --at="14,1.7,6,56,-8"` |
| Een vat, gasfles of jerrycan in het level laten branden of laten ontploffen (het dichtstbijzijnde bij dat punt) | `tools/benchmark.sh --quick --ignite="17.62,0.6,-5.75" --hold=0.8 --at="16.4,1,-4.9,-53,-10"` of `--detonate="17.9,0,-5.9" --hold=3` |
| Meten wat de effecten kosten tijdens een aanhoudend vuurgevecht (schoten per seconde, in elk standpunt) | `tools/benchmark.sh --weapon=0 --firefight=12` |
| Meten wat explosies kosten (explosies met nabrandend vuur per seconde, negen meter voor elk standpunt) | `tools/benchmark.sh --weapon=0 --barrage=1` |
| Snel screenshots van de benchmarkstandpunten | `tools/shots.sh` |
| Meten wat elk effect per standpunt kost (schaduwen, SSAO, SSIL, SSR, mist, glow, props, decals, glas, stof, lenspass) | `tools/benchmark.sh --profile` |
| Een run zonder bepaalde effecten, om screenshots te vergelijken | `tools/benchmark.sh --off=ssil,glow` |
| Screenshots vanaf een eigen standpunt (x,y,z,draaiing,helling; meerdere gescheiden door `;`) | `tools/benchmark.sh --quick --at="-11,1.7,-6,20,-5"` |
| Gameplay en beide levels testen (headless) | `tools/selftest.sh` |
| Een benchmark of bake in een gewoon venster volgen | `GODOT_WINDOW=1 tools/benchmark.sh` |

**Alles draait zonder venster.** De benchmark en de bake starten Godot via `tools/godot.sh` in de modus waarmee de editor een draaiend spel inbedt (`--embedded`). Die rendert gewoon op de GPU, maar opent geen venster, toont geen Dock-icoon en maakt geen geluid, zodat een run nooit de focus afpakt van waar je mee bezig bent. Een gewoon venster doet dat altijd: Godot activeert zichzelf zodra het hoofdvenster verschijnt, en daar is geen schakelaar voor. Zonder venster zijn de screenshots gelijk, is een bake byte voor byte gelijk en komen de gemiddelden overeen met die in een venster (1080p: 90–104 tegen 91–101 fps, 1440p met FSR 2: 75–79 tegen 75–79 fps). De 1% low is alleen vergeleken terwijl de laptop in gebruik was (62–95 fps over twee runs, tegen 80–90 in een venster op een rustige machine); die vergelijking moet nog een keer op een rustige machine. In `results.json` staat bij zo'n run `"display": "embedded"`.

**Meting** op 8 oktober 2026, M1 Pro, 1920×1080, kwaliteit High (zonder SSIL), met alles wat hierboven staat, zonder venster gemeten terwijl de laptop in gebruik was:

| Camerastandpunt | Gemiddeld | 1% low |
|---|---|---|
| Overview | 88 fps | 85 fps |
| Corridor | 96 fps | 93 fps |
| Platform | 82 fps | 79 fps |
| Hall | 94 fps | 91 fps |

Na de inrichting van de aanbouw (9 oktober 2026) haalt het standpunt Corridor nog 86 tot 89 fps; de andere drie zijn gelijk gebleven. Los gemeten, direct na elkaar: de muurshader kost daar circa 2 fps, het luchtkanaal 1, de kabelladder met kabels 2 en de deuren 1. Die metingen zijn gedaan terwijl de laptop zwaar in gebruik was; de gemiddelden waren stabiel, de 1% low niet (65 tot 85 fps), dus die staat hier niet bij.

Op 9 oktober 2026, na de vaten en de nieuwe bake, haalde de fabriek op 1440p met FSR 2 op 67% 67 tot 72 fps in de vaste standpunten, tegen de 71 tot 76 in de tabel verderop. Dat ligt aan de laptop en niet aan het level: de vorige commit, er in een worktree naast gezet en om en om gemeten, haalde op dat moment dezelfde 67 tot 72 fps (per standpunt hooguit 0,2 fps verschil). De lightmap van de fabriek is met de zeven vaten erbij 53,2 MB.

Dit is gemeten nadat de hallampen omhoog zijn gegaan: ze hangen nu op 8,3 m tussen de spanten, zodat de kraan eronderdoor kan rijden. Ze schijnen daarvoor harder door een smallere kegel, zodat de lichtvlek op de vloer gelijk blijft; in de standpunten scheelt dat 2 tot 4 fps in het voordeel. Het wapen en de vijanden staan niet in de vaste standpunten. Los gemeten op 1440p met FSR 2, midden in de hal: het wapen in beeld kost circa 0,4 ms (inclusief de bredere kijkhoek van de speler) en een volle wave van acht robots in beeld nog eens 0,2 ms, samen ongeveer 3 fps.

Vóór de lampen omhoog gingen was dit gemiddeld 84, 92, 80 en 90 fps. Vóór de machines was dit gemiddeld 95, 98, 91 en 101 fps. In het standpunt Hall kostten de twee nieuwe lampen samen 4 fps; met een korter bereik is dat 2 fps. De werkbank met zijn modellen kost circa 2 fps en de twee machines samen 1 à 2. Vóór de containers, tanks en kraan was het 90, 96, 86 en 94 fps. Die kostten samen met de lakshader, de belijning en het stof 0,45 tot 1,1 ms per frame; de lakshader is daarvan 0,2 tot 0,4 ms en het stof 0,1 tot 0,2 ms. De lichtere lenspass verdiende daarvan 0,2 ms terug. De zeventien kleine modellen en de blokken kostten samen circa 1 fps.

De modellen brengen het aantal driehoeken per frame van circa 80 duizend naar 1,4 tot 2,5 miljoen, in 600 tot 950 tekenopdrachten. Dat is goedkoop: de eerste zes modellen kostten op 1440p met FSR 2 hooguit 0,4 ms per frame, de vijftien daarna samen ongeveer 1 fps. De levelgeometrie zelf is 84 duizend driehoeken. De lightmap van de fabriek groeide van 25 naar 52,5 MB, omdat elke massieve prop een eigen stukje lightmap krijgt. Boven 50 MB waarschuwt GitHub over de bestandsgrootte (bij 100 MB weigert het).

**Nog open in deze fase**

- De wapens, de handen en de vijanden zijn gebouwd en niet gescand of gegenereerd. De handen zijn handschoenen van buizen en afgeronde blokken, zonder skelet: bij het herladen beweegt de hele arm mee, de vingers niet. De robots lopen procedureel en hebben geen ingestudeerde animaties. Zodra er een generatiedienst is die bruikbare topologie en rigs levert, zijn dit de eerste om te vervangen; de gameplay hoeft daarvoor niet te veranderen, want die kent een wapen en een vijand alleen als een scène met een paar benoemde onderdelen.
- Poly Haven heeft geen kubusvormige krat; de kratstapels bestaan daarom uit langwerpige kisten.
- De machines, containers, tanks en kraan zijn gebouwd en niet gescand. Zodra er een generatiedienst is, zijn na de wapens en de vijanden de machines aan de beurt.
- Poly Haven heeft sinds juli 2026 een bovenloopkraan met een overspanning van 12,5 m. De kraan in de hal overspant 23 m en is daarom in code gebouwd.
- De schakelkasten zijn straatkasten die 1,45 keer vergroot zijn; van dichtbij zijn de waarschuwingsstickers daardoor te groot.

## Vijanden die mensen kunnen zijn

De vijanden kunnen in plaats van robots ook personages zijn: één huid op een skelet, aangestuurd door hetzelfde `scripts/enemy.gd`. Wie het zijn is een thema. De standaard is `robots`, en die lopen door dezelfde code als voorheen.

**Wat er staat**

- **Thema's.** Een thema geeft voor elk van de drie rollen (grunt, rusher, heavy) de personages waaruit per vijand willekeurig gekozen wordt, het wapen dat hij draagt, zijn manier van bewegen en wat er aan zijn afstelling anders is. `scripts/enemy_themes.gd` leest ze uit twee tabellen van dezelfde vorm: `assets/characters/manifest.json`, waar de personages komen die voor het spel gemaakt worden, en `assets/animations/themes.json` met wat er altijd is: `mannequin` (de twee poppen van de animatieset, met karabijn, vuisten en pistoolmitrailleur) en `mannequin_zombie` (dezelfde poppen, schuifelend en slaand). Ontbreekt het bestand, het thema, de rol of het personage, dan is die vijand een robot; een thema mag dus ook maar één rol invullen. Kiezen doe je in het instellingenscherm of met `--enemies=<thema>`; het geldt voor wie daarna spawnt.
- **Wat een personage moet zijn.** `assets/characters/<id>/<id>.glb`, in meters, voeten op de oorsprong, kijkend langs +Z, geïmporteerd met Godots retarget naar het humanoid-profiel (skelet `GeneralSkeleton`, botten `Hips`, `Spine`, `LeftUpperArm` enzovoort, in de rusthouding van dat profiel), zonder animaties en zonder wapen. Nodig zijn heupen, minstens één rugbot, hoofd, en per kant boven- en onderarm, hand, boven- en onderbeen en voet; vingers, tenen, schouders en nek worden gebruikt als ze er zijn. De botkaarten in `assets/animations/` laten zien hoe zo'n import eruitziet.
- **Afstelling per rol.** `tuning` in een thema zet geëxporteerde variabelen van `enemy.gd` bij naam; een bereik van twee getallen wordt een `Vector2`, een kleur is een hexcode. Nieuw daarbij is `size`: hoe groot het personage staat ten opzichte van hoe het gemaakt is. Zet een thema alleen `melee` aan bij een rol die schiet, dan krijgt die rol vanzelf het bereik van een vechter van dichtbij (aanval binnen 2 m, één klap per aanval); anders zou hij van 26 m afstand slaan. De botsvorm neemt de hoogte van het personage over en wordt smaller dan die van de robot (hooguit 0,19 keer de hoogte, nooit breder dan in de scène), en de ogen en het begin van het hoofd liggen waar het personage ze heeft, ook als het gebogen loopt. Een schot treft dus wat je ziet.
- **Ingestudeerde bewegingen.** De Universal Animation Library van Quaternius, deel 1 en 2, in de gratis Standard-uitgave: CC0, zonder account te downloaden van OpenGameArt. Bron, licentie en controlegetallen staan in `assets/animations/manifest.json`. De twee bronnen worden via een botkaart op het humanoid-profiel geïmporteerd, en `tools/build_moves.sh` knipt de 19 bewegingen die het manifest noemt naar `assets/animations/moves.res` (0,2 MB): stilstaan, lopen, rennen, sprinten, het schuifelen en het klauwen van een zombie, drie stoten, twee manieren van terugdeinzen, drie manieren van vallen en vier handhoudingen. In hetzelfde manifest staat welke bewegingen samen een manier van bewegen vormen (`default` en `zombie`; een onbekende naam in een thema is `default`). Een beweging houdt 22 botten en de verplaatsing van de heupen; de vingers krijgen één keer een houding. Elke loopcyclus wordt op één seconde gebracht, begint op de linkervoet en wordt opgemeten: hoe ver hij komt (lopen 1,05 m/s, rennen 5,9 m/s, sprinten 8,9 m/s, schuifelen 1,0 m/s voor de pop) en wanneer welke voet staat.
- **Wat de gratis set niet heeft**, en wat de rig daarom zelf doet: geen loop opzij of achteruit, niets met een geweer, en niets tussen een wandeling van 1 m/s en een ren van 6 m/s.
- **Lopen.** Er speelt één cyclus tegelijk, de traagste die past. Om de snelheid van het lijf te halen stapt hij sneller en, in gelijke mate, verder: de enkels worden tot 1,45 keer zo ver van de heupen gezet en de benen daarnaar gebogen. De benen staan in de richting waarin het lijf gaat en lopen vooruit of achteruit, wat de rug het minst verdraait; de romp draait terug naar waar hij op richt. Zo dient één loop voor alle richtingen: opzij met een geweer is de heupen een kwartslag naar rechts, en dan vooruit of achteruit. Een voet die volgens de cyclus staat wordt vastgehouden op de plek waar hij neerkwam, en de heupen zakken zover als nodig is om beide benen te laten reiken. De test meet hoe ver een voet verschuift terwijl hij staat: 0,000 tot 0,004 m/s in vijf richtingen, tegen 0,13 tot 0,34 m/s zonder dat vasthouden.
- **Wapen.** De vijf wapens zijn een tweede keer gebouwd zonder de handen van de speler en als één mesh (`tools/models/held.gd`, 2 tot 8 duizend driehoeken, `scenes/models/<wapen>_held.scn`), met markeringen waar de handen en ellebogen zaten. Wat een kolf heeft gaat aan de schouder, de rest op armlengte voor de ogen; beide armen worden met inverse kinematica naar de handplekken gebogen en de wang gaat naar de kolf. Zonder zicht op de speler hangt het wapen laag voor het lijf. Wie schiet zonder wapen in het thema, wijst; wie van dichtbij vecht, draagt niets.
- **Een aanval aankondigen.** Het wapen komt van net onder het doel omhoog en op de loop verschijnt een ster in de kleur van de rol (rood, oranje, paars: de kleur van het vizier van de robot). Die ster wordt op het scherm nooit kleiner dan hij op 5 m is; op 20 m is hij in een screenshot duidelijker dan het oplichtende vizier van een robot op dezelfde plek. Een klap wordt uitgehaald op het moment van aankondigen en zo getimed dat hij aankomt wanneer de aanval valt.
- **Geraakt worden en sterven.** Een treffer geeft bloed in plaats van vonken (`Fx.blood`: druppels en een rode nevel de kant op waarheen het schot ging, soms een spat op de vloer of de muur erachter) en laat de romp terugdeinzen, met een ingestudeerde beweging en een duw in de richting van het schot. Bij de dood valt het wapen als los voorwerp, en het lijf valt om: ineenzakkend, of achterover geworpen als de laatste klap zwaar was (60 schade binnen een ogenblik: een lading hagel, een schot van het scherpschuttersgeweer). Het draait daarbij weg van het schot, of naar waar ruimte is als daar een muur staat. Onder het lijf loopt een plas bloed uit. Een lijf heeft geen botsvorm, rekent niets meer uit zodra het stilligt, vervaagt na vijf seconden en is na zes weg; van de bloedsporen blijven de laatste 24 staan.
- **Geluid.** Stap, kreet, pijn en dood voor een mens en voor een zombie, een zwaai en een val, gesynthetiseerd zoals de rest. Wie een wapen draagt klinkt bij een schot als dat wapen.

**Werkwijze**

| Stap | Commando |
|---|---|
| De animatiebronnen ophalen volgens het manifest, daarna importeren | `tools/fetch_animations.py`, dan `godot --headless --path . --import` |
| De bewegingen opnieuw uit de bronnen knippen | `tools/build_moves.sh` |
| De wapens zonder handen opnieuw bouwen | `tools/build_model.sh held` |
| Een beweging als rij houdingen bekijken (90 draait de poppen op hun zij) | `tools/benchmark.sh --quick --scene=res://scenes/moves_sheet.tscn --move=death --turn=90 --at="0,1.15,5.4,0,-3"` |
| Een vijand in beweging als rij momenten: lopend (`--walk=rechts,vooruit` als deel van zijn snelheid), en met `--then=die`, `blast`, `hit`, `charge` of `swing` wat daarop volgt | `tools/benchmark.sh --quick --scene=res://scenes/moves_sheet.tscn --enemies=mannequin --enemy=res://scenes/enemy.tscn --walk=0.5,0 --step=0.12 --at="0,1.15,5.4,0,-3"` |
| Een vijand van een thema in een level bekijken (houdingen 1 tot en met 4 als hierboven; 5, 6 en 7 lopen naar rechts, naar links en achteruit, 8 is vlak voor de aanval, 9 de treffer) | `tools/benchmark.sh --quick --enemies=mannequin --spawn="res://scenes/enemy.tscn@-2,0,-1,-100,1,8" --at="2.5,1.7,3,90,-4"` |
| Meten wat vijanden kosten terwijl ze bewegen | `tools/benchmark.sh --enemies=mannequin --spawn="..." --animate` |
| Testen dat personages de speler vinden, raken en sterven, en dat hun voeten niet glijden (zonder venster) | `tools/test_humanoid.sh [--enemies=<thema>]` |

**Meting** op 9 oktober 2026 in de fabriek, M1 Pro, 2560×1440 met FSR 2 op 67%, kwaliteit High, midden in de hal met een volle wave van acht in beeld (vier grunts, drie rushers, een heavy) op 8 tot 12 m. De GPU wordt gedeeld met twee andere sessies, dus de cijfers zijn een indicatie. Ze komen uit runs die om en om zijn gedaan toen er niets anders op de GPU liep (twee rondes in beweging, één bevroren); de lege hal mat daarin vier keer 14,53 tot 14,58 ms en herhalingen verschilden hooguit 0,04 ms. Een derde reeks, later op de dag, is afgebroken omdat de anderen toen zelf maten.

| | Frame | Meer dan de lege hal |
|---|---|---|
| Lege hal | 14,55 ms | |
| Acht robots, bevroren in hun houding (zo is de 0,2 ms hierboven gemeten) | 14,74 ms | 0,17 ms |
| Acht poppen, bevroren | 14,94 ms | 0,37 ms |
| Acht robots, lopend op de plaats | 14,98 ms | 0,45 ms |
| Acht poppen, lopend op de plaats | 15,22 ms | 0,68 ms |

Acht poppen kosten dus 0,2 ms meer dan acht robots, bevroren en in beweging. Bevroren is dat het tekenen: een pop is 13,7 duizend driehoeken en draagt een wapen van 4 tot 8 duizend, een robot is er 6 tot 9 duizend, al vraagt een pop minder tekenopdrachten (hij is één mesh, een robot zestien: 835 tegen 1540 voor het hele beeld). In beweging komen daar bij allebei de schaduwen bij, die dan elke frame opnieuw getekend worden, en het poseren. Dat laatste kost per lopende pop 45 tot 80 microseconden per frame, waarvan 4 voor het mengen van de clips en de rest voor het script dat benen, romp en armen plaatst: voor acht poppen circa een halve milliseconde processortijd, waarvan maar een deel in de frametijd terugkomt omdat de GPU de maat bepaalt. Een volle wave poppen in beeld gebruikt daarmee ongeveer 3 fps van de marge van 10, waar de robots er 2 gebruiken. Een lijf dat stilligt kost alleen nog het tekenen.

**Nog open**

- De geluiden zijn niet beluisterd: de runs draaien zonder geluid en ik kan niet horen. Ze zijn afgeleid van de bestaande en bescheiden afgesteld.
- Er is maar op twee poppen met hetzelfde skelet getest, een man en een vrouw. Een personage met andere verhoudingen, kleding die doorbuigt of een skelet zonder tenen of vingers is nog niet voorbijgekomen; de rig houdt er rekening mee, maar gezien is het niet.
- De gratis animatieset heeft geen val voorover. Wie in de rug geschoten wordt, zakt daarom op zijn rug ineen, tegen het schot in.
- Tussen 2 en 3 m/s (een heavy, een grunt die opzij stapt, een zombie) is de loop een gehaaste wandeling met lange passen, omdat er geen cyclus is tussen wandelen en rennen. Een draf van rond 3 m/s lost dat op zonder code: een regel bij `moves` en zijn naam bij `gaits` in `assets/animations/manifest.json`, dan `tools/build_moves.sh`.
- Slaan met iets in de hand kan niet: daar zijn geen bewegingen voor geknipt (de set heeft wel zwaardslagen). Een rol die van dichtbij vecht draagt dus niets, ook als het thema een wapen noemt.
- De voeten volgen de vloer niet: op een trap staan ze op de hoogte van het lijf, zoals bij de robots. Bij snel omdraaien schuiven staande voeten in één keer mee zodra het lijf meer dan 35 graden gedraaid is.
- De vingers bewegen niet; ze hebben een greep, een vuist, een klauw of een losse hand.
- `tools/benchmark.sh --shoot` laat op een personage vonken zien in plaats van bloed, omdat de benchmark het effect zelf kiest en `Fx.robot_hit` aanroept; in het spel gaat een treffer via de vijand en klopt het.
- Een lijf kan door een muur steken als er in geen enkele richting 1,9 m ruimte is.

## Moderne shooter-eisen (fase 4)

**Wat er staat**

- **Menu.** Titelscherm over het geladen level, levelkeuze, pauzemenu (Esc of Start) en een instellingenscherm. Alles is met muis, toetsenbord en controller te bedienen. `--play` slaat het titelscherm over.
- **Instellingen**, bewaard in `user://settings.cfg`: kwaliteit (Low tot Ultra), upscaler, renderschaal, V-Sync, fullscreen, fps-teller, gezichtsveld, muis- en stickgevoeligheid, Y-as omkeren en volume. Een kwaliteitsniveau zet alleen effecten uit die het level zelf aan heeft staan.
- **Upscaling.** Bilinear, FSR 1, FSR 2 en op Apple-hardware MetalFX Spatial en Temporal.
- **Controller.** Linkerstick lopen, rechterstick kijken, RT vuren, LT richten, A springen, B bukken en sliden, X herladen, Y granaat, LB en RB wapen wisselen, linkerstick indrukken sprinten, Start pauze. Niet getest met een fysieke controller.
- **Checkpoints.** Elke wave die je bereikt is een checkpoint in `user://save.cfg`. Na een dood of een herstart van het spel ga je daar verder.
- **Wapens.** SMG (toets 4) en Marksman met kijker (toets 5), naast rifle, pistol en shotgun. Bij elk schot loopt de slede of de grendel terug en vliegt de huls eruit; het pistool blijft open staan als het leeg is. De shotgun wordt na elk schot doorgeladen en patroon voor patroon herladen, wat je met een schot kunt afbreken. Een magazijnwissel is te zien: het wapen kantelt, het magazijn gaat eruit en het nieuwe erin. Gericht toont de Marksman het beeld door de kijker, met een dradenkruis.
- **Vijanden.** Naast de grunt een rusher (snel, zwak, slaat van dichtbij) en een heavy (traag, veel health, lange salvo's). Rushers komen vanaf wave 2, heavies vanaf wave 4. Elke vijand gaat 1,5 tot 4 seconden na het spawnen op zoek naar de speler.
- **Tweede level: Depot.** Een ommuurd containerterrein in de schemering met een overdekt laadperron en een portiersloge, verlicht door schijnwerpers. De containers staan er in vijf kleuren lak, het perron heeft genummerde roldeuren en op het terrein staan de vakken van de containers nog op de grond. Hoofdscène `scenes/depot.tscn`, beschrijving in `tools/levels/depot.gd`. De gedeelde bouwstenen staan in `tools/level_builder.gd`.

**Meting op 1440p** op 8 oktober 2026, M1 Pro, 2560×1440, kwaliteit High (zonder SSIL), met alle 45 modellen, de machines en de uitgewerkte containers, tanks en kraan, zonder venster gemeten terwijl de laptop in gebruik was. Het budget van 60 fps wordt met upscaling gehaald, met 10 fps over.

| Level | Instelling | Gemiddeld (laagste en hoogste standpunt) | 1% low |
|---|---|---|---|
| Fabriek | FSR 2 op 67% | 71–76 fps | 69–75 fps |
| Fabriek | MetalFX Temporal op 67% | 73–78 fps | 70–72 fps |
| Fabriek | Geen upscaling | 52–59 fps | 46–57 fps |
| Depot | FSR 2 op 67% | 74–82 fps | 68–75 fps |

Met SSIL erbij haalde de fabriek met FSR 2 gemiddeld 66–72 fps en een 1% low die per run tussen 52 en 66 fps lag, afhankelijk van wat de machine verder deed. Dat was te krap om er nog iets bij te zetten. De marge is nu 10 fps in de vaste standpunten, waarvan het wapen en een volle wave vijanden er in het spel ongeveer 3 gebruiken: wat er in de fabriek nog bij komt, moet elders worden terugverdiend. Vóór de containers, tanks en kraan haalde de fabriek met FSR 2 70–74 fps en het depot 75–81 fps; in de fabriek is dat verschil met de lichtere lenspass terugverdiend, in het depot, waar 21 containers staan, voor de helft. MetalFX en de run zonder upscaling zijn gemeten vóór de kleine modellen erbij kwamen.

Het depot haalt op 1920×1080 zonder upscaling 85–102 fps gemiddeld en 80–98 fps 1% low.

**Wat een vuurgevecht kost**, gemeten op 9 oktober 2026 in de fabriek op 1440p met FSR 2 op 67%, met de karabijn in beeld en twaalf schoten per seconde in elk standpunt (vlam, licht, tracer, inslag en kogelgat bij elk schot):

| | Gemiddeld (laagste en hoogste standpunt) | 1% low |
|---|---|---|
| Wapen in beeld, er wordt niet geschoten | 69–74 fps | 67–71 fps |
| Aanhoudend vuur | 68–72 fps | 65–69 fps |

Dat is 1 tot 3 fps, het meest in de gang, waar de stofwolken dichtbij hangen en dus het meeste beeld vullen. Er is geen hapering bij het eerste schot: de 1% low blijft even dicht bij het gemiddelde als zonder schieten. Zolang er niet geschoten wordt kosten de effecten niets, want er bestaat dan niets van.

De benchmark neemt hiervoor opties aan: `tools/benchmark.sh --res=2560x1440 --upscaler=fsr2 --scale=0.67 --scene=res://scenes/depot.tscn`. Het volgende geldt alleen nog voor een run in een venster (`GODOT_WINDOW=1`); zonder venster wordt elk frame getekend. macOS tekent een bedekt venster niet; de benchmark mat dan steeds circa 145 fps, wat op een uitstekende meting lijkt. Hij telt daarom nu alleen een ononderbroken reeks getekende frames en begint een standpunt opnieuw zodra het venster weer zichtbaar is. Dat werkt: na een korte onderbreking ging een run vanzelf verder, en een run waarvan het venster tien minuten lang niet getekend werd, bleef al die tijd wachten. Een run met de melding `window is not being drawn` gooi je wel weg, want de frames eromheen zijn onbetrouwbaar (één zo'n run gaf een 1% low van 21 fps). Na een minuut zonder getekend frame hoort de benchmark met een fout te stoppen; dat is nog niet in het echt gebeurd. Een onbekende upscaler of een onbekend effect bij `--off` geeft een fout in plaats van een meting onder de verkeerde naam. Meet met niets anders op de GPU: een tweede Godot ernaast halveert de cijfers.

**In deze fase opgelost**

- Vijanden die buiten het zicht van de speler spawnden, bleven daar voor altijd staan, waardoor een wave kon stilvallen. Ze komen nu vanzelf naar de speler toe (`HUNT_DELAY` in `scripts/game.gd`).
- De tussenvloer en de twee kamers in de aanbouw zaten niet aan het navmesh vast: de trap en de deuren waren te smal. Vijanden die daar spawnden kwamen er niet af. De trap is nu 2,2 m breed en de deuren 1,6 m, en de selftest controleert voor elk level dat elk spawnpunt de speler kan bereiken.

**Nog open**

- Vaten komen niet terug: wat in een wave is opgeblazen, is weg tot je doodgaat of het level opnieuw begint. Granaten krijg je elke wave opnieuw.
- Robots weten niets van vuur en granaten: ze lopen door een brand heen en blijven naast een brandend vat staan. Dat maakt de vaten nu vooral een wapen van de speler.
- Door een wrak loop je heen, en een schot gaat erdoor: het botst alleen met het level. Waar een vat stond, houdt het navmesh een gat.
- Vuur slaat niet over op kisten of pallets, en de klap van een explosie beweegt geen props: alles wat een lightmap heeft, staat vast.
- De granaat is in de hand niet te zien; alleen de arm die hem gooit beweegt.
- Een schot in een plas spat niet op: of een punt nat is, weet alleen de vloershader. Ramen hebben geen botsvorm, dus een schot gaat er zonder spoor doorheen.
- Een stelling heeft één doos als botsvorm; een schot tussen de planken door geeft daarom vonken in de lucht ervoor.
- De selftest meet "enemies approach" in echte tijd en faalde één keer op die stap toen de laptop zwaar belast was; drie herhalingen daarna slaagden.
- Geen instelbare toetsen en geen aim assist voor de controller.
- De HUD schaalt niet mee op hoge resoluties; de tekst is daar klein.
