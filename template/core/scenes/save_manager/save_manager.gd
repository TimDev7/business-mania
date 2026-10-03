extends Node
class_name CoreSaveManager

## user:// on a Web export is backed by the browser's IndexedDB, but Godot
## doesn't reliably flush a write to it before the page actually closes -
## a long-documented Emscripten/IDBFS timing issue (the sync is async and
## debounced; see godotengine/godot#39643 and godotengine/godot#56640). A
## save can fully succeed from GDScript's point of view (FileAccess.close()
## returns normally) and still never reach real persistent storage if the
## tab closes shortly after - exactly the moment this template's own
## save-on-hidden (see _on_app_hidden_changed()) is trying hardest to
## protect. window.localStorage, in contrast, is synchronous - every
## setItem() call is guaranteed durable the instant it returns - so Web
## builds use it directly instead of user:// for the actual save blob.
## Desktop/editor (including every GUT test - OS.has_feature("web") is
## always false there) keep using FileAccess/user://, unchanged.
var DATA_SAVEPATH:String = "user://game_data.json"

var data_handler:Node
@onready var auto_save_timer = $AutoSaveTimer

func initialize(_data_handler:Node) -> void:
	data_handler = _data_handler

func load_data() -> void:
	data_handler.load_default_data()

	if not _save_exists():
		save_data()
		Core.event_bus.emit_signal("game_data_loaded", int(Time.get_unix_time_from_system()))
		return

	var content := _read_raw()
	var loaded_data = JSON.parse_string(content)

	if typeof(loaded_data) != TYPE_DICTIONARY:
		push_error("Save file is corrupted! Starting with default data.")
		Core.event_bus.emit_signal("game_data_loaded", int(Time.get_unix_time_from_system()))
		return

	data_handler.dict_to_game_data(loaded_data)
	Core.event_bus.emit_signal("game_data_loaded", loaded_data.get("save_time", int(Time.get_unix_time_from_system())))


func save_data() -> void:
	if auto_save_timer:
		auto_save_timer.start()

	var data:Dictionary = data_handler.game_data_to_dict()
	data["save_time"] = int(Time.get_unix_time_from_system())

	_write_raw(JSON.stringify(data, "\t"))
	# Best-effort mirror to the portal's own cloud storage (Bridge.storage -
	# CrazyGames'/Y8's own Data API, see addons/playgama_bridge/modules/
	# storage/storage.gd). Without this, the game genuinely saves fine
	# (above), but the PORTAL's own "has this game saved anything" check
	# sees nothing, since it's checking its own storage, not user://
	# /localStorage - a real, observed cause of a portal's "no saved
	# progress yet" notice even though the game does save locally.
	# Fire-and-forget - _write_raw() above is this game's own real,
	# authoritative save; a slow/failed portal-side write must never block
	# or fail it. Couples this otherwise-generic template file to
	# addons/playgama_bridge specifically - a game reusing template/
	# without Playgama Bridge installed would need to remove this line,
	# since unlike everything else in this file, Bridge isn't part of
	# template/ itself.
	Bridge.storage.set(_web_storage_key(), data)


## DATA_SAVEPATH's own filename, minus the user:// prefix, doubles as the
## localStorage key - a game that changes DATA_SAVEPATH still gets its own
## distinct key, same as it'd get its own distinct user:// file.
func _web_storage_key() -> String:
	return DATA_SAVEPATH.trim_prefix("user://")


func _save_exists() -> bool:
	if OS.has_feature("web"):
		return JavaScriptBridge.get_interface("window").localStorage.getItem(_web_storage_key()) != null
	return FileAccess.file_exists(DATA_SAVEPATH)


func _read_raw() -> String:
	if OS.has_feature("web"):
		return JavaScriptBridge.get_interface("window").localStorage.getItem(_web_storage_key())
	var file = FileAccess.open(DATA_SAVEPATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	return content


func _write_raw(json_data: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").localStorage.setItem(_web_storage_key(), json_data)
		return
	var file = FileAccess.open(DATA_SAVEPATH, FileAccess.WRITE)
	file.store_string(json_data)
	file.close()


func _on_AutoSaveTimer_timeout() -> void:
	save_data()


## Connected by Core to event_bus.app_hidden_changed (see core.gd) - a web
## build's browser tab getting hidden is the actual "player might be about
## to leave for good" moment for a Web-portal game, not something
## NOTIFICATION_APPLICATION_FOCUS_OUT (below) can catch there - see
## core.gd's own comment on why.
func _on_app_hidden_changed(hidden: bool) -> void:
	if hidden:
		save_data()


func _notification(what: int) -> void:
	# Real for a desktop/mobile export (kept for template reuse beyond
	# Web), but a Web-portal game never reaches this via a tab losing
	# focus - see _on_app_hidden_changed() above, which is what actually
	# covers that case there.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_data()

	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()
