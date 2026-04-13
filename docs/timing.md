# Simülasyon Zamanlama Analizi — tb_array.v

## Saat Parametresi

```
always #5 clk = ~clk  →  T = 10 ns  (50 MHz)
```

---

## Çevrim Tablosu (1-indeksli, mutlak kenar sayısı)

| Çevrim | Zaman | Olay |
|--------|-------|------|
| 1 | 5 ns | Reset yakalanır (rst=1) |
| 2 | 15 ns | Reset yakalanır; `rst=0` serbest bırakılır |
| 3 | 25 ns | Besleme t=0 — PE[0][0] 1. MAC |
| 4 | 35 ns | Besleme t=1 |
| 5 | 45 ns | Besleme t=2 |
| **6** | **55 ns** | Besleme t=3 — **PE[0][0] son (4.) MAC** |
| 7 | 65 ns | Besleme t=4 |
| 8 | 75 ns | Besleme t=5 |
| 9 | 85 ns | Besleme t=6 (son besleme, 2N−1=7 adım tamam) |
| 10 | 95 ns | Boşaltma 1/5 |
| 11 | 105 ns | Boşaltma 2/5 |
| **12** | **115 ns** | Boşaltma 3/5 — **PE[3][3] son (4.) MAC** |
| 13 | 125 ns | Boşaltma 4/5 |
| 14 | 135 ns | Boşaltma 5/5 (`repeat(N+1)` tamamlandı) |
| — | **136 ns** | `#1` → `$display` / `$finish` |

---

## Sorular ve Yanıtlar

**İlk sonuç kaçıncı çevrimde çıkıyor?**
PE[0][0] → **çevrim 6** (t = 55 ns).

**PE[3][3] (son sonuç) kaçıncı çevrimde tamamlanıyor?**
→ **çevrim 12** (t = 115 ns).
Besleme fazının bitiminden 3 boşaltma çevrimi sonrasına denk gelir.
`repeat(N+1) = 5` boşaltma çevrimi, burada 2 çevrimlik güvenlik marjı bırakır.

**Toplam simülasyon kaç ns sürdü?**
→ **136 ns**
Son posedge çevrim 14 (t=135 ns) + 1 ns okuma gecikmesi, ardından `$finish`.

---

## PE[r][c] Formülü

Her PE'nin ızgaradaki konumuna göre zamanlama:

```
İlk MAC çevrimi : r + c + 3
Son  MAC çevrimi : r + c + 6   (= r + c + N + 2, N=4 için)
```

| PE | r+c | İlk MAC | Son MAC | Zaman |
|----|-----|---------|---------|-------|
| [0][0] | 0 | 3 | **6** | 55 ns |
| [0][3] | 3 | 6 | 9 | 85 ns |
| [3][0] | 3 | 6 | 9 | 85 ns |
| [3][3] | 6 | 9 | **12** | 115 ns |

---

## Faz Özeti

| Faz | Çevrim sayısı | Formül |
|-----|--------------|--------|
| Reset | 2 | sabit |
| Besleme (skewed input) | 7 | 2N−1 |
| Boşaltma (drain) | 5 | N+1 |
| **Toplam** | **14** | |

Tüm çıktılar çevrim 12'den sonra sabittir; testbench çevrim 14'te okur.

---

## Skew Mantığı

Testbench veriyi köşegen köşegen kaydırarak besler:

```
Besleme adımı t, satır i için: A[i][t-i]   (t >= i ve t-i < N koşuluyla)
Besleme adımı t, sütun j için: B[t-j][j]   (t >= j ve t-j < N koşuluyla)
```

Böylece A[r][k] ve B[k][c] her zaman aynı anda PE[r][c]'ye ulaşır (her ikisi de
besleme adımı `r + c + k`'da). Systolic array'in temel invariantı budur.
