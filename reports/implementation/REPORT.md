# TD 目标实现报告

日期2026-10-24。Tang Dynasty V6.2.168116，PH1A100SFG676，速度等级2；该器件为软件评估假设。核心RTL与先前功能验证版本一致，使用只读状态选择封装降低IO数量。[运行条件及命令](../../docs/TARGET_ANALYSIS.md) · [机器可读汇总](summary.json)

## 资源与时序

| 指标 | 两级同步 | 三级同步 |
| --- | ---: | ---: |
| 寄存器位 | 1532 | 1576 |
| LUT6 合计 | 1040 | 1040 |
| LUT6 核心层次归属 | 799 | 812 |
| LUT6 封装及边界归属 | 241 | 228 |
| ERAM20K | 2 | 2 |
| 有效RAM数据位 | 16384 | 16384 |
| IO / 全局时钟 | 231 / 5 | 231 / 5 |
| 完整接口 setup WNS ns | -5.919 | -5.919 |
| 完整接口 hold WNS ns | -2.794 | -2.794 |
| 内部寄存器路径 setup WNS ns | 0.387 | 0.924 |
| 内部寄存器路径 hold WNS ns | 0.021 | 0.020 |
| STA coverage 工具口径 | 100% | 100% |
| 功耗 W | 未测 | 未测 |

资源为同一评估顶层口径，包含状态组合选择与IO。层次间优化会改变LUT归属；主要比较合计。ERAM20K物理容量不能当作有效数据量；LUT和FF数量不能标成平方微米面积。

完整接口时序没有收敛。最差setup涉及RAM到b_rd_data[26]外部输出，最差hold涉及b_wr_data[4]输入到RAM。自动引脚和IO缓冲均参与路径，没有真实外部器件或板级布线预算。不得把负裕量删除后声称通过。

内部视图在**同一套SDC**下用report_timing_path筛选dut层次内部寄存器起止路径，每组最差20端点；没有新加假路径或重新创建时钟。以下频率仅用于这一分析视图，不覆盖外部数据接口或全部RAM端点：

| 时钟域 | 约束周期 ns | 2级内部Fmax MHz | 3级内部Fmax MHz |
| --- | ---: | ---: | ---: |
| a_wr_clk | 20 | 131.718 | 172.176 |
| a_rd_clk | 12 | 211.149 | 190.114 |
| b_wr_clk | 35 | 173.310 | 159.821 |
| b_rd_clk | 10 | 173.310 | 189.609 |
| monitor_clk | 10 | 104.026 | 110.181 |

不同同步级数改变布局，内部Fmax没有逐域单调关系。三级增加44位寄存器：36位指针同步加8位监控请求/确认同步。

## 约束证据

16组最大数据延迟共472条路径，Dominated=Total、Shadowed=Ignored=0。五个命名时钟存在，无默认DeriveClock。异步hold例外与复位、诊断接口例外保留在ignored报告，STA coverage 100%不表示例外路径已经通过时序验证。

| Gray 总线 | 源周期上界 ns | 2级最大延迟 ns | 3级最大延迟 ns |
| --- | ---: | ---: | ---: |
| a_r2w | 12 | 1.035 | 0.950 |
| a_w2r | 20 | 1.007 | 1.203 |
| b_r2w | 10 | 1.064 | 1.158 |
| b_w2r | 35 | 1.029 | 0.929 |

每组均报告9位。逐位绝对延迟限制作保守偏斜上界；同一max corner下的延迟差并非跨PVT独立偏斜签核。虽然导出的SDC包含set_max_skew，没有独立原生生效报告，因此不宣称该命令通过。

## 关键警告与功耗缺项

**TMR-5506**提示ERAM地址/片选受异步复位寄存器驱动，潜在RAM数据翻转。本项目共同复位清空逻辑队列、等待本地域释放并门控操作，但尚未完成该器件物理RAM/复位行为的门级或厂商规则验证。功能仿真通过不消除这一警告，本结果不能作为硬件部署签核。

原生功耗图建立后，calculate_power返回 **PWR-5001 Import power lib first**。本机未找到匹配的功耗库；[探测记录](power_attempt.log)、[设置](power_attempt_settings.txt)和[缺项状态](power_status.json)保留。输出中的未计算零值不接受为W值，summary中为null。两种级数的总功耗对比待补。

结构代理仅说明同步寄存器从88增至132，多44位；在等单位负载假设下这一部分时钟负载增加50%，不能推导整机功耗增加50%。

## 原始证据索引

每个s2_/s3_前缀分别保留：route.area资源、route.timing完整接口、core.timing内部寄存器筛选、各域.timing、exceptions.timing最大延迟、ignored.timing例外、effective.sdc实际约束、clocks.rpt、routing.rpt、route.status、flow.log及运行脚本。rtl/gate/place报告用于检查流程，最终数字均取route阶段。manifest记录输入文件规范化LF哈希和封装参数。

flow.log中的IMPLEMENTATION: PASS仅指流程执行完成。最终日志由保存的route.db重新导出报告，源文件和SDC匹配检查通过；完整布线设置由flow.tcl保留。数据库和网表位于仓库外。

两种封装配置均通过原双通道自检及状态选择附加检查：[2级日志](s2_wrapper_verify.log)、[3级日志](s3_wrapper_verify.log)、[参数记录](wrapper_verify_manifest.json)。全新目录另完成[指定配置及10组回归](../reproduction/summary.json)。核心RTL未改动，旧验证数据库与manifest保留原始来源。
