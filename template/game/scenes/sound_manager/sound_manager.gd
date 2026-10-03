extends Node
class_name GameSoundManager


func initialize() -> void:
	Core.sound_manager.set_bus_mute("SFX",Game.game_data.sounds.sfx_mute)
	Core.sound_manager.set_bus_mute("Music",Game.game_data.sounds.music_mute)


func set_sfx_mute(mute:bool) -> void:
	Game.game_data.sounds.sfx_mute = mute
	Core.sound_manager.set_bus_mute("SFX", mute)


func set_music_mute(mute:bool) -> void:
	Game.game_data.sounds.music_mute = mute
	Core.sound_manager.set_bus_mute("Music", mute)
