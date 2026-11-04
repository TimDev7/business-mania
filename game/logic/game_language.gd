extends RefCounted
class_name GameLanguage

## Язык интерфейса: русский, казахский, английский. Выбор запоминается (в вебе -
## localStorage, иначе user://settings.cfg); при первом запуске берётся язык браузера,
## если он поддерживается, иначе русский. Тексты всей игры читают UiText.lang, сессия
## получает язык от Play. Менять язык можно только на титуле (кнопка LanguageToggle).

const SUPPORTED := ["ru", "kk", "en"]
const STORAGE_KEY := "internity_lang"
const SETTINGS_PATH := "user://settings.cfg"

static var _loaded := false


## Один раз за запуск: сохранённый язык -> язык браузера/системы -> русский.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var lang := _read_saved()
	if lang == "":
		lang = _system_language()
	apply(lang if lang in SUPPORTED else "ru", false)


## Ставит язык интерфейса и подбирает шрифт под него; save - запомнить выбор.
static func apply(lang: String, save: bool = true) -> void:
	UiText.lang = lang
	UiStyle.apply_language_font(lang)
	if save:
		_write_saved(lang)


## Следующий язык по кругу (ru -> kk -> en -> ru).
static func next() -> String:
	var i := SUPPORTED.find(UiText.lang)
	return SUPPORTED[(i + 1) % SUPPORTED.size()]


static func _system_language() -> String:
	if OS.has_feature("web"):
		var browser: Variant = JavaScriptBridge.eval("(navigator.language || '').slice(0, 2).toLowerCase()")
		return str(browser) if browser != null else ""
	return OS.get_locale_language()


static func _read_saved() -> String:
	if OS.has_feature("web"):
		var saved: Variant = JavaScriptBridge.eval(
				"(function(){try{return window.localStorage.getItem('%s')}catch(e){return null}})()" % STORAGE_KEY)
		return str(saved) if saved != null else ""
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return str(cfg.get_value("ui", "lang", ""))
	return ""


static func _write_saved(lang: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
				"(function(){try{window.localStorage.setItem('%s','%s')}catch(e){}})()" % [STORAGE_KEY, lang])
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "lang", lang)
	cfg.save(SETTINGS_PATH)
