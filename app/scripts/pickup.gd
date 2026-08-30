extends Area2D
## Canavar öldüğünde dünyaya düşen basit altın drop'u. Oyuncu üzerinden geçince
## toplanır. Placeholder: sarı kare. İleride farklı item tipleri (iksir, ekipman)
## aynı düzende (ayrı script/scene) eklenebilir.

const SIZE := 16.0
const GOLD_MIN := 5
const GOLD_MAX := 15

func _ready() -> void:
	add_to_group("pickups")

	var visual := ColorRect.new()
	visual.color = Color(0.95, 0.85, 0.2)
	visual.size = Vector2(SIZE, SIZE)
	visual.position = -visual.size / 2.0
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = SIZE
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("gain_gold"):
		body.gain_gold(randi_range(GOLD_MIN, GOLD_MAX))
		queue_free()
