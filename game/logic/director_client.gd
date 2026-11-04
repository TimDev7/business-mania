extends Node
class_name DirectorClient

## Сетевая часть директора: POST на прокси с Gemini. Нода нужна только ради
## HTTPRequest - добавь её в сцену, остальное делает GameSession.
##
## Любая беда (нет URL, нет сети, таймаут 8 с, не 200, не JSON) = пустой словарь:
## вызывающий уходит в запасной вариант. Контракт запроса/ответа - proxy/README.md.

@export var proxy_url: String = ""
@export var timeout_seconds: float = 8.0

## Короткий код причины последней неудачи ("" - всё хорошо): no_url, send_N, net_N
## (N - HTTPRequest.RESULT_*: 12 таймаут, 3 не нашли адрес, 2/4 нет соединения,
## 5 TLS), http_КОД[_ошибка воркера]. Нужен, чтобы понять фолбэк на телефоне,
## где консоли нет: GameSession может показать его в пометке про связь.
var last_error: String = ""


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
	last_error = ""
	if proxy_url.strip_edges() == "" or not is_inside_tree():
		last_error = "no_url"
		return {}
	var http := HTTPRequest.new()
	http.timeout = timeout_seconds
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	# В браузере Origin выставляет сам браузер (и менять его нельзя). Десктопная сборка и
	# редактор его не шлют, а воркер без Origin отвечает отказом - подставляем dev-значение,
	# чтобы директора можно было проверять из редактора. Это не защита, а удобство.
	if not OS.has_feature("web"):
		headers.append("Origin: http://localhost:8080")
	var body := JSON.stringify(payload) if method == HTTPClient.METHOD_POST else ""
	var err := http.request(proxy_url.rstrip("/") + path, headers, method, body)
	if err != OK:
		push_warning("DirectorClient: запрос не отправлен (код ошибки %d)" % err)
		last_error = "send_%d" % err
		http.queue_free()
		return {}
	# result: [result, response_code, headers, body]
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		# Причина фолбэка видна в Output: result 4/5 = сеть/таймаут, response_code = ответ воркера.
		var reply := (result[3] as PackedByteArray).get_string_from_utf8().left(200)
		push_warning("DirectorClient: %s вернул result=%d, HTTP %d %s" % [path, int(result[0]), int(result[1]), reply])
		if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
			last_error = "net_%d" % int(result[0])
		else:
			last_error = "http_%d" % int(result[1])
			var failure: Variant = JSON.parse_string(reply)
			if typeof(failure) == TYPE_DICTIONARY and failure.has("error"):
				last_error += "_%s" % str(failure["error"])
		return {}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
