`timescale 1ns/1ps
// Reusable independent scoreboard, derived from the already exercised single-channel TB.
module fifo_channel_checker #(
    parameter integer CHANNEL_ID = 0,
    parameter integer SYNC_STAGES = 2,
    parameter integer COUNT_WIDTH = 32,
    parameter integer AF_CLEAR = 224,
    parameter integer AE_CLEAR = 32
) (
    input wire rst_n, wr_clk, rd_clk, wr_rst_done, rd_rst_done,
    input wire wr_en, rd_en, rd_ready,
    input wire [31:0] wr_data, rd_data,
    input wire rd_data_valid, full, empty, almost_full, almost_empty,
    input wire [8:0] wr_level, rd_level,
    input wire [COUNT_WIDTH-1:0] write_count, read_count, overflow_count, underflow_count,
    input wire [COUNT_WIDTH-1:0] backpressure_count, backpressure_cycles,
    input wire [8:0] observed_wbin, observed_rbin, observed_wgray, observed_rgray
);
    logic [31:0] reference_queue[$];
    integer checks = 0;
    integer cumulative_writes = 0, cumulative_reads = 0, discarded = 0;
    integer overflow_attempts = 0, underflow_attempts = 0;
    integer write_wraps = 0, read_wraps = 0, backpressure_events = 0, longest_stall = 0;
    integer occupancy_hits [0:9];
    integer stall_one=0, stall_short=0, stall_long=0;
    integer full_rise=0, full_fall=0, empty_rise=0, empty_fall=0;
    integer af_rise=0, af_fall=0, ae_rise=0, ae_fall=0;
    bit previous_full=0, previous_empty=1, previous_af=0, previous_ae=1;
    logic [5:0] saturation_seen = 0;
    integer bin_index;
    initial for (bin_index = 0; bin_index < 10; bin_index++) occupancy_hits[bin_index] = 0;
    // Independent binary-position model: no Gray full-comparison expression is reused.
    integer model_wpos = 0, model_rpos = 0;
    integer rpos_pipe [0:SYNC_STAGES-1];
    integer wpos_pipe [0:SYNC_STAGES-1];
    integer epoch_writes = 0, epoch_reads = 0, epoch_overflows = 0, epoch_underflows = 0;
    integer epoch_bp_events = 0, epoch_bp_cycles = 0;
    bit model_af = 0, model_ae = 1, previous_stall = 0;
    integer stall_length = 0;
    integer wi, ri;
    integer next_wpos, next_rpos, expected_wlevel, expected_rlevel;
    bit accepted_write, accepted_read, sampled_stall;
    logic [8:0] old_wgray, old_rgray;
    logic [31:0] expected_data, held_data;

    task automatic check(input bit condition, input string message);
        begin
            checks++;
            if (!condition) begin
                $display("CHECK_FAIL channel=%0d at %0t: %s", CHANNEL_ID, $time, message);
                $display("RESULT: FAIL");
                $fatal(1, "single FIFO self-check failed");
            end
        end
    endtask

    function automatic [COUNT_WIDTH-1:0] capped(input longint unsigned total);
        longint unsigned maximum;
        begin
            maximum = (64'd1 << COUNT_WIDTH) - 1;
            capped = (total > maximum) ? maximum[COUNT_WIDTH-1:0] : total[COUNT_WIDTH-1:0];
        end
    endfunction

    function automatic integer changed_bits(input logic [8:0] delta);
        integer i;
        begin
            changed_bits = 0;
            for (i = 0; i < 9; i++) changed_bits += delta[i];
        end
    endfunction

    task automatic record_occupancy;
        begin
            case (reference_queue.size())
                0: occupancy_hits[0]++;
                1: occupancy_hits[1]++;
                31: occupancy_hits[2]++;
                32: occupancy_hits[3]++;
                33: occupancy_hits[4]++;
                223: occupancy_hits[5]++;
                224: occupancy_hits[6]++;
                225: occupancy_hits[7]++;
                255: occupancy_hits[8]++;
                256: occupancy_hits[9]++;
            endcase
        end
    endtask

    // Model source positions use NBA just like registers. Coincident clocks therefore
    // sample the previous source position, independent of the order of the monitors.
    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n || !wr_rst_done) begin
            model_wpos <= 0;
            for (wi = 0; wi < SYNC_STAGES; wi++) rpos_pipe[wi] <= 0;
            epoch_writes = 0;
            epoch_overflows = 0;
            model_af = 0;
        end else begin
            accepted_write = wr_en && !full;
            next_wpos = (model_wpos + accepted_write) % 512;
            expected_wlevel = (next_wpos - rpos_pipe[SYNC_STAGES-1] + 512) % 512;
            old_wgray = observed_wgray;
            if (expected_wlevel >= 224) model_af = 1;
            else if (expected_wlevel < AF_CLEAR) model_af = 0;
            model_wpos <= next_wpos;
            rpos_pipe[0] <= model_rpos;
            for (wi = 1; wi < SYNC_STAGES; wi++) rpos_pipe[wi] <= rpos_pipe[wi-1];
            if (accepted_write) begin
                reference_queue.push_back(wr_data);
                epoch_writes++;
                cumulative_writes++;
                check(reference_queue.size() <= 256, "true occupancy exceeded 256");
                if (next_wpos == 0) write_wraps++;
                record_occupancy();
            end
            if (wr_en && full) begin epoch_overflows++; overflow_attempts++; end
            #0.001;
            if (rst_n && wr_rst_done) begin
                if (full && !previous_full) full_rise++;
                if (!full && previous_full) full_fall++;
                if (almost_full && !previous_af) af_rise++;
                if (!almost_full && previous_af) af_fall++;
                previous_full=full; previous_af=almost_full;
                check(observed_wbin === next_wpos[8:0], "write pointer / full protection");
                check(full === (expected_wlevel == 256), "registered full timing");
                check(wr_level === expected_wlevel[8:0], "write-domain occupancy estimate");
                check(almost_full === model_af, "almost_full / hysteresis");
                check(write_count === capped(epoch_writes), "successful write count");
                check(overflow_count === capped(epoch_overflows), "overflow count");
                check(changed_bits(observed_wgray ^ old_wgray) == (accepted_write ? 1 : 0), "source write Gray step");
                if (COUNT_WIDTH <= 4) begin
                    if (epoch_writes > 15) saturation_seen[0] = 1;
                    if (epoch_overflows > 15) saturation_seen[2] = 1;
                end
            end
        end
    end

    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n || !rd_rst_done) begin
            model_rpos <= 0;
            for (ri = 0; ri < SYNC_STAGES; ri++) wpos_pipe[ri] <= 0;
            epoch_reads = 0;
            epoch_underflows = 0;
            epoch_bp_events = 0;
            epoch_bp_cycles = 0;
            model_ae = 1;
            previous_stall = 0;
            stall_length = 0;
        end else begin
            accepted_read = rd_en && rd_ready && !empty;
            sampled_stall = rd_en && !empty && !rd_ready;
            next_rpos = (model_rpos + accepted_read) % 512;
            expected_rlevel = (wpos_pipe[SYNC_STAGES-1] - next_rpos + 512) % 512;
            old_rgray = observed_rgray;
            held_data = rd_data;
            if (expected_rlevel <= 32) model_ae = 1;
            else if (expected_rlevel > AE_CLEAR) model_ae = 0;
            model_rpos <= next_rpos;
            wpos_pipe[0] <= model_wpos;
            for (ri = 1; ri < SYNC_STAGES; ri++) wpos_pipe[ri] <= wpos_pipe[ri-1];
            if (accepted_read) begin
                check(reference_queue.size() > 0, "accepted read with empty reference queue");
                expected_data = reference_queue.pop_front();
                epoch_reads++;
                cumulative_reads++;
                if (next_rpos == 0) read_wraps++;
                record_occupancy();
            end
            if (rd_en && rd_ready && empty) begin epoch_underflows++; underflow_attempts++; end
            if (sampled_stall) begin
                epoch_bp_cycles++;
                stall_length++;
                if (!previous_stall) begin epoch_bp_events++; backpressure_events++; end
                if (stall_length > longest_stall) longest_stall = stall_length;
            end else begin
                if (stall_length == 1) stall_one++;
                else if (stall_length >= 2 && stall_length <= 10) stall_short++;
                else if (stall_length > 10) stall_long++;
                stall_length = 0;
            end
            previous_stall = sampled_stall;
            #0.001;
            if (rst_n && rd_rst_done) begin
                if (empty && !previous_empty) empty_rise++;
                if (!empty && previous_empty) empty_fall++;
                if (almost_empty && !previous_ae) ae_rise++;
                if (!almost_empty && previous_ae) ae_fall++;
                previous_empty=empty; previous_ae=almost_empty;
                check(observed_rbin === next_rpos[8:0], "read pointer / empty / backpressure protection");
                check(empty === (expected_rlevel == 0), "registered empty timing");
                check(rd_level === expected_rlevel[8:0], "read-domain occupancy estimate");
                check(almost_empty === model_ae, "almost_empty / hysteresis");
                check(rd_data_valid === accepted_read, "registered read response valid");
                if (accepted_read) check(rd_data === expected_data, "FIFO data order / content");
                else check(rd_data === held_data, "read output must hold without an accepted read");
                check(read_count === capped(epoch_reads), "successful read count");
                check(underflow_count === capped(epoch_underflows), "underflow count");
                check(backpressure_count === capped(epoch_bp_events), "backpressure episode count");
                check(backpressure_cycles === capped(epoch_bp_cycles), "backpressure cycle count");
                check(changed_bits(observed_rgray ^ old_rgray) == (accepted_read ? 1 : 0), "source read Gray step");
                if (COUNT_WIDTH <= 4) begin
                    if (epoch_reads > 15) saturation_seen[1] = 1;
                    if (epoch_underflows > 15) saturation_seen[3] = 1;
                    if (epoch_bp_events > 15) saturation_seen[4] = 1;
                    if (epoch_bp_cycles > 15) saturation_seen[5] = 1;
                end
            end
        end
    end

    integer reset_index;
    // Independent reset handling remains active while either edge checker waits 1ps.
    always @(negedge rst_n) begin
        model_wpos <= 0; model_rpos <= 0;
        for (reset_index=0; reset_index<SYNC_STAGES; reset_index++) begin
            rpos_pipe[reset_index] <= 0; wpos_pipe[reset_index] <= 0;
        end
        epoch_writes=0; epoch_reads=0; epoch_overflows=0; epoch_underflows=0;
        epoch_bp_events=0; epoch_bp_cycles=0; model_af=0; model_ae=1;
        previous_stall=0; stall_length=0;
        previous_full=0; previous_empty=1; previous_af=0; previous_ae=1;
        discarded += reference_queue.size();
        reference_queue.delete();
    end

endmodule
