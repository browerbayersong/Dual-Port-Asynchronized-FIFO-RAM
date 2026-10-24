"""Create diagrams and plots, including waveforms from a passing ModelSim trace."""
import bisect
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/figures'
FONT=fm.FontProperties(fname='C:/Windows/Fonts/msyh.ttc')
plt.rcParams.update({'font.family':FONT.get_name(),'axes.unicode_minus':False,'font.size':10,'savefig.facecolor':'white'})


def box(ax,x,y,w,h,label):
    patch=FancyBboxPatch((x,y),w,h,boxstyle='round,pad=0.015,rounding_size=0.02',
                        ec='#333333',fc='#F3F5F7',lw=1)
    ax.add_patch(patch);ax.text(x+w/2,y+h/2,label,ha='center',va='center',fontproperties=FONT,fontsize=10)


def arrow(ax,a,b,label=None):
    ax.add_patch(FancyArrowPatch(a,b,arrowstyle='-|>',mutation_scale=12,color='#444444',lw=1))
    if label:ax.text((a[0]+b[0])/2,(a[1]+b[1])/2+0.025,label,ha='center',fontsize=8,fontproperties=FONT)


def diagram():
    fig,ax=plt.subplots(figsize=(10.8,5.5));ax.set(xlim=(0,1),ylim=(0,1));ax.axis('off')
    for y,ch,wr,rd in [(0.66,'A','50 MHz','83.333 MHz'),(0.31,'B','28.571 MHz','100 MHz')]:
        box(ax,0.02,y,0.19,0.20,f'{ch} 写时钟域\n{wr}\n写指针及满保护')
        box(ax,0.32,y,0.22,0.20,f'{ch} 独立双端口 RAM\n256 × 32 bit\n写口与读口独立时钟')
        box(ax,0.66,y,0.22,0.20,f'{ch} 读时钟域\n{rd}\n读指针及空保护')
        arrow(ax,(0.21,y+0.1),(0.32,y+0.1),'写数据');arrow(ax,(0.54,y+0.1),(0.66,y+0.1),'读数据')
        ax.text(0.45,y-0.06,'寄存 Gray 指针分别经 2 或 3 级同步至对侧',ha='center',fontproperties=FONT,fontsize=9)
    box(ax,0.33,0.015,0.37,0.15,'统一监控 100 MHz\n四个源域快照握手与原子发布')
    for points in [[(0.21,0.66),(0.265,0.60),(0.265,0.20),(0.40,0.165)],
                   [(0.66,0.66),(0.605,0.60),(0.605,0.20),(0.63,0.165)]]:
        ax.plot([p[0] for p in points[:-1]],[p[1] for p in points[:-1]],color='#444444',lw=1)
        arrow(ax,points[-2],points[-1])
    arrow(ax,(0.115,0.31),(0.47,0.165));arrow(ax,(0.77,0.31),(0.56,0.165))
    ax.text(0.02,0.97,'双通道结构与五个时钟域',fontsize=15,fontproperties=FONT,va='top')
    fig.tight_layout();fig.savefig(OUT/'architecture.png',dpi=180);plt.close(fig)
    fig,ax=plt.subplots(figsize=(10.8,4.7));ax.set(xlim=(0,1),ylim=(0,1));ax.axis('off')
    states=[(0.04,0.55,'IDLE\n接受手动或定时请求'),(0.54,0.55,'WAIT_ACK\n等待四域确认'),(0.54,0.13,'GUARD\n等待保护边沿'),(0.04,0.13,'CAPTURE\n四包一起发布')]
    for x,y,label in states:box(ax,x,y,0.36,0.23,label)
    arrow(ax,(0.40,0.665),(0.54,0.665),'翻转请求')
    arrow(ax,(0.72,0.55),(0.72,0.36),'四路确认匹配')
    arrow(ax,(0.54,0.245),(0.40,0.245),'进入捕获')
    arrow(ax,(0.22,0.36),(0.22,0.55),'valid 一拍 id 加一')
    ax.text(0.5,0.96,'监控状态机',fontsize=15,ha='center',fontproperties=FONT)
    ax.text(0.5,0.015,'共同复位清除未完成请求并返回 IDLE',ha='center',fontproperties=FONT,fontsize=10)
    fig.tight_layout();fig.savefig(OUT/'monitor_fsm.png',dpi=180);plt.close(fig)
    fig,ax=plt.subplots(figsize=(10.2,3.9));x=[i/10 for i in range(201)]
    ax.plot(x,[v/2.302585093 for v in x],color='#235789',lw=2)
    ax.set(xlabel='额外稳定时间 / τ（无量纲）',ylabel='log10（MTBF3 / MTBF2）',title='增加稳定时间的模型敏感性')
    ax.grid(alpha=0.25);ax.text(0.03,0.94,'数学模型示意 未代入本器件的 τ 或绝对寿命',transform=ax.transAxes,va='top',fontsize=9,fontproperties=FONT)
    fig.tight_layout();fig.savefig(OUT/'mtbf_relative.png',dpi=180);plt.close(fig)


def trace():
    build=Path('D:/fifo_build/report_waveforms');build.mkdir(parents=True,exist_ok=True)
    sim=Path('D:/altera/14.1/modelsim_ase/win32aloem')
    rtl=(ROOT/'sim/dual_rtl.f').read_text().split();tb=(ROOT/'sim/dual_tb.f').read_text().split()
    for name in rtl+tb:
        (build/name).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,build/name)
    def run(name,args,log):
        with (build/log).open('w') as f:p=subprocess.run([str(sim/(name+'.exe')),*map(str,args)],cwd=build,stdout=f,stderr=subprocess.STDOUT)
        if p.returncode:raise RuntimeError(str(build/log))
    if not (build/'modelsim.ini').exists():run('vmap',['-c'],'map.log')
    if not (build/'work').exists():run('vlib',['work'],'lib.log')
    run('vlog',rtl,'rtl.log');run('vlog',['-sv',*tb],'tb.log')
    names=['a_wr_clk','a_rd_clk','a_wr_en','a_rd_en','a_rd_ready','a_full','a_empty','a_wr_level','a_rd_level','a_rd_data_valid','a_rd_data',
           'monitor_clk','snapshot_req','snapshot_ready','snapshot_busy','snapshot_valid','snapshot_id']
    cmd='vcd file waveform.vcd;vcd add '+' '.join('/dual_fifo_tb/dut/'+n for n in names)+';run -all;vcd flush;quit -f'
    run('vsim',['-c','-onfinish','stop','-sv_seed','1','-l','run.log','-gSYNC_STAGES=2','-gAUTO_REFRESH_CYCLES=0','work.dual_fifo_tb','+OPS=5000','-do',cmd],'driver.log')
    log=(build/'run.log').read_text()
    if 'RESULT: PASS' not in log or re.search(r'CHECK_FAIL|RESULT: FAIL|TIMEOUT|\*\* (Error|Fatal):',log):raise RuntimeError('Waveform source did not pass')
    shutil.copyfile(build/'run.log',OUT/'waveform_run.log')
    data={name:[] for name in names};symbols={};values={name:0 for name in names};header=True;time=0;started=False
    def flush():
        for name,value in values.items():
            if not data[name] or data[name][-1][1]!=value:data[name].append((time/1000,value))
    with (build/'waveform.vcd').open() as f:
        for line in f:
            line=line.strip()
            if not line:continue
            if header:
                if line.startswith('$var '):
                    parts=line.split();_,kind,width,ident,name=parts[:5];bit=None
                    if name in names:
                        if width=='1' and len(parts)>5 and re.fullmatch(r'\[\d+\]',parts[5]):bit=int(parts[5][1:-1])
                        symbols[ident]=(name,bit)
                if line.startswith('$enddefinitions'):header=False
            elif line.startswith('#'):
                if started:flush()
                time=int(line[1:]);started=True
            elif not line.startswith('$'):
                if line[0].lower()=='b':bits,ident=line[1:].split()
                else:bits,ident=line[0],line[1:]
                if ident in symbols:
                    name,bit=symbols[ident];value=int(bits,2) if re.fullmatch('[01]+',bits) else 0
                    values[name]=value if bit is None else (values[name]&~(1<<bit))|((value&1)<<bit)
    flush()
    def value_at(name,t):
        rows=data[name];i=bisect.bisect_right([x[0] for x in rows],t)-1
        return rows[max(0,i)][1]
    full=next(t for t,v in data['a_full'] if v)
    release=next(t for t,v in data['a_full'] if t>full and not v)
    stall=next(t for t,v in data['a_rd_ready'] if t>500 and not v and value_at('a_empty',t)==0 and value_at('a_rd_en',t)==1)
    req=next(t for t,v in data['snapshot_req'] if t>300 and v)
    def draw(name,title,lo,hi,digital,analog):
        fig,axes=plt.subplots(2,1,figsize=(11,3.7),gridspec_kw={'height_ratios':[len(digital),2.3]},sharex=True)
        ax=axes[0]
        for index,sig in enumerate(reversed(digital)):
            pairs=[(lo,value_at(sig,lo))]+[(t,v) for t,v in data[sig] if lo<t<hi]+[(hi,value_at(sig,hi))]
            ax.step([p[0] for p in pairs],[index+p[1]*0.65 for p in pairs],where='post',lw=1,color='#235789')
        ax.set(yticks=[i+0.3 for i in range(len(digital))],yticklabels=list(reversed(digital)),ylim=(-0.3,len(digital)),title=title)
        ax.tick_params(axis='y',length=0,labelsize=9);ax.grid(axis='x',alpha=0.2)
        ay=axes[1]
        for sig in analog:
            pairs=[(lo,value_at(sig,lo))]+[(t,v) for t,v in data[sig] if lo<t<hi]+[(hi,value_at(sig,hi))]
            ay.step([p[0] for p in pairs],[p[1] for p in pairs],where='post',lw=1.4,label=sig)
        ay.set(xlim=(lo,hi),xlabel='仿真时间 ns');ay.legend(loc='upper right',fontsize=8);ay.grid(alpha=0.2)
        fig.tight_layout();fig.savefig(OUT/(name+'.png'),dpi=180);plt.close(fig)
    draw('wave_full_release','写域 full 在读出后经同步延迟撤销',release-120,release+240,
         ['a_wr_clk','a_rd_clk','a_rd_en','a_rd_data_valid','a_full','a_empty'],['a_wr_level','a_rd_level'])
    draw('wave_backpressure','读就绪撤销期间暂停弹出',stall-80,stall+950,
         ['a_rd_ready','a_rd_en','a_rd_data_valid','a_empty'],['a_rd_level'])
    draw('wave_snapshot','监控请求 等待确认与快照发布',max(0,req-40),req+520,
         ['monitor_clk','snapshot_req','snapshot_ready','snapshot_busy','snapshot_valid'],['snapshot_id'])
    (OUT/'waveform_manifest.json').write_text(json.dumps({'source':'passing ModelSim 10.3c dual_fifo_tb','sync_stages':2,'auto_refresh_cycles':0,'seed':1,'ops_per_channel':5000,
        'vcd_sha256':hashlib.sha256((build/'waveform.vcd').read_bytes()).hexdigest(),
        'event_times_ns':{'first_full':full,'first_full_release':release,'selected_stall':stall,'selected_request':req}},indent=2)+'\n')


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);diagram();trace();print('REPORT_FIGURES: PASS')
