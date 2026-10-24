# 已验证环境

检查日期：2026-10-24。

| 项目 | 实测结果 |
| --- | --- |
| 系统与脚本 | Windows、PowerShell |
| 仿真器 | ModelSim ALTERA STARTER EDITION 10.3c |
| 编译器 | vlog 10.3c，2014.09 |
| 安装目录 | D:/altera/14.1/modelsim_ase/win32aloem |
| Verilog RTL | 编译、仿真通过 |
| SV logic/int、队列、$urandom、过程式/立即检查 | 环境小测试和单通道回归通过 |
| covergroup | 可编译，加载时 verification license 不可用，提示要求 QuestaSim |
| vcover | 当前安装目录未发现，原生覆盖率未导出 |
| 中文构建路径 | 库数据库打开失败，英文路径通过 |
| 单通道构建目录 | D:/fifo_sim/，由脚本建立 |
| 综合工具 | Yosys 0.70 / YoWASP 0.70.0.0.post1259，通用综合通过 |
| 目标器件、上板要求 | 用户确认未指定器件，先通用综合；板级工作待定 |
| 额外覆盖率工具 | verilator 包 5.48.0，二进制 rev vUNKNOWN-built20260516-4e853d8 |
| 原生 cover property / SVA / 代码插桩 | 两组回放通过，原生 .dat 已保存；见 reports/native_coverage/ |
| Verilator covergroup | 当前二进制探测为 COVERIGN，不使用 |
| C++ 编译器 | Zig 0.14.1（c++），仓库外独立安装 |
| Python | 3.12.14，使用标准库运行脚本 |

环境小测试结果为 RESULT: PASS checks=40 enabled=20。单通道结果及证据见 reports/。

双通道与统一监控也已在同一工具下完成 10 组配置回归，两路每组各 5000 次随机写侧决策，记录见 reports/dual/。监控采用过程式独立检查和自定义功能 bins，未启用原生 covergroup。

运行脚本每次复制并编译当前源码，库和波形保留在英文构建目录。后续原生覆盖率阶段通过 C++ 输入回放验证了所用 SVA 与代码插桩，安装和能力边界见 [ANALYSIS.md](ANALYSIS.md)。UVM、randomize 和其他未使用特性仍未验证，不能推断为全部支持。
