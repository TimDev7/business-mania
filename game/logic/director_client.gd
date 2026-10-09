extends Node
class_name DirectorClient

## Сетевая часть директора: POST на прокси с Gemini. Нода нужна только ради
## HTTPRequest - добавь её в сцену, остальное делает GameSession.
##
## Любая беда (нет URL, нет сети, таймаут 8 с, не 200, не JSON) = пустой словарь:
## вызывающий уходит в запасной вариант. Контракт запроса/ответа - proxy/README.md.

@export var proxy_url: String = ""
@export var timeout_seconds: float = 8.0


## Оценка ответа игрока. Возвращает разобранный JSON ответа или {} при любой неудаче.
func evaluate(payload: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/evaluate", payload)


## Эхо-проверка связи (день 2 плана: CORS и домен источника из билда на itch.io).
## Прокси отвечает {ok, origin, time}.
func ping() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/ping", {})


## Под каждый запрос - свой HTTPRequest: параллельные вызовы не мешают друг другу,
## а отмена/освобождение не оставляет повисших await.
func _request(method: int, path: String, payload: Dictionary) -> Dictionary:
	if proxy_url.strip_edges() == "" or not is_inside_tree():
		return {}
	var http := HTTPRequest.new()
	http.timeout = timeout_seconds
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var body := JSON.stringify(payload) if method == HTTPClient.METHOD_POST else ""
	var err := http.request(proxy_url.rstrip("/") + path, headers, method, body)
	if err != OK:
		http.queue_free()
		return {}
	# result: [result, response_code, headers, body]
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return {}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
