extends Control
class_name Minigame

## Общий контракт мини-игры. Play кладёт сцену в MinigameHost на время шага,
## зовёт start() и ждёт finished. Таймер шага ведёт CycleRun: по таймауту Play
## сам убирает сцену, мини-игре об этом знать не нужно.
## Каждая мини-игра (stub, toppings, purchase, courier) - наследник этого скрипта.

signal finished(success: bool)

var _done := false


## logic - объект из GameSession.new_minigame() (null у заглушки),
## step - словарь шага CycleRun (game, limit, reward, upgrade_level).
func start(_logic: RefCounted, _step: Dictionary) -> void:
	pass


## Для наследников: сообщить итог ровно один раз.
func finish(success: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(success)
