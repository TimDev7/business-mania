extends RefCounted
class_name MistakeLog

## Лог ошибок квиза за сессию. Нужен для темы директора, разбора ошибок цикла
## и итогового экрана (топ ошибок). Хранит id и индексы, тексты берёт из конфига
## в момент показа - язык можно сменить посреди сессии.

var _config: GameConfig
var _entries: Array = []


func _init(config: GameConfig) -> void:
	_config = config


func clear() -> void:
	_entries.clear()


## chosen_option - индекс варианта в JSON (до перемешивания), -1 если вышло время.
func add(cycle_index: int, question_id: String, chosen_option: int) -> void:
	var q := _config.question_by_id(question_id)
	_entries.append({
		"cycle": cycle_index,
		"question_id": question_id,
		"topic": q.get("topic", ""),
		"chosen": chosen_option,
		"seq": _entries.size(),
	})


func size() -> int:
	return _entries.size()


func for_cycle(cycle_index: int) -> Array:
	return _entries.filter(func(e): return e["cycle"] == cycle_index)


## {тема: число ошибок} за цикл.
func topic_counts(cycle_index: int) -> Dictionary:
	var counts := {}
	for e in for_cycle(cycle_index):
		counts[e["topic"]] = int(counts.get(e["topic"], 0)) + 1
	return counts


## Ошибка в виде, пригодном для показа и для запроса к директору.
func describe(entry: Dictionary, lang: String) -> Dictionary:
	var q := _config.question_by_id(entry["question_id"])
	var opts: Array = Localizer.list(q.get("options", {}), lang)
	var chosen := int(entry["chosen"])
	var correct := int(q.get("correct", -1))
	return {
		"question_id": entry["question_id"],
		"topic": entry["topic"],
		"cycle": entry["cycle"],
		"question": Localizer.text(q.get("text", {}), lang),
		"player_answer": opts[chosen] if chosen >= 0 and chosen < opts.size() else "",
		"timed_out": chosen < 0,
		"correct_answer": opts[correct] if correct >= 0 and correct < opts.size() else "",
		"explanation": Localizer.text(q.get("explanation", {}), lang),
	}


## Ошибки цикла, описанные для показа; не больше limit (0 = все), свежие первыми.
func describe_cycle(cycle_index: int, lang: String, limit: int = 0) -> Array:
	var items := for_cycle(cycle_index)
	items.reverse()
	if limit > 0 and items.size() > limit:
		items = items.slice(0, limit)
	return items.map(func(e): return describe(e, lang))


## Топ ошибок за все циклы: по числу повторов вопроса, при равенстве - более свежие.
func top(limit: int, lang: String) -> Array:
	var groups := {}
	for e in _entries:
		var id: String = e["question_id"]
		if not groups.has(id):
			groups[id] = {"count": 0, "last": e}
		groups[id]["count"] += 1
		groups[id]["last"] = e
	var list: Array = groups.values()
	list.sort_custom(func(a, b):
		if a["count"] != b["count"]:
			return a["count"] > b["count"]
		return a["last"]["seq"] > b["last"]["seq"])
	if list.size() > limit:
		list = list.slice(0, limit)
	return list.map(func(g):
		var d := describe(g["last"], lang)
		d["count"] = g["count"]
		return d)
