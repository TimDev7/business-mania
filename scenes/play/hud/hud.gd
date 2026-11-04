extends Control
class_name Hud

## Верх экрана дня: номер дня и кредит, полоска времени дня с секундами
## поверх (TimeLabel лежит внутри TimeBar), «заработано», полоска возврата
## (отметку 70% рисует сцена), таймер шага и всплывающее «+400 / −200».
## Только показывает то, что ему передал Play. Тексты - из UiText. CycleLabel и
## EarnedLabel лучше сделать RichTextLabel: тогда вместо слова «фетов» будет иконка.

const GOOD := Color("#5cc46a")
const BAD := Color("#e0534a")

@onready var cycle_label: Control = %CycleLabel
@onready var time_label: Label = %TimeLabel
@onready var time_bar: JuicyProgressBar = %TimeBar
@onready var earned_label: Control = %EarnedLabel
@onready var earned_bar: JuicyProgressBar = %EarnedBar
@onready var step_bar: JuicyProgressBar = %StepBar
@onready var delta_label: Label = %DeltaLabel

## Три полосы - три разных смысла, поэтому и вид разный: время дня (фиолетовая, красная
## в конце), закрытие кредита (зелёная, самая крупная, монета - цель) и таймер задания (тонкая
## синяя). Текстуры векторные (SVG), каждая нарисована под свою высоту: cap - радиус
## закругления (боковые поля 9-slice), height - высота полосы в px.
const BAR_SPECS := {
	"time": {"under": "res://assets/textures/bars/time_track.svg", "fill": "res://assets/textures/bars/time_fill.svg",
			"over": "res://assets/textures/bars/time_over.svg", "height": 44, "cap": 22},
	"earned": {"under": "res://assets/textures/bars/earned_track.svg", "fill": "res://assets/textures/bars/earned_fill.svg",
			"over": "res://assets/textures/bars/earned_over.svg", "height": 56, "cap": 28},
	"step": {"under": "res://assets/textures/bars/step_track.svg", "fill": "res://assets/textures/bars/step_fill.svg",
			"over": "", "height": 10, "cap": 5},
}
const TIME_LOW_FRACTION := 0.25 # столько дня осталось - фиолетовая заливка сменяется красной
const TIME_FILL_LOW := "res://assets/textures/bars/time_fill_low.svg"

var _time_fill: Texture2D
var _time_fill_low: Texture2D
var _time_low := false
var _repay := 0
var _shown_earned := -1
var _day_seconds := 1.0
var _delta_tween: Tween


func _ready() -> void:
	delta_label.modulate.a = 0.0
	_style_bar(time_bar, BAR_SPECS["time"])
	_style_bar(earned_bar, BAR_SPECS["earned"])
	_style_bar(step_bar, BAR_SPECS["step"])
	_time_fill = time_bar.texture_progress
	_time_fill_low = load(TIME_FILL_LOW) as Texture2D
	# Секунды по центру фиолетовой полосы, тёмная обводка для читаемости.
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_constant_override("outline_size", 6)
	time_label.add_theme_color_override("font_outline_color", Color("#2b1d14"))
	# Монета на правом конце полосы «заработано»: цель, к которой идёт игрок.
	earned_bar.icon_tex = UiText.icon("coin")
	earned_bar.icon.custom_minimum_size = Vector2(52, 52)


## Шаблонные полосы идут с градиентами-заглушками 64 px и процентом поверх: ставим свои
## векторные текстуры, высоту (без вертикальных полей 9-slice, иначе минимум 48 px)
## и выключаем процент (цифры уже в подписях). Линейная фильтрация: у шаблона nearest.
func _style_bar(bar: JuicyProgressBar, spec: Dictionary) -> void:
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bar.nine_patch_stretch = true
	var cap := int(spec["cap"])
	bar.stretch_margin_left = cap
	bar.stretch_margin_right = cap
	bar.stretch_margin_top = 0
	bar.stretch_margin_bottom = 0
	bar.texture_under = load(str(spec["under"])) as Texture2D
	bar.texture_progress = load(str(spec["fill"])) as Texture2D
	var over_path := str(spec["over"])
	bar.texture_over = load(over_path) as Texture2D if over_path != "" else null
	bar.custom_minimum_size = Vector2(0, int(spec["height"]))
	bar.text_value_visible = false


## Начало дня (day_number с 1).
## principal оставлен в сигнатуре, но не показывается: сумма возврата и так видна у «заработано».
func setup(day_number: int, day_count: int, _principal: int, repay: int, day_seconds: float) -> void:
	_repay = repay
	_day_seconds = maxf(0.001, day_seconds)
	time_bar.max_value = _day_seconds
	time_bar.value = day_seconds
	_set_time_low(false)
	UiText.put(cycle_label, UiText.t("hud_day", [day_number, day_count]), "center")
	earned_bar.max_value = maxf(1.0, float(repay))
	earned_bar.value = 0.0
	_shown_earned = -1


## Каждый кадр дня.
func update_values(time_left: float, earned: int, step_time_left: float, step_limit: float) -> void:
	time_label.text = UiText.t("seconds_short", [ceili(maxf(0.0, time_left))])
	time_bar.value = time_left # меняется каждый кадр - анимация не нужна
	# Последняя четверть дня: фиолетовая заливка сменяется красной.
	_set_time_low(time_left / _day_seconds <= TIME_LOW_FRACTION)
	# Подпись и плавная полоска - только при изменении суммы, не каждый кадр.
	if earned != _shown_earned:
		_shown_earned = earned
		# Иконка фета и «X / Y» без слова «Заработано»; в обычном Label остаётся словесный вариант.
		if earned_label is RichTextLabel:
			UiText.put(earned_label, "%s %s / %s" % [UiText.img("coin"), UiText.num(earned), UiText.num(_repay)], "center")
		else:
			UiText.put(earned_label, UiText.t("hud_earned", [UiText.num(earned), UiText.money(_repay)]))
		earned_bar.new_value = earned
	# Таймер шага и так меняется каждый кадр - анимация не нужна, ставим value напрямую.
	step_bar.max_value = maxf(0.001, step_limit)
	step_bar.value = step_time_left if step_limit > 0.0 else 0.0


func _set_time_low(low: bool) -> void:
	if low == _time_low:
		return
	_time_low = low
	time_bar.texture_progress = _time_fill_low if low else _time_fill


func show_delta(delta: int) -> void:
	if delta == 0:
		return
	delta_label.text = "%+d" % delta
	delta_label.add_theme_color_override("font_color", GOOD if delta > 0 else BAD)
	if _delta_tween != null:
		_delta_tween.kill()
	delta_label.modulate.a = 1.0
	_delta_tween = create_tween()
	_delta_tween.tween_interval(0.4)
	_delta_tween.tween_property(delta_label, "modulate:a", 0.0, 0.5)
