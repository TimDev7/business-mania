extends RefCounted
class_name GameMusic

## Фоновая музыка по настроению (game/data/audio.json): calm - титул, диалоги, куратор,
## магазин; vigorous - игровой день. Сам плеер живёт в Core.sound_manager и переживает
## смену сцен. Браузер не включает звук без нажатия игрока, поэтому первый set_mood()
## должен прийти из обработчика нажатия (кнопка «Начать стажировку»).

const PATH := "res://game/data/audio.json"

static var muted: bool = false

static var _current: String = ""
static var _data: Dictionary = {}
static var _streams: Dictionary = {}


## Включает музыку настроения (ничего не делает, если оно уже играет).
static func set_mood(mood: String) -> void:
	if mood == _current:
		return
	var stream := _stream_for(mood)
	if stream == null:
		return
	_current = mood
	var tracks: Array[AudioStream] = [stream]
	Core.sound_manager.play_music_playlist(tracks, float(_load().get("volume", 0.5)))
	Core.sound_manager.set_bus_mute("Music", muted)


## Переключает звук музыки, возвращает новое состояние (true - выключена).
static func toggle_mute() -> bool:
	muted = not muted
	Core.sound_manager.set_bus_mute("Music", muted)
	return muted


static func _stream_for(mood: String) -> AudioStream:
	if not _streams.has(mood):
		var path := str(_load().get("moods", {}).get(mood, ""))
		_streams[mood] = load(path) as AudioStream if path != "" else null
		if _streams[mood] == null:
			push_warning("GameMusic: нет музыки для настроения '%s'" % mood)
	return _streams[mood]


static func _load() -> Dictionary:
	if _data.is_empty():
		var res: Resource = load(PATH)
		if res is JSON and res.data is Dictionary:
			_data = res.data
		else:
			push_error("GameMusic: не удалось прочитать %s" % PATH)
	return _data
