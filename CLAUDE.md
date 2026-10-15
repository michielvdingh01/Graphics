# Graphics FPS

Een first-person shooter in Godot 4.7, gebouwd door meerdere agents tegelijk. `PLAN.md` is het logboek: wat er gebouwd is, wat het kostte en wat nog open staat. De trunk is `fase-2-vertical-slice`, niet `main`. Er wordt gewerkt op een MacBook en op een ASUS met Windows; wat op de ASUS anders gaat, staat onder "De ASUS".

## Werkafspraken

- **Eigen worktree, eigen branch.** Werk in `.claude/worktrees/<naam>` op een eigen branch vanaf `fase-2-vertical-slice`. Er bouwen andere agents tegelijk: kijk met `git worktree list` wat er loopt en blijf binnen de bestanden van je opdracht. Ongecommit werk in de worktree van een ander is van die ander.
- **Lees eerst** de secties van `PLAN.md` die je opdracht noemt.
- **Levels herbouwen en lightmaps bakken doet alleen de agent van "Kit-ruimtes".** Commit geen herbouwde scènes (`scenes/levels/`) en geen `.exr`, `.lmbake` of `*_bakes.json`.
- **Eén Godot tegelijk op de GPU.** Kijk met `ps` voor elke GPU-run, en meet een verschil om en om met de stand ervoor. Zie "Godot en de GPU" en "Meten".
- **Vraag voor je iets downloadt of installeert**, met bron, licentie en grootte, en blijf daarna binnen wat je vroeg.
- **`tools/selftest.sh` moet slagen voor je commit.** Commit op je eigen branch; niet mergen, niet pushen.
- **Schrijf** wat je bouwde, mat en niet kon beoordelen als eigen sectie in `PLAN.md`.
- **Sluit af** met wat Michiel zelf moet bekijken of beluisteren: per onderdeel één commando of één blad met voor en na. Hij oordeelt op het oog en op het oor: een geluid krijgt hij als `tools/hear.py <naam>`, niet als bestand.

## Een worktree opzetten

```sh
M=/Users/michielvandeningh/dev/Graphics
git -C $M worktree add $M/.claude/worktrees/<naam> -b <naam> fase-2-vertical-slice
cd $M/.claude/worktrees/<naam>
cp -cR $M/.godot .godot
git ls-files -z | while IFS= read -r -d '' f; do if [ -f "$M/$f" ] && cmp -s "$M/$f" "$f"; then touch -r "$M/$f" "$f"; fi; done
```

- De importcache `.godot` staat niet in git. Zonder de kopie importeert Godot zes minuten lang alles opnieuw, op alle cores; zonder de `touch -r` doet de editor dat alsnog, omdat uitgecheckte bestanden een nieuwe wijzigingstijd hebben. `cp -c` maakt een kloon die geen ruimte kost: de schijf zit bijna vol.
- Meldt een run `Unable to open file: res://.godot/imported/...`, dan mist de gekopieerde cache wat er later bij is gekomen. Kloon die bestanden uit de `.godot/imported/` van de worktree die ze maakte (`cp -c`). Zelf importeren kan ook, met `Godot --headless --path . --import`, maar lightmaps kosten daarbij minuten per stuk op alle cores: doe dat niet terwijl een ander meet.
- Wie nieuwe lightmaps of texturen in de hoofdcheckout voegt, kloont om dezelfde reden hun bestanden uit `.godot/imported/` mee. Elke nieuwe worktree begint met die cache.
- Een `cd` naar een andere worktree verplaatst je hele sessie daarheen. Kijk bij een ander met `git -C <pad>` en volledige paden.
- Elke checkout deelt dezelfde `user://` (`~/Library/Application Support/Godot/app_userdata/Graphics FPS/`): één `save.cfg` en één `settings.cfg`, die van Michiel. De tests blijven daarvan af en houden per checkout hun eigen bestanden bij onder `user://selftest/<checkout>/`.
- Geef je Michiel een build uit je worktree om te spelen, haal dan eerst de trunk binnen: een build die een instelling uit zijn `settings.cfg` niet kent, speelt anders dan hij gewend is en gooit die instelling weg zodra hij iets opslaat.
- Een branch van vóór 11 oktober 2026 kent het GPU-slot en de eigen testbestanden niet. Haal de trunk binnen voor je meet of test naast anderen.

## Godot en de GPU

- **Nooit een venster.** Wat de GPU nodig heeft start je met `tools/godot.sh [argumenten]` (`tools/benchmark.sh`, `tools/shots.sh`, `tools/zone_sheet.py`, `tools/level_cost.sh` en de bake doen dat al); al het andere draait `--headless`. `GODOT_WINDOW=1` alleen als Michiel een venster wil zien.
- **Het GPU-slot.** `tools/godot.sh` neemt voor elke run het slot van `tools/gpu_slot.sh` en wacht zolang een run uit een andere checkout het heeft; op stderr staat op wie. Een reeks die niet onderbroken mag worden houdt het slot in één keer vast: `tools/gpu_slot.sh sh -c '...'`. Wie na 30 minuten nog wacht, stopt met status 75.
- **Wat het slot niet ziet:** de editor van Michiel, het spel dat hij daaruit speelt, en een checkout van vóór het slot. Daarom toch `ps -axo pid,etime,args | grep '[G]odot'` voor elke GPU-run, niet één keer per taak: hij start en stopt meerdere keren per uur. Speelt hij (een tweede proces met `--path` naast de editor), doe dan het werk dat geen GPU vraagt. Een meting naast zijn spel halveert zijn beeldsnelheid en de jouwe.
- **Loopt een run vast** of meldt hij `timeout waiting for fence`: start geen GPU-werk meer, stop alleen je eigen proces op PID (nooit `pkill -f` op een patroon) en zeg het Michiel. Wat daarna gemeten wordt is niets waard tot het vastgelopen proces weg is; de vorige keer hielp alleen een herstart van de laptop.

## Meten

- **Om en om.** De cijfers schuiven een paar fps mee met hoe druk de laptop is. Te vertrouwen is alleen het verschil tussen twee standen die om en om gemeten zijn, een paar ronden lang: zet de stand ervoor in een tweede checkout ernaast (een worktree, of een kloon van je eigen worktree met `cp -cR`, zonder het bestand `.git`, waarin je de gewijzigde bestanden terugzet met `git show <commit>:<bestand>`). `tools/godot.sh` draait altijd het project van zijn eigen checkout.
- **Meet ook zoals hij speelt:** `--res=3456x2160 --upscaler=metalfx --quality=3 --scale=auto`. De tabellen in `PLAN.md` zijn op 1440p met FSR 2 op 67%.
- **Schrijf erbij** hoe de laptop erbij stond (`uptime`, wie er nog meer mat) en hoe vaak je mat. Tekenopdrachten en driehoeken hebben geen last van drukte, fps wel.
- **De eerste keer telt apart.** Wat voor het eerst getekend wordt kan seconden haperen. Tel de pipelines die tijdens het tekenen gemaakt worden, begin bij het titelscherm en geef een nieuw uiterlijk mee aan `Fx.rehearse()`.
- **Tests kosten ook rekentijd** en drukken de meting van een ander. Draai onder het bouwen het deel dat je raakt en de hele selftest pas voor de commit.

| Wat | Commando |
|---|---|
| De hele selftest (5 minuten) | `tools/selftest.sh` |
| Alleen gevechten, routes, beeld of wat stuk kan, of één level | `tools/selftest.sh --fights`, `--routes`, `--view`, `--breaks`, `--level=<level>` |
| Samen spelen, personages, de sandbox | `tools/nettest.sh`, `tools/test_humanoid.sh`, `tools/test_sandbox.sh` |
| Een wedstrijd van alleen bots, of twaalf een minuut lang | `tools/test_match.sh`, `tools/test_match.sh --match=tdm:works:6 --only-bots --soak=60` |
| Vaste standpunten meten, of alleen de beelden | `tools/benchmark.sh [--scene=res://scenes/<level>.tscn]`, `tools/shots.sh` |
| Een level zone voor zone, met keurmerk en contactblad | `tools/zone_sheet.py <level>` |
| Het spel zoals het gespeeld wordt, één beeld | `tools/godot.sh -- --play --snap=5 --at="x,y,z,draai,kantel"` |

De tests draaien zonder GPU en kunnen naast die van een andere checkout lopen. De rest van het gereedschap staat in de tabellen van `PLAN.md`.

## Bakken (alleen de agent van "Kit-ruimtes")

- `tools/build_level.sh <level>` bouwt de geometrie, `tools/bake_lightmaps.sh res://scenes/<level>.tscn` bakt wat sindsdien veranderd is; `--list` zegt alleen wat dat is. De handtekening per zone staat in `scenes/<level>_bakes.json` en hoort bij de lightmaps in dezelfde commit. Een gewijzigd materiaal, een gewijzigde textuur of een opnieuw geïmporteerd model ziet de handtekening niet: bak daarna met `--all`.
- **Een bake wil de GPU voor zichzelf.** Naast een andere Godot zijn beide vastgelopen, en elke Godot daarna. De bake houdt het GPU-slot vast zolang hij duurt, en weigert bovendien zolang er een Godot buiten het slot tekent, tenzij met `--anyway`. Gebruik dat niet naast het spel van Michiel.
- **Bak een zone die nog nooit gebakken is eerst alleen**, en geef elke bake een tijdslimiet. Een bake die blijft herhalen `Inconsistency found in triangulation while building BSP` komt niet klaar: zet de probes verder uit elkaar. Na een afgebroken bake is de `.exr` nieuw en de `.lmbake` oud: die zone moet opnieuw voor iemand ernaar kijkt.
- **Lightmaps staan in Git LFS** (`scenes/*.exr`, `scenes/*.lmbake`). Elke gewijzigde lightmap telt bij een push voor zijn hele grootte mee in de opslag bij GitHub; een account heeft 10 GiB. Faalt een push met grote bestanden op HTTP 400: `git -c http.postBuffer=524288000 push`.

## De ASUS

De ASUS draait Windows 11 met een RTX 4060 Laptop (8 GB) en 16 GB geheugen. Het gereedschap is hetzelfde en draait vanuit Git Bash; de shellscripts en `tools/*.py` start je zoals hierboven. Wat er anders is:

- **Waar het staat.** De hoofdcheckout is `C:\dev\Graphics`, de worktrees staan in `C:\dev\Graphics\.claude\worktrees\<naam>`. Godot 4.7.2 staat in `C:\dev\tools\godot\`, en de omgevingsvariabele `GODOT` wijst naar `Godot_v4.7.2-stable_win64_console.exe`: de console-versie geeft uitvoer en exitcode door. Verder Python 3.14 als `python3`, met `PYTHONUTF8=1`, ImageMagick 7 als `magick` (met librsvg voor SVG) en Git LFS.
- **Een worktree opzetten** gaat zonder `cp -c`, en de `touch -r`-lus doet `tools/match_times.py` in seconden in plaats van minuten:

  ```sh
  M=/c/dev/Graphics
  git -C $M worktree add $M/.claude/worktrees/<naam> -b <naam> fase-2-vertical-slice
  cd $M/.claude/worktrees/<naam>
  cp -R $M/.godot .godot
  tools/match_times.py $M
  ```

  De importcache is ongeveer een GB en wordt echt gekopieerd; er is ruimte genoeg.
- **Een venster, maar buiten beeld.** Windows kent de embedded modus niet. `tools/godot.sh` start Godot met een gewoon venster, en `GODOT_OUT_OF_SIGHT` laat dat onzichtbaar worden en van het scherm verdwijnen zodra het spel draait (`scripts/benchmark.gd`) of de editor bakt (`addons/bake_cli/plugin.gd`). De eerste vijf seconden of zo staat het wel in beeld, zonder de focus te nemen. Een schermafbeelding heeft de maat van `--res`. Een `--script` zonder spel erachter (`tools/level_cost.sh`) blijft in beeld. Na een bake zet `tools/bake_lightmaps.py` de layout van de editor terug (`.godot/editor/editor_layout.cfg`), zodat die niet onthoudt dat zijn venster buiten beeld stond.
- **Het GPU-slot** neemt `tools/gpu_slot.py`, want Windows heeft geen `lockf`. Het slot staat in `%APPDATA%\Godot\gpu-slot` en werkt verder hetzelfde.
- **Kijken wie de GPU gebruikt** gaat met `ps -W | grep -i '[g]odot'` in plaats van `ps -axo`. Een eigen proces stop je op PID met `taskkill //PID <pid>`, nooit op naam.
- **MetalFX bestaat er niet**: meet met `--upscaler=fsr2`. Het scherm is 1920×1080.
- **Wat de ASUS bouwt is niet wat de MacBook bouwt.** De meshes van een level dat op de ASUS gebouwd is, verschillen byte voor byte van die van de MacBook; twee keer bouwen op de ASUS geeft wel hetzelfde. Een lightmap past alleen op de meshes waarmee hij gebakken is, dus een level wordt op één machine gebouwd én gebakken. Commit op de ASUS geen herbouwde levels die op de MacBook gebakken zijn. `tools/build_check.py` meldt op de ASUS elk level van de MacBook als veranderd: vergelijk daar met een eigen bouw van vóór je wijziging.
- **`user://`** is `%APPDATA%\Godot\app_userdata\Graphics FPS\`.
- **Geluid** speelt `tools/hear.py` af met Windows zelf.
- **Tekst blijft LF** (`.gitattributes`), ook wat Python op Windows schrijft.
