extends CanvasLayer
## Faz 4 HUD: sol üstte seviye + HP/MP/XP çubukları + altın + öldürülen canavar
## sayacı, üst ortada hedeflenen canavarın HP çubuğu, sağ üstte harita butonu.

## world.gd tarafından add_child()'dan ÖNCE set edilir (harita çizimi için gerekli).
var world_size := Vector2(2400, 1350)

const BAR_SIZE := Vector2(180, 22)

var _level_label: Label
var _hp_bar: Control
var _mp_bar: Control
var _xp_bar: Control
var _gold_label: Label
var _kill_label: Label
var _level_up_label: Label
var _kills := 0

var _target_container: Control
var _target_name_label: Label
var _target_bar: Control
var _current_target: Node = null

func _ready() -> void:
	layer = 10 # TouchControls (varsayılan layer 1) her zaman altında kalsın; overlay'ler üstte görünsün

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_level_label = _make_label(box)
	_hp_bar = _make_bar(box, Color(0.85, 0.25, 0.25))
	_mp_bar = _make_bar(box, Color(0.25, 0.5, 0.9))
	_xp_bar = _make_bar(box, Color(0.9, 0.75, 0.2))
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
	_build_target_ui()

func _make_label(parent: VBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(label)
	return label

func _make_bar(parent: VBoxContainer, color: Color) -> Control:
	var bar: Control = load("res://scripts/ui_bar.gd").new()
	parent.add_child(bar)
	bar.setup(color, BAR_SIZE)
	bar.set_value(1, 1)
	return bar

func set_player_hp(current: int, max_hp: int) -> void:
	_hp_bar.set_value(current, max_hp)

func set_player_mp(current: int, max_mp: int) -> void:
	_mp_bar.set_value(current, max_mp)

func set_xp(current: int, needed: int, level: int) -> void:
	_level_label.text = "Seviye: %d" % level
	_xp_bar.set_value(current, needed)

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

## --- Hedeflenen canavar HP göstergesi (üst orta) ----------------------------

func _build_target_ui() -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var width := 200.0

	_target_container = Control.new()
	_target_container.position = Vector2(viewport_width / 2.0 - width / 2.0, 12)
	_target_container.size = Vector2(width, 50)
	_target_container.visible = false
	add_child(_target_container)

	_target_name_label = Label.new()
	_target_name_label.size = Vector2(width, 20)
	_target_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_name_label.add_theme_font_size_override("font_size", 16)
	_target_container.add_child(_target_name_label)

	_target_bar = load("res://scripts/ui_bar.gd").new()
	_target_bar.position = Vector2((width - BAR_SIZE.x) / 2.0, 22)
	_target_container.add_child(_target_bar)
	_target_bar.setup(Color(0.85, 0.2, 0.2), BAR_SIZE)

## world.gd bunu player.target_changed sinyaline bağlar.
func set_target(enemy: Node) -> void:
	if _current_target == enemy:
		return
	if is_instance_valid(_current_target) and _current_target.health_changed.is_connected(_on_target_health_changed):
		_current_target.health_changed.disconnect(_on_target_health_changed)

	_current_target = enemy
	if enemy == null or not is_instance_valid(enemy):
		_target_container.visible = false
		return

	_target_container.visible = true
	_target_name_label.text = _display_name_for_type(enemy.type_id if "type_id" in enemy else "")
	_target_bar.set_value(enemy.hp, enemy.max_hp)
	enemy.health_changed.connect(_on_target_health_changed)

func _on_target_health_changed(current: int, max_hp: int) -> void:
	_target_bar.set_value(current, max_hp)
	if current <= 0:
		_target_container.visible = false

func _display_name_for_type(type_id: String) -> String:
	match type_id:
		"goblin":
			return "Goblin"
		"skelet":
			return "İskelet"
		"orc_warrior":
			return "Ork Savaşçı"
		"big_demon":
			return "Dev İblis"
		_:
			return type_id.capitalize()
