extends RefCounted
class_name Localizer

## Тексты в JSON лежат как {"ru": ..., "kk": ..., "en": ...}. Исходный язык - RU,
## всё, чего ещё нет в переводе, откатывается на RU, потом на EN.

const SOURCE_LANG := "ru"
const FALLBACK_LANG := "en"


## Строка на нужном языке. Обычная String (не словарь) возвращается как есть.
static func text(value: Variant, lang: String) -> String:
	if value is String:
		return value
	if value is Dictionary:
		for l in [lang, SOURCE_LANG, FALLBACK_LANG]:
			if value.has(l) and value[l] is String and value[l] != "":
				return value[l]
	return ""


## Список строк на нужном языке (например, варианты ответа квиза).
static func list(value: Variant, lang: String) -> Array:
	if value is Array:
		return value
	if value is Dictionary:
		for l in [lang, SOURCE_LANG, FALLBACK_LANG]:
			if value.has(l) and value[l] is Array and not value[l].is_empty():
				return value[l]
	return []
