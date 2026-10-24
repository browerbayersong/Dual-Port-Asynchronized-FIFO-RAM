"""ModelSim input trace -> Verilator native cover-property/line database + scoreboard.

No unsupported covergroups are accepted. Raw native databases remain the evidence.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

REPO = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--build-root',type=Path,default=Path('D:/fifo_build'))
    ap.add_argument('--packages',type=Path,default=Path('D:/fifo_tools/python'))
    ap.add_argument('--zig',type=Path,default=Path('D:/fifo_tools/compiler/ziglang/zig.exe'))
    ap.add_argument('--simulator-bin',type=Path,default=Path('D:/altera/14.1/modelsim_ase/win32aloem'))
    ap.add_argument('--quick',action='store_true')
    ap.add_argument('--reuse',action='store_true',help='Reuse compiled model only if source/config hashes match')
    args=ap.parse_args()
    build=args.build_root/'native_common'
    if not str(build.resolve()).isascii():raise RuntimeError('ASCII-only build path required')
    out=REPO/'reports/native_coverage';out.mkdir(parents=True,exist_ok=True)
    rtl=(REPO/'sim/dual_rtl.f').read_text().split()
    tb=(REPO/'sim/dual_tb.f').read_text().split()
    files=rtl+tb+['tb/native_coverage_top.sv','tools/native_replay.cpp']
    manifest={f:hashlib.sha256((REPO/f).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for f in files}
    for f in files:
        (build/f).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(REPO/f,build/f)
    env=os.environ.copy();root=args.packages/'verilator'
    env['VERILATOR_ROOT']=str(root);env['ZIG_GLOBAL_CACHE_DIR']=str(args.build_root/'zig_cache')
    verilator=root/'bin/verilator_bin.exe'
    def run(argv,log,expected=0):
        with log.open('w',encoding='utf-8') as f:
            p=subprocess.run([str(x) for x in argv],cwd=build,env=env,stdout=f,stderr=subprocess.STDOUT)
        if p.returncode!=expected:raise RuntimeError(f'Command exit {p.returncode}; see {log}')
        return log.read_text(encoding='utf-8',errors='replace')
    if not (build/'modelsim.ini').exists():run([args.simulator_bin/'vmap.exe','-c'],build/'map.log')
    if not (build/'work').exists():run([args.simulator_bin/'vlib.exe','work'],build/'lib.log')
    run([args.simulator_bin/'vlog.exe',*rtl],build/'rtl.log')
    run([args.simulator_bin/'vlog.exe','-sv',*tb],build/'tb.log')
    configs=[dict(name='s2_manual',stages=2,count=32,auto=0,af=224,ae=32,seed=1),
             dict(name='s3_auto_hysteresis_saturation',stages=3,count=4,auto=8,af=220,ae=36,seed=2026)]
    if args.quick:configs=configs[:1]
    rows=[]
    for c in configs:
        c.update(ops_per_channel=5000,a_rd_phase_ps=1000,b_wr_phase_ps=2500,b_rd_phase_ps=500,
                 a_write_period_ps=20000,a_read_period_ps=12000,b_write_period_ps=35000,b_read_period_ps=10000,monitor_period_ps=10000)
        name=c['name'];obj=build/('obj_'+name);obj.mkdir(exist_ok=True)
        vlog_log=out/(name+'_verilate.log')
        params=[f'-GSYNC_STAGES={c["stages"]}',f'-GCOUNT_WIDTH={c["count"]}',f'-GAUTO_REFRESH_CYCLES={c["auto"]}',f'-GAF_CLEAR={c["af"]}',f'-GAE_CLEAR={c["ae"]}']
        key=json.dumps({'manifest':manifest,'params':params},sort_keys=True)
        keyfile=obj/'build_key.json';exe=obj/'replay.exe'
        if not(args.reuse and keyfile.exists() and keyfile.read_text()==key and exe.exists()):
            text=run([verilator,'--cc','--coverage-user','--coverage-line','--assert','-Wno-fatal',
                      '--top-module','native_coverage_top','--Mdir',obj,*params,*rtl,'tb/native_coverage_top.sv'],vlog_log)
            if re.search(r'COVERIGN|UNSUPPORTED|Unsupported|%Error',text):raise RuntimeError('Unsupported coverage/assertion instrumentation')
            cpp=list(obj.glob('*.cpp'))+[build/'tools/native_replay.cpp',root/'include/verilated.cpp',
                root/'include/verilated_threads.cpp',root/'include/verilated_cov.cpp']
            print('NATIVE: compiling',name,flush=True)
            run([args.zig,'c++','-std=c++20','-O0','-DVL_TIME_CONTEXT','-DVM_COVERAGE=1','-DVM_TRACE=0',
                '-I'+str(obj),'-I'+str(root/'include'),'-I'+str(root/'include/vltstd'),*cpp,'-o',exe],out/(name+'_build.log'))
            keyfile.write_text(key)
        inputs=['rst_n','a_wr_clk','a_wr_en','a_wr_data','a_rd_clk','a_rd_en','a_rd_ready',
                'b_wr_clk','b_wr_en','b_wr_data','b_rd_clk','b_rd_en','b_rd_ready','monitor_clk','snapshot_req']
        trace=name+'.vcd'
        commands=f'vcd file {trace}; vcd add '+' '.join('/dual_fifo_tb/dut/'+p for p in inputs)+'; run -all; vcd flush; quit -f'
        simlog=build/(name+'_modelsim.log')
        simargs=[f'-gSYNC_STAGES={c["stages"]}',f'-gCOUNT_WIDTH={c["count"]}',f'-gAUTO_REFRESH_CYCLES={c["auto"]}',f'-gAF_CLEAR={c["af"]}',f'-gAE_CLEAR={c["ae"]}']
        run([args.simulator_bin/'vsim.exe','-c','-onfinish','stop','-sv_seed',c['seed'],'-l',simlog,*simargs,
             'work.dual_fifo_tb',f'+OPS={c["ops_per_channel"]}',f'+A_RD_PHASE_PS={c["a_rd_phase_ps"]}',
             f'+B_WR_PHASE_PS={c["b_wr_phase_ps"]}',f'+B_RD_PHASE_PS={c["b_rd_phase_ps"]}',
             '-do',commands],out/(name+'_modelsim_driver.log'))
        text=simlog.read_text(errors='replace')
        if 'RESULT: PASS' not in text or re.search(r'CHECK_FAIL|RESULT: FAIL|TIMEOUT|\*\* (Error|Fatal):',text):raise RuntimeError('Source trace did not pass original SV scoreboard')
        shutil.copyfile(simlog,out/(name+'_modelsim.log'))
        database=build/(name+'.dat')
        replay=run([exe,build/trace,database],out/(name+'_replay.log'))
        if 'RESULT: PASS native replay' not in replay:raise RuntimeError('Missing native replay pass')
        shutil.copyfile(database,out/database.name)
        if c==configs[0]:
            negative=run([exe,build/trace,build/'negative.dat','--inject-check-fault'],out/'negative_checker.log',expected=1)
            if 'RESULT: FAIL read data / order / hold' not in negative:raise RuntimeError('Negative scoreboard control did not fire')
        c['trace_sha256']=hashlib.sha256((build/trace).read_bytes()).hexdigest()
        c['trace_bytes']=(build/trace).stat().st_size
        rows.append(c);print('NATIVE: PASS',name,flush=True)
    version=subprocess.check_output([str(verilator),'--version'],env=env,text=True).strip()
    zig_version=subprocess.check_output([str(args.zig),'version'],text=True).strip()
    (out/'run_manifest.json').write_text(json.dumps({'verilator':version,'zig':zig_version,'sources_sha256_lf':manifest,'configurations':rows},indent=2)+'\n')


if __name__=='__main__':main()
