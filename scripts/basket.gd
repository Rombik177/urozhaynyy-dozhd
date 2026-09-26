extends Node2D
class_name Basket

# Корзинка. Ездит влево-вправо, качается как на пружинке, приседает когда ловит.
# Внутри невидимая чаша, а пойманные фрукты - настоящие физические тела (RigidBody2D),
# поэтому они катаются, толкаются и съезжают, когда корзинка наклоняется.

const Y = 581.0         # на какой высоте стоит корзинка
const SPEED = 540.0     # скорость в пикселях в секунду
const CATCH_W = 46.0    # насколько далеко от середины ещё ловит
const PILE_MAX = 7      # сколько фруктов влезает

var main
var speed = 0.0
var angle = 0.0         # наклон в градусах
var turn = 0.0          # как быстро меняется наклон
var drop = 0.0          # насколько присела
var drop_speed = 0.0
var stun = 0.0          # сколько ещё бьёт током
var fruits = []         # фрукты, которые лежат в корзинке

@onready var back = $Back
@onready var front = $Front
@onready var bowl = $Bowl
@onready var zap = $Zap
@onready var shadow = $Shadow


func _ready():
	position = Vector2(240, Y)
	shadow.texture = Art.shadows[7]
	# делаю невидимую чашу из отрезков: две стенки и дно в виде дуги
	# ширина 92, край на 18 выше середины, дно на 24 ниже
	var segs = PackedVector2Array()
	segs.append(Vector2(-46, -140))  # левая стенка (намного выше края, чтобы фрукты не вылетали)
	segs.append(Vector2(-46, -18))
	segs.append(Vector2(46, -140))   # правая стенка
	segs.append(Vector2(46, -18))
	var prev = Vector2(-46, -18)
	for i in range(1, 21):           # дно из 20 кусочков параболы
		var x = -46.0 + 92.0 * i / 20.0
		var p = Vector2(x, 24.0 - 42.0 * pow(x / 46.0, 2))
		segs.append(prev)
		segs.append(p)
		prev = p
	var shape = ConcavePolygonShape2D.new()
	shape.segments = segs
	$Bowl/Shape.shape = shape


func catches(p):
	# поймала, если фрукт над корзинкой и на её высоте
	return abs(p.x - position.x) < CATCH_W and p.y >= Y - 45 and p.y <= Y + 5


func _physics_process(delta):
	var target = 0.0
	if main.state == "game" and stun <= 0:
		if Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"):
			target = -SPEED
		elif Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"):
			target = SPEED
	stun = max(0.0, stun - delta)
	# разгоняется плавно, а в грозу трава мокрая и корзинку заносит
	var grip = 14.0
	if main.weather.rain_level > 0.5:
		grip = 4.0
	speed += (target - speed) * min(1.0, delta * grip)
	var x = position.x + speed * delta
	if x < 45 or x > 435:
		x = clamp(x, 45, 435)
		speed = 0
	# наклон как на пружинке: наклоняется в сторону движения, потом качается
	turn += (-speed / SPEED * 11.0 - angle) * 170.0 * delta
	turn -= turn * 7.0 * delta
	angle = clamp(angle + turn * delta, -14.0, 14.0)
	# приседание когда поймала (тоже пружинка)
	drop_speed += -drop * 320.0 * delta
	drop_speed -= drop_speed * 13.0 * delta
	drop += drop_speed * delta
	var shake = 0.0
	if stun > 0:
		shake = randf_range(-2.5, 2.5)
	position = Vector2(x, Y + drop)
	# картинка корзинки: 15 кадров наклона от -14 до +14 градусов
	var frame = int(round((angle + 14.0) / 2.0))
	back.texture = Art.basket_back[frame]
	back.position.x = shake
	front.texture = Art.basket_front[frame]
	front.position.x = shake
	# чаша наклоняется вместе с картинкой
	bowl.rotation = -deg_to_rad(angle)
	zap.visible = stun > 0
	if stun > 0:
		zap.texture = Art.zap[int(Time.get_ticks_msec() / 55) % 4]
	shadow.global_position = Vector2(x, 618)


func bounce(power):
	drop_speed += power


func add_fruit(kind, from, vel):
	# если корзинка полная - самый нижний фрукт пропадает
	if fruits.size() >= PILE_MAX:
		var lowest = fruits[0]
		for f in fruits:
			if f.global_position.y > lowest.global_position.y:
				lowest = f
		var color = "yellow"
		if lowest.get_meta("kind") == "apple":
			color = "red"
		main.fx.burst(lowest.global_position, [color], 6, 120.0)
		fruits.erase(lowest)
		lowest.queue_free()
	# пойманный фрукт становится физическим телом
	var b = RigidBody2D.new()
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.5
	col.shape = circle
	b.add_child(col)
	var s = Sprite2D.new()
	s.texture = Art.small[kind]
	b.add_child(s)
	b.mass = 0.15
	var m = PhysicsMaterial.new()
	m.friction = 0.9     # не скользкий
	m.bounce = 0.12      # почти не прыгает
	b.physics_material_override = m
	b.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE   # чтобы быстрый фрукт не пролетел сквозь стенку
	b.can_sleep = false  # а то уснёт и не заметит, что корзинка поехала
	b.contact_monitor = true
	b.max_contacts_reported = 2
	b.body_entered.connect(_on_fruit_hit.bind(b))
	b.set_meta("kind", kind)
	main.pile.add_child(b)
	# новый фрукт появляется над кучей, а не внутри неё (иначе фрукты расталкиваются слишком сильно)
	var top_y = Y - 48
	for f in fruits:
		top_y = min(top_y, f.global_position.y - 26)
	b.global_position = Vector2(clamp(from.x, position.x - 32, position.x + 32), max(min(from.y, top_y), Y - 130))
	b.reset_physics_interpolation()
	b.linear_velocity = Vector2((vel.x - speed) * 0.3, min(vel.y, 400.0) * 0.5)
	fruits.append(b)


func _on_fruit_hit(body, fruit):
	# стук, когда фрукт сильно ударился
	if fruit.linear_velocity.length() > 140:
		Sfx.play("bump")


func knock_out():
	# бомба или молния - фрукты вылетают из корзинки
	for b in fruits:
		b.collision_mask = 0     # больше ни обо что не ударяются
		b.collision_layer = 0
		b.linear_velocity = Vector2(randf_range(-170, 170) + speed * 0.3, randf_range(-560, -380))
		b.angular_velocity = randf_range(-12, 12)
		get_tree().create_timer(1.4).timeout.connect(b.queue_free)
	fruits.clear()


func clear_pile():
	for b in fruits:
		b.queue_free()
	fruits.clear()
