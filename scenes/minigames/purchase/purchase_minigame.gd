extends Minigame

## «Закупка»: распредели бюджет между тремя ползунками так, чтобы каждый попал
## в зелёную зону. Правила - в PurchaseLogic (move() подстраивает остальные
## ползунки, check() говорит про зоны). Успех засчитывается, когда игрок отпустил
## ползунок и все три в зонах; провал по времени засчитывает CycleRun.

@onready var scenario_label: Label = %ScenarioLabel
@onready var rows_box: Control = %Rows

var _logic: PurchaseLogic
var _rows: Dictionary = {} # key -> PurchaseRow


func _ready() -> void:
	for child in rows_box.get_children():
		if child is PurchaseRow:
			_rows[child.key] = child
			child.moved.connect(_on_row_moved)
			child.released.connect(_on_row_released)


## logic - PurchaseLogic с уже выбранным сценарием; step.lang - язык игрока.
func start(logic: RefCounted, step: Dictionary) -> void:
	_logic = logic as PurchaseLogic
	if _logic == null:
		push_error("PurchaseMinigame: нет PurchaseLogic")
		return
	var lang := str(step.get("lang", "ru"))
	scenario_label.text = Localizer.text(_logic.rule, lang) + "\n" + Localizer.text(_logic.scenario.get("text", {}), lang)
	var zones: Dictionary = _logic.scenario.get("zones", {})
	for key in _rows:
		var zone: Array = zones.get(key, [0, _logic.budget])
		_rows[key].setup(_logic.key_name(key, lang), _logic.budget, _logic.step, int(zone[0]), int(zone[1]))
	_refresh()


func _refresh() -> void:
	var zone_states: Dictionary = _logic.check()["zones"]
	for key in _rows:
		_rows[key].show_state(int(_logic.values[key]), str(zone_states[key]))


func _on_row_moved(key: String, value: int) -> void:
	if _logic == null:
		return
	_logic.move(key, value)
	_refresh()


func _on_row_released() -> void:
	if _logic != null and _logic.check()["success"]:
		finish(true)
