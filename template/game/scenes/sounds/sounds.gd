extends Node
class_name Sounds

var music_mute: bool = false
var sfx_mute: bool = false
var vibration_mute: bool = false

## The player's explicitly chosen UI language - empty means "never
## explicitly chosen", so the game keeps using whatever locale it booted
## with instead of forcing a default. Lives here (not a dedicated node) for
## the same reason vibration_mute does - one more persisted field, not a
## whole new GameData child that would need a matching .tscn node.
var locale: String = ""


func serialize() -> Dictionary:
	var dict:Dictionary = {}

	dict["music_mute"] = music_mute
	dict["sfx_mute"] = sfx_mute
	dict["vibration_mute"] = vibration_mute
	dict["locale"] = locale

	return dict


func deserialize(dict:Dictionary) -> void:
	music_mute = dict.get("music_mute",false)
	sfx_mute = dict.get("sfx_mute",false)
	vibration_mute = dict.get("vibration_mute",false)
	locale = dict.get("locale","")


func load_default_data() -> void:
	music_mute = false
	sfx_mute = false
	vibration_mute = false
	locale = ""
