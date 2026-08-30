extends CharacterBody2D
## Faz 2 + asset entegrasyonu: tek canavar tipi (goblin). Basit state machine:
## Idle -> oyuncuyu görünce Chase -> menzile girince Attack -> HP 0 olunca Dead.
## Görsel: 0x72'nin "DungeonTilesetII" paketinden goblin sprite'ları.

signal died(xp_reward: int)

enum State { IDLE, CHASE, ATTACK, DEAD }

const BODY_SIZE := 16.0
const MAX_HP := 40
const SPEED := 90.0
const DETECT_RANGE := 220.0
const ATTACK_RANGE := 34.0
const ATTACK_DAMAGE := 10
const ATTACK_COOLDOWN := 1.0
const XP_REWARD := 15 # Faz 3'te leveling sistemi bu değeri kullanacak

const SPRITE_DIR := "res://assets/monsters/goblin/"

var hp := MAX_HP
var state: int = State.IDLE

var _attack_ready := true
var _player: Node2D
var _visual: AnimatedSprite2D
var _collision_shape: CollisionShape2D
var _health_bar: HealthBar

func _ready() -> void:
	add_to_group("enemies")

	_visual = AnimatedSprite2D.new()
	_visual.sprite_frames = _build_sprite_frames()
	_visual.animation = "idle"
	_visual.play()
	add_child(_visual)

	_collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BODY_SIZE - 4.0, BODY_SIZE - 4.0)
	_collision_shape.shape = rect
	add_child(_collision_shape)

	_health_bar = HealthBar.new()
	_health_bar.position = Vector2(0, -BODY_SIZE / 2.0 - 10.0)
	add_child(_health_bar)
	_health_bar.update_ratio(1.0)

	_player = get_tree().get_first_node_in_group("player")

func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	frames.add_animation("idle")
	frames.set_animation_speed("idle", 6.0)
	frames.set_animation_loop("idle", true)
	for i in 4:
		frames.add_frame("idle", load(SPRITE_DIR + "goblin_idle_anim_f%d.png" % i))

	frames.add_animation("run")
	frames.set_animation_speed("run", 10.0)
	frames.set_animation_loop("run", true)
	for i in 4:
		frames.add_frame("run", load(SPRITE_DIR + "goblin_run_anim_f%d.png" % i))

	return frames

func _physics_process(_delta: float) -> void:
	if state == State.DEAD or _player == null or not is_instance_valid(_player) or _player.is_dead:
		velocity = Vector2.ZERO
		_update_animation()
		return

	var to_player: Vector2 = _player.global_position - global_position
	var dist := to_player.length()

	if dist <= ATTACK_RANGE:
		state = State.ATTACK
		velocity = Vector2.ZERO
		if _attack_ready:
			_attack()
	elif dist <= DETECT_RANGE:
		state = State.CHASE
		velocity = to_player.normalized() * SPEED
	else:
		state = State.IDLE
		velocity = Vector2.ZERO

	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	_visual.animation = "run" if state == State.CHASE else "idle"
	if abs(velocity.x) > 0.1:
		_visual.flip_h = velocity.x < 0.0

func _attack() -> void:
	_attack_ready = false
	_player.take_damage(ATTACK_DAMAGE)
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	_attack_ready = true

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	hp = max(hp - amount, 0)
	_health_bar.update_ratio(float(hp) / float(MAX_HP))
	_flash_hit()
	if hp <= 0:
		_die()

func _flash_hit() -> void:
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color(1, 0.4, 0.4), 0.08)
	tw.tween_property(_visual, "modulate", Color.WHITE, 0.25)

func _die() -> void:
	state = State.DEAD
	_collision_shape.disabled = true
	died.emit(XP_REWARD)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2.ZERO, 0.3)
	tw.parallel().tween_property(_health_bar, "scale", Vector2.ZERO, 0.15)
	await tw.finished
	queue_free()
