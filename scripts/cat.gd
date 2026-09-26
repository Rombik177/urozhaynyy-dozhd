extends AnimatedSprite2D
class_name Cat

# Кот. Проходит по тропинке или приходит поближе, садится и смотрит на яблоки.
# Убегает от молнии, взрыва, дождя и если корзинка подъехала слишком близко.

const NEAR_Y = 624.0
const PATH_Y = 550.0
const FEAR = 80.0       # ближе этого корзинку не подпускает

var main
var color = "ginger"
var size_name = "small" # small - далеко на тропинке, big - рядом
var mode = "path"       # path, in, sitting, watch, standing, out, flee
var dir = 1             # 1 - идёт вправо, -1 - влево
var spot_x = 0.0        # где сядет
var watch = 0.0
var meow_timer = 6.0
var look_hold = 0.0


func setup():
	sprite_frames = Art.cats[color][size_name]
	centered = false
	face(dir)
	play("walk")


func face(d):
	# все картинки кота смотрят вправо, влево - просто отражаем
	dir = d
	flip_h = d < 0
	var a = Art.cat_info["colors"][color][size_name]
	if d < 0:
		offset = Vector2(-(a["w"] - a["ax"]), -a["ay"])
	else:
		offset = Vector2(-a["ax"], -a["ay"])


func stride_speed(action):
	# скорость по длине шага, чтобы лапы не скользили по траве
	var ppm = Art.cat_info["colors"][color][size_name]["px_per_m"]
	var frames = sprite_frames.get_frame_count(action)
	return float(Art.cat_info["stride"][action]) * ppm * sprite_frames.get_animation_speed(action) / frames


func scare(from_x):
	if mode == "in" or mode == "sitting" or mode == "watch" or mode == "standing":
		mode = "flee"
		if position.x > from_x:
			face(1)    # убегает в другую сторону
		else:
			face(-1)
		play("run")
		Sfx.play("rustle")


func _process(delta):
	delta = min(delta, 0.05)
	# коты не любят дождь
	if (mode == "sitting" or mode == "watch" or mode == "standing") and main.weather.rain_level > 0.4:
		scare(position.x - dir)
	# корзинка подъехала слишком близко
	if main.state == "game" and size_name == "big" and abs(main.basket.position.x - position.x) < FEAR:
		scare(main.basket.position.x)
	if mode == "path":
		var action = "walk"
		if main.weather.rain_level > 0.5:
			action = "run"
		if animation != action:
			play(action)
		position.x += dir * stride_speed(action) * delta
	elif mode == "in":
		position.x += dir * stride_speed("walk") * delta
		if (position.x - spot_x) * dir >= 0:
			position.x = spot_x
			mode = "sitting"
			play("sit")
	elif mode == "sitting":
		if not is_playing():
			mode = "watch"
			watch = randf_range(9, 15)
			play("idle")
	elif mode == "watch":
		main.purr = 0.55
		watch -= delta
		meow_timer -= delta
		look_at_fruit(delta)
		if meow_timer <= 0:
			meow_timer = randf_range(6, 12)
			play("meow")
			Sfx.play("meow")
		if watch <= 0:
			mode = "standing"
			play_backwards("sit")   # встаёт - те же кадры, только наоборот
	elif mode == "standing":
		if not is_playing():
			mode = "out"
			face(-dir)              # уходит туда, откуда пришёл
			play("walk")
	elif mode == "out":
		position.x += dir * stride_speed("walk") * delta
	elif mode == "flee":
		position.x += dir * stride_speed("run") * delta
	if position.x < -90 or position.x > 570:
		queue_free()


func look_at_fruit(delta):
	# кот поворачивает голову за самым нижним фруктом
	if animation == "meow" and is_playing():
		return
	var target = main.lowest_fruit()
	if target == null:
		if animation != "idle":
			play("idle")
		return
	look_hold -= delta
	if look_hold > 0:
		return
	look_hold = 0.14
	var head = position + Vector2(dir * 30, -75)
	var dx = (target.position.x - head.x) * dir   # плюс - впереди кота, минус - сзади
	var dy = head.y - target.position.y           # плюс - выше головы
	var elevation = rad_to_deg(atan2(dy, max(abs(dx), 1.0)))
	var yaw = 135
	if dx > 70:
		yaw = 0
	elif dx > -45:
		yaw = 45
	var pitch = 50
	if elevation < 12:
		pitch = 0
	elif elevation < 38:
		pitch = 25
	var a = "look_" + str(yaw) + "_" + str(pitch)
	if sprite_frames.has_animation(a):
		play(a)
	if target.kind == "gold" and randf() < 0.02:
		Sfx.play("chirp")
