# Businessmania — бэкенд (логика без сцен)

Вся игровая логика лежит в `game/logic/` и **не содержит нод и сцен** — это `RefCounted`-классы
(кроме `DirectorClient`, ему нужен `HTTPRequest`). Все числа и тексты — в `game/data/*.json`.
Фронтенд (сцены, UI, анимации, ввод) подключается к одному фасаду — `GameSession`.

Время в логике идёт **только** через `tick(delta)`: пауза = перестать звать `tick`.

## Подключение (что сделать в редакторе)

1. Один раз прогнать headless-редактор, чтобы Godot зарегистрировал новые `class_name`
   (`godot --headless --editor --quit`, дать **полностью** завершиться), затем проверить
   `git diff --stat -- '*.tscn'`.
2. Добавить в сцену игры ноду `DirectorClient` (Node со скриптом `game/logic/director_client.gd`),
   задать `proxy_url` (URL воркера из `proxy/`). Без URL директор работает на эталонных ответах.
3. Создать сессию и отдать ей клиент:

```gdscript
var session := GameSession.create_default()   # читает game/data/*.json, ошибки данных -> push_error
session.director_client = $DirectorClient
session.set_language("ru")                    # ru / kk / en
session.new_player()                          # «Новый игрок»
```

JSON читаются через `load()` как ресурс `JSON` (попадают в экспорт без include_filter).
Проверить после первого Web-экспорта, что `GameConfig.load_default()` не вернул ошибок.

## Поток игры

```
new_player() → start_cycle() → CYCLE ──(cycle_finished)──▶ CYCLE_RESULT
  → begin_director() → DIRECTOR → await submit_director_answer(text) → SHOP
  → buy_upgrade(game_id)… → start_cycle() …
  после директора ПОСЛЕДНЕГО цикла → FINISHED (session_finished, final_summary())
```

`GameSession`: `state`, `piggy`, `cycle_index`, `run`, `shop_catalog()`, `final_summary()`,
сигналы `cycle_started`, `cycle_finished(summary)`, `piggy_changed`, `session_finished(final)`.
Каждый кадр во время цикла: `session.tick(delta)`.

### Цикл — `CycleRun` (его возвращает `start_cycle()`, он же `session.run`)

Раунд = подсказка A → мини-игра A → подсказка B → мини-игра B → квиз; A ≠ B, порядок случайный.

| Сигнал / метод | Что делает фронтенд |
|---|---|
| `step_started(step)` | `step.kind`: `hint` (`game`, `limit`), `minigame` (`game`, `limit` с учётом апгрейда, `reward`, `upgrade_level`), `quiz` (`limit`, `question`: `text`, `options`, `correct_index`) |
| `report_minigame_result(success)` | мини-игра закончилась (успех/провал); таймаут шага считает сам `CycleRun` |
| `answer_quiz(shown_index)` | индекс кнопки как показано игроку (варианты уже перемешаны) |
| `step_finished(step, outcome)` | `success/fail/timeout/aborted`, `correct/wrong/timeout/aborted`, `done` |
| `earned_changed(earned, delta)` | обновить деньги цикла |
| `time_left`, `step_time_left`, `earned` | поля для таймера 90 с и таймера шага |

Шаг, не уложившийся в общий таймер, получает `aborted` и **не засчитывается** (ни награды, ни штрафа, ни записи ошибки).
Таймаут квиза = неверный ответ (−200, ошибка в лог). «Заработано» не уходит ниже нуля.

`cycle_finished(summary)`: `earned`, `repay`, `return_percent`, `credit_bonus`, `credit_closed` («Кредит закрыт!»),
`shortfall`, `shortfall_forgiven` (цикл 1), `net` (в циклах 2–3 может быть отрицательным), `savings_base`, счётчики.

### Мини-игры

На `step_started` с `kind == "minigame"`: `var logic = session.new_minigame(step.game)` — свежая логика с уже
загруженным заказом/сценарием/раскладкой (без повторов подряд). Один запуск = один заказ/сценарий/раскладка.

- **toppings** — `ToppingsLogic`: `order.items`, `place(id)` → `ok/done/wrong`, `remaining()`, `is_complete()`.
- **purchase** — `PurchaseLogic`: `scenario.text/zones`, `move(key, value)` (остальные ползунки подстраиваются, сумма = бюджету),
  `check()` → `{success, zones: {key: low|ok|high}}`. Ключи: `food`, `staff`, `marketing`.
- **courier** — `CourierLogic`: сетка `rows × cols`, `tile_type/tile_rotation(r, c)`, `rotate_tile(r, c)`, `connections(r, c)`
  для отрисовки, `reachable()` для подсветки пути, `is_solved()`. Пиццерия (`P`) и дом (`H`) зафиксированы.

Успех → `run.report_minigame_result(true)`. Раскладки курьера генерирует `tools/gen_courier_layouts.py`.

### Директор

1. `var p := session.begin_director()` → `text`, `is_repeat`/`repeat_intro`, `input_seconds` (60), `max_chars` (150),
   `mistakes` (разбор ошибок цикла на примерах игрока).
2. Фронтенд показывает поле; `input_seconds` в config.json - лимит времени (0 = без ограничения, таймера нет; сейчас 0). По таймеру (если задан) или кнопке: `var r = await session.submit_director_answer(text)`.
3. `r`: `score` 0–3, `verdict`, `missing`, `better`, `is_fallback`, `note` («связь нестабильна»), `bonus`
   (0/100/200/300), `mistakes`, `savings_deposit`, `piggy`.

Запасной вариант (нет URL/сети, 12 с без ответа - `request_timeout_seconds`, невалидный JSON): эталон, оценка 1 (+100), `is_fallback = true`.
Пустой ответ: 0 без запроса. Текст обрезается до 150 символов и склеивается в одну строку.

### Магазин, итог

`shop_catalog()` → по каждой станции `level`, `next_price` (−1 = максимум), `affordable`; `buy_upgrade(game_id)`.
`final_summary()`: `top_mistakes` (топ-3, с `count`), `cycles`, `director_scores` (динамика для питча), `piggy`, `learn_more_url`.

## Локализация

Тексты в JSON — `{"ru": …, "kk": …, "en": …}`. Нет перевода → RU → EN (`Localizer`). Сейчас контент **черновой**:
9 из 24 вопросов, 6 проблем директора, RU+EN, казахского пока нет.

## Принятые решения по неоднозначным местам GDD (проверьте!)

- Минимум копилки 300 применяется к «25% + бонус кредита»; бонус директора добавляется **поверх** минимума.
- «Остаток уходит в минус итога» в циклах 2–3 реализован как отрицательный `net` в итоге цикла; копилка
  от него не уменьшается и ничего не переносится дальше.
- Деньги цикла (`earned`) не опускаются ниже 0.
- Темы директора: цикл 1 — тема с максимумом ошибок (иначе случайная), цикл 2 — максимум ошибок среди новых тем,
  последний цикл — повтор темы цикла 1, вариант 2.

## Не сделано (осознанно)

Сцены/UI/арт/звук, перетаскивание и отрисовка (фронтенд), реальный контент 24 вопросов + KZ, боевой ключ Gemini,
деплой воркера (`proxy/README.md`), экспорт и страница на itch.io. Тестов нет по правилу репозитория (тесты — только `template/`);
логика проверялась симуляцией в headless-Godot.
