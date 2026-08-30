extends CanvasLayer
## HUD: sol üstte çerçeveli durum paneli (seviye + HP/MP/XP çubukları + altın ve
## öldürme sayacı), üst ortada hedeflenen canavarın paneli, sağ üstte canlı minimap.
##
## Çerçeveler Kenney "Fantasy UI Borders" panelinden NinePatchRect ile üretiliyor:
## kaynak 48x48 beyaz bir çerçeve, 16px kenar payıyla her boyuta düzgün esniyor
## ve beyaz olduğu için modulate ile istenen renge boyanabiliyor.

## world.gd tarafından add_child()'dan ÖNCE set edilir (harita çizimi için gerekli).
var world_size := Vector2(2400, 1350)
var map_features := {} # bkz. WorldGen.get_map_features(); minimap/haritaya aktarılır

const PANEL_TEXTURE := "res://assets/ui/panel_frame.png"
const PANEL_MARGIN := 16
const PANEL_TINT := Color(0.16, 0.13, 0.11, 0.92) # koyu ahşap/parşömen hissi
const BAR_SIZE := Vector2(190, 20)

var _level_label: Label
var _hp_bar: Control
var _mp_bar: Control
var _xp_bar: Control
var _gold_label: Label
var _kill_label: Label
var _level_up_label: Label
var _kills := 0

var _target_panel: Control
var _target_name_label: Label
var _target_bar: Control
var _current_target: Node = null

func _ready() -> void:
	layer = 10 # TouchControls (varsayılan layer 1) altta kalsın; overlay'ler üstte

	_build_stat_panel()
	_build_target_panel()
	_build_minimap()
	_build_level_up_banner()

## Herhangi bir HUD kutusu için çerçeveli arka plan üretir.
func make_panel(pos: Vector2, panel_size: Vector2, tint: Color = PANEL_TINT) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = load(PANEL_TEXTURE)
	panel.patch_margin_left = PANEL_MARGIN
	panel.patch_margin_top = PANEL_MARGIN
	panel.patch_margin_right = PANEL_MARGIN
	panel.patch_margin_bottom = PANEL_MARGIN
	panel.position = pos
	panel.size = panel_size
	# self_modulate: modulate kullanılsa renk tonu çocuklara da geçer ve panelin
	# içindeki metin/çubuklar da kararırdı.
	panel.self_modulate = tint
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

## --- Sol üst: durum paneli ---------------------------------------------------

func _build_stat_panel() -> void:
	var panel := make_panel(Vector2(14, 14), Vector2(226, 172))
	add_child(panel)

	var pad := 18.0
	var x := 14.0 + pad
	var y := 14.0 + pad - 4.0

	_level_label = _make_label(Vector2(x, y), 20, Color(1, 0.88, 0.55))
	_level_label.text = "Seviye 1"
	y += 30.0

	_hp_bar = _make_bar(Vector2(x, y), Color(0.80, 0.20, 0.20)); y += BAR_SIZE.y + 6.0
	_mp_bar = _make_bar(Vector2(x, y), Color(0.25, 0.48, 0.90)); y += BAR_SIZE.y + 6.0
	_xp_bar = _make_bar(Vector2(x, y), Color(0.92, 0.72, 0.18)); y += BAR_SIZE.y + 10.0

	_gold_label = _make_icon_row(Vector2(x, y), "res://assets/ui/icon_coin.png", "0", Color(1, 0.87, 0.4))
	_kill_label = _make_icon_row(Vector2(x + 108.0, y), "res://assets/ui/icon_kills.png", "0", Color(0.9, 0.9, 0.92))

func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _make_bar(pos: Vector2, color: Color) -> Control:
	var bar: Control = load("res://scripts/ui_bar.gd").new()
	bar.position = pos
	add_child(bar)
	bar.setup(color, BAR_SIZE)
	bar.set_value(1, 1)
	return bar

## Küçük ikon + yanında değer (altın/öldürme). Metin etiketini döndürür.
func _make_icon_row(pos: Vector2, icon_path: String, value: String, color: Color) -> Label:
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.ignore_texture_size = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(22, 22)
	icon.position = pos
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	var label := _make_label(pos + Vector2(28, 1), 18, color)
	label.text = value
	return label

## --- Üst orta: hedef paneli --------------------------------------------------

func _build_target_panel() -> void:
	var width := 236.0
	var viewport_width := get_viewport().get_visible_rect().size.x

	_target_panel = make_panel(Vector2(viewport_width / 2.0 - width / 2.0, 10), Vector2(width, 74))
	_target_panel.visible = false
	add_child(_target_panel)

	_target_name_label = Label.new()
	_target_name_label.size = Vector2(width - 24.0, 22)
	_target_name_label.position = Vector2(12, 12)
	_target_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_name_label.add_theme_font_size_override("font_size", 17)
	_target_name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.72))
	_target_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_target_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_target_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_target_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_panel.add_child(_target_name_label)

	_target_bar = load("res://scripts/ui_bar.gd").new()
	_target_bar.position = Vector2((width - BAR_SIZE.x) / 2.0, 40)
	_target_panel.add_child(_target_bar)
	_target_bar.setup(Color(0.82, 0.18, 0.18), BAR_SIZE)

## --- Sağ üst: canlı minimap --------------------------------------------------

func _build_minimap() -> void:
	var minimap: Control = load("res://scripts/minimap.gd").new()
	minimap.world_size = world_size
	minimap.map_features = map_features
	minimap.tapped.connect(_show_map)
	add_child(minimap) # ebeveyn ağaçta olduğu için _ready() burada senkron çalışır,
	                   # dolayısıyla konum/boyut aşağıda okunmaya hazır

	# Çerçeve minimap'ten biraz taşar ve arkasında durur.
	var frame := make_panel(minimap.position - Vector2(8, 8), minimap.size + Vector2(16, 16),
							Color(0.20, 0.17, 0.13, 0.95))
	add_child(frame)
	move_child(frame, minimap.get_index())

func _show_map() -> void:
	var overlay: Control = load("res://scripts/map_overlay.gd").new()
	overlay.world_size = world_size
	overlay.map_features = map_features
	add_child(overlay)

## --- Seviye atlama bildirimi -------------------------------------------------

func _build_level_up_banner() -> void:
	_level_up_label = Label.new()
	_level_up_label.add_theme_font_size_override("font_size", 38)
	_level_up_label.add_theme_color_override("font_color", Color(1, 0.9, 0.35))
	_level_up_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.08, 0, 0.9))
	_level_up_label.add_theme_constant_override("shadow_offset_x", 2)
	_level_up_label.add_theme_constant_override("shadow_offset_y", 2)
	var viewport_size := get_viewport().get_visible_rect().size
	_level_up_label.size = Vector2(viewport_size.x, 50)
	_level_up_label.position = Vector2(0, viewport_size.y * 0.3)
	_level_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_up_label.modulate.a = 0.0
	_level_up_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_up_label)

## --- Dışarıdan çağrılan güncellemeler ----------------------------------------

func set_player_hp(current: int, max_hp: int) -> void:
	_hp_bar.set_value(current, max_hp)

func set_player_mp(current: int, max_mp: int) -> void:
	_mp_bar.set_value(current, max_mp)

func set_xp(current: int, needed: int, level: int) -> void:
	_level_label.text = "Seviye %d" % level
	_xp_bar.set_value(current, needed)

func set_gold(amount: int) -> void:
	_gold_label.text = str(amount)

func add_kill(_xp_reward: int) -> void:
	_kills += 1
	_kill_label.text = str(_kills)

func announce_level_up(new_level: int) -> void:
	_level_up_label.text = "Seviye %d!" % new_level
	var tw := create_tween()
	tw.tween_property(_level_up_label, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.9)
	tw.tween_property(_level_up_label, "modulate:a", 0.0, 0.6)

## world.gd bunu player.target_changed sinyaline bağlar.
func set_target(enemy: Node) -> void:
	if _current_target == enemy:
		return
	if is_instance_valid(_current_target) and _current_target.health_changed.is_connected(_on_target_health_changed):
		_current_target.health_changed.disconnect(_on_target_health_changed)

	_current_target = enemy
	if enemy == null or not is_instance_valid(enemy):
		_target_panel.visible = false
		return

	_target_panel.visible = true
	var display_name: String = enemy.get_display_name() if enemy.has_method("get_display_name") else "?"
	var lvl: int = enemy.get_level() if enemy.has_method("get_level") else 1
	_target_name_label.text = "%s  ·  Lv.%d" % [display_name, lvl]
	_target_bar.set_value(enemy.hp, enemy.max_hp)
	enemy.health_changed.connect(_on_target_health_changed)

func _on_target_health_changed(current: int, max_hp: int) -> void:
	_target_bar.set_value(current, max_hp)
	if current <= 0:
		_target_panel.visible = false
