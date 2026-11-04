extends Control
class_name HintView

## Подсказка (1 с) перед мини-игрой: название и что делать.

@onready var title_label: Label = %TitleLabel
@onready var text_label: Label = %TextLabel


func show_hint(title: String, text: String) -> void:
	title_label.text = title
	text_label.text = text
