@icon("res://template/Core/CoreNodeIcon.svg")
extends Node

@onready var event_bus:CoreEventBus = $EventBus
@onready var save_manager:CoreSaveManager = $SaveManager
@onready var sound_manager:CoreSoundManager = $SoundManager

## Godot's own JavaScriptBridge docs warn that a callback object from
## create_callback() must be kept referenced somewhere in GDScript for as
## long as JS might call it, or it can be garbage-collected and silently
## stop firing - this member is that reference (a local var inside
## _connect_web_visibility_listener() would have gone out of scope the
## instant that function returned).
var _visibility_callback_ref: JavaScriptObject


func _ready():
	randomize()
	# Wired here (the parent), not in each child's own _ready(), because
	# Godot readies children before parents - event_bus/save_manager/
	# sound_manager are only guaranteed non-null once THIS _ready() runs,
	# not during any of theirs.
	event_bus.app_hidden_changed.connect(sound_manager._on_app_hidden_changed)
	event_bus.app_hidden_changed.connect(save_manager._on_app_hidden_changed)
	_connect_web_visibility_listener()


## Godot's own NOTIFICATION_APPLICATION_FOCUS_OUT/_IN - what a save-on-blur
## or mute-on-blur would naturally reach for - is a confirmed no-op on Web
## exports specifically for a browser tab losing focus
## (https://github.com/godotengine/godot/issues/87014), only firing for a
## real OS-level window/app switch (desktop, mobile). Since this template
## targets Web-portal games first, relying on it would silently never fire
## on a real build. Goes straight to the browser's own
## document.visibilitychange event instead, and broadcasts it as
## app_hidden_changed so every interested system reacts to the one real
## signal instead of each wiring up its own JS listener.
func _connect_web_visibility_listener() -> void:
	if not OS.has_feature("web"):
		return
	var window := JavaScriptBridge.get_interface("window")
	_visibility_callback_ref = JavaScriptBridge.create_callback(_on_js_visibility_changed)
	window.__coreVisibilityCallback = _visibility_callback_ref
	JavaScriptBridge.eval("""
		document.addEventListener('visibilitychange', function () {
			window.__coreVisibilityCallback(document.hidden);
		});
	""", true)


func _on_js_visibility_changed(args: Array) -> void:
	event_bus.app_hidden_changed.emit(args[0])


func register_game(data_handler:Node) -> void:
	save_manager.initialize(data_handler)
	# Must happen here: this is what actually reads the save file and emits
	# "game_data_loaded" - without it BaseGame never gets that signal, so
	# game_data.initialize()/sound_manager.initialize() never run and
	# nothing ever gets restored from a previous session (it still *saves*
	# fine, which is why this is easy to miss).
	save_manager.load_data()


## Which independent callers currently want the tree paused (source name ->
## true) - e.g. the player's own Pause menu and an ad flow (see
## template/sdk/sdk.gd's _begin_ad_pause()/_end_ad_pause()) can both want it
## at once. A plain last-write-wins boolean would let one unpause the
## other's reason out from under it (e.g. an ad closing while the player
## still has the Pause menu open would have silently resumed gameplay
## behind that still-open overlay) - the tree stays paused as long as ANY
## source still wants it.
var _pause_sources: Dictionary = {}


## source defaults to "manual" so existing callers don't need to change -
## only a caller sharing the tree with another pause source (see
## _pause_sources above) needs to pass its own distinct one.
func toggle_pause(turn_on: bool, source: String = "manual") -> void:
	if turn_on:
		_pause_sources[source] = true
	else:
		_pause_sources.erase(source)
	get_tree().paused = not _pause_sources.is_empty()

