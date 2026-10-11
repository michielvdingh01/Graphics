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
| 3. AI-assetpipeline | parallel aan fase 2 | Scripts die uit het manifest props, texturen, skyboxes en geluid genereren en importeren | Begin gemaakt: decals, opschriften, kogelgaten, slijtagemaskers en de normal maps voor oppervlakken van dichtbij komen procedureel uit het manifest en modellen van Poly Haven worden via het manifest opgehaald. Twintig geluiden worden via het manifest uit CC0-opnames gesneden en in lagen gemengd, zie Geluid. Zelf genereren van props, wapens, vijanden en geluid wacht op een generatiedienst |
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

Het level is een verlaten fabriek bij zonsondergang: een hal met kraanbaan en tussenvloer, een aanbouw met gang en twee kamers, en daarachter een ketelhuis waar je door een gang met een knik komt. De hoofdscène is `scenes/factory.tscn`; de greybox uit fase 0 en 1 staat nog in `scenes/main.tscn`.

**Wat er staat**

- Gescande PBR-materialen van Poly Haven (2K, CC0) en een HDRI als lucht, vastgelegd in `assets/manifest.json`.
- Gebakken lightmaps voor al het indirecte licht; zon en lampen zijn realtime met schaduwen.
- Volumetrische mist met lichtbundels, reflectieprobes per ruimte, screen-space reflecties, SSAO, SSIL, glow en AgX-tonemapping.
- Een natte-vloer-shader met plassen met een grillige rand en een lenspass met vignette en filmkorrel. De lichte chromatische aberratie zit alleen nog in Ultra: daarvoor moet het beeld worden teruggelezen, en dat kostte op 1440p circa 2 fps voor iets wat je nauwelijks ziet.
- Vuil glas in alle ramen en dakramen, met hier en daar een ontbrekende ruit.
- Decals: lekstrepen onder de ramen, vuil langs de plinten en olievlekken op de vloer.
- Gescande CC0-modellen van Poly Haven (1K), 45 in totaal: vaten, houten kisten, betonnen wegbarrières, stellingen, hallampen, schakelkasten, een bureau, banden, gasflessen, cementzakken op pallets, een compressor, een lasset, gereedschapswagens, een ladder, een steekwagen, werkbanken met twee kolomboren, een bankschroef en een gereedschapskist, een kruk en groepenkasten. Daarbij het kleine spul dat een ruimte bewoond maakt: brandblussers en brandmelders bij de deuren, jerrycans en olieblikken bij de machines, gereedschap op de werkbank, een voorhamer en een koevoet tegen de muur, bezems, vuilniszakken, kartonnen dozen, plastic stoelen, putdeksels in de vloer en een waarschuwingsbord bij de plas in de gang. Ze staan in het manifest, krijgen bij import lightmap-UV's (importstandaard in `project.godot`) en worden door de levelbouwer geplaatst, die er zelf een eenvoudige botsvorm bij zet; los gereedschap (`drop`) krijgt geen botsvorm en geen lightmap.
- Een excenterpers en een draaibank van zes meter, in code opgebouwd (`press` en `lathe` in `tools/kit/machines.gd`), omdat er van grote machines geen gescande modellen zijn. De levelbouwer heeft daarvoor afgeronde blokken, omwentelingslichamen en slangen gekregen (`rounded_box`, `revolve`, `hose`). Samen zijn ze circa 26 duizend driehoeken; ze horen bij de gewone levelgeometrie en krijgen dus een lightmap. Blank staal, donker staal, rubber, messing en rode lak zijn materialen zonder eigen kleurtextuur. De werklamp van de draaibank brandt en boven de werkbank hangt een tl-buis, anders stond die hoek in het donker.
- Ook in code opgebouwd, omdat Poly Haven er geen modellen van heeft: zeecontainers van geperste panelen met deuren en sluitstangen (`container`, met `corrugated` voor het geperste staal), twee opslagtanks met mangat, peilglas, afsluiters, kooiladder en leidingwerk naar de wand (`tank`), een bovenloopkraan met loopkat, haakblok, kabelslingers en hangende bediening (`crane`), roldeuren van lamellen (`roller_door`), pallets van losse planken, ronde buisleuningen met schopplaat, werkplaatskasten en een rij kluisjes waarvan er twee openstaan (`cupboard`, `lockers`). De gedeelde bouwstenen staan in `tools/level_builder.gd` en in de bouwdoos (`tools/kit/`) en gelden dus voor elk level.
- Al het gelakte staal (machines, containers, tanks, kraan, leuningen, leidingen) gebruikt één shader, `shaders/worn_paint.gdshader`: een laklaag in een kleur naar keuze over een gescande laktextuur, met roestplekken die strepen naar beneden trekken, afgebladderde randen die op de rand zelf blank zijn gesleten, en stof op wat naar boven wijst. De levelbouwer geeft daarvoor elk vlak mee hoe ver een punt van de rand ligt, verpakt in de vertexkleur (`_edge`). De ruis komt uit een procedureel masker in het manifest (`wear`), de roest uit een scan van Poly Haven.
- Vloerbelijning in de hal: een rijpad van de laaddeur naar de aanbouw met een aftakking naar de trap, zwart-gele randen om de pers en de draaibank, arcering voor de laaddeur en de schakelkasten, en opslagvakken langs de zuidwand. Een level beschrijft de belijning met `floor_line`, `floor_frame` en `floor_hatch`; de levelbouwer tekent daar één textuur van en de vloershader legt die over het beton en laat de verf slijten.
- Opschriften, gesjabloneerd met de bruggetjes die een sjabloon nodig heeft: nummers op de containers, de hijslast op de kraan, tanknummers, deurnummers op het perron van het depot en vaknummers op de vloer. De pers en de draaibank hebben een machinenummer, tekst op hun typeplaatje, de perskracht op de kop en waarschuwingsdriehoeken waar iets beweegt (soort `warning` in het manifest). Elk opschrift staat als decal in het manifest (soort `text`) en wordt gezet in het ingebouwde lettertype van de engine, dus zonder extra bestand; `label` plaatst het en `floor_text` schildert het mee in de vloerverf. Ze kosten geen meetbare rekentijd.
- De aanbouw is ingericht als het kantoor- en magazijngedeelte van een fabriek. De muren hebben een lambrisering: glansverf tot heuphoogte met een bies erboven en een donkere plint, afgebladderd waar karren en schoenen ertegen stoten en vuil vanaf de vloer (`shaders/dado_wall.gdshader`, materiaal `plaster_dado`; het kost geen geometrie). Beide kamers hebben een stalen kozijn met dubbele deuren die openstaan, met een ruitje, een schopplaat, klinken en scharnieren (`doorway` en `_leaf` in `tools/kit/fittings.gd`), en een nummerplaatje ernaast. Onder het plafond van de gang lopen een luchtkanaal van verzinkt plaatstaal met roosters en een kabelladder met kabels; vanaf de ladder komt een buis naar een schakelaar bij elke deur. Op de gangmuur hangt een prikbord. De scharnieren zitten aan de buitenkant van het kozijn, zodat een open deur de doorgang niet smaller maakt: die is precies zo breed als de robots nodig hebben.
- Stof in de lucht van de hal: 4000 deeltjes die alleen oplichten waar licht op valt, dus in de zonnebundels en onder de lampen (`shaders/dust.gdshader`). Kost 0,1 tot 0,2 ms. Het ketelhuis heeft er 1400 van zichzelf; de levelbouwer zet het stof per ruimte neer (`dust`), zodat het verdwijnt met de ruimte waar het hangt.
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
- **Handgranaten.** Twee om mee te beginnen en hooguit drie, met G of Y op de controller. Een checkpoint vult ze aan tot twee en een heavy laat er een achter (zie Gevechten). De linkerhand laat het wapen los, wat een herlaadbeurt afbreekt; de granaat stuitert, rolt en gaat na 2,2 seconden af met dezelfde klap als een vat. Het model is in code gebouwd (`tools/models/props.gd`) en de HUD toont hoeveel er nog zijn.
- **Waar ze staan.** `fuel` in de levelbouwer zet een rood vat neer. In de fabriek staan er negen: langs het rijpad waar de robots overheen komen, aan de kop van de containers, in een laadvak en één op de tussenvloer. In het depot acht, waar de gangpaden tussen de containers kruisen en op het perron. Daarnaast de gasflessen en jerrycans die er al stonden.
- **Hoe het eruitziet.** Een explosie is een lichtflits, een drukgolf die een derde seconde lang het beeld erachter vervormt (`shaders/shockwave.gdshader`), een vuurbal die van witgeel via oranje tot roet uitbrandt, een ring van stof die over de vloer wegschiet, vonken en brokstukken. Vuurbal en rook zijn dezelfde zachte bollen als het stof van een inslag, maar ze branden: het heetst waar ze het dikst zijn, en de dunne randen gaan het eerst uit, zodat het vuur opbreekt in de rook die het achterlaat. Vuur dat blijft branden is een eigen shader (`shaders/flames.gdshader`): bollen vlam die van de grond opstijgen, onderweg tot een punt worden uitgerekt en uitbranden, en onderaan opnieuw beginnen, elk in zijn eigen ritme. Met een lange reikwijdte en een hoog tempo is dezelfde shader de steekvlam van een gasfles. Het licht van een vuur flakkert en neemt af zoals dat van een echte vlam, zodat het bij het vuur blijft.
- **Hoe het werkt.** De levelbouwer geeft elk model dat kan ontploffen een eigen botsvorm met `scripts/explosive.gd` erop, in plaats van een vorm in het ene grote lichaam van het level; alleen zo kan het uit het level verdwijnen. Het model houdt zijn stukje lightmap, het wrak is een kopie die door de probes wordt belicht waar het ook terechtkomt. `scripts/blast.gd` doet de schade, het wegslingeren en de kettingreactie; wat er te zien is, is van `Fx.explosion` en `Fx.fire`. Een blast zoekt alleen op de lagen van speler, robots, losse stukken en explosieven, want het level zelf is één lichaam met duizenden vormen.
- **De rook van een explosie wordt niet per pixel belicht.** Dat was de eerste opzet, zoals bij het stof van een inslag, en het kostte een derde van de framerate: een wolk die een kwart van het beeld vult, moet dan voor elke pixel van elke bol de lampen en schaduwen opzoeken. Met één explosie per seconde vol in beeld zakte het van 74 naar 48 fps. Schaduwen weglaten gaf 53 fps, belichten per hoekpunt 57, niet belichten 67. De rook van explosies en vuur gebruikt daarom `shaders/smoke.gdshader`, dezelfde bollen zonder belichting (beide shaders delen `shaders/puff.gdshaderinc`). In plaats daarvan krijgt een wolk één helderheid mee: één straal naar de zon zegt of hij in de schaduw hangt of in het licht. Roet is zo donker dat het verschil met echte belichting niet te zien is.

- **Wat het kost.** Zolang er niets ontploft: niets. Gemeten op 9 oktober 2026 in de fabriek op 1440p met FSR 2 op 67%, met de karabijn in beeld en elke seconde een explosie met nabrandend vuur, negen meter voor elk standpunt:

| | Gemiddeld (laagste en hoogste standpunt) | 1% low | Traagste frame |
|---|---|---|---|
| Wapen in beeld, er ontploft niets | 65–74 fps | (laptop in gebruik, zie hieronder) | |
| Elke seconde een explosie | 64–66 fps | 60–61 fps | 17–20 ms |

  Dat is 1 tot 8 fps, voor iets wat in het spel een paar keer per gevecht gebeurt en niet elke seconde. De traagste frame van zo'n run duurde 20 ms tegen 14 tot 16 normaal: de eerste explosie hapert niet. De benchmark drukt die traagste frame nu bij elke meting af.

**Afwijking van het plan: SDFGI staat uit.** Naast de lightmaps gaf SDFGI geen zichtbaar verschil, maar het kostte circa 25 fps. Dynamische objecten krijgen hun indirecte licht van de lightmap-probes.

**SSIL staat alleen nog op Ultra aan.** Het kostte 1,25 ms van een frame van 14 ms (op 1440p met FSR 2), terwijl het naast de lightmaps alleen zonbeschenen objecten een fractie lichter maakt; in een vergelijking naast elkaar is het verschil niet te zien. Op High levert het weglaten 7 fps op.

**Werkwijze**

| Stap | Commando |
|---|---|
| Assets ophalen volgens het manifest (texturen, HDRI's en modellen) | `tools/fetch_assets.py` |
| Nieuw opgehaalde bestanden importeren | `godot --headless --path . --import` |
| Procedurele decals en maskers opnieuw genereren volgens het manifest | `tools/gen_decals.sh` |
| Geluiden uitsnijden en mengen volgens het manifest; haalt de pakketten op als ze ontbreken. Met een naam erachter alleen dat geluid opnieuw, met `--all` alles | `tools/build_sounds.py` |
| Een geluid horen zoals de game het afspeelt, door de bussen heen: één keer, of anderhalve seconde vuur met het aantal schoten per minuut erachter | `tools/hear.py rifle_shot 620` |
| Levelgeometrie opnieuw genereren uit `tools/levels/<naam>.gd` | `tools/build_level.sh factory` of `depot` |
| Alle levels en modellen opnieuw bouwen en horen wat er anders uitkomt dan wat er in git staat; wat gelijk is gebleven wordt teruggezet | `tools/build_check.py`, of `tools/build_check.py factory` voor één level |
| Een bouwsteen van dichtbij bekijken zonder een level te bakken: alles wat in code is opgebouwd staat naast elkaar in de showroom (`tools/levels/showroom.gd`) | `tools/build_level.sh showroom`, dan `tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="-23,2.2,9,0,-5"` |
| Lightmaps bakken: alleen wat sinds de vorige bake veranderd is (de hal duurt twee minuten, het ketelhuis een halve). De bake drukt op de knop van de editor zelf en zet daarvoor eerst de 3D-weergave voor | `tools/bake_lightmaps.sh [res://scenes/depot.tscn]` |
| Horen welke zones een bake nodig hebben, bepaalde zones bakken wat hun staat ook is, of alles | `tools/bake_lightmaps.sh --list`, `tools/bake_lightmaps.sh res://scenes/factory.tscn boiler,passage`, `tools/bake_lightmaps.sh --all` |
| Wapens, vijanden of de granaat opnieuw genereren uit `tools/models/<naam>.gd` | `tools/build_model.sh weapons`, `enemies` of `props` |
| Een wapen bekijken zoals de speler het vasthoudt (nummer in de loadout vanaf 0; `,1` erachter is gericht, `,0,0.4` is 40% van het herladen) | `tools/benchmark.sh --quick --weapon=2 --at="2,1.7,3,-120,0"` |
| Een model of een vijand in een level neerzetten om te bekijken (x,y,z,draaiing,schaal,houding: 1 richt, 2 loopt, 3 ligt in stukken, 4 vuurt, 10 met de plaat voor zich, 11 weggedoken, 12 met een brandend pack) | `tools/benchmark.sh --quick --spawn="res://scenes/enemy_heavy.tscn@-2,0,-1,-100,1,1" --at="2.5,1.7,3,90,-4"` |
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
| Alleen testen wat de vijanden in een gevecht doen en wat er te vinden is (50 seconden). Met `--map` erbij de dekking in de fabriek als plattegrond, met `--trace` wat één grunt van stap tot stap doet | `tools/selftest.sh --fights` |
| Alleen de routes door de levels testen, met een lijst van waar elke robot verschijnt: het deel om te draaien terwijl je aan een level bouwt (25 seconden) | `tools/selftest.sh --routes` |
| Samen spelen testen: het spel twee keer zonder venster, één host en één gast (35 seconden) | `tools/nettest.sh [--enemies=<thema>]` |
| Een medespeler bekijken zoals een ander hem ziet (houding 1 richt, 2 loopt, 3 rent; de tiende kiest het wapen) | `tools/benchmark.sh --quick --spawn="res://scenes/puppet.tscn@1,0,-7.4,-90,1,2.2" --at="4.2,0.9,-7.4,90,0"` |
| Het spel zelf bekijken zoals het gespeeld wordt, met HUD en menu: een screenshot na zoveel seconden. `--at` zet de speler ergens neer, `--eval` voert een regel script uit; de save blijft ongemoeid | `tools/godot.sh -- --play --snap=5 --at="-7,0,0.5,90,4"` of `--snap=4 --eval="Menu.show_end(27)"` |
| Iets tonen wat een level verborgen houdt tot het spel het aanzet, zoals de lamp boven een uitgang | `tools/benchmark.sh --quick --show=Lamp --at="-7,1.7,0.5,90,4"` |
| De robots van de route op hun post zetten, uitgeschakeld zoals de speler ze aantreft: om een standpunt te zien zoals het in het spel is, of om te meten wat het kost dat ze er staan | `tools/benchmark.sh --posted` |
| De uitgang tonen zoals hij is als alles is opgeruimd: de lamp aan en de deur omhoog | `tools/benchmark.sh --quick --exit --at="-7,1.7,0.5,90,4"` |
| Meten wat het scheelt dat alleen de zones in het zicht worden getekend: een run waarin alles wordt getekend, of dat ene verschil een paar keer achter elkaar | `tools/benchmark.sh --off=zones` of `tools/benchmark.sh --profile --only=zones` |
| Meten wat aankomen in een andere zone kost: de traagste frame telt dan vanaf het eerste beeld | `tools/benchmark.sh --quick --warmup=0 --at="40.2,1.6,-17.1,90,0;15,1.6,8,68,0"` |
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

## Geluid (fase 3)

Alle geluid werd bij het opstarten gesynthetiseerd uit ruis en een toon. Sinds 9 oktober 2026 zijn twintig van de 32 geluiden opnames: 95 takes, samen 6,5 MB in `assets/audio/`. De eerste versie, één kale opname per geluid, klonk bij het beluisteren "vlak en minimalistisch", het automatische wapen voorop. De tweede versie van 10 oktober legt lagen onder de wapens, de explosie en de robot die uit elkaar valt (acht van de twintig geluiden) en stuurt alles door een busindeling met galm. Van de karabijn zijn daarna twee varianten naast die van gisteren beluisterd als gerenderd salvo; de zwaardere is gekozen, voor de karabijn en de pistoolmitrailleur. Al het andere is gemeten en niet beluisterd.

- **Waar de opnames vandaan komen.** Vier pakketten, alle vier CC0, die met hun adres en checksum als `packs` in het manifest staan:

| Pakket | Maker | Gebruikt voor |
|---|---|---|
| The Free Firearm Sound Library, de voorbewerkte schoten (194 MB) | Still North Media | De vijf wapens en het schot van een robot, en de knal vooraan in een explosie |
| Impact Sounds (0,8 MB) | Kenney | Voetstappen, neerkomen na een sprong, geraakt worden, de slag van een rusher, inslagen per ondergrond, het wrak van een vat dat neerkomt, een granaat die stuitert, het staal in een robot die uit elkaar valt |
| Sci-fi Sounds (5,9 MB) | Kenney | Explosies, een robot die uit elkaar valt, de vlam uit een lek vat |
| Metal footsteps on concrete (0,7 MB) | Thimras | De stappen van een robot |

  De karabijn is een AK-47, het pistool een Walther PPQ, het pompgeweer een Benelli Nova en een Mossberg, de pistoolmitrailleur een PPSh en het scherpschuttersgeweer een Mosin Nagant, alle van dichtbij opgenomen (in de library "near distance": twee microfoons voor de schutter, links en rechts). Een robot schiet met een Carl Gustav M45, opgenomen op halve afstand ("mid distance").

- **Hoe het werkt.** Elk geluid is een regel in het manifest (soort `sound`) met het pakket en het bestand waar het uit komt. `tools/build_sounds.py` haalt een pakket op naar `.cache/sounds/` (buiten git, 289 MB), pakt alleen de genoemde bestanden uit en zoekt de takes in een opname: een bestand uit de wapenlibrary bevat twee tot vijf schoten met stilte ertussen. Elke take wordt uitgesneden, gemengd met zijn lagen, sterft aan het eind uit en komt als 16 bit, 44,1 kHz in `assets/audio/<naam>/`. `scripts/sfx.gd` laadt bij het opstarten elke map en kiest elke keer een andere take dan de vorige. De gameplay kent een geluid alleen bij naam: een map met de naam van een gesynthetiseerd geluid vervangt het zonder dat er code verandert.
- **Waarom één opname niet genoeg is.** Een opgenomen schot is één piek van tien milliseconden met bijna niets erna: 40 ms na de knal is het ruim 30 dB zachter, en onder 250 Hz zit bij de karabijn een kwart van de energie en bij de pistoolmitrailleur 9%. Het gehoor telt geluid op over zo'n 200 ms, dus harder aanzetten helpt niet: in een salvo van de karabijn viel het niveau tussen twee schoten 34 dB weg, losse tikken met stilte ertussen.
- **Lagen.** Elk wapen is daarom drie lagen. De knal is de opname van dichtbij, ingekort tot waar de knal begint (`tight`): de takes van de pistoolmitrailleur begonnen 30 ms te vroeg, met het mechaniek, en klonken dus bijna een half schot te laat. Daaronder ligt het laag van hetzelfde of een zwaarder wapen, opgenomen op halve afstand en afgesneden boven 400 tot 500 Hz, en een dreun: een sinus die in 60 tot 250 ms van 110 à 180 Hz naar 40 à 70 Hz zakt. Een laatste zachte begrenzer over het geheel (`glue`) maakt er één geluid van. Per laag is gemeten met welke vertraging en polariteit het laag optelt bij dat van de opname in plaats van het uit te doven; dat scheelt per laag tot 4 dB, gemeten op het linkerkanaal. Het pompgeweer heeft er twee takes van een Mossberg bij gekregen en heeft er nu vier.

| Per schot | Onder 250 Hz | Binnen 20 dB van de piek |
|---|---|---|
| Karabijn | 25 → 65% | 41 → 119 ms |
| Pistoolmitrailleur | 9 → 45% | 36 → 67 ms |
| Pistool | 14 → 44% | 40 → 70 ms |
| Pompgeweer | 29 → 62% | 88 → 190 ms |
| Scherpschuttersgeweer | 23 → 66% | 60 → 186 ms |
| Schot van een robot | 7 → 36% | 70 → 108 ms |

- **Explosie en robot.** De explosie was een plak van 1,2 s zonder knal (piek 6,4 dB boven het gemiddelde). Ze heeft nu de knal van het pompgeweer vooraan en minder begrenzing erna (8,6 dB). Een robot die uit elkaar valt zwol pas na 40 ms aan en bestond voor 99% uit laag; daar liggen nu staalplaat en metaal in, vanaf het eerste moment. Een schot dat een robot raakt maakte geen geluid behalve de hitmarker en klinkt nu als een inslag op metaal.
- **Bussen.** `default_bus_layout.tres` geeft de game vijf bussen. Alles in de spelwereld, het eigen wapen ook, gaat over World: daarop zit de galm van de ruimte en een clipper (2 dB erin, 4 dB eruit). De tonen van de hitmarker gaan droog over UI, op -10 dB: op -4 dB liet elke treffer de begrenzer ingrijpen en was een salvo dat raak was ruim 1 dB zachter dan een dat miste. Voice en Music liggen klaar. Op Master zit een begrenzer op -1 dB. De volumeschuif staat achter die effecten en verandert dus niet hoe hard ze werken.
- **Galm per ruimte.** `scripts/sfx.gd` kent drie ruimtes en volgt de camera: de fabriekshal (nagalm 2,7 s onder 1 kHz), een kamer (de aanbouw en het poortgebouw, 1,0 s) en de open plaats van het depot (een herhaling om de 175 ms, die ongeveer even lang doorklinkt als de kamer en geen losse echo is). Gerekend naar afmetingen en materiaal galmt een echte hal van 40 bij 24 bij 9 m ruim 6 s na; dat is hier bewust korter, omdat het niveau van de galm bepaalt of schoten los van elkaar blijven. De eis was dat het niveau tussen twee schoten bij 900 schoten per minuut nog 10 dB zakt.
- **Wat op afstand speelt.** Godot haalt bij een 3D-geluid standaard tot 24 dB van alles boven 5 kHz af naarmate het verder weg of zachter is, gemeten twee keer zo sterk als de instelling zegt: een inslag op 8 m was boven 10 kHz 36 dB kwijt en over alles boven 5 kHz 24 dB. Dat staat nu op 6 dB. Een geluid dichtbij was begrensd op +3 dB, waardoor de +6 dB van een explosie binnen 11 m niets uitmaakte. Een inslag speelt op -8 dB, één per doel per schot: een lading hagel in een robot op armlengte gaf negen inslagen op vol niveau, 12 tot 14 dB te veel.
- **Wat het oplevert**, gerenderd zoals de game het afspeelt (`tools/render_mix.gd`), voor en na:

| | Salvo karabijn, 620 per minuut | Salvo pistoolmitrailleur, 900 per minuut |
|---|---|---|
| Luidheid over het salvo | -7,4 → -6,0 LUFS | -7,7 → -6,2 LUFS |
| Val tussen twee schoten | 34 → 11 dB | 32 → 12 dB |
| Niveau tussen de schoten, tegen het schot | -16 → -4 dB | -16 → -6 dB |
| Staart tot -40 dBFS na het laatste schot | 0,22 → 1,34 s | 0,23 → 1,21 s |

  "Voor" is de versie van 9 oktober, droog op Master zonder bussen; "na" gaat door de bussen, die 1 dB onder het maximum blijven waar de oude versie eroverheen ging. Een vuurgevecht van 94 geluiden in 3,2 s (de karabijn ingedrukt, een inslag per schot, voetstappen, twee salvo's van een heavy en twee explosies) piekte op de uitgang op +7,9 dBFS met 16.519 samples boven het maximum, en nu op -2,3 dBFS met geen enkele. Een explosie op 4 m is even luid als voorheen (-6 LUFS over de eerste 400 ms) en dus niet luider dan een salvo. De luidheid is gemeten met een eigen K-weging: de verschillen kloppen, de absolute waarden zijn bij benadering.
- **Kleiner.** De takes worden ongecomprimeerd geïmporteerd: Godots standaard (Quite OK Audio) maakte van de steile flank van een schot een fout die maar 12 tot 21 dB onder het schot lag. De toonhoogte van een schot varieert 3% in plaats van 6%; een halve toon verschil per schot klonk als telkens een ander wapen.
- **Beluisteren zonder de game.** Een take op schijf is niet meer wat de speler hoort. `tools/hear.py rifle_shot 620` rendert anderhalve seconde vuur door de bussen van de game en speelt die af; zonder getal één schot. Elk geluid speelt daarbij op vol niveau en in het midden, zoals het eigen wapen, dus een voetstap of een schot van een robot klinkt er harder dan in het spel.
- **Eigen opnames.** Een opname van onszelf komt in `assets/recordings/` (Godot slaat die map over) en krijgt een regel in het manifest met `"source": "recording"`. Met `"split": true` mag één opname meerdere takes bevatten met telkens een halve seconde stilte ertussen; elke take wordt een variatie. Getest met aiff en met m4a, het formaat van Dictafoon en QuickTime, op een door de Mac ingesproken bestand; een echte opname is er nog niet.
- **Nog gesynthetiseerd.** Twaalf geluiden: herladen (twee), leeg klikken, wisselen van wapen, de pin en de worp van een granaat, de sliding, een huls op de vloer, de drie tonen van de hitmarker en het signaal van een robot die je ziet. De voorbewerkte wapenlibrary bevat alleen schoten; het mechaniek (grendel, magazijn, leeg klikken) zit in de ruwe versie van ongeveer 3 GB, die alleen via MediaFire te halen is.

**Nog open**

- Alleen de salvo's van de karabijn en de pistoolmitrailleur zijn beluisterd, buiten het spel. De andere wapens, de explosie, de galm van de kamer en de plaats en de balans tussen de geluiden zijn gekozen op meting en op wat geluidsontwerpers van shooters beschrijven. Drie dingen kan alleen een oor beoordelen: of het laag van het scherpschuttersgeweer, dat 19 ms na de knal piekt, ermee versmelt; of de begrenzers achter elkaar (`punch`, `glue` en de clipper op World) scheuren; en of de echo van de schietbaan, die in elke opname zit, binnen stoort.
- Boven 150 Hz is de knal van vier van de vijf wapens iets zwakker dan in de eerste versie: het laag neemt ruimte in onder dezelfde piek. Op kleine luidsprekers blijft vooral de winst tussen de schoten over.
- In de stereotakes loopt het rechterkanaal 1 tot 2 ms voor op het linker; dat zit in de opnames. Op een koptelefoon kan de knal daardoor iets rechts van het midden staan.
- Een explosie is niet het luidste wat er gebeurt: alles op World loopt tegen dezelfde clipper aan.
- De galm is op elke afstand even sterk ten opzichte van het directe geluid. In een echte hal is een robot op 20 m vooral galm.
- De kamers waarin de galm omschakelt zijn dozen met vaste coördinaten in `scripts/sfx.gd`. Verhuist de aanbouw in `tools/levels/factory.gd`, dan moeten ze mee. Door het raam van kamer B kom je buiten te staan in de galm van de hal.
- Geluid dat nog klinkt als je naar het titelscherm gaat of opnieuw begint vanaf een checkpoint, klinkt verder aan het begin van het volgende spel.
- De begrenzer van Godot komt na een ingreep nooit helemaal terug (0,2 dB van elke 3 dB blijft staan). Daarom blijft de mix eronder en hoort hij alleen bij uitschieters in te grijpen.
- De vuursnelheid wordt afgerond op hele frames: op 60 fps vuurt de pistoolmitrailleur 720 in plaats van 900 schoten per minuut en de karabijn 600 in plaats van 620 (nagerekend, niet in het spel gemeten).
- Elk wapen heeft drie tot vijf takes.
- Robots hebben geen stem en de stemmen van personages zijn gesynthetiseerd; er is geen omgevingsgeluid, geen muziek en geen geluid van een schot dat langs je heen gaat.
- De galm kent het ketelhuis en de doorgang van de fabriek niet: daar klinkt het als in de hal.

### Volgende ronde geluid (plan, 10 oktober 2026)

Zes dingen die bij het spelen nep klonken. Dat was gespeeld op een stand zonder de opnames; punt 3, 4 en het stuiteren uit punt 5 zijn sindsdien al opnames. Daarom eerst luisteren, dan pas bouwen.

**Stap 0: luisteren naar wat er nu is.** `tools/hear.py shotgun_shot`, `tools/hear.py marksman_shot`, `tools/hear.py bounce`, en één ronde in het spel. Wat dan nog nep klinkt gaat door; de rest valt af.

| # | Geluid | Nu | Plan |
|---|---|---|---|
| 1 | Huls op de vloer (`casing`) | Gesynthetiseerd: 70 ms toon van 3400 Hz | Opnames van messing op beton, 5 tot 6 takes, en een eigen set voor de dikke huls van het pompgeweer (plastic, doffer). Twee tikken per huls in plaats van één: de tweede zachter en 60 tot 120 ms later, door `scripts/fx.gd` afgespeeld bij de tweede stuit die de huls al maakt. Per ondergrond hoeft niet: bijna alles is beton. |
| 2 | Herladen (`reload`, `reload_end`) | Gesynthetiseerd: twee tikken, dezelfde voor elk wapen | Per wapen een eigen reeks, in stappen die bij de animatie horen: magazijn eruit, magazijn erin, grendel of slede. Het pompgeweer krijgt per patroon een klik en aan het eind de pomp. Dat vraagt een veld `reload_sounds` in `WeaponData` en tijdstippen in `scripts/weapons.gd`, die nu twee vaste momenten kent. `dry_fire` en `switch` gaan in dezelfde ronde mee: ze komen uit dezelfde bron. |
| 3 | Pompgeweer (`shotgun_shot`) | Opname sinds 9 oktober: Nova en Mossberg, 1,15 s, binnen 30 dB van de piek tot 0,22 s | Als het na stap 0 nog te licht is: de staart langer laten doorklinken (minder `tight`, de take op afstand hoger in de mix en niet onder 400 Hz afgekapt), de dreun dieper en langer (`sweep` van 90 naar 35 Hz over 0,35 s), en na het schot het geluid van de pomp, dat nu ontbreekt: dat is wat een pompgeweer een pompgeweer maakt. De pomp komt uit de bron van punt 2 en speelt 0,25 s na het schot. |
| 4 | Scherpschuttersgeweer (`marksman_shot`) | Opname: Mosin Nagant, maar afgekapt op 0,41 tot 0,45 s en hard geclipt (`punch` 8, `drive` 2) | Dat afkappen en clippen is de "demper". De take op afstand (`M_26P`) voluit als staart eronder, 1,5 tot 2 s lang, zonder lowpass op 400 Hz; `drive` eraf en `punch` terug naar 4 zodat de knal een knal blijft; een eigen galm op afstand door de staart 15 ms te laten voorlopen op de bus. Doel: binnen 30 dB van de piek tot 0,6 s in plaats van 0,2 s, en hoorbaar tot 1,5 s. |
| 5 | Granaat: pin, worp, stuiteren (`pin`, `throw`, `bounce`) | `pin` en `throw` gesynthetiseerd; `bounce` is sinds 9 oktober een opname van metaal op metaal | `pin`: een opname van een ring die lostrekt en een hendel die wegspringt (twee takes volstaan). `throw`: een zwiep van stof en arm, geen ruis. `bounce`: zwaar gietijzer op beton in plaats van blik op blik, luider bij een harde stuit en stil onder 1 m/s, en een korte rol erachteraan als hij blijft liggen. `scripts/grenade.gd` geeft de snelheid van de stuit door als volume. |
| 6 | Muziek in het hoofdmenu | Geen; de bus Music bestaat en is leeg | Zie hieronder. |

**Waar de opnames vandaan komen.** De vier pakketten die er zijn hebben geen hulzen, geen herlaadgeluiden en geen pin: van het vuurwapenpakket zijn alleen schoten uitgepakt, en de Kenney-pakketten zijn inslagen en explosies. Er is dus een bron bij nodig, CC0 zoals de rest, die als `packs` met adres en checksum in het manifest komt. Te zoeken, in deze volgorde: (a) of het volledige vuurwapenpakket van Still North Media ook mechaniek bevat, (b) CC0-pakketten met foley van wapens op OpenGameArt en Freesound, (c) zelf opnemen in `assets/recordings/`: een huls, een sleutelbos en een nietmachine komen een eind. Voor elk pakket eerst de naam, het adres en de grootte voorleggen, dan pas ophalen.

**Muziek in het hoofdmenu.**

- **Het nummer.** Eén nummer van twee tot drie minuten dat rond kan lopen. Zwaar en traag past bij de fabriek: lage synth, vervormde gitaar of beide, 90 tot 110 bpm. Het nummer komt later (Michiel, 10 oktober 2026); alles eromheen kan zonder worden gebouwd en met een proefnummer worden getest. Waar het vandaan kan komen: een bestaand CC0- of CC-BY-nummer (dan komt de maker in het manifest en op het titelscherm), een gegenereerd nummer (dan eerst de licentie van de dienst nalezen), of iets van onszelf.
- **Compressie van het bestand.** Ogg Vorbis, stereo, 44,1 kHz, kwaliteit 5 (ongeveer 160 kbit/s): 1,2 MB per minuut, dus 2,5 tot 3,5 MB voor het nummer, tegen 365 MB voor de download nu. Godot speelt Ogg als stroom van schijf af en houdt het niet uitgepakt in het geheugen, anders dan de WAV-takes van de schoten. Lager dan kwaliteit 4 gaat het hoog van bekkens en vervorming horen te ruisen; hoger dan 6 hoort niemand op een titelscherm. Het bronbestand (WAV of FLAC) blijft buiten git in `.cache/`.
- **Compressie van het geluid.** Het nummer wordt vooraf op luidheid gebracht, niet in het spel: -16 LUFS met de piek op -1 dB, zodat het onder de schoten blijft (een salvo zit op -6 LUFS) en de begrenzer op Master er niets aan hoeft te doen. Op de bus Music komt alleen een zachte compressor (2:1) voor het geval een nummer te veel dynamiek heeft. `tools/build_sounds.py` krijgt er een soort `music` bij die dit doet en het Ogg-bestand schrijft.
- **Afspelen.** `scripts/sfx.gd` krijgt `music(naam)` en `stop_music(seconden)`: één speler op de bus Music die doorloopt als het spel gepauzeerd is. Het menu start het nummer op het titelscherm, laat het doorlopen in Controls, Settings en Play together, en laat het in 1,5 s uitsterven zodra een level begint. Het nummer begint niet opnieuw bij terugkeer van Settings. Het lus-punt staat in de importinstelling, op een maat.
- **Instelling.** Een eigen schuif "Music" naast "Volume", die de bus Music regelt.
- **Later.** Dezelfde speler kan in een level zacht een tweede nummer draaien dat aanzwelt bij een gevecht; dat is een andere ronde.

**Volgorde.** Stap 0, dan 4 en 3 (alleen het manifest, geen nieuwe bron), dan de bron zoeken en 2, 1 en 5 in één keer, dan 6. Na elke stap `tools/hear.py` voor Michiel: hij oordeelt op het oor.

**Wat het kost.** Punt 3 en 4 zijn regels in het manifest en opnieuw bouwen. Punt 1, 2 en 5 zijn een nieuw pakket, zo'n 25 takes erbij (ongeveer 1,5 MB in `assets/audio/`) en code in `weapons.gd`, `weapon_data.gd`, `fx.gd` en `grenade.gd`. Punt 6 is één bestand van 3 MB, een functie in `sfx.gd`, een schuif en een keuze van Michiel.

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
- **Besturing.** Het titelscherm en het pauzemenu hebben een scherm Controls, met een knop die wisselt tussen muis, trackpad en controller. Voor de trackpad is er één toets bij gekomen: richten met Option (Alt), omdat een trackpad niet tegelijk een rechterklik kan vasthouden en klikken. Wapens wissel je daar met 1 tot 5, want scrollen met twee vingers is voor Godot geen muiswiel. Het scherm noemt C voor bukken en niet Ctrl: macOS maakt van een klik met Ctrl ingedrukt een rechterklik, dus gebukt vuren zou richten worden. Niet op een echte trackpad geprobeerd.
- **Instellingen**, bewaard in `user://settings.cfg`: kwaliteit (Low tot Ultra), upscaler, renderschaal, V-Sync, fullscreen, fps-teller, gezichtsveld, muis- en stickgevoeligheid, Y-as omkeren en volume. Een kwaliteitsniveau zet alleen effecten uit die het level zelf aan heeft staan.
- **Upscaling.** Bilinear, FSR 1, FSR 2 en op Apple-hardware MetalFX Spatial en Temporal.
- **Controller.** Linkerstick lopen, rechterstick kijken, RT vuren, LT richten, A springen, B bukken en sliden, X herladen, Y granaat, LB en RB wapen wisselen, linkerstick indrukken sprinten, Start pauze. Niet getest met een fysieke controller.
- **Checkpoints.** Een checkpoint is een plek op de route door het level, bewaard in `user://save.cfg`. Na een dood of een herstart van het spel ga je daar verder. Zie "Een route door de levels" onderaan.
- **Wapens.** SMG (toets 4) en Marksman met kijker (toets 5), naast rifle, pistol en shotgun. Bij elk schot loopt de slede of de grendel terug en vliegt de huls eruit; het pistool blijft open staan als het leeg is. De shotgun wordt na elk schot doorgeladen en patroon voor patroon herladen, wat je met een schot kunt afbreken. Een magazijnwissel is te zien: het wapen kantelt, het magazijn gaat eruit en het nieuwe erin. Gericht toont de Marksman het beeld door de kijker, met een dradenkruis.
- **Vijanden.** Naast de grunt een rusher (snel, zwak, slaat van dichtbij) en een heavy (traag, veel health, lange salvo's). Welke er waar staan, legt de route van het level vast. Ze staan er al als het level laadt, uitgeschakeld; 1,5 tot 4 seconden nadat hun gevecht is begonnen gaat elk op zoek naar de speler.
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

- Vaten komen niet terug: wat is opgeblazen, is weg tot je doodgaat of het level opnieuw begint. Na een herstart bij een checkpoint staan ze er allemaal weer, ook in het deel dat al is opgeruimd. Een checkpoint vult de granaten aan tot twee.
- Door een wrak loop je heen, en een schot gaat erdoor: het botst alleen met het level. Waar een vat stond, houdt het navmesh een gat.
- Vuur slaat niet over op kisten of pallets, en de klap van een explosie beweegt geen props: alles wat een lightmap heeft, staat vast.
- De granaat is in de hand niet te zien; alleen de arm die hem gooit beweegt.
- Een schot in een plas spat niet op: of een punt nat is, weet alleen de vloershader. Ramen hebben geen botsvorm, dus een schot gaat er zonder spoor doorheen.
- Een stelling heeft één doos als botsvorm; een schot tussen de planken door geeft daarom vonken in de lucht ervoor.
- De selftest meet "enemies approach" in echte tijd en faalde één keer op die stap toen de laptop zwaar belast was; drie herhalingen daarna slaagden.
- Geen instelbare toetsen en geen aim assist voor de controller.
- De HUD schaalt niet mee op hoge resoluties; de tekst is daar klein.

## Een route door de levels

Een level had geen begin en geen eind: waves verschenen op willekeurige punten en een checkpoint was een wavenummer. Nu loopt er door elk level een route. De speler begint op een vaste plek, vecht zich door een reeks zones en bereikt een uitgang. De fabriek eindigt bij de laaddeur in de westwand, daarna laadt het depot, en de uitgang van het depot sluit af met een eindscherm.

**Wat er staat**

- **De route staat in het levelbestand**, naast de geometrie (`_route_through` in `tools/levels/<naam>.gd`, of bij een level in meerdere bestanden in het bestand van elke zone): `route_start`, `route_zone`, `route_checkpoint` en `route_exit`, in de volgorde waarin de speler ze tegenkomt. De levelbouwer zet ze in de levelscène onder `Route` en `scripts/game.gd` speelt wat daar staat. Route en gebouw veranderen zo samen: wie een muur verzet, verzet in hetzelfde bestand het spawnpunt erachter. De bouwer weigert een route zonder start of uitgang, een start die in een zone ligt en een checkpoint dat in een latere zone ligt. De met de hand geplaatste spawnpunten in `scenes/factory.tscn` en `scenes/depot.tscn` zijn weg.
- **Zones.** De robots die een zone opsomt staan er vanaf het laden, elk op zijn eigen post, met het gezicht naar waar de speler vandaan komt. Ze staan uit: ze zien niets en bewegen niet. Het gevecht om een zone begint wanneer de speler de zone binnenloopt of op een van zijn robots schiet; dan gaan ze allemaal aan. De zone is opgeruimd als de laatste ligt. Er verschijnt dus niets meer uit het niets: wat je straks tegenkomt, zie je al staan. Ze staan uit omdat een robot die aan staat op de speler afgaat zodra hij hem ziet, tot op 45 m; in de hal zou dan elk gevecht tegelijk beginnen. Waar de speler het level begint of bij een checkpoint verdergaat, staat er geen dichterbij dan 14 m in het zicht: dezelfde afstand die de waves aanhielden.
- **Checkpoints.** Een checkpoint is een plek met een gebied eromheen. Het telt zodra de speler in dat gebied staat, er geen gevecht loopt en alle zones die ervoor liggen zijn opgeruimd. Na een dood of een herstart van het spel sta je er weer, met wat ervoor ligt opgeruimd, met 75 health en met de reserve en de granaten waarmee een level begint (zie Gevechten). De save bevat daarom alleen het level en de naam van het checkpoint: wat is opgeruimd, volgt uit waar het op de route ligt. Het begin van een level is het eerste checkpoint.
- **De uitgang** gaat open wanneer elke zone is opgeruimd. Boven de deur springt een groene lamp aan, die ook de mist kleurt, en een halve seconde later rolt de deur in ruim drie seconden omhoog. De laaddeur van de fabriek geeft uit op het voorterrein, met recht ertegenover de poort in de muur. Deur 3 van het depot geeft toegang tot een kale gang het magazijn in, verlicht van achteren. Het level eindigt een stap voorbij de deur: daar gaat het beeld op zwart en komt het volgende level op. De zones mogen in elke volgorde: wie in het depot de oostelijke oprit neemt, staat eerder op het perron, maar de deur blijft dicht tot ook het terrein is opgeruimd.
- **Een deur die beweegt** is een onderdeel van het level dat apart is gehouden (`roller_door` met `opens` in de levelbouwer). Het rolluik is dan een eigen lichaam met een eigen mesh en een eigen stukje lightmap, in plaats van deel van de ene grote mesh en het ene grote lichaam van het level; `scripts/game.gd` schuift het omhoog. Het hangt in een deuropening, in de dikte van de muur, en die muur onttrekt het aan het zicht als het omhoog gaat. In het depot hingen de roldeuren tegen de muur; alle vijf hangen nu in een deuropening, zodat deur 3 er niet anders uitziet dan de rest. De hal van de fabriek en het depot zijn daarvoor opnieuw gebakken (1:48 en 2:08); de lightmap van het depot is er 48,0 MB door geworden, van 45,7.
- **De fabriek** (16 robots): binnen door de buitendeur van het ketelhuis (twee grunts achter de ketel, een rusher die de gang uit komt rennen), door de gang met de knik het magazijn in en de gang van de aanbouw op (twee grunts uit de kleedkamer, een rusher uit de hal), de hal in (drie grunts en een rusher) en door naar het westelijke deel (drie grunts, twee rushers en een heavy voor de laaddeur). Checkpoints in de gang naar het ketelhuis, in de gang van de aanbouw en halverwege de hal.
- **Het depot** (15 robots): van de oostpoort het terrein op (drie grunts en een rusher), tussen de containerrijen door (drie grunts, twee rushers en een heavy), de westelijke oprit op en over het perron (twee grunts, een rusher en twee heavies) naar roldeur 3. Checkpoints waar de rijen beginnen en onderaan de oprit.
- **De weg vinden zonder uitleg.** Op de vloer van de fabriek wijzen pijlen in de verf van de belijning van de buitendeur van het ketelhuis door de gangen en het gangpad van de hal naar de laaddeur, in het depot over de zuidelijke rijbaan naar het westen en langs de muur naar de oprit (`floor_arrow` in de levelbouwer). Het licht doet de rest: de fabriek begint in het schemerige ketelhuis met recht vooruit de verlichte deur van de gang, en boven de uitgang brandt de lamp. Rechtsboven in de HUD, waar het wavenummer stond, staat wat er te doen is: `Reach the boiler house`, `Clear the boiler house · 3 left`, `Leave by the loading door`.
- **Het eindscherm** zegt hoeveel robots er onderweg zijn gesneuveld en biedt opnieuw spelen aan. Het titelscherm noemt bij "Continue" het level en het checkpoint.

**Wat de selftest ervan controleert**, voor elk level in de volgorde waarin ze gespeeld worden:

- dat de route van de start langs elk checkpoint naar de uitgang over het navmesh te lopen is en door elke zone komt;
- dat elke robot vanaf zijn post de speler kan bereiken, en dat er geen dichtbij en in het zicht staat waar de speler zijn zone binnenloopt, het level begint of bij een checkpoint verdergaat;
- dat de robots van een zone uitgeschakeld op hun post staan tot de speler de zone binnenloopt of, bij de laatste zone, tot er op een van hen wordt geschoten, en dat de zone is opgeruimd als ze liggen;
- dat een checkpoint een herstart van het spel overleeft (het bestand wordt opnieuw van schijf gelezen) en een dood, en dat wat ervoor ligt dan opgeruimd blijft, ook als je er weer doorheen loopt;
- dat de deur van de uitgang dicht is, omhoog rolt als elke zone is opgeruimd en dan de weg vrijgeeft, dat het volgende level bij zijn begin start en het laatste level het spel beëindigt.

`tools/selftest.sh --routes` zegt bij elke post ook of de speler hem al ziet staan vanaf waar hij een eerdere zone binnenloopt. Zo is één rusher in de hal verzet, die vanaf de deur van de aanbouw op 37 m in het zicht stond.

**Wat het kost.** Niets wat te meten is. Er is niets aan het beeld toegevoegd behalve verf op de vloer, en de grootste zone telt zes robots waar een volle wave er acht had. Gemeten op 9 oktober 2026 op 1440p met FSR 2 op 67%, de vorige commit ernaast gezet en om en om gemeten, vijf runs elk. De GPU werd op dat moment gedeeld met twee andere sessies, dus de runs liepen uiteen (losse standpunten zakten tot onder de 50 fps); hieronder staat per standpunt de beste van de vijf.

| Standpunt | Vorige commit | Met de route |
|---|---|---|
| Overview | 73,7 fps | 73,3 fps |
| Corridor | 72,2 fps | 73,3 fps |
| Platform | 70,1 fps | 70,0 fps |
| Hall | 75,7 fps | 75,4 fps |

De lamp boven de uitgang is een licht zonder schaduw. Met de laaddeur vol in beeld mat ik 77,8 fps zonder en 76,9 en 74,4 fps met de lamp: 1 tot 3 fps, in een meting die even onrustig was.

**Wat de robots op hun post kosten.** Niets wat te meten is, zolang ze roerloos staan. Gemeten op 9 oktober 2026 op 1440p met FSR 2 op 67%, vanaf het standpunt dat de hele hal van de fabriek overziet (Overview), vijf keer om en om met en zonder `--posted`, terwijl de laptop in gebruik was:

| | Gemiddeld | De vijf runs |
|---|---|---|
| Zonder robots | 72,3 fps | 73,2 · 73,7 · 73,1 · 71,5 · 70,2 |
| Alle robots roerloos op hun post | 72,0 fps | 69,8 · 73,2 · 72,7 · 71,2 · 73,2 |

Over alle standpunten van beide levels, drie ronden om en om, lag het verschil tussen −2,4 en +0,8 fps, in runs die onderling tot 6 fps uiteenliepen. Twee standpunten vielen daarbuiten. In de gang van de aanbouw mat ik −3,6 fps; vier keer om en om met alleen dat standpunt gaf 67,3 fps zonder en 68,0 fps met robots, dus dat was ruis. Op het terrein van het depot (Yard) haalde één run met robots 61,7 fps waar de andere twee 80,7 en 80,4 haalden, tegen 82,1 en 81,8 zonder.

**Onderweg opgelost**

- De physics-server meldde de speler een frame lang op de plek die hij in het scènebestand heeft, nadat hij al bij de start was neergezet. In de fabriek lag die plek in de hal, zodat de hal bij het laden meteen afging. Een stap van de route controleert nu zelf of de speler erin staat.
- Een robot die stilstaat, wiegt met zijn romp. Dat is duur: met alle robots wiegend op hun post haalde het standpunt Overview 67,2 fps, tegen 71,3 fps met de robots roerloos, vijf keer om en om en elke keer 2 tot 6 fps verschil. Ik vermoed dat elke lamp met schaduw waar zo'n robot onder staat daardoor elk frame zijn schaduwen opnieuw tekent; dat heb ik niet apart gemeten. Een robot die uit staat, staat daarom helemaal stil: zijn knoop staat op `PROCESS_MODE_DISABLED`, met `disable_mode` zo dat hij te raken blijft. Voor een robot die aan staat en even niets doet, geldt het nog.

**Nog open**

- Een robot die uit staat, komt alleen in actie als de speler zijn zone binnenloopt of op een robot van die zone schiet. Staat hij in het zicht terwijl er in de zone ernaast wordt gevochten, dan staat hij erbij. Vanaf waar je de containerrijen van het depot binnenloopt staat er zo één op het perron in het zicht, op 21 m; vanaf de deur van de aanbouw staat er in de hal geen robot van het westelijke deel meer in het zicht. Verderop in een zone kan dat anders zijn: de selftest kijkt alleen vanaf waar een zone wordt binnengelopen.
- Aan een robot is niet te zien dat hij uit staat: zijn vizier gloeit zoals altijd en hij staat in de houding waarin hij ook stilstaat als hij aan is. Een eigen houding en een gedoofd vizier horen bij het model, dus bij `scripts/enemy_rig.gd`.
- De zon is gebakken. Als de laaddeur omhoog gaat zie je het voorterrein in de avondzon, maar op de vloer van de hal valt geen zonlicht naar binnen.
- De deur heeft geen eigen geluid: bij de lamp en als hij boven is klinkt `clang`. Achter de laaddeur ligt een leeg voorterrein met twee containers; meer dan een seconde zie je er niet van.
- Wie doorrent, stapelt gevechten: elke zone waar je doorheen loopt gaat aan, en de robots lopen de speler het hele level door achterna.
- De route is niet met de hand gespeeld. De selftest loopt hem af en kijkt of alles klopt, maar of de gevechten goed voelen, weet ik niet.

## Een level dat kan groeien: zones

De marge is 10 fps op 1440p met FSR 2, en het spel gebruikt er 3 van. Een level kan dus niet groeien door er meer in beeld te zetten, wel door ruimtes achter hoeken en deuren. Dat werkte niet zolang alles altijd werd getekend: al het gebakken levelwerk was één mesh, er was geen occlusion culling, en de lightmap van de fabriek was één bestand van 53 MB dat met elke ruimte groter zou worden. De levelbouwer knipt een level daarom nu in zones.

**Wat er staat**

- **Zones in het levelbestand.** Een level somt bovenaan zijn zones op (`zone` in `tools/level_builder.gd`): een naam en de dozen die de zone vult. Welke andere zones je er vandaan kunt zien, stond er eerst met de hand bij; sinds 10 oktober 2026 rekent de bouwer dat zelf uit, zie "Grotere levels bouwen". Alles wat daarna gebouwd wordt, komt bij de zone waarin het staat: muren, props, lampen, decals, reflectieprobes, stof. Het levelbestand zelf hoefde daar nauwelijks voor te veranderen; alleen de vloer, die onder alles door liep, is per zone gelegd. Wat buiten elke zone valt (het terrein en de skyline) hoort bij geen en is er altijd. Een level zonder zones komt eruit zoals voorheen: de meshes van het depot zijn byte voor byte gelijk gebleven.
- **Alleen wat in het zicht is, wordt getekend** (`scripts/zones.gd`, dat de bouwer aan de levelscène hangt). Elk frame kijkt het in welke zone de camera staat en zet de inhoud van alle zones uit, behalve die zone en de zones die hij als zichtbaar opgeeft. Het werkt op de camera en niet op de speler, dus ook in de benchmark en achter het titelscherm. De schil van een zone die uit staat (zijn gebakken muren, vloer en dak) blijft schaduw werpen: anders scheen de zon door de deuropeningen de buurzone in. Een robot hoort bij geen zone, maar wie in een zone staat die uit is, staat achter dezelfde muren en wordt ook niet getekend.
- **Een lightmap per zone.** Elke zone heeft zijn eigen `LightmapGI` en zijn eigen bestand (`scenes/factory_<zone>.exr`). Een zone wordt gebakken met alleen zichzelf om zich heen, dus moet hij gesloten zijn met eigen muren, vloer en dak. De bake zet daarvoor zolang hij duurt een zwart paneel in elke deuropening (`bake_blocker`) en een kopie van de zon in de zone, want een bake kijkt alleen naar wat onder de ouder van zijn `LightmapGI` hangt. Wie een ruimte verandert, bakt alleen die ruimte.
- **De selftest zoekt zichtlijnen.** Vanaf elke plek waar de speler kan staan trekt hij lijnen naar punten door elke zone die daar uit staat (ruim een miljoen in de fabriek) en faalt bij de eerste die nergens op stuit. Zo kan een zone niet ongemerkt wegvallen terwijl je hem kunt zien. Ter controle heb ik de aanbouw de gang laten vergeten: 840 zichtlijnen en een falende test.
- **De fabriek in vier zones**: hal, aanbouw, gang en ketelhuis, op een rij. Hal en aanbouw zien elkaar door twee deuropeningen. De gang heeft een knik, zodat aanbouw en ketelhuis elkaar nooit zien, en de gang de hal niet. Wie in de hal staat, tekent dus hal en aanbouw, zoals voorheen; wie in het ketelhuis staat, alleen het ketelhuis en de gang.
- **Het ketelhuis** is de nieuwe ruimte: 12 bij 12 m en 7 m hoog, baksteen onder een betonnen dak, met de ramen op het noorden en oosten zodat de avondzon er niet in komt. Erin staan een vlampijpketel op zadels met brander, ventilator, manometers, peilglas, veiligheidskleppen, stoomleiding en rookkanaal door het dak (`boiler` in `tools/kit/plant.gd`), een voedingstank, twee pompen met hun leidingwerk (`pump`), een bord met meters (`gauge_board`) en de schakelkasten. Het licht komt van één hallamp, een tl-buis, een peertje in de hoek en het vuur. De gang ernaartoe is 2,4 m breed. Samen 35 duizend driehoeken gebakken levelwerk, tegen 60 duizend voor de hal.
- **De route begint nu in het ketelhuis**, bij een buitendeur die dicht is, en loopt door de gang het magazijn van de aanbouw in. Daarmee is hij een ruimte en een gevecht langer.

**Wat het kost**, gemeten op 9 oktober 2026 op 1440p met FSR 2 op 67%, terwijl de GPU gedeeld werd met twee andere sessies. De cijfers liggen daardoor een paar fps onder die van 8 oktober en losse runs lopen uiteen; ze zijn een indicatie. Wat wel te vertrouwen is, is het verschil tussen twee builds die om en om zijn gemeten.

De fabriek van vóór de zones tegen de fabriek met het ketelhuis erbij, vier ronden om en om, gemiddeld per standpunt:

| Standpunt | Vóór | Met zones en ketelhuis |
|---|---|---|
| Overview | 69,2 fps | 69,6 fps |
| Corridor | 69,9 fps | 69,4 fps |
| Platform | 67,2 fps | 66,5 fps |
| Hall | 71,0 fps | 71,4 fps |
| Boiler (nieuw) | | 72,1 fps |

Het level is een ruimte en een gang groter en de vier oude standpunten zijn binnen 0,7 fps gelijk gebleven. Het nieuwe standpunt, vanaf de start het ketelhuis in, haalt hetzelfde als de hal.

Wat het tekenen van alleen de zones in het zicht scheelt, vijf keer achter elkaar gemeten met de zones om en om aan en uit (mediaan):

| Standpunt | Tijd per frame met zones | Zonder |
|---|---|---|
| Boiler | 14,5 ms | 1,6 ms meer |
| Corridor | 15,1 ms | 0,8 ms meer |
| Platform | 16,0 ms | 0,4 ms meer |
| Overview en Hall | 15,0 ms | geen verschil |

In het ketelhuis is dat 7 fps: zonder zones werd daar de hele hal achter de muur meegetekend, 1156 tekenopdrachten en 2,5 miljoen driehoeken tegen 355 en 0,6 miljoen. Waar je van de nieuwe vleugel wegkijkt, scheelt het niets, want wat buiten beeld valt tekende de engine al niet.

- **Lightmaps**: hal 44,7 MB, ketelhuis 9,9 MB, aanbouw 8,4 MB, gang 1,0 MB. Het grootste bestand is kleiner dan het ene bestand van 53,2 MB dat er was, en een nieuwe ruimte voegt een bestand toe in plaats van het grote te laten groeien. Bakken duurt 1:50 voor de hal, 32 seconden voor het ketelhuis, 15 voor de aanbouw en 2 voor de gang.
- **Van zone wisselen** kost niets wat te meten is: met de camera van zone naar zone gesprongen is de traagste frame met zones even lang als zonder (40 tot 55 ms; ik vermoed dat het meeste daarvan de screenshot is die de benchmark tussen twee standpunten bewaart, maar dat heb ik niet apart gemeten). Eén ding kostte wel iets: de hal voor het eerst in beeld, halverwege het level, gaf een frame van 290 ms voor shaders en texturen. Het level tekent daarom de eerste vier frames alles, terwijl het beeld nog opkomt uit zwart; daarna is die frame 60 ms.
- **De zon in het ketelhuis**: in één meting 0,5 ms, voor schaduw die daar alleen de zon buiten houdt.

**Wat er aan de scène is veranderd**

- De stofdeeltjes stonden in `scenes/factory.tscn` op de maat van de hal. Ze staan nu in het levelbestand, per zone.
- De mistlengte van 48 m is gebleven: de langste zichtlijn in het level, uit het magazijn door twee deuren naar de westwand van de hal, is ruim 50 m, en verder dan de hal zelf kijkt niemand.
- De schaduwafstand van de zon van 70 m is gebleven. Korter in de kleine zones zou de halve milliseconde in het ketelhuis terugverdienen, maar wat je door een deur in de volgende zone ziet, staat dan voorbij de schaduw in de zon.
- `LightmapGI` staat niet meer in de scène maar in elke zone; kwaliteit, bounces en probes zet de levelbouwer.

**Onderweg gevonden**

- Een muur met een raam boven een deur metselde de deur dicht: de noordelijke doorgang van de hal naar de aanbouw was op een halve meter na dicht, onzichtbaar achter de pleisterwand van de aanbouw. `wall` kan nu openingen boven elkaar aan. De route gebruikt die doorgang.
- Een gang van 1,8 m is te smal zodra er iets in staat: met een brandblusser en een ton erin kwamen de robots er niet door. De selftest meldde dat de route niet te lopen was; de gang is nu 2,4 m en leeg.
- Een bake slaat nodes zonder eigenaar over. De kopie van de zon had er geen, en de eerste zone-bake had dus geen direct zonlicht.

**Nog open**

- De lightmap van de hal is met 44,7 MB nog altijd het grootste bestand. Kleiner kan alleen door de hal zelf te knippen, en die is één ruimte.
- Tussen zones wordt geen licht meer uitgewisseld in de bake: de gang van de aanbouw krijgt geen weerkaatst licht uit de hal. In de screenshots van vóór en na zie ik het verschil niet.
- De selftest kijkt of je *in* een zone kunt kijken, niet of je zijn buitenkant ziet. Vanaf de tussenvloer zou de dakrand van het ketelhuis door de bovenramen van de hal te zien kunnen zijn; die wordt daar niet getekend.
- Het depot is niet in zones geknipt: het is één terrein onder de open lucht.
- De ketel, de pompen en het leidingwerk zijn gebouwd in code, zoals de machines in de hal.

## Grotere levels bouwen

De fabriek is vier zones en zestien robots, en elke ruimte is met de hand in code geschreven. Een level van tien keer die omvang is zo niet te maken. Op 10 oktober 2026 is daarom afgesproken hoe levels veel groter kunnen worden zonder dat de graphics inleveren, in vijf stappen. De eerste is gezet.

**Waar het op vastliep**

- **Elke ruimte was handwerk.** De fabriek was één bestand van 1720 regels; het ketelhuis alleen kostte er ruim 250.
- **De mooiste bouwstenen zaten opgesloten in de fabriek.** Pers, draaibank, tank, ketel, pomp, deuren, kraan en het leidingwerk van de gang stonden in het levelbestand en niet in de gedeelde bouwer. De showroom moest de hele fabriek uitbreiden om ze te kunnen laten zien.
- **Alles laadt in één keer.** Een level is één scène met alle lightmaps, en het navmesh wordt bij het laden berekend. Laadtijd en geheugen groeien mee met het level.
- **Lightmaps zijn groot.** De fabriek is 64 MB over vier zones. Vijf keer zoveel level is naar schatting 300 MB en een kwartier bakken, en `.git` is nu al 1,0 GB.
- **Welke zones elkaar zien, staat er met de hand in.** Bij vier zones gaat dat, bij twintig niet.
- **De framerate is niet het probleem**, zolang een level groeit achter hoeken en deuren: zie de zones hierboven.

**De stappen**

| Stap | Wat | Waaraan je ziet dat het klaar is | Status |
|---|---|---|---|
| 1. Bouwdoos | De bouwstenen uit de fabriek naar een gedeelde bibliotheek, en een level in één bestand per zone met vaste deurposities | De fabriek komt er byte voor byte gelijk uit | Klaar, zie hieronder |
| 2. Automatisch wat nu handwerk is | Zichtlijnen tussen zones uitrekenen bij het bouwen, alleen gewijzigde zones opnieuw bakken, en zones die elkaars toeval niet verschuiven | Na een wijziging in één ruimte zijn bouwen en bakken in minder dan een minuut klaar | Klaar, op de hal na. Zie hieronder |
| 3. Streamen | Zones op de achtergrond laden en loslaten langs de route; grote kale vlakken krijgen een grovere lightmap | Vijf fabrieken achter elkaar als proeflevel: 60 fps, en het geheugen blijft vlak | Klaar zonder streamen: het proeflevel haalt het zo. Zie hieronder |
| 4. Ruimtes uit een plattegrond | Een level begint als lijst van ruimtes met een type (hal, gang, kantoor, opslag, terrein) en deuren. De bouwer maakt daar schil, zones, lampen, probes, vuil en rommel van volgens regels; de blikvangers komen er met de hand in | Een nieuwe vleugel van vijf ruimtes staat in één sessie speelbaar in greybox | Klaar: de vleugel is gebouwd, gebakken en bekeken. Gespeeld is hij nog niet. Zie hieronder |
| 5. Het eerste grote level | Ongeveer 20 zones en 80 vijanden, 15 tot 20 minuten spelen | De route is te lopen en elke zone haalt het budget | Gebouwd, gebakken en gemeten: het fabrieksterrein, 23 ruimtes en 59 robots. Twee keer kort gespeeld, in een build die de renderschaal van de hoofdbranch nog mist. Zie hieronder |

**Wat is afgesproken**

- **Groter betekent een langere route door veel ruimtes**, met af en toe een ommuurd buitenterrein. Een open wereld past niet binnen de marge van 10 fps op deze laptop.
- **De fabriek is het proefterrein** voor stap 1 tot 3; het grote level wordt nieuw gebouwd.
- **Lightmaps gaan uit git**, naar Git LFS. Dat is op 10 oktober 2026 gedaan: `git-lfs` 3.8.0 via Homebrew, alleen voor deze repository aangezet (`git lfs install --local`). De `.exr` en `.lmbake` in `scenes/` staan vanaf die commit als verwijzing in de geschiedenis; wat ervoor ligt is niet herschreven. Een verse checkout krijgt de echte bestanden. Er is nog niets naar GitHub gepusht; hoeveel LFS-opslag daar beschikbaar is, is niet nagekeken.

**Hoe de graphics op niveau blijven**, vanaf stap 2:

- Een keurmerk per zone, automatisch gecontroleerd: de framerate vanaf de ingang van de zone, het aantal tekenopdrachten en driehoeken, of er een reflectieprobe en een lichtbron hangt, en geen groot kaal vlak zonder decal of rand.
- Een contactblad per zone, zoals bij de personages: twintig zones beoordelen op één pagina in plaats van ze af te lopen.
- Eerst greybox en spelen, dan aankleden, dan bakken, zodat er geen baktijd naar een ruimte gaat die nog verschuift.
- Meer variatie in assets: met 45 modellen gaat een groot level zich herhalen.

### Stap 1: de bouwdoos

**Wat er staat**

- **De bouwdoos** (`tools/kit.gd` en `tools/kit/`): alles wat in code is opgebouwd en in elk level kan staan. `tank`, `press`, `lathe`, `workbench` en `crane` in `machines.gd`, `boiler`, `pump` en `gauge_board` in `plant.gd`, `doorway`, `corridor_services` en `notice_board` in `fittings.gd`, en de onderdelen waar machines van gemaakt zijn (balken, flenzen, bouten, handwielen, motoren, meters) in `parts.gd`. Een level breidt `tools/kit.gd` uit in plaats van de levelbouwer. GDScript kan één script niet uit meerdere bestanden samenstellen, dus de laden zijn een ketting: elk breidt het vorige uit.
- **Een bouwsteen weet niets meer van de fabriek.** Wat hij van zijn omgeving moet weten, krijgt hij mee: de ketel de muur waar de stoomleiding heen gaat en de hoogte van het dak, de werkbank de muur waar hij tegenaan staat, de tank de leiding waarop hij aansluit, de kraan de maten van de hal (het aantal verstijvingen volgt de overspanning), het leidingwerk van de gang waar kanaal, kabelladder, roosters en schakelaars zitten.
- **Een level in meerdere bestanden.** `tools/levels/factory/plan.gd` heeft de maten, de zones en de deuropeningen ertussen (`HALL_DOORWAYS`, `PASSAGE_DOORWAY`, `BOILER_DOORWAY`): de muur aan de ene kant en de muur aan de andere kant halen de opening daar vandaan. Elke zone heeft een eigen bestand dat het plan uitbreidt (`hall.gd`, `annex.gd`, `passage.gd`, `boiler.gd`, en `outside.gd` voor wat eromheen ligt), met wat erin staat: schil, inrichting, probes, vuil, vloerverf en zijn stuk van de route. De rommel van hal en aanbouw staat in één bestand, `clutter.gd`; waarom staat onder "Onderweg gevonden". `tools/levels/factory.gd` is nog 21 regels: het plan, de volgorde waarin de zones gebouwd worden en de volgorde van de route. Twee sessies kunnen zo elk aan een eigen zone werken zonder hetzelfde bestand aan te raken.
- **Hoe dat werkt.** De levelbouwer is geen `SceneTree` meer: `tools/build.gd` start hem, voor levels en modellen. Daardoor kan een level andere bestanden hun deel laten bouwen (`build` in `tools/level_builder.gd`): elk is een eigen bouwer, die van het level overneemt wat er al staat en het daarna teruggeeft.
- **De showroom** breidt de bouwdoos uit en niet meer de fabriek, en laat nu ook de pompen, het metersbord, de ketel, de werkbank, een deur en het prikbord zien. Dat ze er staan is het bewijs dat ze buiten de fabriek te gebruiken zijn.
- **`tools/build_check.py`** bouwt alle levels en modellen opnieuw en zegt wat er anders uitkomt dan wat er in git staat. Meshes vergelijkt het byte voor byte, scènes op wat erin staat: de nummers die Godot bij elke keer opslaan opnieuw uitdeelt tellen niet mee. Dezelfde botsvormen in een andere volgorde tellen wel als wijziging, en dat staat er dan bij. Wat gelijk is gebleven zet het terug, zodat `git status` alleen laat zien wat echt veranderd is. Het duurt twaalf seconden.

**Gecontroleerd**

- De fabriek, het depot en de modellen komen er gelijk uit. De 45 bestanden met de meshes en de vloerverf van de twee levels zijn byte voor byte gelijk gebleven, en de scène van de fabriek is op de nummers van Godot na regel voor regel dezelfde tekst. De lightmaps zijn dus niet opnieuw gebakken, en het spel draait op precies de bestanden van vóór deze stap.
- De showroom is het enige wat veranderd is, door wat erbij is gezet. Dat is bekeken in vier screenshots.
- `tools/selftest.sh` slaagt.

**Onderweg gevonden**

- **Eén vuilniszak in het ketelhuis verandert het gevecht in de hal.** In de eerste opzet bouwde elke zone zijn eigen rommel. De botsvormen van het level kwamen daardoor in een andere volgorde in de scène, en de selftest faalde op "de meeste vechten vanuit dekking": van vijf grunts vochten er na twaalf seconden twee vanuit dekking in plaats van vijf, en ze zochten 55 tot 58 keer naar dekking in plaats van 9 tot 11 keer. Drie keer om en om gemeten, elke keer hetzelfde. Het navmesh was in beide gevallen hetzelfde, veelhoek voor veelhoek; de plekken met dekking die de verkenning van `scripts/squad.gd` vindt niet. Daarna heb ik het zonder de nieuwe opzet geprobeerd: één vuilniszak erbij in het ketelhuis, ruim dertig meter van het gevecht en twee zones verder, gaf dezelfde twee van de vijf. Het ligt dus niet aan de knip in bestanden: elke botsvorm die er in een level bij komt, kan dit doen. Mijn vermoeden is dat de physics-engine met een andere lijst vormen elke straal een fractie anders laat uitkomen, en dat de verkenning daar een andere plek van maakt waar twee richtingen even dichtbij zijn; dat heb ik niet nagegaan.
- Daarom staat de rommel van hal en aanbouw in één bestand, in de volgorde van voorheen: zo blijft de scène dezelfde en het gevecht ook. Wat er vanaf nu in een zone bij komt, kan gewoon in het bestand van die zone.

**Werkwijze**

| Stap | Hoe |
|---|---|
| Een zone aan een level toevoegen | De zone en zijn deuropening in `tools/levels/<level>/plan.gd`, een bestand `tools/levels/<level>/<zone>.gd` dat het plan uitbreidt en `_describe` en `_route_through` heeft, en de naam in de twee lijsten in `tools/levels/<level>.gd` |
| Een bouwsteen voor elk level maken | In de la van `tools/kit/` waar hij hoort, zonder iets van een level erin, en erbij in `tools/levels/showroom.gd` |
| Nagaan dat een wijziging aan de bouwer of de bouwdoos verder niets heeft veranderd | `tools/build_check.py` |
| Een level zone voor zone bekijken en horen wat elke zone kost en mist | `tools/zone_sheet.py factory`, of met `--check` zonder beelden; `--posted` zet de robots op hun post |
| Bakken wat er na een wijziging gebakken moet worden | `tools/bake_lightmaps.sh`, zie stap 2 |
| Meten wat een level kost om te laden en vast te houden | `tools/level_cost.sh factory` |
| Een proeflevel maken van vijf kopieën van een level, om aan te meten | `tools/proof_level.sh`, dan `tools/zone_sheet.py proof` of `tools/level_cost.sh proof` |

**Nog open**

- Of de robots dekking vinden hangt af van iets wat bij elke wijziging aan een level verschuift, zie hierboven. Dat moet robuust zijn vóór stap 2: daar verandert het navmesh, en in stap 5 komt er elke dag iets bij. Tot dan zegt een falende gevechtstest na een levelwijziging niets over die wijziging.
- De volgorde in `tools/levels/factory.gd` ligt vast: de zones van de fabriek delen de reeksen willekeurige getallen waarmee kratten gedraaid en ruiten weggelaten worden. Een zone ertussen zetten verschuift die in de zones erna, en dan moeten die opnieuw gebakken worden. Sinds stap 2 heeft elk bestand van een level zijn eigen reeksen; de fabriek doet het nog op de oude manier, zie daar.
- De werkbank, het leidingwerk van de gang, het prikbord en de kraan kunnen maar in één richting staan. Een ruimte met een eigen assenstelsel, waarin alles gebouwd wordt, hoort bij stap 4.
- De kraan staat niet in de showroom: hij heeft een hal nodig om te overspannen.
- Het depot is één bestand gebleven: het is één ruimte.
- De deuropeningen staan in het plan als getallen; de lateien en de panelen die een opening tijdens het bakken afsluiten zijn daar nog met de hand van afgeleid.

### Stap 2: automatisch wat handwerk was

**Wat er staat**

- **De bouwer rekent uit welke zones elkaar zien** (`_find_sightlines` in `tools/level_builder.gd`). Hij zet de botsvormen van het level in een wereld, bakt er een navmesh van zoals het spel dat doet, en kijkt vanaf waar iemand kan staan, staand en gebukt, naar punten door elke andere zone. Eén lijn die nergens op stuit en de twee zones worden samen getekend. Ramen tellen als gaten. Voor de fabriek vindt hij precies wat er met de hand stond: hal en aanbouw, aanbouw en gang, gang en ketelhuis. De lijsten zijn uit het plan van de fabriek gehaald en de scène is dezelfde gebleven. `zone` neemt nog wel namen aan van zones die er hoe dan ook bij getekend moeten worden. De selftest zoekt in het draaiende spel nog steeds naar dezelfde lijnen en faalt op de eerste; dat is nu de controle op de bouwer.
- **Lukt het uitrekenen niet, dan wordt er niets weggeschreven.** Een level waarvan de zones niet weten wat ze zien, laat ruimtes wegvallen terwijl je ernaar kijkt. Dat gebeurde twee keer tijdens het bouwen hiervan, zonder foutmelding die de bouw stopte.
- **`tools/bake_lightmaps.sh` bakt alleen wat veranderd is.** Van alles waar de bake van een zone naar kijkt wordt een handtekening gemaakt: de gebakken meshes van de zone (de bestanden zelf), de lampen, de geplaatste modellen, de panelen die de deuropeningen afsluiten, de instellingen van de bake, en uit de gespeelde scène de zon en de lucht. De handtekening waarmee een zone het laatst gebakken is staat in `scenes/<level>_bakes.json`, naast de lightmaps. Zonder argument bakt het script de zones waarvan de handtekening niet meer klopt; `--list` zegt alleen welke dat zijn, `--all` bakt alles, een naam bakt die zone, `--mark` neemt de lightmaps die er liggen voor geldig aan. Het depot, dat één lightmap heeft, telt als één geheel.
- **Elk bestand van een level heeft zijn eigen toeval** (`_shared_dice` en `_seed_dice` in de levelbouwer). De kratten, de vaten en de ontbrekende ruiten van een zone hangen dan niet meer af van wat er in de zones ervoor is gebouwd, en hun lightmap dus ook niet. De fabriek deelt zijn reeksen nog, zoals hij gebouwd en gebakken is.

- **Een contactblad en een keurmerk per zone** (`tools/zone_sheet.py`). De bouwer kiest per zone zelf een paar standpunten waar de speler kan komen, ver uit elkaar, meer in een grote zone, en kijkt vanaf elk de kant op waar de meeste vloer te zien is (`_find_views`); ze staan in de levelscène op de zone. Het script laat de benchmark vanaf elk een beeld maken op de instelling van het budget, 1440p met FSR 2 op 67%, en plakt ze op één blad met eronder wat dat standpunt kost. Een level zonder zones, zoals het depot, wordt bekeken waar er gevochten wordt. Per zone zegt het script of er een reflectieprobe hangt, een lamp brandt, een decal ligt en de lightmap nog klopt, en per standpunt of het binnen 2000 tekenopdrachten en 4 miljoen driehoeken blijft en 60 fps haalt. Met `--check` doet het alleen wat zonder GPU kan.

**Gemeten** op 10 oktober 2026

| | |
|---|---|
| Het contactblad van de fabriek: tien beelden, het blad en de tabel | 37 s |
| De fabriek bouwen | 5,0 s, waarvan 2,1 s voor 1,2 miljoen zichtlijnen; het was 2,8 s |
| Alle levels en modellen bouwen en vergelijken (`tools/build_check.py`) | 14 s; het was 12 s |
| De gang bakken, van commando tot klaar | 16 s, waarvan 2,4 s de bake zelf en de rest het starten van de editor |
| Aanbouw, ketelhuis en hal bakken | de bake zelf is 15 s, 32 s en 1:50 (gemeten op 9 oktober); met de 13 s van de editor erbij naar schatting 30 s, 45 s en 2 minuten |

- **Wat een zone als veranderd telt.** Een tl-buis in de gang tien centimeter verplaatst: alleen de gang. Een vlek op de vloer van de aanbouw groter gemaakt (een decal): niets. Dikkere mist in `scenes/factory.tscn`: niets. Een fellere zon: alle vier.
- **Twee bakes achter elkaar zijn byte voor byte gelijk.** De gang opnieuw gebakken geeft een bestand dat 33 bytes korter is dan het gecommitte, maar gedecodeerd is het beeld hetzelfde: geen texel verschilt. De lightmap die er lag was dus nog geldig, en hij is teruggezet. Voor de andere zones en het depot is dat aangenomen en niet nagebakken.
- **Zones met eigen toeval staan los van elkaar.** Met de fabriek als proef op eigen reeksen gezet en een stapel kratten bijgezet in de hal: alleen de gebakken mesh van de hal verandert, die van aanbouw, gang en ketelhuis blijven byte voor byte gelijk.

**Wat het eerste blad liet zien**

| Standpunt | Tekenopdrachten | Driehoeken | Fps in drie runs |
|---|---|---|---|
| Hal, vier standpunten | 454 tot 909 | 1,2 tot 2,4 miljoen | 66 tot 75 |
| Aanbouw 1: uit de kleedkamer, door de gang, de hal in | 1647 | 3,2 miljoen | 73, 75, 76 |
| Aanbouw 2: de gang | 474 | 0,8 miljoen | 69, 58, 75 |
| Gang 1: naar de deur van het magazijn | 1311 | 3,2 miljoen | 73, 72, 73 |
| Gang 2 | 515 | 0,9 miljoen | 78, 76, 79 |
| Ketelhuis 1: achter de ketel | 661 | 0,9 miljoen | 79, 81, 81 |
| Ketelhuis 2: vanaf de deur van de gang | 820 | 1,5 miljoen | 71, 65, 75 |

- Tekenopdrachten en driehoeken komen in alle drie de runs tot op de driehoek gelijk uit. De framerate niet: de gang van de aanbouw gaf 69, 58 en 75 fps, met een 1% low van 20 in de middelste run, terwijl de laptop in gebruik was. Een standpunt dat onder de 60 uitkomt wordt daarom één keer opnieuw gemeten en de beste van de twee telt.
- De zwaarste beelden zijn niet de grootste ruimte maar de doorkijkjes: uit de kleedkamer en uit de gang kijk je door een deur een volgende zone in, en die wordt dan helemaal getekend. Ze halen ruim 70 fps. De grenzen van het keurmerk liggen een marge boven dat zwaarste beeld; de fabriek is de maat.
- Wat er op het oog opvalt, en waar het blad voor is: de kleedkamer is bijna zwart (de tl-buis daar is uit), de gang naar het ketelhuis is kaal, en achter de ketel is het donker.
- Het depot: vier standpunten, 359 tot 447 tekenopdrachten, 0,8 tot 1,0 miljoen driehoeken, 67 tot 81 fps.

**Afwijking van het plan: het navmesh wordt niet vooraf gebakken.** Het bakken bij het laden duurt 65 tot 69 ms voor de fabriek en 116 tot 126 ms voor het depot. Een level van vijf keer die omvang is dan een halve seconde, achter een zwart beeld. Daar staat geen bestand per zone en geen wijziging aan het spel tegenover. De bouwer bakt er wel een, om te weten waar iemand kan staan, en gooit hem weer weg.

**Onderweg gevonden**

- **Een verse worktree hoeft niet zes minuten te importeren.** De editor importeerde in een nieuwe worktree alles opnieuw, ook met een gekopieerde `.godot`, omdat de uitgecheckte bestanden een nieuwe wijzigingstijd hebben. Wie elk bestand dat gelijk is aan dat in de hoofdmap de tijd van dat bestand geeft (`touch -r`), is in 9 seconden klaar.
- `Engine.get_main_loop()` is leeg zolang de bouwer in de constructor van de `SceneTree` draait, en de root staat pas vanaf het eerste frame in de boom. `tools/build.gd` wacht daarom één frame.

**Nog open**

- **De hal haalt de minuut niet**: zijn bake duurt 1:50. Dat is één ruimte met een lightmap van 44,7 MB; korter kan alleen met een grovere lightmap op de grote kale vlakken, en dat is stap 3.
- **De zichtlijnen groeien met het kwadraat van het aantal zones.** De fabriek kost 2,1 s voor zes paren die elkaar niet zien. Twintig zones zijn er ruim driehonderd, naar schatting twee minuten per bouw. Paren die elkaar wel zien zijn snel klaar: de eerste lijn is genoeg. Wat helpt: een uitkomst "ziet elkaar niet" blijft geldig zolang er alleen botsvormen bij komen, dus alleen na het weghalen of verplaatsen van iets hoeft alles opnieuw. Dat is nog niet gebouwd.
- **De fabriek staat nog op gedeeld toeval.** Hem omzetten verlegt elke krat en vraagt een bake van alle vier de zones. Dat wacht tot het dekkingzoeken tegen zulke wijzigingen kan (zie stap 1).
- Een handtekening ziet geen gewijzigd materiaal, geen gewijzigde textuur en geen opnieuw geïmporteerd model. Daarna: `tools/bake_lightmaps.sh --all`.
- Het keurmerk kijkt niet naar grote kale vlakken: het telt alleen of er in een zone een decal ligt. De gang van de fabriek heeft er twee en is toch kaal, zoals op het blad te zien is.
- De standpunten staan in de hoeken van een zone, en dat is niet altijd waar de speler binnenkomt. Het uitzicht vanaf de deur waar de route een zone binnenkomt ontbreekt nog.

### Stap 3: gemeten in plaats van gestreamd

Het plan was zones te gaan streamen: op de achtergrond laden en weer loslaten. Voordat daar iets voor gebouwd is, is gemeten wat een level van vijf fabrieken kost. Het haalt de framerate en het geheugen zonder streamen. Wat er wel te halen viel, lag ergens anders.

**Wat er staat**

- **`tools/level_cost.sh [level]`** laadt een level in een lege scène en zegt hoe lang dat duurt en wat het aan geheugen bijzet, met de lightmaps één voor één.
- **`tools/proof_level.sh [level] [kopieën]`** maakt van een gebouwd en gebakken level een proeflevel: de fabriek vijf keer, als één level van twintig zones en tachtig robots. De kopieën staan 300 m uit elkaar, te ver om elkaar te zien of te beschaduwen, en delen hun meshes en lightmaps met de eerste. De twee scènes die het schrijft staan niet in git.
- **Het levelbestand is dertig keer kleiner.** De bouwer plaatste modellen zonder Godot te vertellen hoe ze oorspronkelijk waren. Van elk model waarvan hij daarna iets binnenin veranderde, om het door de probes te laten belichten, werd de hele mesh in het level opgeslagen: 46 meshes, 7,4 van de 7,7 MB van de fabriek. Geplaatst zoals de editor het doet (`GEN_EDIT_STATE_INSTANCE` in `prop`) wordt alleen opgeslagen wat het level veranderde.
- **Wat in een uitgeschakelde zone beweegt, wordt niet meer getekend.** Het rolluik van een uitgang hangt bij de schil van zijn zone, en die schil blijft staan om schaduw te werpen. Het rolluik zelf bleef daarbij gewoon zichtbaar. `scripts/zones.gd` laat het nu, net als de schil, alleen nog schaduw werpen.

**Gemeten** op 10 oktober 2026, terwijl de laptop in gebruik was

| | De fabriek | Het proeflevel: vijf fabrieken |
|---|---|---|
| Zones, nodes | 4, 1317 | 20, 6510 |
| Het levelbestand | 0,25 MB, gelezen in 46 ms | 1,12 MB, gelezen in 196 ms |
| Het level laden zonder beeld, alles | 0,25 tot 0,47 s | 0,40 tot 0,67 s |
| Navmesh bakken bij het laden | 66 tot 73 ms, 612 veelhoeken | 375 ms, 3068 veelhoeken |
| Texturen op de videokaart | 870 MB | 870 MB |
| Meshes en andere buffers | 66 MB | 71 MB |
| Geheugen van de engine zelf | 57 MB | 76 MB |
| Lightmaps op de videokaart | 25 MB (hal 16, aanbouw 4, ketelhuis 4, gang 1) | dezelfde 25 MB, gedeeld; eigen lightmaps zouden 125 MB zijn |
| De tien standpunten van de fabriek | 454 tot 1647 tekenopdrachten | in kopie 1 tot op de driehoek hetzelfde, alle tien |
| Framerate in die standpunten, 1440p met FSR 2 op 67% | 68 tot 81 fps | 68 tot 80 fps |
| Met de robots op hun post (16 en 80), mediaan | 73,5 fps | 74,3 fps |

- **Het geheugen zit in wat elk level deelt.** De 870 MB aan texturen zijn die van de materialen en de modellen, en die groeien niet mee met het level. Per fabriek aan nieuwe ruimtes komt er 25 MB aan lightmaps bij, plus de eigen meshes. Het proeflevel deelt zijn meshes en lightmaps, dus een echt level van die omvang ligt hoger dan wat hier gemeten is: 100 MB aan lightmaps erbij en hooguit 260 MB aan meshes (vier keer alle buffers die de fabriek nu heeft), op een totaal van ruim 1 GB.
- **Het laden van een level groeit met zijn omvang, maar het is weinig.** Het bestand en het navmesh van het proeflevel kosten samen 0,6 s. Dat de fabriek eerst 1,4 s nodig had, kwam door de meshkopieën: 1,2 s daarvan was het lezen van die tekst. De fabriek laadt nu in een kwart tot een halve seconde, en het depot in 0,05 tot 0,07 s in plaats van 0,6 tot 0,7.
- **Wat een beeld kost, hangt niet af van hoeveel zones er zijn.** In elk van de tien standpunten tekent het level van twintig zones precies evenveel als de fabriek alleen.
- **De lightmaps zijn op schijf groot en op de videokaart klein.** De hal is 44,7 MB als `.exr` en 16 MB gecomprimeerd in het geheugen.

**Afwijkingen van het plan**

- **Er wordt niet gestreamd.** Het zou geheugen en laadtijd besparen die er niet zijn, en het raakt alles wat nu van het hele level uitgaat: het navmesh, de verkenning van dekking, de robots op hun post.
- **De grote vlakken hebben geen grovere lightmap gekregen.** Dat scheelt naar schatting een vijfde van de baktijd en de bestandsgrootte van de hal, en vraagt een bake van alles en een oordeel op het oog. Met LFS is de bestandsgrootte geen probleem meer; de 1:50 van de hal blijft staan.

**Onderweg gevonden**

- **De zon tekent mee wat binnen bereik van zijn schaduw staat.** Met de kopieën eerst 130 m uit elkaar kostten twee standpunten 25 en 38 tekenopdrachten en 60 duizend driehoeken meer dan in de fabriek alleen: de schil van de hal van de buurkopie, één keer getekend voor de schaduw. Dat is in een echt level ook zo: elke schil binnen het bereik van de zonneschaduw (70 m) telt mee, of zijn zone nu aan staat of niet.
- **De getallen op een zone worden gedeeld door elke kopie van de scène.** De standpunten van de kopieën stonden eerst allemaal 1300 m verderop, de som van alle verschuivingen: het aanpassen van de ene kopie paste ze allemaal aan.
- **Meten terwijl er gespeeld wordt, halveert de cijfers.** Eén run van het contactblad gaf 32 tot 37 fps in elk standpunt, ook in een lege gang. Het script zegt het nu als zelfs het lichtste standpunt tekortschiet. Tekenopdrachten en driehoeken hebben daar geen last van.
- Door het rolluik staan er in het blad van de fabriek sindsdien vijf tekenopdrachten minder bij de twee standpunten waar het in beeld viel terwijl de hal uit stond: gang 2 (510) en ketelhuis 1 (656).

**Nog open**

- Het proeflevel is gekopieerd en niet gebouwd: wat de bouwer zelf aan twintig zones kost (de zichtlijnen, zie stap 2) is er niet mee gemeten, en evenmin een level waarin de zones aan elkaar grenzen.
- De 870 MB aan texturen is het grootste wat een level in het geheugen heeft. Dat is geen vraag van levelgrootte, maar wel de eerste plek om te kijken als het geheugen ooit krap wordt.

### Stap 4: ruimtes uit een plattegrond

**Wat er staat**

- **Een level als plattegrond** (`tools/kit/rooms.gd`, de vijfde la van de bouwdoos). Het plan van een level noemt zijn ruimtes: een rechthoek op de grond, een soort en een hoogte. Daarna de deuren ertussen, de ramen, wat vrij moet blijven voor wat er met de hand in komt, en de route: `room`, `door`, `window`, `keep_clear`, `start_in`, `fight`, `checkpoint_in` en `exit_through`. De rechthoek is de ruimte met zijn muren, dus twee ruimtes die een muur delen hebben rechthoeken die elkaar raken.
- **Wat de bouwer daarvan maakt** (`build_rooms`). Per ruimte een eigen zone, gesloten door eigen vloer, muren en plafond; de deuropeningen en ramen uitgespaard, met in elke deuropening het paneel dat hem tijdens het bakken afsluit; lampen naar de soort ruimte (tl-buizen onder een laag plafond, hallampen onder een hoog), waarvan de meeste nog branden; een reflectieprobe. En tenzij het level kaal is (`_bare`): deuren in de deuropeningen, vuil langs de plinten, lekstrepen onder de ramen, vlekken op de vloer, en wat er in zo'n ruimte rondstaat. Een magazijn krijgt stellingen langs de muren en kisten, pallets en zakken ertussen; een kantoor een bureau, een stoel, een kast en dozen; een gang brandblussers en leidingen; een werkhal iets tegen de muur om de paar meter en dekking op de vloer. Dat blijft uit de buurt van de deuren, van waar de robots staan en van wat het plan vrijhoudt.
- **Vijf soorten ruimte**: `hall`, `plant`, `corridor`, `office` en `storage` (`ROOM_KINDS`). Een soort legt het materiaal van muren en plafond vast, de dikte van de muren, welke lampen er hangen en hoe ver uit elkaar, en wat er rondstaat.
- **De robots krijgen hun post van de bouwer.** `fight` zet er een per soort neer, zo ver van de deur waar de speler binnenkomt als de vloer toelaat, een paar passen uit elkaar.
- **Wat een ruimte tot díé ruimte maakt, komt er met de hand in**, in een bestand per ruimte, met `spot_in` voor een plek gerekend vanaf de noordwesthoek van de ruimte. De ruimte verhuizen in het plan verhuist dan ook wat erin staat.
- **Elke ruimte heeft zijn eigen toeval**, zodat een wijziging in de ene de lampen en kisten van de andere laat staan, en hun lightmap ook.
- **De bouwer controleert of de route te lopen is** (`_check_walkable`). Een robot of een checkpoint op een plek die vanaf de start niet te bereiken is, geeft een fout bij het bouwen. Dat geldt voor elk level; de fabriek en het depot komen erdoor.
- **`tools/level_map.py [level]`** tekent een level van bovenaf zoals het gebouwd is: wat er op de vloer staat (zwart wat hoger is dan een mens, grijs waar een robot overheen schiet), de zones, de robots op hun post, de start en de uitgang. Zonder GPU.
- **De vleugel** (`tools/levels/wing.gd`, `scenes/wing.tscn`): een lobby en een magazijn aan de westkant van een gang, een werkplaats en een ketelruimte aan de oostkant, en een laaddeur in de oostwand van de werkplaats als uitgang. In de werkplaats staan een draaibank, een pers en een tank met de hand; in de ketelruimte de ketel, twee pompen en het metersbord. Elf robots in vier gevechten, met een checkpoint in het magazijn.

**Gemeten** op 10 oktober 2026

| | |
|---|---|
| De vleugel, vijf ruimtes met machines en route | 137 regels in vijf bestanden; de fabriek was 1720 regels voor vier zones |
| Kaal gebouwd | 254 nodes, 9 modellen, 20 decals |
| Ingericht | 440 nodes, 88 modellen, 72 decals |
| Bouwen, met zichtlijnen | 1,8 s |
| Zichtlijnen die de bouwer vond | lobby en gang, lobby en werkplaats, magazijn en gang, magazijn en ketelruimte, gang en werkplaats, gang en ketelruimte, werkplaats en ketelruimte |

**Gecontroleerd, en wat niet**

- De route is te lopen: de bouwer vindt elke robot en het checkpoint bereikbaar vanaf de start.
- Het spel laadt de vleugel en draait hem 600 frames zonder beeld en zonder fout.
- De fabriek, het depot, de showroom en de modellen komen er gelijk uit, en `tools/selftest.sh --routes` slaagt.
- **De vleugel is gebakken en bekeken, na een herstart van de laptop.** Het contactblad laat vijf ruimtes zien die bij de fabriek passen: een lobby met een bureau onder het raam, een magazijn met stellingen en kisten, een gang met leidingen en open deuren, een werkplaats met pers, draaibank en tank onder hallampen, en een ketelruimte met de ketel, het metersbord en de pompen. Wat opvalt: de lobby is kaal en schemerig met één brandende buis, en de voorste hoek van de werkplaats is donker.
- **Gespeeld is hij niet.** Of de gevechten kloppen, weet ik niet. De selftest loopt hem niet af: hij staat niet in de levelkeuze van het spel.
- **Een proeflevel laat het savebestand met rust.** De vleugel spelen schreef eerst over wat er van het echte spel bewaard was: de start van de vleugel bij het begin, niets meer aan het eind. `scripts/save.gd` schrijft nu alleen nog voor de levels uit de levelkeuze; een ander level houdt zijn checkpoints zolang het draait. Getest in een kopie van het project met een eigen savemap: de vleugel schrijft niets, de fabriek wel, en de vleugel daarna laat staan wat de fabriek schreef.

**De vleugel gemeten**, tien standpunten, op 10 oktober 2026 vlak na de herstart

| | Tekenopdrachten | Driehoeken | Fps |
|---|---|---|---|
| 1440p met FSR 2 op 67%, zonder robots | 125 tot 1000 | 0,1 tot 1,7 miljoen | 63 tot 79 |
| 3456×2160 met MetalFX op 50%, zoals er gespeeld wordt | 125 tot 1006 | 0,1 tot 1,9 miljoen | 66 tot 80 |
| 1440p met FSR 2 op 67%, de elf robots op hun post | 125 tot 2108 | 0,1 tot 2,1 miljoen | 67 tot 77 |

- Alle vijf de ruimtes bakken samen in 43 seconden: lobby 4, magazijn 10, gang 4, werkplaats 19 en ketelruimte 7. Met het starten van de editor erbij is de hele vleugel in een minuut gebakken. De lightmaps zijn samen 22,8 MB.
- Met de robots op hun post verdubbelt het aantal tekenopdrachten in de gang, zonder dat de framerate eronder lijdt. De grenzen van het keurmerk gelden voor een ruimte zonder robots; met `--posted` telt alleen de framerate.

**Wat er misging: de bake liep vast, en de GPU met hem**

- Om 17:39 begon de bake van de vijf ruimtes. Lobby, magazijn, gang en werkplaats waren in twee minuten klaar. Om 17:41:06 startte er een andere Godot op de laptop, niet van deze sessie; de bake bleef daarna hangen op de ketelruimte.
- Die andere Godot stond twintig minuten later nog in de proceslijst als bezig met afsluiten. Elke nieuwe run op de GPU liep sindsdien vast met `timeout waiting for fence`, ook een screenshot van één standpunt, en bleef na afbreken zelf minutenlang hangen.
- Daarna is de inrichting van de vleugel nog veranderd, dus ook de vier lightmaps die er lagen klopten niet meer. Ze zijn weggehaald: de vleugel heeft geen lightmaps.
- **`tools/bake_lightmaps.sh` weigert sindsdien te bakken zolang er een andere Godot op de GPU zit**, tenzij met `--anyway`. Een bake wil de GPU voor zichzelf.
- `tools/build.gd` laat Godot niet meer eindeloos draaien als een bouwer op een fout stukloopt: na vier minuten stopt het met een melding. Dat gebeurde hier drie keer.
- **Het lag niet aan de ketelruimte.** Het vastlopen begon precies toen de bake aan die ruimte toekwam, dus dat kon de oorzaak zijn. Een half uur later hingen beide processen er nog, en een poging om het spel te starten liep op dezelfde manier vast; pas een herstart van de laptop hielp. Daarna is de ketelruimte eerst alleen gebakken, met niets anders op de GPU: klaar in 7 seconden. Wat overblijft is de botsing met de andere Godot.

**Werkwijze**

| Stap | Hoe |
|---|---|
| Een level uit ruimtes opzetten | Een plan met `room`, `door`, `window` en de route, en `_bare = true`; `tools/build_level.sh <level>`, dan `tools/level_map.py <level>` om het van bovenaf te zien |
| Het level inrichten | `_bare = false`, `keep_clear` voor wat er met de hand in komt, en een bestand per ruimte dat het level zijn deel laat bouwen |
| De vleugel bakken en bekijken, als er geen andere Godot draait | `tools/bake_lightmaps.sh res://scenes/wing.tscn`, dan `tools/zone_sheet.py wing` |
| Meten op de resolutie waarop gespeeld wordt | `tools/zone_sheet.py wing --res=3456x2160 --upscaler=metalfx --scale=0.5` |
| De vleugel spelen in een venster | `/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/wing.tscn -- --play` |

**Nog open**

- De regels voor wat er rondstaat zijn een eerste gok. In de werkplaats, met drie machines, drie deuren en vijf robots op 200 m², blijft er plek voor drie eilanden dekking. De robots staan open en bloot, in het zicht van wie binnenkomt: in de ketelruimte staat er een op een meter van de deur.
- Een ruimte is een rechthoek langs de assen met een vlak plafond. Geen schuin dak met spanten, geen tussenvloer, geen trap, geen terrein onder de open lucht.
- Tussen twee ruimtes staan twee muren rug aan rug. Dat houdt elke zone gesloten voor zijn bake, en kost muur die niemand ziet.
- Wat er met de hand in komt, moet het plan zelf vrijhouden; de bouwer weet niet hoe groot een pers is.
- De werkbank, het leidingwerk van de gang en de kraan uit de bouwdoos kunnen nog steeds maar in één richting staan.

### Stap 5: het fabrieksterrein

**Wat er staat**

- **Het fabrieksterrein** (`tools/levels/works.gd`, `scenes/works.tscn`), het level tussen de fabriek en het depot: 23 ruimtes op 84 bij 57 meter. Kantoren aan een gang aan de westkant; magazijn, gereedschapskamer, compressorruimte en werkplaats ten noorden van een ommuurd binnenterrein; kantine, keuken, ketelhuis en schakelruimte ten zuiden ervan; aan de oostkant de montagehal, de spuiterij, de expeditie en het laadperron, met de laaddeur als uitgang. 59 robots in elf gevechten, vijf checkpoints; het waren er eerst 73, zie "Na de eerste keer spelen".
- **Het zit in het spel.** De levelkeuze is Factory, Works, Depot; de uitgang van de fabriek leidt naar het fabrieksterrein en die van het fabrieksterrein naar het depot. Een ruimte galmt naar haar soort: `scripts/sfx.gd` leest dat van de zone af voor een level dat het niet zelf opgeeft.
- **Twee soorten ruimte erbij**: `canteen`, met tafels en stoelen, en `yard`, een ommuurd terrein onder de open lucht met schijnwerpers op masten en containers.
- **De robots staan niet meer open en bloot.** `fight` noemt per ruimte welke soorten er staan; hun post krijgen ze pas als alles staat, bij de opmeting (`_garrison` in `tools/kit/rooms.gd`). Een plek telt als verborgen als hij binnen 16 m niet te zien is vanaf waar de speler binnenkomt (de eerste 2,4 m achter de deur, over de hele breedte van de deuropening), vanaf de start of vanaf een checkpoint dat voor het gevecht ligt. Verborgen plekken gaan voor, zo ver mogelijk van de deur en uit elkaar. In de ruimte waar de speler binnenkomt zet de bouwer er iets hoogs voor neer, waar ze twee aan twee achter wachten: drie stapels pallets, een kast in een kantoor of een container op het terrein.
- **Zichtlijnen: sneller, en door elke opening.** De opmeting kijkt alleen nog naar de zijden van een zone die naar het oog toe staan: 57 s werd 19 s. Daarnaast kijkt de bouwer door elke opening in de zijden van een zone (`_look_through`): om de 30 cm, op drie hoogtes, in 480 richtingen. Een blik die naar beide kanten vrij is, verbindt de zones waar hij doorheen gaat. Dat vangt de kier tussen twee deurposten aan het eind van een gang, die de punten missen en de speler een stap later ziet.
- **Wat in de schaduw staat, werpt geen zonneschaduw** (`scripts/shade.gd`). De zon tekent haar schaduw tot 70 m ver in vier kaarten, en in elke kaart gaat alles wat binnen bereik staat in een zone die getekend wordt. Binnen staat bijna alles onder een dak. Bij het laden van een level kijkt het spel van elk geplaatst model naar de zon: staat er vanaf elke hoek een muur of dak tussen, dan gaat het naar een eigen laag die de zon overslaat. Lampen werpen zijn schaduw als voorheen. Dat geldt voor elk level.
- **De schaduwatlas heeft zestien vakken in zijn grootste maat** (`project.godot`), in plaats van vier. Zie hieronder wat er zonder gebeurde.
- **De route gaat met een knik naar de werkplaats**: van het magazijn door de gereedschapskamer en de compressorruimte, om twee hoeken. Eerst was er een deur recht van het magazijn naar de werkplaats.
- **Het keurmerk telt de schaduwlampen in zicht** (`tools/zone_sheet.py`, kolom `shadows`): die van de zone zelf en van de zones die ze ziet, twee vakken voor een lamp die rondom schijnt en een voor een spot, hooguit 48.
- `tools/benchmark.sh` neemt `--eval=` nu ook bij een gemeten run, om in een level iets uit te proberen zonder het in te bouwen. De nettest neemt niet meer aan dat het level na de fabriek één zone voor zijn eerste checkpoint heeft.

**Gemeten** op 10 oktober 2026

| | |
|---|---|
| Het fabrieksterrein beschreven | 289 regels in zes bestanden |
| Gebouwd | 2809 nodes in de scène, 818 modellen, 420 decals, 83 lampen |
| Bouwen | 24 s, waarvan 19 s de opmeting: 9,5 miljoen blikken |
| Zichtlijnen | 42 paren uit de punten en 2 door een opening; een ruimte ziet gemiddeld 3,7 andere, de westgang 8 |
| Alle 23 ruimtes bakken | 7 min 43 s; de werkplaats 78 s, de montagehal 68 s, het laadperron 54 s |
| Lightmaps | 222 MB op schijf, 141 MB op de videokaart |
| Laden | 0,8 s; 527 MB op de videokaart, waarvan 441 MB texturen |

**Het contactblad**, 56 standpunten op 1440p met FSR 2 op 67%, tenzij anders vermeld

| | Tekenopdrachten | Driehoeken | Fps | Het zwaarste standpunt |
|---|---|---|---|---|
| Zoals het eerst gebouwd was | 161 tot 2874 | 0,1 tot 6,0 miljoen | 55 tot 84 | de westdeur van het magazijn: 55 fps |
| Met de atlas en de schaduwsortering | 146 tot 1082 | 0,1 tot 2,0 miljoen | 59 tot 83 | dezelfde deur: 59 fps |
| En met de knik in de route | 146 tot 949 | 0,1 tot 2,0 miljoen | 65 tot 85 | de westgang: 65 fps; die deur ook 65 |
| Op 3456×2160 met MetalFX op 50%, zoals er gespeeld wordt | 147 tot 951 | 0,1 tot 2,1 miljoen | 60 tot 85 | de westdeur van het magazijn en de keuken: 60 fps |
| Met de 73 robots op hun post | 159 tot 3007 | 0,1 tot 2,7 miljoen | 59 tot 80 | de spuiterij, met 26 robots in zicht: 59 fps |

- De fabriek zelf, tien standpunten: 454 tot 1311 tekenopdrachten en 0,8 tot 3,2 miljoen driehoeken werd 343 tot 835 en 0,5 tot 1,5 miljoen. De framerate bleef 69 tot 80; een standpunt daar wordt begrensd door wat de pixels kosten, niet door de meetkunde.
- De laptop was bij geen van deze metingen in rust: er draaiden tests en een export van andere sessies. De getallen zijn onderling te vergelijken, niet de beste die de laptop haalt.

**Wat de metingen aan het licht brachten**

- **De lampen verdrongen elkaar in de schaduwatlas.** Godot deelt de atlas op in vier kwarten met 4, 4, 16 en 64 vakken. Een lamp die veel van het beeld beslaat wil een groot vak, en zijn er daar te weinig van, dan pakt de ene lamp elk frame het vak van de andere en wordt elke schaduw opnieuw getekend. Vanaf de westdeur van het magazijn was dat 2800 tekenopdrachten en 4,7 miljoen driehoeken per frame extra. Met drie kwarten van zestien vakken blijven de schaduwen staan tot er iets beweegt. De grootste schaduwkaart van een lamp is daarmee 512 in plaats van 1024 pixels. In het beeld scheelt dat weinig: per standpunt verschillen hooguit 705 van de 2 miljoen pixels meer dan 3%, langs de randen van schaduwen.
- **De zon tekende wat nooit zon krijgt.** Van de 4,4 miljoen driehoeken die bij die deur overbleven, waren er 3,7 miljoen van de zonneschaduw. Met de schaduwsortering 1,5 miljoen in totaal. Over alle 57 standpunten samen ging het van 83,5 naar 45,9 miljoen driehoeken. Het beeld bleef gelijk: per standpunt verschilden hooguit 234 van de 2 miljoen pixels meer dan 3%, evenveel als tussen twee runs zonder enig verschil.
- **In een deuropening staat de camera in twee zones tegelijk.** `scripts/zones.gd` rekent 60 cm buiten een zone nog als erin, zodat de ruimte achter de deur er al is. In de westdeur van het magazijn stonden daardoor het magazijn, de gang en alles wat die twee zien aan: 12 van de 23 ruimtes. De knik haalt de werkplaats en het binnenterrein uit dat zicht.
- **De fabriek had een kier.** Uit de zuidoosthoek van de hal is door een deuropening van de annex en de deur van de gang een reep van de gang te zien. De lijst die er met de hand stond, de punten van de bouwer en de selftest hadden hem alle drie gemist. De hal en de gang tekenen elkaar nu mee; de gang haalt daarmee 74 en 76 fps.

**Wat er misging**

- **De bake van de werkplaats liep twee keer vast**, na de knik, in het sorteren van de lichtprobes: Godot schreef in zes minuten ruim honderdduizend keer `Inconsistency found in triangulation while building BSP` en kwam niet tot een einde. De GPU had er geen deel aan. De bouwer zette de probes in een hal van 21 m om de 66 cm; nu staan ze een goede meter uit elkaar (`cells > 20` in `tools/level_builder.gd`). De werkplaats bakt zo in 70 s, zonder waarschuwing, en zijn probebestand is 0,6 MB in plaats van 2,9. Het raakt in dit level ook de zuidgang oost.
- Een bake of een bouw die niet eindigt wordt door de tijdslimiet gestopt; meer dan tijd heeft het niet gekost.

**Gecontroleerd, en wat niet**

- `tools/selftest.sh` slaagt met het fabrieksterrein erin, 197 controles, waaronder: de route is te lopen, elke robot kan de speler bereiken, geen robot staat in zicht waar zijn zone betreden wordt of bij een checkpoint, en geen zone die uit staat is te zien. `tools/selftest.sh --fights` en `tools/nettest.sh` slagen ook; de nettest loopt nu van de fabriek naar het fabrieksterrein.
- Het fabrieksterrein komt bij twee keer bouwen gelijk uit. In de fabriek veranderde alleen wie wie ziet en waar de uitgang heen leidt; het depot en de modellen zijn gelijk gebleven. Alle lightmaps zijn bij.
- De vleugel is opnieuw gebouwd met de schermen en de posten van nu, en zijn magazijn en werkplaats zijn opnieuw gebakken.
- **Gespeeld is het niet.** Of elf gevechten met 73 robots een kwartier boeiend blijven, of de schermen eerlijk aanvoelen en of de checkpoints goed liggen, weet ik niet.
- Met de robots op hun post haalt één standpunt 59 fps. Dat is met alle 73 nog overeind; wie in de spuiterij staat heeft de montagehal al leeg. Een gevecht zelf is op het fabrieksterrein niet gemeten.

**Na de eerste keer spelen**, 11 oktober 2026

Michiel startte het fabrieksterrein twee keer vanuit de worktree. Volgens het savebestand eindigde de tweede beurt na 41 seconden, met een dood en zonder het eerste checkpoint. Twee dingen zaten hem in de weg, en geen van beide is het level zelf.

- **Deze branch mist de renderschaal die zichzelf instelt.** Die kwam op 10 oktober op `fase-2-vertical-slice`, nadat `bouwdoos` was afgetakt. Zijn instellingen (Ultra, MetalFX, `auto_scale`) leest deze build als een renderschaal van 100%. Gemeten aan het begin van het fabrieksterrein, van de portiersloge tot de deur van het magazijn:

| Op zijn instellingen | Fps |
|---|---|
| Volledig scherm, 3456×2160 op 100%: wat deze build doet | 13 tot 17 |
| In het venster van 1920×1080 op 100% | 42 tot 54 |
| Volledig scherm op 50%: wat de hoofdbranch ervan maakt | 38 tot 47 |

- De fabriek haalt op de hoofdbranch met die instellingen 44 tot 50 fps (gemeten door de sessie die de renderschaal bouwde). Het budget van 60 fps hierboven is dat van High; op Ultra zit het fabrieksterrein er net als de fabriek onder, en aan de deur van het magazijn het verst.
- **De gevechten waren te groot.** De fabriek stuurt er 3, 3, 4 en 6 op de speler af en het depot 4, 6 en 5. Het fabrieksterrein begon met 8, uit vier kamers tegelijk een gang in waar niets staat om achter te schuilen, en had zes gevechten van 8. De vleugels die als één gevecht tellen zijn teruggebracht naar die maat: de kantoren 3 (twee grunts en een rusher, zoals de fabriek begint), het magazijn met gereedschapskamer en compressorruimte 5, de kantine met keuken 5, het ketelhuis met schakelruimte 5. Samen 59 robots in plaats van 73. Er verschoof niets dat gebakken is: alle lightmaps zijn nog bij, en de selftest en de nettest slagen.
- De vier grote ruimtes staan nog op 7 en 8 (werkplaats, binnenterrein, montagehal, laadperron). Daar staat dekking, en ze naar 6 brengen verplaatst de schermen, wat een bake vraagt.
- De meting met de robots op hun post, hierboven, is die met 73.

**Werkwijze**

| Stap | Hoe |
|---|---|
| Het fabrieksterrein bouwen | `tools/build_level.sh works`, dan `tools/level_map.py works` om het van bovenaf te zien |
| De routes nalopen, met waar elke robot staat | `tools/selftest.sh --routes` |
| Bakken wat veranderd is, als er geen andere Godot draait | `tools/bake_lightmaps.sh res://scenes/works.tscn` |
| Het keurmerk en het contactblad | `tools/zone_sheet.py works`, met `--posted` voor de robots erbij |
| Uitzoeken wat een standpunt zwaar maakt | `tools/benchmark.sh --quick --scene=res://scenes/works.tscn --at=x,y,z,draai,kantel --profile` |
| Iets uitproberen in een gemeten level | dezelfde opdracht met `--eval='game.get_node("Level/ZoneYard").hide()'` |

**Nog open**

- **Op de speelresolutie is er geen marge**: twee standpunten halen daar 60 fps. Het licht van een lamp reikt door muren heen tot in de ruimtes ernaast en wordt daar per pixel uitgerekend, met zijn schaduw erbij; dat is de grootste post die overblijft. Een lamp aan zijn eigen ruimte binden vraagt renderlagen per zone.
- **Rijen kamers aan een gang zien elkaar.** Uit een kamer kijk je door je eigen deur schuin de deuren aan de overkant in. De westgang ziet zo acht ruimtes. Occlusion culling zou tekenen wat echt in beeld is; nu is het alles of niets per zone.
- De kantoren zijn kaal: een bureau, een stoel en een kast op ruim 90 m². De schermen zijn overal dezelfde drie stapels pallets.
- De schaduwsortering kijkt bij het laden. Een model dat in de schaduw stond van iets dat wordt opgeblazen, werpt daarna nog steeds geen zonneschaduw.
- De lightmaps van het fabrieksterrein zijn 222 MB in Git LFS, naast ongeveer 130 MB van de fabriek, het depot en de vleugel. Hoeveel LFS-opslag er bij GitHub is, is nog steeds niet nagekeken.
- **`bouwdoos` loopt 34 commits achter op `fase-2-vertical-slice`**: de renderschaal, de stemmen, wat stuk kan, de beweging van het beeld. Proef samengevoegd botst het op twee regels (`scripts/game.gd` en de levellijst in `scripts/menu.gd`). De sessie mocht het niet zelf samenvoegen; dat wacht op Michiel. Daarna moeten de nieuwe geluiden worden ingelezen, de tests opnieuw draaien en het contactblad opnieuw gemaakt, want kratten en lampen kunnen dan stuk.
- Elke kamer een eigen gevecht, in plaats van een vleugel als één gevecht, geeft 21 kleine gevechten en houdt alle robots. Dan moet de speler elke kamer in, en de regel dat de route door elk gevecht loopt vervalt. Dat is niet besloten.

## Gevechten: dekking, beurten en schaarste

De branch `gevecht` voegt eerst `looproute` (de route) en `speelbaar` (de personages) samen en bouwt daarop. Tot hier liep elke vijand op de speler af, stapte ervoor heen en weer en schoot zodra zijn eigen klok afliep; health kwam vanzelf volledig terug en elk checkpoint vulde alle munitie aan. Een gevecht vroeg dus niets van de speler behalve raak schieten. Nu vechten de vijanden vanuit dekking en om beurten, en moet de speler wat hij nodig heeft bij de wrakken halen.

**Wat de vijanden doen**

- **Dekking.** `scripts/squad.gd` (autoload `Squad`) zoekt bij het laden van een level de dekking op: over het navmesh van de zones om de meter een plek, en waar op kniehoogte iets naast staat wordt die plek bewaard en ertegenaan geschoven. In de fabriek zijn dat 530 plekken. Een vijand die dekking neemt (`takes_cover`, de grunt) vraagt er een die hem voor de speler verbergt. Dat wordt dan pas nagekeken, met lijnen van de ogen van de speler naar zijn hoofd en zijn borst, in het midden en op beide schouders: een plek op de rand van wat hem dekt verbergt de helft van wie er staat. Achter iets hoogs staat hij en schiet hij van een stap opzij; achter iets laags duikt een robot weg en komt hij overeind om te schieten. Hij verkast als de speler om hem heen is gekomen (0,7 s in het zicht), dichterbij is dan 4 m, als hij er 7 tot 12 s heeft gezeten of twee keer voor niets is uitgekomen. Vindt hij niets, dan doet hij wat hij altijd deed.
- **Beurten.** Wie wil aanvallen vraagt een beurt, en er zijn er maar zoveel tegelijk (op Normal twee), met een pauze van een seconde na elke aanval voordat de volgende mag. Wie het langst wacht gaat voor. De rest wacht in dekking of verplaatst zich. Wie slaat in plaats van schiet (de rusher) heeft geen beurt nodig. Een groep van vijf grunts viel in de test 11 tot 15 keer aan in 12 seconden, nooit met meer dan twee tegelijk; zonder pauze was dat 20 tot 26 keer.
- **Omtrekken.** Van een groep van drie of meer gaat er één (op Hard twee) om de speler heen: hij kiest dekking opzij van waar de rest staat, tot 22 m lopen, en geeft dat aan met een eigen roep.
- **Gevaar.** Wat op ontploffen staat meldt zichzelf (groep `hazard`, methode `danger()`): een granaat, een brandend vat, het brandende pack van een heavy. Wie binnen het bereik staat laat na 0,3 tot 0,6 s alles vallen en rent naar een plek buiten het bereik, of naar een plek waar iets tussen hem en de klap staat. Om een brand op de vloer loopt hij heen, en staat hij erin dan loopt hij er de kortste weg uit. De heavy trekt zich er niets van aan (`heeds_danger`). De granaat is daarmee vooral iets om grunts uit hun dekking te jagen: met de volle 2,2 seconden kwam een grunt in de test 7 m weg, zonder schade.
- **De plaat van de grunt.** De robotgrunt droeg een plaatje op zijn linkerarm dat niets deed. Het is nu een plaat van 50 bij 57 cm (onderdeel `Shield` in `tools/models/enemies.gd`) die hij voor zijn romp houdt zodra hij van de speler weet, en die van voren elk schot tussen heup en hals tegenhoudt (0,8 tot 1,37 m). Hoofd en benen steken erbuiten, van opzij en van achteren is hij open, en een explosie gaat er dwars doorheen. Het eerste schot op een grunt die nog niets weet, komt aan. Een tegengehouden schot geeft geen hitmarker, wel vonken, een eigen klank en een oplichtende plaat. Na 80 schade vliegt de plaat van zijn arm en staat hij 0,9 s te wankelen. Op Normal draagt de helft van de grunts er een; dat is te zien voordat het gevecht begint.
- **Het pack van de heavy.** De munitie op zijn rug is een gele trommel met lampen geworden (onderdeel `Pack`). Een schot erin van achteren telt anderhalf keer. Na 70 schade spuit er een vlam uit, en 1,3 seconde later ontploft het: 140 schade in het hart, niets meer op 5 m, ook voor de robots ernaast. De heavy draait daarvoor traag (2,4 rad/s tegen 8), schiet alleen op wat binnen 45 graden voor hem staat en houdt midden in een salvo op als de speler verder om hem heen is.
- **Wat je hoort.** Vóór een salvo een oplopende toon, voor grunt, rusher en heavy een eigen; een roep van wie omtrekt; een alarm van wie wegrent. Gesynthetiseerd, zoals de rest in deze branch.
- **Personages** (soldaten, zombies, clowns) hebben hetzelfde brein: wie schiet neemt staand dekking, wacht zijn beurt af en vlucht. Ze duiken niet weg, dragen geen plaat en geen pack, en zeggen niets van het nieuwe.

**Wat er te halen valt**

- **Health komt vanzelf terug tot 35** (Normal), na vier seconden zonder treffer. De rest zit in cellen die de vijanden achterlaten: 25 per stuk. Op de healthbalk staat een streep bij 35 en ernaast het getal, rood zolang je onder de streep zit.
- **Munitie.** Een wapen begint een level met twee magazijnen reserve in plaats van met alles wat het kan dragen (de karabijn 60 van de 150). Een blik munitie geeft een magazijn voor het wapen in de hand en een derde voor elk ander. Het pistool raakt nooit op (`bottomless`): er is altijd iets om mee te schieten.
- **Wat een vijand achterlaat** volgt wat de speler mist, zonder toeval (`LEAVES_CELL`, `LEAVES_CAN` en `LEAVES_GRENADE` in `scripts/game.gd`). Elke kill telt een deel van een cel, een blik en een granaat op, en er valt iets zodra een deel vol is. Voor een cel: 0,2 per kill, plus 0,9 maal het deel van zijn health dat de speler mist, plus 0,3 voor een kill van binnen 8 m; een heavy laat er altijd een achter, en een granaat. Voor een blik: 0,3 plus 0,8 maal hoe ver de reserve van het wapen in de hand is gezakt. Wie gewond en zonder kogels drie grunts van dichtbij neerhaalt, vindt drie cellen en drie blikken.
- **Oprapen** is eroverheen lopen (`scripts/pickup.gd`); de laatste meters komt het naar je toe. Wat je niet kunt gebruiken blijft liggen. Na 40 seconden is het weg, de laatste 6 knippert het. Elk gloeit in zijn eigen kleur, zodat het in een donkere hal te vinden is, en linksonder staat even wat je kreeg.
- **Een checkpoint** vult niet meer alles aan: de reserve van elk wapen en de granaten komen terug tot waarmee een level begint, health tot 75. Wie bij een checkpoint verdergaat na een dood krijgt precies dat, zodat doodgaan nooit de betere weg is.

**Moeilijkheid en wat een run opleverde**

- De moeilijkheid is één tabel, `RULES` in `scripts/settings.gd`, te kiezen in het instellingenscherm:

| | Easy | Normal | Hard |
|---|---|---|---|
| Vijanden die tegelijk aanvallen | 1 | 2 | 3 |
| Pauze na een aanval | 1,2 s | 1,0 s | 0,5 s |
| Wie om de speler heen gaat | 1 | 1 | 2 |
| Grunts met een plaat | 30% | 50% | 75% |
| Schade van een vijand | 0,6× | 1× | 1,35× |
| Hoe lang een aanval wordt aangekondigd | 1,3× | 1× | 0,8× |
| Health die vanzelf terugkomt | tot 50 | tot 35 | tot 25 |
| Wat vijanden achterlaten | 1,4× | 1× | 0,75× |

- Het eindscherm zegt naast het aantal vijanden hoe lang het duurde, hoe vaak je doodging, hoeveel schoten raak waren en hoeveel in het hoofd. Dat wordt bijgehouden in `Save.stats` en gaat bij elk checkpoint en elke dood het savebestand in.

**Werkwijze**

| Stap | Commando |
|---|---|
| Alleen de gevechten en de voorraden testen | `tools/selftest.sh --fights` |
| De gevonden dekking als plattegrond (`c` laag, `C` hoog), of één grunt van stap tot stap | `tools/selftest.sh --fights --map` of `--trace` |
| De plaat, het wegduiken en het pack bekijken | `tools/benchmark.sh --quick --spawn="res://scenes/enemy.tscn@-2,0,-1.2,-100,1,10;res://scenes/enemy.tscn@-2,0,0.6,-100,1,11;res://scenes/enemy_heavy.tscn@-2,0,2.8,80,1,1" --at="1.6,1.5,0.8,90,-6"` |
| Meten wat een gevecht kost: alle robots van de route tegelijk aan, tegen een speler op die plek | `tools/benchmark.sh --awake=12,0,4 --warmup=400 --at="15,1.6,8,68,0"`, naast dezelfde run met `--posted` |
| Het spel met HUD bekijken, gewond en met iets om op te rapen | `tools/godot.sh -- --play --snap=3.2 --at="12,0,4,90,-14" --eval="player.take_damage(70.0)" --eval="game.leave(0, Vector3(8.6,0.9,3.2))"` |
| De robots opnieuw bouwen, of de cel en het blik | `tools/build_model.sh enemies` of `props` |

**Wat de selftest ervan controleert** (136 controles, was 103; de test van de personages 26):

- dat een grunt naar dekking rent en daar van hoofd tot borst niet te zien is, eruit komt om te schieten als het zijn beurt is en teruggaat;
- dat van vijf grunts er nooit meer dan het toegestane aantal tegelijk aanvalt, dat ze wel aanvallen, en dat er één omtrekt en niet meer;
- dat een grunt wegrent van een granaat aan zijn voeten en dat overleeft, en uit een brand loopt;
- de plaat: het eerste schot op een grunt die niets weet komt aan, daarna houdt de plaat van voren tegen, niet op hoofd, benen of rug en niet bij een explosie; een tegengehouden schot geeft geen hitmarker; genoeg schoten slaan de plaat eraf;
- het pack: van voren alleen schade, van achteren meer schade en brand, en dan de klap die de heavy en de grunt ernaast meeneemt;
- dat health tot 35 terugkomt en niet verder, dat het pistool niet opraakt, dat kills cellen en blikken achterlaten voor wie ze nodig heeft, dat oprapen werkt en een cel blijft liggen bij wie niets mankeert, en wat een checkpoint aanvult;
- dat de moeilijkheid de tabel volgt en dat een run wordt gemeten en samengevat.

Een deel van de test dat op een scriptfout halverwege ophoudt, telde tot nu toe als geslaagd: wat niet meer werd nagekeken, faalde ook niet. De test houdt nu bij welke delen hun einde hebben gehaald en faalt voor elk dat ontbreekt.

**Wat het kost**

- Het opzoeken van de dekking: 44 ms voor de fabriek, één keer, terwijl het beeld uit zwart opkomt. Het navmesh van een level is vooral het terrein eromheen (24 duizend plekken); er wordt alleen in de zones gekeken (1569 plekken).
- Een keer dekking zoeken: 0,3 tot 0,4 ms, hooguit 1 ms. Vijf grunts in gevecht doen dat samen 10 keer in 12 seconden.
- Een heel gevecht: gemeten op 10 oktober 2026 op 1440p met FSR 2 op 67%, vanaf de oostkant van de hal, met alle zestien robots van de fabriek tegelijk aan en op de speler af (`--awake`) tegen dezelfde zestien roerloos op hun post (`--posted`), twee keer om en om terwijl de laptop zwaar in gebruik was (load 5 tot 6): 71,6 en 74,2 fps roerloos, 70,1 en 67,3 fps in gevecht. Dat is 2 tot 7 fps voor zestien robots; een zone heeft er hooguit zes. De 1% low liep in die runs uiteen van 46 tot 67 fps, in beide soorten; daar is niets uit af te lezen.
- De grunt is met zijn plaat 9,4 duizend driehoeken in 17 onderdelen, de heavy met zijn pack 8,7 duizend in 19. De cel en het blik zijn 1,1 en 1,5 duizend, met elk een licht zonder schaduw.

**Onderweg gevonden**

- Het navmesh zweeft tot een halve meter boven de vloer. De dekkingsplekken lagen daardoor te hoog en een "lage" dekking werd op heuphoogte gemeten. Elke plek wordt nu met een straal op de vloer gezet.
- Een schot dat de plaat tegenhoudt kost de robot geen health, en het spel zag aan zijn health dat er op hem geschoten was. Een zone begon dus niet als je op een plaat schoot. Een vijand meldt nu zelf dat hij geraakt is (signaal `disturbed`), wat ook het open punt uit de route oplost dat het spel te veel van een robot las.
- De test van de personages ging nog uit van waves en faalde op de samengevoegde branch op drie punten. Hij speelt nu het eerste gevecht van de route.

**Nog open**

- **Het is niet gespeeld.** Alles hierboven is nagekeken met tests en screenshots. Of een gevecht leuk is, te makkelijk of te moeilijk, kan ik niet beoordelen. De getallen zijn een eerste gok: de tabel hierboven, de 80 van de plaat, de 70 en 1,3 s van het pack, de twee magazijnen reserve, de 25 van een cel en de aandelen in `LEAVES_*`. Ze staan elk op één plek.
- De nieuwe geluiden heeft niemand gehoord.
- Een grunt met een plaat die achter iets laags overeind komt, laat van voren alleen zijn hoofd zien. Dat is zo bedoeld (het hoofd, de plaat eraf schieten, eromheen of een granaat), maar het kan in de praktijk te taai zijn.
- De dekking wordt één keer opgezocht. Een vat dat is ontploft telde al niet mee, maar een deur die opengaat of een wrak dat ergens neerkomt verandert er niets aan.
- Robots gooien zelf niets en schieten niet blind om je in dekking te houden. De rusher doet wat hij deed, behalve dat hij voor een granaat wegrent.
- Wat een vijand achterlaat, valt een stap naast hem; er wordt alleen gekeken of daar geen muur staat. Op de rand van de tussenvloer kan het naar beneden vallen.
- Personages duiken niet weg en hebben geen eigen stem voor het nieuwe. Het eindscherm noemt ze nog robots.
- Het geluidswerk dat in de hoofdmap in bewerking is, raakt `scripts/sfx.gd` op dezelfde plek als de nieuwe geluiden hier; samenvoegen vraagt daar handwerk.

## Samen spelen

Het spel is met meer spelers over het netwerk te spelen: samen de route door de levels, van de start naar de uitgang. Eén speler host, de anderen joinen op zijn adres. Gebouwd op 10 oktober 2026 op de branch `multiplayer`, bovenop de route en de personages; het werk aan de gevechten en aan het geluid liep op dat moment nog op eigen branches en zit er niet in.

**Wat er staat**

- **Hosten en joinen vanuit het menu.** "Play together" op het titelscherm: een naam, "Host a game" met een levelkeuze, en een adres met "Join the game at that address". Wie joint terwijl er al gespeeld wordt, komt binnen bij het laatste checkpoint en vindt het level zoals het er staat: wat is opgeruimd, wat is ontploft, waar de robots zijn. Het pauzemenu van de host laat zien op welke adressen de anderen binnenkomen. Naam en adres worden onthouden in `user://net.cfg`.
- **Een menu zet het spel niet stil** als je samen speelt: het level loopt door achter het menu.
- **De ander is een soldaat.** Elke medespeler staat in het level als een van de vijf soldaten uit de cast, op het skelet en met de bewegingen van de vijanden die mensen zijn (`scripts/humanoid_rig.gd`), met in zijn handen het wapen dat hij draagt (`scenes/models/<wapen>_held.scn`) en zijn naam boven zijn hoofd. Hij loopt in de maat van zijn snelheid, richt waar de speler kijkt, laat zijn wapen zakken als die rent, vuurt, deinst terug als hij geraakt wordt en valt als hij doodgaat. Welke soldaat het is volgt uit het nummer van de speler, dus iedereen ziet dezelfde.
- **De regels van samen.** Een zone begint als de eerste speler hem binnenloopt; een checkpoint dat één speler bereikt geldt voor allemaal, met munitie en granaten voor iedereen. Wie doodgaat staat vijf seconden later weer bij het laatste checkpoint. Liggen ze allemaal tegelijk, dan begint het level voor iedereen opnieuw vanaf dat checkpoint. Het level eindigt pas als iedereen die nog overeind staat bij de open uitgang is; dan gaat iedereen samen naar het volgende level. Een robot gaat af op de dichtstbijzijnde speler die nog staat, en laat de speler waar hij achteraan zit pas los als een ander duidelijk dichterbij is (een kwart). Kogels gaan door medespelers heen; een explosie niet, ook je eigen granaat niet.
- **Alleen spelen is hetzelfde spel** met niemand erbij: er is één codepad. De checkpoints van een spel alleen worden door samen spelen niet aangeraakt.

**Hoe het werkt**

- **De host beslist over de wereld, elke machine over haar eigen speler.** Bij de host lopen de robots, de schade, de explosies en de route. Beweging en schieten doet elke machine zelf, zodat die zo direct zijn als alleen: ze vertelt de anderen dertig keer per seconde waar haar speler is, en vraagt de host om schade aan wat ze raakte. De host vertelt twintig keer per seconde waar de robots zijn. Dat neemt elke machine op haar woord: prima onder vrienden, niet geschikt voor openbare servers. Voor openbare servers moet de host ook beweging en treffers narekenen, en dat is een andere opzet van `scripts/player.gd` en `scripts/weapons.gd`.
- **Beslissen en laten zien zijn uit elkaar gehaald.** Waar een script iets besliste en het meteen liet zien, staat het laten zien nu in een eigen functie (`_show_...`) die via `Net.show` op elke machine draait: het schot van een robot, een treffer, een dood, het begin van een zone, een checkpoint, een explosie, een vat dat vlam vat. Een gast draait de beslissingen niet; een robot gaat daar alleen waar de host zegt dat hij is, en zijn rig doet de rest zelf.
- **Alles loopt via één node**, `scripts/net.gd` (autoload `Net`), die op elke machine bestaat welk level er ook geladen is, en een bericht bij een node bezorgt aan de hand van zijn pad. Wat een level tijdens het spel aanmaakt, moet daarom overal dezelfde naam krijgen: de robots heten naar hun zone en hun plaats daarin. Een gast die het level nog aan het laden is, krijgt niets tot hij zich meldt; dan krijgt hij eerst de stand van het level.
- **Wat een schot raakte wordt op elke machine opnieuw opgezocht**, met een korte straal rond het eindpunt. Zo krijgt elke machine de inslag die bij haar eigen ondergrond hoort, zonder dat het effect zelf over de lijn gaat.
- **Een granaat** vliegt op elke machine apart; hij ontploft waar die van de werper ligt.
- **Elke machine houdt de health van haar eigen speler bij.** Een robot van de host die een ander raakt, of een explosie, geeft dat door aan de machine van die speler.
- **De verbinding** is ENet over UDP-poort 24565, rechtstreeks. Op hetzelfde netwerk werkt dat zo. Van buitenaf moet de host die poort op zijn router doorsturen naar zijn computer en zijn publieke adres doorgeven. Twee machines spelen alleen samen als ze dezelfde `VERSION` in `scripts/net.gd` hebben; die gaat omhoog bij alles wat verandert aan wat er over de lijn gaat of aan hoe een level is opgebouwd.

**Getest**

`tools/nettest.sh` start het spel twee keer op deze machine, zonder venster, en laat beide via het menu gaan zoals een speler: de een host de fabriek, de ander joint op 127.0.0.1. Elke kant controleert haar deel van hetzelfde verhaal, samen 58 controles: binnenkomen in een level waar al een robot ligt, elkaar zien lopen, een robot die de gast doodschiet en die bij de host valt, een robot van de host die de gast kiest en raakt, een granaat en een vat die bij beiden afgaan, doodgaan en weer opstaan, van wapen wisselen, de uitgang die op beiden wacht, samen naar het depot, allebei dood en opnieuw beginnen, weggaan, terugkomen in een level dat inmiddels voorbij een checkpoint is, en de host die weggaat. Drie keer achter elkaar gedraaid, drie keer geslaagd, ook met soldaten als vijand. De selftest van het spel alleen geeft dezelfde 103 controles als ervoor.

**Wat de test onderweg vond**

- Wie binnenkwam in een level dat voorbij een checkpoint was, zette de robots van de opgeruimde zones niet neer, en telde de rest dus anders dan de host: elke robot was bij de gast een andere dan de host bedoelde. Robots hebben nu een nummer dat uit hun zone en hun plaats daarin volgt.

**Nog open**

- **Alleen getest op één machine**, zonder vertraging en zonder verlies. Hoe het voelt over een echt netwerk, met 30 tot 100 ms ertussen, heeft niemand gezien, en ook niet met twee vensters naast elkaar gespeeld: de test kijkt naar wat er gebeurt, niet naar hoe het eruitziet.
- **De Windows-build heeft nog nooit gedraaid**, en de Mac-build alleen zonder venster. Zie "De download voor vrienden".
- **Port forwarding moet met de hand.** Geen UPnP, geen relay, geen uitnodigingslink.
- **De gevechten zijn samen maar half te zien.** Sinds 10 oktober 2026 staan de gevechten, het geluid en samen spelen op één branch. De host beslist alles en een gast ziet wat er al was: alarm, treffers, opladen, schoten, slagen en sterven. Wat de gevechten erbij brachten is alleen op de host te zien en te horen: de plaat die een schot tegenhoudt en van de arm valt, de rugzak die brandt en ontploft, bukken en de roep van een robot die omloopt of vlucht. Welke grunt een plaat draagt wordt per machine geloot en is dus bij een gast een andere dan bij de host. Wat een robot achterlaat valt op elke machine apart, uit wat de speler daar tekortkomt; de moeilijkheid van de host telt voor de robots, die van de gast voor wat hij vindt. De netwerktest slaagt, maar kijkt naar geen van deze dingen; het is uit de code afgeleid, niet met twee machines bekeken.
- **Met het thema soldaten lijken medespelers op vijanden**; alleen de naam boven het hoofd onderscheidt ze.
- Een medespeler bukt en slidet niet zichtbaar (zijn botsvorm en ooghoogte wel), herlaadt niet zichtbaar en wisselt van wapen door een nieuw figuur te worden: één frame, geen beweging.
- De HUD toont niet hoe het met de anderen gaat en er is geen chat.
- Geen deathmatch. Daarvoor moeten spelers elkaar kunnen raken (de straal van een schot slaat spelers nu over), verspreid opnieuw beginnen en moet er een stand zijn.
- Stopt de host, dan is het spel voor iedereen voorbij: de gasten staan weer op het titelscherm met de melding waarom.
- Wrakken, hulzen, brokstukken en kogelgaten zijn per machine verschillend, en een vat dat al weg was toen je binnenkwam heeft bij jou geen wrak.

**De download voor vrienden**

- `tools/export.sh` bouwt `build/GraphicsFPS-windows.zip` (365 MB) en `build/GraphicsFPS-macos.zip` (387 MB, voor Intel en Apple Silicon), elk met `tools/LEESMIJ.txt` erin: hoe je het start, meedoet en host. De instellingen staan in `export_presets.cfg`; `build/` staat niet in git. Van de export-templates van Godot 4.7.2 zijn alleen die voor Windows en macOS opgehaald (231 MB van de 1,28 GB).
- **Getest:** de gebouwde Mac-app speelt, twee keer gestart zonder venster, de hele netwerktest (58 controles), ook met soldaten als vijand. Er zit dus in wat het spel nodig heeft, de tabellen met thema's inbegrepen (`*.json` gaat apart mee, want het zijn geen resources). Met een venster heeft de build niet gedraaid, en de Windows-build helemaal niet.
- **De Mac-build komt uit een kopie van het project**, `build/src`. Godot exporteert alleen voor Apple Silicon als elke textuur ook als ETC2/ASTC is geïmporteerd, en pakt daarna dezelfde texturen in als voor Windows. In het project zelf zou die instelling elke import en elke lightmap-bake alle texturen een tweede keer laten omzetten, dus staat hij alleen in de kopie aan.
- **Het duurt lang.** Het script deed er de eerste keer 20 minuten over, met alle cores: beide exports importeerden alles opnieuw. Of een tweede keer sneller gaat, zoals de bedoeling van de kopie is, is niet gemeten.
- **Niet ondertekend.** Windows waarschuwt bij het starten en een Mac weigert de eerste keer; `LEESMIJ.txt` zegt hoe je erdoor komt. Zonder waarschuwing kost een Apple Developer-account.
- Er is nog geen plek waar de zips staan, en het spel heeft geen eigen icoon.
