# 单通道使用说明

2026-10-24：单通道 RTL、自动检查平台与运行脚本已经实现。本页验收对象是一个 256×32 bit FIFO；双通道顶层与统一监控已在 [双通道入口](DUAL_CHANNEL.md) 实现。

## 1. 一条命令运行

在仓库根目录打开 PowerShell：

~~~powershell
& .\sim\run_single.ps1
~~~

默认使用本机 D:/altera/14.1/modelsim_ase/win32aloem，2 级同步、种子 1、写周期 20ns、读周期 12ns、5000 次写侧随机决策。源码复制到 D:/fifo_sim 中的独立英文构建目录，日志保存到仓库 reports/logs/。

其他机器可显式设置工具和构建路径：

~~~powershell
& .\sim\run_single.ps1 -SimulatorBin 'C:\tools\modelsim\win64' -BuildRoot 'C:\fifo_sim'
~~~

日志必须含 RESULT: PASS，且不含失败、超时或致命错误。脚本会检查这些条件；ModelSim 进程退出码为零本身不能证明测试通过。

## 2. 打开波形

先运行上一节命令，再将其输出的 GUI 命令粘贴到 ModelSim 底部 Transcript。当前默认配置为：

~~~tcl
do {D:/fifo_sim/single_s2_seed1_w10000_r6000_p0_c32_h0/run_gui.do}
~~~

脚本加载测试，添加时钟、复位、请求、空满/阈值、指针、水位和数据波形，并运行全部场景。测试结束时停在 $finish 或显示宏 PAUSED 属正常停止；以 RESULT: PASS 和错误数判断结果。需要全景时执行：

~~~tcl
wave zoom full
~~~

wr_level、rd_level 是各时钟域的保守估计，不能要求始终相同。rd_data_valid 对应成功读出的响应，即使 empty 已经为 1，最后一个字仍可有效。

## 3. 回归与配置变体

~~~powershell
& .\sim\regress_single.ps1
& .\sim\run_single.ps1 -SyncStages 3 -Seed 1
& .\sim\run_single.ps1 -Seed 7 -ReadPhasePs 1000
& .\sim\run_single.ps1 -SyncStages 3 -Seed 2026 -WriteHalfPs 17500 -ReadHalfPs 5000 -ReadPhasePs 2500
& .\sim\run_single.ps1 -SyncStages 3 -Seed 11 -CountWidth 4
& .\sim\run_single.ps1 -Seed 13 -Hysteresis
~~~

第一条执行固定的 9 组配置，后续为单独运行示例。时钟参数单位为 ps，WriteHalfPs/ReadHalfPs 是半周期，ReadPhasePs 为读时钟初始偏移。

CountWidth=4 专门将六个计数器的上限缩至 15，检查饱和行为；正常使用为 32 位。Hysteresis 将几乎满撤销边界改为 <220，几乎空撤销边界改为 >36，置位门限仍为 224/32。

同一配置再次运行会更新相应日志。日志内 RUN_CONFIG 记录操作规模；保存其他操作规模的实验时另行归档，避免覆盖已有证据。

## 4. 测试内容

1. 复位输出、标志与全部计数器。
2. 三轮各写满 256 个随机字，满后再尝试写 20 次，排空后再尝试读 20 次。
3. 检查 224/223/219 与 37/32/33/37 阈值序列，覆盖默认与回差行为。
4. 至少 20 个短背压事件及连续 16 个读周期的背压；空时 ready=0 不误记下溢。
5. 默认 5000 次写时钟随机决策，读侧独立决策。分阶段切换写多读少、均衡、读多写少，随机插入背压。
6. 两个扩展指针多次绕回；所有成功读与独立参考队列比较，其余周期检查输出保持。
7. 留下 13 个未读字后共同复位，再写入/读出 64 字，验证清空与恢复。

平台逐边沿检查指针、空满、域内水位、阈值、响应和统计。参考模型使用二进制环形位置与独立延迟链，满状态用位置差等于 256 检查，不复制 RTL 的格雷码比较式。

参考位置使用非阻塞赋值，保证重合时钟采到旧的对侧位置；输入在下降沿驱动，输出在上升沿 NBA 后 1ps 检查。

## 5. 覆盖与局限

自定义水位 bins 为 0、1、31、32、33、223、224、225、255、256，另记录绕回、错误和背压统计。occupancy=10/10 只表示这十个水位 bins 命中。

当前许可证拒绝 covergroup，没有原生 UCDB、工具代码覆盖率或完整双通道覆盖率报告。自定义统计是否符合课程报告形式仍待确认。

尚未运行综合、布局布线、物理 CDC 分析、功耗或 MTBF 估算；未验证块 RAM 推断。复位仅支持两侧共同清空，当前接口是请求/响应式。

实测数据见 [单通道验证报告](../reports/SINGLE_CHANNEL_REPORT.md)，端口定义见 [接口说明](INTERFACE.md)。
