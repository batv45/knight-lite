extends Area2D
## Canavar öldüğünde düşen altın. Oyuncu üzerinden geçince toplanır. Gerçek sikke
## görseli (0x72 icon_coin) + hafif zıplama animasyonu. Toplanmazsa LIFETIME sonunda
## yok olur (haritada sonsuza dek birikmesin), son SANİYELERDE yanıp söner.

const PICKUP_RADIUS := 20.0
const GOLD_MIN := 5
const GOLD_MAX := 15
const COIN_SCALE := 2.0        # icon_coin 6x7px, büyütülmeden görünmez kalıyor
const LIFETIME := 18.0
const BLINK_LAST := 3.0

var _age := 0.0
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("pickups")

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/ui/icon_coin.png")
	_sprite.scale = Vector2(COIN_SCALE, COIN_SCALE)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PICKUP_RADIUS
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)

	# Sürekli hafif zıplama — dikkat çeker, "toplanabilir" hissi verir.
	var tw := create_tween().set_loops()
	tw.tween_property(_sprite, "position:y", -4.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sprite, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# Son saniyelerde yanıp sönerek "kaybolacak" uyarısı ver.
	if _age >= LIFETIME - BLINK_LAST:
		_sprite.visible = fmod(_age * 6.0, 1.0) < 0.5
	else:
		_sprite.visible = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("gain_gold"):
		body.gain_gold(randi_range(GOLD_MIN, GOLD_MAX))
		queue_free()
