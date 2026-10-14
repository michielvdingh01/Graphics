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
| `panic_clowns` | als `clowns` | als `clowns` | als `clowns` | De clowns met `panics` aan: wie een andere clown binnen 8 m ziet sterven of zelf nog 40% van zijn gezondheid heeft, slaat door. In het manifest staat het als `"like": "clowns"` met een eigen `tuning`, dus het volgt vanzelf wie bij de clowns in welke rol staat |
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

- Zombies en clowns zijn plaatshouders. Een realistisch model van een van beide is nergens te krijgen onder een licentie die gebruik in een eigen spel toestaat zonder account; er is een generatiedienst voor nodig. Het manifest heeft per plaatshouder de prompt klaarstaan. Wat er per dag kan en in welke volgorde staat onder "Houding en beweging".
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

- De vijf wapens zijn onderdeel voor onderdeel in code opgebouwd (`tools/models/weapons.gd`), omdat er geen gescande of gegenereerde modellen voor zijn: een karabijn met een open richtkijker en een lamp, een dienstpistool, een pompgeweer met reservepatronen op de kast, een pistoolmitrailleur met draadkolf en een scherpschuttersgeweer met kijker en tweepoot. Elk is 36 tot 46 duizend driehoeken, inclusief de handschoenen en mouwen van de schutter: sinds 11 oktober 2026 een hand met een skelet uit Blender in plaats van buizen en blokken, en de wapens zelf op echte maten met een rail naar het echte profiel. Zie "De wapens opnieuw".
- Een modelbouwer (`tools/model_builder.gd`) gebruikt daarvoor dezelfde bouwstenen als de levelbouwer en verdeelt de driehoeken over onderdelen met een eigen draaipunt, zodat een slede, een grendel, een pomp of een magazijn kan bewegen. Een model wordt één bestand in `scenes/models/`. De levelbouwer heeft er `slab` bij gekregen: een plaat die naar een omtrek is gesneden, met afgeronde randen. Daar zijn de kasten, kolven, grepen en magazijnen van gemaakt.
- Wapens en robots gebruiken één shader, `shaders/finish.gdshader`: een deklaag (bruinering, anodiseerlaag, lak of het kunststof zelf) die langs de randen tot op het metaal is weggesleten, met krassen en schuurplekken op de vlakken en vet waar het wordt vastgepakt. De randen komen uit dezelfde vertexkleur als bij de lakshader. Handschoenen en mouwen hebben een stofshader met een weefsel (`shaders/cloth.gdshader`). Vier naadloze normal maps voor wat je van een handbreedte afstand ziet (weefsel, korrel van kunststof, gestraald metaal, ruitjes van een greep) worden uit het manifest gegenereerd (soort `grain`).
- De rode stip van de richtkijker is niet op het glas geschilderd: de shader tekent hem waar de kijklijn door het glas evenwijdig aan de loop loopt, zoals een echte gecollimeerde stip. Hij blijft dus op het doel als het wapen beweegt.
- Het wapen in beeld wordt met een eigen kijkhoek van 58 graden getekend, hoe de kijkhoek van de wereld ook staat ingesteld of ingezoomd: het wordt daarvoor voor de camera zijwaarts en omhoog uitgerekt, wat op hetzelfde neerkomt als een smallere lens. Drie lichten zonder schaduw die alleen het wapen raken houden de vorm zichtbaar waar het level het in het donker laat: een zacht invullicht over de linkerschouder, een licht schuin boven en voor het wapen dat een glimlicht over de bovenkant trekt, en een licht van voorbij de loop dat de omtrek aftekent. Ze reiken niet verder dan het wapen. Tot 10 oktober 2026 was het wapen in beeld een zwart silhouet: de deklagen van wapens, handschoenen en het robotframe stonden op 4 tot 7% helderheid (sRGB), donkerder dan enig echt materiaal, zodat er geen licht was dat er vorm in kon brengen. Ze staan nu op 10 tot 16%, waar zwart kunststof en geanodiseerd aluminium liggen. Wat het kost is niet zuiver te meten geweest: acht runs om en om op 1440p met FSR 2 gaven per standpunt 0 tot 4 fps minder, met de laptop zwaar belast (load 33) en runs die onderling meer uiteenliepen dan dat. Vlak voor een muur wordt het wapen teruggetrokken met de loop omhoog, in plaats van erdoorheen te steken.
- De vijanden zijn drie bewakingsrobots op één skelet (`tools/models/enemies.gd`), 6 tot 9 duizend driehoeken in 16 onderdelen: de grunt met een geweer als onderarm en een schild aan de andere arm, de rusher klein en voorovergebogen met een lemmet aan elke arm, de heavy breed met een draaiend meerloopskanon en de munitie op zijn rug. `scripts/enemy_rig.gd` laat zien wat `scripts/enemy.gd` beslist: de benen stappen in de maat van de snelheid en de richting waarin het lijf beweegt, de wapenarm komt omhoog tot op de speler en slaat terug bij elk schot, alles wat gloeit licht op vóór een aanval, een treffer laat de romp terugdeinzen en oplichten, en een robot die kapot gaat valt in losse stukken uiteen die met physics neerkomen en een paar seconden blijven liggen.

**Wat je ziet als er geschoten wordt**

- **Mondingsvlam.** Een vlam die de shader bij elk schot opnieuw tekent uit een eigen willekeurig getal, zodat geen twee gelijk zijn (`shaders/muzzle_flash.gdshader`): een hete kern met tongen van ongelijke lengte en dunne strepen brandend kruit, van opzij een vlam in de lengte. Elk wapen heeft zijn eigen maat en vorm (`flash_size` en `flash_prongs` in de wapengegevens): vier tongen uit de vlamdemper van de karabijn, een bol uit het pompgeweer, twee stralen opzij uit de mondingsrem van het scherpschuttersgeweer. De vlam licht de omgeving een ogenblik aan en is over het vizier kleiner, zodat hij het doel niet bedekt. Als het schieten stopt, kringelt er rook uit de loop, meer naarmate er langer is gevuurd.
- **Tracers.** Een korte gloeiende streep die met 260 m/s van de loop naar het doel reist, in plaats van een balk die er in één keer staat. De robots schieten rood.
- **Inslagen per ondergrond.** De levelbouwer merkt elke botsvorm met waar hij van gemaakt is (`_surface` in `tools/level_builder.gd`; een model noemt het in het manifest als het geen staal is), en een schot leest dat af van wat het raakt. Beton en baksteen geven een stofwolk, wegspattende scherven en af en toe een vonk; staal een waaier vonken die de kant op gaat waarheen het schot afketst, op de vloer stuitert en van wit naar dofrood afkoelt; hout splinters en fijn stof; zakken, banden en karton alleen een pluimpje.
- **Kogelgaten** zijn echte decals met een eigen normal map, zodat het licht in de krater valt: een uitgebroken krater in beton (rood getint in baksteen), een gat met een rand van blank staal en roet eromheen in staal, dat een kleine seconde nagloeit, en een langs de nerf opengescheurd gat in hout. Ze komen uit het manifest (soort `hole`) en de laatste 80 blijven staan.
- **Een robot die kapot gaat** geeft een lichtflits, een vuurbal, een regen van vonken, rook die een paar seconden blijft hangen en roet op de vloer eronder (soort `scorch`). Een treffer op een robot geeft vonken en een lichtje.
- **Hoe het werkt.** Vonken, scherven en rook komen in salvo's: één mesh van losse vierkantjes waarvan de shader voor elk deeltje uitrekent waar het is uit de tijd sinds het salvo begon, inclusief de stuit op de vloer (`shaders/fx_common.gdshaderinc`). Er wordt dus niets per frame gesimuleerd en een salvo kost het script niets terwijl het speelt. Stof en rook worden belicht zoals de rest van het level: donker in een donkere hoek, oplichtend in een zonnebundel. Alles loopt op één eigen klok (`Fx.time`), die stilstaat als het spel pauzeert en die voor een screenshot op een exact moment kan worden stilgezet.

**Hoe het beeld meebeweegt**

Tot 10 oktober 2026 stond de camera stil op het hoofd: lopen, landen en geraakt worden waren alleen te zien aan het wapen. Dat is nu anders, en alles is klein gehouden: het is er om te voelen, niet om te zien.

- **Eén pas voor alles.** `stride()` in `scripts/player.gd` telt de passen: een heel getal bij elke voet die neerkomt, elke 2,4 m. Het deinen van de camera, dat van het wapen en het geluid van de stap hangen aan dat ene getal, zodat het beeld op zijn laagst is op het moment dat je de stap hoort. Het wapen deinde al, maar op zijn eigen klok: 1,2 keer per seconde tegen 2,1 stappen.
- **Deinen.** Bij elke stap gaat het oog 14 mm op en neer en 6 mm opzij naar de voet die het gewicht draagt, met een rol van 0,2° en een knik van 0,12°. Rennend is het 1,6 keer zoveel, gebukt ruim de helft. Over het vizier blijft een vijfde van de beweging over en geen draaiing, zodat het vizier stilstaat. Het zit op de camera en niet op het hoofd: op het hoofd richten de vijanden, en de helling ervan gaat naar wie meespeelt.
- **Landen.** De knieën veren: het oog zakt in 70 ms tot 88 mm na een gewone sprong en komt terug. Het zakte 142 mm in één frame.
- **Terugslag.** Waar een schot heen gaat is niet veranderd (`add_recoil` en de getallen in `weapons/*.tres`). Wat erbij kwam, verplaatst het richtpunt niet: het wapen in beeld slaat terug op een veer die na 25 ms op zijn verst is en iets doorschiet, elk schot een beetje anders gerold en verschoven, en bij aanhoudend vuur klimt de loop schot na schot (de karabijn 4,8° na een seconde, tegen 2,6°). Van de terugslag was een kwart al weg voor het eerste beeld. Het gezichtsveld springt per schot even open, 0,39° bij de karabijn en 1,65° bij het pompgeweer, en de twee zware wapens laten het beeld 0,2 tot 0,3° rammelen. Over het vizier slaat het wapen niet verder terug dan het deed.
- **Het wapen heeft gewicht.** Het loopt een tiende stap achter op de camera, blijft tot 2° achter bij een draai (ook met de stick, die het eerst niet bewoog), sleept na bij optrekken en stoppen, hangt achter bij springen en vallen, zakt bij een landing en ademt als je stilstaat.
- **Geraakt worden heeft een richting.** `take_damage` kreeg de richting van het schot al mee en deed er niets mee: het beeld schokte een willekeurige kant op, gemiddeld 0,4° in helling en draaiing, even hard voor een schampschot als voor een klap. Nu rolt het hoofd weg van de kant waar het vandaan kwam, 0,4° voor een schot van een grunt en 1° voor 40 schade, met voor een treffer van voren een knik naar achteren. Het richtpunt blijft vrijwel staan. Het signaal `hit_from` geeft de richting door; de HUD tekent er een zachte rode boog voor op een ring om het vizier, die 0,3 seconde staat, in 0,9 seconde vervaagt en meeschuift als je ernaartoe draait. Onder 30% health ademt de rode rand.
- **Explosies** verschuiven het beeld nu ook (tot 12 mm) en trekken het gezichtsveld even open (tot 1,9°), naast het schudden dat er al was.
- **Eén instelling, View motion** (0 tot 150%, `Settings.view_motion`). Op 0 staat de camera volkomen stil: geen deinen, geen overhellen, geen zakken, geen openspringen, geen schudden. Dat is de schakelaar tegen wagenziekte die shooters horen te hebben. Terugslag van het richtpunt, de zoom van het vizier en alles wat de HUD tekent blijven. Het wapen houdt op 0 een derde van zijn beweging: doodstil lijkt het kapot.
- **Het instellingenscherm scrolt.** Het was 1067 van de 1080 beeldpunten hoog en met een regel erbij viel Back van het scherm. De instellingen staan nu in een lijst die meeschuift met wat de focus heeft, tussen een kop en een Back-knop die blijven staan.
- **Hoe het werkt.** Alles wat veert gebruikt `scripts/spring.gd`: een stap is de exacte beweging van de veer over die tijd en geen schatting, zodat een duw er op 45 beelden per seconde hetzelfde uitziet als op 120. De getallen staan elk op één plek, bovenaan `scripts/player.gd` en `scripts/weapons.gd`.

Gemeten op vaste 60 beelden per seconde, zonder scherm; "eerst" is de stand van 10 oktober voor deze wijziging:

| | Eerst | Nu |
|---|---|---|
| Lopen: oog op en neer, opzij | 0 | ±14 mm, ±6 mm |
| Lopen: knik, rol | 0 | ±0,12°, ±0,20° |
| Rennen: oog, knik, rol | 0 | ±22 mm, ±0,18°, ±0,32° |
| Lopen over het vizier: oog, draaiing | 0 | ±1,7 mm, 0 |
| Landen na een sprong | 142 mm in één frame | 88 mm na 70 ms |
| Schot met de karabijn: richtpunt, gezichtsveld, wapen terug | 0,67°, 0, 31 mm | 0,67°, +0,39°, 38 mm |
| Schot met het pompgeweer: gezichtsveld, rammelen | 0, 0 | +1,65°, 0,2–0,3° |
| Treffer van 7 van links | willekeurig, 0,39° gemiddeld | rol 0,41° |
| Treffer van 40 van links | willekeurig, 0,39° gemiddeld | rol 0,96° |

**Niemand heeft het gezien.** Het is gebouwd en gemeten zonder scherm: de getallen zeggen hoe ver iets beweegt, niet of het goed voelt. Ze zijn een eerste gok aan de kleine kant; met View motion is het geheel groter of kleiner te zetten zonder de code in te gaan.

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

**Wat er kapot kan**

- **Kisten en dozen.** Een stapel houten kisten is twee of drie kisten hoog, en elke kist heeft zijn eigen health: 110, wat vijf schoten met de karabijn is of één lading hagel van dichtbij. Een schot raakt de kist op de hoogte waar het aankomt. Een kist die het begeeft vliegt in planken uiteen, wat erop stond valt omlaag en komt met een bons neer, en de botsvorm van de stapel past meteen bij wat er nog staat: dekking wordt lager naarmate er meer in is geschoten. Een stapel die op een andere stapel staat komt mee omlaag. Een kartonnen doos houdt 30. Een klap van een vat of een granaat raakt alle kisten van een stapel tegelijk. Schoten van vijanden doen het ook, net als bij de vaten: wie lang achter een stapel blijft zitten, raakt hem kwijt. De fabriek heeft 38 stapels en 6 dozen, het fabrieksterrein 51 en 16, het depot 29 en 2.
- **De planken** zijn de kist zelf: het model is één keer in tien stukken gesneden, per zijde in planken, en die vliegen als losse lichamen weg, de kant op van het schot of van de klap af. Ze blijven vijf tot zes seconden liggen en krimpen dan weg. Er liggen er nooit meer dan 48; breken er in één klap meer kisten dan dat toelaat, dan laat elke kist minder planken achter in plaats van sommige geen.
- **Lampen.** De hallampen, de peertjes in hun kooi, de tl-buizen, de schijnwerpers van het depot en de lamp boven de draaibank gaan met één treffer uit, en ook door een klap. Het glas komt naar beneden met een regen van vonken, het licht hapert een kwart seconde en is weg, en van een hallamp of een schijnwerper spat het daarna nog een paar keer. Ook een hallamp die al uit was heeft glas om kapot te schieten. De fabriek heeft er 23, het fabrieksterrein 91, het depot 12. De lamp boven de uitgang en het vuur in de ketel horen er niet bij. Een lamp staat niemand in de weg en vijanden raken hem niet: alleen schoten van spelers en klappen vinden hem.
- **Geluid.** Vijf opnames, gemengd uit pakketten die er al waren: `lamp_break`, `bulb_break`, `crate_break`, `box_break` en `crate_drop`. Door de bussen gemeten zitten ze tussen een inslag en een explosie in; een hallamp speelt op -3 dB, een kist op -4. Er is geen opname van karton: `box_break` is het dichtstbijzijnde. **Niemand heeft ze gehoord**: `tools/hear.py crate_break` en de rest.
- **Hoe het werkt.** De levels zijn er niet voor herbouwd en niet opnieuw gebakken. `scripts/breakables.gd` loopt bij het laden door wat de levelbouwer heeft neergezet en geeft alles wat kapot kan een eigen lichaam onder `Level/Breakables`: `scripts/stack.gd` om een stapel, `scripts/lamp.gd` om een lamp. Het werkt daardoor op elk level dat de bouwer maakt. De botsvormen van de stapels verhuizen uit het ene lichaam van het level naar hun eigen (in de fabriek 44 van de 294), want alleen zo kunnen ze krimpen. Een model dat kapot is wordt verborgen en niet weggehaald, om dezelfde reden als bij de vaten: de lightmap zoekt het op bij zijn pad. Schoten en klappen vinden wat kapot kan op een eigen laag (6, `breakable`).
- **Een lamp die uit is.** Alleen de hallamp is een eigen model: daar verdwijnt het glas en dooft het peertje. Bij de rest is wat gloeit een paar driehoeken in een mesh die de lamp met de halve hal deelt. Die worden bij het laden opgezocht, bij het licht waar ze het dichtst bij liggen, en krijgen een donkere kopie van zichzelf die vier millimeter ruimer is en pas te zien is als de lamp kapot is.
- **Samen spelen.** De host beslist en laat het iedereen zien, zoals bij de vaten; wie later binnenkomt krijgt mee welke kisten weg zijn en welke lampen uit, zonder planken en zonder geluid. `VERSION` in `scripts/net.gd` is 4: 3 kwam met wat kapot kan, 4 met het fabrieksterrein tussen de fabriek en het depot.
- **De eerste keer haperde het vier seconden.** De eerste lamp die op deze laptop werd uitgeschoten hield het spel zo lang op: de renderer had nog nooit vallend glas, een lamp zonder glas of de planken van een kist getekend en maakte zich daar klaar voor op het moment dat ze in beeld kwamen. Godot telt zulke momenten: de eerste lamp kostte er twee tot drie, het eerste donkere peertje twee, de eerste kist twee. `Fx.rehearse()` tekent nu bij het laden alles één keer, zes frames lang, een meter voor de camera die op dat moment het beeld maakt en een duizendste zo groot, terwijl het beeld uit het zwart opkomt. Daarna kost breken er geen meer. De eerste versie hing het aan één camera, en dat was bij een level dat vanaf het titelscherm start die van het menu, die weg is voor er een frame getekend wordt: daar deed het dus niets. Dat kwam uit een review; de telling is daarna vanaf het titelscherm herhaald, voor en na. Het geldt meteen voor de splinters, de vonken en de rook van een eerste schot op een muur.
- **De repetitie verschuift de teller van tekenopdrachten.** Nadat alles één keer getekend is, telt de renderer op sommige standpunten een handvol tekenopdrachten meer, met tot op de driehoek hetzelfde aantal driehoeken en dezelfde framerate. Op het fabrieksterrein, 1440p met FSR 2 op 67%: 1236 in plaats van 1230 op het derde standpunt en 611 in plaats van 603 op het vijfde; de andere drie zijn gelijk. Het zit in de repetitie en niet in wat kapot kan: zonder repetitie zijn het de getallen van `bouwdoos`, ook met alle lichamen van kisten en lampen erbij, en met alleen de lege salvo's van de repetitie is het al 1232 en 611. De getallen zijn van run tot run dezelfde. Waarom de renderer daarna anders bundelt weet ik niet. Wie een contactblad naast een ouder legt, moet het weten.
- **Wat het kost.** Zolang er niets kapot gaat: niets. Het opzoeken bij het laden duurt 7 ms in de fabriek en 4 in het depot, en de eerste keer 33 ms doordat de kist en de doos dan in stukken worden gesneden. Een kist breken kost 0,3 ms. Gemeten op 10 oktober 2026, om en om met de stand ervoor:

| | Ervoor | Erna |
|---|---|---|
| Fabriek, 1440p met FSR 2 op 67% | 69,4–76,4 fps | 69,3–76,4 fps |
| Zoals Michiel speelt: 3456×2160, Ultra, MetalFX Spatial | 46,6–51,4 fps | 46,5–51,4 fps |
| Elke seconde een explosie, die nu ook kisten breekt | 63,2–66,6 fps, traagste frame 17,0–17,6 ms | 62,8–66,9 fps, 17,0–17,7 ms |

- **De dekking van de vijanden** was op deze branch gevoelig voor elke verandering aan de botsvormen van het level, en stapels uit dat lichaam halen is zo'n verandering. In alle runs van de selftest bleven vijf van de vijf grunts vanuit dekking vechten; dat was een uitkomst, geen garantie. Sinds 11 oktober zit de fix erin, zie "Dekking die aan het laatste cijfer hing".

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
| De handschoen van de schutter opnieuw bouwen: Blender zonder venster geeft hem vorm en botten, Godot maakt er `scenes/models/glove.scn` van. Met `--sheet=<map>` rendert Blender hem ook in vijf houdingen, op de CPU. Daarna de wapens opnieuw genereren | `tools/build_hands.sh`, dan `tools/build_model.sh weapons` |
| Een wapen bekijken zoals de speler het vasthoudt (nummer in de loadout vanaf 0; `,1` erachter is gericht, `,0,0.4` is 40% van het herladen, `,0,0,0.36` is 36% van een klap met het wapen) | `tools/benchmark.sh --quick --weapon=2 --at="2,1.7,3,-120,0"` |
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
| Gameplay en alle levels testen (headless) | `tools/selftest.sh` |
| Alleen testen hoe het beeld meebeweegt, of alleen wat er kapot kan (elk een paar seconden na het laden) | `tools/selftest.sh --view` of `--breaks` |
| Alleen testen wat de vijanden in een gevecht doen en wat er te vinden is (50 seconden). Met `--map` erbij de dekking in de fabriek als plattegrond, met `--trace` wat één grunt van stap tot stap doet | `tools/selftest.sh --fights` |
| Alleen de routes door de levels testen, met een lijst van waar elke robot verschijnt: het deel om te draaien terwijl je aan een level bouwt (25 seconden) | `tools/selftest.sh --routes` |
| Samen spelen testen: het spel twee keer zonder venster, één host en één gast (35 seconden) | `tools/nettest.sh [--enemies=<thema>]` |
| Een medespeler bekijken zoals een ander hem ziet (houding 1 richt, 2 loopt, 3 rent; de tiende kiest het wapen) | `tools/benchmark.sh --quick --spawn="res://scenes/puppet.tscn@1,0,-7.4,-90,1,2.2" --at="4.2,0.9,-7.4,90,0"` |
| Het spel zelf bekijken zoals het gespeeld wordt, met HUD en menu: een screenshot na zoveel seconden. `--at` zet de speler ergens neer, `--eval` voert een regel script uit; de save blijft ongemoeid | `tools/godot.sh -- --play --snap=5 --at="-7,0,0.5,90,4"` of `--snap=4 --eval="Menu.show_end(27)"` |
| Iets kapot laten gaan en kijken wat ervan overblijft. Stapels en lampen heten `Stack0`, `Lamp0` en zo verder onder `Level/Breakables`; `take_blast` breekt een hele stapel en zet een lamp uit. De regel wordt na één seconde uitgevoerd, het beeld is van `--snap` seconden na de start | `tools/godot.sh -- --play --snap=3 --at="1.2,0,-0.8,-22,-4" --eval='game.get_node("Level/Breakables/Stack10").take_blast(1000.0, Vector3(0,0,0), Vector3(-0.6,1,0.3))'` |
| De geluiden van breken horen | `tools/hear.py lamp_break`, `bulb_break`, `crate_break`, `box_break` of `crate_drop` |
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

- De klap met een leeg wapen is één beweging van het hele wapen, voor alle vijf dezelfde; hij is op screenshots van losse momenten bekeken, niet in beweging.
- De wapens, de handen en de vijanden zijn gebouwd en niet gescand of gegenereerd. De handen hebben sinds 11 oktober 2026 een skelet en vingers die bij het herladen bewegen (zie "De wapens opnieuw", ook voor wat daar nog aan open staat). De robots lopen procedureel en hebben geen ingestudeerde animaties. Zodra er een generatiedienst is die bruikbare topologie en rigs levert, zijn dit de eerste om te vervangen; de gameplay hoeft daarvoor niet te veranderen, want die kent een wapen en een vijand alleen als een scène met een paar benoemde onderdelen.
- Poly Haven heeft geen kubusvormige krat; de kratstapels bestaan daarom uit langwerpige kisten.
- De machines, containers, tanks en kraan zijn gebouwd en niet gescand. Zodra er een generatiedienst is, zijn na de wapens en de vijanden de machines aan de beurt.
- Poly Haven heeft sinds juli 2026 een bovenloopkraan met een overspanning van 12,5 m. De kraan in de hal overspant 23 m en is daarom in code gebouwd.
- De schakelkasten zijn straatkasten die 1,45 keer vergroot zijn; van dichtbij zijn de waarschuwingsstickers daardoor te groot.

## De wapens opnieuw: echte maten en handen met een skelet

De wapens en de handschoenen waren het zwakste wat er te zien is, en ze staan altijd in beeld: een rail van losse blokjes, een vizier van vier balkjes, een steunhand als glad vlak met een duim, vingers die bij het herladen niet bewegen. Op 11 oktober 2026 is eerst alleen de karabijn opnieuw gedaan, langs twee wegen om naast elkaar te leggen. Michiel koos weg (a), verfijnen in code; daarna zijn de andere vier wapens op dezelfde manier gedaan.

**Weg (a): verfijnen in code**

- **De karabijn** is een AR-15 met een loop van 14,5 inch, op de maten van het echte wapen: de bovenkant van de rail 30,7 mm boven de loop, een upper van 33 mm breed met ronde schouders en een hals waar de rail op staat, een lower van 30 mm. De rail is geen rij blokjes meer maar het echte profiel (MIL-STD-1913, `_picatinny` in `tools/models/weapons.gd`): een zwaluwstaart van 21,2 mm breed met een sleuf van 5,2 mm om de 10 mm, 3 mm diep. Het vizier heeft een behuizing met de batterij achter en een kap met ronde hoeken om het glas, met twee knoppen naar de schutter toe, een klem met hendel en stelschroeven. Verder: klapvizieren met scharnier en stelwiel, de laadhendel met zijn pal, een borgmoer met nokken en een eindplaat om de kolfbuis, een kolf met huls, kolfplaat en schoor waartussen de driehoek open is, ribben voor en achter op het magazijn, een uitlopende magazijnschacht, schroeven in de handguard.
- **Afgeschuinde randen.** `_chamfer` snijdt van een omtrek elke hoek die uitsteekt af, zodat wat ervan gemaakt wordt daar een vlakke afschuining heeft in plaats van een scherpe rand. De slijtageshader ziet die randen en slijt ze blank, zoals bij de rail goed te zien is.
- **De handschoen is in Blender gemaakt**, zonder venster (`tools/models/hands.py`, `blender -b`). De vorm is niet gemodelleerd maar beschreven: voor elk punt in een blok ruimte hoe ver het van de dichtstbijzijnde van een stel afgeronde vormen ligt (een vingerkootje, de middenhandsbeentjes, de duimmuis), waarbij de vormen in elkaar overvloeien waar ze elkaar raken. Het oppervlak is waar die afstand nul is; OpenVDB, dat met Blender meekomt, maakt er driehoeken van. De platen op de knokkels en de vingers, het dubbele stuk in de vork van de duim en de band om de pols zijn hetzelfde oppervlak een paar millimeter verder naar buiten, op hun omtrek afgesneden; de mouw is een buis waarvan de omvang rimpelt. Samen 16,8 duizend driehoeken per hand.
- **Het skelet** heeft 17 botten: hand, onderarm, drie per vinger en drie voor de duim. De hand rust ontspannen, niet plat, zodat een greep en een open hand er even ver vanaf liggen. Welk bot een punt van het oppervlak draagt, rekent het script zelf uit langs de lijn waar het omheen ligt: het automatische wegen van Blender liet de vingerbotten de rug van de hand meetrekken. Een plaat volgt wat de handschoen eronder volgt.
- **`tools/build_hands.sh`** laat Blender de hand bouwen en Godot er `scenes/models/glove.res` (het mesh met zijn drie materialen) en `scenes/models/glove.scn` (het skelet met dat mesh erop) van maken, in twaalf seconden. Alleen dit heeft Blender nodig; `tools/build_model.sh weapons` werkt met wat het achterlaat. Met `--sheet=<map>` rendert Blender de hand in vijf houdingen op de CPU, om hem te bekijken zonder het spel te starten.
- **Een hand sluit zich zelf.** `_glove` in `tools/models/weapons.gd` legt de handpalm tegen wat hij vasthoudt, op een plek rondom en in de richting van de pols, en buigt dan elke vinger gewricht voor gewricht tot het kootje raakt (`Grasp`). De duim doet hetzelfde of volgt een pad, net als de wijsvinger van de schiethand, die langs de kast ligt. De hand heeft één maat: de oude handen rekten mee met wat ze vasthielden. Een linkerhand is de rechter in een spiegel. Dezelfde regels sluiten de hand om elk ander wapen; alleen de plek van de palm is per greep gekozen.
- **Herladen met vingers.** De handschoen bewaart zijn grepen (`holds`): om de handguard, om het magazijn, en los. Bij een magazijnwissel laat de linkerhand de handguard los, gaat open, pakt het magazijn van links met de vingers om de voorkant en de duim erachter, neemt het mee naar beneden en komt met het volle terug (`Viewmodel.reach` in `scripts/weapons.gd`). Wanneer het magazijn eruit gaat en erin komt is niet veranderd.
- **De andere vier wapens** dragen dezelfde handschoen, die zich om elk van hun grepen sluit, en hebben de echte rail en afgeschuinde randen gekregen waar ze die hadden:
  - het **pompgeweer**: een kast met ronde bovenkant en een ingelaten trekkerplaat, de ghost ring tussen twee oren op de rail, een hitteschild van geperforeerd plaatstaal over de loop, een kolf met afgeschuinde randen. De steunhand gaat met de pomp mee; bij het laden komt hij met een patroon onder de kast en duwt het met de duim naar binnen (greep `shell`);
  - de **pistoolmitrailleur**: een achtkantige kast van geperst staal met de rail erop, een uitlopende magazijnschacht, een diopter tussen oren en een korrel in een ring, elk op de rail geklemd, een handstop, een kap achterop waar de draadkolf in zit;
  - het **scherpschuttersgeweer**: de kasten van de karabijn een maat groter, twee rails, de handguard met sleuven op alle acht vlakken, een mondingsrem met afgeschuinde hoeken, ringen met schroeven om de kijker, een wangstuk op de kolf, ribben op het magazijn;
  - het **pistool** is zelf niet veranderd. De rechterhand ligt om de greep met de duim naar links, de linker ertegenaan met de vingers over die van de rechter; bij het herladen gaat de linker onder de greep en pakt het magazijn.
- **De stof vangt licht langs zijn rand** (`shaders/cloth.gdshader`): een zwarte handschoen in een donkere hal was anders alleen een silhouet. Het geldt voor gladde stof en niet voor de mouw, die er lichter en geler van werd dan hij is.

**Weg (b): een bestaand CC0-model**

- **Er is geen CC0-pakket met realistische armen, een karabijn en een herlaadanimatie.** Gezocht op Sketchfab, Poly Haven, Poly Pizza, itch.io, BlenderKit, OpenGameArt en GitHub: wat er als geheel is, is low-poly of retro en heeft hooguit een schietanimatie; wat realistisch is en armen heeft, is CC-BY of heeft een eigen licentie. Het dichtst erbij komt een combinatie van twee losse bronnen, die Michiel heeft goedgekeurd (samen 7,6 MB):
  - het wapen: "M4A1 Assault Rifle" van 3DModelsCC0, waarvan de eigen site niet meer bestaat; de kopie staat op https://opengameart.org/content/m4a1-assault-rifle met "Public Domain CC0" erbij. `m4a1_0.zip`, 3,6 MB (sha256 `ed5779ec82718861964227e2aad2a900978ea087081154365d6d86246be62f0d`): een FBX van 9,2 duizend driehoeken in dertien losse onderdelen en één set texturen van 2048 beeldpunten;
  - de handen: die van Godot XR Tools door DigitalN8m4r3 (Miodrag Sejic), map `addons/godot-xr-tools/hands` op GitHub, met een eigen `License.md` die er CC0 1.0 van maakt. Gebruikt: `Hand_Glove_R.gltf` (3,5 duizend driehoeken, 26 botten) met de drie texturen van de vingerloze camouflagehandschoen, 3,9 MB.
- **Hoe het ernaast is gelegd.** Buiten de repo, in een kloon van de worktree: een script zet het wapen met de loop op de as en de trekker waar die van de andere karabijn zit, maakt van magazijn en grendel losse onderdelen, en sluit de gevonden hand met dezelfde regels als de eigen handschoen (palm ertegen, vingers dicht tot ze raken). De gevonden hand houdt bij de pols op; de mouw is die van weg (a). Script en bronnen staan in `benchmark/results/weg-b/`, niet in git. Er is niets van geïmporteerd of in het manifest gezet: de texturen zitten onverpakt in één scènebestand van 16 MB. Dat is genoeg om te kijken, niet om uit te leveren.
- **Wat het laat zien** (derde rij van `benchmark/results/bladen/karabijn.png`): het wapen heeft een fijner silhouet dan wat in code is gebouwd (een handguard met vier rails, de driehoek van het voorvizier, een opgeklapt achtervizier) en slijtage die erop geschilderd is, maar geen richtkijker, dus geen rode stip, en niet de shader die randen blank slijt: van dichtbij is het vlakker. De hand is een blote hand met een vingerloze handschoen; de vingertoppen steken in de donkere hal fel af. Hij is in rust gespreid en sluit daardoor minder net dan de eigen handschoen.
- **Wat (b) verder zou vragen:** voor de andere vier wapens moet elk nog een CC0-model gevonden worden (daar is niet naar gezocht), en geen van de gevonden modellen brengt een animatie mee: het herladen blijft in beide wegen van ons.

**Wat het kost.** De handen zijn van 11,9 naar 33,6 duizend driehoeken gegaan (16,8 duizend per hand, voor elk wapen dezelfde), in evenveel tekenopdrachten als eerst:

| Wapen in beeld, in duizenden driehoeken | Ervoor | Erna | Waarvan het wapen zelf |
|---|---|---|---|
| Karabijn | 20,0 | 46,1 | 8,1 → 12,5 |
| Pistool | 14,1 | 35,8 | 2,2 → 2,2 |
| Pompgeweer | 16,1 | 40,0 | 4,2 → 6,4 |
| Pistoolmitrailleur | 16,0 | 39,5 | 4,1 → 5,9 |
| Scherpschuttersgeweer | 19,8 | 45,2 | 7,9 → 11,6 |

Gemeten op 11 oktober 2026 in de fabriek met het wapen in beeld (`--weapon=N --at="2,1.7,3,-120,0"`), om en om met de stand ervoor in een kloon ernaast, terwijl drie andere sessies bouwden en maten (load 3 tot 8):

| | Ervoor | Erna |
|---|---|---|
| Karabijn, zoals Michiel speelt (3456×2160, Ultra, MetalFX Spatial), drie ronden | 53,0 / 52,9 / 53,0 fps | 52,2 / 52,2 / 52,0 fps |
| Karabijn, 1440p met FSR 2 op 67%, drie ronden | 75,2 / 75,1 / 75,3 fps | 74,2 / 74,0 / 74,0 fps |
| Pistool, zoals Michiel speelt, twee ronden | 52,8 / 53,4 fps | 52,8 / 52,4 fps |
| Pompgeweer, idem | 52,4 / 52,5 fps | 51,6 / 52,2 fps |
| Pistoolmitrailleur, idem | 52,9 / 51,8 fps | 52,2 / 52,2 fps |
| Scherpschuttersgeweer, idem | 52,8 / 49,5 fps | 51,2 / 51,9 fps |

Bij de karabijn is dat 1 fps, 0,2 tot 0,3 ms. Bij de andere vier ligt het tussen niets en 1 fps; die metingen zijn onrustiger (in twee ervan zit een ronde waarin een andere sessie de 1% low van de stand ervoor naar 29 en 46 fps trok). Aan de driehoeken ligt het niet: een handschoen met de helft ervan (9,2 duizend per hand), in een kloon ernaast gezet, haalde in de enige rustige ronde van drie 52,3 fps tegen 52,2. Of het het skelet is, of dat een mesh met botten voor de upscaler twee keer wordt doorgerekend, is niet uitgezocht. De hele selftest, de test van de mensachtige vijanden en die van samen spelen slagen. Wat een ander draagt heeft dezelfde merktekens voor de handen als eerst en is met het wapen meegegroeid.

**Niet kunnen beoordelen, en nog open**

- **Niemand heeft het in beweging gezien.** Alles is op losse beelden bekeken: per wapen een blad met voor en na in rust, gericht en op drie momenten van het herladen (`benchmark/results/bladen/`, niet in git; op dat van de karabijn staat weg (b) eronder) en renders op de CPU. Hoe de hand loslaat, het magazijn of een patroon pakt en terugkomt is op drie momenten bekeken, niet als beweging; op 40% van een magazijnwissel is de hand met het magazijn onder beeld, net als voorheen.
- **De schiethand** ligt om de greep met de wijsvinger langs de kast en beweegt niet: hij gaat niet naar de trekker bij een schot. Vanuit de schutter is hij nauwelijks te zien.
- **De hand is stijf waar een echte meegeeft.** De palm is één stuk: om de handguard ligt hij er vlak tegenaan in plaats van eromheen. Waar een gewricht ver buigt, vouwt de binnenkant in zichzelf; dat zit tegen het wapen aan.
- **Er zit geen patroon in de hand** die het pompgeweer laadt: de hand komt bij de laadopening en gaat weer, het patroon moet je erbij denken. Hetzelfde geldt voor de magazijnen: de hand pakt het magazijn dat erin zat en komt met hetzelfde terug.
- **Het pistool** heeft als enige zijn oude model gehouden; alleen de handen zijn nieuw.
- **Wat een ander draagt** (`*_held.scn`) is met de wapens meeveranderd, zonder handen; `_gloved()` in `tools/models/held.gd` houdt de handschoen daar weg. De test van de mensachtige vijanden en die van samen spelen slagen ermee, maar niemand heeft een vijand met het nieuwe pompgeweer bekeken.
- **Het grove korreltje op de kast** komt uit `materials/gun_receiver.tres` (een gestraalde korrel van ruim een millimeter). Dat bestand hoorde niet bij deze opdracht; fijner zou meer op geanodiseerd aluminium lijken.

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
- ~~De galm is op elke afstand even sterk ten opzichte van het directe geluid.~~ Sinds 11 oktober niet meer: zie "Geluid: ruimte, omgeving en stemmen".
- ~~De kamers waarin de galm omschakelt zijn dozen met vaste coördinaten in `scripts/sfx.gd`.~~ De galm wordt sinds 11 oktober uit de zones gelezen.
- ~~Geluid dat nog klinkt als je naar het titelscherm gaat of opnieuw begint vanaf een checkpoint, klinkt verder aan het begin van het volgende spel.~~ Opgeruimd op 11 oktober.
- De begrenzer van Godot komt na een ingreep nooit helemaal terug (0,2 dB van elke 3 dB blijft staan). Daarom blijft de mix eronder en hoort hij alleen bij uitschieters in te grijpen.
- De vuursnelheid wordt afgerond op hele frames: op 60 fps vuurt de pistoolmitrailleur 720 in plaats van 900 schoten per minuut en de karabijn 600 in plaats van 620 (nagerekend, niet in het spel gemeten).
- Elk wapen heeft drie tot vijf takes.
- ~~Robots hebben geen stem en de stemmen van personages zijn gesynthetiseerd; er is geen omgevingsgeluid, geen muziek en geen geluid van een schot dat langs je heen gaat.~~ Zie "Geluid: ruimte, omgeving en stemmen".
- ~~De galm kent het ketelhuis en de doorgang van de fabriek niet: daar klinkt het als in de hal.~~ Elke zone heeft nu haar eigen galm.

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

**Stand op 10 oktober 2026.** Punt 2, 3 en 4 zijn gedaan en door Michiel op het oor goedgekeurd: het scherpschuttersgeweer en het pompgeweer hebben hun knal terug en een staart (de opname op afstand op volle lengte, echo's en een nieuwe laag `rumble`), het pompgeweer heeft het lichaam van een Winchester Model 12 eronder en zijn pomp na het schot, en elk wapen herlaadt met opnames uit drie nieuwe CC0-pakketten van OpenGameArt (2,6 MB). De karabijn en de pistoolmitrailleur herladen met het pistool, vertraagd: een eigen opname is er niet. Daarna ook punt 1 en 5, uit drie CC0-pakketten met algemene geluiden van metaal en zwiepen (4 MB), op meting gekozen en door Michiel goedgekeurd: de huls is klein helder metaal dat valt, de huls van het pompgeweer heeft een eigen, doffer geluid, de pin is een veer met een sleutelring erover, de worp een vertraagde zwiep en het stuiteren zwaar metaal dat harder klinkt naarmate de granaat harder neerkomt. Een huls maakt één geluid dat over zijn stuiters doorrinkelt, niet twee tikken; de rol van een granaat die blijft liggen is er niet. `dry_fire`, `switch` en `slide` zijn nog gesynthetiseerd. De drie tonen van de hitmarker zijn weg: Michiel vond ze niet passen, en drie opgenomen tikken ervoor in de plaats ook niet (te aanwezig, het verkeerde soort geluid). Een treffer hoor je nu alleen aan de inslag op de vijand zelf, metaal bij een robot en dof bij een mens; de HUD markeert hem. Het oppakken van munitie, een cel en een granaat is een opname geworden en zachter, een huls is 12 dB zachter gezet. Wat Michiel daarna nog als synthesizer hoorde bij een treffer waren de stemmen van de soldaten: hij speelt met dat thema. Personages hebben nu opgenomen stemmen uit een CC0-pakket met vier mannenstemmen (9,7 MB): een korte grunt bij een treffer, een roep bij het zien van de speler en een kreun bij het sterven (de lange kreten waren te heftig), en hun stappen, hun val en hun slag zijn opnames uit de pakketten die er al waren. De plaat van een grunt is een klap op staalplaat geworden. Zombies en clowns hebben nog gesynthetiseerde stemmen, de robots hun alarm, oplaadtoon en roepen. Van punt 6 staat alles behalve het nummer: `Sfx.music()` speelt een stuk uit `assets/music/` (`.ogg` of `.mp3`, als stroom van schijf) in een lus op de bus Music, het titelscherm vraagt om `theme` en laat het in 1,5 s uitsterven zodra er gespeeld wordt, en Settings heeft een schuif Music. Zonder bestand is het stil. Nog niet gedaan: het nummer zelf, het op luidheid brengen ervan (er is geen encoder voor Ogg op deze machine; een nummer wordt gebruikt zoals het wordt aangeleverd) en de compressor op de bus, die pas zin heeft als er iets is om naar te luisteren. Sinds dezelfde dag zijn er twee nummers van Michiel, mp3's van 5 MB die worden gebruikt zoals ze zijn aangeleverd: `theme` op het titelscherm en `level1and2` in de fabriek en het depot, 9 dB zachter en doorlopend van het ene level in het andere. Waar ze vandaan komen en onder welke licentie staat nog niet in het manifest. Muziek voor latere levels komt later.

**Volgorde.** Stap 0, dan 4 en 3 (alleen het manifest, geen nieuwe bron), dan de bron zoeken en 2, 1 en 5 in één keer, dan 6. Na elke stap `tools/hear.py` voor Michiel: hij oordeelt op het oor.

**Wat het kost.** Punt 3 en 4 zijn regels in het manifest en opnieuw bouwen. Punt 1, 2 en 5 zijn een nieuw pakket, zo'n 25 takes erbij (ongeveer 1,5 MB in `assets/audio/`) en code in `weapons.gd`, `weapon_data.gd`, `fx.gd` en `grenade.gd`. Punt 6 is één bestand van 3 MB, een functie in `sfx.gd`, een schuif en een keuze van Michiel.

## Geluid: ruimte, omgeving en stemmen

Op 11 oktober 2026 gevraagd, gebouwd op de branch `geluid`: omgevingsgeluid per soort ruimte, een kogel die rakelings langsgaat, een eigen geluid voor de roldeur, opnames voor de drie geluiden die nog gesynthetiseerd waren, stemmen voor zombies, clowns en robots, galm die met de afstand toeneemt en uit de zones van een level wordt afgelezen, en het afspelen van een tweede muzieklaag die aanzwelt bij een gevecht.

**Wat Michiel hoorde.** De eerste versie kwam uit de pakketten die er al waren. Die heeft hij dezelfde dag onderdeel voor onderdeel beluisterd met `tools/hear.py`: "bijna allemaal goed". Niet goed: de kogel die langsgaat ("heel nep"). Erbij gevraagd: een eigen geluid voor het checkpoint, "een soort diep inademen", en het wisselen van wapen droger, in de richting van `dry_fire`. Daarna zijn de acht voorgestelde pakketten opgehaald en zijn de bedden, de stemmen, de roldeur en het wisselen daaruit opnieuw gebouwd. Voor de kogel heeft hij zelf een opname van Freesound gehaald, en voor het checkpoint is er een negende pakket bij gekomen. **Ook die tweede versie heeft hij beluisterd en goedgekeurd** (11 oktober 2026): de kogel, het checkpoint, de robot die praat, de zombie, de lach van de clown, de vijf bedden, de roldeur en het wisselen, en het aanzwellen van de tweede muzieklaag. Wat hij niet apart genoemd heeft is de galm op afstand en per zone, die hij bij de eerste ronde hoorde. Daarna is de branch in de trunk gevoegd en gepusht.

**Waar de nieuwe opnames vandaan komen.** Negen pakketten van opengameart.org, alle CC0, samen 16 MB in `.cache/sounds/`, met adres en checksum in het manifest, en één opname van Freesound:

| Pakket | Maker | Gebruikt voor |
|---|---|---|
| 30 CC0 SFX loops (3,4 MB) | rubberduck | De bedden: een grote ruimte met installaties, machines, een pomp, kokend water |
| Steam release sounds (0,6 MB) | bart | Een klep die afblaast in het ketelhuis |
| wind whoosh loop (0,2 MB) | SketchMan3 | De wind op het terrein |
| Zombies Sound Pack (4,6 MB) | artisticdude | De stem van een zombie, 20 van de 24 geluiden |
| Evil Laughs Pack (2,1 MB) | Eldritch Grim | De lach van een clown |
| Robot Voice Pack (3,7 MB) | Cough-E | Wat een robot zegt, zes van de twintig zinnen |
| old elevator door (0,1 MB) | sinny | De roldeur |
| Mechanical Sounds (0,4 MB, negen losse bestanden) | BMacZero | De ratel en de pal van de roldeur, de tweede klik van het wisselen |
| Breathing Tired (0,5 MB) | mikeask | De adem bij een checkpoint |
| Bullet Fly By (3,4 MB, freesound.org/people/GO_s0unds123/sounds/730351/) | GO_s0unds123 | De kogel die langsgaat. Freesound vraagt een account: Michiel haalde hem zelf, en hij staat daarom als bestand in `assets/recordings/` |

Voor de bedden is `oggenc` geïnstalleerd (`brew install vorbis-tools`, 5,7 MB met vier bibliotheken).

**Wat er nu is**

- **Galm uit de zones.** De vaste dozen in `scripts/sfx.gd` zijn weg. Bij het laden leest `Sfx` van elke zone van het level de dozen (`bounds`) en, als de zone als ruimte is aangelegd, wat voor ruimte het is (`space`). Hoe lang een ruimte naklinkt volgt uit haar inhoud gedeeld door haar oppervlak, zoals bij Sabine: `0,908 × (V/S)^0,889` seconden onder 1 kHz, gepast op de twee ruimtes die op meting en op het oor waren afgesteld, de hal van de fabriek (2,6 s) en de aanbouw (1,0 s). Die twee klinken dus precies als voorheen; al het andere ligt ertussen of eronder. Helderheid en niveau van de galm schuiven mee tussen "kamer" en "hal". Een zone onder de open lucht krijgt een echo waarvan de afstand uit haar grootte volgt (het terrein van de werkplaats 163 ms, de schakeltuin van de centrale 148 ms). Buiten elke zone, door een raam of over een muur, blijft het klinken als de zone die je verliet.

| Zone | Was | Nu |
|---|---|---|
| Fabriek, hal | hal, 2,6 s | 2,6 s |
| Fabriek, aanbouw | kamer, 1,0 s | 1,0 s |
| Fabriek, ketelhuis | als de hal, 2,6 s | 1,4 s |
| Fabriek, doorgang | als de hal, 2,6 s | 0,6 s |
| Centrale, turbinehal | hal, 2,6 s | 2,3 s |
| Centrale, ketelhuis | hal, 2,6 s | 2,1 s |
| Centrale, kabelgang | kamer, 1,0 s | 0,6 s |
| Werkplaats, montagehal | hal, 2,6 s | 2,1 s |
| Werkplaats, kantoor | kamer, 1,0 s | 0,9 s |

  `tools/test_sound.sh --zones` geeft de hele lijst, 43 zones in vier levels.
- **Een level zonder zones** (het depot, de showroom) wordt afgetast vanaf de camera, vier keer per seconde: is er een dak, en hoe ver zijn de wanden. Geen dak, of een dak met twee open zijden: buitenlucht. Anders een ruimte van die maten. Het poortgebouw van het depot is zo een kamer zonder dat iemand zijn coördinaten kent.
- **Meer galm van verder weg.** Tot 8 m is er niets veranderd: het geluid en zijn galm zakken samen. Voorbij 8 m zakt alleen het geluid zelf nog, met 6 dB per verdubbeling; de galm blijft zo luid als hij op 8 m is, tot 24 m, en zakt daarna ook. Een hal antwoordt immers niet zachter omdat de bron verder weg staat. Dat loopt over een nieuwe bus `Far` met een eigen galm (alleen nat, even afgesteld als die op World): een geluid van voorbij 8 m speelt daar een tweede keer, zonder afstandsdemping, op het niveau dat ontbreekt.

| Schot van een robot, in de hal | 8 m | 12 m | 16 m | 20 m | 30 m |
|---|---|---|---|---|---|
| Geluid zelf tegenover zijn galm, voorheen | +5,5 dB | +5,4 | +5,3 | +5,3 | +5,3 |
| Nu | +5,5 dB | +1,8 | -0,7 | -2,7 | -4,3 |
| Alles samen, tegenover voorheen | 0 dB | +1,1 | +2,2 | +3,4 | +4,5 |

  Op 16 m zijn schot en galm even sterk, op 20 m is het vooral de hal. Buiten is het minder: op 20 m is het schot daar nog 2 dB sterker dan zijn echo.
- **Omgevingsgeluid.** Vijf bedden: hal, kamer, terrein, ketelhuis en turbinehal, elk een lus van 30 s die zonder naad rondgaat, als Ogg van 0,4 MB, op een eigen bus `Ambience` zonder galm of clipper. In elk bed liggen opnames van verschillende lengte over elkaar, elk in zichzelf rondgevouwen, zodat ze nooit twee keer hetzelfde samenvallen: de hal is een opname van een grote ruimte met een dreun en een machine in de verte; het terrein is wind, twee keer op twee snelheden, met vlagen erover; het ketelhuis kokend water, branders, een pomp en stoom; de turbinehal een brommende en een draaiende machine met het gesuis van de sets erboven. Welk bed een zone heeft volgt uit wat voor ruimte ze is; een zone met "boiler" of "turbine" in haar naam krijgt het ketelhuis of de turbinehal. Wat je hoort is het bed van de zone waar je staat, en daaronder dat van elke zone die van daaruit te zien is: 8 dB zachter op de drempel en 1,2 dB zachter per meter daarvandaan. De turbinehal hoor je dus aankomen. Om de 6 tot 16 s klinkt er iets in de ruimte zelf, op 9 tot 22 m van de camera: een klap op metaal in een hal, een klep die afblaast in het ketelhuis (een opname van stoom), een schakelaar die invalt in de turbinehal. Op het titelscherm en in het pauzemenu staat het stil.

| Bed | Niveau (RMS) | Onder 80 Hz | 80 tot 250 | 250 tot 1000 | Daarboven |
|---|---|---|---|---|---|
| Kamer | -40 dBFS | 16% | 68% | 16% | 1% |
| Hal | -32 dBFS | 11% | 58% | 30% | 1% |
| Terrein | -33 dBFS | 4% | 12% | 81% | 2% |
| Ketelhuis | -27 dBFS | 16% | 40% | 32% | 13% |
| Turbinehal | -24 dBFS | 21% | 39% | 34% | 6% |

- **De roldeur.** `Sfx` kijkt zelf naar de deuren van de uitgang (de groep `exit_door`) en speelt `roller_door` vanaf de deur zolang die beweegt; `scripts/game.gd` is er niet voor aangeraakt en speelt aan het eind nog zijn eigen klap. Een deur die in één keer ergens anders staat, zoals bij het laden met de uitgang al open, maakt geen geluid. Het geluid is de deur van een oude lift die openschuift, vertraagd tot een zwaardere, met een pal die losschiet, lamellen en een ratel erover en een motor eronder.
- **Een kogel die langsgaat.** `Sfx.passing(van, naar)`: gaat een schot binnen 3 m langs de camera en minstens anderhalve meter verder, dan klinkt `whiz` op het punt waar het het dichtst langskwam, dus links of rechts, harder naarmate het dichterbij was. Een schot dat bij de camera eindigt was raak en een schot dat ervoor eindigt trof de muur ertussen: die hoor je niet langsgaan. Niet vaker dan eens per 70 ms. Het geluid is een opname van kogels die langsgaan: in de 18 s van "Bullet Fly By" zitten er zes, waarvan de vier korte zijn gebruikt zoals ze zijn (0,3 tot 0,45 s, de piek na 60 ms, driekwart van de energie boven 2,5 kHz). De twee eerdere pogingen waren in elkaar gezet: een zwiep met dalende toon en een sis, die "heel nep" klonk, en daarna een knal zonder lichaam met een ruk lucht, die niemand gehoord heeft.
- **Het checkpoint** speelde de gesynthetiseerde tik van het herladen en heeft nu een eigen geluid, `checkpoint`: diep inademen, en het begin van het uitademen. De opname is van iemand die buiten adem is, met ademstoten van een derde seconde. Eén daarvan op 58% van de snelheid is de adem van een grotere borstkas, en achterstevoren zwelt hij aan en houdt hij abrupt op, wat inademen doet; het is dus een bewerkte adem, geen opname van diep inademen. 0,65 s in, een pauze, en zacht 0,7 s uit.
- **De drie die gesynthetiseerd waren.** `dry_fire` is een klik uit de opname van uitrusting met een doffere tik eronder. `switch` is diezelfde klik als het ene wapen loskomt en een tiende seconde later de klap van het andere dat vastzit; de eerste versie, rammelende uitrusting over een mouw, is vervangen. `slide` is een stap in sneeuw op 70% snelheid met geritsel, een dreun en ruis eronder zolang de sliding duurt. Gesynthetiseerd zijn nu alleen nog `reload` en `reload_end`, de terugval van een wapen zonder eigen herlaadgeluid.
- **Stemmen.** Een zombie is nu een opname van een zombie: de korte bij een treffer, de middellange bij het zien van de speler, de lange bij het sterven, iets vertraagd. Een clown lacht met de eerste anderhalve seconde van een lach, een vijfde sneller; zijn kreet bij een treffer, zijn val en zijn paniek zijn de mannenstemmen, sneller en neuziger, zoals in de eerste versie. Een robot zegt wat hij doet, in de stem van een machine: "target acquired" of "target found" als hij de speler ziet, "target out of sight" of "where did you go" als hij omtrekt, "taking cover" of "I need backup" als hij ergens voor vlucht. Die stem zat vrijwel geheel onder 600 Hz; hij is boven 280 Hz afgesneden en hard in een clip geduwd, zodat een derde van zijn energie nu tussen 600 en 2500 Hz ligt en hij te verstaan blijft. Voor een salvo loopt per soort een motor op, zo lang als de waarschuwing duurt. Een thema zegt per rol wiens stem zijn mensen hebben (`"voice"` in `assets/characters/manifest.json`); zonder dat klinkt iemand zoals hij beweegt. Daardoor klinken de zombies die rennen nu ook als zombies: die hadden de stem van een mens.
- **De tweede muzieklaag.** Ligt er naast `assets/music/<stuk>.mp3` een `<stuk>_fight.mp3` (of `.ogg`), dan start die tegelijk met het stuk, onhoorbaar, en zwelt in 1,2 s aan tot het niveau van het stuk zodra het level zegt dat er gevochten wordt (`fighting()` in `scripts/game.gd`); 5 s na het gevecht is hij weer weg. Het stuk zelf blijft zoals het is. De twee bestanden moeten even lang zijn: elk loopt in zijn eigen lus rond. Het aanzwellen heeft Michiel gehoord en goedgekeurd met het thema als proeflaag (`tools/hear.py music level1and2 --layer=assets/music/theme.mp3`). In `assets/music/` ligt nog geen `level1and2_fight`: tot die er is, blijft de laag in het spel stil.
- **Wat bleef doorklinken.** Een geluid dat nog klonk bij het verlaten van een level ging verder aan het begin van het volgende spel. `Sfx` ruimt nu op bij elke wissel van level.
- **Gereedschap.** `tools/hear.py` kan een geluid van een afstand laten horen (`--at=20`), in een andere ruimte (`--in=room`, `--in=powerhouse/turbine_hall`), en heeft `ambience <soort>`, `door`, `whiz`, `voice <wie>` en `music <stuk>`. `tools/build_sounds.py` kan een bed maken (`bed`, `rms`, `ogg`, `rate`), een stuk uit een opname nemen (`trim`), de toonhoogte laten glijden (`glide`), omkeren, een stem tot machine maken (`ring`, `comb`), een ratel strooien uit losse tikken (`scatter`) en ruis en brom maken die niet wegsterven (`air`, `hum`); een pakket mag uit losse bestanden bestaan. `tools/test_sound.sh` loopt dit alles na, 37 controles, zonder geluidskaart.

**Gemeten**

- Een gevecht in de turbinehal zoals het spel het afspeelt (het eigen salvo, vijf salvo's van robots op 12 tot 35 m, een explosie op 14 m, drie kogels die langsgaan, het bed): de uitgang piekt op -1,0 dBFS met geen enkele sample erboven, de bus `Far` zit gemiddeld 14 dB onder World en het geheel is 0,2 tot 0,3 dB luider dan zonder de extra galm. Gemeten met de eerste versie van de geluiden; de niveaus van de bedden zijn gelijk gebleven.
- Elk bed gaat rond zonder sprong, ook zoals Godot een Ogg rondspeelt: over het punt waar de lus opnieuw begint is de grootste stap tussen twee samples niet groter dan elders in het bed, en er valt geen stilte. Links en rechts hebben niets gemeen (correlatie 0,0): een opname loopt rechts 37% van haar lus voor op links.
- `assets/audio/` ging van 16 naar 24 MB voor 28 geluiden: vijf bedden van samen 2 MB en 94 takes van stemmen, deur en mechaniek. Daarbij komt de opname van de kogel in `assets/recordings/`, 3,4 MB.
- Alle 37 controles van `tools/test_sound.sh` slagen, net als de hele selftest (315), de test van de personages (55), van de sandbox (30) en van samen spelen (62), ook nadat de trunk van die middag erin was gevoegd. Daarbij botsten twee bestanden: `scripts/humanoid_rig.gd` op de stem, en `tools/build_sounds.py`, waar de trunk intussen `burst` aan had toegevoegd voor een treffer in iemand.

**Buiten mijn bestanden geraakt**, in een eigen commit; Michiel heeft gezegd dat het blijft staan:

- `scripts/enemy.gd`: één regel in `_show_shot()`, `Sfx.passing(muzzle, end)`. Zonder die regel weet het geluid niet waar een schot heen ging.
- `scripts/enemy_themes.gd` (één regel en het commentaar), `scripts/humanoid_rig.gd` (de stem komt uit de rol en anders uit de bewegingen) en `assets/characters/manifest.json` (`"voice"` bij negen rollen): zonder klinken clowns als soldaten.
- `tools/render_mix.gd`, de renderer achter `tools/hear.py`: een geplaatst geluid zonder afstandsdemping, en een geluid dat halverwege begint of wordt afgekapt.
- `scripts/game.gd`: één regel, het checkpoint speelt `checkpoint` in plaats van `reload_end`.

**Nog open**

- De kogel is de kale opname, vier takes, niets eronder, en de adem bij het checkpoint is een bewerkte adem; beide zijn zo goedgekeurd. In het spel, naast de wapens en de muziek, zijn ze nog niet gehoord: het oordeel is gegeven op `tools/hear.py`.
- De opname van de kogel staat ook nog los in `assets/recordings/` van de hoofdcheckout, waar Michiel hem neerlegde. Git voegt deze branch daar pas in als dat bestand weg is: het zit nu in de branch zelf.
- Zien vijf robots de speler tegelijk, dan zeggen ze met vijf tegelijk hetzelfde: er zijn twee zinnen per gelegenheid, en niets houdt bij wie er al iets zei. De pack heeft ook "ouch", "that hurt" en "target down"; een robot die geraakt wordt of de speler neerlegt zegt nog niets.
- De niveaus van de bedden zijn gekozen op getal en zo goedgekeurd met `tools/hear.py`, waar de muziek niet onder speelt: `"rms"` per bed in het manifest. Er is geen schuif voor.
- Een geluid uit een andere zone klinkt in de galm van de zone waar je zelf staat, en gaat door muren heen: er is geen demping door wat ertussen staat.
- Wat er af en toe klinkt in een ruimte kan achter een muur vandaan komen: de plek wordt niet tegen het level gehouden.
- De roldeur eindigt met de klap van een vat (`clang`) uit `scripts/game.gd`.
- Een schot van een medespeler (`scripts/puppet.gd`) hoor je niet langsgaan: alleen dat van een vijand meldt zich.
- In een level zonder zones hangt de galm af van wat de stralen raken: naast een stapel kratten is de kamer kleiner.
- De waarschuwingstoon van een robot is één take per soort: dat is zo bedoeld, het is een signaal.
- Een run zonder venster die stopt terwijl er een level geladen is, eindigt nu meestal met `WARNING: ... ObjectDB instances were leaked at exit` en soms met `ERROR: ... resources still in use at exit`: dat is wat nog speelt als de engine stopt, en met een bed en wat er af en toe klinkt is dat er nu bijna altijd. Voorheen stonden die regels er alleen als er toevallig net een geluid klonk. De test slaagt er even goed om. Alles stoppen in `_exit_tree()` is geprobeerd en maakte het erger.

## Vijanden die mensen kunnen zijn

De vijanden kunnen in plaats van robots ook personages zijn: één huid op een skelet, aangestuurd door hetzelfde `scripts/enemy.gd`. Wie het zijn is een thema. De standaard is `robots`, en die lopen door dezelfde code als voorheen.

**Wat er staat**

- **Thema's.** Een thema geeft voor elk van de drie rollen (grunt, rusher, heavy) de personages waaruit per vijand willekeurig gekozen wordt, het wapen dat hij draagt, zijn manier van bewegen en wat er aan zijn afstelling anders is. `scripts/enemy_themes.gd` leest ze uit twee tabellen van dezelfde vorm: `assets/characters/manifest.json`, waar de personages komen die voor het spel gemaakt worden, en `assets/animations/themes.json` met wat er altijd is: `mannequin` (de twee poppen van de animatieset, met karabijn, vuisten en pistoolmitrailleur) en `mannequin_zombie` (dezelfde poppen, schuifelend en slaand). Ontbreekt het bestand, het thema, de rol of het personage, dan is die vijand een robot; een thema mag dus ook maar één rol invullen. Een thema mag ook een ander thema zijn met iets erbovenop: `"like": "clowns"` met een eigen `tuning` is de clowns, elke rol met dat over zijn eigen afstelling heen. Kiezen doe je in het instellingenscherm of met `--enemies=<thema>`; het geldt voor wie daarna spawnt.
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
| Een vijand van een thema in een level bekijken (houdingen 1 tot en met 4 als hierboven; 5, 6 en 7 lopen naar rechts, naar links en achteruit, 8 is vlak voor de aanval, 9 de treffer, 13 rent in paniek) | `tools/benchmark.sh --quick --enemies=mannequin --spawn="res://scenes/enemy.tscn@-2,0,-1,-100,1,8" --at="2.5,1.7,3,90,-4"` |
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
- Bij snel omdraaien schuiven staande voeten in één keer mee zodra het lijf meer dan 35 graden gedraaid is.
- De val voorover, de draf, het slaan met iets in de hand en de voeten op een trap stonden hier open; ze zijn gebouwd, zie "Houding en beweging".
- De vingers bewegen niet; ze hebben een greep, een vuist, een klauw of een losse hand.
- `tools/benchmark.sh --shoot` laat op een personage vonken zien in plaats van bloed, omdat de benchmark het effect zelf kiest en `Fx.robot_hit` aanroept; in het spel gaat een treffer via de vijand en klopt het.
- Een lijf kan door een muur steken als er in geen enkele richting 1,9 m ruimte is.

## Houding en beweging: robots uit, draf, val, trap en slagwapen

Wat een vijand laat zien, los van wat hij beslist: `scripts/enemy_rig.gd` voor de robots, `scripts/humanoid_rig.gd` voor de mensen. Gebouwd op 11 oktober 2026 op de open punten van "Vijanden die mensen kunnen zijn", "Personages" en "Een route door de levels". Van elk onderdeel staat een blad met voor en na in `assets/animations/sheets/`.

**Wat er staat**

- **Een robot die uit staat** (`robot_uit.jpg`) hangt in zijn gewrichten: benen gestrekt, 21 graden voorover in het middel, het hoofd nog eens 36 graden op de borst, de armen loodrecht omlaag. Vizier, borstlamp en de lampen op het pak van de heavy zijn gedoofd. De rig merkt zelf dat hij uit gaat: `scripts/game.gd` zet een robot op zijn post stil met `PROCESS_MODE_DISABLED`, en de melding daarvan is voor de rig "uit"; de melding dat hij weer loopt is "aan". Er is dus niets aan `game.gd` of `enemy.gd` veranderd. Wie het liever zegt dan laat merken, roept `power(false)` en `power(true)` op de rig aan. Aangezet komt hij in 0,8 s overeind: de lampen slaan haperend aan, het hoofd komt eerst omhoog, dan de romp, dan armen en benen. Een robot die een gereedschap stilzet om hem te bekijken (`--spawn`, het bewegingenblad) blijft aan: die is al stilgezet voor hij in het level staat, of zijn rig is met de hand stilgezet.
- **Een robot die stilstaat, beweegt niets meer.** Het wiegen van de romp is weg, elke overgang komt nu aan in plaats van eindeloos dichterbij te komen (binnen 0,0005 is aangekomen), en een gewricht dat dezelfde stand krijgt als de vorige keer wordt niet aangeraakt. Daarvoor in de plaats ademt het vizier: de gloed gaat 12% op en neer, en licht werpt geen schaduw. Voorheen verplaatsten bij een stilstaande grunt elk frame 8 van zijn 17 onderdelen (rusher 8 van 16, heavy 11 van 19, bij hem draaiden ook de lopen eeuwig uit); nu geen enkel, en na het lopen staat alles 0,77 s na de laatste stap stil.
- **Een draf** (`draf.jpg`). De set heeft niets tussen wandelen (1,05 m/s) en rennen (5,9 m/s), dus `tools/build_moves.gd` maakt hem: de wandel- en de rencyclus worden eerst in de pas gebracht en dan over elkaar gelegd, met 35% ren in de benen en 70% in romp en armen, één cyclus per 0,95 s. Dat geeft 3,08 m/s met passen van 1,46 m, 2,1 per seconde, elke voet 24% van de cyclus aan de grond (wandelen 50%, rennen 18%). De bouwer meet de mengcyclus op zoals elke andere. De zombies hebben een eigen draf (`zombie_trot`, 2,93 m/s): dezelfde benen onder het bovenlijf van de schuifelgang. In het manifest is het één regel: `"with"` noemt de tweede clip, `"share"` en `"carried"` de aandelen, `"cycle"` de duur. De rig schakelt nu ook eerder over (`LATE` van 1,25 naar 1,1): een pop van gewone lengte draaft van 2,1 tot 5,0 m/s. De heavy (2,6 m/s) en de zombie (2,4 m/s) draven dus in plaats van te snelwandelen, en de grunt op volle snelheid (4,2 m/s) loopt de draf op 136% waar hij de ren op 71% liep.
- **Voorover vallen** (`val_voorover.jpg`). Wie van achteren geraakt wordt (meer dan 126 graden uit het midden van voren) valt op zijn gezicht, met het schot mee, als er daar 1,9 m ruimte is; anders zakt hij ineen zoals voorheen. De set heeft die val niet, dus hij is uit stukken gezet (`"pieces"` in het manifest): door de knieën met de clip van iemand die knielt om iets te repareren, in 0,45 s, en dan plat voorover naar de houding van een zwemmer die op de grond is gelegd. Een zware klap in de rug (60 schade in een ogenblik) werpt hem naar voren: de afzet van een duikrol, en dan 1,9 m verder plat neer.
- **Voeten die de vloer volgen** (`trap.jpg`). Onder elke voet wordt naar de vloer gezocht, tot 0,4 heuphoogte boven en onder waar het lijf staat; de enkel gaat daarheen, de heupen zakken zover als het laagste been nodig heeft, en een hoogteverschil onder de 1,5 cm telt niet, zodat er op een vlakke vloer niets verandert. Op een helling tot 20 graden ligt de voet plat op de helling (de oprit van het depot is 11 graden); op iets steilers blijft hij waterpas, want dat is een trap. De trap in de hal van de fabriek is voor het spel een helling door de voorkanten van de treden: daar staan de voeten op, dus tot één optrede (20 cm) boven het getekende trapvlak, net als het lijf en de speler.
- **Slaan met iets in de hand** (`slaan.jpg`). Er zijn drie dingen om mee te slaan, gebouwd in `tools/models/enemies.gd`: een stuk stoompijp, een brandbijl en een hakmes (`scenes/models/pipe.scn`, `axe.scn`, `cleaver.scn`; 1440, 232 en 244 driehoeken). Een rol die van dichtbij vecht en in zijn thema zo'n ding als `weapon` heeft, draagt het in de rechterhand en slaat ermee: twee zwaardslagen uit de set (`club_slash`, `club_swing`), de arm in de houding van iemand die een zwaard draagt, de vingers eromheen. Bij dood of paniek valt het. Noemt het thema iets anders, een geweer bijvoorbeeld, dan draagt zo'n rol nog steeds niets. In de thema's hebben nu de rusher van de poppen de pijp, de zombie-heavy (de brandweerman) de bijl en de snelle clown het hakmes. Onderweg bleek een snelle slag na een lange aanloop al terug te zijn voor hij moest aankomen; de rig kiest daarom uit de slagen die op tijd kunnen landen.

**Werkwijze**

| Stap | Commando |
|---|---|
| Een robot uit, en wat er gebeurt als hij aan gaat | `tools/benchmark.sh --quick --scene=res://scenes/moves_sheet.tscn --enemies=robots --enemy=res://scenes/enemy.tscn --then=off --lower --at="0,1.15,5.4,0,-3"` (`--then=wake --step=0.12` voor het opstarten) |
| Een level met de robots uit op hun post | `tools/benchmark.sh --quick --posted` |
| De draf als rij momenten (0,714 van 4,2 m/s is 3 m/s) | `tools/benchmark.sh --quick --scene=res://scenes/moves_sheet.tscn --enemies=mannequin --enemy=res://scenes/enemy.tscn --walk=0,0.714 --step=0.11 --turn=90 --lower --at="0,1.15,5.4,0,-3"` |
| Een schot in de rug, of met `--then=thrown` een zware klap | dezelfde, met `--then=back --step=0.2` in plaats van `--walk` en `--lower` |
| De trap op | dezelfde, met `--stairs --walk=0,0.5 --step=0.5 --count=4 --at="-1.5,1.55,3.3,0,-2"` |
| Uithalen en slaan met wat hij in de hand heeft | `tools/benchmark.sh --quick --scene=res://scenes/moves_sheet.tscn --enemies=zombies --enemy=res://scenes/enemy_heavy.tscn --then=swing --step=0.12 --turn=20 --at="0,1.15,5.4,0,-3"` (`--then=charge` voor de aanloop) |
| De dingen om mee te slaan opnieuw bouwen (zet daarna de drie robots terug met `git checkout`, die komen er anders uit zonder anders te zijn) | `tools/build_model.sh enemies` |
| Wat er van het rantsoen van vandaag over is, zonder iets te versturen | `tools/characters/generate.py --ration` |
| Het trefgeluid op een mens beluisteren zoals het spel het speelt | `tools/hear.py impact_flesh` |

**Meting** op 11 oktober 2026, M1 Pro, 3456×2160 met MetalFX op automatische schaal, kwaliteit Ultra, om en om met de commit ervoor, vier rondes. Andere sessies draaiden intussen tests zonder venster; runs die daardoor uitschoten staan er tussen haakjes bij.

| De fabriek, alle 16 robots op hun post, standpunt Overview | Frame | Tekenopdrachten | Driehoeken |
|---|---|---|---|
| Uit, zoals het spel ze neerzet | 19,84 tot 20,02 ms | 1167 | 1,54 miljoen |
| Aan en stilstaand, voorheen | 20,16 tot 20,20 ms | 3350 | 4,23 miljoen |
| Aan en stilstaand, nu | 19,85 tot 19,96 ms | 1169 | 1,54 miljoen |

| De hal, acht robots aan en stilstaand op 6 tot 8 m | Frame | Tekenopdrachten |
|---|---|---|
| Lege hal | 18,58 tot 18,90 ms | 775 |
| Voorheen | 19,30 tot 19,39 ms (en één van 20,74) | 1855 |
| Nu | 19,25 tot 19,33 ms | 1495 |
| Nu, bevroren door de benchmark | 19,26 en 19,34 ms (en 19,86 en 21,65) | 1495 |

Een robot die aan staat en stilstaat kost nu wat een robot kost die uit staat: de schaduwen worden niet meer hertekend. Dat scheelt per frame 2180 tekenopdrachten en 2,7 miljoen driehoeken met alle zestien in het level, en 0,28 ms (0,7 fps bij 50). Op deze resolutie bepaalt het beeld zelf de frametijd; de 4 fps die eerder op 1440p voor wiegende robots is gemeten haal ik hier niet terug.

Het poseren van een lopende pop kost 52 microseconden per frame. De twee stralen naar de vloer zijn daarin niet terug te vinden: om en om met en zonder gemeten, twee keer 600 frames elk, is het verschil kleiner dan een microseconde en dus kleiner dan de spreiding.

`tools/test_humanoid.sh` controleert nu ook: dat 3 m/s een eigen pas is (draf, 2,1 passen per seconde, passen 0,99 keer zo lang als gemaakt), dat een schot van voren iemand op zijn rug achter zijn plek legt en een van achteren op zijn gezicht ervoor, dat de rusher zijn pijp in de rechterhand heeft en bij zijn dood loslaat, dat op een vlakke vloer beide voeten met rust gelaten worden, en dat op de trap van de hal een voet die staat hooguit 4,4 cm van de vloer eronder is (26 cm als de voeten op de hoogte van het lijf blijven) met de voeten tot 58 cm boven elkaar. Aan het eind neemt de test de drie robots: stilgezet gaan ze uit, losgelaten komen ze aan, en stilstaand verplaatst geen onderdeel. 54 controles, alle geslaagd; `tools/selftest.sh` ook (312). Daarna is de trunk van 11 oktober binnengehaald (de sandbox, het GPU-slot, `CLAUDE.md`): zonder conflict, en op het geheel slagen `tools/selftest.sh` (315), `tools/test_humanoid.sh` (54) en `tools/test_sandbox.sh`. De metingen en de bladen zijn van vóór dat binnenhalen; de trunk raakte de rigs niet.

**De cast: wat het gratis rantsoen toelaat, en een volgorde**

- **Het rantsoen.** De pagina's van Hugging Face geven een gratis account 5 minuten GPU per dag, geteld vanaf het eerste gebruik en 24 uur daarna weer vol; zonder account 2 minuten, een betaald account (PRO) 40. Een stap begint alleen als er nog over is wat hij hooguit mag gebruiken: 90 s voor een plaatje, 120 s voor elk van de twee stappen van een model. Wat een stap van het rantsoen afhaalt zeggen de demo's niet, en het is veel meer dan hij draait. Op 11 oktober draaide een plaatje 3 tot 8 s en de twee stappen van een model 21 en 22 s; na één model en zes plaatjes, samen 68 s, zei de demo "0s left". Op 10 oktober waren het twee modellen en vijf plaatjes. Mijn eerste rekensom (wat een stap draait gaat eraf, dus vier modellen per dag) was dus fout. Wat vaststaat: één model per dag, en plaatjes zijn niet gratis: schilder er weinig.
- **`generate.py` houdt de telling zelf bij**, naast het token (`~/.cache/huggingface/zerogpu_ration.json`): wanneer elke stap begon, hoe lang hij liep, en wat een demo zei dat er over was toen hij een stap weigerde. Hoeveel er in een dag gaat neemt hij van de laatste dag die opraakte (nu: 68 s van zijn eigen seconden, dus een model en een stuk of zeven plaatjes). `--ration` zegt wat er over is zonder iets te versturen, en een model dat er niet meer in past wordt niet begonnen (`--anyway` doet het toch). De telling kent alleen wat dit script deed.
- **`clown_07` is begonnen en niet af.** Het eerste plaatje (de prompt die klaarstond) gaf een clown met open armen, en zijn model (11,5 MB, 283 duizend driehoeken, in een minuut) is niet te riggen: de bovenarmen zitten in de mouw aan het lijf vast en de onderarmen steken horizontaal uit, zodat er op geen enkele hoogte een losse arm naast de romp is. Drie andere zaden gaven dezelfde houding: het ligt aan de prompt ("held out to the sides", "hands open"), niet aan het toeval. De nieuwe prompt vraagt om armen die gestrekt schuin naar de vloer wijzen, de handen op heuphoogte een handbreedte buiten de heupen; zaad 2 daarvan is goed (armen recht en vrij, benen uit elkaar) en staat met die prompt in `build_cast.sh`. Het rantsoen was toen op. Zodra het terug is: `tools/characters/build_cast.sh clown_07`, een minuut of vier; het plaatje ligt in `assets/characters/.source/generated/clown_07/` in de hoofdmap.
- **`--baggy`** is nieuw in de scanroute, voor een pak dat tot de knieën hangt: bij deze clown komen de benen op 25% van de hoogte samen, waar de route minstens 30% eist om knieën die tegen elkaar staan te weigeren. De heupen komen dan op de vaste verhouding van de lengte en de knie boven het punt waar de pijpen uiteengaan. De route zegt nu ook op welke hoogte de benen samenkomen als hij weigert.
- **Volgorde.** (1) `clown_07` afmaken: daarmee is elke rol van de clowns een echte clown. (2) Een zombie voor de rol van grunt, want de meeste zombies in een level zijn grunts; die moet nog geschilderd worden. (3) `zombie_07`, de zombie-brandweerman (heavy) die de bijl draagt: zijn plaatje van 10 oktober ligt er al, maar met de onderarmen naar voren, de houding waarop `clown_07` strandde; schilder hem opnieuw met de armen omlaag. (4) De snelle zombie (rusher). Dan heeft ook bij de zombies elke rol een gegenereerd personage en kunnen de plaatshouders uit de rollen. Eén per dag, dus vier dagen, tenzij er een betaald account komt (40 minuten per dag).
- **Wat de prompt moet zeggen**, geleerd aan drie clowns: armen gestrekt en omlaag, schuin van het lijf af, handen op heuphoogte. Niet "45 graden opzij" en niet "open handen": dat wordt een verwelkomend gebaar met gebogen ellebogen. Bij een dik figuur groeit de bovenarm anders aan de romp vast.

**Op zijn aanwijzing erbij, 11 oktober 's middags**

- **Een schot op een mens heeft een eigen geluid.** Het speelde `impact_soft`, het geluid van een kogel in een kartonnen doos: 0,14 s, bijna alles onder de 200 Hz, in 0,05 s weg. Nu is er `impact_flesh`, en `scripts/enemy.gd` noemt het oppervlak van een mens `flesh` in plaats van `soft`; `Fx.strike()` laat daar niets achter, want het bloed is van de rig. Hoe het klinkt heeft Michiel op het oor gekozen, in vier rondes: een zware vuistslag met het kraken van sneeuw eronder ("moet natter"), dezelfde natter, drie varianten met oplopende blubjes ("nog steeds een raar geluid"), en toen zijn eigen recept: korte ruis die wit begint en snel dof wordt richting bruin. Daarvan koos hij de kaalste. Het is 0,35 s ruis die er meteen is, met een laagdoorlaatfilter van 6 dB per octaaf dat in 40 ms van 16 kHz naar 200 Hz zakt: in de eerste 15 ms zit bijna alles boven de 2 kHz, na 80 ms bijna alles onder de 300 Hz. De bouwer van de geluiden kent dat nu als bouwsteen (`"burst": [seconden, van Hz, naar Hz, valtijd]` in `assets/manifest.json`), ook als laag onder een opname. Beluisteren: `tools/hear.py impact_flesh`.
- **Pauze tijdens het laden brak het pauzemenu.** `SCRIPT ERROR ... 'scene_file_path' on a base object of type 'null instance'` in `menu.gd`. Na een dood en tussen twee levels is het oude level een frame eerder weg dan het nieuwe er is, en in dat frame landt een toets die tijdens het laden is ingedrukt; het menu vroeg dan het level naar zijn bestand. Daarna stond het spel op pauze met een half menu. Zonder venster nagespeeld (herladen vanuit een timer, pauze in hetzelfde frame): met de fout voor, zonder na. Het menu slaat de toets nu over zolang er geen level is.

**Wat ik niet kon beoordelen**

- Alles hierboven is bekeken als rij stilstaande momenten, niet in beweging. Of de draf vloeiend loopt, of de overgang van wandelen naar draven en van draven naar rennen niet verspringt, en of de val op de knieën niet te beheerst oogt voor iemand die wordt neergeschoten, moet in het spel blijken.
- De trap is alleen gezien met het lijf met de hand langs de helling bewogen (het blad en de test). In het spel staat het lijf op een capsule en dus een centimeter of zeven boven een helling van 34 graden; de voeten reiken dan dieper. Geen vijand van de route loopt uit zichzelf de trap van de hal op.
- Of het gevecht er beter van wordt dat een robot die uit staat ook minder opvalt. Het vizier was het helderste aan hem: in een donkere hoek van de hal is hij op 20 m nu een silhouet (onderste rij van `robot_uit.jpg`), terwijl de route erop rekent dat je al ziet staan wat je straks tegenkomt. Van dichtbij leest de houding duidelijk als uit; van voren en van ver nauwelijks.
- Het ademen van het vizier is klein gehouden (12%); in de bladen is het niet te zien.
- De bijl en het hakmes zijn op de plaatshouders gezet. Het hakmes is van opzij een streep.
- Er klinkt niets nieuws: een slag met de bijl klinkt als een vuistslag, en opstarten is stil.

**Nog open**

- Een mens die op zijn post staat te wachten, staat bevroren in de houding waarin hij verscheen. Voor mensen bestaat "uit" niet; een wachthouding die niets kost is er nog niet.
- Een personage dat stilstaat ademt, en laat dus wel elke lamp zijn schaduw hertekenen. Dat is niet gemeten.
- De robots volgen de vloer niet: op een trap staan hun voeten op de hoogte van het lijf.
- De treden van een trap zijn alleen getekend. Voeten die op de treden zelf staan vragen om treden waar de voeten tegen kunnen botsen, in het level.
- Wie met iets slaat, slaat met één hand. Voor twee handen (een moker, een geweerkolf) zijn geen slagen geknipt.
- De derde slag uit de set (`Sword_Regular_B`) begint waar de eerste eindigt en is daarom niet los te gebruiken.
- `tools/build_model.sh enemies` schrijft de drie robots opnieuw weg met andere bytes, ook als er niets aan veranderd is.
- Wat een stap echt van het rantsoen afhaalt is onbekend; de telling gaat af op wat er de vorige keer in een dag ging.
- `clown_07` wacht op het rantsoen. Zijn plaatje is goed; of het model het ook is, blijkt dan pas.
- Het trefgeluid op een mens is door hem gekozen uit losse opnamen, niet in een gevecht gehoord: daar speelt het op afstand en door de galm van de ruimte.

## Moderne shooter-eisen (fase 4)

**Wat er staat**

- **Menu.** Titelscherm over het geladen level, levelkeuze, pauzemenu (Esc of Start) en een instellingenscherm. Alles is met muis, toetsenbord en controller te bedienen. `--play` slaat het titelscherm over.
- **Besturing.** Het titelscherm en het pauzemenu hebben een scherm Controls, met een knop die wisselt tussen muis, trackpad en controller. Voor de trackpad is er één toets bij gekomen: richten met Option (Alt), omdat een trackpad niet tegelijk een rechterklik kan vasthouden en klikken. Wapens wissel je daar met 1 tot 5, want scrollen met twee vingers is voor Godot geen muiswiel. Het scherm noemt C voor bukken en niet Ctrl: macOS maakt van een klik met Ctrl ingedrukt een rechterklik, dus gebukt vuren zou richten worden. Niet op een echte trackpad geprobeerd.
- **Instellingen**, bewaard in `user://settings.cfg`: kwaliteit (Low tot Ultra), upscaler, renderschaal, V-Sync, fullscreen, fps-teller, gezichtsveld, beeldbeweging (View motion, zie "Hoe het beeld meebeweegt"), muis- en stickgevoeligheid, Y-as omkeren en volume. Een kwaliteitsniveau zet alleen effecten uit die het level zelf aan heeft staan.
- **Upscaling.** Bilinear, FSR 1, FSR 2 en op Apple-hardware MetalFX Spatial. Een speler begint met MetalFX Spatial (elders FSR 1) en een renderschaal die zichzelf instelt. Zie "Fullscreen op een Retina-scherm" hieronder, ook voor waarom MetalFX Temporal niet meer in het menu staat.
- **Springen** is kort: 0,9 m hoog en na twee derde seconde weer op de grond (was 1,2 m en een hele seconde). De speler valt daarvoor 1,65 keer zo snel als de rest van de wereld (`GRAVITY_SCALE` in `scripts/player.gd`).
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

**Fullscreen op een Retina-scherm** (10 oktober 2026)

Het budget hierboven gaat over 1440p. Zo wordt er niet gespeeld: vanuit de editor opent het spel in een venster van 1920×1080 pixels, wat op het scherm van een 16 inch MacBook Pro klein is, en fullscreen is daar 3456×2160. Dat zijn 3,6 keer zoveel pixels. Met de instellingen zoals ze stonden (Ultra, renderschaal 100%) liep de fabriek fullscreen op 17 tot 18 fps, tegen 48 tot 59 in het venster. Een upscaler kiezen hielp niet: op 100% heeft die niets te doen, en het menu zei dat nergens.

- **De renderschaal stelt zichzelf in** (`auto_scale`, standaard aan; `scale_for()` in `scripts/settings.gd`). Hij tekent de 3D-scène op de pixels van 1920×1080 of net daaronder, hoe groot het venster ook is, in de stappen van de schuif en niet lager dan 50%: 100% in een venster van 1920×1080, 75% op 2560×1440, 50% op 3456×2160. Hij volgt het venster als dat van grootte verandert. In het menu staat een schakelaar "Auto render scale"; staat die uit, dan geldt de schuif weer, die begint waar de automaat stond. Onder de schuif staat wat het in pixels betekent ("Drawn at 1728 × 1080 and enlarged to 3456 × 2160").
- **Wie begint, krijgt MetalFX Spatial**, buiten Apple-hardware FSR 1: de goedkoopste upscalers die verscherpen wat ze vergroten. Een instellingenbestand van vóór deze wijziging waarin een upscaler stond die op 100% niets deed, krijgt die standaard ook.
- **Een benchmark verandert niet**: die tekent op de volle grootte tenzij `--scale=` iets anders zegt. `--scale=auto` geeft hem de schaal van een speler.

Michiel heeft het op 10 oktober zo gespeeld, vanuit de editor en op het volle scherm: het werkt.

Gemeten in de fabriek op 3456×2160, M1 Pro, met de karabijn in beeld, terwijl de laptop in gebruik was:

| Kwaliteit | Upscaler en schaal | Gemiddeld (laagste en hoogste standpunt) | Beeld |
|---|---|---|---|
| Ultra | Geen, 100% | 17–18 fps | scherp |
| High | MetalFX Spatial, 50% | 63–67 fps | scherp, iets aangezet |
| Ultra | MetalFX Spatial, 50% | 44–50 fps | niet bekeken |
| High | FSR 2, 50% | 45–47 fps | scherp |
| High | MetalFX Temporal, 50% | 48–51 fps | blokken van twee bij twee pixels |
| High | MetalFX Temporal, 67% | 36–39 fps | wazig; niet uitvergroot bekeken |
| Medium | MetalFX Temporal, 50% | 51–55 fps | niet bekeken |

De regel voor Ultra met MetalFX Spatial is van na een herstart van de laptop, met `--scale=auto`; de eerste meting brak af na drie standpunten, die 47–50 fps gaven. High met MetalFX Spatial gaf bij die tweede meting 64–73 fps.

Ook op halve schaal kost het volle scherm iets: alles na de upscaler (lens, HUD) loopt op 7,5 miljoen pixels. Op 1920×1080 zonder upscaling haalde dezelfde fabriek op Ultra 48 tot 59 fps.

**MetalFX Temporal staat niet meer in het menu.** In een level van dit spel bouwt het geen beeld op: wat op halve schaal is getekend, komt als blokken van twee bij twee pixels terug, waar FSR 2 uit dezelfde invoer een scherp beeld maakt. Het is bovendien trager dan MetalFX Spatial. Een opgeslagen keuze ervoor wordt FSR 2; een benchmark kan er nog om vragen (`--upscaler=metalfx_temporal`). Wat erover vaststaat:

- Het ligt niet aan Godot alleen. In een lege scène met dunne schuine staven werkt het: gladde randen, ook op 3, 12 en 40 m afstand, ook in een donker of juist heel licht beeld, en met glow, SSR en SSAO aan.
- In het spel werkt het op zulke staven ook, onbelicht en in dezelfde scène neergezet, dichtbij en op 20 m. De kisten, de machines en een los neergezet model (`ammo_can.scn`) ernaast komen als blokken terug.
- Dat model wordt gladder als het level om hem heen verborgen is.
- Het een voor een weghalen van mist, glow, SSR, SSAO, stof, de lenspass, de HUD, schaduwen, lightmaps, reflectieprobes, decals en de eigen materialen van het level hielp niet. Zonder de lampen bleven de randen getrapt, al was het beeld toen te donker om het met zekerheid te zeggen.

De oorzaak is dus niet gevonden. Het is een belicht oppervlak in een level waar het misgaat, en niet één effect dat uit kan.

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
- Vuur slaat niet over op kisten of pallets. Een klap breekt kisten en dozen, maar beweegt geen andere props: wat een lightmap heeft, staat vast.
- Wat kapot is laat sporen na in het gebakken licht: van een lamp die uit is blijft het licht staan dat via de muren kwam, en van een kist die weg is de gebakken schaduw op de vloer.
- De vijanden weten niet dat een stapel weg is: de plek erachter blijft op hun kaart van dekking staan tot ze er gezien worden, en het navmesh houdt er een gat. Kisten en lampen komen net als de vaten pas terug bij een herstart.
- Niet kapot te schieten: de kleine kisten op de stellingen, pallets, banden, cementzakken, tl-buizen die al uit waren en ramen. Vijanden schieten wel kisten stuk, maar geen lampen.
- Terwijl kisten omlaag vallen (een kwart seconde) staat hun botsvorm al waar ze neerkomen: een schot op de kist die nog in de lucht hangt gaat erdoorheen.
- Een kogel die rakelings langs gaat is niet te horen en niet te voelen: er is geen opname van.
- Hoe het beeld meebeweegt en hoe breken eruitziet en klinkt, heeft nog niemand gespeeld of gehoord.
- De granaat is in de hand niet te zien; alleen de arm die hem gooit beweegt.
- Een schot in een plas spat niet op: of een punt nat is, weet alleen de vloershader. Ramen hebben geen botsvorm, dus een schot gaat er zonder spoor doorheen.
- Een stelling heeft één doos als botsvorm; een schot tussen de planken door geeft daarom vonken in de lucht ervoor.
- Selftests van verschillende checkouts deelden één savebestand (`user://selftest_save.cfg`) en lieten elkaar falen als ze tegelijk draaiden, steeds vanaf "a restart carries on from that checkpoint". Sinds 11 oktober heeft elke checkout zijn eigen, zie "Meerdere agents tegelijk".
- De selftest meet "enemies approach" in echte tijd en faalde één keer op die stap toen de laptop zwaar belast was; drie herhalingen daarna slaagden.
- Geen instelbare toetsen en geen aim assist voor de controller.
- De HUD schaalt niet mee op hoge resoluties; de tekst is daar klein.
- Waarom MetalFX Temporal in een level geen beeld opbouwt, is niet gevonden; zie "Fullscreen op een Retina-scherm".
- De renderschaal die zichzelf instelt is alleen op de M1 Pro gemeten. FSR 1 als begin buiten Apple-hardware is een keuze op papier: op Windows is er niets van geprobeerd. Onder de 50% gaat hij niet, dus op een scherm van 5K tekent hij meer dan de pixels van 1920×1080.
- Of de schakelaar Fullscreen in het menu iets doet in het Game-venster van de editor, waar het spel draait als je daar op Play drukt, is niet bekend.

## Zestig beelden op het volle scherm

Op 11 oktober 2026 gevraagd: alle vier de levels op de instellingen waarmee gespeeld wordt (3456×2160, Ultra, MetalFX Spatial, renderschaal vanzelf) naar 60 fps, of laten zien wat Ultra daarvoor moet inleveren. Ze haalden 44 tot 52 fps. Het is allebei geworden: twee dingen die het beeld gelijk laten, drie instellingen waar niets van te zien is, en drie dingen die Ultra inlevert. Op de maat van het scherm haalt elk vast standpunt van elk level nu 65 fps of meer, en elk standpunt van de contactbladen 60 of meer. Zoals de benchmark tekent, met 11% meer pixels dan het scherm, blijft één standpunt eronder: de tussenvloer van de fabriek, op 59,7. Gebouwd op branch `zestig` en op 11 oktober, op Michiels woord, in `fase-2-vertical-slice` gezet om het te kunnen spelen; de metingen hieronder zijn daarna gedaan, op de samengevoegde stand. Er is niets herbouwd en niets gebakken: alles gebeurt bij het laden of in het spel.

De twee punten bovenaan "Nog open" van stap 5 zijn hiermee gedaan: de kamers die elkaar allemaal tekenen, en de lampen die door muren heen rekenen, voor zover ze een schaduw hebben.

**De benchmark tekende meer dan het scherm**

`tools/benchmark.sh --res=3456x2160` geeft zonder venster een beeld van 3840×2160: het venster zonder venster is 16:9, en het spel vult de gevraagde 16:10 aan tot het past. Dat is 11% meer pixels dan het scherm van de MacBook. Alle cijfers "op 3456×2160" in dit plan, ook die van 10 oktober, zijn zo gemeten, en op het scherm zelf loopt het spel een beeld of vier sneller dan ze zeggen. `tools/godot.sh --resolution 1728x1080 -- --benchmark --res=3456x2160 …` tekent wel 3456×2160; `tools/zone_sheet.py` kan dat niet meekrijgen. De tabellen hieronder geven beide. `scripts/benchmark.gd` is niet aangepast: dat bestand hoorde niet bij deze opdracht.

**Waar de tijd zat**

Gemeten door in één run, per standpunt, één ding om en om aan en uit te zetten (twee of drie keer, 100 frames per keer), op de instellingen van hierboven. In milliseconden per frame, laagste en hoogste standpunt; de centrale is gemeten toen de lampen al aan hun ruimtes gebonden waren:

| | Fabriek | Depot | Centrale |
|---|---|---|---|
| Het hele frame, voor | 19,6–21,8 | 18,8–21,8 | 19,5–21,8 |
| De schaduw van de zon | 1,9–2,6 | 2,9–3,1 | 2,1–2,6 |
| waarvan de atlas van 8192 in plaats van 4096 | 1,1–1,6 | 1,9–2,1 | 1,3–1,6 |
| en 4096 in plaats van 2048 | 0,3 | 0,5 | 0,3 |
| De schaduwen van de lampen: het breedste filter in plaats van de stand eronder | 1,0–1,6 | 1,0–2,2 | 1,2–2,3 |
| SSIL | 1,6 | 1,4–1,6 | 1,5–1,8 |
| SSR | 1,6–1,8 | 1,4–1,7 | 1,5–1,9 |
| MSAA 4× in plaats van 2× | 1,0–1,4 | 1,0–1,3 | 0,9–1,2 |
| MSAA 4× in plaats van geen | 2,5–3,5 | | 2,4–3,0 |
| De lenspass | 1,3–1,4 | | 1,2–1,6 |
| waarvan de kleurzweem | 0,7–0,9 | | 0,7–0,9 |
| Glow | 0,6–0,7 | 0,6–0,7 | 0,5–0,6 |
| Mist | 0,4–0,5 | 0,6 | 0,6 |
| SSAO | 0,3–0,7 | 0,4–0,5 | 0,5–0,6 |
| MetalFX in plaats van bilineair vergroten | 0,3 | | 0,3 |

- **De schaduw van een lamp wordt per pixel opgezocht**, voor elke lamp binnen wiens bereik de pixel ligt, met zestien monsters op de hoogste filterstand en acht op de stand eronder. Het was de grootste post die aan één instelling hing. De schaduwen helemaal uitzetten levert minder op dan het filter halveren: wat in de schaduw lag, wordt dan door elke lamp volledig belicht.
- **De zon is gebakken.** Haar licht en haar schaduw op muren, vloeren en containers staan in de lightmaps. De zon van het spel verlicht alleen wat geen lightmap heeft: modellen, robots, het wapen, de mist, en de grond buiten een level dat in zones is geknipt. Haar schaduwkaart, vier keer 4096×4096 op Ultra, werd elk frame opnieuw getekend voor de schaduwranden op die dingen.
- **De lenspass van Ultra las het hele beeld terug** om rood en blauw uit elkaar te trekken: elk pixel van het volle scherm kopiëren en drie keer lezen. Die van de andere niveaus vermenigvuldigt alleen, met vignet en korrel.
- **Het fabrieksterrein heeft de vaste standpunten van de fabriek.** Twee van de vijf (Overview en Boiler) staan daardoor buiten het gebouw en kijken over de daken, en Hall staat met de neus tegen een rij kluisjes. Ze zeggen weinig over het level; het contactblad met zijn 56 standpunten zegt meer.

**Wat er staat**

- **Een lamp met schaduw blijft in de ruimtes waar zijn licht komt** (`_bind_lamps()` in `scripts/zones.gd`). Als het level geladen is, gaan er van elke lamp lijnen uit: naar elke deuropening en elk raam binnen zijn bereik (de panelen van de bake en de ruiten wijzen ze aan) en driehonderd in het rond. Een zone waar zo'n lijn doorheen gaat voor hij op het level stuit, is een zone waar de lamp komt. Daarna krijgen de zones renderlagen, zo dat geen lamp de ene zone bereikt en een andere met dezelfde laag binnen zijn bereik niet, en de lamp belicht alleen de lagen van zijn eigen zones. Zijn schaduw tekent hij ook alleen nog van wat daar staat. Op het fabrieksterrein worden zo 43 van de 83 lampen losgemaakt van samen 120 zones waar ze doorheen rekenden, in de centrale 19 van de 43 van 44, in de fabriek 6 van de 18 van 7. Met acht kleuren blijven er op het fabrieksterrein 6 van die 120 over die een kleur delen. Het kost bij het laden hooguit 86 ms, op het fabrieksterrein. Robots, het wapen en alles wat het spel zelf maakt horen bij geen zone en worden door elke lamp belicht, zoals voorheen. Een lamp zonder schaduw ook: zie "Onderweg gevonden".
- **De muren zijn occluders** (`_wall_off()` in `scripts/zones.gd`). Van de botsvormen van het level gaan de dozen van baksteen, beton en pleister die dun zijn en minstens 1,2 m lang en hoog, als één occluder naar de renderer: 77 muren in de fabriek, 245 op het fabrieksterrein, 165 in de centrale. Zo'n doos is door de levelbouwer samen met de muur gemaakt en dus even dicht. Van een zone in het zicht wordt daarna alleen getekend wat niet achter een muur staat, model voor model. Lightmaps, lampen, reflectieprobes en decals doen daar niet aan mee: zie "Onderweg gevonden". Een stelling, een hek of een betonblok, waarvan de botsvorm een doos is om iets waar je doorheen of overheen kijkt, verbergt niets. Het gaat aan na de eerste vier frames, waarin het level alles één keer tekent.
- **De schaduwsortering deelt die lagen** (`scripts/shade.gd`): wat in de schaduw staat krijgt de schaduwlaag van zijn zone in plaats van één laag voor alles. Acht kleuren voor wat de zon mag raken, acht voor wat in de schaduw staat, drie voor wat bij geen zone hoort: negentien van de twintig lagen waar een camera, een decal en een reflectieprobe naar kijken.
- **Drie instellingen waar niets van te zien is**, op elk kwaliteitsniveau:
  - *De atlas van de zonneschaduw is 2048* (`SUN_ATLAS` in `scripts/settings.gd`), in plaats van 8192 op Ultra en 4096 op Medium en High.
  - *Glow wordt lineair vergroot* in plaats van bicubisch, en *SSAO staat op lage kwaliteit* in plaats van medium (`project.godot`).
- **Ultra levert drie dingen in** (`QUALITY` in `scripts/settings.gd`):
  - *SSIL.* Staat nu op geen enkel niveau meer aan.
  - *Het breedste filter op de schaduwen van de lampen.* Ze worden gefilterd als op High. De zon houdt het breedste, wat niets kost.
  - *Zijn eigen lenspass.* De kleurzweem wordt nu gemaakt vóór het vergroten (`scripts/lens_fringe.gd`, een `CompositorEffect` dat `scripts/settings.gd` aan de omgeving van het level hangt): dezelfde verschuiving van rood en blauw naar de randen, maar op het beeld zoals het getekend is, een kwart van de pixels, en vóór de tonemapping, zodat de zweem langs een lamp met die lamp meegloeit. Vignet en korrel komen daarna van de lenspass van de andere niveaus. Die kan alleen vermenigvuldigen, waar de oude korrel optelde: het beeld is er 3% donkerder door (gemeten: het gemiddelde van twee standpunten zakt van 155,5 naar 151,0 en van 137,3 naar 133,2 op 255), en de korrel is in het donker fijner dan in het licht in plaats van overal even sterk. Korrel optellen vraagt het beeld terug te lezen, en dat was juist de post. Waar de renderer geen script toelaat (de Compatibility-renderer) doet de oude lenspass het als voorheen.
- **Ultra houdt MSAA 4×, de kleurzweem en de zachte zonneschaduw.** Dat is nu het verschil met High.
- **Elke maatregel is voor een meting terug te zetten**: `--undo=ssil,lamp_filter,sun_atlas,fringe,glow,ssao,lamps,occlusion`, of `--undo=all` (`UNDO` in `scripts/settings.gd`). Het werkt op `tools/benchmark.sh` en, omdat die elke optie doorgeeft, op `tools/zone_sheet.py`.

**Gemeten** op 11 oktober 2026, M1 Pro, op de samengevoegde hoofdbranch (met de wapens en handen van `wapens` in beeld), om en om: "voor" is dezelfde stand met `--undo=all`, die in de fabriek de cijfers van de branch van vóór dit werk geeft (46 tot 51 fps). Ultra, MetalFX Spatial, renderschaal vanzelf (50%), de karabijn in beeld. Twee rondes, terwijl andere sessies tests draaiden; per standpunt de beste van de twee, voor en na. Gemiddelde fps, tussen haakjes de 1% low. "Voor" en "Na" zijn zoals de benchmark tekent, op 3840×2160.

**Fabriek**, de vaste standpunten

| Standpunt | Voor | Na | Voor, op 3456×2160 | Na, op 3456×2160 |
|---|---|---|---|---|
| Overview | 48,7 (47) | 62,8 (60) | 52,5 (50) | 68,3 (65) |
| Corridor | 49,3 (47) | 66,6 (64) | 53,2 (51) | 72,6 (69) |
| Platform | 45,9 (44) | 59,7 (58) | 49,6 (43) | 65,5 (62) |
| Hall | 49,9 (48) | 64,9 (62) | 53,6 (51) | 70,6 (68) |
| Boiler | 50,5 (48) | 68,6 (65) | 54,5 (52) | 75,0 (71) |

**Fabrieksterrein**, de vaste standpunten

| Standpunt | Voor | Na | Voor, op 3456×2160 | Na, op 3456×2160 |
|---|---|---|---|---|
| Overview | 64,3 (28) | 92,0 (50) | 70,2 (29) | 101,3 (52) |
| Corridor | 59,6 (48) | 82,1 (77) | 64,7 (62) | 90,5 (85) |
| Platform | 56,0 (54) | 79,2 (75) | 59,2 (57) | 84,5 (80) |
| Hall | 47,3 (45) | 71,5 (68) | 51,6 (49) | 78,2 (74) |
| Boiler | 68,5 (66) | 95,0 (89) | 75,8 (71) | 106,2 (100) |

**Depot**, de vaste standpunten

| Standpunt | Voor | Na | Voor, op 3456×2160 | Na, op 3456×2160 |
|---|---|---|---|---|
| Overview | 51,5 (49) | 72,7 (69) | 55,4 (52) | 78,0 (74) |
| Lane | 45,2 (43) | 65,6 (63) | 47,3 (45) | 71,4 (68) |
| Dock | 46,3 (44) | 65,4 (63) | 49,8 (48) | 70,2 (68) |
| Yard | 52,5 (50) | 73,6 (70) | 56,0 (52) | 78,8 (75) |

**Centrale**, de vaste standpunten

| Standpunt | Voor | Na | Voor, op 3456×2160 | Na, op 3456×2160 |
|---|---|---|---|---|
| Yard | 50,9 (49) | 68,5 (65) | 55,6 (54) | 74,8 (72) |
| PumpHouse | 47,3 (45) | 64,7 (54) | 51,3 (49) | 70,8 (67) |
| BoilerHouse | 47,9 (46) | 65,3 (62) | 52,0 (50) | 71,2 (68) |
| ControlRoom | 43,8 (42) | 61,8 (59) | 47,4 (45) | 67,9 (65) |
| TurbineHall | 46,7 (45) | 62,5 (60) | 49,9 (47) | 67,5 (65) |

Het contactblad, `tools/zone_sheet.py <level> --res=3456x2160 --upscaler=metalfx --scale=0.5 --quality=3`, "voor" met `--undo=all` erbij: zonder wapen in beeld, gemeten over dertig frames per standpunt, zoals de benchmark tekent. Na haalt elke zone van elk level het keurmerk. Deze tabellen en die van de vaste standpunten zijn van vóór de reparatie van de lightmaps (zie "Onderweg gevonden"); met haar haalden de bladen van het fabrieksterrein en de centrale 60 tot 85 en 62 tot 72 fps.

| Level | Standpunten | Fps voor | Fps na | Onder de 60 voor | na | Tekenopdrachten voor | na | Zwaarste standpunt na |
|---|---|---|---|---|---|---|---|---|
| Fabriek | 10 | 48 tot 59 | 63 tot 83 | 10 | 0 | 343 tot 839 | 337 tot 813 | hall 2: 63 fps |
| Fabrieksterrein | 56 | 42 tot 62 | 61 tot 86 | 55 | 0 | 147 tot 951 | 147 tot 916 | paint_shop 2: 61 fps |
| Depot | 4 | 48 tot 57 | 69 tot 81 | 4 | 0 | 334 tot 391 | 336 tot 391 | level 2: 69 fps |
| Centrale | 25 | 47 tot 56 | 66 tot 78 | 25 | 0 | 216 tot 1098 | 216 tot 1085 | turbine_hall 3: 66 fps |

Een gevecht, in de fabriek, met alle zestien soldaten tegelijk aan en op de speler af (`--awake`) tegen dezelfde zestien op hun post (`--posted`), vanaf Overview en Hall:

| | Op hun post | In gevecht | 1% low op hun post | 1% low in gevecht |
|---|---|---|---|---|
| Voor | 47,3 en 48,4 | 48,9 en 48,0 | 45 en 47 | 44 en 44 |
| Na | 61,2 en 63,0 | 62,1 en 62,6 | 59 en 61 | 57 en 58 |

Het gemiddelde blijft gelijk; de 1% low zakt twee tot drie fps, voor en na evenveel. Dat is wat de soldaten die lopen aan schaduwen laten hertekenen. Er is niets apart aan gedaan, behalve dat een gebonden lamp zijn schaduw nog maar van zijn eigen ruimtes tekent.

**Wat elke maatregel oplevert en hoeveel van het beeld erdoor verandert**

De winst is gemeten als hierboven, om en om in één run. De pixels zijn geteld tussen twee screenshots van 3840×2160 (8,3 miljoen pixels) van hetzelfde standpunt, een seconde na elkaar, één met en één zonder de maatregel: het aantal dat meer dan 3% verschilt, in het vaste standpunt waar dat het meest is. De eerste regel is wat twee screenshots zonder enig verschil al uit elkaar liggen, door stof, mist en korrel.

| Maatregel | Winst per frame | Fabriek | Fabrieksterrein | Depot | Centrale |
|---|---|---|---|---|---|
| Twee keer hetzelfde | | 2 764 | 3 491 | 249 | 1 367 |
| Lampen met schaduw in hun eigen ruimtes | niets in de fabriek, 0–0,9 ms op het fabrieksterrein, 0–0,4 in de centrale | 1 654 | 4 371 | | 2 342 |
| Muren als occluders | 0–0,1, 0–1,1 en 0–0,3 ms | 1 450 | 3 952 | | 1 183 |
| Atlas van de zon van 8192 naar 4096 | 1,1–2,1 ms | 1 980 | 5 674 | 256 | 945 |
| en van 4096 naar 2048 | 0,3–0,5 ms | 2 381 | 8 683 | 191 | 1 199 |
| Glow lineair vergroot | 0,2 ms | 1 750 | 3 897 | 211 | 998 |
| SSAO op lage kwaliteit | 0,15 ms | 1 515 | 4 075 | 298 | 929 |
| Ultra: SSIL uit | 1,4–1,8 ms | 9 891 | 32 804 | 2 078 | 3 028 |
| Ultra: filter van de lampschaduwen een stand lager | 1,0–2,3 ms | 1 938 | 4 141 | 1 340 | 4 209 |
| Ultra: kleurzweem vóór het vergroten, korrel van High | 0,3 ms | 7 498 | 34 624 | 5 459 | 16 909 |
| Niet gedaan: MSAA 2× in plaats van 4× | 0,9–1,4 ms | 7 267 | 5 534 | 3 769 | 7 225 |

- Het meeste is 34 624 pixels, 0,4% van het beeld. Voor het fabrieksterrein is Overview buiten de telling gehouden, zie hieronder.
- **De kleurzweem** verschilt langs randen: hij wordt nu gemaakt op het halve beeld en daarna vergroot, in plaats van op het vergrote beeld. De 3% die het hele beeld donkerder wordt, telt deze telling niet mee: ze blijft per pixel onder de drempel. Het is de maatregel die het minst oplevert en het meest verandert.
- **SSIL** maakte wat in de zon staat een fractie lichter: de cementzakken in de gang van de fabriek, de kluisjes op het fabrieksterrein.
- **De atlas van de zon** is binnen niet terug te vinden, ook niet met de soldaten op hun post in het depot en de fabriek (hooguit 268 en 2 476 pixels, tegen 208 en 2 643 voor twee keer hetzelfde). Buiten het fabrieksterrein verschuift de rand van de schaduw van het gebouw op de grond een paar pixels: dat zijn de 8 683.
- **Het filter van de lampschaduwen** verschilt langs een handvol schaduwranden.
- **De lampen en de muren** veranderen het beeld niet. De getallen in de tabel zijn van de vaste standpunten, vóór de twee correcties uit "Onderweg gevonden". Erna zijn alle 91 standpunten van de contactbladen bekeken, op 1920×1080 (2,1 miljoen pixels), elk met en zonder: hooguit 1 039, 513 en 701 pixels verschil voor de lampen in de fabriek, op het fabrieksterrein en in de centrale, en 1 031, 500 en 715 voor de occluders, tegen 1 031, 503 en 696 voor twee keer hetzelfde.

De bladen met voor, na en het verschil, per maatregel het standpunt van elk level waar het meest verandert, staan in `benchmark/results/zestig/` van de worktree `.claude/worktrees/zestig` (niet in Git), met de contactbladen van voor en na erbij.

**Onderweg gevonden**

- **De renderer gebruikt acht lightmaps per frame, en het fabrieksterrein heeft er 23.** Liggen er in de kijkrichting meer dan acht dozen van lightmaps, ook van zones die uit staan, dan krijgen acht ruimtes hun gebakken licht en de rest niet. Zo'n ruimte wordt dan egaal verlicht door het hemellicht, zonder schaduw en veel lichter dan ze gebakken is: het magazijn van het fabrieksterrein is zonder lightmap gemiddeld vier keer zo licht als met. Welke ruimtes afvallen hangt af van de volgorde waarin de renderer ze tegenkomt, en die verschuift terwijl zones aan en uit gaan; hetzelfde standpunt komt er in het ene blad met en in het andere zonder uit. **Dat is niet van dit werk**: op het blad van de branch van vóór dit werk missen andere ruimtes hun licht dan op de bladen van erna (12 van de 56 standpunten van het fabrieksterrein verschillen), en met alle 23 lightmaps verborgen ziet het magazijn eruit zoals het daar stond. Het speelt op het fabrieksterrein en in de centrale (11 zones); de fabriek heeft er vier. Voor en na zijn hieronder met dezelfde ruimtes zonder licht gemeten, dus de vergelijking klopt; de bladen zelf laten een mengsel zien, zoals elk blad van die twee levels tot nu toe.
- **De occluders veranderden welke acht dat waren.** De doos van een lightmap achter een muur telde in de eerste versie niet meer mee, en in 13 van de 56 standpunten van het fabrieksterrein en 4 van de 25 van de centrale kwam een ruimte er anders uit, tot een vijfde van het beeld. Ik hield dat eerst voor licht dat verdween; het was licht dat terugkwam. De occluders laten lightmaps, lampen, reflectieprobes en decals nu met rust, zodat zij aan het beeld niets veranderen. Daarna is over alle 91 standpunten geteld wat hierboven staat.
- **De reparatie staat erin** (`_light()` in `scripts/zones.gd`), op 11 oktober op Michiels woord in de hoofdbranch gezet: alleen de lightmaps van de zones die getekend worden staan aan, en zijn dat er meer dan acht, dan die van de zones het dichtst bij de camera. Dertien van de 56 standpunten van het fabrieksterrein en drie van de 25 van de centrale worden er meer dan 10% donkerder van: de compressorruimte, het ketelhuis, de kantoren, de spuiterij, de loge, de oostgang, de regelkamer en het ketelhuis van de centrale komen eruit zoals ze gebakken zijn, warm onder hun lampen en donker daarbuiten, in plaats van egaal blauwgrijs. Het blad `lightmaps_zoals_nu_en_gerepareerd.jpg` zet negen ruimtes naast elkaar. Met de reparatie haalt elk standpunt van die twee contactbladen nog 60 fps (60 tot 85 en 62 tot 72, tegen 61 tot 86 en 66 tot 78), van zone wisselen duurt niet langer (de traagste frame bij een sprong naar een andere zone 35 tot 41 ms, tegen 38 tot 50) en de selftest slaagt. Het verandert hoe twee levels eruitzien: wie ze gespeeld heeft, kent een deel van de kamers lichter dan ze nu zijn.
- **Een lamp zonder schaduw verlicht de ruimte achter de muur, en dat is te zien.** De eerste versie bond elke lamp. In zes standpunten van het fabrieksterrein en drie van de centrale werd het daar donkerder van: de linkerhelft van de ontvangst van de centrale had haar licht van een buis in de kabelgang ernaast. Dat is een lek, maar het is het licht waarmee het level is gemaakt en bekeken. Alleen de lampen met schaduw worden nu gebonden; bij hen kwam er achter de muur niets aan.
- **De sortering in de schaduw en de zon zelf leveren verder niets op.** Zeventien van de 38 zones krijgen geen zon. Alles wat in de schaduw staat buiten het licht van de zon houden: niets te meten, want de schil van een zone slaat de gebakken zon al over. Twee schaduwkaarten in plaats van vier: 0,1 ms, en te zien.
- **Een rij runs zonder pauze laat andere sessies wachten.** Mijn runs volgden elkaar binnen een seconde op; een andere sessie, die netjes wachtte tot de GPU vrij was, kwam een uur niet aan de beurt en meldde het. Sindsdien start een run pas als er een tijd lang geen andere Godot heeft getekend.
- **Michiel speelde zelf, in een venster, en dat zag mijn controle niet**: die keek alleen naar Godot zonder venster. Twee keer liep er anderhalve tot twee minuten een meting naast zijn spel. Die metingen zijn weggegooid en opnieuw gedaan; een run breekt nu af zodra er naast hem een andere Godot tekent.
- **Een laadcontrole met `--play` schrijft in het savebestand.** Om te zien of een level nog laadde startte ik het een keer of twaalf zonder venster met `--play`, en elk daarvan zette een checkpoint in Michiels `save.cfg`. Zo'n controle krijgt nu een eigen `HOME`.

**Gecontroleerd, en wat niet**

- `tools/selftest.sh` en `tools/nettest.sh` slagen op de samengevoegde hoofdbranch, met een eigen `HOME` omdat andere sessies tegelijk testten.
- Met `--undo=all` haalde de branch in de fabriek de cijfers van de kopie van ervoor: 46,2 tot 51,2 fps tegen 46,5 tot 51,4. De "voor" van de tabellen is daarom zo gemeten: de samenvoeging met `wapens` zette andere wapens en handen in beeld, en daarmee was de kopie niet meer te vergelijken.
- **Ik heb het alleen in screenshots gezien.** Alles is gemeten zonder venster en vergeleken door pixels te tellen en de bladen te bekijken. Michiel heeft de samengevoegde stand op 11 oktober gespeeld; wat hij ervan vond, staat hier nog niet.
- De frametijden zijn die van een camera die stilstaat. In beweging komen daar de schaduwen bij die een lamp opnieuw tekent als er iets onder beweegt; dat is alleen in het ene gevecht hierboven gemeten.
- **Een standpunt buiten het level is niet te vertrouwen.** Staat de camera in geen enkele zone, dan tekent het level alle zones tegelijk, en dan zijn er meer lampen met schaduw in beeld dan de atlas plaats heeft. Welke lamp dan zonder schaduw blijft, wisselt van keer tot keer: op het dak van het magazijn van het fabrieksterrein scheelde dat 30 duizend pixels tussen twee runs die verder gelijk waren. Dat was er al, en in het spel komt de camera daar niet. Ik hield het eerst voor een fout van de lampen per zone.
- De eerste keer dat iets getekend wordt kan haperen. De occluders stellen dat moment uit voor wat achter een muur staat; het is niet geteld met de teller van pipelines.
- Samen spelen is getest met `tools/nettest.sh`, niet gespeeld. Lagen en maskers zijn op elke machine eigen en gaan niet over het net.
- De Compatibility-renderer, waar de kleurzweem terugvalt op de lenspass, is niet gestart.
- De pixels per maatregel zijn geteld vóór de samenvoeging met de hoofdbranch en, voor de instellingen van Ultra, vóór de twee correcties; die raken de lampen en de occluders, en die twee zijn daarna over alle standpunten opnieuw geteld.
- Low, Medium en High zijn niet opnieuw gemeten. Ze krijgen de lampen per zone, de occluders en de drie instellingen ook.

**Werkwijze**

| Stap | Hoe |
|---|---|
| Een level op de instellingen waarmee gespeeld wordt | `tools/benchmark.sh --res=3456x2160 --scale=auto --upscaler=metalfx --quality=3 --weapon=0 --scene=res://scenes/works.tscn` |
| Hetzelfde op de maat van het scherm | `tools/godot.sh --resolution 1728x1080 -- --benchmark --res=3456x2160 --scale=auto --upscaler=metalfx --quality=3 --weapon=0 --scene=res://scenes/works.tscn` |
| Eén maatregel terugzetten, of alle | dezelfde opdracht met `--undo=lamp_filter` of `--undo=all` |
| Het contactblad op die instellingen | `tools/zone_sheet.py works --res=3456x2160 --upscaler=metalfx --scale=0.5 --quality=3` |
| Wachten op de GPU als er meer sessies meten | `tools/godot.sh` neemt sinds de samenvoeging met de hoofdbranch zelf het slot (`tools/gpu_slot.sh`). Een spel dat Michiel uit de editor of een terminal start kent dat slot niet: daarvoor met `ps` kijken, ook naar een Godot met venster, en stoppen zodra hij begint |

**Nog open**

- **Waar meer dan acht zones tegelijk getekend worden**, uit de westgang van het fabrieksterrein zijn dat er negen, valt de verste nog altijd af en wordt zonder gebakken licht getekend.
- **Wat over het licht van het fabrieksterrein en de centrale is gezegd, is gezegd over kamers die deels te licht waren.** Elk contactblad en elke screenshot van die twee levels van vóór de reparatie van de lightmaps laat een wisselend deel van de kamers vlak en te licht zien, ook die in "Stap 5" en "De centrale". Of de ontvangst, de schakelruimte en het pompenhuis te donker zijn om bij te vechten, moet opnieuw bekeken worden, nu ze zijn zoals ze gebakken zijn.
- **MSAA 4× is wat Ultra nog kost**: 0,9 tot 1,4 ms boven 2×. Wie meer marge wil dan er nu is, vindt die daar; het is op de bladen het best te zien van alles wat overwogen is.
- **SSR kost 1,4 tot 1,9 ms**, op High en op Ultra. Het halve aantal stappen scheelt 0,25 ms en is te zien; verder is er niet naar gekeken.
- **De schaduwen van de lampen blijven de grootste post per pixel.** Een pixel betaalt voor elke lamp met schaduw binnen wiens bereik hij ligt, ook waar die lamp nauwelijks nog licht geeft. Korter bereik of minder lampen met schaduw verandert het licht en vraagt de levelbouwer.
- **Een robot hoort bij geen zone.** Loopt hij door een gang, dan tekenen de lampen in de kamers ernaast, binnen wiens bereik hij door de muur heen ligt, hun schaduw opnieuw. De zone waarin hij staat is elk frame bekend; zijn laag kan die volgen.
- **De zon helemaal uit waar geen zonlicht in beeld kan zijn** zou nog een halve milliseconde schelen, maar vraagt te weten wat er door elk raam te zien is.
- **De lampen zonder schaduw schijnen door muren**: 36 van de 83 op het fabrieksterrein, 20 van de 43 in de centrale. Ze een schaduw geven kost plaats in de atlas, ze een korter bereik geven verandert het licht; allebei is het werk van de levelbouwer. Daarna kunnen ook zij aan hun ruimte gebonden worden.
- **De occluders kijken met een grof beeld**: de renderer bepaalt wat verborgen is op zo'n 95 bij 54 punten. Een robot die alleen door een kier ver weg te zien is, kan een frame wegvallen. Niet gezien in de screenshots, en niet in beweging bekeken; `rendering/occlusion_culling/occlusion_rays_per_thread` in `project.godot` maakt het fijner.
- De benchmark tekent 3840×2160 als er 3456×2160 gevraagd wordt, en het fabrieksterrein heeft de standpunten van de fabriek: beide zijn van `scripts/benchmark.gd` en `scenes/works.tscn`.

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
- Een robot die stilstaat, wiegt met zijn romp. Dat is duur: met alle robots wiegend op hun post haalde het standpunt Overview 67,2 fps, tegen 71,3 fps met de robots roerloos, vijf keer om en om en elke keer 2 tot 6 fps verschil. Ik vermoed dat elke lamp met schaduw waar zo'n robot onder staat daardoor elk frame zijn schaduwen opnieuw tekent; dat heb ik niet apart gemeten. Een robot die uit staat, staat daarom helemaal stil: zijn knoop staat op `PROCESS_MODE_DISABLED`, met `disable_mode` zo dat hij te raken blijft. Voor een robot die aan staat en even niets doet, gold het nog tot 11 oktober; zie "Houding en beweging".

**Nog open**

- Een robot die uit staat, komt alleen in actie als de speler zijn zone binnenloopt of op een robot van die zone schiet. Staat hij in het zicht terwijl er in de zone ernaast wordt gevochten, dan staat hij erbij. Vanaf waar je de containerrijen van het depot binnenloopt staat er zo één op het perron in het zicht, op 21 m; vanaf de deur van de aanbouw staat er in de hal geen robot van het westelijke deel meer in het zicht. Verderop in een zone kan dat anders zijn: de selftest kijkt alleen vanaf waar een zone wordt binnengelopen.
- Aan een robot was niet te zien dat hij uit staat. Nu wel: zie "Houding en beweging".
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
| 5. Het eerste grote level | Ongeveer 20 zones en 80 vijanden, 15 tot 20 minuten spelen | De route is te lopen en elke zone haalt het budget | Gebouwd, gebakken en gemeten: het fabrieksterrein, 23 ruimtes en 59 robots. Twee keer kort gespeeld, in een build die de renderschaal van de hoofdbranch nog miste. Zie hieronder |

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
- Een ruimte is een rechthoek langs de assen met een vlak plafond. Geen schuin dak met spanten, geen tussenvloer, geen trap, geen terrein onder de open lucht. (Het terrein kwam er in stap 5 bij, daken met spanten onder "Kit-ruimtes".)
- Tussen twee ruimtes staan twee muren rug aan rug. Dat houdt elke zone gesloten voor zijn bake, en kost muur die niemand ziet.
- Wat er met de hand in komt, moet het plan zelf vrijhouden; de bouwer weet niet hoe groot een pers is.
- De werkbank, het leidingwerk van de gang en de kraan uit de bouwdoos kunnen nog steeds maar in één richting staan. (Sinds "Kit-ruimtes" is er leidingwerk en een werkbank die in elke richting kunnen; de kraan niet.)

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

- `tools/selftest.sh` slaagt met het fabrieksterrein erin, 197 controles (264 sinds de samenvoeging met de hoofdbranch, die het beeld en wat kapot kan meetest), waaronder: de route is te lopen, elke robot kan de speler bereiken, geen robot staat in zicht waar zijn zone betreden wordt of bij een checkpoint, en geen zone die uit staat is te zien. `tools/selftest.sh --fights` en `tools/nettest.sh` slagen ook; de nettest loopt nu van de fabriek naar het fabrieksterrein.
- Het fabrieksterrein komt bij twee keer bouwen gelijk uit. In de fabriek veranderde alleen wie wie ziet en waar de uitgang heen leidt; het depot en de modellen zijn gelijk gebleven. Alle lightmaps zijn bij.
- De vleugel is opnieuw gebouwd met de schermen en de posten van nu, en zijn magazijn en werkplaats zijn opnieuw gebakken.
- **Gespeeld is het niet.** Of elf gevechten met 73 robots een kwartier boeiend blijven, of de schermen eerlijk aanvoelen en of de checkpoints goed liggen, weet ik niet.
- Met de robots op hun post haalt één standpunt 59 fps. Dat is met alle 73 nog overeind; wie in de spuiterij staat heeft de montagehal al leeg. Een gevecht zelf is op het fabrieksterrein niet gemeten.

**Na de eerste keer spelen**, 11 oktober 2026

Michiel startte het fabrieksterrein twee keer vanuit de worktree. Volgens het savebestand eindigde de tweede beurt na 41 seconden, met een dood en zonder het eerste checkpoint. Twee dingen zaten hem in de weg, en geen van beide is het level zelf.

- **`bouwdoos` miste tot de samenvoeging de renderschaal die zichzelf instelt.** Die kwam op 10 oktober op `fase-2-vertical-slice`, nadat `bouwdoos` was afgetakt. Zijn instellingen (Ultra, MetalFX, `auto_scale`) las die build als een renderschaal van 100%. Gemeten aan het begin van het fabrieksterrein, van de portiersloge tot de deur van het magazijn:

| Op zijn instellingen | Fps |
|---|---|
| Volledig scherm, 3456×2160 op 100%: wat die build deed | 13 tot 17 |
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
- De kantoren zijn kaal: een bureau, een stoel en een kast op ruim 90 m². De schermen zijn overal dezelfde drie stapels pallets. (Beide aangepakt onder "Kit-ruimtes".)
- De schaduwsortering kijkt bij het laden. Een model dat in de schaduw stond van iets dat wordt opgeblazen, werpt daarna nog steeds geen zonneschaduw.
- De lightmaps van het fabrieksterrein zijn 222 MB in Git LFS, naast ongeveer 130 MB van de fabriek, het depot en de vleugel. Hoeveel LFS-opslag er bij GitHub is, is op 11 oktober nagekeken: 10 GiB, zie "Meerdere agents tegelijk".
- **`bouwdoos` is op 11 oktober 2026 samengevoegd met `fase-2-vertical-slice`**, op Michiels woord: de renderschaal, de stemmen, wat stuk kan en de beweging van het beeld zitten er nu in. Het botste op de twee regels die de proef al gaf. In `_ready()` van `scripts/game.gd` staan ze allebei: eerst krijgt wat stuk kan zijn lichamen, dan wordt uitgezocht wat in de schaduw staat. In de levellijst van `scripts/menu.gd` staat het fabrieksterrein tussen de fabriek en het depot met hetzelfde muziekstuk als die twee, zodat het doorspeelt in plaats van het langste level stil te laten; dat is niet op het gehoor gekozen. `scripts/shade.gd` laat wat stuk kan buiten wat de zon tegenhoudt: zes modellen, vier in de fabriek en twee op het fabrieksterrein, stonden alleen in de schaduw doordat er een stapel kisten tussen hen en de zon stond, en bleven buiten de schaduw van de zon als die stapel was weggeschoten. Er staan er nu 198 en 755 in de schaduw, tegen 202 en 757. Op het geheel slagen `tools/selftest.sh` (264 controles), `tools/test_humanoid.sh` en `tools/nettest.sh`; een herbouw geeft de bewaarde levels terug en `tools/bake_lightmaps.py --list` noemt elke zone bij. Er is niets herbouwd of opnieuw gebakken. De framerate van het fabrieksterrein is dezelfde als ervoor (72 tot 95 fps op 1440p met FSR 2 op 67%). Nog te doen: het contactblad opnieuw maken, want kratten en lampen kunnen nu stuk en de tekenopdrachten zijn op een paar standpunten een handvol hoger, zie "De repetitie verschuift de teller van tekenopdrachten" onder "Wat er kapot kan". Een worktree die de hoofdbranch binnenhaalt moet de nieuwe geluiden nog inlezen (`godot --headless --path . --import`).
- Elke kamer een eigen gevecht, in plaats van een vleugel als één gevecht, geeft 21 kleine gevechten en houdt alle robots. Dan moet de speler elke kamer in, en de regel dat de route door elk gevecht loopt vervalt. Dat is niet besloten.

## De centrale: het vierde level

Op 11 oktober 2026 gevraagd: een heel nieuw level op de standaard van nu. Dat is de centrale geworden (`tools/levels/powerhouse.gd`, `scenes/powerhouse.tscn`), de elektriciteitscentrale van het fabrieksterrein, gebouwd met de bouwdoos en de plattegrond van "Grotere levels bouwen". Het thema is door de sessie gekozen, niet door Michiel. Het is gebouwd op branch `centrale` en dezelfde dag, op zijn woord, in `fase-2-vertical-slice` gezet en gepusht, met zijn lightmaps in Git LFS.

**Wat er staat**

- **Elf ruimtes op 76 bij 56 meter.** De speler komt binnen waar de stroom naar buiten gaat en werkt terug naar waar hij gemaakt wordt: de ontvangst, een kabelgang, de schakelruimte, het schakelterrein onder de open lucht, het pompenhuis, de werkplaats, het ketelhuis met de brandstofopslag eraan, een gang, de regelkamer en de turbinehal. De grote deur aan het eind van de hal is de uitgang.
- **Dertig robots in zeven gevechten**, drie checkpoints. Geen gevecht is groter dan die van de fabriek en het depot: 3, 4, 4, 4, 6, 3 en 6. De eerste heavy staat in de werkplaats, de laatste twee in de turbinehal.
- **Het zit in het spel.** De levelkeuze is Factory, Works, Depot, Powerhouse; roldeur 3 van het depot leidt naar de centrale, en de uitgang van de centrale sluit het spel af. `VERSION` in `scripts/net.gd` is daarom 5.
- **Een nieuwe la in de bouwdoos**, `tools/kit/power.gd`, met wat stroom maakt, schakelt en wegstuurt: `turbine` (een turbogenerator op zijn fundatieblok: regelaar, hogedruk- en lagedrukcilinder, generator en opwekker op één as, met de stoomleidingen en hun afsluiters), `transformer` (tank met radiatoren, conservator en doorvoeringen op een plint met oliekering), `switchboard` (een rij schakelkasten, of met `instruments` het paneel van een regelkamer), `control_desk`, `lattice_mast` en `lattice_girder`, `wire`, `insulator_string`, `wall_insulator` en `cable_ladder`. In `tools/kit/plant.gd` is `vessel` erbij gekomen, een liggend drukvat, en de ketel neemt zijn nummer aan. Alles staat in de showroom.
- **Vijf materialen**: grijze machinelak, porselein, koper, en een rood en een groen signaallampje. **Vijf opschriften** in het manifest: K2, G1, G2, 10 kV en DANGER.
- **Een soort ruimte erbij**, `control`: gepleisterd, tl-buizen, en niets wat de bouwer er zelf neerzet.
- **Een gevecht zonder schermen** (`fight(..., false)`). Waar een ruimte eigen machines heeft om achter te wachten, zet de bouwer geen drie stapels pallets meer neer. De robots van de schakelruimte wachten tussen de schakelkasten, die van het pompenhuis achter de rij starters, die van het ketelhuis achter de ketels, die van de regelkamer achter het instrumentenpaneel dat de kamer in tweeën deelt, en die van de turbinehal achter de machines of ver weg. Het terrein en de werkplaats houden de schermen van de bouwer: containers en pallets.

**Wat elke ruimte tot die ruimte maakt**

| Ruimte | Met de hand erin |
|---|---|
| Ontvangst | De dichte roldeur waar het depot achter ligt, en een buis erboven die nog brandt |
| Kabelgang | Een kabelladder langs het plafond |
| Schakelruimte | Twee rijen van negen schakelkasten tegenover elkaar, rubber matten, kabelladders naar de muur van het terrein |
| Schakelterrein | Drie transformatoren in hun vak tussen scherfmuren, een portaal van vier masten ervoor, en negen lijnen die over de muur binnenkomen van een mast daarbuiten |
| Pompenhuis | Negen starters dwars door de ruimte, vier pompen tussen een zuig- en een persleiding, twee voedingstanks en een voorwarmer |
| Werkplaats | Draaibank, pers, werkbanken, boormachines onder de ramen |
| Ketelhuis | Twee ketels naast elkaar met hun front naar de stookvloer, K1 en K2, een voedingstank, pompen, meters en vaten brandstof |
| Brandstofopslag | Een olietank, vaten, jerrycans en gasflessen: een ruimte om buiten te blijven of in te schieten |
| Regelkamer | Het instrumentenpaneel met de relais in zijn rug, en de lessenaar ervoor |
| Turbinehal | Twee turbogeneratoren in lijn, G1 en G2, de kraan erboven, de stoomleiding langs de zuidwand, een lamp boven de eerste machine en verf op de vloer |

**Het licht.** De avondzon staat laag in het zuidzuidwesten. Ze valt door de zuidramen van het ketelhuis en de turbinehal, door de westramen van de werkplaats, de schakelruimte en de opslag, en door ramen boven het dak van de lagere buren: in het ketelhuis boven de brandstofopslag, in de hal boven de regelkamer. Op het terrein staan de transformatoren en het portaal in de zon en ligt de zuidelijke helft in de schaduw van de muur. Het pompenhuis heeft geen ramen.

**Gemeten** op 11 oktober 2026, met niets anders op de GPU

| | |
|---|---|
| De centrale beschreven | 503 regels in acht bestanden; de la `power.gd` is er 575 |
| Gebouwd | 2476 nodes, 511 modellen, 280 decals, 43 lampen |
| Bouwen | 11 s, waarvan 6,6 s de opmeting |
| Zichtlijnen | 14 paren; het ketelhuis en de turbinehal zien elkaar niet |
| Alle elf ruimtes bakken | 4 min 35 s met het starten van de editor; de turbinehal 60 s, de werkplaats 46 s, het terrein 38 s |
| Lightmaps | 137 MB op schijf, 82 MB op de videokaart |
| Laden | 0,4 tot 0,6 s; 495 MB op de videokaart, waarvan 404 MB texturen |

**Het contactblad**, 25 standpunten

| | Tekenopdrachten | Driehoeken | Fps | Het zwaarste standpunt |
|---|---|---|---|---|
| 1440p met FSR 2 op 67%, zonder robots | 220 tot 1092 | 0,5 tot 2,2 miljoen | 68 tot 81 | de kabelgang en de werkplaats: 68 fps |
| Met de dertig robots op hun post | 327 tot 2529 | 0,5 tot 2,7 miljoen | 66 tot 81 | de werkplaats: 66 fps |
| 3456×2160 met MetalFX op 50% | 216 tot 1098 | 0,5 tot 2,3 miljoen | 68 tot 82 | de werkplaats: 68 fps |

Elke ruimte haalt het keurmerk. Op de instellingen waarmee gespeeld wordt (Ultra, volledig scherm, renderschaal vanzelf) halen de vijf vaste standpunten van de centrale 45 tot 52 fps, en de fabriek in dezelfde meting 47 tot 52.

**Gecontroleerd, en wat niet**

- `tools/selftest.sh` slaagt met de centrale erin, 312 controles: de route is te lopen en komt door elk gevecht, elke robot kan de speler bereiken, geen staat dichtbij in zicht waar zijn gevecht begint of bij een checkpoint, geen ruimte die uit staat is te zien, de checkpoints overleven een herstart en een dood, de grote deur gaat open en het spel eindigt erachter. Van de vijf grunts in de hal van de fabriek vechten er nog steeds vijf vanuit dekking. `tools/nettest.sh` slaagt ook.
- `tools/build_check.py`: de fabriek, het fabrieksterrein, de vleugel en de modellen komen er gelijk uit. Veranderd zijn de showroom, door wat erbij staat, en van het depot alleen waar de uitgang heen leidt. Er is niets anders opnieuw gebakken.
- Het spel start de centrale en laat de HUD zien wat er te doen is (`Reach the switch room`).
- De nieuwe stukken zijn bekeken in de showroom, en elke ruimte op het contactblad en vanaf twintig eigen standpunten.
- **Gespeeld is het niet.** De selftest loopt de route af en legt de robots om; of de gevechten goed voelen, of de rij starters en het instrumentenpaneel eerlijk zijn als schuilplaats, en of dertig robots de juiste maat is, weet ik niet.
- De muziek is het stuk van de andere drie levels. Niemand heeft dat op het gehoor gekozen.

**Onderweg gevonden**

- **Een checkpoint in een ruimte waar ook gevochten wordt, moet zijn plek vrijhouden vóór het gevecht gepland wordt.** `fight` zet zijn schermen neer op het moment dat het genoemd wordt, `checkpoint_in` houdt het midden pas daarna vrij. In de werkplaats kwam er zo een stapel pallets op het checkpoint, en de bouwer meldde dat het niet te bereiken was. Het plan houdt die twee plekken nu zelf vrij, vóór de gevechten.
- **Ramen koppelen ruimtes die niets met elkaar te maken hebben.** Een zuidraam in de schakelruimte keek door een westraam de werkplaats in, en een oostraam van het ketelhuis door de zuidramen de turbinehal in: de bouwer tekende ze dan samen. Die ramen zijn weg.
- **Drie deuren op één lijn.** Van het terrein door het pompenhuis en de werkplaats was het ketelhuis te zien. De deur tussen pompenhuis en werkplaats ligt daarom in de zuidhoek en die naar het ketelhuis ver naar het westen.
- **Een rij kasten dwars door een ruimte snijdt haar in tweeën** als er aan de ene kant een tank en aan de andere een vat tegenaan staat: het navmesh vraagt meer dan een meter. De bouwer meldde het als "ruimte voor 0 robots" in elke ruimte erna.
- **Welke lampen de bouwer uit laat, valt niet altijd goed.** Boven de eerste turbine en boven de ingang van de hal waren ze alle drie uit, en boven de pompen ook: de machine die de speler het eerst ziet stond in het donker. Daar hangt nu een lamp bij, met de hand; in de ontvangst een buis boven de roldeur.
- De turbinehal is hoger dan de muur van het terrein, en een ruimte die uit staat wordt niet getekend. Vanaf het terrein stond er lucht waar de hal hoort. `outside.gd` zet daar nu een strook baksteen en een dakrand neer, die altijd getekend worden.

**Werkwijze**

| Stap | Hoe |
|---|---|
| De centrale bouwen | `tools/build_level.sh powerhouse`, dan `tools/level_map.py powerhouse` om haar van bovenaf te zien |
| Een stuk uit `power.gd` van dichtbij bekijken | `tools/build_level.sh showroom`, dan `tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="24,2.4,17.5,0,-8"` |
| Bakken wat veranderd is, als er geen andere Godot draait | `tools/bake_lightmaps.sh res://scenes/powerhouse.tscn` |
| Het keurmerk en het contactblad | `tools/zone_sheet.py powerhouse`, met `--posted` voor de robots erbij |
| De vijf vaste standpunten | `tools/benchmark.sh --quick --scene=res://scenes/powerhouse.tscn`, met `--exit` voor de open deur |
| De centrale spelen in een venster | `/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/powerhouse.tscn -- --play`, of in het spel: Play, Powerhouse |

**Nog open**

- De machines zijn dicht. Op het fundatieblok van een turbine kan niemand staan en de hal heeft geen bordes: een ruimte uit de plattegrond is een vlakke vloer onder een vlak plafond.
- De lijnen van de mast buiten naar het portaal liggen grotendeels buiten het terrein en horen daarom bij geen ruimte: ze worden altijd getekend.
- De ontvangst, de schakelruimte en het pompenhuis zijn donker, zoals de kleedkamer van de fabriek. Of dat sfeer is of te weinig om bij te vechten, moet het spelen uitwijzen. (Sinds "Kit-ruimtes" zijn ze dat niet meer: zie de lichtregel daar.)
- De schermen op het terrein en in de werkplaats zijn nog die van de bouwer. In de werkplaats staan zo twee wanden van pallets op 180 m². (Sinds "Kit-ruimtes" kiest de bouwer uit tien vormen.)

## Kit-ruimtes: daken, wanden, inrichting en licht uit de bouwdoos

Op 11 oktober 2026 gevraagd: het fabrieksterrein en de centrale zijn uit de plattegrond gebouwd en zagen eruit als dozen, met vlakke plafonds, kale wanden, bijna zwarte kamers en overal dezelfde drie stapels pallets en dezelfde kisten. De met de hand gebouwde fabriekshal is de maat. Gebouwd op de branch `kitruimtes` en niet in de trunk gezet. De trunk van 11 oktober, met de zestig beelden en de tweede ronde geluid, is wel in de branch samengevoegd: zie "Met de trunk erin". De fabriek en het depot zijn niet aangeraakt.

**Wat er staat**

- **Drie laden erbij in de bouwdoos**, en de plattegrond (`rooms.gd`) is nu de laatste van de ketting, zodat ze uit alle andere kan putten:
  - `tools/kit/structure.gd`: `roof()` in vijf vormen (een vlakke plaat, een plaat op betonbalken, een plat stalen dak op liggers met een daklicht per travee, een zadeldak op spanten met dakramen in beide dakvlakken, een sheddak met glas in de steile kant en de vakwerkligger in dat glas), en wat een wand geleedt: `pier`, `corbel`, `plinth` en `buttress`. Een dak sluit de rechthoek van zijn wanden af, topgevels inbegrepen, zodat de zone eronder dicht is voor haar bake op het glas na; `roof_height()` zegt hoe hoog zijn onderkant boven een plek hangt.
  - `tools/kit/services.gd`: wat door een gebouw loopt en aan zijn wanden hangt. `pipe_run` (met bochten, flenzen en beugels), `pipe_valve`, `duct_run`, `round_duct`, `sprinkler_line`, `cable_tray`, `wall_pipe`, `downpipe`, `switch_drop`, `radiator`, `sign_plate`, `wall_lamp`, `pin_board`, en `hang` voor een model aan de wand. Alles neemt een plek op de wand en de kant waar de wand heen kijkt, en kan dus aan elke wand: het leidingwerk van de gang en het prikbord uit `fittings.gd` konden maar in één richting.
  - `tools/kit/furniture.gd`: wat in code gemaakt is en ergens staat. `filing_cabinets`, `counter`, `table`, `bench` (een vrijstaande werkbank met bankschroef en gereedschap), `shelving` (met archiefdozen en ordners), `slat_bench`, `wash_trough`, `kitchen_range` met afzuigkap, `screens` (lasschermen), `plate_rack`, `cable_drum`, `case` en `cases`, `spray_booth`, `pile`.
- **Een ruimte krijgt haar dak naar haar soort**, en een plan kan het per ruimte anders zeggen in het laatste argument van `room()`: `{"roof": "sawtooth", "glazed": SOUTH}`. Een hal heeft spanten met dakramen, een installatieruimte een plaat op balken, de rest een vlakke plaat. Op het fabrieksterrein: de montagehal een sheddak met het glas naar de avondzon, de werkplaats en het laadperron spanten, de spuiterij een plat stalen dak met daklichten. In de centrale: de turbinehal spanten met een dakraam in elke travee, de werkplaats spanten. Hallampen hangen onder een schuin dak tussen de spanten, zoals in de fabriek, waar een kraan eronderdoor kan.
- **De wanden zijn geleed.** Onder elk spant, elke ligger en elke balk een pilaster, of een console waar een deur of raam in de weg zit; een betonnen plint langs baksteen en een stootrand langs pleisterwerk; steunberen, regenpijpen en een camera tegen de muren van een terrein. De spanten van de werkplaats, het laadperron en de turbinehal staan tussen de ramen (`"lines"` in het plan), en de consoles van de kranen liggen op de pilasters (`piers_along()`).
- **Boven elke deur een bord** met de naam van de ruimte erachter, en `EXIT` boven de uitgang: 29 opschriften erbij in het manifest. De HUD zegt "Reach the switch room"; nu staat op de deur welke dat is.
- **Leidingwerk onder elk plafond**: in een gang een kanaal met roosters, een kabelladder en een leiding; in een kantoor, kantine of keuken een kanaal langs de wand; boven een magazijn sprinklers met hun stijgleiding en afsluiter; in een hal een rond kanaal onder de trekstangen en een persluchtleiding langs de wanden met een aftakking per pilaster; in een installatieruimte twee hoofdleidingen onder de plaat en een kabelgoot langs de wand.
- **Inrichting per soort ruimte.** Twee soorten erbij, `kitchen` en `changing`, en zes voorraden die een plan aan een ruimte kan geven: `lodge`, `archive`, `tools`, `despatch`, `paint` en `bay`. Een kantoor heeft een bureau met wat erop lag, archiefkasten, boekenkasten en een tafel; een archief rijen stellingen; een kleedkamer kluisjes, banken en een wastrog; een keuken een fornuis onder een kap, werkbladen en kratten; een kantine tafels van twee soorten, een buffet, een theewagen en een dartbord; een werkhal werkbanken, een platenrek, kabelhaspels en pakkisten naast wat er al stond. Wat tegen een wand staat komt uit één regel, `_line_walls()`: een lijst van dingen met hun breedte, en de bouwer vult de vrije stukken wand.
- **Schermen in tien vormen**, waarvan de drie stapels pallets er nog één zijn: pakkisten in verband gestapeld, lasschermen, een platenrek, twee kabelhaspels, stellingen met een rug, een kast, kluisjes, een container, en in de spuiterij de spuitcabine zelf, die met haar rug naar de deur staat: de robots wachten erin. Een ruimte heeft ze om de beurt, naar wat er in zo'n ruimte zou staan (`SCREENS` in `tools/kit/rooms.gd`).
- **De lichtregel** (`_room_lamps()` in `tools/kit/rooms.gd`). De dobbelstenen laten een deel van de lampen uit, en daarna geldt: geen stuk vloer ligt verder van een brandende lamp dan haar licht reikt (4,6 m voor een tl-buis, 6,2 m en meer voor een hallamp), en anders gaat er een lamp aan; brede lage ruimtes hebben een tweede rij buizen. Wat er in een ruimte te zien is, het eerste waarvoor het plan de vloer vrijhoudt of wat `eye_catcher()` noemt, heeft een lamp een stap vóór de kant waar de speler vandaan komt, zodat zijn voorkant verlicht is en niet alleen zijn bovenkant; die brandt altijd. Die lamp en de lamp bij de deur zijn de twee die schaduw werpen. De met de hand bijgehangen lampen van de centrale (boven de roldeur, de pompen en de eerste turbine) zijn daardoor weg.
- **Wandlampen die niets kosten.** Boven elke deur van een terrein of een installatieruimte, en in een installatieruimte om de vijf meter langs de wand, hangt een lamp in een korf waarvan het licht helemaal in de lightmap gebakken is (`BAKE_STATIC`). Wat achter de schakelkasten en de ketels staat, staat zo niet meer in het donker, en er komt geen lamp bij die elk beeld berekend moet worden: de lamp zelf is er alleen voor de bake en gaat bij het laden uit het spel (`scripts/bake_only.gd`, aan de groep `Baked` van elke zone). Dat laatste was eerst niet zo, en toen kostten ze wel iets: zie "Onderweg gevonden". De prijs: zo'n lamp is voor het spel geen lamp en kan niet kapotgeschoten worden, en wat geen lightmap heeft, een model of een robot, krijgt er geen licht van.
- **29 modellen van Poly Haven** (CC0, 1k, samen 58,5 MB in `assets/models/`), opgehaald met `tools/fetch_assets.py`: een auto onder een hoes, een aggregaat, een vuurton, vuilnisbakken, kratten en bakken van kunststof, een legerkist, een schoolstoel en een kruk, drie tafels en een bank, een keukenkast, twee boekenkasten en een stelling, een theewagen, een magnetron, een televisie, een radio, een klok, een dartbord, een verbandtrommel, een camera, een klembord, papier, spuitbussen, een blik en een jerrycan schoonmaakmiddel. Een dertigste, `vintage_wooden_drawer_01`, is niet opgehaald: het bestand dat Poly Haven levert klopt niet met de checksum die het er zelf bij geeft.
- **Een eerste standpunt per ruimte**: wat de speler ziet als hij een stap binnen is door de deur waar de route hem brengt, en in de ruimte waar hij begint wat hij dan ziet. De bouwer zet het vóór de standpunten die hij zelf kiest (`_own_views()`).
- **`tools/room_sheet.py <level> --before=<andere checkout>`** kijkt vanuit die deuren in deze checkout en in een andere en zet de twee naast elkaar op één blad, met onder elk beeld hoeveel ervan bijna zwart is.
- **De bouwer controleert de route zoals het spel loopt.** Zie "Onderweg gevonden".
- De showroom heeft er een plaat bij met alle nieuwe stukken, en vier open loodsen onder de vier daken.

**Gemeten** op 11 oktober 2026. Er maten en testten de hele tijd andere sessies; tekenopdrachten en driehoeken hebben daar geen last van, de framerates wel.

| | Fabrieksterrein, was | Fabrieksterrein, is | Centrale, was | Centrale, is |
|---|---|---|---|---|
| Modellen geplaatst, soorten | 818, 36 | 561, 67 | 511, 41 | 378, 51 |
| Decals | 420 | 472 | 280 | 320 |
| Lampen, waarvan gebakken wandlampen | 83, 0 | 135, 19 | 43, 0 | 93, 35 |
| Lampen met schaduw | 47 | 31 | 23 | 17 |
| Zichtlijnen tussen ruimtes | 42 paren | 44 | 14 | 16 |
| Bouwen, waarvan de opmeting | 24 s, 19 s | 30 s, 22 s | 11 s, 6,6 s | 12 s, 6,2 s |
| Alle ruimtes bakken | 7 min 43 s | 6 min 23 s aan bakes | 4 min 35 s met het starten van de editor | 4 min 13 s aan bakes |
| Lightmaps op schijf | 229 MB | 196 MB | 138 MB | 130 MB |

Het contactblad en het keurmerk (`tools/zone_sheet.py`, 1440p met FSR 2 op 67%, zonder robots):

| | Standpunten | Tekenopdrachten | Driehoeken | Fps | Keurmerk |
|---|---|---|---|---|---|
| Fabrieksterrein, was (stap 5) | 56 | 146 tot 949 | 0,1 tot 2,0 miljoen | 65 tot 85 | gehaald |
| Fabrieksterrein, is | 78 | 215 tot 1791 | 0,1 tot 1,8 miljoen | 64 tot 82 | gehaald: "Every zone has what it is held to" |
| Centrale, was | 25 | 220 tot 1092 | 0,5 tot 2,2 miljoen | 68 tot 81 | gehaald |
| Centrale, is | 36 | 204 tot 1395 | 0,2 tot 2,1 miljoen | 64 tot 78 | gehaald |

Dit is de stand van vóór de trunk erin zat, gemeten naast andere sessies; hoe het er nu voor staat, ook op de instellingen waarop gespeeld wordt, staat onder "Met de trunk erin".

- **De tekenopdrachten zijn op het zwaarste standpunt bijna verdubbeld** en blijven onder de grens van 2000: de montagehal 1791, de spuiterij 1741. Het sheddak laat de zon binnen, en wat in de zon kan staan werpt haar schaduw weer (`scripts/shade.gd` haalt het niet meer uit de schaduwkaarten). De framerate is er niet onder gezakt: het langzaamste standpunt is 64 fps op beide levels. Op het fabrieksterrein zijn dat de gangen die acht ruimtes zien, zoals voorheen; in de centrale de werkplaats.
- **Hoe donker**, gemeten als het deel van een beeld dat donkerder is dan 6% grijs, vanuit de deur van elke ruimte:

| | Donkerste beeld, was | Donkerste beeld, is | Meer dan half zwart, was | is |
|---|---|---|---|---|
| Fabrieksterrein, 23 deuren | 52% bijna zwart (het archief) | 4% (de kleedkamer) | 1 | 0 |
| Centrale, 11 deuren | 33% (de brandstofopslag), 31% (de ontvangst), 30% (de schakelruimte) | 3% (de gang) | 0 | 0 |

  Over alle standpunten, ook die de bouwer zelf kiest: op het fabrieksterrein is van 78 beelden het donkerste voor 31% bijna zwart (een hoek van de oostgang, met de neus tegen een kast) en geen enkel voor meer dan de helft; in de centrale is het donkerste van 36 beelden 10%.

  Dit is opnieuw gemeten met de reparatie van het gebakken licht erin, aan beide kanten (zie "Met de trunk erin"), en de tabel is gebleven wat ze was. Aan de kant "was" komen er ruimtes donkerder uit dan eerst leek, omdat ze toen zonder hun lightmap getekend waren: de loge 16% bijna zwart waar 0% stond, de compressorruimte 15%. Aan de kant "is" worden 15 van de 78 standpunten van het fabrieksterrein een kwart donkerder (gemiddeld van 0,37 naar 0,28) en blijven ze op 2% bijna zwart of minder, op één na: de schakelruimte vanuit haar tweede standpunt gaat van 0% naar 10%, en naar 15% sinds de wandlampen uit het spel zijn, omdat de kasten daar geen licht meer van krijgen. De donkerste vijf zijn dezelfde: de oostgang 31%, het laadperron 23%, de westgang en de werkplaats 16%, de expeditie 9%. In de centrale verandert er niets boven de 3 punten, behalve de regelkamer vanuit haar tweede standpunt: 6%.
- `tools/selftest.sh` slaagt (315 controles), `tools/nettest.sh` ook (62). `tools/build_check.py`: de fabriek, het depot en de modellen komen er gelijk uit; veranderd zijn het fabrieksterrein, de centrale, de vleugel en de showroom. Een tweede keer bouwen geeft dezelfde bestanden en `tools/bake_lightmaps.sh --list` noemt elke ruimte van de drie levels bij.
- De vleugel is met dezelfde bouwdoos herbouwd en opnieuw gebakken (vijf ruimtes, 62 s, 35 MB); die staat niet in het spel.

**Met de trunk erin**

De trunk van 11 oktober is twee keer in de branch samengevoegd, zodat een build uit deze worktree elke instelling van de trunk kent: eerst `fa1a9b5` (zestig beelden op het volle scherm, en de tweede ronde geluid), en toen `zestig` daarna de reparatie van het gebakken licht in de trunk zette, `4cd05bf`. Niets botste; dit plan en het manifest voegden vanzelf samen.

- **De tests slagen op het resultaat**: `tools/selftest.sh` (315 controles) en `tools/nettest.sh` (62) na beide keren, `tools/test_sound.sh` (37 van 37) na de eerste; de tweede keer veranderde alleen `scripts/zones.gd`.
- **De muren die verbergen wat erachter staat, zijn dezelfde muren.** `_wall_off()` in `scripts/zones.gd` maakt van de dunne botsvormen van baksteen, beton en pleister occluders: 245 op het fabrieksterrein en 165 in de centrale, voor en na deze herbouw, geteld uit de scènes. Van de nieuwe stukken telt er geen mee: een dak en een plafond hebben geen botsvorm, een pilaster is te smal, en wat verder botst is van staal of hout. Er verdwijnt dus niets achter iets waar je doorheen kijkt.
- **Het geluid leest dezelfde ruimtes.** De galm volgt uit de dozen van een zone, en die zijn gebleven wat ze waren: de plattegrond en de hoogte tot de goot. De kap van een hal telt niet mee. De twee nieuwe soorten ruimte, keuken en kleedkamer, klinken als een kamer, wat ze als magazijn en kantoor ook deden.
- **De reparatie van het gebakken licht raakt wat hier over licht gezegd is, en het houdt stand.** `zestig` vond dat de renderer acht lightmaps per frame gebruikt, waar het fabrieksterrein er 23 heeft en de centrale 11: een wisselend deel van de ruimtes werd zonder gebakken licht getekend, egaal blauwgrijs en te licht. Dat gold ook voor de bladen en de cijfers van dit hoofdstuk. Met de reparatie in beide checkouts zijn de bladen met voor en na opnieuw gemaakt en is opnieuw geteld hoe donker elk standpunt is: zie "Hoe donker" hierboven. Vanuit de deur is het donkerste beeld nog steeds 4% bijna zwart op het fabrieksterrein en 3% in de centrale; de kant "voor" is donkerder dan ze eerst leek.
- **Vanuit de westgang van het fabrieksterrein worden negen zones tegelijk getekend**, die van voorheen: de gang zelf, de twee kantoren, het archief, de kleedkamer, het magazijn, de gereedschapsruimte, de loge en het voorportaal. De verste van de negen krijgt dan geen gebakken licht. De bouwer kan dat voorkomen door geen ruimte meer dan zeven andere te laten zien; dat is niet gedaan.
- **Het keurmerk, op de samengevoegde stand**: "Every zone has what it is held to" voor beide levels. Gemeten op 12 oktober om acht uur 's ochtends, met de accu vol, elk blad in één keer, terwijl een andere sessie testte (load 5 tot 9).

| | Standpunten | Tekenopdrachten | Driehoeken | Fps | Traagste standpunt |
|---|---|---|---|---|---|
| Fabrieksterrein | 78 | 215 tot 1777 | 0,1 tot 1,8 miljoen | 69 tot 87 | de werkplaats, vierde standpunt: 68,9 |
| Centrale | 36 | 204 tot 1338 | 0,2 tot 1,9 miljoen | 70 tot 84 | de turbinehal vanuit haar deur: 70,0 |

  De occluders halen er tekenopdrachten af: over alle standpunten van het fabrieksterrein samen 5%, en in de centrale 1338 waar 1395 het meeste was.
- **Op de instellingen waarop gespeeld wordt** (Ultra, MetalFX Spatial, renderschaal 50%), met `tools/zone_sheet.py <level> --res=3456x2160 --upscaler=metalfx --scale=0.5 --quality=3`. De benchmark tekent daarbij 3840×2160, 11% meer pixels dan het scherm (zie "Zestig beelden op het volle scherm"). Dezelfde ochtend, de zes bladen na elkaar, de oude levels uit een kopie van de trunk:

| | Standpunten | Fps | Onder de 60 | Traagste standpunt |
|---|---|---|---|---|
| Fabrieksterrein, het oude level | 56 | 62 tot 86 | 0 | de werkplaats: 61,9 |
| Fabrieksterrein, herbouwd, met de wandlampen nog in het spel | 78 | 60 tot 83 | 1 | de werkplaats: 59,9 |
| Fabrieksterrein, zoals het nu is | 78 | 61 tot 84 | 0 | de werkplaats en de montagehal: 61,0 |
| Centrale, het oude level | 25 | 65 tot 77 | 0 | de turbinehal: 65,2 |
| Centrale, herbouwd, met de wandlampen nog in het spel | 36 | 58 tot 74 | 3 | de turbinehal 58,4, de werkplaats 58,9 en 59,8 |
| Centrale, zoals ze nu is | 36 | 60 tot 79 | 0 | de turbinehal vanuit haar deur: 60,4 |

  De herbouw kost op het traagste standpunt van het fabrieksterrein 1 fps en in de centrale 5. De wandlampen kostten daarbovenop 3 tot 6 fps in en naast de installatieruimtes: zie "Onderweg gevonden". Per ruimte van de centrale, het traagste standpunt in het oude level, met de wandlampen en nu: de schakelruimte 69, 60 en 66, het pompenhuis 71, 64 en 70, het ketelhuis 69, 65 en 69, de werkplaats 66, 59 en 63, de turbinehal 65, 58 en 60.
- **De turbinehal is het krapst**: 60,4 fps vanuit haar deur, waar het oude level 65 haalde. Vanaf dezelfde plek: 16,6 ms tegen 15,2. Zonder alles wat geen lightmap heeft (de spanten en gordingen, het leidingwerk, de pilasters en consoles) is het 15,6. Het glas in beeld kost er 0,60 ms waar dat van het oude level 0,35 kostte: er zit nu een dakraam in elke travee. En er hangen tien lampen waar er acht hingen, met een iets groter bereik (15,2 m tegen 14,1). Wie daar marge wil, zet `"glass": "alternate"` in het plan of laat de lichtregel er twee lampen minder ophangen, en bakt de hal opnieuw.
- **De occluders en de gebonden lampen veranderen in de herbouwde levels niets aan het beeld.** Elk standpunt is gefotografeerd zoals het is, nog een keer, zonder de occluders en zonder de gebonden lampen (`--undo=occlusion`, `--undo=lamps`; 1920×1080, geteld wat meer dan 3% verschilt). Op het fabrieksterrein verschillen er hooguit 967 en 909 van de 2,1 miljoen pixels, tegen 890 voor twee keer hetzelfde; in de centrale 603 en 541 tegen 554.
- **De avond ervoor was de framerate niet te meten.** Om 20:14 was de accu leeg en ging de laptop slapen, midden in een meting; om 20:47 werd hij gewekt aan een telefoonlader van 20 W. Die levert een deel van wat de laptop onder deze last vraagt, en met een bijna lege accu erbij tekent hij met tussenpozen op halve kracht of minder. Een blad van de centrale, om 21:04 met de accu op 5%, mat op de eerste twee standpunten 74 en 65 fps en op de 34 daarna 8 tot 49. Om 21:36, met 10%, haalden beide levels het keurmerk, maar 33 van de 78 standpunten van het fabrieksterrein pas de tweede keer (34 tot 59 fps de eerste). De volgende ochtend, met de accu vol aan dezelfde lader, ging alles in één keer.
- **Niet gemeten**: op de maat van het scherm zelf (`tools/godot.sh --resolution 1728x1080 ...`, waar het spel volgens "Zestig beelden" een beeld of vier sneller loopt dan de benchmark zegt), in beweging, en in een gevecht.
- **`tools/clone_imports.py <andere checkout>`** haalt naar een checkout wat een andere al geïmporteerd heeft. Wie deze branch in de trunk zet, krijgt de bronnen van 39 lightmaps, 29 modellen en 29 opschriften, maar niet wat Godot ervan maakte: dat staat in `.godot/imported/`, buiten Git. Zonder speelt het spel uit de hoofdcheckout het fabrieksterrein met de lightmaps van vóór de herbouw op de wanden van erna, tot de editor alles opnieuw heeft geïmporteerd. Het gereedschap kloont van elke bron wat de andere checkout ervan maakte, als dat van dezelfde versie van de bron gemaakt is (197 bronnen, 339 MB, als klonen: het kost geen ruimte), en neemt de regel van de editor mee voor de veertien lightmaps waarvan het `.import`-bestand veranderde. Uitgeprobeerd op een kopie van de trunk met deze branch eroverheen, elk bestand met de tijd van nu, zoals Git het achterlaat: de editor is daarna in acht seconden rond en importeert niets, en het fabrieksterrein, de centrale, de vleugel en de showroom laden met alle 39 lightmaps en zonder één melding.

**Onderweg gevonden**

- **De bouwer keurde een route goed die het spel niet kon lopen.** Zijn controle telde twee stukken navmesh als verbonden zodra ze een hoekpunt delen; het padzoeken van het spel vraagt een gedeelde rand. In het laadperron stonden een pilaster, een haspel, twee stapels kisten, de auto en een stelling op een rij, elk een meter van de volgende: de vloer hing nog aan hoekpunten aan elkaar, en alle acht robots konden de speler niet bereiken. De selftest ving het ("every robot can reach the player from its post"), de bouwer niet. `_walked()` in `tools/level_builder.gd` volgt nu randen, de bouwer zegt hoeveel vloer van een ruimte niet te belopen is als dat meer is dan een hoek, en wat op de vloer komt te staan houdt 60 cm meer afstand dan het zelf reikt (`WAY_BETWEEN`). Wat hij nu meldt en wat er al was: 18 van de 68 m² van het pompenhuis ligt tussen de machines waar geen robot komt.
- **Een scherm kon zijn robots insluiten.** Wat tegen de wand staat hield alleen afstand tot het scherm zelf, niet tot de doorgang om zijn uiteinden. In het magazijn van de vleugel stonden de robots daardoor in het zicht: de plek achter het scherm was niet meer te belopen. `_plan_screens()` houdt nu aan beide uiteinden een doorgang vrij.
- **Een scherm met kieren is geen scherm.** De kisten stonden eerst los naast elkaar en de twee haspels rand aan rand: door de kier stond een robot in het zicht. De kisten zijn nu in verband gestapeld en de haspels staan een stap achter elkaar.
- **De bake zag een wachtende meting aan voor een tekenende Godot.** `tools/bake_lightmaps.py` zocht in de opdrachtregel van elk proces naar het pad van Godot, en een run van een andere checkout die op het GPU-slot wacht is een shell met dat pad erin. Zolang een andere sessie metingen in de rij had staan, weigerde elke bake. Het kijkt nu naar de naam van het programma dat draait.
- **Mijn eigen tijdslimiet hield het GPU-slot zes minuten bezet.** Het script dat een bake na een tijd afbreekt startte daarvoor een `sleep`, en die erfde het slot en bleef leven nadat de bake al geweigerd had. De sessie `zestig` en ikzelf wachtten daar van 17:38 tot 17:45 op. Wie een bewaker naast een run in het slot zet, moet die het slot laten loslaten (`exec 9>&-`) en hem met zijn `sleep` opruimen.
- **De spanten vielen eerst op de ramen.** Gelijk verdeeld stonden drie van de vier spanten van de werkplaats boven een raam, en vier van de vijf in de turbinehal: geen pilaster eronder. Een plan kan daarom zeggen waar ze staan.
- **De regelkamer van de centrale liep dicht** door een radiator onder haar raam: tussen de lessenaar, de stoel, een openstaande deurvleugel en die radiator bleef geen doorgang van een meter over. Het plan houdt de lessenaar en de weg eromheen nu vrij. Hetzelfde geldt voor alles wat met de hand tegen een wand hangt: de metersborden staan nu als vrij te houden in de plannen, anders zet de bouwer er een pilaster of een bord voor.
- **`covered_car` komt binnen met vier `VehicleWheel3D`'s**: de importer van Godot leest de namen van de wielen als een aanwijzing. Zonder voertuig eromheen doen ze niets; de wielen worden gewoon getekend.
- **De bake van de brandstofopslag waarschuwt** zestien tot dertig keer met `Inconsistency found in triangulation while building BSP` en is daarna in 18 s klaar. Dat is de waarschuwing die bij de werkplaats van stap 5 niet meer ophield; hier houdt ze op. De probes van die ruimte kunnen iets minder goed aansluiten.
- **De editor importeert opnieuw wat een ander `.import`-bestand kreeg, ook als wat hij ervan maakte er al ligt.** In `.godot/editor/filesystem_cache10` houdt hij van elke bron de checksum van haar `.import`-bestand bij. Klopt die niet meer, dan importeert hij, wat de checksums in `.godot/imported/` ook zeggen. Een bake die een lightmap een ander aantal lagen geeft, verandert dat bestand (`slices/vertical`): hier bij veertien van de 39. Op de proefkopie begon de editor daardoor aan die veertien; ik heb hem na ruim drie minuten gestopt, toen hij nog aan de eerste bezig was. Een bron die nieuw is, of veranderd met hetzelfde `.import`-bestand, neemt hij wel over op de checksum.
- **Een lader van 20 W is geen stroom om mee te meten.** Het is te zien aan een blad waarop de eerste twee standpunten gewoon meten en de rest de helft of minder, aan een run die tien seconden over een standpunt doet in plaats van drie, en aan `ioreg -rn AppleSmartBattery | grep InstantAmperage`: een getal van twintig cijfers is een negatief getal, de accu loopt dan leeg terwijl de lader erin zit. `pmset -g ac` zegt hoeveel watt de lader geeft. Een stuk van twintig seconden meet nog gewoon; daarna knijpt de laptop af. Tekenopdrachten, driehoeken en de beelden zelf hebben er geen last van.
- **De wandlampen die niets zouden kosten, kostten 1,1 tot 1,4 ms per beeld.** Gevonden toen de levels voor het eerst gemeten werden zoals er gespeeld wordt, en daarna vanaf drie plekken in de centrale om en om gemeten, twee ronden, met en zonder (de lampen uit het lopende spel gehaald met `--eval`): de schakelruimte 16,45 ms met haar elf wandlampen en 15,04 zonder, wat op de honderdste is wat het oude level daar kostte; de werkplaats ernaast, die er zelf geen heeft, 17,10 en 15,97; de turbinehal, waar er geen in de buurt hangt, 16,60 en 16,57. De renderer geeft een lamp aan elk pixel binnen haar bereik, ook door een muur heen. Wat een lightmap heeft slaat een gebakken lamp dan over, maar al het andere wordt er volledig door belicht: de modellen, het leidingwerk, de spanten, een robot, en daar staat een installatieruimte vol mee. De lamp `editor_only` maken helpt niet: een bake slaat zulke lampen over. Ze hangen nu in een eigen groep die bij het laden uit het spel gaat. Het beeld verandert er nauwelijks door, want hun licht op wanden en vloeren staat in de lightmap: over de 36 standpunten van de centrale verschilt hooguit 1% van de pixels, in de schakelruimte, waar de kasten vlak bij een lamp een fractie donkerder zijn. De lightmaps zijn niet opnieuw gebakken, want een bake ziet dezelfde lampen op dezelfde plek: de negen zones met zulke lampen zijn bijgeschreven met `tools/bake_lightmaps.sh --mark`.

**Buiten mijn bestanden geraakt**

- `tools/bake_lightmaps.py`: één functie, `drawing_godots()`, zie hierboven. Zonder kon ik niet bakken.
- `scripts/net.gd`: `VERSION` van 5 naar 6. "Raise it with anything that changes ... how a level is built", staat erbij: twee machines met een verschillend fabrieksterrein mogen niet samen spelen.
- `tools/room_sheet.py` is nieuw, en in `benchmark/sheets/` staan de bladen.
- `tools/clone_imports.py` is nieuw: zie "Met de trunk erin".
- `scripts/bake_only.gd` is nieuw, twintig regels: wat eronder hangt gaat bij het laden uit het spel. De levelbouwer hangt er de gebakken wandlampen aan.
- De opschriften in `assets/manifest.json` en `assets/decals/`, naast de modellen die bij de opdracht horen.

**Niet kunnen beoordelen**

- **Gespeeld is het niet.** De selftest loopt beide levels af en legt de robots om. Of de nieuwe schermen eerlijk aanvoelen, of een gevecht tussen haspels en pakkisten beter is dan tussen pallets, en of de robots in de spuitcabine een goede vondst zijn of een flauwe, weet ik niet. De pakkisten, lasschermen, haspels en het platenrek kunnen niet stuk, de stapels kisten van Poly Haven nog wel: er is dus meer vaste dekking dan voorheen.
- **Op de instellingen waarop gespeeld wordt is gemeten met een camera die stilstaat, zonder robots en zonder wapen in beeld.** Daar halen beide levels de 60, het krapst de turbinehal met 60,4: zie "Met de trunk erin". In beweging en in een gevecht komt daar bij wat de lampen aan schaduw opnieuw tekenen; `zestig` mat dat in de fabriek als twee tot drie fps op de 1% low, en hier is het niet gemeten.
- Of het sheddak met het glas naar het zuiden het goede is. Een echt sheddak kijkt naar het noorden; dit vangt de avondzon en geeft strepen licht door de hal. `"glazed": NORTH` in het plan draait het om, en dan staat er niets meer in de zon.
- Of de lichtere kamers de sfeer houden. Het archief, de kantine en de magazijnen waren schemerig en zijn nu gewoon verlicht.
- De borden boven de deuren zijn Engels, zoals de HUD.

**Werkwijze**

| Stap | Hoe |
|---|---|
| Een ruimte een ander dak, een andere voorraad of een ander bord geven | Het laatste argument van `room()` in het plan: `{"roof": "beams", "stock": "paint", "sign": "PAINT"}` |
| Zeggen wat de speler in een ruimte het eerst moet zien | Het eerste `keep_clear()` van die ruimte, of `eye_catcher()` |
| Iets dat met de hand geplaatst wordt, ook aan een wand | `keep_clear()` in het plan, vóór de gevechten: de bouwer weet niet wat een bestand van een ruimte er later in zet |
| Een stuk uit de nieuwe laden van dichtbij bekijken | `tools/build_level.sh showroom`, dan `tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="-13,1.7,21,15,-3"` |
| Een level voor en na naast elkaar | `tools/room_sheet.py works --before=<checkout van ervoor>`; het blad staat in `benchmark/sheets/` |
| Hoe donker elk standpunt is | `tools/room_sheet.py works --views=6` |
| Een bake met een tijdslimiet, achter in de rij van het GPU-slot | `tools/gpu_slot.sh <script dat de bake start en bewaakt>`: de limiet gaat dan pas in als het slot er is |
| Deze branch in de trunk zetten zonder dat de editor veertien lightmaps opnieuw importeert | De editor van de hoofdcheckout dicht, dan in de hoofdcheckout `git merge kitruimtes` en `tools/clone_imports.py .claude/worktrees/kitruimtes`; `--list` zegt eerst wat dat zou doen |
| Weten of de laptop de stroom heeft om te meten | `pmset -g ac` (de eigen lader van een MacBook Pro van 16 inch geeft 140 W, een telefoonlader 20) en `pmset -g batt` |

**Nog open**

- **Zichtlijnen hangen aan wat er toevallig staat.** In de centrale zien het ketelhuis en het pompenhuis elkaar nu door de werkplaats, en het pompenhuis en de schakelruimte over het terrein; op het fabrieksterrein de zuidgang en de werkplaats over het binnenterrein. Eerder stond daar een stapel pallets tussen. Het keurmerk haalt het, maar een deur die drie ruimtes verderop iets laat tekenen is toeval dat bij de volgende wijziging anders valt.
- **De halve wand tussen twee ruimtes blijft dubbel**, en een ruimte is nog steeds een rechthoek met een vlakke vloer: geen bordes, geen trap.
- **De kap van een dak is van buiten niet af.** Vanaf een terrein zie je een hal die niet getekend wordt niet; `wall_above()` zet de topgevel van de turbinehal boven de muur van het schakelterrein, verder nergens.
- De gebakken wandlampen kunnen niet stuk. Wie dat wil, maakt er gewone lampen van (`BAKE_DYNAMIC` en de naam `Bulb` in `wall_lamp()`, in de groep `Lights`), en betaalt dan 54 lampen die elk beeld berekend worden: in de schakelruimte van de centrale was dat 1,4 ms per beeld toen ze alleen nog voor wat geen lightmap heeft meetelden.
- Zes van de 29 modellen staan in de twee levels maar op één plek (de theewagen, de magnetron, het dartbord, de schragentafel, de boekenkast en de smalle boekenplank), en de legerkist nergens: ze staat bij wat een magazijn tegen zijn wanden kan hebben, en de dobbelstenen kozen haar in geen van de vier. Ze staat in de showroom.
- Het keurmerk kijkt niet naar hoe donker een beeld is. `tools/room_sheet.py` meet het; een grens in `tools/zone_sheet.py` zou het vasthouden.

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
- **Paniek** (`panics`, alleen in het thema `panic_clowns`, in het menu Panic Clowns). Wie nog 40% van zijn gezondheid heeft of een ander binnen 8 m ziet sterven, slaat door en komt daar niet van terug. Hij laat zijn wapen vallen, geeft zijn dekking en zijn beurt op en rent 1,35 keer zo snel van het ene willekeurige punt naar het andere, elke 0,8 tot 2,2 s een nieuw. Aanvallen doet hij niet meer en voor een granaat loopt hij niet meer weg; om een brand loopt hij nog wel heen. De armen boven het hoofd en het hoofd in de nek zet `humanoid_rig.gd` in code (`_flail`): er is geen clip voor. Hij schreeuwt met `human_panic`, acht opnames uit het stemmenpakket dat er al was (de lange kreten die voor een stervende soldaat te heftig waren), met 0,25 tot 0,9 s adem ertussen; de schreeuw loopt met hem mee (`Sfx.play_on`) en breekt af als hij valt. In een gedeeld spel reist het mee met waar hij is (richt-id -1), dus ook wie later binnenkomt ziet het. Bij `clown_05` trekt de mouw onder de oksel wat mee, wat als een wijde mouw leest. Huilen doet hij niet: daar is geen opname voor. De acht schreeuwen zijn door Michiel op het oor goedgekeurd, los beluisterd; gespeeld heeft hij het nog niet.

**Wat er te halen valt**

- **Health komt vanzelf terug tot 35** (Normal), na vier seconden zonder treffer. De rest zit in cellen die de vijanden achterlaten: 25 per stuk. Op de healthbalk staat een streep bij 35 en ernaast het getal, rood zolang je onder de streep zit.
- **Munitie.** Een wapen begint een level met twee magazijnen reserve in plaats van met alles wat het kan dragen (de karabijn 60 van de 150). Een blik munitie geeft een magazijn voor het wapen in de hand en een derde voor elk ander. Het pistool raakt nooit op (`bottomless`): er is altijd iets om mee te schieten.
- **Wat een vijand achterlaat** volgt wat de speler mist, zonder toeval (`LEAVES_CELL`, `LEAVES_CAN` en `LEAVES_GRENADE` in `scripts/game.gd`). Elke kill telt een deel van een cel, een blik en een granaat op, en er valt iets zodra een deel vol is. Voor een cel: 0,2 per kill, plus 0,9 maal het deel van zijn health dat de speler mist, plus 0,3 voor een kill van binnen 8 m; een heavy laat er altijd een achter, en een granaat. Voor een blik: 0,3 plus 0,8 maal hoe ver de reserve van het wapen in de hand is gezakt. Wie gewond en zonder kogels drie grunts van dichtbij neerhaalt, vindt drie cellen en drie blikken.
- **Oprapen** is eroverheen lopen (`scripts/pickup.gd`); de laatste meters komt het naar je toe. Wat je niet kunt gebruiken blijft liggen. Na 40 seconden is het weg, de laatste 6 knippert het. Elk gloeit zwak in zijn eigen kleur, genoeg om het in een donkere hal te vinden, en linksonder staat even wat je kreeg. Na het eerste spelen waren ze te fel: het licht eromheen is van 0,7 naar 0,22 gegaan en reikt 1,5 m in plaats van 2,4, het venster van de cel gloeit op een derde, en ze draaien half zo snel.
- **Zonder kogels sla je.** Is het magazijn leeg en de reserve op, dan zwaait de trekker het wapen zelf: een halve seconde, de klap valt na een derde daarvan op wat binnen 2,1 m voor je staat, een vijand vóór een muur, en doet 60 schade. Een rusher ligt in één klap, een grunt in twee; de plaat van een grunt houdt ook een klap tegen. Met het pistool gebeurt het nooit, want dat raakt niet op.
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

**Wat de selftest ervan controleert** (138 controles, was 103; de test van de personages 26):

- dat er vanaf waar de speler staat dekking is om achter te staan en om achter te bukken, en dat een collider erbij ver van het gevecht of dezelfde colliders in een andere volgorde daar niets aan veranderen (sinds 10 oktober, zie "Dekking die aan het laatste cijfer hing");
- dat een grunt naar dekking rent en daar van hoofd tot borst niet te zien is, eruit komt om te schieten als het zijn beurt is en teruggaat;
- dat van vijf grunts er nooit meer dan het toegestane aantal tegelijk aanvalt, dat ze wel aanvallen, en dat er één omtrekt en niet meer;
- dat een grunt wegrent van een granaat aan zijn voeten en dat overleeft, en uit een brand loopt;
- de plaat: het eerste schot op een grunt die niets weet komt aan, daarna houdt de plaat van voren tegen, niet op hoofd, benen of rug en niet bij een explosie; een tegengehouden schot geeft geen hitmarker; genoeg schoten slaan de plaat eraf;
- het pack: van voren alleen schade, van achteren meer schade en brand, en dan de klap die de heavy en de grunt ernaast meeneemt;
- dat health tot 35 terugkomt en niet verder, dat het pistool niet opraakt, dat kills cellen en blikken achterlaten voor wie ze nodig heeft, dat oprapen werkt en een cel blijft liggen bij wie niets mankeert, en wat een checkpoint aanvult;
- dat de moeilijkheid de tabel volgt en dat een run wordt gemeten en samengevat.

Een deel van de test dat op een scriptfout halverwege ophoudt, telde tot nu toe als geslaagd: wat niet meer werd nagekeken, faalde ook niet. De test houdt nu bij welke delen hun einde hebben gehaald en faalt voor elk dat ontbreekt.

**Wat het kost**

- Het opzoeken van de dekking: 44 ms voor de fabriek, één keer, terwijl het beeld uit zwart opkomt (dat het één keer is en dan gebeurt, klopt pas sinds 10 oktober, zie verderop). Het navmesh van een level is vooral het terrein eromheen (24 duizend plekken); er wordt alleen in de zones gekeken (1569 plekken).
- Een keer dekking zoeken: 0,3 tot 0,4 ms, hooguit 1 ms. Vijf grunts in gevecht doen dat samen 10 keer in 12 seconden.
- Een heel gevecht: gemeten op 10 oktober 2026 op 1440p met FSR 2 op 67%, vanaf de oostkant van de hal, met alle zestien robots van de fabriek tegelijk aan en op de speler af (`--awake`) tegen dezelfde zestien roerloos op hun post (`--posted`), twee keer om en om terwijl de laptop zwaar in gebruik was (load 5 tot 6): 71,6 en 74,2 fps roerloos, 70,1 en 67,3 fps in gevecht. Dat is 2 tot 7 fps voor zestien robots; een zone heeft er hooguit zes. De 1% low liep in die runs uiteen van 46 tot 67 fps, in beide soorten; daar is niets uit af te lezen.
- De grunt is met zijn plaat 9,4 duizend driehoeken in 17 onderdelen, de heavy met zijn pack 8,7 duizend in 19. De cel en het blik zijn 1,1 en 1,5 duizend, met elk een licht zonder schaduw.

**Onderweg gevonden**

- Het navmesh zweeft tot een halve meter boven de vloer. De dekkingsplekken lagen daardoor te hoog en een "lage" dekking werd op heuphoogte gemeten. Elke plek wordt nu met een straal op de vloer gezet.
- Een schot dat de plaat tegenhoudt kost de robot geen health, en het spel zag aan zijn health dat er op hem geschoten was. Een zone begon dus niet als je op een plaat schoot. Een vijand meldt nu zelf dat hij geraakt is (signaal `disturbed`), wat ook het open punt uit de route oplost dat het spel te veel van een robot las.
- De test van de personages ging nog uit van waves en faalde op de samengevoegde branch op drie punten. Hij speelt nu het eerste gevecht van de route.

**Dekking die aan het laatste cijfer hing (10 oktober 2026)**

Of de grunts dekking vonden, hing af van iets dat met elke wijziging aan de colliders van een level verschoof. Met één vuilniszak erbij in het ketelhuis, ruim dertig meter en twee zones van het gevecht in de hal, vochten van de vijf grunts in de test er nog twee vanuit dekking in plaats van vijf, en zochten ze 56 tot 59 keer dekking in 12 seconden in plaats van 8 tot 12 keer. Dezelfde colliders in een andere volgorde deden hetzelfde, en de bestaande vuilniszak weghalen ook. Aan het navmesh lag het niet: dat was met de zak erbij dezelfde 612 polygonen.

De oorzaak heeft twee schakels:

- **Waar het verschil vandaan komt.** Alle colliders van een level zijn vormen van één body (294 in de fabriek), en Jolt bewaart elke vorm ten opzichte van het zwaartepunt van allemaal samen, in getallen van 32 bit. Een vorm erbij verschuift dat punt en een andere volgorde rondt de som anders af; daarna komt elke straal een haar anders terug. Dat is af te lezen aan `center_of_mass_local` van de body: een volgorde die dat punt tot op het laatste cijfer gelijk liet, liet ook elke straal gelijk. Met de zak verschoof het zwaartepunt 0,27 mm en de treffers tot 0,000005 m; met een doos van 60 m op een kilometer afstand werd dat 0,0001 tot 0,0003 m. De vloer van de hal lag zo op +0,0000001 m of op −0,0000001 m.
- **Wat eraan hing.** Wie staand dekking neemt schiet van een stap opzij, en `_suits()` keurde die stap goed als het navmesh niet verder dan 0,45 m van die plek lag. Die afstand werd schuin gemeten, van de plek op de vloer naar het navmesh erboven, en het navmesh zweeft in de hal precies 0,45 m boven de vloer. Bij een vloer op +0,0000001 was het 0,4499999 en goed, bij −0,0000001 was het 0,4500001 en afgekeurd: voor alle plekken in de hal tegelijk. Tegen zes standpunten in de hal voldeed 127 keer een plek om achter te staan; met de zak 0 keer. De plekken zelf waren toen op 0,000005 m dezelfde 361, met dezelfde richtingen. Het vermoeden dat de survey andere plekken opleverde klopte voor de zak dus niet; de survey had wel dezelfde kwaal, zie verderop.

Dat die twee getallen samenvielen is geen toeval van dit ene level. Het navmesh ligt op lagen van 0,25 m, geteld vanaf het laagste punt van alle colliders, en komt een kwart tot een halve meter boven een vloer uit. In de fabriek en in het depot ligt dat punt op −1,05 m, wat boven de begane grond 0,45 m geeft. Nagemeten met een collider buiten het level waarvan de onderkant 10 cm dieper ligt dan de rest: het navmesh zweeft dan 0,35 m boven de hal en de oude regel had 28 cm speling. Op de tussenvloer zweeft het 0,50 m, net als op 202 plekken in het depot; daar kon de oude regel nooit slagen. De 0,45 m was kennelijk als speling over de vloer bedoeld, uit de tijd dat de plekken nog op het navmesh lagen (zie "Onderweg gevonden").

De survey had dezelfde kwaal in het klein. De plekken liggen op hele meters en een level is op hele en halve meters gebouwd: de 164 dozen die recht staan hebben 44 vlakken in x en 91 in z precies op een hele meter. Een straal vanaf zo'n plek loopt dan precies langs een vlak en raakt een hoek, eindigt precies op de muur die 1,6 m verderop begint, en midden in een gang is het naar links even ver als naar rechts. Wat zo'n straal oplevert beslist het laatste cijfer. Met alleen de regel hierboven gerepareerd verdwenen over twaalf verstoringen (dozen ver weg, de vormen gehusseld) samen 80 plekken, kwamen er 23 bij en stond er bij 52 iets anders omheen.

Wat er veranderd is, alles in `scripts/squad.gd`:

- Hoe ver een punt van het navmesh van een punt op de vloer ligt, wordt over de vloer gemeten. Tot 0,6 m hoger of lager is het dezelfde vloer (`HOVER`).
- De survey kijkt van een haar naast elke plek en nooit vanaf de plek zelf (`ASIDE`: 5,6 en 11,3 mm opzij, 3,8 mm hoger). Dat geldt voor de stralen om de plek heen, de straal naar de vloer, de vraag aan het navmesh waar de plek naartoe schuift en het vakje waarin twee plekken als dezelfde tellen. Geen straal loopt zo nog langs een vlak of door een hoek van iets dat op het raster staat.
- Twee afstanden die minder dan 1,5 mm verschillen zijn dezelfde afstand (`HAIR`). Midden tussen twee muren wint de eerste richting, wat het laatste cijfer ook zegt.

Wat het oplevert, gemeten door in het draaiende spel colliders toe te voegen en te husselen en de survey over te doen:

| | Was | Nu |
|---|---|---|
| Plekken in de fabriek | 361 | 353 |
| Keer dat een plek voldoet om achter te staan, tegen zes standpunten in de hal | 127, of 0 | 141 |
| Om achter te bukken | 33 | 32 |
| Verschil na een verstoring in de fabriek: zes dozen, van een vuilniszak dichtbij tot 60 m op een kilometer, en veertig keer 50 vormen achteraan gezet | tot 9 plekken weg en 8 met iets anders eromheen | geen plek, geen richting, geen oordeel over een plek |
| Hetzelfde in het depot (576 plekken, zes dozen en dertig keer husselen) | niet gemeten | geen |

Er voldoen nu meer plekken om achter te staan dan in het gunstige geval van vroeger, omdat de stap opzij echt tot 0,45 m naast het navmesh mag uitkomen. De acht plekken minder bestonden bij de gratie van een straal die een hoek schampte. De survey zelf is iets duurder geworden: 31 tot 33 ms tegen 29 tot 32 ms in de fabriek en 47 tot 52 ms tegen 43 tot 44 ms in het depot (mediaan van negen, vier keer om en om gemeten).

`tools/selftest.sh --fights` per variant van het level, voor de oude code één keer gedraaid en voor de nieuwe twee of drie keer:

| Level | Was | Nu |
|---|---|---|
| Zoals het is | 5 van de 5 vanuit dekking, 8 tot 12 keer zoeken | 5 van 5, 12 tot 15 keer |
| Vuilniszak erbij in het ketelhuis | 2 van 5, 56 tot 59 keer | 5 van 5, 10 tot 13 keer |
| Dezelfde colliders in omgekeerde volgorde | 2 van 5, 53 keer | 5 van 5 en één keer 4 van 5, 11 tot 14 keer |
| De bestaande vuilniszak weg | 2 van 5, 58 keer | 5 van 5, 11 keer |
| Een doos van 10 m op 140 m van de hal erbij | 5 van 5, 10 keer | 5 van 5, 10 tot 11 keer |
| Een collider 10 cm dieper dan de rest (het navmesh zweeft dan 0,35 m) | 5 van 5, 11 keer | 5 van 5, 9 tot 11 keer |

Die ene keer had één grunt op het moment van tellen geen dekking; waardoor heb ik niet nagegaan. De test vraagt er drie.

De selftest kijkt er nu zelf naar, vóór het eerste gevecht: of er vanaf waar de speler staat dekking is om achter te staan en om achter te bukken (18 en 3 plekken), en of een doos van 30 m op 300 m afstand of dezelfde vormen in een andere volgorde daar iets aan veranderen. Met de oude `squad.gd` falen daarvan twee controles in het level zoals het is en alle drie met de vuilniszak erbij. De hele selftest telt nu 141 controles en slaagt, net als de test van de personages (26) en die van samen spelen (58).

Onderweg gevonden:

- De survey bij het laden kwam te vroeg. Een navmesh dat net gebakken is, staat pas een paar frames later op de kaart waar de vragen aan gesteld worden; `prepare()` keek op frame 3, de kaart had het op frame 6. Dat kostte 28 ms voor 369 plekken waarvan er geen tegen zijn dekking was aangeschoven, en de echte survey (44 ms) kwam bij de eerste vraag om dekking, midden in het eerste gevecht. De survey wacht nu tot het navmesh op de kaart staat en gebeurt één keer, terwijl het beeld opkomt.
- In het depot stond één plek nu eens links en dan weer rechts van een pilaar die precies op zijn rasterlijn staat, 11 cm uit elkaar. Daarom gaat ook de vraag aan het navmesh een haar opzij.

Nog open hiervan:

- De haar opzij maakt toeval onwaarschijnlijk, niet onmogelijk: iets dat zelf 5,6 mm naast een rasterlijn begint, ligt weer op de rand. De controle in de selftest is er om dat te merken.
- `_suits()` kijkt vanaf de ogen van de speler. Die staan in het spel nooit precies op het raster, in de test wel. In geen van de verstoringen hierboven gaf dat een ander oordeel.
- Op twee plekken wordt nog schuin gemeten tussen de vloer en het navmesh: of een pad bij een plek uitkomt, met 1,0 m als grens. Met een navmesh dat hooguit een halve meter zweeft is daar een halve meter speling; dat is zo gelaten.
- Het is niet gespeeld. Staand dekking nemen kan nu op meer plekken dan in het gunstige geval van vroeger. Op de tussenvloer scheelt het weinig, want daar staat weinig hoogs: tegen drie standpunten daarboven voldoet nu één plek om achter te staan, eerst geen.

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
- Een klap met een leeg wapen is bij de anderen niet te zien of te horen; de schade komt wel aan.
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

## Meerdere agents tegelijk

Op 11 oktober 2026 gevraagd: de repo klaarmaken voor agents die tegelijk bouwen, elk in een eigen worktree. Gebouwd op de branch `klaarzetten`. Terwijl dit gebouwd werd, begonnen er drie (`houding`, `wapens`, `zestig`); hun branches zijn van vóór dit werk.

**Wat er nu is**

- **`CLAUDE.md`**, dat elke sessie te lezen krijgt: de werkafspraken, en wat dit plan leert over worktrees, de GPU, meten en bakken.
- **Het GPU-slot** (`tools/gpu_slot.sh`). Wat tekent, neemt eerst het slot en wacht zolang een ander het heeft. `tools/godot.sh` doet dat voor elke run, met of zonder venster, dus ook voor `tools/benchmark.sh`, `tools/shots.sh`, `tools/zone_sheet.py` en `tools/level_cost.sh`. Het slot is een slot (`lockf`) op één bestand dat elke checkout deelt, `~/Library/Application Support/Godot/gpu-slot`. Het blijft dicht zolang het proces leeft dat het nam, met alles wat dat startte, en gaat open zodra die weg zijn, hoe ze ook eindigden: er blijft niets achter om op te ruimen. In het bestand staat wie het heeft, en wie wacht zegt dat op stderr. Na 30 minuten wachten (`GPU_SLOT_WAIT`) stopt een run met status 75.
- **Een bake houdt het slot zolang hij duurt.** `tools/bake_lightmaps.py` neemt het zodra er iets te bakken is, vóór het naar andere Godots kijkt, en geeft het pas terug als de editor klaar is; de run van `tools/godot.sh` daarbinnen neemt het niet nog eens (`GPU_SLOT_HELD`). `--list` en `--mark` raken het niet. Op dezelfde manier houdt een reeks het slot van de eerste tot de laatste run: `tools/gpu_slot.sh sh -c '...'`.
- **Eigen testbestanden per checkout.** `SelfTest.own_file()` geeft een test een bestand in `user://selftest/<map>-<getal>/`, met de map van de checkout en een getal uit het hele pad. Daar staan nu de save van een testrun (`save.cfg`) en het logboek van de sandboxtest (`sandbox.jsonl`). De test van samen spelen telt op dezelfde manier door naar een eigen poort, 24599 tot 24998.
- **De dekkingsfix** uit de worktree `brave-bose-91ce03`, zie "Dekking die aan het laatste cijfer hing". Op de trunk botste alleen `scripts/selftest.gd`; beide blokken functies staan erin. Met de kisten en lampen uit het lichaam van het level komen dezelfde getallen terug als toen: 353 plekken, 18 om achter te staan en 3 om achter te bukken.
- **De sandbox** uit de worktree `sandbox`, zie hieronder. Op de trunk botste alleen `take_damage()` in `scripts/player.gd`: de parameter heet `direction`, die het beeld gebruikt, en de test is `if dead or invulnerable:`.

**De sandbox**

Eén gevecht in één zone van een level, zo vaak als je wilt, met elke keer iets anders eraan: om te beslissen hoe iets moet spelen. Nergens beschreven tot nu toe; dit is wat de code doet.

- "Sandbox" op het titelscherm, of `--sandbox=<experiment>` (met `:2` erachter voor de derde variant). `assets/sandbox.json` noemt de experimenten: een level, de zone die de arena is, eventueel wie er op de posten staat, en de varianten. Een variant is een thema zoals `scripts/enemy_themes.gd` dat leest; wat je vergelijkt moet dus een `@export` van `scripts/enemy.gd` zijn. Daarvoor zijn de drie getallen van de paniek dat geworden (`panic_health`, `panic_radius`, `panic_pace`).
- Er zijn er drie: hoe ver paniek zich verspreidt (laadperron van de fabriek, 8 m, de hele ruimte of niet), hoe hard ze dan rennen (de hal, vijf vijanden, 1,35, 1 of 2 keer hun loopsnelheid) en tegen wie je vecht bij de poort van het depot (robots, soldaten, zombies, clowns, paniekclowns).
- T begint de ronde opnieuw, Q en E met de vorige of volgende variant, F en X noteren of de ronde goed was. Het pauzemenu heeft de rest: niets doet pijn, munitie raakt niet op, slow motion, vijanden staan stil, een vijand erbij waar je kijkt, en het level opnieuw laden, wat terugbrengt wat ontplofte of brak.
- Wat het spel had opgeslagen staat zolang opzij en is daarna terug. Elke ronde laat één regel achter in `user://sandbox.jsonl`: variant, afloop, seconden, schade, schoten, treffers en het oordeel.
- `tools/test_sandbox.sh`, 30 controles, speelt het eerste experiment zonder een schot te lossen en opent het laatste. Het middelste opent hij niet; zijn zone (`hall`) bestaat.

**Gemeten**

Twee checkouts naast elkaar, de tweede een paar seconden na de eerste gestart, met de code van vóór de eigen testbestanden en erna:

| Test | Ervoor | Erna |
|---|---|---|
| `tools/selftest.sh --routes`, 17 s na elkaar | de ene 183 van 183, de andere 10 fout vanaf "a restart carries on from that checkpoint" | allebei 183 van 183 |
| `tools/nettest.sh`, 5 s na elkaar | de ene 62 van 62, de andere 3 fout: de host kan niet hosten en de gast komt in het spel van de ander | allebei 62 van 62 |
| `tools/test_sandbox.sh`, 3 s na elkaar | de ene 30 van 30, de andere 1 fout | allebei 30 van 30 |

Op hetzelfde moment gestart slaagden de twee oude routetests allebei: ze lopen dan gelijk op en schrijven hetzelfde weg. Het ging dus mis zodra twee sessies niet toevallig tegelijk begonnen.

Het slot, door de echte scripts heen met een script van vijf regels op de plaats van Godot (`GODOT=`), dat zegt wanneer het begint en eindigt:

- Een run uit de ene checkout en een seconde later een uit de andere: de tweede zegt op wie hij wacht en begint in de seconde dat de eerste eindigt. Elk geeft de eigen afloop door (3 en 0).
- Een run met venster (`GODOT_WINDOW=1`) neemt het slot ook. `tools/bake_lightmaps.sh --list` wacht nergens op.
- Een bake in de ene checkout, anderhalve seconde later een meting in de andere: de meting begint als de bake klaar is.
- Een bake die begint terwijl een meting loopt, wacht daarop en kijkt dan pas naar andere Godots. Hij weigerde toen, terecht: de editor stond open en een andere sessie mat zonder slot.
- Wie het slot heeft en gestopt wordt terwijl iets dat hij startte nog leeft, houdt het tot dat ook weg is. Genest (`tools/gpu_slot.sh tools/gpu_slot.sh ...`) start meteen.

De hele selftest slaagt (315 controles), net als `--fights` (5 van 5 vanuit dekking), de test van samen spelen (62), van de personages (36) en van de sandbox (30).

**Onderweg gevonden**

- **De importcache van de hoofdcheckout liep achter.** De centrale is erin gevoegd zonder haar geïmporteerde bestanden: de elf lightmaps en vijf opschriften, 32 bestanden in `.godot/imported/`. Elke worktree die daarna met `cp -cR .godot` begon, laadde de centrale met foutmeldingen en zonder lightmaps; de selftest slaagt dan toch, want die kijkt daar niet naar. Zelf importeren (`--import`) vult aan wat ontbreekt en niets anders, maar was na tien minuten op vier cores bij de vijfde lightmap van elf. Uit de worktree `centrale` klonen kost een seconde. In `CLAUDE.md` staat nu dat wie lightmaps of texturen in de hoofdcheckout voegt, die bestanden meekloont.

**Git LFS bij GitHub**

- Een account op GitHub Free of Pro heeft 10 GiB opslag en 10 GiB download per maand (docs.github.com, "Git Large File Storage billing", gelezen op 11 oktober 2026). Daarboven wordt zonder betaalmiddel niets meer geaccepteerd.
- In de geschiedenis staan 97 LFS-objecten, samen 542 MB; allemaal op commits die gepusht zijn. De stand van nu is daarvan 525 MB in 88 bestanden: het fabrieksterrein 229 MB, de centrale 138, de fabriek 68, het depot 49 en de vleugel 41. Dat is ongeveer een twintigste van de 10 GiB, als dit het enige project met LFS op het account is.
- Elke lightmap die verandert telt bij een push opnieuw voor zijn hele grootte, en wat eenmaal gepusht is blijft meetellen. Alles opnieuw bakken en pushen kost dus een halve GiB per keer: daar is ruimte voor een kleine twintig keer.
- **Wat GitHub zelf als verbruik telt, heb ik niet kunnen lezen.** Dat vraagt het recht `user` op de inlog van `gh`, en dat heeft hij niet. Los daarvan is de gewone geschiedenis bij GitHub 1,0 GB (`size` van de repo), vooral lightmaps van vóór LFS: van de 400 grootste bestanden in de geschiedenis is 790 MB een `.exr`.

**Opruimen: niets gedaan, dat wacht op Michiels woord**

- Volledig in de trunk en zonder eigen werk: de worktrees en branches `beeld`, `bouwdoos`, `centrale` en `claude/admiring-bassi-66e193`, en op GitHub `origin/bouwdoos`. In `admiring-bassi` staat één bestand klaargezet en niet gecommit, een leeg `benchmark/.gdignore`; de trunk heeft het al.
- `claude/brave-bose-91ce03` en `sandbox`: hun commits zaten al in de trunk, hun ongecommitte werk nu ook. Ze kunnen weg zodra `klaarzetten` in de trunk zit.
- `origin/claude/relaxed-wozniak-wpi9ky` zit er niet in: twee commits uit fase 1, een eerdere opzet van de gunfeel met een eigen rooktest, afgetakt bij het bouwplan.
- `main` staat 141 commits achter de trunk en heeft niets eigens: doorschuiven kan zonder merge. Het is de standaardbranch op GitHub, dus wie de repo kloont krijgt nu het spel van fase 1.
- In `user://` blijven `selftest_save.cfg` en `sandbox_test.jsonl` liggen. Branches van vóór dit werk gebruiken ze nog.

**Nog open**

- **Eén echte run is door het slot gegaan, een bake niet.** Tijdens het bouwen was de GPU negen minuten lang geen moment vrij: de drie andere sessies maten aan één stuk, twee keer met twee tegelijk. Michiel draaide daarna zelf `tools/benchmark.sh --quick --at="-23,2.2,9,0,-5"` vanuit de worktree: het beeld staat er, het slot noemde de run en was daarna weer vrij. Dat die run op een ander wachtte is op de GPU niet gezien, alleen met de nagemaakte Godot. Bakken is aan de agent van "Kit-ruimtes".
- **Het slot ziet alleen wie het neemt.** De editor, het spel dat Michiel daaruit speelt en een branch van vóór dit werk tekenen erbuiten. `ps` blijft dus nodig, en `houding`, `wapens` en `zestig` wachten pas op elkaar als ze de trunk binnenhalen.
- Een Godot die bij het afsluiten blijft hangen, zoals op 10 oktober, houdt het slot vermoedelijk vast zolang hij in de proceslijst staat. Dan wacht alles, wat toen ook het beste was; wie wacht leest wie het heeft. Dat is niet uitgeprobeerd.
- De sandbox en de dekkingsfix zijn niet gespeeld.

## Effecten: rook, ramen, plassen, vuur en de uitgang

Op 12 oktober 2026 gebouwd op de branch `effecten`, door vijf agents elk in een eigen worktree en daarna samengevoegd en nagekeken. De levels zijn er niet voor herbouwd of gebakken: alles komt erbij als een level laadt, via `scripts/breakables.gd`. De regels onder "Nog open" van "Moderne shooter-eisen" over vuur dat niet overslaat, ramen en de plas zijn hiermee achterhaald, net als het slot van "De rook van een explosie wordt niet per pixel belicht".

**Wat er staat**

- **Rook als volume.** De wolk van een explosie en de rook van een vuur zijn nog steeds onbelicht (`shaders/smoke.gdshader`, geen lampen of schaduwen per pixel, dezelfde twee ruisopzoekingen), maar krijgen per salvo één hoofdlicht mee: `Fx.smoke_light()` kiest uit de zon en de lampen van het level de sterkste die de wolk kan zien, met een straal elk. De shader belicht elke bol als bol, maakt de kant van de wolk die van het licht af ligt donker en laat dunne randen licht door. Het roet was 0,8% helder en is nu houtskoolgrijs.
- **Ramen breken.** Een ruit houdt geen kogel tegen: het schot gaat erdoor en de ruit breekt. Het glas zit op een eigen laag (7) die geen schot, zichtlijn of loper ziet; `Fx.tracer()` kijkt welke ruiten de baan kruist, voor schoten van speler, medespelers en vijanden. Een klap breekt de ruiten die hij kan zien. `scripts/window.gd` maakt per raamopening één lichaam `Window<N>` met een vorm per ruit; wat breekt verdwijnt uit een eigen kopie van de glasmesh en laat tanden van glas langs de roeden achter. Fabriek 189 ruiten, fabrieksterrein 416, depot 3, centrale 314.
- **Een plons.** `Fx` houdt per level bij waar de vloershader water tekent (dezelfde formule, uit het masker van het vloermateriaal) en `Fx.strike()` geeft op water druppels, een pluim en kringen die bij de oever ophouden (`shaders/drops.gdshader`, `shaders/rings.gdshader`) in plaats van stof en scherven.
- **Vuur slaat over.** Brandende brandstof en de vuurbal van een klap verhitten kisten, dozen en stapels pallets (`scripts/tinder.gd`); die vatten vlam, branden met vlammen die om hun vorm passen, zijn zelf een brandplek voor wie ernaast staat en steken hun buren binnen 1,2 m aan. Een kist breekt na zes seconden in zwarte planken, een stapel pallets brandt uit en houdt roet. Hooguit vier vuren tegelijk; een gangpad houdt het tegen.
- **Licht bij de uitgang.** `scripts/daylight.gd` zet buiten elke uitgangsdeur een schijnwerper met schaduw en een zacht licht in de opening, die de deur volgen: in de fabriek langs de zon, op het fabrieksterrein en in de centrale koel hemellicht, in het depot het licht van de lamp achter de deur. Het gordijn van de deur werpt zelf de schaduw, dus de vlek groeit met de opening.

**Gemeten** op 12 oktober 2026, M1 Pro aan een lader van 30 W met de accu op 53%, 1440p met FSR 2 op 67%, om en om met de trunk (a865564), vier rondes, load 2,7 tot 4. De trunk zelf liep tussen rondes tot 6 fps uiteen, dus alleen het gemiddelde verschil zegt iets.

| Standpunt | `--firefight=12` | `--barrage=1` |
|---|---|---|
| Overview | +2,2 fps | -0,3 fps |
| Corridor | +1,2 | +1,1 |
| Platform | +1,4 | +2,0 |
| Hall | +1,1 | -0,4 |
| Boiler | +1,6 | +0,1 |

Een eerste reeks van drie rondes, begonnen onder load 8, gaf voor het vuurgevecht 1,6 tot 4,9 fps minder en voor de explosies +3,2 tot -3,8; die is door de tweede niet bevestigd. Niet gemeten: 3456×2160 met MetalFX, en een echte klap die ramen breekt en vuur sticht (de benchmark roept alleen `Fx.explosion` aan).

Eerste gebruik, geteld op de GPU in de fabriek: plons, explosie, kist die vlam vat en doorbrandt, pallets en gebroken glas maken tijdens het tekenen geen enkele pipeline. De drukgolf, de tracer en de mondingsvlam gaan nu ook mee in de repetitie; de drukgolf kostte er op de trunk één. De uitgang die opengaat kost er twee, op de trunk ook.

**Getest.** `tools/test_effects.sh` (239 controles, een onderdeel per effect in `tools/effects/`, speelt in een eigen thuismap), naast de selftest en de test van samen spelen.

**Buiten de bestanden van de opdracht geraakt**, in een eigen commit: `VERSION` in `scripts/net.gd` is 7, want de lijst van wat kapot kan telt nu ramen en pallets mee.

**Niet kunnen beoordelen.** Niets is in beweging gezien of gespeeld: alle beelden zijn stilstaand. Geluid: een ruit klinkt als `lamp_break`, een deurruitje als `bulb_break`, een schot in water als `impact_soft`; vuur heeft geen geluid. De getallen van het vuur zijn een eerste gok.

**Nog open**

- Van een lading hagel breekt alleen elke derde korrel glas: `weapons.gd` en `puppet.gd` tekenen maar één tracer op drie. Een aanroep `Fx.shot(muzzle, end)` voor de andere korrels lost het op.
- Een granaat vliegt door glas zonder het te breken, een klap met het wapen breekt het niet, en het blad van een deur houdt een schot door zijn gebroken ruitje tegen.
- Het schot van een medespeler wordt op de host vanaf de loop van zijn pop gevolgd; vlak bij een roede kan de ruit ernaast breken.
- Wie later binnenkomt ziet niet wat er op dat moment brandt, en geen roet van wat al was afgebrand.
- De bundel bij de uitgang staat 18 m buiten de deur (verder weg streept de schaduw), dus de stralen lopen een graad of vijf uiteen. Robots en het wapen in beeld vangen het koele licht op het fabrieksterrein en in de centrale niet.
- Alleen schoten spatten op; een granaat of een explosie boven een plas niet.
- De nieuwe scripts en shaders zonder `.uid`-bestand krijgen er een zodra de editor het project opent.

## Wedstrijden: teams, bots en een buit (plan)

Op 12 oktober 2026 gevraagd: een plan voor de klassieke spelsoorten, team deathmatch, ieder voor zich en capture the flag, zes tegen zes, met bots in het eigen team en in dat van de tegenstander zoals bij Call of Duty; een vlag die ook een voetbal of een grote banaan kan zijn; en spawnplekken die kloppen, ook op levels die er nog niet zijn. **Dit is een plan: er is niets van gebouwd.** Michiel heeft het dezelfde dag akkoord bevonden en in de trunk laten zetten. Wel is de code gelezen waar het op moet aansluiten, en is het idee voor de spawnplekken zonder GPU uitgeprobeerd op de vier levels die er staan: zie "Gemeten voor dit plan" en het blad `assets/arenas/sheets/spawnplekken.jpg`. Geschreven op de branch `wedstrijd`.

**Waar het op verder bouwt, en wat ontbreekt**

- **Samen spelen staat er.** Eén machine host en beslist over de wereld, elke machine over haar eigen speler, en alleen spelen is hetzelfde spel met niemand erbij (`scripts/net.gd`). Een medespeler is al een soldaat met het wapen van de speler in zijn handen, die loopt, richt, vuurt en valt (`scripts/puppet.gd`).
- **De vijanden hebben een brein** dat dekking zoekt, voor een granaat wegrent en om brand heen loopt, en `scripts/squad.gd` weet waar in een level dekking is. De sandbox laat zien hoe iets anders dan de route een level overneemt.
- **De wapens kloppen al.** De karabijn doodt iemand met 100 health in vier treffers, 0,29 s; de andere vier zitten tussen één schot en 0,35 s. Zo snel hoort het in dit soort spel te gaan: aan de wapens hoeft niets te veranderen.
- **Wat ontbreekt:** spelers kunnen elkaar niet raken (een schot slaat ze over), er zijn geen teams, geen stand en geen einde, wie doodgaat staat weer bij het checkpoint, een vijand kent alleen "de speler" en schiet om de beurt een aangekondigd salvo van drie keer 7 schade, er kunnen acht spelers meedoen, en geen van de levels is als arena gebouwd.

**Het ontwerp**

- **Een wedstrijd is een tweede manier om een level te spelen**, naast de route. Een autoload `Match` (`scripts/match.gd`) houdt bij wat er gespeeld wordt, wie meedoet, de stand en de klok, en neemt het level over zoals de sandbox dat doet: de route staat uit, er staan geen robots en de uitgang blijft dicht. Wat beslist wordt, beslist de host, en wat te zien is loopt via `Net.show`, zoals nu. Alleen tegen bots is dus dezelfde code als met vrienden erbij.
- **Iedereen die meedoet is een deelnemer**: een mens of een bot, met een nummer, een naam, een team en een stand. **Een bot is een pop zoals die van een medespeler**, alleen komt wat hij doet van een brein op de host in plaats van van een andere machine. Raken, doodgaan, terugkomen en tellen gaan voor mens en bot door dezelfde code, en op de machine van een gast is een bot niet van een speler te onderscheiden. Mensen houden het nummer van hun machine, bots krijgen negatieve nummers.
- **Een spelsoort is een klein bestand met regels** (`scripts/modes/`): wie bij wie hoort, wat een punt oplevert, waar je terugkomt, wat de bots willen en wanneer het voorbij is. Een vierde spelsoort is een bestand erbij.
- **Een arena is een level, of een stuk ervan, met wat een wedstrijd ervan moet weten**: waar de teams beginnen, waar de buit staat en waar je mag terugkomen. Dat laatste wordt niet met de hand gezet maar uitgerekend uit het navmesh, en per keer gekozen naar waar iedereen op dat moment staat.
- **De buit is een regel in een tabel**: een model, hoe je het draagt en waar het op staat. Vlag, voetbal en banaan zijn drie regels.

**De spelsoorten**

| | Team deathmatch | Ieder voor zich | Capture the flag |
|---|---|---|---|
| Wie | twee teams van 1 tot 6 | 2 tot 12 | twee teams van 2 tot 6 |
| Een punt | een kill | een kill | de buit van de ander op je eigen standaard zetten, terwijl je eigen buit daar staat |
| Gewonnen bij | 50 | 25 | 3 |
| Of na | 10 minuten: wie voor staat | 10 minuten | 12 minuten |
| Terug na | 3 s | 2 s | 5 s |
| Waar je terugkomt | bij je team | ver van iedereen | op de grond van je eigen basis |

- **Health komt in een wedstrijd helemaal terug**, na vijf seconden zonder treffer; er vallen geen cellen. Wie terugkomt heeft waarmee een level begint, en een kill laat voor de speler een blik munitie liggen. Een bot raakt door zijn magazijn heen, niet door zijn reserve.
- **Je eigen team raak je niet**, je eigen granaat raakt jou wel. Teamgenoten lopen door elkaar heen: niemand staat klem in een deuropening achter een bot.
- **Wie terugkomt is anderhalve seconde onkwetsbaar**, of tot hij zelf schiet.
- **Capture the flag.** De buit pak je door ertegenaan te lopen. Wie hem draagt laat hem vallen als hij sterft; de eigenaars brengen hem terug door hem aan te raken, en na twintig seconden gaat hij vanzelf. De drager is voor zijn eigen team altijd te zien; voor de tegenpartij zolang een van hen hem ziet, en anders elke vijf seconden even.
- Alle getallen staan per spelsoort op één plek (`assets/match.json`), zoals de moeilijkheid in `Settings.RULES`. Het zijn eerste gokken.

**Bots**

- **Instellen zoals bij Call of Duty.** Op het scherm van de wedstrijd kies je de teamgrootte, hoeveel bots er in je eigen team zitten, hoeveel in het andere, en per team hoe goed ze zijn. Zeg je niets, dan vullen bots elk team aan tot de teamgrootte. Een vriend die binnenkomt neemt de plaats van een bot in; gaat hij weg, dan komt de bot terug.
- **Een bot is een speler**: 100 health, de wapens van de speler met hun eigen schade, vuursnelheid, spreiding, magazijn en herlaadtijd, en dezelfde loopsnelheden. Elke bot draagt één hoofdwapen, verdeeld over het team (karabijn, pistoolmitrailleur, shotgun, scherpschuttersgeweer), en het pistool.
- **Wat hij weet, heeft hij gezien of gehoord.** Zien: binnen zijn blikveld, met een vrije lijn, na zijn reactietijd. Horen: een schot zover het draagt (de duinen brengen dat mee voor de vijand die de wacht houdt, `hears`), rennen dichtbij, en vanwaar hij zelf geraakt wordt. Wat één bot weet, weet zijn team een seconde later (`scripts/team_mind.gd`): de laatste plek van elke vijand, en hoe oud dat is. Door muren kijkt niemand.
- **Richten is een veer, geen sprong.** Zijn richtpunt loopt achter het doel aan en komt tot rust; hoe snel en met hoeveel ruis is zijn niveau. Elk schot is een echte straal langs waar zijn loop wijst, met de spreiding van het wapen. Dekking werkt dus, en een misser slaat in naast je hoofd en breekt de ruit erachter.
- **In een gevecht** kiest hij tussen opdringen, standhouden vanuit dekking (de plekken van `Squad`), opzij stappen, en terugtrekken om te herladen of bij te komen: naar zijn health, zijn magazijn en de afstand die bij zijn wapen past. Voor een granaat rent hij weg en om brand loopt hij heen, zoals de vijanden al doen. Om de beurt schieten doet hij niet: dat is er om één speler ruimte te geven tegen vijf.
- **Daarbuiten** volgt hij de spelsoort. Team deathmatch: in paren naar waar het team de vijand het laatst zag, en anders langs de wegen van de arena naar de overkant. Ieder voor zich: van de ene drukke plek naar de andere. Capture the flag: het team verdeelt rollen, en opnieuw bij elk nieuws. Van zes gaan er drie halen, blijven er twee thuis en zwerft er één in het midden; draagt iemand de buit, dan lopen de halers met hem mee; ligt de eigen buit ergens, dan gaat wie het dichtstbij is hem terugbrengen. Wat jij doet telt mee: blijf je thuis, dan gaat er een bot meer halen; ga je halen, dan loopt er een met je mee.
- **Vastlopen wordt gemerkt.** Wie anderhalve seconde niet vooruitkomt zoekt een andere weg, wie het na vijf seconden nog niet lukt een ander doel, en de test telt elke keer.
- **Wat een bot in de eerste versie niet doet:** springen, bukken en zichtbaar herladen (de pop heeft er geen houding voor), en praten.

De niveaus, als eerste gok; ze staan in één tabel (`assets/bots.json`):

| | Recruit | Regular | Hardened | Veteran |
|---|---|---|---|---|
| Van zien tot het eerste schot | 0,9 s | 0,55 s | 0,35 s | 0,22 s |
| Hoe ver hij er bij dat schot naast zit | 3,5° | 2° | 1,2° | 0,6° |
| Tijd waarin zijn richtpunt het doel inhaalt | 0,9 s | 0,6 s | 0,4 s | 0,25 s |
| Blikveld | 90° | 110° | 120° | 140° |
| Dekking nemen en omlopen | zelden | ja | ja | ja, en herladen in dekking |
| Granaten | nee | nee | soms | ja |

**Spawnplekken**

Een goede plek om terug te komen is er een waar niemand je ziet aankomen, waar je team dichtbij is en de vijand niet, vanwaar je binnen een paar tellen weer meedoet, en die niet elke keer dezelfde is. Welke plek dat is hangt af van waar iedereen op dat moment staat. Vaste punten per level kunnen dat niet weten, en ze zouden voor elk nieuw level met de hand gezet moeten worden. Daarom worden de plekken uitgerekend en wordt er per keer gekozen (`scripts/arena.gd`).

- **De plekken komen uit het navmesh.** Als een level geladen is: om de twee meter een plek op alle vloer waar je kunt komen, voor zover er iemand kan staan. Dat zijn er 155 in de fabriek en 592 op het fabrieksterrein, in 3 tot 9 ms. Van elke plek wordt één keer bewaard hoe open hij ligt (welk deel van de andere plekken hem ziet) en in welke richting je er het verst kijkt.
- **Loopafstanden komen uit een net over het navmesh**: een knoop op elke hoek en midden op elke gedeelde rand van zijn polygonen, en binnen een polygoon loop je recht. Dat zit gemiddeld 2 tot 6% naast de route die het navmesh zelf geeft, op zijn slechtst 12%. Het net bouwen kost 2 tot 7 ms; de afstand van een groep mensen naar álle plekken tegelijk 3 tot 11 ms.
- **Wat een plek uitsluit:**
  - een vijand binnen 12 m, of een die er in minder dan 18 m naartoe loopt;
  - een vijand die het hoofd of de borst ziet van wie daar zou staan, met de lijnen waarmee `Squad` dekking keurt;
  - iets dat op ontploffen staat of brandt, binnen zijn bereik;
  - een dood binnen 8 m in de laatste zes seconden;
  - iemand die er staat, of er binnen drie seconden komt te staan.
- **Wat een plek beter maakt:**
  - de dichtstbijzijnde vijand op 30 tot 50 m lopen: niet erbovenop, en niet aan de andere kant van de map;
  - een teamgenoot op 6 tot 20 m lopen die zelf niet onder vuur ligt;
  - dichter bij je eigen mensen dan bij de vijand, in loopafstand;
  - weinig open;
  - niet de plek of de kamer van de vorige keer, en niet waar je net doodging.
  Uit de beste drie wordt geloot. Je staat er met je gezicht naar het eerste stuk van de weg naar je team, of naar je doel, en nooit naar een muur.
- **Team deathmatch: de kanten liggen niet vast.** Bij het begin staat elk team op een rij in zijn basis, gezicht naar buiten. Daarna is jouw kant waar je team staat. Dringt een team het andere terug tot in zijn basis, dan komt dat team niet voor de loop van de aanvaller terug maar elders, en wisselen de kanten zonder dat daar een regel voor is. De plekken van de laatste tien seconden tellen mee, zodat het niet bij elke stap omslaat.
- **Ieder voor zich:** geen team en geen kant. Zo ver mogelijk van iedereen, zo weinig open mogelijk.
- **Capture the flag:** alleen op de grond van je eigen basis: de plekken binnen 25 m lopen van je standaard, niet binnen 6 m ervan. Is daar niets veilig, dan in het achterland, de rest van je eigen helft. Nooit in de helft van de ander.
- **Als er niets veilig is:** eerst telt zicht alleen nog binnen 30 m, dan afstand vanaf 8 m, en anders wordt het de plek die het verst van elke vijand ligt. Zo'n noodspawn wordt geteld; de anderhalve seconde onkwetsbaarheid is ervoor.
- **Kiezen gebeurt terwijl je dood bent.** In de proef kostte één keuze 6,5 tot 39 ms, het meest op het fabrieksterrein. Dat wordt over een paar frames gedaan in de seconden voor je terugkomt, en de gekozen plek en twee reserves worden op het laatste moment nog eens nagekeken.
- **Wat een level erbij kan zeggen**, in zijn plan, naast de route: `arena()` voor het stuk waar gespeeld wordt, `base()`, `flag_stand()`, `spawn_ground()` en `no_spawn()`. De bouwer zet ze onder `Level/Arena`, zoals de route onder `Level/Route`. Zegt een level niets, dan zijn de bases de twee plekken die in loopafstand het verst uit elkaar liggen, staat de buit op de meest beschutte plek met drie meter vrije vloer bij elke basis, en is alles daartussen arena. **Voor de vier bestaande levels hoeft dus niets herbouwd of gebakken te worden.** Wat aan die afleiding niet bevalt, kan per level worden overschreven in `assets/arenas.json`.

**Het blad** `assets/arenas/sheets/spawnplekken.jpg` laat de regels zien op twee levels, elk op één moment van zes tegen zes en één moment van ieder voor zich met twaalf. Op het fabrieksterrein zijn 409 van de 592 plekken veilig als de vijand tot het midden is gekomen, en komt de speler terug in de werkplaats, één deur achter zijn team op het binnenterrein; bij ieder voor zich in het archief, het verst van iedereen. In het depot zijn 42 van de 363 plekken veilig, en bij ieder voor zich 5: het is één open terrein, en de gekozen plek is beide keren het poorthuisje in de zuidoosthoek. Wie daar staat te wachten, weet waar iedereen terugkomt.

**Wat de bestaande levels als arena zijn**

| | Factory | Works | Depot | Powerhouse |
|---|---|---|---|---|
| Vloer waar je kunt komen | 765 m² | 2 698 m² | 1 693 m² | 1 610 m² |
| Plekken om te staan | 155 | 592 | 363 | 362 |
| Van eind tot eind lopen, en sprintend | 71 m, 9 s | 220 m, 27 s | 74 m, 9 s | 186 m, 23 s |
| Hemelsbreed | 64 m | 58 m | 63 m | 58 m |
| Wegen door het midden | één ruimte, 22 m breed | één doorgang, één plek breed | vijf, tussen de containers | één ruimte |
| Langste zichtlijn | 48 m | 50 m | 58 m | 38 m |
| Hoe open: welk deel van de andere plekken een plek ziet (mediaan) | 0,52 | 0,07 | 0,31 | 0,11 |
| Ieder voor zich met twaalf: veilige plekken gemiddeld, en in de slechtste van twintig keer | 5, geen | 160, 101 | 4, geen | 58, 27 |
| Teams van zes, de vijand in zijn eigen helft: veilig in de jouwe | 44% | 94% | 36% | 84% |
| Teams van zes, de vijand overal: veilig in jouw helft, gemiddeld en in de slechtste van twintig | 27%, geen | 50%, 98 plekken | 8%, 1 plek | 37%, 26 plekken |
| Meeste spelers bij ieder voor zich, als er negentien van de twintig keer acht veilige plekken moeten overblijven | 5 | 16 of meer | 7 | 16 of meer |
| Grootste team dat teruggedrongen nog zo terug kan komen | geen | 8 of meer | 3 | 8 of meer |

- **Het fabrieksterrein draagt zes tegen zes**, en de centrale ook, krapper. **De fabriek en het depot zijn te klein en te open voor meer dan drie tegen drie**: in de fabriek ziet een plek de helft van alle andere, het depot is één open terrein. Ook met drie tegen drie blijven daar soms maar een paar veilige plekken over, in de fabriek een enkele keer geen; daar is de onkwetsbaarheid bij terugkomen voor. Het scherm van de wedstrijd biedt per arena niet meer spelers aan dan deze regel toelaat.
- **Geen van de binnenlevels heeft meer dan één weg tussen zijn uiteinden.** Het fabrieksterrein is 220 m lopen bij 58 m hemelsbreed, door één doorgang in het midden: de route is één lijn, zoals hij voor de campagne bedoeld is. Voor team deathmatch en ieder voor zich is dat te spelen. Voor capture the flag is het één gang heen en dezelfde gang terug, 27 seconden sprinten per kant. Met de tabel kunnen de bases daar dichter bij elkaar gezet worden; een goede map wordt het er niet van.

**Het keurmerk voor een arena** (`tools/arena_sheet.py <level>`, zonder GPU): de tabel hierboven voor één level, met een oordeel per regel, en twee kaarten. De eerste zoals het blad: de plekken naar hoe open ze liggen, de bases, de standaards en de wegen ertussen. De tweede na een wedstrijd van alleen bots, versneld nagespeeld: waar gespawnd en waar gestorven is. Uit die wedstrijd komen de cijfers waar het om gaat:

- niemand die terugkomt in het zicht van een vijand, en geen noodspawns;
- minder dan 2% sterft binnen drie seconden na terugkomen zonder zelf geschoten te hebben;
- de helft is binnen 4 tot 10 seconden weer in gevecht;
- over tien wedstrijden wint elke kant er vier tot zes;
- geen bot loopt vast.

Een level dat er nog niet is, wordt zo op de dag dat het gebouwd wordt gekeurd, voor er iemand in gespeeld heeft.

**Wat een arena voor zes tegen zes moet hebben**, voor wie de volgende levels bouwt. De getallen komen uit de tabel hierboven en uit de sprintsnelheid van 8 m/s.

- **Tussen de bases 110 tot 170 m lopen**, 14 tot 21 seconden sprinten; hemelsbreed 60 tot 100 m.
- **Drie wegen tussen de bases**, elk ten minste 2,4 m breed en leeg, de langste hooguit anderhalf keer de kortste, met op twee plekken een dwarsverbinding. Geen doodlopende kamer verder dan één ruimte van een doorgaande weg, behalve in een basis.
- **2 000 tot 4 000 m² vloer** waar je kunt komen, en gesloten genoeg dat een plek doorgaans niet meer dan 15% van de andere ziet. Het fabrieksterrein haalt dat ruim, het depot bij lange na niet.
- **Elke basis:** drie uitgangen, 40 plekken (160 m²) om terug te komen buiten het zicht van het midden en van de andere basis, en de standaard 8 tot 15 m daarvandaan, vanuit het midden niet te zien.
- **Zichtlijnen** tot 60 m, en dan op één of twee plekken.
- **Alles is te lopen.** Bots springen niet: een trap is een helling, een tussenvloer heeft twee opgangen.
- **Een arena mag een stuk van een groter level zijn**, als dat stuk dicht is: muren, dichte deuren of land waar je niet overheen komt. Het duinenlevel dat nu gebouwd wordt is 340 bij 230 m: met twaalf is dat ruim 6 000 m² land de man, tegen 225 m² vloer op het fabrieksterrein, en dan vindt niemand elkaar. Het complex of het kamp daarin kan wel een arena zijn.

**De buit**

- `assets/prizes.json` noemt per buit: het model (`scenes/models/flag.scn`, `football.scn`, `banana.scn`, in code gebouwd zoals de wapens en de cellen: `tools/models/prizes.gd`), waar het op staat (een voet met een mast, een stip op de grond, een kist), hoe een soldaat het draagt (op de rug, onder de arm, over de schouder), wat ervan de kleur van het team krijgt (het doek, de vlakken van de bal, een lint), en de woorden en geluiden erbij.
- `scripts/prize.gd` kent drie toestanden: thuis, gedragen, op de grond. De regels zijn van de spelsoort en niet van de buit: dezelfde bal kan later één bal in het midden zijn die je bij de ander moet binnenbrengen.
- Welke buit er gespeeld wordt kies je op het scherm van de wedstrijd. Een nieuwe buit is een model en een regel in de tabel; de test loopt ze allemaal af: pakken, dragen, laten vallen, terugbrengen, binnenbrengen.
- De eerste versie: wat valt, blijft liggen waar het viel. Een bal die wegrolt is leuker en moet dan op elke machine op dezelfde plek uitkomen; dat komt erna.

**Teams uit elkaar houden**

- **Teamgenoten hebben een blauw teken en hun naam boven het hoofd**, ook door muren heen, flauwer naarmate ze verder weg zijn. Wie dat niet heeft, is van de ander. De naam van een vijand zie je alleen onder je vizier. Blauw tegen oranje, niet rood tegen groen: dat is ook voor wie kleuren slecht onderscheidt uit elkaar te houden.
- **Een tweede uniform.** De vijf soldaten dragen hetzelfde. De hele textuur kleuren (`tint` in een thema) kleurt het gezicht mee. De schilderroute van de personages weet van elke texel waar op het lijf hij ligt (`tools/characters/looks.py`, waarmee zombies en clowns geschminkt zijn): een look erbij schildert de kleding van het tweede team anders en haalt de vlag van de mouw.
- **Een team mag ook een andere bezetting zijn**: soldaten tegen clowns, of tegen zombies met geweren. De bezettingen staan er al; het is een keuze op het scherm van de wedstrijd.

**Scherm, menu en geluid**

- **"Multiplayer" op het titelscherm** opent het scherm van de wedstrijd: spelsoort, arena, teamgrootte, bots bij jou en bij de ander met hun niveau, de stand waarbij gewonnen is, de tijd, de buit, en een schakelaar om anderen op jouw adres te laten meedoen. Wat je kiest wordt onthouden. Meedoen met andermans wedstrijd blijft "Join" onder "Play together". Vanaf de opdrachtregel: `--match=<soort>:<level>:<aantal>[:<buit>]`, met het aantal per team, of bij ieder voor zich in totaal.
- **In beeld** (`scripts/match_hud.gd`, naast de HUD die er is): bovenaan de stand en de klok; waar nu het doel van de route staat, wat er te doen is ("Bring it home"); wie wie neerhaalde; de buit met zijn afstand, thuis, onderweg of op de grond; het scorebord onder Tab; als je dood bent wie het deed, waarmee, en de tellen tot je terugkomt; aan het eind de winnaar, de tabel en opnieuw, een andere arena of stoppen.
- **Geluid.** Signalen voor het begin, de laatste minuut, de buit gepakt, gevallen, terug en binnen (anders voor jouw team dan voor het andere), gewonnen en verloren. Gesynthetiseerd zoals de rest, elk in twee of drie varianten om op het oor te kiezen. Geen stem: daar zijn opnamen of een spraakdienst voor nodig.

**Samen**

- De host laat de bots lopen en zegt twintig keer per seconde waar ze zijn, zoals nu met de robots; hun schoten, treffers en dood gaan met dezelfde berichten als die van een speler.
- Een mens die een mens raakt: de machine van de schutter beslist of het raak was, op het beeld dat zij heeft, en vraagt de host om de schade; de machine van wie geraakt wordt houdt zijn eigen health bij, zoals nu, en meldt zijn dood met wie het deed. Dat neemt elke machine op haar woord: goed onder vrienden, zoals het hele spel.
- De host kiest de spawnplekken, houdt de stand, de klok en de buit bij, en vertelt wie later binnenkomt hoe het ervoor staat. `MAX_PLAYERS` gaat van 8 naar 12 en `VERSION` omhoog.

**Wat het kost**

- **Bekend.** Zestien soldaten tegelijk in gevecht, op de instellingen waarmee gespeeld wordt: het gemiddelde blijft gelijk en de 1% low zakt twee tot drie fps ("Zestig beelden op het volle scherm"). Een lopende pop poseren kost 52 microseconden per frame, voor elf bots 0,6 ms. Dekking opzoeken over een heel level in plaats van alleen de zones van de route: 67 tot 233 ms, één keer bij het laden.
- **Niet bekend.** Elf figuren die nooit stilstaan en overal in het level lopen: elke lamp met schaduw waar er een onderdoor loopt tekent die schaduw opnieuw, en een robot hoort bij geen zone (het open punt uit "Zestig beelden"). Het denken van elf bots op de processor. Twaalf wapens tegelijk in het geluid. En wat er de eerste keer hapert: de nieuwe uiterlijken moeten mee in `Fx.rehearse()`.
- **Stap 1 meet het**, om en om met een leeg level, op 3456×2160 met MetalFX. De maat: de vaste standpunten van de arena blijven op 60. Lukt dat niet, dan volgt een figuur de laag van de zone waarin hij staat, en denkt een bot die niet getekend wordt half zo vaak.

**De stappen**

Stap 1 raakt de bestanden die iedereen raakt en gaat dus eerst, alleen. De sessie die de duinen bouwt had op 12 oktober ongecommit werk in zeven van die bestanden; stap 1 begint als dat in de trunk staat. Daarna kunnen 2a tot en met 2e tegelijk, elk in eigen, nieuwe bestanden.

| Stap | Wat | Wacht op | Wat je ervan bekijkt |
|---|---|---|---|
| 1. Een ruw potje | `Match` en de deelnemers: teams, elkaar raken, wie wie neerhaalde, de stand en de klok. Team deathmatch en ieder voor zich. Bots die naar de dichtstbijzijnde vijand lopen die ze kennen en schieten. Terugkomen op de veilige plek die het verst van de vijand ligt. De stand in beeld, starten vanaf het titelscherm en met `--match=`. De meting van wat twaalf figuren kosten | de duinen in de trunk | spelen: `GODOT_WINDOW=1 tools/godot.sh -- --play --match=tdm:works:6` |
| 2a. Bots | het brein, het team dat kennis deelt, de niveaus (`scripts/bot.gd`, `scripts/team_mind.gd`, `assets/bots.json`) | 1 | spelen: één tegen één in de fabriek tegen elk niveau, `--match=ffa:factory:2 --bots=veteran`, dan zes tegen zes |
| 2b. Arena en spawnplekken | de plekken, het net, het kiezen, per spelsoort; wat een level erbij kan zeggen; het keurmerk (`scripts/arena.gd`, `assets/arenas.json`, een la `tools/kit/arena.gd` in de bouwdoos, `tools/arena_sheet.py`) | 1 | het blad per level, en na een wedstrijd van bots de kaart van waar gespawnd en gestorven is |
| 2c. Het scherm eromheen | het scherm van de wedstrijd, de stand, het scorebord, de tekens boven teamgenoten, dood en einde, de signalen (`scripts/match_hud.gd`, `scripts/match_menu.gd`) | 1 | spelen; de signalen met `tools/hear.py`, twee of drie varianten elk |
| 2d. De buit | vlag, voetbal, banaan en waar ze op staan; dragen op de pop (`tools/models/prizes.gd`, `scripts/prize.gd`, `assets/prizes.json`) | niets voor de modellen, 1 voor het dragen | één blad: elk van de drie op zijn standaard, gedragen van voren, opzij en achter, en op de grond |
| 2e. Twee uniformen | de look voor het tweede team, de vlag van de mouw (`tools/characters/looks.py`, vijf personages erbij) | niets | één blad: de twee teams naast elkaar op 5, 20 en 40 m, in het licht van de hal en in een donkere hoek |
| 3. Capture the flag | de regels, de rollen van de bots, de buit in beeld en in het geluid (`scripts/modes/ctf.gd`) | 2a, 2b, 2d | spelen: `--match=ctf:works:6:banana` |
| 4. Samen | alles over de lijn, later binnenkomen, een bot die plaatsmaakt; `tools/nettest.sh` speelt een wedstrijd | 2a, 2b, 2c, 3 | de test, en spelen met een vriend |
| 5. De eerste arena voor zes tegen zes | een map naar "Wat een arena voor zes tegen zes moet hebben", gebouwd en gebakken door de agent van "Kit-ruimtes" | 2b, voor het keurmerk | het contactblad, het arenablad, spelen |
| 6. Afstellen | de getallen van de bots en de spelsoorten, naar wat je er onder het spelen van zegt | wat er dan staat | |

Wat stap 1 aan de gedeelde bestanden verandert, zodat de stappen erna ze met rust kunnen laten: `scripts/game.gd` roept `Match` aan zoals het de sandbox aanroept; `scripts/puppet.gd` krijgt een team, een hoofd dat geraakt kan worden en de mogelijkheid door de host bestuurd te worden; `scripts/player.gd` een team; `scripts/weapons.gd` raakt wie de wedstrijd zegt dat te raken is en zegt erbij wie schoot; `scripts/blast.gd` en `scripts/grenade.gd` zeggen wie gooide; `Settings.rules()` geeft in een wedstrijd de regels van de wedstrijd; `scripts/net.gd` twaalf spelers en de opzet van de wedstrijd in wat een gast te horen krijgt; `scripts/menu.gd` één knop; `project.godot` de autoload, twee botslagen voor de teams (9 en 10; 7 is het glas) en een toets voor het scorebord. Een test `tools/test_match.sh` speelt zonder venster een hele wedstrijd van alleen bots, en komt in de tabel van `CLAUDE.md`. Stap 2b voegt zijn functies aan de bouwer toe zonder een level te herbouwen: het eerste level dat ze gebruikt is dat van stap 5.

Wat daarna kan, in geen volgorde: klassen in plaats van alle vijf de wapens; één bal in het midden; een plek om te houden; hurken en zichtbaar herladen voor de pop, wat ook een open punt van "Samen spelen" is; roepen met een stem; bots als teamgenoten op de route.

**Aannames die van Michiel zijn om om te gooien**

Bij zijn akkoord van 12 oktober 2026 heeft hij er niets apart over gezegd: ze gelden tot hij iets anders zegt, en de vijfde staat open.

1. **Wapens.** Iedereen draagt alle vijf, zoals op de route; een bot één hoofdwapen en het pistool. Het andere is klassen zoals bij Call of Duty: één hoofdwapen kiezen voor je begint.
2. **Uiterlijk.** Dezelfde soldaten in twee uniformen, met het blauwe teken boven teamgenoten; een andere bezetting per team als keuze erbij.
3. **Health** komt in een wedstrijd helemaal terug, anders dan op de route.
4. **De bestaande levels doen mee als voorlopige arena**, met de grenzen uit de tabel. Zes tegen zes dus eerst op het fabrieksterrein.
5. **Welke map stap 5 wordt** is niet gekozen: een nieuwe uit de plattegrond met drie wegen, of een stuk van de duinen. Van buitenlevels is niet gemeten hoe open ze liggen: het enige open terrein dat er staat, het depot, valt af, maar dat heeft geen duinen en geen bos.

**Gemeten voor dit plan** op 12 oktober 2026, M1 Pro op de accu, load 3,0 tot 3,6, terwijl een andere sessie testte en mat. Alles zonder GPU, met een proefscript dat via een tijdelijke haak in de selftest in het geladen spel draait; de haak is weer weg. De scripts en hun uitvoer staan in `benchmark/results/wedstrijd/proef/` van de worktree `.claude/worktrees/wedstrijd`, niet in Git.

- **De tabel met de vier levels.** De vloer is het deel van het navmesh waar je vanaf de start kunt komen. "Veilig" is daar: geen vijand binnen 12 m hemelsbreed en geen vijand die hoofd of borst ziet. Per regel 150 keer de vijanden willekeurig over de plekken gezet. De twee uiteinden zijn de plekken die in loopafstand het verst uit elkaar liggen; een helft is wat dichter bij het ene uiteinde ligt dan bij het andere. In de fabriek zijn de helften scheef, 31 tegen 124 plekken, en de percentages van de kleine helft zeggen daar weinig.
- **Het net.** Tegen 76 tot 79 routes van het navmesh zelf per level: gemiddeld 2, 3, 3 en 6% ernaast (fabrieksterrein, fabriek, centrale, depot), op zijn slechtst 4, 6, 6 en 12%. Met alleen de hoeken als knoop, in de fabriek: 5% en 12%, en drie keer zo snel. Met alleen het midden van de randen: 26 tot 38% te lang.
- **Het blad.** Zes vijanden tussen 28 en 55% van de weg vanaf hun uiteinde, vijf teamgenoten tussen 25 en 50% vanaf het hunne, willekeurig gekozen; bij ieder voor zich elf anderen waar dan ook. De uitsluitingen en de punten zijn die van "Spawnplekken", op vier dingen na: voor de eigen kant is de vaste helft genomen, gevaar en recente doden bestonden niet, en er is niet geloot: de ster is de plek met de meeste punten.
- **De tijden** komen elk uit één run, in GDScript; het opzoeken van dekking is de middelste van drie.

**Wat ik niet kon beoordelen**

- **Of het leuk is.** Bots maken of breken dit, en van een bot bestaat nog geen regel. De getallen van de niveaus en de spelsoorten zijn gokken.
- **De spawnregels zijn op stilstaande momenten geprobeerd**, met mensen op willekeurige plekken. In een wedstrijd staan mensen bij elkaar en bij deuren; of de regels dan net zo goed kiezen blijkt uit de wedstrijden van bots in stap 2b.
- **Wat twaalf figuren in beweging kosten** op het volle scherm.
- **Buiten.** De proef zegt iets over kamers en één open terrein, niets over duinen en bos.

**Nog open**

- De wegen door het midden zijn geteld als groepen plekken halverwege; een brede hal en drie gangen naast elkaar tellen daarin allebei als één of als drie naar hoe ze toevallig liggen. Het keurmerk moet wegen tellen die elkaar niet raken.
- Samen spelen is nooit over een echt netwerk gespeeld, en schutter tegen schutter is gevoeliger voor vertraging dan samen tegen robots.
- De soldaten dragen het camouflagepatroon en de vlag van het Amerikaanse leger; stap 2e haalt de vlag weg bij het tweede team, niet bij het eerste.
- Een bot die niet bukt, neemt alleen staand dekking, zoals de personages op de route.

## De duinen: het vijfde level

Op 12 oktober 2026 gevraagd: een volgend level volgens de standaard van nu, een stuk langer dan de andere en veel lichter: een duingebied in een bos, met vijanden die patrouilleren bij zandzakken, bij een legertent waar ze over een landkaart gebogen staan en bij jeeps en tanks, van de bosrand naar de achterdeur van een groot complex, en met schaduw om in te schuilen. Dat is `dunes` geworden (`tools/levels/dunes.gd`, `scenes/dunes.tscn`), gebouwd op de branch `duinen`. Het is het eerste level onder de open lucht bij daglicht, het eerste op een terrein met hoogteverschil, en het eerste waarin vijanden iets doen vóór hun gevecht begint. Voor alle drie moest er iets bij. Dezelfde avond op Michiels woord ("merge het maar, dan ga ik het spelen") in `fase-2-vertical-slice` gevoegd, voor iemand het gespeeld had; niet gepusht.

**Wat er staat**

- **Het level.** 340 bij 230 meter duin en dennenbos. De speler komt in het zuidwesten uit het bos en volgt het karrenspoor van de vrachtwagens in drie stukken, met telkens een lange duin ertussen: door het bos en langs de kap, over de pas met de slagboom, door de kaalgewaaide vallei en langs het depot onder zijn net; over het zadel, waar een wachtpost ligt, terug naar het westen langs het bivak met de commandotent, het wagenpark en het tankkamp; en door het gat in de laatste duin naar het prikkeldraad voor de muur, door de poort de binnenplaats op en achter het hoofdgebouw langs naar de achterdeur. Die deur is de uitgang.
- **Veertien gevechten van 3 tot 7, samen 74 vijanden, zes checkpoints.** Het fabrieksterrein, tot nu toe het langste level, heeft 59 vijanden in elf gevechten; van het begin langs het midden van elke zone naar de uitgang is het daar 253 m en hier 852 m. Er stonden er eerst 52 in elf gevechten: evenveel gevechten als het fabrieksterrein, en dat is geen stuk langer. De vallei en de binnenplaats zijn daarom elk twee gevechten geworden, op het zadel is een wachtpost bijgekomen en de posten van het wagenpark tot de achterdeur hebben er een man bij. In de tent staan er vier om de kaarttafel; de rest staat op wacht of loopt een ronde.
- **Het zit in het spel.** De levelkeuze is Factory, Works, Depot, Powerhouse, Dunes; de grote deur van de centrale leidt naar de duinen, en de achterdeur van het complex sluit het spel af tot het volgende level er is. `VERSION` in `scripts/net.gd` is 8.
- **Land** (`tools/kit/land.gd`, de negende la van de bouwdoos). Een level zegt hoeveel land het heeft en vormt het van grof naar fijn: `land`, `swell`, `ridge`, `mound`, `hollow`, `bank`, `dig`, `level_off`, `track`, `soften`, `roughen`, en legt het met `lay_ground`; `shut_in` zet er de muren omheen die niemand ziet en waar niemand langs komt. Het land is een veld van hoogtes op een meter van elkaar: één botsvorm (`HeightMapShape3D`, in een eigen lichaam `Ground`) en een mesh in blokken van 32 m. Daarna zegt `ground(x, z)` overal hoe hoog de grond ligt, en alles wat erop staat vraagt dat. Een duin heeft een korte steile kant waar niemand tegenop loopt (steiler dan 45 graden: het navmesh en de speler houden daar op) en een lange rug.
- **Wat de grond bedekt** staat op een kaart van het land, twee punten per meter: naalden, mos en aangereden aarde (`cover`). Het materiaal `dune_ground` mengt daar vier gescande texturen mee. Een boom legt zelf naalden en mos onder zich neer, een spoor zijn aarde.
- **Geen lightmap.** Onder de open lucht is het licht de zon en de lucht zoals ze zijn; er wordt niets gebakken en er hoeft dus ook niets opnieuw gebakken. `tools/bake_lightmaps.py` zegt dat van zo'n level (`dunes has no lightmap ... Nothing to bake`), en het keurmerk telt het als bij.
- **De schaduw is uitgerekend** (`_shade_land`). Als alles staat kijkt de bouwer van elk punt van die kaart op borsthoogte naar de zon: stuit de blik op een botsvorm of gaat hij door een kruin, dan ligt het punt in de schaduw. 17% van het land ligt zo uit de zon. Dat staat in de kaart (de grond wordt er donker van waar de schaduwkaarten van de zon ophouden, voorbij 80 tot 105 m) en gaat als bitkaart met het level mee (`scenes/levels/dunes_shade.res`, `scripts/land.gd`): daar leest het spel af of iemand in de schaduw staat.
- **Wat er groeit.** Dennen in vijf vormen en duindoorn in twee, in code getekend (`tools/models/trees.gd`): een stam met de stompen van afgeworpen takken, zijtakken, en een kruin van kaarten met naalden. Elk is twee meshes: van dichtbij ongeveer 600 driehoeken, vanaf 60 m een stam met vijf kaarten. `wood()` plant een bos over een gebied, `thicket()` een haag van struiken waar niemand doorheen komt, `marram()` helmgras, `ferns()` varens. 393 dennen, 306 struiken en 2000 pollen helm.
- **Wat een leger in het veld laat staan** (`tools/kit/field.gd`, de tiende la): `sandbags`, `sandbag_post`, `sandbag_ring`, `tent`, `bivouac`, `camo_net`, `wire_fence`, `wire_coil`, `barrier_pole`, `sentry_box`, `sign_post`, `pillbox`, `watch_tower`, `nissen_hut`, `campfire` en `vehicle`. De voertuigen zijn modellen uit code (`tools/models/vehicles.gd`): een jeep, een vrachtwagen met huif en een tank, die laatste ook met gedraaide koepel; 3600 tot 4900 driehoeken. Alles staat in de showroom.
- **De landkaart is de kaart van het level zelf** (`map_sheet`, `mark_on_map`). De bouwer tekent hem uit het land zoals het ligt: hoogtelijnen, het bos groen, het spoor, en een rode cirkel om elke post en om de poort en de achterdeur. Hij ligt op de tafel in de tent en hangt groot op een bord erachter.
- **De wacht.** Een zone kan door een wacht gehouden worden: het level zegt per vijand wat hij doet (`guard()`, `beat()` in `tools/kit/land.gd`, als derde ding in `route_zone`). Zo'n vijand staat niet uit: hij loopt zijn ronde of staat op zijn post en kijkt om zich heen. Hij ziet wat voor hem is (58 graden naar weerszijden): iemand in het licht tot op 34 m, iemand in de schaduw pas op 7,5 m, gebukt 30% minder; wie rent wordt binnen 9 m gehoord, wie tegen hem aan loopt altijd opgemerkt. Zeker weten kost tijd (1,7 s aan de rand van wat hij ziet, een vijfde daarvan van dichtbij); twijfelt hij, dan blijft hij staan en kijkt. Een schot hoort hij, verder naarmate het wapen harder is: het pistool 17 m, het geweer 34, de shotgun 42. Weet er één het, dan begint het gevecht van die zone zoals altijd. Een zone binnenlopen begint niets meer. Alle veertien de zones van de duinen worden zo gehouden; de andere levels zijn niet veranderd.
- **Wat de speler ervan ziet.** Staat hij in de schaduw terwijl er een wacht in de buurt is, dan staat onderin `IN THE SHADE`. Om het richtkruis groeit een boogje naar elke wachter die hem begint te zien, van wit via oranje naar rood; vol is gezien.
- **Een wacht ver van iedereen staat stil** (`_stir` in `scripts/game.gd`): binnen 75 m van een speler loopt hij, voorbij 90 m niet.
- **Geluid.** Stappen in zand (`footstep_sand`), een inslag in zand (`impact_sand`, met een eigen stofwolk en een kuiltje) en een bed voor de open lucht van de duinen (`ambience_dunes`: wind, en het ruisen van dennen). Gesneden uit de pakken die er al waren.
- **De zon.** Ze staat op 48 graden in het zuidzuidwesten, waar de lucht haar heeft (`kloofendal_48d_partly_cloudy_puresky`, 4k): schaduwen vallen naar het noordnoordoosten en zijn ongeveer zo lang als wat ze werpt hoog is. De noordkant van het hoofdgebouw, waar de achterdeur is, ligt daardoor helemaal in de schaduw.

**Van Poly Haven opgehaald** (CC0, 69 MB, op Michiels woord): acht texturen op 1k (`dense_sand`, `sand_01`, `forrest_ground_01`, `forrest_ground_03`, `dirt`, `pine_bark`, `hessian_380`, `rough_linen`), de lucht op 4k, en tien modellen op 1k (munitiekist, legerkrat, groene jerrycan, veldradio, vuurplaats, boomstronk, dode takken, varen en twee soorten onderbegroeiing). `sand_01` en de twee onderbegroeiingen (`shrub_03`, `weed_plant_02`) zijn nog nergens gebruikt. De bomen van Poly Haven zijn te zwaar: van 0,15 miljoen driehoeken voor een kokerboom tot 17 miljoen voor de den.

**Gemeten** op 12 oktober 2026, 's avonds, op de accu (72 tot 74%, geen spaarstand), load 2 tot 3, niets anders op de GPU; elk blad één keer

| | |
|---|---|
| De duinen beschreven | 836 regels in zeven bestanden; de laden `land.gd` en `field.gd` zijn er 1061 en 473 |
| Gebouwd | 736 botsvormen, 699 bomen en struiken, 234 losse modellen, 23 voertuigen, 21 dingen die ontploffen, 73 decals, 6 probes |
| Bouwen | 30 s, waarvan 2 s de opmeting met de schaduw |
| De bestanden van het level | 7,1 MB in 210 bestanden; geen lightmap |
| Laden zonder beeld, met het navmesh | 2,0 s |

Het contactblad, 23 standpunten (`benchmark/sheets/dunes_zones.jpg`):

| | Tekenopdrachten | Driehoeken | Fps | Traagste standpunt |
|---|---|---|---|---|
| 1440p met FSR 2 op 67%, zonder vijanden | 370 tot 973 | 0,4 tot 1,4 miljoen | 83 tot 106 | een loods van dichtbij: 83; het bos: 86 |
| 3456×2160, Ultra, MetalFX, renderschaal vanzelf: zoals er gespeeld wordt | 347 tot 948 | 0,5 tot 1,5 miljoen | 73 tot 102 | het bos: 73 |
| Hetzelfde met de 74 vijanden op hun post | 800 tot 1935 | 0,6 tot 2,4 miljoen | 64 tot 99 | het bos: 64, met 55 voor het traagste honderdste |

Het keurmerk: "Every zone has what it is held to".

- **Wie op wacht staat wordt van overal getekend**, ook achter drie duinen: een level zonder zones laat niets weg, en een wacht staat er vanaf het laden. In het bos zijn dat 800 tot 950 tekenopdrachten erbij, en het ging er van 73 naar 64 fps; met 52 vijanden was dat van 72 naar 70. Elk van die cijfers is één ronde, dus hoeveel van het verschil van de 22 erbij komt is niet gemeten. Wie verder weg staat dan er te zien valt niet tekenen is het eerste om te proberen, en is niet gedaan.

- **De schaduwkaart van de zon kostte in het bos 17 beelden per seconde.** Elk level kreeg een zonnekaart van 2048, omdat de zon overal gebakken is; hier is ze alles. Op Ultra, 3456×2160, vier standpunten in het bos, om en om gemeten: met de kaart van 8192 en overvloeiende schaduwlagen 55, 54, 59 en 62 fps; met 4096 en overvloeien 64, 63, 68 en 69; met 8192 zonder overvloeien 63, 62, 67 en 70; met 4096 zonder 74, 68, 79 en 73. Een level onder de open lucht (`metadata/open_sky` op zijn omgeving) krijgt daarom 4096 (`SUN_ATLAS_OPEN` in `scripts/settings.gd`), en de zon van de duinen laat haar lagen niet overvloeien. Op de beelden is geen naad te zien.
- **Niets hapert de eerste keer.** Op een wandeling langs vijftien plekken van het level, vanaf het laden, worden er tijdens het tekenen geen pipelines meer gemaakt; het langste beeld duurde 11 ms. Dat is gemeten voor de wachtpost op het zadel erbij kwam, die niets heeft wat er niet al stond. Het land laat bij het laden van elk materiaal één mesh tekenen achter het zwart (`_rehearse` in `scripts/land.gd`).

**Gecontroleerd, en wat niet**

- `tools/selftest.sh` slaagt met de duinen erin, 401 controles in vijf minuten en tien seconden (de grens staat nu op 420 s): de route is te lopen en komt door elke zone, elke vijand kan de speler bereiken, de checkpoints overleven een herstart en een dood, de achterdeur gaat open en het spel eindigt erachter. Voor een zone met een wacht controleert hij dat de vijanden op wacht staan en van niets weten, dat binnenlopen niets begint en dat een schot het gevecht begint. En één keer per level, bij een wachter die stilstaat: wie voor hem in de schaduw staat wordt niet gezien, wie voor hem in het licht staat wel, en dat begint het gevecht.
- `tools/nettest.sh` (62), `tools/test_humanoid.sh`, `tools/test_sandbox.sh` (30), `tools/test_effects.sh` (259) en `tools/test_sound.sh` (38) slagen.
- `tools/build_check.py`: de fabriek, het fabrieksterrein, het depot, de vleugel en de modellen komen er gelijk uit. Van de centrale is één regel veranderd, in het plan en in haar scène: waar de uitgang heen leidt (`metadata/next`). Haar lightmaps zijn bij. De showroom is veranderd door wat erbij staat.
- **Gespeeld is het niet.** Er zijn ruim honderd beelden van bekeken, twee uit het lopende spel, en een plattegrond. Of sluipen leuk is, of 34 en 7,5 m de goede afstanden zijn, of een wacht eerlijk aanvoelt en of elf gevechten boeien, weet ik niet.
- De getallen van de wacht zijn een eerste gok. Ze zijn `@export` in `scripts/enemy.gd` (`sight_lit`, `sight_shade`, `sight_crouched`, `sight_side`, `notice_time`, `round_pace`), dus per thema en in de sandbox te zetten.
- De drie geluiden heeft niemand gehoord.

**Onderweg gevonden**

- **De muren die niemand ziet hielden de zon tegen.** Om het land staan vier muren van 60 m hoog tegen weglopen, en de schaduw wordt uitgerekend met een straal naar de zon die op elke botsvorm stuit. Een strook van 30 m langs de hele zuidrand en van 20 m langs de westrand gold daardoor als schaduw: het begin, het spoor door het bos, de zuidkant van de vallei. Wie daar in de volle zon liep werd pas op 7,5 m gezien en las `IN THE SHADE`, en van ver lag er een rechte donkere baan over het zand. De test met de schaduw slaagde gewoon. Het viel pas op toen het level van boven getekend was, met de schaduwkaart erin: 33% schaduw was 17%. De muren zijn nu van de la zelf (`shut_in`), de straal gaat erdoorheen (`_stops_sun`), en een schot dat erop eindigt laat niets achter (het oppervlak `air` in `scripts/fx.gd`).
- **De zandzakken stonden binnenstebuiten.** De zijkant van een zak was met de klok mee opgegeven waar de bouwer tegen de klok in verwacht: wat getekend werd was de binnenkant van de achterste helft. Dat zag eruit als een zak, met het licht aan de verkeerde kant: zwart naar de zon toe en licht in zijn eigen schaduw. Op de beelden van de eerste ronde is het niet opgevallen; het bleek bij de nieuwe post, van voren en van achteren bekeken.
- **Een MultiMesh is niet te bouwen zonder beeld.** De bouwer draait zonder GPU, en een `MultiMesh` bewaart zijn plaatsen in de renderer: de 2000 pollen helm stonden na het opslaan allemaal op nul. Het gras van een blok grond is daarom één gewone mesh geworden.
- **De kaart van de bedekking moet ná het opruimen geschreven worden.** De bouwer gooit bij het wegschrijven de bestanden van vorige keer weg; wat tijdens de opmeting al bewaard was (de schaduw) ging mee. Het wordt nu in `_finish_zones` geschreven.
- **Een texel buiten de kaart herhaalt de rand.** Het spoor liep als een streep het zand buiten het land in tot aan de horizon. Buiten de kaart ligt nu alleen zand.
- **Het kortste pad neemt de steile kant niet, maar wel het uiteinde van een duin, en het volgt het spoor niet.** Waar een duin uitloopt wordt zijn steile kant begaanbaar, en van het zadel naar het kampspoor loopt de test schuin over de rug van de duin en niet langs de tent. Een zone moet daarom zo breed zijn dat elk pad erdoor komt, en waar de test een zone binnenkomt is niet waar de speler dat doet: de uitkijk op zijn heuvel stond op 13,7 m van waar het pad de zone van het depot in liep, en de grens is opgeschoven.
- `tools/gen_decals.sh` tekent alle decals opnieuw, maar steeds dezelfde: na vijftien opschriften erbij is er geen bestaand bestand veranderd.

**Buiten de bestanden van het level geraakt**

- `scripts/enemy.gd` (de wacht), `scripts/game.gd` (zones met een wacht, en `_stir`), `scripts/hud.gd` (de boogjes en het woord), `scripts/weapons.gd` en `scripts/puppet.gd` (een schot wordt gehoord), `scripts/player.gd` (stappen in zand), `scripts/fx.gd` (zand, en de muur die niemand ziet), `scripts/sfx.gd` (het bed van de open lucht van een level), `scripts/settings.gd` (de zonnekaart onder de open lucht), `scripts/menu.gd` (de levelkeuze), `scripts/net.gd` (`VERSION`).
- `scripts/selftest.gd`: zones met een wacht, de proef met de schaduw, `--level=<level>` om één level alleen te spelen, en de tijdsgrens.
- `tools/level_builder.gd`: `route_zone` neemt de wacht aan. `tools/kit/rooms.gd` breidt nu `field.gd` uit en roept in `_garrison` zijn voorganger aan.
- `tools/bake_lightmaps.py`: een level zonder lightmap. `tools/effects/daylight.gd` en `tools/test_sound.gd`: de duinen erbij.
- `tools/levels/powerhouse/plan.gd` en `scenes/levels/powerhouse_level.tscn`: de ene regel van de uitgang, op Michiels woord.
- `tools/levels/showroom.gd` en zijn scène: de nieuwe stukken.
- `CLAUDE.md`: de selftest duurt vijf minuten, en `--level`.

**Werkwijze**

| Stap | Hoe |
|---|---|
| De duinen bouwen | `tools/build_level.sh dunes` (een halve minuut); er valt niets te bakken |
| Alleen dit level testen | `tools/selftest.sh --level=dunes` (50 s) |
| Het contactblad en het keurmerk | `tools/zone_sheet.py dunes`, met `--posted` voor de vijanden erbij; op de speelinstelling met `--res=3456x2160 --upscaler=metalfx --quality=3 --scale=auto` |
| De bomen of de voertuigen opnieuw bouwen | `tools/build_model.sh trees` of `vehicles`, dan het level |
| De getekende texturen opnieuw maken (naalden, helm, net, gaas, bosrand, sporen) | `tools/gen_foliage.sh [naam]` |
| Een stuk van dichtbij bekijken | `tools/build_level.sh showroom`, dan `tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="-50,1.7,46,0,-4"` |
| De duinen spelen in een venster | `/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/dunes.tscn -- --play`, of in het spel: Play, Dunes |
| De geluiden horen | `tools/hear.py footstep_sand`, `tools/hear.py impact_sand`, `tools/hear.py ambience dunes --in=yard` |

**Nog open**

- **De bomen zijn getekend, niet gescand.** Van een paar meter zijn het kaarten met naalden erop. Een gescande den van bruikbare omvang is er niet onder CC0.
- **Wie om de tafel staat, staat er alleen.** Er is geen houding voor overleggen of wijzen: ze staan in hun gewone rusthouding met het gezicht naar de kaart. In `assets/animations/ual1.glb` zit een `Idle_Talking_Loop` die daarvoor te gebruiken is.
- **De boogjes van de wacht zijn er alleen voor wie host.** Wat een wachter ziet beslist de host; een gast krijgt het niet te horen. De wacht zelf loopt bij een gast wel.
- **De wachttoren is leeg.** Wie boven staat kan niet naar de speler lopen, en de route eist dat van elke vijand.
- **Zandzakken, tenten en netten kunnen niet stuk**, en een net of een tentdoek houdt een kogel niet tegen maar een blik ook niet: alleen de dichte wanden van de tent doen dat.
- **Een robot klinkt in het zand als op beton**: alleen de speler heeft stappen in zand.
- **Er zingt geen vogel.** Het bed is wind; iets wat nu en dan klinkt is er voor de duinen niet.
- **De binnenplaats is groot en nog schraal**, en de muur is kaal.
- **Een wal van zandzakken houdt op met tanden**: om en om steekt een halve zak uit. Een kopse zak aan het eind zou hem sluiten.
- **Het navmesh meldt bij het laden vier randen die samenvallen** (`Navigation region synchronization had 4 edge error(s)`). Elke vijand komt bij de speler en de route is te lopen; waar die randen liggen is niet uitgezocht.
- **De plattegrond die de twee fouten liet zien is een los script gebleven** en geen gereedschap: hoogte, steile kanten, schaduw, bomen, botsvormen, zones en posten van boven. Voor het volgende level met land is dat het eerste om te maken.
- `tools/level_map.py` kan geen land tekenen: het kent alleen dozen op een vloer op nul.
- De muziek is het stuk van de andere levels. Niemand heeft dat op het gehoor gekozen.

## De duinen: het beeld

Op 12 oktober 2026 's avonds gevraagd: het vijfde level, de duinen, grafisch afmaken, in de nacht. Gebouwd op de branch `duinbeeld`, door vier agents elk in een eigen worktree met een eigen deel (`duinbeeld-bomen`, `duinbeeld-grond`, `duinbeeld-veld`, `duinbeeld-complex`) en een vijfde die het licht deed, mat, hun werk samenvoegde en dit schreef. Op 13 oktober om elf uur op Michiels woord ("merge het maar in de trunk") in `fase-2-vertical-slice` gevoegd, nadat hij het vanuit de worktree gespeeld had; niet gepusht. Het werk lag stil van 23:45 tot 06:10, omdat de gebruikslimiet van de sessie op was, en nog eens in de ochtend tot kwart over negen door een netwerkstoring; het was om half elf klaar.

Het level was die avond gebouwd en speelde, maar zag eruit als een eerste schets: kruinen van een handvol kaarten die als loofbomen lazen, één vlakke toon zand met een bruine veeg als spoor, 2000 keer dezelfde pol helm, een tent als een doos, prikkeldraadrollen als zwarte linten, een kale muur om een kaal terrein met een grijze doos als hoofdgebouw, en een zwart silhouet als bosrand.

**Wat er staat**

- **Het licht.** De gescande lucht (`kloofendal_48d_partly_cloudy_puresky`) heeft onder haar horizon de lucht gespiegeld, als boven water: alles wat naar beneden kijkt of in de schaduw staat, de onderkant van een kruin, de noordkant van het hoofdgebouw, een kin, kreeg koud blauw licht van onderaf (gemiddeld 0,16, 0,19, 0,28 onder de horizon tegen 1,77, 1,83, 1,90 erboven). `shaders/dune_sky.gdshader` zet daar het land voor in de plaats zoals de lucht het ziet: warm zand, 0,8 keer zo helder als zijn kleur. De zon is sterker en warmer (3,9 waar 3,2 stond), de lucht iets zwakker (0,88), de nevel dunner (0,0009 waar 0,0016 stond) en warmer naar de zon toe, en de tonemapper heeft iets meer contrast. De schaduw van de zon heeft een rand die overal even zacht is, in plaats van een die met de afstand meegroeit: zie "Gemeten".
- **De dennen** (`tools/models/trees.gd`, `shaders/crown.gdshader`, `tools/gen_sprigs.sh`). Een den wordt eerst gegroeid en dan getekend: een stam, takken die draaien en zich splitsen, en aan het eind van elke tak een schijf naalden die vlak ligt, met lucht tussen de ene schijf en de volgende. De kaarten van een kruin tonen takjes en hele takeinden die in Blender gegroeid en op de CPU gerenderd zijn, van boven, van opzij en van voren. Een boom wordt drie keer getekend, voor dichtbij, de middenafstand en ver weg, en een vierde keer voor zijn schaduw. De duindoorn is opnieuw gemaakt, in bes, op dezelfde manier. De bosrand om het land was één textuur en is nu rijen van de dennen van het land zelf, per stuk samengevoegd tot één mesh.
- **De grond** (`shaders/dune_ground.gdshader`, `tools/kit/land.gd`, `shaders/grass.gdshader`, `tools/render_grass.sh`). Bleek zand, crème tot zeemkleurig in de zon en het bleekst op een kam, met ribbels in drie maten op de ruggen waar de wind tegenop komt en geen op een glijhelling; een bosbodem van donkere naalden met mos in kussens; een korst van mos en korstmos op het grijze duin; een spoor van twee geulen met de afdruk van het profiel erin. Het mesh van de grond wordt gemaakt als alles staat en draagt wat de bouwer van elke plek weet naar het materiaal: hoe hoog ze ligt tussen wat eromheen ligt, hoe los het zand is, de korst, het gras, en waar ze langs het spoor ligt. Helm groeit in driften, dicht op de kammen en afwezig ertussen, in pollen van elke maat: bundels halmen die één voor één gemodelleerd en in Blender gerenderd zijn, op kaarten die uit één voet buigen, elke grotere pol op een bult zand. De halmen buigen in vlagen die met de wind meelopen.
- **Wat een leger in het veld laat staan** (`tools/kit/field.gd`, `tools/models/vehicles.gd`). De commandotent hangt tussen haar palen, met een volant, wanden die bollen, naden, lappen, scheerlijnen met schuivers en haringen, en een voorkant die opgerold en vastgebonden is; binnen liggen een grondzeil en loopplanken en staan een veldtelefoon, helmen en mokken. Zandzakken zijn platgedrukt bij de naad, één op de vijf is dichtgebonden, elke zak hangt anders, een halve zak sluit om de andere laag de kop van een wal (een open punt van het vorige hoofdstuk), en aan de voet ligt zand. Prikkeldraad is een hoepel van getekend draad per winding, twee tegen elkaar, lager tussen de piketten. Netten hangen tussen hun palen, met een rafelige schort. De jeep, de vrachtwagen en de tank zijn opnieuw gebouwd, met één verf voor staal, banden en rupsen waar het zand van onderaf tegenop zit, en sterren, brugplaatjes en nummers van één getekend blad. Slagboom, schildwachthuisje, borden, bunker, wachttoren, Nissenhut en kampvuur zijn uitgewerkt, en boven het vuur van het bivak staat een dunne rookpluim: één mesh van 48 driehoeken. In de kampen liggen en hangen dingen die zeggen dat er mensen wonen; niets daarvan heeft een botsvorm.
- **Het complex** (`tools/levels/dunes/depot.gd`, nieuw, en `complex.gd`). De muur is gestort in vakken van 4 m tussen pijlers, in twee lagen met een rand, op een voet en onder een afdekrand, met gekromde betonnen armen met drie draden en een rol erop, een wachtpost op twee hoeken, dertien lichtmasten die niet branden, vaknummers aan de binnenkant en borden aan de buitenkant; druipgaten, roest eronder, strepen van de afdekrand, vocht en groen aan de voet zijn één shader. De poort heeft vleugels van stalen buis en plaat, en het wachtlokaal is van baksteen. De binnenplaats heeft wegen van betonplaten met voegen, scheuren, bandensporen en olie, banden, putten, een stopstreep, parkeervakken, een tankplaats en een exercitieveld tussen gewitte banden. Het hoofdgebouw is een betonnen skelet met baksteen ertussen en twee rijen stalen ramen per travee, 24 cm teruggelegd; de schotel op het dak is dof grijs op een juk. De achterdeur, het doel van het level, heeft een luifel, gestreepte stijlen en een wit bord van 6,2 m met GOODS IN.
- **Wat een duin verbergt wordt niet getekend** (`scripts/hidden.gd`). Een level op land heeft geen zones om uit te zetten: vanuit het eerste bos werd elke post van het hele level getekend. Het land zelf, grof en van onderaf gezien (een punt per twee meter, zo laag als de laagste grond eromheen en nog 30 cm lager), en de muren die erop staan zijn nu de occluders van de renderer. Een boom is hoger dan een duin en wordt toch getekend.
- **Kleine dingen.** De speler laat laarsafdrukken na in het zand, links en rechts om en om, een echte pas uit elkaar: een decal die vooral een deuk is, en de oudste van zestig waait dicht (`Fx.footprint()`). Negen meeuwen cirkelen boven het open duin, één mesh die één keer getekend wordt en waarvan elke vogel zijn cirkel in de vertex-shader vliegt (`scripts/gulls.gd`). En in de lucht hangen stofjes die alleen oplichten waar de zon erop valt, om wie kijkt heen (`scripts/air.gd`); tegen de lucht worden ze weggelaten.
- **Gereedschap.** `--at` van de benchmark neemt een hoogte boven de grond (`--at="120,+1.6,187,-88,-2"`). De benchmark telt per standpunt de pipelines die tijdens het tekenen gemaakt werden, en `--profile` haalt in een level op land om de beurt de bomen, de grond en wat erop gestrooid is weg. `tools/room_sheet.py` kijkt nu ook naar een level zonder zones en neemt `--columns` en `--res`. `tools/gen_decals.sh` maakt alleen de decals die genoemd worden.

**Achterhaald in "De duinen: het vijfde level"**: "Wie op wacht staat wordt van overal getekend" (wat een duin verbergt niet meer), "De bomen zijn getekend, niet gescand" (de takjes zijn nu gegroeid en gerenderd; gescand zijn ze nog steeds niet), "Een wal van zandzakken houdt op met tanden", en "De binnenplaats is groot en nog schraal, en de muur is kaal".

**Gemeten**

Alle framerates op de instelling waarop gespeeld wordt (3456×2160, Ultra, MetalFX, renderschaal vanzelf), met de 74 vijanden als soldaten op hun post, om en om met het level van die avond in een kopie ernaast. Tekenopdrachten en driehoeken hebben geen last van drukte, framerates wel.

De eindstand, 13 oktober 2026 van 10:13 tot 10:24, **op de accu** (68 tot 59%, geen lader), load 4 tot 5 terwijl een andere sessie testte, drie ronden om en om, 600 beelden per standpunt:

| Standpunt | Fps voor, 1% low | Fps na, 1% low | Verschil | Tekenopdrachten en driehoeken, voor en na |
|---|---|---|---|---|
| Het bos, 1 | 66,7 en 61,9 | 70,2 en 64,3 | +3,5 | 995 en 2,09 miljoen, 907 en 1,74 |
| Het bos, 2 | 66,0 en 61,9 | 73,1 en 66,5 | +7,2 | 1070 en 2,36, 885 en 1,72 |
| Het bos, 22 | 70,4 en 64,8 | 82,6 en 74,8 | +12,2 | 1218 en 3,11, 939 en 1,90 |
| De vallei, 5 | 83,3 en 76,1 | 81,4 en 73,9 | -1,9 | 738 en 1,39, 625 en 1,21 |
| De uitkijk, 6 | 83,1 en 69,2 | 79,8 en 72,9 | -3,4 | 462 en 1,04, 461 en 1,12 |
| Het bivak, 8 | 72,2 en 66,4 | 73,0 en 66,8 | +0,8 | 999 en 2,03, 997 en 1,92 |
| Het tankkamp, 12 | 92,6 en 84,3 | 89,4 en 81,9 | -3,3 | 766 en 1,56, 727 en 1,39 |
| Het prikkeldraad, 14 | 90,9 en 83,3 | 90,3 en 82,9 | -0,6 | 807 en 2,09, 796 en 1,74 |
| De binnenplaats, 16 | 90,0 en 82,3 | 84,9 en 77,7 | -5,1 | 738 en 1,56, 664 en 1,41 |
| De achterdeur, 19 | 75,2 en 66,5 | 87,9 en 80,0 | +12,7 | 959 en 2,18, 621 en 1,33 |

De drie ronden van een kant lagen nooit meer dan één beeld per seconde uit elkaar.

- **Het keurmerk, met de soldaten op hun post, op dezelfde instelling**: "Every zone has what it is held to", in één keer (10:26, load 5, accu 57%). 23 standpunten: 461 tot 1202 tekenopdrachten, 0,9 tot 2,8 miljoen driehoeken, 65,8 tot 90,0 fps, en het traagste honderdste nergens onder de 61. Het traagste standpunt is 21, vanaf het oostelijke duin over het bos en het bivak: 65,8. Het blad staat in `benchmark/sheets/dunes_zones.jpg`.
- **Wat een duin verbergt** (`scripts/hidden.gd`), 1920×1080, robots op hun post, de 23 standpunten: 30.607 tekenopdrachten samen waar het er 33.470 waren (9% minder), en per standpunt tot een derde minder driehoeken (standpunt 19: 0,88 miljoen waar 1,65). De beelden met en zonder verschillen alleen waar blad beweegt. Om en om gemeten voor de rest erbij kwam, twee ronden: het bos +2, +3 en +7 fps, de achterdeur +6, de rest gelijk.
- **De eerste dennen kostten twintig beelden per seconde**, en waar dat zat: zie "Onderweg gevonden". Met `--profile`, dat iets weghaalt en terugzet binnen één run, het eerste standpunt van het bos zonder wachters, in ms per beeld:

| | De bomen tekenen | De schaduw van de zon | De grond |
|---|---|---|---|
| Het level van die avond | 3,8 | 3,9 | 3,1 |
| De eerste dennen, met zachte randen | 7,1 tot 9,0 | 5,9 tot 6,9 | 3,2 tot 3,7 |
| De dennen zoals ze nu zijn | 3,3 | 3,6 | 3,6 |

- **De zachte rand van de zonneschaduw die met de afstand meegroeit** (`light_angular_distance` 0,6 op de zon) kostte in elk beeld zes tot zeven beelden per seconde. Om en om, twee ronden, met soldaten: het traagste standpunt 60,0 met en 65,8 zonder, het bos 62,8 en 70,3, het bivak 67,0 en 73,0, van dichtbij op de grond gekeken 76,4 en 83,3. Zonder is de schaduw van een kruin geen vlek meer maar toont ze de schijven naalden; de rand is overal even zacht (`shadow_blur` 1,5).
- **Een soldaat is goedkoper te tekenen dan een robot.** Eén robot is 86 tekenopdrachten; met alle wachters op hun post kosten drie standpunten als robots 1480, 1189 en 1502 tekenopdrachten en als soldaten 908, 646 en 964, tegen iets meer driehoeken (1,56, 1,03 en 1,63 miljoen tegen 1,30, 0,83 en 1,34). Er wordt met soldaten gespeeld; de cijfers van het vorige hoofdstuk zijn met robots.
- **De bestanden van het level**: 32 MB in 436 bestanden, waar het 7,1 MB in 210 was; nog steeds geen lightmap. Bouwen duurt 35 s. Het land draagt 3444 pollen helm, 5218 plukken fijn gras, 280 varens, 379 kruiden, 71 dode takken, 2418 dennenappels en 1380 wortels, elk soort per blok van 32 m één mesh zonder schaduw die voorbij 40 tot 85 m niet getekend wordt; `--profile` meet voor al het gestrooide samen 0,2 tot 0,9 ms per beeld.
- **Niet gemeten**: aan de eigen lader en op een stille laptop (alles van de eindstand is op de accu gemeten naast een andere sessie; de avond ervoor, aan een lader van 94 W, lag het level van toen een paar beelden hoger), in beweging, en in een gevecht.

**Gecontroleerd, en wat niet**

- `tools/selftest.sh` slaagt op de eindstand, 401 controles; `tools/nettest.sh` (62), `tools/test_effects.sh`, `tools/test_humanoid.sh` (55), `tools/test_sandbox.sh` (30) en `tools/test_sound.sh` (38) ook. Dat was vóór de laatste wijziging, de schaduwrand van de zon in `scenes/dunes.tscn`; daarna is alleen de test van de duinen opnieuw gedraaid.
- `tools/build_check.py factory works depot powerhouse wing` op de eindstand: geen bestand van die vijf levels is veranderd, en `tools/bake_lightmaps.sh --list` noemt elk van hun lightmaps bij. Veranderd zijn de duinen, de showroom (door de veldstukken en de voertuigen die erin staan) en de modellen van de bomen, de struiken en de voertuigen.
- **Wat staat, staat waar het stond.** De agents van het veld en van het complex hebben na hun laatste bouw alle 780 botsvormen van het level (vorm, maat, plek, oppervlak) naast die van het level van die avond gelegd: geen regel verschil. De agent van de grond deed hetzelfde met elke botsvorm, boom, model, wat ontploft, de punten van de route en de schaduwkaart (53.840 bits), tot en met zijn derde commit. De bouw zegt nog steeds 17% schaduw, 14 zones en 6 checkpoints. Na het samenvoegen van alle vier is die vergelijking niet nog eens gemaakt.
- **Niets hapert de eerste keer, voor zover een benchmark dat ziet**: 92 pipelines op het eerste standpunt, dat geen laadscherm heeft, en geen enkele op de 22 daarna. Een rondgang vanaf het titelscherm, zoals in het vorige hoofdstuk, is niet gelopen.
- **Michiel heeft het gespeeld**, op 13 oktober vanuit de worktree, op de accu, voor het de trunk in ging. Zijn woord erna: "Geweldig werk geleverd!" Over de afzonderlijke punten onder "Niet kunnen beoordelen" heeft hij niets gezegd. Zelf heb ik niets in beweging gezien.

**Onderweg gevonden**

- **Het licht van onderaf was blauw.** Een "pure sky" van Poly Haven heeft geen grond: onder de horizon staat de lucht nog eens, gespiegeld. Als achtergrond valt dat niet op, want het land staat ervoor; als omgevingslicht kleurt het alles wat naar beneden kijkt. De andere levels met zo'n lucht (het fabrieksterrein, de centrale) hebben gebakken licht en zijn niet nagekeken.
- **Een kruin met zachte randen kostte het bos twintig beelden per seconde.** De eerste dennen maakten de rand van elk gat in een kaart zacht waar het beeld met meerdere monsters per punt getekend wordt (alpha-to-coverage). Daarmee doet een kruin niet meer mee aan de dieptepas vooraf, en wordt elke kaart die achter een andere ligt volledig belicht voor ze bedekt wordt, met voor elk punt de zachte schaduw van de zon erbij (zestien monsters en een zoektocht naar wat ervoor staat). Het bos ging met soldaten van 68 naar 49 fps; tekenopdrachten en driehoeken waren niet gestegen. De schaduw van de zon korter maken, van 110 naar 72 m, veranderde niets (6,89 en 6,73 ms): het zat niet in de schaduwkaarten maar in het opzoeken. Met een harde rand, een eigen schaduwmesh van 330 driehoeken per boom en minder kaarten zijn de dennen goedkoper dan de oude.
- **De naad in de schors was een schaduw.** Elke stam had van dichtbij een verticale rij zaagtandjes. Het was de schaduw van de grovere schaduwstam, die op plekken buiten de getekende stam uitstak. Hij loopt nu door dezelfde punten, op 0,8 van de straal.
- **De "geperforeerde plaat" aan de binnenkant van de tentwand** was geen weefsel maar de schaduwkaart van de zon op de kant die van de zon af ligt. Het doek krijgt in de schaduwpas een eigen diepteverschuiving.
- **Aangestampte aarde las als boomschaduw.** Op de binnenplaats en in de kampen lag ze als donkere rafelige vlekken met de korrel van het zand eromheen: vanaf ooghoogte de schaduwen van bomen die er niet staan. Ik hield het voor een fout in de schaduw van de dennen tot ik van boven keek. Ze is nu bleker en grijzer, met een eigen korrel en glans; stenen, sporen en slijtplekken heeft ze nog niet.
- **Een bleke lijn over de bosbodem**, tien meter links van het spoor: het mesh ging daar van een punt dat links van het spoor ligt naar een dat er rechts van ligt, door nul, en nul is het midden van het spoor. Een punt ver van het spoor krijgt nu de kant van zijn buren.
- **Een afdruk van een laars was eerst niet te zien.** Een decal legt zijn normal map alleen neer waar zijn textuur niet doorzichtig is; een afdruk die het zand alleen iets donkerder maakte, deed dus niets. De textuur is nu dekkend en wordt dun ingemengd (`albedo_mix`).
- **Stofjes tegen de lucht zijn witte stippen.** Buiten valt overal licht; ze worden nu alleen getoond dicht bij de camera en ongeveer op ooghoogte of lager (`shaders/mote.gdshader`).
- **Volumetrische mist geeft geen zonnestralen tussen de stammen.** Geprobeerd (dichtheid 0,006, 90 m): een waas tegen de zon in, niets tussen de bomen, voor een prijs die het bos niet heeft. Stralen als nabewerking vanuit de zon op het scherm helpen evenmin: de zon staat op 48 graden en is buiten beeld voor wie recht voor zich kijkt.
- **Vier delen naast elkaar botsen op namen.** Drie keer brak de bouw na het samenvoegen: het complex strooide helm met `tuft()`, die de grond intussen vervangen had (nu `marram_clump()`); het veld en het complex kregen dezelfde nacht elk een `tarpaulin()` met andere argumenten (die van het complex heet nu `sheeted()`); en uit `tools/gen_foliage.gd` verdwenen `_chainlink` en `_ruts` terwijl het manifest hun texturen nog noemt.
- **Een script dat op een fout loopt, blijft staan.** `tools/gen_foliage.sh` hing daarna tien minuten op 1% van een core: een generator die een functie niet vindt, komt nooit bij `quit()`. Elke run zonder beeld verdient een tijdslimiet, zoals `CLAUDE.md` al van een bake zegt.
- **Met een lege shadercache duurt de eerste keer laden lang.** Eén beeld uit het echte spel, in een eigen thuismap zodat Michiels save bleef wat hij was (`HOME=<map> tools/godot.sh res://scenes/dunes.tscn -- --play --snap=7`, met `GPU_SLOT` op het echte slot): zeven seconden na de start was het level nog aan het verschijnen, op 1 fps, en stonden de meshes van de repetitie als een rij zwarte balkjes midden in beeld: de repetitie duurt een vast aantal beelden, het zwart een vaste tijd. De tweede keer, met de cache gevuld, liep het na negen seconden op 98 fps en was er niets van te zien. Hoe lang de eerste keer duurt is niet gemeten. Op deze laptop is de cache van het spel al gevuld door de metingen van deze nacht, die dezelfde `user://` delen.
- **Het eerste standpunt van een benchmark maakt 75 tot 92 pipelines**: de benchmark heeft geen laadscherm. Voor het tellen van haperingen telt het eerste standpunt dus niet mee.
- **Twee keer viel het werk stil zonder dat er iets verloren ging**: om 23:45 op de gebruikslimiet en om een uur of zeven op het netwerk. De agents zijn daarna hervat met wat er in hun worktree stond; wat ze voor de onderbreking gecommit hadden en ik nog niet had gezien, stond gewoon op hun branch.

**Buiten de bestanden van het level geraakt**

- `scripts/benchmark.gd`: de hoogte boven de grond in `--at`, de pipelines per standpunt, en de bomen, de grond en het gestrooide in `--profile`.
- `scripts/zones.gd`: de lus die van muren occluders maakt staat nu in een eigen functie, `wall_boxes()`, die `scripts/hidden.gd` ook aanroept; wat hij doet is niet veranderd.
- `scripts/player.gd` en `scripts/fx.gd`: de laarsafdrukken. `tools/gen_decals.gd` en `tools/gen_decals.sh`: de afdruk, en alleen de decals die genoemd worden.
- `tools/room_sheet.py`: een level zonder zones, `--columns` en `--res`.
- `scripts/net.gd`: `VERSION` is 9, want de duinen zijn anders gebouwd.
- De showroom is herbouwd, omdat de veldstukken en de voertuigen erin staan. De herbouwde bestanden van de duinen en van de showroom zijn meegecommit, zoals bij het vijfde level zelf: geen van beide heeft een lightmap, en van de andere levels is geen bestand veranderd.
- Nieuw: `scripts/hidden.gd`, `scripts/air.gd`, `scripts/gulls.gd`; de shaders `dune_sky`, `mote`, `gull`, `crown`, `grass`, `strewn`, `canvas`, `sacking`, `wire`, `field_paint`, `smoke_column`, `weathered_wall`, `window_pane`, `worn_marking`, `yard_slab`; `tools/gen_sprigs.py`, `tools/render_grass.py` met hun `.sh`; `tools/levels/dunes/depot.gd`.
- `materials/army_green.tres`, `canvas.tres`, `sandbag.tres` en `wire.tres` zijn nu shadermaterialen. Geen ander level gebruikt ze; `tank.tres`, dat de centrale ook gebruikt, is niet aangeraakt.
- Vervallen: `assets/foliage/pine_needles.png` en `thorn_scrub.png`. Door niets meer gebruikt en blijven liggen: `assets/foliage/marram.png`, `tyre_ruts.png` en `materials/tyre_ruts.tres`.

**Niet kunnen beoordelen**

- **Zelf heb ik niets in beweging gezien.** Alles is beoordeeld op stilstaande beelden; Michiel speelde het daarna en vond het goed, zonder er meer over te zeggen. Wat ik op een stilstaand beeld niet kon zien: de wind in het gras en de kruinen; de overgang van een den op 21 m (de takjes aan de rand verdwijnen) en op 62 m; of naalden met een harde rand flikkeren op halve renderschaal; of het prikkeldraad flikkert bij het lopen; de stofjes, de meeuwen en de rook boven het bivak.
- **Of het zand de goede kleur heeft.** Het is twee keer bijgesteld op mijn oog, van te wit naar crème.
- **Of de diepere schaduw onder de dennen het sluipen verandert.** Wat een wachter ziet is niet aangeraakt, maar een soldaat in de schaduw is op het scherm donkerder dan hij was.
- Het geluid: de betonplaten van de binnenplaats hebben geen botsvorm, dus een stap erop klinkt als zand en een schot laat een kuiltje in zand achter.

**Werkwijze**

| Stap | Hoe |
|---|---|
| Het level opnieuw bouwen na een wijziging aan bomen of voertuigen | `tools/build_model.sh trees` of `vehicles`, dan `tools/build_level.sh dunes` |
| De takjes of de halmen opnieuw renderen (Blender op de CPU, een halve minuut per blad) | `tools/gen_sprigs.sh`, `tools/render_grass.sh` |
| Het blad met voor en na van de 23 standpunten | `tools/room_sheet.py dunes --before=<checkout van ervoor> --views=23 --quality=3 --res=1920x1080` |
| Wat bomen, grond, gras en de schaduw van de zon per beeld kosten | `tools/benchmark.sh --scene=res://scenes/dunes.tscn --at="16,+1.6,199.5,-85,-3" --res=3456x2160 --upscaler=metalfx --quality=3 --scale=auto --profile --only=trees,ground,strewn,sun_shadow --warmup=60`, en `cost_ms` in `results.json` |
| Het level zonder wat een duin verbergt, om het verschil te meten of te zien | `--undo=occlusion` |
| Kijken vanaf een plek zonder de hoogte van de grond op te zoeken | `--at="x,+1.6,z,draai,kantel"` |
| Het level van boven | `tools/benchmark.sh --quick --scene=res://scenes/dunes.tscn --at="170,260,150,0,-78"` |
| Haperingen tellen op een rondgang | `pipelines` per standpunt in `results.json`; het eerste standpunt telt niet |

**Nog open**

- **De grond is het duurste in elk beeld**: 2,9 tot 3,6 ms, waar ze 2,0 tot 3,1 kostte, en vanaf het oostelijke duin 2,9 waar 1,0: de nieuwe kruinen laten meer grond zien. Anisotroop filteren op de vier normal maps uitzetten scheelt niets (2,84 tegen 2,86 ms). Wie marge zoekt, zoekt hier.
- **De bosrand om het land** staat op vaste hoogtes en niet op het land, is van over de muur een rij even grote kruinen op de muurrand (standpunt 14), en telt niet mee voor de schaduw die het spel kent.
- **De dennen van heel dichtbij en van boven.** Van tien meter eronder lezen de kaarten van de dichtstbijzijnde kruin op halve renderschaal nog als brede bladeren; een jonge den is tussen 21 en 62 m een donkere kegel; van boven (de wachttoren, het dak) is een boom voorbij 62 m alleen staande kaarten. Lange dode takken zijn rechte bleke stokken. De gevelde stammen en de omgevallen dennen hebben nog de oude, rodere schors (`materials/bark.tres`).
- **De grond van dichtbij.** Aangestampte aarde is een egaal bleek korrelig vlak, zonder stenen, schuurplekken of sporen; het grijze duin is een groenige waas met een zachte rand; mos is nauwelijks als mos te herkennen; de bandafdruk is honderden meters lang dezelfde scherpe visgraat; helm is voorbij 85 m alleen een tint; de 2418 dennenappels kosten 72 duizend driehoeken.
- **Het midden van de binnenplaats is groot en leeg**; de ramen van het hoofdgebouw breken niet (`scripts/window.gd` neemt alleen een glasmesh van één oppervlak); een schot op een raam eindigt op de botsvorm van de muur, 24 cm voor het glas; het dak is alleen van boven te zien en niet af.
- **De betonplaten hebben geen botsvorm**: een stap op de weg klinkt als zand en een schot laat een kuiltje in zand achter. Het spel zou moeten weten waar platen liggen.
- **De veldstukken.** Een net is van de schaduwkant een donkere massa en van binnen twee meter zichtbaar getekend; de bunker is een blok met een betere schietspleet; het dak van de Nissenhut is twaalf vlakken; alle voertuigen van een soort zijn gelijk (de kentekens staan op het blad en zijn niet geplaatst); de voertuigen hebben geen model voor veraf (5276, 7397 en 8762 driehoeken), wat het wagenpark het zwaarst maakt.
- **De repetitie achter het zwart is te zien als het laden traag gaat**: zie "Onderweg gevonden". Het zwart zou moeten blijven tot de repetitie klaar is, op elk level; dat is `scripts/game.gd` en niet aangeraakt.
- **Alleen de speler laat afdrukken na**, en alleen op zijn eigen scherm: een vijand en een medespeler niet.
- **De meeuwen zijn stil**, zoals het hele level op de wind na.
- **De lucht is 4k**: 11 beeldpunten per graad, waar het scherm er 27 toont. Bij Poly Haven staat dezelfde lucht op 8k (CC0); niet opgehaald, want niet gevraagd.
- **De stofjes in de lucht** zijn op een stilstaand beeld bijna niet te zien. Of ze in beweging iets doen is niet beoordeeld; `scripts/air.gd` uit `scenes/dunes.tscn` halen is één knoop.
- **De worktrees en branches van de vier delen** (`duinbeeld-bomen`, `-grond`, `-veld`, `-complex`) en `duinbeeld` zelf staan er nog; alles ervan zit in de trunk. Opruimen wacht op Michiels woord.
- **Bij het afsluiten van het spel op Ultra blijven een compute-shader, een shader en een sampler achter** (`1 RID of type "Compute" was leaked`, in Michiels uitvoer). Het enige script dat een compute-shader maakt is `scripts/lens_fringe.gd`, dat hier niet is aangeraakt; het ruimt ze op bij `NOTIFICATION_PREDELETE`, en dat komt kennelijk te laat. Het proces stopt toch: onschuldig, en niet uitgezocht.
- De open punten van "De duinen: het vijfde level" die hier niet achterhaald heten, staan nog: wie om de tafel staat overlegt niet, de boogjes zijn er alleen voor wie host, de wachttoren is leeg, een robot klinkt in het zand als op beton, het navmesh meldt vier samenvallende randen, er is geen plattegrond van een level met land, en de muziek heeft niemand gekozen.

## Een ruw potje: stap 1 van de wedstrijden

Op 13 oktober 2026 gevraagd: verder met de bouw van de wedstrijden. Dit is stap 1 uit "Wedstrijden: teams, bots en een buit (plan)": een wedstrijd die te spelen is, alleen tegen bots, in team deathmatch en ieder voor zich. Gebouwd op de branch `potje`, vanaf de trunk met de duinen erin. De uniformen (2e, branch `uniformen`) zijn er op 13 oktober bij gekomen, op Michiels woord samen met deze stap in de trunk gezet: de tweede kant draagt het woestijnuniform. De buit (2d, branch `buit`) is er later die dag bij gekomen, toen capture the flag gebouwd werd.

**Wat er nu is**

- **Een wedstrijd is een tweede manier om een level te spelen** (`scripts/match.gd`, de autoload `Match`). Hij neemt het level over zoals de sandbox: de route staat uit, er staan geen robots, de uitgang blijft dicht, en wat het spel had opgeslagen staat opzij zolang hij open is. Starten kan met "Multiplayer" op het titelscherm (soort, arena, aantal, Start) of met `--match=<soort>:<level>:<aantal>`; `--only-bots` laat de speler toekijken.
- **Iedereen die meedoet is een deelnemer**, mens of bot, met een nummer, een naam, een kant en een stand. Een bot is de pop van een medespeler (`scripts/puppet.gd`) met een brein erin. Raken, doodgaan, terugkomen en tellen gaan voor allebei door dezelfde functie, `Match.harm()`: wie op dezelfde kant staat raak je niet, je eigen granaat raakt jou wel, en wie net terug is, is anderhalve seconde onkwetsbaar of tot hij zelf schiet.
- **De kanten staan op eigen botslagen** (9 en 10). Een schot zoekt alleen op de laag van de ander en gaat dus door je eigen team heen, en je loopt door teamgenoten heen en tegen de ander aan. Bij ieder voor zich staat iedereen op één laag.
- **Team deathmatch en ieder voor zich** zijn elk een bestand in `scripts/modes/` naast `mode.gd`, dat zegt wat twee teams doen; de getallen staan in `assets/match.json` (50 punten of 10 minuten, terug na 3 s; 25 punten, terug na 2 s). Health komt na vijf seconden zonder treffer helemaal terug, wie terugkomt heeft waarmee een level begint, en wie valt laat een halve minuut een blik munitie liggen.
- **De bots** (`scripts/bot.gd`, de eerste versie) lopen naar de dichtstbijzijnde vijand die ze kennen en schieten als ze er een zien. Kennen is: gezien (binnen 110° voor zich, met een vrije lijn naar hoofd of borst), gehoord (een schot zover het draagt) of door geraakt. Een bot draagt één wapen van de speler, verdeeld over zijn kant (karabijn, pistoolmitrailleur, shotgun, scherpschuttersgeweer), met de schade, de vuursnelheid en het magazijn van dat wapen; elk schot is een echte straal langs waar hij richt. Zijn richtpunt loopt een halve seconde achter zijn doel aan en zwerft er 2° omheen, en hij schiet 0,55 s na het zien: de kolom "Regular" uit het plan. Wie anderhalve seconde niet vooruitkomt, bedenkt iets anders, en dat wordt geteld.
- **Terugkomen** (`scripts/arena.gd`, de eerste versie): de plekken komen uit het navmesh zoals in de proef van het plan, en gekozen wordt de plek het verst van de dichtstbijzijnde vijand die geen vijand ziet en waar niemand staat. De twee kanten beginnen bij de twee plekken die in loopafstand het verst uit elkaar liggen (op het fabrieksterrein 219 m lopen en 58 m hemelsbreed, in de centrale 177 m: de getallen van het plan); bij ieder voor zich begint iedereen zo ver mogelijk van de rest. Wie neergezet wordt kijkt langs de eerste vier meter van de weg naar de ander, niet naar de muur waarachter die staat.
- **De wedstrijd wacht tot de wegzoeker het level kent.** `game.gd` meldt met het signaal `baked` dat het navmesh gebakken is, en de server die de wegen zoekt heeft het pas een of meer frames later; tot dan geeft hij lege wegen terug, ook als een level een navmesh uit de bouw meebrengt. Zonder dat wachten stonden op het fabrieksterrein beide kanten op één hoop en vielen er negen doden in de eerste twee seconden. In de fabriek ging het toevallig goed, en alleen daar keek de test; gevonden is het op een beeld van het spel.
- **In beeld** (`scripts/match_hud.gd`): bovenaan jouw punten in blauw, die van de ander in oranje, de soort, de stand waarbij gewonnen is en de klok; rechtsboven wie wie neerhaalde en waarmee; als je dood bent wie het deed en de tellen tot je terug bent; onder Tab de tabel; aan het eind VICTORY, DEFEAT of DRAW, met Enter voor nog een keer. Teamgenoten hebben hun naam in blauw boven het hoofd, ook door muren heen; een vijand heeft niets.
- **Wat er aan de gedeelde bestanden veranderd is**, zoals het plan het voor stap 1 opsomt: `game.gd` roept `Match` aan waar het de sandbox aanroept; `puppet.gd` heeft een kant, een hoofd dat geraakt kan worden, en kan door een brein bestuurd worden; `player.gd` een kant en een hoofd; `weapons.gd` zoekt in een wedstrijd ook op de laag van de ander en meldt wie schoot en waarmee; `blast.gd` en `grenade.gd` zeggen wie gooide; `Settings.rules()` geeft in een wedstrijd de regels van de wedstrijd; `net.gd` gaat naar twaalf spelers en versie 9 en heeft plaats voor de opzet van een wedstrijd; `menu.gd` één knop en één scherm; `project.godot` de autoloads, de twee lagen en Tab voor de tabel.
- **Twee fouten die er al zaten** en bij het wisselen van level boven kwamen: `game.gd` en `daylight.gd` wachtten een paar frames en gingen dan verder in een level dat al weg was, als de sandbox of een wedstrijd de speler meteen doorstuurde. Beide kijken nu of ze nog in de boom staan.

**Getest en gemeten**, 13 oktober 2026, M1 Pro op de accu, load 5 tot 10, terwijl een andere sessie op de GPU mat. Alles zonder GPU.

- `tools/test_match.sh`, 37 controles sinds de uniformen erbij zijn (de tweede kant draagt het woestijnuniform, de eerste het gewone): bots spelen in de fabriek drie tegen drie tot acht punten (20 tot 24 s wedstrijd, zes keer versneld), elke dood is één keer geteld en elke kill een punt, wie viel kwam terug en geen van hen stond binnen 8 m van een vijand; daarna nog een keer vanaf nul; daarna ieder voor zich met de speler erin: zijn schot telt, een bot kan hem neerhalen, hij staat drie tellen later weer in hetzelfde level, en zijn health komt helemaal terug; het menu start zes tegen zes op het fabrieksterrein, en daar staan de dichtstbijzijnde twee van verschillende kanten 51 m uit elkaar.
- `tools/selftest.sh` (401 controles), `tools/nettest.sh` (62), `tools/test_sandbox.sh` (30) en `tools/test_humanoid.sh` (55) slagen op deze stand, en opnieuw op de stand die in de trunk is gezet: met het beeld van de duinen en de uniformen erin.
- **Twaalf bots een minuut lang**, `tools/test_match.sh --match=tdm:works:6 --only-bots --soak=60`, twee keer: 36 en 33 doden, geen noodspawn, geen bot vast. In de centrale ieder voor zich met twaalf, twee keer: 73 en 71 doden, niemand vast. Daar valt er elke seconde iemand: twaalf beginnen er op 8 tot 16 m van elkaar, in zicht.
- **Wat het de processor kost.** Het denken en lopen van twaalf bots samen: 30 tot 41 ms per seconde wedstrijd, 0,3 ms per stap van de physics (120 per seconde), waarvan ruim de helft het verplaatsen van het lijf. De hele stap duurde op het fabrieksterrein met twaalf vechtende bots gemiddeld 2,2 tot 3,6 ms (zeven keer gemeten) en met twee 1,1 en 1,3 ms (vier keer gemeten; de andere twee keer 4,8 en 6,0 ms met uitschieters van 155 ms, iets anders op de laptop). Die ruim één milliseconde verschil zit dus niet in de bots zelf; waar wel is niet uitgezocht. Het navmesh is het niet (0,01 ms). In de centrale zat in beide runs één stap van 0,44 s, kort na het begin; zonder die stap is het gemiddelde daar 3,9 ms. Wat die stap is, is niet uitgezocht: het opzoeken van dekking bij het laden ligt voor de hand, en dat gebruikt een wedstrijd nog niet.

**Wat er niet in zit, en bij welke stap het hoort**

- Bots die dekking nemen, terugtrekken, kennis delen, granaten gooien, en de vier niveaus: 2a. Er is nu één niveau.
- De rest van de spawnregels (een dood in de buurt, gevaar, teamgenoten dichtbij, niet de vorige plek, loten uit drie), de afleiding van bases, het keurmerk en het blad: 2b. Loopafstand naar de vijand telt nog niet: het is hemelsbreed.
- Het scherm zoals het plan het beschrijft (bots per kant instellen, onthouden wat je koos, niet meer spelers aanbieden dan een arena draagt), de signalen in het geluid, het teken dat flauwer wordt met de afstand: 2c.
- **Over het net.** Een wedstrijd wordt nu op één machine gespeeld: `Match.open()` verlaat een spel met anderen. De vorm is er wel naar (alles wat te zien is loopt via `Net.show`, de host zegt waar de bots zijn), maar een gast die een wedstrijd binnenkomt is niet gebouwd en niet getest: stap 4.
- De duinen staan niet in de lijst van arena's: te groot, en er is nog geen stuk van afgebakend. Met `--match=` kan het wel; boven de 1 200 plekken worden ze uitgedund.

**Wat ik niet kon beoordelen**

- **Of het leuk is, en of de bots te goed of te slecht zijn.** Er is geen potje gespeeld: alles hierboven komt uit tests zonder venster en uit drie losse beelden van het spel (de stand, de klok, wie wie neerhaalde en "Back in 1" staan waar ze horen). Vier treffers van een karabijn zijn dodelijk en een bot schiet een halve seconde nadat hij je ziet.
- **De blauwe naam boven een teamgenoot** heb ik niet in beeld gehad: op het ene beeld waar iemand naast de speler stond, lag hij er al.
- **Wat het op het volle scherm kost.** De meting uit het plan (om en om met een leeg level, 3456×2160 met MetalFX) is niet gedaan: de laptop stond op de accu en een andere sessie mat op de GPU.
- **Of er iets hapert als de eerste soldaat in beeld komt.** De poppen worden gemaakt terwijl het beeld opkomt, maar pipelines zijn niet geteld.
- **Hoe goed de twee kanten uit elkaar te houden zijn.** De tweede kant draagt het woestijnuniform van 2e en je eigen kant heeft een blauwe naam boven het hoofd; in een wedstrijd heb ik dat niet in beeld gehad.

**Nog open**

- Wie valt, verdwijnt zodra hij terugkomt: het lijk is de pop zelf. Bij drie tellen is dat te zien.
- Een bot ziet door ruiten en struiken heen wat de speler niet ziet, en andersom: hij kijkt alleen naar de wereldlaag.
- Een vat dat een bot of de speler raakt en dat iemand doodt, telt voor niemand.
- Het `Kills`-tellertje van de gewone HUD telt in een wedstrijd de kills van de speler; het doel van de route blijft leeg.

**Wat Michiel bekijkt**

- Spelen, zes tegen zes op het fabrieksterrein: "Multiplayer" op het titelscherm, of `GODOT_WINDOW=1 tools/godot.sh -- --play --match=tdm:works:6`
- Ieder voor zich met acht in de centrale: dezelfde regel met `--match=ffa:powerhouse:8`.
- Alleen kijken hoe bots het onder elkaar doen: `--only-bots` erachter.

## Twee uniformen: het tweede team in woestijnkleuren

Op 12 oktober 2026 gebouwd op de branch `uniformen`: stap 2e van "Wedstrijden". De vijf soldaten bestaan nu ook in een tweede uniform, zodat twee teams van dezelfde soldaten uit elkaar te houden zijn. Er is geen script van het spel voor aangeraakt, geen level herbouwd en niets gedownload: alles zit in `tools/characters/` en `assets/characters/`.

**Wat er staat**

- **Vijf personages erbij**: `soldier_01_desert` tot en met `soldier_05_desert`, de vijf soldaten in zand en kaki, samen 10,5 MB. Het thema `soldiers_desert` zet ze in zoals `soldiers` de gewone vijf inzet: dezelfde rollen, wapens en afstelling. Het staat tussen de andere thema's in het instellingenscherm, als "Soldiers Desert". De tabel onder "Personages" noemt ze nog niet.
- **Een look voor een uniform** (`tools/characters/looks.py`). `UNIFORMS` is een tabel met per uniform twee kleuren voor de stof en één voor de laarzen; een uniform erbij is een regel erbij. Er staan er drie in: `desert`, `woodland` en `night`. De look verft wat een soldaat draagt en bij zich heeft: uniform, vest en tassen, helmhoes, handschoenen en laarzen. Patroon en plooien blijven, als licht en donker: elke toon van de stof wordt de nieuwe kleur, zoveel lichter of donkerder. De twee kleuren liggen in vlekken van een hand groot over het lijf, in de ruimte uitgezet, zodat ze doorlopen over een naad en van de jas op het vest. Een donkere kleur krijgt zijn tonen verder uit elkaar, anders valt het patroon erin weg.
- **Wat niet geverfd wordt:** het gezicht met haar, ogen en mond, het glas van de stofbril, en blote handen en onderarmen. Op het hoofd gaat dat per eiland van de textuur: het gezicht is met zijn haar één eiland en is fel van kleur waar helm en bril grijs zijn, en glas is donker en glad. Elders gaat het op kleur: huid is fel en warm, en een plek is huid als wat eromheen ligt dat ook is. De huidtoon uit de wangen, waar `zombie` en `clown` mee werken, is hier niet gebruikt: bij `soldier_02` valt het meetpunt naast zijn wang en telt zijn uitrusting als huid, en bij `soldier_01` dekt die toon maar de helft van het gezicht.
- **De vlag is van de mouw**, en ook wat eronder en op de andere mouw genaaid zit: rang, naam en het embleem van de eenheid. De vlag wordt gevonden aan zijn rood en blauw op de bovenarm. Over het zakje waar hij op zit (van 5 cm boven het midden van de vlag tot 19 cm eronder en 7,5 cm naar weerszijden, op beide armen) komt stof van elders op dezelfde mouw, een vaste stap verderop in de textuur, zodat de korrel van het gedrukte patroon heel blijft. Bij opgerolde mouwen (`soldier_05`) houdt het op waar het patroon ophoudt. Per soldaat zijn dat 10 tot 15 duizend texels. Een andere landsaanduiding heb ik op geen van de vijf gevonden. Rang en naam zijn er nog, meegeverfd: het rangteken op de borst, en bij `soldier_04` zijn naam achter op de pet.
- **Alleen de verf verschilt.** `--route=repaint` (`tools/characters/repaint.py`) neemt een personage dat al door de route is geweest, laat Blender het alleen lezen, zodat de look weet waar elke texel op het lijf ligt, en zet de nieuwe kleurtextuur in een kopie van het bestand. Mesh, skelet, huid, UV-indeling, normal map en ruwheid zijn byte voor byte die van het origineel; dat is voor alle vijf nagegaan. Buiten de eilanden wordt de textuur helemaal met de nieuwe kleuren opgevuld (`atlas.flood`), zodat er van ver, in de kleine mipmaps, niets van de oude doorheen mengt.
- **Het vergelijkingsblad** `assets/characters/sheets/uniforms.jpg` met de getallen in `uniforms.json` ernaast, en het gereedschap dat het maakt (`tools/characters/uniform_sheet.py`).
- **De twee teams met hun wapens**, `assets/characters/sheets/uniforms_teams.jpg`: grunt, rusher en heavy van `soldiers` en van `soldiers_desert`, zoals het spel ze als vijand neerzet, richtend.

**Waarom niet opnieuw door de hele route**

De bronbestanden van Rocketbox staan niet op deze machine, dus het uniform moest uit de geïmporteerde `.glb` komen. `soldier_01.glb` nog eens door `tools/import_character.sh` sturen laat driehoeken en botten heel, maar pakt de UV-indeling opnieuw in en bemonstert daarbij alle drie de texturen opnieuw:

| | Origineel | Opnieuw door de route | `--route=repaint` |
|---|---|---|---|
| Driehoeken, botten | 14 723, 56 | gelijk, dezelfde namen en rusthouding | gelijk |
| Hoekpunten | 11 667 | 11 753 | 11 667 |
| Scherpte van de kleur (spreiding van de Laplace) | 9,9 | 7,3 | nieuwe verf op dezelfde texels |
| Scherpte van de normal map | 6,5 | 4,6 | dezelfde bytes |
| Scherpte van de ruwheid | 0,99 | 0,68 | dezelfde bytes |

Een kwart van de scherpte kwijt voor een andere kleur is geen ruil; vandaar de smalle route. Beide kosten twaalf seconden per soldaat, zonder het contactblad.

**Drie kandidaten, één gekozen: woestijn**

`soldier_01` is in alle drie de uniformen geprobeerd en naast het origineel in de fabriekshal gezet, op 5, 20 en 40 m, één keer onder de lamp aan het westeinde en één keer in de schaduw tegen de oostmuur. De beelden zijn genomen zoals er gespeeld wordt: 3456×2160, MetalFX, Ultra, `--scale=auto` (dat werd 50%). Elk beeld is twee keer genomen, met en zonder de figuren, zodat van elke figuur precies bekend is wat erachter staat. Gemeten is de gemiddelde kleur van een figuur op het scherm, van de laarzen tot onder de schouders, en de afstand daarvan in CIELAB tot het origineel en tot de muur erachter: 2 is naast elkaar net te zien, 10 is in één oogopslag duidelijk.

| | Woestijn | Bos | Nacht |
|---|---|---|---|
| Verschil met het origineel in het licht, op 5, 20 en 39,5 m | 25, 19, 16 | 17, 13, 9 | 19, 15, 10 |
| Verschil met het origineel in de donkere hoek, op 5, 20 en 39,9 m | 21, 16, 11 | 18, 12, 8 | 19, 12, 8 |
| Verschil met de muur erachter op 40 m, licht en donker (het origineel: 11 en 10) | 19 en 14 | 3,3 en 2,6 | 6,2 en 2,3 |
| Helderheid op 40 m, licht en donker (het origineel: 44 en 34, de muur: 35 en 26) | 52 en 39 | 36 en 29 | 34 en 28 |

- **Woestijn is op elke afstand en in beide lichten het verst van het origineel**, en het enige van de drie dat niet verdwijnt. Op 40 m in de donkere hoek zitten bos en nacht op 2,6 en 2,3 van de muur: op de grens van wat te zien is. Op het blad staan daar twee figuren en twee vage vlekken.
- **Bos en nacht verschillen van het origineel vooral doordat ze donker zijn**, en donker is in deze hal ook de achtergrond. Een team dat je niet ziet staan is geen eerlijk tweede team.
- **De nevel telt mee.** Tussen de camera en 40 m verderop hangt het stof van de hal in het zonlicht: de donkere muur gaat van helderheid 3 op 5 m naar 26 op 40 m, en in die sluier verdwijnen de donkere uniformen het eerst.
- **Woestijn valt meer op dan het origineel**: 19 tegen 11 van de muur in het licht, 14 tegen 10 in het donker. Het tweede team is dus iets makkelijker te zien dan het eerste. Een donkerder kaki trekt dat gelijk en kost verschil tussen de twee; het is één regel in de tabel.
- **Nacht was eerst marineblauw.** Blauw is in beeld de kleur van je eigen kant, dus een blauw uniform zou "mijn team" zeggen wie het ook draagt. Het is nu houtskoolgrijs, een fractie warm, omdat koel licht het anders weer blauw trekt.

Elke kandidaat is eerst op een eigen contactblad bekeken: gezicht onaangeroerd, vlag weg, patroon nog als camouflage te lezen, geen naden of spikkels waar de verf aan huid, riemen of bril raakt. Wat daarbij is bijgesteld: de eerste versie zette alleen de drie tonen van het patroon om en gaf drie keer hetzelfde uniform in een andere tint, vandaar de vlekken in twee kleuren; die waren eerst 30 cm groot en lazen als verfspatten, nu 13 cm; woestijn is een slag dieper van kleur gemaakt, wat het verschil met het origineel op 40 m in het donker van 8 naar 11 bracht; en bij `soldier_03` en `soldier_04` bleef eerst op één mouw staan wat eraf moest, omdat er op die mouw geen ruimte was om alles met één stap te bedekken. De proefpersonages van bos en nacht en hun contactbladen zijn daarna weer weggehaald; hun regels staan nog in de tabel, en het vergelijkingsblad trekt ze zelf even aan.

**De plekken van het blad**

In deze hal zijn vier mensen naast elkaar bijna nergens van 40 m helemaal te zien. Zonder GPU is elke halve meter van de hal geprobeerd, in elke richting, met stralen naar knie, heup en hoofd tegen de 315 botsvormen van het level: vijftien plekken, twaalf rond de lamp aan het westeinde en drie tegen de oostmuur. Daar staan de rijen, 70 cm uit elkaar, en de camera's kijken door de enige openingen die er zijn: in het licht tussen een stapel kisten en een poot van het bordes door (39,5 m), in het donker langs de pers en een kist (39,9 m).

De donkere hoek is niet overal even donker. Door het raam in de zuidmuur valt een streep zon op de oostmuur, die bij de eerste figuur van de rij over hoofd en schouders gaat (boven 1,45 m) en bij de tweede over de helm; de derde en vierde staan er helemaal onder. Verder naar het zuiden staat een kist ervoor. De donkerste twee plekken zijn daarom aan de kandidaten gegeven die kunnen verdwijnen, en gemeten is alleen wat bij alle vier in de schaduw staat: tot 1,3 m.

**Gemeten en getest** op 12 oktober 2026, M1 Pro. Tot een uur of tien op de accu (70%), daarna aan de lader; de beelden van het blad zijn aan de lader genomen. Er zijn alleen beelden gemaakt, geen beeldsnelheden gemeten: een soldaat in woestijnkleuren is dezelfde mesh met dezelfde soort materiaal en even grote texturen als het origineel. Load 2,8 tot 7; andere sessies testten en maten de hele avond, en de laatste GPU-runs hebben tot tien minuten op hun beurt gewacht.

- `tools/characters/check.gd`: alle vijf zonder aanmerkingen, met de driehoeken, lengte en ooghoogte van het origineel.
- `tools/test_humanoid.sh --enemies=soldiers_desert`: geslaagd, 52 controles.
- `tools/selftest.sh`: geslaagd, 315 controles in 4 minuten 26.

**Niet kunnen beoordelen**

- **Alles is stilstaand en in één hal bekeken.** Niet in beweging, niet in een gevecht en niet in een wedstrijd. Op het vergelijkingsblad staan ze zonder wapen, de armen langs het lijf; met wapen zijn ze alleen van dichtbij bekeken.
- **De andere levels.** Het depot ligt buiten, de centrale is donkerder, en in de duinen is de grond zand: daar kan juist het woestijnuniform wegvallen. Het blad zegt alleen iets over de fabriekshal.
- **Kleurenblindheid.** Het verschil tussen de teams is licht tegen iets donkerder en blauwgrijs tegen geelbruin, niet rood tegen groen, maar het is niet met een simulatie bekeken.
- **Of het patroon bevalt.** De vlekken zijn mijn keuze; het zijn dezelfde vlekken op alle vijf.
- **Wat er de eerste keer hapert.** De nieuwe personages gebruiken hetzelfde soort materiaal als de oude, dus nieuwe pipelines verwacht ik niet, maar geteld is het niet.

**Nog open**

- **De wedstrijd moet het thema nog kiezen**: wie in het tweede team zit, wordt uit `soldiers_desert` gecast. Dat hoort bij stap 1 en bij de pop van een medespeler (`scripts/puppet.gd`), niet bij deze stap.
- **Het eerste team houdt de vlag en het patroon van het Amerikaanse leger.** `tools/characters/build_uniforms.sh` kan het ook een eigen uniform geven, maar de gewone soldaten zelf zijn niet aangeraakt.
- **De twee uniformen delen niets.** Normal map en ruwheid van een soldaat staan in beide bestanden en worden twee keer geladen als beide teams op het veld staan. Delen kan als de texturen buiten de `.glb` komen te staan.
- **Wie een soldaat opnieuw bouwt** met `build_cast.sh`, bouwt daarna zijn uniformen opnieuw.
- Blauwe lenzen op een helm (de nachtkijker van `soldier_02`) worden meegeverfd; een rood lichtstaafje op een vest blijft rood.
- `woodland` en `night` staan in de tabel maar zijn niet gebouwd. Een uniform dat niet meer nodig is, gaat met de hand weg: vijf mappen, hun bladen, hun regels in het manifest en het thema.

**Werkwijze**

| Stap | Commando |
|---|---|
| De vijf soldaten in een uniform bouwen, met hun bladen, hun regels in het manifest en het thema `soldiers_<uniform>` | `tools/characters/build_uniforms.sh desert` (of `woodland`, `night`, of een regel die je in `UNIFORMS` zet) |
| Eén soldaat opnieuw | `tools/characters/build_uniforms.sh desert soldier_03` |
| Een personage anders schilderen zonder de rest aan te raken | `tools/import_character.sh assets/characters/<id>/<id>.glb <nieuw id> --route=repaint --look=<look>` |
| Het vergelijkingsblad opnieuw maken (twee runs op de GPU; wat niet gebouwd is wordt even aangetrokken en weer uitgedaan) | `tools/characters/uniform_sheet.py` |
| Andere personages naast elkaar zetten op dezelfde plekken | `tools/characters/uniform_sheet.py soldier_03 soldier_03_desert --name=soldier_03` |
| Het tweede team als vijand in de hal zien, richtend (zo is het blad met de twee teams gemaakt, één keer met `soldiers` en één keer met `soldiers_desert`, met de hand naast elkaar gezet) | `tools/benchmark.sh --quick --res=3456x2160 --upscaler=metalfx --quality=3 --scale=auto --enemies=soldiers_desert --spawn="res://scenes/enemy.tscn@-19,0,-3,-90,1,1;res://scenes/enemy_rusher.tscn@-19,0,-4.1,-90,1,1;res://scenes/enemy_heavy.tscn@-19,0,-5.2,-90,1,1" --at="-14.6,1.6,-4.2,90,-5"` |
| Testen dat ze de speler vinden, raken en sterven | `tools/test_humanoid.sh --enemies=soldiers_desert` |

**Voor Michiel om te bekijken**

- Het blad: `assets/characters/sheets/uniforms.jpg`. Zes beelden, het origineel links en de drie kandidaten ernaast, met onder elk uitvergroot beeld hetzelfde op de grootte van het scherm.
- De twee teams met hun wapens: `assets/characters/sheets/uniforms_teams.jpg`.
- De vijf in het gekozen uniform: `assets/characters/sheets/soldier_01_desert.jpg` tot en met `soldier_05_desert.jpg`, naast `soldier_01.jpg` tot en met `soldier_05.jpg`.
- Ertegen spelen, om ze in beweging te zien: `GODOT_WINDOW=1 tools/godot.sh -- --play --enemies=soldiers_desert`. Dat commando heb ik niet kunnen proberen, want het opent een venster; `--enemies=soldiers_desert` zelf is zonder venster getest.

## Het potje bijgesteld: wat Michiel er na het spelen van zei

Op 13 oktober 2026 speelde Michiel het ruwe potje en gaf zeven punten door. Dit is wat er per punt gedaan is, op de branch `potje`. Capture the flag staat in de sectie hierna.

**Wat er veranderd is**

- **De moeilijkheid telt nu in een wedstrijd.** Dat deed ze niet: een wedstrijd had één stel regels, wat er ook was ingesteld. `assets/match.json` heeft er nu drie, en `Settings.rules()` geeft in een wedstrijd die van de ingestelde moeilijkheid:

  | | Easy | Normal | Hard |
  |---|---|---|---|
  | Health komt vanzelf terug tot | 100 | 75 | 50 |
  | Wat er overblijft van wat een bot een mens doet | 75% | 90% | alles |
  | De bots | Recruit | Regular | Hardened |
  | Van zien tot het eerste schot | 1,1 s | 0,55 s | 0,35 s |
  | Hoe ver zijn richtpunt van het doel zwerft | 4,5° | 2° | 1,2° |
  | Tijd waarin zijn richtpunt het doel inhaalt | 1,0 s | 0,6 s | 0,4 s |
  | Blikveld | 90° | 110° | 120° |
  | Vuurt zo lang, en laat dan zo lang los | 0,35 s, 1,2 tot 2 s | 1 s, 0,4 tot 0,7 s | 1,6 s, 0,2 tot 0,4 s |
  | Bots die tegelijk op één mens schieten | 1 | 2 | allemaal |
  | Health begint terug te komen na | 3 s | 5 s | 5 s |

  Zo staat het na de tweede ronde hieronder; in de eerste was de Recruit 0,9 s, 3,5° en 0,9 s, en waren er geen stoten en geen grens aan wie tegelijk schiet.

  De niveaus van de bots staan in `assets/bots.json`, met de vierde uit het plan (Veteran) erbij voor later. Bots komen zelf tot dezelfde grens terug als een mens.
- **Twee schoten van een scherpschutter op easy.** Het geweer doet 70; op easy komt daarvan 52,5 aan, dus één treffer in het lijf laat je staan en de tweede niet; een schot in het hoofd (175, op easy 131) is er één. Dat gold op het lijf al, maar de bots richtten op de hals, 6 cm onder waar het hoofd begint, en hun richtpunt zwerft: een deel van hun schoten was dus een schot in het hoofd. Hoeveel is niet geteld. Ze richten nu op de borst, een halve meter onder de ogen.
- **Tegen wie je speelt** is de instelling "Enemies" die er al was, en die deed in een wedstrijd niets: de ander was altijd een soldaat. Nu is de andere kant (bij ieder voor zich: iedereen behalve jij) wie daar gekozen is: soldaten in het woestijnuniform, zombies, clowns, de blokkige zombies of de paspoppen. Ze dragen een wapen van de speler en lopen en rennen zoals iedereen: een zombie is hier een bot met het lijf en de stem van een zombie, niet de trage van de route. Robots kunnen niet dragen wat een speler draagt; staat de instelling daarop, dan zijn het soldaten. De keuze staat ook op het scherm "Multiplayer", als "Against", naast "Difficulty": het zijn dezelfde twee instellingen als onder Settings.
- **Sprinten gaat van 8,0 naar 7,2 m/s**, voor de speler overal in het spel, en voor de bots, die de snelheden van de speler nu uit `scripts/player.gd` lezen in plaats van ze over te schrijven. Lopen blijft 5,0.
- **Cellen die 25 health geven liggen in de arena**, zuinig: één per 250 plekken, ten minste één en hooguit vier (fabriek 1, fabrieksterrein 1, centrale 1, duinen 2), halverwege de twee uiteinden en zo ver mogelijk uit elkaar. Een cel blijft liggen tot iemand hem pakt en ligt er 45 seconden later weer. Boven de grens waartot health vanzelf terugkomt is dit de enige manier om erbij te krijgen. Alleen de speler raapt op; een bot niet.
- **De duinen zijn een arena.** De twee kanten beginnen 399 m lopen uit elkaar. Wat daarvoor nodig was: een arena houdt hooguit 500 plekken (in de duinen 491, om de drie; het opzoeken van de wegen kost daar 1,3 s bij het begin, tegen 6,5 s met alle 1 145), een bot die niemand kent loopt naar de helft van de ander in plaats van zomaar ergens heen, wie een vijand ziet zegt het zijn kant, een scherpschutter ziet 180 m ver (de anderen 40 tot 70), en in een arena langer dan 300 m draagt een kant twee scherpschuttersgeweren en één shotgun minder.
- **Een bot die geen weg kreeg bleef staan** zonder dat het als vastlopen telde: op een stuk navmesh dat nergens aan vastzit geeft de wegzoeker de plek zelf terug. Hij loopt dan recht op zijn doel af, wat hem van dat stuk af brengt.

**Tweede ronde, dezelfde dag.** Michiel speelde de bijgestelde stand: "heel vet", maar easy nog veel te moeilijk, en vijf tellen wegzijn te lang.

- **Terugkomen na 2 seconden**, in alle drie de spelsoorten (het was 3, 2 en 5).
- **Easy is op vier manieren zachter gemaakt**, omdat de schade niet verder omlaag kan zonder dat een scherpschutter drie treffers nodig heeft:
  - **Een bot vuurt in stoten.** Hij schoot door zolang hij zijn doel had: tien schoten per seconde uit een karabijn. Nu vuurt een Recruit 0,35 s en laat dan 1,2 tot 2 s los; een Regular 1 s en 0,4 tot 0,7 s; een Hardened 1,6 s en 0,2 tot 0,4 s. Met een langzaam wapen is een stoot één schot.
  - **Op een mens schieten er niet meer tegelijk dan de moeilijkheid toelaat**: één op easy, twee op normal, op hard iedereen die hem ziet. De anderen houden hun wapen op hem en wachten tot een van de schutters een seconde niet gevuurd heeft. Bots onderling kennen die grens niet.
  - **De Recruit is trager en wijder**: 1,1 s van zien tot schieten (was 0,9), zijn richtpunt zwerft 4,5° (was 3,5°) en haalt het doel in 1 s in (was 0,9).
  - **Health begint op easy na 3 s terug te komen**, niet na 5.
- **Een lading hagel uit de handen van een bot telt in het hoofd als in het lijf.** Anders kon een shotgun van dichtbij op easy in één schot doden (88 in het lijf, 131 met de hagel in het hoofd), en dat mag daar alleen het scherpschuttersgeweer.

Gemeten met de speler erin, stilstaand waar hij begon, drie tegen drie in de fabriek, negentig seconden, om en om met een kloon waarin easy stond zoals het was; de speler kan in die meting niet dood. Load 21 tijdens de laatste vier runs, alles zonder GPU:

| | Schade per seconde | De snelste honderd |
|---|---|---|
| Easy zoals het was (twee keer) | 17,9 en 95,0 | 0,2 en 0,1 s |
| Easy nu (vier keer, vóór de regel voor hagel) | 2,9 · 10,2 · 13,7 · 24,5 | 1,2 · 1,4 · 0,3 · 1,4 s |
| Normal nu (twee keer) | 45,5 en 61,7 | 0,2 en 0,1 s |
| Hard nu (twee keer) | 95,4 en 87,4 | 0,0 en 0,1 s |

Het loopt ver uiteen van run tot run: het hangt af van hoeveel van de drie de speler bereiken voor zijn eigen kant ze neerhaalt. De ene keer van 0,3 s op easy is een shotgun van dichtbij geweest, de aanleiding voor de regel hierboven; na die regel is niet opnieuw gemeten. Op normal en hard is de snelste honderd één lading hagel.

**Getest en gemeten**, alles zonder GPU, de laptop aan de lader, load 4 tot 8.

- `tools/test_match.sh`, 47 controles. Nieuw: de drie stellen regels; op easy laat één schot van het scherpschuttersgeweer in het lijf de speler staan en het tweede niet, en één in het hoofd is genoeg; health komt terug tot 50, 75 en 100; er ligt een cel tussen de uiteinden die blijft liggen; tegen zombies is de andere kant zombies met een wapen in handen en de eigen kant soldaten, ze leggen 5,5 m per seconde af en vechten (7 neergehaald, 5 verloren in 34 s); het scherm gaat langs soldaten, zombies en clowns en biedt geen robots aan; de duinen staan in de lijst.
- **Twaalf bots twee minuten in de duinen**, twee keer: 15 en 21 doden, geen noodspawn. Ze liepen 83 en 99 keer ergens tegenaan, zeven keer per bot: op het land klopt het navmesh niet overal met wat er staat. Ze komen er elke keer na anderhalve seconde uit, maar een tiende van hun tijd staan ze dus stil. Op het fabrieksterrein in twee minuten 38 doden en één keer vast.

**Wat ik niet kon beoordelen**

- **Of easy nu makkelijk genoeg is.** Na de tweede ronde krijgt een speler die stilstaat er gemiddeld een kwart van de schade van eerst en duurt de snelste dood een ruime seconde in plaats van een tiende; of dat genoeg is, zegt het spelen. Tussen easy en normal zit nu een factor vier tot vijf: normal en hard zijn op de stoten na niet zachter gemaakt.
- **Of 7,2 de goede sprint is.** "Ietsje trager" is tien procent geworden.
- **Zombies en clowns van dichtbij.** Op twee beelden van een potje in de fabriek staan drie zombies op twintig meter: ze rennen en richten als de anderen. Hoe een geweer in de handen van een zombie of een clown er van dichtbij uitziet heb ik niet gezien.
- **De duinen op het oog.** Geen beeld van gemaakt, en niet gemeten wat twaalf figuren daar kosten.

**Nog open**

- De regel voor health geldt in een wedstrijd. Op de route komt health terug tot 50, 35 en 25: dat is niet aangeraakt.
- Een bot ziet in de duinen door struiken en bomen heen.
- Een clown die op de route in paniek raakt doet dat hier niet, en de zware van een bezetting is hier even groot en even sterk als de rest.

## De buit: vlag, voetbal en banaan

Op 12 oktober 2026 gebouwd op de branch `buit`: stap 2d van "Wedstrijden: teams, bots en een buit (plan)". Wat twee teams elkaar afpakken, waar het thuis op staat en hoe iemand het draagt. De regels van capture the flag horen hier niet bij; die komen in stap 3. Niet in de trunk gezet.

**Wat er staat**

- **Drie buiten, elk met zijn standaard**, in code gebouwd (`tools/models/prizes.gd`):
  - een vlag op een mast van 1,95 m, met een doek van 90 bij 60 cm (1866 driehoeken), en een gegoten voet met een koker waar de mast 20 cm in staat (684);
  - een voetbal van tweeëndertig vlakken, 22 cm, met het net waarin hij gedragen wordt (2700 driehoeken, en 2544 voor het net), op een mat met een rubberen ring (480);
  - een banaan van 1,05 m met een lint en een strik (2164), op een kist van latten (300).
- **De kleur van het team** zit in een onderdeel `Team` van elk model: het doek, de vijfhoeken van de bal, het lint van de banaan, een band om de voet en om de koker, de rand van de mat, een lat rondom de kist. Het materiaal daarvan heeft een shader met twee instance uniforms, `team` en `teamed` (`shaders/team.gdshader`, en voor het doek `shaders/flag.gdshader`), zodat elk exemplaar zijn eigen kleur heeft op één materiaal. Van niemand is de bal zwart-wit, het doek grijs en het lint wit.
- **Het doek beweegt in de shader**: golven die naar het uiteinde lopen en onderweg groter worden, en een wind van 0 (het hangt langs de mast) tot 1 (het staat recht uit). Thuis waait het 0,72; op iemands rug hangt het af van hoe hard hij loopt. Op het doek staat een lichte chevron en verder niets: het is de vlag van geen land.
- **`assets/prizes.json`** noemt per buit het model, de standaard en drie manieren van zitten, elk als plek en draaiing: thuis op de standaard, op wie hem draagt, en op de grond. Daarbij hoe hij heet en hoe een zin hem noemt ("the banana"). **Een nieuwe buit is een model, een standaard en een regel in die tabel.**
- **`scripts/prize.gd`** (`scenes/prize.tscn`) is het huis van één buit: het staat waar de buit thuishoort, met de standaard, en de buit zelf is thuis, gedragen of gevallen. Het kent geen regels. Het zegt wie de buit aanraakt (`touched`), wie bij de standaard komt (`reached`) en dat er iets veranderd is (`moved`), en doet wat het gezegd wordt: `take()`, `drop()`, `send_home()`. Wie de wedstrijd leidt vraagt verder waar de buit is (`where()`), wie er nu bij staat (`within_reach()`, `at_stand()`) en hoe lang hij al ligt (`down_for`).
- **Dragen** doet de rig van de personages: `bear()` en `release()` in `scripts/humanoid_rig.gd`. Wat gedragen wordt hangt aan de heupen of aan de rug en gaat mee met dat bot, op zijn eigen maat, hoe groot het personage ook is. De banaan ligt schuin over de rug. De vlag en de bal hangen aan de heupen: wie aanlegt buigt zijn bovenlijf een graad of dertig voorover, en een mast die daaraan vastzit wijst dan naar voren over zijn hoofd. De heupen draaien bovendien mee met de benen, dus het doek wijst weg van waar hij heen loopt.
- **De speler van deze machine heeft geen figuur** en draagt de buit op zijn eigen lijf. Zelf ziet hij er alleen de schaduw van.
- **Wat onderweg mis kan gaan, gaat goed.** Een pop die van wapen wisselt wordt een nieuw figuur: de buit verhuist mee. Wie uit het level verdwijnt zonder los te laten: de buit komt neer waar hij stond.
- **Waar hij staat of ligt gloeit hij zwak** in de kleur van zijn team, zoals wat je opraapt: een licht zonder schaduw van 2,2 m.
- **De eerste keer.** Een buit laat alles wat hij kan worden één keer tekenen als hij in het level komt (`Fx.rehearse()`), dus bij het laden en niet als de eerste speler hem ziet.

**Het blad** `assets/prizes/sheets/prizes.jpg`, gemaakt door `tools/prize_sheet.py`: per buit thuis in de kleur van beide kanten, op een soldaat van voren, van links en van achteren, en gevallen naast zijn standaard.

**Getest.** `tools/test_prize.sh`, 86 controles, zonder venster: elke buit uit de tabel staat in de hal van de fabriek, in de kleur van zijn team; wie erheen loopt raakt hem aan en staat bij de standaard; hij is te pakken en gaat mee, op de rug, en is daar niet aan te raken; het doek staat verder uit naarmate de drager harder loopt; hij valt op de vloer waar de drager stond, telt hoe lang hij ligt en gaat naar huis; een pop draagt hem op zijn rig, op zijn eigen maat, houdt hem bij het wisselen van wapen, en laat hem achter als hij uit het level verdwijnt; de speler draagt hem op zijn eigen lijf. Daarnaast slagen `tools/selftest.sh`, `tools/test_humanoid.sh` en `tools/nettest.sh`.

**Gemeten** op 12 oktober 2026, M1 Pro op de accu, in de fabriek, met de buit eerst achter de speler neergezet, die zich dan omdraait. Geteld zijn de pipelines die tijdens het tekenen gemaakt worden, en het langste beeld van elke stap.

| | Vlag | Voetbal | Banaan |
|---|---|---|---|
| Zonder repetitie: bij het neerzetten, en bij de eerste aanblik | 0, 4 | 0, 2 | 0, 4 |
| Met repetitie: bij het neerzetten, en bij de eerste aanblik | 4, 0 | 2, 0 | 4, 0 |
| Gepakt, gevallen, weer thuis | 0 | 0 | 0 |
| Langste beeld met repetitie | 51 ms, bij het neerzetten | 14 ms | 16 ms |

- De repetitie doet wat ze moet doen: het werk verhuist naar het moment van neerzetten, en dat is in een wedstrijd het laden. Deze machine had alles al eens getekend; hoe lang het duurt op een machine die dat niet heeft, is niet gemeten.
- **Een pop die voor het eerst in beeld komt kost drie pipelines**, met of zonder buit. Dat is van de pop en niet van dit werk; in een wedstrijd met elf bots hoort het bij stap 1.
- Wat de buit per beeld kost is niet gemeten: een paar duizend driehoeken en één licht zonder schaduw.

**Buiten de bestanden van de opdracht geraakt:** `scripts/humanoid_rig.gd`, 51 regels erbij voor `bear()` en `release()`. Aan wat de rig al deed is niets veranderd.

**Werkwijze**

| Stap | Commando |
|---|---|
| De modellen opnieuw bouwen | `tools/build_model.sh prizes` |
| De buit testen | `tools/test_prize.sh` |
| Het blad opnieuw maken, of van één buit | `tools/prize_sheet.py [flag]` (`--run` voor een soldaat in de pas, `--compose` zonder opnieuw te fotograferen) |
| Eén buit in een level bekijken: 1 thuis, 2 gedragen, 3 gedragen in de pas, 4 gevallen; het eerste cijfer achter de komma kiest de buit, het tweede de kant | `tools/benchmark.sh --quick --spawn="res://scenes/prize.tscn@1.6,0,-1.5,0,1,2.21" --at="4.8,1.35,0.1,90,-3"` |

**Wat ik niet kon beoordelen**

- **Alles is stilstaand bekeken.** Of het doek mooi beweegt, of de bal aan de heup niet raar meedeint en of de banaan over de rug blijft liggen als iemand rent, moet in beweging blijken.
- Of een banaan van een meter grappig is of flauw.
- Er klinkt niets: pakken, vallen en thuiskomen hebben geen geluid. Dat is stap 2c.

**Nog open**

- **Het gaat nog niet over de lijn.** Wie de buit heeft, weet alleen de machine waar het gebeurt. Dat wacht op het nummer dat elke deelnemer in stap 1 krijgt, en op stap 4.
- **De vlag op de rug reikt bijna drie meter hoog.** Hij steekt door een deurpost en door het plafond van een gang. Hij botst nergens tegen, dus het is alleen te zien.
- De standaard botst ook nergens tegen: je loopt door de kist heen. Met een botsvorm staat hij de bots in de weg, want het navmesh kent hem niet.
- Wie zelf de buit draagt, ziet daar niets van in beeld.
- De buit voelt wie op de botslaag van de spelers staat (laag 2). Krijgen de teams in stap 1 elk een eigen laag, dan horen die erbij: `PLAYERS` in `scripts/prize.gd`.
- Wat valt, blijft liggen: een bal rolt niet.
- Wie achteruit loopt met de vlag, heeft het doek naar voren: de heupen staan dan andersom.
- Het net van de bal is alleen van dichtbij te zien, en de bal hangt links: van rechts gezien zit het lijf ervoor.

## Capture the flag: de eerste versie

Op 13 oktober 2026 zei Michiel dat capture the flag nog gebouwd moest worden. Het plan zette dat achter het brein van de bots (2a) en de arena (2b); dit is een eerste versie zonder die twee, op de branch `potje`, met de buit van 2d erin (de branch `buit` is daarvoor binnengehaald).

**Wat er nu is**

- **De regels** (`scripts/modes/ctf.gd`): elke kant heeft een buit op een standaard aan haar eigen uiteinde van de arena. Tegen de buit van de ander aan lopen is hem pakken. Wie hem draagt laat hem vallen waar hij neergaat; de kant van wie hij is brengt hem terug door hem aan te raken, en na twintig seconden gaat hij vanzelf. Een punt is de buit van de ander op je eigen standaard brengen terwijl de jouwe daar staat. Drie punten of twaalf minuten; een kill is geen punt; je bent vijf tellen weg en komt terug op de grond van je eigen basis, 6 tot 25 m lopen van je standaard.
- **De buit kies je**: vlag, voetbal of banaan, op het scherm "Multiplayer" (de knop "Prize", die er alleen bij capture the flag staat) of als vierde deel van `--match=ctf:works:6:banana`. De lijst komt uit `assets/prizes.json`: een buit erbij staat er vanzelf tussen.
- **De bots verdelen het werk**, in de volgorde waarin ze bij hun kant kwamen: halen, bewaken, halen, zwerven, halen, bewaken. Een haler loopt naar de buit van de ander, of met wie hem draagt mee. Een wachter staat op een vaste plek 4 tot 12 m van zijn standaard. Wie de buit heeft rent naar huis en vecht alleen met wie binnen 14 m komt. Ligt de eigen buit ergens, dan gaat de dichtstbijzijnde bot hem halen; loopt iemand ermee weg, dan gaan de wachters en de zwerver erachteraan. Wie ergens moet zijn, loopt door terwijl hij schiet in plaats van te blijven staan vechten: zonder dat stonden de halers van beide kanten halverwege tegenover elkaar tot er een viel.
- **In beeld**: onder de stand twee regels, van hun buit en van de jouwe: thuis, bij wie, of op de grond met de tellen tot hij teruggaat, en hoe ver weg. Boven elke buit staat YOURS of THEIRS, door muren heen. Wie de buit pakt, laat vallen, terugbrengt of scoort staat bij wie-wie-neerhaalde.
- **Een spelsoort kan nu meer dan tellen.** `scripts/modes/mode.gd` heeft er haken bij: wat er bij het begin in het level komt, wat er elke stap gebeurt, wat er gebeurt als iemand valt, waar iemand terugkomt, waar een bot heen moet, of hij haast heeft, en wat er onder de stand staat. `match.gd` weet niets van een buit; `Match.show_mode()` laat een spelsoort iets op elke machine doen. Een vierde spelsoort is weer één bestand.

**Getest**, zonder GPU.

- `tools/test_match.sh`, 75 controles na de tweede ronde (63 ervoor). Voor capture the flag: elke kant heeft een banaan aan haar eigen uiteinde in haar eigen kleur; je eigen buit thuis aanraken doet niets; tegen die van de ander aan lopen pakt hem; wie hem draagt laat hem vallen waar hij neergaat en die kill is geen punt; een eigen speler brengt hem terug door hem aan te raken; beide kunnen tegelijk weg zijn en dan scoort niemand; een buit die ligt gaat vanzelf naar huis, en wie daar met de andere stond te wachten scoort op dat moment; wie viel komt terug bij zijn eigen basis; het menu gaat langs de drie soorten en de drie soorten buit.
- `tools/test_prize.sh` van de buit slaagt met de wedstrijd erbij.
- **Bots onder elkaar.** In de fabriek, drie tegen drie: in vijf minuten is de buit 3 keer gepakt en één keer binnengebracht; in een andere run van tweeënhalve minuut 3 keer gepakt, 3 keer gevallen, 3 keer teruggebracht en niet gescoord; in een run van vier minuten is hij niet gepakt. Op het fabrieksterrein (zes tegen zes, vier minuten, 91 doden) en in de centrale (vier tegen vier, 69 doden) pakte geen bot de buit: de halers van beide kanten komen elkaar in het midden tegen. Het punt moet daar van de speler komen.

**Een fout die Michiel bij het spelen vond: de vlag ging mee de dood in.** Wie neerging liet de buit vallen waar hij lag, maar de speler had hem weer op zijn rug op het moment dat hij bij zijn basis terugkwam. Een buit vraagt de physics wie er binnen bereik is, en dat antwoord loopt een stap achter: de speler, die dood naast de buit lag, stond er nog in terwijl hij al verplaatst was, en gold op dat moment weer als meespelend. Een bot had het niet, want die verliest zijn botslaag als hij valt. De spelsoort kijkt nu zelf of iemand werkelijk bij de buit of de standaard staat (1,7 m over de vloer). De test speelt het na en zakte op de oude stand op precies dit punt: de speler pakt de vlag, gaat halverwege neer, komt terug bij zijn basis en de vlag ligt nog waar hij viel; een teamgenoot pakt hem over; de andere kant stuurt hem naar huis door hem aan te raken.

**Wat ik niet kon beoordelen**

- **Of het leuk is.** Niemand heeft het gespeeld. Ik heb één beeld gezien, van het begin: de stand, de twee regels over de buit, de banaan met het blauwe lint op zijn kist en YOURS erboven.
- **Hoe de buit eruitziet op de rug van wie hem draagt in een wedstrijd.** De bladen van 2d laten dat zien op een pop die stilstaat; in een potje heb ik het niet in beeld gehad. Bij de speler zelf hangt hij op zijn eigen rug, waar hij hem niet ziet.
- **De geluiden.** Pakken, terugbrengen en scoren lenen de geluiden van een granaat oprapen, munitie oprapen en een checkpoint. Eigen signalen, in twee of drie varianten om te kiezen, horen bij 2c.

**Nog open**

- De standaard staat op het uiteinde zelf, niet op "de meest beschutte plek met drie meter vrije vloer" uit het plan, en een basis heeft geen eigen grond buiten wat binnen 25 m lopen ligt.
- Wat de speler doet verandert niets aan wie wat doet: blijf je thuis, dan gaat er geen bot meer halen.
- De drager is voor iedereen altijd te vinden: de bots weten waar hij is, en de speler leest de afstand. Het plan wilde dat de tegenpartij hem alleen ziet als een van hen hem ziet.
- Een wachter staat stil met zijn gezicht waar hij toevallig heen keek.
- Op het fabrieksterrein is het één gang heen en dezelfde gang terug, zoals het plan al zei: een arena met drie wegen is stap 5.
- Meer voorwerpen als buit, en ze laden van buiten de build zodat vrienden ze ook krijgen: Michiels vraag van 12 oktober. De tabel en het menu zijn erop gebouwd; het laden van buiten de build niet.
- Over het net is niets hiervan gebouwd: stap 4.

## Een buit uit een beschrijving

Op 12 oktober 2026 vroeg Michiel om in het menu te kunnen kiezen uit allerlei voorwerpen als "vlag" van capture the flag, en om er een nieuw "makkelijk in te laden met een prompt" als hij met vrienden speelt. Op 14 oktober zei hij dat die prompt een opdracht aan Claude is, en dat het bovenop `potje` gebouwd mocht worden voordat dat in de trunk staat. Gebouwd op de branch `buitkeuze`, die van `potje` afstamt. **Niet in de trunk, en zonder `potje` kan het er niet in.**

**Wat er staat**

- **Een buit kan gemaakt worden op de machine waarop gespeeld wordt.** Zo'n buit is een map in `user://prizes/<naam>/` met `model.glb` en `prize.json`, en daarnaast `build.py` (het script dat hem maakte), `preview.png` en eventueel `sheet.jpg`. `scripts/prize.gd` leest die mappen naast `assets/prizes.json`, en doet dat opnieuw elke keer dat het scherm "Multiplayer" opent (`reread()`): een buit die gemaakt wordt terwijl het spel draait, staat er dan bij, zonder herstart en zonder nieuwe build. Een map zonder model of met de naam van een buit uit de tabel wordt overgeslagen, met een waarschuwing.
- **Het model is een `.glb`**, gelezen met `GLTFDocument` terwijl het spel draait, dus ook in de gebouwde versie. Een `.glb` kan geen code bevatten, een `.scn` wel. Dat telt zodra een host zijn buiten naar gasten stuurt.
- **De kleur van het team** krijgt elke mesh waarvan de naam met Team begint, net als bij de drie buiten uit de tabel. Die mesh krijgt het materiaal van een team (`team_paint`, `team_ribbon` of `team_leather`, te kiezen in `prize.json`), zodat dezelfde instance uniforms hem kleuren.
- **Hoe de buit zit, volgt uit zijn maat** voor zover `prize.json` het niet zegt. Thuis staat hij midden op zijn standaard en gevallen rechtop waar hij viel. Gedragen hangt hij als een rugzak: het midden 22 cm onder het borstbot, de voorkant 12 cm erachter, en wat dieper is dan breed wordt een kwartslag gedraaid zodat de brede kant tegen de rug ligt. `prize.json` mag ook alleen een draaiing geven; de plek wordt dan berekend met die draaiing erbij. De standaard is een van die uit de tabel, standaard de stip met de ring; een eigen standaard als `.glb` kan ook.
- **Het scherm.** "Prize" op het scherm "Multiplayer" opent een lijst van alle buiten; achter die van deze machine staat "made here", en wie er een kiest gaat terug met die buit gekozen. De keuze blijft bewaard (`Settings.prize`). Hij staat op het scherm van de wedstrijd en niet onder Settings, waar Michiel hem eerst vroeg: daar staat ook de rest van wat bij een wedstrijd hoort, "Against" en "Difficulty" inbegrepen.
- **Het maken.** `tools/prizes/kit.py` is een werkplaats in Blender, zonder venster. Een vorm is een afstandsveld (bollen, staven, blokken en ringen die in elkaar overlopen, zoals de handschoen van de schutter gemaakt is) of is gemaakt van gedraaide profielen, blokken, buizen en ringen. `save()` zet het voorwerp op de grond, exporteert het, schrijft `prize.json` en maakt op de processor een beeld naast een figuur van 1,8 m. `tools/make_prize.sh <script>` doet dat en controleert de buit daarna zoals het spel hem toont (`tools/prize_check.sh`). Het rekenen kost zo'n tien seconden en geen GPU, dus het kan terwijl Michiel speelt.
- **`/buit`**, een skill in `.claude/skills/buit/SKILL.md`, beschrijft voor elke sessie in dit project de stappen, de maten en wanneer de GPU niet gebruikt mag worden. Michiel typt wat hij wil, de sessie schrijft het script, maakt de buit, bekijkt het beeld en zegt waar hij te kiezen is.
- **`tools/prize_sheet.py`** neemt de gemaakte buiten mee. Het blad van één gemaakte buit komt als `sheet.jpg` in zijn eigen map. Voorbij de tiende buit staan de tientallen vóór de pose: `12.21` is de twaalfde op iemands rug.
- **Drie voorbeelden**, gemaakt zoals de skill het zegt en neergezet in de `user://prizes/` van Michiel: een badeend van 83 cm met een kraag in de teamkleur, op de stip; een pylon van 75 cm met twee banden in de teamkleur; een beker van 67 cm met een band om de voet, op de kist. De scripts staan in `tools/prizes/`.

**De bladen** `assets/prizes/sheets/made_prizes.jpg` en `made_prizes_run.jpg`: de drie voorbeelden in de hal van de fabriek, thuis in de kleur van beide kanten, gedragen door een soldaat die stilstaat of rent, en gevallen.

**Gevonden onderweg: de wedstrijdtest schreef de instellingen van Michiel.** In de test gaan de knoppen "Against" en "Difficulty" langs hun keuzes, en `Settings.put()` slaat die op in `user://settings.cfg`. Alleen de selftest en de benchmark werden daarvan uitgezonderd. Na elke run van `tools/test_match.sh` stond de moeilijkheid in zijn bestand dus op Hard en zijn tegenstander op wat de test als laatste had gekozen. Nu slaat geen enkele test meer instellingen op (`Settings.testing()`). Tests lezen gemaakte buiten uit een map van hun eigen checkout (`user://selftest/<checkout>/prizes`), zodat de buiten van Michiel niets veranderen aan wat een test telt.

**Getest**, zonder GPU, terwijl Michiel een deel van de tijd speelde. Load 3 tot 5.

- `tools/test_prize.sh`: 122 controles, waarvan 36 nieuw. Een gemaakte buit staat na de drie uit de tabel in de lijst. Een met de naam van een buit uit de tabel en een zonder model blijven weg. Wat later gemaakt wordt, verschijnt pas als er opnieuw gekeken wordt. Een gemaakte krat met een band doorloopt alles wat de drie andere ook doorlopen: thuis staat hij precies op de standaard, met de band in het materiaal van een team; hij wordt gepakt en hangt 12 cm achter het borstbot; hij ligt op de vloer, niet erin; hij hangt op een pop, verhuist mee bij het wisselen van wapen en valt neer als die verdwijnt.
- `tools/test_match.sh`: 77 controles, tegen 75 op `potje`. Nieuw: "Prize" opent een lijst met de vlag, de voetbal en de banaan, en wie er een kiest gaat terug met die buit gekozen en bewaard.
- `tools/selftest.sh`: 401 controles, evenveel als op `potje`. `tools/nettest.sh`: geslaagd aan beide kanten.
- De drie voorbeelden en een script van buiten het project door `tools/make_prize.sh`: per stuk tien seconden.
- Het bestand met de instellingen van Michiel is na de wedstrijdtest niet veranderd.

**Wat ik niet kon beoordelen**

- **Of het snel genoeg gaat op een avond met vrienden.** Het rekenen kost tien seconden, maar eerst moet het script geschreven worden en het beeld bekeken. Voor de drie voorbeelden was dat een paar minuten per stuk, waarvan het meeste bij het eerste.
- **Hoe ze er in beweging uitzien.** Op de bladen hangen de pylon en de beker rechtop op de rug van een soldaat die voorover rent, en van achteren zie je vooral de zwarte voet van de pylon. Of dat er gek uitziet of gewoon grappig, zie je pas in een potje.
- **Wat de eerste keer tekenen kost.** Een gemaakte buit heeft eigen materialen. De buit laat ze bij het neerzetten één keer tekenen (`Fx.rehearse()`), zoals de drie uit de tabel, maar ik heb niet geteld hoeveel pipelines dat zijn.

**Nog open**

- **Vrienden krijgen een gemaakte buit nog niet.** Wedstrijden over het netwerk bestaan nog niet (stap 4). Als ze er zijn, moet de host bij het begin van een wedstrijd de map van de gekozen buit meesturen: een `.glb` van een paar honderd kB en een `prize.json`. Een gast bewaart die in een map van die host.
- **Een gemaakte buit zit niet in git en niet in de build.** Wil Michiel er een voor iedereen, dan gaat het script naar `tools/prizes/` en is er nog een manier nodig om het model met het spel mee te leveren.
- **Kantelen.** Het spel rekent de plek uit met de doos rond het model, niet met de vorm zelf. Een draaiing om de verticale as gaat goed, maar een gekantelde buit zweeft of zakt een stukje weg.

**Werkwijze**

| Stap | Commando |
|---|---|
| Een buit maken uit een script, en controleren | `tools/make_prize.sh <script.py>` |
| Een buit controleren zoals het spel hem toont | `tools/prize_check.sh <naam>` of `tools/prize_check.sh <map>` |
| Het blad in het spel, alleen als niemand speelt | `tools/prize_sheet.py <naam>` (`--run` voor een soldaat in de pas) |
| De test | `tools/test_prize.sh` |
