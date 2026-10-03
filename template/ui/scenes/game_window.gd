extends CanvasLayer
class_name GameWindow

@export var export_animation_player: AnimationPlayer
@onready var animation_player:AnimationPlayer = $DefaultAnimationPlayer
@onready var control: Control = $Control
@onready var back_button: TextureButton = $BackButton

func _ready() -> void:
	if export_animation_player:
		animation_player.queue_free()
		animation_player = export_animation_player


func open_window() -> void:
	animation_player.stop()
	animation_player.play("open")


func close_window() -> void:
	animation_player.stop()
	animation_player.play("close")


func _on_back_button_pressed() -> void:
	close_window()
