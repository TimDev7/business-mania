extends RefCounted
class_name GameSession

## Фасад бэкенда: одна сессия игрока (2-3 цикла) от «Новый игрок» до итогового экрана.
## Фронтенд держит один экземпляр и ходит только сюда. Состояния:
##   IDLE -> start_cycle() -> CYCLE -> (cycle_finished) CYCLE_RESULT
##   -> begin_director() -> DIRECTOR -> submit_director_answer() -> SHOP -> start_cycle() ...
##   после директора последнего цикла -> FINISHED (session_finished).
## Копилка, апгрейды и ошибки живут только внутри сессии; new_player() сбрасывает всё.

signal cycle_started(cycle_index: int)
signal cycle_finished(summary: Dictionary)
signal piggy_changed(balance: int)
signal session_finished(final_summary: Dictionary)

enum State { IDLE, CYCLE, CYCLE_RESULT, DIRECTOR, SHOP, FINISHED }

var config: GameConfig
var economy: Economy
var shop: UpgradeShop
var mistakes: MistakeLog
var lang: String = "ru"
var state: State = State.IDLE
var cycle_index: int = -1
var piggy: int = 0
var run: CycleRun = null
## Нода-клиент прокси. Не задана (или пустой proxy_url) = директор работает на эталонах.
var director_client: DirectorClient = null
## Итоги циклов (с полями директора и копилки после закрытия цикла).
var cycle_summaries: Array = []

var _rng := RandomNumberGenerator.new()
var _deck: QuizDeck
var _director_history: Array = []
var _director_scores: Array = []
var _problem: Dictionary = {}
var _director_busy := false
var _toppings: ToppingsLogic
var _purchase: PurchaseLogic
var _courier: CourierLogic


## seed >= 0 - детерминированная сессия (для отладки и симуляций).
func _init(game_config: GameConfig, seed_value: int = -1) -> void:
	config = game_config
	economy = Economy.new(config.economy_data)
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	lang = str(config.settings.get("default_language", "ru"))
	shop = UpgradeShop.new(economy, config.minigames())
	mistakes = MistakeLog.new(config)
	_deck = QuizDeck.new(config.questions, _rng)
	_build_minigames()


## Сессия из game/data/*.json; ошибки данных уходят в push_error.
static func create_default(seed_value: int = -1) -> GameSession:
	var errors: Array = []
	var cfg := GameConfig.load_default(errors)
	for e in errors:
		push_error("GameSession: " + str(e))
	return GameSession.new(cfg, seed_value)


func set_language(new_lang: String) -> void:
	lang = new_lang
	if run != null:
		run.set_language(new_lang)


## Кнопка «Новый игрок»: всё в ноль.
func new_player() -> void:
	run = null
	state = State.IDLE
	cycle_index = -1
	piggy = 0
	cycle_summaries.clear()
	_director_history.clear()
	_director_scores.clear()
	_problem = {}
	_director_busy = false
	shop.reset()
	mistakes.clear()
	_deck.reset()
	_build_minigames()
	piggy_changed.emit(piggy)


func cycle_count() -> int:
	return config.cycle_count()


func is_last_cycle() -> bool:
	return cycle_index >= cycle_count() - 1


# --- Цикл ---

## Запускает следующий цикл (из IDLE или из магазина). Возвращает CycleRun,
## в который фронтенд подписывается и шлёт tick(); null если сейчас нельзя.
func start_cycle() -> CycleRun:
	if state != State.IDLE and state != State.SHOP:
		push_warning("GameSession.start_cycle: неверное состояние %d" % state)
		return null
	cycle_index += 1
	run = CycleRun.new(cycle_index, config, economy, _deck, mistakes, shop, _rng, lang)
	run.finished.connect(_on_cycle_finished)
	state = State.CYCLE
	cycle_started.emit(cycle_index)
	run.start()
	return run


## Свежая логика мини-игры для шага step_started (kind == "minigame", game == id):
## ToppingsLogic ("toppings"), PurchaseLogic ("purchase"), CourierLogic ("courier"),
## уже с загруженным следующим заказом/сценарием/раскладкой. null для неизвестного id.
func new_minigame(game_id: String) -> RefCounted:
	match game_id:
		"toppings":
			_toppings.next_order()
			return _toppings
		"purchase":
			_purchase.next_scenario()
			return _purchase
		"courier":
			_courier.next_layout()
			return _courier
	return null


func _build_minigames() -> void:
	var toppings_data: Dictionary = config.minigame_data.get("toppings", {})
	_toppings = ToppingsLogic.new(toppings_data.get("orders", []), _rng, toppings_data.get("items", {}))
	_purchase = PurchaseLogic.new(config.minigame_data.get("purchase", {}), _rng)
	_courier = CourierLogic.new(config.courier_layouts, _rng, config.minigame_data.get("courier", {}))


func tick(delta: float) -> void:
	if state == State.CYCLE and run != null:
		run.tick(delta)


func _on_cycle_finished(summary: Dictionary) -> void:
	cycle_summaries.append(summary)
	state = State.CYCLE_RESULT
	cycle_finished.emit(summary)


# --- Директор ---

## Выбирает проблему и открывает сцену директора. Возвращает данные для экрана
## (id, text, is_repeat, repeat_intro) плюс input_seconds и max_chars; {} при неверном состоянии.
func begin_director() -> Dictionary:
	if state != State.CYCLE_RESULT:
		push_warning("GameSession.begin_director: неверное состояние %d" % state)
		return {}
	_problem = DirectorLogic.pick_problem(config, cycle_index, cycle_count(), mistakes, _director_history, _rng)
	state = State.DIRECTOR
	var shown := DirectorLogic.present_problem(_problem, lang, _is_repeat(_problem), config)
	shown["input_seconds"] = float(config.director_setting("input_seconds"))
	shown["max_chars"] = int(config.director_setting("max_chars"))
	shown["mistakes"] = mistakes.describe_cycle(cycle_index, lang, int(config.director_setting("mistakes_explained")))
	return shown


## Отправляет ответ игрока (по таймеру 60 с - то, что успели написать).
## Вызывать через await. Результат: score, verdict, missing, better, is_fallback, note,
## bonus, mistakes (разбор на примерах игрока), savings_deposit, piggy. {} при неверном состоянии.
func submit_director_answer(text: String) -> Dictionary:
	if state != State.DIRECTOR or _director_busy:
		return {}
	_director_busy = true
	var clean := DirectorLogic.clamp_input(text, int(config.director_setting("max_chars")))
	var result: Dictionary
	if clean == "":
		result = DirectorLogic.empty_result(config, _problem, lang)
	else:
		result = await _evaluate(clean)
	_director_busy = false
	return _close_cycle(result)


## Директор пропущен (отладка / урезанная версия): бонус 0, проблема не показывалась.
func skip_director() -> Dictionary:
	if state != State.CYCLE_RESULT and state != State.DIRECTOR:
		return {}
	if _problem.is_empty():
		_problem = DirectorLogic.pick_problem(config, cycle_index, cycle_count(), mistakes, _director_history, _rng)
	state = State.DIRECTOR
	return _close_cycle(DirectorLogic.empty_result(config, _problem, lang))


func _evaluate(clean_text: String) -> Dictionary:
	var raw: Dictionary = {}
	if director_client != null:
		var sent := mistakes.describe_cycle(cycle_index, lang, int(config.director_setting("mistakes_in_request")))
		var payload := DirectorLogic.build_request(_problem["id"], lang, clean_text, sent)
		raw = await director_client.evaluate(payload)
	var parsed := DirectorLogic.parse_response(raw)
	if parsed.is_empty():
		var fallback := DirectorLogic.fallback_result(config, _problem, lang)
		# На время тестов на телефоне: код причины в пометке (config director.show_error_code).
		if config.director_setting("show_error_code") == true:
			var reason := director_client.last_error if director_client != null else "no_client"
			fallback["note"] = str(fallback.get("note", "")) + " [%s]" % reason
		return fallback
	return parsed


func _close_cycle(result: Dictionary) -> Dictionary:
	var summary: Dictionary = cycle_summaries[cycle_index]
	var bonus := economy.director_bonus(int(result["score"]))
	var deposit := int(summary["savings_base"]) + bonus
	piggy += deposit
	result["bonus"] = bonus
	result["mistakes"] = mistakes.describe_cycle(cycle_index, lang, int(config.director_setting("mistakes_explained")))
	result["savings_deposit"] = deposit
	result["piggy"] = piggy
	summary["director_problem"] = _problem.get("id", "")
	summary["director_score"] = int(result["score"])
	summary["director_bonus"] = bonus
	summary["director_fallback"] = bool(result.get("is_fallback", false))
	summary["savings_deposit"] = deposit
	summary["piggy_after"] = piggy
	_director_history.append(_problem.get("id", ""))
	_director_scores.append(int(result["score"]))
	_problem = {}
	piggy_changed.emit(piggy)
	if is_last_cycle():
		state = State.FINISHED
		session_finished.emit(final_summary())
	else:
		state = State.SHOP
	return result


func _is_repeat(problem: Dictionary) -> bool:
	for id in _director_history:
		if config.problem_by_id(id).get("topic", "") == problem.get("topic", ""):
			return true
	return false


# --- Магазин ---

func shop_catalog() -> Array:
	return shop.catalog(piggy)


## Покупка уровня станции за копилку. false - нельзя (нет денег, максимум, не магазин).
func buy_upgrade(game_id: String) -> bool:
	if state != State.SHOP:
		return false
	var cost := shop.buy(game_id, piggy)
	if cost < 0:
		return false
	piggy -= cost
	piggy_changed.emit(piggy)
	return true


# --- Итог ---

## Данные итогового экрана: топ ошибок, итоги циклов, динамика оценок директора.
func final_summary() -> Dictionary:
	return {
		"top_mistakes": mistakes.top(int(config.settings.get("final_screen", {}).get("top_mistakes", 3)), lang),
		"total_mistakes": mistakes.size(),
		"cycles": cycle_summaries.duplicate(true),
		"director_scores": _director_scores.duplicate(),
		"piggy": piggy,
		"learn_more_url": str(config.settings.get("final_screen", {}).get("learn_more_url", "")),
	}
