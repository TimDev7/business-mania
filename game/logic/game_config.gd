extends RefCounted
class_name GameConfig

## Все данные игры: тайминги, экономика, вопросы, проблемы директора.
## Читаются из game/data/*.json; в коде нет ни одного игрового числа.

const CONFIG_PATH := "res://game/data/config.json"
const ECONOMY_PATH := "res://game/data/economy.json"
const QUESTIONS_PATH := "res://game/data/questions.json"
const DIRECTOR_PATH := "res://game/data/director.json"
const MINIGAMES_PATH := "res://game/data/minigames.json"
const COURIER_PATH := "res://game/data/courier_layouts.json"

var settings: Dictionary = {}
var economy_data: Dictionary = {}
var questions: Array = []
var topics: Array = []
var problems: Array = []
var director_strings: Dictionary = {}
## Контент мини-игр: toppings {items, orders}, purchase {budget, step, start, scenarios}.
var minigame_data: Dictionary = {}
var courier_layouts: Array = []

var _questions_by_id: Dictionary = {}
var _problems_by_id: Dictionary = {}


## Загружает и проверяет все файлы. Ошибки данных - в errors (пустой массив = всё ок).
static func load_default(errors: Array = []) -> GameConfig:
	var c := GameConfig.new()
	c.settings = _read_json(CONFIG_PATH, errors)
	c.economy_data = _read_json(ECONOMY_PATH, errors)
	var q := _read_json(QUESTIONS_PATH, errors)
	var d := _read_json(DIRECTOR_PATH, errors)
	c.questions = q.get("questions", [])
	c.topics = q.get("topics", [])
	c.problems = d.get("problems", [])
	c.director_strings = d.get("strings", {})
	c.minigame_data = _read_json(MINIGAMES_PATH, errors)
	c.courier_layouts = _read_json(COURIER_PATH, errors).get("layouts", [])
	c._index()
	for e in c.validate():
		errors.append(e)
	return c


## Из готовых словарей - для отладки и симуляций.
static func from_dicts(
		settings_d: Dictionary, economy_d: Dictionary, questions_d: Dictionary, director_d: Dictionary,
		minigames_d: Dictionary = {}, courier_layouts_a: Array = []) -> GameConfig:
	var c := GameConfig.new()
	c.settings = settings_d
	c.economy_data = economy_d
	c.questions = questions_d.get("questions", [])
	c.topics = questions_d.get("topics", [])
	c.problems = director_d.get("problems", [])
	c.director_strings = director_d.get("strings", {})
	c.minigame_data = minigames_d
	c.courier_layouts = courier_layouts_a
	c._index()
	return c


func question_by_id(id: String) -> Dictionary:
	return _questions_by_id.get(id, {})


func problem_by_id(id: String) -> Dictionary:
	return _problems_by_id.get(id, {})


func cycle_count() -> int:
	return int(settings.get("cycle_count", 3))


func minigames() -> Array:
	return settings.get("minigames", [])


func timing(key: String) -> float:
	return float(settings.get("timing", {}).get(key, 0.0))


func director_setting(key: String) -> Variant:
	return settings.get("director", {}).get(key)


func languages() -> Array:
	return settings.get("languages", ["ru"])


## Проверка целостности данных. Возвращает список человекочитаемых ошибок.
func validate() -> PackedStringArray:
	var errs := PackedStringArray()
	if settings.is_empty():
		errs.append("config.json: пусто или не прочитан")
	if economy_data.is_empty():
		errs.append("economy.json: пусто или не прочитан")
	if minigames().size() < 2:
		errs.append("config.json: нужно минимум 2 мини-игры (в раунде они всегда разные)")
	var principals: Array = economy_data.get("credit", {}).get("principals", [])
	if principals.size() < cycle_count():
		errs.append("economy.json: principals короче cycle_count (%d < %d)" % [principals.size(), cycle_count()])
	if economy_data.get("upgrades", {}).get("prices", []).is_empty():
		errs.append("economy.json: нет цен апгрейдов")

	var seen := {}
	for q in questions:
		var id: String = q.get("id", "")
		if id == "" or seen.has(id):
			errs.append("questions.json: пустой или повторяющийся id '%s'" % id)
		seen[id] = true
		if not topics.has(q.get("topic", "")):
			errs.append("questions.json: %s - неизвестная тема '%s'" % [id, q.get("topic", "")])
		var correct := int(q.get("correct", -1))
		var ru_opts := Localizer.list(q.get("options", {}), "ru")
		if ru_opts.size() != 4:
			errs.append("questions.json: %s - нужно ровно 4 варианта ответа" % id)
		if correct < 0 or correct >= ru_opts.size():
			errs.append("questions.json: %s - 'correct' вне диапазона" % id)
		for lang in languages():
			var opts = q.get("options", {}).get(lang)
			if opts != null and opts.size() != ru_opts.size():
				errs.append("questions.json: %s - число вариантов в '%s' не совпадает с ru" % [id, lang])
		if Localizer.text(q.get("text", {}), "ru") == "" or Localizer.text(q.get("explanation", {}), "ru") == "":
			errs.append("questions.json: %s - нет текста или объяснения на ru" % id)

	var by_topic := {}
	for p in problems:
		var pid: String = p.get("id", "")
		var topic: String = p.get("topic", "")
		if not topics.has(topic):
			errs.append("director.json: %s - неизвестная тема '%s'" % [pid, topic])
		if Localizer.text(p.get("text", {}), "ru") == "" or Localizer.text(p.get("reference", {}), "ru") == "":
			errs.append("director.json: %s - нет текста или эталона на ru" % pid)
		if not by_topic.has(topic):
			by_topic[topic] = []
		by_topic[topic].append(int(p.get("variant", 0)))
	for t in topics:
		var v: Array = by_topic.get(t, [])
		if not (v.has(1) and v.has(2)):
			errs.append("director.json: у темы '%s' должны быть варианты 1 и 2" % t)
	errs.append_array(_validate_minigames())
	return errs


func _validate_minigames() -> PackedStringArray:
	var errs := PackedStringArray()
	if minigame_data.is_empty():
		errs.append("minigames.json: пусто или не прочитан")
		return errs
	var items: Dictionary = minigame_data.get("toppings", {}).get("items", {})
	for o in minigame_data.get("toppings", {}).get("orders", []):
		for t in o.get("items", []):
			if not items.has(t):
				errs.append("minigames.json: заказ %s - неизвестный топпинг '%s'" % [o.get("id", "?"), t])
	var pd: Dictionary = minigame_data.get("purchase", {})
	var budget := int(pd.get("budget", 100))
	var snap := int(pd.get("step", 5))
	for sc in pd.get("scenarios", []):
		if not PurchaseLogic.is_feasible(sc, budget, snap):
			errs.append("minigames.json: сценарий %s невыполним (зоны не дают сумму %d)" % [sc.get("id", "?"), budget])
		var start := PurchaseLogic.check_values(pd.get("start", {}), sc, budget)
		if start["success"]:
			errs.append("minigames.json: сценарий %s решён со стартовых значений" % sc.get("id", "?"))
	if courier_layouts.is_empty():
		errs.append("courier_layouts.json: нет раскладок")
	for l in courier_layouts:
		var c := CourierLogic.new([], RandomNumberGenerator.new())
		c.load_layout(l)
		if c.types.size() != c.rows * c.cols:
			errs.append("courier_layouts.json: %s - размер сетки не совпадает" % l.get("id", "?"))
		elif not c.is_solvable():
			errs.append("courier_layouts.json: %s неразрешима" % l.get("id", "?"))
		elif c.is_solved():
			errs.append("courier_layouts.json: %s уже решена с начала" % l.get("id", "?"))
	return errs


func _index() -> void:
	_questions_by_id.clear()
	_problems_by_id.clear()
	for q in questions:
		_questions_by_id[q.get("id", "")] = q
	for p in problems:
		_problems_by_id[p.get("id", "")] = p


## .json в Godot 4 - ресурс типа JSON (попадает в экспорт как обычный ресурс);
## FileAccess - запасной путь для редактора/отладки.
static func _read_json(path: String, errors: Array) -> Dictionary:
	var parsed: Variant = null
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is JSON:
			parsed = res.data
	if parsed == null and FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("не удалось прочитать JSON: " + path)
		return {}
	return parsed
