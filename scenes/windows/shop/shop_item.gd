extends Button
class_name ShopItem

## Строка магазина - сама кнопка: иконка, название станции, уровень и цена.
## game_id и иконку задают в инспекторе инстанса (toppings / purchase / courier).
## Дочерние ноды должны иметь Mouse Filter = Ignore, иначе съедят нажатие.
## LevelLabel и PriceLabel лучше сделать RichTextLabel: тогда вместо слова «фетов» - иконка.

signal buy_pressed(game_id: String)

@export var game_id: String = ""
@export var icon_texture: Texture2D

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var level_label: Control = %LevelLabel
@onready var price_label: Control = %PriceLabel


func _ready() -> void:
	icon_rect.texture = icon_texture
	pressed.connect(func() -> void: buy_pressed.emit(game_id))


## entry - строка GameSession.shop_catalog() для этой станции.
func show_entry(entry: Dictionary, title: String) -> void:
	name_label.text = title
	UiText.put(level_label, UiText.t("shop_level", [
		int(entry.get("level", 0)), int(entry.get("max_level", 0)),
		UiText.money_for(level_label, int(entry.get("reward", 0)))]))
	var price := int(entry.get("next_price", -1))
	UiText.put(price_label, UiText.t("shop_max") if price < 0 else UiText.money_for(price_label, price))
	disabled = not bool(entry.get("affordable", false))
	# Тема красит только саму кнопку, а содержимое внутри - нет: приглушаем целиком.
	modulate.a = 0.55 if disabled else 1.0
