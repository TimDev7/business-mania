extends GameWindow
class_name MistakesWindow

## Разбор ошибок дня (самоанализ), отдельно от кейса куратора: по каждой ошибке
## вопрос, что ответил игрок, как верно и почему. Читаемость - через цвета и абзацы.

signal continue_pressed

@onready var text_label: RichTextLabel = %RichTextLabel # так назван узел в сцене
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	super._ready()
	continue_button.pressed.connect(continue_pressed.emit)


## mistakes - результат MistakeLog.describe_cycle (свежие первыми).
func show_mistakes(mistakes: Array) -> void:
	text_label.text = _format(mistakes)
	UiText.fill(continue_button, "btn_continue")
	open_window()


func _format(mistakes: Array) -> String:
	var parts: PackedStringArray = ["[i]%s[/i]\n" % UiText.t("mistakes_intro")]
	for m in mistakes:
		var mine := UiText.t("mistakes_timeout") if bool(m.get("timed_out", false)) else _esc(str(m.get("player_answer", "")))
		var block := "[b]%s[/b]\n" % _esc(str(m.get("question", "")))
		# Значки вместо слов «Ты / Верно / Почему»: красный крест, зелёная галочка, лампочка.
		block += "%s [color=#e0534a]%s[/color]\n" % [UiText.img("cross"), mine]
		block += "%s [color=#5cc46a]%s[/color]\n" % [UiText.img("check"), _esc(str(m.get("correct_answer", "")))]
		var why := str(m.get("explanation", ""))
		if why != "":
			block += "%s %s\n" % [UiText.img("bulb"), _esc(why)]
		parts.append(block)
	return "\n".join(parts)


## Квадратная скобка в тексте не должна стать тегом BBCode.
func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


## Закрыть фоном нельзя: с разбора выходят кнопкой.
func _on_back_button_pressed() -> void:
	pass
