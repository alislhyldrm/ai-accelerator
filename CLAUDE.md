# AI Accelerator — Claude Code Kılavuzu

## Proje Özeti

4×4 Sistolic Array YZ Hızlandırıcısı. Matris çarpımını (A×B=C) donanımda
paralel yapan Verilog-2005 tasarımı. Google TPU'nun temel prensibini taklit eder.

Her Processing Element (PE):
- a_in × b_in çarpımını 32-bit akümülatöre ekler (MAC)
- a_in değerini sağa (a_out), b_in değerini aşağıya (b_out) iletir
- Veriler dalga gibi yayılır — tüm PE'ler aynı anda çalışır

---

## Araç Zinciri

| Araç        | Sürüm   | Amaç                          |
|-------------|---------|-------------------------------|
| iverilog    | 12.0    | Verilog simülasyonu           |
| vvp         | 12.0    | Simülasyon çalıştırma         |
| Python      | 3.x     | NumPy doğrulaması             |
| NumPy       | latest  | Altın referans (ground truth) |
| Vivado      | 2025.2  | FPGA sentezi (Faz 5)          |
| Hedef FPGA  | Basys3  | Xilinx Artix-7                |

Dil standardı: **Verilog-2005** (SystemVerilog kullanma)

---

## Dizin Yapısı
ai-accelerator/
├── CLAUDE.md
├── .gitignore
├── rtl/
│   ├── pe.v
│   ├── systolic_array.v
│   └── top.v
├── sim/
│   ├── tb_pe.v
│   └── tb_array.v
├── scripts/
│   ├── check.py
│   └── gen_stimulus.py
├── constraints/
└── docs/---

## Karpathy İlkeleri — Claude Code Davranış Kuralları

Bu kurallar Claude Code'un bu projede nasıl davranacağını belirler.
Karpathy'nin LLM kodlama tuzakları üzerine gözlemlerinden türetilmiştir.

### 1. Kodlamadan Önce Düşün

**Varsayım yapma. Belirsizliği gizleme. Alternatifleri sun.**

- Belirsizlik varsa sessizce bir yorum seçme — sor
- Birden fazla yaklaşım varsa tradeoff'ları açıkça sun
- Daha basit bir yol varsa bunu söyle, doğrudan uygulamaya geçme
- Kafan karışırsa dur, ne anlamadığını isim vererek açıkla

### 2. Önce Basitlik

**Problemi çözen minimum kod. Spekülatif hiçbir şey ekleme.**

- İstenmediği sürece ek özellik ekleme
- Tek kullanımlık kod için soyutlama oluşturma
- "Esneklik" veya "yapılandırılabilirlik" istenmedi ise ekleme
- 200 satırla yapılabiliyorsa 50'de yap

Test: Kıdemli bir mühendis bunu aşırı karmaşık bulur mu? Evet → basitleştir.

### 3. Cerrahi Değişiklik

**Sadece dokunman gereken şeye dokun. Kendi bıraktığın pisliği temizle.**

Mevcut kodu düzenlerken:
- İlgisiz kodu, yorumları veya formatlamayı "iyileştirme"
- Bozulmayan şeyleri refactor etme
- Mevcut stili koru, farklı yapardın diye değiştirme
- İlgisiz ölü kod fark edersen söyle — silme

Değişikliklerin artık kullanılmayan import/değişken/fonksiyon bırakırsa:
- Bunları SEN temizle
- Önceden var olan ölü koda dokunma

Test: Her değiştirilen satır doğrudan kullanıcının isteğiyle izlenebilmeli.

### 4. Hedefe Yönelik Çalışma

**Başarı kriterini tanımla. Doğrulanana kadar döngü.**

Zorunlu çalışma şekli — her görev için:
| Bunun yerine...       | Bunu kullan...                                  |
|-----------------------|-------------------------------------------------|
| "Validasyon ekle"     | "Geçersiz giriş testlerini yaz, sonra geçir"   |
| "Bug'ı düzelt"        | "Reproducing test yaz, sonra geçir"            |
| "X'i refactor et"     | "Önce testler PASS, sonra değiştir, sonra PASS" |

Karpathy'nin kilit içgörüsü: LLM'ler belirli hedefleri karşılayana kadar
döngü kurmakta son derece iyidir. Ne yapacağını söyleme — başarı kriterini
ver ve bırak gitsin.

---

## Verilog Kodlama Standartları

### Zorunlu Kurallar

`timescale 1ns/1ps   // Her dosyanın başında — istisnasız

// Non-blocking assignment: flip-flop'larda ZORUNLU
always @(posedge clk) begin
    acc <= acc + product;  // <= kullan
end

// Blocking assignment: sadece combinational logic'te
always @(*) begin
    product = a_in * b_in;  // = kullan
end`

### Yasak Uygulamalar

- Magic number kullanma → `parameter` kullan
- Aynı always bloğunda blocking + non-blocking karıştırma
- Eksik sensitivity list (latch riski) → her zaman `@(*)` kullan
- Port isimlerinde tutarsızlık → standart: `a_in`, `a_out`, `acc_out`

---

## Mimari Kararlar (Değiştirme)

| Karar                | Değer     | Gerekçe                               |
|----------------------|-----------|---------------------------------------|
| Giriş veri genişliği | 8 bit     | Basitlik, FPGA LUT optimizasyonu      |
| Akümülatör genişliği | 32 bit    | Overflow önlemi                       |
| Saat                 | Tek clock | Senkron tasarım                       |
| Reset                | Active-high senkron | Xilinx standardı             |
| Pipeline             | 1 çevrim/adım | Dalga modeli                      |

---

## Test Komutları

```bash
# PE testi
iverilog -o sim/tb_pe.vvp sim/tb_pe.v rtl/pe.v && vvp sim/tb_pe.vvp

# Array testi
iverilog -o sim/tb_array.vvp sim/tb_array.v rtl/systolic_array.v rtl/pe.v \
  && vvp sim/tb_array.vvp

# NumPy doğrulaması (ZORUNLU — simülatör PASS olsa bile çalıştır)
python3 scripts/check.py
```

---

## Başarı Kriterleri

| Faz | Kriter |
|-----|--------|
| 2 — PE | 3/3 test PASS, overflow davranışı belgelenmiş |
| 3 — Array | Kimlik matrisi testi PASS |
| 4 — Doğrulama | 10 rastgele matris → NumPy %100 eşleşme |
| 5 — FPGA | Timing constraint karşılanmış, Basys3'e yüklenmiş |

---

## Commit Formatı
