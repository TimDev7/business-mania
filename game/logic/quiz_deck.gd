extends RefCounted
class_name QuizDeck

## Колода вопросов: случайный порядок без повторов, после исчерпания перемешивается заново.

var _bag: ShuffleBag
var _rng: RandomNumberGenerator


func _init(questions: Array, rng: RandomNumberGenerator) -> void:
	_bag = ShuffleBag.new(questions, rng)
	_rng = rng


func reset() -> void:
	_bag.reset()


## Следующий вопрос (исходный словарь из JSON) или {} если вопросов нет.
func draw() -> Dictionary:
	var q = _bag.draw()
	if q == null:
		push_error("QuizDeck: пустой пул вопросов")
		return {}
	return q


## Вопрос для показа: тексты на языке игрока, варианты перемешаны.
## order[i] - индекс варианта в JSON, который показан на i-й кнопке.
func present(q: Dictionary, lang: String) -> Dictionary:
	var opts: Array = Localizer.list(q.get("options", {}), lang)
	var order: Array = range(opts.size())
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var shown: Array = []
	var correct_shown := -1
	for i in order.size():
		shown.append(opts[order[i]])
		if order[i] == int(q.get("correct", -1)):
			correct_shown = i
	return {
		"id": q.get("id", ""),
		"topic": q.get("topic", ""),
		"text": Localizer.text(q.get("text", {}), lang),
		"options": shown,
		"correct_index": correct_shown,
		"order": order,
	}
