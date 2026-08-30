class_name WorldGen
extends RefCounted
## Dünya üretimi: zemin, göl, yollar, kasaba, ormanlar. world.gd'den ayrıldı
## çünkü orası oyun mantığına (oyuncu/canavar/HUD) odaklı kalsın.
##
## Tüm tile'lar tek bir spritesheet'ten (Kenney "Roguelike/RPG Pack") gelir.
## Koordinatlar Vector2i(sütun, satır) biçiminde; spritesheet 16x16 tile,
## tile'lar arası 1px boşluk var.

const TILE := 16
const SHEET := "res://assets/tiles/roguelike_sheet.png"

# --- Atlas koordinatları (sütun, satır) ---
const GRASS := Vector2i(5, 0)

const DIRT := Vector2i(6, 0)
const DIRT_ALT := Vector2i(6, 1)
const BRICK := Vector2i(7, 2) # açık tuğla: çime karşı temiz kontrast, toprak yoldan ayrışıyor

## Zemin detayları: hepsi ŞEFFAF zeminli sprite'lar, bu yüzden çimin üstüne
## konunca kusursuz kaynaşırlar. (Tileset'teki "çiçekli çim" tile'ları bilinçli
## olarak kullanılmadı: farklı tonda opak yeşil zeminleri var ve içlerinde
## istenmeyen gri nesne artıkları bulunuyor — çimin üstünde yama gibi duruyorlar.)
const DETAIL_COMMON := [Vector2i(22, 10), Vector2i(22, 11), Vector2i(9, 1)]
const DETAIL_RARE := [Vector2i(23, 10), Vector2i(23, 11), Vector2i(21, 9)]

## Göl: 3x3 blok (köşeler yuvarlak, çime oturuyor). Ortası tekrarlanarak büyütülür.
const WATER := {
	"tl": Vector2i(2, 0), "t": Vector2i(3, 0), "tr": Vector2i(4, 0),
	"l": Vector2i(2, 1), "c": Vector2i(3, 1), "r": Vector2i(4, 1),
	"bl": Vector2i(2, 2), "b": Vector2i(3, 2), "br": Vector2i(4, 2),
}

const TREES_ROUND := [Vector2i(13, 10), Vector2i(14, 10), Vector2i(15, 10),
					  Vector2i(13, 11), Vector2i(15, 11)]
const TREES_PINE := [Vector2i(16, 10), Vector2i(17, 10), Vector2i(18, 10),
					 Vector2i(16, 11), Vector2i(18, 11)]
const HEDGES := [Vector2i(19, 10), Vector2i(20, 10), Vector2i(21, 10)]
const CROPS := [Vector2i(0, 6), Vector2i(1, 6), Vector2i(0, 7), Vector2i(1, 7)]
## Meydan ortasındaki yuvarlak taş kuyu: 4 çeyrek tile 2x2 dizilince tam daire olur.
const WELL := [[Vector2i(7, 13), Vector2i(8, 13)], [Vector2i(7, 14), Vector2i(8, 14)]]

# --- Yerleşim planı ---
const PLAZA_HALF := Vector2i(7, 5)    # tile cinsinden yarı genişlik/yükseklik
const PLAZA_CORNER_CUT := 3           # köşeleri pahlayıp dikdörtgen hissini kırar
const ROAD_HALF_TILES := 2            # yol yarı genişliği (tile)
const GROUND_DETAIL_COUNT := 520
const TOWN_CLEAR_RADIUS := 340.0      # bu yarıçapta ağaç/canavar doğmaz
const FOREST_CLUSTERS := 20
const TREES_PER_CLUSTER := Vector2i(38, 78)
## Ağaç sprite'ları 16x16; karakter de 16px olduğu için 1:1 ölçekte çalı gibi
## kalıyorlar (evler ~100px). 2x ölçek hem oranı düzeltiyor hem tam sayı
## olduğu için piksel netliğini bozmuyor.
const TREE_SCALE := 2.0
const LAKE_RECT := Rect2i(22, 12, 14, 9) # tile cinsinden (x, y, w, h)

var world_size: Vector2
var _parent: Node2D
var _center_tile: Vector2i
var _blockers: Array[Rect2] = [] # ağaç/canavar konamayacak alanlar (dünya koordinatı)

func _init(parent: Node2D, size: Vector2) -> void:
	_parent = parent
	world_size = size
	_center_tile = Vector2i(int(size.x / TILE / 2.0), int(size.y / TILE / 2.0))

func build() -> void:
	_build_ground()
	_build_paths()
	_build_lake()
	_build_town()
	_build_forests()
	_scatter_ground_detail()

func _is_in_plaza(pos: Vector2) -> bool:
	var c := Vector2(_center_tile) * TILE
	return absf(pos.x - c.x) <= PLAZA_HALF.x * TILE and absf(pos.y - c.y) <= PLAZA_HALF.y * TILE

func _is_in_lake(pos: Vector2) -> bool:
	return _tile_rect_to_world(LAKE_RECT).has_point(pos)

## --- Yardımcılar -------------------------------------------------------------

func _make_layer(z: int, tiles: Array) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(SHEET)
	atlas.texture_region_size = Vector2i(TILE, TILE)
	atlas.separation = Vector2i(1, 1)
	for coord in tiles:
		atlas.create_tile(coord)
	tile_set.add_source(atlas, 0)

	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.z_index = z
	_parent.add_child(layer)
	return layer

func _make_texture(coord: Vector2i) -> AtlasTexture:
	var pitch := TILE + 1
	var tex := AtlasTexture.new()
	tex.atlas = load(SHEET)
	tex.region = Rect2(coord.x * pitch, coord.y * pitch, TILE, TILE)
	return tex

func _add_sprite(coord: Vector2i, pos: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _make_texture(coord)
	sprite.position = pos
	_parent.add_child(sprite)
	return sprite

## Ağaç gibi "dikey duran" nesneler için: dokuyu yukarı kaydırır, böylece node'un
## konumu gövdenin dibine denk gelir. Y-sort node konumuna baktığı için ağaç,
## oyuncuyu ancak dibi oyuncunun altındaysa örter — yani gerçekten önündeyse.
## Ortalanmış dokuda ise ağacın tepesi de aşağı sayılıp beklenmedik örtme oluyor.
func _add_standing_sprite(coord: Vector2i, pos: Vector2, scale_factor: float) -> Sprite2D:
	var sprite := _add_sprite(coord, pos)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.offset.y = -TILE / 2.0
	return sprite

func _add_static_box(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	_parent.add_child(body)

func _tile_rect_to_world(r: Rect2i) -> Rect2:
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)

## --- Zemin -------------------------------------------------------------------

func _build_ground() -> void:
	var layer := _make_layer(-10, [GRASS])
	var w := int(world_size.x / TILE)
	var h := int(world_size.y / TILE)
	for y in h:
		for x in w:
			layer.set_cell(Vector2i(x, y), 0, GRASS)

## Tek düze yeşilliği kıran zemin detayları (ot tutamı, çakıl, çalı). Tile
## katmanı yerine şeffaf sprite'lar kullanılıyor — böylece hem çimin hem yolun
## üstünde dikişsiz duruyorlar.
func _scatter_ground_detail() -> void:
	for i in GROUND_DETAIL_COUNT:
		var pos := Vector2(
			randf_range(20.0, world_size.x - 20.0),
			randf_range(20.0, world_size.y - 20.0))
		if _is_in_plaza(pos) or _is_in_lake(pos):
			continue
		var palette: Array = DETAIL_RARE if randf() < 0.18 else DETAIL_COMMON
		_add_sprite(palette[randi() % palette.size()], pos)

## --- Meydan ve yollar --------------------------------------------------------

func _build_paths() -> void:
	var layer := _make_layer(-9, [BRICK, DIRT, DIRT_ALT])
	var w := int(world_size.x / TILE)
	var h := int(world_size.y / TILE)
	var c := _center_tile

	# Kasaba meydanı: tek tip döşeme (karışık tile "lekeli/çöplü" görünüyordu),
	# köşeleri pahlanmış — böylece ekranı dolduran keskin bir dikdörtgen olmuyor.
	for y in range(c.y - PLAZA_HALF.y, c.y + PLAZA_HALF.y + 1):
		for x in range(c.x - PLAZA_HALF.x, c.x + PLAZA_HALF.x + 1):
			if _is_plaza_corner(Vector2i(x, y) - c):
				continue
			layer.set_cell(Vector2i(x, y), 0, BRICK)

	# Dört ana yön yolu (toprak)
	for x in range(c.x + PLAZA_HALF.x, w):
		_road_strip(layer, x, c.y, true)
	for x in range(0, c.x - PLAZA_HALF.x):
		_road_strip(layer, x, c.y, true)
	for y in range(c.y + PLAZA_HALF.y, h):
		_road_strip(layer, y, c.x, false)
	for y in range(0, c.y - PLAZA_HALF.y):
		_road_strip(layer, y, c.x, false)

	_blockers.append(_tile_rect_to_world(Rect2i(
		c.x - PLAZA_HALF.x, c.y - PLAZA_HALF.y,
		PLAZA_HALF.x * 2 + 1, PLAZA_HALF.y * 2 + 1)))

func _is_plaza_corner(d: Vector2i) -> bool:
	var over_x: int = absi(d.x) - (PLAZA_HALF.x - PLAZA_CORNER_CUT)
	var over_y: int = absi(d.y) - (PLAZA_HALF.y - PLAZA_CORNER_CUT)
	return over_x > 0 and over_y > 0 and over_x + over_y > PLAZA_CORNER_CUT

## Yolun bir enine dilimi. En dıştaki tile bazen atlanır: kusursuz düz kenarlı
## bir şerit yapay duruyor, seyrek boşluk aşınmış toprak yol hissi veriyor.
func _road_strip(layer: TileMapLayer, along: int, across: int, horizontal: bool) -> void:
	for offset in range(-ROAD_HALF_TILES, ROAD_HALF_TILES + 1):
		if absi(offset) == ROAD_HALF_TILES and randf() < 0.35:
			continue
		var cell := Vector2i(along, across + offset) if horizontal else Vector2i(across + offset, along)
		layer.set_cell(cell, 0, DIRT if randf() < 0.8 else DIRT_ALT)

## Bir dünya konumu yol/meydan üstünde mi?
func is_on_path(pos: Vector2) -> bool:
	var c := Vector2(_center_tile) * TILE
	var road_half := (ROAD_HALF_TILES + 1) * TILE
	if abs(pos.x - c.x) < road_half or abs(pos.y - c.y) < road_half:
		return true
	return false

## --- Göl ---------------------------------------------------------------------

func _build_lake() -> void:
	var layer := _make_layer(-8, WATER.values())
	var r := LAKE_RECT
	for y in r.size.y:
		for x in r.size.x:
			# Konuma göre kenar/köşe/orta tile'ı seç: "tl", "t", "tr", "l", "c", ...
			var key := ""
			key += "t" if y == 0 else ("b" if y == r.size.y - 1 else "")
			key += "l" if x == 0 else ("r" if x == r.size.x - 1 else "")
			if key == "":
				key = "c"
			layer.set_cell(r.position + Vector2i(x, y), 0, WATER[key])

	# İçine yürünemesin: gölün (kenar tile'ları hariç) ortasına çarpışma kutusu
	var inner := Rect2i(r.position + Vector2i(1, 1), r.size - Vector2i(2, 2))
	var wr := _tile_rect_to_world(inner)
	_add_static_box(wr.get_center(), wr.size)
	_blockers.append(_tile_rect_to_world(r))

## --- Kasaba ------------------------------------------------------------------

func _build_town() -> void:
	var c := Vector2(_center_tile) * TILE

	# Evler meydanın çevresine, içeri bakacak şekilde yerleştirildi (rastgele değil,
	# "planlı yerleşim" hissi vermesi için elle konumlandırıldı).
	var houses := [
		{"tex": "house_orange", "pos": Vector2(-190, -120)},
		{"tex": "house_blue", "pos": Vector2(-40, -135)},
		{"tex": "house_orange", "pos": Vector2(130, -120)},
		{"tex": "house_blue", "pos": Vector2(-165, 95)},
		{"tex": "house_orange", "pos": Vector2(60, 100)},
	]
	for h in houses:
		var tex: Texture2D = load("res://assets/village/%s.png" % h["tex"])
		var pos: Vector2 = c + h["pos"]
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.position = pos
		_parent.add_child(sprite)
		# Çarpışma: evin sadece alt gövdesi (çatı altından geçilebilir hissi olmasın)
		_add_static_box(pos + Vector2(0, tex.get_height() * 0.22),
						Vector2(tex.get_width() * 0.8, tex.get_height() * 0.32))

	var stall := Sprite2D.new()
	stall.texture = load("res://assets/village/market_stall.png")
	stall.position = c + Vector2(-95, -5)
	_parent.add_child(stall)

	# Oyuncu meydanın tam ortasında doğduğu için kuyu hafif kaydırıldı; ayrıca
	# çevredeki evlerin/tezgahın kapladığı alanların dışında tutuldu.
	_build_well(c + Vector2(-15, 48))
	_build_farm(c + Vector2(250, 60), 6, 4)

## Meydana odak noktası: etrafından dolaşılan yuvarlak taş kuyu.
func _build_well(center: Vector2) -> void:
	for row in WELL.size():
		for col in WELL[row].size():
			var offset := Vector2(col - 0.5, row - 0.5) * TILE
			_add_sprite(WELL[row][col], center + offset)
	_add_static_box(center, Vector2(TILE * 1.8, TILE * 1.5))

## Kasabanın kenarına çitle çevrili ekili tarla — "burada insanlar yaşıyor" hissi
## verir. Çit, tarlayı çevreleyerek amaçlı görünür (öylesine serpilmiş çalı yerine).
func _build_farm(origin: Vector2, cols: int, rows: int) -> void:
	for row in rows:
		for col in cols:
			var coord: Vector2i = CROPS[(row + col) % CROPS.size()]
			_add_sprite(coord, origin + Vector2(col * TILE, row * TILE))

	for col in range(-1, cols + 1):
		_add_sprite(HEDGES[abs(col) % HEDGES.size()], origin + Vector2(col * TILE, -TILE))
		_add_sprite(HEDGES[abs(col) % HEDGES.size()], origin + Vector2(col * TILE, rows * TILE))
	for row in rows:
		_add_sprite(HEDGES[row % HEDGES.size()], origin + Vector2(-TILE, row * TILE))
		_add_sprite(HEDGES[row % HEDGES.size()], origin + Vector2(cols * TILE, row * TILE))

## --- Ormanlar ----------------------------------------------------------------

## Ağaçlar düzgün dağılmak yerine kümeler halinde serpilir: uniform rastgele
## dağılım "toz serpilmiş" gibi durur, kümelenme orman hissi verir.
func _build_forests() -> void:
	var town_center := world_size / 2.0
	for i in FOREST_CLUSTERS:
		var center := Vector2(
			randf_range(120.0, world_size.x - 120.0),
			randf_range(120.0, world_size.y - 120.0))
		if center.distance_to(town_center) < TOWN_CLEAR_RADIUS + 120.0:
			continue

		# Her orman tek tür ağırlıklı olsun (iğne yapraklı / yayvan) — karışık
		# palet kullanınca ormanlar birbirinin aynısı ve alacalı görünüyor.
		var palette: Array = TREES_PINE if randf() < 0.5 else TREES_ROUND
		var count := randi_range(TREES_PER_CLUSTER.x, TREES_PER_CLUSTER.y)
		var spread := randf_range(80.0, 150.0)

		for j in count:
			var pos := center + Vector2(randfn(0.0, spread), randfn(0.0, spread * 0.7))
			if not _can_place_decor(pos):
				continue
			_add_standing_sprite(palette[randi() % palette.size()], pos, TREE_SCALE)

	# Ormanlar arasına seyrek tek ağaç/çalı: açıklıklar tamamen çıplak kalmasın,
	# ama kümelenme okunaklılığını bozacak kadar da yoğun olmasın.
	for i in 70:
		var pos := Vector2(
			randf_range(60.0, world_size.x - 60.0),
			randf_range(60.0, world_size.y - 60.0))
		if not _can_place_decor(pos):
			continue
		if randf() < 0.3:
			_add_sprite(HEDGES[randi() % HEDGES.size()], pos)
		else:
			var trees: Array = TREES_ROUND + TREES_PINE
			_add_standing_sprite(trees[randi() % trees.size()], pos, TREE_SCALE)

func _can_place_decor(pos: Vector2) -> bool:
	if pos.x < 40.0 or pos.y < 40.0 or pos.x > world_size.x - 40.0 or pos.y > world_size.y - 40.0:
		return false
	if pos.distance_to(world_size / 2.0) < TOWN_CLEAR_RADIUS:
		return false
	if is_on_path(pos):
		return false
	for rect in _blockers:
		if rect.grow(TILE).has_point(pos):
			return false
	return true

## Canavar/oyuncu doğması güvenli mi? (kasaba, yol, göl dışında)
func is_spawn_safe(pos: Vector2) -> bool:
	if pos.distance_to(world_size / 2.0) < TOWN_CLEAR_RADIUS:
		return false
	for rect in _blockers:
		if rect.grow(TILE * 2).has_point(pos):
			return false
	return true
