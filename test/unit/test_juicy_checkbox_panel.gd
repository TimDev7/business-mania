extends GutTest

# Covers template/ui/scenes/juicy_checkbox_panel.gd - two compounding bugs
# that together made a checkbox using this component look and act broken:
#   1. Nothing wired the real inner CheckBox's own "toggled" signal to
#      _on_button_toggled() - a real click never did anything at all.
#   2. Even with that connected, button_pressed's setter never pushed the
#      value down to the real CheckBox - so setting it from code (e.g. a
#      Settings window syncing the checkbox to a saved mute state on open)
#      never changed what the player actually saw.

const PANEL_SCENE := preload("res://template/ui/scenes/juicy_checkbox_panel.tscn")


func _make_panel() -> JuicyCheckboxPanel:
	var panel: JuicyCheckboxPanel = PANEL_SCENE.instantiate()
	add_child_autofree(panel)
	return panel


## button_pressed's setter pushes to the real CheckBox via
## call_deferred("_update_ui") (matches every other exported property on
## this class - text, font_size, etc.) - so these await a frame before
## checking the real button, same as a caller like a Settings window would
## effectively get in practice.

func test_setting_button_pressed_from_code_updates_the_real_checkbox() -> void:
	var panel := _make_panel()

	panel.button_pressed = true
	await get_tree().process_frame
	assert_true(panel.button.button_pressed)

	panel.button_pressed = false
	await get_tree().process_frame
	assert_false(panel.button.button_pressed)


func test_setting_button_pressed_from_code_does_not_re_emit_toggled() -> void:
	var panel := _make_panel()
	watch_signals(panel)

	panel.button_pressed = true
	await get_tree().process_frame

	assert_signal_not_emitted(panel, "toggled",
		"a programmatic sync (e.g. opening Settings) shouldn't look like the player clicked it")


func test_clicking_the_real_checkbox_emits_toggled_and_updates_button_pressed() -> void:
	var panel := _make_panel()
	watch_signals(panel)

	panel.button.button_pressed = true # what an actual click does under the hood

	assert_signal_emitted_with_parameters(panel, "toggled", [true])
	assert_true(panel.button_pressed)


func test_clicking_the_real_checkbox_off_again_emits_toggled_false() -> void:
	var panel := _make_panel()
	panel.button_pressed = true
	await get_tree().process_frame # let the deferred sync land before "clicking"
	watch_signals(panel)

	panel.button.button_pressed = false

	assert_signal_emitted_with_parameters(panel, "toggled", [false])
	assert_false(panel.button_pressed)
