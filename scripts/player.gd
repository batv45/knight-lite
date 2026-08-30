extends CharacterBody2D
## Faz 1: sadece hareket. Görsel şimdilik düz renkli kare (placeholder) —
## asset paketi seçilince bu kısım gerçek sprite/AnimatedSprite2D ile değişecek.

const SPEED := 180.0
const BODY_SIZE := 32.0

func _ready() -> void:
	var visual := ColorRect.new()
	visual.name = "PlaceholderVisual"
	visual.color = Color(0.2, 0.6, 1.0) # mavi kare = karakter
	visual.size = Vector2(BODY_SIZE, BODY_SIZE)
	visual.position = -visual.size / 2.0
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BODY_SIZE - 4.0, BODY_SIZE - 4.0)
	shape.shape = rect
	add_child(shape)

func _physics_process(_delta: float) -> void:
	var dir := InputBridge.get_move_vector()
	velocity = dir * SPEED
	move_and_slide()
