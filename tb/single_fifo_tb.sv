`timescale 1ns/1ps
module single_fifo_tb #(
    parameter integer SYNC_STAGES = 2,
    parameter integer COUNT_WIDTH = 32,
    parameter integer AF_CLEAR = 224,
    parameter integer AE_CLEAR = 32
);
    logic rst_n = 0;
    logic wr_clk = 0, rd_clk = 0;
    logic wr_en = 0, rd_en = 0, rd_ready = 1;
    logic [31:0] wr_data = 0;
    wire [31:0] rd_data;
    wire rd_data_valid, full, empty, almost_full, almost_empty;
    wire wr_rst_done, rd_rst_done;
    wire [8:0] wr_level, rd_level;
    wire [COUNT_WIDTH-1:0] write_count, read_count, overflow_count, underflow_count;
    wire [COUNT_WIDTH-1:0] backpressure_count, backpressure_cycles;
    integer wr_half_ps = 10000, rd_half_ps = 6000, rd_phase_ps = 0;
    integer operations = 5000;
    integer decisions = 0;
    bit writer_done = 0;
    bit config_ok;
    logic [31:0] reference_queue[$];
    integer checks = 0;
    integer cumulative_writes = 0, cumulative_reads = 0, discarded = 0;
    integer overflow_attempts = 0, underflow_attempts = 0;
    integer write_wraps = 0, read_wraps = 0, backpressure_events = 0, longest_stall = 0;
    integer occupancy_hits [0:9];
    logic [5:0] saturation_seen = 0;

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

    async_fifo #(
        .SYNC_STAGES(SYNC_STAGES), .COUNT_WIDTH(COUNT_WIDTH),
        .AF_CLEAR(AF_CLEAR), .AE_CLEAR(AE_CLEAR)
    ) dut (
        .rst_n(rst_n), .wr_clk(wr_clk), .wr_en(wr_en), .wr_data(wr_data),
        .full(full), .almost_full(almost_full), .wr_level(wr_level), .wr_rst_done(wr_rst_done),
        .write_count(write_count), .overflow_count(overflow_count),
        .rd_clk(rd_clk), .rd_en(rd_en), .rd_ready(rd_ready),
        .rd_data(rd_data), .rd_data_valid(rd_data_valid), .empty(empty),
        .almost_empty(almost_empty), .rd_level(rd_level), .rd_rst_done(rd_rst_done),
        .read_count(read_count), .underflow_count(underflow_count),
        .backpressure_count(backpressure_count), .backpressure_cycles(backpressure_cycles)
    );

    initial begin
        #0;
        forever #(wr_half_ps / 1000.0) wr_clk = ~wr_clk;
    end
    initial begin
        #0;
        #(rd_phase_ps / 1000.0);
        forever #(rd_half_ps / 1000.0) rd_clk = ~rd_clk;
    end

    task automatic check(input bit condition, input string message);
        begin
            checks++;
            if (!condition) begin
                $display("CHECK_FAIL at %0t: %s", $time, message);
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
            old_wgray = dut.wgray;
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
            check(dut.wbin === next_wpos[8:0], "write pointer / full protection");
            check(full === (expected_wlevel == 256), "registered full timing");
            check(wr_level === expected_wlevel[8:0], "write-domain occupancy estimate");
            check(almost_full === model_af, "almost_full / hysteresis");
            check(write_count === capped(epoch_writes), "successful write count");
            check(overflow_count === capped(epoch_overflows), "overflow count");
            check(changed_bits(dut.wgray ^ old_wgray) == (accepted_write ? 1 : 0), "source write Gray step");
            if (COUNT_WIDTH <= 4) begin
                if (epoch_writes > 15) saturation_seen[0] = 1;
                if (epoch_overflows > 15) saturation_seen[2] = 1;
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
            old_rgray = dut.rgray;
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
            end else stall_length = 0;
            previous_stall = sampled_stall;
            #0.001;
            check(dut.rbin === next_rpos[8:0], "read pointer / empty / backpressure protection");
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
            check(changed_bits(dut.rgray ^ old_rgray) == (accepted_read ? 1 : 0), "source read Gray step");
            if (COUNT_WIDTH <= 4) begin
                if (epoch_reads > 15) saturation_seen[1] = 1;
                if (epoch_underflows > 15) saturation_seen[3] = 1;
                if (epoch_bp_events > 15) saturation_seen[4] = 1;
                if (epoch_bp_cycles > 15) saturation_seen[5] = 1;
            end
        end
    end

    always @(negedge rst_n) begin
        discarded += reference_queue.size();
        reference_queue.delete();
    end

    task automatic settle;
        begin
            repeat (SYNC_STAGES + 4) @(posedge wr_clk);
            repeat (SYNC_STAGES + 4) @(posedge rd_clk);
            #0.01;
        end
    endtask

    task automatic write_words(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i++) begin
                @(negedge wr_clk);
                wr_en = 1;
                wr_data = $urandom();
            end
            @(negedge wr_clk);
            wr_en = 0;
        end
    endtask

    task automatic read_cycles(input integer n, input bit ready_value);
        integer i;
        begin
            for (i = 0; i < n; i++) begin
                @(negedge rd_clk);
                rd_en = 1;
                rd_ready = ready_value;
            end
            @(negedge rd_clk);
            rd_en = 0;
            rd_ready = 1;
        end
    endtask

    task automatic drain;
        integer watchdog;
        begin
            watchdog = 0;
            @(negedge rd_clk);
            rd_ready = 1;
            rd_en = 1;
            while (reference_queue.size() != 0 || !empty) begin
                @(negedge rd_clk);
                watchdog++;
                check(watchdog < 10000, "drain timeout");
            end
            rd_en = 0;
            settle();
            check(empty && !full && wr_level == 0 && rd_level == 0, "settled empty state");
        end
    endtask

    task automatic reset_fifo;
        begin
            @(negedge wr_clk);
            wr_en = 0;
            rd_en = 0;
            rd_ready = 1;
            rst_n = 0;
            #1;
            check(rd_data === 0 && !rd_data_valid, "asynchronous output reset");
            repeat (3) @(negedge wr_clk);
            rst_n = 1;
            wait (wr_rst_done && rd_rst_done);
            settle();
            check(empty && !full && almost_empty && !almost_full, "reset flags");
            check(write_count == 0 && read_count == 0 && overflow_count == 0 && underflow_count == 0,
                  "reset operation and error counters");
            check(backpressure_count == 0 && backpressure_cycles == 0, "reset backpressure counters");
        end
    endtask

    task automatic random_write;
        integer i, probability;
        begin
            for (i = 0; i < operations; i++) begin
                @(negedge wr_clk);
                decisions = i;
                if (i < operations/3) probability = 85;
                else if (i < 2*operations/3) probability = 50;
                else probability = 20;
                wr_en = ($urandom_range(0, 99) < probability);
                wr_data = $urandom();
            end
            @(negedge wr_clk);
            wr_en = 0;
            writer_done = 1;
        end
    endtask

    task automatic random_read;
        integer probability;
        begin
            while (!writer_done) begin
                @(negedge rd_clk);
                if (decisions < operations/3) probability = 20;
                else if (decisions < 2*operations/3) probability = 50;
                else probability = 90;
                rd_en = ($urandom_range(0, 99) < probability);
                rd_ready = ($urandom_range(0, 99) < 75);
            end
            @(negedge rd_clk);
            rd_en = 0;
            rd_ready = 1;
        end
    endtask

    integer round_index, bin_index, saved_writes, saved_errors;
    initial begin
        config_ok = $value$plusargs("OPS=%d", operations);
        config_ok = $value$plusargs("WR_HALF_PS=%d", wr_half_ps);
        config_ok = $value$plusargs("RD_HALF_PS=%d", rd_half_ps);
        config_ok = $value$plusargs("RD_PHASE_PS=%d", rd_phase_ps);
        for (bin_index = 0; bin_index < 10; bin_index++) occupancy_hits[bin_index] = 0;
        check(operations >= 90 && wr_half_ps >= 1000 && rd_half_ps >= 1000 && rd_phase_ps >= 0,
              "invalid runtime configuration");
        check(COUNT_WIDTH == 4 || COUNT_WIDTH == 32, "testbench count width must be 4 or 32");
        $display("RUN_CONFIG: sync=%0d count_width=%0d ops=%0d wr_half_ps=%0d rd_half_ps=%0d phase_ps=%0d af_clear=%0d ae_clear=%0d",
                 SYNC_STAGES, COUNT_WIDTH, operations, wr_half_ps, rd_half_ps, rd_phase_ps, AF_CLEAR, AE_CLEAR);
        reset_fifo();
        $display("TEST: fill_drain_and_error_guard");
        for (round_index = 0; round_index < 3; round_index++) begin
            saved_writes = cumulative_writes;
            write_words(256);
            settle();
            check(full && wr_level == 256 && reference_queue.size() == 256, "exact depth 256");
            check(cumulative_writes - saved_writes == 256, "premature full or lost write");
            saved_errors = overflow_attempts;
            write_words(20);
            check(overflow_attempts - saved_errors == 20, "exact overflow attempt count");
            check(reference_queue.size() == 256, "full writes changed occupancy");
            drain();
            saved_errors = underflow_attempts;
            read_cycles(20, 1);
            check(underflow_attempts - saved_errors == 20, "exact underflow attempt count");
        end

        $display("TEST: thresholds_and_hysteresis");
        write_words(224); settle();
        check(almost_full, "almost_full assertion at 224");
        read_cycles(1, 1); settle();
        check(almost_full == (AF_CLEAR <= 223), "almost_full hold/clear at 223");
        read_cycles(4, 1); settle();
        check(!almost_full, "almost_full clears below 220");
        drain();
        write_words(37); settle();
        check(!almost_empty, "almost_empty clears above 36");
        read_cycles(5, 1); settle();
        check(almost_empty, "almost_empty asserts at 32");
        write_words(1); settle();
        check(almost_empty == (AE_CLEAR >= 33), "almost_empty hold/clear at 33");
        write_words(4); settle();
        check(!almost_empty, "almost_empty clears at 37");
        drain();

        $display("TEST: backpressure");
        write_words(64); settle();
        repeat (20) begin read_cycles(1, 0); read_cycles(1, 1); end
        read_cycles(16, 0);
        drain();
        saved_errors = underflow_attempts;
        read_cycles(5, 0);
        check(underflow_attempts == saved_errors, "not-ready must not count as underflow");

        $display("TEST: random_mix decisions=%0d", operations);
        fork
            random_write();
            random_read();
        join
        drain();
        check(write_wraps > 0 && read_wraps > 0, "extended pointers must wrap");
        check(backpressure_events >= 21 && longest_stall >= 16, "backpressure coverage");
        if (COUNT_WIDTH == 4) check(saturation_seen == 6'b111111, "all six counters saturated and checked");

        $display("TEST: reset_with_pending_data");
        write_words(13); settle();
        check(reference_queue.size() == 13, "pending words before reset");
        reset_fifo();
        write_words(64); settle(); drain();
        check(cumulative_writes == cumulative_reads + discarded, "end-to-end accounting including reset flush");
        for (bin_index = 0; bin_index < 10; bin_index++) begin
            $display("COVER_BIN: occupancy_index=%0d hits=%0d", bin_index, occupancy_hits[bin_index]);
            check(occupancy_hits[bin_index] > 0, "required occupancy bin not hit");
        end
        $display("CUSTOM_COVERAGE: occupancy=10/10 write_wraps=%0d read_wraps=%0d overflow=%0d underflow=%0d bp_events=%0d longest_stall=%0d",
                 write_wraps, read_wraps, overflow_attempts, underflow_attempts, backpressure_events, longest_stall);
        $display("RESULT: PASS checks=%0d writes=%0d reads=%0d reset_discarded=%0d decisions=%0d",
                 checks, cumulative_writes, cumulative_reads, discarded, operations);
        $finish;
    end

    initial begin
        #10000000;
        $display("TIMEOUT: single FIFO simulation exceeded 10 ms");
        $display("RESULT: FAIL");
        $fatal(1, "test timeout");
    end
endmodule
