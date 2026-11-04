extends RefCounted
class_name UiText

## Тексты и иконки интерфейса из game/data/ui_strings.json. Скрипты сцен не держат
## русских строк в коде: UiText.t("ключ", [подстановки]). Язык ставит Play (из сессии);
## до него (титул) действует язык по умолчанию. Нет перевода -> RU -> EN (Localizer).
##
## Иконки (таблица icons в JSON) вставляются в RichTextLabel через [img]. Сцену можно
## оставить обычным Label: put() и money_for() сами уберут иконки и вернут слова.

const PATH := "res://game/data/ui_strings.json"

static var lang: String = "ru"
static var _data: Dictionary = {}
static var _icons: Dictionary = {} # имя -> Texture2D


## Строка по ключу; args подставляются через %. Нет ключа - вернёт сам ключ и предупредит.
static func t(key: String, args: Array = []) -> String:
	_ensure_loaded()
	var entry: Variant = _data.get("strings", {}).get(key, null)
	var s := Localizer.text(entry, lang) if entry != null else ""
	if s == "":
		push_warning("UiText: нет строки '%s'" % key)
		return key
	return s % args if not args.is_empty() else s


## Подпись статичного узла (кнопка, надпись). Если автор сцены уже вписал текст в
## редакторе - не трогаем: текст сцены главнее, строка из таблицы нужна только
## как запасная. Для динамических надписей (меняются по ходу игры) зовите t() напрямую.
static func fill(node: Node, key: String, args: Array = []) -> void:
	if node != null and str(node.get("text")).strip_edges() == "":
		node.set("text", t(key, args))


## Статичные надписи сцен: узел с метаданными tr_key (в сцене: metadata/tr_key = "ключ")
## получает текст из таблицы на текущем языке, текст из редактора для него - лишь заглушка.
## Зовётся при старте сцены и при смене языка. Узлы без tr_key не трогает.
static func localize_tree(root: Node) -> void:
	if root.has_meta("tr_key") and root is Control:
		put(root as Control, t(str(root.get_meta("tr_key"))))
	for child in root.get_children():
		localize_tree(child)


## Ссылка из таблицы (links в ui_strings.json) или "".
static func link(key: String) -> String:
	_ensure_loaded()
	return str(_data.get("links", {}).get(key, ""))


# --- Иконки ---

## Текстура иконки по имени из таблицы icons (null, если нет).
static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		_ensure_loaded()
		var path := str(_data.get("icons", {}).get(name, ""))
		_icons[name] = load(path) as Texture2D if path != "" else null
		if _icons[name] == null:
			push_warning("UiText: нет иконки '%s'" % name)
	return _icons[name]


## BBCode вставки иконки: [img=размер]путь[/img]. size 0 - размер из icon_sizes (по группе).
static func img(name: String, size: int = 0) -> String:
	_ensure_loaded()
	var path := str(_data.get("icons", {}).get(name, ""))
	if path == "":
		return ""
	if size <= 0:
		var group := name
		if name.begins_with("star"):
			group = "star"
		elif name.begins_with("dot"):
			group = "dot"
		elif name in ["check", "cross", "bulb"]:
			group = "mark"
		elif name in ["gift", "piggy", "gauge", "gamepad", "quiz"]:
			group = "row"
		size = int(_data.get("icon_sizes", {}).get(group, 28))
	return "[img=%d]%s[/img]" % [size, path]


## Звёзды оценки: score заполненных из total. Только для RichTextLabel.
static func stars(score: int, total: int) -> String:
	var parts: PackedStringArray = []
	for i in total:
		parts.append(img("star_on" if i < score else "star_off"))
	return " ".join(parts)


## Ставит текст узлу. RichTextLabel: включает BBCode (align - center/right через тег).
## Label и прочие: убирает иконки и теги, остаётся голый текст.
static func put(node: Control, text: String, align: String = "") -> void:
	if node == null:
		return
	if node is RichTextLabel:
		node.bbcode_enabled = true
		node.text = "[%s]%s[/%s]" % [align, text, align] if align != "" else text
	else:
		node.set("text", strip_markup(text))


## Текст без [img]...[/img] и прочих BBCode-тегов.
static func strip_markup(text: String) -> String:
	var no_img := RegEx.create_from_string("\\[img[^\\]]*\\].*?\\[/img\\]").sub(text, "", true)
	return RegEx.create_from_string("\\[/?[a-z_]+[^\\]]*\\]").sub(no_img, "", true)


# --- Деньги ---

## Число с разделителем тысяч: 2400 -> "2 400".
static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = " " + s.substr(i - 3, 3) + out
		i -= 3
	return ("-" if n < 0 else "") + s.substr(0, i) + out


## Сумма с названием валюты и правильным склонением: 1 фет, 2 фета, 5 фетов.
static func money(n: int) -> String:
	_ensure_loaded()
	var all: Dictionary = _data.get("currency", {})
	var forms: Array = all.get(lang, all.get("ru", ["", "", ""]))
	var a := absi(n)
	var word: String
	if forms.size() == 2: # en и языки без трёх форм: единственное / остальное
		word = forms[0] if a == 1 else forms[1]
	elif forms.size() == 1:
		word = forms[0]
	else:
		var m10 := a % 10
		var m100 := a % 100
		if m10 == 1 and m100 != 11:
			word = forms[0]
		elif m10 >= 2 and m10 <= 4 and not (m100 >= 12 and m100 <= 14):
			word = forms[1]
		else:
			word = forms[2]
	return num(n) + " " + word


## Сумма с иконкой фета вместо слова (для RichTextLabel).
static func money_rich(n: int) -> String:
	return num(n) + " " + img("coin")


## Сумма в подходящем для узла виде: иконка для RichTextLabel, слово для остальных.
static func money_for(node: Control, n: int) -> String:
	return money_rich(n) if node is RichTextLabel else money(n)


static func _ensure_loaded() -> void:
	if not _data.is_empty():
		return
	var res: Resource = load(PATH)
	if res is JSON and res.data is Dictionary:
		_data = res.data
	else:
		push_error("UiText: не удалось прочитать %s" % PATH)
