`timescale 1ns/1ps
module fifo_monitor #(
    parameter integer WRITE_WIDTH = 75,
    parameter integer READ_WIDTH = 139,
    parameter integer SYNC_STAGES = 2,
    parameter integer AUTO_REFRESH_CYCLES = 32
) (
    input wire rst_n,
    input wire monitor_clk,
    input wire snapshot_req,
    output wire snapshot_ready,
    output wire snapshot_busy,
    output reg snapshot_valid,
    output reg [31:0] snapshot_id,
    input wire a_wr_clk, a_wr_rst_n,
    input wire a_rd_clk, a_rd_rst_n,
    input wire b_wr_clk, b_wr_rst_n,
    input wire b_rd_clk, b_rd_rst_n,
    input wire [WRITE_WIDTH-1:0] a_write_packet, b_write_packet,
    input wire [READ_WIDTH-1:0] a_read_packet, b_read_packet,
    output reg [WRITE_WIDTH-1:0] a_write_status, b_write_status,
    output reg [READ_WIDTH-1:0] a_read_status, b_read_status
);
    localparam [1:0] IDLE = 2'd0, WAIT_ACK = 2'd1, GUARD = 2'd2, CAPTURE = 2'd3;
    reg [1:0] state;
    reg request_toggle;
    reg [31:0] idle_cycles;
    wire monitor_rst_done;
    wire [3:0] ack;
    wire [WRITE_WIDTH-1:0] held_aw, held_bw;
    wire [READ_WIDTH-1:0] held_ar, held_br;
    wire automatic_request = (AUTO_REFRESH_CYCLES != 0) &&
                             (idle_cycles == AUTO_REFRESH_CYCLES-1);

    reset_sync u_reset (.clk(monitor_clk), .arst_n(rst_n), .srst_n(monitor_rst_done));
    assign snapshot_ready = monitor_rst_done && (state == IDLE);
    assign snapshot_busy = monitor_rst_done && (state != IDLE);

    snapshot_mailbox #(.WIDTH(WRITE_WIDTH), .SYNC_STAGES(SYNC_STAGES)) u_a_write (
        .src_clk(a_wr_clk), .src_rst_n(a_wr_rst_n), .src_data(a_write_packet),
        .dst_clk(monitor_clk), .dst_rst_n(monitor_rst_done), .request_toggle(request_toggle),
        .acknowledgement(ack[0]), .held_data(held_aw)
    );
    snapshot_mailbox #(.WIDTH(READ_WIDTH), .SYNC_STAGES(SYNC_STAGES)) u_a_read (
        .src_clk(a_rd_clk), .src_rst_n(a_rd_rst_n), .src_data(a_read_packet),
        .dst_clk(monitor_clk), .dst_rst_n(monitor_rst_done), .request_toggle(request_toggle),
        .acknowledgement(ack[1]), .held_data(held_ar)
    );
    snapshot_mailbox #(.WIDTH(WRITE_WIDTH), .SYNC_STAGES(SYNC_STAGES)) u_b_write (
        .src_clk(b_wr_clk), .src_rst_n(b_wr_rst_n), .src_data(b_write_packet),
        .dst_clk(monitor_clk), .dst_rst_n(monitor_rst_done), .request_toggle(request_toggle),
        .acknowledgement(ack[2]), .held_data(held_bw)
    );
    snapshot_mailbox #(.WIDTH(READ_WIDTH), .SYNC_STAGES(SYNC_STAGES)) u_b_read (
        .src_clk(b_rd_clk), .src_rst_n(b_rd_rst_n), .src_data(b_read_packet),
        .dst_clk(monitor_clk), .dst_rst_n(monitor_rst_done), .request_toggle(request_toggle),
        .acknowledgement(ack[3]), .held_data(held_br)
    );

    always @(posedge monitor_clk or negedge monitor_rst_done) begin
        if (!monitor_rst_done) begin
            state <= IDLE;
            request_toggle <= 0;
            idle_cycles <= 0;
            snapshot_valid <= 0;
            snapshot_id <= 0;
            a_write_status <= 0;
            a_read_status <= 0;
            b_write_status <= 0;
            b_read_status <= 0;
        end else begin
            snapshot_valid <= 0;
            case (state)
                IDLE: begin
                    if (snapshot_req || automatic_request) begin
                        request_toggle <= ~request_toggle;
                        idle_cycles <= 0;
                        state <= WAIT_ACK;
                    end else if (AUTO_REFRESH_CYCLES != 0) idle_cycles <= idle_cycles + 1'b1;
                end
                WAIT_ACK: begin
                    if (ack == {4{request_toggle}}) state <= GUARD;
                end
                GUARD: state <= CAPTURE;
                CAPTURE: begin
                    a_write_status <= held_aw;
                    a_read_status <= held_ar;
                    b_write_status <= held_bw;
                    b_read_status <= held_br;
                    snapshot_id <= snapshot_id + 1'b1;
                    snapshot_valid <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if (SYNC_STAGES < 2 || AUTO_REFRESH_CYCLES < 0) begin
            $display("PARAMETER_ERROR: invalid monitor configuration");
            $finish;
        end
    end
    // synthesis translate_on
endmodule
