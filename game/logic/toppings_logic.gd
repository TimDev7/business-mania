extends RefCounted
class_name ToppingsLogic

## «Топпинги»: заказ - набор топпингов (повторы значимы: два пепперони = два раза).
## Фронтенд при каждом броске топпинга на пиццу зовёт place(); порядок не важен.
## Один запуск мини-игры = один заказ; успех - заказ собран до конца таймера.

var order: Dictionary = {}
var wrong_count: int = 0
## {id топпинга: {"ru": ..., "en": ...}} - названия для фронтенда.
var items: Dictionary = {}

var _bag: ShuffleBag
var _left: Dictionary = {}
var _initial: Dictionary = {}


func _init(orders: Array, rng: RandomNumberGenerator, topping_items: Dictionary = {}) -> void:
	_bag = ShuffleBag.new(orders, rng)
	items = topping_items


## Путь к иконке топпинга (res://...) или "" - берётся из minigames.json.
func topping_icon_path(topping_id: String) -> String:
	var entry = items.get(topping_id, {})
	return str(entry.get("icon", "")) if entry is Dictionary else ""


func topping_name(topping_id: String, lang: String) -> String:
	var n := Localizer.text(items.get(topping_id, topping_id), lang)
	return n if n != "" else topping_id


## Берёт следующий заказ из колоды (без повторов подряд) и обнуляет прогресс.
func next_order() -> Dictionary:
	order = _bag.draw() if _bag.size() > 0 else {}
	wrong_count = 0
	_left.clear()
	for id in order.get("items", []):
		_left[id] = int(_left.get(id, 0)) + 1
	_initial = _left.duplicate()
	return order


## Лишний или не тот топпинг = пицца выброшена: заказ собирается заново с нуля.
## Время при этом идёт, поэтому класть всё подряд невыгодно. wrong_count не сбрасывается.
func restart_order() -> void:
	_left = _initial.duplicate()


## "ok" - топпинг нужен, заказ ещё не собран; "done" - заказ собран;
## "wrong" - такого топпинга нет в заказе или он уже выложен в нужном количестве
## (считается в wrong_count; фронтенд в ответ зовёт restart_order()).
func place(topping_id: String) -> String:
	if int(_left.get(topping_id, 0)) <= 0:
		wrong_count += 1
		return "wrong"
	_left[topping_id] = int(_left[topping_id]) - 1
	if _left[topping_id] == 0:
		_left.erase(topping_id)
	return "done" if _left.is_empty() else "ok"


## Чего ещё не хватает: {топпинг: сколько}.
func remaining() -> Dictionary:
	return _left.duplicate()


func is_complete() -> bool:
	return not order.is_empty() and _left.is_empty()
