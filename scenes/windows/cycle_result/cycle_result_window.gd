extends GameWindow
class_name CycleResultWindow

## Итог дня: возврат, бонус за кредит, «Кредит закрыт!». Наружу только
## сигналы, решения принимает Play. Тексты - из UiText.

signal next_pressed
signal restart_pressed

@onready var title_label: Label = %TitleLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var next_button: Button = %NextButton
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	super._ready()
	next_button.pressed.connect(next_pressed.emit)
	# Перезапуск стажировки из итога дня гостю не нужен и сбросил бы прогресс случайным
	# нажатием: кнопка осталась от первых версий. Перезапуск есть в финале («Новый день»).
	restart_button.visible = false
	restart_button.pressed.connect(restart_pressed.emit)


## summary - итог из GameSession.cycle_finished.
func show_summary(summary: Dictionary) -> void:
	var day_number := int(summary["cycle_index"]) + 1
	var day_count := maxi(int(summary.get("day_count", day_number)), day_number)
	title_label.text = UiText.t("result_credit_closed") if bool(summary.get("credit_closed", false)) \
			else UiText.t("result_title", [day_number, day_count])
	# Строки «иконка + число» без слов: заработано / возврат, процент, бонус, копилка, статистика.
	var won := int(summary["minigames_won"])
	var quiz_ok := int(summary["quiz_correct"])
	var lines: PackedStringArray = [
		"%s %s / %s" % [UiText.img("coin"), UiText.num(int(summary["earned"])), UiText.num(int(summary["repay"]))],
		"%s %d%%" % [UiText.img("gauge"), int(summary["return_percent"])],
		"%s +%s" % [UiText.img("gift"), UiText.money_rich(int(summary["credit_bonus"]))],
		"%s +%s" % [UiText.img("piggy"), UiText.money_rich(int(summary["savings_base"]))],
		"%s %d/%d    %s %d/%d" % [
			UiText.img("gamepad"), won, won + int(summary["minigames_failed"]),
			UiText.img("quiz"), quiz_ok, quiz_ok + int(summary["quiz_wrong"])],
	]
	# Особые случаи (учебный день, недобор) - словами: они важны и бывают редко.
	if bool(summary.get("shortfall_forgiven", false)):
		lines.append(UiText.t("result_forgiven", [UiText.money_rich(int(summary["shortfall"]))]))
	elif int(summary.get("net", 0)) < 0:
		lines.append(UiText.t("result_shortfall", [UiText.money_rich(-int(summary["net"]))]))
	# Тестеры принимали это окно за конец игры и закрывали её до куратора: прямо говорим,
	# что игра продолжается и что будет дальше.
	var hint_key := "result_next_hint_last" if day_number >= day_count else "result_next_hint"
	lines.append("[color=#ffd54a]%s[/color]" % UiText.t(hint_key))
	UiText.put(text_label, "\n".join(lines), "center")
	UiText.fill(next_button, "btn_to_mentor")
	UiText.fill(restart_button, "btn_new_day")
	open_window()


## Клик по фону не закрывает окно: без кнопки игра бы зависла между днями.
func _on_back_button_pressed() -> void:
	pass
