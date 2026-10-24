"""Run the existing full scoreboard behind the implementation-only wrapper."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
SIM=Path('D:/altera/14.1/modelsim_ase/win32aloem')


def main():
    out=ROOT/'reports/implementation';out.mkdir(parents=True,exist_ok=True)
    sources=(ROOT/'sim/dual_rtl.f').read_text().split()+['analysis/dual_fifo_eval.v']
    checkers=['tb/fifo_channel_checker.sv','tb/snapshot_source_checker.sv']
    original=(ROOT/'tb/dual_fifo_tb.sv').read_text()
    start=original.index('    dual_async_fifo #');end=original.index(');',start)+2
    inst=original[start:end]
    hidden=['a_write_count','a_read_count','a_overflow_count','a_underflow_count','a_backpressure_count','a_backpressure_cycles',
            'b_write_count','b_read_count','b_overflow_count','b_underflow_count','b_backpressure_count','b_backpressure_cycles',
            'snapshot_id','a_write_status','a_read_status','b_write_status','b_read_status']
    aliases=[]
    for name in hidden:
        match=re.search(r'\.'+name+r'\(([^()]*)\)',inst)
        if not match:raise RuntimeError('Missing wrapper port '+name)
        aliases.append(f'    assign {match[1]}=dut.{name};')
        inst=re.sub(r'\.'+name+r'\([^()]*\),?', '',inst)
    inst=inst.replace('dual_async_fifo #','dual_fifo_eval #',1)
    inst=inst.replace(') dut (',') dut (\n        .status_select(eval_select),.status_data(eval_data),',1)
    inst=re.sub(r',\s*\);',');',inst)
    text=original[:start]+inst+'\n'+'\n'.join(aliases)+original[end:]
    text=text.replace('module dual_fifo_tb','module eval_wrapper_tb',1).replace('dut.fifo_','dut.dut.fifo_').replace('dut.u_monitor','dut.dut.u_monitor')
    text=text.replace('    localparam integer WW', '    reg [4:0] eval_select=0;\n    wire [31:0] eval_data;\n    localparam integer WW',1)
    extra='''
    localparam EVAL_BITS=24*COUNT_WIDTH+76;
    localparam EVAL_WORDS=(EVAL_BITS+31)/32;
    wire [EVAL_WORDS*32-1:0] eval_reference={
        {(EVAL_WORDS*32-EVAL_BITS){1'b0}},
        writes[0],reads[0],overflows[0],underflows[0],bp_events[0],bp_cycles[0],
        writes[1],reads[1],overflows[1],underflows[1],bp_events[1],bp_cycles[1],
        snapshot_id,aw,ar,bw,br};
    always @(negedge monitor_clk) begin
        #0.002;
        if(rst_n) check(eval_data === ((eval_select<EVAL_WORDS)?eval_reference[eval_select*32 +:32]:32'b0),"evaluation diagnostic mux");
        eval_select=eval_select+1;
    end
'''
    text=text.replace('endmodule',extra+'\nendmodule')
    build=Path('D:/fifo_build/wrapper_verify');build.mkdir(parents=True,exist_ok=True)
    for f in sources+checkers:
        (build/f).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/f,build/f)
    (build/'tb/eval_wrapper_tb.sv').write_text(text)
    def run(tool,args,log):
        with log.open('w',encoding='utf-8') as f:
            p=subprocess.run([str(SIM/(tool+'.exe')),*map(str,args)],cwd=build,stdout=f,stderr=subprocess.STDOUT)
        if p.returncode:raise RuntimeError(str(log))
    if not (build/'modelsim.ini').exists():run('vmap',['-c'],build/'map.log')
    if not (build/'work').exists():run('vlib',['work'],build/'lib.log')
    run('vlog',sources,build/'rtl.log')
    run('vlog',['-sv',*checkers,'tb/eval_wrapper_tb.sv'],build/'tb.log')
    for stage in [2,3]:
        run('vsim',['-c','-onfinish','stop','-sv_seed','1','-l',f's{stage}.log',f'-gSYNC_STAGES={stage}',
            '-gAUTO_REFRESH_CYCLES=32','work.eval_wrapper_tb','+OPS=5000','-do','run -all;quit -f'],build/f's{stage}_driver.log')
        log=(build/f's{stage}.log').read_text()
        if 'RESULT: PASS' not in log or re.search(r'CHECK_FAIL|RESULT: FAIL|TIMEOUT|\*\* (Error|Fatal):',log):raise RuntimeError(f'Wrapper failed s{stage}')
        shutil.copyfile(build/f's{stage}.log',out/f's{stage}_wrapper_verify.log')
        print('WRAPPER_VERIFY: PASS',stage,flush=True)
    (out/'wrapper_verify_manifest.json').write_text(json.dumps({'derived_from':'tb/dual_fifo_tb.sv',
        'source_tb_sha256_lf':hashlib.sha256(original.replace('\r\n','\n').encode()).hexdigest(),
        'derived_tb_sha256_lf':hashlib.sha256(text.replace('\r\n','\n').encode()).hexdigest(),
        'configurations':{'sync_stages':[2,3],'seed':1,'auto_refresh_cycles':32,'ops_per_channel':5000},
        'changes':'Only rebind the DUT, expose hidden status wires to the original scoreboards, and exercise all diagnostic mux selections.'},indent=2)+'\n')


if __name__=='__main__':main()
