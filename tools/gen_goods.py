#!/usr/bin/env python3
"""Draws what a supermarket sells: one sheet of labels and a list of products.

	tools/gen_goods.py            draws every cell that is not there yet
	tools/gen_goods.py --all      draws them all again
	tools/gen_goods.py --list     says how many products there are

Every product is a shape, a size in metres, what it is made of and a design.
The designs are made up, brands and all: nothing here is anybody's trademark.
Each is drawn with ImageMagick into a square cell of assets/goods/.cells/, not
in git, and the cells are laid out in assets/goods/goods_atlas.jpg. What the
game and the level builder want to know of a product goes into
assets/goods/goods.json, see scripts/goods_catalog.gd.

The cell is what is printed on the thing, and what the shape does with it is
in scripts/goods_shapes.gd: a box has it on its front and its back and the
left edge of it on its sides; what is round has it twice round, with the top
of the cell at the top; a bag has it on both sides; a fruit has it all over.
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/goods"
CELLS = OUT / ".cells"
CELL = 256
ACROSS = 16
FONTS = "/System/Library/Fonts/Supplemental/"
IMPACT = FONTS + "Impact.ttf"
BLACK = FONTS + "Arial Black.ttf"
ROUNDED = FONTS + "Arial Rounded Bold.ttf"
SERIF = FONTS + "Georgia Bold.ttf"
BRUSH = FONTS + "Brush Script.ttf"
COOPER = FONTS + "Rockwell.ttc"
NARROW = FONTS + "DIN Condensed Bold.ttf"

PRODUCTS = []


def add(id, shape, size, stuff, draw, liquid=None, shiny=0.5):
	PRODUCTS.append({"id": id, "shape": shape, "size": size, "stuff": stuff, "draw": draw, "liquid": liquid, "shiny": shiny})


# --- Drawing ------------------------------------------------------------------


def words(text, font, fill, box, stroke=None, weight=0, at=(0, 0), turn=0.0):
	"""The ImageMagick arguments that lay a word over the picture so far,
	filling `box` as far as it can, with its middle `at` from the middle."""
	args = ["(", "-background", "none", "-fill", fill, "-font", font, "-size", "%dx%d" % box]
	if stroke:
		args += ["-stroke", stroke, "-strokewidth", str(weight)]
	args += ["-gravity", "center", "label:" + text]
	if turn:
		args += ["-background", "none", "-rotate", str(turn)]
	args += [")", "-gravity", "center", "-geometry", "%+d%+d" % at, "-composite"]
	return args


def bands(*layers):
	"""Rectangles from the top: (height in pixels, colour)."""
	draw = []
	y = 0
	for height, colour in layers:
		draw += ["-fill", colour, "-draw", "rectangle 0,%d %d,%d" % (y, CELL, y + height)]
		y += height
	return draw


def ball(colour, at, across):
	return ["-fill", colour, "-stroke", "none", "-draw", "circle %d,%d %d,%d" % (at[0], at[1], at[0] + across // 2, at[1])]


def carton(colour, deep, ink, accent, brand, sub="", font=IMPACT, picture=None):
	"""A printed box: a sky behind the name, a ball of what is inside, a line
	of small print along the foot."""
	args = ["-size", "%dx%d" % (CELL, CELL), "gradient:%s-%s" % (colour, deep)]
	args += ball(accent, (128, 180), 120) if picture is None else ball(picture, (128, 180), 120) + ball(accent, (108, 164), 34) + ball(accent, (152, 196), 26)
	args += words(brand, font, ink, (232, 96), stroke="#00000055", weight=2, at=(0, -62), turn=-4)
	if sub:
		args += ["-fill", ink, "-draw", "rectangle 0,226 256,232"]
		args += words(sub, BLACK, ink, (216, 26), at=(0, 112))
	return args


def wrap(colour, band, ink, brand, sub="", font=IMPACT, cap="#d8d8d0", foot=None):
	"""What goes round a can or a jar: lid or rim, label, foot."""
	args = ["-size", "%dx%d" % (CELL, CELL), "xc:" + colour]
	args += bands((14, cap), (28, band), (172, colour), (28, band), (14, foot or cap))
	args += words(brand, font, ink, (240, 104), stroke="#00000044", weight=2, at=(0, -14))
	if sub:
		args += words(sub, BLACK, ink, (214, 30), at=(0, 62))
	return args


def bottle(cap, drink, label, ink, brand, sub="", font=IMPACT):
	"""A bottle from the top: cap, neck full of air or drink, label, shoulder
	and foot full of drink."""
	args = ["-size", "%dx%d" % (CELL, CELL), "xc:" + drink]
	args += bands((22, cap), (62, drink), (108, label), (64, drink))
	args += ["-fill", ink, "-draw", "rectangle 0,84 256,92", "-draw", "rectangle 0,184 256,192"]
	args += words(brand, font, ink, (236, 74), stroke="#00000044", weight=2, at=(0, 10))
	if sub:
		args += words(sub, BLACK, ink, (180, 16), at=(0, 44))
	return args


def foil(colour, deep, ink, accent, brand, sub="", font=IMPACT):
	"""A bag: shiny at the top and bottom seam, the name across, a burst."""
	args = ["-size", "%dx%d" % (CELL, CELL), "gradient:%s-%s" % (colour, deep)]
	args += bands((14, "#ffffff55"))
	args += ball(accent, (190, 178), 96)
	args += words(brand, font, ink, (232, 110), stroke="#00000066", weight=3, at=(0, -40), turn=-6)
	if sub:
		args += words(sub, BLACK, ink, (90, 40), at=(62, 50))
	return args


def jug(cap, body, label, ink, brand, sub=""):
	"""A jug of milk or of soap: a coloured cap, a body, a label."""
	args = ["-size", "%dx%d" % (CELL, CELL), "xc:" + body]
	args += bands((20, cap), (60, body), (120, label))
	args += words(brand, ROUNDED, ink, (226, 72), at=(0, -2))
	if sub:
		args += words(sub, BLACK, ink, (200, 34), at=(0, 54))
	return args


def skin(base, deep, speck="#00000030", grain=3, dimple=None):
	"""What grows: a colour that wanders, freckled."""
	args = ["-size", "%dx%d" % (CELL, CELL), "-seed", str(hash_of(base + deep) % 9999), "plasma:gray50-gray50", "-colorspace", "Gray", "-blur", "0x%d" % grain, "-auto-level", "-colorspace", "sRGB", "+level-colors", base + "," + deep]
	args += ["(", "-size", "%dx%d" % (CELL, CELL), "xc:none", "-seed", "7", "+noise", "Random", "-threshold", "96%", "-channel", "A", "-separate", "+channel", ")"]
	args += ["(", "-size", "%dx%d" % (CELL, CELL), "xc:" + speck, ")", "+swap", "-composite"]
	if dimple:
		args += ball(dimple, (128, 8), 56)
	return args


def hash_of(text):
	value = 0
	for letter in text:
		value = (value * 31 + ord(letter)) & 0xFFFFFF
	return value


def meat(lean, deep, fat, tray="#f2f0ea"):
	"""A cut in a tray under film: the tray round the edge, the cut with its
	fat, a sticker."""
	args = ["-size", "%dx%d" % (CELL, CELL), "xc:" + tray]
	args += ["(", "-size", "216x216", "-seed", str(hash_of(lean + fat)), "plasma:gray50-gray50", "-colorspace", "Gray", "-blur", "0x2", "-auto-level", "-colorspace", "sRGB", "+level-colors", lean + "," + deep, ")", "-gravity", "center", "-composite"]
	args += ["(", "-size", "216x216", "-seed", str(hash_of(fat)), "plasma:gray50-gray50", "-colorspace", "Gray", "-blur", "0x6", "-auto-level", "-threshold", "72%", "-colorspace", "sRGB", "-transparent", "black", "-fill", fat, "-opaque", "white", ")", "-gravity", "center", "-composite"]
	args += ["-fill", "#fbf6d8", "-stroke", "#a03020", "-strokewidth", "2", "-draw", "roundrectangle 150,186 240,240 6,6"]
	return args


# --- What is on sale ----------------------------------------------------------
# Sizes are width, height and depth in metres, as a thing stands on a shelf.

CAN = [0.066, 0.122, 0.066]
SOUP = [0.075, 0.102, 0.075]
TWO_LITRE = [0.112, 0.312, 0.112]
SMALL_BOTTLE = [0.066, 0.205, 0.066]
TWELVE = [0.27, 0.125, 0.21]
SIX = [0.2, 0.15, 0.135]
CEREAL = [0.2, 0.3, 0.06]
WINE = [0.076, 0.3, 0.076]
BEER = [0.062, 0.23, 0.062]
GALLON = [0.155, 0.255, 0.155]
JAR = [0.08, 0.125, 0.08]
TUB = [0.1, 0.075, 0.1]
TRAY = [0.21, 0.05, 0.15]
PIZZA = [0.29, 0.045, 0.29]
BAG = [0.2, 0.28, 0.075]
SACK = [0.3, 0.42, 0.11]
LOAF = [0.13, 0.12, 0.27]

SODAS = [
	("fizz", "#c8102e", "#7e0a1c", "#ffffff", "FIZZ", "COLA", "#1c0a06"),
	("dietfizz", "#c9ccd2", "#8c9096", "#c8102e", "FIZZ", "DIET", "#23120a"),
	("zap", "#2e9b3f", "#0f5a22", "#fff14a", "ZAP!", "LEMON LIME", "#c5e6b0"),
	("burst", "#f47a14", "#b84a06", "#ffffff", "BURST", "ORANGE", "#f08c1c"),
	("barrel", "#5a3214", "#2c1606", "#f2d28a", "OLD BARREL", "ROOT BEER", "#2a1206"),
	("gush", "#6a2c9a", "#3c1266", "#ffe14a", "GUSH", "GRAPE", "#3a0f52"),
	("bomb", "#b0123e", "#5e0620", "#ffc8d8", "CHERRY BOMB", "SODA", "#5a0a18"),
	("doc", "#7a1420", "#3e0810", "#ffd8a0", "DOC SPARK", "23 FLAVORS", "#301008"),
]
for key, colour, deep, ink, name, sub, drink in SODAS:
	add(key + "_2l", "bottle", TWO_LITRE, "pop", bottle("#e8e8e0" if key == "dietfizz" else colour, drink, colour, ink, name, sub), liquid=drink, shiny=0.75)
	add(key + "_12", "box", TWELVE, "card", carton(colour, deep, ink, "#ffffff44", name, "12 CANS " + sub), liquid=drink)
	add(key + "_can", "can", CAN, "can", wrap(colour, deep, ink, name, sub, cap="#c8ccd0"), liquid=drink, shiny=0.8)

add("spring_case", "box", [0.4, 0.22, 0.27], "card", carton("#c4e6f4", "#6cb6dc", "#0b4a80", "#ffffff66", "CLEAR SPRING", "24 BOTTLES"))
add("spring_bottle", "bottle", SMALL_BOTTLE, "pop", bottle("#3a8ad0", "#cfe8f2", "#2a78c0", "#ffffff", "CLEAR SPRING", "PURE WATER", ROUNDED), liquid="#bcd8e8", shiny=0.85)
add("spring_gallon", "jug", GALLON, "jug", jug("#2a78c0", "#d4ecf4", "#2a78c0", "#ffffff", "SPRING", "1 GALLON"), liquid="#bcd8e8", shiny=0.7)
for key, colour, ink, name in (("red", "#d81e2c", "#ffffff", "FRUIT PUNCH"), ("blue", "#1e6cd8", "#ffffff", "ARCTIC ICE"), ("lime", "#74d01e", "#123a02", "LIME RUSH"), ("orange", "#f49a14", "#3a1a00", "TANGERINE")):
	add("bolt_" + key, "bottle", [0.078, 0.22, 0.078], "pop", bottle(colour, colour, "#111418", colour, "BOLT", name), liquid=colour, shiny=0.75)
add("volt_can", "can", [0.058, 0.155, 0.058], "can", wrap("#101418", "#101418", "#c6ff1a", "VOLT", "ENERGY", cap="#90949a"), liquid="#d0e040", shiny=0.8)
add("oj_carton", "box", [0.095, 0.25, 0.095], "card", carton("#fff2c0", "#f8c040", "#d85a00", "#f49a14", "SUNNY GROVE", "ORANGE JUICE", SERIF), liquid="#f4a020")
add("apple_juice", "jug", [0.13, 0.24, 0.13], "jug", jug("#2e9b3f", "#c88a28", "#fff6dc", "#a02a14", "ORCHARD", "APPLE JUICE"), liquid="#c88a28", shiny=0.7)
add("grape_juice", "jug", [0.13, 0.24, 0.13], "jug", jug("#6a2c9a", "#3a0f52", "#fff6dc", "#6a2c9a", "ORCHARD", "GRAPE JUICE"), liquid="#3a0f52", shiny=0.7)

BEERS = [
	("hawk", "#123a6a", "#071c38", "#f2d28a", "LONE HAWK", "LAGER"),
	("river", "#a0261e", "#54100a", "#ffe8b0", "RIVER CITY", "PALE ALE"),
	("peak", "#d8dfe6", "#8ca0b4", "#143a6a", "SILVER PEAK", "LIGHT"),
	("stone", "#2c6030", "#123018", "#f6e6a0", "BIG STONE", "IPA"),
]
for key, colour, deep, ink, name, sub in BEERS:
	add(key + "_six", "box", SIX, "glass", carton(colour, deep, ink, "#ffffff22", name, "SIX " + sub), liquid="#c88a28")
	add(key + "_case", "box", [0.4, 0.19, 0.27], "card", carton(colour, deep, ink, "#ffffff22", name, "24 " + sub), liquid="#c88a28")
	add(key + "_bottle", "wine", BEER, "glass", bottle("#c8a040", "#3a1c08", colour, ink, name, sub), liquid="#c88a28", shiny=0.85)
for key, glass, label, ink, name, sub, drink in (
	("red_wine", "#1a2612", "#f0e6d0", "#5a0a18", "Sierra Vale", "CABERNET", "#4a0612"),
	("rose_wine", "#e8a0a0", "#fff4ec", "#a03048", "Golden Coast", "ROSE", "#e88a90"),
	("white_wine", "#b8c070", "#f6f0dc", "#3a4a1a", "Golden Coast", "CHARDONNAY", "#d8cc80"),
):
	add(key, "wine", WINE, "glass", bottle("#7a1420" if key == "red_wine" else "#c8a040", glass, label, ink, name, sub, SERIF), liquid=drink, shiny=0.85)

for key, colour, deep, ink, accent, name, sub, crumb in (
	("crunchers", "#f6c21a", "#d88a06", "#b4140e", "#fff08a", "CRUNCHERS", "SALTED", "#e8c060"),
	("crunchers_bbq", "#a8341a", "#5c1408", "#ffd24a", "#e86a1a", "CRUNCHERS", "BBQ", "#c88030"),
	("ridge", "#1c4ea8", "#0c2660", "#ffffff", "#ffd21a", "RIDGE KINGS", "SOUR CREAM", "#e8d090"),
	("tortilla", "#14763a", "#083c1c", "#ffe14a", "#e03a14", "TORTILLA TOWN", "NACHO", "#e8b040"),
	("cheezy", "#f26a0e", "#b43c04", "#ffffff", "#ffd21a", "CHEEZY PUFFS", "EXTRA", "#f08a1a"),
	("pretzel", "#6a3c18", "#361c08", "#f6e0a8", "#c8842a", "PRETZEL BARN", "TWISTS", "#a8682a"),
	("popped", "#e8e4d8", "#c4bca8", "#c8102e", "#f6d24a", "POPPED!", "BUTTER", "#f4e8b0"),
	("gummy", "#e0267a", "#8e0e4a", "#ffffff", "#40d0e0", "GUMMY WORMS", "SOUR", "#e0408a"),
	("corn_candy", "#f4d21a", "#f07a0a", "#ffffff", "#ffffff", "CANDY CORN", "HALLOWEEN", "#f49a14"),
):
	add(key, "bag", BAG, "bag", foil(colour, deep, ink, accent, name, sub), liquid=crumb, shiny=0.7)

for key, colour, deep, ink, accent, name, sub, crumb in (
	("frosty", "#1c8ad8", "#0c4a8c", "#ffffff", "#f6f0d8", "FROSTY O's", "CEREAL", "#e8d090"),
	("choco", "#5a2c10", "#2c1404", "#ffd24a", "#3a1c08", "CHOCO BOMBS", "CEREAL", "#3a1c08"),
	("honey", "#f6b81a", "#d8800a", "#6a2c08", "#c88a1a", "HONEY HOOPS", "CEREAL", "#d8a040"),
	("flakers", "#2e9b3f", "#116028", "#ffffff", "#f6d24a", "CORN FLAKERS", "CEREAL", "#e8c060"),
	("rings", "#e0267a", "#8e0e4a", "#ffffff", "#40c0e0", "FRUIT RINGS", "CEREAL", "#e86a9a"),
	("bran", "#8c5a2c", "#5a3414", "#fff0c8", "#c49a5a", "BRAN BUDS", "FIBER", "#6a4420"),
	("moons", "#2a2a8c", "#101050", "#ffe14a", "#f6f0d8", "MARSHMALLOW MOONS", "CEREAL", "#f0e8d0"),
	("squares", "#c8301a", "#7c1608", "#fff0c8", "#e8b060", "OAT SQUARES", "HEARTY", "#c8944a"),
):
	add(key, "box", CEREAL, "card", carton(colour, deep, ink, accent, name, sub), liquid=crumb)
add("oatmeal", "can", [0.125, 0.18, 0.125], "card", wrap("#c8301a", "#7c1608", "#fff0c8", "QUAKY OATS", "OLD FASHIONED", SERIF, cap="#d8c49a"), liquid="#d8c090")
add("pancake", "box", [0.16, 0.25, 0.07], "card", carton("#f6d24a", "#e88a1a", "#6a2c08", "#a85a14", "AUNT MAY'S", "PANCAKE MIX", SERIF), liquid="#f0e0b0")
add("syrup", "bottle", [0.075, 0.21, 0.075], "pop", bottle("#c82a1a", "#5a2406", "#f0e0c0", "#5a2406", "MAPLE TOWN", "SYRUP", SERIF), liquid="#5a2406", shiny=0.8)

for key, colour, band, ink, name, sub, inside in (
	("soup_chicken", "#d81e2c", "#f4f0e4", "#ffffff", "MA'S", "CHICKEN NOODLE", "#d8b860"),
	("soup_tomato", "#c0100e", "#ffffff", "#ffffff", "MA'S", "TOMATO SOUP", "#c02010"),
	("corn_can", "#e6c21a", "#1c7a30", "#1c4a10", "GREEN VALLEY", "SWEET CORN", "#e8c840"),
	("beans_can", "#1c7a30", "#f4f0e4", "#ffffff", "GREEN VALLEY", "CUT BEANS", "#5a8a30"),
	("peas_can", "#58a02a", "#114a10", "#ffffff", "GREEN VALLEY", "SWEET PEAS", "#70a030"),
	("baked_can", "#8c3a14", "#f6d24a", "#ffffff", "CAMPFIRE", "BAKED BEANS", "#8a3a12"),
	("chili_can", "#a81c0e", "#1a1a1a", "#ffd24a", "HOT TEX", "CHILI", "#7a2a10"),
	("peach_can", "#f49a54", "#a84a14", "#ffffff", "SUNNY GROVE", "PEACHES", "#f4b050"),
):
	add(key, "can", SOUP, "can", wrap(colour, band, ink, name, sub, cap="#c8ccd0"), liquid=inside, shiny=0.7)
add("tuna_can", "can", [0.085, 0.04, 0.085], "can", wrap("#1c4ea8", "#f4f0e4", "#ffffff", "SEA KING", "TUNA", cap="#c8ccd0"), liquid="#c8b890", shiny=0.7)

add("spaghetti", "box", [0.075, 0.27, 0.035], "card", carton("#1c4ea8", "#0c2660", "#ffffff", "#f6d24a", "NONNA", "SPAGHETTI", SERIF), liquid="#e8d090")
add("penne", "box", [0.13, 0.2, 0.06], "card", carton("#c8102e", "#7e0a1c", "#ffffff", "#f6d24a", "NONNA", "PENNE", SERIF), liquid="#e8d090")
add("mac", "box", [0.16, 0.11, 0.04], "card", carton("#1c5ad8", "#0c2c80", "#ffe14a", "#f49a14", "MAC & CHEESE", "THE CHEESY ONE"), liquid="#f4a020")
add("rice", "box", [0.13, 0.2, 0.06], "card", carton("#f6f0dc", "#d8c8a0", "#a01c14", "#ffffff", "UNCLE RAY'S", "LONG GRAIN", SERIF), liquid="#f0ead8")
for key, colour, band, ink, name, sub, inside in (
	("marinara", "#a81c0e", "#14642c", "#ffffff", "NONNA", "MARINARA", "#a81c0e"),
	("pickles", "#6a8a2a", "#f6d24a", "#123a02", "CRISPY JOE", "DILL PICKLES", "#a8b870"),
	("peanut", "#b8742a", "#c8102e", "#ffffff", "SKIPPER", "PEANUT BUTTER", "#b8742a"),
	("jelly", "#6a0f4a", "#f4f0e4", "#ffffff", "GRANNY'S", "GRAPE JELLY", "#4a0a4a"),
	("salsa", "#c8401a", "#14642c", "#ffffff", "HOT TEX", "SALSA", "#c0401a"),
):
	add(key, "jar", JAR, "glass", wrap(colour, band, ink, name, sub, cap="#e4e4dc"), liquid=inside, shiny=0.8)
add("ketchup", "bottle", [0.08, 0.235, 0.08], "pop", bottle("#ffffff", "#a8100c", "#f4f0e4", "#a8100c", "BIG RED", "KETCHUP"), liquid="#a8100c", shiny=0.8)
add("mustard", "bottle", [0.07, 0.2, 0.07], "pop", bottle("#d8200c", "#f0c40e", "#f0c40e", "#a81c0e", "YELLOW DOG", "MUSTARD"), liquid="#e0b40c", shiny=0.7)
add("mayo", "jar", [0.1, 0.15, 0.1], "glass", wrap("#f6f0dc", "#1c4ea8", "#1c4ea8", "CREAMY", "MAYONNAISE", cap="#1c4ea8"), liquid="#f4eed8", shiny=0.8)
add("bbq", "bottle", [0.08, 0.21, 0.08], "pop", bottle("#1a1a1a", "#4a1608", "#e8761a", "#1a0a04", "SMOKY PIT", "BBQ SAUCE"), liquid="#4a1608", shiny=0.8)
add("ranch", "bottle", [0.075, 0.2, 0.075], "pop", bottle("#14642c", "#f0ead8", "#f0ead8", "#14642c", "VALLEY", "RANCH"), liquid="#f0ead8", shiny=0.7)
add("oil", "bottle", [0.09, 0.3, 0.09], "pop", bottle("#d8a01a", "#d8b01a", "#14642c", "#ffffff", "GOLDEN", "VEGETABLE OIL"), liquid="#d8b01a", shiny=0.85)
add("olive", "wine", [0.07, 0.28, 0.07], "glass", bottle("#1a1a1a", "#3a4a12", "#f4ecd0", "#3a4a12", "Bella Terra", "OLIVE OIL", SERIF), liquid="#6a7a1a", shiny=0.85)
add("flour", "box", [0.17, 0.3, 0.1], "card", carton("#f4f0e4", "#dcd4c0", "#1c4ea8", "#c8a040", "BAKER'S GOLD", "ALL PURPOSE", SERIF), liquid="#f4f0e4")
add("sugar", "box", [0.15, 0.24, 0.09], "card", carton("#f4f4f4", "#d0dce8", "#c8102e", "#6cb6dc", "PURE CANE", "SUGAR"), liquid="#f8f8f4")
add("cakemix", "box", [0.14, 0.2, 0.05], "card", carton("#e0267a", "#8e0e4a", "#ffffff", "#5a2c10", "BETTY ANN", "DEVIL'S FOOD", SERIF), liquid="#5a2c10")
add("salt", "can", [0.09, 0.14, 0.09], "card", wrap("#1c4ea8", "#0c2660", "#ffffff", "SEA KING", "IODIZED SALT", cap="#d8d8d8"), liquid="#f8f8f4")
add("spice", "jar", [0.045, 0.1, 0.045], "glass", wrap("#a8541a", "#1a1a1a", "#fff0c8", "SPICE RACK", "PAPRIKA", cap="#c8102e"), liquid="#a8341a", shiny=0.8)
add("coffee_can", "can", [0.15, 0.17, 0.15], "can", wrap("#1a3a7a", "#c8a040", "#ffffff", "MORNING JOE", "DARK ROAST", SERIF, cap="#1a1a1a"), liquid="#2a1408", shiny=0.6)
add("coffee_bag", "bag", [0.12, 0.2, 0.07], "bag", foil("#3a1c08", "#180a02", "#f2d28a", "#c8842a", "MORNING JOE", "WHOLE BEAN", SERIF), liquid="#2a1408", shiny=0.6)
add("tea", "box", [0.14, 0.08, 0.07], "card", carton("#14642c", "#083c1c", "#f6e0a8", "#c8a040", "ENGLISH ROSE", "40 TEA BAGS", SERIF), liquid="#6a3c18")
add("cookies", "box", [0.21, 0.07, 0.11], "card", carton("#1c2c8c", "#0c1450", "#ffffff", "#2a1408", "CREME ROYALS", "SANDWICH COOKIES"), liquid="#2a1408")
add("chips_ahoy", "bag", [0.2, 0.19, 0.07], "bag", foil("#1c5ad8", "#0c2c80", "#ffffff", "#8c5a2c", "CHOCO CHUNK", "COOKIES"), liquid="#8c5a2c")
add("chocbar", "box", [0.1, 0.035, 0.02], "card", carton("#5a2c10", "#2c1404", "#fff0c8", "#c8842a", "CHOC-O-BAR", "", SERIF), liquid="#3a1c08")

add("tp", "box", [0.42, 0.24, 0.31], "soft", carton("#dceaf8", "#a8c8e8", "#1c4ea8", "#ffffff", "SOFT CLOUD", "12 MEGA ROLLS", ROUNDED), liquid="#f8f8f4")
add("towels", "box", [0.29, 0.28, 0.2], "soft", carton("#f4f0e4", "#c8e0a0", "#14642c", "#ffffff", "BIG SOAK", "6 ROLLS", ROUNDED), liquid="#f8f8f4")
add("trashbags", "box", [0.27, 0.13, 0.13], "card", carton("#1a1a1a", "#3a3a3a", "#f6d24a", "#c8102e", "HEAVY DUTY", "33 GALLON"), liquid="#1a1a1a")
add("foil", "box", [0.32, 0.06, 0.06], "card", carton("#c8102e", "#7e0a1c", "#ffffff", "#c8ccd0", "KITCHEN WRAP", "FOIL"), liquid="#c8ccd0")
for key, cap, body, label, ink, name, sub, inside in (
	("wash", "#f49a14", "#1c5ad8", "#ffffff", "#c8102e", "BRIGHT", "LAUNDRY", "#3a8ad0"),
	("wash2", "#ffffff", "#e8761a", "#1a1a1a", "#ffffff", "POWER", "LAUNDRY", "#f49a14"),
	("softener", "#ffffff", "#e8a0d0", "#ffffff", "#8e0e8a", "SNUGGLES", "SOFTENER", "#e8a0d0"),
	("bleach", "#1c4ea8", "#f4f4f0", "#1c4ea8", "#ffffff", "CLEAR", "BLEACH", "#e8e8dc"),
):
	add(key, "jug", [0.17, 0.3, 0.12], "jug", jug(cap, body, label, ink, name, sub), liquid=inside, shiny=0.6)
add("dish", "bottle", [0.08, 0.24, 0.05], "pop", bottle("#ffffff", "#1c8a4a", "#1c8a4a", "#ffffff", "SUDSY", "DISH SOAP", ROUNDED), liquid="#1c8a4a", shiny=0.7)
add("spray", "bottle", [0.09, 0.27, 0.06], "pop", bottle("#d8200c", "#40a0e0", "#ffffff", "#1c4ea8", "SPARKLE", "GLASS CLEANER", ROUNDED), liquid="#40a0e0", shiny=0.7)
add("shampoo", "bottle", [0.07, 0.21, 0.045], "pop", bottle("#c8a040", "#8c4ac8", "#8c4ac8", "#ffffff", "SILKEN", "SHAMPOO", SERIF), liquid="#b89ae0", shiny=0.7)
add("toothpaste", "box", [0.19, 0.05, 0.05], "card", carton("#c8102e", "#ffffff", "#ffffff", "#1c8ad8", "BRIGHT SMILE", "TOOTHPASTE", ROUNDED), liquid="#e8f4f8")
add("vitamins", "jar", [0.07, 0.12, 0.07], "pop", wrap("#f6f0dc", "#e8761a", "#c84a0a", "VITAL", "MULTIVITAMIN", cap="#ffffff"), liquid="#e8761a", shiny=0.7)
add("diapers", "box", [0.38, 0.27, 0.2], "soft", carton("#40c0e0", "#1c78b8", "#ffffff", "#f6d24a", "SNUG BABY", "SIZE 4", ROUNDED), liquid="#f8f8f4")
add("dogfood", "box", [0.4, 0.6, 0.14], "soft", carton("#c8301a", "#7c1608", "#ffffff", "#8c5a2c", "GOOD BOY", "BEEF DINNER"), liquid="#6a3c18")
add("catfood", "can", [0.075, 0.04, 0.075], "can", wrap("#8e0e8a", "#f6d24a", "#ffffff", "MISS KITTY", "SALMON", cap="#c8ccd0"), liquid="#a87050", shiny=0.7)
add("litter", "box", [0.3, 0.4, 0.14], "soft", carton("#2a7ab8", "#124a7c", "#ffffff", "#e8e4d8", "CLEAN PAWS", "CLUMPING"), liquid="#b8b4a8")

add("batteries", "box", [0.12, 0.18, 0.02], "card", carton("#1a1a1a", "#3a3a3a", "#f6d24a", "#d8761a", "LONGLIFE", "AA 8 PACK"), liquid="#3a3a3a")
add("bulbs", "box", [0.08, 0.13, 0.08], "glass", carton("#f6f0dc", "#f6d24a", "#1c4ea8", "#ffffff", "BRIGHT DAY", "60 WATT", ROUNDED), liquid="#f8f8f4")
add("charcoal", "box", [0.34, 0.46, 0.13], "soft", carton("#1a1a1a", "#3a2a1a", "#f49a14", "#c8301a", "KING COALS", "BRIQUETS"), liquid="#1a1a1a")
add("motoroil", "bottle", [0.1, 0.22, 0.06], "pop", bottle("#1a1a1a", "#1a1a1a", "#f6d24a", "#1a1a1a", "ROADMASTER", "10W-30"), liquid="#2a1c08", shiny=0.5)
add("candle", "jar", [0.08, 0.1, 0.08], "glass", wrap("#d8a0c0", "#f4f0e4", "#6a0f4a", "HOMEY", "VANILLA", SERIF, cap="#c8a040"), liquid="#d8a0c0", shiny=0.7)
add("tape", "box", [0.06, 0.06, 0.12], "card", carton("#90949a", "#5a5e64", "#ffffff", "#c8102e", "STICKS", "DUCT TAPE"), liquid="#90949a")

add("pizza_a", "box", PIZZA, "card", carton("#c8102e", "#7e0a1c", "#ffffff", "#f6d24a", "PIZZA PALACE", "PEPPERONI", picture="#e0a040"), liquid="#c02010")
add("pizza_b", "box", PIZZA, "card", carton("#14642c", "#083c1c", "#ffffff", "#c8102e", "BIG SLICE", "SUPREME", picture="#e0a040"), liquid="#c02010")
add("dinner", "box", [0.2, 0.05, 0.16], "card", carton("#1c2c8c", "#0c1450", "#ffffff", "#c8842a", "HUNGRY MAN'S", "TURKEY DINNER"), liquid="#c8a060")
add("waffles", "box", [0.2, 0.16, 0.05], "card", carton("#f6c21a", "#d88a06", "#a01c14", "#c8842a", "GOLDEN GRID", "WAFFLES", ROUNDED), liquid="#d8a040")
add("popsicle", "box", [0.2, 0.08, 0.14], "card", carton("#40c0e0", "#1c78b8", "#ffffff", "#e0267a", "ICY POPS", "12 COUNT", ROUNDED), liquid="#e0267a")
add("fries", "bag", [0.24, 0.32, 0.07], "bag", foil("#f6d24a", "#d88a06", "#a01c14", "#c8102e", "CRINKLE KING", "FRIES"), liquid="#f0d080")
add("frozen_peas", "bag", [0.18, 0.25, 0.05], "bag", foil("#2e9b3f", "#0f5a22", "#ffffff", "#a8d040", "GREEN VALLEY", "PEAS"), liquid="#70a030")
for key, colour, ink, name in (("vanilla", "#f6ecc8", "#7a1420", "VANILLA"), ("choc", "#5a2c10", "#fff0c8", "CHOCOLATE"), ("straw", "#f0a0b8", "#8e0e4a", "STRAWBERRY"), ("mint", "#a8e0c0", "#14642c", "MINT CHIP")):
	add("icecream_" + key, "tub", [0.15, 0.12, 0.15], "bag", wrap(colour, "#1c2c8c", ink, "CREAMERY", name, SERIF, cap="#1c2c8c"), liquid=colour, shiny=0.4)

for key, cap, name, sub in (("whole", "#c8102e", "WHOLE", "VITAMIN D"), ("two", "#1c5ad8", "2%", "REDUCED FAT"), ("skim", "#2e9b3f", "SKIM", "FAT FREE")):
	add("milk_" + key, "jug", GALLON, "jug", jug(cap, "#f4f4ee", "#ffffff", cap, name, sub), liquid="#f4f4ee", shiny=0.5)
add("milk_choc", "jug", [0.13, 0.2, 0.13], "jug", jug("#5a2c10", "#7a4a2a", "#ffffff", "#5a2c10", "CHOCOLATE", "MILK"), liquid="#7a4a2a", shiny=0.5)
add("eggs", "box", [0.3, 0.07, 0.11], "glass", carton("#d8d0bc", "#b8ae98", "#3a2a1a", "#f6f0dc", "FARM FRESH", "12 LARGE EGGS", SERIF), liquid="#f0c030")
add("butter", "box", [0.13, 0.065, 0.065], "card", carton("#f6e68a", "#e8c84a", "#1c5a2c", "#ffffff", "MEADOW", "SWEET BUTTER", SERIF), liquid="#f6e68a")
for key, colour, name in (("straw", "#f0a0b8", "STRAWBERRY"), ("peach", "#f4b878", "PEACH"), ("blue", "#7a80d0", "BLUEBERRY"), ("plain", "#f4f0e4", "PLAIN")):
	add("yogurt_" + key, "tub", [0.08, 0.09, 0.08], "bag", wrap(colour, "#1c5ad8", "#1c2c8c", "SMOOTHY", name, ROUNDED, cap="#e8e8e0"), liquid="#f4f0e4", shiny=0.4)
add("sourcream", "tub", [0.11, 0.08, 0.11], "bag", wrap("#f4f4ee", "#2e9b3f", "#14642c", "MEADOW", "SOUR CREAM", SERIF, cap="#2e9b3f"), liquid="#f4f4ee", shiny=0.4)
add("shredded", "bag", [0.17, 0.22, 0.04], "bag", foil("#f6c21a", "#e8761a", "#1c2c8c", "#f49a14", "MEADOW", "SHREDDED"), liquid="#f0b030")
add("cheddar_block", "box", [0.2, 0.05, 0.08], "cheese", carton("#f49a14", "#e8761a", "#ffffff", "#f6c21a", "CHEDDAR", "SHARP"), liquid="#f0a020", shiny=0.3)

add("wheel_gouda", "wheel", [0.34, 0.1, 0.34], "cheese", skin("#e0a81a", "#c88a0e", "#00000018", 4), liquid="#f0c040", shiny=0.45)
add("wheel_red", "wheel", [0.26, 0.09, 0.26], "cheese", skin("#c8201a", "#a01410", "#00000018", 4), liquid="#f4d870", shiny=0.6)
add("wheel_black", "wheel", [0.3, 0.11, 0.3], "cheese", skin("#2a2a2a", "#141414", "#ffffff10", 4), liquid="#f4e090", shiny=0.55)
add("wedge_swiss", "wedge", [0.18, 0.08, 0.14], "cheese", skin("#f4dc7a", "#ecd060", "#c8a84060", 2), liquid="#f4dc7a", shiny=0.3)
add("wedge_blue", "wedge", [0.16, 0.07, 0.12], "cheese", skin("#e8e8d8", "#c8d0c0", "#3a5a7a90", 2), liquid="#e8e8d8", shiny=0.25)
add("wedge_parm", "wedge", [0.15, 0.09, 0.12], "cheese", skin("#ecd890", "#d8bc60", "#a8843050", 2), liquid="#ecd890", shiny=0.2)
add("brie", "wheel", [0.2, 0.04, 0.2], "cheese", skin("#f4f0e0", "#e0d8c0", "#a8a08040", 3), liquid="#f4ead0", shiny=0.2)

add("ribeye", "tray", TRAY, "meat", meat("#a81c1c", "#6a0e10", "#f0d8c0"), liquid="#6a0a0e", shiny=0.75)
add("ground", "tray", TRAY, "meat", meat("#b83a34", "#8a2020", "#e8b0a0"), liquid="#6a0a0e", shiny=0.75)
add("chicken", "tray", [0.24, 0.07, 0.17], "meat", meat("#e8c0a0", "#d8a080", "#f4e0c0"), liquid="#a87060", shiny=0.75)
add("porkchop", "tray", TRAY, "meat", meat("#e09088", "#c86a64", "#f6e8dc"), liquid="#8a3030", shiny=0.75)
add("sausage", "tray", [0.24, 0.05, 0.12], "meat", meat("#8c3a24", "#6a2412", "#a85a3a"), liquid="#6a2412", shiny=0.75)
add("bacon", "box", [0.2, 0.025, 0.12], "meat", carton("#c8301a", "#7c1608", "#fff0c8", "#e8b090", "HICKORY", "THICK BACON", SERIF), liquid="#6a0a0e", shiny=0.75)
add("hotdogs", "box", [0.17, 0.03, 0.09], "meat", carton("#e8761a", "#c84a0a", "#ffffff", "#c8301a", "BIG JOE", "FRANKS"), liquid="#a84a30", shiny=0.75)
add("turkey", "round", [0.34, 0.2, 0.26], "meat", skin("#f0e0c4", "#e0c8a0", "#c0a07020", 6), liquid="#a87060", shiny=0.7)
add("salmon", "tray", [0.24, 0.04, 0.12], "meat", meat("#f0845c", "#e0683c", "#f8d8c0"), liquid="#a84a30", shiny=0.75)
add("shrimp", "tray", TRAY, "meat", meat("#f4a890", "#e88870", "#f8e0d0"), liquid="#a87060", shiny=0.75)
add("salami", "long", [0.07, 0.34, 0.07], "meat", skin("#7a2a20", "#4a1410", "#e8d8c060", 2), liquid="#6a0a0e", shiny=0.35)
add("ham", "round", [0.2, 0.2, 0.17], "meat", skin("#c86a58", "#a84a3a", "#f0d0c040", 5), liquid="#8a3030", shiny=0.6)

for key, base, deep, size, dimple, shiny in (
	("apple_red", "#b81c1c", "#e8483a", [0.08, 0.075, 0.08], "#4a3a10", 0.65),
	("apple_green", "#8cc030", "#b8d850", [0.08, 0.075, 0.08], "#4a3a10", 0.6),
	("orange", "#f08a10", "#f8a830", [0.085, 0.085, 0.085], "#c86a10", 0.4),
	("lemon", "#f0d820", "#f8e850", [0.065, 0.085, 0.065], "#a8a020", 0.45),
	("lime", "#6ab020", "#8cc830", [0.055, 0.06, 0.055], "#4a8010", 0.45),
	("tomato", "#d0200e", "#e84a20", [0.08, 0.07, 0.08], "#3a6a10", 0.7),
	("potato", "#a8824a", "#c8a468", [0.1, 0.07, 0.07], None, 0.1),
	("onion", "#c8843a", "#e8b060", [0.085, 0.08, 0.085], "#8a5a20", 0.35),
	("pepper_red", "#c81410", "#e83020", [0.085, 0.1, 0.085], "#3a6a10", 0.8),
	("pepper_yellow", "#f0c010", "#f8d830", [0.085, 0.1, 0.085], "#3a6a10", 0.8),
	("pepper_green", "#3a8a1c", "#58a830", [0.085, 0.1, 0.085], "#2a5a10", 0.8),
	("avocado", "#2a3a14", "#4a5a24", [0.07, 0.1, 0.07], None, 0.3),
	("peach", "#f0a060", "#e0604a", [0.08, 0.08, 0.08], "#a85a2a", 0.15),
	("pumpkin", "#e8740e", "#d05a08", [0.34, 0.27, 0.34], "#5a6a1a", 0.35),
	("melon", "#2a6a24", "#1c4a18", [0.26, 0.24, 0.36], None, 0.5),
	("cantaloupe", "#c8b070", "#a89050", [0.17, 0.16, 0.17], None, 0.15),
):
	add(key, "round", size, "produce", skin(base, deep, dimple=dimple), liquid=deep, shiny=shiny)
add("lettuce", "head", [0.19, 0.17, 0.19], "produce", skin("#7ab830", "#b8dc60", "#3a7a1020", 2), liquid="#7ab830", shiny=0.35)
add("cabbage", "head", [0.2, 0.19, 0.2], "produce", skin("#9cc868", "#c8e498", "#5a9a3020", 2), liquid="#9cc868", shiny=0.4)
add("broccoli", "head", [0.15, 0.17, 0.15], "produce", skin("#2a6a24", "#4a8a34", "#10401020", 1), liquid="#3a7a2a", shiny=0.1)
add("cucumber", "long", [0.05, 0.22, 0.05], "produce", skin("#1c5a24", "#3a7a34", "#a8c88040", 2), liquid="#a8c870", shiny=0.5)
add("carrot", "long", [0.04, 0.2, 0.04], "produce", skin("#e8700e", "#f08a20", "#a84a0830", 2), liquid="#e8700e", shiny=0.25)
add("corn", "long", [0.06, 0.24, 0.06], "produce", skin("#e8d040", "#d8b830", "#a8882030", 1), liquid="#e8d040", shiny=0.3)
add("banana", "long", [0.05, 0.2, 0.05], "produce", skin("#f0d030", "#e8c020", "#6a4a1040", 3), liquid="#f0e0a0", shiny=0.3)
add("strawberries", "tray", [0.15, 0.08, 0.11], "produce", meat("#c81420", "#e02a30", "#f8d060", "#d8e8e0"), liquid="#c81420", shiny=0.8)
add("mushrooms", "tray", [0.15, 0.07, 0.11], "produce", meat("#d8ccb8", "#b8a890", "#f0e8d8", "#3a6aa8"), liquid="#a89878", shiny=0.6)

add("loaf_white", "bag", LOAF, "soft", foil("#f4f0e4", "#e0d0a8", "#1c5ad8", "#c8102e", "SUNBEAM", "WHITE BREAD", ROUNDED), liquid="#f0e0b8", shiny=0.6)
add("loaf_wheat", "bag", LOAF, "soft", foil("#c89a5a", "#8c5a2c", "#fff0c8", "#2e9b3f", "SUNBEAM", "100% WHEAT", ROUNDED), liquid="#a87040", shiny=0.6)
add("buns", "bag", [0.2, 0.1, 0.14], "soft", foil("#e8c88a", "#c89a5a", "#a01c14", "#f6d24a", "SUNBEAM", "BURGER BUNS", ROUNDED), liquid="#d8b070", shiny=0.6)
add("bagels", "bag", [0.15, 0.1, 0.13], "soft", foil("#d8b070", "#a87040", "#1a3a7a", "#f4f0e4", "NY DELI", "6 BAGELS", SERIF), liquid="#c89a5a", shiny=0.6)
add("donuts", "box", [0.26, 0.09, 0.19], "card", carton("#f0a0b8", "#e0267a", "#ffffff", "#f6e0a8", "DONUT TOWN", "ONE DOZEN", ROUNDED, picture="#c8843a"), liquid="#d8a060")
add("cake", "box", [0.26, 0.12, 0.26], "card", carton("#f4f0f8", "#e0c8e8", "#8e0e4a", "#f0a0b8", "HAPPY DAY", "SHEET CAKE", BRUSH, picture="#f8f0e8"), liquid="#f8f0e8")
add("muffins", "tray", [0.2, 0.11, 0.14], "soft", meat("#b8824a", "#8c5a2c", "#3a1c08", "#e8f0ec"), liquid="#b8824a", shiny=0.7)
add("baguette", "long", [0.075, 0.62, 0.075], "soft", skin("#c88a3a", "#e0b060", "#6a3c1040", 2), liquid="#e8c890", shiny=0.2)
add("pie", "wheel", [0.25, 0.05, 0.25], "soft", skin("#c88a3a", "#e0b060", "#8a4a1030", 2), liquid="#c8301a", shiny=0.2)

# The boxes behind the shop: what comes in on a pallet.
add("shipper", "box", [0.5, 0.36, 0.38], "card", carton("#b8925c", "#a07c48", "#3a2a1a", "#00000000", "THIS SIDE UP", "GROCERY SUPPLY", NARROW), liquid="#b8925c", shiny=0.1)
add("shipper_cold", "box", [0.5, 0.3, 0.38], "card", carton("#c8a470", "#a88a58", "#1c4ea8", "#00000000", "KEEP COLD", "DAIRY SUPPLY", NARROW), liquid="#b8925c", shiny=0.1)
add("shipper_fragile", "box", [0.42, 0.42, 0.42], "card", carton("#bc9860", "#a4824c", "#a01c14", "#00000000", "FRAGILE", "GLASS", NARROW), liquid="#b8925c", shiny=0.1)

STUFF = {
	"pop": "a plastic bottle full of drink: it bursts, and falls whole",
	"glass": "glass: it shatters, also when it only falls",
	"can": "a can: holed by a shot, it falls whole and rolls",
	"card": "cardboard: torn by a shot, it falls whole",
	"bag": "a bag: it pops",
	"jug": "a jug: it splits and spills a lot",
	"soft": "soft: bread and paper, it tears",
	"produce": "what grows: it bursts into lumps",
	"meat": "meat: it bursts into lumps",
	"cheese": "cheese: it comes apart in lumps",
}


# --- What hangs in the shop ---------------------------------------------------
# Signs go on a sheet of their own: a sign is a column or two of cells that are
# four times as wide as they are high. Each is a plate, a word and a line under
# it, or a number beside that for an aisle.

SIGN_COLUMNS = 4
SIGN_ROWS = 18
SIGN_W = 512
SIGN_H = 128
SIGNS = {}


def sign(id, text, sub="", colour="#123a7a", ink="#ffffff", font=IMPACT, number="", wide=1):
	SIGNS[id] = {"text": text, "sub": sub, "colour": colour, "ink": ink, "font": font, "number": number, "wide": wide}


AISLE_WORDS = [
	("BEER & WINE", "COLD CASE IN BACK"), ("SODA", "2 LITER · 12 PACKS"), ("WATER · SPORTS", "JUICE"), ("CHIPS", "PRETZELS · POPCORN"),
	("COOKIES · CANDY", "CEREAL"), ("COFFEE · TEA", "CEREAL · BREAKFAST"), ("CANNED FOOD", "SOUP · BEANS"), ("PASTA · RICE", "SAUCES · CONDIMENTS"),
	("BAKING", "OILS · SPICES"), ("PAPER GOODS", "CLEANING"), ("HEALTH · BEAUTY", "BABY"), ("PET FOOD", "HARDWARE · FLASHLIGHTS"), ("SEASONAL", "HARDWARE · CHARCOAL"),
]
for i, (top, under) in enumerate(AISLE_WORDS):
	sign("aisle_%d" % (i + 1), top, under, number=str(i + 1))
sign("produce", "FRESH PRODUCE", colour="#14642c", font=BRUSH, wide=2)
sign("bakery", "OUR BAKERY", colour="#8c5a2c", font=BRUSH, wide=2)
sign("deli", "DELI & CHEESE", colour="#7a1420", font=BRUSH, wide=2)
sign("meat", "BUTCHER SHOP", colour="#a81c0e", font=BRUSH, wide=2)
sign("dairy", "DAIRY", "MILK · EGGS · BUTTER", colour="#1c5ad8", font=ROUNDED, wide=2)
sign("frozen", "FROZEN FOODS", colour="#1c78b8", font=ROUNDED, wide=2)
sign("checkout", "CHECKOUT", colour="#c8102e", font=IMPACT)
sign("service", "CUSTOMER SERVICE", "RETURNS · LOTTERY", colour="#123a7a", wide=2)
sign("employees", "EMPLOYEES ONLY", colour="#1a1a1a", ink="#f6d24a")
sign("electrical", "DANGER", "ELECTRICAL ROOM · HIGH VOLTAGE", colour="#f6d24a", ink="#1a1a1a")
sign("receiving", "RECEIVING", "ALL DELIVERIES", colour="#1a1a1a", ink="#ffffff")
sign("exit_sign", "EXIT", colour="#7a1010", ink="#ffffff")
sign("carts", "CART RETURN", "THANK YOU!", colour="#c8102e", ink="#ffffff")
sign("cart_back", "PLEASE RETURN", "YOUR CARTS HERE", colour="#123a7a", ink="#ffffff")
sign("store", "MEGA VALUE", colour="#c8102e", ink="#ffffff", font=IMPACT, wide=2)
sign("store_open", "OPEN 24 HOURS", "GROCERY · PHARMACY · FUEL", colour="#123a7a", ink="#ffffff", wide=2)
sign("welcome", "WELCOME", "WE ACCEPT FOOD STAMPS", colour="#14642c", ink="#ffffff")
sign("sale", "ROLLBACK", "PRICES CUT DAILY", colour="#f6d24a", ink="#c8102e")
sign("lane", "OPEN", "", colour="#14642c", ink="#ffffff")
sign("handicap", "RESERVED", "PARKING", colour="#1c5ad8", ink="#ffffff")


def draw_sign(id):
	design = SIGNS[id]
	wide = SIGN_W * design["wide"]
	args = ["-size", "%dx%d" % (wide, SIGN_H), "xc:" + design["colour"]]
	left = 0
	if design["number"]:
		args += ["-fill", design["ink"], "-draw", "circle 64,64 64,14"]
		args += ["(", "-background", "none", "-fill", design["colour"], "-font", BLACK, "-size", "76x64", "-gravity", "center", "label:" + design["number"], ")"]
		args += ["-gravity", "west", "-geometry", "+26+0", "-composite"]
		left = 124
	width = wide - left - 24
	top = 104 if not design["sub"] else 70
	args += ["(", "-background", "none", "-fill", design["ink"], "-font", design["font"], "-size", "%dx%d" % (width, top), "-gravity", "center", "label:" + design["text"], ")"]
	args += ["-gravity", "northwest", "-geometry", "+%d+%d" % (left + 12, 10), "-composite"]
	if design["sub"]:
		args += ["(", "-background", "none", "-fill", design["ink"], "-font", BLACK, "-size", "%dx32" % width, "-gravity", "center", "label:" + design["sub"], ")"]
		args += ["-gravity", "northwest", "-geometry", "+%d+%d" % (left + 12, 84), "-composite"]
	target = CELLS / ("sign_" + id + ".png")
	subprocess.run(["magick"] + args + ["-alpha", "off", str(target)], check=True)
	return target


def lay_out_signs():
	places = {}
	spot = [0, 0]
	sheet = ["magick", "-size", "%dx%d" % (SIGN_W * SIGN_COLUMNS, SIGN_H * SIGN_ROWS), "xc:#808080"]
	for id, design in SIGNS.items():
		if spot[0] + design["wide"] > SIGN_COLUMNS:
			spot = [0, spot[1] + 1]
		if spot[1] >= SIGN_ROWS:
			raise SystemExit("The signs do not fit their sheet")
		x, y = spot[0] * SIGN_W, spot[1] * SIGN_H
		sheet += [str(draw_sign(id)), "-gravity", "northwest", "-geometry", "+%d+%d" % (x, y), "-composite"]
		w = SIGN_W * design["wide"]
		places[id] = [(x + 2) / (SIGN_W * SIGN_COLUMNS), (y + 2) / (SIGN_H * SIGN_ROWS), (w - 4) / (SIGN_W * SIGN_COLUMNS), (SIGN_H - 4) / (SIGN_H * SIGN_ROWS), w / SIGN_H]
		spot[0] += design["wide"]
	subprocess.run(sheet + ["-quality", "93", str(OUT / "signs.jpg")], check=True)
	(OUT / "signs.json").write_text(json.dumps(places, indent="\t") + "\n")


# --- Laying it out ------------------------------------------------------------


def draw(product, again):
	target = CELLS / (product["id"] + ".png")
	if target.exists() and not again:
		return
	subprocess.run(["magick"] + product["draw"] + ["-resize", "%dx%d!" % (CELL, CELL), "-alpha", "off", str(target)], check=True)


def main():
	if "--list" in sys.argv:
		print(len(PRODUCTS), "products of", ACROSS * ACROSS, "cells")
		return
	if len(PRODUCTS) > ACROSS * ACROSS:
		raise SystemExit("%d products do not fit %d cells" % (len(PRODUCTS), ACROSS * ACROSS))
	seen = set()
	for product in PRODUCTS:
		if product["id"] in seen:
			raise SystemExit("two products are called " + product["id"])
		seen.add(product["id"])
	CELLS.mkdir(parents=True, exist_ok=True)
	again = "--all" in sys.argv
	for product in PRODUCTS:
		draw(product, again)
	files = [str(CELLS / (product["id"] + ".png")) for product in PRODUCTS]
	files += ["xc:#808080[%dx%d!]" % (CELL, CELL)] * (ACROSS * ACROSS - len(files) - 1)
	# The last cell is white, for what takes all its colour from a tint.
	files.append("xc:#ffffff[%dx%d!]" % (CELL, CELL))
	atlas = OUT / "goods_atlas.jpg"
	sheet = ["magick"]
	for row in range(ACROSS):
		sheet += ["("] + files[row * ACROSS:(row + 1) * ACROSS] + ["+append", ")"]
	subprocess.run(sheet + ["-append", "-quality", "92", str(atlas)], check=True)
	table = {"across": ACROSS, "stuff": STUFF, "products": {}}
	for i, product in enumerate(PRODUCTS):
		entry = {"cell": i, "shape": product["shape"], "size": product["size"], "stuff": product["stuff"], "shiny": product["shiny"]}
		if product["liquid"]:
			entry["liquid"] = product["liquid"]
		table["products"][product["id"]] = entry
	(OUT / "goods.json").write_text(json.dumps(table, indent="\t") + "\n")
	lay_out_signs()
	print(len(PRODUCTS), "products in", atlas.relative_to(ROOT))


if __name__ == "__main__":
	main()
