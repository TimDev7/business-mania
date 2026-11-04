extends Minigame

## «Топпинги»: перетащи топпинги из лотка на пиццу по заказу. Правила - в
## ToppingsLogic (place() -> ok / done / wrong), здесь только ввод и показ.
## Успех - заказ собран; провал по времени засчитывает CycleRun сам.

@onready var order_label: Control = %OrderLabel # RichTextLabel покажет иконки топпингов
const ORDER_ICON_SIZE := 56 # размер иконки топпинга в заказе

@onready var pizza: Control = %Pizza
@onready var placed_template: TextureRect = %PlacedTemplate
@onready var tray: Control = %Tray
@onready var ghost: TextureRect = %DragGhost

var _logic: ToppingsLogic
var _lang := "ru"
var _chips: Dictionary = {} # topping_id -> ToppingChip
var _placed: Array[TextureRect] = [] # топпинги, уже лежащие на пицце
var _rng := RandomNumberGenerator.new()
var _flash_tween: Tween


func _ready() -> void:
	_rng.randomize()
	placed_template.visible = false
	ghost.visible = false
	for child in tray.get_children():
		if child is ToppingChip:
			_chips[child.topping_id] = child
			child.drag_started.connect(_on_drag_started)
			child.drag_moved.connect(_on_drag_moved)
			child.drag_ended.connect(_on_drag_ended)


## logic - ToppingsLogic с уже выбранным заказом; step.lang - язык игрока.
func start(logic: RefCounted, step: Dictionary) -> void:
	_logic = logic as ToppingsLogic
	_lang = str(step.get("lang", "ru"))
	if _logic == null:
		push_error("ToppingsMinigame: нет ToppingsLogic")
		return
	for id in _chips:
		var path := _logic.topping_icon_path(id)
		var icon: Texture2D = load(path) if path != "" else null
		_chips[id].setup(_logic.topping_name(id, _lang), icon)
	_refresh_order()


## Заказ: в RichTextLabel - иконки топпингов с числом («картинка x2»), в обычном
## Label - прежний текст с названиями. prefix - сообщение об ошибке над заказом.
func _refresh_order(prefix: String = "") -> void:
	var left := _logic.remaining()
	var parts: PackedStringArray = []
	var rich := order_label is RichTextLabel
	for id in left:
		var n := int(left[id])
		var count := " ×%d" % n if n > 1 else ""
		if rich:
			var path := _logic.topping_icon_path(id)
			parts.append(("[img=%d]%s[/img]" % [ORDER_ICON_SIZE, path] if path != "" else _logic.topping_name(id, _lang)) + count)
		else:
			parts.append(_logic.topping_name(id, _lang) + count)
	if rich:
		UiText.put(order_label, prefix + "   ".join(parts), "center")
	else:
		UiText.put(order_label, prefix + UiText.t("toppings_need") + ", ".join(parts))


func _on_drag_started(chip: ToppingChip) -> void:
	ghost.texture = chip.icon_texture
	ghost.visible = true


func _on_drag_moved(_chip: ToppingChip, pos: Vector2) -> void:
	ghost.global_position = pos - ghost.size / 2.0


func _on_drag_ended(chip: ToppingChip, pos: Vector2) -> void:
	ghost.visible = false
	if _logic == null or not pizza.get_global_rect().has_point(pos):
		return # отпустили мимо пиццы - ничего не происходит
	var result := _logic.place(chip.topping_id)
	if result == "wrong":
		_discard_pizza()
		return
	_add_placed(chip.icon_texture)
	_refresh_order()
	if result == "done":
		finish(true)


## Копия скрытого образца кладётся в случайное место на пицце.
func _add_placed(texture: Texture2D) -> void:
	var piece := placed_template.duplicate() as TextureRect
	piece.unique_name_in_owner = false
	piece.texture = texture
	piece.visible = true
	pizza.add_child(piece)
	_placed.append(piece)
	var radius := minf(pizza.size.x, pizza.size.y) * 0.3
	var offset := Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
	piece.position = pizza.size / 2.0 + offset - piece.size / 2.0


## Не тот топпинг: пицца выброшена, заказ собирается заново (время идёт).
func _discard_pizza() -> void:
	_logic.restart_order()
	for piece in _placed:
		var fade := create_tween()
		fade.tween_property(piece, "modulate:a", 0.0, 0.2)
		fade.tween_callback(piece.queue_free)
	_placed.clear()
	_refresh_order(UiText.t("toppings_wrong"))
	if _flash_tween != null:
		_flash_tween.kill()
	order_label.modulate = Color(1.0, 0.45, 0.4)
	_flash_tween = create_tween()
	_flash_tween.tween_property(order_label, "modulate", Color.WHITE, 0.6)
