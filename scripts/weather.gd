extends Node2D
class_name Weather

# Погода. Меняется по кругу каждые 14 секунд, переход плавный - 4 секунды.
# Небо красит шейдер, дождь и светлячки - частицы.
# Погода меняет правила: ветер сносит фрукты, в грозу бьют молнии,
# на закате больше золотых яблок, ночью падают звёзды.

signal struck(x)        # молния ударила в точку x
signal star_wanted      # пора запустить падающую звезду

const ORDER = ["clear", "cloudy", "rain", "sunset", "night"]
const NAMES = {"clear": "Ясно", "cloudy": "Ветер", "rain": "Гроза", "sunset": "Закат", "night": "Ночь"}
const TOAST = {"clear": "Наступает утро", "cloudy": "Ветер! Порывы сносят фрукты вбок",
	"rain": "Гроза! Скользко, берегись молний", "sunset": "Золотой час: больше золотых яблок",
	"night": "Звездопад: лови звёзды, +3"}
const SOUND = {"rain": "storm_start", "sunset": "golden_hour"}
const AMBIENT = {"clear": "amb_clear", "cloudy": "amb_windy", "rain": "amb_rain", "sunset": "amb_sunset", "night": "amb_night"}
const TIME = 14.0
const FADE = 4.0
# цвет неба сверху, посередине и снизу (последнее число - насколько сильно красит)
const TINT = {
	"clear": [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)],
	"cloudy": [Color8(110, 125, 150, 82), Color8(100, 118, 125, 64), Color8(90, 110, 100, 46)],
	"rain": [Color8(55, 65, 90, 140), Color8(48, 62, 80, 122), Color8(40, 60, 70, 102)],
	"sunset": [Color8(235, 95, 45, 148), Color8(245, 125, 65, 130), Color8(85, 30, 75, 115)],
	"night": [Color8(8, 12, 45, 189), Color8(6, 11, 38, 176), Color8(4, 10, 30, 163)]}

var main
var index = 0
var clock = FADE
var shown = "clear"     # какая погода написана вверху
var rain_level = 0.0
var wind = 0.0
var gust_wind = 0.0
var night_level = 0.0
var star_points = []
var star_timer = 0.0
var starfall_timer = 2.0
var thunder_timer = 9.0
# порыв ветра
var gust_timer = 3.0
var gust_active = false
var gust_time = 0.0
var gust_side = 1
# молния
var lightning_timer = 3.0
var strike_active = false
var strike_time = 0.0
var strike_x = 0.0
var ring = null
var bolt = null

@onready var tint = $Tint
@onready var stars = $Stars
@onready var rain = $Rain
@onready var fireflies = $Fireflies


func _ready():
	# дождь - тонкие светлые чёрточки
	var img = Image.create(2, 18, false, Image.FORMAT_RGBA8)
	for y in 18:
		img.set_pixel(0, y, Color(0.85, 0.92, 1.0, y / 18.0 * 0.8))
		img.set_pixel(1, y, Color(0.85, 0.92, 1.0, y / 18.0 * 0.5))
	rain.texture = ImageTexture.create_from_image(img)
	rain.amount = 140
	rain.lifetime = 0.9
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(300, 10)
	rain.position = Vector2(240, -20)
	rain.direction = Vector2(0, 1)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 700
	rain.initial_velocity_max = 850
	rain.emitting = false
	# светлячки ночью у травы
	fireflies.texture = Art.firefly
	fireflies.amount = 10
	fireflies.lifetime = 4.0
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = Vector2(230, 70)
	fireflies.position = Vector2(240, 530)
	fireflies.direction = Vector2(1, 0)
	fireflies.spread = 180.0
	fireflies.gravity = Vector2.ZERO
	fireflies.initial_velocity_min = 5
	fireflies.initial_velocity_max = 25
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fireflies.color_ramp = g
	fireflies.emitting = false
	# звёзды ставлю только туда, где на картинке сада небо (голубой пиксель)
	var bg = Art.sad[0].get_image()
	if bg == null:
		return
	if bg.is_compressed():
		bg.decompress()
	var tries = 0
	while star_points.size() < 38 and tries < 3000:
		tries += 1
		var p = Vector2i(randi_range(20, 460), randi_range(90, 470))
		var c = bg.get_pixelv(p)
		if c.b8 > 190 and c.b8 > c.r8 + 40:
			star_points.append([Vector2(p), randf_range(1.0, 2.0)])
	stars.draw.connect(draw_stars)


func _process(delta):
	delta = min(delta, 0.05)
	clock += delta
	if clock > TIME:
		clock = 0.0
		index = (index + 1) % ORDER.size()
	var now = ORDER[index]
	var old = ORDER[index - 1]
	var mix = min(1.0, clock / FADE)
	if mix > 0.5 and shown != now:   # надпись меняю, когда небо уже наполовину перекрасилось
		shown = now
		main.weather_changed(now)
	# цвет неба плавно перетекает из старой погоды в новую
	var names = ["top", "mid", "bottom"]
	for i in 3:
		var a = TINT[old][i]
		var b = TINT[now][i]
		if a.a == 0.0:
			a = Color(b.r, b.g, b.b, 0.0)
		if b.a == 0.0:
			b = Color(a.r, a.g, a.b, 0.0)
		tint.material.set_shader_parameter(names[i], a.lerp(b, mix))
	# звуки погоды тоже перетекают: старый затихает, новый нарастает
	for w in AMBIENT:
		var amount = 0.0
		if w == now:
			amount = sin(max(0.0, (mix - 0.3) / 0.7) * PI / 2)
		elif w == old:
			amount = cos(min(1.0, mix / 0.7) * PI / 2)
		Sfx.set_loop(AMBIENT[w], amount)
	night_level = 0.0
	if now == "night":
		night_level = mix
	elif old == "night":
		night_level = 1.0 - mix
	var target = 0.0
	if now == "rain" and mix > 0.3:
		target = 1.0
	rain_level = move_toward(rain_level, target, delta * 0.3)
	var wind_target = rain_level * 60
	if now == "cloudy":
		wind_target += 25 * mix
	wind += (wind_target - wind) * min(1.0, delta)
	rain.emitting = rain_level > 0.05
	rain.modulate.a = rain_level
	rain.direction = Vector2(wind / 700.0, 1.0).normalized()
	fireflies.emitting = night_level > 0.3
	fireflies.modulate.a = night_level
	star_timer -= delta
	if star_timer <= 0:
		star_timer = 0.12
		stars.queue_redraw()   # звёзды мерцают
	update_gusts(delta, now == "cloudy" and mix > 0.5)
	update_lightning(delta, now == "rain" and rain_level > 0.6)
	# ночью звездопад
	if now == "night" and mix > 0.5 and main.state == "game":
		starfall_timer -= delta
		if starfall_timer <= 0:
			starfall_timer = randf_range(3, 6)
			star_wanted.emit()
	# далёкий гром между молниями
	if rain_level > 0.8 and not strike_active:
		thunder_timer -= delta
		if thunder_timer <= 0:
			thunder_timer = randf_range(9, 14)
			Sfx.play("thunder", -8.0)


func draw_stars():
	if night_level < 0.45:
		return
	var colors = [Color.WHITE, Color.WHITE, Color("fff4c2"), Color("c9d6ff"), Color("7f88aa")]
	for s in star_points:
		stars.draw_circle(s[0], s[1], colors.pick_random())


func update_gusts(delta, windy):
	# порывы ветра то влево, то вправо, сносят падающие фрукты и несут листья
	if not gust_active:
		gust_wind = 0.0
		if windy:
			gust_timer -= delta
			if gust_timer <= 0:
				gust_active = true
				gust_time = 0.0
				gust_side = 1
				if randf() < 0.5:
					gust_side = -1
				gust_timer = randf_range(3.5, 6)
				Sfx.play("gust")
				if main.state == "game":
					if gust_side > 0:
						main.ui.toast("Порыв ветра →")
					else:
						main.ui.toast("Порыв ветра ←")
				var leaf_x = 500
				if gust_side > 0:
					leaf_x = -20
				for i in 4:
					main.spawn_leaf(leaf_x, randf_range(80, 400), gust_side)
		return
	gust_time += delta
	gust_wind = gust_side * 150.0 * sin(PI * min(1.0, gust_time / 1.6))
	if gust_time >= 1.6:
		gust_active = false


func update_lightning(delta, storm):
	# гроза: на траве мигает кольцо, через секунду туда бьёт молния
	if not strike_active:
		if storm:
			lightning_timer -= delta
			if lightning_timer <= 0:
				lightning_timer = randf_range(4.5, 8)
				strike_x = randf_range(40, 440)
				if main.state == "game" and randf() < 0.55:
					# чаще целится рядом с корзинкой, чтобы было интереснее
					strike_x = clamp(main.basket.position.x + randf_range(-45, 45), 40, 440)
				ring = AnimatedSprite2D.new()
				var sf = SpriteFrames.new()
				for t in Art.warn:
					sf.add_frame("default", t)
				sf.set_animation_speed("default", 14)
				ring.sprite_frames = sf
				ring.position = Vector2(strike_x, 610)
				ring.z_index = 9     # поверх корзинки, чтобы было видно
				main.add_child(ring)
				ring.play()
				strike_active = true
				strike_time = 0.0
				bolt = null
				Sfx.play("lightning_warn")
		return
	strike_time += delta
	if strike_time >= 1.0 and bolt == null:
		ring.queue_free()
		ring = null
		bolt = Sprite2D.new()
		bolt.texture = Art.bolts.pick_random()
		bolt.centered = false
		bolt.offset = Vector2(-110, -620)
		bolt.position = Vector2(strike_x, 614)
		bolt.z_index = 10
		main.add_child(bolt)
		struck.emit(strike_x)
	elif bolt != null:
		bolt.visible = int(strike_time * 30) % 2 == 0   # молния мерцает
		if strike_time > 1.3:
			bolt.queue_free()
			bolt = null
			strike_active = false


func clear_strike():
	# убрать молнию и порыв (когда игра начинается заново)
	if ring != null and is_instance_valid(ring):
		ring.queue_free()
	if bolt != null and is_instance_valid(bolt):
		bolt.queue_free()
	ring = null
	bolt = null
	strike_active = false
	gust_active = false
	gust_wind = 0.0
