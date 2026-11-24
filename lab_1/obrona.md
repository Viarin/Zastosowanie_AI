# Obrona – Lab 1: grafik zmian na SOR (CP-SAT)

> Файл тільки для мене. НЕ класти в ZIP.
> Пояснення – українською, готові відповіді (🗣) – польською.
> Усі числа в розділах 6 і 8 – справжні результати запусків на копії ноутбука (OR-Tools 9.15.6755).

---

## 1. Задача в 5 реченнях

1. **Вхід:** файл `L1_zad.csv` – 12 працівників (5 Senior, 7 Junior), у кожного ставка `stawka_h` (65–140 PLN), ліміт `max_zmian` і доступність (0/1) на кожну з 9 змін.
2. **Що шукаємо:** хто на якій зміні працює (3 дні × 3 зміни по 8 годин: Rano, Popołudnie, Noc).
3. **Обмеження:** рівно 2 особи на зміні, мінімум 1 Senior, ніхто не перевищує `max_zmian`, ніхто не працює недоступним, після Noc немає Rano наступного дня (11 год відпочинку).
4. **Мета:** мінімальна сумарна вартість зарплат (ставка × 8 год).
5. **Результат:** статус `OPTIMAL`, **12 192 PLN**, працюють 6 осіб (по 3 зміни кожен).

🗣 *„Mam 12 pracowników i 9 zmian. Na każdej zmianie muszą być dwie osoby, w tym co najmniej jeden Senior. Szukam grafiku o najniższym koszcie płac. Solver CP-SAT znalazł optimum: 12 192 PLN, pracuje 6 osób.”*

---

## 2. Комірка за коміркою

Ноутбук: 22 клітинки (15 з кодом, 7 markdown). Нумерація = індекс клітинки в ноутбуці.

### Клітинка 0 (markdown)
Заголовок: «Zadanie 1: grafik pracy na SOR», автор, album, grupa + одне речення, що модель зроблена в OR-Tools CP-SAT.

### Клітинка 1 (код) – встановлення

```python
!pip install ortools pandas
```

**Що робить:** встановлює бібліотеки в Colab. `!` = виконати команду оболонки, а не Python.
**Як працює:** `ortools` – солвер, `pandas` – таблиці. У Colab pandas вже є, тому виводить «already satisfied».
**Навіщо:** в Colab немає OR-Tools «з коробки».
**Можуть спитати:**
- *Po co `!pip`?* – 🗣 „Żeby w Colabie doinstalować OR-Tools, bo domyślnie go tam nie ma.”

### Клітинка 2 (markdown)
«Najpierw importy i dane» – підпис до наступної клітинки.

### Клітинка 3 (код) – імпорти і дані

```python
import os
import pandas as pd
from ortools.sat.python import cp_model

if not os.path.exists("L1_zad.csv"):
    from google.colab import files
    files.upload()

dane = pd.read_csv("L1_zad.csv")
dane
```

**Що робить:** підключає бібліотеки, завантажує CSV у таблицю `dane`, показує її.
**Як працює:**
- `import pandas as pd` – `pd` це скорочена назва.
- `from ortools.sat.python import cp_model` – модуль з класами моделі й солвера.
- `os.path.exists("L1_zad.csv")` – чи файл лежить поруч. Якщо ні (Colab) – `files.upload()` відкриває вікно вибору файла.
- `pd.read_csv` читає CSV у `DataFrame`; рядок = працівник, колонки: `pracownik, rola, stawka_h, max_zmian, Pon_Rano, …, Sr_Noc`.
- останній рядок `dane` – Jupyter показує таблицю.

**Навіщо:** всі вхідні дані беремо з файла, а не пишемо вручну.
**Можуть спитати:**
- *Co oznaczają 0 i 1 w kolumnach `Pon_Rano` itd.?* – 🗣 „To dostępność: 1 – pracownik może pracować na tej zmianie, 0 – nie może.”
- *Po co `os.path.exists`?* – 🗣 „W Colabie plik trzeba najpierw wgrać; ten warunek wgrywa go tylko wtedy, gdy go nie ma.”

### Клітинка 4 (код) – стала структура

```python
dni = ["Pon", "Wt", "Sr"]
pory = ["Rano", "Popoludnie", "Noc"]

zmiany = []
for dzien in dni:
    for pora in pory:
        zmiany.append(dzien + "_" + pora)

godziny_zmiany = 8
liczba_pracownikow = len(dane)
```

**Що робить:** будує список з 9 назв змін: `Pon_Rano, Pon_Popoludnie, Pon_Noc, Wt_Rano, …, Sr_Noc`.
**Як працює:** зовнішній цикл – дні, внутрішній – пори; `dzien + "_" + pora` склеює рядки. `len(dane)` = кількість рядків = 12.
**Навіщо:** назви збігаються з назвами колонок у CSV, тому далі `dane.loc[p, s]` працює напряму. `godziny_zmiany = 8` – з умови задачі.
**Можуть спитати:**
- *Jak dodać czwarty dzień?* – 🗣 „Dopisuję `\"Czw\"` do listy `dni`; reszta kodu liczy się z `len(dni)`, ale w CSV muszą być kolumny `Czw_…` z dostępnością.”

### Клітинка 5 (markdown)
Пояснює змінну `x[p, s]` (1 = працівник `p` на зміні `s`) і перелічує обмеження з умови: по 2 особи, мінімум 1 senior, `max_zmian`, заборона Rano після Noc.

### Клітинка 6 (код) – змінні рішення

```python
model = cp_model.CpModel()

x = {}
for p in range(liczba_pracownikow):
    for s in zmiany:
        x[p, s] = model.NewBoolVar("x_" + str(p) + "_" + s)
        # niedostępny -> od razu 0
        if dane.loc[p, s] == 0:
            model.Add(x[p, s] == 0)
```

**Що робить:** створює порожню модель і 12 × 9 = 108 булевих змінних; якщо людина недоступна – ставить змінну = 0.
**Як працює:**
- `cp_model.CpModel()` – «контейнер» для змінних, обмежень і мети.
- `x = {}` – словник; ключ це **кортеж** `(p, s)`, наприклад `x[3, "Pon_Rano"]`.
- `model.NewBoolVar(name)` – змінна, яка може бути лише 0 або 1; ім'я потрібне лише для налагодження.
- `dane.loc[p, s]` – комірка таблиці: рядок `p` (номер), колонка `s` (назва зміни) → 0 або 1.
- `model.Add(x[p, s] == 0)` – обмеження «ця змінна дорівнює 0».

**Навіщо:** це «пульт керування» моделі – солвер вирішує, які змінні = 1. Доступність = жорстке обмеження.
**Можуть спитати:**
- *Dlaczego zmienne binarne?* – 🗣 „Bo decyzja jest tak/nie: pracownik na zmianie albo nie. Binarna zmienna 0/1 dokładnie to modeluje.”
- *Dlaczego `== 0` zamiast nie tworzyć zmiennej?* – 🗣 „Tak jest prościej: wszystkie pary mają zmienną, więc reszta kodu jest jednolita. Solver przy upraszczaniu modelu i tak usuwa taką zmienną.”

### Клітинка 7 (код) – рівно 2 особи

```python
for s in zmiany:
    model.Add(sum(x[p, s] for p in range(liczba_pracownikow)) == 2)
```

**Що робить:** для кожної зміни сума змінних по всіх працівниках = 2.
**Як працює:** `sum(... for p in range(...))` – generator expression: бере `x[0,s], x[1,s], …, x[11,s]` і додає. Тут `x` – змінні моделі, тому результат – лінійний вираз, а не число. `== 2` робить із нього обмеження.
**Навіщо:** вимога задачі: рівно 2 особи.
**Можуть спитати:**
- *Dlaczego dokładnie 2, a nie co najmniej 2?* – 🗣 „Zadanie wymaga dwóch osób. Przy „co najmniej 2” solver i tak nie dałby więcej, bo każda dodatkowa osoba kosztuje, ale `== 2` dokładnie oddaje treść zadania i jest czytelniejsze.”

### Клітинка 8 (код) – мінімум 1 Senior

```python
for s in zmiany:
    seniorzy_na_zmianie = []
    for p in range(liczba_pracownikow):
        if dane.loc[p, "rola"] == "Senior":
            seniorzy_na_zmianie.append(x[p, s])
    model.Add(sum(seniorzy_na_zmianie) >= 1)
```

**Що робить:** для кожної зміни збирає змінні лише Senior-ів і вимагає, щоб їхня сума ≥ 1.
**Як працює:** порожній список → у циклі по людях `if` відбирає тих, у кого `rola == "Senior"` → `append` додає їхню змінну → `sum(...) >= 1`. Список перескладається для кожної зміни (він оголошується всередині зовнішнього циклу).
**Навіщо:** на кожній зміні має бути хоч один Senior; це автоматично означає, що два Junior-и ніколи разом не працюють.
**Можуть спитати:**
- *Co się stanie, jeśli usuniesz ograniczenie seniora?* – 🗣 „Solver weźmie najtańsze osoby, czyli głównie Juniorów. Sprawdziłem: koszt spada do 9 912 PLN, ale grafik jest nieprawidłowy, bo nie ma żadnego Seniora.”
- *Dlaczego `>= 1`, a nie `== 1`?* – 🗣 „Zadanie mówi „co najmniej jeden Senior”, więc dwóch Seniorów na zmianie też jest dozwolone.”

### Клітинка 9 (код) – ліміт змін

```python
for p in range(liczba_pracownikow):
    model.Add(sum(x[p, s] for s in zmiany) <= dane.loc[p, "max_zmian"])
```

**Що робить:** для кожного працівника сума його змін ≤ `max_zmian`.
**Як працює:** тут `sum` іде по змінах `s` (а не по людях); права частина береться з таблиці.
**Навіщо:** вимога задачі. Саме цей ліміт є «вузьким місцем»: найдешевші люди завантажені на максимум.
**Можуть спитати:**
- *Co jeśli nie ma rozwiązania?* – 🗣 „Solver zwraca status `INFEASIBLE`. Sprawdziłem: gdy ustawię `max_zmian = 1` dla wszystkich, to 12 osób daje tylko 12 miejsc przy 18 potrzebnych i dostaję `INFEASIBLE`.”

### Клітинка 10 (код) – Rano після Noc

```python
# rano po nocy jest zabronione
for p in range(liczba_pracownikow):
    for i in range(len(dni) - 1):
        model.Add(x[p, dni[i] + "_Noc"] + x[p, dni[i + 1] + "_Rano"] <= 1)
```

**Що робить:** для кожної людини і кожної пари сусідніх днів: Noc дня `i` + Rano дня `i+1` ≤ 1.
**Як працює:** `range(len(dni) - 1)` = 0, 1 (пари Pon→Wt, Wt→Sr; останній день не має «наступного»). `dni[i] + "_Noc"` – ім'я зміни (напр. `"Pon_Noc"`). Сума двох булевих ≤ 1 означає «не обидві одночасно».
**Навіщо:** умова задачі: після нічної зміни потрібно 11 годин відпочинку, а ранкова зміна йде майже одразу після нічної.
**Можуть спитати:**
- *Dlaczego suma `<= 1`, a nie „jeśli… to…”?* – 🗣 „Dla zmiennych 0/1 warunek „nie obie naraz” to dokładnie suma co najwyżej 1. Solver pracuje na takich liniowych ograniczeniach.”

### Клітинка 11 (markdown)
Пояснює моє додаткове обмеження: максимум 1 зміна на день (інакше Rano+Noc того ж дня = лише 8 год перерви).

### Клітинка 12 (код) – моє припущення

```python
zalozenie_max_1_zmiana_dziennie = True

if zalozenie_max_1_zmiana_dziennie:
    for p in range(liczba_pracownikow):
        for dzien in dni:
            model.Add(x[p, dzien + "_Rano"] + x[p, dzien + "_Popoludnie"]
                      + x[p, dzien + "_Noc"] <= 1)
```

**Що робить:** якщо прапорець `True` – для кожної людини і дня сума її трьох змін ≤ 1.
**Як працює:** прапорець – звичайна змінна `True/False`; `if` додає обмеження лише коли `True`. Вираз у дужках просто перенесений на 2 рядки.
**Навіщо:** без нього можливо Rano + Noc в один день (8 год перерви). Це моє припущення, не вимога задачі; прапорець дозволяє його вимкнути й порівняти.
**Можуть спитати:**
- *Dlaczego dodałeś to ograniczenie?* – 🗣 „Zadanie wymaga 11 godzin odpoczynku po nocy. Bez tego ograniczenia ktoś mógłby mieć poranek i noc tego samego dnia, czyli tylko 8 godzin przerwy. Koszt jest ten sam, ale grafik jest realistyczniejszy.”
- *Ile kosztuje to założenie?* – 🗣 „Nic: z założeniem i bez niego optimum to 12 192 PLN.”

### Клітинка 13 (markdown)
Пояснює друге, опційне обмеження (кожен ≥ 1 зміни): у оптимумі 6 з 12 не працюють, опція справедливіша, але дорожча; залишено вимкненою, бо задача вимагає найдешевшого графіка.

### Клітинка 14 (код) – опційне «мін. 1 зміна»

```python
zalozenie_min_1_zmiana = False

if zalozenie_min_1_zmiana:
    for p in range(liczba_pracownikow):
        model.Add(sum(x[p, s] for s in zmiany) >= 1)
```

**Що робить:** якщо `True` – кожен працівник отримує ≥ 1 зміну. За замовчуванням вимкнено.
**Як працює:** як у клітинці 9, але `>= 1`.
**Навіщо:** показати, скільки коштує «справедливість» (+632 PLN).
**Можуть спитати:**
- *Jak zmienić, żeby było sprawiedliwiej?* – 🗣 „Mogę włączyć flagę `zalozenie_min_1_zmiana` (każdy ma co najmniej 1 zmianę, koszt 12 824 PLN) albo dodać górny limit zmian na osobę, np. 2 (koszt 13 088 PLN, pracuje 10 osób).”

### Клітинка 15 (markdown)
Мета = сума `stawka_h * 8` по всіх призначених змінах; потім запуск солвера.

### Клітинка 16 (код) – функція мети

```python
koszt_calkowity = 0
for p in range(liczba_pracownikow):
    for s in zmiany:
        koszt_zmiany = dane.loc[p, "stawka_h"] * godziny_zmiany * x[p, s]
        koszt_calkowity = koszt_calkowity + koszt_zmiany

model.Minimize(koszt_calkowity)
```

**Що робить:** будує вираз «сума ставка × 8 × x» і каже солверу його мінімізувати.
**Як працює:** `stawka * 8 * x[p,s]` – число × змінна = лінійний член. Якщо `x = 1` – платимо ставку × 8, якщо 0 – нічого. Цикл накопичує суму в `koszt_calkowity`. `model.Minimize(...)` ставить це метою.
**Навіщо:** без мети солвер знайшов би будь-який допустимий графік, а не найдешевший.
**Можуть спитати:**
- *Dlaczego CP-SAT, a nie zwykły Python?* – 🗣 „Liczba kombinacji jest ogromna (2^108), a solver przeszukuje je mądrze i daje dowód optymalności.”
- *Czy współczynniki muszą być całkowite?* – 🗣 „Tak, CP-SAT pracuje na liczbach całkowitych. Stawki i godziny są całkowite, więc jest dobrze.”

### Клітинка 17 (код) – розв'язання

```python
solver = cp_model.CpSolver()
solver.parameters.num_workers = 1
solver.parameters.random_seed = 42
status = solver.Solve(model)

print("Status:", solver.StatusName(status))
koszt = round(solver.ObjectiveValue())
print("Całkowity koszt grafiku:", f"{koszt:,}".replace(",", " "), "PLN")
```

Вивід: `Status: OPTIMAL` / `Całkowity koszt grafiku: 12 192 PLN`.

**Що робить:** створює солвер, налаштовує, розв'язує, друкує статус і вартість.
**Як працює:**
- `num_workers = 1` – один потік (за замовчуванням CP-SAT запускає кілька паралельно, і результат може відрізнятися між запусками).
- `random_seed = 42` – фіксоване «зерно» випадковості.
- `Solve(model)` повертає код статусу; `StatusName(status)` перетворює його на текст (`OPTIMAL`, `FEASIBLE`, `INFEASIBLE`…).
- `ObjectiveValue()` – значення мети (float) → `round` → int.
- `f"{koszt:,}"` дає `12,192` (кома як роздільник тисяч); `.replace(",", " ")` міняє кому на пробіл → `12 192`.

**Навіщо:** це точка, де «мислить» солвер; статус перевіряємо, бо без `OPTIMAL` результату довіряти не можна.
**Можуть спитати:**
- *Co znaczy `OPTIMAL`?* – 🗣 „Solver znalazł rozwiązanie i udowodnił, że lepszego nie ma.”
- *Po co `num_workers = 1` i `random_seed = 42`?* – 🗣 „Żeby wynik był powtarzalny. Przy wielu wątkach solver może zwrócić inny, równie tani grafik. Koszt jest ten sam, ale konkretne osoby mogą się różnić.”

### Клітинка 18 (markdown)
Далі: виводимо графік, кількість змін кожного і перевіряємо результат.

### Клітинка 19 (код) – графік

```python
wiersze = []
for s in zmiany:
    osoby = []
    for p in range(liczba_pracownikow):
        if solver.Value(x[p, s]) == 1:
            osoby.append(dane.loc[p, "pracownik"] + " (" + dane.loc[p, "rola"] + ", " + str(dane.loc[p, "stawka_h"]) + " PLN/h)")
    wiersze.append({"Zmiana": s, "Pracownik 1": osoby[0], "Pracownik 2": osoby[1]})

grafik = pd.DataFrame(wiersze)
grafik
```

**Що робить:** для кожної зміни знаходить 2 людей з `x = 1` і складає таблицю.
**Як працює:** `solver.Value(x[p, s])` – значення змінної у знайденому розв'язку (0 або 1). Для кожної людини з 1 додаємо рядок «ім'я (роль, ставка PLN/h)». `str(...)` потрібен, бо число не склеїться зі строкою. `osoby[0]`, `osoby[1]` – перша й друга особа. `wiersze` – список словників; `pd.DataFrame(wiersze)` робить з нього таблицю (ключі = назви колонок).
**Навіщо:** результат у зрозумілому вигляді (це Tabela 1 у звіті).
**Можуть спитати:**
- *Co by się stało, gdyby na zmianie było nie 2, tylko 3 osoby?* – 🗣 „`osoby[1]` i `osoby[0]` wzięłyby tylko dwie pierwsze, ale to się nie zdarzy, bo ograniczenie wymusza dokładnie 2.”

### Клітинка 20 (код) – кількість змін

```python
liczby_zmian = []
for p in range(liczba_pracownikow):
    ile = 0
    for s in zmiany:
        ile = ile + solver.Value(x[p, s])
    liczby_zmian.append(ile)

podsumowanie = pd.DataFrame({"Pracownik": dane["pracownik"], "Rola": dane["rola"],
                             "Stawka [PLN/h]": dane["stawka_h"], "Liczba zmian": liczby_zmian})
podsumowanie
```

**Що робить:** рахує, скільки змін у кожного, і складає зведену таблицю.
**Як працює:** лічильник `ile` додає значення `x[p, s]` по всіх змінах; результат кладеться в список. `dane["pracownik"]` – колонка за назвою (Series); словник колонок → `DataFrame`.
**Навіщо:** видно, що працюють 6 осіб по 3 зміни, 6 – 0 змін; список `liczby_zmian` використовується в `assert`.
**Можуть спитати:**
- *Dlaczego 6 osób nie pracuje?* – 🗣 „Bo funkcja celu minimalizuje koszt i nie ma nagrody za równy podział pracy. Sześć najtańszych osób z limitem 3 zmian pokrywa wszystkie 18 miejsc.”

### Клітинка 21 (код) – перевірка

```python
assert status == cp_model.OPTIMAL, "brak optimum"
for s in zmiany:
    liczba_osob = 0
    liczba_seniorow = 0
    for p in range(liczba_pracownikow):
        liczba_osob = liczba_osob + solver.Value(x[p, s])
        if dane.loc[p, "rola"] == "Senior":
            liczba_seniorow = liczba_seniorow + solver.Value(x[p, s])
    assert liczba_osob == 2, "zła obsada: " + s
    assert liczba_seniorow >= 1, "brak seniora: " + s
for p in range(liczba_pracownikow):
    assert liczby_zmian[p] <= dane.loc[p, "max_zmian"], "za dużo zmian"
    for i in range(len(dni) - 1):
        noc = solver.Value(x[p, dni[i] + "_Noc"])
        rano = solver.Value(x[p, dni[i + 1] + "_Rano"])
        assert noc + rano <= 1, "rano po nocy: " + dane.loc[p, "pracownik"]
print("Wszystko się zgadza.")
```

**Що робить:** вдруге, незалежно від моделі, перевіряє результат.
**Як працює:** `assert умова, "повідомлення"` – якщо умова хибна, програма зупиняється з цим повідомленням; якщо правдива – мовчить. Перевіряємо: статус OPTIMAL; на кожній зміні рівно 2 особи й ≥ 1 Senior; ніхто не перевищив `max_zmian`; немає Rano після Noc.
**Навіщо:** захист від помилки в моделі (якби я неправильно записав обмеження, `assert` би це виявив). Перевірка рахує «з нуля» по готовому розв'язку.
**Можуть спитати:**
- *Po co `assert`, skoro solver gwarantuje wynik?* – 🗣 „Solver gwarantuje rozwiązanie *mojego modelu*. `assert` sprawdza, czy model naprawdę odpowiada treści zadania, więc łapie moje ewentualne błędy w ograniczeniach.”
- *Czy `assert` sprawdza dostępność?* – 🗣 „Nie bezpośrednio; dostępność jest wymuszona w modelu przez `x == 0`. Można dopisać taki `assert` jako dodatkową kontrolę.”

---

## 3. Python і бібліотеки

**pandas**
```python
import pandas as pd
dane = pd.read_csv("L1_zad.csv")        # CSV -> DataFrame
dane.loc[2, "stawka_h"]                 # komórka: wiersz 2, kolumna "stawka_h" -> 110
dane.loc[3, "Pon_Rano"]                 # dostępność pracownika 3 na Pon_Rano -> 1
dane["rola"]                            # cała kolumna (Series)
tabela = pd.DataFrame([{"a": 1, "b": 2}, {"a": 3, "b": 4}])   # z listy słowników
tabela2 = pd.DataFrame({"a": [1, 3], "b": [2, 4]})            # ze słownika kolumn
```
`.loc[wiersz, kolumna]` – доступ за *назвою* (індекс рядка тут = число 0…11).

**cp_model (OR-Tools)**
```python
from ortools.sat.python import cp_model
model = cp_model.CpModel()                  # pusty model
a = model.NewBoolVar("a")                   # zmienna 0/1
b = model.NewBoolVar("b")
model.Add(a + b <= 1)                       # ograniczenie
model.Minimize(3 * a + 5 * b)               # cel
solver = cp_model.CpSolver()                # solver
status = solver.Solve(model)                # rozwiązanie
solver.StatusName(status)                   # "OPTIMAL" / "FEASIBLE" / "INFEASIBLE"
solver.ObjectiveValue()                     # wartość celu
solver.Value(a)                             # wartość zmiennej po rozwiązaniu (0 lub 1)
```

**Словник із ключем-кортежем**
```python
x = {}
x[3, "Pon_Rano"] = "zmienna"     # klucz to krotka (3, "Pon_Rano")
x[3, "Pon_Rano"]                 # odczyt tak samo
```
Це зручніше за список списків: індекс = (людина, зміна).

**Generator всередині `sum`**
```python
sum(x[p, s] for p in range(12))   # to samo co x[0,s] + x[1,s] + ... + x[11,s]
sum([1, 2, 3])                    # 6 – ta sama funkcja, ale na liczbach
```
Із змінними моделі `sum` повертає *вираз*, а не число; число з'являється аж після `Solve`.

---

## 4. Теорія коротко

**CSP vs оптимізація з обмеженнями.** CSP (constraint satisfaction problem): є змінні, їхні області значень і обмеження; шукаємо *будь-яке* присвоєння, що задовольняє все. Оптимізація з обмеженнями: додається функція мети, і з усіх допустимих розв'язків шукаємо найкращий. У нас обмеження описують допустимі графіки, а мета – вартість.
🗣 *„CSP szuka dowolnego rozwiązania spełniającego ograniczenia, a optymalizacja z ograniczeniami szuka najlepszego według funkcji celu – u nas najtańszego.”*

**Що робить CP-SAT.** Поєднує кілька ідей: *propagacja ograniczeń* (коли значення змінної відомо, одразу викреслюються неможливі значення в інших), *przeszukiwanie* (перебір з поверненнями – «спробуй 1, якщо тупик – назад»), *uczenie się z konfliktów* (як у SAT-солверах: коли тупик, запам'ятовує причину й більше її не повторює) та *elementy programowania liniowego* (LP дає оцінку знизу для мети й відсікає заздалегідь погані гілки).
🗣 *„CP-SAT łączy propagację ograniczeń, przeszukiwanie z uczeniem się na konfliktach i dolne oszacowanie z programowania liniowego.”*

**OPTIMAL vs FEASIBLE.** `OPTIMAL` – знайдено розв'язок і *доведено*, що кращого немає (нижня межа = знайдена вартість). `FEASIBLE` – розв'язок є, але солвер не довів оптимальність (зазвичай вийшов ліміт часу). `INFEASIBLE` – розв'язку, що задовольняє обмеження, не існує.
🗣 *„OPTIMAL znaczy: rozwiązanie jest najlepsze i solver to udowodnił. FEASIBLE znaczy tylko, że rozwiązanie jest poprawne, ale nie ma dowodu optymalności.”*

**Чому двійкові змінні 0/1.** Рішення «працює / не працює» – це так/ні. Булева змінна точно це описує, а сума таких змінних = «скільки людей», тому всі обмеження (по 2 особи, ліміт, мін. 1 Senior) стають простими лінійними нерівностями, з якими CP-SAT працює найкраще.
🗣 *„Decyzja jest tak albo nie, więc używam zmiennych 0/1. Dzięki temu wszystkie ograniczenia to proste sumy i nierówności.”*

---

## 5. Математика (як у звіті) ↔ код

**Позначення.** $P$ – працівники (12), $Z$ – зміни (9), $S\subseteq P$ – Senior-и, $D=\{\text{Pon},\text{Wt},\text{Sr}\}$ – дні, $Z_d$ – три зміни дня $d$, $N=\{(\text{Pon\_Noc},\text{Wt\_Rano}),(\text{Wt\_Noc},\text{Sr\_Rano})\}$ – заборонені пари. Дані: ставка $c_p$, ліміт $m_p$, доступність $d_{pz}\in\{0,1\}$, довжина зміни $H=8$.
**Змінна:** $x_{pz}\in\{0,1\}$ = 1, якщо $p$ працює на зміні $z$ → `x[p, s] = model.NewBoolVar(...)`.

| # | Формула | Значення | Код |
|---|---|---|---|
| Мета | $\min \sum_{p}\sum_{z} H\cdot c_p\cdot x_{pz}$ | мінімальна вартість | клітинка 16: `koszt_zmiany = dane.loc[p,"stawka_h"] * godziny_zmiany * x[p,s]`, `model.Minimize(koszt_calkowity)` |
| 1 | $x_{pz}\le d_{pz}$ | доступність | клітинка 6: `if dane.loc[p, s] == 0: model.Add(x[p, s] == 0)` |
| 2 | $\sum_{p} x_{pz}=2$ | рівно 2 особи | клітинка 7: `model.Add(sum(x[p, s] for p in range(liczba_pracownikow)) == 2)` |
| 3 | $\sum_{p\in S} x_{pz}\ge 1$ | мін. 1 Senior | клітинка 8: `model.Add(sum(seniorzy_na_zmianie) >= 1)` |
| 4 | $\sum_{z} x_{pz}\le m_p$ | ліміт змін | клітинка 9: `model.Add(sum(x[p, s] for s in zmiany) <= dane.loc[p, "max_zmian"])` |
| 5 | $x_{pn}+x_{pr}\le 1,\ (n,r)\in N$ | Rano не після Noc | клітинка 10: `model.Add(x[p, dni[i] + "_Noc"] + x[p, dni[i + 1] + "_Rano"] <= 1)` |
| 6 | $\sum_{z\in Z_d} x_{pz}\le 1$ | моє: макс. 1 зміна на день | клітинка 12: три `x` з одного дня `<= 1` |
| 7 | $\sum_{z} x_{pz}\ge 1$ | опційне: мін. 1 зміна | клітинка 14: `model.Add(sum(x[p, s] for s in zmiany) >= 1)` |

Обмеження 1–5 – з умови задачі, 6 і 7 – мої (6 увімкнене, 7 вимкнене за замовчуванням).
🗣 *„Zmienna $x_{pz}$ jest równa 1, gdy pracownik $p$ pracuje na zmianie $z$. Minimalizuję sumę stawek razy 8 godzin po wszystkich przydzielonych zmianach, przy ograniczeniach: dostępność, dokładnie dwie osoby, co najmniej jeden Senior, limit zmian i zakaz poranka po nocy.”*

---

## 6. Результат

**Чому 12 192 PLN – оптимум (нижня межа, крок за кроком):**
1. Усього 9 змін × 2 місця = 18 місць. На кожній зміні потрібен мінімум 1 Senior → мінімум **9 місць Senior-ів** (і 9 «будь-яких» місць).
2. Кожен має ліміт 3 зміни (Dr_Kowalski і Dr_Nowakowska – лише 2). Щоб закрити 9 місць Senior-ів найдешевше, беремо трьох найдешевших Senior-ів по 3 зміни: 95, 105, 110 PLN/h.
3. Інших 9 місць може займати хто завгодно; найдешевші – 65, 65, 68 PLN/h (Junior-и), знову по 3 зміни.
4. Сума ставок × кількість змін: 3·(95+105+110) + 3·(65+65+68) = 3·310 + 3·198 = 930 + 594 = **1 524** PLN за «годину кожного».
5. × 8 годин = 1 524 · 8 = **12 192 PLN**. Нижче неможливо: ми взяли найдешевший склад, а графік, знайдений солвером, цю межу досягає → він оптимальний.
🗣 *„Potrzebuję 9 miejsc Seniora i 9 miejsc drugiej osoby. Najtańsi Seniorzy to 95, 105 i 110 złotych na godzinę, po trzy zmiany każdy, a najtańsi pozostali to 65, 65 i 68. Razem 8 razy 1524 daje 12 192 złote, a to jest dolne ograniczenie, więc grafik jest optymalny.”*

**Чому 6 осіб не працюють:** мета лише мінімізує вартість, «нагороди» за рівний розподіл немає. 6 найдешевших з лімітом 3 зміни закривають усі 18 місць (6 × 3 = 18); кожна дорожча особа підвищила б вартість. Це не помилка моделі. Це Dr_Kowalski, Dr_Nowakowska, Piel_Lewandowska, Piel_Zielinska, Rat_Szymanski, Rat_Wozniak (0 змін).
🗣 *„To nie błąd modelu. Funkcja celu nie nagradza równego podziału, a sześć najtańszych osób z limitem trzech zmian pokrywa wszystkie 18 miejsc.”*

**Моє додаткове обмеження (макс. 1 зміна на день) – варіанти a і b** (справжні запуски):

| Варіант | `zalozenie_max_1…` | `zalozenie_min_1…` | Статус | Вартість | Працює |
|---|---|---|---|---|---|
| a) | False | False | OPTIMAL | 12 192 PLN | 6 |
| b) (за замовч., = Tabela 1) | True | False | OPTIMAL | 12 192 PLN | 6 |
| c) | True | True | OPTIMAL | 12 824 PLN | 12 |

- a vs b: **вартість однакова**, змінюється лише якість графіка. Без обмеження в варіанті a: **Rat_Wojcik** у понеділок має Pon_Rano + Pon_Noc, **Piel_Kaminska** у середу має Sr_Rano + Sr_Noc (лише 8 годин перерви, а потрібно 11 після ночі). Інших подвійних змін немає.
- c: вартість **+632 PLN (+5,2 %)**; Dr_Kowalski і Dr_Nowakowska отримують по 1 зміні (найдорожчі, 140 і 135 PLN/h).

🗣 *„Moje założenie o jednej zmianie dziennie nic nie kosztuje: w obu wariantach koszt to 12 192 złote. Bez niego Rat_Wojcik miałby w poniedziałek poranek i noc, a Piel_Kaminska w środę poranek i noc. Wymuszenie pracy dla wszystkich kosztuje 632 złote więcej, czyli 5,2 procent.”*

**Чому `num_workers = 1` і `random_seed = 42`:** за замовчуванням CP-SAT працює паралельно в кількох потоках з різним «зерном»; може бути багато *однаково дешевих* графіків і солвер може повернути інший при кожному запуску. З 1 потоком і фіксованим seed графік однаковий локально й у Colab, тож таблиці у звіті збігаються з ноутбуком. Вартість 12 192 PLN була б та сама.
🗣 *„Jeden wątek i stałe ziarno dają powtarzalny wynik, więc grafik z raportu zgadza się z tym w Colabie. Koszt byłby taki sam, ale osoby na zmianach mogłyby być inne.”*

---

## 7. Топ-15 питань на захисті

1. **Jaki problem rozwiązujesz?**
   „Układam grafik 9 zmian dla 12 pracowników tak, żeby koszt płac był jak najniższy, przy ograniczeniach z zadania: dwie osoby na zmianie, co najmniej jeden Senior, limit zmian, dostępność i zakaz poranka po nocy.”

2. **Dlaczego CP-SAT, a nie np. algorytm zachłanny?**
   „Zachłanny nie daje gwarancji optymalności, a CP-SAT daje: dostaję status OPTIMAL, czyli dowód, że lepszego grafiku nie ma. Przy tylu ograniczeniach ręczne rozwiązanie jest trudne.”

3. **Co znaczy status OPTIMAL?**
   „Solver znalazł rozwiązanie i udowodnił, że nie ma tańszego. FEASIBLE znaczyłoby, że rozwiązanie jest poprawne, ale bez dowodu optymalności.”

4. **Dlaczego zmienne binarne?**
   „Decyzja to tak/nie: pracownik pracuje na zmianie albo nie. Zmienna 0/1 dokładnie to opisuje, a sumy takich zmiennych dają liczbę osób.”

5. **Co się stanie, jeśli usuniesz ograniczenie seniora?**
   „Solver weźmie najtańszych, czyli Juniorów. Sprawdziłem: koszt spada do 9 912 złotych, ale na żadnej zmianie nie ma Seniora, więc grafik nie spełnia zadania.”

6. **Dlaczego `x == 0` zamiast nie tworzyć zmiennej?**
   „Dla prostoty: każda para (pracownik, zmiana) ma zmienną, więc reszta kodu jest jednolita. Solver przy uproszczeniu modelu i tak eliminuje zmienną ustawioną na 0.”

7. **Co jeśli nie ma rozwiązania?**
   „Solver zwraca status INFEASIBLE. Sprawdziłem: przy `max_zmian = 1` dla wszystkich jest tylko 12 miejsc na 18 potrzebnych i dostaję INFEASIBLE. Wtedy nie ma grafiku, więc trzeba poluzować ograniczenia.”

8. **Jak dodać czwarty dzień?**
   „Dopisuję `\"Czw\"` do listy `dni` i dodaję do danych kolumny `Czw_Rano`, `Czw_Popoludnie`, `Czw_Noc` z dostępnością. Reszta kodu używa `len(dni)`, więc działa bez zmian. Przy pełnej dostępności koszt to 17 152 złote.”

9. **Dlaczego dokładnie 2, a nie co najmniej 2?**
   „Zadanie mówi o dwóch osobach. Przy „co najmniej 2” solver i tak nie wziąłby więcej, bo każda osoba kosztuje, ale `== 2` dokładnie oddaje treść zadania.”

10. **Jak zmienić, żeby było sprawiedliwiej?**
    „Mogę włączyć `zalozenie_min_1_zmiana` (każdy co najmniej jedna zmiana, 12 824 złote) albo ograniczyć liczbę zmian na osobę do 2 (13 088 złotych, pracuje 10 osób). Sprawiedliwość kosztuje więcej, bo wchodzą droższe osoby.”

11. **Dlaczego sześć osób nie dostaje żadnej zmiany?**
    „Funkcja celu minimalizuje tylko koszt, bez nagrody za równy podział. Sześć najtańszych osób z limitem 3 zmian pokrywa wszystkie 18 miejsc.”

12. **Skąd wiesz, że 12 192 PLN to naprawdę minimum?**
    „Policzyłem dolne ograniczenie: 9 miejsc Seniora po 95, 105, 110 złotych, 9 pozostałych po 65, 65, 68, po 3 zmiany każdy. 8 razy 1524 to 12 192, a solver osiągnął dokładnie tę wartość.”

13. **Po co twoje założenie o jednej zmianie dziennie?**
    „Zadanie wymaga 11 godzin odpoczynku po nocy. Bez tego założenia Rat_Wojcik miałby w poniedziałek poranek i noc, czyli tylko 8 godzin przerwy. Koszt jest ten sam, więc nic nie traci się na jakości.”

14. **Po co `num_workers = 1` i `random_seed = 42`?**
    „Żeby wynik był powtarzalny lokalnie i w Colabie. Przy wielu wątkach mogę dostać inny, równie tani grafik.”

15. **Po co `assert`, skoro solver już policzył?**
    „Solver gwarantuje poprawność względem mojego modelu. `assert` sprawdza niezależnie, czy gotowy grafik spełnia treść zadania (obsada, Senior, limit zmian, brak poranka po nocy), więc wykrywa ewentualne błędy w modelu.”

---

## 8. Що змінити наживо (справжні результати)

Усе перевірено на копії ноутбука, OR-Tools 9.15.6755. Усі зміни – в іншій комірці **перед** `Solve`, потім «Run all».

### 8.1 Четвертий день (Czw)
Змінити клітинку 4 і додати колонки з доступністю (у CSV їх немає, припускаю повну доступність):
```python
dni = ["Pon", "Wt", "Sr", "Czw"]
```
Після завантаження даних:
```python
for pora_x in ["Rano", "Popoludnie", "Noc"]:
    dane["Czw_" + pora_x] = 1
```
**Результат:** `OPTIMAL`, **17 152 PLN**, працює **10** осіб (12 змін × 2 = 24 місця, не вистачає 6 найдешевших, тому підключаються ще Rat_Szymanski, Rat_Wozniak, Dr_Nowakowska, Dr_Kowalski). Assert-и проходять. Заборона «Rano після Noc» і `assert` автоматично охоплюють нову пару Sr→Czw, бо використовують `len(dni)`.
🗣 *„Dodałem czwarty dzień i kolumny dostępności. Reszta kodu bierze liczbę dni z `len(dni)`, więc nic więcej nie trzeba zmieniać. Koszt rośnie do 17 152 złotych i pracuje 10 osób.”*

### 8.2 Два Senior-и на нічних змінах
Нове обмеження (після клітинки 10):
```python
for dzien in dni:
    seniorzy_w_nocy = []
    for p in range(liczba_pracownikow):
        if dane.loc[p, "rola"] == "Senior":
            seniorzy_w_nocy.append(x[p, dzien + "_Noc"])
    model.Add(sum(seniorzy_w_nocy) >= 2)
```
**Результат:** `OPTIMAL`, **13 840 PLN** (+1 648 PLN проти 12 192), працює **7** осіб; на кожній Noc обоє – Senior-и (Pon_Noc і Sr_Noc: Wisniewski + Wojcik; Wt_Noc: Wisniewski + Kaminska). Додатково працюють дорожчі Dr_Nowakowska (2 зміни) і Dr_Kowalski (1).
🗣 *„Dodałem wymaganie dwóch Seniorów na nocnej zmianie. Koszt rośnie do 13 840 złotych, bo na nocy pracują wyłącznie Seniorzy, a to droższe osoby.”*

### 8.3 Зміна довжини зміни
Клітинка 4:
```python
godziny_zmiany = 12
```
**Результат:** `OPTIMAL`, **18 288 PLN**, ті самі 6 осіб (= 12 × 1 524; графік не змінюється, бо змінився лише множник для всіх).
🗣 *„Zmiana długości zmiany to tylko mnożnik kosztu: 12 razy 1524 daje 18 288 złotych, a grafik zostaje taki sam, bo wszystkie koszty rosną proporcjonalnie.”*

### 8.4 Справедливіше: максимум 2 зміни на людину
Після клітинки 9:
```python
for p in range(liczba_pracownikow):
    model.Add(sum(x[p, s] for s in zmiany) <= 2)
```
**Результат:** `OPTIMAL`, **13 088 PLN** (+896 PLN, +7,3 %), працює **10** осіб, ніхто не має більше 2 змін (Dr_Kowalski 1, Dr_Nowakowska 2, Rat_Wozniak 1, решта працюючих по 2).
🗣 *„Ograniczyłem liczbę zmian na osobę do dwóch. Praca jest równiej podzielona, pracuje 10 osób, ale koszt rośnie do 13 088 złotych.”*

### 8.5 (бонус для питань) Без обмеження Senior-а
Видалити (або закоментувати) `model.Add(sum(seniorzy_na_zmianie) >= 1)` у клітинці 8 (тоді `assert … brak seniora` у клітинці 21 теж треба прибрати, інакше він зупинить програму).
**Результат:** `OPTIMAL`, **9 912 PLN**, працює 7 осіб, **усі Junior-и**.

### 8.6 (бонус) INFEASIBLE
Після завантаження даних: `dane["max_zmian"] = 1`.
**Результат:** `Status: INFEASIBLE` (12 осіб × 1 зміна = 12 місць < 18). Solver друкує «Całkowity koszt grafiku: 0 PLN», а наступна клітинка з графіком падає з `IndexError`, бо немає розв'язку. Тому `assert status == OPTIMAL` корисний.

---

*Контрольні суми й числа в цьому файлі отримані з реальних запусків на копіях ноутбука; оригінал `2026_2_S_Rybak_1_K.ipynb` не змінювався.*
