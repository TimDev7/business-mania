extends RefCounted
class_name Haptics

## Thin wrapper over Input.vibrate_handheld() that respects the player's own
## vibration setting (Game.game_data.sounds.vibration_mute, toggled the same
## way as the music/sfx mutes). Call these instead of Input.vibrate_handheld()
## directly anywhere gameplay wants haptic feedback, so the one mute toggle
## actually covers every call site instead of each needing its own check.
## Harmlessly does nothing on a platform/device without vibration support -
## Godot's own vibrate_handheld() already no-ops there, nothing extra needed
## here for that part.

const LIGHT_MS := 15
const MEDIUM_MS := 35


## A small, frequent event - a quick tap, not meant to be felt as a big
## moment.
static func light() -> void:
	_vibrate(LIGHT_MS)


## A bigger moment - e.g. completing a level.
static func medium() -> void:
	_vibrate(MEDIUM_MS)


static func _vibrate(duration_ms: int) -> void:
	if Game.game_data.sounds.vibration_mute:
		return
	Input.vibrate_handheld(duration_ms)
