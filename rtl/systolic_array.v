`timescale 1ns/1ps

module systolic_array #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                     clk,
    input  wire                     rst,
    // A satırları: soldan girer, [row*DATA_WIDTH +: DATA_WIDTH]
    input  wire [N*DATA_WIDTH-1:0]  a_in,
    // B sütunları: üstten girer, [col*DATA_WIDTH +: DATA_WIDTH]
    input  wire [N*DATA_WIDTH-1:0]  b_in,
    // C çıktıları: [(row*N+col)*ACC_WIDTH +: ACC_WIDTH]
    output wire [N*N*ACC_WIDTH-1:0] c_out
);

    // Yatay tel: a_h[row][0] = sol kenar girişi, a_h[row][1..N] = PE çıkışları
    wire [DATA_WIDTH-1:0] a_h [0:N-1][0:N];
    // Dikey tel: b_v[0][col] = üst kenar girişi, b_v[1..N][col] = PE çıkışları
    wire [DATA_WIDTH-1:0] b_v [0:N][0:N-1];

    genvar r, c;

    // Dış a_in → sol kenar
    generate
        for (r = 0; r < N; r = r + 1) begin : conn_a
            assign a_h[r][0] = a_in[r*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    // Dış b_in → üst kenar
    generate
        for (c = 0; c < N; c = c + 1) begin : conn_b
            assign b_v[0][c] = b_in[c*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    // 4x4 PE ızgarası
    generate
        for (r = 0; r < N; r = r + 1) begin : row_gen
            for (c = 0; c < N; c = c + 1) begin : col_gen
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) pe_inst (
                    .clk    (clk),
                    .rst    (rst),
                    .a_in   (a_h[r][c]),
                    .a_out  (a_h[r][c+1]),
                    .b_in   (b_v[r][c]),
                    .b_out  (b_v[r+1][c]),
                    .acc_out(c_out[(r*N+c)*ACC_WIDTH +: ACC_WIDTH])
                );
            end
        end
    endgenerate

endmodule
