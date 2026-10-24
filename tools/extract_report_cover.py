"""Extract the user's original first PDF page and render it without redrawing its layout."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from pypdf import PdfReader, PdfWriter

ROOT=Path(__file__).resolve().parents[1]
RUNTIME=Path('C:/Users/browersong/.cache/codex-runtimes/codex-primary-runtime/dependencies')


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--source',type=Path,default=ROOT.parent/'硬件描述语言 课设题目27.pdf')
    ap.add_argument('--poppler-bin',type=Path,default=RUNTIME/'native/poppler/Library/bin')
    args=ap.parse_args()
    original=PdfReader(args.source);page=original.pages[0]
    out=ROOT/'assets';out.mkdir(exist_ok=True)
    pdf=out/'course-report-cover.pdf';png=out/'course-report-cover.png'
    writer=PdfWriter();writer.add_page(page)
    writer.add_metadata({'/Title':'Original course report cover first page'})
    with pdf.open('wb') as stream:writer.write(stream)
    extracted=PdfReader(pdf)
    assert len(extracted.pages)==1
    assert extracted.pages[0].get_contents().get_data()==page.get_contents().get_data()
    subprocess.run([str(args.poppler_bin/'pdftoppm.exe'),'-f','1','-singlefile','-r','300','-png',str(pdf),str(png.with_suffix(''))],check=True)
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    manifest={'source_file_name':args.source.name,'source_pdf_sha256':sha(args.source),'source_page_number':1,
        'page_width_pt':float(page.mediabox.width),'page_height_pt':float(page.mediabox.height),
        'extracted_pdf_sha256':sha(pdf),'cover_png_sha256':sha(png),'raster_dpi':300,
        'page_content_stream_unchanged':True,'fields':'All original blank fields and original year retained; no personal details inserted',
        'report_top_level_sections':['设计题目','设计目的','设计内容','设计结果分析','总结','参考文献']}
    (out/'course-report-cover.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('COVER_EXTRACT: PASS original first page, unchanged content stream, 300 dpi Word image')


if __name__=='__main__':main()
