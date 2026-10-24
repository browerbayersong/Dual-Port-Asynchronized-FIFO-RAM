`timescale 1ns/1ps
module gray_sync #(
    parameter integer WIDTH = 9,
    parameter integer STAGES = 2
) (
    input wire clk,
    input wire rst_n,
    input wire [WIDTH-1:0] gray_in,
    output wire [WIDTH-1:0] gray_out
);
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] pipe [0:STAGES-1];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < STAGES; i = i + 1) pipe[i] <= {WIDTH{1'b0}};
        end else begin
            pipe[0] <= gray_in;
            for (i = 1; i < STAGES; i = i + 1) pipe[i] <= pipe[i-1];
        end
    end
    assign gray_out = pipe[STAGES-1];
endmodule
