extends RefCounted
class_name CourierLogic

## «Курьер»: сетка плиток дорог, тапом поворачиваем плитку на 90° по часовой; нужно, чтобы
## дорога шла сквозь от пиццерии (P) до дома (H). Пиццерия и дом зафиксированы.
##
## Направления: 0=N 1=E 2=S 3=W. Базовые соединения при повороте 0:
## "-" {N,S}, "L" {N,E}, "T" {N,E,S}, "+" все, "P"/"H" {N}, "." пусто.
## Токен плитки в данных: <тип><поворот>[!] (! = зафиксирована); строки сетки - через пробел.

const BASE := {
	"-": [0, 2], "L": [0, 1], "T": [0, 1, 2], "+": [0, 1, 2, 3],
	"P": [0], "H": [0], ".": [],
}
const DR := [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1)] # (row, col) для N E S W

var rows: int = 0
var cols: int = 0
var layout_id: String = ""
## Плитки по клеткам, индекс = r * cols + c.
var types: Array = []
var rotations: Array = []
var fixed: Array = []
var taps: int = 0

var _bag: ShuffleBag
var _layouts: Array


func _init(layouts: Array, rng: RandomNumberGenerator) -> void:
	_layouts = layouts
	_bag = ShuffleBag.new(layouts, rng)


## Берёт следующую раскладку (без повторов подряд). Возвращает её словарь.
func next_layout() -> Dictionary:
	var layout = _bag.draw() if _bag.size() > 0 else null
	if layout == null:
		return {}
	load_layout(layout)
	return layout


func load_layout(layout: Dictionary) -> void:
	layout_id = str(layout.get("id", ""))
	rows = int(layout["rows"])
	cols = int(layout["cols"])
	types.clear()
	rotations.clear()
	fixed.clear()
	taps = 0
	for line in layout["grid"]:
		for tok in (line as String).split(" ", false):
			var is_fixed: bool = tok.ends_with("!")
			var t: String = tok.substr(0, 1)
			types.append(t)
			rotations.append(int(tok.substr(1, 1)))
			fixed.append(is_fixed)


func tile_type(r: int, c: int) -> String:
	return types[r * cols + c]


func tile_rotation(r: int, c: int) -> int:
	return rotations[r * cols + c]


func is_rotatable(r: int, c: int) -> bool:
	var i := r * cols + c
	return not fixed[i] and types[i] != "." and types[i] != "+"


## Тап по плитке. true, если плитка повернулась (зафиксированные, пустые и крест не вращаются).
func rotate_tile(r: int, c: int) -> bool:
	if r < 0 or c < 0 or r >= rows or c >= cols or not is_rotatable(r, c):
		return false
	var i := r * cols + c
	rotations[i] = (rotations[i] + 1) % 4
	taps += 1
	return true


## Направления, в которые клетка сейчас открыта.
func connections(r: int, c: int) -> Array:
	var i := r * cols + c
	return _dirs(types[i], rotations[i])


## Клетки (Vector2i(row, col)), до которых доходит дорога от пиццерии - для подсветки пути.
func reachable() -> Array:
	var start := _find("P")
	if start.x < 0:
		return []
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in connections(cur.x, cur.y):
			var n: Vector2i = cur + DR[d]
			if n.x < 0 or n.y < 0 or n.x >= rows or n.y >= cols or seen.has(n):
				continue
			if connections(n.x, n.y).has((d + 2) % 4):
				seen[n] = true
				queue.append(n)
	return seen.keys()


func is_solved() -> bool:
	var home := _find("H")
	return home.x >= 0 and reachable().has(home)


## Разрешима ли раскладка (есть простой путь P -> H, на котором каждую плитку можно
## повернуть так, чтобы она соединила вход и выход). Не зависит от текущих поворотов.
func is_solvable() -> bool:
	var start := _find("P")
	var home := _find("H")
	if start.x < 0 or home.x < 0:
		return false
	# Пиццерия открыта только в зафиксированную сторону.
	var d0: int = _dirs("P", rotations[start.x * cols + start.y])[0]
	var first: Vector2i = start + DR[d0]
	return _dfs(first, (d0 + 2) % 4, {start: true}, home)


# Вошли в клетку cell, входящая сторона in_dir (с её стороны). Ищем путь до дома.
func _dfs(cell: Vector2i, in_dir: int, seen: Dictionary, home: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= rows or cell.y >= cols or seen.has(cell):
		return false
	var i := cell.x * cols + cell.y
	var t: String = types[i]
	if cell == home:
		return _dirs("H", rotations[i]).has(in_dir)
	if t == "." or t == "P" or t == "H":
		return false
	seen[cell] = true
	for out_dir in range(4):
		if out_dir == in_dir or not _can_connect(t, i, in_dir, out_dir):
			continue
		if _dfs(cell + DR[out_dir], (out_dir + 2) % 4, seen, home):
			seen.erase(cell)
			return true
	seen.erase(cell)
	return false


func _can_connect(t: String, i: int, a: int, b: int) -> bool:
	if fixed[i]:
		var d := _dirs(t, rotations[i])
		return d.has(a) and d.has(b)
	for k in range(4):
		var d := _dirs(t, k)
		if d.has(a) and d.has(b):
			return true
	return false


@warning_ignore("integer_division")
func _find(t: String) -> Vector2i:
	for i in types.size():
		if types[i] == t:
			return Vector2i(i / cols, i % cols)
	return Vector2i(-1, -1)


static func _dirs(t: String, rot: int) -> Array:
	var out: Array = []
	for d in BASE[t]:
		out.append((d + rot) % 4)
	return out
