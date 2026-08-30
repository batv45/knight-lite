extends Node2D
## Faz 4 test dünyası: zemin + oyuncu + kamera + touch kontrol + HUD + canavarlar + loot.
## Canavar tipi, spawn noktasına olan mesafeye göre seçilir (zorluk eğrisi).
## Canavar öldüğünde: oyuncuya XP verilir, dünyaya bir altın drop'u düşer, birkaç
## saniye sonra rastgele bir yerde yeni canavar doğar (öldür-kas-tekrar döngüsü).

const WORLD_SIZE := Vector2(2400, 1350)
const ENEMY_COUNT := 10
const ENEMY_RESPAWN_DELAY := 4.0
const ENEMY_SPAWN_MARGIN := 200.0

## Zorluk eğrisi: spawn noktasına (dünya merkezi) olan mesafeye göre canavar tipi
## seçilir. Merkeze yakın zayıf canavarlar, uzaklaştıkça güçlüleri, en uçlarda
## nadiren boss-tier (big_demon) çıkar.
func _pick_enemy_type(pos: Vector2) -> String:
	var dist := pos.distance_to(WORLD_SIZE / 2.0)
	if dist < 400.0:
		return "goblin"
	elif dist < 750.0:
		return "goblin" if randf() < 0.5 else "skelet"
	elif dist < 1050.0:
		return "skelet" if randf() < 0.7 else "orc_warrior"
	else:
		return "big_demon" if randf() < 0.15 else "orc_warrior"

var _hud: CanvasLayer
var _player: CharacterBody2D

func _ready() -> void:
	_build_ground()
	_build_world_bounds()
	_player = _spawn_player()
	_attach_camera(_player)
	_add_touch_controls()

	_hud = load("res://scenes/HUD.tscn").instantiate()
	_hud.world_size = WORLD_SIZE
	add_child(_hud)
	_player.health_changed.connect(_hud.set_player_hp)
	_player.xp_changed.connect(_hud.set_xp)
	_player.gold_changed.connect(_hud.set_gold)
	_player.leveled_up.connect(_hud.announce_level_up)
	_hud.set_player_hp(_player.hp, _player.max_hp)
	_hud.set_xp(_player.xp, _player.xp_to_next, _player.level)
	_hud.set_gold(_player.gold)

	for i in ENEMY_COUNT:
		_spawn_enemy_at(_random_enemy_position())

	_maybe_take_dev_screenshot()

## Kenney "Roguelike/RPG Pack" spritesheet'i: 16x16 tile, tile'lar arası 1px boşluk.
## Koordinatlar spritesheet'i inceleyip bulundu (bkz. app/assets/tiles/).
const TILE_SIZE := 16
const GRASS_COORD := Vector2i(5, 0)

func _build_ground() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/tiles/roguelike_sheet.png")
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas.separation = Vector2i(1, 1)
	atlas.create_tile(GRASS_COORD)
	var source_id := tile_set.add_source(atlas)

	var ground := TileMapLayer.new()
	ground.tile_set = tile_set
	ground.z_index = -10
	add_child(ground)

	var tiles_x := int(WORLD_SIZE.x / TILE_SIZE)
	var tiles_y := int(WORLD_SIZE.y / TILE_SIZE)
	for y in tiles_y:
		for x in tiles_x:
			ground.set_cell(Vector2i(x, y), source_id, GRASS_COORD)

## Karakterin (ve canavarların) dünya sınırlarının dışına çıkmasını engelleyen
## görünmez duvarlar. StaticBody2D olduğu için move_and_slide() kullanan tüm
## CharacterBody2D'ler (Player, Enemy) otomatik olarak buna çarpar, ekstra kod gerekmez.
const WALL_THICKNESS := 64.0

func _build_world_bounds() -> void:
	_add_wall(Vector2(WORLD_SIZE.x / 2.0, -WALL_THICKNESS / 2.0), Vector2(WORLD_SIZE.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall(Vector2(WORLD_SIZE.x / 2.0, WORLD_SIZE.y + WALL_THICKNESS / 2.0), Vector2(WORLD_SIZE.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall(Vector2(-WALL_THICKNESS / 2.0, WORLD_SIZE.y / 2.0), Vector2(WALL_THICKNESS, WORLD_SIZE.y + WALL_THICKNESS * 2.0))
	_add_wall(Vector2(WORLD_SIZE.x + WALL_THICKNESS / 2.0, WORLD_SIZE.y / 2.0), Vector2(WALL_THICKNESS, WORLD_SIZE.y + WALL_THICKNESS * 2.0))

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
	cam.zoom = Vector2(2.5, 2.5) # 16px tile'lar/sprite'lar mobilde okunaklı büyüklükte görünsün (Godot'ta yüksek zoom = yakınlaşma)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WORLD_SIZE.x)
	cam.limit_bottom = int(WORLD_SIZE.y)
	cam.position_smoothing_enabled = true
	target.add_child(cam)
	cam.make_current()

func _add_touch_controls() -> void:
	add_child(load("res://scenes/TouchControls.tscn").instantiate())

func _random_enemy_position() -> Vector2:
	return Vector2(
		randf_range(ENEMY_SPAWN_MARGIN, WORLD_SIZE.x - ENEMY_SPAWN_MARGIN),
		randf_range(ENEMY_SPAWN_MARGIN, WORLD_SIZE.y - ENEMY_SPAWN_MARGIN)
	)

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
## `-- --screenshot` argümanıyla çalıştırılırsa oyuncunun hemen yanına garanti
## menzilde bir test canavarı koyup öldürür, üzerine düşen altını toplar, sonra
## res://screenshot.png'ye kaydedip çıkar. Oyun mantığının bir parçası değil,
## sadece geliştirici aracı.
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

	# Ölünce düşen altını toplamak için üzerine doğru birazcık daha yürü.
	InputBridge.set_move_vector(Vector2.RIGHT)
	await get_tree().create_timer(0.4).timeout
	InputBridge.set_move_vector(Vector2.ZERO)
	await get_tree().create_timer(0.3).timeout

	print("Oyuncu XP/level/altın: ", _player.xp, "/", _player.xp_to_next, " lvl=", _player.level, " gold=", _player.gold)

	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshot.png")
	print("Screenshot kaydedildi: screenshot.png")
	get_tree().quit()
