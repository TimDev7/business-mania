extends Node
class_name TransitionManager

enum Scenes {None}
var _scene_to_packed:Dictionary[Scenes, PackedScene] = {
}
var current_scene:Scenes

var _tween:Tween
@onready var color_rect: ColorRect = $Control/ColorRect

func change_scene_to(scene:Scenes) -> void:
	if current_scene == scene:
		push_warning("Can't change scene to the current scene")
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	
	color_rect.modulate = Color(1,1,1,0)
	color_rect.visible = true
	_tween.tween_property(color_rect,"modulate",Color(1,1,1,1),0.1)
	_tween.play()
	await _tween.finished
	
	get_tree().change_scene_to_packed(_scene_to_packed[scene])
	current_scene = scene
	
	_tween = create_tween()
	_tween.tween_property(color_rect, "modulate", Color(1,1,1,0),0.1)
	_tween.play()
	await _tween.finished
	color_rect.visible = false
