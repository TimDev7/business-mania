@tool
extends MarginContainer
class_name JuicyCheckboxPanel

## DO NOT INTERACT WITH CHILDREN.
## USE PROPERTIES TO ACCESS WITH THEM FROM THIS CLASS INSTEAD

signal toggled(is_on: bool)

@onready var label: Label = %Label
@onready var juicy_check_box: JuicyCheckbox = %JuicyCheckBox
@onready var button: CheckBox = juicy_check_box.button


## Neither juicy_checkbox_panel.tscn nor juicy_check_box.tscn wires the
## real inner CheckBox's own "toggled" up to _on_button_toggled() below -
## there's no [connection] for it anywhere, so a player clicking the
## checkbox never actually called it, never emitted THIS class's own
## toggled signal, and so never reached whatever a caller connected to
## that. Wiring it here instead of in the .tscn matches this class's own
## "don't reach into children, go through this class" rule at the top of
## the file.
func _ready() -> void:
	if not button.toggled.is_connected(_on_button_toggled):
		button.toggled.connect(_on_button_toggled)


@export var text:String:
	set(value):
		text = value
		call_deferred("_update_ui")

@export var font_size:int:
	set(value):
		font_size = value
		call_deferred("_update_ui")


@export var button_min_size:Vector2 = Vector2(32,32):
	set(value):
		button_min_size = value
		call_deferred("_update_ui")


@export_category("Button")
@export var disabled:bool:
	set(value):
		disabled = value
		call_deferred("_update_ui")


@export var button_pressed:bool:
	set(value):
		button_pressed = value
		call_deferred("_update_ui")


func _update_ui() -> void:
	if not is_inside_tree(): return
	if not label:
		label = %Label
	if not juicy_check_box:
		juicy_check_box = %JuicyCheckBox
	if not button:
		button = juicy_check_box.button
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	button.disabled = disabled
	# set_pressed_no_signal, not a plain assignment: the inner CheckBox's
	# own toggled signal is what drives _on_button_toggled below, so
	# looping back through it here would be redundant at best. Without
	# this line, button_pressed's setter only ever updated this wrapper's
	# own tracked value, never the real CheckBox the player actually sees -
	# so setting it from code (e.g. a Settings window syncing the checkbox
	# to a saved mute state on open) silently did nothing visually; only an
	# actual click ever moved the box.
	button.set_pressed_no_signal(button_pressed)
	juicy_check_box.custom_minimum_size = button_min_size


func _on_button_toggled(toggled_on: bool) -> void:
	if button_pressed == toggled_on:
		return
	button_pressed = toggled_on
	toggled.emit(toggled_on)
