"""Extract measured route resources and two report selections. Reject default-clock results."""
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/implementation'
CLOCKS=['a_wr_clk','a_rd_clk','b_wr_clk','b_rd_clk','monitor_clk']


def required(pattern,text):
    match=re.search(pattern,text,re.M)
    if not match:raise RuntimeError('Missing report field '+pattern)
    return match


def interface(text):
    if 'DeriveClock' in text or 'Confidence          : Routed' not in text:raise RuntimeError('Invalid timing provenance')
    clocks={}
    for line in text.splitlines():
        cells=line.split()
        if len(cells)==4 and cells[0].startswith('clk') and cells[-1] in CLOCKS:
            clocks[cells[-1]]={'target_mhz':float(cells[1])}
    if set(clocks)!=set(CLOCKS):raise RuntimeError('Expected all five independent clocks')
    return {'setup_wns_ns':float(required(r'SWNS:\s+(-?[\d.]+)ns',text)[1]),
        'hold_wns_ns':float(required(r'HWNS:\s+(-?[\d.]+)ns',text)[1]),
        'sta_coverage_percent':float(required(r'STA coverage\s+:\s+([\d.]+)%',text)[1]),'clocks':clocks}


def internal(text):
    if 'DeriveClock' in text:raise RuntimeError('Invalid internal default-clock report')
    clocks={}
    for block in text.split('Path Group     :')[1:]:
        group=block.splitlines()[0].strip()
        for clock in CLOCKS:
            if group!=f'{clock} -> {clock}':continue
            clocks[clock]={'fmax_mhz':float(required(r'Fmax\s+:\s+([\d.]+)MHz',block)[1]),
                'min_period_ns':float(required(r'Min Period\s+:\s+([\d.]+)ns',block)[1]),
                'setup_wns_ns':float(required(r'Max\s+: SWNS\s+(-?[\d.]+)ns',block)[1]),
                'hold_wns_ns':float(required(r'Min\s+: HWNS\s+(-?[\d.]+)ns',block)[1])}
    if set(clocks)!=set(CLOCKS):raise RuntimeError('Missing filtered internal clock groups')
    return {'definition':'Native report_timing_path between internal register nets under unchanged full SDC; worst 20 endpoints per group',
            'setup_wns_ns':min(x['setup_wns_ns'] for x in clocks.values()),
            'hold_wns_ns':min(x['hold_wns_ns'] for x in clocks.values()),'clocks':clocks}


def main():
    configs=[]
    for stage in [2,3]:
        area=(OUT/f's{stage}_route.area').read_text(errors='replace')
        timing=(OUT/f's{stage}_route.timing').read_text(errors='replace')
        core=(OUT/f's{stage}_core.timing').read_text(errors='replace')
        exceptions=(OUT/f's{stage}_exceptions.timing').read_text(errors='replace')
        bounds=[]
        for line in exceptions.splitlines():
            m=re.match(r'\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .*|set_max_skew .*)$',line)
            if m:bounds.append({'type':'max_delay' if m[5].startswith('set_max_delay') else 'max_skew',
                'total':int(m[1]),'dominated':int(m[2]),'shadowed':int(m[3]),'ignored':int(m[4]),'constraint':m[5]})
        maxes=[x for x in bounds if x['type']=='max_delay']
        if len(maxes)!=16 or any(x['shadowed'] or x['ignored'] or x['dominated']!=x['total'] for x in maxes):
            raise RuntimeError('CDC max-delay constraints were lost or overridden')
        gray=[]
        for block in exceptions.split('Timing details for constraint:')[1:]:
            label=re.search(r'fifo_([ab])/u_(r2w|w2r)/gray_in',block.split('--------------------------------------------------')[0])
            if not label:continue
            delays=[float(x) for x in re.findall(r'Data Path Delay\s+:\s+([\d.]+)ns',block)]
            if len(delays)!=9:raise RuntimeError('Expected all nine Gray bit max-path delays')
            budget=float(required(r'Budget\s+:\s+([\d.]+)ns',block)[1])
            if max(delays)>=budget:raise RuntimeError('Gray data delay exceeds its source period')
            gray.append({'bus':label[1]+'_'+label[2],'reported_bits':9,'max_delay_ns':max(delays),
                'min_delay_same_max_corner_ns':min(delays),'spread_same_max_corner_ns':round(max(delays)-min(delays),3),
                'source_period_bound_ns':budget})
        if len(gray)!=4:raise RuntimeError('Missing Gray bus evidence')
        reg=int(required(r'^#reg\s+(\d+)',area)[1]);ram=int(required(r'^\s*#eram20k\s+(\d+)',area)[1])
        if ram!=2:raise RuntimeError('Expected two independent ERAM20K macros')
        core_luts=None;wrapper_luts=None
        for line in area.splitlines():
            fields=[s.strip() for s in line.split('|')]
            if len(fields)>6 and fields[1]=='dut':core_luts=int(fields[3])+int(fields[4])
        total_luts=int(required(r'^#lut6\s+(\d+)',area)[1])
        if core_luts is not None:wrapper_luts=total_luts-core_luts
        configs.append({'sync_stages':stage,'registers':reg,'lut6':total_luts,'core_lut6':core_luts,'wrapper_lut6':wrapper_luts,
            'io':int(required(r'^#IO\s+(\d+)',area)[1]),'eram20k':ram,'interface':interface(timing),'core':internal(core),
            'cdc_bounds':bounds,'cdc_max_delay_valid_paths':sum(x['dominated'] for x in maxes),'gray_delay_evidence':gray,
            'independent_max_skew_command_status':'No separate native enforcement report; no independent set_max_skew pass is claimed. The audited per-bit absolute delay bound is the conservative skew bound.',
            'power_w':None,'power_status':'missing_device_power_library',
            'critical_warning':'TMR-5506: ERAM address/chip-select signals driven by asynchronous-reset registers; physical RAM/reset behavior not signed off'})
    result={'tool':'Tang Dynasty V6.2.168116','device':'PH1A100SFG676','speed_grade':2,
        'scope':'Software evaluation including read-only status mux. Full IO timing is not closed; filtered internal reports are not IO signoff.',
        'configurations':configs}
    (OUT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    for c in configs:print('TARGET_SUMMARY:',c['sync_stages'],c['registers'],c['lut6'],c['core_lut6'],c['core']['setup_wns_ns'],c['core']['hold_wns_ns'],c['cdc_max_delay_valid_paths'])


if __name__=='__main__':main()
