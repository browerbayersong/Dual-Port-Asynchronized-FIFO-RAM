"""Target-specific software implementation. No board, bitstream or programmer required."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--td-bin',type=Path,default=Path('D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/bin/td_commands_prompt.exe'))
    ap.add_argument('--build-root',type=Path,default=Path('D:/fifo_build'))
    ap.add_argument('--stages',type=int,choices=[2,3],nargs='+',default=[2,3])
    ap.add_argument('--resume',choices=['place','route'],help='Resume only a matching saved implementation database')
    args=ap.parse_args()
    if not str(args.build_root).isascii():raise RuntimeError('Use an ASCII build root')
    out=ROOT/'reports/implementation';out.mkdir(parents=True,exist_ok=True)
    rtl=(ROOT/'sim/dual_rtl.f').read_text().split()+['analysis/dual_fifo_eval.v']
    files=rtl+['constraints/td_eval.sdc','constraints/td_endpoint_audit.tcl']
    manifest={'device':'PH1A100SFG676','speed':2,'assumption':'software evaluation target selected for installed tool; not specified by coursework',
        'source_sha256_lf':{f:hashlib.sha256((ROOT/f).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for f in files},'runs':[]}
    for stages in args.stages:
        build=args.build_root/f'impl_s{stages}';build.mkdir(parents=True,exist_ok=True)
        for f in files:
            expected=(ROOT/f).read_text()
            if f=='analysis/dual_fifo_eval.v':expected=re.sub(r'(parameter integer SYNC_STAGES = )2',rf'\g<1>{stages}',expected,count=1)
            if args.resume and f in rtl+['constraints/td_eval.sdc'] and (not (build/f).exists() or (build/f).read_text()!=expected):
                raise RuntimeError('Cannot resume stale/missing source '+f)
            (build/f).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/f,build/f)
        # Change only a copied wrapper parameter default; the delivered core RTL is untouched.
        wrapper=build/'analysis/dual_fifo_eval.v'
        wrapper.write_text(re.sub(r'(parameter integer SYNC_STAGES = )2',rf'\g<1>{stages}',wrapper.read_text(),count=1))
        flow='''cd [file dirname [info script]]
if {[catch {
    import_device ph1_100.db -package PH1A100SFG676 -speed 2
    set_param flow thread 4
    set_param rtl keep_hierarchy on
    set_param rtl merge_equal off
    set_param rtl seq_syn off
    set_param rtl infer_shifter off
    set_param gate pack_seq_in_io off
    set_param place seed 1
    read_hdl -file {'''+ ' '.join(rtl)+'''} -top dual_fifo_eval
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
'''
        flowname='flow.tcl'
        (build/flowname).write_text(flow,encoding='ascii')
        if args.resume:
            db=args.resume+'.db'
            if not (build/db).exists():raise RuntimeError('Missing resume database '+str(build/db))
            cut=flow.index('    route\n') if args.resume=='place' else flow.index('    update_timing -mode final\n')
            flow='''cd [file dirname [info script]]
if {[catch {
    import_device ph1_100.db -package PH1A100SFG676 -speed 2
    import_db '''+db+'''
    source constraints/td_endpoint_audit.tcl
'''+flow[cut:]
            flowname='resume_'+args.resume+'.tcl'
        (build/flowname).write_text(flow,encoding='ascii')
        print('IMPLEMENTATION: running',stages,flush=True)
        with (out/f's{stages}_flow.log').open('w',encoding='utf-8') as log:
            proc=subprocess.run([str(args.td_bin),(build/flowname).as_posix()],cwd=build,stdout=log,stderr=subprocess.STDOUT)
        text=(out/f's{stages}_flow.log').read_text(encoding='utf-8',errors='replace')
        reports={'rtl.area','gate.area','place.area','place.timing','route.area','route.timing','route.status',
            'exceptions.timing','ignored.timing','clocks.rpt','routing.rpt','effective.sdc','core.timing','flow.tcl',flowname}
        reports.update(c+'.timing' for c in ['a_wr_clk','a_rd_clk','b_wr_clk','b_rd_clk','monitor_clk'])
        for p in build.glob('*'):
            if p.is_file() and p.name in reports:
                shutil.copyfile(p,out/f's{stages}_{p.name}')
        if proc.returncode or 'IMPLEMENTATION: PASS' not in text or ' ERROR:' in text:
            raise RuntimeError(f'Implementation failed: {out/f"s{stages}_flow.log"}')
        timing=(build/'route.timing').read_text(errors='replace')
        if not (build/'effective.sdc').exists():raise RuntimeError('Missing exported active SDC')
        if text.count('CDC_BOUND:')!=(16 if args.resume else 32) or 'DeriveClock' in timing:
            raise RuntimeError('Clock or CDC constraints did not take effect')
        internal=(build/'core.timing').read_text(errors='replace')
        for clock in ['a_wr_clk','a_rd_clk','b_wr_clk','b_rd_clk','monitor_clk']:
            if f'{clock} -> {clock}' not in internal:raise RuntimeError('Missing internal clock group '+clock)
        if 'DeriveClock' in internal:raise RuntimeError('Invalid default-clock internal report')
        manifest['runs'].append({'sync_stages':stages,'build':str(build),'result':'FLOW_COMPLETED','resume_from':args.resume,
            'note':'Flow completion does not imply timing closure; see measured setup/hold slack.',
            'wrapper_staged_sha256_lf':hashlib.sha256(wrapper.read_bytes().replace(b'\r\n',b'\n')).hexdigest()})
        (out/f's{stages}_manifest.json').write_text(json.dumps({**manifest,'runs':[manifest['runs'][-1]]},indent=2)+'\n')
        combined=[]
        for m in out.glob('s*_manifest.json'):
            item=json.loads(m.read_text())
            if item.get('source_sha256_lf')==manifest['source_sha256_lf']:combined.extend(item['runs'])
        (out/'manifest.json').write_text(json.dumps({**manifest,'runs':sorted(combined,key=lambda x:x['sync_stages'])},indent=2)+'\n')
        print('IMPLEMENTATION: PASS',stages,flush=True)


if __name__=='__main__':main()
