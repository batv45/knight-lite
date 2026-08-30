extends CanvasLayer
## Faz 4 HUD: can, seviye/XP, altın, öldürülen canavar sayacı, level-up bildirimi
## ve sağ üstteki harita butonu (basınca dünyanın anlık bir "fotoğrafını" gösterir).

## world.gd tarafından add_child()'dan ÖNCE set edilir (harita çizimi için gerekli).
var world_size := Vector2(2400, 1350)

var _hp_label: Label
var _level_label: Label
var _xp_label: Label
var _gold_label: Label
var _kill_label: Label
var _level_up_label: Label
var _kills := 0

func _ready() -> void:
	layer = 10 # TouchControls (varsayılan layer 1) her zaman altında kalsın; harita overlay'i üstte görünsün

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	_hp_label = _make_label(box)
	_level_label = _make_label(box)
	_xp_label = _make_label(box)
	_gold_label = _make_label(box)
	_kill_label = _make_label(box)
	_kill_label.text = "Öldürülen canavar: 0"

	_level_up_label = Label.new()
	_level_up_label.add_theme_font_size_override("font_size", 36)
	_level_up_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_level_up_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_level_up_label.position = Vector2(-100, 60)
	_level_up_label.modulate.a = 0.0
	add_child(_level_up_label)

	_build_map_button()

func _make_label(parent: VBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(label)
	return label

func set_player_hp(current: int, max_hp: int) -> void:
	_hp_label.text = "Can: %d / %d" % [current, max_hp]

func set_xp(current: int, needed: int, level: int) -> void:
	_level_label.text = "Seviye: %d" % level
	_xp_label.text = "XP: %d / %d" % [current, needed]

func set_gold(amount: int) -> void:
	_gold_label.text = "Altın: %d" % amount

func add_kill(_xp_reward: int) -> void:
	_kills += 1
	_kill_label.text = "Öldürülen canavar: %d" % _kills

func announce_level_up(new_level: int) -> void:
	_level_up_label.text = "Seviye %d!" % new_level
	var tw := create_tween()
	tw.tween_property(_level_up_label, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.8)
	tw.tween_property(_level_up_label, "modulate:a", 0.0, 0.6)

## --- Harita butonu ----------------------------------------------------------

func _build_map_button() -> void:
	var button := TextureButton.new()
	button.texture_normal = load("res://assets/ui/round_panel.png")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.modulate = Color(0.55, 0.75, 1.0, 0.95)
	button.size = Vector2(64, 64)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.position = Vector2(-80, 16)
	button.pressed.connect(_show_map)
	add_child(button)

	var label := Label.new()
	label.text = "Harita"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.1, 0.15, 0.25))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

func _show_map() -> void:
	var overlay: Control = load("res://scripts/map_overlay.gd").new()
	overlay.world_size = world_size
	add_child(overlay)
