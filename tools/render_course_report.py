"""Use the packaged DOCX rasterizer with native WPS export on Windows without LibreOffice."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
RUNTIME=Path('C:/Users/browersong/.cache/codex-runtimes/codex-primary-runtime/dependencies')
SKILL=Path('C:/Users/browersong/.codex/plugins/cache/openai-primary-runtime/documents/26.1022.11436/skills/documents')


def main():
    spec=importlib.util.spec_from_file_location('packaged_docx_renderer',SKILL/'render_docx.py')
    renderer=importlib.util.module_from_spec(spec);spec.loader.exec_module(renderer)
    os.environ['PATH']=str(RUNTIME/'native/poppler/Library/bin')+os.pathsep+os.environ['PATH']
    script=ROOT/'tools/export_report_pdf.ps1'
    def convert(doc_path,user_profile,convert_tmp_dir,stem,verbose):
        pdf=Path(convert_tmp_dir)/(stem+'.pdf')
        proc=subprocess.run([str(RUNTIME/'native/powershell/pwsh.exe'),'-NoProfile','-File',str(script),
            '-DocumentPath',doc_path,'-PdfPath',str(pdf)],capture_output=True,text=True,encoding='utf-8',errors='replace')
        log=proc.stdout+proc.stderr
        if proc.returncode or not pdf.exists():return '',log
        return str(pdf),log
    renderer.convert_to_pdf=convert
    qa=Path('D:/fifo_build/report_qa');qa.mkdir(parents=True,exist_ok=True)
    pages=renderer.rasterize(str(ROOT/'deliverables/双异步FIFO课程设计报告.docx'),str(qa),144,False,True)
    print('RENDER: PASS',len(pages),'pages',str(qa))


if __name__=='__main__':main()
