extends Node
class_name JuicyButtonComponent

@export var button_normal_scale:Vector2 = Vector2(1.0,1.0)
@export var button_down_scale:Vector2 = Vector2(0.8,0.8)
@export var button_up_scale:Vector2 = Vector2(1.1,1.1)
@export var anim_time:float = 0.1
## Optional: add an AudioStreamPlayer child named "AudioStreamPlayer" (with
## its own bus/stream assigned in the editor - a game-specific click SFX
## asset has no business living in this generic template) to get a click
## sound for free on every button using this component. Left unset
## (get_node_or_null returns null), _on_button_pressed() below just skips
## playing anything - no scene using this component today is broken by
## adding this.
@onready var audio_stream_player: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")

var tween:Tween
var _button:BaseButton

func _ready() -> void:
	var parent = get_parent()
	if parent is BaseButton:
		_button = parent
	_button.pivot_offset_ratio = Vector2(0.5,0.5)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	_button.pressed.connect(_on_button_pressed)


func _on_button_down() -> void:
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(_button, "scale", button_down_scale, anim_time).set_ease(Tween.EASE_IN)


func _on_button_up() -> void:
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(_button, "scale", button_up_scale, anim_time).set_ease(Tween.EASE_OUT)
	tween.tween_property(_button, "scale", button_normal_scale, anim_time).set_ease(Tween.EASE_OUT)


func _on_button_pressed() -> void:
	if is_inside_tree() and audio_stream_player:
		audio_stream_player.pitch_scale = randf_range(0.9,1.1)
		audio_stream_player.play()
