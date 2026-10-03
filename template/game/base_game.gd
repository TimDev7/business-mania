@icon("res://template/Game/GameNodeIcon.svg")
extends Node
class_name BaseGame

@onready var game_data:GameData = $GameData
@onready var event_bus:GameEventBus = $EventBus
@onready var sound_manager:GameSoundManager = $SoundManager

func _ready():
	Core.event_bus.connect("game_data_loaded",_on_game_data_loaded)
	Core.register_game(game_data)


func _on_game_data_loaded(_last_save_time:int) -> void:
	game_data.initialize(_last_save_time)
	sound_manager.initialize()
