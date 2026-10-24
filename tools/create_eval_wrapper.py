"""Generate a read-only status mux wrapper; no FIFO control or sequential logic changes."""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]


def main():
    text=(ROOT/'tb/native_coverage_top.sv').read_text()
    text=text[:text.index('    wire [ADDR_WIDTH:0] a_true_level')]
    text=text.replace('module native_coverage_top','module dual_fifo_eval',1)
    header,body=text.split(');',1)
    internal=[]; exports=[]
    for line in header.splitlines():
        if 'output wire' in line and any(x in line for x in ['write_count','read_count','backpressure_count','snapshot_id','write_status','read_status']):
            internal.append(line.strip().replace('output wire','wire').rstrip(',')+';')
        else:exports.append(line)
    exports[-1]=exports[-1].rstrip(',')+','
    exports+=['    input wire [4:0] status_select,','    output wire [31:0] status_data']
    signals=['a_write_count','a_read_count','a_overflow_count','a_underflow_count','a_backpressure_count','a_backpressure_cycles',
             'b_write_count','b_read_count','b_overflow_count','b_underflow_count','b_backpressure_count','b_backpressure_cycles',
             'snapshot_id','a_write_status','a_read_status','b_write_status','b_read_status']
    tail='''
    // This combinational diagnostic output only preserves visibility for software implementation.
    // It is excluded from interface timing and is not an additional coherent CDC interface.
    localparam STATUS_BITS = 24*COUNT_WIDTH + 4*ADDR_WIDTH + 44;
    localparam STATUS_WORDS = (STATUS_BITS+31)/32;
    wire [STATUS_WORDS*32-1:0] status_vector = {{(STATUS_WORDS*32-STATUS_BITS){1'b0}},
        '''+',\n        '.join(signals)+'''};
    assign status_data = (status_select < STATUS_WORDS) ? status_vector[status_select*32 +: 32] : 32'b0;
endmodule
'''
    out=ROOT/'analysis/dual_fifo_eval.v';out.parent.mkdir(exist_ok=True)
    out.write_text('\n'.join(exports)+'\n);\n'+'\n'.join('    '+x for x in internal)+'\n'+body+tail)
    print(out)


if __name__=='__main__':main()
