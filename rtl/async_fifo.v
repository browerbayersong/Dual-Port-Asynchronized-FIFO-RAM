`timescale 1ns/1ps
module async_fifo #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 8,
    parameter integer SYNC_STAGES = 2,
    parameter integer COUNT_WIDTH = 32,
    parameter integer AF_ASSERT = ((1 << ADDR_WIDTH) * 7) / 8,
    parameter integer AF_CLEAR = AF_ASSERT,
    parameter integer AE_ASSERT = (1 << ADDR_WIDTH) / 8,
    parameter integer AE_CLEAR = AE_ASSERT
) (
    input wire rst_n,
    input wire wr_clk,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output reg full,
    output reg almost_full,
    output reg [ADDR_WIDTH:0] wr_level,
    output wire wr_rst_done,
    output reg [COUNT_WIDTH-1:0] write_count,
    output reg [COUNT_WIDTH-1:0] overflow_count,

    input wire rd_clk,
    input wire rd_en,
    input wire rd_ready,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire rd_data_valid,
    output reg empty,
    output reg almost_empty,
    output reg [ADDR_WIDTH:0] rd_level,
    output wire rd_rst_done,
    output reg [COUNT_WIDTH-1:0] read_count,
    output reg [COUNT_WIDTH-1:0] underflow_count,
    output reg [COUNT_WIDTH-1:0] backpressure_count,
    output reg [COUNT_WIDTH-1:0] backpressure_cycles
);
    localparam integer DEPTH = 1 << ADDR_WIDTH;
    localparam [ADDR_WIDTH:0] FULL_XOR_MASK = {2'b11, {(ADDR_WIDTH-1){1'b0}}};
    localparam [ADDR_WIDTH:0] AF_SET = AF_ASSERT;
    localparam [ADDR_WIDTH:0] AF_DROP = AF_CLEAR;
    localparam [ADDR_WIDTH:0] AE_SET = AE_ASSERT;
    localparam [ADDR_WIDTH:0] AE_DROP = AE_CLEAR;

    reg [ADDR_WIDTH:0] wbin, wgray, rbin, rgray;
    wire [ADDR_WIDTH:0] rgray_wsync, wgray_rsync;
    wire [ADDR_WIDTH:0] rbin_wsync, wbin_rsync;
    wire wr_fire, rd_fire, stall;
    wire [ADDR_WIDTH:0] wbin_next, wgray_next, rbin_next, rgray_next;
    wire [ADDR_WIDTH:0] wr_level_next, rd_level_next;
    wire full_next, empty_next;
    reg stall_previous;

    reset_sync u_wr_reset (.clk(wr_clk), .arst_n(rst_n), .srst_n(wr_rst_done));
    reset_sync u_rd_reset (.clk(rd_clk), .arst_n(rst_n), .srst_n(rd_rst_done));
    gray_sync #(.WIDTH(ADDR_WIDTH+1), .STAGES(SYNC_STAGES)) u_r2w (
        .clk(wr_clk), .rst_n(wr_rst_done), .gray_in(rgray), .gray_out(rgray_wsync)
    );
    gray_sync #(.WIDTH(ADDR_WIDTH+1), .STAGES(SYNC_STAGES)) u_w2r (
        .clk(rd_clk), .rst_n(rd_rst_done), .gray_in(wgray), .gray_out(wgray_rsync)
    );

    function [ADDR_WIDTH:0] gray_to_binary;
        input [ADDR_WIDTH:0] gray;
        integer bit_index;
        begin
            gray_to_binary[ADDR_WIDTH] = gray[ADDR_WIDTH];
            for (bit_index = ADDR_WIDTH-1; bit_index >= 0; bit_index = bit_index-1)
                gray_to_binary[bit_index] = gray_to_binary[bit_index+1] ^ gray[bit_index];
        end
    endfunction

    function [COUNT_WIDTH-1:0] increment_saturated;
        input [COUNT_WIDTH-1:0] value;
        begin
            if (&value) increment_saturated = value;
            else increment_saturated = value + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
        end
    endfunction

    assign wr_fire = wr_rst_done && wr_en && !full;
    assign rd_fire = rd_rst_done && rd_en && rd_ready && !empty;
    assign stall = rd_en && !empty && !rd_ready;
    assign wbin_next = wbin + {{ADDR_WIDTH{1'b0}}, wr_fire};
    assign rbin_next = rbin + {{ADDR_WIDTH{1'b0}}, rd_fire};
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;
    assign full_next = (wgray_next == (rgray_wsync ^ FULL_XOR_MASK));
    assign empty_next = (rgray_next == wgray_rsync);
    assign rbin_wsync = gray_to_binary(rgray_wsync);
    assign wbin_rsync = gray_to_binary(wgray_rsync);
    assign wr_level_next = wbin_next - rbin_wsync;
    assign rd_level_next = wbin_rsync - rbin_next;

    fifo_ram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_ram (
        .wr_clk(wr_clk), .wr_en(wr_fire), .wr_addr(wbin[ADDR_WIDTH-1:0]), .wr_data(wr_data),
        .rd_clk(rd_clk), .rd_rst_n(rd_rst_done), .rd_en(rd_fire),
        .rd_addr(rbin[ADDR_WIDTH-1:0]), .rd_data(rd_data), .rd_data_valid(rd_data_valid)
    );

    always @(posedge wr_clk or negedge wr_rst_done) begin
        if (!wr_rst_done) begin
            wbin <= 0;
            wgray <= 0;
            full <= 1'b0;
            almost_full <= (AF_ASSERT == 0);
            wr_level <= 0;
            write_count <= 0;
            overflow_count <= 0;
        end else begin
            wbin <= wbin_next;
            wgray <= wgray_next;
            full <= full_next;
            wr_level <= wr_level_next;
            if (wr_level_next >= AF_SET) almost_full <= 1'b1;
            else if (wr_level_next < AF_DROP) almost_full <= 1'b0;
            if (wr_fire) write_count <= increment_saturated(write_count);
            if (wr_en && full) overflow_count <= increment_saturated(overflow_count);
        end
    end

    always @(posedge rd_clk or negedge rd_rst_done) begin
        if (!rd_rst_done) begin
            rbin <= 0;
            rgray <= 0;
            empty <= 1'b1;
            almost_empty <= 1'b1;
            rd_level <= 0;
            read_count <= 0;
            underflow_count <= 0;
            backpressure_count <= 0;
            backpressure_cycles <= 0;
            stall_previous <= 1'b0;
        end else begin
            rbin <= rbin_next;
            rgray <= rgray_next;
            empty <= empty_next;
            rd_level <= rd_level_next;
            if (rd_level_next <= AE_SET) almost_empty <= 1'b1;
            else if (rd_level_next > AE_DROP) almost_empty <= 1'b0;
            if (rd_fire) read_count <= increment_saturated(read_count);
            if (rd_en && rd_ready && empty) underflow_count <= increment_saturated(underflow_count);
            if (stall && !stall_previous) backpressure_count <= increment_saturated(backpressure_count);
            if (stall) backpressure_cycles <= increment_saturated(backpressure_cycles);
            stall_previous <= stall;
        end
    end

    // synthesis translate_off
    initial begin
        if (DATA_WIDTH < 1 || ADDR_WIDTH < 1 || SYNC_STAGES < 2 || COUNT_WIDTH < 1 ||
            AF_CLEAR < 0 || AF_CLEAR > AF_ASSERT || AF_ASSERT > DEPTH ||
            AE_ASSERT < 0 || AE_CLEAR < AE_ASSERT || AE_CLEAR > DEPTH) begin
            $display("PARAMETER_ERROR: invalid asynchronous FIFO configuration");
            $finish;
        end
    end
    // synthesis translate_on
endmodule
