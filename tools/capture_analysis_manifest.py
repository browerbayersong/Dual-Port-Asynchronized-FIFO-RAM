"""Capture provenance after all analysis runs; does not claim an unsaved commit ID."""
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.metadata
import json
from pathlib import Path
import subprocess

REPO=Path(__file__).resolve().parents[1]


def main():
    def sha(path,normalize=False):
        raw=path.read_bytes()
        return hashlib.sha256(raw.replace(b'\r\n',b'\n') if normalize else raw).hexdigest()
    sources=[]
    for folder in ['rtl','tb','sim','tools']:
        sources.extend(p for p in (REPO/folder).rglob('*') if p.is_file() and p.suffix in ['.v','.sv','.f','.ps1','.py','.cpp','.txt'])
    sources=sorted(set(sources))
    versions={}
    for base in ['D:/fifo_tools/python','D:/fifo_tools/compiler']:
        for dist in importlib.metadata.distributions(path=[base]):
            versions[dist.metadata['Name']]=dist.version
    metadata={
        'captured_at':datetime.now(timezone(timedelta(hours=8))).isoformat(),
        'checkout_head_at_capture':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),
        'branch':subprocess.check_output(['git','branch','--show-current'],cwd=REPO,text=True).strip(),
        'commit_note':'The checkout HEAD is the parent baseline if analysis changes are uncommitted; source hashes identify tested files. The containing Git commit identifies the delivered artifact set.',
        'target_device':None,'scope':'generic synthesis and RTL simulation; no physical PPA',
        'package_versions':versions,
        'source_sha256_lf':{p.relative_to(REPO).as_posix():sha(p,True) for p in sources},
        'report_sha256':{p.relative_to(REPO).as_posix():{'sha256':sha(p,p.suffix!='.dat'),
            'normalization':'raw binary' if p.suffix=='.dat' else 'CRLF to LF'}
            for folder in ['synthesis','performance','native_coverage']
            for p in sorted((REPO/'reports'/folder).glob('*')) if p.is_file() and p.suffix in ['.dat','.json','.log','.ys']}}
    (REPO/'reports/analysis_manifest.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    print('PROVENANCE: captured',len(sources),'source/runner files')


if __name__=='__main__':main()
