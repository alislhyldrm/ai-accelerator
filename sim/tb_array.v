`timescale 1ns/1ps

// Kimlik matrisi testi: I × I = I
// Skew testbench yönetir — systolic_array skew bilmez.
//
// Zamanlama özeti (N=4):
//   - 2*N-1 = 7 çevrim: kaydırılmış giriş beslenir (t=0..6)
//   - N+1   = 5 çevrim: boru hattı boşaltması (en geç PE[3][3] için)
//   - C[i][j] son kez çevrim (i+j+N-1)'de güncellenir; maks = 9
module tb_array;

    parameter N          = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;

    reg                     clk, rst;
    reg  [N*DATA_WIDTH-1:0] a_in;
    reg  [N*DATA_WIDTH-1:0] b_in;
    wire [N*N*ACC_WIDTH-1:0] c_out;

    systolic_array #(
        .N         (N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) dut (
        .clk  (clk),
        .rst  (rst),
        .a_in (a_in),
        .b_in (b_in),
        .c_out(c_out)
    );

    // 10 ns döngü (50 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Kimlik matrisleri
    reg [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    reg [DATA_WIDTH-1:0] B [0:N-1][0:N-1];

    integer i, j, t;
    integer errors;

    initial begin
        // A = B = I
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                A[i][j] = (i == j) ? 8'd1 : 8'd0;
                B[i][j] = (i == j) ? 8'd1 : 8'd0;
            end

        // Senkron reset (2 çevrim)
        rst = 1; a_in = 0; b_in = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // Kaydırılmış (skewed) giriş besleme
        // Çevrim t: satır i için A[i][t-i], sütun j için B[t-j][j]
        for (t = 0; t < 2*N-1; t = t + 1) begin
            a_in = 0;
            b_in = 0;
            for (i = 0; i < N; i = i + 1)
                if (t >= i && (t - i) < N)
                    a_in[i*DATA_WIDTH +: DATA_WIDTH] = A[i][t-i];
            for (j = 0; j < N; j = j + 1)
                if (t >= j && (t - j) < N)
                    b_in[j*DATA_WIDTH +: DATA_WIDTH] = B[t-j][j];
            @(posedge clk); #1;
        end

        // Girişleri sıfırla, boru hattının bitmesini bekle
        a_in = 0; b_in = 0;
        repeat (N + 1) @(posedge clk);
        #1;

        // Sonuçları doğrula: I*I = I
        errors = 0;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                if (c_out[(i*N+j)*ACC_WIDTH +: ACC_WIDTH] !==
                        ((i == j) ? 32'd1 : 32'd0)) begin
                    $display("FAIL C[%0d][%0d]: beklenen=%0d alınan=%0d",
                             i, j,
                             (i == j) ? 32'd1 : 32'd0,
                             c_out[(i*N+j)*ACC_WIDTH +: ACC_WIDTH]);
                    errors = errors + 1;
                end
            end

        if (errors == 0)
            $display("PASS: kimlik matrisi I*I=I — 16/16 eleman dogru");
        else
            $display("FAIL: %0d/16 hata", errors);

        $finish;
    end

endmodule
