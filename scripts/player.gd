extends CharacterBody2D
## Faz 3: hareket + savaş + leveling. Görsel şimdilik düz renkli kare (placeholder) —
## asset paketi seçilince bu kısım gerçek sprite/AnimatedSprite2D ile değişecek.

signal died
signal health_changed(current: int, max_hp: int)
signal xp_changed(current: int, needed: int, level: int)
signal leveled_up(new_level: int)
signal gold_changed(amount: int)

const SPEED := 180.0
const BODY_SIZE := 32.0
const BASE_MAX_HP := 100
const BASE_ATTACK_DAMAGE := 20
const HP_PER_LEVEL := 20
const ATTACK_PER_LEVEL := 5
const ATTACK_RANGE := 46.0
const ATTACK_COOLDOWN := 0.4
const RESPAWN_DELAY := 1.5

var hp := BASE_MAX_HP
var max_hp := BASE_MAX_HP
var attack_damage := BASE_ATTACK_DAMAGE
var level := 1
var xp := 0
var xp_to_next := _xp_for_level(1)
var gold := 0

var facing := Vector2.DOWN
var can_attack := true
var is_dead := false
var spawn_point := Vector2.ZERO

var _visual: ColorRect
var _collision_shape: CollisionShape2D
var _health_bar: HealthBar

func _ready() -> void:
	add_to_group("player")
	spawn_point = position

	_visual = ColorRect.new()
	_visual.color = Color(0.2, 0.6, 1.0) # mavi kare = karakter
	_visual.size = Vector2(BODY_SIZE, BODY_SIZE)
	_visual.pivot_offset = _visual.size / 2.0
	_visual.position = -_visual.size / 2.0
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	var dir := InputBridge.get_move_vector()
	if dir.length() > 0.1:
		facing = dir.normalized()
	velocity = dir * SPEED
	move_and_slide()

	if InputBridge.consume_attack_request():
		_attack()

func _attack() -> void:
	if not can_attack or is_dead:
		return
	can_attack = false
	_play_attack_flash()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() <= ATTACK_RANGE and to_enemy.normalized().dot(facing) > 0.3:
			enemy.take_damage(attack_damage)
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true

func _play_attack_flash() -> void:
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(_visual, "scale", Vector2.ONE, 0.08)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp = max(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	_health_bar.update_ratio(float(hp) / float(max_hp))
	_flash_hit()
	if hp <= 0:
		_die()

func _flash_hit() -> void:
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color(1, 0.3, 0.3), 0.08)
	tw.tween_property(_visual, "modulate", Color.WHITE, 0.25)

func _die() -> void:
	is_dead = true
	visible = false
	_collision_shape.disabled = true
	died.emit()
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	_respawn()

func _respawn() -> void:
	hp = max_hp
	health_changed.emit(hp, max_hp)
	_health_bar.update_ratio(1.0)
	global_position = spawn_point
	is_dead = false
	visible = true
	_collision_shape.disabled = false

## --- Leveling & loot -------------------------------------------------------

func _xp_for_level(lvl: int) -> int:
	return 30 + lvl * 20 # basit doğrusal eğri, ileride dengelenebilir

func gain_xp(amount: int) -> void:
	if is_dead:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	xp_changed.emit(xp, xp_to_next, level)

func _level_up() -> void:
	level += 1
	max_hp += HP_PER_LEVEL
	attack_damage += ATTACK_PER_LEVEL
	hp = max_hp
	xp_to_next = _xp_for_level(level)
	health_changed.emit(hp, max_hp)
	_health_bar.update_ratio(1.0)
	leveled_up.emit(level)
	_play_level_up_flash()

func _play_level_up_flash() -> void:
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color(1, 0.95, 0.4), 0.15)
	tw.tween_property(_visual, "modulate", Color.WHITE, 0.35)

func gain_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
