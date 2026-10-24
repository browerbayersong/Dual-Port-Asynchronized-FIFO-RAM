"""Report the native SystemC::Coverage-3 records without changing denominators."""
from collections import defaultdict
import json
from pathlib import Path
import re

REPO=Path(__file__).resolve().parents[1]
OUT=REPO/'reports/native_coverage'


def read_database(path):
    records=[]
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line.startswith('C '):continue
        match=re.fullmatch(r"C '(.*)' (\d+)",line)
        if not match:raise RuntimeError(f'Unrecognized native coverage record: {path}')
        fields={}
        for field in match[1].split('\x01'):
            if field:
                k,v=field.split('\x02',1);fields[k]=v
        fields['count']=int(match[2]);records.append(fields)
    if not records:raise RuntimeError(f'Empty native database: {path}')
    return records


def main():
    manifest=json.loads((OUT/'run_manifest.json').read_text())
    merged={}; per_run=[]
    def metric(items):return {'hit':sum(r['count']>0 for r in items),'total':len(items),'percent':round(100*sum(r['count']>0 for r in items)/len(items),3) if items else None}
    for cfg in manifest['configurations']:
        records=read_database(OUT/(cfg['name']+'.dat'))
        per_run.append({'name':cfg['name'],
            'functional':metric([r for r in records if r.get('t')=='user' and not r.get('o','').startswith('ex_')]),
            'assertion_activation':metric([r for r in records if r.get('t')=='user' and r.get('o','').startswith('ex_')]),
            'rtl_line_instrumentation':metric([r for r in records if r.get('t')=='line' and r['f'].replace('\\','/').startswith('rtl/')]),
            'rtl_branch_instrumentation':metric([r for r in records if r.get('t')=='branch' and r['f'].replace('\\','/').startswith('rtl/')])})
        for r in records:
            key=tuple(sorted((k,v) for k,v in r.items() if k!='count'))
            if key not in merged:merged[key]={**r,'counts':{}}
            merged[key]['counts'][cfg['name']]=r['count']
    records=list(merged.values())
    for r in records:r['count']=sum(r['counts'].values())
    functional=[r for r in records if r.get('t')=='user' and not r.get('o','').startswith('ex_')]
    activations=[r for r in records if r.get('t')=='user' and r.get('o','').startswith('ex_')]
    lines=[r for r in records if r.get('t')=='line' and r['f'].replace('\\','/').startswith('rtl/')]
    branches=[r for r in records if r.get('t')=='branch' and r['f'].replace('\\','/').startswith('rtl/')]
    data={'method':'Verilator native cover-property and line instrumentation; Python report from raw .dat',
          'functional':metric(functional),'assertion_activation':metric(activations),'rtl_line_instrumentation':metric(lines),
          'rtl_branch_instrumentation':metric(branches),
          'per_run':per_run,'records':sorted(records,key=lambda r:(r.get('f',''),int(r.get('l','0')),r.get('h','')))}
    (OUT/'summary.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    table=['# 原生覆盖点逐项计数','', '由工具原生数据库汇总；每个点计数大于 0 即为命中。断言激活与功能目标分开，代码点保留全部分母。','',
           '| 类型 | 覆盖点 | 行 | 总命中 |','| --- | --- | ---: | ---: |']
    for kind,items in [('功能',functional),('断言激活',activations)]:
        for r in sorted(items,key=lambda r:r.get('o','')):table.append(f"| {kind} | {r.get('o')} | {r.get('l')} | {r['count']} |")
    table+=['','## RTL 未命中代码插桩点','','| 文件 | 行 | 原生类别 | 层级 |','| --- | ---: | --- | --- |']
    for r in lines+branches:
        if not r['count']:table.append(f"| {r['f']} | {r['l']} ({r.get('S','')}) | {r.get('t','')}/{r.get('o','')} | {r.get('h','')} |")
    (OUT/'POINTS.md').write_text('\n'.join(table)+'\n',encoding='utf-8')
    print(json.dumps({k:data[k] for k in ['functional','assertion_activation','rtl_line_instrumentation','rtl_branch_instrumentation','per_run']},indent=2))


if __name__=='__main__':main()
