#!/usr/bin/env python3
"""
NumPy doğrulama betiği — Faz 4 başarı kriteri.
Rastgele 3 matris çifti üretir, Verilog simülasyonu ile karşılaştırır.
Kullanım: python3 scripts/check.py  (proje kökünden çalıştırılır)
"""
import numpy as np
import subprocess
import tempfile
import os
import sys

N         = 4
NUM_TESTS = 3
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RTL_DIR    = os.path.join(SCRIPT_DIR, "..", "rtl")
ARRAY_V    = os.path.join(RTL_DIR, "systolic_array.v")
PE_V       = os.path.join(RTL_DIR, "pe.v")

# Geçici testbench şablonu — {INIT} yerine matris atamaları gelir
TB_TEMPLATE = """\
`timescale 1ns/1ps
module tb_check;
    parameter N          = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;

    reg                      clk, rst;
    reg  [N*DATA_WIDTH-1:0]  a_in;
    reg  [N*DATA_WIDTH-1:0]  b_in;
    wire [N*N*ACC_WIDTH-1:0] c_out;

    systolic_array #(.N(N),.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk),.rst(rst),.a_in(a_in),.b_in(b_in),.c_out(c_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    reg [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    reg [DATA_WIDTH-1:0] B [0:N-1][0:N-1];
    integer i, j, t;

    initial begin
{INIT}
        rst = 1; a_in = 0; b_in = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        for (t = 0; t < 2*N-1; t = t + 1) begin
            a_in = 0; b_in = 0;
            for (i = 0; i < N; i = i + 1)
                if (t >= i && (t - i) < N)
                    a_in[i*DATA_WIDTH +: DATA_WIDTH] = A[i][t-i];
            for (j = 0; j < N; j = j + 1)
                if (t >= j && (t - j) < N)
                    b_in[j*DATA_WIDTH +: DATA_WIDTH] = B[t-j][j];
            @(posedge clk); #1;
        end

        a_in = 0; b_in = 0;
        repeat (N + 1) @(posedge clk);
        #1;

        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1)
                $display("C[%0d][%0d]=%0d", i, j, c_out[(i*N+j)*ACC_WIDTH +: ACC_WIDTH]);

        $finish;
    end
endmodule
"""


def matrix_to_verilog(name, mat):
    """NumPy matrisini Verilog initial atama satırlarına çevirir."""
    lines = []
    for i in range(N):
        for j in range(N):
            lines.append(f"        {name}[{i}][{j}] = 8'd{int(mat[i, j])};")
    return "\n".join(lines)


def run_sim(A, B):
    """Geçici testbench oluşturur, derler ve çalıştırır; stdout döndürür."""
    init = matrix_to_verilog("A", A) + "\n" + matrix_to_verilog("B", B)
    tb_src = TB_TEMPLATE.replace("{INIT}", init)

    with tempfile.TemporaryDirectory() as tmpdir:
        tb_path  = os.path.join(tmpdir, "tb_check.v")
        vvp_path = os.path.join(tmpdir, "tb_check.vvp")

        with open(tb_path, "w") as f:
            f.write(tb_src)

        r = subprocess.run(
            ["iverilog", "-o", vvp_path, tb_path, ARRAY_V, PE_V],
            capture_output=True, text=True
        )
        if r.returncode != 0:
            raise RuntimeError(f"iverilog hatası:\n{r.stderr}")

        r = subprocess.run(["vvp", vvp_path], capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError(f"vvp hatası:\n{r.stderr}")

        return r.stdout


def parse_output(stdout):
    """'C[i][j]=val' satırlarından 4×4 int64 dizisi üretir."""
    C = np.zeros((N, N), dtype=np.int64)
    for line in stdout.splitlines():
        if line.startswith("C["):
            ij, val = line.split("=")
            i = int(ij[2])
            j = int(ij[5])
            C[i, j] = int(val)
    return C


def main():
    np.random.seed(42)
    passes = 0

    for trial in range(1, NUM_TESTS + 1):
        A = np.random.randint(0, 256, (N, N), dtype=np.uint8)
        B = np.random.randint(0, 256, (N, N), dtype=np.uint8)
        C_ref = A.astype(np.int64) @ B.astype(np.int64)

        try:
            stdout  = run_sim(A, B)
            C_sim   = parse_output(stdout)
        except RuntimeError as e:
            print(f"Test {trial}/{NUM_TESTS}: SIM HATASI — {e}")
            continue

        if np.array_equal(C_sim, C_ref):
            print(f"Test {trial}/{NUM_TESTS}: PASS")
            passes += 1
        else:
            print(f"Test {trial}/{NUM_TESTS}: FAIL")
            for i in range(N):
                for j in range(N):
                    if C_sim[i, j] != C_ref[i, j]:
                        print(f"  C[{i}][{j}]: sim={C_sim[i,j]}  numpy={C_ref[i,j]}")

    print()
    if passes == NUM_TESTS:
        print(f"PASS: {passes}/{NUM_TESTS} test NumPy ile tam uyumlu")
    else:
        print(f"FAIL: {passes}/{NUM_TESTS} test gecti")
    sys.exit(0 if passes == NUM_TESTS else 1)


if __name__ == "__main__":
    main()
