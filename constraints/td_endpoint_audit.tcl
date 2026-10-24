# Source this Tcl only to audit endpoints; apply the separate SDC with read_sdc.
proc exact_regs {pattern} {
    set result {}
    foreach object [get_regs -hier -regexp $pattern] {if {[regexp $pattern $object]} {lappend result $object}}
    return $result
}
set src [exact_regs {^dut/fifo_a/u_r2w/gray_in\[[0-8]\]$}]
set dst [exact_regs {^dut/fifo_a/u_r2w/pipe\[0\]\[[0-8]\]$}]
if {[llength $src]!=9 || [llength $dst]!=9} {error "CDC endpoints missing: a_r2w src=[llength $src] dst=[llength $dst] expected=9"}
puts "CDC_BOUND: a_r2w sources=[llength $src] destinations=[llength $dst] max_ns=12 skew=1"
set src [exact_regs {^dut/fifo_a/u_w2r/gray_in\[[0-8]\]$}]
set dst [exact_regs {^dut/fifo_a/u_w2r/pipe\[0\]\[[0-8]\]$}]
if {[llength $src]!=9 || [llength $dst]!=9} {error "CDC endpoints missing: a_w2r src=[llength $src] dst=[llength $dst] expected=9"}
puts "CDC_BOUND: a_w2r sources=[llength $src] destinations=[llength $dst] max_ns=20 skew=1"
set src [exact_regs {^dut/fifo_b/u_r2w/gray_in\[[0-8]\]$}]
set dst [exact_regs {^dut/fifo_b/u_r2w/pipe\[0\]\[[0-8]\]$}]
if {[llength $src]!=9 || [llength $dst]!=9} {error "CDC endpoints missing: b_r2w src=[llength $src] dst=[llength $dst] expected=9"}
puts "CDC_BOUND: b_r2w sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=1"
set src [exact_regs {^dut/fifo_b/u_w2r/gray_in\[[0-8]\]$}]
set dst [exact_regs {^dut/fifo_b/u_w2r/pipe\[0\]\[[0-8]\]$}]
if {[llength $src]!=9 || [llength $dst]!=9} {error "CDC endpoints missing: b_w2r src=[llength $src] dst=[llength $dst] expected=9"}
puts "CDC_BOUND: b_w2r sources=[llength $src] destinations=[llength $dst] max_ns=35 skew=1"
set src [exact_regs {^dut/u_monitor/request_toggle$}]
set dst [exact_regs {^dut/u_monitor/u_a_write/u_request_sync/pipe\[0\]\[0\]$}]
if {[llength $src]!=1 || [llength $dst]!=1} {error "CDC endpoints missing: a_write_request src=[llength $src] dst=[llength $dst] expected=1"}
puts "CDC_BOUND: a_write_request sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/u_a_write/source_ack$}]
set dst [exact_regs {^dut/u_monitor/u_a_write/u_ack_sync/pipe\[0\]\[0\]$}]
if {[llength $src]!=1 || [llength $dst]!=1} {error "CDC endpoints missing: a_write_ack src=[llength $src] dst=[llength $dst] expected=1"}
puts "CDC_BOUND: a_write_ack sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/u_a_write/held_data\[[0-9]+\]$}]
set dst [exact_regs {^dut/u_monitor/a_write_status\[[0-9]+\]$}]
if {[llength $src]!=75 || [llength $dst]!=75} {error "CDC endpoints missing: a_write_held src=[llength $src] dst=[llength $dst] expected=75"}
puts "CDC_BOUND: a_write_held sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/request_toggle$}]
set dst [exact_regs {^dut/u_monitor/u_a_read/u_request_sync/pipe\[0\]\[0\]$}]
if {[llength $src]!=1 || [llength $dst]!=1} {error "CDC endpoints missing: a_read_request src=[llength $src] dst=[llength $dst] expected=1"}
puts "CDC_BOUND: a_read_request sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/u_a_read/source_ack$}]
set dst [exact_regs {^dut/u_monitor/u_a_read/u_ack_sync/pipe\[0\]\[0\]$}]
if {[llength $src]!=1 || [llength $dst]!=1} {error "CDC endpoints missing: a_read_ack src=[llength $src] dst=[llength $dst] expected=1"}
puts "CDC_BOUND: a_read_ack sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/u_a_read/held_data\[[0-9]+\]$}]
set dst [exact_regs {^dut/u_monitor/a_read_status\[[0-9]+\]$}]
if {[llength $src]!=139 || [llength $dst]!=139} {error "CDC endpoints missing: a_read_held src=[llength $src] dst=[llength $dst] expected=139"}
puts "CDC_BOUND: a_read_held sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/request_toggle$}]
set dst [exact_regs {^dut/u_monitor/u_b_write/u_request_sync/pipe\[0\]\[0\]$}]
if {[llength $src]!=1 || [llength $dst]!=1} {error "CDC endpoints missing: b_write_request src=[llength $src] dst=[llength $dst] expected=1"}
puts "CDC_BOUND: b_write_request sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/u_b_write/source_ack$}]
set dst [exact_regs {^dut/u_monitor/u_b_write/u_ack_sync/pipe\[0\]\[0\]$}]
if {[llength $src]!=1 || [llength $dst]!=1} {error "CDC endpoints missing: b_write_ack src=[llength $src] dst=[llength $dst] expected=1"}
puts "CDC_BOUND: b_write_ack sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/u_b_write/held_data\[[0-9]+\]$}]
set dst [exact_regs {^dut/u_monitor/b_write_status\[[0-9]+\]$}]
if {[llength $src]!=75 || [llength $dst]!=75} {error "CDC endpoints missing: b_write_held src=[llength $src] dst=[llength $dst] expected=75"}
puts "CDC_BOUND: b_write_held sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/request_toggle$}]
set dst [exact_regs {^dut/u_monitor/u_b_read/u_request_sync/pipe\[0\]\[0\]$}]
if {[llength $src]!=1 || [llength $dst]!=1} {error "CDC endpoints missing: b_read_request src=[llength $src] dst=[llength $dst] expected=1"}
puts "CDC_BOUND: b_read_request sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/u_b_read/source_ack$}]
set dst [exact_regs {^dut/u_monitor/u_b_read/u_ack_sync/pipe\[0\]\[0\]$}]
if {[llength $src]!=1 || [llength $dst]!=1} {error "CDC endpoints missing: b_read_ack src=[llength $src] dst=[llength $dst] expected=1"}
puts "CDC_BOUND: b_read_ack sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
set src [exact_regs {^dut/u_monitor/u_b_read/held_data\[[0-9]+\]$}]
set dst [exact_regs {^dut/u_monitor/b_read_status\[[0-9]+\]$}]
if {[llength $src]!=139 || [llength $dst]!=139} {error "CDC endpoints missing: b_read_held src=[llength $src] dst=[llength $dst] expected=139"}
puts "CDC_BOUND: b_read_held sources=[llength $src] destinations=[llength $dst] max_ns=10 skew=0"
