`timescale 1ns/1ps

// input_seq: Preset matris çiftini sistolic array'e skewed (dalgalanmalı) olarak besler.
//
// Besleme şeması — 4×4 matris için 7 çevrim:
//   a_in[r*8+:8] = A[r][t-r]   satır r,  t ∈ [r, r+3]
//   b_in[c*8+:8] = B[t-c][c]   sütun c,  t ∈ [c, c+3]
//
// Matris depolama (row-major düz 128-bit):
//   mat[(r*4+c)*8+:8] = M[r][c]  →  bit[127:120]=M[3][3], bit[7:0]=M[0][0]
//
// Preset seçimi (sw[1:0]):
//   0 → A=I4, B=I4                              → C=I4
//   1 → A=[[1,2,3,4],[5,6,7,8],[1,2,3,4],[5,6,7,8]], B=I4  → C=A
//   2 → A=[[1,1,2,3],[5,8,13,21],[1,2,3,5],[8,13,21,34]], B=I4  → C=A (Fibonacci)
//   3 → A=[[1,1,1,1],[2,2,2,2],[3,3,3,3],[4,4,4,4]],
//          B=[[1,2,3,4],[1,2,3,4],[1,2,3,4],[1,2,3,4]]
//
// FSM: IDLE → LOAD (7 çevrim) → DONE → IDLE
//   done: LOAD bittikten 1 çevrim sonra 1-çevrimlik pulse
module input_seq (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,    // 1-çevrimlik başlatma darbesi (btn_sync'ten)
    input  wire [1:0]  sw,       // preset seçici
    output reg  [31:0] a_in,     // a_in[r*8+:8] = satır r verisi
    output reg  [31:0] b_in,     // b_in[c*8+:8] = sütun c verisi
    output reg         done      // tüm veri beslendi, 1-çevrimlik pulse
);

    // -----------------------------------------------------------------
    // FSM durum kodları
    // -----------------------------------------------------------------
    localparam IDLE = 2'd0;
    localparam LOAD = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state;
    reg [2:0] cycle;  // 0-6: 7 besleme çevrimi

    // -----------------------------------------------------------------
    // Preset matrisler (localparam)
    //   mat[(r*4+c)*8+:8] = M[r][c]
    //   128-bit hex gösterimi: bit[127:96]=M[3][3:0], bit[95:64]=M[2][3:0],
    //                          bit[63:32]=M[1][3:0], bit[31:0]=M[0][3:0]
    //   Her 32-bit grup: {M[r][3], M[r][2], M[r][1], M[r][0]} sırasıyla
    // -----------------------------------------------------------------

    // Preset 0: A=I4, B=I4
    localparam [127:0] A0 = 128'h01000000_00010000_00000100_00000001;
    localparam [127:0] B0 = 128'h01000000_00010000_00000100_00000001;

    // Preset 1: A=[[1,2,3,4],[5,6,7,8],[1,2,3,4],[5,6,7,8]], B=I4
    localparam [127:0] A1 = 128'h08070605_04030201_08070605_04030201;
    localparam [127:0] B1 = 128'h01000000_00010000_00000100_00000001;

    // Preset 2: A=[[1,1,2,3],[5,8,13,21],[1,2,3,5],[8,13,21,34]], B=I4
    //   13=0x0D, 21=0x15, 34=0x22
    localparam [127:0] A2 = 128'h22150D08_05030201_150D0805_03020101;
    localparam [127:0] B2 = 128'h01000000_00010000_00000100_00000001;

    // Preset 3: A=[[1,1,1,1],[2,2,2,2],[3,3,3,3],[4,4,4,4]]
    //           B=[[1,2,3,4],[1,2,3,4],[1,2,3,4],[1,2,3,4]]
    localparam [127:0] A3 = 128'h04040404_03030303_02020202_01010101;
    localparam [127:0] B3 = 128'h04030201_04030201_04030201_04030201;

    // -----------------------------------------------------------------
    // Preset seçimi (kombinasyonel)
    // -----------------------------------------------------------------
    reg [127:0] a_mat, b_mat;

    always @(*) begin
        case (sw)
            2'd0: begin a_mat = A0; b_mat = B0; end
            2'd1: begin a_mat = A1; b_mat = B1; end
            2'd2: begin a_mat = A2; b_mat = B2; end
            2'd3: begin a_mat = A3; b_mat = B3; end
        endcase
    end

    // -----------------------------------------------------------------
    // FSM: IDLE → LOAD → DONE → IDLE
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            cycle <= 3'd0;
            done  <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        cycle <= 3'd0;
                    end
                end
                LOAD: begin
                    if (cycle == 3'd6)
                        state <= DONE;
                    else
                        cycle <= cycle + 3'd1;
                end
                DONE: begin
                    done  <= 1'b1;
                    state <= IDLE;
                    cycle <= 3'd0;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // -----------------------------------------------------------------
    // Kombinasyonel skewed çıkış
    //
    // Çevrim t'de aktif hücreler:
    //   t=0: A[0][0], B[0][0]
    //   t=1: A[0][1], A[1][0], B[1][0], B[0][1]
    //   t=2: A[0][2], A[1][1], A[2][0], B[2][0], B[1][1], B[0][2]
    //   t=3: A[0][3], A[1][2], A[2][1], A[3][0], B[3][0], B[2][1], B[1][2], B[0][3]
    //   t=4: A[1][3], A[2][2], A[3][1], B[3][1], B[2][2], B[1][3]
    //   t=5: A[2][3], A[3][2], B[3][2], B[2][3]
    //   t=6: A[3][3], B[3][3]
    //
    // a_mat[(r*4+c)*8+:8] = A[r][c]   →  r*32 + c*8 bit ofseti
    // b_mat[(r*4+c)*8+:8] = B[r][c]   →  r*32 + c*8 bit ofseti
    // -----------------------------------------------------------------
    always @(*) begin
        a_in = 32'h0;
        b_in = 32'h0;
        if (state == LOAD) begin
            case (cycle)
                3'd0: begin
                    a_in[ 7: 0] = a_mat[  7:  0]; // A[0][0]
                    b_in[ 7: 0] = b_mat[  7:  0]; // B[0][0]
                end
                3'd1: begin
                    a_in[ 7: 0] = a_mat[ 15:  8]; // A[0][1]
                    a_in[15: 8] = a_mat[ 39: 32]; // A[1][0]
                    b_in[ 7: 0] = b_mat[ 39: 32]; // B[1][0]
                    b_in[15: 8] = b_mat[ 15:  8]; // B[0][1]
                end
                3'd2: begin
                    a_in[ 7: 0] = a_mat[ 23: 16]; // A[0][2]
                    a_in[15: 8] = a_mat[ 47: 40]; // A[1][1]
                    a_in[23:16] = a_mat[ 71: 64]; // A[2][0]
                    b_in[ 7: 0] = b_mat[ 71: 64]; // B[2][0]
                    b_in[15: 8] = b_mat[ 47: 40]; // B[1][1]
                    b_in[23:16] = b_mat[ 23: 16]; // B[0][2]
                end
                3'd3: begin
                    a_in[ 7: 0] = a_mat[ 31: 24]; // A[0][3]
                    a_in[15: 8] = a_mat[ 55: 48]; // A[1][2]
                    a_in[23:16] = a_mat[ 79: 72]; // A[2][1]
                    a_in[31:24] = a_mat[103: 96]; // A[3][0]
                    b_in[ 7: 0] = b_mat[103: 96]; // B[3][0]
                    b_in[15: 8] = b_mat[ 79: 72]; // B[2][1]
                    b_in[23:16] = b_mat[ 55: 48]; // B[1][2]
                    b_in[31:24] = b_mat[ 31: 24]; // B[0][3]
                end
                3'd4: begin
                    a_in[15: 8] = a_mat[ 63: 56]; // A[1][3]
                    a_in[23:16] = a_mat[ 87: 80]; // A[2][2]
                    a_in[31:24] = a_mat[111:104]; // A[3][1]
                    b_in[15: 8] = b_mat[111:104]; // B[3][1]
                    b_in[23:16] = b_mat[ 87: 80]; // B[2][2]
                    b_in[31:24] = b_mat[ 63: 56]; // B[1][3]
                end
                3'd5: begin
                    a_in[23:16] = a_mat[ 95: 88]; // A[2][3]
                    a_in[31:24] = a_mat[119:112]; // A[3][2]
                    b_in[23:16] = b_mat[119:112]; // B[3][2]
                    b_in[31:24] = b_mat[ 95: 88]; // B[2][3]
                end
                3'd6: begin
                    a_in[31:24] = a_mat[127:120]; // A[3][3]
                    b_in[31:24] = b_mat[127:120]; // B[3][3]
                end
                default: begin
                    a_in = 32'h0;
                    b_in = 32'h0;
                end
            endcase
        end
    end

endmodule
