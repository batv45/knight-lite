class_name HealthBar
extends Node2D
## Player ve Enemy'nin başının üstünde gösterilen basit HP çubuğu.
## `update_ratio(0..1)` ile doldurulma oranı ayarlanır. Placeholder: düz renk
## dikdörtgenler, asset seçilince görsel stil değişebilir ama arayüz (bu fonksiyon) aynı kalır.

const WIDTH := 40.0
const HEIGHT := 6.0

var _fg: ColorRect

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.05, 0.05, 0.85)
	bg.size = Vector2(WIDTH, HEIGHT)
	bg.position = -bg.size / 2.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_fg = ColorRect.new()
	_fg.color = Color(0.2, 0.9, 0.3, 0.95)
	_fg.size = Vector2(WIDTH, HEIGHT)
	_fg.position = bg.position
	_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fg)

func update_ratio(ratio: float) -> void:
	_fg.size.x = WIDTH * clampf(ratio, 0.0, 1.0)
