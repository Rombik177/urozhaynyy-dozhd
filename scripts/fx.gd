extends Node2D

# Эффекты: брызги, взрыв, пыль (анимации из картинок), разлёт частиц и надписи "+1".


func flipbook(n, pos, fps = 30.0):
	# проигрывает анимацию из картинок один раз и удаляет её
	var a = AnimatedSprite2D.new()
	var sf = SpriteFrames.new()
	for t in Art.fx[n]:
		sf.add_frame("default", t)
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", false)
	a.sprite_frames = sf
	a.position = pos
	add_child(a)
	a.play()
	a.animation_finished.connect(a.queue_free)


func burst(pos, colors, count, power):
	# разлёт маленьких частиц нужного цвета
	for c in colors:
		var p = CPUParticles2D.new()
		p.texture = Art.parts[c]
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = max(1, int(count / colors.size()))
		p.lifetime = 0.7
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = power * 0.35
		p.initial_velocity_max = power
		p.gravity = Vector2(0, 700)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = g
		p.position = pos
		add_child(p)
		p.emitting = true
		get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func popup(pos, text, color, size = 22, strong = false):
	# надпись улетает вверх и исчезает
	var l = Label.new()
	l.text = text
	var s = LabelSettings.new()
	s.font = get_parent().ui.bold
	s.font_size = size
	s.font_color = color
	# у минусов обводка толще, чтобы было видно на любом фоне
	if strong:
		s.outline_size = 10
		s.outline_color = Color("1a0c06")
	else:
		s.outline_size = 6
		s.outline_color = Color("2a1a0e")
	l.label_settings = s
	var w = max(120.0, text.length() * size * 0.6)
	var box = Rect2(pos - Vector2(w / 2, 16), Vector2(w, size + 10))
	# если место занято другой надписью - сдвигаю на строчку
	var step = -26.0
	if pos.y < 213:
		step = 26.0
	for i in 6:
		if not busy(box):
			break
		box.position.y += step
	l.position = box.position
	l.size = box.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var t = create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 45, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


func busy(box):
	# проверяю, не налезет ли надпись на объявление погоды или на другую надпись
	if get_parent().ui.toast_l.text != "" and box.intersects(Rect2(0, 58, 480, 44)):
		return true
	for n in get_children():
		if n is Label and n.modulate.a > 0.3 and box.grow(3).intersects(Rect2(n.position, n.size)):
			return true
	return false
