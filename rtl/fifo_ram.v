`timescale 1ns/1ps
module fifo_ram #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 8
) (
    input wire wr_clk,
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire rd_clk,
    input wire rd_rst_n,
    input wire rd_en,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output reg [DATA_WIDTH-1:0] rd_data,
    output reg rd_data_valid
);
    localparam integer DEPTH = 1 << ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge wr_clk) begin
        if (wr_en) mem[wr_addr] <= wr_data;
    end

    // Reset only the read output, never the memory array.
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_data <= {DATA_WIDTH{1'b0}};
            rd_data_valid <= 1'b0;
        end else begin
            rd_data_valid <= rd_en;
            if (rd_en) rd_data <= mem[rd_addr];
        end
    end
endmodule
