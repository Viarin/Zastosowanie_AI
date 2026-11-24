#set document(title: "Ćwiczenie 1, optymalizacja harmonogramu", author: "Vladyslav Rybak")
#set page(paper: "a4", margin: 2.5cm, numbering: "1")
#set text(font: ("Times New Roman", "Liberation Serif"), size: 12pt, lang: "pl")
#set par(justify: true, leading: 0.65em, spacing: 1em)
#set heading(numbering: "1.")
#show heading: set text(weight: "bold", fill: black)
#show heading.where(level: 1): set text(size: 14pt)
#show heading.where(level: 2): set text(size: 12pt)
#show heading: set block(above: 1.2em, below: 0.7em)
#show raw: set text(font: "DejaVu Sans Mono", size: 9pt)
#show raw.where(block: true): it => block(
  fill: luma(245), stroke: 0.5pt + luma(200), inset: 7pt, width: 100%, breakable: false, it)
#set table(stroke: 0.5pt + black, inset: 4pt)
#show table.cell.where(y: 0): set text(weight: "bold")
#show figure: set block(above: 1em, below: 1em)
#show figure.caption: set text(size: 11pt)

// ---------------- Nagłówek (tabela informacyjna) ----------------
#[
  #show table.cell.where(y: 0): set text(weight: "regular")
  #table(
    columns: (1fr, 1fr),
    inset: 6pt,
    stroke: 0.5pt,
    table.cell(colspan: 2, align: center)[*Zastosowanie Biznesowe Sztucznej Inteligencji*],
    [Imię i nazwisko: Vladyslav Rybak], [Nr albumu: 120750],
    [Grupa: 2], [Studia stacjonarne],
    table.cell(colspan: 2)[*Ćwiczenie 1:* Zastosowanie sztucznej inteligencji w optymalizacji harmonogramu zadań dla pracowników \ *Zadanie 1:* grafik zmian w szpitalnym oddziale ratunkowym],
  )
]
#v(0.6cm)

// ---------------- 1. Opis problemu ----------------
= Opis problemu i wprowadzenie teoretyczne

== Problem

Szpitalny oddział ratunkowy zatrudnia 12 osób, w tym 5 Seniorów i 7 Juniorów. Stawki godzinowe są od 65 do 140 PLN, a każdy ma swój limit zmian (`max_zmian`) i swoją dostępność. Trzeba obsadzić trzy dni (Pon, Wt, Sr) po trzy ośmiogodzinne zmiany: Rano, Popołudnie i Noc, razem 9 zmian. Na każdej zmianie mają pracować dokładnie dwie osoby i co najmniej jedna z nich musi być Seniorem. Po zmianie nocnej nie wolno dać zmiany porannej, bo trzeba zachować 11 godzin odpoczynku. Cel to jak najniższy łączny koszt płac.

Od siebie dodałem jeszcze założenie, że nikt nie pracuje więcej niż jedną zmianę dziennie. Bez niego solver mógłby dać komuś rano i noc tego samego dnia, czyli tylko 8 godzin przerwy, a samo zadanie wymaga 11 godzin po nocy. Sprawdziłem też, ile to założenie kosztuje (@wariant).

== Teoria

Układanie grafików to klasyczny problem planowania personelu. Można go zapisać jako problem spełniania ograniczeń (CSP): mamy zmienne, ich dziedziny i ograniczenia, a szukamy przypisania, które spełnia wszystkie naraz. Kiedy dodatkowo minimalizujemy funkcję celu, dostajemy optymalizację z ograniczeniami. Tutaj ograniczenia opisują dopuszczalne grafiki, a funkcja celu to koszt.

Użyty solver CP-SAT z biblioteki OR-Tools łączy propagację ograniczeń z solverem SAT, który uczy się z konfliktów, i z elementami programowania liniowego. Status `OPTIMAL` oznacza, że solver udowodnił, że lepszego rozwiązania nie ma.

== Model matematyczny

Oznaczam przez $P$ zbiór pracowników (12), przez $Z$ zbiór zmian (9), przez $S subset.eq P$ Seniorów, przez $D = {"Pon", "Wt", "Sr"}$ dni, a przez $Z_d$ trzy zmiany dnia $d$. Zbiór $N = {("Pon_Noc", "Wt_Rano"), ("Wt_Noc", "Sr_Rano")}$ to zakazane pary "noc, potem ranek". Dane to stawka $c_p$, limit zmian $m_p$, dostępność $d_(p z) in {0,1}$ i długość zmiany $H = 8$.

Zmienna decyzyjna $x_(p z) in {0,1}$ jest równa 1, gdy pracownik $p$ pracuje na zmianie $z$. Funkcja celu:

$ min sum_(p in P) sum_(z in Z) H dot c_p dot x_(p z) $

#block(sticky: true)[
Ograniczenia:

$ x_(p z) &<= d_(p z) quad &&forall p in P, z in Z quad &&"(dostępność)" \
  sum_(p in P) x_(p z) &= 2 &&forall z in Z &&"(obsada)" \
  sum_(p in S) x_(p z) &>= 1 &&forall z in Z &&"(Senior na zmianie)" \
  sum_(z in Z) x_(p z) &<= m_p &&forall p in P &&"(limit zmian)" \
  x_(p n) + x_(p r) &<= 1 &&forall p in P, (n, r) in N &&"(rano po nocy, z zadania)" \
  sum_(z in Z_d) x_(p z) &<= 1 &&forall p in P, d in D &&"(moje założenie)" \
  sum_(z in Z) x_(p z) &>= 1 &&forall p in P &&"(opcjonalne, domyślnie wyłączone)" $
]

// ---------------- 2. Opis rozwiązania ----------------
= Opis rozwiązania

Pracowałem w Google Colab. Dane z pliku `L1_zad.csv` wczytałem biblioteką pandas, ona też służy do tabel z wynikami. Sam model zbudowałem w OR-Tools CP-SAT (`cp_model`). Kod robi kolejno: wczytuje dane, tworzy zmienne $x_(p z)$, dodaje ograniczenia, ustawia funkcję celu, uruchamia solver i wypisuje grafik. Na końcu są kontrole `assert`. Solver ma ustawiony jeden wątek i ziarno 42, żeby grafik był taki sam lokalnie i w Colabie.

#block(breakable: false)[
Poniżej najważniejsze fragmenty, skopiowane z notebooka bez zmian. Listę dziewięciu zmian buduję z listy dni i pór dnia dwiema pętlami, a godziny zmiany biorę z treści zadania:

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
]

#block(breakable: false)[
Zmienne to jedna zmienna binarna na parę (pracownik, zmiana), a jeśli ktoś jest niedostępny (0 w CSV), od razu ustawiam ją na 0:

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
]

#block(breakable: false)[
Warunek na Seniora to suma zmiennych Seniorów na zmianie, która musi być co najmniej 1. Dzięki temu dwóch Juniorów nigdy nie trafi razem na jedną zmianę:

```python
for s in zmiany:
    seniorzy_na_zmianie = []
    for p in range(liczba_pracownikow):
        if dane.loc[p, "rola"] == "Senior":
            seniorzy_na_zmianie.append(x[p, s])
    model.Add(sum(seniorzy_na_zmianie) >= 1)
```
]

#block(breakable: false)[
Zakaz zmiany porannej po nocnej zapisałem w pętli po kolejnych dniach: dla każdej osoby suma zmiennych "noc dnia i" oraz "ranek dnia i+1" nie może być większa niż 1:

```python
# rano po nocy jest zabronione
for p in range(liczba_pracownikow):
    for i in range(len(dni) - 1):
        model.Add(x[p, dni[i] + "_Noc"] + x[p, dni[i + 1] + "_Rano"] <= 1)
```
]

#block(breakable: false)[
Moje założenie o jednej zmianie dziennie wygląda tak (lista `dni` jest zdefiniowana wcześniej). Flaga pozwala je wyłączyć:

```python
zalozenie_max_1_zmiana_dziennie = True

if zalozenie_max_1_zmiana_dziennie:
    for p in range(liczba_pracownikow):
        for dzien in dni:
            model.Add(x[p, dzien + "_Rano"] + x[p, dzien + "_Popoludnie"]
                      + x[p, dzien + "_Noc"] <= 1)
```
]

#block(breakable: false)[
Drugie, opcjonalne ograniczenie (każdy dostaje co najmniej 1 zmianę) jest domyślnie wyłączone, żeby wynik był prawdziwym optimum z zadania:

```python
zalozenie_min_1_zmiana = False

if zalozenie_min_1_zmiana:
    for p in range(liczba_pracownikow):
        model.Add(sum(x[p, s] for s in zmiany) >= 1)
```
]

#block(breakable: false)[
Funkcja celu to suma stawek razy 8 godzin po wszystkich przydzielonych zmianach:

```python
koszt_calkowity = 0
for p in range(liczba_pracownikow):
    for s in zmiany:
        koszt_zmiany = dane.loc[p, "stawka_h"] * godziny_zmiany * x[p, s]
        koszt_calkowity = koszt_calkowity + koszt_zmiany

model.Minimize(koszt_calkowity)
```
]

#block(breakable: false)[
Na koniec uruchamiam solver:

```python
solver = cp_model.CpSolver()
solver.parameters.num_workers = 1
solver.parameters.random_seed = 42
status = solver.Solve(model)

print("Status:", solver.StatusName(status))
koszt = round(solver.ObjectiveValue())
print("Całkowity koszt grafiku:", f"{koszt:,}".replace(",", " "), "PLN")
```
]

Ograniczenia na obsadę (dokładnie 2 osoby) i na `max_zmian` oraz końcowe `assert` są w notebooku w osobnych komórkach i wyglądają podobnie.

// ---------------- 3. Zrzut ekranu ----------------
= Zrzut ekranu działającego programu

#figure(
  image("img/screen.png", width: 62%),
  caption: [Notebook uruchomiony w Google Colab: status solvera, koszt, grafik i liczba zmian każdego pracownika.],
) <rys-screen>

Solver zwrócił `OPTIMAL`, a koszt całkowity to 12 192 PLN. Kontrole `assert` w notebooku przeszły (wypisały „Wszystko się zgadza.”).

// ---------------- 4. Rozwiązanie końcowe ----------------
= Ostateczne rozwiązanie i komentarz

== Grafik

#block(breakable: false)[
@tab-grafik pokazuje grafik z domyślnego uruchomienia (z moim założeniem o jednej zmianie dziennie).

#figure(
  table(
    columns: (auto, 1fr, 1fr, auto),
    align: (left, left, left, right),
    [Zmiana], [Senior], [Junior], [Koszt zmiany],
    [Pon_Rano], [Rat_Wojcik (105)], [Piel_Dabrowska (68)], [1 384 PLN],
    [Pon_Popoludnie], [Piel_Kaminska (95)], [Piel_Kozlowska (65)], [1 280 PLN],
    [Pon_Noc], [Rat_Wisniewski (110)], [Rat_Jankowski (65)], [1 400 PLN],
    [Wt_Rano], [Piel_Kaminska (95)], [Piel_Dabrowska (68)], [1 304 PLN],
    [Wt_Popoludnie], [Rat_Wojcik (105)], [Piel_Kozlowska (65)], [1 360 PLN],
    [Wt_Noc], [Rat_Wisniewski (110)], [Rat_Jankowski (65)], [1 400 PLN],
    [Sr_Rano], [Piel_Kaminska (95)], [Piel_Dabrowska (68)], [1 304 PLN],
    [Sr_Popoludnie], [Rat_Wisniewski (110)], [Rat_Jankowski (65)], [1 400 PLN],
    [Sr_Noc], [Rat_Wojcik (105)], [Piel_Kozlowska (65)], [1 360 PLN],
    table.hline(),
    [*Razem*], [], [], [*12 192 PLN*],
  ),
  caption: [Optymalny grafik (w nawiasie stawka PLN/h) i koszt każdej zmiany.],
) <tab-grafik>
]

#block(breakable: false)[
@tab-prac pokazuje liczbę zmian i zarobek każdej osoby.

#figure(
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, left, right, right),
    [Pracownik], [Rola], [Liczba zmian], [Zarobek],
    [Rat_Wisniewski], [Senior], [3], [2 640 PLN],
    [Rat_Wojcik], [Senior], [3], [2 520 PLN],
    [Piel_Kaminska], [Senior], [3], [2 280 PLN],
    [Piel_Dabrowska], [Junior], [3], [1 632 PLN],
    [Piel_Kozlowska], [Junior], [3], [1 560 PLN],
    [Rat_Jankowski], [Junior], [3], [1 560 PLN],
  ),
  caption: [Pracownicy użyci w grafiku. Suma zarobków to 12 192 PLN.],
) <tab-prac>
]

== Dlaczego właśnie ci ludzie

Na każdej zmianie potrzebny jest jeden Senior i jedna dowolna druga osoba, czyli łącznie 9 miejsc Seniora i 9 miejsc drugiej osoby. Solver wziął trzech najtańszych Seniorów (95, 105 i 110 PLN/h) i trzech najtańszych Juniorów (65, 65 i 68 PLN/h), każdego na maksymalne 3 zmiany. Koszt wychodzi $8 dot (3 dot (95+105+110) + 3 dot (65+65+68)) = 8 dot 1thin 524 = 12thin 192$ PLN. Taki sam wynik dostałem z ręcznego liczenia dolnego ograniczenia, więc rozwiązanie jest optymalne.

Sześć osób nie dostało żadnej zmiany: Dr_Kowalski, Dr_Nowakowska, Piel_Lewandowska, Piel_Zielinska, Rat_Szymanski i Rat_Wozniak. To nie błąd modelu. W oknie trzech dni jest tylko 18 miejsc (9 zmian po 2 osoby), a sześć najtańszych osób z limitem 3 zmian pokrywa je wszystkie. Każde zatrudnienie droższej osoby podniosłoby koszt, a funkcja celu nie ma żadnej nagrody za równy podział pracy. Dwaj najdrożsi lekarze (140 i 135 PLN/h) mogliby mieć kompetencje, których model nie opisuje, ale na podstawie danych z zadania nie ma powodu ich zatrudniać.

Wiąże głównie limit `max_zmian`, bo najtańsze osoby są obciążone do maksimum. Dostępność i zakaz rano po nocy decydują o tym, kto pracuje na której zmianie (stąd różne koszty zmian w #ref(<tab-grafik>, supplement: [Tabeli])), ale nie podnoszą kosztu ponad dolne ograniczenie.

== Wpływ moich założeń <wariant>

#block(breakable: false)[
Ten sam model rozwiązałem w trzech wariantach, a wyniki są w #ref(<tab-wariant>, supplement: [Tabeli]). Warianty różnią się wartością dwóch flag: \
`zalozenie_max_1_zmiana_dziennie` i `zalozenie_min_1_zmiana`.

#figure(
  table(
    columns: (2fr, auto, auto, auto, auto),
    align: (left, left, right, right, right),
    [Wariant], [Status], [Koszt], [Pracujących], [Różnica],
    [bez założeń (tylko wymagania z zadania)], [OPTIMAL], [12 192 PLN], [6], [0],
    [z założeniem "maks. 1 zmiana dziennie" (domyślny)], [OPTIMAL], [12 192 PLN], [6], [0],
    [dodatkowo "co najmniej 1 zmiana" (opcjonalne)], [OPTIMAL], [12 824 PLN], [12], [+632 PLN (+5,2%)],
  ),
  caption: [Koszt grafiku w trzech wariantach. Różnica jest liczona względem optimum 12 192 PLN.],
) <tab-wariant>
]

Założenie o jednej zmianie dziennie nic nie kosztuje, bo dolne ograniczenie 12 192 PLN da się osiągnąć w obu wariantach. Zmienia się tylko jakość grafiku. Sprawdziłem to, przełączając flagę i uruchamiając ten sam notebook jeszcze raz (OR-Tools 9.15.6755). W grafiku bez założenia Rat_Wojcik pracuje w poniedziałek na zmianie porannej i nocnej (Pon_Rano i Pon_Noc), a Piel_Kaminska w środę na porannej i nocnej (Sr_Rano i Sr_Noc). Nikt inny nie ma dwóch zmian w jednym dniu. To tylko 8 godzin przerwy, choć po nocy zadanie wymaga 11. W grafiku z #ref(<tab-grafik>, supplement: [Tabeli]) każdy pracuje najwyżej raz dziennie, więc tego problemu nie ma, a koszt jest ten sam.

Wymuszenie pracy dla wszystkich 12 osób dałoby sprawiedliwszy podział, ale kosztuje 632 PLN więcej (+5,2%), bo zmiany trafiają też do najdroższych osób (Dr_Kowalski i Dr_Nowakowska dostają po jednej). Zadanie wymaga najtańszego grafiku, więc tę opcję zostawiłem wyłączoną, a @tab-grafik i zrzut ekranu pokazują wynik bez niej.
