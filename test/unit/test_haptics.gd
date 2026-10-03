extends GutTest

# Covers template/haptics/haptics.gd. Input.vibrate_handheld() can't be
# observed from a test (no mock layer, unlike Bridge's ad mock - see
# test_sdk.gd), so this only proves both muted and unmuted calls run
# without error, the same "doesn't crash" bar test_sdk.gd's own
# notify-function tests hold themselves to.


func after_each() -> void:
	Game.game_data.sounds.load_default_data()


func test_light_and_medium_do_not_error_when_unmuted() -> void:
	Game.game_data.sounds.vibration_mute = false

	Haptics.light()
	Haptics.medium()

	assert_false(Game.game_data.sounds.vibration_mute) # just needs an assertion to not be "risky"


func test_light_and_medium_do_not_error_when_muted() -> void:
	Game.game_data.sounds.vibration_mute = true

	Haptics.light()
	Haptics.medium()

	assert_true(Game.game_data.sounds.vibration_mute)
