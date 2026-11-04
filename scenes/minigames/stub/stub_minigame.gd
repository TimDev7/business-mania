extends Minigame

## Заглушка мини-игры (Этап 1): две кнопки вместо механики.

@onready var title_label: Label = %TitleLabel
@onready var success_button: Button = %SuccessButton
@onready var fail_button: Button = %FailButton


func _ready() -> void:
	success_button.pressed.connect(finish.bind(true))
	fail_button.pressed.connect(finish.bind(false))


func start(_logic: RefCounted, step: Dictionary) -> void:
	title_label.text = "%s (заглушка, +%d)" % [str(step.get("title", step.get("game", ""))), int(step.get("reward", 0))]
