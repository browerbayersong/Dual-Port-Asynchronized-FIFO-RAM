`timescale 1ns/1ps
// Bundled-data snapshot: hold the complete source packet until the next request.
// The coordinator waits for synchronized acknowledgements plus two guard edges.
module snapshot_mailbox #(
    parameter integer WIDTH = 75,
    parameter integer SYNC_STAGES = 2
) (
    input wire src_clk,
    input wire src_rst_n,
    input wire [WIDTH-1:0] src_data,
    input wire dst_clk,
    input wire dst_rst_n,
    input wire request_toggle,
    output wire acknowledgement,
    output reg [WIDTH-1:0] held_data
);
    wire request_sync;
    reg source_ack;
    gray_sync #(.WIDTH(1), .STAGES(SYNC_STAGES)) u_request_sync (
        .clk(src_clk), .rst_n(src_rst_n), .gray_in(request_toggle), .gray_out(request_sync)
    );
    gray_sync #(.WIDTH(1), .STAGES(SYNC_STAGES)) u_ack_sync (
        .clk(dst_clk), .rst_n(dst_rst_n), .gray_in(source_ack), .gray_out(acknowledgement)
    );
    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            held_data <= {WIDTH{1'b0}};
            source_ack <= 1'b0;
        end else if (request_sync != source_ack) begin
            held_data <= src_data;
            source_ack <= request_sync;
        end
    end
endmodule
