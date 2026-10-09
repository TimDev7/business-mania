extends RefCounted
class_name CycleRun

## Один цикл (90 с): раунды подряд до конца общего таймера.
## Раунд = подсказка A, мини-игра A, подсказка B, мини-игра B, квиз; A и B всегда разные.
## Время ведёт ТОЛЬКО tick(delta) - сам по себе никакого таймера нет, поэтому
## пауза = перестать звать tick, а логика одинаково работает в игре и в симуляции.
##
## Фронтенд: слушает step_started, рисует шаг, по итогу мини-игры зовёт
## report_minigame_result(), по нажатию варианта квиза - answer_quiz().
## Шаг, не уложившийся в общий таймер, обрывается ("aborted") и не засчитывается.

signal round_started(round_index: int, games: Array)
signal step_started(step: Dictionary)
## outcome: hint - "done"; minigame - "success"/"fail"/"timeout"/"aborted";
## quiz - "correct"/"wrong"/"timeout"/"aborted".
signal step_finished(step: Dictionary, outcome: String)
signal earned_changed(earned: int, delta: int)
signal finished(summary: Dictionary)

const KIND_HINT := "hint"
const KIND_MINIGAME := "minigame"
const KIND_QUIZ := "quiz"
const EPS := 0.000001
const MAX_STEPS_PER_TICK := 1000

var cycle_index: int
var time_left: float
var earned: int = 0
## Текущий шаг (пустой словарь до start() и после конца цикла).
var step: Dictionary = {}
var step_time_left: float = 0.0
var round_index: int = -1
var is_finished: bool = false

var _config: GameConfig
var _economy: Economy
var _deck: QuizDeck
var _mistakes: MistakeLog
var _upgrades: UpgradeShop
var _rng: RandomNumberGenerator
var _lang: String
var _queue: Array = []
var _step_truncated := false

var _minigames_won := 0
var _minigames_failed := 0
var _quiz_correct := 0
var _quiz_wrong := 0
var _tasks_done := 0


func _init(
		cycle_idx: int, config: GameConfig, economy: Economy, deck: QuizDeck,
		mistakes: MistakeLog, upgrades: UpgradeShop, rng: RandomNumberGenerator, lang: String) -> void:
	cycle_index = cycle_idx
	_config = config
	_economy = economy
	_deck = deck
	_mistakes = mistakes
	_upgrades = upgrades
	_rng = rng
	_lang = lang
	time_left = config.timing("cycle_seconds")


func set_language(lang: String) -> void:
	_lang = lang


func start() -> void:
	if not step.is_empty() or is_finished:
		return
	_advance()


## Продвигает время. Можно звать с любым delta, в том числе большим (лаг): шаги
## закрываются по очереди, остаток времени переходит в следующий.
func tick(delta: float) -> void:
	if is_finished or step.is_empty() or delta <= 0.0:
		return
	var left := delta
	var guard := 0
	while left > EPS and not is_finished and guard < MAX_STEPS_PER_TICK:
		guard += 1
		var dt := minf(left, minf(step_time_left, time_left))
		left -= dt
		step_time_left -= dt
		time_left -= dt
		if step_time_left <= EPS and not _step_truncated:
			_finish_step_by_own_timeout()
		elif time_left <= EPS:
			_finish_step("aborted")
		# Шаг без ограничения не бывает, но если лимит нулевой - цикл не зависнет: guard.


## Итог мини-игры. false, если сейчас не мини-игра (поздний/лишний вызов игнорируется).
func report_minigame_result(success: bool) -> bool:
	if is_finished or step.get("kind", "") != KIND_MINIGAME:
		return false
	if success:
		_minigames_won += 1
		_add_earned(int(step["reward"]))
	else:
		_minigames_failed += 1
	_tasks_done += 1
	_finish_step("success" if success else "fail")
	return true


## Ответ на квиз: индекс кнопки так, как варианты показаны игроку (после перемешивания).
## false, если сейчас не квиз или индекс невалиден.
func answer_quiz(shown_index: int) -> bool:
	if is_finished or step.get("kind", "") != KIND_QUIZ:
		return false
	var q: Dictionary = step["question"]
	var order: Array = q["order"]
	if shown_index < 0 or shown_index >= order.size():
		return false
	var correct: bool = shown_index == int(q["correct_index"])
	_resolve_quiz(correct, int(order[shown_index]))
	_finish_step("correct" if correct else "wrong")
	return true


func _finish_step_by_own_timeout() -> void:
	match step["kind"]:
		KIND_HINT:
			_finish_step("done")
		KIND_MINIGAME:
			_minigames_failed += 1
			_tasks_done += 1
			_finish_step("timeout")
		KIND_QUIZ:
			_resolve_quiz(false, -1)
			_finish_step("timeout")


func _resolve_quiz(correct: bool, original_option: int) -> void:
	_tasks_done += 1
	if correct:
		_quiz_correct += 1
	else:
		_quiz_wrong += 1
		_mistakes.add(cycle_index, step["question"]["id"], original_option)
	_add_earned(_economy.quiz_delta(correct))


func _finish_step(outcome: String) -> void:
	var done := step
	step = {}
	step_finished.emit(done, outcome)
	if time_left <= EPS or outcome == "aborted":
		_finish_cycle()
	else:
		_advance()


func _advance() -> void:
	if _queue.is_empty():
		_plan_round()
	_begin_step(_queue.pop_front())


func _plan_round() -> void:
	round_index += 1
	var games := pick_games(_config.minigames(), _rng)
	_queue.clear()
	for g in games:
		_queue.append({"kind": KIND_HINT, "game": g, "limit": _config.timing("hint_seconds")})
		var lvl := _upgrades.level(g)
		_queue.append({
			"kind": KIND_MINIGAME, "game": g,
			"limit": _economy.minigame_time(_config.timing("minigame_seconds"), lvl),
			"reward": _economy.minigame_reward(lvl),
			"upgrade_level": lvl,
		})
	_queue.append({"kind": KIND_QUIZ, "limit": _config.timing("quiz_seconds")})
	round_started.emit(round_index, games)


func _begin_step(s: Dictionary) -> void:
	if s["kind"] == KIND_QUIZ:
		s["question"] = _deck.present(_deck.draw(), _lang)
	step = s
	step_time_left = float(s["limit"])
	_step_truncated = time_left < step_time_left - EPS
	step_started.emit(step)


func _add_earned(delta: int) -> void:
	# Кошелёк цикла не уходит ниже нуля: штраф квиза не может сделать "заработано" отрицательным.
	var before := earned
	earned = maxi(0, earned + delta)
	earned_changed.emit(earned, earned - before)


func _finish_cycle() -> void:
	is_finished = true
	step = {}
	_queue.clear()
	finished.emit(build_summary())


## Две РАЗНЫЕ мини-игры в случайном порядке. Статическая - удобно проверять отдельно.
static func pick_games(pool: Array, rng: RandomNumberGenerator) -> Array:
	var bag := pool.duplicate()
	var a: int = rng.randi_range(0, bag.size() - 1)
	var first = bag[a]
	bag.remove_at(a)
	var second = bag[rng.randi_range(0, bag.size() - 1)]
	return [first, second]


func build_summary() -> Dictionary:
	var repay := _economy.repay_amount(cycle_index)
	var bonus := _economy.credit_bonus(earned, repay)
	var forgiven := _economy.is_shortfall_forgiven(cycle_index)
	var shortfall := maxi(0, repay - earned)
	return {
		"cycle_index": cycle_index,
		"principal": _economy.principal(cycle_index),
		"repay": repay,
		"earned": earned,
		"return_percent": _economy.return_percent(earned, repay),
		"credit_bonus": bonus,
		"credit_closed": _economy.is_credit_closed(earned, repay),
		"shortfall": shortfall,
		"shortfall_forgiven": forgiven and shortfall > 0,
		# Минус итога: в циклах 2-3 непогашенный остаток; дальше он не переносится.
		"net": maxi(0, earned - repay) if forgiven else earned - repay,
		"savings_base": _economy.savings_deposit(earned, bonus),
		"minigames_won": _minigames_won,
		"minigames_failed": _minigames_failed,
		"quiz_correct": _quiz_correct,
		"quiz_wrong": _quiz_wrong,
		"tasks_done": _tasks_done,
		"rounds_started": round_index + 1,
	}
