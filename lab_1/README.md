# Ćwiczenie 1 – grafik zmian na SOR

Polecenia wykonuj z głównego folderu repozytorium (`uv` korzysta ze wspólnego projektu).

```bash
# 1. zależności (jednorazowo)
uv sync

# 2. uruchomienie notebooka z zapisem wyników
uv run jupyter nbconvert --to notebook --execute --inplace lab_1/rozwiazanie.ipynb

# 3. sprawozdanie PDF
cd lab_1
typst compile sprawozdanie.typ 2026_2_S_Rybak_1_S.pdf
```

- Kod:  `2026_2_S_Rybak_1_K.ipynb`
- Dane: `L1_zad.csv` (w Google Colab wgraj ten plik najpierw do środowiska).
- Zrzut ekranu w raporcie: `img/screen.png` 
- Do oddania: `2026_2_S_Rybak_1_K.ipynb` i `2026_2_S_Rybak_1_S.pdf` (ZIP `2026_2_S_Rybak_1.zip`).
