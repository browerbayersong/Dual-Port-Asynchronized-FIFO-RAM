`timescale 1ns/1ps
module reset_sync (
    input wire clk,
    input wire arst_n,
    output wire srst_n
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] release_pipe;
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) release_pipe <= 2'b00;
        else release_pipe <= {release_pipe[0], 1'b1};
    end
    assign srst_n = release_pipe[1];
endmodule
