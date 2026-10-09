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
- Een excenterpers en een draaibank van zes meter, in code opgebouwd (`_press` en `_lathe` in `tools/levels/factory.gd`), omdat er van grote machines geen gescande modellen zijn. De levelbouwer heeft daarvoor afgeronde blokken, omwentelingslichamen en slangen gekregen (`rounded_box`, `revolve`, `hose`). Samen zijn ze circa 26 duizend driehoeken; ze horen bij de gewone levelgeometrie en krijgen dus een lightmap. Blank staal, donker staal, rubber, messing en rode lak zijn materialen zonder eigen kleurtextuur. De werklamp van de draaibank brandt en boven de werkbank hangt een tl-buis, anders stond die hoek in het donker.
- Ook in code opgebouwd, omdat Poly Haven er geen modellen van heeft: zeecontainers van geperste panelen met deuren en sluitstangen (`container`, met `corrugated` voor het geperste staal), twee opslagtanks met mangat, peilglas, afsluiters, kooiladder en leidingwerk naar de wand (`_tank`), een bovenloopkraan met loopkat, haakblok, kabelslingers en hangende bediening (`_crane`), roldeuren van lamellen (`roller_door`), pallets van losse planken, ronde buisleuningen met schopplaat, werkplaatskasten en een rij kluisjes waarvan er twee openstaan (`cupboard`, `lockers`). De gedeelde bouwstenen staan in `tools/level_builder.gd` en gelden dus ook voor het depot.
- Al het gelakte staal (machines, containers, tanks, kraan, leuningen, leidingen) gebruikt één shader, `shaders/worn_paint.gdshader`: een laklaag in een kleur naar keuze over een gescande laktextuur, met roestplekken die strepen naar beneden trekken, afgebladderde randen die op de rand zelf blank zijn gesleten, en stof op wat naar boven wijst. De levelbouwer geeft daarvoor elk vlak mee hoe ver een punt van de rand ligt, verpakt in de vertexkleur (`_edge`). De ruis komt uit een procedureel masker in het manifest (`wear`), de roest uit een scan van Poly Haven.
- Vloerbelijning in de hal: een rijpad van de laaddeur naar de aanbouw met een aftakking naar de trap, zwart-gele randen om de pers en de draaibank, arcering voor de laaddeur en de schakelkasten, en opslagvakken langs de zuidwand. Een level beschrijft de belijning met `floor_line`, `floor_frame` en `floor_hatch`; de levelbouwer tekent daar één textuur van en de vloershader legt die over het beton en laat de verf slijten.
- Opschriften, gesjabloneerd met de bruggetjes die een sjabloon nodig heeft: nummers op de containers, de hijslast op de kraan, tanknummers, deurnummers op het perron van het depot en vaknummers op de vloer. De pers en de draaibank hebben een machinenummer, tekst op hun typeplaatje, de perskracht op de kop en waarschuwingsdriehoeken waar iets beweegt (soort `warning` in het manifest). Elk opschrift staat als decal in het manifest (soort `text`) en wordt gezet in het ingebouwde lettertype van de engine, dus zonder extra bestand; `label` plaatst het en `floor_text` schildert het mee in de vloerverf. Ze kosten geen meetbare rekentijd.
- De aanbouw is ingericht als het kantoor- en magazijngedeelte van een fabriek. De muren hebben een lambrisering: glansverf tot heuphoogte met een bies erboven en een donkere plint, afgebladderd waar karren en schoenen ertegen stoten en vuil vanaf de vloer (`shaders/dado_wall.gdshader`, materiaal `plaster_dado`; het kost geen geometrie). Beide kamers hebben een stalen kozijn met dubbele deuren die openstaan, met een ruitje, een schopplaat, klinken en scharnieren (`_door` en `_leaf` in `tools/levels/factory.gd`), en een nummerplaatje ernaast. Onder het plafond van de gang lopen een luchtkanaal van verzinkt plaatstaal met roosters en een kabelladder met kabels; vanaf de ladder komt een buis naar een schakelaar bij elke deur. Op de gangmuur hangt een prikbord. De scharnieren zitten aan de buitenkant van het kozijn, zodat een open deur de doorgang niet smaller maakt: die is precies zo breed als de robots nodig hebben.
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
- **Handgranaten.** Drie stuks, bij elk checkpoint aangevuld, met G of Y op de controller. De linkerhand laat het wapen los, wat een herlaadbeurt afbreekt; de granaat stuitert, rolt en gaat na 2,2 seconden af met dezelfde klap als een vat. Het model is in code gebouwd (`tools/models/props.gd`) en de HUD toont hoeveel er nog zijn.
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
| Levelgeometrie opnieuw genereren uit `tools/levels/<naam>.gd` | `tools/build_level.sh factory` of `depot` |
| Een bouwsteen van dichtbij bekijken zonder een level te bakken: alles wat in code is opgebouwd staat naast elkaar in de showroom (`tools/levels/showroom.gd`) | `tools/build_level.sh showroom`, dan `tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="-23,2.2,9,0,-5"` |
| Lightmaps bakken (nodig na elke geometrie- of lichtwijziging, 2 minuten). De bake drukt op de knop van de editor zelf en zet daarvoor eerst de 3D-weergave voor | `tools/bake_lightmaps.sh [res://scenes/depot.tscn]` |
| Alleen de lightmap van de zones bakken die veranderd zijn (de fabriek heeft er een per zone; het ketelhuis duurt een halve minuut) | `tools/bake_lightmaps.sh res://scenes/factory.tscn boiler,passage` |
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
| Alleen de routes door de levels testen, met een lijst van waar elke robot verschijnt: het deel om te draaien terwijl je aan een level bouwt (25 seconden) | `tools/selftest.sh --routes` |
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

## Moderne shooter-eisen (fase 4)

**Wat er staat**

- **Menu.** Titelscherm over het geladen level, levelkeuze, pauzemenu (Esc of Start) en een instellingenscherm. Alles is met muis, toetsenbord en controller te bedienen. `--play` slaat het titelscherm over.
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

- Vaten komen niet terug: wat is opgeblazen, is weg tot je doodgaat of het level opnieuw begint. Na een herstart bij een checkpoint staan ze er allemaal weer, ook in het deel dat al is opgeruimd. Granaten krijg je bij elk checkpoint opnieuw.
- Robots weten niets van vuur en granaten: ze lopen door een brand heen en blijven naast een brandend vat staan. Dat maakt de vaten nu vooral een wapen van de speler.
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

- **De route staat in het levelbestand**, naast de geometrie (`_route_through` in `tools/levels/<naam>.gd`): `route_start`, `route_zone`, `route_checkpoint` en `route_exit`, in de volgorde waarin de speler ze tegenkomt. De levelbouwer zet ze in de levelscène onder `Route` en `scripts/game.gd` speelt wat daar staat. Route en gebouw veranderen zo samen: wie een muur verzet, verzet in hetzelfde bestand het spawnpunt erachter. De bouwer weigert een route zonder start of uitgang, een start die in een zone ligt en een checkpoint dat in een latere zone ligt. De met de hand geplaatste spawnpunten in `scenes/factory.tscn` en `scenes/depot.tscn` zijn weg.
- **Zones.** De robots die een zone opsomt staan er vanaf het laden, elk op zijn eigen post, met het gezicht naar waar de speler vandaan komt. Ze staan uit: ze zien niets en bewegen niet. Het gevecht om een zone begint wanneer de speler de zone binnenloopt of op een van zijn robots schiet; dan gaan ze allemaal aan. De zone is opgeruimd als de laatste ligt. Er verschijnt dus niets meer uit het niets: wat je straks tegenkomt, zie je al staan. Ze staan uit omdat een robot die aan staat op de speler afgaat zodra hij hem ziet, tot op 45 m; in de hal zou dan elk gevecht tegelijk beginnen. Waar de speler het level begint of bij een checkpoint verdergaat, staat er geen dichterbij dan 14 m in het zicht: dezelfde afstand die de waves aanhielden.
- **Checkpoints.** Een checkpoint is een plek met een gebied eromheen. Het telt zodra de speler in dat gebied staat, er geen gevecht loopt en alle zones die ervoor liggen zijn opgeruimd. Na een dood of een herstart van het spel sta je er weer, met wat ervoor ligt opgeruimd en met volle reservemunitie en granaten. De save bevat daarom alleen het level en de naam van het checkpoint: wat is opgeruimd, volgt uit waar het op de route ligt. Het begin van een level is het eerste checkpoint.
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
- Het spel leest van een robot ook `health` en `max_health`, om te zien dat er op hem geschoten is. Dat is meer dan de afspraak over vijanden noemt (het signaal `died`, `alert()`, `dead` en de groep `enemy`).
- De zon is gebakken. Als de laaddeur omhoog gaat zie je het voorterrein in de avondzon, maar op de vloer van de hal valt geen zonlicht naar binnen.
- De deur heeft geen eigen geluid: bij de lamp en als hij boven is klinkt `clang`. Achter de laaddeur ligt een leeg voorterrein met twee containers; meer dan een seconde zie je er niet van.
- Wie doorrent, stapelt gevechten: elke zone waar je doorheen loopt gaat aan, en de robots lopen de speler het hele level door achterna.
- De route is niet met de hand gespeeld. De selftest loopt hem af en kijkt of alles klopt, maar of de gevechten goed voelen, weet ik niet.

## Een level dat kan groeien: zones

De marge is 10 fps op 1440p met FSR 2, en het spel gebruikt er 3 van. Een level kan dus niet groeien door er meer in beeld te zetten, wel door ruimtes achter hoeken en deuren. Dat werkte niet zolang alles altijd werd getekend: al het gebakken levelwerk was één mesh, er was geen occlusion culling, en de lightmap van de fabriek was één bestand van 53 MB dat met elke ruimte groter zou worden. De levelbouwer knipt een level daarom nu in zones.

**Wat er staat**

- **Zones in het levelbestand.** Een level somt bovenaan zijn zones op (`zone` in `tools/level_builder.gd`): een naam, de dozen die de zone vult en welke andere zones je er vandaan kunt zien. Alles wat daarna gebouwd wordt, komt bij de zone waarin het staat: muren, props, lampen, decals, reflectieprobes, stof. Het levelbestand zelf hoefde daar nauwelijks voor te veranderen; alleen de vloer, die onder alles door liep, is per zone gelegd. Wat buiten elke zone valt (het terrein en de skyline) hoort bij geen en is er altijd. Een level zonder zones komt eruit zoals voorheen: de meshes van het depot zijn byte voor byte gelijk gebleven.
- **Alleen wat in het zicht is, wordt getekend** (`scripts/zones.gd`, dat de bouwer aan de levelscène hangt). Elk frame kijkt het in welke zone de camera staat en zet de inhoud van alle zones uit, behalve die zone en de zones die hij als zichtbaar opgeeft. Het werkt op de camera en niet op de speler, dus ook in de benchmark en achter het titelscherm. De schil van een zone die uit staat (zijn gebakken muren, vloer en dak) blijft schaduw werpen: anders scheen de zon door de deuropeningen de buurzone in. Een robot hoort bij geen zone, maar wie in een zone staat die uit is, staat achter dezelfde muren en wordt ook niet getekend.
- **Een lightmap per zone.** Elke zone heeft zijn eigen `LightmapGI` en zijn eigen bestand (`scenes/factory_<zone>.exr`). Een zone wordt gebakken met alleen zichzelf om zich heen, dus moet hij gesloten zijn met eigen muren, vloer en dak. De bake zet daarvoor zolang hij duurt een zwart paneel in elke deuropening (`bake_blocker`) en een kopie van de zon in de zone, want een bake kijkt alleen naar wat onder de ouder van zijn `LightmapGI` hangt. Wie een ruimte verandert, bakt alleen die ruimte.
- **De selftest zoekt zichtlijnen.** Vanaf elke plek waar de speler kan staan trekt hij lijnen naar punten door elke zone die daar uit staat (ruim een miljoen in de fabriek) en faalt bij de eerste die nergens op stuit. Zo kan een zone niet ongemerkt wegvallen terwijl je hem kunt zien. Ter controle heb ik de aanbouw de gang laten vergeten: 840 zichtlijnen en een falende test.
- **De fabriek in vier zones**: hal, aanbouw, gang en ketelhuis, op een rij. Hal en aanbouw zien elkaar door twee deuropeningen. De gang heeft een knik, zodat aanbouw en ketelhuis elkaar nooit zien, en de gang de hal niet. Wie in de hal staat, tekent dus hal en aanbouw, zoals voorheen; wie in het ketelhuis staat, alleen het ketelhuis en de gang.
- **Het ketelhuis** is de nieuwe ruimte: 12 bij 12 m en 7 m hoog, baksteen onder een betonnen dak, met de ramen op het noorden en oosten zodat de avondzon er niet in komt. Erin staan een vlampijpketel op zadels met brander, ventilator, manometers, peilglas, veiligheidskleppen, stoomleiding en rookkanaal door het dak (`_boiler` in `tools/levels/factory.gd`), een voedingstank, twee pompen met hun leidingwerk (`_pump`), een bord met meters (`_gauge_board`) en de schakelkasten. Het licht komt van één hallamp, een tl-buis, een peertje in de hoek en het vuur. De gang ernaartoe is 2,4 m breed. Samen 35 duizend driehoeken gebakken levelwerk, tegen 60 duizend voor de hal.
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
