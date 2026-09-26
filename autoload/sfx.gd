extends Node

# Звуки. Эффекты идут через шину SFX, звуки погоды и мурлыканье - через шину Ambient.
# Чтобы звуки не сливались в кашу: у каждого есть важность, сразу играет не больше 4 эффектов,
# один и тот же звук не повторяется слишком часто, а громкие звуки ненадолго приглушают фон.

const MAX_VOICES = 4
# важность звука: чем больше, тем важнее
const PRIORITY = {"click": 5, "start": 5, "record": 5, "over": 5, "bomb": 5, "lightning": 5, "zap": 5,
	"level": 4, "combo": 4, "gold": 4, "can": 4, "tick": 4, "star_catch": 4, "lightning_warn": 4,
	"apple": 3, "pear": 3, "golden_hour": 3,
	"miss": 2, "thunder": 2, "gust": 2, "meow": 2, "chirp": 2, "star_fall": 2, "storm_start": 2,
	"splash": 1, "bounce": 1, "bump": 1, "whoosh": 1, "rustle": 1}
# через сколько секунд звук можно играть снова
const COOLDOWN = {"bounce": 0.15, "bump": 0.09, "splash": 0.1, "miss": 0.08, "whoosh": 0.3, "rustle": 0.8,
	"gust": 2.0, "meow": 4.0, "chirp": 2.0, "thunder": 4.0, "tick": 0.4, "star_fall": 1.0}

var variants = {}       # имя звука -> несколько вариантов (apple_1, apple_2, apple_3)
var loops = {}          # звуки по кругу (фон погоды, мурлыканье)
var last_variant = {}
var last_played = {}
var ambient_bus = 0
var ambient_db = -3.0
var duck_time = 0.0     # сколько ещё фон приглушён


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	make_bus("SFX", -3.0)
	ambient_bus = make_bus("Ambient", -3.0)
	# раскладываю файлы по именам: apple_1.wav и apple_2.wav -> "apple"
	var files = {}
	for f in DirAccess.get_files_at("res://sounds"):
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if not f.ends_with(".wav"):
			continue
		var n = f.get_basename().rstrip("0123456789").rstrip("_")
		if not files.has(n):
			files[n] = []
		if not f in files[n]:
			files[n].append(f)
	for n in files:
		# если есть варианты apple_1..3, то простой apple.wav не беру
		var list = []
		for f in files[n]:
			if f.get_basename() != n:
				list.append(f)
		if list.is_empty():
			list = files[n]
		for f in list:
			var stream = load("res://sounds/" + f)
			var p = AudioStreamPlayer.new()
			p.stream = stream
			add_child(p)
			if n.begins_with("amb_") or n == "purr":
				# этот звук играет по кругу, сначала без громкости
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
				p.bus = "Ambient"
				p.volume_db = -80.0
				p.play()
				loops[n] = p
			else:
				p.bus = "SFX"
				if not variants.has(n):
					variants[n] = []
				variants[n].append(p)


func make_bus(bus_name, db):
	var i = AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, db)
	return i


func play(n, volume_db = 0.0):
	if not variants.has(n):
		return false
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_played.get(n, -99.0) < COOLDOWN.get(n, 0.05):
		return false   # только что звучал
	var importance = PRIORITY.get(n, 2)
	# сколько звуков уже играет
	var playing = []
	for list in variants.values():
		for p in list:
			if p.playing:
				playing.append(p)
	if playing.size() >= MAX_VOICES:
		# ищу самый неважный звук
		var weakest = playing[0]
		for p in playing:
			if p.get_meta("importance", 2) < weakest.get_meta("importance", 2):
				weakest = p
		if weakest.get_meta("importance", 2) >= importance:
			return false   # все играющие звуки важнее - этот пропускаю
		weakest.stop()     # неважный звук уступает место
	# выбираю вариант, который не играл в прошлый раз
	var free = []
	for p in variants[n]:
		if not p.playing and p != last_variant.get(n):
			free.append(p)
	if free.is_empty():
		free = variants[n]
	var player = free.pick_random()
	last_variant[n] = player
	last_played[n] = now
	player.set_meta("importance", importance)
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.96, 1.04)   # чуть выше или ниже, чтобы не надоедало
	player.play()
	if importance >= 5:
		duck(player.stream.get_length())
	return true


func set_loop(n, amount):
	# amount от 0 до 1 - насколько громко играет звук по кругу
	if loops.has(n):
		if amount > 0.003:
			loops[n].volume_db = linear_to_db(amount)
		else:
			loops[n].volume_db = -80.0


func duck(seconds):
	# громкий звук: фон на время становится тише
	duck_time = max(duck_time, seconds)


func _process(delta):
	if duck_time > 0:
		duck_time -= delta
		ambient_db = move_toward(ambient_db, -8.0, delta * 100.0)   # быстро тише
	else:
		ambient_db = move_toward(ambient_db, -3.0, delta * 4.0)     # потом плавно обратно
	AudioServer.set_bus_volume_db(ambient_bus, ambient_db)
