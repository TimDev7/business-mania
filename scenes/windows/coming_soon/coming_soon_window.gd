extends GameWindow
class_name ComingSoonWindow

## «Контент в разработке» (кнопка «Углубиться», позже карта закрытых бизнесов).
## Закрывается тапом по фону или кнопкой назад - поведение GameWindow по умолчанию.

@onready var text_label: Label = %TextLabel


func show_message(text: String) -> void:
	text_label.text = text
	open_window()
