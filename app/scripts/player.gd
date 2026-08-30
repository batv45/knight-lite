extends CharacterBody2D
## Faz 3 + asset entegrasyonu + hedef kilitleme: hareket + savaş + leveling.
## Görsel: 0x72'nin "DungeonTilesetII" paketinden şövalye (knight_m) sprite'ları.
##
## Saldırınca vurduğun canavar "hedef" olur (current_target): o canavar artık
## sana saldırmaya başlar (bkz. enemy.gd set_targeted), etrafında halka belirir,
## HUD'da üstte HP'si görünür. Başka bir canavara vurunca hedef değişir.

signal died
signal health_changed(current: int, max_hp: int)
signal mp_changed(current: int, max_mp: int)
signal xp_changed(current: int, needed: int, level: int)
signal leveled_up(new_level: int)
signal gold_changed(amount: int)
signal target_changed(enemy: Node)

const SPEED := 180.0
const BODY_SIZE := 16.0
const BASE_MAX_HP := 100
const BASE_MAX_MP := 50
const BASE_ATTACK_DAMAGE := 20
const HP_PER_LEVEL := 20
const MP_PER_LEVEL := 10
const ATTACK_PER_LEVEL := 5
const MP_REGEN_PER_SEC := 5.0
const ATTACK_RANGE := 46.0
const ATTACK_COOLDOWN := 0.4
const RESPAWN_DELAY := 1.5

const SPRITE_DIR := "res://assets/characters/knight/"

var hp := BASE_MAX_HP
var max_hp := BASE_MAX_HP
var mp := BASE_MAX_MP
var max_mp := BASE_MAX_MP
var attack_damage := BASE_ATTACK_DAMAGE
var level := 1
var xp := 0
var xp_to_next := _xp_for_level(1)
var gold := 0
var current_target: Node = null

var facing := Vector2.DOWN
var can_attack := true
var is_dead := false
var spawn_point := Vector2.ZERO

var _mp_regen_accum := 0.0
var _visual: AnimatedSprite2D
var _collision_shape: CollisionShape2D
var _health_bar: HealthBar

func _ready() -> void:
	add_to_group("player")
	spawn_point = position

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

func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	frames.add_animation("idle")
	frames.set_animation_speed("idle", 6.0)
	frames.set_animation_loop("idle", true)
	for i in 4:
		frames.add_frame("idle", load(SPRITE_DIR + "knight_m_idle_anim_f%d.png" % i))

	frames.add_animation("run")
	frames.set_animation_speed("run", 10.0)
	frames.set_animation_loop("run", true)
	for i in 4:
		frames.add_frame("run", load(SPRITE_DIR + "knight_m_run_anim_f%d.png" % i))

	return frames

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	_regen_mp(delta)

	var dir := InputBridge.get_move_vector()
	if dir.length() > 0.1:
		facing = dir.normalized()
	velocity = dir * SPEED
	move_and_slide()

	_update_animation(dir)

	if InputBridge.consume_attack_request():
		_attack()

func _regen_mp(delta: float) -> void:
	if mp >= max_mp:
		return
	_mp_regen_accum += MP_REGEN_PER_SEC * delta
	if _mp_regen_accum >= 1.0:
		var whole := int(_mp_regen_accum)
		_mp_regen_accum -= whole
		mp = min(mp + whole, max_mp)
		mp_changed.emit(mp, max_mp)

func _update_animation(dir: Vector2) -> void:
	_visual.animation = "run" if dir.length() > 0.1 else "idle"
	if abs(dir.x) > 0.1:
		_visual.flip_h = dir.x < 0.0

func _attack() -> void:
	if not can_attack or is_dead:
		return
	can_attack = false
	_play_attack_flash()

	var hit_target: Node = null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() <= ATTACK_RANGE and to_enemy.normalized().dot(facing) > 0.3:
			enemy.take_damage(attack_damage)
			# Bu vuruşla öldüyse hedef olarak işaretleme (ölüm sinyali zaten
			# current_target'ı temizledi, üstüne yazıp geri getirmeyelim).
			if hit_target == null and is_instance_valid(enemy) and enemy.is_alive():
				hit_target = enemy
	if hit_target != null:
		_set_target(hit_target)

	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true

## Hedefi değiştirir: eski hedefin "targeted" durumunu kapatır (artık saldırmaz,
## halkası kaybolur), yeniyi açar. Hedef ölünce de bu, null ile çağrılır.
func _set_target(enemy: Node) -> void:
	if current_target == enemy:
		return
	if is_instance_valid(current_target):
		current_target.set_targeted(false)
		if current_target.died.is_connected(_on_target_died):
			current_target.died.disconnect(_on_target_died)

	current_target = enemy
	if is_instance_valid(current_target):
		current_target.set_targeted(true)
		current_target.died.connect(_on_target_died, CONNECT_ONE_SHOT)

	target_changed.emit(current_target)

func _on_target_died(_xp_reward: int) -> void:
	current_target = null
	target_changed.emit(null)

func _play_attack_flash() -> void:
	# Yöne doğru kısa bir "hamle" (lunge) + sıkışma-esneme (squash & stretch) efekti.
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	var lunge := facing * 5.0
	tw.tween_property(_visual, "position", lunge, 0.05)
	tw.parallel().tween_property(_visual, "scale", Vector2(1.3, 0.85), 0.05)
	tw.tween_property(_visual, "position", Vector2.ZERO, 0.14)
	tw.parallel().tween_property(_visual, "scale", Vector2.ONE, 0.14)

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
	_set_target(null)
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
	max_mp += MP_PER_LEVEL
	attack_damage += ATTACK_PER_LEVEL
	hp = max_hp
	mp = max_mp
	xp_to_next = _xp_for_level(level)
	health_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
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
