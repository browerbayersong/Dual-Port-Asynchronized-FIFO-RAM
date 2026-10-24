`timescale 1ns/1ps
module fifo_performance_tb #(
    parameter integer SYNC_STAGES=2,
    parameter integer BLOCK_CYCLES=0,
    parameter integer A_WRITE_HALF_PS=10000,
    parameter integer A_READ_HALF_PS=6000,
    parameter integer B_WRITE_HALF_PS=17500,
    parameter integer B_READ_HALF_PS=5000
);
    localparam integer COUNT_WIDTH=32, AF_CLEAR=224, AE_CLEAR=32, AUTO_REFRESH_CYCLES=32;
    localparam integer WW=75, RW=139;
    logic rst_n=0, monitor_clk=0, snapshot_req=0;
    logic [1:0] wr_clk=0, rd_clk=0, produce=0, consume=0;
    wire [1:0] wr_en, rd_en, rd_ready;
    logic [31:0] wr_data [0:1];
    wire [31:0] rd_data [0:1];
    wire [1:0] rd_valid,full,empty,af,ae,wr_done,rd_done;
    wire [8:0] wr_level [0:1],rd_level [0:1];
    wire [31:0] writes [0:1],reads [0:1],overflows [0:1],underflows [0:1],bp_events [0:1],bp_cycles [0:1];
    wire snapshot_ready,snapshot_busy,snapshot_valid;
    wire [31:0] snapshot_id;
    wire [WW-1:0] aw,bw;
    wire [RW-1:0] ar,br;
    integer phase=0,checks=0;
    logic [31:0] read_ticks [0:1];
    real first_write [0:1],first_read [0:1];
    real window_start,window_end;
    integer start_reads_a,start_reads_b,start_bp_a,start_bp_b;
    initial forever #(A_WRITE_HALF_PS/1000.0) wr_clk[0]=~wr_clk[0];
    initial forever #(A_READ_HALF_PS/1000.0) rd_clk[0]=~rd_clk[0];
    initial forever #(B_WRITE_HALF_PS/1000.0) wr_clk[1]=~wr_clk[1];
    initial forever #(B_READ_HALF_PS/1000.0) rd_clk[1]=~rd_clk[1];
    initial forever #5 monitor_clk=~monitor_clk;
    genvar g;
    generate for(g=0;g<2;g=g+1) begin: drivers
        assign wr_en[g]=produce[g] && !full[g];
        assign rd_en[g]=consume[g] && !empty[g];
        assign rd_ready[g]=(phase!=3) || ((read_ticks[g]%10)>=BLOCK_CYCLES);
        always @(posedge wr_clk[g] or negedge rst_n) begin
            if(!rst_n) wr_data[g] <= (g==0 ? 32'h00000000 : 32'h80000000);
            else if(wr_done[g] && wr_en[g] && !full[g]) wr_data[g]<=wr_data[g]+1;
        end
        always @(posedge rd_clk[g] or negedge rst_n) begin
            if(!rst_n) read_ticks[g]<=0;
            else read_ticks[g]<=read_ticks[g]+1;
        end
        always @(posedge wr_clk[g])
            if(phase==1 && wr_done[g] && wr_en[g] && !full[g] && first_write[g]<0) first_write[g]=$realtime;
        always @(posedge rd_clk[g])
            if(phase==1 && rd_done[g] && rd_en[g] && rd_ready[g] && !empty[g] && first_read[g]<0) first_read[g]=$realtime;
    end endgenerate
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


    task automatic check(input bit value,input string message);
        checks++;
        if(!value) begin $display("CHECK_FAIL PERF: %s",message); $display("RESULT: FAIL"); $fatal(1,"benchmark check"); end
    endtask
    task automatic reset_all;
        produce=0;consume=0;rst_n=0;
        #200;rst_n=1;#200;
        check((&wr_done)&&(&rd_done)&&empty==2'b11,"benchmark reset");
    endtask
    task automatic one_packet(input integer ch);
        @(negedge rd_clk[ch]);consume[ch]=1;
        @(negedge wr_clk[ch]);produce[ch]=1;
        @(negedge wr_clk[ch]);produce[ch]=0;
        wait(first_read[ch]>=0);
        @(negedge rd_clk[ch]);consume[ch]=0;
        $display("PERF_LATENCY: channel=%0d first_read_ns=%0.3f write_at_ns=%0.3f read_at_ns=%0.3f",ch,first_read[ch]-first_write[ch],first_write[ch],first_read[ch]);
    endtask
    task automatic fill_channel(input integer ch);
        @(negedge wr_clk[ch]);produce[ch]=1;
        wait(full[ch]);
        @(negedge wr_clk[ch]);produce[ch]=0;
    endtask
    task automatic release_full(input integer ch);
        real read_at,release_at;
        @(negedge rd_clk[ch]);consume[ch]=1;
        @(posedge rd_clk[ch]);read_at=$realtime;
        @(negedge rd_clk[ch]);consume[ch]=0;
        wait(!full[ch]);release_at=$realtime;
        $display("PERF_LATENCY: channel=%0d full_release_ns=%0.3f read_at_ns=%0.3f release_at_ns=%0.3f",ch,release_at-read_at,read_at,release_at);
    endtask
    task automatic stop_and_drain(input integer ch);
        integer watchdog=0;
        @(negedge wr_clk[ch]);produce[ch]=0;
        // Allow the final write pointer to reach the read domain before using empty.
        repeat(SYNC_STAGES+3) @(negedge rd_clk[ch]);
        while(!empty[ch]) begin @(negedge rd_clk[ch]); watchdog++; check(watchdog<20000,"benchmark drain timeout"); end
        @(negedge rd_clk[ch]);consume[ch]=0;
    endtask
    initial begin
        first_write[0]=-1;first_write[1]=-1;first_read[0]=-1;first_read[1]=-1;
        check(BLOCK_CYCLES>=0 && BLOCK_CYCLES<10,"invalid block duty cycle");
        $display("PERF_CONFIG: sync=%0d block_cycles=%0d a_wr_half_ps=%0d a_rd_half_ps=%0d b_wr_half_ps=%0d b_rd_half_ps=%0d",SYNC_STAGES,BLOCK_CYCLES,A_WRITE_HALF_PS,A_READ_HALF_PS,B_WRITE_HALF_PS,B_READ_HALF_PS);
        reset_all();#(1000-$realtime);phase=1;
        fork one_packet(0);one_packet(1);join
        #(2000-$realtime);phase=2;reset_all();
        fork fill_channel(0);fill_channel(1);join
        check(full==2'b11,"full benchmark precondition");
        fork release_full(0);release_full(1);join
        #(20000-$realtime);phase=3;reset_all();
        #(21000-$realtime);produce=2'b11;consume=2'b11;
        #(40000-$realtime);#0.001;
        window_start=$realtime;start_reads_a=chan_a.cumulative_reads;start_reads_b=chan_b.cumulative_reads;
        start_bp_a=chan_a.epoch_bp_cycles;start_bp_b=chan_b.epoch_bp_cycles;
        #(240000-$realtime);#0.001;window_end=$realtime;
        $display("PERF_WINDOW: channel=0 duration_ns=%0.3f reads=%0d words_per_s=%0.3f mbps=%0.3f stall_cycles=%0d",window_end-window_start,chan_a.cumulative_reads-start_reads_a,(chan_a.cumulative_reads-start_reads_a)*1.0e9/(window_end-window_start),(chan_a.cumulative_reads-start_reads_a)*32000.0/(window_end-window_start),chan_a.epoch_bp_cycles-start_bp_a);
        $display("PERF_WINDOW: channel=1 duration_ns=%0.3f reads=%0d words_per_s=%0.3f mbps=%0.3f stall_cycles=%0d",window_end-window_start,chan_b.cumulative_reads-start_reads_b,(chan_b.cumulative_reads-start_reads_b)*1.0e9/(window_end-window_start),(chan_b.cumulative_reads-start_reads_b)*32000.0/(window_end-window_start),chan_b.epoch_bp_cycles-start_bp_b);
        fork stop_and_drain(0);stop_and_drain(1);join
        #1000;
        $display("PERF_ACCOUNTING: A writes=%0d reads=%0d discarded=%0d pending=%0d B writes=%0d reads=%0d discarded=%0d pending=%0d",chan_a.cumulative_writes,chan_a.cumulative_reads,chan_a.discarded,chan_a.reference_queue.size(),chan_b.cumulative_writes,chan_b.cumulative_reads,chan_b.discarded,chan_b.reference_queue.size());
        check(chan_a.cumulative_writes==chan_a.cumulative_reads+chan_a.discarded,"A benchmark accounting");
        check(chan_b.cumulative_writes==chan_b.cumulative_reads+chan_b.discarded,"B benchmark accounting");
        $display("RESULT: PASS performance checks=%0d",checks+chan_a.checks+chan_b.checks);$finish;
    end
    initial begin #1000000;$display("TIMEOUT performance");$display("RESULT: FAIL");$fatal(1,"timeout");end
endmodule
