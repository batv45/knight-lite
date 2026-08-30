extends CanvasLayer
## Sol altta hareket için sanal joystick, sağ altta saldırı butonu.
## Görseller Kenney "Fantasy UI Borders" paketinden (round_panel.png), renk
## tonlamasıyla (modulate) farklı amaçlar için ayrıştırılıyor.
## PC'de mouse ile de çalışır çünkü project.godot'ta "emulate_touch_from_mouse" açık.
## İki dokunuşu (hareket + saldırı) aynı anda ayırt edebilmek için her biri kendi
## touch index'ini takip eder.

const BASE_SIZE := 140.0
const KNOB_SIZE := 60.0
const MARGIN := 100.0
const MAX_OFFSET := (BASE_SIZE - KNOB_SIZE) / 2.0

const ATTACK_BUTTON_SIZE := 90.0
const ATTACK_MARGIN := 90.0

const PANEL_TEXTURE := "res://assets/ui/round_panel.png"

var _touch_index := -1
var _base_center := Vector2.ZERO
var _knob_center := Vector2.ZERO
var _base_visual: TextureRect
var _knob_visual: TextureRect

var _attack_touch_index := -1
var _attack_center := Vector2.ZERO
var _attack_visual: TextureRect

## Harita gibi bir overlay açıkken devre dışı bırakılır (bkz. map_overlay.gd),
## yoksa ham _input() harita açıkken de joystick/saldırıyı tetiklemeye devam eder.
var _enabled := true

func _ready() -> void:
	add_to_group("touch_controls")
	var viewport_size := get_viewport().get_visible_rect().size

	_base_center = Vector2(MARGIN + BASE_SIZE / 2.0, viewport_size.y - MARGIN - BASE_SIZE / 2.0)
	_knob_center = _base_center
	# Taban koyu, topuz açık: açık zeminlerde (kasaba meydanı gibi) beyaz bir
	# taban neredeyse görünmez oluyordu; koyu taban her arka planda okunuyor.
	_base_visual = _make_pad(BASE_SIZE, Color(0.12, 0.10, 0.09, 0.62))
	_knob_visual = _make_pad(KNOB_SIZE, Color(0.96, 0.93, 0.86, 0.95))
	add_child(_base_visual)
	add_child(_knob_visual)

	_attack_center = Vector2(viewport_size.x - ATTACK_MARGIN, viewport_size.y - ATTACK_MARGIN)
	_attack_visual = _make_pad(ATTACK_BUTTON_SIZE, Color(1.0, 0.35, 0.3, 0.85))
	add_child(_attack_visual)
	_add_attack_label(_attack_visual)

	_update_visuals()

func _make_pad(size: float, color: Color) -> TextureRect:
	var pad := TextureRect.new()
	pad.texture = load(PANEL_TEXTURE)
	pad.ignore_texture_size = true
	pad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pad.size = Vector2(size, size)
	pad.modulate = color
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pad

## Butonun üstüne kılıç ikonu: metin yerine ikon dilden bağımsız ve daha okunaklı.
func _add_attack_label(parent: TextureRect) -> void:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/icon_sword.png")
	icon.ignore_texture_size = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_size := ATTACK_BUTTON_SIZE * 0.55
	icon.size = Vector2(icon_size, icon_size)
	icon.position = (parent.size - icon.size) / 2.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)

func _update_visuals() -> void:
	_base_visual.position = _base_center - _base_visual.size / 2.0
	_knob_visual.position = _knob_center - _knob_visual.size / 2.0
	_attack_visual.position = _attack_center - _attack_visual.size / 2.0

func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_release_joystick()
		_attack_touch_index = -1

func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and event.position.distance_to(_base_center) <= BASE_SIZE:
				_touch_index = event.index
				_drag_to(event.position)
			elif _attack_touch_index == -1 and event.position.distance_to(_attack_center) <= ATTACK_BUTTON_SIZE / 2.0:
				_attack_touch_index = event.index
				InputBridge.request_attack()
				_pulse_attack_button()
		else:
			if event.index == _touch_index:
				_release_joystick()
			elif event.index == _attack_touch_index:
				_attack_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_drag_to(event.position)

func _drag_to(pos: Vector2) -> void:
	var offset := pos - _base_center
	if offset.length() > MAX_OFFSET:
		offset = offset.normalized() * MAX_OFFSET
	_knob_center = _base_center + offset
	_update_visuals()
	InputBridge.set_move_vector(offset / MAX_OFFSET)

func _release_joystick() -> void:
	_touch_index = -1
	_knob_center = _base_center
	_update_visuals()
	InputBridge.set_move_vector(Vector2.ZERO)

func _pulse_attack_button() -> void:
	_attack_visual.pivot_offset = _attack_visual.size / 2.0
	var tw := create_tween()
	tw.tween_property(_attack_visual, "scale", Vector2(0.85, 0.85), 0.05)
	tw.tween_property(_attack_visual, "scale", Vector2.ONE, 0.1)
