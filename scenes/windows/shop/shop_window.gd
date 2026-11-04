extends GameWindow
class_name ShopWindow

## Магазин апгрейдов между днями. Строки станций (ShopItem) пользователь
## кладёт в %Items в редакторе и задаёт каждой game_id; окно только заполняет их.

signal buy_pressed(game_id: String)
signal next_pressed

@onready var piggy_label: Control = %PiggyLabel # RichTextLabel покажет иконку фета
@onready var items_box: Control = %Items
@onready var next_button: Button = %NextButton

var _items: Dictionary = {} # game_id -> ShopItem
var _titles: Dictionary = {}


func _ready() -> void:
	super._ready()
	for child in items_box.get_children():
		if child is ShopItem:
			_items[child.game_id] = child
			child.buy_pressed.connect(buy_pressed.emit)
	next_button.pressed.connect(next_pressed.emit)


## catalog - GameSession.shop_catalog(); titles - {game_id: название станции}.
func show_shop(catalog: Array, piggy: int, titles: Dictionary) -> void:
	_titles = titles
	UiText.fill(next_button, "btn_next_day")
	refresh(catalog, piggy)
	open_window()


func refresh(catalog: Array, piggy: int) -> void:
	UiText.put(piggy_label, UiText.t("shop_piggy", [UiText.money_for(piggy_label, piggy)]), "center")
	for entry in catalog:
		var item: ShopItem = _items.get(entry["game"])
		if item != null:
			item.show_entry(entry, str(_titles.get(entry["game"], entry["game"])))


## Закрыть фоном нельзя: из магазина выходят кнопкой «Следующий день».
func _on_back_button_pressed() -> void:
	pass
