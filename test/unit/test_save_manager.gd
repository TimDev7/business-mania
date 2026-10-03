extends GutTest

# Covers template/core/scenes/save_manager/save_manager.gd: the actual
# save/load round trip and its corrupted-file fallback. This is the
# single highest-blast-radius piece of the template - a bug here means
# every future game can lose the player's progress.
#
# DATA_SAVEPATH is redirected to a dedicated test file (it's a var, not a
# const, specifically so this suite never reads, writes, or deletes the
# developer's real user://game_data.json).

const CoreSaveManagerScript := preload("res://template/core/scenes/save_manager/save_manager.gd")
const TEST_SAVE_PATH := "user://test_game_data.json"


class DummyDataHandler:
	extends Node
	var load_default_data_calls := 0
	var deserialized_from := {}
	var data_to_save := {"sounds": {"music_mute": true, "sfx_mute": false}}

	func load_default_data() -> void:
		load_default_data_calls += 1

	func dict_to_game_data(dict: Dictionary) -> void:
		deserialized_from = dict

	func game_data_to_dict() -> Dictionary:
		return data_to_save


func _make_save_manager() -> Node:
	var save_manager: Node = CoreSaveManagerScript.new()
	save_manager.DATA_SAVEPATH = TEST_SAVE_PATH
	autofree(save_manager)
	return save_manager


func _remove_test_save_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	# save_data() also mirrors to Bridge.storage (see save_manager.gd) -
	# outside a real web export that's storage_editor_mock.gd's own
	# user://<key>.save file, which needs its own cleanup here too.
	var mock_storage_path := "user://" + TEST_SAVE_PATH.trim_prefix("user://") + ".save"
	if FileAccess.file_exists(mock_storage_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(mock_storage_path))


func before_each() -> void:
	_remove_test_save_file()


func after_each() -> void:
	_remove_test_save_file()
	# In case a test left these tweaked (see the corrupted-file test below),
	# make sure the next test in the suite starts with GUT's normal behavior.
	gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.FAILURE
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.FAILURE


func test_save_data_writes_handler_dict_plus_timestamp() -> void:
	var save_manager := _make_save_manager()
	var handler: DummyDataHandler = autofree(DummyDataHandler.new())
	save_manager.initialize(handler)

	save_manager.save_data()

	assert_true(FileAccess.file_exists(TEST_SAVE_PATH))
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var saved = JSON.parse_string(file.get_as_text())
	file.close()

	assert_eq(saved.get("sounds"), {"music_mute": true, "sfx_mute": false})
	assert_true(saved.has("save_time"))


## Bug report (observed on a real portal): a game's own "has this player
## saved progress" indicator showed nothing even though the game genuinely
## does save locally - the portal's own indicator checks ITS OWN storage
## (Bridge.storage, which routes to the portal's own Data API), not
## user:///localStorage, and save_data() never wrote anything there.
func test_save_data_also_mirrors_to_the_portals_own_storage() -> void:
	var save_manager := _make_save_manager()
	var handler: DummyDataHandler = autofree(DummyDataHandler.new())
	save_manager.initialize(handler)

	save_manager.save_data()

	var mock_storage_path := "user://" + TEST_SAVE_PATH.trim_prefix("user://") + ".save"
	assert_true(FileAccess.file_exists(mock_storage_path), "save_data() must also mirror to Bridge.storage")


func test_load_data_feeds_saved_dict_into_a_fresh_handler() -> void:
	var writer := _make_save_manager()
	var writer_handler: DummyDataHandler = autofree(DummyDataHandler.new())
	writer.initialize(writer_handler)
	writer.save_data()

	var reader := _make_save_manager()
	var reader_handler: DummyDataHandler = autofree(DummyDataHandler.new())
	reader.initialize(reader_handler)
	reader.load_data()

	assert_eq(reader_handler.load_default_data_calls, 1)
	assert_eq(reader_handler.deserialized_from.get("sounds"), {"music_mute": true, "sfx_mute": false})


func test_load_data_with_no_existing_file_falls_back_to_defaults_and_creates_one() -> void:
	var save_manager := _make_save_manager()
	var handler: DummyDataHandler = autofree(DummyDataHandler.new())
	save_manager.initialize(handler)

	save_manager.load_data()

	assert_eq(handler.load_default_data_calls, 1)
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH))


## Bug report: autosave-on-tab-blur can never actually fire on a real web
## build if it's wired to NOTIFICATION_APPLICATION_FOCUS_OUT, which is a
## confirmed no-op for a browser tab losing focus specifically (see
## core.gd's own comment on the engine issue). Fixed by having Core forward
## the browser's real document.visibilitychange event as
## event_bus.app_hidden_changed instead - this covers the actual save logic
## that connects to.
func test_on_app_hidden_changed_saves_immediately_when_the_tab_is_hidden() -> void:
	var save_manager := _make_save_manager()
	var handler: DummyDataHandler = autofree(DummyDataHandler.new())
	save_manager.initialize(handler)

	save_manager._on_app_hidden_changed(true)

	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "the tab being hidden must trigger an immediate save")


func test_on_app_hidden_changed_does_not_save_when_the_tab_becomes_visible_again() -> void:
	var save_manager := _make_save_manager()
	var handler: DummyDataHandler = autofree(DummyDataHandler.new())
	save_manager.initialize(handler)

	save_manager._on_app_hidden_changed(false)

	assert_false(FileAccess.file_exists(TEST_SAVE_PATH), "becoming visible again is not itself a save trigger")


func test_load_data_falls_back_to_defaults_on_corrupted_save_file() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{this is not valid json")
	file.close()

	var save_manager := _make_save_manager()
	var handler: DummyDataHandler = autofree(DummyDataHandler.new())
	save_manager.initialize(handler)

	# Parsing invalid JSON intentionally logs an engine error and save_manager.gd
	# intentionally push_errors on top of that; that's the behavior under test,
	# not a bug, so don't let either auto-fail the test. GUT only checks these
	# flags after this function returns, so they're restored in after_each()
	# instead of here.
	gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.NOTHING
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING
	save_manager.load_data()

	assert_eq(handler.load_default_data_calls, 1, "should still reset to defaults before attempting to read")
	assert_eq(handler.deserialized_from, {}, "corrupted data must never reach the handler")
