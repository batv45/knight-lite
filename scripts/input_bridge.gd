extends Node
## Autoload singleton. Klavye (PC test) ve dokunmatik joystick (Android) girdilerini
## tek bir arayüzde birleştirir. Oyun mantığı (Player, ileride NPC/UI) sadece
## InputBridge.get_move_vector() çağırır, kaynağın klavye mi touch mu olduğuyla
## ilgilenmez.

var _touch_move_vector := Vector2.ZERO

## TouchControls tarafından her sürüklemede çağrılır.
func set_move_vector(v: Vector2) -> void:
	_touch_move_vector = v

## Player'ın her fizik karesinde okuduğu birleşik hareket vektörü.
## Touch aktifse onu, değilse klavyeyi kullanır.
func get_move_vector() -> Vector2:
	if _touch_move_vector.length() > 0.05:
		return _touch_move_vector.limit_length(1.0)
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
