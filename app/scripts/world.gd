extends Node2D
## Oyun dünyası: oyuncu, canavarlar, loot, kamera ve HUD'u kurar.
## Görsel dünya üretimi (zemin, göl, yollar, kasaba, ormanlar) world_gen.gd'de.
##
## Canavar tipi, kasabaya olan mesafeye göre seçilir (zorluk eğrisi).
## Canavar öldüğünde: oyuncuya XP verilir, altın drop'u düşer, birkaç saniye
## sonra uygun bir yerde yeni canavar doğar (öldür-kas-tekrar döngüsü).

const WORLD_SIZE := Vector2(2400, 1350)
const ENEMY_COUNT := 14
const ENEMY_RESPAWN_DELAY := 4.0
const ENEMY_SPAWN_MARGIN := 120.0
const WALL_THICKNESS := 64.0

var _gen: WorldGen
var _hud: CanvasLayer
var _player: CharacterBody2D

func _ready() -> void:
	y_sort_enabled = true # oyuncu/canavar/ağaç/ev Y konumuna göre doğru sıralansın

	_gen = WorldGen.new(self, WORLD_SIZE)
	_gen.build()
	_build_world_bounds()

	_player = _spawn_player()
	_attach_camera(_player)
	_add_touch_controls()
	_setup_hud()

	for i in ENEMY_COUNT:
		_spawn_enemy_at(_random_enemy_position())

	_maybe_take_dev_screenshot()

func _setup_hud() -> void:
	_hud = load("res://scenes/HUD.tscn").instantiate()
	_hud.world_size = WORLD_SIZE
	add_child(_hud)
	_player.health_changed.connect(_hud.set_player_hp)
	_player.mp_changed.connect(_hud.set_player_mp)
	_player.xp_changed.connect(_hud.set_xp)
	_player.gold_changed.connect(_hud.set_gold)
	_player.leveled_up.connect(_hud.announce_level_up)
	_player.target_changed.connect(_hud.set_target)
	_hud.set_player_hp(_player.hp, _player.max_hp)
	_hud.set_player_mp(_player.mp, _player.max_mp)
	_hud.set_xp(_player.xp, _player.xp_to_next, _player.level)
	_hud.set_gold(_player.gold)

## Zorluk eğrisi: kasabaya (dünya merkezi) olan mesafeye göre canavar tipi.
## Kasabaya yakın zayıf canavarlar, uzaklaştıkça güçlüleri, en uçlarda nadiren
## boss-tier (big_demon) çıkar.
func _pick_enemy_type(pos: Vector2) -> String:
	var dist := pos.distance_to(WORLD_SIZE / 2.0)
	if dist < 500.0:
		return "goblin"
	elif dist < 800.0:
		return "goblin" if randf() < 0.5 else "skelet"
	elif dist < 1050.0:
		return "skelet" if randf() < 0.7 else "orc_warrior"
	else:
		return "big_demon" if randf() < 0.15 else "orc_warrior"

## Karakterin (ve canavarların) dünya sınırlarının dışına çıkmasını engelleyen
## görünmez duvarlar. StaticBody2D olduğu için move_and_slide() kullanan tüm
## CharacterBody2D'ler otomatik olarak buna çarpar, ekstra kod gerekmez.
func _build_world_bounds() -> void:
	var half := WALL_THICKNESS / 2.0
	var wide := Vector2(WORLD_SIZE.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	var tall := Vector2(WALL_THICKNESS, WORLD_SIZE.y + WALL_THICKNESS * 2.0)
	_add_wall(Vector2(WORLD_SIZE.x / 2.0, -half), wide)
	_add_wall(Vector2(WORLD_SIZE.x / 2.0, WORLD_SIZE.y + half), wide)
	_add_wall(Vector2(-half, WORLD_SIZE.y / 2.0), tall)
	_add_wall(Vector2(WORLD_SIZE.x + half, WORLD_SIZE.y / 2.0), tall)

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)

func _spawn_player() -> CharacterBody2D:
	var player: CharacterBody2D = load("res://scenes/Player.tscn").instantiate()
	player.position = WORLD_SIZE / 2.0
	add_child(player)
	return player

func _attach_camera(target: Node2D) -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2(2.5, 2.5) # 16px tile/sprite'lar mobilde okunaklı boyutta görünsün
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WORLD_SIZE.x)
	cam.limit_bottom = int(WORLD_SIZE.y)
	cam.position_smoothing_enabled = true
	target.add_child(cam)
	cam.make_current()

func _add_touch_controls() -> void:
	add_child(load("res://scenes/TouchControls.tscn").instantiate())

## Kasabanın, yolların ve gölün dışında bir doğma noktası bulur.
func _random_enemy_position() -> Vector2:
	var pos := Vector2.ZERO
	for attempt in 20:
		pos = Vector2(
			randf_range(ENEMY_SPAWN_MARGIN, WORLD_SIZE.x - ENEMY_SPAWN_MARGIN),
			randf_range(ENEMY_SPAWN_MARGIN, WORLD_SIZE.y - ENEMY_SPAWN_MARGIN)
		)
		if _gen.is_spawn_safe(pos):
			break
	return pos

func _spawn_enemy_at(pos: Vector2, forced_type: String = "") -> CharacterBody2D:
	var enemy: CharacterBody2D = load("res://scenes/Enemy.tscn").instantiate()
	enemy.type_id = forced_type if forced_type != "" else _pick_enemy_type(pos)
	enemy.position = pos
	add_child(enemy)
	enemy.died.connect(func(xp_reward: int) -> void:
		_hud.add_kill(xp_reward)
		if is_instance_valid(_player):
			_player.gain_xp(xp_reward)
		_spawn_pickup(enemy.global_position)
		await get_tree().create_timer(ENEMY_RESPAWN_DELAY).timeout
		_spawn_enemy_at(_random_enemy_position())
	)
	return enemy

func _spawn_pickup(pos: Vector2) -> void:
	var pickup: Area2D = load("res://scenes/Pickup.tscn").instantiate()
	pickup.position = pos
	add_child(pickup)

## Ekranı olmayan (headless/server) ortamda görsel doğrulama için: proje
## `-- --screenshot` argümanıyla çalıştırılırsa oyuncunun yanına garanti menzilde
## bir test canavarı koyup öldürür, düşen altını toplar, sonra
## res://screenshot.png'ye kaydedip çıkar. Oyun mantığının parçası değil.
func _maybe_take_dev_screenshot() -> void:
	if "--screenshot" not in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(0.2).timeout

	var dummy := _spawn_enemy_at(_player.global_position + Vector2(40, 0), "goblin")

	InputBridge.set_move_vector(Vector2.RIGHT)
	await get_tree().create_timer(0.15).timeout
	InputBridge.set_move_vector(Vector2.ZERO)

	for i in 5:
		InputBridge.request_attack()
		await get_tree().create_timer(0.5).timeout

	print("Test canavarı hâlâ hayatta mı: ", is_instance_valid(dummy))

	InputBridge.set_move_vector(Vector2.RIGHT)
	await get_tree().create_timer(0.4).timeout
	InputBridge.set_move_vector(Vector2.ZERO)
	await get_tree().create_timer(0.3).timeout

	print("Oyuncu XP/level/altın: ", _player.xp, "/", _player.xp_to_next, " lvl=", _player.level, " gold=", _player.gold)

	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshot.png")
	print("Screenshot kaydedildi: screenshot.png")
	get_tree().quit()
