@tool extends EditorPlugin

## Same pattern as addons/gpx-godot-plugin/plugin.gd (that plugin's own
## author, GamePix, wrote it this exact way): enabling this plugin in
## Project -> Project Settings -> Plugins is what's actually allowed to
## touch export_presets.cfg/the autoload list, via the editor's own
## EditorPlugin API - not this project's own rule of never hand-editing
## export_presets.cfg/.tscn as plain text while the editor has its own copy
## in memory. Re-enabling (or a fresh clone reopening the project) is safe -
## _enter_tree() only ever ADDS the "CrazyGames" preset if one doesn't
## already exist by name, never touches an existing one's settings.

func _enter_tree():
	var cfg = ConfigFile.new()
	cfg.load("res://export_presets.cfg")

	var preset_exists = false
	for key in cfg.get_sections():
		if cfg.has_section_key(key, "name") and cfg.get_value(key, "name") == "CrazyGames":
			preset_exists = true
			break

	if not preset_exists:
		# Each preset occupies two sections ("presetN" and "presetN.options"),
		# so the next free index is half the current section count - same
		# arithmetic gpx-godot-plugin's own plugin.gd uses for the same reason.
		var new_section = "preset" + "." + str(len(cfg.get_sections()) / 2)
		var options = new_section + ".options"

		cfg.set_value(new_section, "name", "CrazyGames")
		cfg.set_value(new_section, "platform", "Web")
		cfg.set_value(new_section, "runnable", false)
		cfg.set_value(new_section, "custom_features", "")
		cfg.set_value(new_section, "export_filter", "all_resources")
		cfg.set_value(new_section, "include_filter", "")
		cfg.set_value(new_section, "exclude_filter", "res://Export/*, *.aseprite, res://addons/gut/*, res://test/*, res://tools/*")
		cfg.set_value(options, "html/custom_html_shell", "res://addons/crazygames_sdk/index.html")
		cfg.save("res://export_presets.cfg")

	add_autoload_singleton("CG", "res://addons/crazygames_sdk/crazygames.gd")


func _exit_tree():
	remove_autoload_singleton("CG")
