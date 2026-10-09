extends RefCounted
class_name PurchaseLogic

## «Закупка»: фиксированный бюджет делится между тремя ползунками (продукты, сотрудники,
## маркетинг); у каждого есть зелёная зона. Успех - все три в своих зонах.
## Бюджет в процентах от 100, шаг ползунка берётся из данных (по умолчанию 5).
##
## Фронтенд: на движение ползунка зовёт rebalance(), потом check() для подсветки зон.

const KEYS := ["food", "staff", "marketing"]

var scenario: Dictionary = {}
var budget: int = 100
var step: int = 5
var values: Dictionary = {}

var _bag: ShuffleBag
var _start: Dictionary


func _init(purchase_data: Dictionary, rng: RandomNumberGenerator) -> void:
	budget = int(purchase_data.get("budget", 100))
	step = maxi(1, int(purchase_data.get("step", 5)))
	_start = purchase_data.get("start", {})
	_bag = ShuffleBag.new(purchase_data.get("scenarios", []), rng)


## Берёт следующий сценарий и возвращает ползунки в стартовое положение.
@warning_ignore("integer_division")
func next_scenario() -> Dictionary:
	scenario = _bag.draw() if _bag.size() > 0 else {}
	values = {}
	for k in KEYS:
		values[k] = int(_start.get(k, budget / 3))
	return scenario


## Двигает один ползунок, остальные подстраиваются так, чтобы сумма осталась равной бюджету.
## Возвращает новые значения (и сохраняет их в values).
func move(key: String, new_value: int) -> Dictionary:
	values = rebalance(values, key, new_value, budget, step)
	return values


## Чистая функция: значения после движения ползунка key. Новое значение прижимается
## к 0..budget и шагу; оставшееся распределяется между двумя другими пропорционально
## их текущим долям (если оба нулевые - поровну).
static func rebalance(current: Dictionary, key: String, new_value: int, total: int, snap: int) -> Dictionary:
	var v := clampi(roundi(float(new_value) / snap) * snap, 0, total)
	var others: Array = KEYS.filter(func(k): return k != key)
	var remaining := total - v
	var sum_old := 0
	for k in others:
		sum_old += int(current.get(k, 0))
	var first_share: int
	if sum_old <= 0:
		first_share = roundi(remaining / 2.0 / snap) * snap
	else:
		first_share = roundi(remaining * float(current[others[0]]) / sum_old / snap) * snap
	first_share = clampi(first_share, 0, remaining)
	var out := {key: v}
	out[others[0]] = first_share
	out[others[1]] = remaining - first_share
	return out


## Состояние зон для подсветки: {success, sum_ok, zones: {key: "low"|"ok"|"high"}}.
func check() -> Dictionary:
	return check_values(values, scenario, budget)


static func check_values(vals: Dictionary, scen: Dictionary, total: int) -> Dictionary:
	var sum := 0
	var zones := {}
	var all_ok := true
	for k in KEYS:
		var v := int(vals.get(k, 0))
		sum += v
		var z: Array = scen.get("zones", {}).get(k, [0, total])
		var state := "ok"
		if v < int(z[0]):
			state = "low"
		elif v > int(z[1]):
			state = "high"
		zones[k] = state
		all_ok = all_ok and state == "ok"
	var sum_ok := sum == total
	return {"success": all_ok and sum_ok, "sum_ok": sum_ok, "zones": zones}


## Есть ли хоть одно решение (для проверки данных): целые числа с шагом snap, сумма = бюджету.
static func is_feasible(scen: Dictionary, total: int, snap: int) -> bool:
	var z: Dictionary = scen.get("zones", {})
	for f in range(int(z["food"][0]), int(z["food"][1]) + 1, snap):
		for s in range(int(z["staff"][0]), int(z["staff"][1]) + 1, snap):
			var m := total - f - s
			if m >= int(z["marketing"][0]) and m <= int(z["marketing"][1]) and m % snap == 0:
				return true
	return false
