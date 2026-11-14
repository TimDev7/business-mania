class_name PixelDialog
extends Control
## Белое пиксельное диалоговое окно, выезжает снизу экрана.
## Наружу: show_text(text), close() и сигналы next_pressed / closed.

signal next_pressed
signal closed

const CHARS_PER_SEC := 45.0
const SLIDE_TIME := 0.25
const BOTTOM_MARGIN := 24.0

@onready var _panel: PanelContainer = %Panel
@onready var _text: RichTextLabel = %Text

var _tween: Tween
var _type_tween: Tween
var _shown_y := 0.0
var _is_open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_text.add_theme_color_override("default_color", Color.BLACK)
	_text.fit_content = true
	_text.scroll_active = false
	_panel.gui_input.connect(_on_panel_input)
	_panel.hide()


func show_text(text: String) -> void:
	_text.text = text
	_text.visible_ratio = 0.0
	if not _is_open:
		await _slide_in()
	_type_text()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_kill_tweens()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:y", size.y, SLIDE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tween.finished
	_panel.hide()
	closed.emit()


func _slide_in() -> void:
	_is_open = true
	_panel.show()
	await get_tree().process_frame  # даём контейнеру посчитать высоту
	_shown_y = size.y - _panel.size.y - BOTTOM_MARGIN
	_panel.position.y = size.y
	_kill_tweens()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:y", _shown_y, SLIDE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _tween.finished


func _type_text() -> void:
	var total := _text.get_total_character_count()
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, maxf(total / CHARS_PER_SEC, 0.05))


func _on_panel_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	if _text.visible_ratio < 1.0:  # первый тап дописывает текст сразу
		if _type_tween:
			_type_tween.kill()
		_text.visible_ratio = 1.0
	else:
		next_pressed.emit()


func _kill_tweens() -> void:
	if _tween:
		_tween.kill()
