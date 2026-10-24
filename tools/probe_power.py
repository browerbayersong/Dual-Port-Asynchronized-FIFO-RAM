"""Record the native missing-model result; never interpret uncalculated zeros as watts."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--power-lib',type=Path)
    ap.add_argument('--stages',type=int,choices=[2,3],default=2);args=ap.parse_args()
    build=Path(f'D:/fifo_build/impl_s{args.stages}')
    if not (build/'route.db').exists():raise RuntimeError('Run target implementation first')
    out=ROOT/'reports/implementation'
    library=''
    if args.power_lib:
        p=args.power_lib.resolve()
        if not p.is_file() or not str(p).isascii() or any(x in str(p) for x in '{}\n\r'):raise RuntimeError('Use an existing model at an ASCII path')
        library='import_power_lib {'+p.as_posix()+'}\n'
    script='''cd [file dirname [info script]]
import_device ph1_100.db -package PH1A100SFG676 -speed 2
import_db route.db
build_power_graph power_graph.json
'''+library+'''
create_power_report -report fifo_ppa -path fifo_ppa.pwr -junc 85 -defTogg 0.125 -vccd 0.9 -vcca 1.8
calculate_power -report fifo_ppa
export_power_report -report fifo_ppa
exit
'''
    (build/'power.tcl').write_text(script,encoding='ascii')
    log_path=out/'power_attempt.log'
    with log_path.open('w') as log:
        proc=subprocess.run(['D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/bin/td_commands_prompt.exe',(build/'power.tcl').as_posix()],cwd=build,stdout=log,stderr=subprocess.STDOUT)
    text=log_path.read_text(errors='replace')
    missing='PWR-5001' in text
    if proc.returncode or ' ERROR:' in text:raise RuntimeError('Native power command failed; inspect '+str(log_path))
    record={'status':'unavailable_missing_device_power_library' if missing else 'engine_returned_manual_result_review_required',
        'power_w':None,'model_path':str(args.power_lib) if args.power_lib else None,
        'attempt_configuration':{'device':'PH1A100SFG676','vccd_v':0.9,'vccaux_v':1.8,'junction_c':85,'vectorless_toggle_fraction':0.125},
        'note':'No quantified power is accepted without a matching vendor model and result review. No SAIF-based measured workload is claimed.'}
    (out/'power_status.json').write_text(json.dumps(record,indent=2)+'\n')
    header=(build/'fifo_ppa.pwr').read_text(encoding='gb18030').split('----- Instances -----')[0]
    (out/'power_attempt_settings.txt').write_text(header,encoding='utf-8')
    print('POWER_STATUS:',record['status'])


if __name__=='__main__':main()
