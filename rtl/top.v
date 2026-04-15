`timescale 1ns/1ps

// top: 4×4 Sistolic Array FPGA üst modülü (Basys3 / Artix-7)
//
// Sinyal akışı:
//   btnC (senkron)  → rst → tüm alt modüller
//   rst ↓ kenar     → auto-start → input_seq → systolic_array
//   seq_done + DRAIN=3 çevrim gecikme → c_out_latch
//   sw[1:0]         → preset seçimi
//   btnR/btnL       → sel_reg artır/azalt (0-15, PE[r*N+c] indeksi)
//   btnU            → show_upper toggle → hex_word üst/alt 16-bit
//   led[3:0]=sel_reg, led[15]=done_flag, dp=ON/OFF üst 16-bit göstergesi
//
// Drain gecikmesi (DRAIN = N-1 = 3):
//   seq_done LOAD'ın son çevriminden 2 posedge sonra ateşlenir (P8).
//   PE[N-1][N-1] son akümülasyonu, son beslemenin (P7) üzerinden
//   N-1=3 pipeline atlaması sonra tamamlanır (P10).
//   c_out_latch P11'de güvenle örneklenir.
//   Referans: tb_array.v — "C[i][j] son kez çevrim (i+j+N-1)'de güncellenir"
module top (
    input  wire        clk,    // 100 MHz sistem saati
    input  wire        btnC,   // Merkez — senkron reset
    input  wire        btnR,   // Sağ    — sel_reg artır
    input  wire        btnL,   // Sol    — sel_reg azalt
    input  wire        btnU,   // Yukarı — üst/alt 16-bit geçiş
    input  wire [3:0]  sw,     // sw[1:0]=preset seçici, sw[3:2] kullanılmıyor
    output wire [6:0]  seg,    // 7-segment sürücü (active-low)
    output wire        dp,     // Ondalık nokta (active-low): yanar=üst 16-bit
    output wire [3:0]  an,     // Anode seçimi (active-low)
    output wire [15:0] led     // [3:0]=sel_reg, [14:4]=0, [15]=done_flag
);

    localparam N     = 4;
    localparam DRAIN = N - 1;  // PE[N-1][N-1] için pipeline boşaltma çevrimi

    // -----------------------------------------------------------------
    // Reset senkronizörü: btnC → 2-FF → active-high senkron rst
    // -----------------------------------------------------------------
    reg rst_s0, rst_s1;
    always @(posedge clk) begin
        rst_s0 <= btnC;
        rst_s1 <= rst_s0;
    end
    wire rst = rst_s1;

    // -----------------------------------------------------------------
    // Auto-start: rst'nin düşen kenarında 1-çevrimlik start pulse
    //   rst yükselince rst_d=1 olur; düşünce (start=rst_d & ~rst)=1
    //   → input_seq IDLE→LOAD geçişini tetikler.
    // -----------------------------------------------------------------
    reg rst_d;
    always @(posedge clk) rst_d <= rst;
    wire start = rst_d & ~rst;

    // -----------------------------------------------------------------
    // clk_div: 100 MHz → 1 kHz tick (seg7 çoğullama refresh'i)
    // -----------------------------------------------------------------
    wire tick;
    clk_div u_clk_div (
        .clk (clk),
        .rst (rst),
        .tick(tick)
    );

    // -----------------------------------------------------------------
    // btn_sync: btnR, btnL, btnU — 10 ms debounce + yükselen kenar pulse
    // -----------------------------------------------------------------
    wire btn_r_pulse, btn_l_pulse, btn_u_pulse;

    btn_sync u_btn_r (
        .clk      (clk),
        .rst      (rst),
        .btn_in   (btnR),
        .btn_pulse(btn_r_pulse)
    );

    btn_sync u_btn_l (
        .clk      (clk),
        .rst      (rst),
        .btn_in   (btnL),
        .btn_pulse(btn_l_pulse)
    );

    btn_sync u_btn_u (
        .clk      (clk),
        .rst      (rst),
        .btn_in   (btnU),
        .btn_pulse(btn_u_pulse)
    );

    // -----------------------------------------------------------------
    // input_seq: 4 preset matrisi skewed olarak sistolic array'e besler
    // -----------------------------------------------------------------
    wire [31:0] a_in, b_in;
    wire        seq_done;

    input_seq u_input_seq (
        .clk  (clk),
        .rst  (rst),
        .start(start),
        .sw   (sw[1:0]),
        .a_in (a_in),
        .b_in (b_in),
        .done (seq_done)
    );

    // -----------------------------------------------------------------
    // systolic_array: 4×4 PE ızgarası — 8-bit giriş, 32-bit akümülatör
    // -----------------------------------------------------------------
    wire [511:0] c_out;

    systolic_array #(
        .N         (N),
        .DATA_WIDTH(8),
        .ACC_WIDTH (32)
    ) u_array (
        .clk  (clk),
        .rst  (rst),
        .a_in (a_in),
        .b_in (b_in),
        .c_out(c_out)
    );

    // -----------------------------------------------------------------
    // Drain shift register: seq_done'u DRAIN=3 çevrim geciktirir
    //   P8:seq_done=1 → P9:done_sr[0]=1 → P10:done_sr[1]=1
    //   → done_sr[2]=1 → latch_en=1 → P11:c_out_latch örneklenir
    // -----------------------------------------------------------------
    reg [DRAIN-1:0] done_sr;
    always @(posedge clk) begin
        if (rst) done_sr <= {DRAIN{1'b0}};
        else     done_sr <= {done_sr[DRAIN-2:0], seq_done};
    end
    wire latch_en = done_sr[DRAIN-1];

    // -----------------------------------------------------------------
    // done_latch: boru hattı boşalınca c_out'u yakala
    //   done_flag: LED[15] için yapışkan bit (rst'ye kadar HIGH kalır)
    // -----------------------------------------------------------------
    reg [511:0] c_out_latch;
    reg         done_flag;

    always @(posedge clk) begin
        if (rst) begin
            c_out_latch <= 512'b0;
            done_flag   <= 1'b0;
        end else if (latch_en) begin
            c_out_latch <= c_out;
            done_flag   <= 1'b1;
        end
    end

    // -----------------------------------------------------------------
    // sel_reg: 4-bit PE indeksi (0-15)
    //   PE[r][c] → r = sel_reg[3:2], c = sel_reg[1:0]
    //   btnR: artır (15→0 otomatik wrap)
    //   btnL: azalt (0→15 otomatik wrap)
    // -----------------------------------------------------------------
    reg [3:0] sel_reg;

    always @(posedge clk) begin
        if (rst)
            sel_reg <= 4'd0;
        else if (btn_r_pulse)
            sel_reg <= sel_reg + 4'd1;
        else if (btn_l_pulse)
            sel_reg <= sel_reg - 4'd1;
    end

    // -----------------------------------------------------------------
    // 16:1 sonuç mux: c_out_latch'ten sel_reg'e göre 32-bit seç
    // -----------------------------------------------------------------
    integer    idx;
    reg [31:0] hex_word;

    always @(*) begin
        hex_word = 32'b0;
        for (idx = 0; idx < 16; idx = idx + 1)
            if (sel_reg == idx[3:0])
                hex_word = c_out_latch[idx*32 +: 32];
    end

    // -----------------------------------------------------------------
    // show_upper: btnU ile üst/alt 16-bit geçişi
    //   0 → hex_word[15:0]  (alt — reset sonrası varsayılan)
    //   1 → hex_word[31:16] (üst)
    // -----------------------------------------------------------------
    reg show_upper;

    always @(posedge clk) begin
        if (rst)
            show_upper <= 1'b0;
        else if (btn_u_pulse)
            show_upper <= ~show_upper;
    end

    wire [15:0] hex_val = show_upper ? hex_word[31:16] : hex_word[15:0];

    // -----------------------------------------------------------------
    // seg7_drv: 4 haneli hex → 7-segment çoğullayıcı
    // -----------------------------------------------------------------
    seg7_drv u_seg7 (
        .clk    (clk),
        .rst    (rst),
        .tick   (tick),
        .hex_val(hex_val),
        .seg    (seg),
        .an     (an)
    );

    // -----------------------------------------------------------------
    // Çıkışlar
    // -----------------------------------------------------------------
    assign dp        = ~show_upper;  // active-low: 0=ON → üst 16-bit gösterilince yanar
    assign led[3:0]  = sel_reg;
    assign led[14:4] = 11'b0;
    assign led[15]   = done_flag;

endmodule
