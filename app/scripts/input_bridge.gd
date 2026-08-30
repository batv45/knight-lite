extends Node
## Autoload singleton. Klavye (PC test) ve dokunmatik kontroller (Android) girdilerini
## tek bir arayüzde birleştirir. Oyun mantığı (Player, ileride UI) sadece bu arayüzü
## çağırır, kaynağın klavye mi touch mu olduğuyla ilgilenmez.

var _touch_move_vector := Vector2.ZERO
var _attack_requested := false

## TouchControls tarafından her sürüklemede çağrılır.
func set_move_vector(v: Vector2) -> void:
	_touch_move_vector = v

## Player'ın her fizik karesinde okuduğu birleşik hareket vektörü.
## Touch aktifse onu, değilse klavyeyi kullanır.
func get_move_vector() -> Vector2:
	if _touch_move_vector.length() > 0.05:
		return _touch_move_vector.limit_length(1.0)
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

## Dokunmatik saldırı butonuna basıldığında çağrılır (bkz. touch_controls.gd).
func request_attack() -> void:
	_attack_requested = true

## Bir kez tüketilen (one-shot) saldırı isteği: touch butonundan gelen tetikleme
## ya da klavyede yeni basılmış ui_accept (boşluk/enter).
func consume_attack_request() -> bool:
	if _attack_requested:
		_attack_requested = false
		return true
	return Input.is_action_just_pressed("ui_accept")
