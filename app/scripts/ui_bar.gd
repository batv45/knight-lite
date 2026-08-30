extends Control
## HUD için yeniden kullanılabilir durum çubuğu (HP/MP/XP/hedef canı).
## Katmanlar: koyu oyuk zemin -> renkli dolgu -> üstte açık renkli parlama
## şeridi -> ince çerçeve -> gölgeli değer metni.
## `setup()` ile renk/boyut, `set_value()` ile değer ayarlanır.

const BORDER_COLOR := Color(0, 0, 0, 0.55)
const TRACK_COLOR := Color(0.07, 0.06, 0.09, 0.85)

var _track: ColorRect
var _fill: ColorRect
var _gloss: ColorRect
var _border: ReferenceRect
var _label: Label

func _ready() -> void:
	_track = ColorRect.new()
	_track.color = TRACK_COLOR
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)

	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	# Dolgunun üst yarısındaki açık şerit çubuğa hacim hissi verir.
	_gloss = ColorRect.new()
	_gloss.color = Color(1, 1, 1, 0.22)
	_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gloss)

	_border = ReferenceRect.new()
	_border.border_color = BORDER_COLOR
	_border.border_width = 2.0
	_border.editor_only = false
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func setup(bar_color: Color, bar_size: Vector2) -> void:
	size = bar_size
	custom_minimum_size = bar_size
	_track.size = bar_size
	_fill.size = bar_size
	_fill.color = bar_color
	_gloss.size = Vector2(bar_size.x, maxf(2.0, bar_size.y * 0.32))
	_gloss.position = Vector2(0, 2)
	_border.size = bar_size
	_label.size = bar_size

func set_value(current: int, max_value: int) -> void:
	var ratio: float = 0.0 if max_value <= 0 else clampf(float(current) / float(max_value), 0.0, 1.0)
	var width := _track.size.x * ratio
	_fill.size.x = width
	_gloss.size.x = width
	_label.text = "%d / %d" % [current, max_value]
