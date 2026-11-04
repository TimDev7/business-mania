extends Button
class_name LanguageToggle

## Кнопка языка с иконкой (RU / KZ / EN) по образцу SoundToggle. Каждое нажатие -
## следующий язык по кругу (ru -> kk -> en). Выбор запоминается (GameLanguage).
## Сама тексты сцены не обновляет: об этом говорит сигнал language_changed, на него
## подписывается сцена (титул пересчитывает свои надписи).

signal language_changed(lang: String)

const MIN_SIDE := 72.0
const NAMES := {"ru": "Русский", "kk": "Қазақша", "en": "English"}


func _ready() -> void:
	text = ""
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(MIN_SIDE, MIN_SIDE)
	GameLanguage.ensure_loaded()
	pressed.connect(_on_pressed)
	_refresh()


func _on_pressed() -> void:
	GameLanguage.apply(GameLanguage.next())
	_refresh()
	language_changed.emit(UiText.lang)


func _refresh() -> void:
	icon = UiText.icon("lang_" + UiText.lang)
	tooltip_text = str(NAMES.get(UiText.lang, UiText.lang))
