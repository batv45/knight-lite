extends Control
## Sağ üstte her zaman görünen, CANLI (her karede güncellenen) küçük harita.
## Üzerine dokununca büyük haritayı (map_overlay.gd) açması için "tapped" sinyali
## yayar. Dokunuş algılama touch_controls.gd ile AYNI ham _input() yöntemiyle
## yapılır (Godot'un Button/gui_input akışı yerine) — bu yöntem cihazda zaten
## kanıtlanmış şekilde çalışıyor, tutarlılık için burada da kullanılıyor.

signal tapped

var world_size := Vector2(2400, 1350)

const MINIMAP_SIZE := Vector2(120, 90)
const MARGIN := 16.0
const ENEMY_DOT_RADIUS := 2.0
const PLAYER_DOT_RADIUS := 3.0

func _ready() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	position = Vector2(viewport_size.x - MINIMAP_SIZE.x - MARGIN, MARGIN)
	size = MINIMAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE # kendi _input()'umuzu kullanıyoruz

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.05, 0.8)
	bg.size = MINIMAP_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _process(_delta: float) -> void:
	queue_redraw() # canlı: her karede güncel konumlarla yeniden çiz

func _input(event: InputEvent) -> void:
	var pos: Vector2
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pos = event.position
		pressed = true

	if pressed and Rect2(position, size).has_point(pos):
		tapped.emit()

func _draw() -> void:
	var available := MINIMAP_SIZE - Vector2(6, 6)
	var scale_factor: float = min(available.x / world_size.x, available.y / world_size.y)
	var map_size := world_size * scale_factor
	var origin := (MINIMAP_SIZE - map_size) / 2.0

	draw_rect(Rect2(origin, map_size), Color(0.22, 0.42, 0.22, 1.0))
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(1, 1, 1, 0.7), false, 1.5)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var p: Vector2 = origin + enemy.global_position * scale_factor
		var type_id: String = enemy.type_id if "type_id" in enemy else "goblin"
		draw_circle(p, ENEMY_DOT_RADIUS, _color_for_type(type_id))

	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var pp: Vector2 = origin + player.global_position * scale_factor
		draw_circle(pp, PLAYER_DOT_RADIUS, Color(0.3, 0.6, 1.0))

func _color_for_type(type_id: String) -> Color:
	match type_id:
		"goblin":
			return Color(0.3, 0.85, 0.3)
		"skelet":
			return Color(0.9, 0.9, 0.85)
		"orc_warrior":
			return Color(0.65, 0.7, 0.25)
		"big_demon":
			return Color(0.9, 0.15, 0.15)
		_:
			return Color.YELLOW
