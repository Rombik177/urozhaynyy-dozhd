extends Node

# Тут один раз при запуске загружаются все картинки, а потом все берут их отсюда.
# Например Art.items["apple"][5] - пятая картинка вращения яблока.

const KINDS = ["apple", "pear", "gold", "can", "bomb"]
const FX = {"juice_apple": 12, "juice_pear": 12, "sparkle_gold": 12, "boom3": 14, "dust2": 9}
const PART_COLORS = ["red", "yellow", "green", "grey", "fire", "smoke", "spark", "white"]

var sad = []            # 48 картинок сада (деревья качаются)
var trava = []          # ближняя трава отдельно
var items = {}          # 72 картинки вращения для каждого предмета
var items_squash = {}   # 3 картинки, как фрукт сплющивается об траву
var icons = {}
var small = {}          # маленькие фрукты для корзинки
var basket_back = []    # 15 картинок наклона корзинки
var basket_front = []   # передняя стенка отдельно, фрукты лежат между ними
var fx = {}
var parts = {}          # частицы разных цветов
var shadows = []
var sparkles = []
var firefly
var heart
var heart_empty
var bolts = []
var warn = []
var scorch = []
var stars = []
var zap = []
var leaf
var cat_info = {}
var cats = {}           # окрас -> размер -> анимации кота


func _ready():
	sad = seq("res://img/sad/sad_%02d.png", 48)
	trava = seq("res://img/sad_fg/fg_%02d.png", 48)
	for k in KINDS:
		items[k] = seq("res://img/items72/" + k + "_%02d.png", 72)
		items_squash[k] = seq("res://img/items/" + k + "_squash_%d.png", 3)
		icons[k] = load("res://img/items/" + k + "_icon.png")
		if k == "apple" or k == "pear" or k == "gold":
			small[k] = load("res://img/items/" + k + "_small.png")
	basket_back = seq("res://img/basket/basket_%02d.png", 15)
	basket_front = seq("res://img/basket/front_%02d.png", 15)
	for n in FX:
		fx[n] = seq("res://img/fx/" + n + "_%02d.png", FX[n])
	for n in PART_COLORS:
		parts[n] = load("res://img/fx/part_" + n + "_1.png")
	shadows = seq("res://img/fx/shadow_%d.png", 8)
	sparkles = seq("res://img/fx/sparkle_%d.png", 3)
	firefly = load("res://img/fx/firefly_0.png")
	heart = load("res://img/fx/heart.png")
	heart_empty = load("res://img/fx/heart_empty.png")
	bolts = seq("res://img/weather/bolt_%d.png", 3)
	warn = seq("res://img/weather/warn_%d.png", 4)
	scorch = seq("res://img/weather/scorch_%d.png", 3)
	stars = seq("res://img/weather/star_%d.png", 4)
	zap = seq("res://img/fx/zap_%d.png", 4)
	leaf = load("res://img/weather/leaf_0.png")
	load_cats()


func seq(fmt, count):
	# загружает несколько картинок подряд: name_00, name_01, ...
	var out = []
	for i in count:
		out.append(load(fmt % i))
	return out


func load_cats():
	# кот: картинки движений и файл cat.json, где записано, где у кота лапы и какой длины шаг
	var info = JSON.parse_string(FileAccess.get_file_as_string("res://img/cat/cat.json"))
	if info == null:
		return
	cat_info = info
	var fps = {"walk": 18.0, "run": 24.0, "sit": 14.0, "idle": 12.0, "meow": 12.0}
	for color in info["colors"]:
		cats[color] = {}
		for size_name in ["small", "big"]:
			var sf = SpriteFrames.new()
			sf.remove_animation("default")
			for action in fps:
				var i = 0
				var path = "res://img/cat/%s/%s_r_%s_%02d.png" % [color, size_name, action, i]
				while ResourceLoader.exists(path):
					if i == 0:
						sf.add_animation(action)
						sf.set_animation_speed(action, fps[action])
						sf.set_animation_loop(action, action == "walk" or action == "run" or action == "idle")
					sf.add_frame(action, load(path))
					i += 1
					path = "res://img/cat/%s/%s_r_%s_%02d.png" % [color, size_name, action, i]
			# куда кот смотрит: 12 положений головы
			for yaw in [0, 45, 90, 135]:
				for pitch in [0, 25, 50]:
					var p = "res://img/cat/%s/%s_r_look_%d_%d.png" % [color, size_name, yaw, pitch]
					if ResourceLoader.exists(p):
						var a = "look_" + str(yaw) + "_" + str(pitch)
						sf.add_animation(a)
						sf.add_frame(a, load(p))
			cats[color][size_name] = sf
