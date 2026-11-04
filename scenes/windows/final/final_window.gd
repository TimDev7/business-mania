extends GameWindow
class_name FinalWindow

## Итог стажировки: копилка, динамика оценок куратора, топ-3 ошибки,
## «Углубиться» и «Новый день». Тексты - из UiText.

signal learn_more_pressed
signal restart_pressed

@onready var piggy_label: Control = %PiggyLabel # RichTextLabel покажет иконку фета
@onready var scores_label: Label = %ScoresLabel
@onready var mistakes_label: Label = %MistakesLabel
@onready var learn_more_button: Button = %LearnMoreButton
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	super._ready()
	learn_more_button.pressed.connect(learn_more_pressed.emit)
	restart_button.pressed.connect(restart_pressed.emit)


## summary - GameSession.final_summary().
func show_final(summary: Dictionary) -> void:
	UiText.put(piggy_label, UiText.t("final_piggy", [UiText.money_for(piggy_label, int(summary.get("piggy", 0)))]), "center")
	var scores: Array = summary.get("director_scores", [])
	scores_label.visible = not scores.is_empty()
	scores_label.text = UiText.t("final_scores") + ", ".join(scores.map(func(s) -> String: return str(s)))
	mistakes_label.text = _format_top(summary.get("top_mistakes", []))
	UiText.fill(learn_more_button, "btn_learn_more")
	UiText.fill(restart_button, "btn_new_day")
	open_window()


func _format_top(top: Array) -> String:
	if top.is_empty():
		return UiText.t("final_no_mistakes")
	var lines: PackedStringArray = [UiText.t("final_top_header")]
	for m in top:
		var times := int(m.get("count", 1))
		lines.append("• %s%s" % [str(m.get("question", "")), " (×%d)" % times if times > 1 else ""])
		lines.append(UiText.t("final_correct", [str(m.get("correct_answer", ""))]))
	return "\n".join(lines)


## Закрыть фоном нельзя: с финала выходят кнопками.
func _on_back_button_pressed() -> void:
	pass
