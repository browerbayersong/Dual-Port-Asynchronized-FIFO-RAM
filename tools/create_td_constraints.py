"""Emit plain SDC for TD's file parser and separate Tcl endpoint audits."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def definitions():
    rows=[]
    for channel,read_period,write_period in [('a',12,20),('b',10,35)]:
        for direction,period in [('r2w',read_period),('w2r',write_period)]:
            base=f'dut/fifo_{channel}/u_{direction}'
            rows.append((f'{channel}_{direction}',rf'^{base}/gray_in\[[0-8]\]$',rf'^{base}/pipe\[0\]\[[0-8]\]$',9,period,True))
    for src,dst,bits in [('a_write','a_write_status',75),('a_read','a_read_status',139),('b_write','b_write_status',75),('b_read','b_read_status',139)]:
        base='dut/u_monitor/u_'+src
        rows += [(src+'_request',r'^dut/u_monitor/request_toggle$',rf'^{base}/u_request_sync/pipe\[0\]\[0\]$',1,10,False),
                 (src+'_ack',rf'^{base}/source_ack$',rf'^{base}/u_ack_sync/pipe\[0\]\[0\]$',1,10,False),
                 (src+'_held',rf'^{base}/held_data\[[0-9]+\]$',rf'^dut/u_monitor/{dst}\[[0-9]+\]$',bits,10,False)]
    return rows


def main():
    lines=['# Software evaluation: PH1A100SFG676 speed 2. All times in ns.',
           '# Plain SDC only: TD read_sdc does not execute arbitrary Tcl loops/procedures.',
           '# No broad asynchronous clock groups or setup false paths on CDC data.']
    for name,period in [('a_wr_clk',20),('a_rd_clk',12),('b_wr_clk',35),('b_rd_clk',10),('monitor_clk',10)]:
        lines += [f'create_clock -name {name} -period {period} [get_ports {name}]',
                  f'set_clock_uncertainty 0.2 [get_clocks {name}]']
    audit=['# Source this Tcl only to audit endpoints; apply the separate SDC with read_sdc.',
           'proc exact_regs {pattern} {', '    set result {}',
           '    foreach object [get_regs -hier -regexp $pattern] {if {[regexp $pattern $object]} {lappend result $object}}',
           '    return $result','}']
    for label,src,dst,bits,bound,skew in definitions():
        source=f'[get_regs -hier -regexp {{{src}}}]';dest=f'[get_regs -hier -regexp {{{dst}}}]'
        lines += [f'# {label}: {bits} bits; held buses are bounded within one guard clock period.',
                  f'set_max_delay -datapath_only -from {source} -to {dest} {bound}',
                  f'set_false_path -hold -from {source} -to {dest}']
        if skew:lines.append(f'set_max_skew -from {source} -to {dest} {bound}')
        audit += [f'set src [exact_regs {{{src}}}]',f'set dst [exact_regs {{{dst}}}]',
                  f'if {{[llength $src]!={bits} || [llength $dst]!={bits}}} {{error "CDC endpoints missing: {label} src=[llength $src] dst=[llength $dst] expected={bits}"}}',
                  f'puts "CDC_BOUND: {label} sources=[llength $src] destinations=[llength $dst] max_ns={bound} skew={int(skew)}"']
    for clock,budget,signals in [('a_wr_clk',4,'a_wr_en a_wr_data*'),('a_rd_clk',2.4,'a_rd_en a_rd_ready'),
        ('b_wr_clk',7,'b_wr_en b_wr_data*'),('b_rd_clk',2,'b_rd_en b_rd_ready'),('monitor_clk',2,'snapshot_req')]:
        lines += [f'set_input_delay -clock [get_clocks {clock}] -max {budget} [get_ports {{{signals}}}]',
                  f'set_input_delay -clock [get_clocks {clock}] -min 0.5 [get_ports {{{signals}}}]']
    for clock,budget,signals in [('a_wr_clk',4,'a_full a_almost_full a_wr_level* a_wr_rst_done'),
        ('a_rd_clk',2.4,'a_empty a_almost_empty a_rd_data* a_rd_level* a_rd_rst_done'),
        ('b_wr_clk',7,'b_full b_almost_full b_wr_level* b_wr_rst_done'),
        ('b_rd_clk',2,'b_empty b_almost_empty b_rd_data* b_rd_level* b_rd_rst_done'),('monitor_clk',2,'snapshot_ready snapshot_busy snapshot_valid')]:
        lines += [f'set_output_delay -clock [get_clocks {clock}] -max {budget} [get_ports {{{signals}}}]',
                  f'set_output_delay -clock [get_clocks {clock}] -min 0.5 [get_ports {{{signals}}}]']
    lines += ['# Common asynchronous reset input; recovery/removal of the external reset is excluded.',
              'set_false_path -from [get_ports rst_n]',
              '# Diagnostic mux has no sequential feedback; its LUTs/IOs remain in area/power.',
              'set_false_path -from [get_ports {status_select*}]','set_false_path -to [get_ports {status_data*}]']
    (ROOT/'constraints/td_eval.sdc').write_text('\n'.join(lines)+'\n',encoding='ascii')
    (ROOT/'constraints/td_endpoint_audit.tcl').write_text('\n'.join(audit)+'\n',encoding='ascii')


if __name__=='__main__':main()
