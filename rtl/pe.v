`timescale 1ns/1ps

module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire [DATA_WIDTH-1:0] a_in,
    input  wire [DATA_WIDTH-1:0] b_in,
    output reg  [DATA_WIDTH-1:0] a_out,
    output reg  [DATA_WIDTH-1:0] b_out,
    output reg  [ACC_WIDTH-1:0]  acc_out
);

    wire [ACC_WIDTH-1:0] product;
    assign product = a_in * b_in;

    always @(posedge clk) begin
        if (rst) begin
            a_out   <= {DATA_WIDTH{1'b0}};
            b_out   <= {DATA_WIDTH{1'b0}};
            acc_out <= {ACC_WIDTH{1'b0}};
        end else begin
            a_out   <= a_in;
            b_out   <= b_in;
            acc_out <= acc_out + product;
        end
    end

endmodule
