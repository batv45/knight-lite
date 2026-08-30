extends Control
## Minimap'e dokununca açılan büyük, CANLI dünya haritası: arazi (yollar, kasaba
## meydanı, göl), canavarlar ve isimleri, oyuncunun konumu. Açıkken arka plandaki
## dokunmatik joystick/saldırı butonunun yanlışlıkla tetiklenmesini önlemek için
## TouchControls devre dışı bırakılır, kapanınca tekrar etkinleştirilir.
## Herhangi bir yere dokununca kapanır (minimap.gd ile aynı ham _input() yöntemi).

var world_size := Vector2(2400, 1350)
var map_features := {} # bkz. WorldGen.get_map_features()

const MARGIN := 56.0
const PLAYER_DOT_RADIUS := 7.0
const ENEMY_DOT_RADIUS := 4.0

var _map_rect: Rect2

func _ready() -> void:
	# Anchor yerine bilinçli olarak açık boyut/pozisyon veriyoruz: bu node bir
	# Control-parent'ın değil doğrudan bir CanvasLayer'ın çocuğu olarak ekleniyor,
	# anchor tabanlı FULL_RECT'in her durumda doğru boyuta oturmadığı görüldü.
	var viewport_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = viewport_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE # kendi _input()'umuzu kullanıyoruz
	z_index = 100 # tüm HUD/touch-control katmanlarının üstünde

	# Karartma ve çerçeve bilinçli olarak _draw() içinde çiziliyor: Godot'ta bir
	# Control önce kendini, sonra çocuklarını çizer. Bunlar çocuk node olsaydı
	# haritanın ÜSTÜNE gelir ve onu örterdi (yarı saydam arka plan haritayı
	# soldurup okunmaz hale getiriyordu).
	_map_rect = _compute_map_rect()

	var hint := Label.new()
	hint.text = "Kapatmak için dokun"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.position = Vector2(0, viewport_size.y - 34)
	hint.size = Vector2(viewport_size.x, 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	_set_touch_controls_enabled(false)
	tree_exiting.connect(func(): _set_touch_controls_enabled(true))

func _compute_map_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var available := viewport_size - Vector2(MARGIN, MARGIN) * 2.0
	var scale_factor: float = minf(available.x / world_size.x, available.y / world_size.y)
	var map_size := world_size * scale_factor
	return Rect2((viewport_size - map_size) / 2.0, map_size)

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
	var scale_factor := _map_rect.size.x / world_size.x
	var origin := _map_rect.position
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.04, 0.86)) # arka planı karart

	MapDraw.draw_terrain(self, map_features, world_size, origin, scale_factor)
	MapDraw.draw_enemies(self, get_tree(), origin, scale_factor, ENEMY_DOT_RADIUS, font, 13)
	MapDraw.draw_player(self, get_tree(), origin, scale_factor, PLAYER_DOT_RADIUS, font, 14)

	# Haritanın çerçevesi: dışta kalın koyu, içte ince açık çizgi
	draw_rect(_map_rect.grow(4.0), Color(0.16, 0.13, 0.10), false, 8.0)
	draw_rect(_map_rect.grow(1.0), Color(0.72, 0.62, 0.42), false, 2.0)
