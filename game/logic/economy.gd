extends RefCounted
class_name Economy

## Вся арифметика денег. Источник чисел - economy.json, ничего не зашито в коде.
## Деньги внутри цикла и копилки - целые.

var _d: Dictionary


func _init(economy_data: Dictionary) -> void:
	_d = economy_data


# --- Кредит ---

func principal(cycle_index: int) -> int:
	var p: Array = _d["credit"]["principals"]
	return int(p[clampi(cycle_index, 0, p.size() - 1)])


## Сумма возврата: тело + проценты (2000 -> 2400 при 20%).
func repay_amount(cycle_index: int) -> int:
	var base := principal(cycle_index)
	return base + roundi(base * float(_d["credit"]["rate_percent"]) / 100.0)


## Прощается ли непогашенный остаток в этом цикле (цикл 1 - обучающий).
func is_shortfall_forgiven(cycle_index: int) -> bool:
	return (_d["credit"]["forgive_shortfall_cycles"] as Array).has(cycle_index + 1)


## Доля возврата в целых процентах, округление вниз (сравнения порогов делаются ниже на целых).
func return_percent(earned: int, repay: int) -> int:
	if repay <= 0:
		return 0
	return floori(earned * 100.0 / repay)


func credit_bonus(earned: int, repay: int) -> int:
	var cb: Dictionary = _d["credit_bonus"]
	# Сравниваем earned*100 >= repay*порог на целых: никаких ошибок float на границах 70% и 100%.
	if earned * 100 >= repay * int(cb["full_from_percent"]):
		return int(cb["full_bonus"])
	if earned * 100 >= repay * int(cb["partial_from_percent"]):
		return int(cb["partial_bonus"])
	return 0


func is_credit_closed(earned: int, repay: int) -> bool:
	return earned * 100 >= repay * int(_d["credit_bonus"]["full_from_percent"])


# --- Награды ---

func minigame_reward(upgrade_level: int) -> int:
	return int(_d["rewards"]["minigame_success"]) + upgrade_level * int(_d["upgrades"]["reward_bonus_per_level"])


func quiz_delta(correct: bool) -> int:
	return int(_d["rewards"]["quiz_correct"]) if correct else int(_d["rewards"]["quiz_wrong"])


## Лимит времени мини-игры с учётом апгрейда.
func minigame_time(base_seconds: float, upgrade_level: int) -> float:
	return base_seconds + upgrade_level * float(_d["upgrades"]["time_bonus_per_level"])


# --- Копилка ---

## 25% заработанного + бонус кредита, но не меньше минимума. Бонус директора
## начисляется поверх и в минимум не входит (иначе слабому игроку он почти ничего не давал бы).
func savings_deposit(earned: int, credit_bonus_value: int) -> int:
	var s: Dictionary = _d["savings"]
	var share := floori(earned * float(s["earned_share_percent"]) / 100.0)
	return maxi(int(s["minimum"]), share + credit_bonus_value)


func director_bonus(score: int) -> int:
	return clampi(score, 0, 3) * int(_d["director"]["bonus_per_point"])


# --- Апгрейды ---

func upgrade_max_level() -> int:
	return (_d["upgrades"]["prices"] as Array).size()


## Цена следующего уровня; current_level - уже купленный (0..max). -1 если куплено всё.
func upgrade_price(current_level: int) -> int:
	var prices: Array = _d["upgrades"]["prices"]
	if current_level < 0 or current_level >= prices.size():
		return -1
	return int(prices[current_level])
