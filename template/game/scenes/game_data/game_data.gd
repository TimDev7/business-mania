extends Node
class_name GameData

# --- NODE ---
@onready var sounds: Sounds = $Sounds
@onready var background_manager: BackgroundManager = $BackgroundManager
@onready var transition_manager: TransitionManager = $TransitionManager



func initialize(_last_save_time:int) -> void:
	pass


func load_default_data() -> void:
	for node in get_children():
		if node.has_method("load_default_data"):
			node.load_default_data()


func dict_to_game_data(dict:Dictionary) -> void:
	for node in get_children():
		if node.has_method("deserialize"):
			var key = node.name.to_lower()
			node.deserialize(dict.get(key,{}))


func game_data_to_dict() -> Dictionary:
	var dict:Dictionary = {}
	
	for node in get_children():
		if node.has_method("serialize"):
			var key = node.name.to_lower()
			dict[key] = node.serialize()
	
	return dict


# --- DEBUG ---
@export var debug_mode: bool = false
