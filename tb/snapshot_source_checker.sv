`timescale 1ns/1ps
// Observe the actual source capture edge and compare against pre-edge external state.
module snapshot_source_checker #(
    parameter integer WIDTH = 75,
    parameter integer SOURCE_ID = 0
) (
    input wire clk, rst_n, local_rst_done,
    input wire [WIDTH-1:0] native_packet,
    input wire source_ack,
    input wire [WIDTH-1:0] held_data,
    output logic [WIDTH-1:0] expected_packet = 0,
    output integer capture_count = 0
);
    logic old_ack;
    logic [WIDTH-1:0] at_edge;
    integer checks = 0;
    // This separate reset observer cannot be blocked by the post-NBA sampling delay.
    always @(negedge rst_n) begin
        expected_packet = 0;
        capture_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && local_rst_done) begin
            old_ack = source_ack;
            at_edge = native_packet;
            #0.001;
            if (rst_n && local_rst_done) begin
                if (source_ack !== old_ack) begin
                    expected_packet = at_edge;
                    capture_count++;
                end
                checks++;
                if (held_data !== expected_packet || (^source_ack === 1'bx)) begin
                    $display("CHECK_FAIL source=%0d: snapshot capture/hold differs from external native state", SOURCE_ID);
                    $display("RESULT: FAIL");
                    $fatal(1, "source snapshot mismatch");
                end
            end
        end
    end
endmodule
