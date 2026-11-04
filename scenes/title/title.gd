extends Node

## Титул: «Начать стажировку» -> сцена Play (там вступление и первый день).
## Музыка стартует по нажатию кнопки: браузер не включает звук без жеста игрока.
## Надписи с метаданными tr_key берутся из таблицы на выбранном языке (UiText.localize_tree);
## остальные тексты сцены - как написано в редакторе. Кнопка языка (%LanguageButton)
## при смене языка просит титул пересчитать надписи.

@onready var new_player_button: Button = %NewPlayerButton
@onready var brand_label: Control = get_node_or_null("%BrandLabel")
@onready var language_button: LanguageToggle = get_node_or_null("%LanguageButton")


func _ready() -> void:
	GameLanguage.ensure_loaded()
	if language_button != null:
		language_button.language_changed.connect(func(_lang: String) -> void: _refresh_texts())
	_refresh_texts()
	new_player_button.pressed.connect(_on_new_player_pressed)


## Надписи титула на текущем языке; шрифт и размеры подтягивает UiStyle.
func _refresh_texts() -> void:
	UiText.localize_tree(self)
	UiText.fill(new_player_button, "title_start")
	UiText.fill(brand_label, "title_brand")
	var tagline := get_node_or_null("%TaglineLabel") as Label
	if tagline != null:
		# Казахская подпись длиннее экрана: переносим на вторую строку (растёт вверх, якорь снизу).
		tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tagline.custom_minimum_size.x = 1.0
	UiStyle.apply(self)


func _on_new_player_pressed() -> void:
	GameMusic.set_mood("calm")
	Game.game_data.transition_manager.change_scene_to(TransitionManager.Scenes.Play)


## Кнопка сайта AlmaU (сигнал подключён в сцене). В вебе откроет новую вкладку.
func _on_alma_u_button_pressed() -> void:
	var url := UiText.link("almau")
	if url != "":
		OS.shell_open(url)
