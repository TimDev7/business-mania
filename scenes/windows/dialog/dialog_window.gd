extends GameWindow
class_name DialogWindow

## Диалог по страницам: легенда, вступление куратора, подсказки «как играть».
## Окно не знает, откуда страницы: Play передаёт готовый список
## [{speaker, text, portrait}] (см. Story). Наружу - сигнал finished
## (дошли до конца или нажали «Пропустить»).

signal finished

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var next_button: Button = %NextButton
@onready var skip_button: Button = %SkipButton
@onready var page_label: Control = %PageLabel # RichTextLabel покажет точки-страницы
# Портрет необязателен: сцену без него окно переживёт.
@onready var portrait_rect: TextureRect = get_node_or_null("%PortraitRect")

var _pages: Array = []
var _index := 0
var _last_button_text := ""


func _ready() -> void:
	super._ready()
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_finish)
	# «Пропустить» - компактная кнопка-иконка вместо вытянутой надписи.
	skip_button.text = ""
	skip_button.icon = UiText.icon("skip")
	skip_button.expand_icon = true
	skip_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	skip_button.tooltip_text = UiText.t("btn_skip")


## pages - Story.intro() / Story.tutorial(id); last_button - надпись кнопки на последней
## странице («Начать день», «Понятно»); can_skip - показывать ли «Пропустить».
func show_pages(pages: Array, last_button: String, can_skip: bool) -> void:
	if pages.is_empty():
		finished.emit()
		return
	_pages = pages
	_index = 0
	_last_button_text = last_button
	skip_button.visible = can_skip and pages.size() > 1
	_show_page()
	open_window()
	_fix_text_height()


## Высота текста = самая длинная страница диалога: окно не меняет размер при смене
## страниц, и кнопки «Далее» / «Пропустить» остаются на месте. Ширина берётся после
## раскладки (кадр спустя); без портрета (рассказчик) текст шире, поэтому считаем
## по узкому варианту - с запасом.
func _fix_text_height() -> void:
	text_label.custom_minimum_size.y = 0.0
	await get_tree().process_frame
	var width := text_label.size.x
	if portrait_rect != null and not portrait_rect.visible:
		width -= portrait_rect.custom_minimum_size.x + 8.0
	if width <= 0.0:
		return
	var font := text_label.get_theme_font("font")
	var font_size := text_label.get_theme_font_size("font_size")
	var line_gap := float(text_label.get_theme_constant("line_spacing"))
	var tallest := 0.0
	for page in _pages:
		var measured := font.get_multiline_string_size(
				str(page.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1,
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		var lines := maxi(1, roundi(measured.y / font.get_height(font_size)))
		tallest = maxf(tallest, measured.y + line_gap * lines)
	text_label.custom_minimum_size.y = ceilf(tallest)


func _show_page() -> void:
	var page: Dictionary = _pages[_index]
	speaker_label.text = str(page.get("speaker", ""))
	text_label.text = str(page.get("text", ""))
	if portrait_rect != null:
		portrait_rect.texture = page.get("portrait") as Texture2D
		portrait_rect.visible = portrait_rect.texture != null
	var is_last := _index >= _pages.size() - 1
	next_button.text = _last_button_text if is_last else UiText.t("btn_next")
	page_label.visible = _pages.size() > 1
	if page_label is RichTextLabel:
		# Точки-страницы: текущая яркая, остальные серые.
		var dots: PackedStringArray = []
		for i in _pages.size():
			dots.append(UiText.img("dot_on" if i == _index else "dot_off"))
		UiText.put(page_label, " ".join(dots), "center")
	else:
		UiText.put(page_label, "%d / %d" % [_index + 1, _pages.size()])


func _on_next_pressed() -> void:
	if _index >= _pages.size() - 1:
		_finish()
	else:
		_index += 1
		_show_page()


func _finish() -> void:
	close_window()
	finished.emit()


## Закрыть диалог тапом по фону нельзя: только «Далее» или «Пропустить».
func _on_back_button_pressed() -> void:
	pass
