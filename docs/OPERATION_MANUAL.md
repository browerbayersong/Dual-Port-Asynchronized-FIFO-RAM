# 操作手册

适用项目：题目 1“双异步 FIFO 系统”。本文同时作为实现约定和后续运行指南。

**2026-10-24 更新：单通道 RTL 与自动验证已实现。当前可直接运行的入口见 [单通道使用说明](SINGLE_CHANNEL.md)。** 本文保留完整双通道目标流程，第 7—9 节 dual_fifo_tb 与原生覆盖率命令仍为后续约定；双通道监控、综合与 PPA 尚未完成。

关联文档：[任务清单](TASKS.md) · [项目首页](../README.md)

## 1. 先确认范围

### 1.1 题目硬性要求

1. 两个独立异步 FIFO，每路深度 256、数据位宽 32；A 读写频率比 5:3，B 为 7:2。
2. 自行描述 RAM，不调用设计 IP；允许两路复用参数化代码。
3. 正常读写、空满保护、输出保持、可参数化几乎空/满，默认门限为 32/224。
4. 读侧背压、溢出与下溢计数、顶层统一监控接口。
5. 完成题目 6.1—6.6 测试；设计用 Verilog，测试平台用 SystemVerilog 或 C++。
6. 报告包含结构/FSM、预设条件、实现方法、验证日志、覆盖率、时序/面积及 PPA 对比；使用 AI 时附实际提示词记录。

原始依据为用户提供的《硬件描述语言 课设题目27.pdf》第 2—4 页。题目 2 的 CROC、IHP 130nm 及其指定工具流程不作为本题的工具要求。

### 1.2 本项目建议约定

以下为便于落地提出的方案，不是任务书逐字规定：请求式读接口、同步 RAM 读、共同复位、32 位饱和计数、握手快照监控、可选阈值回差、Questa 命令示例。实现前可调整，但须同步接口表、参考模型、用例及报告。

建议主要拓展为 2/3 级同步器对比，并增加背压周期、水位峰值等可量化统计。已有的空满、阈值、背压与错误计数属于基本功能。

## 2. 环境准备与首次下载

### 2.1 克隆仓库

在用于保存项目的目录打开 PowerShell，执行：

~~~powershell
git clone https://github.com/browerbayersong/Dual-Port-Asynchronized-FIFO-RAM.git
Set-Location .\Dual-Port-Asynchronized-FIFO-RAM
git status
git log -1 --oneline
~~~

已有本地副本时先检查本地修改，再使用 git pull --ff-only；不要为更新文档覆盖未提交代码。

### 2.2 记录工具能力

~~~powershell
Get-Command git, vlog, vsim, vcover, quartus_sh, vivado -ErrorAction SilentlyContinue
vlog -version
vsim -version
~~~

每位成员将实际工具版本、操作系统、综合目标器件、许可证能力和选择理由记录到后续创建的 docs/ENVIRONMENT.md。

2026-10-23 的本次本机检查仅确认：

- PATH 中存在 Git。
- vlog/ vsim 位于 D:/altera/14.1/modelsim_ase/win32aloem/。
- vlog 返回 ModelSim ALTERA 10.3c，编译器日期为 2014.09。
- 上述安装目录未发现 vcover.exe，PATH 中未找到 vcover、quartus_sh、vivado。
- 未确认全机其他位置是否存在综合工具，也未验证仿真许可证、covergroup、SVA 或完整回归能力。

因此先用最小 SystemVerilog 示例验证所需语言能力，再选择完整流程。旧版环境可优先采用过程式驱动、固定数组参考队列和过程式检查。正式功能覆盖率建议使用已确认支持 covergroup 和覆盖率导出的工具；如果使用自定义 bins 统计，必须输出覆盖点定义、命中数、总数和缺口，并确认课程接受这种报告形式，不能将代码覆盖率充当功能覆盖率。

Questa 示例命令的依据见文末命令参考；旧版 ModelSim 的选项和许可证可能不同，须以实际安装帮助和小规模试运行为准。

## 3. 目录与后续文件约定

以下为完整双通道目标目录；当前已实现的单通道文件和运行入口见 SINGLE_CHANNEL.md，最新环境实测见 ENVIRONMENT.md：

~~~text
rtl/
  reset_sync.v          各时钟域复位同步释放
  gray_sync.v           参数化格雷码同步链
  fifo_ram.v            自描述双时钟 RAM
  async_fifo.v          单通道核心及本地统计
  fifo_monitor.v        统一快照控制和采样
  dual_async_fifo.v     两个 FIFO 实例及监控顶层
tb/
  dual_fifo_tb.sv       驱动、参考模型、检查与用例选择
sim/
  rtl.f                 仅设计文件清单
  tb.f                  仅验证文件清单
constraints/            目标工具的时钟与跨域约束
reports/
  logs/                 原始运行日志
  coverage/             功能覆盖率与数据库
  synthesis/            资源、时序、功耗报告
  comparison/           同步级数与吞吐对比
docs/
  ENVIRONMENT.md        实际环境与复现条件
  INTERFACE.md          最终端口、时序、计数规则
  AI_ASSISTANCE.md      实际 AI 辅助过程
~~~

文件清单每行一个相对仓库根目录的源文件路径；按依赖顺序列出。本文命令都从仓库根目录运行。创建 .gitignore 时排除 work/、仿真临时文件和大波形；保留必要的小型文本报告，大型原始产物记录可访问的存放位置。

## 4. 接口、参数与事件定义

### 4.1 建议参数

| 参数 | 默认值 | 约束或含义 |
| --- | --- | --- |
| DATA_WIDTH | 32 | 本题验收使用 32 |
| ADDR_WIDTH | 8 | DEPTH=2^ADDR_WIDTH=256 |
| SYNC_STAGES | 2 | 至少 2；拓展比较 3 |
| AF_ASSERT / AF_CLEAR | 224 / 224 | 几乎满置位门限及撤销边界 |
| AE_ASSERT / AE_CLEAR | 32 / 32 | 几乎空置位门限及撤销边界 |
| COUNT_WIDTH | 32 | 统计计数器位宽，建议饱和计数 |

基本模式不引入回差：几乎满在水位 >=224 时为 1，<224 时撤销；几乎空在 <=32 时为 1，>32 时撤销。

可选回差示例：AF_CLEAR=220，则水位 <220 时撤销；AE_CLEAR=36，则水位 >36 时撤销。置位门限仍为 224 和 32。校验 0<=AF_CLEAR<=AF_ASSERT<=DEPTH、0<=AE_ASSERT<=AE_CLEAR<=DEPTH；回差必须独立列入测试。

### 4.2 每路建议端口

| 时钟域 | 输入 | 输出 |
| --- | --- | --- |
| 写域 wr_clk | wr_en、wr_data | full、almost_full、写侧统计 |
| 读域 rd_clk | rd_en、rd_ready | rd_data、rd_data_valid、empty、almost_empty、读侧统计 |
| 监控域 monitor_clk | snapshot_req | snapshot_valid、snapshot_id、两路状态统计 |
| 复位 | 共同低有效 rst_n | 各域本地复位完成状态，可供验证观察 |

建议采用请求式接口：在读时钟边沿接受 rd_en && rd_ready && !empty；同步 RAM 在该边沿后更新 rd_data，rd_data_valid 指示对应响应。测试平台在非阻塞赋值完成后比较响应。rd_ready 表示下游有能力接收该请求的响应。

这套接口不是完整的标准流式 valid/ready 接口；若改为标准流接口，需要输出缓冲和响应保持，重新定义接受事件，避免背压过程中丢失已产生的数据。上游满时持续 wr_en 在本题中记非法写尝试；标准流协议中 valid 等待 ready 的含义须另行约定。

### 4.3 唯一事件口径

~~~verilog
wr_fire       = wr_en && !full;
rd_fire       = rd_en && rd_ready && !empty;
overflow_evt  = wr_en && full;
underflow_evt = rd_en && rd_ready && empty;
stall         = rd_en && !empty && !rd_ready;
stall_start   = stall && !stall_previous;
~~~

- 成功写/读计数仅在 wr_fire/rd_fire 时加一；RAM 和指针也使用同一接受事件。
- 每个写时钟的 overflow_evt 加一次溢出，每个读时钟的 underflow_evt 加一次下溢。
- rd_ready=0 时不视为有效读尝试，故不累计下溢。
- 背压触发次数累计 stall_start，背压周期累计 stall；连续阻塞 10 拍是 1 次事件、10 个周期。
- stall_previous 每个读时钟更新，复位置零。
- 建议计数饱和于最大值；参考模型使用同样规则。统计复位后为零，复位期间不计数。

### 4.4 复位与输出保持

共同 rst_n 异步有效，各时钟域独立同步释放。验证驱动在所有相关域退出复位后再发请求。初始化指针=0、full=0、empty=1、almost_full=0、almost_empty=1，rd_data 与统计置零。

不接受读请求时 rd_data 保持，rd_data_valid 按响应协议撤销；同步读取最后一个字时可以出现 empty=1 且 rd_data_valid=1，前者表示队列已空，后者表示最后一次响应有效。

RAM 无需逐字复位，旧内容由指针和 empty 屏蔽。运行中只复位某一侧会破坏双方一致性；本基线仅支持整体清空式复位，如需单侧复位恢复，必须作为单独协议实现和验证。

## 5. 单通道实现步骤

1. 建立 RAM 写时钟进程与同步读进程；禁止在满时写入，未接受读取时保持数据输出。
2. 使用 9 位本地二进制指针，低 8 位寻址；有效操作时加一，按 9 位自然绕回。
3. 对下一二进制指针执行 gray=(bin>>1)^bin，并在源时钟域寄存后跨域。
4. 同步链中只放目标域寄存器；最终级供目标域使用，中间级不驱动业务逻辑。
5. 写指针格雷码同步到读域，读指针格雷码同步到写域。
6. 使用下一指针生成并寄存空满标志，避免最后一个槽位边界出错。

对本题 9 位指针：

~~~verilog
wbin_next  = wbin + wr_fire;
rbin_next  = rbin + rd_fire;
wgray_next = (wbin_next >> 1) ^ wbin_next;
rgray_next = (rbin_next >> 1) ^ rbin_next;
empty_next = (rgray_next == wgray_sync);
full_next  = (wgray_next == {~rgray_sync[8:7], rgray_sync[6:0]});
~~~

上式为逻辑说明，实际代码要显式处理位宽、参数、复位和时序赋值。格雷码满判断翻转最高两位，不能直接套用二进制只翻转最高位的判断方式。实现依据见 [Cummings 异步 FIFO 论文](https://www.researchgate.net/profile/Clifford-Cummings/publication/252160343_Simulation_and_Synthesis_Techniques_for_Asynchronous_FIFO_Design/links/54bfe9720cf28eae4a66418a/Simulation-and-Synthesis-Techniques-for-Asynchronous-FIFO-Design.pdf)。

阈值使用同步后的对侧指针转换回二进制。注册标志时，可用本地下一指针与同步对侧指针做差，使阈值与本拍接受操作一致：

~~~text
写域下一水位估计 = wbin_next - rbin_sync    （9 位模 512）
读域下一水位估计 = wbin_sync - rbin_next    （9 位模 512）
~~~

写域估计倾向高估实际水位，读域估计倾向低估；空满及阈值撤销有同步延迟。参考模型需跟踪相同的域内可见指针和注册时序。保护失败的请求不能推动指针；远端正常操作仍可以在同步后解除 full/empty。

先完成单通道的写满/排空和多次绕回，再增加阈值与统计。不要用一个同时受读写时钟更新的共享水位计数器代替异步指针方案。

## 6. 双通道与监控

顶层实例化两次 async_fifo，RAM、指针、同步链、标志、计数全部各自独立。四个时钟由外部输入，RTL 不需要为题目频率比制作内部固定分频器。

建议激励周期：A 写 20ns、读 12ns；B 写 35ns、读 10ns。读写频率比等于写周期/读周期，因此分别为 5:3、7:2。设定 timeunit=1ns、timeprecision=1ps，保证 17.5ns 等半周期能准确表示。通过不同初始延迟覆盖相位，记录每轮配置。

监控计数在事件源时钟域产生。统一监控使用以下握手快照方案：

1. monitor_clk 域生成请求翻转位，经同步器送到四个数据时钟域。
2. 各源域检测新请求，将本域标志/计数锁存到保持寄存器，再返回应答翻转位。
3. 监控域同步应答，确认保持数据已有足够稳定时间后捕获；下一次请求前源域保持数据。
4. 四个域均应答后更新完整输出，snapshot_valid 有效，snapshot_id 更新；请求不允许重叠。

监控 FSM 可以为 IDLE → REQUEST → WAIT_ACK → CAPTURE → IDLE。对保持数据总线进行稳定性和握手检查，不直接逐位同步正在变化的二进制计数器。增加周期性采样可形成持续刷新状态；只有所有源时钟运行时，才能承诺有界刷新延迟。

各源域捕获时刻不同，快照是每个源域内部一致的集合，不保证全系统同一瞬间。不能直接用来自不同捕获时刻的读写总次数差作为精确当前水位。需要精确核对最终统计时，先停止激励并等待同步及快照完成。

## 7. 测试平台与运行约定

### 7.1 测试平台必须实现的入口

后续 dual_fifo_tb.sv 约定顶层参数 SYNC_STAGES，以及以下命令行参数。命令行本身不会自动产生这些功能，测试平台必须解析并执行。

| 入口 | 示例 | 含义 |
| --- | --- | --- |
| 顶层参数 | -gSYNC_STAGES=2 | elaboration 时选择同步级数 |
| 随机种子 | -sv_seed 1 | 仿真器随机种子 |
| 用例选择 | +TEST=fill_drain | $value$plusargs 解析用例名 |
| 操作规模 | +OPS=5000 | random_mix 每路的操作组数 |
| 初始相位 | +PHASE_ID=0 | 解析为预先定义的四时钟初始延迟表 |

未知用例或非法参数应直接报错。建议统一打印 RUN_CONFIG、各通道计数、FAIL 明细和最终 RESULT: PASS/FAIL。每轮需要超时保护，失败不能只打印后仍给出 PASS。

“5000 组”的建议定义：每路写驱动产生至少 5000 次写侧决策，读驱动在独立读时钟持续做读侧决策；三个概率阶段动态变化。分别记录两域决策次数、请求次数和实际成功次数，读侧不能因为读时钟更快而少覆盖一个阶段。

### 7.2 参考模型与采样

两路各有独立参考队列；wr_fire 时加入 wr_data，rd_fire 时取队首建立期望响应，在 rd_data_valid 的对应时刻比较。驱动与采样分离，避免在同一上升沿和 DUT 竞争。可在下降沿更新输入，在上升沿记录接受事件，再按明确的时钟块或延后采样规则检查非阻塞赋值后的输出。

监控原生域标志时使用该域边沿；统一监控输出仅在 snapshot_valid 后采样。两路参考模型不得混用一个队列。随机测试结束时停止写、解除背压并排空，两路队列都必须为空。

### 7.3 六类场景的执行重点

| TEST 名 | 操作 | 通过证据 |
| --- | --- | --- |
| smoke | 两路少量写入并读回 | 基础编译与数据通路通过 |
| fill_drain | 停读写满 256 项，再停写排空，多轮重复 | 容量准确、数据顺序一致、绕回命中 |
| random_mix | 每路至少 5000 组，切换读写概率与种子 | 全程自动比较、参数与次数记录完整 |
| error_guard | 满后再尝试写 N 次，空后再尝试读 M 次 | 指针/数据受保护，错误增量分别为 N/M |
| thresholds | 上下穿越 32、224，重复阈值附近操作 | 注册标志符合本地域估计和回差规则 |
| backpressure | 单拍/长时间/反复暂停，随机撤销写请求 | 不重复、不乱序，背压事件与周期正确 |
| dual_combo | 定向构造 A 满 B 空、反向、双几乎满、双背压 | 组合命中，监控快照及最终统计正确 |

读时钟更快时随机激励可能一直不满，所以 fill_drain 和 dual_combo 必须定向暂停读取。每次检查空满撤销应使用与同步级数及注册逻辑一致的等待条件，不写死“真实水位变化当拍就撤销”。

## 8. 编译与仿真示例

### 8.1 前置条件

rtl/、tb/ 和 sim/rtl.f、sim/tb.f 已实现，顶层测试模块名为 dual_fifo_tb，并支持第 7 节的入口。下面给出命令模板，**本次文档提交未执行这些仿真命令**。

先创建输出目录，然后首次创建工作库：

~~~powershell
New-Item -ItemType Directory -Force reports/logs, reports/coverage | Out-Null
vlib work
vlog -work work -f sim/rtl.f
vlog -work work -sv -f sim/tb.f
~~~

已有 work 库时不需要重复 vlib。若旧版环境不支持原生覆盖率或某些验证特性，测试平台须提供过程式检查/自定义功能 bins 的兼容实现，再进行基础仿真。

基础快速运行：

~~~powershell
vsim -c -onfinish stop -sv_seed 1 -gSYNC_STAGES=2 -l reports/logs/smoke_s1.log work.dual_fifo_tb +TEST=smoke +PHASE_ID=0 -do "run -all; quit -f"
~~~

定向用例将 +TEST 改为第 7 节的名称。随机回归示例：

~~~powershell
$taskSeeds = @(1, 7, 23, 101, 2026)
foreach ($taskSeed in $taskSeeds) {
    $taskLog = "reports/logs/random_mix_s$taskSeed.log"
    vsim -c -onfinish stop -sv_seed $taskSeed -gSYNC_STAGES=2 -l $taskLog work.dual_fifo_tb +TEST=random_mix +OPS=5000 +PHASE_ID=0 -do "run -all; quit -f"
    if ($LASTEXITCODE -ne 0) { throw "仿真进程失败：$taskLog" }
    $taskText = Get-Content -LiteralPath $taskLog -Raw
    if (($taskText -notmatch 'RESULT: PASS') -or ($taskText -match 'RESULT: FAIL|CHECK_FAIL|TIMEOUT|\*\* (Error|Fatal):')) {
        throw "检查失败或未完成：$taskLog"
    }
}
~~~

本示例要求测试平台使用约定的最终结果标记；进程退出码为零本身不能证明检查通过。每次运行还应确认两路排空、统计匹配和运行未超时。更换相位和 SYNC_STAGES 时使用不同文件名保存日志，避免覆盖。

### 8.2 查看波形

~~~powershell
vsim -voptargs=+acc -sv_seed 1 -gSYNC_STAGES=2 work.dual_fifo_tb +TEST=fill_drain +PHASE_ID=0
~~~

在仿真器 Transcript 中执行：

~~~tcl
add wave -r sim:/dual_fifo_tb/*
run -all
~~~

至少观察四个时钟、复位、两路接受事件、二进制/格雷码指针、同步末级指针、空满/阈值、数据响应、背压和错误计数。图形只作为解释证据，自动检查负责判断数据是否正确。

## 9. 功能覆盖率流程

本节仅用于已确认支持 covergroup、覆盖率数据库和 vcover 的环境。过程式兼容模式应单独输出 bins 表，不能假定它会生成 UCDB。

建议功能 bins：

- 每路真实模型水位 0、1、31、32、33、223、224、225、255、256；域内阈值检查另用本地域水位模型。
- 空到非空、非空到空、未满到满、满到未满。
- 溢出、下溢、背压事件及背压长度区间。
- RAM 地址与扩展指针多次绕回、两种同步级数、多种初始相位。
- 双通道指定状态交叉；避免生成没有意义且不可达的全量交叉。

功能覆盖率与 RTL 语句/分支覆盖率分别报告。需要 RTL 代码覆盖率时，在支持该选项的 Questa 环境中重新编译设计，例如：

~~~powershell
vlog -work work -cover bces -f sim/rtl.f
vlog -work work -sv -f sim/tb.f
vsim -c -onfinish stop -coverage -sv_seed 1 -gSYNC_STAGES=2 -l reports/logs/random_mix_cov_s1.log work.dual_fifo_tb +TEST=random_mix +OPS=5000 +PHASE_ID=0 -do "run -all; coverage save reports/coverage/random_mix_s1.ucdb; quit -f"
vcover report -details reports/coverage/random_mix_s1.ucdb
~~~

保存独立测试的 UCDB，确认文件非空且报告中确实存在预期 covergroup 和实例。合并示例，前置条件是两个输入数据库已经产生且采用相同覆盖模型：

~~~powershell
vcover merge reports/coverage/merged.ucdb reports/coverage/fill_drain_s1.ucdb reports/coverage/random_mix_s1.ucdb
vcover report -details reports/coverage/merged.ucdb
~~~

首次实现应验证 covergroup 的每实例设置、采样事件和合并规则。两路以及 2/3 级配置均需单独报告，不能靠合并掩盖一路未被测试。

闭环标准：指定可达功能 bins 命中 100%；未命中项有定位、补测或不可达说明。不得仅增加仿真时长后假定已完成覆盖。

## 10. 综合、时序、功耗与拓展

### 10.1 建立工程

1. 在选定综合工具创建工程，选择实际目标器件/工艺，顶层为 dual_async_fifo。
2. 仅加入 rtl.f 中的设计文件，禁止把测试平台加入综合。
3. 固定 DATA_WIDTH=32、ADDR_WIDTH=8，分别综合 SYNC_STAGES=2 与 3。
4. 加入五个时钟的定义：四个数据时钟及 monitor_clk。数据时钟周期可使用第 6 节示例；监控时钟由工程明确设置。
5. 声明实际异步关系，给同步链添加目标工具识别的属性；对格雷码总线设置适当的最大数据路径延迟或位间偏斜约束。
6. 检查约束优先级与实际生效路径，避免宽泛异步/假路径设置使所需最大延迟约束失效；保持本地域正常时序分析。
7. 运行综合与目标流程的布局布线/时序分析，检查 RAM 推断、锁存器、未约束端点和多驱动警告。

RAM 用 RTL 推断符合“不调用设计 IP”的方案；是否映射到目标器件块 RAM 取决于工具、器件和读写编码方式，以综合报告为准。不能仅凭源代码数组声明声称已使用块 RAM。

约束依据可参阅 [AMD CDC 路径约束说明](https://docs.amd.com/r/2024.2-English/ug1387-acap-hardware-ip-platform-dev-methodology/Constraints-on-Individual-CDC-Paths)。不同工具的具体命令不同，应根据实际目标工程编写并检查报告。

### 10.2 保持对比条件一致

| 指标 | 2 级同步 | 3 级同步 | 数据来源 |
| --- | --- | --- | --- |
| 两路功能回归 | 待运行 | 待运行 | 日志和种子清单 |
| 必需功能 bins | 待运行 | 待运行 | 独立配置覆盖率报告 |
| LUT/ALM 或单元面积 | 待测 | 待测 | 相同器件和设置的综合报告 |
| 寄存器、RAM 资源 | 待测 | 待测 | 综合资源报告 |
| 各时钟域关键路径/频率 | 待测 | 待测 | 时序报告 |
| 首次可读、满撤销延迟 | 待测 | 待测 | 相同刺激的边沿时间戳 |
| 吞吐、背压占比 | 待测 | 待测 | 有效传输计数/统计窗口 |
| 动态、静态功耗 | 待测或未测 | 待测或未测 | 同活动和环境的功耗估算 |
| MTBF | 待估或缺参数 | 待估或缺参数 | 器件参数或专用工具报告 |

不得用 LUT 数量直接标成物理面积，也不得把综合前估计与布线后结果混作同一阶段。功耗估算需注明活动文件、频率、器件、温度、电压和分析阶段；缺少数据时写“未测”，保留补测任务。

### 10.3 同步级数、可靠性与吞吐

仅四条 9 位指针同步链，从 2 级改 3 级增加 4×9=36 个寄存器；复位、监控等总资源差异由综合结果决定。额外一级通常增加一个目标域周期的指针可见延迟，应测量由此造成的标志撤销和突发传输代价。

MTBF 的常用形式为 exp(T_res/τ)/(C·f_clk·f_toggle)，器件常数和可用稳定时间必须有依据。增加稳定时间通常显著提高 MTBF，但 RTL 仿真无法测量真实亚稳态失效率；缺少工艺/器件参数时只做带明确假设的相对分析，不编造绝对年数。参见 [Intel 亚稳态分析](https://www.intel.com/content/www/us/en/docs/programmable/683068/18-1/metastability-analysis.html) 与 [器件 MTBF 白皮书](https://cdrdv2-public.intel.com/650346/wp-01082-quartus-ii-metastability.pdf)。

每路吞吐用“统计窗口内成功传输字数×32/窗口秒数”报告为 bit/s，同时列出字/s。无背压且持续供数时，理论上限不超过 min(f_wr,f_rd) 个字/s，实际值还受空满切换及同步开销影响。指定比例均为读侧较快，应重点解释写入速率瓶颈；额外选择读慢写快、极快读侧、间歇背压进行极端比例实验，并与必测场景分开记录。

## 11. 常见问题定位

| 现象 | 优先检查 |
| --- | --- |
| 写到 255 或 257 项才满 | 指针位宽、下一指针、格雷码最高两位取反 |
| 第一项/最后一项比较失败 | 同步 RAM 读延迟、非阻塞赋值采样、参考队列出队时机 |
| 远端操作后标志未立即变化 | 按同步级数与注册时序检查，先排除合理延迟 |
| 空后写入仍永久 empty | 写指针同步链、复位释放、目标读时钟是否运行 |
| 阈值与真实水位差几项 | 区分读域/写域估计，核对对侧指针同步延迟 |
| 背压次数多了十倍 | 是否把持续周期当成触发次数 |
| 两路混入对方数据 | 独立 RAM/端口连接、参考队列索引 |
| 没有覆盖率或报不支持 | 工具版本/许可证、covergroup 兼容、数据库保存和采样 |
| 仿真不结束 | 收尾排空、背压解除、写驱动停止、超时是否实现 |
| 统计总数偶发异常 | 二进制总线跨域采样、快照握手、饱和规则 |
| 同步指针跳过多个码值 | 快源慢目的域的正常采样可能；只检查源端单步格雷码性质 |
| RAM 没有映射为存储块 | 是否清空整个数组、读写模板、器件及工具能力 |

## 12. Git 协作与交付

实现工作建议使用功能分支，每次提交对应可检查的小步。示例：

~~~powershell
git switch -c feat/single-fifo
git status
git diff --check
git add rtl tb sim docs
git diff --cached --stat
git commit -m "feat: implement single-channel async FIFO"
git push -u origin feat/single-fifo
~~~

此提交命令仅在相应目录和代码已创建、检查已完成后使用。提交前审查暂存内容，排除工具临时库、大波形、许可证和无关个人文件。出现冲突先检查双方改动，合并后重跑受影响用例。

每次正式实验保存以下字段：提交号、日期、工具和版本、目标器件、SYNC_STAGES、阈值/回差、时钟和相位、测试名、种子、操作数、最终结果、原始产物路径。

AI 记录应包含实际问题与提示词、输出用途、采用/修改内容、人工复核和测试证据。本次可记录的实际请求包括“我们要做第一个题目，分析分析该怎么做”和后续要求生成任务清单、操作手册并上传仓库；当前采用的是规划文档，尚未产生 RTL 验证证据。后续每次辅助编码另行追加，不能将建议示例写成已完成实验。

最终报告按任务清单 M5 逐项核对，纸质和电子版各一份，并写明实际成员分工。交付前让另一名成员从干净目录复现，更新首页状态与真实运行命令。

## 13. 命令与方法参考

- [Questa SIM Command Reference Manual 2024.2](https://ww1.microchip.com/downloads/aemDocuments/documents/FPGA/swdocs/questasim/questa_sim_ref_2024_2.pdf)：编译、仿真、参数和覆盖率命令；实际选项以所用版本为准。
- [Questa Verification Run Manager User Guide 2024.2](https://ww1.microchip.com/downloads/aemDocuments/documents/FPGA/swdocs/questasim/vrm_user_2024_2.pdf)：多种子运行、覆盖率保存和合并工作流。
- 本文第 5、10 节中的原始论文和厂商说明：分别支持 FIFO 方法、CDC 约束与可靠性分析。

建立日期：2026-10-23。文档中的所有“待测”“待运行”必须在实际完成后用原始证据更新。
