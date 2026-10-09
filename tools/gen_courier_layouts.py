#!/usr/bin/env python3
"""Генератор раскладок мини-игры «Курьер» -> game/data/courier_layouts.json.

Строит самонепересекающийся путь от пиццерии (низ) до дома (верх), типы плиток на пути
выводит из поворотов (прямая / угол), остальное забивает «шумом» и случайно крутит плитки.
Запуск: python3 tools/gen_courier_layouts.py [seed]. Результат закоммичен как данные;
независимую проверку «решаемо и не решено с начала» делает сама игра (CourierLogic.validate_layout).

Токен плитки: <тип><поворот>[!]; тип: P пиццерия, H дом, - прямая, L угол, T тройник, + крест, . пусто.
Поворот 0..3 по часовой стрелке; ! - плитка зафиксирована. Направления: 0=N 1=E 2=S 3=W.
Базовые соединения при повороте 0: - {N,S}, L {N,E}, T {N,E,S}, + все, P/H {N}.
"""
import json
import random
import sys

ROWS, COLS = 5, 4
DR = [(-1, 0), (0, 1), (1, 0), (0, -1)]  # N E S W
BASE = {"-": {0, 2}, "L": {0, 1}, "T": {0, 1, 2}, "+": {0, 1, 2, 3}, "P": {0}, "H": {0}, ".": set()}


def rot(dirs, k):
    return {(d + k) % 4 for d in dirs}


def find_rot(tile, want):
    for k in range(4):
        if rot(BASE[tile], k) == want:
            return k
    raise ValueError((tile, want))


def make_path(rng, min_len):
    while True:
        start = (ROWS - 1, rng.randrange(COLS))
        path = [start]
        seen = {start}
        while True:
            r, c = path[-1]
            if r == 0 and len(path) >= min_len:
                return path
            opts = []
            for d, (dr, dc) in enumerate(DR):
                n = (r + dr, c + dc)
                if 0 <= n[0] < ROWS and 0 <= n[1] < COLS and n not in seen:
                    # путь не должен касаться сам себя боком - иначе решение неоднозначно, но это допустимо
                    opts.append(n)
            if not opts:
                break
            # слегка тянем вверх
            up = [o for o in opts if o[0] < r]
            n = rng.choice(up) if up and rng.random() < 0.55 else rng.choice(opts)
            path.append(n)
            seen.add(n)


def dir_between(a, b):
    return DR.index((b[0] - a[0], b[1] - a[1]))


def build(rng, min_len):
    while True:
        path = make_path(rng, min_len)
        if path[-1][0] != 0:
            continue
        grid = {}
        sol = {}
        for i, cell in enumerate(path):
            if i == 0:
                d = dir_between(cell, path[1])
                grid[cell] = "P"
                sol[cell] = find_rot("P", {d})
            elif i == len(path) - 1:
                d = dir_between(cell, path[i - 1])
                grid[cell] = "H"
                sol[cell] = find_rot("H", {d})
            else:
                a, b = dir_between(cell, path[i - 1]), dir_between(cell, path[i + 1])
                t = "-" if (a - b) % 4 == 2 else "L"
                grid[cell] = t
                sol[cell] = find_rot(t, {a, b})
        rotatable = [c for c in path[1:-1]]
        # доля «нужных» поворотов, чтобы был смысл крутить
        if len(rotatable) < 4:
            continue
        for r in range(ROWS):
            for c in range(COLS):
                if (r, c) not in grid:
                    grid[(r, c)] = rng.choice([".", "-", "L", "L", "T", "-"])
                    sol[(r, c)] = rng.randrange(4)
        state = {}
        for cell, t in grid.items():
            if cell in path and t in "PH":
                state[cell] = sol[cell]
            elif cell in path:
                # неверный поворот хотя бы по эквивалентным соединениям
                while True:
                    k = rng.randrange(4)
                    if rot(BASE[t], k) != rot(BASE[t], sol[cell]):
                        break
                state[cell] = k
            else:
                state[cell] = rng.randrange(4)
        rows = []
        for r in range(ROWS):
            toks = []
            for c in range(COLS):
                t = grid[(r, c)]
                toks.append(f"{t}{state[(r, c)]}" + ("!" if t in "PH" else ""))
            rows.append(" ".join(toks))
        return {"rows": ROWS, "cols": COLS, "grid": rows, "path_len": len(path)}


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 20261009
    rng = random.Random(seed)
    layouts = []
    for i in range(7):
        lay = build(rng, 6 + i % 3)
        lay["id"] = f"courier_{i + 1:02d}"
        layouts.append(lay)
    out = {"_note": "Сгенерировано tools/gen_courier_layouts.py. Не править руками - перегенерировать.", "layouts": layouts}
    with open("game/data/courier_layouts.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write("\n")
    for l in layouts:
        print(l["id"], l["path_len"])
        for r in l["grid"]:
            print("   ", r)


if __name__ == "__main__":
    main()
