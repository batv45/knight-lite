class_name MapDraw
## Minimap ve büyük haritanın ortak şematik çizimi: arazi (çim/yol/meydan/göl),
## canavar noktaları ve oyuncu işareti. İki ekranın aynı görünmesi ve tek yerden
## güncellenmesi için burada toplandı.

const GRASS_COLOR := Color(0.34, 0.55, 0.28)
const ROAD_COLOR := Color(0.55, 0.42, 0.28)
const PLAZA_COLOR := Color(0.78, 0.72, 0.56)
const LAKE_COLOR := Color(0.36, 0.69, 0.82)
const PLAYER_COLOR := Color(0.35, 0.68, 1.0)

static func color_for_type(type_id: String) -> Color:
	match type_id:
		"goblin":
			return Color(0.35, 0.88, 0.35)
		"skelet":
			return Color(0.95, 0.95, 0.90)
		"orc_warrior":
			return Color(0.80, 0.80, 0.25)
		"big_demon":
			return Color(0.95, 0.25, 0.25)
		_:
			return Color.YELLOW

## Araziyi çizer: çim zemin, dört yöne giden yollar, kasaba meydanı ve göl.
## `origin` haritanın sol üst köşesi, `scale_factor` dünya->harita ölçeği.
static func draw_terrain(canvas: CanvasItem, features: Dictionary,
						 world_size: Vector2, origin: Vector2, scale_factor: float) -> void:
	var map_size := world_size * scale_factor
	canvas.draw_rect(Rect2(origin, map_size), GRASS_COLOR)

	if features.is_empty():
		return

	var center: Vector2 = origin + (features["center"] as Vector2) * scale_factor
	var road_w: float = maxf(1.5, (features["road_width"] as float) * scale_factor)

	# Yollar dünyanın bir ucundan diğerine, merkezde kesişerek geçer.
	canvas.draw_rect(Rect2(origin.x, center.y - road_w / 2.0, map_size.x, road_w), ROAD_COLOR)
	canvas.draw_rect(Rect2(center.x - road_w / 2.0, origin.y, road_w, map_size.y), ROAD_COLOR)

	var plaza: Rect2 = features["plaza"]
	canvas.draw_rect(Rect2(origin + plaza.position * scale_factor, plaza.size * scale_factor), PLAZA_COLOR)

	var lake: Rect2 = features["lake"]
	canvas.draw_rect(Rect2(origin + lake.position * scale_factor, lake.size * scale_factor), LAKE_COLOR)

## Canavarları noktalar halinde çizer; `label_font` verilirse yanına adını yazar.
static func draw_enemies(canvas: CanvasItem, tree: SceneTree, origin: Vector2,
						 scale_factor: float, dot_radius: float,
						 label_font: Font = null, label_size: int = 13) -> void:
	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var p: Vector2 = origin + enemy.global_position * scale_factor
		var type_id: String = enemy.type_id if "type_id" in enemy else "goblin"
		canvas.draw_circle(p, dot_radius, color_for_type(type_id))
		if label_font != null and enemy.has_method("get_display_name"):
			canvas.draw_string(label_font, p + Vector2(dot_radius + 3.0, 4.0),
				enemy.get_display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, label_size,
				Color(1, 1, 1, 0.95))

## Oyuncuyu beyaz halkalı mavi nokta olarak çizer.
static func draw_player(canvas: CanvasItem, tree: SceneTree, origin: Vector2,
						scale_factor: float, dot_radius: float,
						label_font: Font = null, label_size: int = 13) -> void:
	var player := tree.get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	var p: Vector2 = origin + player.global_position * scale_factor
	canvas.draw_circle(p, dot_radius, PLAYER_COLOR)
	canvas.draw_arc(p, dot_radius, 0, TAU, 16, Color.WHITE, maxf(1.0, dot_radius * 0.3))
	if label_font != null:
		canvas.draw_string(label_font, p + Vector2(dot_radius + 3.0, 4.0), "Sen",
			HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(0.75, 0.88, 1.0))
