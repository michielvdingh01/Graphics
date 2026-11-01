extends "res://tools/levels/supermarket/plan.gd"
## The aisles: twelve gondolas in two lengths with a cross aisle between them,
## and thirteen aisles that each sell something else in their two halves. Every
## aisle has a list per half: a list per shelf from the bottom up, or one list
## that goes for all of them.

const SODA_2L: Array = [
	["fizz_2l", "dietfizz_2l", "barrel_2l"], ["fizz_2l", "zap_2l", "burst_2l"], ["bomb_2l", "doc_2l", "gush_2l"],
	["fizz_2l", "dietfizz_2l", "zap_2l"], ["burst_2l", "barrel_2l", "doc_2l"],
]
const SODA_12: Array = [
	["fizz_12", "dietfizz_12"], ["zap_12", "burst_12", "barrel_12"], ["gush_12", "bomb_12", "doc_12"],
	["fizz_can", "dietfizz_can", "zap_can", "burst_can"], ["barrel_can", "gush_can", "bomb_can", "doc_can"],
]
const WATER: Array = [
	["spring_case"], ["spring_gallon"], ["spring_bottle", "bolt_red", "bolt_blue"], ["bolt_lime", "bolt_orange", "volt_can"], ["volt_can", "spring_bottle"],
]
const JUICE: Array = [
	["oj_carton", "apple_juice"], ["grape_juice", "apple_juice"], ["oj_carton", "grape_juice"], ["apple_juice"], ["oj_carton"],
]
const BEER: Array = [
	["hawk_case", "river_case"], ["peak_case", "stone_case"], ["hawk_six", "river_six"], ["peak_six", "stone_six"], ["hawk_bottle", "river_bottle", "peak_bottle", "stone_bottle"],
]
const WINE_SHELF: Array = [
	["red_wine"], ["red_wine", "rose_wine"], ["white_wine", "rose_wine"], ["white_wine"], ["red_wine", "white_wine"],
]
const CHIPS: Array = [
	["crunchers"], ["crunchers", "crunchers_bbq"], ["ridge", "tortilla"], ["cheezy", "tortilla"], ["ridge", "crunchers_bbq"],
]
const SNACKS: Array = [
	["popped", "pretzel"], ["pretzel", "cheezy"], ["popped"], ["gummy", "corn_candy"], ["corn_candy"],
]
const COOKIES: Array = [
	["cookies"], ["chips_ahoy"], ["cookies", "chips_ahoy"], ["chocbar"], ["gummy", "chocbar"],
]
const CEREALS: Array = [
	["frosty", "flakers"], ["choco", "honey"], ["rings", "moons"], ["bran", "squares"], ["frosty", "moons", "honey"],
]
const BREAKFAST: Array = [
	["coffee_can"], ["coffee_bag", "tea"], ["oatmeal", "pancake"], ["syrup", "pancake"], ["tea", "oatmeal"],
]
const CANNED: Array = [
	["corn_can", "beans_can"], ["peas_can", "beans_can"], ["baked_can", "chili_can"], ["peach_can", "corn_can"], ["tuna_can", "peach_can"],
]
const SOUP: Array = [
	["soup_chicken"], ["soup_tomato"], ["soup_chicken", "soup_tomato"], ["chili_can", "baked_can"], ["soup_tomato", "soup_chicken"],
]
const PASTA: Array = [
	["spaghetti", "penne"], ["mac", "rice"], ["penne", "mac"], ["marinara", "salsa"], ["marinara"],
]
const SAUCES: Array = [
	["ketchup", "mustard"], ["mayo", "pickles"], ["bbq", "ranch"], ["peanut", "jelly"], ["ketchup", "bbq"],
]
const BAKING: Array = [
	["flour", "sugar"], ["sugar", "flour"], ["cakemix", "salt"], ["cakemix"], ["spice", "salt"],
]
const OILS: Array = [
	["oil"], ["oil", "olive"], ["olive"], ["spice"], ["spice", "salt"],
]
const PAPER: Array = [
	["tp"], ["tp", "towels"], ["towels"], ["trashbags", "foil"], ["foil", "trashbags"],
]
const CLEANING: Array = [
	["wash", "wash2"], ["softener", "bleach"], ["dish", "spray"], ["spray", "dish"], ["wash", "softener"],
]
const HEALTH: Array = [
	["shampoo"], ["toothpaste", "vitamins"], ["shampoo", "vitamins"], ["toothpaste"], ["vitamins"],
]
const BABY: Array = [
	["diapers"], ["diapers"], ["shampoo", "toothpaste"], ["vitamins"], ["toothpaste"],
]
const PETS: Array = [
	["dogfood"], ["litter"], ["catfood"], ["catfood"], ["catfood"],
]
const HARDWARE: Array = [
	["charcoal"], ["motoroil"], ["candle", "bulbs"], ["batteries", "tape"], ["bulbs", "batteries"],
]
const SEASON: Array = [
	["charcoal"], ["corn_candy", "gummy"], ["candle"], ["candle", "corn_candy"], ["corn_candy"],
]
## What each aisle sells in its two halves, from the north.
const AISLES: Array = [
	[BEER, WINE_SHELF], [SODA_2L, SODA_12], [WATER, JUICE], [CHIPS, SNACKS], [COOKIES, CEREALS], [BREAKFAST, CEREALS],
	[CANNED, SOUP], [PASTA, SAUCES], [BAKING, OILS], [PAPER, CLEANING], [HEALTH, BABY], [PETS, HARDWARE], [SEASON, HARDWARE],
]
## What hangs over each aisle.
const SIGNS: Array[String] = [
	"aisle_1", "aisle_2", "aisle_3", "aisle_4", "aisle_5", "aisle_6", "aisle_7", "aisle_8", "aisle_9", "aisle_10", "aisle_11", "aisle_12", "aisle_13",
]
## What stands in the end of a gondola: a product per shelf.
const OFFERS: Array = [
	["fizz_12", "fizz_12", "fizz_2l"], ["crunchers", "crunchers_bbq", "tortilla"], ["hawk_six", "peak_six", "stone_six"],
	["frosty", "choco", "honey"], ["ketchup", "bbq", "mustard"], ["corn_candy", "gummy", "chocbar"],
	["soup_chicken", "soup_tomato", "chili_can"], ["cookies", "chips_ahoy", "chocbar"], ["wash", "softener", "dish"],
]


func _describe() -> void:
	for i in GONDOLAS:
		var z := gondola_z(i)
		for half in 2:
			var ends: Vector2 = AISLE_B if half == 1 else AISLE_A
			var north: Array = AISLES[i][half]
			var south: Array = AISLES[i + 1][half]
			gondola(Vector2(ends.x, z), Vector2(ends.y, z), north, south)
		# Their ends, towards the front and either side of the cross aisle.
		var offer: Array = OFFERS[i % OFFERS.size()]
		end_cap(Vector3(AISLE_A.x, 0, z), Vector3.LEFT, offer)
		end_cap(Vector3(AISLE_A.y, 0, z), Vector3.RIGHT, OFFERS[(i + 3) % OFFERS.size()])
		end_cap(Vector3(AISLE_B.x, 0, z), Vector3.LEFT, OFFERS[(i + 5) % OFFERS.size()])
		end_cap(Vector3(AISLE_B.y, 0, z), Vector3.RIGHT, OFFERS[(i + 7) % OFFERS.size()])
	# In the hardware aisle, on the end of a gondola, where anyone would look.
	flashlight_at(Vector3(AISLE_B.y + 0.9, 1.0, gondola_z(10)))
	for i in AISLES.size():
		var z := GONDOLA_FIRST + GONDOLA_PITCH * (i - 0.5)
		for x: float in [AISLE_A.x + 0.6, AISLE_B.x + 0.6]:
			aisle_sign(SIGNS[i], Vector3(x, 0, z), 3.4, 3.6, DECK)
