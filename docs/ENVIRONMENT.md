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
| 综合工具、目标器件、上板要求 | 待确认；本次未综合 |

环境小测试结果为 RESULT: PASS checks=40 enabled=20。单通道结果及证据见 reports/。

运行脚本每次复制并编译当前源码，库和波形保留在英文构建目录。此结果不代表支持全部 SV 特性；并发 SVA、UVM、约束随机 randomize 和原生代码覆盖率均未在本阶段验证。
