extends Node2D
## Faz 1 test dünyası: düz renkli zemin + oyuncu + oyuncuyu takip eden kamera +
## dokunmatik kontrol katmanı. İleride TileMap tabanlı gerçek açık dünya ile
## değişecek, ama Player/InputBridge/TouchControls mimarisi aynı kalacak.

const WORLD_SIZE := Vector2(2400, 1350)

func _ready() -> void:
	_build_ground()
	var player := _spawn_player()
	_attach_camera(player)
	_add_touch_controls()
	_maybe_take_dev_screenshot()

## Ekranı olmayan (headless/server) ortamda görsel doğrulama için: proje
## `-- --screenshot` argümanıyla çalıştırılırsa birkaç kare bekleyip
## res://screenshot.png dosyasına kaydeder ve çıkar. Oyun mantığının bir
## parçası değil, sadece geliştirici aracı.
func _maybe_take_dev_screenshot() -> void:
	if "--screenshot" not in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshot.png")
	print("Screenshot kaydedildi: screenshot.png")
	get_tree().quit()

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
