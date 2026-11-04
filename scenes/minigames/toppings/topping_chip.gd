extends Button
class_name ToppingChip

## Топпинг в лотке: иконка и название. Сам ничего не кладёт - при нажатии и
## движении пальца/мыши сообщает позицию, решает мини-игра. Нажатие "захватывает"
## ввод: motion и release приходят сюда, даже когда палец ушёл за пределы кнопки.
## topping_id задаётся в инспекторе инстанса; иконку подставляет мини-игра из
## данных (icon_texture в инспекторе - необязательная замена).

signal drag_started(chip: ToppingChip)
signal drag_moved(chip: ToppingChip, global_pos: Vector2)
signal drag_ended(chip: ToppingChip, global_pos: Vector2)

@export var topping_id: String = ""
@export var icon_texture: Texture2D

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel

var _dragging := false


func _ready() -> void:
	icon_rect.texture = icon_texture


func setup(title: String, icon: Texture2D) -> void:
	name_label.text = title
	if icon_texture == null:
		icon_texture = icon
	icon_rect.texture = icon_texture


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			drag_started.emit(self)
			drag_moved.emit(self, get_global_mouse_position())
		elif _dragging:
			_dragging = false
			drag_ended.emit(self, get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		drag_moved.emit(self, get_global_mouse_position())
