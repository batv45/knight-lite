extends Control
## HUD için yeniden kullanılabilir çubuk (HP/MP/XP/hedef HP'si). Arkaplan +
## renkli dolgu + üstünde "current / max" metni. `setup()` ile boyut/renk,
## `set_value()` ile değer güncellenir.

var _bg: ColorRect
var _fg: ColorRect
var _label: Label

func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.55)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_fg = ColorRect.new()
	_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fg)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func setup(bar_color: Color, bar_size: Vector2) -> void:
	size = bar_size
	custom_minimum_size = bar_size
	_bg.size = bar_size
	_fg.size = bar_size
	_fg.color = bar_color
	_label.size = bar_size

func set_value(current: int, max_value: int) -> void:
	var ratio: float = 0.0 if max_value <= 0 else clampf(float(current) / float(max_value), 0.0, 1.0)
	_fg.size.x = _bg.size.x * ratio
	_label.text = "%d / %d" % [current, max_value]
