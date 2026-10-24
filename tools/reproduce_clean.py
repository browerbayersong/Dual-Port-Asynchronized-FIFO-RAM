"""Automated clean-directory reproduction; explicitly not a second person's verification."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    out=ROOT/'reports/reproduction';out.mkdir(parents=True,exist_ok=True)
    clean=Path(tempfile.mkdtemp(prefix='reproduce_',dir='D:/fifo_build'))
    files=[]
    for folder in ['rtl','tb','sim','analysis','constraints','tools']:
        for p in (ROOT/folder).rglob('*'):
            if p.is_file() and p.suffix in ['.v','.sv','.f','.ps1','.py','.cpp','.txt','.sdc','.tcl']:
                rel=p.relative_to(ROOT);(clean/rel).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,clean/rel)
                if folder in ['rtl','tb','sim']:files.append(rel)
    def sha(p):return hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    versions={str(p).replace('\\','/'):sha(clean/p) for p in files}
    shell='C:/Users/browersong/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'
    jobs=[('single_configuration','sim/run_dual.ps1',['-SyncStages','3','-Seed','1','-AutoRefreshCycles','32']),
          ('full_regression','sim/regress_dual.ps1',[])]
    for name,script,args in jobs:
        with (out/(name+'.log')).open('w',encoding='utf-8') as log:
            proc=subprocess.run([shell,'-NoProfile','-File',str(clean/script),*args,'-BuildRoot',str(clean/'build')],cwd=clean,stdout=log,stderr=subprocess.STDOUT)
        text=(out/(name+'.log')).read_text(errors='replace')
        expected=1 if name=='single_configuration' else 10
        if proc.returncode or len(re.findall('RESULT: PASS',text))!=expected or re.search(r'CHECK_FAIL|RESULT: FAIL|TIMEOUT',text):
            raise RuntimeError('Clean reproduction failed '+name)
        print('CLEAN_REPRODUCTION: PASS',name,flush=True)
    for rel in files:
        if sha(clean/rel)!=versions[str(rel).replace('\\','/')]:raise RuntimeError('Source modified during reproduction')
    summary={'kind':'automated clean-directory reproduction on the same computer','human_independent_reproduction':False,
        'clean_directory':str(clean),'single_configuration':'PASS','full_regression':'PASS 10/10',
        'copied_verification_source_sha256_lf':versions}
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')


if __name__=='__main__':main()
