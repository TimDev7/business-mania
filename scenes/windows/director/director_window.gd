extends GameWindow
class_name DirectorWindow

## Окно куратора (класс и сцена назывались «директор» - имя историческое): кейс ->
## свободный ответ (60 с, до 150 символов) -> «куратор думает» -> оценка и подсказка.
## Разбор ошибок дня - отдельное окно (MistakesWindow). Про GameSession окно не знает:
## наружу answer_submitted(text) и continue_pressed. Тексты - из UiText.

signal answer_submitted(text: String)
signal continue_pressed

@onready var problem_label: Label = %ProblemLabel

@onready var input_panel: Control = %InputPanel
@onready var answer_edit: TextEdit = %AnswerEdit
@onready var chars_label: Label = %CharsLabel
@onready var timer_label: Label = %TimerLabel
@onready var submit_button: Button = %SubmitButton

@onready var thinking_label: RichTextLabel = %ThinkingLabel

@onready var result_panel: Control = %ResultPanel
@onready var score_label: Control = %ScoreLabel # RichTextLabel покажет звёзды вместо текста
@onready var verdict_label: Label = %VerdictLabel
@onready var missing_label: Label = %MissingLabel
@onready var better_label: Label = %BetterLabel
@onready var note_label: Label = %NoteLabel
@onready var bonus_label: Control = %BonusLabel # RichTextLabel покажет иконку фета
@onready var continue_button: Button = %ContinueButton
# Необязательные ноды: старая сцена без них продолжит работать.
@onready var mistakes_label: Label = get_node_or_null("%MistakesLabel")
@onready var portrait_rect: TextureRect = get_node_or_null("%PortraitRect")

var _max_chars := 150
var _time_left := 0.0
var _waiting_input := false


func _ready() -> void:
	super._ready()
	set_process(false)
	answer_edit.text_changed.connect(_on_text_changed)
	submit_button.pressed.connect(_submit)
	continue_button.pressed.connect(continue_pressed.emit)
	# Разбор ошибок переехал в MistakesWindow: старая подпись из сцены не нужна.
	if mistakes_label != null:
		mistakes_label.visible = false


func _process(delta: float) -> void:
	_time_left -= delta
	timer_label.text = UiText.t("seconds_short", [ceili(maxf(0.0, _time_left))])
	if _time_left <= 0.0:
		_submit() # по таймеру уходит то, что успели написать


## problem - результат GameSession.begin_director().
func show_problem(problem: Dictionary) -> void:
	_max_chars = int(problem.get("max_chars", 150))
	# input_seconds = 0 (config.director) - без ограничения по времени: ни таймера, ни автоотправки.
	_time_left = float(problem.get("input_seconds", 0.0))
	timer_label.visible = _time_left > 0.0
	var intro := str(problem.get("repeat_intro", ""))
	problem_label.text = (intro + "\n\n" if intro != "" else "") + str(problem.get("text", ""))
	UiText.fill(submit_button, "btn_submit")
	if portrait_rect != null:
		portrait_rect.texture = Story.mentor_portrait()
	answer_edit.text = ""
	_update_chars()
	input_panel.visible = true
	thinking_label.visible = false
	result_panel.visible = false
	_waiting_input = true
	set_process(_time_left > 0.0)
	open_window()


func show_thinking() -> void:
	_waiting_input = false
	set_process(false)
	input_panel.visible = false
	thinking_label.visible = true


## result - результат GameSession.submit_director_answer(). Если у дня есть ошибки,
## кнопка ведёт к разбору ошибок, иначе просто «Дальше».
func show_result(result: Dictionary) -> void:
	var score := int(result.get("score", 0))
	UiText.put(score_label, UiText.stars(score, 3) if score_label is RichTextLabel else UiText.t("mentor_score", [score]), "center")
	verdict_label.text = str(result.get("verdict", ""))
	_set_optional(missing_label, UiText.t("mentor_missing", [str(result.get("missing", ""))]) if str(result.get("missing", "")) != "" else "")
	_set_optional(better_label, UiText.t("mentor_better", [str(result.get("better", ""))]) if str(result.get("better", "")) != "" else "")
	_set_optional(note_label, str(result.get("note", "")))
	UiText.put(bonus_label, UiText.t("mentor_bonus", [
		UiText.money_for(bonus_label, int(result.get("bonus", 0))),
		UiText.money_for(bonus_label, int(result.get("savings_deposit", 0))),
		UiText.money_for(bonus_label, int(result.get("piggy", 0)))]))
	var has_mistakes: bool = not (result.get("mistakes", []) as Array).is_empty()
	continue_button.text = UiText.t("btn_mistakes") if has_mistakes else UiText.t("btn_continue")
	thinking_label.visible = false
	result_panel.visible = true


func _submit() -> void:
	if not _waiting_input:
		return
	_waiting_input = false
	set_process(false)
	answer_submitted.emit(answer_edit.text)


func _on_text_changed() -> void:
	if answer_edit.text.length() > _max_chars:
		answer_edit.text = answer_edit.text.substr(0, _max_chars)
		answer_edit.set_caret_column(_max_chars)
	_update_chars()


func _update_chars() -> void:
	chars_label.text = UiText.t("chars_counter", [answer_edit.text.length(), _max_chars])


func _set_optional(label: Label, text: String) -> void:
	label.text = text
	label.visible = text != ""


## Закрыть фоном нельзя: ответ куратору нельзя пропустить случайным тапом.
func _on_back_button_pressed() -> void:
	pass
