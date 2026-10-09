extends RefCounted
class_name UpgradeShop

## Апгрейды станций: у каждой мини-игры свой уровень (0..max). Уровень даёт
## +награду и +время (числа - в economy.json). Деньги (копилку) держит GameSession.

var _economy: Economy
var _levels: Dictionary = {}


func _init(economy: Economy, minigames: Array) -> void:
	_economy = economy
	for g in minigames:
		_levels[g] = 0


func reset() -> void:
	for g in _levels:
		_levels[g] = 0


func level(game_id: String) -> int:
	return int(_levels.get(game_id, 0))


func levels() -> Dictionary:
	return _levels.duplicate()


func is_maxed(game_id: String) -> bool:
	return level(game_id) >= _economy.upgrade_max_level()


## Цена следующего уровня или -1, если станция уже прокачана до максимума.
func next_price(game_id: String) -> int:
	return _economy.upgrade_price(level(game_id))


func can_buy(game_id: String, balance: int) -> bool:
	var price := next_price(game_id)
	return price >= 0 and balance >= price


## Покупает уровень. Возвращает потраченную сумму или -1, если купить нельзя.
## Сам баланс не трогает - вызывающий вычитает возвращённое.
func buy(game_id: String, balance: int) -> int:
	if not _levels.has(game_id) or not can_buy(game_id, balance):
		return -1
	var price := next_price(game_id)
	_levels[game_id] = level(game_id) + 1
	return price


## Для магазина: по каждой станции уровень, цена следующего, можно ли купить.
func catalog(balance: int) -> Array:
	var out: Array = []
	for g in _levels:
		out.append({
			"game": g,
			"level": level(g),
			"max_level": _economy.upgrade_max_level(),
			"next_price": next_price(g),
			"affordable": can_buy(g, balance),
			"reward": _economy.minigame_reward(level(g)),
		})
	return out
