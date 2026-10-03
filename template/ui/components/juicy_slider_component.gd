@tool
extends Control
class_name JuicySliderComponent

## ALL SLIDERS GRABER TEXTURES WILL BE REPLACED WITH PLACEHOLDERS

@export var juicy_slider_tex:Texture2D:
	set(value):
		juicy_slider_tex = value
		if is_node_ready():
			juicy_slider.texture = juicy_slider_tex
			_update_ui()
@export var juicy_slider_pressed_tex:Texture2D
@export var juicy_slider_normal_scale:Vector2 = Vector2(1.0,1.0):
	set(value):
		juicy_slider_normal_scale = value
@export var juicy_slider_up_scale:Vector2 = Vector2(1.2,1.2)
@export var juicy_slider_down_scale:Vector2 = Vector2(0.8,0.8)
@export var juicy_slider_anim_time:float = 0.2
@onready var juicy_slider_control: Control = %JuicySliderControl
@onready var juicy_slider: TextureRect = %JuicySlider
@onready var slider: Slider


var _juicy_slider_step:float = -1
var _tween:Tween
var _is_horizontal:bool = false

func _ready() -> void:
	var parent = get_parent()
	if parent is not Slider:
		queue_free()
		return
	
	slider = parent
	if slider is HSlider:
		_is_horizontal = true
	slider.drag_started.connect(_on_drag_started)
	slider.drag_ended.connect(_on_drag_ended)
	slider.value_changed.connect(_on_value_changed)
	slider.resized.connect(_on_resized)
	
	call_deferred("_apply_theme_on_juicy_slider")
	await get_tree().create_timer(0.1).timeout
	call_deferred("_on_resized")


func _update_ui() -> void:
	if not juicy_slider:
		juicy_slider = %JuicySlider
	if not juicy_slider_control:
		juicy_slider_control = %JuicySliderControl
	juicy_slider.scale = juicy_slider_normal_scale
	if _juicy_slider_step < 0:
		_update_juicy_slider_step()
		
	if _is_horizontal:
		juicy_slider.position.x = _juicy_slider_step * slider.value
	else:
		juicy_slider.position.y = _juicy_slider_step * (slider.max_value - slider.value)


func _apply_theme_on_juicy_slider() -> void:
	var stylebox:StyleBox = slider.get_theme_stylebox("grabber_area")
	if juicy_slider_tex and juicy_slider_pressed_tex:
		juicy_slider.texture = juicy_slider_tex
		var placeholder:PlaceholderTexture2D = PlaceholderTexture2D.new()
		placeholder.size = Vector2.ZERO
		slider.add_theme_icon_override("grabber",placeholder)
		slider.add_theme_icon_override("grabber_highlight",placeholder)
		slider.add_theme_icon_override("grabber_disabled",placeholder)
		return
	
	if stylebox is StyleBoxFlat:
		juicy_slider.modulate = stylebox.bg_color
	elif stylebox is StyleBoxTexture:
		juicy_slider.texture = stylebox.texture


func _update_juicy_slider_step() -> void:
	var save_area_size:float
	if _is_horizontal:
		save_area_size = (juicy_slider_control.size.x - juicy_slider.size.x)
	else:
		save_area_size = (juicy_slider_control.size.y - juicy_slider.size.y)
	_juicy_slider_step = (save_area_size / slider.max_value)


func _on_resized() -> void:
	if _is_horizontal:
		juicy_slider.position.y = size.y / 2.0 + juicy_slider.size.y / 2.0
	else:
		juicy_slider.position.x = size.x / 2.0 + juicy_slider.size.x / 2.0
	_update_juicy_slider_step()
	_update_ui()


func _on_value_changed(_value: float) -> void:
	_update_ui()


func _on_drag_started() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	
	juicy_slider.texture = juicy_slider_pressed_tex
	_tween.tween_property(
		juicy_slider,
		"scale",
		juicy_slider_up_scale,
		juicy_slider_anim_time
	).set_trans(Tween.TRANS_BACK)


func _on_drag_ended(_value_changed: bool) -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(false)
	
	juicy_slider.texture = juicy_slider_tex
	_tween.tween_property(
		juicy_slider,
		"scale",
		juicy_slider_down_scale,
		juicy_slider_anim_time
	).set_trans(Tween.TRANS_BOUNCE)
	_tween.tween_property(
		juicy_slider,
		"scale",
		juicy_slider_normal_scale,
		juicy_slider_anim_time
	).set_trans(Tween.TRANS_BOUNCE)
