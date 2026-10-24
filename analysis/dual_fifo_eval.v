`timescale 1ns/1ps
module dual_fifo_eval #(
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
    input wire b_wr_clk, b_wr_en,
    input wire [DATA_WIDTH-1:0] b_wr_data,
    input wire b_rd_clk, b_rd_en, b_rd_ready,
    output wire [DATA_WIDTH-1:0] b_rd_data,
    output wire b_rd_data_valid, b_full, b_empty, b_almost_full, b_almost_empty,
    output wire [ADDR_WIDTH:0] b_wr_level, b_rd_level,
    output wire b_wr_rst_done, b_rd_rst_done,
    input wire monitor_clk, snapshot_req,
    output wire snapshot_ready, snapshot_busy, snapshot_valid,
    input wire [4:0] status_select,
    output wire [31:0] status_data
);
    wire [COUNT_WIDTH-1:0] a_write_count, a_read_count, a_overflow_count, a_underflow_count;
    wire [COUNT_WIDTH-1:0] a_backpressure_count, a_backpressure_cycles;
    wire [COUNT_WIDTH-1:0] b_write_count, b_read_count, b_overflow_count, b_underflow_count;
    wire [COUNT_WIDTH-1:0] b_backpressure_count, b_backpressure_cycles;
    wire [31:0] snapshot_id;
    wire [2*COUNT_WIDTH+ADDR_WIDTH+2:0] a_write_status, b_write_status;
    wire [4*COUNT_WIDTH+ADDR_WIDTH+2:0] a_read_status, b_read_status;

    dual_async_fifo #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.COUNT_WIDTH(COUNT_WIDTH),
        .SYNC_STAGES(SYNC_STAGES),.AF_ASSERT(AF_ASSERT),.AF_CLEAR(AF_CLEAR),
        .AE_ASSERT(AE_ASSERT),.AE_CLEAR(AE_CLEAR),.AUTO_REFRESH_CYCLES(AUTO_REFRESH_CYCLES)) dut (
        .rst_n(rst_n),
        .a_wr_clk(a_wr_clk),
        .a_wr_en(a_wr_en),
        .a_wr_data(a_wr_data),
        .a_rd_clk(a_rd_clk),
        .a_rd_en(a_rd_en),
        .a_rd_ready(a_rd_ready),
        .a_rd_data(a_rd_data),
        .a_rd_data_valid(a_rd_data_valid),
        .a_full(a_full),
        .a_empty(a_empty),
        .a_almost_full(a_almost_full),
        .a_almost_empty(a_almost_empty),
        .a_wr_level(a_wr_level),
        .a_rd_level(a_rd_level),
        .a_wr_rst_done(a_wr_rst_done),
        .a_rd_rst_done(a_rd_rst_done),
        .a_write_count(a_write_count),
        .a_read_count(a_read_count),
        .a_overflow_count(a_overflow_count),
        .a_underflow_count(a_underflow_count),
        .a_backpressure_count(a_backpressure_count),
        .a_backpressure_cycles(a_backpressure_cycles),
        .b_wr_clk(b_wr_clk),
        .b_wr_en(b_wr_en),
        .b_wr_data(b_wr_data),
        .b_rd_clk(b_rd_clk),
        .b_rd_en(b_rd_en),
        .b_rd_ready(b_rd_ready),
        .b_rd_data(b_rd_data),
        .b_rd_data_valid(b_rd_data_valid),
        .b_full(b_full),
        .b_empty(b_empty),
        .b_almost_full(b_almost_full),
        .b_almost_empty(b_almost_empty),
        .b_wr_level(b_wr_level),
        .b_rd_level(b_rd_level),
        .b_wr_rst_done(b_wr_rst_done),
        .b_rd_rst_done(b_rd_rst_done),
        .b_write_count(b_write_count),
        .b_read_count(b_read_count),
        .b_overflow_count(b_overflow_count),
        .b_underflow_count(b_underflow_count),
        .b_backpressure_count(b_backpressure_count),
        .b_backpressure_cycles(b_backpressure_cycles),
        .monitor_clk(monitor_clk),
        .snapshot_req(snapshot_req),
        .snapshot_ready(snapshot_ready),
        .snapshot_busy(snapshot_busy),
        .snapshot_valid(snapshot_valid),
        .snapshot_id(snapshot_id),
        .a_write_status(a_write_status),
        .b_write_status(b_write_status),
        .a_read_status(a_read_status),
        .b_read_status(b_read_status)
    );
    // Native cover-property counters are emitted by Verilator --coverage-user.

    // This combinational diagnostic output only preserves visibility for software implementation.
    // It is excluded from interface timing and is not an additional coherent CDC interface.
    localparam STATUS_BITS = 24*COUNT_WIDTH + 4*ADDR_WIDTH + 44;
    localparam STATUS_WORDS = (STATUS_BITS+31)/32;
    wire [STATUS_WORDS*32-1:0] status_vector = {{(STATUS_WORDS*32-STATUS_BITS){1'b0}},
        a_write_count,
        a_read_count,
        a_overflow_count,
        a_underflow_count,
        a_backpressure_count,
        a_backpressure_cycles,
        b_write_count,
        b_read_count,
        b_overflow_count,
        b_underflow_count,
        b_backpressure_count,
        b_backpressure_cycles,
        snapshot_id,
        a_write_status,
        a_read_status,
        b_write_status,
        b_read_status};
    assign status_data = (status_select < STATUS_WORDS) ? status_vector[status_select*32 +: 32] : 32'b0;
endmodule
