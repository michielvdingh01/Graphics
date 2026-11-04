"""The three slop memes of the Unmuted match, drawn here as SVG: stickers for
the slop gun of the Slop Soldiers, die-cut with a white edge. Our own
drawings of the three, not pictures from the internet:

ballerina: Ballerina Cappuccina, a ballerina whose head is a cup of
cappuccino, on her toes with her arms up in a ring.
tung: Tung Tung Tung Sahur, a log of wood with big eyes, thin black arms and
legs, and a baseball bat over its shoulder.
bombardiro: Bombardiro Crocodillo, a crocodile that is a bomber: wings with
two engines, a tail with fins, and bombs under it.

tools/unmuted/stickers.py renders them to assets/unmuted/stickers/.
"""

INK = "#2a1c14"
LINE = f'stroke="{INK}" stroke-width="10" stroke-linejoin="round" stroke-linecap="round"'


def die_cut(art: str, size: int = 1024) -> str:
    """`art` on a canvas `size` square, with a white edge 26 wide round all of
    it and a thin grey line round that, as a sticker is cut out."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <defs>
    <filter id="cut" x="-10%" y="-10%" width="120%" height="120%">
      <feMorphology in="SourceAlpha" operator="dilate" radius="30" result="far"/>
      <feFlood flood-color="#b9b9b4"/>
      <feComposite in2="far" operator="in" result="rim"/>
      <feMorphology in="SourceAlpha" operator="dilate" radius="26" result="near"/>
      <feFlood flood-color="#ffffff"/>
      <feComposite in2="near" operator="in" result="edge"/>
      <feMerge><feMergeNode in="rim"/><feMergeNode in="edge"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <g filter="url(#cut)">
{art}
  </g>
</svg>
"""


def ballerina() -> str:
    skin = "#f2c4a4"
    pink = "#ff7fae"
    tutu = "#ffc2da"
    art = f"""
    <!-- Arms up in a ring over the cup. -->
    <path d="M430,520 C330,470 300,330 380,250 C420,210 470,200 500,205" fill="none" stroke="{INK}" stroke-width="44" stroke-linecap="round"/>
    <path d="M430,520 C330,470 300,330 380,250 C420,210 470,200 500,205" fill="none" stroke="{skin}" stroke-width="26" stroke-linecap="round"/>
    <path d="M594,520 C694,470 724,330 644,250 C604,210 554,200 524,205" fill="none" stroke="{INK}" stroke-width="44" stroke-linecap="round"/>
    <path d="M594,520 C694,470 724,330 644,250 C604,210 554,200 524,205" fill="none" stroke="{skin}" stroke-width="26" stroke-linecap="round"/>
    <!-- Legs: one on its toes straight down, the other bent with its toe at the knee. -->
    <path d="M492,700 L478,930" stroke="{INK}" stroke-width="46" stroke-linecap="round"/>
    <path d="M492,700 L478,930" stroke="{skin}" stroke-width="28" stroke-linecap="round"/>
    <path d="M540,700 C640,760 640,810 520,830" fill="none" stroke="{INK}" stroke-width="46" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M540,700 C640,760 640,810 520,830" fill="none" stroke="{skin}" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M462,915 L496,915 L490,985 L470,985 Z" fill="{pink}" {LINE}/>
    <ellipse cx="512" cy="833" rx="26" ry="18" fill="{pink}" {LINE}/>
    <!-- The bodice, and the tutu over the hips. -->
    <path d="M450,520 C440,600 455,650 470,690 L554,690 C569,650 584,600 574,520 C540,505 484,505 450,520 Z" fill="{pink}" {LINE}/>
    <path d="M300,700 C330,650 420,645 512,655 C604,645 694,650 724,700 C700,725 680,705 655,730 C630,705 610,735 585,712 C560,740 535,712 512,738 C489,712 464,740 439,712 C414,735 394,705 369,730 C344,705 324,725 300,700 Z" fill="{tutu}" {LINE}/>
    <path d="M330,690 C380,670 450,668 512,675 C574,668 644,670 694,690" fill="none" stroke="#ff9cc4" stroke-width="8"/>
    <!-- The saucer for a collar, and the cup for a head, with its handle. -->
    <ellipse cx="512" cy="508" rx="130" ry="30" fill="#fdf6ec" {LINE}/>
    <path d="M606,330 C700,330 700,440 600,440" fill="none" stroke="{INK}" stroke-width="44"/>
    <path d="M606,330 C700,330 700,440 600,440" fill="none" stroke="#fdf6ec" stroke-width="24"/>
    <path d="M392,300 L632,300 C628,400 600,470 560,492 L464,492 C424,470 396,400 392,300 Z" fill="#fdf6ec" {LINE}/>
    <ellipse cx="512" cy="300" rx="120" ry="34" fill="#c8915c" {LINE}/>
    <path d="M512,318 C480,298 482,280 500,282 C506,283 510,288 512,292 C514,288 518,283 524,282 C542,280 544,298 512,318 Z" fill="#fbecd8"/>
    <!-- Steam. -->
    <path d="M470,250 C450,225 490,205 470,175" fill="none" stroke="#ffffff" stroke-width="14" stroke-linecap="round"/>
    <path d="M550,250 C530,220 570,200 550,165" fill="none" stroke="#ffffff" stroke-width="14" stroke-linecap="round"/>
    <!-- A face on the cup: eyes shut with lashes, cheeks, a smile. -->
    <path d="M455,395 C470,410 490,410 502,395 M522,395 C534,410 554,410 569,395" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>
    <path d="M458,398 L448,388 M470,405 L464,394 M566,398 L576,388 M554,405 L560,394" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
    <circle cx="452" cy="428" r="16" fill="#ff9ab5" opacity="0.7"/>
    <circle cx="572" cy="428" r="16" fill="#ff9ab5" opacity="0.7"/>
    <path d="M492,440 C502,452 522,452 532,440" fill="none" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>
"""
    return die_cut(art)


def tung() -> str:
    wood = "#b5773f"
    dark = "#8a5428"
    light = "#e2b27a"
    art = f"""
    <!-- The bat over its right shoulder, behind the log. -->
    <path d="M720,690 L860,150" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>
    <path d="M708,688 L732,690 L888,160 C895,130 840,120 832,150 Z" fill="#e8c78f" {LINE}/>
    <path d="M714,700 L740,705" stroke="{INK}" stroke-width="22" stroke-linecap="round"/>
    <!-- Legs and feet. -->
    <path d="M440,800 L420,930 M584,800 L604,930" stroke="{INK}" stroke-width="22" stroke-linecap="round"/>
    <ellipse cx="402" cy="940" rx="52" ry="24" fill="{INK}"/>
    <ellipse cx="622" cy="940" rx="52" ry="24" fill="{INK}"/>
    <!-- The log: a rounded body, grain down it, rings on top. -->
    <path d="M330,240 L330,780 C330,830 694,830 694,780 L694,240 Z" fill="{wood}" {LINE}/>
    <path d="M380,320 C372,450 392,600 378,770 M450,300 C460,420 440,560 456,800 M590,310 C580,460 600,600 584,800 M646,300 C656,430 640,610 650,770" fill="none" stroke="{dark}" stroke-width="9" stroke-linecap="round"/>
    <ellipse cx="512" cy="240" rx="182" ry="58" fill="{light}" {LINE}/>
    <ellipse cx="512" cy="240" rx="120" ry="36" fill="none" stroke="{dark}" stroke-width="6"/>
    <ellipse cx="512" cy="240" rx="64" ry="18" fill="none" stroke="{dark}" stroke-width="6"/>
    <ellipse cx="512" cy="240" rx="14" ry="5" fill="{dark}"/>
    <!-- Arms: the left hangs, the right goes up to the bat. -->
    <path d="M336,520 C270,580 260,640 280,700" fill="none" stroke="{INK}" stroke-width="22" stroke-linecap="round"/>
    <circle cx="282" cy="708" r="22" fill="{INK}"/>
    <path d="M688,520 C760,560 760,640 726,690" fill="none" stroke="{INK}" stroke-width="22" stroke-linecap="round"/>
    <circle cx="724" cy="694" r="24" fill="{INK}"/>
    <!-- The face: big round eyes looking aside, brows up, a grin. -->
    <circle cx="440" cy="430" r="62" fill="white" {LINE}/>
    <circle cx="590" cy="430" r="62" fill="white" {LINE}/>
    <circle cx="462" cy="438" r="27" fill="{INK}"/>
    <circle cx="612" cy="438" r="27" fill="{INK}"/>
    <circle cx="472" cy="428" r="8" fill="white"/>
    <circle cx="622" cy="428" r="8" fill="white"/>
    <path d="M378,352 C400,328 470,330 490,350 M540,350 C560,330 630,328 652,352" fill="none" stroke="{INK}" stroke-width="16" stroke-linecap="round"/>
    <path d="M430,580 C470,630 560,630 600,580 C560,600 470,600 430,580 Z" fill="#5a2418" {LINE}/>
"""
    return die_cut(art)


def bombardiro() -> str:
    green = "#5f9a43"
    belly = "#c9d98a"
    wing = "#6f7d5a"
    metal = "#3f4636"
    art = f"""
    <g transform="translate(0,40)">
    <!-- The far wing, swept back, behind the body. -->
    <path d="M520,380 L640,380 L560,170 L478,170 Z" fill="#5c6849" {LINE}/>
    <path d="M500,250 L600,250 C616,250 616,282 600,282 L500,282 Z" fill="{metal}" {LINE}/>
    <ellipse cx="612" cy="266" rx="10" ry="56" fill="#ffffff" fill-opacity="0.5" {LINE}/>
    <!-- The tail: the crocodile's own, with fins on it. -->
    <path d="M300,470 C220,470 150,420 90,330 C150,360 210,390 290,400 Z" fill="{green}" {LINE}/>
    <path d="M150,360 L110,250 L190,250 L220,380 Z" fill="{wing}" {LINE}/>
    <path d="M150,400 L80,430 L120,470 L240,440 Z" fill="{wing}" {LINE}/>
    <!-- The body, with a pale belly, scales down its back and a cockpit. -->
    <path d="M240,440 C260,360 420,340 600,350 C700,356 760,380 790,420 L800,470 C760,520 640,540 470,540 C330,540 250,510 240,440 Z" fill="{green}" {LINE}/>
    <path d="M280,480 C380,530 640,530 780,470 C760,520 640,540 470,540 C340,540 270,515 280,480 Z" fill="{belly}"/>
    <path d="M330,372 l18,-22 l18,22 M390,362 l18,-24 l18,24 M450,356 l18,-24 l18,24 M510,354 l18,-24 l18,24" fill="#4c8034" {LINE}/>
    <path d="M560,360 C580,320 650,318 676,362 Z" fill="#a9d6f0" {LINE}/>
    <!-- The head: a long snout with teeth, a nostril, an eye on top. -->
    <path d="M760,400 C840,380 930,395 975,420 C985,440 970,452 950,452 L800,460 Z" fill="{green}" {LINE}/>
    <path d="M790,470 C860,470 930,466 960,458 C960,478 930,492 860,494 C820,494 796,488 790,470 Z" fill="{green}" {LINE}/>
    <path d="M806,458 l10,16 l10,-16 l10,16 l10,-16 l10,16 l10,-16 l10,16 l10,-16 l10,16 l10,-16 l10,16 l10,-16" fill="none" stroke="white" stroke-width="8" stroke-linejoin="round"/>
    <circle cx="950" cy="412" r="7" fill="{INK}"/>
    <ellipse cx="790" cy="380" rx="36" ry="30" fill="{green}" {LINE}/>
    <circle cx="795" cy="378" r="20" fill="#f4d23c" {LINE}/>
    <ellipse cx="798" cy="378" rx="5" ry="14" fill="{INK}"/>
    <!-- Bombs under the body, and feet tucked up as wheels are. -->
    <path d="M330,520 l-20,40 l30,-6 l6,20 l20,-36 Z M720,500 l-14,40 l26,-4 l8,18 l14,-38 Z" fill="{green}" {LINE}/>
    <path d="M300,560 C270,560 270,616 300,616 L380,616 L408,588 L380,560 Z" fill="{metal}" {LINE}/>
    <path d="M272,574 L246,556 L246,622 L272,604" fill="{metal}" {LINE}/>
    <path d="M660,556 C630,556 630,612 660,612 L740,612 L768,584 L740,556 Z" fill="{metal}" {LINE}/>
    <path d="M632,570 L606,552 L606,618 L632,600" fill="{metal}" {LINE}/>
    <!-- The near wing, swept back, an engine on it with its propeller, the roundel. -->
    <path d="M440,490 L640,490 L520,800 L370,800 Z" fill="{wing}" {LINE}/>
    <path d="M470,610 L620,610 C646,610 646,666 620,666 L470,666 Z" fill="{metal}" {LINE}/>
    <path d="M636,620 L664,638 L636,656 Z" fill="#c9c9c0" {LINE}/>
    <ellipse cx="668" cy="638" rx="14" ry="104" fill="#ffffff" fill-opacity="0.55" {LINE}/>
    <circle cx="455" cy="752" r="32" fill="#1f8a3a" {LINE}/>
    <circle cx="455" cy="752" r="21" fill="white"/>
    <circle cx="455" cy="752" r="10" fill="#d43a2c"/>
    </g>
"""
    return die_cut(art)


MEMES = {"ballerina": ballerina, "tung": tung, "bombardiro": bombardiro}
