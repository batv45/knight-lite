extends CharacterBody2D
## Faz 4: veri odaklı çoklu canavar tipi + hedef kilitleme. `type_id` (world.gd
## tarafından add_child'dan ÖNCE set edilir) hangi sprite/stat setinin
## kullanılacağını belirler.
##
## Canavarlar artık OTOMATİK saldırmaz: sadece oyuncu tarafından hedeflenince
## (bkz. player.gd _set_target) Chase/Attack state'ine geçer, hedef değişince/
## kaybolunca tekrar Idle'a döner. Hedeflenen canavarın etrafında sarı bir
## halka gösterilir.

signal died(xp_reward: int)
signal health_changed(current: int, max_hp: int)

enum State { IDLE, CHASE, ATTACK, DEAD }

## Her canavar tipinin sprite klasörü ve dengelemesi. Yeni bir tip eklemek için
## sadece buraya bir satır eklemek ve app/assets/monsters/<id>/ altına
## "<id>_idle_anim_f0..3.png" + "<id>_run_anim_f0..3.png" koymak yeterli.
const ENEMY_TYPES := {
	"goblin": {
		"body_size": Vector2(16, 16), "max_hp": 40, "speed": 90.0,
		"attack_range": 34.0, "attack_damage": 10, "xp_reward": 15,
	},
	"skelet": {
		"body_size": Vector2(16, 16), "max_hp": 65, "speed": 85.0,
		"attack_range": 34.0, "attack_damage": 15, "xp_reward": 30,
	},
	"orc_warrior": {
		"body_size": Vector2(16, 23), "max_hp": 100, "speed": 75.0,
		"attack_range": 38.0, "attack_damage": 20, "xp_reward": 50,
	},
	"big_demon": {
		"body_size": Vector2(32, 36), "max_hp": 220, "speed": 65.0,
		"attack_range": 46.0, "attack_damage": 35, "xp_reward": 150,
	},
}
const DEFAULT_TYPE := "goblin"

## world.gd bunu add_child()'dan ÖNCE set eder (Player'ın position'ı gibi).
var type_id := DEFAULT_TYPE

var state: int = State.IDLE
var is_targeted := false
var hp: int
var max_hp: int
var speed: float
var attack_range: float
var attack_damage: int
var xp_reward: int
var body_size: Vector2

var _attack_ready := true
var _player: Node2D
var _visual: AnimatedSprite2D
var _collision_shape: CollisionShape2D
var _health_bar: HealthBar
var _target_ring: Node2D

func _ready() -> void:
	add_to_group("enemies")

	var cfg: Dictionary = ENEMY_TYPES.get(type_id, ENEMY_TYPES[DEFAULT_TYPE])
	body_size = cfg["body_size"]
	max_hp = cfg["max_hp"]
	hp = max_hp
	speed = cfg["speed"]
	attack_range = cfg["attack_range"]
	attack_damage = cfg["attack_damage"]
	xp_reward = cfg["xp_reward"]

	_visual = AnimatedSprite2D.new()
	_visual.sprite_frames = _build_sprite_frames()
	_visual.animation = "idle"
	_visual.play()
	add_child(_visual)

	_collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size - Vector2(4, 4)
	_collision_shape.shape = rect
	add_child(_collision_shape)

	_health_bar = HealthBar.new()
	_health_bar.position = Vector2(0, -body_size.y / 2.0 - 10.0)
	add_child(_health_bar)
	_health_bar.update_ratio(1.0)

	_target_ring = Node2D.new()
	_target_ring.visible = false
	add_child(_target_ring)
	_target_ring.draw.connect(func():
		var radius: float = max(body_size.x, body_size.y) / 2.0 + 5.0
		_target_ring.draw_arc(Vector2.ZERO, radius, 0, TAU, 28, Color(1, 0.9, 0.2, 0.95), 2.5)
	)

	_player = get_tree().get_first_node_in_group("player")

func _build_sprite_frames() -> SpriteFrames:
	var dir := "res://assets/monsters/%s/" % type_id
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	frames.add_animation("idle")
	frames.set_animation_speed("idle", 6.0)
	frames.set_animation_loop("idle", true)
	for i in 4:
		frames.add_frame("idle", load(dir + "%s_idle_anim_f%d.png" % [type_id, i]))

	frames.add_animation("run")
	frames.set_animation_speed("run", 10.0)
	frames.set_animation_loop("run", true)
	for i in 4:
		frames.add_frame("run", load(dir + "%s_run_anim_f%d.png" % [type_id, i]))

	return frames

func is_alive() -> bool:
	return state != State.DEAD

## Player tarafından vurulunca (bkz. player.gd _set_target) çağrılır. Hedeflenmeyen
## canavarlar tamamen pasif kalır (hareket etmez, saldırmaz).
func set_targeted(value: bool) -> void:
	is_targeted = value
	_target_ring.visible = value
	if value:
		_target_ring.queue_redraw()
	else:
		state = State.IDLE
		velocity = Vector2.ZERO
		_attack_ready = true

func _physics_process(_delta: float) -> void:
	if state == State.DEAD or not is_targeted or _player == null or not is_instance_valid(_player) or _player.is_dead:
		velocity = Vector2.ZERO
		_update_animation()
		return

	var to_player: Vector2 = _player.global_position - global_position
	var dist := to_player.length()

	if dist <= attack_range:
		state = State.ATTACK
		velocity = Vector2.ZERO
		if _attack_ready:
			_attack()
	else:
		state = State.CHASE
		velocity = to_player.normalized() * speed

	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	_visual.animation = "run" if state == State.CHASE else "idle"
	if abs(velocity.x) > 0.1:
		_visual.flip_h = velocity.x < 0.0

func _attack() -> void:
	_attack_ready = false
	_player.take_damage(attack_damage)
	await get_tree().create_timer(1.0).timeout
	_attack_ready = true

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	hp = max(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	_health_bar.update_ratio(float(hp) / float(max_hp))
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
	died.emit(xp_reward)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2.ZERO, 0.3)
	tw.parallel().tween_property(_health_bar, "scale", Vector2.ZERO, 0.15)
	await tw.finished
	queue_free()
