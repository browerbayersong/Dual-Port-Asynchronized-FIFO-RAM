# 通用综合、性能与覆盖率操作说明

用户尚未指定用于软件评估的器件或工艺库，现阶段完成无器件映射的结构资源比较与 RTL 行为测量。后续补充软件综合/实现的约束、时序、面积和功耗分析。任务书未要求上板，不需要为完成题目 1 购买开发板、烧录或进行实板测试。

## 工具与安装

已有 ModelSim：`D:/altera/14.1/modelsim_ase/win32aloem`。额外工具均放在仓库外，不修改系统 PATH，不上传工具二进制。

使用可运行的 Python（本机为 Codex 自带 Python），在仓库根目录执行；以下 `$python` 改为本机 Python 路径：

~~~powershell
$python = 'C:\Users\browersong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python -m pip install --target D:\fifo_tools\python -r tools/requirements-analysis.txt
& $python -m pip install --target D:\fifo_tools\compiler ziglang==0.14.1
& $python tools/run_synthesis.py
& $python tools/run_performance.py
& $python tools/run_native_coverage.py
& $python tools/report_native_coverage.py
& $python tools/capture_analysis_manifest.py
~~~

`verilator` PyPI 包是第三方 Windows 二进制封装；包版本与二进制报告版本分开记录。本机二进制报告 `rev vUNKNOWN-built20260516-4e853d8`。不要以最新网页文档推断本机二进制支持所有特性。

脚本支持 `--build-root`、`--simulator-bin` 等参数，用 `--help` 查看。构建目录须为英文路径。性能脚本 `--quick` 只跑首组；覆盖率脚本 `--quick` 同样只跑首组，不代表完整覆盖。`--reuse` 仅在源码/配置哈希匹配时复用已编译模型，仍重跑刺激和检查。首次 Zig 编译会建立标准库缓存，耗时可能较长。

## 综合口径

运行 [run_synthesis.py](../tools/run_synthesis.py)，分别对两级、三级使用相同参数和相同源文件运行 Yosys。第一阶段保留抽象 RAM，第二阶段展开 RAM 为通用 FF/选择逻辑；不使用 ABC 或目标单元库。

检查两块 256×32 存储、无锁存器、`check -assert` 通过，并分别保存统计和日志。资源结果、元数据口径与警告解释见 [通用综合报告](../reports/synthesis/REPORT.md)。原始 `stat` 含 `$scopeinfo` 元数据，汇总排除其硬件计数。

## 性能测量

运行 [run_performance.py](../tools/run_performance.py)，自动执行两级/三级、正常比/周期背压/读慢写快三种情况。平台继续使用独立参考队列和位置模型检查器，不只输出速率。

首次可读延迟以实际接受的写/读边沿计时；满撤销以实际弹出边沿至写域 full 下降计时。吞吐仅按预热后 200 μs 内成功读出的完整字统计。完整参数、测量和局限见 [性能报告](../reports/performance/REPORT.md)。

## 原生覆盖率方法

ModelSim Starter 的 covergroup 加载被许可证拒绝，当前额外 Verilator 二进制也会发出 `COVERIGN` 忽略 covergroup。采用本机已探测支持的 `cover property`，配合 `--coverage-user --coverage-line --assert`，不把忽略警告当作成功。脚本遇到 COVERIGN/不支持/错误即失败。

先在 ModelSim 跑已有完整双路自检，将 DUT 的 15 个输入导出为 VCD；再通过 C++ 回放同一输入事件，让实际 RTL 在 Verilator 中重新运行，生成原生 `.dat` 计数数据库。C++ 另用两个队列按接受操作核对数据、顺序、容量、读有效和保持，结束时核对复位丢弃与排空。原生 SVA 同时检查源格雷码、保护、背压和监控稳定性。

原生数据库中的功能点、代码插桩点与断言激活记录分别统计。报告脚本只读取工具数据库，不把旧的过程式计数改名为原生覆盖率。数据库采用 SystemC::Coverage-3 记录格式；Python 汇总不是 `verilator_coverage` 工具输出，也不是 UCDB。原始文件全部保留供审查。

Verilator 为二态回放，不能替代 ModelSim 四态验证、物理 CDC 或形式验证。只回放输入，不把原仿真的输出作为覆盖率证据；回放中的接受操作由当前 RTL 输出判定，独立队列再次检查。

## 明确软件评估目标后的工作

按 [约束意图](../constraints/README.md) 在目标工具建立五时钟及 CDC 约束，检查例外优先级、RAM 映射和所有未约束路径。随后在相同器件或工艺库、相同工作条件、活动与实现设置下，补充对应的资源/面积、关键路径、裕量、Fmax 和功耗报告。这些步骤在软件中完成，不要求实物硬件。

MTBF 需要器件常数和实际可用稳定时间；目前仅可解释增加一级带来的额外稳定时间，不能给绝对年数。题目最终报告仍需真实成员分工和人工复现。

方法参考：[Verilator 原生覆盖率](https://verilator.org/guide/latest/simulating.html#coverage-analysis)、[YoWASP Yosys](https://github.com/YoWASP/yosys)、[Windows 包封装](https://github.com/dau-dev/verilator-python)。实际能力以本机探测和日志为准。
