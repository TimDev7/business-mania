extends RefCounted
class_name ShuffleBag

## Случайный порядок без повторов; когда мешок пуст - перемешивается заново
## (без повтора одного и того же элемента на стыке). Порядок воспроизводим по seed RNG.

var _items: Array
var _rng: RandomNumberGenerator
var _bag: Array = []
var _last: Variant = null


func _init(items: Array, rng: RandomNumberGenerator) -> void:
	_items = items
	_rng = rng


func reset() -> void:
	_bag.clear()
	_last = null


func size() -> int:
	return _items.size()


## Следующий элемент или null, если пул пуст.
func draw() -> Variant:
	if _items.is_empty():
		return null
	if _bag.is_empty():
		_refill()
	_last = _bag.pop_back()
	return _last


func _refill() -> void:
	_bag = _items.duplicate()
	_shuffle(_bag)
	# Следующим берётся последний элемент (pop_back): на стыке мешков не даём ему совпасть с прошлым.
	if _bag.size() > 1 and is_same(_bag.back(), _last):
		var t = _bag[0]
		_bag[0] = _bag[_bag.size() - 1]
		_bag[_bag.size() - 1] = t


# Fisher-Yates на нашем RNG.
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
