extends Node

## Дирижёр сцены Play (архитектура - CLAUDE.md, раздел Businessmania).
## Держит GameSession, слушает её сигналы и решает, что показать. Только он
## вызывает методы session; view и окна сообщают о действиях игрока сигналами.
## Поток: вступление (легенда + куратор) -> день -> итог дня -> кейс куратора ->
## разбор ошибок -> магазин -> следующий день; после кейса последнего дня - финал.
## Обучалка: при первом появлении каждого задания, квиза и кейса время стоит,
## пока игрок не закроет подсказку. Музыка: спокойная вне дня, бодрая в день.

## id мини-игры -> сцена (наследник Minigame). Нет в словаре -> stub_minigame.
@export var minigame_scenes: Dictionary[String, PackedScene] = {}
@export var stub_minigame: PackedScene

@onready var director_client: DirectorClient = $DirectorClient
@onready var hud: Hud = %Hud
@onready var hint_view: HintView = %HintView
@onready var quiz_view: QuizView = %QuizView
@onready var minigame_host: Control = %MinigameHost
@onready var windows: WindowsManager = %Windows

var session: GameSession
var _minigame: Minigame
var _blocked := false # открыт диалог или подсказка: время дня стоит
var _after_dialog := Callable()
var _seen_tutorials := {} # id -> true, чтобы показывать подсказку один раз за стажировку
var _last_mistakes: Array = []


func _ready() -> void:
	session = GameSession.create_default()
	# Язык выбран на титуле (GameLanguage); сессия работает на нём, а не на default_language из конфига.
	GameLanguage.ensure_loaded()
	session.set_language(UiText.lang)
	# Адрес прокси и таймаут - из config.json (поле в инспекторе ноды остаётся запасным).
	var proxy_url := str(session.config.director_setting("proxy_url"))
	if proxy_url != "":
		director_client.proxy_url = proxy_url
	director_client.timeout_seconds = float(session.config.director_setting("request_timeout_seconds"))
	session.director_client = director_client
	session.cycle_finished.connect(_on_cycle_finished)

	quiz_view.answered.connect(_on_quiz_answered)
	windows.cycle_next_pressed.connect(_on_cycle_next_pressed)
	windows.director_submitted.connect(_on_director_submitted)
	windows.director_continue_pressed.connect(_on_director_continue_pressed)
	windows.mistakes_continue_pressed.connect(_after_reflection)
	windows.buy_pressed.connect(_on_buy_pressed)
	windows.shop_next_pressed.connect(_start_cycle)
	windows.learn_more_pressed.connect(func() -> void: windows.show_coming_soon(UiText.t("coming_soon")))
	windows.restart_pressed.connect(_begin_session)
	windows.dialog_finished.connect(_on_dialog_finished)

	UiText.localize_tree(self) # статичные надписи окон (метаданные tr_key) на выбранном языке
	UiStyle.apply(self)
	_begin_session()


func _process(delta: float) -> void:
	if _blocked or session.state != GameSession.State.CYCLE or session.run == null:
		return
	session.tick(delta)
	var run := session.run
	hud.update_values(run.time_left, run.earned, run.step_time_left, float(run.step.get("limit", 0.0)))


# --- Сессия и диалоги ---

## Новая стажировка: сброс, вступление (его можно пропустить), потом первый день.
func _begin_session() -> void:
	session.new_player()
	_seen_tutorials.clear()
	_last_mistakes = []
	windows.close_all()
	GameMusic.set_mood("calm")
	_open_dialog(Story.intro(), UiText.t("btn_start_day"), true, _start_cycle)


## Показывает диалог; пока он открыт, время дня стоит. after вызывается по закрытии.
func _open_dialog(pages: Array, last_button: String, can_skip: bool, after: Callable) -> void:
	if pages.is_empty():
		if after.is_valid():
			after.call()
		return
	_blocked = true
	_after_dialog = after
	windows.show_dialog(pages, last_button, can_skip)


func _on_dialog_finished() -> void:
	_blocked = false
	var next := _after_dialog
	_after_dialog = Callable()
	if next.is_valid():
		next.call()


## Подсказка «как играть» - только при первом появлении (id: задание, quiz, case).
func _tutorial_once(id: String, after: Callable = Callable()) -> void:
	if _seen_tutorials.has(id):
		if after.is_valid():
			after.call()
		return
	_seen_tutorials[id] = true
	_open_dialog(Story.tutorial(id), UiText.t("btn_got_it"), false, after)


# --- День ---

func _start_cycle() -> void:
	var run := session.start_cycle()
	if run == null:
		return
	run.step_started.connect(_on_step_started)
	run.step_finished.connect(_on_step_finished)
	run.earned_changed.connect(func(_earned: int, delta: int) -> void: hud.show_delta(delta))
	var i := run.cycle_index
	hud.setup(i + 1, session.cycle_count(), session.economy.principal(i), session.economy.repay_amount(i), run.time_left)
	windows.close_all()
	GameMusic.set_mood("vigorous")
	# start() выпустил первый шаг ещё до подписки - показываем его вручную.
	if not run.step.is_empty():
		_on_step_started(run.step)


func _on_step_started(step: Dictionary) -> void:
	var kind: String = step.get("kind", "")
	var game: String = step.get("game", "")
	hint_view.visible = kind == CycleRun.KIND_HINT
	quiz_view.visible = kind == CycleRun.KIND_QUIZ
	minigame_host.visible = kind == CycleRun.KIND_MINIGAME
	if kind == CycleRun.KIND_HINT:
		hint_view.show_hint(_minigame_text("titles", game), _minigame_text("hints", game))
		_tutorial_once(game)
	elif kind == CycleRun.KIND_MINIGAME:
		_spawn_minigame(step)
	elif kind == CycleRun.KIND_QUIZ:
		quiz_view.show_question(step.get("question", {}))
		_tutorial_once("quiz")


func _on_step_finished(step: Dictionary, _outcome: String) -> void:
	# Мини-игра убирается при любом исходе: успех, провал, таймаут шага или конец дня.
	if step.get("kind", "") == CycleRun.KIND_MINIGAME:
		_clear_minigame()


func _spawn_minigame(step: Dictionary) -> void:
	_clear_minigame()
	var game: String = step.get("game", "")
	var scene: PackedScene = minigame_scenes.get(game, stub_minigame)
	if scene == null:
		push_error("Play: нет сцены мини-игры для '%s' и не задан stub_minigame" % game)
		return
	_minigame = scene.instantiate() as Minigame
	minigame_host.add_child(_minigame)
	UiStyle.apply(_minigame)
	_minigame.finished.connect(_on_minigame_finished)
	# Логику (заказ/сценарий/раскладку) берём только для настоящей мини-игры, не для заглушки.
	var logic: RefCounted = session.new_minigame(game) if minigame_scenes.has(game) else null
	var shown := step.duplicate()
	shown["title"] = _minigame_text("titles", game)
	shown["lang"] = session.lang
	_minigame.start(logic, shown)


func _clear_minigame() -> void:
	if _minigame != null and is_instance_valid(_minigame):
		_minigame.queue_free()
	_minigame = null


func _on_minigame_finished(success: bool) -> void:
	if session.run != null:
		session.run.report_minigame_result(success)


func _on_quiz_answered(shown_index: int) -> void:
	if session.run != null:
		session.run.answer_quiz(shown_index)


# --- Между днями ---

func _on_cycle_finished(summary: Dictionary) -> void:
	_clear_minigame()
	GameMusic.set_mood("calm")
	var shown := summary.duplicate()
	shown["day_count"] = session.cycle_count() # окно итога говорит «день N из M» и «это не конец»
	windows.show_cycle_result(shown)


func _on_cycle_next_pressed() -> void:
	var problem := session.begin_director()
	if problem.is_empty():
		return
	# Таймер ответа идёт сам в окне куратора, поэтому подсказка - до его открытия.
	_tutorial_once("case", func() -> void: windows.show_director(problem))


func _on_director_submitted(text: String) -> void:
	windows.show_director_thinking()
	var result := await session.submit_director_answer(text)
	if result.is_empty():
		return
	_last_mistakes = result.get("mistakes", [])
	windows.show_director_result(result)


func _on_director_continue_pressed() -> void:
	if _last_mistakes.is_empty():
		_after_reflection()
	else:
		windows.show_mistakes(_last_mistakes)


## После кейса и разбора ошибок: финал или магазин.
func _after_reflection() -> void:
	if session.state == GameSession.State.FINISHED:
		windows.show_final(session.final_summary())
	else:
		windows.show_shop(session.shop_catalog(), session.piggy, _game_titles())


func _on_buy_pressed(game_id: String) -> void:
	if session.buy_upgrade(game_id):
		windows.refresh_shop(session.shop_catalog(), session.piggy)


func _game_titles() -> Dictionary:
	var titles := {}
	for g in session.config.minigames():
		titles[g] = _minigame_text("titles", g)
	return titles


func _minigame_text(section: String, game: String) -> String:
	var texts: Dictionary = session.config.minigame_data.get(section, {})
	return Localizer.text(texts.get(game, game), session.lang)
