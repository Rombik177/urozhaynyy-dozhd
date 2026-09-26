extends Node2D

# Главный скрипт игры "Урожайный дождь".
# Тут меню, очки, жизни, уровни, таймер, появление фруктов, коты и рекорды.

const START_LIVES = 3
const GAME_TIME = 30.0          # режим "на время" длится 30 секунд
const START_FALL_SPEED = 150.0  # с такой скоростью фрукты падают в начале
const MAX_FALL_SPEED = 480.0    # быстрее уже нечестно
const START_SPAWN_DELAY = 1.0   # раз в сколько секунд появляется новый предмет
const MIN_SPAWN_DELAY = 0.35
const POINTS_PER_LEVEL = 5      # каждые 5 очков - новый уровень
const FRUIT_POINTS = {"apple": 1, "pear": 2, "gold": 5}
const RECORD_FILE = "user://record.txt"
const RED = Color("ff7a6e")     # цвет для минусов

var state = "menu"      # menu - меню, game - игра, pause - пауза, over - конец
var mode = "lives"      # lives - три жизни, time - на время
var score = 0
var lives = START_LIVES
var time_left = GAME_TIME
var last_second = 30
var level = 1
var spawn_timer = 0.0
var streak = 0          # сколько фруктов поймал подряд
var multiplier = 1      # во сколько раз больше очков за серию
var records = {"lives": 0, "time": 0}
var bg_time = 0.0
var shake_time = 0.0
var shake_power = 0.0
var cat_timer = 5.0
var purr = 0.0          # громкость мурлыканья, её ставит кот
var menu_fruit_timer = 0.0
var level_sound_timer = 0.0
var end_sound_timer = 0.0
var end_sound = ""
var leaf_list = []      # листья, которые летают по экрану

@onready var sad = $Sad
@onready var trava = $Trava
@onready var camera = $Camera
@onready var weather = $Weather
@onready var basket = $Basket
@onready var items = $Items
@onready var shadows = $Shadows
@onready var pile = $Pile
@onready var fx = $Fx
@onready var ui = $UI
@onready var flash = $Flash
@onready var cats_far = $CatsFar
@onready var cats_near = $CatsNear
@onready var leaves = $LeavesLow


func _ready():
	weather.main = self
	basket.main = self
	weather.struck.connect(_on_struck)
	weather.star_wanted.connect(_spawn_star)
	ui.start_pressed.connect(start_game)
	ui.menu_pressed.connect(show_menu)
	ui.again_pressed.connect(_on_again)
	load_records()
	show_menu()


func _process(delta):
	if state == "pause":
		return
	var d = min(delta, 0.05)   # если игра подвисла, чтобы всё не прыгнуло
	bg_time += d
	# сад качается: 48 картинок, 12 в секунду
	var frame = int(bg_time * 12) % 48
	sad.texture = Art.sad[frame]
	trava.texture = Art.trava[frame]
	# мурлыканье: сидящий рядом кот каждый кадр ставит purr
	Sfx.set_loop("purr", purr)
	purr = 0.0
	move_leaves(d)
	update_cats(d)
	update_shake(d)
	update_sound_timers(d)
	if state == "menu":
		menu_rain(d)
	if state != "game":
		return
	spawn_timer -= d
	if spawn_timer <= 0:
		spawn_fruit()
		spawn_timer = spawn_delay()
	if mode == "time":
		time_left -= delta    # тут настоящие секунды, чтобы таймер был честный
		var sec = int(ceil(time_left))
		if sec != last_second:
			last_second = sec
			update_hud()
			if sec > 0 and sec <= 5:
				Sfx.play("tick")
		if time_left <= 0:
			end_game()


# ---------- фрукты ----------

func menu_rain(d):
	# в меню за табличкой тоже идёт "урожайный дождь", но фрукты никто не ловит
	menu_fruit_timer -= d
	if menu_fruit_timer > 0:
		return
	menu_fruit_timer = randf_range(0.5, 1.1)
	var f = Fruit.new()
	f.main = self
	f.decor = true
	f.kind = ["apple", "apple", "pear", "gold"].pick_random()
	f.speed = randf_range(90, 150)
	f.vy = 40.0
	f.angle = randf_range(0, 360)
	f.spin = randf_range(60, 120)
	if randf() < 0.5:
		f.spin = -f.spin
	f.position = Vector2(randf_range(30, 450), -40)
	items.add_child(f)


func fall_speed():
	# чем выше уровень, тем быстрее падают
	return min(START_FALL_SPEED + (level - 1) * 45.0, MAX_FALL_SPEED)


func spawn_delay():
	# и тем чаще появляются
	return max(START_SPAWN_DELAY - (level - 1) * 0.09, MIN_SPAWN_DELAY)


func spawn_fruit():
	var f = Fruit.new()
	f.main = self
	# что упадёт - решает случайное число от 1 до 100
	var n = randi_range(1, 100)
	var gold_chance = 3
	if weather.shown == "sunset":
		gold_chance = 14      # на закате золотых яблок больше
	if n <= gold_chance:
		f.kind = "gold"
	elif n <= 50:
		f.kind = "apple"
	elif n <= 70:
		f.kind = "pear"
	elif n <= 85:
		f.kind = "can"
	else:
		f.kind = "bomb"
	f.speed = fall_speed() * randf_range(0.85, 1.15)
	f.vy = f.speed * 0.3     # сначала падает медленно, потом разгоняется
	f.angle = randf_range(0, 360)
	if f.kind == "can" or f.kind == "bomb":
		f.spin = randf_range(220, 340)   # мусор крутится быстрее
	else:
		f.spin = randf_range(90, 170)
	if randf() < 0.5:
		f.spin = -f.spin
	f.position = Vector2(randi_range(35, 445), -40)
	f.caught.connect(_on_caught)
	f.landed.connect(_on_landed)
	items.add_child(f)


func _spawn_star():
	# ночью падают звёзды
	var f = Fruit.new()
	f.main = self
	f.kind = "star"
	f.vx = 70.0
	if randf() < 0.5:
		f.vx = -70.0
	f.vy = 200.0
	f.position = Vector2(randi_range(80, 400), -20)
	f.caught.connect(_on_caught)
	items.add_child(f)
	Sfx.play("star_fall")


func lowest_fruit():
	# самый нижний фрукт - на него смотрит кот
	var best = null
	for f in items.get_children():
		if f.is_landed or f.kind == "can" or f.kind == "bomb":
			continue
		if best == null or f.position.y > best.position.y:
			best = f
	return best


func _on_caught(f):
	var pos = f.position
	if f.kind == "apple" or f.kind == "pear" or f.kind == "gold":
		var combo_up = add_streak()
		add_score(FRUIT_POINTS[f.kind] * multiplier, pos)
		basket.bounce(160)
		if f.kind == "apple":
			fx.flipbook("juice_apple", pos - Vector2(0, 6))
			fx.burst(pos, ["red"], 4, 220.0)
		elif f.kind == "pear":
			fx.flipbook("juice_pear", pos - Vector2(0, 6))
			fx.burst(pos, ["yellow"], 4, 220.0)
		else:
			fx.flipbook("sparkle_gold", pos - Vector2(0, 6))
			fx.burst(pos, ["spark", "white"], 8, 300.0)
			ui.toast("Золотое яблоко! +" + str(5 * multiplier))
		basket.add_fruit(f.kind, pos, Vector2(f.vx, f.vy))
		if not combo_up:
			Sfx.play(f.kind)
		Sfx.play("splash")
	elif f.kind == "can":
		reset_streak()
		if mode == "lives":
			lose_life(pos)       # в режиме с жизнями банка - минус жизнь
		else:
			add_score(-1, pos)   # на время - минус очко
		fx.burst(pos, ["grey", "red"], 10, 220.0)
		basket.bounce(120)
		shake(4, 0.2)
		Sfx.play("can")
	elif f.kind == "bomb":
		reset_streak()
		add_score(-2, pos)
		if mode == "lives":
			lose_life(pos)
		fx.flipbook("boom3", pos - Vector2(0, 24), 28.0)
		fx.burst(pos, ["fire", "smoke"], 12, 380.0)
		basket.bounce(260)
		basket.knock_out()     # взрыв выбивает фрукты из корзинки
		shake(10, 0.4)
		flash_screen(Color(1, 0.24, 0.12, 0.37), 0.15)
		scare_cats(pos.x, 140)
		Sfx.play("bomb")
	elif f.kind == "star":
		add_score(3, pos)
		fx.burst(pos, ["spark", "white"], 20, 300.0)
		Sfx.play("star_catch")
	f.queue_free()
	update_hud()


func _on_landed(f):
	# фрукт упал на траву - значит пропустил
	if f.kind == "apple" or f.kind == "pear":
		reset_streak()
		fx.flipbook("dust2", Vector2(f.position.x, 598))
		Sfx.play("miss")
		if mode == "lives":
			lose_life(Vector2(f.position.x, 620))
		update_hud()


# ---------- очки, жизни, серия ----------

func add_score(points, pos):
	score += points
	if points > 0:
		fx.popup(pos, "+" + str(points), Color("ffe45c"))
	else:
		fx.popup(pos, str(points), RED, 22, true)
	# новый уровень каждые 5 очков
	var new_level = 1 + int(max(score, 0) / POINTS_PER_LEVEL)
	if new_level > level:
		level = new_level
		fx.popup(Vector2(240, 280), "Быстрее!", Color("fff3a0"), 36)
		level_sound_timer = 0.25   # звук чуть позже, чтобы не слился со звуком фрукта
	update_hud()


func lose_life(pos):
	lives -= 1
	fx.popup(pos - Vector2(0, 50), "−1 жизнь", RED, 20, true)
	update_hud()
	if lives <= 0:
		end_game()


func add_streak():
	# серия только в режиме с жизнями, на время очки как в задании
	if mode == "time":
		return false
	streak += 1
	var m = min(3, 1 + int(streak / 5))   # 5 подряд - x2, 10 подряд - x3
	if m > multiplier:
		multiplier = m
		fx.popup(Vector2(basket.position.x, 500), "Серия ×" + str(m) + "!", Color("ffd23f"), 26)
		Sfx.play("combo")
		return true
	return false


func reset_streak():
	streak = 0
	multiplier = 1


func update_hud():
	ui.update_hud(score, level, Weather.NAMES[weather.shown], mode, lives, time_left, multiplier)


# ---------- погода ----------

func weather_changed(now):
	if state == "game":
		ui.toast(Weather.TOAST[now])
		if Weather.SOUND.has(now):
			Sfx.play(Weather.SOUND[now])
		update_hud()


func _on_struck(x):
	# молния ударила в точку x
	scare_cats(x, 220)
	Sfx.play("lightning")
	if state == "game":
		flash_screen(Color(1, 1, 1, 0.6), 0.12)
		shake(7, 0.3)
	else:
		flash_screen(Color(1, 1, 1, 0.4), 0.05)   # в меню без тряски
	fx.burst(Vector2(x, 604), ["white", "spark"], 16, 300.0)
	# на траве остаётся выжженное пятно, оно бледнеет 4 секунды
	var scorch = Sprite2D.new()
	scorch.texture = Art.scorch[0]
	scorch.position = Vector2(x, 612)
	shadows.add_child(scorch)
	var t = create_tween()
	t.tween_property(scorch, "modulate:a", 0.0, 4.0)
	t.tween_callback(scorch.queue_free)
	# молния попала в фрукт - он становится золотым, а мусор взрывается
	for f in items.get_children():
		if f.is_landed or f.kind == "star" or abs(f.position.x - x) > 32:
			continue
		if f.kind == "apple" or f.kind == "pear":
			f.kind = "gold"
			f.add_sparks()
			fx.popup(f.position - Vector2(0, 30), "Золотое!", Color("ffd23f"), 18)
		elif f.kind == "can" or f.kind == "bomb":
			fx.flipbook("boom3", f.position - Vector2(0, 20), 28.0)
			fx.popup(f.position - Vector2(0, 30), "Бах!", Color("ff9f1c"), 18)
			f.queue_free()
	# молния попала в корзинку - её бьёт током
	if state == "game" and abs(basket.position.x - x) < 55:
		basket.stun = 1.2
		basket.knock_out()
		reset_streak()
		Sfx.play("zap")
		add_score(-1, basket.position - Vector2(0, 50))
		fx.popup(basket.position - Vector2(0, 90), "Током!", Color("cfe0ff"), 22)


func spawn_leaf(x, y, side = 0):
	if leaf_list.size() >= 12:
		return
	var l = Sprite2D.new()
	l.texture = Art.leaf
	l.position = Vector2(x, y)
	leaves.add_child(l)
	var spin = randf_range(3, 8)
	if randf() < 0.5:
		spin = -spin
	# лист из порыва ветра влетает сбоку
	leaf_list.append({"node": l, "vx": side * randf_range(90, 170), "vy": randf_range(50, 100),
		"phase": randf_range(0, 6), "spin": spin})


func move_leaves(d):
	var wind = weather.wind + weather.gust_wind
	# в ветер листья сами срываются с деревьев
	if weather.wind > 15 and randf() < d * weather.wind / 60:
		var x = randf_range(0, 150)
		if randf() < 0.5:
			x = randf_range(330, 480)
		spawn_leaf(x, randf_range(40, 150))
	for leaf in leaf_list.duplicate():
		var l = leaf["node"]
		leaf["vx"] *= 1.0 - 0.8 * d
		l.position.y += leaf["vy"] * d
		l.position.x += (leaf["vx"] + wind * 0.9 + sin(bg_time * 2 + leaf["phase"]) * 40) * d
		l.rotation += leaf["spin"] * d
		if l.position.y > 660 or l.position.x < -30 or l.position.x > 510:
			l.queue_free()
			leaf_list.erase(leaf)


# ---------- коты ----------

func update_cats(d):
	cat_timer -= d
	if cat_timer > 0 or Art.cats.is_empty():
		return
	cat_timer = randf_range(8, 18)
	if cats_far.get_child_count() + cats_near.get_child_count() >= 2:
		return   # больше двух котов сразу не надо
	var c = Cat.new()
	c.main = self
	c.color = Art.cats.keys().pick_random()
	if cats_near.get_child_count() == 0 and weather.rain_level < 0.3 and randf() < 0.45:
		# кот приходит поближе и садится в углу
		c.size_name = "big"
		c.mode = "in"
		if randf() < 0.5:
			c.spot_x = 92.0     # слева, смотрит вправо
			c.dir = 1
			c.position = Vector2(-70, Cat.NEAR_Y)
		else:
			c.spot_x = 388.0    # справа, смотрит влево
			c.dir = -1
			c.position = Vector2(550, Cat.NEAR_Y)
		cats_near.add_child(c)
	else:
		# кот просто проходит по тропинке
		if randf() < 0.5:
			c.dir = 1
			c.position = Vector2(-60, Cat.PATH_Y)
		else:
			c.dir = -1
			c.position = Vector2(540, Cat.PATH_Y)
		cats_far.add_child(c)
	c.setup()
	Sfx.play("rustle")


func scare_cats(x, radius):
	for c in cats_near.get_children():
		if abs(c.position.x - x) < radius:
			c.scare(x)


# ---------- экран ----------

func shake(power, seconds):
	shake_power = power
	shake_time = seconds


func update_shake(d):
	if shake_time > 0:
		shake_time -= d
		var s = shake_power * max(shake_time, 0.0) / 0.4
		camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
		# немного приближаем, чтобы при тряске не был виден край картинки
		camera.zoom = Vector2.ONE * 240.0 / (240.0 - s)
	else:
		camera.offset = Vector2.ZERO
		camera.zoom = Vector2.ONE


func flash_screen(color, seconds):
	flash.color = color
	var t = create_tween()
	t.tween_interval(seconds)
	t.tween_property(flash, "color:a", 0.0, 0.1)


func update_sound_timers(d):
	# звук нового уровня
	if level_sound_timer > 0:
		level_sound_timer -= d
		if level_sound_timer <= 0:
			Sfx.play("level")
	# музыка в конце игры
	if end_sound_timer > 0:
		end_sound_timer -= d
		if end_sound_timer <= 0 and state == "over":
			Sfx.play(end_sound)


# ---------- меню, начало, конец, пауза ----------

func show_menu():
	state = "menu"
	get_tree().paused = false
	end_sound_timer = 0.0
	clear_field()
	basket.visible = false
	basket.clear_pile()
	ui.show_menu(records)


func clear_field():
	for f in items.get_children():
		f.queue_free()
	for n in fx.get_children():
		n.queue_free()
	weather.clear_strike()
	basket.stun = 0.0


func _on_again():
	start_game(mode)


func start_game(new_mode):
	mode = new_mode
	score = 0
	lives = START_LIVES
	time_left = GAME_TIME
	last_second = int(GAME_TIME)
	level = 1
	spawn_timer = 0.4
	end_sound_timer = 0.0
	reset_streak()
	clear_field()
	basket.clear_pile()
	basket.visible = true
	basket.position.x = 240
	basket.speed = 0.0
	basket.reset_physics_interpolation()
	get_tree().paused = false
	ui.show_game()
	Sfx.play("start")
	state = "game"
	ui.toast(Weather.TOAST[weather.shown])   # сразу пишем правило текущей погоды
	update_hud()


func end_game():
	state = "over"
	clear_field()
	var is_record = score > records[mode]
	if is_record:
		records[mode] = score
		save_records()
	var title = "Сезон окончен!"
	var reason = "Жизни кончились"
	if mode == "time":
		title = "Время вышло!"
		reason = "30 секунд прошли"
	ui.show_end(title, reason, score, level, records[mode], is_record)
	# через секунду играет музыка конца или рекорда
	end_sound = "over"
	if is_record:
		end_sound = "record"
	end_sound_timer = 0.85


func toggle_pause():
	if state == "game":
		state = "pause"
		get_tree().paused = true
		flash.color.a = 0.0
		Sfx.set_loop("purr", 0.0)
		ui.show_pause(true)
	elif state == "pause":
		state = "game"
		get_tree().paused = false
		ui.show_pause(false)


func _unhandled_input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k = event.physical_keycode
	if state == "menu":
		if k == KEY_2 or k == KEY_KP_2:
			start_game("time")
		elif k in [KEY_1, KEY_KP_1, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_LEFT, KEY_RIGHT]:
			start_game("lives")
	elif state == "over":
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			start_game(mode)
		elif k == KEY_ESCAPE:
			show_menu()
	elif k == KEY_SPACE or k == KEY_ESCAPE:
		toggle_pause()


# ---------- рекорды ----------

func load_records():
	var f = FileAccess.open(RECORD_FILE, FileAccess.READ)
	if f == null:
		return   # файла ещё нет, значит рекордов пока нет
	for line in f.get_as_text().split("\n", false):
		var parts = line.split(" ")
		if parts.size() == 2 and records.has(parts[0]):
			records[parts[0]] = int(parts[1])


func save_records():
	var f = FileAccess.open(RECORD_FILE, FileAccess.WRITE)
	if f:
		for key in records:
			f.store_line(key + " " + str(records[key]))
