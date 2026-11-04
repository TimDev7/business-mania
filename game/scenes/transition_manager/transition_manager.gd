extends Node
class_name TransitionManager

enum Scenes {None, Title, Play}
# Пути, а не preload: сцена, которой ещё нет на диске, не должна ломать загрузку автозагрузки Game.
var _scene_paths:Dictionary[Scenes, String] = {
	Scenes.Title: "res://scenes/title/title.tscn",
	Scenes.Play: "res://scenes/play/play.tscn",
}
var current_scene:Scenes

var _tween:Tween
@onready var color_rect: ColorRect = $Control/ColorRect

func change_scene_to(scene:Scenes) -> void:
	if current_scene == scene:
		push_warning("Can't change scene to the current scene")
		return
	var packed := load(_scene_paths.get(scene, "")) as PackedScene
	if packed == null:
		push_error("TransitionManager: нет сцены для %s" % Scenes.keys()[scene])
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()

	color_rect.modulate = Color(1,1,1,0)
	color_rect.visible = true
	_tween.tween_property(color_rect,"modulate",Color(1,1,1,1),0.1)
	_tween.play()
	await _tween.finished

	get_tree().change_scene_to_packed(packed)
	current_scene = scene

	_tween = create_tween()
	_tween.tween_property(color_rect, "modulate", Color(1,1,1,0),0.1)
	_tween.play()
	await _tween.finished
	color_rect.visible = false
