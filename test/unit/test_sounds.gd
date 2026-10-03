extends GutTest

# Covers template/game/scenes/sounds/sounds.gd: the serialize/deserialize
# contract every save-data node in the template follows. A typo in one of
# the dict keys here silently loses the player's mute settings on load.


func test_defaults_are_unmuted() -> void:
	var sounds: Sounds = autofree(Sounds.new())
	assert_false(sounds.music_mute)
	assert_false(sounds.sfx_mute)
	assert_false(sounds.vibration_mute)
	assert_eq(sounds.locale, "")


func test_serialize_returns_current_state() -> void:
	var sounds: Sounds = autofree(Sounds.new())
	sounds.music_mute = true
	sounds.sfx_mute = false
	sounds.vibration_mute = true
	sounds.locale = "es"

	assert_eq(sounds.serialize(), {"music_mute": true, "sfx_mute": false, "vibration_mute": true, "locale": "es"})


func test_deserialize_restores_state_from_dict() -> void:
	var sounds: Sounds = autofree(Sounds.new())
	sounds.deserialize({"music_mute": true, "sfx_mute": true, "vibration_mute": true})

	assert_true(sounds.music_mute)
	assert_true(sounds.sfx_mute)
	assert_true(sounds.vibration_mute)


func test_deserialize_defaults_missing_keys_to_false() -> void:
	var sounds: Sounds = autofree(Sounds.new())
	sounds.music_mute = true
	sounds.sfx_mute = true
	sounds.vibration_mute = true

	sounds.deserialize({})

	assert_false(sounds.music_mute)
	assert_false(sounds.sfx_mute)
	assert_false(sounds.vibration_mute)


func test_load_default_data_resets_to_unmuted() -> void:
	var sounds: Sounds = autofree(Sounds.new())
	sounds.music_mute = true
	sounds.sfx_mute = true
	sounds.vibration_mute = true

	sounds.load_default_data()

	assert_false(sounds.music_mute)
	assert_false(sounds.sfx_mute)
	assert_false(sounds.vibration_mute)


func test_serialize_deserialize_round_trip() -> void:
	var original: Sounds = autofree(Sounds.new())
	original.music_mute = true
	original.sfx_mute = false
	original.vibration_mute = true
	original.locale = "es"

	var restored: Sounds = autofree(Sounds.new())
	restored.deserialize(original.serialize())

	assert_eq(restored.music_mute, original.music_mute)
	assert_eq(restored.sfx_mute, original.sfx_mute)
	assert_eq(restored.vibration_mute, original.vibration_mute)
	assert_eq(restored.locale, original.locale)


func test_deserialize_defaults_missing_locale_to_empty_string() -> void:
	var sounds: Sounds = autofree(Sounds.new())
	sounds.locale = "es"

	sounds.deserialize({})

	assert_eq(sounds.locale, "")


func test_load_default_data_resets_locale_too() -> void:
	var sounds: Sounds = autofree(Sounds.new())
	sounds.locale = "es"

	sounds.load_default_data()

	assert_eq(sounds.locale, "")
