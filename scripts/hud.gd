extends CanvasLayer
## Faz 3 HUD: can, seviye/XP, altın, öldürülen canavar sayacı + level-up bildirimi.

var _hp_label: Label
var _level_label: Label
var _xp_label: Label
var _gold_label: Label
var _kill_label: Label
var _level_up_label: Label
var _kills := 0

func _ready() -> void:
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
