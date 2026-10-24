create_clock -name a_wr_clk -period 20 [get_ports a_wr_clk]
set_clock_uncertainty 0.2 [get_clocks a_wr_clk]
create_clock -name a_rd_clk -period 12 [get_ports a_rd_clk]
set_clock_uncertainty 0.2 [get_clocks a_rd_clk]
create_clock -name b_wr_clk -period 35 [get_ports b_wr_clk]
set_clock_uncertainty 0.2 [get_clocks b_wr_clk]
create_clock -name b_rd_clk -period 10 [get_ports b_rd_clk]
set_clock_uncertainty 0.2 [get_clocks b_rd_clk]
create_clock -name monitor_clk -period 10 [get_ports monitor_clk]
set_clock_uncertainty 0.2 [get_clocks monitor_clk]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/fifo_a/u_r2w/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_a/u_r2w/pipe\[0\]\[[0-8]\]$}] 12
set_false_path -hold -from [get_regs -hier -regexp {^dut/fifo_a/u_r2w/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_a/u_r2w/pipe\[0\]\[[0-8]\]$}]
set_max_skew -from [get_regs -hier -regexp {^dut/fifo_a/u_r2w/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_a/u_r2w/pipe\[0\]\[[0-8]\]$}] 12
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/fifo_a/u_w2r/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_a/u_w2r/pipe\[0\]\[[0-8]\]$}] 20
set_false_path -hold -from [get_regs -hier -regexp {^dut/fifo_a/u_w2r/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_a/u_w2r/pipe\[0\]\[[0-8]\]$}]
set_max_skew -from [get_regs -hier -regexp {^dut/fifo_a/u_w2r/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_a/u_w2r/pipe\[0\]\[[0-8]\]$}] 20
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/fifo_b/u_r2w/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_b/u_r2w/pipe\[0\]\[[0-8]\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/fifo_b/u_r2w/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_b/u_r2w/pipe\[0\]\[[0-8]\]$}]
set_max_skew -from [get_regs -hier -regexp {^dut/fifo_b/u_r2w/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_b/u_r2w/pipe\[0\]\[[0-8]\]$}] 10
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/fifo_b/u_w2r/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_b/u_w2r/pipe\[0\]\[[0-8]\]$}] 35
set_false_path -hold -from [get_regs -hier -regexp {^dut/fifo_b/u_w2r/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_b/u_w2r/pipe\[0\]\[[0-8]\]$}]
set_max_skew -from [get_regs -hier -regexp {^dut/fifo_b/u_w2r/gray_in\[[0-8]\]$}] -to [get_regs -hier -regexp {^dut/fifo_b/u_w2r/pipe\[0\]\[[0-8]\]$}] 35
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/request_toggle$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_a_write/u_request_sync/pipe\[0\]\[0\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/request_toggle$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_a_write/u_request_sync/pipe\[0\]\[0\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/u_a_write/source_ack$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_a_write/u_ack_sync/pipe\[0\]\[0\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/u_a_write/source_ack$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_a_write/u_ack_sync/pipe\[0\]\[0\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/u_a_write/held_data\[[0-9]+\]$}] -to [get_regs -hier -regexp {^dut/u_monitor/a_write_status\[[0-9]+\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/u_a_write/held_data\[[0-9]+\]$}] -to [get_regs -hier -regexp {^dut/u_monitor/a_write_status\[[0-9]+\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/request_toggle$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_a_read/u_request_sync/pipe\[0\]\[0\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/request_toggle$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_a_read/u_request_sync/pipe\[0\]\[0\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/u_a_read/source_ack$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_a_read/u_ack_sync/pipe\[0\]\[0\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/u_a_read/source_ack$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_a_read/u_ack_sync/pipe\[0\]\[0\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/u_a_read/held_data\[[0-9]+\]$}] -to [get_regs -hier -regexp {^dut/u_monitor/a_read_status\[[0-9]+\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/u_a_read/held_data\[[0-9]+\]$}] -to [get_regs -hier -regexp {^dut/u_monitor/a_read_status\[[0-9]+\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/request_toggle$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_b_write/u_request_sync/pipe\[0\]\[0\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/request_toggle$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_b_write/u_request_sync/pipe\[0\]\[0\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/u_b_write/source_ack$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_b_write/u_ack_sync/pipe\[0\]\[0\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/u_b_write/source_ack$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_b_write/u_ack_sync/pipe\[0\]\[0\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/u_b_write/held_data\[[0-9]+\]$}] -to [get_regs -hier -regexp {^dut/u_monitor/b_write_status\[[0-9]+\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/u_b_write/held_data\[[0-9]+\]$}] -to [get_regs -hier -regexp {^dut/u_monitor/b_write_status\[[0-9]+\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/request_toggle$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_b_read/u_request_sync/pipe\[0\]\[0\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/request_toggle$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_b_read/u_request_sync/pipe\[0\]\[0\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/u_b_read/source_ack$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_b_read/u_ack_sync/pipe\[0\]\[0\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/u_b_read/source_ack$}] -to [get_regs -hier -regexp {^dut/u_monitor/u_b_read/u_ack_sync/pipe\[0\]\[0\]$}]
set_max_delay -datapath_only -from [get_regs -hier -regexp {^dut/u_monitor/u_b_read/held_data\[[0-9]+\]$}] -to [get_regs -hier -regexp {^dut/u_monitor/b_read_status\[[0-9]+\]$}] 10
set_false_path -hold -from [get_regs -hier -regexp {^dut/u_monitor/u_b_read/held_data\[[0-9]+\]$}] -to [get_regs -hier -regexp {^dut/u_monitor/b_read_status\[[0-9]+\]$}]
set_input_delay -clock [get_clocks a_wr_clk] -max 4 [get_ports {a_wr_en a_wr_data*}]
set_input_delay -clock [get_clocks a_wr_clk] -min 0.5 [get_ports {a_wr_en a_wr_data*}]
set_input_delay -clock [get_clocks a_rd_clk] -max 2.4 [get_ports {a_rd_en a_rd_ready}]
set_input_delay -clock [get_clocks a_rd_clk] -min 0.5 [get_ports {a_rd_en a_rd_ready}]
set_input_delay -clock [get_clocks b_wr_clk] -max 7 [get_ports {b_wr_en b_wr_data*}]
set_input_delay -clock [get_clocks b_wr_clk] -min 0.5 [get_ports {b_wr_en b_wr_data*}]
set_input_delay -clock [get_clocks b_rd_clk] -max 2 [get_ports {b_rd_en b_rd_ready}]
set_input_delay -clock [get_clocks b_rd_clk] -min 0.5 [get_ports {b_rd_en b_rd_ready}]
set_input_delay -clock [get_clocks monitor_clk] -max 2 [get_ports {snapshot_req}]
set_input_delay -clock [get_clocks monitor_clk] -min 0.5 [get_ports {snapshot_req}]
set_output_delay -clock [get_clocks a_wr_clk] -max 4 [get_ports {a_full a_almost_full a_wr_level* a_wr_rst_done}]
set_output_delay -clock [get_clocks a_wr_clk] -min 0.5 [get_ports {a_full a_almost_full a_wr_level* a_wr_rst_done}]
set_output_delay -clock [get_clocks a_rd_clk] -max 2.4 [get_ports {a_empty a_almost_empty a_rd_data* a_rd_level* a_rd_rst_done}]
set_output_delay -clock [get_clocks a_rd_clk] -min 0.5 [get_ports {a_empty a_almost_empty a_rd_data* a_rd_level* a_rd_rst_done}]
set_output_delay -clock [get_clocks b_wr_clk] -max 7 [get_ports {b_full b_almost_full b_wr_level* b_wr_rst_done}]
set_output_delay -clock [get_clocks b_wr_clk] -min 0.5 [get_ports {b_full b_almost_full b_wr_level* b_wr_rst_done}]
set_output_delay -clock [get_clocks b_rd_clk] -max 2 [get_ports {b_empty b_almost_empty b_rd_data* b_rd_level* b_rd_rst_done}]
set_output_delay -clock [get_clocks b_rd_clk] -min 0.5 [get_ports {b_empty b_almost_empty b_rd_data* b_rd_level* b_rd_rst_done}]
set_output_delay -clock [get_clocks monitor_clk] -max 2 [get_ports {snapshot_ready snapshot_busy snapshot_valid}]
set_output_delay -clock [get_clocks monitor_clk] -min 0.5 [get_ports {snapshot_ready snapshot_busy snapshot_valid}]
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {status_select*}]
set_false_path -to [get_ports {status_data*}]
