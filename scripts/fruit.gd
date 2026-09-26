extends Node2D
class_name Fruit

# Падающий предмет: яблоко, груша, золотое яблоко, банка, бомба или звезда.
# Падает с ускорением, крутится (72 картинки на полный оборот),
# об траву сплющивается, отскакивает и пропадает.

signal caught(fruit)    # попал в корзинку
signal landed(fruit)    # упал на траву

const GRAVITY = 700.0
const GROUND = 614.0

var main
var kind = "apple"
var speed = 150.0       # самая большая скорость падения
var vy = 45.0
var vx = 0.0
var angle = 0.0
var spin = 120.0
var is_landed = false
var bounces = 0
var squash = 0.0
var whoosh = false
var decor = false       # фрукт для красоты в меню: его не ловят и он не звучит
var sprite = Sprite2D.new()
var shadow = Sprite2D.new()
var sparks


func _ready():
	add_child(sprite)
	shadow.texture = Art.shadows[0]
	main.shadows.add_child(shadow)
	if kind == "gold" or kind == "star":
		add_sparks()


func add_sparks():
	# у золотого яблока и звезды сыплются искорки
	if sparks:
		return
	sparks = CPUParticles2D.new()
	sparks.texture = Art.sparkles[1]
	sparks.amount = 14
	sparks.lifetime = 0.6
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 18.0
	sparks.gravity = Vector2(0, 40)
	sparks.scale_amount_min = 0.5
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	sparks.color_ramp = g
	add_child(sparks)


func _exit_tree():
	if is_instance_valid(shadow):
		shadow.queue_free()


func _process(delta):
	delta = min(delta, 0.05)
	if kind == "star":
		fly_star(delta)
		return
	if is_landed:
		vy += GRAVITY * delta    # после отскока просто падает обратно
		vx *= 0.97               # и катится всё медленнее
	else:
		vy = min(speed, vy + GRAVITY * delta)   # разгоняется до своей скорости
	position.y += vy * delta
	if not is_landed and vy > 330 and not whoosh and not decor:
		whoosh = true
		Sfx.play("whoosh")
	# ветер сносит в сторону
	position.x = clamp(position.x + (main.weather.wind * 0.3 + main.weather.gust_wind * 0.5 + vx) * delta, 25, 455)
	angle += spin * delta
	squash = max(0.0, squash - delta)
	var frame = int(fposmod(angle, 360.0) / 5.0)   # 72 картинки, каждая на 5 градусов
	if squash > 0:
		sprite.texture = Art.items_squash[kind][min(2, int((0.18 - squash) / 0.06))]
		sprite.scale = Vector2.ONE
	else:
		sprite.texture = Art.items[kind][frame]
		# на большой скорости фрукт немного вытягивается, так видно что он быстро летит
		var k = 0.0
		if not is_landed:
			k = clampf((vy - 180.0) / 300.0, 0.0, 1.0) * 0.1
		sprite.scale = Vector2(1.0 - k * 0.45, 1.0 + k)
	update_shadow()
	if not is_landed and not decor and main.basket.catches(position):
		caught.emit(self)
		return
	if position.y >= GROUND - 22 and vy > 0:
		position.y = GROUND - 22
		if not is_landed:
			is_landed = true
			vx = randf_range(-60, 60)
			landed.emit(self)
			if is_queued_for_deletion():   # если из-за этого игра кончилась
				return
		bounces += 1
		squash = 0.18
		if bounces > 1 and not decor:
			Sfx.play("bounce")
		if bounces == 1:
			vy = -max(vy * 0.4, 160.0)
		else:
			vy = -vy * 0.4
		spin *= 0.5
		if bounces >= 3:
			main.fx.flipbook("dust2", Vector2(position.x, GROUND - 16), 24.0)
			queue_free()


func fly_star(delta):
	# звезда летит наискосок и отскакивает от краёв
	position += Vector2(vx, vy) * delta
	if position.x < 20 or position.x > 460:
		vx = -vx
	sprite.texture = Art.stars[int(Time.get_ticks_msec() / 80) % 4]
	update_shadow()
	if main.basket.catches(position):
		caught.emit(self)
	elif position.y > GROUND - 10:
		main.fx.burst(Vector2(position.x, GROUND - 10), ["spark", "white"], 10, 150.0)
		queue_free()


func update_shadow():
	# тень растёт, когда предмет подлетает к земле - так легче целиться
	var k = clampf(position.y / GROUND, 0.0, 1.0)
	shadow.texture = Art.shadows[int(k * 7)]
	shadow.global_position = Vector2(position.x, GROUND)
