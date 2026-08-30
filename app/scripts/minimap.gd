extends Control
## Sağ üstte her zaman görünen, CANLI (her karede güncellenen) küçük harita.
## Üzerine dokununca büyük haritayı (map_overlay.gd) açması için "tapped" sinyali
## yayar. Dokunuş algılama touch_controls.gd ile AYNI ham _input() yöntemiyle
## yapılır (Godot'un Button/gui_input akışı yerine) — bu yöntem cihazda zaten
## kanıtlanmış şekilde çalışıyor, tutarlılık için burada da kullanılıyor.

signal tapped

var world_size := Vector2(2400, 1350)
var map_features := {} # bkz. WorldGen.get_map_features()

## Dünya oranıyla (2400x1350 = 16:9) aynı tutuluyor; farklı oranda üstte/altta
## boş bantlar oluşup çerçevenin içi açıkta kalıyordu.
const MINIMAP_SIZE := Vector2(128, 72)
const MARGIN := 22.0
const ENEMY_DOT_RADIUS := 2.2
const PLAYER_DOT_RADIUS := 3.2

func _ready() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	position = Vector2(viewport_size.x - MINIMAP_SIZE.x - MARGIN, MARGIN)
	size = MINIMAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE # kendi _input()'umuzu kullanıyoruz

func _process(_delta: float) -> void:
	queue_redraw() # canlı: her karede güncel konumlarla yeniden çiz

func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed and Rect2(position, size).has_point(event.position):
		tapped.emit()

func _draw() -> void:
	var scale_factor: float = minf(size.x / world_size.x, size.y / world_size.y)
	var origin := (size - world_size * scale_factor) / 2.0

	MapDraw.draw_terrain(self, map_features, world_size, origin, scale_factor)
	MapDraw.draw_enemies(self, get_tree(), origin, scale_factor, ENEMY_DOT_RADIUS)
	MapDraw.draw_player(self, get_tree(), origin, scale_factor, PLAYER_DOT_RADIUS)
