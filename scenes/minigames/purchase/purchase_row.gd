extends VBoxContainer
class_name PurchaseRow

## Один ползунок «Закупки»: название, значение, зелёная зона за ползунком.
## key (food / staff / marketing) задаётся в инспекторе инстанса.
## Сам баланс не считает - сообщает о движении, решает мини-игра.

signal moved(key: String, value: int)
signal released

@export var key: String = ""

@onready var name_label: Label = %NameLabel
@onready var value_label: Label = %ValueLabel
@onready var zone_band: Control = %ZoneBand
@onready var slider: HSlider = %Slider

const OK_COLOR := Color("#5cc46a")
const OFF_COLOR := Color("#f0a04b")

var _budget := 100
var _zone_low := 0
var _zone_high := 0


func _ready() -> void:
	slider.value_changed.connect(func(v: float) -> void: moved.emit(key, int(v)))
	slider.drag_ended.connect(func(_changed: bool) -> void: released.emit())
	slider.resized.connect(_update_zone)


func setup(title: String, budget: int, step: int, zone_low: int, zone_high: int) -> void:
	name_label.text = title
	slider.min_value = 0
	slider.max_value = budget
	slider.step = step
	_budget = budget
	_zone_low = zone_low
	_zone_high = zone_high
	_update_zone()
	_update_zone.call_deferred() # после первой раскладки размеры уже настоящие


## state - "low" / "ok" / "high" из PurchaseLogic.check().
func show_state(value: int, state: String) -> void:
	slider.set_value_no_signal(value)
	value_label.text = "%d%%" % value
	value_label.add_theme_color_override("font_color", OK_COLOR if state == "ok" else OFF_COLOR)


## Ручка HSlider ходит не по всей ширине, а по (ширина - размер ручки), и её центр
## стоит на grabber/2 + доля * (ширина - ручка). Считаем зону по реальным размерам
## ползунка, поэтому отступы у родителя зоны подгонять не нужно.
func _update_zone() -> void:
	var grabber := slider.get_theme_icon("grabber")
	var grabber_w := float(grabber.get_width()) if grabber != null else 0.0
	var travel := maxf(0.0, slider.size.x - grabber_w)
	var parent := zone_band.get_parent() as Control
	# Положение ползунка в системе координат родителя зоны.
	var origin := slider.global_position.x - parent.global_position.x
	var left := origin + grabber_w / 2.0 + travel * float(_zone_low) / _budget
	var right := origin + grabber_w / 2.0 + travel * float(_zone_high) / _budget
	zone_band.anchor_left = 0.0
	zone_band.anchor_right = 0.0
	zone_band.offset_left = left
	zone_band.offset_right = right
