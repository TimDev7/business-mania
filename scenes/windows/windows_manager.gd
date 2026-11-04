extends CanvasLayer
class_name WindowsManager

## Владеет окнами поверх игры и пробрасывает их сигналы в Play.
## Play зовёт show_*(), окна про GameSession не знают. Одновременно открыто одно
## «основное» окно (итог, куратор, разбор ошибок, магазин, финал): при показе нового
## остальные закрываются. Диалог и «Контент в разработке» ложатся поверх остальных.

signal cycle_next_pressed
signal restart_pressed
signal director_submitted(text: String)
signal director_continue_pressed
signal mistakes_continue_pressed
signal buy_pressed(game_id: String)
signal shop_next_pressed
signal learn_more_pressed
signal dialog_finished

@onready var cycle_result_window: CycleResultWindow = %CycleResultWindow
@onready var director_window: DirectorWindow = %DirectorWindow
@onready var shop_window: ShopWindow = %ShopWindow
@onready var final_window: FinalWindow = %FinalWindow
@onready var coming_soon_window: ComingSoonWindow = %ComingSoonWindow
# Эти два окна добавлены позже: без них игра пропускает шаг и пишет предупреждение.
@onready var mistakes_window: MistakesWindow = get_node_or_null("%MistakesWindow")
@onready var dialog_window: DialogWindow = get_node_or_null("%DialogWindow")


func _ready() -> void:
	cycle_result_window.next_pressed.connect(cycle_next_pressed.emit)
	cycle_result_window.restart_pressed.connect(restart_pressed.emit)
	director_window.answer_submitted.connect(director_submitted.emit)
	director_window.continue_pressed.connect(director_continue_pressed.emit)
	if mistakes_window != null:
		mistakes_window.continue_pressed.connect(mistakes_continue_pressed.emit)
	shop_window.buy_pressed.connect(buy_pressed.emit)
	shop_window.next_pressed.connect(shop_next_pressed.emit)
	final_window.learn_more_pressed.connect(learn_more_pressed.emit)
	final_window.restart_pressed.connect(restart_pressed.emit)
	if dialog_window != null:
		dialog_window.finished.connect(dialog_finished.emit)


func show_cycle_result(summary: Dictionary) -> void:
	_close_others(cycle_result_window)
	cycle_result_window.show_summary(summary)


func show_director(problem: Dictionary) -> void:
	_close_others(director_window)
	director_window.show_problem(problem)


func show_director_thinking() -> void:
	director_window.show_thinking()


func show_director_result(result: Dictionary) -> void:
	director_window.show_result(result)


func show_mistakes(mistakes: Array) -> void:
	if mistakes_window == null:
		push_warning("WindowsManager: в сцене нет %MistakesWindow, разбор ошибок пропущен")
		mistakes_continue_pressed.emit.call_deferred()
		return
	_close_others(mistakes_window)
	mistakes_window.show_mistakes(mistakes)


func show_shop(catalog: Array, piggy: int, titles: Dictionary) -> void:
	_close_others(shop_window)
	shop_window.show_shop(catalog, piggy, titles)


func refresh_shop(catalog: Array, piggy: int) -> void:
	shop_window.refresh(catalog, piggy)


func show_final(summary: Dictionary) -> void:
	_close_others(final_window)
	final_window.show_final(summary)


## Поверх финала: закрывается тапом по фону, финал остаётся под ним.
func show_coming_soon(text: String) -> void:
	coming_soon_window.show_message(text)


## Диалог поверх всего (легенда, вступление, «как играть»). pages - из Story.
func show_dialog(pages: Array, last_button: String, can_skip: bool = true) -> void:
	if dialog_window == null:
		push_warning("WindowsManager: в сцене нет %DialogWindow, диалог пропущен")
		dialog_finished.emit.call_deferred()
		return
	dialog_window.show_pages(pages, last_button, can_skip)


func close_all() -> void:
	_close_others(null)


func _close_others(keep: GameWindow) -> void:
	for w: GameWindow in [cycle_result_window, director_window, mistakes_window, shop_window, final_window, coming_soon_window]:
		if w != null and w != keep and w.visible:
			w.close_window()
