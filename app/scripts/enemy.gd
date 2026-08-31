extends CharacterBody2D
## Faz A: gerçek düşman AI'ı. Canavarlar artık görüş menzilinde OTOMATİK aggro
## olur (önceden sadece oyuncu vurunca saldırıyordu — bu yüzden oyun risksizdi).
##
## Durum makinesi:
##   IDLE   — evinde (spawn noktası), pasif
##   CHASE  — oyuncuyu kovalıyor ya da eve dönüyor
##   ATTACK — menzilde, saldırıyor
##   DEAD   — ölüm animasyonu + queue_free
##
## Aggro edinme/bırakma:
##   - Oyuncu AGGRO_RANGE içine girince ya da canavar vurulunca aggro olur.
##   - Aggro'yken oyuncu (evden ölçülen) LEASH_RANGE'i aşarsa vazgeçip eve döner.
##     Leash EVDEN ölçülür ki oyuncu canavarı harita boyunca sürükleyemesin.
##
## `type_id` world.gd tarafından add_child'dan ÖNCE set edilir.

signal died(xp_reward: int)
signal health_changed(current: int, max_hp: int)

enum State { IDLE, CHASE, ATTACK, DEAD }

## Her canavar tipinin sprite klasörü ve dengelemesi. Yeni tip eklemek için
## sadece buraya bir satır + app/assets/monsters/<id>/ altına sprite koymak yeterli.
const ENEMY_TYPES := {
	"goblin": {
		"body_size": Vector2(16, 16), "max_hp": 40, "speed": 90.0,
		"attack_range": 34.0, "attack_damage": 10, "xp_reward": 15,
		"display_name": "Goblin", "level": 1,
	},
	"skelet": {
		"body_size": Vector2(16, 16), "max_hp": 65, "speed": 85.0,
		"attack_range": 34.0, "attack_damage": 15, "xp_reward": 30,
		"display_name": "İskelet", "level": 2,
	},
	"orc_warrior": {
		"body_size": Vector2(16, 23), "max_hp": 100, "speed": 75.0,
		"attack_range": 38.0, "attack_damage": 20, "xp_reward": 50,
		"display_name": "Ork Savaşçı", "level": 3,
	},
	"big_demon": {
		"body_size": Vector2(32, 36), "max_hp": 220, "speed": 65.0,
		"attack_range": 46.0, "attack_damage": 35, "xp_reward": 150,
		"display_name": "Dev İblis", "level": 5,
	},
}
const DEFAULT_TYPE := "goblin"

const AGGRO_RANGE := 175.0        # oyuncu bu menzile girince kovalamaya başlar
const LEASH_RANGE := 540.0        # evden bu kadar uzaklaşınca vazgeçip döner
const ATTACK_COOLDOWN := 1.0
const RETURN_SPEED_MULT := 0.75   # eve dönerken biraz daha yavaş
const SEPARATION_RANGE := 24.0    # bu mesafedeki komşulardan itilir (üst üste binmesin)
const SEPARATION_FORCE := 55.0

## world.gd bunu add_child()'dan ÖNCE set eder.
var type_id := DEFAULT_TYPE

var state: int = State.IDLE
var is_targeted := false          # sadece görsel: sarı halka + HUD hedef çubuğu
var is_aggro := false
var hp: int
var max_hp: int
var speed: float
var attack_range: float
var attack_damage: int
var xp_reward: int
var body_size: Vector2
var home_position: Vector2

var _attack_cooldown := 0.0
var _player: Node2D
var _visual: AnimatedSprite2D
var _collision_shape: CollisionShape2D
var _health_bar: HealthBar
var _target_ring: Node2D
var _name_label: Label

func _ready() -> void:
	add_to_group("enemies")
	home_position = position

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

	_name_label = Label.new()
	_name_label.text = "%s Lv.%d" % [get_display_name(), get_level()]
	_name_label.add_theme_font_size_override("font_size", 7)
	_name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(100, 14)
	_name_label.position = Vector2(-50, -body_size.y / 2.0 - 24.0)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

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

func get_display_name() -> String:
	var cfg: Dictionary = ENEMY_TYPES.get(type_id, {})
	return cfg.get("display_name", type_id.capitalize())

func get_level() -> int:
	var cfg: Dictionary = ENEMY_TYPES.get(type_id, {})
	return cfg.get("level", 1)

## Sadece görsel: sarı halka + HUD'un bu canavarı hedef alması. AI'yı ETKİLEMEZ
## (artık aggro bağımsız). Oyuncu bir canavara vurunca player.gd bunu çağırır.
func set_targeted(value: bool) -> void:
	is_targeted = value
	_target_ring.visible = value
	if value:
		_target_ring.queue_redraw()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		return

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	var player_available: bool = _player != null and is_instance_valid(_player) and not _player.is_dead
	if player_available:
		_update_aggro()

	if is_aggro and player_available:
		_chase_and_attack()
	else:
		is_aggro = false
		_return_home()

	move_and_slide()
	_update_animation()

func _update_aggro() -> void:
	var dist_player := global_position.distance_to(_player.global_position)
	if not is_aggro:
		if dist_player <= AGGRO_RANGE:
			is_aggro = true
	# Leash EVDEN ölçülür (oyuncunun konumundan değil) ki oyuncu canavarı haritanın
	# öbür ucuna sürükleyemesin. Hem canavar hem oyuncu bölgeden çıkınca vazgeçer;
	# oyuncu için de kontrol edilir ki canavar sınıra kadar boşuna koşmasın.
	elif global_position.distance_to(home_position) > LEASH_RANGE \
			or _player.global_position.distance_to(home_position) > LEASH_RANGE:
		is_aggro = false

func _chase_and_attack() -> void:
	var to_player: Vector2 = _player.global_position - global_position
	var dist := to_player.length()
	if dist <= attack_range:
		state = State.ATTACK
		velocity = _separation() # yerinde dururken bile komşulardan ayrış
		if _attack_cooldown <= 0.0:
			_do_attack()
	else:
		state = State.CHASE
		velocity = to_player.normalized() * speed + _separation()

func _return_home() -> void:
	var to_home := home_position - global_position
	if to_home.length() > 8.0:
		state = State.CHASE # koşma animasyonu
		velocity = to_home.normalized() * speed * RETURN_SPEED_MULT + _separation()
	else:
		state = State.IDLE
		velocity = Vector2.ZERO

## Yakın komşulardan iten kuvvet — canavarların üst üste yığılmasını önler.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		var off: Vector2 = global_position - other.global_position
		var d := off.length()
		if d > 0.01 and d < SEPARATION_RANGE:
			push += off.normalized() * (SEPARATION_RANGE - d) / SEPARATION_RANGE * SEPARATION_FORCE
	return push

func _update_animation() -> void:
	_visual.animation = "run" if state == State.CHASE else "idle"
	if absf(velocity.x) > 0.1:
		_visual.flip_h = velocity.x < 0.0

## Hasarı anında verir; cooldown _physics_process'te sayaçla işler. (Önceki
## `await create_timer` yaklaşımı, canavar bekleme sırasında queue_free edilirse
## serbest bırakılmış instance'ta devam edip hata veriyordu.)
func _do_attack() -> void:
	_attack_cooldown = ATTACK_COOLDOWN
	if is_instance_valid(_player) and not _player.is_dead:
		_player.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	hp = max(hp - amount, 0)
	is_aggro = true # vurulunca menzil dışında bile misilleme yapar
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
	_target_ring.visible = false
	died.emit(xp_reward)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2.ZERO, 0.3)
	tw.parallel().tween_property(_health_bar, "scale", Vector2.ZERO, 0.15)
	await tw.finished
	queue_free()
