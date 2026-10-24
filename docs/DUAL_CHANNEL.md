# 双通道与统一监控使用说明

2026-10-24：dual_async_fifo 已实例化两个独立的 256×32 bit FIFO，并通过 fifo_monitor 在监控时钟域统一发布状态。两路共用单通道 RTL，各自维护 RAM、指针、空满、阈值、背压及六个计数器。

## 快速运行

在仓库根目录 PowerShell 中执行：

~~~powershell
& .\sim\run_dual.ps1
& .\sim\regress_dual.ps1
~~~

第一条执行一组完整测试；第二条执行 10 组固定配置。默认工具路径为 D:/altera/14.1/modelsim_ase/win32aloem，构建目录为 D:/fifo_sim。可通过 SimulatorBin、BuildRoot 参数修改，构建路径必须为纯英文。

仿真固定 A 写/读周期 20/12ns，B 为 35/10ns，读写频率比分别为 5:3 和 7:2。monitor_clk 周期为 10ns。每组两路各进行 5000 次写侧随机决策，读侧按各自时钟独立决策，并在三个阶段改变读写概率。

## 查看波形

先运行脚本，再将输出的 GUI 命令输入 ModelSim Transcript。默认配置：

~~~tcl
do {D:/fifo_sim/dual_s2_seed1_a1000_bw2500_br500_c32_h0_auto0_n5000/run_gui.do}
~~~

结束时停在 $finish/PAUSED 可以是正常停止；以 RESULT: PASS 和错误日志判断。需要全景时输入 wave zoom full。波形包含两路请求、空满/阈值，以及监控请求、ready/busy、valid、序号和四个状态包。

## 配置示例

~~~powershell
& .\sim\run_dual.ps1 -SyncStages 3 -Seed 1
& .\sim\run_dual.ps1 -Seed 7 -AReadPhasePs 0 -BWritePhasePs 0 -BReadPhasePs 0
& .\sim\run_dual.ps1 -Seed 37 -CountWidth 4
& .\sim\run_dual.ps1 -SyncStages 3 -Seed 11 -Hysteresis
& .\sim\run_dual.ps1 -Seed 19 -AutoRefreshCycles 32
~~~

相位单位为 ps。4 位计数器用于验证两路共 12 个计数器饱和；正常使用为 32 位。回差开启后 AF 在 <220 时撤销、AE 在 >36 时撤销，置位门限仍为 224/32。

RTL 顶层的 AUTO_REFRESH_CYCLES 默认 32，表示空闲期间等待 32 个监控周期后自动发起下一次采集。测试脚本默认传入 0，以定向检查手动握手、源时钟暂停和复位取消；回归额外验证自动刷新 8/32 两种配置。

## 当前验证范围

每组均执行题目六类场景：两路随机数据写满/读空、各 5000 次混合决策、满后持续写/空后持续读、阈值与回差、背压、双路组合及监控统计。

- A/B 各有独立参考队列，数据最高位按通道打标，便于检出通道接错；每次成功读出都比较完整 32 位内容。
- 逐本地域时钟检查指针、水位、空满、阈值、输出保持和本地计数。
- 每个源域实际锁存快照时，独立记录该边沿之前的外部标志/计数，随后逐帧比较统一输出。
- 快照 valid 之外输出保持；每个请求必须收到四个源域各一次确认后才能发布。
- 手动模式额外暂停 B 写时钟，确认监控等待、busy 中请求不重叠；恢复时钟后完成，并验证共同复位取消未完成采集。
- 自动模式检查定时请求真实发生，同时继续核对所有快照；暂停/取消用例由手动配置覆盖。

自定义功能 bins 包含两路各 10 个水位、8 个标志跳变、3 类背压长度，以及 4 个指定双路组合。详见 [验证报告](../reports/dual/REPORT.md)。

## 端口与后续工作

业务端口在单通道名称前增加 a_/b_ 前缀；读响应和统计语义沿用 [单通道接口](INTERFACE.md)。统一状态包的字段和时序见 [监控协议](MONITOR_PROTOCOL.md)。

源码新增 snapshot_mailbox.v、fifo_monitor.v、dual_async_fifo.v；独立文件清单为 sim/dual_rtl.f、sim/dual_tb.f，原单通道入口保留。

当前完成 RTL 功能仿真及自定义覆盖统计。原生 covergroup/UCDB、目标器件综合、时序/面积、PPA 和物理 CDC 约束验证尚未完成。
