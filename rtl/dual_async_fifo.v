`timescale 1ns/1ps
module dual_async_fifo #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 8,
    parameter integer COUNT_WIDTH = 32,
    parameter integer SYNC_STAGES = 2,
    parameter integer AF_ASSERT = ((1 << ADDR_WIDTH) * 7) / 8,
    parameter integer AF_CLEAR = AF_ASSERT,
    parameter integer AE_ASSERT = (1 << ADDR_WIDTH) / 8,
    parameter integer AE_CLEAR = AE_ASSERT,
    parameter integer AUTO_REFRESH_CYCLES = 32
) (
    input wire rst_n,
    input wire a_wr_clk, a_wr_en,
    input wire [DATA_WIDTH-1:0] a_wr_data,
    input wire a_rd_clk, a_rd_en, a_rd_ready,
    output wire [DATA_WIDTH-1:0] a_rd_data,
    output wire a_rd_data_valid, a_full, a_empty, a_almost_full, a_almost_empty,
    output wire [ADDR_WIDTH:0] a_wr_level, a_rd_level,
    output wire a_wr_rst_done, a_rd_rst_done,
    output wire [COUNT_WIDTH-1:0] a_write_count, a_read_count, a_overflow_count, a_underflow_count,
    output wire [COUNT_WIDTH-1:0] a_backpressure_count, a_backpressure_cycles,
    input wire b_wr_clk, b_wr_en,
    input wire [DATA_WIDTH-1:0] b_wr_data,
    input wire b_rd_clk, b_rd_en, b_rd_ready,
    output wire [DATA_WIDTH-1:0] b_rd_data,
    output wire b_rd_data_valid, b_full, b_empty, b_almost_full, b_almost_empty,
    output wire [ADDR_WIDTH:0] b_wr_level, b_rd_level,
    output wire b_wr_rst_done, b_rd_rst_done,
    output wire [COUNT_WIDTH-1:0] b_write_count, b_read_count, b_overflow_count, b_underflow_count,
    output wire [COUNT_WIDTH-1:0] b_backpressure_count, b_backpressure_cycles,
    input wire monitor_clk, snapshot_req,
    output wire snapshot_ready, snapshot_busy, snapshot_valid,
    output wire [31:0] snapshot_id,
    output wire [2*COUNT_WIDTH+ADDR_WIDTH+2:0] a_write_status, b_write_status,
    output wire [4*COUNT_WIDTH+ADDR_WIDTH+2:0] a_read_status, b_read_status
);
    localparam integer WW = 2*COUNT_WIDTH+ADDR_WIDTH+3;
    localparam integer RW = 4*COUNT_WIDTH+ADDR_WIDTH+3;
    wire [WW-1:0] a_write_packet, b_write_packet;
    wire [RW-1:0] a_read_packet, b_read_packet;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .COUNT_WIDTH(COUNT_WIDTH),
                 .SYNC_STAGES(SYNC_STAGES), .AF_ASSERT(AF_ASSERT), .AF_CLEAR(AF_CLEAR),
                 .AE_ASSERT(AE_ASSERT), .AE_CLEAR(AE_CLEAR)) fifo_a (
        .rst_n(rst_n), .wr_clk(a_wr_clk), .wr_en(a_wr_en), .wr_data(a_wr_data),
        .full(a_full), .almost_full(a_almost_full), .wr_level(a_wr_level), .wr_rst_done(a_wr_rst_done),
        .write_count(a_write_count), .overflow_count(a_overflow_count),
        .rd_clk(a_rd_clk), .rd_en(a_rd_en), .rd_ready(a_rd_ready),
        .rd_data(a_rd_data), .rd_data_valid(a_rd_data_valid), .empty(a_empty),
        .almost_empty(a_almost_empty), .rd_level(a_rd_level), .rd_rst_done(a_rd_rst_done),
        .read_count(a_read_count), .underflow_count(a_underflow_count),
        .backpressure_count(a_backpressure_count), .backpressure_cycles(a_backpressure_cycles)
    );
    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .COUNT_WIDTH(COUNT_WIDTH),
                 .SYNC_STAGES(SYNC_STAGES), .AF_ASSERT(AF_ASSERT), .AF_CLEAR(AF_CLEAR),
                 .AE_ASSERT(AE_ASSERT), .AE_CLEAR(AE_CLEAR)) fifo_b (
        .rst_n(rst_n), .wr_clk(b_wr_clk), .wr_en(b_wr_en), .wr_data(b_wr_data),
        .full(b_full), .almost_full(b_almost_full), .wr_level(b_wr_level), .wr_rst_done(b_wr_rst_done),
        .write_count(b_write_count), .overflow_count(b_overflow_count),
        .rd_clk(b_rd_clk), .rd_en(b_rd_en), .rd_ready(b_rd_ready),
        .rd_data(b_rd_data), .rd_data_valid(b_rd_data_valid), .empty(b_empty),
        .almost_empty(b_almost_empty), .rd_level(b_rd_level), .rd_rst_done(b_rd_rst_done),
        .read_count(b_read_count), .underflow_count(b_underflow_count),
        .backpressure_count(b_backpressure_count), .backpressure_cycles(b_backpressure_cycles)
    );

    assign a_write_packet = {a_almost_full, a_full, a_wr_level, a_overflow_count, a_write_count};
    assign b_write_packet = {b_almost_full, b_full, b_wr_level, b_overflow_count, b_write_count};
    assign a_read_packet = {a_almost_empty, a_empty, a_rd_level, a_backpressure_cycles,
                            a_backpressure_count, a_underflow_count, a_read_count};
    assign b_read_packet = {b_almost_empty, b_empty, b_rd_level, b_backpressure_cycles,
                            b_backpressure_count, b_underflow_count, b_read_count};

    fifo_monitor #(.WRITE_WIDTH(WW), .READ_WIDTH(RW), .SYNC_STAGES(SYNC_STAGES),
                   .AUTO_REFRESH_CYCLES(AUTO_REFRESH_CYCLES)) u_monitor (
        .rst_n(rst_n), .monitor_clk(monitor_clk), .snapshot_req(snapshot_req),
        .snapshot_ready(snapshot_ready), .snapshot_busy(snapshot_busy),
        .snapshot_valid(snapshot_valid), .snapshot_id(snapshot_id),
        .a_wr_clk(a_wr_clk), .a_wr_rst_n(a_wr_rst_done), .a_rd_clk(a_rd_clk), .a_rd_rst_n(a_rd_rst_done),
        .b_wr_clk(b_wr_clk), .b_wr_rst_n(b_wr_rst_done), .b_rd_clk(b_rd_clk), .b_rd_rst_n(b_rd_rst_done),
        .a_write_packet(a_write_packet), .a_read_packet(a_read_packet),
        .b_write_packet(b_write_packet), .b_read_packet(b_read_packet),
        .a_write_status(a_write_status), .a_read_status(a_read_status),
        .b_write_status(b_write_status), .b_read_status(b_read_status)
    );
endmodule
