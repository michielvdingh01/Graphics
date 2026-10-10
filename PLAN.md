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
| Geluiden uitsnijden en mengen volgens het manifest; haalt de pakketten op als ze ontbreken. Met een naam erachter alleen dat geluid opnieuw, met `--all` alles | `tools/build_sounds.py` |
| Een geluid horen zoals de game het afspeelt, door de bussen heen: één keer, of anderhalve seconde vuur met het aantal schoten per minuut erachter | `tools/hear.py rifle_shot 620` |
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
- De vijanden hebben geen stem, er is geen omgevingsgeluid, geen muziek en geen geluid van een schot dat langs je heen gaat.

## Moderne shooter-eisen (fase 4)

**Wat er staat**

- **Menu.** Titelscherm over het geladen level, levelkeuze, pauzemenu (Esc of Start) en een instellingenscherm. Alles is met muis, toetsenbord en controller te bedienen. `--play` slaat het titelscherm over.
- **Besturing.** Het titelscherm en het pauzemenu hebben een scherm Controls, met een knop die wisselt tussen muis, trackpad en controller. Voor de trackpad is er één toets bij gekomen: richten met Option (Alt), omdat een trackpad niet tegelijk een rechterklik kan vasthouden en klikken. Wapens wissel je daar met 1 tot 5, want scrollen met twee vingers is voor Godot geen muiswiel. Het scherm noemt C voor bukken en niet Ctrl: macOS maakt van een klik met Ctrl ingedrukt een rechterklik, dus gebukt vuren zou richten worden. Niet op een echte trackpad geprobeerd.
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
