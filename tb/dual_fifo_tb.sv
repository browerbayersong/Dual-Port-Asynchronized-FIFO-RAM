`timescale 1ns/1ps
module dual_fifo_tb #(
    parameter integer SYNC_STAGES = 2,
    parameter integer COUNT_WIDTH = 32,
    parameter integer AF_CLEAR = 224,
    parameter integer AE_CLEAR = 32,
    parameter integer AUTO_REFRESH_CYCLES = 0
);
    localparam integer WW = 2*COUNT_WIDTH+11;
    localparam integer RW = 4*COUNT_WIDTH+11;
    logic rst_n = 0, monitor_clk = 0, snapshot_req = 0;
    logic [1:0] wr_clk = 0, rd_clk = 0, wr_en = 0, rd_en = 0, rd_ready = 2'b11;
    logic [31:0] wr_data [0:1];
    wire [31:0] rd_data [0:1];
    wire [1:0] rd_valid, full, empty, af, ae, wr_done, rd_done;
    wire [8:0] wr_level [0:1], rd_level [0:1];
    wire [COUNT_WIDTH-1:0] writes [0:1], reads [0:1], overflows [0:1], underflows [0:1];
    wire [COUNT_WIDTH-1:0] bp_events [0:1], bp_cycles [0:1];
    wire snapshot_ready, snapshot_busy, snapshot_valid;
    wire [31:0] snapshot_id;
    wire [WW-1:0] aw, bw;
    wire [RW-1:0] ar, br;
    wire [WW-1:0] native_aw = {af[0], full[0], wr_level[0], overflows[0], writes[0]};
    wire [WW-1:0] native_bw = {af[1], full[1], wr_level[1], overflows[1], writes[1]};
    wire [RW-1:0] native_ar = {ae[0], empty[0], rd_level[0], bp_cycles[0], bp_events[0], underflows[0], reads[0]};
    wire [RW-1:0] native_br = {ae[1], empty[1], rd_level[1], bp_cycles[1], bp_events[1], underflows[1], reads[1]};
    wire [WW-1:0] expected_aw, expected_bw;
    wire [RW-1:0] expected_ar, expected_br;
    wire integer captures_aw, captures_ar, captures_bw, captures_br;
    integer operations = 5000, a_rd_phase_ps = 1000, b_wr_phase_ps = 2500, b_rd_phase_ps = 500;
    integer decisions [0:1];
    logic [1:0] writer_done = 0;
    bit b_write_clock_running = 1;
    bit parse_result;
    integer checks = 0, snapshots = 0, epoch_requests = 0, epoch_published = 0, auto_requests = 0;
    integer combo_a_full_b_empty = 0, combo_b_full_a_empty = 0, combo_both_af = 0, combo_both_bp = 0;
    integer clock_pause_seen = 0, busy_ignored_seen = 0, reset_cancel_seen = 0;
    logic old_request, pre_ready, pre_manual, previous_valid = 0;
    logic [WW-1:0] old_aw, old_bw;
    logic [RW-1:0] old_ar, old_br;
    logic [31:0] old_id;

    initial forever #10 wr_clk[0] = ~wr_clk[0];
    initial begin #0; #(a_rd_phase_ps/1000.0); forever #6 rd_clk[0] = ~rd_clk[0]; end
    initial begin
        #0; #(b_wr_phase_ps/1000.0);
        forever begin
            #17.5;
            if (b_write_clock_running) wr_clk[1] = ~wr_clk[1];
            else wr_clk[1] = 0;
        end
    end
    initial begin #0; #(b_rd_phase_ps/1000.0); forever #5 rd_clk[1] = ~rd_clk[1]; end
    initial forever #5 monitor_clk = ~monitor_clk;

    dual_async_fifo #(.SYNC_STAGES(SYNC_STAGES), .COUNT_WIDTH(COUNT_WIDTH),
        .AF_CLEAR(AF_CLEAR), .AE_CLEAR(AE_CLEAR), .AUTO_REFRESH_CYCLES(AUTO_REFRESH_CYCLES)) dut (
        .rst_n(rst_n),
        .a_wr_clk(wr_clk[0]), .a_wr_en(wr_en[0]), .a_wr_data(wr_data[0]),
        .a_rd_clk(rd_clk[0]), .a_rd_en(rd_en[0]), .a_rd_ready(rd_ready[0]),
        .a_rd_data(rd_data[0]), .a_rd_data_valid(rd_valid[0]),
        .a_full(full[0]), .a_empty(empty[0]), .a_almost_full(af[0]), .a_almost_empty(ae[0]),
        .a_wr_level(wr_level[0]), .a_rd_level(rd_level[0]), .a_wr_rst_done(wr_done[0]), .a_rd_rst_done(rd_done[0]),
        .a_write_count(writes[0]), .a_read_count(reads[0]), .a_overflow_count(overflows[0]), .a_underflow_count(underflows[0]),
        .a_backpressure_count(bp_events[0]), .a_backpressure_cycles(bp_cycles[0]),
        .b_wr_clk(wr_clk[1]), .b_wr_en(wr_en[1]), .b_wr_data(wr_data[1]),
        .b_rd_clk(rd_clk[1]), .b_rd_en(rd_en[1]), .b_rd_ready(rd_ready[1]),
        .b_rd_data(rd_data[1]), .b_rd_data_valid(rd_valid[1]),
        .b_full(full[1]), .b_empty(empty[1]), .b_almost_full(af[1]), .b_almost_empty(ae[1]),
        .b_wr_level(wr_level[1]), .b_rd_level(rd_level[1]), .b_wr_rst_done(wr_done[1]), .b_rd_rst_done(rd_done[1]),
        .b_write_count(writes[1]), .b_read_count(reads[1]), .b_overflow_count(overflows[1]), .b_underflow_count(underflows[1]),
        .b_backpressure_count(bp_events[1]), .b_backpressure_cycles(bp_cycles[1]),
        .monitor_clk(monitor_clk), .snapshot_req(snapshot_req), .snapshot_ready(snapshot_ready),
        .snapshot_busy(snapshot_busy), .snapshot_valid(snapshot_valid), .snapshot_id(snapshot_id),
        .a_write_status(aw), .a_read_status(ar), .b_write_status(bw), .b_read_status(br)
    );

    fifo_channel_checker #(.CHANNEL_ID(0), .SYNC_STAGES(SYNC_STAGES), .COUNT_WIDTH(COUNT_WIDTH),
        .AF_CLEAR(AF_CLEAR), .AE_CLEAR(AE_CLEAR)) chan_a (
        .rst_n(rst_n), .wr_clk(wr_clk[0]), .rd_clk(rd_clk[0]), .wr_rst_done(wr_done[0]), .rd_rst_done(rd_done[0]),
        .wr_en(wr_en[0]), .rd_en(rd_en[0]), .rd_ready(rd_ready[0]), .wr_data(wr_data[0]), .rd_data(rd_data[0]),
        .rd_data_valid(rd_valid[0]), .full(full[0]), .empty(empty[0]), .almost_full(af[0]), .almost_empty(ae[0]),
        .wr_level(wr_level[0]), .rd_level(rd_level[0]), .write_count(writes[0]), .read_count(reads[0]),
        .overflow_count(overflows[0]), .underflow_count(underflows[0]), .backpressure_count(bp_events[0]), .backpressure_cycles(bp_cycles[0]),
        .observed_wbin(dut.fifo_a.wbin), .observed_rbin(dut.fifo_a.rbin),
        .observed_wgray(dut.fifo_a.wgray), .observed_rgray(dut.fifo_a.rgray)
    );
    fifo_channel_checker #(.CHANNEL_ID(1), .SYNC_STAGES(SYNC_STAGES), .COUNT_WIDTH(COUNT_WIDTH),
        .AF_CLEAR(AF_CLEAR), .AE_CLEAR(AE_CLEAR)) chan_b (
        .rst_n(rst_n), .wr_clk(wr_clk[1]), .rd_clk(rd_clk[1]), .wr_rst_done(wr_done[1]), .rd_rst_done(rd_done[1]),
        .wr_en(wr_en[1]), .rd_en(rd_en[1]), .rd_ready(rd_ready[1]), .wr_data(wr_data[1]), .rd_data(rd_data[1]),
        .rd_data_valid(rd_valid[1]), .full(full[1]), .empty(empty[1]), .almost_full(af[1]), .almost_empty(ae[1]),
        .wr_level(wr_level[1]), .rd_level(rd_level[1]), .write_count(writes[1]), .read_count(reads[1]),
        .overflow_count(overflows[1]), .underflow_count(underflows[1]), .backpressure_count(bp_events[1]), .backpressure_cycles(bp_cycles[1]),
        .observed_wbin(dut.fifo_b.wbin), .observed_rbin(dut.fifo_b.rbin),
        .observed_wgray(dut.fifo_b.wgray), .observed_rgray(dut.fifo_b.rgray)
    );

    snapshot_source_checker #(.WIDTH(WW), .SOURCE_ID(0)) source_aw (
        .clk(wr_clk[0]), .rst_n(rst_n), .local_rst_done(wr_done[0]), .native_packet(native_aw),
        .source_ack(dut.u_monitor.u_a_write.source_ack), .held_data(dut.u_monitor.held_aw),
        .expected_packet(expected_aw), .capture_count(captures_aw)
    );
    snapshot_source_checker #(.WIDTH(RW), .SOURCE_ID(1)) source_ar (
        .clk(rd_clk[0]), .rst_n(rst_n), .local_rst_done(rd_done[0]), .native_packet(native_ar),
        .source_ack(dut.u_monitor.u_a_read.source_ack), .held_data(dut.u_monitor.held_ar),
        .expected_packet(expected_ar), .capture_count(captures_ar)
    );
    snapshot_source_checker #(.WIDTH(WW), .SOURCE_ID(2)) source_bw (
        .clk(wr_clk[1]), .rst_n(rst_n), .local_rst_done(wr_done[1]), .native_packet(native_bw),
        .source_ack(dut.u_monitor.u_b_write.source_ack), .held_data(dut.u_monitor.held_bw),
        .expected_packet(expected_bw), .capture_count(captures_bw)
    );
    snapshot_source_checker #(.WIDTH(RW), .SOURCE_ID(3)) source_br (
        .clk(rd_clk[1]), .rst_n(rst_n), .local_rst_done(rd_done[1]), .native_packet(native_br),
        .source_ack(dut.u_monitor.u_b_read.source_ack), .held_data(dut.u_monitor.held_br),
        .expected_packet(expected_br), .capture_count(captures_br)
    );

    task automatic check(input bit condition, input string message);
        begin
            checks++;
            if (!condition) begin
                $display("CHECK_FAIL dual at %0t: %s", $time, message);
                $display("RESULT: FAIL");
                $fatal(1, "dual FIFO / monitor check failed");
            end
        end
    endtask

    always @(posedge monitor_clk or negedge rst_n) begin
        if (!rst_n || !dut.u_monitor.monitor_rst_done) begin
            epoch_requests = 0;
            epoch_published = 0;
            previous_valid = 0;
        end else begin
            old_request = dut.u_monitor.request_toggle;
            pre_ready = snapshot_ready;
            pre_manual = snapshot_req && snapshot_ready;
            old_aw = aw; old_ar = ar; old_bw = bw; old_br = br; old_id = snapshot_id;
            #0.001;
            if (dut.u_monitor.request_toggle !== old_request) begin
                epoch_requests++;
                if (!pre_manual) auto_requests++;
            end
            if (pre_manual) check(dut.u_monitor.request_toggle !== old_request, "manual request handshake lost");
            if (!pre_ready) check(dut.u_monitor.request_toggle === old_request, "busy request must not overlap");
            check(snapshot_ready === !snapshot_busy, "ready/busy consistency");
            check(!(snapshot_valid && previous_valid), "snapshot_valid must be a one-cycle pulse");
            if (snapshot_valid) begin
                epoch_published++;
                snapshots++;
                check(snapshot_id === epoch_published[31:0], "snapshot sequence ID");
                check(epoch_requests == epoch_published, "one complete publication per request");
                check(captures_aw == epoch_requests && captures_ar == epoch_requests &&
                      captures_bw == epoch_requests && captures_br == epoch_requests, "all four source domains acknowledged once");
                check(aw === expected_aw && ar === expected_ar && bw === expected_bw && br === expected_br,
                      "published snapshot differs from independently sampled source packets");
            end else begin
                check(aw === old_aw && ar === old_ar && bw === old_bw && br === old_br,
                      "snapshot output changed without valid / partial frame");
                check(snapshot_id === old_id, "snapshot ID changed without publication");
            end
            previous_valid = snapshot_valid;
            if (full[0] && empty[1]) combo_a_full_b_empty++;
            if (full[1] && empty[0]) combo_b_full_a_empty++;
            if (&af) combo_both_af++;
            if ((&rd_en) && !(|rd_ready) && !(|empty)) combo_both_bp++;
        end
    end

    function automatic integer queued(input integer channel);
        if (channel == 0) queued = chan_a.reference_queue.size();
        else queued = chan_b.reference_queue.size();
    endfunction

    task automatic settle;
        begin
            repeat (SYNC_STAGES+5) @(posedge wr_clk[0]);
            repeat (SYNC_STAGES+5) @(posedge wr_clk[1]);
            repeat (SYNC_STAGES+5) @(posedge rd_clk[0]);
            repeat (SYNC_STAGES+5) @(posedge rd_clk[1]);
            #0.01;
        end
    endtask

    task automatic reset_all;
        begin
            @(negedge wr_clk[0]);
            wr_en = 0; rd_en = 0; rd_ready = 2'b11; snapshot_req = 0; rst_n = 0;
            #1;
            check(!snapshot_valid && !snapshot_busy && snapshot_id == 0, "monitor asynchronous reset/cancel");
            check(rd_data[0] === 0 && rd_data[1] === 0 && rd_valid == 0, "both read outputs reset");
            repeat (3) @(negedge wr_clk[0]);
            rst_n = 1;
            wait ((&wr_done) && (&rd_done));
            settle();
            check(empty == 2'b11 && full == 0 && af == 0 && ae == 2'b11, "both channels reset flags");
        end
    endtask

    task automatic write_words(input integer channel, input integer n);
        integer i;
        begin
            for (i = 0; i < n; i++) begin
                @(negedge wr_clk[channel]);
                wr_en[channel] = 1;
                wr_data[channel] = $urandom();
                wr_data[channel][31] = (channel != 0);
            end
            @(negedge wr_clk[channel]);
            wr_en[channel] = 0;
        end
    endtask

    task automatic read_cycles(input integer channel, input integer n, input bit ready_value);
        integer i;
        begin
            for (i = 0; i < n; i++) begin
                @(negedge rd_clk[channel]); rd_en[channel] = 1; rd_ready[channel] = ready_value;
            end
            @(negedge rd_clk[channel]); rd_en[channel] = 0; rd_ready[channel] = 1;
        end
    endtask

    task automatic drain(input integer channel);
        integer watchdog;
        begin
            watchdog = 0;
            @(negedge rd_clk[channel]); rd_en[channel] = 1; rd_ready[channel] = 1;
            while (queued(channel) != 0 || !empty[channel]) begin
                @(negedge rd_clk[channel]);
                watchdog++;
                check(watchdog < 10000, "channel drain timeout");
            end
            rd_en[channel] = 0;
        end
    endtask

    task automatic wait_publication;
        integer watchdog;
        begin
            watchdog = 0;
            while (!snapshot_valid) begin
                @(negedge monitor_clk); watchdog++;
                check(watchdog < 2000, "snapshot handshake timeout");
            end
        end
    endtask

    task automatic take_snapshot;
        integer watchdog;
        begin
            watchdog = 0;
            @(negedge monitor_clk);
            while (!snapshot_ready) begin
                @(negedge monitor_clk); watchdog++;
                check(watchdog < 2000, "snapshot ready timeout");
            end
            snapshot_req = 1;
            @(negedge monitor_clk); snapshot_req = 0;
            wait_publication();
        end
    endtask

    task automatic stable_snapshot;
        begin
            settle();
            take_snapshot();
            check(aw === native_aw && ar === native_ar && bw === native_bw && br === native_br,
                  "quiescent final snapshot statistics/flags");
        end
    endtask

    task automatic thresholds(input integer channel);
        begin
            write_words(channel,224); settle(); check(af[channel], "AF assertion 224");
            read_cycles(channel,1,1); settle(); check(af[channel] == (AF_CLEAR <= 223), "AF 223 hold/clear");
            read_cycles(channel,4,1); settle(); check(!af[channel], "AF clear below 220");
            drain(channel); settle();
            write_words(channel,37); settle(); check(!ae[channel], "AE clear above 36");
            read_cycles(channel,5,1); settle(); check(ae[channel], "AE assertion 32");
            write_words(channel,1); settle(); check(ae[channel] == (AE_CLEAR >= 33), "AE 33 hold/clear");
            write_words(channel,4); settle(); check(!ae[channel], "AE clear 37");
            drain(channel);
        end
    endtask

    task automatic random_write(input integer channel);
        integer i, probability;
        begin
            for (i = 0; i < operations; i++) begin
                @(negedge wr_clk[channel]); decisions[channel] = i;
                if (i < operations/3) probability = 85;
                else if (i < 2*operations/3) probability = 50;
                else probability = 20;
                wr_en[channel] = ($urandom_range(0,99) < probability);
                wr_data[channel] = $urandom(); wr_data[channel][31] = (channel != 0);
            end
            @(negedge wr_clk[channel]); wr_en[channel] = 0; writer_done[channel] = 1;
        end
    endtask

    task automatic random_read(input integer channel);
        integer probability;
        begin
            while (!writer_done[channel]) begin
                @(negedge rd_clk[channel]);
                if (decisions[channel] < operations/3) probability = 20;
                else if (decisions[channel] < 2*operations/3) probability = 50;
                else probability = 90;
                rd_en[channel] = ($urandom_range(0,99) < probability);
                rd_ready[channel] = ($urandom_range(0,99) < 75);
            end
            @(negedge rd_clk[channel]); rd_en[channel] = 0; rd_ready[channel] = 1;
        end
    endtask

    task automatic random_monitor;
        begin
            while (writer_done != 2'b11) begin take_snapshot(); repeat (3) @(negedge monitor_clk); end
        end
    endtask

    integer round_index, bin_index, saved_requests, saved_b_captures, saved_writes_a, saved_writes_b;
    initial begin
        wr_data[0] = 0; wr_data[1] = 0; decisions[0] = 0; decisions[1] = 0;
        parse_result = $value$plusargs("OPS=%d", operations);
        parse_result = $value$plusargs("A_RD_PHASE_PS=%d", a_rd_phase_ps);
        parse_result = $value$plusargs("B_WR_PHASE_PS=%d", b_wr_phase_ps);
        parse_result = $value$plusargs("B_RD_PHASE_PS=%d", b_rd_phase_ps);
        check(operations >= 90 && a_rd_phase_ps >= 0 && b_wr_phase_ps >= 0 && b_rd_phase_ps >= 0, "runtime configuration");
        check(COUNT_WIDTH == 4 || COUNT_WIDTH == 32, "supported test count widths");
        $display("RUN_CONFIG: dual sync=%0d count_width=%0d ops_per_channel=%0d a_rd_phase_ps=%0d b_wr_phase_ps=%0d b_rd_phase_ps=%0d auto=%0d af_clear=%0d ae_clear=%0d",
                 SYNC_STAGES,COUNT_WIDTH,operations,a_rd_phase_ps,b_wr_phase_ps,b_rd_phase_ps,AUTO_REFRESH_CYCLES,AF_CLEAR,AE_CLEAR);
        reset_all(); stable_snapshot();
        $display("TEST: 6.1/6.3 dual_fill_drain_and_errors");
        for (round_index = 0; round_index < 3; round_index++) begin
            saved_writes_a = chan_a.cumulative_writes; saved_writes_b = chan_b.cumulative_writes;
            fork write_words(0,256); write_words(1,256); join
            stable_snapshot();
            check(full == 2'b11 && queued(0) == 256 && queued(1) == 256, "both capacities exactly 256");
            check(chan_a.cumulative_writes-saved_writes_a == 256 && chan_b.cumulative_writes-saved_writes_b == 256,
                  "independent successful write capacities");
            fork write_words(0,20); write_words(1,20); join
            fork drain(0); drain(1); join
            settle();
            fork read_cycles(0,20,1); read_cycles(1,20,1); join
            stable_snapshot();
        end

        $display("TEST: 6.6 dual_state_combinations_and_live_snapshot");
        write_words(0,256); stable_snapshot(); check(full[0] && empty[1], "A full / B empty"); drain(0); settle();
        write_words(1,256); stable_snapshot(); check(full[1] && empty[0], "B full / A empty"); drain(1); settle();
        fork write_words(0,224); write_words(1,224); join
        stable_snapshot(); check(af == 2'b11, "both almost full");
        fork
            read_cycles(0,64,0);
            read_cycles(1,64,0);
            begin #100; take_snapshot(); end
        join
        fork drain(0); drain(1); join
        settle();

        $display("TEST: 6.4 dual_thresholds");
        fork thresholds(0); thresholds(1); join
        settle();
        $display("TEST: 6.5 dual_backpressure");
        fork write_words(0,64); write_words(1,64); join
        settle();
        fork
            begin repeat (20) begin read_cycles(0,1,0); read_cycles(0,1,1); end read_cycles(0,4,0); drain(0); end
            begin repeat (20) begin read_cycles(1,1,0); read_cycles(1,1,1); end read_cycles(1,4,0); drain(1); end
        join
        fork read_cycles(0,5,0); read_cycles(1,5,0); join
        stable_snapshot();

        $display("TEST: 6.2 concurrent_random_mix ops_per_channel=%0d",operations);
        fork random_write(0); random_write(1); random_read(0); random_read(1); random_monitor(); join
        fork drain(0); drain(1); join
        stable_snapshot();
        if (COUNT_WIDTH == 4) check(chan_a.saturation_seen == 6'b111111 && chan_b.saturation_seen == 6'b111111,
                                    "all twelve native counters saturated and checked");

        if (AUTO_REFRESH_CYCLES == 0) begin
            $display("TEST: monitor_stopped_source_busy_request_and_reset_cancel");
            @(negedge monitor_clk); while (!snapshot_ready) @(negedge monitor_clk);
            @(negedge wr_clk[1]); b_write_clock_running = 0;
            saved_requests = epoch_requests; saved_b_captures = captures_bw;
            @(negedge monitor_clk); snapshot_req = 1;
            @(negedge monitor_clk); snapshot_req = 0;
            repeat (12) @(negedge monitor_clk);
            check(snapshot_busy && !snapshot_valid && captures_bw == saved_b_captures, "incomplete snapshot must wait for stopped source");
            snapshot_req = 1; repeat (5) @(negedge monitor_clk); snapshot_req = 0;
            check(epoch_requests == saved_requests+1, "busy requests are not queued or reissued");
            busy_ignored_seen++; clock_pause_seen++;
            b_write_clock_running = 1; wait_publication(); stable_snapshot();

            @(negedge monitor_clk); while (!snapshot_ready) @(negedge monitor_clk);
            @(negedge wr_clk[1]); b_write_clock_running = 0;
            @(negedge monitor_clk); snapshot_req = 1;
            @(negedge monitor_clk); snapshot_req = 0;
            repeat (12) @(negedge monitor_clk); check(snapshot_busy, "request pending before common reset");
            b_write_clock_running = 1; reset_all(); reset_cancel_seen++; stable_snapshot();
        end else begin
            check(auto_requests > 0, "automatic refresh requests observed");
        end

        $display("TEST: common_reset_with_both_channels_nonempty");
        fork write_words(0,13); write_words(1,21); join
        stable_snapshot(); check(queued(0) == 13 && queued(1) == 21, "independent pending data before reset");
        reset_all();
        fork write_words(0,64); write_words(1,64); join
        settle(); fork drain(0); drain(1); join
        stable_snapshot();
        check(chan_a.cumulative_writes == chan_a.cumulative_reads+chan_a.discarded, "A end-to-end accounting");
        check(chan_b.cumulative_writes == chan_b.cumulative_reads+chan_b.discarded, "B end-to-end accounting");
        check(chan_a.write_wraps > 0 && chan_a.read_wraps > 0 && chan_b.write_wraps > 0 && chan_b.read_wraps > 0,
              "all four extended pointers wrapped");
        for (bin_index=0; bin_index<10; bin_index++) begin
            check(chan_a.occupancy_hits[bin_index] > 0 && chan_b.occupancy_hits[bin_index] > 0, "per-channel occupancy coverage");
            $display("COVER_BIN: occupancy_index=%0d a_hits=%0d b_hits=%0d", bin_index,chan_a.occupancy_hits[bin_index],chan_b.occupancy_hits[bin_index]);
        end
        check(combo_a_full_b_empty > 0 && combo_b_full_a_empty > 0 && combo_both_af > 0 && combo_both_bp > 0,
              "required dual-state combination coverage");
        check(chan_a.stall_one > 0 && chan_a.stall_short > 0 && chan_a.stall_long > 0 &&
              chan_b.stall_one > 0 && chan_b.stall_short > 0 && chan_b.stall_long > 0, "backpressure length bins on both channels");
        check(chan_a.full_rise > 0 && chan_a.full_fall > 0 && chan_a.empty_rise > 0 && chan_a.empty_fall > 0 &&
              chan_a.af_rise > 0 && chan_a.af_fall > 0 && chan_a.ae_rise > 0 && chan_a.ae_fall > 0 &&
              chan_b.full_rise > 0 && chan_b.full_fall > 0 && chan_b.empty_rise > 0 && chan_b.empty_fall > 0 &&
              chan_b.af_rise > 0 && chan_b.af_fall > 0 && chan_b.ae_rise > 0 && chan_b.ae_fall > 0, "all flag transition bins on both channels");
        $display("COVER_TRANSITIONS: a_flags=8/8 b_flags=8/8 a_bp_lengths=3/3 b_bp_lengths=3/3");
        $display("CUSTOM_COVERAGE: a_occupancy=10/10 b_occupancy=10/10 dual_combinations=4/4 snapshots=%0d busy_ignored=%0d clock_pause=%0d reset_cancel=%0d auto_requests=%0d",
                 snapshots,busy_ignored_seen,clock_pause_seen,reset_cancel_seen,auto_requests);
        $display("CHANNEL_A: writes=%0d reads=%0d reset_discarded=%0d wrap_w=%0d wrap_r=%0d",chan_a.cumulative_writes,chan_a.cumulative_reads,chan_a.discarded,chan_a.write_wraps,chan_a.read_wraps);
        $display("CHANNEL_B: writes=%0d reads=%0d reset_discarded=%0d wrap_w=%0d wrap_r=%0d",chan_b.cumulative_writes,chan_b.cumulative_reads,chan_b.discarded,chan_b.write_wraps,chan_b.read_wraps);
        $display("RESULT: PASS checks=%0d snapshots=%0d ops_per_channel=%0d",checks+chan_a.checks+chan_b.checks+source_aw.checks+source_ar.checks+source_bw.checks+source_br.checks,snapshots,operations);
        $finish;
    end

    initial begin
        #10000000;
        $display("TIMEOUT: dual FIFO exceeded 10 ms"); $display("RESULT: FAIL"); $fatal(1,"timeout");
    end
endmodule
