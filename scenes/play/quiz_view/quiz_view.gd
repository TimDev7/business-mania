extends Control
class_name QuizView

## Квиз: вопрос и до 4 вариантов. Нажатие -> answered(индекс кнопки как показано).

signal answered(shown_index: int)

@onready var question_label: Label = %QuestionLabel
@onready var option_buttons: Array[Button] = [%Option1, %Option2, %Option3, %Option4]


func _ready() -> void:
	for i in option_buttons.size():
		option_buttons[i].pressed.connect(answered.emit.bind(i))


## question - словарь из CycleRun (text, options уже перемешаны).
func show_question(question: Dictionary) -> void:
	question_label.text = str(question.get("text", ""))
	var options: Array = question.get("options", [])
	for i in option_buttons.size():
		var b := option_buttons[i]
		b.visible = i < options.size()
		if b.visible:
			b.text = str(options[i])
