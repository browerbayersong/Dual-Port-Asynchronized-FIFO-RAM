`timescale 1ns/1ps
module native_coverage_top #(
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
    wire [ADDR_WIDTH:0] a_true_level = dut.fifo_a.wbin - dut.fifo_a.rbin;
    wire a_stall = a_rd_en && !a_empty && !a_rd_ready;
    integer a_stall_length=0;
    always @(posedge a_rd_clk or negedge rst_n) begin
        if(!rst_n) a_stall_length<=0;
        else if(a_stall) a_stall_length<=a_stall_length+1;
        else a_stall_length<=0;
    end
    a_occupancy_0: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==0);
    a_occupancy_1: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==1);
    a_occupancy_31: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==31);
    a_occupancy_32: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==32);
    a_occupancy_33: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==33);
    a_occupancy_223: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==223);
    a_occupancy_224: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==224);
    a_occupancy_225: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==225);
    a_occupancy_255: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==255);
    a_occupancy_256: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_true_level==256);
    a_full_rise: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) $rose(a_full));
    a_full_fall: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) $fell(a_full));
    a_almost_full_rise: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) $rose(a_almost_full));
    a_almost_full_fall: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) $fell(a_almost_full));
    a_empty_rise: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $rose(a_empty));
    a_empty_fall: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $fell(a_empty));
    a_almost_empty_rise: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $rose(a_almost_empty));
    a_almost_empty_fall: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $fell(a_almost_empty));
    a_write_accept: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_wr_en && !a_full);
    a_overflow: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_wr_en && a_full);
    a_read_accept: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) a_rd_en && a_rd_ready && !a_empty);
    a_underflow: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) a_rd_en && a_rd_ready && a_empty);
    a_bp_one: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) !a_stall && a_stall_length==1);
    a_bp_short: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) !a_stall && a_stall_length>=2 && a_stall_length<=10);
    a_bp_long: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) !a_stall && a_stall_length>10);
    a_write_gray: assert property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) $onehot0(dut.fifo_a.wgray ^ $past(dut.fifo_a.wgray)));
    a_read_gray: assert property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $onehot0(dut.fifo_a.rgray ^ $past(dut.fifo_a.rgray)));
    a_full_guard: assert property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) a_full |=> $stable(dut.fifo_a.wbin));
    a_empty_guard: assert property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) a_empty |=> $stable(dut.fifo_a.rbin));
    a_backpressure_hold: assert property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) (a_rd_en && !a_rd_ready) |=> ($stable(dut.fifo_a.rbin) && $stable(a_rd_data)));
    wire [ADDR_WIDTH:0] b_true_level = dut.fifo_b.wbin - dut.fifo_b.rbin;
    wire b_stall = b_rd_en && !b_empty && !b_rd_ready;
    integer b_stall_length=0;
    always @(posedge b_rd_clk or negedge rst_n) begin
        if(!rst_n) b_stall_length<=0;
        else if(b_stall) b_stall_length<=b_stall_length+1;
        else b_stall_length<=0;
    end
    b_occupancy_0: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==0);
    b_occupancy_1: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==1);
    b_occupancy_31: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==31);
    b_occupancy_32: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==32);
    b_occupancy_33: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==33);
    b_occupancy_223: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==223);
    b_occupancy_224: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==224);
    b_occupancy_225: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==225);
    b_occupancy_255: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==255);
    b_occupancy_256: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_true_level==256);
    b_full_rise: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) $rose(b_full));
    b_full_fall: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) $fell(b_full));
    b_almost_full_rise: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) $rose(b_almost_full));
    b_almost_full_fall: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) $fell(b_almost_full));
    b_empty_rise: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $rose(b_empty));
    b_empty_fall: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $fell(b_empty));
    b_almost_empty_rise: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $rose(b_almost_empty));
    b_almost_empty_fall: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $fell(b_almost_empty));
    b_write_accept: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_wr_en && !b_full);
    b_overflow: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_wr_en && b_full);
    b_read_accept: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) b_rd_en && b_rd_ready && !b_empty);
    b_underflow: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) b_rd_en && b_rd_ready && b_empty);
    b_bp_one: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) !b_stall && b_stall_length==1);
    b_bp_short: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) !b_stall && b_stall_length>=2 && b_stall_length<=10);
    b_bp_long: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) !b_stall && b_stall_length>10);
    b_write_gray: assert property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) $onehot0(dut.fifo_b.wgray ^ $past(dut.fifo_b.wgray)));
    b_read_gray: assert property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $onehot0(dut.fifo_b.rgray ^ $past(dut.fifo_b.rgray)));
    b_full_guard: assert property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) b_full |=> $stable(dut.fifo_b.wbin));
    b_empty_guard: assert property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) b_empty |=> $stable(dut.fifo_b.rbin));
    b_backpressure_hold: assert property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) (b_rd_en && !b_rd_ready) |=> ($stable(dut.fifo_b.rbin) && $stable(b_rd_data)));
    a_full_b_empty: cover property (@(posedge monitor_clk) disable iff(!rst_n) a_full && b_empty);
    b_full_a_empty: cover property (@(posedge monitor_clk) disable iff(!rst_n) b_full && a_empty);
    both_almost_full: cover property (@(posedge monitor_clk) disable iff(!rst_n) a_almost_full && b_almost_full);
    both_backpressured: cover property (@(posedge monitor_clk) disable iff(!rst_n) a_stall && b_stall);
    monitor_state_0: cover property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) dut.u_monitor.state==0);
    monitor_state_1: cover property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) dut.u_monitor.state==1);
    monitor_state_2: cover property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) dut.u_monitor.state==2);
    monitor_state_3: cover property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) dut.u_monitor.state==3);
    monitor_publish: cover property (@(posedge monitor_clk) disable iff(!rst_n) snapshot_valid);
    monitor_wait: cover property (@(posedge monitor_clk) disable iff(!rst_n) snapshot_busy && !snapshot_valid);
    monitor_reset_cancel: cover property (@(posedge monitor_clk) !rst_n && $past(snapshot_busy));
    generate if(AUTO_REFRESH_CYCLES>0) begin: automatic_mode
        monitor_auto: cover property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) dut.u_monitor.automatic_request && snapshot_ready && !snapshot_req);
    end endgenerate
    integer bw_edges=0, previous_bw_edges=0, bw_silent_cycles=0;
    always @(posedge b_wr_clk or negedge rst_n) begin if(!rst_n) bw_edges<=0;else bw_edges<=bw_edges+1;end
    always @(posedge monitor_clk or negedge rst_n) begin
        if(!rst_n) begin previous_bw_edges<=0;bw_silent_cycles<=0;end
        else begin previous_bw_edges<=bw_edges;if(previous_bw_edges==bw_edges) bw_silent_cycles<=bw_silent_cycles+1;else bw_silent_cycles<=0;end
    end
    monitor_clock_pause: cover property (@(posedge monitor_clk) disable iff(!rst_n) snapshot_busy && bw_silent_cycles>=8);
    monitor_output_hold: assert property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) !snapshot_valid |-> $stable({a_write_status,a_read_status,b_write_status,b_read_status}));
    monitor_id: assert property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) snapshot_valid |-> snapshot_id==$past(snapshot_id)+1);
    monitor_pulse: assert property (@(posedge monitor_clk) disable iff(!rst_n) snapshot_valid |=> !snapshot_valid);
    aw_source_hold: assert property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) $stable(dut.u_monitor.u_a_write.source_ack) |-> $stable(dut.u_monitor.held_aw));
    ar_source_hold: assert property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $stable(dut.u_monitor.u_a_read.source_ack) |-> $stable(dut.u_monitor.held_ar));
    bw_source_hold: assert property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) $stable(dut.u_monitor.u_b_write.source_ack) |-> $stable(dut.u_monitor.held_bw));
    br_source_hold: assert property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $stable(dut.u_monitor.u_b_read.source_ack) |-> $stable(dut.u_monitor.held_br));

    // Non-vacuous activation counters for each assertion; these are separate from functional goals.
    ex_a_write_gray: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) dut.fifo_a.wgray!=$past(dut.fifo_a.wgray));
    ex_a_read_gray: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) dut.fifo_a.rgray!=$past(dut.fifo_a.rgray));
    ex_a_full_guard: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) $past(a_full));
    ex_a_empty_guard: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $past(a_empty));
    ex_a_backpressure_hold: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $past(a_rd_en && !a_rd_ready));
    ex_b_write_gray: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) dut.fifo_b.wgray!=$past(dut.fifo_b.wgray));
    ex_b_read_gray: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) dut.fifo_b.rgray!=$past(dut.fifo_b.rgray));
    ex_b_full_guard: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) $past(b_full));
    ex_b_empty_guard: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $past(b_empty));
    ex_b_backpressure_hold: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $past(b_rd_en && !b_rd_ready));
    ex_monitor_output_hold: cover property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) !snapshot_valid);
    ex_monitor_id: cover property (@(posedge monitor_clk) disable iff(!rst_n || !dut.u_monitor.monitor_rst_done) snapshot_valid);
    ex_monitor_pulse: cover property (@(posedge monitor_clk) disable iff(!rst_n) $past(snapshot_valid));
    ex_aw_source_hold: cover property (@(posedge a_wr_clk) disable iff(!rst_n || !a_wr_rst_done) $stable(dut.u_monitor.u_a_write.source_ack));
    ex_ar_source_hold: cover property (@(posedge a_rd_clk) disable iff(!rst_n || !a_rd_rst_done) $stable(dut.u_monitor.u_a_read.source_ack));
    ex_bw_source_hold: cover property (@(posedge b_wr_clk) disable iff(!rst_n || !b_wr_rst_done) $stable(dut.u_monitor.u_b_write.source_ack));
    ex_br_source_hold: cover property (@(posedge b_rd_clk) disable iff(!rst_n || !b_rd_rst_done) $stable(dut.u_monitor.u_b_read.source_ack));
endmodule
