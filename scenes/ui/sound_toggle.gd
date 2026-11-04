extends Button
class_name SoundToggle

## Кнопка звука с иконкой (динамик / динамик перечёркнутый) вместо текста. Кладётся в
## титул и в игру инстансом одной сцены; состояние общее и хранится в GameMusic.
## Иконки - из таблицы icons (sound_on / sound_off в ui_strings.json). Размер и фон
## кнопки задаёт сцена, скрипт лишь ставит иконку и убирает текст.

const MIN_SIDE := 72.0


func _ready() -> void:
	text = ""
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(MIN_SIDE, MIN_SIDE)
	pressed.connect(_on_pressed)
	_refresh()


func _on_pressed() -> void:
	GameMusic.toggle_mute()
	_refresh()


func _refresh() -> void:
	icon = UiText.icon("sound_off" if GameMusic.muted else "sound_on")
	tooltip_text = UiText.t("music_off" if GameMusic.muted else "music_on")
