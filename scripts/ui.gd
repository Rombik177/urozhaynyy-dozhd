extends CanvasLayer

# Всё, что на экране поверх игры: меню, счёт, сердечки, надписи про погоду, пауза и конец игры.
# Кнопки и карточки рисую кодом, шрифт Rubik.

signal start_pressed(mode)
signal menu_pressed
signal again_pressed

const INK = Color("3a1f0e")          # тёмно-коричневый для текста и обводки
const CREAM = Color("fbf1da")
const CREAM_DARK = Color("ecd9b3")
const EDGE = Color("c9a36b")
const GREEN = Color("5cb445")
const ORANGE = Color("f08a24")

var bold          # жирный шрифт
var heavy         # ещё жирнее, для заголовков
var plain         # обычный
var hud = Control.new()
var score_l
var combo_l
var level_l
var timer_l
var toast_box
var toast_l
var hearts = []
var vignette
var menu
var end_panel
var pause_panel
var toast_time = 0.0
var letters = []        # буквы заголовка
var bob_icons = []      # значки фруктов в меню, которые качаются
var title_leaves = []   # листики у заголовка
var buttons = []        # кнопки (увеличиваются, когда наводишь мышку)
var main_button         # главная кнопка чуть-чуть "дышит"
var count_label         # счёт в конце игры, числа бегут от нуля
var count_value = 0.0
var count_target = 0
var count_delay = 0.0
var end_title = ""
var end_sentence = ""


func _ready():
	var rubik = load("res://fonts/Rubik-Bold.ttf")
	bold = FontVariation.new()
	bold.base_font = rubik
	heavy = FontVariation.new()
	heavy.base_font = rubik
	heavy.variation_embolden = 0.8
	plain = load("res://fonts/Rubik-Regular.ttf")
	# затемнение по краям экрана в меню (чтобы смотрели в середину)
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(0.08, 0.04, 0.02, 0.0), Color(0.08, 0.04, 0.02, 0.0), Color(0.08, 0.04, 0.02, 0.6)])
	var gt = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.05, 1.08)
	vignette = TextureRect.new()
	vignette.texture = gt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.size = Vector2(480, 640)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	# счёт, уровень, таймер и сердечки
	add_child(hud)
	score_l = text(hud, Vector2(16, 10), 22, Color.WHITE, "", 200)
	combo_l = text(hud, Vector2(16, 40), 16, Color("ffd23f"), "", 200)
	level_l = text(hud, Vector2(90, 13), 17, Color("fff3a0"), "", 300, HORIZONTAL_ALIGNMENT_CENTER)
	timer_l = text(hud, Vector2(300, 10), 22, Color.WHITE, "", 164, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in 3:
		var h = TextureRect.new()
		h.texture = Art.heart
		h.position = Vector2(442 - i * 30, 14)
		hud.add_child(h)
		hearts.append(h)
	# надпись про погоду на тёмной плашке, чтобы читалась на любом небе
	var row = row_center(self, 62, 34)
	toast_box = PanelContainer.new()
	toast_box.add_theme_stylebox_override("panel", box(Color(0.12, 0.07, 0.03, 0.55), 16, 0, Color(), 14, 3))
	row.add_child(toast_box)
	toast_l = Label.new()
	toast_l.label_settings = settings(bold, 18, Color.WHITE, 4, INK)
	toast_box.add_child(toast_l)
	toast_box.visible = false


# ---------- маленькие функции, чтобы не повторять одно и то же ----------

func settings(font, size, color, outline = 0, outline_color = INK):
	var s = LabelSettings.new()
	s.font = font
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = outline_color
	return s


func text(parent, pos, size, color, t = "", width = 0, align = HORIZONTAL_ALIGNMENT_LEFT, is_bold = true, outline = 6):
	var l = Label.new()
	var font = plain
	if is_bold:
		font = bold
	l.label_settings = settings(font, size, color, outline)
	l.text = t
	l.position = pos
	if width > 0:
		l.size = Vector2(width, size + 12)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func box(bg, radius, border = 0, border_color = Color(), pad_x = 0, pad_y = 0):
	# прямоугольник со скруглёнными углами
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


func row_center(parent, y, h):
	# строка на всю ширину экрана, всё что в неё положишь - встанет по центру
	var r = HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.position = Vector2(0, y)
	r.size = Vector2(480, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", 6)
	parent.add_child(r)
	return r


func keycap(parent, t):
	# рисунок клавиши
	var p = PanelContainer.new()
	var sb = box(CREAM, 6, 2, Color("8a6a45"), 7, 1)
	sb.border_width_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l = Label.new()
	l.text = t
	l.label_settings = settings(bold, 14, INK)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func chip(t, good, heart = false):
	# бирка с очками: зелёная - плюс, светлая с красным - минус
	var p = PanelContainer.new()
	var sb
	var l = Label.new()
	l.text = t
	if good:
		sb = box(GREEN, 10, 0, Color(), 9, 1)
		sb.border_width_bottom = 3
		sb.border_color = GREEN.darkened(0.3)
		l.label_settings = settings(bold, 16, Color.WHITE, 3, GREEN.darkened(0.5))
	else:
		sb = box(Color("fff1ec"), 10, 2, Color("d9534a"), 9, 1)
		l.label_settings = settings(bold, 16, Color("c0392b"))
	p.add_theme_stylebox_override("panel", sb)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.add_child(l)
	if heart:
		var tr = TextureRect.new()
		tr.texture = Art.heart
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(17, 17)
		h.add_child(tr)
	p.add_child(h)
	return p


func card(parent, rect, header):
	# светлая карточка с заголовком сверху
	var c = Panel.new()
	var sb = box(Color(CREAM, 0.97), 20, 3, EDGE)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 6)
	c.add_theme_stylebox_override("panel", sb)
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	var top = Panel.new()
	var tb = box(CREAM_DARK, 0)
	tb.corner_radius_top_left = 17
	tb.corner_radius_top_right = 17
	top.add_theme_stylebox_override("panel", tb)
	top.position = Vector2(3, 3)
	top.size = Vector2(rect.size.x - 6, 40)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(top)
	var l = text(c, Vector2(0, 11), 18, INK, header, int(rect.size.x), HORIZONTAL_ALIGNMENT_CENTER, true, 0)
	l.size.y = 24
	return c


func big_button(parent, rect, t, key, color):
	# большая кнопка с объёмным низом, при нажатии "проседает"
	var b = Button.new()
	b.text = t
	b.position = rect.position
	b.size = rect.size
	b.pivot_offset = rect.size / 2
	b.focus_mode = Control.FOCUS_NONE   # Enter и пробел ловит игра, а не кнопка
	for st in ["normal", "hover", "pressed"]:
		var bg = color
		if st == "hover":
			bg = color.lightened(0.12)
		elif st == "pressed":
			bg = color.darkened(0.08)
		var sb = box(bg, 16)
		sb.border_width_bottom = 6
		sb.content_margin_top = 0
		if st == "pressed":
			sb.border_width_bottom = 2
			sb.content_margin_top = 6
		sb.border_color = color.darkened(0.35)
		sb.shadow_color = Color(0, 0, 0, 0.28)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", color.darkened(0.55))
	parent.add_child(b)
	var k = keycap(b, key)   # клавиша на уголке кнопки
	k.position = Vector2(rect.size.x - 26, -9)
	buttons.append(b)
	return b


func title(parent, t, y, size, gradient, fill, depth, delay = 0.0):
	# заголовок по буквам: каждая буква падает сверху и подпрыгивает, как яблоко
	var s = settings(heavy, size, fill, max(8, int(size / 4)), INK)
	if gradient:
		s.font_color = Color.WHITE   # белое шейдер раскрасит градиентом
	s.shadow_color = depth           # тёмная тень снизу - буквы как будто объёмные
	s.shadow_size = s.outline_size
	s.shadow_offset = Vector2(0, max(4, int(size / 9)))
	var mat = null
	if gradient:
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/bukvy.gdshader")
		mat.set_shader_parameter("y0", size * 0.3)
		mat.set_shader_parameter("y1", size * 1.05)
	# считаю ширину слова, чтобы поставить его по центру
	var total = 0.0
	for ch in t:
		total += heavy.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x = 240.0 - total / 2.0
	var now = Time.get_ticks_msec() / 1000.0
	for i in t.length():
		var ch = t[i]
		var w = heavy.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if ch != " ":
			var l = Label.new()
			l.text = ch
			l.label_settings = s
			l.material = mat
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(l)
			l.position = Vector2(x, y - 170)
			l.reset_size()
			l.pivot_offset = l.size / 2
			l.modulate.a = 0.0
			var start = delay + i * 0.055
			var tw = l.create_tween()
			tw.tween_interval(start)
			tw.tween_property(l, "modulate:a", 1.0, 0.08)
			tw.parallel().tween_property(l, "position:y", y, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			letters.append({"label": l, "y": y, "landed": now + start + 0.8, "n": letters.size()})
		x += w


func leaf(parent, pos, deg, sc):
	var tr = TextureRect.new()
	tr.texture = Art.leaf
	tr.position = pos
	tr.scale = Vector2(sc, sc)
	tr.rotation_degrees = deg
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	title_leaves.append([tr, deg, pos.y])


func hint_label(t):
	var l = Label.new()
	l.text = t
	l.label_settings = settings(bold, 15, Color("fff4dc"), 5, INK)
	return l


# ---------- экраны ----------

func show_menu(records):
	clear_panels()
	hud.visible = false
	vignette.visible = true
	menu = Control.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	leaf(menu, Vector2(52, 10), -35.0, 1.5)
	leaf(menu, Vector2(404, 20), 40.0, 1.3)
	title(menu, "УРОЖАЙНЫЙ", 12, 54, true, Color.WHITE, Color("7a2e0e"))
	title(menu, "ДОЖДЬ", 74, 48, false, Color("fff4dc"), Color("5a2a10"), 0.35)
	var c = card(menu, Rect2(24, 148, 432, 312), "Лови фрукты — не лови мусор!")
	# строчки с правилами: значок, название, пояснение и бирки с очками
	var rules = [
		["apple", "Яблоко", "", [["+1", true, false]]],
		["pear", "Груша", "", [["+2", true, false]]],
		["gold", "Золотое яблоко", "редкое, на закате чаще", [["+5", true, false]]],
		["can", "Банка", "на время: −1 очко", [["−1", false, true]]],
		["bomb", "Бомба", "", [["−2", false, false], ["−1", false, true]]]]
	for i in rules.size():
		var r = rules[i]
		var slot = Panel.new()
		slot.add_theme_stylebox_override("panel", box(Color("fffaf0"), 12, 2, Color("e7d3ad")))
		slot.position = Vector2(14, 52 + i * 44)
		slot.size = Vector2(404, 40)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(slot)
		var icon = TextureRect.new()
		icon.texture = Art.icons[r[0]]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(32, 32)
		icon.position = Vector2(10, 4)
		slot.add_child(icon)
		bob_icons.append([icon, i])
		if r[2] == "":
			text(slot, Vector2(52, 9), 17, INK, r[1], 0, HORIZONTAL_ALIGNMENT_LEFT, true, 0)
		else:
			text(slot, Vector2(52, 2), 16, INK, r[1], 0, HORIZONTAL_ALIGNMENT_LEFT, true, 0)
			text(slot, Vector2(52, 20), 13, Color("8a6a45"), r[2], 0, HORIZONTAL_ALIGNMENT_LEFT, false, 0)
		var chips = HBoxContainer.new()
		chips.alignment = BoxContainer.ALIGNMENT_END
		chips.position = Vector2(0, 6)
		chips.size = Vector2(392, 28)
		chips.add_theme_constant_override("separation", 5)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(chips)
		for ch in r[3]:
			chips.add_child(chip(ch[0], ch[1], ch[2]))
	text(c, Vector2(0, 272), 14, Color("7a5634"), "Упустил фрукт — минус сердце", 432, HORIZONTAL_ALIGNMENT_CENTER, false, 0)
	text(c, Vector2(0, 290), 14, Color("7a5634"), "Каждые 14 секунд — новая погода и новые правила", 432,
		HORIZONTAL_ALIGNMENT_CENTER, false, 0)
	# кнопки режимов
	var b1 = big_button(menu, Rect2(24, 474, 208, 58), "Три жизни", "1", GREEN)
	b1.pressed.connect(_on_lives_pressed)
	var b2 = big_button(menu, Rect2(248, 474, 208, 58), "На время 30 с", "2", ORANGE)
	b2.pressed.connect(_on_time_pressed)
	main_button = b1
	# рекорды
	var rec = row_center(menu, 544, 28)
	var pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", box(Color(CREAM, 0.95), 14, 2, EDGE, 12, 2))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rec.add_child(pill)
	var ph = HBoxContainer.new()
	ph.add_theme_constant_override("separation", 6)
	pill.add_child(ph)
	var gi = TextureRect.new()
	gi.texture = Art.icons["gold"]
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gi.custom_minimum_size = Vector2(20, 20)
	ph.add_child(gi)
	var rl = Label.new()
	rl.text = "Рекорд: " + str(records["lives"]) + "   ·   на время: " + str(records["time"])
	rl.label_settings = settings(bold, 15, INK)
	ph.add_child(rl)
	# подсказка про клавиши
	var hint = row_center(menu, 584, 30)
	keycap(hint, "←")
	keycap(hint, "→")
	hint.add_child(hint_label("двигать"))
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(16, 1)
	hint.add_child(gap)
	keycap(hint, "Пробел")
	hint.add_child(hint_label("пауза"))


func show_game():
	clear_panels()
	hud.visible = true
	vignette.visible = false


func show_end(t, reason, score, level, best, is_record):
	clear_panels()
	vignette.visible = true
	end_title = t
	end_sentence = "Ты набрал " + str(score) + " " + word(score) + "."
	end_panel = Control.new()
	end_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(end_panel)
	title(end_panel, t, 108, 44, true, Color.WHITE, Color("7a2e0e"))
	var c = card(end_panel, Rect2(40, 184, 400, 236), reason)
	count_label = text(c, Vector2(0, 66), 28, INK, "", 400, HORIZONTAL_ALIGNMENT_CENTER, true, 0)
	count_label.size.y = 40
	# очки набегают от нуля, как на кассе
	count_value = 0.0
	count_target = score
	count_delay = 0.35
	count_label.text = "Ты набрал 0 очков."
	text(c, Vector2(0, 116), 17, Color("7a5634"), "Дошёл до уровня " + str(level), 400, HORIZONTAL_ALIGNMENT_CENTER, false, 0)
	var badge_row = HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.position = Vector2(0, 160)
	badge_row.size = Vector2(400, 40)
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(badge_row)
	var badge = PanelContainer.new()
	var sb
	if is_record:
		sb = box(Color("ffc21a"), 14, 2, Color("c98a00"), 16, 4)
	else:
		sb = box(Color("fffaf0"), 14, 2, EDGE, 16, 4)
	sb.border_width_bottom = 4
	badge.add_theme_stylebox_override("panel", sb)
	var bl = Label.new()
	if is_record:
		bl.text = "Новый рекорд!"
	else:
		bl.text = "Рекорд: " + str(best)
	bl.label_settings = settings(bold, 20, INK)
	badge.add_child(bl)
	badge_row.add_child(badge)
	if is_record:
		# плашка рекорда выпрыгивает
		badge.pivot_offset = Vector2(80, 18)
		badge.scale = Vector2(0.2, 0.2)
		badge.create_tween().tween_property(badge, "scale", Vector2.ONE, 0.5).set_delay(1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var b1 = big_button(end_panel, Rect2(40, 448, 190, 58), "Ещё раз", "Enter", GREEN)
	b1.pressed.connect(_on_again_pressed)
	var b2 = big_button(end_panel, Rect2(250, 448, 190, 58), "В меню", "Esc", ORANGE)
	b2.pressed.connect(_on_menu_pressed)
	main_button = b1


func show_pause(on):
	if pause_panel != null and is_instance_valid(pause_panel):
		pause_panel.queue_free()
		letters.clear()
	pause_panel = null
	vignette.visible = on
	if not on:
		return
	pause_panel = Control.new()
	pause_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pause_panel)
	var dim = ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.35)
	dim.size = Vector2(480, 640)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(dim)
	title(pause_panel, "Пауза", 250, 56, true, Color.WHITE, Color("7a2e0e"))
	var hint = row_center(pause_panel, 340, 30)
	keycap(hint, "Пробел")
	hint.add_child(hint_label("продолжить"))


# ---------- нажатия на кнопки ----------

func _on_lives_pressed():
	Sfx.play("click")
	start_pressed.emit("lives")


func _on_time_pressed():
	Sfx.play("click")
	start_pressed.emit("time")


func _on_again_pressed():
	Sfx.play("click")
	again_pressed.emit()


func _on_menu_pressed():
	Sfx.play("click")
	menu_pressed.emit()


# ---------- остальное ----------

func word(n):
	# 1 очко, 2 очка, 5 очков
	n = abs(n)
	if n % 10 == 1 and n % 100 != 11:
		return "очко"
	if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 12 or n % 100 > 14):
		return "очка"
	return "очков"


func clear_panels():
	for p in [menu, end_panel, pause_panel]:
		if p != null and is_instance_valid(p):
			p.queue_free()
	menu = null
	end_panel = null
	pause_panel = null
	count_label = null
	main_button = null
	letters.clear()
	bob_icons.clear()
	title_leaves.clear()
	buttons.clear()
	toast_l.text = ""
	toast_box.visible = false


func update_hud(score, level, weather_name, mode, lives, time_left, mult):
	score_l.text = "Счёт: " + str(score)
	level_l.text = "Уровень " + str(level) + "  ·  " + weather_name
	if mult > 1:
		combo_l.text = "Серия ×" + str(mult)
	else:
		combo_l.text = ""
	var sec = int(ceil(max(time_left, 0.0)))
	if mode == "time":
		timer_l.text = str(sec) + " с"
	else:
		timer_l.text = ""
	if sec <= 5:
		timer_l.label_settings.font_color = Color("ff6a50")   # последние секунды красным
	else:
		timer_l.label_settings.font_color = Color.WHITE
	for i in hearts.size():
		hearts[i].visible = mode == "lives"
		if i < lives:
			hearts[i].texture = Art.heart
		else:
			hearts[i].texture = Art.heart_empty


func toast(t):
	toast_l.text = t
	toast_box.visible = true
	toast_time = 2.5


func _process(delta):
	var t = Time.get_ticks_msec() / 1000.0
	# надпись про погоду исчезает через 2.5 секунды
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_l.text = ""
			toast_box.visible = false
	# буквы заголовка: после падения тихо покачиваются
	for d in letters:
		var l = d["label"]
		if not is_instance_valid(l):
			continue
		l.rotation = sin(t * 1.9 + d["n"] * 0.8) * 0.035
		if t > d["landed"]:
			var k = min(1.0, (t - d["landed"]) / 0.5)   # покачивание начинается плавно
			l.position.y = d["y"] + sin(t * 2.4 + d["n"] * 0.55) * 2.5 * k
	# значки фруктов в меню качаются вверх-вниз
	for b in bob_icons:
		if is_instance_valid(b[0]):
			b[0].position.y = 4.0 + 2.0 * sin(t * 2.5 + b[1])
	# листики у заголовка качаются на ветру
	for lf in title_leaves:
		if is_instance_valid(lf[0]):
			lf[0].rotation_degrees = lf[1] + 6.0 * sin(t * 1.6 + lf[2])
	# кнопки чуть увеличиваются под мышкой, а главная кнопка "дышит"
	for b in buttons:
		if not is_instance_valid(b):
			continue
		var target = 1.0
		if b.is_hovered():
			target = 1.05
		elif b == main_button:
			target = 1.0 + 0.022 * sin(t * 3.2)
		b.scale = b.scale.lerp(Vector2(target, target), min(1.0, delta * 12.0))
	# очки в конце игры набегают от нуля
	if count_label != null and is_instance_valid(count_label):
		if count_delay > 0:
			count_delay -= delta
		elif int(round(count_value)) != count_target:
			var speed = max(abs(count_target) / 0.7, 1.0)
			count_value = move_toward(count_value, count_target, speed * delta)
			var n = int(round(count_value))
			count_label.text = "Ты набрал " + str(n) + " " + word(n) + "."
