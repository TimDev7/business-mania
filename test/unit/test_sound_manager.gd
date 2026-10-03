extends GutTest

# Covers template/core/scenes/sound_manager/global_sound.gd - specifically
# the shuffled music playlist (play_music_playlist(), _shuffled_indices()):
# a whole cycle must play every track exactly once before any repeats - not
# "pick one at random each time", which can by chance keep trading off
# between just two tracks while a third never comes up - and the seam
# between cycles must not repeat whichever track just finished. Also
# is_music_playing(), which a Title-style screen can use to avoid
# restarting an already-playing track every time the player revisits it.
# Not asserting that sound actually plays/sounds right - that's audio
# "juice", out of scope for a unit test.


func after_each() -> void:
	# Leave the shared singleton in a harmless, silent state for whatever
	# test runs next - clearing .stream too (not just stopping playback)
	# so the dummy AudioStreamWAV instances these tests hand it don't stay
	# referenced by this persistent singleton for the rest of the suite.
	Core.sound_manager._music_playlist = []
	Core.sound_manager._music_shuffle_order = []
	Core.sound_manager._music_shuffle_position = 0
	Core.sound_manager._music_player.stop()
	Core.sound_manager._music_player.stream = null


func _dummy_tracks(count: int) -> Array[AudioStream]:
	var tracks: Array[AudioStream] = []
	for i in count:
		tracks.append(AudioStreamWAV.new())
	return tracks


func test_music_player_is_wired_to_advance_the_playlist_when_it_finishes() -> void:
	assert_true(Core.sound_manager._music_player.finished.is_connected(Core.sound_manager._play_next_in_playlist),
		"without this, a track would just play once and go silent instead of advancing")


func test_is_music_playing_reports_the_real_players_state() -> void:
	assert_eq(Core.sound_manager.is_music_playing(), Core.sound_manager._music_player.playing)


func test_shuffled_indices_contains_every_index_exactly_once() -> void:
	var order := Core.sound_manager._shuffled_indices(5)
	order.sort()
	assert_eq(order, [0, 1, 2, 3, 4])


func test_shuffled_indices_avoids_repeating_the_given_first_pick() -> void:
	for i in 30: # a real shuffle, so run it enough times to catch a flaky implementation
		var order: Array[int] = Core.sound_manager._shuffled_indices(3, 1)
		assert_ne(order[0], 1)


func test_shuffled_indices_with_only_one_track_does_not_hang_even_avoiding_itself() -> void:
	var order := Core.sound_manager._shuffled_indices(1, 0)
	assert_eq(order, [0])


func test_play_music_playlist_starts_on_one_of_the_given_tracks() -> void:
	var tracks := _dummy_tracks(3)

	Core.sound_manager.play_music_playlist(tracks)

	assert_true(tracks.has(Core.sound_manager._music_player.stream))


func test_a_full_cycle_plays_every_track_exactly_once() -> void:
	var tracks := _dummy_tracks(3)
	Core.sound_manager.play_music_playlist(tracks)

	var seen: Dictionary = {Core.sound_manager._music_player.stream: true}
	for i in tracks.size() - 1: # one more track to reach after the first
		Core.sound_manager._play_next_in_playlist()
		seen[Core.sound_manager._music_player.stream] = true

	assert_eq(seen.size(), tracks.size(), "every track should have come up exactly once in one full cycle")


func test_play_music_still_loops_a_single_track_forever() -> void:
	var track: AudioStream = _dummy_tracks(1)[0]
	Core.sound_manager.play_music(track)

	Core.sound_manager._play_next_in_playlist()
	Core.sound_manager._play_next_in_playlist()

	assert_eq(Core.sound_manager._music_player.stream, track)


## Bug report: mute checkboxes could do nothing even though set_bus_mute()
## itself is correct, if the "Music"/"SFX" buses it looks up by name don't
## actually exist at runtime. Godot only auto-loads an AudioBusLayout
## resource's buses into the live AudioServer when project.godot's
## audio/buses/default_bus_layout setting names one - if left as "",
## AudioServer only ever has the built-in "Master" bus, and
## set_bus_mute()'s own get_bus_index() guard silently no-ops on every
## call. These assert against the real AudioServer (not a mock)
## specifically so a regression in the project setting itself - not just in
## this script - would fail the suite.
func test_set_bus_mute_actually_mutes_the_real_music_bus() -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	assert_ne(bus_idx, -1, "the Music bus must exist in the live AudioServer - see project.godot's audio/buses/default_bus_layout")
	var original_state := AudioServer.is_bus_mute(bus_idx)

	Core.sound_manager.set_bus_mute("Music", true)
	assert_true(AudioServer.is_bus_mute(bus_idx))
	Core.sound_manager.set_bus_mute("Music", false)
	assert_false(AudioServer.is_bus_mute(bus_idx))

	AudioServer.set_bus_mute(bus_idx, original_state)


## Bug report: switching browser tabs can leave a web game's audio playing
## in the background. See _on_app_hidden_changed()'s own doc comment in
## global_sound.gd for why Master (not Music/SFX) is what gets muted here.
## Godot's own NOTIFICATION_APPLICATION_FOCUS_OUT/_IN is a confirmed no-op
## on Web exports specifically for a browser tab losing focus (see
## core.gd's _connect_web_visibility_listener() for the engine issue link),
## so this template listens to the browser's own document.visibilitychange
## event via JavaScriptBridge instead, from Core (shared with
## SaveManager's own save-on-blur - see test_save_manager.gd), and
## broadcasts it as event_bus.app_hidden_changed. That JS wiring itself is
## only set up under OS.has_feature("web") (untestable headless), but
## _on_app_hidden_changed() - the actual mute logic Core connects to that
## signal - is plain GDScript and exercised directly here.
func test_losing_focus_mutes_everything_and_regaining_it_restores() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	var original_state := AudioServer.is_bus_mute(master_idx)

	Core.sound_manager._on_app_hidden_changed(true)
	assert_true(AudioServer.is_bus_mute(master_idx), "audio must go silent the instant a web build's tab is hidden")

	Core.sound_manager._on_app_hidden_changed(false)
	assert_false(AudioServer.is_bus_mute(master_idx), "audio must come back once the tab is visible again")

	AudioServer.set_bus_mute(master_idx, original_state)


func test_set_bus_mute_actually_mutes_the_real_sfx_bus() -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	assert_ne(bus_idx, -1, "the SFX bus must exist in the live AudioServer - see project.godot's audio/buses/default_bus_layout")
	var original_state := AudioServer.is_bus_mute(bus_idx)

	Core.sound_manager.set_bus_mute("SFX", true)
	assert_true(AudioServer.is_bus_mute(bus_idx))
	Core.sound_manager.set_bus_mute("SFX", false)
	assert_false(AudioServer.is_bus_mute(bus_idx))

	AudioServer.set_bus_mute(bus_idx, original_state)
