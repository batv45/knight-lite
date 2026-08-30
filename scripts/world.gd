extends Node2D
## Faz 2 test dünyası: zemin + oyuncu + kamera + touch kontrol + HUD + canavarlar.
## Canavar öldüğünde bir süre sonra dünyada rastgele bir yerde yenisi doğar,
## böylece "öldür-tekrar öldür" döngüsü (Faz 3'te XP/level ile beslenecek) test edilebiliyor.

const WORLD_SIZE := Vector2(2400, 1350)
const ENEMY_COUNT := 3
const ENEMY_RESPAWN_DELAY := 4.0
const ENEMY_SPAWN_MARGIN := 200.0

var _hud: CanvasLayer

func _ready() -> void:
	_build_ground()
	var player := _spawn_player()
	_attach_camera(player)
	_add_touch_controls()

	_hud = load("res://scenes/HUD.tscn").instantiate()
	add_child(_hud)
	player.health_changed.connect(_hud.set_player_hp)
	_hud.set_player_hp(player.hp, player.MAX_HP)

	for i in ENEMY_COUNT:
		_spawn_enemy_at(_random_enemy_position())

	_maybe_take_dev_screenshot(player)

func _build_ground() -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.16, 0.35, 0.16) # koyu yeşil = zemin (placeholder)
	ground.size = WORLD_SIZE
	ground.position = Vector2.ZERO
	ground.z_index = -10
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

func _spawn_player() -> CharacterBody2D:
	var player: CharacterBody2D = load("res://scenes/Player.tscn").instantiate()
	player.position = WORLD_SIZE / 2.0
	add_child(player)
	return player

func _attach_camera(target: Node2D) -> void:
	var cam := Camera2D.new()
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

func _spawn_enemy_at(pos: Vector2) -> CharacterBody2D:
	var enemy: CharacterBody2D = load("res://scenes/Enemy.tscn").instantiate()
	enemy.position = pos
	add_child(enemy)
	enemy.died.connect(func(xp_reward: int) -> void:
		_hud.add_kill(xp_reward)
		await get_tree().create_timer(ENEMY_RESPAWN_DELAY).timeout
		_spawn_enemy_at(_random_enemy_position())
	)
	return enemy

## Ekranı olmayan (headless/server) ortamda görsel doğrulama için: proje
## `-- --screenshot` argümanıyla çalıştırılırsa oyuncunun hemen yanına garanti
## menzilde bir test canavarı koyup öldürür (hasar/HP/ölüm/respawn zincirini
## uçtan uca doğrulamak için), sonra res://screenshot.png'ye kaydedip çıkar.
## Oyun mantığının bir parçası değil, sadece geliştirici aracı.
func _maybe_take_dev_screenshot(player: CharacterBody2D) -> void:
	if "--screenshot" not in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(0.2).timeout

	var dummy := _spawn_enemy_at(player.global_position + Vector2(40, 0))

	InputBridge.set_move_vector(Vector2.RIGHT)
	await get_tree().create_timer(0.15).timeout
	InputBridge.set_move_vector(Vector2.ZERO)

	for i in 5:
		InputBridge.request_attack()
		await get_tree().create_timer(0.5).timeout

	print("Test canavarı hâlâ hayatta mı: ", is_instance_valid(dummy))

	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshot.png")
	print("Screenshot kaydedildi: screenshot.png")
	get_tree().quit()
