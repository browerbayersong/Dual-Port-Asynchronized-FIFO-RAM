# 原生覆盖点逐项计数

由工具原生数据库汇总；每个点计数大于 0 即为命中。断言激活与功能目标分开，代码点保留全部分母。

| 类型 | 覆盖点 | 行 | 总命中 |
| --- | --- | ---: | ---: |
| 功能 | a_almost_empty_fall | 123 | 22 |
| 功能 | a_almost_empty_rise | 122 | 22 |
| 功能 | a_almost_full_fall | 119 | 15 |
| 功能 | a_almost_full_rise | 118 | 15 |
| 功能 | a_bp_long | 130 | 2 |
| 功能 | a_bp_one | 128 | 923 |
| 功能 | a_bp_short | 129 | 119 |
| 功能 | a_empty_fall | 121 | 618 |
| 功能 | a_empty_rise | 120 | 616 |
| 功能 | a_full_b_empty | 174 | 178 |
| 功能 | a_full_fall | 117 | 424 |
| 功能 | a_full_rise | 116 | 424 |
| 功能 | a_occupancy_0 | 106 | 12532 |
| 功能 | a_occupancy_1 | 107 | 1122 |
| 功能 | a_occupancy_223 | 111 | 81 |
| 功能 | a_occupancy_224 | 112 | 574 |
| 功能 | a_occupancy_225 | 113 | 20 |
| 功能 | a_occupancy_255 | 114 | 930 |
| 功能 | a_occupancy_256 | 115 | 2387 |
| 功能 | a_occupancy_31 | 108 | 44 |
| 功能 | a_occupancy_32 | 109 | 100 |
| 功能 | a_occupancy_33 | 110 | 98 |
| 功能 | a_overflow | 125 | 1619 |
| 功能 | a_read_accept | 126 | 6907 |
| 功能 | a_underflow | 127 | 3293 |
| 功能 | a_write_accept | 124 | 6933 |
| 功能 | b_almost_empty_fall | 161 | 23 |
| 功能 | b_almost_empty_rise | 160 | 23 |
| 功能 | b_almost_full_fall | 157 | 14 |
| 功能 | b_almost_full_rise | 156 | 14 |
| 功能 | b_bp_long | 168 | 2 |
| 功能 | b_bp_one | 166 | 1252 |
| 功能 | b_bp_short | 167 | 145 |
| 功能 | b_empty_fall | 159 | 1724 |
| 功能 | b_empty_rise | 158 | 1722 |
| 功能 | b_full_a_empty | 175 | 175 |
| 功能 | b_full_fall | 155 | 335 |
| 功能 | b_full_rise | 154 | 335 |
| 功能 | b_occupancy_0 | 144 | 5473 |
| 功能 | b_occupancy_1 | 145 | 1793 |
| 功能 | b_occupancy_223 | 149 | 54 |
| 功能 | b_occupancy_224 | 150 | 148 |
| 功能 | b_occupancy_225 | 151 | 18 |
| 功能 | b_occupancy_255 | 152 | 335 |
| 功能 | b_occupancy_256 | 153 | 408 |
| 功能 | b_occupancy_31 | 146 | 39 |
| 功能 | b_occupancy_32 | 147 | 62 |
| 功能 | b_occupancy_33 | 148 | 66 |
| 功能 | b_overflow | 163 | 764 |
| 功能 | b_read_accept | 164 | 7793 |
| 功能 | b_underflow | 165 | 9544 |
| 功能 | b_write_accept | 162 | 7835 |
| 功能 | both_almost_full | 176 | 4991 |
| 功能 | both_backpressured | 177 | 230 |
| 功能 | monitor_auto | 186 | 393 |
| 功能 | monitor_clock_pause | 194 | 20 |
| 功能 | monitor_publish | 182 | 2140 |
| 功能 | monitor_reset_cancel | 184 | 1 |
| 功能 | monitor_state_0 | 178 | 22592 |
| 功能 | monitor_state_1 | 179 | 30592 |
| 功能 | monitor_state_2 | 180 | 2142 |
| 功能 | monitor_state_3 | 181 | 2142 |
| 功能 | monitor_wait | 183 | 34876 |
| 断言激活 | ex_a_backpressure_hold | 208 | 2311 |
| 断言激活 | ex_a_empty_guard | 207 | 22094 |
| 断言激活 | ex_a_full_guard | 206 | 3473 |
| 断言激活 | ex_a_read_gray | 205 | 6907 |
| 断言激活 | ex_a_write_gray | 204 | 6933 |
| 断言激活 | ex_ar_source_hold | 218 | 45744 |
| 断言激活 | ex_aw_source_hold | 217 | 26586 |
| 断言激活 | ex_b_backpressure_hold | 213 | 4928 |
| 断言激活 | ex_b_empty_guard | 212 | 21746 |
| 断言激活 | ex_b_full_guard | 211 | 1106 |
| 断言激活 | ex_b_read_gray | 210 | 7793 |
| 断言激活 | ex_b_write_gray | 209 | 7835 |
| 断言激活 | ex_br_source_hold | 220 | 55325 |
| 断言激活 | ex_bw_source_hold | 219 | 14262 |
| 断言激活 | ex_monitor_id | 215 | 2140 |
| 断言激活 | ex_monitor_output_hold | 214 | 55328 |
| 断言激活 | ex_monitor_pulse | 216 | 2140 |

## RTL 未命中代码插桩点

| 文件 | 行 | 原生类别 | 层级 |
| --- | ---: | --- | --- |
| rtl\fifo_monitor.v | 94 (94) | line/case | TOP.native_coverage_top.dut.u_monitor |
| rtl\fifo_monitor.v | 94 (94) | line/case | TOP.native_coverage_top.dut.u_monitor |
| rtl\async_fifo.v | 150 (150,152-154) | branch/if | TOP.native_coverage_top.dut.fifo_* |
| rtl\fifo_monitor.v | 100 (100-102) | branch/if | TOP.native_coverage_top.dut.u_monitor |
| rtl\fifo_monitor.v | 79 (79) | branch/if | TOP.native_coverage_top.dut.u_monitor |
| rtl\fifo_monitor.v | 100 (100-102) | branch/if | TOP.native_coverage_top.dut.u_monitor |
| rtl\fifo_monitor.v | 79 () | branch/else | TOP.native_coverage_top.dut.u_monitor |
