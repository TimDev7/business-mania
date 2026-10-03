extends Control

@onready var juicy_progress_bar: JuicyProgressBar = $VBoxContainer/JuicyProgressBar

func _on_button_pressed() -> void:
	$GameWindow.open_window()



func _on_h_slider_value_changed(value: float) -> void:
	juicy_progress_bar.new_value = value
