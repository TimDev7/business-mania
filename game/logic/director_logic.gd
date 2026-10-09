extends RefCounted
class_name DirectorLogic

## Сцена директора без сети: выбор проблемы, разбор ввода и ответа модели,
## запасной вариант. Вызов Gemini (через прокси) делает DirectorClient.

const MAX_SCORE := 3


## Выбирает проблему цикла. history - id уже показанных проблем (по порядку).
## Цикл 1..N-1: тема с наибольшим числом ошибок квиза в этом цикле среди ещё не
## использованных тем (нет ошибок - любая неиспользованная). Последний цикл
## (при cycle_count >= 2): тема цикла 1, второй вариант.
static func pick_problem(
		config: GameConfig, cycle_index: int, cycle_count: int,
		mistakes: MistakeLog, history: Array, rng: RandomNumberGenerator) -> Dictionary:
	var problems: Array = config.problems
	if problems.is_empty():
		return {}

	if cycle_index >= 1 and cycle_index == cycle_count - 1 and not history.is_empty():
		var first := config.problem_by_id(history[0])
		for p in problems:
			if p["topic"] == first.get("topic", "") and int(p["variant"]) != int(first.get("variant", 1)):
				return p

	var used_topics: Array = history.map(func(id): return config.problem_by_id(id).get("topic", ""))
	var free_topics: Array = config.topics.filter(func(t): return not used_topics.has(t))
	if not free_topics.is_empty():
		var counts := mistakes.topic_counts(cycle_index)
		var best := -1
		var tied: Array = []
		for t in free_topics:
			var c := int(counts.get(t, 0))
			if c > best:
				best = c
				tied = [t]
			elif c == best:
				tied.append(t)
		var topic = tied[rng.randi_range(0, tied.size() - 1)]
		return _first_unused(problems, topic, history)

	# Тем меньше, чем циклов: берём любую непоказанную проблему, иначе первую.
	for p in problems:
		if not history.has(p["id"]):
			return p
	return problems[0]


## Проблема в виде для показа.
static func present_problem(problem: Dictionary, lang: String, is_repeat: bool, config: GameConfig) -> Dictionary:
	return {
		"id": problem.get("id", ""),
		"topic": problem.get("topic", ""),
		"text": Localizer.text(problem.get("text", {}), lang),
		"is_repeat": is_repeat,
		"repeat_intro": Localizer.text(config.director_strings.get("repeat_intro", {}), lang) if is_repeat else "",
	}


## Ввод игрока: переводы строк -> пробелы, обрезка пробелов по краям и до max_chars символов.
static func clamp_input(text: String, max_chars: int) -> String:
	var t := text.replace("\r", " ").replace("\n", " ").strip_edges()
	if t.length() > max_chars:
		t = t.substr(0, max_chars).strip_edges()
	return t


## Тело запроса к прокси. Рубрику и эталон прокси берёт у себя по problem_id;
## ошибки - уже описанные MistakeLog.describe (текст на языке игрока).
static func build_request(problem_id: String, lang: String, text: String, described_mistakes: Array) -> Dictionary:
	var items: Array = []
	for m in described_mistakes:
		items.append({
			"question": m["question"],
			"player_answer": m["player_answer"],
			"correct_answer": m["correct_answer"],
			"explanation": m["explanation"],
		})
	return {"problem_id": problem_id, "lang": lang, "text": text, "mistakes": items}


## Проверяет JSON ответа прокси. Возвращает нормализованный результат или {} если ответ негоден.
static func parse_response(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var r: Dictionary = raw
	var score = r.get("score")
	if not (score is int or score is float) or float(score) != floorf(float(score)):
		return {}
	var s := int(score)
	if s < 0 or s > MAX_SCORE:
		return {}
	for key in ["verdict", "better"]:
		if not (r.get(key) is String) or (r[key] as String).strip_edges() == "":
			return {}
	if not (r.get("missing", "") is String):
		return {}
	return {
		"score": s,
		"verdict": _cap(r["verdict"], 400),
		"missing": _cap(r.get("missing", ""), 250),
		"better": _cap(r["better"], 500),
		"is_fallback": false,
		"note": "",
	}


## Пустой ответ: 0 баллов без запроса к модели.
static func empty_result(config: GameConfig, problem: Dictionary, lang: String) -> Dictionary:
	return {
		"score": 0,
		"verdict": Localizer.text(config.director_strings.get("empty_verdict", {}), lang),
		"missing": "",
		"better": Localizer.text(problem.get("reference", {}), lang),
		"is_fallback": false,
		"note": "",
	}


## Запасной вариант (нет связи, 8 с без ответа, невалидный JSON): эталон и нейтральная оценка.
static func fallback_result(config: GameConfig, problem: Dictionary, lang: String) -> Dictionary:
	return {
		"score": int(config.director_setting("neutral_score")),
		"verdict": "",
		"missing": "",
		"better": Localizer.text(problem.get("reference", {}), lang),
		"is_fallback": true,
		"note": Localizer.text(config.director_strings.get("fallback_note", {}), lang),
	}


static func _first_unused(problems: Array, topic: String, history: Array) -> Dictionary:
	var candidates: Array = problems.filter(func(p): return p["topic"] == topic)
	candidates.sort_custom(func(a, b): return int(a["variant"]) < int(b["variant"]))
	for p in candidates:
		if not history.has(p["id"]):
			return p
	return candidates[0] if not candidates.is_empty() else problems[0]


static func _cap(s: String, max_len: int) -> String:
	var t := s.strip_edges()
	return t if t.length() <= max_len else t.substr(0, max_len - 1).strip_edges() + "…"
