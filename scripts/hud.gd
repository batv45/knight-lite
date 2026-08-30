extends CanvasLayer
## Faz 2 basit HUD: can göstergesi + öldürülen canavar sayacı.
## Faz 3'te XP/level çubuğu buraya eklenecek.

var _hp_label: Label
var _kill_label: Label
var _kills := 0

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_hp_label)

	_kill_label = Label.new()
	_kill_label.add_theme_font_size_override("font_size", 22)
	_kill_label.text = "Öldürülen canavar: 0"
	box.add_child(_kill_label)

func set_player_hp(current: int, max_hp: int) -> void:
	_hp_label.text = "Can: %d / %d" % [current, max_hp]

func add_kill(_xp_reward: int) -> void:
	_kills += 1
	_kill_label.text = "Öldürülen canavar: %d" % _kills
