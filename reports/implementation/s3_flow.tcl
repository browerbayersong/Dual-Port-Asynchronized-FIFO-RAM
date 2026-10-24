cd [file dirname [info script]]
if {[catch {
    import_device ph1_100.db -package PH1A100SFG676 -speed 2
    set_param flow thread 4
    set_param rtl keep_hierarchy on
    set_param rtl merge_equal off
    set_param rtl seq_syn off
    set_param rtl infer_shifter off
    set_param gate pack_seq_in_io off
    set_param place seed 1
    read_hdl -file {rtl/reset_sync.v rtl/gray_sync.v rtl/fifo_ram.v rtl/async_fifo.v rtl/snapshot_mailbox.v rtl/fifo_monitor.v rtl/dual_async_fifo.v analysis/dual_fifo_eval.v} -top dual_fifo_eval
    optimize_rtl
    report_area -verbose -file rtl.area
    source constraints/td_endpoint_audit.tcl
    read_sdc constraints/td_eval.sdc
    optimize_gate
    legalize_phy_inst
    source constraints/td_endpoint_audit.tcl
    read_sdc constraints/td_eval.sdc
    report_area -verbose -file gate.area
    write_verilog gate.v
    export_db gate.db
    place
    update_timing -mode manhattan
    report_area -verbose -io_info -file place.area
    report_timing_summary -file place.timing
    export_db place.db
    route
    update_timing -mode final
    export_db route.db
    report_area -verbose -io_info -file route.area
    report_timing_status -file route.status
    report_timing_summary -file route.timing -ep_num 20
    report_timing_exception -file exceptions.timing -ep_num 100
    report_timing_ignored -file ignored.timing -ep_num 20
    report_clock_summary -file clocks.rpt
    report_route_status -file routing.rpt
    export_sdc -file effective.sdc
    foreach clock {a_wr_clk a_rd_clk b_wr_clk b_rd_clk monitor_clk} {
        report_timing_path -from [get_clocks $clock] -to [get_clocks $clock] -file ${clock}.timing -ep_num 10
    }
    # Select internal register endpoints for a second report, without changing any SDC.
    set internal_regs {}
    foreach object [get_regs -hier -regexp {^dut/.*}] {
        if {[regexp {^dut/} $object]} {lappend internal_regs $object}
    }
    puts "INTERNAL_REG_NETS=[llength $internal_regs]"
    report_timing_path -from $internal_regs -to $internal_regs -file core.timing -ep_num 20
    puts "IMPLEMENTATION: PASS"
} msg opts]} {puts "IMPLEMENTATION: FAIL $msg";puts [dict get $opts -errorinfo];exit 1}
exit
