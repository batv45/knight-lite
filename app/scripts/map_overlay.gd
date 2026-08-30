extends Control
## Minimap'e (sağ üst) dokununca açılan büyük, CANLI dünya haritası: her karede
## yeniden çizilip oyuncu/canavar konumlarını ve isimlerini günceller. Açıkken
## arka plandaki dokunmatik joystick/saldırı butonunun yanlışlıkla tetiklenmesini
## önlemek için TouchControls devre dışı bırakılır, kapanınca tekrar etkinleştirilir.
## Herhangi bir yere dokununca kapanır (minimap.gd ile AYNI ham _input() yöntemi
## kullanılır — Godot'un gui_input akışı yerine, tutarlılık/güvenilirlik için).

var world_size := Vector2(2400, 1350)

const MARGIN := 50.0
const PLAYER_DOT_RADIUS := 7.0
const ENEMY_DOT_RADIUS := 4.0

func _ready() -> void:
	# Anchor yerine bilinçli olarak açık boyut/pozisyon veriyoruz: bu node bir
	# Control-parent'ın değil doğrudan bir CanvasLayer'ın çocuğu olarak ekleniyor,
	# anchor tabanlı FULL_RECT'in her durumda doğru boyuta oturmadığı görüldü.
	var viewport_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE # kendi _input()'umuzu kullanıyoruz
	z_index = 100 # diğer tüm HUD/touch-control katmanlarının üstünde görünsün

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.05, 0.9)
	bg.position = Vector2.ZERO
	bg.size = viewport_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hint := Label.new()
	hint.text = "Kapatmak için dokun"
	hint.add_theme_font_size_override("font_size", 16)
	hint.position = Vector2(0, viewport_size.y - 40)
	hint.size = Vector2(viewport_size.x, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	_set_touch_controls_enabled(false)
	tree_exiting.connect(func(): _set_touch_controls_enabled(true))

func _set_touch_controls_enabled(value: bool) -> void:
	var tc := get_tree().get_first_node_in_group("touch_controls")
	if tc:
		tc.set_enabled(value)

func _process(_delta: float) -> void:
	queue_redraw() # canlı harita: her karede güncel konumlarla yeniden çiz

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		queue_free()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var available := viewport_size - Vector2(MARGIN, MARGIN) * 2.0
	var scale_factor: float = min(available.x / world_size.x, available.y / world_size.y)
	var map_size := world_size * scale_factor
	var origin := (viewport_size - map_size) / 2.0
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(origin, map_size), Color(0.22, 0.42, 0.22, 1.0))
	draw_rect(Rect2(origin, map_size), Color(1, 1, 1, 0.9), false, 3.0)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var p: Vector2 = origin + enemy.global_position * scale_factor
		var type_id: String = enemy.type_id if "type_id" in enemy else "goblin"
		draw_circle(p, ENEMY_DOT_RADIUS, _color_for_type(type_id))
		var label: String = enemy.get_display_name() if enemy.has_method("get_display_name") else type_id
		draw_string(font, p + Vector2(7, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))

	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var pp: Vector2 = origin + player.global_position * scale_factor
		draw_circle(pp, PLAYER_DOT_RADIUS, Color(0.3, 0.6, 1.0))
		draw_arc(pp, PLAYER_DOT_RADIUS, 0, TAU, 16, Color.WHITE, 2.0)
		draw_string(font, pp + Vector2(9, 4), "Sen", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.8, 1.0))

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
