extends Minigame

## «Курьер»: тапами поворачивай плитки, чтобы дорога шла сквозь от пиццерии
## до дома. Правила - в CourierLogic (rotate_tile / reachable / is_solved),
## здесь только сетка плиток и подсветка пути. Провал по времени считает CycleRun.

@onready var rule_label: Label = %RuleLabel
@onready var grid: GridContainer = %Grid

## Пауза после сборки дороги, чтобы игрок успел увидеть зелёный путь.
const SOLVED_PAUSE := 0.3

var _logic: CourierLogic
var _solved := false
var _tiles: Array[CourierTile] = []
var _textures: Dictionary = {} # тип плитки -> Texture2D


func _ready() -> void:
	for child in grid.get_children():
		if child is CourierTile:
			_tiles.append(child)
			child.tapped.connect(_on_tile_tapped)


## logic - CourierLogic с уже загруженной раскладкой; step.lang - язык игрока.
@warning_ignore("integer_division")
func start(logic: RefCounted, step: Dictionary) -> void:
	_logic = logic as CourierLogic
	if _logic == null:
		push_error("CourierMinigame: нет CourierLogic")
		return
	rule_label.text = Localizer.text(_logic.rule, str(step.get("lang", "ru")))
	var total := _logic.rows * _logic.cols
	if _tiles.size() < total:
		push_error("CourierMinigame: в сетке %d плиток, а раскладке нужно %d" % [_tiles.size(), total])
		return
	grid.columns = _logic.cols
	for i in _tiles.size():
		if i >= total:
			_tiles[i].visible = false
			continue
		var r := i / _logic.cols
		var c := i % _logic.cols
		var type := _logic.tile_type(r, c)
		_tiles[i].setup(r, c, _texture_for(type), _logic.tile_rotation(r, c), type == "P" or type == "H")
	_refresh()


func _texture_for(type: String) -> Texture2D:
	if not _textures.has(type):
		var path := str(_logic.tile_paths.get(type, ""))
		_textures[type] = load(path) if path != "" else null
	return _textures[type]


func _on_tile_tapped(tile: CourierTile) -> void:
	if _logic == null or _solved or not _logic.rotate_tile(tile.row, tile.col):
		return
	var turning := tile.turn()
	_refresh()
	if _logic.is_solved():
		# Дорога собрана: дожидаемся конца поворота и даём увидеть зелёный путь,
		# иначе мини-игра обрывается на середине анимации. Ввод на это время закрыт.
		_solved = true
		await turning.finished
		await get_tree().create_timer(SOLVED_PAUSE).timeout
		finish(true)


## Подсвечивает клетки, до которых уже доходит дорога от пиццерии.
func _refresh() -> void:
	var lit := _logic.reachable()
	for tile in _tiles:
		if tile.visible:
			tile.set_lit(lit.has(Vector2i(tile.row, tile.col)))
