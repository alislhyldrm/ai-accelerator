# AI Accelerator — 4×4 Systolic Array Matrix Multiplier

![Simulation](https://img.shields.io/badge/simulation-PASS%2016%2F16-brightgreen)
![Tests](https://img.shields.io/badge/tests-all%20phases%20PASS-brightgreen)
![NumPy](https://img.shields.io/badge/NumPy%20verification-13%2F13-brightgreen)
![Language](https://img.shields.io/badge/language-Verilog--2005-blue)
![FPGA](https://img.shields.io/badge/target-Nexys%204%20DDR%20%7C%20Artix--7-blueviolet)

---

A fully verified, FPGA-ready hardware matrix multiplier inspired by Google's TPU. It executes 4×4 integer MAC operations in a systolic array pipeline — 16 processing elements running in parallel, results validated cycle-accurately against NumPy ground truth.

---

## Architecture

### How the Systolic Array Works

Data flows through a grid of Processing Elements (PEs) like a wave. Matrix A enters from the left, matrix B from the top. Every PE performs one multiply-accumulate (MAC) per clock cycle and passes its operands to its right and bottom neighbors. No PE ever waits — the pipeline is always full.

```
         b[0]↓    b[1]↓    b[2]↓    b[3]↓
          |        |        |        |
a[0] → [PE 0,0]→[PE 0,1]→[PE 0,2]→[PE 0,3]
          ↓        ↓        ↓        ↓
a[1] → [PE 1,0]→[PE 1,1]→[PE 1,2]→[PE 1,3]
          ↓        ↓        ↓        ↓
a[2] → [PE 2,0]→[PE 2,1]→[PE 2,2]→[PE 2,3]
          ↓        ↓        ↓        ↓
a[3] → [PE 3,0]→[PE 3,1]→[PE 3,2]→[PE 3,3]
```

Each PE computes one element of the result matrix C:

```
C[r][c] = Σ A[r][k] × B[k][c]   for k = 0..3
```

Inputs are **skew-fed** — row `i` of A is delayed by `i` cycles, column `j` of B by `j` cycles — so operands that belong together arrive at the same PE at the same time. This is the fundamental insight behind the TPU-inspired systolic architecture.

### Processing Element (PE)

```verilog
always @(posedge clk) begin
    if (rst) begin
        a_out   <= 0;
        b_out   <= 0;
        acc_out <= 0;
    end else begin
        a_out   <= a_in;                    // pass A rightward
        b_out   <= b_in;                    // pass B downward
        acc_out <= acc_out + (a_in * b_in); // MAC accumulate
    end
end
```

8-bit inputs, 32-bit accumulator. One cycle latency per PE. Zero stall cycles.

---

## Features

| Decision | Value | Rationale |
|---|---|---|
| Array size | 4×4 (16 PEs) | Fits comfortably on Artix-7; demonstrates full MAC pipeline |
| Input width | 8-bit | Matches uint8 neural network activations; fits FPGA LUTs efficiently |
| Accumulator | 32-bit | Overflow-safe for 4 accumulation steps: max = 4 × 255² = 260,100 ≪ 2³² |
| Reset | Active-high synchronous | Xilinx recommended; avoids async reset timing violations |
| Skew logic | External (`input_seq`) | Array stays generic; any N×N matrix pair can be fed without RTL change |
| Drain counter | DRAIN = N−1 = 3 FFs | Exact pipeline depth; no over-waiting, no premature latch |
| Result display | 16:1 mux + btnR/L nav | Browse all 16 C[r][c] results on 4-digit 7-segment with a single button |

---

## File Structure

```
ai-accelerator/
├── rtl/
│   ├── pe.v              # Processing Element — MAC core
│   ├── systolic_array.v  # 4×4 PE grid via generate
│   └── top.v             # FPGA top — clk_div, btn_sync, input_seq, seg7_drv
├── sim/
│   ├── tb_pe.v           # PE unit tests (8 checks)
│   ├── tb_array.v        # Identity matrix test (16 elements)
│   └── tb_top.v          # Full system test (16 checks)
├── scripts/
│   ├── check.py          # NumPy ground-truth verifier (13 test cases)
│   └── gen_stimulus.py   # Stimulus generator
├── constraints/
│   ├── basys3.xdc        # Basys3 / Artix-7 35T pin constraints
│   └── nexys4ddr.xdc     # Nexys 4 DDR / Artix-7 100T pin constraints
└── CLAUDE.md
```

---

## Getting Started

### Prerequisites

```bash
# Verilog simulator
sudo apt install iverilog   # Ubuntu/Debian
# or: brew install icarus-verilog  (macOS)

# Python verification
pip install numpy
```

### Run All Simulations

```bash
# 1 — PE unit test
iverilog -o sim/tb_pe.vvp sim/tb_pe.v rtl/pe.v && vvp sim/tb_pe.vvp

# 2 — Array integration test
iverilog -o sim/tb_array.vvp sim/tb_array.v rtl/systolic_array.v rtl/pe.v \
  && vvp sim/tb_array.vvp

# 3 — Full system test (top module)
iverilog -o sim/tb_top.vvp sim/tb_top.v \
  rtl/top.v rtl/systolic_array.v rtl/pe.v \
  && vvp sim/tb_top.vvp

# 4 — NumPy ground-truth verification (run from project root)
python3 scripts/check.py
```

### Expected Output

```
# PE test
PASS [T1] acc_out=12
PASS [T2] acc_out=42
PASS [T3] acc_out=0
...
Sonuc: 8 PASS, 0 FAIL

# Array test
PASS: kimlik matrisi I*I=I — 16/16 eleman dogru

# System test
PASS [T1] got=00000001   ← done_flag
PASS [T2] got=00000000   ← sel_reg=0
...
Sonuc: 16 PASS, 0 FAIL

# NumPy verification
Test 01/13: PASS
...
PASS: 13/13 test NumPy ile tam uyumlu
```

---

## Test Results

| Phase | Module | Tests | Result | Description |
|---|---|---|---|---|
| 2 — PE | `pe.v` | 8 | **PASS** | MAC, accumulation, reset, 4-cycle overflow boundary |
| 3 — Array | `systolic_array.v` | 16 | **PASS** | Identity matrix I×I=I, all 16 elements verified |
| 4 — Verification | `check.py` | 13 | **PASS** | 10 random + zero matrix + all-255 + I×random vs NumPy |
| 5 — System | `top.v` | 16 | **PASS** | done_flag, sel_reg nav, wrap-around, show_upper, dp toggle |
| **Total** | | **53** | **53 / 53 PASS** | |

---

## Timing Analysis

### Pipeline Latency

| Stage | Cycles | Description |
|---|---|---|
| Reset synchronizer (2-FF) | 2 | btnC → synchronous rst edge detection |
| Skewed feed (2N−1) | 7 | All rows/columns interleaved and fed into array |
| Drain (N−1) | 3 | PE[N−1][N−1] finishes last accumulation |
| Latch | 2 | seq_done → shift register → c_out captured |
| **Total** | **14** | **136 ns @ 100 MHz** |

### PE Completion Formula

Element `C[r][c]` receives its final accumulation at clock cycle:

```
cycle_done(r, c) = r + c + (N − 1)
```

For a 4×4 array (N=4):

| PE | r + c + 3 | Cycle |
|---|---|---|
| C[0][0] | 0+0+3 | 3 |
| C[1][1] | 1+1+3 | 5 |
| C[2][2] | 2+2+3 | 7 |
| C[3][3] | 3+3+3 | **9** ← last |

The drain counter waits exactly `N−1 = 3` cycles after `seq_done` to ensure PE[3][3] has committed its final result before the output latch fires.

---

## FPGA Deployment

### Target Board: Nexys 4 DDR (Artix-7 100T)

| Signal | Pin | Function |
|---|---|---|
| `clk` | E3 | 100 MHz system clock |
| `btnC` | N17 | Synchronous reset |
| `btnR` / `btnL` | M17 / P17 | Navigate PE results (sel_reg ±1) |
| `btnU` | M18 | Toggle upper/lower 16-bit display |
| `sw[1:0]` | L16 / J15 | Preset matrix selector (4 built-in pairs) |
| `seg[6:0]` | T10…L18 | 7-segment cathodes (active-low) |
| `an[3:0]` | J17…J14 | 4-digit anode select (active-low) |
| `led[3:0]` | N14…H17 | Current PE index |
| `led[15]` | V11 | Computation done flag |

> Basys3 users: swap `nexys4ddr.xdc` with `constraints/basys3.xdc` and target `xc7a35tcpg236-1`.

### Vivado Steps

```
1. New Project → RTL Project
   Part: xc7a100tcsg324-1  (Nexys 4 DDR)

2. Add Sources:
   rtl/pe.v  rtl/systolic_array.v  rtl/top.v
   rtl/clk_div.v  rtl/btn_sync.v
   rtl/input_seq.v  rtl/seg7_drv.v

3. Add Constraints:
   constraints/nexys4ddr.xdc

4. Run Synthesis → Run Implementation → Generate Bitstream

5. Open Hardware Manager → Program Device
```

### How to Use on Hardware

```
1. Press btnC (~100 ms hold) → releases reset → computation starts automatically
2. Wait for LED[15] to turn ON — matrix multiplication complete (~140 cycles)
3. SW[1:0] selects the preset matrix pair (4 presets available)
4. btnR / btnL scrolls through C[0][0]…C[3][3] on the 7-segment display
5. btnU toggles between lower 16 bits and upper 16 bits of the selected element
   Decimal point ON = currently showing upper 16 bits
```

---

## Tool Chain

| Tool | Version | Purpose |
|---|---|---|
| Icarus Verilog (`iverilog`) | 12.0 | Verilog-2005 simulation |
| VVP runtime (`vvp`) | 12.0 | Simulation execution |
| Python | 3.x | Test orchestration |
| NumPy | latest | Ground-truth matrix multiplication reference |
| Vivado | 2025.2 | FPGA synthesis, place-and-route, bitstream generation |

---

## Roadmap

| Milestone | Description |
|---|---|
| UART readout | Stream the full C matrix over serial — no button navigation needed |
| Larger arrays | Parameterize N; target 8×8 or 16×16 on higher-density FPGAs |
| Multi-clock domains | Separate compute and I/O clocks with CDC handshaking |
| INT16 / FP16 support | Widen data path for higher-precision inference workloads |
| AXI-Lite interface | Drop-in integration as an accelerator IP core in a SoC |
