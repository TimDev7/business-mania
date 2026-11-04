extends RefCounted
class_name UiStyle

## Размеры шрифтов по всему интерфейсу (game/data/ui_style.json). У проекта нет общей
## темы, поэтому подписи без своего размера получали 16 px движка. apply(root) обходит
## дерево и: ставит размер тексту без собственного (body / button), а у тех, где размер
## задан в сцене, только подтягивает слишком мелкий до пола (floor / button_floor).
## Размеры больше пола не трогаются. Зовётся из _ready() сцен и после создания
## мини-игры. Не заходит внутрь полосок (значения на них задаёт сцена) и в узлы с
## метаданными "ui_style_skip".

const PATH := "res://game/data/ui_style.json"
const RICH_TEXT_SIZES := ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]

static var _cfg: Dictionary = {}
static var _theme: Theme = null


static func apply(root: Node) -> void:
	_walk(root, _config())


## Общей темы проекта нет, а тема наследуется только по цепочке Control, поэтому
## main.tres вешается на каждый верхний Control (его родитель не Control): окна лежат
## в CanvasLayer и цепочку рвут. Свою тему узла (theme уже задана) не трогаем.
static func _apply_theme(node: Node, cfg: Dictionary) -> void:
	if not (node is Control) or node.theme != null or node.get_parent() is Control:
		return
	var theme := _main_theme(cfg)
	if theme != null:
		node.theme = theme


## Тема main.tres (одна на всех, грузится один раз).
static func _main_theme(cfg: Dictionary) -> Theme:
	if _theme == null:
		var path := str(cfg.get("theme", ""))
		_theme = load(path) as Theme if path != "" else null
	return _theme


## Шрифт под язык. Встроенный шрифт Godot не гарантирует казахские буквы (ә ғ қ ң ө ұ ү һ і),
## а в вебе системные шрифты не подставляются: вместо них были бы пустые квадраты. Для
## языков из font_languages (ui_style.json) в тему ставится шрифт font с полной кириллицей;
## для остальных остаётся встроенный. Тема общая, поэтому шрифт меняется у всех сразу.
static func apply_language_font(lang: String) -> void:
	var cfg := _config()
	var theme := _main_theme(cfg)
	if theme == null:
		return
	var font_path := str(cfg.get("font", ""))
	if font_path != "" and lang in cfg.get("font_languages", []):
		var font := load(font_path) as Font
		theme.default_font = font
		if font != null and not font.has_char(0x04D9): # ә
			push_warning("UiStyle: в шрифте %s нет казахских букв" % font_path)
	else:
		theme.default_font = null


static func _walk(node: Node, cfg: Dictionary, in_button: bool = false) -> void:
	_apply_theme(node, cfg)
	if node is TextureProgressBar or node.has_meta("ui_style_skip"):
		return
	var body := int(cfg.get("body", 24))
	var floor_size := int(cfg.get("floor", 22))
	if node is Button:
		_fit(node, "font_size", int(cfg.get("button", 28)), int(cfg.get("button_floor", 26)))
		_button_text_colors(node, cfg)
	elif node is RichTextLabel:
		for size_name in RICH_TEXT_SIZES:
			_fit(node, size_name, body, floor_size)
		if in_button:
			_darken_if_light(node, "default_color", cfg)
	elif node is Label or node is TextEdit or node is LineEdit:
		_fit(node, "font_size", body, floor_size)
		if in_button and node is Label:
			_darken_if_light(node, "font_color", cfg)
	for child in node.get_children():
		_walk(child, cfg, in_button or node is Button)


## Кнопки светлые (текстура темы), а в теме чёрный текст задан только для обычного и
## наведённого состояния: в нажатом, с фокусом и отключённом он оставался белым и
## пропадал. Ставим тёмный текст во всех состояниях, кроме тех, что заданы на самой кнопке.
static func _button_text_colors(button: Button, cfg: Dictionary) -> void:
	var dark := Color(str(cfg.get("button_text", "#1b1b1b")))
	var dim := Color(str(cfg.get("button_text_disabled", "#6a6a6a")))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		if not button.has_theme_color_override(color_name):
			button.add_theme_color_override(color_name, dark)
	if not button.has_theme_color_override("font_disabled_color"):
		button.add_theme_color_override("font_disabled_color", dim)


## Подпись внутри кнопки (строка магазина, чип топпинга) лежит на светлой текстуре:
## если её цвет светлый - делаем тёмным. Тёмные цвета, заданные в сцене, не трогаем.
static func _darken_if_light(control: Control, color_name: String, cfg: Dictionary) -> void:
	var threshold := float(cfg.get("light_threshold", 0.55))
	if control.get_theme_color(color_name).get_luminance() > threshold:
		control.add_theme_color_override(color_name, Color(str(cfg.get("button_text", "#1b1b1b"))))


## Нет своего размера - ставим основной; есть, но меньше пола - поднимаем до пола.
static func _fit(control: Control, size_name: String, default_size: int, floor_size: int) -> void:
	if control.has_theme_font_size_override(size_name):
		if control.get_theme_font_size(size_name) < floor_size:
			control.add_theme_font_size_override(size_name, floor_size)
	else:
		control.add_theme_font_size_override(size_name, default_size)


static func _config() -> Dictionary:
	if _cfg.is_empty():
		var res: Resource = load(PATH)
		if res is JSON and res.data is Dictionary:
			_cfg = res.data
		else:
			push_error("UiStyle: не удалось прочитать %s" % PATH)
	return _cfg
