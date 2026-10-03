extends GutTest

# Covers template/core/core.gd's toggle_pause() - specifically that multiple
# independent callers (the player's own Pause menu, the portal's own
# pause_state_changed relayed via sdk.gd's connect_platform_signals()) can
# each want the tree paused without one unpausing the other's reason out
# from under it (e.g. the portal reporting "resumed" while the player still
# has the Pause menu open must not silently resume gameplay behind it).

func after_each() -> void:
	Core._pause_sources.clear()
	get_tree().paused = false


func test_toggle_pause_pauses_the_tree() -> void:
	Core.toggle_pause(true)

	assert_true(get_tree().paused)


func test_toggle_pause_unpauses_when_the_same_source_releases() -> void:
	Core.toggle_pause(true)
	Core.toggle_pause(false)

	assert_false(get_tree().paused)


func test_two_sources_both_wanting_pause_requires_both_to_release() -> void:
	Core.toggle_pause(true, "pause_window")
	Core.toggle_pause(true, "platform")

	Core.toggle_pause(false, "platform")
	assert_true(get_tree().paused, "pause_window still wants it paused")

	Core.toggle_pause(false, "pause_window")
	assert_false(get_tree().paused)


func test_default_source_does_not_conflict_with_a_named_one() -> void:
	Core.toggle_pause(true) # defaults to "manual"
	Core.toggle_pause(true, "platform")

	Core.toggle_pause(false, "platform")
	assert_true(get_tree().paused, "the default-source pause is still active")

	Core.toggle_pause(false)
	assert_false(get_tree().paused)


func test_releasing_a_source_that_was_never_set_is_a_safe_no_op() -> void:
	Core.toggle_pause(false, "never_paused_this")

	assert_false(get_tree().paused)


func test_core_wires_app_hidden_changed_to_the_save_manager() -> void:
	assert_true(Core.event_bus.app_hidden_changed.is_connected(Core.save_manager._on_app_hidden_changed))


func test_core_wires_app_hidden_changed_to_the_sound_manager() -> void:
	assert_true(Core.event_bus.app_hidden_changed.is_connected(Core.sound_manager._on_app_hidden_changed))
