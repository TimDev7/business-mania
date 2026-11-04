extends RefCounted
class_name Story

## Сюжет и обучалка из game/data/story.json: вступление (легенда + куратор)
## и подсказки «как играть». Возвращает страницы для DialogWindow:
## [{speaker: имя, text: текст, portrait: Texture2D или null}]. Язык - UiText.lang.

const PATH := "res://game/data/story.json"

static var _data: Dictionary = {}
static var _portraits: Dictionary = {} # путь -> Texture2D


static func intro() -> Array:
	return _pages(_load().get("intro", []))


## id: toppings / purchase / courier / quiz / case.
static func tutorial(id: String) -> Array:
	return _pages(_load().get("tutorial", {}).get(id, []))


static func mentor_portrait() -> Texture2D:
	return _portrait(str(_load().get("speakers", {}).get("mentor", {}).get("portrait", "")))


static func _pages(raw: Array) -> Array:
	var speakers: Dictionary = _load().get("speakers", {})
	var out: Array = []
	for page in raw:
		var sp: Dictionary = speakers.get(page.get("speaker", ""), {})
		out.append({
			"speaker": Localizer.text(sp.get("name", ""), UiText.lang),
			"text": Localizer.text(page.get("text", ""), UiText.lang),
			"portrait": _portrait(str(sp.get("portrait", ""))),
		})
	return out


static func _portrait(path: String) -> Texture2D:
	if path == "":
		return null
	if not _portraits.has(path):
		_portraits[path] = load(path) as Texture2D
	return _portraits[path]


static func _load() -> Dictionary:
	if _data.is_empty():
		var res: Resource = load(PATH)
		if res is JSON and res.data is Dictionary:
			_data = res.data
		else:
			push_error("Story: не удалось прочитать %s" % PATH)
	return _data
