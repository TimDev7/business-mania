extends RefCounted
class_name ToppingsLogic

## «Топпинги»: заказ - набор топпингов (повторы значимы: два пепперони = два раза).
## Фронтенд при каждом броске топпинга на пиццу зовёт place(); порядок не важен.
## Один запуск мини-игры = один заказ; успех - заказ собран до конца таймера.

var order: Dictionary = {}
var wrong_count: int = 0

var _bag: ShuffleBag
var _left: Dictionary = {}


func _init(orders: Array, rng: RandomNumberGenerator) -> void:
	_bag = ShuffleBag.new(orders, rng)


## Берёт следующий заказ из колоды (без повторов подряд) и обнуляет прогресс.
func next_order() -> Dictionary:
	order = _bag.draw() if _bag.size() > 0 else {}
	wrong_count = 0
	_left.clear()
	for id in order.get("items", []):
		_left[id] = int(_left.get(id, 0)) + 1
	return order


## "ok" - топпинг нужен, заказ ещё не собран; "done" - заказ собран;
## "wrong" - такого топпинга нет в заказе или он уже выложен в нужном количестве
## (считается в wrong_count, заказ не ломается).
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
