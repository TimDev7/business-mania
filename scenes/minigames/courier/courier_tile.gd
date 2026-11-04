extends Button
class_name CourierTile

## Плитка дороги. Тап = просьба повернуть; поворачивать ли, решает логика.
## Картинка дороги лежит в %Road и вращается вокруг центра, подсветка пути и
## «якорь» (пиццерия/дом) - цвет %Background.

signal tapped(tile: CourierTile)

const COLOR_IDLE := Color("#d8c8a0")
const COLOR_LIT := Color("#9ed98f")
const COLOR_ANCHOR := Color("#c9a86a")
const TURN_SECONDS := 0.1

@onready var background: ColorRect = %Background
@onready var road: TextureRect = %Road

var row := 0
var col := 0

var _turns := 0
var _anchor := false
var _tween: Tween


func _ready() -> void:
	pressed.connect(func() -> void: tapped.emit(self))
	road.resized.connect(_center_pivot)
	_center_pivot()


## steps - стартовый поворот плитки (0..3 четверти по часовой).
func setup(r: int, c: int, texture: Texture2D, steps: int, is_anchor: bool) -> void:
	row = r
	col = c
	_anchor = is_anchor
	_turns = steps
	road.texture = texture
	road.rotation_degrees = steps * 90.0
	set_lit(false)
	visible = true


## Плавный поворот на 90° по часовой. Возвращает твин, чтобы можно было
## дождаться конца анимации (tween.finished).
func turn() -> Tween:
	_turns += 1
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(road, "rotation_degrees", _turns * 90.0, TURN_SECONDS)
	return _tween


func set_lit(lit: bool) -> void:
	background.color = COLOR_LIT if lit else (COLOR_ANCHOR if _anchor else COLOR_IDLE)


func _center_pivot() -> void:
	road.pivot_offset = road.size / 2.0
